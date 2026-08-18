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
## 228 COMMIT Unreleased cd73cb7 2026-08-18T15:07:22-07:00

#### Coming From:

Unreleased 302bb3e

#### Purpose:

Raise generalized P/B long-GOP decode throughput from the observed four-frame-per-second hardware rate to at least the encoded 25-frame-per-second rate without changing reconstructed pixels or display order.

#### Outcome:

The uploaded 21.165-second hardware capture proves monotonic presentation through source frame 71 but requires approximately 18 seconds for a 72-frame, 25 fps stream whose encoded duration is 2.88 seconds, identifying decoder backpressure rather than camera aliasing or intentional presentation pacing. Commit `cd73cb7` adds a four-entry fully associative cache at the shared P/B reference-read boundary, permits only prediction reads to hit or fill, keeps destination verification traffic uncached, and invalidates the cache outside each raster transaction so rewritten reference banks cannot return stale words. The focused cache regression passes misses, repeated and interleaved hits, replacement, uncached bypass, invalidation, downstream backpressure, and delayed responses. The DDR-backed 128x96 live-raster soak passes all 72 pictures with 22 P pictures, 47 B pictures, 25 publications, final identity 25 corresponding to source frame 71, both scratch banks, completed presentation, and zero parser, prediction, writer, or presentation errors; it records 2,267,813 cache hits, 463,835 prediction misses, 158,976 uncached verification reads, and 622,811 physical DDR reads, reducing external reads by 78.5 percent or 4.64 times. The independent 720x480 long-GOP publication regression passes all 791,528 bytes with 22 P pictures, 47 B pictures, 25 publications, final identity 25, and zero overwrite or presentation errors. The session-authorized incremental Quartus 17.0.2 compile preserves the project database and completes in 9 minutes 17 seconds with 0 errors and 121 standing warnings; global setup and hold slack are +0.241 and +0.246 ns, focused decoder and video setup slack are +1.407 and +6.518 ns, and utilization is 29,666 ALMs, 43,189 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit228_cd73cb7.rbf` is 4,253,812 bytes with SHA-256 `3c6a612cd88449ee283dd50437c20ee07f175af028fef145b0ff48af47b9cc9e`; its MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload the MiSTer core and load `test_compat_long_gop.m2v` while recording from the first visible frame through settled source frame 71, then report the elapsed load time and terminal USER, POWER, and DISK state. Hardware acceptance requires the existing passing LED pattern and at least 25 fps, corresponding to no more than 2.88 seconds for all 72 frames; if the cache improves throughput but remains below that threshold, retain the measured gain and target the serialized raster-engine handshake or uncached verification boundary in the next commit.

#### Files Modified:

- files.qip
- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 229 COMMIT Unreleased ??? 2026-08-18T15:58:14-07:00

#### Coming From:

Unreleased cd73cb7

#### Purpose:

Remove the registered cache-hit handshake from generalized P/B prediction so resident reference words can advance the raster engines directly without changing the miss path, pixels, or display order.

#### Outcome:

Entry 228 hardware remains functionally clean: the long-GOP stream reaches source frame 71, USER and POWER are solid, and DISK code 11 confirms the deepest successful final-GOP boundary, future-reference presentation. Its approximately 9.9-second load time is only about 7.3 fps and remains well below the encoded 25 fps rate. Because Entry 228 simulation removed 78.5 percent of external reads while hardware still misses the throughput target, DDR bandwidth is no longer the first boundary; static cycle tracing shows that each cache hit still passes through request capture, acceptance, registered response, and engine response consumption before a pel can advance. Expose the cache's associative lookup result to the selected P or B raster engine, add an explicit consume event for accounting, and let a hit advance the tap accumulator directly while retaining the existing registered transaction for misses and all uncached accesses.

#### Next Steps:

Extend the focused cache regression to prove direct-hit lookup and consumption, miss fallback, replacement, invalidation, delayed DDR response, and uncached isolation. Add cycle accounting to the integrated 72-picture live-raster soak, require exact reconstructed memory, persistence, publication, ownership, scratch selection, and final display identity to remain unchanged, and require a material cycle reduction before the session-authorized incremental Quartus build. Deploy the resulting RBF for another timed long-GOP run; if direct hits still do not reach 25 fps, preserve the measured gain and use the cycle breakdown to choose between residual-read bubbles and post-store verification traffic.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_word_cache.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/tb_h262_prediction_word_cache.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [ ] Built
- [ ] Passed

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
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
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
## 204 COMMIT Unreleased 7256a7f 2026-08-18T02:34:46-07:00

#### Coming From:

Unreleased e3036ac

#### Purpose:

Replace picture-wide P/B residual accumulation with row-bounded parse, transform, and reconstruction transactions that admit dense ordinary coefficient traffic without increasing FPGA RAM capacity.

#### Outcome:

Commit `e3036ac` is hardware accepted: `test_b_residual_streaming.m2v` briefly displays its B-only vertical stripe, then correctly presents the following plain P reference, with USER and POWER solid and DISK off; software decode confirms display order I/B/P, identical I and P hashes, and a distinct B frame. Commits `00d4229` and `7256a7f` add explicit row-ready and row-retired handshakes across the active P/B parsers, transforms, raster engines, reference wrapper, and publication shell, holding input until each row is reconstructed and persisted before reusing descriptor, coefficient, and shared spatial-sample addresses. The 2,875,981-byte dense corpus now completes its first P picture with 8,100 blocks and 175,586 coefficients and its first B picture with 8,073 blocks and 182,707 coefficients; each path emits 1,350 ordered motion records across 30 transactions, while the largest P row uses 270 blocks and 6,017 coefficients and the largest B row uses 270 blocks and 7,441 coefficients. The existing 120-block P and B full-raster regressions, parser-window and restricted-slice replays, prediction-source diagnostics, active hierarchy elaboration, and the first ordinary mixed-corpus B picture remain clean. The clean Quartus 17.0.2 build completes in 9 minutes 21 seconds with zero setup and hold TNS, no Critical Warning, +0.126 ns global setup, +0.250 ns global hold, +1.397 ns decoder setup, 29,087 ALMs, 42,000 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `15e53c93517a1227671fd2f8d24673858f78b80ae902b1a9e68637afaa39730f`.

#### Next Steps:

Install the Commit-204 RBF and run `test_compat_dense_residual.m2v`, `test_p_residual_streaming.m2v`, and `test_b_residual_streaming.m2v` on MiSTer through complete settled diagnostic reports. Each stream must finish with USER and POWER solid and DISK dark; the dense stream must remain coherent through its P/B sequence, the P stripe must remain stable, and the B stripe must appear only during the B display interval before the following plain P reference.

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
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_parser_windows.sv
- tools/streams/tb_h262_row_streaming.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 205 COMMIT Unreleased c9636a7 2026-08-18T03:26:00-07:00

#### Coming From:

Unreleased 7256a7f

#### Purpose:

Guarantee that any B parser or reconstruction failure aborts the in-flight B transaction and releases compressed-stream backpressure.

#### Outcome:

Commit `7256a7f` is not hardware accepted: `test_compat_dense_residual.m2v` displays its coherent dense I/P raster but leaves the MiSTer file-transfer overlay permanently active with all diagnostic LEDs dark. Commit `c9636a7` makes sticky B parser/replay failure abort only the live B transaction and suppress its persistence wait, preserving the error for diagnostics while allowing the HPS byte path to drain. The focused transport regression holds B failure asserted and accepts all 4,102 bytes with zero post-abort stalls, while the separate full-corpus reproducer identifies the first deterministic dense failure at byte 818,622, slice row 9, and proves the parser itself releases `parse_hold`; the existing first dense B full-raster replay remains clear across 1,350 macroblocks, 8,073 residual blocks, 516,672 residual samples, and 518,400 stored samples.

#### Next Steps:

Correct the second and later B-picture parser/lifecycle behavior, require the complete dense `IPBBPBBPBBPB` coded sequence to finish without parser, replay, reconstruction, publication, presentation, or transport errors, then run a clean Quartus build for the combined recovery commits.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_dense_transport_recovery.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 206 COMMIT Unreleased 2dd4c67 2026-08-18T04:27:00-07:00

#### Coming From:

Unreleased c9636a7

#### Purpose:

Correct repeated-B parsing and transaction lifecycle so every picture in the dense `IPBBPBBPBBPB` corpus completes without error or transport stall.

#### Outcome:

Commit `c9636a7` guarantees fail-open transport after the former second-B fault. Commits `10d88d0` and `2dd4c67` complete the repeated-B correction: a rightmost macroblock now enters zero-stuffing state, a stuffing-only refill tail may terminate with fewer than three buffered bytes, raw compatibility streams receive an explicit sequence end, and every accepted picture header produces its own presentation event even when adjacent coding types are both B. Two independent non-reference scratch frames preserve consecutive B display order before the retained future reference, while decoder or ownership failure aborts presentation backpressure. The full 2,875,985-byte dense parser/transform replay completes all seven B pictures, 210 row transactions, 9,450 motion records, 52,846 residual blocks, 1,539,306 coefficient events, and 3,382,144 spatial samples without error. Focused regressions also prove 4,102 accepted transport bytes with zero post-abort stalls, scratch0/scratch1/future presentation order plus fail-open recovery, all six scratch-bank/plane tag mappings, and the established 518,400-sample B residual raster.

The final clean Quartus 17.0.2 build completes in 9 minutes 14 seconds with zero setup, hold, or recovery TNS, no Critical Warning, +0.496 ns global setup, +0.245 ns global hold, +3.411 ns global recovery, +1.666 ns focused decoder setup, and +14.384 ns focused decoder recovery. It uses 28,935 ALMs, 41,815 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. Generated RBF `MediaPlayer.rbf` has SHA-256 `c681b82a672dc7c21eff38bfd69244510481cef7cfc6bc0cb9f3dc2647cef56e`; regenerated stream `test_compat_dense_residual.m2v` has SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e`. Both files were uploaded to the standard MiSTer at `10.10.0.30` and read back with matching hashes.

