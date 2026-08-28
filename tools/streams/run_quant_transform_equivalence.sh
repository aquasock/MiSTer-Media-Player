#!/usr/bin/env bash
# Prove weight-prefetch timing keeps every public output and coefficient cycle.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE="${1:-38286081a7540a6156b44a762edad7aabfbfde0b}"
BASELINE_REPO="${BASELINE_REPO:-$ROOT}"
WORK="$ROOT/simulation/quant_transform_equivalence"
mkdir -p "$WORK"
git -C "$BASELINE_REPO" show "$BASELINE:rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv" > "$WORK/reference.sv"
python3 "$ROOT/tools/streams/generate_quant_matrix_vectors.py" "$WORK"
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root,work=map(Path,sys.argv[1:])
p=work/'reference.sv'
p.write_text(p.read_text().replace('module mpeg2_h262_p_non_intra_transform',
                                  'module mpeg2_h262_p_non_intra_transform_reference',1))
tb=(root/'tools/streams/tb_h262_quant_matrix_iq.sv').read_text()
checker=r'''
integer eq_cycles=0;
mpeg2_h262_p_non_intra_transform_reference baseline(
 .clk(clk),.reset(reset),.stream_data(stream_data),.stream_valid(stream_valid),
 .qfs_block_index(2'd1),.qfs_block_start(start),.qfs_write_en(we),
 .qfs_write_index(widx),.qfs_write_value(wvalue),.qfs_block_end(finish),
 .quantiser_scale_code(qs),.q_scale_type(qt),.alternate_scan(alt),
 .intra_block(intra),.intra_dc_precision(dc),.block_done(),
 .first_sample_valid(),.first_sample_value(),.residual_sample_valid(),
 .residual_sample_block_index(),.residual_sample_index(),.residual_sample_value(),.probe_error());
always @(negedge clk) begin
 #0.1;
 if(!reset) begin
  if({p.idct_coeff_block_start,p.idct_coeff_valid,p.idct_coeff_index,p.idct_coeff_value,p.idct_coeff_block_end,
      p.block_done,p.first_sample_valid,p.first_sample_value,p.residual_sample_valid,
      p.residual_sample_block_index,p.residual_sample_index,p.residual_sample_value,p.probe_error,p.transform_busy}
    !==
     {baseline.idct_coeff_block_start,baseline.idct_coeff_valid,baseline.idct_coeff_index,baseline.idct_coeff_value,baseline.idct_coeff_block_end,
      baseline.block_done,baseline.first_sample_valid,baseline.first_sample_value,baseline.residual_sample_valid,
      baseline.residual_sample_block_index,baseline.residual_sample_index,baseline.residual_sample_value,baseline.probe_error,baseline.transform_busy})
   $fatal(1,"transform cycle equivalence case=%0d cycle=%0d",c,eq_cycles);
  eq_cycles=eq_cycles+1;
 end
end
'''
tb=tb.replace('$finish;', '$display("TRANSFORM_EQUIVALENCE_PASS cycles=%0d cases=%0d",eq_cycles,CASES);$finish;')
(work/'tb.sv').write_text(tb.replace('endmodule',checker+'\nendmodule'))
PY
verilator --binary --timing -j 6 -Wno-fatal -Wno-WIDTH \
 --top-module tb_h262_quant_matrix_iq --Mdir "$WORK/obj" -o transform_equivalence \
 "$WORK/tb.sv" "$WORK/reference.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv" \
 "$ROOT/rtl/mpeg2_new/mpeg2_h262_idct.sv" > "$WORK/build.log" 2>&1
"$WORK/obj/transform_equivalence" "+DIR=$WORK"
