## 150 COMMIT v0.5.0-cycle 4469220 2026-08-15T16:57:25-07:00

#### Coming From:

v0.5.0-cycle 0cbafd8

#### Purpose:

Add comments-only Audio-fork jumping-off points without changing FPGA behavior or establishing a permanent integration ABI.

#### Outcome:

Exact GitHub master commit `44692208170113ed5fc35877e4ec2c16d2b04e08` modifies only `MediaPlayer_top_00.svh` with 35 comment lines. Five `AUDIO_FORK_POINT[...]` anchors identify PCM output, stream split/demux, clock/reset, DDR-client integration, and system-level integration guidance while preserving the video-private H.262 path.

Executable RTL is identical to hardware-accepted Commit 149. Commit 150 was not separately rebuilt.

#### Next Steps:

Preserve the Audio comments in subsequent source baselines.

#### Files Modified:

- MediaPlayer_top_00.svh (comments only)

#### Status:

- [ ] Built — comments-only; executable state equals built Commit 149
- [ ] Passed

---
## 151 COMMIT v0.5.0-cycle f05d07d 2026-08-15T17:22:51-07:00

#### Coming From:

v0.5.0-cycle 4469220

#### Purpose:

Attempt one final ALM-focused IDCT cleanup without changing arithmetic, DDR ownership, B ordering, Audio comments, or the 68-DSP ceiling.

#### Outcome:

Exact GitHub master commit `f05d07d326f4f0bc224695ed979d77570cf3c7d5` modifies only `rtl/mpeg2_new/mpeg2_h262_idct.sv` (+6/-21), removing reset/block-start writes believed unreachable under the complete-64-coefficient caller contract.

Build validation is clean but misses the resource objective: 31,828 ALMs, 42,873 registers, 461,345 block-memory bits, 68 DSPs, 3 PLLs. ALMs increase by 150 versus the prior executable baseline.

Repeated `test_p_consecutive_reference.m2v` is intermittent at approximately 50/50 and can crash the MiSTer. Commit 151 is rejected regardless of the clean build.

#### Next Steps:

Revert only the Commit-151 IDCT-clear removal and retest consecutive P.

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

Restore the stable Commit-150/149 IDCT storage/reset behavior while preserving the 68-DSP consolidation and Audio handoff comments.

#### Outcome:

Exact GitHub master commit `c49a9e5cf0becea550984050b9e44d9bb0cfa17a` exactly reverses Commit 151 and restores the Commit-150 source tree.

The clean build returns to the expected resource/timing shape, but repeated `test_p_consecutive_reference.m2v` still intermittently stalls/crashes while the other four standing streams pass. This proves Commit 151 did not create the underlying instability and invalidates the assumption that the earlier baseline was reliably stable under repeated consecutive-P stress.

Build evidence and the crash photograph were archived.

#### Next Steps:

Stop resource optimization and instrument the consecutive-P failure before attempting a functional correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv (exact Commit-151 revert)

#### Status:

- [x] Built
- [ ] Passed — REJECTED: consecutive-P instability remains

---
## 153 COMMIT v0.5.0-cycle 99c7519 2026-08-15T18:24:58-07:00

#### Coming From:

v0.5.0-cycle c49a9e5

#### Purpose:

Instrument the intermittent consecutive-P stall with an observer-only USER-LED progress trace without changing decode behavior.

#### Outcome:

Exact GitHub master commit `99c7519ed99021eb39b692d8451757044a15d147` modifies only `MediaPlayer_top_07.svh` (+211/-2). The observer distinguishes generalized replay, DDR reconstruction/persistence, publication, and stream release while remaining functionally passive.

Trace codes are 1..10 progress, 11 publication error, 12 prediction/reference-pipeline error, 13 DDR store/cache error, and 14 frontend/IQ/IDCT/reconstruction error.