#### Next Steps:

Run `test_compat_dense_residual.m2v` through its complete sequence on MiSTer. Confirm the raster remains coherent through every P/B interval, the file-transfer overlay retires instead of freezing, and the terminal LEDs are solid USER, solid POWER, and dark DISK. Report any transient image order issue separately from the settled LED state.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- MediaPlayer.sdc
- files.qip
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- tools/streams/generate_test_progressive_compatibility.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_transport_recovery.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 207 COMMIT Unreleased 2dd4c67 2026-08-18T04:37:17-07:00

#### Coming From:

Unreleased 2dd4c67

#### Purpose:

Record the MiSTer hardware result for the repeated-B transport and presentation correction.

#### Outcome:

Commit `2dd4c67` is not hardware accepted. The 2,875,985-byte `test_compat_dense_residual.m2v` now loads completely instead of freezing the MiSTer transfer path, but does so slowly and settles on a repeated coherent diagonal test raster. The uploaded photograph records that final raster. The settled diagnostic is USER 2, POWER 9, and DISK 0: the first error is `phase1_probe_error`, its parent source is the generalized P controller, and sub-code 9 is `raster_hold_error`, meaning at least one generalized P row-complete transaction failed to observe persistence before its 24-bit hold timeout. No DISK sub-code is defined for this error class. This proves the Entry-205 fail-open transport and Entry-206 terminal stream drain worked while isolating the next failure to P row persistence or its hold-time bound rather than repeated-B parsing.

#### Next Steps:

