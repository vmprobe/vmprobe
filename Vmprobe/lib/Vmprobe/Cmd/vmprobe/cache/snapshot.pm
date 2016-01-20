package Vmprobe::Cmd::vmprobe::cache::snapshot;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;

use Sereal::Encoder;


our $spec = q{

doc: Take a full snapshot of filesystem cache usage.

opt:
    output:
        type: Str
        alias: o
        doc: Filename to save the snapshot to. This file will be overwritten if it exists. If omitted, snapshot is printed to stdout.

};

sub validate {
    die "must specify vmprobe cache --path"
        if !exists opt('vmprobe::cache')->{path};
}


sub run {
    my $data;

    my $path = opt('vmprobe::cache')->{path};

    Vmprobe::Poller::poll({
        remotes => opt('vmprobe')->{remote},
        probe_name => 'cache::snapshot',
        args => {
            path => $path,
        },
        cb => sub {
            my ($remote, $res) = @_;
            $data = {
                type => 'cache-snapshot',
                host => $remote->{host},
                path => $path,
                snapshot => $res->{snapshot},
            };
        },
    });

    Vmprobe::Poller::wait;

    my $filename = opt->{output};
    my $fh;

    if (defined $filename) {
        open($fh, '>:raw', $filename) || die "couldn't open $filename for writing: $!";
    } else {
        $fh = \*STDOUT;
        binmode $fh;
    }

    print $fh Sereal::Encoder::encode_sereal($data, { compress => 1, });
}




1;
