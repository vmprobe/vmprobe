package Vmprobe::Daemon::Entity::Standby;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Time::HiRes;

use Vmprobe::Util;
use Vmprobe::Daemon::DB::Standby;



sub init {
    my ($self) = @_;

    $self->{standbys_by_id} = {};

    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->foreach(sub {
        my $key = shift;
        my $standby = shift;

        $self->load_standby_into_cache($standby);
    });

    $txn->commit;
}



sub load_standby_into_cache {
    my ($self, $standby) = @_;

    my $id = $standby->{id};

    $self->{standbys_by_id}->{$id} = $standby;
}


sub unload_standby_from_cache {
    my ($self, $standby) = @_;

    my $id = $standby->{id};

    delete $self->{standbys_by_id}->{$id};
}


sub remote_removed {
    my ($self, $remoteId, $txn) = @_;

    my $db = Vmprobe::Daemon::DB::Standby->new($txn);

    foreach my $id (keys %{ $self->{standbys_by_id} }) {
        my $standby = $self->get_standby_by_id($id);

        if (grep { $_ == $remoteId } @{ $standby->{remoteIds} }) {
            $standby->{remoteIds} = [ grep { $_ != $remoteId } @{ $standby->{remoteIds} } ];

            if (defined $standby->{primary} && $standby->{primary} == $remoteId) {
                $standby->{primary} = undef;
            }

            $db->update($standby);

            $self->load_standby_into_cache($standby);
        }
    }
}




sub get_standby_by_id {
    my ($self, $id) = @_;

    my $standby = $self->{standbys_by_id}->{$id};

    return if !$standby;

    return {
        %$standby,
    };
}


sub validate_remoteIds {
    my ($self, $standby) = @_;

    my $remoteIds_seen = {};

    $standby->{remoteIds} = [ $standby->{remoteIds} ] if ref $standby->{remoteIds} ne 'ARRAY';

    foreach my $remoteId (@{ $standby->{remoteIds} }) {
        return "unknown remoteId: $remoteId" if !$self->get_remote($remoteId);

        return "duplicate remoteId: $remoteId" if $remoteIds_seen->{$remoteId};

        $remoteIds_seen->{$remoteId} = 1;

        $remoteId += 0;
    }

    return;
}


sub validate_paths {
    my ($self, $standby) = @_;

    ## FIXME: normalize paths

    my $paths_seen = {};

    $standby->{paths} = [ $standby->{paths} ] if ref $standby->{paths} ne 'ARRAY';

    foreach my $path (@{ $standby->{paths} }) {
        return "paths must begin with /" if $path !~ m{\A/};

        return "duplicate path: $path" if $paths_seen->{$path};

        $paths_seen->{$path} = 1;
    }

    return;
}



sub ENTRY_get_all_standbys {
    my ($self, $c) = @_;

    my $standbys = [];

    foreach my $id (keys %{ $self->{standbys_by_id} }) {
        push @$standbys, $self->get_standby_by_id($id);
    }

    return $standbys;
}


sub ENTRY_create_new_standby {
    my ($self, $c) = @_;

    my $standby = {};

    $standby->{remoteIds} = delete $c->params->{remoteIds} || [];
    my $err = $self->validate_remoteIds($standby);
    return $c->err_bad_request($err) if defined $err;

    $standby->{primary} = delete $c->params->{primary};
    if (defined $standby->{primary}) {
        return $c->err_bad_request("primary not a member of remoteIds")
            if !grep { $standby->{primary} == $_ } @{ $standby->{remoteIds} };
    }

    $standby->{paths} = delete $c->params->{paths} || [];
    my $err = $self->validate_paths($standby);
    return $c->err_bad_request($err) if defined $err;

    return $c->err_unknown_params if $c->is_params_left;


    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->insert($standby);

    $self->load_standby_into_cache($standby);

    $txn->commit;

    return $standby;
}


sub ENTRY_get_standby {
    my ($self, $c) = @_;

    my $id = $c->url_args->{standbyId};
    my $standby = $self->get_standby_by_id($id);
    return $c->err_not_found('no such standbyId') if !$standby;

    return $standby;
}


sub ENTRY_update_standby {
    my ($self, $c) = @_;

    my $update;

    my $id = $c->url_args->{standbyId};
    my $standby = $self->get_standby_by_id($id);
    return $c->err_not_found('no such standbyId') if !$standby;

    if (defined $c->params->{remoteIds}) {
        $update->{remoteIds} = delete $c->params->{remoteIds};
        my $err = $self->validate_remoteIds($update);
        return $c->err_bad_request($err) if defined $err;
        $standby->{remoteIds} = $update->{remoteIds};
    }

    if (defined $c->params->{primary}) {
        $update->{primary} = delete $c->params->{primary};
        return $c->err_bad_request("primary not a member of remoteIds")
            if !grep { $update->{primary} == $_ } @{ $standby->{remoteIds} };
        $standby->{primary} = $update->{primary};
    }

    if (defined $c->params->{paths}) {
        $update->{paths} = delete $c->params->{paths};
        my $err = $self->validate_paths($update);
        return $c->err_bad_request($err) if defined $err;
        $standby->{paths} = $update->{paths};
    }

    return $c->err_bad_request("need to provide one or more params to update") if !keys(%$update);

    return $c->err_unknown_params if $c->is_params_left;


    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->update($standby);

    $txn->commit;
    $self->load_standby_into_cache($standby);

    return $standby;
}


sub ENTRY_delete_standby {
    my ($self, $c) = @_;

    my $id = $c->url_args->{standbyId};
    my $standby = $self->get_standby_by_id($id);
    return $c->err_not_found('no such standbyId') if !$standby;

    return $c->err_unknown_params if $c->is_params_left;


    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->delete($id);

    $self->unload_standby_from_cache($standby);

    $txn->commit;

    return {};
}



1;
