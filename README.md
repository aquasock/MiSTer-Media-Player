# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. **v0.8.0 is the current milestone**, adding a bounded 720x480 interlaced frame-DCT all-I path with native 480i presentation, AC-3 decode, and AC-3/DTS passthrough over S/PDIF, on the v0.7.0 Program Stream, PTS, and ARM-helper foundation.

Current `master` extends that released baseline with simulation-qualified
720x480 interlaced frame-picture P/B decoding, frame or field motion, and frame
or field DCT. A clean Quartus fit and MiSTer playback qualification are still
required before that extension becomes a released capability.

## Current status

The active decoder is the clean H.262 implementation under `rtl/mpeg2_new/`. v0.8.0 provides:

- raw MPEG-2 Video elementary-stream playback, a bounded H.222.0 MPEG-2 Program Stream path for `.mpg` and `.mpeg` files, and audio-only `.mp3`, `.wav`, `.flac` or Ogg Vorbis `.ogg` playback;
- decrypted or CSS-encrypted DVD ISO and direct USB optical-disc playback,
  including authored first-play/root menus, highlighted button navigation,
  previous/next chapter controls and pause/resume;
- a matching ARM helper that demultiplexes Program Streams, decodes MPEG Layers II/III, WAV, FLAC, Ogg Vorbis or AC-3 audio to signed stereo PCM, and transports video, picture PTS, and PCM or passthrough bursts to the FPGA;
- byte-exact raw `.m2v` pass-through with a synthetic 90 kHz fallback timeline;
- Program Stream picture PTS driving the FPGA 90 kHz presentation timeline;
- timestamp-indexed keyboard seeking for ordinary `.mpg` and `.mpeg` files in
  10-second, 1-minute, or 5-minute jumps;
- sample-position keyboard seeking for standalone `.mp3`, `.wav`, `.flac` and
  `.ogg` files with the same fixed jumps;
- cadence as a mandatory floor: PTS may delay a picture but never presents it earlier than its encoded H.262 frame cadence;
- hardware-qualified H.262 frame-rate codes 1 through 5: `24000/1001`, exact 24, 25, `30000/1001`, and exact 30 fps;
- MPEG Layer II Program Stream audio and standalone MPEG-1 Layer III audio at 44.1 kHz and 48 kHz through an 8,192-frame stereo PCM FIFO;
- a standalone-audio 720x480p interface rendered by the ARM helper, with a full-screen 4:3 CRT-safe album-art, metadata, playlist and transport composition plus track-relative elapsed, remaining and progress presentation;
- a clean-video queue so decoder backpressure cannot prevent timely PCM delivery;
- continuous progressive 4:2:0 I/P/B decoding, retained DDR3 reference banks, separate B scratch storage, and coded-order/display-order presentation;
- full 8-bit Y, Cb, and Cr reconstruction with limited-range BT.601 presentation;
- clean Program Stream and raw-stream terminal handling, including reordered-picture flush and one explicit PCM end marker;
- a 720x480 interlaced frame-picture, frame-DCT, all-I subset with preserved top- or bottom-field-first order and native 480i timing;
- AC-3 decode to stereo, and AC-3 or DTS passthrough to S/PDIF as IEC 61937 bursts for an external decoder.

The supported subset is intentionally bounded while the architecture is being proven. These are implementation limits, not limits of H.262 or H.222.0.

