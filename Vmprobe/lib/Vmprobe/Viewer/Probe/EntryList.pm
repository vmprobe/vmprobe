package Vmprobe::Viewer::Probe::EntryList;

use common::sense;

use parent 'Vmprobe::Viewer::Probe::Base';



sub history_size {
    my ($self) = @_;

    return $self->height;
}


sub process_entry {
    my ($self, $entry) = @_;

}


sub render {
    my ($self, $canvas) = @_;

    my $curr_line = 0;

}



1;
