#define _POSIX_C_SOURCE 200809L

#include "cdda_audio.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <linux/cdrom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#define CDDA_MAX_TRACKS 99u
#define CDDA_READ_SECTORS 8u
#define CDDA_BYTES_PER_PCM_FRAME 4u
#define CDDA_PREVIOUS_RESTART_FRAMES (3u * CDDA_SAMPLE_RATE_HZ)

struct cdda_track {
    unsigned number;
    int start_lba;
    uint64_t first_sector;
    uint64_t sectors;
};

struct cdda_reader {
    int fd;
    const struct cdda_device_ops *ops;
    void *ops_opaque;
    struct cdda_track tracks[CDDA_MAX_TRACKS];
    unsigned track_count;
    uint64_t total_sectors;
    uint64_t cursor_frame;
    uint64_t buffer_first_sector;
    unsigned buffer_sectors;
    int buffer_valid;
    int error;
    uint8_t buffer[CDDA_READ_SECTORS * CD_FRAMESIZE_RAW];
};

static void set_error(char *error, size_t error_size, const char *message,
                      const char *detail)
{
    if (!error || !error_size)
        return;
    if (detail)
        snprintf(error, error_size, "%s: %s", message, detail);
    else
        snprintf(error, error_size, "%s", message);
}

static int system_open_device(void *opaque, const char *path, int flags)
{
    (void)opaque;
    return open(path, flags);
}

static int system_ioctl_device(void *opaque, int fd, unsigned long request,
                               void *argument)
{
    (void)opaque;
    return ioctl(fd, request, argument);
}

static int system_close_device(void *opaque, int fd)
{
    (void)opaque;
    return close(fd);
}

static const struct cdda_device_ops system_ops = {
    system_open_device,
    system_ioctl_device,
    system_close_device
};

static int read_toc_entry(struct cdda_reader *reader, unsigned track,
                          struct cdrom_tocentry *entry)
{
    memset(entry, 0, sizeof(*entry));
    entry->cdte_track = (uint8_t)track;
    entry->cdte_format = CDROM_LBA;
    return reader->ops->ioctl_device(reader->ops_opaque, reader->fd,
                                     CDROMREADTOCENTRY, entry);
}

static int inventory_tracks(struct cdda_reader *reader, char *error,
                            size_t error_size)
{
    struct cdrom_tochdr header;
    struct cdrom_tocentry entries[CDDA_MAX_TRACKS];
    struct cdrom_tocentry leadout;
    unsigned physical_count;
    unsigned index;

    memset(&header, 0, sizeof(header));
    if (reader->ops->ioctl_device(reader->ops_opaque, reader->fd,
                                  CDROMREADTOCHDR, &header) < 0) {
        set_error(error, error_size, "cannot read Audio CD table of contents",
                  strerror(errno));
        return -1;
    }
    if (!header.cdth_trk0 || header.cdth_trk1 < header.cdth_trk0) {
        set_error(error, error_size, "Audio CD table of contents is invalid",
                  NULL);
        return -1;
    }
    physical_count = (unsigned)header.cdth_trk1 -
                     (unsigned)header.cdth_trk0 + 1u;
    if (physical_count > CDDA_MAX_TRACKS) {
        set_error(error, error_size, "Audio CD has too many tracks", NULL);
        return -1;
    }
    for (index = 0; index < physical_count; ++index) {
        unsigned track = (unsigned)header.cdth_trk0 + index;

        if (read_toc_entry(reader, track, &entries[index]) < 0) {
            set_error(error, error_size, "cannot read Audio CD track entry",
                      strerror(errno));
            return -1;
        }
    }
    if (read_toc_entry(reader, CDROM_LEADOUT, &leadout) < 0) {
        set_error(error, error_size, "cannot read Audio CD lead-out",
                  strerror(errno));
        return -1;
    }
    for (index = 0; index < physical_count; ++index) {
        int start_lba = entries[index].cdte_addr.lba;
        int end_lba = index + 1u < physical_count ?
                      entries[index + 1u].cdte_addr.lba :
                      leadout.cdte_addr.lba;
        uint64_t sectors;
        struct cdda_track *track;

        if (start_lba < 0 || end_lba <= start_lba) {
            set_error(error, error_size,
                      "Audio CD track addresses are invalid", NULL);
            return -1;
        }
        if (entries[index].cdte_ctrl & CDROM_DATA_TRACK)
            continue;
        sectors = (uint64_t)(end_lba - start_lba);
        if (reader->total_sectors > UINT64_MAX - sectors) {
            set_error(error, error_size, "Audio CD duration is too large",
                      NULL);
            return -1;
        }
        track = &reader->tracks[reader->track_count++];
        track->number = (unsigned)entries[index].cdte_track;
        track->start_lba = start_lba;
        track->first_sector = reader->total_sectors;
        track->sectors = sectors;
        reader->total_sectors += sectors;
    }
    if (!reader->track_count || !reader->total_sectors) {
        set_error(error, error_size, "disc contains no Audio CD tracks", NULL);
        return -1;
    }
    if (reader->total_sectors > UINT64_MAX / CDDA_PCM_FRAMES_PER_SECTOR) {
        set_error(error, error_size, "Audio CD duration is too large", NULL);
        return -1;
    }
    return 0;
}

