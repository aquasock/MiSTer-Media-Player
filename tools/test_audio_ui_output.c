#include "../host/arm/audio_ui.h"
#include "../host/arm/media_player_protocol.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct capture {
    uint8_t frame[AUDIO_UI_FRAME_BYTES];
    uint32_t hashes[3];
    size_t offset;
    unsigned begins;
    unsigned data_records;
    unsigned commits;
    int failed;
};

static uint32_t fnv1a(const uint8_t *data, size_t size)
{
    uint32_t hash = 2166136261u;
    size_t index;

    for (index = 0; index < size; ++index) {
        hash ^= data[index];
        hash *= 16777619u;
    }
    return hash;
}

static int capture_record(void *opaque, uint8_t command,
                          const uint8_t *payload, size_t size)
{
    struct capture *capture = opaque;

    if (command == MEDIA_PLAYER_AUDIO_UI_BEGIN) {
        if (size || capture->offset)
            capture->failed = 1;
        capture->begins++;
        return 0;
    }
    if (command == MEDIA_PLAYER_AUDIO_UI_DATA) {
        if (!size || size > AUDIO_UI_DATA_BYTES ||
            capture->offset + size > sizeof(capture->frame)) {
            capture->failed = 1;
            return -1;
        }
        memcpy(capture->frame + capture->offset, payload, size);
        capture->offset += size;
        capture->data_records++;
        return 0;
    }
    if (command == MEDIA_PLAYER_AUDIO_UI_COMMIT) {
        if (size || capture->offset != sizeof(capture->frame) ||
            capture->commits >= 3u) {
            capture->failed = 1;
            return -1;
        }
        capture->hashes[capture->commits] =
            fnv1a(capture->frame, sizeof(capture->frame));
        capture->commits++;
        capture->offset = 0;
        return 0;
    }
    capture->failed = 1;
    return -1;
}

static int run_rate(unsigned rate_hz, uint64_t frame_limit)
{
    struct audio_ui *ui = NULL;
    struct capture capture = {0};
    uint64_t frames;

    if (audio_ui_create(&ui) < 0) {
        fprintf(stderr, "audio UI allocation failed\n");
        return 1;
    }
    for (frames = 16; frames <= frame_limit; frames += 16) {
        if (audio_ui_service(ui, frames, rate_hz,
                             capture_record, &capture) < 0) {
            fprintf(stderr, "audio UI service failed at %llu\n",
                    (unsigned long long)frames);
            audio_ui_destroy(ui);
            return 1;
        }
    }
    if (capture.failed || capture.commits < 2u ||
        capture.begins < capture.commits ||
        capture.data_records < capture.commits * 127u ||
        capture.hashes[0] == capture.hashes[1] ||
        audio_ui_committed_frames(ui) != capture.commits) {
        fprintf(stderr,
                "audio UI %u Hz mismatch begins=%u data=%u commits=%u "
                "hash0=%08x hash1=%08x api=%u\n",
                rate_hz, capture.begins, capture.data_records, capture.commits,
                capture.hashes[0], capture.hashes[1],
                audio_ui_committed_frames(ui));
        audio_ui_destroy(ui);
        return 1;
    }
    printf("audio UI %u Hz PASS begins=%u data=%u commits=%u "
           "hash0=%08x hash1=%08x\n",
           rate_hz, capture.begins, capture.data_records, capture.commits,
           capture.hashes[0], capture.hashes[1]);
    audio_ui_destroy(ui);
    return 0;
}

static int run_seek_reset(void)
{
    struct audio_ui *ui = NULL;
    struct capture before = {0};
    struct capture after = {0};
    uint64_t emitted = 0;

    if (audio_ui_create(&ui) < 0)
        return 1;
    while (!before.data_records) {
        emitted += 16;
        if (audio_ui_service(ui, emitted, 48000u,
                             capture_record, &before) < 0) {
            audio_ui_destroy(ui);
            return 1;
        }
    }
    if (audio_ui_seek(ui, emitted, 48000u, 37u * 48000u) < 0) {
        audio_ui_destroy(ui);
        return 1;
    }
    while (!after.commits) {
        emitted += 16;
        if (audio_ui_service(ui, emitted, 48000u,
                             capture_record, &after) < 0) {
            audio_ui_destroy(ui);
            return 1;
        }
    }
    if (after.failed || after.begins != 1u || after.data_records != 127u ||
        after.commits != 1u || !after.hashes[0] ||
        audio_ui_committed_frames(ui) != 1u) {
        fprintf(stderr,
                "audio UI seek reset mismatch begins=%u data=%u commits=%u "
                "hash=%08x api=%u\n",
                after.begins, after.data_records, after.commits,
                after.hashes[0], audio_ui_committed_frames(ui));
        audio_ui_destroy(ui);
        return 1;
    }
    puts("audio UI seek reset PASS position=37s complete-frame restart");
    audio_ui_destroy(ui);
    return 0;
}

int main(void)
{
    if (run_rate(48000u, 110000u) != 0)
        return 1;
    if (run_rate(44100u, 100000u) != 0)
        return 1;
    if (run_seek_reset() != 0)
        return 1;
    return 0;
}
