#define _POSIX_C_SOURCE 200809L
#define _FILE_OFFSET_BITS 64

#include "media_source.h"
#include "media_player_protocol.h"

#include <dvdnav/dvdnav.h>
#include <dvdnav/dvdnav_events.h>

#include <errno.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct media_source_ops {
    size_t (*read)(void *state, void *data, size_t size);
    int (*get_character)(void *state);
    int (*rewind_source)(void *state);
    int (*seek_source)(void *state, int64_t offset,
                       enum media_source_seek_origin origin);
    int (*has_error)(void *state);
    void (*close_source)(void *state);
};

struct file_source_state {
    FILE *stream;
};

struct iso_source_state {
    FILE *stream;
    dvdnav_t *navigation;
    uint8_t block[DVD_VIDEO_LB_LEN];
    size_t block_offset;
    size_t block_size;
    int32_t title;
    uint64_t duration;
    int end_of_stream;
    int error;
};

static size_t file_read(void *opaque, void *data, size_t size)
{
    struct file_source_state *state = opaque;
    return fread(data, 1, size, state->stream);
}

static int file_get_character(void *opaque)
{
    struct file_source_state *state = opaque;
    return fgetc(state->stream);
}

static int file_rewind(void *opaque)
{
    struct file_source_state *state = opaque;
    return fseek(state->stream, 0, SEEK_SET);
}

static int file_seek(void *opaque, int64_t offset,
                     enum media_source_seek_origin origin)
{
    struct file_source_state *state = opaque;
    int whence = origin == MEDIA_SOURCE_SEEK_START ? SEEK_SET : SEEK_CUR;

    return fseeko(state->stream, (off_t)offset, whence);
}

static int file_has_error(void *opaque)
{
    struct file_source_state *state = opaque;
    return ferror(state->stream);
}

static void file_close(void *opaque)
{
    struct file_source_state *state = opaque;
    if (state) {
        if (state->stream)
            fclose(state->stream);
        free(state);
    }
}

static const struct media_source_ops file_ops = {
    file_read,
    file_get_character,
    file_rewind,
    file_seek,
    file_has_error,
    file_close
};

static int iso_stream_seek(void *opaque, uint64_t position)
{
    struct iso_source_state *state = opaque;

    if (position > (uint64_t)INT64_MAX) {
        errno = EOVERFLOW;
        return -1;
    }
    clearerr(state->stream);
    return fseeko(state->stream, (off_t)position, SEEK_SET);
}

static int iso_stream_read(void *opaque, void *data, int size)
{
    struct iso_source_state *state = opaque;
    size_t count;

    if (size < 0) {
        errno = EINVAL;
        return -1;
    }
    count = fread(data, 1, (size_t)size, state->stream);
    if (count < (size_t)size && ferror(state->stream))
        return -1;
    return (int)count;
}

static int iso_select_title(struct iso_source_state *state)
{
    int32_t title_count = 0;
    int32_t title;
    int32_t longest_title = 0;
    uint64_t longest_duration = 0;

    if (dvdnav_get_number_of_titles(state->navigation, &title_count) !=
            DVDNAV_STATUS_OK ||
        title_count < 1)
        return -1;
    for (title = 1; title <= title_count; ++title) {
        uint64_t *chapter_times = NULL;
        uint64_t duration = 0;

        if (dvdnav_describe_title_chapters(state->navigation, title,
                                           &chapter_times, &duration) != 0 &&
            duration > longest_duration) {
            longest_title = title;
            longest_duration = duration;
        }
        free(chapter_times);
    }
    if (!longest_title ||
        dvdnav_title_play(state->navigation, longest_title) != DVDNAV_STATUS_OK)
        return -1;
    state->title = longest_title;
    state->duration = longest_duration;
    state->block_offset = 0;
    state->block_size = 0;
    state->end_of_stream = 0;
    state->error = 0;
    return 0;
}

