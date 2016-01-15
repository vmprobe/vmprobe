package Vmprobe::Resource::FsCache;

use common::sense;

use parent 'Vmprobe::Resource::Base::AllRemotes';


sub get_initial_params {
    return {
        paths => [],
        buckets => 32,
    };
}


sub poll_remote {
    my ($self, $remote) = @_;

    my @probes;

    foreach my $path (@{ $self->{view}->{params}->{paths} }) {
        push @probes, {
            probe_name => 'cache::summary',
            args => { path => $path, buckets => $self->{view}->{params}->{buckets} },
            on_result => sub {
                my ($result) = @_;

                my $remote_pos = $self->get_remote_position($remote);

                $self->update({
                    remotes => {
                        $remote_pos => {
                            fs_cache => {
                                '$merge' => {
                                    $path => $result->{summary},
                                },
                            }
                        },
                    },
                });
            },
        };
    }

    return \@probes;
}


sub cmd_touch_sel {
    my ($self, $args) = @_;

    my $remote = $self->{dispatcher}->find_remote($args->{host});

    $remote->probe('cache::touch',
                   {
                     path => $args->{path},
                     start_pages => $args->{start_pages},
                     num_pages => $args->{num_pages},
                   },
                   sub { });
}

sub cmd_evict_sel {
    my ($self, $args) = @_;

    my $remote = $self->{dispatcher}->find_remote($args->{host});

    $remote->probe('cache::evict',
                   {
                     path => $args->{path},
                     start_pages => $args->{start_pages},
                     num_pages => $args->{num_pages},
                   },
                   sub { });
}


1;
