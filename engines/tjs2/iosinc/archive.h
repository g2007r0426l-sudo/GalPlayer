// =============================================================================
// archive.h —— libarchive 桩（iOS 不提供）
//
// UtilStreams.cpp 会包含 <archive.h>/<archive_entry.h>（用于 tar 等额外格式）。
// 我们只用 XP3，这里给最小桩让编译通过；相关调用在 iOS 上不会被触发。
// =============================================================================
#ifndef GP_LIBARCHIVE_STUB_H
#define GP_LIBARCHIVE_STUB_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct archive;
struct archive_entry;

#define ARCHIVE_OK 0
#define ARCHIVE_EOF 1

static inline struct archive *archive_read_new(void) { return 0; }
static inline int archive_read_support_filter_all(struct archive *a) { (void)a; return ARCHIVE_OK; }
static inline int archive_read_support_format_all(struct archive *a) { (void)a; return ARCHIVE_OK; }
static inline int archive_read_open_filename(struct archive *a, const char *p, size_t b) {
    (void)a; (void)p; (void)b; return ARCHIVE_OK;
}
static inline int archive_read_next_header(struct archive *a, struct archive_entry **e) {
    (void)a; (void)e; return ARCHIVE_EOF;
}
static inline long long archive_read_data(struct archive *a, void *b, size_t n) {
    (void)a; (void)b; (void)n; return 0;
}
static inline int archive_read_free(struct archive *a) { (void)a; return ARCHIVE_OK; }

#ifdef __cplusplus
}
#endif

#endif
