#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
HELPER=${1:-$ROOT/host/build/media_player_helper.native}
WORK=$(mktemp -d /tmp/mmp-private-audio.XXXXXX)

cleanup() {
    rm -rf -- "$WORK"
}
trap cleanup EXIT

command -v ffmpeg >/dev/null 2>&1 || {
    printf 'private audio skip: ffmpeg is required\n' >&2
    exit 1
}
[[ -x $HELPER ]] || {
    printf 'private audio skip: helper is not executable: %s\n' "$HELPER" >&2
    exit 1
}

ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f lavfi -i color=c=blue:s=720x480:r=30000/1001:d=0.5 \
    -f lavfi -i sine=frequency=440:sample_rate=48000:duration=0.5 \
    -map_metadata -1 -shortest \
    -c:v mpeg2video -pix_fmt yuv420p -g 15 -b:v 1200k \
    -c:a pcm_s16be -ar 48000 -ac 2 -f vob \
    "$WORK/lpcm.vob" 2>"$WORK/ffmpeg.log"

"$HELPER" --video-out "$WORK/video.m2v" \
    --pcm-out "$WORK/audio.pcm" "$WORK/lpcm.vob" \
    >"$WORK/stdout.bin" 2>"$WORK/helper.log"

grep -q 'skipping unsupported DVD LPCM substream 0xa0' \
    "$WORK/helper.log" || {
    printf 'private audio skip: LPCM diagnostic was not emitted\n' >&2
    exit 1
}
grep -q 'video=[1-9][0-9]* bytes' "$WORK/helper.log" || {
    printf 'private audio skip: helper did not complete video\n' >&2
    exit 1
}
[[ -s $WORK/video.m2v && ! -s $WORK/audio.pcm && ! -s $WORK/stdout.bin ]] || {
    printf 'private audio skip: output routing or silent-audio result is wrong\n' >&2
    exit 1
}

printf 'private audio skip: DVD LPCM is silent and video completes\n'
