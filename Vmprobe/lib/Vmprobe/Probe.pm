package Vmprobe::Probe;

use common::sense;

use AnyEvent;

use Vmprobe::Util;


sub init {}

sub needs_sudo { 0 }

sub probe_args { die "need to specify probe args" }

sub process_results { return $_[1] }



sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    $self->init();

    $self->{remote} = $self->{engine}->get_remote($self->{params}->{host}, $self->needs_sudo);

    return $self;
}



sub once {
    my ($self, $cb) = @_;

    my ($raw_name, $args, $connection_id) = $self->probe_args();

    my $start = curr_time();

    $self->{remote}->probe($raw_name,
                           $args,
                           sub {
                               my $end = curr_time();

                               my $data = $self->process_results(@_);

                               $cb->({
                                   start => $start,
                                   end => $end,
                                   probe_num => $self->{probe_num},
                                   data => $data,
                               });
                           },
                           $connection_id);
}


sub start_poll {
    my ($self, $cb) = @_;

    $self->{polling} = 1;

    my ($raw_name, $args, $connection_id) = $self->probe_args();

    my $refresh = $self->{params}->{refresh} // 10;

    $self->{timer} = AE::timer $refresh, 0, sub {
        $self->once(sub {
            delete $self->{timer};
            $self->start_poll($cb) if $self->{polling};
            $cb->(@_);
        });
    };
}


sub stop_poll {
    my ($self) = @_;

    delete $self->{timer};
    delete $self->{polling};
}


1;
