#define _POSIX_C_SOURCE 200809L

#include "../host/arm/output_stage.h"
#include "../host/arm/output_reserve.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

struct capture {
    uint8_t data[64];
    int priority[8];
    size_t size;
    size_t records;
    size_t fail_after;
    int inject_failure;
};

struct reserve_writer {
    struct output_reserve *reserve;
};

struct count_capture {
    size_t size;
    size_t records;
    size_t priority_records;
};

static int capture_write(void *opaque, const void *data, size_t size,
                         int priority)
{
    struct capture *capture = opaque;

    if (capture->inject_failure && capture->records == capture->fail_after) {
        errno = EIO;
        return -1;
    }
    if (capture->size + size > sizeof(capture->data) ||
        capture->records >= sizeof(capture->priority) /
                            sizeof(capture->priority[0])) {
        errno = ENOSPC;
        return -1;
    }
    memcpy(capture->data + capture->size, data, size);
    capture->size += size;
    capture->priority[capture->records++] = priority;
    return 0;
}

static int reserve_write(void *opaque, const void *data, size_t size,
                         int priority)
{
    struct reserve_writer *writer = opaque;

    return priority ?
        output_reserve_write_priority(writer->reserve, data, size) :
        output_reserve_write(writer->reserve, data, size);
}

static int count_write(void *opaque, const void *data, size_t size,
                       int priority)
{
    struct count_capture *capture = opaque;

    if ((!data && size) || capture->size > SIZE_MAX - size) {
        errno = EOVERFLOW;
        return -1;
    }
    capture->size += size;
    capture->records++;
    if (priority)
        capture->priority_records++;
    return 0;
}

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "output stage: %s\n", message);
    return 1;
}

