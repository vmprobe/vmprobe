package Vmprobe::Cmd::vmprobe::cache::evict;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;


our $spec = q{

doc: Evicts files out of memory.

};


sub validate {
    die "must specify vmprobe cache --path"
        if !exists opt('vmprobe::cache')->{path};
}


sub run {
    Vmprobe::Poller::poll({
        probe_name => 'cache::evict',
        args => {
            path => opt('vmprobe::cache')->{path},
        },
    });

    Vmprobe::Poller::wait;
}




1;
