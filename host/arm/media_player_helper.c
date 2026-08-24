#define _POSIX_C_SOURCE 200809L
#define MINIMP3_IMPLEMENTATION
#define MINIMP3_NO_SIMD

#include "minimp3.h"
#include "media_player_protocol.h"
#include "media_source.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define AUDIO_BUFFER_LIMIT (256u * 1024u)

struct output_state {
    FILE *video;
    FILE *pcm;
    uint64_t video_bytes;
    uint64_t pcm_frames;
    unsigned video_pts;
    unsigned audio_frames;
};

struct audio_state {
    mp3dec_t decoder;
    uint8_t *data;
    size_t size;
    size_t capacity;
};

static void usage(const char *program)
{
    fprintf(stderr,
            "usage: %s [--protocol 1] [--source SOURCE | INPUT] "
            "[--pcm-out FILE] [--video-out FILE]\n"
            "       %s --capabilities\n",
            program,
            program);
}

static int write_all(FILE *stream, const void *data, size_t size,
                     const char *what)
{
    if (size && fwrite(data, 1, size, stream) != size) {
        fprintf(stderr, "media_player_helper: writing %s failed: %s\n",
                what, strerror(errno));
        return -1;
    }
    return 0;
}

static int read_exact(struct media_source *source, void *data, size_t size)
{
    return media_source_read(source, data, size) == size ? 0 : -1;
}

static int skip_bytes(struct media_source *source, size_t size)
{
    uint8_t scratch[4096];

    while (size) {
        size_t chunk = size < sizeof(scratch) ? size : sizeof(scratch);
        if (read_exact(source, scratch, chunk) < 0)
            return -1;
        size -= chunk;
    }
    return 0;
}

static int find_start_code(struct media_source *source, uint8_t *code)
{
    unsigned state = 0xffffff;
    int value;

    while ((value = media_source_getc(source)) != EOF) {
        state = ((state << 8) | (unsigned)(uint8_t)value) & 0xffffff;
        if (state == 0x000001) {
            value = media_source_getc(source);
            if (value == EOF)
                return -1;
            *code = (uint8_t)value;
            return 1;
        }
    }
    return media_source_error(source) ? -1 : 0;
}

static uint64_t decode_pts(const uint8_t *p)
{
    return ((uint64_t)(p[0] & 0x0e) << 29) |
           ((uint64_t)p[1] << 22) |
           ((uint64_t)(p[2] & 0xfe) << 14) |
           ((uint64_t)p[3] << 7) |
           ((uint64_t)p[4] >> 1);
}

static int emit_video_pts(struct output_state *output, uint64_t pts)
{
    uint8_t record[9] = {0, 0, 1, MEDIA_PLAYER_PTS_MARKER_CODE};
    uint64_t value = ((pts & 0x1ffffffffULL) << 7) | (3u << 5) | (1u << 2);
    int i;

    for (i = 8; i >= 4; --i) {
        record[i] = (uint8_t)value;
        value >>= 8;
    }
    if (write_all(output->video, record, sizeof(record), "video timestamp") < 0)
        return -1;
    output->video_bytes += sizeof(record);
    output->video_pts++;
    return 0;
}

static int emit_pcm_sample(struct output_state *output,
                           mp3d_sample_t left, mp3d_sample_t right)
{
    uint16_t left_bits = (uint16_t)left;
    uint16_t right_bits = (uint16_t)right;
    uint8_t record[9] = {
        0, 0, 1, MEDIA_PLAYER_PCM_MARKER_CODE,
        MEDIA_PLAYER_PCM_MODE_48K_STEREO,
        (uint8_t)(left_bits >> 8), (uint8_t)left_bits,
        (uint8_t)(right_bits >> 8), (uint8_t)right_bits
    };

    return write_all(output->video, record, sizeof(record), "in-band PCM");
}

static int emit_pcm_end(struct output_state *output)
{
    const uint8_t record[4] = {0, 0, 1, MEDIA_PLAYER_PCM_END_MARKER_CODE};
    return write_all(output->video, record, sizeof(record), "PCM end marker");
}

