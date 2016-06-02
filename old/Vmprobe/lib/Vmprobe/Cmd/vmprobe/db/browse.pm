package Vmprobe::Cmd::vmprobe::db::browse;

use common::sense;

use EV;

use Vmprobe::Util;
use Vmprobe::Cmd;
use Vmprobe::RunContext;
use Vmprobe::Viewer;


our $spec = q{

doc: Browse vmprobe database with curses interface.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};




sub run {
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $viewer = Vmprobe::Viewer->new(init_screen => ['ProbeList']);

    AE::cv->recv;
}




1;
