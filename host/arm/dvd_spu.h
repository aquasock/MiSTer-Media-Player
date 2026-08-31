#ifndef DVD_SPU_H
#define DVD_SPU_H

#include <stddef.h>
#include <stdint.h>

#define DVD_SPU_WIDTH 720u
#define DVD_SPU_HEIGHT 480u
#define DVD_SPU_PLANE_BYTES ((DVD_SPU_WIDTH * DVD_SPU_HEIGHT) / 4u)

struct dvd_spu_decoder;

struct dvd_spu_overlay {
    const uint8_t *pixels;
    uint8_t rgba[4][4];
    uint8_t highlight_rgba[4][4];
    uint16_t highlight_x1;
    uint16_t highlight_y1;
    uint16_t highlight_x2;
    uint16_t highlight_y2;
    int visible;
    int menu;
};

struct dvd_spu_decoder *dvd_spu_create(void);
void dvd_spu_destroy(struct dvd_spu_decoder *decoder);
void dvd_spu_reset(struct dvd_spu_decoder *decoder);
void dvd_spu_set_clut(struct dvd_spu_decoder *decoder,
                      const uint32_t clut[16]);
void dvd_spu_set_stream(struct dvd_spu_decoder *decoder, int physical_stream);
int dvd_spu_feed(struct dvd_spu_decoder *decoder, int physical_stream,
                 const uint8_t *data, size_t size);
int dvd_spu_set_highlight(struct dvd_spu_decoder *decoder, int display,
                          uint32_t palette, uint16_t x1, uint16_t y1,
                          uint16_t x2, uint16_t y2);
const struct dvd_spu_overlay *dvd_spu_overlay(
    const struct dvd_spu_decoder *decoder);
/* Count the four packed two-bit plane indices in the inclusive highlight. */
int dvd_spu_selected_histogram(const struct dvd_spu_overlay *overlay,
                               uint32_t histogram[4]);

#endif
