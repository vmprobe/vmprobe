package Vmprobe::Cmd::vmprobe::cache::restore;

use common::sense;

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
    my $expression_string = argv->[1] // die "need path";

    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $expr = Vmprobe::Expression->new($expression_string);
    my $result = $expr->eval();

    Vmprobe::Cache::Snapshot::restore($path, $$result);
}
