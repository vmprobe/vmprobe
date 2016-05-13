package Vmprobe::Viewer::Probe::EntryList;

use common::sense;

use Curses;

use parent 'Vmprobe::Viewer::Probe::Base';



sub bindings {
    {
        'f' => sub {
            my ($self) = @_;

            $self->{viewer}->open_probe_screen("Files", $self->{probe_id});
        },
    }
}


sub history_size {
    my ($self) = @_;

    return $self->height - 2;
}


sub process_entry {
    my ($self, $entry) = @_;

    return { start => $entry->{start} };
}


sub render {
    my ($self, $canvas) = @_;

    my $curr_line = 0;

    $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
    $canvas->addstring($curr_line, 0, "(f) files (h) histogram (d) delta summary (D) delta in-depth");
    $canvas->attroff(Curses::A_COLOR);

    $curr_line += 2;

    for my $entry (@{ $self->{entries} }) {
        $canvas->addstring($curr_line, 0, $entry->{start} . "  " . scalar(localtime($entry->{start} / 1e6)));

        $curr_line++;
    }
}



1;
