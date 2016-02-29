package Vmprobe::Daemon::DB::Standby;

use common::sense;

use parent 'Vmprobe::Daemon::DB';


sub db_name { 'standby' };

sub key_type { 'autoinc' };
sub value_type { 'sereal' };

 
 
1;
