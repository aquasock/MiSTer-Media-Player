#include "audio_visualizer.h"

#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define VISUALIZER_MAGIC "MMPVIS1\0"
#define VISUALIZER_HEADER_BYTES 32u
#define VISUALIZER_MAX_BYTES (16u * 1024u * 1024u)
#define VISUALIZER_MAX_GOPS 120u
#define VISUALIZER_LEAD_GOPS 2u
#define VISUALIZER_IDLE_SECONDS 10u

struct visualizer_entry {
    uint32_t offset;
    uint32_t size;
};

struct audio_visualizer {
    uint8_t *file;
    size_t file_size;
    struct visualizer_entry *entries;
    unsigned gop_count;
    unsigned frames_per_gop;
    unsigned fps_num;
    unsigned fps_den;
    uint64_t gops_sent;
    uint64_t timeline_origin;
    const uint8_t *current;
    size_t current_size;
    size_t current_offset;
    uint32_t envelope;
    unsigned level;
    uint64_t activity_frame;
    int overlay_visible;
    int overlay_action;
};

static uint32_t read_le32(const uint8_t *data)
{
    return (uint32_t)data[0] | ((uint32_t)data[1] << 8) |
           ((uint32_t)data[2] << 16) | ((uint32_t)data[3] << 24);
}

static void set_error(char *error, size_t size, const char *message)
{
    if (error && size)
        (void)snprintf(error, size, "%s", message);
}

static int validate_gop(const uint8_t *data, size_t size,
                        unsigned frames_per_gop)
{
    unsigned sequences = 0;
    unsigned groups = 0;
    unsigned pictures = 0;
    int first_intra = 0;
    size_t offset;

    for (offset = 0; offset + 8u <= size; ++offset) {
        uint8_t code;

        if (memcmp(data + offset, "\0\0\1", 3u))
            continue;
        code = data[offset + 3u];
        if (code == 0xb3u) {
            if (offset != 0)
                return -1;
            sequences++;
        } else if (code == 0xb8u) {
            groups++;
            if (!(data[offset + 7u] & 0x40u))
                return -1;
        } else if (code == 0x00u) {
            if (!pictures)
                first_intra = ((data[offset + 5u] >> 3) & 7u) == 1u;
            pictures++;
        }
    }
    return sequences == 1u && groups == 1u && first_intra &&
           pictures == frames_per_gop ? 0 : -1;
}

