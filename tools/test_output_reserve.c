#define _POSIX_C_SOURCE 200809L

#include "../host/arm/output_reserve.h"

#include <errno.h>
#include <pthread.h>
#include <sched.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#define TEST_SEGMENT_BYTES (2u * 1024u * 1024u)
#define TEST_BYTES (3u * TEST_SEGMENT_BYTES)
#define PRIORITY_BYTES 49u
#define EXPECTED_BYTES (TEST_BYTES + PRIORITY_BYTES)
#define RESERVE_BYTES (4u * 1024u * 1024u)
#define DISCARD_ACTIVE_BYTES (2u * 1024u * 1024u)
#define DISCARD_NORMAL_BYTES (1024u * 1024u)
#define DISCARD_PRIORITY_BYTES 71u
#define DISCARD_FRESH_BYTES (96u * 1024u + 17u)

struct reader_state {
    int fd;
    uint8_t *data;
    size_t size;
    unsigned delay_us;
    int failed;
};

static void timed_out(int signal_number);

static void *reader_thread(void *opaque)
{
    struct reader_state *reader = opaque;
    size_t offset = 0;

    if (reader->delay_us) {
        struct timespec delay = {
            reader->delay_us / 1000000u,
            (long)(reader->delay_us % 1000000u) * 1000l
        };

        while (nanosleep(&delay, &delay) < 0 && errno == EINTR)
            ;
    }

    while (offset < reader->size) {
        ssize_t count = read(reader->fd, reader->data + offset,
                             reader->size - offset);

        if (count > 0) {
            offset += (size_t)count;
            continue;
        }
        if (count < 0 && errno == EINTR)
            continue;
        reader->failed = 1;
        break;
    }
    return NULL;
}

static int test_discard(void)
{
    struct output_reserve *reserve = NULL;
    struct reader_state reader = {0};
    pthread_t thread;
    uint8_t *active = NULL;
    uint8_t *stale_normal = NULL;
    uint8_t stale_priority[DISCARD_PRIORITY_BYTES];
    uint8_t *fresh = NULL;
    uint8_t *expected = NULL;
    int descriptors[2] = {-1, -1};
    int pipe_created = 0;
    int available = 0;
    size_t discarded = 0;
    size_t expected_size = DISCARD_ACTIVE_BYTES + DISCARD_FRESH_BYTES;
    size_t i;
    int failed = 0;

    active = malloc(DISCARD_ACTIVE_BYTES);
    stale_normal = malloc(DISCARD_NORMAL_BYTES);
    fresh = malloc(DISCARD_FRESH_BYTES);
    expected = malloc(expected_size);
    reader.data = malloc(expected_size);
    if (!active || !stale_normal || !fresh || !expected || !reader.data) {
        fprintf(stderr, "output reserve discard: setup failed\n");
        failed = 1;
        goto done;
    }
    if (pipe(descriptors) < 0) {
        fprintf(stderr, "output reserve discard: pipe failed: %s\n",
                strerror(errno));
        failed = 1;
        goto done;
    }
    pipe_created = 1;
    for (i = 0; i < DISCARD_ACTIVE_BYTES; ++i)
        active[i] = (uint8_t)(0x31u ^ i ^ (i >> 11));
    for (i = 0; i < DISCARD_NORMAL_BYTES; ++i)
        stale_normal[i] = (uint8_t)(0x72u ^ i ^ (i >> 9));
    for (i = 0; i < sizeof(stale_priority); ++i)
        stale_priority[i] = (uint8_t)(0xa0u + i);
    for (i = 0; i < DISCARD_FRESH_BYTES; ++i)
        fresh[i] = (uint8_t)(0xc5u ^ i ^ (i >> 7));
    memcpy(expected, active, DISCARD_ACTIVE_BYTES);
    memcpy(expected + DISCARD_ACTIVE_BYTES, fresh, DISCARD_FRESH_BYTES);

    reader.fd = descriptors[0];
    reader.size = expected_size;
    reader.delay_us = 20000u;
    if (output_reserve_create(&reserve, descriptors[1], RESERVE_BYTES) < 0 ||
        output_reserve_write(reserve, active, DISCARD_ACTIVE_BYTES) < 0) {
        fprintf(stderr, "output reserve discard: enqueue failed: %s\n",
                strerror(errno));
        failed = 1;
        goto done;
    }
    while (!available) {
        if (ioctl(descriptors[0], FIONREAD, &available) < 0) {
            fprintf(stderr, "output reserve discard: pipe query failed: %s\n",
                    strerror(errno));
            failed = 1;
            goto done;
        }
        sched_yield();
    }
    if (output_reserve_write(reserve, stale_normal,
                             DISCARD_NORMAL_BYTES) < 0 ||
        output_reserve_write_priority(reserve, stale_priority,
                                      sizeof(stale_priority)) < 0 ||
        pthread_create(&thread, NULL, reader_thread, &reader)) {
        fprintf(stderr, "output reserve discard: stale setup failed\n");
        failed = 1;
        goto done;
    }
    signal(SIGALRM, timed_out);
    alarm(5);
    if (output_reserve_discard(reserve, &discarded) < 0 ||
        discarded != DISCARD_NORMAL_BYTES + sizeof(stale_priority) ||
        output_reserve_write(reserve, fresh, DISCARD_FRESH_BYTES) < 0 ||
        output_reserve_destroy(reserve) < 0) {
        fprintf(stderr,
                "output reserve discard: boundary failed discarded=%zu "
                "expected=%zu error=%s\n",
                discarded, DISCARD_NORMAL_BYTES + sizeof(stale_priority),
                strerror(errno));
        reserve = NULL;
        failed = 1;
    } else {
        reserve = NULL;
    }
    alarm(0);
    close(descriptors[1]);
    descriptors[1] = -1;
    pthread_join(thread, NULL);
    if (reader.failed || memcmp(expected, reader.data, expected_size)) {
        fprintf(stderr,
                "output reserve discard: active or fresh bytes changed\n");
        failed = 1;
    }

done:
    if (reserve)
        (void)output_reserve_destroy(reserve);
    if (pipe_created) {
        if (descriptors[1] >= 0)
            close(descriptors[1]);
        close(descriptors[0]);
    }
    free(reader.data);
    free(expected);
    free(fresh);
    free(stale_normal);
    free(active);
    return failed ? -1 : 0;
}

