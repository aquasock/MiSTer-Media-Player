## 151 COMMIT v0.5.0-cycle f05d07d 2026-08-15T17:22:51-07:00

#### Coming From:

v0.5.0-cycle 4469220

#### Purpose:

Attempt one final ALM-focused IDCT cleanup without changing arithmetic, DDR ownership, B ordering, Audio comments, or the 68-DSP ceiling.

#### Outcome:

Exact commit `f05d07d326f4f0bc224695ed979d77570cf3c7d5` modifies only `rtl/mpeg2_new/mpeg2_h262_idct.sv`. Build is clean at 31,828 ALMs, 42,873 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs, but ALMs increase by 150 versus the prior executable baseline.

Repeated `test_p_consecutive_reference.m2v` is intermittent and can crash the MiSTer. Commit 151 is rejected.

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

Exact commit `c49a9e5cf0becea550984050b9e44d9bb0cfa17a` exactly reverses Commit 151 and restores the Commit-150 source tree. Repeated `test_p_consecutive_reference.m2v` still intermittently stalls/crashes while the other standing streams pass, proving Commit 151 did not create the underlying instability.

#### Next Steps:

Stop resource optimization and instrument the consecutive-P failure before attempting a functional correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv

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

Exact commit `99c7519ed99021eb39b692d8451757044a15d147` modifies only `MediaPlayer_top_07.svh`. Repeated hardware testing separates pass code **10** from failure code **12**, localizing the failure to the prediction/reference pipeline while remaining functionally passive.

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

Refine the intermittent consecutive-reference P diagnostic so the prediction/reference bucket identifies the first generalized-P engine failure class.

#### Outcome:

Exact commit `ad071ba3380f918b9f4a3734a97cee1f00bf80c5` adds observer-only generalized-P first-error cause visibility. Build is clean at 31,855 ALMs, 43,890 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs with global setup +0.384 ns.

Repeated hardware runs show **10** on pass and **13** on failure. Code 13 indicates DDR store/cache error is present and masks whether a lower-priority prediction cause is also present or first.

#### Next Steps:

Refine code 13 into specific DDR store/cache first-fault classes and preserve prediction-error ordering.

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

