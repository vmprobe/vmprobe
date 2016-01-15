#pragma once

#include <string>
#include <vector>
#include <functional>
#include <stdexcept>

namespace vmprobe { namespace cache { namespace snapshot {



class bitfield {
  public:
    uint64_t bucket_size;
    uint64_t num_buckets;
    uint8_t *data;

    inline uint64_t data_size() {
        return (num_buckets + 7) / 8;
    }

    inline int get_bit(uint64_t i) {
        return data[i >> 3] & (1 << (i & 7)) ? 1 : 0;
    }
};


class element {
  public:
    char *filename;
    size_t filename_len;
    uint64_t file_size;
    uint64_t resident_pages;
    bitfield bf;
};





class builder {
  public:
    builder(std::string path);

    std::string buf;

  private:
    void add_element(element &elem);
};

std::string encode_varuint64(uint64_t input);

void mincore_vector_to_bitfield(std::vector<uint8_t> &mincore_vector, std::vector<uint8_t> &bf);




using parser_element_handler_cb = std::function<void(element &elem)>;


class parser {
  public:
    parser(char *ptr, size_t len)
      : begin(ptr), orig_begin(ptr), end(ptr + len) {};

    void process(parser_element_handler_cb cb);

  private:
    std::runtime_error make_error(std::string msg);
    element *next();

    char *begin;
    char *orig_begin;
    char *end;

    std::string curr_filename;
    element curr_elem;
};

bool decode_varuint64(char *&begin, char *end, uint64_t &output);



void restore(char *ptr, size_t len);



class summary_bucket {
  public:
    uint64_t num_pages = 0;
    uint64_t num_resident = 0;
    uint64_t num_files = 0;

    char *start_filename = nullptr;
    size_t start_filename_len = 0;
    uint64_t start_page_offset = 0;
};

class summary {
  public:
    summary(std::string path_, uint64_t num_buckets_);

    // input:
    std::string path; // file/directory prefix to summarise, empty string is longest common prefix in snapshot
    uint64_t num_buckets; // max number of buckets

    // output
    std::vector<summary_bucket> buckets;
    char *last_filename = nullptr;
    size_t last_filename_len = 0;
    uint64_t last_page_offset = 0;

    bool match(char *filename, size_t filename_len);
    void add_element(element &elem);
    void compress();

  private:
    std::string path_plus_slash;
    uint64_t pages_per_bucket = 1;
};



void summarize(char *snapshot_ptr, size_t snapshot_len, std::vector<summary> &summaries);


class diff {
  public:
    std::string filename;
    uint64_t touched = 0;
    uint64_t evicted = 0;
};

void diff_snapshots(char *ptr_a, size_t len_a, char *ptr_b, size_t leb_b, std::vector<diff> &diffs);


}}}
