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

## 961 COMMIT Unreleased 4116a00 2026-09-04T00:07:31-07:00

#### Coming From:

Unreleased 3b2a0ca

#### Purpose:

Replace marker-file optical launching with a hierarchical loader menu that starts physical DVD and Audio CD media directly while retaining separate DVD ISO, MPEG-2 video and audio file pickers.

#### Outcome:

This proposal was never implemented or committed; substantial unrelated development proceeded on master afterward without being logged here, per explicit user direction to leave that interim history undocumented and resume the formal propose/log/build/log/test cycle fresh from the repository's current state.  The loader-menu reorganization and direct physical CDDA/DVD launch behavior described above did not happen under this entry and remain open work if still wanted in the future.  This entry is closed as abandoned and superseded, anchored at `4116a00`, the actual repository HEAD at the point formal logging resumes.

#### Next Steps:

None; this proposal is closed without action.  Any future loader-menu reorganization work should be proposed fresh against the current HEAD rather than resumed from this entry.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 960 COMMIT Unreleased 3b2a0ca 2026-09-03T22:32:01-07:00

#### Coming From:

Unreleased 5fc7a1e

#### Purpose:

Add direct physical Audio CD playback through the existing standalone-audio interface and combine its picker change with the pending naming RBF build.

#### Outcome:

