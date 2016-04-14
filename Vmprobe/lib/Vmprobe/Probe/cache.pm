package Vmprobe::Probe::cache;

use common::sense;

use Cwd;

use parent 'Vmprobe::Probe';



sub init {
    my ($self) = @_;

    if ($self->{params}->{path} !~ m{\A/} && (!defined $self->{params}->{host} || $self->{params}->{host} eq 'localhost')) {
        $self->{params}->{path} = Cwd::realpath($self->{params}->{path})
    }

    $self->{path} = $self->{params}->{path};

    my @flags;

    if ($self->{params}->{flags}) {
        @flags = split /\s*,\s*/, $self->{params}->{flags};
    } else {
        @flags = ('mincore');
    }

    die "need one or more flags" if !@flags;

    $self->{needs_sudo} = (@flags == 1 && $flags[0] eq 'mincore') ? 0 : 1;
    $self->{flags} = \@flags;
}


sub needs_sudo {
    my ($self) = @_;

    return $self->{needs_sudo};
}



sub probe_args {
    my ($self) = @_;

    my $name = 'cache::snapshot';

    my $args = { path => $self->{path}, flags => $self->{flags}, };

    return ($name, $args, undef);
}


sub process_results {
    my ($self, $result, $connection_id) = @_;

    return $result; 
}


1;
