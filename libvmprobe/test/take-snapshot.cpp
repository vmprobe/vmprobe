#include <string>
#include <iostream>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    if (argc < 2) {
        std::cerr << "usage: take-snapshot <path>" << std::endl;
        return 1;
    }

    int bit = -1;

    if (argc == 3) {
        bit = std::stoi(argv[2]);
    }

    std::string path(argv[1]);

    try {
        std::string snap;

        if (bit == -1) {
            vmprobe::cache::snapshot::builder b;

            b.crawl(path);

            snap = b.get_snapshot();
        } else {
            vmprobe::cache::snapshot::pagemap_builder b;

            // note this "54" overloading hack prevents us from accessing some of the internal kernel bits
            if (bit > 54) b.register_pagemap_bit(bit);
            else b.register_kpageflags_bit(bit);

            b.crawl(path);

            if (bit > 54) snap = b.get_pagemap_snapshot(bit);
            else snap = b.get_kpageflags_snapshot(bit);
        }

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
