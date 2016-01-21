#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>

#include <string>
#include <vector>
#include <utility>

#include "cache.h"
#include "crawler.h"
#include "pageutils.h"



namespace vmprobe { namespace cache {

void process(std::string &path, uint64_t start_page, uint64_t end_page, std::function<void(vmprobe::cache::file &, uint64_t, uint64_t)> cb) {
    uint64_t curr_page = 0;

    vmprobe::crawler c([&](std::string &filename, struct ::stat &sb) {
        uint64_t pages = vmprobe::pageutils::bytes2pages(sb.st_size);

        if (curr_page + pages < start_page || curr_page > end_page) {
            curr_page += pages;
            return;
        }

        uint64_t start_byte = vmprobe::pageutils::pages2bytes(start_page < curr_page ? 0 : start_page - curr_page);
        uint64_t end_byte = vmprobe::pageutils::pages2bytes(std::min(pages, end_page - curr_page));

        curr_page += pages;

        vmprobe::cache::file f(filename);

        cb(f, start_byte, end_byte);
    });

    c.crawl(path);
}




void touch(std::string path) {
    touch(path, 0, UINT64_MAX);
}

void touch(std::string path, uint64_t start_page, uint64_t end_page) {
    process(path, start_page, end_page, [&](vmprobe::cache::file &f, uint64_t start_byte, uint64_t end_byte) {
        f.advise(advice::SEQUENTIAL);
        f.touch(start_byte, end_byte - start_byte);
        f.advise(advice::DEFAULT_NORMAL);
    });
}


void evict(std::string path) {
    evict(path, 0, UINT64_MAX);
}

void evict(std::string path, uint64_t start_page, uint64_t end_page) {
    process(path, start_page, end_page, [&](vmprobe::cache::file &f, uint64_t start_byte, uint64_t end_byte) {
        f.advise(advice::RANDOM);
        f.evict(start_byte, end_byte - start_byte);
        f.advise(advice::DEFAULT_NORMAL);
    });
}


lock_context *lock(std::string path) {
    return lock(path, 0, UINT64_MAX);
}

lock_context *lock(std::string path, uint64_t start_page, uint64_t end_page) {
    lock_context l;

    process(path, start_page, end_page, [&](vmprobe::cache::file &f, uint64_t start_byte, uint64_t end_byte) {
        f.advise(advice::RANDOM);
        f.lock(start_byte, end_byte - start_byte);
        f.advise(advice::DEFAULT_NORMAL);

        f.close();

        l.files.push_back(std::move(f));
    });

    return new lock_context(std::move(l));
}


}}
