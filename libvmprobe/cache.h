#include <string>
#include <functional>

#include "file.h"


namespace vmprobe { namespace cache {

void process(std::string &path, uint64_t start_page, uint64_t end_page, std::function<void(vmprobe::cache::file &f, uint64_t start_byte, uint64_t end_byte)> cb);

void touch(std::string path);
void touch(std::string path, uint64_t start_page, uint64_t end_page);

void evict(std::string path);
void evict(std::string path, uint64_t start_page, uint64_t end_page);

struct lock_context {
    std::vector<vmprobe::cache::file> files;
};

lock_context *lock(std::string path);
lock_context *lock(std::string path, uint64_t start_page, uint64_t end_page);

}}
