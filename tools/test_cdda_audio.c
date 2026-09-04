#define _POSIX_C_SOURCE 200809L

#include "cdda_audio.h"

#include <errno.h>
#include <fcntl.h>
#include <linux/cdrom.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

struct fake_drive {
    int open_calls;
    int close_calls;
    int read_calls;
    int fail_multi_read;
    int fail_all_reads;
    int all_data;
};

static int require(int condition, const char *message)
{
    if (condition)
        return 0;
    fprintf(stderr, "cdda audio: %s\n", message);
    return 1;
}

static int fake_open(void *opaque, const char *path, int flags)
{
    struct fake_drive *drive = opaque;

    drive->open_calls++;
    if (strcmp(path, "/dev/fake") || !(flags & O_NONBLOCK) ||
        !(flags & O_CLOEXEC)) {
        errno = EINVAL;
        return -1;
    }
    return 17;
}

static void fake_sample(uint8_t *output, int lba, unsigned frame)
{
    int16_t left = (int16_t)(lba * 16 + (int)frame);
    int16_t right = (int16_t)-left;

    output[0] = (uint8_t)left;
    output[1] = (uint8_t)((uint16_t)left >> 8);
    output[2] = (uint8_t)right;
    output[3] = (uint8_t)((uint16_t)right >> 8);
}

static int fake_ioctl(void *opaque, int fd, unsigned long request,
                      void *argument)
{
    struct fake_drive *drive = opaque;

    if (fd != 17) {
        errno = EBADF;
        return -1;
    }
    if (request == CDROMREADTOCHDR) {
        struct cdrom_tochdr *header = argument;

        header->cdth_trk0 = 1;
        header->cdth_trk1 = 4;
        return 0;
    }
    if (request == CDROMREADTOCENTRY) {
        struct cdrom_tocentry *entry = argument;

        entry->cdte_ctrl = 0;
        switch (entry->cdte_track) {
        case 1:
            entry->cdte_addr.lba = 0;
            break;
        case 2:
            entry->cdte_addr.lba = 300;
            entry->cdte_ctrl = CDROM_DATA_TRACK;
            break;
        case 3:
            entry->cdte_addr.lba = 600;
            break;
        case 4:
            entry->cdte_addr.lba = 900;
            break;
        case CDROM_LEADOUT:
            entry->cdte_addr.lba = 1200;
            break;
        default:
            errno = EINVAL;
            return -1;
        }
        if (drive->all_data && entry->cdte_track != CDROM_LEADOUT)
            entry->cdte_ctrl = CDROM_DATA_TRACK;
        return 0;
    }
    if (request == CDROMREADAUDIO) {
        struct cdrom_read_audio *read = argument;
        int sector;

        drive->read_calls++;
        if (drive->fail_all_reads ||
            (drive->fail_multi_read && read->nframes > 1)) {
            errno = EIO;
            return -1;
        }
        for (sector = 0; sector < read->nframes; ++sector) {
            unsigned frame;

            for (frame = 0; frame < CDDA_PCM_FRAMES_PER_SECTOR; ++frame) {
                size_t byte = ((size_t)sector *
                               CDDA_PCM_FRAMES_PER_SECTOR + frame) * 4u;

                fake_sample(read->buf + byte, read->addr.lba + sector,
                            frame);
            }
        }
        return 0;
    }
    errno = EINVAL;
    return -1;
}

static int fake_close(void *opaque, int fd)
{
    struct fake_drive *drive = opaque;

    if (fd != 17) {
        errno = EBADF;
        return -1;
    }
    drive->close_calls++;
    return 0;
}

static const struct cdda_device_ops fake_ops = {
    fake_open,
    fake_ioctl,
    fake_close
};

