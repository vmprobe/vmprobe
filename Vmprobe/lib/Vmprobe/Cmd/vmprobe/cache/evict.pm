package Vmprobe::Cmd::vmprobe::cache::evict;

use common::sense;

use Cwd;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::Cache;



our $spec = q{

doc: Evicts the specified files from memory, forcing them to be read from disk the next time they are accessed.

argv: Files or directories to evict.

};


sub run {
    die "need files or directories" if !@{ argv() };

    foreach my $path (@{ argv() }) {
        Vmprobe::Cache::evict(Cwd::realpath($path));
    }
}
