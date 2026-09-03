# MiSTer Media Player v0.9.0 release notes

v0.9.0 is the DVD navigation, native-video, consumer-audio and playback-control
milestone. It advances the v0.8.0 native-480i foundation into practical DVD
ISO and direct optical-disc playback with authored menus, expands interlaced
I/P/B decoding, replaces the progressive diagnostic raster with native 480p,
and adds a complete standalone-audio experience.

This document currently describes the **v0.9.0 release candidate**. The user is
performing final functional and regression testing. The annotated tag, public
package identity and final clean-build reproduction data will be added only
after qualification; v0.9.0 has not yet been published.

## Highlights since v0.8.0

- Play decrypted or CSS-encrypted DVD-Video from `.iso` images or a USB drive
  exposed as `/dev/sr0`. DVD libraries and CSS support are linked into the
  helper; MiSTer does not need a separately installed `libdvdcss` package.
- Use authored first-play, root and submenu navigation with button highlights,
  scene-selection pages and automatic actions. DVD stills and overlay-only
  transitions retain an interactive, stable presentation.
- Navigate with player-one D-pad/A/Start/Select or keyboard arrows/Enter/M;
  use player-one Left/Right or P/N for chapters and Start or Space to pause.
- Decode 720x480 interlaced frame-picture I, P and B video with frame or field
  motion and DCT modes, field-order metadata, repeat-first-field scheduling and
  mixed ordinary-interlaced/progressive-film frames. Field pictures and 576i
  remain outside the implementation envelope.
- Present progressive video as native 720x480p at `60000/1001` and supported
  interlaced video as native 720x480i at `30000/1001`.
- Seek ordinary `.mpg` and `.mpeg` files by 10 seconds, 1 minute or 5 minutes;
  `.vob` files are now visible in the MPEG-2 picker.
- Play standalone MP3, WAV, FLAC and Ogg Vorbis through a 720x480 player screen
  with elapsed, total and remaining time, progress, fixed-step seeking and
  clean replay from the beginning after EOF.
- Use the optional MPEG-2 visualizer pack during standalone audio. Its eight
  color/brightness grades track PCM loudness, the player interface remains as
  a translucent scanline-style overlay for ten seconds after user activity,
  and animation cadence remains constant while playing or paused.
- Enable production telemetry only when needed. Telemetry defaults Off; On
  exposes the hardware snapshot and creates `/tmp/MediaPlayer_ARM.log` for the
  next playback.

## DVD behavior

The release uses libdvdnav for first-play and authored-menu state. Stream hops
cross a private helper/Main READY/GO barrier that drains old data, resets the
download session and prevents stale bytes from entering the next menu, still,
scene or title. Direct optical playback reuses its authenticated navigation
session and reads through an 8 MiB HPS-RAM ring with a 4 MiB startup reserve to
absorb normal drive stalls.

Unsupported DVD LPCM and other unsupported private-audio substreams are skipped
rather than treated as fatal. A menu authored with LPCM can therefore remain
interactive but silent and then transition to a title with supported AC-3,
MPEG audio or DTS passthrough. DVD LPCM is not decoded in v0.9.0.

Some commercial discs contain a nonconforming 4:2:0 progressive-frame chroma
flag in authored stills. The helper contains a narrow, syntax-validated
compatibility normalization for that one-bit contradiction, including repeated
sequence boundaries. It does not change conforming streams or alter the FPGA
decoder's H.262 validation rules.

## Required runtime set

The package contains a matching date-coded RBF, patched `MiSTer`, executable
`linux/MediaPlayer_Helper`, and optional
`linux/MediaPlayer_Visualizer.mmpvis`. Direct USB-disc playback additionally
uses `games/MediaPlayer/USB DVD Drive.dvd`. The RBF, Main and helper must remain
a matched set; standalone audio falls back to its ordinary interface when the
visualizer is omitted.

The current tested candidate combines:

- timing-qualified RBF source `dfe1057`, built as
  `MediaPlayer_20260901.rbf`;
- patched Main source `3689cca`;
- visualizer/interface source `932dc22`, using the native-interlaced visualizer
  pack introduced at `366a227`;
- final helper compatibility source `0f1165c`.

The exact artifacts used for the current candidate testing are:

| Candidate file | Size | SHA-256 |
| --- | ---: | --- |
| `MediaPlayer_20260901.rbf` | 4,480,236 | `6389fa57b2d642b5b4e85980c6ccf8746ea8d20869cbe480f80b0ea172bcdb4b` |
| `MiSTer` | 1,182,692 | `1b3387170083be269831bf4c3a828f1cce6bcb3b93c519d8cde32cb9768bedf9` |
| `linux/MediaPlayer_Helper` | 966,052 | `613d35de5ace0622584ae14b4540423c2c56b1f923c02c599f47b55722e21e56` |
| `linux/MediaPlayer_Visualizer.mmpvis` | 3,740,562 | `448407cdd7e6c79fbe13cbb435241116127f726aca5af9f99d75b32fc2519f47` |
| `games/MediaPlayer/USB DVD Drive.dvd` | 111 | `4757d49e9d1b94d88f554b3bd3157ed5d2064caaa65a6cf0f856e8ab6fbe2d2e` |

These hashes identify the tested candidate and are not yet release-package
provenance. Final package filenames and SHA-256 values will be recorded after
the clean release build; the published package's `SHA256SUMS` will then be
authoritative.

## Candidate FPGA qualification

The unchanged source-`dfe1057` RBF was built with Quartus Prime Lite 17.0.2 and
fitter seed 24. It completed with zero errors and positive timing in every
required category: +0.180 ns setup, +0.190 ns hold, +3.758 ns recovery,
+0.644 ns removal and +0.925 ns minimum pulse width, with zero violated paths.
Dedicated 60 MHz decoder and 54 MHz video setup margins were +1.220 ns and
+2.215 ns. The fit used 34,859 ALMs, 54,492 registers, 4,187,219 block-memory
bits in 536 RAM blocks, 70 DSP blocks and 3 PLLs.

That RBF is 4,480,236 bytes with SHA-256
`6389fa57b2d642b5b4e85980c6ccf8746ea8d20869cbe480f80b0ea172bcdb4b`.
This identifies the current hardware-tested candidate and does not replace the
required final clean/from-scratch release reproduction.

## Validation scope

Deterministic host and simulation coverage accumulated since v0.8.0 includes
interlaced field-motion and field-DCT reconstruction, mixed-film scheduling,
audio FIFO pacing, native output timing, DDR arbitration, audio-interface and
visualizer transport, Program Stream/audio seeking and EOF, DVD random access,
subpicture rendering, menu navigation, still termination, staged transitions,
reserve cancellation, unsupported LPCM handling and the malformed-chroma
compatibility boundary.

Physical development testing has covered `.mpg` playback, standalone MP3/WAV/
FLAC/Ogg playback, the ten-second visualizer transition, encrypted direct-disc
startup, root menus, scene selection, scene-page changes, chapter navigation,
pause/resume and repeated title/menu transitions across multiple commercial
DVDs. The final release regression is still underway.

## Known limitations

- This remains a pre-1.0 compatibility release, not complete MPEG-2 or DVD
  conformance.
- Field-picture H.262 structures, 576i and frame-rate codes 6 through 8 are not
  supported.
- MPEG Transport Streams, AAC, DVD LPCM decode, DVD subtitle presentation,
  title/angle/audio/subtitle switching and general DVD seeking are not present.
- DTS is passthrough-only. AC-3 decoded output is stereo and discards LFE;
  discrete surround requires S/PDIF passthrough and an external decoder.
- Only the first supported Program Stream/DVD audio track is selected.
- The optical launcher targets `/dev/sr0`; automatic drive discovery and
  software-controlled eject are not implemented.
- File seeking uses fixed keyboard jumps. Raw `.m2v`, DVD ISO and optical-disc
  playback do not support arbitrary-position scrubbing.
- Pause is an ARM-side transport hold. A long pause can set the existing FPGA
  audio-underrun telemetry even though playback resumes normally.
- The audio-player artwork, metadata and playlist regions remain reserved UI;
  album-art/tag parsing and playlist population are not implemented.
- The visualizer uses fixed loudness thresholds rather than per-track automatic
  gain and falls back to the ordinary audio-player screen if its pack is absent.
- A targeted hardware comparison found one blended pixel column at sharp color
  transitions; comprehensive playback pixel accuracy remains unqualified.

## Preparing `.mpg` files

Use the project's [recommended FFmpeg recipe](MEDIA_CONVERSION.md) for a
conservative 720x480 exact-24-fps Program Stream with stereo MP2 audio.
