#!/usr/bin/env bash
#
# Replay an MPEG-2 elementary stream through tb_h262_live_raster_soak under
# Icarus Verilog.
#
# The testbench loads the stream with $readmemh, so the .m2v is first expanded
# to one hex byte per line.  The RTL file list is taken from files.qip rather
# than from a wildcard: several module names are defined in more than one file
# and files.qip is what selects the variant the Quartus build compiles.
#
# Usage:  tools/streams/run_live_raster_soak.sh <stream.m2v> [+PLUSARG ...]
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/soak"
TB="$ROOT/tools/streams/tb_h262_live_raster_soak.sv"

stream="${1:?usage: run_live_raster_soak.sh <stream.m2v> [+PLUSARG ...]}"
shift || true
[ -f "$stream" ] || { echo "stream not found: $stream" >&2; exit 1; }

mkdir -p "$WORK"
name="$(basename "${stream%.m2v}")"
hex="$WORK/$name.hex"
vvp_out="$WORK/$name.vvp"

len=$(stat -c%s "$stream")
if [ ! -f "$hex" ] || [ "$stream" -nt "$hex" ]; then
    echo "hex     : expanding $len bytes -> $hex"
    xxd -c1 -p "$stream" > "$hex"
fi

# SYSTEMVERILOG_FILE entries under rtl/ only; the MiSTer top level and its
# framebuffer/scaler siblings pull in sys/ and are not part of this bench.
mapfile -t sources < <(
    grep -oP '(?<=-name SYSTEMVERILOG_FILE )rtl/mpeg2_new/\S+' "$ROOT/files.qip"
)

echo "compile : ${#sources[@]} RTL files + testbench"
( cd "$ROOT" && iverilog -g2012 -gsupported-assertions \
    -I rtl/mpeg2_new \
    -o "$vvp_out" -s tb_h262_live_raster_soak \
    "$TB" "${sources[@]}" )

echo "run     : $name"
( cd "$WORK" && exec vvp "$vvp_out" "+HEX=$hex" "+LEN=$len" "$@" )
