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

## 995 COMMIT Unreleased 9233f07 2026-09-13T05:59:28-07:00

#### Coming From:

Unreleased 8b6ed49

#### Purpose:

Restore progressive stock-Main file playback on the hardware-accepted a57079f baseline with MPEG Program Stream video ingress.

#### Outcome:

The user accepted the rebuilt a57079f seed-11 RBF on hardware and approved restoring MPG demultiplexing, then FPGA MP2 decoding and A/V synchronization, then progressive 720x480 output, with interlace, Bob/Weave, DVD and helper/custom-Main dependencies out of scope. The original three-seed rebuild passed standard and focused timing for seeds 11 and 33; seed 26 was stopped at the user's request. Seed 11 has +0.441 ns worst setup and is a new build, not a claim of byte-identical historical reproduction. Earlier recovery incorrectly described a57079f as retaining a Program Stream demux; commit 3771f19 had removed it, and the stale README caused that error. The candidate returns runtime sources to a57079f while preserving Git history and current project-control memory. It recovers the demux from 3713581, fixes held-output backpressure, selects the first video/audio IDs, detects raw versus Program Stream input, skips audio in this stage, and appends a missing video sequence-end only after Program Stream EOF drains. Raw private metadata and encoded cadence remain; direct PES-to-picture timestamp binding is deferred to A/V integration. Deterministic and real-file Icarus tests pass, including 4675731 real video bytes matching FFmpeg under randomized stalls and repeated sessions; baseline metadata and PCM verification also pass. Source changes are prepared for installation and a fresh three-seed Quartus batch. This build PC hosts the project at /run/media/vash/GIT/MiSTer-Media-Player and the test MiSTer is 10.10.0.45.

#### Next Steps:

Commit the reviewed candidate as a new master revision, build independent tracked-source exports with seeds 11, 33 and 52, review standard and focused timing, and deliver a passing RBF plus a short progressive MPG/MP2 conversion command. The user will test raw regression, silent MPG video, EOF and repeated loads before MP2 implementation starts. Reuse historical implementations and their failure evidence where appropriate without reintroducing the old architecture.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/test_program_stream_demux.sv
- tools/test_program_stream_ingress.sv
- tools/verify_program_stream_ingress.py
- tools/build.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 994 STATUS Unreleased 8b6ed49 2026-09-13T05:05:48-07:00

#### Coming From:

Unreleased 8b6ed49

#### Purpose:

Record a session-ending status checkpoint: where the wide-motion RTL investigation stands, and a new, separate finding about stock Main compatibility that changed direction mid-session. No source changes in this entry.

#### Outcome:

Entry 993's build (seed99, +0.267ns margin) let the file advance from ~143590 to 171634 bytes before stalling again, same real-backpressure `credit=0` symptom. Fresh telemetry showed the fix had zero effect on this particular stall (`stall_diag_p_hold_raw`/`stall_diag_p_hold_effective` still latched, identical byte offset both before and after entry 993's build) - meaning entry 993's fix, while a real and independently-verified bug (same probe_error/parse_hold-pairing defect as entry 992, confirmed by direct code comparison), was not the cause of *this specific* occurrence. Traced further: this module's row-management logic (`mpeg2_h262_p_wide_motion_syntax_probe_part2.svh`) mirrors the B-core probe's row_retired/outstanding_rows pattern exactly, and `row_retired` (`p_row_persistence_complete`, ultimately `mpeg2_h262_reference_pipeline_probe_rearm.sv`'s `row_persisted`) appears to have no engagement path for "wide" mode specifically - that module's engine-select logic (`b_select`/`mixed_select`) has no awareness of `wide_mode` by name. Investigated whether wide-mode output reaches the shared `p_forward_vector_valid`/`p_residual_sample_valid` ports the engine-select watches (it does, via `wide_mode`-branched assigns) and definitively ruled out `p_implicit_reconstruct_request` as the exclusion cause for wide mode too (`p_forward_vector_valid` and `p_residual_sample_valid` are the literal same signal, `wide_sideband_valid`, when `wide_mode=1`, so `!p_forward_vector_valid` cannot be true at the exact moment the marker-pulse condition is checked - proven by direct signal-equality, not inferred). No confirmed root cause yet for why wide-mode rows never get persistence credit; two hypotheses have now been ruled out by code-level proof (this is the second dead end from pure code-tracing this session, after the earlier B-side implicit-reconstruct lead), so further progress needs either a proper Icarus reproduction of the engine-select logic in isolation, or live hardware signal capture, not more inference from reading.

