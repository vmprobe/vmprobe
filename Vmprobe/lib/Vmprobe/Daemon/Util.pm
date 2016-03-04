package Vmprobe::Daemon::Util;

use common::sense;

use Exporter 'import';
our @EXPORT = qw(config);


our $config;


sub load_config {
    my ($file) = @_;

    die "config already loaded" if defined $config;

    require YAML;

    my $contents;

    {
        open(my $fh, '<', $file) || die "couldn't open config file '$file': $!";

        local $/;
        $contents = <$fh>;
    }

    $config = YAML::Load($contents);
}

sub config() {
    die "config not loaded" if !defined $config;

    return $config;
}



1;
