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
## 174 COMMIT Unreleased 4c65826 2026-08-16T19:21:12-07:00

#### Coming From:
Unreleased 912a874

#### Purpose:
Restore a reproducible clean Quartus 17.0.2 build by correcting the inherited ASCAL `mode` port-width mismatch exposed after deleting the cached compilation database.

#### Outcome:
`4c65826960541bbb98e55090e0fc2304593d8112` changes only `sys/sys_top.v`: ASCAL's documented TBD `MODE[4]` is explicitly driven low, preserving the existing `MODE[3:0]` mapping while satisfying the five-bit `mode` port. No MPEG-2 decoder RTL, scaler implementation, QIP, SDC, or timing constraint changed. Hardware clean-build qualification is pending.

#### Validation:
Start from a clean local database/output state and run the complete Quartus flow. Require successful Analysis & Synthesis, Fitter, Assembler and TimeQuest plus regenerated `MediaPlayer.fit.rpt`, `MediaPlayer.fit.summary`, `MediaPlayer.flow.rpt` and `MediaPlayer.sta.rpt`. Then run Phase-1P timing and the existing ten-stream hardware matrix; timing acceptance remains non-negative setup slack, zero setup TNS and no timing-requirements Critical Warning.

#### Outcome (build/timing):
Upload `807fb86` is clean: 30,111 ALMs (72%), 40,748 registers, 559,565 memory bits, 86 RAM blocks, 69 DSPs, 3 PLLs — identical to Commit-173, confirming the ASCAL fix is non-functional to the decoder. Flow Status is Successful with zero Critical Warnings/Errors across `MediaPlayer.flow.rpt`, `.fit.rpt`, and `.sta.rpt`. Global setup is +0.219 ns / zero TNS; the 54 MHz decoder clock (`general[2]` PLL output) is +0.626 ns / zero TNS, matching Commit-173 exactly. Hold +0.241 ns, recovery +4.415 ns, removal +0.725 ns, minimum pulse width +0.462 ns all positive with zero TNS. Phase-1P setup/recovery summaries match the same-clock STA results.

#### Next Steps:
Awaiting the ten-stream hardware regression matrix result (LED-based, requires user report) to close hardware qualification; also awaiting the Audio-project repository URL (blank in core.md) to complete the Commit-174 compatibility check. After both are confirmed, resume picture-signaled P/B `f_code` as Commit 175.

#### Files Modified:
- sys/sys_top.v

#### Status:
- [x] Built — clean flow, zero TNS, no critical warnings (`807fb86`)
- [ ] Passed — hardware regression matrix result pending

---
## 175 COMMIT Unreleased c634a1e 2026-08-16T20:45:00-07:00

#### Coming From:
Unreleased 4c65826

#### Purpose:
Retire the `tools/streams/generate_test_*.py` regression-stream generator set and design a replacement test-generation framework from scratch.

#### Outcome:
Agent-side analysis of all 20 existing generator scripts on 2026-08-16 found:

1. **Confirmed broken generator.** `generate_test_p_motion_residual_boundary.py` raises `SystemExit` — its own internal consistency check finds an unexpected sequence-header-like `00 00 01 b3` byte pattern at offset 489 inside what should be a verbatim-copied I/P prefix (expected only the appended boundary preamble at offset 519). The script writes `test_p_motion_residual_boundary.m2v` to disk *before* running that check, so the file left on disk is self-flagged invalid, not a usable regression stream.
2. **Root cause is systemic, not local.** None of the 20 hand-bit-packing generators implement H.262 start-code emulation avoidance. Any of them can silently embed an accidental byte-aligned `00 00 01` inside packed slice/macroblock data; Commit-175's analysis only surfaced the one case where a script happened to scan for that exact pattern for an unrelated reason.
3. **Verification rigor is inconsistent across the set.** Most P-only generators (`test_p_general_decode`, `test_p_motion_dispatch`, `test_p_motion_residual_mix`, `test_p_general_residual_plan`, `test_p_general_motion_plan`, `test_p_aligned_motion_right`, `test_p_consecutive_reference`, the `six/twelve/twentyfour_mb` family, `test_p_controlled_raster`) build an explicit software H.262 reference model and pixel-diff FFmpeg's decode against it. The four 720x480 B-picture generators (`test_b_720x480_address_increment`, `..._mixed_gop`, `..._residual_decode`, `test_pb_720x480_restricted_slices`) plus `test_b_core_decode` and `test_b_mixed_gop` only check coded/display picture-type order, stream geometry, and that FFmpeg's own decoder completes without erroring — never confirming the intended MBA-escape, CBP/coefficient, or bidirectional-vector semantics actually decoded to the claimed values.
4. **Heavy duplicated boilerplate.** VLC tables (`MBA`, `MCODE`, `BTYPE`, `CBP`) and bit-packing helpers (`start_codes`, `bits_to_bytes`, `enc_comp`/`encode_component`, `delta_for`, `escape`) are copy-pasted near-identically across most of the 20 files, so a representation bug fixed in one script has to be hand-propagated to the rest instead of fixed once.

Per user instruction, the entire existing `tools/streams/generate_test_*.py` set and its stored `.m2v` outputs are retired as the authoritative regression source effective this entry. They remain on disk pending the replacement (no functioning generator set otherwise) but must not be used to qualify future commits.

#### Implementation:
Per user direction, coverage was re-derived from scratch (old-set coverage explicitly not ported) and capped at 6 files, all 720x480/45x30 — the larger multi-geometry suite is deferred to future version-release cycles. `c634a1e` adds `tools/streams/h262common.py`, a shared library (VLC tables reused verbatim from the retired set, which were never the source of the problem; a real non-intra dequantization + 8x8 IDCT reference model; half-sample P/B motion-compensation sampling; per-slice-segment start-code emulation detection), and six generators:

- `test_i_baseline` — all-intra sanity floor, no hand-patching.
- `test_p_motion_residual` — half-sample motion (all 4 phases), full validated-CBP coverage (63/48/32/21/12/3) with DC/AC/Escape coefficients, mid-slice `quantiser_scale_code` changes.
- `test_p_mba_escape` — ordinary skips, leading skip, mid-slice and leading `macroblock_escape`, last-column (44) addressing.
- `test_b_bidirectional` — forward/backward/bidirectional prediction + residual, independent fp/bp tracking.
- `test_pb_restricted_slices` — same-row P/B slice partitioning (H262-025) with per-segment predictor reset, ported forward with real verification.
- `test_consecutive_chain` — 6-generation consecutive-P reference chain (previous deepest validated chain was 2).

Every stream is verified pixel-exact against FFmpeg's own decode at generation time; residual-affected pixels get a documented +/-1 tolerance (ITU-T H.262 does not mandate a bit-exact IDCT — confirmed empirically when an exact-math reference landed within 0.002 of a rounding boundary and FFmpeg's practical IDCT resolved it to the other side). Motion-only pixels remain exact-match throughout.

Two non-obvious behaviors were found empirically (via direct FFmpeg cross-checks, not memory) and are binding on future test authoring: a P-picture skip resets the motion-vector predictor to zero, but a B-picture skip does **not** — it repeats the previous macroblock's full prediction. `test_b_bidirectional` and `test_pb_restricted_slices` were scoped to avoid needing B-skip semantics rather than risk encoding that rule wrong under time pressure; it needs its own dedicated, separately-verified regression in the larger future suite.

The 20 retired generators and their stale `.m2v` outputs are removed. Hardware qualification against `4c65826`/current decoder RTL is still outstanding — these streams have not yet been run through the 10-stream-matrix-style hardware pass.

