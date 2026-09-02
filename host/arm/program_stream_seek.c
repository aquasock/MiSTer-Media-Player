#include "program_stream_seek.h"

#include <limits.h>
#include <stdlib.h>

#define PROGRAM_STREAM_SEEK_INTERVAL_90K 45000u
#define PROGRAM_STREAM_SEEK_MAX_ENTRIES 262144u

void program_stream_seek_destroy(struct program_stream_seek_index *index)
{
    if (!index)
        return;
    free(index->entries);
    index->entries = NULL;
    index->count = 0;
    index->capacity = 0;
}

int program_stream_seek_record(struct program_stream_seek_index *index,
                               uint64_t pts_90k, int64_t source_offset)
{
    struct program_stream_seek_entry *entries;
    size_t capacity;

    if (!index || source_offset < 0)
        return -1;
    if (index->count) {
        uint64_t previous = index->entries[index->count - 1u].pts_90k;

        if (pts_90k <= previous ||
            pts_90k - previous < PROGRAM_STREAM_SEEK_INTERVAL_90K)
            return 0;
    }
    if (index->count == PROGRAM_STREAM_SEEK_MAX_ENTRIES)
        return -1;
    if (index->count == index->capacity) {
        capacity = index->capacity ? index->capacity * 2u : 256u;
        if (capacity > PROGRAM_STREAM_SEEK_MAX_ENTRIES)
            capacity = PROGRAM_STREAM_SEEK_MAX_ENTRIES;
        entries = realloc(index->entries, capacity * sizeof(*entries));
        if (!entries)
            return -1;
        index->entries = entries;
        index->capacity = capacity;
    }
    index->entries[index->count].pts_90k = pts_90k;
    index->entries[index->count].source_offset = source_offset;
    index->count++;
    return 1;
}

uint64_t program_stream_seek_target(uint64_t current_pts_90k,
                                    int delta_seconds)
{
    uint64_t delta;

    if (delta_seconds >= 0) {
        delta = (uint64_t)delta_seconds * 90000u;
        return current_pts_90k > UINT64_MAX - delta ? UINT64_MAX :
                                                     current_pts_90k + delta;
    }
    delta = (uint64_t)(-(int64_t)delta_seconds) * 90000u;
    return current_pts_90k > delta ? current_pts_90k - delta : 0;
}

int program_stream_seek_find(const struct program_stream_seek_index *index,
                             uint64_t target_pts_90k,
                             struct program_stream_seek_entry *entry)
{
    size_t low;
    size_t high;

    if (!index || !index->count || !entry)
        return 0;
    low = 0;
    high = index->count;
    while (low < high) {
        size_t middle = low + (high - low) / 2u;

        if (index->entries[middle].pts_90k <= target_pts_90k)
            low = middle + 1u;
        else
            high = middle;
    }
    *entry = index->entries[low ? low - 1u : 0u];
    return 1;
}
