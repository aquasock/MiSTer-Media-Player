## 147 COMMIT v0.5.0-cycle f8afbe4 2026-08-15T15:56:39-07:00

#### Coming From:

v0.5.0-cycle 94aaf9b

#### Purpose:

Correct the mixed-GOP regression generator so every B-picture prediction footprint stays inside the coded reference picture while preserving the approved repeated I/P/B test scope.

#### Outcome:

Exact GitHub master commit `f8afbe453a1c8caec17f14992520c0a816d7c269` modifies only `tools/streams/generate_test_b_mixed_gop.py` (+2/-2). No RTL, QIP, SDC, DDR, parser, prediction, pacing, presentation, or observer source changes.

The corrected stream retains I/P/B/P/B coded order, I/B/P/B/P display order, two B pictures, forward/backward/bidirectional prediction, real internal MBA skips, and residual/no-residual cases, but removes the second-B edge-crossing motion vectors.

Because RTL is unchanged from Commit 146, fitted resources remain 32,238 ALMs, 44,532 registers, 461,345 block-memory bits, 92 DSPs, and 3 PLLs with clean timing.

Hardware corrected `test_b_mixed_gop.m2v` reaches stable **12-flash** diagnostic success. This proves both B parses/skips, both B prediction/reconstruction and scratch persistence transactions, the intervening second P/reference publication, both scratch presentations, both retained future-P presentations, and final normal acceptance. The four standing regressions also pass with normal solid USER: `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, `test_p_consecutive_reference.m2v`, and `test_all_i.m2v`.

#### Next Steps:

Retire the temporary Commit-146 mixed-GOP USER trace and restore normal USER behavior, then rerun all five accepted streams.

#### Files Modified:

- tools/streams/generate_test_b_mixed_gop.py

#### Status:

- [x] Built
- [x] Passed — mixed GOP reaches stage 12; all four standing regressions pass

---
## 148 COMMIT v0.5.0-cycle 4e9058a 2026-08-15T16:09:00-07:00

#### Coming From:

v0.5.0-cycle f8afbe4

#### Purpose:

Retire the temporary mixed-GOP USER diagnostic now that corrected repeated I/P/B playback is hardware accepted, and restore the normal USER acceptance indication without changing decode behavior.

#### Outcome:

Exact GitHub master commit `4e9058a59e9d99b2d36dab8bc65a11faa7159dc2` modifies only `MediaPlayer_top_07.svh`, deleting the Commit-146 observer and returning `LED_USER` directly to normal acceptance. Repeated mixed-GOP/re-arm logic, corrected generator, Commit-142 DDR frame-region protection, and Commit-139 presentation ordering remain untouched.

The user deleted Quartus database/output folders before this build. Exact build validation is clean: 32,155 / 41,910 ALMs (77%), 44,388 registers, 461,345 block-memory bits in 73 RAM blocks, 92 / 112 DSPs, 3 / 6 PLLs; zero setup TNS, global setup +0.324 ns, decoder +1.543 ns, video +8.313 ns, hold +0.228 ns, recovery +3.838 ns, removal +0.850 ns, minimum pulse-width +0.462 ns.

All five required normal-USER hardware regressions pass: `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, `test_p_consecutive_reference.m2v`, and `test_all_i.m2v`. Commit 148 is the accepted cleaned repeated-mixed-I/P/B functional baseline.

#### Next Steps:

Recover FPGA resources conservatively before release closure, favoring reuse/consolidation and preserving all five proven stream behaviors, Commit-142 DDR protection, Commit-139 presentation ordering, repeated-B behavior, and the corrected deterministic generator.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — all five normal-USER regressions solid USER on after clean database/output deletion

---
## 149 COMMIT v0.5.0-cycle 0cbafd8 2026-08-15T16:46:05-07:00

#### Coming From:

v0.5.0-cycle 4e9058a

#### Purpose:

Recover pre-release FPGA resources without changing accepted MPEG-2 behavior by consolidating the H.262 IDCT's mutually exclusive transform passes onto one multiplier/adder bank.

#### Outcome:

Exact GitHub master commit `0cbafd8d1ad5a9e832fe72a3ec15ca3c344c1fa1` modifies only `rtl/mpeg2_new/mpeg2_h262_idct.sv` (+253/-384). Three active IDCT instances previously synthesized separate eight-multiplier banks for pass 1 and pass 2 despite sequential non-overlapping execution. Commit 149 shares the multiplier/adder bank between passes without changing transform constants, rounding, visible sample order, or caller interfaces.

Exact clean build validation: 31,678 / 41,910 ALMs (76%), 43,752 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), 3 / 6 PLLs. Relative to Commit 148 this recovers 477 ALMs, 636 registers, and 24 DSPs. Timing is clean: global setup +0.470 ns with zero setup TNS, decoder +0.900 ns, video +8.338 ns, hold +0.228 ns, recovery +3.922 ns, removal +0.689 ns, minimum pulse-width +0.462 ns.

Hardware validation passes all five accepted streams with solid USER. The shared-IDCT 68-DSP consolidation is therefore hardware accepted.

#### Next Steps:

Preserve this executable baseline. Add advisory Audio-fork handoff comments, then consider at most one additional separately approved low-risk ALM cleanup before release closure.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv

#### Status:

- [x] Built
- [x] Passed — all five accepted normal-USER hardware regressions solid USER on

---
## 150 COMMIT v0.5.0-cycle 4469220 2026-08-15T16:57:25-07:00

#### Coming From:

v0.5.0-cycle 0cbafd8

#### Purpose:

Add comments-only Audio-fork jumping-off points to the prospective v0.5.0 baseline without changing FPGA behavior or establishing a permanent integration ABI.

#### Outcome:

Exact GitHub master commit `44692208170113ed5fc35877e4ec2c16d2b04e08` modifies only `MediaPlayer_top_00.svh` with 35 comment lines and no executable RTL changes. Five searchable `AUDIO_FORK_POINT[...]` anchors document advisory future integration locations: PCM output, stream split/demux, clock/reset, DDR-client integration, and system-level integration guidance. They explicitly preserve the video-private H.262 path and current DDR/reference ownership behavior rather than defining a fixed ABI.

The required MiSTer-Media-Player-Audio compatibility check remains unavailable because `core.md` has no configured Audio GitHub repository.

Executable RTL is identical to the hardware-accepted Commit-149 tree. Exact Commit-150 source was not separately compiled at this boundary.

#### Next Steps:

Use the accepted Commit-149 executable state for immediate regression evidence. Preserve the Audio comments in all subsequent exact release candidates.

#### Files Modified:

- MediaPlayer_top_00.svh (comments only)

#### Status:

- [ ] Built — comments-only source; executable state equals built Commit 149
- [ ] Passed

---
## 151 COMMIT v0.5.0-cycle f05d07d 2026-08-15T17:22:51-07:00

#### Coming From:

v0.5.0-cycle 4469220

#### Purpose:

Perform one final conservative ALM-focused pre-release cleanup without changing accepted H.262 arithmetic, picture behavior, DDR ownership, B presentation ordering, Audio handoff comments, or the 68-DSP ceiling established by Commit 149.

