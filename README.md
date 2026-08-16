# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. **v0.4.0 is the current hardware-qualified release candidate.** It preserves the established progressive 4:2:0 all-I path, the generalized P-picture path, and adds the first hardware-proven bounded B-picture reconstruction/presentation path. Audio, program-stream demux, DVD support, and broader H.262 coverage remain future work.

## Current status

The active decoder is a clean H.262 implementation under `rtl/mpeg2_new/`. It currently provides:

- streaming MPEG-2 elementary-stream input with FIFO backpressure;
- picture, slice, macroblock, block, and DCT VLC parsing for the supported paths;
- inverse quantization and fixed-point two-pass 8x8 IDCT;
- full 8-bit Y, Cb, and Cr intra reconstruction;
- two retained planar MiSTer DDR3 frame banks for I/P ping-pong/reference ownership plus a separate B scratch region;
- explicit DDR arbitration, DDR3 readback through small line caches, display-region write protection, and blanking-aligned frame publication;
- 4:2:0 chroma expansion and limited-range BT.601 YCbCr-to-RGB presentation;
- continuous supported all-I picture decode using one re-armed parser;
- P-picture reference ownership, publication, consecutive reconstructed-P reference promotion, and destination-ownership pacing;
- syntax-derived per-macroblock P forward motion with signed horizontal/vertical vectors, predictor reuse/reset, integer and half-sample interpolation, and 4:2:0 chroma-vector scaling on the generalized path;
- syntax-derived 4:2:0 coded-block-pattern selection across Y0/Y1/Y2/Y3/Cb/Cr;
- generalized non-intra P coefficient handling including ordinary run/level VLCs, non-zero runs, signs, EOB, Escape syntax, q_scale_type, alternate_scan, and quantiser-scale changes;
- prediction-plus-residual reconstruction, clipping, DDR persistence/readback, and generalized P-picture re-arm;
- bounded B-picture reconstruction with forward, backward, and bidirectional prediction, internal macroblock skips, residual reconstruction, scratch persistence, and coded-order/display-order presentation handling on the hardware-proven regression path;
- a 33-bit / 90 kHz synthetic elementary-stream presentation-timing foundation derived from H.262 frame-rate information and `temporal_reference`.

The current implementation subset remains intentionally bounded while the decoder architecture is being proven. These are implementation limits, **not** limits of H.262.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | Continuous supported I pictures; generalized hardware-proven P regression path; bounded hardware-proven B regression/presentation path |
| Picture structure | Progressive frame pictures on the proven paths |
| Chroma format | 4:2:0 |
| Proven geometry | Up to 720x480 for the established I path; 128x96 / 8x6 macroblocks for the generalized P and B regression paths |
| Generalized P motion envelope | Forward f_code=(3,3), signed H/V vectors, predictor reuse/reset, integer/H/V/bilinear half-sample prediction |
| Generalized P residual envelope | Up to 16 coded residual blocks and 64 non-zero coefficient events per picture; implementation caps |
| B regression envelope | Deterministic mixed I/P/B streams with forward/backward/bidirectional prediction, internal skips, bounded residuals, B scratch storage, and display reordering |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | Two retained planar MiSTer DDR3 I/P frame banks plus a distinct B scratch region |
| Timing metadata | Synthetic elementary-stream 33-bit / 90 kHz schedule; not PES-derived PTS |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains only as a historical/reference implementation and is not part of the active Quartus build.

## Releases

Milestone releases use semantic-version tags on GitHub. MiSTer RBF assets retain the normal date-coded core naming convention.

Current published milestone release:

- **v0.3.0** — Phase 1T reference-picture management and the first controlled hardware-proven P-picture prediction/reconstruction paths; binary asset `MediaPlayer_20260814.rbf`.

Current hardware-qualified release candidate:

- **v0.4.0** — generalized progressive 4:2:0 P-picture decoding plus the first bounded hardware-proven B-picture reconstruction/presentation path, corrected reference/display ownership handling, and the 68-DSP shared-IDCT baseline.

