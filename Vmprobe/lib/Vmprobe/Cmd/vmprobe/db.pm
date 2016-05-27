package Vmprobe::Cmd::vmprobe::db;

use common::sense;

use EV;

use Vmprobe::Util;
use Vmprobe::Cmd;
use Vmprobe::RunContext;
use Vmprobe::Expression;


our $spec = q{

doc: Inspect and modify information in the vmprobe database.

argv: Sub-command: init, show, viz

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};




sub run {
    my $cmd = argv->[0] // die "need sub-command";
    my $expression_string;

    if ($cmd eq 'init') {
        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 1);
        say "vmprobe db initialized: $Vmprobe::RunContext::var_dir";
    } elsif ($cmd eq 'dump' || $cmd eq 'show') {
        $expression_string = argv->[1];

        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);
    } else {
        die "unrecognized sub-command: $cmd";
    }


    if ($cmd eq 'viz') {
        my $viewer;

        if (!defined $expression_string) {
            require Vmprobe::Viewer;
            $viewer = Vmprobe::Viewer->new(init_screen => ['ProbeList']);
        }

        AE::cv->recv;
    } elsif ($cmd eq 'show') {
        my $expr = Vmprobe::Expression->new($expression_string);

        my $result = $expr->eval();

        binmode(STDOUT, ":utf8");
        print Vmprobe::Cache::Snapshot::render_parse_records($result);
    }
}





1;
