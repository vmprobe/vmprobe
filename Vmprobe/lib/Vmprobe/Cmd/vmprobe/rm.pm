package Vmprobe::Cmd::vmprobe::rm;

use common::sense;

use Cwd;

use Vmprobe::DB;
use Vmprobe::DB::Probe;
use Vmprobe::Cmd;


our $spec = q{

doc: Removes a probe.

argv: Probe ID to remove.

};




sub run {
    die "requires one or more probe IDs to remove" if @{ argv() } < 1;

    my $txn = Vmprobe::DB::new_txn();

    my $db = Vmprobe::DB::Probe->new($txn);

    foreach my $probe_id (@{ argv() }) {
        $db->delete($probe_id);
    }

    $txn->commit;

    foreach my $probe_id (@{ argv() }) {
        say "Deleted probe: $probe_id";
    }
}



1;
