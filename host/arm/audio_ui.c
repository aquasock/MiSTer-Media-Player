#include "audio_ui.h"
#include "media_player_protocol.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define AUDIO_UI_Y_BYTES (AUDIO_UI_WIDTH * AUDIO_UI_HEIGHT)
#define AUDIO_UI_C_WIDTH (AUDIO_UI_WIDTH / 2u)
#define AUDIO_UI_C_HEIGHT (AUDIO_UI_HEIGHT / 2u)
#define AUDIO_UI_C_BYTES (AUDIO_UI_C_WIDTH * AUDIO_UI_C_HEIGHT)
#define AUDIO_UI_CHUNKS \
    ((AUDIO_UI_FRAME_BYTES + AUDIO_UI_DATA_BYTES - 1u) / AUDIO_UI_DATA_BYTES)

#define UI_BG_Y 16u
#define UI_PANEL_Y 30u
#define UI_PANEL_ALT_Y 38u
#define UI_TRACK_Y 42u
#define UI_ACCENT_Y 112u
#define UI_PROGRESS_Y 178u
#define UI_TEXT_Y 220u
#define UI_MUTED_Y 116u
#define UI_CB 128u
#define UI_CR 128u
#define UI_ACCENT_CB 146u
#define UI_ACCENT_CR 104u
#define UI_PROGRESS_CB 166u
#define UI_PROGRESS_CR 78u

enum audio_ui_state {
    AUDIO_UI_BEGIN,
    AUDIO_UI_DATA,
    AUDIO_UI_COMMIT
};

struct audio_ui {
    uint8_t *frame;
    size_t offset;
    unsigned chunk_index;
    unsigned sequence;
    unsigned rate_hz;
    uint64_t position_pcm_frames;
    uint64_t length_pcm_frames;
    uint64_t frame_start_pcm;
    int service_started;
    enum audio_ui_state state;
};

static void fill_rect(struct audio_ui *ui, unsigned x, unsigned y,
                      unsigned width, unsigned height,
                      uint8_t luma, uint8_t cb, uint8_t cr)
{
    uint8_t *plane_y = ui->frame;
    uint8_t *plane_cb = plane_y + AUDIO_UI_Y_BYTES;
    uint8_t *plane_cr = plane_cb + AUDIO_UI_C_BYTES;
    unsigned x2 = x + width;
    unsigned y2 = y + height;
    unsigned row;

    if (x >= AUDIO_UI_WIDTH || y >= AUDIO_UI_HEIGHT)
        return;
    if (x2 > AUDIO_UI_WIDTH)
        x2 = AUDIO_UI_WIDTH;
    if (y2 > AUDIO_UI_HEIGHT)
        y2 = AUDIO_UI_HEIGHT;
    for (row = y; row < y2; ++row)
        memset(plane_y + (size_t)row * AUDIO_UI_WIDTH + x, luma, x2 - x);
    for (row = y / 2u; row < (y2 + 1u) / 2u; ++row) {
        unsigned cx = x / 2u;
        unsigned cx2 = (x2 + 1u) / 2u;

        memset(plane_cb + (size_t)row * AUDIO_UI_C_WIDTH + cx, cb, cx2 - cx);
        memset(plane_cr + (size_t)row * AUDIO_UI_C_WIDTH + cx, cr, cx2 - cx);
    }
}

static void border_rect(struct audio_ui *ui, unsigned x, unsigned y,
                        unsigned width, unsigned height, unsigned thickness,
                        uint8_t luma, uint8_t cb, uint8_t cr)
{
    fill_rect(ui, x, y, width, thickness, luma, cb, cr);
    fill_rect(ui, x, y + height - thickness, width, thickness, luma, cb, cr);
    fill_rect(ui, x, y, thickness, height, luma, cb, cr);
    fill_rect(ui, x + width - thickness, y, thickness, height, luma, cb, cr);
}

struct audio_ui_glyph {
    char character;
    uint8_t rows[7];
};

