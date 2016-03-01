package Vmprobe::Probe::cache::restore;

use common::sense;

use Vmprobe::Cache;
use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    die "need path" if !defined $params->{path};
    die "can't specify both save and diff" if defined $params->{save} && defined $params->{diff};

    if (defined $params->{diff}) {
        die "need delta" if !defined $params->{delta};

        my $before = $Vmprobe::Cache::snapshots->{$params->{diff}};
        die "unknown snapshot id: $params->{diff}" if !defined $before;

        $Vmprobe::Cache::snapshots->{$params->{diff}} = Vmprobe::Cache::Snapshot::delta($before, $params->{delta});

        Vmprobe::Cache::Snapshot::restore($params->{path}, $Vmprobe::Cache::snapshots->{$params->{diff}});
    } else {
        die "need snapshot" if !defined $params->{snapshot};

        if (defined $params->{save}) {
            $Vmprobe::Cache::snapshots->{$params->{save}} = $params->{snapshot};
        }

        Vmprobe::Cache::Snapshot::restore($params->{path}, $params->{snapshot});
    }

    return {};
}

1;
