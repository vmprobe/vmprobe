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
#use Vmprobe::DB::Object;


our $spec = q{

doc: Capture a trace.

opt:
  probe:
    type: Str
    alias: p
    doc: Probe definition, key=value pairs separated by white-space.
  file:
    type: Str
    alias: f
    doc: Filename of a YAML file specifying probes.
  single:
    type: Bool
    alias: 1
    doc: Only acquire a single initial snapshot of each probe.
  tag:
    type: Str[]
    alias: t
    doc: Tags to associate with this trace.
  output:
    type: Str
    alias: o
    doc: Output file to save trace. If not specified, save in .vmprobe DB.
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
    die "need to specify a probe (-p), or the filename of a YAML file containing the probe definition (-f)"
        if !defined opt->{probe} && !defined opt->{file};
}


our $ctx;
our $output_fh;
our $viewer;

sub run {
    $ctx = Vmprobe::RunContext->new;

    my $remote_cache = Vmprobe::RemoteCache->new;

    my $probe_params = Vmprobe::Util::parse_key_value(opt->{probe});

    my $probe = Vmprobe::Probe->new(
                 remote_cache => $remote_cache,
                 params => $probe_params,
             );

    my $summary = $probe->summary();
    my $summary_encoded = sereal_encode($summary);

    if (defined opt->{output}) {
        diagnostic("Saving new trace $summary->{trace_id} to file '" . opt->{output} . "'");

        open($output_fh, '>', opt->{output}) || die "couldn't open output file " . opt->{output} . " for writing: $!";
        print $output_fh pack("w", length($summary_encoded));
        print $output_fh $summary_encoded;
    } else {
        diagnostic("Saving new trace $summary->{trace_id} to DB");
        ## FIXME: save to DB
    }

if(!$viewer){
use Data::Dumper;
print Dumper($summary);
}
    $viewer = Vmprobe::Viewer->new(probe_summaries => [ $summary ]) if opt->{curses};

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

if(!$viewer){
use Data::Dumper; print "PROBE RESULT: " . Dumper($result);
print Dumper(Vmprobe::Cache::Snapshot::parse_records($result->{data}{snapshots}{mincore}, 10, 2));
}

    my $result_encoded = sereal_encode($result);

    #$viewer->update($result) if $viewer;

    if (defined opt->{output}) {
        print $output_fh pack("w", length($result_encoded));
        print $output_fh $result_encoded;
    } else {
        die;
        #my $txn = $ctx->new_txn();
        #$txn->commit;
    }
}




sub diagnostic {
    my $msg = shift;

    if (!opt->{quiet} && !$viewer) {
        say STDERR $msg;
    }
}


1;
