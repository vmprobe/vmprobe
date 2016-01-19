package Vmprobe::Resource::CacheSnapshots;

use common::sense;

use parent 'Vmprobe::Resource::Base';

use AnyEvent;

use Vmprobe::Util;
use Vmprobe::Cache::Snapshot;


sub get_initial_params {
    return {
        snapshot_dir => "$ENV{HOME}/.vmprobe/cache-snapshots/",
    };
}



sub on_ready {
    my ($self) = @_;

    $self->list_snapshot_dir();

    $self->{scan_timer} = AE::timer 2, 2, sub {
        $self->list_snapshot_dir();
    };
}


sub list_snapshot_dir {
    my ($self) = @_;

    my $snapshot_dir = $self->{view}->{params}->{snapshot_dir};

    return if !-d $snapshot_dir;

    my $dh;

    if (!opendir($dh, $snapshot_dir)) {
        $self->add_error("couldn't open directory '$snapshot_dir': $!");
        return;
    }

    my $filenames_seen = {};

    while(readdir $dh) {
        next if /^[.]/;

        my $filename = $_;
        my $path = "$snapshot_dir/$_";
        my $mtime = (stat($path))[9];

        $filenames_seen->{$filename} = 1;

        next if exists $self->{view}->{snapshots}->{$filename} &&
                $self->{view}->{snapshots}->{$filename}->{mtime} == $mtime;

        my $snapshot_data = load_snapshot_data_from_file($path);

        my $summary = Vmprobe::Cache::Snapshot::summarize($snapshot_data, 32);

        my $file = {
            filename => $filename,
            path => $path,
            mtime => $mtime,
            summary => $summary,
        };

        $self->update({ snapshots => { $filename => { '$set' => $file }}});
    }

    foreach my $filename (keys %{ $self->{view}->{snapshots} }) {
        if (!$filenames_seen->{$filename}) {
            $self->update({ snapshots => { '$unset' => $filename }});
        }
    }
}





sub cmd_restore_snapshot {
    my ($self, $args) = @_;

    my $snapshot_data = load_snapshot_data_from_file($args->{snapshot_path});

    my $remote = $self->{dispatcher}->find_remote($args->{hostname});

    $remote->probe('cache::restore', { snapshot => $snapshot_data, }, sub {});
}




sub load_snapshot_data_from_file {
    my $path = shift;

    my $encoded_snapshot = Vmprobe::Util::load_file($path);
    my $snapshot;

    eval {
        $snapshot = Sereal::Decoder::decode_sereal($encoded_snapshot);
    };

    if ($@) {
        die "error decoding sereal found in '$path': $@";
    }

    my @snapshot_hosts = keys %$snapshot;
    die "expected only one host in snapshot, found " . scalar(@snapshot_hosts) . " (" . join(', ', @snapshot_hosts) . ")"
        if @snapshot_hosts != 1;

    my @snapshot_paths = keys %{ $snapshot->{$snapshot_hosts[0] } };
    die "expected only one path in snapshot, found " . scalar(@snapshot_paths) . " (" . join(', ', @snapshot_paths) . ")"
        if @snapshot_paths != 1;

    return $snapshot->{$snapshot_hosts[0]}->{$snapshot_paths[0]}->{snapshot};
}



1;
