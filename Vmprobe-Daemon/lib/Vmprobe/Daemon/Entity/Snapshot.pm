package Vmprobe::Daemon::Entity::Snapshot;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Time::HiRes;

use Vmprobe::Util;
use Vmprobe::Daemon::DB::Snapshot;



sub init {
    my ($self) = @_;
}





sub ENTRY_take_snapshot {
    my ($self, $c) = @_;

    my $params = {};

    $params->{remoteId} = delete $c->params->{remoteId} || return $c->err_bad_request("need to specify remoteId");
    $params->{path} = delete $c->params->{path} || return $c->err_bad_request("need to specify path");
    return $c->err_bad_request("path must start with /") if $params->{path} !~ m{^/};

    return $c->err_unknown_params if $c->is_params_left;


    my $remote = $self->get_remote($params->{remoteId});
    return $c->err_bad_request("no such remoteId") if !$remote;

    return sub {
        my $responder = shift;

        my $start_time = Time::HiRes::time();

        $remote->probe(
            'cache::snapshot',
            {
                path => $params->{path},
            },
            sub {
                my ($res) = @_;

                my $end_time = Time::HiRes::time();

                my $to_save = {
                    remoteId => $params->{remoteId},
                    path => $params->{path},
                    snapshot => $res->{snapshot},
                    time => $start_time,
                    duration => $end_time - $start_time,
                };

                my $txn = $self->lmdb_env->BeginTxn();

                Vmprobe::Daemon::DB::Snapshot->new($txn)->insert($to_save);

                $txn->commit;

                $responder->({ snapshotId => $to_save->{id} });
            }
        );
    };
}



sub ENTRY_restore_snapshot {
    my ($self, $c) = @_;

    my $params = {};

    $params->{remoteId} = delete $c->params->{remoteId};

    return $c->err_unknown_params if $c->is_params_left;

    my $txn = $self->lmdb_env->BeginTxn();

    my $snapshot = Vmprobe::Daemon::DB::Snapshot->new($txn)->get($c->url_args->{snapshotId});
    return $c->err_bad_request('no such snapshotId') if !defined $snapshot;

    $txn->commit;

    my $remote;

    if (exists $params->{remoteId}) {
        $remote = $self->get_remote($params->{remoteId});
        return $c->err_bad_request("no such remoteId") if !$remote;
    } else {
        $remote = $self->get_remote($snapshot->{remoteId});
        return $c->err_bad_request("remoteId in snapshot has been deleted, please specify new remoteId") if !$remote;
    }

    return sub {
        my $responder = shift;

        $remote->probe(
            'cache::restore',
            {
                path => $snapshot->{path},
                snapshot => $snapshot->{snapshot},
            },
            sub {
                my ($res) = @_;

                $responder->({});
            },
        );
    };
}



1;
