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
`1370c28` restores diagnostic files. Clean build: 31,782 ALMs, 43,812 registers. Repeated consecutive-P and all guards pass.

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
`3fae896` adds full CBP selection, blocks 0..5, generalized non-intra VLC/EOB/Escape parsing and bounded 16-block/64-event storage. Clean build: 30,089 ALMs (72%), setup +0.310 ns, zero TNS. Eight-stream matrix passes.

#### Status:
- [x] Built
- [x] Passed

---
## 171 COMMIT Unreleased eb80c7b 2026-08-16T15:39:00-07:00

#### Purpose:
Generalize B macroblock-address increments across Table-B.1 plus `macroblock_escape` within a 45-MB row.

#### Outcome:
`eb80c7b` accepts 1..33 plus escape accumulation and a six-bit skip counter. All nine hardware regressions pass, but clean STA fails 54 MHz setup at -0.036 ns / -0.206 ns TNS (30,215 ALMs, 40,762 registers). Cleanup `7f5789a`; Audio `826b2df` compatibility clean.

#### Status:
- [x] Built — hardware behavior passes; setup timing fails
- [ ] Passed — -0.036 ns setup / -0.206 ns TNS

---
## 172 COMMIT Unreleased 338c2f8 2026-08-16T16:53:00-07:00

#### Purpose:
Restore Commit-171 54 MHz timing without changing accepted B address semantics.

#### Outcome:
`338c2f8` registers each decoded B MBA symbol before escape/row-bound/skip arithmetic. Clean build: 29,901 ALMs (71%), 40,799 registers, 559,565 bits, 86 RAM, 69 DSP, 3 PLL; setup +0.823 ns / zero TNS, Fmax 56.51 MHz. All nine regressions pass. Cleanup `bbbdcf6`; Audio compatibility clean.

#### Status:
- [x] Built
- [x] Passed

---
## 173 COMMIT Unreleased 912a874 2026-08-16T17:42:56-07:00

#### Coming From:
Unreleased 338c2f8

#### Purpose:
Generalize H.262 restricted slice partitioning across the accepted progressive P/B <=720x480 paths.

#### Outcome:
`912a87494a30ae6f5d3dfb1320f8bf3b558430b4` implements `H262-025`: multiple same-row P/B slices are accepted, first-slice MBA positioning no longer creates synthetic leading skips, internal MBA gaps retain skipped-macroblock behavior, and row/picture transitions require contiguous non-overlapping restricted coverage. Agent stream `test_pb_720x480_restricted_slices.m2v` validates at 183,290 bytes / SHA256 `320f1f5aa5281b77284c9d354a1350a449fe91214ba6d381054c5114dec2c837`.

Build upload `11dd441` is clean: 30,111 ALMs (72%), 40,748 registers, 559,565 memory bits, 86 RAM blocks, 69 DSPs, 3 PLLs. Global setup is +0.219 ns / zero TNS; the 54 MHz decoder clock is +0.626 ns / zero TNS; hold +0.241 ns, recovery +4.415 ns, removal +0.725 ns and minimum pulse width +0.462 ns are positive. All ten requested hardware regressions pass. Cleanup is `d500567`. Audio `fd90c77` compatibility is clean.

#### Next Steps:
Restore reproducible clean Quartus compilation before further decoder capability work; then resume picture-signaled P/B `f_code` under `H262-022`.

#### Status:
- [x] Built
- [x] Passed

---
## 174 PROPOSAL Unreleased pending 2026-08-16T19:00:00-07:00

#### Coming From:
Unreleased 912a874

#### Purpose:
Restore a reproducible clean Quartus 17.0.2 build by correcting the inherited ASCAL `mode` port-width mismatch exposed after deleting the cached compilation database.

#### Outcome:
A fresh `quartus_sh --flow compile MediaPlayer` from the qualified Commit-173 source fails during Analysis & Synthesis before Fitter. `sys/ascal.vhd` declares `mode : IN unsigned(4 DOWNTO 0)` (5 bits), while `sys/sys_top.v` connects `{~lowlat,LFB_EN ? LFB_FLT : |scaler_flt,2'b00}` (4 bits). Quartus reports that the 4-element array cannot connect to the 5-element port. The current MiSTer upstream framework carries the same source pair, so this is an inherited framework mismatch rather than a Commit-173 decoder regression. ASCAL documents `MODE[4]` as TBD; therefore the conservative compatibility repair is to drive that unused high bit to zero while preserving the existing `MODE[3:0]` mapping exactly.

Scope Commit 174 only to `sys/sys_top.v`: change the ASCAL connection to `{1'b0,~lowlat,LFB_EN ? LFB_FLT : |scaler_flt,2'b00}` and mark the intentional repair with `kate - Commit 174`. Do not alter `sys/ascal.vhd`, decoder RTL, P/B/I behavior, DDR/raster/reference/presentation logic, QIP, SDC, or timing constraints. The previously proposed picture-signaled P/B `f_code` work is deferred to Commit 175.

Validation must start from a clean local database/output state, run the complete Quartus flow, and require successful Analysis & Synthesis/Fitter/Assembler/TimeQuest plus regenerated `MediaPlayer.fit.rpt`, `MediaPlayer.fit.summary`, `MediaPlayer.flow.rpt`, and `MediaPlayer.sta.rpt`. Then run Phase-1P timing and the existing ten-stream hardware matrix; timing acceptance remains non-negative setup slack, zero setup TNS, and no timing-requirements Critical Warning.

#### Next Steps:
Await user approval before implementation. After qualification, resume P/B picture-signaled `f_code` as the next capability boundary.

#### Files Modified:
- sys/sys_top.v

#### Status:
- [ ] Built
- [ ] Passed
