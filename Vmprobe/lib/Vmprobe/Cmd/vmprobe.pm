package Vmprobe::Cmd::vmprobe;

use common::sense;

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

};

1;
