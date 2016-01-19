#include <algorithm>
#include <map>

#include <fcntl.h>

#include "pageutils.h"
#include "snapshot.h"
#include "crawler.h"
#include "file.h"


namespace vmprobe { namespace cache { namespace snapshot {


std::string encode_varuint64(uint64_t input) {
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


bool decode_varuint64(char *&begin, char *end, uint64_t &output) {
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





builder::builder(std::string path) {
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
        elem.resident_pages = r.resident_pages;
        elem.bf.bucket_size = vmprobe::pageutils::pagesize();
        elem.bf.num_buckets = r.num_pages;
        elem.bf.data = r.bitfield_vec.data();

        add_element(elem);
    });

    c.crawl(path);
}


void builder::add_element(element &elem) {
    std::string tmp;

    tmp += encode_varuint64(elem.filename_len);
    tmp += std::string(elem.filename, elem.filename_len);
    tmp += encode_varuint64(elem.file_size);
    tmp += encode_varuint64(elem.resident_pages);
    tmp += encode_varuint64(elem.bf.bucket_size == 4096 ? 0 : elem.bf.bucket_size);
    tmp += encode_varuint64(elem.bf.num_buckets);

    buf += encode_varuint64(tmp.size() + elem.bf.data_size());
    buf += tmp;
    buf += std::string(reinterpret_cast<const char *>(elem.bf.data), elem.bf.data_size());
}



std::runtime_error parser::make_error(std::string msg) {
    std::string err = std::string("snapshot parse error: ");

    err += msg;
    err += std::string(" (detected at byte ");
    err += std::to_string(begin - orig_begin);
    err += std::string(")");

    return std::runtime_error(err);
}


element *parser::next() {
    if (begin == end) return nullptr;

    uint64_t elem_len;
    if (!decode_varuint64(begin, end, elem_len)) throw make_error("bad elem length");

    char *elem_end = begin + elem_len;
    if (elem_end > end || elem_end < begin) throw make_error("declared elem length extends beyond buffer");

    uint64_t filename_len;
    if (!decode_varuint64(begin, elem_end, filename_len)) throw make_error("bad filename length");

    if (begin+filename_len > elem_end || begin+filename_len < begin) throw make_error("declared filename length extends beyond buffer");
    curr_elem.filename = begin;
    curr_elem.filename_len = (size_t)filename_len;
    begin += filename_len;

    if (!decode_varuint64(begin, elem_end, curr_elem.file_size)) throw make_error("bad file size");
    if (!decode_varuint64(begin, elem_end, curr_elem.resident_pages)) throw make_error("bad resident pages");
    if (!decode_varuint64(begin, elem_end, curr_elem.bf.bucket_size)) throw make_error("bad bucket size");
    if (!decode_varuint64(begin, elem_end, curr_elem.bf.num_buckets)) throw make_error("bad num buckets");

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


static void restore_residency_state(vmprobe::cache::file &file, bitfield &bf) {
    size_t range_start = 0;
    size_t range_end = 0;
    int range_state = -1;

    size_t mem_len = file.get_size();

    file.advise(RANDOM);

    for (uint64_t i=0; i < bf.num_buckets; i++) {
        int bit_state = bf.get_bit(i);
        if (range_state == -1) range_state = bit_state;

        if (bit_state != range_state) {
            if (range_state == 1) file.touch(range_start, range_end - range_start);
            else file.evict(range_start, range_end - range_start);
            range_start = range_end;
            range_state = bit_state;
        }

        range_end += bf.bucket_size ? bf.bucket_size : 4096;

        if (range_end > mem_len) {
            range_end = mem_len;
            break;
        }
    }

    if (range_start != range_end) {
        if (range_state == 1) file.touch(range_start, range_end - range_start);
        else file.evict(range_start, range_end - range_start);
    }

    file.advise(NORMAL);
}

void restore(char *ptr, size_t len) {
    parser p(ptr, len);

    p.process([&](element &elem) {
        std::string filename(elem.filename, elem.filename_len);
        vmprobe::cache::file f(filename);
        restore_residency_state(f, elem.bf);
    });
}




summary::summary(std::string path_, uint64_t num_buckets_) {
    path = path_;
    num_buckets = num_buckets_;

    // FIXME: normalize path (remove ".." "." "//")

    path_plus_slash = path + "/";

    buckets.emplace_back();
}


bool summary::match(char *filename, size_t filename_len) {
    if (!path.size()) return true;

    if (!path.compare(0, path.size(), filename, filename_len)) return true;

    if (filename_len > path_plus_slash.size() && !path_plus_slash.compare(0, path_plus_slash.size(), filename, path_plus_slash.size())) return true;

    return false;
}


void summary::add_element(element &elem) {
    if (!buckets.back().start_filename) {
        buckets.back().start_filename = elem.filename;
        buckets.back().start_filename_len = elem.filename_len;
    }

    buckets.back().num_files++;

    for (uint64_t i=0; i < elem.bf.num_buckets; i++) {
        int bit_state = elem.bf.get_bit(i);

        if (buckets.back().num_pages >= pages_per_bucket) {
            if (buckets.size() == num_buckets) compress();

            if (buckets.back().num_pages >= pages_per_bucket) {
                buckets.emplace_back();
                buckets.back().start_filename = elem.filename;
                buckets.back().start_filename_len = elem.filename_len;
                buckets.back().start_page_offset = i;
            }
        }

        buckets.back().num_pages++;
        buckets.back().num_resident += bit_state;
    }

    last_filename = elem.filename;
    last_filename_len = elem.filename_len;
}


void summary::compress() {
    if (buckets.size() % 2) {
        buckets.emplace_back();
    }

    for (size_t i = 0; i < buckets.size(); i += 2) {
        buckets[i/2].num_pages = buckets[i].num_pages + buckets[i+1].num_pages;
        buckets[i/2].num_resident = buckets[i].num_resident + buckets[i+1].num_resident;
        buckets[i/2].num_files = buckets[i].num_files + buckets[i+1].num_files;
        buckets[i/2].start_filename = buckets[i].start_filename;
        buckets[i/2].start_filename_len = buckets[i].start_filename_len;
        buckets[i/2].start_page_offset = buckets[i].start_page_offset;
    }

    buckets.resize(buckets.size()/2);
    pages_per_bucket *= 2;
}


void summarize(char *snapshot_ptr, size_t snapshot_len, std::vector<summary> &summaries) {
    parser p(snapshot_ptr, snapshot_len);

    p.process([&](element &elem) {
        for (auto &summary : summaries) {
            if (summary.match(elem.filename, elem.filename_len)) summary.add_element(elem);
        }
    });
}




void diff_snapshots(char *ptr_a, size_t len_a, char *ptr_b, size_t len_b, std::vector<diff> &diffs) {
    std::map<std::string, bitfield> lookup;

    parser p_a(ptr_a, len_a);

    p_a.process([&](element &e) {
        std::string filename(e.filename, e.filename_len);
        lookup[filename] = e.bf;
    });

    parser p_b(ptr_b, len_b);

    // FIXME: need a way to report created/deleted files and files with differing sizes
    p_b.process([&](element &e) {
        std::string filename(e.filename, e.filename_len);

        std::map<std::string, bitfield>::iterator iter = lookup.find(filename);
        if (iter == lookup.end()) return;

        bitfield *bf_a = &iter->second;
        bitfield *bf_b = &e.bf;

        diff *curr_diff = nullptr;
        uint64_t num_buckets = std::max(bf_a->num_buckets, bf_b->num_buckets);

        for(size_t i = 0; i < num_buckets; i++) {
            int bit_a = bf_a->get_bit(i);
            int bit_b = bf_b->get_bit(i);

            if (bit_a != bit_b) {
                if (!curr_diff) {
                    diffs.emplace_back();
                    curr_diff = &diffs.back();
                    curr_diff->filename = filename;
                }

                if (bit_a) curr_diff->evicted++;
                else curr_diff->touched++;
            }
        }
    });
}



}}}
