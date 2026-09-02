## 888 COMMIT Unreleased ??? 2026-09-01T23:49:02-07:00

#### Coming From:

Unreleased 9397fa7

#### Purpose:

Make the standalone-audio progress bar represent the current absolute track position instead of repeating once per minute.

#### Outcome:

The user physically accepts the source-`9397fa7` full-screen 4:3 layout but reports that its moving progress bar does not track the audio file's duration.  The accepted helper already obtains exact output-frame lengths for MP3, WAV and FLAC and already carries the absolute target frame through each audio seek, while the UI currently discards the length and renders `position_seconds % 60`.  Focused integration exposed that miniaudio's callback-based Ogg Vorbis backend uses push mode and returns a successful zero length, so this boundary will also add file-end seeking to the local media-source abstraction and read only the final bounded Ogg page's authoritative granule position rather than scanning or decoding the whole file.  A one-time decoder-to-UI duration callback will retain an absolute UI position in PCM frames and scale that position safely across the existing 652-pixel interior so ordinary playback and fixed seeks both produce true file-relative progress for all four formats.  The bar's geometry, one-hertz frame cadence, bounded UI interleaving, atomic publication, codecs, audio priority, controls, Main, RTL, RBF, video and DVD paths will remain unchanged; elapsed, remaining and track-duration text will remain placeholders.

#### Next Steps:

Commit and push this proposal after the authorized ring-buffer rotation, implement duration configuration and overflow-safe progress scaling in the helper, and extend the deterministic renderer regression for empty, proportional, seeked and complete bar states.  Extend the real-helper four-format seek regression to require that each decoder's reported duration reaches the UI, run strict and sanitizer tests, then build and verify a uniquely named static ARMv7 helper with the local GNU 10.2 toolchain.  Deliver only the helper for MiSTer testing and preserve the accepted Main and timing-qualified RBF.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_source.c
- host/arm/media_source.h
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c

#### Status:

- [ ] Built
- [ ] Passed

---

## 887 COMMIT Unreleased 9397fa7 2026-09-01T23:40:06-07:00

#### Coming From:

Unreleased 9397fa7

#### Purpose:

Record physical acceptance of the full-screen 4:3 CRT-safe standalone-audio interface layout.

#### Outcome:

The user reports that everything looked great on MiSTer, physically accepting source `9397fa7` and its helper-only audio-interface layout with playback behavior unchanged.  The fresh 8,308-byte 1,920-by-1,080 screenshot at SHA-256 `511b79f7badd1b9a3c660ba547d735a0dcc865fdfd62a50a45488c398b5c18bc` visibly contains the complete album-art and metadata column, six-row playlist, transport controls, time placeholders and active full-width progress bar without a clipped panel or label.  The matching 4,575,874-byte helper/Main log at SHA-256 `02dbd13e504e7816eae2ee25a790d291b503bdc31a2648aa04dd5860b2cd2345` covers approximately 74.7 seconds of 44.1-kHz FLAC playback, identifies the 720-by-480 BT.601 audio UI, records 74 complete UI commits at a 1.005-second average interval and includes four successful ten-second seek commands without a fatal helper or transport event.  Its 76 begin, 9,725 data and 74 commit records include expected partial-frame restarts around seeking and the live capture endpoint.  Main's overlay-only trace formatter calls audio-UI commands `0x10`, `0x11` and `0x12` `overlay_submit unknown` and increments its local `order_errors` diagnostic because that formatter predates the audio-UI protocol; the successfully rendered frames prove these labels are not FPGA publication failures.  The 2,818-byte `telemetry.txt` at SHA-256 `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004` correctly reports that no supported telemetry matrix can be extracted from the clean audio-interface screenshot, so it supplies no decoder-word snapshot and does not contradict the visual and transport acceptance.

#### Next Steps:

Preserve source `9397fa7`, `host/build/MediaPlayer_Helper_AudioLayout_9397fa7`, the installed source-`72bdccc` Main and the timing-qualified RBF as the accepted standalone-audio layout baseline.  Continue ordinary audio, MPEG Program Stream and DVD testing without enabling telemetry unless diagnostic evidence is needed; a later approved boundary may populate artwork, tags, playlist entries and true duration-relative time fields while retaining this accepted 4:3 geometry and playback behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 886 COMMIT Unreleased 9397fa7 2026-09-01T22:56:38-07:00

#### Coming From:

Unreleased 72bdccc

#### Purpose:

Replace the initial standalone-audio diagnostic composition with the approved full-screen 4:3 CRT-safe album, metadata, playlist and transport layout without changing playback behavior.

#### Outcome:

Source `9397fa7` replaces the standalone-audio diagnostic composition with the approved full-screen 720-by-480 interface authored for 4:3 CRT display.  A 224-by-200 raster-pixel album-art placeholder, physically square at the mode's 8:9 pixel aspect, and title, artist and album placeholders occupy the left column; a six-row current-playlist placeholder occupies the right; previous, play/pause and next controls, track and playlist time placeholders, and a full-width progress bar complete the lower area inside 32-pixel horizontal and approximately 24-pixel vertical safe margins.  A deterministic built-in 5-by-7 font supplies the static labels, while the existing one-minute sample-clock progress motion, one-hertz update cadence, bounded interleaving and atomic inactive-bank publication are retained.  Actual tag parsing, album-art decoding, playlist management, duration calculation, control behavior and scrubbing remain deferred.  Exact layout-region checks and frame hashes pass at 48 and 44.1 kHz under strict native compilation and AddressSanitizer/UndefinedBehaviorSanitizer; UI seek-reset and real-helper `.mp3`, `.wav`, `.flac` and `.ogg` forward/backward seek regressions also pass.  The inspected deterministic YCbCr preview has SHA-256 `cdee861ec163331526bf1f6749eca81975e86373c529d0d946ef7f0b20f087f5` and its PNG conversion has SHA-256 `22b364cd5cad02e78bd03e1679be3cefe49fcc066d732ec3a6c2fcf9a2f23d8a`.  The GNU 10.2 build produces the 953,764-byte static ARMv7 helper `host/build/MediaPlayer_Helper_AudioLayout_9397fa7` with SHA-256 `517543f9f47b3ca7b42a4646c542347902d2fa2de5feb2ae628ae4a53df7dc7c`; Main, RTL, RBF, codecs, seeking, video and DVD behavior are unchanged.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_Helper_AudioLayout_9397fa7` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, and preserve the installed `MiSTer_AudioSeek_72bdccc` Main and timing-qualified RBF.  Re-enter the core and test at least one standalone audio file on the intended 4:3 CRT: verify that all panel borders and labels remain visible outside overscan, the album-art placeholder appears physically square, the progress bar advances once per second, and audio plus fixed seeking remain clean.  Also spot-check one 16:9 display mode for acceptable pillarbox/stretch behavior, then report hardware acceptance or capture a screenshot and fresh telemetry if any presentation or playback regression appears.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- tools/test_audio_ui_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 885 COMMIT Unreleased 72bdccc 2026-09-01T21:54:05-07:00

#### Coming From:

Unreleased eb11247

#### Purpose:

Add responsive fixed ten-second, one-minute and five-minute seeking to every supported standalone audio-file format without changing FPGA logic or established video and DVD controls.

#### Outcome:

Source `512b5eb` implements the approved helper/Main-only boundary and source `72bdccc` corrects the generated Main patch's new-file hunk length after the first exact build exposed truncation, making `72bdccc` the final build source.  File-backed `.mp3`, `.wav`, `.flac` and `.ogg` playback now accepts the source-`68f8f26` Alt, Ctrl and Ctrl-plus-Alt fixed jumps through bounded control polling, saturated sample-frame target arithmetic, codec-native random access and the existing READY/GO download reset; the helper flushes pre-jump output and restarts any partial audio-interface update at the absolute target before new PCM is emitted.  WAV, FLAC and Ogg Vorbis retain their miniaudio decoders, while standalone MP3 uses miniaudio's bundled seek-aware backend with sixty-four seek points and preserves the existing MPEG-1 Layer III mono/stereo and 44.1/48 kHz restrictions.  Strict target and UI-reset tests, AddressSanitizer and UndefinedBehaviorSanitizer checks, deterministic real-helper forward/backward seek regressions for all four formats, retained Program Stream random-access, AC-3 recovery, DVD random-access, DVD subpicture, output-reserve and output-stage tests all pass; both Main patches apply to pinned upstream `0a8fb44`, and the full GNU 10.2 ARM helper and Main builds succeed.  The 953,764-byte static ARMv7 helper `host/build/MediaPlayer_Helper_AudioSeek_72bdccc` has SHA-256 `bcd3cbae9d30115784d0f3de5aef9e38b84f58d7ced0a45378ae67101ce94b22`, and the 1,178,588-byte dynamic ARMv7 Main `host/build/MiSTer_AudioSeek_72bdccc` has SHA-256 `b0e5d1f941559139daf82dfe1f03db6fcc3d41d36b48cae527d7c787c99aac05`.  Ordinary arrows, pause, MPG seeking, DVD chapters, authored menus, RTL, RBF and Quartus remain unchanged.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_Helper_AudioSeek_72bdccc` as `/media/fat/linux/MediaPlayer_Helper` and `host/build/MiSTer_AudioSeek_72bdccc` as `/media/fat/MiSTer`, preserve executable modes and the current timing-qualified RBF, then reboot because Main changed.  During each supported standalone audio format, verify Alt+Left/Right, Ctrl+Left/Right and Ctrl+Alt+Left/Right repeatedly in both directions, including clamping near the beginning and end; acceptance requires a prompt clean restart at the expected position, uninterrupted synchronized audio, a correctly restarted progress display and normal playback afterward.  Retest one ordinary MPG seek, pause, one DVD chapter change and authored-menu arrows to prove the unchanged paths, then report hardware acceptance or enable telemetry before playback and collect fresh helper/Main diagnostics for any failure.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/audio_file_seek.c
- host/arm/audio_file_seek.h
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.c
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 884 COMMIT Unreleased eb11247 2026-09-01T21:16:29-07:00

#### Coming From:

Unreleased 68f8f26

#### Purpose:

Add semantic schema-21 overlay telemetry decoding and deterministic regression coverage without rebuilding or changing any MiSTer runtime component.

#### Outcome:

Source `eb11247` teaches `tools/decode-hardware-telemetry.py` that schema 21 retains the common cadence, terminal and schema-20 audio words but replaces words 37 through 54 with overlay-pipeline evidence.  The decoder now reports record, byte, publication, rectangle, ABGR palette, video-sample and capture-trigger semantics without reinterpreting `OVL1` as native deadline counters, validates overlay magic and both protocol-error observations, and clearly marks the unavailable full-width cadence rate.  The new deterministic regression covers the exact checksum-valid 64-word accepted source-`68f8f26` screenshot, a synthetic active authored-menu transfer, protocol-error validation and unchanged schema-20 deadline/audio interpretation.  Python syntax, all four unit tests, JSON decoding, human-readable decoding and raw word-dump decoding passed against the accepted screenshot; it reported bounded no-commit fallback during ordinary video, ready engine state, zero protocol errors, zero transport blocks and zero recurring audio underruns.  RTL, RBF, ARM helper, patched Main and target files were untouched.

#### Next Steps:

Use the schema-21 semantic decoder on a future authored DVD-menu capture to read the nonzero overlay counters directly.  No ARM compiler, Quartus build, MiSTer transfer, reboot or hardware rerun is required for this completed host-tool-only boundary.

#### Files Modified:

- tools/decode-hardware-telemetry.py
- tools/test_hardware_telemetry.py

#### Status:

- [x] Built
- [x] Passed

---

## 883 COMMIT Unreleased 68f8f26 2026-09-01T21:11:53-07:00

#### Coming From:

Unreleased 68f8f26

#### Purpose:

Record physical acceptance of ordinary MPEG Program Stream seeking and distinguish the fresh schema-21 screenshot from stale diagnostic sidecar files.

#### Outcome:

The user reports that source `68f8f26` seeking works perfectly on MiSTer, accepting the fixed ten-second, one-minute and five-minute ordinary `.mpg` jump boundary in hardware.  The fresh 329,184-byte 1,920-by-1,080 screenshot at SHA-256 `31f8765a08fc40e9c63191c3209d36460041d199518468e7e608f809011276e8` shows stable progressive video with the visible telemetry matrix after seeking.  Direct extraction from that image produces a complete 64-word schema-21 snapshot: every prefix, row index and parity bit passes and calculated XOR `7ea59e0a` matches word 63; hardware error flags, the recurring audio-underrun count and transport-block count are zero, while word 54 reports the expected thirty-second no-overlay fallback capture for ordinary video.  The uncertainty is a host reporting limitation rather than a malformed FPGA snapshot: `tools/decode-hardware-telemetry.py` can extract schema-21 words with `--word-dump` but its semantic parser deliberately rejects every schema above 20.  The supplied `telemetry.txt` and `MediaPlayer_ARM.log` retain morning timestamps, hashes `b8361d71fc79fb54a2459ee068ebb0e5397b15416b52e392a71d83ac6a975561` and `49ed6cf08da17fd05625ad2e4be516af2c155021cb2990ffa70fee6a74245303`, and pre-seek contents, so neither is attributed to this fresh hardware run.

#### Next Steps:

Preserve source `68f8f26`, `host/build/MediaPlayer_Helper_ProgramSeek_68f8f26`, `host/build/MiSTer_ProgramSeek_68f8f26` and the timing-qualified source-`dfe1057` RBF as the accepted ordinary-Program-Stream seeking baseline.  Treat semantic schema-21 decoding as a separate host-tool compatibility correction: if approved, extend the decoder for the overlay word layout without changing RTL or playback, add a known-image regression for checksum `7ea59e0a`, and make the screenshot collection script save a fresh semantic report while continuing to preserve raw word-dump evidence.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 882 COMMIT Unreleased 68f8f26 2026-09-01T20:31:54-07:00

#### Coming From:

Unreleased dfe1057

#### Purpose:

Add safe keyboard-driven ten-second, one-minute and five-minute relative seeking for ordinary MPEG Program Stream files without changing audio or DVD navigation.

#### Outcome:

Source `68f8f26` implements the approved first seeking boundary for ordinary file-backed `.mpg` and `.mpeg` Program Streams.  Patched Main maps Alt, Ctrl and Ctrl-plus-Alt with Left or Right to signed ten-second, sixty-second and three-hundred-second control messages while leaving Shift combinations, unmodified arrows and DVD-menu navigation unchanged.  The helper records at most one timestamped video-PES source offset per half second, uses binary lookup for indexed targets, extends the index with a packet-length-aware no-output scan for later targets, clamps at file ends, flushes stale pipe bytes, resets demux, audio and scheduling state, and reuses the proven download-reset plus READY/GO barrier and sequence/I/following-reference random-access gate.  The focused index test passes strict compilation, AddressSanitizer and UndefinedBehaviorSanitizer, the retained random-access, AC-3 recovery, output-reserve and output-stage tests pass, a complete native decode of the user's 492-megabyte `01.mpg` reaches all 60,270 audio frames and 450,552,801 video bytes, and an end-to-end control smoke test completes forward and backward ten-, sixty- and three-hundred-second barriers on that file.  Both Main patches apply cleanly to pinned upstream `0a8fb44`, and the full Main build plus strict native and GNU 10.2 ARM helper builds succeed.  The final 920,948-byte static ARMv7 helper `host/build/MediaPlayer_Helper_ProgramSeek_68f8f26` has SHA-256 `ed0356a8cc941c75d3aac0f53db675da99d7ddaf606f82e42241f4cda89d5fae`; the final 1,174,492-byte dynamic ARMv7 Main `host/build/MiSTer_ProgramSeek_68f8f26` has SHA-256 `0d78e26c84575d825f5701cd9937cbb4cbc0c3cdf971c753b34fd9a4385e3f17`.  Three-second jumps, standalone audio, ISO, physical DVD, authored menus, decoder RTL and the timing-qualified source-`dfe1057` RBF remain unchanged.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_Helper_ProgramSeek_68f8f26` as `/media/fat/linux/MediaPlayer_Helper` and `host/build/MiSTer_ProgramSeek_68f8f26` as `/media/fat/MiSTer`, preserve executable mode and the accepted source-`dfe1057` RBF, then reboot because Main changed.  During ordinary `.mpg` playback, verify Alt+Left/Right, Ctrl+Left/Right and Ctrl+Alt+Left/Right repeatedly in both directions, including clamping near the beginning and end; acceptance requires prompt clean-picture restart, synchronized uninterrupted audio after every jump and normal playback afterward.  Retest unmodified arrows in a DVD menu, P/N chapter changes, Space pause/resume, one audio-only file and one physical DVD to prove the excluded paths remain unchanged, then report hardware acceptance or collect telemetry-enabled helper/Main diagnostics for any failure.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/arm/program_stream_seek.c
- host/arm/program_stream_seek.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_program_stream_seek.c

