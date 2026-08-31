#ifndef MEDIA_SOURCE_H
#define MEDIA_SOURCE_H

#include <stddef.h>
#include <stdint.h>

enum media_source_kind {
    MEDIA_SOURCE_NONE = 0,
    MEDIA_SOURCE_FILE,
    MEDIA_SOURCE_ISO,
    MEDIA_SOURCE_DVD
};

struct media_source_ops;

struct media_source {
    enum media_source_kind kind;
    const struct media_source_ops *ops;
    void *state;
};

enum media_source_result {
    MEDIA_SOURCE_OK = 0,
    MEDIA_SOURCE_INVALID = -1,
    MEDIA_SOURCE_UNSUPPORTED = -2,
    MEDIA_SOURCE_IO_ERROR = -3
};

enum media_source_seek_origin {
    MEDIA_SOURCE_SEEK_START = 0,
    MEDIA_SOURCE_SEEK_CURRENT
};

int media_source_open(struct media_source *source, const char *specification,
                      char *error, size_t error_size);
size_t media_source_read(struct media_source *source, void *data, size_t size);
int media_source_getc(struct media_source *source);
int media_source_rewind(struct media_source *source);
int media_source_prepare(struct media_source *source);
int media_source_seek(struct media_source *source, int64_t offset,
                      enum media_source_seek_origin origin);
int media_source_error(struct media_source *source);
int media_source_change_chapter(struct media_source *source, int direction);
void media_source_close(struct media_source *source);
const char *media_source_kind_name(enum media_source_kind kind);

#endif
