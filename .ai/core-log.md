## 970 COMMIT Unreleased 6ac6895 2026-09-12T07:39:05-07:00

#### Coming From:

Unreleased 24a6bda

#### Purpose:

Fix the `.mpg` progress overlay flashing briefly then going missing after every seek, even though `24a6bda` fixed the pause reveal correctly.

#### Outcome:

The user reported that skipping forward/backward briefly flashes the overlay, then the screen goes black before the video resumes at the new position, after which the overlay is gone.  A screenshot of a paused mid-test frame confirmed the resumed video itself is completely clean, isolating this to the overlay specifically.  Investigation found `mpeg2_h262_native_startup` (instantiated in `MediaPlayer.sv`), a module that blanks the screen (forcing `base_de` low via `mpeg2_new_startup_video_blank`) until either the first picture is shown or a `bypass_event` fires; the DVD-style overlay compositor's `overlay_sample_valid` also requires `base_de`, so nothing can composite during that blank window.  The user identified its origin directly: it was added specifically to hide genuinely corrupt video while skipping DVD chapters (a mid-GOP splice glitch crossing program chain segments), not for `.mpg` seeking.  Its reset was `reset_mpeg2`, which includes the Entry 237 rearm pulse fired on every seek, so this module's "startup done" latch (`decided`/`bypass`/`shown`) re-armed and re-blanked the screen on every plain `.mpg` seek too - the same class of bug already fixed twice tonight for `mpeg2_h262_audio_ui` (`b0372f6`) and the luma framebuffer (`1b1ab7a`).  A literal git revert of the module's history was not practical (three prior commits including a full native-480p rewrite would be unwound); DVD chapter navigation is out of scope for this project now, and a plain `.mpg` seek decodes straight from a GOP boundary and never produces the corruption this blank existed to hide, matching the clean resumed-video screenshot.

#### Next Steps:

Source `6ac6895` changes `mpeg2_h262_native_startup`'s reset from `reset_mpeg2` to `reset_mpeg2_base`, so "startup done" latches once at the true first load and never re-blanks the screen on a seek again; `swaps_enabled` staying permanently true afterward is correct (it only ever gated the first frame swap until a complete picture was ready) and its only other consumer is an unrelated development-only diagnostic condition.  This touches RTL, so a 3-seed Quartus build is required; deliver the RBF for the user to retest: seeking on `.mpg` should no longer blank the screen or lose the progress overlay, while the video itself and ordinary `.mpg`/audio-player behavior remain unaffected.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [ ] Built
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

## 943 COMMIT Unreleased cea2add 2026-09-03T05:54:12-07:00

#### Coming From:

Unreleased 401148e

#### Purpose:

Rearm bounded Program Stream scheduling when a silent first-play DVD epoch automatically enters an authored menu with its own synchronized audio timeline.

#### Outcome:

