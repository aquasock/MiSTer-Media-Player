---
## 258 COMMIT Unreleased 1138b7a 2026-08-20T06:31:37-07:00

#### Coming From:

Unreleased f6e3877

#### Purpose:

Use the accepted 21.82/19.85 fps hardware boundary to determine whether modestly deeper block-fetch, cache, and DDR read-command capacity can hide enough remaining response latency to justify another production change.

#### Outcome:

Proposal only. Entry 257 is visually hardware accepted: both long-GOP and mixed-macroblock streams retain their established passing LED signatures, the user sees a noticeable improvement from discrete stuttering frames to a slow but continuous movie, and the MiSTer is released for continued development. Hardware telemetry shows that the accepted depth-two path leaves 27,754,704 prediction-response cycles in long and 8,925,420 in mixed, while stable 25 fps still requires reductions of 22,331,819 and 12,883,846 cadence cycles respectively. Because the mixed gap exceeds its entire recorded prediction-response wait, deeper queueing alone is not assumed sufficient; it must first prove its exact contribution before the next compute-stage optimization is selected.

Commit `1138b7a` makes the shared descriptor depth a guarded compile-time constant across the block-footprint fetcher, reference cache and DDR arbiter while retaining production depth two by default. Pointer widths, count widths and non-power-of-two wrap are derived from the selected depth, and the focused tests now fill and drain the configured capacity rather than assuming two. Depths two, three and four each pass exact address and response order, delayed service, deterministic backpressure, display-over-prediction priority, multiword display ownership, same-cycle full-queue retire-and-replace, zero-latency direct response and writer exclusion. The focused 88-word block footprint completes at simulation times 5.64, 4.56 and 4.03 million respectively, providing an initial reason to run the complete boundaries without yet changing production capacity.

The complete traces reject a production depth increase. The 423,936-pixel mixed boundary remains exact at every depth with zero mismatches and maximum channel delta two: at one-cycle service depth two takes 1,969,996 cycles and depths three/four both take 1,959,996, only 10,000 cycles or 0.51% saved; at ten-cycle service the corresponding results are 2,069,996 and 2,039,996, only 1.45% saved. The 69-picture long decode likewise preserves 372,696 reads, 25 publications, 71 swaps, all reference/scratch writes and zero errors: at one-cycle service depth two takes 10,719,996 cycles and depths three/four both take 10,659,996, only 60,000 cycles or 0.56% saved. Even with the artificial ten-cycle delay, depth two takes 11,619,996 cycles, depth three 11,199,996 and depth four 11,069,996. The descriptor-capacity hypothesis is therefore measured and rejected for production; default depth two remains unchanged, and no Quartus or hardware cycle is warranted for this infrastructure-only commit.

#### Next Steps:

Retain production depth two. Use the exact occupancy profile to attack the registered per-pixel lookup/emit sequence next: the mixed trace spends 617,354 state-cycles in prediction lookup and exactly 423,936 state-cycles emitting pixels, while the long trace spends 2,999,376 lookup and 1,271,808 emit cycles. Determine whether the first lookup for the following pixel can be issued while the current pixel is emitted, preserving registered timing and exact output, before committing another production optimization.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- tools/streams/tb_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_ddram_arbiter.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 257 COMMIT Unreleased f6e3877 2026-08-20T06:14:25-07:00

#### Coming From:

Unreleased cc23163

#### Purpose:

Remove the remaining zero-latency response-capacity feedback loop while preserving full-cache same-edge retirement and replacement, then obtain a reproducibly timing-qualified placement without changing decoder RTL.

#### Outcome:

Commit `cc23163` removed request-valid from cache and arbiter busy equations, but its clean Quartus elaboration found a different ten-node loop: cache command valid used downstream response-ready to decide that a full descriptor FIFO would pop, while legal direct-response routing used that command valid to select response ownership. The build was interrupted before fitting completed and no RBF was produced or deployed. Commit `1d4329d` instead lets a full cache accept a replacement only when the arbiter's request-independent prediction readiness proves that its corresponding head command is retiring; response-ready now feeds only clocked pop and data association. The strengthened downstream model genuinely fills at two and reopens only on retirement. Focused cache and arbiter tests pass idle readiness, depth two, full-queue same-edge replacement, direct response, backpressure, burst ownership and prediction/display/prediction order. The exact mixed ten-cycle boundary remains all 423,936 samples, zero mismatches, 69,556 reads and 2,069,996 cycles, preserving the full Entry 255 gain with no response-routing feedback in command valid. A fully clean seed-2 Quartus build then completed with zero errors and no reported combinational loop; decoder and ordinary video timing are clean at +1.167 and +6.670 ns, but the dynamic HDMI scaler/OSD clock misses global setup by 0.179 ns across standing framework paths, so that RBF is rejected and was not deployed. Commit `0d4f679` changes only the reproducible fitter seed from two to five, leaving every decoder source and simulation result unchanged. Its fully clean build improves the standing HDMI scaler/OSD miss to 0.048 ns and improves decoder setup to +1.463 ns, but still fails the positive-global gate and is also rejected without deployment. Commit `f6e3877` changes only the fitter seed from five to six. Its fully clean Quartus 17.0.2 build completes in 10 minutes 34 seconds with zero errors, 143 standing warnings, no Critical Warning and no reported combinational loop. Timing is positive at +0.321 ns global setup, +1.139 ns decoder setup, +7.127 ns video setup, +0.247 ns hold, +3.622 ns global recovery, +13.605 ns decoder recovery and +0.695 ns removal. The fit uses 31,802 ALMs, 47,567 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit257_f6e3877_seed6.rbf` is 4,282,980 bytes with SHA-256 `c32a0c363458e5a9036c75b25f17bdff3e535682bc26f08e0981ac81b2c00d0c`; the standard MiSTer FTP readback is byte-identical. Automated MiSTer acquisition accepts both streams with every expected picture, zero error flags and zero destination stalls. Long displays 72 pictures through 71 swaps in 175,691,819 cycles or 3.253552 seconds at 21.822302 fps, improving 24.96 percent over Entry 247's 17.463119 fps and reducing cadence cycles by 19.98 percent. Mixed displays 24 pictures through 23 swaps in 62,563,846 cycles or 1.158590 seconds at 19.851721 fps, improving 32.49 percent over Entry 247's 14.983129 fps and reducing cadence cycles by 24.52 percent. Both gains are substantial hardware confirmation of the two-request path, although neither test has yet reached the requested stable 25 fps.

Visual hardware acceptance also passes: the user reports that both streams retain exactly their prior passing LED signatures, the gain is noticeable, and playback now resembles a slow movie rather than a series of stuttering frames.

#### Next Steps:

Continue under Entry 258 from the accepted 21.82/19.85 fps boundary, preserving the exact timing-qualified seed-6 image as the rollback point.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---
## 256 COMMIT Unreleased cc23163 2026-08-20T05:19:52-07:00

#### Coming From:

Unreleased 0f5baad

#### Purpose:

Remove the synthesis-discovered cache-to-arbiter combinational handshake loop without reducing Entry 255's two-command capacity or changing response order.

#### Outcome:

The first Entry 255 clean Quartus elaboration reported a six-node combinational loop from the reference probe request through prediction busy and back to that request; the build was interrupted before fitting completed and no RBF was produced or deployed. Commit `cc23163` makes cache readiness depend only on active transaction, descriptor capacity, hit state and downstream backpressure, while reader and prediction arbiter readiness depend only on descriptor capacity, display priority and DDR backpressure. Acceptance remains separately request-qualified, so valid no longer feeds its own ready and no latency stage is added. Focused cache and arbiter tests explicitly require idle readiness and still pass depth two, prediction/display/prediction ordering, command backpressure, burst ownership, same-edge replacement and direct response. The exact mixed ten-cycle boundary remains 423,936 samples, zero mismatches, maximum delta two, 69,556 reads and 2,069,996 cycles; the complete long ten-cycle boundary remains 22 P and 47 B pictures, 71 swaps, 372,696 reads, 11,619,996 cycles and zero errors. The correction therefore preserves all Entry 255 behavior and gain while removing the source-level ready/valid dependency.

#### Next Steps:

Restart a fully clean Quartus build from `cc23163`, require the synthesis report to contain zero combinational-loop logic and require positive global and decoder timing. If qualified, hash and deploy the RBF, run automated mixed and long hardware cadence acquisition, compare against Entry 247, and then pause with an alert for the user's own visual inspection before any further optimization.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_ddram_arbiter.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 255 COMMIT Unreleased 0f5baad 2026-08-20T04:40:42-07:00

#### Coming From:

Unreleased 5b37c1f

#### Purpose:

Permit two ordered prediction reads to remain outstanding through the shared cache and DDR arbiter without weakening display priority or response ownership.

#### Outcome:

Commit `0f5baad` extends only the intervening cache and shared DDR boundary to two ordered read descriptors while retaining display priority, burst ownership and writer-region exclusion. Focused RTL proves back-to-back misses, command backpressure, prediction/display/prediction response order, a three-word display burst, full-queue response/accept reuse and legal direct response. The exact mixed boundary passes all 423,936 samples with zero mismatches, maximum delta two, 23 swaps and zero errors at 1,969,996 one-cycle and 2,069,996 ten-cycle cycles. The complete long boundary passes all 22 P and 47 B pictures, 71 swaps and zero errors at 10,719,996 and 11,619,996 cycles. Against Entry 254's identical ten-cycle runs, 2,379,996 mixed and 13,449,996 long, this is a 13.03 and 13.61 percent reduction; the 82,806-row mixed request trace also balances exactly. Potential hits behind an older response intentionally become ordered misses, changing physical reads only from 69,528 to 69,556 mixed and 372,648 to 372,696 long. No pixel, response-association, ownership, burst or shutdown regression remains.

#### Next Steps:

Run a clean Quartus build from `0f5baad`, require timing closure, deploy the resulting RBF and capture the same hardware cadence/stall telemetry. If hardware confirms the simulated overlap, retain this boundary and use the remaining mixed-stream gap to choose the next bounded concurrency step; HDMI recordings remain final visual verification after measured cadence reaches 25 FPS.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_ddram_arbiter.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 254 COMMIT Unreleased 5b37c1f 2026-08-20T04:16:09-07:00

#### Coming From:

Unreleased 5f1d561

#### Purpose:

Replace serialized per-tap B-picture prediction with one- or two-phase direct-index block footprints while retaining the current cache and arbiter contract.

