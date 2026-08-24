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
#define VIDEO_QUEUE_LIMIT  (512u * 1024u)
#define PCM_SCHEDULE_RESERVE_FRAMES 4096u
#define PCM_SCHEDULE_BATCH_FRAMES   2048u
#define PCM_INITIAL_RELEASE_FRAMES  4096u
#define PCM_MAX_FREE_VIDEO_BYTES    4096u
#define PCM_REFILL_FRAMES           128u
#define PCM_SINK_FIFO_FRAMES        8192u
#define PTS_MAX_PICTURE_GAP         60u
#define VIDEO_SLICE_BYTES           256u

/*
 * Entry 429: the FPGA gates its whole in-band byte path on the PCM sink, so a
 * decoded sample emitted the moment it exists throttles the video bytes behind
 * it to real time.  A short initial PCM hold lets the first picture cross that
 * path before audio starts.  Steady state then uses bounded lookahead and PTS
 * horizons, because preserving Program Stream PES order can starve audio
 * whenever the mux places several pictures between audio packets.
 */
/*
 * Entry 453: the horizon alone does not bound delivery order.  A whole audio
 * packet ahead of a whole video packet, or a picture-sized video run behind a
 * single guard sample, both let the sink's audio backlog swing by more than
 * PCM_SINK_FIFO_FRAMES, which is an underrun however exact the payload is.
 * Video is therefore admitted in VIDEO_SLICE_BYTES slices, no video run
 * exceeds PCM_MAX_FREE_VIDEO_BYTES without a PCM_REFILL_FRAMES refill, and the
 * horizon is served whether or not video is queued, so a low-bitrate scene
 * cannot throttle audio.  The reserve plus one batch stays below the sink FIFO
 * so that a batch never has to wait for room.
 */
/*
 * Entry 455 ended this lead on a byte budget as well, to leave the decoder
 * most of the compressed FIFO to work from.  Entry 456 measured that it bought
 * almost nothing, moving 174 display outliers to 170, and entry 461 found the
 * cost: a full video FIFO blocks the shared path, so the PCM records queued
 * behind it wait and the audio sink can starve while the producer is ahead of
 * schedule.  The lead ends on the second picture again.
 */
/*
 * The lead is normally ended when the second picture start proves that the
 * first picture is complete, so this bound only exists to keep the buffer
 * finite if that never happens.  It must be
 * comfortably larger than the audio a first picture can sit behind, or it ends
 * the lead early and defeats it: the faded-tones fixture needs 69,120 samples
 * because its intra frame is 97% of the video payload.
 */
#define PCM_HOLD_DEFAULT_MS 4000u
#define PCM_SAMPLE_RATE     48000u

struct video_chunk {
    struct video_chunk *next;
    uint8_t *data;
    size_t size;
    size_t offset;
    int has_pts;      /* carries a timeline the scheduler paces against  */
    int has_record;   /* that timeline is also written into the stream   */
    uint64_t pts;
};

struct output_state {
    FILE *video;
    FILE *pcm;
    uint64_t video_bytes;
    uint64_t pcm_frames;
    unsigned video_pts;
    unsigned audio_frames;
    int16_t *hold;            /* interleaved L,R awaiting emission */
    size_t hold_count;        /* samples written into hold         */
    size_t hold_head;         /* samples already emitted           */
    size_t hold_capacity;
    size_t hold_limit;        /* safety bound on the lead, frames  */
    int hold_active;          /* cleared once the lead is released */
    unsigned picture_marks;   /* picture_start_codes emitted       */
    int hold_rate_hz;         /* sample rate of the held records   */
    uint32_t video_window;    /* start-code scanner across writes  */
    struct video_chunk *video_head;
    struct video_chunk *video_tail;
    size_t video_queued_bytes;
    size_t video_peak_bytes;
    size_t pcm_peak_frames;
    uint64_t pcm_emitted_frames;
    size_t video_bytes_since_pcm;
    uint64_t first_audio_pts;
    uint64_t max_video_pts;
    int have_audio_pts;
    int have_video_pts;
    int scheduler_enabled;
    int scheduler_started;
    uint32_t pts_window;      /* start-code scanner across queued payloads */
    unsigned pictures_since_pts;
    int pts_boundary_seen;    /* sequence or group header since last record */
    int pts_emitted;
};

