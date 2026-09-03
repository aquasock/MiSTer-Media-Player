#include "dvd_random_access.h"

#include <limits.h>
#include <stdint.h>

#define MPEG_PICTURE_START 0x00u
#define MPEG_USER_DATA_START 0xb2u
#define MPEG_SEQUENCE_HEADER 0xb3u
#define MPEG_SEQUENCE_END 0xb7u

#define MPEG_PICTURE_I 1u
#define MPEG_PICTURE_P 2u
#define MPEG_PICTURE_B 3u

static int start_code_at(const uint8_t *data, size_t size, size_t offset)
{
    return offset + 3u < size && data[offset] == 0 &&
           data[offset + 1u] == 0 && data[offset + 2u] == 1;
}

static unsigned picture_coding_type(const uint8_t *data, size_t size,
                                    size_t offset)
{
    if (!start_code_at(data, size, offset) ||
        data[offset + 3u] != MPEG_PICTURE_START || offset + 5u >= size)
        return 0;
    return (data[offset + 5u] >> 3) & 7u;
}

static void neutralize_start_codes(uint8_t *data, size_t begin, size_t end)
{
    size_t i;

    for (i = begin; i + 3u < end; ++i) {
        if (data[i] == 0 && data[i + 1u] == 0 && data[i + 2u] == 1)
            data[i + 3u] = MPEG_USER_DATA_START;
    }
}

static int filter_group(uint8_t *data, size_t size,
                        struct dvd_random_access_result *result,
                        int terminal)
{
    size_t sequence_offset = SIZE_MAX;
    size_t intra_offset = SIZE_MAX;
    size_t next_reference_offset = SIZE_MAX;
    size_t i;
    unsigned pre_context_pictures = 0;
    unsigned leading_b_pictures = 0;

    if ((!data && size) || !result)
        return -1;
    *result = (struct dvd_random_access_result){0};

    /*
     * A sequence header is decoder context, not merely a nearby start code.
     * Restart the candidate whenever a later one appears and accept it only
     * after an I picture plus the next I/P reference bounds every open-GOP B
     * picture. A P picture before the I is pre-roll, not a helper fatal.
     */
    for (i = 0; i + 5u < size; ++i) {
        unsigned code;
        unsigned coding_type;

        if (!start_code_at(data, size, i))
            continue;
        code = data[i + 3u];
        if (code == MPEG_SEQUENCE_HEADER) {
            sequence_offset = i;
            intra_offset = SIZE_MAX;
            continue;
        }
        if (code == MPEG_SEQUENCE_END && intra_offset == SIZE_MAX) {
            sequence_offset = SIZE_MAX;
            continue;
        }
        if (code != MPEG_PICTURE_START || sequence_offset == SIZE_MAX)
            continue;
        coding_type = picture_coding_type(data, size, i);
        if (intra_offset == SIZE_MAX) {
            if (coding_type == MPEG_PICTURE_I)
                intra_offset = i;
            continue;
        }
        if (coding_type == MPEG_PICTURE_I || coding_type == MPEG_PICTURE_P) {
            next_reference_offset = i;
            break;
        }
    }
    if (intra_offset == SIZE_MAX ||
        (next_reference_offset == SIZE_MAX && !terminal))
        return 0;
    if (next_reference_offset == SIZE_MAX)
        next_reference_offset = size;

    for (i = 0; i < sequence_offset && i + 5u < size; ++i) {
        if (start_code_at(data, size, i) &&
            data[i + 3u] == MPEG_PICTURE_START)
            pre_context_pictures++;
    }
    neutralize_start_codes(data, 0, sequence_offset);

    /*
     * Preserve the qualifying sequence header, its extensions and the first
     * I picture. Pictures between that header and I are contextless pre-roll;
     * B pictures between the I and next reference need an older reference.
     * Converting every start code in each rejected picture to user data keeps
     * byte positions and queued timestamp records stable while hiding it from
     * the FPGA decoder.
     */
    for (i = sequence_offset; i < next_reference_offset;) {
        size_t end;
        unsigned coding_type;
        int discard;

        if (!start_code_at(data, size, i) ||
            data[i + 3u] != MPEG_PICTURE_START) {
            i++;
            continue;
        }
        coding_type = picture_coding_type(data, size, i);
        discard = i < intra_offset ||
                  (i > intra_offset && coding_type == MPEG_PICTURE_B);
        end = i + 4u;
        while (end < next_reference_offset) {
            if (start_code_at(data, size, end) &&
                (data[end + 3u] == MPEG_PICTURE_START ||
                 data[end + 3u] == MPEG_SEQUENCE_HEADER ||
                 data[end + 3u] == MPEG_SEQUENCE_END))
                break;
            end++;
        }
        if (discard) {
            neutralize_start_codes(data, i, end);
            if (i < intra_offset)
                pre_context_pictures++;
            else
                leading_b_pictures++;
        }
        i = end;
    }

    result->sequence_offset = sequence_offset;
    result->intra_offset = intra_offset;
    result->next_reference_offset = next_reference_offset;
    result->pre_context_pictures = pre_context_pictures;
    result->leading_b_pictures = leading_b_pictures;
    return 1;
}

int dvd_random_access_filter(uint8_t *data, size_t size,
                             struct dvd_random_access_result *result)
{
    return filter_group(data, size, result, 0);
}

int dvd_random_access_filter_terminal(
    uint8_t *data, size_t size, struct dvd_random_access_result *result)
{
    return filter_group(data, size, result, 1);
}
