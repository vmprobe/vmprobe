package Vmprobe::Cmd::vmprobe;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::RunContext;

our $spec = q{

doc: Top-level command.

opt:
    var-dir:
        type: Str
        alias: v
        doc: Directory for the vmprobe DB and other run-time files.
};


sub validate {
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'});
}

1;
