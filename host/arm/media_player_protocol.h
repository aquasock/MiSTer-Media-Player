#ifndef MEDIA_PLAYER_PROTOCOL_H
#define MEDIA_PLAYER_PROTOCOL_H

#define MEDIA_PLAYER_PROTOCOL_VERSION 1
#define MEDIA_PLAYER_FILE_PREFIX "file:"
#define MEDIA_PLAYER_DVD_PREFIX "dvd:"

#define MEDIA_PLAYER_CAPABILITIES \
    "protocol=1 sources=file reserved_sources=dvd " \
    "containers=m2v,mpeg-ps video=h262 audio=mp2-s16le-48000"

#endif
