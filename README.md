# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-1.0. **v0.9.0 is the current milestone**,
> adding encrypted DVD ISO and direct USB-disc playback, authored menus and
> navigation, expanded native interlaced decoding, file/audio seeking, a
> standalone-audio interface and an optional MPEG-2 visualizer.

## Current status

The active decoder is the clean H.262 implementation under `rtl/mpeg2_new/`.
v0.9.0 provides:

- raw MPEG-2 Video elementary-stream playback, a bounded H.222.0 MPEG-2
  Program Stream path for `.mpg`, `.mpeg` and `.vob` files, and audio-only
  `.mp3`, `.wav`, `.flac` or Ogg Vorbis `.ogg` playback;
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
- a standalone-audio 720x480p interface rendered by the ARM helper, with a
  full-screen 4:3 CRT-safe layout reserving album-art, metadata and playlist
  regions and implementing transport, elapsed, total, remaining and progress
  presentation;
- an optional legal-H.262 visualizer pack: its seamless MPEG-2 loop is the idle
  background whenever the core is loaded, DVD or MPEG-2 media replaces it,
  and standalone audio overlays its translucent player interface for ten
  seconds before the loop's synchronized color grades follow decoded-PCM
  loudness through three-frame adjacent-grade crossfades; a missing pack
  retains audio playback but leaves the idle screen without that background;
- a clean-video queue so decoder backpressure cannot prevent timely PCM delivery;
- continuous progressive 4:2:0 I/P/B decoding, retained DDR3 reference banks, separate B scratch storage, and coded-order/display-order presentation;
- full 8-bit Y, Cb, and Cr reconstruction with limited-range BT.601 presentation;
- clean Program Stream and raw-stream terminal handling, including reordered-picture flush and one explicit PCM end marker;
- 720x480 interlaced frame-picture I/P/B decoding with frame or field motion,
  frame or field DCT, repeat-first-field scheduling, mixed ordinary-interlaced
  and progressive-film frames, and native 480i timing;
- AC-3 decode to stereo, and AC-3 or DTS passthrough to S/PDIF as IEC 61937 bursts for an external decoder.

The supported subset is intentionally bounded while the architecture is being proven. These are implementation limits, not limits of H.262 or H.222.0.

| Area | Current implementation |
| --- | --- |
| Input | Raw MPEG-2 Video `.m2v`, bounded MPEG-2 Program Stream `.mpg` / `.mpeg` / `.vob`, decrypted or CSS-encrypted DVD `.iso` and direct USB DVD playback through `/dev/sr0`, including authored menus, or audio-only MPEG-1 Layer III `.mp3`, RIFF WAVE `.wav`, FLAC `.flac` and Ogg Vorbis `.ogg` through the ARM helper |
| Video, progressive | 4:2:0 I, P and B pictures through 720x480 |
| Video, interlaced | 720x480 at 30000/1001, 4:2:0 frame pictures with I, P and B coding, frame or field motion, frame or field DCT, top- or bottom-field-first presentation, repeat-first-field scheduling, and mixed ordinary-interlaced/progressive-film frames. Field pictures remain unsupported |
| Picture types | Coded-order/display-order presentation with B reordering |
| Presentation rates | H.262 frame-rate codes 1..5; codes 6..8 are rejected before transport |
| Program Stream timing | Picture PTS on a 33-bit / 90 kHz FPGA timeline with cadence-floor enforcement |
| Raw-stream timing | Synthetic 33-bit / 90 kHz cadence derived from H.262 frame-rate metadata |
| Audio | MPEG Layer II or standalone MPEG-1 Layer III at 44.1 or 48 kHz, ordinary PCM/float WAV, FLAC and Ogg Vorbis converted to stereo at 44.1 or 48 kHz, Audio CD at native 44.1 kHz stereo, and AC-3 at 48 kHz. The AC-3 stereo downmix discards LFE |
| Audio passthrough | AC-3 and DTS carried to S/PDIF as IEC 61937 bursts for an external decoder. DTS is passthrough only; there is no DTS decoder |
| Audio output | A menu option selects HDMI or S/PDIF. The unused output is muted, because both are fed from one stereo stream |
| Audio buffering | Packed signed PCM records into an 8,192-frame stereo FPGA FIFO |
| Audio-only display | ARM-rendered planar 720x480 YCbCr 4:2:0, transferred in bounded records to an inactive DDR frame bank and published atomically at a safe frame boundary. The CRT-safe 4:3 layout reserves album art, title/artist/album metadata, playlist, transport and time fields and tracks absolute file-relative progress at one-hertz resolution |
| Frame storage | Retained planar MiSTer DDR3 I/P banks and separate B scratch storage; native all-I overlap uses a bounded three-region ordinary frame queue |
| Video output | Native 720x480p at 60000/1001 for supported progressive input, or native 720x480i at 30000/1001 for supported interlaced input. The isolated patched Main also has an experimental NTSC-only direct-HDMI 480i path for HDMI-to-SDI testing |

