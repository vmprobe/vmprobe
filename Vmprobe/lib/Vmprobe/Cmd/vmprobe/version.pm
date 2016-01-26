package Vmprobe::Cmd::vmprobe::version;

use common::sense;

use Time::HiRes;

use Vmprobe::Cmd;
use Vmprobe::Poller;
use Vmprobe::Util;


our $spec = q{

doc: Gets the vmprobe version and basic platform information.

};


sub run {
    Vmprobe::Poller::poll({
        probe_name => 'version',
        args => {},
        cb => sub {
            my ($remote, $result) = @_;

            say "$remote->{host}";
            say "    vmprobe: $result->{vmprobe}";
            say "    os type: $result->{os_type}";
        },
    });

    Vmprobe::Poller::wait();
}


1;
