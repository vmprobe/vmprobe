package Vmprobe::Viewer::Page::ProbeSummary;

use common::sense;

use Curses;

use Vmprobe::Util;
use Vmprobe::Cache::Snapshot;

use parent 'Vmprobe::Viewer::Page::BaseProbe';



sub bindings {
    {
        'f' => sub {
            my ($self) = @_;

            $self->{viewer}->new_screen("ProbeFiles", { probe_id => $self->{probe_id} });
        },
    }
}



sub help_text {
  q{f          - most recent per-file break-down
}
}




sub render {
    my ($self, $canvas) = @_;

    my $curr_line = 0;

    $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('green', 'black')));
    $canvas->addstring($curr_line, 0, "(f) files (h) histogram (d) delta summary (D) delta in-depth");
    $canvas->attroff(Curses::A_COLOR);

    $curr_line += 2;
    my $curr_time_secs = curr_time() / 1e6;

    $canvas->addstring($curr_line++, 0, "Probe id: $self->{summary}->{probe_id}");

    my $creation_ago = $curr_time_secs - ($self->{summary}->{start} / 1e6);
    $canvas->addstring($curr_line++, 0, "Created:  "
                                        . scalar(localtime($self->{summary}->{start} / 1e6))
                                        . " (" . format_duration($creation_ago) . " ago)");

    my $params = $self->{summary}->{params};
    $canvas->addstring($curr_line++, 0, "Params:   " . join(' ', map { "$_=$params->{$_}" } sort keys %$params));

    $curr_line++;

    if (@{ $self->{entries} }) {
        my $entry = $self->{entries}->[0];

        my $last_update = $curr_time_secs - ($entry->{start} / 1e6);

        $canvas->addstring($curr_line++, 0, "Most recent entry: $entry->{entry_id}");
        $canvas->addstring($curr_line++, 2, "Updated:    "
                                            . scalar(localtime($entry->{start} / 1e6)
                                            . " (" . format_duration($last_update) . " ago)"));

        my $probe_time = ($entry->{end} - $entry->{start}) / 1e6;

        $canvas->addstring($curr_line++, 2, "Probe time: " . format_duration($probe_time, 1));

        $curr_line++;

        $canvas->addstring($curr_line++, 2, "Files: $entry->{data}->{files}");
        $canvas->addstring($curr_line++, 2, "Pages: $entry->{data}->{pages} | " . pages2size($entry->{data}->{pages}));

        foreach my $key (sort keys %{ $entry->{data}->{snapshots} }) {
            my $snapshot_pages = Vmprobe::Cache::Snapshot::popcount($entry->{data}->{snapshots}->{$key});
            $canvas->addstring($curr_line++, 4, sprintf("%-15s: %s | %s | %.1f%%", $key, $snapshot_pages, pages2size($snapshot_pages), 100.0*$snapshot_pages/$entry->{data}->{pages}));
        }
    }
}



1;
