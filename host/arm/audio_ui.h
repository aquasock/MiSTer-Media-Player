#ifndef AUDIO_UI_H
#define AUDIO_UI_H

#include <stddef.h>
#include <stdint.h>

#define AUDIO_UI_WIDTH 720u
#define AUDIO_UI_HEIGHT 480u
#define AUDIO_UI_FRAME_BYTES \
    (AUDIO_UI_WIDTH * AUDIO_UI_HEIGHT * 3u / 2u)
#define AUDIO_UI_DATA_BYTES 4096u

struct audio_ui;

typedef int (*audio_ui_record_writer)(void *opaque, uint8_t command,
                                      const uint8_t *payload, size_t size);

int audio_ui_create(struct audio_ui **ui);
void audio_ui_destroy(struct audio_ui *ui);

/*
 * Service at a PCM-record boundary. At most one bounded display record is
 * emitted per call, so image traffic can never hide an unbounded audio gap.
 */
int audio_ui_service(struct audio_ui *ui, uint64_t emitted_pcm_frames,
                     unsigned rate_hz, audio_ui_record_writer writer,
                     void *opaque);

unsigned audio_ui_committed_frames(const struct audio_ui *ui);

#endif
