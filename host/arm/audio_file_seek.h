#ifndef AUDIO_FILE_SEEK_H
#define AUDIO_FILE_SEEK_H

#include <stdint.h>

uint64_t audio_file_seek_target(uint64_t current_frame,
                                uint64_t length_frames,
                                unsigned rate_hz,
                                int seconds);

#endif
