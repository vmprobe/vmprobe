package Vmprobe::DB::ActiveRun;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'active-runs' }

sub key_type { 'raw' }
sub value_type { 'int' }


1;