static const struct audio_ui_glyph audio_ui_glyphs[] = {
    {'A', {14, 17, 17, 31, 17, 17, 17}},
    {'B', {30, 17, 17, 30, 17, 17, 30}},
    {'C', {14, 17, 16, 16, 16, 17, 14}},
    {'D', {30, 17, 17, 17, 17, 17, 30}},
    {'E', {31, 16, 16, 30, 16, 16, 31}},
    {'F', {31, 16, 16, 30, 16, 16, 16}},
    {'G', {14, 17, 16, 23, 17, 17, 15}},
    {'H', {17, 17, 17, 31, 17, 17, 17}},
    {'I', {31, 4, 4, 4, 4, 4, 31}},
    {'J', {7, 2, 2, 2, 18, 18, 12}},
    {'K', {17, 18, 20, 24, 20, 18, 17}},
    {'L', {16, 16, 16, 16, 16, 16, 31}},
    {'M', {17, 27, 21, 21, 17, 17, 17}},
    {'N', {17, 25, 21, 19, 17, 17, 17}},
    {'O', {14, 17, 17, 17, 17, 17, 14}},
    {'P', {30, 17, 17, 30, 16, 16, 16}},
    {'Q', {14, 17, 17, 17, 21, 18, 13}},
    {'R', {30, 17, 17, 30, 20, 18, 17}},
    {'S', {15, 16, 16, 14, 1, 1, 30}},
    {'T', {31, 4, 4, 4, 4, 4, 4}},
    {'U', {17, 17, 17, 17, 17, 17, 14}},
    {'V', {17, 17, 17, 17, 17, 10, 4}},
    {'W', {17, 17, 17, 21, 21, 21, 10}},
    {'X', {17, 17, 10, 4, 10, 17, 17}},
    {'Y', {17, 17, 10, 4, 4, 4, 4}},
    {'Z', {31, 1, 2, 4, 8, 16, 31}},
    {'0', {14, 17, 19, 21, 25, 17, 14}},
    {'1', {4, 12, 4, 4, 4, 4, 14}},
    {'2', {14, 17, 1, 2, 4, 8, 31}},
    {'3', {30, 1, 1, 14, 1, 1, 30}},
    {'4', {2, 6, 10, 18, 31, 2, 2}},
    {'5', {31, 16, 16, 30, 1, 1, 30}},
    {'6', {14, 16, 16, 30, 17, 17, 14}},
    {'7', {31, 1, 2, 4, 8, 8, 8}},
    {'8', {14, 17, 17, 14, 17, 17, 14}},
    {'9', {14, 17, 17, 15, 1, 1, 14}},
    {':', {0, 4, 4, 0, 4, 4, 0}},
    {'-', {0, 0, 0, 31, 0, 0, 0}},
    {'/', {1, 1, 2, 4, 8, 16, 16}}
};

static const uint8_t *glyph_rows(char character)
{
    size_t index;

    for (index = 0; index < sizeof(audio_ui_glyphs) /
                                 sizeof(audio_ui_glyphs[0]); ++index) {
        if (audio_ui_glyphs[index].character == character)
            return audio_ui_glyphs[index].rows;
    }
    return NULL;
}

static unsigned text_width(const char *text, unsigned scale)
{
    size_t length = strlen(text);

    return length ? (unsigned)(length * 6u - 1u) * scale : 0u;
}

static void draw_text(struct audio_ui *ui, unsigned x, unsigned y,
                      const char *text, unsigned scale, uint8_t luma)
{
    while (*text) {
        const uint8_t *rows = glyph_rows(*text);
        unsigned row;

        if (rows) {
            for (row = 0; row < 7u; ++row) {
                unsigned column;

                for (column = 0; column < 5u; ++column) {
                    if (rows[row] & (1u << (4u - column)))
                        fill_rect(ui, x + column * scale, y + row * scale,
                                  scale, scale, luma, UI_CB, UI_CR);
                }
            }
        }
        x += 6u * scale;
        ++text;
    }
}

