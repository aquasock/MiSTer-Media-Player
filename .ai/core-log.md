## 154 COMMIT v0.5.0-cycle ad071ba 2026-08-15T18:55:00-07:00

#### Purpose:
Refine generalized-P prediction/reference diagnostics.

#### Outcome:
`ad071ba` adds first-error visibility. Clean build: 31,855 ALMs, setup +0.384 ns. Failure code 13 shows DDR store/cache error masking ordering.

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
## 155 COMMIT v0.5.0-cycle dbd0993 2026-08-15T19:52:00-07:00

#### Purpose:
Refine DDR store/cache first-fault classes.

#### Outcome:
`dbd0993` attached the observer to the wrong writer sibling and failed synthesis.

#### Status:
- [ ] Built — synthesis failed
- [ ] Passed

---
## 156 COMMIT Unreleased ebd3ead 2026-08-15T20:03:49-07:00

#### Purpose:
Attach the observer to active `_420p.sv`.

#### Outcome:
`ebd3ead` builds cleanly and reports writer overlap with prediction error already present/coincident.

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
## 157 COMMIT Unreleased 177a480 2026-08-15T21:16:37-07:00

#### Purpose:
Refine writer state/busy/ordering evidence.

#### Outcome:
`177a480` records the required observer evidence but its USER encoding was superseded before build.

#### Status:
- [ ] Built — superseded
- [ ] Passed

---
## 158 COMMIT Unreleased 5740587 2026-08-15T21:24:27-07:00

#### Purpose:
Make Commit-157 evidence readable on USER LED.

#### Outcome:
`5740587` reports 4-1: writer write+flush overlap while DDR busy, with prediction error earlier.

#### Status:
- [x] Built
- [ ] Passed — diagnostic captured 4-1

---
## 159 COMMIT Unreleased a5b518d 2026-08-15T21:55:32-07:00

#### Purpose:
Identify the first generalized-P prediction/reference failure class.

#### Outcome:
`a5b518d` reports 2-2-4: generalized-P prediction timeout precedes writer overlap.

#### Status:
- [x] Built
- [x] Passed — timeout identified first

---
## 160 COMMIT Unreleased 1efbb4b 2026-08-15T23:31:10-07:00

#### Purpose:
Refine generalized-P timeout to active transaction phase.

#### Outcome:
`1efbb4b` reports 1-3-4: reconstructed output is waiting for ordinary DDR store completion.

#### Status:
- [x] Built
- [ ] Passed — phase-3 stall localized

---
## 161 COMMIT Unreleased 5d8c8ba 2026-08-15T23:59:26-07:00

#### Purpose:
Classify DDR-arbiter condition during the phase-3 stall.

#### Outcome:
`5d8c8ba` reports 2-1-4: display-region ownership exclusion is first; protection is correct.

#### Status:
- [x] Built
- [x] Passed — root cause localized

---
## 162 COMMIT Unreleased 42d330f 2026-08-16T00:25:40-07:00

#### Purpose:
Correct the consecutive-P publication/presentation ownership race.

#### Outcome:
`42d330f` adds P-only destination ownership pacing. Repeated consecutive-P and all guards pass.

#### Status:
- [x] Built
- [x] Passed — functional fix accepted

---
## 163 COMMIT Unreleased 1370c28 2026-08-16T00:51:40-07:00

#### Purpose:
Retire temporary diagnostics while preserving Commit-162 pacing.

#### Outcome:
`1370c28` restores the diagnostic files. Clean build: 31,782 ALMs, 43,812 registers. Repeated consecutive-P and all guards pass.

#### Status:
- [x] Built
- [x] Passed — cleaned baseline accepted

---
## 164 COMMIT v0.4.0 cf9ec63 2026-08-16T01:55:28-07:00

#### Purpose:
Record v0.4.0 clean-build/hardware qualification.

#### Outcome:
Underlying `1370c28` passes fresh-clone qualification; consecutive-P passes 20 runs and all standing guards pass.

