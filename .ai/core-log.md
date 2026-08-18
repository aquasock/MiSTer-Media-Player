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

#### Build Correction:
`466f0b3` failed Analysis & Synthesis with `Error (12002): Port "probe_error_source" does not exist in macrofunction "mpeg2_h262_two_picture_probe"` at `MediaPlayer_top_03.svh:22`. The output had been added to `mpeg2_h262_picture_bookkeeper`, but that module is not on the active path: the port list beginning at `MediaPlayer_top_02.svh:73` belongs to `mpeg2_h262_two_picture_probe` and spans into `MediaPlayer_top_03.svh`, so the connection landed on the wrong module. The bookkeeper is reached only through the `_p_chain`, `_p_publish` and `_multimb` variants.

`d5b97ce` reverts the bookkeeper to its pre-178 state and adds the output to `mpeg2_h262_two_picture_probe` instead. That module ORs eight sources rather than the bookkeeper's four, and the four additional ones are P-specific, so the Commit-178 sub-code table was incomplete as well as unbuildable. Corrected probe-source mapping: 1 `probe_error_latched`, 2 `parser_probe_error`, 3 `reference_error`, 4 `reference_progress_error`, 5 `p_syntax_probe_error`, 6 `p_residual_probe_error`, 7 `p_stream_hold_error`, 8 `p_syntax_progress_error`. The signal widens to `[3:0]` through `MediaPlayer_top_01.svh` and `MediaPlayer_top_07.svh`. `probe_error` itself remains unchanged.

The four P-specific sources are the more probable candidates for the observed failures and were absent from the original encoding, so the corrected build is also a better diagnostic than the one that failed.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh

#### Status:
- [x] Built — corrected as `d5b97ce`; build hash for this cycle is `d5b97ce`
- [ ] Passed — sub-code result pending

---
## 179 COMMIT Unreleased 0225bef 2026-08-16T23:58:00-07:00

#### Coming From:
Unreleased 466f0b3 (build hash `d5b97ce`)

#### Purpose:
Fix the `d5b97ce` build failure so the Commit-178 sub-code diagnostic can actually run.

#### Outcome:
The user's build of `d5b97ce` failed Analysis & Synthesis: `Error (12002): Port "probe_error_source" does not exist in macrofunction "mpeg2_h262_two_picture_probe" File: MediaPlayer_top_03.svh Line: 22`. Root cause: four separate `.sv` files under `rtl/mpeg2_new/` all declare `module mpeg2_h262_two_picture_probe` with the identical name (base, `_p_chain`, `_multimb`, `_p_publish`). `files.qip` compiles only `mpeg2_h262_two_picture_probe_p_chain.sv` for that module name. `d5b97ce` added `probe_error_source` to the uncompiled base file — the same class of wrong-file mistake its own "Build Correction" note had already flagged once (landing on the bookkeeper first, then this base file, neither of which is on the active `_p_chain` path).

`0225bef` adds `probe_error_source` directly to `mpeg2_h262_two_picture_probe_p_chain.sv`, using a 5-term priority-encoded breakdown of that file's own `probe_error` OR (`bookkeeper_error` gated, `p_error_raw` gated, `b_error`, `publication_error`, `reference_progress_error`) rather than porting the base file's unrelated 8-term encoding. `probe_error` itself is unchanged. The `LED_POWER` sub-code comment table in `MediaPlayer_top_07.svh` is corrected to match. User approved the 5-source (vs. full 8-source bookkeeper-exposing) approach before implementation.

#### Validation:
Full clean Quartus 17.0.2 CLI flow from the existing `output_files/` state (`quartus_map` → `quartus_fit` → `quartus_asm` → `quartus_sta`), run directly by the agent this cycle. Analysis & Synthesis: 0 errors (was 1), 102 warnings. Fitter: Successful, 0 errors, 8 warnings. Assembler: Successful, 0 errors, 0 warnings. 30,161 ALMs (72%), 40,877 registers, 559,565 memory bits, 86 RAM blocks, 69 DSPs, 3 PLLs. TimeQuest: every setup/hold/recovery/removal/minimum-pulse-width slack positive, zero TNS on all; global (worst-case) setup +0.347 ns, the 54 MHz decoder clock (`general[2]` PLL) setup +0.415 ns / hold +0.250 ns / recovery +15.405 ns / removal +0.631 ns / minimum pulse width +7.818 ns. Flow Status Successful, zero Critical Warnings anywhere.

Hardware regression against the Commit-178 diagnostic (report `LED_USER`/`LED_POWER` blink counts for `test_p_mba_escape`, `test_consecutive_chain`, `test_p_motion_residual`, plus `test_i_baseline` as steady-ON control) is still outstanding — this commit only restores a buildable bitstream carrying that diagnostic.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- MediaPlayer_top_07.svh

#### Diagnostic Result:
Hardware run of `0225bef` on the standard target:

| Stream | USER | POWER | Meaning |
|---|---|---|---|
| `test_p_mba_escape` | 2 blinks | 2 blinks | `phase1_probe_error`, source `p_error_raw` |
| `test_consecutive_chain` | 2 blinks | 2 blinks | `phase1_probe_error`, source `p_error_raw` |
| `test_p_motion_residual` | 2 blinks | 2 blinks | `phase1_probe_error`, source `p_error_raw` |
| `test_i_baseline` (control) | steady ON | 1 blink | accepted; POWER 1 is expected, see below |

The control reads exactly as predicted before the run: `LED_USER` steady ON, `LED_POWER` 1 blink. The Commit-178 note that the control "must read steady ON on both" was wrong. `mpeg2_new_diag_power_code` is gated only on `mpeg2_new_diag_error_code == 0`, which is true both when USER is steady OFF and when USER is steady ON, so an accepted stream still emits a prerequisite sub-code. For an all-I stream `p_macroblock_type_seen` is never asserted (`_p_chain.sv` forces it only via `b_final_success`), so the first false prerequisite is term 1. The same 1-blink pattern is the idle/boot baseline with no file loaded. This is an encoding wart in the diagnostic, not a decode defect; POWER is only meaningful on the control when read together with USER.

