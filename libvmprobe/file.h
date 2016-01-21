#pragma once

#include <vector>


namespace vmprobe { namespace cache {

class mincore_result {
  public:
    void compute_bitfield();

    std::vector<uint8_t> mincore_vec;
    std::vector<uint8_t> bitfield_vec;
    uint64_t num_pages;
    uint64_t resident_pages;
};

enum class advice {
    DEFAULT_NORMAL,
    SEQUENTIAL,
    RANDOM,
};

class file {
  public:
    file(std::string &filename);
    file(const file &) = delete;
    file(file &&);
    ~file();

    void mmap();
    void mincore(mincore_result &map);
    void touch(size_t start, size_t len);
    void evict(size_t start, size_t len);
    void lock(size_t start, size_t len);
    void advise(advice a);
    void close();
    void munmap();

    size_t get_size();

  private:

    int fd = -1;
    size_t file_size;
    char *mmap_ptr = nullptr;
};

}}
