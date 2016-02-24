package Vmprobe::Resource::Base::AllRemotes;

use common::sense;

use parent 'Vmprobe::Resource::Base';

use AnyEvent;
use Callback::Frame;


sub get_initial_view {
    return {
        remotes => [],
    };
}


sub on_add_remote {
    my ($self, $remote) = @_;

    $self->update({
        remotes => {
            '$push' => [{ host => $remote->{host} }]
        }
    });
}


sub on_init_remote {
    my ($self, $remote) = @_;

    $self->_update_polls($remote);
}


sub on_remote_state_change {
    my ($self, $remote) = @_;

    $self->update({
        remotes => {
            $self->get_remote_position($remote) => {
                '$merge' => {
                    remote_state => $remote->get_state(),
                },
            },
        },
    });
}



sub on_remove_remote {
    my ($self, $remote) = @_;

    $self->_stop_polls($remote);

    delete $self->{remotes}->{$remote->{host}};

    $self->update({
        remotes => {
            '$splice' => [[$self->get_remote_position($remote), 1]],
        }
    });
}



sub on_params_update {
    my ($self) = @_;

    foreach my $remote (@{ $self->{dispatcher}->{remotes} }) {
        $self->_update_polls($remote);
    }
}



sub _update_polls {
    my ($self, $remote) = @_;

    $self->_stop_polls($remote);

    my $new_polls = $self->poll_remote($remote);

    $new_polls = [ $new_polls ] if ref($new_polls) ne 'ARRAY';

    foreach my $poll (@$new_polls) {
        $poll->{handler} = sub {
            undef $poll->{timer};

            frame_try {
                $remote->probe($poll->{probe_name}, $poll->{args}, sub {
                    return if $poll->{stop};

                    my $result = shift;

                    $poll->{on_result}->($result);

                    $poll->{timer} = AE::timer($poll->{frequency} // 1, 0, $poll->{handler});
                });
            } frame_catch {
                say STDERR "error in probe: $@";
                $poll->{timer} = AE::timer($poll->{frequency} // 1, 0, $poll->{handler});
            };
        };

        $poll->{handler}->();
    }

    $self->{remotes}->{$remote->{host}}->{polls} = $new_polls;
}


sub _stop_polls {
    my ($self, $remote) = @_;

    foreach my $poll (@{ $self->{remotes}->{$remote->{host}}->{polls} }) {
        $poll->{stop} = 1;
        delete $poll->{timer};
        delete $poll->{handler};
        delete $poll->{on_result};
    }

    delete $self->{remotes}->{$remote->{host}}->{polls};
}



sub shutdown {
    my ($self) = @_;

    $self->SUPER::shutdown();

    foreach my $remote (@{ $self->{dispatcher}->{remotes} }) {
        $self->on_remove_remote($remote);
    }
}



1;
