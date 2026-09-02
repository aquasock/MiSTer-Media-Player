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
    MEDIA_SOURCE_SEEK_CURRENT,
    MEDIA_SOURCE_SEEK_END
};

enum media_source_dvd_command {
    MEDIA_SOURCE_DVD_MENU_UP = 1,
    MEDIA_SOURCE_DVD_MENU_DOWN,
    MEDIA_SOURCE_DVD_MENU_LEFT,
    MEDIA_SOURCE_DVD_MENU_RIGHT,
    MEDIA_SOURCE_DVD_MENU_ACTIVATE,
    MEDIA_SOURCE_DVD_ROOT_MENU
};

enum media_source_dvd_command_result {
    MEDIA_SOURCE_DVD_COMMAND_ERROR = -1,
    MEDIA_SOURCE_DVD_NO_HOP = 0,
    MEDIA_SOURCE_DVD_STREAM_HOP = 1,
    MEDIA_SOURCE_DVD_MENU_CONTINUE = 2,
    MEDIA_SOURCE_DVD_MENU_PENDING = 3
};

struct media_source_dvd_state {
    int menu_active;
    int menu_changed;
    int clut_changed;
    uint32_t clut[16];
    int spu_stream_changed;
    int spu_stream;
    int highlight_changed;
    int highlight_display;
    uint32_t highlight_palette;
    uint16_t highlight_x1;
    uint16_t highlight_y1;
    uint16_t highlight_x2;
    uint16_t highlight_y2;
    int hop;
};

int media_source_open(struct media_source *source, const char *specification,
                      char *error, size_t error_size);
size_t media_source_read(struct media_source *source, void *data, size_t size);
int media_source_getc(struct media_source *source);
int media_source_rewind(struct media_source *source);
int media_source_prepare(struct media_source *source);
int media_source_seek(struct media_source *source, int64_t offset,
                      enum media_source_seek_origin origin);
int media_source_position(struct media_source *source, int64_t *position);
int media_source_error(struct media_source *source);
int media_source_change_chapter(struct media_source *source, int direction);
int media_source_dvd_command(struct media_source *source,
                             enum media_source_dvd_command command);
int media_source_dvd_state(struct media_source *source,
                           struct media_source_dvd_state *state);
int media_source_dvd_still(struct media_source *source,
                           unsigned *seconds);
int media_source_dvd_still_skip(struct media_source *source,
                                int classify_menu_transition);
void media_source_close(struct media_source *source);
const char *media_source_kind_name(enum media_source_kind kind);

#endif