The v0.4.0 RTL qualification baseline is commit `1370c28e3d34b1fd603c17130986bc336da29a32`. It passed a fresh-clone Quartus Prime 17.0.2 build and the required MiSTer regression matrix before the documentation-only release commits were applied.

See [`docs/RELEASE_NOTES_v0.4.0.md`](docs/RELEASE_NOTES_v0.4.0.md) for release notes and qualification details.

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
        +----------------------+----------------------+
        |                      |                      |
        v                      v                      v
intra reconstruction    P prediction + residual    B prediction + residual
        |                      |                      |
        +----------+-----------+                      |
                   |                                  v
                   |                            B scratch DDR
                   |                                  |
                   +------------------+---------------+
                                      |
                                      v
                  retained I/P DDR reference banks + presentation scheduler
                                      |
                                      v
                 DDR arbitration -> line caches -> 4:2:0 expansion -> BT.601 RGB
                                      |
                                      v
                 blanking-aligned publication/reorder -> MiSTer video output
```

A sideband timing path derives a 33-bit / 90 kHz elementary-stream presentation schedule from H.262 frame-rate metadata. It is deliberately not called PTS because the current `.m2v` input has no H.222.0 PES layer.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for architectural background and [`docs/MPEG2_NEW_DECODER.md`](docs/MPEG2_NEW_DECODER.md) for the decoder development record.

## Building

The Quartus project is `MediaPlayer.qpf` and targets Quartus Prime 17.0.x.

```bash
quartus_sh --flow compile MediaPlayer
quartus_sta -t tools/phase1p_timing.tcl
```

Release candidates are accepted only after a clean/from-scratch Quartus build, the standard Phase 1P timing reports, and the required MiSTer hardware regression tests all pass for the candidate RTL.

See [`docs/BUILDING.md`](docs/BUILDING.md) for the full workflow.

## Diagnostic streams

Binary regression streams are generated locally from deterministic scripts under `tools/streams/`. Important current regressions include:

- `test_all_i.m2v` for the established continuous all-I path;
- `test_p_general_decode.m2v` for the combined generalized signed-motion, interpolation, skip/predictor, quantiser, and residual P path;
- `test_p_consecutive_reference.m2v` for reconstructed P-to-P reference promotion and destination-ownership pacing;
- `test_b_core_decode.m2v` for the bounded B-picture core reconstruction path;
- `test_b_mixed_gop.m2v` for mixed I/P/B coded order, B forward/backward/bidirectional prediction, and display-order presentation.

The USER LED is used as a positive completion diagnostic during development. Its exact gating is not a public player UI.

## Project layout

- `MediaPlayer.sv` and `MediaPlayer_top_*.svh` — MiSTer top-level glue, decoder integration, ownership, and presentation scheduling.
- `rtl/mpeg2_new/` — active standards-driven H.262 decoder pipeline.
- `rtl/mpeg2_luma_framebuffer.sv` — DDR-backed frame readback and video-side line caching.
- `rtl/mpeg2fpga/` — frozen legacy reference; inactive in `files.qip`.
- `sys/` — MiSTer framework.
- `tools/` — timing scripts and deterministic diagnostic-stream generators.
- `docs/` — architecture, building, decoder, and release documentation.
- `files.qip` — authoritative active RTL source list for Quartus.

## Development roadmap

After v0.4.0, decoder work can broaden the currently bounded P/B implementation toward a wider real-stream H.262 compatibility envelope, including broader picture structures and chroma formats. Later work includes presentation-quality chroma improvements, H.222.0 Program Stream/PES handling and real timestamps, audio integration, and DVD navigation/optical-drive integration.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Systems/program-stream work uses **ITU-T H.222.0 / ISO/IEC 13818-1**.

Implementation constraints, diagnostic-stream limits, synthetic elementary-stream timing, and temporary engineering shortcuts are implementation choices rather than MPEG-2 requirements.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
