#include <algorithm>
#include <map>

#include <fcntl.h>

#include "pageutils.h"
#include "varuint64.h"
#include "snapshot.h"
#include "crawler.h"
#include "file.h"


namespace vmprobe { namespace cache { namespace snapshot {

builder::builder() : vmprobe::cache::binformat::builder(vmprobe::cache::binformat::typecode::SNAPSHOT_V1) {
    auto pagesize = vmprobe::pageutils::pagesize();
    buf += vmprobe::varuint64::encode(pagesize == 4096 ? 0 : pagesize);
}

void builder::crawl(std::string path) {
    vmprobe::cache::mincore_result r;

    // FIXME: normalize path (remove ".." "." "//")

    vmprobe::crawler c([&](std::string &filename, struct stat &sb) {
        vmprobe::cache::file f(filename);

        f.mmap();
        f.mincore(r);

        element elem;

        elem.filename = (char*) filename.data();
        elem.filename_len = filename.size();
        elem.file_size = f.get_size();
        elem.bf.num_buckets = r.num_pages;
        elem.bf.data = r.bitfield_vec.data();

        add_element(elem);
    });

    c.crawl(path);
}


void builder::add_element(element &elem) {
    std::string tmp;

    tmp += vmprobe::varuint64::encode(elem.filename_len);
    tmp += std::string(elem.filename, elem.filename_len);
    tmp += vmprobe::varuint64::encode(elem.file_size);
    tmp += vmprobe::varuint64::encode(elem.bf.num_buckets);

    buf += vmprobe::varuint64::encode(tmp.size() + elem.bf.data_size());
    buf += tmp;
    buf += std::string(reinterpret_cast<const char *>(elem.bf.data), elem.bf.data_size());
}





parser::parser(vmprobe::cache::binformat::typecode type, char *ptr, size_t len) : vmprobe::cache::binformat::parser(type, ptr, len) {
    if (!vmprobe::varuint64::decode(begin, end, snapshot_pagesize)) throw make_error("unable to parse snapshot_pagesize");
    if (snapshot_pagesize == 0) snapshot_pagesize = 4096;
}


element *parser::next() {
    if (begin == end) return nullptr;

    uint64_t elem_len;
    if (!vmprobe::varuint64::decode(begin, end, elem_len)) throw make_error("bad elem length");

    char *elem_end = begin + elem_len;
    if (elem_end > end || elem_end < begin) throw make_error("declared elem length extends beyond buffer");

    uint64_t filename_len;
    if (!vmprobe::varuint64::decode(begin, elem_end, filename_len)) throw make_error("bad filename length");

    if (begin+filename_len > elem_end || begin+filename_len < begin) throw make_error("declared filename length extends beyond buffer");
    curr_elem.filename = begin;
    curr_elem.filename_len = (size_t)filename_len;
    begin += filename_len;

    if (!vmprobe::varuint64::decode(begin, elem_end, curr_elem.file_size)) throw make_error("bad file size");
    if (!vmprobe::varuint64::decode(begin, elem_end, curr_elem.bf.num_buckets)) throw make_error("bad num buckets");

    if (begin+curr_elem.bf.data_size() > elem_end || begin+curr_elem.bf.data_size() < begin) throw make_error("declared num_buckets extends beyond buffer");
    curr_elem.bf.data = (uint8_t *)begin;
    begin += curr_elem.bf.data_size();

    // support extra trailing space for forwards compatibility
    begin = elem_end;

    return &curr_elem;
}


void parser::process(parser_element_handler_cb cb) {
    element *e;

    while ((e = next())) {
        std::string filename(e->filename, e->filename_len);
        cb(*e);
    }
}


static void restore_residency_state(uint64_t bucket_size, vmprobe::cache::file &file, vmprobe::cache::bitfield &bf) {
    size_t range_start = 0;
    size_t range_end = 0;
    int range_state = -1;

    size_t mem_len = file.get_size();

    file.advise(advice::RANDOM);

    for (uint64_t i=0; i < bf.num_buckets; i++) {
        int bit_state = bf.get_bit(i);
        if (range_state == -1) range_state = bit_state;

        if (bit_state != range_state) {
            if (range_state == 1) file.touch(range_start, range_end - range_start);
            else file.evict(range_start, range_end - range_start);
            range_start = range_end;
            range_state = bit_state;
        }

        range_end += bucket_size;

        if (range_end > mem_len) {
            range_end = mem_len;
            break;
        }
    }

    if (range_start != range_end) {
        if (range_state == 1) file.touch(range_start, range_end - range_start);
        else file.evict(range_start, range_end - range_start);
    }

    file.advise(advice::DEFAULT_NORMAL);
}

void restore(char *ptr, size_t len) {
    parser p(vmprobe::cache::binformat::typecode::SNAPSHOT_V1, ptr, len);

    p.process([&](element &elem) {
        std::string filename(elem.filename, elem.filename_len);
        vmprobe::cache::file f(filename);
        restore_residency_state(p.snapshot_pagesize, f, elem.bf);
    });
}








}}}