static int iso_next_payload_block(struct iso_source_state *state)
{
    unsigned events_without_payload = 0;

    while (events_without_payload++ < 1024) {
        int32_t event = 0;
        int32_t length = 0;

        if (dvdnav_get_next_block(state->navigation, state->block,
                                  &event, &length) != DVDNAV_STATUS_OK) {
            state->error = 1;
            return -1;
        }
        if ((event == DVDNAV_BLOCK_OK || event == DVDNAV_NAV_PACKET) &&
            length == DVD_VIDEO_LB_LEN) {
            state->block_offset = 0;
            state->block_size = (size_t)length;
            return 1;
        }
        if (event == DVDNAV_STOP) {
            state->end_of_stream = 1;
            return 0;
        }
        if (event == DVDNAV_STILL_FRAME) {
            if (dvdnav_still_skip(state->navigation) != DVDNAV_STATUS_OK)
                break;
        } else if (event == DVDNAV_WAIT) {
            if (dvdnav_wait_skip(state->navigation) != DVDNAV_STATUS_OK)
                break;
        }
    }
    state->error = 1;
    return -1;
}

static size_t iso_read(void *opaque, void *data, size_t size)
{
    struct iso_source_state *state = opaque;
    uint8_t *output = data;
    size_t total = 0;

    while (total < size && !state->end_of_stream && !state->error) {
        size_t available;
        size_t count;

        if (state->block_offset == state->block_size) {
            if (iso_next_payload_block(state) <= 0)
                break;
        }
        available = state->block_size - state->block_offset;
        count = size - total < available ? size - total : available;
        memcpy(output + total, state->block + state->block_offset, count);
        state->block_offset += count;
        total += count;
    }
    return total;
}

static int iso_get_character(void *opaque)
{
    uint8_t value;

    return iso_read(opaque, &value, 1) == 1 ? value : EOF;
}

static int iso_rewind(void *opaque)
{
    struct iso_source_state *state = opaque;

    if (dvdnav_reset(state->navigation) != DVDNAV_STATUS_OK ||
        dvdnav_title_play(state->navigation, state->title) != DVDNAV_STATUS_OK) {
        state->error = 1;
        return -1;
    }
    state->block_offset = 0;
    state->block_size = 0;
    state->end_of_stream = 0;
    state->error = 0;
    return 0;
}

static int iso_seek(void *opaque, int64_t offset,
                    enum media_source_seek_origin origin)
{
    if (offset == 0 && origin == MEDIA_SOURCE_SEEK_START)
        return iso_rewind(opaque);
    if (offset == 0 && origin == MEDIA_SOURCE_SEEK_CURRENT)
        return 0;
    return -1;
}

static int iso_has_error(void *opaque)
{
    struct iso_source_state *state = opaque;
    return state->error || ferror(state->stream);
}

static void iso_close(void *opaque)
{
    struct iso_source_state *state = opaque;

    if (!state)
        return;
    if (state->navigation)
        dvdnav_close(state->navigation);
    if (state->stream)
        fclose(state->stream);
    free(state);
}

static const struct media_source_ops iso_ops = {
    iso_read,
    iso_get_character,
    iso_rewind,
    iso_seek,
    iso_has_error,
    iso_close
};

static int starts_with(const char *value, const char *prefix)
{
    return !strncmp(value, prefix, strlen(prefix));
}

static void set_error(char *error, size_t error_size, const char *message,
                      const char *detail)
{
    if (!error || !error_size)
        return;
    if (detail)
        snprintf(error, error_size, "%s: %s", message, detail);
    else
        snprintf(error, error_size, "%s", message);
}

