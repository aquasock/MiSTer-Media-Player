#ifndef CONSUMER_AUDIO_H
#define CONSUMER_AUDIO_H

#include "media_source.h"

#include <stddef.h>
#include <stdint.h>

typedef int (*consumer_pcm_callback)(void *opaque, const int16_t *stereo,
                                     size_t frames, int rate_hz);

struct consumer_audio_info {
    unsigned source_channels;
    unsigned source_rate_hz;
    unsigned output_rate_hz;
    uint64_t output_frames;
};

int consumer_audio_decode_wav(struct media_source *source,
                              consumer_pcm_callback callback, void *opaque,
                              struct consumer_audio_info *info,
                              char *error, size_t error_size);

int consumer_audio_decode_flac(struct media_source *source,
                               consumer_pcm_callback callback, void *opaque,
                               struct consumer_audio_info *info,
                               char *error, size_t error_size);

int consumer_audio_decode_ogg(struct media_source *source,
                              consumer_pcm_callback callback, void *opaque,
                              struct consumer_audio_info *info,
                              char *error, size_t error_size);

#endif
