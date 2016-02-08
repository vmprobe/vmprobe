#include <string>
#include <iostream>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    if (argc < 3) {
        std::cerr << "usage: take-snapshot <path> <is sparse>" << std::endl;
        return 1;
    }

    std::string path(argv[1]);

    std::string sparse_str(argv[2]);
    int sparse;
    if (sparse_str == "1") {
        sparse = 1;
    } else if (sparse_str == "0") {
        sparse = 0;
    } else {
        std::cerr << "is sparse should be either 0 or 1" << std::endl;
        return 1;
    }

    try {
        vmprobe::cache::snapshot::builder b;
        b.crawl(path, sparse);

        std::string snap(b.buf.data(), b.buf.size());
        std::cout << snap;
    } catch(std::runtime_error &e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return 1;
    } catch(...) {
        std::cerr << "unknown exception" << std::endl;
        return 1;
    }

    return 0;
}