All three P-final streams now report a single common source: `probe_error_source` 2 = `p_error_gated` = the `probe_error` output of `mpeg2_h262_p_diagnostic_controller` (`p_controller`). `b_picture_observed` is false on all three, as expected for streams with no B pictures, so the gate is transparent.

#### Correction To Commit 177:
`test_p_motion_residual` was recorded as steady OFF at `92d14cf` and reads 2 blinks here. The user has confirmed the Commit-177 reading was a misread and that the `0225bef` results are definitive. **The Commit-177 "two distinct faults" conclusion is withdrawn.** There is one deterministic fault affecting all three P-final streams, not two, and there is no separate acceptance-prerequisite failure to chase. The Commit-177 entry is left in place as the historical record but its interpretation is superseded by this entry.

This also removes the intermittency question: no evidence of run-to-run variation remains, and `git show 0225bef` independently confirms the commit was purely additive (`assign probe_error=...` byte-identical), so nothing in the diff could have changed the observed state either.

#### Status:
- [x] Built — clean flow, zero TNS, no critical warnings (`0225bef`)
- [x] Passed — diagnostic named the common fault source; see Commit-180 proposal

---
## 180 COMMIT Unreleased 7337195 2026-08-17T00:51:23-07:00

#### Coming From:
Unreleased 0225bef

#### Purpose:
Resolve the Commit-179 reproducibility question and name the specific term inside `mpeg2_h262_p_diagnostic_controller.probe_error`.

#### Scoping:
`p_error_raw` is an OR of eight terms at `mpeg2_h262_p_diagnostic_controller.sv:196` and does not localize further on its own:

| Code | Term | Code | Term |
|---|---|---|---|
| 1 | `syntax_error` | 5 | `residual_error` |
| 2 | `two_mb_error` | 6 | `hold_error` |
| 3 | `four_mb_error` | 7 | `raster_hold_error` |
| 4 | `aligned_error` | 8 | `progress_error` |

Five of these are `probe_error` outputs of dedicated sub-probes (`mpeg2_h262_p_syntax_probe`, `_p_two_mb_syntax_probe`, `_p_four_mb_two_row_syntax_probe`, `_p_aligned_motion_syntax_probe`, `_p_residual_probe`); `syntax_error` is additionally qualified by `!two_mb_seen && !four_mb_seen && !aligned_seen`, and `progress_error` is the flat `p_picture_expected && !p_macroblock_type_seen`.

The three failing streams have deliberately disjoint content — `test_consecutive_chain` carries no residual coefficients, no escapes, no quantiser changes and increment 1 on every macroblock; `test_p_mba_escape` is built from gaps and escapes; `test_p_motion_residual` is residual-heavy with mid-slice quantiser changes. Three structurally unrelated streams landing on one source points at a common early term rather than a content-specific probe, which makes `progress_error` and `syntax_error` the leading candidates over `residual_error` or the aligned/two-MB/four-MB probes. This is a hypothesis for the diagnostic to confirm or refute, not a conclusion.

#### Ruled Out By Static Analysis:
Two candidates were eliminated this cycle without spending a build, and neither needs diagnostic coverage:

1. **The `Warning (10259)` constant overflow at `mpeg2_h262_p_syntax_probe.sv:327` is benign.** The literal `13'sd4096` overflows a 13-bit signed type to `-4096`, and the unary minus overflows again back to `-4096`, so `value >= -13'sd4096` evaluates to the intended full-range 13-bit lower bound. The f_code-9 range check is correct despite the warning. Cosmetic only; it should be cleaned up eventually but it is not this defect.

2. **The `D_MOTION_PREP` guard set at `mpeg2_h262_p_syntax_probe.sv:607-616` passes on all three streams.** That state raises `probe_error` unless `p_picture_controls_seen`, `picture_structure == 2'b11`, `frame_pred_frame_dct`, and both forward f_codes in 1..9. Reading the generator's picture_coding_extension patching at `tools/streams/h262common.py:330-336`: `f_code[0][0]` and `f_code[0][1]` are both forced to 3, `frame_pred_frame_dct` is explicitly set, `concealment_motion_vectors`/`q_scale_type`/`alternate_scan` are cleared, and `picture_structure` stays at FFmpeg's frame value 3. Every guard is satisfied, so this is not the failing term and picture-level f_code signalling (`H262-022`) is not implicated.

#### Expectation On Diagnostic Depth:
`progress_error` is `p_picture_expected && !p_macroblock_type_seen`, and `p_macroblock_type_seen` at `mpeg2_h262_p_diagnostic_controller.sv:182` is itself a deep conjunction of `mb_seen_decoded` (which folds in `mb_seen_combined`, `residual_decision`, `residual_required_raw`, `residual_success_raw`), `hold_seen_combined`, `two_mb_wait` and `raster_wait`. If `progress_error` is the winning term it is a symptom, not a root cause, and a bare eight-way split would end the cycle knowing little more than it started. The boundary below therefore covers both levels in one build rather than spending two.

#### Proposed Commit Boundary:
Observability only, no behavioral change, matching the Commit-177/178 pattern:

1. Add a `probe_error_source` output to `mpeg2_h262_p_diagnostic_controller`, priority-encoded over the eight terms above in the same order as the existing OR. `probe_error` itself is untouched.
2. Add a second `progress_detail` output to the same module, priority-encoded over the false conjuncts of `p_macroblock_type_seen`: 1 `mb_seen_combined`, 2 `residual_decision`, 3 `residual_required_raw && !residual_success_raw`, 4 `hold_seen_combined`, 5 `two_mb_wait`, 6 `raster_wait`.
3. Route both up through `_p_chain.sv` and `MediaPlayer_top_0x.svh`. `LED_POWER` carries the eight-way source when `LED_USER` blinks 2 and the existing five-way source is 2. `LED_DISK` is temporarily repurposed from `ioctl_download` to blink `progress_detail` when the eight-way source is 8 (`progress_error`), and is otherwise steady off. This is the same displacement Commit 176 used and Commit 177 reverted.
4. Verify both encoders in an iverilog testbench across every code plus the clean case before commit, as was done for Commits 177 and 178.

Only the compiled `_p_chain` path is edited. The three unused same-named `mpeg2_h262_two_picture_probe` variants and the base file are deliberately left alone; editing those was the direct cause of the `466f0b3` and `d5b97ce` build failures.

#### Proposed Validation:
Clean Quartus 17.0.2 build; acceptance remains non-negative setup slack, zero setup TNS, no timing-requirements Critical Warning. Then run each of the three P-final streams once and record USER, POWER and DISK. `test_i_baseline` remains the control on USER only — POWER reads 1 on the control by design and carries no information there. Repeat runs are not required; the fault is deterministic.

#### Build Correction:
`quartus_map` failed: `Error (12002): Port "probe_error_source" does not exist in macrofunction "p_controller" File: mpeg2_h262_two_picture_probe_p_chain.sv Line: 146` (and the same for `progress_detail`). The implementation had added both outputs to `mpeg2_h262_p_diagnostic_controller.sv`, the unused base file — the same class of mistake as `466f0b3` and `d5b97ce`, this time against a third module name. `files.qip` compiles `mpeg2_h262_p_diagnostic_controller_rearm.sv` for this module name.

The base file's edit was reverted (never committed). The `_rearm` variant is not a drop-in equivalent: its `probe_error` is a **nine**-term OR (`syntax_error`, `two_mb_error`, `four_mb_error`, `legacy_error`, `wide_error`, `progress_error`, `residual_error_raw`, `hold_error`, `raster_hold_error`) rather than the base file's eight, `legacy_error`/`wide_error` replace `aligned_error`, and `p_macroblock_type_seen` carries an additional `general_final_proof` short-circuit not present in the base file. Porting the base file's encoding verbatim after only fixing the compile error would have mislabeled every code. Both diagnostics were re-derived directly from `_rearm.sv`'s own signals and re-verified in iverilog against the actual 9-term/short-circuit structure before commit (`7337195`).

A full audit of `rtl/mpeg2_new/` found seven module names with this duplicate-definition pattern in total (`two_picture_probe`, `p_diagnostic_controller`, `p_aligned_motion_syntax_probe`, `p_residual_probe`, `reference_read_probe`, `ddram_store`, `p_luma_macroblock_engine`); only the `files.qip`-listed file compiles for each. Saved to agent memory with an audit command so this is checked before future edits rather than discovered by a failed build.

#### Diagnostic Result:
Corrected `7337195` build is clean: 0 errors across map/fit/asm/sta, 0 Critical Warnings, Flow Status Successful. 29,954 ALMs (71%), 40,849 registers, 559,565 memory bits, 86 RAM, 69 DSP, 3 PLL. Zero TNS on every timing check; worst-case setup +0.297 ns, 54 MHz decoder clock (`general[2]` PLL) setup +0.902 ns.

Hardware regression against the three P-final streams (record USER, POWER, DISK; `test_i_baseline` as USER-only control) is outstanding.

#### Hardware Result:
Run of `7337195`. `LED_USER` and `LED_POWER` share one slot counter, so both light together through the overlap and only the larger code keeps blinking; the user reported the observed composite pattern and it decodes as:

| Stream | USER | POWER | DISK | Meaning |
|---|---|---|---|---|
| `test_p_mba_escape` | 2 | 1 | off | `phase1_probe_error` → `syntax_error` |
| `test_consecutive_chain` | 2 | 3 | off | `phase1_probe_error` → `four_mb_error` |
| `test_p_motion_residual` | 2 | 1 | off | `phase1_probe_error` → `syntax_error` |
| `test_i_baseline` (control) | steady ON | — | — | accepted |

USER 2 on all three matches Commit 179. DISK stayed off on every stream, so `progress_error` (code 6) is **not** the failing term. The Commit-179 hypothesis that `progress_error`/`syntax_error` were the leading candidates was half right: `syntax_error` is confirmed on two streams, `progress_error` is refuted outright. Building the `progress_detail` sub-code in the same commit cost nothing and eliminated it as a candidate in a single pass.

There are two distinct faults, split by stream — the opposite of the Commit-179 conclusion, and this time named rather than inferred.

#### Interpretation:
The failing terms are controlled-pattern observers whose own documented scope excludes these streams, not general decode faults.

`mpeg2_h262_p_four_mb_two_row_syntax_probe.sv:20-23` states its boundary explicitly: "The controlled semantic boundary remains intentionally narrower than a full P parser: every transmitted macroblock must be Table B.3 motion-forward-only (001), motion_code=(0,0), no residual." `test_consecutive_chain` is a six-generation P chain built from MC-not-coded macroblocks carrying **explicit non-zero motion vectors**, which that observer is documented not to accept. `four_mb_error` is therefore the observer correctly rejecting a stream outside its designed scope, not the decoder failing to decode legal H.262.

The same applies to `syntax_error` on the other two streams: it is `syntax_error_raw` qualified by none of the specialized observers having claimed the stream, so it fires when the generalized `mpeg2_h262_p_syntax_probe` meets syntax outside its controlled subset. That probe has 18 separate `probe_error` assertion sites; splitting them would need a further diagnostic cycle and is not proposed, because the scope mismatch already explains the result.

