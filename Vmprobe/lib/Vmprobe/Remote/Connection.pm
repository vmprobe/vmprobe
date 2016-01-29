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
    $self->{cmd} = $args{cmd};

    ## Internals

    $self->{host} = $self->{remote_obj}->{host};
    $self->{pending_probes} = [];


    $self->_open_handle;
    $self->_drain_probes;

    return $self;
}



sub _open_handle {
    my ($self) = @_;

    my ($fh1, $fh2) = AnyEvent::Util::portable_socketpair;

    my $ssh_stderr = '';

    $self->{cmd_cv} = AnyEvent::Util::run_cmd($self->{cmd},
                          '<' => $fh1,
                          '>' => $fh1,
                          '2>' => sub {
                                      my $data = shift;
                                      return if !defined $data;
                                      $ssh_stderr .= $data;
                                      say STDERR "stderr from raw process: $data";
                                  },
                          close_all => 1,
                          '$$' => \my $pid,
                      );

    $self->{cmd_cv}->cb(sub {
        my $rc = shift;
        delete $self->{cmd_cv};

        my $err_msg = "connecting process died: $ssh_stderr";
        $self->{remote_obj}->error_message($err_msg);
        $self->_teardown($err_msg);
    });

    close($fh1);

    $self->{handle} = AnyEvent::Handle->new(
                          fh => $fh2,
                          on_error => sub {
                              my ($handle, $fatal, $msg) = @_;
                              my $err_msg = "connection lost: $msg";
                              $self->{remote_obj}->error_message($err_msg);
                              $self->_teardown($err_msg);
                          });
}


sub queue_probe {
    my ($self, $probe) = @_;

    unshift @{ $self->{pending_probes} }, $probe;

    $self->_drain_probes;
}


sub _teardown {
    my ($self, $err_msg) = @_;

    warn "connection already torn down" if $self->{zombie};
    $self->{zombie} = 1;

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

    $self->{remote_obj}->_connection_is_disconnected($self);

    delete $self->{remote_obj};
}


sub _drain_probes {
    my ($self) = @_;

    return if $self->{zombie};
    return if exists $self->{probe_in_progress};

    if (!@{ $self->{pending_probes} }) {
        $self->{remote_obj}->_connection_is_idle($self);
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