| Area | Current implementation |
| --- | --- |
| Input | Raw MPEG-2 Video `.m2v`, bounded MPEG-2 Program Stream `.mpg` / `.mpeg`, decrypted or CSS-encrypted DVD `.iso` and direct USB DVD playback through `/dev/sr0`, including authored menus, or audio-only MPEG-1 Layer III `.mp3`, RIFF WAVE `.wav`, FLAC `.flac` and Ogg Vorbis `.ogg` through the ARM helper |
| Video, progressive | 4:2:0 I, P and B pictures through 720x480 |
| Video, interlaced | Current `master`: 720x480 at 30000/1001, 4:2:0 frame pictures with I, P and B coding, frame or field motion, frame or field DCT, top- or bottom-field-first presentation, and mixed ordinary-interlaced/progressive-film frames within one interlaced sequence. Field pictures remain unsupported; Quartus and MiSTer qualification are pending |
| Picture types | Coded-order/display-order presentation with B reordering |
| Presentation rates | H.262 frame-rate codes 1..5; codes 6..8 are rejected before transport |
| Program Stream timing | Picture PTS on a 33-bit / 90 kHz FPGA timeline with cadence-floor enforcement |
| Raw-stream timing | Synthetic 33-bit / 90 kHz cadence derived from H.262 frame-rate metadata |
| Audio | MPEG Layer II or standalone MPEG-1 Layer III at 44.1 or 48 kHz, ordinary PCM/float WAV, FLAC and Ogg Vorbis converted to stereo at 44.1 or 48 kHz, and AC-3 at 48 kHz. The AC-3 stereo downmix discards LFE |
| Audio passthrough | AC-3 and DTS carried to S/PDIF as IEC 61937 bursts for an external decoder. DTS is passthrough only; there is no DTS decoder |
| Audio output | A menu option selects HDMI or S/PDIF. The unused output is muted, because both are fed from one stereo stream |
| Audio buffering | Packed signed PCM records into an 8,192-frame stereo FPGA FIFO |
| Audio-only display | ARM-rendered planar 720x480 YCbCr 4:2:0, transferred in bounded records to an inactive DDR frame bank and published atomically at a safe frame boundary. The CRT-safe 4:3 layout reserves album art, title/artist/album metadata, playlist, transport and time fields and tracks absolute file-relative progress at one-hertz resolution |
| Frame storage | Retained planar MiSTer DDR3 I/P banks and separate B scratch storage; native all-I overlap uses a bounded three-region ordinary frame queue |
| Video output | Native 720x480p at 60000/1001 for supported progressive input, or native 720x480i at 30000/1001 for supported interlaced input |

The frozen `rtl/mpeg2fpga/` tree remains historical reference material and is not part of the active Quartus build.

## Installation

Download the [v0.8.0 pre-release](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.8.0). It requires three matching runtime files. Back up the existing files before replacing them, and verify the unpacked files against the package's `SHA256SUMS`.

| Release file | MiSTer destination | SHA-256 |
| --- | --- | --- |
| `MediaPlayer_20260827.rbf` | `/media/fat/MediaPlayer_20260827.rbf` | `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce` |
| `MiSTer` | `/media/fat/MiSTer` | `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9` |
| `linux/MediaPlayer_Helper` | `/media/fat/linux/MediaPlayer_Helper` | `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8` |

`MiSTer` is a patched Main and is not optional: it passes the core's `Audio output` selection to the helper and yields during backpressured media transfers to keep the menu responsive. An older Main may display the core's option without passing its selection to the helper. The helper must be executable. Reboot after installing Main. Mixing v0.8.0 components with a different Main, helper, or RBF is unsupported.

Current development builds can also place `assets/USB DVD Drive.dvd` at the
absolute path `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`. Selecting that
launcher opens the inserted optical disc through `dvd:/dev/sr0`; the marker's
contents are not media data. The drive does not need to be mounted.
The helper authenticates and selects the title once, reuses that navigation
session during preflight, then fills a 4 MiB launch reserve inside an 8 MiB
HPS-RAM ring before playback begins. The ring is direct-disc-only and does not
consume FPGA M10K memory.

The development menu separates `Run DVD-Video`, `Open MPEG-2 Video`, and
`Open WAV, MP3, FLAC, OGG` so each picker exposes only its relevant files.
Aspect Ratio defaults to 16:9 with 4:3 as the alternate; Deinterlacer Mode
offers Bob and Weave. Telemetry defaults to Off for normal playback; turning it
On reveals the internally captured hardware snapshot and enables the combined
Main/helper diagnostic log on the next playback start. The Audio Test and Audio
Output choices are unchanged.

