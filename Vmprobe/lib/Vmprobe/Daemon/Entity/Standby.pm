package Vmprobe::Daemon::Entity::Standby;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Time::HiRes;
use Callback::Frame;

use Vmprobe::Util;
use Vmprobe::Daemon::DB::Standby;
use Vmprobe::Cache::Snapshot;



sub init {
    my ($self, $logger) = @_;

    $self->{standbys_by_id} = {};
    $self->{state_by_id} = {};

    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->foreach(sub {
        my $key = shift;
        my $standby = shift;

        $self->load_standby_into_cache($standby);
        $logger->info("Activating standby $standby->{id}");
        $logger->data->{standby} = $standby;
    });

    $txn->commit;
}



sub load_standby_into_cache {
    my ($self, $standby) = @_;

    my $id = $standby->{id};

    $self->{standbys_by_id}->{$id} = $standby;
    $self->{state_by_id}->{$id} //= {};

    $self->probe_primary($id);
}


sub unload_standby_from_cache {
    my ($self, $standby) = @_;

    my $id = $standby->{id};

    delete $self->{standbys_by_id}->{$id};
    delete $self->{state_by_id}->{$id};
}


sub probe_primary {
    my ($self, $id) = @_;

    my $standby = $self->{standbys_by_id}->{$id};
    my $state = $self->{state_by_id}->{$id};

    delete $state->{watcher};

    return if !defined $standby->{primary} || !@{ $standby->{paths} };

    my $cv = AE::cv;

    foreach my $path (@{ $standby->{paths} }) {
        my $logger = $self->get_logger;
        $logger->info("Standby $id, probing primary ($standby->{primary}), path $path");

        $cv->begin;

        my $path_state = ($state->{paths}->{$path}->{$standby->{primary}} //= {});

        frame_try_void {
            my $args = { path => $path };

            if (defined $path_state->{diff} && defined $path_state->{snapshot} && defined $path_state->{connection_id}) {
                $args->{diff} = $path_state->{diff};

                $logger->info("Using delta id $args->{diff}");
            } else {
                delete $path_state->{connection_id};

                $args->{save} = $path_state->{diff} = get_session_token();

                $logger->info("No valid delta, created $args->{save}");
            }

            my $timer = $logger->timer('cache::snapshot');

            $self->get_remote($standby->{primary})->probe('cache::snapshot', $args, sub {
                my ($res, $connection_id) = @_;

                undef $timer;
                $cv->end;

                $path_state->{connection_id} = $connection_id;

                if (defined $res->{delta}) {
                    $logger->data->{delta_size} = length($res->{delta});
                    $path_state->{snapshot} = Vmprobe::Cache::Snapshot::delta($path_state->{snapshot}, $res->{delta});
                } else {
                    $path_state->{snapshot} = $res->{snapshot};
                }

                $logger->data->{snapshot_size} = length($path_state->{snapshot});

                $self->copy_to_standbys($id, $path, \$res->{delta});
            }, $path_state->{connection_id});
        } frame_catch {
            $cv->end;

            my $error = $@;
            chomp $error;
            $logger->error("$error");

            delete $path_state->{connection_id};
            delete $path_state->{diff};
            delete $path_state->{snapshot};
        };
    }

    $cv->cb(sub {
        $state->{watcher} = AE::timer $standby->{refresh}, 0, sub {
            $self->probe_primary($id);
        };
    })
}



sub copy_to_standbys {
    my ($self, $id, $path, $delta_ref) = @_;

    my $standby = $self->{standbys_by_id}->{$id};
    my $state = $self->{state_by_id}->{$id};

    return if !defined $standby->{primary} || !@{ $standby->{paths} };

    foreach my $remoteId (@{ $standby->{remoteIds} }) {
        next if $remoteId == $standby->{primary};

        my $logger = $self->get_logger;
        $logger->info("Standby $id, copying to remoteId $remoteId, path $path");

        $state->{paths}->{$path} //= {};
        my $path_state = ($state->{paths}->{$path}->{$remoteId} //= {});
        my $primary_path_state = ($state->{paths}->{$path}->{$standby->{primary}} //= {});

        next if !defined $primary_path_state->{snapshot};

        if (exists $path_state->{restore_in_progress}) {
            $logger->warn("Restore already in progress, accumulating delta");

            if (exists $path_state->{accumulated_delta_ref}) {
                $path_state->{accumulated_delta_ref} = \Vmprobe::Cache::Snapshot::delta(${ $path_state->{accumulated_delta_ref} }, $$delta_ref);
            } else {
                $path_state->{accumulated_delta_ref} = $delta_ref;
            }

            return;
        }

        $path_state->{restore_in_progress} = 1;

        frame_try_void {
            my $args = { path => $path };

            if (defined $$delta_ref && defined $path_state->{diff} && defined $path_state->{connection_id}) {
                $args->{diff} = $path_state->{diff};
                $args->{delta} = $$delta_ref;

                $logger->info("Using delta id $args->{diff}");
            } else {
                delete $path_state->{connection_id};
                delete $path_state->{diff};

                $args->{snapshot} = $primary_path_state->{snapshot};
                $args->{save} = $path_state->{diff} = get_session_token();

                $logger->info("No valid delta id, created $args->{save}");
            }

            my $timer = $logger->timer('cache::restore');

            $self->get_remote($remoteId)->probe('cache::restore', $args, sub {
                my ($res, $connection_id) = @_;

                undef $timer;

                $path_state->{connection_id} = $connection_id;

                delete $path_state->{restore_in_progress};

                if (exists $path_state->{accumulated_delta_ref}) {
                    $logger->warn("A delta has accumulated, restoring it now...");
                    $self->copy_to_standbys($id, $path, delete $path_state->{accumulated_delta_ref});
                }
            }, $path_state->{connection_id});
        } frame_catch {
            my $error = $@;
            chomp $error;
            $logger->error("$error");

            delete $path_state->{connection_id};
            delete $path_state->{diff};
            delete $path_state->{restore_in_progress};
            delete $path_state->{accumulated_delta_ref};
        };
    }
}


sub change_primary {
    my ($self, $id) = @_;

    my $state = $self->{state_by_id}->{$id};

    delete $state->{paths};
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

    $standby->{refresh} = delete $c->params->{refresh} || 30;
    $standby->{refresh} += 0.0;
    return $c->err_bad_request("invalid refresh interval") if $standby->{refresh} < 0.1;

    $standby->{paths} = delete $c->params->{paths} || [];
    my $err = $self->validate_paths($standby);
    return $c->err_bad_request($err) if defined $err;

    return $c->err_unknown_params if $c->is_params_left;


    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->insert($standby);

    $self->load_standby_into_cache($standby);

    $txn->commit;

    $c->logger->info("Created new standby $standby->{id}");
    $c->logger->data->{standby} = $standby;

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
        $c->logger->info("Updated remoteIds from [" . join(',', @{ $standby->{remoteIds} }) . "] to [" . join(',', @{ $update->{remoteIds} }) . "]");
        $standby->{remoteIds} = $update->{remoteIds};
    }

    if (defined $c->params->{primary}) {
        $update->{primary} = delete $c->params->{primary};
        return $c->err_bad_request("primary not a member of remoteIds")
            if !grep { $update->{primary} == $_ } @{ $standby->{remoteIds} };
        $c->logger->info("Changed primary from remoteId $standby->{primary} to $update->{primary}");
        $standby->{primary} = $update->{primary};
    }

    if (defined $c->params->{paths}) {
        $update->{paths} = delete $c->params->{paths};
        my $err = $self->validate_paths($update);
        return $c->err_bad_request($err) if defined $err;
        $c->logger->info("Updated paths from [" . join(',', @{ $standby->{paths} }) . "] to [" . join(',', @{ $update->{paths} }) . "]");
        $standby->{paths} = $update->{paths};
    }

    if (defined $c->params->{refresh}) {
        $update->{refresh} = delete $c->params->{refresh};
        $update->{refresh} += 0.0;
        return $c->err_bad_request("invalid refresh interval") if $update->{refresh} < 0.1;
        $c->logger->info("Changed refresh interval from $standby->{refresh} to $update->{refresh}");
        $standby->{refresh} = $update->{refresh};
    }

    return $c->err_unknown_params if $c->is_params_left;

    return $c->err_bad_request("need to provide one or more params to update") if !keys(%$update);


    my $txn = $self->lmdb_env->BeginTxn();

    Vmprobe::Daemon::DB::Standby->new($txn)->update($standby);

    $txn->commit;

    $self->load_standby_into_cache($standby);
    if (defined $update->{primary}) {
        $self->change_primary($id);
    }

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

    $c->logger->info("Removed standby $id");

    return {};
}



1;