The frozen `rtl/mpeg2fpga/` tree remains historical reference material and is not part of the active Quartus build.

## Installation

[Download the v0.9.0 pre-release](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.9.0).
Its package contains a matching RBF, patched Main and helper plus the optional
visualizer and optical-drive launcher. Back up the existing files, extract the
ZIP at the root of `/media/fat`, preserve executable permissions and verify its
`SHA256SUMS`. Do not combine runtime files from different releases.

| Release file | MiSTer destination | SHA-256 |
| --- | --- | --- |
| `MediaPlayer_20260901.rbf` | `/media/fat/MediaPlayer_20260901.rbf` | `6389fa57b2d642b5b4e85980c6ccf8746ea8d20869cbe480f80b0ea172bcdb4b` |
| `MiSTer` | `/media/fat/MiSTer` | `1b3387170083be269831bf4c3a828f1cce6bcb3b93c519d8cde32cb9768bedf9` |
| `linux/MediaPlayer_Helper` | `/media/fat/linux/MediaPlayer_Helper` | `613d35de5ace0622584ae14b4540423c2c56b1f923c02c599f47b55722e21e56` |
| `linux/MediaPlayer_Visualizer.mmpvis` | `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` | `448407cdd7e6c79fbe13cbb435241116127f726aca5af9f99d75b32fc2519f47` |
| `games/MediaPlayer/USB DVD Drive.dvd` | `/media/fat/games/MediaPlayer/USB DVD Drive.dvd` | `4757d49e9d1b94d88f554b3bd3157ed5d2064caaa65a6cf0f856e8ab6fbe2d2e` |

`MiSTer` is a patched Main and is not optional: it passes the core's controls
and `Audio output` selection to the helper while keeping the menu responsive.
The helper must be executable. Reboot after installing Main. Mixing v0.9.0
components with a different Main, helper or RBF is unsupported.

### Isolated Main for development builds

Development builds after v0.9.0 keep the official `/media/fat/MiSTer`
executable in place. Install the matching patched Main as
`/media/fat/MiSTer_MediaPlayer`, make it executable, and merge the tracked
[`MiSTer_MediaPlayer.ini.fragment`](assets/MiSTer_MediaPlayer.ini.fragment) at
the end of `/media/fat/MiSTer.ini`:

```ini
[MediaPlayer]
main=MiSTer_MediaPlayer
```

The section name is the core-reported `MediaPlayer`, not the filename of the
RBF or an informal DVD-player name. Main's upstream core-specific executable
handoff starts `MiSTer_MediaPlayer` when this core loads and returns to the
official `MiSTer` executable when the Menu core loads. The patched Main remains
a required matched runtime component, but it no longer replaces the system-wide
binary or affects other cores. The installed official Main must include the
core-specific `main=` option introduced upstream in March 2024. Do not place
this setting in the global `[MiSTer]` section.

### Experimental NTSC 480i HDMI-to-SDI output

The isolated development Main can expose the core's native 525-line interlaced
raster without MiSTer's scaler or Bob/Weave deinterlacing. This is an initial
lock-and-picture test for equipment such as the Decimator MD-LX; it is HDMI
that is intended to be converted externally to SMPTE 259M SD-SDI, not an SDI
electrical output generated by the DE10-Nano.

Install the newly built `MiSTer_MediaPlayer` at
`/media/fat/MiSTer_MediaPlayer`, retain the existing RBF and helper, and add the
following line to the existing `[MediaPlayer]` section of `/media/fat/MiSTer.ini`:

```ini
[MediaPlayer]
main=MiSTer_MediaPlayer
direct_video=1
```

