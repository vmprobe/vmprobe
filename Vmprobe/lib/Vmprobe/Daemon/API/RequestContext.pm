package Vmprobe::Daemon::API::RequestContext;

use common::sense;


sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    return $self;
}


sub req { shift->{req} }
sub res { shift->{res} }
sub url_args { shift->{url_args} }
sub params { shift->{params} }


sub err_bad_request {
    my ($self, $msg) = @_;

    $msg //= 'bad request';

    $self->{res}->status(400);

    return {
        error => $msg,
    };
}


sub err_not_found {
    my ($self, $msg) = @_;

    $msg //= 'resource not found';

    $self->{res}->status(404);

    return {
        error => $msg,
    };
}


1;
