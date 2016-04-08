package Vmprobe::Raw::cache::touch;

use common::sense;

use Vmprobe::Cache;

sub run {
    my ($params) = @_;

    if (exists $params->{start_pages}) {
        Vmprobe::Cache::touch_page_range($params->{path}, $params->{start_pages}, $params->{start_pages} + $params->{num_pages});
    } else {
        Vmprobe::Cache::touch($params->{path});
    }

    return {};
}

1;
