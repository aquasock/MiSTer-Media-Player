---
## 256 COMMIT Unreleased ??? 2026-08-20T05:19:52-07:00

#### Coming From:

Unreleased 0f5baad

#### Purpose:

Remove the synthesis-discovered cache-to-arbiter combinational handshake loop without reducing Entry 255's two-command capacity or changing response order.

#### Outcome:

Entry 255 passes every focused, exact-pixel and long-order simulation, but the first clean Quartus elaboration reports a six-node combinational loop from the reference probe request through prediction busy and back to that request. The build was interrupted before fitting completed and no RBF was produced or deployed. The loop is confined to ready/valid expression: cache busy currently depends on request assertion and arbiter prediction busy depends on prediction request assertion, so the newly transparent command boundary lets valid and ready depend on one another even though all stored descriptors remain clocked.

#### Next Steps:

Express cache readiness only from descriptor capacity, hit state and downstream backpressure, and express reader/prediction arbiter readiness only from descriptor capacity, display priority and DDR backpressure; qualify acceptance separately with each request. Extend focused tests to require useful busy readiness before request assertion, rerun exact mixed latency and ordered long coverage, commit the correction, and restart a fully clean Quartus build requiring zero combinational loops and positive timing before deployment.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_ddram_arbiter.sv

#### Status:

- [ ] Built
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
## 229 COMMIT Unreleased 6a4e935 2026-08-18T15:58:14-07:00

#### Coming From:

Unreleased cd73cb7

#### Purpose:

Remove the registered cache-hit handshake from generalized P/B prediction so resident reference words can advance the raster engines directly without changing the miss path, pixels, or display order.

#### Outcome:

Entry 228 hardware is functionally clean but remains throughput-limited: `test_compat_long_gop.m2v` reaches source frame 71 in approximately 9.9 seconds with USER and POWER solid, while DISK code 11 confirms the deepest successful final-GOP boundary rather than an error. Commit `a16947a` first exposed a combinational cache-hit path and reduced the exact 72-picture live-raster soak from 25,249,996 to 19,449,996 cycles, but its -5.112 ns decoder setup slack made it ineligible for deployment. Commit `6a4e935` replaces that path with timing-safe registered lookup responses while presenting each successive half-pel tap during the preceding response. The focused cache test passes three hits, nine misses, two uncached accesses, and eleven downstream transactions; the B-residual and P-intra engine regressions remain exact. The integrated soak reconstructs and presents all 72 pictures with 622,811 DDR reads, 2,267,813 cache hits, 463,835 misses, 158,976 uncached accesses, final source-frame identity 71, and zero decoder, reconstruction, or presentation errors in 21,249,996 cycles, a 15.84 percent reduction from Entry 228. The session-authorized incremental Quartus 17.0.2 compile completes in 9 minutes 36 seconds with 0 errors and 121 standing warnings; global setup/hold slack is +0.323/+0.253 ns, focused decoder/video setup slack is +1.545/+8.686 ns, decoder recovery slack is +14.665 ns, and utilization is 30,259 ALMs, 43,273 registers, 4,027,379 memory bits, and 65 DSP blocks. `MediaPlayer_commit229_6a4e935.rbf` is 4,262,892 bytes with SHA-256 `aec392b4a8e5e4284039e8eff449d7d012c398fd67f8b8fc903f27a0476aabeb`; its MiSTer FTP readback is byte-identical. Hardware acceptance retains USER and POWER solid, DISK stage 11, and final source frame 71; the uploaded 30 fps recording measures approximately 8.4 seconds from first frame 0 to first frame 71, confirming the predicted performance gain. It also exposes a separate presentation-cadence defect: 0.1-second samples near completion show 63, 64, 65, 65, 66, 68, 68, 69, 69, 71, proving that some pictures persist for multiple samples while intermediate pictures 67 and 70 are visible for less than one camera interval.

#### Next Steps:

Retain the verified cache gain and treat decode throughput and display cadence as separate boundaries. Before another throughput change, add focused timestamped observation of picture completion, scratch readiness, future-reference readiness, and framebuffer swaps; then use it to pace already-decoded pictures so no B picture is exposed for only one video refresh, without weakening display order or adding compressed-stream backpressure. The decoder remains approximately 8.5 fps, so true 25 fps playback will still require further reconstruction throughput after the burst-and-hold presentation defect is isolated.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv

