package Vmprobe::Cmd::vmprobe::trace;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Util;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::ProbeSpec;
#use Vmprobe::DB::Object;


our $spec = q{

doc: Capture a trace.

opt:
  probespec:
    type: Str
    alias: p
    doc: Filename of the probespec to use while capturing the trace.
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

argv: Command to run. Otherwise capture trace until process is killed.

};



sub validate {
    die "need to specify a probespec with the -p option" if !defined opt->{probespec};
}


our $ctx;

sub run {
    $ctx = Vmprobe::RunContext->new;

    my $ps = Vmprobe::ProbeEngine->new(
                 spec_filename => opt->{probespec},
                 cb => \&handle_probe_result,
             );   

    $ps->barrier();
    $ps->start_poll();

    if (!@{ argv }) {
        say STDERR "Tracing... Stop with control-c" unless opt->{quiet};
        AE::cv->recv;
    }

    my $exit_code = AnyEvent::Util::run_cmd(argv)->recv;

    $ps->stop_poll();
    $ps->barrier();

    exit $recv;
}



sub handle_probe_result {
    my $result = shift;

use Data::Dumper;
print Dumper($result);
    #my $txn = $ctx->new_txn();
    #$txn->commit;
}



1;
