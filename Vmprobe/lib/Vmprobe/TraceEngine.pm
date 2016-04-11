package Vmprobe::TraceEngine;

use common::sense;

use Vmprobe::Remote;
use Vmprobe::Util;



sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    die "must specify one or more probes" if !@{ $self->{probes} };

    $self->{remotes_cache} = {};
    $self->{probe_objs} = [];
    $self->{trace_id} = get_session_token();
    $self->{start} = curr_time();

    my $probe_num = 0;

    foreach my $probe (@{ $self->{probes} }) {
        my $type = $probe->{type} // 'cache';
        my $pkg = "Vmprobe::Probe::$type";

        eval "require $pkg" || die "unable to load probe type '$type' ($@)";

        my $probe_obj = &{ "Vmprobe::Probe::new" }($pkg, params => $probe, engine => $self, probe_num => $probe_num, );
        $probe_num++;

        push @{ $self->{probe_objs} }, $probe_obj;
    }

    return $self;
}



sub summary {
    my ($self) = @_;

    return {
        trace_id => $self->{trace_id},
        start => $self->{start},
        probes => $self->{probes},
    };
}


sub get_remote {
    my ($self, $host, $needs_sudo) = @_;

    $host //= 'localhost';
    $needs_sudo = !!$needs_sudo;

    return $self->{remotes_cache}->{$host}->{$needs_sudo}
        if defined $self->{remotes_cache}->{$host}->{$needs_sudo};

    $self->{remotes_cache}->{$host}->{$needs_sudo} =
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

    return $self->{remotes_cache}->{$host}->{$needs_sudo};
}



sub barrier {
    my ($self) = @_;

    my $cv = AE::cv;

    foreach my $probe_obj (@{ $self->{probe_objs} }) {
        $cv->begin;

        $probe_obj->once(sub {
            my $result = shift;
            $self->{cb}->($result);
            $cv->end;
        });
    }

    $cv->wait;
}

sub start_poll {
    my ($self) = @_;

    foreach my $probe_obj (@{ $self->{probe_objs} }) {
        $probe_obj->start_poll(sub {
            my $result = shift;
            $self->{cb}->($result);
        });
    }
}

sub stop_poll {
    my ($self) = @_;

    foreach my $probe_obj (@{ $self->{probe_objs} }) {
        $probe_obj->stop_poll();
    }
}




1;
