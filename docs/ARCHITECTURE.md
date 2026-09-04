# Architecture

MiSTer Media Player is being developed as a standards-driven media decoder for MiSTer, with MPEG-2 Video decoding performed primarily in FPGA logic.

## High-level partitioning

### HPS / host side

The ARM helper opens file sources, demultiplexes bounded MPEG-2 Program Streams,
extracts picture PTS, decodes MPEG Layer II or AC-3 to stereo, packs AC-3 or DTS
passthrough bursts, and translates authored DVD menu subpictures into bounded
overlay records. Pinned libdvdcss, libdvdread and libdvdnav are linked into the
static helper for encrypted or unencrypted ISO and direct optical playback.
For standalone audio the helper decodes MP3, WAV, FLAC or Ogg Vorbis, renders a
planar 720x480 limited-range BT.601 player interface and can feed a validated
eight-grade MPEG-2 visualizer stream selected from decoded-PCM loudness. Patched
MiSTer Main launches the helper with the selected audio mode and brokers its
annotated byte stream through guarded, resumable transfers. Main remains the
sole FPGA SPI owner; the helper does not access that bridge directly.

DVD/ISO navigation uses libdvdnav first-play/root-menu state plus a private
Main/helper control channel for directional, activation, root, chapter and
stream-reset commands. Direct optical reads use an 8 MiB HPS-RAM ring with a
4 MiB launch reserve. Stream hops use interruptible reserve discard and staged
output so a slow picture-bearing menu cannot deadlock Main or leak old bytes
across a decoder reset.
See the [helper architecture](../host/arm/ARCHITECTURE.md) for the source and
transport contracts.

### FPGA side

The active FPGA pipeline performs:

1. asynchronous input buffering and clock-domain crossing;
2. separation of video, picture-PTS, PCM-or-burst and shared display records, followed by command routing of display records to either the DVD-overlay engine or audio-interface uploader and H.262 byte/bit reading with backpressure;
3. picture/slice/macroblock/block parsing;
4. MPEG-2 DCT VLC decoding;
5. inverse quantization;
6. fixed-point two-pass 8x8 IDCT;
7. intra reconstruction and supported P/B motion compensation and residual reconstruction;
8. planar Y/Cb/Cr frame storage in DDR3;
9. DDR3 readback through small ping-pong line caches;
10. 4:2:0 chroma expansion;
11. limited-range BT.601 YCbCr-to-RGB conversion;
12. cadence-floor and picture-PTS scheduling with native 720x480p or 720x480i presentation;
13. native-480i composition of the double-buffered DVD overlay with authored normal/highlight RGBA state;
14. inactive-bank loading and safe-frame-boundary publication of the ARM-rendered standalone-audio interface in native 720x480p;
15. two-bit overlay composition of that interface over the native-interlaced audio visualizer stream.

Audio records enter an 8,192-frame stereo FIFO. The selected output routes decoded PCM to HDMI or S/PDIF, or sends AC-3/DTS bursts through a bit-preserving S/PDIF path that bypasses gain, mixing and filtering. The unused output is muted. Video decoder backpressure is isolated by the separate 64 KiB clean-video queue; the ingress FIFO adds 32 KiB of compressed read-ahead.

## Active decoder

The clean decoder lives in `rtl/mpeg2_new/` and is the only MPEG-2 decoder implementation included in the active `files.qip` source list.

The older `rtl/mpeg2fpga/` implementation is retained only as a frozen reference. It is not part of the active design.

## Current supported implementation path

v0.9.0 covers continuous progressive 4:2:0 I/P/B frame pictures
through 720x480. Its interlaced path accepts 720x480 at `30000/1001`, 4:2:0
frame pictures with I, P and B coding, frame or field motion, frame or field
DCT, per-picture field order, repeat-first-field scheduling and mixed ordinary
interlaced/progressive-film frames. Field pictures, 576i and H.262 frame-rate
codes 6 through 8 remain unsupported.

These limits describe the current implementation only. They are not restrictions imposed by H.262.

## DDR frame layout

The current framebuffer format is planar 8-bit Y, Cb, and Cr.

For the maximum current diagnostic geometry:

- Y: 720x480;
- Cb: 360x240;
- Cr: 360x240;
- eight adjacent 8-bit pixels are packed into one 64-bit DDR word;
- Y stride: 90 DDR words per row;
- Cb/Cr stride: 45 DDR words per row.

The current frame resides in a DDR region beginning at physical byte address `0x30000000`. This region was chosen after an earlier base at `0x20000000` collided with MiSTer's system-video/scaler use of DDR.

DVD menu overlays use two packed two-bit 720x480 planes at byte addresses
`0x30280000` and `0x30300000`. The display client caches one parity line while
the helper loads the inactive plane, then publishes it atomically on commit.
The full-frame audio-only interface reuses ordinary frame regions zero and one
when the visualizer pack is unavailable. Each
518,400-byte Y/Cb/Cr frame is divided into bounded records, written only to the
inactive frame bank, validated for exact byte and word count, and then published
by changing banks only at the established safe frame window. The helper offers
at most one UI record after a PCM record, so a full-screen update cannot become
an unbounded audio-service gap.

With the visualizer pack present, the helper instead sends validated
native-interlaced, closed-GOP MPEG-2 segments. Eight aligned variants of every
GOP carry different color/brightness grades; RMS thresholds, hysteresis and a
one-grade-per-GOP limit select the variant without corrupting H.262 syntax or
changing cadence. A two-bit player overlay remains visible for ten playback
seconds after start, pause/resume, seek or other user activity and then clears
to reveal the full visualizer. Overlay-visible output caps brightness at grade
three for legibility.

