#!/usr/bin/env bash
# Entry 550: replay the interlaced P fixture through the complete decoder and
# compare every reconstructed sample against an FFmpeg decode of the same
# stream.
#
# UNVALIDATED.  Do not trust results from this script yet.  A raw FFmpeg
# yuv420p decode is not the oracle format MIXED_PIXEL_MODE expects: running the
# known-good 128x96 progressive fixture through the same path mismatches on
# 64.7 per cent of samples with a max delta of 251, while the very same run
# reports the decoder healthy (25 pictures, 25 promotions, 71 swaps, no
# errors).  Until that progressive control passes, any figure this produces
# says more about the oracle than about reconstruction.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/interlaced_p"
GENERATED="$ROOT/tools/streams/generated_interlaced"
TB="$ROOT/tools/streams/tb_h262_interlaced_p_pixels.sv"
SOAK="$ROOT/tools/streams/tb_h262_live_raster_soak.sv"
mkdir -p "$WORK"

python3 "$ROOT/tools/streams/generate_test_interlaced_p_frames.py"

stream="$GENERATED/test_interlaced_p_tff.m2v"
hex="$WORK/interlaced_p.hex"
oracle_raw="$WORK/interlaced_p.yuv"
oracle_hex="$WORK/interlaced_p_pixels.hex"

xxd -c1 -p "$stream" > "$hex"
ffmpeg -hide_banner -loglevel error -y -threads 1 -i "$stream" \
    -frames:v 8 -an -f rawvideo -pix_fmt yuv420p "$oracle_raw"
xxd -c1 -p "$oracle_raw" > "$oracle_hex"

mapfile -t sources < <(
    grep -oP '(?<=-name SYSTEMVERILOG_FILE )rtl/mpeg2_new/\S+' "$ROOT/files.qip"
)

echo "compile : ${#sources[@]} RTL files + testbench"
( cd "$ROOT" && iverilog -g2012 -gsupported-assertions -I rtl/mpeg2_new \
    -o "$WORK/interlaced_p.vvp" -s tb_h262_interlaced_p_pixels \
    "$TB" "$SOAK" "${sources[@]}" )

len=$(stat -c%s "$stream")
echo "run     : interlaced P pixels ($len bytes, oracle $(stat -c%s "$oracle_raw") bytes)"
( cd "$WORK" && exec vvp "$WORK/interlaced_p.vvp" \
    "+HEX=$hex" "+LEN=$len" "+PIXELS=$oracle_hex" "$@" )
