#!/usr/bin/env bash
#
# Cycle A differential parser regression.
#
# Moving the 512-byte `row_bytes` slice buffers in mpeg2_h262_b_core_probe and
# mpeg2_h262_p_wide_motion_syntax_probe from distributed registers into block
# memory must not change what the parsers decode.  This script replays a fixed
# set of elementary streams through every Icarus testbench that instantiates
# those probes and prints only their deterministic RESULT lines, so a run
# against unmodified RTL and a run against modified RTL can be compared with
# diff.
#
# The RTL file list comes from files.qip rather than a wildcard: several module
# names are defined in more than one file and files.qip selects the variant the
# Quartus build compiles.
#
# Usage:  tools/streams/run_cycle_a_parser_equivalence.sh <report-file>
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STREAMS="$ROOT/tools/streams"
WORK="$ROOT/simulation/cycle_a_equivalence"
REPORT="${1:?usage: run_cycle_a_parser_equivalence.sh <report-file>}"

mkdir -p "$WORK"

# module:file:stream triples.  Every module listed instantiates at least one of
# the two probes whose row buffer this cycle relocates.  Two testbench files
# carry two top modules each, so the module name is given explicitly rather
# than derived from the filename.
#
# tb_h262_row_streaming is deliberately excluded: its Entry 204 assertions
# require a dense capacity fixture (over 1,526 blocks and 32,768 coefficient
# events at 1,350 macroblocks) that none of the committed generators produce,
# so it has no clean baseline to differentiate against.  Its parser coverage is
# subsumed by tb_h262_b_residual_streaming and tb_h262_dense_publication_order.
TRIPLES=(
    "tb_h262_b_intra_macroblocks:tb_h262_b_intra_macroblocks:test_b_intra_macroblocks"
    "tb_h262_p_intra_macroblocks:tb_h262_p_intra_macroblocks:test_p_intra_macroblocks"
    "tb_h262_b_residual_streaming:tb_h262_b_residual_streaming:test_b_residual_streaming"
    "tb_h262_parser_windows:tb_h262_parser_windows:test_pb_parser_window"
    "tb_h262_b_transport_abort:tb_h262_dense_transport_recovery:test_b_bidirectional"
    "tb_h262_dense_full_b_sequence:tb_h262_dense_transport_recovery:test_b_bidirectional"
    "tb_h262_dense_publication_order:tb_h262_dense_publication_order:test_consecutive_chain"
    "tb_h262_live_raster_soak:tb_h262_live_raster_soak:test_live_raster_soak"
)

mapfile -t sources < <(
    grep -oP '(?<=-name SYSTEMVERILOG_FILE )rtl/mpeg2_new/\S+' "$ROOT/files.qip"
)
echo "rtl     : ${#sources[@]} files from files.qip" >&2

: > "$REPORT"

for triple in "${TRIPLES[@]}"; do
    top="${triple%%:*}"
    rest="${triple#*:}"
    tb="${rest%%:*}"
    stream_name="${rest##*:}"
    stream="$STREAMS/$stream_name.m2v"
    generator="$STREAMS/generate_${stream_name}.py"

    if [ ! -f "$stream" ]; then
        [ -f "$generator" ] || { echo "missing generator: $generator" >&2; exit 1; }
        echo "generate: $stream_name" >&2
        python3 "$generator" --output "$stream" >&2
    fi

    hex="$WORK/$stream_name.hex"
    if [ ! -f "$hex" ] || [ "$stream" -nt "$hex" ]; then
        echo "hex     : $stream_name" >&2
        xxd -c1 -p "$stream" > "$hex"
    fi

    # tb_h262_b_intra_macroblocks reads a fixed path instead of a plusarg.
    if [ "$top" = "tb_h262_b_intra_macroblocks" ]; then
        cp -f "$hex" /tmp/b_intra.hex
    fi

    vvp_out="$WORK/$top.vvp"
    echo "compile : $top" >&2
    ( cd "$ROOT" && iverilog -g2012 -gsupported-assertions \
        -I rtl/mpeg2_new -o "$vvp_out" -s "$top" \
        "$STREAMS/$tb.sv" "${sources[@]}" ) >&2

    len=$(stat -c%s "$stream")
    echo "run     : $top / $stream_name" >&2
    log="$WORK/$top.log"
    set +e
    ( cd "$WORK" && timeout 3600 vvp "$vvp_out" "+HEX=$hex" "+LEN=$len" ) > "$log" 2>&1
    status=$?
    set -e

    {
        echo "### $top $stream_name exit=$status"
        grep -E '^[A-Z0-9_]*RESULT' "$log" || echo "(no RESULT line)"
    } >> "$REPORT"
done

echo >&2
echo "report  : $REPORT" >&2
