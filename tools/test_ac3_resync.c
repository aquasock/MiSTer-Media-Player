#include "../host/arm/ac3_resync.h"

#include <stdio.h>

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "AC-3 resync: %s\n", message);
    return 1;
}

int main(void)
{
    int failed = 0;

    failed |= require(ac3_rate_candidate(48000, 48000, 0, 0) ==
                      AC3_RATE_CANDIDATE_ACCEPT,
                      "supported clean candidate was not accepted");
    failed |= require(ac3_rate_candidate(44100, 48000, 0, 0) ==
                      AC3_RATE_CANDIDATE_FATAL,
                      "clean unsupported stream was not rejected");
    failed |= require(ac3_rate_candidate(44100, 48000, 1, 0) ==
                      AC3_RATE_CANDIDATE_RECOVER,
                      "false rate after a skipped byte remained fatal");
    failed |= require(ac3_rate_candidate(44100, 48000, 0, 2) ==
                      AC3_RATE_CANDIDATE_RECOVER,
                      "false rate after rejected frames remained fatal");
    failed |= require(ac3_rate_candidate(48000, 48000, 6475, 6) ==
                      AC3_RATE_CANDIDATE_ACCEPT,
                      "supported recovery candidate was not accepted");

    if (failed)
        return 1;
    puts("AC-3 resync: clean-rate rejection and false-rate recovery pass");
    return 0;
}
