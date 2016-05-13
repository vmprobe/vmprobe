package Vmprobe::Viewer::ProbeList;

use common::sense;

use Curses;
use AnyEvent;
use List::MoreUtils;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::ProbeUpdateTimes;

use parent 'Curses::UI::Widget';


sub new {
    my ($class, %userargs) = @_;

    my %args = ( 
        %userargs,

        -routines => {
            'select-prev-probe' => \&select_prev_probe,
            'select-next-probe' => \&select_next_probe,
            'open-probe-screen' => \&open_probe_screen,
        },

        -bindings => {
            KEY_UP() => 'select-prev-probe',
            KEY_DOWN() => 'select-next-probe',
            KEY_ENTER() => 'open-probe-screen',
        },

        -intellidraw => 1,
    );

    my $self = $class->SUPER::new( %args );

    $self->{refresh_timer} = AE::timer 1, 1, sub {
        $self->schedule_draw(1);
        $self->draw(0) if !$self->hidden && $self->in_topwindow;
    };

    $self->{new_probes_watcher} = switchboard->listen('new-entry', sub {
        $self->find_probe_updates($self->height / 2);
        $self->draw(0) if !$self->hidden && $self->in_topwindow;
    });

    $self->find_probe_updates($self->height / 2);

    return $self;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;


    my $curr_time_secs = curr_time() / 1e6;

    my $curr_line = 0;

    my $probe_index = 0;
    foreach my $probe_id (@{ $self->{list_of_probes} }) {
        my $summary = $self->{summaries}->{$probe_id};

        if ($self->{selected_probe} == $probe_index) {
            $self->{-canvasscr}->addstr($curr_line, 0, "\N{RIGHTWARDS ARROW}");
            $self->{-canvasscr}->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('white', 'blue')));
            $self->{-canvasscr}->addstr($curr_line, 2, $probe_id);
            $self->{-canvasscr}->attroff(Curses::A_COLOR);
        } else {
            $self->{-canvasscr}->addstr($curr_line, 2, $probe_id);
        }

        $self->{-canvasscr}->addstr(" : " . ($summary->{params}->{host} // 'localhost') . ":$summary->{params}->{path}");

        $self->{-canvasscr}->move($curr_line + 1, 3);

        $self->{-canvasscr}->addstr("Creation: " . scalar(localtime($summary->{start} / 1e6)));

        my $last_update = $curr_time_secs - ($self->{last_updated}->{$probe_id} / 1e6);
        $self->{-canvasscr}->addstr(" \x{2014} Last update: ");
        $self->{-canvasscr}->attron(Curses::COLOR_PAIR($Curses::UI::color_object->get_color_pair('red', 'black')))
            if $last_update < ($summary->{params}->{refresh} // 60) * 2;
        $self->{-canvasscr}->addstr(format_duration($last_update));
        $self->{-canvasscr}->attroff(Curses::A_COLOR);


        $curr_line += 2;

        $probe_index++;
    }



    $self->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
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

    $self->{viewer}->open_probe_screen('EntryList', $self->{list_of_probes}->[$self->{selected_probe}]);
}


1;
