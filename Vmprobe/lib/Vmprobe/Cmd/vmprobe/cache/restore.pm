package Vmprobe::Cmd::vmprobe::cache::restore;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::Poller;


our $spec = q{

doc: Restore a snapshot of filesystem cache usage.

opt:
    input:
        type: Str
        alias: i
        doc: Filename to load the snapshot from. If omitted (or '-'), snapshot is read from stdin.

};



sub run {
    my $data = {};

    ## Load snapshot

    my $encoded_snapshot = Vmprobe::Util::load_file(opt->{input} // '-');
    my $snapshot = sereal_decode($encoded_snapshot);

    ## Apply snapshot

    Vmprobe::Poller::poll({
        probe_name => 'cache::restore',
        args => {
             snapshot => $snapshot->{snapshot},
        },
    });

    Vmprobe::Poller::wait;
}




1;
