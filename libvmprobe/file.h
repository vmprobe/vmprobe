#pragma once

#include <vector>
#include <string>


namespace vmprobe { namespace cache {

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
    void touch(size_t start, size_t len);
    void evict(size_t start, size_t len);
    void lock(size_t start, size_t len);
    void advise(advice a);
    void close();
    void munmap();

    size_t get_size() { return file_size; };
    char *get_mmap_ptr() { return mmap_ptr; };

  private:

    int fd = -1;
    size_t file_size;
    char *mmap_ptr = nullptr;
};

}}