For `.iso` and `.dvd` playback, player-one Left and Right select the previous
or next chapter and Start toggles pause/resume while the MiSTer OSD is closed.
On a keyboard, P and N select the previous and next chapter, and Space toggles
pause/resume under the same OSD-closed guard.

For ordinary file-backed `.mpg`, `.mpeg`, `.mp3`, `.wav`, `.flac` and `.ogg`
playback, Alt+Left/Right jumps backward or forward 10 seconds,
Ctrl+Left/Right jumps 1 minute, and Ctrl+Alt+Left/Right jumps 5 minutes. Program
Streams use a sparse video-PTS index; standalone audio uses the decoder's PCM
sample timeline. Main leaves the active presentation running while the helper
decides each request; only a valid target's READY response enters the clean
download reset and GO barrier, so no pre-jump bytes or partial audio-interface
frame crosses that reset. These
controls do not apply to raw `.m2v`, DVD ISO images, or optical discs. A
standalone-audio forward jump that would reach or pass the exact end is ignored
with an explicit continuation response and no download reset. At clean EOF,
Main keeps the final valid MPG frame or standalone-audio interface resident and
enters a replay-ready paused state; the next Start or Space press launches the
same file again from the beginning.

In an authored DVD menu, the player-one D-pad moves the highlight, A or Start
activates it, and Select calls the root menu. Keyboard arrows, Enter (including
keypad Enter), and M provide the same actions. Main uses distinct `isomenu:` and
`dvdmenu:` launch routes for this mode; legacy `iso:` and `dvd:` retain
longest-title behavior for regression and host use. Finite menu stills honor
their authored duration, while indefinite stills remain interactive until a
navigation command. The FPGA overlay compositor is active only in native 480i.
A chapter change preserves the authenticated libdvdnav session, flushes every
old HPS/Main byte, resets the existing FPGA download session, and begins from
the selected chapter's random-access boundary. The helper retains the selected
Program Stream audio codec and DVD private substream across that reset and
performs bounded AC-3 byte resynchronization if the new chapter boundary lands
on an undecodable candidate frame. Pause intentionally holds the
Main-to-FPGA transport; a long pause can still raise the current FPGA audio
FIFO-underrun telemetry because this ARM-only boundary cannot add an explicit
pause state to the core.

## Release qualification

All three v0.8.0 runtime binaries reproduced byte for byte from source baseline `2f1d32c`. The published annotated tag points to `af43de2`; later documentation commits do not change the qualified binaries.

The clean Quartus Prime Lite 17.0.2 build used fitter seed 17 and produced the RBF listed above:

- RBF size: 4,332,740 bytes; 0 errors and 208 warnings, with the same warning identifier set as the accepted build;
- fit: 31,464 ALMs (75%), 50,273 registers, 512 of 553 M10K blocks (93%), and 67 DSP blocks;
- setup +0.243 ns, hold +0.251 ns, recovery +2.865 ns, removal +0.564 ns, and minimum pulse width +0.925 ns; all reported total negative slack is zero.

The helper is 399,340 bytes and patched Main is 1,170,340 bytes, with the hashes in the installation table. Both reproduced using ARM GNU 10.2; Main uses pinned upstream `0a8fb44`.

Recorded host regressions cover cadence telemetry, eleven DVD-ceiling tests, guarded Main transfers and fault handling, AC-3 decode/downmix, byte-identical AC-3/DTS passthrough, and the unchanged full-length MPEG Layer II PCM output. The corrected seven hand tests completed all 360 pictures each. Progressive I/P/B playback is supported by a run with 121 reference and 239 B pictures. Native interlaced tests had no deadline gaps; the native deadline counters are not a progressive cadence qualification.

The Main responsiveness fix was measured separately: maximum media-poll occupancy on test one fell from 160,937 to 9,287 microseconds, and the user reported normal menu response. The 2,000-microsecond work budget is not a hard latency guarantee. Full-movie interlaced testing is recorded separately and retains the known one-or-two-slot repeat at a large-picture scene cut.

