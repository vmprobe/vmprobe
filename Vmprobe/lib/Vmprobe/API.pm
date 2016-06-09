package Vmprobe::API;

use common::sense;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Callback::Frame;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Event;
use Vmprobe::DB::ActiveRun;




sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    $self->_start;

    return $self;
}




sub _start {
    my ($self) = @_;

    $self->{server_guard} = tcp_server($self->{host} // undef, $self->{port} // 7624, sub {
        my ($fh, $host, $port) = @_;

        my $conn = { fh => $fh, peer_host => $host, };
        my $conn_id = 0 + $conn;

        logger->info("New connection $conn_id from $host:$port");

        $self->{conns}->{$conn_id} = $conn;

        frame_try {
            $self->_init_connection($conn_id);
        } frame_catch {
            logger->error("Connection $conn_id error: $@");
            $self->_remove_connection($conn_id);
        };
    });
}



sub _init_connection {
    my ($self, $id) = @_;

    $self->{conns}->{$id}->{handle} =
        AnyEvent::Handle->new(
            fh => $self->{conns}->{$id}->{fh},
            on_eof => fub {
                $self->_remove_connection($id);
            },
            on_error => fub {
                my ($handle, $fatal, $msg) = @_;
                die "disconnect: $id ($msg)";
            },
        );

    my $msg_handler; $msg_handler = fub {
        my ($handle, $response) = @_;

        eval {
            $response = sereal_decode($response);
        };

        die "unable to decode msg ($@)" if $@;

        $self->{conns}->{$id}->{handle}->push_read(packstring => "w", $msg_handler);

        $self->_handle_msg($id, $response);
    };

    $self->{conns}->{$id}->{handle}->push_read(packstring => "w", $msg_handler);
}


sub _remove_connection {
    my ($self, $conn_id) = @_;

    my $conn = $self->{conns}->{$conn_id} // die "no such conn to remove: $conn_id";

    $conn->{handle}->destroy if $conn->{handle};
    delete $conn->{handle};

    delete $self->{conns}->{$conn_id};
}


sub _handle_msg {
    my ($self, $id, $msg) = @_;

    my $timestamp = curr_time();

    my $c = $self->{conns}->{$id};

    if ($msg->{cmd} eq 'new-run') {
        my $run_id = get_session_token();

        my $logger = logger;
        $logger->info("New run: $run_id");
        $logger->debug(msg => $msg);

        my $event = {
            type => 'new-run',
            run_id => $run_id,
            info => $msg->{info},
            peer_host => $c->{peer_host},
        };

        my $txn = new_lmdb_txn();

        Vmprobe::DB::ActiveRun->new($txn)->insert($run_id, $timestamp);
        Vmprobe::DB::Event->new($txn)->insert($timestamp, $event);

        $txn->commit;
        switchboard->trigger("new-event");

        my $response = {
            cmd => 'start-run',
            req_id => $msg->{req_id},
            run_id => $run_id,
        };

        $c->{handle}->push_write(packstring => "w", sereal_encode($response));
    } elsif ($msg->{cmd} eq 'end-run') {
        my $logger = logger;
        $logger->info("End run: $msg->{run_id}");
        $logger->debug(msg => $msg);

        my $event = {
            type => 'end-run',
            run_id => $msg->{run_id},
            info => $msg->{info},
            peer_host => $c->{peer_host},
        };

        my $txn = new_lmdb_txn();

        my $active_run_db = Vmprobe::DB::ActiveRun->new($txn);

        die "trying to delete run $msg->{run_id} but doesn't exist in active runs table"
            if !defined $active_run_db->get($msg->{run_id});

        $active_run_db->delete($msg->{run_id});

        Vmprobe::DB::Event->new($txn)->insert($timestamp, $event);

        $txn->commit;
        switchboard->trigger("new-event");

        my $response = {
            cmd => 'ack',
            req_id => $msg->{req_id},
        };

        $c->{handle}->push_write(packstring => "w", sereal_encode($response));
    } else {
        die "unknown cmd: $msg->{cmd}";
    }
}




1;