Source `184b2fa` adds the `Audio CD.cd` marker to the existing audio picker, maps it in isolated Main to `cdda:/dev/sr0`, inventories the disc table of contents through Linux optical-drive controls, skips data tracks and reads audio sectors digitally as native 44.1 kHz signed stereo PCM for the existing audio UI, visualizer and in-band transport.  The helper exposes playable tracks as one continuous timeline, retains fixed-time seeking and maps previous or next commands to audio-track boundaries through the established READY/GO lifecycle; the decoder RTL and transport protocol are unchanged.  Focused CDDA optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer coverage passes, as do strict native compilation, the isolated Main CDDA contract and retained AC-3, file-audio, UI, visualizer, DVD random-access, SPU, reserve, staging, Program Stream seek, Main seek, LPCM-skip and real MP3, WAV, FLAC and Ogg integrations.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `35a369ed1c3f30197f0ce663da67a0c171dbf132c34d6c131c859aa626663dd7` and the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `06339d6b5ac2fa216c2be47062ba7e5d8b178c0bd4aa950562c25ea3fedfdc3f`.  The initial seed-24 Quartus build failed only global setup at negative 0.606 ns while decoder and video setup passed at positive 0.984 ns and positive 1.097 ns; the single authorized source-`3b2a0ca` seed-25 retry passes global setup at positive 0.118 ns, hold at positive 0.247 ns, recovery at positive 3.578 ns, removal at positive 0.580 ns, minimum pulse width at positive 0.925 ns, decoder setup at positive 0.250 ns and video setup at positive 1.662 ns, with peak interconnect reduced from 67 percent to 60 percent.  Its worst path is the pre-existing `ascal` vertical-accept-to-address DSP calculation, whose 6.596 ns data delay is 78 percent cell delay and 22 percent routing rather than a general interconnect failure.  The resulting 4,477,416-byte `host/build/MediaPlayer_20260903.rbf` has SHA-256 `686957247693c1556aee9018ff4be19e08e1969225fe35e1063ffb67c597d74e`; no physical Audio CD was available for local hardware acceptance.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_20260903.rbf` as `/media/fat/MediaPlayer_20260903.rbf`, `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer`, `host/build/MediaPlayer_Helper` as executable `/media/fat/linux/MediaPlayer_Helper`, `assets/Video DVD.dvd` as `/media/fat/games/MediaPlayer/Video DVD.dvd` and `assets/Audio CD.cd` as `/media/fat/games/MediaPlayer/Audio CD.cd`, remove the obsolete `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`, preserve the current visualizer and per-core INI, then reboot.  Load an Audio CD through the audio picker and require clean first-track playback, UI and visualization, previous and next track selection, fixed-time seeking, pause and end-of-disc behavior, including a mixed-mode disc if available; then confirm ordinary DVD loading, menus, chapter controls, Bob or Weave output and the retained experimental native-NTSC mode before marking this source hardware-passed.  Treat a future scaler timing-improvement cycle separately by investigating the registered `ascal` address-DSP path rather than weakening the timing gate.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- MediaPlayer.sv
- README.md
- assets/Audio CD.cd
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 959 COMMIT Unreleased 5fc7a1e 2026-09-03T22:22:02-07:00

#### Coming From:

Unreleased d34c292

#### Purpose:

Rename the DVD picker and physical-drive launcher to concise user-facing labels without changing playback routing.

#### Outcome:

Source `5fc7a1e` replaces the core-menu label `Run DVD-Video` with `Load Disk`, renames the tracked launcher from `USB DVD Drive.dvd` to `Video DVD.dvd`, and updates current setup and testing documentation plus the Unreleased changelog.  Patched Main continues mapping every selected `.dvd` file to `dvdmenu:/dev/sr0`, so the helper protocol, source selection and DVD playback behavior remain unchanged; the immutable v0.9.0 release manifests and package hashes retain the historical launcher name they actually shipped.  Static checks confirm the new menu string, asset contents and extension routing, and the source commit is pushed without staging the user's unrelated local changes.

#### Next Steps:

Retain source `5fc7a1e` as the naming boundary and incorporate its pending RBF change into the approved Audio CD development cycle rather than performing a separate Quartus compile.  The combined cycle should add `.cd` picker support and physical CDDA playback, rebuild the affected Main and helper, then perform one clean timing-gated Quartus build with the established seed unless timing requires the single authorized reseed.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- assets/USB DVD Drive.dvd
- assets/Video DVD.dvd
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 958 COMMIT Unreleased d34c292 2026-09-03T21:59:59-07:00

#### Coming From:

Unreleased d34c292

#### Purpose:

Package the source-`d34c292` native NTSC output boundary for controlled HDMI, HDMI-to-SDI and analog forum testing.

#### Outcome:

The 1,378,292-byte forum archive `host/build/MiSTer_MediaPlayer_NTSC480i_d34c292.zip` has SHA-256 `621cf865c1561f6f87a3ded01bc3c95f00416acd508f2b561e5c4a7dc4aaefdc` and passes ZIP integrity plus every internal SHA-256 check.  It contains the source-`d34c292` 1,182,684-byte `MiSTer_MediaPlayer`, the source-`f93c6ba` 970,148-byte static helper needed for the latest automatic-menu pacing behavior, the per-core INI fragment, source provenance, project and dependency licences, and a dedicated installation, rollback and reporting guide.  The guide separates ordinary Bob/Weave HDMI as the control, native 525i59.94 direct HDMI for sinks that explicitly accept 480i, HDMI-to-SDI through the Decimator MD-LX with downstream external processing, and native 15 kHz RGB or YPbPr analog output; it warns that a blank unsupported HDMI monitor is inconclusive and that scaled screenshots are not a reliable Direct Video capture.  The unchanged RBF, visualizer and USB DVD launcher are intentionally absent so testers retain their installed matched v0.9.0 set, and the official `/media/fat/MiSTer` is never replaced.

#### Next Steps:

Distribute `MiSTer_MediaPlayer_NTSC480i_d34c292.zip` as an unreleased forum hardware test and have each tester verify the archive manifest, preserve the official Main, install the two isolated executables and report the exact display, converter and processor models.  Require a normal Bob/Weave HDMI control first, then record whether direct HDMI or the MD-LX identifies and locks 480i or 525i at 59.94 Hz, whether menus, titles and audio remain continuous, whether 4:3 and 16:9 are identified correctly, and whether field motion reaches the external processor intact; compare with a 15 kHz analog CRT where available and return the results before changing the ADV7513 policy.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 957 COMMIT Unreleased d34c292 2026-09-03T21:18:06-07:00

#### Coming From:

Unreleased f93c6ba

#### Purpose:

Expose the proven native NTSC raster as standards-signalled 525i59.94 HDMI for external processing through the Decimator MD-LX.

#### Outcome:

Source `d34c292` adds an experimental NTSC-only direct-HDMI boundary to the isolated patched Main without changing the decoder, helper or RBF.  It activates only for the reported `MediaPlayer` core with per-core `direct_video=1`, divides the core's 54 MHz ADV7513 input clock by two, samples every 13.5 MHz content pixel twice at 27 MHz, advertises manual x2 pixel repetition without multiplying that already-correct link clock, selects negative-sync CTA VIC 6 or 7 from status bit 121, identifies BT.601 and limited RGB, forces the full-to-limited CSC and uses CTS 27,000 for 48 or 96 kHz audio.  Generic Main behavior remains behind the existing branches, the aspect and AVI state refresh without a scaler mode change, the tracked INI fragment leaves Direct Video commented by default, and the README and architecture document the initial native-interlaced-only test boundary.  The new static register-policy test passes, all three Main patches apply cleanly in order to pinned upstream `0a8fb44`, and GNU 10.2.1 builds the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `6aeded222240b6abd324b5d1525ce88d4ef6d56984a80c1d9d0332aaa2675462`.

#### Next Steps:

Replace only `/media/fat/MiSTer_MediaPlayer`, retain the accepted helper and RBF, add `direct_video=1` beneath the existing `[MediaPlayer]` section, reboot and test native-interlaced NTSC DVD material through MiSTer's HDMI port and the Decimator MD-LX.  Require the MD-LX and downstream processor to identify and hold 525i59.94, confirm continuous picture and HDMI audio through menus and title playback, exercise both 4:3 and 16:9 signalling, inspect field motion for intact interlace rather than Bob or Weave, and remove `direct_video=1` after the test because progressive and standalone-audio output are intentionally not qualified in this first boundary; return the updated results before considering 576i, 60.000 Hz or a live core-menu switch.

#### Files Modified:

- CHANGELOG.md
- README.md
- assets/MiSTer_MediaPlayer.ini.fragment
- docs/ARCHITECTURE.md
- host/build_arm_stack.sh
- host/main_mister/0003-mediaplayer-ntsc-480i-hdmi.patch
- tools/test_main_ntsc_480i.py

#### Status:

- [x] Built
- [ ] Passed

---

## 956 COMMIT Unreleased f93c6ba 2026-09-03T20:32:38-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Keep automatic-menu PCM below its safety ceiling without recreating the long downstream audio lead.

#### Outcome:

Source `f93c6ba` retains source `67ce19d`'s reserve-drain pacing boundary and replaces its fixed one-batch fallback ceiling with pressure-driven 2,048-frame runs.  Each stalled-timestamp automatic-menu pass drains held PCM to a low watermark equal to half the configured hold limit when that is above the existing 8,192-frame scheduling reserve, which is 96,000 frames at the default four-second limit; the normal advancing-timestamp scheduler, ordinary title reserve, overlay priority and transport byte order remain unchanged.  This gives the default route two seconds of hold-limit headroom, bounds the initial sink-paced catch-up from the observed 183,808 frames to approximately 1.83 seconds, and makes subsequent work proportional to each newly decoded Program Stream audio burst instead of permitting a net-growing hold.  The production fixture proves that one fallback pass drains 48,000 held frames to its 24,000-frame test watermark through the real reserve, then absorbs a further 12,000-frame burst while preserving the watermark and every emitted sample; the retained long-menu and advancing-PTS controls pass.  Strict optimized, AddressSanitizer with leak detection disabled for the ptrace environment, UndefinedBehaviorSanitizer and GCC analyzer checks pass apart from the known audio-overlay allocation false positive, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests.  Twenty repeated production runs, one hundred menu-hop runs, fifty output-reserve runs and twenty LPCM-skip integrations pass, and real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `70cfc0c59957bfaf8ca1b536f3746537c76e4108551a4b28c359a3ebcefa8785`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`f93c6ba` artifact and retain the current per-core Main, RBF and visualizer.  Let Futurama run through all intros into its root menu, require one fallback diagnostic containing `watermark=96000 reserve=8192 paced_batch=2048`, and confirm the menu appears and animates with continuous intelligible audio, a responsive selector, no hold-limit diagnostic and no helper termination.  Exercise its nested episode menu and selected-title playback, then repeat automatic-menu entry on several other discs and return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 955 COMMIT Unreleased 67ce19d 2026-09-03T20:28:11-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Qualify source `67ce19d` on Futurama's automatic root-menu transition and isolate its failure before menu playback.

#### Outcome:

The physical source-`67ce19d` run rejects the one-batch fallback admission policy while validating its sink-pacing boundary.  All three finite intro boundaries complete, the silent-video lookahead classifies and releases, the automatic menu inherits the continuous scheduling epoch at 41.085422 seconds, the first translated audio and video horizon remains fixed at PTS 647,273, and a valid 86,400-byte overlay plane commits without ordering error.  Fallback activates at 41.376416 seconds with 183,808 held PCM frames and no timestamp-derived audio due; draining the output reserve before each scheduled run succeeds, but admitting only one 2,048-frame batch per Program Stream scheduler pass is slightly slower than the disc's decoded AC-3 bursts.  Held PCM consequently rises to 193,024 frames, crosses the unchanged 192,000-frame safety ceiling about 4.37 seconds later, and deliberately terminates the helper with exit status one at 45.764969 seconds before the menu can play.  Main reports `helper-error`; there is no reserve-pacing failure, audio underrun, PCM protocol error, decoder error or overlay ordering error.  The checksum-valid schema-21 snapshot is an earlier settled-overlay capture with 127 displayed pictures, 126 swaps, zero decoder and PCM errors, zero underruns and one valid visible menu overlay; the later screenshot shows the black post-exit diagnostic display.  The 1,083,151-byte log, 11,711-byte screenshot and 844-byte telemetry sidecar have SHA-256 `c74ffb51e544a2ab233fc66164d2ec00694e6c14fba86c4b3c4757e3a842add0`, `915763d7b660d4b82ef007c02f78f655c43c59c3dff4eccea59c6769a9c1b4f8` and `335b0923d031579f9cfb03c19d8320563c5089243b762857569ca1a72ad05f46`.

#### Next Steps:

Retain the source-`67ce19d` reserve-drain pacing boundary but replace its fixed one-batch ceiling after user approval with a pressure-driven bounded burst that emits sink-paced 2,048-frame runs until held PCM reaches a safe low watermark below the four-second ceiling.  Bound each admission interval so menu input remains responsive, add production regressions in which a single Program Stream packet decodes more PCM than one batch and verify that held audio falls rather than grows under a stalled timestamp, then rerun strict native, analyzer, sanitizer and retained DVD/audio suites and build only a new static ARM helper for Futurama plus the broader physical-disc menu test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 954 COMMIT Unreleased 67ce19d 2026-09-03T20:08:11-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Bound automatic-menu fallback output latency across physical DVDs without weakening normal title buffering.

#### Outcome:

Source `67ce19d` adds one fallback-aware PCM emission boundary: while a physical DVD's automatic menu is using sink pacing, each scheduled PCM run first drains the asynchronous output reserve, and the fallback itself admits at most one 2,048-frame batch per scheduler pass.  This prevents the four-megabyte normal lane from absorbing approximately twenty seconds of decoded PCM and lets the pipe and unchanged FPGA FIFO credit establish delivery rate, while ordinary advancing-timestamp scheduling, normal title use of the complete optical-stall reserve, overlay priority and byte order remain unchanged.  The production regression starts with 24,000 held frames, proves the first exhausted-target pass emits exactly one batch, repeatedly reaches the exact 8,192-frame reserve and reconstructs all 15,808 emitted stereo frames sample-for-sample through the real reserve; its advancing-PTS control restores the original scheduler.  Strict optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer checks pass, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests, twenty repeated production runs, one hundred menu-hop runs and fifty output-reserve runs.  Real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `6b7524f082e81e3b6f9e49064deea7950804438485bed366e7089b1b434b2da7`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`67ce19d` artifact and retain the current per-core Main, RBF and visualizer.  Test Futurama plus several other physical DVDs that previously delayed at automatic menus; each affected route should log one fallback activation containing `paced_batch=2048`, reach moving menu video and a usable selector without the prior long apparent freeze, retain continuous intelligible audio and show no pacing failure, hold-limit diagnostic, underrun or helper termination.  Launch titles and exercise chapter navigation on at least one disc to confirm the unchanged ordinary reserve path, then return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 953 COMMIT Unreleased 5f1cf92 2026-09-03T19:51:25-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Qualify source `5f1cf92` across Futurama's automatic root menu, nested episode-selection menus and selected-title playback.

#### Outcome:

The physical source-`5f1cf92` run passes hardware validation.  All three finite intro boundaries drain and release, automatic menu entry at 35.059491 seconds preserves the continuous decoder epoch, and the bounded fallback activates with 183,808 held PCM frames before settling near its 8,192-frame reserve without a hold-limit diagnostic, signal-nine termination or audio underrun.  The root menu initially appears frozen while the output path consumes an approximately 1.16 to 1.21 million-frame PCM scheduling lead, about 24 to 25 seconds, but then animates normally and accepts directional input; this is observable catch-up latency rather than a decoder deadlock.  Root-menu activation, nested episode-selection transitions and their overlay transactions complete, the final selection leaves the menu at 327.905704 seconds, and the chosen episode sustains advancing presentation timestamps for more than ninety seconds with over 77 MiB of helper video delivered.  The user confirms the menus are navigable and the selected episode looks and sounds good.  The checksum-valid schema-21 snapshot reports 128 displayed pictures, 127 swaps, zero decoder and PCM protocol errors, zero audio underruns and a valid overlay, while the updated screenshot visibly captures episode playback.  The 17,823,653-byte log, 1,386,067-byte screenshot and 818-byte telemetry sidecar have SHA-256 `4e31c76f52ab03fa55a38027c314064306d4ff9ac8d8b5a3056666d35e41eea7`, `e6511bd6c54ccab344419b1c703b38d61430c1073790293f1d11fef66e0273ce` and `9e6ede6ae979d7a24a16133f9ec1237dc3c4f4dda7bc444c4a84494f26052633`.

#### Next Steps:

Retain source `5f1cf92` and its helper as the accepted hardware baseline.  Treat the initial automatic-menu catch-up as a future latency optimization rather than reopening the functional fix, and broaden physical-disc regression to other automatic menus, still menus and supported title audio before the next release boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 952 COMMIT Unreleased 5f1cf92 2026-09-03T18:36:35-07:00

#### Coming From:

Unreleased 0df8570

#### Purpose:

Bound automatic-menu PCM scheduling when a repeated video timestamp exhausts the normal timestamp-derived audio target.

#### Outcome:

Source `5f1cf92` preserves the continuous automatic-menu decoder epoch and normal advancing-PTS scheduler while recognizing three equivalent stalled-horizon conditions confined to that epoch: video remaining at the first audio PTS, a repeated video PTS, or 256 KiB of delivered video without a PTS advance.  After the timestamp-derived target is exhausted, decoded PCM above the existing 8,192-frame reserve drains completely as individually bounded 2,048-frame batches through the unchanged output and FPGA FIFO-credit path; any later PTS advance disables fallback before the new target is evaluated.  A post-drain 48,000-frame hold invariant now reports and rejects an impossible growing queue instead of allowing host memory exhaustion.  The production test delivers 100,000 patterned stereo frames with exact sample reconstruction, an exact terminal reserve and more than 2 MiB of byte-exact continuous menu video under repeated PTS, verifies the advancing-PTS control remains on its original 2,048-frame timestamp batch, and exercises the hard-limit rejection.  Strict optimized, GCC analyzer, AddressSanitizer, UndefinedBehaviorSanitizer, twenty repeated production runs, native helper, DVD random-access, SPU, menu-hop, output reserve and staging, AC-3 resynchronization, unsupported-LPCM, audio UI, visualizer and seek tests pass.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `a919e4f202d9de9ce996fdfbacbe11c6da815d21e043af0e1f6a6446e2d591f1`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`5f1cf92` artifact and retain the current per-core Main and RBF, then rerun Futurama disc one through the complete intro into its moving menu.  Confirm one `automatic menu PCM fallback activated` diagnostic, continuous intelligible audio without periodic bursts, a responsive selector, held PCM remaining near the 8,192-frame reserve rather than growing by millions of frames, no hold-limit diagnostic and no signal-nine termination; return the updated helper/Main log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 951 COMMIT Unreleased 0df8570 2026-09-03T18:32:13-07:00

#### Coming From:

Unreleased 0df8570

#### Purpose:

Qualify the continuous automatic-menu epoch on Futurama disc one and isolate its remaining burst-audio failure.

#### Outcome:

The physical source-`0df8570` run validates the continuous decoder correction but rejects its audio scheduling.  All three finite intro boundaries complete, automatic menu entry at 43.904862 seconds produces the new helper-only scheduling and PTS epochs without a fourth Main decoder reset, the menu becomes visible and animated, and the user confirms its selector responds.  The checksum-valid schema-21 capture reports 128 displayed pictures and 127 swaps in 4.423730 seconds, zero decoder flags, zero PCM protocol errors and a valid overlay; Main records eighty-two complete overlay commits with no ordering error and no video lookahead failure.  At menu entry the first raw PTS 45,045 is translated to 647,273, equal to the later maximum video horizon, so the audio target remains fixed at the 8,192-frame reserve for the entire run.  The scheduler consequently emits only its 128-frame safety refill per 4,096 video bytes, averaging about 4,270 frames per second instead of 48,000 and matching the reported periodic distorted bursts, while AC-3 decode accumulates unchecked: the final progress record has emitted 591,360 frames but holds 118,129,152 frames, approximately 472.5 MiB of stereo PCM.  Linux then kills the helper with signal nine at 187.177284 seconds, consistent with exhausting the target's approximately 492 MiB visible RAM.  The 4,060,455-byte log, 637,658-byte screenshot and 844-byte telemetry sidecar have SHA-256 `f22b5b1808ac1bb94b8c19440e4c19079410d7c3fed86b5dff1f06925148dbba`, `1bdd9d344bb5b18584c6f04b258b7397b9285806ae4c0f995fcf986c11ed86dc` and `1322af6836d63a481d2fbab7b4815c84a6c95a6a38792eaeba79a139f3a47f19`.

#### Next Steps:

After user approval, preserve the source-`0df8570` continuous decoder/menu transition and normal advancing-PTS scheduler, but add an automatic-menu-only PCM fallback for an exhausted timestamp target: after startup, when decoded audio exceeds the existing reserve and the video horizon schedules nothing, emit the excess in bounded batches through the unchanged PCM transport so FPGA FIFO credit supplies the real-time 48 kHz backpressure instead of allowing an unbounded host queue.  Add a hard bounded-hold invariant and diagnostics, extend the production regression with repeated or nonadvancing menu video PTS plus sustained decoded PCM to prove continuous exact sample delivery, bounded memory, byte-exact video and unchanged advancing-PTS behavior, rerun strict native, analyzer, sanitizer and retained DVD/audio suites, then build only a new static ARM helper for another Futurama menu test; Main, protocol, RTL and RBF should remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 950 COMMIT Unreleased 0df8570 2026-09-03T17:53:57-07:00

#### Coming From:

Unreleased d7d5ab2

#### Purpose:

Carry a live silent-video decoder session continuously into an automatic DVD menu while starting a fresh synchronized helper scheduling epoch.

#### Outcome:

Source `0df8570` removes the automatic silent-video-to-menu READY/GO boundary while retaining every finite-still and explicit-navigation decoder boundary.  Silent-video release now includes the H.262 compatibility filter's pending byte in its capacity decision and flushes that byte through the bounded queue before switching to immediate output, preserving exact order.  Automatic menu entry keeps the live FPGA decoder and resident frame, rearms only helper audio and bounded scheduling state, leaves the initial sequence/I/reference filter disabled, and establishes one explicit PTS offset shared by menu video and audio above the preceding DVD timestamp.  The production regression releases a near-2 MiB silent first-play fixture byte-exactly, then schedules more than 2 MiB of picture-bearing menu video with no new sequence header alongside synchronized AC-3 without reaching the lookahead limit.  Optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer builds pass, as do the strict native static helper and retained DVD random-access, menu-hop, SPU, reserve, staging, unsupported-LPCM, audio UI, visualizer and seek tests.  GNU 10.2.1 builds the 966,052-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `af73f0d5ae8104ef05fa3270b51a5da3bf92b39189cd32fc9219b5d2ac0efb6c`; Main remains source `d7d5ab2`, and the protocol, decoder RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`0df8570` artifact, retain the source-`d7d5ab2` per-core Main and existing RBF, then rerun Futurama disc one through all finite intro stills, the complete 20th Century animation and the moving menu.  Confirm that menu entry produces the new `DVD automatic menu scheduling epoch continued` and `DVD automatic menu PTS epoch` diagnostics, no fourth Main decoder boundary, no `video lookahead limit exceeded`, visible menu motion and selector response; return the resulting log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 949 COMMIT Unreleased d7d5ab2 2026-09-03T17:49:51-07:00

#### Coming From:

Unreleased d7d5ab2

#### Purpose:

Qualify the boundary odd-byte correction on Futurama disc one and isolate the later black failure during its 20th Century transition.

#### Outcome:

The physical source-`d7d5ab2` run validates the corrected Main boundary path but rejects the complete host behavior.  All three finite first-play stills now finish and cross one decoder boundary each, the first two observed odd tails each log `pipe quiescent odd_tail=1` and submit their final byte, and every boundary reaches `released after drain`; the third session then qualifies a normal sequence/I/P restart group, releases 2,096,389 queued silent-video bytes and visibly advances into the 20th Century animation.  At 40.445047 seconds libdvdnav enters menu space while that live video session is still progressing, and the helper requests a fourth decoder boundary; Main drains 76,372 remaining bytes, resets the healthy decoder at 41.727776 seconds and leaves a black display.  The fresh menu epoch emits no H.262 restart diagnostic because its next 2,097,152 bytes never contain the sequence-header/I/reference combination required only after a decoder reset, although the helper accepts AC-3, publishes nine complete 86,400-byte overlay planes and remains responsive to an Up command that changes button one to four.  At 85.968714 seconds the queued video reaches the implementation guard and `video lookahead limit exceeded` deliberately exits the helper with code one.  Checksum-valid schema-21 telemetry confirms zero pictures and swaps in the reset session, nine valid overlay commits with no protocol error, and no audio underrun or transport block; the black 1,920-by-1,080 screenshot retains only the telemetry raster.  The 1,707,301-byte log, 1,557-byte screenshot and 480-byte telemetry sidecar have SHA-256 `9ec5ac166630067398f71e8226ed2c2b7a49f0cc68639ce43effc59bd3101789`, `5b3b2acf3c879c741b48e7d7a9c6c89b2ffc73f65b7ad1af633f7903491c421b` and `c5c1c9ba9f37749c4f0fa08b16d9ad56761fc12579b5b63b3739cd0509618f`.

#### Next Steps:

After user approval, preserve all finite-still decoder boundaries and the source-`d7d5ab2` Main correction, but stop resetting the already-live FPGA decoder solely because the continuous first-play video enters menu space.  Replace that automatic boundary with a helper-only audio and scheduling epoch transition that drains any pending H.262 normalization byte in original order, retains continuous decoder context and the resident picture, does not re-enable the initial random-access filter, and keeps the new menu's audio/video PTS relationship valid without a backward FPGA timestamp.  Add a production-path regression whose post-transition video exceeds 2 MiB without a new sequence header, proving byte-exact continuous delivery, bounded scheduling, synchronized AC-3 admission, overlay continuation and no Main READY/GO; retain finite-still boundaries, explicit navigation hops, late-audio rejection and sanitizer coverage, then build only a new ARM helper and retest Futurama through the complete animation into its moving menu.  Main, protocol, RTL and RBF should remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 948 COMMIT Unreleased d7d5ab2 2026-09-03T16:51:15-07:00

#### Coming From:

Unreleased ae533a1

#### Purpose:

Submit the final odd byte of an autonomous DVD boundary after nonblocking pipe quiescence instead of returning before the existing transport path.

#### Outcome:

Source `d7d5ab2` corrects the single Main control-flow defect demonstrated by the Futurama trace: after an autonomous boundary, nonblocking pipe quiescence with one buffered byte now falls through to the existing transport routine, which submits that real byte in a zero-padded 16-bit word, while ordinary non-boundary lone bytes remain held and `EINTR` remains nonterminal.  A later empty-pipe observation permits the existing reset and GO handshake, so no media byte is discarded and the control protocol, helper, RTL and RBF are unchanged.  The lifecycle regression covers ordinary hold, interrupted read, boundary odd-byte submission, empty-pipe release, exact byte accounting and a single reset/GO; optimized, AddressSanitizer plus UndefinedBehaviorSanitizer and GCC analyzer runs pass.  The production overlay-output regression passes optimized, AddressSanitizer and UndefinedBehaviorSanitizer runs, the patch applies cleanly to pinned Main `0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f`, and two local GNU 10.2.1 ARM builds are byte-identical.  The resulting 1,182,692-byte ARMv7 executable `host/build/MiSTer_MediaPlayer` has SHA-256 `250f065859f30150a4b8226072b254ff81f76e27e1b926d1c63ede0ef48bc121`; the unchanged 966,052-byte helper has SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72`.  The 1,335,713-byte archive `host/build/MiSTer_MediaPlayer_BoundaryByte_d7d5ab2.zip` has SHA-256 `0ef5a03055e39a52ea185064ca32b1a74c53f67fe0309200f72d0f38d6086783`; ZIP integrity, fresh extraction, executable modes and its five-file manifest verify.