Source `cea2add` fixes the stale-state cause without weakening the late-audio guard.  `process_program_stream` now refreshes libdvdnav menu state immediately after `find_start_code` exposes a new block and before that payload is processed; a false-to-true menu transition rearms output only when the preceding epoch was already classified silent.  The rearm uses the established navigation reset to reacquire initial random-access video, PTS normalization, bounded lookahead and PCM startup hold while preserving the output reserve and activation stage and emitting no decoder barrier, Main reset or overlay clear, so the prior resident frame remains available until menu video replaces it.  The production-translation-unit regression queues 2,097,144 bytes of silent first-play video with PTS 151,777, proves the old state rejects AC-3 PTS 45,045 as 106,732 ticks behind, rearms the automatic menu epoch, qualifies fresh sequence/I/P video at PTS 45,045 and accepts that synchronized AC-3 through the real private-PES path.  Strict optimized compilation, focused GCC analyzer, AddressSanitizer address checks, UndefinedBehaviorSanitizer, DVD random-access, SPU, menu-hop, overlay, reserve, staging, AC-3 recovery, Program Stream seek, private LPCM skip, audio UI, visualizer and audio-file seek tests pass; LeakSanitizer remains unavailable in the ptrace-hosted local environment.  Local GNU 10.2.1 produced the 966,052-byte static stripped ARMv7 EABI5 helper `host/build/MediaPlayer_Helper_MenuEpoch_cea2add` with SHA-256 `23547d0d777cbc666759f0623d6b7d5b899902698a95e7da98c914405926791e`; it has no dynamic section, passes its protocol-one capability probe and passes real MP3, WAV, FLAC, Ogg and private-LPCM integrations under local ARM execution.  Main, media-source navigation policy, decoder, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_MenuEpoch_cea2add`, preserve executable mode and retain the accepted v0.9.0 Main, visualizer and RBF.  Run the same `FUTURAMA_S1D1` physical disc from first-play into its automatic menu with telemetry; acceptance requires the silent lookahead record followed by `DVD menu entered` and `DVD automatic menu scheduling epoch rearmed`, a surviving helper, audible synchronized menu AC-3 and visibly moving selector highlights.  Activate a title, return to the menu and exercise each selector direction once, then return fresh log, screenshot and telemetry results.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 942 COMMIT Unreleased 401148e 2026-09-03T05:40:29-07:00

#### Coming From:

Unreleased 401148e

#### Purpose:

Use the source-`401148e` Futurama diagnostic to distinguish a safely future late-audio packet from stale silent-video state crossing an automatic DVD menu transition.

#### Outcome:

The fresh `FUTURAMA_S1D1` run reproduces the expected helper exit and supplies both bounded diagnostic records.  Before libdvdnav reports entry into the authored menu, the helper classifies the active DVD session as silent at the 2 MiB queue boundary, releasing 2,096,723 queued bytes at 2,321,525 total video bytes with two picture marks and a maximum video PTS of 151,777.  It then remains in permanent silent mode across the automatic menu-domain transition and emits 8,636,808 total video bytes before encountering the menu's valid AC-3 substream `0x80`.  That first audio packet has PTS 45,045, which is 106,732 90 kHz ticks, approximately 1.186 seconds, behind the retained video horizon; accepting it at the existing rejection point would therefore start audio late rather than restore synchronization.  The checksum-valid schema-21 snapshot again reports one completed and displayed I picture, sequence-end and presentation completion, zero decoder errors, zero transport blocks and zero audio underruns.  Main observes the expected exit-code-one helper EOF only after draining reserved output.  The 1,078,836-byte log, 637,394-byte screenshot and 441-byte sidecar have SHA-256 `5ee82e04ed9e510db88dffcafd2a70f28b3f68f341925048a3039f7e9a707ba3`, `a6a8c0694187aa92fde5509c54b4785a498276d33d785dccccb8e40cbeffe205` and `3c852112765d9bf2b432454813449353e9c66b02cf828fa31aef1acd92f408bf`.  The diagnostic succeeds and local source remains unchanged.

#### Next Steps:

After user approval, preserve the 2 MiB bound and the late-audio fail-fast guard while treating an automatic DVD transition from first-play/title space into menu space during silent-video mode as a new scheduling epoch.  Refresh the DVD menu state immediately after source reads expose the transition and before processing that payload, then rearm bounded video lookahead, the initial random-access filter, PTS state and PCM startup hold without clearing the resident frame, resetting Main or changing libdvdnav navigation.  Add a production-path regression that begins with more than 2 MiB of silent first-play video, enters a menu, and then supplies synchronized video plus AC-3, proving that the old source-`401148e` path rejects it while the corrected epoch accepts and schedules it; retain genuinely silent Program Stream completion, out-of-epoch late-audio rejection, automatic menu exit, authored still, overlay, staging, navigation, audio and sanitizer coverage.  Build only a new static ARM helper locally for Futurama menu, selector, title launch and return-to-menu testing while retaining the accepted v0.9.0 Main, RBF and visualizer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 941 COMMIT Unreleased 401148e 2026-09-03T04:56:54-07:00

#### Coming From:

v0.9.0 b1a6dcb

#### Purpose:

Instrument and reproduce Futurama's late-menu-audio rejection so the permanent silent-video classification can be corrected without hiding an A/V synchronization failure.

#### Outcome:

The fresh `FUTURAMA_S1D1` physical-disc capture reaches its authored menu, publishes one valid still and selector overlay, and then leaves that frame resident after the helper exits normally with status one.  The checksum-valid schema-21 snapshot reports one completed and displayed I picture, sequence-end and presentation completion, zero decoder error flags, zero transport blocks and zero audio underruns.  The helper log identifies the software boundary: before any audio PES appears, the bounded 2 MiB video queue fills and `scheduler_release_silent_video()` irreversibly disables scheduling; the later valid AC-3 private substream `0x80` reaches the deliberate late-audio rejection, after which Main drains the already-reserved bytes and observes helper EOF.  Source `401148e` preserves that fail-fast behavior and every media byte while logging the exact silent-release queue, released and total-video counts, picture count and final video PTS horizon, followed by the late MPEG Layer II, AC-3 or DTS packet's PTS validity, value, horizon relation and absolute 90 kHz delta.  The focused production-translation-unit regression forces the 2 MiB boundary, proves its queued video remains byte-identical and verifies ahead, behind and untimestamped late-audio diagnostics.  Strict optimized compilation, focused GCC analyzer, AddressSanitizer, UndefinedBehaviorSanitizer, DVD random-access, SPU, overlay, reserve, output-stage, menu-hop, private-LPCM-skip, AC-3 recovery, Program Stream seek, audio UI, visualizer and audio-seek tests pass.  Real MP3, WAV, FLAC and Ogg integrations pass against both native and final ARM helpers with 378 or 381 pictures and one clear record per file.  Local GNU 10.2.1 produced the 966,052-byte static stripped ARMv7 EABI5 helper `host/build/MediaPlayer_Helper_LateAudioDiag_401148e` with SHA-256 `19020ff3e785718854fe399f23462720428012129082335f9c3c61414fa371c7`; its protocol-one capability probe passes and it has no dynamic section.  Main, decoder, RBF, visualizer and RTL are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_LateAudioDiag_401148e`, preserving executable mode and the installed Main, RBF and visualizer.  Enable telemetry, launch Futurama disc one, wait until the menu and selector appear and allow the helper to reach its expected clean rejection without needing to press a direction.  Return the fresh helper log; its `video lookahead classified silent` and expanded `AC-3 audio begins beyond` records will establish whether the first audio PTS is ahead of, equal to or behind the already-released video horizon.  Do not suppress the rejection or increase the queue from this diagnostic evidence alone; use the measured temporal relationship to propose the bounded state transition that retains genuinely silent Program Streams and synchronized late-starting DVD audio.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 940 COMMIT Unreleased 177886b 2026-09-03T03:51:20-07:00

