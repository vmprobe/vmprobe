package Vmprobe::Cmd::vmprobe::ping;

use common::sense;

use Time::HiRes;

use Vmprobe::Cmd;
use Vmprobe::Poller;
use Vmprobe::Util;


our $spec = q{

doc: Establishes a vmprobe connection to each remote and measures the communication latency for each connection.

};


sub run {
    my $time0 = Time::HiRes::time();

    Vmprobe::Poller::poll({
        probe_name => 'timestamp',
        args => {},
        cb => sub {
            my ($remote, $result) = @_;

            my $time1 = Time::HiRes::time();

            Vmprobe::Poller::poll({
                remote => $remote,
                probe_name => 'timestamp',
                args => {},
                cb => sub {
                    my ($remote, $result) = @_;

                    my $time2 = Time::HiRes::time();

                    my $connection_time = Vmprobe::Util::format_time($time1 - $time0);
                    my $ping_time = Vmprobe::Util::format_time($time2 - $time1);

                    say "$remote->{host} connection=$connection_time ping=$ping_time";
                },
            });
        },
    });

    Vmprobe::Poller::wait();
}


1;
