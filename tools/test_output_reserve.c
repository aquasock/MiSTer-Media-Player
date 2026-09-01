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
#include <unistd.h>

#define TEST_SEGMENT_BYTES (2u * 1024u * 1024u)
#define TEST_BYTES (3u * TEST_SEGMENT_BYTES)
#define PRIORITY_BYTES 49u
#define EXPECTED_BYTES (TEST_BYTES + PRIORITY_BYTES)
#define RESERVE_BYTES (4u * 1024u * 1024u)

struct reader_state {
    int fd;
    uint8_t *data;
    size_t size;
    int failed;
};

static void *reader_thread(void *opaque)
{
    struct reader_state *reader = opaque;
    size_t offset = 0;

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
    puts("output reserve: stalled sink, record priority and exact drain pass");
    return 0;
}
