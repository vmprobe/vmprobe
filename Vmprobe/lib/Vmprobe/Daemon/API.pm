package Vmprobe::Daemon::API;

use common::sense;

use EV;
use AnyEvent;
use LMDB_File;
use Twiggy::Server;
use Plack::Middleware::ContentLength;
use Plack::Middleware::Deflater;
use Log::File::Rolling;
use Data::Dumper;
use JSON::XS;
use Time::HiRes;
use Log::Defer;

use Vmprobe::Util;
use Vmprobe::Daemon::Util;
use Vmprobe::Daemon::Router;

use Vmprobe::Daemon::DB::Global;
use Vmprobe::Daemon::Entity::Root;
use Vmprobe::Daemon::Entity::Remote;
use Vmprobe::Daemon::Entity::Snapshot;
use Vmprobe::Daemon::Entity::Standby;



sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    if (!-e config->{var_dir}) {
        die "specified var directory does not exist: " . config->{var_dir};
    }

    $self->_open_logger();

    Vmprobe::Daemon::Util::daemonize() unless $self->{nodaemon};

    my $logger = $self->get_logger;

    $logger->info("vmprobed started, pid $$");
    $logger->data->{start_time} = Time::HiRes::time();
    $logger->data->{pid} = $$;

    eval {
        $self->_open_db($logger);
        $self->_create_entities($logger);

        $self->_start_service($logger);
    };

    if ($@) {
        $logger->error("Erroring starting vmprobed: $@");
        $logger->error("vmprobed unable to run, shutting down");
        die $@;
    }

    return $self;
}

sub run {
    AE::cv->recv;
}


sub _open_logger {
    my ($self) = @_;

    my $log_dir = config->{var_dir} . "/logs";

    if (!-e $log_dir) {
        mkdir($log_dir) || die "couldn't mkdir($log_dir): $!";
    }

    $self->{logger} = Log::File::Rolling->new(
                          filename => "$log_dir/vmprobed.%Y-%m-%dT%H.log",
                          current_symlink => "$log_dir/vmprobed.log.current",
                          timezone => 'localtime',
                      ) || die "Error creating Log::File::Rolling logger: $!";
}



sub json_clean {
    my $x = shift;

    if (ref $x) {
        if (ref $x eq 'ARRAY') {
            $x->[$_] = json_clean($x->[$_]) for 0 .. @$x-1;
        } elsif (ref $x eq 'HASH') {
            $x->{$_} = json_clean($x->{$_}) for keys %$x;
        } else {
            $x = "Unable to JSON encode: " . Dumper($x);
        }
    }

    return $x;
}

sub get_logger {
    my ($self) = @_;

    return Log::Defer->new({ cb => sub {
        my $msg = shift;

        if ($self->{nodaemon}) {
            state $pretty_json = JSON::XS->new->canonical(1)->pretty(1);
            say $pretty_json->encode($msg);
        }

        my $encoded_msg;
        eval {
            $encoded_msg = encode_json($msg)
        };

        if ($@) {
            eval {
                $encoded_msg = encode_json(json_clean($msg));
            };

            if ($@) {
                $encoded_msg = "Failed to JSON clean: " . Dumper($msg);
            }
        }

        $self->{logger}->log("$encoded_msg\n");
    }});
}




sub _open_db {
    my ($self, $logger) = @_;

    my $db_dir = config->{var_dir} . "/db";

    if (!-e $db_dir) {
        $logger->info("Creating db directory: $db_dir");
        mkdir($db_dir) || die "couldn't mkdir($db_dir): $!";
    }

    eval {
        $self->{lmdb} = LMDB::Env->new($db_dir,
                            {
                                mapsize => 100 * 1024 * 1024 * 1024,
                                maxdbs => 32,
                                mode   => 0600,
                            });

        my $txn = $self->{lmdb}->BeginTxn;

        Vmprobe::Daemon::DB::Global->new($txn)->check_arch($txn);

        $txn->commit;

        $logger->data->{lmdb_stats} = $self->{lmdb}->stat;
    };

    if ($@) {
        die "error creating LMDB environment: $@";
    }
}



sub _create_entities {
    my ($self, $logger) = @_;

    $self->{entities}->{root} = Vmprobe::Daemon::Entity::Root->new(api => $self, logger => $logger);
    $self->{entities}->{remote} = Vmprobe::Daemon::Entity::Remote->new(api => $self, logger => $logger);
    $self->{entities}->{snapshot} = Vmprobe::Daemon::Entity::Snapshot->new(api => $self, logger => $logger);
    $self->{entities}->{standby} = Vmprobe::Daemon::Entity::Standby->new(api => $self, logger => $logger);
}


sub _start_service {
    my ($self, $logger) = @_;

    my $app = $self->_api_plack_handler();

    $app = Plack::Middleware::ContentLength->wrap($app);

    $app = Plack::Middleware::Deflater->wrap($app, content_type => [qw{application/json application/javascript text/html text/plain}]);


    my $host = config->{api}->{host} || '127.0.0.1';
    my $port = config->{api}->{port} || 7600;

    my $server = Twiggy::Server->new(
        host => $host,
        port => $port,
    );

    $server->register_service($app);

    $logger->info("API Listening on http://$host:$port");
}



sub _api_plack_handler {
    my ($self) = @_;

    my $router = Vmprobe::Daemon::Router->new(api => $self);

    $router->mount({
        entity => $self->{entities}->{root},
        routes => {
            '/' => {
                GET => 'api_info',
            },
        },
    });

    $router->mount({
        entity => $self->{entities}->{remote},
        routes => {
            '/remote' => {
                GET => 'get_all_remotes',
                POST => 'create_new_remote',
            },
            '/remote/:remoteId' => {
                GET => 'get_remote',
                PUT => 'update_remote',
                DELETE => 'delete_remote',
            },
        },
    });

    $router->mount({
        entity => $self->{entities}->{snapshot},
        routes => {
            '/cache/snapshot' => {
                POST => 'take_snapshot',
            },
            '/cache/snapshot/:snapshotId' => {
                GET => 'get_snapshot',
                DELETE => 'delete_snapshot',
            },
            '/cache/snapshot/:snapshotId/restore' => {
                POST => 'restore_snapshot',
            },
        },
    });

    $router->mount({
        entity => $self->{entities}->{standby},
        routes => {
            '/cache/standby' => {
                GET => 'get_all_standbys',
                POST => 'create_new_standby',
            },
            '/cache/standby/:standbyId' => {
                GET => 'get_standby',
                PUT => 'update_standby',
                DELETE => 'delete_standby',
            },
        },
    });

    return sub {
        my $env = shift;
        return $router->route($env);
    };
}



1;