static void draw_centered_text(struct audio_ui *ui, unsigned x, unsigned y,
                               unsigned width, const char *text,
                               unsigned scale, uint8_t luma)
{
    unsigned width_pixels = text_width(text, scale);

    draw_text(ui, x + (width > width_pixels ?
                      (width - width_pixels) / 2u : 0u),
              y, text, scale, luma);
}

static void draw_play(struct audio_ui *ui, unsigned x, unsigned y,
                      unsigned size, uint8_t luma, uint8_t cb, uint8_t cr)
{
    unsigned row;

    for (row = 0; row < size; ++row) {
        unsigned half = row < size / 2u ? row : size - row - 1u;
        unsigned width = 2u + half * 2u;

        fill_rect(ui, x, y + row, width, 1u, luma, cb, cr);
    }
}

static uint64_t projected_position(const struct audio_ui *ui,
                                   uint64_t position_pcm_frames)
{
    uint64_t remaining;

    if (!ui->length_pcm_frames)
        return position_pcm_frames;
    if (position_pcm_frames >= ui->length_pcm_frames)
        return ui->length_pcm_frames;
    remaining = ui->length_pcm_frames - position_pcm_frames;
    return position_pcm_frames +
           (remaining < ui->rate_hz ? remaining : ui->rate_hz);
}

static unsigned progress_width(const struct audio_ui *ui)
{
    const unsigned width = 652u;
    uint64_t quotient;
    uint64_t remainder;
    unsigned low = 0;
    unsigned high = width;

    if (!ui->length_pcm_frames)
        return 0;
    if (ui->position_pcm_frames >= ui->length_pcm_frames)
        return width;

    /*
     * Find floor(position * width / length) without overflowing either
     * 64-bit PCM-frame value.  ceil(length * pixel / width) is decomposed
     * before multiplication; pixel never exceeds width.
     */
    quotient = ui->length_pcm_frames / width;
    remainder = ui->length_pcm_frames % width;
    while (low < high) {
        unsigned pixel = (low + high + 1u) / 2u;
        uint64_t threshold = quotient * pixel +
            (remainder * pixel + width - 1u) / width;

        if (ui->position_pcm_frames >= threshold)
            low = pixel;
        else
            high = pixel - 1u;
    }
    return low;
}

static uint64_t rounded_up_seconds(uint64_t frames, unsigned rate_hz)
{
    uint64_t seconds;

    if (!frames || !rate_hz)
        return 0;
    seconds = frames / rate_hz;
    return seconds + (frames % rate_hz != 0u);
}

static void format_time(char *text, size_t size, uint64_t seconds)
{
    uint64_t minutes = seconds / 60u;

    (void)snprintf(text, size, "%02llu:%02llu",
                   (unsigned long long)minutes,
                   (unsigned long long)(seconds % 60u));
}