#### Next Steps:

Leave `/media/fat/MiSTer` untouched, install the archive's `MiSTer_MediaPlayer` and `linux/MediaPlayer_Helper` at the paths documented in `INSTALL.txt`, merge only its `[MediaPlayer]` fragment, set both executables to mode 755 and reboot.  Retest Futurama through every finite first-play still into its visible moving menu with synchronized AC-3 and responsive activation.  The log should show the helper boundary request and Main boundary pending; when an odd tail exists it should then show `DVD stream boundary pipe quiescent odd_tail=1`, a one-byte transfer, `DVD stream boundary released after drain`, and helper release rather than repeated would-block polling.  Collect a fresh Main/helper log, screenshot and telemetry for acceptance or further isolation.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 947 COMMIT Unreleased ae533a1 2026-09-03T16:48:14-07:00

#### Coming From:

Unreleased ae533a1

#### Purpose:

Qualify the isolated-Main stream-boundary build on Futurama disc one and isolate its first finite-still freeze.

#### Outcome:

The physical source-`ae533a1` run confirms that the per-core Main selection works, but rejects the stream-boundary handshake as implemented.  Main starts the `MediaPlayer` core through its alternate executable and the helper completes the first authored ten-second FBI still, sends the autonomous boundary event and waits for GO.  Main receives that event at 20.234007 seconds after submitting 224,682 bytes, but retains one buffered byte and never records `DVD stream boundary released after drain`; more than four million later would-block polls submit no additional data through the 227-second capture endpoint.  The visible FBI frame and checksum-valid schema-21 snapshot show that this is a host-handshake deadlock rather than a decoder failure: the FPGA accepted 224,669 decoder bytes, exactly the 224,665-byte authored video plus the four-byte sequence end, completed and displayed its one I picture, reports sequence end, presentation complete and session quiet, and has zero decoder errors, transport blocks, PCM samples or audio underruns.  The five following zero bytes are implementation-only transport drain; four crossed Main before the terminal decoder stopped returning input credit and the fifth remains in Main's pipe buffer, so the current requirement that every boundary byte receive FPGA credit can never become true.  The 5,630,162-byte log, 685,317-byte screenshot and 441-byte telemetry sidecar have SHA-256 `24ff68036d13b73d674dca1bf349a5fb2041d4de4343ef3f0bbe8ac041732d45`, `afcb6905c04398c9bcf6f2aef795d55bbcc85c990000d90908b6bc88f6c84f3e` and `dfb936ef46bc9eb7324357e82d356be24c3f7646d4bc6183ba5e07e7880bfa52`.