#### Status:

- [x] Built
- [ ] Passed

---

## 881 COMMIT Unreleased dfe1057 2026-09-01T19:17:39-07:00

#### Coming From:

Unreleased dfe1057

#### Purpose:

Bundle the timing-qualified telemetry build as a release-format community-test archive without creating a semantic-version release.

#### Outcome:

`host/build/MiSTer_Media_Player_dfe1057.zip` follows the current public-package layout with the date-coded `MediaPlayer_20260901.rbf`, patched `MiSTer`, `linux/MediaPlayer_Helper`, `SHA256SUMS`, installation and source-provenance notes, the project licence and all currently bundled dependency licences.  The archive contains the qualified source-`dfe1057` seed-24 RBF, the matched telemetry-aware Main and the unchanged hardware-accepted helper; their respective SHA-256 values are `6389fa57b2d642b5b4e85980c6ccf8746ea8d20869cbe480f80b0ea172bcdb4b`, `74b354977d3ce56c0ad27c90089936d303258a869fa75fa73c80ef6a2edbfd29` and `5de3178711e7893d23ad75e22f1ef19a7905454bf48fc71c9bf98a95db6977a4`.  Fresh extraction preserves executable mode on Main and the helper, all thirteen internal checksum checks pass, ZIP integrity reports no error, and the 3,321,895-byte archive has SHA-256 `38b43973499027cf5788833d8e86a067acaa2dd0acd337e97b8399a0022646ba`.

#### Next Steps:

Distribute the archive explicitly as an unreleased `dfe1057` community test and retain the source-`5f00e35` runtime set as rollback.  Testers should install all three packaged runtime files, reboot, report the source identifier with MPG, DVD, standalone-audio and menu observations, and verify that Telemetry Off creates neither the diagnostic raster nor `/tmp/MediaPlayer_ARM.log` while enabling Telemetry before playback retains both diagnostic paths; community results do not mark the source Passed until the user's current MiSTer test accepts it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 880 COMMIT Unreleased dfe1057 2026-09-01T18:30:20-07:00

#### Coming From:

Unreleased 40dd64d

#### Purpose:

Remove the nine residual HDMI setup violations by shortening the three remaining ASCAL logic-depth clusters without adding visible latency.

#### Outcome:

Source `dfe1057` registers the normal line-plus-burst address during its existing request-preparation cycle, splits the vertical RGB maximum across the existing pixel and coefficient stages, and precomputes the horizontal adaptive enable while preserving vertical-over-horizontal priority, sampled values, Avalon request timing and scaler alignment.  All ten exact-source telemetry, progressive cadence, framebuffer geometry, output timing, audio-interface, DDR-arbiter, DVD-overlay metadata, engine, integrated delivery and snapshot regressions pass.  Quartus Prime 17.0.2 seed 24 completes synthesis in 2 minutes 25 seconds, fitting in 12 minutes 23 seconds and assembly with zero errors; global setup, hold, recovery, removal and minimum-pulse-width margins are positive at 0.180, 0.190, 3.758, 0.644 and 0.925 nanoseconds, with zero violated paths, while dedicated 60 MHz decoder and 54 MHz video setup are positive at 1.220 and 2.215 nanoseconds.  The fit uses 34,859 ALMs, 54,492 registers, 4,187,219 block-memory bits in 536 RAM blocks and 70 DSP blocks.  The byte-identical local and build-PC artifact `output_files/MediaPlayer_20260901_dfe1057.rbf` is 4,480,236 bytes at SHA-256 `6389fa57b2d642b5b4e85980c6ccf8746ea8d20869cbe480f80b0ea172bcdb4b`; the matched 1,178,588-byte telemetry-aware patched Main is collected as `host/build/MiSTer_TelemetryOff_dfe1057` at SHA-256 `74b354977d3ce56c0ad27c90089936d303258a869fa75fa73c80ef6a2edbfd29`, and the accepted 916,852-byte helper remains unchanged at SHA-256 `5de3178711e7893d23ad75e22f1ef19a7905454bf48fc71c9bf98a95db6977a4`.

#### Next Steps:

Preserve the accepted source-`5f00e35` rollback, install `output_files/MediaPlayer_20260901_dfe1057.rbf` and `host/build/MiSTer_TelemetryOff_dfe1057`, retain the unchanged accepted helper, and reboot because Main changes.  Physical validation should confirm normal MPG, DVD and standalone-audio playback with Telemetry Off producing neither the diagnostic raster nor `/tmp/MediaPlayer_ARM.log`, then enable Telemetry before a fresh playback and confirm the diagnostic raster and combined Main/helper log remain available; do not mark this entry Passed until that MiSTer test succeeds.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [ ] Passed

---

## 879 COMMIT Unreleased 40dd64d 2026-09-01T18:08:06-07:00

#### Coming From:

Unreleased 326382a

#### Purpose:

Close the telemetry build's HDMI-domain setup timing structurally without changing decoder, presentation or telemetry behavior.

#### Outcome:

Source `40dd64d` gives cycle-eight its own same-edge outer-pixel register, supplies the vertical red, green and blue DSP groups from independent value-identical coefficient registers protected from merging, and permanently adds a routed one-hundred-path global setup report to the existing TimeQuest extractor.  All ten exact-source telemetry, progressive cadence, framebuffer geometry, output timing, audio-interface, DDR-arbiter, DVD-overlay metadata, engine, integrated delivery and snapshot regressions pass.  Quartus Prime 17.0.2 seed 24 completes synthesis in 2 minutes 24 seconds, fitting in 12 minutes 23 seconds and assembly with zero errors; the targeted negative 0.978-nanosecond outer-pixel route and nineteen negative 0.581-nanosecond shared-coefficient routes disappear, while global setup improves to negative 0.138 nanoseconds with only nine residual `ascal` violations.  Global hold, recovery, removal and minimum-pulse-width margins remain positive at 0.248, 3.710, 0.477 and 0.925 nanoseconds, and the dedicated 60 MHz decoder and 54 MHz video setup checks are clean at positive 0.717 and 1.573 nanoseconds.  The fit uses 34,681 ALMs, 54,549 registers, 4,187,203 block-memory bits in 535 RAM blocks and 70 DSP blocks; its RBF remains rejected on the build PC.

#### Next Steps:

Proceed through entry 880's separately recorded second structural correction for the nine measured residual paths, retaining seed 24 and every accepted source-`5f00e35` artifact.  Do not collect or distribute the source-`40dd64d` RBF.

#### Files Modified:

- sys/ascal.vhd
- tools/phase1p_timing.tcl

#### Status:

- [x] Built
- [ ] Passed

---

## 878 COMMIT Unreleased 326382a 2026-09-01T18:02:25-07:00

#### Coming From:

Unreleased 326382a

#### Purpose:

Record the final permitted seed-24 telemetry build result and stop without distributing a timing-rejected RBF.

#### Outcome:

Exact source `326382a` passes all ten focused and retained Icarus regressions covering default-hidden and live telemetry visibility, progressive cadence and geometry, 480p and 480i output timing, the complete 64,800-word audio-interface upload, DDR arbitration, DVD-overlay extraction, engine, integrated stalled-DDR delivery and schema-21 snapshot triggering.  The strict native helper, static ARMv7 helper and patched ARMv7 Main builds also succeed, with both generated Main patches applying cleanly to pinned upstream `0a8fb44`.  Quartus Prime 17.0.2 seed 24 completes synthesis in 2 minutes 25 seconds, fitting in 12 minutes 24 seconds and assembly with zero errors, but is rejected at negative 0.978-nanosecond global setup slack while global hold, recovery, removal and minimum-pulse-width slacks remain positive at 0.254, 3.432, 0.395 and 0.925 nanoseconds.  Dedicated 60 MHz decoder and 54 MHz video setup are violation-free at positive 0.555 and 1.128 nanoseconds.  The fit uses 34,587 ALMs, 53,873 registers, 4,187,203 block-memory bits in 535 RAM blocks and 70 DSP blocks.  The 4,465,712-byte generated RBF is rejected and remains only on the build PC; no new RBF or Main is collected locally, and the accepted source-`5f00e35` RBF/helper pair remains untouched.

#### Next Steps:

Pause at source `326382a` under the one-reseed limit.  Resume only with explicit user approval for a timing-correction cycle; first inspect the global HDMI-domain failing paths from both rejected placements, then choose a structural or constraint correction rather than another blind seed and require all ten simulations plus a fully positive timing gate before collecting the telemetry RBF and Main for physical validation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 877 COMMIT Unreleased 326382a 2026-09-01T17:44:34-07:00

#### Coming From:

Unreleased 60d7c75

#### Purpose:

Perform the single permitted fitter reseed after the telemetry source passes regressions but the accepted seed-23 placement narrowly misses unrelated global setup timing.

#### Outcome:

The exact source-`60d7c75` build completes synthesis in 2 minutes 26 seconds, fitting in 11 minutes 22 seconds and assembly with zero errors, but is rejected by the project timing gate at negative 0.164-nanosecond global setup slack in the HDMI output clock domain.  Dedicated 60 MHz decoder and 54 MHz video setup remain clean at positive 0.265 and 2.021 nanoseconds, and global hold, recovery, removal and minimum-pulse-width slacks remain positive at 0.220, 3.826, 0.603 and 0.925 nanoseconds.  The fit uses 34,466 ALMs, 53,977 registers, 4,187,203 block-memory bits in 535 RAM blocks and 70 DSP blocks.  Source `326382a` changes only the fitter seed from 23 to 24 for the one permitted retry; the seed-23 RBF is rejected and the previously accepted source-`5f00e35` artifact remains the rollback.

#### Next Steps:

Change only the fitter seed from 23 to 24, rerun the ten passing focused and retained simulations from exact source, then perform one clean Quartus build and require positive global setup, hold, recovery, removal and minimum-pulse-width timing plus zero violations in the dedicated decoder and video reports.  Stop without further reseeding if seed 24 fails.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---

## 876 COMMIT Unreleased 60d7c75 2026-09-01T17:15:50-07:00

#### Coming From:

Unreleased 5f00e35

#### Purpose:

Add a default-off production telemetry mode that preserves internal schema-21 capture while suppressing both its visible raster and ARM/Main diagnostic logging.

#### Outcome:

Source `60d7c75` assigns unused saved OSD status bit 125 to `Telemetry`, defaulting its zero state to Off.  FPGA schema-21 counters, capture timing and snapshot contents remain unconditional, while a three-stage video-domain synchronizer gates only diagnostic raster composition and an updated first-stage timing exception replaces the obsolete status-125 target from the deleted diagnostic generator.  Main samples the same bit before each helper launch: Off opens no diagnostic log, removes any stale RAM-backed `/tmp/MediaPlayer_ARM.log`, makes Main diagnostic writes no-ops and redirects helper standard error to `/dev/null`, while On retains the existing combined Main/helper log.  Both generated Main patches apply in order to pinned upstream `0a8fb44` and the resulting complete ARM translation unit builds successfully with GNU 10.2; the new focused RTL regression covers hidden capture, live reveal and re-hide.  Media bytes, decoder scheduling, PCM delivery, DVD navigation, audio-interface rendering and diagnostic schemas are unchanged.

#### Next Steps:

Push exact source `60d7c75`, run the focused visibility test and retained media, audio-interface, overlay and DDR regressions on build PC `10.10.0.42`, build strict native and ARM Main/helper artifacts, then build one timing-qualified RBF from the accepted seed-23 baseline.  Preserve the matched RBF and Main locally for user transfer, then require physical MPG, DVD and standalone-audio playback with no visible stripe or `/tmp/MediaPlayer_ARM.log` at Telemetry Off, plus a retained visible stripe and combined log after enabling Telemetry before playback.

#### Files Modified:

- MediaPlayer.sv
- MediaPlayer.sdc
- README.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- host/main_mister/0002-mediaplayer-overlay-trace.patch
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/test_telemetry_visibility.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 875 COMMIT Unreleased 5f00e35 2026-09-01T07:34:29-07:00

#### Coming From:

Unreleased 5f00e35

#### Purpose:

Record physical acceptance of the timing-qualified ARM-rendered standalone-audio interface and its moving progress presentation.

#### Outcome:

The user reports that source `5f00e35` looks great on MiSTer and explicitly confirms that the progress bar moves correctly during standalone FLAC playback.  The 9,154-byte 1,920-by-1,080 screenshot at SHA-256 `674f4dab0fdfa1636f195b75af90f89425dda637ddff0e92cb216cdd19de0dd5` shows a clean stable native presentation with the reserved square album-art viewport, transport panel, progress bar and activity ruler plus reserved metadata strip.  The 6,000,885-byte Main/helper log at SHA-256 `0aff68b888e6c58f4d3733c4de0e915a9dbb62efd8f04c8ae0a750ca969a831f` starts `Symphony No.6 (1st movement).flac`, selects decoded stereo HDMI PCM and enables the 720-by-480p BT.601 audio interface; across approximately one hundred seconds it carries 99 frame begins, 12,559 data chunks and 98 commits.  Every completed frame contains exactly 127 chunks comprising 126 full 4,096-byte payloads and one 2,304-byte tail, with zero framing or ordering failures, while the final begun frame is merely partial at capture time.  Main's repeated `overlay_submit unknown` and `order_errors` labels are stale diagnostic classification of the newly valid commands `0x10`, `0x11` and `0x12`, not FPGA or transport faults; the log contains no fatal, decoder, protocol, unsupported-stream or transport error.  The 2,818-byte file at SHA-256 `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004` records only that the legacy screenshot telemetry decoder finds no stripe in the audio-interface image, as expected, and is not a failed hardware snapshot.  The timing-qualified RBF/helper pair is physically accepted for this first audio-interface boundary.

#### Next Steps:

Preserve `output_files/MediaPlayer_20260901_5f00e35.rbf` and `host/build/MediaPlayer_Helper_AudioUI_5f00e35` together as the accepted standalone-audio interface baseline while retaining source `add7d00` as the prior video-only rollback.  In the next approved feature cycle, teach the ARM renderer to populate the reserved viewport and metadata strip from bounded album-art and tag decoding without increasing the one-hertz FPGA publication rate or weakening PCM priority; also update Main's passive record profiler to recognize commands `0x10` through `0x12` so future logs do not mislabel valid UI records as DVD-overlay order errors.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 874 COMMIT Unreleased 5f00e35 2026-09-01T07:09:16-07:00

#### Coming From:

Unreleased f0fba4d

#### Purpose:

Restore the known seed-23 placement for the synchronized audio-interface source and require a clean full-core timing result.

#### Outcome:

Source `5f00e35` restores seed 23 while retaining the source-`f0fba4d` three-stage audio-startup blank synchronizer and its resolved first-stage-only timing exception.  The exact source matches on Raspberry Pi and build PC `10.10.0.42`; the focused audio-interface regression reconstructs all 64,800 DDR words and one safe commit, and the retained DDR-arbiter priority and response-ownership regression passes.  Quartus Prime 17.0.2 completes synthesis in 3 minutes 11 seconds, fitting in 11 minutes 45 seconds, assembly and the full timing gate with zero errors.  Global setup, hold, recovery, removal and minimum-pulse-width slacks are positive at 0.110, 0.124, 4.037, 0.597 and 0.925 nanoseconds; dedicated 60 MHz decoder and 54 MHz video setup slacks are 0.689 and 2.528 nanoseconds with no violations.  The fit uses 34,837 ALMs, 54,693 registers, 4,187,011 block-memory bits in 535 RAM blocks and 70 DSP blocks.  The byte-identical local and build-PC artifact `output_files/MediaPlayer_20260901_5f00e35.rbf` is 4,462,772 bytes at SHA-256 `74a529213b4dfdcb4f2784f9c21129d625743d489315c211058f20e61da6603a`; the matching 916,852-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_AudioUI_5f00e35` has SHA-256 `5de3178711e7893d23ad75e22f1ef19a7905454bf48fc71c9bf98a95db6977a4`.

#### Next Steps:

Exit MediaPlayer so the running helper releases its executable, transfer `host/build/MediaPlayer_Helper_AudioUI_5f00e35` as `/media/fat/linux/MediaPlayer_Helper`, preserve executable mode, and upload `output_files/MediaPlayer_20260901_5f00e35.rbf` as a new core file while retaining the accepted source-`add7d00` rollback.  Test standalone MP3, WAV, FLAC and Ogg Vorbis playback for uninterrupted audio, stable native 720-by-480 output, the reserved album-art viewport, static controls and once-per-second activity motion; then retest a known-good progressive MPG and physical DVD menu before reporting acceptance or collecting a fresh helper/Main log, screenshot and telemetry for any failure.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 873 COMMIT Unreleased f0fba4d 2026-09-01T05:51:42-07:00

#### Coming From:

Unreleased add7d00

#### Purpose:

Add the first audio-only ARM-rendered user-interface boundary with reserved album-art space and atomic one-hertz progress presentation.

#### Outcome:

Source `f0fba4d` implements the first standalone-audio presentation boundary: the ARM helper renders a deterministic limited-range BT.601 720-by-480 4:2:0 interface with a reserved 280-by-280 album-art viewport, static transport panel, reserved metadata strip and sample-clock-driven activity ruler.  Bounded in-band begin, data and commit records upload one complete frame into the inactive existing DDR framebuffer bank without passing through H.262 syntax; PCM records retain transport priority, publication is atomic at a safe frame boundary and DVD overlay commands retain their existing route and arbitration order.  Strict native and Raspberry Pi GNU 10.2 ARM builds pass, the 916,852-byte static stripped ARMv7 helper has SHA-256 `5de3178711e7893d23ad75e22f1ef19a7905454bf48fc71c9bf98a95db6977a4`, 48 kHz and 44.1 kHz renderer tests pass, sanitizer coverage passes, and a 3.2-second WAV integration emits 9,600 PCM records plus three complete UI commits with every UI record following PCM service.  The exact-source FPGA UI regression reconstructs all 64,800 64-bit writes and one safe commit, while the retained DDR-arbiter regression passes.  Seed 23 completed synthesis, fitting and assembly but was rejected at negative 7.142-nanosecond global setup slack because the new first-frame loading level directly crossed from the 60 MHz decoder domain into 54 MHz video blanking; `f0fba4d` corrects that structural defect with an explicit three-stage video-domain synchronizer and a first-stage-only timing exception.  The one permitted seed-24 attempt passed the focused regressions and synthesis, but the user cancelled it after approximately 30 minutes in fitting because routing was progressing abnormally slowly.  No timing-qualified RBF was produced or collected.

#### Next Steps:

Pause at source `f0fba4d` as requested and preserve the physically accepted source-`add7d00` RBF and installed helper on MiSTer.  Do not install the new audio-UI helper by itself because its display records require the matching FPGA implementation.  Resume only with explicit user approval; first inspect the cancelled seed-24 fitter reports and constrain any next attempt to a separately approved build boundary, then require a timing-clean RBF before transferring both the new helper and RBF for physical standalone MP3, WAV, FLAC and Ogg Vorbis validation plus retained MPG and DVD regression testing.

#### Files Modified:

- MediaPlayer.sv
- MediaPlayer.qsf
- MediaPlayer.sdc
- README.md
- docs/ARCHITECTURE.md
- files.qip
- host/arm/Makefile
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- rtl/mpeg2_new/mpeg2_h262_audio_ui.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_display_record_router.sv
- tools/test_audio_ui_output.c
- tools/test_dvd_overlay_arbiter.sv
- tools/test_mpeg2_audio_ui.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 872 COMMIT Unreleased add7d00 2026-09-01T04:57:47-07:00

#### Coming From:

Unreleased add7d00

#### Purpose:

Record physical acceptance of native progressive presentation while confirming that the retained DVD path remains unchanged.

#### Outcome:

The user physically accepts source `add7d00` and its 4,478,208-byte `MediaPlayer_20260901_add7d00.rbf`: progressive MPG files play well through the new native 720-by-480p path and DVD playback behaves the same as before, closing the removal of the 800-by-600 presentation mode.  The collected 1,793,035-byte Main/helper log at SHA-256 `14ecb520c5d8d6f845e5b7ba12febbbde66a74fc80d5c51bb9c511d0d8931eed` independently confirms a complete physical-DVD run with successful root-menu entry, right and left navigation across all four buttons, activation, the authored finite still, staged destination output, delayed stream hop, post-hop random access and one complete 22-record, 86,400-byte overlay at zero order errors, with no transport fault, fatal event, unsupported-stream report or decoder error.  The 566,331-byte 1,920-by-1,080 screenshot at SHA-256 `ac586df0d0ca936ceb208f4a4e08927ff89169f54dd67d6c70eaeb75746b6691` shows stable displayed video, and the 818-byte schema-21 snapshot at SHA-256 `f268ca46da9cd93f4cc02a06bac18b8c9a277937844acaf7451610a1d5277329` passes all 64 prefixes, row indices and parity bits with checksum `36a563a4` matching word 63.

#### Next Steps:

Preserve source `add7d00`, the accepted RBF and the existing Main/helper as the hardware baseline.  Prepare showcase media as progressive 720-by-480 4:2:0 MPEG-2 Program Streams at the source-appropriate supported rate from 24000/1001 through 30 frames per second, with I, P and B pictures and 48 kHz stereo MPEG Layer II audio; begin a new development cycle only when a reproducible unsupported stream or separate requested feature provides the next boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 871 COMMIT Unreleased add7d00 2026-09-01T03:23:04-07:00

#### Coming From:

Unreleased 59f6312

#### Purpose:

Replace the development-era 800-by-600 fallback with native 720-by-480 progressive presentation while preserving the physically accepted 480i decoder path.

#### Outcome:

Source `add7d00` removes the standalone and embedded 800-by-600 timing paths, makes exact 720-by-480 progressive at 60000/1001 the reset presentation, retains the existing 720-by-480i field path for supported interlaced and film-in-interlaced sequences, and admits progressive 4:2:0 frame-picture I, P and B sequences through 720 by 480 at H.262 rate codes one through five.  Progressive framebuffer geometry is now centered inside the permanent 720-by-480 raster, the extracted cadence accumulator implements exact source-to-output ratios including two presentations per five output frames for 24000/1001, and presentation mode changes complete only on safe frame or field boundaries.  The obsolete generator is absent from the active QIP and the legacy inactive wrapper, while historical changelog text and the excluded frozen `rtl/mpeg2fpga` reference remain intact.  All nine focused and retained SystemVerilog regressions pass on exact source, and deterministic fixtures probe as 720-by-480 progressive 24000/1001 and top-field-first interlaced 30000/1001.  Clean Quartus Prime 17.0.2 seeds 20, 21 and 22 were rejected for unrelated global setup slacks of negative 0.010, 0.409 and 0.130 nanoseconds; seed 23 completes synthesis, fitting, assembly and the project timing gate with positive setup, hold, recovery, removal and minimum-pulse-width slacks of 0.224, 0.244, 3.333, 0.625 and 0.925 nanoseconds, plus dedicated 60 MHz decoder and 54 MHz video setup slacks of 0.872 and 2.685 nanoseconds with no violations.  The fit uses 35,092 ALMs, 54,790 registers, 4,187,011 block-memory bits in 535 RAM blocks and 70 DSP blocks.  The byte-identical local and build-PC artifact `output_files/MediaPlayer_20260901_add7d00.rbf` is 4,478,208 bytes at SHA-256 `33ecb87988427d44a97993dc7dda53930c60b0397d0a0202a6e928bb36aa048f`; Main, the helper, DVD navigation, audio and record formats are unchanged.

#### Next Steps:

Upload only `output_files/MediaPlayer_20260901_add7d00.rbf` to the MiSTer while preserving the installed Main and helper, then test the generated-style 720-by-480 progressive 24000/1001 MPEG-2 Program Stream and an ordinary progressive code-four or code-five stream for stable native video, correct centering, smooth exact cadence and no vertical-line artifact.  Retest the known-good 720-by-480 top-field-first 30000/1001 interlaced reference for unchanged field order, motion and DVD overlay behavior, then report the installed RBF hash and capture a fresh screenshot, helper/Main log and telemetry if either presentation family fails; hardware acceptance is required before marking this entry Passed.

#### Files Modified:

- MediaPlayer.qsf
- MediaPlayer.sdc
- MediaPlayer.sv
- README.md
- files.qip
- rtl/mpeg2_decoder.sv
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_native_startup.sv
- rtl/mpeg2_new/mpeg2_h262_output_cadence.sv
- rtl/mpeg2_progressive_geometry.sv
- rtl/mpeg2_video_output_timing.sv
- rtl/mpeg2_video_svga_800x600.sv
- tools/generate-progressive-regression.sh
- tools/test_mpeg2_output_timing.sv
- tools/test_mpeg2_progressive_cadence.sv
- tools/test_mpeg2_progressive_framebuffer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 870 COMMIT Unreleased 59f6312 2026-09-01T02:45:32-07:00

#### Coming From:

Unreleased 22e780a

#### Purpose:

Stage ambiguous post-activation DVD output until the authored menu destination can be classified without losing its background frame or regressing Play.

#### Outcome:

Source `59f6312` adds a bounded four-megabyte helper output transaction for ambiguous same-title DVD menu activations.  When libdvdnav returns pending activation, the helper resets its parser and audio scheduling state and stages all newly generated video, in-band PCM and overlay records with their record order and priority tags while the old physical-DVD reserve remains independently drainable.  A destination containing payload followed by an indefinite still now discards only that stale reserve, enters the established Main ready/go decoder barrier and commits the staged destination after rearm without clearing the newly decoded subpicture state; an empty indefinite still cancels its empty transaction and retains the resident-frame continuation, while a finite still commits immediately and retains the authored delay and later title-hop behavior.  Chapter, root, menu-leave and superseding-command paths cancel obsolete transactions explicitly, and partial commit failure retains only unwritten records.  One hundred repeated byte-exact stage tests, stale-reserve preservation, AddressSanitizer, UndefinedBehaviorSanitizer, GCC analyzer, strict native and sanitizer helper builds, capabilities, output-reserve, AC-3 recovery, random-access, subpicture and menu-hop tests plus twenty production 86,400-byte overlay reconstructions pass.  The Raspberry Pi GNU 10.2.1 toolchain builds `host/build/MediaPlayer_Helper_SceneStage_59f6312`, a 916,852-byte static stripped ARMv7 EABI5 hard-float executable with no dynamic section at SHA-256 `12946bc036c497088a9016db5a613f4a9c33c17e19c6fce75e97fd3f060026bc`; Main, RTL, the source-`1bf06db` RBF, record formats and Quartus are untouched.

#### Next Steps:

Exit MediaPlayer so the running helper releases its executable, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_SceneStage_59f6312`, restore executable mode if needed and verify the recorded size and SHA-256 while preserving the installed source-`22e780a` Main and source-`1bf06db` RBF.  Reboot or restart the core, enter the root menu, activate Scene Selection and require its authored background and selector to appear and remain interactive instead of retaining the root background and freezing; then activate a scene, return to the root menu, exercise Play, directional controls and several chapter hops, and capture a fresh helper/Main log, screenshot and telemetry for physical acceptance.  The decisive log path must show activation staging, a payload-bearing indefinite staged hop, stale reserve discard, ready/go release and staged commit without `MENU_CONTINUE` for the Scene Selection transition.

#### Files Modified:

- host/arm/Makefile
- host/arm/media_player_helper.c
- host/arm/output_stage.c
- host/arm/output_stage.h
- tools/test_output_stage.c

#### Status:

- [x] Built
- [ ] Passed

---

## 869 COMMIT Unreleased 22e780a 2026-09-01T02:39:54-07:00

#### Coming From:

Unreleased 22e780a

#### Purpose:

Close the accepted chapter-transition masking limitation and localize the missing Scene Selection menu background after activation from the root menu.

#### Outcome:

The user explicitly accepts the remaining visible chapter scramble as a closed known limitation and preserves the source-`22e780a` Main/helper with the source-`1bf06db` RBF.  A fresh reboot-to-root-menu run then moves correctly through all four root buttons and successfully activates Scene Selection, but the screenshot retains the old root-menu background behind the new upper selection rectangle and the remaining video naturally drains and freezes after approximately one or two seconds.  The 1,111,768-byte log at SHA-256 `2645d8dafd7c361e19b672ba02d8b453b2b1fa19dcac52a1334f53385074249d` proves activation command `0x08` succeeds on button four, enters the pending same-title-zero path, consumes 249 post-activation payload start codes with a PTS discontinuity, receives a new SPU stream and complete new menu overlay, then reaches an authored indefinite still and incorrectly sends `MENU_CONTINUE`; Main consequently logs `DVD menu continuation preserved resident frame` instead of performing a decoder barrier.  The helper source reaches the indefinite still at 22.322828 seconds while its four-megabyte reserve continues feeding queued bytes until 27.203381 seconds, explaining the short additional motion and subsequent non-crash freeze.  The 686,552-byte screenshot at SHA-256 `a2df586866caaafb9f378dd8ea3c81206f273a637bb18c0e4395391a5c8965f6` visibly confirms the stale base frame and new upper selector, while checksum-valid schema-21 telemetry at SHA-256 `2ee40370dcb3f010c68434bcc36e5256ff14ee4893c8411750dff87e0df54ad7` proves the second 86,400-byte plane received all 22 data records, accepted one commit, published one plane and has no decoder error flags.  The fault is therefore helper-side deferred-activation classification and old-reserve ownership, not DVD button navigation, the overlay pipeline, FPGA rendering or a decoder crash.

#### Next Steps:

After user approval, preserve Main and the RBF and add a bounded helper-side activation transaction that separates all post-activation output from the pre-activation reserve while libdvdnav exposes the destination.  An indefinite still reached after destination payload must discard only stale pre-activation reserve data, enter the existing ready/go stream-hop barrier and release the staged clean destination menu after rearm; a no-payload indefinite still must retain the resident-frame continuation, while finite-still Play must release its staged transition normally and keep the pending activation alive for the later title hop.  Add focused reserve and menu-navigation regressions for all three paths, rerun AC-3, random-access, subpicture and overlay-priority validation, then build only a new helper locally for physical Scene Selection, Play and root-return testing.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 868 COMMIT Unreleased 22e780a 2026-09-01T02:27:02-07:00

#### Coming From:

Unreleased 22e780a

#### Purpose:

Qualify the source-`22e780a` navigation-discard and chapter-blank changes on physical hardware and localize the remaining visible chapter scramble.

#### Outcome:

The user's physical source-`22e780a` run accepts the helper reserve discard and every tested control path: all buttons operate correctly, chapter transitions are visibly faster, and 51 consecutive chapter requests comprising 25 next and 26 previous commands complete without a fatal helper or transport event.  Main records `chapter startup blank rearmed` for every request, the helper discards between 528,161 and 4,188,934 obsolete reserved bytes at complete record boundaries, and rearm-to-barrier latency is 2,206 microseconds minimum, 25,936 microseconds median, 22,584 microseconds mean and 95,160 microseconds maximum; two root requests reach stream-hop ready in 23,249 and 49,993 microseconds.  The requested black masking is rejected because the user still sees the transition scramble.  The 6,371,107-byte log at SHA-256 `cb7b5d9059fbfb734cfa4950826d27fb051e92d5f033377bc366a7753d1befc5` proves that the first post-barrier payload is a seven-byte overlay-clear record before each clean random-access video group, while the installed source-`1bf06db` RBF makes any `dvd_overlay_record_valid` event sticky-bypass the existing startup blank; the host correctly rearms the session, but the core releases black on that overlay clear approximately 0.2 to 0.3 seconds before the first clean chapter video reaches Main.  The matching screenshot and checksum-valid schema-21 telemetry have SHA-256 `73e81bba6248cf8408cd235e6b5551a3e417596f9b6007430f2116d497d5ce95` and `19c6fbca57ec69db661347a684b04e93ddfe8c9da3330f603c3f6d3036b0256d`; the snapshot reports no decoder error flags but is not timed to observe the transient blank state.

