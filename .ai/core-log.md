## 152 COMMIT v0.5.0-cycle c49a9e5 2026-08-15T17:51:47-07:00

#### Coming From:
v0.5.0-cycle f05d07d

#### Purpose:
Restore the pre-151 IDCT behavior.

#### Outcome:
`c49a9e5cf0becea550984050b9e44d9bb0cfa17a` exactly reverses Commit 151. Consecutive-P still intermittently stalls/crashes, proving Commit 151 was not the root cause.

#### Next Steps:
Instrument the consecutive-P failure before functional correction.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_idct.sv

#### Status:
- [x] Built
- [ ] Passed — REJECTED

---
## 153 COMMIT v0.5.0-cycle 99c7519 2026-08-15T18:24:58-07:00

#### Coming From:
v0.5.0-cycle c49a9e5

#### Purpose:
Add observer-only USER-LED progress tracing for consecutive-P instability.

#### Outcome:
`99c7519ed99021eb39b692d8451757044a15d147` changes only `MediaPlayer_top_07.svh`. Hardware separates pass code 10 from failure code 12, localizing failure to prediction/reference pipeline.

#### Next Steps:
Refine code 12 to a first generalized-P error class.

#### Files Modified:
- MediaPlayer_top_07.svh

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
## 154 COMMIT v0.5.0-cycle ad071ba 2026-08-15T18:55:00-07:00

#### Coming From:
v0.5.0-cycle 99c7519

#### Purpose:
Refine prediction/reference diagnostics to first generalized-P failure class.

#### Outcome:
`ad071ba3380f918b9f4a3734a97cee1f00bf80c5` adds observer-only first-error cause visibility. Clean build: 31,855 ALMs, 43,890 registers, 461,345 memory bits, 68 DSPs, 3 PLLs, setup +0.384 ns. Failures report code 13, proving DDR store/cache error is present but masking ordering.

#### Next Steps:
Refine code 13 and preserve prediction-error ordering.

#### Files Modified:
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
## 155 COMMIT v0.5.0-cycle dbd0993 2026-08-15T19:52:00-07:00

#### Coming From:
v0.5.0-cycle ad071ba

#### Purpose:
Refine DDR store/cache first-fault classes.

#### Outcome:
`dbd0993e78d187a5aee57a3edcb567bd0c558c28` adds observer-only writer/cache causes, but Analysis & Synthesis fails because the port was attached to an unused writer sibling rather than active `_420p.sv`.

#### Next Steps:
Move only the observer to active `_420p.sv`.

#### Files Modified:
- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv

#### Status:
- [ ] Built — synthesis failed
- [ ] Passed

---
## 156 COMMIT Unreleased ebd3ead 2026-08-15T20:03:49-07:00

#### Coming From:
Unreleased dbd0993

#### Purpose:
Attach the Commit-155 observer to the active writer.

#### Outcome:
`ebd3ead1316691d3032a33ada7654bf1a98c53bf` moves the observer to active `_420p.sv`. Clean build: 31,910 ALMs, 43,934 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Failure code 23 means writer overlap with prediction error already present/coincident.

#### Next Steps:
Refine exact writer state, DDR busy, and prediction ordering.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
## 157 COMMIT Unreleased 177a480 2026-08-15T21:16:37-07:00

#### Coming From:
Unreleased ebd3ead

#### Purpose:
Refine code 23 into writer state/busy/ordering evidence.

#### Outcome:
`177a4800820560d13610d03f4f14c6e55d71163b` records the required observer evidence, but its USER encoding was intentionally superseded before build.

#### Next Steps:
Replace only USER presentation with readable grouped output.

#### Files Modified:
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv

#### Status:
- [ ] Built — superseded
- [ ] Passed

---
## 158 COMMIT Unreleased 5740587 2026-08-15T21:24:27-07:00

#### Coming From:
Unreleased 177a480

#### Purpose:
Make Commit-157 evidence human-readable on USER LED.

#### Outcome:
`5740587427e3dda356eaa316ced0fbfab7b258d6` changes only USER presentation. Clean build: 31,944 ALMs, 43,942 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Hardware reports 4-1: writer write+flush overlap while DDR busy, with prediction error earlier.

