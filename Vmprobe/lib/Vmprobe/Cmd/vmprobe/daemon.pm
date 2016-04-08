package Vmprobe::Cmd::vmprobe::daemon;

use common::sense;

use EV;

use Vmprobe::Cmd;
use Vmprobe::Daemon;



our $spec = q{

doc: API server.

opt:
  fg:
    type: Bool
    alias: f
    doc: Don't daemonize. Instead run in the foreground until killed.

};



sub run {
    my $daemon_ctx = Vmprobe::Daemon->new;

    $daemon_ctx->daemonize() unless opt->{fg};

    say "Listening on $daemon_ctx->{socket_path}";
}


1;
