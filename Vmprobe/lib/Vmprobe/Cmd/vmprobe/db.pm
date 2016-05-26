package Vmprobe::Cmd::vmprobe::db;

use common::sense;

use EV;

use Vmprobe::Cmd;
use Vmprobe::RunContext;
use Vmprobe::Viewer;


our $spec = q{

doc: Inspect and modify information in the vmprobe database.

argv: Sub-command: init, dump, show

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};




sub run {
    my $cmd = argv->[0] // die "need sub-command";
    my $expr;

    if ($cmd eq 'init') {
        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 1);
        say "vmprobe db initialized: $Vmprobe::RunContext::var_dir";
    } elsif ($cmd eq 'dump' || $cmd eq 'show') {
        $expr = argv->[1];

        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);
    } else {
        die "unrecognized sub-command: $cmd";
    }


    if ($cmd eq 'show') {
        my $viewer;

        if (!defined $expr) {
            $viewer = Vmprobe::Viewer->new(init_screen => ['ProbeList']);
        }

        AE::cv->recv;
    }
}





1;
