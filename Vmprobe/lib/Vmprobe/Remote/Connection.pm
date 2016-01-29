package Vmprobe::Remote::Connection;

use common::sense;

use AnyEvent;
use Callback::Frame;

use Vmprobe::Util;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    ## Args

    $self->{remote_obj} = $args{remote_obj};
    $self->{connection_id} = $args{connection_id};

    ## Internals

    $self->{host} = $self->{remote_obj}->{host};
    $self->{pending_probes} = [];


    $self->_populate_handle;

    return $self;
}

sub _populate_handle {
    my ($self) = @_;

    my $vmprobe_binary;

    $vmprobe_binary //= $Vmprobe::Remote::global_params->{vmprobe_binary};
    $vmprobe_binary //= $0 if $self->{host} eq 'localhost';
    $vmprobe_binary //= 'vmprobe';

    my $cmd = [ $vmprobe_binary, 'raw', ];

    unshift @$cmd, qw(sudo -p -n --)
        if $Vmprobe::Remote::global_params->{sudo};

    if ($self->{host} eq 'localhost') {
        $self->_start_cmd($cmd);
    } else {
        require Net::OpenSSH;

        $self->{master_pipe} = Vmprobe::Util::capture_stderr {
            $self->{ssh} = Net::OpenSSH->new($self->{host}, key_path => $Vmprobe::Remote::global_params->{ssh_private_key}, async => 1);
        };

        $self->{master_pipe_output} = '';

        $self->{master_stderr_watcher} = AE::io $self->{master_pipe}, 0, sub {
            my $rc = sysread($self->{master_pipe}, $self->{master_pipe_output}, 16384, length($self->{master_pipe_output}));
            return if $rc || $! == Errno::EINTR;
            delete $self->{master_stderr_watcher};
        };

        ## FIXME: use inotify etc
        $self->{ssh_timer} = AE::timer 0.1, 0.1, sub {
            if ($self->{ssh}->error) {
                delete $self->{ssh_timer};
                $self->_teardown_handle("ssh failed: " . ($self->{master_pipe_output} || $self->{ssh}->error));
            }

            if ($self->{ssh}->wait_for_master(1)) {
                delete $self->{ssh_timer};
                $self->_start_cmd([ $self->{ssh}->make_remote_command({ tty => 1 }, @$cmd) ]);
            }
        };
    }
}

sub _start_cmd {
    my ($self, $cmd) = @_;

    my ($fh1, $fh2) = AnyEvent::Util::portable_socketpair;

    $self->{cmd_cv} = AnyEvent::Util::run_cmd($cmd,
                          '<' => $fh1,
                          '>' => $fh1,
                          '2>' => \my $err_msg,
                          close_all => 1,
                          '$$' => \my $pid,
                      );

    $self->{cmd_cv}->cb(sub {
        my $rc = shift;
        delete $self->{cmd_cv};

        $self->_teardown_handle("connecting process died: $err_msg");
    });

    close($fh1);

    $self->{handle} = AnyEvent::Handle->new(
                          fh => $fh2,
                          on_error => sub {
                              my ($handle, $fatal, $msg) = @_;
                              $self->_teardown_handle("connection lost: $err_msg");
                          });

    $self->_drain_probes;
}


sub queue_probe {
    my ($self, $probe) = @_;

    unshift @{ $self->{pending_probes} }, $probe;

    $self->_drain_probes;
}


sub _teardown_handle {
    my ($self, $err_msg) = @_;

    warn "connection already torn down" if $self->{zombie};
    $self->{zombie} = 1;

    $self->{remote_obj}->error_message($err_msg);

    if ($self->{handle}) {
        $self->{handle}->destroy;
        delete $self->{handle};
    }

    if (exists $self->{probe_in_progress}) {
        unshift @{ $self->{pending_probes} }, $self->{probe_in_progress};
        delete $self->{probe_in_progress};
    }

    foreach my $probe (@{ $self->{pending_probes} }) {
        frame(existing_frame => $probe->{cb}, code => sub {
            die "remote communication error: $err_msg";
        })->();
    }

    $self->{pending_probes} = [];

    if ($self->{cmd_cv}) {
        $self->{cmd_cv}->cb(sub {});
        delete $self->{cmd_cv};
    }

    if ($self->{ssh}) {
        $self->{ssh}->disconnect(1);
        $self->{ssh_timer} = AE::timer 0.1, 0.1, sub {
            if ($self->{ssh}->error || $self->{ssh}->wait_for_master(1)) {
                if ($self->{ssh}->error) {
                    warn "Error from ssh master while shutting down: " . ($self->{master_pipe_output} || $self->{ssh}->error);
                }

                delete $self->{master_pipe};
                delete $self->{ssh_timer};
                delete $self->{ssh};
                delete $self->{master_stderr_watcher};
            }
        };
    }

    $self->{remote_obj}->_is_disconnected($self);
}


sub _drain_probes {
    my ($self) = @_;

    return if !$self->{handle};
    return if exists $self->{probe_in_progress};

    if (!@{ $self->{pending_probes} }) {
        $self->{remote_obj}->_is_idle($self);
        return;
    }

    $self->{probe_in_progress} = pop @{ $self->{pending_probes} };

    $self->{handle}->push_write(packstring => "w", $self->{probe_in_progress}->{msg});

    $self->{handle}->push_read(packstring => "w", sub {
        my ($handle, $response) = @_;

        my $cb = $self->{probe_in_progress}->{cb};

        delete $self->{probe_in_progress};
        $self->_drain_probes;

        eval {
            $response = sereal_decode($response);
        };

        if ($@) {
            frame(existing_frame => $cb, code => sub {
                die "error deserializing msg: $@";
            })->();
        }

        if (exists $response->{error}) {
            frame(existing_frame => $cb, code => sub {
                die $response->{error};
            })->();
        } else {
            $cb->($response->{result}, $self->{connection_id});
        }
    });
}


1;
