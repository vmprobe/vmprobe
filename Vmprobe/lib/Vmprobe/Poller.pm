package Vmprobe::Poller;

use common::sense;

use Callback::Frame;

use Vmprobe::Remote;
use Vmprobe::Util;


our $poll_cv;

sub wait {
    return if !defined $poll_cv;

    ## If there are no waiters, just return right away
    $poll_cv->begin;
    $poll_cv->end;

    $poll_cv->wait;

    undef $poll_cv;
}

my $remotes_cache = {};

sub poll {
    my $params = shift;

    $poll_cv //= AE::cv;

    my $remotes_param = $params->{remotes};

    if (exists $params->{remote}) {
        die "poll can take either remote or remotes paramaters, not both"
            if exists $params->{remotes};

        $remotes_param = $params->{remote};
    }

    $remotes_param = [] if !defined $remotes_param;
    $remotes_param = [ $remotes_param ] if ref $remotes_param ne 'ARRAY';

    my @remotes;

    foreach my $remote (@{ $remotes_param }) {
        if (ref $remote) {
            push @remotes, $remote;
        } else {
            if ($remotes_cache->{$remote}) {
                push @remotes, $remotes_cache->{$remote};
            } else {
                $remotes_cache->{$remote} = Vmprobe::Remote->new( host => $remote );
                push @remotes, $remotes_cache->{$remote};
            }
        }
    }

    foreach my $remote (@remotes) {
        my $result = {};

        $poll_cv->begin;

        frame_try {
            $remote->probe($params->{probe_name}, $params->{args}, fub {
                my $result = shift;

                $params->{cb}->($remote, $result)
                    if $params->{cb};

                $poll_cv->end;
            });
        } frame_catch {
            my $error = $@;
            chomp $error;

            if ($params->{on_error}) {
                $params->{on_error}->($remote, $error)
            } else {
                say "$remote->{host} threw exception: ", colour($error, 'red');
            }

            $poll_cv->end;
        };
    }
}



1;
