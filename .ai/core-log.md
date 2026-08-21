---
## 259 COMMIT Unreleased 9101fcc 2026-08-20T06:47:21-07:00

#### Coming From:

Unreleased 1138b7a

#### Purpose:

Attribute the remaining exact decoder backpressure to its mutually exclusive parser, replay, reconstruction, persistence, and presentation owners before selecting the next production optimization.

#### Outcome:

Commit `9101fcc` adds simulation-only attribution at the publication and row-controller boundaries without changing decoder behavior. The exact 423,936-pixel mixed trace remains 1,969,996 cycles with zero mismatches, maximum delta two, 69,556 reads, 23 swaps and zero errors; its 1,845,062 decoder-wait cycles divide into 29,877 base-parser, 724,223 P-row and 1,090,962 B-row cycles. The P hold divides into 160,555 parse, 69,546 spatial replay, 232,118 raster and 262,004 transform/coordination cycles; the B hold divides into 182,004 parse, 428,277 transform/replay and 480,681 row-persistence cycles. The exact long trace remains 10,719,996 cycles with 372,696 reads, 25 publications, 71 swaps and zero errors; its 10,276,423 decoder-wait cycles divide into 146,944 base-parser, 2,787,631 P-row and 7,341,848 B-row cycles. Long P holds divide into 646,591 parse, 332,508 spatial replay, 571,368 raster and 1,237,164 transform/coordination cycles, while B holds divide into 1,548,488 parse, 3,078,515 transform/replay and 2,714,845 row-persistence cycles. The measurements prove whole rows still serialize parse, transform replay and raster, and also show an immediate contained waste: transformed spatial blocks are first captured and then replayed for another 64 cycles each.

#### Next Steps:

Forward each transform's already ordered spatial output directly into the P/B raster capture protocol after its descriptor, removing the duplicate 64-cycle temporary-buffer replay while retaining complete-row reconstruction and every existing ownership barrier. Require the mixed exact-pixel oracle to remain bit-exact and the long boundary to preserve all reads, writes, publications, swaps and zero-error accounting; proceed to Quartus only if the measured cycle reduction is material.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 260 COMMIT Unreleased c958794 2026-08-20T07:03:18-07:00

#### Coming From:

Unreleased 9101fcc

#### Purpose:

Remove the duplicate 64-cycle spatial-sample replay after each transformed P/B residual block by streaming the transform's ordered output directly into row capture.

#### Outcome:

Commit `c958794` publishes each P/B block descriptor before transform start and forwards the transform's existing registered index-zero-through-index-63 spatial output directly into row capture, removing both private 64-sample arrays and their duplicate replay states. The exact mixed boundary preserves all 423,936 pixels with zero mismatches and maximum delta two, 69,556 reads, every write, nine publications, 23 swaps and zero errors while falling from 1,969,996 to 1,809,996 cycles, an 8.12 percent reduction. The complete long boundary preserves 372,696 reads, all reference/scratch writes, 25 publications, 71 swaps and zero errors while falling from 10,719,996 to 9,779,996 cycles, an 8.77 percent reduction. Focused B residual streaming falls by exactly 7,680 cycles across 120 blocks while preserving 7,680 samples, 518,400 stores and its authored stripe; P intra falls by exactly 384 cycles across six blocks with all samples exact. B intra, eight-refill parser windows, dense P row streaming across 8,100 blocks and 518,400 samples, and dense B row streaming across 8,073 blocks and 516,672 samples all pass exact ordering and accounting. The measured simulation gain projects the accepted hardware from 19.85 to approximately 21.61 fps mixed and from 21.82 to approximately 23.92 fps long if timing and hardware scale proportionally.

The fully clean seed-six Quartus 17.0.2 build completes in 10 minutes 12 seconds with zero errors, 143 standing warnings, no Critical Warning and no combinational loop. Timing is positive at +0.364 ns global setup, +1.385 ns decoder setup, +7.828 ns video setup, +0.248 ns hold, +3.006 ns global recovery, +14.138 ns decoder recovery and +0.724 ns removal. The fit uses 30,826 ALMs, 45,389 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Generated `MediaPlayer.rbf` is 4,295,800 bytes with SHA-256 `1861768efab90d93a5805f9545aa1565be7884df1eab0b4fb38386b3be1e77bf`.

