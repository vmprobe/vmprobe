package Vmprobe::Viewer::Page::BaseProbeHistory;

use common::sense;

use Vmprobe::RunContext;

use parent 'Vmprobe::Viewer::Page::BaseProbe';



our $bindings = [
    {
        key => '+',
        desc => 'Zoom-in in time',
        cb => sub {
            my $self = shift;

            my $new_skip = $self->{skip};

            if ($new_skip == 0) {
                $new_skip = 2 * ($self->{summary}->{params}->{refresh} // 5) * 1e6;
            } else {
                $new_skip *= 2;
            }

            $self->change_window_skip($self->{window_size}, $new_skip);
            $self->redraw;
        },
    },
    {
        key => '-',
        desc => 'Zoom-out in time',
        cb => sub {
            my $self = shift;

            my $new_skip = $self->{skip};

            $new_skip /= 2;
            $new_skip = 0 if $new_skip <= ($self->{summary}->{params}->{refresh} // 5);
            $new_skip = 0 if $new_skip <= 1;

            $self->change_window_skip($self->{window_size}, $new_skip);
            $self->redraw;
        },
    }
];


sub initial_window_size { shift->height }



sub render_window_skip_line {
    my ($self) = @_;

    my $canvas = $self->{-canvasscr};

    $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
    $canvas->addstring(sprintf("(+/-) Every %ds", int($self->{skip} / 1e6)));
    $canvas->attroff(Curses::A_COLOR);
}



1;
