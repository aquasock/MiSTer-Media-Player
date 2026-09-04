## 973 COMMIT Unreleased cd484ba 2026-09-04T04:34:35-07:00

#### Coming From:

Unreleased 8a86b77

#### Purpose:

Prevent deferred same-menu DVD activations from deadlocking behind the initial random-access filter and video-queue bound.

#### Outcome:

Source `cd484ba` retains the existing two-megabyte video-queue guard and qualified restart barriers while adding a context-preserving fallback for deferred button activations that remain in menu space without supplying a complete sequence-header, I-picture and following-reference startup group.  At queue pressure the helper rebases all queued, pending, audio and triggering video timestamps above the prior live epoch, releases only the initial random-access filter, drains the exact interleaved stream through the normal scheduler into the existing activation stage, commits it to the resident decoder and acknowledges continuation; actual menu-to-title exits and independently decodable motion-menu restarts keep their established decoder barriers.  The production-translation-unit regression drives this through the real PES, H.262 filter, bounded queue, scheduler, stage and control-event path, verifies two megabytes of byte-exact video and rebased in-band PTS records, and passes optimized, AddressSanitizer plus UndefinedBehaviorSanitizer and twenty repeated runs.  Retained DVD random-access, SPU, menu-hop, overlay, reserve, staging, AC-3, CDDA, audio UI, visualizer and seek tests pass, including one hundred menu-hop runs, static Main contracts and final-ARM real MP3, WAV, FLAC, Ogg, pause-barrier and private-audio integrations.  GNU 10.2.1 produced the 978,340-byte stripped static ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `7cd8427fd955beb81ba35c7fa2ff34e09cd8214f4872f9d8f9695187dcd560e4`; it has no dynamic section and passes its protocol-one capability probe.  Main, protocol, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`cd484ba` artifact and leave the current per-core Main, RBF and visualizer in place.  Reproduce the same Simpsons route through its first-episode menu activation and require `DVD menu activation deferred`, `DVD menu continuation PTS rebased` and `DVD menu activation preserved resident decoder context` without `video lookahead limit exceeded` or helper termination, then select and play the episode.  Retest Futurama root-menu arrival, selector motion, nested episode selection and title playback, spot-check an Audio CD and ordinary audio file, and return the updated result set for hardware qualification.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 972 COMMIT Unreleased 8a86b77 2026-09-04T04:31:41-07:00

#### Coming From:

Unreleased 8a86b77

#### Purpose:

Accept the completed Audio CD presentation and localize The Simpsons first-episode stall without changing runtime source.

#### Outcome:

The user reports that source `8a86b77`'s Audio CD title, aligned metadata, placeholders and default artwork look good, completing the current audio-player work.  The fresh physical Simpsons DVD run independently rejects the button-activation path: Main sends menu activate at 171.246404 seconds, libdvdnav accepts button one and remains in menu space, and the helper begins its 8 MiB deferred activation stage before resetting navigation scheduling with the initial random-access filter active.  The destination then supplies 2,097,152 bytes without a complete sequence-header, I-picture and following-reference startup group, so `scheduler_drain()` admits none of that queued video to the stage and the helper deliberately exits at 207.840268 seconds on its 2 MiB lookahead guard.  Main reports helper-error with exit code one after 33,710,172 submitted bytes; this is a helper state-machine deadlock rather than an RTL syntax stall or frozen process.  The stage's 4 MiB motion-menu decision is unreachable while the filter holds all video behind the smaller queue bound, and the existing motion-stage regression bypasses both the filter and queue.  The checksum-valid schema-21 snapshot covers an earlier healthy 30-second epoch with 5,107,715 accepted bytes, 128 displayed pictures, 127 swaps and zero decoder, presentation, PCM, underrun or transport errors, so it does not contradict the later host-side failure.  The 8,503,411-byte log, 350,644-byte screenshot and 766-byte sidecar have SHA-256 `f8fabeea0079268de9da7a8facc2f7be8a3231d2bef4b22c58c3ff83265fe45c`, `90c77634fcbb8bc143df68bc306016d8de895bf73b7d28212d2c451fd5cd4187` and `a3f2e0eae728a1d7e12b67712b2f3492074b0c7b02f4158fb103723ca887ba8d`.  No runtime source was changed.

#### Next Steps:

