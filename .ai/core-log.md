## 36 COMMIT Unreleased aad072a 2026-09-14T00:15:26-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the freeze telemetry reproduced with fellow.

#### Outcome:

The user reports making fellow freeze. The fresh screenshot and checksum-valid schema-10 decode are under results/telemetry-20260914-001450. Error flags are 0x2004: the same aggregate decoder probe error 0x0004 plus audio timestamp error 0x2000. Audio underrun, MP2 decoding error and transport error are zero; EOF is false. The final recorded picture type is P with temporal reference eleven, unlike the B-picture states in the Pee Strike captures. The snapshot reports 967021 played audio sample pairs, 1259 processed audio frames, transport position 2656842 and 649 completed requests in generation two. The common aggregate decoder error now occurs on both tested movies, while the audio underrun is not consistent across failures. This supports investigating a shared playback/seek path rather than treating the issue as specific to Pee Strike, but does not establish an exact cause or first-fault order. The loaded state was preserved.

#### Next Steps:

Use both captures to guide combined MPG/audio reproduction and add decoder error subcode plus first-fault visibility; do not attribute the failure to audio underrun alone.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 35 COMMIT Unreleased aad072a 2026-09-14T00:13:44-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record decoded telemetry from the repeated freeze on the latest RBF.

#### Outcome:

The user reports both tested RBFs freeze alike and reran the latest candidate until telemetry appeared. The fresh screenshot and checksum-valid schema-10 decode are under results/telemetry-20260914-001304. Error flags are 0x3004: aggregate decoder probe error 0x0004, MP2 output underrun 0x1000 and MP2 output timestamp error 0x2000. Transport error and MP2 decoding error remain zero; EOF is false. The latched snapshot shows 104 associated pictures, 37 reference pictures, final B-picture temporal reference nine, 224 processed audio frames, 157321 played audio sample pairs, 4204428 transport bytes and 1027 requests/completions in generation two. Profiler session_cycles and accepted_bytes are both two following the seek reset; these are not whole-file counts or evidence of two-byte total progress. The same aggregate decoder error recurs across the reported seed tests, but this snapshot cannot order the video and audio faults or identify the decoder subcode. The prior seed-87 snapshot had the decoder error without either audio flag. The loaded state was preserved and no playback changes were made.

#### Next Steps:

Use the repeated decoder failure as the primary reproduction target, include combined MPG/audio flow and host stalls, and capture error subcodes and first-fault ordering rather than infer causality from the latched summary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 34 COMMIT Unreleased aad072a 2026-09-14T00:05:22-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the repeated seek freeze on timing-qualified seed 88.

#### Outcome:

The user reports that seed 88 froze in the same way after seeking. Fresh screenshots at 00:03:48 and 00:04:30 on September 14 show pixel-identical nonblack movie frames, confirming no visible frame change across 42 seconds. Neither screenshot contains decodable telemetry, so the previous seed-87 error 0x0004 cannot be assigned to this occurrence. Evidence and comparison.json are under results/telemetry-20260914-000348 and results/telemetry-20260914-000430. Passing all timing corners has not resolved the observed freeze; root cause remains undetermined. The core and loaded file were left untouched. Seed 88 remains timing qualified but fails hardware playback-control acceptance.

#### Next Steps:

Extend the exact-file reproduction to the combined MPG/audio buffering path and add bounded playback-control state and decoder error subcode visibility if required to distinguish seek, pause, starvation and fatal decoder states.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 33 COMMIT Unreleased aad072a 2026-09-13T23:54:38-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record timing-qualified seed 88 and the first exact-file seek replay comparison.

#### Outcome:

The additional aad072a placement batch completed. Seed 88 passes all four timing corners with setup +0.084 ns, hold +0.103 ns, recovery +3.150 ns, removal +0.231 ns and pulse width +0.925 ns, and passes the 135-register CDC audit. It uses 40462 ALMs, 54737 registers, 480 RAM blocks, 69 DSPs and three PLLs; its RBF SHA-256 is 983a08a8f3b90befc3ea66a4fd9e64393493f7effca1cb62db43716d3522d52e. Seeds 53 and 62 fail setup at -0.131 and -0.059 ns respectively, with other timing categories and CDC passing. Batch times are 1210 to 1221 seconds. Seed 88 is hash verified and marked preferred under results/hardware-test-aad072a, with the unresolved seed-87 decoder failure explicitly documented. An exact-file video-only simulation of Pee Strike completed ordinary playback to four seconds and a forward seek from about 2.2 to 12.2 seconds without the hardware decoder error. Evidence is under results/seek-repro-pee, including bounded-stream provenance, extracted diagnostic harness, logs and diagnosis.json. This is a decoder/reconstruction comparison, not full MPG/audio buffering or FPGA timing reproduction. The initial short-fixture watchdog stopped before the seek; final runs disabled that cutoff and required explicit boundary completion. A log-reading wrapper exceeded memory after baseline simulation completed, but its underlying log records successful completion. The root cause remains unresolved and seed 88 is not hardware accepted. No reset, reload or deployment was performed.

#### Next Steps:

Compare the same early Right-arrow seek on timing-qualified seed 88; if the failure persists, extend the exact-file reproduction to MPG/audio buffering and expose the decoder error subcode needed to isolate it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 32 COMMIT Unreleased aad072a 2026-09-13T18:40:17-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record faster successful seeks and the early forward-seek decoder failure in Pee Strike.

#### Outcome:

The user requested the best first-batch RBF and received hash-verified aad072a seed 87 with its -0.010 ns setup miss explicitly disclosed. The user reports successful skips are faster, but one Right-arrow press a few seconds into 01 - Pee Strike.mpg froze playback. Captures under results/telemetry-20260913-183433 and results/telemetry-20260913-183457 contain the same schema-10 snapshot with error_flags 0x0004, which maps to the aggregate decoder probe error. MP2 decode, timestamp and underrun flags and transport error are zero. The latched record shows 69 associated pictures, 25 reference pictures, final B-picture temporal reference 22, 105519 audio samples and transport generation two; counters are snapshot values, not live progress. The user identified the exact non-lower MPG. The Git drive contains its MP4 and lower MPG, so a bounded 16 MiB prefix of the exact 887078912-byte MiSTer file was retrieved into results/seek-repro-pee. Its video is progressive 720x480 at 30000/1001. A diagnostic replay of the first 450 pictures is being prepared with a forward seek around 2.2 seconds and detailed decoder error reporting. No reset, reload or deployment was performed. Additional placement seeds 53/62/88 remain running, but timing qualification alone cannot establish that this decoder failure is fixed.

#### Next Steps:

Compare ordinary playback and an in-flight forward seek on the exact opening stream, isolate the aggregate decoder error source, and validate a correction before hardware acceptance; finish the existing placement reports separately.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 31 COMMIT Unreleased aad072a 2026-09-13T18:30:07-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the first seek-acceleration build results and continue timing qualification.

#### Outcome:

All three aad072a seeds compile and pass the 135-register CDC audit, but none passes setup at every corner. Seed 52 uses 40401 ALMs and 54723 registers with setup -0.311 ns on scaler pixel unpacking; seed 61 uses 40612 ALMs and 54703 registers with setup -0.382 ns on scaler vertical polyphase rounding; seed 87 uses 40339 ALMs and 54709 registers with setup -0.010 ns on scaler horizontal position to picture-enable. Hold, recovery, removal and pulse width pass in all seeds. All retain 480 RAM blocks, 69 DSPs and three PLLs. Synthesis versus 17743f8 uses 147 fewer combinational ALUTs and 30 more registers, with unchanged block memory bits and DSP/PLL counts. Full build plus audits took 1157 to 1197 seconds. Evidence and explicitly unqualified RBFs are under results/build-aad072a-20260913-180758 and results/hardware-test-aad072a. A second clean placement batch of seeds 53, 62 and 88 from the identical aad072a source is running under results/build-aad072a-20260913-182853; playback logic and timing constraints are unchanged. No candidate has been deployed or hardware accepted.

#### Next Steps:

Finish the additional placement batch and deliver a timing-qualified seek acceleration candidate; if no seed qualifies, address the reported scaler timing paths before qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 30 COMMIT Unreleased aad072a 2026-09-13T17:56:12-07:00

#### Coming From:

Unreleased 17743f8

#### Purpose:

Reduce forward seek latency by retaining the current decoder session and validate repeated MPG seeks.

#### Outcome:

Committed and pushed aad072a. Forward seeks retain the live decoder session; backward seeks keep the byte-zero retirement handshake and ignore old-session completion until the new reader starts. Every seek refreshes its audio destination instead of retaining the previous landing time. MP2 frames ending at least 24 ms before the target bypass decoding and synthesis; at least one decoded frame restores finite synthesis history before playback. Tests pass repeated retained-session I/P/B seeks with zero reconstruction mismatches, EOF clamping, three forward/backward asynchronous control cycles with delayed DDR/host retirement, all key modifiers and paused state. The MPG regression bypasses 16 audio frames, resumes at the exact expected sample with no audio errors, preserves all 307021 video bytes and validates 30 picture timestamps. Independent quantizer/joint-stereo tests verify exact post-preroll PCM across timestamp wrap and two reset sessions. Legacy MP2, mounted reader, OSD, raster, refresh and CDC regressions pass. Evidence is under results/build-aad072a-20260913-180758/regressions; clean seeds 52/61/87 are compiling. The user confirms the previous black-screen seek eventually resumed and the earlier display duplication was a monitor issue; previous pause is accepted, faster seeks remain untested on hardware.