static int write_pcm(struct output_state *output, const mp3d_sample_t *samples,
                     int samples_per_channel, int channels)
{
    mp3d_sample_t stereo[MINIMP3_MAX_SAMPLES_PER_FRAME * 2];
    const mp3d_sample_t *source = samples;
    int i;

    if (channels == 1) {
        for (i = 0; i < samples_per_channel; ++i) {
            stereo[i * 2] = samples[i];
            stereo[i * 2 + 1] = samples[i];
        }
        source = stereo;
        channels = 2;
    }
    if (output->pcm) {
        size_t total = (size_t)samples_per_channel * (size_t)channels;
        if (write_all(output->pcm, source, total * sizeof(*source), "PCM") < 0)
            return -1;
    } else {
        for (i = 0; i < samples_per_channel; ++i) {
            if (emit_pcm_sample(output, source[i * 2], source[i * 2 + 1]) < 0)
                return -1;
        }
    }
    output->pcm_frames += (uint64_t)samples_per_channel;
    output->audio_frames++;
    return 0;
}

static int decode_audio_buffer(struct audio_state *audio,
                               struct output_state *output, int at_eof)
{
    size_t original_size = audio->size;
    size_t offset = 0;

    while (offset < original_size) {
        mp3dec_t decoder_before = audio->decoder;
        mp3dec_frame_info_t info;
        mp3d_sample_t pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];
        int samples = mp3dec_decode_frame(&audio->decoder,
                                          audio->data + offset,
                                          (int)(original_size - offset),
                                          pcm, &info);
        if (!info.frame_bytes) {
            if (!at_eof)
                audio->decoder = decoder_before;
            break;
        }
        /*
         * minimp3 accepts an exact-sized final frame without a following
         * header, but a later incremental call can then fail its next-header
         * comparison and clear the synthesis history.  Do not commit either
         * the bytes or speculative decoder state until following input proves
         * that the frame was not merely the current end of the stream.
         */
        if (!at_eof &&
            offset + (size_t)info.frame_bytes >= original_size) {
            audio->decoder = decoder_before;
            break;
        }
        offset += (size_t)info.frame_bytes;
        if (offset > original_size)
            offset = original_size;
        if (!samples)
            continue;
        if (info.layer != 2) {
            fprintf(stderr, "media_player_helper: unsupported MPEG audio layer %d\n",
                    info.layer);
            return -1;
        }
        if (info.hz != 48000 || (info.channels != 1 && info.channels != 2)) {
            fprintf(stderr,
                    "media_player_helper: unsupported audio format: %d Hz, %d channels\n",
                    info.hz, info.channels);
            return -1;
        }
        if (write_pcm(output, pcm, samples, info.channels) < 0)
            return -1;
    }
    if (offset) {
        memmove(audio->data, audio->data + offset, audio->size - offset);
        audio->size -= offset;
    }
    if (at_eof && audio->size) {
        fprintf(stderr,
                "media_player_helper: truncated or undecodable audio tail (%zu bytes)\n",
                audio->size);
        return -1;
    }
    return 0;
}

static int append_audio(struct audio_state *audio, struct output_state *output,
                        const uint8_t *data, size_t size)
{
    size_t needed = audio->size + size;
    uint8_t *replacement;

    if (needed > AUDIO_BUFFER_LIMIT) {
        fprintf(stderr, "media_player_helper: audio buffer limit exceeded\n");
        return -1;
    }
    if (needed > audio->capacity) {
        size_t capacity = audio->capacity ? audio->capacity : 8192;
        while (capacity < needed)
            capacity *= 2;
        replacement = realloc(audio->data, capacity);
        if (!replacement) {
            fprintf(stderr, "media_player_helper: out of memory\n");
            return -1;
        }
        audio->data = replacement;
        audio->capacity = capacity;
    }
    memcpy(audio->data + audio->size, data, size);
    audio->size += size;
    return decode_audio_buffer(audio, output, 0);
}

static int parse_pes_header(const uint8_t *packet, size_t size,
                            size_t *payload_offset, uint64_t *pts,
                            int *has_pts)
{
    size_t pos = 0;

    *has_pts = 0;
    if (!size)
        return -1;
    if ((packet[0] & 0xc0) == 0x80) {
        size_t header_size;
        if (size < 3)
            return -1;
        header_size = 3u + packet[2];
        if (header_size > size)
            return -1;
        if ((packet[1] & 0x80) != 0) {
            if (packet[2] < 5)
                return -1;
            *pts = decode_pts(packet + 3);
            *has_pts = 1;
        }
        *payload_offset = header_size;
        return 0;
    }

    while (pos < size && packet[pos] == 0xff)
        pos++;
    if (pos < size && (packet[pos] & 0xc0) == 0x40)
        pos += 2;
    if (pos >= size)
        return -1;
    if ((packet[pos] & 0xf0) == 0x20) {
        if (size - pos < 5)
            return -1;
        *pts = decode_pts(packet + pos);
        *has_pts = 1;
        pos += 5;
    } else if ((packet[pos] & 0xf0) == 0x30) {
        if (size - pos < 10)
            return -1;
        *pts = decode_pts(packet + pos);
        *has_pts = 1;
        pos += 10;
    } else if (packet[pos] == 0x0f) {
        pos++;
    } else {
        return -1;
    }
    *payload_offset = pos;
    return 0;
}