After user approval, keep the 2 MiB runaway guard and distinguish restart-qualified staged activations from menu continuations that require the resident decoder context.  When an activation remains in menu space but cannot form an independent random-access group before the queue bound, release that activation through a context-preserving continuation path and acknowledge it without resetting Main; retain the existing barrier for a qualified staged restart or an actual menu-to-title exit.  Add a production-path regression that reaches this bound through the real filter and queue, plus controls for Futurama staged stills, qualified motion-menu hops, overlay-only continuation and title launch, then build only a local static ARM helper.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 971 COMMIT Unreleased 8a86b77 2026-09-04T04:09:25-07:00

#### Coming From:

Unreleased 2ab755b

#### Purpose:

Present coherent Audio CD metadata with aligned labels and a built-in default disc image.

#### Outcome:

Source `8a86b77` uses the existing TOC-backed playlist state as the Audio CD presentation discriminator and formats the title from the same selected physical track byte as the corresponding `TRACK nn` row, preventing title and selector drift across beginning, middle and end changes.  A shared metadata-row renderer right-aligns TITLE, ARTIST and ALBUM before one fixed colon column, keeps artist and album at `---`, and preserves the ordinary-file title placeholder.  The prior empty artwork box now contains a bounded concentric-disc graphic and `AUDIO CD` caption; its ellipse width compensates for the native mode's 8:9 pixel aspect and requires no asset or protocol change.  Strict optimized and ASAN/UBSAN pixel tests pass selector/title changes `09` to `01` to `18`, all three aligned colons, both retained placeholders, default-art palette and bounds, ordinary-file fallback, timing and progress; GCC analyzer, CDDA reader tests, static Main contracts and native real-helper integrations also pass.  GNU 10.2.1 produced the 978,340-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `2e87ba05eb6e5dcce4f42712626e19f773126a683d529672ae23a4f25b8d42e2`, and that exact artifact passes idle plus MP3, WAV, FLAC, Ogg and pause integration.  Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`8a86b77` artifact, preserving executable mode, then re-enter the core and load a physical Audio CD.  Require the default disc image to stay inside the album-art box, all three metadata colons to align, TITLE to match the selected playlist row through natural, previous and next track changes, and ARTIST plus ALBUM to remain `---`; spot-check the accepted timing fields and one ordinary audio file before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- tools/test_audio_ui_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 970 COMMIT Unreleased 2ab755b 2026-09-04T04:08:26-07:00

#### Coming From:

Unreleased 2ab755b

#### Purpose:

Record hardware acceptance of Audio CD track-relative timing and define the requested metadata alignment and default-art boundary.

#### Outcome:

The user reports that source `2ab755b` looks good on the test MiSTer, accepting active-track elapsed, remaining, total and progress plus the complete album-duration playlist clock delivered by entry 969.  The next requested Audio CD presentation boundary is to mirror the selected `TRACK nn` playlist label in the title field, retain `---` placeholders for artist and album, align the title, artist and album colons on one vertical axis, and replace the empty artwork placeholder with a built-in default Audio CD image.  Existing CDDA transport, timing, selector behavior, visualizer lifecycle and ordinary audio-file presentation remain unchanged.

#### Next Steps:

Proceed with a separate approved helper-only proposal that gives the renderer an Audio CD presentation mode, derives the title from the same selected physical TOC track used by the playlist, aligns the metadata labels without changing their established scale, draws a deterministic default disc image inside the existing artwork viewport, and validates both CD and ordinary-file frames without rebuilding Main or the RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 969 COMMIT Unreleased 2ab755b 2026-09-04T03:50:52-07:00

#### Coming From:

Unreleased 04360e9

#### Purpose:

Give Audio CD playback track-relative elapsed, remaining and total clocks plus a whole-album playlist-duration clock.

#### Outcome:

Source `2ab755b` preserves the absolute concatenated CDDA cursor for reading and seeking but exposes the active audio track's logical start and length from the filtered TOC.  The audio UI atomically carries that window with the selected physical track, so `ELAPSED`, `REMAIN`, the existing `TRACK` total field and the progress bar are track-relative while `PLAYLIST` shows the duration of the complete filtered audio program.  Partial track and album seconds retain the established upward duration rounding, elapsed time retains completed-second truncation, data-track gaps remain excluded, and ordinary audio files retain their file-relative clocks and placeholder playlist summary.  Strict optimized and ASAN/UBSAN reader and pixel tests pass mixed-mode timing, invalid ranges, fractional durations and an exact `00:21` elapsed, `00:41` remaining, `01:02` track, `05:02` playlist and 224-of-652 progress case; GCC analyzer, static Main contracts and native real-helper visualizer/pause integrations pass.  GNU 10.2.1 produced the 978,340-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `6d13a20e9c4d5fd23f3c71522d1e1be1b23d10b7fd406e757aa2dba55321d4e4`, and that exact artifact passes idle plus MP3, WAV, FLAC, Ogg and pause integration.  Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`2ab755b` artifact, preserving executable mode, then re-enter the core and load a physical Audio CD.  Verify that elapsed and remaining restart at each natural or requested track boundary, `TRACK` remains that track's total length, `PLAYLIST` remains the album's combined audio duration, and the progress bar restarts per track; also spot-check previous, next and fixed seeks plus one ordinary audio file before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- tools/test_audio_ui_output.c
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 968 COMMIT Unreleased 04360e9 2026-09-04T03:50:04-07:00

