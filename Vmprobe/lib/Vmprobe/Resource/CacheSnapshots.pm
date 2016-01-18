package Vmprobe::Resource::CacheSnapshots;

use common::sense;

use parent 'Vmprobe::Resource::Base';


sub get_initial_params {
    return {
        snapshot_dir => "$ENV{HOME}/.vmprobe/cache-snapshots/",
    };
}



sub on_ready {
    my ($self) = @_;

    $self->list_snapshot_dir();
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

    my @files;

    while(readdir $dh) {
        next if /^[.]/;

        my $filename = "$snapshot_dir/$_";
        my $mtime = (stat($filename))[9];

        push @files, {
            filename => $_,
            full_path => $filename,
            mtime => $mtime,
        };
    }

    $self->update({ snapshots => { '$set' => \@files }});
}


1;
