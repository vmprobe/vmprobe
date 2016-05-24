package Vmprobe::Daemon::Util;

use common::sense;

use Exporter 'import';
our @EXPORT = qw(config);

use POSIX qw();


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




sub daemonize {
    my $ret = fork();

    die "unable to fork while daemonizing: $!"
        if !defined $ret;

    exit if $ret;

    POSIX::setsid();

    open(STDIN, '<', '/dev/null');
    open(STDOUT, '>', '/dev/null');
    open(STDERR, '>', '/dev/null');

    chdir(config->{var_dir});
}



1;
