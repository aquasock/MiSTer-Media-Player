#ifndef OUTPUT_STAGE_H
#define OUTPUT_STAGE_H

#include <stddef.h>

struct output_stage;

typedef int (*output_stage_writer)(void *opaque, const void *data,
                                   size_t size, int priority);

enum output_stage_still_action {
    OUTPUT_STAGE_STILL_NONE = 0,
    OUTPUT_STAGE_STILL_COMMIT,
    OUTPUT_STAGE_STILL_CANCEL,
    OUTPUT_STAGE_STILL_HOP
};

int output_stage_create(struct output_stage **stage, size_t capacity);
int output_stage_begin(struct output_stage *stage);
int output_stage_write(struct output_stage *stage, const void *data,
                       size_t size, int priority);
int output_stage_commit(struct output_stage *stage,
                        output_stage_writer writer, void *opaque,
                        size_t *committed_bytes, size_t *committed_records);
int output_stage_cancel(struct output_stage *stage,
                        size_t *cancelled_bytes, size_t *cancelled_records);
void output_stage_destroy(struct output_stage *stage);
int output_stage_active(const struct output_stage *stage);
size_t output_stage_size(const struct output_stage *stage);
size_t output_stage_records(const struct output_stage *stage);
enum output_stage_still_action output_stage_classify_still(
    int active, unsigned payloads, unsigned seconds);

#endif
