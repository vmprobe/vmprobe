package Vmprobe::Probe::cache::summary;

use common::sense;

use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    my $sparse = $params->{sparse} ? 1 : 0;

    my $snapshot = Vmprobe::Cache::Snapshot::take($params->{path}, $sparse);

    my $summary = Vmprobe::Cache::Snapshot::summarize($snapshot, $params->{buckets});

    return { summary => $summary };
}

1;
