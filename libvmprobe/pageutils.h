#pragma once

#include <unistd.h>

namespace vmprobe { namespace pageutils {

inline size_t pagesize() {
    static size_t pagesize = sysconf(_SC_PAGESIZE);

    return pagesize;
}

inline bool is_page_aligned(void *p) {
    return 0 == (reinterpret_cast<unsigned long>(p) & (pagesize()-1));
}

inline uint64_t bytes2pages(uint64_t bytes) {
    return (bytes+pagesize()-1) / pagesize();
}

inline uint64_t pages2bytes(uint64_t pages) {
    return pages * pagesize();
}

}}
