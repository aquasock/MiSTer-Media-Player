#ifndef AC3_RESYNC_H
#define AC3_RESYNC_H

#include <stddef.h>

enum ac3_rate_candidate_result {
    AC3_RATE_CANDIDATE_FATAL = -1,
    AC3_RATE_CANDIDATE_ACCEPT = 0,
    AC3_RATE_CANDIDATE_RECOVER = 1
};

/*
 * A clean first header defines the stream rate and must fail explicitly when
 * the sink cannot represent it.  Once bytewise recovery has begun, however,
 * syncinfo has only found another candidate inside damaged or partial data;
 * an unexpected rate rejects that candidate rather than redefining the track.
 */
static inline enum ac3_rate_candidate_result ac3_rate_candidate(
    int sample_rate, int supported_rate, size_t skipped_bytes,
    unsigned rejected_candidates)
{
    if (sample_rate == supported_rate)
        return AC3_RATE_CANDIDATE_ACCEPT;
    if (skipped_bytes || rejected_candidates)
        return AC3_RATE_CANDIDATE_RECOVER;
    return AC3_RATE_CANDIDATE_FATAL;
}

#endif
