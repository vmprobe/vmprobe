package Vmprobe::Viewer;

use common::sense;

use Curses::UI::AnyEvent;

use Vmprobe::Util;
use Vmprobe::RunContext;

use Vmprobe::DB::Probe;
use Vmprobe::DB::EntryByProbe;
use Vmprobe::DB::Entry;


sub new {
    my ($class, %args) = @_;

    my $self = { summaries => {}, };
    bless $self, $class;



    $self->{cui} = Curses::UI::AnyEvent->new(-color_support => 1, -mouse_support => 0, -utf8 => 1,);
$self->{cui}->leave_curses if $ENV{LEAVE_CURSES};

    $self->{cui}->set_binding(sub { exit }, "\cC");
    $self->{cui}->set_binding(sub { exit }, "q");

    $self->{main_window} = $self->{cui}->add('main', 'Window');
    $self->{notebook} = $self->{main_window}->add(undef, 'Notebook');

    $self->{probes_list_page} = $self->{notebook}->add_page("Probes");
    $self->{probes_list_page_widget} = $self->{probes_list_page}->add('probes list page', 'Vmprobe::Viewer::ProbeList',
                                                                      -focusable => 0, summaries => $self->{summaries});


    $self->{new_probes_watcher} = switchboard->listen('new-probe', sub {
        $self->find_new_active_probes();
    });

    $self->find_new_active_probes();



    $self->{cui}->draw;
    $self->{cui}->startAsync();

    return $self;
}



sub find_new_active_probes {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    ITER: {
        my $halt_time = curr_time() - (3600 * 1_000_000);

        my $probe_db = Vmprobe::DB::Probe->new($txn);
        my $entry_db = Vmprobe::DB::Entry->new($txn);

        $entry_db->iterate({
            backward => 1,
            cb => sub {
                my ($k, $v) = @_;
                last ITER if $k < $halt_time;

                my $probe_id = $v->{probe_id};

                if (!exists $self->{summaries}->{$probe_id}) {
                    my $probe_summary = $probe_db->get($probe_id);

                    $self->{summaries}->{$probe_id} = $probe_summary;
                    $self->{probes_list_page_widget}->add_new_probe($probe_id);

                    $self->{curr_entries}->{$probe_id} = $halt_time;
                    $self->{probe_watcher}->{$probe_id} = switchboard->listen("probe-$probe_id", sub {
                        $self->find_new_probe_entries($probe_id, undef);
                    });
                    $self->find_new_probe_entries($probe_id, $txn);
                }
            },
        });
    }

    $txn->commit;
}


sub find_new_probe_entries {
    my ($self, $probe_id, $txn) = @_;

    $txn //= new_lmdb_txn();

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
        key => $probe_id,
        start => $self->{curr_entries}->{$probe_id},
        skip_start => 1,
        cb => sub {
            my ($k, $v) = @_;

            $self->{curr_entries}->{$probe_id} = $k;
            my $entry = $entry_db->get($v);

            $self->{probes_list_page_widget}->new_entry($probe_id, $entry);
        },
    });
}



1;


__END__

sub update {
    my ($self, $update) = @_;
}


sub create_probe_page {
    my ($self, $probe) = @_;

    my $page = $self->{notebook}->add_page("Probes");
    $self->render_probe_page();
}

sub render_probe_page {
    my $self = shift;

    my $l = $self->{probe_page}->add('blah', 'Label',
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -x => 0,
                               -border => 1,
                               -fg => 'red',
                               -focusable => 0,
                             );
$l->text("hi\x{2588}\x{2586}\x{2584} \x{033d}\x{033c}' \x{2591}\x{2592}\x{2593}");

    my $l2 = $self->{probe_page}->add('blah 2', 'Vmprobe::Viewer::Probe',
                               -y => 7,
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -border => 1,
                               -focusable => 0,
                             );



    my $l3 = $self->{probe_page}->add('blah 3', 'Vmprobe::Viewer::Probe',
                               -y => 14,
                               -height => 7,
                               -width => $self->{main_window}->{_width},
                               -border => 1,
                               -focusable => 0,
                             );
$self->{notebook}->set_binding(sub { $l->focus(); }, "1");
}





1;
