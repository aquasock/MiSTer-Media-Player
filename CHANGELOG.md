# Changelog

All notable project milestones are documented here.

This project is still in active pre-release development. Published milestone releases use semantic version numbers, while unreleased work remains organized by development phase.

## Unreleased

No unreleased milestone changes yet.

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
- Kept picture 1 stored/displayed while picture 2 traversed parser, inverse quantization, IDCT, and reconstruction.
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
