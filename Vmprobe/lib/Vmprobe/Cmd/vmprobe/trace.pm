package Vmprobe::Cmd::vmprobe::trace;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Util;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::Probe;
use Vmprobe::RemoteCache;

use Vmprobe::Viewer;
use Vmprobe::Cache::Snapshot;

use Vmprobe::DB::Probe;
use Vmprobe::DB::EntryByProbe;
use Vmprobe::DB::Entry;
use Vmprobe::DB::ProbeUpdateTimes;


our $spec = q{

doc: Capture a trace.

opt:
  probe:
    type: Str
    alias: p
    doc: Probe definition, key=value pairs separated by white-space.
  single:
    type: Bool
    alias: 1
    doc: Only acquire a single initial snapshot of each probe.
  tag:
    type: Str[]
    alias: t
    doc: Tags to associate with this trace.
  verbose:
    type: Bool
    alias: v
    doc: Print additional info to stderr while capturing trace.
  quiet:
    type: Bool
    alias: q
    doc: Don't print any informational messages to stderr.
  curses:
    type: Bool
    alias: c
    doc: Show interactive curses display in terminal.

argv: Command to run. Otherwise capture trace until process is killed.

};



sub validate {
    die "need to specify a probe (-p)" if !defined opt->{probe};
}


our $viewer;
our $summary;
our $last_update_time;

sub run {
    my $remote_cache = Vmprobe::RemoteCache->new;

    my $probe_params = Vmprobe::Util::parse_key_value(opt->{probe});

    my $probe = Vmprobe::Probe->new(
                 remote_cache => $remote_cache,
                 params => $probe_params,
             );

    $summary = $probe->summary();

    {
        diagnostic("Saving new probe $summary->{probe_id} to DB");

        my $txn = new_lmdb_txn();
        Vmprobe::DB::Probe->new($txn)->insert($summary->{probe_id}, $summary);
        $txn->commit;
    }

    switchboard->trigger('new-probe');

if(!$viewer){
use Data::Dumper;
print Dumper($summary);
}
    #$viewer = Vmprobe::Viewer->new(probe_summaries => [ $summary ]) if opt->{curses};

    diagnostic("Taking initial snapshot...");

    $probe->once_blocking(\&handle_probe_result);

    if (opt->{single}) {
        diagnostic("Done.");
        return;
    }

    $probe->start_poll(\&handle_probe_result);

    if (!@{ argv() }) {
        diagnostic("Tracing... Stop with control-c");
        AE::cv->recv;
    }

    diagnostic("Tracing command...");

    my $exit_code = AnyEvent::Util::run_cmd(argv)->recv;

    diagnostic("Taking final snapshot...");

    $probe->stop_poll();
    $probe->once_blocking(\&handle_probe_result);

    exit $exit_code;
}



sub handle_probe_result {
    my $result = shift;

    {
        my $txn = new_lmdb_txn();

        my $timestamp = curr_time();

        Vmprobe::DB::EntryByProbe->new($txn)->insert($summary->{probe_id}, $timestamp);
        Vmprobe::DB::Entry->new($txn)->insert($timestamp, $result);

        my $update_times_db = Vmprobe::DB::ProbeUpdateTimes->new($txn);
        $update_times_db->insert($timestamp, $summary->{probe_id});
        $update_times_db->delete($last_update_time) if defined $last_update_time;

        $txn->commit;

        $last_update_time = $timestamp;

        switchboard->trigger("new-entry")
                   ->trigger("probe-" . $summary->{probe_id});
    }

#if(!$viewer){
#use Data::Dumper; print "PROBE RESULT: " . Dumper($result);
#print Dumper(Vmprobe::Cache::Snapshot::parse_records($result->{data}{snapshots}{mincore}, 10, 2));
#}
}




sub diagnostic {
    my $msg = shift;

    if (!opt->{quiet} && !$viewer) {
        say STDERR $msg;
    }
}


1;
