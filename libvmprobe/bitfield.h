#pragma once

namespace vmprobe { namespace cache {


class bitfield {
  public:
    uint64_t bucket_size;
    uint64_t num_buckets;
    uint8_t *data;

    inline uint64_t data_size() {
        return (num_buckets + 7) / 8;
    }

    inline int get_bit(uint64_t i) {
        return data[i >> 3] & (1 << (i & 7)) ? 1 : 0;
    }
};


}}
