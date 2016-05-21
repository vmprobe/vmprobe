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


=pod
sub render {
    my ($self, $canvas) = @_;

    my @snapshot_types = sort keys %{ $self->{entries}->[0] };
    $self->{snapshot_types} = \@snapshot_types;

    my $sort_field = $snapshot_types[$self->{selected_type_index}];


    my $by_file = {};

    foreach my $type (@snapshot_types) {
        foreach my $record (@{ $self->{entries}->[0]->{$type} }) {
            $by_file->{$record->{filename}}->{$type} = $record;
        }
    }

    my $curr_line = 0;

    $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
    $canvas->addstring($curr_line, 0, "(s)ort by:  ");
    foreach my $type (@snapshot_types) {
        my @colours = $type eq $sort_field ? qw(black green) : qw(green black);

        $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair(@colours)));
        $canvas->addstring($type);
        $canvas->attroff(Curses::A_COLOR);
        $canvas->addstring("  ");
    }

    $curr_line += 2;


    foreach my $record (@{ $self->{entries}->[0]->{ $sort_field } }) {
        $canvas->addstring($curr_line++, 0, "$record->{filename}  " . pages2size($record->{num_pages}));

        foreach my $type (@snapshot_types) {
            my $subrecord = $by_file->{$record->{filename}}->{$type};

            my $resident = 0;
            my $rendered = '';

            if (defined $subrecord) {
                $resident = $subrecord->{num_resident_pages};
                $rendered = buckets_to_rendered($subrecord);
            }

            $canvas->addstring($curr_line++, 0, sprintf("  %-13s | %-10s | %s", $type, pages2size($resident), $rendered));
        }

        last if $curr_line + @snapshot_types >= $self->height;
    }
}
=cut



sub buckets_to_rendered {
    my ($parsed) = @_;

    return join('',
                map {
                    $_ == 0 ? ' ' :
                    $_ == $parsed->{pages_per_bucket} ? "\x{2588}" :
                    chr(0x2581 + int(8 * $_ / $parsed->{pages_per_bucket}))
                }
                @{ $parsed->{buckets} });
}


1;
