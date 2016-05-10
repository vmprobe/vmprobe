package Vmprobe::Viewer::Probe;

use common::sense;

use Curses;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::Cache::Snapshot;
use Vmprobe::DB::Probe;
use Vmprobe::DB::Entry;

use parent 'Curses::UI::Widget';


sub new {
    my ($class, %userargs) = @_;

    my %args = ( 
        %userargs,

        -routines => {
        },

        -bindings => {
        },
    );

    my $self = $class->SUPER::new( %args );

    {
        my $txn = new_lmdb_txn();

        $self->{summary} = Vmprobe::DB::Probe->new($txn)->get($self->{probe_id});

        $txn->commit;
    }

    $self->{new_probes_watcher} = switchboard->listen("probe-$self->{probe_id}", sub {
        $self->find_new_entries();
        $self->draw(0) if !$self->hidden && $self->in_topwindow;
    });

    $self->find_new_entries();
$self->collect_entries();

    return $self;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;

    my $curr_line = 0;

    my $parsed = Vmprobe::Cache::Snapshot::parse_records($self->{latest_entry}{data}{snapshots}{mincore}, $self->width, 100);

    foreach my $record (@$parsed) {
        $self->{-canvasscr}->addstring($curr_line, 0, "$self->{summary}->{params}->{path}$record->{filename} " . pages2size($record->{num_resident_pages}) . "/" . pages2size($record->{num_pages}));
        $self->{-canvasscr}->addstring($curr_line+1, 0, buckets_to_rendered($record));
        $curr_line += 2;
    }

    foreach my $entry (@{ $self->{entries} }) {
        $self->{-canvasscr}->addstring($curr_line, 0, "WERD $entry");
        $curr_line++;
    }

    $self->{-canvasscr}->noutrefresh();

    doupdate() unless $no_doupdate;
}


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



sub collect_entries {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    ITER: {
        Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
            key => $self->{probe_id},
            reverse => 1,
            cb => sub {
                my ($k, $v) = @_;

                push @{ $self->{entries} }, $v;
            },
        });
    }
}


sub find_new_entries {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
        key => $self->{probe_id},
        offset => $self->{last_update} // (curr_time() - 3600),
        cb => sub {
            my ($k, $v) = @_;

            $self->{last_update} = $v;
            my $entry = $entry_db->get($v);

            $self->process_new_entry($entry);
        },
    });

    $txn->commit;
}


sub process_new_entry {
    my ($self, $entry) = @_;

    $self->{latest_entry} = $entry;
}




1;
