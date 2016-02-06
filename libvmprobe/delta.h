#pragma once

#include <string>
#include <vector>
#include <functional>
#include <stdexcept>

#include "bitfield.h"
#include "binformat.h"


namespace vmprobe { namespace cache { namespace delta {


/*

DELTA_V1:

"VMP" magic bytes
VI: type
N>=0 records:
  VI: record size in bytes, not including this size
  VI: flags
  VI: filename size in bytes
  filename
  VI: file size in bytes
  VI: total size of patches in bytes, not including this size
  N>=1 patches:
    VI: patch size in bytes, not including this size
    VI: file offset in bytes
    VI: bitfield buckets
    bitfield (0 = same as before, 1 = different)


*/



class patch {
  public:
    uint64_t offset;
    vmprobe::cache::bitfield bf;
};

class element {
  public:
    char *filename;
    size_t filename_len;
    uint64_t file_size;
    std::vector<patch>;
};



class builder : protected vmprobe::cache::binformat::builder {
  public:
    builder(char *before_ptr, size_t before_len, char *after_ptr, size_t after_len);

  private:
    void add_element(element &elem);
};





using parser_element_handler_cb = std::function<void(element &elem)>;


class parser : protected vmprobe::cache::binformat::parser {
  public:
    parser(char *ptr, size_t len);

    void process(parser_element_handler_cb cb);

  private:
    element *next();

    std::string curr_filename;
    element curr_elem;
};




}}}
