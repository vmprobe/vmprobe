#include <string>
#include <iostream>
#include <fstream>
#include <streambuf>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    if (argc < 3) {
        std::cerr << "usage: delta-snapshots <before-snapshot> <after-snapshot>" << std::endl;
        return 1;
    }

    std::ifstream before_stream(argv[1]);
    std::string before((std::istreambuf_iterator<char>(before_stream)),
                       std::istreambuf_iterator<char>());

    std::ifstream after_stream(argv[2]);
    std::string after((std::istreambuf_iterator<char>(after_stream)),
                      std::istreambuf_iterator<char>());


    vmprobe::cache::snapshot::builder b;
    b.delta(before, after);

    std::string delta(b.buf.data(), b.buf.size());
    std::cout << delta;

    return 0;
}