Exact MiSTer telemetry passes both compatibility streams with the timing-qualified RBF. Long GOP accepts all 791,528 bytes, displays all 72 pictures with 71 swaps, zero error flags and zero destination stalls, and improves from 175,691,819 cycles at 21.822302 fps to 173,900,457 cycles at 22.047096 fps: 1,791,362 cycles or 1.02 percent removed and 1.03 percent more delivered cadence. Mixed macroblocks accepts all 366,071 bytes, displays all 24 pictures with 23 swaps, zero error flags and zero destination stalls, and improves from 62,563,846 cycles at 19.851721 fps to 61,431,804 cycles at 20.217541 fps: 1,132,042 cycles or 1.81 percent removed and 1.84 percent more delivered cadence. The hardware gain is therefore real but substantially smaller than the isolated simulation projection; presentation and memory-response overlap mask most of the eliminated local replay cycles. `MediaPlayer_commit260_c958794.rbf` is deployed and retained for the requested visual acceptance check.

#### Next Steps:

Pause on the deployed Entry 260 RBF for the user's visual check of both compatibility streams. If its accepted LED signatures and visibly smoother playback remain correct, attribute the newly exposed hardware stalls before selecting the next overlap or queueing change toward stable 25 fps.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv

#### Status:

- [x] Built
- [x] Passed

---
## 261 COMMIT Unreleased 3dc020b 2026-08-20T07:38:21-07:00

#### Coming From:

Unreleased c958794

#### Purpose:

Recalibrate the proven prediction-request queue against measured MiSTer DDR response latency and deploy a deeper ordered boundary only if complete exact traces predict a material cadence gain.

#### Outcome:

Entry 260 is timing-clean and exact on both hardware streams, but removing 8.12 percent of mixed and 8.77 percent of long isolated simulation cycles improves MiSTer cadence by only 1.84 and 1.03 percent. Its telemetry records 8,941,202 mixed and 27,723,374 long cycles with at least one prediction response outstanding, while 69,556 and 372,696 physical prediction reads imply roughly 129 and 74 outstanding cycles per read. Commit `3dc020b` replaces the simulation delay shifter with an exact circular response queue supporting up to 256 cycles and raises the already-proven block-fetcher, cache and arbiter production depth from two to four. At the calibrated 128-cycle mixed latency, depth four reduces the complete trace from 5,869,996 to 3,729,996 cycles, 36.46 percent, while preserving all 423,936 pixels with maximum delta two, 69,556 reads, 23 swaps and zero errors. At the calibrated 74-cycle long latency it reduces the complete trace from 21,539,996 to 15,039,996 cycles, 30.18 percent, while preserving 372,696 reads, all writes, 25 publications, 71 swaps and zero errors. Default one-cycle mixed and long boundaries remain exact at 1,809,996 and 9,719,996 cycles, and focused fetcher, cache and arbiter regressions pass depth-four fill/drain, response order, backpressure, display priority, same-cycle full-queue replacement, direct response and writer exclusion.

The fully clean seed-six Quartus 17.0.2 build completes in 10 minutes 8 seconds with zero errors, 143 standing warnings, no Critical Warning and no combinational loop. Timing is positive at +0.410 ns global setup, +1.524 ns decoder setup, +7.062 ns video setup, +0.249 ns hold, +3.082 ns global recovery, +15.519 ns decoder recovery and +0.685 ns removal. The fit uses 30,981 ALMs, 45,493 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. `MediaPlayer_commit261_3dc020b.rbf` is 4,314,724 bytes with SHA-256 `2c4a6436f13d601659a0166e532ab82948e3862cc5b16900b53f21e57b1efe64`; the standard MiSTer upload and FTP readback match byte-for-byte.

