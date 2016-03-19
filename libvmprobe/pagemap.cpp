#include <stdexcept>

#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/mman.h>

#include "pagemap.h"
#include "pageutils.h"


namespace vmprobe { namespace cache {

void pagemap_result::read_pagemap(int pagemap_fd, vmprobe::cache::file &f) {
    char *mmap_ptr = f.get_mmap_ptr();
    if (!mmap_ptr) throw(std::runtime_error("file has not been mmap()ed yet"));
    size_t file_size = f.get_size();

    num_pages = vmprobe::pageutils::bytes2pages(file_size);
    if (num_pages == 0) return;


    mincore_vec.resize(num_pages);

    // This nasty cast is needed for portability: 3rd argument to mincore is unsigned char* on linux but char* on BSD.
    (*(reinterpret_cast<void(*)(void*, size_t, unsigned char*)>(&::mincore)))(mmap_ptr, file_size, mincore_vec.data());

    if (madvise(mmap_ptr, file_size, MADV_RANDOM)) throw(std::runtime_error(std::string("madvise failed: ") + std::string(strerror(errno))));

    // soft-fault in PTEs
    for (size_t i = 0; i < num_pages; i++) {
        if (mincore_vec[i] & 1) (void)*(volatile int *)(mmap_ptr + i * vmprobe::pageutils::pagesize());
    }

    if (madvise(mmap_ptr, file_size, MADV_SEQUENTIAL)) throw(std::runtime_error(std::string("madvise failed: ") + std::string(strerror(errno))));


    page_vec.resize(num_pages + 7); // extra 0s at the end simplifies scanning logic
    for (size_t i = 0; i < 7; i++) page_vec[num_pages + i] = 0;

    if (pread(pagemap_fd, page_vec.data(), num_pages * 8, 8 * ((size_t)mmap_ptr / vmprobe::pageutils::pagesize())) != (ssize_t)num_pages * 8) {
        throw(std::runtime_error(std::string("read from pagemap failed: ") + std::string(strerror(errno))));
    }
}


void pagemap_result::read_kpageflags(int kpageflags_fd) {
    for (size_t i=0; i < num_pages; i++) {
        if (page_vec[i] & (1LL << 63)) {
            uint64_t pfn = page_vec[i] & ((1LL << 55) - 1);

            if (pread(kpageflags_fd, &page_vec[i], 8, pfn * 8) != 8) {
                throw(std::runtime_error(std::string("read from kpageflags failed: ") + std::string(strerror(errno))));
            }
        } else {
            page_vec[i] = 0;
        }
    }
}


void pagemap_result::scan_for_bit(int bit) {
    bitfield_vec.clear();
    bitfield_vec.resize((num_pages + 7) / 8, 0);
    resident_pages = 0;

    uint64_t mask = 1LL << bit;

    for (size_t i=0; i < num_pages; i+=8) {
        bitfield_vec[i / 8] =
            (!!(page_vec[i + 0] & mask) << 0) |
            (!!(page_vec[i + 1] & mask) << 1) |
            (!!(page_vec[i + 2] & mask) << 2) |
            (!!(page_vec[i + 3] & mask) << 3) |
            (!!(page_vec[i + 4] & mask) << 4) |
            (!!(page_vec[i + 5] & mask) << 5) |
            (!!(page_vec[i + 6] & mask) << 6) |
            (!!(page_vec[i + 7] & mask) << 7);

        resident_pages |= bitfield_vec[i / 8];
    }
}


}}
