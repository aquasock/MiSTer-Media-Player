#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
MISTER_HOST=${MISTER_HOST:-10.10.0.30}
MISTER_USER=${MISTER_USER:-root}
MISTER_PASS=${MISTER_PASS:-1}
OUTPUT_DIR=/home/vash/MiSTer-Media-Player/.ai/current_results
OUTPUT_NAME=$(basename -- "${1:-mister-screenshot.png}")
OUTPUT="$OUTPUT_DIR/$OUTPUT_NAME"
TELEMETRY="$OUTPUT_DIR/telemetry.txt"
HELPER_LOG="$OUTPUT_DIR/MediaPlayer_ARM.log"

command -v curl >/dev/null || { printf 'curl is required.\n' >&2; exit 1; }
command -v magick >/dev/null || { printf 'ImageMagick is required.\n' >&2; exit 1; }
command -v python3 >/dev/null || { printf 'python3 is required.\n' >&2; exit 1; }

REMOTE_NAME="screenshot_$(date +%s)_$$.png"
REMOTE_PATH="/media/fat/screenshots/$REMOTE_NAME"
TEMP_FILE=$(mktemp /tmp/mister-screenshot.XXXXXX.png)
TELEMETRY_TEMP=$(mktemp /tmp/mister-telemetry.XXXXXX.txt)
HELPER_LOG_TEMP=$(mktemp /tmp/MediaPlayer_ARM.XXXXXX.log)
FTP=(curl -fsS --user "$MISTER_USER:$MISTER_PASS")

trap 'rm -f -- "$TEMP_FILE" "$TELEMETRY_TEMP" "$HELPER_LOG_TEMP"' EXIT

png_complete() {
    [[ -s $1 ]] || return 1
    [[ $(od -An -tx1 -N8 "$1" | tr -d ' \n') == 89504e470d0a1a0a ]] || return 1
    [[ $(tail -c 12 "$1" | od -An -tx1 | tr -d ' \n') == \
        0000000049454e44ae426082 ]]
}

# Capture the MiSTer screen.
printf 'screenshot scaled %s\n' "$REMOTE_NAME" | \
    "${FTP[@]}" --upload-file - "ftp://$MISTER_HOST//dev/MiSTer_cmd"

# Transfer the screenshot to the host.
downloaded=0
for _ in {1..50}; do
    if "${FTP[@]}" --output "$TEMP_FILE" \
        "ftp://$MISTER_HOST/$REMOTE_PATH" 2>/dev/null && \
        png_complete "$TEMP_FILE"; then
        downloaded=1
        break
    fi
    sleep 0.1
done

(( downloaded )) || {
    printf 'Screenshot capture failed.\n' >&2
    exit 1
}

# Delete the original screenshot from the MiSTer.
"${FTP[@]}" --quote "DELE $REMOTE_PATH" "ftp://$MISTER_HOST/" >/dev/null

# Save it at the display's 1920x1080 resolution.
mkdir -p -- "$OUTPUT_DIR"
magick "$TEMP_FILE" -resize '1920x1080!' "$OUTPUT"
printf 'Saved %s\n' "$OUTPUT"

# Copy the helper log to the Raspberry Pi. The original remains on the MiSTer.
"${FTP[@]}" --output "$HELPER_LOG_TEMP" \
    "ftp://$MISTER_HOST//tmp/MediaPlayer_ARM.log"
mv -f -- "$HELPER_LOG_TEMP" "$HELPER_LOG"
printf 'Saved %s\n' "$HELPER_LOG"

# Decode the machine-readable telemetry with OpenCV.
decode_status=0
PYTHONDONTWRITEBYTECODE=1 python3 \
    "$SCRIPT_DIR/decode-hardware-telemetry.py" \
    "$OUTPUT" --word-dump >"$TELEMETRY_TEMP" 2>&1 || decode_status=$?

mv -f -- "$TELEMETRY_TEMP" "$TELEMETRY"
(( decode_status == 0 )) || {
    printf 'Telemetry could not be decoded; details saved to %s\n' "$TELEMETRY" >&2
    exit 1
}
printf 'Saved %s\n' "$TELEMETRY"
