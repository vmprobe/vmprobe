package Vmprobe::DB::EntryByProbe;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'entry_by_probe' }

sub key_type { 'raw' }
sub value_type { 'int' }

sub dup_keys { 1 }



1;
