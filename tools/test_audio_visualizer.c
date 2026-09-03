#define _POSIX_C_SOURCE 200809L

#include "../host/arm/audio_visualizer.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TEST_GOPS 2u
#define TEST_GOP_BYTES 48u
#define TEST_ENTRIES (AUDIO_VISUALIZER_LEVELS * TEST_GOPS)
#define TEST_FILE_BYTES (32u + TEST_ENTRIES * 8u + \
                         TEST_ENTRIES * TEST_GOP_BYTES)

static void put32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

struct capture {
    unsigned writes;
    unsigned levels[64];
};

static int capture_write(void *opaque, const uint8_t *data, size_t size)
{
    struct capture *capture = opaque;
    if (size < 5 || memcmp(data, "\0\0\1\xb3", 4))
        return -1;
    if (capture->writes >= sizeof(capture->levels) / sizeof(capture->levels[0]))
        return -1;
    capture->levels[capture->writes++] = data[4];
    return 0;
}

static void fill_stereo(int16_t *samples, size_t frames, int16_t value)
{
    size_t index;

    for (index = 0; index < frames * 2u; ++index)
        samples[index] = value;
}

static void analyze_many(struct audio_visualizer *visualizer,
                         int16_t *samples, size_t frames, int16_t value,
                         unsigned count)
{
    fill_stereo(samples, frames, value);
    while (count--)
        audio_visualizer_analyze(visualizer, samples, frames);
}

static int expect_levels(struct audio_visualizer *visualizer,
                         struct capture *capture, uint64_t pcm_frames,
                         const unsigned *expected, size_t count)
{
    size_t start = capture->writes;
    size_t index;

    for (index = 0; index < count; ++index) {
        if (audio_visualizer_service(visualizer, pcm_frames, 48000,
                                     capture_write, capture) != 1)
            return -1;
    }
    for (index = 0; index < count; ++index) {
        if (capture->levels[start + index] != expected[index])
            return -1;
    }
    return 0;
}

int main(void)
{
    char path[] = "/tmp/mmp-visualizer-test-XXXXXX";
    uint8_t file[TEST_FILE_BYTES] = {0};
    int16_t loud[2048 * 2];
    struct audio_visualizer *visualizer = NULL;
    struct capture capture = {0};
    char error[128];
    size_t index;
    uint32_t offset = 32u + TEST_ENTRIES * 8u;
    static const unsigned attack[] = {1, 2, 3, 4, 5, 6, 7, 7};
    static const unsigned decay[] = {6, 5, 4, 3, 2, 1, 0, 0};
    static const unsigned rise_to_two[] = {1, 2};
    static const unsigned level_two[] = {2};
    static const unsigned level_three[] = {3};
    int fd = mkstemp(path);
    FILE *stream;

    if (fd < 0)
        return 1;
    memcpy(file, "MMPVIS1\0", 8);
    put32(file + 8, 1);
    put32(file + 12, AUDIO_VISUALIZER_LEVELS);
    put32(file + 16, TEST_GOPS);
    put32(file + 20, 1); put32(file + 24, 30000); put32(file + 28, 1001);
    for (index = 0; index < TEST_ENTRIES; ++index) {
        put32(file + 32 + index * 8, offset);
        put32(file + 36 + index * 8, TEST_GOP_BYTES);
        memcpy(file + offset, "\0\0\1\xb3", 4);
        file[offset + 4] = (uint8_t)(index / TEST_GOPS);
        memcpy(file + offset + 8, "\0\0\1\xb5\x14\x82", 6);
        memcpy(file + offset + 16, "\0\0\1\xb8", 4);
        file[offset + 23] = 0x40;
        memcpy(file + offset + 24, "\0\0\1\x00", 4);
        file[offset + 29] = 0x08;
        memcpy(file + offset + 32,
               "\0\0\1\xb5\x80\x00\x03\x80\x00", 9);
        offset += TEST_GOP_BYTES;
    }
    stream = fdopen(fd, "wb");
    if (!stream || fwrite(file, 1, sizeof(file), stream) != sizeof(file) ||
        fclose(stream) != 0)
        return 1;
    if (audio_visualizer_create(&visualizer, path, error, sizeof(error)) < 0) {
        fprintf(stderr, "%s\n", error);
        unlink(path);
        return 1;
    }
    analyze_many(visualizer, loud, 2048, 16000, 2);
    if (expect_levels(visualizer, &capture, 480000, attack,
                      sizeof(attack) / sizeof(attack[0])) < 0 ||
        audio_visualizer_level(visualizer) != 7)
        return 1;
    analyze_many(visualizer, loud, 2048, 0, 64);
    if (expect_levels(visualizer, &capture, 480000, decay,
                      sizeof(decay) / sizeof(decay[0])) < 0 ||
        audio_visualizer_level(visualizer) != 0)
        return 1;

    analyze_many(visualizer, loud, 2048, 1500, 64);
    if (expect_levels(visualizer, &capture, 480000, rise_to_two,
                      sizeof(rise_to_two) / sizeof(rise_to_two[0])) < 0)
        return 1;
    analyze_many(visualizer, loud, 2048, 1550, 64);
    if (expect_levels(visualizer, &capture, 480000, level_two, 1) < 0)
        return 1;
    analyze_many(visualizer, loud, 2048, 1600, 64);
    if (expect_levels(visualizer, &capture, 480000, level_three, 1) < 0)
        return 1;
    analyze_many(visualizer, loud, 2048, 1250, 64);
    if (expect_levels(visualizer, &capture, 480000, level_three, 1) < 0)
        return 1;
    analyze_many(visualizer, loud, 2048, 1200, 64);
    if (expect_levels(visualizer, &capture, 480000, level_two, 1) < 0)
        return 1;

    if (audio_visualizer_take_overlay_action(visualizer, 479999, 48000) ||
        audio_visualizer_take_overlay_action(visualizer, 480000, 48000) != -1)
        return 1;
    audio_visualizer_activity(visualizer, 480000);
    if (audio_visualizer_take_overlay_action(visualizer, 480000, 48000) != 1)
        return 1;
    audio_visualizer_seek(visualizer, 500000);
    if (audio_visualizer_gops_sent(visualizer) != 0)
        return 1;
    capture.writes = 0;
    if (audio_visualizer_service(visualizer, 500016, 48000,
                                 capture_write, &capture) != 1 ||
        audio_visualizer_service(visualizer, 500032, 48000,
                                 capture_write, &capture) != 1 ||
        audio_visualizer_service(visualizer, 500048, 48000,
                                 capture_write, &capture) != 0 ||
        capture.writes != 2 || capture.levels[0] != 2 ||
        capture.levels[1] != 2)
        return 1;
    audio_visualizer_destroy(visualizer);

    file[32u + TEST_ENTRIES * 8u + 13u] |= 0x08u;
    stream = fopen(path, "wb");
    if (!stream || fwrite(file, 1, sizeof(file), stream) != sizeof(file) ||
        fclose(stream) != 0 ||
        audio_visualizer_create(&visualizer, path, error, sizeof(error)) == 0)
        return 1;
    file[32u + TEST_ENTRIES * 8u + 13u] &= (uint8_t)~0x08u;
    file[32u + TEST_ENTRIES * 8u + 40u] |= 0x80u;
    stream = fopen(path, "wb");
    if (!stream || fwrite(file, 1, sizeof(file), stream) != sizeof(file) ||
        fclose(stream) != 0 ||
        audio_visualizer_create(&visualizer, path, error, sizeof(error)) == 0)
        return 1;
    unlink(path);
    puts("audio visualizer: pass");
    return 0;
}
