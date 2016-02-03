package Vmprobe::Remote;

use common::sense;

use AnyEvent;
use AnyEvent::Util;
use AnyEvent::Handle;
use Scalar::Util;
use Callback::Frame;

use Vmprobe::Remote::Connection;
use Vmprobe::Util;


our $global_params = {};



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    ## Args

    $self->{host} = $args{host};
    $self->{on_state_change} = $args{on_state_change} // sub {};
    $self->{max_connections} = $args{max_connections} // 3;
    $self->{reconnection_interval} = $args{reconnection_interval} // 5;
    $self->{collect_version_info} = $args{collect_version_info} // 1;

    ## Internals

    $self->{num_connections} = 0;
    $self->{state} = 'disconnected'; ## disconnected, ssh_wait, ok

    $self->{pending_probes} = [];
    $self->{connections} = {};
    $self->{idle_connections} = [];

    {
        local $self->{on_state_change} = sub {};
        $self->_init;
    }

    return $self;
}



sub set_state {
    my ($self, $new_state) = @_;

    $self->{state} = $new_state;
    $self->{on_state_change}->($self);
}

sub get_state {
    my ($self) = @_;

    return 'fail' if $self->{state} eq 'disconnected' && $self->{last_error_message};

    return $self->{state};
}


sub get_num_connections {
    my ($self) = @_;

    return $self->{num_connections};
}


sub error_message {
    my ($self, $err_msg) = @_;

    say STDERR "$self->{host} error: $err_msg";

    $self->{last_error_message} = $err_msg;
    $self->{on_state_change}->($self);
}


sub add_version_info {
    my ($self, $version_info) = @_;

    $self->{version_info} = $version_info;
    $self->{on_state_change}->($self);
}

sub refresh_version_info {
    my ($self) = @_;

    frame_try {
        $self->probe('version', {}, sub {
            my ($version) = @_;
            $self->add_version_info($version);
        });
    } frame_catch {
        say STDERR "error refreshing version info: $@";
    };
}


sub _init {
    my ($self) = @_;

    $self->_connect_ssh;
    $self->refresh_version_info if $self->{collect_version_info};
}

sub _connect_ssh {
    my ($self) = @_;

    return if $self->{state} ne 'disconnected';

    if ($self->{host} eq 'localhost') {
        $self->set_state('ok');
        $self->_drain_probes;
        return;
    }

    require Net::OpenSSH;

    $self->set_state('ssh_wait');

    $self->{ssh_master_pipe} = Vmprobe::Util::capture_stderr {
        $self->{ssh} = Net::OpenSSH->new($self->{host}, key_path => $Vmprobe::Remote::global_params->{ssh_private_key}, async => 1);
    };

    $self->{ssh_master_pipe_output} = '';

    $self->{ssh_master_stderr_watcher} = AE::io $self->{ssh_master_pipe}, 0, sub {
        my $rc = sysread($self->{ssh_master_pipe}, $self->{ssh_master_pipe_output}, 16384, length($self->{ssh_master_pipe_output}));
        return if $rc || $! == Errno::EINTR;
        delete $self->{ssh_master_stderr_watcher};
        close($self->{ssh_master_pipe});

        my $err_msg = "ssh control master exited: $self->{ssh_master_pipe_output}";
        $self->error_message($err_msg);
        $self->_teardown_ssh_master($err_msg);
    };

    ## FIXME: use inotify etc
    $self->{ssh_timer} = AE::timer 0.1, 0.1, sub {
        if ($self->{ssh}->error) {
            delete $self->{ssh_timer};
            my $err_msg = "ssh failed: " . ($self->{ssh_master_pipe_output} || $self->{ssh}->error);
            $self->error_message($err_msg);
            $self->_teardown_ssh_master($err_msg);
        } elsif ($self->{ssh}->wait_for_master(1)) {
            delete $self->{ssh_timer};
            $self->set_state('ok');
            $self->_drain_probes;
        }
    };
}


