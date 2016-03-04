package Vmprobe::Daemon::Entity::Remote;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Vmprobe::Remote;
use Vmprobe::Daemon::Config;
use Vmprobe::Daemon::DB::Remote;



sub init {
    my ($self) = @_;

    $self->{remotes_by_id} = {};
    $self->{remote_ids_by_host} = {};
    $self->{remote_objs_by_id} = {};

    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Remote->new($txn)->foreach(sub {
        my $key = shift;
        my $remote = shift;

        $self->load_remote_into_cache($remote);
    });

    $txn->commit;
}



sub load_remote_into_cache {
    my ($self, $remote) = @_;

    my $id = $remote->{id};

    $self->{remotes_by_id}->{$id} = $remote;
    $self->{remote_ids_by_host}->{$remote->{host}} = $id;

    $self->{remote_objs_by_id}->{$id} =
        Vmprobe::Remote->new(
            ssh_to_localhost => 1,
            host => $remote->{host},
            on_state_change => sub {},
            max_connections => config->{remotes}->{max_connections_per_remote} || 3,
        );
}


sub unload_remote_from_cache {
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

    return {
        %$remote,
    };
}


sub populate_remote_with_state {
    my ($self, $remote) = @_;

    my $remote_obj = $self->{remote_objs_by_id}->{$remote->{id}};

    $remote->{state} = $remote_obj->get_state();
    $remote->{num_connections} = $remote_obj->get_num_connections();

    $remote->{last_error_message} = $remote_obj->{last_error_message}
        if defined $remote_obj->{last_error_message};

    $remote->{version_info} = $remote_obj->{version_info}
        if defined $remote_obj->{version_info};
}



sub ENTRY_get_all_remotes {
    my ($self, $c) = @_;

    my $remotes = [];

    foreach my $id (keys %{ $self->{remotes_by_id} }) {
        my $remote = $self->get_remote_by_id($id);
        $self->populate_remote_with_state($remote);
        push @$remotes, $remote;
    }

    return $remotes;
}


sub ENTRY_get_remote {
    my ($self, $c) = @_;

    my $id = $c->url_args->{remoteId};
    my $remote = $self->get_remote_by_id($id);
    return $c->err_not_found('no such remoteId') if !$remote;

    $self->populate_remote_with_state($remote);

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

    Vmprobe::Daemon::DB::Remote->new($txn)->insert($remote);

    $self->load_remote_into_cache($remote);

    $txn->commit;

    return $remote;
}


sub ENTRY_delete_remote {
    my ($self, $c) = @_;

    my $id = $c->url_args->{remoteId};
    my $remote = $self->get_remote_by_id($id);
    return $c->err_not_found('no such remoteId') if !$remote;

    my $txn = $self->lmdb_env->BeginTxn();

    foreach my $entity (values %{ $self->{api}->{entities} }) {
        $entity->remote_removed($id, $txn);
    }

    Vmprobe::Daemon::DB::Remote->new($txn)->delete($id);

    $self->unload_remote_from_cache($remote);

    $txn->commit;

    return {};
}


1;