static void render_frame(struct audio_ui *ui)
{
    char elapsed[32];
    char total[32];
    char remaining[32];
    char elapsed_timing[64];
    char total_timing[64];
    char remaining_timing[64];
    unsigned filled_width = progress_width(ui);
    unsigned row;
    uint64_t elapsed_seconds = ui->rate_hz ?
        ui->position_pcm_frames / ui->rate_hz : 0;
    uint64_t remaining_frames =
        ui->length_pcm_frames > ui->position_pcm_frames ?
        ui->length_pcm_frames - ui->position_pcm_frames : 0;

    format_time(elapsed, sizeof(elapsed), elapsed_seconds);
    format_time(total, sizeof(total),
                rounded_up_seconds(ui->length_pcm_frames, ui->rate_hz));
    format_time(remaining, sizeof(remaining),
                rounded_up_seconds(remaining_frames, ui->rate_hz));
    (void)snprintf(elapsed_timing, sizeof(elapsed_timing),
                   "ELAPSED %s", elapsed);
    (void)snprintf(total_timing, sizeof(total_timing),
                   "TRACK %s", total);
    (void)snprintf(remaining_timing, sizeof(remaining_timing),
                   "REMAIN %s", remaining);

    /* Full 4:3 composition, inset for consumer-CRT overscan. */
    fill_rect(ui, 0, 0, AUDIO_UI_WIDTH, AUDIO_UI_HEIGHT,
              UI_BG_Y, UI_CB, UI_CR);

    /* Left column: square artwork and the three reserved tag fields. */
    /* 224x200 raster pixels is square at the 4:3 mode's 8:9 pixel aspect. */
    fill_rect(ui, 32, 24, 224, 200, UI_PANEL_Y, UI_CB, UI_CR);
    border_rect(ui, 32, 24, 224, 200, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_centered_text(ui, 32, 40, 224, "ALBUM ART", 2, UI_TEXT_Y);
    border_rect(ui, 48, 66, 192, 138, 2,
                UI_MUTED_Y, UI_CB, UI_CR);
    draw_centered_text(ui, 48, 124, 192, "ARTWORK", 2, UI_MUTED_Y);

    fill_rect(ui, 32, 236, 224, 116, UI_PANEL_Y, UI_CB, UI_CR);
    border_rect(ui, 32, 236, 224, 116, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_text(ui, 46, 250, "TITLE: ---", 2, UI_TEXT_Y);
    draw_text(ui, 46, 280, "ARTIST: ---", 2, UI_TEXT_Y);
    draw_text(ui, 46, 310, "ALBUM: ---", 2, UI_TEXT_Y);

    /* Right column: a static playlist reservation with one neutral selection. */
    fill_rect(ui, 272, 24, 416, 328, UI_PANEL_Y, UI_CB, UI_CR);
    border_rect(ui, 272, 24, 416, 328, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_text(ui, 288, 40, "CURRENT PLAYLIST", 2, UI_TEXT_Y);
    fill_rect(ui, 288, 64, 384, 2, UI_MUTED_Y, UI_CB, UI_CR);
    fill_rect(ui, 282, 76, 396, 34, UI_PANEL_ALT_Y, UI_CB, UI_CR);
    for (row = 0; row < 6u; ++row) {
        static const char *const tracks[] = {
            "01  TRACK TITLE", "02  TRACK TITLE", "03  TRACK TITLE",
            "04  TRACK TITLE", "05  TRACK TITLE", "06  TRACK TITLE"
        };
        unsigned y = 88u + row * 42u;

        draw_text(ui, 294, y, tracks[row], 2,
                  row ? UI_MUTED_Y : UI_TEXT_Y);
        if (row != 5u)
            fill_rect(ui, 288, y + 20u, 384, 1,
                      UI_TRACK_Y, UI_CB, UI_CR);
    }

    /* Transport plus the absolute track-relative time display. */
    fill_rect(ui, 210, 364, 94, 34, UI_PANEL_ALT_Y, UI_CB, UI_CR);
    border_rect(ui, 210, 364, 94, 34, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_centered_text(ui, 210, 378, 94, "PREVIOUS", 1, UI_TEXT_Y);

    fill_rect(ui, 316, 364, 112, 34, UI_PANEL_ALT_Y, UI_CB, UI_CR);
    border_rect(ui, 316, 364, 112, 34, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_play(ui, 326, 373, 16,
              UI_TEXT_Y, UI_CB, UI_CR);
    draw_centered_text(ui, 342, 378, 80, "PLAY/PAUSE", 1, UI_TEXT_Y);

    fill_rect(ui, 440, 364, 94, 34, UI_PANEL_ALT_Y, UI_CB, UI_CR);
    border_rect(ui, 440, 364, 94, 34, 2,
                UI_ACCENT_Y, UI_ACCENT_CB, UI_ACCENT_CR);
    draw_centered_text(ui, 440, 378, 94, "NEXT", 1, UI_TEXT_Y);

    draw_text(ui, 576, 378, "PLAYLIST --:--", 1, UI_MUTED_Y);
    draw_centered_text(ui, 32, 412, 218, elapsed_timing, 1, UI_TEXT_Y);
    draw_centered_text(ui, 250, 412, 220, total_timing, 1, UI_TEXT_Y);
    draw_centered_text(ui, 470, 412, 218, remaining_timing, 1, UI_TEXT_Y);

    /* Absolute decoder-frame position scaled across the track duration. */
    fill_rect(ui, 32, 438, 656, 14, UI_TRACK_Y, UI_CB, UI_CR);
    if (filled_width)
        fill_rect(ui, 34, 441, filled_width, 8,
                  UI_PROGRESS_Y, UI_PROGRESS_CB, UI_PROGRESS_CR);
}

int audio_ui_create(struct audio_ui **result)
{
    struct audio_ui *ui;

    if (!result)
        return -1;
    ui = calloc(1, sizeof(*ui));
    if (!ui)
        return -1;
    ui->frame = malloc(AUDIO_UI_FRAME_BYTES);
    if (!ui->frame) {
        free(ui);
        return -1;
    }
    ui->state = AUDIO_UI_BEGIN;
    render_frame(ui);
    *result = ui;
    return 0;
}

void audio_ui_destroy(struct audio_ui *ui)
{
    if (!ui)
        return;
    free(ui->frame);
    free(ui);
}

int audio_ui_set_track_length(struct audio_ui *ui,
                              uint64_t length_pcm_frames,
                              unsigned rate_hz)
{
    if (!ui || !length_pcm_frames ||
        (rate_hz != 44100u && rate_hz != 48000u) ||
        (ui->rate_hz && ui->rate_hz != rate_hz))
        return -1;
    ui->rate_hz = rate_hz;
    ui->length_pcm_frames = length_pcm_frames;
    ui->position_pcm_frames = projected_position(ui, 0);
    render_frame(ui);
    return 0;
}

int audio_ui_service(struct audio_ui *ui, uint64_t emitted_pcm_frames,
                     unsigned rate_hz, audio_ui_record_writer writer,
                     void *opaque)
{
    size_t count;
    uint64_t due;

    if (!ui || !writer || (rate_hz != 44100u && rate_hz != 48000u))
        return -1;
    if (!ui->rate_hz) {
        ui->rate_hz = rate_hz;
    } else if (ui->rate_hz != rate_hz) {
        return -1;
    }
    if (!ui->service_started) {
        ui->frame_start_pcm = emitted_pcm_frames;
        ui->service_started = 1;
    }

    if (ui->state == AUDIO_UI_BEGIN) {
        if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_BEGIN, NULL, 0) < 0)
            return -1;
        ui->state = AUDIO_UI_DATA;
        return 0;
    }
    if (ui->state == AUDIO_UI_COMMIT) {
        if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_COMMIT, NULL, 0) < 0)
            return -1;
        ui->sequence++;
        ui->position_pcm_frames =
            projected_position(ui, ui->position_pcm_frames);
        ui->offset = 0;
        ui->chunk_index = 0;
        ui->frame_start_pcm = emitted_pcm_frames;
        render_frame(ui);
        ui->state = AUDIO_UI_BEGIN;
        return 0;
    }

    due = ui->frame_start_pcm +
          ((uint64_t)(ui->chunk_index + 1u) * ui->rate_hz) /
          AUDIO_UI_CHUNKS;
    if (emitted_pcm_frames < due)
        return 0;
    count = AUDIO_UI_FRAME_BYTES - ui->offset;
    if (count > AUDIO_UI_DATA_BYTES)
        count = AUDIO_UI_DATA_BYTES;
    if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_DATA,
               ui->frame + ui->offset, count) < 0)
        return -1;
    ui->offset += count;
    ui->chunk_index++;
    if (ui->offset == AUDIO_UI_FRAME_BYTES)
        ui->state = AUDIO_UI_COMMIT;
    return 0;
}