Reboot before testing. Main recognizes this mode only for the core-reported
name `MediaPlayer`. It divides the core's 54 MHz HDMI bus clock to 27 MHz; the
core holds every 13.5 MHz content pixel for two transmitter samples. The
ADV7513 then advertises CTA VIC 6 for 4:3 or VIC 7 for 16:9, negative sync,
BT.601 colorimetry, limited-range RGB and the matching 27 MHz audio clock
regeneration value. The core's Aspect Ratio option updates the VIC and AVI
aspect signaling.

This test mode is intentionally NTSC 480i-only. Use it only while playing
native-interlaced 720x480 DVD material; progressive video and the standalone
audio interface are not qualified with it. Remove or comment out
`direct_video=1` to return to the ordinary Bob/Weave scaler path. Displays that
do not accept 480i over HDMI may show no picture even when the SDI converter
locks correctly.

The standalone-audio visualizer has this role:

| Release file | MiSTer destination | Required for |
| --- | --- | --- |
| `linux/MediaPlayer_Visualizer.mmpvis` | `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` | Idle background and standalone-audio visualizer; audio still works if omitted |

The `Load Physical Disc` submenu starts an inserted Video DVD through
`dvdmenu:/dev/sr0` or an Audio CD through `cdda:/dev/sr0` directly. Patched Main
handles both choices without a marker file, and the drive does not need to be
mounted.
The helper authenticates and selects the title once, reuses that navigation
session during preflight, then fills a 4 MiB launch reserve inside an 8 MiB
HPS-RAM ring before playback begins. The ring is direct-disc-only and does not
consume FPGA M10K memory.

For Audio CD, the helper reads the disc table of contents, skips data tracks on
mixed-mode media and presents all audio tracks as one 44.1 kHz stereo timeline
in the existing standalone-audio player. No filesystem mount or extracted audio
files are required. Audio CD image files are not currently supported.

The current menu provides a `Load Physical Disc` submenu for direct Video DVD
or Audio CD playback, a `Load Disc Image` submenu whose `Video DVD` choice opens
an ISO-only browser, and immediate `Load MPEG-2 Video File` and `Load Audio File`
browsers. Each picker exposes only its relevant formats.
With the visualizer pack installed, loading the core starts its background
automatically. Video DVD and MPEG-2 playback replace it; the background returns
after playback ends or fails. Audio files and Audio CDs reuse that loop and
show the existing player overlay for ten seconds before clearing it. The idle
source is ARM-paced and sends no silent PCM, and no alternate RBF is required.
Aspect Ratio defaults to 16:9 with 4:3 as the alternate; Deinterlacer Mode
offers Bob and Weave. Telemetry defaults to Off for normal playback; turning it
On reveals the internally captured hardware snapshot and enables the combined
Main/helper diagnostic log on the next playback start. The Audio Test and Audio
Output choices are unchanged.

- To play a Video DVD or Audio CD in the USB drive, choose the matching item
  under `Load Physical Disc`.
- To play a DVD ISO, choose `Load Disc Image`, then `Video DVD`.
- To play `.m2v`, `.mpg`, `.mpeg` or `.vob`, choose
  `Load MPEG-2 Video File`.
- To play `.mp3`, `.wav`, `.flac` or `.ogg`, choose `Load Audio File`.

For DVD ISO and physical DVD playback, player-one Left and Right select the
previous or next chapter and Start toggles pause/resume while the MiSTer OSD is closed.
On a keyboard, P and N select the previous and next chapter, and Space toggles
pause/resume under the same OSD-closed guard.

For a physical Audio CD, the same Left/Right or P/N controls select audio tracks.
Previous restarts the current track after three seconds or selects the prior
audio track near its beginning; Next selects the following audio track.
For standalone audio files and Audio CDs, the first Start or Space pause press
reveals the player overlay before both music and visualizer stop. The next
press resumes both, and the overlay remains for ten emitted-audio seconds
before clearing again.

For ordinary file-backed `.mpg`, `.mpeg`, `.mp3`, `.wav`, `.flac` and `.ogg`
playback and for a physical Audio CD, Alt+Left/Right jumps backward or forward 10 seconds,
Ctrl+Left/Right jumps 1 minute, and Ctrl+Alt+Left/Right jumps 5 minutes. Program
Streams use a sparse video-PTS index; standalone audio uses the decoder's PCM
sample timeline, and CDDA uses the concatenated audio-track timeline. Main
leaves the active presentation running while the helper
decides each request; only a valid target's READY response enters the clean
download reset and GO barrier, so no pre-jump bytes or partial audio-interface
frame crosses that reset. These
controls do not apply to raw `.m2v`, DVD ISO images, or DVD-Video discs. A
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

