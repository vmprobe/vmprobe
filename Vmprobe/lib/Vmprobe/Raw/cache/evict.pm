package Vmprobe::Raw::cache::evict;

use common::sense;

use Vmprobe::Cache;

sub run {
    my ($params) = @_;

    if (exists $params->{start_pages}) {
        Vmprobe::Cache::evict_page_range($params->{path}, $params->{start_pages}, $params->{start_pages} + $params->{num_pages});
    } else {
        Vmprobe::Cache::evict($params->{path});
    }

    return {};
}

1;
