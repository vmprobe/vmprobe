package Vmprobe::Viewer::ProbeList;

use common::sense;
use Curses;

use parent 'Curses::UI::Widget';


sub new {
    my ($class, %userargs) = @_;

    my %args = ( 
        %userargs,

        -routines => {
            'select-prev-probe' => \&select_prev_probe,
            'select-next-probe' => \&select_next_probe,
        },

        -bindings => {
            KEY_UP() => 'select-prev-probe',
            KEY_DOWN() => 'select-next-probe',
        },
    );

    my $self = $class->SUPER::new( %args );

    return $self;
}


my $cnt = 0;
sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;



    my $curr_line = 0;

    my $probe_index = 0;
    foreach my $probe_id (@{ $self->{list_of_probes} }) {
        my $summary = $self->{summaries}->{$probe_id};
#use Data::Dumper;
#        $self->{-canvasscr}->addstr($curr_line + 5, 0, Dumper($self->{summaries}->{$probe_id}));

        if ($self->{selected_probe} == $probe_index) {
            $self->{-canvasscr}->addstr($curr_line, 0, ">>");
            $self->{-canvasscr}->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('white', 'blue')));
            $self->{-canvasscr}->addstr($curr_line, 3, $probe_id);
            $self->{-canvasscr}->attroff(Curses::A_COLOR);
        } else {
            $self->{-canvasscr}->addstr($curr_line, 3, $probe_id);
        }

        $self->{-canvasscr}->addstr($curr_line, 28, ($summary->{params}->{host} // 'localhost') . ":$summary->{params}->{path}");
delete $self->{curr_entries}->{$probe_id}->{data}{snapshots};
use Data::Dumper; $self->{-canvasscr}->addstr($curr_line+5 , 0, Dumper($self->{curr_entries}->{$probe_id}));

        $curr_line++;

        $probe_index++;
    }



    $self->{-canvasscr}->noutrefresh();

    doupdate() unless $no_doupdate;
}


sub add_new_probe {
    my ($self, $probe_id) = @_;

    push @{ $self->{list_of_probes} }, $probe_id;

    $self->{selected_probe} = 0 if !defined $self->{selected_probe};
    $self->root->draw;
}

sub new_entry {
    my ($self, $probe_id, $entry) = @_;

    $self->{curr_entries}->{$probe_id} = $entry;

    $self->root->draw;
}





sub select_prev_probe {
    my ($self) = @_;

    $self->{selected_probe}--;
    $self->{selected_probe}++ if $self->{selected_probe} < 0;

    $self->schedule_draw(1);
}

sub select_next_probe {
    my ($self) = @_;

    $self->{selected_probe}++;
    $self->{selected_probe}--  if $self->{selected_probe} >= @{ $self->{list_of_probes} };

    $self->schedule_draw(1);
}




=pod
    #$self->{-canvasscr}->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'blue')));
    #$self->{-canvasscr}->attroff(Curses::A_COLOR);


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
=cut
 


1;
