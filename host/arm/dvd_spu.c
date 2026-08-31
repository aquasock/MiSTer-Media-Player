#include "dvd_spu.h"

#include <stdlib.h>
#include <string.h>

#define DVD_SPU_PACKET_LIMIT 65535u

struct dvd_spu_decoder {
    uint8_t packet[DVD_SPU_PACKET_LIMIT];
    size_t packet_size;
    size_t expected_size;
    uint32_t clut[16];
    int physical_stream;
    uint8_t pixels[DVD_SPU_PLANE_BYTES];
    uint8_t color_map[4];
    uint8_t alpha[4];
    struct dvd_spu_overlay overlay;
};

static uint16_t read_be16(const uint8_t *data)
{
    return (uint16_t)(((uint16_t)data[0] << 8) | data[1]);
}

static uint8_t clip_byte(int value)
{
    if (value < 0)
        return 0;
    if (value > 255)
        return 255;
    return (uint8_t)value;
}

static void clut_to_rgba(uint32_t value, uint8_t alpha,
                         uint8_t rgba[4])
{
    int y = (int)((value >> 16) & 0xffu) - 16;
    int cr = (int)((value >> 8) & 0xffu) - 128;
    int cb = (int)(value & 0xffu) - 128;

    if (y < 0)
        y = 0;
    rgba[0] = clip_byte((298 * y + 409 * cr + 128) >> 8);
    rgba[1] = clip_byte((298 * y - 100 * cb - 208 * cr + 128) >> 8);
    rgba[2] = clip_byte((298 * y + 516 * cb + 128) >> 8);
    rgba[3] = (uint8_t)(alpha * 17u);
}

static void refresh_normal_palette(struct dvd_spu_decoder *decoder)
{
    unsigned index;

    for (index = 0; index < 4; ++index)
        clut_to_rgba(decoder->clut[decoder->color_map[index] & 15u],
                     decoder->alpha[index] & 15u,
                     decoder->overlay.rgba[index]);
}

static void reset_highlight(struct dvd_spu_decoder *decoder)
{
    memcpy(decoder->overlay.highlight_rgba, decoder->overlay.rgba,
           sizeof(decoder->overlay.rgba));
    decoder->overlay.highlight_x1 = 0;
    decoder->overlay.highlight_y1 = 0;
    decoder->overlay.highlight_x2 = 0;
    decoder->overlay.highlight_y2 = 0;
}

static int read_nibble(const uint8_t *packet, size_t packet_size,
                       size_t *nibble_offset, unsigned *value)
{
    size_t byte_offset = *nibble_offset >> 1;

    if (byte_offset >= packet_size)
        return -1;
    *value = (*nibble_offset & 1u) ? packet[byte_offset] & 15u :
                                     packet[byte_offset] >> 4;
    (*nibble_offset)++;
    return 0;
}

static void set_pixel(struct dvd_spu_decoder *decoder,
                      unsigned x, unsigned y, unsigned value)
{
    size_t pixel = (size_t)y * DVD_SPU_WIDTH + x;
    unsigned shift = (unsigned)(3u - (pixel & 3u)) * 2u;
    uint8_t mask = (uint8_t)(3u << shift);

    decoder->pixels[pixel >> 2] =
        (uint8_t)((decoder->pixels[pixel >> 2] & ~mask) |
                  ((value & 3u) << shift));
}

static int decode_field(struct dvd_spu_decoder *decoder,
                        const uint8_t *packet, size_t packet_size,
                        unsigned offset, unsigned x1, unsigned y1,
                        unsigned x2, unsigned y2, unsigned field)
{
    size_t nibble_offset = (size_t)offset * 2u;
    unsigned y;

    for (y = y1 + field; y <= y2; y += 2u) {
        unsigned x = x1;

        while (x <= x2) {
            unsigned code;
            unsigned nibble;
            unsigned run;
            unsigned remaining = x2 - x + 1u;
            unsigned i;

            if (read_nibble(packet, packet_size, &nibble_offset, &code) < 0)
                return -1;
            if (code < 4u) {
                if (read_nibble(packet, packet_size, &nibble_offset,
                                &nibble) < 0)
                    return -1;
                code = (code << 4) | nibble;
                if (code < 16u) {
                    if (read_nibble(packet, packet_size, &nibble_offset,
                                    &nibble) < 0)
                        return -1;
                    code = (code << 4) | nibble;
                    if (code < 64u) {
                        if (read_nibble(packet, packet_size, &nibble_offset,
                                        &nibble) < 0)
                            return -1;
                        code = (code << 4) | nibble;
                    }
                }
            }
            if (code < 4u)
                code |= remaining << 2;
            run = code >> 2;
            if (!run || run > remaining)
                return -1;
            for (i = 0; i < run; ++i)
                set_pixel(decoder, x + i, y, code & 3u);
            x += run;
        }
        if (nibble_offset & 1u)
            nibble_offset++;
    }
    return 0;
}

