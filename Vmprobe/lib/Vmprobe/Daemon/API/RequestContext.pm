package Vmprobe::Daemon::API::RequestContext;

use common::sense;

use LMDB_File qw(:flags :cursor_op);


sub new {
    my ($class, %args) = @_;

    my $self = \%args;
    bless $self, $class;

    return $self;
}


sub req { shift->{req} }
sub res { shift->{res} }
sub url_args { shift->{url_args} }
sub params { shift->{params} }
sub lmdb { shift->{lmdb} }


sub err_bad_request {
    my ($self, $msg) = @_;

    $self->{res}->status(400);

    return {
        error => $msg,
    };
}




sub foreach_db {
    my ($self, $db, $cb) = @_;

    my $cursor = my $cursor = $db->Cursor;

    my ($key, $value);

    eval {
        $cursor->get($key, $value, MDB_FIRST);
    };

    return if $@;

    $cb->($key, $value);

    while(1) {
        eval {
            $cursor->get($key, $value, MDB_NEXT);
        };

        return if $@;

        $cb->($key, $value);
    }
}



1;
