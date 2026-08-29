#!/usr/bin/env bash
# Entry 707: reconstruct an interlaced I/P/B stream whose P and B pictures use
# frame prediction plus field-DCT residual macroblocks, then compare every
# output sample against an oracle independently cross-checked with FFmpeg.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/interlaced_field_dct_residual"
mkdir -p "$WORK/obj"

python3 "$ROOT/tools/streams/generate_test_interlaced_field_dct_residual.py" \
    --output "$WORK/field_dct_residual.m2v" \
    --oracle-output "$WORK/pixels.hex"
od -An -v -tx1 "$WORK/field_dct_residual.m2v" | tr -d ' \n' | \
    fold -w2 > "$WORK/field_dct_residual.hex"

mapfile -t sources < <(sed -n \
    's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' \
    "$ROOT/files.qip")

echo "compile : ${#sources[@]} RTL files + testbench"
(cd "$ROOT" && verilator --binary --timing -j 6 \
 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT \
 -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new \
 --top-module tb_h262_interlaced_field_dct_residual_pixels \
 --Mdir "$WORK/obj" -o field_dct_residual \
 tools/streams/tb_h262_interlaced_field_dct_residual_pixels.sv \
 tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") \
 > "$WORK/build.log" 2>&1

len=$(stat -c%s "$WORK/field_dct_residual.m2v")
echo "run     : interlaced P/B field DCT residual ($len bytes)"
"$WORK/obj/field_dct_residual" \
    "+HEX=$WORK/field_dct_residual.hex" "+LEN=$len" \
    "+PIXELS=$WORK/pixels.hex" "$@"
