#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="$(mktemp -d)"
trap 'rm -rf "${build_dir}"' EXIT

iverilog -g2012 -s tb_h262_native_startup \
  -o "${build_dir}/tb_h262_native_startup" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_native_startup.sv" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_download_rearm.sv" \
  "${repo_root}/rtl/mpeg2_hdmi_deinterlace_control.sv" \
  "${repo_root}/tools/streams/tb_h262_native_startup.sv"
vvp "${build_dir}/tb_h262_native_startup"

iverilog -g2012 \
  -s tb_native_field_order \
  -o "${build_dir}/tb_native_field_order" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_native_field_order.sv" \
  "${repo_root}/tools/streams/tb_native_field_order.sv"
vvp "${build_dir}/tb_native_field_order"

iverilog -g2012 \
  -s tb_interlaced_420_cache_mapping \
  -o "${build_dir}/tb_interlaced_420_cache_mapping" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv" \
  "${repo_root}/rtl/mpeg2_luma_framebuffer.sv" \
  "${repo_root}/tools/streams/tb_interlaced_420_cache_mapping.sv"
vvp "${build_dir}/tb_interlaced_420_cache_mapping"

iverilog -g2012 \
  -s tb_native_480i_timing \
  -o "${build_dir}/tb_native_480i_timing" \
  "${repo_root}/rtl/mpeg2_video_output_timing.sv" \
  "${repo_root}/tools/streams/tb_native_480i_timing.sv"

vvp "${build_dir}/tb_native_480i_timing"
vvp "${build_dir}/tb_native_480i_timing" +BFF

iverilog -g2012 \
  -s tb_hdmi_deinterlace_control \
  -o "${build_dir}/tb_hdmi_deinterlace_control" \
  "${repo_root}/rtl/mpeg2_hdmi_deinterlace_control.sv" \
  "${repo_root}/tools/streams/tb_hdmi_deinterlace_control.sv"
vvp "${build_dir}/tb_hdmi_deinterlace_control"

iverilog -g2012 \
  -s tb_native_480i_timing_pattern \
  -o "${build_dir}/tb_native_480i_timing_pattern" \
  "${repo_root}/rtl/mpeg2_native_timing_pattern.sv" \
  "${repo_root}/tools/streams/tb_native_480i_timing_pattern.sv"
vvp "${build_dir}/tb_native_480i_timing_pattern"

iverilog -g2012 \
  -s tb_native_ordinary_overlap_ownership \
  -o "${build_dir}/tb_native_ordinary_overlap_ownership" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv" \
  "${repo_root}/tools/streams/tb_native_ordinary_overlap_ownership.sv"
vvp "${build_dir}/tb_native_ordinary_overlap_ownership"

iverilog -g2012 \
  -s tb_native_ordinary_pts_ownership \
  -o "${build_dir}/tb_native_ordinary_pts_ownership" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv" \
  "${repo_root}/tools/streams/tb_native_ordinary_overlap_ownership.sv"
vvp "${build_dir}/tb_native_ordinary_pts_ownership"

iverilog -g2012 \
  -s tb_native_480i_presentation_integration \
  -o "${build_dir}/tb_native_480i_presentation_integration" \
  "${repo_root}/rtl/mpeg2_video_output_timing.sv" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv" \
  "${repo_root}/tools/streams/tb_native_480i_presentation_integration.sv"
vvp "${build_dir}/tb_native_480i_presentation_integration"

iverilog -g2012 \
  -s tb_native_480i_cache_refill \
  -o "${build_dir}/tb_native_480i_cache_refill" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv" \
  "${repo_root}/rtl/mpeg2_luma_framebuffer.sv" \
  "${repo_root}/tools/streams/tb_native_480i_cache_refill.sv"
vvp "${build_dir}/tb_native_480i_cache_refill" +SYNC_RESET
vvp "${build_dir}/tb_native_480i_cache_refill"
vvp "${build_dir}/tb_native_480i_cache_refill" +SLOW
vvp "${build_dir}/tb_native_480i_cache_refill" +PREFILL_LATE
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT +BFF
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT +CORRUPT
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT +WRONG_BANK
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT +READ_CORRUPT
vvp "${build_dir}/tb_native_480i_cache_refill" +FINGERPRINT +WRITE_INVALID
vvp "${build_dir}/tb_native_480i_cache_refill" +GENERATIONS
vvp "${build_dir}/tb_native_480i_cache_refill" +GENERATIONS +BFF
vvp "${build_dir}/tb_native_480i_cache_refill" +GENERATIONS +GEN_DELAY

iverilog -g2012 \
  -s tb_h262_luma_write_fingerprint \
  -o "${build_dir}/tb_h262_luma_write_fingerprint" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_luma_write_fingerprint.sv" \
  "${repo_root}/tools/streams/tb_h262_luma_write_fingerprint.sv"
vvp "${build_dir}/tb_h262_luma_write_fingerprint"

iverilog -g2012 \
  -s tb_h262_hardware_cadence_profiler \
  -o "${build_dir}/tb_h262_hardware_cadence_profiler" \
  "${repo_root}/rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv" \
  "${repo_root}/tools/streams/tb_h262_hardware_cadence_profiler.sv"
vvp "${build_dir}/tb_h262_hardware_cadence_profiler" \
  "+DEADLINE_SNAPSHOT=${build_dir}/deadline_snapshot.hex"

python3 "${repo_root}/tools/streams/test_decode_hardware_cadence.py" \
  --rtl-snapshot "${build_dir}/deadline_snapshot.hex"
