package Vmprobe::Viewer::Page::ProbeEntries;

use common::sense;

use Curses;

use Vmprobe::Cache::Snapshot;
use Vmprobe::Util;

use parent 'Vmprobe::Viewer::Page::BaseProbeHistory';




sub process_entry {
    my ($self, $entry, $entry_id) = @_;

    unshift @{ $self->{entries} }, { entry_id => $entry_id, %$entry };
}

sub reset_entries {
    my ($self) = @_;

    delete $self->{entries};
}



sub render {
    my ($self, $canvas) = @_;

    $self->render_window_skip_line;
    my $curr_line = 1;

    foreach my $entry (@{ $self->{entries} }) {
        $canvas->addstring($curr_line++, 0, "$entry->{entry_id} : " . scalar(localtime($entry->{entry_id} / 1e6)));
    }
}



1;
