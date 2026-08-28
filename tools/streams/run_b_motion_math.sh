#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/b_motion_math"
mkdir -p "$WORK/obj"
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-WIDTH -Wno-PINMISSING +incdir+rtl/mpeg2_new \
 --top-module tb_h262_b_motion_math --Mdir "$WORK/obj" -o motion_math \
 tools/streams/tb_h262_b_motion_math.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/motion_math"
