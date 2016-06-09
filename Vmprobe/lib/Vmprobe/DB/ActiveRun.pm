package Vmprobe::DB::ActiveRuns;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'active-runs' }

sub key_type { 'raw' }
sub value_type { 'raw' }


1;
