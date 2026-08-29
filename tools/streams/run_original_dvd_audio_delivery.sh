#!/usr/bin/env bash
# Production-path audio delivery proof using behavioral FIFO models.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$(realpath "${1:?usage: run_original_dvd_audio_delivery.sh fixtures helper output-directory}")"
HELPER="$(realpath "${2:?native helper required}")"
WORK="$(realpath -m "${3:?output directory required}")"
mkdir -p "$WORK"

python3 "$ROOT/tools/streams/prepare_original_dvd_timing.py" \
    "$FIXTURES" "$HELPER" "$WORK/timing" > "$WORK/prepare.log"
python3 "$ROOT/tools/streams/analyze_arm_av_transport.py" \
    "$HELPER" "$FIXTURES/dvd_opening_original.mpg" --sample-rate 48000 \
    --json > "$WORK/hdmi_transport.json"
python3 "$ROOT/tools/streams/verify_ac3_passthrough.py" \
    --helper "$HELPER" --fixture "$FIXTURES/dvd_opening_original.mpg" \
    --report "$WORK/spdif_payload.json" > "$WORK/spdif_payload.log"

for mode in hdmi spdif; do
    "$HELPER" --protocol 1 --audio-out "$mode" \
        --source "file:$FIXTURES/dvd_opening_original.mpg" \
        > "$WORK/$mode.transport" 2> "$WORK/$mode.helper.log"
    xxd -p -c 1 "$WORK/$mode.transport" > "$WORK/$mode.hex"
done

pictures=$(wc -l < "$FIXTURES/dvd_opening_map.hex")
records=$(wc -l < "$WORK/timing/pts.hex")
mapfile -t sources < <(sed -n \
    's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' \
    "$ROOT/files.qip")
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal \
    -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE \
    -Wno-BLKANDNBLK +incdir+rtl/mpeg2_new +incdir+tools/streams \
    +define+H262_SOAK_MAX_STREAM_BYTES=16777216 \
    --top-module tb_h262_live_raster_soak -GMIXED_PIXEL_MODE=2 \
    -GPIXEL_WIDTH=720 -GPIXEL_HEIGHT=480 -GPIXEL_PICTURES="$pictures" \
    -GMAX_SIM_CYCLES=1500000000 -GFREEZE_TRACE_CYCLES=0 \
    -GNATIVE_PRESENTATION=1 -GAUDIO_TRANSPORT=1 \
    --Mdir "$WORK/obj" -o audio_delivery \
    tools/streams/tb_h262_live_raster_soak.sv \
    tools/streams/tb_h262_clean_video_queue.sv \
    tools/streams/tb_audio_pcm_fifo.sv \
    tools/streams/tb_native_480i_cache_refill.sv \
    rtl/mpeg2_luma_framebuffer.sv rtl/mpeg2_video_output_timing.sv \
    rtl/audio/audio_pcm_fifo.sv rtl/audio/audio_pcm_output_adapter.sv \
    "${sources[@]}") > "$WORK/build.log" 2>&1

run_case() {
    local name=$1 mode=$2 stride=$3 stop=$4
    local complete=()
    local stop_arg=()
    if (( stop == 0 )); then
        complete=(--complete)
    else
        stop_arg=("+AUDIO_STOP_CYCLES=$stop")
    fi
    "$WORK/obj/audio_delivery" \
        "+HEX=$FIXTURES/dvd_opening_original.hex" \
        "+LEN=$(stat -c%s "$FIXTURES/dvd_opening_original.m2v")" \
        "+PIXELS=$FIXTURES/dvd_opening_original_pixels.hex" \
        "+MAP=$FIXTURES/dvd_opening_map.hex" \
        "+PTS=$WORK/timing/pts.hex" "+PTS_COUNT=$records" \
        "+NATIVE_TRACE=$WORK/$name.native.csv" \
        "+AUDIO_TRACE=$WORK/$name.audio.csv" \
        "+TRANSPORT=$WORK/$mode.hex" \
        "+TRANSPORT_LEN=$(stat -c%s "$WORK/$mode.transport")" \
        "+HOST_STRIDE=$stride" "${stop_arg[@]}" \
        +GENERIC_STREAM +CHAIN_ERROR_BOUND +PROGRESS=10000000 \
        > "$WORK/$name.log" 2>&1
    python3 "$ROOT/tools/streams/analyze_original_audio_delivery.py" \
        "$WORK/$name.audio.csv" "$WORK/$name.log" "$WORK/$name.json" \
        "${complete[@]}"
}

# These two bounded cases cross the exact ideal-source S/PDIF failure and the
# slower decoded-audio sensitivity boundary from entry 687.
run_case spdif_prefix spdif 1 180000000
run_case hdmi_stride15_prefix hdmi 15 150000000
if [[ "${AUDIO_DELIVERY_FULL:-0}" == 1 ]]; then
    run_case spdif_full spdif 1 0
    run_case hdmi_full hdmi 1 0
fi
echo "ORIGINAL_DVD_AUDIO_DELIVERY_PASS full=${AUDIO_DELIVERY_FULL:-0}"