This is a direct consequence of Commit 175. The retired generator set produced streams shaped to match these observers; Commit 175 re-derived coverage from scratch with old-set coverage explicitly not ported, so the six replacement streams legitimately exceed the observer boundary. The observers were never widened to match.

#### Critical Scope Finding:
`mpeg2_new_phase1_probe_error` has exactly two consumers in the whole design (`MediaPlayer_top_07.svh:74` and `:112`): the acceptance LED term and the diagnostic error code. **It does not gate decode, reconstruction, DDR, or display.** The controlled observers do influence real byte-stream flow, but through the separate `stream_hold` path, not through `probe_error`.

The acceptance LED is therefore currently reporting observer scope rather than decoder health, and cannot answer whether these three streams decode correctly. The only evidence bearing on actual decode remains the Commit-175 photographic analysis, which showed the final P's residual content absent from the display — and that was taken against the `4c65826` build, before Commits 176-180. Whether a genuine decode gap still exists is untested and must not be inferred from the LED either way.

#### Status:
- [x] Built — clean flow, zero TNS, no critical warnings (`7337195`)
- [x] Passed — diagnostic named both faults; see Commit-181 proposal

---
## 181 COMMIT Unreleased 05422a5 2026-08-17T01:58:06-07:00

#### Coming From:
Unreleased 7337195

#### Purpose:
Stop the controlled-pattern observers from reporting acceptance failures on generalized streams they are documented not to cover, so the acceptance LED measures the decoder again.

#### Scoping:
Commits 176-180 spent five cycles narrowing a signal that turns out to be an observer-scope artifact. `probe_error` gates only the LED, and the failing terms are two Phase-1T/1U observers rejecting streams outside their own stated boundaries. Continuing to split `syntax_error`'s 18 sites would spend a sixth cycle refining the same artifact.

`syntax_error` already implements the correct pattern: it is qualified by `!two_mb_seen && !four_mb_seen && !legacy_candidate && !legacy_seen && !wide_candidate && !wide_seen`, so it only counts when no specialized observer has claimed the stream. `four_mb_error` carries no equivalent qualification and latches even when the observer has effectively disqualified itself.

#### Proposed Commit Boundary:
Behavioral, narrow, one proof boundary:

1. Qualify each controlled observer's error contribution so it counts only while that observer still claims the pattern it is designed to prove. An observer that meets syntax outside its documented subset should withdraw its claim rather than latch a permanent acceptance failure.
2. Leave `stream_hold` semantics untouched. Flow control is a separate path with real timing consequences and is not implicated by this result.
3. Leave `probe_error`'s remaining terms, all decode/DDR error flags, and the acceptance prerequisite chain unchanged.

Risk: an observer that withdraws too readily could mask a real syntax fault. Mitigation is that the retired-suite patterns those observers were built for are gone, so their remaining value is narrow; and the eight other error flags plus the twelve acceptance prerequisites are unaffected and still gate the LED.

#### Proposed Validation:
Clean Quartus 17.0.2 build; non-negative setup slack, zero setup TNS, no timing-requirements Critical Warning. Then run all six Commit-175 streams and record USER/POWER/DISK. `test_i_baseline`, `test_b_bidirectional` and `test_pb_restricted_slices` must keep their existing accepted state — any regression there means an observer was disqualified too aggressively.

Separately, and regardless of LED state, capture the display output for the three P-final streams and compare against the FFmpeg reference the generators already validate to, using the Commit-175 macroblock-boundary z-score method. The LED cannot answer whether these streams decode correctly; only the picture can. If the LED accepts but the picture is wrong, the real decode defect is still open and becomes the next boundary.

#### Outcome:
`05422a5` implements the approved boundary in `mpeg2_h262_p_diagnostic_controller_rearm.sv` only. Root cause named: each controlled observer admits only its own documented subset, keyed on the picture_coding_extension `f_code` — the four-MB raster observer claims `f_code` 2 (`..._p_four_mb_two_row_syntax_probe.sv:512`), the Commit-166 wide parser claims `f_code` 3 (`..._p_wide_motion_syntax_probe_part3.svh:273`). The Commit-175 generators emit `f_code` 3, so `four_mb_candidate` is **false by construction** on all six streams. That observer never claimed `test_consecutive_chain`, yet its `probe_error` still latched from an internal scope check and permanently failed acceptance for a stream it was not proving — the POWER 3 reading.

Each observer error is now qualified by that observer's own claim (`two_mb_seen`, `four_mb_candidate||four_mb_seen`, `legacy_mode`, `wide_mode`). `syntax_error` already carried the equivalent qualification and is unchanged. `probe_error` keeps every term; only unowned contributions are dropped. `probe_error_source` was updated to the qualified terms so the diagnostic stays truthful.

#### Timing Regression And Closure (Commit 182, same upload):
The Commit-181 build failed STA: 54 MHz decoder clock setup **-0.081 ns / -0.629 ns TNS**, `Critical Warning (332148)`. A Fitter re-run on the same netlist reproduced it bit-for-bit, ruling out placement nondeterminism (`NUM_PARALLEL_PROCESSORS ALL` left unchanged by user direction — it affects compile time, not results).

`report_timing` traced the path to `mpeg2_h262_b_bidirectional_raster_engine`: `motion_word[24]` → `out_reg`, twelve logic levels carrying the entire motion-vector address computation in series with the byte select, prediction accumulate, bidirectional average, residual add and clip — all in one cycle, 17.929 ns of an 18.518 ns budget (97%). **No Commit-181 signal appears anywhere on that path**; the near-free added gates only perturbed placement enough to tip an already-marginal path that had been reading +0.902 ns.

