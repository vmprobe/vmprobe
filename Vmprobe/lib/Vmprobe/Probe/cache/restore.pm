package Vmprobe::Probe::cache::restore;

use common::sense;

use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    my $snapshot = Vmprobe::Cache::Snapshot::restore($params->{snapshot});

    return {};
}

1;
