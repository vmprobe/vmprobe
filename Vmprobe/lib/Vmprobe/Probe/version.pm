package Vmprobe::Probe::version;

use common::sense;

use Vmprobe;
use Vmprobe::Probe;

use Time::HiRes;

# Returns server's current time of day as an epoch timestamp. Useful for ping requests and also checking for incorrectly set clocks.

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