#### Coming From:

Unreleased 04360e9

#### Purpose:

Record hardware acceptance of the TOC-backed Audio CD playlist and define the requested per-track and whole-album timing semantics.

#### Outcome:

The user reports that source `04360e9` looks good on the test MiSTer, accepting the `TRACK nn` playlist population, moving selection and six-row scrolling window delivered by entry 967.  The next requested display boundary is now explicit for Audio CD playback: `ELAPSED` is elapsed time within the selected track, `REMAIN` is time left within that track, `TOTAL` is that track's complete duration, and `PLAYLIST` is the complete duration of every filtered audio track on the disc.  Existing controls, playlist labels, current-track selection, audio transport and ordinary audio-file timing remain unchanged.

#### Next Steps:

Proceed with a separate approved helper-only proposal that exposes current-track start and duration from the CD TOC, derives the four requested clocks from the existing absolute CDDA sample position, and validates boundary, seek, natural-transition and mixed-mode behavior without rebuilding Main or the RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 967 COMMIT Unreleased 04360e9 2026-09-04T03:25:13-07:00

#### Coming From:

Unreleased e0f6f9a

#### Purpose:

Populate the Audio CD playlist with the disc track sequence and keep the playing track selected near the vertical center without changing transport controls.

#### Outcome:

The test MiSTer reports `/dev/cdrom` linked to `/dev/sr0` and a drive with Audio CD playback support; its existing source-`e0f6f9a` helper was actively consuming the inserted disc, so no competing live-drive process was started.  Final source `04360e9` exposes ordered physical audio-track numbers from the already filtered Red Book TOC and configures the audio UI with stable `TRACK 01`-style rows.  The six-row window selects the playing entry, targets the fourth visible row when both sides permit, clamps cleanly at the first and last tracks, preserves gaps when mixed-mode data tracks are excluded, and follows natural playback, fixed seeks and existing previous or next track changes without altering controls.  Before an Audio CD pause barrier, the current overlay is republished so revealing a UI that timed out on an earlier track cannot show a stale selector.  Strict optimized pixel and reader tests cover middle, beginning and end windows plus mixed-number numbering and invalid inputs; AddressSanitizer and UndefinedBehaviorSanitizer pass with leak detection disabled because LeakSanitizer is unavailable under the local ptrace wrapper, GCC analyzer passes, the complete native helper compiles with the established host-only `-Wno-attributes` exception, static Main routing and NTSC checks pass, and real-helper idle plus MP3, WAV, FLAC and Ogg visualizer, seek and pause integrations remain clean.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `cb06ef1bd73e12f47741c723ad88aaa2485f1df48be9ff2ccbad06a11382661a`; Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit the MediaPlayer core, replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`04360e9` artifact and preserve executable mode, then re-enter the core and load the inserted Audio CD.  Require every TOC entry to appear as `TRACK nn`, the playing row to move on P/N or player-one Left/Right and on a natural track boundary, and a disc with more than six tracks to keep middle selections on the fourth row while clamping the window near either end.  After the overlay has timed out on a later track, press Space once and require the refreshed UI to identify that current track before audio and visualizer hold, then resume and spot-check fixed seeks, ordinary audio playback and Video DVD startup before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- tools/test_audio_ui_output.c
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 966 COMMIT Unreleased e0f6f9a 2026-09-04T03:16:49-07:00

#### Coming From:

Unreleased e0f6f9a

#### Purpose:

Record hardware acceptance of the overlay-first audio pause barrier and scope selectable visualizer-pack support against the current decoder-safe asset format.

#### Outcome:

The user reports that source `e0f6f9a` works perfectly on MiSTer, accepting the first-Space overlay reveal, stopped audio and visualizer, and second-Space resume behavior; this closes the hardware check left open by entry 965.  Alternate visualizers can reuse the current version-two `.mmpvis` container and generator while changing the underlying 720-by-480 artwork or animation, provided all eight steady grades, seven rising transitions and seven falling transitions remain phase-aligned native-interlaced MPEG-2 closed GOPs with the validated three-picture structure.  Production currently opens only `/media/fat/linux/MediaPlayer_Visualizer.mmpvis`, although tests may override it through `MMP_VISUALIZER_PATH`.  Manual replacement therefore works now without another build, while an on-screen `Load Visualizer` file picker would require a small `CONF_STR` addition and thus one Quartus/RBF build, plus isolated Main path selection and helper launch plumbing; no decoder datapath or visualizer format change is inherently required.  Hot-swapping during active audio would need a larger live-control transaction, whereas selecting while idle and applying the choice to the next helper launch is the safer first boundary.

#### Next Steps:

Preserve source `e0f6f9a` and its accepted runtime artifacts.  If selectable visualizers are approved, first create several deterministic version-two packs from distinct source animations and add a session-scoped `Load Visualizer` picker that validates the selected `.mmpvis`, restarts the idle helper immediately and uses the choice for subsequent audio-file and Audio CD launches; defer active-song hot-swapping and optional persistent configuration until the basic selection route is hardware-proven, and perform only one Quartus seed for the required menu-string RBF change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 965 COMMIT Unreleased e0f6f9a 2026-09-04T02:52:38-07:00

#### Coming From:

Unreleased 889f4ea

#### Purpose:

Make the first Play/Pause press reveal the standalone-audio player UI before holding audio and visualizer transport, with deterministic resume behavior and no RTL change.

#### Outcome:

The user hardware-accepts source `889f4ea` as visibly smoothing the eight-level visualizer transitions, then reports that after the audio-player overlay has timed out the first Space press pauses music and the visualizer without revealing the UI, while the second Space resumes both and makes the UI appear.  Source `e0f6f9a` fixes the diagnosed ordering defect with an audio-only `PAUSE` and `PAUSE_READY` barrier: the helper reveals the resident overlay style, flushes all preceding in-band output, acknowledges and waits for the existing `GO`, while isolated Main drains through acknowledgment and pipe quiescence before setting the transport hold.  The next Play/Pause press releases the same emitted-audio frame with `GO`, so the visualizer and music remain stopped during pause and the ten-second overlay interval advances only after resume.  The optimized and AddressSanitizer plus UndefinedBehaviorSanitizer production-path integrations prove that `STYLE` precedes readiness, output remains byte-stable while held and all MP3, WAV, FLAC and Ogg paths resume; focused audio UI, visualizer, seek, CDDA, Main lifecycle, native-480i and static routing tests pass, the complete Main patch stack applies and compiles against pinned upstream `0a8fb44`, and the visualizer analyzer test remains clean.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `34227d89d11c28bb7d0a2206e87462d9c17315f0dd521c34e0c8bc2e4fbc7ae7` and the 1,186,780-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `1a333b83f43e71789922befcc828fc705480d7dafe85022b7591d0b18028b4f8`; the accepted visualizer pack and RBF remain byte-identical.

#### Next Steps:

