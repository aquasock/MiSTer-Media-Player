#define _POSIX_C_SOURCE 200809L

#include "output_reserve.h"

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OUTPUT_RESERVE_WRITE_CHUNK (64u * 1024u)
#define OUTPUT_RESERVE_PRIORITY_BYTES (256u * 1024u)

/*
 * One bit per queued byte marks the final byte of each producer write.  The
 * writer may split that record into bounded system calls, but it never changes
 * lanes until the complete record reaches the pipe.  An overlay can therefore
 * overtake queued media without landing inside an in-band PCM record.
 */
struct output_ring {
    uint8_t *data;
    uint8_t *record_ends;
    size_t capacity;
    size_t head;
    size_t count;
};

struct output_reserve {
    int fd;
    struct output_ring normal;
    struct output_ring priority;
    int stopping;
    int failed;
    int failure_errno;
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t readable;
    pthread_cond_t writable;
};

static int ring_allocate(struct output_ring *ring, size_t capacity)
{
    size_t record_end_bytes;

    if (capacity > SIZE_MAX - 7u) {
        errno = EOVERFLOW;
        return -1;
    }
    record_end_bytes = (capacity + 7u) / 8u;

    ring->data = malloc(capacity);
    ring->record_ends = calloc(record_end_bytes, 1u);
    if (!ring->data || !ring->record_ends) {
        free(ring->record_ends);
        free(ring->data);
        memset(ring, 0, sizeof(*ring));
        return -1;
    }
    ring->capacity = capacity;
    return 0;
}

static int ring_has_record_end(const struct output_ring *ring, size_t index)
{
    return (ring->record_ends[index >> 3] >> (index & 7u)) & 1u;
}

static void ring_set_record_end(struct output_ring *ring, size_t index)
{
    ring->record_ends[index >> 3] |= (uint8_t)(1u << (index & 7u));
}

static void ring_clear_record_end(struct output_ring *ring, size_t index)
{
    ring->record_ends[index >> 3] &= (uint8_t)~(1u << (index & 7u));
}

static void ring_free(struct output_ring *ring)
{
    free(ring->record_ends);
    free(ring->data);
    memset(ring, 0, sizeof(*ring));
}

static void ring_enqueue(struct output_ring *ring, const uint8_t *data,
                         size_t size)
{
    size_t tail = (ring->head + ring->count) % ring->capacity;
    size_t first = ring->capacity - tail;
    size_t end;

    if (first > size)
        first = size;
    memcpy(ring->data + tail, data, first);
    memcpy(ring->data, data + first, size - first);
    end = (tail + size - 1u) % ring->capacity;
    ring_set_record_end(ring, end);
    ring->count += size;
}

static size_t ring_first_record_size(const struct output_ring *ring)
{
    size_t size;

    for (size = 1; size <= ring->count; ++size) {
        size_t index = (ring->head + size - 1u) % ring->capacity;

        if (ring_has_record_end(ring, index))
            return size;
    }
    return 0;
}

static void ring_remove_record(struct output_ring *ring, size_t size)
{
    size_t end = (ring->head + size - 1u) % ring->capacity;

    ring_clear_record_end(ring, end);
    ring->head = (ring->head + size) % ring->capacity;
    ring->count -= size;
}

static void reserve_fail_locked(struct output_reserve *reserve, int error)
{
    reserve->failed = 1;
    reserve->failure_errno = error ? error : EIO;
    pthread_cond_broadcast(&reserve->readable);
    pthread_cond_broadcast(&reserve->writable);
}

static void *output_reserve_worker(void *opaque)
{
    struct output_reserve *reserve = opaque;

    for (;;) {
        struct output_ring *ring;
        size_t record_size;
        size_t record_written = 0;

        pthread_mutex_lock(&reserve->mutex);
        while (!reserve->normal.count && !reserve->priority.count &&
               !reserve->stopping && !reserve->failed)
            pthread_cond_wait(&reserve->readable, &reserve->mutex);
        if (reserve->failed ||
            (!reserve->normal.count && !reserve->priority.count &&
             reserve->stopping)) {
            pthread_mutex_unlock(&reserve->mutex);
            break;
        }
        /* Priority is reconsidered only at the preceding record boundary. */
        ring = reserve->priority.count ? &reserve->priority : &reserve->normal;
        record_size = ring_first_record_size(ring);
        if (!record_size) {
            reserve_fail_locked(reserve, EPROTO);
            pthread_mutex_unlock(&reserve->mutex);
            break;
        }
        pthread_mutex_unlock(&reserve->mutex);

        while (record_written < record_size) {
            size_t index = (ring->head + record_written) % ring->capacity;
            size_t chunk = ring->capacity - index;
            size_t remaining = record_size - record_written;
            ssize_t result;

            if (chunk > remaining)
                chunk = remaining;
            if (chunk > OUTPUT_RESERVE_WRITE_CHUNK)
                chunk = OUTPUT_RESERVE_WRITE_CHUNK;
            result = write(reserve->fd, ring->data + index, chunk);

            if (result > 0) {
                record_written += (size_t)result;
                continue;
            }
            if (result < 0 && errno == EINTR)
                continue;
            pthread_mutex_lock(&reserve->mutex);
            reserve_fail_locked(reserve, result < 0 ? errno : EIO);
            pthread_mutex_unlock(&reserve->mutex);
            return NULL;
        }

        pthread_mutex_lock(&reserve->mutex);
        ring_remove_record(ring, record_size);
        pthread_cond_broadcast(&reserve->writable);
        pthread_mutex_unlock(&reserve->mutex);
    }
    return NULL;
}