#### Outcome:

Exact GitHub master commit `f05d07d326f4f0bc224695ed979d77570cf3c7d5` modifies only `rtl/mpeg2_new/mpeg2_h262_idct.sv` (+6/-21), removing IDCT reset/block-start writes believed unreachable under the complete-64-coefficient caller contract. Transform arithmetic and sequencing remain source-identical.

Exact build validation is healthy but misses the resource objective: 31,828 / 41,910 ALMs (76%), 42,873 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs, 3 / 6 PLLs. Relative to Commit 150's executable baseline this increases ALMs by 150 while reducing registers by 879. Timing remains clean.

Repeated hardware `test_p_consecutive_reference.m2v` testing is intermittent at approximately 50/50; failing runs can crash the MiSTer. Commit 151 is therefore rejected regardless of its otherwise clean build and also fails the intended ALM-reduction objective.

#### Next Steps:

Revert only Commit-151's executable IDCT-clear removal in a new forward commit, restoring the exact Commit-150/149 executable tree while preserving Commit-150 Audio handoff comments and Commit-149's 68-DSP consolidation. Validate with repeated consecutive-P testing before any further optimization.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv

#### Status:

- [x] Built
- [ ] Passed — REJECTED: intermittent consecutive-P failure/crash and no ALM benefit

---
## 152 COMMIT v0.5.0-cycle c49a9e5 2026-08-15T17:51:47-07:00

#### Coming From:

v0.5.0-cycle f05d07d

#### Purpose:

Restore the stable Commit-150/149 IDCT storage/reset behavior after Commit 151 produced a nondeterministic consecutive-reference P regression and increased ALM use, while preserving the accepted 68-DSP shared-IDCT consolidation and all Audio-fork handoff comments.

#### Outcome:

Exact GitHub master commit `c49a9e5cf0becea550984050b9e44d9bb0cfa17a` is the exact reverse source delta of Commit 151 and points to the same Git tree as Commit 150. The complete source tree is therefore byte-for-byte identical to Commit 150: Commit-149 shared-IDCT consolidation remains; Commit-151 clear removal is absent; all Audio handoff comments remain.

The exact clean build returns to the expected Commit-149/150 resource shape and clean timing. However repeated `test_p_consecutive_reference.m2v` still intermittently stalls/crashes, with disk LED remaining active and USER off on failure. The other four standing streams work properly. Because Commit 152 is source-identical to Commit 150, this repeated-run evidence invalidates the earlier assumption that the Commit-149/150 executable baseline was reliably stable under consecutive-reference P stress; it does not prove Commit 151 introduced the underlying instability.

The build evidence and crash photograph were archived after inspection.

#### Next Steps:

Reject release closure and further resource optimization. Add a diagnostic-only consecutive-reference P progress/ownership trace covering stream ingress/backpressure, P2 execution/publication, DDR writer/read-response completion, reference promotion, and final stream release. Capture both pass and failure on repeated runs before any functional correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv (exact Commit-151 revert)

#### Status:

- [x] Built
- [ ] Passed — REJECTED: repeated `test_p_consecutive_reference.m2v` still intermittently stalls/crashes

---
## 153 COMMIT v0.5.0-cycle 99c7519 2026-08-15T18:24:58-07:00

#### Coming From:

v0.5.0-cycle c49a9e5

#### Purpose:

Instrument the intermittent `test_p_consecutive_reference.m2v` stall with an observer-only USER-LED progress trace that distinguishes the second consecutive P picture's generalized replay, DDR reconstruction/persistence, reference publication, and final stream release without changing decoder behavior.

#### Outcome:

Exact GitHub master commit `99c7519ed99021eb39b692d8451757044a15d147` modifies only `MediaPlayer_top_07.svh` (+211/-2). The observer preserves all decoder-ready, parser, replay, prediction, transform, reconstruction, DDR, reference, framebuffer, presentation, QIP, SDC, generator, and Audio-fork behavior.

The trace uses progress codes 1..10 and error buckets 11 publication-boundary error, 12 prediction/reference-pipeline error, 13 DDR store/cache error, and 14 frontend/IQ/IDCT/reconstruction error.

Repeated hardware testing cleanly separates complete runs at **10 flashes** from failing runs at **12 flashes**. Failures take noticeably longer to load and have a visibly different frozen framebuffer state. Code 12 is `mpeg2_new_pred_error`, proving the instability reaches the shared prediction/reference pipeline before normal completion, but this bucket still contains multiple possible generalized-P failure classes and is too broad for a correction.

#### Next Steps:

Refine only code 12 with observer-only first generalized-P error classification: metadata/re-arm, start prerequisites, source bounds, DDR response ownership, persistence readback, timeout, residual accounting, or wrapper/other. Preserve all functional behavior.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — diagnostic separates 10-pass from 12-failure; functional stability unresolved

---
## 154 COMMIT v0.5.0-cycle ad071ba 2026-08-15T18:55:00-07:00

#### Coming From:

v0.5.0-cycle 99c7519

#### Purpose:

Refine the intermittent consecutive-reference P diagnostic so the Commit-153 prediction/reference-pipeline error bucket identifies the first generalized-P engine failure class without changing decode behavior.

#### Outcome:

Exact GitHub master commit `ad071ba3380f918b9f4a3734a97cee1f00bf80c5` modifies `MediaPlayer_top_07.svh` (+28/-7) and `rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv` (+64/-13). The generalized-P engine gains an observer-only sticky first-error cause published through paired `0xE?` / `0xD?` proof-output signatures. Functional engine control does not consume the cause.

Cause mapping: 1 metadata/re-arm accounting; 2 invalid reference/destination launch prerequisites; 3 source bounds; 4 unsolicited DDR response; 5 persistence readback mismatch; 6 engine timeout; 7 residual-descriptor accounting. Top-level terminal mapping 15..21 corresponds to those classes, with 22 wrapper/other. Pass remains code 10.

Exact build validation is clean: 31,855 / 41,910 ALMs (76%), 43,890 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs, 3 / 6 PLLs; zero setup TNS, global setup +0.384 ns, decoder +1.518 ns, video +7.627 ns, hold +0.248 ns, recovery +3.761 ns, removal +0.692 ns, minimum pulse-width +0.462 ns.

Repeated hardware runs show **10** on pass and **13** on failure. Code 13 has higher priority and means DDR store/cache error is present; it masks whether a lower-priority prediction cause is also present or first. The build archive was inspected and archived.

#### Next Steps:

Refine code 13 observer-only into specific DDR store/cache first-fault classes and record whether prediction error was already present or coincident. Do not apply a functional fix until ordering is known.

#### Files Modified:

- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [x] Passed — diagnostic narrows failures to DDR store/cache code 13; functional stability unresolved

---
## 155 COMMIT v0.5.0-cycle dbd0993 2026-08-15T19:52:00-07:00

#### Coming From:

v0.5.0-cycle ad071ba

#### Purpose:

Refine the intermittent consecutive-reference P diagnostic so Commit-154 code 13 identifies the first DDR picture-store or framebuffer-cache failure class and records whether prediction error was already present or coincident, without changing decode behavior.

