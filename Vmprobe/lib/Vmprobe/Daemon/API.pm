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



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->open_db();
    $self->start_service();

    return $self;
}



sub open_db {
    my ($self) = @_;

    my $db_dir = config->{var_dir} . "/db";

    if (!-e $db_dir) {
        mkdir $db_dir || die "couldn't mkdir($db_dir): $!";
    }

    $self->{lmdb} = LMDB::Env->new($db_dir,
                        {
                            mapsize => 100 * 1024 * 1024 * 1024,
                            maxdbs => 32,
                            mode   => 0600,
                        });
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



=pod
/remote (GET, POST)
/remote/:remoteIdOrName (GET, PUT, DELETE)

/cache/monitor (GET, POST)
/cache/monitor/:monitor (GET, PUT, DELETE)

/cache/snapshot (GET, POST)
/cache/snapshot/:snapshotId (GET, DELETE)
/cache/snapshot/:snapshotId/restore (POST)

/cache/standby (GET, POST)
/cache/standby/:standbyId (GET, PUT, DELETE)
=cut


sub api_plack_handler {
    my ($self) = @_;

    my $router = Vmprobe::Daemon::Router->new(lmdb => $self->{lmdb});

    $router->mount({
        entity => Vmprobe::Daemon::Entity::Remote->new(),
        routes => {
            '/remote' => {
                GET => 'get_all_remotes',
                POST => 'create_new_remote_anon',
            },
            '/remote/:remoteId' => {
                GET => 'get_remote',
                PUT => 'update_remote',
                DELETE => 'remove_remote',
            },
        },
    });

    return sub {
        my $env = shift;
        return $router->route($env);
    };
}



1;
