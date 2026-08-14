# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. Phase 1T is the **v0.3.0 release candidate**: the hardware-proven continuous progressive 4:2:0 all-I path remains intact, and the core now also contains controlled hardware-proven P-picture reference, prediction, residual-reconstruction, persistence, and multi-macroblock raster paths. P-picture support is still a deliberately narrow diagnostic subset rather than general arbitrary MPEG-2 P-picture playback. B pictures, audio, program-stream demux, and DVD support remain future work.

## Current status

The active decoder is a clean H.262 implementation under `rtl/mpeg2_new/`. It currently provides:

- streaming MPEG-2 elementary-stream input with FIFO backpressure;
- picture, slice, macroblock, block, and DCT VLC parsing for the supported paths;
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
- reference-picture bookkeeping and reference/destination DDR-bank ownership for predictive-picture diagnostics;
- controlled P-picture syntax and motion-vector observation;
- controlled forward-prediction reference reads, including zero-vector copying and established half-sample interpolation diagnostics;
- controlled non-intra P residual parsing and prediction-plus-residual reconstruction;
- ordinary DDR persistence/readback for complete controlled 4:2:0 P macroblocks;
- controlled two-adjacent-macroblock and four-macroblock/two-row P reconstruction proofs;
- live coded raster width for the four-macroblock P placement path, derived from H.262 horizontal geometry;
- a first 33-bit / 90 kHz presentation-timing metadata foundation derived from H.262 frame-rate information and `temporal_reference` for elementary-stream testing.

The current implementation subset is intentionally narrow while the decoder architecture is being proven. These are implementation limits, **not** limits of the H.262 standard.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | Continuous supported I pictures; controlled hardware-proven P-picture diagnostic subset |
| Picture structure | Progressive frame pictures on the proven paths |
| Chroma format | 4:2:0 |
| Proven diagnostic geometry | Up to 720x480 for the established I-picture path; controlled smaller P-picture regression geometries |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | Two planar MiSTer DDR3 frame banks used as a repeated ping-pong/reference store |
| Display | Repeated completed-frame publication during true vertical blanking |
| Timing metadata | Synthetic elementary-stream 33-bit / 90 kHz schedule for supported direct H.262 frame rates; not PES-derived PTS |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains in the repository only as a historical/reference implementation. It is not part of the active Quartus build.

## Releases

Milestone releases use semantic version tags on GitHub. MiSTer RBF assets retain the normal date-coded core naming convention.

Current published milestone release:

- **v0.2.0** — Phase 1S continuous supported all-I playback, repeated DDR ping-pong publication, presentation-path CDC cleanup, and initial presentation-timing metadata; binary asset `MediaPlayer_20260812.rbf`.

Current release candidate:

- **v0.3.0** — Phase 1T reference-picture management and the first controlled hardware-proven P-picture prediction/reconstruction paths, while preserving the v0.2.0 all-I baseline.

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
        +-----------------------------+
        |                             |
        v                             v
intra reconstruction        controlled P prediction / residual path
        |                             |
        +-------------+---------------+
                      |
                      v
planar Y / Cb / Cr DDR3 ping-pong/reference frame banks
                      |
                      v
DDR arbitration -> line caches -> 4:2:0 expansion -> BT.601 RGB
                      |
                      v
blanking-aligned repeated frame publication -> MiSTer video output
```

A sideband timing path derives a 33-bit / 90 kHz elementary-stream presentation schedule from H.262 frame-rate metadata. It is deliberately not called PTS because the current `.m2v` input has no H.222.0 PES layer; later systems-layer work can replace that synthetic source with PES timestamps while keeping the same downstream units and width.

The current P-picture logic should be understood as standards-driven, hardware-proven incremental decoder infrastructure, not as a claim of general P-picture compatibility. The diagnostic paths deliberately recognize and reconstruct narrowly controlled syntax while reference management, motion prediction, residual reconstruction, DDR persistence, and raster placement are proven independently.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for more detail.

## Building

The Quartus project is `MediaPlayer.qpf`. The project configuration targets Quartus Prime 17.0.x, matching the MiSTer framework generation used by this repository.

A typical command-line build is:

```bash
quartus_sh --flow compile MediaPlayer
```

The generated RBF is placed under `output_files/`.

The focused timing report is part of the normal development and release-candidate build workflow:

```bash
quartus_sta -t tools/phase1p_timing.tcl
```

Release candidates are accepted only after a clean/from-scratch Quartus build, the standard Phase 1P timing reports, and the required MiSTer hardware regression tests have all passed for the exact candidate commit.

See [`docs/BUILDING.md`](docs/BUILDING.md) for the full development and hardware-test workflow.

## Diagnostic streams

Hardware development uses the streams in `tools/streams/`, including:

- `test_flat_gray_i.m2v` for neutral/flat decode and color-neutrality checks;
- `test_all_i.m2v` and `test_all_i_q1.m2v` for the established all-I regression path;
- `test_ip_only.m2v` for the established I/P diagnostic path;
- `test_p420_recon.m2v` for controlled 4:2:0 P reconstruction;
- `test_p_two_mb.m2v` for controlled two-adjacent-macroblock placement/persistence;
- `test_p_four_mb_two_row.m2v` for controlled four-macroblock/two-row raster placement/persistence.

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

1. broaden P-picture syntax, prediction, and macroblock/raster handling beyond the current controlled diagnostic subset;
2. extend predictive-picture reconstruction toward general supported P-picture playback;
3. add B-picture prediction / motion compensation;
4. broaden H.262 picture structures and chroma formats;
5. improve chroma positioning/interpolation for presentation quality;
6. add H.222.0 / MPEG program-stream demux and real PES timestamps;
7. add audio;
8. add DVD navigation and optical-drive playback where practical.

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
