# Changelog

All notable project milestones are documented here.

This project is still in active pre-release development. Published milestone releases use semantic version numbers, while unreleased work remains organized by development phase.

## Unreleased

No unreleased milestone changes yet.

## [0.5.0] - 2026-08-17 — 720x480 progressive P/B `f_code` milestone

Hardware-qualified 720x480 progressive 4:2:0 I/P/B regression coverage with independently picture-signaled P/B motion-vector `f_code` handling from 1 through 4.

- Widened the bounded B syntax and raster path to 45x30 macroblocks / 720x480 while retaining separate B scratch storage and coded-order/display-order presentation.
- Generalized B residual parsing across all six 4:2:0 blocks and generalized B macroblock-address increments, escaped gaps, internal skips, and restricted same-row slice coverage within the accepted progressive envelope.
- Replaced the earlier mixed legacy/controlled P acceptance path with deterministic full-width 720x480 generators and completed generalized P parsing, raster execution, reference reads, prediction-plus-residual reconstruction, persistence, publication, and presentation through sequence end.
- Added leading P skips, macroblock-address Escape coverage, up to 32 residual descriptors, full coded-block-pattern coverage, quantiser changes, and visible P-presentation discrimination.
- Generalized P forward horizontal/vertical and B forward/backward horizontal/vertical `f_code` fields independently across values 1 through 4, including zero through three residual bits, both signs, predictor reuse/independence, H.262 wraparound, and chained references.
- Corrected the vendored ASCAL `MODE[4]` width mismatch and pipelined its vertical boundary predicate, preserving positive HDMI timing margin through the final release-candidate build.
- Replaced overlapping playback-time LED indications with a settled post-stream report and aligned acceptance with durable generalized publication/reference completion. Successful streams settle with USER and POWER solid and DISK dark.
- Established the authoritative seven-stream hardware matrix: `test_i_baseline.m2v`, `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_b_bidirectional.m2v`, `test_p_visual_discriminator.m2v`, `test_p_f_code_range.m2v`, and `test_b_f_code_range.m2v`. The former nine-stream matrix is not a release gate going forward.
- Hardware qualification accepted all seven streams with the expected LED result and clean images; the P visual discriminator retained all four quadrants and both center seams.
- Release qualification checkout: `424eec43b0d0b4f8085e6591a15543eafab394e7`; synthesized RTL baseline: `b1bde49df3831669b577a1ed78404e026f19382d`.
- The clean GitHub-clone Quartus Prime 17.0.2 build completed with no Critical Warning, zero TNS, +0.387 ns global setup, +0.207 ns global hold, +2.012 ns decoder setup, 31,625 ALMs, 42,223 registers, 592,333 block-memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs.
- The fresh-clone RBF is bit-identical to the already hardware-accepted Commit-194 artifact and has SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`.
- Audio project `fd90c775a129995544ea7aa9d9369408d949ca63` remains integration-compatible.
- Current limits remain deliberate: raw MPEG-2 Video elementary streams, progressive frame pictures, 4:2:0 chroma, the proven 720x480 regression envelope, synthetic rather than PES-derived timing, fixed diagnostic video output, no audio, and no DVD/program-stream navigation.

## [0.4.0] - 2026-08-16 — Progressive 4:2:0 I/P/B milestone

Hardware-qualified progressive 4:2:0 I/P/B decoding and presentation within the current bounded implementation envelope.

- Preserved the hardware-proven continuous progressive 4:2:0 all-I decode, DDR-backed presentation, blanking-aligned publication, and synthetic 90 kHz elementary-stream timing baseline from v0.3.0.
- Generalized P-picture reconstruction around syntax-derived per-macroblock motion and residual execution, including signed horizontal/vertical forward vectors, predictor reuse/reset, H.262 wrap behavior, integer and half-sample interpolation, 4:2:0 chroma-vector scaling, coded-block-pattern handling, sparse residual placement, run/level and Escape coefficient syntax, q_scale_type, alternate_scan, and quantiser-scale changes within the proven regression envelope.
- Preserved consecutive reconstructed-P reference promotion and corrected the publication-versus-presentation destination-ownership race by pacing a following P until its destination retained bank is no longer display-owned.
- Added the first hardware-proven B-picture core path with forward, backward, and bidirectional prediction, internal macroblock-address skips, bounded residual reconstruction, and 128x96 mixed I/P/B deterministic regressions.
- Added a dedicated B scratch DDR region and corrected frame-region identity to use the full two-bit region selector so retained bank 0, retained bank 1, and B scratch remain distinct under display-write protection.
- Added blanking-aligned B presentation/reorder handling that preserves the future P reference while the intervening B picture reconstructs and presents from scratch, then presents the retained future reference in display order.
- Split the large top-level integration into `MediaPlayer_top_00.svh` through `MediaPlayer_top_07.svh` without changing the MiSTer-facing top entity.
- Consolidated the active IDCT arithmetic around a shared multiplier bank, reducing DSP use from the earlier 92-DSP development point to 68 DSP blocks while preserving the accepted regression behavior.
- Added comments-only Audio-fork integration anchors without establishing a permanent ABI or altering synthesized behavior.
- Localized and corrected an intermittent consecutive-P failure to a display/reference destination-ownership race; the temporary first-fault, timeout-phase, writer, cache, and arbiter diagnostic layer was completely retired after the functional fix was accepted.
- Restored normal USER completion behavior after the diagnostic investigation.
- Hardware-qualified RTL baseline: `1370c28e3d34b1fd603c17130986bc336da29a32`.
- Release qualification used a fresh clone of GitHub `master`, Quartus Prime 17.0.2 Lite, the standard Phase 1P timing reports, and the full required MiSTer matrix: 20 consecutive passes of `test_p_consecutive_reference.m2v`, plus passes of `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v`.
- Qualified fit: 31,782 / 41,910 ALMs (76%), 43,812 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSP blocks, and 3 / 6 PLLs.
- Qualified timing: global setup +0.167 ns, hold +0.248 ns, recovery +4.117 ns, removal +0.704 ns, decoder setup +1.311 ns with 0/100 violations, video setup +6.987 ns with 0/80 violations, and setup endpoint TNS 0.
- Current implementation limits remain deliberate engineering bounds: established I-picture coverage reaches 720x480, while the generalized P/B hardware regressions use 128x96 / 8x6 macroblocks. General arbitrary H.262 P/B playback, interlaced/broader picture structures, non-4:2:0 chroma, H.222.0 Program Stream/PES demux and real PTS, audio, and DVD/VOB navigation remain future work.

## [0.3.0] - 2026-08-14 — Phase 1T

Reference-picture management and the first hardware-proven predictive-picture reconstruction paths.

- Preserved the hardware-proven continuous progressive 4:2:0 all-I decode, DDR ping-pong storage, blanking-aligned publication, and synthetic 90 kHz elementary-stream timing baseline from v0.2.0.
- Added reference-picture bookkeeping and controlled reference/destination DDR-bank ownership for predictive-picture work.
- Added P-picture diagnostic syntax, motion-vector, stream-hold, and reference-read paths developed against ITU-T H.262 semantics.
- Added controlled forward-prediction reconstruction paths, including zero-vector reference copying, explicit reference sampling, and the established half-sample interpolation behavior used by the hardware diagnostics.
- Added non-intra P residual parsing, inverse quantization / transform handling, prediction-plus-residual reconstruction, and ordinary DDR persistence for the controlled supported path.
- Extended the controlled P reconstruction proof from one complete 4:2:0 macroblock to two adjacent macroblocks and then to four macroblocks over two raster rows.
- Replaced fixed macroblock-index placement in the four-macroblock path with explicit raster row/column tracking and then fed that path from live coded horizontal geometry using the H.262 `(horizontal_size + 15) / 16` macroblock-width rule.
- Preserved the existing all-I hardware regressions while adding dedicated P-picture regression streams for reference reads, residual reconstruction, two-macroblock placement, and four-macroblock/two-row placement.
- Preserved the Phase 1P timing/CDC discipline throughout the predictive-picture increments.
- Current limitation: P-picture support remains a deliberately controlled hardware-proven diagnostic subset, not general arbitrary MPEG-2 P-picture playback. B pictures are not supported.
- Current input remains raw MPEG-2 Video elementary stream data; H.222.0/MPEG program-stream demux, PES timestamps, audio, and DVD/VOB playback remain future work.

## [0.2.0] - 2026-08-12 — Phase 1S

Continuous all-I playback and presentation-timing foundation.

- Extended the single re-armed H.262 parser from two pictures to continuous supported all-I picture decode.
- Reused the two planar DDR frame banks as a repeated bank 0 / bank 1 ping-pong store.
- Protected the displayed DDR bank from reconstruction writes while it remained owned by the display reader.
- Moved repeated frame publication and framebuffer re-arm into true vertical blanking so active video remains continuous.
- Removed the old asynchronous multi-bit line-number CDC bus; the line-cache handoff now crosses only a synchronized one-bit event and derives source-line identity locally in the DDR clock domain.
- Eliminated all observed playback artifacts from the continuous-all-I diagnostic stream, including mixed-frame distortion, black flicker, the bottom-edge white bar, and faint horizontal line artifacts.
- Added the first presentation-timing metadata foundation using H.262 frame-rate information and `temporal_reference` with a 33-bit 90 kHz representation compatible with later H.222.0 PTS handling.
- Kept the current elementary-stream timing explicitly synthetic: `.m2v` input has no PES layer, so the generated schedule is not represented as a normative PES PTS.
- Hardware acceptance: `test_all_i.m2v` plays to completion with USER completion correct and no observed flicker, tearing, corruption, bars, or other image artifacts.
- Final proven Phase 1S RTL commit before release documentation: `37d6268080d6d14f2e2e2d91345bc4a0132747ee`.
- Final proven Phase 1S Quartus fit at that commit: 11,349 / 41,910 ALMs (27%), 18,231 registers, 63 / 553 RAM blocks (11%), and 55 / 112 DSP blocks (49%).
- Final focused timing at that commit: decoder setup +4.838 ns, video setup +7.945 ns, decoder recovery +15.683 ns, video recovery +21.572 ns, all with TNS 0; hold and removal checks are positive.

## [0.1.0] - 2026-08-12 — Phase 1R

First hardware-proven milestone release.

- Added an alternate DDR frame bank for the second decoded picture.
- Added explicit DDR arbitration so display reads and reconstructed-frame writes can safely share the MiSTer DDRAM interface.
- Preserved picture 1 on screen while picture 2 is decoded and stored in the alternate bank.
- Made the parser wait for DDR persistence on both pictures so second-picture completion means the full frame has been stored.
- Added controlled framebuffer re-arm and frame-bank publication after picture 2 completes.
- Proved a visible picture 1 -> picture 2 transition on MiSTer hardware.
- Hardware acceptance: USER completion correct, stable color output, no tearing observed, and no flicker observed.
- Final Quartus fit: 11,342 / 41,910 ALMs (27%), 18,142 registers, 63 / 553 RAM blocks (11%), and 55 / 112 DSP blocks (49%).
- Final focused timing: decoder setup +5.265 ns, video setup +7.619 ns, decoder recovery +16.147 ns, video recovery +21.712 ns, with TNS 0; hold and removal checks are positive.
- Published GitHub pre-release tag: `v0.1.0`.
- MiSTer binary asset: `MediaPlayer_20260812.rbf`.

## Phase 1Q — Successive I-picture decode

- Proved two consecutive supported I-picture decodes in hardware.
- Reused a single proven H.262 parser by locally re-arming it between pictures.
- Kept picture 1 stored/displayed while picture 2 traverses parser, inverse quantization, IDCT, and reconstruction.
- Removed an earlier duplicated-parser diagnostic that introduced slight color-image flicker.
- Hardware acceptance: both diagnostic streams pass, image is stable, USER completion behavior is correct.

## Phase 1P — Timing and CDC closure

- Closed the real 54 MHz decoder and 40 MHz video timing paths.
- Pipelined and balanced inverse-quantization and IDCT arithmetic where required.
- Synchronized reset release independently in each destination clock domain.
- Enabled synchronized DCFIFO asynchronous-clear handling.
- Narrowed timing exceptions to intentional synchronizer boundaries rather than broad clock-domain false paths.
- Final accepted setup and recovery reports had zero total negative slack on the decoder and video clocks.

## Phase 1O — Full-precision DDR frame storage and readback

### Phase 1Oa

- Added full-precision planar Y/Cb/Cr DDR3 writes.
- Serialized block persistence so the parser could not advance until reconstructed block data reached DDR.
- Kept the existing on-chip framebuffer active temporarily to isolate DDR-write verification.

### Phase 1Ob

- Removed the large full-picture on-chip framebuffer.
- Added DDR3 readback through small dual-clock ping-pong line caches.
- Restored full 8-bit chroma presentation.
- Moved decoder frame storage away from the MiSTer system-video DDR region after identifying an address collision.
- Reduced M10K use dramatically compared with full-frame on-chip storage.

## Phase 1N — Full color reconstruction

- Added Cb and Cr to the serialized inverse-quantization, IDCT, and reconstruction pipeline.
- Implemented 4:2:0 component storage and BT.601 YCbCr-to-RGB conversion.
- Proved the first complete color picture in hardware.
- Used a temporary reduced-chroma on-chip storage format before the later DDR architecture removed the M10K pressure.

## Phase 1M — Complete first picture

- Continued parsing across all slices of the first supported I picture.
- Correctly reset slice-local DC predictors and macroblock address state.
- Produced the first complete 720x480 grayscale MPEG-2 picture.

## Phase 1L — Complete slice decode

- Removed the temporary fixed macroblock-count stop.
- Decoded an entire slice.
- Used H.262 slice termination rather than assuming a fixed row length.

## Phase 1K — Streaming bitreader

- Replaced the bounded whole-slice capture buffer with a streaming bitreader.
- Added exact byte/bit consumption and FIFO backpressure while downstream arithmetic was busy.
- Removed an implementation capture limit that had previously appeared as a decode failure.

## Phase 1J — Multi-macroblock diagnostics

- Expanded decode beyond the first macroblock.
- Parsed Cb/Cr block syntax sufficiently to advance through consecutive 4:2:0 intra macroblocks.
- Added detailed diagnostics that localized a failure to exhaustion of the temporary slice capture buffer.

## Phase 1I — First full luma macroblock

- Decoded all four Y blocks of the first 4:2:0 intra macroblock.
- Produced a stable 16x16 decoded luma region in hardware.

## Phase 1H — Legacy decoder removed from active build

- Removed MPEG2FPGA and its DDR bridge from the active Quartus design.
- Retained the source tree only as a frozen reference implementation.
- Reduced FPGA resource usage substantially and improved hardware stability.

## Phase 1G — Independent display timing

- Decoupled display timing from the legacy decoder.
- Added a fixed 800x600 / 40 MHz diagnostic timing generator.
- Eliminated raster shifts caused by the earlier timing path.

## Earlier clean-decoder milestones

- Began a standards-driven H.262 decoder.
- Parsed slice and first intra-macroblock syntax.
- Decoded intra DC and AC VLC data, including run/level and end-of-block handling.
- Implemented inverse quantization.
- Implemented a fixed-point two-pass 8x8 IDCT.
- Displayed the first decoded 8x8 luma block.