/*
 * Entry 459: every in-band record costs the presentation path something.
 * Carrying one timestamp per timestamped PES packet measured 21 late
 * presentations in 24 seconds on hardware, roughly one per second, while the
 * same 577 pictures presented perfectly from 26 timestamps with the decoder's
 * reservoir untouched in both cases.  Presentation reconstructs display order
 * from each picture's own temporal reference, so a timestamp is only needed
 * where that reconstruction restarts, at a sequence or group boundary, with a
 * picture-count bound so a stream carrying neither still gets one periodically.
 */
static int pts_record_wanted(struct output_state *output)
{
    if (output->pts_emitted && !output->pts_boundary_seen &&
        output->pictures_since_pts < PTS_MAX_PICTURE_GAP)
        return 0;
    output->pts_boundary_seen = 0;
    output->pictures_since_pts = 0;
    output->pts_emitted = 1;
    return 1;
}

/* Track the boundaries and pictures that decide the next record. */
static void pts_scan_payload(struct output_state *output, const uint8_t *data,
                             size_t size)
{
    size_t i;

    for (i = 0; i < size; ++i) {
        output->pts_window = (output->pts_window << 8) | data[i];
        if ((output->pts_window & 0xffffff00u) != 0x00000100u)
            continue;
        switch (output->pts_window & 0xffu) {
        case 0x00:
            output->pictures_since_pts++;
            break;
        case 0xb3:
        case 0xb8:
            output->pts_boundary_seen = 1;
            break;
        default:
            break;
        }
    }
}

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
            "[--pcm-out FILE] [--video-out FILE] [--audio-delay-ms MS]\n"
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

static void encode_video_pts(uint8_t record[9], uint64_t pts)
{
    uint64_t value = ((pts & 0x1ffffffffULL) << 7) | (3u << 5) | (1u << 2);
    int i;

    memset(record, 0, 9);
    record[2] = 1;
    record[3] = MEDIA_PLAYER_PTS_MARKER_CODE;
    for (i = 8; i >= 4; --i) {
        record[i] = (uint8_t)value;
        value >>= 8;
    }
}

static int emit_video_pts(struct output_state *output, uint64_t pts)
{
    uint8_t record[9];

    encode_video_pts(record, pts);
    if (write_all(output->video, record, sizeof(record), "video timestamp") < 0)
        return -1;
    output->video_bytes += sizeof(record);
    output->video_pts++;
    return 0;
}

static int emit_pcm_sample(struct output_state *output,
                           mp3d_sample_t left, mp3d_sample_t right,
                           int rate_hz)
{
    uint16_t left_bits = (uint16_t)left;
    uint16_t right_bits = (uint16_t)right;
    /*
     * Entry 431: the FPGA already selects between 48 kHz and 44.1 kHz from this
     * mode bit -- mpeg2_h262_inband_metadata extracts it and
     * audio_pcm_output_adapter switches its phase step on it -- so the rate
     * only ever needed carrying here.  Records are always emitted stereo; a
     * mono frame is duplicated into both channels by write_pcm.
     */
    uint8_t record[9] = {
        0, 0, 1, MEDIA_PLAYER_PCM_MARKER_CODE,
        (uint8_t)(MEDIA_PLAYER_PCM_MODE_STEREO |
                  (rate_hz == 48000 ? MEDIA_PLAYER_PCM_MODE_48K : 0)),
        (uint8_t)(left_bits >> 8), (uint8_t)left_bits,
        (uint8_t)(right_bits >> 8), (uint8_t)right_bits
    };

    if (write_all(output->video, record, sizeof(record), "in-band PCM") < 0)
        return -1;
    output->video_bytes_since_pcm = 0;
    return 0;
}

static int emit_pcm_end(struct output_state *output)
{
    const uint8_t record[4] = {0, 0, 1, MEDIA_PLAYER_PCM_END_MARKER_CODE};
    return write_all(output->video, record, sizeof(record), "PCM end marker");
}

/* Write bytes that the scheduler has admitted to the shared FPGA path. */
static int write_video_immediate(struct output_state *output, const void *data,
                                 size_t size, const char *what)
{
    const uint8_t *bytes = data;
    size_t i;

    if (write_all(output->video, bytes, size, what) < 0)
        return -1;
    output->video_bytes += size;
    output->video_bytes_since_pcm += size;
    if (!output->hold_active)
        return 0;
    for (i = 0; i < size; ++i) {
        output->video_window = (output->video_window << 8) | bytes[i];
        if ((output->video_window & 0xffffffffu) == 0x00000100u)
            output->picture_marks++;
    }
    return 0;
}

