#define _POSIX_C_SOURCE 200809L
#define MINIMP3_IMPLEMENTATION
#define MINIMP3_NO_SIMD

#include "minimp3.h"
#include "a52.h"
#include "ac3_resync.h"
#include "audio_file_seek.h"
#include "mm_accel.h"
#include "consumer_audio.h"
#include "audio_ui.h"
#include "audio_visualizer.h"
#include "cdda_audio.h"
#include "dvd_random_access.h"
#include "dvd_spu.h"
#include "media_player_protocol.h"
#include "media_source.h"
#include "output_reserve.h"
#include "output_stage.h"
#include "program_stream_seek.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <unistd.h>

#define AUDIO_BUFFER_LIMIT (256u * 1024u)
/*
 * Entry 693: the lookahead holds video while the scheduler reads far enough
 * ahead to satisfy the PCM reserve, so this bound scales with that reserve.
 * At 8192 frames of reserve the 512 KiB bound is reached on real DVD muxing
 * and aborts playback; 2 MiB is still negligible against 492 MiB of host RAM
 * and keeps the runaway protection this bound exists for.
 */
#define VIDEO_QUEUE_LIMIT  (2u * 1024u * 1024u)
#define OUTPUT_RESERVE_BYTES (4u * 1024u * 1024u)
#define OUTPUT_ACTIVATION_STAGE_DECISION_BYTES (4u * 1024u * 1024u)
#define OUTPUT_ACTIVATION_STAGE_BYTES (8u * 1024u * 1024u)
#define PCM_SCHEDULE_RESERVE_FRAMES 8192u
#define PCM_SCHEDULE_BATCH_FRAMES   2048u
#define PCM_INITIAL_RELEASE_FRAMES  8192u
#define PCM_MAX_FREE_VIDEO_BYTES    4096u
#define PCM_REFILL_FRAMES           128u
#define PCM_SINK_FIFO_FRAMES        16384u
#define PTS_MAX_PICTURE_GAP         60u
#define PCM_STARTUP_VIDEO_BYTES     28672u
#define PCM_RECORD_FRAMES           16u
#define VIDEO_SLICE_BYTES           256u
#define AUTOMATIC_MENU_STALLED_VIDEO_BYTES (256u * 1024u)
#define H262_RESTART_DIAGNOSTIC_PREFIX_BYTES 256u
#define MP3_PROBE_BYTES             (64u * 1024u)
#define ID3V2_TAG_LIMIT             (64u * 1024u * 1024u)
#define ISO_PTS_DISCONTINUITY_TICKS (10u * 90000u)
#define AUDIO_VISUALIZER_PATH "/media/fat/linux/MediaPlayer_Visualizer.mmpvis"
#define AUDIO_OVERLAY_RECORDS \
    (2u + (AUDIO_UI_OVERLAY_BYTES + 4095u) / 4096u)

_Static_assert(OUTPUT_ACTIVATION_STAGE_BYTES >=
                   OUTPUT_ACTIVATION_STAGE_DECISION_BYTES +
                       VIDEO_QUEUE_LIMIT,
               "activation stage must retain one video-queue drain of "
               "headroom after its motion-menu decision");

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
 *
 * Entry 693: the sink FIFO doubled to 16384 frames, paid for by halving the
 * clean video queue, because the shared byte path stalls while that queue is
 * full and audio behind the held byte stalls with it.  The reserve is half the
 * sink FIFO by construction, so it doubles with it; leaving it at 4096 while
 * the shorter video queue made those stalls more frequent starved audio once
 * at startup on hardware.  Reserve plus one batch, 8192 plus 2048, still sits
 * below the sink FIFO so a batch never waits for room.
 * Video is therefore admitted in VIDEO_SLICE_BYTES slices, no video run
 * exceeds PCM_MAX_FREE_VIDEO_BYTES without a PCM_REFILL_FRAMES refill, and the
 * horizon is served whether or not video is queued, so a low-bitrate scene
 * cannot throttle audio.  The reserve plus one batch stays below the sink FIFO
 * so that a batch never has to wait for room.
 */
/*
 * Entry 455 ended this lead on a byte budget as well, to leave the decoder most
 * of the compressed FIFO to work from, and entry 456 measured that it bought
 * almost nothing for cadence.  Entry 461 removed it on the theory that a full
 * video FIFO starves the audio sink; entry 462 measured the opposite, with the
 * soak's underrun arriving at 39.3 seconds without the budget against 62.2 with
 * it.  It is an audio-margin measure rather than the cadence measure it was
 * introduced as, and it is kept for that.
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

/*
 * DVD carries AC-3 inside private stream 1.  Each such PES payload opens with
 * a substream identifier, a frame count and a pointer to the first frame
 * header in this packet; 0x80 through 0x87 are the eight AC-3 tracks.  A frame
 * is always six blocks of 256 samples per channel, and every DVD AC-3 track is
 * 48 kHz, so the existing PCM record path and its rate assumptions are
 * unchanged.  a52_syncinfo needs the first seven bytes of a frame to report
 * that frame's length.
 */
#define AC3_SUBSTREAM_FIRST 0x80u
#define AC3_SUBSTREAM_LAST  0x87u
#define AC3_PRIVATE_HEADER  4u
#define AC3_SYNCINFO_BYTES  7u
#define AC3_BLOCKS_PER_FRAME 6
#define AC3_SAMPLES_PER_BLOCK 256
#define AC3_SAMPLES_PER_FRAME (AC3_BLOCKS_PER_FRAME * AC3_SAMPLES_PER_BLOCK)
#define AC3_RESYNC_LIMIT (64u * 1024u)

/*
 * IEC 61937 passthrough. The burst period for AC-3 is the frame's own 1536
 * samples, so one frame fills exactly one period of 16-bit stereo and no rate
 * conversion is involved: 1536 frames * 2 channels * 2 bytes = 6144 bytes. The
 * receiver finds the burst by its sync words, so the words below are the whole
 * contract, together with a bit transparent path to the S/PDIF pin.
 */
#define IEC61937_PA 0xF872u
#define IEC61937_PB 0x4E1Fu
#define IEC61937_DATA_TYPE_AC3 0x0001u
#define IEC61937_HEADER_WORDS 4

/*
 * DTS also arrives on private stream 1, on substreams 0x88 to 0x8F. Its frame
 * carries its own sample count, and IEC 61937 gives each count its own data
 * type: 512 samples is type 11, 1024 is type 12 and 2048 is type 13. The burst
 * period is that sample count, so unlike AC-3 the period is not fixed.
 *
 * There is no DTS decoder here, so DTS is passthrough only. A DTS track
 * selected for HDMI output is refused rather than played as silence.
 */
#define DTS_SUBSTREAM_FIRST 0x88u
#define DTS_SUBSTREAM_LAST  0x8Fu
#define DTS_HEADER_BYTES 8
#define DTS_MAX_SAMPLES_PER_FRAME 2048
#define IEC61937_DATA_TYPE_DTS1 0x000Bu
#define IEC61937_DATA_TYPE_DTS2 0x000Cu
#define IEC61937_DATA_TYPE_DTS3 0x000Du
#define IEC61937_MAX_BURST_SAMPLES DTS_MAX_SAMPLES_PER_FRAME

struct video_chunk {
    struct video_chunk *next;
    uint8_t *data;
    size_t size;
    size_t offset;
    int has_pts;      /* carries a timeline the scheduler paces against  */
    int has_record;   /* that timeline is also written into the stream   */
    uint64_t pts;
};

/*
 * A picture coding extension carries chroma_420_type in the byte immediately
 * before progressive_frame.  Holding one elementary-stream byte is therefore
 * sufficient to validate the latter before releasing the former, including
 * when a DVD video PES boundary falls between them.
 */
struct h262_chroma_stream_state {
    uint32_t window;
    uint64_t input_bytes;
    unsigned payload_index;
    unsigned sequence_chroma_format;
    unsigned picture_coding_type;
    unsigned picture_structure;
    unsigned corrections;
    uint8_t start_code;
    uint8_t extension_id;
    uint8_t pending_byte;
    int sequence_pending;
    int sequence_extension_valid;
    int picture_started_since_sequence;
    int picture_header_valid;
    int picture_structure_valid;
    int have_pending;
};

enum audio_overlay_upload_state {
    AUDIO_OVERLAY_IDLE,
    AUDIO_OVERLAY_CONFIG,
    AUDIO_OVERLAY_DATA,
    AUDIO_OVERLAY_COMMIT
};

struct audio_overlay_state {
    uint8_t *plane;
    size_t offset;
    unsigned record_index;
    uint64_t frame_start;
    uint64_t next_update;
    int visible;
    enum audio_overlay_upload_state state;
};

