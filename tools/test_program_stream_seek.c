#include "../host/arm/program_stream_seek.h"

#include <stdint.h>
#include <stdio.h>

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "program stream seek: %s\n", message);
    return 1;
}

int main(void)
{
    struct program_stream_seek_index index = {0};
    struct program_stream_seek_entry entry;
    int failed = 0;

    failed |= require(program_stream_seek_record(&index, 90000u, 100) == 1,
                      "first timestamp was not indexed");
    failed |= require(program_stream_seek_record(&index, 100000u, 120) == 0,
                      "sub-half-second timestamp was indexed");
    failed |= require(program_stream_seek_record(&index, 135000u, 200) == 1,
                      "half-second timestamp was not indexed");
    failed |= require(program_stream_seek_record(&index, 120000u, 180) == 0,
                      "decode-order regression entered monotonic index");
    failed |= require(program_stream_seek_record(&index, 225000u, 400) == 1,
                      "later timestamp was not indexed");
    failed |= require(index.count == 3,
                      "unexpected sparse-index entry count");

    failed |= require(program_stream_seek_find(&index, 180000u, &entry) &&
                      entry.pts_90k == 135000u && entry.source_offset == 200,
                      "lookup did not select the last timestamp at/before target");
    failed |= require(program_stream_seek_find(&index, 0, &entry) &&
                      entry.pts_90k == 90000u && entry.source_offset == 100,
                      "lookup did not clamp to first indexed packet");
    failed |= require(program_stream_seek_find(&index, UINT64_MAX, &entry) &&
                      entry.pts_90k == 225000u && entry.source_offset == 400,
                      "lookup did not clamp to last indexed packet");

    failed |= require(program_stream_seek_target(900000u, -10) == 0,
                      "backward target did not clamp to zero");
    failed |= require(program_stream_seek_target(1800000u, -10) == 900000u,
                      "backward target arithmetic is wrong");
    failed |= require(program_stream_seek_target(1800000u, 60) == 7200000u,
                      "forward target arithmetic is wrong");
    failed |= require(program_stream_seek_target(UINT64_MAX - 10u, 300) ==
                          UINT64_MAX,
                      "forward target did not saturate");

    program_stream_seek_destroy(&index);
    failed |= require(!index.entries && !index.count && !index.capacity,
                      "destroy did not clear the index");
    if (failed)
        return 1;
    puts("program stream seek: sparse indexing, lookup and target clamps pass");
    return 0;
}