#### Outcome:

Exact GitHub master commit `dbd0993e78d187a5aee57a3edcb567bd0c558c28` adds observer-only first-error cause visibility to the DDR picture writer, framebuffer cache, and top-level consecutive-P trace. Codes 15..22 represent four store causes followed by four cache causes without prediction already/coincident; codes 23..30 represent the same causes with prediction already present or coincident. Classified first-fault state is sticky.

Build validation fails during Analysis & Synthesis: `MediaPlayer_top_04.svh` connects `diag_error_cause` to `mpeg2_h262_ddram_store`, but Quartus compiles the entity from `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`; the observer had been added to an unused sibling. No hardware diagnostic exists for this commit. Failed build resources were archived.

#### Next Steps:

Correct only the diagnostic hookup to the active `_420p.sv` writer implementation, preserving the approved mapping and all functional writer behavior.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv

#### Status:

- [ ] Built — Analysis & Synthesis failed before fitter
- [ ] Passed

---
## 156 COMMIT Unreleased ebd3ead 2026-08-15T20:03:49-07:00

#### Coming From:

Unreleased dbd0993

#### Purpose:

Correct the Commit-155 DDR writer diagnostic hookup so the already-approved first-fault observer is attached to the `mpeg2_h262_ddram_store` implementation that the Quartus project actually compiles, without changing the diagnostic mapping or functional writer behavior.

#### Outcome:

Exact GitHub master commit `ebd3ead1316691d3032a33ada7654bf1a98c53bf` moves the observer from the unused writer sibling to active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`. No writer state transition, DDR request/response, parser, prediction, reference, pacing, framebuffer, B behavior, QIP, SDC, generator, or Audio-fork behavior changes.

Build validation is clean: 31,910 / 41,910 ALMs (76%), 43,934 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs, 3 / 6 PLLs; zero setup TNS, global setup +0.558 ns, decoder +1.744 ns, video +8.084 ns, hold +0.248 ns, recovery +4.109 ns, removal +0.676 ns, minimum pulse-width +0.462 ns.

Repeated consecutive-P hardware runs produce **10** on pass and **23** on crash. Code 23 means store cause 1 (`block_start` overlap with an existing capture/flush/write) with prediction error already present or coincident. Crashing runs remain noticeably longer to load. All four standing guard streams pass: `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v`. A better external PSU does not change the intermittent 10/23 behavior.

The exact build package was inspected, archived, and removed from the active project folder.

#### Next Steps:

Refine the proven code-23 writer overlap into exact pre-edge writer state, writer-visible DDR busy state, and prediction-before versus prediction-coincident ordering. No functional correction yet.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:

- [x] Built
- [x] Passed — diagnostic boundary complete: 10 pass / 23 crash, all four guards pass; functional stability unresolved

---
## 157 COMMIT Unreleased 177a480 2026-08-15T21:16:37-07:00

#### Coming From:

Unreleased ebd3ead

#### Purpose:

Refine the proven consecutive-P code-23 writer-overlap diagnostic to identify the exact pre-edge writer state, writer-visible DDR busy state during an active write, and prediction-before versus prediction-coincident ordering without changing functional decode behavior.

#### Outcome:

Exact GitHub master commit `177a4800820560d13610d03f4f14c6e55d71163b` modifies `MediaPlayer_top_07.svh` (+82/-47) and active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv` (+9/-4). The writer observer maps 1 capture-active only; 2 flush-pending only; 3 write-active+flush with visible DDR busy low; 4 write-active+flush with DDR busy high; 5 orphan pixel; 6 invalid block_complete; 7 invalid geometry/metadata. It remains sticky and observer-only.

Top-level ordering preserves an early `prediction-before-DDR` latch and separately identifies prediction first visible coincident with overlap. Internal codes 31..38 represent four writer states crossed with prediction-before/coincident. No functional decode behavior is changed.

This commit was intentionally superseded before build because counting 31..38 flashes was not reliably human-readable.

#### Next Steps:

Preserve the exact observer encoding but replace the USER presentation with a two-group display through Commit 158.

#### Files Modified:

- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:

- [ ] Built — superseded before build by Commit 158 display-only refinement
- [ ] Passed

---
## 158 COMMIT Unreleased 5740587 2026-08-15T21:24:27-07:00

#### Coming From:

Unreleased 177a480

#### Purpose:

Make the approved Commit-157 consecutive-P overlap diagnostic reliably human-readable on the single USER LED without changing any underlying observer evidence or functional decoder behavior.

#### Outcome:

Exact GitHub master commit `5740587427e3dda356eaa316ced0fbfab7b258d6` modifies only `MediaPlayer_top_07.svh` (+40/-5). Internal codes 31..38 remain unchanged. USER renders them as two short groups: group 1 writer state (1 capture, 2 flush, 3 write+flush/DDR not busy, 4 write+flush/DDR busy); group 2 prediction ordering (1 prediction already present before overlap, 2 prediction first coincident). Pass remains 10.

Exact build validation is clean: 31,944 / 41,910 ALMs (76%), 43,942 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs, 3 / 6 PLLs; zero setup TNS, global setup +0.220 ns, decoder +1.239 ns, video +7.501 ns, hold +0.246 ns, recovery +4.017 ns, removal +0.562 ns, minimum pulse-width +0.462 ns.

Hardware crash reports **4-1**: writer overlap occurs in write-active+flush while writer-visible DDR busy is high, and prediction error was already present on an earlier decoder clock. Therefore prediction/reference-pipeline failure precedes the writer overlap; the writer condition is downstream and is not yet the corrective target. The build archive was inspected and archived.

#### Next Steps:

The user approved a prediction-first observer boundary. Commit 159 should identify the generalized-P first-error cause already present before the later writer overlap, without a functional correction.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed — primary diagnostic captured as 4-1; Commit-159 refinement supersedes remaining observer work

---
## 159 COMMIT Unreleased a5b518d 2026-08-15T21:55:32-07:00

#### Coming From:

Unreleased 5740587

#### Purpose:

Identify the first prediction/reference-pipeline failure class that is already present before the proven DDR-busy writer overlap in the intermittent consecutive-P failure, while preserving the Commit-157/158 writer-state ordering evidence and making the resulting USER diagnostic practical to read.

#### Outcome:

Exact GitHub master commit `a5b518d045bb035748cb668f797ba4187a84bcba` (`Trace prediction first fault`) is exactly one commit ahead of Commit 158. Final GitHub comparison reports exactly one modified path, `MediaPlayer_top_07.svh` (+114/-8). No predictor control, prediction arithmetic, reconstructed data, writer sequencing, DDR behavior, parser state, stream pacing, reference ownership/publication, framebuffer scheduling, B behavior, QIP, SDC, generator, or Audio-fork behavior changes.