#### Coming From:

Unreleased 7759f87

#### Purpose:

Qualify, document and package the accepted v0.9.0 runtime set for the user's GitHub release publication.

#### Outcome:

The user reports that the complete v0.9.0 functional and regression matrix looks good and accepts the exact runtime set for release.  At the user's explicit direction, packaging invoked no build: it retained the already clean, reproducible, timing-qualified source-`dfe1057` RBF and byte-identical accepted source-`3689cca` Main, source-`0f1165c` helper and source-`366a227` visualizer pack with source-`932dc22` behavior.  The helper's protocol-one capability probe passes.  `host/build/MiSTer_Media_Player_v0.9.0.zip` contains the five runtime/launcher payloads, installation and source notes, the project licence, seven dependency licences and a 15-entry SHA-256 manifest.  A fresh extraction is byte-identical to its bounded staging directory, every manifest entry passes, ZIP integrity is clean, and Main/helper retain mode 755 while all other files use mode 644.  The 6,580,818-byte archive has SHA-256 `e8bc8e0c25291df85d6d53ad2688995d30ce156c547b7315b08058052863e1f9`; its 16 files total 10,476,902 uncompressed bytes.  Source `177886b` moves the changelog into the dated v0.9.0 milestone, starts a clean Unreleased section and finalizes the README, release notes, architecture, build and test guidance with the exact package identity, accepted validation and no-rebuild provenance.  Documentation link, fence, whitespace, package-identity and staged-diff audits pass.  No tag or GitHub Release was created.

#### Next Steps:

The repository and package are ready for the project owner to create annotated tag `v0.9.0` on the final metadata commit following source `177886b`, create a GitHub pre-release titled `MiSTer Media Player v0.9.0`, attach `host/build/MiSTer_Media_Player_v0.9.0.zip`, and use `docs/RELEASE_NOTES_v0.9.0.md` as the release description.  After publication, record the tag resolution, GitHub release time and downloaded-asset verification in a VERSION entry without changing the accepted runtime payloads.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/RELEASE_NOTES_v0.9.0.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---