#### Files Modified:
- tools/streams/h262common.py (new)
- tools/streams/generate_test_i_baseline.py (new)
- tools/streams/generate_test_p_motion_residual.py (new)
- tools/streams/generate_test_p_mba_escape.py (new)
- tools/streams/generate_test_b_bidirectional.py (new)
- tools/streams/generate_test_pb_restricted_slices.py (new)
- tools/streams/generate_test_consecutive_chain.py (new)
- tools/streams/generate_test_*.py (20 retired scripts removed)
- .gitignore (build_time.txt, __pycache__/, *.pyc)

#### Status:
- [x] Built — all 6 generators run clean and pass their own software verification
- [x] Passed — 3/6 qualify on hardware; the 3 P-final streams are blocked by the decoder finding recorded in Commit 176, not by a defect in the streams themselves

---
## 176 COMMIT Unreleased 28feb3f 2026-08-16T21:37:36-07:00

#### Coming From:
Unreleased c634a1e

#### Purpose:
Record the Commit-175 hardware result and scope the first presentation defect it exposed: a P picture that is the final coded picture of a stream is decoded but never presented.

#### Evidence:
All six Commit-175 streams were run on the standard DE10-Nano target against the `4c65826` build. No crashes, stalls, or visible corruption were observed on any stream. USER-LED acceptance results:

| Stream | Coded pictures | Final picture | LED |
|---|---|---|---|
| `test_i_baseline` | I I I I | I | ON |
| `test_b_bidirectional` | I P B P B | B | ON |
| `test_pb_restricted_slices` | I P B P B | B | ON |
| `test_p_motion_residual` | I P | **P** | OFF |
| `test_p_mba_escape` | I P | **P** | OFF |
| `test_consecutive_chain` | I P P P P P P | **P** | OFF |

The LED is OFF in exactly the three cases where the final coded picture is a P, and ON in every case where it is an I or a B. Every retired 720x480 P generator produced `I / P / I` — a trailing I — so the retired suite never presented a P-final stream and this behavior was masked rather than absent.

Photographic analysis confirms the mechanism independently of the LED. `test_p_motion_residual`'s P picture places residual macroblocks at MB (8,19), (8,26), (8,33), (8,40) and (15,38). Measuring macroblock-boundary luma discontinuity on the real FFmpeg-decoded P frame gives z-scores of +4.02, +5.24, +5.36, +3.44 and +5.38 against the same measurement on the I frame; the same measurement on the captured display photo gives -1.02 to +0.84 at those coordinates, indistinguishable from noise (largest outlier anywhere in the photo, z = 4.16, is at unrelated MB (26,20)). The residual content of the final P is therefore not on screen.

`test_consecutive_chain` discriminates the cause: it contains no residual coefficients, no escapes, no quantiser changes and no coded-block patterns at all — only MC-not-coded macroblocks with explicit motion — and it still fails. A residual- or syntax-decode fault would not produce that result, whereas a presentation fault does. All three failing streams carry a correct trailing `sequence_end` (`00 00 01 B7`).

#### Interpretation:
The three P streams are valid H.262 and are verified pixel-exact against FFmpeg at generation time; the fault is on the decoder side, in presentation rather than in decode. `mpeg2_new_frame_waiting` (`MediaPlayer_top_04.svh`/`_05.svh`) publishes a completed frame only when `completed_frame_bank != display_frame_bank` and a swap window pulse follows; the B path reaches the display through the separate Commit-139/162 scratch-then-future-reference transaction, and an I-final stream is followed by nothing that needs pacing. The P-final case is the one path with no subsequent picture to carry it to the display. Root-cause localization inside that logic is not attempted here and is deferred to the approved cycle.

Severity is low for sustained DVD playback, where a P is essentially never the last coded picture, but it is a real defect: the final frame of any title, chapter, or stream ending on a P will never be shown. It also currently blocks LED qualification of three of the six standing regressions.