#### Next Steps:

Finish all three builds and timing/CDC audits, deliver a qualified RBF, and compare forward skip duration near the start and late in fellow.mpg; verify backward seeks, paused seeks, EOF and audible continuity.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- README.md
- docs/OSD_PLAYBACK_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- rtl/audio/mp2_decoder.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_playback_control.sv
- tools/test_mp2_decoder.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/test_playback_restart.sv
- tools/verify_mp2_seek.py
- tools/verify_mpg_audio.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 29 COMMIT Unreleased 17743f8 2026-09-13T17:24:06-07:00

#### Coming From:

Unreleased 62f4741

#### Purpose:

Deliver timing-qualified keyboard pause and seek candidates from the completed three-seed build.

#### Outcome:

All three clean 17743f8 seeds compile and pass the expanded 135-register CDC audit. Seed 52 passes all timing categories at all four corners with minimum setup +0.065 ns, hold +0.116 ns, recovery +2.865 ns, removal +0.260 ns and pulse width +0.925 ns; it is the preferred candidate and uses 40233 ALMs, 54615 registers, 480 RAM blocks, 69 DSPs and three PLLs. Its RBF SHA-256 is be8e0a26c4b3df7d12eb35db4a83067457ae8111551ec9310201cc509fe07607. Seed 61 also passes, with setup +0.005 ns, hold +0.108 ns, recovery +2.611 ns, removal +0.217 ns and pulse width +0.925 ns, using 40530 ALMs and 54621 registers. Seed 87 uses 40413 ALMs and 54622 registers but fails setup at -0.481 ns from ASCAL vertical position to output VS; its other timing categories pass. Total compile plus timing durations are 1161, 1111 and 1169 seconds for seeds 52, 61 and 87. Relative to compact source 0b6eb0e, synthesis adds 906 combinational ALUTs and 534 registers with unchanged memory bits, DSPs and PLLs; larger fitted ALM differences include placement effects. Evidence is under results/build-17743f8-20260913-170250 and hash-verified RBFs plus explicit timing status and instructions are under results/hardware-test-17743f8. The extended EOF seek oracle lands on the last frame with zero pixel mismatches and explicitly completes its paused-display check. Seven-minute numbered raw/MPG clips are under results/playback-control-tests. No new core has been deployed or hardware accepted; 0b6eb0e seed 87 remains the accepted baseline.

#### Next Steps:

Have the user load the preferred seed 52 and verify Space pause/resume, all three Left/Right seek sizes, paused seeking, EOF clamps, repeated commands, OSD isolation, audio continuity and both output refresh rates using the documented vsync_adjust=1 override; record landing times and reconstruction latency.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 28 COMMIT Unreleased 62f4741 2026-09-13T17:17:06-07:00

#### Coming From:

Unreleased 58f74d7

#### Purpose:

Document the required HDMI refresh override and align setup guidance with current playback features.

#### Outcome:

Committed and pushed 62f4741 documenting [MediaPlayer] vsync_adjust=1 even when the global setting is zero. Official MiSTer video documentation confirms mode one follows core refresh while zero uses configured output timing and can introduce repeat/drop cadence conversion. README now describes accepted compact baseline 0b6eb0e seed 87, fully manual aspect and refresh, color matrix selection, keyboard controls pending hardware validation and reconstruction-seek latency. The hardware instructions include the override and no longer claim pause/seek are unexposed. Whitespace review passes; documentation-only changes require no FPGA build and do not modify the running 17743f8 batch.

#### Next Steps:

Use the documented per-core refresh override and finish the current build handoff for hardware playback-control testing.

#### Files Modified:

- README.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 27 COMMIT Unreleased 58f74d7 2026-09-13T17:10:11-07:00

#### Coming From:

Unreleased 17743f8

#### Purpose:

Require successful seek-controller completion in the full I/P/B EOF reconstruction regression.

#### Outcome:

Committed and pushed 58f74d7: the full mixed-pixel bench now supports a seek beyond the file end as well as the existing frame-ten seek. Both modes verify the expected landing time and retained paused display bank; control-mode drain observation is extended so the bench cannot finish before the pause/seek checks complete. An explicit completion assertion prevents the pixel oracle alone from being mistaken for control acceptance. The extended EOF mode lands on frame 23 of the 24-picture stream with zero pixel mismatches, no decoder/presentation errors and clean control completion. These are test-only changes and do not change the 17743f8 RBF being built.

#### Next Steps:

Finish the 17743f8 build batch and deliver timing-qualified hardware candidates with the extended regression evidence; the test-only commit requires no separate FPGA build.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/verify_decoder_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 26 COMMIT Unreleased 17743f8 2026-09-13T17:02:36-07:00

#### Coming From:

Unreleased 6b22b6e

#### Purpose:

Retain the frame-rounded seek destination through the audio acknowledgement handoff.

#### Outcome:

Committed and pushed 17743f8 to latch the frame-rounded destination until the next decoder reset. The added assertion fails on 6b22b6e and passes on the corrected controller, including all five source rates and all three seek intervals. All focused keyboard, asynchronous restart, PCM pause/seek, timestamp wrap and legacy sink checks pass. The canceled 6b22b6e process group was confirmed stopped, and replacement clean seeds 52/61/87 are running under results/build-17743f8-20260913-170250. All three pass synthesis; seed 87 reports 52905 synthesized registers with unchanged 3754315 memory bits, 69 DSPs and three PLLs. Fitted utilization and timing remain pending. Seven-minute 25/29.97 fps counter clips were generated with the committed make_cadence_motion_tests.py --seconds 420 under results/playback-control-tests; all four raw/MPG files pass full decode and frame-count checks. No playback-controls RBF is hardware accepted.

#### Next Steps:

Finish all seeded builds and timing/CDC audits, retain the seven-minute counter media for hardware checks, and extend the reconstruction regression to require explicit end-of-file seek completion.

#### Files Modified:

- rtl/media_playback_control.sv
- tools/test_media_playback_control.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 25 COMMIT Unreleased 6b22b6e 2026-09-13T16:38:32-07:00

#### Coming From:

Unreleased 6da4771

#### Purpose:

Implement keyboard play/pause and time-based seeks using the existing stock-Main playback path.

#### Outcome:

Committed 6b22b6e implementing Space pause and Left/Right 10/30/300-second seeks with both modifier sides, OSD exclusion and typematic suppression. Playback time, queued PCM and display ownership are retained on pause; seeks reconstruct from byte zero with silent PCM discard and frame-boundary completion. Keyboard, exact rational target rounding at five rates, timestamp wrap, PCM retention/EOF, three asynchronous restart transactions, reader retirement and raw EOF closure tests pass. The real MPG oracle retains all 24192 sample pairs through a 100 ms pause with at most one code of FFmpeg error, and the mixed 24-picture I/P/B oracle has zero pixel mismatches in normal and seek/pause modes. Video/OSD regressions also pass. Full-top Verilator lint encountered an internal tool fault with vendor simulation libraries, so it was not counted as a pass. Three clean builds under results/build-6b22b6e-20260913-165629 reached fitting but were stopped after review found that the rounded audio landing time could revert to the requested time after seek acknowledgement. A new regression reproduces that defect. No RBF from this source is qualified or delivered.

#### Next Steps:

Latch the final rounded destination until the next session reset, repeat the focused regression, and rebuild the corrected source in three clean seeds.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- docs/OSD_PLAYBACK_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/mp2_pcm_output.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_playback_control.sv
- tools/test_mp2_pcm_output.sv
- tools/test_mp2_playback_control.sv
- tools/test_mpg_audio_playback.sv
- tools/test_playback_restart.sv
- tools/test_program_stream_ingress.sv
- tools/verify_decoder_timing.py
- tools/verify_mpg_audio.py
- tools/verify_playback_controls.py
- tools/verify_program_stream_ingress.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 24 COMMIT Unreleased 6da4771 2026-09-13T16:23:17-07:00

#### Coming From:

Unreleased 6da4771

#### Purpose:

Record user acceptance of the refresh-rate comparison using the generated motion tests.

#### Outcome:

The user confirms the refresh switch is working and clearly observes smoother motion with the 29.97 fps test at 59.94 Hz. They cannot readily distinguish the two output settings with the 25 fps clip, so that visual comparison remains inconclusive rather than a failure. This accepts the observed refresh-dependent cadence benefit on the existing hardware-accepted compact core 0b6eb0e seed 87 by handoff context. No independent running-RBF hash, measured HDMI refresh, or specific raw-versus-program-stream test coverage was reported. The media generator passed its software checks; no new FPGA build was needed for this cycle.

#### Next Steps:

Retain the accepted compact core and manual refresh selection, with 59.94 Hz for 29.97 fps content and 50 Hz available for 25 fps content; no corrective implementation is indicated by this test.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 23 COMMIT Unreleased 6da4771 2026-09-13T16:01:34-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Generate deterministic motion-focused media for visual refresh-rate qualification.

#### Outcome:

Implemented the reproducible motion-test generator and produced approximately 60-second progressive 720x480 clips at 25 and 30000/1001 fps, each in raw M2V and silent-audio MPG form. Sharp constant-speed bars, panning fences and frame IDs expose uneven frame holds while keeping source speed fixed during refresh switches. All four files pass complete FFmpeg decoding and ffprobe checks for exact rate, progressive geometry and expected frame count (1500 or 1798). Representative frames were visually inspected. Media, comparison instructions, previews and SHA-256 manifests are under results/cadence-motion-tests. Python syntax and git whitespace checks pass. No RTL changed or FPGA build was required; hardware comparison of these new clips remains pending.

#### Next Steps:

Have the user compare the same 25 fps clip at 50 and 59.94 Hz, then use the 29.97 fps clip as the reverse control; close the OSD and keep filters constant during each observation. Confirm actual output refresh with display signal information when available.

#### Files Modified:

- tools/make_cadence_motion_tests.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 22 COMMIT Unreleased 0b6eb0e 2026-09-13T16:01:34-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Record user acceptance of the compact core and withdraw the reported hang as a core defect.

#### Outcome:

The user states that they caused the reported hang and instructs the agent to ignore it, then reports the new core works perfectly like the preceding core. This accepts ordinary hardware behavior of the delivered compact seed 87 by handoff context; no running hash was independently captured. The earlier freeze is no longer an open core defect. The user is still qualifying the visible refresh-rate benefit and requests more discriminating test media because the existing clips make the difference difficult to see.

#### Next Steps:

Retain compact source 0b6eb0e seed 87 as the hardware-accepted baseline and produce motion-focused media to compare 25 fps at 50/59.94 Hz.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 21 COMMIT Unreleased 0b6eb0e 2026-09-13T15:55:39-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Record completed compact-telemetry builds, measured resource savings and the clarified whole-movie failure context.

#### Outcome:

All three clean source-0b6eb0e seeds compile and pass the unchanged 108-register CDC audit. Seed 87 passes every timing category at all four corners, with minimum setup +0.082 ns, hold +0.100 ns, recovery +3.007 ns, removal +0.199 ns and pulse width +0.925 ns. Its fitted use is 37548 ALMs, 54191 registers, 480 RAM blocks and 69 DSP blocks, leaving 4362 ALMs free; its RBF SHA-256 is 17e0b04eb91fe7d75538338f171da9c8cf8e6a8d57e1c395e6fd3ad8b3137507. Seed 52 uses 40372 ALMs and fails setup at -0.011 ns in the ASCAL vertical polyphase path; seed 61 uses 40247 ALMs and fails setup at -0.493 ns in ASCAL vertical filtering. Both other seeds pass hold, recovery, removal and pulse width. Compile plus timing durations are 1119, 1081 and 1162 seconds for seeds 52, 61 and 87. Compared with dd144a3, source synthesis saves 1803 combinational ALUTs and 3021 registers without changing memory bits, DSPs or PLLs; the profiler alone falls from 3290 to 1515 synthesized ALUTs and from 5449 to 2429 registers, while fitted seed-87 profiler use is 894 ALMs. The larger reduction between the preceding qualified seed 52 and this qualified seed 87 includes placement effects. Complete evidence, regression results and copied RBFs with explicit timing status are under results/build-0b6eb0e-20260913-153453 and results/hardware-test-0b6eb0e. Separately, the user clarifies the freeze occurred in fellow.mpg at fixed 50 Hz without a switch, and this was the first test that far into the file. FTP reports 4359360512 bytes at /media/fat/games/MediaPlayer/fellow.mpg, exactly matching the historical large-file case in af7f570. That old fix enabled 64-bit ARM-helper stat() for Total/Remaining labels and did not resolve the separately noted decoder hang. The current reader uses 64-bit size and position; the saved snapshot already read 110306058 bytes, exceeding the 64393216-byte low-32-bit size, so simple size truncation does not explain that captured progress. Actual filesystem type was not established by the FTP proc-file read, and the /media/fat name is not evidence of FAT32. No freeze cause or refresh regression has been established, and no compact RBF has been deployed or hardware-accepted.

#### Next Steps:

Offer source-0b6eb0e seed 87 for compact-telemetry hardware validation with the updated decoder, retaining the detailed dd144a3 candidate and saved freeze captures for diagnosis. Confirm normal playback, retained EOF/error/audio/transport fields and OSD controls before accepting telemetry cuts. Investigate fellow.mpg separately, using reproducible position and a 59.94 Hz comparison or fresh live-state diagnostics; do not present telemetry cuts as a freeze fix. Do not use timing-failed seeds 52 or 61 as qualified artifacts.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 20 COMMIT Unreleased dd144a3 2026-09-13T15:46:46-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Record the user's long-movie freeze report and preserve non-disruptive hardware evidence during the telemetry builds.

#### Outcome:

While separately testing the dd144a3 refresh candidate, the user reports a whole-movie file froze well into playback at 50 Hz, that other files worked at both refresh rates, and that the OSD still opens. Two fresh FTP-triggered captures 26.5 seconds apart are pixel-identical across all 720x480 pixels, confirming a stationary movie picture while Main remains responsive. Evidence is retained under results/telemetry-20260913-154407 and results/telemetry-20260913-154434, including comparison.json. Both images decode a valid schema-9 snapshot with source rate code 2 (24 fps), audio-underrun flag 0x1000, no decoder/presentation/file-reader error, no EOF, 7380 decoded MP2 frames and 8501760 played sample pairs, and audio STC 177 seconds. The profiler latches at the first triggering event, so this may be an earlier underrun snapshot rather than the freeze state; neither 177 seconds nor the wrapped FPS/cycle/picture counters establishes the freeze time or cause. The RTL underrun flag does not gate transport or playback. Large file size and 50 Hz are not established causes. No reset, file reload, deployment or mode change was performed. This is partial refresh validation with an unresolved long-file playback failure, not overall hardware acceptance; compact-telemetry source 0b6eb0e continues compiling separately and has not been installed.

#### Next Steps:

Preserve the detailed dd144a3 candidate and captured evidence for investigation, distinguish the current stall from the previously latched snapshot, and obtain a reproducible file/position or fresh live diagnostic evidence before choosing a playback fix. Complete the already authorized compact-telemetry builds and report their resources and timing without treating them as a fix for this freeze.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 19 COMMIT Unreleased 0b6eb0e 2026-09-13T15:28:53-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Reduce default observational telemetry logic while retaining essential playback-health diagnostics and an optional detailed profile.

#### Outcome:

Source 0b6eb0e implements compact schema 10 with 25 words instead of 49, retaining the approved byte/time/picture metadata, errors, one maximum gap and outlier count, basic terminal state, audio and transport-health words. Only detailed-performance outputs are excluded from the default synthesis cone; their equations remain available under MMP_DETAILED_TELEMETRY for schema-9 diagnostic builds. The overlay remains at (8,280) but is 100 pixels tall instead of 196. Side-by-side RTL tests prove every retained word equals the detailed profile at quiet EOF, all supported cadence codes, terminal timeout, fatal error, no-progress capture and pre-decode transport failure. The new verifier decodes actual compact RTL overlay RGB pixels, rejects corrupted cells, checks the command-line report, and confirms schema 7/8/9 compatibility at every retained overlay origin. Removed diagnostics are explicitly unavailable/null; the host checksum field now correctly uses the last word for every schema. Existing video, OSD, scanout, cadence, geometry, CDC, 50 Hz switching and profiler regressions pass. Decoder, audio and presentation-control RTL are unchanged. Source is pushed and seeds 52, 61 and 87 are compiling under results/build-0b6eb0e-20260913-153453, which retains regression evidence. Resource savings and timing remain pending; the user is separately testing the preceding dd144a3 seed-52 refresh build.

#### Next Steps:

Measure synthesized and fitted savings against dd144a3, complete all four timing corners and the unchanged 108-register audit for all three seeds, then deliver timing-qualified compact RBFs and capture instructions. Record the user's dd144a3 hardware feedback separately when it arrives; do not conflate that acceptance with this telemetry build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- MediaPlayer_top_07.svh
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/verify_compact_telemetry.py
- tools/streams/run_hardware_cadence.py
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 18 COMMIT Unreleased dd144a3 2026-09-13T15:26:03-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Record completed manual-refresh builds, the timing-qualified candidate and the resource review requested during compilation.

#### Outcome:

All three clean source-dd144a3 builds compile and pass the 108-register fitted CDC audit. Seed 52 passes every timing category at all four operating corners, with minimum setup +0.114 ns, hold +0.018 ns, recovery +2.714 ns, removal +0.186 ns and pulse width +0.925 ns. It uses 41215 ALMs, 57400 registers, 480 RAM blocks and 69 DSP blocks; its RBF SHA-256 is 6a0720e4623c77c65e1736a729686b7c9165ef10c42265311a029dd57131de45. Seed 61 uses 41082 ALMs and fails setup at -0.004 ns in ASCAL, while seed 87 uses 41279 ALMs and fails setup at -4.958 ns from the prediction fetcher descriptor count into a reference-cache tag; their other timing classes pass. Build plus timing durations are 1353, 1267 and 1421 seconds for seeds 52, 61 and 87 respectively. Source synthesis adds 157 combinational ALUTs and 24 registers versus 24d3de0, with unchanged memory bits, DSPs and PLLs; the smaller fitted seed-52 ALM total reflects placement and is not an architectural saving. Complete evidence is under results/build-dd144a3-20260913-150109 and copied RBFs with hashes and explicit qualification status are under results/hardware-test-dd144a3. The user was given seed 52 and results/refresh-tests/README.txt; hardware acceptance is pending. During compilation the user requested resource and removable-telemetry analysis. The accepted 24d3de0 seed-52 hierarchy attributes approximately 3110 ALMs, 65 RAM blocks and 12 DSPs to identifiable audio blocks excluding shared A/V logic, and 2612 ALMs to the observational cadence profiler alone. Detailed ranked-gap history, per-picture stall and overlapping hold counters, DDR performance totals and scheduler dumps are candidates for a smaller diagnostic profile, while errors, basic cadence, audio counts/status and transport health should remain. No telemetry removal or RAM-storage redesign was authorized or implemented.

