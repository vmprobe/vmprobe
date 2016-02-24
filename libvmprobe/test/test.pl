#!/usr/bin/env perl

use common::sense;
use File::Temp qw/tempdir/;
use Cwd;

use Test::More qw/no_plan/;



my $files_dir = getcwd() . "/test-files/";
my $snapshots_dir = getcwd() . "/test-snapshots/";

my $tempdir = tempdir( CLEANUP => !$ENV{NOCLEANUP} );



## Basic snapshot application

restore_snapshot("$snapshots_dir/none");
restore_snapshot("$snapshots_dir/all");

foreach my $snap (qw/just-a just-b just-z some-c/) {
    restore_snapshot("$snapshots_dir/none");
    restore_snapshot("$snapshots_dir/$snap");

    restore_snapshot("$snapshots_dir/all");
    restore_snapshot("$snapshots_dir/$snap");
}




## Deltas


## Make sure the step* snapshots are all valid...

foreach my $snap (qw/step0 step1 step2 step3 step4 step5/) {
    restore_snapshot("$snapshots_dir/$snap");
}


## one-by-one forwards

for my $i (0..4) {
    my $next = $i + 1;

    delta("$snapshots_dir/step$i", "$snapshots_dir/step$next", "$tempdir/delta$i.$next");
    delta("$snapshots_dir/step$i", "$tempdir/delta$i.$next", "$tempdir/recovered_step$next");

    is(slurp("$snapshots_dir/step$next"), slurp("$tempdir/recovered_step$next"), "delta $i -> $next");
}


## combine deltas forwards (relies on deltas from previous tests)

for my $i (2..5) {
    my $prev = $i - 1;

    delta("$tempdir/delta0.$prev", "$tempdir/delta$prev.$i", "$tempdir/delta0.$i");
    delta("$snapshots_dir/step0", "$tempdir/delta0.$i", "$tempdir/recovered2_step$i");

    is(slurp("$snapshots_dir/step$i"), slurp("$tempdir/recovered2_step$i"), "delta 0 -> $i");
}


## combine deltas backwards (relies on deltas from previous tests)

delta("$tempdir/delta3.4", "$tempdir/delta4.5", "$tempdir/rev_delta3.5");
delta("$tempdir/delta2.3", "$tempdir/rev_delta3.5", "$tempdir/rev_delta2.5");
delta("$tempdir/delta1.2", "$tempdir/rev_delta2.5", "$tempdir/rev_delta1.5");
delta("$tempdir/delta0.1", "$tempdir/rev_delta1.5", "$tempdir/rev_delta0.5");

delta("$snapshots_dir/step0", "$tempdir/rev_delta0.5", "$tempdir/recovered3_step5");
is(slurp("$snapshots_dir/step5"), slurp("$tempdir/recovered3_step5"), "reverse delta");




## Finished

restore_snapshot("$snapshots_dir/none");

if ($ENV{NOCLEANUP}) {
    say STDERR "TEMPDIR: $tempdir";
}






sub restore_snapshot {
    my $snapshot = shift;

    system("./restore-snapshot $files_dir < $snapshot");
    is(curr_snapshot(), slurp($snapshot), "restored $snapshot");
}

sub slurp {
    my $filename = shift;

    open(my $fh, '<:raw', $filename) || die "couldn't open $filename: $!";

    local $/;
    return <$fh>;
}

sub delta {
    my ($before, $after, $output) = @_;

    system("./delta-snapshots $before $after > $output");
}

sub curr_snapshot {
    return `./take-snapshot $files_dir`;
}