int audio_ui_seek(struct audio_ui *ui, uint64_t emitted_pcm_frames,
                  unsigned rate_hz, uint64_t position_pcm_frames)
{
    if (!ui || (rate_hz != 44100u && rate_hz != 48000u))
        return -1;
    if (ui->rate_hz && ui->rate_hz != rate_hz)
        return -1;
    ui->rate_hz = rate_hz;
    ui->position_pcm_frames = projected_position(ui, position_pcm_frames);
    ui->frame_start_pcm = emitted_pcm_frames;
    ui->service_started = 1;
    ui->offset = 0;
    ui->chunk_index = 0;
    ui->state = AUDIO_UI_BEGIN;
    render_frame(ui);
    return 0;
}

int audio_ui_render_overlay(struct audio_ui *ui,
                            uint64_t position_pcm_frames,
                            uint8_t *packed_pixels, size_t size)
{
    size_t pixel;

    if (!ui || !packed_pixels || size != AUDIO_UI_OVERLAY_BYTES)
        return -1;
    ui->position_pcm_frames = projected_position(ui, position_pcm_frames);
    render_frame(ui);
    memset(packed_pixels, 0, size);
    for (pixel = 0; pixel < AUDIO_UI_WIDTH * AUDIO_UI_HEIGHT; ++pixel) {
        uint8_t y = ui->frame[pixel];
        unsigned index = y == UI_BG_Y ? 0u :
                         y <= UI_PANEL_ALT_Y ? 1u :
                         y <= UI_MUTED_Y ? 2u : 3u;
        unsigned shift = 6u - (unsigned)(pixel & 3u) * 2u;

        packed_pixels[pixel >> 2] |= (uint8_t)(index << shift);
    }
    return 0;
}

