#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

#include <stdexcept>
#include <vector>

#include "cache.h"


MODULE = Vmprobe::Cache        PACKAGE = Vmprobe::Cache

PROTOTYPES: ENABLE


void
touch(path_sv)
        SV *path_sv
    CODE:
        char *path_p;
        size_t path_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::touch(path);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }


void
touch_page_range(path_sv, start_page, end_page)
        SV *path_sv
        unsigned long start_page
        unsigned long end_page
    CODE:
        char *path_p;
        size_t path_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::touch(path, start_page, end_page);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }



void
evict(path_sv)
        SV *path_sv
    CODE:
        char *path_p;
        size_t path_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::evict(path);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }


void
evict_page_range(path_sv, start_page, end_page)
        SV *path_sv
        unsigned long start_page
        unsigned long end_page
    CODE:
        char *path_p;
        size_t path_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::evict(path, start_page, end_page);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }



void
lock_page_range(path_sv, start_page, end_page)
        SV *path_sv
        unsigned long start_page
        unsigned long end_page
    CODE:
        char *path_p;
        size_t path_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        static std::vector<vmprobe::cache::lock_context *> locks;

        try {
            locks.push_back(vmprobe::cache::lock(path, start_page, end_page));
        } catch(std::runtime_error &e) {
            croak(e.what());
        }
