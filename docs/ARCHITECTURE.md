# Architecture

MiSTer Media Player is being developed as a standards-driven media decoder for MiSTer, with MPEG-2 Video decoding performed primarily in FPGA logic.

## High-level partitioning

### HPS / host side

The ARM helper opens file sources, demultiplexes bounded MPEG-2 Program Streams, extracts picture PTS, decodes MPEG Layer II or AC-3 to stereo, packs AC-3 or DTS passthrough bursts, and translates authored DVD menu subpictures into bounded overlay records. Patched MiSTer Main launches the helper with the selected audio mode and brokers its annotated byte stream through guarded, resumable transfers. Main remains the sole FPGA SPI owner; the helper does not access that bridge directly.

DVD/ISO navigation uses libdvdnav first-play/root-menu state plus a private
Main/helper control channel for directional, activation and root commands.
See the [helper architecture](../host/arm/ARCHITECTURE.md) for the source and
transport contracts.

### FPGA side

The active FPGA pipeline performs:

1. asynchronous input buffering and clock-domain crossing;
2. separation of video, picture-PTS, PCM-or-burst and DVD-overlay records, followed by H.262 byte/bit reading with backpressure;
3. picture/slice/macroblock/block parsing;
4. MPEG-2 DCT VLC decoding;
5. inverse quantization;
6. fixed-point two-pass 8x8 IDCT;
7. intra reconstruction and supported P/B motion compensation and residual reconstruction;
8. planar Y/Cb/Cr frame storage in DDR3;
9. DDR3 readback through small ping-pong line caches;
10. 4:2:0 chroma expansion;
11. limited-range BT.601 YCbCr-to-RGB conversion;
12. cadence-floor and picture-PTS scheduling with selectable 800x600 diagnostic or native 480i presentation;
13. native-480i composition of the double-buffered DVD overlay with authored normal/highlight RGBA state.

Audio records enter an 8,192-frame stereo FIFO. The selected output routes decoded PCM to HDMI or S/PDIF, or sends AC-3/DTS bursts through a bit-preserving S/PDIF path that bypasses gain, mixing and filtering. The unused output is muted. Video decoder backpressure is isolated by the separate 64 KiB clean-video queue; the ingress FIFO adds 32 KiB of compressed read-ahead.

## Active decoder

The clean decoder lives in `rtl/mpeg2_new/` and is the only MPEG-2 decoder implementation included in the active `files.qip` source list.

The older `rtl/mpeg2fpga/` implementation is retained only as a frozen reference. It is not part of the active design.

## Current supported implementation path

v0.8.0 covers continuous progressive 4:2:0 I/P/B frame pictures through 720x480. Its interlaced path accepts a deliberately bounded 720x480 at 30000/1001, 4:2:0 all-I subset: frame pictures, frame DCT and frame prediction only, no repeat-first-field, and consistent authored top- or bottom-field-first order. Field pictures, field DCT, interlaced P/B, repeat-first-field and 576i remain unsupported.

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
The DDR arbiter preserves display-read priority, followed by overlay reads,
prediction reads, decoder writes and overlay writes.

## Presentation path

Full-frame storage is kept in DDR3 rather than M10K memory. The display side uses small dual-clock ping-pong caches:

- two 720-pixel Y lines;
- two 360-pixel Cb lines;
- two 360-pixel Cr lines.

This architecture reduced on-chip memory pressure dramatically and restored full 8-bit chroma storage/presentation.

The display path expands 4:2:0 chroma for RGB presentation. A targeted comparison of a hardware screenshot against the same software-decoded frame found one blended column at a sharp colour transition. Chroma upsampling is a hypothesis for that difference, not an established root cause; the write/read path and chroma siting have not been fully isolated. Reconstruction has simulation comparisons, but comprehensive playback pixel accuracy remains unqualified. The finding is documented rather than scheduled for correction in v0.8.0.

### Two interlaced output tiers

Supported interlaced input is kept as two correctly ordered fields in a native 480i raster. On normal HDMI, MiSTer's scaler processes that raster and the core's `HDMI scaler deinterlacer` menu requests either Weave or Bob. Weave prioritizes stable vertical detail; Bob prioritizes motion handling at the expected cost of reduced vertical stability.

The second tier preserves native 480i for an external processor and eventual HDMI-to-SDI conversion. The core does not deinterlace or scale this tier. Raw, unscaled HDMI also requires MiSTer's global `direct_video` configuration: that framework input arrives as `cfg[10]` and cannot be changed by a core status-menu option. Native 480i therefore describes the core's output format, not an automatic promise that direct video is enabled.

## Clocking and CDC

The principal active clocks are:

- 60 MHz decoder/memory-side logic;
- 40 MHz 800x600 diagnostic timing, or the native 480i video clock path.

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

The v0.8.0 seed-17 build uses 512 of 553 M10K blocks (93%) and 31,464 ALMs (75%), with +0.243 ns worst setup and zero reported total negative slack. The framework scaler's horizontal accumulator previously failed setup at seed 16; reseeding closed that build but did not eliminate the path's margin risk.

Large coded pictures can exhaust the available input lead and repeat one or two display slots at a scene cut. Increasing buffering was deferred to preserve memory headroom. These are measured implementation limitations, not input-format limits. See the [release notes](RELEASE_NOTES_v0.8.0.md) for the exact binaries, qualification scope and outstanding package-install confirmation.

## Standards boundary

H.262 / ISO/IEC 13818-2 is the normative source for MPEG-2 Video syntax and decoding behavior. H.222.0 / ISO/IEC 13818-1 is the normative source for MPEG systems/program-stream behavior.

Temporary buffer sizes, supported geometries, diagnostic formats, presentation filters, and development-stage picture-type limits are implementation decisions and should not be presented as standard requirements.
