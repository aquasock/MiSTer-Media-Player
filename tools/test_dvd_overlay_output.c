#define main media_player_helper_program_main
#include "../host/arm/media_player_helper.c"
#undef main

#include <stdio.h>
#include <string.h>

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "DVD overlay output: %s\n", message);
    return 1;
}

int main(void)
{
    struct dvd_spu_overlay overlay = {0};
    struct output_state output = {0};
    uint8_t pixels[DVD_SPU_PLANE_BYTES];
    uint8_t reconstructed[DVD_SPU_PLANE_BYTES];
    unsigned configs = 0;
    unsigned data_records = 0;
    unsigned commits = 0;
    size_t reconstructed_bytes = 0;
    size_t offset;
    int failed = 0;

    for (offset = 0; offset < sizeof(pixels); ++offset)
        pixels[offset] = (uint8_t)(offset ^ (offset >> 8));
    overlay.pixels = pixels;
    overlay.visible = 1;
    overlay.menu = 1;
    overlay.highlight_x1 = 10;
    overlay.highlight_y1 = 20;
    overlay.highlight_x2 = 11;
    overlay.highlight_y2 = 21;
    output.video = tmpfile();
    failed |= require(output.video != NULL, "could not create output stream");
    if (failed)
        return 1;
    failed |= require(output_reserve_create(&output.reserve,
                                            fileno(output.video),
                                            4u * 1024u * 1024u) == 0,
                      "could not create production output reserve");
    if (failed)
        return 1;

    failed |= require(emit_overlay_frame(&output, &overlay) == 0,
                      "production frame emitter failed");
    failed |= require(output_reserve_destroy(output.reserve) == 0,
                      "production priority output did not drain");
    output.reserve = NULL;
    failed |= require(fflush(output.video) == 0,
                      "production output stream did not flush");
    rewind(output.video);
    for (;;) {
        uint8_t header[7];
        uint8_t payload[4096];
        size_t got = fread(header, 1, sizeof(header), output.video);
        size_t record_size;
        size_t payload_size;

        if (!got)
            break;
        failed |= require(got == sizeof(header), "truncated record header");
        if (got != sizeof(header))
            break;
        failed |= require(!memcmp(header, "\x00\x00\x01\xb9", 4),
                          "record marker changed");
        record_size = ((size_t)header[4] << 8) | header[5];
        failed |= require(record_size >= 1 && record_size <= sizeof(payload) + 1u,
                          "record length is out of range");
        if (record_size < 1 || record_size > sizeof(payload) + 1u)
            break;
        payload_size = record_size - 1u;
        failed |= require(fread(payload, 1, payload_size, output.video) ==
                              payload_size,
                          "truncated record payload");
        if (header[6] == MEDIA_PLAYER_OVERLAY_CONFIG) {
            configs++;
            failed |= require(payload_size == 41,
                              "configuration payload length changed");
        } else if (header[6] == MEDIA_PLAYER_OVERLAY_DATA) {
            data_records++;
            failed |= require(reconstructed_bytes + payload_size <=
                                  sizeof(reconstructed),
                              "plane exceeded 86,400 bytes");
            if (reconstructed_bytes + payload_size <= sizeof(reconstructed)) {
                memcpy(reconstructed + reconstructed_bytes, payload,
                       payload_size);
                reconstructed_bytes += payload_size;
            }
        } else if (header[6] == MEDIA_PLAYER_OVERLAY_COMMIT) {
            commits++;
            failed |= require(payload_size == 0,
                              "commit unexpectedly carried a payload");
        } else {
            failed |= require(0, "unexpected output record command");
        }
    }
    failed |= require(configs == 1, "more than one plane candidate was emitted");
    failed |= require(data_records == 22, "plane did not use 22 bounded records");
    failed |= require(commits == 1, "more than one plane was committed");
    failed |= require(reconstructed_bytes == sizeof(pixels),
                      "plane byte count was not exactly 86,400");
    failed |= require(!memcmp(reconstructed, pixels, sizeof(pixels)),
                      "emitted plane bytes changed");
    fclose(output.video);

    if (failed)
        return 1;
    puts("DVD overlay output: one exact 86,400-byte candidate passes");
    return 0;
}