#### Next Steps:
Identify the first prediction/reference failure preceding writer overlap.

#### Files Modified:
- MediaPlayer_top_07.svh

#### Status:
- [x] Built
- [ ] Passed — diagnostic captured 4-1

---
## 159 COMMIT Unreleased a5b518d 2026-08-15T21:55:32-07:00

#### Coming From:
Unreleased 5740587

#### Purpose:
Identify the first generalized-P prediction/reference failure class.

#### Outcome:
`a5b518d045bb035748cb668f797ba4187a84bcba` decodes the first-error carrier. Failures report 2-2-4: generalized-P prediction transaction timeout precedes writer overlap. Clean build: 32,011 ALMs, 44,079 registers, 461,345 memory bits, 68 DSPs, 3 PLLs.

#### Next Steps:
Record timeout transaction phase.

#### Files Modified:
- MediaPlayer_top_07.svh

#### Status:
- [x] Built
- [x] Passed — timeout identified first

---
## 160 COMMIT Unreleased 1efbb4b 2026-08-15T23:31:10-07:00

#### Coming From:
Unreleased a5b518d

#### Purpose:
Refine generalized-P timeout to active transaction phase.

#### Outcome:
`1efbb4b328a933a31a350213f7ffdadd669c82cd` adds observer-only timeout phase. Clean build: 32,031 ALMs, 43,911 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Failure 1-3-4 proves reconstructed output is waiting for ordinary DDR store completion.

#### Next Steps:
Classify the DDR-arbiter condition holding the writer.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:
- [x] Built
- [ ] Passed — phase-3 stall localized

---
## 161 COMMIT Unreleased 5d8c8ba 2026-08-15T23:59:26-07:00

#### Coming From:
Unreleased 1efbb4b

#### Purpose:
Classify the DDR-arbiter condition during the phase-3 stall.

#### Outcome:
`5d8c8ba7073ea1273ff0aa7df1a074b86ca83a64` adds a passive arbiter mirror. Clean build: 32,034 ALMs, 44,006 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Failure 2-1-4 proves display-region ownership exclusion is first; protection is correct.

#### Next Steps:
Pace a following P until its destination bank is no longer display-owned.

#### Files Modified:
- MediaPlayer_top_07.svh

#### Status:
- [x] Built
- [x] Passed — root cause localized

---
## 162 COMMIT Unreleased 42d330f 2026-08-16T00:25:40-07:00

#### Coming From:
Unreleased 5d8c8ba

#### Purpose:
Correct the consecutive-P publication/presentation ownership race.

#### Outcome:
`42d330fffe8555cbaea01d5d002680fb4ab20acf` adds P-only destination ownership pacing while preserving DDR exclusion, reference publication, B behavior, QIP, and SDC. Clean build: 31,922 ALMs, 43,946 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Repeated consecutive-P and all guards pass.

#### Next Steps:
Retire temporary diagnostics and retest clean baseline.

#### Files Modified:
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh

#### Status:
- [x] Built
- [x] Passed — functional fix accepted

---
## 163 COMMIT Unreleased 1370c28 2026-08-16T00:51:40-07:00

#### Coming From:
Unreleased 42d330f

#### Purpose:
Retire temporary diagnostics while preserving Commit-162 pacing.

#### Outcome:
`1370c28e3d34b1fd603c17130986bc336da29a32` restores seven diagnostic files to pre-investigation contents. Clean build: 31,782 ALMs, 43,812 registers, 461,345 memory bits, 68 DSPs, 3 PLLs. Repeated consecutive-P and all four standing guards pass.

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
Record accepted v0.4.0 clean-build/hardware qualification in release notes.

#### Outcome:
`cf9ec63a47ffa4fea8b6525190a0cfa39e7ba0b6` changes only release notes. Fresh-clone `1370c28`: 31,782 ALMs, 43,812 registers, 461,345 memory bits, 68 DSPs, 3 PLLs, setup TNS 0, setup +0.167 ns. Consecutive-P passes 20 runs; mixed-GOP B, B core, generalized P, and all-I pass.

