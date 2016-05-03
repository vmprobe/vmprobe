package Vmprobe::Viewer::Probe;

use common::sense;

use parent 'Curses::UI::Widget';



sub draw {
my $self = shift;
    my $no_doupdate = shift || 0;

    # Draw the widget
    $self->SUPER::draw(1) or return $self;

$self->{-canvasscr}->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'blue')));
$self->{-canvasscr}->addstr(0,0,'WERRRD');
$self->{-canvasscr}->addstr(1,0,'JFKSDJFK');

    # Clear all attributes.
    $self->{-canvasscr}->attroff(Curses::A_COLOR);

$self->{-canvasscr}->addstr(2,0,'OKDOFKWEOF');
$self->{-canvasscr}->addstr(3,0,'OKDOFKWEOF');
$self->{-canvasscr}->addstr(4,0,'OKDOFKWEOF');
#$self->{-canvasscr}->addstr(5,0,"DIMS: " . $self->width . " / $self->{_height}");
$self->{-canvasscr}->addstr(5,0,"X" x ($self->width - 1) .  "Y");

    $self->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
}


1;
