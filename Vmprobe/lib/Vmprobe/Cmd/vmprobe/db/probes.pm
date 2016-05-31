package Vmprobe::Cmd::vmprobe::db::probes;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Util;
use Vmprobe::RunContext;
use Vmprobe::DB::Probe;
use Vmprobe::DB::ProbeUpdateTimes;


our $spec = q{

doc: List probes in DB.

opt:
  var-dir:
    type: Str
    alias: v
    doc: Directory for the vmprobe DB and other run-time files.
  long:
    type: Bool
    alias: l
    doc: Long listing with more detailed information about each probe.
  num:
    type: Str
    alias: n
    doc: Limit number of probes listed.
};




sub run {
    Vmprobe::RunContext::set_var_dir(opt->{'var-dir'}, 0, 0);

    my $txn = new_lmdb_txn();
    my $probe_db = Vmprobe::DB::Probe->new($txn);

    my $curr = 0;

    ITER: {
        Vmprobe::DB::ProbeUpdateTimes->new($txn)->iterate({
            backward => 1,
            cb => sub {
                my ($k, $v) = @_;

                display_probe($probe_db, $v, $k);

                $curr++;
                last ITER if defined opt->{num} && $curr >= opt->{num};
            },
        });
    }
}



sub display_probe {
    my ($probe_db, $probe_id, $update_time) = @_;

    say $probe_id;

    return if !opt->{long};

    my $curr_time_secs = curr_time() / 1e6;

    my $summary = $probe_db->get($probe_id);

    my $creation_ago = $curr_time_secs - ($summary->{start} / 1e6);
    say "  Created:  " . scalar(localtime($summary->{start} / 1e6)) . " (" . format_duration($creation_ago) . " ago)";

    my $updated_ago = $curr_time_secs - ($update_time / 1e6);
    say "  Updated:  " . scalar(localtime($update_time / 1e6)) . " (" . format_duration($updated_ago) . " ago)";

    my $params = $summary->{params};

    say "  Params:   " . join(' ', map { "$_=$params->{$_}" } sort keys %$params);
}


1;
