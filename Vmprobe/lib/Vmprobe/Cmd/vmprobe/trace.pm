package Vmprobe::Cmd::vmprobe::trace;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Util;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::TraceEngine;
#use Vmprobe::DB::Object;


our $spec = q{

doc: Capture a trace.

opt:
  probe:
    type: Str[]
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

argv: Command to run. Otherwise capture trace until process is killed.

};



sub validate {
    die "need to specify one or more probes (-p), or the filename of a YAML file containing probes (-f)"
        if !defined opt->{probe} && !defined opt->{file};
}


our $ctx;
our $output_fh;

sub run {
    $ctx = Vmprobe::RunContext->new;

    my $probes = [ map { Vmprobe::Util::parse_key_value($_) } @{ opt->{probe} } ];

    my $te = Vmprobe::TraceEngine->new(
                 probes => $probes,
                 cb => \&handle_probe_result,
             );


    my $trace_summary = $te->summary();
    my $trace_summary_encoded = sereal_encode($trace_summary);

    if (defined opt->{output}) {
        open($output_fh, '>', opt->{output}) || die "couldn't open output file " . opt->{output} . " for writing: $!";
        print $output_fh pack("w", length($trace_summary_encoded));
        print $output_fh $trace_summary_encoded;
    } else {
        ## FIXME: save to DB
    }

use Data::Dumper; print "SUMMARY: " . Dumper($trace_summary);

    say STDERR "Taking initial snapshot..." unless opt->{quiet};

    $te->barrier();

    if (opt->{single}) {
        say STDERR "Done." unless opt->{quiet};
        return;
    }

    $te->start_poll();

    if (!@{ argv() }) {
        say STDERR "Tracing... Stop with control-c" unless opt->{quiet};
        AE::cv->recv;
    }

    say STDERR "Tracing command..." unless opt->{quiet};

    my $exit_code = AnyEvent::Util::run_cmd(argv)->recv;

    say STDERR "Taking final snapshot..." unless opt->{quiet};

    $te->stop_poll();
    $te->barrier();

    exit $exit_code;
}



sub handle_probe_result {
    my $result = shift;

use Data::Dumper; print "PROBE RESULT: " . Dumper($result);

    my $result_encoded = sereal_encode($result);

    if (defined opt->{output}) {
        print $output_fh pack("w", length($result_encoded));
        print $output_fh $result_encoded;
    } else {
    }
    #my $txn = $ctx->new_txn();
    #$txn->commit;
}



1;