Mid-investigation, the user asked whether the modified Main/helper could be the actual cause instead of RTL, given the project's stated goal of eventually removing them entirely. This led to a significant, evidence-backed detour: confirmed `user_io_file_tx_data_step`/`media_burst_*` (the whole non-blocking bulk-transfer mechanism `plain_video_poll()` relies on) is custom code this project wrote in `host/main_mister/0001-mediaplayer-arm-loader.patch`, not a stock MiSTer primitive - grepping pristine `user_io.cpp` at the pinned commit finds zero occurrences. Verified the demux is not a source of corruption: extracted the same real file bytes' video elementary stream two independent ways (our RTL demux run under Icarus, and `ffmpeg` as a trusted reference) and diffed them byte-for-byte identical (`cmp` exit 0) across the whole region covering the stall point; `ffprobe` confirms the file is completely standard MPEG-2 Main Profile @ Main Level, 720x480 - the "wide motion" content is genuine, not corruption-induced. Built and tested genuinely stock, unpatched Main (cloned fresh from the pinned commit, zero of the four patches applied) with a short 8MB truncated test file, loaded via the standard F4 menu (MediaPlayer.sv's CONF_STR already declares this generically, no custom C++ required for basic routing) - and found a new, different, more severe hang: Main spins at ~50% CPU in userspace (`R` state, `wchan=0`, confirmed via `/proc/<pid>/io` showing zero rchar/wchar growth across repeated checks) with no forward progress at all, far earlier than where the custom-Main build got stuck. Ruled out several hypotheses for this by direct evidence: `ioctl_file_ext` is exposed by `hps_io.sv` but never read anywhere in `MediaPlayer.sv` (extension mismatch impossible); the `MEDIA_BURST` additions to this project's local `sys/hps_io.sv` copy (commit a4f2769) are purely additive - a new opt-in parameter defaulting to 0, a new command gated behind it - and do not touch the base FIO_FILE_TX_DAT/ioctl_download protocol at all; `mpeg2_stream_fifo`'s `burst_ready` settle-timer only needs ~63 cycles (microseconds) to clear, far too fast to explain a multi-minute hang on its own. No live debugging tools are available on-device (no strace, no way to get a stack trace), and no confirmed root cause was reached before the user asked to stop for this session. Notably, neither the old ARM-helper architecture nor this session's patch 0004 ever exercised the plain/non-burst transfer path successfully before - both always used the burst-aware mechanism - so this exact combination (stock Main + this FPGA core, no burst negotiation at all) may never have been tested in this project's history until now.

#### Next Steps:

Device state: the user deleted both the custom `MiSTer_MediaPlayer` binary and the ARM helper from `/media/fat/`, then rebooted; only stock `/media/fat/MiSTer` remains, running with the seed99 RBF (entries 992/993's fixes). The stock-Main hang was last observed live and may still be running in that state - check on resume. This is a decisive change of direction: the user wants to commit to stock Main going forward (matching the project's stated eventual goal of removing the custom Main/helper entirely) rather than continue developing patch 0004. That means the wide-motion RTL investigation, while still open, is now secondary to first getting the plain file-load protocol working with genuinely stock Main - there is no point fixing the wide-motion persistence gap if the file cannot even begin transferring under the architecture the user now wants to use. When resuming: get live diagnostic visibility into what `ioctl_download`/`session_start`/`mpeg2_burst_ready` actually do under a plain, non-burst stock Main transfer (the user was mid-way through choosing how to gather this evidence, favoring a purely diagnostic use of the custom Main build to get the data, with the fix itself implemented in RTL only) - do not add custom Main C++ back as the shipped solution regardless of what the diagnostic step uses to gather data.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 993 COMMIT Unreleased 8b6ed49 2026-09-13T04:12:53-07:00

#### Coming From:

Unreleased 2f413b4

#### Purpose:

Fix the same parse_hold-not-cleared-on-error bug found again, this time in the P-side wide-motion probe, after entry 992's B-side fix let the file progress further.

#### Outcome:

Deployed entry 992's build (seed99, +0.434ns margin) and asked the user to reload. Real progress: `sent` advanced from ~143590 to 171634 bytes before stalling again with the same `credit=0` real-backpressure symptom, confirming entry 992's fix genuinely works - it just wasn't the last blocker in this file. Fresh telemetry showed `stall_diag_b_parse_hold=False` now (fixed) but `stall_diag_p_hold_raw`/`stall_diag_p_hold_effective=True` - a different sub-module, `mpeg2_h262_p_diagnostic_controller_rearm.sv`'s `wide_parse_hold`, one of `stream_hold`'s four OR-terms. Ruled out the other three: `four_mb_parse_hold` and `legacy_parse_hold` are both hardwired to `1'b0` (dead code), and `raster_hold_active` has its own ~0.28-second timeout safety net already built in (`raster_hold_timeout<=24'hffffff`), so it could not still be stuck after the diagnostic's 3-second arm delay. Comparing `mpeg2_h262_p_wide_motion_syntax_probe_part3.svh`'s eight `probe_error<=1` sites against entry 992's exact bug pattern found the identical defect: six sites correctly pair `probe_error<=1` with `parse_hold<=0` (matching every `parser_error` site in the B-core probe), but two sites (both `probe_error_detail=30`, in the slice-continuation-classification branch) do not. Source `8b6ed49` adds the same one-line unconditional statement entry 992 used, outside the `if(stream_valid)` gate for the identical reason (no further bytes ever arrive once `stream_hold` has blocked `stream_ready`): whenever `probe_error` is set, clear `parse_hold`. `quartus_map` on seed99 is clean, 0 errors, same warning count. No new Icarus reproduction attempted (same reasoning as entry 992 - this module's own sequencing preconditions aren't fully understood by a narrow isolated harness); rests on real hardware evidence plus the already-verified code pattern.

#### Next Steps:

Sync to all three seed build directories, run the full timing build, deploy the best-passing seed, and ask the user to reload the file. Given the pattern established across entries 986/990/992/993 (each fix uncovers real forward progress into a new, distinct stuck point rather than fully unblocking playback), pull fresh telemetry immediately on any further stall rather than assuming completion or the same cause; if `stall_diag_valid` shows all of `parser_ready`/`p_hold_effective`/`b_parse_hold`/`b_persistence_wait` clear, the stall has moved to a mechanism outside this stall-diagnostic bundle entirely (widen the diagnostic's coverage, or check `mpeg2_new_stream_ready`'s own `mpeg2_download_rearm_reset` term and both top-level holds again fresh) rather than re-checking the same four bits. If the file reaches a point where video actually displays, that is the first real milestone this stall-hunting chain has been working toward - confirm playback continues past the point of a full picture, not just single-frame progress.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 992 COMMIT Unreleased 2f413b4 2026-09-13T03:48:42-07:00

#### Coming From:

Unreleased 14af685

#### Purpose:

Fix the actual stall entry 991's live diagnostic pinpointed: parse_hold stuck inside mpeg2_h262_b_core_probe, not either hold already fixed this session.

#### Outcome:

Deployed entry 991's stall-diagnostic build (seed33, +0.039ns margin) and asked the user to reload and let it stall past the 3-second arm threshold. `stall_diag_valid=true` with `stall_diag_b_parse_hold=true`, `stall_diag_b_candidate=true`, `stall_diag_b_error=true`, `stall_diag_b_seen=false`, `stall_diag_b_picture_inflight=false`, all other flags (parser_ready=true, p_hold_raw/p_hold_effective=false, b_persistence_wait=false) clear - decoder_stream_ready held low purely by mpeg2_h262_b_core_probe's own parse_hold, not by anything entries 986 or 990 touched. Traced the module (spread across mpeg2_h262_b_core_probe_part0-5.svh) and found parse_hold's only release paths are the row-completion state (R_FINISH) receiving external row_retired credit, or a fresh slice start reaching a rearm branch at the bottom of the FSM. Several `replay_error` assignment sites set the module's error output without also clearing parse_hold, unlike the `parser_error` sites, which consistently pair the two. If parse_hold is already asserted (waiting on row_retired) when one of these fires, nothing clears it: row_retired's only source is a downstream B-prediction engine (`mpeg2_h262_reference_pipeline_probe_rearm.sv`) that itself only activates via `b_motion_transport` from this same module - a signal needing the forward progress parse_hold is blocking. Worse, the rearm branch that could otherwise recover sits inside a `stream_valid`-gated block, which never fires again once stream_ready (derived from parse_hold) has gone permanently low - no further bytes ever arrive to reach it. Source `2f413b4` adds one unconditional statement at the very end of the module's always block, deliberately outside the stream_valid gate so it keeps evaluating with no new bytes arriving: whenever `parser_error`, `replay_error` or `prior_error` is latched, clear `parse_hold`. Matches this module's own stated design intent ("a failed B parser/replay transaction must never retain ownership of the compressed-stream path") and the identical recovery pattern the wrapper already applies one layer up for `b_picture_inflight`/`b_persistence_verified` on `b_error`. Attempted an Icarus reproduction feeding the real file's demuxed bytes directly into this module in isolation; it never left its idle state for reasons not fully understood (likely a sequencing precondition the narrow harness didn't model), so the reproduction was inconclusive and the exploratory testbench was not committed - this fix rests on the real hardware diagnostic's precise bit-level evidence plus the code-level tracing above, not a verified simulation. `quartus_map` on seed99 is clean, 0 errors, same warning count, negligible logic change.

#### Next Steps:

Sync to all three seed build directories, run the full timing build (margins have been thin the last two cycles - seed99 alone passed at +0.001ns two cycles ago, then failed entirely last cycle while seed26/seed33 passed near +0.01-0.04ns; watch for the possibility that none pass this time and a margin-recovery pass becomes necessary before any further hardware test), deploy the best-passing seed, and ask the user to reload the file. If `mpeg2_new_decoder_stream_ready` still stalls, pull fresh telemetry - `stall_diag_valid`/`stall_diag_b_parse_hold` should now read differently (either clear, confirming the fix, or the stall should shift to a new signal, which would mean this fix was necessary but not sufficient and the next blocker needs identifying from fresh evidence, not assumed to be a variant of this one). If decode proceeds past this point, watch for whether video actually starts displaying, since this is the first fix in this whole session that touches the path required to reach a first real picture at all.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 991 COMMIT Unreleased 14af685 2026-09-13T03:08:33-07:00

#### Coming From:

Unreleased 03b033f

#### Purpose:

Get precise live evidence of what is actually blocking decode, instead of continuing to guess from code reading after entry 990's targeted fix retested unchanged.

#### Outcome:

Deployed entry 990's build (seed99, only passing seed this cycle at a razor-thin +0.001ns margin; seed26/33/40/7/52 all failed timing) and asked the user to reload. Same symptom: `sent` frozen near 143588 bytes, `credit=0` held for 670,000+ poll cycles - functionally identical to the pre-990 stall. Rather than assume the fix was ineffective, pulled fresh telemetry and compared its *live* counter fields (decoder_stall_cycles, presentation_stall_cycles, destination_stall_cycles, b_stall_cycles - these keep incrementing until the one-shot arms, unlike the frozen scheduler_flags/error_flags fields) against a second screenshot: `presentation_stall_cycles` totaled only ~2.8M cycles and `destination_stall_cycles` was exactly 0 across the whole ~30-second session, while `decoder_stall_cycles`/`b_stall_cycles` accounted for nearly all of it (~1.79-1.8 billion cycles, matching the corner telemetry's 30-second no-commit fallback arm). This proves neither hold this session fixed (entry 986's `b_presentation_hold`, entry 990's `p_destination_ownership_hold`) has been the dominant blocker - both fixes are real and correct, but something else, further upstream, has actually been stalling decode almost since the start. That points at `mpeg2_new_decoder_stream_ready` itself, the picture bookkeeper's own `stream_ready` output in `mpeg2_h262_two_picture_probe_p_chain.sv`, gated by its internal `parser_ready`/`p_hold_effective`/`b_parse_hold`/`b_persistence_wait` terms. Traced one candidate (`p_implicit_reconstruct_request` disqualifying the persistence-tracking engine select) by code reading alone and found it was a dead end - implicit-reconstruct macroblocks complete through a separate signal (`reconstructed_seen`), not `persisted_seen`. Rather than keep guessing, asked the user how to proceed; they chose building a live diagnostic. Source `14af685` bundles the four gating terms plus their own sub-signals (`b_picture_inflight`, `b_seen`, `b_persistence_verified`, `b_error`, `b_candidate`, `b_transport`, `p_error_raw` - 12 bits total) into a new `stall_probe_debug` output from the bookkeeper, and adds a small one-shot capture in `MediaPlayer.sv` (mirroring this project's established armed-once-per-session pattern, not a live/continuously-updating signal, to avoid the CDC/timing risk that got the earlier `mpeg2_h262_live_deadlock_probe` removed) that arms after ~3 seconds of sustained real stall and latches that bundle plus `stream_ready`, both top-level holds, and the active/display frame banks. Published as corner-telemetry snapshot word 58, replacing a hardwired zero confirmed unused in this build's `DEADLINE_DIAGNOSTICS=1` configuration (the python decoder's only reads of words 58-62 are gated at schema versions this build's `SNAPSHOT_FORMAT` never reaches). `tools/test_telemetry_visibility.sv` (the profiler's existing regression) and `tools/test_two_picture_probe_abandon.sv` (entry 990's regression) both still pass unchanged against the real modules. `quartus_map` on seed99 is clean, 0 errors, same warning count; logic cells rose modestly (88426->88692), consistent with one new counter/register/comparator, not a structural change.

#### Next Steps:

Sync to all seed build directories and run the full timing build - given entry 990's cycle already left only one of six seeds passing (seed99, +0.001ns), this addition's extra logic may push even that seed over the edge; if all six fail, that needs its own resolution before any further hardware test. Once a passing seed deploys, ask the user to reload the file, let it run past 3 seconds of stall, and pull fresh telemetry - `stall_diag_valid` true means word 58 has real content; decode `stall_diag_*` to see exactly which of parser_ready/p_hold_effective/b_parse_hold/b_persistence_wait (and their own sub-terms) is false, and fix that specific mechanism next instead of the two already-fixed holds.

#### Files Modified:

- MediaPlayer.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/decode-hardware-telemetry.py
- tools/test_telemetry_visibility.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 990 COMMIT Unreleased 03b033f 2026-09-13T02:28:44-07:00

#### Coming From:

Unreleased 2967e0b

#### Purpose:

Fix the third deadlock hardware testing surfaced after entries 986/988/989's fixes shipped: a frozen bank in the picture bookkeeper, not the scheduler or the transport gate.

#### Outcome:

Deployed entry 989's build and asked the user to reload the file again. Fresh telemetry confirmed `presentation_hold=False` throughout (all three earlier fixes are genuinely working - no more indefinite hold, no more fatal-latch drain), but a fresh Main log pull showed `sent` frozen at 143590 bytes with `credit=0` held for 670,000+ poll cycles - real FIFO backpressure this time, not the old unthrottled drain, and a much earlier, smaller failure point than before. Traced it by direct code reading, no simulation needed to find the mechanism (though Icarus reproduction was still used to verify the fix before any hardware build): entry 986's abort deliberately abandons the in-flight overlap reference picture mid-decode, so `picture_420_complete`/`p_persistence_complete` never pulse for it. The separate picture bookkeeper inside `mpeg2_h262_two_picture_probe_p_chain.sv` only advances its own `active_frame_bank_reg` on those same completion pulses, so it freezes on the abandoned picture's bank forever - nothing else in that module resets or advances it. The very next real picture header is then classified by `MediaPlayer.sv`'s separate P-destination-ownership-hold watcher (Commit 162) against that frozen bank; since nothing has moved display since the abort, it very likely collides, latching a hold that can only release once display moves to a new bank - which requires a new picture to decode and get promoted, which requires `stream_ready`, which this same hold blocks. A genuine third circular wait, confirmed in the code before writing any fix. Source `03b033f` adds a new one-cycle pulse output, `overlap_reference_abandoned`, fired by the scheduler in the same cycle as its entry-986 abort, wired into the bookkeeper to advance `active_frame_bank_reg` exactly as a real completion would (the same 0->1->2->0 rotation) while deliberately leaving `completed_frame_bank_reg`, `picture_count_reg`, `reference_frame_valid_reg`, `reference_frame_bank_reg` and `reference_promotion_count_reg` untouched, since this picture was never actually reconstructed and must never be published as a usable reference - only the one frozen value the ownership-hold check reads is corrected. Two testbenches verify this: `tools/test_two_picture_probe_abandon.sv` (new) drives the bookkeeper in isolation and confirms three abandon pulses wrap the bank 0->1->2->0 while every reference/publication field stays at reset, and that a single pulse advances exactly one step, not a level; `tools/test_b_presentation_scheduler_deadlock.sv` (updated) confirms the scheduler's abort pulses `overlap_reference_abandoned` for exactly one cycle. Both pass. `quartus_map` on seed99 is clean, 0 errors, 156 warnings, matching prior baselines.

#### Next Steps:

Sync to all three seed build directories, run the full three-seed timing build, deploy the best-passing seed, and ask the user to reload the file again. If it still stalls, pull fresh telemetry and a fresh Main log immediately and characterize the new failure precisely (unthrottled drain vs real backpressure, and how far it got) rather than assuming it is a variant of any of the first three; three distinct real deadlocks have now surfaced from decoding this one file, each in a different subsystem (the B-reorder scheduler, the transport gate's fatal-error latch, and now the picture bookkeeper/ownership-hold pair), so a fourth is plausible and should be diagnosed from evidence again, not guessed at.

#### Files Modified:

- MediaPlayer.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/test_b_presentation_scheduler_deadlock.sv
- tools/test_two_picture_probe_abandon.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 989 COMMIT Unreleased 2967e0b 2026-09-13T01:50:32-07:00

#### Coming From:

Unreleased 5764dd4

#### Purpose:

Exclude the two remaining sources still latching the transport gate's fatal-error kill switch after entry 988's partial fix.

#### Outcome:

Deployed entry 988's build (excluding only `mpeg2_new_b_presentation_error`) and asked the user to reload the file. Fresh telemetry confirmed `presentation_hold=False` throughout (entry 986's deadlock fix is genuinely working) but `presentation_error=True` with `error_flags=518` still latched, and a fresh Main log pull showed the same unthrottled full-speed drain pattern as before (`credit` pegged at max, ~2020 bytes consumed per poll, matching entry 987's `sent=887078912`-at-completion rate) with the screen staying black - the exact `fatal_error_latched` symptom, this time tripped by `phase1_probe_error`/`pred_error`, which entry 988 deliberately left in the fatal-error list pending evidence. Reading `rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv` found that evidence directly: two of `probe_error`'s five OR-terms, `publication_error` and `reference_progress_error`, are consistency checks against `reference_frame_bank`/`reference_frame_valid`/`reference_promotion_count` - the exact picture-bookkeeping state entry 986's scheduler abort resets in its own module without this separate bookkeeper module ever being told. `mpeg2_new_pred_error`'s source module (`mpeg2_h262_p_frame_predictor` wiring at `MediaPlayer.sv:1650-1697`) reads those same bookkeeper outputs (`reference_frame_valid`, `reference_frame_bank`, `destination_frame_bank`). Both are therefore the expected knock-on of the same recoverable abort, not independent faults. Source `2967e0b` removes both from `mpeg2_new_transport_fatal_error` in `MediaPlayer.sv`, leaving `mpeg2_new_syntax_error`, both `inverse_quant` flags, `idct`, `recon`, and both `ddr` flags untouched, since none of them read the reference-bank bookkeeping and each represents a genuinely distinct failure mode. `quartus_map` on seed99 is clean, 0 errors, 156 warnings, matching prior baselines.

#### Next Steps:

Sync to all three seed build directories, run the full three-seed timing build, deploy the best-passing seed, and ask the user to reload the file again. If it still does not play, pull fresh telemetry and check `error_flags` again - if all nine remaining sources are clear and `presentation_error` alone is the only bit set, the transport gate should no longer latch at all, and any remaining failure is a different, new symptom, not a continuation of this one. If some other error flag now appears instead, it should be treated as a distinct root cause, not assumed to be the same bookkeeping-desync issue.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 988 COMMIT Unreleased 5764dd4 2026-09-13T01:22:47-07:00

#### Coming From:

Unreleased e6e5a4c

#### Purpose:

Stop entry 986's scheduler-abort fix from silently discarding the rest of the file's decode.

#### Outcome:

Hardware testing of entry 987's build confirmed the deadlock itself is fixed (`hold=False`, presentation duration ~2.5M cycles instead of ~1.79 billion) but the user reported the file still froze the same way; fresh telemetry showed `error=True` with three simultaneous bits (`b_presentation_error`, `pred_error`, `phase1_probe_error`), all LEDs steady off, and a full Main log pull showed the *entire* 887MB file had transferred (`finish reason=complete sent=887078912 polls=435207`) with nothing ever decoded afterward. Reading `rtl/mpeg2_new/mpeg2_h262_stream_transport_gate.sv` directly found the cause: its `fatal_error_latched` register is permanently sticky (only `reset_mpeg2` clears it), and once any of the OR-aggregated `mpeg2_new_transport_fatal_error` sources fires, the gate keeps draining `mpeg2_stream_fifo` unthrottled forever (`fifo_read` ungated) while permanently zeroing `decoder_valid` - exactly matching the observed symptom. `mpeg2_h262_b_presentation_scheduler`'s own header states its aborts are intentionally recoverable ("fails the transaction without retaining compressed-stream backpressure") and it already resets its own bookkeeping to clean idle on `presentation_error`; wiring that signal into a project-wide permanent kill switch contradicted the module's own documented design. Source `5764dd4` removes `mpeg2_new_b_presentation_error` from the `mpeg2_new_transport_fatal_error` OR-list in `MediaPlayer.sv`, leaving the other eight sources (syntax, phase1_probe, pred, inverse_quant x2, idct, recon, ddr_store, ddr_cache) untouched, since `phase1_probe_error` and `pred_error` also cover genuinely unsupported I/P syntax unrelated to B-scheduler aborts and were not removed without independent evidence they are similarly safe to exclude - even though both were also latched in the same telemetry snapshot and are suspected to be direct knock-on effects of the same aborted transaction rather than independent faults. `quartus_map` on seed99 is clean, 0 errors, 156 warnings, matching prior baselines.

#### Next Steps:

Sync this change to all three seed build directories and run the full three-seed `quartus_sh --flow compile` timing build, deploy the best-passing seed's RBF, and ask the user to reload the real `.mpg` via F4. If video still does not play, pull fresh `--json` telemetry immediately rather than assuming the same cause, and check whether `phase1_probe_error`/`pred_error` are independently still tripping the same sticky latch - if so they likely also need excluding from `mpeg2_new_transport_fatal_error`, or the scheduler's abort path needs to properly signal the phase1-probe/prediction-reader modules to stop too.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 987 COMMIT Unreleased e6e5a4c 2026-09-13T00:54:32-07:00

#### Coming From:

Unreleased e6e5a4c

#### Purpose:

Build and deploy entry 986's presentation-scheduler deadlock fix for hardware testing.

#### Outcome:

Ran the three-seed timing build. seed26 failed setup timing this time; seed33 and seed99 both passed cleanly, seed33 with the better margin (+0.399ns worst case vs seed99's +0.320ns). Installed seed33's RBF (`.ai/current_results/MediaPlayer_stageB_schedfix_seed33.rbf`, SHA-256 `e98b442d884daa19893256313624534261a22db1bc17bb3b6969278c5b7c2c7d`) onto the test MiSTer via `tools/mister.sh install`, replacing the prior `MediaPlayer_stageB_legacyfix_seed26.rbf` file (confirmed by the installed checksum). Main is unchanged from entry 983 and was not reinstalled. Not yet tested.

#### Next Steps:

Reload the real `.mpg` via F4 and check whether video now actually plays through. If it stalls again, pull fresh telemetry (`tools/decode-hardware-telemetry.py --json`) immediately rather than assuming the same root cause - this scheduler's state space is large and entry 986's fix only addresses the one specific combination the previous snapshot proved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 986 COMMIT Unreleased e6e5a4c 2026-09-13T00:34:53-07:00

#### Coming From:

Unreleased 3713581

#### Purpose:

Fix the presentation-scheduler deadlock entry 985's hardware telemetry pinned down exactly.

#### Outcome:

Pulled `tools/decode-hardware-telemetry.py --json` on entry 985's stuck screenshot and got the scheduler's full internal register snapshot: `reorder_active=1, run_closed=1, decode_inflight=0, promotion_pending=1, queued_run_active=0`. Tracing `presentation_hold`'s expression against those exact values, plus `deferred_queued_b_start` (not exported to telemetry but inferable from `promotion_pending`'s own clear guard requiring it false), found a genuine circular wait in `mpeg2_h262_b_presentation_scheduler`: `deferred_queued_b_start` asserts `presentation_hold` directly and unconditionally - a separate OR-term, not gated on `promotion_pending` at all - which blocks all further decoder input at the top level (`mpeg2_new_stream_ready`), including the remaining compressed bytes of the very overlap-reference picture whose completion (a `frame_waiting` pulse) is the only thing that can ever clear `deferred_queued_b_start`. Once an early B-picture header defers while its overlap reference (an I/P admitted right after the run closed) is still decoding, nothing can ever resolve it - the exact scenario the hardware hit, and almost certainly the same underlying decoder defect the original freeze investigation from much earlier in this session (on the old helper architecture) never got to the bottom of. Built a standalone Icarus testbench (`tools/test_b_presentation_scheduler_deadlock.sv`) instantiating the real scheduler module and reproduced the exact deadlock before writing any fix: admit and complete two B pictures, admit a P header that closes the run and opens an overlap decode, admit a third B header before ever supplying the overlap reference's `frame_waiting`, then run 320 cadence cycles confirming `presentation_hold` never clears. Fixed by detecting this specific combination at the point the closed run's own future frame is ready to retire, and aborting - matching the module's own stated design philosophy ("any decode or ownership failure aborts the transaction without retaining compressed-stream backpressure") instead of latching `promotion_pending` and hanging forever. The properly-promoted (`queued_run_active`) path and the plain non-deferred path are untouched. The same test now verifies the abort fires and `presentation_hold` actually clears afterward. `quartus_map` on seed99 remains clean, 0 errors, same warning count as before.

#### Next Steps:

Run the full three-seed timing build, deploy, and reload the real `.mpg` via F4. This fix only addresses the specific deadlock the telemetry proved; if playback still stalls, pull fresh telemetry again rather than assuming it is the same root cause, since this scheduler's state space is large and this may not be the only unrecoverable combination in it.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/test_b_presentation_scheduler_deadlock.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 985 COMMIT Unreleased 3713581 2026-09-13T00:08:46-07:00

#### Coming From:

Unreleased 3713581

#### Purpose:

Build and deploy entry 984's legacy-PES-header fix for hardware testing.

#### Outcome:

Ran the three-seed timing build. seed99 (this project's usual best seed) failed setup timing this time, but seed26 and seed33 both passed cleanly - seed26 with the better margin (+0.397ns worst case vs seed33's +0.088ns). Installed seed26's RBF (`.ai/current_results/MediaPlayer_stageB_legacyfix_seed26.rbf`, SHA-256 `75c81cf0970372bdb2b7d6c0e99f38056fd55cd17e4a4a8e3fa4afa2e48c38c1`) onto the test MiSTer via `tools/mister.sh install`, confirmed by re-reading the installed file's checksum over SSH. Main is unchanged from entry 983 and was not reinstalled. Not yet tested.

#### Next Steps:

Reload the real `.mpg` via F4 and check whether video now actually decodes and displays - the load should also be fast this time, since a correctly-parsed elementary stream should let the FIFO fill and drain against real decode consumption rather than racing unthrottled through the whole file. Pull the diagnostic log afterward regardless of outcome and check whether `credit` fluctuates now instead of staying pinned at maximum.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 984 COMMIT Unreleased 3713581 2026-09-12T23:48:33-07:00

#### Coming From:

Unreleased 254fd3a

#### Purpose:

Fix the black screen: the demux never recognized the real test file's PES optional-header form at all.

#### Outcome:

Entry 983's diagnostic log showed the transfer running at full, unthrottled speed (constant maximum burst credit, zero backpressure) for 183MB with zero video ever appearing - meaning the FPGA was accepting bytes but the demux was never forwarding any of them as real payload. Pulled the actual file's header bytes over SSH and found the cause directly: the first video PES packet's optional header starts with `0x31`, whose top two bits are `00`, not the `10` marker this demux exclusively recognized - the legacy MPEG-1 PES header form (optional 0xFF stuffing, an optional 2-byte STD_buffer_scale/size field, then a bare PTS/PTS+DTS/no-timestamp marker with no `header_data_length` field), which entry 979 explicitly and wrongly assumed no real file still used. `host/arm/media_player_helper.c`'s own `parse_pes_header()` already handles this form in software. Added it to the RTL, and building an Icarus test from the file's actual captured bytes before touching hardware again caught three real bugs in the process: `legacy_prefix_bytes` was never initialized for the (real-file-common) case where the very first header byte is already the marker, the legacy PTS byte counter was off by one because the marker byte is shifted into `pts_shift` at detection time unlike the MPEG-2 path, and the STD field's own second byte was incorrectly matched against the timestamp-marker pattern instead of just being consumed. Four new Icarus passes cover the exact real-file byte sequence, a stuffed variant, and an STD-field variant, all now passing; `quartus_map` on seed99 remains clean, 0 errors, same warning count as before.

#### Next Steps:

Run the full three-seed timing build, deploy the RBF (Main is unchanged from entry 983 and does not need reinstalling), and reload the real `.mpg` via F4. Watch the diagnostic log for `credit` actually fluctuating now (evidence the FIFO is filling and draining against real decode consumption instead of racing unthrottled) and confirm video actually appears this time.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- tools/test_program_stream_demux.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 983 COMMIT Unreleased 254fd3a 2026-09-12T23:19:48-07:00

#### Coming From:

Unreleased 709c5cd

#### Purpose:

Fix a blocking-transfer hardware bug and a black-screen hardware bug found testing entry 982's timing-clean stage B build.

#### Outcome:

Deployed entry 982's build (seed99 RBF, four-patch Main) and loaded a real `.mpg` via F4. Two real bugs surfaced. First, the file loaded extremely slowly and Main was completely unresponsive - no input, no `/dev/MiSTer_cmd` commands, nothing - for the whole transfer, traced to `user_io_file_tx()`'s chunk loop never returning to Main's top-level poll until the entire file finished, which this project's Program Stream demux backpressures to real-time decode consumption. Second, once the transfer did finish, the screen stayed completely black: `user_io_file_tx_data()`, the function called for the interim fix, is the plain ACK-per-word blocking primitive with no knowledge of this project's `MEDIA_BURST` credit protocol, so bytes sent through it never satisfied `mpeg2_stream_fifo`'s `burst_ready` gate and the decoder never received a single byte, even though Main believed the transfer had succeeded. Found the correct primitive already in stock Main by reading how the ARM helper's own transfer loop (`mediaplayer_poll_inner()`) works: `user_io_file_tx_data_step()`, a non-blocking, burst-credit-aware function that fast-writes only as many bytes as the FPGA currently has room for, returning 0 consumed immediately when no credit is available rather than blocking. Rewrote patch `0004` around this: `mediaplayer_start_plain_video_file()` now opens the file and returns immediately, and a new `plain_video_poll()` - called once per `mediaplayer_poll()` tick exactly like the existing helper-pipe transfer path it sits beside - refills a pending buffer from the file and steps it through `user_io_file_tx_data_step()`, so Main's normal loop keeps running between calls instead of blocking on the whole file. Also fixed `user_io_file_info()` to pass the literal `.M2V` instead of the file's real extension, matching every other call site in this file. Verified by cloning the pinned `Main_MiSTer` commit, applying all four patches in sequence from a fresh checkout, and cross-compiling cleanly (`host/build/MiSTer_MediaPlayer`, SHA-256 `b5a694c0f8e0acd6d332cdb608d42bce9e6455d36204f67b1b156ca09b6b579d`). Not yet retested on hardware.

#### Next Steps:

Install this corrected Main binary (RBF unchanged from entry 982's seed99 build) and reload a `.mpg` via F4; confirm the load is now fast and Main stays responsive throughout (screenshot/input work during the transfer), and that video actually decodes and displays once the transfer completes. If video still does not appear, check `mpeg2_burst_ready`/`mpeg2_stream_full`/the demux's `in_ready` live via a fresh diagnostic rather than guessing further.

#### Files Modified:

- host/main_mister/0004-mediaplayer-plain-video-generic-load.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 982 COMMIT Unreleased 709c5cd 2026-09-12T22:53:53-07:00

#### Coming From:

Unreleased 4d23624

#### Purpose:

Close the recovery-timing failure entry 981's probe removal exposed, and identify a passing seed for hardware testing of stage B.

#### Outcome:

Entry 981's probe removal fixed setup timing completely but exposed a second, smaller failure: all six available seeds (26, 33, 40, 7, 52, 99) failed recovery/removal analysis on the identical path, `mpeg2_h262_audio_ui|mode_active` (60MHz decoder clock) to `mpeg2_luma_framebuffer|rd_reset_sync` (54MHz video clock's async reset), by a consistent -1.4 to -1.9ns margin (one outlier at -0.012). Tracing the mechanism found `mode_active` feeds `mpeg2_new_framebuffer_reset` (`MediaPlayer.sv:2011-2014`), the async reset for that synchronizer - a path with no real timing requirement, since it only fires on a rare, user-driven audio-visualizer/video mode switch, not per-frame. Since six-seed variance had already been exhausted without finding a pass, added a targeted `set_false_path` exception in `MediaPlayer.sdc` for exactly that register pair, following the file's existing per-signal CDC exception convention. Verified the fix without a full re-fit: re-ran `quartus_sta` alone against each seed's already-placed netlist (a false-path exception only relaxes analysis, it cannot change a placement already found valid under the stricter constraint) and found seed26, seed52 and seed99 now pass timing completely with no critical warning; seed33, seed40 and seed7 still fail on an unrelated, pre-existing HDMI-PLL setup margin that has always been seed-sensitive in this project, unrelated to any of today's changes. Selected seed99 (`output_files/MediaPlayer.rbf`, SHA-256 `a24b8bedb58cc7783e6f32e45a1d925c8a5e51bb99e164694e1cf95fad894d85`, 4,465,740 bytes) as the best candidate: best margin among the three passers and the seed this project has used for prior milestones. Also, while builds ran earlier, audited RTL for resources recoverable from the disabled interlaced/Bob-Weave/native-bypass paths (see entry 981) - found nothing recoverable, since that logic was already cheap and the real M10K consumers are all load-bearing decode logic.

#### Next Steps:

Install seed99's RBF alongside the four-patch Main stack (`host/build_arm_stack.sh`'s `main_patches`) on the test MiSTer and confirm silent (audio-muted) video-only playback of a real `.mpg` file loaded via F4, watching for anything the synthetic Icarus demux test didn't exercise. Once hardware-confirmed, proceed to stage C: an MP2 audio decoder consuming the demux's audio elementary output, budgeting carefully against the ~3% M10K headroom entry 981 measured.

#### Files Modified:

- MediaPlayer.sdc

#### Status:

- [x] Built
- [ ] Passed

---

## 981 COMMIT Unreleased 4d23624 2026-09-12T21:52:06-07:00

#### Coming From:

Unreleased b1864ab

#### Purpose:

Diagnose and fix the timing failure found by the three-seed build of entry 980's stage B RTL, and check FPGA resource headroom for stage C's MP2 decoder while builds ran.

#### Outcome:

All three seeds (26, 33, 99) failed timing identically: `quartus_sh --flow compile` reported "Timing requirements not met" with worst-case setup slack -2.929/-2.873/-3.058ns respectively, each on the same path - `mpeg2_h262_b_presentation_scheduler` (60MHz decoder clock) to `mpeg2_h262_live_deadlock_probe|word0_sync1` (54MHz video clock), confirmed via `tools/phase1p_timing.tcl`'s detailed path report. The identical failure across three independent placement seeds (rather than the small slack variance normal seed-search accounts for) pointed to a structural gap rather than placement luck: entry 977/978's diagnostic probe crosses its two live words from the mpeg2 clock domain into the video clock domain with a plain double-flop synchronizer and no SDC exception, so TimeQuest tried to close setup timing between two unrelated clocks as though they were synchronous. Since the freeze investigation that probe was built for is already abandoned in favor of entry 979's rewrite, removed the probe outright (`MediaPlayer.sv`, `files.qip`, and its RTL/tool/test files) rather than add a false-path exception to preserve a feature nothing needs anymore. Separately, while the seed builds ran, audited the RTL for resources recoverable from the already-disabled interlaced/Bob-Weave/native-bypass paths per seed99's completed fit report: current usage is 538/553 M10K blocks (97%) and 35,010/41,910 ALMs (84%), but the tied-off interlaced/native logic (`HDMI_BOB_DEINT`, `interlaced_request_async`) turned out cheap already - `mpeg2_luma_framebuffer`'s native-interlaced-aware paths account for only ~26 of 553 blocks, and `mpeg2_video_output_timing` has no RAM at all. The real top M10K consumers - `mpeg2_h262_two_picture_probe` (170 blocks), `mpeg2_h262_reference_read_probe` (162), three "probe"/"diagnostic_controller"-named P/B motion-vector and residual decode modules (85 each, 255 total), and residual coefficient storage (76) - are all load-bearing H.262 decode logic despite diagnostic-sounding names, confirmed by reading `mpeg2_h262_p_diagnostic_controller_rearm.sv` directly; none are safe removal candidates. No RAM-recovery change was made.

#### Next Steps:

Re-sync the corrected RTL (with the probe removed) to all three seed directories and rerun the three-seed timing build; if it passes, install the RBF and the four-patch Main and get a real hardware test of silent video-only `.mpg` playback via F4. Separately, `audio_pcm_fifo`'s 70 M10K blocks exist only for the legacy helper's already-decoded PCM path - revisit whether stage C's MP2 decoder can reuse it once stage E removes the helper, since a fresh 97%-utilized M10K budget leaves little room for a new audio FIFO of its own.

#### Files Modified:

- MediaPlayer.sv
- files.qip

#### Status:

- [x] Built
- [ ] Passed

---

## 980 COMMIT Unreleased b1864ab 2026-09-12T21:25:48-07:00

#### Coming From:

Unreleased 8527df9

#### Purpose:

Wire entry 979's Program Stream demux into MediaPlayer.sv and reroute Main so a plain .mpg file loads with no ARM helper process at all.

#### Outcome:

Instantiated `mpeg2_h262_program_stream_demux` alongside the existing `mpeg2_h262_inband_metadata`, muxed on a new `mpeg2_new_direct_demux_active` flag latched per-download-session from `ioctl_index`: index 1 (the legacy ARM helper channel) keeps using `mpeg2_h262_inband_metadata` unchanged, while index 4 (`MEDIAPLAYER_LOADER_VIDEO_FILE`, the existing F4 "Load MPEG-2 Video File" OSD slot) now feeds the new demux directly. Both share one `mpeg2_stream_fifo`; `mpeg2_stream_wr` and the `hps_io` burst-ready/`wr_attempt` gating were extended to accept either index, and the inactive consumer's input is gated to always-invalid so it stays completely inert regardless of which path is selected. On the Main side, cloned the pinned `Main_MiSTer` commit referenced by `host/build_arm_stack.sh`, applied all three existing patches, and added a fourth, `0004-mediaplayer-plain-video-generic-load.patch`: a plain `.mpg`/`.m2v`/`.mpeg` file selected via F4 now routes through the ordinary `user_io_file_tx()` path any ROM-loading core uses instead of launching the ARM helper, verified by a real ARM cross-compile of the four-patch stack with zero errors or warnings from the changed files. DVD/ISO/VOB and the standalone audio-file player are untouched and still route through the helper via F5 or the physical-loader path. Audio is not yet decoded anywhere on the new path - stage C's MP2 decoder does not exist yet - so the demux's audio elementary output is sunk with `audio_ready` tied high. `quartus_map` (analysis & synthesis) on seed99 completed with 0 errors and no warnings traced to any of the new or changed signals, confirming the wiring elaborates cleanly; no full timing-closed build or hardware test has been run yet, and the demux has only been exercised against synthetic Icarus test data, never a real captured `.mpg` byte sequence.

#### Next Steps:

Run a full three-seed timing-checked Quartus build of this RTL, install the resulting RBF and the four-patch Main alongside the still-functional helper-based `.rbf`/binary, and confirm silent (audio-muted) video-only playback of a real `.mpg` file loaded via F4 on hardware - watching in particular for anything the synthetic Icarus stream didn't exercise (unusual pack header placement, multiple audio streams, non-PTS-bearing PES packets). Once that is hardware-confirmed, proceed to stage C: an MP2 audio decoder consuming the demux's audio elementary output.

#### Files Modified:

- MediaPlayer.sv
- host/build_arm_stack.sh
- host/main_mister/0004-mediaplayer-plain-video-generic-load.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 979 COMMIT Unreleased 8527df9 2026-09-12T20:55:15-07:00

#### Coming From:

Unreleased 39df52e

#### Purpose:

Adopt a `.mpg`-only architecture that moves Program Stream demux, MP2 audio decode and progress-bar overlay rendering into the FPGA core, eliminating the ARM helper process and the custom Main patches entirely.

#### Outcome:

While diagnosing entry 978's freeze, the user reconsidered why a custom ARM helper and heavily patched Main exist at all: originally for DVD/CD navigation and multi-format audio, neither of which is wanted any more. The user confirmed three scoping decisions: (1) drop the standalone MP3/FLAC/WAV/Ogg audio-file player entirely, (2) support MP2 (MPEG-1 Layer II) audio only, no AC-3, matching `core-reference.md`'s already-adopted H.222.0 Program Stream/PES records (H222-001 through H222-010) and the project's existing ARM-side MP2 decode experience, and (3) abandon entry 978's freeze investigation once this rebuilt RBF exists, since the bug lives entirely inside the cross-process pipe/SPI architecture being replaced, not in the H.262 decode pipeline itself. The target end state plays a `.mpg` file the same way a ROM-loading MiSTer core plays a ROM: stock Main streams the raw file bytes into the FPGA via the existing generic `ioctl_download` path, and the FPGA does everything downstream - Program Stream/PES demux, H.262 video decode (unchanged, already proven), a new MP2 subband decoder, a new glyph-based overlay text renderer, and pause/seek handled natively in RTL without a control-socket handshake to a separate process. Deleted at completion: all of `host/arm/` (11,016 lines), all three `host/main_mister/*.patch` files, the DVD-only RTL (`mpeg2_h262_dvd_overlay.sv` and the DVD leg of `mpeg2_h262_display_record_router.sv`), and the vendored libdvdnav/libdvdread/libdvdcss/liba52/minimp3 dependencies. Stage A landed in the same commit as this entry's resolution: `mpeg2_h262_program_stream_demux`, a from-scratch RTL module parsing MPEG-1/MPEG-2 pack headers, PES framing via `PES_packet_length`, and the MPEG-2-style PES optional header, producing independent ready/valid video and audio elementary-byte streams each with a directly-attached PTS (no in-band metadata escape protocol needed, unlike the ARM helper's scheme). Verified in Icarus against a synthetic but spec-accurate Program Stream covering a stuffed pack header, a video PES, a skipped private stream, an audio PES, and the program end code, including a backpressure test confirming `in_ready` correctly gates the whole input on whichever elementary output is stalled. Not yet wired into `MediaPlayer.sv` or exercised against a real captured `.mpg` byte sequence.

