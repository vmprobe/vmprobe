#pragma once

#include <vector>

#include "file.h"


namespace vmprobe { namespace cache {

class mincore_result {
  public:
    void mincore(vmprobe::cache::file &f);

    std::vector<uint8_t> bitfield_vec;
    uint64_t num_pages;
    uint64_t resident_pages;

  private:
    void compute_bitfield();

    std::vector<uint8_t> mincore_vec;
};


}}
