package Vmprobe::Probe::cache::restore;

use common::sense;

use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    die "need path" if !defined $params->{path};
    die "need snapshot" if !defined $params->{snapshot};

    my $snapshot = Vmprobe::Cache::Snapshot::restore($params->{path}, $params->{snapshot});

    return {};
}

1;