#### Status:

- [x] Built
- [x] Passed

---
## 230 COMMIT Unreleased 1177e26 2026-08-18T17:10:35-07:00

#### Coming From:

Unreleased 6a4e935

#### Purpose:

Pace accepted 25 fps picture presentation against the fixed 800x600 display refresh so no decoded B picture is exposed for only one video frame.

#### Outcome:

The Entry 229 hardware recording confirmed both the cache gain and a separate burst-and-hold presentation defect: source frames 0 through 71 completed in approximately 8.4 seconds rather than 9.9 seconds, while 0.1-second samples near completion showed 63, 64, 65, 65, 66, 68, 68, 69, 69, 71. Commit 1177e26 adds a saturating rational cadence credit for frame-rate code 3 only, using the fixed 40 MHz, 1056-by-628 display timing to pace distinct ordinary, B-scratch, and future-reference swaps at 25 fps; starvation saturates at one pending slot so late readiness cannot cause catch-up bursts, while non-25-fps behavior remains immediate. The focused scheduler regression passed scratch-zero, scratch-one, and future-reference order with cadence intervals 1, 3, and 2, starvation saturation, publication-race barriers, ordinary and terminal release, and fail-open recovery. The exact DDR-backed 72-picture live-raster soak passed in 21,729,996 cycles versus Entry 229's 21,249,996 cycles, a 480,000-cycle or 2.26 percent modeled pacing cost, with 71 swaps, final P temporal reference 23, unchanged cache and DDR traffic counts, and no read, reconstruction, presentation, or ownership error. The full 720-by-480 long-GOP regression passed all 72 pictures, 25 publications and promotions, 47 B pictures, 25 display identities, and zero destination holds, overwrites, or presentation errors. The session-authorized incremental Quartus build completed in 9 minutes 26 seconds with zero errors, 121 standing warnings, no critical warning, +0.155 ns worst setup slack, +0.257 ns worst hold slack, +1.336 ns decoder-clock setup slack, +8.827 ns video-clock setup slack, and +14.821 ns decoder recovery slack. Utilization is 30,331 ALMs, 43,402 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and three PLLs. The 4,251,284-byte MediaPlayer_commit230_1177e26.rbf artifact has SHA-256 1cc79ae363145746fb3d94460f767b104777e82ab1e8adcbf84a4aac580be7e0; FTP upload and MiSTer readback produced the same digest. The deployed hardware recording reaches frame 71 without a crash and is visibly smoother; the user reports that every frame now appears to be produced. Thirty-frame-per-second contact sheets place the first visible frame 0 at approximately 0.73 seconds and the first frame 71 at approximately 9.93 seconds, or about 9.2 seconds for the 2.84-second source sequence. Ten-frame-per-second samples progress monotonically and show that the remaining visible stutter consists of decoder-starvation holds rather than the former one-refresh presentation flashes: effective delivered-picture throughput is approximately 7.7 fps, well below the encoded 25 fps rate. Hardware acceptance passes with USER and POWER solid and 11 DISK blinks, matching the expected frame-71 success signature.

#### Next Steps:

Retain the accepted cadence gate and treat the remaining stutter as decoder throughput work. Profile the exact DDR-backed soak by read, reconstruction, cache-refill, and presentation idle intervals before proposing the next optimization, while preserving all 72 pictures, the passing LED signature, and the new minimum display lifetime.

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
## 203 COMMIT Unreleased e3036ac 2026-08-18T01:52:05-07:00

#### Coming From:

Unreleased 104965c

#### Purpose:

Replace the generalized B path's 16-block and 64-coefficient residual-plan limits with RAM-backed block transactions and a sparse-sample store shared across mutually exclusive P and B reconstruction.

#### Outcome:

Commit `104965c` is hardware accepted: `test_p_residual_streaming.m2v` displays the authored vertical stripe from rows 5 through 24 at column 20 with a coherent raster, USER and POWER solid, and DISK off. Commit `e3036ac` replaces the B parser's 16-block and 64-coefficient arrays with synchronous M10K stores for 2,048 block descriptors and 32,768 coefficient events, transforms and replays one block at a time, moves the B raster descriptors into M10K RAM, and lets mutually exclusive P/B reconstruction share one 2,048-block sparse spatial-sample store. The deterministic 182,849-byte B streaming regression reports exactly 1,350 motion records, 120 residual blocks, 7,680 spatial samples and RAM writes, and a complete 518,400-sample raster in which exactly the 7,680 stripe samples change; parser, transform, raster, ordering, and persistence checks remain clear. The original P intra and 120-block P streaming tests, parser-window and restricted-slice replays, prediction-source diagnostic, all seven standing generators, and their software references remain clean. The ordinary 366,067-byte compatibility corpus now completes its first B picture with 817 residual blocks and 17,244 coefficient events and no P or B error, exceeding the former limits by more than 50 and 269 times respectively. The clean Quartus 17.0.2 build completes in 9 minutes 15 seconds with zero setup and hold TNS, no Critical Warning, +0.515 ns global setup, +0.251 ns global hold, +1.065 ns decoder setup, 29,142 ALMs, 41,855 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `b8695a036e4871b9aecdb7587ba603d18821e23dffb2bf17fed9eddf697cb3a7`; stream `test_b_residual_streaming.m2v` has SHA-256 `d9ee48a2d34f5054cb6754b892633a1789f892a6bc71b3119470d312d82e8aed`.

#### Next Steps:

Install the Commit-203 RBF and run `test_b_residual_streaming.m2v` on MiSTer through one complete 32-second diagnostic frame, recording whether USER, POWER, and DISK are solid, dark, or blinking and confirming a coherent vertical stripe at column 20 from rows 5 through 24. Clean acceptance is solid USER, solid POWER, and dark DISK.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_b_residual_streaming.py
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 204 COMMIT Unreleased 7256a7f 2026-08-18T02:34:46-07:00

#### Coming From:

Unreleased e3036ac

#### Purpose:

Replace picture-wide P/B residual accumulation with row-bounded parse, transform, and reconstruction transactions that admit dense ordinary coefficient traffic without increasing FPGA RAM capacity.

#### Outcome:

Commit `e3036ac` is hardware accepted: `test_b_residual_streaming.m2v` briefly displays its B-only vertical stripe, then correctly presents the following plain P reference, with USER and POWER solid and DISK off; software decode confirms display order I/B/P, identical I and P hashes, and a distinct B frame. Commits `00d4229` and `7256a7f` add explicit row-ready and row-retired handshakes across the active P/B parsers, transforms, raster engines, reference wrapper, and publication shell, holding input until each row is reconstructed and persisted before reusing descriptor, coefficient, and shared spatial-sample addresses. The 2,875,981-byte dense corpus now completes its first P picture with 8,100 blocks and 175,586 coefficients and its first B picture with 8,073 blocks and 182,707 coefficients; each path emits 1,350 ordered motion records across 30 transactions, while the largest P row uses 270 blocks and 6,017 coefficients and the largest B row uses 270 blocks and 7,441 coefficients. The existing 120-block P and B full-raster regressions, parser-window and restricted-slice replays, prediction-source diagnostics, active hierarchy elaboration, and the first ordinary mixed-corpus B picture remain clean. The clean Quartus 17.0.2 build completes in 9 minutes 21 seconds with zero setup and hold TNS, no Critical Warning, +0.126 ns global setup, +0.250 ns global hold, +1.397 ns decoder setup, 29,087 ALMs, 42,000 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `15e53c93517a1227671fd2f8d24673858f78b80ae902b1a9e68637afaa39730f`.

#### Next Steps:

Install the Commit-204 RBF and run `test_compat_dense_residual.m2v`, `test_p_residual_streaming.m2v`, and `test_b_residual_streaming.m2v` on MiSTer through complete settled diagnostic reports. Each stream must finish with USER and POWER solid and DISK dark; the dense stream must remain coherent through its P/B sequence, the P stripe must remain stable, and the B stripe must appear only during the B display interval before the following plain P reference.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv
- tools/streams/tb_h262_row_streaming.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 205 COMMIT Unreleased c9636a7 2026-08-18T03:26:00-07:00