Exact commit `dbd0993e78d187a5aee57a3edcb567bd0c558c28` adds observer-only writer/cache cause visibility, but Analysis & Synthesis fails because the new port is connected to an unused writer sibling rather than active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`.

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

Exact commit `ebd3ead1316691d3032a33ada7654bf1a98c53bf` moves the observer to active `rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv`. Build is clean at 31,910 ALMs, 43,934 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs. Failing consecutive-P runs report **23**, meaning writer cause 1 with prediction error already present or coincident.

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

Exact commit `177a4800820560d13610d03f4f14c6e55d71163b` preserves observer-only behavior and records writer state plus prediction ordering. The internal result codes were intentionally superseded before build because the USER presentation was impractical.

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

Exact commit `5740587427e3dda356eaa316ced0fbfab7b258d6` changes only USER presentation. Build is clean at 31,944 ALMs, 43,942 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs. Hardware failure reports **4-1**: writer overlap occurs in write-active+flush while DDR busy is high, and prediction error was already present earlier.

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

Exact commit `a5b518d045bb035748cb668f797ba4187a84bcba` decodes the generalized-P first-error carrier at top level. Failing `test_p_consecutive_reference.m2v` runs report **2-2-4**, identifying generalized-P prediction transaction timeout before the later writer overlap. Build is clean at 32,011 ALMs, 44,079 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs.

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

Exact commit `1efbb4b328a933a31a350213f7ffdadd669c82cd` adds observer-only timeout-phase state. Build is clean at 32,031 ALMs, 43,911 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs. Failing hardware reports **1-3-4**, proving the generalized-P engine is waiting for ordinary DDR store completion after reconstruction/output.

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

Exact commit `5d8c8ba7073ea1273ff0aa7df1a074b86ca83a64` adds a passive arbiter mirror. Build is clean at 32,034 ALMs, 44,006 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs. Failing hardware reports **2-1-4**: display-region ownership exclusion is the first stall reason, proving the existing display-write protection is correctly blocking an unsafe destination bank.

#### Next Steps:

Pace a following P picture until its selected destination bank is no longer display-owned.

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

Exact commit `42d330fffe8555cbaea01d5d002680fb4ab20acf` adds a registered P-only destination-ownership hold. Commit-142 display-write exclusion, DDR arbitration/writer, reference publication, B behavior, QIP, and SDC remain unchanged. Build is clean at 31,922 ALMs, 43,946 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs; repeated consecutive-P and all standing guard streams pass.

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

Exact commit `1370c28e3d34b1fd603c17130986bc336da29a32` restores the seven diagnostic files to their pre-investigation contents while preserving the two Commit-162 pacing changes. Build is clean at 31,782 ALMs, 43,812 registers, 461,345 block-memory bits, 68 DSPs, and 3 PLLs; repeated consecutive-P and all four standing guards pass.

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

Exact commit `cf9ec63a47ffa4fea8b6525190a0cfa39e7ba0b6` modifies only `docs/RELEASE_NOTES_v0.4.0.md`. Release qualification used a fresh clone of exact `1370c28`: 31,782 ALMs, 43,812 registers, 461,345 block-memory bits, 68 DSPs, 3 PLLs, zero setup TNS, global setup +0.167 ns. Consecutive-P passes 20 runs and the mixed-GOP B, B-core, generalized-P, and all-I guards pass.

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

Exact commit `b4385fe4ec62587df701c160333a81ea367c5659` modifies only `README.md` and `CHANGELOG.md`. The annotated `v0.4.0` tag resolves to `b4385fe`, and the GitHub v0.4.0 pre-release is published with the expected `MediaPlayer_20260816.rbf` asset. No synthesized source changed after qualified Commit 163.

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

Widen generalized progressive 4:2:0 P-picture decoding from fixed 128x96 to the established 720x480 frame envelope while preserving accepted DDR ownership, publication, B ordering, IDCT, and pacing behavior.

#### Outcome:

Exact functional commit `74535adb3574ef71a00e39e806816929ec3facdd` adds streamed wide-P syntax, 45x30 macroblock geometry, a 1350x16 M10K-oriented motion store, and 11-bit sparse-residual macroblock indices while retaining 16-block / 64-coefficient-event implementation ceilings. Build is clean at 36,957 ALMs (88%), 45,721 registers, 487,041 block-memory bits, 78 RAM blocks, 70 DSPs, and 3 PLLs.

The deterministic 720x480 P regression plus repeated consecutive-P, generalized P, mixed-GOP B, B core, and all-I all pass.

#### Next Steps:

Recover generalized-P parser resources before widening B geometry.

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

Recover FPGA headroom by consolidating duplicate generalized-P syntax implementations onto the Commit-166 streamed parser without expanding B capability.

#### Outcome:

Exact functional commit `b11590cf77febb7364a13e628a64e107fc2a8620` consolidates exact 128x96 and wider <=720x480 P syntax onto the streamed parser. Quartus is clean at 30,771 ALMs (73%), 41,381 registers, 486,017 block-memory bits, 77 RAM blocks, 69 DSPs, and 3 PLLs, recovering 6,186 ALMs versus Commit 166.

Five hardware streams pass, but `test_p_consecutive_reference.m2v` loses normal USER acceptance without crashing. Commit 167 is not functionally accepted.

#### Next Steps:

Restore exact 128x96 consecutive-P compatibility without giving back parser-consolidation resource recovery.

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

Restore consecutive-reference P acceptance after generalized-P parser consolidation without giving back the recovered FPGA headroom.

#### Outcome:

Exact functional commit `0ea9ac55723d10812bbf0f4ac0b01ecf2a3df0b0` modifies only `rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv`, retaining an already-observed streamed-motion transaction across wide-picture completion so motion-only P can accept persistence completion. Build is clean at 30,751 ALMs (73%), 41,338 registers, 486,017 block-memory bits, 77 RAM blocks, 69 DSPs, and 3 PLLs with global setup +0.644 ns.

All six requested hardware regressions pass, including repeated consecutive-P and 720x480 generalized P.

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

Widen progressive 4:2:0 B-picture decoding from fixed 128x96 / 8x6 to the established <=720x480 frame envelope while preserving two-reference prediction, non-reference scratch semantics, and qualified P/I behavior.

#### Outcome:

Exact functional commit `ac1ddaf393a09c7b2733657a84940f227cd1a63a` widens B syntax/raster geometry through 45x30 macroblocks, streams ordered B motion metadata, retains it in a 1350x34 M10K-oriented store, and widens the internal B scratch-coordinate tag while preserving the existing scratch region and four-block Y0 residual ceiling.

Quartus 17.0.2 validation is clean: 28,106 / 41,910 ALMs (67%), 38,220 registers, 534,989 block-memory bits in 84 RAM blocks, 69 DSPs, and 3 PLLs. Relative to Commit 168 this recovers 2,645 ALMs and 3,118 registers while using 48,972 additional memory bits and seven additional RAM blocks. Setup TNS is zero; worst setup +0.367 ns, hold +0.251 ns, recovery +3.395 ns, removal +0.734 ns, minimum pulse-width +0.462 ns. No flow Error or Critical Warning records are present.

Hardware validation passes completely: `test_b_720x480_mixed_gop.m2v`, `test_p_720x480_general_decode.m2v`, repeated `test_p_consecutive_reference.m2v`, `test_p_general_decode.m2v`, `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, and `test_all_i.m2v` all pass. Latest Audio tip `81219ce` has no independent edits to any Commit-169 RTL path, so compatibility remains clean.

