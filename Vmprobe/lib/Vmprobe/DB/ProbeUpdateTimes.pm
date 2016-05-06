package Vmprobe::DB::ProbeUpdateTimes;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'probe_update_times' }

sub key_type { 'int' }
sub value_type { 'raw' }



1;
