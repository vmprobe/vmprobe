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
        doc: Filenames of private keys to be used for the ssh connection. This is passed through to ssh's -i switch.

};


sub validate {
    my $keys = opt->{'ssh-private-key'};

    if ($keys) {
        require Vmprobe::Remote;

        die "currently only one ssh private key parameter is supported"
            if @$keys != 1;

        $Vmprobe::Remote::global_params->{ssh_private_key} = $keys->[0];
    }
}


1;
