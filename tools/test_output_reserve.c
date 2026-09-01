#define _POSIX_C_SOURCE 200809L

#include "../host/arm/output_reserve.h"

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TEST_SEGMENT_BYTES (2u * 1024u * 1024u)
#define TEST_BYTES (3u * TEST_SEGMENT_BYTES)
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
    int descriptors[2];
    size_t i;
    int failed = 0;

    source = malloc(TEST_BYTES);
    reader.data = malloc(TEST_BYTES);
    if (!source || !reader.data || pipe(descriptors) < 0) {
        fprintf(stderr, "output reserve: setup failed\n");
        return 1;
    }
    for (i = 0; i < TEST_BYTES; ++i)
        source[i] = (uint8_t)(i ^ (i >> 8) ^ (i >> 16));
    reader.fd = descriptors[0];
    reader.size = TEST_BYTES;
    if (output_reserve_create(&reserve, descriptors[1], RESERVE_BYTES) < 0) {
        fprintf(stderr, "output reserve: create failed: %s\n", strerror(errno));
        return 1;
    }
    signal(SIGALRM, timed_out);
    alarm(5);
    if (output_reserve_write(reserve, source, TEST_SEGMENT_BYTES) < 0) {
        fprintf(stderr, "output reserve: enqueue failed: %s\n", strerror(errno));
        return 1;
    }
    alarm(0);
    if (pthread_create(&thread, NULL, reader_thread, &reader)) {
        fprintf(stderr, "output reserve: reader thread failed\n");
        return 1;
    }
    if (output_reserve_drain(reserve) < 0 ||
        output_reserve_write(reserve, source + TEST_SEGMENT_BYTES,
                             TEST_SEGMENT_BYTES) < 0 ||
        output_reserve_drain(reserve) < 0 ||
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
    if (reader.failed || memcmp(source, reader.data, TEST_BYTES)) {
        fprintf(stderr, "output reserve: drained bytes changed\n");
        failed = 1;
    }
    free(reader.data);
    free(source);
    if (failed)
        return 1;
    puts("output reserve: stalled sink and byte-exact drain pass");
    return 0;
}
