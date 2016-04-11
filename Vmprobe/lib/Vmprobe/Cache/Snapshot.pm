package Vmprobe::Cache::Snapshot;

use common::sense;

require XSLoader;
XSLoader::load;



## https://www.kernel.org/doc/Documentation/vm/pagemap.txt

our $pagemap_string_to_bit = {
    ## pagemap bits

    soft_dirty => 55,
    exclusively_mapped => 56,
    file_or_shared_anon => 61,
    swapped => 62,
    mincore => 63,

    ## kpageflags bits

    locked => 0,
    error => 1,
    referenced => 2,
    uptodate => 3,
    dirty => 4,
    lru => 5,
    active => 6,
    slab => 7,
    writeback => 8,
    reclaim => 9,
    buddy => 10,
    mmap => 11,
    anon => 12,
    swapcache => 13,
    swapbacked => 14,
    compound_head => 15,
    compound_tail => 16,
    huge => 17,
    unevictable => 18,
    hwpoison => 19,
    nopage => 20,
    ksm => 21,
    thp => 22,
    balloon => 23,
    zero_page => 24,
    idle => 25,
};

sub take {
    my ($path, $flags) = @_;

    die "need a path" if !defined $path;
    die "must provide an array ref of flags" if ref($flags) ne 'ARRAY' || !@$flags;

    if (@$flags == 1 && $flags->[0] eq 'mincore') {
        my $snap = _take_mincore($path, my $total_files, my $total_pages);
        return { pages => $total_pages, files => $total_files, snapshots => { mincore => $snap, } };
    }

    my @bits;

    foreach my $flag (@$flags) {
        push @bits, ($pagemap_string_to_bit->{$flag} // die "unknown page flag: $flag");
    }

    my $snaps = _take_pagemap($path, \@bits, my $total_files, my $total_pages);
    my $output = { pages => $total_pages, files => $total_files, snapshots => {} };

    for my $i (0 .. (@$flags - 1)) {
        $output->{snapshots}->{$flags->[$i]} = $snaps->[$i];
    }

    return $output;
}




1;
