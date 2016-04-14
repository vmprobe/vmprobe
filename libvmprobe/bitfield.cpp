#include "bitfield.h"


namespace vmprobe { namespace cache {


__attribute__((__target__("default")))
#include "impl/popcount.fragment"

__attribute__((__target__("popcnt")))
#include "impl/popcount.fragment"


}}
