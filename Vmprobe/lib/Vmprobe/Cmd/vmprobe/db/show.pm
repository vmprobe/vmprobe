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
  raw:
    type: Bool
    alias: r
    doc: Print a binary snapshot to standard output.
  min:
    type: Str
    alias: m
    doc: When showing, only show files this size or larger (ie "16k", "0.5G")
  num:
    type: Str
    alias: n
    doc: Only show this number of files in each snapshot, sorted by most populated.
  width:
    type: Str
    alias: w
    default: 25
    doc: Width of the residency charts.

};




sub run {
    my $expression_string = argv->[0] // die "need expression";

    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $expr = Vmprobe::Expression->new($expression_string);

    my $result = $expr->eval();

    if (opt->{raw}) {
        binmode(STDOUT, ":raw");
        print $$result;
    } else {
        binmode(STDOUT, ":utf8");

        my $min_pages;
        $min_pages = Vmprobe::Util::parse_size(opt->{min}) if defined opt->{min};

        print Vmprobe::Cache::Snapshot::render_parse_records($result, opt->{width}, opt->{num}, $min_pages);
    }
}





1;