#### Next Steps:

Have the user validate the preferred dd144a3 seed 52 using the generated 25/29.97 fps MPG and M2V controls, manual refresh switches, display-rate confirmation with vsync_adjust=1, OSD/aspect/matrix/filter operation and A/V synchronization. Retain 24d3de0 seed 52 as recovery and do not present seeds 61 or 87 as timing-qualified. Further telemetry reduction remains a proposal requiring user direction and measured synthesis savings.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 17 COMMIT Unreleased dd144a3 2026-09-13T14:52:23-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Add user-selected 50 Hz progressive output alongside the accepted 59.94 Hz mode while retaining 720x480 decoding.

#### Outcome:

Source dd144a3 adds Refresh rate 59.94 Hz/50 Hz on status bit 6. Both modes use 27 MHz and 720x480 active pixels; total rasters are 858x525 and 864x625. Requests cross through a coherent mailbox and apply only at frame end; a second mailbox publishes the applied mode to the decoder before the next swap window. Exact cadence tests pass for all five source rates at both refresh rates, including 1000 presentations in 2000 windows for 25 fps/50 Hz. Pending-picture ownership and timestamp admission survive mode changes. Full raster tests pass six complete frames with four asynchronous live switches, while both fixed-mode scanout tests deliver all 345600 exact pixels despite DDR stalls and bank resets. Existing OSD, geometry, color arithmetic/control, cadence telemetry and MPG audio regressions pass; the audio oracle retains zero underrun and timestamp error. No audio or PTS clock changes are needed. Deterministic progressive 25/29.97 fps MPG and M2V hardware clips and README are under results/refresh-tests. Source is pushed and clean seeds 52, 61 and 87 are compiling under results/build-dd144a3-20260913-150109, which also retains regression evidence. The fitted audit now requires 108 preserved registers. HDMI relock and user-visible A/V behavior still require hardware validation; there is no DVD, interlaced, 576-line, gamut or gamma expansion.

#### Next Steps:

Complete the three clean builds, record all four timing corners and resources, and deliver timing-qualified RBFs with the generated refresh checks. Retain hardware-accepted 24d3de0 seed 52 as recovery until the user validates mode switching, 25 fps cadence, OSD controls and audio synchronization with vsync_adjust=1.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/mpeg2_video_720x480p.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/phase1p_timing.tcl
- tools/test_480p_scanout.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/verify_video_sync.py
- tools/test_refresh_rate.sv
- tools/make_refresh_tests.py
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 16 COMMIT Unreleased 24d3de0 2026-09-13T14:25:07-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Record the user's successful hardware validation of the color-matrix build.

#### Outcome:

The user reports that all tests pass and that every change outlined in the supplied README was observed on hardware. This accepts the requested visual color-matrix checks following delivery of the recommended 24d3de0 seed 52 candidate, which already passes all four timing corners and the 96-register CDC audit. Seed 52 is associated with this acceptance from the handoff context; the running RBF hash was not independently captured. The user's observation is the hardware evidence, and no additional screen capture was taken. Local acceptance metadata is retained under results/hardware-test-24d3de0/seed52. Gamma and gamut conversion remain excluded.

#### Next Steps:

Retain 24d3de0 seed 52 as the accepted baseline and await the next requested development task; no additional build or release is required for this validation cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 15 COMMIT Unreleased 24d3de0 2026-09-13T14:09:33-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Record the completed color-matrix builds and timing-qualified hardware candidates.

#### Outcome:

All three clean 24d3de0 seeds compiled successfully and passed the fitted 96-register CDC audit. Seed 52 passes every timing class at all four operating corners with minimum setup +0.266 ns, hold +0.044 ns, recovery +2.335 ns, removal +0.141 ns and pulse width +0.925 ns; its SHA-256 is 256ff2b2eade4f525785364a38f989c91d32fc50178ed87d5d950d80d9c3815c. Seed 87 also passes, with setup +0.069 ns, hold +0.036 ns, recovery +3.543 ns, removal +0.188 ns and pulse width +0.925 ns; its SHA-256 is edd3f3ce51b2d4ecead3c668fd86188387806ad06ad670f82fbc9fb166c656e6. Seed 61 fails setup at -0.096 ns on the presentation-scheduler pending-bank path into the P parser; its other timing classes pass. The preferred candidate is seed 52, while the previously delivered seed 87 remains timing-qualified. RBFs, hashes and explicit timing status are under results/hardware-test-24d3de0/seed52, seed61 and seed87, with complete reports under results/build-24d3de0-20260913-134011. Synthesis adds 126 combinational ALUTs and 46 registers versus 62baf08, with unchanged block-memory bits and DSP count. Fitted seeds 52, 61 and 87 use 41274, 41004, 41011 ALMs respectively; every seed uses 480 RAM blocks and 69 DSP blocks. Total build/timing durations were approximately 1654, 1176 and 1347 seconds. Regression evidence and generated matching/untagged clips are retained; no matrix-enabled or new aspect hardware acceptance has been reported. Gamma and gamut conversion remain explicitly excluded.

#### Next Steps:

Test the preferred seed 52 with results/color-matrix-tests: Auto should match the tagged 601 and 709 clips, while the untagged 709 clip requires the manual BT.709 override. Verify frame-boundary color changes, subsequent file reload, uninterrupted OSD/filter controls and manual 4:3/16:9 aspect switching. Await hardware feedback before further implementation or release; do not treat seed 61 as timing-qualified.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 14 COMMIT Unreleased 24d3de0 2026-09-13T13:28:53-07:00

#### Coming From:

Unreleased 62baf08

#### Purpose:

Implement frame-associated BT.601/BT.709 color matrix selection with user overrides and deterministic visual tests.

#### Outcome:

Committed and pushed 24d3de0 with optional sequence-display color-matrix parsing, frame-associated reference/scratch matrix context, Auto/BT.601/BT.709 overrides and frame-boundary application through two acknowledged mailboxes. Missing/unspecified/unsupported tags use the documented BT.601 compatibility fallback. Exhaustive simulation covers all 16777216 input triples: BT.601 is exact against 62baf08 and BT.709 differs from the BT.709-6 reference by at most one RGB code. Metadata, reset, repeated/truncated descriptions, all 256 tag values, queued B pictures, simultaneous header/commit and override CDC tests pass. Colored stalled-DDR scanout checks 345600 exact pixels and continuous sync; existing video/OSD/cadence and integrated mixed I/P/B regressions also pass. Deterministic 601/709 matching clips and an untagged 709 clip are generated under results/color-matrix-tests. The consulted BT.709-6 items 3.2 through 3.4 are added to core-reference.md with notification to the user; the H.262 metadata interpretation uses the already-controlled 02/2000 baseline. Gamut and gamma conversion are explicitly excluded by the user. The independent 62baf08 seeds are now complete: seed 61 passes all four operating corners with setup +0.395 ns, hold +0.103 ns, recovery +3.149 ns, removal +0.152 ns and pulse width +0.925 ns, and all 84 audited synchronizer registers. Its RBF SHA-256 is 1d0b6dfcb917df72f567f760956280638696d866fa190362fe7f3d03357c47ff, with 41267 ALMs, 57463 registers, 480 RAM blocks and 69 DSP blocks. Seed 52 fails setup at -0.159 ns on a P-frame address path and seed 87 at -0.032 ns on scaler vertical interpolation; other timing classes and audits pass. All three files are under results/hardware-test-62baf08/, with seed 61 delivered as the timing-qualified aspect/OSD candidate and no hardware acceptance yet. Clean color seeds 52, 61 and 87 are running under results/build-24d3de0-20260913-134011; the fitted audit now requires 96 synchronizer registers. No matrix-enabled hardware result is available yet.

#### Next Steps:

Complete the three color builds, require all four operating-corner timing classes and all 96 audited registers, compare resource use against 62baf08 and provide timing-qualified candidates. Hardware should validate Auto on both tagged clips, the manual override on the untagged clip, frame-boundary changes, subsequent file reload and uninterrupted OSD/filter/aspect behavior. Continue using the delivered 62baf08 seed 61 for the independent aspect/timing hardware test.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_color_control.sv
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_picture_color.sv
- rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv
- tools/make_color_matrix_tests.py
- tools/phase1p_timing.tcl
- tools/test_media_color_control.sv
- tools/test_picture_color.sv
- tools/verify_color_matrix.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 13 COMMIT Unreleased 62baf08 2026-09-13T13:05:36-07:00

#### Coming From:

Unreleased a0f153a

#### Purpose:

Provide manual 4:3 and 16:9 aspect selection and repair the observed decoder and scaler setup paths.

#### Outcome:

Committed and pushed 62baf08 with exactly two user-selected aspect choices, 4:3 and 16:9; removed sequence-aspect synchronization and its obsolete exception. The actual core mailbox and platform rectangle test passes six switches across 1080p and 5:4 outputs. B-frame coordinate snapshots split launch-address arithmetic without changing request latency. The final scaler fraction step occupies an existing delay stage and registered blanking preserves transition cycles. Extracted production VHDL matches a0f153a for 250000 randomized cycles at FRAC 4, 6 and 8 across every consumed fraction stage and resolution-blanking transition; the complete scaler also analyzes successfully in GHDL. The mixed I/P/B oracle checks 423936 samples with zero tolerance violations and maximum delta two, matching a0f153a cycle counts, request counts and prefetch activity. The old bench referenced a removed arbiter diagnostic and had a one-cycle stale depth-four total; both were corrected against the baseline. OSD/raster/CDC/cadence/telemetry and mounted-reader/session regressions pass. Timed MPG audio checks 24192 stereo pairs with maximum error one, 152679 video bytes and 15 timestamps without underrun. Clean seeds 52, 61 and 87 are running under results/build-62baf08-20260913-131350; timing and hardware acceptance remain pending.

#### Next Steps:

Complete all three clean builds and the fitted 84-register CDC audit, inspect every setup/hold/recovery/removal/pulse-width operating corner, and deliver clearly labeled hardware candidates. Verify manual aspect changes and continued OSD/filter operation during playback on hardware. Do not describe a seed as timing-qualified before all corners pass.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- docs/TEST_INSTRUCTIONS.md
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- sys/ascal.vhd
- tools/streams/tb_h262_live_raster_soak.sv
- tools/verify_decoder_timing.py
- tools/verify_manual_aspect.py
- tools/verify_scaler_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 012 COMMIT Unreleased a0f153a 2026-09-13T12:54:32-07:00

#### Coming From:

Unreleased a0f153a

#### Purpose:

Record completed OSD builds, accepted interactive-menu hardware behavior and the remaining setup-timing work.

#### Outcome:

All three clean a0f153a seeds compiled and passed the fitted 84-register CDC audit and explicit four-corner hold, recovery, removal and pulse-width checks. Worst setup for seeds 52, 61 and 87 is -0.200, -0.137 and -0.234 ns respectively; no build is timing-qualified. Seed 52's worst path is the 60 MHz B-frame backward-motion/address calculation into phase1_base_addr_reg; seed 61 fails HDMI scaler fraction/address logic and seed 87 fails HDMI scaler control-to-pixel logic. Their ALM counts are 41237, 40806 and 40913, with 480 RAM blocks and 69 DSP blocks each. Build and timing times were approximately 1263, 1235 and 1436 seconds. Evidence is retained in results/build-a0f153a-20260913-122739/ and all three RBFs are copied under results/hardware-test-a0f153a/seed52, seed61 and seed87 with hashes and explicit timing status. At the user's request, seed 52 SHA-256 2fe49c2d3f05dd038062b76c1026dc261b03c2e53378967c2dfb632cf084d5af was delivered despite its disclosed timing failure. The user confirmed the fix works: OSD is controllable and filters work during playback. Passed here records that accepted OSD/filter scope, not timing qualification or unreported EOF/reload testing. The user explicitly excluded DVD and interlaced playback from the project; progressive-only scope supersedes the older roadmap in core.md and historical references, without automatically editing restricted core.md. A read-only FTP check confirmed current MiSTer.ini has MediaPlayer vsync_adjust=1, global video_mode=8 and direct_video=0, and no active MediaPlayer main override in the inspected section. This config matches HDMI to the fixed 60000/1001 Hz core raster, not to each movie frame rate. Source rates 24000/1001, 24, 25 and 30 still have noninteger repetition on that raster; 30000/1001 has a two-refresh cadence. Optional progressive source-matched raster/scheduler modes were investigated only and not implemented.

#### Next Steps:

Plan a focused timing cleanup of the B-frame address calculation and HDMI scaler arithmetic/control paths, preserving decoder values, filter quality and pixel/sync alignment. Require regression checks and positive setup at every operating corner; do not loosen clocks or hide genuine synchronous paths. Keep the accepted OSD behavior and progressive-only scope. Future refresh work can target twice-source-rate outputs where displays support them while retaining 59.94 Hz compatibility mode; leave vsync_adjust=1 configured. Await the user's direction before a new implementation cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 011 COMMIT Unreleased a0f153a 2026-09-13T12:11:46-07:00

#### Coming From:

Unreleased 07b8688

#### Purpose:

Implement stock-Main mounted-file playback with interactive OSD access and session foundations for future pause and seeking.

#### Outcome:

The approved implementation was committed and pushed as a0f153a before three clean seed builds. Stock Main now mounts MPG/M2V files through S0; a 4 KiB sector staging RAM feeds a 32 KiB byte/EOF FIFO with prefill and exact final-byte handling. The session controller stops DDR grants, drains descriptor-owned responses and waits for host retirement before restarting clients and releasing FIFO reset. Tests passed 102757 exact bytes across tails, nonzero offsets, stalls, cancellation, malformed responses and timeout quarantine, plus actual hps_io status/WIDE transfer checks and DDR/session restart ordering. Timed mounted-reader MPG simulation with periodic 2 ms host delays matched 152679 video bytes, 15 picture timestamps and 24192 stereo sample pairs against FFmpeg with maximum one-unit PCM error and no underrun or timestamp error. Existing video/OSD/cadence, ingress and arbiter regressions passed. Schema 9 adds transport diagnostics and preserves older capture decoding, including capture of a first-read failure before any decoded byte. A synthesis preflight compiled and the post-map audit preserved all 84 required synchronizer registers. Formal fitted builds remain pending. Read-offset and request-suspension primitives are implemented and tested for future seeking/pause; user-facing controls and their timeline logic are deferred. No hardware files, Main binary or ini were touched during the user's baseline test.

#### Next Steps:

Finish clean seeds 52, 61 and 87 from a0f153a, require the fitted 84-register audit and all four explicit operating corners, then report RBF candidates and retained evidence. Hardware acceptance must verify stock Main identity, menu responsiveness, filter adjustment during uninterrupted playback, repeated loads/reset and EOF. The simulation queues are ideal bounded models and do not establish physical CDC behavior or full video reconstruction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- docs/OSD_PLAYBACK_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_file_reader.sv
- rtl/media_session_control.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_stream_fifo.sv
- tools/build_three_seeds.py
- tools/phase1p_timing.tcl
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/test_media_file_reader.sv
- tools/test_media_hps_io.sv
- tools/test_media_session_control.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_media_file_reader.py
- tools/verify_mpg_audio.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 010 COMMIT Unreleased 07b8688 2026-09-13T12:09:39-07:00

#### Coming From:

Unreleased 0710e81

#### Purpose:

Record the completed subcarrier-crossing repair builds and explicit four-corner timing qualification.

#### Outcome:

Clean seeds 52, 61 and 87 compiled successfully and each passed the 60-register fitted synchronizer audit. Explicit checks at all four available operating conditions supersede the initial default-corner summaries: seed 52 fails setup at -0.076 ns and seed 61 at -0.005 ns in HDMI scaler paths at Slow 1100mV -40C; both pass hold, recovery, removal and pulse width. Seed 87 passes all four corners with minimum setup +0.121 ns, hold +0.097 ns, recovery +2.991 ns, removal +0.194 ns and pulse width +0.925 ns. Seed 87 uses 40609 ALMs, 55779 registers, 472 RAM blocks and 69 DSP blocks. Reports and corner-summary.json are retained under results/build-07b8688-20260913-114641/. The timing-qualified candidate is results/hardware-test-07b8688-seed87/MediaPlayer_20260913.rbf, SHA-256 9e5fe835433a1ca2141f37a7a84f870c10069cab645ad120e994bd59c435ee5e, with build-info.json. No new RTL or audio changes were made during validation and no candidate was installed. Loading-message suppression has only the earlier partial hardware acceptance; interactive OSD access remains absent. Read-only investigation found stock Main's generic mounted-file sector service provides a proposed RBF-side route to interactive menus, correcting the earlier overly categorical suggestion that a Main change might be necessary. The user requested a plan accommodating later pause and seeking; a local proposed docs/OSD_PLAYBACK_PLAN.md describes bounded reads, explicit sessions/EOF, coordinated flushing, future presentation pause and offset-based restart, pending implementation authorization.

#### Next Steps:

Have the user validate the seed-87 candidate on hardware. Preserve the timing reports and rollback reference. Implement the proposed stock-Main mounted-file transport only after the user accepts that plan, validating installed Main identity, menu responsiveness, buffering, repeated loads and exact EOF; pause and user seeking remain future milestones. Update the committed timing helper in a future authorized source cycle so file reports explicitly enumerate operating corners instead of relying on ineffective multi_corner file output.

#### Files Modified:

- sys/sys_top.v
- tools/phase1p_timing.tcl

#### Status:

- [x] Built
- [ ] Passed

---

## 009 COMMIT Unreleased 0710e81 2026-09-13T11:55:45-07:00

#### Coming From:

Unreleased 0710e81

#### Purpose:

Record partial hardware validation of loading-message suppression and the user's instruction to defer menu-access work.

#### Outcome:

At the user's explicit request, the timing-failing 0710e81 seed-87 RBF was provided for hardware testing while the corrected 07b8688 builds ran. It is retained at results/hardware-test-0710e81-seed87/MediaPlayer_20260913.rbf with SHA-256 ef3026b9b2e3eda03865c70a6df327b8002c510ac3b81ee04198dd8ae13b4d63 and a build-info.json marking setup -1.525 ns and timing_passed false. The user reported that the loading bar is gone, but pressing the menu button still cannot bring up the OSD during playback. This confirms the visual message-suppression behavior only; it does not establish interactive menu access. That remaining limitation is consistent with Main's blocking file-transfer loop and was identified in the approved proposal; preserving ordinary menu rendering in RTL does not make Main service the menu button during that loop. The user explicitly instructed leaving the behavior as-is for now and waiting for the three current timing results. Source 07b8688 adds only the subcarrier mailbox and its six audit stages and was committed and pushed before clean seeds 52, 61 and 87 began under results/build-07b8688-20260913-114641/. No Main or audio changes were made.

#### Next Steps:

Finish the three 07b8688 builds and their timing checks, including the fitted 60-register synchronizer audit and explicit operating-corner reports. Report the results and any passing candidate without further implementation changes; menu access during playback is deferred by the user's instruction.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 008 COMMIT Unreleased 0710e81 2026-09-13T11:44:14-07:00

#### Coming From:

Unreleased 0710e81

#### Purpose:

Record the completed timing-repair batch and identify the final shared subcarrier configuration crossing.

#### Outcome:

All three clean 0710e81 builds compiled and passed the fitted 54-register synchronizer audit. Seeds 52, 61 and 87 finished compilation and focused timing in 1052, 1176 and 1112 seconds, using 40441, 40540 and 40304 ALMs respectively; each used 472 RAM blocks and 69 DSP blocks. Setup remained -1.656, -1.702 and -1.525 ns, with the shared worst path from the system-clock subcarrier flag to video-clock subcarrier_out. All passed hold at +0.243, +0.241 and +0.238 ns, recovery at +3.790, +2.242 and +3.476 ns, removal at +0.418, +0.551 and +0.390 ns, and pulse width at +0.925 ns. Focused decoder setup was -0.237, +0.173 and +0.143 ns; HDMI setup was +0.013, +0.214 and +0.390 ns, while same-clock video setup was +16.635, +15.933 and +17.190 ns. Thus seeds 61 and 87 now fail only the remaining shared configuration crossing among the reported paths; seed 52 also has a smaller decoder setup violation. The old request, VS, LFB_EN, HDMI_PR and lowlat failures were removed. No new hardware candidate is timing-qualified. All reports, RBF hashes and regression evidence are retained under results/build-0710e81-20260913-112410/.

#### Next Steps:

Within the approved remaining-configuration-crossing repair scope, transfer subcarrier through the verified mailbox and extend the fitted audit to its six control stages. Verify the mailbox behavior, commit and push, then run clean seeds 52, 61 and 87 again. Require positive standard and focused timing before delivering the loading-overlay repair for hardware testing; audio remains unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 007 COMMIT Unreleased 0710e81 2026-09-13T11:24:43-07:00

#### Coming From:

Unreleased 9c6ccbb

#### Purpose:

Correct top-level synchronizer constraint matching before fitting the loading-overlay repair.

#### Outcome:

All three 9c6ccbb clean exports completed synthesis successfully in approximately 150 seconds, but inspection found the existing hierarchy-separator prefix excluded top-level VS registers and the new top-level mailboxes from timing exceptions. The three fitting jobs and their supervisor were terminated before completion; they produced no accepted build. A post-map TimeQuest audit reproduced rejection of the old platform_aspect_config pattern, then passed with the corrected patterns: all 54 required control registers were present, with eight request stage-zero endpoints, eight acknowledgement stage-zero endpoints, each VS stage-zero endpoint and 267 held/destination data bits matched. Source 0710e81 changes only constraint and audit patterns; the 9c6ccbb RTL regressions remain applicable. The correction was committed and pushed before restarting clean seeds 52, 61 and 87 with six workers each under results/build-0710e81-20260913-112410/. The prior batch and its cancellation record remain under results/build-9c6ccbb-20260913-111811/. No replacement RBF has been delivered or installed.

#### Next Steps:

Finish all three clean builds, require the fitted 54-register audit and standard and focused timing reports, then deliver a timing-passing candidate for user validation of loading-overlay suppression, video, audio and repeated loads. Preserve the hardware-accepted 1750154 seed-87 rollback reference and keep the earlier inaudible audio underrun outside this cycle as directed.

#### Files Modified:

- MediaPlayer.sdc
- tools/phase1p_timing.tcl

#### Status:

- [ ] Built
- [ ] Passed

---

## 006 COMMIT Unreleased 9c6ccbb 2026-09-13T11:04:15-07:00

#### Coming From:

Unreleased f8bebcd

#### Purpose:

Suppress the loading message during playback and repair synthesized video-configuration clock crossings.

#### Outcome:

Implemented playback-controlled suppression of Main message-mode OSD on HDMI and analog paths, preserving ordinary menu and info windows. The first scheduled display-frame swap latches playback state; reset or a new download clears it, and an acknowledged mailbox carries the state into the system clock before the OSD configuration mailboxes. Explicit OSD startup state makes the every-other-frame enable behavior reproducible in simulation. Configuration and VS synchronizers now disable shift-register RAM inference and preserve their registers. System aspect configuration is transferred as a held bundle, ASCAL receives separate input/output-clock mode snapshots, and HDMI framebuffer enable is synchronized. Focused timing extraction now requires all three stages of every configuration and VS synchronization chain to exist as registers. Full-raster compiled OSD simulation passes seven visibility cases and sync alignment, including zero loading-message pixels during playback and retained menu/info pixels. Raster reset, 345600-pixel cache scanout, mailbox, geometry, all five cadence rates, B-picture ordering and telemetry regressions pass. Timed MPG regression passes 24192 stereo sample pairs with maximum FFmpeg difference one sample unit, 152679 matching video bytes and 15 correct picture timestamps; its FIFO is ideal and full video reconstruction and physical CDC are outside that test. The user explicitly excluded the earlier inaudible audio underrun from this cycle; audio behavior is unchanged. Source 9c6ccbb was committed and pushed before launching three independent clean Quartus exports under results/build-9c6ccbb-20260913-111811/. Only fitter seed and worker count differ from committed project settings; seeds are 52, 61 and 87 with six workers each. New synthesis and timing results remain pending.

#### Next Steps:

Implement the reviewed changes, run focused OSD, mailbox, raster, cadence and playback regressions, commit and push the source, then run clean seeds 52, 61 and 87 with standard and focused timing reports. Deliver a timing-passing candidate for loading-overlay, flicker, audio and repeated-load hardware tests. Retain 1750154 seed 87 as the timing-passed and hardware-accepted rollback. Do not change audio behavior in this cycle.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- rtl/video_config_cdc.sv
- sys/ascal.vhd
- sys/emu_ports.vh
- sys/osd.v
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_osd_playback.sv
- tools/verify_video_sync.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 005 COMMIT Unreleased f8bebcd 2026-09-13T10:54:04-07:00

#### Coming From:

Unreleased f8bebcd

#### Purpose:

Record user acceptance of seed 52 playback and the freshly captured early audio-underrun telemetry.

#### Outcome:

The user confirmed that everything played perfectly and identified seed 52, accepting visual and audible playback for this test of f8bebcd. A fresh uniquely named screenshot captured over FTP from 10.10.0.45 at 2026-09-13T10:52:38-07:00 decoded successfully as schema eight. Its one-shot snapshot froze approximately 0.207309 seconds into the session on error_flags 0x1000, identifying MP2 underrun, with four audio frames decoded and 4608 stereo sample pairs played; MP2 decode and timestamp errors were clear at capture. This is an early error snapshot, not end-of-playback telemetry: sequence_end_seen, presentation_complete, audio_finished and session_quiet were false at that early point and do not establish failure to finish the user's test. The snapshot recorded 74207 accepted bytes, three displayed pictures and a 100.1 ms display gap. The screenshot and decoded JSON are retained in results/telemetry-20260913-105236/. User acceptance does not resolve the underrun or the seed's setup -2.173 ns, hold -0.104 ns and decoder setup -0.061 ns timing failures. Passed records the user's hardware acceptance only. The user identified the current agent environment as the build PC and instructed ignoring keyboard LED commands; the user subsequently explicitly authorized pushing from this build PC.

#### Next Steps:

Prepare the next timing-repair proposal around preserving real synchronization flip-flops, checking matched timing endpoints and completing the remaining configuration clock crossings, with a separate investigation of the early MP2 underrun. Retain 1750154 seed 87 as the timing-passed and hardware-accepted rollback. Commit and push this checkpoint from the build PC under the user's explicit authorization.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 004 COMMIT Unreleased f8bebcd 2026-09-13T10:35:05-07:00

#### Coming From:

Unreleased f8bebcd

#### Purpose:

Record the completed progressive-sync repair batch, remaining timing defects and the user's preliminary playback observation.

#### Outcome:

All three f8bebcd builds compiled and produced RBFs, but none passed timing. Seed 52 completed in 1431 seconds with setup -2.173 ns, hold -0.104 ns, decoder setup -0.061 ns and 40480 ALMs; seed 61 completed in 1834 seconds with setup -2.284 ns, hold +0.202 ns, decoder setup +0.442 ns and 40578 ALMs; seed 87 completed in 1669 seconds with setup -2.343 ns, hold +0.202 ns, decoder setup -0.476 ns and 40862 ALMs. All used 472 RAM blocks and 69 DSP blocks, and all passed recovery, removal and pulse-width checks. Same-clock video margins were +12.517, +11.337 and +11.794 ns respectively. Seed 52's detailed reports reveal that Quartus inferred RAM shift registers from newly added request and VS synchronization chains, causing first-stage register constraints to match nothing; its worst path is aspect_config request into an inferred shift RAM. Remaining direct platform configuration crossings include LFB_EN and HDMI_PR, while lowlat into ASCAL i_mode causes the hold failure. Thus the prior synchronization changes are incomplete in synthesized hardware despite passing RTL simulations. The user reports that audio and video look and sound good, but the tested seed and explicit disappearance of lingering-frame flicker have not been confirmed. Two screenshot commands over responsive FTP produced no capture within their polling windows, so current telemetry and the prior audio timestamp flag remain unverified. Detailed reports, RBF hashes, regression evidence and the preliminary user observation are stored under /home/vash/builds/f8bebcd-20260913-100007. No source changes or replacement builds were started while the user tests. Built records successful compilation only; Passed remains unchecked pending hardware acceptance.

#### Next Steps:

Let the user finish the current test and confirm the seed and flicker behavior, then obtain fresh telemetry when screenshot commands respond. Preserve actual flip-flop synchronization stages through synthesis, verify that constraints match their intended endpoints, and finish remaining configuration crossings before another timing batch; retain 1750154 seed 87 as the timing-passed and hardware-accepted rollback reference.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 003 COMMIT Unreleased f8bebcd 2026-09-13T09:59:54-07:00

#### Coming From:

Unreleased f960c0e

#### Purpose:

Repair progressive frame-switch sync glitches and the configuration clock crossings exposed by the 27 MHz raster.

#### Outcome:

The previous native-480p batch completed seeds 52 and 87 but failed setup at -2.395 ns and -3.249 ns; the user canceled seed 61, whose stopped fitter was terminated to finish cancellation. Same-clock video setup remained +17.460 ns and +16.964 ns: the major failures were 20-to-27 MHz OSD configuration and cfg_done gating the HDMI adjuster's video clock, with additional aspect and VS crossings. Seed 52 also missed decoder setup by 0.208 ns, while seed 87 passed that path by 0.503 ns. The user reported generally good audio/video but lingering, flickering blended frames and unavailable OSD during playback, so f960c0e is not hardware accepted. The captured telemetry froze early on audio timestamp_error 0x2000 and is not an end-of-playback result; that separate flag is unresolved. Committed fixes keep HS/VS/DE free-running across frame-bank cache resets, transfer slow OSD/aspect settings through held acknowledged mailboxes, resynchronize system-clock VS edge detection, remove cfg_done gating of the actual HDMI-adjuster input clock, and align telemetry coordinates with framebuffer RGB/DE. The new reset regression fails on f960c0e and passes with the fix while checking all 345600 visible pixels with stalled DDR. The 20/27 MHz mailbox regression verifies atomic updates, source hold and final convergence; OSD elaboration, geometry, all five cadence rates, B-picture ordering and telemetry RTL also pass. Simulations use an ideal cache RAM and do not establish physical timing, full decoder reconstruction or HDMI scaler behavior. The accepted 1750154 seed-87 RBF remains the rollback reference.

#### Next Steps:

Run three clean Quartus seeds from the committed fixes, verify standard and focused timing and configuration synchronizer constraints, and compare resource use. Test HDMI for continuous frame changes, retained images, audio sync and OSD behavior; capture fresh telemetry to distinguish the remaining timestamp flag from this raster fix.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_luma_framebuffer.sv
- sys/osd.v
- sys/sys_top.v
- tools/test_480p_scanout.sv
- rtl/video_config_cdc.sv
- tools/test_video_config_cdc.sv
- tools/verify_video_sync.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 002 COMMIT Unreleased f960c0e 2026-09-13T09:12:17-07:00

#### Coming From:

Unreleased 1750154

#### Purpose:

Restore native 720x480 progressive output while retaining the hardware-accepted I/P/B decoder, FPGA MP2 audio and screen telemetry.

#### Outcome:

The user accepted 1750154 seed 87 and authorized continuing the progressive output plan. That baseline passed setup +0.257 ns, hold +0.248 ns, recovery +3.716 ns, removal +0.641 ns and pulse +1.122 ns, using 40132 ALMs and 470 RAM blocks; seed 61 also passed timing, while seed 52's fitter exited unexpectedly with Quartus error 293007. This cycle reuses progressive raster geometry and centered-picture policy from b3626a6 without importing its interlace or helper architecture. Prepared changes select a 27 MHz pixel clock, 858x525 total raster with 720x480 active pixels at 60000/1001 Hz, negative sync, a 480-line blanking swap boundary and exact fallback cadence ratios. Decoder and MP2 clocks remain unchanged. A full raster/cache simulation verifies all 345600 visible pixels with varied DDR stalls and two-stage DE/sync alignment; centered geometry and scheduler regressions pass all five frame rates, B reordering, timestamp waits, terminal draining and ownership cases. Exact 30 fps requires occasional adjacent refreshes because it exceeds half the output refresh rate. Schema-eight telemetry moves to line 312; its RTL regression passes, and the Python decoder round-trips native and prior SVGA layouts. Original aspect follows 4:3 versus default 16:9 sequence signalling. Direct analog is progressive 480p/31 kHz, not a newly implemented 15 kHz mode. Static timing and hardware validation of these prepared changes remain pending.

#### Next Steps:

Changes are committed; run three clean Quartus seeds and require all standard and focused timing reports including the new 27 MHz video clock and HDMI scaler. Preserve the accepted 1750154 seed-87 RBF, compare frame edges, aspect and audio synchronization on hardware, and revisit the previously recorded video cadence outlier using retained telemetry.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- README.md
- files.qip
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_progressive_geometry.sv
- rtl/mpeg2_video_720x480p.sv
- rtl/pll/pll_0002.v
- tools/phase1p_timing.tcl
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/test_480p_scanout.sv
- tools/test_mpeg2_progressive_framebuffer.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 001 COMMIT Unreleased 1750154 2026-09-13T08:38:36-07:00

#### Coming From:

Unreleased ace6b7b

#### Purpose:

Reduce FPGA resource pressure by removing legacy LED diagnostics, disabling Linux ALSA and limiting ASCAL image width to 2048 while retaining screen telemetry and core-generated MP2 audio.

#### Outcome:

The user authorized these changes and three builds. Prior source ace6b7b completed all seeds: 52 used 40671 ALMs with setup -0.307 ns, 61 used 40841 ALMs with setup -0.145 ns and hold -0.057 ns, and 87 used 40711 ALMs with setup -0.131 ns. None passed static timing. The user accepted seed 87 playback with synchronized flash/beep audio; captured schema-8 telemetry confirmed 1250 MP2 frames, exactly 1440000 stereo sample pairs, quiet completion and zero error flags, underruns or audio timestamp errors. One 106.62245 ms video gap was recorded. Detailed timing confirms ASCAL horizontal pixel and line-buffer paths dominate seeds 52 and 61; history records that retiming the extended-resolution read mux worsened RAM inference, so the approved 2048-width bound will remove its extension requirement instead. The cleanup reuses the LED removal from 391baa4 and existing MISTER_DISABLE_ALSA option, with explicit zero ties for inactive sample and DDR request inputs. Playback and telemetry RTL remain unchanged; packing remains MEDIUM. The standalone PCM sink regression passed 2304 samples in each of normal and wrapping timestamp sessions, and a source audit found no external consumers of the removed blink signals.

#### Next Steps:

Changes are committed. Inspect synthesis for removal of ALSA, LED diagnostics and extended-width scaler storage, then run clean seeds 87, 52 and 61 with standard and focused timing reports including HDMI setup and global hold. Compare fitted resources with ace6b7b and require new hardware playback validation; preserve the prior user-tested RBF.

#### Files Modified:

- MediaPlayer_top_07.svh
- MediaPlayer.qsf
- sys/sys_top.v
- tools/phase1p_timing.tcl
- README.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 999 COMMIT Unreleased ace6b7b 2026-09-13T07:53:13-07:00

#### Coming From:

Unreleased 9fd1829

#### Purpose:

Separate the registered reference-cache response word for the P and B prediction engines to repair the MP2 candidate's localized video routing failure.

#### Outcome:

The user requested stopping the two remaining Quartus builds and implementing the proposed handoff fix. Source 9fd1829 seed 87 compiled and completed focused timing in 1471 seconds, using 40824 ALMs, 55768 registers, 474 RAM blocks and 69 DSP blocks, but it is not timing-qualified: setup is -0.354 ns with four violations from shared_engine_dout_q[32] to B-fetcher word_data slots 11, 16, 4 and 24, totaling -0.745 ns. Other standard slacks are hold +0.245 ns, recovery +3.449 ns, removal +0.528 ns and pulse +1.122 ns; focused video setup is +7.825 ns and decoder recovery +9.400 ns. Seeds 52 and 61 were canceled by the user's instruction after 1952 seconds, and both process groups were confirmed exited. The prior handoff registration in ebf372e documents the same routing-dominated topology; this change will keep its one-cycle response latency and ownership rule while giving each consumer an independent data register. No RBF from this batch is recommended for hardware testing.
 The implemented response_handoff module now retains independent owner-enabled 64-bit registers for mixed-P and B delivery, with dont_merge attributes to preserve that separation. The existing owned-valid pulses and one-cycle response latency are unchanged. A 10000-cycle simulation matches the prior handoff's observable data/valid behavior with 1849 mixed responses, 3668 B responses, 3692 ownership changes and reset every 127 cycles. The existing four-transaction, six-phase, 88-word fetcher regression passes immediate and delayed response, backpressure, simultaneous acceptance/response and invalid-footprint cases; the new module also passes Verilator lint without warnings. Full timing qualification of the fix remains pending.

#### Next Steps:

Run clean builds with seeds 52, 61 and 87 from this committed source, using seed 87 as the direct comparison against the prior routing failure. Require all standard and focused timing classes to pass before delivering a candidate for audible synchronized MPG playback and telemetry validation on hardware.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_reference_response_handoff.sv
- files.qip
- tools/streams/tb_h262_reference_response_handoff.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 998 COMMIT Unreleased 9fd1829 2026-09-13T07:17:37-07:00

#### Coming From:

Unreleased 9233f07

#### Purpose:

Add FPGA MPEG-1 Layer II audio decoding and synchronized progressive MPG playback on the accepted seed-52 video baseline.

#### Outcome:

Implemented 48 kHz stereo/dual/joint-stereo MP2 at 112–384 kb/s with a bounded frame parser, serial requantization and polyphase synthesis, an independent compressed-video DDR ring, ordered PES metadata binding, PCM timestamp scheduling and schema-eight audio telemetry. Stock Main and the accepted progressive decoder/output raster remain; raw video bypasses the new DDR queue. CRC-protected frames, other rates/codecs, mono and timestamp-discontinuity recovery are not supported by this first audio profile. All 17 quantizers and all joint-stereo bounds pass FFmpeg comparison after increasing requantization coefficients from Q24 to Q30; eight quality fixtures pass two reset-separated, backpressured sessions with maximum PCM error 0–2 sample units, and six unsupported/truncated fixtures fail explicitly. A timed MPG test plays 24192 sample pairs from 21 frames without underrun or timestamp error, agrees with FFmpeg PCM within one unit, preserves 152679 video bytes and binds all 15 picture timestamps correctly. That harness models a bounded PCM FIFO and does not claim complete H.262 or vendor CDC simulation. DDR stress passes 5000 words with 8014 competing responses; legacy arbiter, raw/PS ingress, PCM baseline, PES split-prefix and telemetry checks pass. An early synthesis estimate fits at 38562 ALMs and 68 DSP elements before the final precision/telemetry changes, but full build/timing qualification is pending. Sources are installed from the isolated development export; no hardware acceptance is claimed.

#### Next Steps:

Push this source and run independent clean Quartus builds with seeds 52, 61 and 87, reviewing standard and focused timing before delivering RBFs. Provide the executable flash/beep and movie-content generator, then require audible synchronized MPG playback, exact audio completion counters, repeated raw/MPG loads and a longer-file synchronization test on hardware. Native progressive 720x480 output follows audio acceptance.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/av_stream_fifo.sv
- rtl/audio/mp2_cos.hex
- rtl/audio/mp2_decoder.sv
- rtl/audio/mp2_pcm_fifo.sv
- rtl/audio/mp2_pcm_output.sv
- rtl/audio/mp2_scale.hex
- rtl/audio/mp2_synthesis.sv
- rtl/audio/mp2_window.hex
- rtl/mpeg2_new/mpeg2_av_ddr_fifo.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_pes_metadata_expand.sv
- rtl/mpeg2_new/mpeg2_pes_picture_pts.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/generate_mp2_tables.py
- tools/make_mpg_audio_test.sh
- tools/mp2_fixtures.py
- tools/mp2_model.py
- tools/reference/LICENSE.pl_mpeg
- tools/reference/README.md
- tools/reference/pl_mpeg.h
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_ddram_arbiter.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/test_av_ddr_fifo.sv
- tools/test_mp2_decoder.sv
- tools/test_mp2_pcm_output.sv
- tools/test_mp2_synthesis.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/test_pes_picture_pts.sv
- tools/verify_mp2.py
- tools/verify_mpg_audio.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 997 COMMIT Unreleased 9233f07 2026-09-13T06:31:16-07:00

#### Coming From:

Unreleased 9233f07

#### Purpose:

Record user acceptance and independently decoded screen telemetry for the seed-52 progressive MPG video candidate.

#### Outcome:

The user explicitly confirmed seed 52 and the file generated by make-mpg-test.sh played perfectly. A fresh launch-free FTP screenshot from MiSTer 10.10.0.45 decodes with valid schema-seven row framing, parity and checksum, error_flags zero, sequence_end_seen true, presentation_complete true and session_quiet true; terminal decode, reorder, scratch, reference, frame, promotion and boundary pending flags and both holds are clear. FFmpeg independently counts 900 video frames in /run/media/vash/GIT/test_progressive_mpg.mpg: 38 I, 263 P and 599 B. The hardware's eight-bit display/reference/B values 132, 45 and 87 match 900, 301 and 599 modulo 256, respectively; its displayed 4.36 delivered_fps calculation uses wrapped counts and is not a real low-frame-rate measurement. Hardware accepted_bytes is exactly 1151356, matching the independently extracted 1151352 elementary bytes plus the inserted four-byte video sequence end, which the muxed file lacked. The snapshot spans 30.0143479 seconds between first and last presentation with zero cadence outliers. This accepts the single generated MPG video test with the user's visual confirmation; it does not claim separate raw/reload/long-file checks or movie audio. The user identifies seed 52; the loaded hardware RBF hash was not independently retrieved. Evidence is retained in /home/vash/builds/9233f07-20260913-055946/hardware-acceptance.json and its referenced PNG, while the accepted candidate hash remains b3cf7bca197820e295a309ad86f446b55c8398dfa822f428dad0ae17aec739a5.

#### Next Steps:

Proceed to the approved FPGA MP2 decoding and A/V synchronization stage using this accepted progressive video boundary, retaining stock Main and the existing output raster. Reuse historical PCM output and buffer findings, but implement compressed audio in the core and associate PES timestamps with their correct pictures/audio samples. Native progressive 720x480 output follows working synchronized MPG playback; interlace, Bob/Weave, DVD, helpers and modified Main remain outside scope.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 996 COMMIT Unreleased 9233f07 2026-09-13T06:25:18-07:00

#### Coming From:

Unreleased 9233f07

#### Purpose:

Record the clean three-seed progressive MPG ingress build batch and its delivered hardware candidates.

#### Outcome:

Source 9233f07 was pushed and built in three independent tracked-source exports using Quartus Lite 17.0.2 Build 602 with seeds 11, 33 and 52, with no input differences beyond the intended fitter seeds. Seed 11 completed compilation and focused timing in 1177 seconds with setup +0.288 ns, hold +0.257 ns, recovery +4.168 ns, removal +0.649 ns, pulse width +1.122 ns, decoder same-clock setup +0.437 ns and video same-clock setup +7.883 ns; its 4276012-byte RBF SHA-256 is f25ed4dea6d0e3e6a10d562cfb6dfb7c3d1c3ce4c3d10c2f1f09a72a9c623e6d. Seed 52 completed compilation and focused timing in 1223 seconds despite routing-congestion warnings, with setup +0.510 ns, hold +0.224 ns, recovery +4.280 ns, removal +0.494 ns, pulse width +1.122 ns, decoder setup +1.122 ns and video setup +7.076 ns; its 4205152-byte RBF SHA-256 is b3cf7bca197820e295a309ad86f446b55c8398dfa822f428dad0ae17aec739a5. Seed 33 remained in congested routing and was terminated at the user's explicit request after 1388 seconds; the process group and supervisor were confirmed exited, so it is canceled rather than timing-qualified. Seed 11 uses 36344 ALMs, 52992 registers, 410 RAM blocks and 65 DSP blocks. Reports, checksums and both named RBFs are retained under /home/vash/builds/9233f07-20260913-055946. The user could not copy the supplied FFmpeg command, so an executable script was saved at /home/vash/Downloads/make-mpg-test.sh; a one-second encode verified its progressive 720x480 30000/1001 video and 48 kHz stereo 192 kb/s MP2 output. The script generates a 30-second test_progressive_mpg.mpg on the GIT drive. Changelog text was reconciled without changing the built runtime source.

#### Next Steps:

The user should load either passing candidate with stock Main and Audio test Off, repeat the accepted raw control, then require silent MPG video playback, terminal-picture completion and repeated raw/MPG reloads. Seed 52 has the larger measured setup margin, while seed 11 was already offered as a valid candidate. Capture any failure against the exact file and source rather than attributing it to the old DVD architecture. Only after this ingress stage is hardware-accepted should FPGA MP2 decode and A/V synchronization begin, followed by progressive 720x480 output.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