#### Next Steps:

Preserve source `22e780a` Main and helper because their speed and controls pass.  After user approval, make a narrowly scoped RBF correction that latches black on each download rearm independently of metadata, PCM and DVD overlay traffic and releases it only when the new decoder session has a clean presentable video frame, without delaying helper output, chapter barriers, audio or video decode; retain the existing native-startup swap policy separately, add focused simulation for overlay clear and audio records arriving before the first random-access picture, then perform a timing-clean Quartus build for physical chapter-transition validation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 867 COMMIT Unreleased 22e780a 2026-09-01T01:55:58-07:00

#### Coming From:

Unreleased 58196d6

#### Purpose:

Remove avoidable reserved-output latency from DVD root and chapter hops while hiding any irreducible chapter transition behind the existing clean-start blank.

#### Outcome:

Source `44a1cc9` implements the approved host-only boundary and source `22e780a` corrects the generated Main patch's new-file hunk length after the first exact build exposed truncation, making `22e780a` the final build source.  The helper's atomic discard request waits only for a record already being written, drops every later queued normal and priority record, blocks concurrent producers until that boundary completes and reports the discarded byte count; root, previous and next navigation use it while activation and ordinary completion retain the existing exact drain.  Main now lowers and immediately reasserts download at an `N` or `P` key press, leaving the already installed FPGA startup blank active throughout helper seeking and stale-pipe discard, then sends go without a second reset; root and Play navigation retain their prior Main sequencing and the disc-authored ten-second still is unchanged.  The stalled-sink reserve regression passes 100 consecutive runs, preserving the complete active record and new post-discard record while dropping exactly 1,048,647 queued obsolete bytes, and also passes AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer validation.  Strict native helper and capabilities, AC-3 recovery, random access, subpicture, immediate and delayed menu-hop, plus 20 repeated production overlay-priority runs pass.  Both Main patches apply cleanly to pinned upstream `0a8fb44` and the complete Main ARM build succeeds.  The Raspberry Pi GNU 10.2.1 toolchain builds `host/build/MediaPlayer_Helper_NavBlank_22e780a`, a 912,756-byte static stripped ARMv7 EABI5 executable with no dynamic section at SHA-256 `a3c7ae74e5e40394b2931874ec3244bb805350626e3ea5160ba96a78a0ec9b60`, and `host/build/MiSTer_NavBlank_22e780a`, a 1,178,588-byte stripped dynamic ARMv7 EABI5 executable at SHA-256 `48dd016c5d83d8d2dbe8ab93794b01dd58d5dcf4fe424cda3c145b4dc1907ddb`.  RTL, the source-`1bf06db` RBF and Quartus are untouched.

#### Next Steps:

Exit MediaPlayer so its helper stops, replace `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_NavBlank_22e780a`, replace `/media/fat/MiSTer` with `host/build/MiSTer_NavBlank_22e780a`, restore executable modes if needed, verify both recorded sizes and hashes, and reboot because Main changed while preserving the source-`1bf06db` RBF.  Exercise repeated `M`, rapid forward and backward chapter runs, selector arrows and Play.  The log must show `navigation reserve discarded` for commands `0x09`, `0x01` and `0x02` plus `chapter startup blank rearmed` for previous and next; acceptance requires root and chapter command-to-barrier timing no slower than source `58196d6`, near-instant chapter changes where the drive permits, black rather than scrambled video until each first clean chapter picture, unchanged selector response, the authored Play still and continuing synchronized playback after aggressive seeking and an optical stall.  Capture a fresh helper/Main log, screenshot and telemetry for physical qualification.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/output_reserve.c
- host/arm/output_reserve.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_output_reserve.c

#### Status:

- [x] Built
- [ ] Passed

---

## 866 COMMIT Unreleased 58196d6 2026-09-01T01:42:17-07:00

#### Coming From:

Unreleased 58196d6

#### Purpose:

Qualify the priority-overlay helper on physical hardware and isolate the remaining root-menu and Play response delays.

#### Outcome:

The user's physical source-`58196d6` capture accepts the 256-kibibyte priority overlay lane: the helper uniquely reports the four-megabyte normal reserve plus priority capacity, twelve directional changes visibly respond well, and Main receives each corresponding authored selector rectangle without overlay framing errors before activation.  Root-menu command `0x09` is submitted at 10.293811 seconds, the helper completes the root hop almost immediately, but Main does not receive navigation ready until 13.594761 seconds and releases the barrier at 13.595371 seconds, proving an artificial 3.301560-second wait while the helper drains obsolete normal-media reserve data.  Activation command `0x08` is submitted at 35.693855 seconds; its selector-clear style reaches Main at 36.073282 seconds, only 0.379427 seconds later, then the helper explicitly waits the disc-authored ten-second finite still and reports menu leave at 45.910168 seconds, so the 10.216313-second Play delay is authored navigation behavior rather than reserve or overlay latency.  More than twenty subsequent chapter barriers complete successfully and the user reports `N` and `P` remain fast.  The 4,062,817-byte log has SHA-256 `a1250d181338173b42b5d3817cf46accc40558ea78beb6227566c91373d09cf8`; the 541,595-byte screenshot and checksum-valid schema-21 telemetry have SHA-256 `01bed1b8cb9e28e0750eb563e1702d202fc1153d5fa84fd78d14ed083b717a4e` and `a6a90a2811ae5fcb2790621dc3ea7df2d5b02136127313054b57f3d961f56197`.

#### Next Steps:

Preserve Main, the RBF, the priority overlay lane and the existing `N` and `P` path.  After user approval, make a helper-only reserve-boundary change that finishes any record already being written, discards queued obsolete normal media for root-menu stream hops and lets Main's existing decoder barrier discard already-piped stale bytes, eliminating the artificial `M` drain without weakening the optical-stall reserve during ordinary playback.  Keep the authored ten-second finite Play still unless the user explicitly chooses immediate activation semantics; skipping that still is a separate DVD-navigation policy change and must retain the pending activation until libdvdnav exposes menu leave.  Validate reserve byte integrity, concurrent discard at every record boundary, menu overlay priority, root and delayed-activation hops, random access, AC-3 recovery and exact local ARM output before physical retest.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 865 COMMIT Unreleased 58196d6 2026-09-01T01:30:48-07:00

#### Coming From:

Unreleased 5ae655a

#### Purpose:

Preserve the physical-DVD output reserve while allowing menu overlay changes to bypass its multi-second normal-media backlog at complete record boundaries.

#### Outcome:

The user's physical source-`5ae655a` capture proves that the four-megabyte output reserve is active and leaves chapter `N` and `P` transitions as responsive as before, and the user cannot yet reproduce the original first-chapter audio dropout, but the run rejects its FIFO ordering for interactive menu use.  The helper handles Right at approximately 19.155498 seconds while Main receives the corresponding selector style at 24.194433 seconds, a 5.038935-second delay, then handles Left at approximately 26.065074 seconds while Main receives that style at 31.576002 seconds, a 5.510928-second delay; Activate reaches the helper in approximately 83 milliseconds, isolating the latency to the in-band overlay waiting behind queued A/V.  Source `58196d6` preserves the four-megabyte normal reserve, marks every complete producer write with a compact boundary map and adds a bounded 256-kibibyte FIFO priority lane serviced only between complete normal records, so an overlay cannot split PCM or another framed output.  Every overlay header and payload is now assembled into one priority record.  The focused stalled-pipe regression proves that a 49-byte priority update overtakes a four-megabyte normal backlog exactly after the already active two-megabyte test record while all 6,291,505 output bytes remain exact, passes 100 consecutive runs, and passes sanitizer and static-analyzer validation; the real production emitter also passes 20 repeated priority-drain runs while reconstructing its one configuration, 22 records and all 86,400 authored plane bytes exactly.  Strict native and optional solid-overlay-probe helper builds, full capabilities, AC-3 recovery, random access, subpicture and immediate/delayed menu-hop regressions pass.  The Raspberry Pi GNU 10.2.1 toolchain builds exact source `58196d6` into `host/build/MediaPlayer_Helper_MenuPriority_58196d6`, a 912,756-byte static stripped ARMv7 EABI5 executable at SHA-256 `759d01177f37d7b2d624a026ac3d8aa68a8f24ac72e1704e01f4d1e11d9bf649`; it has no dynamic section, contains the reserve-priority and false-sync recovery diagnostics, and omits authored-selector compensation and the solid-magenta overlay probe.  Main, RTL, the source-`1bf06db` RBF and Quartus are untouched.

#### Next Steps:

Exit MediaPlayer so its current helper stops, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_MenuPriority_58196d6`, restore executable mode if needed, and verify the 912,756-byte size and recorded SHA-256 while preserving the installed source-`2de0717` Main and source-`1bf06db` RBF.  The new log marker must report `DVD output reserve=4194304 bytes overlay_priority=262144 bytes`.  Enter the menu, rapidly move the selector among all buttons and activate Play; acceptance requires visually immediate correctly aligned selector changes rather than the measured five-second lag, reliable menu and Play transitions, and no overlay framing or plane corruption.  Then repeat rapid forward and backward chapter changes before playing chapter one continuously; acceptance also requires the previously retained fast `N` and `P` response, a surviving helper, no reproduced audio dropout through a comparable optical stall and continued A/V synchronization.  Capture a fresh helper log, screenshot and telemetry for physical acceptance.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/output_reserve.c
- host/arm/output_reserve.h
- tools/test_dvd_overlay_output.c
- tools/test_output_reserve.c

#### Status:

- [x] Built
- [ ] Passed

---

## 864 COMMIT Unreleased 5ae655a 2026-09-01T01:03:21-07:00

#### Coming From:

Unreleased 0318f70

#### Purpose:

Add a bounded helper-side output reserve so temporary physical-DVD read stalls after aggressive chapter seeking do not interrupt otherwise recoverable playback.

#### Outcome:

Source `5ae655a` adds a four-megabyte helper-side ring reserve between the synchronous physical-DVD producer and a dedicated output writer, preserving exact byte order while giving the producer approximately four seconds of combined-stream read-ahead through temporary optical-source stalls.  Capacity backpressure is bounded, writer errors propagate to the producer, navigation barriers and shutdown explicitly drain the reserve, and the reserve is enabled only for physical-DVD program-stream playback through the in-band output so ISO, file and split-output behavior remains unchanged.  A focused stalled-pipe regression proves that two megabytes can enqueue before a reader exists and that six megabytes spanning repeated drain and ring-wrap cycles emerge byte-identically; strict native, sanitizer, analyzer, capability, production-overlay, AC-3, random-access, subpicture and menu-hop validation also passes.  The Raspberry Pi GNU 10.2.1 toolchain builds exact source `5ae655a` into `host/build/MediaPlayer_Helper_DVDReserve_5ae655a`, a 908,660-byte static stripped ARMv7 EABI5 executable at SHA-256 `5fb737f79ad54c6754e92fe433359bf1237e6366bd21ee5b15ea827615ad23cd`; it has no dynamic section and includes the reserve and false-sync recovery diagnostics without authored-selector compensation or the solid-magenta overlay probe.  Main, RTL, the source-`1bf06db` RBF and Quartus are untouched.

#### Next Steps:

Exit MediaPlayer so its current helper stops, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_DVDReserve_5ae655a`, restore executable mode if needed, and verify the 908,660-byte size and recorded SHA-256.  Preserve the installed source-`2de0717` Main and source-`1bf06db` RBF.  Restart the DVD and first verify reliable menu entry, the correctly aligned movable selector and Play navigation, then repeat many fast forward and backward chapter skips before allowing chapter one to play continuously for more than sixty seconds.  The helper log must identify a 4,194,304-byte DVD output reserve; acceptance requires fluid chapter changes, intact video and selector rendering, a surviving helper, no audible gap through a comparable temporary optical stall and continued A/V synchronization.  Capture a fresh helper log, screenshot and telemetry for physical acceptance.

