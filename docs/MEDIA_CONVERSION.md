# Preparing media files

MiSTer Media Player can open compatible MPEG-2 Program Streams directly as
`.mpg` or `.mpeg` files. The following command is the project's recommended
"house recipe" for converting ordinary source media into a conservative
720x480, exact-24-fps MPEG-2 Program Stream with stereo MPEG Layer II audio.

## Recommended FFmpeg recipe

```bash
ffmpeg -hide_banner -y \
  -i "input.*" \
  -map 0:v:0 -map '0:a:0?' -sn -dn \
  -vf "scale=w='if(gte(dar,16/9),720,2*round(405*dar/2))':h='if(gte(dar,16/9),2*round(1280/(3*dar)),480)':flags=lanczos+accurate_rnd:in_color_matrix=bt709:out_color_matrix=bt601:in_range=limited:out_range=limited,pad=720:480:(ow-iw)/2:(oh-ih)/2:black,setsar=32/27,format=yuv420p,fps=24" \
  -c:v mpeg2video -profile:v main -level:v main \
  -pix_fmt yuv420p -threads 1 -flags:v +bitexact \
  -g 24 -bf 2 -b_strategy 0 -mbd rd -trellis 2 \
  -q:v 3 -qmin 2 -qmax 12 \
  -maxrate:v 8000k -bufsize:v 1835008 \
  -sc_threshold 1000000000 -mpv_flags +strict_gop \
  -aspect 16:9 -colorspace smpte170m -color_range tv \
  -c:a mp2 -ar 48000 -ac 2 -b:a 320k \
  -f mpeg "output.mpg"
```

Replace `input.*` with the source filename. The optional audio mapping allows a
silent source to convert successfully; FFmpeg omits the audio stream when none
exists. The filter preserves display aspect ratio, scales into 720x480, pads
unused space with black, produces limited-range BT.601 YCbCr 4:2:0 and signals
the 32:27 sample aspect ratio used for 16:9 720x480 presentation.

The `-threads 1`, GOP, B-frame, rate-control and bit-exact options intentionally
favor repeatable, decoder-friendly output over conversion speed. Do not remove
the output format or rename the result to `.mpg` without actually producing an
MPEG Program Stream.

## Verify the result

Use the repository helpers to inspect the stream and require a complete video
decode without FFmpeg errors:

```bash
tools/media.sh probe "output.mpg"
tools/media.sh verify "output.mpg"
```

At minimum, verify that the result is an MPEG Program Stream containing
720x480 MPEG-2 video, `yuv420p`, exact 24 fps and, when the source has audio,
48 kHz two-channel MP2.

## Other supported file paths

- Raw MPEG-2 Video elementary streams may be opened as `.m2v`; they have no
  embedded audio or Program Stream timestamps.
- Existing compatible MPEG Program Streams may be opened as `.mpg`, `.mpeg` or
  `.vob`. Renaming another container does not convert it.
- DVD-Video should normally be opened from an `.iso` image or directly from an
  inserted physical disc instead of transcoding individual VOBs.
- Standalone `.mp3`, `.wav`, `.flac` and `.ogg` files use the consumer-audio
  path and do not need conversion to MPEG-2 video.

The accepted implementation envelope and codec limits are documented in the
[README](../README.md#known-limitations).
