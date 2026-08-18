
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
- [x] Passed

---
## 194 COMMIT Unreleased b1bde49 2026-08-17T17:15:45-07:00

#### Coming From:

Unreleased a42bb74

#### Purpose:

Generalize the progressive 4:2:0 B path from fixed `f_code=(3,3,3,3)` to independently picture-signaled forward and backward horizontal and vertical `f_code` values from 1 through 4.

#### Outcome:

Commit 193 passes all six requested hardware streams with the expected settled USER/POWER solid and DISK-dark result; the photographs confirm the standing I, P and B rasters, the visual discriminator seams, and the P `f_code` range markers. Commit `b1bde49` captures and independently applies all four B-picture `f_code` fields from 1 through 4, consumes zero through three component residual bits, and uses the established H.262 reconstruction and wraparound rule without widening the signed eight-bit B vector transport. Exact parser replay passes both new B pictures and all 2,700 emitted vector records. The new stream is pixel-exact for both B pictures, and all nine generators pass their established pixel-exact or IDCT-tolerant verification. A clean Quartus 17.0.2 build completes with zero TNS, no Critical Warning, +0.387 ns global setup, +0.207 ns global hold, +2.012 ns decoder setup, 31,625 ALMs, 42,223 registers, 592,333 memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs. Qualified RBF `MediaPlayer_commit194_b1bde49.rbf` has SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`; generated stream `test_b_f_code_range.m2v` has SHA-256 `70da72fd53a1e3a6c2ac5b87bcf26dbfbf7398fb6ae526903d06e0402d54dacd`; Audio project `fd90c77` remains integration-compatible.

#### Next Steps:

Run `test_b_f_code_range.m2v`, `test_p_f_code_range.m2v`, `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_p_visual_discriminator.m2v`, `test_i_baseline.m2v`, and `test_b_bidirectional.m2v` using the qualified RBF. Each accepted stream must settle with USER and POWER solid and DISK dark; the new B stream must present a stable decoded raster, and the visual discriminator must retain its four quadrants and center seams.

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

- [x] Built
- [x] Passed

---
## 195 VERSION v0.5.0 56db0c4 2026-08-17T18:02:13-07:00

#### Coming From:

Unreleased b1bde49

#### Purpose:

Publish the hardware-qualified 720x480 progressive 4:2:0 I/P/B and independently signaled P/B `f_code` 1-through-4 milestone as pre-release v0.5.0.

#### Outcome:

Commit 194 passes the authoritative seven-stream hardware matrix with USER and POWER solid, DISK dark, and all decoded images accepted; the former nine-stream matrix is invalid for release qualification going forward. A fresh GitHub `master` clone at `424eec4` with no prior build products reproduces all seven deterministic stream hashes and completes Quartus Prime 17.0.2 with zero TNS, no Critical Warning, +0.387 ns setup, +0.207 ns hold, +2.012 ns decoder setup, 31,625 ALMs, 42,223 registers, 592,333 memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs. Its RBF is bit-identical to the already hardware-accepted Commit-194 artifact at SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`. Commit `56db0c4` publishes the v0.5.0 README, changelog milestone, and release notes covering the 720x480 P/B envelope, independently signaled component `f_code` values 1 through 4, qualification evidence, and current limitations without changing decoder RTL; Audio project `fd90c77` remains integration-compatible.

#### Next Steps:

