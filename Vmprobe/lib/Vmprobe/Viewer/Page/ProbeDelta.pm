package Vmprobe::Viewer::Page::ProbeDelta;

use common::sense;

use Curses;

use Vmprobe::Cache::Snapshot;
use Vmprobe::Util;

use parent 'Vmprobe::Viewer::Page::BaseProbeHistory';




sub process_entry {
    my ($self, $entry, $entry_id) = @_;

    if ($self->{prev_entry}) {
        my $deltas = {};

        foreach my $key (keys %{ $entry->{data}->{snapshots} }) {
            my $added = Vmprobe::Cache::Snapshot::subtract($entry->{data}->{snapshots}->{$key},
                                                           $self->{prev_entry}->{data}->{snapshots}->{$key});

            my $removed = Vmprobe::Cache::Snapshot::subtract($self->{prev_entry}->{data}->{snapshots}->{$key},
                                                             $entry->{data}->{snapshots}->{$key});

            my $added_popcount = Vmprobe::Cache::Snapshot::popcount($added);
            my $removed_popcount = Vmprobe::Cache::Snapshot::popcount($removed);

            if ($added_popcount) {
                #$deltas->{$key}->{added} = $added;
                $deltas->{$key}->{added_popcount} = $added_popcount;
            }

            if ($removed_popcount) {
                #$deltas->{$key}->{removed} = $removed;
                $deltas->{$key}->{removed_popcount} = $removed_popcount;
            }
        }

        unshift @{ $self->{entries} }, { entry_id => $entry_id, deltas => $deltas }
            if keys %$deltas;
    }

    $self->{prev_entry} = $entry;
}


sub reset_entries {
    my ($self) = @_;

    delete $self->{prev_entry};
    delete $self->{entries};
}



sub render {
    my ($self, $canvas) = @_;

    $self->render_window_skip_line;
    my $curr_line = 1;

    foreach my $entry (@{ $self->{entries} }) {
        $canvas->addstring($curr_line++, 0, scalar(localtime($entry->{entry_id} / 1e6)));
        foreach my $key (sort keys %{ $entry->{deltas} }) {
            $canvas->addstring($curr_line, 2, sprintf("%-15s", $key));

            my $added = $entry->{deltas}->{$key}->{added_popcount};
            my $removed = $entry->{deltas}->{$key}->{removed_popcount};

            if ($added) {
                $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
                $canvas->addstring("+$added (" . pages2size($added) . ")  ");
            }

            if ($removed) {
                $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('red', 'black')));
                $canvas->addstring("-$removed (" . pages2size($removed) . ")");
            }

            $canvas->attroff(Curses::A_COLOR);

            $curr_line++;
        }

        return if $curr_line > $self->height;
    }
}


1;