Fix: `src_x_tap[2:0]` selects a byte of the returned 64-bit DDR word, but data does not arrive until several cycles after the request is accepted, and every input feeding `src_x_tap` (`motion_word`, `col`, `mrow`, `blk`, `ei`, `tap_index`, `pred_direction`) is held constant across that wait. The select is now registered at request accept and the registered copy drives the byte mux. No computed value changes — same number, captured from the same evaluation of `src_x_tap` that formed the address. Verified in an iverilog testbench across varying DDR latency (1-5 cycles), `ddram_busy` stalls, tap advances within a half-sample block, the bidirectional second pass where `pred_direction` flips the selected vector, and macroblock changes.

Rejected alternative: rerolling the Fitter seed until it closes. That is luck, not closure, and the next commit re-rolls it; Commit 171→172 set the precedent of fixing by registering.

#### Build:
`05422a5` clean from wiped `db`/`incremental_db`/`output_files`: 0 errors across map/fit/asm/sta, 0 Critical Warnings, Flow Status Successful. 30,170 ALMs (72%), 40,854 registers, 559,565 memory bits, 86 RAM, 69 DSP, 3 PLL. Zero TNS on every timing check. 54 MHz decoder clock setup **-0.081 → +1.176 ns**; worst-case setup +0.313 ns. The critical path has moved off the B raster engine entirely (now `p_residual_probe|g_success` → `explicit_probe|error`, 15 levels, +1.176 ns), confirming a structural fix rather than a number nudged over the line.

#### Validation:
Run all six Commit-175 streams and record USER/POWER/DISK. `test_p_mba_escape`, `test_consecutive_chain`, `test_p_motion_residual` are the targets. `test_i_baseline`, `test_b_bidirectional` and `test_pb_restricted_slices` are regression guards and must keep their existing accepted state — `test_b_bidirectional` especially, since Commit 182 modifies the B raster engine that Commits 139/162 hardware-qualified.

Expected: `test_consecutive_chain` should clear, since its `four_mb_error` was unowned by construction. `test_p_mba_escape` and `test_p_motion_residual` reported `syntax_error`, which was already correctly qualified, so they may still fail — if so the open question is why the wide parser does not claim streams matching its own `f_code` 3 admission criteria, and that becomes the next boundary.

Independently of the LEDs, capture the display for the three P streams and compare against the FFmpeg reference using the Commit-175 macroblock-boundary z-score method. The acceptance LED cannot establish that these streams decode correctly; only the picture can.

#### Files Modified:
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh

#### Hardware Result:
User reports all six streams pass on `05422a5`, including the three P-final targets and all three regression guards. `test_b_bidirectional` passing is the one that matters most, since Commit 182 modified the B raster engine that Commits 139/162 hardware-qualified. The Commit-181 ownership fix is accepted; `test_p_mba_escape` and `test_p_motion_residual` also cleared, which is better than predicted — the `syntax_error` qualification was already correct, so those two were expected to possibly persist.

#### Photographic Evidence — Negative Result:
Three display photographs were captured to `.ai/current_results/` and analysed. All three show clean 720x480 rendering: correct geometry, no blocking, no tearing, no dropped slices, pattern consistent with the generator's synthetic diagonal source. That rules out gross decode corruption.

**They do not establish that the final P was presented, and must not be recorded as if they do.** Decoding each stream with FFmpeg and diffing the I picture against the final P picture:

| Stream | Macroblocks differing (of 1350) | Mean abs luma diff |
|---|---|---|
| `test_p_motion_residual` | 13 (1.0%) | 0.111 / 255 |
| `test_p_mba_escape` | 14 (1.0%) | 0.082 / 255 |
| `test_consecutive_chain` | **1** (0.1%) | 0.031 / 255 |

99.0-99.9% of every frame is pixel-identical between the I and the final P. A display stuck on the I frame — precisely the Commit-175/176 failure mode — photographs indistinguishably from a perfect decode. `test_consecutive_chain` is the extreme case: after a six-generation P chain, exactly one macroblock out of 1350 differs from the I.

A targeted check at the known differing coordinates does not rescue this. Those are 16x16 regions; resolving them in a handheld photograph requires registration to within a few pixels through perspective skew, JPEG artifacts, moire and glare, against a high-frequency diagonal gradient. Measurement noise would swamp a signal confined to 1% of the frame.

The earlier claim in this log that "only the picture can" settle decode correctness was right that the acceptance LED cannot, and wrong that these pictures can. The I-versus-P separability should have been measured before requesting the photographs.

#### Follow-on: `test_p_visual_discriminator` (`ea6b9ef`):
`tools/streams/generate_test_p_visual_discriminator.py` adds a stream built for exactly this question and nothing else. One I, one P; the P displaces two diagonally opposite quadrants vertically by 24 px (48 half-pel, inside the f_code 3 range of [-64, 63]). Top quadrants displace down and bottom quadrants up so every prediction reads inside the reference frame — a single sign would read off the frame edge.

675 of 1350 macroblocks change (50.0%), against 0.1-1.0% for the existing set. The source luma pattern repeats every 40 rows, so 24 px is 60% of a period and lands the shifted quadrants visibly out of phase. Pass/fail is absolute rather than comparative: a presented P shows two hard seams crossing at frame centre in a 2x2 pattern; a stuck I frame shows an unbroken diagonal gradient with no seams. No reference image, no registration, no measurement.

Verified pixel-exact against FFmpeg. The generator additionally refuses to emit a stream whose macroblock change rate falls below 40%, so the discriminating property cannot silently regress. Binary `.m2v` is generated locally per the `tools/streams` convention; only the generator is committed.

Not yet hardware-run. This stream proves nothing about residual, escape or reference chaining — the other five cover those — only that the final P reached the display, and it proves that from a photograph.

#### Status:
- [x] Built — clean flow, zero TNS, no critical warnings (`05422a5`)
- [x] Passed — all six streams accepted on hardware; LED qualification complete
- [ ] Open — P presentation not yet photographically confirmed; run `test_p_visual_discriminator`

