package Vmprobe::Probe::exec;

use common::sense;
use AnyEvent;

use Vmprobe::Probe;

sub run {
    my $params = shift;

    my $cv = AnyEvent::Util::run_cmd(
                 $params->{cmd},
                 '<', '/dev/null',
                 '>', \my $stdout,
                 '2>', \my $stderr);

    my $ret = $cv->recv;

    return {
        stdout => $stdout,
        stderr => $stderr,
        ret => $ret,
    };
}

1;
