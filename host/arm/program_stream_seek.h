#ifndef PROGRAM_STREAM_SEEK_H
#define PROGRAM_STREAM_SEEK_H

#include <stddef.h>
#include <stdint.h>

struct program_stream_seek_entry {
    uint64_t pts_90k;
    int64_t source_offset;
};

struct program_stream_seek_index {
    struct program_stream_seek_entry *entries;
    size_t count;
    size_t capacity;
};

void program_stream_seek_destroy(struct program_stream_seek_index *index);
int program_stream_seek_record(struct program_stream_seek_index *index,
                               uint64_t pts_90k, int64_t source_offset);
uint64_t program_stream_seek_target(uint64_t current_pts_90k,
                                    int delta_seconds);
int program_stream_seek_find(const struct program_stream_seek_index *index,
                             uint64_t target_pts_90k,
                             struct program_stream_seek_entry *entry);

#endif
