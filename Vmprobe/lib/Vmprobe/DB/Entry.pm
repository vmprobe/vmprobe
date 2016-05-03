package Vmprobe::DB::Entry;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'entry' }

sub key_type { 'int' }
sub value_type { 'sereal' }



1;
