package Vmprobe::Daemon::Entity::Remote;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Vmprobe::Util;

use LMDB_File qw(:flags :cursor_op);


sub get_all_remotes {
    my ($self, $c) = @_;

    my $txn = $c->lmdb->BeginTxn();

    my $remote_db = $txn->OpenDB({
                        dbname => 'remote',
                        flags => MDB_CREATE,
                    });

    my $remotes = [];

    $c->foreach_db($remote_db, sub {
        my ($key, $value) = @_;

        next if $key !~ /^\d+$/;

        push @$remotes, sereal_decode($value);
    });

    return $remotes;
}


sub create_new_remote_anon {
    my ($self, $c) = @_;

    my $remote = {};

    $remote->{host} = delete $c->params->{host} || return $c->err_bad_request("need to specify host");
    $remote->{name} = delete $c->params->{name} || return $c->err_bad_request("need to specify name");
   
    return $c->err_bad_request("unknown parameters: " . join(', ', keys %{ $c->params })) if keys %{ $c->params };


    my $txn = $c->lmdb->BeginTxn();

    my $remote_db = $txn->OpenDB({
                        dbname => 'remote',
                        flags => MDB_CREATE,
                    });

    $remote->{id} = $remote_db->get('next') || 1;

    $remote_db->put($remote->{id}, sereal_encode($remote));

    $remote_db->put('next', $remote->{id} + 1);

    $txn->commit;

    return $remote;
}


1;