## 939 COMMIT Unreleased 7759f87 2026-09-03T03:19:43-07:00

#### Coming From:

Unreleased 0f1165c

#### Purpose:

Prepare the repository documentation and release-candidate notes for the v0.9.0 capability set accumulated since v0.8.0.

#### Outcome:

The user reports that the source-`0f1165c` candidate looks good and is conducting the final functional and regression pass independently.  Source `7759f87` reconciles the README, changelog, architecture, build and hardware-test documentation with the complete v0.9.0 candidate: native 480p and expanded native-480i decoding, Program Stream seeking and replay-ready EOF, standalone consumer audio and its timed visualizer overlay, encrypted ISO and direct-optical DVD playback, authored menus and scene selection, unsupported LPCM behavior, telemetry and current limitations.  It adds dedicated v0.9.0 release-candidate notes with the tested component identities, exact candidate artifact hashes and established timing/resources while explicitly reserving publication provenance for the clean release build.  It also adds a focused media-preparation guide and promotes the user's 720-by-480 exact-24-fps MPEG-2 Program Stream FFmpeg command as the project recipe.  That command produces the documented Main Profile, 4:2:0, 32:27-SAR output with a 48 kHz 320-kilobit MP2 track and also succeeds without an input audio stream; local links, code fences, whitespace and staged-diff checks pass.  No runtime source or artifact changed.

#### Next Steps:

Complete the user's functional and regression matrix, then perform the required clean/from-scratch Quartus, helper, Main and visualizer release build from the exact accepted source.  Once those artifacts reproduce and pass the final hardware gate, update the changelog from Unreleased to the dated v0.9.0 boundary, replace candidate language with final package filenames and hashes, and have the user create the annotated tag and pre-release from that exact documentation commit.  Do not tag or publish v0.9.0 before those gates close.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/RELEASE_NOTES_v0.9.0.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 938 COMMIT Unreleased 0f1165c 2026-09-03T02:28:26-07:00

#### Coming From:

Unreleased 490dc02

#### Purpose:

Normalize each qualifying malformed DVD H.262 sequence boundary across PES fragmentation instead of correcting only the session's initial random-access group.

#### Outcome:

Source `0f1165c` replaces the startup-only correction boundary with a DVD/ISO elementary-video compatibility filter that carries sequence, picture and extension syntax state across PES payloads and delays exactly one byte.  That lookahead validates `progressive_frame` before conditionally setting the preceding zero `chroma_420_type` bit on only the first valid complete-frame I picture after a 4:2:0 sequence header; stream length, byte order, offsets and timestamp-record order remain exact, navigation reset discards the old held suffix, and authored-still or ordinary stream completion flushes it.  Every correction logs its cumulative elementary-stream offset and before/after byte.  The focused C regression joins two captured malformed Big Lebowski prefixes and proves exactly offsets 185 and 380 change from `0xc0` to `0xc1` under every possible single split and one-byte fragmentation, while conforming, non-4:2:0, non-I, field and interlaced controls remain byte-identical.  Icarus reproduces source 21 on the original prefix and admits two consecutive corrected stills with supported film fields and no syntax error.  Strict native and ARM helper builds, ASan/UBSan, focused GCC analyzer, one hundred random-access, menu-hop, reserve and staging repetitions, twenty overlay and SPU repetitions, Program Stream seek, audio seek/UI/visualizer and unsupported-LPCM tests pass.  The exact ARM helper passes its capability probe and real MP3/WAV/FLAC/Ogg integration with 378 or 381 pictures and one clear record per file.  The static stripped ARMv7 EABI5 artifact `host/build/MediaPlayer_Helper_H262Stream_0f1165c` is 966052 bytes with SHA-256 `613d35de5ace0622584ae14b4540423c2c56b1f923c02c599f47b55722e21e56`; Main, RBF and visualizer are unchanged.

#### Next Steps:

