#pragma once

#include <string>
#include <vector>
#include <functional>
#include <unordered_map>
#include <unordered_set>

#include <sys/types.h>
#include <sys/stat.h>

namespace vmprobe {

using crawler_file_handler_cb = std::function<void(std::string &filename, struct ::stat &sb)>;
using file_index = std::unordered_map<dev_t, std::unordered_set<ino_t>>;

class crawler {
  public:
    // Interface
    crawler(crawler_file_handler_cb file_handler_)
      : file_handler(file_handler_) {}
    void crawl(std::string &path);

    // Parameters
    bool follow_symlinks = false;
    bool skip_duplicate_hardlinks = true;
    int max_crawl_depth = 64;

    // Output
    uint64_t num_dirs = 0;
    uint64_t num_files = 0;
    std::vector<std::string> warnings;

  private:
    void _crawl(std::string &path, file_index &already_seen_files);
    void process_file(std::string &path_std_string, struct ::stat &sb);
    void warning(const char *format, ...);
    void fatal(const char *format, ...);
    void increment_nofile_rlimit();

    crawler_file_handler_cb file_handler;
    int curr_crawl_depth = 0;
};

}
