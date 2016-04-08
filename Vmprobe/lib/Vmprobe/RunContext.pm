package Vmprobe::RunContext;

use common::sense;

use LMDB_File;

use Vmprobe::Cmd;



sub new {
    my ($class, %args) = @_;

    my $self = {};
    bless $self, $class;

    $self->_find_var_dir;
    $self->_init_db;

    return $self;
}


sub _find_var_dir {
    my ($self, $var_dir) = @_;

    if (!defined $var_dir) {
        $var_dir = opt('vmprobe')->{'var-dir'};
    }

    if (!defined $var_dir) {
        my $home_dir = $ENV{HOME} // (getpwuid($<))[7] // die "unable to determine home directory";

        $var_dir = "$home_dir/.vmprobe";

        if (!-d $var_dir) {
            mkdir($var_dir) || die "unable to create var directory $var_dir ($!)";
        }
    }

    $self->{var_dir} = $var_dir;
}


sub _init_db {
    my ($self) = @_;

    my $db_dir = "$self->{var_dir}/db";

    if (!-e $db_dir) {
        say "Creating db directory: $db_dir";
        mkdir($db_dir) || die "couldn't mkdir($db_dir): $!";
    }

    eval {
        $self->{lmdb_env} = LMDB::Env->new($db_dir,
                                {
                                    mapsize => 100 * 1024 * 1024 * 1024,
                                    maxdbs => 32,
                                    mode => 0600,
                                });

        my $txn = $self->{lmdb_env}->BeginTxn;

        require Vmprobe::DB::Global;
        Vmprobe::DB::Global->new($txn)->check_arch($txn);

        $txn->commit;
    };

    if ($@) {
        die "error creating LMDB environment: $@";
    }
}


sub new_txn {
    my ($self) = @_;

    return $self->{lmdb_env}->BeginTxn();
}




1;
