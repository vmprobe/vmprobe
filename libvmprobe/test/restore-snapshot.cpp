#include <string>
#include <iostream>
#include <sstream>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    if (argc < 2) {
        std::cerr << "usage: restore-snapshot <path> < mysnapshot" << std::endl;
        return 1;
    }

    std::ostringstream std_input;
    std_input << std::cin.rdbuf();
    std::string input = std_input.str();

    std::string path(argv[1]);

    try {
        vmprobe::cache::snapshot::restore(path, (char*)input.data(), input.size());
    } catch(std::runtime_error &e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return 1;
    } catch(...) {
        std::cerr << "unknown exception" << std::endl;
        return 1;
    }

    return 0;
}
