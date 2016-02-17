package Vmprobe::Daemon::Entity::Snapshot;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use LMDB_File qw(:flags :cursor_op);

use Vmprobe::Util;



sub init {
    my ($self) = @_;
}





sub ENTRY_create_new_snapshot {
    my ($self, $c) = @_;

    my $snapshot = {};

    $snapshot->{remoteId} = delete $c->params->{remoteId} || return $c->err_bad_request("need to specify remoteId");
    $snapshot->{path} = delete $c->params->{path} || return $c->err_bad_request("need to specify path");
    return $c->err_bad_request("path must start with /") if $snapshot->{path} !~ m{^/};

    return $c->err_unknown_params if $c->is_params_left;


    my $remote = $self->get_remote($snapshot->{remoteId});
    return $c->err_bad_request("no such remoteId") if !$remote;

    return sub {
        my $responder = shift;

        $remote->probe(
            'cache::snapshot',
            {
                path => $snapshot->{path},
                sparse => 1,
            },
            sub {
                my ($res) = @_;

                my $snapshotId = store_snapshot($res->{snapshot});
                $responder->({ snapshotId => $snapshotId });
            }
        );
    };
}




sub store_snapshot {
}


1;