#### Coming From:

Unreleased 7256a7f

#### Purpose:

Guarantee that any B parser or reconstruction failure aborts the in-flight B transaction and releases compressed-stream backpressure.

#### Outcome:

Commit `7256a7f` is not hardware accepted: `test_compat_dense_residual.m2v` displays its coherent dense I/P raster but leaves the MiSTer file-transfer overlay permanently active with all diagnostic LEDs dark. Commit `c9636a7` makes sticky B parser/replay failure abort only the live B transaction and suppress its persistence wait, preserving the error for diagnostics while allowing the HPS byte path to drain. The focused transport regression holds B failure asserted and accepts all 4,102 bytes with zero post-abort stalls, while the separate full-corpus reproducer identifies the first deterministic dense failure at byte 818,622, slice row 9, and proves the parser itself releases `parse_hold`; the existing first dense B full-raster replay remains clear across 1,350 macroblocks, 8,073 residual blocks, 516,672 residual samples, and 518,400 stored samples.

#### Next Steps:

Correct the second and later B-picture parser/lifecycle behavior, require the complete dense `IPBBPBBPBBPB` coded sequence to finish without parser, replay, reconstruction, publication, presentation, or transport errors, then run a clean Quartus build for the combined recovery commits.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_dense_transport_recovery.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 206 COMMIT Unreleased 2dd4c67 2026-08-18T04:27:00-07:00

#### Coming From:

Unreleased c9636a7

#### Purpose:

Correct repeated-B parsing and transaction lifecycle so every picture in the dense `IPBBPBBPBBPB` corpus completes without error or transport stall.

#### Outcome:

Commit `c9636a7` guarantees fail-open transport after the former second-B fault. Commits `10d88d0` and `2dd4c67` complete the repeated-B correction: a rightmost macroblock now enters zero-stuffing state, a stuffing-only refill tail may terminate with fewer than three buffered bytes, raw compatibility streams receive an explicit sequence end, and every accepted picture header produces its own presentation event even when adjacent coding types are both B. Two independent non-reference scratch frames preserve consecutive B display order before the retained future reference, while decoder or ownership failure aborts presentation backpressure. The full 2,875,985-byte dense parser/transform replay completes all seven B pictures, 210 row transactions, 9,450 motion records, 52,846 residual blocks, 1,539,306 coefficient events, and 3,382,144 spatial samples without error. Focused regressions also prove 4,102 accepted transport bytes with zero post-abort stalls, scratch0/scratch1/future presentation order plus fail-open recovery, all six scratch-bank/plane tag mappings, and the established 518,400-sample B residual raster.