Commit 159 resurfaces the existing generalized-P observer carrier only at top level. A valid carrier requires `mpeg2_new_pred_error`, paired `E?/D?` high nibbles, matching low-nibble cause, and cause 1..7. Cause classes remain: 1 metadata/order; 2 start prerequisites; 3 source bounds; 4 unsolicited DDR response; 5 persistence verify mismatch; 6 timeout; 7 residual-descriptor accounting. Cause 8 is top-level other/unclassified if a valid paired carrier does not appear after the observer wait.

When prediction is proven earlier than a classified writer overlap, USER reports three groups `A-B-C`. `A-B` encodes prediction cause: `1-1` cause1, `1-2` cause2, `1-3` cause3, `1-4` cause4, `2-1` cause5, `2-2` cause6, `2-3` cause7, `2-4` cause8. `C` preserves later writer state: 1 capture, 2 flush, 3 write+flush/DDR busy low, 4 write+flush/DDR busy high. The presence of this display itself preserves prediction-before-writer ordering. A clean run remains code 10.

Primary hardware evidence is now complete. Failing `test_p_consecutive_reference.m2v` runs report **2-2-4**. The first two groups are generalized-P cause 6, the prediction transaction timeout; the third group preserves the later write+flush/DDR-busy overlap. Passing runs report **10**. The user reports the other standing regression streams work correctly: `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v` all pass. The longer-load symptom was not separately re-reported for this final Commit-159 validation.

Exact `a5b518d_build_logs.tar.gz` was inspected from the Google Drive project folder. Quartus Prime 17.0.2 Build 602 completed successfully for `5CSEBA6U23I7`. Fitter utilization is 32,011 / 41,910 ALMs (76%), 44,079 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), and 3 / 6 PLLs. Setup endpoint TNS is zero. Global worst setup is +0.120 ns; decoder same-clock worst +0.997 ns with 0/100 violations; video same-clock worst +7.608 ns with 0/80 violations; hold +0.205 ns; recovery +4.399 ns; removal +0.666 ns; minimum pulse-width +0.462 ns. Structural timing remains `no_clock=3094`, `multiple_clock=86`, `virtual_clock=1`, `no_input_delay=14`, `no_output_delay=129`, zero loops/latches.

The inspected build package was moved into the Google Drive project `archives` folder and removed from the active project folder. Do not re-open it without explicit user approval.

This evidence establishes **prediction transaction timeout first, writer overlap later**. Cause 6 does not yet reveal which prediction transaction phase stopped making forward progress, so no functional correction is justified.

#### Next Steps:

The user explicitly approved an observer-only refinement of timeout cause 6. Commit 160 implements that boundary by recording which transaction phase is active when the watchdog expires. Build exact Commit 160 and capture at least one clean pass and one crash if practical, then rerun the four standing guards.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — observer validation complete: 10 pass / 2-2-4 crash; all four standing guard streams pass; functional consecutive-P stability remains unresolved

---
## 160 COMMIT Unreleased 1efbb4b 2026-08-15T23:31:10-07:00

#### Coming From:

Unreleased a5b518d

#### Purpose:

Refine generalized-P timeout cause 6 so a failing consecutive-reference transaction identifies which prediction transaction phase stopped making forward progress before the watchdog expired, while preserving all functional decode/DDR behavior and the proven later writer-overlap ordering.

#### Outcome:

Exact GitHub master commit `1efbb4b328a933a31a350213f7ffdadd669c82cd` (`Trace prediction timeout phase`) is exactly one commit ahead of Commit 159 `a5b518d045bb035748cb668f797ba4187a84bcba`. Final GitHub comparison reports exactly one modified path, `rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv`, with 50 additions and 16 deletions. No top-level file, parser, prediction arithmetic, residual arithmetic, reconstructed sample data, writer state machine, DDR request/response protocol, arbiter, reference ownership/publication, stream pacing, framebuffer scheduling, B-picture behavior, QIP, SDC, generator, or Audio-fork source is modified.

Commit 160 adds two observer-only three-bit registers to the active generalized-P raster engine: a live timeout phase and a latched timeout phase captured only when sticky first-error cause 6 wins. Neither register feeds engine control. The four phase classes are:

1. prediction DDR request issue/accept
2. prediction DDR response wait
3. reconstructed block output / waiting for store completion
4. persistence readback

The existing transaction watchdog and cause-6 condition are unchanged. Commit 160 reuses the established Commit-159 paired error carrier and three-group USER display rather than adding a functional interface or another top-level observer. For timeout cause 6 only, the carrier is remapped from historical `E6/D6` to `E1/D1` through `E4/D4`, where the low nibble is the latched timeout phase. Non-timeout generalized-P causes retain their historical carrier values unchanged.

Because Commit 159 maps cause numbers 1..4 to USER `1-1` through `1-4`, a prediction-before-writer timeout on Commit 160 is intentionally displayed as **`1-P-C`**:

- `1-1-C` = timeout phase 1, prediction request issue/accept
- `1-2-C` = timeout phase 2, waiting for prediction DDR response
- `1-3-C` = timeout phase 3, reconstructed output / store completion
- `1-4-C` = timeout phase 4, persistence readback

`C` continues to preserve the later writer-overlap state exactly as Commit 159: 1 capture, 2 flush, 3 write+flush/DDR busy low, 4 write+flush/DDR busy high. A clean run remains the historical **10**. This Commit-160-specific `1-P-C` interpretation supersedes the Commit-159 timeout display only for binaries built from Commit 160; Commit 159's observed `2-2-4` remains correctly recorded as cause-6 timeout followed later by writer state 4.

The commit was published directly to `master` as a single final commit with Commit 159 as its parent. GitHub verification reports exactly one commit ahead, zero commits behind, and exactly the one intended RTL file modified.

Exact `1efbb4b_build_logs.tar.gz` was inspected from the Google Drive project folder. Quartus Prime 17.0.2 Build 602 completed successfully for `5CSEBA6U23I7`. Fitter utilization is 32,031 / 41,910 ALMs (76%), 43,911 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), and 3 / 6 PLLs. Setup endpoint TNS is zero. Global worst setup is +0.141 ns; decoder same-clock worst +0.956 ns with 0/100 violations; video same-clock worst +6.274 ns with 0/80 violations; hold +0.252 ns; recovery +4.062 ns; removal +0.996 ns; minimum pulse-width +0.462 ns. Structural timing remains `no_clock=3094`, `multiple_clock=86`, `virtual_clock=1`, `no_input_delay=14`, `no_output_delay=129`. The build package was moved into the Google Drive project `archives` folder after inspection.

Primary failing hardware evidence is **`1-3-4`** on `test_p_consecutive_reference.m2v`. Commit-160 decoding makes the first two groups timeout phase 3: the generalized-P engine has completed reconstruction/output of a block and is waiting for the ordinary DDR store to assert `block_stored`. The third group remains the later Commit-157 writer evidence: write-active + flush while writer-visible `ddram_busy` is high. Thus the first proven stalled region is now the **P reconstructed-block -> ordinary DDR store completion handshake**, not prediction DDR request issue, prediction DDR response wait, or persistence readback.

