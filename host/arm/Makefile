CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11
CPPFLAGS ?=
LDFLAGS ?=
DEPS_DIR ?= .deps
OUTPUT ?= media_player_helper

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): media_player_helper.c $(DEPS_DIR)/minimp3.h
	$(CC) $(CPPFLAGS) -I$(DEPS_DIR) $(CFLAGS) $< $(LDFLAGS) -o $@

clean:
	rm -f $(OUTPUT)