Before changing decoder behavior, measure the exact dense P row that arms and expires `raster_hold_active`, distinguish a genuinely missing row-persistence acknowledgement from a valid transaction whose hardware latency exceeds the fixed timeout, and extend a focused top-level regression or first-fault diagnostic to reproduce that boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 208 COMMIT Unreleased 450f78a 2026-08-18T04:42:35-07:00

#### Coming From:

Unreleased 2dd4c67

#### Purpose:

Accept a generalized P picture whose persistence proof precedes its parser completion pulse by one cycle.

#### Outcome:

Commit `450f78a` makes P raster-hold admission consume an already-present persistence proof atomically. The focused regression reproduces the hardware ordering: before the correction all 30 rows retired but completion left `raster_hold_active` set and `raster_hold_ready` clear; afterward the same transaction completes immediately with the hold inactive, ready asserted, no error, and P acceptance retained. The dense P row regression completes 1,350 motion records, 8,100 residual blocks, 175,586 coefficients, and 518,400 samples; the seven-B corpus, fail-open transport, two-scratch presentation, and six storage-tag regressions also pass unchanged. The clean Quartus 17.0.2 build completes in 9 minutes 13 seconds with no Critical Warning, zero setup, hold, or recovery TNS, +0.570 ns global setup, +0.251 ns global hold, +2.931 ns global recovery, +1.776 ns focused decoder setup, and +14.264 ns focused decoder recovery. It uses 29,045 ALMs, 41,901 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 `6172e2ed1f5883b1517c838041961f6528ebe983f1935f822883b87c13d31ec1` and dense-stream SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e` were uploaded to `10.10.0.30` and read back with matching hashes.

#### Next Steps:

Run `test_compat_dense_residual.m2v` through its complete sequence on MiSTer and confirm that transfer and P-picture transitions no longer pause for the former timeout, the final raster remains coherent, and the settled diagnostic is solid USER, solid POWER, and dark DISK.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- tools/streams/tb_h262_p_raster_hold.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 209 COMMIT Unreleased 450f78a 2026-08-18T05:12:25-07:00

#### Coming From:

Unreleased 450f78a

#### Purpose:

Record the MiSTer hardware result for the generalized P completion and persistence handshake correction.

#### Outcome:

Commit `450f78a` is not hardware accepted, but it removes the former POWER-9 raster-hold failure. The dense compatibility transfer remains slow yet now advances consistently, and the final coherent diagonal raster is unchanged. The settled diagnostic is USER 2, POWER 4, and DISK 0: the first error is `phase1_probe_error`, its parent source is `publication_error` in the compiled I/P/B publication shell, and no DISK sub-code is currently defined for that error class. This proves the final-row persistence proof is now accepted and moves the first failure to one of the shell's reference-bank, P-publication, or following-header ordering checks; the remaining load duration is consistent with live serialized raster work rather than the eliminated fixed hold timeout.

#### Next Steps:

Add first-fault detail for each publication-error assertion site and a complete dense I/P/B publication-order regression that drives row and picture persistence in hardware order, then use that evidence to correct only the failing reference-bank or header-order transition before another Quartus build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 210 COMMIT Unreleased 3fcf22f 2026-08-18T05:13:48-07:00

#### Coming From:

Unreleased 450f78a

#### Purpose:

Identify the hidden repeated-P parser failure that prevents the second dense P reference from reaching publication.

#### Outcome:

Commit `3fcf22f` proves the POWER-4 publication failure was downstream of stale B ownership: `b_candidate` remained asserted after B persistence, suppressed the following P parser's refill hold, and let thousands of compressed bytes overrun its active 512-byte window until coefficient state failed. The B parser now releases candidate ownership when the following non-B header is known, the P parser and publication shell retain sticky first-fault detail, and the complete dense regression passes 120 P rows, four P pictures, 210 B rows, seven B pictures, and five reference publications with no parser, transport, or publication error. Fail-open transport, parser-window, and restricted-slice regressions pass unchanged. The clean Quartus 17.0.2 build completes in 9 minutes 25 seconds with zero setup and hold TNS, no Critical Warning, +0.062 ns global setup, +0.249 ns global hold, +2.613 ns focused decoder setup, +14.318 ns focused decoder recovery, 29,163 ALMs, 41,923 registers, 4,025,331 memory bits, 503 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 `6692722e11d44c10bbbd716e60d4b1761072c4b72452742d1df403c7342c1120` was uploaded to `10.10.0.30` and read back with the same hash. Hardware accepts the deployed build: `test_compat_dense_residual.m2v` loads slowly but completes, visibly advances through more pattern changes, settles on the full dense diagonal raster captured in the uploaded photograph, and reports USER and POWER solid with DISK off.

#### Next Steps:

Proceed to the next v0.6.0 roadmap boundary by recording its proposal before making further decoder changes.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [x] Passed

---
## 211 COMMIT Unreleased 19914b2 2026-08-18T07:25:22-07:00

#### Coming From:

Unreleased 3fcf22f

#### Purpose:

Integrate intra-coded macroblocks into the generalized progressive B-picture path and qualify the ordinary mixed-macroblock compatibility corpus without regressing existing predictive modes.

#### Outcome:

Commit `19914b2` recognizes the H.262 Table B.4 unquantised and quantised intra macroblock types in non-scalable B pictures, applies picture-signalled DC precision and intra VLC format, carries intra ownership through the shared transform and sparse-sample protocol, and reconstructs all six 4:2:0 blocks without reference prediction. The deterministic 182,458-byte B-intra stream places unquantised and quantised intra macroblocks at column 20 in consecutive rows and passes software reference verification; RTL produces exactly 1,350 B macroblocks, two intra markers, twelve intra blocks, twelve DC events, 768 spatial samples and writes, and exactly 768 changed raster samples without parser or raster error. The complete 366,071-byte mixed corpus passes 210 P rows, seven P pictures, 450 B rows, fifteen B pictures, and eight reference publications without transport, decoder, publication, or presentation error; parser-window, standing B-residual, prediction-source, active-hierarchy, and authoritative seven-generator regressions also pass. Standards record H262-026 is published by metadata commit `d182f15`. The clean Quartus 17.0.2 build completes in 9 minutes 27 seconds with zero setup and hold TNS, no Critical Warning, +0.294 ns global setup, +0.248 ns global hold, +2.057 ns focused decoder setup, 29,442 ALMs, 42,188 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `350773e5804bccd566dd4cb7c8a953427e2bafae2feebf50bbeb890fc87b1176`; B-intra stream SHA-256 is `60c914c8d9232515b21cbbd55416e1ae17c7134ee45af5f90829f06026b78166`; regenerated mixed-corpus SHA-256 is `ad1d9e81f0f7544ac16a1aaddb85ef9e1065333c1fdd305aa3cf275aa1ccc289`.

#### Next Steps:

Install the Commit-211 RBF and run `test_b_intra_macroblocks.m2v` through one complete settled diagnostic report, confirming coherent display order I/B/P, two vertically adjacent authored intra macroblocks at column 20 in rows 8 and 9, solid USER and POWER, and dark DISK. Then run `test_compat_mixed_macroblocks.m2v` through all 24 pictures and confirm coherent I/P/B presentation, complete transfer retirement, and the same settled LED result.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- tools/streams/generate_test_b_intra_macroblocks.py
- tools/streams/tb_h262_b_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 212 COMMIT Unreleased 19914b2 2026-08-18T08:12:31-07:00

#### Coming From:

Unreleased 19914b2

#### Purpose:

Record MiSTer hardware acceptance of the B-picture intra-macroblock and ordinary mixed-macroblock compatibility boundary.

#### Outcome:

Commit `19914b2` passes both requested MiSTer LED tests with USER and POWER solid and DISK off. The uploaded B-intra capture shows the coherent repeated diagonal reference field and the authored vertically adjacent intra region at column 20 in rows 8 and 9 after complete I/B/P presentation. The uploaded mixed-corpus capture matches decoded source frame 8 at timestamp `00:00:00.320`, including the vertical color bars, moving diagonal, gray bar, sparse dots, and checkerboard feature. Frame-by-frame software review confirms the reported feature flicker during file loading is the intended motion of the 24-frame `testsrc2` source combined with rapid load-time picture publication, rather than missing decode regions, publication-order corruption, or a settled hardware error.

#### Next Steps:

Record the proposal for the long-GOP ownership, reference-rotation, publication, and soak-validation boundary before making further decoder changes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 213 COMMIT Unreleased 065a775 2026-08-18T08:13:58-07:00

#### Coming From:

Unreleased 19914b2

#### Purpose:

Qualify long-GOP decoder ownership, reference rotation, publication order, and sustained progressive 4:2:0 operation across the complete 72-picture compatibility stream.

#### Outcome:

Commit `065a775` extends the complete I/P/B publication regression with a long-GOP mode and corrects the single boundary it exposed: when a P parser refill ended exactly after a complete row and its alignment zeroes, the resumed capture contained only the two retained start-code-prefix bytes and was falsely rejected as a short slice chunk. The P path now accepts that empty `R_STUFF` tail for boundary classification, matching the standing B behavior without changing decoded syntax. The complete 791,528-byte long-GOP regression passes 660 P rows, 22 P pictures, 1,410 B rows, 47 B pictures, and 23 reference publications and promotions across three GOPs without transport, parser, reconstruction, ownership, persistence, or publication error. The 366,071-byte mixed and 2,875,985-byte dense publication regressions pass unchanged, and all seven authoritative stream hashes match their published values. The clean Quartus 17.0.2 build completes in 9 minutes 20 seconds with zero setup and hold TNS, no Critical Warning, +0.428 ns global setup, +0.247 ns global hold, +1.600 ns focused decoder setup, +15.088 ns focused decoder recovery, 29,576 ALMs, 42,157 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `3e60392fba96cab4d5ee00215bc55401441e71e4784a92ee0ae792833832bbe4`; long-GOP stream SHA-256 is `39dd3e889d1baa42e4d65fc2d6ca7a04c58c2ac38de0a5b1dba00e6585836d96`.

#### Next Steps:

Install `MediaPlayer_commit213_065a775.rbf` and load `test_compat_long_gop.m2v` through all 72 pictures and one complete settled diagnostic report, confirming coherent repeated-GOP I/P/B presentation, complete transfer retirement, USER and POWER solid, and DISK off.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 214 COMMIT Unreleased 065a775 2026-08-18T09:06:35-07:00

#### Coming From:

Unreleased 065a775

#### Purpose:

Record the MiSTer visual result that separates clean LED diagnostics from failed repeated-GOP presentation on the mixed compatibility stream.

#### Outcome:

Commit `065a775` passes the reported USER, POWER, and DISK checks on the B-intra and mixed-macroblock streams, and the B-intra stream now loads quickly before settling on its coherent authored raster. The mixed stream still glitches during loading, and the uploaded settled capture reads timestamp `00:00:00.440` and frame `11`; it matches decoded source frame 11 exactly, which is the last displayed frame of the first 12-frame GOP rather than final frame 23 of the 24-frame stream. The clean LEDs therefore prove that the existing syntax, reconstruction, and counted publication assertions did not fire, but they do not qualify repeated-GOP presentation or the pending 72-picture long-GOP hardware boundary.

#### Next Steps:

Add a repeated-GOP presentation regression that distinguishes every I/P/B frame and requires the final displayed identity to cross the second I-picture boundary, then correct the first reference, bank, or scheduler transition that leaves frame 11 settled before rebuilding for MiSTer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 215 COMMIT Unreleased 69d1b90 2026-08-18T09:10:40-07:00

#### Coming From:

Unreleased 065a775

#### Purpose:

Require complete repeated-GOP I-picture publication and final-frame presentation across the mixed and long compatibility streams.

#### Outcome:

Commit `69d1b90` removes the first-GOP-only publication proof exposed by the frame-11 hardware result. The shell's P header/publication counters saturated at three and its B header/persistence counters saturated at seven, making B picture eight at the second-GOP boundary indistinguishable from the already-settled first-GOP state; all four counters now retain exact eight-bit transaction totals. The publication regression now uses the real front-end I support window, counts every repeated I publication, models scheduler vblank holds and scratch-to-future presentation, rejects displayed-bank overwrites, and requires the final reference identity. The 366,071-byte mixed stream passes seven P, fifteen B, nine reference publications and final identity nine; the 791,528-byte long stream passes twenty-two P, forty-seven B, twenty-five publications and final identity twenty-five; the 2,875,985-byte dense stream passes four P, seven B, five publications and final identity five, all without parser, ownership, overwrite, or presentation error. The clean Quartus 17.0.2 build completes in 9 minutes 36 seconds with zero errors, no Critical Warning, zero setup and hold TNS, +0.680 ns global setup, +0.244 ns global hold, +2.047 ns focused decoder setup, +13.351 ns focused decoder recovery, 29,506 ALMs, 42,076 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `9506e967d78d2a18b9fc4bdb5a6f7e27fa8e4b0b4a6fcf8a3f235c14e042d0ee`.

#### Next Steps:

Install `MediaPlayer_commit215_69d1b90.rbf` and load `test_compat_mixed_macroblocks.m2v`, waiting for the presentation to settle and confirming timestamp `00:00:00.920`, frame `23`, coherent features, USER and POWER solid, and DISK off. Then load `test_compat_long_gop.m2v` through all 72 pictures and confirm the same settled LED result without feature or macroblock flicker.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/tb_h262_dense_publication_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 216 COMMIT Unreleased 69d1b90 2026-08-18T10:37:17-07:00

#### Coming From:

Unreleased 69d1b90

#### Purpose:

Record the MiSTer hardware result for exact repeated-GOP transaction counting and long-GOP presentation.

#### Outcome:

Commit `69d1b90` is not hardware accepted. The mixed-macroblock stream is visibly improved and reports the passing LED pattern, but remains jittery during loading; its uploaded capture reaches timestamp `00:00:00.400`, frame `10`, proving that presentation now advances into the second GOP without proving the required settled frame `23`. Loading the long-GOP stream instead leaves the MiSTer unresponsive while the file-transfer overlay is still visible. Its uploaded capture remains at timestamp `00:00:00.000`, frame `0`, and all LEDs are dark. Because the settled diagnostic snapshot is taken only after `ioctl_download` retires, the dark LEDs in this state are evidence that the transfer never completed, not a passing or ordinary sticky decoder-error report. The first unresolved boundary is therefore live compressed-stream backpressure or presentation ownership under sustained hardware timing.

#### Next Steps:

Reproduce the long stream with hardware-scale swap cadence and HPS-to-decoder FIFO backpressure, require bounded forward progress at every accepted-byte boundary, and expose the first asserted decoder, B-presentation, or P-destination ownership hold. Correct only the hold transition proven to keep `ioctl_wait` asserted, then rerun mixed and long full-stream presentation before another MiSTer build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 217 COMMIT Unreleased a559d43 2026-08-18T10:42:27-07:00

#### Coming From:

Unreleased 69d1b90

#### Purpose:

Guarantee fail-open HPS transfer retirement when a sticky downstream decode, raster, DDR, or presentation failure makes normal persistence impossible.

#### Outcome:

Commit `a559d43` adds an explicit MPEG-domain transport gate between the dual-clock FIFO and the decoder. Clean operation preserves the existing ready/valid contract; after any sticky syntax, decoder, raster, DDR, or presentation error, the gate masks decoder validity while draining the FIFO so `ioctl_wait` can release and the post-load LED snapshot can report the first failure. The focused regression proves normal backpressure and accepted-byte delivery, then drains sixteen queued bytes with decoder readiness low and zero invalid decoder deliveries. The B scheduler regression still passes scratch-zero, scratch-one, future-reference order and fail-open retirement. At a hardware-scale one-million-cycle swap cadence, the complete 791,528-byte long regression passes twenty-two P, forty-seven B, twenty-five reference publications, final display identity twenty-five, and no overwrite or presentation error, ruling out the widened counters and real vblank cadence as the hardware lockup source. The clean Quartus 17.0.2 build completes in 9 minutes 32 seconds with zero errors, no Critical Warning, zero setup and hold TNS, +0.230 ns global setup, +0.246 ns global hold, +1.391 ns focused decoder setup, +15.274 ns focused decoder recovery, 29,398 ALMs, 42,225 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. RBF SHA-256 is `874b37b9be25c28ed85e2767d9381ebf9650a9db9689098d5fb6fb67822a350f`.

#### Next Steps:

Install `MediaPlayer_commit217_a559d43.rbf` and load `test_compat_long_gop.m2v`. Confirm first that the file overlay always closes and the MiSTer remains responsive. If the stream is not cleanly accepted, report the repeating USER, POWER, and DISK blink counts from the settled snapshot; those codes will identify the live raster or DDR failure that the former deadlock concealed. Then load `test_compat_mixed_macroblocks.m2v` and confirm that its passing LED pattern and second-GOP presentation remain unchanged.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_05.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_stream_transport_gate.sv
- tools/streams/tb_h262_stream_transport_gate.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 218 COMMIT Unreleased a559d43 2026-08-18T11:09:59-07:00

#### Coming From:

Unreleased a559d43

#### Purpose:

Record the MiSTer long-GOP result after adding fatal-error transport retirement.

#### Outcome:

Commit `a559d43` removes the host-transfer deadlock: the long-GOP file overlay closes, the menu remains responsive, and the uploaded post-load capture reaches timestamp `00:00:02.000`, frame `50`, before the fatal boundary. All three LEDs remain dark because fail-open correctly masks the decoder while draining the remaining compressed bytes, including the final sequence-end code, but the settled diagnostic snapshot still arms only from `mpeg2_new_sequence_end_seen`. The fatal error is therefore preserved internally while `mpeg2_new_diag_snapshot_valid` never asserts. This is an observability-trigger defect after successful fail-open retirement, not a recurrence of the MiSTer crash.

#### Next Steps:

Arm the existing one-second settled diagnostic delay from either a decoded sequence end or the sticky transport-fatal condition, prove that clean sequence-end capture is unchanged and fatal drain produces a stable error snapshot, then rebuild and redeploy so the frame-50 raster or DDR failure is identified by USER, POWER, and DISK.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 219 COMMIT Unreleased daf7af2 2026-08-18T11:10:43-07:00

#### Coming From:

Unreleased a559d43

#### Purpose:

Preserve the settled LED diagnostic snapshot when fail-open transport intentionally discards the stream's final sequence-end code.

#### Outcome:

Commit `daf7af2` extends only the settled-snapshot arm condition so either the decoded sticky sequence-end flag or the sticky transport-fatal flag starts the existing four-slot, one-second stabilization delay. The capture registers, first-fault priority, blink epoch, clean-stream sequence-end behavior, and transport drain are unchanged. The focused fail-open transport and B-picture scheduler regressions pass. A clean Quartus 17.0.2 build completes with 0 errors, 121 standing warnings, no critical warnings, global setup slack +0.419 ns, hold slack +0.247 ns, recovery slack +3.470 ns, and focused decoder setup/recovery slack +1.571/+15.398 ns. The build uses 29,491 ALMs, 42,139 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit219_daf7af2.rbf` is 4,235,564 bytes with SHA-256 `241237b30b480ef1b8184f7cbe0bdf25d93e9f38f97218b1fc899e4260175a5e`; its MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload the long-GOP stream and wait at least one second after the frame-50 stop. Record the complete 32-second LED diagnostic epoch, or count the USER blinks during its first 6 seconds, POWER blinks during the next 10 seconds, and DISK blinks during the final 16 seconds, to expose the concealed fatal error code and detail.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [x] Built
- [ ] Passed