int audio_ui_complete(struct audio_ui *ui, uint64_t emitted_pcm_frames,
                      unsigned rate_hz, audio_ui_record_writer writer,
                      void *opaque)
{
    size_t count;

    if (!ui || !writer || !ui->length_pcm_frames ||
        (rate_hz != 44100u && rate_hz != 48000u) ||
        (ui->rate_hz && ui->rate_hz != rate_hz))
        return -1;
    ui->rate_hz = rate_hz;
    ui->frame_start_pcm = emitted_pcm_frames;
    ui->service_started = 1;
    if (ui->state == AUDIO_UI_BEGIN) {
        ui->position_pcm_frames = ui->length_pcm_frames;
        render_frame(ui);
        if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_BEGIN, NULL, 0) < 0)
            return -1;
        ui->state = AUDIO_UI_DATA;
    } else if (ui->position_pcm_frames != ui->length_pcm_frames) {
        /* A partially uploaded frame cannot be restarted without FPGA reset. */
        return -1;
    }
    while (ui->state == AUDIO_UI_DATA) {
        count = AUDIO_UI_FRAME_BYTES - ui->offset;
        if (count > AUDIO_UI_DATA_BYTES)
            count = AUDIO_UI_DATA_BYTES;
        if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_DATA,
                   ui->frame + ui->offset, count) < 0)
            return -1;
        ui->offset += count;
        ui->chunk_index++;
        if (ui->offset == AUDIO_UI_FRAME_BYTES)
            ui->state = AUDIO_UI_COMMIT;
    }
    if (ui->state != AUDIO_UI_COMMIT)
        return -1;
    if (writer(opaque, MEDIA_PLAYER_AUDIO_UI_COMMIT, NULL, 0) < 0)
        return -1;
    ui->sequence++;
    ui->position_pcm_frames = ui->length_pcm_frames;
    ui->offset = 0;
    ui->chunk_index = 0;
    ui->state = AUDIO_UI_BEGIN;
    return 0;
}

unsigned audio_ui_committed_frames(const struct audio_ui *ui)
{
    return ui ? ui->sequence : 0u;
}
