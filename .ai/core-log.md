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
## 247 COMMIT Unreleased 66e769f 2026-08-20T01:41:00-07:00

#### Coming From:

Unreleased e0db323

#### Purpose:

Overlap decoding of the following reference picture with presentation of the completed B-picture run while preserving every reference and scratch-frame lifetime.

#### Outcome:

Commit `66e769f` permits exactly one following P transaction to decode while the completed prior B run presents, captures that P publication behind the ordinary classification barrier, and reasserts presentation hold before a later B header can reuse either scratch frame. The existing displayed-destination ownership gate now recognizes this overlap header, so no P write can begin until the first scratch swap releases its target reference bank. The focused scheduler passes header-before/same/after-publication, cadence, exact scratch0/scratch1/future order, one-P overlap, preserved-next-reference, starvation, terminal and fail-open cases. The exact mixed oracle retains 423,936 samples, zero mismatches, maximum delta two, 499,551/71,329/0 cache accounting and 23 swaps while falling from 2,519,996 to 2,279,996 cycles, a 9.52 percent reduction. The 72-picture live soak retains every cache count, write count, 25 publications, 47 B pictures, 71 swaps and final identity while falling from 13,419,996 to 12,689,996 cycles, a 5.44 percent reduction. The complete 366,071-byte mixed publication run passes nine reference publications, fifteen B pictures, final identity nine, zero displayed-bank overwrites and completed presentation.

A fully clean Quartus 17.0.2 build completes in 9 minutes 56 seconds with zero errors and 125 standing warnings. Timing is positive at +0.558 ns global setup, +1.389 ns decoder setup, +6.898 ns video setup, +0.200 ns hold, +4.253 ns global recovery, +15.227 ns decoder recovery and +0.448 ns removal. The fit uses 30,085 ALMs, 43,317 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. Qualified artifact `MediaPlayer_commit247_66e769f.rbf` is 4,256,044 bytes with SHA-256 `5db29ae0ee415c61096c53ebcaf2ddcacb096bc048ccbecd2f0054445653fb35`. Automated MiSTer acquisition accepts both streams exactly with zero errors. Long displays 72 pictures through 71 swaps in 219,548,405 cycles or 4.065711 seconds, improving from 14.490829 to 17.463119 fps; presentation stalls fall from 54,737,767 to 7,203,116 cycles while decoder stalls remain 161,506,865 and destination stalls remain zero. Mixed displays 24 pictures through 23 swaps in 82,893,234 cycles or 1.535060 seconds, improving from 12.786594 to 14.983129 fps; presentation stalls fall from 16,974,046 to 3,131,037 cycles while decoder stalls remain 54,797,368 and destination stalls remain zero. This proves the serialized presentation boundary was a real hardware bottleneck and leaves prediction-bound P/B reconstruction as the dominant limit.

#### Next Steps:

Retain and deploy the timing-qualified `66e769f` core as the new measured baseline. Continue with Entry 248's proposal-first cache partition model, because long still needs 66,188,405 fewer cadence cycles to reach stable 25 fps and physical prediction acceptance/response wait now accounts for 63,001,860 cycles. Reserve user video verification until telemetry reaches the requested stable 25 fps.

#### Files Modified:

- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 246 COMMIT Unreleased e0db323 2026-08-20T01:19:04-07:00

#### Coming From:

Unreleased 2a26c05

#### Purpose:

Reduce the dominant physical prediction-read wait by fetching the immediately following reference word with each cacheable DDR miss when measured address locality proves that read-ahead is useful.

#### Outcome:

Commit `e0db323` adds simulation-only models for the proposed four-entry following-word fill and a safer two-bank sidecar that never evicts a proven cache entry. The exact mixed oracle still passes 423,936 samples with zero mismatches, maximum delta two, 499,551 cache hits, 71,329 cache misses, 23 swaps and zero decoder, writer or presentation errors in 2,519,996 cycles. The proposed four-entry fill performs 97,354 modeled requests, avoids only 8,883 baseline misses, and induces 37,368 new misses by evicting useful resident words: a net regression of 26,025 requests, or 36.49 percent over the existing physical miss count. The non-evicting sidecar is directionally positive but only converts 8,632 of 68,869 observed lookup misses, split 4,160/4,472 across the two reference banks; it requires 60,237 two-word fills and therefore doubles transferred word traffic on nearly every remaining miss. Even optimistically scaling its 12.10 percent request reduction against Entry 245's complete hardware response wait predicts only a two-to-three percent FPS improvement, far below the 25 fps requirement. The hard negative mixed result is sufficient to reject functional RTL before the much slower long simulation. No cache, decoder, scheduler or synthesis source changed, and no RBF was built or deployed.

#### Next Steps:

Retain the qualified Entry 245 hardware core and the negative locality evidence. Do not add two-response DDR behavior or disturb the timing-safe four-way cache cone. Continue with Entry 247's larger measured presentation/decode serialization boundary, preserving the same exact oracle and hardware cadence gates.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 245 COMMIT Unreleased 2a26c05 2026-08-20T00:00:02-07:00

#### Coming From:

Unreleased 8d76c43

#### Purpose:

Measure real MiSTer picture cadence and decoder bottlenecks without requiring HDMI recordings for each development iteration.

#### Outcome:

