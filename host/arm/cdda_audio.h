#ifndef CDDA_AUDIO_H
#define CDDA_AUDIO_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#define CDDA_SAMPLE_RATE_HZ 44100u
#define CDDA_CHANNELS 2u
#define CDDA_PCM_FRAMES_PER_SECTOR 588u

struct cdda_reader;

struct cdda_device_ops {
    int (*open_device)(void *opaque, const char *path, int flags);
    int (*ioctl_device)(void *opaque, int fd, unsigned long request,
                        void *argument);
    int (*close_device)(void *opaque, int fd);
};

int cdda_reader_open(struct cdda_reader **reader, const char *path,
                     char *error, size_t error_size);
int cdda_reader_open_with_ops(struct cdda_reader **reader, const char *path,
                              const struct cdda_device_ops *ops, void *opaque,
                              char *error, size_t error_size);
void cdda_reader_close(struct cdda_reader *reader);

uint64_t cdda_reader_length_frames(const struct cdda_reader *reader);
uint64_t cdda_reader_position_frames(const struct cdda_reader *reader);
unsigned cdda_reader_track_count(const struct cdda_reader *reader);
unsigned cdda_reader_track_number(const struct cdda_reader *reader,
                                  unsigned index);
unsigned cdda_reader_current_track(const struct cdda_reader *reader);
int cdda_reader_current_track_timing(const struct cdda_reader *reader,
                                     uint64_t *start_frame,
                                     uint64_t *length_frames);

int cdda_reader_seek_frame(struct cdda_reader *reader, uint64_t frame);
uint64_t cdda_reader_track_target(const struct cdda_reader *reader,
                                  int direction);
ssize_t cdda_reader_read_frames(struct cdda_reader *reader, int16_t *stereo,
                                size_t frames);
int cdda_reader_error(const struct cdda_reader *reader);

#endif
