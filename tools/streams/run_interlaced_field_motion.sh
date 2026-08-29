#!/usr/bin/env bash
# Entry 695: replay the interlaced field-motion P fixture through the complete
# decoder and compare every reconstructed sample against the fixture's own
# oracle.
#
# The oracle is produced by the generator, which builds the expected frame with
# h262common's field reference model and proves it byte-identical to FFmpeg's
# decode of the same bitstream before writing it.  This is the arrangement
# run_mixed_raster_pixels.sh uses.  It deliberately does not reuse
# run_interlaced_p_pixels.sh, whose own progressive control does not pass.
#
# Expected outcome while the parser gate still requires frame_pred_frame_dct:
# the run reaches the P picture and prints UNSUPPORTED, then the testbench's
# error trap fires because nothing claimed the picture.  That is the baseline,
# not a regression.  When the admission and parser gates open, this run becomes
# a real sample-by-sample comparison against the oracle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/interlaced_field_motion"
mkdir -p "$WORK/obj"

python3 "$ROOT/tools/streams/generate_test_interlaced_field_motion.py" \
    --output "$WORK/field_motion.m2v" --oracle-output "$WORK/pixels.hex"
xxd -c1 -p "$WORK/field_motion.m2v" > "$WORK/field_motion.hex"

mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")

echo "compile : ${#sources[@]} RTL files + testbench"
(cd "$ROOT" && verilator --binary --timing -j 6 -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new --top-module tb_h262_interlaced_field_motion_pixels --Mdir "$WORK/obj" -o field_motion \
 tools/streams/tb_h262_interlaced_field_motion_pixels.sv tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") > "$WORK/build.log" 2>&1

len=$(stat -c%s "$WORK/field_motion.m2v")
echo "run     : interlaced field motion ($len bytes)"
"$WORK/obj/field_motion" "+HEX=$WORK/field_motion.hex" "+LEN=$len" "+PIXELS=$WORK/pixels.hex" "$@"
