package Vmprobe::Viewer::Page::Base;

use common::sense;

use Curses;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::Entry;

use parent 'Curses::UI::Widget';



sub new {
    my ($class, %userargs) = @_;

    my %args = (
        %userargs,
    );

    my $self = $class->SUPER::new( %args );


    $self->set_binding(sub { $self->root->dialog(-message => $self->_help_text_wrapper()) }, "?");

    my $bindings = $self->bindings();

    foreach my $key (keys %{ $bindings }) {
        $self->set_binding($bindings->{$key}, $key);
    }


    $self->init;


    return $self;
}


sub _help_text_wrapper {
    my ($self) = @_;

    my $text =
qq{?          - this help screen
left/right - switch tabs
x          - close current tab
q          - quit
};

    my $page_specific_help_text = $self->help_text();

    $text = "$page_specific_help_text\n$text" if $page_specific_help_text;

    return $text;
}


sub help_text { '' }



sub redraw {
    my $self = shift;

    $self->schedule_draw(1);
    $self->draw(0) if !$self->hidden && $self->in_topwindow;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;

    $self->render($self->{-canvasscr});

    $self->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
}


sub bindings { {} }

sub render {
    die "must implement render";
}


sub init {}



1;