#### Outcome:

Commit `5b37c1f` gives B reconstruction the same latched direct-buffer lifecycle as P while retaining the one-outstanding cache and arbiter. Forward-only and backward-only blocks map their sole reference rectangle to phase zero; bidirectional blocks map forward to phase zero and backward to phase one, and synchronous retries preserve phase, tap, byte selection, interpolation and rounding until each retained word is valid. The exact mixed boundary passes all 423,936 samples with zero mismatches, maximum delta two, 23 swaps, zero errors, 69,528 DDR reads and 1,999,996 cycles. The complete long boundary passes all 22 P and 47 B pictures, 71 swaps, zero errors, 372,648 reads and 11,069,996 cycles. Relative to Entry 247 this removes 1,801 mixed and 91,187 long physical reads and reduces cycles by 12.28 and 12.77 percent before hiding response latency. Focused B residual cold and hit modes converge at 1,392,289 cycles while both pass 1,350 motion records, 120 residual blocks, 7,680 residual samples and all 518,400 stores; the authored B-intra case passes 12 blocks, 768 samples and the exact 768 changed stripe samples at 785,956 cycles. No stale phase, response reassociation, arithmetic, scratch-write or presentation regression remains.

#### Next Steps:

Expand the shared cache and DDR arbiter to accept the fetchers' already-proven depth-two ordered request stream. Track prediction and display response ownership explicitly in command order, permit a response to free a descriptor while the next command is accepted, retain display priority and writer exclusion, and require the standalone simultaneous-response test, exact mixed pixels, complete long order and a substantial ten-cycle reduction before any Quartus build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_b_residual_streaming.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 253 COMMIT Unreleased 5f1d561 2026-08-20T03:51:26-07:00

#### Coming From:

Unreleased c9e5a90

#### Purpose:

Replace serialized per-tap P-picture prediction with the proven direct-index block fetcher while retaining the current cache and arbiter contract.

#### Outcome:

Commit `5f1d561` integrates the block fetcher only into generalized P reconstruction while retaining the shared cache and one-outstanding arbiter. P block geometry is latched before address generation, every tap uses synchronous direct phase/row/column lookup, invalid early lookups retry without consuming stale data, and intra arithmetic, residual look-ahead, writer barriers and presentation ownership remain unchanged. The exact mixed boundary passes 423,936 samples with zero mismatches, maximum delta two, 23 swaps, zero errors, 71,317 DDR reads and 2,189,996 cycles, improving 90,000 cycles or 3.95 percent from Entry 247 before multi-outstanding service. The complete long boundary passes 71 swaps, all 22 P and 47 B pictures, zero errors, 463,831 reads and 12,269,996 cycles, improving 420,000 cycles or 3.31 percent. Both focused 720x480 P/intra modes pass 1,350 ordered motion records, the authored intra macroblock, six blocks and 384 exact samples at 787,530 cycles, and the standalone fetcher still passes delayed, backpressured, simultaneous and zero-latency response association. The first live attempt exposed that fetch width was not latched and stopped at a deterministic missing final word; latching every rectangle parameter eliminated the stall and all final regressions pass.

#### Next Steps:

Apply the same latched one- or two-rectangle direct-buffer contract to B reconstruction while keeping the one-outstanding cache and arbiter unchanged. Map forward-only and backward-only blocks to phase zero, bidirectional forward and backward references to phases zero and one, preserve rounding and phase order exactly, and require residual-focused B regressions plus exact mixed pixels and complete long ordering before expanding shared DDR concurrency.

#### Files Modified:

- files.qip
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 252 COMMIT Unreleased c9e5a90 2026-08-20T03:46:05-07:00

#### Coming From:

Unreleased 6218ff5

#### Purpose:

Prove a direct-index block-footprint fetcher that retains at most thirty-six prediction words while issuing two ordered DDR reads.

#### Outcome:

Commit `c9e5a90` adds an uninstantiated standalone block-footprint fetcher and focused regression, so the production Entry 247 netlist remains unaffected. The committed analyzer now rejects any non-rectangular trace footprint and proves exact mixed counts of 54 intra, 5,736 single-reference and 834 dual-reference blocks plus exact long counts of 132 intra, 11,676 single-reference and 8,064 dual-reference blocks; every reference phase is a complete rectangle no wider than two words or taller than nine rows. The fetcher assigns eighteen direct slots per phase, generates each rectangle word once, permits two ordered reads, stores responses through an explicit two-entry slot descriptor FIFO and returns retained data through synchronous phase/row/column lookup. Its regression passes four transactions, six phases and 88 exact words across both width and height limits, delayed service, deterministic command backpressure, simultaneous response and next acceptance, same-cycle acceptance and response, maximum outstanding depth two, direct lookup and invalid phase-count rejection without address loss, duplication or response reassociation.

#### Next Steps:

Integrate the proven fetcher behind the P/B wrapper in a simulation-first boundary. Derive each phase's top-left word, one- or two-word width and eight- or nine-row height from the already registered block motion state, route its two ordered requests through an expanded response-owner queue, and replace per-tap cache waits with direct buffered slot lookup while leaving intra blocks, pel arithmetic, residual timing, writer ownership, display priority and presentation unchanged. Require exact mixed pixels and long order before any Quartus build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_prediction_block_fetcher.sv
- tools/streams/analyze_prediction_queue_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---
## 251 COMMIT Unreleased 6218ff5 2026-08-20T03:16:07-07:00

#### Coming From:

Unreleased 0c8d2c4

#### Purpose:

Measure the full-trace performance ceiling of block-scoped prediction address, ordered request and returned-word queues before changing production RTL.

#### Outcome:

Commit `6218ff5` adds optional exact prediction tracing and a deterministic block-scoped queue replay without changing production RTL. The mixed trace self-audits 499,551 hits, 71,329 misses, 6,624 block starts and ends, 423,936 exact pixels, zero errors and the unchanged 2,279,996-cycle default result; its exact ten-cycle serialized baseline is 2,919,996 cycles. A depth-two ordered queue with a retained block-word buffer predicts 2,332,586 cycles, a 20.12 percent reduction and hardware-scaled 18.756 fps, while depths four through sixteen improve by only thirty more cycles; the absolute prediction-memory ceiling is 19.189 fps. The long trace self-audits 2,267,813 hits, 463,835 misses, 19,872 blocks, 71 swaps, zero errors and the unchanged 12,689,996-cycle default result; its exact ten-cycle baseline is 16,869,996 cycles. Depth two predicts 12,848,592 cycles, a 23.84 percent reduction and hardware-scaled 22.929 fps, with an absolute ceiling of 23.215 fps. Mixed blocks require at most 34 distinct words and long blocks at most 36, while depths above two are ineffective because block-start address production supplies enough lead. The queue is therefore a material next step but cannot reach 25 fps without later non-memory overlap.

#### Next Steps:

Proceed with a functional block-footprint fetcher that generates the current P or B block's bounded reference-word rectangle ahead of pixel consumption, retains up to thirty-six tagged words for that block, and permits two ordered DDR requests with explicit response-slot ownership. Preserve the global cache, display-reader priority, decoded arithmetic and write/presentation contracts; require exact mixed pixels, long ordering, unchanged transaction identity, positive clean timing and a substantial hardware cadence gain before accepting it. After this memory stage, profile the remaining mixed compute and transform occupancy because even perfect prediction-memory removal cannot independently reach 25 fps.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/analyze_prediction_queue_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---
## 250 COMMIT Unreleased 0c8d2c4 2026-08-20T02:22:32-07:00

#### Coming From:

Unreleased 25d7b50

#### Purpose:

Measure whether one exact following prediction address can hide enough ordered DDR response latency to justify a depth-two hardware path.

#### Outcome:

Commit `0c8d2c4` adds simulation-only ordered-read and variable-latency models without changing production RTL. The focused ten-cycle service completes 64 reads in 641 cycles with one outstanding, 322 with depth two, 346 under deterministic backpressure and 64 with zero latency while preserving prediction/display/prediction owner order. A temporary depth-two decoder candidate remained exact across 423,936 mixed samples with zero mismatches and maximum delta two, but at ten-cycle latency it reduced the safe Entry 247 trace only from 2,919,996 to 2,819,996 cycles because just 8,072 of 71,329 physical reads had an immediately usable exact successor. The 100,000-cycle or 3.42 percent whole-stream reduction would move the measured 14.983 mixed rate only to roughly 15.5 fps, far short of 25 fps, so the candidate was rejected and fully removed before Quartus or MiSTer deployment. The committed default-latency regression remains unchanged at 2,279,996 cycles, 499,551 cache hits, 71,329 misses, 23 swaps, zero errors and exact pixels; the ten-cycle baseline also passes at 2,919,996 cycles.

#### Next Steps:

Retain the timing-qualified Entry 247 production RTL and obtain approval for a materially deeper prediction architecture. The next proposal should decouple block-scoped address production from pixel consumption, queue enough ordered requests and returned words to cover the measured memory latency rather than only one successor, preserve display priority and explicit response ownership, and prove the attainable full-trace ceiling in simulation before functional RTL, Quartus or MiSTer deployment.

#### Files Modified:

- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 249 COMMIT Unreleased 25d7b50 2026-08-20T02:20:30-07:00

#### Coming From:

Unreleased d9231a7

#### Purpose:

Recover prediction conflict misses through a second-stage victim cache without lengthening the accepted four-entry fast-hit path.

#### Outcome:

Commit `25d7b50` adds a simulation-only exclusive-cache model with the accepted four-entry fully associative primary and four victim entries per reference bank. It models deterministic promotion, primary eviction, victim replacement, active invalidation and the extra probe cycle without feeding live RTL. The exact mixed oracle remains fully passing at 423,936 samples, zero mismatches, maximum delta two, 499,551/71,329/0 physical cache accounting, 23 swaps and 2,279,996 cycles. Across 561,243 lookups, the model produces 490,752 primary hits, only 863 victim hits and 69,628 full misses, so the second stage probes 70,491 times to avoid only 863 DDR transactions. Charging one cycle per primary miss costs about 70,000 cycles while even an optimistic ten-cycle hardware response credit saves fewer than 9,000 cycles. The victim design is therefore a clear mixed-stream slowdown and is rejected before functional RTL, long simulation or Quartus build.

#### Next Steps:

Retain the timing-qualified Entry 247 cache and scheduler. Continue with Entry 250's proposal-first depth-two ordered request experiment, using the MiSTer interface's explicit pipelined-read contract to hide latency rather than trying to reduce a locality stream that three independent models show is not cache-capacity limited.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 248 COMMIT Unreleased d9231a7 2026-08-20T02:13:42-07:00

#### Coming From:

Unreleased 66e769f

#### Purpose:

Reduce the remaining serialized prediction-memory wait with a bank- and row-partitioned cache that retains a four-way timed lookup cone.

#### Outcome:

Commit `d9231a7` adds simulation-only mirrors of two four-comparison partition candidates without changing cache or decoder RTL. The exact mixed regression remains at 423,936 samples, zero mismatches, maximum delta two, 499,551/71,329/0 physical cache accounting, 23 swaps and 2,279,996 cycles. Across 561,243 registered lookups, the existing cache produces 68,869 observed lookup misses. Two four-way sets selected only by reference bank produce 69,499 modeled misses, 630 worse than baseline; four four-way sets selected by reference bank and address bit one produce 69,484 misses, 615 worse than baseline. Static bank and row distribution therefore fragment useful capacity instead of resolving conflict pressure. The hard negative mixed result rejects functional RTL before a long simulation or Quartus build; the timing-qualified Entry 247 core remains deployed and unchanged.

#### Next Steps:

Retain the existing four-entry primary cache and the negative partition evidence. Continue with Entry 249's proposal-first second-stage victim model, which can exploit additional capacity without adding comparisons to the fast primary hit cone.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 287 COMMIT Unreleased 73dada5 2026-08-21T00:18:53-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Establish why the P picture never publishes, which Entry 286 identified as the single unexplained fact blocking every candidate repair.

#### Outcome:

No source changed. The answer relocates the defect out of the presentation scheduler entirely, which invalidates the layer all four previous repair attempts targeted. Two hypotheses were tested and rejected before the real cause was found. The publication gate at `mpeg2_h262_two_picture_probe_p_chain.sv`, which refuses to publish while `b_picture_inflight` is high, looked like an exact match for a circular wait, but a tracer on that condition never fired once, so the picture never even reaches `base_picture_420_complete`. The stream-boundary hypothesis was also excluded by measuring byte geometry: the sixth P occupies bytes 41,185 to 60,815 and the transport stalls at 60,822, which is seven bytes into the following B picture header, so the start code that terminates the P's final slice had already been delivered and the picture was not starved of its own data.

The measured cause is that the P reconstruction path never engages for that picture at all. Tracing the probe's parser handshake shows `p_hold_effective` toggling continuously for roughly 734,000 cycles while the fifth P reconstructs, which is the backpressure that normally throttles the transport across a P picture, and shows it never asserting even once while the sixth P is consumed. The last assertion anywhere in the run occurs during the fifth P. With no backpressure the sixth P's 19,630 bytes are accepted at one byte per cycle in 19,630 cycles, and the picture-row counter confirms the consequence: it stands at exactly 150 rows for five completed pictures of thirty rows each, so the sixth P reconstructed nothing. A picture that reconstructs nothing never completes, never publishes, and never sets `pending_frame_valid`, which is precisely the condition the queued-admission branch fail-stops on.

The scheduler error recorded in Entries 284 through 286 is therefore a downstream symptom rather than the defect. This also explains why every repair failed on its own terms: deferring the run close addressed a branch never reached, holding from `overlap_decode_open` starved a P that genuinely needed its data, and deferring the queued admission with a hold at the B header livelocked because it waited on a publication that could never arrive no matter how long the wait. None of those repairs could have worked, because the picture they were all waiting for was never being decoded. The distinguishing property of that picture remains its size, 19,630 bytes against 1,157 to 3,104 for every other P in the clip and 3,388 to 4,830 across the corpus, but size alone is a correlation and the mechanism inside the controller is not yet identified. `p_hold_raw` originates in `mpeg2_h262_p_diagnostic_controller`, and its `p_picture_expected` input was checked and excluded: that signal is a sticky latch in `mpeg2_h262_picture_bookkeeper.sv` set on the first transition out of phase-1 support and never cleared, so it is high throughout.

#### Next Steps:

Trace inside `mpeg2_h262_p_diagnostic_controller` to find why it does not assert `stream_hold` for this picture, comparing its internal state directly against the fifth P where the same signal toggles normally. Its `p_picture_expected`, `p_persistence_complete` and `p_row_persistence_complete` inputs are the obvious first candidates, followed by whatever internal decision state governs `p_controls_seen` and `decision_complete` in the residual parser, since those gate the equivalent conditions there. Treat the presentation scheduler as correct until that trace shows otherwise, and do not attempt a fifth repair in that module. The three reverted scheduler experiments should not be revived even though two of them passed the corpus and the focused regression, because passing tests while fixing nothing is exactly how the first four attempts consumed a full development cycle. Retain the separately identified gap that no corpus stream exercises the queued admission path at all, both corpus streams reporting `queued=0 promoted=0`, and close it with a synthetic cross-run stream once the decode defect is understood. This remains the v0.6.0 blocker ahead of the 25 fps scratch-pool work.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 286 COMMIT Unreleased 73dada5 2026-08-20T23:47:12-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Trace the freeze at picture level before attempting a fifth repair, after three scheduler repairs were disproven.

#### Outcome:

No source changed. A simulation-only state tracer and the testbench's picture trace were run against the Big Buck Bunny clip on the committed baseline, and they explain the failure and the three failed repairs together. The decisive discovery is that the queued-run admission path added by Entry 269, which is where the failure occurs, has no coverage whatsoever in the regression corpus: both the long-GOP and the soak streams report `queued=0 promoted=0`, so that branch has never executed in any accepted regression. Real content is the first stream to reach it, which is why a defect there survived every prior commit.

The picture trace shows why the corpus never reaches it. In the accepted pattern the presentation run completes before the following B header arrives: at cycle 10,540,001 `presentation_complete` asserts and `reorder_active` falls, the P publishes 743,000 cycles later, `pending_frame_valid` rises, and only then does the B header appear, so the B is admitted through the ordinary fresh-run path and the queued path is bypassed entirely. In the failing sequence the run is still active when the B header arrives. The P header is accepted at cycle 13,042,608, the run closes with `overlap_decode_open` set one cycle later, the swap window at 13,050,001 leaves the run still open, and the B header arrives at 13,062,238 with `reorder_active` and `run_closed` both high. That reaches the queued-admission branch with `pending_frame_valid` low, and it fail-stops. Nothing throttles the early header because the existing `presentation_hold` expression contains `!overlap_decode_open`, and the trace confirms `presentation_hold` is low across the whole window while `queued_header_capacity` is already low.

The interval between that P header and the following B header is 19,630 cycles, which is exactly the byte length of that P picture, so the transport ran unthrottled for its entire payload. That P is the largest in the clip at 19,630 bytes against 1,157 to 3,104 bytes for every other P, while the corpus soak's P pictures are a uniform 3,388 to 4,830 bytes. Whatever the precise coupling, the distinguishing property is a P whose payload profile differs sharply from the synthetic corpus, and the earlier assumption that the trigger was simply high bidirectional density is too coarse to be the mechanism.

Three repairs were attempted, disproven and reverted before this entry, and each constrains the next. Deferring the run-closing branch left the corpus byte-identical but did not touch the failure, because instrumentation proved that branch is never reached. Holding the transport from `overlap_decode_open` was rejected immediately by the focused regression with "following P was not admitted during prior presentation", because that signal denotes a P that has just been admitted and still requires its own slice data. Deferring the queued admission and holding from the B header instead passed the focused regression with every case intact and kept the corpus at exactly 6,589,996 cycles, and it carried the Big Buck Bunny clip past the failing byte for the first time, but it then livelocked: the run completed with the admission still latched, so the retry condition could never fire, the latch never cleared and the transport stalled permanently with `presentation_hold` high. In that livelock the P never published even though its payload had been fully consumed, which is the single fact still unexplained and the reason no fourth repair is proposed here.

#### Next Steps:

Establish why that P fails to publish once the transport is held, because every remaining repair depends on the answer. If publication is reachable and merely slow, the deferred admission needs only a release path for the case where the run completes first, since the ordinary fresh-run admission is then the correct destination for the latched header. If publication genuinely requires further transport activity, then holding is unusable at any point in this window and the admission must instead be made to succeed against an unpublished reference by deferring the reference binding the way Entry 227 already does for the non-queued path. Instrument the picture-completion and writer-drain path for that specific P under a held transport to distinguish the two, rather than attempting another repair first. Separately, and independently of the fix, the absence of any corpus coverage for the queued admission path is itself a defect worth closing, because a regression suite that never executes a branch cannot protect it; a synthetic stream that forces cross-run admission would have caught this before real content did. Keep this ahead of the 25 fps scratch-pool work as the v0.6.0 blocker.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 285 COMMIT Unreleased 73dada5 2026-08-20T22:39:09-07:00

#### Coming From:

Unreleased ddcc8f3

#### Purpose:

Make a late reference publication a condition the publication probe waits for rather than fail-stops on, and locate precisely why the scheduler still fail-stops afterwards.

#### Outcome:

Only the probe layer is delivered. In `mpeg2_h262_two_picture_probe_p_chain.sv` the header-time comparison of `p_publication_count` against `p_header_count` no longer raises `publication_error`. It latches that the in-flight B transaction is waiting for its future reference, clears that state when the publication arrives, and raises the error with detail one only if the B reaches `b_persisted_now` while still waiting. This preserves the real invariant, that a B must not complete against an unpublished reference, while permitting the deferred binding Entry 227 introduced, and it matters beyond diagnostics because `b_user_success` is gated by `b_accept_error`, so a latched error permanently suppresses the completion edge the scheduler waits on. The complete corpus soak is byte-identical at 6,589,996 cycles with 22/22/47/47 publications and zero errors, and the focused scheduler regression is unchanged at cadence one, three, two with a minimum present gap of two.

The scheduler layer proposed in the previous revision of this entry was implemented, disproven and reverted, and the reasons are recorded because they constrain the correct fix. A first attempt deferred the run-closing branch when `future_reference_pending` was set, holding the transport until the publication bound. It left the corpus byte-identical but did not change the Big Buck Bunny failure at all, because instrumenting every `presentation_error` site proved that branch is never reached by this stream. That instrumentation initially misreported its site, because a blanket textual insertion of the deferred-state clear had been applied into a brace-less `else`, which made both the clear and the diagnostic unconditional; the file was reverted and the edit redone against a single audited site.

