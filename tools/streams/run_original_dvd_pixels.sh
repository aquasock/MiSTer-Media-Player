#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="${1:?usage: run_original_dvd_pixels.sh <prepared-fixture-directory>}"
shift
WORK="${ORIGINAL_DVD_WORK:-$ROOT/simulation/original_dvd_pixels}"
mkdir -p "$WORK/obj"
pictures=$(wc -l < "$FIXTURES/dvd_opening_map.hex")
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new +define+H262_SOAK_MAX_STREAM_BYTES=16777216 \
 --top-module tb_h262_live_raster_soak -GMIXED_PIXEL_MODE=2 -GPIXEL_WIDTH=720 -GPIXEL_HEIGHT=480 \
 -GPIXEL_PICTURES="$pictures" -GMAX_SIM_CYCLES=1500000000 \
 --Mdir "$WORK/obj" -o original_pixels tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/original_pixels" "+HEX=$FIXTURES/dvd_opening_original.hex" "+LEN=$(stat -c%s "$FIXTURES/dvd_opening_original.m2v")" \
 "+PIXELS=$FIXTURES/dvd_opening_original_pixels.hex" "+MAP=$FIXTURES/dvd_opening_map.hex" +GENERIC_STREAM +PROGRESS=10000000 "$@"
