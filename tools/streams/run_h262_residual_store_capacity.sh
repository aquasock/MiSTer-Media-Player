#!/usr/bin/env bash
# Run the focused two-bank sparse residual-store capacity regression.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/residual_store_capacity"
TB="$ROOT/tools/streams/tb_h262_residual_store_capacity.sv"
VVP="$WORK/tb_h262_residual_store_capacity.vvp"

mkdir -p "$WORK"
mapfile -t sources < <(
    grep -oP '(?<=-name SYSTEMVERILOG_FILE )rtl/mpeg2_new/\S+' \
        "$ROOT/files.qip"
)

echo "compile : ${#sources[@]} RTL files + capacity testbench"
(
    cd "$ROOT"
    iverilog -g2012 -gsupported-assertions \
        -I rtl/mpeg2_new -o "$VVP" \
        -s tb_h262_residual_store_capacity "$TB" "${sources[@]}"
)

echo "run     : residual-store capacity"
exec vvp "$VVP"
