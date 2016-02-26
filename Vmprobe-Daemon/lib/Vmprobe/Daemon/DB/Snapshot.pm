package Vmprobe::Daemon::DB::Snapshot;

use common::sense;

use parent 'Vmprobe::Daemon::DB';


sub db_name { 'snapshot' };

sub key_type { 'autoinc' };
sub value_type { 'sereal' };

 
 
1;
