#pragma once

#include <string>


namespace vmprobe { namespace cache { namespace binformat {

enum class typecode : uint64_t {
    SNAPSHOT_V1 = 0,
};


class builder {
  public:
    builder(typecode type);

    std::string buf;
};


class parser {
  public:
    parser(typecode type, char *ptr, size_t len);

  protected:
    std::runtime_error make_error(std::string msg);

    char *begin;
    char *orig_begin;
    char *end;
};


}}}
