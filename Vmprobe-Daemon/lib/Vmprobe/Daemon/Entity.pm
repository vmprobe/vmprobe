package Vmprobe::Daemon::Entity;

use common::sense;


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

    return $remote;
}

sub lmdb_env {
    my ($self) = @_;

    return $self->{api}->{lmdb};
}



1;