int main(void)
{
    static const uint8_t first[] = {0x10, 0x11, 0x12};
    static const uint8_t second[] = {0xa0, 0xa1};
    static const uint8_t third[] = {0x20, 0x21, 0x22, 0x23};
    static const uint8_t expected[] = {
        0x10, 0x11, 0x12, 0xa0, 0xa1, 0x20, 0x21, 0x22, 0x23
    };
    struct output_stage *stage = NULL;
    struct output_stage *overlay_stage = NULL;
    struct capture capture = {0};
    struct count_capture overlay_capture = {0};
    size_t bytes = 0;
    size_t records = 0;
    int failed = 0;
    int descriptors[2] = {-1, -1};
    struct output_reserve *reserve = NULL;
    struct reserve_writer reserve_writer = {0};
    uint8_t combined[sizeof(expected) + 4u];
    static const uint8_t stale[] = {0xde, 0xad, 0xbe, 0xef};
    uint8_t display_record[4103] = {0};
    ssize_t combined_size;
    unsigned record;

    failed |= require(output_stage_create(&stage, 12) == 0,
                      "create failed");
    failed |= require(output_stage_write(stage, first, sizeof(first), 0) == 0,
                      "inactive write was intercepted");
    failed |= require(output_stage_begin(stage) == 0,
                      "begin failed");
    failed |= require(output_stage_write(stage, first, sizeof(first), 0) == 1 &&
                      output_stage_write(stage, second, sizeof(second), 1) == 1 &&
                      output_stage_write(stage, third, sizeof(third), 0) == 1,
                      "active write was not staged");
    failed |= require(output_stage_size(stage) == sizeof(expected) &&
                      output_stage_records(stage) == 3,
                      "stage accounting is wrong");
    failed |= require(output_stage_commit(stage, capture_write, &capture,
                                           &bytes, &records) == 0,
                      "commit failed");
    failed |= require(bytes == sizeof(expected) && records == 3 &&
                      capture.size == sizeof(expected) &&
                      !memcmp(capture.data, expected, sizeof(expected)),
                      "commit changed byte or record order");
    failed |= require(capture.priority[0] == 0 && capture.priority[1] == 1 &&
                      capture.priority[2] == 0,
                      "commit changed priority tags");
    failed |= require(!output_stage_active(stage) &&
                      output_stage_size(stage) == 0,
                      "commit did not close the stage");

    memset(&capture, 0, sizeof(capture));
    capture.inject_failure = 1;
    capture.fail_after = 1;
    failed |= require(output_stage_begin(stage) == 0 &&
                      output_stage_write(stage, first, sizeof(first), 0) == 1 &&
                      output_stage_write(stage, second, sizeof(second), 1) == 1 &&
                      output_stage_write(stage, third, sizeof(third), 0) == 1,
                      "partial failure setup failed");
    errno = 0;
    failed |= require(output_stage_commit(stage, capture_write, &capture,
                                          NULL, NULL) < 0 && errno == EIO &&
                      output_stage_active(stage) &&
                      output_stage_size(stage) == sizeof(second) +
                                                        sizeof(third) &&
                      output_stage_records(stage) == 2,
                      "partial commit did not retain only unwritten records");
    failed |= require(output_stage_cancel(stage, &bytes, &records) == 0 &&
                      bytes == sizeof(second) + sizeof(third) && records == 2,
                      "partial commit remainder did not cancel cleanly");

    failed |= require(output_stage_begin(stage) == 0 &&
                      output_stage_write(stage, expected, sizeof(expected), 1) == 1,
                      "cancel setup failed");
    errno = 0;
    failed |= require(output_stage_write(stage, first, sizeof(first) + 1u, 0) < 0 &&
                      errno == ENOSPC &&
                      output_stage_size(stage) == sizeof(expected),
                      "capacity failure changed retained data");
    failed |= require(output_stage_cancel(stage, &bytes, &records) == 0 &&
                      bytes == sizeof(expected) && records == 1 &&
                      !output_stage_active(stage),
                      "cancel did not report and clear retained data");

    failed |= require(output_stage_classify_still(stage, 0, 0xffu) ==
                          OUTPUT_STAGE_STILL_NONE,
                      "inactive still was classified");
    failed |= require(output_stage_begin(stage) == 0 &&
                      output_stage_classify_still(stage, 0, 0xffu) ==
                          OUTPUT_STAGE_STILL_CANCEL,
                      "empty indefinite still did not preserve resident video");
    failed |= require(output_stage_cancel(stage, NULL, NULL) == 0 &&
                      output_stage_begin(stage) == 0 &&
                      output_stage_write(stage, expected,
                                         sizeof(expected), 1) == 1 &&
                      output_stage_classify_still(stage, 0, 0xffu) ==
                          OUTPUT_STAGE_STILL_CONTINUE,
                      "non-video indefinite still did not continue");
    failed |= require(output_stage_classify_still(stage, 1, 0xffu) ==
                          OUTPUT_STAGE_STILL_HOP,
                      "picture-bearing indefinite still was not a hop");
    failed |= require(output_stage_classify_still(stage, 0, 10) ==
                          OUTPUT_STAGE_STILL_COMMIT,
                      "finite still did not retain delayed activation");
    failed |= require(output_stage_cancel(stage, NULL, NULL) == 0,
                      "still classification setup did not cancel");

    failed |= require(output_stage_create(&overlay_stage, 86664u) == 0 &&
                      output_stage_begin(overlay_stage) == 0 &&
                      output_stage_write(overlay_stage, display_record,
                                         48u, 1) == 1 &&
                      output_stage_write(overlay_stage, display_record,
                                         7u, 1) == 1 &&
                      output_stage_write(overlay_stage, display_record,
                                         48u, 1) == 1,
                      "Coming to America overlay stage setup failed");
    for (record = 0; record < 21u; ++record)
        failed |= require(output_stage_write(overlay_stage, display_record,
                                             sizeof(display_record), 1) == 1,
                          "Coming to America full overlay record failed");
    failed |= require(output_stage_write(overlay_stage, display_record,
                                         391u, 1) == 1 &&
                      output_stage_write(overlay_stage, display_record,
                                         7u, 1) == 1 &&
                      output_stage_size(overlay_stage) == 86664u &&
                      output_stage_records(overlay_stage) == 26u,
                      "Coming to America overlay accounting is wrong");
    failed |= require(output_stage_classify_still(
                          overlay_stage, 0, 0xffu) ==
                          OUTPUT_STAGE_STILL_CONTINUE,
                      "Coming to America overlay-only still requested a hop");
    failed |= require(output_stage_commit(
                          overlay_stage, count_write, &overlay_capture,
                          &bytes, &records) == 0 && bytes == 86664u &&
                      records == 26u && overlay_capture.size == 86664u &&
                      overlay_capture.records == 26u &&
                      overlay_capture.priority_records == 26u,
                      "Coming to America overlay continuation changed output");

    if (pipe(descriptors) < 0) {
        failed |= require(0, "reserve preservation pipe failed");
        goto cleanup;
    }
    if (output_reserve_create(&reserve, descriptors[1], 4096) < 0) {
        failed |= require(0, "reserve preservation setup failed");
        goto cleanup;
    }
    reserve_writer.reserve = reserve;
    failed |= require(output_stage_begin(stage) == 0 &&
                      output_stage_write(stage, expected,
                                         sizeof(expected), 0) == 1 &&
                      output_reserve_write(reserve, stale,
                                           sizeof(stale)) == 0 &&
                      output_reserve_discard(reserve, NULL) == 0 &&
                      output_stage_commit(stage, reserve_write,
                                          &reserve_writer, NULL, NULL) == 0 &&
                      output_reserve_destroy(reserve) == 0,
                      "staged destination did not survive stale-reserve discard");
    reserve = NULL;
    close(descriptors[1]);
    descriptors[1] = -1;
    combined_size = read(descriptors[0], combined, sizeof(combined));
    failed |= require(combined_size >= (ssize_t)sizeof(expected) &&
                      !memcmp(combined + combined_size - sizeof(expected),
                              expected, sizeof(expected)),
                      "stale-reserve discard changed staged destination bytes");
    close(descriptors[0]);
    descriptors[0] = -1;

cleanup:
    output_stage_destroy(stage);
    output_stage_destroy(overlay_stage);
    if (reserve)
        (void)output_reserve_destroy(reserve);
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    if (failed)
        return 1;
    puts("output stage: bounded order, priority and still policy pass");
    return 0;
}