int audio_visualizer_create(struct audio_visualizer **result,
                            const char *path, char *error, size_t error_size)
{
    struct audio_visualizer *visualizer = NULL;
    FILE *stream = NULL;
    long length;
    unsigned levels;
    size_t entry_count;
    size_t index_bytes;
    size_t index;

    if (!result || !path) {
        set_error(error, error_size, "invalid visualizer arguments");
        return -1;
    }
    *result = NULL;
    stream = fopen(path, "rb");
    if (!stream) {
        if (error && error_size)
            (void)snprintf(error, error_size, "cannot open %s: %s", path,
                           strerror(errno));
        return -1;
    }
    if (fseek(stream, 0, SEEK_END) != 0 || (length = ftell(stream)) < 0 ||
        fseek(stream, 0, SEEK_SET) != 0 ||
        (unsigned long)length > VISUALIZER_MAX_BYTES ||
        (size_t)length < VISUALIZER_HEADER_BYTES) {
        set_error(error, error_size, "invalid visualizer file size");
        goto fail;
    }
    visualizer = calloc(1, sizeof(*visualizer));
    if (!visualizer) {
        set_error(error, error_size, "out of memory loading visualizer");
        goto fail;
    }
    visualizer->file_size = (size_t)length;
    visualizer->file = malloc(visualizer->file_size);
    if (!visualizer->file ||
        fread(visualizer->file, 1, visualizer->file_size, stream) !=
            visualizer->file_size) {
        set_error(error, error_size, "cannot read visualizer file");
        goto fail;
    }
    fclose(stream);
    stream = NULL;
    if (memcmp(visualizer->file, VISUALIZER_MAGIC, 8u) != 0 ||
        read_le32(visualizer->file + 8u) != 1u) {
        set_error(error, error_size, "invalid visualizer signature");
        goto fail;
    }
    levels = read_le32(visualizer->file + 12u);
    visualizer->gop_count = read_le32(visualizer->file + 16u);
    visualizer->frames_per_gop = read_le32(visualizer->file + 20u);
    visualizer->fps_num = read_le32(visualizer->file + 24u);
    visualizer->fps_den = read_le32(visualizer->file + 28u);
    if (levels != AUDIO_VISUALIZER_LEVELS || !visualizer->gop_count ||
        visualizer->gop_count > VISUALIZER_MAX_GOPS ||
        !visualizer->frames_per_gop || visualizer->frames_per_gop > 30u ||
        !visualizer->fps_num || !visualizer->fps_den) {
        set_error(error, error_size, "unsupported visualizer geometry");
        goto fail;
    }
    entry_count = (size_t)levels * visualizer->gop_count;
    index_bytes = entry_count * 8u;
    if (index_bytes > visualizer->file_size - VISUALIZER_HEADER_BYTES) {
        set_error(error, error_size, "truncated visualizer index");
        goto fail;
    }
    visualizer->entries = calloc(entry_count, sizeof(*visualizer->entries));
    if (!visualizer->entries) {
        set_error(error, error_size, "out of memory loading visualizer index");
        goto fail;
    }
    for (index = 0; index < entry_count; ++index) {
        const uint8_t *entry = visualizer->file + VISUALIZER_HEADER_BYTES +
                               index * 8u;
        uint32_t offset = read_le32(entry);
        uint32_t size = read_le32(entry + 4u);

        if (!size || offset < VISUALIZER_HEADER_BYTES + index_bytes ||
            offset > visualizer->file_size ||
            size > visualizer->file_size - offset ||
            size < 8u ||
            validate_gop(visualizer->file + offset, size,
                         visualizer->frames_per_gop) < 0) {
            set_error(error, error_size, "invalid visualizer GOP index");
            goto fail;
        }
        visualizer->entries[index].offset = offset;
        visualizer->entries[index].size = size;
    }
    visualizer->overlay_visible = 1;
    *result = visualizer;
    return 0;

fail:
    if (stream)
        fclose(stream);
    audio_visualizer_destroy(visualizer);
    return -1;
}

void audio_visualizer_destroy(struct audio_visualizer *visualizer)
{
    if (!visualizer)
        return;
    free(visualizer->entries);
    free(visualizer->file);
    free(visualizer);
}

static uint32_t integer_sqrt(uint64_t value)
{
    uint64_t bit = (uint64_t)1 << 62;
    uint64_t root = 0;

    while (bit > value)
        bit >>= 2;
    while (bit) {
        if (value >= root + bit) {
            value -= root + bit;
            root = (root >> 1) + bit;
        } else {
            root >>= 1;
        }
        bit >>= 2;
    }
    return root > UINT32_MAX ? UINT32_MAX : (uint32_t)root;
}

void audio_visualizer_analyze(struct audio_visualizer *visualizer,
                              const int16_t *stereo, size_t frames)
{
    uint64_t squares = 0;
    size_t samples;
    size_t index;
    uint32_t rms;

    if (!visualizer || !stereo || !frames || frames > SIZE_MAX / 2u)
        return;
    samples = frames * 2u;
    for (index = 0; index < samples; ++index) {
        int32_t sample = stereo[index];
        squares += (uint64_t)(sample * sample);
    }
    rms = integer_sqrt(squares / samples);
    if (rms > visualizer->envelope)
        visualizer->envelope = (visualizer->envelope + rms * 3u) / 4u;
    else
        visualizer->envelope = (visualizer->envelope * 7u + rms) / 8u;
    visualizer->level = visualizer->envelope < 700u ? 0u :
                        visualizer->envelope < 2500u ? 1u :
                        visualizer->envelope < 7000u ? 2u : 3u;
}