#### Revised Commit Boundary:
The originally proposed boundary was a direct final-P presentation fix. Static tracing of `mpeg2_h262_picture_bookkeeper.sv`, `mpeg2_new_frame_waiting`, `mpeg2_new_pending_frame_valid` and the swap block could not localize the fault: by that reading the acceptance LED should light for all three failing streams, so no fix could be written without guessing at the Commit-139/142/162 presentation race. Ruled out during that trace were stream-FIFO byte loss (`ioctl_wait` backpressure is wired in `MediaPlayer_top_00.svh`), a Commit-162 ownership hold on the final P (`sequence_end` is `00 00 01 B7` and never matches the `00 00 01 00` picture-start window, so the hold never arms), and picture termination generally (the parser completes a picture on any non-slice start code, and the final B of the two passing streams does complete).

Two mechanisms remain and the single acceptance bit cannot separate them: the final P never completes (so `picture_count` / `second_picture_420_parsed` never advance), or it completes but never reaches the display (`completed_frame_bank` never equals `display_frame_bank`). One useful constraint: `mpeg2_new_phase1s_all_i_user_success` carries no picture-type condition, so for `test_consecutive_chain` (picture_count 7 >= 3) the LED can only be OFF through the bank equality or a latched error.

With user approval, Commit 176 was therefore rescoped from fix to diagnostic isolation, and the sequence became: 176 diagnostic, 177 fix, 178 dedicated final-P regression.

#### Outcome:
`28feb3f` changes only `MediaPlayer_top_00.svh` and `MediaPlayer_top_07.svh`. It drives the two core LED outputs that the `emu` interface already exports, so nothing outside the core changes and no framework file is touched:

- board `LED[4]` (`LED_POWER`) — `completed_frame_bank == display_frame_bank`
- board `LED[2]` (`LED_DISK`) — no decode/DDR error latched (`syntax`, `phase1_probe`, `pred`, `inverse_quant`, `inverse_quant_unsupported_matrix`, `idct`, `recon`, `ddr_store`, `ddr_cache`)

`LED_USER` (board `LED[0]`) keeps its existing acceptance meaning. `LED_POWER`/`LED_DISK` are `[1:0]` `{enable, value}`; `sys/sys_top.v` derives `LED[4] = led_power[0]` and `LED[2] = led_disk[0]` when the enable bit is set, so both diagnostic bits are active-high. The previous `LED_DISK = ioctl_download` indicator is displaced for the duration of the diagnostic. No decode, presentation, ownership, or acceptance behavior is altered.

#### Validation:
Clean Quartus 17.0.2 build from a wiped `db`/`incremental_db`/`output_files` state; acceptance remains non-negative setup slack, zero setup TNS, and no timing-requirements Critical Warning. Then run the three P-final streams (`test_p_motion_residual`, `test_p_mba_escape`, `test_consecutive_chain`) and record board `LED[0]`, `LED[4]` and `LED[2]` for each. Reading, for a stream with `LED[0]` OFF:

- `LED[4]` OFF — the completed frame never reached the display; fault is in the swap/presentation path.
- `LED[4]` ON, `LED[2]` OFF — a decode/DDR error latched; fault is in the decode path.
- `LED[4]` ON, `LED[2]` ON — the P acceptance prerequisites failed (`picture_count`, `second_picture_420_parsed`, `p_macroblock_type_seen`, `reference_read_ok`, `implicit_reconstruct_ok`).

Also record all three LEDs for `test_i_baseline` and `test_b_bidirectional` as controls; both should show `LED[0]`, `LED[4]` and `LED[2]` all ON.

#### Next Steps:
Hardware-run `28feb3f` and report the three LED states per stream. That result selects the Commit-177 fix boundary. Commit 178 then adds the dedicated final-P presentation regression. Adding a trailing I picture to the three P streams remains rejected: it would restore LED qualification immediately but re-mask the defect exactly as the retired suite did, and the streams are correct as written.

#### Files Modified:
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh

#### Diagnostic Result:
Hardware run of `28feb3f` on the standard target, read from the IO board cluster (POWER/DISK/USER):

