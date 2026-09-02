#include "../host/arm/audio_file_seek.h"

#include <stdint.h>
#include <stdio.h>

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "audio file seek: %s\n", message);
    return 1;
}

int main(void)
{
    const uint64_t length = 600u * 48000u;
    int failed = 0;

    failed |= require(audio_file_seek_target(120u * 48000u, length,
                                              48000u, -10) ==
                      110u * 48000u, "ten-second backward target");
    failed |= require(audio_file_seek_target(120u * 48000u, length,
                                              48000u, 10) ==
                      130u * 48000u, "ten-second forward target");
    failed |= require(audio_file_seek_target(120u * 48000u, length,
                                              48000u, -60) ==
                      60u * 48000u, "one-minute backward target");
    failed |= require(audio_file_seek_target(120u * 48000u, length,
                                              48000u, 60) ==
                      180u * 48000u, "one-minute forward target");
    failed |= require(audio_file_seek_target(120u * 48000u, length,
                                              48000u, -300) == 0,
                      "five-minute beginning clamp");
    failed |= require(audio_file_seek_target(500u * 48000u, length,
                                              48000u, 300) ==
                      500u * 48000u,
                      "five-minute end overshoot no-op");
    failed |= require(audio_file_seek_target(540u * 48000u, length,
                                              48000u, 60) ==
                      540u * 48000u,
                      "exact-end forward seek no-op");
    failed |= require(audio_file_seek_target(599u * 48000u, length,
                                              48000u, 10) ==
                      599u * 48000u,
                      "past-end forward seek no-op");
    failed |= require(audio_file_seek_target(UINT64_MAX, UINT64_MAX,
                                              UINT32_MAX, INT32_MAX) ==
                      UINT64_MAX, "overflow-safe end clamp");
    failed |= require(audio_file_seek_target(100, 50, 48000u, -10) == 0,
                      "out-of-range current position clamp");
    if (failed)
        return 1;
    puts("audio file seek: fixed targets and boundary no-ops pass");
    return 0;
}
