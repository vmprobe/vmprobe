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





## Unions


#./union-snapshots test-snapshots/just-a <( ./union-snapshots test-snapshots/some-c test-snapshots/other-c ) > test-snapshots/union-just-a--some-c--other-c
union("$snapshots_dir/just-a", "$snapshots_dir/some-c", "$tempdir/union-temp1");
union("$tempdir/union-temp1", "$snapshots_dir/other-c", "$tempdir/union-temp2");
is(slurp("$snapshots_dir/union-just-a--some-c--other-c"), slurp("$tempdir/union-temp2"), "union");




## Intersection

# /intersection-snapshots test-snapshots/some-c test-snapshots/other-c > test-snapshots/intersection-some-c--other-c

intersection("$snapshots_dir/some-c", "$snapshots_dir/other-c", "$tempdir/intersection-temp1");
is(slurp("$snapshots_dir/intersection-some-c--other-c"), slurp("$tempdir/intersection-temp1"), "intersection 1");

intersection("$snapshots_dir/all", "$snapshots_dir/just-b", "$tempdir/intersection-temp2");
is(slurp("$snapshots_dir/just-b"), slurp("$tempdir/intersection-temp2"), "intersection 2");

intersection("$snapshots_dir/some-c", "$snapshots_dir/just-b", "$tempdir/intersection-temp3");
is(slurp("$snapshots_dir/none"), slurp("$tempdir/intersection-temp3"), "intersection 3");




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

sub union {
    my ($a, $b, $output) = @_;

    system("./union-snapshots $a $b > $output");
}

sub intersection {
    my ($a, $b, $output) = @_;

    system("./intersection-snapshots $a $b > $output");
}

sub curr_snapshot {
    return `./take-snapshot $files_dir`;
}
