#include "../host/arm/dvd_random_access.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

enum {
    MPEG_PICTURE_I = 1,
    MPEG_PICTURE_P = 2,
    MPEG_PICTURE_B = 3,
};

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "dvd random access: %s\n", message);
    return 1;
}

static size_t put_start(uint8_t *data, size_t offset, uint8_t code,
                        uint8_t header_byte)
{
    data[offset++] = 0;
    data[offset++] = 0;
    data[offset++] = 1;
    data[offset++] = code;
    data[offset++] = 0;
    data[offset++] = header_byte;
    return offset;
}

static int is_start(const uint8_t *data, size_t offset, uint8_t code)
{
    return data[offset] == 0 && data[offset + 1u] == 0 &&
           data[offset + 2u] == 1 && data[offset + 3u] == code;
}

int main(void)
{
    uint8_t video[128];
    struct dvd_random_access_result result;
    size_t old_p;
    size_t sequence;
    size_t pre_i_p;
    size_t intra;
    size_t leading_b;
    size_t next_p;
    size_t size;
    int filtered;
    int failed = 0;

    memset(video, 0x55, sizeof(video));
    size = 3;
    old_p = size;
    size = put_start(video, size, 0x00, MPEG_PICTURE_P << 3);
    size = put_start(video, size, 0x01, 0xaa);
    sequence = size;
    size = put_start(video, size, 0xb3, 0x11);
    size = put_start(video, size, 0xb5, 0x22);
    pre_i_p = size;
    size = put_start(video, size, 0x00, MPEG_PICTURE_P << 3);
    size = put_start(video, size, 0x01, 0xbb);
    intra = size;
    size = put_start(video, size, 0x00, MPEG_PICTURE_I << 3);
    size = put_start(video, size, 0xb5, 0x33);
    size = put_start(video, size, 0x01, 0xcc);
    leading_b = size;
    size = put_start(video, size, 0x00, MPEG_PICTURE_B << 3);
    size = put_start(video, size, 0xb5, 0x44);
    size = put_start(video, size, 0x01, 0xdd);
    next_p = size;
    size = put_start(video, size, 0x00, MPEG_PICTURE_P << 3);

    filtered = dvd_random_access_filter(video, size, &result);
    failed |= require(filtered == 1, "complete restart group was not released");
    failed |= require(result.sequence_offset == sequence &&
                      result.intra_offset == intra &&
                      result.next_reference_offset == next_p,
                      "qualified sequence/I/P offsets were not retained");
    failed |= require(result.pre_context_pictures == 2 &&
                      result.leading_b_pictures == 1,
                      "discard counts do not identify contextless P and B pictures");
    failed |= require(is_start(video, old_p, 0xb2) &&
                      is_start(video, pre_i_p, 0xb2) &&
                      is_start(video, leading_b, 0xb2),
                      "contextless picture start codes remained visible");
    failed |= require(is_start(video, sequence, 0xb3) &&
                      is_start(video, intra, 0x00) &&
                      is_start(video, next_p, 0x00),
                      "independently decodable sequence/I/P context changed");

    memset(video, 0, sizeof(video));
    size = put_start(video, 0, 0xb3, 0x11);
    size = put_start(video, size, 0x00, MPEG_PICTURE_I << 3);
    filtered = dvd_random_access_filter(video, size, &result);
    failed |= require(filtered == 0,
                      "incomplete I-only group was released without a following reference");

    if (failed)
        return 1;
    puts("dvd random access: sequence context, intra restart and leading-B filtering pass");
    return 0;
}
