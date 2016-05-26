package Vmprobe::RunContext;

use common::sense;

use Exporter 'import';
our @EXPORT = qw(new_lmdb_txn switchboard);

use LMDB_File;

use Vmprobe::Cmd;
use Vmprobe::Switchboard;
use Vmprobe::DB::Global;


our $var_dir;
our $cleanup_on_exit;

sub set_var_dir {
    my ($new_var_dir, $do_mkdir, $do_cleanup) = @_;

    die "var dir already set" if defined $var_dir;

    $cleanup_on_exit = $do_cleanup;

    if (defined $new_var_dir) {
        die "var dir $new_var_dir is not a directory" if !-d $new_var_dir;

        $var_dir = $new_var_dir;
    } else {
        my $home_dir = (getpwuid($<))[7] // $ENV{HOME} // die "unable to determine home directory";

        $var_dir = "$home_dir/.vmprobe";

        if (!-d $var_dir) {
            if ($do_mkdir) {
                mkdir($var_dir) || die "unable to create var dir $var_dir ($!)";
            } else {
                die "var directory $var_dir doesn't exist, create with 'vmprobe db init'";
            }
        }
    }

    switchboard(); ## ensure switchboard directory is created
}




our $lmdb_env;

sub _init_db {
    return if defined $lmdb_env;

    die "var dir hasn't been set" if !defined $var_dir;

    my $db_dir = "$var_dir/db";

    if (!-e $db_dir) {
        mkdir($db_dir) || die "couldn't mkdir($db_dir): $!";
    }

    eval {
        $lmdb_env = LMDB::Env->new($db_dir,
                        {
                            mapsize => 100 * 1024 * 1024 * 1024,
                            maxdbs => 32,
                            mode => 0600,
                        });

        my $txn = $lmdb_env->BeginTxn;

        Vmprobe::DB::Global->new($txn)->check_arch($txn);

        $txn->commit;
    };

    if ($@) {
        die "error creating LMDB environment: $@";
    }
}


sub new_lmdb_txn () {
    _init_db();

    return $lmdb_env->BeginTxn();
}


our $switchboard;

sub switchboard () {
    return $switchboard if $switchboard;

    my $txn = new_lmdb_txn;

    my $global_db = Vmprobe::DB::Global->new($txn);

    my $switchboard_dir = $global_db->get('switchboard_dir');
    if (!defined $switchboard_dir || !-d $switchboard_dir) {
        require File::Temp;
        $switchboard_dir = File::Temp::tempdir(CLEANUP => $cleanup_on_exit);

        $global_db->insert('switchboard_dir', $switchboard_dir);
    }

    $txn->commit;

    $switchboard = Vmprobe::Switchboard->new($switchboard_dir);

    return $switchboard;
}




1;