static int decode_packet(struct dvd_spu_decoder *decoder,
                         const uint8_t *packet, size_t packet_size)
{
    size_t command_offset;
    size_t next_offset;
    unsigned sequence_count = 0;
    unsigned x1 = 0, y1 = 0, x2 = 0, y2 = 0;
    unsigned field_offset[2] = {0, 0};
    int have_area = 0;
    int have_offsets = 0;
    int display_seen = 0;
    int menu = 0;

    if (packet_size < 8u || read_be16(packet) != packet_size)
        return -1;
    command_offset = read_be16(packet + 2);
    if (command_offset < 4u || command_offset + 4u > packet_size)
        return -1;
    memset(decoder->pixels, 0, sizeof(decoder->pixels));

    do {
        size_t position;
        int ended = 0;

        if (++sequence_count > 64u || command_offset + 4u > packet_size)
            return -1;
        next_offset = read_be16(packet + command_offset + 2u);
        position = command_offset + 4u;
        while (position < packet_size && !ended) {
            unsigned command = packet[position++];

            switch (command) {
            case 0x00:
                menu = 1;
                decoder->overlay.visible = 1;
                display_seen = 1;
                break;
            case 0x01:
                decoder->overlay.visible = 1;
                display_seen = 1;
                break;
            case 0x02:
                decoder->overlay.visible = 0;
                display_seen = 1;
                break;
            case 0x03: {
                uint16_t map;
                unsigned i;
                if (position + 2u > packet_size)
                    return -1;
                map = read_be16(packet + position);
                position += 2u;
                for (i = 0; i < 4u; ++i)
                    decoder->color_map[i] = (uint8_t)((map >> (i * 4u)) & 15u);
                break;
            }
            case 0x04: {
                uint16_t alpha;
                unsigned i;
                if (position + 2u > packet_size)
                    return -1;
                alpha = read_be16(packet + position);
                position += 2u;
                for (i = 0; i < 4u; ++i)
                    decoder->alpha[i] = (uint8_t)((alpha >> (i * 4u)) & 15u);
                break;
            }
            case 0x05:
                if (position + 6u > packet_size)
                    return -1;
                x1 = ((unsigned)packet[position] << 4) |
                     (packet[position + 1u] >> 4);
                x2 = ((unsigned)(packet[position + 1u] & 15u) << 8) |
                     packet[position + 2u];
                y1 = ((unsigned)packet[position + 3u] << 4) |
                     (packet[position + 4u] >> 4);
                y2 = ((unsigned)(packet[position + 4u] & 15u) << 8) |
                     packet[position + 5u];
                position += 6u;
                if (x1 > x2 || y1 > y2 || x2 >= DVD_SPU_WIDTH ||
                    y2 >= DVD_SPU_HEIGHT)
                    return -1;
                have_area = 1;
                break;
            case 0x06:
                if (position + 4u > packet_size)
                    return -1;
                field_offset[0] = read_be16(packet + position);
                field_offset[1] = read_be16(packet + position + 2u);
                position += 4u;
                have_offsets = 1;
                break;
            case 0xff:
                ended = 1;
                break;
            default:
                return -1;
            }
        }
        if (!ended)
            return -1;
        if (next_offset == command_offset)
            break;
        if (next_offset <= command_offset || next_offset >= packet_size)
            return -1;
        command_offset = next_offset;
    } while (1);

    if (!have_area || !have_offsets ||
        field_offset[0] >= packet_size || field_offset[1] >= packet_size)
        return -1;
    if (decode_field(decoder, packet, packet_size, field_offset[0],
                     x1, y1, x2, y2, 0) < 0 ||
        decode_field(decoder, packet, packet_size, field_offset[1],
                     x1, y1, x2, y2, 1) < 0)
        return -1;

    decoder->overlay.menu = menu;
    if (!display_seen)
        decoder->overlay.visible = 1;
    refresh_normal_palette(decoder);
    reset_highlight(decoder);
    return 1;
}

struct dvd_spu_decoder *dvd_spu_create(void)
{
    struct dvd_spu_decoder *decoder = calloc(1, sizeof(*decoder));
    unsigned i;

    if (!decoder)
        return NULL;
    decoder->physical_stream = -1;
    decoder->overlay.pixels = decoder->pixels;
    for (i = 0; i < 16u; ++i)
        decoder->clut[i] = 0x00108080u;
    decoder->color_map[0] = 0;
    decoder->color_map[1] = 1;
    decoder->color_map[2] = 2;
    decoder->color_map[3] = 3;
    refresh_normal_palette(decoder);
    reset_highlight(decoder);
    return decoder;
}

void dvd_spu_destroy(struct dvd_spu_decoder *decoder)
{
    free(decoder);
}

void dvd_spu_reset(struct dvd_spu_decoder *decoder)
{
    if (!decoder)
        return;
    decoder->packet_size = 0;
    decoder->expected_size = 0;
    decoder->overlay.visible = 0;
    decoder->overlay.menu = 0;
    memset(decoder->pixels, 0, sizeof(decoder->pixels));
    reset_highlight(decoder);
}

