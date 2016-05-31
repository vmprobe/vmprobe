package Vmprobe::Cmd::vmprobe::db::entries;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::EntryByProbe;
use Vmprobe::DB::Entry;


our $spec = q{

doc: List entries for a particular probe.

argv: Probe ID.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.
  long:
    type: Bool
    alias: l
    doc: Long listing with more detailed information about each probe.
  num:
    type: Str
    alias: n
    doc: Limit number of probes listed.
};




sub run {
    my $probe_id = argv->[0] // die "need probe id";

    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $txn = new_lmdb_txn();
    my $entry_db = Vmprobe::DB::Entry->new($txn);

    my $curr = 0;

    ITER: {
        Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
            key => $probe_id,
            reverse => 1,
            cb => sub {
                my ($k, $v) = @_;

                display_entry($entry_db, $v);

                $curr++;
                last ITER if defined opt->{num} && $curr >= opt->{num};
            },
        });
    }
}



sub display_entry {
    my ($entry_db, $entry_id) = @_;

    say $entry_id;

    return if !opt->{long};

    my $curr_time_secs = curr_time() / 1e6;

    my $entry = $entry_db->get($entry_id);

    my $ago = $curr_time_secs - ($entry_id / 1e6);
    say "  Time:  " . scalar(localtime($entry_id / 1e6)) . " (" . format_duration($ago) . " ago)";
}


1;
