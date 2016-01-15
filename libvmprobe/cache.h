#include <string>


namespace vmprobe { namespace cache {

void touch(std::string path);
void touch(std::string path, uint64_t start_page, uint64_t end_page);

void evict(std::string path);
void evict(std::string path, uint64_t start_page, uint64_t end_page);

}}