#### Next Steps:
Complete v0.4.0 documentation/tag/release metadata.

#### Files Modified:
- docs/RELEASE_NOTES_v0.4.0.md

#### Status:
- [x] Built — underlying `1370c28`
- [x] Passed

---
## 165 COMMIT v0.4.0 b4385fe 2026-08-16T01:56:38-07:00

#### Coming From:
v0.4.0 cf9ec63

#### Purpose:
Complete v0.4.0 documentation and release publication.

#### Outcome:
`b4385fe4ec62587df701c160333a81ea367c5659` changes only README/CHANGELOG. Annotated `v0.4.0` resolves to `b4385fe`; pre-release and `MediaPlayer_20260816.rbf` are published. Synthesized source remains exact qualified Commit 163.

#### Next Steps:
Resume development only under a new approved boundary.

#### Files Modified:
- README.md
- CHANGELOG.md

#### Status:
- [x] Built — underlying `1370c28`
- [x] Passed — release verified

---
## 166 COMMIT Unreleased 74535ad 2026-08-16T04:19:33-07:00

#### Coming From:
Unreleased bc37008

#### Purpose:
Widen generalized progressive 4:2:0 P decoding through 720x480.

#### Outcome:
`74535adb3574ef71a00e39e806816929ec3facdd` adds streamed wide-P syntax, 45x30 geometry, 1350x16 M10K-oriented motion storage, and 11-bit sparse-residual MB indices while retaining 16-block/64-coefficient-event implementation ceilings. Clean build: 36,957 ALMs (88%), 45,721 registers, 487,041 memory bits, 78 RAM, 70 DSPs, 3 PLLs. New 720x480 P plus prior six-stream matrix passes.

#### Next Steps:
Recover parser resources before widening B geometry.

#### Files Modified:
- files.qip
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_p_720x480_general_decode.py

#### Status:
- [x] Built
- [x] Passed

---
## 167 COMMIT Unreleased b11590c 2026-08-16T05:31:18-07:00

#### Coming From:
Unreleased 74535ad

#### Purpose:
Consolidate duplicate generalized-P syntax onto the streamed parser.

#### Outcome:
`b11590cf77febb7364a13e628a64e107fc2a8620` consolidates exact 128x96 and <=720x480 P syntax. Clean build: 30,771 ALMs (73%), 41,381 registers, 486,017 memory bits, 77 RAM, 69 DSPs, 3 PLLs; -6,186 ALMs versus Commit 166. Five streams pass; consecutive-P loses normal USER acceptance without crashing, so functional acceptance fails.

#### Next Steps:
Restore exact 128x96 consecutive-P compatibility without giving back resource recovery.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh ... part3.svh

#### Status:
- [x] Built
- [ ] Passed — consecutive-P regression

---
## 168 COMMIT Unreleased 0ea9ac5 2026-08-16T07:45:00-07:00

#### Coming From:
Unreleased b11590c

#### Purpose:
Restore consecutive-reference P acceptance after parser consolidation.

#### Outcome:
`0ea9ac55723d10812bbf0f4ac0b01ecf2a3df0b0` changes only the P diagnostic controller, retaining an observed streamed-motion transaction across wide-picture completion. Clean build: 30,751 ALMs (73%), 41,338 registers, 486,017 memory bits, 77 RAM, 69 DSPs, 3 PLLs, setup +0.644 ns. All six requested regressions pass.

#### Next Steps:
Widen remaining fixed-geometry B path.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv

#### Status:
- [x] Built
- [x] Passed

---
## 169 COMMIT Unreleased ac1ddaf 2026-08-16T07:52:00-07:00

#### Coming From:
Unreleased 0ea9ac5

#### Purpose:
Widen progressive 4:2:0 B decoding through <=720x480 while preserving two-reference/scratch semantics and qualified P/I behavior.

