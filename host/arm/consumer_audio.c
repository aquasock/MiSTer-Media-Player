#define MA_NO_DEVICE_IO
#define MA_NO_ENGINE
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_GENERATION
#define MA_NO_ENCODING
#define MA_NO_THREADING
#define MA_NO_RUNTIME_LINKING
#define STB_VORBIS_HEADER_ONLY
#include "stb_vorbis.c"
#undef STB_VORBIS_HEADER_ONLY
#define MINIAUDIO_IMPLEMENTATION

#include "miniaudio.h"
#include "stb_vorbis.c"

#include "audio_file_seek.h"
#include "consumer_audio.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define CONSUMER_PCM_CHUNK_FRAMES 2048u
#define CONSUMER_MAX_CHANNELS 8u
#define CONSUMER_MIN_RATE_HZ 8000u
#define CONSUMER_MAX_RATE_HZ 192000u
#define OGG_MAX_PAGE_BYTES (27u + 255u + 255u * 255u)

static void set_format_error(char *error, size_t error_size,
                             const char *format, const char *message)
{
    if (error && error_size)
        snprintf(error, error_size, message, format);
}

static ma_result source_read(ma_decoder *decoder, void *data, size_t size,
                             size_t *read_size)
{
    struct media_source *source = decoder->pUserData;
    size_t count = media_source_read(source, data, size);

    if (read_size)
        *read_size = count;
    if (count)
        return MA_SUCCESS;
    return media_source_error(source) ? MA_ERROR : MA_AT_END;
}

static ma_result source_seek(ma_decoder *decoder, ma_int64 offset,
                             ma_seek_origin origin)
{
    struct media_source *source = decoder->pUserData;
    enum media_source_seek_origin source_origin;

    if (origin == ma_seek_origin_start)
        source_origin = MEDIA_SOURCE_SEEK_START;
    else if (origin == ma_seek_origin_current)
        source_origin = MEDIA_SOURCE_SEEK_CURRENT;
    else if (origin == ma_seek_origin_end)
        source_origin = MEDIA_SOURCE_SEEK_END;
    else
        return MA_INVALID_ARGS;
    return media_source_seek(source, offset, source_origin) == 0 ?
           MA_SUCCESS : MA_ERROR;
}

static unsigned choose_output_rate(unsigned source_rate)
{
    return source_rate % 11025u == 0u ? 44100u : 48000u;
}

static int ogg_tail_length(struct media_source *source, uint64_t *frames)
{
    uint8_t *tail = NULL;
    int64_t file_size;
    int64_t start;
    size_t wanted;
    size_t count = 0;
    size_t offset;
    int result = -1;

    if (!source || !frames ||
        media_source_seek(source, 0, MEDIA_SOURCE_SEEK_END) < 0 ||
        media_source_position(source, &file_size) < 0 || file_size < 27)
        goto done;
    start = file_size > (int64_t)OGG_MAX_PAGE_BYTES ?
            file_size - (int64_t)OGG_MAX_PAGE_BYTES : 0;
    wanted = (size_t)(file_size - start);
    tail = malloc(wanted);
    if (!tail ||
        media_source_seek(source, start, MEDIA_SOURCE_SEEK_START) < 0)
        goto done;
    while (count < wanted) {
        size_t read_size = media_source_read(source, tail + count,
                                             wanted - count);

        if (!read_size)
            break;
        count += read_size;
    }
    if (count < 27u)
        goto done;
    for (offset = count - 27u;; --offset) {
        size_t segment_count;
        size_t header_size;
        size_t body_size = 0;
        size_t segment;
        uint64_t granule = 0;
        unsigned byte;

        if (!memcmp(tail + offset, "OggS", 4) && tail[offset + 4u] == 0 &&
            (tail[offset + 5u] & 0x04u)) {
            segment_count = tail[offset + 26u];
            header_size = 27u + segment_count;
            if (offset + header_size <= count) {
                for (segment = 0; segment < segment_count; ++segment)
                    body_size += tail[offset + 27u + segment];
                if (offset + header_size + body_size == count) {
                    for (byte = 0; byte < 8u; ++byte)
                        granule |= (uint64_t)tail[offset + 6u + byte] <<
                                   (byte * 8u);
                    if (granule != UINT64_MAX) {
                        *frames = granule;
                        result = 0;
                        break;
                    }
                }
            }
        }
        if (!offset)
            break;
    }

done:
    free(tail);
    if (media_source_rewind(source) < 0)
        return -1;
    return result;
}