static int test_disc_layout_and_reads(void)
{
    struct fake_drive drive = {.fail_multi_read = 1};
    struct cdda_reader *reader = NULL;
    int16_t pcm[8];
    uint64_t track_three = 300u * CDDA_PCM_FRAMES_PER_SECTOR;
    uint64_t track_four = 600u * CDDA_PCM_FRAMES_PER_SECTOR;
    uint64_t track_start = UINT64_MAX;
    uint64_t track_length = UINT64_MAX;
    char error[160];
    int failed = 0;

    failed |= require(cdda_reader_open_with_ops(
                          &reader, "/dev/fake", &fake_ops, &drive,
                          error, sizeof(error)) == 0,
                      "mixed-mode disc did not open");
    if (!reader)
        return failed | 1;
    failed |= require(cdda_reader_track_count(reader) == 3,
                      "data track was not skipped");
    failed |= require(cdda_reader_track_number(reader, 0) == 1 &&
                          cdda_reader_track_number(reader, 1) == 3 &&
                          cdda_reader_track_number(reader, 2) == 4,
                      "ordered physical audio-track numbers are wrong");
    failed |= require(cdda_reader_track_number(reader, 3) == 0 &&
                          cdda_reader_track_number(NULL, 0) == 0,
                      "invalid track-number query did not return zero");
    failed |= require(cdda_reader_length_frames(reader) ==
                          900u * CDDA_PCM_FRAMES_PER_SECTOR,
                      "concatenated audio duration is wrong");
    failed |= require(cdda_reader_current_track(reader) == 1,
                      "first audio track was not selected");
    failed |= require(cdda_reader_current_track_timing(
                          reader, &track_start, &track_length) == 0 &&
                          track_start == 0 && track_length == track_three,
                      "first audio track timing is wrong");
    failed |= require(cdda_reader_read_frames(reader, pcm, 4) == 4,
                      "initial Audio CD read failed");
    failed |= require(pcm[0] == 0 && pcm[1] == 0 &&
                          pcm[2] == 1 && pcm[3] == -1,
                      "little-endian stereo samples were decoded incorrectly");
    failed |= require(drive.read_calls == 2,
                      "multi-sector failure did not retry one sector");

    failed |= require(cdda_reader_seek_frame(
                          reader, 300u * CDDA_PCM_FRAMES_PER_SECTOR - 2u) == 0,
                      "cannot seek to first track boundary");
    failed |= require(cdda_reader_read_frames(reader, pcm, 4) == 4,
                      "cross-track Audio CD read failed");
    failed |= require(pcm[0] == (int16_t)(299 * 16 + 586) &&
                          pcm[2] == (int16_t)(299 * 16 + 587) &&
                          pcm[4] == (int16_t)(600 * 16) &&
                          pcm[6] == (int16_t)(600 * 16 + 1),
                      "logical audio program did not skip the data track");
    failed |= require(cdda_reader_current_track(reader) == 3,
                      "current track number did not cross the data gap");
    failed |= require(cdda_reader_current_track_timing(
                          reader, &track_start, &track_length) == 0 &&
                          track_start == track_three &&
                          track_length == track_three,
                      "track timing did not cross the data gap");

    failed |= require(cdda_reader_seek_frame(
                          reader, track_three + 4u * CDDA_SAMPLE_RATE_HZ - 1u)
                          == 0,
                      "cannot seek within track three");
    failed |= require(cdda_reader_track_target(reader, -1) == track_three,
                      "previous did not restart a track after three seconds");
    failed |= require(cdda_reader_seek_frame(
                          reader, track_three + CDDA_SAMPLE_RATE_HZ) == 0,
                      "cannot seek near track three start");
    failed |= require(cdda_reader_track_target(reader, -1) == 0,
                      "previous did not select the preceding audio track");
    failed |= require(cdda_reader_track_target(reader, 1) == track_four,
                      "next did not select the following audio track");
    failed |= require(cdda_reader_seek_frame(
                          reader, track_four + CDDA_SAMPLE_RATE_HZ) == 0 &&
                          cdda_reader_track_target(reader, 1) ==
                              track_four + CDDA_SAMPLE_RATE_HZ,
                      "next at the final track did not preserve position");
    failed |= require(cdda_reader_current_track_timing(
                          reader, &track_start, &track_length) == 0 &&
                          track_start == track_four &&
                          track_length == track_three,
                      "final audio track timing is wrong");
    failed |= require(cdda_reader_current_track_timing(
                          NULL, &track_start, &track_length) == -1 &&
                          errno == EINVAL,
                      "invalid track timing query was accepted");

    cdda_reader_close(reader);
    failed |= require(drive.open_calls == 1 && drive.close_calls == 1,
                      "drive lifetime was not balanced");
    return failed;
}

static int test_no_audio_and_read_error(void)
{
    struct fake_drive data_disc = {.all_data = 1};
    struct fake_drive broken_disc = {.fail_all_reads = 1};
    struct cdda_reader *reader = NULL;
    int16_t pcm[2];
    char error[160];
    int failed = 0;

    failed |= require(cdda_reader_open_with_ops(
                          &reader, "/dev/fake", &fake_ops, &data_disc,
                          error, sizeof(error)) < 0 && !reader,
                      "data-only disc was accepted as Audio CD");
    failed |= require(strstr(error, "no Audio CD tracks") != NULL,
                      "data-only failure did not identify the medium");
    failed |= require(data_disc.close_calls == 1,
                      "rejected data disc did not close the drive");

    failed |= require(cdda_reader_open_with_ops(
                          &reader, "/dev/fake", &fake_ops, &broken_disc,
                          error, sizeof(error)) == 0,
                      "read-error fixture did not open");
    if (reader) {
        failed |= require(cdda_reader_read_frames(reader, pcm, 1) < 0 &&
                              cdda_reader_error(reader) == EIO,
                          "single-sector read error was not retained");
        cdda_reader_close(reader);
    }
    return failed;
}

int main(void)
{
    int failed = 0;

    failed |= test_disc_layout_and_reads();
    failed |= test_no_audio_and_read_error();
    if (!failed)
        puts("cdda audio: TOC, mixed-mode, PCM, retry and track controls pass");
    return failed ? 1 : 0;
}
