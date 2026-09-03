#define _GNU_SOURCE

#define main media_player_helper_program_main
#include "../host/arm/media_player_helper.c"
#undef main

#include <errno.h>
#include <fcntl.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "DVD overlay output: %s\n", message);
    return 1;
}

static int read_pipe_bytes(int fd, uint8_t *data, size_t size)
{
    size_t offset = 0;

    while (offset < size) {
        ssize_t count = read(fd, data + offset, size - offset);

        if (count > 0) {
            offset += (size_t)count;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        return -1;
    }
    return 0;
}

static void drain_pipe_available(int fd)
{
    uint8_t scratch[4096];
    int available;

    while (ioctl(fd, FIONREAD, &available) == 0 && available > 0) {
        size_t size = (size_t)available;

        if (size > sizeof(scratch))
            size = sizeof(scratch);
        if (read_pipe_bytes(fd, scratch, size) < 0)
            break;
    }
}

static int test_reserve_stdio_ownership(void)
{
    struct output_state output = {0};
    uint8_t stdio_buffer[BUFSIZ];
    uint8_t sentinel = 0x5a;
    uint8_t received = 0;
    uint8_t *record = NULL;
    int descriptors[2] = {-1, -1};
    int pipe_capacity;
    int available = 0;
    int before_finish = 0;
    int after_finish = 0;
    size_t record_size;
    unsigned attempt;
    int failed = 0;

    failed |= require(pipe(descriptors) == 0,
                      "could not create ownership pipe");
    if (failed)
        goto done;
    output.video = fdopen(descriptors[1], "wb");
    failed |= require(output.video != NULL,
                      "could not create ownership stream");
    if (failed)
        goto done;
    descriptors[1] = -1;
    failed |= require(setvbuf(output.video, (char *)stdio_buffer, _IOFBF,
                              sizeof(stdio_buffer)) == 0,
                      "could not buffer ownership stream");
    failed |= require(fwrite(&sentinel, 1, 1, output.video) == 1,
                      "could not stage stdio sentinel");
    failed |= require(ioctl(descriptors[0], FIONREAD, &available) == 0 &&
                          available == 0,
                      "stdio sentinel escaped before reserve ownership");
    pipe_capacity = fcntl(fileno(output.video), F_GETPIPE_SZ);
    failed |= require(pipe_capacity > 0,
                      "could not query ownership pipe capacity");
    if (failed)
        goto done;
    record_size = (size_t)pipe_capacity * 2u;
    record = malloc(record_size);
    failed |= require(record != NULL,
                      "could not allocate ownership record");
    if (failed)
        goto done;
    memset(record, 0xa5, record_size);
    failed |= require(output_reserve_create(&output.reserve,
                                            fileno(output.video),
                                            4u * 1024u * 1024u) == 0,
                      "could not create ownership reserve");
    failed |= require(output_reserve_write(output.reserve, record,
                                           record_size) == 0,
                      "could not enqueue ownership record");
    if (failed)
        goto done;
    for (attempt = 0; attempt < 1000000u; ++attempt) {
        if (ioctl(descriptors[0], FIONREAD, &available) < 0) {
            failed |= require(0, "ownership pipe query failed");
            goto done;
        }
        if (available == pipe_capacity)
            break;
        sched_yield();
    }
    failed |= require(available == pipe_capacity,
                      "reserve did not fill ownership pipe");
    if (failed)
        goto done;
    if (discard_reserved_output(&output, MEDIA_PLAYER_CONTROL_ROOT_MENU,
                                "ownership navigation barrier") < 0) {
        failed |= require(0, "reserve discard touched blocked stdio");
        goto done;
    }
    failed |= require(!ferror(output.video),
                      "reserve discard poisoned stdio state");
    failed |= require(ioctl(descriptors[0], FIONREAD, &before_finish) == 0,
                      "could not measure pipe before shutdown");
    failed |= require(read_pipe_bytes(descriptors[0], record,
                                      (size_t)before_finish) == 0,
                      "could not drain ownership prefix");
    failed |= require(ioctl(descriptors[0], FIONREAD, &before_finish) == 0 &&
                          before_finish == 0,
                      "ownership prefix remained before shutdown");
    failed |= require(finish_output(&output, 1) == 0,
                      "reserve shutdown touched blocked stdio");
    failed |= require(ioctl(descriptors[0], FIONREAD, &after_finish) == 0 &&
                          after_finish == before_finish,
                      "reserve shutdown flushed stdio sentinel");
    failed |= require(fflush(output.video) == 0,
                      "stdio sentinel did not remain independently flushable");
    failed |= require(read_pipe_bytes(descriptors[0], &received, 1) == 0 &&
                          received == sentinel,
                      "stdio sentinel changed under reserve ownership");

done:
    if (output.reserve) {
        (void)output_reserve_discard(output.reserve, NULL);
        (void)output_reserve_destroy(output.reserve);
        output.reserve = NULL;
    }
    if (output.video) {
        clearerr(output.video);
        if (descriptors[0] >= 0)
            drain_pipe_available(descriptors[0]);
        fclose(output.video);
    } else if (descriptors[1] >= 0) {
        close(descriptors[1]);
    }
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    free(record);
    return failed ? -1 : 0;
}

static int test_terminal_still_stage(void)
{
    static const uint8_t still_video[] = {
        0x00, 0x00, 0x01, 0xb3, 0x11, 0x22,
        0x00, 0x00, 0x01, 0x00, 0x00, 1u << 3,
        0x00, 0x00, 0x01, 0x01, 0xaa, 0xbb
    };
    struct output_state output = {0};
    uint8_t received[sizeof(still_video)];
    size_t committed_bytes = 0;
    size_t committed_records = 0;
    int filtered;
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create terminal-still output stream");
    failed |= require(output_stage_create(&output.activation_stage,
                                          sizeof(still_video)) == 0 &&
                      output_stage_begin(output.activation_stage) == 0,
                      "could not start terminal-still activation stage");
    if (failed)
        goto done;
    output.scheduler_enabled = 1;
    output.iso_start_filter_active = 1;
    output.hold_active = 1;
    output.hold_limit = PCM_SAMPLE_RATE;
    failed |= require(queue_video(&output, still_video, sizeof(still_video),
                                  0, 0, 0) == 0 &&
                      output.picture_marks == 0 &&
                      output_stage_records(output.activation_stage) == 0,
                      "terminal still escaped before its authored boundary");
    if (failed)
        goto done;
    filtered = iso_filter_initial_random_access(&output, 1);
    failed |= require(filtered == 1 &&
                      !output.iso_start_filter_active &&
                      scheduler_drain(&output, 0) == 0 &&
                      output.picture_marks == 1 &&
                      output_stage_records(output.activation_stage) == 1 &&
                      output_stage_size(output.activation_stage) ==
                          sizeof(still_video) &&
                      output_stage_classify_still(
                          output.activation_stage, output.picture_marks,
                          0xffu) == OUTPUT_STAGE_STILL_HOP,
                      "terminal still did not become a staged picture hop");
    failed |= require(output_stage_commit(
                          output.activation_stage,
                          write_output_stage_callback, &output,
                          &committed_bytes, &committed_records) == 0 &&
                      committed_bytes == sizeof(still_video) &&
                      committed_records == 1 &&
                      fflush(output.video) == 0 &&
                      fseek(output.video, 0, SEEK_SET) == 0 &&
                      fread(received, 1, sizeof(received), output.video) ==
                          sizeof(received) &&
                      !memcmp(received, still_video, sizeof(received)),
                      "terminal still stage changed its qualified picture");

done:
    while (output.video_head)
        free_video_head(&output);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    return failed;
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
    if (test_reserve_stdio_ownership() < 0)
        return 1;
    if (test_terminal_still_stage())
        return 1;
    puts("DVD overlay output: exact plane and reserve ownership pass");
    return 0;
}
