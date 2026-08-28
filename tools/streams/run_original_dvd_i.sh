#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="${1:?usage: run_original_dvd_i.sh <prepared-fixture-directory>}"
WORK="$ROOT/simulation/original_dvd_i"
mkdir -p "$WORK/obj"
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT \
 +incdir+rtl/mpeg2_new --top-module tb_h262_interlaced_i_reconstruction -GFRAME_COUNT=1 \
 --Mdir "$WORK/obj" -o original_i tools/streams/tb_h262_interlaced_i_reconstruction.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/original_i" "+HEX=$FIXTURES/dvd_first_i.hex" "+LEN=$(stat -c%s "$FIXTURES/dvd_first_i.m2v")" \
 "+PIXELS=$FIXTURES/dvd_first_i_pixels.hex" +FILM +TFF
