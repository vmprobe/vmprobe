#pragma once

namespace vmprobe { namespace cache {


class bitfield {
  public:
    uint64_t num_buckets = 0;
    uint8_t *data = nullptr;

    inline bool is_num_buckets_valid() {
        return (num_buckets <= UINT64_MAX-7);
    }

    inline uint64_t data_size() {
        return (num_buckets + 7) / 8;
    }

    inline int get_bit(uint64_t i) {
        return data[i >> 3] & (1 << (i & 7)) ? 1 : 0;
    }
};


}}
