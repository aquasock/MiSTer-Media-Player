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
    state.menu_pci_valid = 1;
    state.menu_pci.pci_gi.nv_pck_lbn = 1234u;
    discarded = iso_reset_after_menu_transition(&state, 1);

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
    failed |= require(!state.menu_pci_valid &&
                      state.menu_pci.pci_gi.nv_pck_lbn == 0,
                      "displayed NAV PCI survived the hop");

    memset(&state, 0, sizeof(state));
    state.block_offset = DVD_VIDEO_LB_LEN;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.menu_pci_valid = 1;
    discarded = iso_reset_after_menu_transition(&state, 1);
    failed |= require(discarded == 0,
                      "empty block boundary reported discarded bytes");
    failed |= require(state.block_offset == 0 && state.block_size == 0 &&
                      state.dvd_state.hop,
                      "empty block boundary did not complete the hop");
    failed |= require(!state.menu_pci_valid,
                      "empty-boundary hop retained displayed NAV PCI");

    memset(&state, 0, sizeof(state));
    state.block_offset = 1024;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.still_active = 1;
    state.still_seconds = 0xffu;
    state.menu_pci_valid = 1;
    discarded = iso_reset_after_menu_transition(&state, 0);
    failed |= require(discarded == 1024 && !state.dvd_state.hop,
                      "menu continuation incorrectly requested a stream hop");
    failed |= require(!state.still_active && !state.menu_pci_valid,
                      "menu continuation retained stale still or NAV state");

    memset(&state, 0, sizeof(state));
    state.block_offset = 256;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.still_active = 1;
    state.still_seconds = 10;
    failed |= require(iso_complete_delayed_menu_transition(&state, 1) ==
                          MEDIA_SOURCE_DVD_STREAM_HOP,
                      "finite-still title exit was not classified as a hop");
    failed |= require(state.dvd_state.hop && !state.still_active &&
                          state.block_offset == 0 && state.block_size == 0,
                      "finite-still title exit retained the old boundary");

    memset(&state, 0, sizeof(state));
    state.block_offset = 256;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.still_active = 1;
    state.still_seconds = 10;
    failed |= require(iso_complete_delayed_menu_transition(&state, 0) ==
                          MEDIA_SOURCE_DVD_MENU_CONTINUE,
                      "finite-still menu transition requested a hop");
    failed |= require(!state.dvd_state.hop && !state.still_active &&
                          state.block_offset == 0 && state.block_size == 0,
                      "finite-still menu continuation retained old state");

    memset(&state, 0, sizeof(state));
    state.block_offset = 128;
    state.block_size = DVD_VIDEO_LB_LEN;
    failed |= require(iso_complete_menu_pending(&state, "activate") ==
                          MEDIA_SOURCE_DVD_MENU_PENDING,
                      "menu activation did not enter the pending state");
    failed |= require(!state.dvd_state.hop && state.block_offset == 0 &&
                          state.block_size == 0,
                      "pending activation retained its old source boundary");

    memset(&state, 0, sizeof(state));
    state.menu_pci_valid = 1;
    state.menu_pci.hli.hl_gi.hli_ss = 1;
    state.menu_pci.hli.hl_gi.btn_ns = 2;
    state.menu_pci.hli.btnit[0].btn_coln = 1;
    state.menu_pci.hli.btnit[0].x_start = 10;
    state.menu_pci.hli.btnit[0].y_start = 20;
    state.menu_pci.hli.btnit[0].x_end = 30;
    state.menu_pci.hli.btnit[0].y_end = 40;
    state.menu_pci.hli.btnit[0].right = 2;
    state.menu_pci.hli.btn_colit.btn_coli[0][0] = 0x12345678u;
    state.menu_pci.hli.btn_colit.btn_coli[0][1] = 0x87654321u;
    iso_refresh_highlight(&state, 1, 1);
    failed |= require(state.dvd_state.highlight_display &&
                      state.dvd_state.highlight_palette == 0x12345678u,
                      "selected button used the activation palette");
    failed |= require(state.dvd_state.highlight_x1 == 10 &&
                      state.dvd_state.highlight_y1 == 20 &&
                      state.dvd_state.highlight_x2 == 30 &&
                      state.dvd_state.highlight_y2 == 40,
                      "retained NAV PCI highlight rectangle was not used");
    failed |= require(iso_menu_direction_target(
                          &state.menu_pci, 1,
                          MEDIA_SOURCE_DVD_MENU_RIGHT) == 2,
                      "authored directional target was not retained");

    if (failed)
        return 1;
    puts("dvd menu hop: immediate and delayed transition boundaries pass");
    return 0;
}
