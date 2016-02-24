#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

#include "snapshot.h"
#include "summary.h"

#include <stdexcept>


MODULE = Vmprobe::Cache::Snapshot        PACKAGE = Vmprobe::Cache::Snapshot
 
PROTOTYPES: ENABLE


SV *
take(path_sv)
        SV *path_sv
    CODE:
        char *path_p;
        size_t path_len;
        SV *output;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::snapshot::builder b;

            b.crawl(path);

            output = newSVpvn(b.buf.data(), b.buf.size());
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        RETVAL = output;
    OUTPUT:
        RETVAL



void
restore(path_sv, snapshot_sv)
        SV *path_sv
        SV *snapshot_sv
    CODE:
        char *path_p;
        size_t path_len;
        char *snapshot_p;
        size_t snapshot_len;

        path_len = SvCUR(path_sv);
        path_p = SvPV(path_sv, path_len);
        snapshot_len = SvCUR(snapshot_sv);
        snapshot_p = SvPV(snapshot_sv, snapshot_len);

        std::string path(path_p, path_len);

        try {
            vmprobe::cache::snapshot::restore(path, snapshot_p, snapshot_len);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }


SV *
summarize(snapshot_sv, buckets)
        SV *snapshot_sv
        int buckets
    INIT:
        char *snapshot_p;
        size_t snapshot_len;

        snapshot_len = SvCUR(snapshot_sv);
        snapshot_p = SvPV(snapshot_sv, snapshot_len);

        AV *results;
        results = (AV *) sv_2mortal ((SV *) newAV ());

    CODE:
        std::vector<vmprobe::cache::snapshot::summary::builder> s;

        s.emplace_back(std::string(""), buckets);

        try {
            vmprobe::cache::snapshot::summary::summarize(snapshot_p, snapshot_len, s);
        } catch(std::runtime_error &e) {
            croak(e.what());
        }

        for (auto &bucket : s.back().buckets) {
            HV *rh = (HV *) sv_2mortal ((SV *) newHV());

            hv_store(rh, "num_pages", 9, newSVnv(bucket.num_pages), 0);
            hv_store(rh, "num_resident", 12, newSVnv(bucket.num_resident), 0);
            hv_store(rh, "num_files", 9, newSVnv(bucket.num_files), 0);

            hv_store(rh, "start_filename", 14, newSVpvn(bucket.start_filename, bucket.start_filename_len), 0);
            hv_store(rh, "start_page_offset", 17, newSVnv(bucket.start_page_offset), 0);

            av_push(results, newRV((SV *)rh)); 
        }

        RETVAL = newRV((SV *)results);
    OUTPUT:
        RETVAL
