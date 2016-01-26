package Vmprobe::Remote;

use common::sense;

use AnyEvent;
use AnyEvent::Util;
use AnyEvent::Handle;
use Scalar::Util;
use Callback::Frame;

use Sereal::Decoder;
use Sereal::Encoder;

use Vmprobe::Util;


my $decoder = Sereal::Decoder->new;
my $encoder = Sereal::Encoder->new;


our $global_params = {};



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{host} = $args{host};

    $self->{state} = 'connecting';
    $self->{on_state_change} = $args{on_state_change} || sub {};
    $self->{on_error_message} = $args{on_error_message} || sub {};

    return $self;
}


sub state_change {
    my ($self, $new_state) = @_;

    $self->{state} = $new_state;
    $self->{on_state_change}->($self);
}

sub add_version_info {
    my ($self, $version_info) = @_;

    $self->{version_info} = $version_info;
    $self->{on_state_change}->($self);
}

sub error_message {
    my ($self, $message) = @_;

    $self->{last_error_message} = $message;
    $self->{on_error_message}->($self, $message);
}

sub teardown_handle {
    my ($self, $err_msg) = @_;

    $self->error_message($err_msg);
    $self->state_change('fail');

    say STDERR $err_msg;

    if ($self->{handle}) {
        $self->{handle}->destroy;
        delete $self->{handle};
    }

    delete $self->{pending_handle_cbs};

    foreach my $cb (values %{ $self->{cbs_in_flight} }) {
        frame(existing_frame => $cb, code => sub {
            die "connection error: $err_msg";
        })->();
    }

    delete $self->{cbs_in_flight};
}


sub _populate_handle {
    my ($self, $cb) = @_;

    if ($self->{handle}) {
        $cb->();
        return;
    }

    push @{ $self->{pending_handle_cbs} }, $cb;

    return if @{ $self->{pending_handle_cbs} } > 1;

    my $vmprobe_binary;

    $vmprobe_binary //= $global_params->{vmprobe_binary};
    $vmprobe_binary //= $0 if $self->{host} eq 'localhost';
    $vmprobe_binary //= 'vmprobe';

    my $cmd = [ $vmprobe_binary, 'raw', ];

    unshift @$cmd, qw(sudo -p -n --)
        if $global_params->{sudo};

    if ($self->{host} eq 'localhost') {
        $self->_start_cmd($cmd);
        $self->state_change('ok');
        my $cbs = $self->{pending_handle_cbs};
        delete $self->{pending_handle_cbs};
        foreach my $cb (@$cbs) {
          $cb->();
        }
    } else {
        require Net::OpenSSH;

        my $master_pipe = Vmprobe::Util::capture_stderr {
            $self->{ssh} = Net::OpenSSH->new($self->{host}, key_path => $global_params->{ssh_private_key}, async => 1);
        };

        my $master_pipe_output = '';

        $self->{master_stderr_watcher} = AE::io $master_pipe, 0, sub {
            my $rc = sysread($master_pipe, $master_pipe_output, 16384, length($master_pipe_output));
            return if $rc || $! == Errno::EINTR;
            delete $self->{master_stderr_watcher};
        };

        ## FIXME: use inotify etc
        $self->{ssh_timer} = AE::timer 0.1, 0.1, sub {
            if ($self->{ssh}->error) {
                delete $self->{ssh_timer};
                $self->teardown_handle("ssh failed: " . ($master_pipe_output || $self->{ssh}->error));
            }

            if ($self->{ssh}->wait_for_master(1)) {
                delete $self->{ssh_timer};
                $self->_start_cmd([ $self->{ssh}->make_remote_command({ tty => 1 }, @$cmd) ]);
                $self->state_change('ok');
                my $cbs = $self->{pending_handle_cbs};
                delete $self->{pending_handle_cbs};
                foreach my $cb (@$cbs) {
                  $cb->();
                }
            }
        };
    }
}

sub _start_cmd {
    my ($self, $cmd) = @_;

    $self->state_change('ssh_ok');

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

        $self->teardown_handle("connecting process died: $err_msg");
    });

    close($fh1);

    $self->{handle} = AnyEvent::Handle->new(
                          fh => $fh2,
                          on_error => sub {
                              my ($handle, $fatal, $msg) = @_;
                              $self->teardown_handle("connection lost: $err_msg");
                          });
}



sub probe {
    my ($self, $probe, $args, $cb) = @_;

    if (!Callback::Frame::is_frame($cb)) {
        $cb = frame(code => $cb);
    }

    $self->{cbs_in_flight}->{0 + $cb} = $cb;

    my $msg = $encoder->encode({
                probe => $probe,
                args => $args,
              });

    $self->_populate_handle(sub {
        $self->{handle}->push_write(packstring => "w", $msg);

        $self->{handle}->push_read(packstring => "w", sub {
            my ($handle, $response) = @_;

            delete $self->{cbs_in_flight}->{0 + $cb};

            eval {
                $response = $decoder->decode($response);
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
                $cb->($response->{result});
            }
        });
    });
}




1;
