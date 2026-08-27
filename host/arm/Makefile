CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11
CPPFLAGS ?=
LDFLAGS ?=
DEPS_DIR ?= .deps
A52_DIR ?= $(DEPS_DIR)/liba52
OUTPUT ?= media_player_helper
SOURCES := media_player_helper.c media_source.c
HEADERS := media_source.h media_player_protocol.h $(DEPS_DIR)/minimp3.h

# Vendored liba52 0.7.4 is unmodified upstream and predates these warnings, so
# it is compiled as its own objects without the helper's -Werror rather than
# being patched.  Keep the sources pristine and change this recipe instead.
A52_SOURCES := $(A52_DIR)/bit_allocate.c $(A52_DIR)/bitstream.c \
               $(A52_DIR)/downmix.c $(A52_DIR)/imdct.c $(A52_DIR)/parse.c
A52_OBJECTS := $(A52_SOURCES:.c=.o)
A52_CFLAGS ?= -O2 -std=gnu99 -w

.PHONY: all clean

all: $(OUTPUT)

$(A52_DIR)/%.o: $(A52_DIR)/%.c
	$(CC) $(CPPFLAGS) -I$(A52_DIR) $(A52_CFLAGS) -c $< -o $@

$(OUTPUT): $(SOURCES) $(HEADERS) $(A52_OBJECTS)
	$(CC) $(CPPFLAGS) -I$(DEPS_DIR) -I$(A52_DIR) $(CFLAGS) $(SOURCES) \
		$(A52_OBJECTS) $(LDFLAGS) -lm -o $@

clean:
	rm -f $(OUTPUT) $(A52_OBJECTS)