static void timed_out(int signal_number)
{
    static const char message[] =
        "output reserve: producer blocked behind stalled sink\n";

    (void)signal_number;
    (void)write(STDERR_FILENO, message, sizeof(message) - 1u);
    _exit(2);
}

int main(void)
{
    struct output_reserve *reserve = NULL;
    struct reader_state reader = {0};
    pthread_t thread;
    uint8_t *source;
    uint8_t *expected;
    uint8_t priority[PRIORITY_BYTES];
    int descriptors[2];
    int available = 0;
    size_t i;
    int failed = 0;

    source = malloc(TEST_BYTES);
    expected = malloc(EXPECTED_BYTES);
    reader.data = malloc(EXPECTED_BYTES);
    if (!source || !expected || !reader.data || pipe(descriptors) < 0) {
        fprintf(stderr, "output reserve: setup failed\n");
        return 1;
    }
    for (i = 0; i < TEST_BYTES; ++i)
        source[i] = (uint8_t)(i ^ (i >> 8) ^ (i >> 16));
    for (i = 0; i < PRIORITY_BYTES; ++i)
        priority[i] = (uint8_t)(0xd0u + (i % 29u));
    memcpy(expected, source, TEST_SEGMENT_BYTES);
    memcpy(expected + TEST_SEGMENT_BYTES, priority, sizeof(priority));
    memcpy(expected + TEST_SEGMENT_BYTES + sizeof(priority),
           source + TEST_SEGMENT_BYTES, TEST_BYTES - TEST_SEGMENT_BYTES);
    reader.fd = descriptors[0];
    reader.size = EXPECTED_BYTES;
    if (output_reserve_create(&reserve, descriptors[1], RESERVE_BYTES) < 0) {
        fprintf(stderr, "output reserve: create failed: %s\n", strerror(errno));
        return 1;
    }
    if (output_reserve_capacity(reserve) != RESERVE_BYTES ||
        output_reserve_priority_capacity(reserve) < PRIORITY_BYTES) {
        fprintf(stderr, "output reserve: reported capacity is invalid\n");
        return 1;
    }
    signal(SIGALRM, timed_out);
    alarm(5);
    if (output_reserve_write(reserve, source, TEST_SEGMENT_BYTES) < 0) {
        fprintf(stderr, "output reserve: enqueue failed: %s\n", strerror(errno));
        return 1;
    }
    while (!available) {
        if (ioctl(descriptors[0], FIONREAD, &available) < 0) {
            fprintf(stderr, "output reserve: pipe query failed: %s\n",
                    strerror(errno));
            return 1;
        }
        sched_yield();
    }
    if ((size_t)available >= TEST_SEGMENT_BYTES) {
        fprintf(stderr, "output reserve: test pipe held an entire record\n");
        return 1;
    }
    if (output_reserve_write_priority(reserve, priority,
                                      sizeof(priority)) < 0 ||
        output_reserve_write(reserve, source + TEST_SEGMENT_BYTES,
                             TEST_SEGMENT_BYTES) < 0) {
        fprintf(stderr, "output reserve: priority enqueue failed: %s\n",
                strerror(errno));
        return 1;
    }
    alarm(0);
    if (pthread_create(&thread, NULL, reader_thread, &reader)) {
        fprintf(stderr, "output reserve: reader thread failed\n");
        return 1;
    }
    if (output_reserve_drain(reserve) < 0 ||
        output_reserve_write(reserve, source + 2u * TEST_SEGMENT_BYTES,
                             TEST_SEGMENT_BYTES) < 0) {
        fprintf(stderr, "output reserve: repeated drain failed: %s\n",
                strerror(errno));
        return 1;
    }
    if (output_reserve_destroy(reserve) < 0) {
        fprintf(stderr, "output reserve: drain failed: %s\n", strerror(errno));
        failed = 1;
    }
    close(descriptors[1]);
    pthread_join(thread, NULL);
    close(descriptors[0]);
    if (reader.failed || memcmp(expected, reader.data, EXPECTED_BYTES)) {
        fprintf(stderr, "output reserve: priority or drained bytes changed\n");
        failed = 1;
    }
    free(reader.data);
    free(expected);
    free(source);
    if (failed)
        return 1;
    if (test_discard() < 0)
        return 1;
    puts("output reserve: stalled sink, priority, drain and discard pass");
    return 0;
}
