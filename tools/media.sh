#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage:
  tools/media.sh probe INPUT
  tools/media.sh verify INPUT
  tools/media.sh clip INPUT OUTPUT [SECONDS] [START]
  tools/media.sh convert INPUT OUTPUT [SECONDS] [START]
  tools/media.sh test-pattern OUTPUT [SECONDS]

clip stream-copies the first video and audio tracks. convert produces a
720x480 progressive MPEG-2 Program Stream with 48 kHz stereo AC-3 audio.
SECONDS defaults to 900 (15 minutes), and START defaults to zero.
EOF
    exit 2
}

require() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'media.sh: required command not found: %s\n' "$1" >&2
        exit 1
    }
}

case ${1:-} in
    probe)
        [[ $# -eq 2 ]] || usage
        require ffprobe
        ffprobe -hide_banner "$2"
        ;;
    verify)
        [[ $# -eq 2 ]] || usage
        require ffmpeg
        ffmpeg -hide_banner -v error -xerror -i "$2" -map 0:v:0 -f null -
        ;;
    clip)
        [[ $# -ge 3 && $# -le 5 ]] || usage
        require ffmpeg
        seconds=${4:-900}
        start=${5:-0}
        ffmpeg -hide_banner -v warning -y -ss "$start" -i "$2" -t "$seconds" \
            -map 0:v:0 -map '0:a:0?' -c copy -f vob "$3"
        ;;
    convert)
        [[ $# -ge 3 && $# -le 5 ]] || usage
        require ffmpeg
        seconds=${4:-900}
        start=${5:-0}
        ffmpeg -hide_banner -v warning -y -ss "$start" -i "$2" -t "$seconds" \
            -map 0:v:0 -map '0:a:0?' \
            -vf 'scale=720:480:force_original_aspect_ratio=decrease,pad=720:480:(ow-iw)/2:(oh-ih)/2' \
            -c:v mpeg2video -pix_fmt yuv420p -r 30000/1001 -g 15 -bf 2 \
            -b:v 6000k -maxrate 8000k -bufsize 1835008 \
            -c:a ac3 -ar 48000 -ac 2 -b:a 192k -f vob "$3"
        ;;
    test-pattern)
        [[ $# -ge 2 && $# -le 3 ]] || usage
        require ffmpeg
        seconds=${3:-15}
        ffmpeg -hide_banner -v warning -y \
            -f lavfi -i "testsrc2=size=720x480:rate=30000/1001:duration=$seconds" \
            -f lavfi -i "sine=frequency=440:sample_rate=48000:duration=$seconds" \
            -c:v mpeg2video -pix_fmt yuv420p -g 15 -bf 2 \
            -b:v 6000k -maxrate 8000k -bufsize 1835008 \
            -c:a ac3 -ar 48000 -ac 2 -b:a 192k -shortest -f vob "$2"
        ;;
    *) usage ;;
esac
