package Vmprobe::Cmd::vmprobe::api;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use YAML::XS::LibYAML;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;


our $spec = q{

doc: Vmprobe api service

opt:
  config:
    type: Str
    alias: c
    doc: Path to config file.
    default: /etc/vmprobe-api.conf
  daemon:
    type: Bool
    alias: d
    doc: Run the server in the background as a daemon.

};




our $config;

sub load_config {
    my $config_filename = opt->{config};
    my $config_file_contents;

    {
        open(my $fh, '<', $config_filename) || die "couldn't open config file '$config_filename': $!";

        local $/;
        $config_file_contents = <$fh>;
    }

    $config = YAML::XS::LibYAML::Load($config_file_contents);
}




our $server_guard;
our $conns = {};


sub run {
    load_config();

    Vmprobe::RunContext::set_var_dir($config->{var_dir} // die "unable to find 'var_dir' in config file", 1, 0);

    $server_guard = tcp_server $config->{host} // undef, $config->{port} // 7624, sub {
        my ($fh, $host, $port) = @_;

        my $connection = add_connection({ fh => $fh, host => $host, port => $port});
    };

    AE::cv->recv;
}



sub add_connection {
    my $id;

    {
        ## New scope so we don't accidentally close over $conn
        my $conn = shift;

        $id = 0 + $conn;
        $conns->{$id} = $conn;
    }

    $conns->{$id}->{handle} = AnyEvent::Handle->new(
                          fh => $conns->{$id}->{fh},
                          on_error => sub {
                              my ($handle, $fatal, $msg) = @_;
                              say STDERR "disconnect: $id ($msg)";
                              $handle->destroy;
                              delete $conns->{$id};
                          },
                      );

    my $msg_handler; $msg_handler = sub {
        my ($handle, $response) = @_;

        eval {
            $response = sereal_decode($response);
        };

        if ($@) {
            say STDERR "unable to decode msg: $id";
            $handle->destroy;
            delete $conns->{$id};
            return;
        }

        my $run_summary = {
            run_id => get_session_token(),
        };

        $conns->{$id}->{handle}->push_write(packstring => "w", sereal_encode($run_summary));

        $conns->{$id}->{handle}->push_read(packstring => "w", $msg_handler);
    };

    $conns->{$id}->{handle}->push_read(packstring => "w", $msg_handler);
}





1;