Exit MediaPlayer, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_H262Stream_0f1165c`, preserve executable mode and retain the installed Main, visualizer and timing-qualified RBF.  With telemetry enabled, start The Big Lebowski and require correction one at elementary offset 185, a second correction when the following seven-second still begins, accepted bytes advancing beyond the former 5,670-byte failure boundary, error flags remaining zero and normal title playback beginning.  Press `m`, exercise the Root Menu and Scene Selection repeatedly, return to the title and reopen both paths, then verify each new malformed authored sequence is corrected without a helper exit or decoder latch.  Spot-check Blazing Saddles and Coming to America title, menu and chapter navigation before returning the fresh log, screenshot and telemetry sidecar.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_h262_restart_normalization.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 937 COMMIT Unreleased 490dc02 2026-09-03T00:41:17-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Normalize The Big Lebowski's nonconforming 4:2:0 progressive-frame chroma flag at the helper's buffered initial I-picture boundary.

#### Outcome:

Implemented the helper-only compatibility normalization approved from entry 936's byte-exact physical evidence.  Immediately after successful random-access filtering, the helper now changes only `chroma_420_type` from zero to one when the buffered restart has a valid 4:2:0 sequence extension and a valid initial complete-frame progressive I-picture coding extension; conforming streams and out-of-scope malformed streams remain byte-identical, stream length and every offset remain unchanged, and the exact offset plus before/after byte are logged.  The captured 191-byte Big Lebowski prefix changes only byte 185 from `0xc0` to `0xc1` and is idempotent.  Its original form raises RTL syntax source 21, while the corrected form reaches the first slice with no syntax error and is accepted as a supported phase-1/native-film picture.  Strict focused C, ASan/UBSan, GCC analyzer, DVD random-access/menu-hop/overlay/SPU/staging/reserve/program-stream, audio seek/UI/visualizer, native static-helper capability and private audio/LPCM tests passed.  The exact ARM release artifact also passed its capability probe and real MP3/WAV/FLAC/Ogg visualizer integration (378/381 pictures and one clear record per file).  No Main, RBF or visualizer change was made.  Built `host/build/MediaPlayer_Helper_ChromaFix_490dc02`, 966052 bytes, SHA-256 `0d99ce70d703eb9486052f8673474aed0b85446e321b73d0d640573f79d3d2c0`.  Physical testing rejects this build for The Big Lebowski while confirming Blazing Saddles remains accepted.  The helper normalizes the first three-second authored still at offset 185 from `0xc0` to `0xc1`; telemetry proves that picture completes, displays and reaches presentation completion with no overlay or presentation fault.  After the still expires, libdvdnav supplies a second seven-second still but `iso_start_filter_active` is already clear, so the normalization is not revisited.  Telemetry then latches H.262 error flag `0x0001` at 5,670 accepted bytes: exactly the first corrected still's 5,473 bytes plus its nine-byte terminal tail plus 188 bytes of the next stream, reproducing the prior source-21 acceptance boundary.  The helper remains alive and continues supplying more than 122 MB, excluding CSS, drive, helper-exit and transport starvation failures.  The 1,178,545-byte log, 1,514-byte screenshot and checksum-valid 441-byte schema-21 sidecar have SHA-256 `9a7607eeeb9ab9030dc8c9d00f1ca03947bc74e91b142374f3cf10c7e347215e`, `3b8e91889e3b2ae78208151f07361f2b540d3f911c330c2916702cb2915d143c` and `4cdc025cc7864ab8449aee283afca0ec433e4e540f04ec8358b3673bae966ad3`.

#### Next Steps:

The next helper-only change should apply the identical narrow normalization at every qualifying DVD elementary-video sequence/I-picture boundary rather than only the session's first random-access group.  Preserve the one-bit 4:2:0/progressive-I gating, byte count, offsets, decoder, RBF and Main; handle start codes and extension fields split across PES payloads with bounded state; and log each correction.  Add regressions containing two consecutive captured malformed stills, deliberately split every relevant header across payload boundaries, plus conforming and out-of-scope controls.  Require both stills to clear source 21 in Icarus before another ARM helper build and physical Big Lebowski startup, title, Root Menu and repeated-menu test, while retaining Blazing Saddles and Coming to America acceptance.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_h262_restart_normalization.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 936 COMMIT Unreleased ac13724 2026-09-03T00:38:42-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Use the source-`ac13724` physical-disc diagnostics to identify The Big Lebowski's common startup and Root Menu H.262 rejection.

#### Outcome:

The user reports that the complete forum ZIP works perfectly on a fresh MiSTer, and after creating that installation's initially absent `/media/fat/screenshots` directory the intended capture succeeds.  The startup still terminal-filters 5,473 bytes and the Root Menu still terminal-filters 128,368 bytes, both with sequence offset zero and I-picture offset 170; their 256-byte prefixes are identical through byte 190 and first differ only in slice payload byte 191, after the decoder has already failed.  Both carry a 720-by-480, aspect-code-two, rate-code-four sequence with valid marker, sequence extension `148200010000` identifying profile/level `0x48`, non-progressive sequence and 4:2:0 chroma, followed by the same I frame and picture-coding extension `8ffff3c080`: all four `f_code` values are 15, picture structure is frame, frame prediction is set, concealment is clear, `progressive_frame` is one and `chroma_420_type` is zero.  Project reference H262-033 and H.262 6.3.10 require `chroma_420_type` to equal `progressive_frame` for 4:2:0; the frontend's source-21 check is the unique early check violated by these fields, and it evaluates on stream byte 186 immediately before the first slice at byte 187, matching the reset session's 188 accepted bytes, error flag `0x0001`, and zero completed or displayed pictures.  The helper remains alive beyond 386 seconds and Main submits more than 912 MB, excluding a transport or helper failure.  The 6,497,185-byte log, 1,451-byte screenshot and 376-byte checksum-valid schema-21 sidecar have SHA-256 `140890eff54f08712d07da8d9bf4d85034c8b3e5038195047c11ad181a958c0d`, `8cfc68f0bb767f52ce2ac7ca38d101ff349639b3b7e21bd1d5a80f979e58ce97` and `a720e6a6355b778971f8138b56e9940e55045d21babde553343919f9cb1d6c46`.

#### Next Steps:

After user approval, preserve the decoder, RBF, Main, random-access structure, byte count and every conforming stream while adding one helper-side compatibility normalization at the already-buffered initial I-picture boundary: only when a parsed sequence extension identifies 4:2:0 and the parsed frame-picture coding extension has `progressive_frame=1` with the nonconforming `chroma_420_type=0`, change that one field from zero to one and log the exact offset and before/after byte.  Add captured-header and conforming-control regressions proving only byte 185 changes from `0xc0` to `0xc1`, simulate the frontend to prove source 21 clears and the first slice is admitted, run the full strict, sanitizer, analyzer, DVD, LPCM and audio suites, build only a new static ARM helper, then retest both Big Lebowski stills plus the accepted Blazing Saddles and Coming to America menu routes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 935 COMMIT Unreleased ac13724 2026-09-03T00:16:48-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Bundle the source-`ac13724` H.262 restart diagnostic helper with its matched runtime set and physical-drive launcher for forum testing.

#### Outcome:

`host/build/MiSTer_Media_Player_H262Diag_ac13724.zip` contains the exact source-`ac13724` static ARMv7 diagnostic helper, accepted source-`3689cca` Main, current source-`366a227` interlaced visualizer pack, timing-qualified source-`dfe1057` `MediaPlayer_20260901.rbf`, `games/MediaPlayer/USB DVD Drive.dvd`, diagnostic installation and source-provenance notes, the project licence and all seven bundled dependency licences.  It is explicitly identified as an unreleased diagnostic community test rather than a tagged or fixed release.  A fresh extraction contains sixteen files, all fifteen manifest entries pass SHA-256 verification, both executables retain mode 755, and the helper, Main, visualizer, RBF and launcher are byte-identical to their qualified inputs; ZIP integrity reports no errors.  The 6,578,930-byte archive has SHA-256 `ceb791f59ccc8db2d9702fb6631b9705a793d645fa8b2532560d5eeab26777ef`.

#### Next Steps:

Upload `host/build/MiSTer_Media_Player_H262Diag_ac13724.zip` to the forum and have the tester follow `INSTALL.txt`: enable telemetry, start The Big Lebowski, leave the failed startup visible briefly, press Root Menu once and leave that failed screen visible briefly, then return the helper log, telemetry screenshot and decoded sidecar.  Keep this package labeled diagnostic until those two bounded H.262 prefixes identify the compatibility correction and subsequent hardware testing qualifies a fixed build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 934 COMMIT Unreleased ac13724 2026-09-03T00:01:33-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Capture the exact common H.262 header construct rejected near byte 188 in The Big Lebowski's startup and Root Menu stills without changing playback behavior.

#### Outcome:

Source `ac13724` retains every filtered byte and existing publication decision while logging at most the first 256 post-filter bytes plus bounded parsed sequence-header, sequence-extension, picture-header and picture-coding-extension fields for each successful initial random-access group.  A focused production-translation-unit regression proves the collector extracts 720x480 sequence, I-picture and raw extension fields without changing one input byte; the existing terminal-still regressions additionally prove the emitted picture bytes remain exact.  Strict native compilation and DVD random-access, menu-hop, reserve, staging, overlay, SPU, Program Stream seek, audio seek/UI/visualizer and private-audio/LPCM-skip suites pass, as do Address/Undefined sanitizers, GCC analyzer, native static build and the MP3/WAV/FLAC/Ogg real-helper seek/visualizer suite against both native and ARM executables.  The local static stripped ARMv7 diagnostic helper `host/build/MediaPlayer_Helper_H262Diag_ac13724` is 966,052 bytes with SHA-256 `15dc2ddb7d55fedac950ac3ce7401d56340a2d032edda45c1578c3cd04f986a1`; its capabilities match the accepted helper.  No decoder, Main, RBF, visualizer, media byte or scheduling behavior changed.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_H262Diag_ac13724` as `/media/fat/linux/MediaPlayer_Helper`, enable telemetry, start The Big Lebowski and leave its failed startup visible briefly, then press Root Menu once and leave that failed screen visible briefly.  Return the updated results folder; its log should contain two `H262 restart diagnostic` prefixes and two `H262 restart fields` records, allowing the exact common byte-187/188 decoder rejection to be identified before any compatibility normalization is proposed.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 933 COMMIT Unreleased 932dc22 2026-09-02T23:59:04-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Determine whether Root Menu recovers The Big Lebowski's failed startup or independently reproduces its decoder rejection.