Source review explains the remaining ambiguity. In active `mpeg2_h262_ddram_store_420p.sv`, `block_stored` is asserted only after the writer accepts all eight row writes; while `writing && ddram_busy`, row progress stops. In `mpeg2_h262_ddram_arbiter.sv`, `writer_busy` is high not only for physical DDR busy but whenever the writer is not granted: an outstanding/display read, a live display-reader request, a prediction-reader request, or display-region ownership exclusion can all deny the writer. Therefore `1-3-4` proves the store is stalled while the writer sees busy, but does **not** yet identify which arbiter denial condition is holding the block. Bypassing writer protection or changing frame ownership is not justified from this evidence alone.

The MiSTer-Media-Player-Audio compatibility check remains unavailable: GitHub returns 404 for the expected `aquasock/MiSTer-Media-Player-Audio` repository, so there is no Audio commit to compare.

#### Next Steps:

The user explicitly approved the observer-only arbiter-stall refinement. Commit 161 implements that boundary without changing writer, arbiter, frame-bank, DDR, parser, predictor, or pacing behavior. Build exact Commit 161 and capture the full three-group code on at least one failing `test_p_consecutive_reference.m2v` run; confirm a clean run still reaches 10 and rerun the four standing guard streams once if practical.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [ ] Passed — primary diagnostic captured as `1-3-4`; phase-3 store-completion stall localized, functional consecutive-P stability unresolved

---
## 161 COMMIT Unreleased 5d8c8ba 2026-08-15T23:59:26-07:00

#### Coming From:

Unreleased 1efbb4b

#### Purpose:

Classify the exact DDR-arbiter condition holding the ordinary reconstruction writer when the Commit-160 consecutive-P diagnostic times out in phase 3, while preserving the proven prediction-before-writer ordering and all functional decoder, writer, arbitration, frame-ownership, and DDR behavior.

#### Outcome:

Exact GitHub master commit `5d8c8ba7073ea1273ff0aa7df1a074b86ca83a64` (`Trace writer arbiter stall`) is exactly one commit ahead of Commit 160 `1efbb4b328a933a31a350213f7ffdadd669c82cd`. Final comparison reports exactly one modified path, `MediaPlayer_top_07.svh`, with 110 additions and 1 deletion. No arbiter source, DDR writer source, parser, prediction engine, reconstruction data path, reference ownership/publication, stream pacing, framebuffer scheduler, B-picture behavior, QIP, SDC, generator, or Audio-fork source is modified.

Commit 161 adds a passive top-level mirror of the active DDR arbiter's read-owner bookkeeping. The observer duplicates `read_outstanding`, read-owner selection, outstanding word count, display-region validity, and display-region identity from the same existing arbiter inputs and physical DDR response signals. The mirrored state is used only for diagnostics and does not feed the real arbiter or any functional client.

From that mirror, Commit 161 classifies the pre-edge writer stall reason while `mpeg2_new_ddr_wr_we` is active:

1. writer destination matches the display-owned DDR region
2. display read is outstanding or has request priority
3. prediction read is outstanding or has request priority
4. writer is otherwise granted but physical `DDRAM_BUSY` remains high

The reason is sampled one decoder clock before the Commit-160 timeout carrier becomes visible, matching the phase-3 watchdog edge rather than the later writer-overlap event.

Commit 160 represents timeout phase 3 as paired `E3/D3`. Commit 161 recognizes that carrier as the phase-3 timeout only while prediction persistence is still incomplete; historical generalized-P source-bounds cause 3 sets `persisted_seen`, so it retains its original cause-3 interpretation. When a valid phase-3 writer-stall reason 1..4 is available, the top-level observer remaps it to existing prediction-detail causes 5..8. The established Commit-159 three-group USER display therefore reports **`2-R-C`**:

- `2-1-C` = display-region ownership exclusion
- `2-2-C` = display read outstanding/request priority
- `2-3-C` = prediction read outstanding/request priority
- `2-4-C` = writer granted, physical DDR busy

`C` remains the later Commit-157 writer-overlap state exactly as before: 1 capture, 2 flush, 3 write+flush/DDR busy low, 4 write+flush/DDR busy high. A clean run remains code **10**. If no valid arbiter reason is captured, the historical Commit-160 `1-3-C` phase-3 display remains as a fallback rather than inventing a reason.

Exact `5d8c8ba_build_logs.tar.gz` was inspected from the Google Drive project folder. Quartus Prime 17.0.2 Build 602 completed successfully for Cyclone V `5CSEBA6U23I7` at 2026-08-16 00:15 local. Fitter utilization is 32,034 / 41,910 ALMs (76%), 44,006 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), and 3 / 6 PLLs (50%). Setup endpoint TNS is zero. Global worst setup is +0.589 ns; decoder same-clock worst +1.030 ns with 0/100 violations; video same-clock worst +8.003 ns with 0/80 violations; hold +0.246 ns; recovery +3.897 ns; removal +0.696 ns; minimum pulse-width +0.462 ns. Structural timing remains `no_clock=3094`, `multiple_clock=86`, `virtual_clock=1`, `no_input_delay=14`, `no_output_delay=129`, `loops=0`, and `latches=0`. The inspected build package was moved into the existing Google Drive project `archives` folder.

Primary failing hardware evidence is **`2-1-4`** on `test_p_consecutive_reference.m2v`. Commit-161 decoding makes `2-1` the first phase-3 writer stall reason: the ordinary reconstruction writer's destination region matches the display-owned DDR region. The final `4` preserves the later writer-overlap state, write-active + flush with writer-visible DDR busy high. This resolves the Commit-160 ambiguity: the phase-3 timeout is caused by display-region ownership exclusion, not display-read priority, prediction-read priority, or physical DDR busy after a writer grant.

Source review identifies the ownership race. The active Quartus file list compiles `rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv`. On a persisted P-picture, that publication shell immediately records the completed bank, flips `active_frame_bank` to the other retained reference bank, and promotes the completed bank to reference ownership. `MediaPlayer_top_04.svh` passes `mpeg2_new_active_frame_bank` directly as `destination_frame_bank` for P reconstruction. Presentation, however, does not transfer display ownership at publication time: the completed frame is queued and the top-level display bank changes only on the synchronized framebuffer swap window. Therefore, for consecutive P pictures, the newly selected P destination bank can still be the bank currently owned by the display when the next P begins. Commit-142's `[17:16]` arbiter protection correctly refuses such a write. The observed intermittency is consistent with this publication-versus-presentation timing race.

Do **not** weaken or bypass Commit-142 display-write protection. The protection is functioning correctly and is what prevents visible-frame corruption. The corrective target is P-picture pacing/ownership handoff before the next reference write begins.

The MiSTer-Media-Player-Audio compatibility check remains unavailable because `core.md` has no configured Audio GitHub repository.

A clean Commit-161 code-10 run and the four standing guard streams have not yet been re-reported for this exact binary. Their absence does not change the first-fault localization, but they remain required validation for a functional correction candidate.

#### Next Steps:

The user explicitly approved the proposed functional boundary. Commit 162 implements the consecutive-P destination-ownership pacing correction while preserving Commit-142 protection and the established B reorder/presentation path. Build and stress-test exact Commit 162 before accepting the functional fix.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — diagnostic boundary complete: `2-1-4` proves display-region ownership exclusion is the first phase-3 writer stall; functional consecutive-P stability remains unresolved

