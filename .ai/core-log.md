## 153 COMMIT v0.5.0-cycle 99c7519 2026-08-15T18:24:58-07:00

#### Purpose:
Add observer-only USER-LED tracing for consecutive-P instability.

#### Outcome:
`99c7519` separates pass code 10 from failure code 12, localizing the failure to prediction/reference handling.

#### Status:
- [x] Built
- [x] Passed — diagnostic boundary

---
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
## 172 COMMIT Unreleased 338c2f8 2026-08-16T16:18:00-07:00

#### Coming From:
Unreleased eb80c7b

#### Purpose:
Restore Commit-171 54 MHz setup closure without changing its hardware-passing B address semantics.

#### Outcome:
Functional commit `338c2f8bb868cd0e8a7d4bf01ac7961a06231d33` (`Pipeline B macroblock address apply`) changes only `mpeg2_h262_b_core_probe_part0.svh` and `part3.svh`. It adds `S_MBA_APPLY` and registers the decoded Table-B.1/escape symbol before the existing escape accumulation, row-bound validation and skip-count arithmetic. `S_MBA_APPLY` consumes no stream bit, so accepted values 1..33, `macroblock_escape`, long internal skips and all Commit-171 bitstream semantics remain unchanged. No DDR, raster, motion, residual, publication/presentation, P, IDCT, QIP, SDC or timing-constraint change is included.

#### Next Steps:
Pull current `master` and build with `338c2f8` as the executable hash. Require non-negative 54 MHz setup slack, zero setup TNS and no timing-requirements Critical Warning. Run `test_b_720x480_address_increment.m2v` first, then the complete nine-stream Commit-171 matrix.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh

#### Status:
- [ ] Built
- [ ] Passed
