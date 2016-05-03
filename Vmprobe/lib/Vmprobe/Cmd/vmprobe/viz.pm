package Vmprobe::Cmd::vmprobe::viz;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Util;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::Viewer;


our $spec = q{

doc: Curses visualization of recorded probes.

};




our $viewer;

sub run {
    $viewer = Vmprobe::Viewer->new();
    AE::cv->recv;
}



1;