static int queue_video(struct output_state *output, const uint8_t *data,
                       size_t size, int has_pts, int has_record, uint64_t pts)
{
    struct video_chunk *chunk;
    size_t prefix = has_record ? 9u : 0u;

    if (size > VIDEO_QUEUE_LIMIT - prefix ||
        output->video_queued_bytes > VIDEO_QUEUE_LIMIT - (size + prefix)) {
        fprintf(stderr,
                "media_player_helper: video lookahead limit exceeded (%u bytes)\n",
                (unsigned)VIDEO_QUEUE_LIMIT);
        return -1;
    }
    chunk = calloc(1, sizeof(*chunk));
    if (!chunk) {
        fprintf(stderr, "media_player_helper: out of memory queuing video\n");
        return -1;
    }
    chunk->data = malloc(prefix + size);
    if (!chunk->data) {
        fprintf(stderr, "media_player_helper: out of memory queuing video\n");
        free(chunk);
        return -1;
    }
    if (has_record)
        encode_video_pts(chunk->data, pts);
    memcpy(chunk->data + prefix, data, size);
    chunk->size = prefix + size;
    chunk->has_pts = has_pts;
    chunk->has_record = has_record;
    chunk->pts = pts;
    if (output->video_tail)
        output->video_tail->next = chunk;
    else
        output->video_head = chunk;
    output->video_tail = chunk;
    output->video_queued_bytes += chunk->size;
    if (output->video_queued_bytes > output->video_peak_bytes)
        output->video_peak_bytes = output->video_queued_bytes;
    if (has_record)
        output->video_pts++;
    return 0;
}

static int hold_push(struct output_state *output,
                     const mp3d_sample_t *stereo, int frames)
{
    size_t needed = output->hold_count + (size_t)frames * 2u;

    if (needed > output->hold_capacity) {
        size_t capacity = output->hold_capacity ? output->hold_capacity : 8192u;
        int16_t *replacement;

        while (capacity < needed)
            capacity *= 2u;
        replacement = realloc(output->hold, capacity * sizeof(*replacement));
        if (!replacement) {
            fprintf(stderr, "media_player_helper: out of memory holding PCM\n");
            return -1;
        }
        output->hold = replacement;
        output->hold_capacity = capacity;
    }
    memcpy(output->hold + output->hold_count, stereo,
           (size_t)frames * 2u * sizeof(*output->hold));
    output->hold_count += (size_t)frames * 2u;
    if ((output->hold_count - output->hold_head) / 2u > output->pcm_peak_frames)
        output->pcm_peak_frames =
            (output->hold_count - output->hold_head) / 2u;
    return 0;
}

/* Emit held samples until no more than `keep` sample frames remain. */
static int hold_flush(struct output_state *output, size_t keep)
{
    while ((output->hold_count - output->hold_head) / 2u > keep) {
        if (emit_pcm_sample(output, output->hold[output->hold_head],
                            output->hold[output->hold_head + 1],
                            output->hold_rate_hz) < 0)
            return -1;
        output->hold_head += 2u;
        output->pcm_emitted_frames++;
    }
    if (output->hold_head && output->hold_head == output->hold_count) {
        output->hold_count = 0;
        output->hold_head = 0;
    } else if (output->hold_head >= 65536u) {
        memmove(output->hold, output->hold + output->hold_head,
                (output->hold_count - output->hold_head) * sizeof(*output->hold));
        output->hold_count -= output->hold_head;
        output->hold_head = 0;
    }
    return 0;
}

static size_t hold_available(const struct output_state *output)
{
    return (output->hold_count - output->hold_head) / 2u;
}

static int hold_emit_frames(struct output_state *output, uint64_t frames)
{
    size_t available = hold_available(output);
    size_t emit = frames < (uint64_t)available ? (size_t)frames : available;

    return hold_flush(output, available - emit);
}

static uint64_t scheduler_pcm_target(const struct output_state *output,
                                     uint64_t video_pts)
{
    uint64_t elapsed;

    if (!output->have_audio_pts || !output->hold_rate_hz ||
        video_pts <= output->first_audio_pts)
        return PCM_SCHEDULE_RESERVE_FRAMES;
    elapsed = ((video_pts - output->first_audio_pts) *
               (uint64_t)output->hold_rate_hz + 89999u) / 90000u;
    return elapsed + PCM_SCHEDULE_RESERVE_FRAMES;
}

