package Vmprobe::Cmd::vmprobe::db::init;

use common::sense;

use Vmprobe::Util;
use Vmprobe::Cmd;
use Vmprobe::RunContext;


our $spec = q{

doc: Initialize vmprobe database.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};




sub run {
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 1, 0);
    say "vmprobe db initialized: $Vmprobe::RunContext::var_dir";
}



1;