Have the user create the annotated `v0.5.0` tag at exact release commit `56db0c4` and publish the GitHub pre-release titled `MiSTer Media Player v0.5.0`, attaching the qualified artifact as `MediaPlayer_20260817.rbf` with SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`. Verify the remote tag, release flags, title, commit target, asset name, and asset digest after publication, then resume development under a fresh Unreleased boundary.

#### Files Modified:

- README.md
- CHANGELOG.md
- docs/RELEASE_NOTES_v0.5.0.md

#### Status:

- [x] Built
- [x] Passed

---
## 196 COMMIT Unreleased d26c37d 2026-08-17T18:46:15-07:00

#### Coming From:

v0.5.0 56db0c4

#### Purpose:

Record the verified v0.5.0 publication on the development branch and correct the README's current-release status.

#### Outcome:

Commit `d26c37d` identifies v0.5.0 as the current published hardware-qualified milestone and names binary asset `MediaPlayer_20260817.rbf`, replacing the stale v0.4.0/current-candidate language without changing decoder RTL or the tagged release. Remote annotated tag `v0.5.0` peels to exact release commit `56db0c4`; the GitHub release is published as a pre-release titled `MiSTer Media Player v0.5.0`; and the uploaded RBF matches the qualified artifact at SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`. The documentation-only commit retains the already clean-built, hardware-passed v0.5.0 RTL unchanged, so no additional Quartus or MiSTer run is required for this boundary.

#### Next Steps:

Prepare the next Unreleased capability proposal for post-v0.5.0 development, retaining the authoritative seven-stream hardware matrix as the mandatory regression gate and treating any new capability stream as supplemental unless the user explicitly approves a matrix change.

#### Files Modified:

- README.md

#### Status:

- [x] Built
- [x] Passed

---
## 197 COMMIT Unreleased 8c9cdaa 2026-08-17T20:53:22-07:00

#### Coming From:

Unreleased d26c37d

#### Purpose:

Establish the deterministic compatibility corpus and failure-classification baseline for the eight-commit v0.6.0 progressive 4:2:0 compatibility roadmap.

#### Outcome:

Commit `8c9cdaa` adds a source-only generator and H.262 structural classifier for four supplemental 720x480 progressive 4:2:0 compatibility streams without changing synthesized RTL or replacing the authoritative seven-stream v0.5.0 matrix. The authored I/P/B case verifies repeated same-row slices and predictor-reset behavior; ordinary single-threaded FFmpeg cases establish an 11,367-byte dense slice, 128 intra macroblocks within P pictures alongside predicted and skipped modes, and a 72-picture long-GOP soak input. All four remain inside the intended frontend envelope, every generated file and encoder invocation is recorded in a local JSON manifest, and all seven standing generators reproduce their published hashes and software-reference results.

#### Next Steps:

Generalize the active P and B slice ingestion paths so independently coded legal slices no longer depend on whole-slice byte capture or restricted row-transition ownership, then validate the authored multi-slice stream and all seven standing generators before a clean Quartus build and MiSTer regression.

#### Files Modified:

- tools/streams/generate_test_progressive_compatibility.py
- tools/streams/analyze_h262_compatibility.py
- tools/streams/generate_test_pb_restricted_slices.py

#### Status:

- [x] Built
- [x] Passed

---
## 198 COMMIT Unreleased 6c6854c 2026-08-17T21:53:24-07:00

#### Coming From:

Unreleased 8c9cdaa

#### Purpose:

Generalize progressive P/B slice ingestion beyond whole-slice byte capture and restricted row-transition ownership.

#### Outcome:

Commit `6c6854c` converts both active 512-byte P/B capture arrays into refillable backpressured parser windows, retains the final two bytes across refills so a `00 00 01` prefix may cross a window boundary, and resumes the syntax state machine without changing macroblock, predictor, residual, reconstruction, or reference ownership. A deterministic 194,005-byte I/P/B stream places 2,285-byte P and 2,291-byte B slice payloads across eight refills per parser; isolated RTL replay reports both pictures without syntax errors and preserves all 1,350 P macroblocks, while software reference decoding makes every P/B frame pixel-identical to the I reference. The Commit-197 multi-slice replay and all seven standing generators retain their accepted hashes and reference results. Fitter seed 2 removes the unrelated marginal HDMI placement failure without changing RTL behavior; the final clean Quartus 17.0.2 build completes in 14 minutes 24 seconds with zero setup and hold TNS, no Critical Warning, +0.042 ns global setup, +0.246 ns global hold, +1.487 ns decoder setup, 40,807 ALMs, 50,336 registers, 584,141 memory bits, 88 RAM blocks, 69 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `09e2ecf7997cbebe7e110e50b7e8238fdc14f7f27cc042de865ef9c21562dd4c`; parser-window stream `test_pb_parser_window.m2v` has SHA-256 `1659d08a7393b4b82e77cb869ae139d0205de8b6c911c3f3d770fc03b744b801`.