---
## 162 COMMIT Unreleased 42d330f 2026-08-16T00:25:40-07:00

#### Coming From:

Unreleased 5d8c8ba

#### Purpose:

Correct the hardware-proven consecutive-P publication-versus-presentation ownership race by pacing only a following P picture until its selected destination reference bank is no longer owned by the display, without weakening DDR write protection or changing B-picture display-order behavior.

#### Outcome:

Exact GitHub master commit `42d330fffe8555cbaea01d5d002680fb4ab20acf` (`Pace consecutive P destination`) is exactly one commit ahead of Commit 161 `5d8c8ba7073ea1273ff0aa7df1a074b86ca83a64`. Final comparison reports two modified paths with 78 additions and 1 deletion total: `MediaPlayer_top_00.svh` (+6/-1) and `MediaPlayer_top_05.svh` (+72/-0).

Commit 162 preserves the existing decoder-owned backpressure and Commit-145/139 B-presentation hold, then adds one new top-level `mpeg2_new_p_destination_ownership_hold` term to `mpeg2_new_stream_ready`. The new hold is registered; there is no combinational dependency from DDR arbitration back into stream acceptance.

A small accepted-byte picture-header classifier is added beside the presentation scheduler. It maintains a 32-bit start-code window over bytes actually accepted with `mpeg2_stream_rd`, recognizes picture start code `0x00000100`, and consumes the two following picture-header bytes before acting on `picture_coding_type`. This is intentionally late enough that a following picture is classified before any ownership pause can assert, avoiding a P-to-P header deadlock and allowing a following B to proceed through the existing B reorder path.

The gate arms only after a published P picture, using the existing `mpeg2_new_picture_420_complete` pulse while `mpeg2_new_picture_coding_type == 3'b010`. At the next classified picture header:

- if the next picture is P and `mpeg2_new_active_frame_bank` still equals `mpeg2_new_display_frame_bank` while the display is not on scratch, the P-only ownership hold asserts;
- if the next picture is B or I, the arm is cleared without asserting the hold;
- once presentation moves the display away from the selected P destination bank, the hold clears and the existing decoder/P reconstruction path resumes unchanged.

This correction targets the exact Commit-161 `2-1-4` root cause. Commit-142 `[17:16]` display-write exclusion is not modified or bypassed. The DDR arbiter, ordinary DDR writer, prediction/reconstruction engines, reference-bank alternation/publication logic, framebuffer swap scheduler, B scratch handling, B coded/display-order transaction, QIP, SDC, generators, and Audio-fork comments are unchanged.

Source sanity review after publication confirms the existing generalized-P controller has no wall-clock timeout active at picture-header classification. Its `raster_hold_timeout` starts only after `raster_complete_now`, so the intentional header-level ownership pause cannot consume the reconstruction/persistence watchdog. General P syntax capture remains driven by accepted `stream_valid` bytes and resumes from the parked header state when the display ownership condition clears.

The MiSTer-Media-Player-Audio compatibility check remains unavailable because `core.md` has no configured Audio GitHub repository.

Exact `42d330f_build_logs.tar.gz` was inspected from the Google Drive project folder. Quartus Prime 17.0.2 Build 602 completed successfully for Cyclone V `5CSEBA6U23I7` at 2026-08-16 00:42 local. Fitter utilization is 31,922 / 41,910 ALMs (76%), 43,946 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), and 3 / 6 PLLs (50%). Setup endpoint TNS is zero. Global worst setup is +0.332 ns; decoder same-clock reports 0/100 violations with worst +1.798 ns; video same-clock reports 0/80 violations with worst +7.606 ns; hold +0.259 ns; recovery +2.627 ns; removal +1.096 ns; minimum pulse-width +0.462 ns. Structural timing remains `no_clock=3094`, `multiple_clock=86`, `virtual_clock=1`, `no_input_delay=14`, `no_output_delay=129`, `loops=0`, and `latches=0`. The inspected build package was moved into the existing Google Drive project `archives` folder.

Hardware validation passes completely. The user reports **everything passes** after the requested Commit-162 matrix: repeated `test_p_consecutive_reference.m2v` stress reaches code **10** without the prior intermittent crash/stall, and all four standing guards pass: `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v`. This closes the Commit-151/152 intermittent consecutive-reference investigation: the root cause was the publication-versus-presentation destination-ownership race localized by Commits 153-161, and the Commit-162 P-only pacing correction resolves it while preserving Commit-142 display-write protection and established B behavior. Commit 162 is the new accepted functional baseline.

#### Next Steps:

The user explicitly approved the diagnostic-retirement boundary. Commit 163 removes the temporary Commits 153-161 consecutive-P diagnostic layer and restores normal USER acceptance while preserving the exact Commit-162 pacing correction and all previously accepted functional baselines. Build and regress exact Commit 163 before accepting the cleaned baseline.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh

#### Status:

- [x] Built
- [x] Passed — accepted functional baseline: consecutive-P stress and all four standing guards pass

---
## 163 COMMIT Unreleased 1370c28 2026-08-16T00:51:40-07:00

#### Coming From:

Unreleased 42d330f

#### Purpose:

Retire the temporary consecutive-P diagnostic instrumentation accumulated through Commits 153-161 now that Commit 162 hardware has resolved and stress-validated the ownership race, restoring normal USER acceptance without altering the accepted functional correction.

#### Outcome:

Exact GitHub master commit `1370c28e3d34b1fd603c17130986bc336da29a32` (`Retire consecutive P diagnostics`) is exactly one commit ahead of accepted Commit 162 `42d330fffe8555cbaea01d5d002680fb4ab20acf`. The cleanup restores the seven files changed by Commits 153-161 byte-for-byte to their accepted Commit-152 (`c49a9e5`) contents: `MediaPlayer_top_01.svh`, `MediaPlayer_top_04.svh`, `MediaPlayer_top_06.svh`, `MediaPlayer_top_07.svh`, `rtl/mpeg2_luma_framebuffer.sv`, `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`, and `rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv`. Relative to Commit 162 the cleanup is seven modified files with 25 additions and 716 deletions.

The removed material is the temporary first-fault/phase/writer/cache/arbiter observer layer used to localize the intermittent consecutive-P failure: diagnostic cause outputs, cache/store diagnostic classifiers, prediction timeout phase instrumentation, arbiter-state mirror, flash-code sequencing, and associated USER multi-group display state. Normal `LED_USER = mpeg2_new_normal_user_led` acceptance is restored. No Commit-162 source file is changed by this cleanup.

A cross-baseline GitHub comparison provides the strongest scope check: comparing accepted pre-investigation Commit 152 `c49a9e5cf0becea550984050b9e44d9bb0cfa17a` directly to Commit 163 reports exactly two changed files, `MediaPlayer_top_00.svh` (+6/-1) and `MediaPlayer_top_05.svh` (+72/-0). Those are precisely the Commit-162 destination-ownership pacing changes. Therefore the entire Commits 153-161 diagnostic source layer has been removed while the accepted functional correction remains intact.

