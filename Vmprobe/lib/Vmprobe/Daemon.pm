package Vmprobe::Daemon;

use common::sense;

use Log::Defer;
use Log::File::Rolling;

use Vmprobe::RunContext;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{run_ctx} = Vmprobe::RunContext->new;

    $self->_listen_on_unix_socket;

    return $self;
}



sub _open_logger {
    my ($self) = @_;

    my $log_dir = $self->{run_ctx}->{var_dir} . "/logs";

    if (!-e $log_dir) {
        mkdir($log_dir) || die "couldn't mkdir($log_dir): $!";
    }

    $self->{logger} = Log::File::Rolling->new(
                          filename => "$log_dir/daemon.%Y-%m-%dT%H.log",
                          current_symlink => "$log_dir/daemon.log.current",
                          timezone => 'localtime',
                      ) || die "Error creating Log::File::Rolling logger: $!";
}



sub json_clean {
    my $x = shift;

    if (ref $x) {
        if (ref $x eq 'ARRAY') {
            $x->[$_] = json_clean($x->[$_]) for 0 .. @$x-1;
        } elsif (ref $x eq 'HASH') {
            $x->{$_} = json_clean($x->{$_}) for keys %$x;
        } else {
            $x = "Unable to JSON encode: " . Dumper($x);
        }
    }

    return $x;
}

sub get_logger {
    my ($self) = @_;

    return Log::Defer->new({ cb => sub {
        my $msg = shift;

        if (!$self->{daemonized}) {
            state $pretty_json = JSON::XS->new->canonical(1)->pretty(1);
            say $pretty_json->encode($msg);
        }

        my $encoded_msg;
        eval {
            $encoded_msg = encode_json($msg)
        };

        if ($@) {
            eval {
                $encoded_msg = encode_json(json_clean($msg));
            };

            if ($@) {
                $encoded_msg = "Failed to JSON clean: " . Dumper($msg);
            }
        }

        $self->{logger}->log("$encoded_msg\n");
    }});
}


sub _listen_on_unix_socket {
    my ($self, $cb) = @_;

    $self->{socket_path} = "$self->{run_ctx}->{var_dir}/daemon.socket";

    require AnyEvent::Socket;
    require AnyEvent::Handle;

    AnyEvent::Socket::tcp_server("unix/", "$self->{run_ctx}->{var_dir}/daemon.socket", sub {
        my ($fh) = @_;
    });
}


sub daemonize {
    my ($self) = @_;

    my $ret = fork();

    die "unable to fork while daemonizing: $!"
        if !defined $ret;

    exit if $ret;

    require POSIX;
    POSIX::setsid();

    open(STDIN, '<', '/dev/null');
    open(STDOUT, '>', '/dev/null');
    open(STDERR, '>', '/dev/null');

    chdir("/");

    $self->{daemonized} = 1;
}



=pod
sub _write_pid_file {
    my ($self) = @_;

    my $pid_filename = "$self->{var_dir}/daemon.pid";

    open(my $fh, '>>', $pid_filename) || die "couldn't open $pid_filename for writing: $!";
    seek($fh, 0, 0);

    require Fcntl;

    if (!flock($fh, Fcntl::LOCK_EX|Fcntl::LOCK_NB)) {
        die "daemon already running, pid: " . <$fh>;
    }

    truncate($fh, 0) || "unable to truncate $pid_filename: $!";

    print $fh "$$\n";
    $fh->flush;

    $self->{pid_fh} = $fh;
}
=cut


1;