Exit the MediaPlayer core, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MiSTer_MediaPlayer` with the two source-`e0f6f9a` artifacts, preserve executable mode and reboot because Main changed; retain `MediaPlayer_Visualizer.mmpvis` and `MediaPlayer_20260904.rbf`.  Play an audio file past the ten-second overlay timeout, press Space once and require the UI to appear before music and visualizer motion both stop, press Space again and require both to resume with the UI clearing after ten resumed playback seconds, then repeat with an Audio CD and spot-check DVD and MPEG-2 takeover before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_main_cdda.py
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 964 COMMIT Unreleased 889f4ea 2026-09-04T02:17:33-07:00

#### Coming From:

Unreleased 8d0ab99

#### Purpose:

Replace visible whole-GOP visualizer grade steps with deterministic three-frame crossfades while retaining the existing eight-level response and legacy-pack compatibility.

#### Outcome:

Source `889f4ea` adds version-two visualizer index handling with eight steady variants, seven adjacent upward transitions and seven adjacent downward transitions, each containing twenty phase-aligned, three-picture native-interlaced closed GOPs.  The helper selects a transition GOP whenever its existing hysteretic one-level slew rises or falls and retains the old steady-stream behavior for version-one packs; idle level zero, the overlay cap, transport slicing, RMS thresholds and media lifecycle are unchanged.  The generator applies the grade ramp per frame and verifies all 440 index entries plus exact file-size accounting before publishing.  Independent FFmpeg decoding measures the first zero-to-one rise at mean luma 56.3227, 61.6911 and 63.2825 between steady endpoints 52.8588 and 63.1943, while the reverse transition measures 61.7344, 56.5000 and 53.0892.  Optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer selector tests pass, with LeakSanitizer unavailable under the local ptrace wrapper; strict native compilation, audio UI, seek and exact-pack idle plus MP3, WAV, FLAC and Ogg integrations pass for both version one and version two.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `f2ab5cd997363ec678371674c13e14428ae79ea81a1d883a13dfa4ed2ace3e95`, and deterministic generation produced the 11,201,580-byte `host/build/MediaPlayer_Visualizer.mmpvis` with SHA-256 `4e1c4f6eeaf2e6b781401b15902b60bd4d38e8254f4f5220a3133b3f5d84753f`; Main, protocol, RTL and RBF remain unchanged.

#### Next Steps:

Exit the MediaPlayer core so the idle helper is not using either file, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` with the two new artifacts, preserve executable mode on the helper, and retain the current `MiSTer_MediaPlayer` and `MediaPlayer_20260904.rbf`.  Re-enter the core to verify the steady idle loop, play an audio file or Audio CD past the ten-second overlay timeout and compare several loud and quiet passages for smooth approximately 100-millisecond grade transitions in both directions, then confirm DVD and MPEG-2 takeover before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- host/arm/audio_visualizer.h
- tools/generate-audio-visualizer.py
- tools/test_audio_visualizer.c

#### Status:

- [x] Built
- [ ] Passed

---

## 963 COMMIT Unreleased 8d0ab99 2026-09-04T01:53:01-07:00

#### Coming From:

Unreleased 8d0ab99

#### Purpose:

Evaluate the first idle-visualizer hardware run and diagnose the reported sputtering DVD-menu audio.

#### Outcome:

The user confirms that source `8d0ab99` displays the visualizer while the core is idle and that a physical Coming to America DVD reaches its visible authored menu, establishing idle startup and DVD takeover on hardware.  The fresh helper log proves this playback launched with `audio output spdif`, selected AC-3 private substream `0x80`, and therefore emitted IEC 61937 AC-3 bursts for an external S/PDIF decoder rather than decoded stereo PCM; equipment interpreting those bursts as ordinary audio produces the reported sputtering or noise.  The source change did not alter status bit 126 or its HDMI/S/PDIF mapping, and the checksum-valid schema-21 capture reports 59 displayed pictures, 58 swaps, zero PCM protocol errors, zero audio underruns and zero transport blocks, so it supplies no evidence of an idle-handoff PCM residue or transport starvation.  The menu screenshot and overlay telemetry are valid, with one complete 86,400-byte overlay plane and no overlay protocol error.  The 938,734-byte log, 691,864-byte screenshot and 844-byte sidecar have SHA-256 `3b95414481949f5300d0daad613c87177bd3da30f5b6bbca3483655bfe4d914c`, `435f70170d31f7aebb0d246394c8b452c905b3fa2339096ee712098c1f06c010` and `9b60f83b41228a9c1c9026ad9281de3d78e470624bb6d3ea040e06884c3b21af`; no runtime source was changed.

#### Next Steps:

Set the core menu's `Audio Output` option to `HDMI`, reload the same DVD and capture fresh results while the menu plays; the new helper log must say `audio output hdmi (decoded stereo PCM)`.  If that run is clean, treat the sputtering as expected undecoded S/PDIF passthrough and continue idle-background qualification through DVD, MPEG-2, audio-file and Audio CD takeover and return; if it still sputters with HDMI proven in the log, diagnose the decoded-PCM scheduler from that trace before proposing a source change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 962 COMMIT Unreleased 8d0ab99 2026-09-04T01:23:00-07:00

#### Coming From:

Unreleased 3e4f7ea

#### Purpose:

Keep the existing MPEG-2 visualizer loop active whenever the MediaPlayer core is idle while preserving immediate video takeover and the current ten-second audio-player overlay.

#### Outcome:

Source `8d0ab99` adds an `idle:` helper source that validates and continuously emits the existing closed-GOP visualizer pack at its encoded cadence from a monotonic-time virtual sample clock without silent PCM or an audio-player overlay.  Isolated Main now starts that background after recognizing the MediaPlayer core, replaces it for every physical-disc or file selection, and restores it after playback finishes or fails while preserving the prior replay source and the established audio-file and Audio CD overlay timeout.  A failed idle helper or missing asset is suppressed until a successful media cycle or core reload so it cannot create a polling fork loop.  Strict native, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer coverage passes together with focused idle pacing, audio UI, audio-file, CDDA, DVD, seek, output and Main lifecycle regressions, and the complete Main patch stack applies and cross-builds against pinned upstream `0a8fb44`.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `f4d392f08d2538b9b2c38e285cb4925f6bc10133915060acd97f6aa7f8559696` and the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `58971dd7b558238fe6dafca269c36d5e595e7ff326e32ee6e3f50a093b006aa1`; no RBF, RTL, menu-string or visualizer-asset change was required.

#### Next Steps:

Exit MediaPlayer, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MiSTer_MediaPlayer` with the two new build artifacts, preserve executable permissions, retain the accepted `MediaPlayer_20260904.rbf`, visualizer pack and per-core INI, and reboot because Main changed.  Validate that the visualizer appears on core entry and behind the OSD, DVD and MPEG-2 sources take over immediately, audio-file and Audio CD playback retain the player overlay for about ten seconds before revealing the visualizer, and the idle background returns after finite playback before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_main_cdda.py
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 961 COMMIT Unreleased 3e4f7ea 2026-09-04T00:07:31-07:00

#### Coming From:

Unreleased 3b2a0ca

#### Purpose:

Replace marker-file optical launching with a hierarchical loader menu that starts physical DVD and Audio CD media directly while retaining separate DVD ISO, MPEG-2 video and audio file pickers.

#### Outcome:

The user reports that source `3b2a0ca` successfully plays a physical Audio CD, accepting the underlying CDDA path for the tested disc.  Source `cde9841` replaces marker-file launching with MiSTer's numbered menu pages for `Load Physical Disc` and `Load Disc Image`; physical `Video DVD` and `Audio CD` now invoke `dvdmenu:/dev/sr0` and `cdda:/dev/sr0` directly through isolated Main, the image submenu exposes an ISO-filtered `Video DVD` browser, and `Load MPEG-2 Video File` and `Load Audio File` remain immediate filtered browsers.  All routes normalize to FPGA stream index one, Audio CD image support remains deliberately omitted pending a CUE/BIN or equivalent backend, and the obsolete `.dvd` and `.cd` marker assets are removed without changing the helper, decoder RTL or media protocol.  The patched Main stack applies cleanly to pinned upstream Main `0a8fb44`, focused direct-loader and retained NTSC-native static contracts pass, and GNU 10.2.1 produced the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `35ac7ca233bf1cdf074409ed781b6ee0367a63e31f00d394b5e0eced26a5a8e4`; the existing helper remains the accepted 974,244-byte artifact with SHA-256 `35a369ed1c3f30197f0ce663da67a0c171dbf132c34d6c131c859aa626663dd7`.  Seed 25 failed only global setup at negative 0.110 ns while hold, recovery, removal, minimum pulse width, decoder setup and video setup remained positive; the single authorized seed-26 commit `3e4f7ea` passes global setup at positive 0.143 ns, hold at positive 0.146 ns, recovery at positive 3.818 ns, removal at positive 0.470 ns, minimum pulse width at positive 0.925 ns, decoder setup at positive 0.841 ns and video setup at positive 2.541 ns with 38 percent average and 57 percent peak interconnect usage.  The accepted 4,470,016-byte `host/build/MediaPlayer_20260904.rbf` has SHA-256 `4896c2b50345e3f29c72435dce0c4188ae2b502465eeb59c37c25930002103b8`; the new menu integration awaits MiSTer hardware validation.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_20260904.rbf` as `/media/fat/MediaPlayer_20260904.rbf` and install `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer`, while retaining the existing helper, visualizer and per-core INI.  Remove `/media/fat/games/MediaPlayer/Video DVD.dvd`, `/media/fat/games/MediaPlayer/Audio CD.cd` and any obsolete `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`, then reboot and validate both physical-disc choices, DVD ISO selection, MPEG-2 file loading, audio file loading, DVD menus and playback, Audio CD transport, Bob or Weave output and the experimental native-NTSC path before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- MediaPlayer.sv
- README.md
- assets/Audio CD.cd
- assets/Video DVD.dvd
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_main_cdda.py

#### Status:

- [x] Built
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
