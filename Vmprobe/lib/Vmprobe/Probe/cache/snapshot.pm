package Vmprobe::Probe::cache::snapshot;

use common::sense;

use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    my $snapshot = Vmprobe::Cache::Snapshot::take($params->{path});

    return { snapshot => $snapshot };
}

1;