#### Next Steps:

Generalize the remaining B residual syntax/coverage while preserving the accepted 67% geometry/motion baseline.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_b_720x480_mixed_gop.py

#### Status:

- [x] Built
- [x] Passed — new 720x480 B stream plus complete prior six-stream matrix pass

---
## 170 PROPOSAL Unreleased pending 2026-08-16T14:15:00-07:00

#### Coming From:

Unreleased ac1ddaf

#### Purpose:

Generalize progressive 4:2:0 B-picture residual syntax across all six macroblock blocks while preserving the accepted <=720x480 B geometry, two-reference motion path, scratch-frame semantics, and all qualified P/I behavior.

#### Outcome:

The accepted Commit-169 B path still has explicit implementation limits: coded residual macroblocks are restricted to CBP=32 / Y0 only, at most four residual blocks are retained, and coefficient parsing is limited to the controlled +/-1 then EOB subset. These are implementation limits, not H.262 limits. The existing standards library already records the required 4:2:0 block order, coded-block-pattern selection, non-intra coefficient VLC rules, and Escape syntax under H262-006, H262-010, H262-021, and H262-024.

Scope the next hardware boundary to full 4:2:0 six-bit coded-block-pattern selection, residual block indices 0..5, and generalized non-intra coefficient parsing using the established project VLC/transform path. Align B residual storage with the existing bounded generalized-P envelope of up to 16 residual blocks / 64 coefficient events where practical; those remain implementation ceilings. Preserve B motion/geometry, DDR arbitration, reference publication, scratch presentation ordering, P pacing, IDCT arithmetic, QIP, and SDC.

Add a deterministic 720x480 B residual regression that exercises multiple luma and chroma residual blocks, more than one coded block in a macroblock, ordinary non-intra VLC coefficients, EOB, and Escape syntax while retaining safe forward/backward/bidirectional motion. Validation requires a clean Quartus/STA build, the new residual regression first, then the complete seven-stream Commit-169 matrix. If implementation requires changes outside B residual syntax/sideband/raster capacity, stop and revise the proposal before proceeding.

#### Next Steps:

Await user approval before implementation.

#### Files Modified:

- TBD — B residual syntax/core, B raster residual-capacity path, and deterministic 720x480 B residual regression generator only

#### Status:

- [ ] Built
- [ ] Passed