static int process_pes(struct media_source *input, uint8_t code,
                       struct audio_state *audio,
                       struct output_state *output, int *video_code,
                       int *audio_code)
{
    uint8_t length_bytes[2];
    uint8_t *packet;
    size_t length;
    size_t payload_offset;
    uint64_t pts = 0;
    int has_pts;
    int result = -1;

    if (read_exact(input, length_bytes, sizeof(length_bytes)) < 0)
        return -1;
    length = ((size_t)length_bytes[0] << 8) | length_bytes[1];
    if (!length) {
        fprintf(stderr,
                "media_player_helper: unbounded PES packets are not supported\n");
        return -1;
    }
    packet = malloc(length);
    if (!packet) {
        fprintf(stderr, "media_player_helper: out of memory\n");
        return -1;
    }
    if (read_exact(input, packet, length) < 0) {
        fprintf(stderr, "media_player_helper: truncated PES packet\n");
        goto done;
    }
    if ((code & 0xf0) == 0xe0) {
        if (*video_code < 0)
            *video_code = code;
        if (*video_code != code) {
            result = 0;
            goto done;
        }
    } else {
        if (*audio_code < 0)
            *audio_code = code;
        if (*audio_code != code) {
            result = 0;
            goto done;
        }
    }
    if (parse_pes_header(packet, length, &payload_offset, &pts, &has_pts) < 0) {
        fprintf(stderr, "media_player_helper: invalid PES header for stream 0x%02x\n",
                code);
        goto done;
    }
    if ((code & 0xf0) == 0xe0) {
        if (has_pts && emit_video_pts(output, pts) < 0)
            goto done;
        if (write_all(output->video, packet + payload_offset,
                      length - payload_offset, "video") < 0)
            goto done;
        output->video_bytes += length - payload_offset;
    } else if ((code & 0xe0) == 0xc0) {
        if (append_audio(audio, output, packet + payload_offset,
                         length - payload_offset) < 0)
            goto done;
    }
    result = 0;
done:
    free(packet);
    return result;
}

static int process_program_stream(struct media_source *input,
                                  struct audio_state *audio,
                                  struct output_state *output)
{
    int video_code = -1;
    int audio_code = -1;

    for (;;) {
        uint8_t code;
        int found = find_start_code(input, &code);
        if (found == 0)
            return 0;
        if (found < 0)
            return -1;
        if (code == 0xb9)
            return 0;
        if (code == 0xba) {
            uint8_t header[10];
            if (read_exact(input, header, 1) < 0)
                return -1;
            if ((header[0] & 0xc0) == 0x40) {
                if (read_exact(input, header + 1, 9) < 0 ||
                    skip_bytes(input, header[9] & 7) < 0)
                    return -1;
            } else if ((header[0] & 0xf0) == 0x20) {
                if (read_exact(input, header + 1, 7) < 0)
                    return -1;
            } else {
                fprintf(stderr, "media_player_helper: invalid pack header\n");
                return -1;
            }
            continue;
        }
        if ((code & 0xf0) == 0xe0 || (code & 0xe0) == 0xc0) {
            if (process_pes(input, code, audio, output,
                            &video_code, &audio_code) < 0)
                return -1;
            continue;
        }
        {
            uint8_t length_bytes[2];
            size_t length;
            if (read_exact(input, length_bytes, sizeof(length_bytes)) < 0)
                return -1;
            length = ((size_t)length_bytes[0] << 8) | length_bytes[1];
            if (skip_bytes(input, length) < 0)
                return -1;
        }
    }
}

static int process_elementary_stream(struct media_source *input,
                                     struct output_state *output)
{
    uint8_t buffer[16384];
    size_t count;

    while ((count = media_source_read(input, buffer, sizeof(buffer))) != 0) {
        if (write_all(output->video, buffer, count, "video") < 0)
            return -1;
        output->video_bytes += count;
    }
    return media_source_error(input) ? -1 : 0;
}

