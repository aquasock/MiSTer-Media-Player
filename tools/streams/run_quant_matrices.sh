#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/quant_matrices"
mkdir -p "$WORK"
verilator --binary --timing -j 6 -Wno-fatal -Wno-WIDTH \
 --top-module tb_h262_quant_matrices --Mdir "$WORK/obj" -o matrix_test \
 "$ROOT/tools/streams/tb_h262_quant_matrices.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv" > "$WORK/build.log" 2>&1
"$WORK/obj/matrix_test"
"$WORK/obj/matrix_test" +CONTINUOUS
python3 "$ROOT/tools/streams/generate_quant_matrix_vectors.py" "$WORK"
verilator --binary --timing -j 6 -Wno-fatal -Wno-WIDTH \
 --top-module tb_h262_quant_matrix_iq --Mdir "$WORK/iq_obj" -o matrix_iq \
 "$ROOT/tools/streams/tb_h262_quant_matrix_iq.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_idct.sv" > "$WORK/iq_build.log" 2>&1
"$WORK/iq_obj/matrix_iq" "+DIR=$WORK"