---
## 220 COMMIT Unreleased daf7af2 2026-08-18T11:34:27-07:00

#### Coming From:

Unreleased daf7af2

#### Purpose:

Record the MiSTer long-GOP result after restoring fatal-drain diagnostic capture.

#### Outcome:

Commit `daf7af2` produces the settled passing diagnostic pattern: USER is solid during its window, POWER is solid during its window, and DISK remains off, proving zero captured error and prerequisite sub-codes with normal I/P/B acceptance and presentation completion. The uploaded 17.235-second video also proves that the loading overlay retires normally after approximately fourteen seconds and the core remains responsive. The displayed source content nevertheless settles at timestamp `00:00:02.000`, frame `50`, while the deterministic 72-picture stream must finish at frame `71`, timestamp `00:00:02.840`. Frame 50 is the third-GOP I-picture, so the real hardware stops visibly advancing through the final GOP's P/B pictures without asserting any current parser, raster, DDR, publication, ownership, or presentation diagnostic. The full-stream publication regression cannot exclude this boundary because it synthesizes row and picture persistence from parser sideband terminators instead of instantiating the live raster engines and DDR transaction path.

#### Next Steps:

Add a full-stream live-raster soak boundary or equivalent settled counters that distinguish P/B raster starts, row persistence, picture persistence, reference publication, and actual display swaps through the final GOP. Require the long stream to reach all 72 pictures and final temporal reference 71 using real persistence acknowledgements, then correct only the first live stage that stops advancing and rebuild for MiSTer validation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 221 COMMIT Unreleased 7f92945 2026-08-18T11:36:01-07:00

