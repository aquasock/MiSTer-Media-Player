#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-generated_progressive_regression}"
mkdir -p "$output_dir"

common_video=(
  -c:v mpeg2video -pix_fmt yuv420p -g 12 -bf 2 -q:v 2
  -sc_threshold 0 -an -f mpeg
)

ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=720x480:rate=24000/1001:duration=12" \
  -vf "drawgrid=width=16:height=16:thickness=1:color=white@0.45" \
  "${common_video[@]}" \
  "$output_dir/progressive_720x480_24000_1001.mpg"

ffmpeg -nostdin -hide_banner -loglevel error -y \
  -f lavfi -i "testsrc2=size=720x480:rate=30000/1001:duration=12" \
  -vf "drawgrid=width=16:height=16:thickness=1:color=white@0.45" \
  -flags +ilme+ildct -top 1 "${common_video[@]}" \
  "$output_dir/interlaced_720x480_30000_1001.mpg"

ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,field_order,codec_name \
  -of default=noprint_wrappers=1 \
  "$output_dir/progressive_720x480_24000_1001.mpg"
ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate,field_order,codec_name \
  -of default=noprint_wrappers=1 \
  "$output_dir/interlaced_720x480_30000_1001.mpg"
