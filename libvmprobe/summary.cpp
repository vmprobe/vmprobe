#include "summary.h"



namespace vmprobe { namespace cache { namespace snapshot { namespace summary {


builder::builder(std::string path_, uint64_t num_buckets_) {
    path = path_;
    num_buckets = num_buckets_;

    // FIXME: normalize path (remove ".." "." "//")

    path_plus_slash = path + "/";

    buckets.emplace_back();
}


bool builder::match(char *filename, size_t filename_len) {
    if (!path.size()) return true;

    if (!path.compare(0, path.size(), filename, filename_len)) return true;

    if (filename_len > path_plus_slash.size() && !path_plus_slash.compare(0, path_plus_slash.size(), filename, path_plus_slash.size())) return true;

    return false;
}


void builder::add_element(vmprobe::cache::snapshot::element &elem) {
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


void builder::compress() {
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


void summarize(char *snapshot_ptr, size_t snapshot_len, std::vector<builder> &summaries) {
    parser p(snapshot_ptr, snapshot_len);

    p.process([&](vmprobe::cache::snapshot::element &elem) {
        for (auto &summary : summaries) {
            if (summary.match(elem.filename, elem.filename_len)) summary.add_element(elem);
        }
    });
}

}}}}
