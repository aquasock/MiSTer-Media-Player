#define _POSIX_C_SOURCE 200809L

/*
 * Include the production translation unit so this focused native test can
 * exercise the private DVD block-boundary transition without adding a test
 * ABI to the ARM helper.
 */
#include "../host/arm/media_source.c"

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "dvd menu hop: %s\n", message);
    return 1;
}

int main(void)
{
    struct iso_source_state state;
    size_t discarded;
    int failed = 0;

    memset(&state, 0, sizeof(state));
    state.block_offset = 513;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.end_of_stream = 1;
    state.error = 1;
    state.still_active = 1;
    state.still_seconds = 0xffu;
    discarded = iso_reset_after_menu_hop(&state);

    failed |= require(discarded == DVD_VIDEO_LB_LEN - 513u,
                      "unread block-tail count was not preserved");
    failed |= require(state.block_offset == 0 && state.block_size == 0,
                      "old navigation block remained readable");
    failed |= require(!state.end_of_stream && !state.error,
                      "terminal state survived the hop");
    failed |= require(!state.still_active && state.still_seconds == 0,
                      "still state survived the hop");
    failed |= require(state.dvd_state.hop,
                      "hop notification was not retained");

    memset(&state, 0, sizeof(state));
    state.block_offset = DVD_VIDEO_LB_LEN;
    state.block_size = DVD_VIDEO_LB_LEN;
    discarded = iso_reset_after_menu_hop(&state);
    failed |= require(discarded == 0,
                      "empty block boundary reported discarded bytes");
    failed |= require(state.block_offset == 0 && state.block_size == 0 &&
                      state.dvd_state.hop,
                      "empty block boundary did not complete the hop");

    if (failed)
        return 1;
    puts("dvd menu hop: stale block tail and empty boundary pass");
    return 0;
}
