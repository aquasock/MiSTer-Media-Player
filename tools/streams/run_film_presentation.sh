#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/film_presentation"
mkdir -p "$WORK"
iverilog -g2012 -s tb_h262_film_cadence -o "$WORK/cadence" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv" "$ROOT/tools/streams/tb_h262_film_cadence.sv"
vvp "$WORK/cadence"
iverilog -g2012 -s tb_h262_film_reorder_timestamp -o "$WORK/reorder" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv" \
 "$ROOT/tools/streams/tb_h262_film_reorder_timestamp.sv"
vvp "$WORK/reorder"
vvp "$WORK/reorder" +OVERLAP_REFERENCE_ADMISSION
vvp "$WORK/reorder" +EARLY_B_REFERENCE
vvp "$WORK/reorder" +EARLY_P_RELEASE
vvp "$WORK/reorder" +ORDINARY_B_OVERLAP
vvp "$WORK/reorder" +DRAIN_REFERENCE_OVERLAP
iverilog -g2012 -s tb_native_field_order -o "$WORK/field_order" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_native_field_order.sv" "$ROOT/tools/streams/tb_native_field_order.sv"
vvp "$WORK/field_order"
iverilog -g2012 -s tb_h262_picture_timestamp -o "$WORK/metadata" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv" "$ROOT/tools/streams/tb_h262_picture_timestamp.sv"
vvp "$WORK/metadata"
verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH \
 --top-module tb_native_480i_cache_refill --Mdir "$WORK/cache_obj" -o film_cache \
 "$ROOT/tools/streams/tb_native_480i_cache_refill.sv" "$ROOT/rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv" \
 "$ROOT/rtl/mpeg2_luma_framebuffer.sv" > "$WORK/cache_build.log" 2>&1
"$WORK/cache_obj/film_cache" +FINGERPRINT +FILM
"$WORK/cache_obj/film_cache" +FINGERPRINT +FILM +BFF
"$WORK/cache_obj/film_cache" +FINGERPRINT +FILM +REPEAT_FIELD
"$WORK/cache_obj/film_cache" +FINGERPRINT +FILM +BFF +REPEAT_FIELD