int media_source_open(struct media_source *source, const char *specification,
                      char *error, size_t error_size)
{
    struct file_source_state *state;
    const char *location;

    if (!source || !specification || !*specification) {
        set_error(error, error_size, "empty media source", NULL);
        return MEDIA_SOURCE_INVALID;
    }
    memset(source, 0, sizeof(*source));
    if (starts_with(specification, MEDIA_PLAYER_DVD_PREFIX)) {
        source->kind = MEDIA_SOURCE_DVD;
        set_error(error, error_size,
                  "dvd source is reserved for a later development phase",
                  specification + strlen(MEDIA_PLAYER_DVD_PREFIX));
        return MEDIA_SOURCE_UNSUPPORTED;
    }
    if (starts_with(specification, MEDIA_PLAYER_ISO_PREFIX)) {
        struct iso_source_state *iso_state;
        dvdnav_stream_cb callbacks = {
            iso_stream_seek,
            iso_stream_read,
            NULL
        };

        source->kind = MEDIA_SOURCE_ISO;
        location = specification + strlen(MEDIA_PLAYER_ISO_PREFIX);
        if (!*location) {
            set_error(error, error_size, "empty ISO source", NULL);
            return MEDIA_SOURCE_INVALID;
        }
        iso_state = calloc(1, sizeof(*iso_state));
        if (!iso_state) {
            set_error(error, error_size, "out of memory", NULL);
            return MEDIA_SOURCE_IO_ERROR;
        }
        iso_state->stream = fopen(location, "rb");
        if (!iso_state->stream) {
            set_error(error, error_size, strerror(errno), location);
            iso_close(iso_state);
            return MEDIA_SOURCE_IO_ERROR;
        }
        if (dvdnav_open_stream(&iso_state->navigation, iso_state, &callbacks) !=
                DVDNAV_STATUS_OK ||
            dvdnav_set_readahead_flag(iso_state->navigation, 0) !=
                DVDNAV_STATUS_OK ||
            iso_select_title(iso_state) < 0) {
            const char *detail = iso_state->navigation ?
                dvdnav_err_to_string(iso_state->navigation) : location;
            set_error(error, error_size, "cannot open unencrypted DVD ISO",
                      detail);
            iso_close(iso_state);
            return MEDIA_SOURCE_IO_ERROR;
        }
        fprintf(stderr,
                "media_source: ISO selected longest title %d "
                "duration90k=%llu\n",
                (int)iso_state->title,
                (unsigned long long)iso_state->duration);
        source->ops = &iso_ops;
        source->state = iso_state;
        return MEDIA_SOURCE_OK;
    }
    if (starts_with(specification, MEDIA_PLAYER_FILE_PREFIX)) {
        source->kind = MEDIA_SOURCE_FILE;
        location = specification + strlen(MEDIA_PLAYER_FILE_PREFIX);
    } else if (strchr(specification, ':')) {
        set_error(error, error_size, "unsupported media source scheme",
                  specification);
        return MEDIA_SOURCE_UNSUPPORTED;
    } else {
        source->kind = MEDIA_SOURCE_FILE;
        location = specification;
    }
    if (!*location) {
        set_error(error, error_size, "empty file source", NULL);
        return MEDIA_SOURCE_INVALID;
    }
    state = calloc(1, sizeof(*state));
    if (!state) {
        set_error(error, error_size, "out of memory", NULL);
        return MEDIA_SOURCE_IO_ERROR;
    }
    state->stream = fopen(location, "rb");
    if (!state->stream) {
        set_error(error, error_size, strerror(errno), location);
        free(state);
        return MEDIA_SOURCE_IO_ERROR;
    }
    source->ops = &file_ops;
    source->state = state;
    return MEDIA_SOURCE_OK;
}

size_t media_source_read(struct media_source *source, void *data, size_t size)
{
    return source && source->ops ? source->ops->read(source->state, data, size) : 0;
}

int media_source_getc(struct media_source *source)
{
    return source && source->ops ? source->ops->get_character(source->state) : EOF;
}

int media_source_rewind(struct media_source *source)
{
    return source && source->ops ? source->ops->rewind_source(source->state) : -1;
}

int media_source_seek(struct media_source *source, int64_t offset,
                      enum media_source_seek_origin origin)
{
    if (!source || !source->ops ||
        (origin != MEDIA_SOURCE_SEEK_START &&
         origin != MEDIA_SOURCE_SEEK_CURRENT))
        return -1;
    return source->ops->seek_source(source->state, offset, origin);
}

int media_source_error(struct media_source *source)
{
    return source && source->ops ? source->ops->has_error(source->state) : 1;
}

void media_source_close(struct media_source *source)
{
    if (source && source->ops)
        source->ops->close_source(source->state);
    if (source)
        memset(source, 0, sizeof(*source));
}

const char *media_source_kind_name(enum media_source_kind kind)
{
    switch (kind) {
    case MEDIA_SOURCE_FILE:
        return "file";
    case MEDIA_SOURCE_ISO:
        return "iso";
    case MEDIA_SOURCE_DVD:
        return "dvd";
    default:
        return "none";
    }
}
