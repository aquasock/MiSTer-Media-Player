#include "audio_file_seek.h"

#include <limits.h>

uint64_t audio_file_seek_target(uint64_t current_frame,
                                uint64_t length_frames,
                                unsigned rate_hz,
                                int seconds)
{
    uint64_t magnitude;
    uint64_t delta;

    if (current_frame > length_frames)
        current_frame = length_frames;
    magnitude = seconds < 0 ? (uint64_t)(-(int64_t)seconds) :
                              (uint64_t)seconds;
    if (rate_hz && magnitude > UINT64_MAX / rate_hz)
        delta = UINT64_MAX;
    else
        delta = magnitude * rate_hz;
    if (seconds < 0)
        return delta >= current_frame ? 0 : current_frame - delta;
    /*
     * Reaching the exact end produces no PCM and ends the helper immediately.
     * Keep the current position instead so an oversized forward jump is a
     * genuine no-op rather than an apparent playback freeze.
     */
    if (delta >= length_frames - current_frame)
        return current_frame;
    return current_frame + delta;
}
