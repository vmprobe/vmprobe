package Vmprobe::Cmd::vmprobe::api;

use common::sense;

use EV;

use Vmprobe::Cmd;
use Vmprobe::Util;

use Vmprobe::Daemon;
use Vmprobe::Daemon::Util;
use Vmprobe::Daemon::API;



our $spec = q{

doc: API server.

opt:
  config:
    type: Str
    alias: c
    doc: Path to config file.
    default: /etc/vmprobe.conf
  daemon:
    type: Bool
    alias: d
    doc: Run the server in the background as a daemon.

};



sub run {
    Vmprobe::Daemon::Util::load_config(opt->{config});

    my $api = Vmprobe::Daemon::API->new;

    $api->run;
}
