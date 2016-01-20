package Vmprobe::Cmd::vmprobe::cache::touch;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;


our $spec = q{

doc: Loads files from disk into memory.

};


sub run {
    Vmprobe::Poller::poll({
        remotes => opt('vmprobe')->{remote},
        probe_name => 'cache::touch',
        args => {
            path => opt('vmprobe::cache')->{path},
        },
    });

    Vmprobe::Poller::wait;
}




1;
