package Vmprobe::Cmd::vmprobe::add::cache;

use common::sense;

use Cwd;

use Vmprobe::DB;
use Vmprobe::DB::Probe;
use Vmprobe::Cmd;
use Vmprobe::Util;


our $spec = q{

doc: Add a new probe.

argv: Path to inspect.

opt:
  refresh:
    type: Str
    alias: r
    doc: How often to poll the page cache.
    default: 30
  host:
    type: Str
    alias: h
    doc: Which host to gather information about.
    default: localhost

};




sub run {
    die "requires exactly one argument: path" if @{ argv() } != 1;

    my $id = get_session_token();

    my $probe = {
        id => $id,
        refresh => opt->{refresh},
        host => opt->{host},
        type => 'cache',
        params => {
            path => Cwd::realpath(argv->[0]),
        },
    };

    my $txn = Vmprobe::DB::new_txn();

    Vmprobe::DB::Probe->new($txn)->insert($id, $probe);

    $txn->commit;

    say "Added new probe: $id";
}



1;

__END__


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
