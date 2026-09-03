#define _POSIX_C_SOURCE 200809L

#define dvdnav_current_title_info test_dvdnav_current_title_info
#define dvdnav_err_to_string test_dvdnav_err_to_string
#define dvdnav_next_pg_search test_dvdnav_next_pg_search
#define dvdnav_prev_pg_search test_dvdnav_prev_pg_search

/*
 * Include the production translation unit so this focused native test can
 * exercise the private DVD block-boundary transition without adding a test
 * ABI to the ARM helper.
 */
#include "../host/arm/media_source.c"

#undef dvdnav_current_title_info
#undef dvdnav_err_to_string
#undef dvdnav_next_pg_search
#undef dvdnav_prev_pg_search

#include <stdarg.h>
#include <unistd.h>

static dvdnav_status_t chapter_info_status = DVDNAV_STATUS_OK;
static dvdnav_status_t chapter_search_status = DVDNAV_STATUS_OK;
static int32_t chapter_title;
static int32_t chapter_part;
static unsigned chapter_info_calls;
static unsigned chapter_next_calls;
static unsigned chapter_previous_calls;
static unsigned chapter_error_calls;

dvdnav_status_t test_dvdnav_current_title_info(dvdnav_t *navigation,
                                                int32_t *title,
                                                int32_t *part)
{
    (void)navigation;
    chapter_info_calls++;
    *title = chapter_title;
    *part = chapter_part;
    return chapter_info_status;
}

dvdnav_status_t test_dvdnav_next_pg_search(dvdnav_t *navigation)
{
    (void)navigation;
    chapter_next_calls++;
    if (chapter_search_status == DVDNAV_STATUS_OK)
        chapter_part++;
    return chapter_search_status;
}

dvdnav_status_t test_dvdnav_prev_pg_search(dvdnav_t *navigation)
{
    (void)navigation;
    chapter_previous_calls++;
    if (chapter_search_status == DVDNAV_STATUS_OK)
        chapter_part--;
    return chapter_search_status;
}

const char *test_dvdnav_err_to_string(dvdnav_t *navigation)
{
    (void)navigation;
    chapter_error_calls++;
    return "simulated navigation failure";
}

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "dvd menu hop: %s\n", message);
    return 1;
}

static void invoke_navigation_log(const char *format, ...)
{
    va_list arguments;

    va_start(arguments, format);
    dvd_navigation_log(NULL, DVDNAV_LOGGER_LEVEL_INFO, format, arguments);
    va_end(arguments);
}

static int test_navigation_logger(void)
{
    int descriptors[2] = {-1, -1};
    int saved_stdout = -1;
    uint8_t unexpected;
    ssize_t count = -1;
    int failed = 0;

    if (pipe(descriptors) < 0) {
        fprintf(stderr, "dvd menu hop: logger pipe failed\n");
        return 1;
    }
    fflush(stdout);
    saved_stdout = dup(STDOUT_FILENO);
    if (saved_stdout < 0 || dup2(descriptors[1], STDOUT_FILENO) < 0) {
        fprintf(stderr, "dvd menu hop: logger capture failed\n");
        failed = 1;
        goto done;
    }
    close(descriptors[1]);
    descriptors[1] = -1;
    invoke_navigation_log("logger-route %d", 7);
    fflush(stdout);
    if (dup2(saved_stdout, STDOUT_FILENO) < 0) {
        fprintf(stderr, "dvd menu hop: logger restore failed\n");
        failed = 1;
        goto done;
    }
    close(saved_stdout);
    saved_stdout = -1;
    count = read(descriptors[0], &unexpected, sizeof(unexpected));
    failed |= require(count == 0,
                      "libdvdnav diagnostic reached media stdout");

done:
    if (saved_stdout >= 0) {
        (void)dup2(saved_stdout, STDOUT_FILENO);
        close(saved_stdout);
    }
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    close(descriptors[0]);
    return failed;
}

static void reset_chapter_navigation(int32_t title, int32_t part)
{
    chapter_info_status = DVDNAV_STATUS_OK;
    chapter_search_status = DVDNAV_STATUS_OK;
    chapter_title = title;
    chapter_part = part;
    chapter_info_calls = 0;
    chapter_next_calls = 0;
    chapter_previous_calls = 0;
    chapter_error_calls = 0;
}

