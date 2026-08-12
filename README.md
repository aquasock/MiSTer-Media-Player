# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. The current hardware-proven baseline decodes two consecutive supported I pictures; only the first picture is stored and displayed today. Continuous playback, P/B pictures, audio, program-stream demux, and DVD support are future work.

## Current status

The active decoder is a clean H.262 implementation under `rtl/mpeg2_new/`. It currently provides:

- streaming MPEG-2 elementary-stream input with FIFO backpressure;
- picture, slice, macroblock, block, and DCT VLC parsing for the supported diagnostic path;
- inverse quantization;
- fixed-point two-pass 8x8 IDCT;
- intra reconstruction;
- full 8-bit Y, Cb, and Cr reconstruction;
- planar frame storage in MiSTer DDR3;
- DDR3 readback through small ping-pong line caches;
- 4:2:0 chroma expansion and limited-range BT.601 YCbCr-to-RGB presentation;
- a fixed 800x600 / 40 MHz diagnostic raster;
- two consecutive supported I-picture decodes using one re-armed parser.

The current implementation subset is intentionally narrow while the decoder architecture is being proven. These are implementation limits, **not** limits of the H.262 standard.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | I pictures |
| Picture structure | Progressive frame pictures |
| Chroma format | 4:2:0 |
| Proven diagnostic geometry | Up to 720x480 |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | MiSTer DDR3 |
| Display | First decoded frame; second frame decode proven but not yet published |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains in the repository only as a historical/reference implementation. It is not part of the active Quartus build.

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
planar Y / Cb / Cr DDR3 frame store
        |
        v
DDR3 line caches -> 4:2:0 expansion -> BT.601 RGB
        |
        v
MiSTer video output
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for more detail.

## Building

The Quartus project is `MediaPlayer.qpf`. The project configuration targets Quartus Prime 17.0.x, matching the MiSTer framework generation used by this repository.

A typical command-line build is:

```bash
quartus_sh --flow compile MediaPlayer
```

The generated RBF is placed under `output_files/`.

After meaningful RTL, clocking, reset, DDR, or CDC changes, also run the focused timing report:

```bash
quartus_sta -t tools/phase1p_timing.tcl
```

See [`docs/BUILDING.md`](docs/BUILDING.md) for the full development and hardware-test workflow.

## Diagnostic streams

Hardware development uses the streams in `tools/streams/`, especially:

- `test_flat_gray_i.m2v` for neutral/flat decode and color-neutrality checks;
- `test_all_i.m2v` for spatial detail, timestamp text, color bars, and decoder stress.

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

1. alternate DDR frame storage and a controlled frame swap;
2. continuous all-I playback and display scheduling;
3. reference-picture management;
4. P- and B-picture prediction / motion compensation;
5. broader H.262 picture structures and chroma formats;
6. improved chroma positioning/interpolation for presentation quality;
7. H.222.0 / MPEG program-stream demux and timestamps;
8. audio;
9. DVD navigation and optical-drive playback where practical.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Systems/program-stream work uses **ITU-T H.222.0 / ISO/IEC 13818-1**.

Implementation constraints, diagnostic stream limits, and temporary engineering shortcuts should always be described as implementation choices rather than MPEG-2 requirements.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices where present.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
