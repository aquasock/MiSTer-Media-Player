#ifndef OUTPUT_RESERVE_H
#define OUTPUT_RESERVE_H

#include <stddef.h>

struct output_reserve;

int output_reserve_create(struct output_reserve **reserve, int fd,
                          size_t capacity);
int output_reserve_write(struct output_reserve *reserve, const void *data,
                         size_t size);
int output_reserve_write_priority(struct output_reserve *reserve,
                                  const void *data, size_t size);
int output_reserve_drain(struct output_reserve *reserve);
int output_reserve_discard(struct output_reserve *reserve,
                           size_t *discarded_bytes);
int output_reserve_destroy(struct output_reserve *reserve);
size_t output_reserve_capacity(const struct output_reserve *reserve);
size_t output_reserve_priority_capacity(const struct output_reserve *reserve);

#endif
