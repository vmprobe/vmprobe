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

    my $self = {};

    $self->{params} = $args{params} || die "need params";

    $self->{probe_id} = get_session_token();
    $self->{start} = curr_time();

    my $type = $self->{params}->{type} // 'cache';
    my $pkg = "Vmprobe::Probe::$type";

    eval "require $pkg" || die "unable to load probe type '$type' ($@)";
    bless $self, $pkg;

    $self->init();

    $self->{remote} = $args{remote_cache}->get(host => $self->{params}->{host}, needs_sudo => $self->needs_sudo);

    return $self;
}


sub summary {
    my ($self) = @_;

    return {
        probe_id => $self->{probe_id},
        start => $self->{start},
        params => $self->{params},
    };
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
                                   probe_id => $self->{probe_id},
                                   start => $start,
                                   end => $end,
                                   data => $data,
                               });
                           },
                           $connection_id);
}


sub once_blocking {
    my ($self, $cb) = @_;

    my $cv = AE::cv;

    $cv->begin;

    $self->once(sub {
        my $result = shift;
        $cb->($result);
        $cv->end;
    });

    $cv->wait;
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
