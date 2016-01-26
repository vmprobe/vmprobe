package Vmprobe::Cmd::vmprobe::cache::show;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;
use Vmprobe::Util;


our $spec = q{

doc: Show filesystem cache usage.

opt:
  verbose:
    type: Bool
    alias: v
    doc: Whether to show a file-by-file break-down of cache usage instead of a concise summary.
  group:
    type: Enum(host path)
    default: host
    alias: g

};


sub validate {
    die "must specify vmprobe cache --path"
        if !exists opt('vmprobe::cache')->{path};
}


sub run {
    my ($term_cols, $term_rows) = Vmprobe::Util::term_dims();

    my $path = opt('vmprobe::cache')->{path};

    my $data = {};

    Vmprobe::Poller::poll({
        probe_name => 'cache::summary',
        args => {
            path => $path,
            buckets => $term_cols - 6,
        },
        cb => sub {
            my ($remote, $res) = @_;
            $data->{$remote->{host}} = $res;
        },
    });

    Vmprobe::Poller::wait;


    foreach my $host (keys %$data) {
        my $chart = '';
        my $resident = 0;
        my $pages = 0;

        foreach my $block (@{ $data->{$host}->{summary} }) {
            $chart .= render_block($block);
            $resident += $block->{num_resident};
            $pages += $block->{num_pages};
        }

        say "  $host:$path";
        say "    $resident/$pages (", pages2size($resident), "/", pages2size($pages), ")";
        say "    [$chart]";
    }
}



sub render_block {
    my $v = shift;

    return " " if $v->{num_resident} == 0;
    return "\x{2588}" if $v->{num_resident} == $v->{num_pages};
    return chr(0x2581 + int(8 * $v->{num_resident} / $v->{num_pages}));
}





1;
