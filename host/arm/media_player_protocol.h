#ifndef MEDIA_PLAYER_PROTOCOL_H
#define MEDIA_PLAYER_PROTOCOL_H

#define MEDIA_PLAYER_PROTOCOL_VERSION 1
#define MEDIA_PLAYER_FILE_PREFIX "file:"
#define MEDIA_PLAYER_DVD_PREFIX "dvd:"
#define MEDIA_PLAYER_ISO_PREFIX "iso:"

#define MEDIA_PLAYER_PTS_MARKER_CODE 0xb0
#define MEDIA_PLAYER_PCM_MARKER_CODE 0xb1
#define MEDIA_PLAYER_PCM_END_MARKER_CODE 0xb6
#define MEDIA_PLAYER_PCM_MODE_STEREO 0x01
#define MEDIA_PLAYER_PCM_MODE_48K 0x02
#define MEDIA_PLAYER_PCM_MODE_NON_AUDIO 0x80
#define MEDIA_PLAYER_PCM_MODE_48K_STEREO \
    (MEDIA_PLAYER_PCM_MODE_48K | MEDIA_PLAYER_PCM_MODE_STEREO)

#define MEDIA_PLAYER_CAPABILITIES \
    "protocol=1 sources=file,iso,dvd " \
    "containers=m2v,mpeg-ps,mp3,wav,flac video=h262 " \
    "audio=mp2-s16le-44100,mp2-s16le-48000," \
    "mp3-s16le-44100,mp3-s16le-48000,wav-s16le-stereo-44100,wav-s16le-stereo-48000," \
    "flac-s16le-stereo-44100,flac-s16le-stereo-48000 " \
    "transport=inband-pcm-v1"

#endif