Correct instrumentation then identified the true failure exactly. It is the queued-run admission path added by Entry 269, at the branch guarded by `promotion_pending`, `pending_frame_valid` and `queued_scratch_available`, with the deciding state `pending_frame_valid=0`, `overlap_decode_open=1`, `queued_scratch_available=1`, `queued_header_capacity=0` and `presentation_hold=0`. Entry 247's overlap deliberately releases the presentation hold so one P may decode during presentation, and the existing hold expression contains `!overlap_decode_open`. When that overlapping P has not yet published, `queued_header_capacity` is low, so the next B header reaches an admission path that cannot succeed and fail-stops on a condition that is merely late. A second attempt therefore held the transport across that window. The focused scheduler regression rejected it immediately with "following P was not admitted during prior presentation", which is correct: `overlap_decode_open` denotes a P that has just been admitted and still requires its own slice data, so holding input starves it and it can never publish. The deadlock-safety argument that holds for the run-closing branch does not hold here, and the regression caught the difference. Both attempts were reverted; the committed source contains the probe change only, so the freeze is not yet fixed.

#### Next Steps:

Defer the queued admission rather than holding the transport, because holding is now proven to starve the very publication being waited for. Latch the B admission request when the queued path would fail only for the transient reasons `promotion_pending` or absent `pending_frame_valid`, leave the transport running so the overlapping P can finish parsing and publish, and complete the admission when `pending_frame_valid` or `frame_waiting` asserts. Keep `!queued_scratch_available` as a genuine fail-stop unless evidence shows it is also transient, since the Entry 282 measurement shows scratch exhaustion is a real resource limit rather than a timing artifact. The retry must not lose the B's coding-type event or its scratch-bank selection, and it must be proven against the focused regression's overlap, starvation, generation and fail-open cases before any full soak. Require the corpus soak to stay at exactly 6,589,996 cycles with zero errors and the 30-picture Big Buck Bunny clip to complete, then take a clean build and a paired hardware comparison. Treat this as the v0.6.0 blocker and keep the 25 fps scratch-pool work behind it.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 284 COMMIT Unreleased ddcc8f3 2026-08-20T21:38:55-07:00

#### Coming From:

Unreleased b9c2ddb

#### Purpose:

Determine whether the publication ordering rule that freezes real content is a correct invariant or an over-strict diagnostic, before changing any decoder logic.

#### Outcome:

It is both, and neither fix alone is sufficient. The question posed by Entry 283 is answered against the source: `mpeg2_h262_b_presentation_scheduler.sv` was given deferred future-reference binding by Entry 227, which explicitly accepts a B header arriving before its future reference publishes and binds that publication into the already open transaction when it later arrives. `mpeg2_h262_two_picture_probe_p_chain.sv` predates that capability and still fails at B header time whenever `p_publication_count` is below `p_header_count`. The two are in direct contradiction, and `MediaPlayer_top_05.svh` sides with the scheduler because its ownership hold arms only for a P successor, while the probe's own `p_hold_effective` is deliberately released as soon as a B candidate appears. Synthetic content never exposed the disagreement because its P pictures always publish before the following B header is parsed.

A simulation-only lenient probe, which counts the late-publication case instead of failing on it, isolates the two layers. The corpus control is unaffected: the complete soak replay is byte-identical at 6,589,996 cycles with 22/22/47/47 publications and zero errors, so relaxing that check does not perturb any accepted behaviour. The Big Buck Bunny clip, however, then fails one byte later at 60,823 instead of 60,822, this time with `presentation_error` from the scheduler rather than `probe_error`. The probe was therefore masking a deeper defect rather than causing the freeze by itself.

The scheduler defect is at the run-closing branch. When a non-B header arrives while `future_reference_pending` is set and no publication is arriving in that same cycle, the scheduler does not wait; it clears `reorder_active`, `run_closed` and `decode_inflight` and raises `presentation_error`. The recorded state `sched=0/0/0/2` matches that branch exactly, including the stale run count. The apparent `run_picture_count>=2` cause was excluded by checking coded order directly: the clip is `IPBBPBBPBB...` with at most two consecutive B pictures, structurally identical to both corpus streams, so no third B exists and the run simply failed to close. The single physical trigger for both failures is a P reference that publishes later than either layer assumes, which real photographic content produces because its P pictures carry far denser residuals and roughly sixteen times the bidirectional macroblock count of the synthetic corpus. Both layers respond to lateness by fail-stopping rather than by applying backpressure, and because `b_user_success` is gated by `b_accept_error`, a latched publication error also permanently suppresses the completion edge the scheduler waits on, which is why the hardware symptom is a permanent freeze with a correct final picture and a fully responsive OSD rather than a visible error.

#### Next Steps:

Treat lateness as a legal condition to be waited on rather than an illegal state to be trapped, in both layers, and change nothing else. In the scheduler, the run-closing branch should hold the pending non-B header until `future_reference_pending` clears instead of raising `presentation_error`, which requires proving that the publication is genuinely guaranteed to arrive so the hold cannot deadlock, and requires the parser backpressure to reach the transport without violating the Entry 247 overlap contract. In the probe, the header-time comparison should be replaced by a check at the point the B transaction actually binds or consumes its future reference, so that Entry 227's deferred binding is permitted while a genuine unpublished-reference consumption is still caught. Bound both changes in simulation before any Quartus build, requiring the corpus soak to stay exactly at 6,589,996 cycles with zero errors and the Big Buck Bunny clip to complete with correct publication counts, then validate on hardware with a paired control. Do not relax the probe alone, because the lenient experiment proves the scheduler fails immediately afterwards. This defect is a v0.6.0 release blocker for real content, and it should be fixed before resuming the 25 fps scratch-pool work, since a compatibility-focused player cannot ship a core that freezes after three pictures of ordinary video.

#### Files Modified:

- .gitignore
- tools/streams/generate_test_big_buck_bunny.py

#### Status:

- [x] Built
- [ ] Passed

---
## 283 COMMIT Unreleased b9c2ddb 2026-08-20T21:14:39-07:00

#### Coming From:

Unreleased 1e68cf9

#### Purpose:

Add a real-content test stream at the user's request and diagnose the reproducible playback freeze it exposes on the road to v0.6.0.

#### Outcome:

The user supplied an archived Big Buck Bunny source and asked for a playable elementary stream, which `generate_test_big_buck_bunny.py` now produces. The source is 854 pels wide and 24 fps, so it is scaled to the framebuffer's 720-pel `SRC_WIDTH` guard and resampled to frame rate code three to engage the cadence accumulator. The stream freezes on hardware after roughly three displayed pictures, reproducibly, with the MiSTer menu and OSD fully responsive and the last decoded picture retained on screen. The retained picture is visually correct with clean gradients and no artefacts, so this is a liveness defect and not a decode-correctness defect, and the user captured video confirming the OSD opens over the frozen frame. HDMI is confirmed as 1920 by 1080 at 60 Hz on the user's panel, matching the assumption recorded in Entry 281.

Two independent defects were found. The first is in the project's own tooling: FFmpeg 8.0.1 no longer emits the H.262 sequence_end_code, while the FFmpeg that produced the committed corpus did. Every committed stream ends with `000001b7`; every stream generated on the current host, including a synthetic `testsrc2` control built with the existing generator's exact flags, does not. The decoder's frontend needs that code to raise `sequence_end_seen`, and the cadence profiler publishes its telemetry overlay only once that is set, so any regenerated stream can never be measured and never quiesces. `generate_test_big_buck_bunny.py` now appends the terminator when the encoder omits it. This affects `generate_test_progressive_compatibility.py` and the other committed generators equally, which are not yet corrected, so the corpus is not currently reproducible on this host as the build environment policy intends.

The second defect is the freeze itself, and the terminator fix does not cure it. A `POST_INPUT_TRACE_CYCLES` watchdog was added to the soak testbench because the existing `STALL_TRACE_CYCLES` guard is gated by `stream_index<stream_len` and therefore cannot observe a decoder that accepts every byte and then fails to quiesce. With a 30-picture terminated clip the failure reproduces exactly in simulation at input byte 60,822 of 107,344, and it is a real error rather than a timeout: `probe_error` fires from `mpeg2_h262_two_picture_probe_p_chain.sv` with source four and publication detail one. That condition rejects a B picture header arriving while `p_publication_count` is below `p_header_count`, and the trace records six P headers observed against five publications. Because `probe_error` feeds `mpeg2_new_phase1_probe_error`, which `MediaPlayer_top_00.svh` treats as a fatal transport error, the transport drains and decoding stops permanently, which is precisely the observed freeze with a live OSD. Earlier hypotheses were eliminated with evidence: capping motion search so no f_code exceeds two did not change the failure, the macroblock symbol sets of the new and working streams are identical, the picture coding extension flags are byte-identical, no custom quantiser matrices are present, and the project's own analyser classifies both streams the same. The distinguishing property is density, since the new stream carries roughly sixteen times the bidirectional macroblock count, which lets a P picture still be persisting when the following B header is parsed.

#### Next Steps:

Establish before changing any RTL whether the publication ordering rule is correct or merely too strict for the overlap path. The rule is checked at B header time, but Entry 247 deliberately permits one P transaction to decode while a prior scratch and future sequence is presented, so a B header may legitimately be parsed while its future reference is still persisting provided the B decode itself waits for publication. Determine which of those two readings the surrounding logic actually implements, because the fix differs entirely: if the invariant is correct then the parser must be held until the observed P publishes, most likely by extending the existing `mpeg2_new_p_destination_ownership_hold`, and if the probe is too strict then it must distinguish header parsing from transaction acceptance rather than failing the transport. Do not relax a diagnostic that is protecting a genuine ordering requirement merely to make the stream play. Correct the remaining generator scripts to guarantee the sequence_end_code in the same cycle, then re-validate the corpus and the new stream on hardware with paired controls before treating v0.6.0 as reachable, and note that this liveness defect is a release blocker for real content while the synthetic corpus passes.

#### Files Modified:

- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 282 COMMIT Unreleased 1e68cf9 2026-08-20T20:17:12-07:00

#### Coming From:

Unreleased c98aeef

#### Purpose:

Replace the priority-encoded stall counters with unconditional hold, overlap and availability counters so the presentation-hold bottleneck can be attributed before any functional change is attempted.

