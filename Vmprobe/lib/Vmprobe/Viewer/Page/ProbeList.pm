package Vmprobe::Viewer::Page::ProbeList;

use common::sense;

use Curses;
use AnyEvent;
use List::MoreUtils;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::ProbeUpdateTimes;

use parent 'Vmprobe::Viewer::Page::Base';


sub init {
    my $self = shift;

    $self->{refresh_timer} = AE::timer 1, 1, sub {
        $self->redraw;
    };

    $self->{new_probes_watcher} = switchboard->listen('new-entry', sub {
        $self->find_probe_updates($self->height / 2);
        $self->redraw;
    });

    $self->find_probe_updates($self->height / 2);
}


sub help_text {
  q{up/down    - select probe
enter      - enter probe
}
}


sub bindings {
    return {
        KEY_UP() => \&select_prev_probe,
        KEY_DOWN() => \&select_next_probe,
        KEY_ENTER() => \&open_probe_screen,
    };
}



sub render {
    my ($self, $canvas) = @_;


    my $curr_time_secs = curr_time() / 1e6;

    my $curr_line = 0;

    my $probe_index = 0;
    foreach my $probe_id (@{ $self->{list_of_probes} }) {
        my $summary = $self->{summaries}->{$probe_id};

        if ($self->{selected_probe} == $probe_index) {
            $canvas->addstr($curr_line, 0, "\N{RIGHTWARDS ARROW}");
            $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('white', 'blue')));
            $canvas->addstr($curr_line, 2, $probe_id);
            $canvas->attroff(Curses::A_COLOR);
        } else {
            $canvas->addstr($curr_line, 2, $probe_id);
        }

        $canvas->addstr(" : " . ($summary->{params}->{host} // 'localhost') . ":$summary->{params}->{path}");

        $canvas->move($curr_line + 1, 3);

        $canvas->addstr("Creation: " . scalar(localtime($summary->{start} / 1e6)));

        my $last_update = $curr_time_secs - ($self->{last_updated}->{$probe_id} / 1e6);
        $canvas->addstr(" \x{2014} Last update: ");
        $canvas->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('red', 'black')))
            if $last_update < ($summary->{params}->{refresh} // 60) * 2;
        $canvas->addstr(format_duration($last_update));
        $canvas->attroff(Curses::A_COLOR);


        $curr_line += 2;

        $probe_index++;
    }
}




sub find_probe_updates {
    my ($self, $limit) = @_;

    my $txn = new_lmdb_txn();
    my $probe_db = Vmprobe::DB::Probe->new($txn);

    my @new_probe_ids;
    my $most_recent_time_seen;

    ITER: {
        Vmprobe::DB::ProbeUpdateTimes->new($txn)->iterate({
            backward => 1,
            cb => sub {
                my ($k, $v) = @_;
                last ITER if defined $self->{halt_time} && $k < $self->{halt_time};
                last ITER if !defined $self->{halt_time} && @new_probe_ids == $limit;

                $most_recent_time_seen //= $k;

                my $probe_id = $v;

                $self->{last_updated}->{$probe_id} = $k;

                if (!exists $self->{summaries}->{$probe_id}) {
                    push @new_probe_ids, $probe_id;
                    $self->{summaries}->{$probe_id} = $probe_db->get($probe_id);
                }
            },
        });
    }

    $self->{halt_time} = $most_recent_time_seen if defined $most_recent_time_seen;

    my $selected_probe_id;

    $selected_probe_id = $self->{list_of_probes}->[$self->{selected_probe}] if defined $self->{selected_probe};

    unshift @{ $self->{list_of_probes} }, @new_probe_ids;
    splice @{ $self->{list_of_probes} }, $limit, scalar(@{ $self->{list_of_probes} });

    $self->{selected_probe} = List::MoreUtils::firstidx { $_ eq $selected_probe_id } @{ $self->{list_of_probes} };
    $self->{selected_probe} = 0 if $self->{selected_probe} == -1;

    $txn->commit;
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

sub open_probe_screen {
    my ($self) = @_;

    return if !defined $self->{selected_probe};

    $self->{viewer}->new_screen('ProbeSummary', { probe_id => $self->{list_of_probes}->[$self->{selected_probe}] });
}



1;