---
## 182 COMMIT Unreleased a2debaa 2026-08-17T04:56:49-07:00

#### Coming From:

Unreleased 05422a5

#### Purpose:

Restore durable HDMI setup margin by removing the ASCAL vertical line-boundary comparison from its cycle-critical accumulator decision.

#### Outcome:

`a2debaa` registers the `o_vcpt_pre3 = o_vmin` predicate every HDMI clock and consumes that aligned predicate when the vertical accumulator advances. A clean Quartus 17.0.2 flow completed with zero setup TNS and no timing-requirements Critical Warning; the former vertical boundary path left the HDMI critical set and both HDMI and decoder setup slack are positive.

#### Next Steps:

Hardware-run the standing stream matrix with particular attention to scaler output stability, then run the P-presentation visual discriminator and report whether the final P frame shows the expected quadrant seams.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [ ] Passed

---
## 183 COMMIT Unreleased f9b9be6 2026-08-17T05:16:03-07:00

#### Coming From:

Unreleased a2debaa

#### Purpose:

Make the P-final acceptance diagnostic report the first causal observer failure instead of reclassifying sticky errors later in a multi-picture stream.

#### Outcome:

The exact pre-Commit-182 control reproduces the same hardware signatures, clearing ASCAL as a cause, while RTL replay makes `syntax_error_raw` rise at the same first-P byte in all three streams and never raises the four-MB observer. Commit `f9b9be6` snapshots the complete diagnostic hierarchy on the first visible parent error in `MediaPlayer_top_07.svh`, preventing later sticky flags or mutable ownership claims from relabeling it without changing decoder behavior. The clean Quartus 17.0.2 build closes with zero TNS, +0.625 ns global setup, +2.159 ns decoder setup, 30,153 ALMs, and 40,880 registers.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, and `test_consecutive_chain.m2v` once each and record USER, POWER, and DISK. The first-fault code must remain stable through the full consecutive chain; after hardware confirms the common observer artifact, scope a separate behavioral commit to retire obsolete controlled-observer errors from acceptance.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [x] Passed

---
## 184 COMMIT Unreleased 4f1c057 2026-08-17T06:04:32-07:00

#### Coming From:

Unreleased f9b9be6

#### Purpose:

Remove obsolete controlled-parser observer failures from generalized P-stream acceptance without weakening functional pipeline checks.

#### Outcome:

Commit 183 hardware makes all three P-final streams converge on the same USER/POWER `1/4` first-fault signature, proving that the prior late `four_mb_error` classification was a mutable diagnostic artifact. Commit `4f1c057` removes only the five historical controlled parser observers from `probe_error`; progress, residual, stream-hold, raster-hold, bookkeeper, publication, reference-progress, decoder, reconstruction, DDR, and presentation checks remain. Simulation verifies retired observers cannot raise acceptance error and functional codes 6 through 9 remain intact. The clean Quartus 17.0.2 build closes with zero TNS, +0.470 ns global setup, +2.714 ns decoder setup, 30,069 ALMs, and 40,861 registers.

#### Next Steps:

Run all six Commit-175 streams and record acceptance, then run `test_p_visual_discriminator.m2v` and confirm that the final displayed P frame shows two hard seams crossing at frame center in a 2x2 pattern rather than an unbroken diagonal gradient.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 185 COMMIT Unreleased d5e5f62 2026-08-17T06:31:10-07:00

#### Coming From:

Unreleased 4f1c057

#### Purpose:

Localize the generalized P raster transaction stage that prevents parsed P pictures from reaching publication.

#### Outcome:

Commit `d5e5f62` adds a monotonic seven-stage trace to the compiled generalized P raster engine and reports its terminal stage on LED_DISK only when the existing diagnostic identifies missing P publication. Simulation verifies admission, execution, reference-read, reconstruction, DDR-store acknowledgement, verification-readback, and persistence codes in order. The clean Quartus 17.0.2 build closes with zero setup TNS, +0.533 ns global setup, +1.978 ns decoder setup, 30,071 ALMs, and 40,713 registers; decoder, storage, publication, and presentation behavior are unchanged.

#### Next Steps:

Run `test_p_motion_residual.m2v` and `test_p_visual_discriminator.m2v`, recording USER, POWER, and DISK for each. DISK codes 1 through 7 name the deepest completed raster stage; code 7 with POWER 4 isolates the loss after persistence export, while any lower code identifies the stalled engine boundary. Confirm separately whether the discriminator image still lacks the center quadrant seams.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 186 COMMIT Unreleased 12b22cd 2026-08-17T06:58:32-07:00

#### Coming From:

Unreleased d5e5f62

#### Purpose:

Complete generalized P parsing and raster publication when the final P picture is delimited by the MPEG sequence-end start code.

#### Outcome:

Commit `12b22cd` accepts MPEG sequence-end code `0xB7` as a legal boundary after the final wide-P slice. Exact controller replay changes the visual discriminator from 1,305 motion events with no completion or terminator to all 1,350 events, wide completion, and the raster terminator. The clean Quartus 17.0.2 build closes with zero setup TNS, +0.244 ns global setup, +2.139 ns decoder setup, 29,920 ALMs, and 40,850 registers. Residual and MBA-escape streams retain separate earlier parser stops outside this commit.

#### Next Steps:

Run `test_p_visual_discriminator.m2v` and record USER, POWER, and DISK after the initial shared blink. Acceptance must clear, DISK must advance beyond capture, and the displayed P must show the center quadrant seams. After hardware confirmation, isolate the earlier content-specific parser stops in the residual and MBA-escape streams as separate boundaries.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 187 COMMIT Unreleased 92546f5 2026-08-17T07:21:08-07:00

#### Coming From:

Unreleased 12b22cd

#### Purpose:

Remove the two diagnosed wide-P parser limits blocking leading skipped macroblocks and the validated 19-block residual transaction.