The final clean Quartus 17.0.2 build completes in 9 minutes 14 seconds with zero setup, hold, or recovery TNS, no Critical Warning, +0.496 ns global setup, +0.245 ns global hold, +3.411 ns global recovery, +1.666 ns focused decoder setup, and +14.384 ns focused decoder recovery. It uses 28,935 ALMs, 41,815 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `c681b82a672dc7c21eff38bfd69244510481cef7cfc6bc0cb9f3dc2647cef56e`; regenerated stream `test_compat_dense_residual.m2v` has SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e`. Both files were uploaded to the standard MiSTer at `10.10.0.30` and read back with matching hashes.

#### Next Steps:

Run `test_compat_dense_residual.m2v` through its complete sequence on MiSTer. Confirm the raster remains coherent through every P/B interval, the file-transfer overlay retires instead of freezing, and the terminal LEDs are solid USER, solid POWER, and dark DISK. Report any transient image order issue separately from the settled LED state.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- MediaPlayer.sdc
- files.qip
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- tools/streams/generate_test_progressive_compatibility.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_transport_recovery.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 207 COMMIT Unreleased 2dd4c67 2026-08-18T04:37:17-07:00

#### Coming From:

Unreleased 2dd4c67

#### Purpose:

Record the MiSTer hardware result for the repeated-B transport and presentation correction.

#### Outcome:

Commit `2dd4c67` is not hardware accepted. The 2,875,985-byte `test_compat_dense_residual.m2v` now loads completely instead of freezing the MiSTer transfer path, but does so slowly and settles on a repeated coherent diagonal test raster. The uploaded photograph records that final raster. The settled diagnostic is USER 2, POWER 9, and DISK 0: the first error is `phase1_probe_error`, its parent source is the generalized P controller, and sub-code 9 is `raster_hold_error`, meaning at least one generalized P row-complete transaction failed to observe persistence before its 24-bit hold timeout. No DISK sub-code is defined for this error class. This proves the Entry-205 fail-open transport and Entry-206 terminal stream drain worked while isolating the next failure to P row persistence or its hold-time bound rather than repeated-B parsing.

#### Next Steps:

Before changing decoder behavior, measure the exact dense P row that arms and expires `raster_hold_active`, distinguish a genuinely missing row-persistence acknowledgement from a valid transaction whose hardware latency exceeds the fixed timeout, and extend a focused top-level regression or first-fault diagnostic to reproduce that boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 208 COMMIT Unreleased 450f78a 2026-08-18T04:42:35-07:00

#### Coming From:

Unreleased 2dd4c67

#### Purpose:

Accept a generalized P picture whose persistence proof precedes its parser completion pulse by one cycle.

#### Outcome:

Commit `450f78a` makes P raster-hold admission consume an already-present persistence proof atomically. The focused regression reproduces the hardware ordering: before the correction all 30 rows retired but completion left `raster_hold_active` set and `raster_hold_ready` clear; afterward the same transaction completes immediately with the hold inactive, ready asserted, no error, and P acceptance retained. The dense P row regression completes 1,350 motion records, 8,100 residual blocks, 175,586 coefficients, and 518,400 samples; the seven-B corpus, fail-open transport, two-scratch presentation, and six storage-tag regressions also pass unchanged. The clean Quartus 17.0.2 build completes in 9 minutes 13 seconds with no Critical Warning, zero setup, hold, or recovery TNS, +0.570 ns global setup, +0.251 ns global hold, +2.931 ns global recovery, +1.776 ns focused decoder setup, and +14.264 ns focused decoder recovery. It uses 29,045 ALMs, 41,901 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 `6172e2ed1f5883b1517c838041961f6528ebe983f1935f822883b87c13d31ec1` and dense-stream SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e` were uploaded to `10.10.0.30` and read back with matching hashes.

#### Next Steps:

Run `test_compat_dense_residual.m2v` through its complete sequence on MiSTer and confirm that transfer and P-picture transitions no longer pause for the former timeout, the final raster remains coherent, and the settled diagnostic is solid USER, solid POWER, and dark DISK.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- tools/streams/tb_h262_p_raster_hold.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 209 COMMIT Unreleased 450f78a 2026-08-18T05:12:25-07:00

#### Coming From:

Unreleased 450f78a

#### Purpose:

Record the MiSTer hardware result for the generalized P completion and persistence handshake correction.

#### Outcome:

Commit `450f78a` is not hardware accepted, but it removes the former POWER-9 raster-hold failure. The dense compatibility transfer remains slow yet now advances consistently, and the final coherent diagonal raster is unchanged. The settled diagnostic is USER 2, POWER 4, and DISK 0: the first error is `phase1_probe_error`, its parent source is `publication_error` in the compiled I/P/B publication shell, and no DISK sub-code is currently defined for that error class. This proves the final-row persistence proof is now accepted and moves the first failure to one of the shell's reference-bank, P-publication, or following-header ordering checks; the remaining load duration is consistent with live serialized raster work rather than the eliminated fixed hold timeout.

#### Next Steps:

Add first-fault detail for each publication-error assertion site and a complete dense I/P/B publication-order regression that drives row and picture persistence in hardware order, then use that evidence to correct only the failing reference-bank or header-order transition before another Quartus build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 210 COMMIT Unreleased 3fcf22f 2026-08-18T05:13:48-07:00

#### Coming From:

Unreleased 450f78a

#### Purpose:

Identify the hidden repeated-P parser failure that prevents the second dense P reference from reaching publication.

