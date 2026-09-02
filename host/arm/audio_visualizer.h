#ifndef AUDIO_VISUALIZER_H
#define AUDIO_VISUALIZER_H

#include <stddef.h>
#include <stdint.h>

#define AUDIO_VISUALIZER_LEVELS 4u
#define AUDIO_VISUALIZER_SLICE_BYTES 4096u

struct audio_visualizer;

typedef int (*audio_visualizer_writer)(void *opaque, const uint8_t *data,
                                       size_t size);

int audio_visualizer_create(struct audio_visualizer **result,
                            const char *path, char *error, size_t error_size);
void audio_visualizer_destroy(struct audio_visualizer *visualizer);
void audio_visualizer_analyze(struct audio_visualizer *visualizer,
                              const int16_t *stereo, size_t frames);
int audio_visualizer_service(struct audio_visualizer *visualizer,
                             uint64_t emitted_pcm_frames, unsigned rate_hz,
                             audio_visualizer_writer writer, void *opaque);
void audio_visualizer_activity(struct audio_visualizer *visualizer,
                               uint64_t emitted_pcm_frames);
void audio_visualizer_seek(struct audio_visualizer *visualizer,
                           uint64_t emitted_pcm_frames);
int audio_visualizer_take_overlay_action(struct audio_visualizer *visualizer,
                                         uint64_t emitted_pcm_frames,
                                         unsigned rate_hz);
unsigned audio_visualizer_level(const struct audio_visualizer *visualizer);
uint64_t audio_visualizer_gops_sent(const struct audio_visualizer *visualizer);

#endif