#### Outcome:

Commit `92546f5` permits a P slice's first macroblock address increment to establish leading skipped macroblocks through the existing zero-motion skip path, and widens residual descriptor transport and raster storage from 16 to 32 entries. Exact compiled-controller replay completes the MBA-escape, motion-residual, and visual-discriminator streams without a wide-parser error; MBA-escape emits exactly 1,350 motion words, and the residual transaction carries all 19 descriptors. The dedicated raster-capacity simulation passes with 19 descriptors, 1,350 motion words, and an accepted terminator. The clean Quartus 17.0.2 build closes with zero setup TNS, +0.045 ns global setup, +2.133 ns decoder setup, 30,928 ALMs, 41,745 registers, and no Critical Warning.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, and `test_p_visual_discriminator.m2v` on hardware. Record USER, POWER, and DISK after the initial shared blink, and confirm that the visual discriminator still displays the center quadrant seams. Clean acceptance of both formerly blocked streams and preserved discriminator seams will pass this boundary.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 188 COMMIT Unreleased dbc3000 2026-08-17T07:44:50-07:00

#### Coming From:

Unreleased 92546f5

#### Purpose:

Identify the frontend syntax condition that remains latched after functionally successful generalized P playback.

#### Outcome:

Commit 187 hardware gives the same USER/POWER `1/4` indication with no DISK activity on all three generalized P streams while the discriminator retains its four visible quadrants, passing the parsing, reconstruction, publication, and presentation boundary. Commit `dbc3000` adds a sticky five-bit source covering all 21 frontend `syntax_error` assertion sites and reports it on DISK for that error class without changing decode control. Exact frontend replay leaves error and source clear on all three streams. The clean Quartus 17.0.2 build closes with zero setup TNS, +0.276 ns global setup, +1.948 ns decoder setup, 31,043 ALMs, 41,883 registers, and no Critical Warning.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, and `test_p_visual_discriminator.m2v`, recording USER, POWER, and DISK across one complete 16-second diagnostic frame. If USER truly reports syntax error, DISK will blink its assertion-site code from 1 through 21; DISK remaining off will prove the prior USER count was not top-level syntax error. Confirm the visual discriminator seams remain visible.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 189 COMMIT Unreleased 06bce8f 2026-08-17T08:04:37-07:00

#### Coming From:

Unreleased dbc3000

#### Purpose:

Replace mutable overlapping playback-time LED indications with an unambiguous settled post-stream diagnostic snapshot.

#### Outcome:

Commit 188 hardware again displays the generalized P discriminator's four quadrants and center seams while DISK remains off throughout the reported USER/POWER `1/4` pattern, matching exact frontend replay and proving no frontend syntax assertion occurred. Commit `06bce8f` waits one second after sequence end, snapshots the settled hierarchy, resets the epoch, and reports USER, POWER, and DISK in non-overlapping windows without changing decoder behavior. A first clean build exposed the unrelated marginal HDMI path at -0.092 ns; reusing the blink divider instead of a separate wide settlement timer produced a clean Quartus 17.0.2 build with zero setup TNS, +0.432 ns global setup, +1.724 ns decoder setup, 30,923 ALMs, 41,806 registers, and no Critical Warning.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, and `test_p_visual_discriminator.m2v`, watching one complete 16-second frame after the one-second settlement delay. USER owns the first three seconds, POWER the next five, and DISK the final eight; record whether each window is solid, dark, or blinking and count any blinks. The clean-success expectation is solid USER, then solid POWER, then dark DISK, with discriminator seams preserved.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 190 COMMIT Unreleased 2849c38 2026-08-17T15:03:19-07:00

#### Coming From:

Unreleased 06bce8f

#### Purpose:

Slow the settled diagnostic blink cadence by half so each reported code can be counted reliably on hardware.

#### Outcome:

Commit `2849c38` doubles each settled diagnostic lit and dark slot from 125 ms to 250 ms while preserving the one-second post-sequence settlement delay, numeric codes, non-overlapping windows, and decoder behavior. The complete report is now 32 seconds. The clean Quartus 17.0.2 build closes with zero setup TNS, +0.180 ns global setup, +1.492 ns decoder setup, 30,974 ALMs, 41,821 registers, and no Critical Warning.

#### Next Steps:

Rerun `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, and `test_p_visual_discriminator.m2v`. After the one-second settlement delay, observe one complete 32-second report: USER owns six seconds, POWER the next ten, and DISK the final sixteen. Record whether each window is solid, dark, or blinking and count any blinks; confirm the visual discriminator seams remain visible.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 191 COMMIT Unreleased 6281359 2026-08-17T15:21:56-07:00

#### Coming From:

Unreleased 2849c38

#### Purpose:

Make generalized P macroblock completion evidence durable and stop classifying its normal pre-completion absence as a sticky decoder error.

#### Outcome:

Commit 190 hardware makes the settled report unambiguous and identical on all three generalized P streams: USER 2, POWER 6, DISK 1, while the visual discriminator retains its center seams. Commit `6281359` incorporates source commit `85e8d4c`, which latches generalized completion and retires transient `progress_error`, plus an endpoint-scoped false path for the legacy asynchronous `hps_io.video_calc` telemetry crossing that caused the first clean build's false hold failure. Exact controller replay passes all three target streams and preserves functional error codes 7 through 9. The final clean Quartus 17.0.2 build closes with zero setup and hold TNS, +0.346 ns global setup, +0.253 ns global hold, +2.107 ns decoder setup, 31,066 ALMs, 41,850 registers, and no Critical Warning. Qualified RBF `MediaPlayer_commit191_6281359.rbf` has SHA-256 `c96b98df825a23f065345185a6d914081fb59ad3a13af571970ed35344ea94af`; Audio project `fd90c77` remains integration-compatible.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_p_visual_discriminator.m2v`, `test_i_baseline.m2v`, and `test_b_bidirectional.m2v` using the qualified RBF. For each stream, allow the one-second settlement and complete 32-second LED report, then record USER, POWER, and DISK behavior. The three P targets should report solid USER, solid POWER, and dark DISK; the visual discriminator must retain its four quadrants and center seams, while the I and B streams must retain their accepted display and diagnostic behavior.