#### Files Modified:

- host/arm/Makefile
- host/arm/media_player_helper.c
- host/arm/output_reserve.c
- host/arm/output_reserve.h
- tools/test_output_reserve.c

#### Status:

- [x] Built
- [ ] Passed

---

## 863 COMMIT Unreleased 0318f70 2026-09-01T00:25:23-07:00

#### Coming From:

Unreleased 1bf06db

#### Purpose:

Remove the obsolete authored-selector compensation and make DVD chapter AC-3 recovery reject false sample-rate candidates without terminating playback.

#### Outcome:

Source `0318f70` removes the obsolete authored-selector compensation, so the production helper emits one configuration, exactly 86,400 authored plane bytes in 22 bounded records and one commit; a regression that invokes the production emitter reconstructs the byte-identical plane and rejects every extra record.  The same source distinguishes a clean unsupported AC-3 stream, which remains fatal, from a mismatched-rate sync candidate encountered after bytewise recovery has begun, which advances one byte and continues under the existing resynchronization limit; it also makes the shared recovery path safe when passthrough audio has no liba52 decoder.  The focused rate-policy, production-overlay, random-access, fragmented-subpicture and immediate/delayed-menu-hop regressions pass, as do strict native and optional solid-overlay-probe helper builds.  The Raspberry Pi GNU 10.2.1 toolchain builds exact source `0318f70` into `host/build/MediaPlayer_Helper_AC3Selector_0318f70`, a 908,660-byte static stripped ARMv7 EABI5 executable at SHA-256 `7d8778890c0cc3bf3444693736f3a9e9d22e615f78ffe0c0765c5fd4fb3257dc`; it has no dynamic section, contains the false-sync recovery and clean unsupported-rate diagnostics, and omits both authored-compensation and solid-magenta-probe markers.  Main and the source-`1bf06db` RBF are unchanged.

#### Next Steps:

Exit MediaPlayer so its current helper stops, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_AC3Selector_0318f70`, restore executable mode if needed, and verify the 908,660-byte size and recorded SHA-256.  Preserve the installed source-`2de0717` Main and source-`1bf06db` RBF.  Restart the DVD, enter the menu and move the selector through several choices; acceptance requires one correctly aligned movable selector without the former duplicate or offset copy.  Then repeatedly cross the reproducible chapter-nine-to-chapter-ten boundary and exercise mixed forward/backward skips; acceptance requires moving playback, a surviving helper, no fatal unsupported-44.1-kHz exit, and, when the damaged boundary recurs, a false-sync rejection followed by the existing AC-3-resynchronized diagnostic.  Capture a fresh helper log, screenshot and telemetry for physical acceptance.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/Makefile
- host/arm/ac3_resync.h
- tools/test_ac3_resync.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 862 COMMIT Unreleased 1bf06db 2026-08-31T23:11:01-07:00

#### Coming From:

Unreleased bb3110d

#### Purpose:

Correct the two FPGA transport boundaries currently masked by the Main stream-hop delay and helper overlay-byte compensation.

#### Outcome:

The user's repeated chapter-forward and chapter-backward run captures ten software-successful DVD stream hops with complete random-access boundaries followed by the same hardware failure previously seen on intermittent menu reloads: the checksum-valid schema-21 fallback accepts only 13,635 bytes, records zero sequence or picture progress, sees a P-picture before any frame-rate code and latches only phase-one probe error `0x0002`.  Source `1bf06db` now asynchronously clears the 32 KiB mixed-width input FIFO on every download rising edge, stretches that clear in the write domain, relies on the primitive's independent read and write release synchronizers, withdraws both legacy wait and burst readiness until an additional 32 write-clock settle cycles complete, and preserves the rolling accepted-word counter and digest used by Main's verifier.  The same source replaces the physical one-byte-per-maximum-record overlay boundary and its helper compensation requirement with a timing-isolated two-entry retained extractor queue that keeps byte and boundary fields stable, absorbs the transition into DDR backpressure and has no combinational engine-ready path.  Six focused and retained Icarus regressions pass, including stale old-session bytes followed by an exact first new word, a nonuniform 86,400-byte plane across 22 records under sustained DDR stalls, metadata retention, engine write/read and blend, DDR arbitration and schema-21 triggering.  A clean exact-commit Quartus Prime 17.0.2 seed-20 build completes synthesis, fitting, assembly and timing with zero errors; global setup, hold, recovery, removal and minimum-pulse-width slacks are positive at 0.129, 0.245, 3.481, 0.437 and 0.925 nanoseconds, while the dedicated 60 MHz decoder and 54 MHz video checks have 0.831 and 1.753 nanoseconds of setup slack and zero violated paths.  The fit uses 34,752 ALMs, 54,655 registers, 4,187,011 block-memory bits and 70 DSP blocks.  Local `output_files/MediaPlayer_20260831_1bf06db.rbf` is byte-identical to the build-PC result at 4,458,716 bytes and SHA-256 `b315309c8fb72b20d5cf1e690ba36808804bd1549a142b98ea73d121554ba63c`; Main and helper source and binaries remain unchanged.

#### Next Steps:

The user should preserve the installed source-`2de0717` Main and source-`bb3110d` compensated helper, copy only `output_files/MediaPlayer_20260831_1bf06db.rbf` to the MiSTer as a new rollback-safe file, verify its size and SHA-256, and load it.  Restart the disc and exercise at least twenty mixed boundaries using repeated `M`, forward and backward chapter skips, Play through the authored still and return to menu; acceptance requires every completed hop to show moving video without the 800-by-600 `0x0002` diagnostic raster, the authored selector to remain visible and movable, and schema 21 to show the ordinary first 86,400-byte overlay candidate accepted and published before the still-installed oversized compensation candidate is safely rejected.  After that physical proof, remove the no-longer-needed helper compensation in a separate helper-only cleanup and repeat one menu-selector check without changing this RBF or Main.

#### Files Modified:

- MediaPlayer.sv
- rtl/mpeg2_stream_fifo.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/test_mpeg2_stream_fifo.sv
- tools/test_dvd_overlay_integrated.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 861 COMMIT Unreleased bb3110d 2026-08-31T23:00:20-07:00

#### Coming From:

Unreleased bb3110d

#### Purpose:

Accept the post-still pending-activation helper on physical hardware for DVD Play entering continuous title playback.

#### Outcome:

The user reports that Play now works, and the physical source-`bb3110d` capture satisfies the targeted delayed-activation boundary.  Main submits activation command `0x08` at 13.526823 seconds; the helper retains it across 89 menu payloads and the authored ten-second still, reports `remains pending after finite still`, then observes menu leave and announces `stream hop before payload` without sending any menu-continuation acknowledgment.  Main receives menu leave and the navigation-ready event at 23.684043 and 23.684121 seconds, the existing barrier releases with zero discarded pending bytes, and the helper retains a complete random-access group at sequence, intra and following-reference offsets 0, 296 and 71,632.  The session then sustains title playback for more than 114 scheduler seconds, reaches 83,205,235 title-video bytes and 117,486,034 total submitted bytes, and records no fatal transport, helper or barrier event.  The 815,401-byte screenshot at SHA-256 `53715e69484d7a711ed106004048dc4b0ed14e01e3c2c48dd963317cfc0ddffb` visibly shows the moving feature-title credit rather than the resident menu; the matching 3,509,286-byte log has SHA-256 `c542e36ed059031e62ce1603e581b684c25a144b8635917de15071a7138191d7`, and the 805-byte checksum-valid schema-21 snapshot at SHA-256 `431dc8517d5fe3738f1e980ad21f1014575dacc9a8e31f2c3f29d9398858f853` reports zero decoder error flags.  This physically accepts source `bb3110d` for the Play transition with the source-`2de0717` Main, source-`f5f650f` RBF and authored selector compensation unchanged.

#### Next Steps:

Preserve `host/build/MediaPlayer_Helper_PostStillPending_bb3110d`, the installed source-`2de0717` Main and source-`f5f650f` RBF as the accepted DVD menu and title-activation baseline.  The user may continue exploratory menu, chapter, return-to-menu and title-playback testing; collect a fresh screenshot, telemetry and helper log for any reproducible failure, but do not change the accepted three-file combination merely for the expected authored ten-second Play still.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 860 COMMIT Unreleased bb3110d 2026-08-31T22:52:26-07:00

#### Coming From:

Unreleased 79da6c3

#### Purpose:

Defer pending DVD activation classification beyond an ambiguous finite-still skip until libdvdnav exposes the actual post-still boundary.

#### Outcome:

Source `79da6c3` changes a title-zero result immediately after `dvdnav_still_skip` from a completed menu continuation to `MEDIA_SOURCE_DVD_MENU_PENDING`, leaves the source boundary and Main request intact, and makes the helper resume event consumption without sending `MENU_CONTINUE`; an immediate nonzero title still enters the existing hop, while a later observed menu leave uses the saved-start-code path to enter the ready/go barrier before title payload processing.  Source `bb3110d` completes the validation boundary by making the real-image harness recognize that helper-side post-still hop and require the pending-payload marker, post-still-pending marker, no continuation acknowledgment, menu leave, second ready event, post-hop random access and title bytes.  The strict authored-compensation native helper builds with `-Werror` after demoting only the pinned DVD headers' ignored-attribute warning, its complete capability smoke test passes, and the focused delayed-transition, random-access and fragmented-subpicture regressions pass.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds exact source `bb3110d` into `host/build/MediaPlayer_Helper_PostStillPending_bb3110d`, a 908,660-byte static stripped ARMv7 EABI5 executable at SHA-256 `f1f40c7e9a36b5182016038bcbbcaa03a3db91ac020e53a544f54020418f67ad`; it has no dynamic section, contains the new post-still-pending and authored-compensation markers, omits the solid-magenta probe marker and returns the complete protocol-one capability string.  Main and the source-`f5f650f` RBF are unchanged.

#### Next Steps:

The user should exit MediaPlayer so its helper process stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_PostStillPending_bb3110d`, restore executable mode if needed and verify the 908,660-byte size and recorded SHA-256.  Preserve the installed source-`2de0717` Main and source-`f5f650f` RBF, restart the disc, enter the root menu, leave Play selected and press Space once, then wait through the authored ten-second still.  Physical acceptance requires `pending reached still`, `remains pending after finite still`, menu leave, `stream hop before payload`, one clean ready/go barrier, a new random-access group and continuously moving title video; returning to the menu must retain the authored selector.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 859 COMMIT Unreleased 33d8151 2026-08-31T22:39:27-07:00

#### Coming From:

Unreleased 33d8151

#### Purpose:

Capture the physical Play result for the pending-payload helper and isolate the remaining delayed menu-to-title classification failure.

#### Outcome:

The user's physical source-`33d8151` run improves the visible result from a permanently resident menu frame to the authored ten-second pause followed by approximately one second of motion, but title playback then freezes permanently.  The unique pending-payload diagnostics prove that the intended 908,660-byte helper receives activation command `0x08`, keeps the request pending across 89 menu payloads and reaches the ten-second finite still.  At expiry, `dvdnav_still_skip` immediately samples `dvdnav_current_title_info` while it still reports title zero, so the helper sends `MENU_CONTINUE` with reason `finite-still-menu` and Main preserves the resident decoder session; only immediately afterward does libdvdnav report menu leave and subpicture stream 128.  Because that acknowledgment clears `activation_pending`, the observed menu leave cannot enter the existing ready/go barrier or rearm random access, yet Main and the helper remain alive and submit more than 257 megabytes of title data through 102 seconds.  The 724,552-byte screenshot at SHA-256 `ca0a97c23a78142ebbf2407287a0605468e427268fff4db0b28cd4988435cefa` shows the later frozen authored frame, the matching 1,937,579-byte log has SHA-256 `cbfa731889b1dfde1f2f109bef1ae7b4b4311ea4632f88deba80c865febd81c3`, and the 844-byte checksum-valid schema-21 snapshot has SHA-256 `ec4ceaaf5deee8fff354d187248264d8e96a4388ba42c1ce032b7c9060ac9697`.  This rejects source `33d8151` on hardware and proves that title zero immediately after a finite-still skip is ambiguous rather than proof of a menu continuation; Main, authored-selector compensation and the source-`f5f650f` RBF remain cleared.

