package Vmprobe::ProbeEngine;

use common::sense;

use YAML;


sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->{spec} = YAML::LoadFile($args{spec_filename});
    $self->{cb} = $args{cb};

    $self->init();

    return $self;
}


sub init {
    $self->{remotes_cache} = {};

    die "must specify one or more probes" if !@{ $self->{spec}->{probes} };

    foreach my $params (@{ $self->{spec}->{probes} }) {
        my $host = $params->{host} // 'localhost';

        if (!exists $self->{remotes_cache}->{$host}) {
            $self->{remotes_cache}->{$host} = Vmprobe::Remote->new(
                host => $host,
                collect_version_info => 0,
                max_connections => $params->{max_connections_per_remote} // 3,
                reconnection_interval => $params->{reconnection_interval} // 30,
                on_state_change => sub {},
                on_error_message => sub {
                    my $err_msg = shift;
                    say STDERR colour("vmprobe: error connecting to $host: $err_msg", $red);
                },
            );
        }

        push @{ $self->{probes} },
             {
                 params => $params,
             };
 
    }
}



sub barrier {
    my ($self) = @_;

    foreach my $probe (@{ $self->{probes} }) {
        $self->run_probe($probe);
    }
}



sub run_probe {
    my ($self, $probe) = @_;

    my $remote = $probe->{params}->{host} // 'localhost';

    my ($probe_name, $args);

    if ($probe->{params}->{type} eq 'cache') {
    } else {
        die "unknown type: $probe->{params}->{type}";
    }

    $remote->probe(
}



1;