int cdda_reader_open_with_ops(struct cdda_reader **reader, const char *path,
                              const struct cdda_device_ops *ops, void *opaque,
                              char *error, size_t error_size)
{
    struct cdda_reader *created;

    if (!reader || !path || path[0] != '/' || !ops || !ops->open_device ||
        !ops->ioctl_device || !ops->close_device) {
        set_error(error, error_size, "invalid Audio CD device", NULL);
        return -1;
    }
    *reader = NULL;
    created = calloc(1, sizeof(*created));
    if (!created) {
        set_error(error, error_size, "cannot allocate Audio CD reader",
                  strerror(errno));
        return -1;
    }
    created->fd = -1;
    created->ops = ops;
    created->ops_opaque = opaque;
    created->fd = ops->open_device(opaque, path,
                                   O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (created->fd < 0) {
        set_error(error, error_size, "cannot open Audio CD device",
                  strerror(errno));
        free(created);
        return -1;
    }
    if (inventory_tracks(created, error, error_size) < 0) {
        ops->close_device(opaque, created->fd);
        free(created);
        return -1;
    }
    *reader = created;
    return 0;
}

int cdda_reader_open(struct cdda_reader **reader, const char *path,
                     char *error, size_t error_size)
{
    return cdda_reader_open_with_ops(reader, path, &system_ops, NULL,
                                     error, error_size);
}

void cdda_reader_close(struct cdda_reader *reader)
{
    if (!reader)
        return;
    if (reader->fd >= 0)
        reader->ops->close_device(reader->ops_opaque, reader->fd);
    free(reader);
}

uint64_t cdda_reader_length_frames(const struct cdda_reader *reader)
{
    return reader ? reader->total_sectors * CDDA_PCM_FRAMES_PER_SECTOR : 0;
}

uint64_t cdda_reader_position_frames(const struct cdda_reader *reader)
{
    return reader ? reader->cursor_frame : 0;
}

unsigned cdda_reader_track_count(const struct cdda_reader *reader)
{
    return reader ? reader->track_count : 0;
}

static unsigned track_index_for_sector(const struct cdda_reader *reader,
                                       uint64_t sector)
{
    unsigned index;

    if (sector >= reader->total_sectors)
        return reader->track_count - 1u;
    for (index = 0; index + 1u < reader->track_count; ++index) {
        if (sector < reader->tracks[index + 1u].first_sector)
            break;
    }
    return index;
}

unsigned cdda_reader_current_track(const struct cdda_reader *reader)
{
    uint64_t sector;

    if (!reader || !reader->track_count)
        return 0;
    sector = reader->cursor_frame / CDDA_PCM_FRAMES_PER_SECTOR;
    return reader->tracks[track_index_for_sector(reader, sector)].number;
}

int cdda_reader_seek_frame(struct cdda_reader *reader, uint64_t frame)
{
    if (!reader || frame > cdda_reader_length_frames(reader)) {
        errno = EINVAL;
        return -1;
    }
    reader->cursor_frame = frame;
    reader->buffer_valid = 0;
    return 0;
}

uint64_t cdda_reader_track_target(const struct cdda_reader *reader,
                                  int direction)
{
    uint64_t sector;
    uint64_t track_start;
    unsigned index;

    if (!reader || !reader->track_count || (direction != -1 && direction != 1))
        return 0;
    sector = reader->cursor_frame / CDDA_PCM_FRAMES_PER_SECTOR;
    index = track_index_for_sector(reader, sector);
    track_start = reader->tracks[index].first_sector *
                  CDDA_PCM_FRAMES_PER_SECTOR;
    if (direction > 0) {
        if (index + 1u < reader->track_count)
            ++index;
        else
            return reader->cursor_frame;
    } else if (reader->cursor_frame <= track_start +
               CDDA_PREVIOUS_RESTART_FRAMES && index) {
        --index;
    }
    return reader->tracks[index].first_sector * CDDA_PCM_FRAMES_PER_SECTOR;
}

static int fill_buffer(struct cdda_reader *reader, uint64_t logical_sector)
{
    struct cdrom_read_audio request;
    struct cdda_track *track;
    uint64_t track_offset;
    uint64_t remaining;
    unsigned index;
    unsigned sectors;
    int result;

    index = track_index_for_sector(reader, logical_sector);
    track = &reader->tracks[index];
    track_offset = logical_sector - track->first_sector;
    remaining = track->sectors - track_offset;
    sectors = remaining < CDDA_READ_SECTORS ? (unsigned)remaining :
                                               CDDA_READ_SECTORS;
    memset(&request, 0, sizeof(request));
    request.addr.lba = track->start_lba + (int)track_offset;
    request.addr_format = CDROM_LBA;
    request.nframes = (int)sectors;
    request.buf = reader->buffer;
    result = reader->ops->ioctl_device(reader->ops_opaque, reader->fd,
                                       CDROMREADAUDIO, &request);
    if (result < 0 && sectors > 1u) {
        request.nframes = 1;
        sectors = 1;
        result = reader->ops->ioctl_device(reader->ops_opaque, reader->fd,
                                           CDROMREADAUDIO, &request);
    }
    if (result >= 0)
        goto filled;
    reader->error = errno ? errno : EIO;
    return -1;

filled:
    reader->buffer_first_sector = logical_sector;
    reader->buffer_sectors = sectors;
    reader->buffer_valid = 1;
    return 0;
}

ssize_t cdda_reader_read_frames(struct cdda_reader *reader, int16_t *stereo,
                                size_t frames)
{
    uint64_t length;
    size_t completed = 0;

    if (!reader || (!stereo && frames)) {
        errno = EINVAL;
        return -1;
    }
    if (reader->error) {
        errno = reader->error;
        return -1;
    }
    length = cdda_reader_length_frames(reader);
    while (completed < frames && reader->cursor_frame < length) {
        uint64_t logical_sector =
            reader->cursor_frame / CDDA_PCM_FRAMES_PER_SECTOR;
        unsigned frame_in_sector =
            (unsigned)(reader->cursor_frame % CDDA_PCM_FRAMES_PER_SECTOR);
        uint64_t buffered_frames;
        uint64_t buffer_offset_frames;
        size_t available;
        size_t wanted;
        size_t frame;

        if (!reader->buffer_valid ||
            logical_sector < reader->buffer_first_sector ||
            logical_sector >= reader->buffer_first_sector +
                              reader->buffer_sectors) {
            if (fill_buffer(reader, logical_sector) < 0)
                return completed ? (ssize_t)completed : -1;
        }
        buffer_offset_frames =
            (logical_sector - reader->buffer_first_sector) *
                CDDA_PCM_FRAMES_PER_SECTOR + frame_in_sector;
        buffered_frames = (uint64_t)reader->buffer_sectors *
                          CDDA_PCM_FRAMES_PER_SECTOR;
        available = (size_t)(buffered_frames - buffer_offset_frames);
        wanted = frames - completed;
        if (wanted > available)
            wanted = available;
        if ((uint64_t)wanted > length - reader->cursor_frame)
            wanted = (size_t)(length - reader->cursor_frame);
        for (frame = 0; frame < wanted; ++frame) {
            size_t byte = (size_t)(buffer_offset_frames + frame) *
                          CDDA_BYTES_PER_PCM_FRAME;
            uint16_t left = (uint16_t)reader->buffer[byte] |
                            (uint16_t)reader->buffer[byte + 1u] << 8;
            uint16_t right = (uint16_t)reader->buffer[byte + 2u] |
                             (uint16_t)reader->buffer[byte + 3u] << 8;

            stereo[(completed + frame) * 2u] = (int16_t)left;
            stereo[(completed + frame) * 2u + 1u] = (int16_t)right;
        }
        reader->cursor_frame += wanted;
        completed += wanted;
    }
    return (ssize_t)completed;
}

int cdda_reader_error(const struct cdda_reader *reader)
{
    return reader ? reader->error : EINVAL;
}