#### Next Steps:

Keep Main, RTL, QSF, the source-`f5f650f` RBF and authored-selector compensation frozen.  After user approval, make a bounded helper-only correction that treats title zero immediately after a pending activation's finite-still skip as still pending, then resolves the request only after libdvdnav exposes the post-still boundary: an observed menu leave enters the existing ready/go barrier before the first title start code, while an indefinite still or another definitive menu state acknowledges continuation.  Strengthen the focused and real-image delayed-activation regressions to reproduce title zero at skip followed by menu leave, require no premature `MENU_CONTINUE`, one delayed stream hop, a second ready event, post-hop random access and title bytes, rebuild only the helper locally and repeat Play.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 858 COMMIT Unreleased 33d8151 2026-08-31T22:23:13-07:00

#### Coming From:

Unreleased 85cda13

#### Purpose:

Keep a pending DVD activation alive across intermediate menu payloads until libdvdnav exposes a definitive continuation or title boundary.

#### Outcome:

Source `33d8151` removes source `85cda13`'s invalid menu-payload continuation acknowledgment.  While activation is pending, ordinary menu payloads now continue through the existing output path without clearing Main's navigation request; the helper counts them, logs the first payload and logs the accumulated count when a still is reached.  Only an indefinite still, a finite-still completion or an observed menu leave now resolves the request, preserving the existing post-still title classification, ready/go barrier and saved-start-code path.  The strict compensated native helper builds with `-Werror`, its capability smoke test passes, and the focused delayed-transition, random-access and fragmented-subpicture regressions pass; the real-image harness's delayed-activation gate additionally requires a nonzero pending-payload count before the title hop, a second ready event, post-hop random access and title bytes.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds `host/build/MediaPlayer_Helper_PendingPayload_33d8151`, a 908,660-byte static stripped ARMv7 EABI5 executable at SHA-256 `915bb2c064f459a9cd4a1d53321db5c8ebe442a103a3ce385da550583661bfa1` with authored-selector compensation and no dynamic section.  Main and the source-`f5f650f` RBF are unchanged.

#### Next Steps:

The user should exit MediaPlayer so its helper process stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_PendingPayload_33d8151`, restore executable mode if needed and verify the 908,660-byte size and recorded SHA-256.  Preserve the installed Main and source-`f5f650f` RBF, restart the disc, enter the root menu, leave Play selected and press Space once, then wait through the authored ten-second still.  Physical acceptance requires pending-payload and reached-still diagnostics, menu leave, delayed stream hop, one clean ready/go barrier and moving title video; returning to the menu must retain the authored selector.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 857 COMMIT Unreleased 85cda13 2026-08-31T22:20:32-07:00

#### Coming From:

Unreleased 85cda13

#### Purpose:

Capture the physical Play result for the delayed-activation helper and identify why the title still does not enter its decoder barrier.

#### Outcome:

The user's physical test runs the source-`85cda13` path, proven by its unique `menu pending activate`, `DVD menu activation deferred` and authored-compensation diagnostics, but the video still freezes on the resident root-menu frame.  Main submits activation command `0x08` at 20.828591 seconds and the helper correctly leaves that request pending at first; an intermediate menu payload then causes the helper to send `MENU_CONTINUE` with reason `menu-payload`, which Main accepts at 21.000909 seconds, approximately 172 milliseconds after the command.  Only after that premature acknowledgment does libdvdnav announce the authored ten-second finite still.  At its expiry the helper reports menu leave and title subpicture stream 128, but `activation_pending` has already been cleared, so there is no delayed-activation hop, ready event, random-access reset or navigation-barrier release.  Main and the helper remain alive and continue submitting the concatenated title stream beyond 207 megabytes, reproducing entry 855 rather than a pause or disc stall.  The 655,681-byte screenshot at SHA-256 `4da4100a79b06e21e8867b61ac2f080f39b917fceb66a49e582524fb97d5ddf0` shows the frozen root-menu frame; its diagnostic raster corresponds to the 844-byte checksum-valid schema-21 snapshot at SHA-256 `5bd2e87048013102194aa7e02f6280ca1e0bf4c21d67da0e7edaaea7e372d30e`, and the matching 1,848,282-byte log has SHA-256 `37ddc328ec24edc5341ee82dfc035ac3be4f9dd11f2a7131cbf2bc1975b74515`.  Source `85cda13` is rejected on hardware because a payload between activation and the still is not proof of a menu continuation.

#### Next Steps:

Keep Main, RTL, QSF, the source-`f5f650f` RBF and authored-selector compensation frozen.  After user approval, make a bounded helper-only correction that retains `activation_pending` across ordinary menu payloads and resolves it only at a definitive boundary: an indefinite still acknowledges menu continuation, a finite still classifies title versus menu after `dvdnav_still_skip`, and an observed menu leave enters the existing ready/go barrier before title payload processing.  Remove the invalid menu-payload acknowledgment, strengthen regression coverage so payload-before-finite-still must still produce a delayed hop and second ready event, rebuild only the helper locally and repeat Play while waiting through the authored ten seconds.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 856 COMMIT Unreleased 85cda13 2026-08-31T22:00:52-07:00

#### Coming From:

Unreleased 330d103

#### Purpose:

Make authored Play activation enter the existing decoder reset barrier when its menu-to-title transition is delayed by a finite still.

#### Outcome:

Source `85cda13` introduces an explicit pending result for an activation that still reports menu title zero, discards its stale source boundary but defers the continuation acknowledgment so Main's existing navigation request remains pending through an authored finite still.  At still expiry the source refreshes libdvdnav title state: a title exit invalidates the boundary and enters the existing ready/go decoder barrier, while a transition that remains in a menu acknowledges continuation and preserves the resident frame.  Indefinite stills acknowledge immediately, and a menu payload that appears without a still is acknowledged before processing; an immediate title payload is retained across the barrier by saving its start code.  The strict native helper builds with `-Werror`, the focused transition test proves pending, finite-still hop and finite-still continuation boundaries, the random-access and fragmented-subpicture regressions pass, and the real-image harness now offers a delayed-activation gate requiring menu leave, a second ready event, a post-activation random-access group and subsequent title bytes.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds a 908,660-byte static stripped ARMv7 helper at `host/build/MediaPlayer_Helper_DelayedPlay_85cda13`, SHA-256 `7b4af55c0de6c88a8be110693476c07e4bebf41fd4cd19bdd88cc5e6471392f2`, with authored-selector compensation and no dynamic section.  Main and the source-`f5f650f` RBF are unchanged.

#### Next Steps:

The user should exit MediaPlayer so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_DelayedPlay_85cda13`, restore executable mode if needed and verify the 908,660-byte size and recorded SHA-256.  Preserve the installed source-`2de0717` Main and source-`f5f650f` RBF, restart the disc, enter the root menu, leave Play selected and press Space once; wait through the authored ten-second still.  Physical acceptance requires a pending activation followed by menu leave, one clean ready/go barrier and moving title video, then a return to the menu with the authored selector still visible and movable.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/media_source.c
- host/arm/media_source.h
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 855 COMMIT Unreleased 330d103 2026-08-31T21:55:35-07:00

#### Coming From:

Unreleased 330d103

#### Purpose:

Diagnose why activating Play with Spacebar leaves the DVD menu frame frozen instead of starting the title.

#### Outcome:

The user's fresh physical run selects Play and presses Spacebar, which Main correctly remaps to menu activation command `0x08` at diagnostic time 11.117172 seconds with playback unpaused.  The helper successfully calls `dvdnav_button_activate` on button one, but because `dvdnav_current_title_info` still reports menu title zero immediately after the call, it classifies the action as an overlay-only menu continuation; Main receives that acknowledgment at 11.147338 seconds and deliberately preserves the resident menu frame.  Libdvdnav then reports an authored ten-second finite still.  At 21.157916 seconds the helper completes the still, reports menu leave, switches to subpicture stream 128, resynchronizes AC-3 and begins producing the movie, but it never sends a ready event, enters a navigation barrier or rearms the random-access filter at this delayed menu-to-title boundary.  Main consequently keeps the original decoder session while continuing to read and submit title bytes; the log reaches more than 115 MB submitted at 56.624699 seconds, proving this is neither a paused player, stopped disc nor helper starvation.  The 729,689-byte screenshot at SHA-256 `13a938c828b3d622d1853d76324f712dfa5d7664309ffeecc51ca630ed576ec0` still shows the resident menu frame after the authored still has expired and the selector has been cleared.  The matching 1,137,918-byte helper/Main log has SHA-256 `a0cf8f1ca89b3d4c6a5e2b4f18515ec987484dcc76ee30db42474b5aa7916fcf`; its timeline localizes the fault to delayed activation classification.  The 844-byte checksum-valid schema-21 snapshot at SHA-256 `26bb7bf3ecc1411b7457995883dbde7e52ac25d008d0b03bba035856768e3e7b` retains the accepted authored-selector plane evidence and introduces no separate selector regression.  Static source inspection confirms that `media_source_dvd_still_skip` clears the still but does not report a menu-to-title hop, so `wait_dvd_still` resumes inside the old session instead of invoking Main's already proven ready/go reset barrier.  Main, the authored selector compensation and the source-`f5f650f` RBF are not implicated.

#### Next Steps:

Obtain approval for a helper-only delayed-transition correction: after a finite still is skipped, refresh libdvdnav title state and classify a menu-to-title change as `MEDIA_SOURCE_DVD_STREAM_HOP`, invalidate the current source boundary and make `wait_dvd_still` enter the existing ready/go navigation barrier before any title bytes are emitted.  Add focused regressions that distinguish a finite still remaining inside a menu from a finite still exiting to a title, extend the real-image navigation test to require the delayed second ready event and post-barrier title video, build only the helper locally with authored selector compensation, and preserve Main and the RBF.  Physical acceptance requires Play to retain its authored ten-second still, then start moving title video after one clean barrier with no selector regression.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 854 COMMIT Unreleased 330d103 2026-08-31T21:50:21-07:00

#### Coming From:

Unreleased 330d103

#### Purpose:

Accept the helper-only authored DVD selector compensation on physical hardware.

#### Outcome:

The user reports that the restored selector looks correct, and the direct capture confirms a clean authored crown-shaped highlight over the menu rather than the diagnostic magenta rectangle or prior speckles.  The 776,392-byte 1,920-by-1,080 screenshot at SHA-256 `603c7e3755e48eed0dc7cab5cb7f507c914c6b84343be623867592d784a6646b` preserves the menu background and shows the authored green-gold selector at Special Features.  The 2,693,429-byte helper/Main log at SHA-256 `931923f98e7bfa329fadaf6f41c204167da6ac49fa62d544e6b68b7271943994` contains the source-`330d103` authored-compensation marker, authored palette `00000000/316a5988/316a59bb/316a59ff`, nontransparent sparse-plane histograms and successful movement through all four buttons, including eleven Right transitions and one Left transition.  The 844-byte schema-21 snapshot at SHA-256 `87a953b3ed49e1711cb0773ea531540a8b85f9d2a9922c10a5e353ab9c0a8ea0` passes all prefix, row, index, parity and XOR checks with checksum `786cc6b3`; it reports two configs, 44 data records, two commits, one expected rejected standard candidate, one accepted compensated candidate, one plane publication and exactly 86,400 received bytes in the accepted candidate.  The video domain records 88,430 highlighted samples, 8,370 nonzero-alpha samples and zero opaque-magenta samples, independently distinguishing the sparse authored artwork from the removed probe.  This physically accepts source `330d103` for the menu-selector goal with the source-`2de0717` Main and source-`f5f650f` RBF unchanged.

#### Next Steps:

Preserve `host/build/MediaPlayer_Helper_AuthoredSelector_330d103` together with the installed source-`2de0717` Main and source-`f5f650f` RBF as the accepted DVD menu baseline.  Treat the selector restoration as complete; any later work should begin from this exact three-file combination and must not reopen the RBF or replace the authored compensation without new physical evidence.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 853 COMMIT Unreleased 330d103 2026-08-31T21:38:36-07:00

