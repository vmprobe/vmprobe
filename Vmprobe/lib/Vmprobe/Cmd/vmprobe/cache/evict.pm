package Vmprobe::Cmd::vmprobe::cache::evict;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;


our $spec = q{

doc: Evicts files out of memory.

};


sub run {
    foreach my $path (@{ opt('vmprobe::cache')->{path} }) {
        Vmprobe::Poller::poll({
            remotes => opt('vmprobe')->{remote},
            probe_name => 'cache::evict',
            args => {
                path => $path,
            },
        });
    }

    Vmprobe::Poller::wait;
}




1;