Exact MiSTer telemetry accepts Entry 261 on both streams with every byte and picture, 71 and 23 swaps, zero error flags and zero destination stalls. Long improves from 173,900,457 cycles at 22.047096 fps to 171,214,171 cycles at 22.393006 fps, removing 2,686,286 cycles or 1.54 percent and improving delivered cadence 1.57 percent. Mixed changes only from 61,431,804 cycles at 20.217541 fps to 61,408,518 cycles at 20.225207 fps, removing 23,286 cycles or 0.04 percent. Prediction-response occupancy nevertheless falls from 27,723,374 to 14,270,560 long and from 8,941,202 to 4,609,850 mixed, approximately halving on both streams; only 2,141,506 long and 677,908 mixed decoder-stall cycles reach the input boundary. Writer wait simultaneously rises by 418,436 long and 158,157 mixed, while mixed presentation wait rises by 532,378 cycles. The depth-four path is exact, timing-safe and a real long-stream gain, but the calibrated fixed-latency model overstates end-to-end benefit because read overlap now starves lower-priority writes and earlier decode completion converts to cadence-gated presentation wait.

#### Next Steps:

Retain the exact timing-safe depth-four boundary and test whether reconstruction writes may be accepted in command gaps while ordered read responses remain outstanding. Preserve display priority, reader-region exclusion and read-response ownership; require a focused read/write/read overlap proof plus the calibrated complete traces to show that removing the arbiter's all-reads-drained writer barrier reduces writer and row-persistence wait before another Quartus build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/streams/tb_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_ddram_arbiter.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 262 COMMIT Unreleased 3dc020b 2026-08-20T08:18:22-07:00

#### Coming From:

Unreleased 3dc020b

#### Purpose:

Permit non-aliasing reconstruction writes to use idle DDR command slots while ordered read responses remain outstanding instead of waiting for the entire read queue to drain.

#### Outcome:

Entry 261 proves that four ordered reads are exact and nearly halve prediction-response occupancy, but hardware cadence improves only 1.57 percent long and 0.04 percent mixed. The deeper queue increases writer wait from 2,919,542 to 3,337,978 cycles long and from 963,004 to 1,121,161 mixed because the arbiter currently asserts writer busy whenever any read descriptor remains outstanding. A temporary candidate removed only that term while retaining live reader priority, prediction priority, DDR busy, displayed-region exclusion and ordered response ownership; the strengthened arbiter test passed a prediction-read, non-aliasing write and prediction-response sequence with the write accepted before the response. The calibrated exact mixed boundary nevertheless remained identically 3,729,996 cycles with all 423,936 pixels, 69,556 reads, every write, 23 swaps and zero errors. Active reconstruction completes every block's footprint reads before it begins persistence, so the proposed command gap does not exist on the path being optimized. The candidate and its test expectation were fully removed, no source change remains, and no Quartus or hardware cycle is justified.

#### Next Steps:

Retain accepted Entry 261 unchanged. Target the serialized P/B row schedule instead: measure a bounded ping-pong or descriptor queue that permits parsing and transforming the following row while the completed row reconstructs and persists, with explicit residual/motion bank ownership and unchanged publication order. Prove its complete-trace ceiling before functional RTL because this is a larger architectural boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 263 COMMIT Unreleased a9c9ea9 2026-08-20T08:22:46-07:00

#### Coming From:

Unreleased 3dc020b

#### Purpose:

Measure the complete-trace ceiling of a two-bank P/B row pipeline that overlaps parsing and transform production for the following row with reconstruction and persistence of the current row.

#### Outcome:

Entry 262 proves command-level write interleave cannot help because every active block completes its prediction footprint before persistence begins. Commit `a9c9ea9` adds optional simulation-only READY/RETIRE tracing at the live P/B row-ownership boundaries plus a deterministic two-machine, two-bank flow-shop replay; neither changes production RTL. The exact mixed boundary remains 1,809,996 cycles with all 423,936 pixels, 69,556 reads, every write, 23 swaps and zero errors. Across its eight P and fifteen B pictures, P row span falls from 637,492 to 496,136 modeled cycles, saving 22.17 percent, while B falls from 933,494 to 592,188, saving 36.56 percent; 482,662 combined cycles equal 26.67 percent of the whole trace. The exact long boundary remains 9,719,996 cycles with 372,696 reads, all writes, 25 publications, 71 swaps and zero errors. Across its 22 P and 47 B pictures, P row span falls from 2,422,526 to 1,818,516 cycles, saving 24.93 percent, while B falls from 6,111,471 to 3,854,559, saving 36.93 percent; 2,860,922 combined cycles equal 29.43 percent of the whole trace. The consistent complete-stream ceiling justifies functional ping-pong ownership, and the existing row memories have sufficient logical address space to bank without adding a physical RAM block.

