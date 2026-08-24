#!/usr/bin/env bash
# Generate and replay the deterministic TFF/BFF 480i all-I streams through the
# complete I parser, inverse-quant, IDCT and reconstruction chain.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$ROOT/simulation/interlaced_i"
GENERATED="$ROOT/tools/streams/generated_interlaced"
TB="$ROOT/tools/streams/tb_h262_interlaced_i_reconstruction.sv"
mkdir -p "$WORK"

python3 "$ROOT/tools/streams/generate_test_interlaced_i_frames.py"

sources=(
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_frontend.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_dct_vlc.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_bitreader.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_luma4_probe.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_picture_bookkeeper.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_idct.sv"
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_intra_recon.sv"
)

obj="$WORK/obj"
rm -rf "$obj"
verilator --binary --timing -j 6 \
    -Wno-fatal -Wno-PINMISSING -Wno-WIDTH -Wno-UNOPTFLAT \
    --top-module tb_h262_interlaced_i_reconstruction \
    --Mdir "$obj" -o interlaced_i "$TB" "${sources[@]}"

for order in tff bff; do
    stream="$GENERATED/test_interlaced_i_${order}.m2v"
    stream_hex="$WORK/test_interlaced_i_${order}.hex"
    oracle_raw="$WORK/test_interlaced_i_${order}.yuv"
    oracle_hex="$WORK/test_interlaced_i_${order}_pixels.hex"
    xxd -c1 -p "$stream" > "$stream_hex"
    ffmpeg -hide_banner -loglevel error -y -threads 1 -i "$stream" \
        -frames:v 4 -an -f rawvideo -pix_fmt yuv420p "$oracle_raw"
    xxd -c1 -p "$oracle_raw" > "$oracle_hex"
    len=$(stat -c%s "$stream")
    plusargs=("+HEX=$stream_hex" "+LEN=$len" "+PIXELS=$oracle_hex")
    if [[ "$order" == tff ]]; then plusargs+=(+TFF); fi
    echo "run     : $order"
    "$obj/interlaced_i" "${plusargs[@]}"
done

# Preserve the released progressive I-picture gate and full reconstruction
# path while the bounded interlaced predicate is added beside it.
python3 "$ROOT/tools/streams/generate_test_i_baseline.py"
progressive="$ROOT/tools/streams/test_i_baseline.m2v"
progressive_hex="$WORK/test_i_baseline.hex"
progressive_raw="$WORK/test_i_baseline.yuv"
progressive_pixels="$WORK/test_i_baseline_pixels.hex"
xxd -c1 -p "$progressive" > "$progressive_hex"
ffmpeg -hide_banner -loglevel error -y -threads 1 -i "$progressive" \
    -frames:v 4 -an -f rawvideo -pix_fmt yuv420p "$progressive_raw"
xxd -c1 -p "$progressive_raw" > "$progressive_pixels"
progressive_len=$(stat -c%s "$progressive")
echo "run     : progressive control"
"$obj/interlaced_i" "+HEX=$progressive_hex" "+LEN=$progressive_len" \
    "+PIXELS=$progressive_pixels" +PROGRESSIVE

# A valid interlaced frame picture using field DCT/motion syntax is outside
# this milestone and must never raise phase1_supported or reconstruct pixels.
reject="$WORK/test_interlaced_field_dct_reject.m2v"
ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i 'testsrc2=size=720x480:rate=60000/1001,tinterlace=mode=interleave_top' \
    -frames:v 2 -an -c:v mpeg2video -pix_fmt yuv420p -threads 1 \
    -flags +bitexact+ildct -g 1 -bf 0 -q:v 2 -f mpeg2video "$reject"
reject_hex="$WORK/test_interlaced_field_dct_reject.hex"
xxd -c1 -p "$reject" > "$reject_hex"
reject_len=$(stat -c%s "$reject")
echo "run     : field-DCT rejection control"
"$obj/interlaced_i" "+HEX=$reject_hex" "+LEN=$reject_len" +REJECT
