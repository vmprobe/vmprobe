package Vmprobe::Daemon::Entity::Root;

use common::sense;

use parent 'Vmprobe::Daemon::Entity';

use Vmprobe::Daemon;
use Vmprobe::Daemon::Util;





sub ENTRY_api_info {
    my ($self, $c) = @_;

    my $output = {
        service => 'vmprobed -- https://vmprobe.com',
        version => $Vmprobe::Daemon::VERSION,
    };

    {
        my $ssh_public_key_filename = config->{remotes}->{ssh_private_key} . '.pub';

        if (open(my $fh, '<', $ssh_public_key_filename)) {
            my $ssh_public_key;

            {
                local $/;
                $ssh_public_key = <$fh>;
            }

            chomp $ssh_public_key;

            $output->{ssh_public_key} = $ssh_public_key;
        } else {
            push @{ $output->{errors} }, "Couldn't load SSH public key from $ssh_public_key_filename: $!";
        }
    }

    return $output;
}



1;
