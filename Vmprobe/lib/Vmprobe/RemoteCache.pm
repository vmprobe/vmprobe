package Vmprobe::RemoteCache;

use common::sense;

use Vmprobe::Remote;
use Vmprobe::Util;


sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    $self->{cache} = {};

    return $self;
}



sub get {
    my ($self, %args) = @_;

    my $host = $args{host} // 'localhost';
    my $needs_sudo = !!$args{needs_sudo};

    return $self->{cache}->{$host}->{$needs_sudo}
        if defined $self->{cache}->{$host}->{$needs_sudo};

    $self->{cache}->{$host}->{$needs_sudo} =
        Vmprobe::Remote->new(
            host => $host,
            sudo => $needs_sudo,
            collect_version_info => 0,
            max_connections => $self->{params}->{max_connections_per_remote} // 3,
            reconnection_interval => $self->{params}->{reconnection_interval} // 30,
            on_state_change => sub {},
            on_error_message => sub {
                my $err_msg = shift;
                say STDERR colour("vmprobe: error connecting to $host: $err_msg", 'red');
            },
        );

    return $self->{cache}->{$host}->{$needs_sudo};
}



1;
