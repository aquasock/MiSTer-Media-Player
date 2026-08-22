# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. **v0.5.0 is the current published hardware-qualified milestone.** It extends the progressive 4:2:0 I/P/B path to the 720x480 regression geometry and independently applies picture-signaled P/B motion-vector `f_code` values from 1 through 4. Audio, program-stream demux, DVD support, and broader H.262 coverage remain future work.

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
- syntax-derived per-macroblock P forward motion with independently signaled horizontal/vertical `f_code` values from 1 through 4, signed vectors, predictor reuse/reset, integer and half-sample interpolation, H.262 wraparound, and 4:2:0 chroma-vector scaling;
- syntax-derived 4:2:0 coded-block-pattern selection across Y0/Y1/Y2/Y3/Cb/Cr;
- generalized non-intra P coefficient handling including ordinary run/level VLCs, non-zero runs, signs, EOB, Escape syntax, q_scale_type, alternate_scan, and quantiser-scale changes;
- prediction-plus-residual reconstruction, clipping, DDR persistence/readback, and generalized P-picture re-arm;
- bounded B-picture reconstruction with independently signaled forward/backward horizontal/vertical `f_code` values from 1 through 4, forward/backward/bidirectional prediction, internal macroblock skips, residual reconstruction, scratch persistence, and coded-order/display-order presentation handling;
- a 33-bit / 90 kHz synthetic elementary-stream presentation-timing foundation derived from H.262 frame-rate information and `temporal_reference`.

The current implementation subset remains intentionally bounded while the decoder architecture is being proven. These are implementation limits, **not** limits of H.262.

| Area | Current implementation |
| --- | --- |
| Input | MPEG-2 Video elementary stream |
| Picture type | Continuous supported I pictures; generalized hardware-proven P regression path; bounded hardware-proven B regression/presentation path |
| Picture structure | Progressive frame pictures on the proven paths |
| Chroma format | 4:2:0 |
| Proven geometry | Up to 720x480 / 45x30 macroblocks for the authoritative I, P, and B regression paths |
| Generalized P motion envelope | Independently signaled horizontal/vertical `f_code` 1..4, signed vectors, predictor reuse/reset and wraparound, integer/H/V/bilinear half-sample prediction |
| Generalized P residual envelope | Up to 32 coded residual blocks and 64 non-zero coefficient events per picture; implementation caps |
| B regression envelope | Independently signaled forward/backward H/V `f_code` 1..4, forward/backward/bidirectional prediction, internal skips, bounded residuals, B scratch storage, and display reordering |
| Reconstruction precision | 8-bit Y/Cb/Cr |
| Frame storage | Two retained planar MiSTer DDR3 I/P frame banks plus a distinct B scratch region |
| Timing metadata | Synthetic elementary-stream 33-bit / 90 kHz schedule; not PES-derived PTS |
| Video output | Fixed 800x600 diagnostic timing |

The frozen `rtl/mpeg2fpga/` tree remains only as a historical/reference implementation and is not part of the active Quartus build.

## Releases

Milestone releases use semantic-version tags on GitHub. MiSTer RBF assets retain the normal date-coded core naming convention.

Current published milestone release:

- **v0.5.0** — 720x480 progressive 4:2:0 I/P/B regression coverage, generalized P/B motion-vector `f_code` 1-through-4 handling, full-width P parser/raster completion, and settled post-stream diagnostics; binary asset `MediaPlayer_20260817.rbf`.

The v0.5.0 release qualification checkout is commit `424eec43b0d0b4f8085e6591a15543eafab394e7`, whose synthesized RTL baseline is `b1bde49df3831669b577a1ed78404e026f19382d`. It passed a fresh-clone Quartus Prime 17.0.2 build and the authoritative seven-stream MiSTer regression matrix before the documentation-only release commits were applied.

See [`docs/RELEASE_NOTES_v0.5.0.md`](docs/RELEASE_NOTES_v0.5.0.md) for release notes and qualification details.

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

Binary regression streams are generated locally from deterministic scripts under `tools/streams/`. The authoritative seven-stream hardware matrix is:

- `test_i_baseline.m2v` for continuous full-width all-I decoding;
- `test_p_motion_residual.m2v` for P motion phases, coded-block patterns, residual reconstruction, and quantiser changes;
- `test_p_mba_escape.m2v` for ordinary and escaped macroblock-address gaps, including leading skips;
- `test_b_bidirectional.m2v` for mixed I/P/B coded/display order, forward/backward/bidirectional motion, residuals, and predictor independence;
- `test_p_visual_discriminator.m2v` for visible P-frame publication, identified by four quadrants and two center seams;
- `test_p_f_code_range.m2v` for independent P horizontal/vertical `f_code` values 1 through 4, residual bits, signs, reuse, and wraparound;
- `test_b_f_code_range.m2v` for independent B forward/backward horizontal/vertical `f_code` values 1 through 4 across two B reference pairs.

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

After v0.5.0, decoder work can broaden the currently bounded P/B implementation toward a wider real-stream H.262 compatibility envelope, including broader picture structures and chroma formats. Later work includes presentation-quality chroma improvements, H.222.0 Program Stream/PES handling and real timestamps, audio integration, and DVD navigation/optical-drive integration.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Systems/program-stream work uses **ITU-T H.222.0 / ISO/IEC 13818-1**.

Implementation constraints, diagnostic-stream limits, synthetic elementary-stream timing, and temporary engineering shortcuts are implementation choices rather than MPEG-2 requirements.

## AI-assisted development in v0.6.0

I am also going to formally expose the **AI project-control system** I use to manage MiSTer-Media-Player as part of the upcoming v0.6.0 release, for anyone interested in experimenting with it.

The `.ai` directory has actually been in the repository for quite a while and has been quietly driving most of the project's development. With v0.6.0, I want to start treating it as something contributors can experiment with rather than just my own internal workflow.

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

v0.6.0 will be the first release where I start treating this workflow itself as something the community can beta test.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