#### Coming From:

Unreleased daf7af2

#### Purpose:

Require real P/B raster persistence and final temporal-reference presentation across the complete long-GOP stream.

#### Outcome:

Commit `7f92945` adds a deterministic 128x96, 72-picture live-raster soak that drives the compiled front end, P/B reference pipeline, active tagged DDR writer and arbiter, modeled DDR memory, real persistence acknowledgements, publication shell, and presentation scheduler. The first failing run proved that B scratch-bank-one pixels were written at the correct address but verified from scratch bank zero because `block_addr` depended implicitly on mutable outer state; passing the latched bank explicitly fixed the readback failure. The completed run then exposed twenty-one duplicate P publications because returning from each B transaction re-exported the preceding P engine's sticky persistence level; edge-qualifying each selected engine's persistence export fixed the duplicate ownership transition. The final soak passes all 72 pictures with 22 P pictures and 132 P rows, 47 B pictures and 282 B rows, 25 reference publications, both B scratch banks written, final display identity 25 corresponding to source frame 71, final in-GOP P temporal reference 23, and zero parser, prediction, writer, or presentation errors. The 720x480 long-GOP publication regression independently passes 22 P, 47 B, 25 publications, final identity 25, and zero overwrites; the B residual, B presentation, and fatal-drain transport regressions also pass. The clean Quartus 17.0.2 build completes in 9 minutes 24 seconds with 0 errors, 121 standing warnings, no critical warnings, global setup/hold slack +0.297/+0.247 ns, focused decoder/video setup slack +2.016/+7.937 ns, 29,435 ALMs, 42,082 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit221_7f92945.rbf` is 4,242,164 bytes with SHA-256 `5a77bf4ee8ae9c286d9d274188731dc8932ae3383336c26495e2581c6564cc65`; its MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload `test_compat_long_gop.m2v` with the deployed RBF and confirm that loading retires without a crash, the LEDs retain the passing USER-solid, POWER-solid, DISK-off pattern, and the settled image advances beyond frame 50 to source frame 71 at timestamp `00:00:02.840`. Then reload `test_compat_mixed_macroblocks.m2v` and report whether its loading jitter and transient feature flicker are reduced without changing the passing LED pattern.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_live_raster_soak.py
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 222 COMMIT Unreleased 7f92945 2026-08-18T12:58:09-07:00

#### Coming From:

Unreleased 7f92945

#### Purpose:

Record the MiSTer long-GOP presentation result after correcting live B scratch verification and duplicate P persistence publication.

#### Outcome:

Commit `7f92945` is not hardware accepted: `test_compat_long_gop.m2v` retains the passing USER-solid diagnostic pattern but still settles at timestamp `00:00:02.000`, frame 50, instead of source frame 71. The displayed frames are materially clearer and every rendered timestamp is now readable, proving that the corrected B scratch-bank verification improves live raster integrity. Visible progression nevertheless skips approximately two or three source frames at a time in an apparently repeatable pattern before stopping at the same third-GOP I-picture boundary. Because all settled error and prerequisite diagnostics remain passing while the raster image quality changed, the unresolved boundary is the actual temporal identity selected by the hardware framebuffer display path, which the Entry 221 soak represented with abstract publication counters rather than DDR-backed source-frame identity.

#### Next Steps:

Trace the compiled scheduler, framebuffer-bank selector, scratch selector, and DDR display addresses together, then extend the live soak to stamp each reconstructed reference and B scratch picture with its source temporal identity and read that identity through the actual framebuffer selection path. Require exact display order rather than only final publication identity, reproduce the two-or-three-frame stepping and frame-50 stop, and correct only the first real bank or swap selection that diverges before another build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 223 COMMIT Unreleased bbe625e 2026-08-18T13:14:21-07:00

#### Coming From:

Unreleased 7f92945

#### Purpose:

Identify the first missing post-I50 live transaction without changing decoder or presentation behavior.

#### Outcome:

The uploaded 14.501-second, 30 fps hardware capture disproves coded-order presentation: visible timestamps advance monotonically through B and reference pictures, reach the third-GOP I-picture at frame 50, and never advance again, while one-refresh B pictures explain the apparent camera-recorded skips. Commit `bbe625e` adds a passive probe that arms on the third I header and monotonically records eleven ordered boundaries through third-I publication, following-P header, P raster metadata, row and picture persistence, P reference publication, following-B header and persistence, B scratch selection, and future-reference presentation; only an otherwise passing DISK diagnostic consumes the stage, so USER, POWER, decode, DDR, ownership, and presentation control are unchanged. The focused stage/reset, B scheduler, and fail-open transport regressions pass. The 128x96 live-raster soak passes all 72 pictures with 22 P pictures, 47 B pictures, 25 publications, 25 display identities, final source-frame identity 71, and zero parser, prediction, writer, or presentation errors; the independent 720x480 long-GOP publication run matches 22 P, 47 B, 25 publications, 25 display identities, no overwrites, and completed presentation. The clean Quartus 17.0.2 build completes in 9 minutes 27 seconds with 0 errors, 121 standing warnings, global setup/hold slack +0.105/+0.175 ns, focused decoder/video setup slack +1.601/+7.708 ns, 29,418 ALMs, 42,182 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit223_bbe625e.rbf` is 4,223,132 bytes with SHA-256 `0c9c1cf5cb7dc03bf66081e0ce69af2b34b29e64272edefab99780b350252236`; its MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload the deployed core, load `test_compat_long_gop.m2v` once, wait for its settled diagnostic window, and report the DISK blink count while also confirming the USER and POWER states and the last visible frame. A count from one through eleven names the deepest post-I50 boundary reached and therefore isolates the next hardware correction without another observational expansion.

