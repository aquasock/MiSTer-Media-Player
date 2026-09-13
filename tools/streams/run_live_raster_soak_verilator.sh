#!/usr/bin/env bash
#
# Replay an MPEG-2 elementary stream through tb_h262_live_raster_soak under
# Verilator.
#
# Same bench and same RTL file list as run_live_raster_soak.sh, but compiled to
# native code instead of interpreted.  Icarus runs this design at roughly 21k
# cycles/sec, which puts a 250-picture 720x480 replay at over two hours; that is
# too slow to iterate a deadlock against.
#
# Usage:  tools/streams/run_live_raster_soak_verilator.sh <stream.m2v> [+PLUSARG ...]
# Set H262_SOAK_SWAP_WINDOW_CYCLES and H262_SOAK_FREEZE_TRACE_CYCLES to
# reproduce hardware-rate presentation pressure without changing the bench.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/verilator"
TB="$ROOT/tools/streams/tb_h262_live_raster_soak.sv"

stream="${1:?usage: run_live_raster_soak_verilator.sh <stream.m2v> [+PLUSARG ...]}"
shift || true
[ -f "$stream" ] || { echo "stream not found: $stream" >&2; exit 1; }

name="$(basename "${stream%.m2v}")"
soak_swap_window_cycles="${H262_SOAK_SWAP_WINDOW_CYCLES:-10000}"
soak_freeze_trace_cycles="${H262_SOAK_FREEZE_TRACE_CYCLES:-2000000}"
OBJ="$WORK/${name}_sw${soak_swap_window_cycles}_fr${soak_freeze_trace_cycles}"
mkdir -p "$OBJ"
hex="$WORK/$name.hex"

len=$(stat -c%s "$stream")
if [ ! -f "$hex" ] || [ "$stream" -nt "$hex" ]; then
    echo "hex     : expanding $len bytes -> $hex"
    xxd -c1 -p "$stream" > "$hex"
fi

mapfile -t sources < <(
    grep -oP '(?<=-name SYSTEMVERILOG_FILE )rtl/mpeg2_new/\S+' "$ROOT/files.qip"
)

echo "compile : ${#sources[@]} RTL files + testbench (verilator), swap=$soak_swap_window_cycles freeze=$soak_freeze_trace_cycles"
( cd "$ROOT" && verilator \
    --binary --timing -j 6 \
    -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT \
    -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
    +incdir+rtl/mpeg2_new \
    --top-module tb_h262_live_raster_soak \
    -GSWAP_WINDOW_CYCLES="$soak_swap_window_cycles" \
    -GFREEZE_TRACE_CYCLES="$soak_freeze_trace_cycles" \
    --Mdir "$OBJ" -o soak \
    "$TB" "${sources[@]}" )

echo "run     : $name"
( cd "$WORK" && exec "$OBJ/soak" "+HEX=$hex" "+LEN=$len" "$@" )
