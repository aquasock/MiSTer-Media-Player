#!/usr/bin/env bash
set -euo pipefail

# Run on the build PC. Generated traces, executables and reports stay outside
# the source tree. GHDL may be a system installation or a private executable.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build_dir="${HDMI_SIM_BUILD_DIR:-$(mktemp -d /tmp/mister-hdmi-sim.XXXXXX)}"
ghdl_bin="${GHDL:-ghdl}"
framebuffer_source="${HDMI_SIM_FRAMEBUFFER:-$repo_root/rtl/mpeg2_luma_framebuffer.sv}"
case_name="${1:-weave}"
mkdir -p "$build_dir"
{
    git -C "$repo_root" rev-parse HEAD
    "$ghdl_bin" --version
    verilator --version
    sha256sum "$repo_root/sys/ascal.vhd" "$framebuffer_source" \
        "$repo_root/rtl/mpeg2_video_output_timing.sv" \
        "$repo_root/tools/streams/tb_hdmi_scaler.sv" \
        "$repo_root/tools/streams/tb_hdmi_scaler_stimulus.sv" \
        "$repo_root/tools/streams/check_hdmi_scaler_sim.py"
} >"$build_dir/$case_name-inputs.txt"

# Compile the actual sync_fix module, not a rewritten behavioral substitute.
python3 - "$repo_root" "$build_dir" <<'PY'
from pathlib import Path
import re, sys
root, build = map(Path, sys.argv[1:])
for name, source in [('sync_fix', 'sys/sys_top.v'),
                     ('altsyncram', 'tools/streams/tb_native_480i_cache_refill.sv')]:
    m = re.search(r'^module ' + name + r'\b.*?^endmodule',
                  (root/source).read_text(), re.M | re.S)
    if not m:
        raise SystemExit('Cannot locate existing ' + name)
    (build/(name+'.v')).write_text(m.group() + '\n')
PY

cd "$build_dir"
"$ghdl_bin" -a --std=08 "$repo_root/sys/ascal.vhd" >scaler-build.log 2>&1
"$ghdl_bin" --synth --std=08 --out=verilog --no-formal \
    -gRAMBASE=00100000000000000000000000000000 -gN_AW=28 -gFRAC=8 \
    -gPALETTE2=false ascal >ascal_netlist.v 2>scaler-synth.log
verilator --binary --timing -Wno-fatal --top-module tb_hdmi_scaler \
    --Mdir "$build_dir/obj_hdmi" -o hdmi_sim -j 4 \
    "$repo_root/rtl/mpeg2_video_output_timing.sv" \
    "$framebuffer_source" \
    "$repo_root/rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv" \
    "$repo_root/sys/scanlines.v" "$build_dir/sync_fix.v" "$build_dir/altsyncram.v" \
    "$repo_root/tools/streams/tb_hdmi_scaler_stimulus.sv" \
    "$repo_root/tools/streams/tb_hdmi_scaler.sv" "$build_dir/ascal_netlist.v" \
    >"$build_dir/hdmi-build.log" 2>&1

stim_args=("+REPORT=$build_dir/$case_name-frames.txt" "+FIELDS=${HDMI_SIM_FIELDS:-80}")
case "$case_name" in
    weave) ;;
    bob) stim_args+=(+BOB) ;;
    progressive) stim_args+=(+PROGRESSIVE) ;;
    identical) stim_args+=(+IDENTICAL) ;;
    bff) stim_args+=(+BFF) ;;
    hold) stim_args+=(+HOLD_START=6 "+HOLD_LENGTH=${HDMI_SIM_HOLD_LENGTH:-23}") ;;
    hold-bob) stim_args+=(+BOB +HOLD_START=6 "+HOLD_LENGTH=${HDMI_SIM_HOLD_LENGTH:-23}") ;;
    stale) stim_args+=(+STALE) ;;
    *) echo "Unknown case: $case_name" >&2; exit 2 ;;
esac
if [[ "${HDMI_SIM_OUTPUT:-1080}" == 720 ]]; then stim_args+=(+720P); fi
if [[ "${HDMI_SIM_OUTPUT:-1080}" == 1080 ]]; then stim_args+=(+1080P); fi
if [[ "${HDMI_SIM_BACKPRESSURE:-0}" == 1 ]]; then stim_args+=(+BACKPRESSURE); fi
if [[ "${HDMI_SIM_DUMP:-0}" == 1 ]]; then
    stim_args+=("+DUMP=$build_dir/$case_name-" "+DUMP_START=${HDMI_SIM_DUMP_START:-24}" "+DUMP_COUNT=${HDMI_SIM_DUMP_COUNT:-8}")
fi
"$build_dir/obj_hdmi/hdmi_sim" "${stim_args[@]}" >"$build_dir/$case_name-scaler.log" 2>&1
check_args=(--mode "$case_name")
if [[ "$case_name" == stale ]]; then check_args+=(--expect-stale); fi
python3 "$repo_root/tools/streams/check_hdmi_scaler_sim.py" \
    "$build_dir/$case_name-frames.txt" "${check_args[@]}" >"$build_dir/$case_name-result.json"
echo "Simulation results: $build_dir/$case_name-frames.txt"