void dvd_spu_set_clut(struct dvd_spu_decoder *decoder,
                      const uint32_t clut[16])
{
    if (!decoder || !clut)
        return;
    memcpy(decoder->clut, clut, sizeof(decoder->clut));
    refresh_normal_palette(decoder);
}

void dvd_spu_set_stream(struct dvd_spu_decoder *decoder, int physical_stream)
{
    if (!decoder || decoder->physical_stream == physical_stream)
        return;
    decoder->physical_stream = physical_stream;
    decoder->packet_size = 0;
    decoder->expected_size = 0;
    decoder->overlay.visible = 0;
}

int dvd_spu_feed(struct dvd_spu_decoder *decoder, int physical_stream,
                 const uint8_t *data, size_t size)
{
    int updated = 0;

    if (!decoder || (!data && size) || physical_stream < 0 ||
        physical_stream != decoder->physical_stream)
        return 0;
    while (size) {
        size_t room = sizeof(decoder->packet) - decoder->packet_size;
        size_t count = size < room ? size : room;

        if (!room)
            return -1;
        memcpy(decoder->packet + decoder->packet_size, data, count);
        decoder->packet_size += count;
        data += count;
        size -= count;
        if (!decoder->expected_size && decoder->packet_size >= 2u) {
            decoder->expected_size = read_be16(decoder->packet);
            if (decoder->expected_size < 8u ||
                decoder->expected_size > sizeof(decoder->packet))
                return -1;
        }
        while (decoder->expected_size &&
               decoder->packet_size >= decoder->expected_size) {
            size_t remaining = decoder->packet_size - decoder->expected_size;
            int result = decode_packet(decoder, decoder->packet,
                                       decoder->expected_size);

            if (result < 0)
                return -1;
            updated |= result;
            memmove(decoder->packet,
                    decoder->packet + decoder->expected_size, remaining);
            decoder->packet_size = remaining;
            decoder->expected_size = remaining >= 2u ?
                read_be16(decoder->packet) : 0u;
            if (decoder->expected_size &&
                (decoder->expected_size < 8u ||
                 decoder->expected_size > sizeof(decoder->packet)))
                return -1;
        }
    }
    return updated;
}

int dvd_spu_set_highlight(struct dvd_spu_decoder *decoder, int display,
                          uint32_t palette, uint16_t x1, uint16_t y1,
                          uint16_t x2, uint16_t y2)
{
    unsigned i;

    if (!decoder || x1 > x2 || y1 > y2 || x2 >= DVD_SPU_WIDTH ||
        y2 >= DVD_SPU_HEIGHT)
        return -1;
    reset_highlight(decoder);
    if (!display)
        return 0;
    /*
     * libdvdnav's displayed-button state is synchronized to the active NAV
     * packet.  Some authored menu SPUs contain a later timed stop command;
     * this decoder has no SPU clock and therefore sees that stop immediately.
     * A displayed button is authoritative evidence that the menu plane must
     * still be composited.
     */
    decoder->overlay.visible = 1;
    decoder->overlay.menu = 1;
    for (i = 0; i < 4u; ++i) {
        unsigned color = (palette >> (16u + i * 4u)) & 15u;
        unsigned alpha = (palette >> (i * 4u)) & 15u;
        clut_to_rgba(decoder->clut[color], (uint8_t)alpha,
                     decoder->overlay.highlight_rgba[i]);
    }
    decoder->overlay.highlight_x1 = x1;
    decoder->overlay.highlight_y1 = y1;
    decoder->overlay.highlight_x2 = x2;
    decoder->overlay.highlight_y2 = y2;
    return 1;
}

const struct dvd_spu_overlay *dvd_spu_overlay(
    const struct dvd_spu_decoder *decoder)
{
    return decoder ? &decoder->overlay : NULL;
}

int dvd_spu_selected_histogram(const struct dvd_spu_overlay *overlay,
                               uint32_t histogram[4])
{
    unsigned x;
    unsigned y;

    if (!overlay || !overlay->pixels || !histogram ||
        overlay->highlight_x1 > overlay->highlight_x2 ||
        overlay->highlight_y1 > overlay->highlight_y2 ||
        overlay->highlight_x2 >= DVD_SPU_WIDTH ||
        overlay->highlight_y2 >= DVD_SPU_HEIGHT)
        return -1;
    memset(histogram, 0, 4u * sizeof(*histogram));
    for (y = overlay->highlight_y1; y <= overlay->highlight_y2; ++y) {
        for (x = overlay->highlight_x1; x <= overlay->highlight_x2; ++x) {
            size_t pixel = (size_t)y * DVD_SPU_WIDTH + x;
            unsigned shift = (3u - (unsigned)(pixel & 3u)) * 2u;
            unsigned index = (overlay->pixels[pixel >> 2] >> shift) & 3u;

            histogram[index]++;
        }
    }
    return 0;
}
