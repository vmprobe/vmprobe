package Vmprobe::Raw::cache::snapshot;

use common::sense;

use Vmprobe::Cache;
use Vmprobe::Cache::Snapshot;

sub run {
    my ($params) = @_;

    die "need path" if !defined $params->{path};

    return Vmprobe::Cache::Snapshot::take($params->{path}, $params->{flags} // ['mincore']);
}


=pod
    die "can't specify both save and diff" if defined $params->{save} && defined $params->{diff};

    my $snapshot = Vmprobe::Cache::Snapshot::take($params->{path});

    if (defined $params->{save}) {
        $Vmprobe::Cache::snapshots->{$params->{save}} = $snapshot;
    }

    if (defined $params->{diff}) {
        my $before = $Vmprobe::Cache::snapshots->{$params->{diff}};
        die "unknown snapshot id: $params->{diff}" if !defined $before;

        my $delta = Vmprobe::Cache::Snapshot::delta($before, $snapshot);

        $Vmprobe::Cache::snapshots->{$params->{diff}} = $snapshot;

        return { delta => $delta };
    }

    return { snapshot => $snapshot };
}
=cut

1;
