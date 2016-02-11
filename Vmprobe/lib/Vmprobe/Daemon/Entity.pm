package Vmprobe::Daemon::Entity;

use common::sense;


sub new { 
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{api} = $args{api};

    return $self;
}



1;
