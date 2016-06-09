package Vmprobe::Cmd::vmprobe::api;

use common::sense;

use EV;
use YAML::XS::LibYAML;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::API;


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





sub run {
    load_config();

    Vmprobe::RunContext::set_var_dir($config->{var_dir} // die "unable to find 'var_dir' in config file", 1, 0);
    Vmprobe::RunContext::init_logger(1);

    my $host = $config->{host} // '0.0.0.0';
    my $port = $config->{port} // 7624;

    my $api = Vmprobe::API->new(host => $host, port => $port);

    logger->info("API started, listening on $host:$port");

    AE::cv->recv;
}




1;
