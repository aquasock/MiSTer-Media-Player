CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11
CPPFLAGS ?=
LDFLAGS ?=
DEPS_DIR ?= .deps
OUTPUT ?= media_player_helper
SOURCES := media_player_helper.c media_source.c

.PHONY: all clean

all: $(OUTPUT)

$(OUTPUT): $(SOURCES) media_source.h media_player_protocol.h $(DEPS_DIR)/minimp3.h
	$(CC) $(CPPFLAGS) -I$(DEPS_DIR) $(CFLAGS) $(SOURCES) $(LDFLAGS) -o $@

clean:
	rm -f $(OUTPUT)
