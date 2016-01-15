package Vmprobe::Cmd::vmprobe::cache::diff;

use common::sense;

use Vmprobe::Cmd;
use Vmprobe::Poller;
use Vmprobe::Util;
use Vmprobe::Cache::Snapshot;

use Sereal::Decoder;


our $spec = q{

doc: Shows the differences between two snapshots.

argv: Snapshot filenames.

};


sub run {
    my $remotes = opt('vmprobe')->{remote};
    my $argv = argv();

    my ($snapshot_a, $snapshot_b);


    ## Arg checking

    if (@$argv > 2) {
        die "too many arguments to diff";
    } elsif (@$argv == 2) {
        die "shouldn't provide any hosts when diffing 2 snapshot files"
            if @$remotes != 1 || $remotes->[0] ne 'localhost';

        $snapshot_a = Vmprobe::Util::load_file($argv->[0]);
        $snapshot_b = Vmprobe::Util::load_file($argv->[1]);
    } elsif (@$argv == 1) {
        die "when providing a single snapshot file, must provide exactly one remote"
            if @$remotes != 1;

        $snapshot_a = Vmprobe::Util::load_file($argv->[0]);
    } elsif (@$argv == 0) {
        die "unless 2 remotes are specified, diff needs arguments"
            if @$remotes != 2;
    }

    if (defined $snapshot_a) {
        $snapshot_a = Sereal::Decoder::decode_sereal($snapshot_a);

        my @hosts = keys %$snapshot_a;
        die "did not expect multi-host snapshot" if @hosts != 1;
        $snapshot_a = $snapshot_a->{$hosts[0]};
    }

    if (defined $snapshot_b) {
        $snapshot_b = Sereal::Decoder::decode_sereal($snapshot_b);

        my @hosts = keys %$snapshot_b;
        die "did not expect multi-host snapshot" if @hosts != 1;
        $snapshot_b = $snapshot_b->{$hosts[0]};
    }


    my $paths = opt('vmprobe::cache')->{path};

    if (@$paths == 0) {
        if (defined $snapshot_a) {
            $paths = [keys %$snapshot_a];
        } else {
            die "must specify one or more paths";
        }
    }


    ## Collect snapshots from remotes if required

    my $data = {};

    foreach my $path (@$paths) {
        Vmprobe::Poller::poll({
            remotes => opt('vmprobe')->{remote},
            probe_name => 'cache::snapshot',
            args => {
                 path => $path,
            },
            cb => sub {
                my ($remote, $result) = @_;
                $data->{$remote->{host}}->{$path} = $result;
            },
        });
    }

    Vmprobe::Poller::wait();


    if (!defined $snapshot_a && !defined $snapshot_b) {
        $snapshot_a = $data->{$remotes->[0]};
        $snapshot_b = $data->{$remotes->[1]};
    } elsif (!defined $snapshot_b) {
        $snapshot_b = $data->{$remotes->[0]};
    }


    ## Compute diff

    my $diffs = [];

    foreach my $path (keys %$snapshot_a) {
        next if !exists $snapshot_b->{$path};

        $diffs = [ @$diffs, @{ Vmprobe::Cache::Snapshot::diff($snapshot_a->{$path}->{snapshot}, $snapshot_b->{$path}->{snapshot}) } ];
    }


    ## Render diff

    my $total_touched = 0;
    my $total_evicted = 0;

    foreach my $diff (@$diffs) {
        say "$diff->{filename}  " . render_plus_minus($diff->{touched}, $diff->{evicted});

        $total_touched += $diff->{touched};
        $total_evicted += $diff->{evicted};
    }

    if ($total_touched || $total_evicted) {
        say "";
        say "TOTAL:  " . render_plus_minus($total_touched, $total_evicted);
    }
}


sub render_plus_minus {
    my ($touched, $evicted) = @_;

    my $output = '';

    $output .= colour("+" . pages2size($touched), 'green') . " "
        if $touched;

    $output .= colour("-" . pages2size($evicted), 'bright_red')
        if $evicted;

    return $output;
}



1;