Commit-142 `[17:16]` DDR display-write exclusion, Commit-139/145 B scratch and presentation ordering, the 68-DSP shared-IDCT baseline, reference ownership/publication behavior, parser/prediction arithmetic, DDR arbiter behavior, generators, QIP/SDC, and Audio-fork comments remain preserved. The cleanup does not weaken the display-write protection that exposed the original ownership race.

Exact `1370c28_build_logs.tar.gz` was inspected from the Google Drive project folder. Quartus Prime 17.0.2 Build 602 completed successfully for Cyclone V `5CSEBA6U23I7` at 2026-08-16 01:05 local. Fitter utilization is 31,782 / 41,910 ALMs (76%), 43,812 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSPs (61%), and 3 / 6 PLLs (50%). Setup endpoint TNS is zero. Global worst setup is +0.167 ns; decoder same-clock reports 0/100 violations with worst +1.311 ns; video same-clock reports 0/80 violations with worst +6.987 ns, hold +0.248 ns, recovery +4.117 ns, removal +0.704 ns, minimum pulse-width +0.462 ns. Structural timing remains `no_clock=3094`, `multiple_clock=86`, `virtual_clock=1`, `no_input_delay=14`, `no_output_delay=129`, `loops=0`, and `latches=0`.

Hardware validation passes completely. The user reports **everything passes** after the requested Commit-163 matrix: repeated `test_p_consecutive_reference.m2v` stress remains clean with normal USER acceptance, and the four standing guards pass: `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v`. This proves the accepted Commit-162 ownership-pacing correction remains effective after complete retirement of the Commits 153-161 diagnostic source layer. Commit 163 is the accepted cleaned post-investigation functional baseline.

The inspected `1370c28_build_logs.tar.gz` package was moved into the existing Google Drive project `archives` folder. The active project folder was re-enumerated afterward and contains only the `archives` folder. Do not re-open the archived package without explicit user approval.

The MiSTer-Media-Player-Audio compatibility check remains unavailable because the project core has no configured Audio GitHub repository.

#### Next Steps:

Preserve exact Commit 163 as the cleaned functional baseline. The next proposed engineering boundary is release qualification. Before assigning a Semantic Version, tag, or GitHub Release, follow the project release procedure beginning with a clean/from-scratch Quartus build and the full regression test suite, then commit those release-qualification results and update project documentation. Do not assign a release version or create release metadata until the user explicitly approves the release milestone/boundary.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [x] Passed — accepted cleaned post-investigation functional baseline; consecutive-P stress and all four standing guards pass with normal USER acceptance

---

## 164 COMMIT v0.4.0 cf9ec63 2026-08-16T01:55:28-07:00

#### Coming From:

Unreleased 1370c28

#### Purpose:

Record the accepted v0.4.0 clean-build and MiSTer hardware release-qualification evidence in the public release-notes document without changing active RTL, source lists, constraints, generators, or synthesized behavior.

#### Outcome:

Exact GitHub master commit `cf9ec63a47ffa4fea8b6525190a0cfa39e7ba0b6` (`Record v0.4.0 qualification`) is exactly one documentation-only commit ahead of hardware-qualified RTL baseline `1370c28e3d34b1fd603c17130986bc336da29a32`. It modifies only `docs/RELEASE_NOTES_v0.4.0.md`.

The release notes now describe v0.4.0 as the hardware-proven progressive 4:2:0 I/P/B development milestone rather than the stale generalized-P-only candidate. They record the established continuous I path, generalized P path, bounded forward/backward/bidirectional B reconstruction and presentation path, separate B scratch DDR region, two-bit DDR region identity protection, P destination-ownership pacing, the 68-DSP shared-IDCT baseline, and retirement of the temporary consecutive-P diagnostic layer.

Release qualification was performed from a fresh clone of exact `1370c28` on Quartus Prime 17.0.2 Lite for Cyclone V `5CSEBA6U23I7`. The newly uploaded active-folder package `1370c28_build_logs.tar.gz` (Drive file id `1eWubmp2fSkE5D_v4VlZuWH1-nVbHLrMH`, created 2026-08-16T08:48:44.672Z) is distinct from the earlier Commit-163 acceptance archive. Quartus Flow and Fitter are successful. Fitter utilization is 31,782 / 41,910 ALMs (76%), 43,812 registers, 461,345 / 5,662,720 block-memory bits (8%) in 73 / 553 RAM blocks (13%), 68 / 112 DSPs (61%), and 3 / 6 PLLs (50%). Setup endpoint TNS is zero; global worst setup is +0.167 ns; decoder same-clock is +1.311 ns with 0/100 violations; video same-clock is +6.987 ns with 0/80 violations; hold +0.248 ns; recovery +4.117 ns; removal +0.704 ns; minimum pulse-width +0.462 ns. The established incomplete external-I/O constraint warning class is unchanged.

The user reports the full release-qualification hardware matrix passes: `test_p_consecutive_reference.m2v` passes 20 consecutive runs with normal USER acceptance, and `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v` each pass. This accepts exact `1370c28` as the v0.4.0 hardware-qualified RTL baseline.

The exact qualification package was moved into the Google Drive project `archives` folder after inspection. The active project folder was re-enumerated and contains only `archives`. Do not re-open the archived package without explicit user approval.

The user explicitly instructed that no second Quartus build is required after the documentation-only release commits. Therefore this commit inherits the accepted `1370c28` synthesized RTL qualification; it was not separately rebuilt.

#### Next Steps:

Update `README.md` and `CHANGELOG.md` to describe the same qualified v0.4.0 I/P/B milestone. Keep the next commit documentation-only. After documentation closure, the user must replace the historical `v0.4.0` annotated tag target with the final documentation commit and create the GitHub v0.4.0 pre-release. Do not create another build after the documentation commit per explicit user instruction.

#### Files Modified:

- docs/RELEASE_NOTES_v0.4.0.md

#### Status:

- [x] Built — exact underlying `1370c28` RTL release qualification accepted; documentation-only commit intentionally not rebuilt
- [x] Passed — full release-qualification hardware matrix accepted and recorded

---
## 165 COMMIT v0.4.0 b4385fe 2026-08-16T01:56:38-07:00

#### Coming From:

v0.4.0 cf9ec63

#### Purpose:

Complete the v0.4.0 documentation boundary by reconciling the project README and changelog with the hardware-qualified I/P/B baseline, while leaving the accepted synthesized RTL unchanged.

#### Outcome:

Exact GitHub master commit `b4385fe4ec62587df701c160333a81ea367c5659` (`Prepare v0.4.0 release`) is exactly one documentation-only commit ahead of Commit 164 `cf9ec63a47ffa4fea8b6525190a0cfa39e7ba0b6`. It modifies only `README.md` and `CHANGELOG.md`.

`README.md` no longer claims B pictures are future work. It now documents the bounded hardware-proven B path, B scratch DDR storage, display-order reordering, P destination-ownership pacing, current 128x96 P/B regression envelope, the two retained I/P reference banks plus distinct B scratch region, the current five-stream regression set, and the v0.4.0 hardware-qualified baseline `1370c28`.

