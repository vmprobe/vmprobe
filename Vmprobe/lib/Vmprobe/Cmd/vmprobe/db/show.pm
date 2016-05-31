package Vmprobe::Cmd::vmprobe::db::show;

use common::sense;

use EV;

use Vmprobe::Util;
use Vmprobe::Cmd;
use Vmprobe::RunContext;
use Vmprobe::Expression;


our $spec = q{

doc: Compute cache expression over database records.

argv: Expression.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};




sub run {
    my $expression_string = argv->[0] // die "need expression";

    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $expr = Vmprobe::Expression->new($expression_string);

    my $result = $expr->eval();

    binmode(STDOUT, ":utf8");
    print Vmprobe::Cache::Snapshot::render_parse_records($result);
}





1;
