package Vmprobe::Daemon::DB::Remote;

use common::sense;

use parent 'Vmprobe::Daemon::DB';


sub db_name { 'remote' };

sub key_type { 'autoinc' };
sub value_type { 'sereal' };



1;