## v0.9.0 release qualification

The accepted runtime set uses the clean, reproducible and timing-qualified
source-`dfe1057` RBF, source-`3689cca` patched Main, source-`932dc22`
interface/visualizer behavior and source-`0f1165c` helper. The project owner
completed the functional and regression matrix and directed that these exact
accepted artifacts be packaged without rebuilding.

`MiSTer_Media_Player_v0.9.0.zip` is 6,580,818 bytes with SHA-256
`e8bc8e0c25291df85d6d53ad2688995d30ce156c547b7315b08058052863e1f9`.
All 15 entries in its internal manifest pass, ZIP integrity is clean, and Main
and the helper retain mode 755. See the
[v0.9.0 release notes](docs/RELEASE_NOTES_v0.9.0.md) for source provenance,
timing/resources, validation scope and limitations.

## Releases

Milestone releases use semantic-version tags on GitHub. RBF assets retain the normal MiSTer date-coded naming convention.

Current milestone:

- **[v0.9.0](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.9.0)** — DVD ISO/direct-disc playback, authored menus, expanded native interlaced decoding, seeking, consumer audio, visualizer and production telemetry; binary `MediaPlayer_20260901.rbf`.

Previous milestones:

- **[v0.8.0](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.8.0)** — bounded native 480i all-I playback, AC-3 decode, AC-3/DTS passthrough, and responsive Main media transfers; binary `MediaPlayer_20260827.rbf`.
- **v0.7.0** — bounded Program Stream input, real picture PTS, MPEG Layer II audio, and full-length audio-video playback; binary `MediaPlayer_20260824.rbf`.
- **v0.6.0** — sustained progressive 720x480 real-stream I/P/B playback with native 23.976/24/25-fps cadence; binary `MediaPlayer_20260822.rbf`.

See the [v0.9.0 release notes](docs/RELEASE_NOTES_v0.9.0.md) for the current
package and [v0.8.0 release notes](docs/RELEASE_NOTES_v0.8.0.md) for the prior
milestone. Historical qualification remains in each version's notes and the
[changelog](CHANGELOG.md).

## Converting media with FFmpeg

This is the project's recommended "house recipe" for a conservative 720x480,
exact-24-fps MPEG-2 Program Stream with optional stereo MP2 audio:

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