static void free_video_head(struct output_state *output)
{
    struct video_chunk *chunk = output->video_head;

    output->video_head = chunk->next;
    if (!output->video_head)
        output->video_tail = NULL;
    output->video_queued_bytes -= chunk->size - chunk->offset;
    free(chunk->data);
    free(chunk);
}

/* The startup lead ends only when both its bounds are satisfied. */
static int startup_lead_complete(const struct output_state *output)
{
    return output->picture_marks >= 2;
}

static size_t startup_video_size(const struct output_state *output,
                                 const struct video_chunk *chunk)
{
    uint32_t window = output->video_window;
    unsigned pictures = output->picture_marks;
    size_t i;

    for (i = chunk->offset; i < chunk->size; ++i) {
        window = (window << 8) | chunk->data[i];
        if ((window & 0xffffffffu) == 0x00000100u && ++pictures >= 2)
            return i + 1u - chunk->offset;
    }
    return chunk->size - chunk->offset;
}

/*
 * Program Stream packet order is not a delivery schedule: a mux may place
 * several pictures between audio PES packets.  Once startup is released, keep
 * video in a bounded lookahead queue and admit each timestamped chunk only
 * after its corresponding PCM horizon plus one FPGA startup reserve is ready.
 * Admission is sliced so that neither stream can hold the shared path for
 * longer than the other's sink can survive.  This preserves both elementary
 * streams exactly while removing mux-burst starvation and mux-burst stalling.
 */
static int scheduler_drain(struct output_state *output, int at_eof)
{
    while (output->video_head) {
        struct video_chunk *chunk = output->video_head;
        uint64_t prospective_pts = output->max_video_pts;
        uint64_t target;
        uint64_t due;
        uint64_t available_total;
        size_t remaining = chunk->size - chunk->offset;
        size_t slice;

        if (chunk->has_pts &&
            (!output->have_video_pts || chunk->pts > prospective_pts)) {
            prospective_pts = chunk->pts;
        }

        if (output->hold_active) {
            size_t startup_size;

            if (startup_lead_complete(output))
                break;
            startup_size = startup_video_size(output, chunk);
            if (write_video_immediate(output, chunk->data + chunk->offset,
                                      startup_size,
                                      "queued video") < 0)
                return -1;
            chunk->offset += startup_size;
            output->video_queued_bytes -= startup_size;
            if (chunk->has_pts &&
                (!output->have_video_pts || chunk->pts > output->max_video_pts)) {
                output->max_video_pts = chunk->pts;
                output->have_video_pts = 1;
            }
            if (chunk->offset == chunk->size)
                free_video_head(output);
            if (startup_lead_complete(output) && hold_available(output)) {
                output->hold_active = 0;
                output->scheduler_started = 1;
                if (hold_emit_frames(output, PCM_INITIAL_RELEASE_FRAMES) < 0)
                    return -1;
            }
            continue;
        }

        if (!output->scheduler_started)
            break;
        slice = remaining > VIDEO_SLICE_BYTES ? VIDEO_SLICE_BYTES : remaining;
        target = scheduler_pcm_target(output, prospective_pts);
        due = target > output->pcm_emitted_frames ?
              target - output->pcm_emitted_frames : 0;
        if (due > PCM_SCHEDULE_BATCH_FRAMES)
            due = PCM_SCHEDULE_BATCH_FRAMES;
        if (!due && output->video_bytes_since_pcm + slice >
                    PCM_MAX_FREE_VIDEO_BYTES)
            due = PCM_REFILL_FRAMES;
        available_total = output->pcm_emitted_frames +
                          (uint64_t)hold_available(output);
        if (!at_eof && available_total < output->pcm_emitted_frames + due)
            break;
        if (due && hold_emit_frames(output, due) < 0)
            return -1;
        if (write_video_immediate(output, chunk->data + chunk->offset, slice,
                                  "scheduled video") < 0)
            return -1;
        chunk->offset += slice;
        output->video_queued_bytes -= slice;
        if (chunk->offset < chunk->size)
            continue;
        if (chunk->has_pts &&
            (!output->have_video_pts || chunk->pts > output->max_video_pts)) {
            output->max_video_pts = chunk->pts;
            output->have_video_pts = 1;
        }
        free_video_head(output);
    }
    /*
     * The horizon belongs to the sink, not to the video queue: a scene whose
     * pictures are small delivers few video bytes per second, and pacing audio
     * against those bytes would starve the sink exactly where the source is
     * quietest.  Serve the horizon once the queue is drained as well.
     */
    if (output->scheduler_started && !output->hold_active && !output->video_head) {
        uint64_t target = scheduler_pcm_target(output, output->max_video_pts);
        uint64_t due = target > output->pcm_emitted_frames ?
                       target - output->pcm_emitted_frames : 0;

        if (due > PCM_SCHEDULE_BATCH_FRAMES)
            due = PCM_SCHEDULE_BATCH_FRAMES;
        if (due && hold_emit_frames(output, due) < 0)
            return -1;
    }
    return 0;
}

