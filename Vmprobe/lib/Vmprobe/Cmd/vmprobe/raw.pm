package Vmprobe::Cmd::vmprobe::raw;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;



our $spec = q{

doc: Synchronous binary interface used by vmprobe internally.

};


sub run {
    binmode(STDIN);
    binmode(STDOUT);

    my $buf = "";

    MESSAGE: while(1) {
        my $len;

        MESSAGE_LEN: while(1) {
            $len = eval { unpack("w", $buf) };
            if (defined $len) {
                substr($buf, 0, length(pack("w", $len)), "");
                last MESSAGE_LEN;
            }

            my $rc = sysread(\*STDIN, $buf, 4096, length($buf));
            die "read error: $!" if !defined $rc;
            last MESSAGE if !$rc;
        }

        die "message body too large ($len)" if $len > 100_000_000;
        die "message body too small ($len)" if $len < 1;

        MESSAGE_BODY: while(1) {
            if (length($buf) >= $len) {
                my $msg = substr($buf, 0, $len);

                substr($buf, 0, $len, "");
                undef $len;

                process_msg($msg);

                next MESSAGE;
            }

            my $rc = sysread(\*STDIN, $buf, 4096, length($buf));
            die "read error: $!" if !defined $rc;
            last MESSAGE if !$rc;
        }
    }

    die "incomplete message" if length($buf);
}


sub process_msg {
    my $msg = sereal_decode($_[0]);

    die "bad probe name: $msg->{probe}" if !Vmprobe::Util::is_valid_package_name($msg->{probe});

    my $package_name = "Vmprobe::Probe::$msg->{probe}";
    eval "require $package_name" || die "unable to load package $package_name: $@";

    my $output;

    {
        no strict 'refs';

        eval {
            $output = {
                result => &{ "Vmprobe::Probe::$msg->{probe}::run" }($msg->{args}),
            };
        };
    }

    if ($@) {
        $output = {
            error => $@,
        };
    }

    my $encoded_output = sereal_encode($output);

    syswrite(\*STDOUT, pack("w", length($encoded_output)));
    syswrite(\*STDOUT, $encoded_output);
}


1;