#### Next Steps:

Stage B: reroute Main to stream raw `.mpg` file bytes directly (no helper process) into `mpeg2_h262_program_stream_demux`, wire its video-elementary output into the existing H.262 decode pipeline in place of `mpeg2_h262_inband_metadata`'s video leg, and confirm silent (audio-muted) video-only playback on hardware. Then stage (C): an MP2 audio decoder module, verified in simulation against reference PCM before wiring to the audio output path, then confirmed on hardware; (D) an RTL overlay text renderer replacing `audio_ui.c`'s glyph drawing, plus native pause/seek input handling in place of the control-socket protocol; (E) delete the ARM helper, the three Main patches, DVD-only RTL and the now-unused vendored dependencies, and update `files.qip` and the build scripts accordingly. Do not delete the current working (if buggy) helper/Main architecture until stage (C) is hardware-confirmed, so there is a fallback playable build throughout.

#### Files Modified:

- files.qip
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 978 COMMIT Unreleased 39df52e 2026-09-12T20:29:13-07:00

#### Coming From:

Unreleased 8e72075

#### Purpose:

Add a continuously-live decode/display progress and ownership-hold probe so the next physical freeze can be diagnosed directly from a screenshot instead of inferred from static code reading.

#### Outcome:

Entry 977's ARM-side pipe-write deadlock fix did not resolve the freeze: hardware testing after that fix still hung after a handful of ordinary pause/resume cycles on the baseline `01 - Pee Strike.mpg`, with two screenshots ten seconds apart byte-identical, `MiSTer_MediaPlayer` pinned at ~50% CPU with `wchan=0` (a busy userspace loop, not a kernel wait), and `MediaPlayer_Helper` blocked in `pipe_write` with no active pause in the log. Tracing the chain from `fpga_spi_write_ack_impl()`'s untimed SSPI-ACK busy-wait (`host/main_mister/0001-mediaplayer-arm-loader.patch`, patched into `fpga_io.cpp`) back through `hps_io`'s `ioctl_wait`, `mpeg2_stream_fifo`'s `wr_full`, and `mpeg2_new_stream_ready`'s gate on `mpeg2_new_p_destination_ownership_hold` and `mpeg2_new_b_presentation_hold` (`MediaPlayer.sv`) identified a plausible circular-wait design flaw: the P-only ownership hold (`MediaPlayer.sv:1699-1747`) only releases once display moves off the bank decode wants to reuse, but display can only move there once decode supplies a new completed picture - which decode cannot do while held. Building a rigorous Icarus simulation of that hypothesis was judged not worth the risk of an unfaithful model, since `mpeg2_h262_b_presentation_scheduler.sv` turned out to be a 1016-line, heavily-evolved B-reordering state machine far more intricate than its two hold outputs suggested. Instead, added `mpeg2_h262_live_deadlock_probe`, a new module inserted last in the video chain (after the existing one-shot `mpeg2_h262_hardware_cadence_profiler`, which only arms once at the first overlay commit after boot and never re-arms) that redraws two small always-live data words every video frame from raw mpeg2-domain state: `mpeg2_stream_full`, `mpeg2_burst_ready`, both ownership holds, the active/display frame banks, and two independent free-running counters that increment on `mpeg2_new_picture_420_complete` and on any change to the display bank/scratch state, so a screenshot taken during a live hang shows directly whether decode or display (or both) have actually stopped advancing. A standalone Icarus unit test (`tools/test_live_deadlock_probe.sv`) confirms the box passes the base color through outside its fixed corner region, both rows draw the fixed alignment prefix, the two words decode to the expected live field values, and the two progress counters advance independently; `tools/decode-live-deadlock-probe.py` was verified against a synthetic PNG built with the same bit layout before trusting it on real hardware screenshots. `MediaPlayer.sv`, `files.qip` and the new RTL/test/tool files build cleanly under Icarus; no Quartus timing build has been run yet.

