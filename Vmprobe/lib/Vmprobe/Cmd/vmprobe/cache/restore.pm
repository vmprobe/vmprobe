package Vmprobe::Cmd::vmprobe::cache::restore;

use common::sense;

use Cwd;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::Expression;
use Vmprobe::Cache::Snapshot;



our $spec = q{

doc: Restore a cache snapshot to the filesystem.

argv: Path and entry expression.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};


sub run {
    my $path = argv->[0] // die "need path";
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $snapshot_ref;

    if (defined argv->[1]) {
        my $expression_string = argv->[1];

        my $expr = Vmprobe::Expression->new($expression_string);

        $snapshot_ref = $expr->eval();
    } else {
        local $/;

        my $snapshot = <STDIN>;

        $snapshot_ref = \$snapshot;
    }

    Vmprobe::Cache::Snapshot::restore(Cwd::realpath($path), $$snapshot_ref);
}



1;
