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
    "$ROOT/rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv"
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

# Field-DCT I pictures have been supported since entry 650. Verify their
# reconstruction rather than retaining the older, now-invalid rejection test.
field_dct="$WORK/test_interlaced_field_dct.m2v"
ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "color=c=black:s=720x480:r=60000/1001,geq=lum='16+219*gte(Y,mod(N*4,472))*lt(Y,mod(N*4,472)+8)':cb=128:cr=128,tinterlace=mode=interleave_top" \
    -frames:v 4 -an -c:v mpeg2video -pix_fmt yuv420p -threads 1 \
    -flags +bitexact+ildct -top 1 -g 1 -bf 0 -q:v 2 -f mpeg2video "$field_dct"
python3 -c 'import sys; from pathlib import Path; p=Path(sys.argv[1]); d=p.read_bytes(); end=bytes.fromhex("000001b7"); p.write_bytes(d if d.endswith(end) else d+end)' "$field_dct"
xxd -c1 -p "$field_dct" > "$WORK/field_dct.hex"
ffmpeg -hide_banner -loglevel error -y -threads 1 -i "$field_dct" \
    -frames:v 4 -an -f rawvideo -pix_fmt yuv420p "$WORK/field_dct.yuv"
xxd -c1 -p "$WORK/field_dct.yuv" > "$WORK/field_dct_pixels.hex"
echo "run     : field-DCT reconstruction control"
"$obj/interlaced_i" "+HEX=$WORK/field_dct.hex" "+LEN=$(stat -c%s "$field_dct")" \
    "+PIXELS=$WORK/field_dct_pixels.hex" +TFF