#### Next Steps:

After user approval, distinguish a finite terminal boundary from an automatic silent-menu boundary on the control channel and give only the terminal form an explicit five-byte discardable-tail contract.  Main must continue submitting all meaningful queued media, then after pipe quiescence accept at most the declared number of remaining zero tail bytes, record their exact count, reset download once and send GO; a nonzero byte, an oversized remainder or any residue on the automatic boundary must fail rather than be hidden.  Extend the Main regression with the observed one-byte no-credit remainder plus zero-, partial- and malformed-tail cases, retain the helper production-path and sanitizer suites, rebuild the patched per-core Main and static ARM helper locally, and retest Futurama through every finite intro still into its moving menu without changing the RBF or RTL.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 946 COMMIT Unreleased ae533a1 2026-09-03T16:22:52-07:00

#### Coming From:

Unreleased ce5a826

#### Purpose:

Install the patched Main only for MediaPlayer so development testing no longer replaces the official system-wide MiSTer executable.

#### Outcome:

Source `ae533a1` makes `host/build/MiSTer_MediaPlayer` the canonical patched-Main output and adds a merge-only `MiSTer.ini` fragment containing the core-reported `[MediaPlayer]` section and `main=MiSTer_MediaPlayer`.  Current build and hardware-test guidance now installs that executable at `/media/fat/MiSTer_MediaPlayer`, retains `/media/fat/MiSTer` for every other core and explains the automatic return to official Main when the Menu core loads; the published v0.9.0 records remain unchanged as historical package provenance.  The pinned-Main build applies and compiles locally with GNU 10.2.1, shell syntax and the exact fragment contract pass, and the renamed 1,182,692-byte binary is byte-identical to the tested source-`ce5a826` Main at SHA-256 `99084bc5db9062e2984ec93f40158f4bfd4c265300b314c7a7ddbd6e8081f706`; the matched 966,052-byte helper remains SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72`.  The host-only test archive `host/build/MiSTer_MediaPlayer_StreamBoundary_ae533a1.zip` contains the two executables, merge fragment, installation and provenance notes plus a five-entry manifest; ZIP integrity and a fresh-extraction manifest check pass.  It is 1,335,862 bytes at SHA-256 `ab9601a2c1c1f08c42aeec842187d822d0b69ea8bb4ddd697c3a7ec42b18697c`.  Helper behavior, Main behavior, RTL, RBF and visualizer are unchanged from `ce5a826`.

#### Next Steps:

Leave `/media/fat/MiSTer` untouched, extract the test archive, copy `MiSTer_MediaPlayer` and `linux/MediaPlayer_Helper` to the paths in `INSTALL.txt`, merge only its `[MediaPlayer]` fragment at the end of the existing `/media/fat/MiSTer.ini`, set both executables to mode 755 and reboot.  Confirm MediaPlayer enters the alternate Main and returning to the Menu core returns to official Main, then run Futurama disc one through every finite intro still into its automatic menu.  Acceptance requires continued playback after each still, visible background and moving selector, synchronized AC-3, responsive activation and fresh log, screenshot and telemetry evidence from the matched pair.

#### Files Modified:

- README.md
- assets/MiSTer_MediaPlayer.ini.fragment
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/build_arm_stack.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 945 COMMIT Unreleased ce5a826 2026-09-03T06:33:43-07:00

#### Coming From:

Unreleased cea2add

#### Purpose:

Reopen the FPGA decoder at autonomous DVD stream boundaries without discarding the completed still or hiding the late-audio synchronization failure.

#### Outcome:

Source `ce5a826` adds control event `0x86` as a coordinated helper/Main stream boundary.  Every expired finite DVD still now drains its intentional sequence-end transport, and an automatic menu transition out of a silent epoch preserves the already-consumed Program Stream start code; in both cases the helper flushes its exclusive reserve, resets demux, audio, PTS, random-access and bounded scheduling state, sends the boundary event and waits for GO.  Main continues submitting through an exact pipe-empty observation, including an odd final byte, then toggles download exactly once and releases the helper without discarding old media or clearing the overlay.  Input polls the control socket before acting and all controls are suppressed during the boundary, while a paused session still drains it.  Static inspection established that `dvdmenu:` and `isomenu:` deliberately bypass the optical prefetch ring, so their libdvdnav state is already consumer-synchronous and `media_source.c` required no change.  The focused production-translation-unit and Main lifecycle regressions pass optimized strict builds, AddressSanitizer and UndefinedBehaviorSanitizer; focused GCC analysis passes with the established audio-overlay leak false positive suppressed.  The updated patch applies to pinned Main `0a8fb44` and both local GNU 10.2.1 ARM builds succeed.  `host/build/MiSTer_StreamBoundary_ce5a826` is 1,182,692 bytes at SHA-256 `99084bc5db9062e2984ec93f40158f4bfd4c265300b314c7a7ddbd6e8081f706`; the static stripped ARMv7 `host/build/MediaPlayer_Helper_StreamBoundary_ce5a826` is 966,052 bytes at SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72` and has no dynamic section.  RTL and the RBF are unchanged.

