#include <iostream> //FIXME
#include <algorithm>
#include <map>

#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include "pageutils.h"
#include "varuint64.h"
#include "path.h"
#include "snapshot.h"
#include "crawler.h"
#include "file.h"
#include "pagemap.h"
#include "mincore.h"


namespace vmprobe { namespace cache { namespace snapshot {


pagemap_builder::pagemap_builder() {
    init_proc_files();
}

pagemap_builder::~pagemap_builder() {
    if (pagemap_fd != -1) {
        close(pagemap_fd);
        pagemap_fd = -1;
    }

    if (kpageflags_fd != -1) {
        close(kpageflags_fd);
        kpageflags_fd = -1;
    }
}

void pagemap_builder::init_proc_files() {
    if (pagemap_fd == -1) {
        pagemap_fd = open("/proc/self/pagemap", O_RDONLY, 0);
        if (pagemap_fd == -1) throw(std::runtime_error(std::string("Failed to open /proc/self/pagemap: ") + std::string(strerror(errno))));
    }

    if (kpageflags_fd == -1) {
        kpageflags_fd = open("/proc/kpageflags", O_RDONLY, 0);
        if (kpageflags_fd == -1) throw(std::runtime_error(std::string("Failed to open /proc/kpageflags: ") + std::string(strerror(errno))));
    }
}

void pagemap_builder::register_pagemap_bit(int bit) {
    pagemap_bits.push_back(bit);
    builder_objs_pagemap.emplace_back();
    builder_objs_pagemap.back().add_snapshot_flags(0);
}

void pagemap_builder::register_kpageflags_bit(int bit) {
    kpageflags_bits.push_back(bit);
    builder_objs_kpageflags.emplace_back();
    builder_objs_kpageflags.back().add_snapshot_flags(0);
}


void pagemap_builder::crawl(std::string &path) {
    std::string normalized_path = vmprobe::path::normalize(path);

    vmprobe::cache::pagemap_result r;

    vmprobe::crawler c([&](std::string &filename, struct stat &sb) {
        vmprobe::cache::file f(filename);

        total_pages_crawled += vmprobe::pageutils::bytes2pages(f.get_size());

        f.mmap();
        r.read_pagemap(pagemap_fd, f);

        for (size_t i=0; i < pagemap_bits.size(); i++) {
            r.scan_for_bit(pagemap_bits[i]);
            if (!r.resident_pages) continue;

            element elem;

            elem.flags = 0;
            elem.filename = (char*) filename.data() + normalized_path.size();
            elem.filename_len = filename.size() - normalized_path.size();
            elem.file_size = f.get_size();
            elem.bf.num_buckets = r.num_pages;
            elem.bf.data = r.bitfield_vec.data();

            builder_objs_pagemap[i].add_element(elem);
        }

        r.read_kpageflags(kpageflags_fd);

        for (size_t i=0; i < kpageflags_bits.size(); i++) {
            r.scan_for_bit(kpageflags_bits[i]);
            if (!r.resident_pages) continue;

            element elem;

            elem.flags = 0;   
            elem.filename = (char*) filename.data() + normalized_path.size();
            elem.filename_len = filename.size() - normalized_path.size();
            elem.file_size = f.get_size();
            elem.bf.num_buckets = r.num_pages;
            elem.bf.data = r.bitfield_vec.data();

            builder_objs_kpageflags[i].add_element(elem);
        }
    });

    c.crawl(normalized_path);

    total_files_crawled += c.num_files;
}

std::string pagemap_builder::get_pagemap_snapshot(int bit) {
    auto it = std::find(pagemap_bits.begin(), pagemap_bits.end(), bit);

    if (it == pagemap_bits.end()) throw std::runtime_error("no such pagemap bit");

    return builder_objs_pagemap[it - pagemap_bits.begin()].get_snapshot();
}

std::string pagemap_builder::get_kpageflags_snapshot(int bit) {
    auto it = std::find(kpageflags_bits.begin(), kpageflags_bits.end(), bit);

    if (it == kpageflags_bits.end()) throw std::runtime_error("no such kpageflags bit");

    return builder_objs_kpageflags[it - kpageflags_bits.begin()].get_snapshot();
}




builder::builder() : vmprobe::cache::binformat::builder(vmprobe::cache::binformat::typecode::SNAPSHOT_V1) {
    auto pagesize = vmprobe::pageutils::pagesize();
    buf += vmprobe::varuint64::encode(pagesize == 4096 ? 0 : pagesize);
}

void builder::crawl(std::string &path) {
    std::string normalized_path = vmprobe::path::normalize(path);

    add_snapshot_flags(0);

    vmprobe::cache::mincore_result r;

    vmprobe::crawler c([&](std::string &filename, struct stat &sb) {
        vmprobe::cache::file f(filename);

        total_pages_crawled += vmprobe::pageutils::bytes2pages(f.get_size());

        f.mmap();

        r.mincore(f);
        if (!r.resident_pages) return;

        element elem;

        elem.flags = 0;
        elem.filename = (char*) filename.data() + normalized_path.size();
        elem.filename_len = filename.size() - normalized_path.size();
        elem.file_size = f.get_size();
        elem.bf.num_buckets = r.num_pages;
        elem.bf.data = r.bitfield_vec.data();

        add_element(elem);
    });

    c.crawl(normalized_path);

    total_files_crawled += c.num_files;
}


std::string builder::get_snapshot() {
    return std::string(buf.data(), buf.size());
}


void builder::delta(std::string &before, std::string &after) {
    delta((char*)before.data(), before.size(), (char*)after.data(), after.size());
}

/*
N: normal (non-delta)
D: delta

N, N: D, add stub
N, D: N, ignore
D, N: invalid
D, D: D, merge
*/

void builder::delta(char *before_ptr, size_t before_len, char *after_ptr, size_t after_len) {
    vmprobe::cache::snapshot::parser before_parser(before_ptr, before_len);
    vmprobe::cache::snapshot::parser after_parser(after_ptr, after_len);

    bool before_is_delta = (before_parser.flags & SNAPSHOT_DELTA);
    bool after_is_delta = (after_parser.flags & SNAPSHOT_DELTA);

    uint64_t new_flags = 0;

    if ((before_is_delta && after_is_delta) || (!before_is_delta && !after_is_delta)) {
        new_flags |= SNAPSHOT_DELTA;
    } else if (before_is_delta && !after_is_delta) {
        throw std::runtime_error("if before snapshot is a delta, after must be too");
    }

    add_snapshot_flags(new_flags);


    auto *before_elem = before_parser.next();
    auto *after_elem = after_parser.next();

    while (before_elem || after_elem) {
        if (!before_elem) {
            delta_add_elem(before_is_delta, after_elem);
            after_elem = after_parser.next();
            continue;
        }

        if (!after_elem) {
            delta_del_elem(before_is_delta, after_is_delta, before_elem);
            before_elem = before_parser.next();
            continue;
        }

        std::string before_filename(before_elem->filename, before_elem->filename_len);
        std::string after_filename(after_elem->filename, after_elem->filename_len);

        int cmp = before_filename.compare(after_filename);

        if (cmp > 0) {
            delta_add_elem(before_is_delta, after_elem);
            after_elem = after_parser.next();
            continue;
        } else if (cmp < 0) {
            delta_del_elem(before_is_delta, after_is_delta, before_elem);
            before_elem = before_parser.next();
            continue;
        } else {
            if (!before_is_delta && !after_is_delta) {
                add_element_xor_diff(*before_elem, *after_elem);
            } else if (!before_is_delta && after_is_delta) {
                if ((after_elem->flags & ELEMENT_DELETED)) {
                    if (after_elem->bf.num_buckets) {
                        if (!before_is_delta) after_elem->flags &= ~ELEMENT_DELETED;
                        add_element(*after_elem);
                    }
                } else {
                    add_element_xor_diff(*before_elem, *after_elem);
                }
            } else {
                if ((after_elem->flags & ELEMENT_DELETED)) {
                    add_element(*after_elem);
                } else {
                    add_element_xor_diff(*before_elem, *after_elem);
                }
            }
            before_elem = before_parser.next();
            after_elem = after_parser.next();
            continue;
        }
    }
}


void builder::delta_add_elem(bool before_is_delta, element *elem) {
    if ((elem->flags & ELEMENT_DELETED)) {
        if (elem->bf.num_buckets) {
            if (!before_is_delta) elem->flags &= ~ELEMENT_DELETED;
            add_element(*elem);
        }
    } else {
        add_element(*elem);
    }
}

void builder::delta_del_elem(bool before_is_delta, bool after_is_delta, element *elem) {
    if (!before_is_delta && !after_is_delta) {
        element new_elem;

        new_elem.flags |= ELEMENT_DELETED;
        new_elem.filename = elem->filename;
        new_elem.filename_len = elem->filename_len;

        add_element(new_elem);
    } else {
        add_element(*elem);
    }
}

void builder::add_element_xor_diff(element &elem_before, element &elem_after) {
    element new_elem;

    new_elem.flags = 0;

    if ((elem_before.flags & ELEMENT_DELETED) || (elem_after.flags & ELEMENT_DELETED)) {
        new_elem.flags |= ELEMENT_DELETED;
    }

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

    if (elem_after.bf.data_size() > elem_before.bf.data_size()) {
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




void builder::build_union(std::string &a, std::string &b) {
    build_union((char*)a.data(), a.size(), (char*)b.data(), b.size());
}

void builder::build_union(char *a_ptr, size_t a_len, char *b_ptr, size_t b_len) {
    add_snapshot_flags(0);

    vmprobe::cache::snapshot::parser a_parser(a_ptr, a_len);
    vmprobe::cache::snapshot::parser b_parser(b_ptr, b_len);

    auto *a_elem = a_parser.next();
    auto *b_elem = b_parser.next();

    while (a_elem || b_elem) {
        if (!a_elem) {
            add_element(*b_elem);
            b_elem = b_parser.next();
            continue;
        }

        if (!b_elem) {
            add_element(*a_elem);
            a_elem = a_parser.next();
            continue;
        }

        std::string a_filename(a_elem->filename, a_elem->filename_len);
        std::string b_filename(b_elem->filename, b_elem->filename_len);

        int cmp = a_filename.compare(b_filename);

        if (cmp > 0) {
            add_element(*b_elem);
            b_elem = b_parser.next();
            continue;
        } else if (cmp < 0) {
            add_element(*a_elem);
            a_elem = a_parser.next();
            continue;
        } else {
            add_element_bitwise_or(*a_elem, *b_elem);

            a_elem = a_parser.next();
            b_elem = b_parser.next();
            continue;
        }
    }
}



void builder::add_element_bitwise_or(element &elem_a, element &elem_b) {
    element new_elem;

    new_elem.flags = 0;
    new_elem.filename = elem_a.filename;
    new_elem.filename_len = elem_a.filename_len;
    new_elem.file_size = std::max(elem_a.file_size, elem_b.file_size);

    std::vector<uint8_t> new_vec(std::max(elem_a.bf.data_size(), elem_b.bf.data_size()), 0);

    size_t i = 0;
    uint8_t accumulator = 0;

    for(; i < std::min(elem_a.bf.data_size(), elem_b.bf.data_size()); i++) {
        new_vec[i] = elem_a.bf.data[i] | elem_b.bf.data[i];
        accumulator |= new_vec[i];
    }

    if (elem_a.bf.data_size() > elem_b.bf.data_size()) {
        for(; i < elem_a.bf.data_size(); i++) {
            new_vec[i] = elem_a.bf.data[i];
            accumulator |= new_vec[i];
        }
    }

    if (elem_b.bf.data_size() > elem_a.bf.data_size()) {
        for(; i < elem_b.bf.data_size(); i++) {
            new_vec[i] = elem_b.bf.data[i];
            accumulator |= new_vec[i];
        }
    }

    if (!accumulator) return;

    new_elem.bf.num_buckets = std::max(elem_a.bf.num_buckets, elem_b.bf.num_buckets);
    new_elem.bf.data = new_vec.data();

    add_element(new_elem);
}




void builder::build_intersection(std::string &a, std::string &b) {
    build_intersection((char*)a.data(), a.size(), (char*)b.data(), b.size());
}

void builder::build_intersection(char *a_ptr, size_t a_len, char *b_ptr, size_t b_len) {
    add_snapshot_flags(0);

    vmprobe::cache::snapshot::parser a_parser(a_ptr, a_len);
    vmprobe::cache::snapshot::parser b_parser(b_ptr, b_len);

    auto *a_elem = a_parser.next();
    auto *b_elem = b_parser.next();

    while (a_elem || b_elem) {
        if (!a_elem) {
            b_elem = b_parser.next();
            continue;
        }

        if (!b_elem) {
            a_elem = a_parser.next();
            continue;
        }

        std::string a_filename(a_elem->filename, a_elem->filename_len);
        std::string b_filename(b_elem->filename, b_elem->filename_len);

        int cmp = a_filename.compare(b_filename);

        if (cmp > 0) {
            b_elem = b_parser.next();
            continue;
        } else if (cmp < 0) {
            a_elem = a_parser.next();
            continue;
        } else {
            add_element_bitwise_and(*a_elem, *b_elem);

            a_elem = a_parser.next();
            b_elem = b_parser.next();
            continue;
        }
    }
}



void builder::add_element_bitwise_and(element &elem_a, element &elem_b) {
    element new_elem;

    new_elem.flags = 0;
    new_elem.filename = elem_a.filename;
    new_elem.filename_len = elem_a.filename_len;
    new_elem.file_size = std::max(elem_a.file_size, elem_b.file_size);

    std::vector<uint8_t> new_vec(std::max(elem_a.bf.data_size(), elem_b.bf.data_size()), 0);

    size_t i = 0;
    uint8_t accumulator = 0;

    for(; i < std::min(elem_a.bf.data_size(), elem_b.bf.data_size()); i++) {
        new_vec[i] = elem_a.bf.data[i] & elem_b.bf.data[i];
        accumulator |= new_vec[i];
    }

    if (!accumulator) return;

    new_elem.bf.num_buckets = std::max(elem_a.bf.num_buckets, elem_b.bf.num_buckets);
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

void builder::add_snapshot_flags(uint64_t flags) {
    buf += vmprobe::varuint64::encode(flags);
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

    file.advise(advice::SEQUENTIAL);

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

void restore(std::string &path, char *snapshot_ptr, size_t snapshot_len) {
    std::string normalized_path = vmprobe::path::normalize(path);

    parser p(snapshot_ptr, snapshot_len);
    element *e = p.next();

    if ((p.flags & SNAPSHOT_DELTA)) {
        throw std::runtime_error("can't restore a snapshot delta");
    }

    vmprobe::crawler c([&](std::string &crawler_filename, struct stat &sb) {
      vmprobe::cache::file f(crawler_filename);

      while(1) {
        if (!e) {
            f.evict(0, sb.st_size);
            return;
        }

        int cmp = crawler_filename.compare(normalized_path.size(), std::string::npos, e->filename, e->filename_len);

        if (cmp > 0) {
            // in snapshot, not in filesystem
            e = p.next();
        } else if (cmp < 0) {
            // in filesystem, not in snapshot
            f.evict(0, sb.st_size);
            return;
        } else {
            restore_residency_state(p.pagesize, f, e->bf);
            e = p.next();
            return;
        }
      }
    });

    c.crawl(normalized_path);
}








}}}