Commits `71c59dd`, `d54e3f3`, and `2a26c05` add timing-isolated decoder-domain counters, a stable versioned and checksummed cross-clock snapshot, a row-serialized machine-readable video overlay, its deterministic PNG decoder, and an automated FTP/SSH MiSTer acquisition runner. The profiler is observational only and no result feeds decode, DDR, publication, presentation, or LEDs. The focused profiler passes all 21 words with picture counts `02020403`, cadence 29 and checksum `7a5b03de`; cache, repeated-download, P-intra, B-residual, parser-window, exact mixed-pixel and complete long-GOP publication regressions retain their locked functional results. The mixed oracle keeps 423,936 samples, zero mismatches, maximum delta two and 499,551/71,329/0 cache accounting; the full publication run keeps 22 P, 47 B, 25 promotions, final display identity 25 and zero holds, overwrites or errors. A fully clean seed-2 Quartus 17.0.2 build completes in 9 minutes 34 seconds with zero errors and 125 standing warnings. Final timing is positive at +0.181 ns global setup, +0.195 ns decoder setup, +7.561 ns video setup, +0.244 ns hold, +2.927 ns recovery and +0.951 ns removal; the stable snapshot and trailing-ready synchronizers have narrowly scoped first-stage CDC exceptions while every settling and ordinary logic path remains timed. Qualified artifact `MediaPlayer_commit245_2a26c05.rbf` is 4,281,080 bytes with SHA-256 `71f4180d07dc57f1d981c793c8af34277e7a4d7eee1f528bce2753cb1ee25b38`. Automated MiSTer acquisition accepts both streams exactly with zero error flags. Long GOP accepts 791,528 bytes, completes 25 reference plus 47 B pictures, displays 72 pictures through 71 swaps in 264,581,138 cycles or 4.899651 seconds, and measures 14.490829 fps; decoder, presentation and destination stalls are 161,508,107/54,737,767/0, prediction request/acceptance-wait/response counts are 5,523,274/8,483,066/54,535,837, and writer wait is 2,264,405. Mixed accepts 366,071 bytes, completes 9 reference plus 15 B pictures, displays 24 pictures through 23 swaps in 97,132,985 cycles or 1.798759 seconds, and measures 12.786594 fps; stalls are 54,845,205/16,974,046/0, prediction counts are 1,763,554/2,731,151/17,424,973, and writer wait is 736,622. These results closely validate Entry 244's video estimates while providing exact internal attribution without HDMI recordings.

#### Next Steps:

Retain the qualified profiler and use its exact hardware baselines for Entry 246's proposal-first prediction-read optimization. Preserve the timing-safe registered cache cone and 25 fps presentation gate, compare every candidate against both decoded screenshots, and reserve HDMI video for final visual verification only after telemetry reaches stable 25 fps.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/run_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 244 COMMIT Unreleased 8d76c43 2026-08-19T23:05:34-07:00

#### Coming From:

Unreleased 28b717c

#### Purpose:

Allow Quartus to optimize the already-registered P following-pixel prelaunch address without changing prediction sequencing or cache behavior.

#### Outcome:

Commit `8d76c43` removes only the synthesis `preserve` attributes from P `next_prelaunch_addr` and `next_prelaunch_valid`; both signals remain clocked registers with unchanged update conditions, lookup timing, and one-outstanding transaction behavior. P-intra, B-residual, four-entry cache accounting, repeated-download rearm, eight-refill parser-window, mixed-pixel, exact 72-picture live-raster, and full 791,528-byte publication regressions all pass unchanged. The mixed oracle retains 423,936 samples, zero mismatches, maximum delta two, 499,551/71,329/0 cache counts, and 6,803 B miss prelaunches in 2,519,996 cycles. The live soak retains 22 P pictures, 47 B pictures, 25 publications, 71 swaps, 2,267,813/463,835/0 cache counts, 463,835 DDR reads, 151,039 B miss prelaunches, 13,419,996 cycles, and zero decoder, writer, or presentation errors. The full publication run retains 25 promotions, final identity 25, zero displayed-bank overwrites, and completed presentation. A fully clean seed-2 Quartus 17.0.2 build after removing `db`, `incremental_db`, and `output_files` completes in 9 minutes 24 seconds with zero errors and 124 standing warnings. Physical synthesis can now retime eligible logic and final timing closes with +0.094 ns global and decoder setup slack, +0.249 ns global hold, +3.803 ns global recovery, +0.895 ns removal, +14.826 ns focused decoder recovery, +7.364 ns video setup, and zero TNS or focused violations; the former P prelaunch cone remains the limiting decoder path but is positive. The fit uses 29,421 ALMs, 40,603 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Qualified artifact `MediaPlayer_commit244_8d76c43.rbf` is 4,234,900 bytes with SHA-256 `0767ca4b1d87c595b9cd300133504518710ef5a659f9288153ca35130e68e66a`; its MiSTer FTP readback is byte-identical. Hardware acceptance passes. The user reports playback visually unchanged, with long GOP POWER and USER solid plus eleven DISK blinks, and mixed macroblocks POWER and USER solid plus DISK dark. Geometry-rectified 59.94 fps analysis independently recovers both the embedded counter and unobscured raster in strict unit-step order from frame 0 through 71 for long GOP and frame 0 through 23 for mixed macroblocks, with no missing identity or visible partial-frame corruption. Counter/raster first-to-final spans are 4.938/4.955 seconds for long GOP and 1.818/1.818 seconds for mixed macroblocks. The 30,976,315-byte long recording has SHA-256 `b130c9914d9ac9f36f27268fe92af5e720bdcfd046f54b572bc587aa8fba6ed7`; the 19,615,496-byte mixed recording has SHA-256 `4b5fe2425cbfbba244807707db13068205e81f0b325765b39d359e8d9626cef0`.

#### Next Steps:

Continue from hardware-accepted commit `8d76c43` and its timing-qualified seed-2 image. Preserve the registered B miss prelaunch optimization and now-closed P prelaunch cone; select the next compatibility or throughput target under the standard proposal-first workflow.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [x] Passed