static int finish_output(struct output_state *output, int success)
{
    if (output->video && fflush(output->video) == EOF)
        success = 0;
    if (output->pcm) {
        if (fclose(output->pcm) == EOF)
            success = 0;
        output->pcm = NULL;
    }
    return success ? 0 : 1;
}

int main(int argc, char **argv)
{
    const char *source_specification = NULL;
    const char *pcm_path = NULL;
    const char *video_path = NULL;
    int protocol_version = 0;
    int protocol_requested = 0;
    int show_capabilities = 0;
    struct output_state output = {0};
    struct audio_state audio = {0};
    struct media_source input = {0};
    char source_error[512];
    uint8_t signature[4];
    int is_program_stream;
    int i;
    int success = 0;

    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--pcm-out") && i + 1 < argc) {
            pcm_path = argv[++i];
        } else if (!strcmp(argv[i], "--video-out") && i + 1 < argc) {
            video_path = argv[++i];
        } else if (!strcmp(argv[i], "--protocol") && i + 1 < argc) {
            char *end = NULL;
            long parsed;
            errno = 0;
            parsed = strtol(argv[++i], &end, 10);
            if (errno || !end || *end || parsed < 0 || parsed > INT32_MAX) {
                fprintf(stderr, "media_player_helper: invalid protocol version\n");
                return 2;
            }
            protocol_version = (int)parsed;
            protocol_requested = 1;
        } else if (!strcmp(argv[i], "--source") && i + 1 < argc) {
            if (source_specification) {
                usage(argv[0]);
                return 2;
            }
            source_specification = argv[++i];
        } else if (!strcmp(argv[i], "--capabilities")) {
            show_capabilities = 1;
        } else if (argv[i][0] == '-' || source_specification) {
            usage(argv[0]);
            return 2;
        } else {
            source_specification = argv[i];
        }
    }
    if (protocol_requested &&
        protocol_version != MEDIA_PLAYER_PROTOCOL_VERSION) {
        fprintf(stderr, "media_player_helper: unsupported protocol version %d\n",
                protocol_version);
        return 2;
    }
    if (show_capabilities) {
        if (source_specification || pcm_path || video_path) {
            usage(argv[0]);
            return 2;
        }
        puts(MEDIA_PLAYER_CAPABILITIES);
        return 0;
    }
    if (!source_specification) {
        usage(argv[0]);
        return 2;
    }
    if (media_source_open(&input, source_specification, source_error,
                          sizeof(source_error)) != MEDIA_SOURCE_OK) {
        fprintf(stderr, "media_player_helper: %s\n", source_error);
        return 1;
    }
    output.video = video_path ? fopen(video_path, "wb") : stdout;
    if (!output.video) {
        fprintf(stderr, "media_player_helper: cannot open video output: %s\n",
                strerror(errno));
        media_source_close(&input);
        return 1;
    }
    if (pcm_path) {
        output.pcm = fopen(pcm_path, "wb");
        if (!output.pcm) {
            fprintf(stderr, "media_player_helper: cannot open PCM output: %s\n",
                    strerror(errno));
            goto done;
        }
    }
    mp3dec_init(&audio.decoder);
    if (read_exact(&input, signature, sizeof(signature)) < 0 ||
        media_source_rewind(&input) < 0) {
        fprintf(stderr, "media_player_helper: input is too short\n");
        goto done;
    }
    is_program_stream = !memcmp(signature, "\x00\x00\x01\xba", 4);
    if (is_program_stream) {
        if (process_program_stream(&input, &audio, &output) < 0 ||
            decode_audio_buffer(&audio, &output, 1) < 0)
            goto done;
    } else if (process_elementary_stream(&input, &output) < 0) {
        goto done;
    }
    if (!output.video_bytes) {
        fprintf(stderr, "media_player_helper: no H.262 video stream found\n");
        goto done;
    }
    if (is_program_stream && !output.audio_frames) {
        fprintf(stderr, "media_player_helper: no MPEG Layer II audio found\n");
        goto done;
    }
    success = 1;
    fprintf(stderr,
            "media_player_helper: video=%llu bytes, pts=%u, audio=%u frames/%llu samples\n",
            (unsigned long long)output.video_bytes, output.video_pts,
            output.audio_frames, (unsigned long long)output.pcm_frames);
done:
    free(audio.data);
    media_source_close(&input);
    if (success && output.audio_frames && !output.pcm &&
        emit_pcm_end(&output) < 0)
        success = 0;
    if (video_path && output.video) {
        fclose(output.video);
        output.video = NULL;
    }
    return finish_output(&output, success);
}
