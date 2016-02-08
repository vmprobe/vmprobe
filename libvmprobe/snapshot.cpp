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

void builder::crawl(std::string path, int sparse) {
    uint64_t flags = 0;

    if (sparse) flags |= SNAPSHOT_SPARSE;
    buf += vmprobe::varuint64::encode(flags);

    // FIXME: normalize path (remove ".." "." "//")

    vmprobe::cache::mincore_result r;

    vmprobe::crawler c([&](std::string &filename, struct stat &sb) {
        vmprobe::cache::file f(filename);

        f.mmap();
        f.mincore(r);

        if (sparse && !r.resident_pages) return;

        element elem;

        elem.flags = 0;
        elem.filename = (char*) filename.data();
        elem.filename_len = filename.size();
        elem.file_size = f.get_size();
        elem.bf.num_buckets = r.num_pages;
        elem.bf.data = r.bitfield_vec.data();

        add_element(elem);
    });

    c.crawl(path);
}


void builder::delta(std::string &before, std::string &after) {
    delta((char*)before.data(), before.size(), (char*)after.data(), after.size());
}

void builder::delta(char *before_ptr, size_t before_len, char *after_ptr, size_t after_len) {
    vmprobe::cache::snapshot::parser before_parser(before_ptr, before_len);
    vmprobe::cache::snapshot::parser after_parser(after_ptr, after_len);

    if ((before_parser.flags & SNAPSHOT_SPARSE) != (after_parser.flags & SNAPSHOT_SPARSE)) {
        throw std::runtime_error("one snapshot was sparse, the other wasn't");
    }

    if ((before_parser.flags & SNAPSHOT_DELTA)) {
        throw std::runtime_error("first snapshot cannot be a delta");
    }

    uint64_t new_flags = before_parser.flags;

    if (!(after_parser.flags & SNAPSHOT_DELTA)) {
        new_flags |= SNAPSHOT_DELTA;
    }

    buf += vmprobe::varuint64::encode(new_flags);


    auto *before_elem = before_parser.next();
    auto *after_elem = after_parser.next();

    while (before_elem || after_elem) {
        if (!before_elem) {
            add_element(*after_elem);
            after_elem = after_parser.next();
            continue;
        }

        if (!after_elem) {
            if ((new_flags & SNAPSHOT_DELTA)) {
                add_element_deleted_stub(*before_elem);
            } else {
                add_element(*before_elem);
            }
            before_elem = before_parser.next();
            continue;
        }

        std::string before_filename(before_elem->filename, before_elem->filename_len);
        std::string after_filename(after_elem->filename, after_elem->filename_len);

        int cmp = before_filename.compare(after_filename);

        if (cmp > 0) {
            add_element(*after_elem);
            after_elem = after_parser.next();
            continue;
        } else if (cmp < 0) {
            if ((new_flags & SNAPSHOT_DELTA)) {
                add_element_deleted_stub(*before_elem);
            } else {
                add_element(*before_elem);
            }
            before_elem = before_parser.next();
            continue;
        } else {
            if (!(after_elem->flags & ELEMENT_DELETED)) {
                add_element_xor_diff(*before_elem, *after_elem);
            }
            before_elem = before_parser.next();
            after_elem = after_parser.next();
            continue;
        }
    }
}


void builder::add_element_deleted_stub(element &elem) {
    element new_elem;

    new_elem.flags |= ELEMENT_DELETED;
    new_elem.filename = elem.filename;
    new_elem.filename_len = elem.filename_len;

    add_element(new_elem);
}

void builder::add_element_xor_diff(element &elem_before, element &elem_after) {
    element new_elem;

    new_elem.flags = elem_after.flags;
    new_elem.filename = elem_after.filename;
    new_elem.filename_len = elem_after.filename_len;
    new_elem.file_size = elem_after.file_size;

    std::vector<uint8_t> new_vec(std::max(elem_before.bf.data_size(), elem_after.bf.data_size()), 0);

    size_t i = 0;
    uint8_t accumulator = 0;

    for(; i < std::min(elem_before.bf.data_size(), elem_after.bf.data_size()); i++) {
        new_vec[i] = elem_before.bf.data[i] ^ elem_after.bf.data[i];
        accumulator |= new_vec[i];
    }

    if (elem_before.bf.data_size() > elem_after.bf.data_size()) {
        for(; i < elem_before.bf.data_size(); i++) {
            new_vec[i] = elem_before.bf.data[i];
            accumulator |= new_vec[i];
        }
    }

    if (elem_after.bf.data_size() > elem_after.bf.data_size()) {
        for(; i < elem_after.bf.data_size(); i++) {
            new_vec[i] = elem_after.bf.data[i];
            accumulator |= new_vec[i];
        }
    }

    if (!accumulator) return;

    new_elem.bf.num_buckets = std::max(elem_before.bf.num_buckets, elem_after.bf.num_buckets);
    new_elem.bf.data = new_vec.data();

    add_element(new_elem);
}


void builder::add_element(element &elem) {
    std::string tmp;

    tmp += vmprobe::varuint64::encode(elem.flags);
    tmp += vmprobe::varuint64::encode(elem.filename_len);
    tmp += std::string(elem.filename, elem.filename_len);
    tmp += vmprobe::varuint64::encode(elem.file_size);
    tmp += vmprobe::varuint64::encode(elem.bf.num_buckets);

    buf += vmprobe::varuint64::encode(tmp.size() + elem.bf.data_size());
    buf += tmp;
    buf += std::string(reinterpret_cast<const char *>(elem.bf.data), elem.bf.data_size());
}





parser::parser(char *ptr, size_t len) : vmprobe::cache::binformat::parser(vmprobe::cache::binformat::typecode::SNAPSHOT_V1, ptr, len) {
    if (!vmprobe::varuint64::decode(begin, end, pagesize)) throw make_error("bad pagesize");
    if (pagesize == 0) pagesize = 4096;

    if (!vmprobe::varuint64::decode(begin, end, flags)) throw make_error("bad snapshot flags");
}


element *parser::next() {
    if (begin == end) return nullptr;

    uint64_t elem_len;
    if (!vmprobe::varuint64::decode(begin, end, elem_len)) throw make_error("bad elem length");

    if (elem_len > (uint64_t)(end - begin)) throw make_error("declared elem length extends beyond buffer");
    char *elem_end = begin + elem_len;

    if (!vmprobe::varuint64::decode(begin, elem_end, curr_elem.flags)) throw make_error("bad record flags");

    uint64_t filename_len;
    if (!vmprobe::varuint64::decode(begin, elem_end, filename_len)) throw make_error("bad filename length");

    if (filename_len > (uint64_t)(elem_end - begin)) throw make_error("declared filename length extends beyond buffer");
    curr_elem.filename = begin;
    curr_elem.filename_len = (size_t)filename_len;
    begin += filename_len;

    if (!vmprobe::varuint64::decode(begin, elem_end, curr_elem.file_size)) throw make_error("bad file size");
    if (!vmprobe::varuint64::decode(begin, elem_end, curr_elem.bf.num_buckets)) throw make_error("bad num buckets");
    if (!curr_elem.bf.is_num_buckets_valid()) throw make_error("declared num_buckets too large");

    if (curr_elem.bf.data_size() > (uint64_t)(elem_end - begin)) throw make_error("declared num_buckets extends beyond buffer");
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
    parser p(ptr, len);

    p.process([&](element &elem) {
        std::string filename(elem.filename, elem.filename_len);
        vmprobe::cache::file f(filename);
        restore_residency_state(p.pagesize, f, elem.bf);
    });
}








}}}
