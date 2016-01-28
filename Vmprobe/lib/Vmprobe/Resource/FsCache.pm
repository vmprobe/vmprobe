package Vmprobe::Resource::FsCache;

use common::sense;

use parent 'Vmprobe::Resource::Base::AllRemotes';

use Vmprobe::Util;

use Time::HiRes;
use Guard;


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

    my $job = $self->start_job('cache::touch', "Touching $args->{path} on $args->{host}");

    $remote->probe('cache::touch',
                   {
                     path => $args->{path},
                     start_pages => $args->{start_pages},
                     num_pages => $args->{num_pages},
                   },
                   sub { undef $job });
}

sub cmd_evict_sel {
    my ($self, $args) = @_;

    my $remote = $self->{dispatcher}->find_remote($args->{host});

    my $job = $self->start_job('cache::evict', "Evicting $args->{path} on $args->{host}");

    $remote->probe('cache::evict',
                   {
                     path => $args->{path},
                     start_pages => $args->{start_pages},
                     num_pages => $args->{num_pages},
                   },
                   sub { undef $job });
}

sub cmd_lock_sel {
    my ($self, $args) = @_;

    my $remote = $self->{dispatcher}->find_remote($args->{host});

    my $job = $self->start_job('cache::lock', "Locking $args->{path} on $args->{host}");

    $remote->probe(
        'cache::lock',
        {
          path => $args->{path},
          start_pages => $args->{start_pages},
          num_pages => $args->{num_pages},
        },
        sub {
            my ($res) = @_;
            undef $job;

            my $lock_id = $res->{lock_id};

            $self->{locks}->{$lock_id} = guard {
                $remote->probe('cache::unlock', { lock_id => $lock_id, }, sub {});
            };

            $self->update({
                locks => {
                    $lock_id => {
                        '$set' => {
                            path => $args->{path},
                            time => Time::HiRes::time(),
                            num_pages => $args->{num_pages},
                        }
                    },
                }
            });
        }
    );
}


sub cmd_unlock {
    my ($self, $args) = @_;

    my $lock_id = $args->{lock_id};

    delete $self->{locks}->{$lock_id};

    $self->update({
        locks => {
            '$unset' => $lock_id,
        },
    });
}

sub cmd_take_snapshot {
    my ($self, $args) = @_;

    my $remote = $self->{dispatcher}->find_remote($args->{host});

    my $job = $self->start_job('cache::snapshot', "Taking snapshot of $args->{path} on $args->{host}");

    $remote->probe(
        'cache::snapshot',
        {
            path => $args->{path},
        },
        sub {
            my ($res) = @_;

            undef $job;

            my $data = {
                type => 'cache-snapshot',
                host => $remote->{host},
                path => $args->{path},
                snapshot => $res->{snapshot},
            };

            mkdir("$ENV{HOME}/.vmprobe/");
            mkdir("$ENV{HOME}/.vmprobe/cache-snapshots/");

            die "unable to mkdir '$ENV{HOME}/.vmprobe/cache-snapshots/': $!"
                if !-d "$ENV{HOME}/.vmprobe/cache-snapshots/";

            my $filename = "$ENV{HOME}/.vmprobe/cache-snapshots/" . Time::HiRes::time() . '.snapshot';

            open(my $fh, '>:raw', $filename) || die "couldn't open $filename for writing: $!";

            print $fh sereal_encode($data);
        }
    );
}


1;
