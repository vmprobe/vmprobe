#include <algorithm>

#include "varuint64.h"


namespace vmprobe { namespace varuint64 {

std::string encode(uint64_t input) {
    std::string out;

    do {
      uint8_t c = input & 0x7F;
      out.push_back(c | 0x80);
      input = input >> 7;
    } while (input);

    out.front() &= ~0x80;

    std::reverse(out.begin(), out.end());

    return out;
}


bool decode(char *&begin, char *end, uint64_t &output) {
    uint64_t v = 0;

    while (begin != end) {
        uint64_t curr = (*(uint8_t*)begin) & 0xFF;
        begin++;
        v = (v<<7) | (curr & ~0x80);
        if (!(curr & 0x80)) {
            output = v;
            return true;
        }
    }

    return false;
}

}}