#### Files Modified:

- MediaPlayer.sdc
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 192 COMMIT Unreleased 454336d 2026-08-17T16:09:53-07:00

#### Coming From:

Unreleased 6281359

#### Purpose:

Align reference-picture completion and settled prerequisite reporting with the generalized P publication path and the already accepted I/B modes.

#### Outcome:

Commit `454336d` exports second-reference completion from either the legacy I-only bookkeeper or the combined I/P publication count and suppresses P-only prerequisite sub-codes after the existing normal I/P/B acceptance result passes. Focused simulation proves generalized P persistence makes the second-reference result durable, preserves the legacy result, clears accepted I/P/B prerequisite reporting, and retains real-error priority. A clean Quartus 17.0.2 build completes with zero TNS, no Critical Warning, +0.466 ns global setup, +0.249 ns global hold, +1.959 ns decoder setup, 31,036 ALMs, 41,842 registers, 592,333 memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs. Qualified RBF `MediaPlayer_commit192_454336d.rbf` has SHA-256 `c2c45fa1fac3514362e8181c1513c4be1887329c5c9811c7f1ed072c06ec8404`; Audio project `fd90c77` remains integration-compatible.

#### Next Steps:

Run `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_p_visual_discriminator.m2v`, `test_i_baseline.m2v`, and `test_b_bidirectional.m2v` using the qualified RBF. Each accepted stream must match the I baseline with USER solid and no POWER or DISK code; the visual discriminator must retain its four quadrants and center seams.

#### Files Modified:

- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv

#### Status:

- [x] Built
- [x] Passed

---
## 193 COMMIT Unreleased a42bb74 2026-08-17T16:38:38-07:00

#### Coming From:

Unreleased 454336d

#### Purpose:

Generalize the progressive 4:2:0 P path from fixed `f_code=(3,3)` to independently picture-signaled horizontal and vertical `f_code` values from 1 through 4.

#### Outcome:

Commit `a42bb74` admits independently signaled progressive-P horizontal and vertical `f_code` values 1 through 4, consumes the corresponding zero through three residual bits per component, and applies H.262 motion-vector reconstruction and wraparound without changing the fixed-3 B path. Deterministic stream generation covers unequal component pairs, every admitted value, nonzero residuals, both signs, predictor wraparound, and chained references. Exact replay passes all 5,400 new vectors and 12,150 standing P vectors; all eight standing generators remain pixel-exact or within their established tolerance. A clean Quartus 17.0.2 build completes with zero TNS, no Critical Warning, +0.243 ns global setup, +0.245 ns global hold, +2.290 ns decoder setup, 31,398 ALMs, 41,994 registers, 592,333 memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs. Qualified RBF `MediaPlayer_commit193_a42bb74.rbf` has SHA-256 `ff29d0f609e57c4b55d4adaee5ca80448c7212fcbb4bae808d12b8e849ad1c18`; generated stream `test_p_f_code_range.m2v` has SHA-256 `b6a9ad050171446b2c55cd18e37d0727063858d49f4c4bdad6a817894fc6d437`; Audio project `fd90c77` remains integration-compatible.

#### Next Steps:

Run `test_p_f_code_range.m2v`, `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_p_visual_discriminator.m2v`, `test_i_baseline.m2v`, and `test_b_bidirectional.m2v` using the qualified RBF. Each accepted stream must settle with USER and POWER solid and DISK dark; the visual discriminator must retain its four quadrants and center seams.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/h262common.py
- tools/streams/generate_test_p_f_code_range.py

#### Status:

- [x] Built
- [ ] Passed

---
## 194 COMMIT Unreleased ??? 2026-08-17T17:15:45-07:00

#### Coming From:

Unreleased a42bb74

#### Purpose:

Generalize the progressive 4:2:0 B path from fixed `f_code=(3,3,3,3)` to independently picture-signaled forward and backward horizontal and vertical `f_code` values from 1 through 4.

#### Outcome:

Commit 193 passes all six requested hardware streams with the expected settled USER/POWER solid and DISK-dark result. The six photographs confirm the standing I, P and B rasters, the visual discriminator's horizontal and vertical center seams, and the new P `f_code` range stream's localized motion-vector markers. Static tracing identifies the next remaining fixed-3 boundary in the B parser: admission requires all four picture-coding-extension fields to equal 3, every nonzero component consumes exactly two residual bits, reconstruction uses a fixed `f_code=3` function, and the shared B selector also requires the forward pair to equal 3. The existing signed eight-bit B vector transport already covers the complete `f_code=4` reconstructed range of -128 through +127, so no raster or DDR interface widening is required.

#### Next Steps:

Capture and independently validate all four B-picture `f_code` fields, consume zero through three residual bits for each applicable forward or backward component, apply the existing H.262 reconstruction and wraparound rule using the selected field, and relax only the generalized B selector while preserving fixed-3 behavior and the P path. Extend the shared deterministic stream patcher and add one pixel-verified 720x480 B regression covering every admitted value, unequal forward/backward component pairs, nonzero residuals, both signs, independent predictor reuse and wraparound across two B reference pairs. Run focused exact parser/raster replay, regenerate every standing stream, complete a clean Quartus 17.0.2 build with nonnegative setup and hold slack and zero TNS, then hardware-run the new stream plus the six Commit-193 guards with the visual seams retained.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/h262common.py
- tools/streams/generate_test_b_f_code_range.py

#### Status:

- [ ] Built
- [ ] Passed

---