`CHANGELOG.md` keeps a fresh `Unreleased` section and rewrites the v0.4.0 milestone heading to `2026-08-16`, recording generalized P decoding, hardware-proven B forward/backward/bidirectional reconstruction and presentation, two-bit DDR region protection, repeated mixed I/P/B behavior, shared-IDCT DSP consolidation, the consecutive-P ownership-race correction, diagnostic retirement, exact release-qualification hardware coverage, and final Quartus resource/timing results.

A direct GitHub comparison from hardware-qualified `1370c28` to final documentation commit `b4385fe` reports exactly two commits and exactly three modified files: `docs/RELEASE_NOTES_v0.4.0.md`, `README.md`, and `CHANGELOG.md`. No RTL, QIP, SDC, generator, top-level integration, DDR logic, decoder logic, or synthesized source changed after the accepted clean build.

The historical annotated `v0.4.0` tag was replaced successfully. GitHub now reports annotated tag object `6a5ef0b72a83a8be8a9ef5d6e1b20ec79f81bae1`, created 2026-08-16T09:01:12Z with message `MiSTer Media Player v0.4.0`, resolving to exact final documentation commit `b4385fe4ec62587df701c160333a81ea367c5659`. GitHub `master` is also exactly `b4385fe4ec62587df701c160333a81ea367c5659`, so the release tag and branch tip are aligned.

The GitHub v0.4.0 Release was published successfully as pre-release id `371279076` at 2026-08-16T09:04:43Z with title `MiSTer Media Player v0.4.0`, tag `v0.4.0`, and the prepared v0.4.0 release notes. The release is not a draft and remains marked prerelease, matching the project milestone convention.

The Release has one expected binary asset, `MediaPlayer_20260816.rbf`, asset id `516633665`, size 3,190,012 bytes, with GitHub-reported SHA-256 `d53534ae91af8e40ec166009918e09364d208c4a8355322a82cf197644b477bf`. The archived `1370c28_build_logs.tar.gz` qualification package intentionally contains reports only and does not include the RBF, so the published asset digest cannot be independently cross-compared against the archived qualification package. The release metadata, filename, upload state, and GitHub digest are all present and internally consistent.

Per explicit user instruction, no second build was performed after this documentation-only commit. The accepted release binary remains the user-built artifact from the exact `1370c28` fresh-clone qualification; no RTL changed between that hardware-qualified baseline and the tagged documentation commit.

The MiSTer-Media-Player-Audio compatibility check remains unavailable because `core.md` has no configured Audio GitHub repository.

#### Next Steps:

v0.4.0 release closure is complete. Preserve tag `v0.4.0`, final documentation commit `b4385fe4ec62587df701c160333a81ea367c5659`, and hardware-qualified RTL baseline `1370c28e3d34b1fd603c17130986bc336da29a32` as the published milestone. Resume new development only from current `master` under a new approved engineering boundary; do not rewrite the published v0.4.0 tag or Release except for explicit release-maintenance work.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built — exact underlying `1370c28` RTL release qualification accepted; documentation-only commit intentionally not rebuilt
- [x] Passed — v0.4.0 tag and GitHub pre-release publication verified; expected binary asset present

---
## 166 COMMIT Unreleased 74535ad 2026-08-16T04:19:33-07:00

#### Coming From:

Unreleased bc37008

#### Purpose:

Widen the generalized progressive 4:2:0 P-picture hardware path from the fixed 128x96 / 8x6-macroblock regression geometry to the established 720x480 frame envelope without weakening the accepted v0.4.0 DDR ownership, publication, B-reorder, IDCT, or pacing behavior.

#### Outcome:

Exact GitHub master source commit `74535adb3574ef71a00e39e806816929ec3facdd` (`Widen generalized P geometry`) is one functional commit ahead of the Commit-166 proposal metadata commit `6018b0095ee7b596dd3ff300ee048e6ff7bc8d23`. Pre-publication comparison reports exactly seven intended paths and no top-level, B-engine, SDC, `.ai`, DDR-protection, publication, or presentation-scheduler changes.

Commit 166 preserves the hardware-qualified 128x96 generalized-P parser as a compatibility path and adds `mpeg2_h262_p_wide_motion_syntax_probe.sv` for progressive 4:2:0 P frame pictures above that legacy envelope through 720x480. The wide parser derives macroblock geometry from the sequence dimensions, buffers one slice row at a time, follows H.262 macroblock-address progression, emits one ordered motion event for every macroblock, and explicitly emits zero-vector events for skipped P macroblocks. This replaces the proposed 1350-entry packed whole-picture interface with a streamed syntax-to-execution handoff.

The shared P residual pipeline is extended rather than duplicated. Wide sparse residual descriptors carry an 11-bit macroblock index through a two-word sideband while the established non-intra IQ/IDCT datapath and 16-block spatial residual buffer are reused. The existing implementation limits of at most 16 coded residual blocks and 64 non-zero coefficient events per picture remain unchanged and are not H.262 limits.

The generalized P raster engine now derives execution geometry through 45x30 macroblocks and retains ordered motion words in an M10K-oriented 1350x16 motion store with no reset loop. Reference and destination addressing preserve the established fixed 720-luma/360-chroma DDR row layout. The reference wrapper broadens only generalized-P sideband detection to the supported frame envelope; B detection and the historical aligned-plan adapter remain restricted to their proven 128x96 paths. `files.qip` changes only to register the new SystemVerilog source.

A deterministic generator `tools/streams/generate_test_p_720x480_general_decode.py` was added. Agent-side FFmpeg/FFprobe validation succeeds on the generated 720x480 I/P/I elementary stream: 45x30 = 1350 macroblocks, forward f_code=(3,3), two internal skipped P macroblocks, safe interior signed half-sample motion, and one sparse Y residual block. The generated `.m2v` remains local-only and is not committed. This software-side generator check is not FPGA build or MiSTer hardware acceptance.

No B-picture geometry, H.222.0/PES, audio, interlaced picture structure, non-4:2:0 chroma, DDR display-write protection, reference-publication semantics, consecutive-P destination pacing, SDC constraints, or release metadata is changed by this boundary. MiSTer-Media-Player-Audio compatibility remains unavailable because `core.md` has no configured Audio repository.

#### Next Steps:

Pull current `master`. Run `python3 tools/streams/generate_test_p_720x480_general_decode.py`, then perform a clean/from-scratch Quartus Prime 17.0.2 build. Place the build logs in `.ai/current_results` as `74535ad_build_logs.tar.gz`. On hardware run `test_p_720x480_general_decode.m2v`, repeated `test_p_consecutive_reference.m2v`, `test_p_general_decode.m2v`, `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, and `test_all_i.m2v`. Report USER behavior and any load/stall/crash or visible reconstruction anomaly before further source work.

#### Files Modified:

- files.qip
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_p_720x480_general_decode.py

#### Status:

- [ ] Built — exact Commit 166 source not yet Quartus-validated
- [ ] Passed — exact Commit 166 source not yet hardware-validated