Repeated hardware testing cleanly separates **10** on pass from **12** on failure. Code 12 proves the failure reaches the prediction/reference pipeline but is still too broad for correction.

#### Next Steps:

Refine code 12 into a first generalized-P error class without changing function.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — diagnostic separates pass/failure; functional instability unresolved

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

Refine code 13 into DDR store/cache first-fault classes and preserve prediction-error ordering without changing decode behavior.

#### Outcome:

Exact GitHub master commit `dbd0993e78d187a5aee57a3edcb567bd0c558c28` adds observer-only cause visibility to the DDR writer, framebuffer cache, and top-level trace. Codes 15..22 are store/cache causes without prior prediction error; 23..30 are the same causes with prediction already present or coincident.

Analysis & Synthesis fails because `MediaPlayer_top_04.svh` connects the new port to `mpeg2_h262_ddram_store`, while Quartus compiles that entity from `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`; the observer was added to an unused sibling. No hardware diagnostic exists for this commit. Failed build resources were archived.

#### Next Steps:

Move only the observer hookup to the active `_420p.sv` writer implementation.

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

Attach the Commit-155 writer diagnostic to the active Quartus writer implementation without changing writer behavior.

#### Outcome:

Exact GitHub master commit `ebd3ead1316691d3032a33ada7654bf1a98c53bf` moves the observer to active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`; functional writer state and DDR behavior are unchanged.

Build validation is clean: 31,910 ALMs, 43,934 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.558 ns.

Repeated consecutive-P runs produce **10** on pass and **23** on crash. Code 23 means writer cause 1 (`block_start` overlap with active capture/flush/write) with prediction error already present or coincident. All four standing guard streams pass. The build package was inspected and archived.

#### Next Steps:

Refine code 23 into exact writer state, DDR-busy state, and prediction-before/coincident ordering.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:

- [x] Built
- [x] Passed — diagnostic boundary complete; functional stability unresolved

---
## 157 COMMIT Unreleased 177a480 2026-08-15T21:16:37-07:00

#### Coming From:

Unreleased ebd3ead

#### Purpose:

Refine code 23 into exact writer state, DDR-busy state, and prediction-before/coincident ordering without changing decode behavior.

#### Outcome:

Exact GitHub master commit `177a4800820560d13610d03f4f14c6e55d71163b` modifies `MediaPlayer_top_07.svh` (+82/-47) and active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv` (+9/-4). The observer distinguishes capture, flush, write+flush with DDR busy low/high, and several invalid writer conditions; it also records whether prediction error preceded or coincided with the overlap.

Internal result codes 31..38 preserve the required evidence, but the commit was intentionally superseded before build because counting that many USER flashes was not practical.

#### Next Steps:

Keep the observer encoding and replace only its USER presentation with a readable grouped display.

#### Files Modified:

- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:

- [ ] Built — superseded before build
- [ ] Passed

---
## 158 COMMIT Unreleased 5740587 2026-08-15T21:24:27-07:00

#### Coming From:

Unreleased 177a480

#### Purpose:

Make the Commit-157 diagnostic human-readable on the USER LED without changing its evidence or decoder behavior.

#### Outcome:

Exact GitHub master commit `5740587427e3dda356eaa316ced0fbfab7b258d6` modifies only `MediaPlayer_top_07.svh` (+40/-5). Internal codes 31..38 are unchanged; USER now presents writer state and prediction ordering as two short groups.

Build validation is clean: 31,944 ALMs, 43,942 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.220 ns.

Hardware failure reports **4-1**: writer overlap occurs in write-active+flush while writer-visible DDR busy is high, and prediction error was already present earlier. Therefore prediction/reference failure precedes the writer overlap. The build archive was inspected and archived.

#### Next Steps:

Identify the first prediction/reference-pipeline failure class present before the later writer overlap.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed — diagnostic captured 4-1; functional stability unresolved

---
## 159 COMMIT Unreleased a5b518d 2026-08-15T21:55:32-07:00

