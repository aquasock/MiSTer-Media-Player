# MiSTer Media Player

A progressive MPEG-2/MP2 player core for stock MiSTer Main. Audio decoding
runs in FPGA logic; no ARM helper or modified Main is required. The accepted
video baseline is `9233f07` seed 52. The current MP2 candidate awaits its own
build and hardware qualification.

- Raw `.m2v` and MPEG Program Stream `.mpg` through the normal file menu.
- Progressive 4:2:0 I/P/B video through 720x480, within the baseline decoder's
  motion/residual limits, at 23.976–30 fps (frame-rate codes 1–5).
- MPEG-1 Layer II audio: 48 kHz, stereo/dual/joint stereo, 112–384 kb/s,
  unprotected frames. The conversion script uses 192 kb/s stereo.
- PES timestamps, audio-clock-based presentation, and independent compressed
  video buffering. Missing individual video PTS retain encoded-cadence fallback.
- Existing 800x600 output raster and aspect-ratio menu. **Audio test Off selects
  movie audio**; test-tone modes remain available.

This first audio candidate targets continuous FFmpeg-generated MPG files with
initial audio/video timestamps and nearby start times. It rejects unsupported
MP2 headers, CRC-protected audio, and malformed frames; it does not implement
mono, 44.1/32 kHz, MP3, AC3, seeking, or timestamp discontinuity recovery.
These are implementation limits, not MPEG standard limits.

Native progressive 720x480 output follows synchronized-audio hardware acceptance.
Interlace, Bob/Weave, DVD navigation and subtitles are outside this development
scope. Historical v0.7–v0.9 releases describe the earlier DVD/ARM architecture.

See [building](docs/BUILDING.md), [architecture](docs/ARCHITECTURE.md), and
[hardware tests](docs/TEST_INSTRUCTIONS.md). Active sources are in `files.qip`;
`rtl/mpeg2fpga/` is frozen reference code.