#### Outcome:

Root Menu performs a genuine second navigation attempt rather than merely redisplaying the first latched telemetry state.  At 113.253892 seconds Main sends command `0x09`; libdvdnav reports a successful root hop, the helper enters the menu, discards 4,180,090 reserved bytes, returns READY at 113.302508 seconds and releases the reset/GO barrier at 113.313835 seconds.  The destination then reaches its authored 15-second menu still and terminal-finalizes a new group with sequence offset 0, I-picture offset 170 and next reference offset 128,368.  The new checksum-valid schema-21 snapshot nevertheless records the same H.262 syntax flag `0x0001`, only 188 accepted bytes, and zero completed, displayed or reference pictures and swaps; the preceding independent startup snapshot failed at 187 bytes with the same sequence and I-picture offsets.  The helper remains alive, continues publishing menu highlights and has supplied 870,570,274 bytes by the 370.83-second capture endpoint, proving that the reset succeeds but both authored stills share an early H.262 construct rejected by the decoder.  Therefore entry 932's proposed non-menu-only gating could avoid the first failure but cannot make this root menu work and must not be shipped as the complete correction.  The 6,131,013-byte log, 1,451-byte barcode screenshot and 376-byte sidecar have SHA-256 `0334960b4723a0f4559d11ed89d3d660f916d109f574f8a3160896a7b17081e7`, `cd46075c074321026dd213f5514271b5502899e3325397b9f9e37bd0cc6f71a0` and `a720e6a6355b778971f8138b56e9940e55045d21babde553343919f9cb1d6c46`.  No runtime source was changed.