#### Outcome:

Review of `mpeg2_h262_hardware_cadence_profiler.sv` established that the three existing stall counters cannot answer the question Entry 281 leaves open, because their attribution is a strict priority chain in which a non-ready decoder is counted first, presentation hold second and destination hold only third. The categories are therefore mutually exclusive by construction, a destination hold overlapping a presentation hold contributes nothing to `destination_stall_cycles`, and the Entry 281 claim that the third reference bank is provably idle does not follow from the zero destination stall standing since Entry 276; that claim is withdrawn. The profiler's `decoder_ready` input is confirmed to be the pre-hold `mpeg2_new_decoder_stream_ready`, so the holds do not feed back into their own counter and the existing totals remain valid for what they measure.

This commit adds five counters that increment whenever their own condition is true, independent of each other and of `fifo_pending`: total presentation hold, total destination hold, both holds together, presentation hold while a scratch destination is available, and presentation hold while a promotion is pending. Two pure observability outputs expose the scheduler's existing `queued_scratch_available` and `promotion_pending` terms; no scheduler logic, ownership rule or presentation behaviour changed. The snapshot grew from 21 to 26 words at schema version two, `OVERLAY_Y` moved from 512 to 492 and `OVERLAY_HEIGHT` from 84 to 104 so 26 four-pixel rows still end at line 596 inside the 600-line active area, and `decode_hardware_cadence.py` was updated in step. The first build was rejected before deployment: the overlay row multiplexer enumerated only rows zero to twenty, so the five new words rendered as the `default` zero and telemetry failed its checksum with a zero final word. Adding rows twenty-one to twenty-five fixed it. The second build then missed the positive-timing gate at minus 0.074 ns worst-case setup on a standing MiSTer framework clock while the decoder and video clocks stayed clean at plus 1.724 and plus 7.915 ns, the same class of miss Entry 257 recorded; that RBF was also rejected and not deployed. Changing the reproducible fitter seed from six to seven, with no source change, closed it. The accepted fully clean Quartus 17.0.2 build completes in 11 minutes 7 seconds with zero errors, zero Critical Warnings, plus 0.212 ns global setup, plus 1.417 ns decoder setup, plus 0.256 ns hold, plus 4.019 ns recovery, plus 0.683 ns removal and plus 0.462 ns minimum pulse slack, using 33,607 ALMs and 49,185 registers. Artifact SHA-256 is `525fa51f10496ff053bd2895fdd73c28c4c4c60cab224ffa4d268f07887c63f3`. The scheduler regression passes and regains the reset-aware consecutive-window monitor restored from Entry 280, reporting the 60.3165 Hz counts of one, three and two with a minimum present gap of two. The long-GOP soak replay passes on the reverted baseline at exactly 6,589,996 cycles with zero errors, reproducing the Entry 278 figure and confirming the revert restored that behaviour precisely.

Hardware reads schema two cleanly with 26 words, no validation failures, all 72 pictures, 71 swaps, 25 references, zero error flags and 23.501596 fps, confirming the instrumentation is cadence-neutral against the 23.6 fps baseline band. The result refutes both standing hypotheses. Destination hold total is exactly zero, so the hold is never asserted at all rather than merely masked by priority, and hold overlap is consequently zero; the masking mechanism was real but is not what was happening. Promotion-pending hold is 21 cycles, effectively never, so presentation hold is almost entirely `!queued_header_capacity`. Presentation hold totals 53,314,257 cycles, 32.1 percent of the session, and a scratch destination is available during only 8,057,481 of them, 15.1 percent. That bounds the proposed lookahead below the target: recovering every one of those cycles at zero cost would reach 24.7227 fps against a requirement of 9,777,856 cycles, so a one-picture lookahead cannot close long-GOP by itself. For the remaining 84.9 percent of hold cycles no scratch bank is free, which identifies the two-bank scratch pool rather than the reference destinations or the input gate as the binding resource.

#### Next Steps:

Stop pursuing the input-transport relaxation as a standalone fix, because its own ceiling is now measured at 24.7227 fps. Target the scratch pool instead, since 84.9 percent of presentation hold occurs with no scratch bank free and promotion is never the cause. Propose and bound a third scratch bank before implementing it, using the same zero-cost ceiling method that correctly rejected the destination predecode in Entry 270, and note that DDR already carries three reference banks plus two scratch banks so a sixth frame's address map and ownership tag width must be checked against the arbiter's three-bit displayed-region comparison from Entry 276. Pair any candidate with the 8,057,481-cycle lookahead saving only if both can be shown to compose, and continue to treat every projection as a lower bound because seven consecutive commits have shown removed cycles migrating into another stall category. A new real-content stream generator, `generate_test_big_buck_bunny.py`, is added at the user's request and produces a 720-by-480 25 fps long-GOP elementary stream from the archived Big Buck Bunny source; the source is 854 pels wide and 24 fps, so it is scaled to the framebuffer's 720-pel `SRC_WIDTH` limit and resampled to frame rate code three to engage the cadence accumulator. Its 250-frame default is 1,078,279 bytes and it is not yet hardware validated.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- MediaPlayer.qsf
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- tools/streams/decode_hardware_cadence.py
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 270 COMMIT Unreleased f298a67 2026-08-20T11:15:00-07:00

#### Coming From:

Unreleased f24e0f5

#### Purpose:

Measure whether bounded destination-safe P row predecode can close both Entry 269 hardware gaps before allocating a fifth full-frame DDR destination.

#### Outcome:

Commit `f298a67` converts the Entry 269 counters into strict zero-cost upper bounds without assuming unobserved per-picture overlap. An attempted reference-bank replay is rejected because aggregated I/P/B totals reproduce 25 fps even for the measured current policy, the same falsified optimism as Entry 268; the retained analyzer instead asks whether an architecture can close the target after granting it more savings than physically possible. Long measures 164,947,334 cycles against 153,360,000: erasing every one of its 10,805,922 destination-wait cycles still leaves 154,141,412 cycles or 24.873264 fps, 781,412 cycles short, so bounded two-row predecode is rejected. Mixed measures 57,180,519 cycles against 49,680,000: erasing every one of its 535,828 destination-wait cycles leaves 56,644,691 cycles or 21.926150 fps, 6,964,691 cycles short. A fifth-frame absolute bound is deliberately stronger still and erases every destination plus presentation wait cycle at zero cost. That can close long, but mixed bottoms out at 50,968,483 cycles or 24.368000 fps and remains 1,288,483 cycles short. Therefore neither destination predecode nor a fifth frame can close both streams alone; even ideal frame ownership must be paired with at least a 5.71 percent reduction of mixed's measured decoder-wait cycles. The analyzer compiles and both deterministic hardware boundaries pass; no functional RTL or Quartus build is warranted.

#### Next Steps:

Retain Entry 269's timing-clean scheduler, reject bounded P predecode, and do not undertake the fifth-frame widening alone. Build the next combined ceiling from the ideal fifth-frame residual and an independently measured decoder change: Entry 266's queued B block fetcher removes an optimistic 13.69 percent of mixed B-span work, which scales above the required 1,288,483-cycle residual, while Entry 267's wider tap lanes provide a separate comparison. Require the combined bound to include realistic rather than zero-cost ownership savings and close both streams before choosing whether to implement B block queueing first or widen full-frame bank identity first.

#### Files Modified:

- tools/streams/analyze_destination_predecode_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 271 COMMIT Unreleased 0cf21a2 2026-08-20T11:25:00-07:00

#### Coming From:

Unreleased f298a67

#### Purpose:

Measure one joint B block-fetch and two-lane interpolation schedule against the fifth-frame residual so shared execution time is never counted twice.

#### Outcome:

Commit `0cf21a2` extends the recorded-block replay with exact per-block one-lane and two-lane tap durations, subtracts only that parity-derived saving from each observed consumer interval, and passes the adjusted interval through the same two-bank producer/consumer schedule; fetch overlap and lookup width are therefore composed rather than added. Every Entry 266 and 267 invariant reproduces exactly. Mixed retains 15 B pictures, 4,320 blocks, 592,054 serial B-span cycles, 64,806 fetch cycles, 124,012 setup-gap cycles, 403,236 consumer cycles, direction counts 894/2,592/834 and 391,808 one-lane tap cycles. Its fetch-only ceiling remains 511,007 cycles and its two-lane tap saving remains 85,760; the joint schedule is 425,567 cycles, saving 166,487 or 28.12 percent of B span. Scaled only against Entry 269's 12,303,219 measured mixed B-stall cycles, that is an optimistic 3,459,694-cycle decoder reduction. Long retains 47 B pictures, 13,536 blocks, 3,854,042 serial cycles, 332,552 fetch cycles, 1,230,804 gap cycles, 2,290,686 consumer cycles, direction counts 1,878/3,594/8,064 and 2,304,000 one-lane taps. Its fetch-only ceiling remains 3,441,302 and two-lane saving remains 908,800; the joint schedule is 2,553,302 cycles, saving 1,300,740 or 33.75 percent of B span, scaled to an optimistic 12,652,760 of Entry 269's measured B stalls. Entry 270's deliberately impossible zero-cost fifth-frame bound plus those non-double-counted decoder ceilings reaches 26.142531 fps mixed and clears long as well. The combined architecture therefore has sufficient upper-bound headroom, while neither constituent alone is justified as a 25-fps claim. Both analyzers compile and both complete recorded traces pass; no RTL or Quartus build is warranted.

#### Next Steps:

Retain Entry 269 scheduler ownership and implement only the lower-risk two-bank B block fetch queue next. Separate block address/fetch production from pixel consumption, permit at most one prefetched successor block, retain the existing one-outstanding tagged DDR/cache contract, and prevent either bank from reuse before its block retires. Require focused B pixels and stores, exact mixed pixels, complete long accounting and a material end-to-end cycle reduction before Quartus; measure hardware before deciding whether to add the two-lane lookup or widen full-frame identity.

#### Files Modified:

- tools/streams/analyze_b_block_pipeline_ceiling.py
- tools/streams/analyze_destination_predecode_ceiling.py

#### Status:

- [x] Built
- [x] Passed

---
## 272 COMMIT Unreleased 41ce63f 2026-08-20T11:30:00-07:00

#### Coming From:

Unreleased 0cf21a2

#### Purpose:

Overlap B-picture prediction fetch for the next block with reconstruction of the current block through two explicitly owned retained-word banks.

