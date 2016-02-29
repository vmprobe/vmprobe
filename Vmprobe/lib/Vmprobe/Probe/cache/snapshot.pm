package Vmprobe::Probe::cache::snapshot;

use common::sense;

use Vmprobe::Cache;
use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    die "need path" if !defined $params->{path};
    die "can't specify both save and delta" if defined $params->{save} && defined $params->{delta};

    my $snapshot = Vmprobe::Cache::Snapshot::take($params->{path});

    if (defined $params->{save}) {
        $Vmprobe::Cache::snapshots->{$params->{save}} = $snapshot;
    }

    if (defined $params->{delta}) {
        my $before = $Vmprobe::Cache::snapshots->{$params->{delta}};
        die "unknown snapshot id: $params->{delta}" if !defined $before;

        my $delta = Vmprobe::Cache::Snapshot::delta($before, $snapshot);

        $Vmprobe::Cache::snapshots->{$params->{delta}} = $snapshot;

        return { delta => $delta };
    }

    return { snapshot => $snapshot };
}

1;
