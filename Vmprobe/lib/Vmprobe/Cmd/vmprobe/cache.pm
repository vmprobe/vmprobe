package Vmprobe::Cmd::vmprobe::cache;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Util;
use File::Temp;

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

doc: Collect information about the filesystem cache.

argv: Sub-command: dump, show, save

opt:
  refresh:
    type: Str
    alias: r
    doc: Refresh interval in seconds. If omitted, just gather a single snapshot.
  flags:
    type: Str
    alias: f
    doc: Comma-separated list of page flags to acquire (ie "mincore,active,referenced").
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.

};



our $summary;
our $last_update_time;


sub run {
    my $cmd = argv->[0] // die "need sub-command";
    my $path = argv->[1] // die "need path";

    if ($cmd eq 'save') {
        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);
    } elsif ($cmd eq 'dump' || $cmd eq 'show') {
        my $var_dir = File::Temp::tempdir(CLEANUP => 1);
        Vmprobe::RunContext::set_var_dir($var_dir, 0, 1);
    } else {
        die "unrecognized sub-command: $cmd";
    }


    my $probe_params = {
        type => 'cache',
        path => $path,
    };

    $probe_params->{flags} = opt->{flags} if defined opt->{flags};
    $probe_params->{refresh} = opt->{refresh} if defined opt->{refresh};

    my $remote_cache = Vmprobe::RemoteCache->new;

    my $probe = Vmprobe::Probe->new(
                 remote_cache => $remote_cache,
                 params => $probe_params,
             );

    $summary = $probe->summary();

    {
        my $txn = new_lmdb_txn();
        Vmprobe::DB::Probe->new($txn)->insert($summary->{probe_id}, $summary);
        $txn->commit;
    }

    switchboard->trigger('new-probe');

    $probe->once_blocking(\&handle_probe_result);

    if (defined $probe_params->{refresh}) {
        $probe->start_poll(\&handle_probe_result);
    }

    if ($cmd eq 'show') {
        my $viewer = Vmprobe::Viewer->new(init_screen => ['ProbeSummary', { probe_id => $summary->{probe_id}, }]);

        AE::cv->recv;
    }
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



1;
