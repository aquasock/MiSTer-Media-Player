# MiSTer Media Player

A progressive MPEG-2/MP2 player core for stock MiSTer Main. Audio decoding
runs in FPGA logic; no ARM helper or modified Main is required. The accepted
audio/video baseline is `1750154` seed 87, accepted by the user and passing
static timing. The native 480p candidate awaits build and hardware qualification.

- Raw `.m2v` and MPEG Program Stream `.mpg` through the normal file menu.
- Progressive 4:2:0 I/P/B video through 720x480, within the baseline decoder's
  motion/residual limits, at 23.976–30 fps (frame-rate codes 1–5).
- MPEG-1 Layer II audio: 48 kHz, stereo/dual/joint stereo, 112–384 kb/s,
  unprotected frames. The conversion script uses 192 kb/s stereo.
- PES timestamps, audio-clock-based presentation, and independent compressed
  video buffering. Missing individual video PTS retain encoded-cadence fallback.
- Native 720x480 progressive raster at 60000/1001 Hz, with a 27 MHz pixel
  clock and aspect-ratio menu (Original follows 4:3 or 16:9 sequence signalling). **Audio test Off selects
  movie audio**; test-tone modes remain available.

This first audio candidate targets continuous FFmpeg-generated MPG files with
initial audio/video timestamps and nearby start times. It rejects unsupported
MP2 headers, CRC-protected audio, and malformed frames; it does not implement
mono, 44.1/32 kHz, MP3, AC3, seeking, or timestamp discontinuity recovery.
These are implementation limits, not MPEG standard limits.

The decoder remains at 60 MHz. Smaller pictures are centered within the 720x480
raster. There is no interlaced output, Bob or Weave support. Direct analog
output is 480p/31 kHz; this is not a 15 kHz 240p or 480i mode.
Interlace, Bob/Weave, DVD navigation and subtitles are outside this development
scope. Historical v0.7–v0.9 releases describe the earlier DVD/ARM architecture.

See [building](docs/BUILDING.md), [architecture](docs/ARCHITECTURE.md), and
[hardware tests](docs/TEST_INSTRUCTIONS.md). Active sources are in `files.qip`;
`rtl/mpeg2fpga/` is frozen reference code.

Supported output targets are HDMI through 1920x1080 and standard CRT resolutions.
ASCAL image width is capped at 2048 pixels; the analog output path is retained.
The unused Linux ALSA path and legacy LED blink diagnostics are disabled;
FPGA movie audio and the screen telemetry remain enabled.
