package Vmprobe::Daemon::DB;

use common::sense;

use LMDB_File qw(:flags :cursor_op);

use Vmprobe::Util;



## global

sub get_global_db {
    my ($txn) = @_;

    my $global_db = $txn->OpenDB({
                        dbname => 'global',
                        flags => MDB_CREATE,
                    });

    return $global_db;
}


sub check_arch {
    my ($txn) = @_;

    my $global_db = get_global_db($txn);

    my $word = pack("j", 1); ## MDB_INTEGERKEY assumes IV

    my $word_from_db = $global_db->get('arch_word_format');

    if (!defined $word_from_db) {
        $global_db->put('arch_word_format', $word);
        return;
    }

    my $len = length($word);
    my $len_from_db = length($word_from_db);

    die "incompatible DB: word size is $len_from_db, need $len"
            if $len != $len_from_db;

    die "incompatible DB: endianness"
            if $word ne $word_from_db;
}




## remote

sub get_remote_db {
    my ($txn) = @_;

    my $remote_db = $txn->OpenDB({
                        dbname => 'remote',
                        flags => MDB_CREATE | MDB_INTEGERKEY,
                    });

    return $remote_db;
}

sub foreach_remote {
    my ($txn, $cb) = @_;

    my $remote_db = get_remote_db($txn);

    _foreach_db($remote_db, sub {
        my ($key, $value) = @_;

        $cb->(sereal_decode($value));
    });
}


sub insert_remote {
    my ($txn, $remote) = @_;

    my $remote_db = get_remote_db($txn);

    my $id = get_next_id($txn, 'remote');

    $remote->{id} = $id;

    $remote_db->put($id, sereal_encode($remote));
}


sub delete_remote {
    my ($txn, $id) = @_;

    my $remote_db = get_remote_db($txn);

    $remote_db->del($id);
}




## snapshot


sub get_snapshot_db {
    my ($txn) = @_;

    my $snapshot_db = $txn->OpenDB({
                        dbname => 'snapshot',
                        flags => MDB_CREATE | MDB_INTEGERKEY,
                    });

    return $snapshot_db;
}

sub store_snapshot {
    my ($txn, $snapshot) = @_;

    my $snapshot_db = get_snapshot_db($txn);

    my $id = get_next_id($txn, 'snapshot');

    $snapshot->{id} = $id;

    $snapshot_db->put($id, sereal_encode($snapshot));
}

sub get_snapshot {
    my ($txn, $snapshotId) = @_;

    my $snapshot_db = get_snapshot_db($txn);

    my $snapshot_encoded = $snapshot_db->get($snapshotId);

    return undef if !defined $snapshot_encoded;

    return sereal_decode($snapshot_encoded);
}



### Utils


sub get_next_id {
    my ($txn, $table) = @_;

    my $counter_name = "next_id_$table";

    my $global_db = get_global_db($txn);

    my $id = $global_db->get($counter_name);
 
    if (defined $id) {
        $id = unpack("j", $id);
    } else {
        $id = 1;
    }

    $global_db->put($counter_name, pack("j", $id + 1));

    return $id;
}


sub _foreach_db {
    my ($db, $cb) = @_;

    my $cursor = my $cursor = $db->Cursor;

    my ($key, $value);

    eval {
        $cursor->get($key, $value, MDB_FIRST);
    };

    return if $@;

    $cb->($key, $value);

    while(1) {
        eval {
            $cursor->get($key, $value, MDB_NEXT);
        };

        return if $@;

        $cb->($key, $value);
    }
}


1;
