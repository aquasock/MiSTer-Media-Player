#define _POSIX_C_SOURCE 200809L

#include "media_source.h"
#include "media_player_protocol.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct media_source_ops {
    size_t (*read)(void *state, void *data, size_t size);
    int (*get_character)(void *state);
    int (*rewind_source)(void *state);
    int (*has_error)(void *state);
    void (*close_source)(void *state);
};

struct file_source_state {
    FILE *stream;
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
    file_has_error,
    file_close
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
    case MEDIA_SOURCE_DVD:
        return "dvd";
    default:
        return "none";
    }
}
