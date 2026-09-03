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

static int test_h262_restart_diagnostic_fields(void)
{
    uint8_t video[64] = {0};
    uint8_t original[sizeof(video)];
    struct dvd_random_access_result restart = {
        .sequence_offset = 0,
        .intra_offset = 24,
        .next_reference_offset = sizeof(video)
    };
    struct h262_restart_diagnostic diagnostic;
    static const uint8_t sequence_extension[] = {
        0x14, 0x8a, 0x00, 0x01, 0x00, 0x23
    };
    static const uint8_t picture_extension[] = {
        0x8f, 0xff, 0xf3, 0x80, 0x00
    };
    int failed = 0;

    video[0] = 0x00;
    video[1] = 0x00;
    video[2] = 0x01;
    video[3] = 0xb3;
    video[4] = 0x2d;
    video[5] = 0x01;
    video[6] = 0xe0;
    video[7] = 0x34;
    video[10] = 0x20;
    video[12] = 0x00;
    video[13] = 0x00;
    video[14] = 0x01;
    video[15] = 0xb5;
    memcpy(video + 16, sequence_extension, sizeof(sequence_extension));
    video[24] = 0x00;
    video[25] = 0x00;
    video[26] = 0x01;
    video[27] = 0x00;
    video[28] = 0x00;
    video[29] = 0x08;
    video[32] = 0x00;
    video[33] = 0x00;
    video[34] = 0x01;
    video[35] = 0xb5;
    memcpy(video + 36, picture_extension, sizeof(picture_extension));
    memcpy(original, video, sizeof(video));

    collect_h262_restart_diagnostic(video, sizeof(video), &restart,
                                    &diagnostic);
    failed |= require(!memcmp(video, original, sizeof(video)),
                      "H262 diagnostic changed the media bytes");
    failed |= require(diagnostic.sequence_header_valid &&
                          diagnostic.horizontal_size == 720 &&
                          diagnostic.vertical_size == 480 &&
                          diagnostic.aspect_ratio == 3 &&
                          diagnostic.frame_rate_code == 4 &&
                          diagnostic.sequence_marker == 1,
                      "H262 diagnostic decoded the sequence header wrongly");
    failed |= require(diagnostic.sequence_extension_valid &&
                          diagnostic.sequence_extension_offset == 12 &&
                          !memcmp(diagnostic.sequence_extension,
                                  sequence_extension,
                                  sizeof(sequence_extension)),
                      "H262 diagnostic missed the sequence extension");
    failed |= require(diagnostic.picture_header_valid &&
                          diagnostic.temporal_reference == 0 &&
                          diagnostic.picture_coding_type == 1,
                      "H262 diagnostic decoded the picture header wrongly");
    failed |= require(diagnostic.picture_extension_valid &&
                          diagnostic.picture_extension_offset == 32 &&
                          !memcmp(diagnostic.picture_extension,
                                  picture_extension,
                                  sizeof(picture_extension)),
                      "H262 diagnostic missed the picture extension");
    return failed;
}

static int hex_nibble(char digit)
{
    if (digit >= '0' && digit <= '9')
        return digit - '0';
    if (digit >= 'a' && digit <= 'f')
        return digit - 'a' + 10;
    return -1;
}

