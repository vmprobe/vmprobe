#pragma once

#include <string>
#include <vector>

#include "snapshot.h"


namespace vmprobe { namespace cache { namespace snapshot { namespace summary {

class bucket {
  public:
    uint64_t num_pages = 0;
    uint64_t num_resident = 0;
    uint64_t num_files = 0;

    char *start_filename = nullptr;
    size_t start_filename_len = 0;
    uint64_t start_page_offset = 0;
};

class builder {
  public:
    builder(std::string path_, uint64_t num_buckets_);

    // input:
    std::string path; // file/directory prefix to summarise, empty string is longest common prefix in snapshot
    uint64_t num_buckets; // max number of buckets

    // output
    std::vector<bucket> buckets;
    char *last_filename = nullptr;
    size_t last_filename_len = 0;
    uint64_t last_page_offset = 0;

    bool match(char *filename, size_t filename_len);
    void add_element(vmprobe::cache::snapshot::element &elem);
    void compress();

  private:
    std::string path_plus_slash;
    uint64_t pages_per_bucket = 1;
};



void summarize(char *snapshot_ptr, size_t snapshot_len, std::vector<builder> &summaries);
}}}}
