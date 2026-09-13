# MiSTer Media Player

A progressive MPEG-2 video player core using stock MiSTer Main. Current
work returns to hardware-accepted source `a57079f` and restores Program
Stream input. Historical v0.7–v0.9 releases describe the previous DVD/ARM
architecture, not this development version.

## Current boundary

- Raw `.m2v` and MPEG Program Stream `.mpg` via the normal file menu.
- MPEG-1 and MPEG-2 pack/PES headers, including legacy PTS/DTS forms.
- First video stream selected; audio and additional streams skipped.
- Progressive 4:2:0 I/P/B video through 720x480 within the baseline's bounded
  motion/residual syntax envelope; frame-rate codes 1–5 (23.976 through 30 fps).
- Existing 800x600 diagnostic raster and aspect-ratio menu.
- Encoded picture cadence; container timestamps do not yet drive presentation.
- Existing 44.1/48 kHz PCM test tones; **no movie audio decoding yet**.

There is no ARM helper or modified Main. MP2 decoding and A/V synchronization
come next, followed by progressive 720x480 output. Interlace, Bob/Weave,
DVD navigation, subtitles and seeking are outside the current scope.

Program Stream EOF closes a missing H.262 sequence-end marker so the final
reordered picture can retire. Raw streams remain unchanged. Load a raw control
and then a short MPG with Audio test Off; repeat both to check restart.
This new ingress requires hardware acceptance independently of the baseline.

Active RTL lives in `rtl/mpeg2_new/` and is listed in `files.qip`.
`rtl/mpeg2fpga/` remains frozen reference code. H.262 governs video and
H.222.0 governs MPEG systems; implementation limits are not standard limits.

See [building](docs/BUILDING.md), [architecture](docs/ARCHITECTURE.md), and
[hardware tests](docs/TEST_INSTRUCTIONS.md). Git history and release notes
retain the previous player implementation and its findings.