#### Outcome:

Commit `3fcf22f` proves the POWER-4 publication failure was downstream of stale B ownership: `b_candidate` remained asserted after B persistence, suppressed the following P parser's refill hold, and let thousands of compressed bytes overrun its active 512-byte window until coefficient state failed. The B parser now releases candidate ownership when the following non-B header is known, the P parser and publication shell retain sticky first-fault detail, and the complete dense regression passes 120 P rows, four P pictures, 210 B rows, seven B pictures, and five reference publications with no parser, transport, or publication error. Fail-open transport, parser-window, and restricted-slice regressions pass unchanged. The clean Quartus 17.0.2 build completes in 9 minutes 25 seconds with zero setup and hold TNS, no Critical Warning, +0.062 ns global setup, +0.249 ns global hold, +2.613 ns focused decoder setup, +14.318 ns focused decoder recovery, 29,163 ALMs, 41,923 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 `6692722e11d44c10bbbd716e60d4b1761072c4b72452742d1df403c7342c1120` was uploaded to `10.10.0.30` and read back with the same hash. Hardware accepts the deployed build: `test_compat_dense_residual.m2v` loads slowly but completes, visibly advances through more pattern changes, settles on the full dense diagonal raster captured in the uploaded photograph, and reports USER and POWER solid with DISK off.

#### Next Steps:

Proceed to the next v0.6.0 roadmap boundary by recording its proposal before making further decoder changes.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [x] Passed

---
## 211 COMMIT Unreleased 19914b2 2026-08-18T07:25:22-07:00

#### Coming From:

Unreleased 3fcf22f

#### Purpose:

Integrate intra-coded macroblocks into the generalized progressive B-picture path and qualify the ordinary mixed-macroblock compatibility corpus without regressing existing predictive modes.

#### Outcome:

Commit `19914b2` recognizes the H.262 Table B.4 unquantised and quantised intra macroblock types in non-scalable B pictures, applies picture-signalled DC precision and intra VLC format, carries intra ownership through the shared transform and sparse-sample protocol, and reconstructs all six 4:2:0 blocks without reference prediction. The deterministic 182,458-byte B-intra stream places unquantised and quantised intra macroblocks at column 20 in consecutive rows and passes software reference verification; RTL produces exactly 1,350 B macroblocks, two intra markers, twelve intra blocks, twelve DC events, 768 spatial samples and writes, and exactly 768 changed raster samples without parser or raster error. The complete 366,071-byte mixed corpus passes 210 P rows, seven P pictures, 450 B rows, fifteen B pictures, and eight reference publications without transport, decoder, publication, or presentation error; parser-window, standing B-residual, prediction-source, active-hierarchy, and authoritative seven-generator regressions also pass. Standards record H262-026 is published by metadata commit `d182f15`. The clean Quartus 17.0.2 build completes in 9 minutes 27 seconds with zero setup and hold TNS, no Critical Warning, +0.294 ns global setup, +0.248 ns global hold, +2.057 ns focused decoder setup, 29,442 ALMs, 42,188 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `350773e5804bccd566dd4cb7c8a953427e2bafae2feebf50bbeb890fc87b1176`; B-intra stream SHA-256 is `60c914c8d9232515b21cbbd55416e1ae17c7134ee45af5f90829f06026b78166`; regenerated mixed-corpus SHA-256 is `ad1d9e81f0f7544ac16a1aaddb85ef9e1065333c1fdd305aa3cf275aa1ccc289`.

#### Next Steps:

Install the Commit-211 RBF and run `test_b_intra_macroblocks.m2v` through one complete settled diagnostic report, confirming coherent display order I/B/P, two vertically adjacent authored intra macroblocks at column 20 in rows 8 and 9, solid USER and POWER, and dark DISK. Then run `test_compat_mixed_macroblocks.m2v` through all 24 pictures and confirm coherent I/P/B presentation, complete transfer retirement, and the same settled LED result.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/generate_test_b_intra_macroblocks.py
- tools/streams/tb_h262_b_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 212 COMMIT Unreleased 19914b2 2026-08-18T08:12:31-07:00

#### Coming From:

Unreleased 19914b2