#### Coming From:

Unreleased 5740587

#### Purpose:

Identify the first generalized-P prediction/reference failure class already present before the proven writer overlap.

#### Outcome:

Exact GitHub master commit `a5b518d045bb035748cb668f797ba4187a84bcba` modifies only `MediaPlayer_top_07.svh` (+114/-8). The top-level observer decodes the existing generalized-P first-error carrier: 1 metadata/order, 2 start prerequisites, 3 source bounds, 4 unsolicited DDR response, 5 persistence mismatch, 6 timeout, 7 residual accounting, 8 other.

Failing `test_p_consecutive_reference.m2v` runs report **2-2-4**: generalized-P cause 6 (prediction transaction timeout) occurs before the later writer state-4 overlap. Passing runs report **10**, and all four standing guard streams pass.

Build validation is clean: 32,011 ALMs, 44,079 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.120 ns. The build package was inspected and archived.

#### Next Steps:

Refine timeout cause 6 to record the active prediction transaction phase when the watchdog expires.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — timeout identified first; functional consecutive-P stability unresolved

---
## 160 COMMIT Unreleased 1efbb4b 2026-08-15T23:31:10-07:00

#### Coming From:

Unreleased a5b518d

#### Purpose:

Refine generalized-P timeout cause 6 so the failing transaction identifies which prediction phase stopped making progress.

#### Outcome:

Exact GitHub master commit `1efbb4b328a933a31a350213f7ffdadd669c82cd` modifies only `rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv` (+50/-16). Observer-only state records timeout phase: 1 request issue/accept, 2 DDR response wait, 3 reconstructed output/store completion, 4 persistence readback. Functional control is unchanged.

Build validation is clean: 32,031 ALMs, 43,911 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.141 ns.

Failing hardware reports **1-3-4**. Phase 3 proves the generalized-P engine has completed reconstruction/output and is waiting for ordinary DDR store completion; the later writer state remains 4. This narrows the stall to the reconstructed-block -> DDR-store completion handshake, but not yet to a specific arbiter denial reason.

#### Next Steps:

Classify the DDR-arbiter condition holding the writer during the phase-3 timeout.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [ ] Passed — phase-3 store-completion stall localized; functional stability unresolved

---
## 161 COMMIT Unreleased 5d8c8ba 2026-08-15T23:59:26-07:00

#### Coming From:

Unreleased 1efbb4b

#### Purpose:

Classify the DDR-arbiter condition holding the ordinary reconstruction writer during the Commit-160 phase-3 timeout.

#### Outcome:

Exact GitHub master commit `5d8c8ba7073ea1273ff0aa7df1a074b86ca83a64` modifies only `MediaPlayer_top_07.svh` (+110/-1). A passive arbiter mirror distinguishes: 1 display-region ownership exclusion, 2 display read priority, 3 prediction read priority, 4 writer granted but physical DDR busy. Functional arbitration is unchanged.

Build validation is clean: 32,034 ALMs, 44,006 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.589 ns.

Failing hardware reports **2-1-4**: the first stall reason is display-region ownership exclusion. Source review shows the next P destination bank can still be the displayed bank because reference publication precedes display-bank handoff. Commit-142 protection is therefore working correctly and must not be weakened.

#### Next Steps:

Pace a following P picture until its selected destination bank is no longer display-owned, preserving existing B behavior and DDR protection.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed — root cause localized to display-region ownership race; functional stability unresolved

---
## 162 COMMIT Unreleased 42d330f 2026-08-16T00:25:40-07:00

#### Coming From:

Unreleased 5d8c8ba

#### Purpose:

Correct the consecutive-P publication-versus-presentation ownership race by pacing only a following P picture until its destination bank is no longer display-owned.

#### Outcome:

Exact GitHub master commit `42d330fffe8555cbaea01d5d002680fb4ab20acf` modifies `MediaPlayer_top_00.svh` (+6/-1) and `MediaPlayer_top_05.svh` (+72/-0). A registered `mpeg2_new_p_destination_ownership_hold` is added to stream readiness and is armed from accepted picture-header classification only for a following P picture. B and I pictures continue without this hold.

Commit-142 display-write exclusion, the DDR arbiter/writer, reference publication, B scratch/reorder behavior, QIP, SDC, and generators are unchanged.

Build validation is clean: 31,922 ALMs, 43,946 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.332 ns.

Hardware validation passes completely: repeated `test_p_consecutive_reference.m2v` no longer stalls/crashes and all four standing guard streams pass. Commit 162 is the accepted functional fix.

#### Next Steps:

Retire the temporary Commits 153-161 diagnostic layer and retest the cleaned baseline.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh

#### Status:

- [x] Built
- [x] Passed — consecutive-P fix accepted; all standing guards pass

---
## 163 COMMIT Unreleased 1370c28 2026-08-16T00:51:40-07:00

#### Coming From:

Unreleased 42d330f

#### Purpose:

Retire the temporary consecutive-P diagnostics while preserving the accepted Commit-162 pacing correction.

#### Outcome:

Exact GitHub master commit `1370c28e3d34b1fd603c17130986bc336da29a32` restores the seven diagnostic files changed by Commits 153-161 to their pre-investigation contents, removing 716 lines of observer code. A direct comparison from Commit 152 to Commit 163 shows only the two Commit-162 pacing files remain changed.

Normal USER acceptance is restored. Commit-142 DDR protection, B ordering, shared-IDCT consolidation, reference publication, parser/prediction arithmetic, and Audio comments remain preserved.

Build validation is clean: 31,782 ALMs, 43,812 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS and global setup +0.167 ns.

Repeated consecutive-P stress and all four standing guard streams pass. Commit 163 is the accepted cleaned post-investigation functional baseline. Build evidence was archived.

#### Next Steps:

Use exact Commit 163 for v0.4.0 release qualification.

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
- [x] Passed — cleaned baseline accepted

---
## 164 COMMIT v0.4.0 cf9ec63 2026-08-16T01:55:28-07:00

#### Coming From:

Unreleased 1370c28

#### Purpose:

Record the accepted v0.4.0 clean-build and hardware qualification in the public release notes without changing synthesized source.

#### Outcome:

Exact GitHub master commit `cf9ec63a47ffa4fea8b6525190a0cfa39e7ba0b6` modifies only `docs/RELEASE_NOTES_v0.4.0.md`. The notes describe the qualified progressive 4:2:0 I/P/B milestone, including B scratch/reorder behavior, DDR region protection, P destination pacing, shared-IDCT consolidation, and diagnostic retirement.

Release qualification used a fresh clone of exact `1370c28` on Quartus Prime 17.0.2 Lite. Results: 31,782 ALMs, 43,812 registers, 461,345 block-memory bits in 73 RAM blocks, 68 DSPs, 3 PLLs; zero setup TNS, global setup +0.167 ns, decoder +1.311 ns, video +6.987 ns.

Hardware qualification passes: `test_p_consecutive_reference.m2v` passes 20 consecutive runs and `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v` each pass. The qualification package was inspected and archived.

Per user instruction, documentation-only release commits were not rebuilt.

#### Next Steps:

Update README/changelog and complete the v0.4.0 tag/release metadata without another build.

#### Files Modified:

- docs/RELEASE_NOTES_v0.4.0.md

#### Status:

- [x] Built — underlying `1370c28` qualification accepted
- [x] Passed — full release matrix accepted

---
## 165 COMMIT v0.4.0 b4385fe 2026-08-16T01:56:38-07:00

#### Coming From:

v0.4.0 cf9ec63

#### Purpose:

Complete v0.4.0 documentation and release publication while leaving the qualified RTL unchanged.

