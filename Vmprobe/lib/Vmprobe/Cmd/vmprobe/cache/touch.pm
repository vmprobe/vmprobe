package Vmprobe::Cmd::vmprobe::cache::touch;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::Cache;



our $spec = q{

doc: Load the specified files into memory, forcing them to be read from disk if not already in memory.

argv: Files or directories to touch.

};


sub run {
    die "need files or directories" if !@{ argv() };

    foreach my $path (@{ argv() }) {
        Vmprobe::Cache::touch($path);
    }
}