#### Next Steps:

Install the matched `MiSTer_StreamBoundary_ce5a826` and `MediaPlayer_Helper_StreamBoundary_ce5a826`, preserving the accepted RBF and visualizer, and reboot for Main.  Run Futurama disc one from first-play through all finite intro stills into the automatic menu; require one `DVD stream boundary pending` and `released after drain` pair for each terminal still, fresh accepted-byte progress after every reset, visible menu background and selector movement, synchronized AC-3, overlay records in the active telemetry session, title activation and return-to-menu.  Then recheck Blazing Saddles redundant-root behavior, Coming to America overlay-only Scene Selections, The Big Lebowski navigation and the forum disc's silent LPCM menu before accepting the matched host pair on hardware.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_dvd_overlay_output.c
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 944 COMMIT Unreleased cea2add 2026-09-03T06:15:39-07:00

#### Coming From:

Unreleased cea2add

#### Purpose:

Use the physical Futurama result to distinguish the automatic-menu scheduler correction from an earlier terminal-still decoder-session freeze.

#### Outcome:

The physical `FUTURAMA_S1D1` run rejects source `cea2add` visually but proves the helper did not freeze.  The first authored ten-second still is finalized from 224,665 bytes of sequence-plus-I video, receives sequence end and transport drain, and is the only payload the schema-21 FPGA snapshot accepts: 224,780 bytes, one I picture, one reference and one displayed picture, sequence-end seen and presentation complete, with zero decoder error flags, transport blocks or audio underruns.  Three finite-still expirations then resume the same completed download session without a READY/GO decoder reset.  The helper continues, classifies later first-play video silent, enters the menu at 40.449462 seconds, rearms source `cea2add`, selects AC-3 substream `0x80`, publishes seven complete overlay planes and accepts an Up command at 63.111029 seconds that changes the authored button from one to four; it remains alive beyond 71 seconds.  Main submits through overlay offset 9,035,621, but telemetry retains zero overlay records, zero PCM samples and the first still's 224,780 accepted bytes, proving every later video, audio and overlay record remains outside the terminal FPGA session.  The black 1,600-by-1,200 screenshot contains valid telemetry but no decoded menu background.  The 1,477,359-byte log, 2,788-byte screenshot and 441-byte sidecar have SHA-256 `19bf6160b410268650e34db63b7507c1d7f5b21396a4d9314da5ebe3fc9d7518`, `bba7649ac2ac61c546f485a5f52d6f9bd09a7b9e4b17552b7ee0aed2ea380a1d` and `abe2bbe935177401657cdb1090b2e3b8b63d3c17368ccd20e4d5a990bf57318c`.  The helper-only menu rearm is therefore insufficient because it cannot reopen an FPGA session already closed by the first finite still.

#### Next Steps:

After user approval, replace the helper-only assumption with an explicit autonomous DVD stream-boundary handshake shared by Main and the helper while retaining the decoder and RTL.  Associate buffered libdvdnav transition metadata with its consumed payload position rather than exposing producer-ahead menu state; when a finite authored still expires or a synchronized automatic menu domain begins after a terminal or silent epoch, finish the intentional old transport, notify Main without requiring a user navigation command, drain rather than discard the completed boundary, deassert and reassert download exactly once, then send GO so the helper resets demux, audio, PTS, random-access and bounded scheduling before consuming the new epoch.  Remove the unsynchronized `cea2add` post-`find_start_code` rearm.  Add regressions for multiple finite first-play stills followed by a silent segment and an automatic video-plus-AC-3 menu, verifying one decoder reset per terminal boundary, consumer-position menu notification, accepted background video, PCM and overlay records, while retaining directional continuations, explicit navigation hops, staged menus, silent Program Streams, late-audio rejection, reserve ownership, seek, audio and sanitizer coverage.  Build Main and the static ARM helper locally; no RTL simulation is required unless implementation evidence unexpectedly reaches the transport decoder.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

