# MiSTer Media Player v0.9.5 release notes

v0.9.5 replaces the ARM-helper/DVD-navigation path introduced in v0.7.0-v0.9.0
with playback implemented entirely in FPGA logic: MPEG-2 Program Stream video
with MP2 audio, standalone or embedded-CUESHEET album FLAC with full track
navigation, SRT subtitles, a transport UI, and three native audio visualizers.
No HPS software or soft CPU is involved in the playback path.

This remains a developer-oriented pre-release with a deliberately bounded
subset rather than general MPEG-2 systems or DVD conformance.

## Highlights

- Native FPGA FLAC album playback: embedded CD CUESHEET/SEEKTABLE parsing,
  N/P track navigation, and video-style keyboard seeking (+/-10s, Ctrl
  +/-30s, Ctrl+Alt +/-5min), all in RTL with no HPS involvement.
- Three native audio visualizers sharing the post-volume PCM tap: Waveforms
  (dual-trace oscilloscope), FFT (quantized spectrum blocks with red
  peak-hold markers), and O-Scope (green-phosphor stereo XY vectorscope
  with genuine multi-level phosphor decay).
- Track-first audio transport UI: three seconds of track progress before
  album progress on playback start and natural track changes; pause, seek
  and F1-F8 (which now always divide the current track) show track-only
  feedback.
- Audio graphics respect the selected 4:3/16:9 aspect ratio, and video-only
  menu entries (Color matrix, Refresh rate, Subtitles) gray out during
  native audio playback.
- `tools/create_mpg.txt` documents the project's ffmpeg Program Stream
  recipe (quality/frame-rate/aspect variants); `tools/pack_flac_album.py`
  and `tools/unpack_flac_album.py` bundle adjacent tracks into a CD-format
  embedded-CUESHEET album FLAC and split one back into numbered tracks.

## Changed from v0.9.0: DVD/ARM-helper path removed

**DVD-authored navigation and ARM-helper decode are no longer part of this
core.** v0.9.0 added encrypted/decrypted DVD ISO and direct-disc playback
with authored menus (via libdvdnav) and helper-decoded WAV/FLAC/Ogg Vorbis
audio. None of that remains: there is no helper binary, no patched Main, and
no DVD launcher file in this release. Program Stream `.mpg`/`.mpeg` video and
FLAC audio are decoded natively in the FPGA instead. Anyone relying on DVD
disc/ISO playback or the ARM-helper audio formats (WAV, Ogg Vorbis) should
stay on v0.9.0 until/unless that capability returns in a later release.

## Required runtime files

This release is FPGA-only — there is no Main patch or helper to match.

| Release file | Size | SHA-256 |
| --- | ---: | --- |
| `MediaPlayer_20260915.rbf` | 4,520,032 | `7ca9345347c88f689860a6fd6a0d13cdbc43019cbe678dfee4c73508fa3393fc` |

Copy the RBF to the SD card root alongside `menu.rbf`, same as any other
MiSTer core; see `INSTALL.md` for the full walkthrough.

## Supported v0.9.5 subset

- MPEG-2/H.262 progressive 4:2:0 video up to 720x480, full I/P/B-picture
  support including B-picture display-order reordering, at any of H.262's
  eight standard frame rates.
- MP2 audio: MPEG-1 Layer II, 48 kHz, stereo/dual-channel/joint-stereo,
  demuxed from the Program Stream.
- FLAC: standalone files and embedded-CUESHEET albums, fixed 44.1 kHz/
  16-bit/stereo profile, full subframe/residual/stereo-decorrelation syntax.
- SRT subtitles: bounded streaming parser, adjustable timing offset and
  playback speed, two lines of 63 characters.
- Audio visualizers: Waveforms, FFT, O-Scope (see `docs/VISUALIZERS.md`).

## Known limitations

- This remains a pre-1.0 compatibility release, not complete MPEG-2
  conformance.
- No DVD ISO/disc navigation, no ARM-helper audio formats (WAV, Ogg
  Vorbis) — see the DVD/ARM-helper removal note above.
- Interlaced/field-structured video, non-4:2:0 chroma, resolutions above
  720x480, and non-default quantization matrices are valid H.262 this
  decoder does not implement.
- FLAC and MP2 audio are both fixed to a stereo-only profile; mono is not
  accepted by either.
- Subtitles are plain-text SRT only, with in-line formatting tags stripped
  rather than rendered.

## Reproducible qualification

- FPGA toolchain: Quartus Prime Lite 17.0.2 Build 602, fitter seed 61, HIGH
  ALM register-packing effort, 6 parallel processors.
- Source commit `1720960`. The preceding Project Refresh reorganized file
  layout and documentation without changing RTL content; this build's RBF
  is byte-for-byte identical (SHA-256 above) to the pre-reorganization
  `68f32c7` seed61 build.

## Quartus and timing

- Fit: 35,817 / 41,910 ALMs (85%), 51,622 registers, 4,158,522 / 5,662,720
  block-memory bits (73%), 546 / 553 RAM blocks (99%), 75 / 112 DSP blocks
  (67%), 4 / 6 PLLs (67%).
- All four TimeQuest sign-off corners pass with zero total negative slack:

  | Corner | Setup | Hold | Recovery | Removal | Min pulse width |
  | --- | ---: | ---: | ---: | ---: | ---: |
  | Slow 1100mV 100C | +0.236 ns | +0.237 ns | +3.468 ns | +0.561 ns | +0.925 ns |
  | Slow 1100mV -40C | +0.127 ns | +0.166 ns | +3.574 ns | +0.482 ns | +0.925 ns |
  | Fast 1100mV 100C | +2.926 ns | +0.133 ns | +4.848 ns | +0.262 ns | +0.925 ns |
  | Fast 1100mV -40C | +3.526 ns | +0.045 ns | +5.105 ns | +0.179 ns | +0.925 ns |

- Two exploratory seeds were also swept from the same source: seed 12 fails
  setup on the Slow 1100mV -40C corner (-0.068 ns); seed 11 fails setup on
  both slow corners (-0.124 ns, -0.139 ns). Seed 61 is the only one of the
  three that closes timing on every corner and remains the qualified
  candidate.

## Hardware evidence

The project owner accepted this exact RBF on the test MiSTer, covering the
XY O-Scope, FFT peak-hold markers, Fire-block spectrum rendering, track-first
audio transport UI, FLAC album navigation and keyboard seeking, aspect-correct
audio graphics, and the standing MPG/FLAC regression set.

## Packaging

`MiSTer_Media_Player_v0.9.5.zip` contains the RBF, `tools/` (the ffmpeg
recipe and FLAC album pack/unpack scripts), `INSTALL.md`, `SOURCE.txt`
(build provenance), `SHA256SUMS`, and the project license.

- ZIP size: **2,098,997 bytes**.
- ZIP SHA-256: `da1c8766d79b8184b467213e6e125a1a45c41c28ad3d5c2f9e98b2396fae02fa`.
- Uncompressed member total: 4,553,165 bytes across 9 entries (8 files, 1
  directory). All `SHA256SUMS` entries pass and ZIP integrity reports no
  errors.