#### Coming From:

Unreleased 413ace2

#### Purpose:

Replace the physically accepted solid-purple diagnostic selector with the correctly shaped authored DVD selector while preserving the proven userspace-only transfer compensation.

#### Outcome:

The user's refreshed physical capture proves source `413ace2` closes the compensated-candidate byte deficit.  The 857-byte schema-21 snapshot at SHA-256 `5b1b15f4bff4195cd7b487ff0808214475408180ca16267f5242fd4f7dd24729` passes every prefix, row, index, parity and XOR check with checksum `5d8d8a25`; it reports two configs, 44 data records, two commits, one rejected commit, one accepted commit and one plane publication.  The first candidate receives 86,379 bytes, while the second receives exactly 86,400 of its submitted 86,422 bytes and publishes successfully.  The 11,001,450-byte helper/Main log at SHA-256 `eaf58071e5a06a70ad7659fa5f65e51724217578d09c5e7594b2c7e4944a055d` confirms that the helper has already decoded the sparse authored plane at FNV-1a `c23cad52`, but the opt-in probe deliberately replaces both its pixels and palette with solid opaque magenta.  The 1,920-by-1,080 screenshot at SHA-256 `37d9b3e7cc6fa4f38a9d654bdfac9274d5278681bde2da3dfe0ede4c07c25050` contains exactly 21,780 opaque-magenta pixels in one 242-by-90 rectangle from output coordinate 566,894 through 807,983, proving the published plane, palette, compositor and authored moving rectangle.  Source `330d103` preserves the unchanged 86,400-byte authored candidate for the zero-loss case, then packetizes the compensated authored candidate as at most 4,095 source bytes followed by a duplicate of that record's final source byte.  Its 21 full 4,096-byte records and one 406-byte final record submit 86,422 bytes, so the measured one-byte loss at each of the 22 record boundaries discards only duplicates and reconstructs the exact original 86,400-byte plane.  The solid-magenta probe remains independently available, while the new authored-compensation build preserves the DVD plane and palette.  Strict native compilation and the focused subpicture, random-access and menu-hop regressions pass; a direct nonuniform-plane framing regression verifies two configs, two commits, 22 data records per candidate, 86,400 and 86,422 submitted bytes, authored style preservation and byte-identical plane recovery after removing every compensated record's final byte.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds `host/build/MediaPlayer_Helper_AuthoredSelector_330d103`, a 908,660-byte stripped static ARM EABI5 executable at SHA-256 `3f81f1bce3489ad4493e88b2f09e29b068f23ba4aac7980c1adf1fc8bf897481`; it contains the authored-compensation marker, omits the solid-magenta marker and returns the complete protocol-one capability string when executed locally.  Main and the source-`f5f650f` RBF remain frozen.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_AuthoredSelector_330d103`, restore executable mode if needed and verify the installed size and SHA-256.  Preserve the installed source-`2de0717` Main and source-`f5f650f` RBF, restart the DVD, enter the menu and move through every button; physical acceptance requires one accepted commit, one plane publication and a correctly shaped authored selector that follows every directional input.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 852 COMMIT Unreleased 413ace2 2026-08-31T21:22:44-07:00

#### Coming From:

Unreleased 4baf17a

#### Purpose:

Close the physically measured final one-byte selector deficit with a helper-only compensated-candidate adjustment.

#### Outcome:

The user approves preserving the proven source-`f5f650f` RBF, source-`2de0717` pre-drain Main and unchanged first 86,400-byte probe candidate while increasing only the second probe candidate from 86,421 to 86,422 all-`0x55` bytes.  Source `413ace2` makes that one-byte correction and updates its diagnostic marker; the compensated candidate still uses 21 full 4,096-byte records, with only the final payload increasing from 405 to 406 bytes.  Strict native compilation and the focused fragmented-subpicture, selected-histogram, scheduled-stop, random-access and menu-hop regressions pass.  A direct framing harness verifies exactly two candidates of 86,400 and 86,422 bytes, 22 data records each, maximum payload 4,096, and final payloads of 384 and 406.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds `host/build/MediaPlayer_Helper_DualCandidate22_413ace2`, a 908,660-byte stripped static ARM EABI5 executable at SHA-256 `beb698b86b46e4a937871637ad6f0b4e5878ae0c2c3eff7dde1c0afabd75b8f4`; it contains the solid-magenta probe and `extra_bytes=22` compensation markers and returns the complete protocol-one capability string when executed locally.  The correction remains restricted to the opt-in purple-probe helper and does not modify normal authored overlays, navigation, Main, the RBF or protocol limits.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_DualCandidate22_413ace2`, restore executable mode if needed and verify the installed size and SHA-256.  Preserve the installed source-`2de0717` Main and source-`f5f650f` RBF, restart the DVD, enter the menu and move through every button; physical acceptance requires the second candidate to reach exactly 86,400 bytes and 10,800 DDR words, at least one accepted commit, one plane publication and a solid purple selector following directional input.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 851 COMMIT Unreleased 4baf17a 2026-08-31T21:19:44-07:00

#### Coming From:

Unreleased 4baf17a

#### Purpose:

Evaluate the helper-only dual-candidate selector compensation on physical hardware and determine the remaining correction from direct pipeline evidence.

#### Outcome:

The user reports that menu loading is again intermittently incomplete but every subsequent `M` command restores it, an accepted consequence of retaining the pre-drain Main, and that small purple speckles are visible near the moving menu selection.  The 857-byte schema-21 snapshot at SHA-256 `4eb9b426d3535001b114b3779721384c1a9b05cb8a7301d04eb7d6e199444e9e` passes all row, index, parity and XOR checks with checksum `07e2e504` and captures exactly two configs, 44 data records, two commits and two styles from the first dual-candidate pair.  Main submits the intended complete 86,400-byte and 86,421-byte all-`0x55` candidates, but the engine receives 86,379 bytes from the standard candidate and 86,399 bytes from the compensated candidate: the first loses 21 bytes and the second loses 22, for 43 missing bytes across the pair.  Both commits are rejected, zero commits are accepted and no plane is published; the second candidate nevertheless reaches 10,799 complete DDR words plus seven byte lanes, exactly one byte short of the required 86,400.  The correct visible-menu style, rectangle 135,397 through 208,436 and opaque-magenta entry one are published while the display bank still contains uninitialized data, producing 73,418 magenta video samples and exactly 926 opaque-magenta screenshot pixels as sparse speckles rather than a valid selector plane.  The matching 4,359,882-byte Main/helper log at SHA-256 `f815529eb5cdd18c02d4d4cabaad0f83c15061aeb3f7424a375f0bdab55282c9` repeatedly proves both candidate sizes, valid framing and directional style movement, and the 1,920-by-1,080 screenshot at SHA-256 `a9d58cdf6cd935522906ef08c21ab0bff12836557f1eb655cdc95dac2a1e03df` visually confirms the localized speckles.  The loaded RBF has already physically rendered a complete purple bar, so this result does not reopen its compositor or scaling path; the dual-candidate strategy reaches the correct software boundary and misses acceptance by exactly one compensated byte.

#### Next Steps:

Preserve the source-`f5f650f` RBF and source-`2de0717` pre-drain Main, and obtain approval for a one-byte helper-only correction that changes the compensated probe candidate from 86,421 to 86,422 bytes and its final payload from 405 to 406 while retaining the standard first candidate unchanged.  Rebuild locally with the Raspberry Pi ARM toolchain and require physical telemetry to show the second candidate receive exactly 86,400 bytes, complete 10,800 DDR words, accept at least one commit, publish a plane and render a solid moving purple selector instead of speckles.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 850 COMMIT Unreleased 4baf17a 2026-08-31T21:09:16-07:00

#### Coming From:

Unreleased 2de0717

#### Purpose:

Restore a visible moving purple selector with a helper-only dual-candidate plane that tolerates both physically observed overlay-transfer outcomes.

#### Outcome:

The user approves a software-only response to entry 849's exact recurring 21-byte shortfall while keeping the source-`f5f650f` RBF and source-`2de0717` pre-drain Main frozen.  Source `4baf17a` retains the probe helper's unchanged first config, 22-record, 86,400-byte all-`0x55` plane and commit, then immediately emits a second config and candidate containing 86,421 all-`0x55` bytes in the same 21 full 4,096-byte records plus a 405-byte final record before committing again.  A zero-loss transfer can publish the first candidate and safely reject the later oversized one without clearing the displayed plane, while the recurring loss of one byte from each full record leaves exactly 86,400 bytes in the second candidate for acceptance and publication.  This compensation is restricted to the opt-in solid-purple probe build and does not alter authored overlay pixels, DVD navigation, Main, the RBF, transport framing limits or normal helper behavior.  Strict native compilation and the focused fragmented-subpicture, selected-histogram, scheduled-stop, random-access and menu-hop regressions pass; a direct framing harness verifies exactly two configs, two commits, 22 data records per candidate, respective totals of 86,400 and 86,421 bytes, maximum payload 4,096, and final payloads 384 and 405.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds `host/build/MediaPlayer_Helper_DualCandidate_4baf17a`, a 908,660-byte stripped static ARM EABI5 executable at SHA-256 `b6f642c0afd3aebda67b3f1c00aa7ba66057790b9305ed210d656cbdd65ae1cc`; it contains both the purple-probe and dual-candidate compensation markers and returns the complete protocol-one capability string when executed locally.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_DualCandidate_4baf17a`, restore executable mode if needed and verify the installed size and SHA-256.  Preserve the installed source-`2de0717` Main and source-`f5f650f` RBF, restart the DVD, enter the menu and move through every button; physical acceptance requires at least one accepted overlay commit, a plane publication and a solid purple selector that follows directional input.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 849 COMMIT Unreleased 2de0717 2026-08-31T21:06:18-07:00

#### Coming From:

Unreleased 2de0717

#### Purpose:

Evaluate the physically installed source-`2de0717` selector pair and localize the still-invisible purple overlay without changing the frozen RBF.

#### Outcome:

The fresh physical capture now proves the intended userspace combination is active: the helper repeatedly identifies `probe=solid-index1-magenta`, Main reports complete ordered 22-record, 86,400-byte all-`0x55` submissions with FNV-1a `f8555d45`, and the former 500-millisecond stream-hop drain marker is absent.  The 831-byte schema-21 snapshot at SHA-256 `2efc445ca659f6612aab8ca10b3a89baf78abfbf123a5c0726484b2063bb3450` passes all 64 row, index, parity and XOR checks with checksum `fe4049a3`, but the first commit still receives only 86,379 plane bytes: exactly one byte is absent from each of the 21 full 4,096-byte data records.  The engine completes 10,797 DDR words plus three byte lanes, sets its protocol-error flag, counts one rejected and zero accepted commits, publishes no plane, and therefore produces zero nonzero-alpha or opaque-magenta samples despite accepting the correct visible-menu style, rectangle 135,397 through 208,436 and opaque-magenta highlight entry one.  The matching 2,202,613-byte Main/helper log at SHA-256 `eae3f6296d082ef2fa4e45476d8b9f3ddcae48b3edf4b9d3d66c615122a068c2` records five complete overlay submissions and successful directional movement through the authored rectangles, while the 1,920-by-1,080 screenshot at SHA-256 `8855562bf166d734ebf335d8a981d94ef85f3492a492f49c07470e1382ea5068` shows the stable menu with no exact opaque-magenta pixels.  This rejects deployment mismatch and the Main drain as causes of the selector failure and establishes the recurring physical 21-byte loss as the current software compatibility boundary.

#### Next Steps:

Keep the source-`f5f650f` RBF and source-`2de0717` pre-drain Main frozen, and obtain approval for a helper-only dual-candidate probe frame: first emit the unchanged 86,400-byte plane so the previously observed zero-loss path can accept it, then emit an immediately following 86,421-byte all-`0x55` candidate using the same 21 full 4,096-byte records and a 405-byte final record so the recurring one-byte-per-full-record physical loss leaves exactly 86,400 accepted bytes.  Because a rejected later commit does not replace an already published plane, the two candidates cover both observed zero-loss and 21-byte-loss behavior without an RBF or Main change; build and physical validation must require at least one accepted commit, a plane publication and a visibly moving purple selector.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
