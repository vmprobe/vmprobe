package Vmprobe::Viewer::Probe;

use common::sense;

use Curses;

use Vmprobe::Util;
use Vmprobe::Cache::Snapshot;

use parent 'Curses::UI::Widget';


sub new {
    my ($class, %userargs) = @_;

    my %args = ( 
        %userargs,

        -routines => {
        },

        -bindings => {
        },
    );

    my $self = $class->SUPER::new( %args );

    return $self;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;




    $self->{-canvasscr}->noutrefresh();

    doupdate() unless $no_doupdate;
}


sub new_entry {
    my ($self, $probe_id, $entry) = @_;
}




1;
