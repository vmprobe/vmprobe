#pragma once

#include <string>
#include <vector>
#include <functional>
#include <stdexcept>

#include "bitfield.h"
#include "binformat.h"


namespace vmprobe { namespace cache { namespace snapshot {


const static uint64_t SNAPSHOT_DELTA = 1;  // whether this snapshot's bitfield should be interpreted as a delta or not

const static uint64_t ELEMENT_DELETED = 1; // in deltas, indicates that this file should be removed from the snapshot


/*

SNAPSHOT_V1:

binformat header:
  "VMP" magic bytes
  VI: type
snapshot data:
  VI: pagesize in bytes (0 special-cased as 4096)
  VI: snapshot flags
  N>=0 records:
    VI: record size in bytes, not including this size
    VI: record flags
    VI: filename size in bytes
    filename
    VI: file size in bytes
    VI: bitfield buckets (in bits)
    bitfield (0 = non-resident, 1 = resident)

(VI == BER encoded uint64_t)

*/




// transient data-structure used internally during parsing/building
// doesn't own any of the data it points to
class element {
  public:
    uint64_t flags = 0;
    char *filename = nullptr;
    size_t filename_len = 0;
    uint64_t file_size = 0;
    vmprobe::cache::bitfield bf;
};


class builder : public vmprobe::cache::binformat::builder {
  public:
    builder();

    void crawl(std::string &path);

    void delta(std::string &before, std::string &after);
    void delta(char *before_ptr, size_t before_len, char *after_ptr, size_t after_len);

  private:
    void add_element_deleted_stub(element &elem);
    void add_element_xor_diff(element &elem_before, element &elem_after);
    void add_element(element &elem);
};




using parser_element_handler_cb = std::function<void(element &elem)>;


class parser : public vmprobe::cache::binformat::parser {
  public:
    parser(char *ptr, size_t len);

    void process(parser_element_handler_cb cb);
    element *next();

    uint64_t pagesize;
    uint64_t flags;

  private:

    std::string curr_filename;
    element curr_elem;
};

void restore(std::string &path, char *snapshot_ptr, size_t snapshot_len);








}}}
