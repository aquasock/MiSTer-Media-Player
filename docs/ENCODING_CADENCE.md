# Conversion cadence: Groove and fellow

For the supplied **23.976 fps** sources, remove `,fps=24000/1001` from the
end of the video filter and add these **output options**, after `-i`:

```sh
-r:v 24000/1001 -fps_mode:v cfr
```

Keep the scale, pad, SAR, MPEG-2 and MP2 options unchanged. This keeps the
existing progressive 720x480, 16:9, limited-range BT.601 output compatible with
the core. Select the rate matching the source: for example `30000/1001` for
29.97 fps Pee, or `25` for 25 fps material. This is not a universal instruction
to convert every source to 23.976 fps. Automatic input matrix/range detection
still depends on reliable source metadata.

## Reproduction and evidence

The supplied Groove and fellow MKVs are HEVC at 24000/1001 with a 1/1000
timestamp time base. Groove's audio/container begins at -21 ms and video at
zero; fellow's video begins at +21 ms and audio/container at zero. After input
start normalization both present video near a half-frame offset (one frame
is about 41.708 ms). Millisecond timestamp rounding around that offset causes
the original `fps` filter's nearest rounding to alternate between dropping and
repeating pictures. This diagnosis is supported by full-start reproduction;
input seeking to 60 seconds changes the phase and masks the problem.

In the original 68-second fellow reproduction, the filter reports 1,633 input
frames, 1,631 output frames, **477 dropped and 475 duplicated**. The output-CFR
comparison encodes 1,631 frames without reported output-sync drops or
duplicates. In a moving Groove sample near 60 seconds, the original encode
has 55 repeated source-frame matches and 54 jumps of two; the corrected
sample has 187 consecutive one-frame advances. Low-resolution nearest-image
matching is ambiguous in fellow's dark/static opening, so its match counts
are not used as a correctness oracle. Visual hardware/user acceptance of the
new sample is still pending.

Decoder thread counts 1 and 8, filter thread settings, audio muxing and
B-frame toggles did not explain the failure. The user's output `-threads 1`
limits MPEG-2 encoding; on the build PC's 28 logical CPUs, one busy thread
accounts for approximately 3.6% aggregate CPU usage. Low aggregate usage is
consistent with this configuration and does not indicate skipped frames.

Generate bounded comparisons without altering the original movies:

```sh
python3 tools/reproduce_encode_cadence.py /run/media/vash/GIT/Groove.mkv \
  --output-dir results/cadence-groove
python3 tools/reproduce_encode_cadence.py /run/media/vash/GIT/fellow.mkv \
  --output-dir results/cadence-fellow
```

The tool saves 68 seconds from the beginning, exact command argument arrays
and verbose logs, refusing to overwrite outputs. Watch motion around one
minute. The final `fps` filter summary contains its internal drops/duplicates;
the normal progress line alone can conceal them. Existing investigation
artifacts are under `results/encode-cadence-check` (not tracked).

This fixes conversion-induced cadence damage; normal 23.976-film judder on a
50/59.94 Hz display is a separate issue. No FPGA changes are needed.

References: [FFmpeg fps filter](https://ffmpeg.org/ffmpeg-filters.html#fps)
and [FFmpeg output rate and synchronization options](https://ffmpeg.org/ffmpeg.html).
