package Vmprobe::Probe::cache::unlock;

use common::sense;

use Vmprobe::Cache;

sub run {
    my ($params) = @_;

    if (!exists $Vmprobe::Cache::locks->{$params->{lock_id}}) {
        die "unknown lock_id: $params->{lock_id}";
    }

    delete $Vmprobe::Cache::locks->{$params->{lock_id}};

    return {};
}

1;
