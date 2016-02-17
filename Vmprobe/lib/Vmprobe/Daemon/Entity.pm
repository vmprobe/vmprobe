package Vmprobe::Daemon::Entity;

use common::sense;

use LMDB_File qw(:flags :cursor_op);


sub new { 
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{api} = $args{api};

    $self->init();

    return $self;
}


sub init {}


sub get_remote {
    my ($self, $id) = @_;

    my $remote = $self->{api}->{entities}->{'remote'}->{remote_objs_by_id}->{$id};

    die "no such remoteId '$id'" if !defined $remote;

    return $remote;
}

sub lmdb_env {
    my ($self) = @_;

    return $self->{api}->{lmdb};
}


sub foreach_db {
    my ($self, $db, $cb) = @_;

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