#### Outcome:

Exact GitHub master commit `b4385fe4ec62587df701c160333a81ea367c5659` modifies only `README.md` and `CHANGELOG.md`, updating them to the qualified I/P/B milestone and preserving a fresh `Unreleased` section.

The annotated `v0.4.0` tag resolves to `b4385fe`, and the GitHub v0.4.0 pre-release is published with the expected `MediaPlayer_20260816.rbf` asset. No RTL, QIP, SDC, generator, DDR, or decoder source changed after qualified Commit 163.

Per user instruction, no second build was performed after the documentation-only release commits.

#### Next Steps:

Preserve the published v0.4.0 milestone and resume development only under a new approved boundary.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built — underlying `1370c28` qualification accepted
- [x] Passed — tag, prerelease, and binary asset verified

---
## 166 COMMIT Unreleased 74535ad 2026-08-16T04:19:33-07:00

#### Coming From:

Unreleased bc37008

#### Purpose:

Widen generalized progressive 4:2:0 P-picture decoding from the fixed 128x96 regression geometry to the established 720x480 frame envelope while preserving accepted DDR ownership, publication, B ordering, IDCT, and pacing behavior.

#### Outcome:

Exact GitHub master functional commit `74535adb3574ef71a00e39e806816929ec3facdd` modifies seven intended paths. It adds a streamed wide-P syntax parser, expands macroblock geometry through 45x30, stores ordered motion in a 1350x16 M10K-oriented memory, and extends sparse residual metadata to 11-bit macroblock indices while retaining the existing 16-block / 64-coefficient-event implementation limits.

A deterministic `test_p_720x480_general_decode` generator was added. The generated stream contains 45x30 macroblocks, signed half-sample motion, internal skipped P macroblocks, and sparse residual data. B geometry and accepted DDR/presentation behavior are unchanged.

Clean Quartus validation: 36,957 / 41,910 ALMs (88%), 45,721 registers, 487,041 block-memory bits in 78 RAM blocks, 70 DSPs, 3 PLLs; zero setup TNS, global setup +0.270 ns, decoder +0.674 ns, video +6.977 ns. The 1350x16 motion store maps to four M10Ks. The new wide parser itself uses about 4,696 ALMs and two DSPs.

All six required hardware regressions pass: the new 720x480 P stream, repeated consecutive-P, legacy generalized P, mixed-GOP B, B core, and all-I. Audio-repo comparison finds no conflicting independent edits in overlapping Commit-166 paths.

#### Next Steps:

Recover generalized-P parser resources before widening B geometry; 88% ALM utilization is too close to capacity.

#### Files Modified:

- files.qip
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_p_720x480_general_decode.py

#### Status:

- [x] Built — timing closes at 88% ALM utilization
- [x] Passed — all six requested P/B/I regressions pass

---
## 167 COMMIT Unreleased b11590c 2026-08-16T05:31:18-07:00

#### Coming From:

Unreleased 74535ad

#### Purpose:

Recover FPGA headroom by consolidating the duplicate generalized-P syntax implementations onto the Commit-166 streamed parser without expanding B-picture capability.

#### Outcome:

Exact functional commit `b11590cf77febb7364a13e628a64e107fc2a8620` consolidates exact 128x96 and wider <=720x480 P syntax onto the streamed parser and leaves the historical packed-plan parser as a constant-zero compatibility shell.

Quartus 17.0.2 build validation is clean: 30,771 / 41,910 ALMs (73%), 41,381 registers, 486,017 block-memory bits in 77 RAM blocks, 69 DSPs, 3 PLLs; zero setup TNS and global setup +0.579 ns. Relative to Commit 166 this recovers 6,186 ALMs, 4,340 registers, one RAM block, and one DSP.

