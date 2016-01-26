package Vmprobe::Cmd::vmprobe;

use common::sense;

use Vmprobe::Cmd;

our $spec = q{

doc: Top-level command.

opt:
    remote:
        type: Str[]
        alias: r
        min_length: 1
        default:
            - localhost
        doc: The host(s) to run the probe on. This affects nearly every sub-command. These should be SSH host specifiers, for example "example.com" or "user@example.com". "localhost" is special-cased and doesn't connect via SSH (force an SSH connection with "127.0.0.1").
    ssh-private-key:
        type: Str[]
        doc: Filenames of private keys to be used for ssh connections. This is passed through to ssh's -i switch.
    remotes-file:
        type: Str
        doc: A file that contains newline-separated hosts to use as remotes. This flag takes precedence over --remote.
    sudo:
        doc: If specified, the vmprobe instances on the remote hosts will be run with sudo.
    vmprobe-binary:
        type: Str
        doc: The binary to run on remotes. This may be useful if vmprobe isn't in your path.
};


sub validate {
    my $keys = opt->{'ssh-private-key'};

    if ($keys) {
        require Vmprobe::Remote;

        die "currently only one ssh private key parameter is supported"
            if @$keys != 1;

        $Vmprobe::Remote::global_params->{ssh_private_key} = $keys->[0];
    }

    if (opt->{'sudo'}) {
        require Vmprobe::Remote;

        $Vmprobe::Remote::global_params->{sudo} = 1;
    }

    if (defined opt->{'vmprobe-binary'}) {
        require Vmprobe::Remote;

        $Vmprobe::Remote::global_params->{vmprobe_binary} = opt->{'vmprobe-binary'};
    }
}



sub get_remotes {
    my $remote_file = opt->{'remotes-file'};

    if ($remote_file) {
        my @remotes;

        open(my $fh, '<', $remote_file) || die "could open remotes file '$remote_file': $!";

        foreach my $line (<$fh>) {
            chomp $line;
            next if $line =~ /^$/ || $line =~ /^\s*#/;
            push @remotes, $line;
        }

        return \@remotes;
    }

    return opt->{remote};
}



1;
