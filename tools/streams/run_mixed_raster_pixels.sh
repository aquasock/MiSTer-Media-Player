#!/usr/bin/env bash
# Preserve the original compact progressive control and its strict counters.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/pixel_control"
mkdir -p "$WORK/obj"
python3 "$ROOT/tools/streams/generate_test_mixed_raster_soak.py" \
 --output "$WORK/control.m2v" --oracle-output "$WORK/pixels.hex"
xxd -c1 -p "$WORK/control.m2v" > "$WORK/control.hex"
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new --top-module tb_h262_mixed_raster_pixels --Mdir "$WORK/obj" -o control \
 tools/streams/tb_h262_mixed_raster_pixels.sv tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/control" "+HEX=$WORK/control.hex" "+LEN=$(stat -c%s "$WORK/control.m2v")" "+PIXELS=$WORK/pixels.hex"
