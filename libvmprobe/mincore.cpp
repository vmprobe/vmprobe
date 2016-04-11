#include <stdexcept>

#include <unistd.h>
#include <sys/mman.h>

#include "mincore.h"
#include "pageutils.h"


namespace vmprobe { namespace cache {


void mincore_result::mincore(file &f) {
    size_t file_size = f.get_size();
    num_pages = vmprobe::pageutils::bytes2pages(file_size);
    if (num_pages == 0) return;

    char *mmap_ptr = f.get_mmap_ptr();
    if (!mmap_ptr) throw(std::runtime_error("can't mincore: file has not been mmap()ed yet"));

    resident_pages = 0;

    mincore_vec.resize(num_pages);

    // This nasty cast is needed for portability: 3rd argument to mincore is unsigned char* on linux but char* on BSD.
    (*(reinterpret_cast<void(*)(void*, size_t, unsigned char*)>(&::mincore)))(mmap_ptr, file_size, mincore_vec.data());

    for (uint64_t i = 0; i < num_pages; i++) {
        resident_pages |= mincore_vec[i];
    }

    compute_bitfield();
}


void mincore_result::compute_bitfield() {
    bitfield_vec.clear();
    bitfield_vec.resize((mincore_vec.size() + 7) / 8, 0);

    uint8_t *ptr = bitfield_vec.data();

    for (size_t i = 0; i < mincore_vec.size(); i++) {
        ptr[i / 8] |= (mincore_vec[i] & 1) << (i & 7);
    }
}


}}
