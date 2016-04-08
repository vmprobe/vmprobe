package Vmprobe::Raw::timestamp;

use common::sense;

use Time::HiRes;


# Returns server's current time of day as an epoch timestamp. Useful for ping requests and also checking for incorrectly set clocks.

sub run {
    return { timestamp => [ Time::HiRes::gettimeofday ] };
}

1;
