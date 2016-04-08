package Vmprobe::DB::Global;

use common::sense;

use parent 'Vmprobe::DB::Base';


sub db_name { 'global' };

sub key_type { 'raw' };
sub value_type { 'raw' };


sub check_arch {
    my ($self, $txn) = @_;

    my $word = pack("j", 1); ## MDB_INTEGERKEY assumes IV

    my $word_from_db = $self->get('arch_word_format');

    if (!defined $word_from_db) {
        $self->insert('arch_word_format', $word);
        return;
    }

    my $len = length($word);
    my $len_from_db = length($word_from_db);

    die "incompatible DB: word size is $len_from_db, need $len"
            if $len != $len_from_db;

    die "incompatible DB: endianness"
            if $word ne $word_from_db;
}






1;
