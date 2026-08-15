# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. Phase 1U is the **v0.4.0 release candidate**. It preserves the hardware-proven continuous progressive 4:2:0 all-I path and advances P-picture decoding from the narrow v0.3.0 diagnostic subsets to a substantially generalized syntax-derived path within the current progressive 4:2:0 implementation envelope. B pictures, audio, program-stream demux, and DVD support remain future work.

## Current status

The active decoder is a clean H.262 implementation under `rtl/mpeg2_new/`. It currently provides:

- streaming MPEG-2 elementary-stream input with FIFO backpressure;
- picture, slice, macroblock, block, and DCT VLC parsing for the supported paths;
- inverse quantization and fixed-point two-pass 8x8 IDCT;
- full 8-bit Y, Cb, and Cr intra reconstruction;
- planar MiSTer DDR3 frame storage with two ping-pong/reference banks;
- explicit DDR arbitration, DDR3 readback through small line caches, and blanking-aligned frame publication;
- 4:2:0 chroma expansion and limited-range BT.601 YCbCr-to-RGB presentation;
- continuous supported all-I picture decode using one re-armed parser;
- P-picture reference ownership, publication, and consecutive reconstructed-P reference promotion;
- syntax-derived per-macroblock P forward motion with signed horizontal/vertical vectors, predictor reuse/reset, integer and half-sample interpolation, and 4:2:0 chroma-vector scaling on the generalized path;
- syntax-derived 4:2:0 coded-block-pattern selection across Y0/Y1/Y2/Y3/Cb/Cr;
- generalized non-intra P coefficient handling including ordinary run/level VLCs, non-zero runs, signs, EOB, Escape syntax, q_scale_type, alternate_scan, and quantiser-scale changes;
- prediction-plus-residual reconstruction, clipping, DDR persistence/readback, and generalized P-picture re-arm;
- a 33-bit / 90 kHz synthetic elementary-stream presentation-timing foundation derived from H.262 frame-rate information and `temporal_reference`.

The current implementation subset remains intentionally bounded while the decoder architecture is being proven. These are implementation limits, **not** limits of H.262.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | Continuous supported I pictures; generalized hardware-proven P regression path; no B pictures |
| Picture structure | Progressive frame pictures on the proven paths |
| Chroma format | 4:2:0 |
| Proven geometry | Up to 720x480 for the established I path; 128x96 / 8x6 macroblocks for the generalized P regression path |
| Generalized P motion envelope | Forward f_code=(3,3), signed H/V vectors, predictor reuse/reset, integer/H/V/bilinear half-sample prediction |
| Generalized P residual envelope | Up to 16 coded residual blocks and 64 non-zero coefficient events per picture; implementation caps |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | Two planar MiSTer DDR3 frame banks used as ping-pong/reference storage |
| Timing metadata | Synthetic elementary-stream 33-bit / 90 kHz schedule; not PES-derived PTS |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains only as a historical/reference implementation and is not part of the active Quartus build.

## Releases

Milestone releases use semantic-version tags on GitHub. MiSTer RBF assets retain the normal date-coded core naming convention.

Current published milestone release:

- **v0.3.0** — Phase 1T reference-picture management and the first controlled hardware-proven P-picture prediction/reconstruction paths; binary asset `MediaPlayer_20260814.rbf`.

Current release candidate:

- **v0.4.0** — Phase 1U generalized progressive 4:2:0 P-picture syntax, motion, residual, interpolation, persistence, and consecutive-reference handling within the current implementation envelope.

See [`docs/RELEASE_NOTES_v0.4.0.md`](docs/RELEASE_NOTES_v0.4.0.md) for the candidate release notes.

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
intra reconstruction          P prediction + residual
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
blanking-aligned frame publication -> MiSTer video output
```

A sideband timing path derives a 33-bit / 90 kHz elementary-stream presentation schedule from H.262 frame-rate metadata. It is deliberately not called PTS because the current `.m2v` input has no H.222.0 PES layer.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for architectural background and [`docs/MPEG2_NEW_DECODER.md`](docs/MPEG2_NEW_DECODER.md) for the decoder development record.

## Building

The Quartus project is `MediaPlayer.qpf` and targets Quartus Prime 17.0.x.

```bash
quartus_sh --flow compile MediaPlayer
quartus_sta -t tools/phase1p_timing.tcl
```

Release candidates are accepted only after a clean/from-scratch Quartus build, the standard Phase 1P timing reports, and the required MiSTer hardware regression tests all pass for the exact candidate commit.

See [`docs/BUILDING.md`](docs/BUILDING.md) for the full workflow.

## Diagnostic streams

Binary regression streams are generated locally from deterministic scripts under `tools/streams/`. Important current regressions include:

- `test_all_i.m2v` for the established continuous all-I path;
- `test_p_general_residual_plan.m2v` for syntax-derived sparse residual block selection;
- `test_p_consecutive_reference.m2v` for reconstructed P-to-P reference promotion;
- `test_p_general_transform_controls.m2v` for generalized q_scale_type/alternate-scan residual controls;
- `test_p_general_decode.m2v` for the combined generalized signed-motion, interpolation, skip/predictor, quantiser, and residual path.

The USER LED is used as a positive completion diagnostic during development. Its exact gating is not a public player UI.

## Project layout

- `MediaPlayer.sv` — MiSTer top-level glue and decoder integration.
- `rtl/mpeg2_new/` — active standards-driven H.262 decoder pipeline.
- `rtl/mpeg2_luma_framebuffer.sv` — DDR-backed frame readback and video-side line caching.
- `rtl/mpeg2fpga/` — frozen legacy reference; inactive in `files.qip`.
- `sys/` — MiSTer framework.
- `tools/` — timing scripts and deterministic diagnostic-stream generators.
- `docs/` — architecture, building, decoder, and release documentation.
- `files.qip` — authoritative active RTL source list for Quartus.

## Development roadmap

After v0.4.0, the next major decoder boundary is B-picture prediction/motion compensation. Later work includes broader H.262 picture structures/chroma formats, presentation-quality chroma improvements, H.222.0 Program Stream/PES handling and real timestamps, audio, and DVD navigation/optical-drive integration.

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
