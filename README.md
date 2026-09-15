# MiSTer Media Player

A progressive MPEG-2/MP2 player core for stock MiSTer Main. Audio decoding
runs in FPGA logic; no ARM helper or modified Main is required. The accepted
audio/video baseline is `0b6eb0e` seed 87, with native progressive output,
manual refresh/aspect controls and compact telemetry accepted on hardware.
Keyboard play/pause is hardware tested. Faster seeking is implemented and awaits hardware validation.

- Manually loaded `.srt` subtitles through **Load subtitles**, using stock Main.
  Initial format coverage and hardware-test status: [subtitle notes](docs/SUBTITLES.md).
- Raw `.m2v` and MPEG Program Stream `.mpg` through the normal file menu.
- Progressive 4:2:0 I/P/B video through 720x480, within the baseline decoder's
  motion/residual limits, at 23.976–30 fps (frame-rate codes 1–5).
- MPEG-1 Layer II audio: 48 kHz, stereo/dual/joint stereo, 112–384 kb/s,
  unprotected frames. The conversion script uses 192 kb/s stereo.
- PES timestamps, audio-clock-based presentation, and independent compressed
  video buffering. Missing individual video PTS retain encoded-cadence fallback.
- Native 720x480 progressive raster with manual 59.94/50 Hz selection.
- User-controlled 4:3 or 16:9 aspect ratio; video metadata never overrides it.
- Frame-associated Auto/BT.601/BT.709 color matrix selection.
- **Audio test Off selects movie audio**; test-tone modes remain available.

The player targets continuous FFmpeg-generated MPG files with
initial audio/video timestamps and nearby start times. It rejects unsupported
MP2 headers, CRC-protected audio, and malformed frames; it does not implement
mono, 44.1/32 kHz, MP3, AC3, or arbitrary timestamp discontinuity recovery.
These are implementation limits, not MPEG standard limits.

## HDMI setup

Add this override to MiSTer.ini, including when the global setting is zero:

```ini
[MediaPlayer]
vsync_adjust=1
```

The Refresh rate menu chooses the core's 50 or 59.94 Hz timing. Mode one lets
HDMI follow that rate; leave it set to one when changing the menu. With zero,
HDMI uses the configured output timing and may repeat/drop frames to convert
between rates, reducing the benefit of the refresh switch.
See [MiSTer's video configuration guide](https://mister-devel.github.io/MkDocs_MiSTer/basics/video/#vsync_adjust).

Use 50 Hz for 25 fps video and 59.94 Hz for 29.97 fps video. This does not
change the encoded playback speed or the audio sample rate.

## Keyboard controls

| Key | Action |
| --- | --- |
| Space | Play/pause |
| Left / Right | Backward / forward 10 seconds |
| Ctrl + Left / Right | Backward / forward 30 seconds |
| Ctrl + Alt + Left / Right | Backward / forward 5 minutes |
| N / P | Next / previous embedded CD track (FLAC albums) |

Controls operate with the OSD closed, once per physical press. Pause retains
the displayed frame and queued samples while silencing movie audio. Seeking
while paused leaves the destination paused. Additional seek commands are
ignored while a seek is in progress; Space still controls the final pause state.

The scaled HDMI player overlay shows Elapsed, Total and Remaining above a
progress bar. It appears at startup and on play/pause or seek activity, remains
visible during a seek, and hides ten seconds afterward. Opening a file first
performs a bounded timestamp probe; when duration cannot be qualified, Total
and Remaining show `--:--:--`. The MiSTer menu remains above the player overlay.
This overlay awaits hardware qualification; subtitle playback is not included.

The same arrow controls work for native FLAC, including whole-CD FLAC files.
N/P selects embedded CUESHEET INDEX 01 track starts; a separate `.cue` file is
not read. P selects the previous track (clamped at the first), and N on the
last track does nothing. Playback continues between tracks without interruption.
Both track changes and timed seeks preserve pause and land at the exact target
sample after CRC-checked preroll. The progress times refer to the whole album.

The core caches up to 99 CD tracks and 512 FLAC seek points in block RAM.
Missing seek points fall back to decoding from the first audio frame, which
can make long jumps slow. Invalid or non-CD cue metadata disables N/P without
blocking ordinary playback or timed seeking. Seeking requires a known, nonzero
STREAMINFO sample count. Loading another file clears all navigation state.
To make one CD image with an embedded cue sheet: `abcde -d /dev/sr0 -1 -o 'flac:-8 -V' -a default,cue`.

MPG seeks in either direction probe file positions for timestamped sequence
headers and I-pictures, then restart nearby and decode the short lead-in.
This works for previously unseen content without decoding the whole skipped
interval. Partial audio frames are resynchronized, and leading B-pictures
that need an unavailable reference are discarded during startup. The screen
is blank during seeking and the OSD remains usable. Jumps clamp at the start/end
of media. Files without usable restart timestamps, including raw M2V, use the
slower reconstruction fallback. Sparse headers or unusual timestamps can also
make a seek slower; initial GOP landing may be approximate.
See the [hardware test procedure](docs/TEST_INSTRUCTIONS.md) for validation.

## Decoder and output scope

The decoder remains at 60 MHz. Smaller pictures are centered within the 720x480
raster. There is no interlaced output, Bob or Weave support. The default direct analog
output is 480p/31 kHz; this is not a 15 kHz 240p or 480i mode. The 50 Hz mode
uses an internal 720x480-active scaler raster, not 576-line decoding.
Interlace, Bob/Weave and DVD navigation are outside this development
scope. Subtitles are supported through a manually loaded SRT file. Historical v0.7–v0.9 releases describe the earlier DVD/ARM architecture.

See [building](docs/BUILDING.md), [architecture](docs/ARCHITECTURE.md), and
[hardware tests](docs/TEST_INSTRUCTIONS.md). Active sources are in `files.qip`;
the inactive MPEG2FPGA reference copy and wrappers have been removed. See
[legacy provenance](docs/LEGACY_MPEG2FPGA.md) for their Git-history location.

Supported output targets are HDMI through 1920x1080 and standard CRT resolutions.
ASCAL image width is capped at 2048 pixels; the analog output path is retained.
The unused Linux ALSA path is disabled. Screen telemetry, reporting-only
circuitry and legacy LED diagnostics are removed; functional decode/transport
checks remain active. FPGA movie audio and the Audio test menu remain enabled
until diagnostic-removal gate three.

On a clean end of file, the core finishes queued video and audio and returns to
the startup screen, clearing times, playback controls and loaded subtitles.
Select a movie to start again; playback positions are not remembered. Paused
playback stays paused at the endpoint until resumed. Opening another movie
replaces the previous session immediately through the safe restart path.

## Native music waveform (pending hardware validation)

The next waveform candidate draws cyan left-channel and orange right-channel
traces during native FLAC playback, behind the player UI and stock OSD. It uses
post-volume output samples, a roughly 23 ms history and a coherent snapshot per
HDMI frame. Pause and mute settle the traces to silence; replacing the file
clears the history. This is HDMI-only and does not add a spectrum analyzer.

Generate RTL previews and run verification with:

```sh
python3 tools/verify_waveform_visualizer.py --output results/waveform --synthesize
```

The separate punctuation build `6d460d2` does not include the visualizer.
