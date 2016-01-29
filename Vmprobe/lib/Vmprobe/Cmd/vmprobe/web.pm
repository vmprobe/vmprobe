package Vmprobe::Cmd::vmprobe::web;

use common::sense;

use AnyEvent;
use Twiggy::Server;
use Plack::Request;
use Plack::Response;
use Plack::App::Proxy;
use Plack::Middleware::Conditional;
use Plack::Middleware::CrossOrigin;
use Plack::Middleware::ContentLength;
use Plack::Middleware::Deflater;
use Plack::Middleware::Static;
use Plack::Middleware::Rewrite;
use JSON::XS;

use Vmprobe;
use Vmprobe::Util;
use Vmprobe::Cmd;
use Vmprobe::Dispatcher;


our $spec = q{

doc: Built-in web-server.

opt:
    host:
        type: Str
        alias: h
        default: 127.0.0.1
        doc: Host/IP address to bind to.
    port:
        type: Str
        alias: p
        default: 5000
        doc: Port to listen on.
    cross-origin:
        type: Str
        doc: Whether to set Cross-Origin Resource Sharing (CORS) headers. This may be useful during development but is not recommended for production.
    repo-dev-mode:
        type: Bool
        doc: Run in repo development mode. This will attempt to run the react hot loader server so that changes made to the javascript immediately take effect (with no compile step or browser reload). The vmprobe binary to run must be inside the vmprobe git repo.
    dev-hot-load-port:
        type: Str
        doc: Port to run the react hot load development server on. Only applicable if --repo-dev-mode is specified.
        default: 58118
};



my $dispatcher;
 

sub run {
    $dispatcher = Vmprobe::Dispatcher->new();

    my $server = Twiggy::Server->new(
        host => opt->{host},
        port => opt->{port},
    );


    my $app = web_javascript_handler();

    $app = Plack::Middleware::Conditional->wrap(
        $app,
        condition  => sub { $_[0]->{REQUEST_URI} =~ m{^/api/} },
        builder => sub { \&vmprobe_api_handler },
    );

    $app = Plack::Middleware::ContentLength->wrap($app);

    if (opt->{'cross-origin'}) {
        $app = Plack::Middleware::CrossOrigin->wrap($app, origins => '*');
    }

    $app = Plack::Middleware::Deflater->wrap($app, content_type => [qw{application/json application/javascript text/html text/plain}]);


    $server->register_service($app);

    say "Listening on http://", opt->{host}, ":", opt->{port};

    require Vmprobe::Cmd::vmprobe;
    foreach my $host (@{ Vmprobe::Cmd::vmprobe::get_remotes() }) {
        say "Adding remote: $host";
        $dispatcher->add_remote($host);
    }

    AE::cv->recv;
}


our $dev_server_keepalive_pipe;

sub web_javascript_handler {
    if (!defined $ENV{VMPROBE_WEBDIST_DIR} && ($Vmprobe::VERSION eq 'REPO_DEV_MODE' || opt->{repo_dev_mode})) {
        require FindBin;

        my $web_dir = "$FindBin::Bin/../../web";

        die "Running in --dev mode requires running the binary in the vmprobe git repo"
            if !-e "$web_dir/dev-server.js";

        die "The web directory doesn't appear to have node_modules/ (forgot to install npm deps?)"
            if !-d "$web_dir/node_modules";

        my $dev_hot_load_port = opt->{'dev-hot-load-port'};

        {
            ## When perl process exits, close node's stdin so it exits too.

            pipe(my $pipe_r, $dev_server_keepalive_pipe) || die "can't pipe: $!";

            if (!fork) {
                close($dev_server_keepalive_pipe);
                open(STDIN, '>&', $pipe_r) or die "Can't dup2: $!";
                close($pipe_r);

                chdir($web_dir);

                exec(qw/node dev-server.js localhost/, $dev_hot_load_port);
                die "couldn't exec node: $!";
            }
        }

        return Plack::App::Proxy->new(remote => "http://127.0.0.1:$dev_hot_load_port")->to_app;
    }

    require File::ShareDir;

    my $webdist_dir = $ENV{VMPROBE_WEBDIST_DIR} // File::ShareDir::dist_dir('Vmprobe') . '/webdist/';

    my $app = sub {
        return [404, ['Content-Type' => 'text/html'], ['404 not found']];
    };

    $app = Plack::Middleware::Static->wrap($app,
                                           root => $webdist_dir,
                                           path => sub { s{^/static/}{} });

    $app = Plack::Middleware::Static->wrap($app,
                                           root => $webdist_dir,
                                           path => sub { s{^/$}{/index.html} });

    $app = Plack::Middleware::Rewrite->wrap($app, request => sub {
               ## Handle bundle.js ourselves because of large file bug in Plack::Middleware::Static and/or Twiggy:
               ## Deep recursion on subroutine "AnyEvent::Handle::push_write" at /usr/local/share/perl/5.20.2/Twiggy/Server.pm line 529, <$fh> chunk 100.
               return [200, ['Content-Type', 'application/javascript'], [Vmprobe::Util::load_file("$webdist_dir/bundle.js")]]
                   if m{^/static/bundle.js$};
           });

    return $app;
}





sub vmprobe_api_handler {
    my $env = shift;
 
    my $req = Plack::Request->new($env);

    if ($req->path_info eq '/api/connect') {
        my $session = $dispatcher->new_session;

        my $resp = {
            token => $session->{token},
        };

        return [200, ["Content-Type" => "application/json"], [encode_json($resp)]];
    } elsif ($req->path_info eq '/api/msg/put') {
        my $body = decode_json($req->raw_body);

        if (!$dispatcher->get_session($body->{token})) {
            return [403, ["Content-Type" => "text/plain"], ["unrecognized session token"]];
        }

        {
            local $dispatcher->{drain_update_corked} = 1;

            foreach my $msg (@{ $body->{msgs} }) {
                $dispatcher->process_msg($msg);
            }
        }

        $dispatcher->drain_updates();

        return [200, ["Content-Type" => "application/json"], ["{}"]];
    } elsif ($req->path_info eq '/api/msg/get') {
        my $session = $dispatcher->get_session($req->parameters->{token});

        if (!defined $session) {
            return [403, ["Content-Type" => "text/plain"], ["unrecognized session token"]];
        }

        return sub {
            my $responder = shift;

            $dispatcher->get_msgs($session, sub {
                my $msgs = shift;
                $responder->([200, ["Content-Type" => "application/json"], [encode_json($msgs)]]);
            });
        };
    }

    return [404, ["Content-Type" => "text/plain"], ["unrecognized end-point"]];
}



1;
