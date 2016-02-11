package Vmprobe::Daemon::API;

use common::sense;

use LMDB_File;
use Twiggy::Server;
use Plack::Request;
use Plack::Response;
use Plack::Middleware::ContentLength;
use Plack::Middleware::Deflater;
use JSON::XS;

use Vmprobe::Dispatcher;
use Vmprobe::Util;

use Vmprobe::Daemon::Config;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{dispatcher} = Vmprobe::Dispatcher->new();

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

    $self->{lmdb_env} = LMDB::Env->new($db_dir,
                            {
                                mapsize => 100 * 1024 * 1024 * 1024,
                                maxdbs => 32,
                                mode   => 0600,
                            });
}



sub start_service {
    my $app = \&api_plack_handler;

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
    my $env = shift;

    my $req = Plack::Request->new($env);

    return [200, ["Content-Type" => "application/json"], [encode_json({ok=>1})]];
}



1;