The public ZIP and all three runtime hashes match the qualified package. A confirmation hardware run after installation from that final package remains unrecorded; publication and binary identity do not supply that missing evidence. See the [v0.8.0 release notes](docs/RELEASE_NOTES_v0.8.0.md) for the qualification scope and remaining limits.

## Releases

Milestone releases use semantic-version tags on GitHub. RBF assets retain the normal MiSTer date-coded naming convention.

Current milestone:

- **[v0.8.0](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.8.0)** — bounded native 480i all-I playback, AC-3 decode, AC-3/DTS passthrough, and responsive Main media transfers; binary `MediaPlayer_20260827.rbf`.

Previous milestones:

- **v0.7.0** — bounded Program Stream input, real picture PTS, MPEG Layer II audio, and full-length audio-video playback; binary `MediaPlayer_20260824.rbf`.
- **v0.6.0** — sustained progressive 720x480 real-stream I/P/B playback with native 23.976/24/25-fps cadence; binary `MediaPlayer_20260822.rbf`.

See [the v0.8.0 release notes](docs/RELEASE_NOTES_v0.8.0.md) for package size, hashes and publication provenance. Historical qualification remains in each version's notes and the [changelog](CHANGELOG.md).

## Converting media with FFmpeg

Two shapes play: a progressive Program Stream, and the narrower interlaced 480i
subset. Pick by what you want on screen, and read Known limitations first — most
material that fails does so because of picture structure, not encoding quality.

### Progressive

Progressive 720x480 4:2:0 with I, P and B pictures, plus MPEG Layer II or AC-3
audio. This exact-24-fps, 48 kHz recipe is a suitable starting point:

```bash
ffmpeg -hide_banner -y \
  -i "input.mp4" \
  -map 0:v:0 -map 0:a:0 \
  -vf "fps=24,scale=720:480:force_original_aspect_ratio=decrease:flags=bicubic,pad=720:480:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1" \
  -c:v mpeg2video -pix_fmt yuv420p -threads 1 -flags +bitexact \
  -g 24 -bf 2 -q:v 6 -qmin 2 -qmax 12 \
  -sc_threshold 1000000000 -mpv_flags +strict_gop \
  -c:a mp2 -ar 48000 -ac 2 -b:a 192k \
  -f vob "output.mpg"

tools/media.sh verify "output.mpg"
```

Use `-an` and omit the audio codec options for a video-only Program Stream. Raw
`.m2v` elementary streams remain supported.

For AC-3 instead, replace the audio options with `-c:a ac3 -ar 48000 -ac 6 -b:a
448k`. A 5.1 track is only heard as 5.1 through S/PDIF passthrough; in HDMI mode
it is downmixed to stereo and its LFE is discarded.

### Interlaced 480i

The released v0.8.0 path is deliberately narrow: 720x480 at 30000/1001,
4:2:0, I-pictures only, frame-structured, frame DCT and frame prediction.
Current `master` additionally admits interlaced P and B frame pictures and
implements both field motion and field DCT, including their combined case.
Those additions are covered by deterministic pixel-oracle simulations but are
not yet a hardware-qualified release.

For a simple 15-minute compatibility clip, use the shared media command:

```bash
tools/media.sh convert input.vob output.mpg
tools/media.sh probe output.mpg
```

The conversion command produces a conservative 720x480 MPEG-2 Program Stream
with 48 kHz stereo AC-3 audio. Direct DVD/VOB playback remains the preferred
test when qualifying the decoder's actual compatibility envelope.

### Audio

The supported audio paths are selected by the track's codec and
by the `Audio output` menu option together:

| Track | HDMI selected | S/PDIF selected |
| --- | --- | --- |
| MPEG Layer II, 44.1 or 48 kHz | decoded to stereo | decoded to stereo |
| Standalone MPEG-1 Layer III, 44.1 or 48 kHz | decoded to stereo | decoded to stereo |
| WAV PCM, 44.1 or 48 kHz | decoded to stereo | decoded to stereo |
| FLAC, 44.1 or 48 kHz | decoded to stereo | decoded to stereo |
| Ogg Vorbis, converted to 44.1 or 48 kHz | decoded to stereo | decoded to stereo |
| AC-3, 48 kHz | decoded to stereo, LFE discarded | passed through as IEC 61937 for your receiver to decode |
| DTS | refused, with a message in the helper log | passed through as IEC 61937 |

The option mutes the digital output it is not driving, because both are fed
from one stream. So selecting HDMI silences S/PDIF and vice versa; a silent
receiver in HDMI mode is the option working, not a fault. Passthrough carries
the bitstream untouched, so volume and any mixing must not be applied to it, and
DTS has no decoder here at all.

Use real DVD material to check the audio mode that matters for playback. HDMI
decodes AC-3 to stereo, while S/PDIF passes AC-3 or DTS to an external decoder.

With Telemetry enabled before playback starts, the MiSTer RAM file
`/tmp/MediaPlayer_ARM.log` records the selected output mode and chosen audio
substream, so a log proves which path ran. It is a single fixed path, so retrieve
it before playing anything else or the next file overwrites it. Telemetry Off
creates no log, removes a stale log at the next playback start and sends helper
diagnostics to `/dev/null`; changing only the visible hardware overlay remains
live while playback is running.

## Architecture

```text
MiSTer Main file selection
          |
          v
MediaPlayer_Helper
Program Stream demux / picture PTS
consumer audio or AC-3 decode / AC-3 or DTS burst packing
          |
          v
packed video + PTS + PCM-or-burst transport
          |
          +-----------------------+-----------------------+
          |                       |                       |
          v                       v                       v
clean-video queue          8,192-frame PCM FIFO   bounded audio-UI records
          |                       |                       |
          v                       v                       v
H.262 FPGA decoder       selected HDMI PCM or   inactive DDR frame bank
                        S/PDIF output             + safe atomic publish
          |
          v
DDR reference/B-scratch storage
          |
          v
cadence floor + 90 kHz PTS scheduler
          |
          v
native 720x480p or 720x480i video output
```

Raw `.m2v` files bypass Program Stream demux and audio decoding while retaining
the same FPGA H.262 path. Standalone `.mp3`, `.wav`, `.flac` and `.ogg` files
use the existing file channel and PCM transport without requiring video bytes.
For those files the helper also renders a limited-range BT.601 planar frame,
interleaves no more than one bounded UI record after each PCM record, and
publishes a completed frame at approximately one update per sample-clock
second. The interface lays out a physically square album-art viewport, title,
artist and album fields, a current-playlist panel, transport controls, time
fields and a full-width progress bar inside 4:3 CRT-safe margins. The decoder's
exact output-frame length scales the bar against the current absolute PCM-frame
position, including after a fixed seek. Elapsed, total track and remaining time
occupy three independently centered fields on one baseline. Elapsed time uses
the absolute completed seconds; total and remaining time round up partial final
seconds, and remaining reaches `00:00` only on the exact completed frame. Clean
helper EOF retains that final interface instead of replacing it with black,
then the next Play input restarts the file from the beginning. Artwork, tags,
playlist entries, playlist/track summary fields and arbitrary-position
scrubbing remain later boundaries.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`host/arm/ARCHITECTURE.md`](host/arm/ARCHITECTURE.md) for design details.

## Building

The FPGA project targets Quartus Prime 17.0.x:

```bash
tools/build.sh
tools/build.sh timing
```

Build the ARM helper and matching patched Main with the ARM GNU 10.2 compiler used by MiSTer Main:

```bash
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc tools/build.sh host arm
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc tools/build.sh host main
```

