#include <string>
#include <iostream>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    try {
        std::string path(argv[1]);

        vmprobe::cache::snapshot::builder b;
        b.crawl(path);

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
