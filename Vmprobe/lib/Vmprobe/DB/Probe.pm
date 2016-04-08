package Vmprobe::DB::Probe;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'probe' };

sub key_type { 'raw' };
sub value_type { 'sereal' };



1;
