#!/usr/bin/env bash
# Combine P/B field prediction with field-DCT residual placement and compare
# every reconstructed sample with an independently FFmpeg-checked oracle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/field_motion_field_dct"
mkdir -p "$WORK/obj"

python3 "$ROOT/tools/streams/generate_test_field_motion_field_dct.py" \
    --output "$WORK/field_motion_field_dct.m2v" \
    --oracle-output "$WORK/pixels.hex"
od -An -v -tx1 "$WORK/field_motion_field_dct.m2v" | tr -d ' \n' | \
    fold -w2 > "$WORK/field_motion_field_dct.hex"
mapfile -t sources < <(sed -n \
    's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' \
    "$ROOT/files.qip")

echo "compile : ${#sources[@]} RTL files + testbench"
(cd "$ROOT" && verilator --binary --timing -j 6 \
 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT \
 -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK +incdir+rtl/mpeg2_new \
 --top-module tb_h262_field_motion_field_dct_pixels \
 --Mdir "$WORK/obj" -o field_motion_field_dct \
 tools/streams/tb_h262_field_motion_field_dct_pixels.sv \
 tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") \
 > "$WORK/build.log" 2>&1

len=$(stat -c%s "$WORK/field_motion_field_dct.m2v")
echo "run     : field motion plus field DCT ($len bytes)"
"$WORK/obj/field_motion_field_dct" \
    "+HEX=$WORK/field_motion_field_dct.hex" "+LEN=$len" \
    "+PIXELS=$WORK/pixels.hex" "$@"
