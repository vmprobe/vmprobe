#include <string>
#include <iostream>
#include <sstream>
#include <stdexcept>

#include "snapshot.h"

int main(int argc, char **argv) {
    // Slurp snapshot from input:

    std::ostringstream std_input;
    std_input << std::cin.rdbuf();
    std::string input = std_input.str();

    // Parse snapshot:

    try {
        vmprobe::cache::snapshot::parser p((char*)input.data(), input.size());

        std::cout << "PAGESIZE: " << p.pagesize << std::endl;
        std::cout << "SNAPSHOT FLAGS: " << p.flags << std::endl;
        std::cout << std::endl;

        p.process([&](vmprobe::cache::snapshot::element &elem) {
            std::string filename(elem.filename, elem.filename_len);

            std::cout << "FILE: '" << filename << "'" << std::endl;
            std::cout << "  RECORD FLAGS: " << elem.flags << std::endl;
            std::cout << "  SIZE: " << elem.file_size << std::endl;

            std::cout << "  BF: ";
            for (uint64_t i=0; i < elem.bf.num_buckets; i++) {
                int bit_state = elem.bf.get_bit(i);
                std::cout << bit_state;
            }
            std::cout << std::endl;
        });

        std::cout << std::endl;
    } catch(std::runtime_error &e) {
        std::cerr << "exception: " << e.what() << std::endl;
        return 1;
    } catch(...) {
        std::cerr << "unknown exception" << std::endl;
        return 1;
    }

    return 0;
}