#### Next Steps:

Implement logical row-bank ownership in a simulation-first boundary: allow the parser/transform producer to fill the alternate bank while reconstruction consumes the current bank, prevent bank reuse until row persistence retires it, and preserve picture-final publication barriers. Begin with one engine if shared controller coupling makes a combined P/B change unsafe, reuse existing memory address space, and require exact pixels, reads, writes, publications and swaps plus a material complete-trace reduction before Quartus.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/analyze_row_pipeline_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 264 COMMIT Unreleased 5a3c0e4 2026-08-20T09:21:36-07:00

#### Coming From:

Unreleased a9c9ea9

#### Purpose:

Overlap B-picture parsing and transform production for the following row with reconstruction and persistence of the current row through two logical metadata banks.

#### Outcome:

Commit `5a3c0e4` gives the B producer and raster consumer two credit-counted row banks while reusing the existing 2,048-descriptor and 131,072-sample physical memories as two 1,024-descriptor logical halves. Capture and execution use independent bank ownership, descriptor counts, motion ranges and row identities; a bank cannot be reused before its persistence pulse, and final-picture completion waits until every queued row retires. The exact mixed oracle preserves all 423,936 pixels with zero mismatches and maximum delta two, 69,556 reads, every write, nine publications, 23 swaps and zero errors while falling from 1,809,996 to 1,459,996 cycles, a 19.34 percent reduction. The exact long boundary preserves 372,696 reads, all writes, 25 publications, 71 swaps and zero errors while falling from 9,719,996 to 7,469,996 cycles, a 23.15 percent reduction. Focused B residual, B intra, eight-refill parser-window, 8,073-block dense row-streaming and complete mixed publication regressions pass; B residual falls from 1,384,609 to 1,341,421 cycles while preserving every sample and store. The fully clean seed-six Quartus 17.0.2 build completes in 10 minutes 17 seconds with zero errors, 144 standing warnings, no Critical Warning and no combinational loop. Timing is positive at +0.412 ns global setup, +1.776 ns decoder setup, +7.089 ns video setup, +0.254 ns hold, +4.137 ns global recovery, +15.830 ns decoder recovery and +0.803 ns removal. The fit uses 31,017 ALMs, 45,564 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. `MediaPlayer_commit264_5a3c0e4.rbf` is 4,298,100 bytes with SHA-256 `c38649282dfc6b5e859f2a0e446ff621d783b8a10b9d03406bab1a2a0932abbd`; the standard MiSTer upload and FTP readback are byte-identical. Exact MiSTer telemetry accepts both streams with every byte and picture, 71 and 23 swaps, zero errors and zero destination stalls. Long improves from 171,214,171 cycles at 22.393006 fps to 164,945,356 cycles at 23.244062 fps, removing 6,268,815 cycles or 3.66 percent and improving cadence 3.80 percent. Mixed improves from 61,408,518 cycles at 20.225207 fps to 59,871,287 cycles at 20.744501 fps, removing 1,537,231 cycles or 2.50 percent and improving cadence 2.57 percent.

#### Next Steps:

Retain the timing-clean hardware-proven B row pipeline and implement the corresponding logical two-bank P row producer/consumer boundary already justified by Entry 263. Preserve exact pixels, reference publication and bank ownership, and require a material complete-trace reduction before another clean Quartus build; after both row engines overlap, reprofile the remaining 11,585,356 long and 10,191,287 mixed cadence cycles required for stable 25 fps rather than assuming row pipelining alone closes the target.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- tools/streams/tb_h262_b_residual_streaming.sv

#### Status:

- [x] Built
- [x] Passed

---
## 265 COMMIT Unreleased 65ecd2e 2026-08-20T09:53:29-07:00

#### Coming From:

Unreleased 5a3c0e4

#### Purpose:

Overlap P-picture parsing and transform production for the following row with reconstruction and persistence of the current row through two logical metadata banks.

