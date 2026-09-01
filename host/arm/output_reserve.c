#define _POSIX_C_SOURCE 200809L

#include "output_reserve.h"

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define OUTPUT_RESERVE_WRITE_CHUNK (64u * 1024u)

struct output_reserve {
    int fd;
    uint8_t *data;
    size_t capacity;
    size_t head;
    size_t count;
    int stopping;
    int failed;
    int failure_errno;
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t readable;
    pthread_cond_t writable;
};

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
        size_t chunk;
        size_t written = 0;

        pthread_mutex_lock(&reserve->mutex);
        while (!reserve->count && !reserve->stopping && !reserve->failed)
            pthread_cond_wait(&reserve->readable, &reserve->mutex);
        if (reserve->failed || (!reserve->count && reserve->stopping)) {
            pthread_mutex_unlock(&reserve->mutex);
            break;
        }
        chunk = reserve->capacity - reserve->head;
        if (chunk > reserve->count)
            chunk = reserve->count;
        if (chunk > OUTPUT_RESERVE_WRITE_CHUNK)
            chunk = OUTPUT_RESERVE_WRITE_CHUNK;
        pthread_mutex_unlock(&reserve->mutex);

        while (written < chunk) {
            ssize_t result = write(reserve->fd,
                                   reserve->data + reserve->head + written,
                                   chunk - written);

            if (result > 0) {
                written += (size_t)result;
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
        reserve->head = (reserve->head + chunk) % reserve->capacity;
        reserve->count -= chunk;
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
    reserve->data = malloc(capacity);
    if (!reserve->data) {
        free(reserve);
        return -1;
    }
    reserve->fd = fd;
    reserve->capacity = capacity;
    result = pthread_mutex_init(&reserve->mutex, NULL);
    if (result) {
        errno = result;
        free(reserve->data);
        free(reserve);
        return -1;
    }
    result = pthread_cond_init(&reserve->readable, NULL);
    if (result) {
        errno = result;
        pthread_mutex_destroy(&reserve->mutex);
        free(reserve->data);
        free(reserve);
        return -1;
    }
    result = pthread_cond_init(&reserve->writable, NULL);
    if (result) {
        errno = result;
        pthread_cond_destroy(&reserve->readable);
        pthread_mutex_destroy(&reserve->mutex);
        free(reserve->data);
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
        free(reserve->data);
        free(reserve);
        return -1;
    }
    *reserve_out = reserve;
    return 0;
}

int output_reserve_write(struct output_reserve *reserve, const void *data,
                         size_t size)
{
    const uint8_t *source = data;
    size_t offset = 0;

    if (!reserve || (!data && size)) {
        errno = EINVAL;
        return -1;
    }
    while (offset < size) {
        size_t tail;
        size_t space;
        size_t chunk;

        pthread_mutex_lock(&reserve->mutex);
        while (reserve->count == reserve->capacity && !reserve->failed)
            pthread_cond_wait(&reserve->writable, &reserve->mutex);
        if (reserve->failed) {
            errno = reserve->failure_errno;
            pthread_mutex_unlock(&reserve->mutex);
            return -1;
        }
        tail = (reserve->head + reserve->count) % reserve->capacity;
        space = reserve->capacity - reserve->count;
        chunk = reserve->capacity - tail;
        if (chunk > space)
            chunk = space;
        if (chunk > size - offset)
            chunk = size - offset;
        memcpy(reserve->data + tail, source + offset, chunk);
        reserve->count += chunk;
        offset += chunk;
        pthread_cond_signal(&reserve->readable);
        pthread_mutex_unlock(&reserve->mutex);
    }
    return 0;
}

int output_reserve_drain(struct output_reserve *reserve)
{
    if (!reserve) {
        errno = EINVAL;
        return -1;
    }
    pthread_mutex_lock(&reserve->mutex);
    while (reserve->count && !reserve->failed)
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
    free(reserve->data);
    free(reserve);
    if (result)
        errno = saved_errno;
    return result;
}

size_t output_reserve_capacity(const struct output_reserve *reserve)
{
    return reserve ? reserve->capacity : 0;
}