| Stream | POWER (presented) | DISK (error-free) | USER (accepted) |
|---|---|---|---|
| `test_p_motion_residual` | ON | **OFF** | OFF |
| `test_p_mba_escape` | ON | **OFF** | OFF |
| `test_consecutive_chain` | ON | **OFF** | OFF |
| `test_i_baseline` (control) | ON | ON | ON |

POWER ON with DISK OFF means presentation is clean and a decode/DDR error is latching. This is the opposite of the mechanism the Commit-176 static trace had favoured; had the originally proposed fix been written blind it would have modified the Commit-139/142/162 swap logic, which is not at fault. The reading also explains the Commit-175 photographic evidence: the error latches during P decode, the P never completes, `completed_frame_bank` still refers to the I frame, the banks therefore match, and the I frame stays on screen.

DISK differentiating between streams also confirms the build under test was `28feb3f` and not the prior core: `4c65826` drove `LED_DISK` from `ioctl_download`, which sits dark at rest on every stream. An earlier agent claim that the diagnostic was absent from the compiled design was wrong — it was based on grepping `MediaPlayer.map.rpt`/`.fit.rpt` for the intermediate net names, which Quartus collapses into the output-pin logic.

#### Status:
- [x] Built
- [x] Passed — diagnostic isolated the fault to the decode path

---
## 177 COMMIT Unreleased 92d14cf 2026-08-16T22:15:08-07:00

#### Coming From:
Unreleased 28feb3f

#### Purpose:
Identify which of the nine decode/DDR error flags latches on the P-final streams.

#### Outcome:
`92d14cf` changes only `MediaPlayer_top_00.svh` and `MediaPlayer_top_07.svh`. The Commit-176 single error bit proved an error latches but cannot say which, so the nine flags are priority-encoded and blinked out on `LED_USER`:

| Code | Flag | Code | Flag |
|---|---|---|---|
| 1 | `syntax_error` | 6 | `idct_error` |
| 2 | `phase1_probe_error` | 7 | `recon_error` |
| 3 | `pred_error` | 8 | `ddr_store_error` |
| 4 | `inverse_quant_error` | 9 | `ddr_cache_error` |
| 5 | `inverse_quant_unsupported_matrix` | | |

`LED_USER` is steady ON when no error latched and the stream is accepted, steady OFF when no error latched but not accepted, and blinks N times followed by a ~2 s gap otherwise. The steady-OFF state is new information: it separates an acceptance-prerequisite failure (`picture_count`, `second_picture_420_parsed`, `p_macroblock_type_seen`, `reference_read_ok`, `implicit_reconstruct_ok`) from a decode fault, which the Commit-176 encoding could not distinguish.

`LED_DISK` returns to `ioctl_download`, restoring the file-load indicator that Commit 176 had displaced. `LED_POWER` keeps the presentation bit. Timing is 250 ms slots in a 26-slot frame off the 54 MHz decoder clock, giving nine countable blinks plus a 2 s separator. The encoder was verified in an iverilog testbench across all ten codes and both steady states before commit. No decode, presentation, ownership, or acceptance behavior changes.

#### Validation:
Clean Quartus 17.0.2 build from a wiped `db`/`incremental_db`/`output_files` state; acceptance remains non-negative setup slack, zero setup TNS, and no timing-requirements Critical Warning. Then run the three P-final streams and count the `LED_USER` blinks on each. `test_i_baseline` remains the control and must stay steady ON. `LED_DISK` must again follow stream loading, confirming the restored indicator.

#### Next Steps:
Report the blink count per stream. That names the failing flag and selects the Commit-178 fix boundary; Commit 179 then adds the dedicated regression. Adding a trailing I picture to the three P streams remains rejected — the streams are valid H.262 and verified pixel-exact against FFmpeg, and the retired suite's `I/P/I` shape is what masked this defect in the first place.

#### Files Modified:
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh

#### Diagnostic Result:
Hardware run of `92d14cf`:

| Stream | USER | Meaning |
|---|---|---|
| `test_p_mba_escape` | 2 blinks | `phase1_probe_error` |
| `test_consecutive_chain` | 2 blinks | `phase1_probe_error` |
| `test_p_motion_residual` | steady OFF | no error latched; an acceptance term is false |
| `test_i_baseline` | steady ON | control good |

Two distinct faults, not one. The steady-OFF reading is only distinguishable because Commit 177 moved the code onto `LED_USER` and added that third state; the Commit-176 encoding would have shown both as a bare OFF.

`phase1_probe_error` is an OR of four sources and does not localize further on its own. A candidate site exists at `rtl/mpeg2_new/mpeg2_h262_luma4_probe.sv:896`, which raises `probe_error` for any `macroblock_address_increment` other than 1 after a slice's first macroblock, commented as the non-scalable I-picture subset prohibiting skipped macroblocks. That would explain `test_p_mba_escape`, which is built entirely from gaps and escapes, but it is not confirmed and two facts argue against it being the whole story: the retired `test_p_720x480_general_decode` carried skips at MB (5,5) and (20,30) and passed at Commit 166, and `test_consecutive_chain` uses increment 1 on every macroblock yet reports the same code. At least one of the two streams is failing through a different source inside the same flag.

#### Status:
- [x] Built
- [x] Passed — diagnostic split the fault in two and named the error class

---
## 178 COMMIT Unreleased 466f0b3 2026-08-16T23:04:44-07:00

#### Coming From:
Unreleased 92d14cf

#### Purpose:
Name the specific `probe_error` source and the specific false acceptance term behind the two Commit-177 faults.

#### Outcome:
`466f0b3` adds a `probe_error_source` output to `mpeg2_h262_picture_bookkeeper.sv`, priority-encoded from the four terms already ORed into `probe_error`; `probe_error` itself is untouched. `LED_POWER` previously carried `presentation_ok`, which read ON on every Commit-176 stream and is therefore spent, so it now blinks a sub-code selected by what `LED_USER` is reporting:

- `LED_USER` blinks 2 (`phase1_probe_error`) — `LED_POWER` blinks the probe source: 1 `probe_error_latched`, 2 `parser_probe_error`, 3 `reference_error`, 4 `reference_progress_error`.
- `LED_USER` steady OFF — `LED_POWER` blinks the first false acceptance term: 1 `p_macroblock_type_seen`, 2 `first_picture_420_parsed`, 3 `second_picture_420_parsed`, 4 `picture_count < 2`, 5 `completed != display`, 6 `reference_read_ok`, 7 `implicit_reconstruct_ok`, 8 `recon_macroblock_420_complete`, 9 `phase1n_frame_geometry_supported`, 10 `ddr_write_seen`, 11 `ddr_cache_ready`, 12 `ddr_read_seen`.
- Otherwise `LED_POWER` is steady ON.

The blink frame grows from 26 to 32 slots so twelve blinks still leave a ~2 s separating gap. `LED_DISK` keeps its `ioctl_download` duty. The encoder was verified in an iverilog testbench across all four probe sources, all twelve prerequisite codes and the clean case before commit. Observability only: no decode, presentation, ownership, or acceptance behavior changes.

#### Validation:
Build and run the three P-final streams, recording both `LED_USER` and `LED_POWER` blink counts for each. `test_i_baseline` remains the control and must read steady ON on both. Expected: `test_p_mba_escape` and `test_consecutive_chain` show USER 2 plus a POWER probe-source code; `test_p_motion_residual` shows USER steady OFF plus a POWER prerequisite code.

#### Next Steps:
Report both counts per stream. The probe-source code decides whether the `luma4_probe:896` MBA restriction is genuinely responsible or whether reference bookkeeping is at fault, and the prerequisite code names what `test_p_motion_residual` is missing. Those two answers select the Commit-179 fix boundary.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_picture_bookkeeper.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh

#### Status:
- [x] Built — source committed
- [ ] Passed — sub-code result pending