static int write_pcm(struct output_state *output, const mp3d_sample_t *samples,
                     int samples_per_channel, int channels, int rate_hz)
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
        /*
         * A rate change mid-stream would mislabel anything still held, so
         * drain the queue at the old rate before adopting the new one.
         */
        if (output->hold_rate_hz && output->hold_rate_hz != rate_hz &&
            hold_flush(output, 0) < 0)
            return -1;
        output->hold_rate_hz = rate_hz;
        if (hold_push(output, source, samples_per_channel) < 0)
            return -1;
        if (output->hold_active &&
            (startup_lead_complete(output) ||
             hold_available(output) >= output->hold_limit)) {
            output->hold_active = 0;
            output->scheduler_started = 1;
            /* Preserve the accepted two-picture startup boundary. */
            if (hold_emit_frames(output, PCM_INITIAL_RELEASE_FRAMES) < 0)
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
        if ((info.hz != 48000 && info.hz != 44100) ||
            (info.channels != 1 && info.channels != 2)) {
            fprintf(stderr,
                    "media_player_helper: unsupported audio format: %d Hz, %d channels "
                    "(supported: 44100 or 48000 Hz, 1 or 2 channels)\n",
                    info.hz, info.channels);
            return -1;
        }
        if (write_pcm(output, pcm, samples, info.channels, info.hz) < 0)
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

struct h262_preflight {
    uint32_t window;
    uint8_t sequence_payload[4];
    unsigned sequence_payload_size;
    int accepted;
};

/*
 * Validate the first sequence header before the normal demux path can emit
 * either video or decoded PCM.  Keeping this scanner outside output_state is
 * intentional: Program Stream preflight is a read-only pass followed by a
 * rewind, so even explicit --video-out/--pcm-out operation remains atomic.
 */
static int h262_preflight_feed(struct h262_preflight *preflight,
                               const uint8_t *data, size_t size)
{
    size_t i;

    for (i = 0; i < size && !preflight->accepted; ++i) {
        if (preflight->sequence_payload_size) {
            unsigned offset = preflight->sequence_payload_size - 1;
            unsigned frame_rate_code;

            preflight->sequence_payload[offset] = data[i];
            preflight->sequence_payload_size++;
            if (preflight->sequence_payload_size != 5)
                continue;
            frame_rate_code = preflight->sequence_payload[3] & 0x0f;
            if (frame_rate_code < 1 || frame_rate_code > 5) {
                fprintf(stderr,
                        "media_player_helper: unsupported H.262 frame rate "
                        "code %u (supported: codes 1 through 5, at most 30 fps)\n",
                        frame_rate_code);
                return -1;
            }
            preflight->accepted = 1;
            continue;
        }
        preflight->window = (preflight->window << 8) | data[i];
        if (preflight->window == 0x000001b3u)
            preflight->sequence_payload_size = 1;
    }
    return 0;
}

static int preflight_program_stream(struct media_source *input)
{
    struct h262_preflight preflight = {0};
    int video_code = -1;

    while (!preflight.accepted) {
        uint8_t code;
        int found = find_start_code(input, &code);

        if (found <= 0)
            break;
        if (code == 0xb9)
            break;
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
        if ((code & 0xf0) == 0xe0) {
            uint8_t length_bytes[2];
            uint8_t *packet;
            size_t length;
            size_t payload_offset;
            uint64_t pts;
            int has_pts;
            int result = 0;

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
                free(packet);
                return -1;
            }
            if (video_code < 0)
                video_code = code;
            if (video_code == code) {
                if (parse_pes_header(packet, length, &payload_offset, &pts,
                                     &has_pts) < 0) {
                    fprintf(stderr,
                            "media_player_helper: invalid PES header for stream 0x%02x\n",
                            code);
                    result = -1;
                } else {
                    result = h262_preflight_feed(&preflight,
                                                 packet + payload_offset,
                                                 length - payload_offset);
                }
            }
            free(packet);
            if (result < 0)
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
    if (preflight.accepted)
        return 0;
    fprintf(stderr, "media_player_helper: no H.262 sequence header found\n");
    return -1;
}

static int preflight_elementary_stream(struct media_source *input)
{
    struct h262_preflight preflight = {0};
    uint8_t buffer[16384];
    size_t count;

    while (!preflight.accepted &&
           (count = media_source_read(input, buffer, sizeof(buffer))) != 0) {
        if (h262_preflight_feed(&preflight, buffer, count) < 0)
            return -1;
    }
    if (preflight.accepted)
        return 0;
    if (media_source_error(input))
        return -1;
    fprintf(stderr, "media_player_helper: no H.262 sequence header found\n");
    return -1;
}

static int preflight_input(struct media_source *input, int is_program_stream)
{
    int result = is_program_stream ? preflight_program_stream(input) :
                                     preflight_elementary_stream(input);

    if (result < 0)
        return -1;
    if (media_source_rewind(input) < 0) {
        fprintf(stderr, "media_player_helper: cannot rewind input after preflight\n");
        return -1;
    }
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
        int has_record = has_pts && pts_record_wanted(output);

        if (output->scheduler_enabled) {
            if (queue_video(output, packet + payload_offset,
                            length - payload_offset, has_pts, has_record,
                            pts) < 0 ||
                scheduler_drain(output, 0) < 0)
                goto done;
        } else {
            if (has_record && emit_video_pts(output, pts) < 0)
                goto done;
            if (write_video_immediate(output, packet + payload_offset,
                                      length - payload_offset, "video") < 0)
                goto done;
        }
        pts_scan_payload(output, packet + payload_offset,
                         length - payload_offset);
    } else if ((code & 0xe0) == 0xc0) {
        if (has_pts && !output->have_audio_pts) {
            output->first_audio_pts = pts;
            output->have_audio_pts = 1;
        }
        if (append_audio(audio, output, packet + payload_offset,
                         length - payload_offset) < 0 ||
            (output->scheduler_enabled && scheduler_drain(output, 0) < 0))
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
        if (write_video_immediate(output, buffer, count, "video") < 0)
            return -1;
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
    unsigned audio_delay_ms = PCM_HOLD_DEFAULT_MS;
    struct audio_state audio = {0};
    struct media_source input = {0};
    char source_error[512];
    uint8_t signature[4];
    int is_program_stream;
    int i;
    int success = 0;

    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--audio-delay-ms") && i + 1 < argc) {
            audio_delay_ms = (unsigned)strtoul(argv[++i], NULL, 10);
        } else if (!strcmp(argv[i], "--pcm-out") && i + 1 < argc) {
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
    output.hold_limit =
        (size_t)audio_delay_ms * (size_t)PCM_SAMPLE_RATE / 1000u;
    output.hold_active = output.hold_limit != 0;
    output.scheduler_started = !output.hold_active;
    mp3dec_init(&audio.decoder);
    if (read_exact(&input, signature, sizeof(signature)) < 0 ||
        media_source_rewind(&input) < 0) {
        fprintf(stderr, "media_player_helper: input is too short\n");
        goto done;
    }
    is_program_stream = !memcmp(signature, "\x00\x00\x01\xba", 4);
    if (preflight_input(&input, is_program_stream) < 0)
        goto done;
    output.scheduler_enabled = is_program_stream && !output.pcm;
    if (is_program_stream) {
        if (process_program_stream(&input, &audio, &output) < 0 ||
            decode_audio_buffer(&audio, &output, 1) < 0 ||
            scheduler_drain(&output, 1) < 0)
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
    if (output.scheduler_enabled)
        fprintf(stderr,
                "media_player_helper: scheduler video_peak=%zu bytes, "
                "pcm_peak=%zu samples, pcm_emitted=%llu samples\n",
                output.video_peak_bytes, output.pcm_peak_frames,
                (unsigned long long)output.pcm_emitted_frames);
done:
    free(audio.data);
    media_source_close(&input);
    output.hold_active = 0;
    if (success && !output.pcm && hold_flush(&output, 0) < 0)
        success = 0;
    if (success && output.audio_frames && !output.pcm &&
        emit_pcm_end(&output) < 0)
        success = 0;
    free(output.hold);
    output.hold = NULL;
    while (output.video_head)
        free_video_head(&output);
    if (video_path && output.video) {
        fclose(output.video);
        output.video = NULL;
    }
    return finish_output(&output, success);
}
