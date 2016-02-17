package Vmprobe::Probe::cache::snapshot;

use common::sense;

use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    my $sparse = $params->{sparse} ? 1 : 0;

    my $snapshot = Vmprobe::Cache::Snapshot::take($params->{path}, $sparse);

    return { snapshot => $snapshot };
}

1;
