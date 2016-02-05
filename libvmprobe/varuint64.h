#pragma once

#include <string>

namespace vmprobe { namespace varuint64 {

// BER-compressed unsigned integer

std::string encode(uint64_t input);
bool decode(char *&begin, char *end, uint64_t &output);

}}