static uint64_t due_gops(const struct audio_visualizer *visualizer,
                         uint64_t pcm_frames, unsigned rate_hz)
{
    uint64_t elapsed = pcm_frames >= visualizer->timeline_origin ?
                       pcm_frames - visualizer->timeline_origin : 0;
    uint64_t denominator = (uint64_t)rate_hz * visualizer->fps_den *
                           visualizer->frames_per_gop;
    uint64_t quotient = elapsed / denominator;
    uint64_t remainder = elapsed % denominator;

    return quotient * visualizer->fps_num +
           remainder * visualizer->fps_num / denominator +
           VISUALIZER_LEAD_GOPS;
}

int audio_visualizer_service(struct audio_visualizer *visualizer,
                             uint64_t emitted_pcm_frames, unsigned rate_hz,
                             audio_visualizer_writer writer, void *opaque)
{
    const struct visualizer_entry *entry;
    size_t count;
    size_t entry_index;

    if (!visualizer || !writer || !rate_hz)
        return -1;
    if (!visualizer->current) {
        if (visualizer->gops_sent >= due_gops(visualizer,
                                              emitted_pcm_frames, rate_hz))
            return 0;
        entry_index = (size_t)visualizer->level * visualizer->gop_count +
                      (size_t)(visualizer->gops_sent % visualizer->gop_count);
        entry = &visualizer->entries[entry_index];
        visualizer->current = visualizer->file + entry->offset;
        visualizer->current_size = entry->size;
        visualizer->current_offset = 0;
    }
    count = visualizer->current_size - visualizer->current_offset;
    if (count > AUDIO_VISUALIZER_SLICE_BYTES)
        count = AUDIO_VISUALIZER_SLICE_BYTES;
    if (writer(opaque, visualizer->current + visualizer->current_offset,
               count) < 0)
        return -1;
    visualizer->current_offset += count;
    if (visualizer->current_offset == visualizer->current_size) {
        visualizer->current = NULL;
        visualizer->gops_sent++;
    }
    return 1;
}

void audio_visualizer_activity(struct audio_visualizer *visualizer,
                               uint64_t emitted_pcm_frames)
{
    if (!visualizer)
        return;
    visualizer->activity_frame = emitted_pcm_frames;
    if (!visualizer->overlay_visible) {
        visualizer->overlay_visible = 1;
        visualizer->overlay_action = 1;
    }
}

void audio_visualizer_seek(struct audio_visualizer *visualizer,
                           uint64_t emitted_pcm_frames)
{
    if (!visualizer)
        return;
    visualizer->gops_sent = 0;
    visualizer->timeline_origin = emitted_pcm_frames;
    visualizer->current = NULL;
    visualizer->current_size = 0;
    visualizer->current_offset = 0;
    visualizer->activity_frame = emitted_pcm_frames;
    visualizer->overlay_visible = 1;
    visualizer->overlay_action = 0;
}

int audio_visualizer_take_overlay_action(struct audio_visualizer *visualizer,
                                         uint64_t emitted_pcm_frames,
                                         unsigned rate_hz)
{
    int action;

    if (!visualizer || !rate_hz)
        return 0;
    if (visualizer->overlay_visible &&
        emitted_pcm_frames - visualizer->activity_frame >=
            (uint64_t)rate_hz * VISUALIZER_IDLE_SECONDS) {
        visualizer->overlay_visible = 0;
        visualizer->overlay_action = -1;
    }
    action = visualizer->overlay_action;
    visualizer->overlay_action = 0;
    return action;
}

unsigned audio_visualizer_level(const struct audio_visualizer *visualizer)
{
    return visualizer ? visualizer->level : 0u;
}

uint64_t audio_visualizer_gops_sent(const struct audio_visualizer *visualizer)
{
    return visualizer ? visualizer->gops_sent : 0u;
}
