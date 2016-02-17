package Vmprobe::Daemon::API;

use common::sense;

use LMDB_File;
use Twiggy::Server;
use Plack::Middleware::ContentLength;
use Plack::Middleware::Deflater;

use Vmprobe::Util;
use Vmprobe::Daemon::Config;
use Vmprobe::Daemon::Router;

use Vmprobe::Daemon::Entity::Remote;
use Vmprobe::Daemon::Entity::Snapshot;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->open_db();
    $self->create_entities();
    $self->start_service();

    return $self;
}


sub open_db {
    my ($self) = @_;

    if (!-e config->{var_dir}) {
        die "specified var directory does not exist: " . config->{var_dir};
    }

    my $db_dir = config->{var_dir} . "/db";

    if (!-e $db_dir) {
        mkdir($db_dir) || die "couldn't mkdir($db_dir): $!";
    }

    eval {
        $self->{lmdb} = LMDB::Env->new($db_dir,
                            {
                                mapsize => 100 * 1024 * 1024 * 1024,
                                maxdbs => 32,
                                mode   => 0600,
                            });
    };

    if ($@) {
        die "error creating LMDB environment: $@";
    }
}



sub create_entities {
    my ($self) = @_;

    $self->{entities}->{remote} = Vmprobe::Daemon::Entity::Remote->new(api => $self);
    $self->{entities}->{snapshot} = Vmprobe::Daemon::Entity::Snapshot->new(api => $self);
}


sub start_service {
    my ($self) = @_;

    my $app = $self->api_plack_handler();

    $app = Plack::Middleware::ContentLength->wrap($app);

    $app = Plack::Middleware::Deflater->wrap($app, content_type => [qw{application/json application/javascript text/html text/plain}]);


    my $ip = config->{api}->{ip} || '127.0.0.1';
    my $port = config->{api}->{port} || 7600;

    my $server = Twiggy::Server->new(
        host => $ip,
        port => $port,
    );

    $server->register_service($app);

    say "API Listening on http://$ip:$port";
}



sub api_plack_handler {
    my ($self) = @_;

    my $router = Vmprobe::Daemon::Router->new;

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
                POST => 'create_new_snapshot',
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

    return sub {
        my $env = shift;
        return $router->route($env);
    };
}



1;
