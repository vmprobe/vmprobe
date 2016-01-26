package Vmprobe::Cmd::vmprobe::exec;

use common::sense;

use Time::HiRes;

use Vmprobe::Cmd;
use Vmprobe::Poller;
use Vmprobe::Util;


our $spec = q{

doc: Executes a command on the remote servers.

opt:
  shell:
    type: Bool
    alias: s
    doc: If specified, the command will be run by a shell and can therefore use shell features such as wild-cards.

argv: The command to run.

};



sub run {
    my $cmd;

    my $argv = argv();

    die "must supply a command to run"
        if !@$argv;

    if (opt->{shell}) {
        $cmd = join(' ', @$argv);
    } else {
        $cmd = $argv;
    }

    Vmprobe::Poller::poll({
        remotes => opt('vmprobe')->{remote},
        probe_name => 'exec',
        args => { cmd => $cmd },
        cb => sub {
            my ($remote, $result) = @_;

            my $stdout = $result->{stdout};
            $stdout =~ s/\s*\z//;
            $stdout =~ s/\n/\n  /g;

            my $stderr = $result->{stderr};
            $stderr =~ s/\s*\z//;
            $stderr =~ s/\n/\n  /g;

            print "$remote->{host} ";
            print $result->{ret} ? colour("FAIL ($result->{ret})", 'red')
                                 : colour("OK", 'green');
            print "\n";
            say "  " . $stdout if $stdout;
            say "  " . colour($stderr, 'red') if $stderr;
        },
    });

    Vmprobe::Poller::wait();
}


1;
