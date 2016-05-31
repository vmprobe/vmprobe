package Vmprobe::Cmd::vmprobe::cache::show;

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
use Vmprobe::DB::ProbeUpdateTimes;


our $spec = q{

doc: Collect information about the filesystem cache.

argv: Optional command to run while recording cache.

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
  save:
    type: Bool
    alias: s
    doc: Save probe results to vmprobe database.
  viz:
    type: Bool
    doc: Show curses visualization of probe.
  quiet:
    type: Bool
    alias: q
    doc: Don't print out anything other than errors.

};



our $summary;
our $last_entry;
our $last_entry_id;
our $viewer;


sub run {
    my @argv = @{ argv() };

    my $path = shift(@argv) // die "need path";

    if (opt->{save}) {
        Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);
    } else {
        my $var_dir = File::Temp::tempdir(CLEANUP => 1);
        Vmprobe::RunContext::set_var_dir($var_dir, 0, 1);
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



    if (opt->{viz}) {
        $viewer = Vmprobe::Viewer->new(init_screen => ['ProbeSummary', { probe_id => $summary->{probe_id}, }]);
    } else {
        binmode(STDOUT, ":utf8");
    }

    if (opt->{save}) {
        say "Probe id: $summary->{probe_id}"
            unless opt->{quiet};
    }


    $probe->once_blocking(\&handle_probe_result);

    if (defined $probe_params->{refresh}) {
        $probe->start_poll(\&handle_probe_result);
    }

    my $run_cv;
    my $exit_code = 0;

    if (@argv) {
         say "Running command '" . join(' ', @argv) ."'"
             unless opt->{quiet};

         $run_cv = AnyEvent::Util::run_cmd(\@argv);
    } elsif ($probe_params->{refresh}) {
        $run_cv = AE::cv;
    }

    if ($run_cv) {
        my $exit_code = $run_cv->recv;

        $probe->stop_poll();

        if (@argv) {
            $probe->once_blocking(\&handle_probe_result);
        }
    }

    exit $exit_code;
}



sub handle_probe_result {
    my $result = shift;

    $last_entry = $result;

    my $txn = new_lmdb_txn();

    my $timestamp = curr_time();

    Vmprobe::DB::EntryByProbe->new($txn)->insert($summary->{probe_id}, $timestamp);
    Vmprobe::DB::Entry->new($txn)->insert($timestamp, $result);

    my $update_times_db = Vmprobe::DB::ProbeUpdateTimes->new($txn);
    $update_times_db->insert($timestamp, $summary->{probe_id});
    $update_times_db->delete($last_entry_id) if defined $last_entry_id;

    $txn->commit;

    $last_entry_id = $timestamp;

    switchboard->trigger("new-entry")
               ->trigger("probe-" . $summary->{probe_id});

    if (!opt->{quiet} && !opt->{viz}) {
        if (opt->{save}) {
            say "  Entry: $last_entry_id";
        } else {
            display_result();
        }
    }
}



sub display_result {
    my $min_pages;
    $min_pages = Vmprobe::Util::parse_size(opt->{min}) if defined opt->{min};

    foreach my $flag (sort keys %{ $last_entry->{data}->{snapshots} }) {
        my $snapshot_ref = \$last_entry->{data}->{snapshots}->{$flag};

        my $resident = Vmprobe::Cache::Snapshot::popcount($$snapshot_ref);

        print "==== $flag ====\n";

        if (!defined opt->{num} || opt->{num}) {
            print "\n";
            print Vmprobe::Cache::Snapshot::render_parse_records($snapshot_ref, opt->{width}, opt->{num}, $min_pages);
            print "\n";
        }

        print "  Total: " . Vmprobe::Cache::Snapshot::render_resident_amount($resident, $last_entry->{data}->{pages});
        print "\n\n";
    }
}


1;
