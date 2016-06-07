package Vmprobe::Cmd::vmprobe::run;

use common::sense;

use EV;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::Util;
use Sys::Hostname;

use Vmprobe::Cmd;
use Vmprobe::Util;


our $spec = q{

doc: Invoke a command that will be traced by vmprobe.

argv: The command to run.

opt:
  host:
    type: Str
    alias: h
    doc: host to be used to connect to the vmprobe API.
    default: localhost
  port:
    type: Str
    alias: p
    doc: port to be used to connect to the vmprobe API.
    default: 7624

};



our $api_handle;
our $run_summary;



sub run {
    initiate_vmprobe_api();

    my $run_cv = AnyEvent::Util::run_cmd(
                     argv(),
                     close_all => 1,
                     '$$' => \my $pid,
                 );

    my $exit_code = $run_cv->recv;

    terminate_vmprobe_api();

    exit $exit_code;
}



sub initiate_vmprobe_api {
    my $cv = AE::cv;

    tcp_connect opt->{host}, opt->{port}, sub {
        my ($fh) = @_;

        die "vmprobe: failed to connect to " . opt->{host} . ":" . opt->{port} . ": $!"
            if !$fh;

        $api_handle = AnyEvent::Handle->new(
                          fh => $fh,
                          on_error => sub {
                              my ($handle, $fatal, $msg) = @_;
                              $handle->destroy;
                              say STDERR "vmprobe: lost connection to vmprobe api: $msg";
                           },
                      );

        my $info = {
            cmd => 'run',
            argv => argv(),
            hostname => hostname(),
        };

        $api_handle->push_write(packstring => "w", sereal_encode($info));

        $api_handle->push_read(packstring => "w", sub {
            my ($handle, $response) = @_;

            eval {
                $run_summary = sereal_decode($response);
            };

            if ($@) {
                die "vmprobe: unable to parse response from vmprobe api: $@";
            }

            $cv->send;
        });
    };

    $cv->recv;
}



sub terminate_vmprobe_api {
    my $cv = AE::cv;

    my $info = {
        cmd => 'exit',
        run_id => $run_summary->{run_id},
    };

    $api_handle->push_write(packstring => "w", sereal_encode($info));

    $api_handle->push_read(packstring => "w", sub {
        $cv->send;
    });

    $cv->recv;
}


1;
