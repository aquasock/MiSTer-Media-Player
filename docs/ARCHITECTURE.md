# Architecture

MiSTer Media Player is being developed as a standards-driven media decoder for MiSTer, with MPEG-2 Video decoding performed primarily in FPGA logic.

## High-level partitioning

### HPS / host side

The host currently supplies media bytes through the existing MiSTer data path. Longer-term host responsibilities are expected to include filesystem access, buffering, program-stream demux, timestamp/control handling, audio coordination, and DVD/optical-drive integration.

### FPGA side

The active FPGA pipeline performs:

1. asynchronous input buffering and clock-domain crossing;
2. H.262 byte/bit reading with backpressure;
3. picture/slice/macroblock/block parsing;
4. MPEG-2 DCT VLC decoding;
5. inverse quantization;
6. fixed-point two-pass 8x8 IDCT;
7. intra reconstruction;
8. planar Y/Cb/Cr frame storage in DDR3;
9. DDR3 readback through small ping-pong line caches;
10. 4:2:0 chroma expansion;
11. limited-range BT.601 YCbCr-to-RGB conversion;
12. selectable 800x600 diagnostic or native 480i timing and MiSTer presentation.

## Active decoder

The clean decoder lives in `rtl/mpeg2_new/` and is the only MPEG-2 decoder implementation included in the active `files.qip` source list.

The older `rtl/mpeg2fpga/` implementation is retained only as a frozen reference. It is not part of the active design.

## Current supported implementation path

The released path covers continuous progressive 4:2:0 I/P/B frame pictures through 720x480. The unreleased interlaced path accepts a deliberately bounded 720x480 4:2:0 all-I subset: frame pictures, frame DCT, no repeat-first-field, and a consistent authored top- or bottom-field-first order.

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

## Presentation path

Full-frame storage is kept in DDR3 rather than M10K memory. The display side uses small dual-clock ping-pong caches:

- two 720-pixel Y lines;
- two 360-pixel Cb lines;
- two 360-pixel Cr lines.

This architecture reduced on-chip memory pressure dramatically and restored full 8-bit chroma storage/presentation.

Chroma expansion is currently nearest-neighbor 4:2:0 replication. This is sufficient for decoder validation but is known to produce visible color fringing on fine anti-aliased text. Better chroma positioning/interpolation is planned as a presentation-quality improvement.

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

The decoder currently uses one hardware-proven parser for consecutive pictures.

After picture 1 completes, the wrapper:

1. latches picture-1 diagnostics;
2. applies a local parser re-arm/reset cycle;
3. allows the same parser to locate and decode picture 2;
4. changes the downstream completion handshake so picture 2 can advance after reconstruction rather than DDR persistence.

The next phase will replace this diagnostic-only second-picture path with alternate-bank DDR storage and a controlled display-frame swap.

## Standards boundary

H.262 / ISO/IEC 13818-2 is the normative source for MPEG-2 Video syntax and decoding behavior. H.222.0 / ISO/IEC 13818-1 is the normative source for MPEG systems/program-stream behavior.

Temporary buffer sizes, supported geometries, diagnostic formats, presentation filters, and development-stage picture-type limits are implementation decisions and should not be presented as standard requirements.