#### Next Steps:

Run the parser-window stream, Commit-197 multi-slice stream, and authoritative seven-stream matrix on MiSTer using the Commit-198 RBF, confirming stable decoded output and no USER, POWER, or DISK error indication. After hardware acceptance, begin P-picture intra-macroblock integration as Commit 199 while preserving predicted, skipped, and residual-coded macroblock behavior.

#### Files Modified:

- MediaPlayer.qsf
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- tools/streams/generate_test_pb_parser_window.py
- tools/streams/tb_h262_parser_windows.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 199 COMMIT Unreleased af20d28 2026-08-17T22:13:12-07:00

#### Coming From:

Unreleased 6c6854c

#### Purpose:

Identify the first prediction-pipeline assertion raised by legal same-row P/B slice partitions without changing decoder behavior.

#### Outcome:

Commit `af20d28` preserves USER error class 3 while snapshotting the responsible prediction engine and its first internal assertion into the existing non-overlapping POWER and DISK diagnostic windows: POWER 1 is the plan adapter, 2 generalized P raster, 3 B raster/history, and 4 legacy/base; DISK reports the first engine-local assertion for P or B. Focused RTL replay proves generalized P POWER 2 / DISK 8 and B POWER 3 / DISK 7 while later malformed metadata cannot relabel the first fault. The 194,005-byte parser-window stream remains clean with eight P and eight B refills, and the 185,393-byte restricted-slices stream remains clean with both pictures seen and all 1,350 P macroblocks. The clean Quartus 17.0.2 build completes in 14 minutes 12 seconds with zero setup and hold TNS, no Critical Warning, +0.173 ns global setup, +0.232 ns global hold, +1.801 ns decoder setup, 40,891 ALMs, 50,495 registers, 584,141 memory bits, 88 RAM blocks, 69 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `24ad77f4207bb9be870e2d294cc975cfffd9529950fc356f20dedafb912751c0`; no parsing, reconstruction, reference, DDR, publication, or presentation control depends on the new observability signals.

#### Next Steps:

Install the Commit-199 RBF and run only `test_pb_restricted_slices.m2v` on MiSTer for one complete 32-second diagnostic frame, recording USER, POWER, and DISK counts. Use POWER to select the prediction engine and DISK to identify its first assertion before proposing any decoder-behavior change.

#### Files Modified:

- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_prediction_error_sources.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 200 COMMIT Unreleased b78ffcc 2026-08-17T22:44:25-07:00

#### Coming From:

Unreleased af20d28

#### Purpose:

Prevent same-row P slice continuations from re-emitting motion metadata for macroblocks already covered by an earlier slice.

#### Outcome:

Commit-199 hardware reports USER 3, POWER 2, and DISK 2 on `test_pb_restricted_slices.m2v`, identifying generalized P raster motion-metadata sequencing rather than B reconstruction or DDR. Commit `b78ffcc` adds an explicit covered-column cursor across P slice boundaries, rejects overlap behind that cursor, emits only genuinely uncovered leading skips, and preserves ordinary first-slice and in-slice skip behavior. The restricted-slices replay now emits exactly 1,350 ordered motion events for each of its two P pictures instead of 1,534, while both pictures parse without P or B errors; the parser-window stream also emits exactly 1,350 events for both P pictures and retains eight P and eight B window refills. The clean Quartus 17.0.2 build completes in 13 minutes 57 seconds with zero setup and hold TNS, no Critical Warning, +0.041 ns global setup, +0.204 ns global hold, +1.838 ns decoder setup, 40,624 ALMs, 50,284 registers, 584,141 memory bits, 88 RAM blocks, 69 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `972fd24b9c7d01ccdedfc9643c5939eb44ba347beb9a1655b7aeabffae381c81`.

