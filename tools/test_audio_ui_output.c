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
    unsigned layout_checks;
    unsigned expected_progress[3];
    int check_layout_enabled;
    int failed;
    int layout_failed;
};

static const char *preview_path;

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

static uint8_t frame_y(const uint8_t *frame, unsigned x, unsigned y)
{
    return frame[(size_t)y * AUDIO_UI_WIDTH + x];
}

static void check_layout(struct capture *capture)
{
    const uint8_t *frame = capture->frame;
    unsigned progress = capture->expected_progress[capture->commits];
    int failed = 0;

    failed |= frame_y(frame, 0, 0) != 16u;
    failed |= frame_y(frame, 32, 24) != 112u;
    failed |= frame_y(frame, 36, 28) != 30u;
    failed |= frame_y(frame, 48, 66) != 116u;
    failed |= frame_y(frame, 93, 40) != 220u;
    failed |= frame_y(frame, 32, 236) != 112u;
    failed |= frame_y(frame, 272, 24) != 112u;
    failed |= frame_y(frame, 284, 78) != 38u;
    failed |= frame_y(frame, 290, 40) != 220u;
    failed |= frame_y(frame, 210, 364) != 112u;
    failed |= frame_y(frame, 32, 438) != 42u;
    failed |= progress > 652u;
    failed |= frame_y(frame, 34, 444) !=
              (progress ? 178u : 42u);
    if (progress)
        failed |= frame_y(frame, 33u + progress, 444) != 178u;
    if (progress <= 652u)
        failed |= frame_y(frame, 34u + progress, 444) != 42u;
    capture->layout_checks++;
    capture->layout_failed |= failed;
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
        if (capture->check_layout_enabled)
            check_layout(capture);
        if (preview_path && capture->commits == 0u) {
            FILE *preview = fopen(preview_path, "wb");
            int write_failed;

            if (!preview) {
                capture->failed = 1;
                return -1;
            }
            write_failed =
                fwrite(capture->frame, 1, sizeof(capture->frame), preview) !=
                    sizeof(capture->frame);
            write_failed |= fclose(preview) != 0;
            if (write_failed) {
                capture->failed = 1;
                return -1;
            }
            preview_path = NULL;
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
    struct capture capture = {
        .expected_progress = {163u, 326u, 489u},
        .check_layout_enabled = 1
    };
    uint64_t frames;

    if (audio_ui_create(&ui) < 0 ||
        audio_ui_set_track_length(ui, 4u * (uint64_t)rate_hz,
                                  rate_hz) < 0) {
        fprintf(stderr, "audio UI allocation failed\n");
        audio_ui_destroy(ui);
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
        capture.layout_checks < 2u || capture.layout_failed ||
        audio_ui_committed_frames(ui) != capture.commits) {
        fprintf(stderr,
                "audio UI %u Hz mismatch begins=%u data=%u commits=%u "
                "hash0=%08x hash1=%08x layout=%u/%d api=%u\n",
                rate_hz, capture.begins, capture.data_records, capture.commits,
                capture.hashes[0], capture.hashes[1],
                capture.layout_checks, capture.layout_failed,
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
    struct capture after = {
        .expected_progress = {247u, 0u, 0u},
        .check_layout_enabled = 1
    };
    uint64_t emitted = 0;

    if (audio_ui_create(&ui) < 0 ||
        audio_ui_set_track_length(ui, 100u * 48000u, 48000u) < 0) {
        audio_ui_destroy(ui);
        return 1;
    }
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
    puts("audio UI seek reset PASS position=37s progress=247/652");
    audio_ui_destroy(ui);
    return 0;
}

static int run_complete_progress(void)
{
    struct audio_ui *ui = NULL;
    struct capture capture = {
        .expected_progress = {652u, 0u, 0u},
        .check_layout_enabled = 1
    };
    uint64_t emitted = 0;

    if (audio_ui_create(&ui) < 0 ||
        audio_ui_set_track_length(ui, 100u * 44100u, 44100u) < 0 ||
        audio_ui_seek(ui, 0, 44100u, 99u * 44100u) < 0) {
        audio_ui_destroy(ui);
        return 1;
    }
    while (!capture.commits) {
        emitted += 16;
        if (audio_ui_service(ui, emitted, 44100u,
                             capture_record, &capture) < 0) {
            audio_ui_destroy(ui);
            return 1;
        }
    }
    if (capture.failed || capture.layout_failed ||
        capture.layout_checks != 1u || capture.commits != 1u) {
        fprintf(stderr,
                "audio UI complete progress mismatch commits=%u layout=%u/%d\n",
                capture.commits, capture.layout_checks,
                capture.layout_failed);
        audio_ui_destroy(ui);
        return 1;
    }
    puts("audio UI complete progress PASS position=100s progress=652/652");
    audio_ui_destroy(ui);
    return 0;
}

static int run_large_progress(void)
{
    struct audio_ui *ui = NULL;
    struct capture capture = {
        .expected_progress = {326u, 0u, 0u},
        .check_layout_enabled = 1
    };
    uint64_t emitted = 0;

    if (audio_ui_create(&ui) < 0 ||
        audio_ui_set_track_length(ui, UINT64_MAX, 48000u) < 0 ||
        audio_ui_seek(ui, 0, 48000u, UINT64_MAX / 2u + 1u) < 0) {
        audio_ui_destroy(ui);
        return 1;
    }
    while (!capture.commits) {
        emitted += 16;
        if (audio_ui_service(ui, emitted, 48000u,
                             capture_record, &capture) < 0) {
            audio_ui_destroy(ui);
            return 1;
        }
    }
    if (capture.failed || capture.layout_failed ||
        capture.layout_checks != 1u || capture.commits != 1u) {
        fprintf(stderr,
                "audio UI large progress mismatch commits=%u layout=%u/%d\n",
                capture.commits, capture.layout_checks,
                capture.layout_failed);
        audio_ui_destroy(ui);
        return 1;
    }
    puts("audio UI large progress PASS UINT64 timeline progress=326/652");
    audio_ui_destroy(ui);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && !strcmp(argv[1], "--dump-yuv"))
        preview_path = argv[2];
    else if (argc != 1) {
        fprintf(stderr, "usage: %s [--dump-yuv OUTPUT]\n", argv[0]);
        return 2;
    }
    if (run_rate(48000u, 110000u) != 0)
        return 1;
    if (run_rate(44100u, 100000u) != 0)
        return 1;
    if (run_seek_reset() != 0)
        return 1;
    if (run_complete_progress() != 0)
        return 1;
    if (run_large_progress() != 0)
        return 1;
    return 0;
}
