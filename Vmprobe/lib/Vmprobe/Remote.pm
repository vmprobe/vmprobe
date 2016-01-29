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

    ## Internals

    $self->{pending_probes} = [];
    $self->{connections} = {};
    $self->{idle_connections} = [];

    return $self;
}


sub add_connection {
    my ($self) = @_;

    my $connection_id = get_session_token();

    my $connection = Vmprobe::Remote::Connection->new(remote_obj => $self, connection_id => $connection_id);

    $self->{connections}->{$connection_id} = $connection;

    $self->{on_state_change}->($self);
}



sub get_state {
    my ($self) = @_;

    if (scalar(keys(%{ $self->{connections} })) == 0) {
        return 'fail' if $self->{last_error_message};
    }

    return 'ok';
}

sub get_num_connections {
    my ($self) = @_;

    return scalar(keys(%{ $self->{connections} }));
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

    delete $self->{version_info};

    frame_try {
        $self->probe('version', {}, sub {
            my ($version) = @_;
            $self->add_version_info($version);
        });
    } frame_catch {
        say STDERR "error refreshing version info: $@";
    };
}


sub shutdown {
    my ($self) = @_;

    ## Resources just remove the reference to the remote so don't bother sending state change info as we shutdown
    $self->{on_state_change} = sub {};

    foreach my $connection (values %{ $self->{connections} }) {
        $connection->_teardown_handle;
    }

    delete $self->{reconnection_timer};
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




sub _is_idle {
    my ($self, $connection) = @_;

    push @{ $self->{idle_connections} }, $connection;

    $self->_drain_probes;
}


sub _is_disconnected {
    my ($self, $connection) = @_;

    delete $self->{connections}->{$connection->{connection_id}};
    $self->{idle_connections} = [ grep { $_ != $connection } @{ $self->{idle_connections} } ];

    if (keys %{ $self->{connections} } == 0) {
        $self->{reconnection_timer} //= AE::timer 4, 0, sub {
            delete $self->{reconnection_timer};
            $self->refresh_version_info;
        };

        # Host might have been restarted/upgraded
        delete $self->{version_info};
    }

    $self->{on_state_change}->($self);
}


sub _drain_probes {
    my ($self) = @_;

    return if !@{ $self->{pending_probes} };

    if (!@{ $self->{idle_connections} }) {
        return if keys(%{ $self->{connections} }) >= $self->{max_connections};
        return if exists $self->{reconnection_timer};

        $self->add_connection;
        return;
    }

    my $connection = pop @{ $self->{idle_connections} };

    $connection->queue_probe(pop @{ $self->{pending_probes} });

    $self->_drain_probes;
}


1;