tools/media.sh verify "output.mpg"
```

The optional audio map lets silent input convert successfully. Replace
`input.*` with the source filename; this does not mean a shell wildcard is
required. See [preparing media files](docs/MEDIA_CONVERSION.md) for what the
recipe produces, verification guidance and the other supported file paths.

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
| Audio CD, 44.1 kHz stereo | read digitally and sent as stereo PCM | read digitally and sent as stereo PCM |
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

The outputs are `host/build/MediaPlayer_Helper` and
`host/build/MiSTer_MediaPlayer`. The build script pins minimp3, miniaudio,
stb_vorbis, liba52, libdvdcss,
libdvdread, libdvdnav, MiSTer Main, dependency hashes and the Main patch. Release
candidates require reproducible FPGA, helper, Main and visualizer artifacts plus
host and MiSTer regression evidence. See [building and testing](docs/BUILDING.md)
for the current workflow.

## Known limitations

- Program Stream support is bounded; MPEG Transport Stream, DVD LPCM, subtitle-track presentation, angles and arbitrary systems-layer layouts are not supported. Authored DVD menus use DVD subpictures only for their button overlay and run in native 480i; ISO and direct `/dev/sr0` playback use statically linked libdvdcss for encrypted sectors. DVD private stream 1 supports AC-3 decode/passthrough and DTS passthrough.
- Decoded audio is MPEG Layer II or standalone MPEG-1 Layer III at 44.1 or 48 kHz, ordinary PCM/float WAV, FLAC and Ogg Vorbis converted to stereo at 44.1 or 48 kHz, and AC-3 at 48 kHz. MPEG-1 Layer III at 32 kHz and MPEG-2/2.5 Layer III remain rejected; AAC is not enabled. Only the first Program Stream audio track is played; chapter changes retain that identity, while deliberate track switching needs a control channel that protocol one does not implement.
- Audio CD playback uses bounded Linux digital-audio reads and the drive's own
  error reporting; it does not yet add cdparanoia-style damaged-disc recovery,
  offset correction, CD-Text or metadata lookup.
- AC-3 is downmixed to stereo for decoded output, which discards LFE. Discrete surround requires passthrough and an external decoder.
- Passthrough carries the bitstream untouched, so nothing may scale it. The audio output option therefore mutes the output it is not driving, and volume control does not apply to a passthrough stream.
- The standalone-audio screen contains a CRT-safe 4:3 composition for album artwork, title/artist/album tags, the current playlist, transport controls, centered elapsed/total/remaining time and a duration-relative progress bar. Track timing, fixed keyboard seeking and absolute progress tracking are active; artwork, metadata, playlist entries, playlist summary fields, arbitrary-position scrubbing and FPGA-aware pause state remain later display boundaries.
- The optional `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` asset is generated with `python3 tools/generate-audio-visualizer.py host/build/MediaPlayer_Visualizer.mmpvis`. Version two contains eight steady grades plus seven rising and seven falling adjacent-grade streams, all aligned as interlaced top-field-first, three-picture closed GOPs rather than malformed decoder input. The helper rejects progressive or otherwise incompatible packs, sends one matching-phase GOP at a time, applies RMS hysteresis and a one-level-per-GOP slew, and uses a dedicated transition GOP to crossfade each rise or fall over three frames. Version-one stepped packs remain accepted. Video admission remains limited to 4 KiB between PCM records. The two-bit player overlay uses a transparent background, a translucent dark panel and opaque text and borders; while it is present, the loop is capped at grade three. The helper clears that overlay after ten playback seconds without input, restores the full zero-through-seven brightness range without changing the GOP cadence, and restores the capped overlay before standalone-audio pause or on seek activity. Pause stops the emitted-audio clock, so the new ten-second interval begins advancing only after resume. The fixed thresholds do not provide per-track automatic gain.
- Progressive 4:2:0 video is supported through 720x480 and decodes I, P and B
  pictures. v0.9.0 also supports 720x480-at-30000/1001
  interlaced frame-picture I/P/B decoding with frame or field motion, frame or
  field DCT, per-picture `repeat_first_field`, and mixed ordinary-interlaced/
  progressive-film frames. Field pictures and 576i remain rejected. DVD
  subtitle tracks and broader systems-layer behavior remain separate limits.
- Comprehensive playback pixel accuracy remains unqualified. Simulation comparisons cover decoder reconstruction, and a targeted hardware-screenshot comparison found the chroma-edge difference below; that comparison is not a full playback pixel-validation suite.
- Sharp colour transitions show one blended pixel column that an independent software decoder does not produce, consistent with horizontal chroma upsampling in the display path. It is obvious on synthetic colour bars and subtle on ordinary material, and it is not specific to any picture type.
- On material whose peak coded picture is large enough, one or two display slots are missed at that picture, shown as a repeated frame rather than a dropped one. This is a property of input buffer depth against peak picture size, not of the stream; the qualified full-length fixture hits it once, at a scene cut.
- The framework scaler has little timing margin: seed 16 missed setup by 0.070 ns after audio routing changed; the seed-17 release has +0.243 ns worst setup. Future logic changes may expose the path again, and 93% M10K usage limits buffering headroom.
- H.262 frame-rate codes 6 through 8 (50, 59.94, and 60 fps) are rejected.
- Arbitrary-position scrubbing and seeking in raw `.m2v`, DVD ISO, and
  DVD optical-disc playback are not implemented; ordinary `.mpg`/`.mpeg`,
  supported standalone-audio files and Audio CD provide only fixed keyboard jumps
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

See [preparing media files](docs/MEDIA_CONVERSION.md) for the recommended
FFmpeg recipe.

## Development roadmap

Future work can extend the qualified envelope toward 50/59.94/60 fps,
field-picture structures and 576i, broader Program Stream handling, DVD LPCM
and additional audio codecs, multi-track selection, album-art/tag/playlist
population, playback pixel qualification, improved chroma presentation, an
FPGA-native pause state, DVD seeking and arbitrary-position scrubbing, DVD
subtitle presentation and title/angle selection, optical-drive discovery, and
qualification of native 480i through external HDMI-to-SDI hardware.

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
