#!/usr/bin/env bash
# Cycle-level differential check against the numerically qualified parser.
# Run on the build PC; the reference RTL is extracted from immutable Git data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASELINE="${1:-4a27f80ebf655de2785fa4efd576eff2952e285d}"
BASELINE_REPO="${BASELINE_REPO:-$ROOT}"
WORK="$ROOT/simulation/quant_matrix_equivalence"
mkdir -p "$WORK"
git -C "$BASELINE_REPO" show "$BASELINE:rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv" > "$WORK/reference.sv"
python3 - "$ROOT" "$WORK" <<'PY'
from pathlib import Path
import sys
root, work = map(Path, sys.argv[1:])
p = work/'reference.sv'
p.write_text(p.read_text().replace('module mpeg2_h262_quant_matrices (',
                                  'module mpeg2_h262_quant_matrices_reference (', 1))
tb = (root/'tools/streams/tb_h262_quant_matrices.sv').read_text()
checker = r'''
wire [7:0] ref_iw, ref_nw;
wire ref_idef, ref_ndef, ref_error, ref_update;
integer eq_index, eq_cycles=0;
mpeg2_h262_quant_matrices_reference baseline(
 .clk(clk),.reset(reset),.stream_data(data),.stream_valid(valid),.read_index(index),
 .intra_weight(ref_iw),.non_intra_weight(ref_nw),.intra_default(ref_idef),
 .non_intra_default(ref_ndef),.syntax_error(ref_error),.update_now(ref_update));
always @(negedge clk) begin
 #0.1;
 if(!reset) begin
  if({iw,nw,idef,ndef,error,dut.update_now} !==
     {ref_iw,ref_nw,ref_idef,ref_ndef,ref_error,ref_update})
   $fatal(1,"matrix interface equivalence cycle=%0d",eq_cycles);
  for(eq_index=0;eq_index<64;eq_index=eq_index+1) begin
   if(dut.intra_mem[eq_index] !== baseline.intra_mem[eq_index] ||
      dut.non_intra_mem[eq_index] !== baseline.non_intra_mem[eq_index])
    $fatal(1,"matrix write equivalence cycle=%0d index=%0d",eq_cycles,eq_index);
  end
  eq_cycles=eq_cycles+1;
 end
end
'''
tb = tb.replace('$finish;', '$display("MATRIX_EQUIVALENCE_PASS cycles=%0d continuous=%0d",eq_cycles,continuous_bytes);$finish;')
(work/'tb.sv').write_text(tb.replace('endmodule', checker+'\nendmodule'))
PY
verilator --binary --timing -j 6 -Wno-fatal -Wno-WIDTH \
 --top-module tb_h262_quant_matrices --Mdir "$WORK/obj" -o matrix_equivalence \
 "$WORK/tb.sv" "$WORK/reference.sv" "$ROOT/rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv" \
 > "$WORK/build.log" 2>&1
"$WORK/obj/matrix_equivalence"
"$WORK/obj/matrix_equivalence" +CONTINUOUS
