#ifndef MMP_DVD_RANDOM_ACCESS_H
#define MMP_DVD_RANDOM_ACCESS_H

#include <stddef.h>
#include <stdint.h>

struct dvd_random_access_result {
    size_t sequence_offset;
    size_t intra_offset;
    size_t next_reference_offset;
    unsigned pre_context_pictures;
    unsigned leading_b_pictures;
};

/*
 * Make the first independently decoded DVD video group begin with a sequence
 * header and an I reference. Return one when a complete group was filtered,
 * zero when more bytes are required, and minus one for invalid arguments.
 */
int dvd_random_access_filter(uint8_t *data, size_t size,
                             struct dvd_random_access_result *result);

#endif
