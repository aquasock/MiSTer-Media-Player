#!/usr/bin/env bash
# Entry 695: replay the interlaced B field-motion fixture through the complete
# decoder and compare every reconstructed sample against the fixture's own
# oracle.
#
# Every macroblock of the B picture predicts with field motion in both
# directions, so each destination field averages a forward and a backward field
# prediction and one macroblock draws on four independently selected reference
# fields.  The oracle is produced by the generator, which builds the expected
# frame with h262common's bidirectional field reference model and proves it
# byte-identical to FFmpeg's decode of the same bitstream before writing it.
#
# The compile-only H262_TEST_FIELD_MOTION define opens the B parser gate for
# this deterministic fixture.  Production synthesis does not define it, so the
# unfinished admission gate stays closed in the RBF source path.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/b_field_motion"
mkdir -p "$WORK/obj"

python3 "$ROOT/tools/streams/generate_test_b_field_motion.py" \
    --output "$WORK/b_field_motion.m2v" --oracle-output "$WORK/pixels.hex"
od -An -v -tx1 "$WORK/b_field_motion.m2v" | tr -d ' \n' | fold -w2 > "$WORK/b_field_motion.hex"

mapfile -t sources < <(sed -n 's/^set_global_assignment -name SYSTEMVERILOG_FILE \(rtl\/mpeg2_new\/.*\)/\1/p' "$ROOT/files.qip")

echo "compile : ${#sources[@]} RTL files + testbench"
(cd "$ROOT" && verilator --binary --timing -j 6 -DH262_TEST_FIELD_MOTION -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT -Wno-CASEINCOMPLETE -Wno-BLKANDNBLK \
 +incdir+rtl/mpeg2_new --top-module tb_h262_b_field_motion_pixels --Mdir "$WORK/obj" -o b_field_motion \
 tools/streams/tb_h262_b_field_motion_pixels.sv tools/streams/tb_h262_live_raster_soak.sv "${sources[@]}") > "$WORK/build.log" 2>&1

len=$(stat -c%s "$WORK/b_field_motion.m2v")
echo "run     : B field motion ($len bytes)"
"$WORK/obj/b_field_motion" "+HEX=$WORK/b_field_motion.hex" "+LEN=$len" "+PIXELS=$WORK/pixels.hex" "$@"
