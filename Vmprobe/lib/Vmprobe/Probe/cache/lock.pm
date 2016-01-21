package Vmprobe::Probe::cache::lock;

use common::sense;

use Vmprobe::Cache;
use Vmprobe::Util;

sub run {
    my ($params) = @_;

    my $lock_id = get_session_token();
    my $lock_context;

    if (exists $params->{start_pages}) {
        $lock_context = Vmprobe::Cache::lock_page_range($params->{path}, $params->{start_pages}, $params->{start_pages} + $params->{num_pages});
    } else {
        $lock_context = Vmprobe::Cache::lock($params->{path});
    }

    $Vmprobe::Cache::locks->{$lock_id} = $lock_context;

    return { lock_id => $lock_id, };
}

1;
