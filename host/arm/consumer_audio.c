#define MA_NO_DEVICE_IO
#define MA_NO_ENGINE
#define MA_NO_RESOURCE_MANAGER
#define MA_NO_NODE_GRAPH
#define MA_NO_GENERATION
#define MA_NO_ENCODING
#define MA_NO_THREADING
#define MA_NO_RUNTIME_LINKING
#define MA_NO_MP3
#define MINIAUDIO_IMPLEMENTATION

#include "miniaudio.h"

#include "consumer_audio.h"

#include <stdio.h>
#include <string.h>

#define CONSUMER_PCM_CHUNK_FRAMES 2048u
#define CONSUMER_MAX_CHANNELS 8u
#define CONSUMER_MIN_RATE_HZ 8000u
#define CONSUMER_MAX_RATE_HZ 192000u

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
    else
        return MA_INVALID_ARGS;
    return media_source_seek(source, offset, source_origin) == 0 ?
           MA_SUCCESS : MA_ERROR;
}

static unsigned choose_output_rate(unsigned source_rate)
{
    return source_rate % 11025u == 0u ? 44100u : 48000u;
}

static int consumer_audio_decode_miniaudio(
    struct media_source *source, ma_encoding_format encoding_format,
    const char *format_name, consumer_pcm_callback callback, void *opaque,
    struct consumer_audio_info *info, char *error, size_t error_size)
{
    ma_decoder decoder;
    ma_decoder_config config;
    ma_format source_format;
    ma_uint32 source_channels;
    ma_uint32 source_rate;
    unsigned output_rate;
    int16_t pcm[CONSUMER_PCM_CHUNK_FRAMES * 2u];
    uint64_t total_frames = 0;
    ma_result result;

    if (!source || !callback) {
        set_format_error(error, error_size, format_name,
                         "invalid %s decoder arguments");
        return -1;
    }
    memset(&decoder, 0, sizeof(decoder));
    config = ma_decoder_config_init_default();
    config.encodingFormat = encoding_format;
    result = ma_decoder_init(source_read, source_seek, source, &config,
                             &decoder);
    if (result != MA_SUCCESS) {
        set_format_error(error, error_size, format_name,
                         "not a supported %s file");
        return -1;
    }
    result = ma_decoder_get_data_format(&decoder, &source_format,
                                        &source_channels, &source_rate,
                                        NULL, 0);
    if (result != MA_SUCCESS || source_format == ma_format_unknown ||
        source_channels == 0 || source_channels > CONSUMER_MAX_CHANNELS ||
        source_rate < CONSUMER_MIN_RATE_HZ ||
        source_rate > CONSUMER_MAX_RATE_HZ) {
        ma_decoder_uninit(&decoder);
        set_format_error(error, error_size, format_name,
                         "unsupported %s channel count or sample rate");
        return -1;
    }
    output_rate = choose_output_rate(source_rate);
    ma_decoder_uninit(&decoder);
    if (media_source_rewind(source) != 0) {
        set_format_error(error, error_size, format_name,
                         "cannot rewind %s source");
        return -1;
    }

    memset(&decoder, 0, sizeof(decoder));
    config = ma_decoder_config_init(ma_format_s16, 2, output_rate);
    config.encodingFormat = encoding_format;
    config.resampling.linear.lpfOrder = 8;
    result = ma_decoder_init(source_read, source_seek, source, &config,
                             &decoder);
    if (result != MA_SUCCESS) {
        set_format_error(error, error_size, format_name,
                         "cannot initialize %s conversion");
        return -1;
    }
    for (;;) {
        ma_uint64 frames_read = 0;

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
                              struct consumer_audio_info *info,
                              char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_wav, "WAV", callback, opaque, info,
        error, error_size);
}

int consumer_audio_decode_flac(struct media_source *source,
                               consumer_pcm_callback callback, void *opaque,
                               struct consumer_audio_info *info,
                               char *error, size_t error_size)
{
    return consumer_audio_decode_miniaudio(
        source, ma_encoding_format_flac, "FLAC", callback, opaque, info,
        error, error_size);
}
