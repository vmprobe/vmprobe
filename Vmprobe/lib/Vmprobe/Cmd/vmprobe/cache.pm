package Vmprobe::Cmd::vmprobe::cache;

use common::sense;

our $spec = q{

doc: Inspect or manipulate the file-system cache.

opt:
    path:
        type: Str[]
        alias: p
        min_length: 1
        doc: Path(s) to files or directories. The virtual memory referred to by sub-commands is the contents of these files, or all files beneath these directories.

};

1;