The build script pins minimp3, miniaudio, stb_vorbis, liba52, MiSTer Main, dependency hashes, and the Main patch. Release candidates require reproducible FPGA, helper, and Main binaries plus host and MiSTer regression evidence. See [building and testing](docs/BUILDING.md) for the current workflow.

## Known limitations

- Program Stream support is bounded; MPEG Transport Stream, DVD LPCM, subtitle-track presentation, angles and arbitrary systems-layer layouts are not supported. Authored DVD menus use DVD subpictures only for their button overlay and run in native 480i; ISO and direct `/dev/sr0` playback use statically linked libdvdcss for encrypted sectors. DVD private stream 1 supports AC-3 decode/passthrough and DTS passthrough.
- Decoded audio is MPEG Layer II or standalone MPEG-1 Layer III at 44.1 or 48 kHz, ordinary PCM/float WAV, FLAC and Ogg Vorbis converted to stereo at 44.1 or 48 kHz, and AC-3 at 48 kHz. MPEG-1 Layer III at 32 kHz and MPEG-2/2.5 Layer III remain rejected; AAC is not enabled. Only the first Program Stream audio track is played; chapter changes retain that identity, while deliberate track switching needs a control channel that protocol one does not implement.
- AC-3 is downmixed to stereo for decoded output, which discards LFE. Discrete surround requires passthrough and an external decoder.
- Passthrough carries the bitstream untouched, so nothing may scale it. The audio output option therefore mutes the output it is not driving, and volume control does not apply to a passthrough stream.
- The standalone-audio screen contains a CRT-safe 4:3 composition for album artwork, title/artist/album tags, the current playlist, transport controls, centered elapsed/total/remaining time and a duration-relative progress bar. Track timing, fixed keyboard seeking and absolute progress tracking are active; artwork, metadata, playlist entries, playlist summary fields, arbitrary-position scrubbing and FPGA-aware pause state remain later display boundaries.
- Progressive 4:2:0 video is released through 720x480 and decodes I, P and B pictures. Current `master` also implements 720x480-at-30000/1001 interlaced frame-picture I/P/B decoding with frame or field motion, frame or field DCT, per-picture `repeat_first_field`, and mixed ordinary-interlaced/progressive-film frame pictures, but this remains simulation-qualified until a clean fit and MiSTer playback pass. Field pictures and 576i remain rejected. DVD subtitle tracks and broader systems-layer behavior remain separate limitations.
- Comprehensive playback pixel accuracy remains unqualified. Simulation comparisons cover decoder reconstruction, and a targeted hardware-screenshot comparison found the chroma-edge difference below; that comparison is not a full playback pixel-validation suite.
- Sharp colour transitions show one blended pixel column that an independent software decoder does not produce, consistent with horizontal chroma upsampling in the display path. It is obvious on synthetic colour bars and subtle on ordinary material, and it is not specific to any picture type.
- On material whose peak coded picture is large enough, one or two display slots are missed at that picture, shown as a repeated frame rather than a dropped one. This is a property of input buffer depth against peak picture size, not of the stream; the qualified full-length fixture hits it once, at a scene cut.
- The framework scaler has little timing margin: seed 16 missed setup by 0.070 ns after audio routing changed; the seed-17 release has +0.243 ns worst setup. Future logic changes may expose the path again, and 93% M10K usage limits buffering headroom.
- H.262 frame-rate codes 6 through 8 (50, 59.94, and 60 fps) are rejected.
- Arbitrary-position scrubbing and seeking in raw `.m2v`, DVD ISO, and
  optical-disc playback are not implemented; ordinary `.mpg`/`.mpeg` and
  supported standalone-audio files provide only the fixed keyboard jumps
  documented above. DVD
  title/angle/audio/subtitle-track selection, drive discovery beyond
  `/dev/sr0`, and software-controlled ejection are also not implemented.
  ARM-side pause/resume is a transport hold; until an FPGA pause state is
  added, a long pause may set the existing audio-underrun telemetry before
  playback resumes.