---
## 243 COMMIT Unreleased 28b717c 2026-08-19T20:45:57-07:00

#### Coming From:

Unreleased 748fb3f

#### Purpose:

Prelaunch the next B prediction cache-miss DDR request at the current registered response boundary without weakening cache timing or transaction ownership.

#### Outcome:

Commit `00e215f` prelaunches an eligible same-phase B half-pel successor miss while the current registered miss response retires; `8189a46` registers the successor word address and byte select at current-request acceptance so live address arithmetic no longer extends the shared cache input cone. The focused cache, B residual, B intra, P intra, parser-window, mixed-pixel oracle, repeated-download, exact live-raster, and full-resolution publication regressions pass with unchanged pixels, identities, ownership, and traffic. The exact 72-picture soak retains 22 P pictures, 47 B pictures, 71 swaps, 2,267,813 cache hits, 463,835 misses and DDR reads, and zero errors while falling from 13,599,996 to 13,419,996 cycles, a 180,000-cycle or 1.32 percent reduction, with 151,039 B miss prelaunches; the mixed oracle retains 423,936 samples, zero mismatches, and maximum delta two while falling by 10,000 cycles. Timing qualification is not complete: the original fit failed setup at -0.481 ns, the registered-address seed-2 fit reduced that to -0.054 ns, and attempted geometry isolation plus seeds 1, 3, and 4 remained negative, with final reproducible commit `9c57bfd` at -0.693 ns setup, +0.271 ns hold, +3.881 ns recovery, and +1.095 ns removal. No RBF was qualified; at the user's explicit request the timing-failed 4,251,320-byte seed-4 image was subsequently uploaded to the standard MiSTer for diagnostic hardware testing, and FTP readback matched SHA-256 `1f773357e317b87cd012e2ed3a1d306c41810907c5aabefc04d80d59691b3170` byte-for-byte. Diagnostic hardware testing reports no lockup or other instability and video playback appears unchanged from the accepted baseline, confirming functional stability on the tested board while also showing that the modeled 1.32 percent gain is not visually distinguishable. A user-approved fully clean seed-2 rebuild after deleting `db`, `incremental_db`, and `output_files` exactly reproduces the prior near miss: 9 minutes 38 seconds, zero errors, 125 standing warnings, -0.054 ns setup with -0.064 ns TNS, +0.254 ns decoder hold, +2.760 ns recovery, +0.696 ns removal, 29,424 ALMs, 40,548 registers, and RBF SHA-256 `ef8a91fd6c4593baace804685125229df35e083fc9be815578c2a13775acc99c`; focused timing again terminates at P `next_prelaunch_addr` from live `vertical_size`, ruling out stale incremental state.

#### Next Steps:

Retain the functionally exact registered successor-miss implementation but do not deploy it until decoder setup is positive. Start from the near-clean seed-2 registered-address result and shorten or floorplan the existing P following-pixel `next_prelaunch_addr` cone without exposing combinational cache-hit data, then rerun the locked regression set and require a timing-clean build before creating or uploading a hash-qualified RBF; if that cannot close with a narrow cut, revert Entry 243 rather than weakening timing constraints.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- MediaPlayer.qsf
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 242 COMMIT Unreleased 748fb3f 2026-08-19T20:05:43-07:00

#### Coming From:

Unreleased c667f2c

#### Purpose:

Measure picture-type and stage-specific decoder backpressure before selecting the next timing-safe throughput optimization.

#### Outcome:

Commit `748fb3f` adds simulation-only input-stall, picture-type, transform-output, raster, cache-lookup, DDR request and response, emit, store, writer, and presentation counters to the exact live-raster regression without changing functional RTL or expected results. The 13,599,996-cycle 72-picture soak passes unchanged and attributes 12,385,071 input-stalled cycles to the decoder, split as 146,937 I, 3,222,891 P, and 9,015,236 B cycles; B raster occupies 4,408,213 cycles, including 2,152,961 registered lookup-wait and 1,180,560 DDR-response cycles, while destination ownership causes zero input stalls and presentation occupies 893,283 cycles. The 2,529,996-cycle mixed-pixel run independently attributes 1,309,851 of 2,164,749 decoder-stalled cycles to B pictures and passes 423,936 oracle samples with zero mismatches and maximum delta two. Cache, eight-refill parser-window, P-intra, B-residual, B-intra, repeated-download, and full 791,528-byte publication regressions pass; the latter retains 22 P pictures, 47 B pictures, 25 publications, zero destination holds or overwrites, and completed presentation. Because this commit changes only a simulation testbench, no Quartus build or MiSTer deployment is required.

#### Next Steps:

Await approval for a focused B prediction refill optimization that launches the next cache-miss DDR request at the current registered response boundary when the following tap or pixel address is already known, while preserving the four-entry fully associative cache, one-outstanding-DDR contract, registered cache-hit timing, exact bidirectional rounding, display order, cadence lifetime, reload behavior, and all pixel and transaction regressions; require a clean Quartus timing result before hardware deployment because the shared cache-to-B prelaunch cone has previously been timing-sensitive.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 231 COMMIT Unreleased 6ddeb82 2026-08-18T22:26:51-07:00

#### Coming From:

Unreleased 1177e26

#### Purpose:

Hide synchronous residual-store latency behind current-pixel P/B reference lookup so the next in-block sample begins without two serialized staging cycles.

#### Outcome:

Entry 230 is hardware accepted at final source frame 71 with USER and POWER solid, 11 DISK blinks, and visibly improved presentation cadence, while its recording measures approximately 9.2 seconds for the 2.84-second source sequence. Profiling its exact 72-picture DDR-backed soak found 21,729,996 total cycles, 20,517,231 cycles of decoder rather than presentation backpressure, and two serialized synchronous residual-store staging states on every reconstructed sample. Commit `6ddeb82` retains those staged reads at block and descriptor transitions, but prefetches the following in-block residual while the current pixel performs its reference lookup and returns directly to pixel setup after emit. Focused P-intra and B-residual regressions pass exact motion, block, residual, store, and changed-sample counts in 2,941,014 and 5,068,729 cycles, respectively. The exact live-raster soak preserves all 72 pictures, 25 publications and promotions, final display identity 25, 50,688 reference writes, 55,296/52,992 B scratch writes, 622,811 DDR reads, 2,267,813/463,835/158,976 cache hit/miss/uncached counts, and zero decoder, reconstruction, writer, or presentation errors while falling to 19,229,996 cycles: an exact 2,500,000-cycle or 11.50 percent reduction. The full 791,528-byte long-GOP publication regression also passes 22 P pictures, 47 B pictures, 25 promotions, final source frame 71, and zero destination holds, overwrites, or presentation errors. The session-authorized incremental Quartus 17.0.2 compile completes in 9 minutes 26 seconds with zero errors and 121 standing warnings; global setup/hold slack is +0.603/+0.246 ns, focused decoder/video setup slack is +1.169/+7.417 ns, and decoder recovery slack is +13.741 ns. Utilization is 30,146 ALMs, 43,384 registers, 4,027,379 memory bits, 504 M10K blocks, and 65 DSP blocks. The 4,259,412-byte `MediaPlayer_commit231_6ddeb82.rbf` artifact has SHA-256 `2347a1bc7cc9879bf42117678d9a99dc20a5a2a3e846920d8eee85f0c56e4abb`; FTP upload and MiSTer readback produced the same digest. Hardware acceptance retains final frame 71, USER and POWER solid, and 11 DISK blinks with no new visible corruption. Frame-level review of the uploaded 30 fps recording places the first fully visible frame 0 at 0.500 seconds and frame 71 at 8.364 seconds, or 7.864 seconds total: approximately 1.34 seconds and 14.5 percent faster than Entry 230's 9.2-second recording, with late frames 61 through 71 remaining monotonic.

#### Next Steps:

Retain the hardware-proven in-block residual prefetch and accepted 25 fps presentation lifetime. Profile the new exact soak outside active raster execution, especially frontend parse, inverse-transform replay, block-store completion, and uncached post-write verification, then target the largest timing-safe serialized boundary while preserving all 72 pictures, final frame 71, and the passing LED signature.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

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
## 232 COMMIT Unreleased 1b1ca8f 2026-08-18T23:55:01-07:00

#### Coming From:

Unreleased 6ddeb82

#### Purpose:

Launch the next non-intra P/B reference lookup during the current pixel's otherwise idle emit or bidirectional handoff cycle so motion reconstruction bypasses the serialized pixel-setup state.

#### Outcome:

Entry 231 is hardware accepted at final source frame 71 with USER and POWER solid, 11 DISK blinks, no new visible corruption, and a measured 7.864 seconds from frame 0 to frame 71, 14.5 percent faster than Entry 230. Commit `1b1ca8f` launches registered next-pixel and B backward-phase first-tap lookups during the preceding emit or final-tap response state, registers B motion-phase selection and base word addresses, and retains exact reconstruction while bypassing serialized pixel setup. Focused B bidirectional replay passes 7,680 samples in 4,040,029 cycles, B-intra passes 768 samples in 2,436,868 cycles, and the exact 25-picture live soak passes all 291,641 bytes, 22 P pictures, 47 B pictures, 71 swaps, 622,811 DDR reads, cache counts 2,267,813/463,835/158,976, and zero errors in 17,469,996 cycles. The user-requested clean rebuild reproduced the original unsafe revision's decoder setup failure at -7.765 ns, proving it was not stale incremental state; successive registered cuts removed the response, direction, and coordinate arithmetic from the cache cone, and the final session-authorized incremental Quartus build closes with +0.001 ns decoder setup, +0.350 ns decoder hold, +14.765 ns decoder recovery, and +6.795 ns video setup. The fit uses 30,512 ALMs, 43,228 registers, 4,027,379 block-memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Qualified artifact `MediaPlayer_commit232_1b1ca8f.rbf` is 4,264,692 bytes with SHA-256 `2eb655010376059befdcdadd290f7d9bd6830197f02e567d51999346ad32f38d`; the uploaded MiSTer readback matches byte-for-byte.

#### Next Steps:

Reload the deployed core and run `test_compat_long_gop.m2v`, recording whether it reaches final frame 71, the frame-0-to-frame-71 load time, visible ordering or stutter, and the settled USER, POWER, and DISK LED pattern. Then run `test_compat_mixed_macroblocks.m2v` as a corruption regression; hardware acceptance requires no new visual errors and the established passing LEDs.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 233 COMMIT Unreleased 4e6130c 2026-08-19T02:49:58-07:00

#### Coming From:

Unreleased 1b1ca8f

#### Purpose:

Retire each reconstructed P/B block at the writer's accepted-write completion barrier instead of issuing eight serialized uncached DDR readbacks that do not feed prediction or presentation.

#### Outcome:

Entry 232 is fully hardware accepted: the long-GOP stream reaches source frame 71 in 7.111 seconds with monotonic presentation, USER and POWER solid, and DISK stage 11, while the mixed-macroblock stream reaches source frame 23 in 2.459 seconds with coherent features, sequential frames, USER and POWER solid, and DISK off. Commit `4e6130c` retires reconstructed P/B blocks when the writer confirms that all eight DDR row writes were accepted, removing a destination readback that neither feeds prediction nor changes presentation. The focused P-intra, B-residual, and B-intra replays remain exact in 2,301,492, 3,910,429, and 2,307,268 cycles. The exact 72-picture live soak preserves all 291,641 bytes, 22 P pictures, 47 B pictures, 71 swaps, 50,688 reference writes, 55,296 and 52,992 scratch writes, final display identity 25, cache hits and misses of 2,267,813 and 463,835, and zero errors while uncached reads fall from 158,976 to zero, physical DDR reads fall from 622,811 to 463,835, and cycles fall from 17,469,996 to 16,679,996. The full 791,528-byte long-GOP regression passes all pictures, publications, promotions, ownership checks, and presentation checks. The session-authorized incremental Quartus build completes in 9 minutes 13 seconds with zero errors, +0.517 ns global setup, +0.252 ns global hold, +0.546 ns decoder setup, +12.502 ns decoder recovery, and +7.532 ns video setup. The fit uses 29,835 ALMs, 42,407 registers, 4,027,379 block-memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Qualified artifact `MediaPlayer_commit233_4e6130c.rbf` is 4,261,064 bytes with SHA-256 `01f617839ce1997200d3816b645ff7ce2f62b0000017cef69489cdcb518e42d4`; the uploaded MiSTer readback matches byte-for-byte.

#### Next Steps:

Reload the deployed core and run `test_compat_long_gop.m2v`, recording the frame-0-to-frame-71 elapsed time, whether presentation remains sequential and visibly coherent, and the settled USER, POWER, and DISK state. Then run `test_compat_mixed_macroblocks.m2v` and confirm final frame 23, coherent features without load-time flicker or partial blocks, USER and POWER solid, and DISK off; hardware acceptance requires no regression and should determine how much removing 4,471,200 full-resolution readbacks improves the remaining loading bottleneck.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 234 COMMIT Unreleased c340da8 2026-08-19T03:57:29-07:00

#### Coming From:

Unreleased 4e6130c

#### Purpose:

Stream each completed inverse-quantised coefficient directly into IDCT capture to remove the serialized 64-cycle coefficient replay from every transformed P/B block.

#### Outcome:

Entry 233 is hardware accepted: the 60 fps recordings show every long-GOP source frame from 0 through 71 and every mixed-macroblock frame from 0 through 23 in monotonic order without partial-block corruption, with the expected passing LEDs. Frame-zero-to-final intervals fall from 7.111 to 5.986 seconds for long GOP and from 2.459 to 2.144 seconds for mixed macroblocks, reductions of 15.8 and 12.8 percent. Profiling the exact soak attributes 15,472,059 input-blocked cycles to the decoder and identifies a duplicate 64-cycle coefficient replay in every transformed block. Commit `c340da8` drives IDCT start, coefficient, and end capture directly from inverse-quantisation completion, removes the private 64-coefficient replay array, and preserves scan order, mismatch control, quantisation, IDCT arithmetic, and the existing shared multiplier and IDCT resources. Exact P-intra, B-residual, and B-intra regressions preserve every event, sample, write, and reconstructed value in 2,301,108, 3,902,749, and 2,306,500 cycles, exactly 64 cycles faster per transformed block. The 72-picture live soak retains all 291,641 bytes, 22 P pictures, 47 B pictures, 71 swaps, final identity 25, 463,835 physical DDR reads, cache counts 2,267,813/463,835/0, and zero errors in 15,739,996 cycles, a 940,000-cycle or 5.64 percent reduction. The eight-refill parser-window test and complete 791,528-byte long-GOP publication regression pass unchanged. The session-authorized incremental Quartus build completes in 9 minutes 5 seconds with zero errors, +0.433 ns global setup, +0.250 ns global hold, +0.687 ns decoder setup, +15.505 ns decoder recovery, and +7.357 ns video setup. The fit uses 29,203 ALMs, 40,967 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Qualified artifact `MediaPlayer_commit234_c340da8.rbf` is 4,261,000 bytes with SHA-256 `af041d0ca68a9540dee1d8f05f1c7335bf42c5353940d47cb2a2304bd05ec5f5`; the uploaded MiSTer readback matches byte-for-byte.

#### Next Steps:

Reload the deployed core and record `test_compat_long_gop.m2v` at 60 fps from the first fully visible frame 0 through settled frame 71, reporting the elapsed interval and USER, POWER, and DISK state. Then record `test_compat_mixed_macroblocks.m2v` through settled frame 23 and report the same LEDs; hardware acceptance requires sequential coherent presentation without renewed partial-block flicker and should measure how closely the 5.64 percent modeled transform reduction carries into the remaining hardware bottleneck.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 235 COMMIT Unreleased 6583c66 2026-08-19T05:02:36-07:00

#### Coming From:

Unreleased c340da8

#### Purpose:

Expand the shared P/B reference-word cache from four fully associative entries to eight timing-safe two-way set-associative entries without changing registered lookup timing or decoded pixels.

#### Outcome:

Entry 234 is hardware accepted: the 60 fps recordings show coherent sequential presentation through long-GOP frame 71 in 5.935 seconds and mixed-macroblock frame 23 in 2.093 seconds, with USER and POWER solid, DISK dark, and no partial-block flicker. Commit `032d08c` implemented an eight-entry fully associative cache and preserved all functional regressions while reducing exact-soak misses from 463,835 to 372,220 and cycles from 15,739,996 to 15,249,996, but its eight-way comparison cone failed decoder setup at -0.463 ns and was not deployed. Commit `6583c66` reorganizes those eight words as four two-way sets indexed by the low DDR word-address bits, adds per-set replacement, and retains the registered lookup and single-outstanding transaction contracts. The focused cache, P-intra, B-residual, B-intra, parser-window, exact live-raster, and complete long-GOP publication regressions all pass; the exact soak preserves every pixel-side and presentation result while reducing misses and DDR reads to 410,546 and cycles to 15,479,996, improvements of 11.49 and 1.65 percent over Entry 234. The user-requested clean Quartus build completed in 9 minutes 58 seconds with 0 errors and 124 warnings, using 29,583 ALMs, 41,706 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Global setup and hold slack are +0.362 and +0.261 ns; focused decoder setup, decoder recovery, and video setup are +0.793, +13.004, and +8.619 ns with zero violations. The 4,247,012-byte RBF has SHA-256 `2e453d6f21425ff0339e4fa3d43d503d051fceb3cdf36e41dad93e3f8db88279`.