#### Files Modified:

- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_final_gop_progress_probe.sv
- tools/streams/tb_h262_final_gop_progress_probe.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 224 COMMIT Unreleased bbe625e 2026-08-18T13:44:27-07:00

#### Coming From:

Unreleased bbe625e

#### Purpose:

Record the hardware boundary identified by the passive final-GOP progress diagnostic.

#### Outcome:

The deployed `bbe625e` RBF again settles on visible frame 50 with USER and POWER solid, while DISK repeats exactly two blinks. Stage two proves that the third-GOP I50 header was accepted and I50 was published, but no following P header reached the top-level accepted-header observer before transport retirement. The source stream places B48 and B49 after coded I50 and P53 after those B pictures. Static tracing identifies a matching hardware-only vblank race: `frame_waiting` can present newly published I50 immediately when its one-cycle pulse coincides with `swap_window_pulse`; the later B48 header then finds its future reference already displayed, raises `b_presentation_error`, and causes the fatal transport gate to drain every remaining byte without exposing P53 to the decoder. The existing acceptance OR can remain true through its I-picture term and the current error encoder omits presentation errors, explaining the otherwise misleading solid USER and POWER report. This exact path accounts for the uploaded frame 47 to frame 50 transition, terminal frame 50, stage two, and clean menu recovery.

