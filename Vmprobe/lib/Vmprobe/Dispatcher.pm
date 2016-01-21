package Vmprobe::Dispatcher;

use common::sense;

use List::MoreUtils;
use Callback::Frame;

use Vmprobe::Remote;
use Vmprobe::Util;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    return $self;
}

sub add_remote {
    my ($self, $host) = @_;

    my $remote = Vmprobe::Remote->new(
        host => $host,
        on_state_change => sub {
            my $remote = shift;
            foreach my $resource_id (keys %{ $self->{resources} }) {
                $self->{resources}->{$resource_id}->on_remote_state_change($remote);
            }

            $self->drain_updates();
        },
    );

    push @{ $self->{remotes} }, $remote;

    foreach my $resource_id (keys %{ $self->{resources} }) {
        $self->{resources}->{$resource_id}->on_add_remote($remote);
    }

    foreach my $resource_id (keys %{ $self->{resources} }) {
        $self->{resources}->{$resource_id}->on_init_remote($remote);
    }

    $remote->probe('version', {}, sub {
        my ($version) = @_;
        $remote->add_version_info($version);
    });

    return $remote;
}

sub find_remote {
    my ($self, $host) = @_;

    foreach my $remote (@{ $self->{remotes} }) {
        return $remote if $remote->{host} eq $host;
    }

    die "couldn't find remote '$host'";
}

sub remove_remote {
    my ($self, $host) = @_;

    my $position = List::MoreUtils::first_index { $_->{host} eq $host } @{ $self->{remotes} };

    my $remote = $self->{remotes}->[$position];

    foreach my $resource_id (keys %{ $self->{resources} }) {
        $self->{resources}->{$resource_id}->on_remove_remote($remote);
    }

    splice(@{ $self->{remotes} }, $position, 1);
}


sub new_session {
    my ($self) = @_;

    my $token = get_session_token();

    my $session = {
        msgs => [],
        token => $token,
    };

    foreach my $resource_id (keys %{ $self->{resources} }) {
        my $resource = $self->{resources}->{$resource_id};
        push @{ $session->{msgs} }, {
            $resource_id => {
                '$set' => $resource->{view},
            },
        };
    }

    $self->{sessions}->{$token} = $session;

    return $session;
}


sub get_session {
    my ($self, $token) = @_;

    return $self->{sessions}->{$token};
}


sub get_msgs {
    my ($self, $session, $cb) = @_;

    if (@{ $session->{msgs} }) {
        my $msgs = $session->{msgs};
        $session->{msgs} = [];
        $cb->($msgs);
    } else {
        $session->{getter_cb} = $cb;
    }
}



sub new_resource {
    my ($self, $resource_name) = @_;

    die "bad resource name" if !Vmprobe::Util::is_valid_package_name($resource_name);

    my $package_name = "Vmprobe::Resource::$resource_name";

    eval "require $package_name" || die "unable to load package $package_name: $@";

    my $token = get_session_token();

    my $resource = $package_name->new($self, $token);

    $self->{resources}->{$token} = $resource;

    foreach my $remote (@{ $self->{remotes} }) {
        $resource->on_add_remote($remote);
    }

    foreach my $remote (@{ $self->{remotes} }) {
        $resource->on_init_remote($remote);
    }
}


sub close_resource {
    my ($self, $resource_id) = @_;

    $self->queue_update({ '$unset' => $resource_id });

    $self->{resources}->{$resource_id}->{zombie} = 1;

    delete $self->{resources}->{$resource_id};
}



sub queue_update {
    my ($self, $update) = @_;

    foreach my $token (keys %{ $self->{sessions} }) {
        push @{ $self->{sessions}->{$token}->{msgs} }, $update,
    }

    $self->drain_updates() unless $self->{drain_update_corked};
}


sub drain_updates {
    my ($self) = @_;

    foreach my $token (keys %{ $self->{sessions} }) {
        my $session = $self->{sessions}->{$token};

        if (@{ $session->{msgs} } && $session->{getter_cb}) {
            my $msgs = $session->{msgs};
            my $getter_cb = $session->{getter_cb};

            $session->{msgs} = [];
            delete $session->{getter_cb};

            $getter_cb->($msgs);
        }
    }
}



sub process_msg {
    my ($self, $msg) = @_;

    if (defined $msg->{new}) {
        $self->new_resource($msg->{new});
    } elsif (defined $msg->{close}) {
        $self->close_resource($msg->{close});
    } elsif (defined $msg->{resource}) {
        my $resource = $self->{resources}->{$msg->{resource}} || die "no such resource";
        my $cmd = "cmd_$msg->{cmd}";

        frame_try {
            $resource->$cmd($msg->{args});
        } frame_catch {
            say STDERR "error: $@";
            $resource->add_error($@);
        }
    } else {
        warn "unknown message";
    }
}



1;