#### Next Steps:

Deploy the hash-qualified Entry 235 RBF and rerun `test_compat_long_gop.m2v` and `test_compat_mixed_macroblocks.m2v`; accept only coherent sequential presentation through final frames 71 and 23, no partial-macroblock flicker, the established POWER and USER pass state with DISK dark after completion, and compare measured load intervals against Entry 234's 5.935- and 2.093-second baselines.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 236 COMMIT Unreleased f206298 2026-08-19T13:36:19-07:00

#### Coming From:

Unreleased 6583c66

#### Purpose:

Restore the hardware-proven four-entry reference cache and add mixed-stream pixel-content coverage after Entry 235 corrupted the mixed-macroblock display despite passing control-path diagnostics.

#### Outcome:

Hardware rejects Entry 235 as a compatibility regression: its long-GOP gain is only 76 ms or 1.28 percent while the byte-identical mixed-macroblock stream displays a repeated diagonal field and a second download never presents a new frame. Commit `f206298` restores Entry 234's exact four-entry fully associative cache and adds a deterministic 128x96, 24-picture mixed I/P/B stream containing intra macroblocks in P pictures plus an FFmpeg-decoded YUV420P oracle. The new integrated regression seeds the omitted I-writer reference model, reconstructs 423,936 P/B samples through the real parser, prediction engines, cache, tagged writer, DDR model, and scheduler, and passes every sample within a maximum MPEG IDCT delta of two; it also locks 499,551 cache hits, 71,329 misses and DDR reads, and 3,109,996 cycles. Focused cache, P-intra, B-residual, B-intra, parser-window, exact 72-picture live-raster, and full-resolution 791,528-byte long-GOP publication regressions all pass; the live soak exactly restores 2,267,813 hits, 463,835 misses and reads, 15,739,996 cycles, all 72 display identities, and zero errors. The incremental Quartus 17.0.2 build completes in 9 minutes 14 seconds with zero errors, 124 standing warnings, no critical warning, global setup and hold slack of +0.433 and +0.250 ns, focused decoder setup and recovery slack of +0.687 and +15.505 ns, video setup slack of +7.357 ns, 29,203 ALMs, 40,967 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer.rbf` is 4,261,000 bytes with SHA-256 `af041d0ca68a9540dee1d8f05f1c7335bf42c5353940d47cb2a2304bd05ec5f5`; its MiSTer FTP readback is byte-identical. Replacement first-load hardware captures supersede the invalid earlier recordings and fully accept the recovery. The mixed-macroblock capture reaches timestamp `00:00:00.920`, frame `23`, with the intended bars, checkerboard, dots, and moving features coherent and stable, USER and POWER solid, and DISK off. The long-GOP capture reaches timestamp `00:00:02.840`, frame `71`, with a coherent settled raster and no repeated diagonal-field corruption, USER and POWER solid, and DISK stage eleven.

#### Next Steps:

Preserve the hardware-accepted four-entry cache and pixel oracle, then add `ioctl_download`-driven decoder rearming as the next separate boundary so repeated downloads reliably start a new decode without coupling that lifecycle change to the recovered first-load datapath.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- tools/streams/generate_test_mixed_raster_soak.py
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv

#### Status:

- [x] Built
- [x] Passed

---
## 237 COMMIT Unreleased 23d8410 2026-08-19T15:21:10-07:00

#### Coming From:

Unreleased f206298

#### Purpose:

Rearm all MPEG-domain decode, publication, presentation, framebuffer-cache, and diagnostic state at the start of each new HPS file download without disturbing the accepted first-load datapath.

#### Outcome:

Commit `23d8410` synchronizes the asynchronous `ioctl_download` level into `clk_mpeg2`, detects each low-to-high transfer boundary, stretches it across exactly eight decoder clock edges, resets every existing MPEG-domain consumer through the common reset net, and blocks FIFO reads throughout that boundary so the first new byte cannot be discarded. The system-reset synchronizers, dual-clock FIFO reset, video domain, accepted four-entry cache, pixel reconstruction, and DDR layout remain unchanged. The focused asynchronous-clock regression passes two independent downloads, sixteen total reset edges, sustained-level non-retrigger, clean release, and complete FIFO gating. Cache, P-intra, B-residual, B-intra, eight-refill parser-window, mixed-pixel, 72-picture live-raster, and full-resolution long-GOP regressions all pass; the mixed oracle retains 423,936 samples with zero mismatches and maximum delta two, the live soak retains 2,267,813 hits, 463,835 misses and reads, 15,739,996 cycles and all 72 identities, and the long run retains 22 P pictures, 47 B pictures, 25 publications and promotions, final identity 25, and zero errors.

#### Next Steps:

Run the session-authorized incremental Quartus build from the preserved database, verify timing and resource reports, deploy the resulting RBF with byte-identical readback, then validate both compatibility streams on a first load followed immediately by a second load without reloading the core.

#### Files Modified:

- MediaPlayer_top_00.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_download_rearm.sv
- tools/streams/tb_h262_download_rearm.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 238 COMMIT Unreleased ca1f0fc 2026-08-19T15:44:38-07:00

#### Coming From:

Unreleased 23d8410

#### Purpose:

Close the download-rearm implementation's intentional clock-domain and asynchronous framebuffer-reset boundaries without placing the rearm controller itself on an asynchronous reset path.

#### Outcome:

The first incremental build of `23d8410` functionally compiles but is ineligible for deployment with `-1.507 ns` setup slack and `-3.338 ns` recovery slack. Detailed TimeQuest analysis identifies the only setup violation as the intentional `clk_sys` `ioctl_download` crossing into the first `clk_mpeg2` synchronizer stage, while the recovery violations come from feeding the asynchronous top-level reset request into every register of the new controller and from the rearm output's intentional asynchronous assertion into the framebuffer read-domain reset synchronizer. Commit `ca1f0fc` resets the controller synchronously from the already synchronized MPEG reset and adds narrowly scoped exceptions only for the source-to-stage-zero download crossing and controller-to-framebuffer read-reset assertion boundary; ordinary same-clock logic, synchronizer release, and all later stages remain timed. The focused asynchronous-clock regression still passes two downloads, sixteen reset edges, sustained-level non-retrigger, and complete FIFO gating. The second incremental Quartus 17.0.2 build completes in 9 minutes 14 seconds with zero errors, 124 standing warnings, no critical warning, global setup, hold, and recovery slack of +0.285, +0.253, and +3.158 ns, decoder setup and recovery slack of +0.423 and +14.019 ns, and video setup slack of +7.004 ns. The fit uses 29,263 ALMs, 40,917 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. The 4,234,588-byte `MediaPlayer_commit238_ca1f0fc.rbf` has SHA-256 `af4992a7b4a1156661162273c01475413a222ad311a147849700cdb2eda364de`; its MiSTer FTP readback is byte-identical. Hardware accepts the completed boundary: both `test_compat_long_gop.m2v` and `test_compat_mixed_macroblocks.m2v` play correctly on their first and consecutive second loads without reloading the core, and every run visibly updates rather than retaining the prior frame. Both files report USER and POWER solid with DISK off; the long-GOP DISK result differs from the pre-test stage-eleven expectation but accompanies correct completion and no stale-screen, decode, or presentation failure.

#### Next Steps:

Continue from hardware-accepted commit `ca1f0fc`, preserving the download-rearm controller, timing exceptions, four-entry reference cache, and mixed-pixel oracle while selecting the next compatibility or performance boundary under the proposal-first workflow.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- rtl/mpeg2_new/mpeg2_h262_download_rearm.sv

#### Status:

- [x] Built
- [x] Passed

---
## 239 COMMIT Unreleased 3c03570 2026-08-19T16:36:30-07:00

#### Coming From:

Unreleased ca1f0fc

#### Purpose:

Reduce the remaining 25 fps starvation stutter by overlapping registered P/B pixel output with the next prediction lookup and establish repeatable counter-plus-raster recording analysis.

#### Outcome:

The accepted Entry 238 recordings provide a clean baseline: independent matching of the embedded frame counter and unobscured raster recovers every long-GOP frame 0 through 71 and mixed-macroblock frame 0 through 23 in strict order, with no sustained counter-only update, skipped image, stale buffer, or partial-frame failure. Long GOP takes 5.939 seconds from first frame 0 to first frame 71, or 11.95 effective fps, while mixed macroblocks takes 2.102 seconds from frame 0 to frame 23, or 10.94 effective fps; B pictures ordinarily persist for three or four 59.94 fps camera samples, but I/P reference pictures persist for eight through ten, proving repeatable reference-hold starvation. Commit `3c03570` adds a deterministic two-track analyzer and retains the registered four-entry cache while latching reconstructed pixel value, coordinates, and block markers into the writer stage; a registered following-pixel address may launch during the current final cache or DDR response, so state advances behind the stable output without exposing the former failing combinational four-way cache data path. Cache-hit focused replay preserves exact P and B pixels while reducing P from 1,791,186 to 755,154 cycles, or 57.84 percent, and B from 3,392,449 to 1,318,849 cycles, or 61.12 percent. The complete 24-picture mixed oracle retains 423,936 samples, zero mismatches, maximum delta two, 499,551 hits, 71,329 misses and reads, and all 24 display identities while falling from 3,109,996 to 2,679,996 cycles, or 13.83 percent. The exact 72-picture soak retains 2,267,813 hits, 463,835 misses and reads, 22 P pictures, 47 B pictures, 25 publications, final identity 25, and zero errors while falling from 15,739,996 to 14,499,996 cycles, or 7.88 percent. Cache accounting, P intra, B residual, B intra, eight-refill parser-window, repeated-download rearm, and full-resolution 791,528-byte long-GOP publication regressions also pass. The session-authorized incremental Quartus 17.0.2 build completes in 9 minutes 28 seconds with zero errors, 124 standing warnings, no critical warning, global setup, hold, and recovery slack of +0.152, +0.252, and +3.862 ns, focused decoder setup and recovery slack of +0.475 and +14.510 ns, and video setup slack of +7.604 ns. The fit uses 29,307 ALMs, 40,943 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. The 4,228,160-byte `MediaPlayer_commit239_3c03570.rbf` has SHA-256 `c780cb66d92832c0e22a1b3ec110993fb98212e30eb76e7814d50cf34cec0419`; FTP upload to the standard MiSTer and readback are byte-identical. Hardware acceptance passes all requested tests, including consecutive reload behavior. The recalibrated 59.94 fps recording analysis recovers every frame in strict unit-step order on both the counter and independent raster tracks: long GOP is 0 through 71 and mixed macroblocks is 0 through 23, with no missing raster identity. Long GOP falls from 5.939 to 5.055 seconds, a 14.89 percent reduction, and rises from 11.95 to 14.05 effective fps; its mean interior hold falls from 4.97 to 4.24 camera samples, while median I, P, and B holds change from 8.5, 8, and 3 samples to 7, 7, and 3. Mixed macroblocks falls from 2.102 to 1.952 seconds, a 7.14 percent reduction, and rises from 10.94 to 11.78 effective fps; its mean interior hold falls from 5.27 to 4.91 samples, while median I, P, and B holds change from 10, 8, and 3 samples to 7, 8, and 3. The recordings therefore validate the optimization and rule out skipped-counter, stale-buffer, or missing-picture explanations, but they also confirm visible starvation remains: reference pictures still persist for approximately seven or eight camera samples while B pictures ordinarily persist for three.

