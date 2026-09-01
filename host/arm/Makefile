CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -Werror -std=c11
CPPFLAGS ?=
LDFLAGS ?=
DEPS_DIR ?= .deps
A52_DIR ?= $(DEPS_DIR)/liba52
DVD_PREFIX ?= $(DEPS_DIR)/dvd-install-native
OUTPUT ?= media_player_helper
SOURCES := media_player_helper.c media_source.c dvd_random_access.c dvd_spu.c \
	output_reserve.c output_stage.c
HEADERS := media_source.h media_player_protocol.h consumer_audio.h \
	ac3_resync.h dvd_random_access.h dvd_spu.h output_reserve.h output_stage.h \
	$(DEPS_DIR)/minimp3.h $(DEPS_DIR)/miniaudio.h \
	$(DEPS_DIR)/stb_vorbis.c
DVDNAV_LIBRARY := $(DVD_PREFIX)/lib/libdvdnav.a
DVDREAD_LIBRARY := $(DVD_PREFIX)/lib/libdvdread.a
DVDCSS_LIBRARY := $(DVD_PREFIX)/lib/libdvdcss.a
CONSUMER_OBJDIR := $(DEPS_DIR)/consumer-obj-$(notdir $(CC))
CONSUMER_OBJECT := $(CONSUMER_OBJDIR)/consumer_audio.o
CONSUMER_CFLAGS ?= -O2 -Wall -Wextra -std=c11 -Wno-unused-function

# Vendored liba52 0.7.4 is unmodified upstream and predates these warnings, so
# it is compiled as its own objects without the helper's -Werror rather than
# being patched.  Keep the sources pristine and change this recipe instead.
A52_SOURCES := bit_allocate.c bitstream.c downmix.c imdct.c parse.c
# Objects are kept per compiler: a native build and a cross build share this
# dependency directory, and mixing their objects fails the link confusingly.
A52_OBJDIR := $(A52_DIR)/obj-$(notdir $(CC))
A52_OBJECTS := $(addprefix $(A52_OBJDIR)/,$(A52_SOURCES:.c=.o))
A52_CFLAGS ?= -O2 -std=gnu99 -w

.PHONY: all clean

all: $(OUTPUT)

$(A52_OBJDIR)/%.o: $(A52_DIR)/%.c
	@mkdir -p $(A52_OBJDIR)
	$(CC) $(CPPFLAGS) -I$(A52_DIR) $(A52_CFLAGS) -c $< -o $@

$(CONSUMER_OBJECT): consumer_audio.c consumer_audio.h media_source.h \
		$(DEPS_DIR)/miniaudio.h $(DEPS_DIR)/stb_vorbis.c
	@mkdir -p $(CONSUMER_OBJDIR)
	$(CC) $(CPPFLAGS) -I$(DEPS_DIR) $(CONSUMER_CFLAGS) -c $< -o $@

$(OUTPUT): $(SOURCES) $(HEADERS) $(A52_OBJECTS) $(CONSUMER_OBJECT) \
		$(DVDNAV_LIBRARY) $(DVDREAD_LIBRARY) $(DVDCSS_LIBRARY)
	$(CC) $(CPPFLAGS) -I$(DEPS_DIR) -I$(A52_DIR) -I$(DVD_PREFIX)/include \
		$(CFLAGS) $(SOURCES) $(A52_OBJECTS) $(CONSUMER_OBJECT) \
		$(DVDNAV_LIBRARY) $(DVDREAD_LIBRARY) $(DVDCSS_LIBRARY) \
		$(LDFLAGS) -lpthread -lm -o $@

clean:
	rm -f $(OUTPUT)
	rm -rf $(A52_DIR)/obj-*
	rm -rf $(DEPS_DIR)/consumer-obj-*
