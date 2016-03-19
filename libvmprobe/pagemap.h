#pragma once

#include <vector>

#include "file.h"


namespace vmprobe { namespace cache {

class pagemap_result {
  public:
    void read_pagemap(int pagemap_fd, vmprobe::cache::file &f);
    void read_kpageflags(int kpageflags_fd);
    void scan_for_bit(int bit);

    std::vector<uint64_t> page_vec;
    std::vector<uint8_t> mincore_vec;
    std::vector<uint8_t> bitfield_vec;
    uint64_t num_pages;
    uint64_t resident_pages;
};

}}