Hardware passes `test_p_720x480_general_decode.m2v`, `test_p_general_decode.m2v`, `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, and `test_all_i.m2v`. `test_p_consecutive_reference.m2v` fails with normal USER indication absent but without the historical crash. Because Commit 166 and the v0.4.0 baseline passed repeated consecutive-P, Commit 167 is not accepted as functionally complete. Build evidence was archived under transitional build hash `b1a0b0f`.

#### Next Steps:

Restore exact 128x96 consecutive-P compatibility without giving back the parser-consolidation resource recovery.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh

#### Status:

- [x] Built — resource-recovery objective met
- [ ] Passed — consecutive-P regression; no crash

---
## 168 COMMIT Unreleased 0ea9ac5 2026-08-16T07:45:00-07:00

#### Coming From:

Unreleased b11590c

#### Purpose:

Restore consecutive-reference P acceptance after the generalized-P parser consolidation without giving back the recovered FPGA headroom.

#### Outcome:

Exact functional commit `0ea9ac55723d10812bbf0f4ac0b01ecf2a3df0b0` modifies only `rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv` (+8/-0), retaining an already-observed streamed-motion transaction across wide-picture completion so motion-only P can accept its persistence completion.

Quartus 17.0.2 validation is clean: 30,751 / 41,910 ALMs (73%), 41,338 registers, 486,017 block-memory bits in 77 RAM blocks, 69 DSPs, 3 PLLs; zero setup TNS and global setup +0.644 ns. All six requested hardware regressions pass, including repeated `test_p_consecutive_reference.m2v` and the 720x480 generalized-P stream. Audio compatibility is clean; the only cumulative overlapping post-fork path is `files.qip`, where main and Audio add independent source entries.

#### Next Steps:

Use the restored 73% baseline to widen the remaining fixed-geometry B path.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv

#### Status:

- [x] Built
- [x] Passed — all six requested P/B/I regressions pass

---
## 169 COMMIT Unreleased ac1ddaf 2026-08-16T07:52:00-07:00

#### Coming From:

Unreleased 0ea9ac5

#### Purpose:

Widen progressive 4:2:0 B-picture decoding from the fixed 128x96 / 8x6 implementation to the established <=720x480 frame envelope while preserving accepted two-reference prediction, non-reference scratch-frame semantics, and qualified P/I behavior.

#### Outcome:

Exact functional commit `ac1ddaf393a09c7b2733657a84940f227cd1a63a` (`Widen generalized B geometry`) modifies exactly four B-path RTL files plus one deterministic regression generator. B syntax now derives geometry through 45x30 macroblocks and streams ordered direction/vector metadata during slice parsing rather than scaling the historical whole-picture register plan. The B raster retains the metadata in a 1350x34 M10K-oriented motion store, uses live padded luma/chroma bounds, and keeps the existing four-block Y0 residual ceiling.

The DDR writer adds a wide internal B-scratch coordinate tag while retaining the legacy 128x96 tag; both forms still target only the existing non-reference scratch region. The reference wrapper admits B sideband detection throughout the same <=720x480 geometry envelope. DDR arbitration, reference publication, P behavior, IDCT, QIP, SDC, and top-level presentation control are unchanged.

Agent-side generator validation passes with FFmpeg/ffprobe: `test_b_720x480_mixed_gop.m2v` is 187,087 bytes, SHA-256 `7c9ab2a9444789b16ef64bbf8a483bda743a7a29caf4de5d8e7e97e8862e5530`, coded order I/P/B/P/B, display order I/B/P/B/P, 45x30 macroblocks, safe signed half-sample B motion, internal skips, and bounded residuals. Quartus and MiSTer hardware validation are pending.

#### Next Steps:

Pull exact `ac1ddaf`, run a clean Quartus/STA build, then run `test_b_720x480_mixed_gop.m2v` first followed by the complete accepted six-stream P/B/I matrix. Report the build and hardware results before any further source change.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_b_720x480_mixed_gop.py

#### Status:

- [ ] Built
- [ ] Passed