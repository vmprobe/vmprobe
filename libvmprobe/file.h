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

enum access_advice {
    NORMAL,
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
    void advise(access_advice advice);

    size_t get_size();

  private:

    int fd = -1;
    size_t file_size;
    char *mmap_ptr = nullptr;
};

}}
