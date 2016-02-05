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

VI: type
N>=0 records:
  VI: record size in bytes, not including this size
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


}}}
