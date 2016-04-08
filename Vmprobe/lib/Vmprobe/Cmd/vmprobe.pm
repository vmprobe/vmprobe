package Vmprobe::Cmd::vmprobe;

use common::sense;

use Vmprobe::Cmd;

our $spec = q{

doc: Top-level command.

opt:
    var-dir:
        type: Str
        alias: v
        doc: Directory for the vmprobe DB, PID file, etc.
};


1;