#### Next Steps:

Superseded before its timing build finished: the user decided, in the same session, to drop DVD/CD and the standalone audio-file player entirely and rebuild the project as `.mpg`-only with Program Stream demux, MP2 audio decode and overlay text rendering moved into the FPGA core, eliminating the custom Main patches and the ARM helper process outright - see entry 979. The three seed compiles this entry's Next Steps called for were killed unstarted-to-timing-closure; this probe and the freeze it was built to diagnose are abandoned along with the architecture that has the bug, not carried forward.

#### Files Modified:

- MediaPlayer.sv
- files.qip
- rtl/mpeg2_new/mpeg2_h262_live_deadlock_probe.sv
- tools/decode-live-deadlock-probe.py
- tools/test_live_deadlock_probe.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 977 COMMIT Unreleased 8e72075 2026-09-12T13:48:48-07:00

#### Coming From:

Unreleased af7f570

#### Purpose:

Remove the reconstructed idle-hide-while-paused overlay clear, which writes to the bulk output pipe after Main has already stopped draining it, and confirmed as a reproducible deadlock on hardware.

#### Outcome:

Hardware testing on `af7f570` reproduced a hang after only a few ordinary pause/resume cycles on both `fellow.mpg` and the baseline `01 - Pee Strike.mpg`, surviving a full core reboot and fresh reload. Diagnosis via `/proc/<pid>/wchan` caught `MediaPlayer_Helper` parked in `pipe_write` while `MiSTer_MediaPlayer` (Main) sat busy at 36-52% CPU without draining, and the ARM diagnostic log confirmed no further bytes were read after the hang point even after a fresh SSH-triggered refetch. `video_overlay_pause_barrier()`'s idle-timeout branch, reconstructed at entry 975 from a lost live-debug session, calls `emit_overlay_clear()` and `flush_output()` on the same buffered stdout pipe Main reads for bulk audio/video/overlay data - but this call happens strictly after `MEDIA_PLAYER_CONTROL_PAUSE_READY` is sent and acknowledged, at which point Main's own `mediaplayer_poll()` gate (`if (playback_paused && !stream_boundary_pending) return;`) has already stopped servicing that pipe, so the write blocks forever once residual buffered bytes plus the clear record exceed the pipe's capacity. This differs from the reveal-on-pause write immediately above it in the same function, which is safe only because it is sent before Main's gate engages - a distinction the function's own preceding comment already documented for the reveal case without recognizing the idle-clear case violates it. The fix removes the wall-clock idle-timeout loop and `control_wait_for_go_timed()` entirely, restoring an unconditional `control_wait_for_go()` block after publishing `PAUSE_READY`, so the overlay simply stays visible for the full duration of any pause instead of auto-hiding after ten seconds; the wall-clock idle-hide introduced at entry 975 for the actively-playing case is unaffected, since Main continues draining the pipe throughout normal playback.

