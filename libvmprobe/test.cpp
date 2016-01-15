// eg++ -std=c++11 -O2 -I. -L. test.cpp -lvmprobe

#include <string>
#include <iostream>

#include "snapshot.h"

int main(int argc, char **argv) {
try {
    std::string path(argv[1]);

    vmprobe::cache::snapshot::builder b(path);

    //std::string lol(b.buf.data(), b.buf.size());
    //std::cout << lol;
    //return 0;

    std::vector<vmprobe::cache::snapshot::summary> s;

    s.emplace_back(std::string(""), 200);

    vmprobe::cache::snapshot::summarize((char*)b.buf.data(), b.buf.size(), s);

    uint64_t i=0;
    for (auto &bucket : s.back().buckets) {
        std::cout << i << std::endl;
        std::cout << "  num_pages: " << bucket.num_pages << std::endl;
        std::cout << "  num_resid: " << bucket.num_resident << std::endl;
        std::cout << "  num_files: " << bucket.num_files << std::endl;

        std::string fn(bucket.start_filename, bucket.start_filename_len);
        std::cout << "  filename: " << fn << std::endl;
        std::cout << "  offset:   " << bucket.start_page_offset << std::endl;

        i++;
    }
} catch(std::string e) {
std::cerr << "exception: " << e << std::endl;
} catch(const char *e) {
std::cerr << "exception char: " << e << std::endl;
}
}
