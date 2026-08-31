#include "dvd_spu.h"

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

static unsigned pixel_at(const struct dvd_spu_overlay *overlay,
                         unsigned x, unsigned y)
{
    size_t pixel = (size_t)y * DVD_SPU_WIDTH + x;
    unsigned shift = (3u - (unsigned)(pixel & 3u)) * 2u;

    return (overlay->pixels[pixel >> 2] >> shift) & 3u;
}

int main(void)
{
    /* Two 2-pixel field rows followed by one self-terminating control set. */
    static const uint8_t packet[] = {
        0x00,0x1e, 0x00,0x06, 0x90,0xa0,
        0x00,0x00, 0x00,0x06,
        0x00,
        0x03,0x32,0x10,
        0x04,0xff,0xf0,
        0x05,0x00,0xa0,0x0b,0x01,0x40,0x15,
        0x06,0x00,0x04,0x00,0x05,
        0xff
    };
    static const uint8_t malformed[] = {
        0x00,0x08,0x00,0x04,0x00,0x00,0x00,0x04
    };
    static const uint8_t scheduled_stop[] = {
        0x00,0x24, 0x00,0x06, 0x90,0xa0,
        0x00,0x00, 0x00,0x1e,
        0x00,
        0x03,0x32,0x10,
        0x04,0xff,0xf0,
        0x05,0x00,0xa0,0x0b,0x01,0x40,0x15,
        0x06,0x00,0x04,0x00,0x05,
        0xff,
        0x00,0x01, 0x00,0x1e, 0x02,0xff
    };
    uint32_t clut[16] = {0};
    struct dvd_spu_decoder *decoder = dvd_spu_create();
    const struct dvd_spu_overlay *overlay;
    struct dvd_spu_overlay invalid_overlay;
    uint32_t histogram[4];
    size_t i;

    assert(decoder);
    clut[0] = 0x00108080u;
    clut[1] = 0x00eb8080u;
    clut[2] = 0x00108080u;
    clut[3] = 0x00808080u;
    dvd_spu_set_clut(decoder, clut);
    dvd_spu_set_stream(decoder, 0);

    assert(dvd_spu_feed(decoder, 1, packet, sizeof(packet)) == 0);
    for (i = 0; i < sizeof(packet); ++i) {
        int result = dvd_spu_feed(decoder, 0, packet + i, 1);
        int expected = i + 1 == sizeof(packet) ? 1 : 0;

        if (result != expected)
            fprintf(stderr, "fragment %zu returned %d, expected %d\n",
                    i, result, expected);
        assert(result == expected);
    }

    overlay = dvd_spu_overlay(decoder);
    assert(overlay && overlay->visible && overlay->menu);
    assert(pixel_at(overlay, 10, 20) == 1);
    assert(pixel_at(overlay, 11, 20) == 1);
    assert(pixel_at(overlay, 10, 21) == 2);
    assert(pixel_at(overlay, 11, 21) == 2);
    assert(pixel_at(overlay, 9, 20) == 0);
    assert(overlay->rgba[1][0] == 255 && overlay->rgba[1][1] == 255 &&
           overlay->rgba[1][2] == 255 && overlay->rgba[1][3] == 255);
    assert(overlay->rgba[0][3] == 0);

    assert(dvd_spu_set_highlight(decoder, 1,
                                 (uint32_t)2u << 20 | (uint32_t)8u << 4,
                                 10,20,11,21) == 1);
    assert(overlay->highlight_x1 == 10 && overlay->highlight_y1 == 20 &&
           overlay->highlight_x2 == 11 && overlay->highlight_y2 == 21);
    assert(overlay->highlight_rgba[1][0] == 0 &&
           overlay->highlight_rgba[1][3] == 136);
    assert(dvd_spu_selected_histogram(overlay, histogram) == 0);
    assert(histogram[0] == 0 && histogram[1] == 2 &&
           histogram[2] == 2 && histogram[3] == 0);
    invalid_overlay = *overlay;
    invalid_overlay.highlight_x2 = DVD_SPU_WIDTH;
    assert(dvd_spu_selected_histogram(&invalid_overlay, histogram) == -1);
    assert(dvd_spu_selected_histogram(NULL, histogram) == -1);
    assert(dvd_spu_selected_histogram(overlay, NULL) == -1);

    dvd_spu_reset(decoder);
    dvd_spu_set_stream(decoder, 0);
    assert(dvd_spu_feed(decoder, 0, scheduled_stop,
                        sizeof(scheduled_stop)) == 1);
    assert(!overlay->visible && overlay->menu);
    assert(pixel_at(overlay, 10, 20) == 1);
    assert(dvd_spu_set_highlight(decoder, 1,
                                 (uint32_t)2u << 20 | (uint32_t)8u << 4,
                                 10,20,11,21) == 1);
    assert(overlay->visible && overlay->menu);
    assert(pixel_at(overlay, 10, 20) == 1);
    assert(dvd_spu_selected_histogram(overlay, histogram) == 0);
    assert(histogram[0] == 0 && histogram[1] == 2 &&
           histogram[2] == 2 && histogram[3] == 0);

    dvd_spu_reset(decoder);
    dvd_spu_set_stream(decoder, 0);
    assert(dvd_spu_feed(decoder, 0, malformed, sizeof(malformed)) == -1);
    dvd_spu_destroy(decoder);
    puts("dvd_spu: fragmented decode, palette, selected histogram, scheduled stop, visible highlight and rejection pass");
    return 0;
}
