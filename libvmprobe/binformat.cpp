#include <stdexcept>
#include <string>

#include "binformat.h"
#include "varuint64.h"

namespace vmprobe { namespace cache { namespace binformat {


builder::builder(typecode type) {
    buf += vmprobe::varuint64::encode((uint64_t)type);
}


parser::parser(typecode type, char *ptr, size_t len) {
    begin = orig_begin = ptr;
    end = ptr + len;

    uint64_t decoded_type;
    if (!vmprobe::varuint64::decode(begin, end, decoded_type)) throw make_error("unable to parse binformat type");

    if (decoded_type != (uint64_t)type) {
        throw make_error(std::string("unexpected binformat type, wanted ") +
                         std::to_string((uint64_t)type) +
                         std::string("got: ") +
                         std::to_string(decoded_type));
    }
}


std::runtime_error parser::make_error(std::string msg) {
    std::string err = std::string("snapshot parse error: ");

    err += msg;
    err += std::string(" (detected at byte ");
    err += std::to_string(begin - orig_begin);
    err += std::string(")");

    return std::runtime_error(err);
}


}}}