#### Outcome:

Commit `65ecd2e` gives the P producer and raster consumer two credit-counted row banks while retaining the existing 2,048-descriptor and 131,072-sample physical memories as two 1,024-descriptor logical halves. Independent capture and execution bank ownership preserves descriptor counts, motion ranges, row identity and final-picture retirement; the producer advances while one older row reconstructs and blocks only when both banks are occupied. The exact mixed oracle preserves all 423,936 samples with zero mismatches and maximum delta two, 69,556 reads, every write, nine publications, 23 swaps and zero errors while falling from 1,459,996 to 1,289,996 cycles, an 11.64 percent reduction. The exact long boundary preserves 372,696 reads, every write, 25 publications, 71 swaps and zero errors while falling from 7,469,996 to 6,999,996 cycles, a 6.29 percent reduction. Focused single-intra, 120-block residual, 8,100-block dense P row-streaming, eight-refill parser-window, final-row persistence and complete mixed publication regressions pass with exact sample, transform and ownership accounting. A fully clean seed-six Quartus 17.0.2 build completes in 10 minutes 29 seconds with zero errors and 145 standing warnings. Timing is positive at +0.117 ns global setup, +1.778 ns decoder setup, +7.885 ns video setup, +0.251 ns hold, +2.694 ns global recovery, +15.698 ns decoder recovery and +0.961 ns removal. The fit uses 30,927 ALMs, 45,708 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. `MediaPlayer_commit265_65ecd2e.rbf` is 4,305,820 bytes with SHA-256 `a2f127e6d80d9a01215364ed6328a091763929aa32dfc1e73c4e03014a64cd38`; the standard MiSTer upload and FTP readback are byte-identical. Hardware accepts both streams with every byte and picture, 71 and 23 swaps, zero errors and zero destination stalls. Long measures 164,932,359 cycles at 23.245893 fps, only 12,997 cycles faster than Entry 264, while decoder stalls fall by 9,845,014 and presentation stalls rise by 8,587,991 cycles. Mixed measures 59,868,266 cycles at 20.745548 fps, only 3,021 cycles faster, while decoder stalls fall by 3,184,646 and presentation stalls rise by 2,800,593 cycles. The P overlap is therefore functionally real and removes substantial internal work, but B-picture reconstruction and cadence-gated presentation remain on the end-to-end critical path.

#### Next Steps:

Retain the exact timing-safe P and B row pipelines and measure the complete-trace ceiling of a B-specific block pipeline that separates next-block prediction address production and reference fetch from current-block pixel reconstruction and persistence. Trace block fetch-ready and block-retire boundaries, model two bounded reference-block banks without changing production RTL, and proceed to functional implementation only if exact mixed and long replays predict a material cadence reduction toward the remaining 10,188,266 and 11,572,359 cycles required for stable 25 fps.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv
- tools/streams/tb_h262_row_streaming.sv

#### Status:

- [x] Built
- [x] Passed

---
## 266 COMMIT Unreleased c7b70cb 2026-08-20T09:55:41-07:00

#### Coming From:

Unreleased 65ecd2e

#### Purpose:

Measure the complete-trace performance ceiling of overlapping B-picture next-block reference fetch with current-block reconstruction before changing production decoder RTL.

#### Outcome:

Commit `c7b70cb` adds optional simulation-only B block START, FETCHED and RETIRE tracing to the exact live-raster harness plus a deterministic two-machine, two-bank replay. The model is deliberately optimistic: it treats full-footprint fetch completion as the instant the producer bank can begin the following block and assigns already-overlapped current-block work only to the consumer remainder. With tracing enabled, the mixed oracle remains exact at 1,289,996 cycles with all 423,936 pixels, 69,556 reads, every write, nine publications, 23 swaps and zero errors. Its 4,320 predicted B blocks span 592,054 serial cycles; the upper-bound replay takes 511,007, saving at most 81,047 cycles or 13.69 percent of the B block span and 6.28 percent of the whole trace. The long boundary remains exact at 6,999,996 cycles with 372,696 reads, every write, 25 publications, 71 swaps and zero errors. Its 13,536 predicted B blocks span 3,854,042 cycles; the upper-bound replay takes 3,441,302, saving at most 412,740 cycles or 10.71 percent of the B block span and 5.90 percent of the whole trace. Because even these cost-free upper bounds cannot close either stable-25-fps gap, a functional ping-pong block fetcher is rejected and no Quartus or hardware cycle is warranted.

