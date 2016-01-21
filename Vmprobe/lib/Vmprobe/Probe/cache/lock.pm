package Vmprobe::Probe::cache::lock;

use common::sense;

use Vmprobe::Cache;

sub run {
    my ($params) = @_;

    if (exists $params->{start_pages}) {
        Vmprobe::Cache::lock_and_fork_page_range($params->{path}, $params->{start_pages}, $params->{start_pages} + $params->{num_pages});
    } else {
        Vmprobe::Cache::lock_and_fork($params->{path});
    }

    return {};
}

1;