struct output_state {
    FILE *video;
    FILE *pcm;
    struct output_reserve *reserve;
    struct output_stage *activation_stage;
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
    uint64_t max_video_pts_byte;
    int have_audio_pts;
    int have_video_pts;
    int audio_pes_seen;
    int silent_video_mode;
    int audio_only_mode;
    struct audio_ui *audio_ui;
    struct audio_visualizer *visualizer;
    struct audio_overlay_state audio_overlay;
    uint64_t audio_position_base;
    uint64_t audio_emitted_base;
    int pcm_non_audio;       /* IEC 61937 burst records, never decoded PCM */
    int scheduler_enabled;
    int scheduler_started;
    int automatic_menu_epoch;
    unsigned automatic_menu_stalled_pts;
    int automatic_menu_pcm_fallback;
    uint64_t automatic_menu_pcm_fallback_frames;
    int iso_start_filter_active;
    int iso_pts_normalization;
    int h262_chroma_normalization;
    struct h262_chroma_stream_state h262_chroma;
    int h262_pending_has_pts;
    int h262_pending_has_record;
    uint64_t h262_pending_pts;
    int have_iso_video_pts;
    uint64_t iso_pts_epoch_offset;
    uint64_t iso_pts_raw_max;
    uint64_t iso_pts_normalized_max;
    unsigned iso_pts_discontinuities;
    uint64_t iso_pts_rebase_floor;
    int iso_pts_rebase_pending;
    uint32_t pts_window;      /* start-code scanner across queued payloads */
    unsigned pictures_since_pts;
    int pts_boundary_seen;    /* sequence or group header since last record */
    int pts_emitted;
    uint64_t sched_log_start_us;  /* monotonic instant of the first report  */
    uint64_t sched_log_next_us;   /* next report due                        */
    unsigned sched_log_poll;      /* divider: clock reads are not free      */
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

/*
 * Codec selection follows ARCHITECTURE.md: the codec is chosen from the first
 * audio PES seen and the other codec is ignored for the rest of the session,
 * rather than branching on the source or container.
 */
enum audio_codec {
    AUDIO_CODEC_NONE = 0,
    AUDIO_CODEC_MP2,
    AUDIO_CODEC_MP3,
    AUDIO_CODEC_AC3,
    AUDIO_CODEC_DTS
};

/*
 * The decoder runs here on the ARM, so only this process can choose between
 * emitting decoded stereo and emitting the compressed bitstream. The selection
 * is therefore made at launch rather than during playback.
 */
enum audio_output {
    AUDIO_OUT_HDMI = 0,
    AUDIO_OUT_SPDIF         /* PCM, or IEC 61937 only for AC-3/DTS */
};

struct audio_state {
    enum audio_codec codec;
    enum audio_output output;
    int dts_substream;
    mp3dec_t decoder;
    a52_state_t *a52;
    int a52_substream;
    int a52_synced;
    size_t ac3_resync_bytes;
    unsigned ac3_resync_events;
    uint32_t unsupported_private_audio_mask;
    uint8_t *data;
    size_t size;
    size_t capacity;
};

struct dvd_menu_state {
    struct dvd_spu_decoder *decoder;
    int enabled;
    int menu_active;
    int spu_stream;
    int overlay_emitted;
    int highlight_display;
    uint32_t highlight_palette;
    uint16_t highlight_x1;
    uint16_t highlight_y1;
    uint16_t highlight_x2;
    uint16_t highlight_y2;
    int activation_pending;
    unsigned activation_payloads;
    int activation_staged_hop;
    int activation_prior_pts_valid;
    uint64_t activation_prior_pts;
    int resume_code_valid;
    uint8_t resume_code;
};

static void usage(const char *program)
{
    fprintf(stderr,
        "usage: %s [--protocol 1] [--source SOURCE | INPUT] "
            "[--pcm-out FILE] [--video-out FILE] [--audio-delay-ms MS] "
            "[--control-fd FD]\n"
            "       %s [--audio-out hdmi|spdif]\n"
            "       %s --capabilities\n",
            program,
            program,
            program);
}

static int control_read_command(int fd)
{
    uint8_t command;
    ssize_t count;

    if (fd < 0)
        return 0;
    count = read(fd, &command, sizeof(command));
    if (count == 1)
        return command;
    if (!count) {
        fprintf(stderr, "media_player_helper: control channel closed\n");
        return -1;
    }
    if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
        return 0;
    fprintf(stderr, "media_player_helper: control read failed: %s\n",
            strerror(errno));
    return -1;
}

static int control_send(int fd, uint8_t event)
{
    ssize_t count;

    if (fd < 0)
        return -1;
    do {
        count = write(fd, &event, sizeof(event));
    } while (count < 0 && errno == EINTR);
    if (count == 1)
        return 0;
    fprintf(stderr, "media_player_helper: control write failed: %s\n",
            count < 0 ? strerror(errno) : "short write");
    return -1;
}

static int control_wait_for_go(int fd)
{
    struct pollfd descriptor = {fd, POLLIN, 0};

    for (;;) {
        int result = poll(&descriptor, 1, -1);
        int command;

        if (result < 0 && errno == EINTR)
            continue;
        if (result <= 0 || !(descriptor.revents & POLLIN))
            return -1;
        command = control_read_command(fd);
        if (command == MEDIA_PLAYER_CONTROL_GO)
            return 0;
        if (command < 0)
            return -1;
        fprintf(stderr,
                "media_player_helper: ignoring control 0x%02x while "
                "waiting for go\n", command);
    }
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

static int write_output_unstaged(struct output_state *output,
                                 const void *data, size_t size,
                                 int priority, const char *what)
{
    if (output->reserve) {
        int result = priority ?
            output_reserve_write_priority(output->reserve, data, size) :
            output_reserve_write(output->reserve, data, size);

        if (result < 0) {
            fprintf(stderr, "media_player_helper: writing %s%s through "
                    "output reserve failed: %s\n",
                    priority ? "priority " : "", what, strerror(errno));
            return -1;
        }
        return 0;
    }
    return write_all(output->video, data, size, what);
}

static int write_output_stage_callback(void *opaque, const void *data,
                                       size_t size, int priority)
{
    return write_output_unstaged(opaque, data, size, priority,
                                 "staged DVD activation output");
}

static int write_output(struct output_state *output, const void *data,
                        size_t size, const char *what)
{
    int staged = output->activation_stage ?
        output_stage_write(output->activation_stage, data, size, 0) : 0;

    if (staged < 0) {
        fprintf(stderr, "media_player_helper: staging %s failed: %s\n",
                what, strerror(errno));
        return -1;
    }
    if (staged)
        return 0;
    return write_output_unstaged(output, data, size, 0, what);
}

static int write_output_priority(struct output_state *output,
                                 const void *data, size_t size,
                                 const char *what)
{
    int staged = output->activation_stage ?
        output_stage_write(output->activation_stage, data, size, 1) : 0;

    if (staged < 0) {
        fprintf(stderr,
                "media_player_helper: staging priority %s failed: %s\n",
                what, strerror(errno));
        return -1;
    }
    if (staged)
        return 0;
    return write_output_unstaged(output, data, size, 1, what);
}

static int begin_activation_stage(struct output_state *output)
{
    if (output_stage_begin(output->activation_stage) < 0) {
        fprintf(stderr,
                "media_player_helper: starting DVD activation stage failed: %s\n",
                strerror(errno));
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: DVD activation output stage started "
            "capacity=%u decision=%u\n", OUTPUT_ACTIVATION_STAGE_BYTES,
            OUTPUT_ACTIVATION_STAGE_DECISION_BYTES);
    return 0;
}

static int commit_activation_stage(struct output_state *output,
                                   const char *reason)
{
    size_t bytes = 0;
    size_t records = 0;

    if (output_stage_commit(output->activation_stage,
                            write_output_stage_callback, output,
                            &bytes, &records) < 0) {
        fprintf(stderr,
                "media_player_helper: committing DVD activation stage "
                "failed: %s\n", strerror(errno));
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: DVD activation output stage committed "
            "reason=%s records=%zu bytes=%zu\n",
            reason, records, bytes);
    return 0;
}

static int cancel_activation_stage(struct output_state *output,
                                   const char *reason)
{
    size_t bytes = 0;
    size_t records = 0;

    if (output_stage_cancel(output->activation_stage,
                            &bytes, &records) < 0) {
        fprintf(stderr,
                "media_player_helper: cancelling DVD activation stage "
                "failed: %s\n", strerror(errno));
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: DVD activation output stage cancelled "
            "reason=%s records=%zu bytes=%zu\n",
            reason, records, bytes);
    return 0;
}

static int flush_output(struct output_state *output, const char *what)
{
    if (output->reserve) {
        if (output_reserve_drain(output->reserve) < 0) {
            fprintf(stderr, "media_player_helper: draining %s failed: %s\n",
                    what, strerror(errno));
            return -1;
        }
        return 0;
    }
    if (output->video && fflush(output->video) == EOF) {
        fprintf(stderr, "media_player_helper: flushing %s failed: %s\n",
                what, strerror(errno));
        return -1;
    }
    return 0;
}

static int discard_reserved_output(struct output_state *output,
                                   int command, const char *what)
{
    size_t discarded = 0;

    if (!output->reserve)
        return flush_output(output, what);
    if (output_reserve_discard(output->reserve, &discarded) < 0) {
        fprintf(stderr, "media_player_helper: discarding %s failed: %s\n",
                what, strerror(errno));
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: navigation reserve discarded command=0x%02x "
            "bytes=%zu\n",
            command, discarded);
    return 0;
}

static int emit_display_record(struct output_state *output, uint8_t command,
                               const uint8_t *payload, size_t size)
{
    uint8_t *record;
    const uint8_t header[7] = {
        0x00, 0x00, 0x01, MEDIA_PLAYER_OVERLAY_MARKER_CODE,
        0x00, 0x00, command
    };
    size_t record_size = size + 1u;
    int result;

    if (!output->video || record_size > 65535u || (!payload && size))
        return -1;
    record = malloc(sizeof(header) + size);
    if (!record)
        return -1;
    memcpy(record, header, sizeof(header));
    record[4] = (uint8_t)(record_size >> 8);
    record[5] = (uint8_t)record_size;
    if (size)
        memcpy(record + sizeof(header), payload, size);
    result = write_output_priority(output, record, sizeof(header) + size,
                                   "display record");
    free(record);
    return result;
}

static int emit_audio_ui_record(void *opaque, uint8_t command,
                                const uint8_t *payload, size_t size)
{
    return emit_display_record(opaque, command, payload, size);
}

static void overlay_style_payload(const struct dvd_spu_overlay *overlay,
                                  uint8_t payload[41])
{
    size_t offset = 1;
    unsigned color;

    payload[0] = (uint8_t)((overlay->visible ? 1u : 0u) |
                           (overlay->menu ? 2u : 0u));
    for (color = 0; color < 4u; ++color) {
        memcpy(payload + offset, overlay->rgba[color], 4u);
        offset += 4u;
    }
    for (color = 0; color < 4u; ++color) {
        memcpy(payload + offset, overlay->highlight_rgba[color], 4u);
        offset += 4u;
    }
    payload[offset++] = (uint8_t)(overlay->highlight_x1 >> 8);
    payload[offset++] = (uint8_t)overlay->highlight_x1;
    payload[offset++] = (uint8_t)(overlay->highlight_y1 >> 8);
    payload[offset++] = (uint8_t)overlay->highlight_y1;
    payload[offset++] = (uint8_t)(overlay->highlight_x2 >> 8);
    payload[offset++] = (uint8_t)overlay->highlight_x2;
    payload[offset++] = (uint8_t)(overlay->highlight_y2 >> 8);
    payload[offset] = (uint8_t)overlay->highlight_y2;
}

#ifdef MMP_DVD_OVERLAY_PROBE
static void overlay_probe_style_payload(uint8_t payload[41])
{
    /* Index one is transparent normally and opaque magenta when selected. */
    memset(payload + 1, 0, 32u);
    payload[21] = 0xffu;
    payload[22] = 0x00u;
    payload[23] = 0xffu;
    payload[24] = 0xffu;
}

static uint32_t overlay_probe_plane_hash(const uint8_t *plane)
{
    uint32_t hash = 2166136261u;
    size_t offset;

    for (offset = 0; offset < DVD_SPU_PLANE_BYTES; ++offset) {
        hash ^= plane[offset];
        hash *= 16777619u;
    }
    return hash;
}

static void overlay_probe_dump_plane(const struct dvd_spu_overlay *overlay)
{
    static unsigned sequence;
    static const char digits[] = "0123456789abcdef";
    char row_hex[(DVD_SPU_WIDTH / 4u) * 2u + 1u];
    uint32_t hash;
    unsigned row;

    if (!overlay || !overlay->pixels)
        return;
    sequence++;
    hash = overlay_probe_plane_hash(overlay->pixels);
    fprintf(stderr,
            "media_player_helper: DVD overlay real-plane begin sequence=%u "
            "bytes=%u rows=%u row_bytes=%u fnv1a=%08x\n",
            sequence, (unsigned)DVD_SPU_PLANE_BYTES,
            (unsigned)DVD_SPU_HEIGHT, (unsigned)(DVD_SPU_WIDTH / 4u),
            (unsigned)hash);
    for (row = 0; row < DVD_SPU_HEIGHT; ++row) {
        const uint8_t *source = overlay->pixels +
                                (size_t)row * (DVD_SPU_WIDTH / 4u);
        unsigned byte;

        for (byte = 0; byte < DVD_SPU_WIDTH / 4u; ++byte) {
            row_hex[byte * 2u] = digits[source[byte] >> 4];
            row_hex[byte * 2u + 1u] = digits[source[byte] & 15u];
        }
        row_hex[sizeof(row_hex) - 1u] = '\0';
        fprintf(stderr,
                "media_player_helper: DVD overlay real-plane sequence=%u "
                "row=%03u data=%s\n", sequence, row, row_hex);
    }
    fprintf(stderr,
            "media_player_helper: DVD overlay real-plane end sequence=%u "
            "fnv1a=%08x\n", sequence, (unsigned)hash);
}
#endif

static int emit_overlay_style(struct output_state *output,
                              const struct dvd_spu_overlay *overlay,
                              uint8_t command)
{
    uint8_t payload[41];
    uint32_t histogram[4];
    uint32_t selected_pixels = 0;
    uint32_t selected_nontransparent_pixels = 0;
    const char *name = command == MEDIA_PLAYER_OVERLAY_CONFIG ? "config" :
                       command == MEDIA_PLAYER_OVERLAY_STYLE ? "style" :
                       "unknown";
    int result;
    unsigned color;

    overlay_style_payload(overlay, payload);
#ifdef MMP_DVD_OVERLAY_PROBE
    overlay_probe_style_payload(payload);
#endif
    result = emit_display_record(output, command, payload, sizeof(payload));
    if (result < 0)
        return result;
    if (dvd_spu_selected_histogram(overlay, histogram) < 0) {
        fprintf(stderr,
                "media_player_helper: DVD overlay record=%s invalid "
                "selected rectangle\n", name);
        return 0;
    }
#ifdef MMP_DVD_OVERLAY_PROBE
    memset(histogram, 0, sizeof(histogram));
    histogram[1] =
        ((uint32_t)overlay->highlight_x2 - overlay->highlight_x1 + 1u) *
        ((uint32_t)overlay->highlight_y2 - overlay->highlight_y1 + 1u);
#endif
    for (color = 0; color < 4u; ++color) {
        selected_pixels += histogram[color];
#ifdef MMP_DVD_OVERLAY_PROBE
        if (payload[17u + color * 4u + 3u] != 0)
#else
        if (overlay->highlight_rgba[color][3] != 0)
#endif
            selected_nontransparent_pixels += histogram[color];
    }
    fprintf(stderr,
            "media_player_helper: DVD overlay record=%s visible=%d menu=%d "
            "rect=%u,%u,%u,%u highlight_rgba="
            "%02x%02x%02x%02x/%02x%02x%02x%02x/"
            "%02x%02x%02x%02x/%02x%02x%02x%02x "
            "selected_histogram=%u,%u,%u,%u selected_pixels=%u "
            "selected_nontransparent_pixels=%u%s\n",
            name, payload[0] & 1u, (payload[0] >> 1) & 1u,
            (unsigned)overlay->highlight_x1,
            (unsigned)overlay->highlight_y1,
            (unsigned)overlay->highlight_x2,
            (unsigned)overlay->highlight_y2,
#ifdef MMP_DVD_OVERLAY_PROBE
            (unsigned)payload[17], (unsigned)payload[18],
            (unsigned)payload[19], (unsigned)payload[20],
            (unsigned)payload[21], (unsigned)payload[22],
            (unsigned)payload[23], (unsigned)payload[24],
            (unsigned)payload[25], (unsigned)payload[26],
            (unsigned)payload[27], (unsigned)payload[28],
            (unsigned)payload[29], (unsigned)payload[30],
            (unsigned)payload[31], (unsigned)payload[32],
#else
            (unsigned)overlay->highlight_rgba[0][0],
            (unsigned)overlay->highlight_rgba[0][1],
            (unsigned)overlay->highlight_rgba[0][2],
            (unsigned)overlay->highlight_rgba[0][3],
            (unsigned)overlay->highlight_rgba[1][0],
            (unsigned)overlay->highlight_rgba[1][1],
            (unsigned)overlay->highlight_rgba[1][2],
            (unsigned)overlay->highlight_rgba[1][3],
            (unsigned)overlay->highlight_rgba[2][0],
            (unsigned)overlay->highlight_rgba[2][1],
            (unsigned)overlay->highlight_rgba[2][2],
            (unsigned)overlay->highlight_rgba[2][3],
            (unsigned)overlay->highlight_rgba[3][0],
            (unsigned)overlay->highlight_rgba[3][1],
            (unsigned)overlay->highlight_rgba[3][2],
            (unsigned)overlay->highlight_rgba[3][3],
#endif
            (unsigned)histogram[0], (unsigned)histogram[1],
            (unsigned)histogram[2], (unsigned)histogram[3],
            (unsigned)selected_pixels,
            (unsigned)selected_nontransparent_pixels,
#ifdef MMP_DVD_OVERLAY_PROBE
            " probe=solid-index1-magenta"
#else
            ""
#endif
            );
    return 0;
}

static int emit_overlay_frame(struct output_state *output,
                              const struct dvd_spu_overlay *overlay)
{
    size_t offset = 0;
#ifdef MMP_DVD_OVERLAY_PROBE
    uint8_t transfer_plane[4096];

    overlay_probe_dump_plane(overlay);
    memset(transfer_plane, 0x55, sizeof(transfer_plane));
#endif

    if (emit_overlay_style(output, overlay, MEDIA_PLAYER_OVERLAY_CONFIG) < 0)
        return -1;
    while (offset < DVD_SPU_PLANE_BYTES) {
        size_t count = DVD_SPU_PLANE_BYTES - offset;

        if (count > 4096u)
            count = 4096u;
        if (emit_display_record(output, MEDIA_PLAYER_OVERLAY_DATA,
#ifdef MMP_DVD_OVERLAY_PROBE
                                transfer_plane,
#else
                                overlay->pixels + offset,
#endif
                                count) < 0)
            return -1;
        offset += count;
    }
    if (emit_display_record(output, MEDIA_PLAYER_OVERLAY_COMMIT, NULL, 0) < 0)
        return -1;
    return 0;
}

static int emit_overlay_clear(struct output_state *output)
{
    return emit_display_record(output, MEDIA_PLAYER_OVERLAY_CLEAR, NULL, 0);
}

static void audio_overlay_descriptor(struct output_state *output,
                                     struct dvd_spu_overlay *overlay,
                                     int visible)
{
    static const uint8_t palette[4][4] = {
        {0x00, 0x00, 0x00, 0x00},
        {0x18, 0x1b, 0x20, 0xa0},
        {0x68, 0x7d, 0x89, 0xff},
        {0xee, 0xf2, 0xf4, 0xff}
    };

    memset(overlay, 0, sizeof(*overlay));
    overlay->pixels = output->audio_overlay.plane;
    memcpy(overlay->rgba, palette, sizeof(palette));
    memcpy(overlay->highlight_rgba, palette, sizeof(palette));
    overlay->visible = visible;
}

static int audio_overlay_style(struct output_state *output, uint8_t command,
                               int visible)
{
    struct dvd_spu_overlay overlay;
    uint8_t payload[41];

    audio_overlay_descriptor(output, &overlay, visible);
    overlay_style_payload(&overlay, payload);
    return emit_display_record(output, command, payload, sizeof(payload));
}

static int audio_overlay_render(struct output_state *output,
                                uint64_t position_pcm_frames)
{
    if (!output->audio_overlay.plane) {
        output->audio_overlay.plane = malloc(AUDIO_UI_OVERLAY_BYTES);
        if (!output->audio_overlay.plane)
            return -1;
    }
    return audio_ui_render_overlay(output->audio_ui, position_pcm_frames,
                                   output->audio_overlay.plane,
                                   AUDIO_UI_OVERLAY_BYTES);
}

static int audio_overlay_publish_full(struct output_state *output,
                                      uint64_t position_pcm_frames)
{
    struct dvd_spu_overlay overlay;

    if (audio_overlay_render(output, position_pcm_frames) < 0)
        return -1;
    audio_overlay_descriptor(output, &overlay, 1);
    if (emit_overlay_frame(output, &overlay) < 0)
        return -1;
    output->audio_overlay.visible = 1;
    output->audio_overlay.state = AUDIO_OVERLAY_IDLE;
    output->audio_overlay.offset = 0;
    output->audio_overlay.record_index = 0;
    return 0;
}

static int audio_pause_barrier(struct output_state *output, int control_fd,
                               unsigned rate_hz, const char *source_name)
{
    int action;

    audio_visualizer_activity(output->visualizer,
                              output->pcm_emitted_frames);
    action = audio_visualizer_take_overlay_action(
        output->visualizer, output->pcm_emitted_frames, rate_hz);
    if (action > 0) {
        output->audio_overlay.state = AUDIO_OVERLAY_IDLE;
        output->audio_overlay.visible = 1;
        if (audio_overlay_style(output, MEDIA_PLAYER_OVERLAY_STYLE, 1) < 0)
            return -1;
    }
    if (flush_output(output, "audio pause overlay") < 0 ||
        control_send(control_fd, MEDIA_PLAYER_CONTROL_PAUSE_READY) < 0) {
        fprintf(stderr,
                "media_player_helper: %s pause barrier publication failed\n",
                source_name);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: %s pause ready frame=%llu overlay=%s\n",
            source_name, (unsigned long long)output->pcm_emitted_frames,
            action > 0 ? "revealed" : "visible");
    if (control_wait_for_go(control_fd) < 0) {
        fprintf(stderr,
                "media_player_helper: %s pause barrier GO failed\n",
                source_name);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: %s pause resumed frame=%llu\n",
            source_name, (unsigned long long)output->pcm_emitted_frames);
    return 0;
}

static uint64_t audio_overlay_position(const struct output_state *output,
                                       uint64_t emitted_pcm_frames)
{
    uint64_t elapsed = emitted_pcm_frames >= output->audio_emitted_base ?
                       emitted_pcm_frames - output->audio_emitted_base : 0;

    return elapsed > UINT64_MAX - output->audio_position_base ? UINT64_MAX :
           output->audio_position_base + elapsed;
}

/* At most one overlay record is admitted at each PCM-record boundary. */
static int audio_overlay_service(struct output_state *output,
                                 uint64_t emitted_pcm_frames,
                                 unsigned rate_hz)
{
    struct audio_overlay_state *state = &output->audio_overlay;
    int action = audio_visualizer_take_overlay_action(
        output->visualizer, emitted_pcm_frames, rate_hz);
    uint64_t due;

    if (action < 0) {
        state->state = AUDIO_OVERLAY_IDLE;
        state->visible = 0;
        return emit_overlay_clear(output) < 0 ? -1 : 1;
    }
    if (action > 0) {
        state->state = AUDIO_OVERLAY_IDLE;
        state->visible = 1;
        state->next_update = emitted_pcm_frames;
        return audio_overlay_style(output, MEDIA_PLAYER_OVERLAY_STYLE, 1) < 0 ?
               -1 : 1;
    }
    if (!state->visible)
        return 0;
    if (state->state == AUDIO_OVERLAY_IDLE) {
        if (emitted_pcm_frames < state->next_update)
            return 0;
        if (audio_overlay_render(output,
                audio_overlay_position(output, emitted_pcm_frames)) < 0)
            return -1;
        state->state = AUDIO_OVERLAY_CONFIG;
        state->frame_start = emitted_pcm_frames;
        state->offset = 0;
        state->record_index = 0;
    }
    due = state->frame_start +
          ((uint64_t)(state->record_index + 1u) * rate_hz) /
          AUDIO_OVERLAY_RECORDS;
    if (emitted_pcm_frames < due)
        return 0;
    if (state->state == AUDIO_OVERLAY_CONFIG) {
        if (audio_overlay_style(output, MEDIA_PLAYER_OVERLAY_CONFIG, 1) < 0)
            return -1;
        state->state = AUDIO_OVERLAY_DATA;
    } else if (state->state == AUDIO_OVERLAY_DATA) {
        size_t count = AUDIO_UI_OVERLAY_BYTES - state->offset;

        if (count > 4096u)
            count = 4096u;
        if (emit_display_record(output, MEDIA_PLAYER_OVERLAY_DATA,
                                state->plane + state->offset, count) < 0)
            return -1;
        state->offset += count;
        if (state->offset == AUDIO_UI_OVERLAY_BYTES)
            state->state = AUDIO_OVERLAY_COMMIT;
    } else {
        if (emit_display_record(output, MEDIA_PLAYER_OVERLAY_COMMIT,
                                NULL, 0) < 0)
            return -1;
        state->state = AUDIO_OVERLAY_IDLE;
        state->next_update = emitted_pcm_frames;
    }
    state->record_index++;
    return 1;
}

static enum media_source_dvd_command dvd_source_command(int command)
{
    switch (command) {
    case MEDIA_PLAYER_CONTROL_MENU_UP:
        return MEDIA_SOURCE_DVD_MENU_UP;
    case MEDIA_PLAYER_CONTROL_MENU_DOWN:
        return MEDIA_SOURCE_DVD_MENU_DOWN;
    case MEDIA_PLAYER_CONTROL_MENU_LEFT:
        return MEDIA_SOURCE_DVD_MENU_LEFT;
    case MEDIA_PLAYER_CONTROL_MENU_RIGHT:
        return MEDIA_SOURCE_DVD_MENU_RIGHT;
    case MEDIA_PLAYER_CONTROL_MENU_ACTIVATE:
        return MEDIA_SOURCE_DVD_MENU_ACTIVATE;
    case MEDIA_PLAYER_CONTROL_ROOT_MENU:
        return MEDIA_SOURCE_DVD_ROOT_MENU;
    default:
        return 0;
    }
}

static int acknowledge_menu_continuation(struct dvd_menu_state *menu,
                                         int control_fd,
                                         const char *reason)
{
    if (control_send(control_fd, MEDIA_PLAYER_CONTROL_MENU_CONTINUE) < 0)
        return -1;
    menu->activation_pending = 0;
    menu->activation_payloads = 0;
    menu->activation_staged_hop = 0;
    menu->activation_prior_pts_valid = 0;
    menu->activation_prior_pts = 0;
    fprintf(stderr,
            "media_player_helper: DVD menu continuation reason=%s\n",
            reason);
    return 0;
}

static int refresh_dvd_menu_state(struct media_source *input,
                                  struct dvd_menu_state *menu,
                                  struct output_state *output,
                                  int control_fd)
{
    struct media_source_dvd_state state;
    int menu_entered = 0;

    if (!menu->enabled || !media_source_dvd_state(input, &state))
        return 0;
    if (state.menu_changed || state.menu_active != menu->menu_active) {
        menu_entered = state.menu_active && !menu->menu_active;
        menu->menu_active = state.menu_active;
        if (control_fd >= 0 &&
            control_send(control_fd, state.menu_active ?
                         MEDIA_PLAYER_CONTROL_MENU_ENTER :
                         MEDIA_PLAYER_CONTROL_MENU_LEAVE) < 0)
            return -1;
        fprintf(stderr, "media_player_helper: DVD menu %s\n",
                state.menu_active ? "entered" : "left");
    }
    if (state.clut_changed)
        dvd_spu_set_clut(menu->decoder, state.clut);
    if (state.spu_stream_changed) {
        menu->spu_stream = state.spu_stream;
        dvd_spu_set_stream(menu->decoder, menu->spu_stream);
        fprintf(stderr, "media_player_helper: DVD SPU stream %d\n",
                menu->spu_stream);
    }
    if (state.highlight_changed) {
        menu->highlight_display = state.highlight_display;
        menu->highlight_palette = state.highlight_palette;
        menu->highlight_x1 = state.highlight_x1;
        menu->highlight_y1 = state.highlight_y1;
        menu->highlight_x2 = state.highlight_x2;
        menu->highlight_y2 = state.highlight_y2;
    }
    if (state.clut_changed || state.highlight_changed) {
        if (dvd_spu_set_highlight(menu->decoder, menu->highlight_display,
                                  menu->highlight_palette,
                                  menu->highlight_x1, menu->highlight_y1,
                                  menu->highlight_x2, menu->highlight_y2) < 0)
            return -1;
        if (menu->overlay_emitted &&
            emit_overlay_style(output, dvd_spu_overlay(menu->decoder),
                               MEDIA_PLAYER_OVERLAY_STYLE) < 0)
            return -1;
    }
    if (state.hop && menu->overlay_emitted) {
        if (emit_overlay_clear(output) < 0)
            return -1;
        menu->overlay_emitted = 0;
    }
    return menu_entered;
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

static int has_suffix_case(const char *text, const char *suffix)
{
    size_t text_length = text ? strlen(text) : 0;
    size_t suffix_length = strlen(suffix);

    return text_length >= suffix_length &&
           !strcasecmp(text + text_length - suffix_length, suffix);
}

/*
 * Return the first bytes after any leading ID3v2 tags. The tag body is opaque
 * to playback, but its synchsafe size is validated and bounded before it is
 * skipped. ID3v2.4's optional footer follows the declared body.
 */
static int read_mp3_prefix(struct media_source *input,
                           uint8_t prefix[10], size_t *prefix_size)
{
    for (;;) {
        uint32_t body_size;
        size_t skip;

        if (media_source_read(input, prefix, 10) != 10) {
            fprintf(stderr, "media_player_helper: MP3 input is too short\n");
            return -1;
        }
        if (memcmp(prefix, "ID3", 3)) {
            *prefix_size = 10;
            return 0;
        }
        if ((prefix[6] | prefix[7] | prefix[8] | prefix[9]) & 0x80u) {
            fprintf(stderr, "media_player_helper: invalid ID3v2 synchsafe size\n");
            return -1;
        }
        body_size = ((uint32_t)prefix[6] << 21) |
                    ((uint32_t)prefix[7] << 14) |
                    ((uint32_t)prefix[8] << 7) |
                    (uint32_t)prefix[9];
        if (body_size > ID3V2_TAG_LIMIT) {
            fprintf(stderr,
                    "media_player_helper: ID3v2 tag exceeds %u-byte limit\n",
                    (unsigned)ID3V2_TAG_LIMIT);
            return -1;
        }
        skip = body_size;
        if (prefix[3] == 4 && (prefix[5] & 0x10u))
            skip += 10u;
        if (skip_bytes(input, skip) < 0) {
            fprintf(stderr, "media_player_helper: truncated ID3v2 tag\n");
            return -1;
        }
    }
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

/*
 * A libdvdnav ISO or direct-disc title can cross a cell or VOB boundary
 * whose PES clock restarts even though the selected title continues.  The
 * scheduler and FPGA need one continuous title clock, while ordinary MPEG
 * decode-order PTS reordering must remain visible.  The ten-second backward
 * threshold is an implementation guard, not a DVD or MPEG limit.  Translate
 * a detected new DVD epoch so its first timestamp follows the prior maximum
 * by one 90 kHz tick; encoded cadence still supplies the minimum picture
 * interval.
 */
static int establish_forced_pts_epoch(struct output_state *output,
                                      uint64_t raw_pts)
{
    uint64_t next;

    if (!output->iso_pts_rebase_pending)
        return 0;
    if (output->iso_pts_rebase_floor == UINT64_MAX) {
        fprintf(stderr,
                "media_player_helper: DVD automatic menu PTS epoch overflow\n");
        return -1;
    }
    next = output->iso_pts_rebase_floor + 1u;
    output->iso_pts_epoch_offset = raw_pts < next ? next - raw_pts : 0;
    output->iso_pts_rebase_pending = 0;
    fprintf(stderr,
            "media_player_helper: DVD automatic menu PTS epoch raw=%llu "
            "normalized=%llu offset=%llu\n",
            (unsigned long long)raw_pts,
            (unsigned long long)(raw_pts + output->iso_pts_epoch_offset),
            (unsigned long long)output->iso_pts_epoch_offset);
    return 0;
}

static int normalize_video_pts(struct output_state *output, uint64_t raw_pts,
                               uint64_t *normalized_pts)
{
    uint64_t normalized;

    if (!output->iso_pts_normalization) {
        *normalized_pts = raw_pts;
        return 0;
    }
    if (establish_forced_pts_epoch(output, raw_pts) < 0)
        return -1;
    if (!output->have_iso_video_pts) {
        if (raw_pts > UINT64_MAX - output->iso_pts_epoch_offset) {
            fprintf(stderr,
                    "media_player_helper: normalized DVD PTS overflow\n");
            return -1;
        }
        normalized = raw_pts + output->iso_pts_epoch_offset;
        output->have_iso_video_pts = 1;
        output->iso_pts_raw_max = raw_pts;
        if (normalized > output->iso_pts_normalized_max)
            output->iso_pts_normalized_max = normalized;
        *normalized_pts = normalized;
        return 0;
    }
    if (raw_pts < output->iso_pts_raw_max &&
        output->iso_pts_raw_max - raw_pts > ISO_PTS_DISCONTINUITY_TICKS) {
        uint64_t next;

        if (output->iso_pts_normalized_max == UINT64_MAX) {
            fprintf(stderr,
                    "media_player_helper: DVD PTS epoch overflow\n");
            return -1;
        }
        next = output->iso_pts_normalized_max + 1u;
        if (raw_pts > next) {
            fprintf(stderr,
                    "media_player_helper: invalid DVD PTS epoch\n");
            return -1;
        }
        output->iso_pts_epoch_offset = next - raw_pts;
        output->iso_pts_raw_max = raw_pts;
        output->iso_pts_discontinuities++;
        fprintf(stderr,
                "media_player_helper: DVD PTS discontinuity raw=%llu "
                "normalized=%llu offset=%llu count=%u\n",
                (unsigned long long)raw_pts,
                (unsigned long long)next,
                (unsigned long long)output->iso_pts_epoch_offset,
                output->iso_pts_discontinuities);
    }
    if (raw_pts > UINT64_MAX - output->iso_pts_epoch_offset) {
        fprintf(stderr,
                "media_player_helper: normalized DVD PTS overflow\n");
        return -1;
    }
    normalized = raw_pts + output->iso_pts_epoch_offset;
    if (raw_pts > output->iso_pts_raw_max)
        output->iso_pts_raw_max = raw_pts;
    if (normalized > output->iso_pts_normalized_max)
        output->iso_pts_normalized_max = normalized;
    *normalized_pts = normalized;
    return 0;
}

static int normalize_audio_pts(struct output_state *output, uint64_t raw_pts,
                               uint64_t *normalized_pts)
{
    if (!output->iso_pts_normalization) {
        *normalized_pts = raw_pts;
        return 0;
    }
    if (establish_forced_pts_epoch(output, raw_pts) < 0)
        return -1;
    if (raw_pts > UINT64_MAX - output->iso_pts_epoch_offset) {
        fprintf(stderr,
                "media_player_helper: normalized DVD audio PTS overflow\n");
        return -1;
    }
    *normalized_pts = raw_pts + output->iso_pts_epoch_offset;
    return 0;
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
    if (write_output(output, record, sizeof(record), "video timestamp") < 0)
        return -1;
    output->video_bytes += sizeof(record);
    output->video_pts++;
    return 0;
}

static int emit_pcm_run(struct output_state *output,
                        const int16_t *frames, unsigned count, int rate_hz)
{
    uint8_t record[4 + 1 + PCM_RECORD_FRAMES * 4u];
    unsigned i;

    /*
     * Entry 431: the FPGA already selects between 48 kHz and 44.1 kHz from this
     * mode bit -- mpeg2_h262_inband_metadata extracts it and
     * audio_pcm_output_adapter switches its phase step on it -- so the rate
     * only ever needed carrying here.  Records are always emitted stereo; a
     * mono frame is duplicated into both channels by write_pcm.
     *
     * Entry 462: the mode byte carries how many frames follow,
     * so one record delivers a run instead of a single sample.  At one frame
     * per record the audio was three quarters of everything crossing the
     * shared path, and hardware measured a cost per record in late
     * presentations.
     *
     * Entry 699: bit seven distinguishes IEC 61937 bursts from decoded PCM.
     * The output selection alone cannot make this decision: both kinds may be
     * routed to S/PDIF, but only a burst may set IEC 60958 non-audio status.
     * Five count bits still cover the helper's bounded sixteen-frame records.
     */
    record[0] = 0;
    record[1] = 0;
    record[2] = 1;
    record[3] = MEDIA_PLAYER_PCM_MARKER_CODE;
    record[4] = (uint8_t)((count << 2) | MEDIA_PLAYER_PCM_MODE_STEREO |
                          (output->pcm_non_audio ?
                              MEDIA_PLAYER_PCM_MODE_NON_AUDIO : 0) |
                          (rate_hz == 48000 ? MEDIA_PLAYER_PCM_MODE_48K : 0));
    for (i = 0; i < count; ++i) {
        uint16_t left_bits = (uint16_t)frames[i * 2u];
        uint16_t right_bits = (uint16_t)frames[i * 2u + 1u];

        record[5 + i * 4u] = (uint8_t)(left_bits >> 8);
        record[6 + i * 4u] = (uint8_t)left_bits;
        record[7 + i * 4u] = (uint8_t)(right_bits >> 8);
        record[8 + i * 4u] = (uint8_t)right_bits;
    }
    if (write_output(output, record, 5u + count * 4u, "in-band PCM") < 0)
        return -1;
    output->video_bytes_since_pcm = 0;
    return 0;
}

static int emit_pcm_end(struct output_state *output)
{
    const uint8_t record[4] = {0, 0, 1, MEDIA_PLAYER_PCM_END_MARKER_CODE};
    return write_output(output, record, sizeof(record), "PCM end marker");
}

/* Write bytes that the scheduler has admitted to the shared FPGA path. */
static int write_video_immediate(struct output_state *output, const void *data,
                                 size_t size, const char *what)
{
    const uint8_t *bytes = data;
    size_t i;

    if (write_output(output, bytes, size, what) < 0)
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

static int write_visualizer_video(void *opaque, const uint8_t *data,
                                  size_t size)
{
    return write_video_immediate(opaque, data, size, "audio visualizer video");
}

static int video_queue_would_overflow(const struct output_state *output,
                                      size_t size, int has_record)
{
    size_t prefix = has_record ? 9u : 0u;
    size_t pending = output->h262_chroma_normalization &&
                     output->h262_chroma.have_pending ? 1u : 0u;
    size_t incoming;

    if (size > VIDEO_QUEUE_LIMIT - prefix)
        return 1;
    incoming = size + prefix;
    if (pending > VIDEO_QUEUE_LIMIT - incoming)
        return 1;
    incoming += pending;
    return output->video_queued_bytes > VIDEO_QUEUE_LIMIT - incoming;
}

static int queue_video(struct output_state *output, const uint8_t *data,
                       size_t size, int has_pts, int has_record, uint64_t pts)
{
    struct video_chunk *chunk;
    size_t prefix = has_record ? 9u : 0u;

    if (video_queue_would_overflow(output, size, has_record)) {
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

static void h262_chroma_stream_consume(
    struct h262_chroma_stream_state *state, uint8_t current,
    uint8_t *previous, int log_correction)
{
    uint32_t window = (state->window << 8) | current;

    if ((window & UINT32_C(0xffffff00)) == UINT32_C(0x00000100)) {
        state->start_code = current;
        state->payload_index = 0;
        state->extension_id = 0xffu;
        if (current == 0xb3u) {
            state->sequence_pending = 1;
            state->sequence_extension_valid = 0;
            state->sequence_chroma_format = 0;
            state->picture_started_since_sequence = 0;
            state->picture_header_valid = 0;
            state->picture_structure_valid = 0;
        } else if (current == 0x00u) {
            if (state->picture_started_since_sequence)
                state->sequence_pending = 0;
            state->picture_started_since_sequence = 1;
            state->picture_header_valid = 0;
            state->picture_coding_type = 0;
            state->picture_structure_valid = 0;
            state->picture_structure = 0;
        }
        state->window = window;
        state->input_bytes++;
        return;
    }

    if (state->start_code == 0xb5u) {
        if (state->payload_index == 0u) {
            state->extension_id = current >> 4;
        } else if (state->extension_id == 1u &&
                   state->payload_index == 1u) {
            state->sequence_chroma_format = (current >> 1) & 3u;
            state->sequence_extension_valid = 1;
        } else if (state->extension_id == 8u &&
                   state->payload_index == 2u) {
            state->picture_structure = current & 3u;
            state->picture_structure_valid = 1;
        } else if (state->extension_id == 8u &&
                   state->payload_index == 4u) {
            if (previous && state->sequence_pending &&
                state->sequence_extension_valid &&
                state->sequence_chroma_format == 1u &&
                state->picture_header_valid &&
                state->picture_coding_type == 1u &&
                state->picture_structure_valid &&
                state->picture_structure == 3u &&
                (current & 0x80u) && !(*previous & 1u)) {
                uint8_t before = *previous;

                *previous |= 1u;
                state->corrections++;
                if (log_correction)
                    fprintf(stderr,
                            "media_player_helper: H262 stream normalized "
                            "chroma_420_type offset=%llu before=%02x "
                            "after=%02x correction=%u\n",
                            (unsigned long long)(state->input_bytes - 1u),
                            before, *previous, state->corrections);
            }
            state->sequence_pending = 0;
        }
    } else if (state->start_code == 0x00u &&
               state->payload_index == 1u) {
        state->picture_coding_type = (current >> 3) & 7u;
        state->picture_header_valid = 1;
    }

    state->payload_index++;
    state->window = window;
    state->input_bytes++;
}

/*
 * Filter one elementary-video payload in place.  The returned prefix is the
 * final byte of the preceding payload, now safe to emit; data[0..return-1]
 * are the safe bytes of this payload.  Its final byte remains in state until
 * the next payload or an explicit stream-boundary flush.
 */
static size_t h262_chroma_stream_filter(
    struct h262_chroma_stream_state *state, uint8_t *data, size_t size,
    uint8_t *prefix, int *prefix_valid, int log_correction)
{
    size_t offset;

    *prefix_valid = 0;
    for (offset = 0; offset < size; offset++) {
        uint8_t current = data[offset];

        h262_chroma_stream_consume(
            state, current, state->have_pending ? &state->pending_byte : NULL,
            log_correction);
        if (state->have_pending) {
            if (!offset) {
                *prefix = state->pending_byte;
                *prefix_valid = 1;
            } else {
                data[offset - 1u] = state->pending_byte;
            }
        }
        state->pending_byte = current;
        state->have_pending = 1;
    }
    return size ? size - 1u : 0u;
}

static int queue_h262_video(struct output_state *output, uint8_t *data,
                            size_t size, int has_pts, int has_record,
                            uint64_t pts)
{
    int pending_has_pts = output->h262_pending_has_pts;
    int pending_has_record = output->h262_pending_has_record;
    uint64_t pending_pts = output->h262_pending_pts;
    uint8_t prefix = 0;
    int prefix_valid = 0;
    size_t safe_size;

    if (!output->h262_chroma_normalization || !size)
        return queue_video(output, data, size, has_pts, has_record, pts);
    safe_size = h262_chroma_stream_filter(
        &output->h262_chroma, data, size, &prefix, &prefix_valid, 1);
    if (prefix_valid &&
        queue_video(output, &prefix, 1u, pending_has_pts,
                    pending_has_record, pending_pts) < 0)
        return -1;
    if (safe_size &&
        queue_video(output, data, safe_size, has_pts, has_record, pts) < 0)
        return -1;
    if (safe_size) {
        output->h262_pending_has_pts = 0;
        output->h262_pending_has_record = 0;
        output->h262_pending_pts = 0;
    } else {
        output->h262_pending_has_pts = has_pts;
        output->h262_pending_has_record = has_record;
        output->h262_pending_pts = pts;
    }
    return 0;
}

static int flush_h262_video(struct output_state *output)
{
    struct h262_chroma_stream_state *state = &output->h262_chroma;
    uint8_t byte;

    if (!output->h262_chroma_normalization || !state->have_pending)
        return 0;
    byte = state->pending_byte;
    state->have_pending = 0;
    if (queue_video(output, &byte, 1u, output->h262_pending_has_pts,
                    output->h262_pending_has_record,
                    output->h262_pending_pts) < 0)
        return -1;
    output->h262_pending_has_pts = 0;
    output->h262_pending_has_record = 0;
    output->h262_pending_pts = 0;
    return 0;
}

struct h262_restart_diagnostic {
    int sequence_header_valid;
    unsigned horizontal_size;
    unsigned vertical_size;
    unsigned aspect_ratio;
    unsigned frame_rate_code;
    unsigned sequence_marker;
    int sequence_extension_valid;
    size_t sequence_extension_offset;
    uint8_t sequence_extension[6];
    unsigned progressive_sequence;
    unsigned chroma_format;
    int picture_header_valid;
    unsigned temporal_reference;
    unsigned picture_coding_type;
    int picture_extension_valid;
    size_t picture_extension_offset;
    uint8_t picture_extension[5];
};

static int h262_start_code_at(const uint8_t *data, size_t size,
                              size_t offset, uint8_t code)
{
    return offset + 4u <= size && data[offset] == 0x00u &&
           data[offset + 1u] == 0x00u && data[offset + 2u] == 0x01u &&
           data[offset + 3u] == code;
}

static void collect_h262_restart_diagnostic(
    const uint8_t *data, size_t size,
    const struct dvd_random_access_result *restart,
    struct h262_restart_diagnostic *diagnostic)
{
    size_t offset;

    memset(diagnostic, 0, sizeof(*diagnostic));
    diagnostic->sequence_extension_offset = SIZE_MAX;
    diagnostic->picture_extension_offset = SIZE_MAX;

    if (h262_start_code_at(data, size, restart->sequence_offset, 0xb3u) &&
        restart->sequence_offset + 11u <= size) {
        const uint8_t *header = data + restart->sequence_offset + 4u;

        diagnostic->sequence_header_valid = 1;
        diagnostic->horizontal_size =
            ((unsigned)header[0] << 4) | ((unsigned)header[1] >> 4);
        diagnostic->vertical_size =
            (((unsigned)header[1] & 0x0fu) << 8) | header[2];
        diagnostic->aspect_ratio = header[3] >> 4;
        diagnostic->frame_rate_code = header[3] & 0x0fu;
        diagnostic->sequence_marker = (header[6] >> 5) & 1u;
    }

    if (h262_start_code_at(data, size, restart->intra_offset, 0x00u) &&
        restart->intra_offset + 6u <= size) {
        const uint8_t *header = data + restart->intra_offset + 4u;

        diagnostic->picture_header_valid = 1;
        diagnostic->temporal_reference =
            ((unsigned)header[0] << 2) | ((unsigned)header[1] >> 6);
        diagnostic->picture_coding_type = (header[1] >> 3) & 7u;
    }

    for (offset = restart->sequence_offset + 4u;
         offset + 10u <= size && offset < restart->intra_offset;
         offset++) {
        if (h262_start_code_at(data, size, offset, 0xb5u) &&
            (data[offset + 4u] >> 4) == 1u) {
            diagnostic->sequence_extension_valid = 1;
            diagnostic->sequence_extension_offset = offset;
            memcpy(diagnostic->sequence_extension, data + offset + 4u,
                   sizeof(diagnostic->sequence_extension));
            diagnostic->progressive_sequence =
                (diagnostic->sequence_extension[1] >> 3) & 1u;
            diagnostic->chroma_format =
                (diagnostic->sequence_extension[1] >> 1) & 3u;
            break;
        }
    }

    for (offset = restart->intra_offset + 4u;
         offset + 9u <= size && offset < restart->next_reference_offset;
         offset++) {
        if (h262_start_code_at(data, size, offset, 0xb5u) &&
            (data[offset + 4u] >> 4) == 8u) {
            diagnostic->picture_extension_valid = 1;
            diagnostic->picture_extension_offset = offset;
            memcpy(diagnostic->picture_extension, data + offset + 4u,
                   sizeof(diagnostic->picture_extension));
            break;
        }
    }
}

struct h262_restart_normalization {
    size_t byte_offset;
    uint8_t before;
    uint8_t after;
};

static int normalize_h262_restart_chroma_420(
    uint8_t *data, size_t size,
    const struct dvd_random_access_result *restart,
    struct h262_restart_normalization *normalization)
{
    struct h262_restart_diagnostic diagnostic;
    const uint8_t *picture;

    memset(normalization, 0, sizeof(*normalization));
    normalization->byte_offset = SIZE_MAX;
    collect_h262_restart_diagnostic(data, size, restart, &diagnostic);
    picture = diagnostic.picture_extension;
    if (!diagnostic.sequence_header_valid ||
        !diagnostic.sequence_extension_valid ||
        diagnostic.chroma_format != 1u ||
        !diagnostic.picture_header_valid ||
        diagnostic.picture_coding_type != 1u ||
        !diagnostic.picture_extension_valid ||
        (picture[2] & 3u) != 3u ||
        !(picture[4] & 0x80u) || (picture[3] & 1u))
        return 0;

    normalization->byte_offset = diagnostic.picture_extension_offset + 7u;
    normalization->before = data[normalization->byte_offset];
    data[normalization->byte_offset] |= 1u;
    normalization->after = data[normalization->byte_offset];
    return 1;
}

static void log_h262_restart_diagnostic(
    const uint8_t *data, size_t size, int terminal,
    const struct dvd_random_access_result *restart)
{
    static const char hex[] = "0123456789abcdef";
    struct h262_restart_diagnostic diagnostic;
    char prefix[H262_RESTART_DIAGNOSTIC_PREFIX_BYTES * 2u + 1u];
    const uint8_t *picture;
    size_t prefix_bytes = size;
    size_t offset;

    if (prefix_bytes > H262_RESTART_DIAGNOSTIC_PREFIX_BYTES)
        prefix_bytes = H262_RESTART_DIAGNOSTIC_PREFIX_BYTES;
    for (offset = 0; offset < prefix_bytes; offset++) {
        prefix[offset * 2u] = hex[data[offset] >> 4];
        prefix[offset * 2u + 1u] = hex[data[offset] & 0x0fu];
    }
    prefix[prefix_bytes * 2u] = '\0';
    collect_h262_restart_diagnostic(data, size, restart, &diagnostic);
    picture = diagnostic.picture_extension;

    fprintf(stderr,
            "media_player_helper: H262 restart diagnostic terminal=%d "
            "bytes=%zu sequence=%zu intra=%zu next_reference=%zu "
            "prefix_bytes=%zu prefix=%s\n",
            terminal, size, restart->sequence_offset, restart->intra_offset,
            restart->next_reference_offset, prefix_bytes, prefix);
    fprintf(stderr,
            "media_player_helper: H262 restart fields sequence_valid=%d "
            "size=%ux%u aspect=%u rate=%u marker=%u "
            "sequence_ext_valid=%d sequence_ext_offset=%zu "
            "sequence_ext=%02x%02x%02x%02x%02x%02x "
            "sequence_progressive=%u chroma_format=%u "
            "picture_valid=%d temporal=%u type=%u "
            "picture_ext_valid=%d picture_ext_offset=%zu "
            "picture_ext=%02x%02x%02x%02x%02x "
            "f_code=%u,%u,%u,%u intra_dc=%u structure=%u top=%u "
            "frame_pred=%u concealment=%u q_scale=%u intra_vlc=%u "
            "alternate_scan=%u repeat=%u chroma420=%u progressive=%u\n",
            diagnostic.sequence_header_valid, diagnostic.horizontal_size,
            diagnostic.vertical_size, diagnostic.aspect_ratio,
            diagnostic.frame_rate_code, diagnostic.sequence_marker,
            diagnostic.sequence_extension_valid,
            diagnostic.sequence_extension_offset,
            diagnostic.sequence_extension[0], diagnostic.sequence_extension[1],
            diagnostic.sequence_extension[2], diagnostic.sequence_extension[3],
            diagnostic.sequence_extension[4], diagnostic.sequence_extension[5],
            diagnostic.progressive_sequence, diagnostic.chroma_format,
            diagnostic.picture_header_valid,
            diagnostic.temporal_reference, diagnostic.picture_coding_type,
            diagnostic.picture_extension_valid,
            diagnostic.picture_extension_offset, picture[0], picture[1],
            picture[2], picture[3], picture[4], picture[0] & 0x0fu,
            picture[1] >> 4, picture[1] & 0x0fu, picture[2] >> 4,
            (picture[2] >> 2) & 3u, picture[2] & 3u,
            picture[3] >> 7, (picture[3] >> 6) & 1u,
            (picture[3] >> 5) & 1u, (picture[3] >> 4) & 1u,
            (picture[3] >> 3) & 1u, (picture[3] >> 2) & 1u,
            (picture[3] >> 1) & 1u, picture[3] & 1u,
            picture[4] >> 7);
}

static int iso_filter_initial_random_access(struct output_state *output,
                                            int terminal)
{
    struct video_chunk *chunk;
    struct dvd_random_access_result filter_result;
    uint8_t *video;
    struct h262_restart_normalization normalization;
    size_t video_size = 0;
    size_t copied = 0;
    int filtered;

    if (!output->iso_start_filter_active)
        return 1;
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        size_t prefix = chunk->has_record ? 9u : 0u;

        if (chunk->offset || chunk->size < prefix) {
            fprintf(stderr,
                    "media_player_helper: invalid random-access startup queue state\n");
            return -1;
        }
        video_size += chunk->size - prefix;
    }
    video = malloc(video_size ? video_size : 1u);
    if (!video) {
        fprintf(stderr,
                "media_player_helper: out of memory filtering random-access startup\n");
        return -1;
    }
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        size_t prefix = chunk->has_record ? 9u : 0u;
        size_t count = chunk->size - prefix;

        memcpy(video + copied, chunk->data + prefix, count);
        copied += count;
    }

    filtered = terminal ?
        dvd_random_access_filter_terminal(video, video_size, &filter_result) :
        dvd_random_access_filter(video, video_size, &filter_result);
    if (filtered <= 0) {
        free(video);
        return filtered;
    }

    if (normalize_h262_restart_chroma_420(
            video, video_size, &filter_result, &normalization)) {
        fprintf(stderr,
                "media_player_helper: H262 restart normalized "
                "chroma_420_type offset=%zu before=%02x after=%02x\n",
                normalization.byte_offset, normalization.before,
                normalization.after);
    }
    log_h262_restart_diagnostic(video, video_size, terminal, &filter_result);

    copied = 0;
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        size_t prefix = chunk->has_record ? 9u : 0u;
        size_t count = chunk->size - prefix;

        memcpy(chunk->data + prefix, video + copied, count);
        copied += count;
    }
    free(video);
    output->iso_start_filter_active = 0;
    fprintf(stderr,
            "media_player_helper: random access %ssequence_offset=%zu "
            "intra_offset=%zu next_reference_offset=%zu discarded=%u "
            "pre-context picture(s), %u leading B picture(s)\n",
            terminal ? "terminal " : "",
            filter_result.sequence_offset, filter_result.intra_offset,
            filter_result.next_reference_offset,
            filter_result.pre_context_pictures,
            filter_result.leading_b_pictures);
    return 1;
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
        size_t due = (output->hold_count - output->hold_head) / 2u - keep;
        unsigned count = due < PCM_RECORD_FRAMES ?
                         (unsigned)due : PCM_RECORD_FRAMES;

        if (emit_pcm_run(output, output->hold + output->hold_head, count,
                         output->hold_rate_hz) < 0)
            return -1;
        output->hold_head += (size_t)count * 2u;
        output->pcm_emitted_frames += count;
        if (output->visualizer) {
            int overlay = audio_overlay_service(
                output, output->pcm_emitted_frames,
                (unsigned)output->hold_rate_hz);

            if (overlay < 0) {
                fprintf(stderr,
                        "media_player_helper: audio overlay output failed\n");
                return -1;
            }
            if (!overlay && audio_visualizer_service(
                    output->visualizer, output->pcm_emitted_frames,
                    (unsigned)output->hold_rate_hz,
                    write_visualizer_video, output) < 0) {
                fprintf(stderr,
                        "media_player_helper: audio visualizer output failed\n");
                return -1;
            }
        } else if (output->audio_ui &&
            audio_ui_service(output->audio_ui,
                             output->pcm_emitted_frames,
                             (unsigned)output->hold_rate_hz,
                             emit_audio_ui_record, output) < 0) {
            fprintf(stderr,
                    "media_player_helper: audio UI output failed\n");
            return -1;
        }
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

/*
 * The physical-DVD reserve is intentionally large enough to bridge optical
 * stalls during ordinary playback.  Once a timestamp-stalled menu falls back
 * to sink pacing, however, allowing that reserve to absorb decoded PCM turns
 * four MiB into roughly twenty seconds of audio lead.  Drain it before each
 * fallback scheduler batch so the pipe and FPGA credit, rather than reserve
 * capacity, set the delivery rate.  Each individual write remains bounded even
 * when hold pressure requires several writes in one scheduler pass.
 */
static int scheduler_emit_pcm(struct output_state *output, uint64_t frames)
{
    if (output->automatic_menu_pcm_fallback && output->reserve &&
        output_reserve_drain(output->reserve) < 0) {
        fprintf(stderr,
                "media_player_helper: automatic menu PCM pacing failed: %s\n",
                strerror(errno));
        return -1;
    }
    return hold_emit_frames(output, frames);
}

static size_t scheduler_automatic_menu_pcm_watermark(
    const struct output_state *output)
{
    size_t watermark = output->hold_limit / 2u;

    return watermark > PCM_SCHEDULE_RESERVE_FRAMES ?
           watermark : PCM_SCHEDULE_RESERVE_FRAMES;
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

/* Keep interpolated delivery in complete guard-sized runs, not tiny records. */
static uint64_t scheduler_pcm_delivery_target(
    const struct output_state *output, uint64_t video_pts)
{
    uint64_t target = scheduler_pcm_target(output, video_pts);

    return target - target % PCM_REFILL_FRAMES;
}

/*
 * A later timestamp can already be present in the bounded queue while an
 * untimestamped run ahead of it is crossing the shared path.  Waiting for the
 * timestamped chunk to become the head leaves only the fixed byte guard to
 * feed audio through that run.  Spread the known timeline advance across the
 * intervening bytes so its PCM crosses before those bytes can fill the clean
 * video queue and block the extractor.  This changes delivery order and PCM
 * record grouping only: timestamp bytes, compressed video and the ordered PCM
 * sample payload remain exact.
 */
static uint64_t scheduler_video_horizon(const struct output_state *output,
                                        size_t next_slice)
{
    const struct video_chunk *chunk;
    uint64_t horizon = output->max_video_pts;
    uint64_t future_byte = output->video_bytes;
    uint64_t progress;

    if (output->video_head->has_pts &&
        (!output->have_video_pts || output->video_head->pts > horizon))
        horizon = output->video_head->pts;
    if (!output->have_video_pts)
        return horizon;

    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        if (chunk->has_pts && chunk->pts > output->max_video_pts) {
            uint64_t span;
            uint64_t delta;
            uint64_t interpolated;

            if (future_byte <= output->max_video_pts_byte)
                return chunk->pts > horizon ? chunk->pts : horizon;
            span = future_byte - output->max_video_pts_byte;
            progress = output->video_bytes + (uint64_t)next_slice -
                       output->max_video_pts_byte;
            if (progress >= span)
                return chunk->pts > horizon ? chunk->pts : horizon;
            delta = chunk->pts - output->max_video_pts;
            interpolated = output->max_video_pts +
                           (delta * progress + span - 1u) / span;
            return interpolated > horizon ? interpolated : horizon;
        }
        future_byte += (uint64_t)(chunk->size - chunk->offset);
    }
    return horizon;
}

static void scheduler_accept_video_pts(struct output_state *output,
                                       const struct video_chunk *chunk)
{
    if (!chunk->has_pts)
        return;
    if (output->have_video_pts && chunk->pts <= output->max_video_pts) {
        if (output->automatic_menu_epoch &&
            chunk->pts == output->max_video_pts &&
            output->automatic_menu_stalled_pts != UINT32_MAX)
            output->automatic_menu_stalled_pts++;
        return;
    }
    if (output->automatic_menu_epoch) {
        output->automatic_menu_stalled_pts = 0;
        if (output->automatic_menu_pcm_fallback) {
            fprintf(stderr,
                    "media_player_helper: automatic menu PCM timestamp "
                    "scheduling resumed old_pts=%llu new_pts=%llu "
                    "fallback_frames=%llu\n",
                    (unsigned long long)output->max_video_pts,
                    (unsigned long long)chunk->pts,
                    (unsigned long long)
                        output->automatic_menu_pcm_fallback_frames);
            output->automatic_menu_pcm_fallback = 0;
        }
    }
    output->max_video_pts = chunk->pts;
    output->max_video_pts_byte = output->video_bytes - chunk->offset;
    output->have_video_pts = 1;
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

static void reset_audio_for_navigation(struct audio_state *audio)
{
    enum audio_codec selected_codec = audio->codec;
    enum audio_output selected_output = audio->output;
    int selected_a52_substream = audio->a52_substream;
    int selected_dts_substream = audio->dts_substream;
    uint32_t unsupported_private_audio_mask =
        audio->unsupported_private_audio_mask;

    if (audio->a52)
        a52_free(audio->a52);
    free(audio->data);
    memset(audio, 0, sizeof(*audio));
    audio->codec = selected_codec;
    audio->output = selected_output;
    audio->a52_substream = selected_a52_substream;
    audio->dts_substream = selected_dts_substream;
    audio->unsupported_private_audio_mask =
        unsupported_private_audio_mask;
    mp3dec_init(&audio->decoder);
    fprintf(stderr,
            "media_player_helper: navigation audio retained codec=%d "
            "ac3_substream=%d dts_substream=%d\n",
            (int)audio->codec, audio->a52_substream,
            audio->dts_substream);
}

static void reset_output_for_navigation(struct output_state *output,
                                        size_t hold_limit,
                                        int dvd_timeline)
{
    FILE *video = output->video;
    FILE *pcm = output->pcm;
    struct output_reserve *reserve = output->reserve;
    struct output_stage *activation_stage = output->activation_stage;

    free(output->hold);
    output->hold = NULL;
    while (output->video_head)
        free_video_head(output);
    memset(output, 0, sizeof(*output));
    output->video = video;
    output->pcm = pcm;
    output->reserve = reserve;
    output->activation_stage = activation_stage;
    output->hold_limit = hold_limit;
    output->hold_active = hold_limit != 0;
    output->scheduler_started = !output->hold_active;
    output->scheduler_enabled = pcm == NULL;
    output->iso_pts_normalization = dvd_timeline;
    output->iso_start_filter_active = output->scheduler_enabled;
    output->h262_chroma_normalization =
        dvd_timeline && output->scheduler_enabled;
}

static void reset_for_stream_boundary(struct audio_state *audio,
                                      struct output_state *output)
{
    size_t hold_limit = output->hold_limit;

    reset_audio_for_navigation(audio);
    reset_output_for_navigation(output, hold_limit, 1);
}

/*
 * A title-to-menu domain change does not itself end the elementary video
 * sequence.  Once silent-video lookahead has released, keep that live FPGA
 * decoder context and start only a fresh helper scheduling epoch.  The first
 * menu timestamp is explicitly rebased above the last emitted DVD timestamp;
 * the same offset is applied to video and audio so their authored relation is
 * unchanged while the continuing FPGA timeline never moves backward.
 */
static int rearm_for_automatic_menu(struct audio_state *audio,
                                    struct output_state *output)
{
    size_t hold_limit = output->hold_limit;
    uint64_t prior_video_bytes = output->video_bytes;
    uint64_t prior_pts = output->iso_pts_normalized_max;
    int have_prior_pts = output->have_iso_video_pts;

    if (output->video_head || output->video_queued_bytes ||
        output->h262_chroma.have_pending) {
        fprintf(stderr,
                "media_player_helper: automatic menu reached with pending "
                "silent-video output\n");
        return -1;
    }
    reset_audio_for_navigation(audio);
    reset_output_for_navigation(output, hold_limit, 1);
    output->automatic_menu_epoch = 1;
    output->iso_start_filter_active = 0;
    if (have_prior_pts) {
        output->iso_pts_normalized_max = prior_pts;
        output->iso_pts_rebase_floor = prior_pts;
        output->iso_pts_rebase_pending = 1;
    }
    fprintf(stderr,
            "media_player_helper: DVD automatic menu scheduling epoch "
            "continued prior_video=%llu prior_pts_valid=%d prior_pts=%llu\n",
            (unsigned long long)prior_video_bytes, have_prior_pts,
            (unsigned long long)prior_pts);
    return 0;
}

static int start_pending_menu_activation(struct dvd_menu_state *menu,
                                         struct audio_state *audio,
                                         struct output_state *output)
{
    size_t hold_limit = output->hold_limit;
    uint64_t prior_pts = output->iso_pts_normalized_max;
    int have_prior_pts = output->have_iso_video_pts;

    if (output_stage_active(output->activation_stage) &&
        cancel_activation_stage(output, "superseded-activation") < 0)
        return -1;
    if (begin_activation_stage(output) < 0)
        return -1;
    reset_audio_for_navigation(audio);
    reset_output_for_navigation(output, hold_limit, 1);
    menu->activation_pending = 1;
    menu->activation_payloads = 0;
    menu->activation_staged_hop = 0;
    menu->activation_prior_pts_valid = have_prior_pts;
    menu->activation_prior_pts = prior_pts;
    fprintf(stderr,
            "media_player_helper: DVD menu activation deferred "
            "prior_pts_valid=%d prior_pts=%llu\n",
            have_prior_pts, (unsigned long long)prior_pts);
    return 0;
}

static int cancel_pending_menu_activation(struct dvd_menu_state *menu,
                                          struct output_state *output,
                                          const char *reason)
{
    if (output_stage_active(output->activation_stage) &&
        cancel_activation_stage(output, reason) < 0)
        return -1;
    menu->activation_pending = 0;
    menu->activation_payloads = 0;
    menu->activation_staged_hop = 0;
    menu->activation_prior_pts_valid = 0;
    menu->activation_prior_pts = 0;
    return 0;
}

/*
 * Entry 472: a Program Stream with no audio has no PCM horizon to satisfy.
 * Release its bounded lookahead byte-exactly and continue as silent video.
 * If MPEG audio appears after this decision, process_pes rejects that stream
 * rather than starting it late and creating a permanent synchronization error.
 */
static int scheduler_release_silent_video(struct output_state *output)
{
    size_t queued_bytes;
    uint64_t video_bytes_before = output->video_bytes;

    if (output->iso_start_filter_active) {
        fprintf(stderr,
                "media_player_helper: stream ended before a complete "
                "initial random-access group\n");
        return -1;
    }
    if (flush_h262_video(output) < 0)
        return -1;
    queued_bytes = output->video_queued_bytes;
    output->hold_active = 0;
    output->scheduler_started = 1;
    output->scheduler_enabled = 0;
    output->silent_video_mode = 1;
    while (output->video_head) {
        struct video_chunk *chunk = output->video_head;
        size_t remaining = chunk->size - chunk->offset;

        if (write_video_immediate(output, chunk->data + chunk->offset,
                                  remaining, "silent queued video") < 0)
            return -1;
        chunk->offset += remaining;
        output->video_queued_bytes -= remaining;
        scheduler_accept_video_pts(output, chunk);
        free_video_head(output);
    }
    fprintf(stderr,
            "media_player_helper: video lookahead classified silent "
            "limit=%u queued=%zu released=%llu total_video=%llu "
            "pictures=%u video_pts_valid=%d max_video_pts=%llu\n",
            (unsigned)VIDEO_QUEUE_LIMIT, queued_bytes,
            (unsigned long long)(output->video_bytes - video_bytes_before),
            (unsigned long long)output->video_bytes, output->picture_marks,
            output->have_video_pts,
            (unsigned long long)output->max_video_pts);
    return 0;
}

static int reject_late_audio(const struct output_state *output,
                             const char *codec, int has_pts, uint64_t pts)
{
    const char *relation = "unknown";
    uint64_t delta = 0;

    if (has_pts && output->have_video_pts) {
        if (pts > output->max_video_pts) {
            relation = "ahead";
            delta = pts - output->max_video_pts;
        } else if (pts < output->max_video_pts) {
            relation = "behind";
            delta = output->max_video_pts - pts;
        } else {
            relation = "equal";
        }
    }
    fprintf(stderr,
            "media_player_helper: %s audio begins beyond the bounded video "
            "lookahead audio_pts_valid=%d audio_pts=%llu "
            "video_pts_valid=%d max_video_pts=%llu relation=%s "
            "delta90k=%llu total_video=%llu queued_video=%zu\n",
            codec, has_pts, (unsigned long long)pts,
            output->have_video_pts,
            (unsigned long long)output->max_video_pts, relation,
            (unsigned long long)delta,
            (unsigned long long)output->video_bytes,
            output->video_queued_bytes);
    return -1;
}

/* The startup lead ends only when both its bounds are satisfied. */
static int startup_lead_complete(const struct output_state *output)
{
    return output->picture_marks >= 2 &&
           output->video_bytes >= PCM_STARTUP_VIDEO_BYTES;
}

static size_t startup_video_size(const struct output_state *output,
                                 const struct video_chunk *chunk)
{
    size_t remaining = chunk->size - chunk->offset;
    uint32_t window = output->video_window;
    unsigned pictures = output->picture_marks;
    uint64_t budget;
    size_t i;

    if (pictures < 2) {
        for (i = chunk->offset; i < chunk->size; ++i) {
            window = (window << 8) | chunk->data[i];
            if ((window & 0xffffffffu) == 0x00000100u && ++pictures >= 2)
                return i + 1u - chunk->offset;
        }
        return remaining;
    }
    budget = output->video_bytes < PCM_STARTUP_VIDEO_BYTES ?
             PCM_STARTUP_VIDEO_BYTES - output->video_bytes : 0;
    return (uint64_t)remaining < budget ? remaining : (size_t)budget;
}

/*
 * Entry 692: the sink consumes PCM at exactly 48 kHz (CLK_AUDIO 24.576 MHz,
 * one sample per 512 clocks) while delivery is paced from video timestamps.
 * A systematic shortfall between those two clocks drains the fixed startup
 * reserve and starves audio long after startup, which is consistent with the
 * entry 691 hardware underrun at approximately 85 seconds and with the twelve
 * second opening never reaching it.  Report both clocks once per second so
 * the deficit rate, and whether it exists in the helper at all, can be read
 * off one short hardware run.  This writes to stderr only: no output byte,
 * delivery order, record grouping or scheduling decision changes.
 */
static uint64_t monotonic_us(void)
{
    struct timespec ts;

    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0)
        return 0;
    return (uint64_t)ts.tv_sec * 1000000u + (uint64_t)ts.tv_nsec / 1000u;
}

/*
 * Keep the visualizer's closed GOP loop moving while no media source owns the
 * decoder.  Reuse the audio visualizer's sample-domain scheduler, but derive
 * that domain from monotonic time: idle playback must not emit silent PCM just
 * to obtain a clock.  Main terminates this process when a real source starts.
 */
static int process_idle_visualizer(struct output_state *output)
{
    const unsigned virtual_rate_hz = 48000u;
    const struct timespec delay = {0, 2 * 1000 * 1000};
    uint64_t origin_us = monotonic_us();

    if (!origin_us) {
        fprintf(stderr,
                "media_player_helper: idle visualizer clock unavailable\n");
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: idle visualizer started rate=%u Hz\n",
            virtual_rate_hz);
    for (;;) {
        uint64_t now_us = monotonic_us();
        uint64_t elapsed_us;
        uint64_t virtual_frames;
        int emitted;

        if (!now_us || now_us < origin_us) {
            fprintf(stderr,
                    "media_player_helper: idle visualizer clock failed\n");
            return -1;
        }
        elapsed_us = now_us - origin_us;
        virtual_frames = elapsed_us / 1000000u * virtual_rate_hz +
                         elapsed_us % 1000000u * virtual_rate_hz / 1000000u;
        emitted = audio_visualizer_service(output->visualizer, virtual_frames,
                                            virtual_rate_hz,
                                            write_visualizer_video, output);
        if (emitted < 0) {
            fprintf(stderr,
                    "media_player_helper: idle visualizer output failed\n");
            return -1;
        }
        if (!emitted) {
            struct timespec remaining = delay;

            while (nanosleep(&remaining, &remaining) < 0) {
                if (errno != EINTR) {
                    fprintf(stderr,
                            "media_player_helper: idle visualizer sleep "
                            "failed: %s\n", strerror(errno));
                    return -1;
                }
            }
        }
    }
}

static void scheduler_log_progress(struct output_state *output)
{
    uint64_t now;
    uint64_t elapsed_us;
    uint64_t expected;
    uint64_t target;
    int rate_hz = output->hold_rate_hz ? output->hold_rate_hz : 48000;

    if ((++output->sched_log_poll & 0xffu) != 0u)
        return;
    now = monotonic_us();
    if (!now)
        return;
    if (!output->sched_log_start_us) {
        output->sched_log_start_us = now;
        output->sched_log_next_us = now + 1000000u;
        return;
    }
    if (now < output->sched_log_next_us)
        return;
    output->sched_log_next_us = now + 1000000u;
    elapsed_us = now - output->sched_log_start_us;
    expected = elapsed_us * (uint64_t)rate_hz / 1000000u;
    target = scheduler_pcm_delivery_target(output, output->max_video_pts);
    fprintf(stderr,
            "media_player_helper: sched elapsed_us=%llu emitted=%llu "
            "expected=%llu delta=%lld target=%llu max_video_pts=%llu "
            "held=%zu queued_video=%zu video_bytes=%llu\n",
            (unsigned long long)elapsed_us,
            (unsigned long long)output->pcm_emitted_frames,
            (unsigned long long)expected,
            (long long)expected - (long long)output->pcm_emitted_frames,
            (unsigned long long)target,
            (unsigned long long)output->max_video_pts,
            hold_available(output),
            output->video_queued_bytes,
            (unsigned long long)output->video_bytes);
}

/*
 * Some authored motion menus leave the video horizon at the first audio PTS,
 * repeat one video PTS indefinitely, or stop carrying video timestamps.  Once
 * one of those conditions is established and the normal PTS target is
 * exhausted, release held PCM as bounded batches until half of the configured
 * hold limit remains, or the ordinary startup reserve when that is larger.
 * This leaves symmetric safety headroom without draining the complete optical
 * stall cushion in one pass.  The unchanged output and FPGA FIFO credit pace
 * those writes at the sink clock.  Any later PTS advance disables this fallback
 * before its new timestamp target is evaluated.
 */
static int scheduler_automatic_menu_pcm(struct output_state *output,
                                        uint64_t timestamp_due)
{
    uint64_t video_since_pts;
    size_t available;
    size_t watermark;
    size_t excess;
    size_t emit;

    if (!output->automatic_menu_epoch || timestamp_due ||
        !output->have_audio_pts || !output->have_video_pts)
        return 0;
    video_since_pts = output->video_bytes > output->max_video_pts_byte ?
                      output->video_bytes - output->max_video_pts_byte : 0;
    if (output->max_video_pts > output->first_audio_pts &&
        !output->automatic_menu_stalled_pts &&
        video_since_pts < AUTOMATIC_MENU_STALLED_VIDEO_BYTES)
        return 0;
    watermark = scheduler_automatic_menu_pcm_watermark(output);
    available = hold_available(output);
    if (available <= watermark)
        return 0;
    if (!output->automatic_menu_pcm_fallback) {
        output->automatic_menu_pcm_fallback = 1;
        fprintf(stderr,
                "media_player_helper: automatic menu PCM fallback "
                "activated stalled_pts=%llu repeats=%u video_since_pts=%llu "
                "held=%zu watermark=%zu reserve=%u paced_batch=%u\n",
                (unsigned long long)output->max_video_pts,
                output->automatic_menu_stalled_pts,
                (unsigned long long)video_since_pts, available,
                watermark, PCM_SCHEDULE_RESERVE_FRAMES,
                PCM_SCHEDULE_BATCH_FRAMES);
    }
    do {
        excess = available - watermark;
        emit = excess > PCM_SCHEDULE_BATCH_FRAMES ?
               PCM_SCHEDULE_BATCH_FRAMES : excess;
        if (scheduler_emit_pcm(output, emit) < 0)
            return -1;
        output->automatic_menu_pcm_fallback_frames += emit;
        available = hold_available(output);
    } while (available > watermark);
    return 0;
}

static int scheduler_check_automatic_menu_hold(struct output_state *output)
{
    size_t available;

    if (!output->automatic_menu_epoch || !output->scheduler_started ||
        output->hold_active || !output->hold_limit)
        return 0;
    available = hold_available(output);
    if (available <= output->hold_limit)
        return 0;
    fprintf(stderr,
            "media_player_helper: automatic menu PCM hold limit exceeded "
            "held=%zu limit=%zu max_video_pts=%llu repeats=%u "
            "fallback=%d\n",
            available, output->hold_limit,
            (unsigned long long)output->max_video_pts,
            output->automatic_menu_stalled_pts,
            output->automatic_menu_pcm_fallback);
    return -1;
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
    if (output->iso_start_filter_active) {
        if (at_eof)
            fprintf(stderr,
                    "media_player_helper: stream ended before a complete "
                    "initial random-access group\n");
        return at_eof ? -1 : 0;
    }
    while (output->video_head) {
        struct video_chunk *chunk = output->video_head;
        uint64_t target;
        uint64_t due;
        uint64_t available_total;
        size_t remaining = chunk->size - chunk->offset;
        size_t slice;

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
            scheduler_accept_video_pts(output, chunk);
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
        target = scheduler_pcm_delivery_target(
            output, scheduler_video_horizon(output, slice));
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
        if (due && scheduler_emit_pcm(output, due) < 0)
            return -1;
        if (write_video_immediate(output, chunk->data + chunk->offset, slice,
                                  "scheduled video") < 0)
            return -1;
        chunk->offset += slice;
        output->video_queued_bytes -= slice;
        if (chunk->offset < chunk->size)
            continue;
        scheduler_accept_video_pts(output, chunk);
        free_video_head(output);
    }
    /*
     * The horizon belongs to the sink, not to the video queue: a scene whose
     * pictures are small delivers few video bytes per second, and pacing audio
     * against those bytes would starve the sink exactly where the source is
     * quietest.  Serve the horizon once the queue is drained as well.
     */
    if (output->scheduler_started && !output->hold_active && !output->video_head) {
        uint64_t target = scheduler_pcm_delivery_target(
            output, output->max_video_pts);
        uint64_t due = target > output->pcm_emitted_frames ?
                       target - output->pcm_emitted_frames : 0;
        uint64_t timestamp_due = due;

        if (due > PCM_SCHEDULE_BATCH_FRAMES)
            due = PCM_SCHEDULE_BATCH_FRAMES;
        if (due && scheduler_emit_pcm(output, due) < 0)
            return -1;
        if (scheduler_automatic_menu_pcm(output, timestamp_due) < 0)
            return -1;
    }
    if (scheduler_check_automatic_menu_hold(output) < 0)
        return -1;
    if (output->scheduler_started && !output->hold_active)
        scheduler_log_progress(output);
    return 0;
}

/*
 * A deferred button activation normally starts a fresh random-access epoch so
 * its staged video can cross a decoder barrier safely.  Some authored menu
 * branches instead continue the already-running elementary sequence and do
 * not repeat a complete sequence/I/reference startup group.  If that branch
 * reaches the ordinary queue guard while libdvdnav still reports menu space,
 * it can only be decoded using the resident context.  Rebase its queued PTS
 * records above the prior live epoch, release the filter, and preserve exact
 * byte order while the existing scheduler drains into the activation stage.
 */
static int rebase_unqualified_menu_activation_pts(
    struct dvd_menu_state *menu, struct output_state *output,
    int incoming_has_pts, uint64_t *incoming_pts)
{
    struct video_chunk *chunk;
    uint64_t first = UINT64_MAX;
    uint64_t delta = 0;
    uint64_t prior;
    int have_current = 0;

    if (!menu->activation_prior_pts_valid)
        return 0;
    prior = menu->activation_prior_pts;
    if (prior == UINT64_MAX) {
        fprintf(stderr,
                "media_player_helper: DVD menu continuation PTS overflow\n");
        return -1;
    }
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        if (chunk->has_pts && (!have_current || chunk->pts < first)) {
            first = chunk->pts;
            have_current = 1;
        }
    }
    if (output->h262_pending_has_pts &&
        (!have_current || output->h262_pending_pts < first)) {
        first = output->h262_pending_pts;
        have_current = 1;
    }
    if (output->have_audio_pts &&
        (!have_current || output->first_audio_pts < first)) {
        first = output->first_audio_pts;
        have_current = 1;
    }
    if (incoming_has_pts &&
        (!have_current || *incoming_pts < first)) {
        first = *incoming_pts;
        have_current = 1;
    }
    if (!have_current) {
        output->iso_pts_normalized_max = prior;
        output->iso_pts_rebase_floor = prior;
        output->iso_pts_rebase_pending = 1;
        fprintf(stderr,
                "media_player_helper: DVD menu continuation PTS rebase "
                "deferred prior=%llu\n",
                (unsigned long long)prior);
        return 0;
    }
    if (first <= prior)
        delta = prior + 1u - first;
    if (delta > UINT64_MAX - output->iso_pts_epoch_offset ||
        (output->have_audio_pts &&
         delta > UINT64_MAX - output->first_audio_pts) ||
        (output->have_video_pts &&
         delta > UINT64_MAX - output->max_video_pts) ||
        (output->h262_pending_has_pts &&
         delta > UINT64_MAX - output->h262_pending_pts) ||
        (incoming_has_pts && delta > UINT64_MAX - *incoming_pts) ||
        (output->have_iso_video_pts &&
         delta > UINT64_MAX - output->iso_pts_normalized_max)) {
        fprintf(stderr,
                "media_player_helper: DVD menu continuation PTS overflow\n");
        return -1;
    }
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        if (!chunk->has_pts)
            continue;
        if (delta > UINT64_MAX - chunk->pts ||
            (chunk->has_record && chunk->size < 9u)) {
            fprintf(stderr,
                    "media_player_helper: invalid DVD menu continuation "
                    "timestamp queue\n");
            return -1;
        }
    }
    output->iso_pts_epoch_offset += delta;
    if (output->have_audio_pts)
        output->first_audio_pts += delta;
    if (output->have_video_pts)
        output->max_video_pts += delta;
    if (output->h262_pending_has_pts)
        output->h262_pending_pts += delta;
    if (incoming_has_pts)
        *incoming_pts += delta;
    for (chunk = output->video_head; chunk; chunk = chunk->next) {
        if (!chunk->has_pts)
            continue;
        chunk->pts += delta;
        if (chunk->has_record)
            encode_video_pts(chunk->data, chunk->pts);
    }
    if (output->have_iso_video_pts)
        output->iso_pts_normalized_max += delta;
    if (output->iso_pts_normalized_max < prior)
        output->iso_pts_normalized_max = prior;
    output->iso_pts_rebase_floor = prior;
    output->iso_pts_rebase_pending = 0;
    fprintf(stderr,
            "media_player_helper: DVD menu continuation PTS rebased "
            "prior=%llu first=%llu delta=%llu\n",
            (unsigned long long)prior, (unsigned long long)first,
            (unsigned long long)delta);
    return 0;
}

static int release_unqualified_menu_activation(
    struct dvd_menu_state *menu, struct output_state *output,
    int control_fd, size_t incoming_size, int incoming_has_record,
    int incoming_has_pts, uint64_t *incoming_pts)
{
    int video_pressure;
    int pcm_pressure;
    const char *pressure;
    size_t queued;
    size_t staged;
    size_t records;

    if (!menu || !menu->activation_pending || !menu->menu_active ||
        !output_stage_active(output->activation_stage) ||
        !output->iso_start_filter_active)
        return 0;
    video_pressure = video_queue_would_overflow(
        output, incoming_size, incoming_has_record);
    pcm_pressure = output->hold_limit &&
        hold_available(output) >= output->hold_limit;
    if (!video_pressure && !pcm_pressure)
        return 0;
    pressure = pcm_pressure ? "pcm" : "video";
    queued = output->video_queued_bytes;
    if (rebase_unqualified_menu_activation_pts(
            menu, output, incoming_has_pts, incoming_pts) < 0)
        return -1;
    output->iso_start_filter_active = 0;
    if (scheduler_drain(output, 0) < 0)
        return -1;
    if (video_queue_would_overflow(output, incoming_size,
                                   incoming_has_record)) {
        if (!output->audio_pes_seen) {
            if (scheduler_release_silent_video(output) < 0)
                return -1;
        } else {
            fprintf(stderr,
                    "media_player_helper: DVD menu continuation could not "
                    "drain queued video queued=%zu incoming=%zu\n",
                    output->video_queued_bytes, incoming_size);
            return -1;
        }
    }
    staged = output_stage_size(output->activation_stage);
    records = output_stage_records(output->activation_stage);
    if (commit_activation_stage(
            output, "unqualified-random-access-menu-continuation") < 0)
        return -1;
    /*
     * Keep fallback pacing out of the finite activation stage.  Once its
     * exact prefix is live, restore the menu epoch so the existing reserve
     * drain and hold invariant pace any accumulated PCM against the sink.
     */
    if (pcm_pressure && output->hold_active) {
        output->hold_active = 0;
        output->scheduler_started = 1;
        if (hold_emit_frames(output, PCM_INITIAL_RELEASE_FRAMES) < 0)
            return -1;
    }
    output->automatic_menu_epoch = 1;
    if (acknowledge_menu_continuation(
            menu, control_fd, "unqualified-random-access") < 0)
        return -1;
    fprintf(stderr,
            "media_player_helper: DVD menu activation preserved resident "
            "decoder context pressure=%s queued=%zu remaining=%zu "
            "held=%zu hold_limit=%zu staged_records=%zu staged_bytes=%zu\n",
            pressure,
            queued, output->video_queued_bytes, hold_available(output),
            output->hold_limit, records, staged);
    return 1;
}

static int iso_finalize_terminal_random_access(struct output_state *output)
{
    /*
     * The live DVD session cannot assert the transport's input_end signal.
     * Five implementation-level drain bytes move the complete sequence-end
     * code through the in-band extractor and downstream delivery lookahead.
     */
    static const uint8_t terminal_tail[9] = {
        0x00, 0x00, 0x01, 0xb7, 0x00, 0x00, 0x00, 0x00, 0x00
    };
    int filtered = iso_filter_initial_random_access(output, 1);

    if (filtered <= 0)
        return filtered;
    if (scheduler_drain(output, 0) < 0 ||
        write_video_immediate(output, terminal_tail, sizeof(terminal_tail),
                              "DVD terminal sequence end and drain") < 0)
        return -1;
    fprintf(stderr,
            "media_player_helper: DVD authored still appended sequence end "
            "and transport drain\n");
    return 1;
}

/*
 * A DVD still is an explicit authored end boundary regardless of how its VM
 * path was entered.  Deferred button activations stage the completed picture;
 * direct root-menu hops write it after their already-completed decoder barrier.
 */
static int finalize_dvd_still_random_access(struct output_state *output)
{
    int filtered;

    if (flush_h262_video(output) < 0)
        return -1;
    if (!output->video_head)
        return 0;
    if (!output->iso_start_filter_active)
        return scheduler_drain(output, 0);
    filtered = iso_finalize_terminal_random_access(output);
    if (filtered < 0)
        return -1;
    if (!filtered)
        fprintf(stderr,
                "media_player_helper: DVD authored still did not "
                "complete a sequence/I startup group queued_video=%zu\n",
                output->video_queued_bytes);
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
    if (output->visualizer && channels == 2)
        audio_visualizer_analyze(output->visualizer, source,
                                 (size_t)samples_per_channel);
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
        if (output->audio_only_mode) {
            output->hold_active = 0;
            output->scheduler_started = 1;
            if (hold_flush(output, 0) < 0)
                return -1;
        } else if (!output->iso_start_filter_active && output->hold_active &&
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

static int write_consumer_pcm(void *opaque, const int16_t *stereo,
                              size_t frames, int rate_hz)
{
    struct output_state *output = opaque;

    if (frames > INT32_MAX)
        return -1;
    return write_pcm(output, stereo, (int)frames, 2, rate_hz);
}

/*
 * liba52 hands back one block of 256 sample_t per channel at a time, planar,
 * with the channel count implied by the flags it accepted.  Requesting
 * A52_STEREO makes it perform the 5.1 downmix itself using the coefficients
 * carried in the stream, and A52_ADJUST_LEVEL keeps that downmix from
 * clipping, so the helper never has to invent matrix coefficients of its own.
 */
/*
 * Wrap one AC-3 frame as an IEC 61937 burst occupying a whole burst period.
 * The payload is written as big-endian 16-bit words so the bytes reach the
 * S/PDIF line in their original order, and the remainder of the period is
 * zero stuffed. Nothing may scale these samples afterwards: any gain, mix or
 * filter turns the burst into noise for the receiver.
 */
static int emit_burst(struct output_state *output, const uint8_t *frame,
                      int length, unsigned data_type, int samples_per_period,
                      const char *what)
{
    mp3d_sample_t burst[IEC61937_MAX_BURST_SAMPLES * 2];
    size_t period_bytes = (size_t)samples_per_period * 2u * 2u;
    int words = length / 2;
    int i;

    if (length <= 0 || samples_per_period <= 0 ||
        samples_per_period > IEC61937_MAX_BURST_SAMPLES ||
        (size_t)length + IEC61937_HEADER_WORDS * 2u > period_bytes) {
        fprintf(stderr,
                "media_player_helper: %s frame of %d bytes does not fit a "
                "%d-sample burst period\n", what, length, samples_per_period);
        return -1;
    }
    memset(burst, 0, period_bytes);
    burst[0] = (mp3d_sample_t)(int16_t)IEC61937_PA;
    burst[1] = (mp3d_sample_t)(int16_t)IEC61937_PB;
    burst[2] = (mp3d_sample_t)(int16_t)data_type;
    burst[3] = (mp3d_sample_t)(int16_t)(unsigned)(length * 8);
    for (i = 0; i < words; ++i)
        burst[IEC61937_HEADER_WORDS + i] =
            (mp3d_sample_t)(int16_t)(uint16_t)((frame[i * 2] << 8) |
                                               frame[i * 2 + 1]);
    if (length & 1)
        burst[IEC61937_HEADER_WORDS + words] =
            (mp3d_sample_t)(int16_t)(uint16_t)(frame[length - 1] << 8);
    output->pcm_non_audio = 1;
    return write_pcm(output, burst, samples_per_period, 2,
                     (int)PCM_SAMPLE_RATE);
}

static int emit_ac3_burst(struct output_state *output,
                          const uint8_t *frame, int length)
{
    return emit_burst(output, frame, length, IEC61937_DATA_TYPE_AC3,
                      AC3_SAMPLES_PER_FRAME, "AC-3");
}

/*
 * Read a 16-bit big-endian DTS core header. FSIZE and NBLKS give the frame's
 * own length and sample count, which together choose the burst period and its
 * IEC 61937 data type. Other bit widths and endiannesses exist and are refused
 * rather than guessed at.
 */
static int dts_frame_info(const uint8_t *data, size_t available,
                          int *length, int *samples, unsigned *data_type)
{
    unsigned nblks, fsize;

    if (available < DTS_HEADER_BYTES) return 0;
    if (!(data[0] == 0x7F && data[1] == 0xFE &&
          data[2] == 0x80 && data[3] == 0x01))
        return -1;
    nblks = ((unsigned)(data[4] & 0x01u) << 6) | (unsigned)(data[5] >> 2);
    fsize = ((unsigned)(data[5] & 0x03u) << 12) |
            ((unsigned)data[6] << 4) | (unsigned)(data[7] >> 4);
    *samples = (int)(nblks + 1u) * 32;
    *length = (int)fsize + 1;
    switch (*samples) {
    case 512:  *data_type = IEC61937_DATA_TYPE_DTS1; break;
    case 1024: *data_type = IEC61937_DATA_TYPE_DTS2; break;
    case 2048: *data_type = IEC61937_DATA_TYPE_DTS3; break;
    default:
        fprintf(stderr,
                "media_player_helper: unsupported DTS frame of %d samples\n",
                *samples);
        return -1;
    }
    return 1;
}

static int decode_dts_buffer(struct audio_state *audio,
                             struct output_state *output, int at_eof)
{
    size_t original_size = audio->size;
    size_t offset = 0;

    while (original_size - offset >= DTS_HEADER_BYTES) {
        int length = 0, samples = 0, ready;
        unsigned data_type = 0;

        ready = dts_frame_info(audio->data + offset, original_size - offset,
                               &length, &samples, &data_type);
        if (ready < 0) {
            /* Not a frame header here; resynchronize a byte at a time. */
            offset++;
            continue;
        }
        if (!ready) break;
        if ((size_t)length > original_size - offset) break;
        if (emit_burst(output, audio->data + offset, length, data_type,
                       samples, "DTS") < 0)
            return -1;
        offset += (size_t)length;
    }
    if (offset) {
        memmove(audio->data, audio->data + offset, audio->size - offset);
        audio->size -= offset;
    }
    if (at_eof && audio->size >= DTS_HEADER_BYTES) {
        fprintf(stderr,
                "media_player_helper: truncated or undecodable DTS tail "
                "(%zu bytes)\n", audio->size);
        return -1;
    }
    return 0;
}

static int decode_ac3_buffer(struct audio_state *audio,
                             struct output_state *output, int at_eof)
{
    size_t original_size = audio->size;
    size_t offset = 0;

    while (original_size - offset >= AC3_SYNCINFO_BYTES) {
        uint8_t *frame = audio->data + offset;
        int flags = 0;
        int sample_rate = 0;
        int bit_rate = 0;
        int length;
        int block;
        sample_t level = 1;
        mp3d_sample_t pcm[AC3_SAMPLES_PER_FRAME * 2];

        length = a52_syncinfo(frame, &flags, &sample_rate, &bit_rate);
        if (length <= 0) {
            /* Resynchronize a byte at a time rather than discarding the run. */
            offset++;
            audio->a52_synced = 0;
            if (++audio->ac3_resync_bytes > AC3_RESYNC_LIMIT) {
                fprintf(stderr,
                        "media_player_helper: AC-3 resynchronization "
                        "exceeded %u bytes\n", AC3_RESYNC_LIMIT);
                return -1;
            }
            continue;
        }
        if ((size_t)length > original_size - offset)
            break;
        if (sample_rate != (int)PCM_SAMPLE_RATE &&
            ac3_rate_candidate(sample_rate, (int)PCM_SAMPLE_RATE,
                               audio->ac3_resync_bytes,
                               audio->ac3_resync_events) ==
                AC3_RATE_CANDIDATE_RECOVER) {
            fprintf(stderr,
                    "media_player_helper: rejecting false AC-3 sync "
                    "candidate at %d Hz during resynchronization\n",
                    sample_rate);
            goto resynchronize_candidate;
        }
        if (sample_rate != (int)PCM_SAMPLE_RATE) {
            fprintf(stderr,
                    "media_player_helper: unsupported AC-3 sample rate %d Hz "
                    "(supported: %u Hz)\n",
                    sample_rate, PCM_SAMPLE_RATE);
            return -1;
        }
        if (audio->output == AUDIO_OUT_SPDIF) {
            /* The frame is validated by syncinfo above; hand it on untouched. */
            if (emit_ac3_burst(output, frame, length) < 0)
                return -1;
            if (audio->ac3_resync_bytes) {
                fprintf(stderr,
                        "media_player_helper: AC-3 resynchronized after "
                        "%zu byte(s), %u rejected candidate(s)\n",
                        audio->ac3_resync_bytes, audio->ac3_resync_events);
            }
            audio->a52_synced = 1;
            audio->ac3_resync_bytes = 0;
            audio->ac3_resync_events = 0;
            offset += (size_t)length;
            continue;
        }
        flags = A52_STEREO | A52_ADJUST_LEVEL;
        if (a52_frame(audio->a52, frame, &flags, &level, 0)) {
            fprintf(stderr,
                    "media_player_helper: resynchronizing after "
                    "undecodable AC-3 frame\n");
            goto resynchronize_candidate;
        }
        for (block = 0; block < AC3_BLOCKS_PER_FRAME; ++block) {
            const sample_t *samples;
            int i;

            if (a52_block(audio->a52)) {
                fprintf(stderr,
                        "media_player_helper: resynchronizing after "
                        "undecodable AC-3 block %d\n", block);
                goto resynchronize_candidate;
            }
            samples = a52_samples(audio->a52);
            for (i = 0; i < AC3_SAMPLES_PER_BLOCK; ++i) {
                int channel;
                for (channel = 0; channel < 2; ++channel) {
                    sample_t value = samples[channel * AC3_SAMPLES_PER_BLOCK + i];
                    int scaled = (int)(value * 32767.0f +
                                       (value >= 0 ? 0.5f : -0.5f));
                    if (scaled > 32767)
                        scaled = 32767;
                    else if (scaled < -32768)
                        scaled = -32768;
                    pcm[(block * AC3_SAMPLES_PER_BLOCK + i) * 2 + channel] =
                        (mp3d_sample_t)scaled;
                }
            }
        }
        if (audio->ac3_resync_bytes) {
            fprintf(stderr,
                    "media_player_helper: AC-3 resynchronized after "
                    "%zu byte(s), %u rejected candidate(s)\n",
                    audio->ac3_resync_bytes, audio->ac3_resync_events);
        }
        audio->a52_synced = 1;
        audio->ac3_resync_bytes = 0;
        audio->ac3_resync_events = 0;
        offset += (size_t)length;
        if (write_pcm(output, pcm, AC3_SAMPLES_PER_FRAME, 2, sample_rate) < 0)
            return -1;
        continue;

resynchronize_candidate:
        ++audio->ac3_resync_events;
        audio->a52_synced = 0;
        offset++;
        if (++audio->ac3_resync_bytes > AC3_RESYNC_LIMIT) {
            fprintf(stderr,
                    "media_player_helper: AC-3 resynchronization exceeded "
                    "%u bytes after %u candidate frame(s)\n",
                    AC3_RESYNC_LIMIT, audio->ac3_resync_events);
            return -1;
        }
        if (audio->a52) {
            a52_free(audio->a52);
            audio->a52 = a52_init(0);
            if (!audio->a52) {
                fprintf(stderr,
                        "media_player_helper: AC-3 decoder reinit failed\n");
                return -1;
            }
        }
    }
    if (offset) {
        memmove(audio->data, audio->data + offset, audio->size - offset);
        audio->size -= offset;
    }
    if (at_eof && audio->size >= AC3_SYNCINFO_BYTES) {
        fprintf(stderr,
                "media_player_helper: truncated or undecodable AC-3 tail "
                "(%zu bytes)\n",
                audio->size);
        return -1;
    }
    return 0;
}

static int decode_mpeg_audio_buffer(struct audio_state *audio,
                                    struct output_state *output, int at_eof)
{
    size_t original_size = audio->size;
    size_t offset = 0;
    int required_layer = audio->codec == AUDIO_CODEC_MP3 ? 3 : 2;

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
        if (!samples) {
            if (at_eof && audio->codec == AUDIO_CODEC_MP3) {
                fprintf(stderr,
                        "media_player_helper: truncated or undecodable MP3 tail\n");
                return -1;
            }
            continue;
        }
        if (info.layer != required_layer) {
            fprintf(stderr,
                    "media_player_helper: MPEG audio layer %d found where layer %d is required\n",
                    info.layer, required_layer);
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

/*
 * Returns non-zero when this codec owns the session.  The first audio PES
 * decides; anything else is ignored for the rest of the file, which is the
 * same single-track rule the MPEG audio path already applied by stream id.
 */
static int claim_audio_codec(struct audio_state *audio, enum audio_codec codec)
{
    if (audio->codec == AUDIO_CODEC_NONE) {
        audio->codec = codec;
        return 1;
    }
    return audio->codec == codec;
}

static int decode_audio_buffer(struct audio_state *audio,
                               struct output_state *output, int at_eof)
{
    switch (audio->codec) {
    case AUDIO_CODEC_DTS:
        return decode_dts_buffer(audio, output, at_eof);
    case AUDIO_CODEC_AC3:
        return decode_ac3_buffer(audio, output, at_eof);
    case AUDIO_CODEC_MP2:
    case AUDIO_CODEC_MP3:
        return decode_mpeg_audio_buffer(audio, output, at_eof);
    case AUDIO_CODEC_NONE:
    default:
        return 0;
    }
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
        if ((packet[0] & 0x30) != 0) {
            fprintf(stderr,
                    "media_player_helper: encrypted or scrambled PES is unsupported\n");
            return -1;
        }
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

static int seek_command_seconds(int command, int *seconds)
{
    switch (command) {
    case MEDIA_PLAYER_CONTROL_SEEK_BACK_10:
        *seconds = -10;
        return 1;
    case MEDIA_PLAYER_CONTROL_SEEK_FORWARD_10:
        *seconds = 10;
        return 1;
    case MEDIA_PLAYER_CONTROL_SEEK_BACK_60:
        *seconds = -60;
        return 1;
    case MEDIA_PLAYER_CONTROL_SEEK_FORWARD_60:
        *seconds = 60;
        return 1;
    case MEDIA_PLAYER_CONTROL_SEEK_BACK_300:
        *seconds = -300;
        return 1;
    case MEDIA_PLAYER_CONTROL_SEEK_FORWARD_300:
        *seconds = 300;
        return 1;
    default:
        return 0;
    }
}

static int skip_program_stream_pack(struct media_source *input)
{
    uint8_t header[10];

    if (read_exact(input, header, 1) < 0)
        return -1;
    if ((header[0] & 0xc0) == 0x40)
        return read_exact(input, header + 1, 9) < 0 ||
               skip_bytes(input, header[9] & 7) < 0 ? -1 : 0;
    if ((header[0] & 0xf0) == 0x20)
        return read_exact(input, header + 1, 7);
    fprintf(stderr, "media_player_helper: invalid pack header\n");
    return -1;
}

/*
 * Extend the sparse index without emitting anything. The scan uses complete
 * Program Stream packet lengths, so start-code-looking bytes inside compressed
 * payloads cannot become false index entries. It leaves the source positioned
 * at the selected entry, ready for the ordinary demux path to restart.
 */
static int scan_program_stream_seek(
    struct media_source *input, struct program_stream_seek_index *index,
    int *video_code, uint64_t target_pts,
    struct program_stream_seek_entry *selected)
{
    for (;;) {
        uint8_t code;
        int64_t after_code;
        int found = find_start_code(input, &code);

        if (found < 0)
            return -1;
        if (!found || code == 0xb9)
            break;
        if (media_source_position(input, &after_code) < 0)
            return -1;
        if (code == 0xba) {
            if (skip_program_stream_pack(input) < 0)
                return -1;
            continue;
        }
        if ((code & 0xf0) == 0xe0) {
            uint8_t length_bytes[2];
            uint8_t *packet;
            size_t length;
            size_t payload_offset;
            uint64_t pts = 0;
            int has_pts = 0;
            int record_result = 0;

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
                free(packet);
                return -1;
            }
            if (*video_code < 0)
                *video_code = code;
            if (*video_code == code &&
                parse_pes_header(packet, length, &payload_offset, &pts,
                                 &has_pts) == 0 && has_pts)
                record_result = program_stream_seek_record(
                    index, pts, after_code - 4);
            free(packet);
            if (record_result < 0)
                return -1;
            if (*video_code == code && has_pts && pts >= target_pts)
                break;
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
    if (!program_stream_seek_find(index, target_pts, selected)) {
        fprintf(stderr,
                "media_player_helper: no timestamped video packet available for seek\n");
        return -1;
    }
    if (media_source_seek(input, selected->source_offset,
                          MEDIA_SOURCE_SEEK_START) < 0) {
        fprintf(stderr, "media_player_helper: cannot reposition Program Stream\n");
        return -1;
    }
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

static int preflight_mp3(struct media_source *input)
{
    uint8_t buffer[MP3_PROBE_BYTES];
    uint8_t prefix[10];
    size_t prefix_size = 0;
    size_t count;
    size_t read_count;
    size_t offset = 0;
    mp3dec_t decoder;

    if (read_mp3_prefix(input, prefix, &prefix_size) < 0)
        return -1;
    memcpy(buffer, prefix, prefix_size);
    read_count = media_source_read(
        input, buffer + prefix_size, sizeof(buffer) - prefix_size);
    count = prefix_size + read_count;
    if (media_source_error(input))
        return -1;
    /*
     * If this bounded read reached EOF, remove terminal ID3v1 before asking
     * minimp3 to validate its following-frame chain. Otherwise a short file
     * with exactly ten MPEG frames can make the tag look like a failed
     * eleventh sync candidate even though every audio frame is complete.
     */
    if (read_count < sizeof(buffer) - prefix_size && count >= 128u &&
        !memcmp(buffer + count - 128u, "TAG", 3))
        count -= 128u;
    mp3dec_init(&decoder);
    while (offset < count) {
        mp3dec_frame_info_t info;
        mp3d_sample_t pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];
        int samples = mp3dec_decode_frame(
            &decoder, buffer + offset, (int)(count - offset), pcm, &info);

        if (!info.frame_bytes)
            break;
        offset += (size_t)info.frame_bytes;
        if (!samples)
            continue;
        if (info.layer != 3) {
            fprintf(stderr,
                    "media_player_helper: raw .mp3 source contains MPEG audio layer %d\n",
                    info.layer);
            return -1;
        }
        if ((info.hz != 44100 && info.hz != 48000) ||
            (info.channels != 1 && info.channels != 2)) {
            fprintf(stderr,
                    "media_player_helper: unsupported MP3 format: %d Hz, %d channels "
                    "(supported: 44100 or 48000 Hz, 1 or 2 channels)\n",
                    info.hz, info.channels);
            return -1;
        }
        if (media_source_rewind(input) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot rewind MP3 input after preflight\n");
            return -1;
        }
        return 0;
    }
    fprintf(stderr, "media_player_helper: no MPEG-1 Layer III frame found\n");
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
                       struct output_state *output,
                       struct dvd_menu_state *menu, int control_fd,
                       int *video_code, int *audio_code,
                       struct program_stream_seek_index *seek_index,
                       int64_t pes_offset)
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
        int has_record;
        size_t video_size;

        if (has_pts && normalize_video_pts(output, pts, &pts) < 0)
            goto done;
        if (has_pts && seek_index &&
            program_stream_seek_record(seek_index, pts, pes_offset) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot extend Program Stream seek index\n");
            goto done;
        }
        has_record = has_pts && pts_record_wanted(output);
        video_size = length - payload_offset;

        if (release_unqualified_menu_activation(
                menu, output, control_fd, video_size, has_record,
                has_pts, &pts) < 0)
            goto done;
        if (output->scheduler_enabled && !output->iso_start_filter_active &&
            !output->audio_pes_seen &&
            video_queue_would_overflow(output, video_size, has_record) &&
            scheduler_release_silent_video(output) < 0)
            goto done;

        if (output->scheduler_enabled) {
            if (queue_h262_video(output, packet + payload_offset,
                                 video_size, has_pts, has_record, pts) < 0)
                goto done;
            if (output->iso_start_filter_active &&
                iso_filter_initial_random_access(output, 0) < 0)
                goto done;
            if (scheduler_drain(output, 0) < 0)
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
        if (!claim_audio_codec(audio, AUDIO_CODEC_MP2)) {
            result = 0;
            goto done;
        }
        if (has_pts && normalize_audio_pts(output, pts, &pts) < 0)
            goto done;
        if (output->silent_video_mode &&
            reject_late_audio(output, "MPEG Layer II", has_pts, pts) < 0)
            goto done;
        output->audio_pes_seen = 1;
        if (has_pts && !output->have_audio_pts) {
            output->first_audio_pts = pts;
            output->have_audio_pts = 1;
        }
        if (append_audio(audio, output, packet + payload_offset,
                         length - payload_offset) < 0 ||
            release_unqualified_menu_activation(
                menu, output, control_fd, 0, 0, 0, NULL) < 0 ||
            (output->scheduler_enabled && scheduler_drain(output, 0) < 0))
            goto done;
    }
    result = 0;
done:
    free(packet);
    return result;
}

static int process_private_pes(struct media_source *input,
                               struct audio_state *audio,
                               struct output_state *output,
                               struct dvd_menu_state *menu,
                               int control_fd)
{
    uint8_t length_bytes[2];
    uint8_t *packet;
    size_t length;
    size_t payload_offset;
    uint64_t pts;
    int has_pts;
    int result = -1;

    if (read_exact(input, length_bytes, sizeof(length_bytes)) < 0)
        return -1;
    length = ((size_t)length_bytes[0] << 8) | length_bytes[1];
    if (!length) {
        fprintf(stderr,
                "media_player_helper: unbounded private PES packet is not "
                "supported\n");
        return -1;
    }
    packet = malloc(length);
    if (!packet) {
        fprintf(stderr, "media_player_helper: out of memory\n");
        return -1;
    }
    if (read_exact(input, packet, length) < 0) {
        fprintf(stderr, "media_player_helper: truncated private PES packet\n");
        goto done;
    }
    if (parse_pes_header(packet, length, &payload_offset, &pts, &has_pts) < 0) {
        fprintf(stderr, "media_player_helper: invalid private PES header\n");
        goto done;
    }
    if (menu && menu->enabled && payload_offset < length &&
        packet[payload_offset] >= 0x20u && packet[payload_offset] <= 0x3fu) {
        int physical = packet[payload_offset] - 0x20u;
        int update;

        if (menu->spu_stream < 0) {
            menu->spu_stream = physical;
            dvd_spu_set_stream(menu->decoder, physical);
        }
        update = dvd_spu_feed(menu->decoder, physical,
                              packet + payload_offset + 1u,
                              length - payload_offset - 1u);
        if (update < 0) {
            fprintf(stderr,
                    "media_player_helper: malformed DVD subpicture packet\n");
            goto done;
        }
        if (update > 0) {
            if (dvd_spu_set_highlight(menu->decoder,
                                      menu->highlight_display,
                                      menu->highlight_palette,
                                      menu->highlight_x1,
                                      menu->highlight_y1,
                                      menu->highlight_x2,
                                      menu->highlight_y2) < 0 ||
                emit_overlay_frame(output,
                                   dvd_spu_overlay(menu->decoder)) < 0)
                goto done;
            menu->overlay_emitted = 1;
            fprintf(stderr,
                    "media_player_helper: DVD subpicture overlay updated\n");
        }
        result = 0;
        goto done;
    }
    if (payload_offset + AC3_PRIVATE_HEADER <= length &&
        packet[payload_offset] >= AC3_SUBSTREAM_FIRST &&
        packet[payload_offset] <= AC3_SUBSTREAM_LAST) {
        int substream = packet[payload_offset];
        const uint8_t *payload = packet + payload_offset + AC3_PRIVATE_HEADER;
        size_t size = length - payload_offset - AC3_PRIVATE_HEADER;
        size_t first_frame;

        if (!claim_audio_codec(audio, AUDIO_CODEC_AC3)) {
            result = 0;
            goto done;
        }
        if (!audio->a52 && audio->output != AUDIO_OUT_SPDIF) {
            /* No accelerated IMDCT is compiled in; ask for the portable path. */
            audio->a52 = a52_init(0);
            if (!audio->a52) {
                fprintf(stderr,
                        "media_player_helper: AC-3 decoder init failed\n");
                goto done;
            }
        }
        if (audio->a52_substream < 0) {
            audio->a52_substream = substream;
            fprintf(stderr,
                    "media_player_helper: AC-3 audio on private substream "
                    "0x%02x\n",
                    substream);
        }
        if (audio->a52_substream != substream) {
            /* A further AC-3 track; protocol one plays the first one only. */
            result = 0;
            goto done;
        }
        if (has_pts && normalize_audio_pts(output, pts, &pts) < 0)
            goto done;
        if (output->silent_video_mode &&
            reject_late_audio(output, "AC-3", has_pts, pts) < 0)
            goto done;
        /*
         * The two-byte pointer locates this packet's first frame header, one
         * based, so it only matters before the decoder has synchronized; once
         * synchronized the payload is simply contiguous.
         */
        first_frame = ((size_t)packet[payload_offset + 2] << 8) |
                      packet[payload_offset + 3];
        if (!audio->a52_synced && first_frame) {
            size_t skip = first_frame - 1;
            if (skip >= size) {
                result = 0;
                goto done;
            }
            payload += skip;
            size -= skip;
        } else if (!audio->a52_synced) {
            /* No frame starts here and none has been decoded yet. */
            result = 0;
            goto done;
        }
        output->audio_pes_seen = 1;
        if (has_pts && !output->have_audio_pts) {
            output->first_audio_pts = pts;
            output->have_audio_pts = 1;
        }
        if (append_audio(audio, output, payload, size) < 0 ||
            release_unqualified_menu_activation(
                menu, output, control_fd, 0, 0, 0, NULL) < 0 ||
            (output->scheduler_enabled && scheduler_drain(output, 0) < 0))
            goto done;
        result = 0;
        goto done;
    }
    if (payload_offset + AC3_PRIVATE_HEADER <= length &&
        packet[payload_offset] >= DTS_SUBSTREAM_FIRST &&
        packet[payload_offset] <= DTS_SUBSTREAM_LAST) {
        int substream = packet[payload_offset];
        const uint8_t *payload = packet + payload_offset + AC3_PRIVATE_HEADER;
        size_t size = length - payload_offset - AC3_PRIVATE_HEADER;
        size_t first_frame;

        if (audio->output != AUDIO_OUT_SPDIF) {
            fprintf(stderr,
                    "media_player_helper: DTS requires --audio-out spdif; "
                    "there is no DTS decoder for HDMI output\n");
            goto done;
        }
        if (!claim_audio_codec(audio, AUDIO_CODEC_DTS)) {
            result = 0;
            goto done;
        }
        if (audio->dts_substream < 0) {
            audio->dts_substream = substream;
            fprintf(stderr,
                    "media_player_helper: DTS audio on private substream "
                    "0x%02x\n", substream);
        }
        if (audio->dts_substream != substream) {
            result = 0;
            goto done;
        }
        if (has_pts && normalize_audio_pts(output, pts, &pts) < 0)
            goto done;
        if (output->silent_video_mode &&
            reject_late_audio(output, "DTS", has_pts, pts) < 0)
            goto done;
        first_frame = ((size_t)packet[payload_offset + 2] << 8) |
                      packet[payload_offset + 3];
        if (!audio->a52_synced && first_frame) {
            size_t skip = first_frame - 1;
            if (skip >= size) {
                result = 0;
                goto done;
            }
            payload += skip;
            size -= skip;
            audio->a52_synced = 1;
        } else if (!audio->a52_synced) {
            result = 0;
            goto done;
        }
        output->audio_pes_seen = 1;
        if (has_pts && !output->have_audio_pts) {
            output->first_audio_pts = pts;
            output->have_audio_pts = 1;
        }
        if (append_audio(audio, output, payload, size) < 0 ||
            release_unqualified_menu_activation(
                menu, output, control_fd, 0, 0, 0, NULL) < 0 ||
            (output->scheduler_enabled && scheduler_drain(output, 0) < 0))
            goto done;
        result = 0;
        goto done;
    }
    if (payload_offset < length && packet[payload_offset] >= 0x90u &&
        packet[payload_offset] <= 0xafu) {
        unsigned substream = packet[payload_offset];
        uint32_t bit = UINT32_C(1) << (substream - 0x90u);

        if (!(audio->unsupported_private_audio_mask & bit)) {
            const char *kind = substream >= 0xa0u && substream <= 0xa7u ?
                               "DVD LPCM" : "private audio";

            fprintf(stderr,
                    "media_player_helper: skipping unsupported %s "
                    "substream 0x%02x; video and navigation continue "
                    "without this audio\n",
                    kind, substream);
            audio->unsupported_private_audio_mask |= bit;
        }
        result = 0;
        goto done;
    }
    result = 0;
done:
    free(packet);
    return result;
}

/*
 * A menu still leaves the last decoded video frame resident in the FPGA while
 * the DVD virtual machine waits.  Poll the private control socket here rather
 * than skipping the still immediately: directional changes remain interactive,
 * title/root hops retain the normal decoder barrier, finite stills expire at
 * their authored duration, and 0xff waits indefinitely for a command.  An
 * overlay-only menu continuation is acknowledged without resetting the
 * resident video frame.  Return 0 when no still is active, 1 when processing
 * should resume, 2 when the caller must enter a navigation barrier, and -1 on
 * failure.
 */
static int wait_dvd_still(struct media_source *input,
                          struct dvd_menu_state *menu,
                          struct audio_state *audio,
                          struct output_state *output,
                          int control_fd, int *control_command)
{
    struct timespec delay = {0, 10 * 1000 * 1000};
    enum output_stage_still_action stage_action;
    unsigned seconds = 0;
    uint64_t deadline = 0;

    if (!media_source_dvd_still(input, &seconds))
        return 0;
    if (seconds != 0xffu)
        deadline = monotonic_us() + (uint64_t)seconds * 1000000u;
    fprintf(stderr, "media_player_helper: DVD still wait %s%u seconds\n",
            seconds == 0xffu ? "indefinite/" : "", seconds);
    if (finalize_dvd_still_random_access(output) < 0)
        return -1;
    if (menu->activation_pending && menu->activation_payloads)
        fprintf(stderr,
                "media_player_helper: DVD menu activation pending reached "
                "still payloads=%u pictures=%u records=%zu duration=%s%u\n",
                menu->activation_payloads, output->picture_marks,
                output_stage_records(output->activation_stage),
                seconds == 0xffu ? "indefinite/" : "", seconds);

    stage_action = output_stage_classify_still(
        output->activation_stage, output->picture_marks, seconds);
    if (stage_action == OUTPUT_STAGE_STILL_HOP) {
        menu->activation_staged_hop = 1;
        *control_command = MEDIA_PLAYER_CONTROL_MENU_ACTIVATE;
        fprintf(stderr,
                "media_player_helper: DVD payload-bearing indefinite menu "
                "requires staged stream hop pictures=%u records=%zu bytes=%zu\n",
                output->picture_marks,
                output_stage_records(output->activation_stage),
                output_stage_size(output->activation_stage));
        return 2;
    }
    if (stage_action == OUTPUT_STAGE_STILL_CONTINUE) {
        if (commit_activation_stage(output,
                                    "overlay-indefinite-menu-continuation") < 0)
            return -1;
        if (acknowledge_menu_continuation(
                menu, control_fd, "overlay-indefinite-still") < 0)
            return -1;
        return 1;
    }
    if (stage_action == OUTPUT_STAGE_STILL_CANCEL) {
        if (cancel_activation_stage(output, "empty-indefinite-still") < 0)
            return -1;
        if (acknowledge_menu_continuation(menu, control_fd,
                                          "indefinite-still") < 0)
            return -1;
        return 1;
    }
    if (stage_action == OUTPUT_STAGE_STILL_COMMIT &&
        commit_activation_stage(output, "finite-still") < 0)
        return -1;

    for (;;) {
        int command = control_read_command(control_fd);
        enum media_source_dvd_command menu_command;

        if (command < 0)
            return -1;
        if (command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ||
            command == MEDIA_PLAYER_CONTROL_NEXT_CHAPTER) {
            if (cancel_pending_menu_activation(menu, output,
                                               "chapter-interrupt") < 0)
                return -1;
            *control_command = command;
            return 2;
        }
        menu_command = dvd_source_command(command);
        if (menu_command) {
            int navigation = media_source_dvd_command(input, menu_command);

            if (navigation < 0)
                return -1;
            if (refresh_dvd_menu_state(input, menu, output, control_fd) < 0)
                return -1;
            if (navigation == MEDIA_SOURCE_DVD_MENU_CONTINUE) {
                if (output_stage_active(output->activation_stage) &&
                    cancel_activation_stage(output,
                                            "command-continuation") < 0)
                    return -1;
                if (acknowledge_menu_continuation(menu, control_fd,
                                                  "command") < 0)
                    return -1;
                return 1;
            }
            if (navigation == MEDIA_SOURCE_DVD_MENU_PENDING) {
                if (start_pending_menu_activation(menu, audio, output) < 0)
                    return -1;
                return 1;
            }
            if (navigation == MEDIA_SOURCE_DVD_STREAM_HOP) {
                if (cancel_pending_menu_activation(menu, output,
                                                   "menu-command-hop") < 0)
                    return -1;
                *control_command = command;
                return 2;
            }
        }
        else if (command) {
            fprintf(stderr,
                    "media_player_helper: ignoring unexpected still "
                    "control 0x%02x\n", command);
        }

        if (seconds != 0xffu && monotonic_us() >= deadline) {
            int navigation = media_source_dvd_still_skip(
                input, menu->activation_pending);

            if (navigation < 0)
                return -1;
            fprintf(stderr, "media_player_helper: DVD finite still complete\n");
            if (refresh_dvd_menu_state(input, menu, output, control_fd) < 0)
                return -1;
            if (menu->activation_pending) {
                if (navigation == MEDIA_SOURCE_DVD_STREAM_HOP) {
                    menu->activation_pending = 0;
                    menu->activation_payloads = 0;
                    menu->activation_prior_pts_valid = 0;
                    menu->activation_prior_pts = 0;
                    *control_command = MEDIA_PLAYER_CONTROL_MENU_ACTIVATE;
                    fprintf(stderr,
                            "media_player_helper: DVD delayed activation "
                            "stream hop\n");
                    return 2;
                }
                if (navigation == MEDIA_SOURCE_DVD_MENU_PENDING) {
                    fprintf(stderr,
                            "media_player_helper: DVD delayed activation "
                            "remains pending after finite still\n");
                    return 1;
                }
                if (acknowledge_menu_continuation(
                        menu, control_fd, "finite-still-menu") < 0)
                    return -1;
            }
            *control_command = MEDIA_PLAYER_CONTROL_STREAM_BOUNDARY;
            fprintf(stderr,
                    "media_player_helper: DVD finite still requests "
                    "decoder stream boundary\n");
            return 2;
        }
        while (nanosleep(&delay, &delay) < 0 && errno == EINTR)
            ;
        delay.tv_sec = 0;
        delay.tv_nsec = 10 * 1000 * 1000;
    }
}

static int activation_stage_motion_hop(struct dvd_menu_state *menu,
                                       struct output_state *output,
                                       int *control_command)
{
    size_t bytes;

    if (!menu->activation_pending || !menu->menu_active ||
        !output_stage_active(output->activation_stage) ||
        output->iso_start_filter_active || !output->picture_marks)
        return 0;
    bytes = output_stage_size(output->activation_stage);
    if (bytes < OUTPUT_ACTIVATION_STAGE_DECISION_BYTES)
        return 0;
    menu->activation_staged_hop = 1;
    *control_command = MEDIA_PLAYER_CONTROL_MENU_ACTIVATE;
    fprintf(stderr,
            "media_player_helper: DVD picture-bearing motion menu "
            "requires staged stream hop pictures=%u records=%zu bytes=%zu "
            "decision=%u capacity=%u\n",
            output->picture_marks,
            output_stage_records(output->activation_stage), bytes,
            OUTPUT_ACTIVATION_STAGE_DECISION_BYTES,
            OUTPUT_ACTIVATION_STAGE_BYTES);
    return 1;
}

static int process_program_stream(struct media_source *input,
                                  struct audio_state *audio,
                                  struct output_state *output,
                                  struct dvd_menu_state *menu,
                                  int control_fd, int *control_command,
                                  struct program_stream_seek_index *seek_index,
                                  int *video_code, int *audio_code)
{
    for (;;) {
        uint8_t code;
        int64_t pes_offset = -1;
        int command = control_read_command(control_fd);
        int seek_seconds;
        enum media_source_dvd_command menu_command;

        if (command < 0)
            return -1;
        {
            int menu_refresh = refresh_dvd_menu_state(
                input, menu, output, control_fd);

            if (menu_refresh < 0)
                return -1;
            if (menu_refresh > 0 && output->silent_video_mode &&
                rearm_for_automatic_menu(audio, output) < 0)
                return -1;
        }
        if (command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ||
            command == MEDIA_PLAYER_CONTROL_NEXT_CHAPTER) {
            if (cancel_pending_menu_activation(menu, output,
                                               "chapter-interrupt") < 0)
                return -1;
            *control_command = command;
            return 1;
        }
        if (seek_command_seconds(command, &seek_seconds) &&
            input->kind == MEDIA_SOURCE_FILE && seek_index) {
            *control_command = command;
            return 1;
        }
        menu_command = dvd_source_command(command);
        if (menu_command) {
            int navigation = media_source_dvd_command(input, menu_command);

            if (navigation < 0) {
                fprintf(stderr,
                        "media_player_helper: DVD menu control 0x%02x failed\n",
                        command);
                return -1;
            }
            if (refresh_dvd_menu_state(input, menu, output, control_fd) < 0)
                return -1;
            if (navigation == MEDIA_SOURCE_DVD_MENU_CONTINUE) {
                if (output_stage_active(output->activation_stage) &&
                    cancel_activation_stage(output,
                                            "command-continuation") < 0)
                    return -1;
                if (acknowledge_menu_continuation(menu, control_fd,
                                                  "command") < 0)
                    return -1;
                continue;
            }
            if (navigation == MEDIA_SOURCE_DVD_MENU_PENDING) {
                if (start_pending_menu_activation(menu, audio, output) < 0)
                    return -1;
                continue;
            }
            if (navigation == MEDIA_SOURCE_DVD_STREAM_HOP) {
                if (cancel_pending_menu_activation(menu, output,
                                                   "menu-command-hop") < 0)
                    return -1;
                *control_command = command;
                return 1;
            }
            continue;
        }
        if (command)
            fprintf(stderr,
                    "media_player_helper: ignoring unexpected control "
                    "0x%02x during playback\n", command);
        if (activation_stage_motion_hop(menu, output, control_command))
            return 1;
        int found;

        if (menu->resume_code_valid) {
            code = menu->resume_code;
            menu->resume_code_valid = 0;
            found = 1;
        } else {
            found = find_start_code(input, &code);
        }
        if (found == 0) {
            int still = wait_dvd_still(input, menu, audio, output, control_fd,
                                       control_command);

            if (still < 0)
                return -1;
            if (still == 1)
                continue;
            if (still == 2)
                return 1;
            return 0;
        }
        if (found < 0)
            return -1;
        {
            int menu_refresh = refresh_dvd_menu_state(
                input, menu, output, control_fd);

            if (menu_refresh < 0)
                return -1;
            if (menu_refresh > 0 && output->silent_video_mode &&
                rearm_for_automatic_menu(audio, output) < 0)
                return -1;
        }
        if (seek_index && media_source_position(input, &pes_offset) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot read Program Stream position\n");
            return -1;
        }
        if (pes_offset >= 0)
            pes_offset -= 4;
        if (menu->activation_pending) {
            if (refresh_dvd_menu_state(input, menu, output, control_fd) < 0)
                return -1;
            if (!menu->menu_active) {
                if (output_stage_active(output->activation_stage) &&
                    cancel_activation_stage(output, "menu-leave") < 0)
                    return -1;
                menu->activation_pending = 0;
                menu->activation_payloads = 0;
                menu->activation_staged_hop = 0;
                menu->activation_prior_pts_valid = 0;
                menu->activation_prior_pts = 0;
                menu->resume_code = code;
                menu->resume_code_valid = 1;
                *control_command = MEDIA_PLAYER_CONTROL_MENU_ACTIVATE;
                fprintf(stderr,
                        "media_player_helper: DVD delayed activation "
                        "stream hop before payload\n");
                return 1;
            }
            ++menu->activation_payloads;
            if (menu->activation_payloads == 1)
                fprintf(stderr,
                        "media_player_helper: DVD menu activation pending "
                        "through payload code=0x%02x\n", code);
        }
        if (code == 0xb9) {
            if (menu && menu->enabled)
                continue;
            return 0;
        }
        if (code == 0xba) {
            if (skip_program_stream_pack(input) < 0)
                return -1;
            continue;
        }
        if ((code & 0xf0) == 0xe0 || (code & 0xe0) == 0xc0) {
            if (process_pes(input, code, audio, output,
                            menu, control_fd,
                            video_code, audio_code, seek_index,
                            pes_offset) < 0)
                return -1;
            continue;
        }
        if (code == 0xbd) {
            if (process_private_pes(input, audio, output, menu,
                                    control_fd) < 0)
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

struct audio_file_control_state {
    struct output_state *output;
    int control_fd;
    int seek_pending;
    int seek_seconds;
    uint64_t length_frames;
};

static int audio_file_configure_timeline(void *opaque,
                                         uint64_t length_frames,
                                         unsigned rate_hz)
{
    struct audio_file_control_state *state = opaque;

    state->length_frames = length_frames;
    state->output->audio_position_base = 0;
    state->output->audio_emitted_base =
        state->output->pcm_emitted_frames;
    if (!state->output->audio_ui)
        return 0;
    if (audio_ui_set_track_length(state->output->audio_ui,
                                  length_frames, rate_hz) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot configure audio UI duration "
                "frames=%llu rate=%u\n",
                (unsigned long long)length_frames, rate_hz);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: audio UI duration frames=%llu rate=%u\n",
            (unsigned long long)length_frames, rate_hz);
    if (state->output->visualizer) {
        if (audio_overlay_publish_full(state->output, 0) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot publish initial audio overlay\n");
            return -1;
        }
        state->output->audio_overlay.next_update = rate_hz;
    }
    return 0;
}

static int audio_file_request_seek(void *opaque, uint64_t current_frame,
                                   uint64_t length_frames, unsigned rate_hz,
                                   int *seconds)
{
    struct audio_file_control_state *state = opaque;
    uint64_t target_frame;
    int command;

    if (state->control_fd < 0)
        return 0;
    command = control_read_command(state->control_fd);
    if (command < 0)
        return -1;
    if (command == MEDIA_PLAYER_CONTROL_USER_ACTIVITY) {
        audio_visualizer_activity(state->output->visualizer,
                                  state->output->pcm_emitted_frames);
        return 0;
    }
    if (command == MEDIA_PLAYER_CONTROL_PAUSE)
        return audio_pause_barrier(state->output, state->control_fd, rate_hz,
                                   "audio file");
    if (!seek_command_seconds(command, seconds)) {
        if (command)
            fprintf(stderr,
                    "media_player_helper: ignoring unexpected audio-file "
                    "control 0x%02x\n", command);
        return 0;
    }
    target_frame = audio_file_seek_target(current_frame, length_frames,
                                          rate_hz, *seconds);
    audio_visualizer_activity(state->output->visualizer,
                              state->output->pcm_emitted_frames);
    if (target_frame == current_frame) {
        fprintf(stderr,
                "media_player_helper: ignoring audio seek %+d seconds "
                "at boundary current=%llu length=%llu rate=%u\n",
                *seconds, (unsigned long long)current_frame,
                (unsigned long long)length_frames, rate_hz);
        if (control_send(state->control_fd,
                         MEDIA_PLAYER_CONTROL_SEEK_CONTINUE) < 0)
            return -1;
        return 0;
    }
    state->seek_pending = 1;
    state->seek_seconds = *seconds;
    state->length_frames = length_frames;
    return 1;
}

static int audio_file_complete_seek(void *opaque, uint64_t current_frame,
                                    uint64_t target_frame, unsigned rate_hz)
{
    struct audio_file_control_state *state = opaque;

    if (flush_output(state->output, "audio seek barrier") < 0)
        return -1;
    if (state->output->audio_ui &&
        audio_ui_seek(state->output->audio_ui,
                      state->output->pcm_emitted_frames,
                      rate_hz, target_frame) < 0) {
        fprintf(stderr, "media_player_helper: cannot reset audio UI for seek\n");
        return -1;
    }
    audio_visualizer_seek(state->output->visualizer,
                          state->output->pcm_emitted_frames);
    state->output->audio_position_base = target_frame;
    state->output->audio_emitted_base =
        state->output->pcm_emitted_frames;
    if (control_send(state->control_fd, MEDIA_PLAYER_CONTROL_READY) < 0 ||
        control_wait_for_go(state->control_fd) < 0) {
        fprintf(stderr, "media_player_helper: audio seek barrier failed\n");
        return -1;
    }
    if (state->output->visualizer &&
        audio_overlay_publish_full(state->output, target_frame) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot republish audio overlay after seek\n");
        return -1;
    }
    state->output->audio_overlay.next_update =
        state->output->pcm_emitted_frames + rate_hz;
    fprintf(stderr,
            "media_player_helper: audio seek %+d seconds "
            "current=%llu target=%llu length=%llu rate=%u\n",
            state->seek_seconds,
            (unsigned long long)current_frame,
            (unsigned long long)target_frame,
            (unsigned long long)state->length_frames, rate_hz);
    state->seek_pending = 0;
    return 0;
}

static int process_mp3_stream(struct media_source *input,
                              struct output_state *output,
                              const struct consumer_audio_control *control)
{
    struct consumer_audio_info info = {0};
    char error[160];

    output->audio_only_mode = 1;
    output->hold_active = 0;
    output->scheduler_started = 1;
    if (consumer_audio_decode_mp3(input, write_consumer_pcm, output, control,
                                  &info, error, sizeof(error)) < 0) {
        fprintf(stderr, "media_player_helper: %s\n", error);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: MP3 %u channel(s) at %u Hz, output %u Hz\n",
            info.source_channels, info.source_rate_hz, info.output_rate_hz);
    return 0;
}

static int process_wav_stream(struct media_source *input,
                              struct output_state *output,
                              const struct consumer_audio_control *control)
{
    struct consumer_audio_info info = {0};
    char error[160];

    output->audio_only_mode = 1;
    output->hold_active = 0;
    output->scheduler_started = 1;
    if (consumer_audio_decode_wav(input, write_consumer_pcm, output, control,
                                  &info, error, sizeof(error)) < 0) {
        fprintf(stderr, "media_player_helper: %s\n", error);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: WAV %u channel(s) at %u Hz, output %u Hz\n",
            info.source_channels, info.source_rate_hz, info.output_rate_hz);
    return 0;
}

static int process_flac_stream(struct media_source *input,
                               struct output_state *output,
                               const struct consumer_audio_control *control)
{
    struct consumer_audio_info info = {0};
    char error[160];

    output->audio_only_mode = 1;
    output->hold_active = 0;
    output->scheduler_started = 1;
    if (consumer_audio_decode_flac(input, write_consumer_pcm, output, control,
                                   &info, error, sizeof(error)) < 0) {
        fprintf(stderr, "media_player_helper: %s\n", error);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: FLAC %u channel(s) at %u Hz, output %u Hz\n",
            info.source_channels, info.source_rate_hz, info.output_rate_hz);
    return 0;
}

static int process_ogg_stream(struct media_source *input,
                              struct output_state *output,
                              const struct consumer_audio_control *control)
{
    struct consumer_audio_info info = {0};
    char error[160];

    output->audio_only_mode = 1;
    output->hold_active = 0;
    output->scheduler_started = 1;
    if (consumer_audio_decode_ogg(input, write_consumer_pcm, output, control,
                                  &info, error, sizeof(error)) < 0) {
        fprintf(stderr, "media_player_helper: %s\n", error);
        return -1;
    }
    fprintf(stderr,
            "media_player_helper: Ogg Vorbis %u channel(s) at %u Hz, "
            "output %u Hz\n",
            info.source_channels, info.source_rate_hz, info.output_rate_hz);
    return 0;
}

static int cdda_update_ui_track(const struct cdda_reader *reader,
                                struct output_state *output)
{
    uint64_t track_start;
    uint64_t track_length;

    if (!output->audio_ui)
        return 0;
    if (cdda_reader_current_track_timing(reader, &track_start,
                                         &track_length) < 0 ||
        audio_ui_set_current_track(output->audio_ui,
                                   cdda_reader_current_track(reader),
                                   track_start, track_length) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot update Audio CD UI track "
                "timing\n");
        return -1;
    }
    return 0;
}

static int cdda_complete_reposition(struct cdda_reader *reader,
                                    struct audio_file_control_state *state,
                                    uint64_t current_frame,
                                    uint64_t target_frame,
                                    const char *action)
{
    if (flush_output(state->output, "Audio CD seek barrier") < 0)
        return -1;
    if (cdda_reader_seek_frame(reader, target_frame) < 0) {
        fprintf(stderr, "media_player_helper: cannot seek Audio CD: %s\n",
                strerror(errno));
        return -1;
    }
    if (cdda_update_ui_track(reader, state->output) < 0)
        return -1;
    if (state->output->audio_ui &&
        audio_ui_seek(state->output->audio_ui,
                      state->output->pcm_emitted_frames,
                      CDDA_SAMPLE_RATE_HZ, target_frame) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot reset Audio CD UI for seek\n");
        return -1;
    }
    audio_visualizer_seek(state->output->visualizer,
                          state->output->pcm_emitted_frames);
    state->output->audio_position_base = target_frame;
    state->output->audio_emitted_base =
        state->output->pcm_emitted_frames;
    if (control_send(state->control_fd, MEDIA_PLAYER_CONTROL_READY) < 0 ||
        control_wait_for_go(state->control_fd) < 0) {
        fprintf(stderr,
                "media_player_helper: Audio CD seek barrier failed\n");
        return -1;
    }
    if (state->output->visualizer &&
        audio_overlay_publish_full(state->output, target_frame) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot republish Audio CD overlay\n");
        return -1;
    }
    state->output->audio_overlay.next_update =
        state->output->pcm_emitted_frames + CDDA_SAMPLE_RATE_HZ;
    fprintf(stderr,
            "media_player_helper: Audio CD %s current=%llu target=%llu "
            "track=%u/%u\n",
            action, (unsigned long long)current_frame,
            (unsigned long long)target_frame,
            cdda_reader_current_track(reader),
            cdda_reader_track_count(reader));
    state->seek_pending = 0;
    return 0;
}

static int process_cdda_stream(const char *source_specification,
                               struct output_state *output,
                               struct audio_file_control_state *control)
{
    struct cdda_reader *reader = NULL;
    const char *path = source_specification +
                       strlen(MEDIA_PLAYER_CDDA_PREFIX);
    uint64_t length_frames;
    unsigned playlist_tracks[AUDIO_UI_MAX_PLAYLIST_TRACKS];
    unsigned track_count;
    unsigned track;
    int16_t pcm[2048u * CDDA_CHANNELS];
    char error[192];
    int result = -1;

    if (cdda_reader_open(&reader, path, error, sizeof(error)) < 0) {
        fprintf(stderr, "media_player_helper: %s\n", error);
        return -1;
    }
    length_frames = cdda_reader_length_frames(reader);
    track_count = cdda_reader_track_count(reader);
    if (track_count > AUDIO_UI_MAX_PLAYLIST_TRACKS)
        goto done;
    for (track = 0; track < track_count; ++track)
        playlist_tracks[track] = cdda_reader_track_number(reader, track);
    if (output->audio_ui &&
        audio_ui_set_playlist(output->audio_ui, playlist_tracks, track_count,
                              cdda_reader_current_track(reader)) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot configure Audio CD playlist\n");
        goto done;
    }
    if (cdda_update_ui_track(reader, output) < 0)
        goto done;
    output->audio_only_mode = 1;
    output->hold_active = 0;
    output->scheduler_started = 1;
    if (audio_file_configure_timeline(control, length_frames,
                                      CDDA_SAMPLE_RATE_HZ) < 0)
        goto done;
    fprintf(stderr,
            "media_player_helper: Audio CD tracks=%u frames=%llu "
            "rate=%u device=%s\n",
            cdda_reader_track_count(reader),
            (unsigned long long)length_frames,
            CDDA_SAMPLE_RATE_HZ, path);
    for (;;) {
        uint64_t current_frame = cdda_reader_position_frames(reader);
        int command = control->control_fd >= 0 ?
                      control_read_command(control->control_fd) : 0;
        int seconds = 0;

        if (cdda_update_ui_track(reader, output) < 0)
            goto done;

        if (command < 0)
            goto done;
        if (command == MEDIA_PLAYER_CONTROL_USER_ACTIVITY) {
            audio_visualizer_activity(output->visualizer,
                                      output->pcm_emitted_frames);
        } else if (command == MEDIA_PLAYER_CONTROL_PAUSE) {
            if (output->visualizer &&
                audio_overlay_publish_full(output, current_frame) < 0) {
                fprintf(stderr,
                        "media_player_helper: cannot refresh Audio CD "
                        "overlay before pause\n");
                goto done;
            }
            if (audio_pause_barrier(output, control->control_fd,
                                    CDDA_SAMPLE_RATE_HZ, "Audio CD") < 0)
                goto done;
        } else if (seek_command_seconds(command, &seconds)) {
            uint64_t target_frame = audio_file_seek_target(
                current_frame, length_frames, CDDA_SAMPLE_RATE_HZ, seconds);

            audio_visualizer_activity(output->visualizer,
                                      output->pcm_emitted_frames);
            if (target_frame == current_frame) {
                if (control_send(control->control_fd,
                                 MEDIA_PLAYER_CONTROL_SEEK_CONTINUE) < 0)
                    goto done;
                fprintf(stderr,
                        "media_player_helper: ignoring Audio CD seek %+d "
                        "seconds at boundary frame=%llu\n",
                        seconds, (unsigned long long)current_frame);
            } else {
                char action[48];

                snprintf(action, sizeof(action), "seek %+d seconds", seconds);
                control->seek_pending = 1;
                control->seek_seconds = seconds;
                if (cdda_complete_reposition(reader, control, current_frame,
                                             target_frame, action) < 0)
                    goto done;
            }
        } else if (command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ||
                   command == MEDIA_PLAYER_CONTROL_NEXT_CHAPTER) {
            int direction = command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ?
                            -1 : 1;
            uint64_t target_frame =
                cdda_reader_track_target(reader, direction);

            audio_visualizer_activity(output->visualizer,
                                      output->pcm_emitted_frames);
            if (target_frame == current_frame) {
                if (control_send(control->control_fd,
                                 MEDIA_PLAYER_CONTROL_SEEK_CONTINUE) < 0)
                    goto done;
                fprintf(stderr,
                        "media_player_helper: ignoring Audio CD %s track "
                        "at boundary track=%u/%u\n",
                        direction < 0 ? "previous" : "next",
                        cdda_reader_current_track(reader),
                        cdda_reader_track_count(reader));
            } else {
                control->seek_pending = 1;
                control->seek_seconds = 0;
                if (cdda_complete_reposition(
                        reader, control, current_frame, target_frame,
                        direction < 0 ? "previous track" : "next track") < 0)
                    goto done;
            }
        } else if (command) {
            fprintf(stderr,
                    "media_player_helper: ignoring unexpected Audio CD "
                    "control 0x%02x\n", command);
        }
        {
            ssize_t frames = cdda_reader_read_frames(reader, pcm, 2048u);

            if (frames < 0) {
                fprintf(stderr,
                        "media_player_helper: Audio CD read failed: %s\n",
                        strerror(cdda_reader_error(reader)));
                goto done;
            }
            if (!frames)
                break;
            if (write_consumer_pcm(output, pcm, (size_t)frames,
                                   CDDA_SAMPLE_RATE_HZ) < 0)
                goto done;
        }
    }
    result = 0;

done:
    cdda_reader_close(reader);
    return result;
}

static int finish_output(struct output_state *output, int success)
{
    int reserve_owned_video = output->reserve != NULL;

    if (output->reserve) {
        if (output_reserve_destroy(output->reserve) < 0) {
            fprintf(stderr,
                    "media_player_helper: output reserve shutdown failed: %s\n",
                    strerror(errno));
            success = 0;
        }
        output->reserve = NULL;
    }
    if (!reserve_owned_video && flush_output(output, "final output") < 0)
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
    int control_fd = -1;
    int show_capabilities = 0;
    struct output_state output = {0};
    unsigned audio_delay_ms = PCM_HOLD_DEFAULT_MS;
    struct audio_state audio = {0};
    struct media_source input = {0};
    struct dvd_menu_state dvd_menu = {0};
    struct program_stream_seek_index seek_index = {0};
    struct audio_file_control_state audio_file_control_state = {
        .output = &output,
        .control_fd = -1
    };
    const struct consumer_audio_control audio_file_control = {
        .opaque = &audio_file_control_state,
        .configure_timeline = audio_file_configure_timeline,
        .request_seek = audio_file_request_seek,
        .complete_seek = audio_file_complete_seek
    };
    char source_error[512];
    uint8_t signature[4];
    int is_program_stream;
    int is_mp3;
    int is_wav;
    int is_flac;
    int is_ogg;
    int is_cdda;
    int is_audio_file;
    int is_idle_visualizer;
    int dvd_menu_mode;
    int seekable_program_stream = 0;
    int program_video_code = -1;
    int program_audio_code = -1;
    int i;
    int success = 0;

    for (i = 1; i < argc; ++i) {
        if (!strcmp(argv[i], "--audio-out") && i + 1 < argc) {
            const char *value = argv[++i];
            if (!strcmp(value, "hdmi")) {
                audio.output = AUDIO_OUT_HDMI;
            } else if (!strcmp(value, "spdif")) {
                audio.output = AUDIO_OUT_SPDIF;
            } else {
                fprintf(stderr,
                        "media_player_helper: unknown audio output '%s' "
                        "(expected hdmi or spdif)\n", value);
                goto done;
            }
        } else if (!strcmp(argv[i], "--audio-delay-ms") && i + 1 < argc) {
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
        } else if (!strcmp(argv[i], "--control-fd") && i + 1 < argc) {
            char *end = NULL;
            long parsed;

            errno = 0;
            parsed = strtol(argv[++i], &end, 10);
            if (errno || !end || *end || parsed < 0 || parsed > INT32_MAX) {
                fprintf(stderr,
                        "media_player_helper: invalid control descriptor\n");
                return 2;
            }
            control_fd = (int)parsed;
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
    is_idle_visualizer =
        !strcmp(source_specification, MEDIA_PLAYER_IDLE_PREFIX);
    is_cdda = !strncmp(source_specification, MEDIA_PLAYER_CDDA_PREFIX,
                       strlen(MEDIA_PLAYER_CDDA_PREFIX));
    dvd_menu_mode = !strncmp(source_specification,
                             MEDIA_PLAYER_DVD_MENU_PREFIX,
                             strlen(MEDIA_PLAYER_DVD_MENU_PREFIX)) ||
                    !strncmp(source_specification,
                             MEDIA_PLAYER_ISO_MENU_PREFIX,
                             strlen(MEDIA_PLAYER_ISO_MENU_PREFIX));
    if (control_fd >= 0) {
        int flags = fcntl(control_fd, F_GETFL);

        if (flags < 0 || fcntl(control_fd, F_SETFL, flags | O_NONBLOCK) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot configure control channel: %s\n",
                    strerror(errno));
            return 2;
        }
        fprintf(stderr,
                "media_player_helper: control protocol %d fd=%d\n",
                MEDIA_PLAYER_CONTROL_PROTOCOL_VERSION, control_fd);
    }
    audio_file_control_state.control_fd = control_fd;
    if (!is_cdda && !is_idle_visualizer &&
        media_source_open(&input, source_specification, source_error,
                          sizeof(source_error)) != MEDIA_SOURCE_OK) {
        fprintf(stderr, "media_player_helper: %s\n", source_error);
        return 1;
    }
    dvd_menu.enabled = dvd_menu_mode;
    dvd_menu.spu_stream = -1;
    if (dvd_menu.enabled) {
        dvd_menu.decoder = dvd_spu_create();
        if (!dvd_menu.decoder) {
            fprintf(stderr,
                    "media_player_helper: cannot allocate DVD SPU decoder\n");
            media_source_close(&input);
            return 1;
        }
    }
    output.video = video_path ? fopen(video_path, "wb") : stdout;
    if (!output.video) {
        fprintf(stderr, "media_player_helper: cannot open video output: %s\n",
                strerror(errno));
        media_source_close(&input);
        return 1;
    }
    if (dvd_menu.enabled &&
        output_stage_create(&output.activation_stage,
                            OUTPUT_ACTIVATION_STAGE_BYTES) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot allocate DVD activation stage: %s\n",
                strerror(errno));
        goto done;
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
    audio.a52_substream = -1;
    audio.dts_substream = -1;
    /*
     * Record the mode so a log proves on its own which path ran. Entry 619
     * had to rely on a listening report for exactly this fact.
     */
    fprintf(stderr, "media_player_helper: audio output %s\n",
            audio.output == AUDIO_OUT_SPDIF
                ? "spdif (decoded PCM; IEC 61937 for AC-3/DTS)"
                : "hdmi (decoded stereo PCM)");
    if (!is_cdda && !is_idle_visualizer &&
        (read_exact(&input, signature, sizeof(signature)) < 0 ||
         media_source_rewind(&input) < 0)) {
        fprintf(stderr, "media_player_helper: input is too short\n");
        goto done;
    }
    is_mp3 = has_suffix_case(source_specification, ".mp3");
    is_wav = has_suffix_case(source_specification, ".wav");
    is_flac = has_suffix_case(source_specification, ".flac");
    is_ogg = has_suffix_case(source_specification, ".ogg");
    is_audio_file = is_mp3 || is_wav || is_flac || is_ogg || is_cdda;
    is_program_stream = !is_idle_visualizer && !is_audio_file &&
                        !memcmp(signature, "\x00\x00\x01\xba", 4);
    seekable_program_stream = is_program_stream &&
                              input.kind == MEDIA_SOURCE_FILE &&
                              (has_suffix_case(source_specification, ".mpg") ||
                               has_suffix_case(source_specification, ".mpeg"));
    if (is_mp3) {
        if (preflight_mp3(&input) < 0)
            goto done;
    } else if (!is_cdda && !is_idle_visualizer && !is_wav && !is_flac &&
               !is_ogg &&
               preflight_input(&input, is_program_stream) < 0) {
        goto done;
    }
    if (!is_cdda && !is_idle_visualizer &&
        media_source_prepare(&input) < 0) {
        fprintf(stderr,
                "media_player_helper: cannot prepare %s source for playback\n",
                media_source_kind_name(input.kind));
        goto done;
    }
    if (is_program_stream && input.kind == MEDIA_SOURCE_DVD &&
        output.video == stdout && !output.pcm) {
        if (output_reserve_create(&output.reserve, fileno(output.video),
                                  OUTPUT_RESERVE_BYTES) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot allocate DVD output reserve: %s\n",
                    strerror(errno));
            goto done;
        }
        fprintf(stderr,
                "media_player_helper: DVD output reserve=%zu bytes "
                "overlay_priority=%zu bytes\n",
                output_reserve_capacity(output.reserve),
                output_reserve_priority_capacity(output.reserve));
    }
    output.scheduler_enabled = is_program_stream && !output.pcm;
    output.iso_pts_normalization =
        input.kind == MEDIA_SOURCE_ISO || input.kind == MEDIA_SOURCE_DVD;
    output.iso_start_filter_active =
        (input.kind == MEDIA_SOURCE_ISO || input.kind == MEDIA_SOURCE_DVD) &&
        output.scheduler_enabled;
    output.h262_chroma_normalization =
        output.iso_pts_normalization && output.scheduler_enabled;
    if ((is_audio_file || is_idle_visualizer) && !output.pcm) {
        const char *visualizer_path = getenv("MMP_VISUALIZER_PATH");
        char visualizer_error[192];

        if (!visualizer_path || !*visualizer_path)
            visualizer_path = AUDIO_VISUALIZER_PATH;
        if (audio_visualizer_create(&output.visualizer, visualizer_path,
                                    visualizer_error,
                                    sizeof(visualizer_error)) == 0) {
            fprintf(stderr,
                    "media_player_helper: audio visualizer enabled asset=%s\n",
                    visualizer_path);
        } else {
            fprintf(stderr,
                    "media_player_helper: audio visualizer unavailable (%s); "
                    "%s\n", visualizer_error,
                    is_idle_visualizer ? "idle background disabled" :
                                         "using framebuffer UI");
            if (is_idle_visualizer)
                goto done;
        }
    }
    if (is_audio_file && !output.pcm) {
        if (audio_ui_create(&output.audio_ui) < 0) {
            fprintf(stderr,
                    "media_player_helper: cannot allocate audio UI\n");
            goto done;
        }
        fprintf(stderr, "media_player_helper: audio UI 720x480p %s enabled\n",
                output.visualizer ? "two-bit overlay" : "BT.601 frame");
    }
    if (is_idle_visualizer) {
        if (process_idle_visualizer(&output) < 0)
            goto done;
    } else if (is_cdda) {
        if (process_cdda_stream(source_specification, &output,
                                &audio_file_control_state) < 0)
            goto done;
    } else if (is_mp3) {
        if (process_mp3_stream(&input, &output, &audio_file_control) < 0)
            goto done;
    } else if (is_wav) {
        if (process_wav_stream(&input, &output, &audio_file_control) < 0)
            goto done;
    } else if (is_flac) {
        if (process_flac_stream(&input, &output, &audio_file_control) < 0)
            goto done;
    } else if (is_ogg) {
        if (process_ogg_stream(&input, &output, &audio_file_control) < 0)
            goto done;
    } else if (is_program_stream) {
        for (;;) {
            int command = 0;
            int result = process_program_stream(&input, &audio, &output,
                                                &dvd_menu,
                                                control_fd, &command,
                                                seekable_program_stream ?
                                                    &seek_index : NULL,
                                                &program_video_code,
                                                &program_audio_code);
            int seek_seconds;

            if (result < 0)
                goto done;
            if (!result)
                break;
            if (command == MEDIA_PLAYER_CONTROL_STREAM_BOUNDARY) {
                if (flush_output(&output, "DVD stream boundary") < 0)
                    goto done;
                reset_for_stream_boundary(&audio, &output);
                if (control_send(
                        control_fd,
                        MEDIA_PLAYER_CONTROL_STREAM_BOUNDARY) < 0 ||
                    control_wait_for_go(control_fd) < 0) {
                    fprintf(stderr,
                            "media_player_helper: DVD stream boundary "
                            "handshake failed\n");
                    goto done;
                }
                fprintf(stderr,
                        "media_player_helper: DVD stream boundary released\n");
                continue;
            }
            if (seekable_program_stream &&
                seek_command_seconds(command, &seek_seconds)) {
                struct program_stream_seek_entry selected;
                uint64_t current_pts = output.have_video_pts ?
                    output.max_video_pts :
                    (seek_index.count ?
                        seek_index.entries[seek_index.count - 1u].pts_90k : 0);
                uint64_t target_pts = program_stream_seek_target(
                    current_pts, seek_seconds);

                if (!seek_index.count ||
                    target_pts >
                        seek_index.entries[seek_index.count - 1u].pts_90k) {
                    if (scan_program_stream_seek(
                            &input, &seek_index, &program_video_code,
                            target_pts, &selected) < 0) {
                        (void)control_send(control_fd,
                                           MEDIA_PLAYER_CONTROL_ERROR);
                        goto done;
                    }
                } else if (!program_stream_seek_find(
                               &seek_index, target_pts, &selected) ||
                           media_source_seek(&input, selected.source_offset,
                                             MEDIA_SOURCE_SEEK_START) < 0) {
                    (void)control_send(control_fd,
                                       MEDIA_PLAYER_CONTROL_ERROR);
                    fprintf(stderr,
                            "media_player_helper: Program Stream seek failed\n");
                    goto done;
                }
                if (flush_output(&output, "seek barrier") < 0)
                    goto done;
                reset_audio_for_navigation(&audio);
                reset_output_for_navigation(
                    &output,
                    (size_t)audio_delay_ms * (size_t)PCM_SAMPLE_RATE / 1000u,
                    0);
                if (control_send(control_fd, MEDIA_PLAYER_CONTROL_READY) < 0 ||
                    control_wait_for_go(control_fd) < 0) {
                    fprintf(stderr,
                            "media_player_helper: seek barrier failed\n");
                    goto done;
                }
                fprintf(stderr,
                        "media_player_helper: seek %+d seconds target=%llu "
                        "selected=%llu offset=%lld entries=%zu\n",
                        seek_seconds, (unsigned long long)target_pts,
                        (unsigned long long)selected.pts_90k,
                        (long long)selected.source_offset, seek_index.count);
                continue;
            }
            if ((command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ||
                 command == MEDIA_PLAYER_CONTROL_NEXT_CHAPTER) &&
                ((input.kind != MEDIA_SOURCE_ISO &&
                  input.kind != MEDIA_SOURCE_DVD) ||
                 media_source_change_chapter(
                     &input,
                     command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ? -1 : 1)
                     < 0)) {
                (void)control_send(control_fd, MEDIA_PLAYER_CONTROL_ERROR);
                fprintf(stderr,
                        "media_player_helper: chapter control failed\n");
                goto done;
            }
            if (command == MEDIA_PLAYER_CONTROL_ROOT_MENU ||
                command == MEDIA_PLAYER_CONTROL_PREVIOUS_CHAPTER ||
                command == MEDIA_PLAYER_CONTROL_NEXT_CHAPTER ||
                dvd_menu.activation_staged_hop) {
                if (discard_reserved_output(&output, command,
                                            "navigation barrier") < 0)
                    goto done;
            } else if (flush_output(&output, "chapter barrier") < 0) {
                goto done;
            }
            reset_audio_for_navigation(&audio);
            reset_output_for_navigation(
                &output,
                (size_t)audio_delay_ms * (size_t)PCM_SAMPLE_RATE / 1000u,
                1);
            if (control_send(control_fd, MEDIA_PLAYER_CONTROL_READY) < 0 ||
                control_wait_for_go(control_fd) < 0) {
                fprintf(stderr,
                        "media_player_helper: chapter barrier failed\n");
                goto done;
            }
            if (dvd_menu.enabled) {
                if (dvd_menu.activation_staged_hop) {
                    if (commit_activation_stage(
                            &output, "payload-indefinite-menu-hop") < 0)
                        goto done;
                    dvd_menu.activation_pending = 0;
                    dvd_menu.activation_payloads = 0;
                    dvd_menu.activation_staged_hop = 0;
                    dvd_menu.activation_prior_pts_valid = 0;
                    dvd_menu.activation_prior_pts = 0;
                } else {
                    dvd_spu_reset(dvd_menu.decoder);
                    dvd_menu.overlay_emitted = 0;
                    if (emit_overlay_clear(&output) < 0)
                        goto done;
                }
            }
            fprintf(stderr,
                    "media_player_helper: navigation barrier released\n");
        }
        if (flush_h262_video(&output) < 0)
            goto done;
        if (!output.audio_pes_seen) {
            if (output.scheduler_enabled &&
                scheduler_release_silent_video(&output) < 0)
                goto done;
        } else if (decode_audio_buffer(&audio, &output, 1) < 0 ||
                   scheduler_drain(&output, 1) < 0) {
            goto done;
        }
    } else if (process_elementary_stream(&input, &output) < 0) {
        goto done;
    }
    if (!is_audio_file && !is_idle_visualizer && !output.video_bytes) {
        fprintf(stderr, "media_player_helper: no H.262 video stream found\n");
        goto done;
    }
    if (is_audio_file && !output.audio_frames) {
        fprintf(stderr, "media_player_helper: no supported audio found\n");
        goto done;
    }
    if (is_program_stream && output.audio_pes_seen && !output.audio_frames) {
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
    if (output.iso_pts_normalization)
        fprintf(stderr,
                "media_player_helper: DVD PTS discontinuities=%u\n",
                output.iso_pts_discontinuities);
done:
    program_stream_seek_destroy(&seek_index);
    if (audio_file_control_state.seek_pending && control_fd >= 0)
        (void)control_send(control_fd, MEDIA_PLAYER_CONTROL_ERROR);
    if (control_fd >= 0)
        close(control_fd);
    if (audio.a52)
        a52_free(audio.a52);
    free(audio.data);
    dvd_spu_destroy(dvd_menu.decoder);
    media_source_close(&input);
    output.hold_active = 0;
    if (success && !output.pcm && hold_flush(&output, 0) < 0)
        success = 0;
    if (success && output.visualizer) {
        static const uint8_t sequence_end[4] = {0, 0, 1, 0xb7};

        if (write_visualizer_video(&output, sequence_end,
                                   sizeof(sequence_end)) < 0 ||
            audio_overlay_publish_full(&output,
                audio_overlay_position(&output,
                                       output.pcm_emitted_frames)) < 0) {
            fprintf(stderr,
                    "media_player_helper: final audio visualizer output failed\n");
            success = 0;
        }
    } else if (success && output.audio_ui &&
        audio_ui_complete(output.audio_ui, output.pcm_emitted_frames,
                          (unsigned)output.hold_rate_hz,
                          emit_audio_ui_record, &output) < 0) {
        fprintf(stderr,
                "media_player_helper: final audio UI output failed\n");
        success = 0;
    }
    if (success && output.audio_frames && !output.pcm &&
        emit_pcm_end(&output) < 0)
        success = 0;
    if (output.audio_ui) {
        if (!output.visualizer)
            fprintf(stderr,
                    "media_player_helper: audio UI committed=%u frame(s)\n",
                    audio_ui_committed_frames(output.audio_ui));
        audio_ui_destroy(output.audio_ui);
        output.audio_ui = NULL;
    }
    if (output.visualizer) {
        fprintf(stderr,
                "media_player_helper: audio visualizer gops=%llu level=%u\n",
                (unsigned long long)audio_visualizer_gops_sent(
                    output.visualizer),
                audio_visualizer_level(output.visualizer));
        audio_visualizer_destroy(output.visualizer);
        output.visualizer = NULL;
    }
    free(output.audio_overlay.plane);
    output.audio_overlay.plane = NULL;
    free(output.hold);
    output.hold = NULL;
    while (output.video_head)
        free_video_head(&output);
    if (output.activation_stage) {
        if (success && output_stage_active(output.activation_stage)) {
            fprintf(stderr,
                    "media_player_helper: active DVD output stage at shutdown\n");
            success = 0;
        }
        output_stage_destroy(output.activation_stage);
        output.activation_stage = NULL;
    }
    if (video_path && output.video) {
        fclose(output.video);
        output.video = NULL;
    }
    return finish_output(&output, success);
}
