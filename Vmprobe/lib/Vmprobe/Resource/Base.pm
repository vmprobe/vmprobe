package Vmprobe::Resource::Base;

use common::sense;
use List::MoreUtils;
use Carp;
use Guard;
use Time::HiRes;

use Vmprobe::Util;
use Vmprobe::ReactUpdate;


sub new {
    my ($class, $dispatcher, $token) = @_;

    my $self = {
        dispatcher => $dispatcher,
        token => $token,
    };
    bless $self, $class;

    my $params = $self->get_initial_params;
    my $view = $self->get_initial_view;

    $view->{params} = $params;

    $class =~ /(\w+)$/;
    $view->{type} = $1;

    $self->update({
        '$set' => $view,
    });

    $self->on_ready();

    return $self;
}


sub get_initial_view {
    return {};
}


sub get_initial_params {
    return {};
}



sub update {
    my ($self, $update) = @_;

    return if $self->{zombie};

    $self->{view} = Vmprobe::ReactUpdate::update($self->{view}, $update);

    my $external_update = {
        $self->{token} => $update,
    };

    $self->{dispatcher}->queue_update($external_update);
}


sub get_remote_position {
    my ($self, $remote) = @_;

    my $position = List::MoreUtils::first_index { $_->{host} eq $remote->{host} }
                                                @{ $self->{view}->{remotes} };

    croak "unable to find remote" if $position == -1;

    return $position;
}



sub shutdown {
    my ($self) = @_;

    $self->{zombie} = 1;
}



sub cmd_params {
    my ($self, $args) = @_;

    $self->update({ params => $args });

    $self->on_params_update();
}



sub add_error {
    my ($self, $err_msg) = @_;

    $self->update({ errors => { '$push' => [ $err_msg ] } });
}




sub start_job {
    my ($self, $job_type, $job_desc) = @_;

    my $token = get_session_token();

    my $job = {
        type => $job_type,
        desc => $job_desc,
        start => Time::HiRes::time(),
    };

    $self->update({ jobs => { $token => { '$set' => $job } } });

    return guard {
        $self->update({ jobs => { '$unset' => $token } });
    };
}



sub on_ready {}
sub on_add_remote {}
sub on_init_remote {}
sub on_remove_remote {}
sub on_remote_state_change {}
sub on_params_update {}





1;
