#!/usr/bin/env bash
# Native-film diagnostic; synthesis sources are never modified by this runner.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$(realpath "${1:?usage: run_original_dvd_timing.sh fixtures helper output-directory}")"
HELPER="$(realpath "${2:?native helper required}")"
WORK="$(realpath -m "${3:?output directory required}")"
mkdir -p "$WORK"
python3 "$ROOT/tools/streams/prepare_original_dvd_timing.py" "$FIXTURES" "$HELPER" "$WORK" > "$WORK/prepare.log"
pictures=$(wc -l < "$FIXTURES/dvd_opening_map.hex")
records=$(wc -l < "$WORK/pts.hex")
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new +incdir+tools/streams +define+H262_SOAK_MAX_STREAM_BYTES=16777216 \
 --top-module tb_h262_live_raster_soak -GMIXED_PIXEL_MODE=2 -GPIXEL_WIDTH=720 -GPIXEL_HEIGHT=480 \
 -GPIXEL_PICTURES="$pictures" -GMAX_SIM_CYCLES=1500000000 -GFREEZE_TRACE_CYCLES=0 -GNATIVE_PRESENTATION=1 \
 -GMEMORY_READ_LATENCY="${NATIVE_MEMORY_LATENCY:-1}" \
 -GMEMORY_BUSY_PERIOD="${NATIVE_BUSY_PERIOD:-0}" -GMEMORY_BUSY_CYCLES="${NATIVE_BUSY_CYCLES:-0}" \
 --Mdir "$WORK/obj" -o original_timing tools/streams/tb_h262_live_raster_soak.sv \
 rtl/mpeg2_luma_framebuffer.sv rtl/mpeg2_video_output_timing.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/original_timing" "+HEX=$FIXTURES/dvd_opening_original.hex" "+LEN=$(stat -c%s "$FIXTURES/dvd_opening_original.m2v")" \
 "+PIXELS=$FIXTURES/dvd_opening_original_pixels.hex" "+MAP=$FIXTURES/dvd_opening_map.hex" \
 "+PTS=$WORK/pts.hex" "+PTS_COUNT=$records" "+NATIVE_TRACE=$WORK/native.csv" \
 "+PICTURE_TRACE=$WORK/pictures.csv" "+PIXEL_REPORT=$WORK/pixels.csv" \
 +GENERIC_STREAM +CHAIN_ERROR_BOUND +PROGRESS=10000000 > "$WORK/run.log" 2>&1
python3 "$ROOT/tools/streams/analyze_original_dvd_timing.py" "$WORK/timing_fixture.json" "$WORK/native.csv" "$WORK/analysis.json"