#### Status:
- [x] Built — underlying `1370c28`
- [x] Passed

---
## 165 COMMIT v0.4.0 b4385fe 2026-08-16T01:56:38-07:00

#### Purpose:
Complete v0.4.0 documentation and release publication.

#### Outcome:
`b4385fe` changes README/CHANGELOG only. Annotated `v0.4.0` and `MediaPlayer_20260816.rbf` are published; synthesized source remains qualified Commit 163.

#### Status:
- [x] Built — underlying `1370c28`
- [x] Passed — release verified

---
## 166 COMMIT Unreleased 74535ad 2026-08-16T04:19:33-07:00

#### Purpose:
Widen generalized progressive 4:2:0 P decoding through 720x480.

#### Outcome:
`74535ad` adds 45x30 geometry, streamed wide-P syntax and M10K-oriented motion storage. Clean build: 36,957 ALMs (88%). New 720x480 P plus prior matrix passes.

#### Status:
- [x] Built
- [x] Passed

---
## 167 COMMIT Unreleased b11590c 2026-08-16T05:31:18-07:00

#### Purpose:
Consolidate duplicate generalized-P syntax onto the streamed parser.

#### Outcome:
`b11590c` reduces utilization to 30,771 ALMs (73%) but regresses consecutive-P acceptance without crashing.

#### Status:
- [x] Built
- [ ] Passed — consecutive-P regression

---
## 168 COMMIT Unreleased 0ea9ac5 2026-08-16T07:45:00-07:00

#### Purpose:
Restore consecutive-reference P acceptance after parser consolidation.

#### Outcome:
`0ea9ac5` preserves streamed-motion transaction evidence across wide completion. Clean build: 30,751 ALMs (73%), setup +0.644 ns. All six regressions pass.

#### Status:
- [x] Built
- [x] Passed

---
## 169 COMMIT Unreleased ac1ddaf 2026-08-16T07:52:00-07:00

#### Purpose:
Widen progressive 4:2:0 B decoding through <=720x480.

#### Outcome:
`ac1ddaf` widens B syntax/raster to 45x30 using streamed motion metadata and M10K-oriented storage. Clean build: 28,106 ALMs (67%), setup +0.367 ns. New 720x480 B plus prior matrix passes; Audio compatibility clean.

#### Status:
- [x] Built
- [x] Passed

---
## 170 COMMIT Unreleased 3fae896 2026-08-16T14:30:00-07:00

#### Purpose:
Generalize B residual syntax across all six 4:2:0 blocks.

#### Outcome:
`3fae896` adds full CBP selection, block 0..5 residuals, generalized non-intra VLC/EOB/Escape parsing and bounded 16-block/64-event storage. Clean build: 30,089 ALMs (72%), setup +0.310 ns, zero TNS. Eight-stream hardware matrix passes.

#### Status:
- [x] Built
- [x] Passed

---
## 171 COMMIT Unreleased eb80c7b 2026-08-16T15:39:00-07:00

#### Purpose:
Generalize B macroblock-address increments across full Table-B.1 plus `macroblock_escape` within a 45-MB row.

#### Outcome:
`eb80c7b` accepts values 1..33 plus escape accumulation and widens the B skip counter to six bits. All nine requested MiSTer regressions pass. Clean build uses 30,215 ALMs (72%), 40,762 registers, 559,565 memory bits, 86 RAM blocks, 69 DSPs and 3 PLLs, but 54 MHz setup fails at -0.036 ns / -0.206 ns TNS (Fmax 53.9 MHz). Hold/recovery/removal/min-pulse remain positive. Cleanup `7f5789a`; Audio `826b2df` compatibility clean.

#### Next Steps:
Restore decoder setup closure without changing the accepted B address semantics.

#### Status:
- [x] Built — hardware behavior passes; setup timing fails
- [ ] Passed — -0.036 ns setup / -0.206 ns TNS

