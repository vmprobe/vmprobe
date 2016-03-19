#include <string>

#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdexcept>

#include "pageutils.h"
#include "file.h"


namespace vmprobe { namespace cache {

file::file(std::string &filename) {
    fd = open(filename.c_str(), O_RDONLY|O_NOATIME, 0);

    if (fd == -1) {
        // FIXME: increment_nofile_rlimit
        throw(std::runtime_error(std::string("Failed to open '") + filename + std::string("': ") + std::string(strerror(errno))));
    }

    struct stat sb;

    if (fstat(fd, &sb)) {
        throw(std::runtime_error(std::string("Failed to fstat: ") + std::string(strerror(errno))));
    }

    if ((uint64_t)sb.st_size > (uint64_t)SIZE_MAX) {
        throw(std::runtime_error(std::string("File too large to map on 32-bit system")));
    }

    file_size = (size_t)sb.st_size;
}

file::file(file &&other) {
    fd = other.fd;
    other.fd = -1;

    file_size = other.file_size;

    mmap_ptr = other.mmap_ptr;
    other.mmap_ptr = nullptr;
}

file::~file() {
    munmap();
    close();
}


void file::close() {
    if (fd != -1) ::close(fd);
    fd = -1;
}


void file::munmap() {
    if (mmap_ptr) ::munmap(mmap_ptr, file_size);
    mmap_ptr = nullptr;
}


void file::mmap() {
    if (mmap_ptr) return; // already mapped

    if (file_size == 0) return; // don't mmap empty files

    mmap_ptr = (char*) ::mmap(NULL, file_size, PROT_READ, MAP_SHARED, fd, 0);

    if (mmap_ptr == MAP_FAILED) {
        throw(std::runtime_error(std::string("Failed to mmap: ") + std::string(strerror(errno))));
    }
}



void file::touch(size_t start, size_t len) {
    // Ignores errors for now...

#if defined(__linux__) || defined(__hpux)
    posix_fadvise(fd, start, len, POSIX_FADV_WILLNEED);
#endif

    char junk;

    // FIXME: benchmark which is faster: pread or mmap+faulting in pages (i bet it's pread)
    for (size_t i = start; i < start + len; i += vmprobe::pageutils::pagesize()) {
        ssize_t ret = pread(fd, &junk, 1, i);

        if (ret != 1) throw(std::runtime_error("pread failed"));
    }
}

void file::evict(size_t start, size_t len) {
    // Ignores errors for now...
    // FIXME: non-linux platforms need access to the mmap in order to call msync

#if defined(__linux__) || defined(__hpux)
    posix_fadvise(fd, start, len, POSIX_FADV_DONTNEED);
#else
    throw(std::runtime_error(std::string("Eviction not yet supported on this platform")));
#endif
}

void file::lock(size_t start, size_t len) {
    mmap();

    if (mlock(mmap_ptr + start, len)) {
        if (errno == ENOMEM) {
            throw(std::runtime_error(std::string("Failed to mlock: exceeded allowed amount of locked memory")));
        } else {
            throw(std::runtime_error(std::string("Failed to mlock: ") + std::string(strerror(errno))));
        }
    }
}

void file::advise(advice a) {
#if defined(__linux__) || defined(__hpux)
    switch(a) {
        case advice::DEFAULT_NORMAL:
            posix_fadvise(fd, 0, file_size, POSIX_FADV_NORMAL);
            break;
        case advice::SEQUENTIAL:
            posix_fadvise(fd, 0, file_size, POSIX_FADV_SEQUENTIAL);
            break;
        case advice::RANDOM:
            posix_fadvise(fd, 0, file_size, POSIX_FADV_RANDOM);
            break;
    }
#endif
}



}}
