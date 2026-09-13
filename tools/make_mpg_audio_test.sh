#!/usr/bin/env bash
set -euo pipefail
# Run from the directory containing fellow.mkv, or pass an input filename.
INPUT=${1:-fellow.mkv}
DURATION=${DURATION:-30}
COMMON_VIDEO=(-c:v mpeg2video -profile:v main -level:v main -pix_fmt yuv420p
  -threads:v 1 -flags:v +bitexact -g 24 -bf 2 -b_strategy 0 -q:v 6 -qmin 2 -qmax 12
  -maxrate:v 8000k -bufsize:v 1835008 -sc_threshold 1000000000 -mpv_flags +strict_gop
  -aspect 16:9 -colorspace smpte170m -color_range tv)
# Both tone channels are gated at each whole second; the first frame of that
# second is white. MPEG encoding delay is compensated by the muxed timestamps.
ffmpeg -hide_banner -y \
  -f lavfi -i "testsrc2=size=720x480:rate=30000/1001:duration=$DURATION" \
  -f lavfi -i "aevalsrc=0.2*sin(2*PI*440*t)*lt(mod(t\,1)\,0.08)|0.2*sin(2*PI*880*t)*lt(mod(t\,1)\,0.08):s=48000:d=$DURATION" \
  -map 0:v:0 -map 1:a:0 \
  -vf "drawbox=x=0:y=0:w=iw:h=ih:color=white:t=fill:enable='lt(mod(t,1),0.034)',setsar=32/27" \
  "${COMMON_VIDEO[@]}" -c:a mp2 -ar 48000 -ac 2 -b:a 192k -f mpeg test_av_sync.mpg
ffmpeg -hide_banner -y -i "$INPUT" -t "$DURATION" \
  -map 0:v:0 -map 0:a:0 -sn -dn \
  -vf "scale=w='if(gte(dar,16/9),720,2*round(405*dar/2))':h='if(gte(dar,16/9),2*round(1280/(3*dar)),480)':flags=lanczos,pad=720:480:(ow-iw)/2:(oh-ih)/2:black,setsar=32/27,format=yuv420p,fps=30000/1001" \
  "${COMMON_VIDEO[@]}" -c:a mp2 -ar 48000 -ac 2 -b:a 192k -f mpeg test_progressive_mpg.mpg
printf '%s\n' 'Created test_av_sync.mpg and test_progressive_mpg.mpg. Use Audio test Off.'
