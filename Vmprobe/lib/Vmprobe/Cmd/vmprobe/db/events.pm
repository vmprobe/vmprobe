package Vmprobe::Cmd::vmprobe::db::events;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Event;


our $spec = q{

doc: List events in DB.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.
  num:
    type: Str
    alias: n
    doc: Limit number of probes listed.
};




sub run {
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $txn = new_lmdb_txn();

    my $curr = 0;

    ITER: {
        Vmprobe::DB::Event->new($txn)->iterate({
            backward => 1,
            cb => sub {
                my ($k, $v) = @_;

                display_event($v, $k);

                $curr++;
                last ITER if defined opt->{num} && $curr >= opt->{num};
            },
        });
    }
}



sub display_event {
    my ($event, $event_id) = @_;

    print "$event_id,$event->{run_id},$event->{msg}->{cmd}";

    if ($event->{msg}->{cmd} eq 'run') {
        print ",", join(' ', @{ $event->{msg}->{argv} });
    }

    print "\n";
}


1;