sub _get_handle_cmd {
    my ($self) = @_;

    die "not in state ok" if $self->{state} ne 'ok';

    my $vmprobe_binary;

    $vmprobe_binary //= $Vmprobe::Remote::global_params->{vmprobe_binary};
    $vmprobe_binary //= $0 if $self->{host} eq 'localhost';
    $vmprobe_binary //= 'vmprobe';

    my $cmd = [ $vmprobe_binary, 'raw', ];

    unshift @$cmd, qw(sudo -p -n --)
        if $Vmprobe::Remote::global_params->{sudo};

    if ($self->{host} eq 'localhost') {
        return $cmd;
    }

    die "no ssh object" if !$self->{ssh};

    return [ $self->{ssh}->make_remote_command(@$cmd) ];
}


sub _add_connection {
    my ($self) = @_;

    my $connection_id = get_session_token();

    my $cmd = $self->_get_handle_cmd;

    my $connection = Vmprobe::Remote::Connection->new(
                         remote_obj => $self,
                         connection_id => $connection_id,
                         cmd => $cmd,
                     );

    $self->{connections}->{$connection_id} = $connection;

    $self->{num_connections}++;

    $self->{on_state_change}->($self);
}



sub probe {
    my ($self, $probe_name, $args, $cb, $connection_id) = @_;

    if (!Callback::Frame::is_frame($cb)) {
        $cb = frame(code => $cb);
    }

    my $msg = sereal_encode({
                  probe => $probe_name,
                  args => $args,
              });

    my $probe = {
        cb => $cb,
        msg => $msg,
    };

    if (defined $connection_id) {
        my $connection = $self->{connections}->{$connection_id};

        if ($connection) {
            $connection->queue_probe($probe);
        } else {
            frame(existing_frame => $probe->{cb}, code => sub {
                die "connection $connection_id no longer established";
            })->();
        }
    } else {
        unshift @{ $self->{pending_probes} }, $probe;
        $self->_drain_probes;
    }
}


sub _drain_probes {
    my ($self) = @_;

    while(1) {
        return if $self->{zombie};
        return if $self->{state} ne 'ok';
        return if !@{ $self->{pending_probes} };

        if (!@{ $self->{idle_connections} }) {
            return if $self->{num_connections} >= $self->{max_connections};
            return if exists $self->{reconnection_timer};

            $self->_add_connection;
            return;
        }

        my $connection = pop @{ $self->{idle_connections} };

        $connection->queue_probe(pop @{ $self->{pending_probes} });
    }
}





sub shutdown {
    my ($self) = @_;

    warn "remote already shutdown" if $self->{zombie};
    $self->{zombie} = 1;

    ## Resources just remove the reference to the remote so don't bother sending state change info as we shutdown
    $self->{on_state_change} = sub {};

    delete $self->{reconnection_timer};

    $self->_teardown_ssh_master;
}

sub _teardown_ssh_master {
    my ($self, $err_msg) = @_;

    $self->set_state('disconnected');

    $err_msg //= 'shutdown';

    foreach my $connection (values %{ $self->{connections} }) {
        $connection->_teardown($err_msg);
    }

    $self->{num_connections} = 0;
    $self->{connections} = {};
    $self->{idle_connections} = [];

    delete $self->{ssh_timer};
    delete $self->{ssh_master_pipe};
    delete $self->{ssh_master_stderr_watcher};
    my $ssh = delete $self->{ssh};

    if ($ssh) {
        $ssh->disconnect(1);
        my $ssh_timer; $ssh_timer = AE::timer 0.1, 0.1, sub {
            my $res = $ssh->wait_for_master(1);

            if (defined $res && !$res) {
                undef $ssh_timer;
                undef $ssh;
            }
        };
    }

    if (!$self->{zombie}) {
        $self->{reconnection_timer} //= AE::timer $self->{reconnection_interval}, 0, sub {
            delete $self->{reconnection_timer};
            $self->_init;
        };

        # Host might have been restarted/upgraded
        delete $self->{version_info};
    }
}



sub _connection_is_idle {
    my ($self, $connection) = @_;

    push @{ $self->{idle_connections} }, $connection;

    $self->_drain_probes;
}


sub _connection_is_disconnected {
    my ($self, $connection) = @_;

    delete $self->{connections}->{$connection->{connection_id}};
    $self->{idle_connections} = [ grep { $_ != $connection } @{ $self->{idle_connections} } ];
    $self->{num_connections}--;

    $self->{on_state_change}->($self);
}




1;
