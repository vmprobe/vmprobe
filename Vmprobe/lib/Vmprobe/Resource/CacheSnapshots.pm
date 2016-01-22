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

    $self->{scan_timer} = AE::timer 0.1, 2, sub {
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

    while (my $filename = readdir $dh) {
        next if $filename =~ /^[.]/;

        my $snapshot_path = "$snapshot_dir/$filename";
        my $mtime = (stat($snapshot_path))[9];

        $filenames_seen->{$filename} = 1;

        next if exists $self->{view}->{snapshots}->{$filename} &&
                $self->{view}->{snapshots}->{$filename}->{mtime} == $mtime;

        my $snapshot = load_snapshot_data_from_file($snapshot_path);

        my $summary = Vmprobe::Cache::Snapshot::summarize($snapshot->{snapshot}, 32);

        my $file = {
            filename => $filename,
            snapshot_path => $snapshot_path,
            mtime => $mtime,

            host => $snapshot->{host},
            path => $snapshot->{path},

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

    my $snapshot = load_snapshot_data_from_file($args->{snapshot_path});

    my $remote = $self->{dispatcher}->find_remote($args->{hostname});

    my $job = $self->start_job('cache::restore', "Restoring snapshot $args->{snapshot_path} to $args->{hostname}");

    $remote->probe('cache::restore', { snapshot => $snapshot->{snapshot}, }, sub { undef $job });
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

    return $snapshot;
}



1;