- Output offers two interlaced tiers. Normal processed HDMI sends native 480i timing into MiSTer's scaler and lets the `HDMI scaler deinterlacer` menu choose Weave or Bob. The external-processing tier preserves native 480i fields; truly unscaled HDMI additionally requires MiSTer's separate `direct_video` setting, which the core menu cannot enable.
- Files should be opened through the normal MiSTer file menu; MGL injection is not a qualified loading method.

### Native elementary-stream startup

The clean-video queue holds up to 64 KiB. For native 29.97-fps all-I video
without PTS or PCM records, the first cached picture stays black until a second
picture is presentable (or sequence end arrives for a one-picture file). It is
then shown at a complete field-pair boundary, with swaps starting on subsequent
boundaries. HS, VS, DE and the raster clock stay continuous. This adds startup
reserve; it does not change playback speed or accelerate decoding. Timestamped
video, audio and other modes bypass the reserve. A new download rearms it;
Bob/Weave changes do not.

Schema 19 still timestamps its first presentation at **first reference decode
completion**, so its aggregate rate includes startup wait. Use the subsequent
swap intervals and deadline-gap counts to assess steady cadence. The simulation
runner additionally reports `visible_start_cycle` and `visible_span_cycles`;
its FIFO/host/DDR and field-window models are not a full HDMI hardware replay.

## Playback evidence

Use the first 15 minutes of real DVDs as the normal stability test. Capture the
current helper log and scaled MiSTer screenshots before starting the next file:

```bash
tools/mister.sh log
tools/mister.sh screenshot playback.png
tools/mister.sh screenshot-stream 60 playback-frames
```

## Project layout

- `MediaPlayer.sv` — MiSTer top-level integration, transport, queues, audio, and presentation scheduling.
- `rtl/mpeg2_new/` — active H.262 decoder pipeline.
- `rtl/mpeg2_luma_framebuffer.sv` — DDR-backed frame readback and video-side line caching.
- `host/arm/` — ARM helper, media source, and packed transport protocol.
- `host/main_mister/` — pinned patch adding helper-based media loading to MiSTer Main.
- `tools/` — compact commands for Quartus, host builds, MiSTer transfers, screenshots, and media preparation.
- `rtl/mpeg2fpga/` — frozen legacy reference; inactive in `files.qip`.
- `docs/` — architecture, building, testing, and release documentation.

## Development roadmap

Future work can extend the qualified envelope toward 50/59.94/60 fps, field-picture structures and 576i, broader Program Stream handling, additional audio codecs and multi-track selection, qualification of playback pixel accuracy against a software decoder, improved chroma presentation, an FPGA-native pause state, DVD seeking and arbitrary-position scrubbing, DVD subtitle presentation and title/angle selection, optical-drive discovery, and qualification of native 480i through external HDMI-to-SDI hardware.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Program Stream, PES, and timing work uses **ITU-T H.222.0 / ISO/IEC 13818-1**. Program Stream MPEG Layer II is decoded by the pinned minimp3 source; standalone MPEG Layer III and RIFF WAVE/FLAC decode, channel conversion, resampling and sample-position seeking use pinned miniaudio source, whose Ogg Vorbis backend uses pinned stb_vorbis source. DVD ISO access uses pinned libdvdcss, libdvdread and libdvdnav sources. These dependencies are compiled directly into the static helper binary; libdvdcss is an implementation dependency and does not establish DVD CSS conformance.

AC-3 decode is performed by the pinned liba52 dependency, and IEC 61937 framing follows that standard for passthrough.

Implementation constraints, qualification limits, and engineering diagnostics are implementation choices rather than MPEG standard requirements. In particular, the picture types and structures this core rejects are limits of this implementation, not of H.262.

## AI-assisted development

The **AI project-control system** used to manage MiSTer-Media-Player was formally exposed with the v0.6.0 milestone for contributors interested in experimenting with it.

The `.ai` directory had already been driving much of the project's development before v0.6.0 made it a documented contributor workflow.

The basic idea is simple:

**AI agents are temporary. The repository is authoritative.**