#### Next Steps:

Retain the accepted Entry 265 hardware and the reusable block trace, but do not implement a second reference-block bank. Measure the larger B pixel-consumption ceiling next: use block direction and forward/backward half-pel parity to quantify one-lane tap work versus a bounded two-lane interpolation or dual-phase lookup path, and compare the exact whole-trace upper bound against both remaining hardware gaps before changing the timing-sensitive raster engine.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/analyze_b_block_pipeline_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 267 COMMIT Unreleased ed074f3 2026-08-20T10:04:41-07:00

#### Coming From:

Unreleased c7b70cb

#### Purpose:

Measure the complete-trace ceiling of replacing the B raster engine's single retained-word interpolation lookup with a bounded two-lane tap or dual-phase lookup path.

#### Outcome:

Commit `ed074f3` extends only the optional B block trace with already-latched forward and backward vector parity and calculates exact one-lane tap demand, ideal two-lane demand and impossible full-parallel one-cycle-per-pixel demand for every predicted block. The mixed oracle remains exact at 1,289,996 cycles with all 423,936 pixels, 69,556 reads, every write, nine publications, 23 swaps and zero errors. Its 894 forward, 2,592 backward and 834 bidirectional blocks require 391,808 serialized tap cycles; ideal two-lane consumption needs 306,048, saving at most 85,760 cycles or 6.65 percent of the whole trace, while full parallelism saves only 115,328 cycles or 8.94 percent. The long boundary remains exact at 6,999,996 cycles with 372,696 reads, every write, 25 publications, 71 swaps and zero errors. Its 1,878 forward, 3,594 backward and 8,064 bidirectional blocks require 2,304,000 serialized tap cycles; ideal two-lane consumption needs 1,395,200, saving at most 908,800 cycles or 12.98 percent of the whole trace, while full parallelism saves 1,437,696 cycles or 20.54 percent. Lookup width is therefore promising for long but insufficient for mixed; even adding Entry 266's independent cost-free block-fetch ceiling to impossible full tap parallelism reaches only 15.22 percent mixed versus the 17.02 percent hardware gap. A functional lookup-width change is rejected as the next standalone build, and no Quartus or hardware cycle is warranted.

#### Next Steps:

Retain the accepted Entry 265 hardware and both reusable B profilers without widening the timing-sensitive lookup path. Measure cross-run presentation decoupling next: the current scheduler already decodes one future P reference while presenting a closed two-B run, but then holds input until all scratch and future frames display even after a scratch bank becomes free; quantify a bounded next-run queue or scratch-bank reuse ceiling against the 47,362,881 long and 9,983,304 mixed hardware presentation-wait cycles before changing scheduler ownership.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/analyze_b_block_pipeline_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 268 COMMIT Unreleased 200f14b 2026-08-20T10:13:18-07:00

#### Coming From:

Unreleased ed074f3

#### Purpose:

Measure whether reusing each released scratch bank for the following B run can overlap enough decode with cadence-gated presentation to justify cross-run scheduler ownership.

#### Outcome:

Commit `200f14b` adds optional simulation-only picture START, READY and DISPLAY tracing plus a deterministic actual-25-fps decode/presentation replay that preserves traced decode order, temporal display order, reference dependencies and exactly two scratch banks. The observer handles the established one-cycle overlap between the next header and prior reference publication with independent start and completion ordering, and validates every traced display transition against temporal-reference order. Both default exact boundaries remain unchanged: mixed preserves all 423,936 pixels, 69,556 reads, every write, nine publications, 23 swaps and zero errors at 1,289,996 cycles; long preserves 372,696 reads, every write, 25 publications, 71 swaps and zero errors at 6,999,996 cycles. The replay scales each picture's traced work distribution to Entry 265's exact hardware I/P/B stall totals and additionally charges every accepted compressed byte as one decode cycle. With no added frame memory, a scratch bank becomes reusable only after display leaves it. Mixed carries 22,930,301 decode-work cycles, waits 25,763,616 cycles for bounded scratch ownership, and still sustains every due slot at exactly 49,680,000 cadence cycles or 25.000 fps, saving the full remaining 10,188,266 cycles. Long carries 62,046,857 decode-work cycles, waits 87,350,996 bounded ownership cycles, and sustains exactly 153,360,000 cadence cycles or 25.000 fps, saving the full remaining 11,572,359 cycles. Cross-run scratch reuse is therefore the first measured architecture that closes both targets without impossible arithmetic or additional DDR frame storage.

