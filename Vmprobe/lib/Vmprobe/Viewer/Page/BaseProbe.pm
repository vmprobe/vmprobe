package Vmprobe::Viewer::Page::BaseProbe;

use common::sense;

use Vmprobe::RunContext;
use Vmprobe::DB::Probe;

use parent 'Vmprobe::Viewer::Page::Base';


sub init {
    my ($self) = @_;

    die "need to provide probe_id" if !defined $self->{probe_id};

    {
        my $txn = new_lmdb_txn();

        $self->{summary} = Vmprobe::DB::Probe->new($txn)->get($self->{probe_id});

        $txn->commit;
    }


    $self->{new_entry_watcher} = switchboard->listen("probe-$self->{probe_id}", sub {
        $self->find_new_entries();
        $self->redraw();
    });

    $self->backfill_entries($self->history_size());

    return $self;
}



sub history_size { 1 }

sub process_entry {
    my ($self, $entry, $entry_id) = @_;

    return { %$entry, entry_id => $entry_id };
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
    unshift @{ $self->{entries} }, $self->process_entry($entry, $entry_id);

    pop @{ $self->{entries} } if @{ $self->{entries} } > $self->history_size();
}



1;
