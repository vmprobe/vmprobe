package Vmprobe::Viewer::Probe::Base;

use common::sense;

use Curses;

use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::Entry;

use parent 'Curses::UI::Widget';


sub new {
    my ($class, %userargs) = @_;

    my %args = ( 
        %userargs,
    );

    my $self = $class->SUPER::new( %args );

    die "need to provide probe_id" if !defined $self->{probe_id};

    {
        my $txn = new_lmdb_txn();

        $self->{summary} = Vmprobe::DB::Probe->new($txn)->get($self->{probe_id});

        $txn->commit;
    }


    my $bindings = $self->bindings();

    foreach my $key (keys %{ $bindings }) {
        $self->set_binding($bindings->{$key}, $key);
    }


    $self->{new_entry_watcher} = switchboard->listen("probe-$self->{probe_id}", sub {
        $self->find_new_entries();
        $self->draw(0) if !$self->hidden && $self->in_topwindow;
    });

    $self->backfill_entries($self->history_size());

    return $self;
}


sub draw {
    my $self = shift;
    my $no_doupdate = shift || 0;

    $self->SUPER::draw(1) or return $self;

    $self->render($self->{-canvasscr});

    $self->{-canvasscr}->noutrefresh();
    doupdate() unless $no_doupdate;
}



sub history_size { 1 }


sub bindings { {} }


sub render {
    die "must implement render";
}


sub process_entry {
    my ($self, $entry) = @_;

    return $entry;
}


sub backfill_entries {
    my ($self, $history_size) = @_;

    my $txn = new_lmdb_txn();

    my @entry_ids;

    ITER: {
        Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
            key => $self->{probe_id},
            reverse => 1,
            cb => sub {
                my ($k, $v) = @_;

                push @entry_ids, $v;

                last ITER if @entry_ids > $history_size;
            },
        });
    }

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    foreach my $entry_id (reverse @entry_ids) {
        my $entry = $entry_db->get($entry_id);

        $self->process_entry_wrapper($entry_id, $entry);
    }

    $txn->commit;
}


sub find_new_entries {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
        key => $self->{probe_id},
        offset => $self->{last_seen_entry},
        cb => sub {
            my ($k, $v) = @_;

            my $entry = $entry_db->get($v);

            $self->process_entry_wrapper($v, $entry);
        },
    });

    $txn->commit;
}


sub process_entry_wrapper {
    my ($self, $entry_id, $entry) = @_;

    $self->{last_seen_entry} = $entry_id;
    unshift @{ $self->{entries} }, $self->process_entry($entry);

    pop @{ $self->{entries} } if @{ $self->{entries} } > $self->history_size();
}



=pod
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







sub process_new_entry {
    my ($self, $entry) = @_;

    $self->{latest_entry} = $entry;
}

=cut



1;