#### Outcome:

Commit `41ce63f` gives B reconstruction two explicitly selected retained-word fetchers while preserving a single active producer and the existing ordered cache and DDR interface. The current bank remains lookup-owned until the writer persistence barrier; only then may its already launched successor become the consumer and release the old bank. Prefetch is limited to the five internal block transitions of a macroblock, with block five retaining the synchronous next-motion-record boundary. A `current_started` guard found by the focused regression prevents a stale completion from launching block one with the previous macroblock's motion record. Predicted and intra-focused replays preserve all 1,350 motion records, 120/12 residual blocks, 7,680/768 residual samples and all 518,400 stores at 1,286,071 and 758,941 cycles; they prove 8,100/8,088 total launches, 6,750/6,740 prefetched handoffs, balanced bank reuse and zero simultaneous producers. Exact mixed preserves 423,936 pixels with zero mismatches, maximum channel delta two, all 69,556 reads and all ownership counts at 1,279,996 one-cycle cycles; the identical ten-cycle Entry 269 comparison falls from 1,329,996 to 1,289,996 cycles, 3.01 percent. Complete long preserves every picture, swap, read and write with zero errors at 6,979,996 cycles. A fully clean seed-six Quartus 17.0.2 build completes in 10 minutes 52 seconds with zero errors, 149 standing warnings and positive timing: +0.065 ns global setup, +1.118 ns decoder setup, +7.469 ns video setup, +0.244 ns hold, +3.059 ns global recovery, +14.915 ns decoder recovery and +0.703 ns removal. The fit uses 32,713 ALMs, 48,156 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit272_41ce63f.rbf` is 4,318,908 bytes with SHA-256 `faa2f35639311d5544f94572307ba1ad2d06ecf7e0e49bd27788b378dfec45c9`; standard-path and cadence-path MiSTer uploads are byte-identical. Hardware long accepts 791,528 bytes, 72 pictures and 71 swaps with zero errors in 164,037,695 cycles or 23.372677 fps, improving 0.55 percent from Entry 269. Mixed accepts 366,071 bytes, 24 pictures and 23 swaps with zero errors in 56,918,964 cycles or 21.820496 fps, improving 0.46 percent. B stall falls 8.10 percent long and 7.51 percent mixed, but increased presentation and writer ownership absorbs most of that decoder gain; the queue is therefore safe pipeline infrastructure, not a large standalone cadence win.

#### Next Steps:

Retain the timing-clean Entry 272 image while implementing the independently measured two-lane B interpolation step from Entry 271. Consume two taps from a retained 64-bit word only when both requested bytes are valid in that word, preserve the existing one-tap path across word and row boundaries, and require parity-exact prediction sums, all focused and complete regressions, a clean timing result and measured hardware cadence before deciding whether the added compute width plus this queue merits its resource cost or should be collapsed back to one retained bank.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 273 COMMIT Unreleased 22e54d9 2026-08-20T12:01:05-07:00

#### Coming From:

Unreleased 41ce63f

#### Purpose:

Consume two horizontally adjacent B-picture interpolation taps from one retained prediction word when their row and word identity are equal.

#### Outcome:

Commit `22e54d9` adds an explicit same-row, same-retained-word pair predicate to the B lookup path so one registered response can contribute two adjacent interpolation bytes while row changes and word crossings retain the single-tap path. Focused predicted and intra replays remain exact at 1,286,071 and 758,941 cycles with every motion record, residual sample and store preserved. Exact mixed preserves all 423,936 pixels with zero mismatches, maximum channel delta two, all 69,556 reads and all queue ownership counts at 1,269,996 one-cycle cycles, with 30,352 paired and 27,344 fallback lookup events. Complete long preserves every picture, swap, read and write with zero errors at 6,929,996 cycles, with 330,064 paired and 488,608 fallback events. These are 0.78 and 0.72 percent simulation reductions from Entry 272. A fully clean Quartus 17.0.2 build completes in 11 minutes 10 seconds with zero errors, 149 standing warnings and positive timing: +0.306 ns global setup, +1.548 ns decoder setup, +7.876 ns video setup, +0.247 ns hold, +4.090 ns global recovery, +15.856 ns decoder recovery and +0.592 ns removal. The fit uses 32,944 ALMs, 48,452 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit273_22e54d9.rbf` is 4,351,884 bytes with SHA-256 `f4ce7bc421b83f37e65d30c2abc683c5dc720cc0ab89f55050eafa7c3a46e805`; the standard MiSTer upload and FTP readback are byte-identical. Hardware long accepts all 791,528 bytes, 72 pictures and 71 swaps with zero errors in 164,069,310 cycles or 23.368173 fps; B stall falls by 450,189 cycles and decoder stall falls by 456,389, but cadence is 31,615 cycles slower than Entry 272. Mixed accepts all 366,071 bytes, 24 pictures and 23 swaps with zero errors in 56,934,988 cycles or 21.814354 fps; B stall falls by 187,231 cycles and decoder stall falls by 189,142, but cadence is 16,024 cycles slower. The paired path therefore removes measured decoder work correctly, yet the existing frame-ownership and presentation boundary absorbs all of that saving.

#### Next Steps:

Retain the timing-clean paired lookup because hardware confirms that it removes B decoder cycles needed by the combined Entry 271 ceiling, but do not claim an end-to-end cadence gain while presentation ownership absorbs it. Extend the two-bank B producer across the remaining block-five to next-macroblock boundary by reading and validating the next motion record early, preserving the single active producer and synchronous motion-memory semantics; require exact recorded traces and a measured B-stall reduction large enough to clear mixed's remaining ideal fifth-frame residual before widening full-frame destination identity.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 274 COMMIT Unreleased 5d0e18c 2026-08-20T12:28:01-07:00

#### Coming From:

Unreleased 22e54d9

#### Purpose:

Prefetch B-picture block zero of the next macroblock while block five of the current macroblock reconstructs.

#### Outcome:

Commit `5d0e18c` stages the next synchronous motion record after current block-five fields are secured and extends the alternate fetch-bank producer through block zero of the following macroblock without adding a motion-memory port or another active DDR producer. Focused predicted replay preserves all 1,350 motion records, 120 residual blocks, 7,680 samples, 518,400 stores, exact prediction values and balanced bank reuse while proving 1,320 cross-macroblock launches and handoffs; it falls from 1,286,071 to 1,275,511 cycles, 0.82 percent. Focused intra preserves all 12 blocks, 768 samples and stores while proving 1,316 eligible cross-boundary handoffs at 757,621 cycles, 1,320 cycles faster. Exact mixed preserves all 423,936 pixels with zero mismatches, maximum channel delta two, all 69,556 reads, 4,230 prefetched handoffs including 630 cross-macroblock handoffs, all tap counts and zero errors, but remains exactly 1,269,996 cycles. Complete long preserves every picture, swap, write and all 372,696 reads with 13,254 prefetched handoffs including 1,974 cross-macroblock handoffs and zero errors at 6,919,996 cycles, only 10,000 cycles or 0.14 percent faster. The candidate therefore fails its material complete-trace threshold: its extra production is already hidden in mixed and almost entirely hidden in long. Per the proposal, no Quartus build, RBF or MiSTer deployment was performed; the standard MiSTer remains on timing-clean Entry 273.

#### Next Steps:

Do not build or deploy the cross-macroblock candidate alone. Use the 27,344 mixed and 488,608 long single-tap fallback events left by Entry 273 to measure a dual-row retained-word lookup ceiling, then compose that reduction with this exact candidate in complete simulation. Proceed to a clean physical build only if the combined boundary materially reduces mixed and long total cycles; otherwise remove the staged-motion control before the next hardware-qualified source commit.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 275 COMMIT Unreleased 45bdfc8 2026-08-20T12:49:21-07:00

#### Coming From:

Unreleased 5d0e18c

#### Purpose:

Pair vertically adjacent B-picture interpolation taps through a registered adjacent-row retained-word response.

#### Outcome:

Commit `b23744c` adds a registered adjacent-row result to each retained B fetch bank and consumes two pure-vertical half-pel taps when consecutive valid rows select the same word column, without adding a DDR read, cache request or combinational external lookup port. Its first clean synthesis exposed that Entry 274's staged cross-macroblock motion-record read had changed the B motion table into uninferred registers, so that build was stopped before place-and-route and never deployed. Corrective commit `45bdfc8` removes the unqualified Entry 274 staging while preserving vertical pairing and restores `motion_mem` as a 34-by-1,350 dual-port M10K. Focused predicted and intra replays preserve every motion record, block, sample and store exactly at 1,286,071 and 758,941 cycles. Exact mixed preserves all 423,936 pixels with zero mismatches, maximum channel delta two and all 69,556 reads at 1,259,996 cycles, with 52,679 paired, 5,017 fallback and 22,327 vertical events; complete long preserves every picture, swap, read and write with zero errors at 6,859,996 cycles, with 755,845 paired, 62,827 fallback and 425,781 vertical events. These are 0.79 and 1.01 percent simulation reductions from Entry 273. The corrected fully clean Quartus 17.0.2 build completes in 11 minutes 24 seconds with zero errors and 149 standing warnings. Timing is positive at +0.335 ns global setup, +2.274 ns decoder setup, +8.062 ns video setup, +0.249 ns hold, +4.437 ns global recovery, +15.079 ns decoder recovery, +0.695 ns removal and +0.462 ns minimum pulse slack. The fit uses 33,322 ALMs, 48,416 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit275_45bdfc8.rbf` is 4,368,628 bytes with SHA-256 `7749cf0dc2d974ae132fcc019de40ffa4a140cf7fe2193a0f48040bb5a97f275`; its standard MiSTer upload and FTP readback are byte-identical. Hardware long accepts all 791,528 bytes, 72 pictures and 71 swaps with zero errors in 164,045,684 cycles or 23.371538 fps; B stall falls by 350,541 cycles and decoder stall by 338,202 from Entry 273, while cadence improves by only 23,626 cycles. Mixed accepts all 366,071 bytes, 24 pictures and 23 swaps with zero errors in 56,954,583 cycles or 21.806849 fps; B stall falls by 84,528 cycles and decoder stall by 79,999, but cadence is 19,595 cycles slower. The registered vertical pair is therefore exact, timing-clean and removes real decoder work, while frame ownership and presentation again absorb essentially all end-to-end savings.

#### Next Steps:

Retain the timing-clean vertical pair and leave Entry 274's cross-macroblock staging removed. Implement the previously bounded fifth full-frame destination identity so decode can continue while the visible past reference, future prediction reference and two B scratch frames are occupied; preserve strict display order, reference dependencies, scratch generation identity and the 25 fps cadence gate. Re-run the exact mixed and long regressions plus a clean timing build and hardware telemetry, noting that erasing current mixed presentation and destination waits would reach 49,947,143 cycles, only 267,143 cycles above the 49,680,000-cycle 25 fps target, so the ownership change must preserve the accumulated decoder savings and expose or remove that small residual rather than claiming success from isolated stall reduction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_b_residual_streaming.sv

#### Status:

- [x] Built
- [x] Passed

---
## 276 COMMIT Unreleased eae80fd 2026-08-20T13:37:33-07:00

#### Coming From:

Unreleased 45bdfc8

#### Purpose:

Add a third reference-picture destination so queued decode can proceed while two references and both B scratch frames remain owned by presentation.

#### Outcome:

Commit `e8d4085` adds reference bank two at DDR word offset `0x00040000`, rotates reference destinations across banks zero, one and two, widens publication, destination, completed, display and profiler identities to two bits, and supplies B prediction with the explicit previous and future reference identities while retaining both existing scratch banks. The scheduler also binds wrapped reference-bank identities with the monotonic promotion count so a later bank reuse cannot be mistaken for an already displayed generation. Focused scheduler, profiler, B prediction and B intra tests pass; the complete 720-by-480 publication streams use bank two three times in mixed and eight times in long with zero overwrite or presentation errors. Exact mixed preserves all 423,936 samples with zero mismatch, maximum delta two, 69,556 reads and 1,259,996 cycles, while exact long preserves every picture, swap, read and write with zero errors at 6,859,996 cycles.

The first fully clean `e8d4085` build completed with zero errors and 148 standing warnings at +0.168 ns global setup, +1.557 ns decoder setup and +7.905 ns video setup. Its 4,329,740-byte RBF had SHA-256 `6b20e26fb7efc1342dd9860f3a939b13d79fef039e1b48e861c02590a988e865`, but both clean-state hardware attempts stalled the MiSTer host inside the stream transfer and prevented later command processing, so that artifact was rejected and Entry 275 was restored. The hardware-only smoking gun was the DDR arbiter's two-bit displayed-region tag: bank two region `100` aliased bank zero region `000`, permanently blocking the next reference write after a live framebuffer read. Commit `eae80fd` widens the ownership tag and comparison to address bits `[18:16]`; the focused arbiter test now proves bank-two exclusion and simultaneous bank-zero writability at descriptor depths two and four.

The corrected fully clean Quartus 17.0.2 build completes in 11 minutes 11 seconds with zero errors and 148 standing warnings. Timing is positive at +0.355 ns global setup, +1.418 ns decoder setup, +7.648 ns video setup, +0.249 ns hold, +3.301 ns global recovery, +15.786 ns decoder recovery, +0.909 ns removal and +0.462 ns minimum pulse slack. The fit uses 33,349 ALMs, 48,497 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit276_eae80fd.rbf` is 4,315,640 bytes with SHA-256 `70a03ba5d45a22d9a7b998e7720f0b07d6ce4cb041e875d84f8f0de6ec4d2f13`; its standard MiSTer upload and FTP readback are byte-identical. Hardware accepts both streams with every byte and picture, 71 and 23 swaps, zero errors and zero destination stalls. A same-session Entry 275 long control measures 162,257,847 cycles at 23.629058 fps with 11,035,408 destination-wait and 35,863,879 presentation-wait cycles; Entry 276 measures 162,259,999 cycles at 23.628744 fps with zero destination wait but 46,960,320 presentation-wait cycles. Mixed similarly moves from a restored Entry 275 control of 56,882,093 cycles at 21.834640 fps with 639,948 destination-wait cycles to 56,956,680 cycles at 21.806046 fps with zero destination wait. The third destination is therefore functionally correct and removes the physical ownership collision, but cadence absorbs the released time almost exactly and no material end-to-end gain remains.

#### Next Steps:

Retain the exact three-bank ownership correction because it removes destination stalls safely, but do not count it as an FPS optimization. Use the paired hardware result to target decoder concurrency rather than another destination: mixed remains 7,276,680 cycles above its 49,680,000-cycle 25 fps target with 21,349,182 decoder-stall cycles, including 11,104,109 in B pictures, while long remains 8,899,999 cycles above target with 57,430,275 decoder-stall cycles. Before changing production RTL, measure a tagged two-word prediction-request producer that separates reference address generation from pixel consumption and permits useful overlap beyond the already rejected passive descriptor-depth increase.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_ddram_arbiter.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 277 COMMIT Unreleased d374f42 2026-08-20T15:13:00-07:00

#### Coming From:

Unreleased eae80fd

#### Purpose:

Collapse eligible B-picture 2-by-2 half-pel phases into one registered retained-word lookup so all four interpolation taps are consumed together.

#### Outcome:

Commit `d374f42` adds the proposed quad predicate only for tap zero of a 2-by-2 half-pel phase when the current and adjacent-row retained words are both valid and each horizontal pair remains within one word. It consumes all four selected bytes in one registered lookup event while leaving word crossings, missing adjacent rows, one- and two-tap interpolation, forward/backward phase order, bidirectional rounding, residual addition, writer persistence and DDR behavior on their accepted paths. The focused predicted and intra regressions remain exact at 1,286,071 and 758,941 cycles; their integer-vector fixtures correctly consume zero quad events.

The complete 423,936-pixel mixed trace remains exact with zero mismatches, maximum channel delta two, 69,556 reads and 1,259,996 total cycles. Its 4,241 quad events replace 8,482 former horizontal-pair events and reduce B lookup/raster work from 351,188/412,388 to 346,225/407,425 cycles, but presentation overlap absorbs the saving and total cadence is unchanged. The long trace likewise preserves all 25 reference publications, 47 B pictures, 71 swaps, 372,696 reads, bank writes and zero errors at exactly 6,859,996 total cycles. Its 102,888 quad events replace 205,776 former pair events and reduce B lookup/raster work from 1,607,305/1,799,065 to 1,494,530/1,686,290 cycles, yet the complete trace again does not move. The candidate therefore fails the proposal's material end-to-end threshold. No Quartus build or hardware deployment is warranted, and the MiSTer remains on the timing-qualified Entry 276 `eae80fd` RBF.

#### Next Steps:

Retain the exact quad implementation as a composable internal reduction, but do not build it by itself. Target the B sideband producer that now dominates the optimized raster path: long spends 2,466,163 cycles in replay and 1,548,488 in active parse versus 1,686,290 in raster, while mixed spends 338,293 in replay and 182,004 in active parse versus 407,425 in raster. Profile replay states and transform-launch gaps, then remove or overlap a sufficiently large producer bubble to cross the current presentation windows before starting another clean physical build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 278 COMMIT Unreleased 62f2654 2026-08-20T15:30:02-07:00

#### Coming From:

Unreleased d374f42

#### Purpose:

Remove the idle cycle between consecutive B residual-coefficient writes by reading the next coefficient while the current registered coefficient enters the transform.

#### Outcome:

Commit `edc1e1b` removed `R_COEFF_WAIT` between consecutive B coefficients and added exact accounting. Focused predicted and intra replays preserve every event and store at their unchanged 1,286,071 and 758,941 cycles; their one-coefficient blocks correctly expose 120 and 12 writes with no removable wait. Mixed preserves all 423,936 pixels with zero mismatches, maximum delta two, 69,556 reads, every write, publication and swap, and zero errors while 26,591 coefficient writes consume no wait state; B replay falls from 338,293 to 313,306 cycles and the complete trace falls from 1,259,996 to 1,239,996, a 1.59 percent reduction. Long preserves all 25 reference publications, 47 B pictures, 71 swaps, 372,696 reads, all bank writes and zero errors while 262,671 coefficient writes consume no wait state; B replay falls from 2,466,163 to 2,213,942 and the complete trace falls from 6,859,996 to 6,589,996, a 3.94 percent reduction. Its first clean synthesis correctly exposed that the combinational successor-address form prevented inference of the 32K-by-19 coefficient M10K, so that build was stopped before fitting and produced no RBF. Corrective commit `62f2654` registers the read address one stage ahead, preserves the same exact simulation results, and restores the coefficient store as a 32,768-word dual-port M10K. The fully clean Quartus 17.0.2 build completes in 11 minutes 15 seconds with zero errors and 148 standing warnings. Timing is positive at +0.431 ns global setup, +1.573 ns decoder setup, +7.382 ns video setup, +0.255 ns hold, +4.064 ns global recovery, +14.210 ns decoder recovery, +1.129 ns removal and +0.462 ns minimum pulse slack. The fit uses 33,176 ALMs, 48,491 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit278_62f2654.rbf` is 4,339,252 bytes with SHA-256 `5118e024936a332ce3de2247da758e6f5b73b0cd5bda039dba570ff6762ed022`; standard-path and cadence-path readbacks are byte-identical. Hardware accepts every byte and picture with zero errors and zero destination stalls. Two long runs deliver 23.643907 and 23.723813 fps with B stalls of 33,056,106 and 33,056,971 and decoder stalls of 56,881,180 and 56,860,739, versus the paired Entry 276 control's 23.513141 fps, 33,677,170 B stalls and 57,489,128 decoder stalls. Two mixed runs deliver 21.718370 and 21.718210 fps versus the paired Entry 276 control's 21.721273 fps, so cadence is neutral, but B stalls fall from 11,126,437 to 10,864,539/10,865,031 and decoder stalls fall from 21,401,633 to 21,140,036/21,142,269. Presentation phase still absorbs most of the local saving, but the decoder reduction is stable and the timing-clean Entry 278 RBF is retained on the MiSTer.

#### Next Steps:

Apply the proven registered coefficient read-ahead pattern to the analogous P residual pipeline, whose `G_COEFF_WAIT` still inserts one idle cycle between synchronous coefficient reads. Instrument exact P coefficient and state occupancy first, preserve RAM inference and every existing P/I pixel and publication invariant, and require a material complete mixed and long reduction before another clean hardware build; mixed cadence remains the limiting boundary at approximately 21.72 fps.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 279 COMMIT Unreleased 62f2654 2026-08-20T16:07:40-07:00

#### Coming From:

Unreleased 62f2654

