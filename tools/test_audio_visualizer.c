#define _POSIX_C_SOURCE 200809L

#include "../host/arm/audio_visualizer.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void put32(uint8_t *p, uint32_t value)
{
    p[0] = (uint8_t)value;
    p[1] = (uint8_t)(value >> 8);
    p[2] = (uint8_t)(value >> 16);
    p[3] = (uint8_t)(value >> 24);
}

struct capture { unsigned writes; unsigned level_byte; };

static int capture_write(void *opaque, const uint8_t *data, size_t size)
{
    struct capture *capture = opaque;
    if (size < 5 || memcmp(data, "\0\0\1\xb3", 4))
        return -1;
    capture->writes++;
    capture->level_byte = data[4];
    return 0;
}

int main(void)
{
    char path[] = "/tmp/mmp-visualizer-test-XXXXXX";
    uint8_t file[32 + 4 * 2 * 8 + 4 * 2 * 24] = {0};
    int16_t loud[2048 * 2];
    struct audio_visualizer *visualizer = NULL;
    struct capture capture = {0};
    char error[128];
    size_t index;
    uint32_t offset = 32 + 4 * 2 * 8;
    int fd = mkstemp(path);
    FILE *stream;

    if (fd < 0)
        return 1;
    memcpy(file, "MMPVIS1\0", 8);
    put32(file + 8, 1); put32(file + 12, 4); put32(file + 16, 2);
    put32(file + 20, 1); put32(file + 24, 30000); put32(file + 28, 1001);
    for (index = 0; index < 8; ++index) {
        put32(file + 32 + index * 8, offset);
        put32(file + 36 + index * 8, 24);
        memcpy(file + offset, "\0\0\1\xb3", 4);
        file[offset + 4] = (uint8_t)(index / 2);
        memcpy(file + offset + 8, "\0\0\1\xb8", 4);
        file[offset + 15] = 0x40;
        memcpy(file + offset + 16, "\0\0\1\x00", 4);
        file[offset + 21] = 0x08;
        offset += 24;
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
    memset(loud, 0x40, sizeof(loud));
    audio_visualizer_analyze(visualizer, loud, 2048);
    if (audio_visualizer_level(visualizer) != 3 ||
        audio_visualizer_service(visualizer, 16, 48000,
                                 capture_write, &capture) != 1 ||
        capture.level_byte != 3 || capture.writes != 1)
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
        capture.writes != 2)
        return 1;
    audio_visualizer_destroy(visualizer);
    unlink(path);
    puts("audio visualizer: pass");
    return 0;
}
