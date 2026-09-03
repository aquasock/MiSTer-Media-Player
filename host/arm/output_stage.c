#include "output_stage.h"

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

struct output_stage_record {
    struct output_stage_record *next;
    size_t size;
    int priority;
    uint8_t data[];
};

struct output_stage {
    struct output_stage_record *head;
    struct output_stage_record *tail;
    size_t capacity;
    size_t size;
    size_t records;
    int active;
};

static void output_stage_clear(struct output_stage *stage)
{
    struct output_stage_record *record = stage->head;

    while (record) {
        struct output_stage_record *next = record->next;

        free(record);
        record = next;
    }
    stage->head = NULL;
    stage->tail = NULL;
    stage->size = 0;
    stage->records = 0;
}

int output_stage_create(struct output_stage **stage_out, size_t capacity)
{
    struct output_stage *stage;

    if (!stage_out || !capacity) {
        errno = EINVAL;
        return -1;
    }
    *stage_out = NULL;
    stage = calloc(1, sizeof(*stage));
    if (!stage)
        return -1;
    stage->capacity = capacity;
    *stage_out = stage;
    return 0;
}

int output_stage_begin(struct output_stage *stage)
{
    if (!stage) {
        errno = EINVAL;
        return -1;
    }
    if (stage->active || stage->head) {
        errno = EBUSY;
        return -1;
    }
    stage->active = 1;
    return 0;
}

int output_stage_write(struct output_stage *stage, const void *data,
                       size_t size, int priority)
{
    struct output_stage_record *record;

    if (!stage || (!data && size)) {
        errno = EINVAL;
        return -1;
    }
    if (!stage->active)
        return 0;
    if (!size)
        return 1;
    if (size > stage->capacity - stage->size ||
        size > SIZE_MAX - sizeof(*record)) {
        errno = ENOSPC;
        return -1;
    }
    record = malloc(sizeof(*record) + size);
    if (!record)
        return -1;
    record->next = NULL;
    record->size = size;
    record->priority = priority != 0;
    memcpy(record->data, data, size);
    if (stage->tail)
        stage->tail->next = record;
    else
        stage->head = record;
    stage->tail = record;
    stage->size += size;
    stage->records++;
    return 1;
}

int output_stage_commit(struct output_stage *stage,
                        output_stage_writer writer, void *opaque,
                        size_t *committed_bytes, size_t *committed_records)
{
    size_t bytes = 0;
    size_t records = 0;

    if (!stage || !writer || !stage->active) {
        errno = EINVAL;
        return -1;
    }
    while (stage->head) {
        struct output_stage_record *record = stage->head;

        if (writer(opaque, record->data, record->size,
                   record->priority) < 0)
            return -1;
        stage->head = record->next;
        stage->size -= record->size;
        stage->records--;
        bytes += record->size;
        records++;
        free(record);
    }
    stage->tail = NULL;
    stage->active = 0;
    if (committed_bytes)
        *committed_bytes = bytes;
    if (committed_records)
        *committed_records = records;
    return 0;
}

int output_stage_cancel(struct output_stage *stage,
                        size_t *cancelled_bytes, size_t *cancelled_records)
{
    size_t bytes;
    size_t records;

    if (!stage || !stage->active) {
        errno = EINVAL;
        return -1;
    }
    bytes = stage->size;
    records = stage->records;
    output_stage_clear(stage);
    stage->active = 0;
    if (cancelled_bytes)
        *cancelled_bytes = bytes;
    if (cancelled_records)
        *cancelled_records = records;
    return 0;
}

void output_stage_destroy(struct output_stage *stage)
{
    if (!stage)
        return;
    output_stage_clear(stage);
    free(stage);
}

int output_stage_active(const struct output_stage *stage)
{
    return stage && stage->active;
}

size_t output_stage_size(const struct output_stage *stage)
{
    return stage ? stage->size : 0;
}

size_t output_stage_records(const struct output_stage *stage)
{
    return stage ? stage->records : 0;
}

enum output_stage_still_action output_stage_classify_still(
    const struct output_stage *stage, unsigned video_pictures,
    unsigned seconds)
{
    if (!output_stage_active(stage))
        return OUTPUT_STAGE_STILL_NONE;
    if (seconds != 0xffu)
        return OUTPUT_STAGE_STILL_COMMIT;
    if (video_pictures)
        return OUTPUT_STAGE_STILL_HOP;
    return output_stage_records(stage) ? OUTPUT_STAGE_STILL_CONTINUE :
                                         OUTPUT_STAGE_STILL_CANCEL;
}