#### Next Steps:

Do not implement the entry-932 gating alone.  After user approval, make one diagnostic helper build that logs a bounded byte-exact prefix and parsed sequence, picture and extension fields for each initial random-access group before publication, without changing the bytes, decoder, Main, RBF, visualizer or timing.  Reproduce Big Lebowski startup and Root Menu once with that helper, identify the exact common construct at the 187/188-byte boundary against the frontend's 22 syntax-source checks, and then propose the narrowest helper-side compatibility normalization that preserves ordinary DVD streams and all accepted Blazing Saddles and Coming to America menu behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 932 COMMIT Unreleased 932dc22 2026-09-02T23:55:22-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Accept the helper-only visualizer blend and localize The Big Lebowski's fresh failure to its initial non-menu authored still.

#### Outcome:

The user accepts source `932dc22`'s visualizer presentation.  The matched Big Lebowski capture instead isolates an independent DVD startup failure: after CSS setup and title inventory, the disc remains outside a menu and reaches a three-second authored still; the generalized terminal finalizer releases its 5,482-byte one-picture H.262 payload at sequence offset 0 and I-picture offset 170, appends sequence end plus drain, and Main submits the resulting 5,490 bytes.  The checksum-valid schema-21 snapshot records H.262 syntax error flag `0x0001` after only 187 accepted video bytes, zero completed or displayed pictures and zero swaps.  The helper neither crashes nor stalls: it proceeds through the following seven-second still and continues generating title video and audio, while Main has submitted 183,236,608 bytes by the 92.55-second capture endpoint with no transport block or audio underrun.  Source `9c00a20` broadened terminal still finalization from pending menu activations to every initial-filter still to repair direct Root Menu one-picture backgrounds; that now exposes this decoder-rejected non-menu first-play picture instead of retaining it behind the startup filter until a later complete random-access group supersedes it.  The 1,519,541-byte log, 1,445-byte telemetry barcode screenshot and 337-byte decoded sidecar have SHA-256 `8be2813b811564546c1ce79e4bf444fede5ff4cafac48f00ebb7bcda1cbeabc5`, `da9debc380f82fdfe9a656d5b8786310764e9582cd11f75a27ab6bf83337c067` and `4192d812816d56e8f24e2e7750c021efff272c61b614082df942fc9445b1811a`.  No runtime source was changed.

