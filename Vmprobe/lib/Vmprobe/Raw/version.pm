package Vmprobe::Raw::version;

use common::sense;

use Time::HiRes;

use Vmprobe;


sub run {
    my $vmprobe_version = $Vmprobe::VERSION;

    if ($vmprobe_version eq 'REPO_DEV_MODE') {
        require FindBin;
        $vmprobe_version = `cd $FindBin::Bin/ && git describe --tags`;
        die "couldn't git describe" if $?;
        chomp $vmprobe_version;
    }

    return {
        vmprobe => $vmprobe_version,
        os_type => $^O,
    };
}

1;