#### Purpose:

Close the uncommitted P residual-coefficient experiment and designate hardware-qualified Entry 278 `62f2654` as the new independent-build baseline.

#### Outcome:

The temporary Entry 279 candidate remained exact in its focused P regression and in the complete mixed trace, where it reduced simulation from 1,239,996 to 1,209,996 cycles, but the user elected to stop optimization before the long regression, Quartus build, source commit or hardware validation. All three temporary tracked-file edits were removed, so no Entry 279 source commit exists. Entry 278 `62f2654` remains the timing-clean, hardware-accepted baseline: its best measured long-GOP result is 23.723813 fps, its mixed result is approximately 21.718 fps, all hardware counters and LED checks pass, and qualified RBF SHA-256 `5118e024936a332ce3de2247da758e6f5b73b0cd5bda039dba570ff6762ed022` remains installed on the MiSTer.

#### Next Steps:

Stop further optimization and use source commit `62f2654` as the reproducible baseline for the user's independent clean Quartus build and testing; preserve the abandoned Entry 279 measurements only as historical evidence if development resumes later.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 280 COMMIT Unreleased b3e8085 2026-08-20T19:20:11-07:00

#### Coming From:

Unreleased 62f2654

#### Purpose:

Retime the display raster to exactly 50.000 Hz so every 25 fps presentation slot receives a uniform 40 ms decode budget instead of alternating 33 and 50 ms budgets.

#### Outcome:

Re-analysis of the Entry 278 baseline finds that long-GOP is limited by presentation slot geometry rather than by decoder throughput, which explains why the decoder reductions accepted in Entries 272, 273, 276, 277 and 278 each removed real cycles without moving cadence. The former raster in `mpeg2_video_svga_800x600.sv` was 800 by 600 active within 1056 by 628 total at a 40 MHz dot clock, so the refresh was 60.3165 Hz and `MediaPlayer_top_04.svh` derived exactly one swap opportunity every 16.5792 ms from the `display_v_pos` threshold. The presentation scheduler paces 25 fps material against that grid with a nanosecond credit accumulator whose `CADENCE_STEP_25FPS` was precisely that refresh period, and a replay of the accumulator confirms it was functionally correct: with every picture ready it presented on a repeating two-and-three refresh pattern averaging 2.4127 refreshes per frame, or 24.9995 fps. The defect is that this pattern produced alternating slots of 33.158 and 49.738 ms rather than uniform ones. Subtracting long's recorded presentation wait from its measured cadence leaves 1,614,781 cycles, or 29.903 ms of actual work per frame at 54 MHz, against a nominal 40 ms budget, so average throughput already satisfied 25 fps while the narrow 33.158 ms slots were missed frequently; Entry 278 measured 2.5424 refreshes per displayed frame against the 2.4127 required. Because the accumulator deliberately saturates at its due threshold so a stalled decode cannot bank credit, every missed slot was lost permanently rather than recovered later.

This commit therefore retimes blanking to 1000 by 800 total for an exactly 50.000 Hz refresh and sets `CADENCE_STEP_25FPS` to the matching 20,000,000 ns period, leaving the 40 MHz dot clock and the 800 by 600 active area unchanged. An intermediate 1056 by 758 candidate at 49.9720 Hz was rejected before commit because its step exceeded half of the 40,000,000 ns limit, which collapsed the due margin to 0.11 percent and allowed a saturated slot to replay on the immediately following refresh; the accepted geometry makes step exactly half of limit so due equals step and, because the due comparison precedes the credit advance, a frame becomes due every second refresh in a uniform 40.000 ms slot at exactly 25 fps. The 88-pixel horizontal back porch is preserved deliberately because it is the framebuffer line-fetch window, and the 56-pixel reduction is taken from the front porch and sync width instead. A dedicated raster replay confirms 800,000 pixels per frame, exactly 50.000000 Hz and an intact 480,000-pixel active area, and every `v_pos` consumer uses thresholds at or below 600 so the added vertical blanking cannot disturb line fetch, overlay placement or the swap window. The scheduler regression passes and was strengthened rather than merely relaxed: its two refresh-specific window counts now read one, two and one, and a new always-on monitor asserts the invariant those counts existed to protect by proving that no two presentations ever land on consecutive swap windows, reporting a minimum gap of two. That monitor was validated against the unmodified 60.3165 Hz scheduler before the counts were changed. The fully clean Quartus 17.0.2 build completes in 11 minutes 32 seconds with zero errors, zero Critical Warnings and 136 standing warnings. Timing is positive at +0.116 ns global setup, +0.780 ns decoder setup, +7.994 ns video setup, +0.247 ns hold, +2.884 ns global recovery, +14.791 ns decoder recovery, +0.960 ns removal and +0.462 ns minimum pulse slack. The fit uses 33,209 ALMs, 48,414 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Artifact `MediaPlayer.rbf` is 4,330,120 bytes with SHA-256 `5531441c2e694e1737021bb8bbeef44abc905720a1574bc41113583f563d5322`, uploaded to the MiSTer as `MediaPlayer_test.rbf` for side-by-side comparison against the retained Entry 278 core. The complete long-GOP soak replay and its paired 60.3165 Hz control were still running when this entry was written and are therefore not yet evidence.

#### Next Steps:

Validate on hardware against the Entry 278 control, requiring the long-GOP stream to preserve every byte, all 72 pictures, all 71 swaps and zero error flags while cadence rises from 23.723813 fps toward the 25.000 fps paced ceiling. Treat the profiler figure as necessary but not sufficient, because the core-side refresh is what changed: with no active `MiSTer.ini` the defaults `direct_video=0` and `vsync_adjust=0` leave HDMI on the display's detected native mode, so a 60 Hz panel will have the framework convert the 50 Hz raster and can still show 50-to-60 cadence judder even when the counters read a genuine 25 fps. Confirm the counters first, then judge the picture in the ordinary HDMI configuration, then repeat against a forced 50 Hz HDMI mode to attribute any residual judder to that conversion rather than to the decoder. Record also that this change moves the free-running path for non-25 fps material, because `cadence_25fps` gates on frame rate code three alone and every other stream now presents at 50 Hz rather than 60.3165 Hz, so 24, 29.97 and 30 fps content needs its own cadence policy before this raster can be considered general. If the mechanism is confirmed but a residual gap remains, the next target is the input transport hold in `MediaPlayer_top_00.svh`, which still stops the parser during a presentation transaction and therefore prevents decode of the following picture from overlapping presentation using the third reference bank that Entry 276 already allocated.

#### Files Modified:

- rtl/mpeg2_video_svga_800x600.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 281 COMMIT Unreleased b3e8085 2026-08-20T19:22:04-07:00

#### Coming From:

Unreleased b3e8085

#### Purpose:

Record the paired long-GOP hardware result of the 50.000 Hz raster retiming and correct the Entry 280 diagnosis it was built on.

#### Outcome:

Hardware rejects the cadence claim. Both cores were measured in one session against the same long-GOP stream with the automated profiler, and the Entry 278 baseline was fetched back from the MiSTer and confirmed as SHA-256 `5118e024936a332ce3de2247da758e6f5b73b0cd5bda039dba570ff6762ed022` before use. Entry 280 `b3e8085` delivers 23.426986 fps against a same-session Entry 278 control of 23.635634 fps, a 0.88 percent regression. Both runs are functionally clean with all 72 pictures, all 71 swaps, 25 reference pictures, zero error flags, zero destination stalls and no validation failures, so the retimed raster is correct; it is simply not faster. The internal movement is the same pattern the log has now recorded six times: decoder stall falls from 56,842,916 to 55,601,714 cycles, a genuine 2.18 percent reduction, while presentation stall rises from 47,150,448 to 49,653,263, a 5.31 percent increase that more than absorbs it. Writer wait also falls from 3,831,708 to 2,335,832 while I and P stalls are effectively unchanged.

The Entry 280 reasoning was wrong in one specific and consequential way. It subtracted recorded presentation wait from measured cadence, obtained 29.903 ms of work per frame, and concluded that the work already fitted a 40 ms budget so only the narrow 33.158 ms slot was blocking 25 fps. The non-stall figure is confirmed at 30.544 ms per frame, but presentation stall is not removable idle time waiting for a grid; it is 12.951 ms per frame of decode blocked on presentation, and it sits on the critical path. The real per-frame requirement is therefore about 43.5 ms, which exceeds the old 33.158 ms narrow slot and the new uniform 40.000 ms slot alike. That is why the measured frame period barely moved, from 42.309 ms on the control to 42.686 ms, and why the refresh grid changed the quantisation without changing the result: the control spent 2.5519 refreshes per frame at 16.5792 ms while Entry 280 spends 2.1343 at 20.000 ms. The retiming is very slightly worse because a coarser 20 ms grid loses more when a frame overruns, and because it removed the 49.738 ms relief slot that roughly one frame in eight had been relying on. The user separately reports that both streams play correctly with a stutter approximately once per second, which is consistent with the roughly thirteen percent of frames that still overrun a uniform slot, and reports the picture as subjectively acceptable; that subjective improvement is plausible because a uniform two-refresh cadence is regular where the former two-and-three alternation was not, but it is not evidence of higher throughput and must not be recorded as such.

#### Next Steps:

Treat presentation stall as the sole remaining target, because it is now measured at 12.951 ms of every 42.686 ms frame and reaching 25 fps requires removing 10,297,414 cycles, or 20.7 percent of it, with no other reduction. The specific mechanism is the input transport hold in `MediaPlayer_top_00.svh`, where `mpeg2_new_stream_ready` is gated by `mpeg2_new_b_presentation_hold` and `mpeg2_new_p_destination_ownership_hold` so the parser stops for the duration of a presentation transaction; Entry 276 already allocated the third reference bank that would let the following picture decode during that window, and its destination stall has been zero ever since, so the storage is provably idle while the parser is blocked. Propose and measure a bounded relaxation of that hold before changing the raster again. Decide with the user whether to retain the 50.000 Hz raster or revert to the Entry 278 geometry while that work proceeds, noting that the counter favours reverting by 0.88 percent, that the subjective report favours retaining, that the two questions are independent, and that with no active `MiSTer.ini` a 60 Hz panel is still frame-rate converting the 50 Hz output so the picture assessment is not yet a clean measurement of the core. The outstanding forced 50 Hz HDMI comparison would settle that last point and requires a configuration change on the user's MiSTer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

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