int output_reserve_create(struct output_reserve **reserve_out, int fd,
                          size_t capacity)
{
    struct output_reserve *reserve;
    int result;

    if (!reserve_out || fd < 0 || !capacity) {
        errno = EINVAL;
        return -1;
    }
    *reserve_out = NULL;
    reserve = calloc(1, sizeof(*reserve));
    if (!reserve)
        return -1;
    if (ring_allocate(&reserve->normal, capacity) < 0 ||
        ring_allocate(&reserve->priority, OUTPUT_RESERVE_PRIORITY_BYTES) < 0) {
        ring_free(&reserve->priority);
        ring_free(&reserve->normal);
        free(reserve);
        return -1;
    }
    reserve->fd = fd;
    result = pthread_mutex_init(&reserve->mutex, NULL);
    if (result) {
        errno = result;
        ring_free(&reserve->priority);
        ring_free(&reserve->normal);
        free(reserve);
        return -1;
    }
    result = pthread_cond_init(&reserve->readable, NULL);
    if (result) {
        errno = result;
        pthread_mutex_destroy(&reserve->mutex);
        ring_free(&reserve->priority);
        ring_free(&reserve->normal);
        free(reserve);
        return -1;
    }
    result = pthread_cond_init(&reserve->writable, NULL);
    if (result) {
        errno = result;
        pthread_cond_destroy(&reserve->readable);
        pthread_mutex_destroy(&reserve->mutex);
        ring_free(&reserve->priority);
        ring_free(&reserve->normal);
        free(reserve);
        return -1;
    }
    result = pthread_create(&reserve->thread, NULL,
                            output_reserve_worker, reserve);
    if (result) {
        errno = result;
        pthread_cond_destroy(&reserve->writable);
        pthread_cond_destroy(&reserve->readable);
        pthread_mutex_destroy(&reserve->mutex);
        ring_free(&reserve->priority);
        ring_free(&reserve->normal);
        free(reserve);
        return -1;
    }
    *reserve_out = reserve;
    return 0;
}

static int output_reserve_write_ring(struct output_reserve *reserve,
                                     struct output_ring *ring,
                                     const void *data, size_t size)
{
    if (!reserve || (!data && size)) {
        errno = EINVAL;
        return -1;
    }
    if (!size)
        return 0;
    if (size > ring->capacity) {
        errno = EMSGSIZE;
        return -1;
    }
    pthread_mutex_lock(&reserve->mutex);
    while (ring->capacity - ring->count < size && !reserve->failed &&
           !reserve->stopping)
        pthread_cond_wait(&reserve->writable, &reserve->mutex);
    if (reserve->failed || reserve->stopping) {
        errno = reserve->failed ? reserve->failure_errno : EPIPE;
        pthread_mutex_unlock(&reserve->mutex);
        return -1;
    }
    ring_enqueue(ring, data, size);
    pthread_cond_signal(&reserve->readable);
    pthread_mutex_unlock(&reserve->mutex);
    return 0;
}

int output_reserve_write(struct output_reserve *reserve, const void *data,
                         size_t size)
{
    return output_reserve_write_ring(reserve,
                                     reserve ? &reserve->normal : NULL,
                                     data, size);
}

int output_reserve_write_priority(struct output_reserve *reserve,
                                  const void *data, size_t size)
{
    return output_reserve_write_ring(reserve,
                                     reserve ? &reserve->priority : NULL,
                                     data, size);
}

int output_reserve_drain(struct output_reserve *reserve)
{
    if (!reserve) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&reserve->mutex);
    while ((reserve->normal.count || reserve->priority.count) &&
           !reserve->failed)
        pthread_cond_wait(&reserve->writable, &reserve->mutex);
    if (reserve->failed) {
        errno = reserve->failure_errno;
        pthread_mutex_unlock(&reserve->mutex);
        return -1;
    }
    pthread_mutex_unlock(&reserve->mutex);
    return 0;
}

int output_reserve_destroy(struct output_reserve *reserve)
{
    int result = 0;
    int saved_errno = 0;

    if (!reserve)
        return 0;
    if (output_reserve_drain(reserve) < 0) {
        result = -1;
        saved_errno = errno;
    }
    pthread_mutex_lock(&reserve->mutex);
    reserve->stopping = 1;
    pthread_cond_broadcast(&reserve->readable);
    pthread_cond_broadcast(&reserve->writable);
    pthread_mutex_unlock(&reserve->mutex);
    if (pthread_join(reserve->thread, NULL) && !result) {
        result = -1;
        saved_errno = EIO;
    }
    pthread_cond_destroy(&reserve->writable);
    pthread_cond_destroy(&reserve->readable);
    pthread_mutex_destroy(&reserve->mutex);
    ring_free(&reserve->priority);
    ring_free(&reserve->normal);
    free(reserve);
    if (result)
        errno = saved_errno;
    return result;
}

size_t output_reserve_capacity(const struct output_reserve *reserve)
{
    return reserve ? reserve->normal.capacity : 0;
}

size_t output_reserve_priority_capacity(const struct output_reserve *reserve)
{
    return reserve ? reserve->priority.capacity : 0;
}