static int test_h262_restart_chroma_normalization(void)
{
    static const char captured_prefix[] =
        "000001b32d01e024138823821010101010101010101010101010101010101010"
        "1010101010101010101010101010101010101010101010101010101010101010"
        "1010101010101010101010110808080808080808080808080808080808080808"
        "0808080808080808080808080808080808080808080808080808080808080808"
        "080808080808080808080808000001b5148200010000000001b5250606060872"
        "0f00000001b88008004000000100000a23e0000001b58ffff3c08000000101";
    enum { PREFIX_BYTES = 191 };
    struct dvd_random_access_result restart = {
        .sequence_offset = 0,
        .intra_offset = 170,
        .next_reference_offset = PREFIX_BYTES
    };
    struct h262_restart_normalization normalization;
    struct h262_restart_diagnostic diagnostic;
    uint8_t malformed[PREFIX_BYTES];
    uint8_t corrected[PREFIX_BYTES];
    uint8_t control[PREFIX_BYTES];
    size_t offset;
    int failed = 0;

    failed |= require(sizeof(captured_prefix) - 1u == PREFIX_BYTES * 2u,
                      "captured H262 prefix length changed");
    for (offset = 0; offset < PREFIX_BYTES; offset++) {
        int high = hex_nibble(captured_prefix[offset * 2u]);
        int low = hex_nibble(captured_prefix[offset * 2u + 1u]);

        failed |= require(high >= 0 && low >= 0,
                          "captured H262 prefix is not hexadecimal");
        malformed[offset] = (uint8_t)((high << 4) | low);
    }
    if (failed)
        return failed;

    memcpy(corrected, malformed, sizeof(corrected));
    failed |= require(normalize_h262_restart_chroma_420(
                          corrected, sizeof(corrected), &restart,
                          &normalization) == 1,
                      "captured H262 mismatch was not normalized");
    failed |= require(normalization.byte_offset == 185 &&
                          normalization.before == 0xc0 &&
                          normalization.after == 0xc1 &&
                          corrected[185] == 0xc1,
                      "captured H262 normalization changed the wrong field");
    for (offset = 0; offset < sizeof(corrected); offset++) {
        failed |= require(corrected[offset] ==
                              (offset == 185 ? 0xc1 : malformed[offset]),
                          "captured H262 normalization changed another byte");
    }
    collect_h262_restart_diagnostic(corrected, sizeof(corrected), &restart,
                                    &diagnostic);
    failed |= require(diagnostic.progressive_sequence == 0 &&
                          diagnostic.chroma_format == 1 &&
                          diagnostic.picture_coding_type == 1 &&
                          (diagnostic.picture_extension[2] & 3u) == 3u &&
                          (diagnostic.picture_extension[3] & 1u) == 1u &&
                          (diagnostic.picture_extension[4] >> 7) == 1u,
                      "normalized H262 fields do not describe a 4:2:0 "
                      "progressive frame");
    failed |= require(normalize_h262_restart_chroma_420(
                          corrected, sizeof(corrected), &restart,
                          &normalization) == 0,
                      "conforming H262 restart was not idempotent");

    memcpy(control, malformed, sizeof(control));
    control[145] = 0x84;
    failed |= require(normalize_h262_restart_chroma_420(
                          control, sizeof(control), &restart,
                          &normalization) == 0 && control[185] == 0xc0,
                      "non-4:2:0 sequence was normalized");
    memcpy(control, malformed, sizeof(control));
    control[175] = 0x12;
    failed |= require(normalize_h262_restart_chroma_420(
                          control, sizeof(control), &restart,
                          &normalization) == 0 && control[185] == 0xc0,
                      "non-I picture was normalized");
    memcpy(control, malformed, sizeof(control));
    control[184] = 0xf1;
    failed |= require(normalize_h262_restart_chroma_420(
                          control, sizeof(control), &restart,
                          &normalization) == 0 && control[185] == 0xc0,
                      "field picture was normalized");
    memcpy(control, malformed, sizeof(control));
    control[186] = 0x00;
    failed |= require(normalize_h262_restart_chroma_420(
                          control, sizeof(control), &restart,
                          &normalization) == 0 && control[185] == 0xc0,
                      "non-progressive frame was normalized");
    return failed;
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
    static const uint8_t terminal_tail[] = {
        0x00, 0x00, 0x01, 0xb7, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    struct output_state output = {0};
    uint8_t received[sizeof(still_video) + sizeof(terminal_tail)];
    size_t committed_bytes = 0;
    size_t committed_records = 0;
    int filtered;
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create terminal-still output stream");
    failed |= require(output_stage_create(&output.activation_stage,
                                          sizeof(received)) == 0 &&
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
    filtered = iso_finalize_terminal_random_access(&output);
    failed |= require(filtered == 1 &&
                      !output.iso_start_filter_active &&
                      output.picture_marks == 1 &&
                      output_stage_records(output.activation_stage) == 2 &&
                      output_stage_size(output.activation_stage) ==
                          sizeof(received) &&
                      output_stage_classify_still(
                          output.activation_stage, output.picture_marks,
                          0xffu) == OUTPUT_STAGE_STILL_HOP,
                      "terminal still did not become a staged picture hop");
    failed |= require(output_stage_commit(
                          output.activation_stage,
                          write_output_stage_callback, &output,
                          &committed_bytes, &committed_records) == 0 &&
                      committed_bytes == sizeof(received) &&
                      committed_records == 2 &&
                      fflush(output.video) == 0 &&
                      fseek(output.video, 0, SEEK_SET) == 0 &&
                      fread(received, 1, sizeof(received), output.video) ==
                          sizeof(received) &&
                      !memcmp(received, still_video, sizeof(still_video)) &&
                      !memcmp(received + sizeof(still_video), terminal_tail,
                              sizeof(terminal_tail)),
                      "terminal still stage did not preserve its picture "
                      "and append its exact sequence-end drain tail");

done:
    while (output.video_head)
        free_video_head(&output);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    return failed;
}

static int test_terminal_still_direct(void)
{
    static const uint8_t still_video[] = {
        0x00, 0x00, 0x01, 0xb3, 0x31, 0x42,
        0x00, 0x00, 0x01, 0x00, 0x00, 1u << 3,
        0x00, 0x00, 0x01, 0x01, 0xcc, 0xdd
    };
    static const uint8_t terminal_tail[] = {
        0x00, 0x00, 0x01, 0xb7, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    struct output_state output = {0};
    uint8_t received[sizeof(still_video) + sizeof(terminal_tail)];
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create direct-still output stream");
    failed |= require(output_stage_create(&output.activation_stage,
                                          sizeof(received)) == 0,
                      "could not create inactive direct-still stage");
    if (failed)
        goto done;
    output.scheduler_enabled = 1;
    output.iso_start_filter_active = 1;
    output.hold_active = 1;
    output.hold_limit = PCM_SAMPLE_RATE;
    failed |= require(queue_video(&output, still_video, sizeof(still_video),
                                  0, 0, 0) == 0 &&
                      finalize_dvd_still_random_access(&output) == 0 &&
                      !output.iso_start_filter_active &&
                      output.picture_marks == 1 &&
                      !output_stage_active(output.activation_stage) &&
                      output_stage_records(output.activation_stage) == 0,
                      "direct Root Menu still was not finalized unstaged");
    failed |= require(fflush(output.video) == 0 &&
                      fseek(output.video, 0, SEEK_SET) == 0 &&
                      fread(received, 1, sizeof(received), output.video) ==
                          sizeof(received) &&
                      !memcmp(received, still_video, sizeof(still_video)) &&
                      !memcmp(received + sizeof(still_video), terminal_tail,
                              sizeof(terminal_tail)),
                      "direct Root Menu still changed its picture or tail");

done:
    while (output.video_head)
        free_video_head(&output);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    return failed;
}

static int test_motion_menu_stage_pressure(void)
{
    static const size_t finite_still_bytes = 3797120u;
    struct dvd_menu_state menu = {0};
    struct output_state output = {0};
    uint8_t compare[65536];
    uint8_t *payload = NULL;
    size_t offset;
    int control_command = 0;
    int failed = 0;

    payload = malloc(OUTPUT_ACTIVATION_STAGE_DECISION_BYTES);
    output.video = tmpfile();
    failed |= require(payload != NULL && output.video != NULL,
                      "could not allocate motion-menu test state");
    failed |= require(output_stage_create(&output.activation_stage,
                                          OUTPUT_ACTIVATION_STAGE_BYTES) == 0 &&
                      output_stage_begin(output.activation_stage) == 0,
                      "could not start motion-menu activation stage");
    if (failed)
        goto done;
    for (offset = 0; offset < OUTPUT_ACTIVATION_STAGE_DECISION_BYTES;
         ++offset)
        payload[offset] = (uint8_t)(offset ^ (offset >> 8) ^ (offset >> 16));
    menu.menu_active = 1;
    menu.activation_pending = 1;
    output.picture_marks = 2;
    failed |= require(output_stage_write(output.activation_stage, payload,
                                         finite_still_bytes, 0) == 1 &&
                      output_stage_classify_still(
                          output.activation_stage, output.picture_marks, 5) ==
                          OUTPUT_STAGE_STILL_COMMIT &&
                      activation_stage_motion_hop(
                          &menu, &output, &control_command) == 0 &&
                      !menu.activation_staged_hop && control_command == 0,
                      "accepted finite still crossed the motion watermark");
    failed |= require(output_stage_write(
                          output.activation_stage,
                          payload + finite_still_bytes,
                          OUTPUT_ACTIVATION_STAGE_DECISION_BYTES -
                              finite_still_bytes,
                          1) == 1 &&
                      output_stage_size(output.activation_stage) ==
                          OUTPUT_ACTIVATION_STAGE_DECISION_BYTES &&
                      activation_stage_motion_hop(
                          &menu, &output, &control_command) == 1 &&
                      menu.activation_staged_hop &&
                      control_command == MEDIA_PLAYER_CONTROL_MENU_ACTIVATE,
                      "picture-bearing motion menu was not promoted");
    failed |= require(commit_activation_stage(
                          &output, "motion-menu-test") == 0 &&
                      fflush(output.video) == 0 &&
                      fseek(output.video, 0, SEEK_SET) == 0,
                      "motion-menu stage did not commit after promotion");
    for (offset = 0;
         !failed && offset < OUTPUT_ACTIVATION_STAGE_DECISION_BYTES;) {
        size_t count = OUTPUT_ACTIVATION_STAGE_DECISION_BYTES - offset;

        if (count > sizeof(compare))
            count = sizeof(compare);
        failed |= require(fread(compare, 1, count, output.video) == count &&
                          !memcmp(compare, payload + offset, count),
                          "motion-menu promotion changed staged bytes");
        offset += count;
    }
    failed |= require(!output_stage_active(output.activation_stage) &&
                      output_stage_size(output.activation_stage) == 0,
                      "motion-menu commit left its stage active");

done:
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    free(payload);
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

    failed |= test_h262_restart_diagnostic_fields();
    failed |= test_h262_restart_chroma_normalization();
    audio_overlay_descriptor(&output, &overlay, 1);
    failed |= require(overlay.visible && overlay.rgba[0][3] == 0x00 &&
                      overlay.rgba[1][3] == 0xa0 &&
                      overlay.rgba[2][3] == 0xff &&
                      overlay.rgba[3][3] == 0xff,
                      "audio overlay palette alpha changed");
    failed |= require(!memcmp(overlay.rgba, overlay.highlight_rgba,
                              sizeof(overlay.rgba)),
                      "audio overlay highlight palette changed");
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
    if (test_terminal_still_direct())
        return 1;
    if (test_motion_menu_stage_pressure())
        return 1;
    puts("DVD overlay output: exact plane and reserve ownership pass");
    return 0;
}
