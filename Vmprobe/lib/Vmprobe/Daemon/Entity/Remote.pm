package Vmprobe::Daemon::Entity::Remote;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use LMDB_File qw(:flags :cursor_op);

use Vmprobe::Util;
use Vmprobe::Remote;



sub init {
    my ($self) = @_;

    my $txn = $self->lmdb_env->BeginTxn();

    my $remote_db = $txn->OpenDB({
                        dbname => 'remote',
                        flags => MDB_CREATE,
                    });

    $self->{remotes_by_id} = {};
    $self->{remote_ids_by_host} = {};
    $self->{remote_objs_by_id} = {};

    $self->foreach_db($remote_db, sub {
        my ($key, $value) = @_;

        return if $key !~ /^\d+$/;

        $self->load_remote(sereal_decode($value));
    });

    $txn->commit;
}



sub load_remote {
    my ($self, $remote) = @_;

    my $id = $remote->{id};

    $self->{remotes_by_id}->{$id} = $remote;
    $self->{remote_ids_by_host}->{$remote->{host}} = $id;

    $self->{remote_objs_by_id}->{$id} =
        Vmprobe::Remote->new(
            ssh_to_localhost => 1,
            host => $remote->{host},
            on_state_change => sub {},
        );
}


sub unload_remote {
    my ($self, $remote) = @_;

    my $id = $remote->{id};

    delete $self->{remotes_by_id}->{$id};
    delete $self->{remote_ids_by_host}->{$remote->{host}};

    my $remote_obj = delete $self->{remote_objs_by_id}->{$id};
    $remote_obj->shutdown;
}


sub get_remote_by_id {
    my ($self, $id) = @_;

    my $remote = $self->{remotes_by_id}->{$id};

    return if !$remote;

    my $remote_obj = $self->{remote_objs_by_id}->{$id};

    return {
        %$remote,

        state => $remote_obj->get_state(),
        num_connections => $remote_obj->get_num_connections(),

        $remote_obj->{last_error_message} ?
          (error_message => $remote_obj->{last_error_message}) : (),
        $remote_obj->{version_info} ?
          (version_info => $remote_obj->{version_info}) : (),
    };
}



sub ENTRY_get_all_remotes {
    my ($self, $c) = @_;

    my $remotes = [];

    foreach my $id (keys %{ $self->{remotes_by_id} }) {
        push @$remotes, $self->get_remote_by_id($id);
    }

    return $remotes;
}


sub ENTRY_get_remote {
    my ($self, $c) = @_;

    my $id = $c->url_args->{remoteId};
    my $remote = $self->get_remote_by_id($id);
    return $c->err_not_found('no such remote id') if !$remote;

    return $remote;
}


sub ENTRY_create_new_remote {
    my ($self, $c) = @_;

    my $remote = {};

    $remote->{host} = delete $c->params->{host} || return $c->err_bad_request("need to specify host");
    $remote->{host} = lc($remote->{host});
    return $c->err_bad_request("remote with host $remote->{host} already exists")
        if exists $self->{remote_ids_by_host}->{$remote->{host}};

    return $c->err_unknown_params if $c->is_params_left;


    my $txn = $self->lmdb_env->BeginTxn();

    my $remote_db = $txn->OpenDB({ dbname => 'remote', });

    $remote->{id} = $remote_db->get('next') || 1;

    $remote_db->put($remote->{id}, sereal_encode($remote));

    $remote_db->put('next', $remote->{id} + 1);

    $self->load_remote($remote);

    $txn->commit;

    return $remote;
}


sub ENTRY_delete_remote {
    my ($self, $c) = @_;

    my $id = $c->url_args->{remoteId};
    my $remote = $self->get_remote_by_id($id);
    return $c->err_not_found('no such remote id') if !$remote;

    my $txn = $self->lmdb_env->BeginTxn();

    my $remote_db = $txn->OpenDB({ dbname => 'remote', });

    $remote_db->del($id);

    $self->unload_remote($remote);

    $txn->commit;

    return {};
}


1;