#### Purpose:

Record MiSTer hardware acceptance of the B-picture intra-macroblock and ordinary mixed-macroblock compatibility boundary.

#### Outcome:

Commit `19914b2` passes both requested MiSTer LED tests with USER and POWER solid and DISK off. The uploaded B-intra capture shows the coherent repeated diagonal reference field and the authored vertically adjacent intra region at column 20 in rows 8 and 9 after complete I/B/P presentation. The uploaded mixed-corpus capture matches decoded source frame 8 at timestamp `00:00:00.320`, including the vertical color bars, moving diagonal, gray bar, sparse dots, and checkerboard feature. Frame-by-frame software review confirms the reported feature flicker during file loading is the intended motion of the 24-frame `testsrc2` source combined with rapid load-time picture publication, rather than missing decode regions, publication-order corruption, or a settled hardware error.

#### Next Steps:

Record the proposal for the long-GOP ownership, reference-rotation, publication, and soak-validation boundary before making further decoder changes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 213 COMMIT Unreleased 065a775 2026-08-18T08:13:58-07:00

#### Coming From:

Unreleased 19914b2

#### Purpose:

Qualify long-GOP decoder ownership, reference rotation, publication order, and sustained progressive 4:2:0 operation across the complete 72-picture compatibility stream.

#### Outcome:

Commit `065a775` extends the complete I/P/B publication regression with a long-GOP mode and corrects the single boundary it exposed: when a P parser refill ended exactly after a complete row and its alignment zeroes, the resumed capture contained only the two retained start-code-prefix bytes and was falsely rejected as a short slice chunk. The P path now accepts that empty `R_STUFF` tail for boundary classification, matching the standing B behavior without changing decoded syntax. The complete 791,528-byte long-GOP regression passes 660 P rows, 22 P pictures, 1,410 B rows, 47 B pictures, and 23 reference publications and promotions across three GOPs without transport, parser, reconstruction, ownership, persistence, or publication error. The 366,071-byte mixed and 2,875,985-byte dense publication regressions pass unchanged, and all seven authoritative stream hashes match their published values. The clean Quartus 17.0.2 build completes in 9 minutes 20 seconds with zero setup and hold TNS, no Critical Warning, +0.428 ns global setup, +0.247 ns global hold, +1.600 ns focused decoder setup, +15.088 ns focused decoder recovery, 29,576 ALMs, 42,157 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `3e60392fba96cab4d5ee00215bc55401441e71e4784a92ee0ae792833832bbe4`; long-GOP stream SHA-256 is `39dd3e889d1baa42e4d65fc2d6ca7a04c58c2ac38de0a5b1dba00e6585836d96`.

#### Next Steps:

Install `MediaPlayer_commit213_065a775.rbf` and load `test_compat_long_gop.m2v` through all 72 pictures and one complete settled diagnostic report, confirming coherent repeated-GOP I/P/B presentation, complete transfer retirement, USER and POWER solid, and DISK off.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 214 COMMIT Unreleased 065a775 2026-08-18T09:06:35-07:00

#### Coming From:

Unreleased 065a775

#### Purpose:

Record the MiSTer visual result that separates clean LED diagnostics from failed repeated-GOP presentation on the mixed compatibility stream.

#### Outcome:

Commit `065a775` passes the reported USER, POWER, and DISK checks on the B-intra and mixed-macroblock streams, and the B-intra stream now loads quickly before settling on its coherent authored raster. The mixed stream still glitches during loading, and the uploaded settled capture reads timestamp `00:00:00.440` and frame `11`; it matches decoded source frame 11 exactly, which is the last displayed frame of the first 12-frame GOP rather than final frame 23 of the 24-frame stream. The clean LEDs therefore prove that the existing syntax, reconstruction, and counted publication assertions did not fire, but they do not qualify repeated-GOP presentation or the pending 72-picture long-GOP hardware boundary.

#### Next Steps:

Add a repeated-GOP presentation regression that distinguishes every I/P/B frame and requires the final displayed identity to cross the second I-picture boundary, then correct the first reference, bank, or scheduler transition that leaves frame 11 settled before rebuilding for MiSTer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
