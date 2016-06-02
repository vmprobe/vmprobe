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

    $self->{window_size} = $self->initial_window_size();
    $self->{skip} = $self->initial_skip();

    $self->backfill_entries();

    return $self;
}



## Over-ride

sub initial_window_size { 1 }
sub initial_skip { 0 }


sub reset_entries {
    my ($self) = @_;

    delete $self->{latest};
}


sub process_entry {
    my ($self, $entry, $entry_id) = @_;

    $self->{latest} = { %$entry, entry_id => $entry_id };
}




## Control methods

sub change_window_skip {
    my ($self, $new_window_size, $new_skip) = @_;

    $self->reset_entries();
    delete $self->{last_seen_entry_id};

    $self->{window_size} = $new_window_size;
    $self->{skip} = $new_skip;

    $self->backfill_entries();
}





## Internal


sub backfill_entries {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    my @entry_ids;

    ITER: {
        Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
            key => $self->{probe_id},
            reverse => 1,
            cb => sub {
                my ($k, $v) = @_;

                next if @entry_ids && $entry_ids[-1] - $v < $self->{skip};

                push @entry_ids, $v;
                last ITER if @entry_ids >= $self->{window_size};
            },
        });
    }

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    foreach my $entry_id (reverse @entry_ids) {
        my $entry = $entry_db->get($entry_id);
        $self->process_entry_wrapper($entry, $entry_id);
    }

    $txn->commit;
}


sub find_new_entries {
    my ($self) = @_;

    my $txn = new_lmdb_txn();

    my $entry_db = Vmprobe::DB::Entry->new($txn);

    Vmprobe::DB::EntryByProbe->new($txn)->iterate_dups({
        key => $self->{probe_id},
        offset => $self->{last_seen_entry_id},
        cb => sub {
            my ($k, $v) = @_;

            next if exists $self->{last_seen_entry_id} && $v - $self->{last_seen_entry_id} < $self->{skip};

            my $entry = $entry_db->get($v);
            $self->process_entry_wrapper($entry, $v);
        },
    });

    $txn->commit;
}


sub process_entry_wrapper {
    my ($self, $entry, $entry_id) = @_;

    $self->{last_seen_entry_id} = $entry_id;
    $self->process_entry($entry, $entry_id);
}




1;
