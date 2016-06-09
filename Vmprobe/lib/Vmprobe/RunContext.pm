package Vmprobe::RunContext;

use common::sense;

use Exporter 'import';
our @EXPORT = qw(new_lmdb_txn switchboard logger);

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
    _init_db() if !$lmdb_env;

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




our $logger;
our $print_to_stdout;

sub init_logger {
    ($print_to_stdout) = @_;

    return if defined $logger;

    require Log::File::Rolling;
    require Log::Defer;
    require JSON::XS;
    require Data::Dumper;

    die "var dir hasn't been set" if !defined $var_dir;
 
    my $log_dir = "$var_dir/logs";

    if (!-e $log_dir) {
        mkdir($log_dir) || die "couldn't mkdir($log_dir): $!";
    }

    $logger = Log::File::Rolling->new(
                  filename => "$log_dir/api.%Y-%m-%dT%H.log",
                  current_symlink => "$log_dir/api.log.current",
                  timezone => 'localtime',
              ) || die "Error creating Log::File::Rolling logger: $!";
}


sub logger {
    my ($self) = @_;

    die "logger not yet initialized" if !$logger;

    return Log::Defer->new({ cb => sub {
        my $msg = shift;

        if ($print_to_stdout) {
            state $pretty_json = JSON::XS->new->canonical(1)->pretty(1);
            say $pretty_json->encode($msg);
        }

        my $encoded_msg;
        eval {
            $encoded_msg = JSON::XS::encode_json($msg)
        };

        if ($@) {
            eval {
                $encoded_msg = JSON::XS::encode_json(_json_clean($msg));
            };

            if ($@) {
                $encoded_msg = "Failed to JSON clean: " . Data::Dumper::Dumper($msg);
            }
        }

        $logger->log("$encoded_msg\n");
    }});
}


sub _json_clean {
    my $x = shift;

    if (ref $x) {
        if (ref $x eq 'ARRAY') {
            $x->[$_] = _json_clean($x->[$_]) for 0 .. @$x-1;
        } elsif (ref $x eq 'HASH') {
            $x->{$_} = _json_clean($x->{$_}) for keys %$x;
        } else {
            $x = "Unable to JSON encode: " . Dumper($x);
        }
    }

    return $x;
}




1;
