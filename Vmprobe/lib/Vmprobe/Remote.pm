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

    frame_try {
        $self->probe('version', {}, sub {
            my ($version) = @_;
            $self->add_version_info($version);
        });
    } frame_catch {
        say STDERR "error refreshing version info: $@";
    };
}



sub _init_connection {
    my ($self) = @_;

    return if $self->{connection_inited};
    $self->{connection_inited} = 1;

    my $vmprobe_binary;

    $vmprobe_binary //= $Vmprobe::Remote::global_params->{vmprobe_binary};
    $vmprobe_binary //= $0 if $self->{host} eq 'localhost';
    $vmprobe_binary //= 'vmprobe';

    my $cmd = [ $vmprobe_binary, 'raw', ];

    unshift @$cmd, qw(sudo -p -n --)
        if $Vmprobe::Remote::global_params->{sudo};

    if ($self->{host} eq 'localhost') {
        $self->_cmd_ready($cmd);
    } else {
        require Net::OpenSSH;

$Net::OpenSSH::debug = ~0;
        $self->{master_pipe} = Vmprobe::Util::capture_stderr {
            $self->{ssh} = Net::OpenSSH->new($self->{host}, key_path => $Vmprobe::Remote::global_params->{ssh_private_key}, async => 1);
        };

        $self->{master_pipe_output} = '';

        $self->{master_stderr_watcher} = AE::io $self->{master_pipe}, 0, sub {
            my $rc = sysread($self->{master_pipe}, $self->{master_pipe_output}, 16384, length($self->{master_pipe_output}));
            return if $rc || $! == Errno::EINTR;
            delete $self->{master_stderr_watcher};
            close($self->{master_pipe});
        };

        ## FIXME: use inotify etc
        $self->{ssh_timer} = AE::timer 0.1, 0.1, sub {
            if ($self->{ssh}->error) {
                delete $self->{ssh_timer};
                my $err_msg = "ssh failed: " . ($self->{master_pipe_output} || $self->{ssh}->error);
                $self->error_message($err_msg);
                $self->_teardown_ssh_master($err_msg);
            }

            if ($self->{ssh}->wait_for_master(1)) {
                delete $self->{ssh_timer};
                $self->_cmd_ready([ $self->{ssh}->make_remote_command({ tty => 1 }, @$cmd) ]);
            }
        };
    }
}


sub _cmd_ready {
    my ($self, $cmd) = @_;

    $self->{connection_cmd} = $cmd;

    foreach my $connection (values %{ $self->{connections} }) {
        $connection->cmd_ready;
    }

    $self->_drain_probes;

    $self->{on_state_change}->($self);
}



sub probe {
    my ($self, $probe_name, $args, $cb, $connection_id) = @_;

    $self->_init_connection;

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

    return if $self->{zombie};
    return if !$self->{connection_cmd};
    return if !@{ $self->{pending_probes} };

    if (!@{ $self->{idle_connections} }) {
my $z = keys(%{ $self->{connections} }); say "CURR CONNS: $z";
        return if keys(%{ $self->{connections} }) >= $self->{max_connections};
        return if exists $self->{reconnection_timer};

        $self->add_connection;
        return;
    }

    my $connection = pop @{ $self->{idle_connections} };

    $connection->queue_probe(pop @{ $self->{pending_probes} });

    $self->_drain_probes;
}



sub add_connection {
    my ($self) = @_;

    my $connection_id = get_session_token();

    my $connection = Vmprobe::Remote::Connection->new(remote_obj => $self, connection_id => $connection_id);

    $self->{connections}->{$connection_id} = $connection;

    $connection->cmd_ready() if $self->{connection_cmd};

    $self->{on_state_change}->($self);
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

    $err_msg //= 'shutdown';

    foreach my $connection (values %{ $self->{connections} }) {
        $connection->_teardown($err_msg);
    }

    $self->{connections} = {};
    $self->{idle_connections} = [];

    delete $self->{connection_inited};
    delete $self->{connection_cmd};

    delete $self->{ssh_timer};
    delete $self->{master_pipe};
    delete $self->{master_stderr_watcher};
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

    if (keys %{ $self->{connections} } == 0) {
        $self->_teardown_ssh_master;

        if (!$self->{zombie}) {
            $self->{reconnection_timer} //= AE::timer 4, 0, sub {
                delete $self->{reconnection_timer};
                $self->refresh_version_info;
            };
        }

        # Host might have been restarted/upgraded
        delete $self->{version_info};
    }

    $self->{on_state_change}->($self);
}




1;