#### Next Steps:

Await approval for a focused scheduler correction that retains each newly published reference until the following accepted picture header determines whether B reordering owns it, adds a regression for publication coincident with vblank followed by B pictures, and preserves fail-open behavior. Use the session-authorized incremental Quartus build after the existing decoder and publication regressions pass.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 225 COMMIT Unreleased 1b26cb5 2026-08-18T13:46:18-07:00

#### Coming From:

Unreleased bbe625e

#### Purpose:

Prevent a newly published future reference from being displayed before the following picture header assigns B-reorder ownership.

#### Outcome:

Commit `1b26cb5` retains each ordinary reference publication as pending and makes it ineligible for display until a following accepted non-B header or terminal sequence boundary releases it; a following B header instead transfers ownership directly into the existing two-scratch reorder transaction. The focused regression reproduces publication coincident with vblank and proves that the future reference remains hidden while both B scratches and then the future reference display in order; ordinary non-B release, a terminal boundary consumed before publication, and fatal fail-open recovery also pass. The transport and final-GOP observer tests pass unchanged. The DDR-backed 72-picture live-raster soak and independent 720x480 long-GOP publication test each pass 22 P pictures, 47 B pictures, 25 publications, 25 final display identities, both scratch banks, completed presentation, and zero presentation, ownership, parser, prediction, or writer errors. The session-authorized incremental Quartus 17.0.2 compile preserves the existing database, recognizes only the changed scheduler source, and completes in 9 minutes 1 second with 0 errors and 121 standing warnings; global setup/hold slack is +0.640/+0.253 ns, focused decoder/video setup slack is +1.852/+7.307 ns, and utilization is 29,589 ALMs, 42,295 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit225_1b26cb5.rbf` is 4,222,572 bytes with SHA-256 `3c31afab0e8d905e12434c8cc9468160add9765f74669c44950b477cdf43208f`; its MiSTer FTP readback is byte-identical.

#### Next Steps:

Reload the deployed core and run `test_compat_long_gop.m2v` once. Confirm whether visible presentation advances beyond frame 50 to the final source frame 71, USER and POWER remain solid, and the settled DISK report advances from stage two to stage eleven; if any lower stage remains, report its blink count and the last visible frame. Then reload `test_compat_mixed_macroblocks.m2v` to check that the classification barrier does not worsen its existing load-time jitter.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 226 COMMIT Unreleased 1b26cb5 2026-08-18T14:13:55-07:00

#### Coming From:

Unreleased 1b26cb5

#### Purpose:

Record the hardware result of the reference-classification barrier and correct the inferred B-to-future-reference event ordering.

#### Outcome:

The deployed `1b26cb5` RBF now stops on frame 47 rather than frame 50; POWER repeats five blinks while USER and DISK remain off. POWER code five proves that a newer reference completed but the displayed bank did not advance to it, with no encoded decoder or DDR error. This result disproves Entry 224's vblank-first ordering: the B48 accepted-header event reaches the scheduler in the I50 publication handoff before the newly registered I50 reference bank is visible. The scheduler therefore compares the displayed P47 bank with stale P47 reference state, classifies the future reference as already displayed, and aborts the B run. Before Entry 225, ordinary `frame_waiting` could still display I50 after that abort, producing the old terminal frame 50; the new classification barrier correctly removes that fallback and exposes the underlying abort as terminal frame 47 and completed-versus-displayed mismatch. The apparent two-frame steps remain compatible with 30 fps camera sampling of one-refresh B pictures and do not alter this bank-ownership result.

#### Next Steps:

Await approval for a two-phase future-reference acquisition in the scheduler: a B header may open the run before its future publication is registered, and the next reference publication must then supply the completed bank without being treated as ordinary display work. Cover B-header ordering before, simultaneous with, and after reference publication, retain the Entry 225 ordinary and terminal release cases, preserve fail-open behavior, and use an incremental Quartus build for the next hardware boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 227 COMMIT Unreleased 302bb3e 2026-08-18T14:17:11-07:00

#### Coming From:

Unreleased 1b26cb5

#### Purpose:

Acquire a B run's future-reference bank correctly when its header and the reference publication cross the same registered handoff.

#### Outcome:

Commit `302bb3e` extends the Entry 225 scheduler barrier with an explicit future-reference-pending state. A B header can now open its decode and reorder transaction before the new reference bank is registered; a simultaneous publication supplies `completed_frame_bank` directly, an earlier publication supplies the locked ordinary pending bank, and a later publication binds the completed bank into the already-open B run instead of entering ordinary display. The scheduler defers the already-displayed conflict decision while that future reference is pending, while retaining scratch ownership checks, ordered B presentation, terminal release, destination ownership, and fatal fail-open behavior. The focused regression passes B-header ordering before, simultaneous with, and after publication, including the frame-47 stale-bank case, the vblank classification barrier, two-scratch order, ordinary non-B release, terminal-boundary release, and abort recovery. The transport and final-GOP observer tests pass unchanged. The DDR-backed 72-picture live-raster soak and independent 720x480 long-GOP publication run each pass 22 P pictures, 47 B pictures, 25 publications, 25 display identities, final source-frame identity 71, both scratch banks, completed presentation, and zero presentation or ownership errors. The session-authorized incremental Quartus 17.0.2 compile preserves the project database, recognizes the changed scheduler source, and completes in 9 minutes 12 seconds with 0 errors and 121 standing warnings; global setup/hold slack is +0.297/+0.202 ns, focused decoder/video setup slack is +0.648/+7.689 ns, and utilization is 29,470 ALMs, 42,060 registers, 4,027,379 memory bits, 504 RAM blocks, 65 DSP blocks, and 3 PLLs. `MediaPlayer_commit227_302bb3e.rbf` is 4,270,644 bytes with SHA-256 `ffad40366cc00d14ecce4575fd44766dd2fedd3fbbc346082d65b908ee9e1a24`; its MiSTer FTP readback is byte-identical. Hardware acceptance passes all requested stream and LED checks: `test_compat_long_gop.m2v` reaches its final source frame 71 with the passing LED report, and the companion compatibility tests also pass.

#### Next Steps:

Continue from hardware-accepted commit `302bb3e`; select the next compatibility target under the standard proposal-first workflow without reopening the completed long-GOP reference-handoff correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [x] Passed

---
