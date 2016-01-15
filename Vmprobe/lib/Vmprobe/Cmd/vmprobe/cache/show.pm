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



sub run {
    my ($term_cols, $term_rows) = Vmprobe::Util::term_dims();

    my $data = {};

    foreach my $path (@{ opt('vmprobe::cache')->{path} }) {
        Vmprobe::Poller::poll({
            remotes => opt('vmprobe')->{remote},
            probe_name => 'cache::summary',
            args => {
                path => $path,
                buckets => $term_cols - 6,
            },
            cb => sub {
                my ($remote, $res) = @_;
                $data->{$remote->{host}}->{$path} = $res;
            },
        });
    }

    Vmprobe::Poller::wait;


    foreach my $host (keys %$data) {
        say $host;
        foreach my $path (keys %{ $data->{$host} }) {
            my $chart = '';
            my $resident = 0;
            my $pages = 0;

            foreach my $block (@{ $data->{$host}->{$path}->{summary} }) {
                $chart .= render_block($block);
                $resident += $block->{num_resident};
                $pages += $block->{num_pages};
            }

            say "  $path";
            say "    $resident/$pages (", pages2size($resident), "/", pages2size($pages), ")";
            say "    [$chart]";
        }
    }
}



sub render_block {
    my $v = shift;

    return " " if $v->{num_resident} == 0;
    return "\x{2588}" if $v->{num_resident} == $v->{num_pages};
    return chr(0x2581 + int(8 * $v->{num_resident} / $v->{num_pages}));
}





1;
