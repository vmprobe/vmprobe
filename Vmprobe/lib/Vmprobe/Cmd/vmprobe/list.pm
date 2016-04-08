package Vmprobe::Cmd::vmprobe::list;

use common::sense;

use Cwd;

use Vmprobe::DB::Probe;
use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;


our $spec = q{

doc: List currently installed probes.

};




sub run {
    my $ctx = Vmprobe::RunContext->new;

    my $txn = $ctx->new_txn();

    my @probes;

    Vmprobe::DB::Probe->new($txn)->foreach(sub {
        my ($key, $probe) = @_;

        push @probes, $probe;
    });

    $txn->commit;


    require Text::ANSITable;
    my $t = Text::ANSITable->new;

    $t->border_style('Default::bold');

    $t->columns(["Probe ID", "Refresh", "Host", "Type", "Params", "Running"]);

    $t->set_column_style('Running', align => 'middle');

    foreach my $probe (@probes) {
        my $params = join ' ', map { "$_:$probe->{params}->{$_}" } keys %{ $probe->{params} };

        my $running = colour("\N{CHECK MARK}", 'green');

        $t->add_row([ $probe->{id}, $probe->{refresh}, $probe->{host}, $probe->{type}, $params, $running ]);
    }


    binmode(STDOUT, ":utf8");
    print $t->draw;
}



1;
