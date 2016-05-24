package Vmprobe::Cmd::vmprobe::cache;

use common::sense;

our $spec = q{

doc: Inspect or manipulate the file-system cache.

opt:
    path:
        type: Str
        alias: p
        doc: Path to files or directories. The virtual memory referred to by sub-commands is the contents of this file, or, if the path refers to a directory, all files beneath this directory.

};

1;
