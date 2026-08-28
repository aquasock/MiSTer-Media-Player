#!/usr/bin/env bash
# All I/P/B samples are reconstructed by RTL, including reference pictures.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
stream="$(realpath "${1:?usage: run_full_frame_pixels.sh stream.m2v [+PLUSARG ...]}")"
shift
WORK="$ROOT/simulation/full_frame_pixels/$(basename "${stream%.m2v}")"
mkdir -p "$WORK/obj"
python3 "$ROOT/tools/streams/prepare_frame_pixel_oracle.py" "$stream" "$WORK"
pictures=$(wc -l < "$WORK/map.hex")
mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new +define+H262_SOAK_MAX_STREAM_BYTES=16777216 \
 --top-module tb_h262_live_raster_soak -GMIXED_PIXEL_MODE=2 -GPIXEL_WIDTH=720 -GPIXEL_HEIGHT=480 \
 -GPIXEL_PICTURES="$pictures" -GMAX_SIM_CYCLES=1500000000 \
 --Mdir "$WORK/obj" -o pixels tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") > "$WORK/build.log" 2>&1
"$WORK/obj/pixels" "+HEX=$WORK/stream.hex" "+LEN=$(stat -c%s "$stream")" \
 "+PIXELS=$WORK/pixels.hex" "+MAP=$WORK/map.hex" +GENERIC_STREAM "+PIXEL_REPORT=$WORK/pixel_report.csv" "$@"
