#pragma once

#include <string>
#include <vector>
#include <functional>
#include <stdexcept>

#include "bitfield.h"


namespace vmprobe { namespace cache { namespace snapshot {


/*


Specs:

* VI is a BER compressed integer


snapshot v0:

VI: record size in bytes, not including this size
VI: filename size in bytes
filename
VI: file size in bytes
VI: number of resident pages
VI: bitfield bucket size, 0 is special-cased as 4096
VI: bitfield buckets
bitfield






snapshot v1:

VI: type
VI: pagesize in bytes (0 special-cased as 4096)
N>=0 records:
  VI: record size in bytes, not including this size
  VI: filename size in bytes
  filename
  VI: file size in bytes
  VI: bitfield buckets
  bitfield (0 = non-resident, 1 = resident)



delta v1:

VI: type
VI: pagesize in bytes (0 special-cased as 4096)
N>=0 records:
  VI: record size in bytes, not including this size
  VI: filename size in bytes
  filename
  VI: file size in bytes
  N>=1 patches:
    VI: patch size in bytes, not including this size
    VI: file offset in bytes
    VI: bitfield buckets
    bitfield (0 = same as before, 1 = different)


*/




class element {
  public:
    char *filename;
    size_t filename_len;
    uint64_t file_size;
    uint64_t resident_pages;
    vmprobe::cache::bitfield bf;
};


class builder {
  public:
    builder(std::string path);

    std::string buf;

  private:
    void add_element(element &elem);
};


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

void restore(char *ptr, size_t len);








}}}
