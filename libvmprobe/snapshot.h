#pragma once

#include <string>
#include <vector>
#include <functional>
#include <stdexcept>

#include "bitfield.h"
#include "binformat.h"


namespace vmprobe { namespace cache { namespace snapshot {


/*

SNAPSHOT_V1:

VI: type
VI: snapshot pagesize in bytes (0 special-cased as 4096)
N>=0 records:
  VI: record size in bytes, not including this size
  VI: filename size in bytes
  filename
  VI: file size in bytes
  VI: bitfield buckets
  bitfield (0 = non-resident, 1 = resident)

*/




class element {
  public:
    char *filename;
    size_t filename_len;
    uint64_t file_size;
    vmprobe::cache::bitfield bf;
};


class builder : protected vmprobe::cache::binformat::builder {
  public:
    builder();

    void crawl(std::string path);

  private:
    void add_element(element &elem);
};


void mincore_vector_to_bitfield(std::vector<uint8_t> &mincore_vector, std::vector<uint8_t> &bf);



using parser_element_handler_cb = std::function<void(element &elem)>;


class parser : protected vmprobe::cache::binformat::parser {
  public:
    parser(vmprobe::cache::binformat::typecode type, char *ptr, size_t len);

    void process(parser_element_handler_cb cb);

    uint64_t snapshot_pagesize;

  private:
    element *next();

    std::string curr_filename;
    element curr_elem;
};

void restore(char *ptr, size_t len);








}}}
