#pragma once

#include <cstdint>


namespace vmprobe { namespace cache {


class bitfield {
  public:
    uint64_t num_buckets = 0;
    uint8_t *data = nullptr;

    bool is_num_buckets_valid() {
        return (num_buckets <= UINT64_MAX-7);
    }

    uint64_t data_size() {
        return (num_buckets + 7) / 8;
    }

    int get_bit(uint64_t i) {
        return data[i >> 3] & (1 << (i & 7)) ? 1 : 0;
    }

    __attribute__((__target__("default"))) uint64_t popcount();
    __attribute__((__target__("popcnt")))  uint64_t popcount();
};


}}
