#include <string>
#include <iostream>
#include <fstream>
#include <streambuf>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    if (argc < 3) {
        std::cerr << "usage: union-snapshots <a-snapshot> <b-snapshot>" << std::endl;
        return 1;
    }

    std::ifstream a_stream(argv[1]);
    std::string a((std::istreambuf_iterator<char>(a_stream)),
                       std::istreambuf_iterator<char>());

    std::ifstream b_stream(argv[2]);
    std::string b((std::istreambuf_iterator<char>(b_stream)),
                      std::istreambuf_iterator<char>());


    vmprobe::cache::snapshot::builder bld;
    bld.build_union(a, b);

    std::string output(bld.buf.data(), bld.buf.size());
    std::cout << output;

    return 0;
}
