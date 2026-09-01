#include "audio_ui.h"
#include "media_player_protocol.h"

#include <stdlib.h>
#include <string.h>

#define AUDIO_UI_Y_BYTES (AUDIO_UI_WIDTH * AUDIO_UI_HEIGHT)
#define AUDIO_UI_C_WIDTH (AUDIO_UI_WIDTH / 2u)
#define AUDIO_UI_C_HEIGHT (AUDIO_UI_HEIGHT / 2u)
#define AUDIO_UI_C_BYTES (AUDIO_UI_C_WIDTH * AUDIO_UI_C_HEIGHT)
#define AUDIO_UI_CHUNKS \
    ((AUDIO_UI_FRAME_BYTES + AUDIO_UI_DATA_BYTES - 1u) / AUDIO_UI_DATA_BYTES)

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
    uint64_t frame_start_pcm;
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

static void render_frame(struct audio_ui *ui)
{
    unsigned progress_width = (ui->sequence % 60u) * 300u / 59u;
    unsigned tick;

    fill_rect(ui, 0, 0, AUDIO_UI_WIDTH, AUDIO_UI_HEIGHT, 24, 138, 120);

    /* Reserved 280x280 album-art viewport. */
    fill_rect(ui, 40, 40, 280, 280, 38, 132, 124);
    border_rect(ui, 40, 40, 280, 280, 4, 112, 146, 104);
    border_rect(ui, 56, 56, 248, 248, 2, 64, 138, 116);

    /* Static transport/control panel. */
    fill_rect(ui, 360, 72, 320, 224, 34, 136, 120);
    border_rect(ui, 360, 72, 320, 224, 2, 76, 142, 108);
    fill_rect(ui, 438, 164, 8, 64, 164, 158, 86);
    draw_play(ui, 454, 164, 64, 190, 158, 82);
    fill_rect(ui, 574, 164, 8, 64, 164, 158, 86);
    draw_play(ui, 590, 164, 64, 190, 158, 82);

    /* One-minute sample-clock activity/progress ruler. */
    fill_rect(ui, 360, 356, 320, 28, 42, 134, 122);
    border_rect(ui, 360, 356, 320, 28, 2, 94, 146, 102);
    if (progress_width)
        fill_rect(ui, 370, 366, progress_width, 8, 178, 166, 78);
    for (tick = 0; tick <= 10; ++tick)
        fill_rect(ui, 370 + tick * 30u, 386, 2, 10,
                  tick <= (ui->sequence % 60u) / 6u ? 150 : 62,
                  tick <= (ui->sequence % 60u) / 6u ? 158 : 136,
                  tick <= (ui->sequence % 60u) / 6u ? 88 : 116);

    /* Reserved lower status strip for later metadata text. */
    fill_rect(ui, 40, 424, 640, 20, 36, 136, 120);
    border_rect(ui, 40, 424, 640, 20, 2, 70, 142, 108);
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
        ui->frame_start_pcm = emitted_pcm_frames;
    } else if (ui->rate_hz != rate_hz) {
        return -1;
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

unsigned audio_ui_committed_frames(const struct audio_ui *ui)
{
    return ui ? ui->sequence : 0u;
}
