#define _POSIX_C_SOURCE 200809L
#define _FILE_OFFSET_BITS 64

#include "media_source.h"
#include "media_player_protocol.h"

#include <dvdnav/dvdnav.h>
#include <dvdnav/dvdnav_events.h>

#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define DVD_BUFFER_CAPACITY (8u * 1024u * 1024u)
#define DVD_BUFFER_PREFILL (4u * 1024u * 1024u)
#define DVD_BUFFER_READ_SIZE (64u * 1024u)
#define DVD_BUFFER_LOG_WAIT_US 100000u

struct media_source_ops {
    size_t (*read)(void *state, void *data, size_t size);
    int (*get_character)(void *state);
    int (*rewind_source)(void *state);
    int (*prepare_source)(void *state);
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
    char *device_path;
    int direct_device;
    dvdnav_t *navigation;
    uint8_t block[DVD_VIDEO_LB_LEN];
    size_t block_offset;
    size_t block_size;
    int32_t title;
    uint32_t chapters;
    uint64_t duration;
    int title_active;
    int32_t title_part;
    int32_t cell_part;
    int32_t cell_number;
    int end_of_stream;
    int error;
    pthread_t buffer_thread;
    pthread_mutex_t buffer_lock;
    pthread_cond_t buffer_can_read;
    pthread_cond_t buffer_can_write;
    uint8_t *buffer;
    size_t buffer_read;
    size_t buffer_write;
    size_t buffer_fill;
    int buffer_sync_initialized;
    int buffer_thread_started;
    int buffer_stop;
    int buffer_end_of_stream;
    int buffer_error;
    uint64_t buffer_produced;
    uint64_t buffer_consumed;
    uint64_t buffer_stall_events;
    uint64_t buffer_stall_us;
    uint64_t buffer_stall_max_us;
    uint64_t test_stall_after_bytes;
    unsigned test_stall_ms;
    int test_stall_injected;
};

static uint64_t monotonic_microseconds(void)
{
    struct timespec now;

    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
        return 0;
    return (uint64_t)now.tv_sec * 1000000u +
           (uint64_t)now.tv_nsec / 1000u;
}

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