#### Next Steps:

Deploy `host/build/MediaPlayer_Helper` via the atomic `.new`-then-`mv` pattern and have the user reproduce the exact repro that hung before (a handful of ordinary pause/resume cycles on both `fellow.mpg` and `01 - Pee Strike.mpg`) to confirm playback survives; also re-check the file's TOTAL/REMAIN duration estimate for `fellow.mpg`, which showed an implausible ~52 hour figure once the large-file `stat()` fix made it non-zero, and address the confirmed missing lowercase/space glyphs in the restyled progress-strip labels as a follow-up commit.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 976 COMMIT Unreleased af7f570 2026-09-12T12:52:53-07:00

#### Coming From:

Unreleased e7fde30

#### Purpose:

Fix the video progress overlay showing TOTAL/REMAIN as 00:00 on a large (~4 GiB) `.mpg` file, and restyle the progress-strip labels to "Label: HH:MM:SS" moved closer to the bar.

#### Outcome:

The user tested a second, much longer `.mpg` file (24fps, ~4.06 GiB) and found pausing showed `TOTAL 00:00`/`REMAIN 00:00` while the progress bar itself still filled correctly.  The ARM diagnostic log showed `video progress overlay enabled file_size=-1` at session start - the file-size `stat()` call was failing.  The file is 4,359,360,512 bytes, past the boundary a 32-bit `off_t`/`struct stat` can represent; without large-file support, glibc's `stat()` on the ARM target returns `EOVERFLOW` instead of a size for any file at or beyond that boundary (roughly 2-4 GiB depending on signedness).  `video_overlay_locked_length_pts()` treats `video_overlay_file_size <= 0` as "can't compute a duration yet" and returns 0 forever once locked that way, which is why TOTAL/REMAIN stayed at zero while the bar (driven by absolute PTS position, not the locked duration) still moved normally.  Separately, the user asked to restyle the progress strip: "Elapsed:"/"Remaining:"/"Total:" (colon, mixed case) instead of "ELAPSED"/"REMAIN"/the bare label, `HH:MM:SS` instead of `MM:SS`, and the whole strip moved down closer to the progress bar.

#### Next Steps:

Source `af7f570` adds `-D_FILE_OFFSET_BITS=64` to `host/arm/Makefile`'s default `CPPFLAGS` (applies to every translation unit in both the native and ARM builds, harmless no-op on x86_64 where `off_t` is already 64-bit by default) so `stat()` correctly reports sizes for files past the 32-bit boundary instead of failing.  `host/arm/audio_ui.c`'s `format_time()` now formats `HH:MM:SS`; `draw_progress_strip()`'s three labels became `"Elapsed: %s"`, `"%s: %s"` (caller-supplied label, now passed capitalized - `"Total"` for the video overlay, `"Track"` for the audio player's own full UI), and `"Remaining: %s"`, and their Y position moved from 412 to 422 (closer to the progress bar at 438).  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change.  Committed immediately on a clean compile, before deployment.  `host/build/MediaPlayer_Helper` (SHA-256 `059bef4d4208356f747eaaf66b54ba177f6df35daa864e2dec7b7e0fac1bcabf`) is built; deliver it (current RBF `5ce3c1f`/seed99 and Main unaffected) for the user to retest the large file's TOTAL/REMAIN and the restyled labels/positioning, and to continue stress-testing for the separately-identified, apparently pre-existing decoder hang (unrelated to this fix).

#### Files Modified:

- host/arm/Makefile
- host/arm/audio_ui.c
- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 975 COMMIT Unreleased e7fde30 2026-09-12T12:33:49-07:00

#### Coming From:

Unreleased 618b197

#### Purpose:

Reconstruct the wall-clock overlay-timing work (auto-hide while paused, and the seek-timing fix) that was live-iterated and deployed on top of `618b197` without ever being committed, and is now gone from both git and the build output path - re-implement it from scratch as a single committed change instead of leaving it lost.

#### Outcome:

A live debugging session chasing the .mpg progress overlay's pause/seek behavior went through several real, working intermediate states (a wall-clock `OVERLAY_IDLE_MS` deadline in the pause barrier, a seek activity-mark fix, and a full rewrite of `video_overlay_service()`/`video_overlay_mark_activity()` from PTS-based to `monotonic_us()`-based idle/refresh tracking) built and deployed directly to the test hardware without an intervening `git commit` - each ARM cross-build overwrote the same output binary, so once a later change was built the earlier one was gone from disk too, and none of it was ever committed to source control. When a genuine, apparently pre-existing decoder hang was found afterward (unrelated to these changes, reproducible even on the fully-reverted `618b197` build) and then a request came to restore the pre-hang state, there was no commit and no surviving binary to restore from - only this session's own memory of the changes. The user correctly identified this as defeating the entire purpose of the commit-before-build workflow.

#### Next Steps:

Source `e7fde30` re-implements the wall-clock overlay-timing mechanism from scratch on top of `618b197` (which already carried `video_overlay_publish()`'s visibility-aware rendering and the hidden-background-refresh cadence from `a45a67c` - only the PTS-vs-wall-clock timing base needed reconstructing): `video_overlay_service()`'s idle-hide and refresh-cadence checks switch from `max_video_pts` deltas to `monotonic_us()` deltas (PTS reflects how much of the stream has been parsed/submitted, not real elapsed time, and bursts far ahead of real time whenever the decode pipeline refills - most visibly right after a seek); `video_overlay_mark_activity()` anchors to `monotonic_us()` directly; and the pause barrier polls for GO with a wall-clock ten-second deadline (`control_wait_for_go_timed()`, added alongside the existing unbounded `control_wait_for_go()`), clearing the overlay once idle and falling back to an unbounded wait, since PTS does not advance at all while genuinely paused. Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change. Committed immediately on a clean compile, before any further live testing, specifically to not repeat the mistake that lost the original version of this work. `host/build/MediaPlayer_Helper` (SHA-256 `18bd95c55fb91df0acfd3a4907ea5e8e5aa86ad8b809eaf1d2c1c55403d19129`) is built; deliver it (current RBF `5ce3c1f`/seed99 and Main unaffected) for the user to retest pause-reveal, pause auto-hide, and seek timing, and to continue stress-testing for the separately-identified, apparently pre-existing decoder hang (unrelated to this file).

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 974 COMMIT Unreleased 618b197 2026-09-12T11:54:33-07:00

#### Coming From:

Unreleased a45a67c

#### Purpose:

Revert the wall-clock idle-hide-while-paused mechanism and the seek-timing rewrite built on top of `a45a67c`: live testing found they introduced a real hang, and the feature they were chasing (auto-hiding the overlay while genuinely paused) was already known architecturally unreachable, so the safer move is dropping back to the last state confirmed fully stable.

#### Outcome:

On top of `a45a67c` (STYLE-only reveal + background refresh), three more iterations were built and live-tested without committing: (1) added `flush_output()` to `video_overlay_pause_barrier()` after discovering the STYLE write was sitting unflushed in the helper's own stdio buffer, which the user confirmed fixed the pause-reveal bug; (2) added a wall-clock `OVERLAY_IDLE_MS` deadline inside the barrier's wait loop to also auto-hide the overlay after ten seconds *while still paused* - the user confirmed play/pause was working well with this in place, even though the hide-while-paused half of it turned out to be structurally unreachable (Main stops draining its pipe entirely while `playback_paused`, so a CLEAR sent from inside the barrier can never actually arrive until resume); (3) chasing a *separate* reported bug (overlay flashing then vanishing after a seek), first anchored the seek's activity mark to the seek target PTS, then - once that proved insufficient because PTS is not a reliable stand-in for real elapsed time during decoder buffer refills - rewrote the whole idle/refresh mechanism (`video_overlay_service()`, `video_overlay_mark_activity()`, and the pause barrier's own wait) to use `monotonic_us()` throughout.  The user confirmed the seek fix worked, then during further open-ended testing (play/pause and seeking back and forth) hit a hard hang: helper cleanly blocked in `poll()` (confirmed via `/proc/<pid>/wchan`), but Main itself pinned at 50% CPU while "R (running)" instead of idling, and two resume keypresses produced no effect and no new log lines - a genuine deadlock/spin, not a cosmetic issue, reproducible from a fresh reboot with a single pause. No `strace`/`gdb` available on the target to pin down the exact mechanism.

#### Next Steps:

Reverted `host/arm/media_player_helper.c` to exactly `a45a67c` plus only the one isolated, well-understood `flush_output()` fix (verified via `git diff --stat`: 8 insertions, 1 deletion) - dropping the wall-clock idle-while-paused loop, the seek PTS-anchor attempt, and the full monotonic_us() rewrite entirely.  This intentionally leaves both previously-reported cosmetic issues unresolved (overlay doesn't auto-hide while paused; a seek can still show a brief stale-timing flash) in exchange for the last build with no observed hangs.  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change.  `host/build/MediaPlayer_Helper` (SHA-256 `51a9c3968dbb9fa8415741392fcdb96e8166864538eb9412483a4a1d3efd9c94`) is built and deployed (current RBF `5ce3c1f`/seed99 and Main unaffected); the user is stress-testing this build now to confirm the hang is actually gone before this is considered resolved.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [ ] Built
- [ ] Passed

---

## 973 COMMIT Unreleased a45a67c 2026-09-12T10:27:30-07:00

#### Coming From:

Unreleased 016f1e2

#### Purpose:

Fix the `.mpg` progress overlay still not appearing on pause: `016f1e2`'s reorder (full publish before `PAUSE_READY`) did not close the race after all - live testing showed Main's own overlay trace receiving the CONFIG record but never the matching COMMIT.

#### Outcome:

The user's retest of `016f1e2` reproduced the exact same symptom.  A live ARM diagnostic log (telemetry enabled) captured Main's `overlay_submit` trace for the failing pause: `config sequence=21` was received, but no `commit sequence=21` (or any `data` records) ever appeared, even though the helper is strictly sequential and cannot send `PAUSE_READY` until `video_overlay_publish()`'s writes have all already returned successfully.  This means the race is not about *when* the helper writes relative to `PAUSE_READY` at all - `PAUSE_READY` travels on a small, separate `control_fd` channel Main can process independently of how far its own asynchronous drain loop has gotten through the ~88 KiB already sitting in the bulk pipe from the publish.  A stale `pause_pipe_empty=true` (set from any earlier momentary gap, since `pause_pending` is already true from the moment Main decides to pause, well before the helper even starts processing the command) combined with `pause_ready` becoming true is enough for `pause_barrier_finish()` to fire and Main to stop draining, abandoning whatever of the publish it had not yet read - regardless of whether the helper sent it before or after `PAUSE_READY`.  The only way to make this safe is to keep the amount of data crossing the wire at pause time small enough that draining it is not itself a multi-poll-cycle operation - i.e. go back to `24a6bda`'s original small `MEDIA_PLAYER_OVERLAY_STYLE`-only reveal - and instead fix the actual staleness problem it was trading away: `video_overlay_service()` previously stopped publishing entirely once idle-hidden, so the plane content a later STYLE-only reveal could show was frozen at whatever was last rendered before the hide, potentially minutes stale.

#### Next Steps:

Reverted `video_overlay_pause_barrier()` back to the small `video_overlay_style()`-only reveal (restored the function `016f1e2` deleted).  Fixed the real problem instead: `video_overlay_publish()` now renders with `output->video_overlay_visible` (was hardcoded to always-visible) so a publish can update pixel content without also forcing the overlay on screen, and `video_overlay_service()` no longer stops entirely once idle-hidden - it keeps publishing fresh content in the background on a slower five-second cadence (`VIDEO_OVERLAY_BACKGROUND_REFRESH_TICKS`, vs. the one-second cadence used while visible) with `visible=0`, so the FPGA plane stays reasonably current the whole time the overlay is hidden.  These background refreshes happen during ordinary, non-barrier operation - the same proven-safe context as any other periodic refresh - so they carry none of the pause-time race risk; only the actual reveal at pause time still crosses the wire, and it is back to the small, safe record.  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change.  `host/build/MediaPlayer_Helper` (SHA-256 `e731e7f405e3530c4fa8bbac94e5b0ea12bab6ef0b5f595a17ef333e4bc25a1c`) is built; deliver it (current RBF `5ce3c1f`/seed99 and Main unaffected) for the user to retest: let the overlay auto-hide, then pause - it should reveal immediately with reasonably current TOTAL/ELAPSED/REMAIN (at most a few seconds stale, not minutes), and no longer race Main's drain detection since the pause-time transfer is tiny again.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [ ] Built
- [ ] Passed

---

## 972 COMMIT Unreleased 016f1e2 2026-09-12T10:13:02-07:00

#### Coming From:

Unreleased 5ce3c1f

#### Purpose:

Fix the `.mpg` progress overlay still only appearing on resume, not on pause, despite `24a6bda`'s lightweight style-toggle fix - the user's own repro (wait for auto-hide, then pause) showed nothing at all on screen while paused.

#### Outcome:

The user reported the exact `24a6bda`-era symptom again ("shows up on resume, not pause") on a fresh install of the current build.  Checking the actual installed binaries found the deployed `MediaPlayer_Helper` still hashed to `f329dce`'s build, not `24a6bda`'s - the fix had never actually reached the test hardware.  Reinstalling the correct `24a6bda` helper (`chmod +x` and atomic rename over the running, text-busy binary, since the process had it open) did not fix the symptom, so the bug is real, not a stale-binary artifact.  With telemetry enabled, a live ARM diagnostic log captured the exact failing pause event (`pause requested` -> `pause helper ready` -> `playback paused`, no errors) but this traced to a genuine structural bug in `video_overlay_pause_barrier()`: it calls `control_wait_for_go()`, which blocks for the entire pause duration, on the line *before* `video_overlay_service()` - the only function that renders fresh content and performs the actual CONFIG+DATA+COMMIT publish - ever gets to run in `process_program_stream()`'s loop.  The barrier's own lightweight `MEDIA_PLAYER_OVERLAY_STYLE` toggle (added in `24a6bda`) only flips a visibility/palette flag; it carries no pixel data, so on a reveal-from-hidden it can only re-show whatever was last actually committed to the FPGA plane - which service() never got to refresh, since it's blocked from running until the barrier returns after resume.  The reason `24a6bda` avoided calling `video_overlay_publish()` (the full ~88 KiB republish) from inside the barrier was a real race with Main's `pause_pipe_empty` detection, but that race is specifically about a write still in flight when Main stops draining *after* `pause_ready` becomes true - not about doing the publish before `PAUSE_READY` is even sent, while Main is still draining completely normally exactly as it does for any other periodic mid-playback refresh.

#### Next Steps:

Source `016f1e2` restructures `video_overlay_pause_barrier()` to force `video_overlay_service()` to run (via `pending_reveal`) *before* sending `PAUSE_READY`, so a full fresh publish completes and is fully handed to the pipe while Main is still in normal-drain mode, then only afterward announces ready and blocks for GO.  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change.  Delivered and the user retested with telemetry enabled: the symptom was unchanged, and a live ARM diagnostic log pinpointed why - Main's own `overlay_submit` trace showed the CONFIG record of the reveal-triggered publish arriving, but no matching COMMIT ever appeared, even though the helper is fully synchronous and cannot send `PAUSE_READY` until the entire publish's writes have already returned.  The real race is not about ordering within the helper at all: `PAUSE_READY` arrives on a small, separate `control_fd` channel that Main can process independently of how far its own asynchronous drain loop has gotten through the ~88 KiB already sitting in the bulk pipe, so `pause_barrier_finish()` can fire (and Main stop draining) while most of a large publish is still unread and gets abandoned.  Superseded by the fix logged in entry 973.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 971 COMMIT Unreleased 5ce3c1f 2026-09-12T08:06:57-07:00

#### Coming From:

Unreleased 6ac6895

#### Purpose:

Remove RTL and OSD support for native (unscaled 480i) presentation, Bob/Weave deinterlacing, and DVD/CD physical-media and disc-image menu entries, since this project only ever plays progressive `.mpg` files and the progressive audio UI/visualizer through the standard scaled HDMI/analog path, in order to recover FPGA resources and improve timing margin (seed26 passed `6ac6895` at only +0.050 ns setup slack).

#### Outcome:

The user asked what could safely be removed from the RBF to help timing/resources now that interlace, Bob/Weave and native output are all unsupported project scope, then directed starting the removal, later narrowing it to "standard HDMI and analog video out" for video and "spdif, analog, and HDMI" for audio, and separately asked to drop the DVD-video and Audio-CD OSD load options.  A repo-wide search for video-SDI support found nothing to remove - the only "SDI" matches are `SDIO_DAT`/`SDIO_CMD`/`SDIO_CLK` (the SD card interface) and `ADC_SDI` (the audio ADC's SPI pin name), both generic MiSTer board-framework names unrelated to video SDI.  Removed: `rtl/mpeg2_native_timing_pattern.sv` (dead, unreferenced); the `mpeg2_hdmi_deinterlace_control` instantiation, tying `HDMI_BOB_DEINT` directly to `1'b0` and deleting `rtl/mpeg2_hdmi_deinterlace_control.sv` along with the now-orphaned `audio_ui_mode_active_video_sync`/`audio_ui_mode_active_video` synchronizer and its `MediaPlayer.sdc` false-path exception; the `"O[124],Deinterlacer Mode:,Bob,Weave;"` OSD entry; the `mpeg2_h262_native_field_order` instantiation and the `mpeg2_new_native_480i_request`/`mpeg2_new_presentation_request` decision chain it fed, simplifying `mpeg2_new_presentation_request` to `mpeg2_new_native_progressive_supported` directly since `mpeg2_new_progressive_sequence` is always true for this project's content, and tying `mpeg2_video_output_timing`'s `interlaced_request_async`/`top_field_first_async` ports to `1'b0`; the `mpeg2_new_film_mode_video_sync` synchronizer, simplifying `mpeg2_new_swap_window_video`'s assignment to `display_frame_window` directly; and the presentation scheduler's `native_film_mode` port, tied to `1'b0`.  Also removed `"P1,Load Physical Disc;"`, `"P1F1,DVD,Video DVD;"`, `"P1F2,CD,Audio CD;"`, `"P2,Load Disc Image;"` and `"P2F3,ISO,Video DVD;"` from `CONF_STR`, keeping `"F4,...;"`/`"F5,...;"` direct `.mpg`/audio-file loading - verified safe since Main's patch dispatches on a single fixed `MEDIAPLAYER_STREAM_INDEX = 1`, not the OSD slot number.  Deliberately deferred: `mpeg2_new_native_active_mpeg2`/`_sync`/`_mode_change`, which are already effectively dead for progressive-only content but are intertwined with the `reset_mpeg2_display_domain` fix from `fa0ebf6`, judged too risky to bundle into this same pass.  All three seeds 26, 33 and 40 compiled with 0 errors and did free real resources - logic utilization dropped from 34,684 to 34,511/34,506/34,456 ALMs respectively (about -0.4 to -0.7%), total registers dropped from 54,327 to 54,293/54,188/54,039, and DSP blocks dropped from 70 to 68 - but none passed timing: worst-case setup slack on the `pll_hdmi` divider-counter path was negative 0.115 ns, negative 0.209 ns and negative 0.297 ns respectively, all worse than `6ac6895`'s own seed26 result (positive 0.050 ns) on that identical critical path.  Removing logic elsewhere apparently shifted placement/routing enough to move this specific PLL path the wrong way on every seed this round, despite the real ALM/register/DSP reduction confirming the cleanup itself works as intended.  Seed 26 (best margin of the three, still failing) was delivered as `.ai/current_results/MediaPlayer_nativemoderemoval_seed26.rbf`, SHA-256 `6c0abc70d9a928b6aff1ed5478758f4eb862b7447cb6a68da1d995975bf42c06`, for reference only - not timing-qualified.  The previously delivered `6ac6895`/seed26 build (`.ai/current_results/MediaPlayer_nativestartupfix_seed26.rbf`) remained the current timing-qualified RBF while further seeds were tried.  A targeted retiming fix to `sys/ascal.vhd` (folding the extended-resolution line-buffer select into its read register, since TimeQuest traced every failing path to that exact structure inside the shared MiSTer scaler IP) was implemented and test-built, but made things measurably worse - setup slack dropped to negative 0.417 ns and a new, worse critical path appeared on the memory write-enable side, indicating the merge broke Quartus's clean M10K inference rather than removing a mux level - so it was reverted (never committed).  Fresh seeds 7, 52 and 99 were then tried on the plain `5ce3c1f` source: seed 99 passed, with worst-case setup slack positive 0.022 ns, logic utilization 34,467 ALMs and 54,220 registers (both below the pre-cleanup `6ac6895` baseline of 34,684 ALMs / 54,327 registers, confirming the cleanup's resource savings hold on a passing seed too).  Investigated whether any of this project's own prior `ascal.vhd` tuning commits (`a2debaa` through `dfe1057`) caused this tight margin: none of them touch the actual failing signals, which are unmodified since upstream commit `d93bc2e` (2025-07-09, predating all project-specific ascal work) - so the tightness is inherent to the shared scaler's extended-resolution line-buffer structure, not a regression introduced here.  Seed 99 was delivered as `.ai/current_results/MediaPlayer_nativemoderemoval_seed99.rbf`, SHA-256 `903f542edd472aaf1ecd326df0ff327688888af35d17231858caa08c52e529f6`.  Main and the helper are unchanged from `24a6bda`'s delivered build.

#### Next Steps:

Install `.ai/current_results/MediaPlayer_nativemoderemoval_seed99.rbf` (Main/helper unchanged from entry `24a6bda`) and retest: `.mpg` playback, seeking, pause/resume and the progress overlay, and standalone audio playback/visualizer should all behave exactly as before, with the Bob/Weave OSD option, the DVD/CD load menu entries, and the native-480i decision path gone, on a build that now also clears timing.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer.sv
- files.qip
- rtl/mpeg2_hdmi_deinterlace_control.sv
- rtl/mpeg2_native_timing_pattern.sv
- rtl/mpeg2_new/mpeg2_h262_native_field_order.sv

#### Status:

- [x] Built
- [x] Passed

---

## 970 COMMIT Unreleased 6ac6895 2026-09-12T07:39:05-07:00

#### Coming From:

Unreleased 24a6bda

#### Purpose:

Fix the `.mpg` progress overlay flashing briefly then going missing after every seek, even though `24a6bda` fixed the pause reveal correctly.

#### Outcome:

The user reported that skipping forward/backward briefly flashes the overlay, then the screen goes black before the video resumes at the new position, after which the overlay is gone.  A screenshot of a paused mid-test frame confirmed the resumed video itself is completely clean, isolating this to the overlay specifically.  Investigation found `mpeg2_h262_native_startup` (instantiated in `MediaPlayer.sv`), a module that blanks the screen (forcing `base_de` low via `mpeg2_new_startup_video_blank`) until either the first picture is shown or a `bypass_event` fires; the DVD-style overlay compositor's `overlay_sample_valid` also requires `base_de`, so nothing can composite during that blank window.  The user identified its origin directly: it was added specifically to hide genuinely corrupt video while skipping DVD chapters (a mid-GOP splice glitch crossing program chain segments), not for `.mpg` seeking.  Its reset was `reset_mpeg2`, which includes the Entry 237 rearm pulse fired on every seek, so this module's "startup done" latch (`decided`/`bypass`/`shown`) re-armed and re-blanked the screen on every plain `.mpg` seek too - the same class of bug already fixed twice tonight for `mpeg2_h262_audio_ui` (`b0372f6`) and the luma framebuffer (`1b1ab7a`).  A literal git revert of the module's history was not practical (three prior commits including a full native-480p rewrite would be unwound); DVD chapter navigation is out of scope for this project now, and a plain `.mpg` seek decodes straight from a GOP boundary and never produces the corruption this blank existed to hide, matching the clean resumed-video screenshot.  Source `6ac6895` changes `mpeg2_h262_native_startup`'s reset from `reset_mpeg2` to `reset_mpeg2_base`, so "startup done" latches once at the true first load and never re-blanks the screen on a seek again; `swaps_enabled` staying permanently true afterward is correct (it only ever gated the first frame swap until a complete picture was ready) and its only other consumer is an unrelated development-only diagnostic condition.  All three seeds 26, 33 and 40 compiled with 0 errors; worst-case setup slack was positive 0.050 ns, negative 0.027 ns and negative 0.334 ns respectively, so only seed 26 passes timing - margins are noticeably tighter than recent builds, consistent with the resource-cleanup motivation behind the native/interlace removal pass queued up next.  Seed 26 was delivered as `.ai/current_results/MediaPlayer_nativestartupfix_seed26.rbf`, SHA-256 `b8964507eacf87fe73f97715860de7020549ca3acbd48e5e45af56d15b4250bf`.  Main and the helper are unchanged from `24a6bda`'s delivered build.

#### Next Steps:

Install `.ai/current_results/MediaPlayer_nativestartupfix_seed26.rbf` (Main/helper unchanged from entry `24a6bda`) and retest: seeking on `.mpg` should no longer blank the screen or lose the progress overlay, while the video itself and ordinary `.mpg`/audio-player behavior remain unaffected.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 969 COMMIT Unreleased 24a6bda 2026-09-12T07:28:33-07:00

#### Coming From:

Unreleased f329dce

#### Purpose:

Fix the `.mpg` progress overlay still only appearing on resume, not on pause itself, despite `f329dce`'s barrier widening.

#### Outcome:

The user confirmed TOTAL/REMAIN now hold steady but the reveal still only showed up on resume.  A fresh telemetry-enabled log pulled from the test MiSTer showed the CONFIG record and `MEDIA_CONTROL_PAUSE_READY` both went out promptly after "pause requested," so the barrier protocol itself was working, but the matching COMMIT record (and most of its ~22 chunked DATA records) did not appear until immediately after "playback resumed," and the helper logged `ignoring unexpected control 0x11 during playback` right after the pause.  The cause: `video_overlay_pause_barrier()` called `video_overlay_service()` inside the barrier, which on a fresh reveal triggers a full `video_overlay_publish()` - CONFIG plus ~22 DATA chunks plus COMMIT, around 88 KiB total.  Main's `pause_pipe_empty` detection can see a momentary gap mid-transfer of that payload and satisfy `pause_barrier_finish()`'s drain check before the trailing records get through, stranding them in the helper's blocked `write()` once Main actually stops draining - the same class of bug as the original fire-and-forget ping, just relocated to a heavier payload racing the same detection.  `audio_pause_barrier()` never has this problem because it only ever sends a single ~41-byte `MEDIA_PLAYER_OVERLAY_STYLE` record inside the barrier, relying on bitmap content already committed from an earlier periodic service call rather than republishing pixel data at pause time.

#### Next Steps:

Source `24a6bda` adds the equivalent `video_overlay_style()` and rewrites `video_overlay_pause_barrier()` to use it exclusively (set `visible`/`activity_pts` directly, send the style toggle only on a fresh reveal, then `PAUSE_READY` and wait for `GO`), relying on the plane already holding a committed bitmap from the unconditional reveal already performed at session start.  Also clears `command` after the barrier so `process_program_stream()`'s unrelated catch-all no longer logs a handled command as unexpected, and genericized Main's remaining "audio pause helper ready"/"unexpected audio pause ready" diagnostic wording now shared with `.mpg` sessions.  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; `host/build/MiSTer_MediaPlayer` (SHA-256 `be3946ba5404dedccdf8b041bad2600b22dc4041eb10f5efc5375f1d531470a1`) and `host/build/MediaPlayer_Helper` (SHA-256 `11bb2a00de4f353fea8f7ef5bd661990353248611f5e150e9ce96768f0c173ad`) are both built; no RTL change, current RBF (`fa0ebf6`, seed 33) unaffected.  Deliver both for the user to retest: the overlay should now reveal immediately on pause, not just on resume.

#### Files Modified:

- host/arm/media_player_helper.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 968 COMMIT Unreleased f329dce 2026-09-12T07:08:14-07:00

#### Coming From:

Unreleased fa0ebf6

#### Purpose:

Fix two remaining `.mpg` progress-overlay problems: it only revealed on the next resume rather than on pause itself, and TOTAL/REMAIN visibly jumped around instead of counting down smoothly.

#### Outcome:

The user confirmed the overlay now draws (`fa0ebf6`) but reported it "only shows up on resume, not pause," matching the audio player's own pre-`4116a00` bug, and that ELAPSED was stable while REMAIN and TOTAL jumped around.  The pause-reveal bug traced to the same root cause as the audio player's original one: the fire-and-forget `MEDIA_CONTROL_USER_ACTIVITY` ping added in `08db78e` raced Main's own transfer loop, which stops draining the helper's output pipe as soon as `playback_paused` is set; once that pipe fills, `process_program_stream()` blocks inside a write and never returns to the top of its loop to see the pending control byte until the *next* unpause lets the blocked write through.  Main's existing audio pause barrier (`MEDIA_CONTROL_PAUSE`/`PAUSE_READY`, `pause_pending`/`pause_ready`/`pause_pipe_empty`, `pause_barrier_finish()`) already solves exactly this by continuing to drain normally while `pause_pending` is set and only asserting `playback_paused` once the helper has replied and the pipe is confirmed empty; it was gated on `audio_visualizer_controls` only.  The TOTAL/REMAIN jitter traced to `video_overlay_estimated_length_pts()` recomputing the `max_video_pts`/`max_video_pts_byte` ratio on every publish, which drifts slightly as more of a VBR file is read; REMAIN (`length - position`) inherits that same drift.

#### Next Steps:

Source `f329dce` widens the pause-barrier gate from `audio_visualizer_controls` to `seek_controls` (audio_visualizer_controls plus direct `.mpg`/`.mpeg` files, excluding DVD/ISO/menu content) so `.mpg` sessions use the identical, already-correct barrier; added `video_overlay_pause_barrier()` (mirrors `audio_pause_barrier()`) wired into `process_program_stream()`'s per-iteration command read in place of the removed `MEDIA_CONTROL_USER_ACTIVITY` ping.  Renamed the estimator to `video_overlay_locked_length_pts()` and made it compute the ratio once (a new `video_overlay_length_known` flag), caching the result in `output_state` and preserving it across `reset_output_for_navigation()`'s memset alongside the other `video_overlay_*` resources, so a seek does not re-lock a different estimate mid-session.  Native and ARM cross-compiled builds both pass `-Wall -Wextra -Werror` clean; no RTL change.  `host/build/MiSTer_MediaPlayer` (SHA-256 `a7bf5dcd6af84f6de6134a2fcd447041f67d59662b0776e2a1985f6be5f2fe13`) and `host/build/MediaPlayer_Helper` (SHA-256 `214e48931268df2e498a73c2e4b4b32d0f570b774c5f09be533266f205383312`) are both built; the current RBF (`fa0ebf6`, seed 33) is unaffected.  Deliver both for the user to retest: the overlay should reveal immediately on pause (not just resume), and TOTAL should hold one static value for the whole session while REMAIN counts down smoothly.

#### Files Modified:

- host/arm/media_player_helper.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 967 COMMIT Unreleased fa0ebf6 2026-09-12T06:19:27-07:00

#### Coming From:

Unreleased 08db78e

#### Purpose:

Fix the .mpg progress-bar overlay never appearing on screen despite `08db78e`'s ARM/Main changes transmitting it correctly.

#### Outcome:

The user reported no visible change on real `.mpg` playback.  A fresh telemetry-enabled log confirmed `08db78e`'s helper code was running (`video progress overlay enabled file_size=...`) and that Main's overlay-trace patch showed `overlay_submit config`/`commit` pairs with a changing content hash roughly once per second, proving the overlay data was being rendered and transmitted correctly end to end.  The bug is in `mpeg2_h262_dvd_overlay.sv`, the FPGA-side DVD-style overlay compositor this feature rides on: `overlay_sample_valid` required `native_active` (the decoder's raw interlace flag, wired from `display_native_interlaced`) to be asserted before compositing any pixel, and the row-fetch request trigger for its line cache carried the same gate, so the cache was never even populated.  The same telemetry log's `H262 restart fields` diagnostic confirmed the user's test file is genuinely `sequence_progressive=1`/`progressive=1` content, so `native_active` reads 0 for it and the overlay is received and parsed correctly but never draws a pixel; the standalone audio player's identical overlay mechanism is unaffected because it does not depend on this signal.  The user confirmed this project no longer plays genuinely interlaced content - only converted progressive `.mpg` files and the progressive audio UI/visualizer - and authorized breaking interlaced/native-passthrough compatibility to fix this.

Source `fa0ebf6` removes `native_active` from both the row-request trigger and the sample-valid gate in `mpeg2_h262_dvd_overlay.sv`; `h_pos`/`v_pos` already enumerate a straightforward progressive raster there regardless of source interlace, so this does not change what row is requested or sampled, only removes a gate that no longer corresponds to how this core is used.  The `native_active` port is left connected but unused rather than touching the module interface.  Following this fix the user set a standing project scope decision: interlaced content, native (unscaled 480i) bypass and Bob/Weave deinterlacing are all now unsupported, since only the user's own progressive `.mpg` encodes and the progressive audio UI/visualizer are played going forward.  All three seeds 26, 33 and 40 compiled with 0 errors; worst-case setup slack was negative 0.137 ns, positive 0.116 ns and negative 0.280 ns respectively, so only seed 33 passes timing.  Seed 33 was delivered as `.ai/current_results/MediaPlayer_progressiveoverlay_seed33.rbf`, SHA-256 `347269119b7e1e4fbbd4f0be433acd21261b2fa87359f8db137826557b320561`.  Main and the helper are unchanged from `966`'s delivered build.

#### Next Steps:

Install `.ai/current_results/MediaPlayer_progressiveoverlay_seed33.rbf` (Main/helper unchanged from entry 966) and retest the `.mpg` progress-bar overlay: it should now actually draw on screen, appearing for ten seconds on play, pause and seek and then disappearing, with ordinary `.mpg` playback/seeking and the audio player unaffected.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_dvd_overlay.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 966 COMMIT Unreleased 08db78e 2026-09-12T05:45:00-07:00

#### Coming From:

Unreleased 1b1ab7a

#### Purpose:

Add the audio player's progress bar and elapsed/remaining/total time overlay to `.mpg` video playback, revealed for ten seconds on play, pause, and seek exactly as it already works for standalone audio files.

#### Outcome:

Investigation found the audio player's progress overlay is not part of the full-screen audio UI background frame at all: `audio_overlay_render()`/`audio_ui_render_overlay()` renders the same `render_frame()` layout into a separate transparent 720x480 two-bit indexed plane and publishes it through `emit_overlay_frame()`/`emit_overlay_clear()`, the identical DVD-SPU-style overlay-compositing channel already used for real DVD subtitles and menus on top of decoded H.262 video - so no RTL change is needed to composite this overlay on top of `.mpg` playback.  The ten-second auto-hide timer (`audio_visualizer_activity()`/`audio_visualizer_take_overlay_action()` in `host/arm/audio_visualizer.c`) is a simple position-vs-rate threshold, not intrinsically audio-specific.  Program Stream (`.mpg`) pause currently has zero helper involvement - Main's non-audio `MEDIAPLAYER_INPUT_PLAY_PAUSE` fallthrough only toggles `playback_paused` locally - unlike audio's pause, which round-trips through the helper via a blocking barrier because audio's software PCM queue needs flushing; `.mpg` needs no equivalent barrier since Main already gates its own transfer loop on `playback_paused`, so introducing a new blocking barrier for `.mpg` would add risk for no functional benefit.  Seek already reaches `process_program_stream()`'s existing seek-completion point via the established `MEDIA_CONTROL_SEEK_*` control bytes.  `MEDIA_CONTROL_USER_ACTIVITY` (0x10) is already defined in the protocol but currently sent nowhere in Main and only consumed as a plain, non-blocking activity ping on the audio-only paths.

Source `08db78e` implements the plan as proposed.  `host/arm/audio_ui.c`'s `render_frame()`'s bottom strip is extracted into `draw_progress_strip()`, taking position/length/rate_hz as explicit parameters rather than reading persistent `ui` fields, since `audio_ui_seek()`/`audio_ui_set_track_length()` restrict `rate_hz` to 44100/48000, which does not hold for a 90000 Hz video PTS clock; the new public `audio_ui_render_progress_overlay()` draws only that strip onto an otherwise-transparent plane using the same `struct audio_ui`.  `struct output_state` gains `video_overlay_ui`/`video_overlay_plane`/`video_overlay_file_size`, created only for `seekable_program_stream` sessions (direct `.mpg`/`.mpeg` files, not DVD/ISO) and, critically, added to the small set of fields `reset_output_for_navigation()` preserves across its `memset(output, 0, ...)` on every seek - alongside the pre-existing `video`/`pcm`/`reserve`/`activation_stage` - since without that the allocation would leak and the overlay would silently disable itself after the first seek.  `video_overlay_mark_activity()`/`video_overlay_service()` are wired into `process_program_stream()`'s existing per-iteration command read and its seek-completion point; Main's non-audio pause fallthrough now sends a fire-and-forget `MEDIA_CONTROL_USER_ACTIVITY` byte.  Both the native and ARM cross-compiled helper builds pass `-Wall -Wextra -Werror` clean; `host/build/MiSTer_MediaPlayer` (SHA-256 `d4c1f1d3ed66c2186e15acf967cb5510a3de8164a1eebf102e5a1fbbf25046f6`) and `host/build/MediaPlayer_Helper` (SHA-256 `15a7934f647794f5dab4be9fcac614f3fa0695b827c6daf7a59a377697eecdf5`) are both built.  No RTL change; the current RBF is unaffected.

#### Next Steps:

Install `host/build/MiSTer_MediaPlayer` and `host/build/MediaPlayer_Helper` (RBF unchanged) and verify on `.mpg` playback: the progress bar and elapsed/total/remaining times appear for ten seconds on play, pause and seek and then disappear, `.mpg` seeking and playback are otherwise unaffected, and standalone audio-file and DVD behavior are unaffected.

#### Files Modified:

- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/media_player_helper.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 965 COMMIT Unreleased 1b1ab7a 2026-09-12T04:11:45-07:00

#### Coming From:

Unreleased b0372f6

#### Purpose:

Fix the residual multi-frame screen flash still seen on every standalone audio-file seek after `b0372f6`, reported by the user as Bob/Weave visibly affecting the visualizer image again.

#### Outcome:

The user installed and tested the `b0372f6`/`1a6297f` 3-seed build: `.mpg` seeking remains unaffected, standalone MP3 seek/pause/skip no longer freezes, pops or falls back to the idle visualizer, but a shorter screen flash on every seek remained, visible as Bob/Weave affecting the image.  A screenshot captured from the test MiSTer mid-issue via `tools/mister.sh screenshot` showed a corrupted block rather than a clean frame, which the user clarified is simply the visible signature of Bob motion-adaptive deinterlacing applied to the visualizer's static frame during the flash, the same mechanism as the original flicker report, not separate DDR corruption.  Investigation found a second module untouched by `b0372f6`: `mpeg2_luma_framebuffer`'s picture-present/generation tracking (`mpeg2_new_framebuffer_reset`) and the interlace-mode-change detector feeding it (`mpeg2_new_native_active_sync`) both still reset directly on `reset_mpeg2`, which includes the Entry 237 rearm pulse fired on every seek; `b0372f6` only protected `mpeg2_h262_audio_ui`'s own persistent `mode_active`/`display_bank` state, not this separate read-side module, so the framebuffer's "is a picture present yet" tracking still reset on every seek even though the underlying DDR content and its validity are completely unaffected, producing a visible multi-frame gap until the next audio UI commit recovered it.  Source `1b1ab7a` adds `reset_mpeg2_display_domain` (true reset unconditionally, the rearm pulse only when `audio_ui_mode_active` is false) and uses it in place of raw `reset_mpeg2` for both `mpeg2_new_native_active_sync` and `mpeg2_new_framebuffer_reset`, exempting them from the rearm while the audio UI owns the display.  All three seeds 26, 33 and 40 compiled with 0 errors and positive worst-case setup slack (positive 0.332 ns, positive 0.148 ns and positive 0.035 ns respectively); seed 26 was chosen for best margin as `.ai/current_results/MediaPlayer_audioseekunify2_seed26.rbf`, SHA-256 `766e20a57098bdd37e98c9fd8421c3c288b05be1a6479ccbdda477c101d89181`.  Main and the helper are unchanged from `964`'s delivered build.

#### Next Steps:

Deliver the RBF for the user to retest standalone MP3 seeking for a completely clean transition with no flash and no Bob/Weave sensitivity, while confirming `.mpg` seeking and normal video playback remain unaffected.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 964 COMMIT Unreleased b0372f6 2026-09-12T03:26:13-07:00

#### Coming From:

Unreleased adb4f53

#### Purpose:

Abandon the bespoke Main-side "skip the download reset" path for standalone audio-file seeking and instead unify standalone audio playback with the already-correct `.mpg` seek/play/pause architecture, fixing the visualizer's reset-visibility problem at its real cause instead of avoiding the shared reset.

#### Outcome:

Hardware testing of `39274a8`/`adb4f53` traced a second, deeper regression (premature clean end-of-stream a few seconds after a seek, falling back to the idle visualizer) that could not be pinned to any single mechanism through log analysis alone: transport-level SPI credit/digest validation never failed, and every identified buffer stage in the chain (Main's 16 KiB pending buffer, the 64 KiB OS pipe, the FPGA's 32 KiB `mpeg2_stream_fifo`, the PCM output adapter's sub-16384-sample counter) is too shallow to explain a multi-second gap through legitimate buffering, leaving the bespoke audio-only seek path's exact failure mode unresolved.  Rather than continue debugging a code path that exists only for standalone audio and has now produced two distinct regressions, the user redirected the design: this project only cares about direct file playback (DVD and Audio CD paths are out of scope), `.mpg` seeking already works perfectly through Main's ordinary full download-session reset (`MEDIA_CONTROL_READY`/`GO`, unconditional `user_io_set_download` toggle and reassert), and standalone audio-file playback should be structured identically to `.mpg` playback - the same session/seek/play/pause state machine, differing only in which "pipe" feeds it (H.262 video + MP2/AC3 audio demuxed from a Program Stream, versus the audio_ui/visualizer full-frame overlay + raw PCM decoded in ARM software) - which also sets up the audio UI's overlay protocol to later serve as the video player's subtitle renderer.  The originally reported flicker is most likely `mpeg2_h262_audio_ui`'s persistent `mode_active`/`display_bank` state being disrupted by `MediaPlayer.sv` Entry 237's elementary-stream rearm pulse on every download-session reset, which real H.262 video decode masks by continuously redrawing but the visualizer's persistent-frame overlay does not; the correct fix is to make that reset harmless to the audio UI's persistent display state, not to avoid the reset.

`39274a8` and `adb4f53` are reverted (`03542c0`, `832a68d`), restoring `host/main_mister/0001-mediaplayer-arm-loader.patch` to byte-identical content with `4116a00`: standalone audio-file seeking now uses the exact same unconditional `MEDIA_CONTROL_READY`/`GO` full-reset path as `.mpg` seeking, with no Main-side branching on content type at all.  Source `b0372f6` implements the actual RTL fix: `mpeg2_h262_audio_ui` gains a `session_start` input, mirroring the existing `reset`/`session_start` split already used in `mpeg2_stream_fifo`, so only a true reset clears `mode_active`/`display_bank` while `session_start` (wired to `mpeg2_download_rearm_reset`, matching `reset` to `reset_mpeg2_base`) still resets the in-flight BEGIN/DATA/COMMIT parser state without disturbing which bank is on screen; both wired signals are already `clk_mpeg2`-domain, so no new CDC synchronizer or SDC exception was needed.  `tools/test_mpeg2_audio_ui.sv` gained coverage proving `mode_active`/`display_bank`/DDR bank addressing survive a `session_start` pulse mid-session while the protocol parser cleanly accepts a fresh frame afterward; this passed under `iverilog`/`vvp` prior to commit.  While reviewing the working tree, an unrelated hardware-validated fix from earlier in the session (forcing the HDMI Bob/Weave deinterlacer off while the audio UI owns the display, fixing the previously-reported visualizer interlace jutter) was found still uncommitted and was committed separately as `1a6297f` ahead of this entry's fix, since both needed the same build cycle.  Neither fix has been synthesized yet.

#### Next Steps:

All three seeds 26, 33 and 40 compiled with 0 errors.  Worst-case setup slack: seed 26 at positive 0.198 ns, seed 33 at positive 0.210 ns, seed 40 at negative 0.253 ns (fails timing, on `pll_hdmi`'s output-counter divider) with a TNS of negative 8.186; seed 33 was chosen as `.ai/current_results/MediaPlayer_audioseekunify_seed33.rbf`, SHA-256 `b93110b73214cb406e66f349f8968fd0c52c66d2e4291b7b612c804fc00f04f0`.  Main was rebuilt from the reverted, now-unified patch to `host/build/MiSTer_MediaPlayer`, SHA-256 `dcc00429096182dfaed319b889c99fe2e64dbc58e22f02abea6c2454e03b8e8e`; the helper is unchanged.  Deliver both files for the user to install and test: standalone MP3 seeking should show no blank/flicker/pop and no premature end-of-stream across repeated seeks, `.mpg` seeking must remain completely unaffected, and the visualizer should no longer show interlace jutter.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer.sv
- host/main_mister/0001-mediaplayer-arm-loader.patch
- rtl/mpeg2_new/mpeg2_h262_audio_ui.sv
- tools/test_mpeg2_audio_ui.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 963 COMMIT Unreleased adb4f53 2026-09-12T02:40:53-07:00

#### Coming From:

Unreleased 39274a8

#### Purpose:

Fix a regression from `39274a8` where the audio player's screen no longer blanked on seek but audio instead stopped and the display froze after roughly one seek.

#### Outcome:

Hardware testing of `39274a8` on `10.10.0.45` reproduced the new symptom on a single MP3 seek, and `/tmp/MediaPlayer_ARM.log` was pulled and inspected: `t=6923223 chapter barrier released discarded=53764` proves `chapter_barrier_poll()`'s shared fallthrough path fired for this audio seek, which it should not have.  The cause is that `39274a8`'s `audio_visualizer_controls` branch skipped the manual `user_io_set_download(0)`/`(1)` toggle but never set `chapter_download_rearmed`, so the shared `if (!chapter_download_rearmed)` block below still ran `user_io_set_index()`, `user_io_file_info(".M2V")` and `user_io_set_download(1)` for every audio seek.  Reading pristine upstream `user_io.cpp` confirms `user_io_set_download()` sends its `FIO_FILE_TX` SPI assert unconditionally on every call regardless of Main's own `download_active` mirror, so this still reasserted a fresh download session to the FPGA, just without the preceding low pulse.  The log shows the remainder of the test file's audio, roughly 38 seconds' worth following the seek target, was consumed in only about 5.6 real seconds before a premature clean end-of-stream, consistent with the reassert disturbing FPGA-side burst credit/byte accounting and defeating playback pacing; Main's resulting hold-last-frame/stop-audio end-of-stream handling is what was observed as a freeze.  Source `adb4f53` sets `chapter_download_rearmed = true` in the audio branch, mirroring the non-audio branch, so the shared reassert is fully suppressed and an audio-only seek makes no download-related FPGA call at all.  The patch was reverified against pinned upstream `Main_MiSTer` `0a8fb44` with `git apply --check` and rebuilt; GNU 10.2.1 produced the stripped ARMv7 `host/build/MiSTer_MediaPlayer`, 1,186,780 bytes, SHA-256 `38430997604e44972cb434d782c39dbf3e5e91980546a12f3f644e4203652f71`.  No helper, decoder RTL or RBF changes were made or are required.

#### Next Steps:

Install `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer` in place of the `39274a8` build, then repeat standalone MP3 seeking, including multiple repeated seeks in one session, and confirm no screen blank/flicker, no audio pop, no premature stop/freeze, and that playback continues correctly at normal pace from the seek target through to the file's true end; also recheck `.mpg`/DVD seeking is unaffected.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 962 COMMIT Unreleased 39274a8 2026-09-12T02:15:36-07:00

#### Coming From:

Unreleased 4116a00

#### Purpose:

Stop standalone audio-file and Audio CD seeking from triggering the FPGA's full new-elementary-stream reset, which the user reports as a full-screen blank and flicker plus an audible pop on every seek in the audio player, matching the same reinitialize behavior seen on a fresh file or core load.

#### Outcome:

Investigation traces the symptom to `MediaPlayer.sv`'s Entry 237 and Entry 410 reset chains: every `ioctl_download` rising edge is treated as a brand new elementary-stream session, rearming the MPEG-2 decode domain and stretching an audio FIFO/scheduler/underrun reset regardless of whether any video content is present.  Standalone `.mp3`/`.wav`/`.flac`/`.ogg` file seeking (`audio_file_complete_seek()`) and Audio CD track/seek repositioning (`cdda_complete_reposition()`) both complete through the shared `MEDIA_PLAYER_CONTROL_READY`/`GO` barrier in `host/main_mister/0001-mediaplayer-arm-loader.patch`'s `chapter_barrier_poll()`, which unconditionally toggles `user_io_set_download(0)` then `(1)` and reasserts `user_io_set_index()`/`file_info(".M2V")` — the same primitive used for a genuinely new file load; existing `.mpg`/DVD Program Stream seeking uses this identical barrier and toggle but is not visibly disruptive because the video decode pipeline is already mid-redecode, whereas standalone audio has no video content to mask the reset, so it is fully visible.  The user has confirmed `.mpg` seeking already works correctly and DVD/menu seeking is out of scope, so the approved fix is Main-only, with no ARM helper protocol changes, no decoder RTL changes and therefore no Quartus/RBF rebuild: in `chapter_barrier_poll()`'s `seek_pending` branch, when the already-available file-scope flag `audio_visualizer_controls` (true for `.mp3`/`.wav`/`.flac`/`.ogg` files and `cdda:` tracks, set in `mediaplayer_start_session()`) is set, the `MEDIA_CONTROL_READY` handler keeps its existing pending-buffer discard (`pending_size`/`pending_offset`/`pending_eof`/`burst_state` reset, `chapter_barrier = true`) but skips `user_io_set_download(0)`, `user_io_set_download(1)`, `user_io_set_index()` and `user_io_file_info(".M2V")` entirely, leaving `ioctl_download` continuously asserted across the seek, which removes both the MPEG-2 domain rearm and the audio FIFO/scheduler/underrun reset for audio-only sessions while leaving DVD/ISO/Program Stream seeking, chapter/navigation barriers and Audio CD's shared code path otherwise untouched.

Source `39274a8` implements the conditional skip exactly as proposed: `chapter_barrier_poll()`'s `seek_pending`/`MEDIA_CONTROL_READY` handler keeps the unconditional pending-buffer discard and `chapter_barrier = true`, then branches on `audio_visualizer_controls` to either log a retained-download diagnostic or perform the prior full download-reset sequence unchanged for non-audio content.  The change was verified by cloning pinned upstream `Main_MiSTer` at `0a8fb44`, confirming all three Main patches still apply cleanly with `git apply --check`, and inspecting the applied `support/mediaplayer/mediaplayer.cpp` to confirm the intended branch structure.  GNU 10.2.1 (`arm-none-linux-gnueabihf-gcc`) built the stripped ARMv7 `host/build/MiSTer_MediaPlayer`; it is 1,186,780 bytes with SHA-256 `ba3375b28e50eed09755b790e6b8a37b7890ed1e614b6113cd36a62abbbe5086`.  No helper, decoder RTL or RBF changes were made or are required for this fix.

#### Next Steps:

Install only `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer`, retaining the current helper and RBF unchanged, then test standalone MP3/audio-file seeking on the test MiSTer and confirm the full-screen blank/flicker and audio pop no longer occur on seek while playback continues correctly at the new position; also verify `.mpg`/DVD seeking is unaffected, and test Audio CD track/seek skipping if a disc is convenient.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

