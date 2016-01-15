package Vmprobe::Resource::ServerList;

use common::sense;

use parent qw(Vmprobe::Resource::Base);



sub get_initial_view {
    return {
        remotes => [],
    };
}


sub on_add_remote {
    my ($self, $remote) = @_;

    $self->update({
        remotes => {
            '$push' => [{
                host => $remote->{host},
                state => $remote->{state},
                error_message => $remote->{last_error_message},
                version_info => $remote->{version_info},
            }],
        },
    });
}

sub on_remove_remote {
    my ($self, $remote) = @_;

    $self->update({
        remotes => {
            '$splice' => [[$self->get_remote_position($remote), 1]],
        }
    });
}

sub on_remote_state_change {
    my ($self, $remote) = @_;

    $self->update({
        remotes => {
            $self->get_remote_position($remote) => {
                '$merge' => {
                    state => $remote->{state},
                    error_message => $remote->{last_error_message},
                    version_info => $remote->{version_info},
                },
            },
        },
    });
}


sub cmd_add_server {
    my ($self, $args) = @_;

    $self->{dispatcher}->add_remote($args->{host});
}


sub cmd_remove_server {
    my ($self, $args) = @_;

    $self->{dispatcher}->remove_remote($args->{host});
}


1;
