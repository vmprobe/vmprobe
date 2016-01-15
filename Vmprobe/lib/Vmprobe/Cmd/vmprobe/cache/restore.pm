package Vmprobe::Cmd::vmprobe::cache::restore;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::Poller;

use Sereal::Decoder;


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
    my $snapshot = Sereal::Decoder::decode_sereal($encoded_snapshot);

    my @snapshot_hosts = keys %$snapshot;
    die "expected only one host in snapshot, found " . scalar(@snapshot_hosts) . " (" . join(', ', @snapshot_hosts) . ")"
        if @snapshot_hosts != 1;

    my $snapshot_paths = $snapshot->{$snapshot_hosts[0]};

    ## Apply snapshot

    foreach my $path (keys %$snapshot_paths) {
        Vmprobe::Poller::poll({
            remotes => opt('vmprobe')->{remote},
            probe_name => 'cache::restore',
            args => {
                 snapshot => $snapshot_paths->{$path}->{snapshot},
            },
        });
    }

    Vmprobe::Poller::wait;
}




1;