#### Outcome:
`ac1ddaf393a09c7b2733657a84940f227cd1a63a` widens B syntax/raster to 45x30, streams B motion metadata into a 1350x34 M10K-oriented store, and widens the internal scratch tag while retaining four-block Y0 residual capacity. Clean build: 28,106 ALMs (67%), 38,220 registers, 534,989 memory bits, 84 RAM, 69 DSPs, 3 PLLs; setup +0.367, hold +0.251, recovery +3.395, removal +0.734, min-pulse +0.462, setup TNS 0, no flow errors/critical warnings. New 720x480 B plus prior six-stream matrix passes; Audio `81219ce` compatibility clean.

#### Next Steps:
Generalize B residual syntax/coverage.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_b_core_probe.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_b_720x480_mixed_gop.py

#### Status:
- [x] Built
- [x] Passed

---
## 170 COMMIT Unreleased 3fae896 2026-08-16T14:30:00-07:00

#### Coming From:
Unreleased ac1ddaf

#### Purpose:
Generalize progressive 4:2:0 B residual syntax across all six macroblock blocks.

#### Outcome:
`3fae8964f7458119eb04cd773cb85128ae6bfc09` adds full 4:2:0 CBP selection, block indices 0..5, generalized non-intra VLC/EOB/Escape parsing, and 16-block/64-event bounded B residual storage. Clean build: 30,089 ALMs (72%), 40,746 registers, 559,565 memory bits, 86 RAM, 69 DSPs, 3 PLLs; setup +0.310, hold +0.209, recovery +3.745, removal +0.785, min-pulse +0.462, setup TNS 0, no flow errors/critical warnings. New residual stream plus prior seven-stream matrix passes. Cleanup `df3380c`; Audio `a5d7606` compatibility clean.

#### Next Steps:
Generalize remaining B macroblock-address increment syntax.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_b_core_probe.sv
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh ... part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh ... part3.svh
- tools/streams/generate_test_b_720x480_residual_decode.py

#### Status:
- [x] Built
- [x] Passed

---
## 171 COMMIT Unreleased eb80c7b 2026-08-16T15:39:00-07:00

#### Coming From:
Unreleased 3fae896

#### Purpose:
Generalize progressive 4:2:0 B-picture macroblock-address increment syntax across the full Table-B.1 range needed inside a 45-macroblock row while preserving the accepted B motion/residual/raster behavior.

#### Outcome:
Exact functional commit `eb80c7b39a1d1abc4535aab3e87484d1b7bdf02f` (`Generalize B macroblock address increments`) extends the B syntax path from the prior 1..8 subset to all Table-B.1 values 1..33 plus `macroblock_escape` accumulation. The B internal-skip counter widens from 4 to 6 bits so long skip runs remain lossless inside the established 45-wide row envelope. The parser still requires the first coded macroblock to begin the row and the final coded macroblock to reach the row end; leading/trailing skipped-B semantics remain outside this boundary.

Agent-side deterministic regression `test_b_720x480_address_increment.m2v` validates with FFmpeg/ffprobe: 183,001 bytes, SHA-256 `dd28b53fa8311d9ee0ea102b294eb681211083dc269b0225275ca6796c2dba68`, coded I/P/B/P/B, display I/B/P/B/P. Every B row codes columns 0, 34, 44, exercising increments 1, 34 (`macroblock_escape` + 1), and 10; selected coded macroblocks retain ten residual blocks per B picture spanning Y0-Y3/Cb/Cr. B motion/geometry, residual syntax/capacity, raster/DDR behavior, reference publication, scratch presentation ordering, P pacing, IDCT, QIP, and SDC are unchanged.

#### Next Steps:
Pull current `master` and treat `eb80c7b` as the executable build hash. Run `python3 tools/streams/generate_test_b_720x480_address_increment.py`, then a clean Quartus/STA build. Run `test_b_720x480_address_increment.m2v` first, followed by `test_b_720x480_residual_decode.m2v`, `test_b_720x480_mixed_gop.m2v`, `test_p_720x480_general_decode.m2v`, repeated `test_p_consecutive_reference.m2v`, `test_p_general_decode.m2v`, `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, and `test_all_i.m2v`.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- tools/streams/generate_test_b_720x480_address_increment.py

#### Status:
- [ ] Built
- [ ] Passed