#### Next Steps:

Retain the hardware-accepted registered output overlap and target the remaining asymmetric reference-picture latency. Profile P-picture and I-picture completion separately from B-picture completion, preserving strict display order, minimum presentation lifetime, reload behavior, all frame identities, and the accepted LED result; use the measured seven-to-eight-sample P/I holds versus three-sample B holds to select the next proposal rather than changing the cadence gate.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/analyze_recorded_cadence.py
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---
## 240 COMMIT Unreleased c667f2c 2026-08-19T18:05:31-07:00

#### Coming From:

Unreleased 3c03570

#### Purpose:

Pipeline non-intra inverse-quantisation issue and retirement so each registered product can enter IDCT capture while the following coefficient product is launched.

#### Outcome:

Entry 239 is hardware accepted with every long-GOP and mixed-macroblock frame present in strict order, while profiling its unchanged 14,499,996-cycle exact soak attributes 13,296,807 cycles to decoder backpressure and shows that longer visible P holds come from coded-order reference-plus-first-B dependency rather than a slower P raster engine. Commit `c667f2c` pre-registers the following scan address and retires each current non-intra inverse-quantisation product into IDCT while launching the next product, preserving the two-cycle intra path, mismatch parity, saturation, scan order, and arithmetic; it also separates first-word B metadata detection from registered B cache ownership so geometry qualification cannot enter the shared cache-to-prelaunch timing cone. P-intra latency remains exactly 1,791,186 cycles, B residual replay falls by exactly 7,560 cycles to 3,384,889, the complete mixed oracle retains 423,936 samples with zero mismatches and maximum delta two while falling from 2,679,996 to 2,529,996 cycles, and the exact 72-picture soak retains all 22 P pictures, 47 B pictures, 25 display identities, 71 swaps, cache and DDR counts, and zero errors while falling to 13,599,996 cycles, a 6.21 percent reduction. Parser windows, repeated-download rearm, B-intra, cache-hit, and the complete 791,528-byte publication regression also pass. An initial incremental build exposed a setup violation, and the user-requested clean rebuild reproduced it at -0.207 ns; the registered ownership cut removes that path, after which the normal incremental Quartus 17.0.2 build completes in 9 minutes 8 seconds with zero errors, 124 standing warnings, no critical warning, and global setup, hold, recovery, and removal slack of +0.195, +0.243, +2.951, and +0.619 ns. The fit uses 29,336 ALMs, 40,715 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. Qualified artifact `MediaPlayer_commit240_c667f2c.rbf` is 4,233,504 bytes with SHA-256 `17915fc7b2b2a35c957332abc4ea43516ef7e4286ac4b715445291e41ce021c0`; its deployed MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload the deployed core and record both `test_compat_long_gop.m2v` and `test_compat_mixed_macroblocks.m2v` at nominal 60 fps on a first load and an immediate consecutive second load without reloading the core. For each stream, report the final visible frame, settled USER, POWER, and DISK states, any corruption or stale-screen behavior, and the frame-zero-to-final interval; upload the recordings so counter and independent raster cadence can be compared with Entry 239's 5.055-second long-GOP and 1.952-second mixed-macroblock baselines.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 241 COMMIT Unreleased c667f2c 2026-08-19T19:59:35-07:00

#### Coming From:

Unreleased c667f2c

#### Purpose:

Record the MiSTer cadence and raster result of the pipelined non-intra inverse-quantisation build.

#### Outcome:

The user reports unchanged passing LED behavior and no visible screen regression on the deployed `c667f2c` RBF. Recalibrated analysis of the new nominal-60 fps recordings recovers all 72 long-GOP pictures and all 24 mixed-macroblock pictures in strict unit-step order. Long GOP advances from first frame 0 to first frame 71 in 4.977 seconds, or 14.27 effective fps, with camera holds ranging from two through nine samples; this is 1.55 percent faster than Entry 239's 5.055-second baseline. Mixed macroblocks advances from first frame 0 to first frame 23 in 1.817 seconds, or 12.66 effective fps, with holds ranging from two through nine samples; this is 6.93 percent faster than Entry 239's 1.952-second baseline. Independent temporal comparison finds a visible raster change for every one of the 71 and 23 logical counter transitions within the 60 fps camera's two-sample ambiguity, ruling out missing pictures, counter-only advancement, and a stale displayed buffer. The inverse-quantisation optimization is therefore hardware accepted and measurably improves throughput, while the remaining two-to-nine-sample hold variation explains why the presentation still looks stuttery.

#### Next Steps:

Continue from hardware-accepted commit `c667f2c`, preserve strict counter and raster identity plus reload behavior, and use the remaining two-to-nine-sample hold distribution to profile the next dominant decoder-backpressure stage before proposing another throughput optimization rather than changing the presentation cadence gate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

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
