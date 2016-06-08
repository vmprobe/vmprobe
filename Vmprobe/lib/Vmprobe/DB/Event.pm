package Vmprobe::DB::Event;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'event' }

sub key_type { 'int' }
sub value_type { 'sereal' }



1;
