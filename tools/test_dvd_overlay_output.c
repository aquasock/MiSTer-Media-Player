#define _GNU_SOURCE

#define main media_player_helper_program_main
#include "../host/arm/media_player_helper.c"
#undef main

#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
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

static void encode_pes_pts(uint8_t encoded[5], uint64_t pts);

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

static int run_h262_stream_filter(const uint8_t *input, size_t size,
                                  size_t first_chunk, uint8_t *output,
                                  unsigned *corrections)
{
    struct h262_chroma_stream_state state = {0};
    size_t input_offset = 0;
    size_t output_offset = 0;
    unsigned chunks = 0;

    while (input_offset < size) {
        uint8_t buffer[512];
        uint8_t prefix = 0;
        int prefix_valid = 0;
        size_t count;
        size_t safe;

        if (first_chunk == SIZE_MAX)
            count = 1u;
        else if (!chunks)
            count = first_chunk;
        else
            count = size - input_offset;
        if (count > size - input_offset)
            count = size - input_offset;
        if (!count || count > sizeof(buffer))
            return -1;
        memcpy(buffer, input + input_offset, count);
        safe = h262_chroma_stream_filter(&state, buffer, count, &prefix,
                                         &prefix_valid, 0);
        if (prefix_valid)
            output[output_offset++] = prefix;
        memcpy(output + output_offset, buffer, safe);
        output_offset += safe;
        input_offset += count;
        chunks++;
    }
    if (state.have_pending)
        output[output_offset++] = state.pending_byte;
    *corrections = state.corrections;
    return output_offset == size ? 0 : -1;
}

