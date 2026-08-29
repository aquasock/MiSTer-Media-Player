#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

iverilog -g2012 -s tb_h262_inband_metadata \
    -o "$temp_dir/inband" \
    "$repo_root/tools/streams/tb_h262_inband_metadata.sv" \
    "$repo_root/rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv"
vvp "$temp_dir/inband"

iverilog -g2012 -s tb_audio_spdif_route \
    -o "$temp_dir/route" \
    "$repo_root/tools/streams/tb_audio_spdif_route.sv" \
    "$repo_root/sys/audio_out.sv"
vvp "$temp_dir/route"