The DDR arbiter preserves display-read priority, followed by overlay reads,
prediction reads, decoder writes, audio-interface writes and overlay writes.

## Presentation path

Full-frame storage is kept in DDR3 rather than M10K memory. The display side uses small dual-clock ping-pong caches:

- two 720-pixel Y lines;
- two 360-pixel Cb lines;
- two 360-pixel Cr lines.

This architecture reduced on-chip memory pressure dramatically and restored full 8-bit chroma storage/presentation.

The display path expands 4:2:0 chroma for RGB presentation. A targeted
comparison of a hardware screenshot against the same software-decoded frame
found one blended column at a sharp colour transition. Chroma upsampling is a
hypothesis for that difference, not an established root cause; the write/read
path and chroma siting have not been fully isolated. Reconstruction has
simulation comparisons, but comprehensive playback pixel accuracy remains
unqualified. The finding remains a documented v0.9.0 limitation rather than an
identified decoder failure.

### Two interlaced output tiers

Supported interlaced input is kept as two correctly ordered fields in a native 480i raster. On normal HDMI, MiSTer's scaler processes that raster and the core's `HDMI scaler deinterlacer` menu requests either Weave or Bob. Weave prioritizes stable vertical detail; Bob prioritizes motion handling at the expected cost of reduced vertical stability.

The second tier preserves native 480i for an external processor and
HDMI-to-SDI conversion. The core does not deinterlace or scale this tier. Raw,
unscaled HDMI also requires MiSTer's per-core `direct_video` configuration:
that framework input arrives as `cfg[10]` and cannot be changed by a core
status-menu option. Native 480i therefore describes the core's output format,
not an automatic promise that direct video is enabled.

The isolated patched Main recognizes `direct_video=1` only when the reported
core name is `MediaPlayer`. In that boundary the DE10-Nano still presents the
core's 54 MHz bus to the ADV7513, with each 13.5 MHz raster sample held for four
bus clocks. The transmitter divides the input clock by two and therefore sees
two identical 27 MHz samples for each content pixel. Manual pixel-repetition
signaling reports that x2 relationship without multiplying the already-27 MHz
TMDS clock. VIC 6/7, negative sync, BT.601, limited RGB and 27 MHz-derived audio
CTS complete the initial CTA 525i59.94 signaling contract. The resulting HDMI
can feed an external SD-HDMI-to-SDI converter; the core does not generate an
SDI serial stream.

This initial mode is intentionally limited to native-interlaced 720x480 DVD
testing. It does not dynamically return to progressive signaling for the audio
interface or progressive video, and it does not implement PAL/576i or HD-SDI.

## Clocking and CDC

The principal active clocks are:

- 60 MHz decoder/memory-side logic;
- 54 MHz video-side logic with exact 720x480 progressive or interlaced pixel enables.

Phase 1P established the project's current timing/CDC discipline:

- true same-clock datapaths must meet timing without broad exceptions;
- reset assertion may remain asynchronous where required;
- reset release is synchronized independently in each destination domain;
- DCFIFO asynchronous-clear synchronization is enabled;
- CDC/reset exceptions are narrowly scoped to intentional synchronizer boundaries.

After meaningful architectural changes, run:

```bash
quartus_sta -t tools/phase1p_timing.tcl
```

## Successive-picture architecture

The released decoder reconstructs and stores successive pictures in DDR, retaining I/P references and separate B scratch storage. Publication and blanking-aligned presentation preserve coded-order versus display-order dependencies and prevent writes into a display-owned region. End-of-stream handling flushes the pending reordered reference.

Native all-I playback can overlap reconstruction and presentation through a bounded three-region ordinary frame queue, including timestamped playback. Capacity and bank-ownership guards remain active. Writer completion grants advance on the capture-completion edge only when the alternate capture bank is free; otherwise one pending grant waits for capacity.

Picture PTS may delay presentation but cannot bypass the encoded cadence floor. Raw streams use the synthetic H.262-derived timeline. The native raw all-I startup reserve and its telemetry caveats are described in the [README](../README.md#native-elementary-stream-startup).

## Resource and qualification limits

The v0.9.0 source-`dfe1057` RBF uses 536 RAM blocks, 34,859 ALMs,
54,492 registers and 70 DSP blocks. Its seed-24 Quartus 17.0.2 build has
+0.180 ns worst global setup with zero reported total negative slack; decoder
and video setup are positive at +1.220 ns and +2.215 ns. That RBF was produced
by the recorded clean, reproducible build and retained unchanged for release.

Large coded pictures can exhaust the available input lead and repeat one or two
display slots at a scene cut. Increasing buffering was deferred to preserve
memory headroom. These are measured implementation limitations, not
input-format limits. See the [v0.9.0 release notes](RELEASE_NOTES_v0.9.0.md) for
package provenance and qualification scope.

## Standards boundary

H.262 / ISO/IEC 13818-2 is the normative source for MPEG-2 Video syntax and decoding behavior. H.222.0 / ISO/IEC 13818-1 is the normative source for MPEG systems/program-stream behavior.

Temporary buffer sizes, supported geometries, diagnostic formats, presentation filters, and development-stage picture-type limits are implementation decisions and should not be presented as standard requirements.