static int test_h262_stream_chroma_normalization(void)
{
    static const char captured_prefix[] =
        "000001b32d01e024138823821010101010101010101010101010101010101010"
        "1010101010101010101010101010101010101010101010101010101010101010"
        "1010101010101010101010110808080808080808080808080808080808080808"
        "0808080808080808080808080808080808080808080808080808080808080808"
        "080808080808080808080808000001b5148200010000000001b5250606060872"
        "0f00000001b88008004000000100000a23e0000001b58ffff3c08000000101";
    static const uint8_t sequence_end[] = {0x00, 0x00, 0x01, 0xb7};
    enum { PREFIX_BYTES = 191, STREAM_BYTES = PREFIX_BYTES * 2 + 4 };
    uint8_t prefix[PREFIX_BYTES];
    uint8_t malformed[STREAM_BYTES];
    uint8_t expected[STREAM_BYTES];
    uint8_t actual[STREAM_BYTES];
    uint8_t control[PREFIX_BYTES];
    size_t offset;
    unsigned corrections = 0;
    int failed = 0;

    for (offset = 0; offset < PREFIX_BYTES; offset++) {
        int high = hex_nibble(captured_prefix[offset * 2u]);
        int low = hex_nibble(captured_prefix[offset * 2u + 1u]);

        failed |= require(high >= 0 && low >= 0,
                          "stream fixture is not hexadecimal");
        prefix[offset] = (uint8_t)((high << 4) | low);
    }
    if (failed)
        return failed;
    memcpy(malformed, prefix, PREFIX_BYTES);
    memcpy(malformed + PREFIX_BYTES, sequence_end, sizeof(sequence_end));
    memcpy(malformed + PREFIX_BYTES + sizeof(sequence_end), prefix,
           PREFIX_BYTES);
    memcpy(expected, malformed, sizeof(expected));
    expected[185] = 0xc1;
    expected[PREFIX_BYTES + sizeof(sequence_end) + 185u] = 0xc1;

    for (offset = 1; offset < sizeof(malformed); offset++) {
        failed |= require(run_h262_stream_filter(
                              malformed, sizeof(malformed), offset, actual,
                              &corrections) == 0 && corrections == 2u &&
                              !memcmp(actual, expected, sizeof(expected)),
                          "PES split changed bytes or missed a captured "
                          "sequence correction");
    }
    failed |= require(run_h262_stream_filter(
                          malformed, sizeof(malformed), SIZE_MAX, actual,
                          &corrections) == 0 && corrections == 2u &&
                          !memcmp(actual, expected, sizeof(expected)),
                      "one-byte PES fragmentation changed normalized output");

    memcpy(control, prefix, sizeof(control));
    control[185] = 0xc1;
    failed |= require(run_h262_stream_filter(
                          control, sizeof(control), 186u, actual,
                          &corrections) == 0 && corrections == 0u &&
                          !memcmp(actual, control, sizeof(control)),
                      "conforming streaming picture changed");
    memcpy(control, prefix, sizeof(control));
    control[145] = 0x84;
    failed |= require(run_h262_stream_filter(
                          control, sizeof(control), 145u, actual,
                          &corrections) == 0 && corrections == 0u &&
                          !memcmp(actual, control, sizeof(control)),
                      "streaming non-4:2:0 picture changed");
    memcpy(control, prefix, sizeof(control));
    control[175] = 0x12;
    failed |= require(run_h262_stream_filter(
                          control, sizeof(control), 176u, actual,
                          &corrections) == 0 && corrections == 0u &&
                          !memcmp(actual, control, sizeof(control)),
                      "streaming non-I picture changed");
    memcpy(control, prefix, sizeof(control));
    control[184] = 0xf1;
    failed |= require(run_h262_stream_filter(
                          control, sizeof(control), 185u, actual,
                          &corrections) == 0 && corrections == 0u &&
                          !memcmp(actual, control, sizeof(control)),
                      "streaming field picture changed");
    memcpy(control, prefix, sizeof(control));
    control[186] = 0x00;
    failed |= require(run_h262_stream_filter(
                          control, sizeof(control), 186u, actual,
                          &corrections) == 0 && corrections == 0u &&
                          !memcmp(actual, control, sizeof(control)),
                      "streaming interlaced-frame picture changed");
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

static int test_unqualified_menu_activation_continuation(void)
{
    static const uint8_t staged_marker[] = {0x91, 0x82, 0x73, 0x64};
    static const uint64_t prior_pts = 900000u;
    static const uint64_t activation_pts = 45000u;
    static const uint64_t continued_pts = prior_pts + 1u;
    const size_t payload_size = VIDEO_QUEUE_LIMIT - 80u;
    enum { INCOMING_VIDEO_BYTES = 64 };
    const size_t held_frames = PCM_SCHEDULE_RESERVE_FRAMES +
        ((payload_size + PCM_MAX_FREE_VIDEO_BYTES - 1u) /
             PCM_MAX_FREE_VIDEO_BYTES + 1u) * PCM_REFILL_FRAMES;
    struct dvd_menu_state menu = {0};
    struct audio_state audio = {0};
    struct output_state output = {0};
    struct media_source input = {0};
    uint8_t pes[2u + 3u + 5u + INCOMING_VIDEO_BYTES];
    uint8_t expected_pts[9];
    uint8_t actual_pts[9];
    uint8_t compare[65536];
    uint8_t event = 0;
    uint8_t *payload = NULL;
    int descriptors[2] = {-1, -1};
    size_t video_bytes = 0;
    uint64_t queued_pts = 0;
    unsigned pts_records = 0;
    char input_path[] = "/tmp/mmp-menu-continuation-XXXXXX";
    char source_error[128];
    int video_code = -1;
    int audio_code = -1;
    int input_fd = -1;
    int input_open = 0;
    int value;
    int failed = 0;

    payload = malloc(payload_size);
    output.video = tmpfile();
    failed |= require(payload != NULL && output.video != NULL &&
                          pipe(descriptors) == 0,
                      "could not allocate context-continuation fixture");
    if (failed)
        goto done;
    memset(payload, 0x55, payload_size);
    output.iso_pts_normalization = 1;
    output.have_iso_video_pts = 1;
    output.iso_pts_raw_max = prior_pts;
    output.iso_pts_normalized_max = prior_pts;
    menu.enabled = 1;
    menu.menu_active = 1;
    audio.a52_substream = -1;
    audio.dts_substream = -1;
    failed |= require(output_stage_create(&output.activation_stage,
                                          OUTPUT_ACTIVATION_STAGE_BYTES) == 0,
                      "could not create context-continuation stage");
    failed |= require(start_pending_menu_activation(
                          &menu, &audio, &output) == 0 &&
                          menu.activation_pending &&
                          menu.activation_prior_pts_valid &&
                          menu.activation_prior_pts == prior_pts &&
                          output.iso_start_filter_active,
                      "pending activation did not retain its live PTS floor");
    output.audio_pes_seen = 1;
    output.have_audio_pts = 1;
    output.first_audio_pts = activation_pts;
    output.hold = calloc(held_frames * 2u, sizeof(*output.hold));
    output.hold_count = held_frames * 2u;
    output.hold_capacity = output.hold_count;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    failed |= require(output.hold != NULL,
                      "could not allocate context-continuation PCM horizon");
    failed |= require(write_output_priority(
                          &output, staged_marker, sizeof(staged_marker),
                          "context-continuation marker") == 0,
                      "could not stage context-continuation marker");
    failed |= require(normalize_video_pts(
                          &output, activation_pts, &queued_pts) == 0 &&
                          queued_pts == activation_pts,
                      "could not establish the staged activation PTS");
    failed |= require(queue_h262_video(
                          &output, payload, payload_size, 1, 1,
                          queued_pts) == 0 &&
                          iso_filter_initial_random_access(&output, 0) == 0 &&
                          output.iso_start_filter_active &&
                          video_queue_would_overflow(
                              &output, INCOMING_VIDEO_BYTES, 1),
                      "sequence-free activation did not reach queue pressure");
    pes[0] = 0;
    pes[1] = (uint8_t)(sizeof(pes) - 2u);
    pes[2] = 0x80;
    pes[3] = 0x80;
    pes[4] = 0x05;
    encode_pes_pts(pes + 5, activation_pts);
    memset(pes + 10, 0x55, INCOMING_VIDEO_BYTES);
    input_fd = mkstemp(input_path);
    failed |= require(input_fd >= 0 &&
                          write(input_fd, pes, sizeof(pes)) ==
                              (ssize_t)sizeof(pes) &&
                          close(input_fd) == 0,
                      "could not create the pressure-triggering PES");
    input_fd = -1;
    failed |= require(!failed &&
                          media_source_open(&input, input_path, source_error,
                                            sizeof(source_error)) ==
                              MEDIA_SOURCE_OK,
                      "could not open the pressure-triggering PES");
    input_open = !failed;
    failed |= require(!failed &&
                          process_pes(
                              &input, 0xe0, &audio, &output, &menu,
                              descriptors[1], &video_code, &audio_code,
                              NULL, -1) == 0 &&
                          !menu.activation_pending &&
                          !menu.activation_followup_pending &&
                          !menu.activation_prior_pts_valid &&
                          !output.iso_start_filter_active &&
                          output.automatic_menu_epoch &&
                          !output_stage_active(output.activation_stage) &&
                          output.video_head == NULL &&
                          output.video_queued_bytes == 0 &&
                          output.have_video_pts &&
                          output.max_video_pts == continued_pts &&
                          output.iso_pts_normalized_max == continued_pts &&
                          output.iso_pts_epoch_offset ==
                              continued_pts - activation_pts,
                      "production PES path did not preserve resident context");
    failed |= require(read(descriptors[0], &event, sizeof(event)) == 1 &&
                          event == MEDIA_PLAYER_CONTROL_MENU_CONTINUE,
                      "context continuation was not acknowledged");
    failed |= require(flush_h262_video(&output) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          fflush(output.video) == 0 &&
                          fseek(output.video, 0, SEEK_SET) == 0,
                      "context-continuation output did not finish");
    encode_video_pts(expected_pts, continued_pts);
    failed |= require(fread(compare, 1, sizeof(staged_marker), output.video) ==
                              sizeof(staged_marker) &&
                          !memcmp(compare, staged_marker,
                                  sizeof(staged_marker)),
                      "staged prefix changed");
    while (!failed && (value = fgetc(output.video)) != EOF) {
        if (value == 0) {
            uint8_t record_header[4];
            unsigned frames;
            size_t pcm_bytes;

            record_header[0] = 0;
            failed |= require(fread(record_header + 1, 1, 3,
                                    output.video) == 3 &&
                                  record_header[1] == 0 &&
                                  record_header[2] == 1,
                              "context continuation truncated a record");
            if (failed)
                break;
            if (record_header[3] == MEDIA_PLAYER_PTS_MARKER_CODE) {
                memcpy(actual_pts, record_header, sizeof(record_header));
                failed |= require(fread(actual_pts + sizeof(record_header),
                                        1,
                                        sizeof(actual_pts) -
                                            sizeof(record_header),
                                        output.video) ==
                                      sizeof(actual_pts) -
                                          sizeof(record_header) &&
                                      !memcmp(actual_pts, expected_pts,
                                              sizeof(expected_pts)),
                                  "rebased PTS record changed");
                pts_records++;
                continue;
            }
            failed |= require(record_header[3] ==
                                  MEDIA_PLAYER_PCM_MARKER_CODE,
                              "context continuation emitted an unknown record");
            value = fgetc(output.video);
            failed |= require(value != EOF,
                              "context continuation truncated a PCM record");
            if (failed)
                break;
            frames = (unsigned)value >> 2;
            pcm_bytes = (size_t)frames * 4u;
            failed |= require(frames > 0 && frames <= PCM_RECORD_FRAMES &&
                                  pcm_bytes <= sizeof(compare) &&
                                  fread(compare, 1, pcm_bytes,
                                        output.video) == pcm_bytes,
                              "context continuation PCM record is invalid");
            continue;
        }
        failed |= require(value == 0x55,
                          "context continuation changed a video byte");
        video_bytes++;
    }
    failed |= require(pts_records == 2 &&
                          video_bytes ==
                              payload_size + INCOMING_VIDEO_BYTES,
                      "context continuation changed PTS or video byte count");

done:
    if (input_open)
        media_source_close(&input);
    if (input_fd >= 0)
        close(input_fd);
    unlink(input_path);
    while (output.video_head)
        free_video_head(&output);
    free(output.hold);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    free(payload);
    return failed;
}

static int test_late_audio_after_silent_release(void)
{
    struct output_state output = {0};
    uint8_t *payload = NULL;
    uint8_t compare[4096];
    size_t payload_size = VIDEO_QUEUE_LIMIT - 8u;
    size_t offset;
    int failed = 0;

    payload = malloc(payload_size);
    output.video = tmpfile();
    failed |= require(payload != NULL && output.video != NULL,
                      "could not allocate late-audio fixture");
    if (failed)
        goto done;
    for (offset = 0; offset < payload_size; ++offset)
        payload[offset] = (uint8_t)(offset ^ (offset >> 8) ^ (offset >> 16));

    output.scheduler_enabled = 1;
    output.hold_active = 1;
    output.have_video_pts = 1;
    output.max_video_pts = 90000u;
    failed |= require(queue_video(&output, payload, payload_size,
                                  1, 0, 180000u) == 0,
                      "could not queue the bounded video lookahead");
    failed |= require(video_queue_would_overflow(&output, 16u, 0),
                      "late-audio fixture did not reach the 2 MiB boundary");
    failed |= require(scheduler_release_silent_video(&output) == 0,
                      "silent-video release failed");
    failed |= require(output.silent_video_mode &&
                          !output.scheduler_enabled &&
                          output.scheduler_started &&
                          !output.hold_active &&
                          output.video_head == NULL &&
                          output.video_tail == NULL &&
                          output.video_queued_bytes == 0 &&
                          output.video_bytes == payload_size &&
                          output.have_video_pts &&
                          output.max_video_pts == 180000u,
                      "silent-video release state changed");
    failed |= require(reject_late_audio(
                          &output, "AC-3", 1, 270000u) < 0,
                      "late AC-3 was not rejected after silent release");
    failed |= require(reject_late_audio(
                          &output, "MPEG Layer II", 1, 90000u) < 0,
                      "behind-horizon MPEG audio was not rejected");
    failed |= require(reject_late_audio(
                          &output, "DTS", 0, 0) < 0,
                      "untimestamped DTS was not rejected");
    failed |= require(fflush(output.video) == 0 &&
                          fseek(output.video, 0, SEEK_SET) == 0,
                      "could not rewind released video");
    for (offset = 0; !failed && offset < payload_size;) {
        size_t count = payload_size - offset;

        if (count > sizeof(compare))
            count = sizeof(compare);
        failed |= require(fread(compare, 1, count, output.video) == count &&
                              !memcmp(compare, payload + offset, count),
                          "silent release changed queued video bytes");
        offset += count;
    }

done:
    while (output.video_head)
        free_video_head(&output);
    if (output.video)
        fclose(output.video);
    free(payload);
    return failed;
}

static int test_provisional_menu_activation_followup(void)
{
    struct dvd_menu_state menu = {0};
    struct audio_state audio = {0};
    struct output_state output = {0};
    uint8_t event = 0;
    int descriptors[2] = {-1, -1};
    int control_command = 0;
    int failed = 0;

    output.video = tmpfile();
    output.hold_limit = PCM_SAMPLE_RATE;
    menu.enabled = 1;
    menu.menu_active = 1;
    audio.a52_substream = -1;
    audio.dts_substream = -1;
    failed |= require(output.video != NULL && pipe(descriptors) == 0 &&
                          output_stage_create(
                              &output.activation_stage,
                              OUTPUT_ACTIVATION_STAGE_BYTES) == 0,
                      "could not allocate provisional-followup fixture");
    if (failed)
        goto done;
    failed |= require(acknowledge_provisional_menu_continuation(
                          &menu, descriptors[1], "test") == 0 &&
                          !menu.activation_pending &&
                          menu.activation_followup_pending &&
                          read(descriptors[0], &event, sizeof(event)) == 1 &&
                          event == MEDIA_PLAYER_CONTROL_MENU_CONTINUE,
                      "provisional continuation did not release Main");
    menu.menu_active = 0;
    failed |= require(delayed_activation_leave_before_payload(
                          &menu, &output, 0xbau,
                          &control_command) == 1 &&
                          !menu.activation_pending &&
                          !menu.activation_followup_pending &&
                          menu.resume_code_valid &&
                          menu.resume_code == 0xbau &&
                          control_command ==
                              MEDIA_PLAYER_CONTROL_STREAM_BOUNDARY,
                      "provisional menu leave lost its asynchronous barrier");

    menu.menu_active = 1;
    menu.activation_followup_pending = 1;
    failed |= require(start_pending_menu_activation(
                          &menu, &audio, &output) == 0 &&
                          menu.activation_pending &&
                          !menu.activation_followup_pending &&
                          output_stage_active(output.activation_stage),
                      "superseding activation retained stale follow-up state");
    failed |= require(cancel_pending_menu_activation(
                          &menu, &output, "test-cleanup") == 0 &&
                          !menu.activation_pending &&
                          !menu.activation_followup_pending &&
                          !output_stage_active(output.activation_stage),
                      "provisional follow-up cancellation was incomplete");

done:
    free(output.hold);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    return failed ? -1 : 0;
}

static void encode_pes_pts(uint8_t encoded[5], uint64_t pts)
{
    encoded[0] = (uint8_t)(0x21u | ((pts >> 29) & 0x0eu));
    encoded[1] = (uint8_t)(pts >> 22);
    encoded[2] = (uint8_t)(0x01u | ((pts >> 14) & 0xfeu));
    encoded[3] = (uint8_t)(pts >> 7);
    encoded[4] = (uint8_t)(0x01u | ((pts << 1) & 0xfeu));
}

static int compare_fixture_video_and_pcm(FILE *stream,
                                         const uint8_t *expected_video,
                                         size_t expected_video_size,
                                         const int16_t *expected_pcm,
                                         size_t expected_pcm_frames)
{
    uint8_t *actual = NULL;
    long end;
    size_t actual_size;
    size_t actual_offset = 0;
    size_t video_offset = 0;
    size_t pcm_offset = 0;
    int failed = 0;

    if (fflush(stream) == EOF || fseek(stream, 0, SEEK_END) < 0 ||
        (end = ftell(stream)) < 0 || fseek(stream, 0, SEEK_SET) < 0)
        return -1;
    actual_size = (size_t)end;
    actual = malloc(actual_size ? actual_size : 1u);
    if (!actual || fread(actual, 1, actual_size, stream) != actual_size) {
        free(actual);
        return -1;
    }
    while (actual_offset < actual_size) {
        if (actual_offset + 5u <= actual_size &&
            actual[actual_offset] == 0 &&
            actual[actual_offset + 1u] == 0 &&
            actual[actual_offset + 2u] == 1 &&
            actual[actual_offset + 3u] == MEDIA_PLAYER_PCM_MARKER_CODE) {
            unsigned frames = (actual[actual_offset + 4u] >> 2) & 0x1fu;
            size_t record_size = 5u + (size_t)frames * 4u;

            if (!frames || record_size > actual_size - actual_offset) {
                failed = 1;
                break;
            }
            for (unsigned frame = 0; frame < frames; ++frame) {
                size_t sample = pcm_offset * 2u;
                uint16_t left =
                    ((uint16_t)actual[actual_offset + 5u + frame * 4u] << 8) |
                    actual[actual_offset + 6u + frame * 4u];
                uint16_t right =
                    ((uint16_t)actual[actual_offset + 7u + frame * 4u] << 8) |
                    actual[actual_offset + 8u + frame * 4u];

                if (pcm_offset >= expected_pcm_frames ||
                    left != (uint16_t)expected_pcm[sample] ||
                    right != (uint16_t)expected_pcm[sample + 1u]) {
                    failed = 1;
                    break;
                }
                pcm_offset++;
            }
            if (failed)
                break;
            actual_offset += record_size;
            continue;
        }
        if (video_offset >= expected_video_size ||
            actual[actual_offset] != expected_video[video_offset]) {
            failed = 1;
            break;
        }
        actual_offset++;
        video_offset++;
    }
    if (video_offset != expected_video_size ||
        pcm_offset != expected_pcm_frames)
        failed = 1;
    free(actual);
    return failed ? -1 : 0;
}

static int test_audio_forward_title_pts_lookahead(void)
{
    enum {
        CHUNKS = 6,
        CHUNK_BYTES = 4096,
        INTERVAL_FRAMES = PCM_SAMPLE_RATE / 2,
        TOTAL_PCM_FRAMES = CHUNKS * INTERVAL_FRAMES
    };
    static const uint64_t first_audio_pts = 90000u;
    struct output_state output = {0};
    uint8_t video[CHUNKS * CHUNK_BYTES];
    int16_t pcm[TOTAL_PCM_FRAMES * 2u];
    unsigned chunk_index;
    size_t sample;
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create title-lookahead output");
    if (failed)
        return -1;
    for (chunk_index = 0; chunk_index < CHUNKS; ++chunk_index)
        memset(video + (size_t)chunk_index * CHUNK_BYTES,
               (int)(0x41u + chunk_index), CHUNK_BYTES);
    for (sample = 0; sample < TOTAL_PCM_FRAMES; ++sample) {
        pcm[sample * 2u] = (int16_t)(sample * 29u + 3u);
        pcm[sample * 2u + 1u] =
            (int16_t)(0x6000u - sample * 17u);
    }
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.iso_pts_normalization = 1;
    output.audio_pes_seen = 1;
    output.have_audio_pts = 1;
    output.first_audio_pts = first_audio_pts;
    output.have_video_pts = 1;
    output.max_video_pts = first_audio_pts;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_HOLD_DEFAULT_MS * PCM_SAMPLE_RATE / 1000u;
    output.pcm_emitted_frames = PCM_SCHEDULE_RESERVE_FRAMES;
    failed |= require(hold_push(&output, pcm, TOTAL_PCM_FRAMES) == 0,
                      "could not stage audio-forward title PCM");
    failed |= require(queue_video(
                          &output, video, CHUNK_BYTES, 1, 0,
                          first_audio_pts + 45000u) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.video_bytes == 0 &&
                          output.video_queued_bytes == CHUNK_BYTES &&
                          scheduler_future_video_pts(&output) == 1u &&
                          output.title_pts_lookahead_logged,
                      "single future title PTS was not retained");
    for (chunk_index = 1; !failed && chunk_index < CHUNKS;
         ++chunk_index) {
        uint64_t retained_pts = first_audio_pts +
            (uint64_t)(chunk_index + 1u) * 45000u;
        uint64_t admitted_pts = retained_pts - 45000u;
        uint64_t target;
        uint64_t consumed =
            (uint64_t)chunk_index * INTERVAL_FRAMES;
        uint64_t lead;

        failed |= require(queue_video(
                              &output,
                              video + (size_t)chunk_index * CHUNK_BYTES,
                              CHUNK_BYTES, 1, 0, retained_pts) == 0 &&
                              scheduler_drain(&output, 0) == 0,
                          "audio-forward title burst did not schedule");
        target = scheduler_pcm_delivery_target(&output, admitted_pts);
        lead = output.pcm_emitted_frames > consumed ?
               output.pcm_emitted_frames - consumed : 0;
        failed |= require(output.video_bytes ==
                              (uint64_t)chunk_index * CHUNK_BYTES &&
                              output.video_queued_bytes == CHUNK_BYTES &&
                              output.video_head != NULL &&
                              output.video_head->has_pts &&
                              output.video_head->pts == retained_pts &&
                              scheduler_future_video_pts(&output) == 1u &&
                              output.max_video_pts == admitted_pts &&
                              output.pcm_emitted_frames == target &&
                              lead >= PCM_SCHEDULE_RESERVE_FRAMES -
                                          PCM_REFILL_FRAMES &&
                              lead <= PCM_SCHEDULE_RESERVE_FRAMES,
                          "title lookahead did not preserve its 48 kHz "
                          "sink reserve");
    }
    failed |= require(!failed && scheduler_drain_all(&output, 0) == 0 &&
                          output.video_head == NULL &&
                          output.video_queued_bytes == 0 &&
                          output.video_bytes == sizeof(video) &&
                          output.max_video_pts ==
                              first_audio_pts + CHUNKS * 45000u &&
                          output.pcm_emitted_frames ==
                              scheduler_pcm_delivery_target(
                                  &output,
                                  first_audio_pts + CHUNKS * 45000u),
                      "title lookahead force drain did not converge");
    failed |= require(!failed &&
                          compare_fixture_video_and_pcm(
                              output.video, video, sizeof(video), pcm,
                              (size_t)(output.pcm_emitted_frames -
                                       PCM_SCHEDULE_RESERVE_FRAMES)) == 0,
                      "title lookahead changed video bytes or PCM samples");

    while (output.video_head)
        free_video_head(&output);
    free(output.hold);
    fclose(output.video);
    return failed ? -1 : 0;
}

struct title_reserve_capture {
    int fd;
    uint8_t *data;
    size_t size;
    unsigned delay_us;
    int failed;
};

static void *title_reserve_reader(void *opaque)
{
    struct title_reserve_capture *capture = opaque;
    struct timespec delay = {
        capture->delay_us / 1000000u,
        (long)(capture->delay_us % 1000000u) * 1000l
    };
    size_t offset = 0;

    while (nanosleep(&delay, &delay) < 0 && errno == EINTR)
        ;
    while (offset < capture->size) {
        ssize_t count = read(capture->fd, capture->data + offset,
                             capture->size - offset);

        if (count > 0) {
            offset += (size_t)count;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        capture->failed = 1;
        break;
    }
    return NULL;
}

static int test_title_pcm_prompt_delivery(void)
{
    enum {
        PRIOR_VIDEO_BYTES = OUTPUT_RESERVE_BYTES,
        PCM_FRAMES = PCM_SCHEDULE_BATCH_FRAMES,
        PCM_BYTES = PCM_FRAMES * 4u +
                    PCM_FRAMES / PCM_RECORD_FRAMES * 5u,
        LATER_VIDEO_BYTES = 4096,
        CAPTURE_BYTES = PRIOR_VIDEO_BYTES + PCM_BYTES + LATER_VIDEO_BYTES
    };
    struct title_reserve_capture capture = {0};
    struct output_state output = {0};
    pthread_t reader;
    uint8_t *prior_video = NULL;
    uint8_t *expected_video = NULL;
    int16_t *pcm = NULL;
    FILE *captured = NULL;
    int descriptors[2] = {-1, -1};
    uint64_t started;
    uint64_t finished;
    size_t offset;
    int reader_started = 0;
    int failed = 0;

    prior_video = malloc(PRIOR_VIDEO_BYTES);
    expected_video = malloc(PRIOR_VIDEO_BYTES + LATER_VIDEO_BYTES);
    pcm = malloc(PCM_FRAMES * 2u * sizeof(*pcm));
    capture.data = malloc(CAPTURE_BYTES);
    captured = tmpfile();
    failed |= require(prior_video != NULL && expected_video != NULL &&
                          pcm != NULL && capture.data != NULL &&
                          captured != NULL && pipe(descriptors) == 0,
                      "could not create title prompt-delivery fixture");
    if (failed)
        goto done;
    memset(prior_video, 0x55, PRIOR_VIDEO_BYTES);
    memcpy(expected_video, prior_video, PRIOR_VIDEO_BYTES);
    memset(expected_video + PRIOR_VIDEO_BYTES, 0x66,
           LATER_VIDEO_BYTES);
    for (offset = 0; offset < PCM_FRAMES; ++offset) {
        pcm[offset * 2u] = (int16_t)(offset * 31u + 7u);
        pcm[offset * 2u + 1u] =
            (int16_t)(0x5000u - offset * 19u);
    }
    capture.fd = descriptors[0];
    capture.size = CAPTURE_BYTES;
    capture.delay_us = 100000u;
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.iso_pts_normalization = 1;
    output.audio_pes_seen = 1;
    output.have_audio_pts = 1;
    output.first_audio_pts = 90000u;
    output.have_video_pts = 1;
    output.max_video_pts = 135000u;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_HOLD_DEFAULT_MS * PCM_SAMPLE_RATE / 1000u;
    failed |= require(output_reserve_create(
                          &output.reserve, descriptors[1],
                          OUTPUT_RESERVE_BYTES) == 0,
                      "could not create title output reserve");
    for (offset = 0; !failed && offset < PRIOR_VIDEO_BYTES;
         offset += 65536u) {
        failed |= require(write_video_immediate(
                              &output, prior_video + offset, 65536u,
                              "prompt-delivery prior video") == 0,
                          "could not populate title output reserve");
    }
    failed |= require(!failed && hold_push(&output, pcm, PCM_FRAMES) == 0 &&
                          pthread_create(&reader, NULL,
                                         title_reserve_reader,
                                         &capture) == 0,
                      "could not start prompt-delivery sink");
    if (failed)
        goto done;
    reader_started = 1;
    started = monotonic_us();
    failed |= require(started != 0 &&
                          scheduler_emit_pcm(&output, PCM_FRAMES) == 0,
                      "title PCM prompt delivery failed");
    finished = monotonic_us();
    failed |= require(finished >= started &&
                          finished - started >= 50000u &&
                          output.title_pcm_prompt_logged &&
                          output.pcm_emitted_frames == PCM_FRAMES &&
                          hold_available(&output) == 0,
                      "title PCM did not wait for the backpressured reserve");
    failed |= require(write_video_immediate(
                          &output,
                          expected_video + PRIOR_VIDEO_BYTES,
                          LATER_VIDEO_BYTES,
                          "prompt-delivery later video") == 0,
                      "could not queue video after prompt PCM");
    failed |= require(output_reserve_destroy(output.reserve) == 0,
                      "could not drain title prompt-delivery output");
    output.reserve = NULL;
    close(descriptors[1]);
    descriptors[1] = -1;
    pthread_join(reader, NULL);
    reader_started = 0;
    failed |= require(!capture.failed &&
                          fwrite(capture.data, 1, CAPTURE_BYTES, captured) ==
                              CAPTURE_BYTES &&
                          compare_fixture_video_and_pcm(
                              captured, expected_video,
                              PRIOR_VIDEO_BYTES + LATER_VIDEO_BYTES,
                              pcm, PCM_FRAMES) == 0,
                      "prompt delivery changed reserve, PCM or video order");

done:
    if (output.reserve) {
        size_t discarded;

        (void)output_reserve_discard(output.reserve, &discarded);
        (void)output_reserve_destroy(output.reserve);
    }
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    if (reader_started)
        pthread_join(reader, NULL);
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    if (captured)
        fclose(captured);
    free(output.hold);
    free(capture.data);
    free(pcm);
    free(expected_video);
    free(prior_video);
    return failed ? -1 : 0;
}

static int test_title_pts_lookahead_pressure(void)
{
    const size_t payload_size = VIDEO_QUEUE_LIMIT - 64u;
    struct output_state output = {0};
    uint8_t *payload = NULL;
    int failed = 0;

    payload = malloc(payload_size);
    output.video = tmpfile();
    failed |= require(payload != NULL && output.video != NULL,
                      "could not create title-lookahead pressure fixture");
    if (failed)
        goto done;
    memset(payload, 0x55, payload_size);
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.iso_pts_normalization = 1;
    output.audio_pes_seen = 1;
    output.have_audio_pts = 1;
    output.first_audio_pts = 90000u;
    output.have_video_pts = 1;
    output.max_video_pts = 90000u;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_HOLD_DEFAULT_MS * PCM_SAMPLE_RATE / 1000u;
    output.pcm_emitted_frames = PCM_SCHEDULE_RESERVE_FRAMES;
    failed |= require(queue_video(&output, payload, payload_size,
                                  0, 0, 0) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.video_bytes == 0 &&
                          output.video_queued_bytes == payload_size &&
                          scheduler_future_video_pts(&output) == 0u,
                      "timestamp-poor title did not retain bounded input");
    failed |= require(!failed &&
                          scheduler_make_title_video_room(
                              &output, 65u, 0) == 0 &&
                          output.video_head == NULL &&
                          output.video_queued_bytes == 0 &&
                          output.video_bytes == payload_size,
                      "title queue pressure did not force bounded progress");
    failed |= require(!failed && compare_fixture_video_and_pcm(
                          output.video, payload, payload_size,
                          NULL, 0) == 0,
                      "title pressure fallback changed video bytes");

done:
    while (output.video_head)
        free_video_head(&output);
    if (output.video)
        fclose(output.video);
    free(payload);
    return failed ? -1 : 0;
}

static int test_pcm_pressure_menu_activation_continuation(void)
{
    static const uint8_t staged_marker[] = {0x91, 0x82, 0x73, 0x64};
    static const uint64_t prior_pts = 900000u;
    static const uint64_t activation_pts = 45000u;
    static const uint64_t continued_pts = prior_pts + 1u;
    enum {
        PAYLOAD_BYTES = 32768,
        HOLD_LIMIT_FRAMES = 16384,
        EXTRA_PCM_FRAMES = 4096,
        TOTAL_PCM_FRAMES = HOLD_LIMIT_FRAMES + EXTRA_PCM_FRAMES,
        EXPECTED_EMITTED_FRAMES = HOLD_LIMIT_FRAMES -
            PCM_SCHEDULE_RESERVE_FRAMES + EXTRA_PCM_FRAMES
    };
    struct dvd_menu_state menu = {0};
    struct audio_state audio = {0};
    struct output_state output = {0};
    struct media_source input = {0};
    uint8_t private_pes[] = {
        0x00, 0x12,
        0x80, 0x80, 0x05, 0, 0, 0, 0, 0,
        0x80, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    uint8_t *payload = NULL;
    uint8_t *expected_video = NULL;
    int16_t *pcm = NULL;
    uint8_t event = 0;
    uint64_t queued_pts = 0;
    int descriptors[2] = {-1, -1};
    char input_path[] = "/tmp/mmp-menu-pcm-pressure-XXXXXX";
    char source_error[128];
    int input_fd = -1;
    int input_open = 0;
    size_t offset;
    int failed = 0;

    payload = malloc(PAYLOAD_BYTES);
    expected_video = malloc(sizeof(staged_marker) + 9u + PAYLOAD_BYTES);
    pcm = malloc((size_t)TOTAL_PCM_FRAMES * 2u * sizeof(*pcm));
    output.video = tmpfile();
    failed |= require(payload != NULL && expected_video != NULL &&
                          pcm != NULL && output.video != NULL &&
                          pipe(descriptors) == 0,
                      "could not allocate PCM-pressure activation fixture");
    if (failed)
        goto done;
    memset(payload, 0x55, PAYLOAD_BYTES);
    for (offset = 0; offset < TOTAL_PCM_FRAMES; ++offset) {
        pcm[offset * 2u] = (int16_t)(offset * 31u + 7u);
        pcm[offset * 2u + 1u] = (int16_t)(0x5000u - offset * 19u);
    }
    output.hold_limit = HOLD_LIMIT_FRAMES;
    output.iso_pts_normalization = 1;
    output.have_iso_video_pts = 1;
    output.iso_pts_raw_max = prior_pts;
    output.iso_pts_normalized_max = prior_pts;
    menu.enabled = 1;
    menu.menu_active = 1;
    audio.a52_substream = -1;
    audio.dts_substream = -1;
    failed |= require(output_stage_create(&output.activation_stage,
                                          OUTPUT_ACTIVATION_STAGE_BYTES) == 0 &&
                          start_pending_menu_activation(
                              &menu, &audio, &output) == 0,
                      "could not start PCM-pressure activation stage");
    failed |= require(write_output_priority(
                          &output, staged_marker, sizeof(staged_marker),
                          "PCM-pressure marker") == 0 &&
                          normalize_video_pts(
                              &output, activation_pts, &queued_pts) == 0 &&
                          queue_h262_video(
                              &output, payload, PAYLOAD_BYTES, 1, 1,
                              queued_pts) == 0 &&
                          iso_filter_initial_random_access(&output, 0) == 0 &&
                          output.iso_start_filter_active &&
                          !video_queue_would_overflow(&output, 0, 0),
                      "PCM-pressure fixture reached video pressure");
    failed |= require(write_pcm(
                          &output, pcm, HOLD_LIMIT_FRAMES, 2,
                          PCM_SAMPLE_RATE) == 0 &&
                          hold_available(&output) == HOLD_LIMIT_FRAMES &&
                          output.pcm_emitted_frames == 0,
                      "PCM-pressure fixture did not reach its hold ceiling");
    encode_pes_pts(private_pes + 5, activation_pts);
    input_fd = mkstemp(input_path);
    failed |= require(input_fd >= 0 &&
                          write(input_fd, private_pes,
                                sizeof(private_pes)) ==
                              (ssize_t)sizeof(private_pes) &&
                          close(input_fd) == 0,
                      "could not create PCM-pressure AC-3 PES");
    input_fd = -1;
    failed |= require(!failed &&
                          media_source_open(&input, input_path, source_error,
                                            sizeof(source_error)) ==
                              MEDIA_SOURCE_OK,
                      "could not open PCM-pressure AC-3 PES");
    input_open = !failed;
    failed |= require(!failed &&
                          process_private_pes(
                              &input, &audio, &output, &menu,
                              descriptors[1]) == 0 &&
                          !menu.activation_pending &&
                          menu.activation_followup_pending &&
                          !output_stage_active(output.activation_stage) &&
                          !output.iso_start_filter_active &&
                          output.automatic_menu_epoch &&
                          output.scheduler_started && !output.hold_active &&
                          output.video_head == NULL &&
                          output.video_queued_bytes == 0 &&
                          output.max_video_pts == continued_pts &&
                          output.first_audio_pts == continued_pts &&
                          output.iso_pts_normalized_max == continued_pts &&
                          output.iso_pts_epoch_offset ==
                              continued_pts - activation_pts &&
                          output.pcm_emitted_frames ==
                              PCM_INITIAL_RELEASE_FRAMES &&
                          hold_available(&output) ==
                              HOLD_LIMIT_FRAMES - PCM_INITIAL_RELEASE_FRAMES,
                      "PCM pressure did not promptly commit live pacing");
    failed |= require(read(descriptors[0], &event, sizeof(event)) == 1 &&
                          event == MEDIA_PLAYER_CONTROL_MENU_CONTINUE,
                      "PCM-pressure continuation was not acknowledged");
    failed |= require(write_pcm(
                          &output,
                          pcm + (size_t)HOLD_LIMIT_FRAMES * 2u,
                          EXTRA_PCM_FRAMES, 2, PCM_SAMPLE_RATE) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.automatic_menu_pcm_fallback &&
                          output.pcm_emitted_frames ==
                              EXPECTED_EMITTED_FRAMES &&
                          hold_available(&output) ==
                              scheduler_automatic_menu_pcm_watermark(&output) &&
                          hold_available(&output) < output.hold_limit,
                      "restored automatic-menu pacing did not bound PCM");
    failed |= require(flush_h262_video(&output) == 0 &&
                          scheduler_drain(&output, 0) == 0,
                      "PCM-pressure continuation did not flush exact video");
    memcpy(expected_video, staged_marker, sizeof(staged_marker));
    encode_video_pts(expected_video + sizeof(staged_marker), continued_pts);
    memcpy(expected_video + sizeof(staged_marker) + 9u,
           payload, PAYLOAD_BYTES);
    failed |= require(compare_fixture_video_and_pcm(
                          output.video, expected_video,
                          sizeof(staged_marker) + 9u + PAYLOAD_BYTES,
                          pcm, EXPECTED_EMITTED_FRAMES) == 0,
                      "PCM-pressure continuation changed output order");

done:
    if (input_open)
        media_source_close(&input);
    if (input_fd >= 0)
        close(input_fd);
    unlink(input_path);
    while (output.video_head)
        free_video_head(&output);
    free(output.hold);
    output_stage_destroy(output.activation_stage);
    if (output.video)
        fclose(output.video);
    if (descriptors[0] >= 0)
        close(descriptors[0]);
    if (descriptors[1] >= 0)
        close(descriptors[1]);
    free(pcm);
    free(expected_video);
    free(payload);
    return failed;
}

static int test_automatic_menu_scheduling_epoch(void)
{
    uint8_t private_pes[] = {
        0x00, 0x12,
        0x80, 0x80, 0x05, 0, 0, 0, 0, 0,
        0x80, 0x00, 0x00, 0x01,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    struct output_state output = {0};
    struct audio_state audio = {0};
    struct media_source input = {0};
    uint8_t *first_play = NULL;
    uint8_t *menu_video = NULL;
    int16_t *pcm = NULL;
    char input_path[] = "/tmp/mmp-menu-epoch-XXXXXX";
    char source_error[128];
    size_t first_play_size = VIDEO_QUEUE_LIMIT - 8u;
    size_t menu_video_size = VIDEO_QUEUE_LIMIT + 65536u;
    size_t offset;
    size_t pcm_offset;
    uint64_t menu_pts = 0;
    int input_fd = -1;
    int input_open = 0;
    int failed = 0;

    first_play = malloc(first_play_size);
    menu_video = malloc(menu_video_size);
    pcm = malloc(200000u * sizeof(*pcm));
    output.video = tmpfile();
    failed |= require(first_play != NULL && menu_video != NULL && pcm != NULL &&
                          output.video != NULL,
                      "could not allocate automatic-menu epoch fixture");
    if (failed)
        goto done;
    memset(first_play, 0x5a, first_play_size);
    for (offset = 0; offset < 100000u; ++offset) {
        pcm[offset * 2u] = (int16_t)(offset * 17u + 3u);
        pcm[offset * 2u + 1u] = (int16_t)(0x6000u - offset * 29u);
    }
    memset(menu_video, 0x66, menu_video_size);
    for (offset = 0; offset + 6u <= menu_video_size; offset += 32768u) {
        menu_video[offset] = 0;
        menu_video[offset + 1u] = 0;
        menu_video[offset + 2u] = 1;
        menu_video[offset + 3u] = 0;
        menu_video[offset + 4u] = 0;
        menu_video[offset + 5u] =
            (uint8_t)((offset ? 2u : 1u) << 3);
    }
    output.scheduler_enabled = 1;
    output.hold_active = 1;
    output.hold_limit = PCM_SAMPLE_RATE;
    output.iso_pts_normalization = 1;
    output.h262_chroma_normalization = 1;
    output.have_iso_video_pts = 1;
    output.iso_pts_raw_max = 151777u;
    output.iso_pts_normalized_max = 151777u;
    failed |= require(queue_h262_video(&output, first_play, first_play_size,
                                       1, 0, 151777u) == 0 &&
                          output.h262_chroma.have_pending &&
                          video_queue_would_overflow(&output, 16u, 0) &&
                          scheduler_release_silent_video(&output) == 0 &&
                          !output.h262_chroma.have_pending &&
                          !output.video_head &&
                          output.video_bytes == first_play_size,
                      "silent first-play release lost its H262 lookahead byte");
    failed |= require(fseek(output.video, 0, SEEK_SET) == 0 &&
                          fread(menu_video, 1, first_play_size, output.video) ==
                              first_play_size &&
                          !memcmp(menu_video, first_play, first_play_size),
                      "silent first-play release changed byte order");
    if (failed)
        goto done;
    memset(menu_video, 0x66, menu_video_size);
    for (offset = 0; offset + 6u <= menu_video_size; offset += 32768u) {
        menu_video[offset] = 0;
        menu_video[offset + 1u] = 0;
        menu_video[offset + 2u] = 1;
        menu_video[offset + 3u] = 0;
        menu_video[offset + 4u] = 0;
        menu_video[offset + 5u] =
            (uint8_t)((offset ? 2u : 1u) << 3);
    }
    failed |= require(fflush(output.video) != EOF &&
                          ftruncate(fileno(output.video), 0) == 0 &&
                          fseek(output.video, 0, SEEK_SET) == 0,
                      "could not reset automatic-menu output fixture");

    audio.output = AUDIO_OUT_SPDIF;
    audio.a52_substream = -1;
    audio.dts_substream = -1;
    failed |= require(rearm_for_automatic_menu(&audio, &output) == 0,
                      "automatic menu scheduling rearm failed");
    failed |= require(output.scheduler_enabled &&
                          output.automatic_menu_epoch &&
                          !output.scheduler_started &&
                          !output.iso_start_filter_active &&
                          output.iso_pts_normalization &&
                          output.h262_chroma_normalization &&
                          output.hold_active && !output.silent_video_mode &&
                          !output.audio_pes_seen &&
                          !output.have_audio_pts && !output.have_video_pts &&
                          output.video_bytes == 0 &&
                          output.picture_marks == 0 &&
                          output.iso_pts_rebase_pending &&
                          output.iso_pts_rebase_floor == 151777u,
                      "automatic menu did not preserve decoder continuity");
    failed |= require(normalize_video_pts(&output, 45045u, &menu_pts) == 0 &&
                          menu_pts == 151778u &&
                          output.iso_pts_epoch_offset == 106733u &&
                          !output.iso_pts_rebase_pending,
                      "automatic menu video PTS was not rebased monotonically");
    if (failed)
        goto done;

    for (offset = 0; offset < 65536u; offset += 16384u) {
        failed |= require(queue_h262_video(
                              &output, menu_video + offset, 16384u,
                              1, 0, menu_pts) == 0 &&
                              scheduler_drain(&output, 0) == 0,
                          "sequence-header-free menu startup could not queue");
    }
    if (failed)
        goto done;

    encode_pes_pts(private_pes + 5, 45045u);
    input_fd = mkstemp(input_path);
    failed |= require(input_fd >= 0,
                      "could not create automatic-menu AC-3 fixture");
    if (failed)
        goto done;
    failed |= require(write(input_fd, private_pes, sizeof(private_pes)) ==
                          (ssize_t)sizeof(private_pes) &&
                          close(input_fd) == 0,
                      "could not write automatic-menu AC-3 fixture");
    input_fd = -1;
    if (failed)
        goto done;
    failed |= require(media_source_open(&input, input_path, source_error,
                                        sizeof(source_error)) ==
                          MEDIA_SOURCE_OK,
                      "could not open automatic-menu AC-3 fixture");
    if (failed)
        goto done;
    input_open = 1;
    unlink(input_path);
    input_path[0] = '\0';
    failed |= require(process_private_pes(&input, &audio, &output, NULL,
                                          -1) == 0 &&
                          audio.codec == AUDIO_CODEC_AC3 &&
                          audio.a52_substream == 0x80 &&
                          audio.size == 6u &&
                          output.audio_pes_seen && output.have_audio_pts &&
                          output.first_audio_pts == menu_pts &&
                          output.scheduler_enabled &&
                          !output.silent_video_mode,
                      "fresh menu epoch did not accept synchronized AC-3");
    pcm_offset = 0;
    for (offset = 65536u; offset < menu_video_size; offset += 32768u) {
        size_t count = menu_video_size - offset;
        size_t pcm_count = 100000u - pcm_offset;

        if (count > 32768u)
            count = 32768u;
        if (pcm_count > 1536u)
            pcm_count = 1536u;
        failed |= require(queue_h262_video(
                              &output, menu_video + offset, count,
                              1, 0, menu_pts) == 0 &&
                              write_pcm(&output, pcm + pcm_offset * 2u,
                                        (int)pcm_count, 2,
                                        PCM_SAMPLE_RATE) == 0,
                          "long menu PCM and video could not queue");
        if (output.automatic_menu_pcm_fallback)
            output.automatic_menu_pcm_clock_start_us -=
                (uint64_t)pcm_count * 1000000u / PCM_SAMPLE_RATE;
        failed |= require(!failed &&
                              scheduler_drain(&output, 0) == 0 &&
                              hold_available(&output) <= output.hold_limit,
                          "long menu PCM and video did not drain boundedly");
        if (failed)
            goto done;
        pcm_offset += pcm_count;
    }
    while (pcm_offset < 100000u) {
        size_t pcm_count = 100000u - pcm_offset;

        if (pcm_count > 1536u)
            pcm_count = 1536u;
        failed |= require(write_pcm(&output, pcm + pcm_offset * 2u,
                                    (int)pcm_count, 2,
                                    PCM_SAMPLE_RATE) == 0,
                          "automatic menu PCM tail could not queue");
        if (output.automatic_menu_pcm_fallback)
            output.automatic_menu_pcm_clock_start_us -=
                (uint64_t)pcm_count * 1000000u / PCM_SAMPLE_RATE;
        failed |= require(!failed &&
                              scheduler_drain(&output, 0) == 0 &&
                              hold_available(&output) <= output.hold_limit,
                          "automatic menu PCM tail did not drain boundedly");
        if (failed)
            goto done;
        pcm_offset += pcm_count;
    }
    failed |= require(output.automatic_menu_pcm_fallback &&
                          output.automatic_menu_stalled_pts > 0 &&
                          hold_available(&output) ==
                              scheduler_automatic_menu_pcm_watermark(&output) &&
                          output.pcm_emitted_frames ==
                              100000u -
                              scheduler_automatic_menu_pcm_watermark(&output) &&
                          output.automatic_menu_pcm_fallback_frames > 0,
                      "nonadvancing menu PTS did not continuously drain PCM");
    failed |= require(flush_h262_video(&output) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          !output.video_head &&
                          output.video_queued_bytes == 0 &&
                          output.video_peak_bytes < VIDEO_QUEUE_LIMIT,
                      "long automatic menu retained bounded video");
    failed |= require(compare_fixture_video_and_pcm(
                          output.video, menu_video, menu_video_size, pcm,
                          (size_t)output.pcm_emitted_frames) == 0,
                      "automatic menu changed continuous H262 or PCM bytes");

done:
    if (input_fd >= 0)
        close(input_fd);
    if (input_path[0])
        unlink(input_path);
    if (input_open)
        media_source_close(&input);
    while (output.video_head)
        free_video_head(&output);
    free(output.hold);
    free(audio.data);
    if (audio.a52)
        a52_free(audio.a52);
    if (output.video)
        fclose(output.video);
    free(first_play);
    free(menu_video);
    free(pcm);
    return failed ? -1 : 0;
}

static int test_automatic_menu_advancing_pts_schedule(void)
{
    struct output_state output = {0};
    struct video_chunk advancing = {0};
    int16_t pcm[12000u * 2u];
    size_t i;
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create advancing-PTS control fixture");
    if (failed)
        return -1;
    for (i = 0; i < 12000u * 2u; ++i)
        pcm[i] = (int16_t)(i * 11u + 7u);
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.automatic_menu_epoch = 1;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_SAMPLE_RATE;
    output.have_audio_pts = 1;
    output.first_audio_pts = 90000u;
    output.have_video_pts = 1;
    output.max_video_pts = 180000u;
    output.automatic_menu_stalled_pts = 7;
    output.automatic_menu_pcm_fallback = 1;
    output.automatic_menu_pcm_fallback_frames = 1234u;
    output.automatic_menu_pcm_fallback_initial_frames = 1024u;
    output.automatic_menu_pcm_clock_start_us = 1u;
    advancing.has_pts = 1;
    advancing.pts = 180001u;
    scheduler_accept_video_pts(&output, &advancing);
    failed |= require(!output.automatic_menu_stalled_pts &&
                          !output.automatic_menu_pcm_fallback &&
                          !output.automatic_menu_pcm_fallback_frames &&
                          !output.automatic_menu_pcm_fallback_initial_frames &&
                          !output.automatic_menu_pcm_clock_start_us &&
                          output.max_video_pts == 180001u,
                      "advancing menu PTS did not restore normal scheduling");
    failed |= require(hold_push(&output, pcm, 12000) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.pcm_emitted_frames ==
                              PCM_SCHEDULE_BATCH_FRAMES &&
                          hold_available(&output) ==
                              12000u - PCM_SCHEDULE_BATCH_FRAMES &&
                          !output.automatic_menu_pcm_fallback,
                      "advancing menu PTS changed timestamp scheduling");
    free(output.hold);
    fclose(output.video);
    return failed ? -1 : 0;
}

static int test_automatic_menu_pcm_batch_pacing(void)
{
    struct output_state output = {0};
    enum {
        FIRST_BURST = 48000,
        SECOND_BURST = 12000,
        CEILING_BURST = 24001,
        TOTAL_FRAMES = FIRST_BURST + SECOND_BURST + CEILING_BURST
    };
    int16_t pcm[TOTAL_FRAMES * 2u];
    size_t watermark;
    uint64_t before_fast_burst;
    uint64_t fast_burst_frames;
    size_t expected_frames = 60001u;
    size_t i;
    int failed = 0;

    output.video = tmpfile();
    failed |= require(output.video != NULL,
                      "could not create automatic-menu pacing output");
    if (failed)
        return -1;
    failed |= require(output_reserve_create(&output.reserve,
                                            fileno(output.video),
                                            OUTPUT_RESERVE_BYTES) == 0,
                      "could not create automatic-menu pacing reserve");
    if (failed)
        goto done;
    for (i = 0; i < TOTAL_FRAMES; ++i) {
        pcm[i * 2u] = (int16_t)(i * 23u + 5u);
        pcm[i * 2u + 1u] = (int16_t)(0x5000u - i * 31u);
    }
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.automatic_menu_epoch = 1;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_SAMPLE_RATE;
    output.have_audio_pts = 1;
    output.first_audio_pts = 90000u;
    output.have_video_pts = 1;
    output.max_video_pts = 90000u;
    output.pcm_emitted_frames = PCM_SCHEDULE_RESERVE_FRAMES;
    watermark = scheduler_automatic_menu_pcm_watermark(&output);
    failed |= require(watermark == PCM_SAMPLE_RATE / 2u &&
                          hold_push(&output, pcm, FIRST_BURST) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.automatic_menu_pcm_fallback &&
                          output.automatic_menu_pcm_fallback_frames ==
                              FIRST_BURST - watermark &&
                          output.automatic_menu_pcm_fallback_initial_frames ==
                              FIRST_BURST - watermark &&
                          output.automatic_menu_pcm_clock_start_us != 0 &&
                          output.pcm_emitted_frames ==
                              PCM_SCHEDULE_RESERVE_FRAMES +
                                  FIRST_BURST - watermark &&
                          hold_available(&output) ==
                              watermark,
                      "fallback pass did not reach its PCM watermark");
    before_fast_burst = output.automatic_menu_pcm_fallback_frames;
    failed |= require(hold_push(&output, pcm + FIRST_BURST * 2u,
                                SECOND_BURST) == 0 &&
                          scheduler_drain(&output, 0) == 0 &&
                          output.automatic_menu_pcm_fallback_frames >=
                              before_fast_burst,
                      "clocked fallback rejected a fast PCM burst");
    fast_burst_frames = output.automatic_menu_pcm_fallback_frames -
                        before_fast_burst;
    failed |= require(fast_burst_frames <= PCM_SAMPLE_RATE / 10u &&
                          hold_available(&output) ==
                              watermark + SECOND_BURST - fast_burst_frames,
                      "unadvanced fallback clock drained source-rate PCM");
    output.automatic_menu_pcm_clock_start_us -= 250000u;
    failed |= require(scheduler_drain(&output, 0) == 0 &&
                          hold_available(&output) == watermark &&
                          output.automatic_menu_pcm_fallback_frames ==
                              FIRST_BURST - watermark + SECOND_BURST &&
                          output.pcm_emitted_frames ==
                              PCM_SCHEDULE_RESERVE_FRAMES + FIRST_BURST -
                                  watermark + SECOND_BURST,
                      "elapsed fallback clock did not admit its exact budget");
    failed |= require(hold_push(
                          &output,
                          pcm + (FIRST_BURST + SECOND_BURST) * 2u,
                          CEILING_BURST) == 0 &&
                          hold_available(&output) ==
                              output.hold_limit + 1u,
                      "clocked fallback did not reach its hard ceiling");
    output.automatic_menu_pcm_clock_start_us -= 500021u;
    failed |= require(scheduler_drain(&output, 0) == 0 &&
                          hold_available(&output) == watermark &&
                          hold_available(&output) <= output.hold_limit &&
                          output.automatic_menu_pcm_fallback_frames ==
                              expected_frames &&
                          output.pcm_emitted_frames ==
                              PCM_SCHEDULE_RESERVE_FRAMES + expected_frames,
                      "clocked fallback did not throttle at its PCM ceiling");
    if (output.reserve) {
        failed |= require(output_reserve_destroy(output.reserve) == 0,
                          "paced fallback reserve did not drain");
        output.reserve = NULL;
    }
    failed |= require(compare_fixture_video_and_pcm(
                          output.video, NULL, 0, pcm,
                          expected_frames) == 0,
                      "paced fallback changed PCM samples or framing");

done:
    if (output.reserve) {
        (void)output_reserve_destroy(output.reserve);
        output.reserve = NULL;
    }
    free(output.hold);
    fclose(output.video);
    return failed ? -1 : 0;
}

static int test_automatic_menu_pcm_hold_limit(void)
{
    struct output_state output = {0};
    int16_t *pcm;
    int failed = 0;

    pcm = calloc((PCM_SAMPLE_RATE + 1u) * 2u, sizeof(*pcm));
    output.video = tmpfile();
    failed |= require(pcm != NULL && output.video != NULL,
                      "could not create automatic-menu hold-limit fixture");
    if (failed)
        goto done;
    output.scheduler_enabled = 1;
    output.scheduler_started = 1;
    output.automatic_menu_epoch = 1;
    output.hold_rate_hz = PCM_SAMPLE_RATE;
    output.hold_limit = PCM_SAMPLE_RATE;
    output.have_audio_pts = 1;
    output.first_audio_pts = 90000u;
    output.have_video_pts = 1;
    output.max_video_pts = 180000u;
    output.pcm_emitted_frames =
        scheduler_pcm_delivery_target(&output, output.max_video_pts);
    failed |= require(hold_push(&output, pcm, PCM_SAMPLE_RATE + 1u) == 0 &&
                          scheduler_drain(&output, 0) < 0,
                      "automatic-menu PCM hold limit was not enforced");

done:
    free(output.hold);
    if (output.video)
        fclose(output.video);
    free(pcm);
    return failed ? -1 : 0;
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
    failed |= test_h262_stream_chroma_normalization();
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
    if (test_unqualified_menu_activation_continuation())
        return 1;
    if (test_pcm_pressure_menu_activation_continuation())
        return 1;
    if (test_provisional_menu_activation_followup())
        return 1;
    if (test_late_audio_after_silent_release())
        return 1;
    if (test_audio_forward_title_pts_lookahead())
        return 1;
    if (test_title_pcm_prompt_delivery())
        return 1;
    if (test_title_pts_lookahead_pressure())
        return 1;
    if (test_automatic_menu_scheduling_epoch())
        return 1;
    if (test_automatic_menu_advancing_pts_schedule())
        return 1;
    if (test_automatic_menu_pcm_batch_pacing())
        return 1;
    if (test_automatic_menu_pcm_hold_limit())
        return 1;
    puts("DVD overlay output: exact plane and reserve ownership pass");
    return 0;
}