There is a plain-text bootstrap procedure in:

`/.ai/core-bootstrap.md`

I can give that bootstrap text to a fresh AI session on a supported platform and have it recover the project state from the repository. It reads the authoritative project-control files, the recent development history, the current source state and the latest validation results.

From there I can usually just tell it:

`continue`

and development resumes from the latest recorded engineering state.

The important part is that I do **not** rely on a long-running AI conversation to remember the project correctly.

### Why the `.ai` directory exists

FPGA development can consume an enormous amount of AI context very quickly. Build logs, Quartus reports, simulation results, timing failures, diagnostic experiments and source changes all add up.

I found that keeping too much history in active context actually made the agents substantially worse.

The main mechanism I currently use to control this is the ring-buffer history in `.ai/core-log.md`.

I experimented with different sizes:

- ~100 entries retained too much irrelevant history and sessions became unreliable.
- ~20 entries forgot useful diagnostic history and sometimes repeated already-completed experiments.
- ~40 entries has been a good balance so far.

I may experiment with reducing that further.

The goal is to keep the agent working inside a small, relevant engineering context while the permanent project history remains in Git.

### Development philosophy

The system is designed around a few rules:

- **Agents are disposable.**
- **The repository is authoritative.**
- **The AI platform should not matter.**
- **A new session should be able to recover the project without relying on conversational memory.**
- **AI-generated changes are not trusted simply because an AI produced them.**
- **Simulation, regression tests, Quartus fitting, TimeQuest timing and real MiSTer hardware remain the validation authority.**

That last point is important.

The AI can propose RTL all day long. If the regression fails, timing fails, Quartus fails, or the MiSTer hardware fails, then the change is wrong.

### Contributing with an AI agent

If you want to experiment with AI-assisted FPGA development on this project:

1. Fork or clone:
   
   `https://github.com/aquasock/MiSTer-Media-Player`

2. Configure your **local copies** of `.ai/core.md` and `.ai/core-bootstrap.md` for your own development environment.

3. Make sure your workflow includes checking the upstream project's current `.ai/core-log.md` before making changes so your agent understands what has changed on the main project since your fork diverged.

4. Work normally on your branch and retain your build/test history.

5. If the work turns into something worth merging, open a normal contribution with both the source changes and the relevant `.ai/core-log.md` history.

The log is useful because it gives the integration agent much more than just a diff. It explains:

- what was attempted,
- what failed,
- what was measured,
- what was hardware-tested,
- and why the final implementation looks the way it does.

I experimented with this concept separately in:

`https://github.com/aquasock/MiSTer-Media-Player-Audio`

That was an early dry run with an older core.md file and did well.

### If you just want to experiment

You do not need Quartus or even an FPGA development environment just to see how the recovery system behaves.

You can copy the bootstrap text from `.ai/core-bootstrap.md` into a **fresh AI session** and let it initialize the project.

Once recovery is complete, try:

`continue`

Obviously, without the required local tools, repository permissions and Quartus environment, it will not be able to perform the complete development workflow. But it should still be able to recover and reason about the current project state.

### Security warning

One very important warning:

**Never give an unknown AI bootstrap prompt control of your development environment without reading it first.**

Treat an AI bootstrap procedure the same way you would treat an unfamiliar shell script.

Before using mine—or anyone else's—I strongly recommend:

1. Read `core-bootstrap.md`.
2. Read `core.md`.
3. Understand what resources and permissions the agent is being instructed to use.
4. Audit the rest of the `.ai` directory.
5. If possible, have a separate sandboxed session inspect it for prompt-injection tricks, hidden instructions or unexpected external actions before running it with real repository credentials.

The goal here is not “let AI loose on an FPGA project.”

It is almost the opposite:

**make the AI disposable, constrain what it is allowed to believe, preserve the engineering state outside the conversation, and require normal FPGA validation before anything becomes authoritative.**

v0.6.0 was the first release to treat this workflow itself as something the community could beta test.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
