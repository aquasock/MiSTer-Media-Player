# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. Phase 1S is the hardware-proven **v0.2.0 release candidate**: supported progressive 4:2:0 I pictures decode continuously, alternate through two DDR frame banks, and are repeatedly published at controlled vertical-blanking boundaries without observed playback artifacts. P/B pictures, audio, program-stream demux, and DVD support remain future work.

## Current status

The active decoder is a clean H.262 implementation under `rtl/mpeg2_new/`. It currently provides:

- streaming MPEG-2 elementary-stream input with FIFO backpressure;
- picture, slice, macroblock, block, and DCT VLC parsing for the supported diagnostic path;
- inverse quantization;
- fixed-point two-pass 8x8 IDCT;
- intra reconstruction;
- full 8-bit Y, Cb, and Cr reconstruction;
- planar frame storage in MiSTer DDR3;
- two DDR frame banks used as a repeated ping-pong store;
- explicit DDR arbitration between frame writes and display reads;
- protection against writes to the frame bank currently owned by the display reader;
- DDR3 readback through small ping-pong line caches;
- controlled repeated publication of completed frames during true vertical blanking;
- one-bit event CDC for line-cache consumption, with source-line identity derived locally in the DDR clock domain;
- 4:2:0 chroma expansion and limited-range BT.601 YCbCr-to-RGB presentation;
- a fixed 800x600 / 40 MHz diagnostic raster;
- continuous supported all-I picture decode using one re-armed parser;
- a first 33-bit / 90 kHz presentation-timing metadata foundation derived from H.262 frame-rate information and `temporal_reference` for elementary-stream testing.

The current implementation subset is intentionally narrow while the decoder architecture is being proven. These are implementation limits, **not** limits of the H.262 standard.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | I pictures |
| Picture structure | Progressive frame pictures |
| Chroma format | 4:2:0 |
| Proven diagnostic geometry | Up to 720x480 |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | Two planar MiSTer DDR3 frame banks used as a repeated ping-pong store |
| Display | Repeated completed-frame publication during true vertical blanking |
| Timing metadata | Synthetic elementary-stream 33-bit / 90 kHz schedule for supported direct H.262 frame rates; not PES-derived PTS |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains in the repository only as a historical/reference implementation. It is not part of the active Quartus build.

## Releases

Milestone releases use semantic version tags on GitHub. MiSTer RBF assets retain the normal date-coded core naming convention.

Current published milestone release:

- **v0.1.0** — Phase 1R alternate DDR frame bank and controlled frame swap; binary asset `MediaPlayer_20260812.rbf`.

Current release candidate:

- **v0.2.0** — Phase 1S continuous supported all-I playback, repeated DDR ping-pong publication, presentation-path CDC cleanup, and initial presentation-timing metadata.

## Architecture

The current data path is:

```text
HPS / MiSTer file data
        |
        v
async MPEG input FIFO
        |
        v
H.262 parser / bitreader / VLC decode
        |
        v
inverse quantization -> IDCT -> intra reconstruction
        |
        v
planar Y / Cb / Cr DDR3 ping-pong frame banks
        |
        v
DDR arbitration -> line caches -> 4:2:0 expansion -> BT.601 RGB
        |
        v
blanking-aligned repeated frame publication -> MiSTer video output
```

A sideband timing path derives a 33-bit / 90 kHz elementary-stream presentation schedule from H.262 frame-rate metadata. It is deliberately not called PTS because the current `.m2v` input has no H.222.0 PES layer; later systems-layer work can replace that synthetic source with PES timestamps while keeping the same downstream units and width.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for more detail.

## Building

The Quartus project is `MediaPlayer.qpf`. The project configuration targets Quartus Prime 17.0.x, matching the MiSTer framework generation used by this repository.

A typical command-line build is:

```bash
quartus_sh --flow compile MediaPlayer
```

The generated RBF is placed under `output_files/`.

The focused timing report is part of the normal development build workflow:

```bash
quartus_sta -t tools/phase1p_timing.tcl
```

See [`docs/BUILDING.md`](docs/BUILDING.md) for the full development and hardware-test workflow.

## Diagnostic streams

Hardware development uses the streams in `tools/streams/`, especially:

- `test_flat_gray_i.m2v` for neutral/flat decode and color-neutrality checks;
- `test_all_i.m2v` for spatial detail, timestamp text, color bars, repeated frame publication, and decoder stress.

The USER LED is used as a positive completion diagnostic during development. Its exact gating evolves with each hardware phase and should not be treated as a public player UI.

## Project layout

- `MediaPlayer.sv` — MiSTer top-level glue and current decoder integration.
- `rtl/mpeg2_new/` — active standards-driven H.262 decoder pipeline.
- `rtl/mpeg2_luma_framebuffer.sv` — DDR-backed frame readback and video-side line caching.
- `rtl/mpeg2fpga/` — frozen legacy reference; inactive in `files.qip`.
- `sys/` — MiSTer framework.
- `tools/` — timing scripts and diagnostic streams.
- `docs/` — architecture and decoder documentation.
- `files.qip` — authoritative active RTL source list for Quartus.

## Development roadmap

Near-term work is deliberately staged into small hardware-testable steps:

1. reference-picture management for predictive pictures;
2. P-picture prediction / motion compensation;
3. B-picture prediction / motion compensation;
4. broader H.262 picture structures and chroma formats;
5. improved chroma positioning/interpolation for presentation quality;
6. H.222.0 / MPEG program-stream demux and real PES timestamps;
7. audio;
8. DVD navigation and optical-drive playback where practical.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Systems/program-stream work uses **ITU-T H.222.0 / ISO/IEC 13818-1**.

Implementation constraints, diagnostic stream limits, synthetic elementary-stream timing, and temporary engineering shortcuts should always be described as implementation choices rather than MPEG-2 requirements.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices where present.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
