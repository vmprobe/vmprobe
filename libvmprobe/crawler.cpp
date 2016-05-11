#include <memory>
#include <iostream>
#include <string>
#include <exception>
#include <vector>
#include <algorithm>

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>

#include "crawler.h"
#include "path.h"


namespace vmprobe {

void crawler::warning(const char *format, ...) {
    va_list vl;

    va_start(vl, format);
    int needed = vsnprintf(nullptr, 0, format, vl) + 1;
    std::unique_ptr<char[]> buf(new char[needed]); 

    va_start(vl, format);
    vsnprintf(buf.get(), needed, format, vl);
    std::string str(buf.get(), buf.get() + needed - 1);

    warnings.push_back(str);
}

void crawler::fatal(const char *format, ...) {
    va_list vl;

    va_start(vl, format);
    int needed = vsnprintf(nullptr, 0, format, vl) + 1;
    std::unique_ptr<char[]> buf(new char[needed]);

    va_start(vl, format);
    vsnprintf(buf.get(), needed, format, vl);
    std::string str(buf.get(), buf.get() + needed - 1);

    throw std::runtime_error(buf.get());
}


void crawler::increment_nofile_rlimit() {
    struct rlimit r;

    if (getrlimit(RLIMIT_NOFILE, &r))
        fatal("increment_nofile_rlimit: getrlimit (%s)", strerror(errno));

    r.rlim_cur = r.rlim_max + 1;
    r.rlim_max = r.rlim_max + 1;

    if (setrlimit(RLIMIT_NOFILE, &r)) {
        if (errno == EPERM) {
            if (getuid() == 0 || geteuid() == 0) fatal("system open file limit reached");
            fatal("open file limit reached and unable to increase limit. retry as root");
        }
        fatal("increment_nofile_rlimit: setrlimit (%s)", strerror(errno));
    }
}



void crawler::_crawl(std::string &path_std_string, file_index &already_seen_files) {
    const char *path = path_std_string.c_str();
    struct ::stat sb;

    int res = follow_symlinks ? stat(path, &sb) : lstat(path, &sb);

    if (res) {
        warning("unable to stat %s (%s)", path, strerror(errno));
        return;
    }

    if (S_ISLNK(sb.st_mode)) {
        warning("not following symbolic link %s", path);
        return;
    }

    if (skip_duplicate_hardlinks && sb.st_nlink > 1) {
        file_index::iterator dev = already_seen_files.find(sb.st_dev);

        // Haven't seen this device before, initialize it
        if (dev == already_seen_files.end()) {
            already_seen_files.emplace(sb.st_dev, std::unordered_set<ino_t> {sb.st_ino});
        }
        // Already seen this inode before
        else if (!dev->second.insert(sb.st_ino).second) {
            warning("skipping duplicate hardlink %s", path);
            return;
        }
    }

    if (S_ISDIR(sb.st_mode)) {
        if (curr_crawl_depth == max_crawl_depth) {
            warning("maximum directory crawl depth reached: %s", path);
            return;
        }

        num_dirs++;

        retry_opendir:

        DIR *dirp = opendir(path);

        if (dirp == NULL) {
            if (errno == ENFILE || errno == EMFILE) {
                increment_nofile_rlimit();
                goto retry_opendir;
            }

            warning("unable to opendir %s (%s), skipping", path, strerror(errno));
            return;
        }

        struct dirent *de;
        std::vector<std::string> dir_entries;

        while((de = readdir(dirp)) != NULL) {
            if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;

            dir_entries.emplace_back(de->d_name);
        }

        if (closedir(dirp)) fatal("unable to closedir %s (%s)", path, strerror(errno));

        std::sort(dir_entries.begin(), dir_entries.end());

        for (auto &s : dir_entries) { 
            std::string npath = path_std_string + std::string("/") + s;

            curr_crawl_depth++;
            _crawl(npath, already_seen_files);
            curr_crawl_depth--;
        }
    } else if (S_ISREG(sb.st_mode)) {
        num_files++;
        // FIXME: catch exceptions thrown by the callback
        file_handler(path_std_string, sb);
    } else {
        warning("skipping non-regular file: %s", path);
    }
}

void crawler::crawl(std::string &path) {
    std::string normalized_path = vmprobe::path::normalize(path);

    file_index already_seen_files;

    _crawl(normalized_path, already_seen_files);
}

}
