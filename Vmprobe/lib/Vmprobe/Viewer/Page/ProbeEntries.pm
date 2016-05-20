package Vmprobe::Viewer::Page::ProbeEntries;

use common::sense;

use Curses;

use Vmprobe::Cache::Snapshot;
use Vmprobe::Util;

use parent 'Vmprobe::Viewer::Page::BaseProbe';






sub initial_window_size {
    my ($self) = @_;

    return $self->height;
}


sub process_entry {
    my ($self, $entry, $entry_id) = @_;

    unshift @{ $self->{entries} }, { entry_id => $entry_id, %$entry };
}



sub render {
    my ($self, $canvas) = @_;

    my $curr_line = 0;

    foreach my $entry (@{ $self->{entries} }) {
        $canvas->addstring($curr_line++, 0, scalar(localtime($entry->{entry_id} / 1e6)));
    }
}



1;