#### Next Steps:

After user approval, keep terminal finalization for an active DVD menu or pending authored menu activation, but leave an initial non-menu finite still queued under the existing random-access filter so a later complete sequence/I/reference group can replace its decoder entry point.  Add production-path regressions proving that a non-menu first-play still does not release or clear the filter, a direct Root Menu one-picture still still receives the terminal tail, and pending finite and indefinite menu activations retain their current staged policies.  Run strict random-access, overlay, navigation, staging, LPCM, audio and sanitizer suites, build one static ARMv7 helper without changing Main, the decoder, RBF, visualizer asset or accepted visualizer cadence, then retest Big Lebowski startup plus Blazing Saddles and Coming to America menu entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 931 COMMIT Unreleased 932dc22 2026-09-02T23:23:00-07:00

#### Coming From:

Unreleased 366a227

#### Purpose:

Minimize the striped standalone-audio interface artifact with helper-only overlay transparency and a covered-visualizer brightness limit while preserving the accepted animation cadence.

#### Outcome:

Source `932dc22` makes standalone-audio overlay palette index zero fully transparent, the dark panel color alpha `0xa0`, and both border/text colors opaque, so missed or background-only rows expose the continuously decoded visualizer while retained UI detail reads as a translucent scanline-style HUD.  While that overlay is visible, the already-scheduled GOP selector limits the displayed grade to level 3 of 7; the existing ten-second CLEAR restores the full zero-through-seven loudness range, and activity or seek reapplies the cap without changing `due_gops`, GOP phase, source frame rate, slice size or service cadence.  Focused strict and ASAN/UBSAN tests prove exact palette alpha, covered attack `1,2,3,3...`, revealed recovery `4,5,6,7`, and renewed capping after activity and seek; GCC analyzer passes both changed translation units.  Native real-helper tests pass MP3, WAV, FLAC and Ogg with 378 through 381 decoded pictures and one CLEAR each, and the final ARMv7 helper passes the same four formats with 372 through 381 pictures and one CLEAR each.  GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_Scanline_932dc22` at SHA-256 `a87a6a81e21996735abc0d218d9d301ad8e349f96b0eeb8d891a172b86c70b09`.  The visualizer asset, decoder, Main and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_Scanline_932dc22` using executable mode, preserving the installed visualizer pack, Main and timing-qualified RBF.  Play standalone audio and require the first ten seconds to show a readable translucent scanline-style interface with the disruptive full-width dark bars removed or materially minimized; after the existing CLEAR, require the normal full-brightness visualizer.  Press Space during playback and pause, require the interface to return immediately over the animation with its quieter brightness ceiling, and confirm that the visualizer motion rate remains constant in both states and returns to full range after another ten seconds without input.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- host/arm/media_player_helper.c
- tools/test_audio_visualizer.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [x] Passed