static int test_chapter_navigation(void)
{
    struct iso_source_state state;
    int failed = 0;

    memset(&state, 0, sizeof(state));
    state.navigation = (dvdnav_t *)&state;
    state.title = 1;
    state.title_active = 1;
    state.title_part = 4;
    state.block_offset = 128;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.end_of_stream = 1;
    state.error = 1;
    state.still_active = 1;
    state.still_seconds = 7;
    state.menu_pci_valid = 1;
    reset_chapter_navigation(1, 4);
    failed |= require(iso_change_chapter(&state, -1) == 3,
                      "previous program did not resolve on the main title");
    failed |= require(chapter_previous_calls == 1 &&
                          chapter_next_calls == 0 && chapter_info_calls == 2,
                      "previous program used the wrong libdvdnav operation");
    failed |= require(state.title == 1 && !state.title_active &&
                          state.title_part == 0,
                      "chapter hop changed selected-title metadata");
    failed |= require(state.block_offset == 0 && state.block_size == 0 &&
                          !state.end_of_stream && !state.error &&
                          !state.still_active && state.still_seconds == 0 &&
                          !state.menu_pci_valid,
                      "successful previous program retained stale state");

    memset(&state, 0, sizeof(state));
    state.navigation = (dvdnav_t *)&state;
    state.title = 1;
    state.title_active = 1;
    state.title_part = 8;
    reset_chapter_navigation(7, 2);
    failed |= require(iso_change_chapter(&state, 1) == 3,
                      "next program rejected a menu-launched alternate title");
    failed |= require(chapter_next_calls == 1 &&
                          chapter_previous_calls == 0 &&
                          chapter_title == 7 && chapter_part == 3,
                      "alternate-title hop did not remain on the active VM path");
    failed |= require(state.title == 1 && !state.error,
                      "alternate-title hop replaced the inventoried main title");

    memset(&state, 0, sizeof(state));
    state.navigation = (dvdnav_t *)&state;
    state.title = 1;
    state.block_offset = 64;
    state.block_size = DVD_VIDEO_LB_LEN;
    state.menu_pci_valid = 1;
    reset_chapter_navigation(7, 9);
    chapter_search_status = DVDNAV_STATUS_ERR;
    failed |= require(iso_change_chapter(&state, 1) < 0,
                      "rejected next-program boundary was accepted");
    failed |= require(chapter_next_calls == 1 && chapter_error_calls == 1 &&
                          state.error && state.block_offset == 64 &&
                          state.block_size == DVD_VIDEO_LB_LEN,
                      "rejected chapter hop changed the source boundary");

    memset(&state, 0, sizeof(state));
    state.navigation = (dvdnav_t *)&state;
    state.title = 1;
    reset_chapter_navigation(0, 0);
    failed |= require(iso_change_chapter(&state, -1) < 0,
                      "menu-domain chapter request was accepted");
    failed |= require(!chapter_previous_calls && !chapter_next_calls &&
                          chapter_error_calls == 1 && state.error,
                      "menu-domain rejection called a program search");

    reset_chapter_navigation(1, 1);
    failed |= require(iso_change_chapter(&state, 0) < 0 &&
                          chapter_info_calls == 0 &&
                          chapter_previous_calls == 0 &&
                          chapter_next_calls == 0,
                      "invalid chapter direction reached libdvdnav");
    return failed;
}

int main(void)
{
    struct iso_source_state state;
    size_t discarded;
    int failed = test_navigation_logger();

    failed |= test_chapter_navigation();

    failed |= require(iso_menu_identity_is_root(0, DVD_MENU_Root),
                      "active root menu was not recognized");
    failed |= require(!iso_menu_identity_is_root(0, DVD_MENU_Audio),
                      "non-root submenu was suppressed");
    failed |= require(!iso_menu_identity_is_root(1, DVD_MENU_Root),
                      "title playback was mistaken for the root menu");

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
                          MEDIA_SOURCE_DVD_MENU_PENDING,
                      "ambiguous finite-still transition was acknowledged");
    failed |= require(!state.dvd_state.hop && state.still_active &&
                          state.still_seconds == 10 &&
                          state.block_offset == 256 &&
                          state.block_size == DVD_VIDEO_LB_LEN,
                      "ambiguous finite-still transition changed state");

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
    state.menu_pci.hli.btnit[1].auto_action_mode = 1;
    state.menu_pci.hli.btn_colit.btn_coli[0][0] = 0x12345678u;
    state.menu_pci.hli.btn_colit.btn_coli[0][1] = 0x87654321u;
    failed |= require(iso_complete_directional_selection(&state, 1) ==
                          MEDIA_SOURCE_DVD_MENU_CONTINUE,
                      "ordinary directional selection lacked an explicit "
                      "continuation decision");
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
    failed |= require(iso_menu_target_valid(&state.menu_pci, 2) &&
                          !iso_menu_target_valid(&state.menu_pci, 0) &&
                          !iso_menu_target_valid(&state.menu_pci, 3),
                      "authored directional target bounds changed");
    failed |= require(iso_menu_target_auto_action(&state.menu_pci, 2) &&
                          !iso_menu_target_auto_action(&state.menu_pci, 1) &&
                          !iso_menu_target_auto_action(&state.menu_pci, 3),
                      "authored directional auto-action was not classified");

    if (failed)
        return 1;
    puts("dvd menu hop: chapter and menu transition boundaries pass");
    return 0;
}