static int consumer_audio_decode_miniaudio(
    struct media_source *source, ma_encoding_format encoding_format,
    const char *format_name, consumer_pcm_callback callback, void *opaque,
    const struct consumer_audio_control *control, int restricted_mp3,
    struct consumer_audio_info *info, char *error, size_t error_size)
{
    ma_decoder decoder;
    ma_decoder_config config;
    ma_format source_format;
    ma_uint32 source_channels;
    ma_uint32 source_rate;
    unsigned output_rate;
    ma_uint64 length_frames;
    uint64_t ogg_source_frames = 0;
    int16_t pcm[CONSUMER_PCM_CHUNK_FRAMES * 2u];
    uint64_t total_frames = 0;
    ma_result result;

    if (!source || !callback) {
        set_format_error(error, error_size, format_name,
                         "invalid %s decoder arguments");
        return -1;
    }
    if (encoding_format == ma_encoding_format_vorbis &&
        ogg_tail_length(source, &ogg_source_frames) < 0) {
        set_format_error(error, error_size, format_name,
                         "cannot determine %s duration");
        return -1;
    }
    memset(&decoder, 0, sizeof(decoder));
    config = ma_decoder_config_init(ma_format_s16, 2, 0);
    config.encodingFormat = encoding_format;
    config.seekPointCount = restricted_mp3 ? 64u : 0u;
    result = ma_decoder_init(source_read, source_seek, source, &config,
                             &decoder);
    if (result != MA_SUCCESS) {
        set_format_error(error, error_size, format_name,
                         "not a supported %s file");
        return -1;
    }
    result = decoder.pBackend ?
        ma_data_source_get_data_format(decoder.pBackend, &source_format,
                                       &source_channels, &source_rate,
                                       NULL, 0) : MA_ERROR;
    if (result != MA_SUCCESS || source_format == ma_format_unknown ||
        source_channels == 0 || source_channels > CONSUMER_MAX_CHANNELS ||
        source_rate < CONSUMER_MIN_RATE_HZ ||
        source_rate > CONSUMER_MAX_RATE_HZ ||
        (restricted_mp3 &&
         ((source_channels != 1u && source_channels != 2u) ||
          (source_rate != 44100u && source_rate != 48000u)))) {
        ma_decoder_uninit(&decoder);
        set_format_error(error, error_size, format_name,
                         "unsupported %s channel count or sample rate");
        return -1;
    }
    output_rate = choose_output_rate(source_rate);
    if (decoder.outputSampleRate != output_rate) {
        ma_decoder_uninit(&decoder);
        if (media_source_rewind(source) != 0) {
            set_format_error(error, error_size, format_name,
                             "cannot rewind %s source");
            return -1;
        }
        memset(&decoder, 0, sizeof(decoder));
        config = ma_decoder_config_init(ma_format_s16, 2, output_rate);
        config.encodingFormat = encoding_format;
        config.seekPointCount = restricted_mp3 ? 64u : 0u;
        config.resampling.linear.lpfOrder = 8;
        result = ma_decoder_init(source_read, source_seek, source, &config,
                                 &decoder);
        if (result != MA_SUCCESS) {
            set_format_error(error, error_size, format_name,
                             "cannot initialize %s conversion");
            return -1;
        }
    }
    result = ma_decoder_get_length_in_pcm_frames(&decoder, &length_frames);
    if (result != MA_SUCCESS) {
        ma_decoder_uninit(&decoder);
        set_format_error(error, error_size, format_name,
                         "cannot determine %s duration");
        return -1;
    }
    if (!length_frames && encoding_format == ma_encoding_format_vorbis)
        length_frames = ma_calculate_frame_count_after_resampling(
            output_rate, source_rate, ogg_source_frames);
    if (!length_frames) {
        ma_decoder_uninit(&decoder);
        set_format_error(error, error_size, format_name,
                         "cannot determine %s duration");
        return -1;
    }
    if (control && control->configure_timeline &&
        control->configure_timeline(control->opaque, length_frames,
                                    output_rate) < 0) {
        ma_decoder_uninit(&decoder);
        set_format_error(error, error_size, format_name,
                         "cannot configure %s playback timeline");
        return -1;
    }
    for (;;) {
        ma_uint64 frames_read = 0;

        if (control && control->request_seek) {
            ma_uint64 current_frame;
            int seconds = 0;
            int request;

            result = ma_decoder_get_cursor_in_pcm_frames(&decoder,
                                                          &current_frame);
            if (result != MA_SUCCESS) {
                ma_decoder_uninit(&decoder);
                set_format_error(error, error_size, format_name,
                                 "cannot read %s playback position");
                return -1;
            }
            request = control->request_seek(
                control->opaque, current_frame, length_frames,
                output_rate, &seconds);
            if (request < 0) {
                ma_decoder_uninit(&decoder);
                set_format_error(error, error_size, format_name,
                                 "cannot read %s seek control");
                return -1;
            }
            if (request > 0) {
                ma_uint64 target_frame = audio_file_seek_target(
                    current_frame, length_frames, output_rate, seconds);

                result = ma_decoder_seek_to_pcm_frame(&decoder, target_frame);
                if (result != MA_SUCCESS || !control->complete_seek ||
                    control->complete_seek(control->opaque, current_frame,
                                           target_frame, output_rate) < 0) {
                    ma_decoder_uninit(&decoder);
                    set_format_error(error, error_size, format_name,
                                     "cannot complete %s seek");
                    return -1;
                }
            }
        }

        result = ma_decoder_read_pcm_frames(&decoder, pcm,
                                            CONSUMER_PCM_CHUNK_FRAMES,
                                            &frames_read);
        if (frames_read) {
            if (callback(opaque, pcm, (size_t)frames_read,
                         (int)output_rate) < 0) {
                ma_decoder_uninit(&decoder);
                set_format_error(error, error_size, format_name,
                                 "cannot write %s PCM output");
                return -1;
            }
            total_frames += frames_read;
        }
        if (result == MA_AT_END || frames_read == 0)
            break;
        if (result != MA_SUCCESS) {
            ma_decoder_uninit(&decoder);
            set_format_error(error, error_size, format_name,
                             "damaged %s audio data");
            return -1;
        }
    }
    ma_decoder_uninit(&decoder);
    if (!total_frames) {
        set_format_error(error, error_size, format_name,
                         "%s file contains no audio frames");
        return -1;
    }
    if (info) {
        info->source_channels = source_channels;
        info->source_rate_hz = source_rate;
        info->output_rate_hz = output_rate;
        info->output_frames = total_frames;
    }
    return 0;
}

int consumer_audio_decode_wav(struct media_source *source,
                              consumer_pcm_callback callback, void *opaque,
                              const struct consumer_audio_control *control,
                              struct consumer_audio_info *info,
                              char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_wav, "WAV", callback, opaque, control, 0,
        info, error, error_size);
}

int consumer_audio_decode_mp3(struct media_source *source,
                              consumer_pcm_callback callback, void *opaque,
                              const struct consumer_audio_control *control,
                              struct consumer_audio_info *info,
                              char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_mp3, "MP3", callback, opaque, control, 1,
        info, error, error_size);
}

int consumer_audio_decode_flac(struct media_source *source,
                               consumer_pcm_callback callback, void *opaque,
                               const struct consumer_audio_control *control,
                               struct consumer_audio_info *info,
                               char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_flac, "FLAC", callback, opaque, control, 0,
        info, error, error_size);
}

int consumer_audio_decode_ogg(struct media_source *source,
                              consumer_pcm_callback callback, void *opaque,
                              const struct consumer_audio_control *control,
                              struct consumer_audio_info *info,
                              char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_vorbis, "Ogg Vorbis", callback, opaque,
        control, 0, info, error, error_size);
}