static int file_prepare(void *opaque)
{
    (void)opaque;
    return 0;
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
    file_prepare,
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

static int dvd_navigation_open(struct iso_source_state *state)
{
    dvdnav_stream_cb callbacks = {
        iso_stream_seek,
        iso_stream_read,
        NULL
    };
    dvdnav_status_t status;

    if (state->direct_device)
        status = dvdnav_open(&state->navigation, state->device_path);
    else
        status = dvdnav_open_stream(&state->navigation, state, &callbacks);
    if (status != DVDNAV_STATUS_OK)
        return -1;
    if (dvdnav_set_readahead_flag(state->navigation,
                                  state->direct_device ? 1 : 0) !=
            DVDNAV_STATUS_OK)
        return -1;
    return 0;
}

static int iso_select_title(struct iso_source_state *state)
{
    int32_t title_count = 0;
    int32_t title;
    int32_t longest_title = 0;
    uint32_t longest_chapters = 0;
    uint64_t longest_duration = 0;

    if (dvdnav_get_number_of_titles(state->navigation, &title_count) !=
            DVDNAV_STATUS_OK ||
        title_count < 1)
        return -1;
    for (title = 1; title <= title_count; ++title) {
        uint64_t *chapter_times = NULL;
        uint64_t duration = 0;
        uint32_t chapters;

        chapters = dvdnav_describe_title_chapters(state->navigation, title,
                                                   &chapter_times, &duration);
        if (chapters != 0 &&
            duration > longest_duration) {
            longest_title = title;
            longest_chapters = chapters;
            longest_duration = duration;
        }
        free(chapter_times);
    }
    if (!longest_title ||
        dvdnav_title_play(state->navigation, longest_title) != DVDNAV_STATUS_OK)
        return -1;
    state->title = longest_title;
    state->chapters = longest_chapters;
    state->duration = longest_duration;
    state->title_active = 0;
    state->title_part = 0;
    state->cell_part = 0;
    state->cell_number = 0;
    state->block_offset = 0;
    state->block_size = 0;
    state->end_of_stream = 0;
    state->error = 0;
    return 0;
}

static int iso_guard_selected_title(struct iso_source_state *state,
                                    int32_t event, int32_t length)
{
    int32_t title = 0;
    int32_t part = 0;
    int64_t current_time;
    const char *reason = NULL;

    if (dvdnav_current_title_info(state->navigation, &title, &part) !=
            DVDNAV_STATUS_OK) {
        state->error = 1;
        return -1;
    }
    current_time = dvdnav_get_current_time(state->navigation);
    if (event == DVDNAV_CELL_CHANGE &&
        length != (int32_t)sizeof(dvdnav_cell_change_event_t)) {
        state->error = 1;
        return -1;
    }
    if (!state->title_active) {
        if (title != state->title)
            return 1;
        state->title_active = 1;
        state->title_part = part;
    } else if (title != state->title) {
        reason = "title exit";
    } else if (part < state->title_part) {
        reason = "title replay";
    } else if (event == DVDNAV_CELL_CHANGE) {
        const dvdnav_cell_change_event_t *cell =
            (const dvdnav_cell_change_event_t *)state->block;

        if (state->cell_part == part && state->cell_number != 0 &&
            cell->cellN <= state->cell_number)
            reason = "title cell replay";
    }
    if (reason) {
        fprintf(stderr,
                "media_source: %s selected title %d complete (%s, "
                "part=%d time90k=%lld duration90k=%llu)\n",
                state->direct_device ? "DVD" : "ISO",
                (int)state->title, reason, (int)part,
                (long long)current_time,
                (unsigned long long)state->duration);
        state->block_offset = 0;
        state->block_size = 0;
        state->end_of_stream = 1;
        return 0;
    }
    if (part > state->title_part)
        state->title_part = part;
    if (event == DVDNAV_CELL_CHANGE) {
        const dvdnav_cell_change_event_t *cell =
            (const dvdnav_cell_change_event_t *)state->block;

        if (part != state->cell_part) {
            state->cell_part = part;
            state->cell_number = cell->cellN;
        } else if (cell->cellN > state->cell_number) {
            state->cell_number = cell->cellN;
        }
    }
    return 1;
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
        if (event == DVDNAV_STOP) {
            state->end_of_stream = 1;
            return 0;
        }
        if (iso_guard_selected_title(state, event, length) <= 0)
            return state->error ? -1 : 0;
        if ((event == DVDNAV_BLOCK_OK || event == DVDNAV_NAV_PACKET) &&
            length == DVD_VIDEO_LB_LEN) {
            state->block_offset = 0;
            state->block_size = (size_t)length;
            return 1;
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

static size_t iso_read_navigation(struct iso_source_state *state, void *data,
                                  size_t size)
{
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

static void sleep_milliseconds(unsigned milliseconds)
{
    struct timespec delay = {
        (time_t)(milliseconds / 1000u),
        (long)(milliseconds % 1000u) * 1000000L
    };

    while (nanosleep(&delay, &delay) != 0 && errno == EINTR)
        ;
}

static void *iso_buffer_producer(void *opaque)
{
    struct iso_source_state *state = opaque;
    uint8_t scratch[DVD_BUFFER_READ_SIZE];

    for (;;) {
        size_t count;
        size_t first;

        pthread_mutex_lock(&state->buffer_lock);
        while (!state->buffer_stop &&
               DVD_BUFFER_CAPACITY - state->buffer_fill < sizeof(scratch))
            pthread_cond_wait(&state->buffer_can_write, &state->buffer_lock);
        if (state->buffer_stop) {
            pthread_mutex_unlock(&state->buffer_lock);
            break;
        }
        pthread_mutex_unlock(&state->buffer_lock);

        if (!state->test_stall_injected && state->test_stall_ms &&
            state->buffer_produced >= state->test_stall_after_bytes) {
            fprintf(stderr,
                    "media_source: injecting DVD producer stall after %llu "
                    "bytes for %u ms\n",
                    (unsigned long long)state->buffer_produced,
                    state->test_stall_ms);
            state->test_stall_injected = 1;
            sleep_milliseconds(state->test_stall_ms);
        }
        count = iso_read_navigation(state, scratch, sizeof(scratch));

        pthread_mutex_lock(&state->buffer_lock);
        if (state->buffer_stop) {
            pthread_mutex_unlock(&state->buffer_lock);
            break;
        }
        if (!count) {
            state->buffer_error = state->error;
            state->buffer_end_of_stream = !state->error;
            pthread_cond_broadcast(&state->buffer_can_read);
            pthread_mutex_unlock(&state->buffer_lock);
            break;
        }
        first = DVD_BUFFER_CAPACITY - state->buffer_write;
        if (first > count)
            first = count;
        memcpy(state->buffer + state->buffer_write, scratch, first);
        memcpy(state->buffer, scratch + first, count - first);
        state->buffer_write = (state->buffer_write + count) %
                              DVD_BUFFER_CAPACITY;
        state->buffer_fill += count;
        state->buffer_produced += count;
        pthread_cond_broadcast(&state->buffer_can_read);
        pthread_mutex_unlock(&state->buffer_lock);
    }
    return NULL;
}

static size_t iso_read(void *opaque, void *data, size_t size)
{
    struct iso_source_state *state = opaque;
    uint8_t *output = data;
    size_t total = 0;

    if (!state->buffer_thread_started)
        return iso_read_navigation(state, data, size);
    while (total < size) {
        size_t count;
        size_t first;
        uint64_t wait_start = 0;

        pthread_mutex_lock(&state->buffer_lock);
        while (!state->buffer_fill && !state->buffer_end_of_stream &&
               !state->buffer_error) {
            if (!wait_start)
                wait_start = monotonic_microseconds();
            pthread_cond_wait(&state->buffer_can_read, &state->buffer_lock);
        }
        if (wait_start) {
            uint64_t now = monotonic_microseconds();
            uint64_t wait_us = now >= wait_start ? now - wait_start : 0;

            if (wait_us >= DVD_BUFFER_LOG_WAIT_US) {
                ++state->buffer_stall_events;
                state->buffer_stall_us += wait_us;
                if (wait_us > state->buffer_stall_max_us)
                    state->buffer_stall_max_us = wait_us;
                fprintf(stderr,
                        "media_source: DVD buffer consumer waited %llu us\n",
                        (unsigned long long)wait_us);
            }
        }
        if (!state->buffer_fill) {
            pthread_mutex_unlock(&state->buffer_lock);
            break;
        }
        count = size - total < state->buffer_fill ?
                size - total : state->buffer_fill;
        first = DVD_BUFFER_CAPACITY - state->buffer_read;
        if (first > count)
            first = count;
        memcpy(output + total, state->buffer + state->buffer_read, first);
        memcpy(output + total + first, state->buffer, count - first);
        state->buffer_read = (state->buffer_read + count) %
                             DVD_BUFFER_CAPACITY;
        state->buffer_fill -= count;
        state->buffer_consumed += count;
        pthread_cond_broadcast(&state->buffer_can_write);
        pthread_mutex_unlock(&state->buffer_lock);
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
    int32_t title = state->title;

    if (state->buffer_thread_started) {
        pthread_mutex_lock(&state->buffer_lock);
        state->buffer_stop = 1;
        pthread_cond_broadcast(&state->buffer_can_write);
        pthread_cond_broadcast(&state->buffer_can_read);
        pthread_mutex_unlock(&state->buffer_lock);
        pthread_join(state->buffer_thread, NULL);
        state->buffer_thread_started = 0;
    }
    if (state->direct_device) {
        if (dvdnav_reset(state->navigation) != DVDNAV_STATUS_OK ||
            dvdnav_title_play(state->navigation, title) != DVDNAV_STATUS_OK) {
            state->error = 1;
            return -1;
        }
        fprintf(stderr,
                "media_source: DVD reset authenticated navigation title %d\n",
                (int)title);
    } else {
        dvdnav_close(state->navigation);
        state->navigation = NULL;
        if (state->stream)
            clearerr(state->stream);
        if ((state->stream && fseeko(state->stream, 0, SEEK_SET) != 0) ||
            dvd_navigation_open(state) < 0 ||
            dvdnav_title_play(state->navigation, title) != DVDNAV_STATUS_OK) {
            state->error = 1;
            return -1;
        }
    }
    if (state->buffer_sync_initialized) {
        pthread_mutex_lock(&state->buffer_lock);
        state->buffer_read = 0;
        state->buffer_write = 0;
        state->buffer_fill = 0;
        state->buffer_stop = 0;
        state->buffer_end_of_stream = 0;
        state->buffer_error = 0;
        state->buffer_produced = 0;
        state->buffer_consumed = 0;
        state->buffer_stall_events = 0;
        state->buffer_stall_us = 0;
        state->buffer_stall_max_us = 0;
        state->test_stall_injected = 0;
        pthread_mutex_unlock(&state->buffer_lock);
    }
    state->block_offset = 0;
    state->block_size = 0;
    state->title_active = 0;
    state->title_part = 0;
    state->cell_part = 0;
    state->cell_number = 0;
    state->end_of_stream = 0;
    state->error = 0;
    return 0;
}

#ifndef __arm__
static int parse_test_u64(const char *name, uint64_t *value)
{
    const char *text = getenv(name);
    char *end;
    unsigned long long parsed;

    if (!text || !*text)
        return 0;
    errno = 0;
    parsed = strtoull(text, &end, 10);
    if (errno || *end) {
        fprintf(stderr, "media_source: ignoring invalid %s=%s\n", name, text);
        return 0;
    }
    *value = (uint64_t)parsed;
    return 1;
}
#endif

static int iso_prepare(void *opaque)
{
    struct iso_source_state *state = opaque;
    uint64_t prefill_start;
    int lock_ready = 0;
    int read_ready = 0;

    if (!state->direct_device || state->buffer_thread_started)
        return 0;
    if (!state->buffer_sync_initialized) {
        state->buffer = malloc(DVD_BUFFER_CAPACITY);
        if (!state->buffer)
            return -1;
        if (pthread_mutex_init(&state->buffer_lock, NULL) != 0)
            goto init_failed;
        lock_ready = 1;
        if (pthread_cond_init(&state->buffer_can_read, NULL) != 0)
            goto init_failed;
        read_ready = 1;
        if (pthread_cond_init(&state->buffer_can_write, NULL) != 0)
            goto init_failed;
        state->buffer_sync_initialized = 1;
    }
#ifndef __arm__
    {
        uint64_t stall_ms = 0;

        parse_test_u64("MMP_DVD_TEST_STALL_AFTER_BYTES",
                       &state->test_stall_after_bytes);
        if (parse_test_u64("MMP_DVD_TEST_STALL_MS", &stall_ms)) {
            if (stall_ms > UINT_MAX)
                stall_ms = UINT_MAX;
            state->test_stall_ms = (unsigned)stall_ms;
        }
    }
#endif
    prefill_start = monotonic_microseconds();
    if (pthread_create(&state->buffer_thread, NULL, iso_buffer_producer,
                       state) != 0)
        return -1;
    state->buffer_thread_started = 1;
    pthread_mutex_lock(&state->buffer_lock);
    while (state->buffer_fill < DVD_BUFFER_PREFILL &&
           !state->buffer_end_of_stream && !state->buffer_error)
        pthread_cond_wait(&state->buffer_can_read, &state->buffer_lock);
    if (state->buffer_error || (!state->buffer_fill &&
                                state->buffer_end_of_stream)) {
        pthread_mutex_unlock(&state->buffer_lock);
        return -1;
    }
    fprintf(stderr,
            "media_source: DVD buffer ready reserve=%zu capacity=%u "
            "prefill_us=%llu\n",
            state->buffer_fill, DVD_BUFFER_CAPACITY,
            (unsigned long long)(monotonic_microseconds() - prefill_start));
    pthread_mutex_unlock(&state->buffer_lock);
    return 0;

init_failed:
    if (read_ready)
        pthread_cond_destroy(&state->buffer_can_read);
    if (lock_ready)
        pthread_mutex_destroy(&state->buffer_lock);
    free(state->buffer);
    state->buffer = NULL;
    return -1;
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
    int source_error;

    if (state->buffer_thread_started) {
        pthread_mutex_lock(&state->buffer_lock);
        source_error = state->buffer_error;
        pthread_mutex_unlock(&state->buffer_lock);
        return source_error;
    }
    return state->error ||
           (state->stream && ferror(state->stream));
}

static void iso_close(void *opaque)
{
    struct iso_source_state *state = opaque;

    if (!state)
        return;
    if (state->buffer_thread_started) {
        pthread_mutex_lock(&state->buffer_lock);
        state->buffer_stop = 1;
        pthread_cond_broadcast(&state->buffer_can_write);
        pthread_cond_broadcast(&state->buffer_can_read);
        pthread_mutex_unlock(&state->buffer_lock);
        pthread_join(state->buffer_thread, NULL);
        state->buffer_thread_started = 0;
    }
    if (state->buffer_sync_initialized) {
        fprintf(stderr,
                "media_source: DVD buffer summary produced=%llu consumed=%llu "
                "waits=%llu wait_us=%llu wait_max_us=%llu\n",
                (unsigned long long)state->buffer_produced,
                (unsigned long long)state->buffer_consumed,
                (unsigned long long)state->buffer_stall_events,
                (unsigned long long)state->buffer_stall_us,
                (unsigned long long)state->buffer_stall_max_us);
        pthread_cond_destroy(&state->buffer_can_write);
        pthread_cond_destroy(&state->buffer_can_read);
        pthread_mutex_destroy(&state->buffer_lock);
    }
    if (state->navigation)
        dvdnav_close(state->navigation);
    if (state->stream)
        fclose(state->stream);
    free(state->buffer);
    free(state->device_path);
    free(state);
}

static const struct media_source_ops iso_ops = {
    iso_read,
    iso_get_character,
    iso_rewind,
    iso_prepare,
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
        struct iso_source_state *dvd_state;

        source->kind = MEDIA_SOURCE_DVD;
        location = specification + strlen(MEDIA_PLAYER_DVD_PREFIX);
        if (!*location || location[0] != '/') {
            set_error(error, error_size,
                      "DVD source requires an absolute device path",
                      *location ? location : NULL);
            return MEDIA_SOURCE_INVALID;
        }
        dvd_state = calloc(1, sizeof(*dvd_state));
        if (!dvd_state) {
            set_error(error, error_size, "out of memory", NULL);
            return MEDIA_SOURCE_IO_ERROR;
        }
        dvd_state->device_path = strdup(location);
        dvd_state->direct_device = 1;
        if (!dvd_state->device_path) {
            set_error(error, error_size, "out of memory", NULL);
            iso_close(dvd_state);
            return MEDIA_SOURCE_IO_ERROR;
        }
        if (dvd_navigation_open(dvd_state) < 0 ||
            iso_select_title(dvd_state) < 0) {
            const char *detail = dvd_state->navigation ?
                dvdnav_err_to_string(dvd_state->navigation) : location;
            set_error(error, error_size, "cannot open DVD device", detail);
            iso_close(dvd_state);
            return MEDIA_SOURCE_IO_ERROR;
        }
        fprintf(stderr,
                "media_source: DVD device %s selected longest title %d "
                "chapters=%u duration90k=%llu\n",
                dvd_state->device_path, (int)dvd_state->title,
                dvd_state->chapters,
                (unsigned long long)dvd_state->duration);
        source->ops = &iso_ops;
        source->state = dvd_state;
        return MEDIA_SOURCE_OK;
    }
    if (starts_with(specification, MEDIA_PLAYER_ISO_PREFIX)) {
        struct iso_source_state *iso_state;

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
        if (dvd_navigation_open(iso_state) < 0 ||
            iso_select_title(iso_state) < 0) {
            const char *detail = iso_state->navigation ?
                dvdnav_err_to_string(iso_state->navigation) : location;
            set_error(error, error_size, "cannot open DVD ISO",
                      detail);
            iso_close(iso_state);
            return MEDIA_SOURCE_IO_ERROR;
        }
        fprintf(stderr,
                "media_source: ISO selected longest title %d "
                "chapters=%u duration90k=%llu\n",
                (int)iso_state->title,
                iso_state->chapters,
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

int media_source_prepare(struct media_source *source)
{
    return source && source->ops ? source->ops->prepare_source(source->state) : -1;
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