#### Next Steps:

Retain the accepted Entry 265 hardware and implement cross-run ownership as a separate proposal: after the overlap P reference publishes and display releases the prior run's first scratch bank, admit the following B header into that bank while the old run continues presenting, then use the reciprocal release for its second B picture. Preserve both runs' future-reference identity and temporal queues, reject any overwrite or early display in focused scheduler tests, and require exact mixed and long end-to-end reductions before Quartus.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/analyze_presentation_queue_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 269 COMMIT Unreleased f24e0f5 2026-08-20T10:25:00-07:00

#### Coming From:

Unreleased 200f14b

#### Purpose:

Permit the following two-B run to decode into scratch banks released by the currently presenting run without exposing, overwriting, or misbinding either run's frames.

#### Outcome:

Commit `f24e0f5` separates the currently presenting B run from one queued decode generation while retaining exactly two physical scratch banks. A released scratch bank can accept the following run's first B picture, the reciprocal release can accept its second, and ownership promotes atomically only after the old future reference displays; the focused regression covers two adjacent runs, explicit generation identities, a queued B completion coincident with delayed promotion, ordered scratch-zero/scratch-one/future display, and every prior race, cadence and fail-open case. The exact mixed oracle remains 1,289,996 cycles with all 423,936 pixels, maximum delta two, 69,556 reads, every write, nine publications, 23 swaps and zero errors; the complete long oracle remains 6,999,996 cycles with 372,696 reads, every write, 25 publications, 71 swaps and zero errors. A cadence-stressed mixed run performs seven queued admissions and seven promotions with identical pixels and accounting; it exposed and then locked a critical rule that presentation hold must not starve an already admitted queued B decode. The clean seed-six Quartus 17.0.2 build completes in 10 minutes 31 seconds with zero errors and 145 standing warnings. Timing is positive at +0.524 ns global setup, +1.771 ns decoder setup, +8.356 ns video setup, +0.246 ns hold, +4.360 ns global recovery, +14.753 ns decoder recovery and +0.611 ns removal; utilization is 31,255 ALMs, 45,603 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. `MediaPlayer_commit269_f24e0f5.rbf` is 4,312,872 bytes with SHA-256 `f6cba79842bb41a0b574c2d815efc78d4f878a78efacc84946585f7a8beeb461`, and its standard MiSTer upload is byte-identical on readback. Hardware is functionally clean with every byte and picture, all 71 and 23 swaps, and zero errors. Mixed improves from 59,868,266 cycles at 20.745548 fps to 57,180,519 cycles at 21.720684 fps, saving 2,687,747 cycles or 4.49 percent. Long remains effectively flat at 164,947,334 cycles and 23.243783 fps: presentation wait falls from 47,362,881 to 35,406,540 cycles, but destination ownership rises from zero to 10,805,922 cycles. Entry 268's no-extra-frame model therefore omitted the two-reference-bank destination dependency; scratch reuse is real and retained, but it does not close 25 fps by itself.

#### Next Steps:

Retain the timing-clean cross-run scratch scheduler and measure the smallest destination-safe P predecode boundary before changing frame storage. The next ceiling must account for all four occupied full-frame buffers during a queued two-B run: visible past reference, future prediction reference and two B scratch frames. Quantify how much of the newly exposed 10,805,922-cycle long destination wait can be hidden by allowing the P parser and two-bank row producer to fill bounded metadata rows while persistence remains blocked until display releases the destination reference bank; compare that against a true fifth-frame destination only if bounded predecode cannot close both hardware gaps.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv

#### Status:

- [x] Built
- [x] Passed

---