---
## 172 COMMIT Unreleased 338c2f8 2026-08-16T16:53:00-07:00

#### Coming From:
Unreleased eb80c7b

#### Purpose:
Restore Commit-171 54 MHz setup closure without changing its hardware-passing B address semantics.

#### Outcome:
`338c2f8bb868cd0e8a7d4bf01ac7961a06231d33` registers each decoded B macroblock-address symbol before escape/row-bound/skip arithmetic. Clean build: 29,901 ALMs (71%), 40,799 registers, 559,565 memory bits, 86 RAM blocks, 69 DSPs and 3 PLLs. Decoder setup closes at +0.823 ns / zero TNS (Fmax 56.51 MHz); hold/recovery/removal/min-pulse are positive, with no flow errors or critical warnings. All nine hardware regressions pass. Build-report cleanup is `bbbdcf6`. Latest Audio `33a5f91` only adds a timing-report `.gitkeep`; latest Audio functional `a50fb2e` changes only `tools/phase1p_timing.tcl`, so integration compatibility is clean.

#### Next Steps:
Generalize profile-conformant restricted slice partitioning in the progressive P/B paths; retain B `f_code` generalization as the following capability boundary.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh

#### Status:
- [x] Built
- [x] Passed

---
## 173 PROPOSAL Unreleased pending 2026-08-16T17:06:00-07:00

#### Coming From:
Unreleased 338c2f8

#### Purpose:
Generalize profile-conformant restricted slice partitioning across the accepted progressive P/B 720x480 paths so a macroblock row may be carried by multiple same-row slices without misclassifying slice-boundary positioning as skipped macroblocks.

#### Outcome:
Online verification against the official freely available ITU-T H.262 (02/2000) text clarifies the required model. A slice is an arbitrary run of consecutive macroblocks whose first and last macroblocks are coded, but slices may start and finish anywhere and multiple slices may therefore have the same `slice_vertical_position`. At slice start `previous_macroblock_address` is reset to the row origin minus one, and skipped-macroblock inference explicitly does not apply there. Table 8-5 requires restricted slice structure for all defined profiles, so every picture macroblock must nevertheless be enclosed in a non-overlapping slice.

The current active I-picture parser already accepts an arbitrary legal first MBA within a slice and traverses successive slice start codes. The generalized P and B parsers impose a narrower implementation rule: each slice starts at column zero, reaches the right edge, and the next slice advances to the next macroblock row. Scope Commit 173 only to removing that P/B one-full-row-slice assumption: accept same-row continuation slices, interpret a non-1 first MBA as the first coded column of that slice rather than as skipped macroblocks, and maintain contiguous non-overlapping full-picture coverage required by restricted slice structure. Preserve the existing internal skipped-macroblock behavior; do not create or accept an illegal skipped first/last macroblock inside a slice.

Preserve current I behavior, P/B geometry, B Table-B.1/escape support, motion and current `f_code` subset, residual/CBP syntax, reference/scratch semantics, DDR arbitration, presentation ordering, P pacing, IDCT, QIP, SDC, and Commit-172 timing closure. Defer B picture-signaled `f_code` generalization to the following capability boundary.

Validation will add a deterministic 720x480 mixed I/P/B regression with selected rows partitioned into two or more slices sharing `slice_vertical_position`, later slices beginning at non-zero columns through their first macroblock address increment, every slice beginning and ending on coded macroblocks, complete row/picture coverage, and internal skipped macroblocks where legal. Run the new stream first, then the complete existing nine-stream matrix. Acceptance requires a clean Quartus/STA build with non-negative setup slack, zero setup TNS, and no timing-requirements critical warning.

#### Next Steps:
Await user approval before implementation.

#### Files Modified:
- TBD — generalized P/B slice-position/coverage state only
- tools/streams/generate_test_pb_720x480_restricted_slices.py

#### Status:
- [ ] Built
- [ ] Passed
