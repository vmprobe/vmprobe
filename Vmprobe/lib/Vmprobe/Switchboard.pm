package Vmprobe::Switchboard;

use common::sense;

use AnyEvent;
use Linux::Inotify2;



sub new {
    my ($class, $dir) = @_;

    die "need dir argument" if !defined $dir;
    die "argument $dir not a directory" if !-d $dir;

    my $self = { dir => $dir };
    bless $self, $class;

    return $self; 
}



sub get_dir {
    my ($self) = @_;

    return $self->{dir};
}



sub trigger {
    my ($self, $channel) = @_;

    $self->_validate_channel($channel);

    my $filename = "$self->{dir}/$channel";

    open(my $fh, '>>', $filename) || die "unable to open file: $filename";

    utime(undef, undef, $fh) || die "unable to touch file: $filename";

    return $self;
}


sub listen {
    my ($self, $channel, $cb) = @_;

    $self->_validate_channel($channel);

    if (!$self->{inotify}) {
        $self->{inotify} = Linux::Inotify2->new() || die "Unable to create Linux::Inotify2 object: $!";
        $self->{inotify}->blocking(0);

        $self->{io_watcher} = AE::io($self->{inotify}->fileno, 0, sub {
            $self->{inotify}->poll;
        });
    }

    my $cbs = ($self->{cbs} ||= {});
    die "already listening for channel $channel" if $cbs->{$channel};
    $cbs->{$channel} = $cb;

    $self->{io_handler} ||= sub {
        my $e = shift;
        
        die "unrecognized inotify event" unless $e->{w}->{name} =~ m{/([^/]+)\z};
        my $channel = $1;

        if ($cbs->{$channel}) {
            if ($e->IN_DELETE_SELF) {
                $cbs->{$channel}->(1);
                $e->w->cancel;
            } else {
                $cbs->{$channel}->(0);
            }
        } else {
            $e->w->cancel;
        }
    };

    my $filename = "$self->{dir}/$channel";

    open(my $fh, '>>', $filename) || die "unable to open file: $filename";

    ## Short race condition here: filename could be unlinked

    $self->{inotify}->watch($filename, IN_ATTRIB|IN_DELETE_SELF, $self->{io_handler});
}


sub unlisten {
    my ($self, $channel) = @_;

    $self->_validate_channel($channel);

    delete $self->{cbs}->{$channel};
}





sub _validate_channel {
    my ($self, $channel) = @_;

    die "need channel name argument" if !defined $channel || length($channel) < 1;
    die "channel name cannot contain / or . or a NUL byte" if $channel =~ m{[/.\x00]};
}



sub DESTROY {
    my ($self) = @_;

    ## To ensure deletion order
    delete $self->{io_watcher};
    delete $self->{inotify};
}

1;