#### Next Steps:

Install the Commit-200 RBF and rerun only `test_pb_restricted_slices.m2v` on MiSTer for one complete 32-second diagnostic frame, recording the USER, POWER, and DISK indications and confirming that the visible raster remains coherent.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/streams/tb_h262_parser_windows.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 201 COMMIT Unreleased 9672f0a 2026-08-17T23:12:19-07:00

#### Coming From:

Unreleased b78ffcc

#### Purpose:

Integrate intra-coded macroblocks into the generalized progressive P-picture reconstruction path without regressing predicted, skipped, residual-coded, parser-window, or restricted-slice behavior.

#### Outcome:

Commit `b78ffcc` is hardware accepted: `test_pb_restricted_slices.m2v` produced a coherent raster with USER and POWER solid and DISK off, confirming that the same-row duplicate motion-event fault is resolved. Commits `40d7a70` through `9672f0a` add standards-derived intra and intra-quant macroblock parsing, DC predictor and differential handling, intra inverse quantisation metadata, and reference-bypassed clipped spatial reconstruction to the generalized P path. The final design serializes intra and non-intra work through one shared multiplier and IDCT, retires superseded P observers and legacy P reference engines, and bounds synthesized generalized-P residual storage to 16 blocks and 32 coefficient events while retaining the external interfaces. The deterministic 181,085-byte mixed-P regression reports exactly 1,350 motion events, one intra macroblock, six blocks, and 384 spatial samples with no parser, residual, or transform error; the parser-window and restricted-slice replays remain clean at exactly 1,350 P events, the shared non-intra transform remains exact, the prediction-error diagnostic test passes, all seven standing generators retain their hashes and reference results, and the active wrapper elaborates. The clean Quartus 17.0.2 build completes in 12 minutes 50 seconds with zero setup and hold TNS, no Critical Warning, +0.128 ns global setup, +0.254 ns global hold, +1.995 ns decoder setup, 35,439 ALMs, 43,615 registers, 576,499 memory bits, 86 RAM blocks, 68 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `444fb51cf35aae0e4191208e803bae3739b3e76e36b35fb0f9087be5af5dc517`; stream `test_p_intra_macroblocks.m2v` has SHA-256 `749bc8908710bd64ddae1da499311eba24396906ebc3b8fc2d56a29077f92dda`.

#### Next Steps:

Install the Commit-201 RBF and run `test_p_intra_macroblocks.m2v` through one complete 32-second diagnostic frame, recording whether USER, POWER, and DISK are solid, dark, or blinking and confirming that the displayed raster remains coherent. Clean acceptance is solid USER, solid POWER, and dark DISK; the authored intra macroblock is at row 8, column 20, with the remainder of the P picture reference-exact.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_p_intra_macroblocks.py
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv
- tools/streams/tb_h262_prediction_error_sources.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 202 COMMIT Unreleased 104965c 2026-08-18T00:50:44-07:00

#### Coming From:

Unreleased 9672f0a

#### Purpose:

Replace the generalized P path's picture-wide residual-plan limits with block-at-a-time transform delivery and RAM-backed sparse reconstruction storage.

#### Outcome:

Commit `9672f0a` is hardware accepted: the authored intra macroblock at row 8, column 20 is visibly reconstructed with a coherent raster, USER and POWER solid, and DISK off. Commits `9525d69` and `104965c` replace the P parser's flattened residual plans with synchronous M10K-backed stores for 2,048 block descriptors and 32,768 coefficient events, transform one block at a time through the existing shared serialized engine, and retain 2,048 sparse reconstructed blocks in M10K RAM; the correction commit packs the raster descriptor fields into one synchronous RAM and adds the required sample-lookup staging cycle after the first fit exposed asynchronous descriptor registers. The existing intra regression remains clean at 1,350 motion events, one intra macroblock, six blocks, and 384 samples, while the new 181,161-byte streaming regression remains clean at 1,350 motion events, 20 intra macroblocks, 120 blocks, and 7,680 samples with no parser, residual, raster, or transform error. Parser-window and restricted-slice replays remain clean, the ordinary 366,067-byte mixed-macroblock corpus now completes all seven P pictures with 158 refills and no P error while retaining the separately scoped B limit, and all seven standing generators retain their hashes and reference results. The clean Quartus 17.0.2 build completes in 9 minutes 18 seconds with zero setup and hold TNS, no Critical Warning, +0.221 ns global setup, +0.251 ns global hold, +2.128 ns decoder setup, 29,590 ALMs, 42,190 registers, 3,335,155 memory bits, 421 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `25c96d4d8caa2bdfc3d7935834823c956e12d3720c31bd59e56449ece1118332`; stream `test_p_residual_streaming.m2v` has SHA-256 `3120133ee6f59159ab02e1927c25d057f92d127b569db4f394e71eefa6e8a801`.

#### Next Steps:

Install the Commit-202 RBF and run `test_p_residual_streaming.m2v` on MiSTer through one complete 32-second diagnostic frame, recording whether USER, POWER, and DISK are solid, dark, or blinking and confirming a coherent vertical intra stripe at column 20 from rows 5 through 24. Clean acceptance is solid USER, solid POWER, and dark DISK; after acceptance, address the independently retained B residual-plan limit in the next commit.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- tools/streams/generate_test_p_residual_streaming.py
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv

#### Status:

- [x] Built
- [ ] Passed

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
## 204 COMMIT Unreleased ??? 2026-08-18T02:34:46-07:00

#### Coming From:

Unreleased e3036ac

#### Purpose:

Replace picture-wide P/B residual accumulation with row-bounded parse, transform, and reconstruction transactions that admit dense ordinary coefficient traffic without increasing FPGA RAM capacity.

#### Outcome:

Commit `e3036ac` is hardware accepted: `test_b_residual_streaming.m2v` briefly displays its B-only vertical stripe, then correctly presents the following plain P reference, with USER and POWER solid and DISK off. Software decode independently confirms display order I/B/P, identical I and P frame hashes, and a distinct middle B frame, so the transient stripe is expected publication order rather than a storage overwrite. Fresh exact replay of the 2,875,981-byte ordinary dense-residual corpus identifies the next implementation boundary: the first P picture reaches exactly 32,768 stored coefficient events with 1,526 residual blocks at macroblock column 29 of row 6, and the first B picture reaches exactly 32,768 events with 1,314 blocks at column 42 of row 5. The clean Commit-203 fit already uses 503 of 553 RAM blocks, so another picture-wide capacity increase is not viable. This cycle will hold input at completed macroblock rows, transform and reconstruct that row before admitting the next one, then clear and reuse bounded residual storage while retaining picture-wide motion ordering, legal same-row slice predictor resets, P/B reference ownership, and final publication order.

#### Next Steps:

Implement an explicit row-ready and row-retired handshake across the active P parser, residual pipeline, B core, P/B raster engines, and reference wrapper; reuse descriptor, coefficient, and spatial-sample addresses only after row persistence; add focused dense-row RTL coverage that exceeds 32,768 total picture coefficient events; preserve the Entry-203 streaming cases, parser-window and restricted-slice tests, prediction diagnostics, full compatibility corpus, and authoritative seven-stream generators; then complete a clean Quartus 17.0.2 build and deploy the qualified RBF and dense diagnostic stream to MiSTer for hardware validation.

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
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/tb_h262_parser_windows.sv
- tools/streams/tb_h262_row_streaming.sv

#### Status:

- [ ] Built
- [ ] Passed

---
