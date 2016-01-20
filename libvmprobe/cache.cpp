#include "cache.h"
#include "crawler.h"
#include "file.h"
#include "pageutils.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>



namespace vmprobe { namespace cache {

void touch(std::string path) {
    touch(path, 0, UINT64_MAX);
}

void touch(std::string path, uint64_t start_page, uint64_t end_page) {
    uint64_t curr_page = 0;

    vmprobe::crawler c([&](std::string &filename, struct ::stat &sb) {
        uint64_t pages = vmprobe::pageutils::bytes2pages(sb.st_size);

        if (curr_page + pages < start_page || curr_page > end_page) {
            curr_page += pages;
            return;
        }

        uint64_t this_start_page = start_page < curr_page ? 0 : start_page - curr_page;
        uint64_t this_end_page = std::min(pages, end_page - curr_page);

        curr_page += pages;

        vmprobe::cache::file f(filename);

        f.advise(SEQUENTIAL);
        f.touch(vmprobe::pageutils::pages2bytes(this_start_page), vmprobe::pageutils::pages2bytes(this_end_page) - vmprobe::pageutils::pages2bytes(this_start_page));
        f.advise(NORMAL);
    });

    c.crawl(path);
}


void evict(std::string path) {
    evict(path, 0, UINT64_MAX);
}

void evict(std::string path, uint64_t start_page, uint64_t end_page) {
    uint64_t curr_page = 0;

    vmprobe::crawler c([&](std::string &filename, struct ::stat &sb) {
        uint64_t pages = vmprobe::pageutils::bytes2pages(sb.st_size);

        if (curr_page + pages < start_page || curr_page > end_page) {
            curr_page += pages;
            return;
        }

        uint64_t this_start_page = start_page < curr_page ? 0 : start_page - curr_page;
        uint64_t this_end_page = std::min(pages, end_page - curr_page);

        curr_page += pages;

        vmprobe::cache::file f(filename);

        f.advise(RANDOM);
        f.evict(vmprobe::pageutils::pages2bytes(this_start_page), vmprobe::pageutils::pages2bytes(this_end_page) - vmprobe::pageutils::pages2bytes(this_start_page));
        f.advise(NORMAL);
    });

    c.crawl(path);
}

}}
