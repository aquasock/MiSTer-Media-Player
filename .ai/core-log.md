## 129 COMMIT Unreleased ??? 2026-09-14T22:03:44-07:00

#### Coming From:

Unreleased 36085f6

#### Purpose:

Disable video-only menu settings while native audio playback is active.

#### Outcome:

The user requests grayed-out Color matrix, Refresh rate and Subtitles entries during audio playback. Use stock Main's D0 disable prefix with menu-mask bit zero driven by music_play_request. Apply the same prefix to generated subtitle controls so flattened menus and existing subtitle pages also remain disabled. Keep the user settings intact and automatically restore access when audio playback ends or a video is loaded; Aspect ratio remains selectable.

#### Next Steps:

Update the menu generator and configuration, verify generated output and full-core elaboration, and include the correction with the pending audio aspect fix in the next build cycle.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 128 COMMIT Unreleased 36085f6 2026-09-14T22:01:28-07:00

#### Coming From:

Unreleased d3c416a

#### Purpose:

Qualify and package the completed CD navigation and FLAC seeking builds.

#### Outcome:

All three HIGH-packing 36085f6 builds compile successfully. Independent four-corner setup, hold, recovery, removal and pulse-width checks pass for seeds 61 and 87; seed 52 fails HDMI setup at -0.083 ns. Recommend seed 87 with worst setup +0.322 ns, hold +0.110 ns, recovery +3.369 ns, removal +0.167 ns and pulse width +0.925 ns. It uses 37911 placed ALMs (33879 estimated), 48480 registers, 516 M10Ks, 68 DSPs and four PLLs, leaving 3999 physical ALMs, 37 M10Ks, 44 DSPs and two PLLs. Seed 61 uses 38072 placed ALMs and has setup +0.319 ns and hold +0.057 ns. All seeds pass 297 configuration CDC register checks and ten reset-release paths. Hash-verified RBF packages and resource/timing JSON are in results/hardware-test-36085f6. Recommended seed 87 SHA-256 is 820bdd7fecf7c4d3dab232b93929f9fc5c87b56f28a889d601a327ae40880757. Hardware acceptance remains pending; no RBF was deployed. These builds do not include the later d3c416a audio graphics aspect correction, which remains ready for the next build cycle.

#### Next Steps:

Have the user test seed 87 with completed CD FLAC N/P navigation, ordinary FLAC timed seeks, paused landing, EOF, MPG/FLAC replacement and the four MPG regression files; include d3c416a in the next build cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 127 COMMIT Unreleased d3c416a 2026-09-14T21:47:29-07:00

#### Coming From:

Unreleased 36085f6

#### Purpose:

Make the audio waveform and player UI respect the selected aspect ratio.

#### Outcome:

Corrected the post-scaler audio renderers to measure and clip against the scaler's selected picture rectangle rather than the entire HDMI raster. Coherent bounds and music enable cross to HDMI through audited mailboxes and commit at vertical sync. A separate layout enable follows the existing waveform pipeline; full HDMI RGB/sync/DE stay aligned, integer font scaling is retained, and movie layout is unchanged. Complete viewport/waveform/UI simulation passes both 4:3 and 16:9 at 480p, 720p and 1080p, including geometry, border clipping, local UI pixels and waveform presence. All three movie frames compare pixel-exactly with the previous renderer layout. Existing waveform equivalence, full overlay pixel oracle, lifetime/control/divider tests and Quartus full-core Analysis and Elaboration pass. Previews and evidence are under results/audio-aspect. Source is ready for the next build cycle; the existing 36085f6 seed builds continue unchanged and do not contain this correction. Full fit/timing and hardware acceptance remain pending.

#### Next Steps:

Include this correction in the next RBF build cycle and verify live 4:3/16:9 changes during FLAC playback, OSD, pause and subsequent MPG playback on hardware; inspect timing and resources before packaging.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_audio_viewport.sv
- rtl/media_overlay_compositor.sv
- rtl/media_player_overlay.sv
- rtl/media_waveform_visualizer.sv
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_media_audio_viewport.sv
- tools/test_media_player_overlay.sv
- tools/test_media_ui_lifetime.sv
- tools/test_media_waveform_visualizer.sv
- tools/verify_audio_viewport.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 126 COMMIT Unreleased 36085f6 2026-09-14T21:24:58-07:00

#### Coming From:

Unreleased d24abc0

#### Purpose:

Add embedded CD track navigation and video-style keyboard seeking to native FLAC playback.

#### Outcome:

Implemented optional CD CUESHEET INDEX 01 and SEEKTABLE parsing into bounded block-RAM tables (99 tracks and 512 seek points), N/P track selection, and Left/Right 10-second, Ctrl 30-second and Ctrl+Alt five-minute jumps for both albums and ordinary FLAC. Cached STREAMINFO and preceding frame offsets drive the existing drained session restart; CRC-admitted PCM preroll is discarded to the exact sample target without resampling. Pause survives navigation, progress stays album-relative, new media clears pending state, and seek configuration is acknowledged across clocks before reader start. Missing seek points fall back to the first audio frame; unknown total samples disable navigation/seeking. The active abcde rip in /run/media/vash/GIT/test1 has 17 tracks; an encoded three-second excerpt previously matched all 132300 original stereo pairs. Reproducible simulation now passes 27 album/navigation/landing cases, 63 DDR corpus/cancellation cases, 73 stream-decoder cases, native audio integration and movie direct-seek regression. Full-core Quartus Analysis and Elaboration passes. Evidence is under results/flac-album and adjacent flac-album-*-regression folders. No damaged-file recovery was added. Three HIGH-packing seeds 52/61/87 are the next build batch; full fit/timing and hardware validation remain pending.

#### Next Steps:

Inspect all three build resource and four-corner timing reports, then package the best candidate for user testing of completed CD FLAC tracks, ordinary FLAC seeking, paused landing, EOF and MPG/FLAC replacement. Retain d24abc0 waveform and accepted 6d460d2 punctuation candidates as rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/flac/flac_album_control.sv
- rtl/audio/flac/flac_ddr_decoder.sv
- rtl/audio/flac/flac_pcm_landing.sv
- rtl/audio/flac/flac_stream_decoder.sv
- tools/phase1p_timing.tcl
- tools/test_flac_album_control.sv
- tools/test_flac_ddr.sv
- tools/test_flac_seek_keyboard.sv
- tools/test_flac_stream.sv
- tools/verify_flac_album.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 125 COMMIT Unreleased d24abc0 2026-09-14T21:04:30-07:00

#### Coming From:

Unreleased d24abc0

#### Purpose:

Qualify and package the completed pipelined waveform builds.

#### Outcome:

Reviewed the other agent's interpolation pipeline and HIGH-packing change, then independently inspected the three completed d24abc0 builds. All seeds pass setup, hold, recovery, removal and pulse width at all four corners, plus 279 CDC register checks and ten native reset-release paths. Seed 52 is recommended with 37347 placed ALMs, 46810 registers, 511 M10Ks, 66 DSPs and four PLLs; worst margins are setup +0.574 ns, hold +0.117 ns, recovery +4.185 ns, removal +0.128 ns and pulse width +0.925 ns. Seed 61 uses 37470 ALMs with setup +0.395 ns and hold +0.095 ns; seed 87 uses 37474 with +0.370/+0.114 ns. Hash-verified packages are in results/hardware-test-d24abc0. Recommended seed 52 SHA-256 is d4a4545a56af3f8bdb0cf90b9004d6dbf6ce1d61970f6f1d8d0abb9e350802c6. Hardware acceptance is pending and no RBF was deployed automatically.

#### Next Steps:

Have the user test seed 52 with native FLAC waveforms, pause/mute, EOF, OSD and MPG/FLAC replacement; retain punctuation seed 87 as rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 124 COMMIT Unreleased d24abc0 2026-09-14T20:44:36-07:00

#### Coming From:

Unreleased 2498125

#### Purpose:

Pipeline the waveform interpolation timing path and adopt HIGH packing for subsequent builds.

#### Outcome:

Implemented separate RAM-output, difference and multiply pipeline stages, extending RGB/sync and coordinate latency from seven to nine cycles and matching glow delay. Both RAMs use no_rw_check only because read/write-overlap values are discarded. HIGH register packing is now the tracked QSF default. Full cycle-by-cycle RGB/sync equivalence to 2498125 passes with two-cycle compensation at 480p, 720p and 1080p, alongside existing constant-signal pixel, stereo history, silence, replacement and bypass tests. Standalone Quartus mapping succeeds with 541 estimated ALMs, 908 registers, two M10Ks and four DSPs. Three clean HIGH seeds 52, 61 and 87 of d24abc0 are running; full-core resource and timing results remain pending. Local source commits and results/waveform-timing-equivalence preserve the evidence. The original HIGH seed 87 remains available for functional testing with its -2.053 ns setup violation disclosed.

#### Next Steps:

Finish the three HIGH builds, inspect every timing corner and CDC audit, and package the best timing-qualified waveform candidate. Hardware acceptance remains pending.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- docs/TEST_INSTRUCTIONS.md
- rtl/media_waveform_visualizer.sv
- tools/test_media_waveform_visualizer.sv
- tools/verify_waveform_visualizer.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 123 COMMIT Unreleased 2498125 2026-09-14T20:22:02-07:00

#### Coming From:

Unreleased 2498125

#### Purpose:

Run an additional HIGH-packing visualizer build to reduce placed logic usage.

#### Outcome:

The user requests one more build using resource-reduction settings. Launch source 2498125 with seed 87 and HIGH ALM_REGISTER_PACKING_EFFORT, retaining STANDARD FIT and HIGH PERFORMANCE EFFORT plus the existing area-oriented physical-synthesis settings. This is the packing configuration that previously saved 936 placed ALMs; savings for the new visualizer must be measured. The three standard MEDIUM-packing seeds continue in their isolated archives. The extra run also performs timing and CDC audits, with explicit corner-slack inspection required afterward.

#### Next Steps:

Compare all four builds on actual placed ALMs, RAM/DSP usage and complete timing qualification, and package the best hardware candidate.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 122 COMMIT Unreleased 2498125 2026-09-14T20:19:12-07:00

#### Coming From:

Unreleased 6d460d2

#### Purpose:

Build the native stereo waveform visualizer for hardware validation.

#### Outcome:

The user authorizes the next visualizer hardware cycle. Launch clean source 2498125 with the usual seeds 52, 61 and 87 and standard MEDIUM packing. This includes the accepted punctuation corrections and the HDMI-only post-volume stereo waveform. Standalone waveform mapping and three-resolution pixel simulations already pass, as does the native serializer/tap regression. The build helper runs compilation and timing/CDC audits; explicit corner-slack inspection is required because a zero timing-script exit alone does not guarantee nonnegative slack.

#### Next Steps:

Inspect every timing corner and resource report, package the best passing candidate and test FLAC visualization, pause/mute, EOF and active/paused MPG/FLAC replacement on 10.10.0.33.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 121 COMMIT Unreleased 6d460d2 2026-09-14T20:19:12-07:00

#### Coming From:

Unreleased 6d460d2

#### Purpose:

Record hardware acceptance of the subtitle punctuation candidate.

#### Outcome:

The user reports that the recommended punctuation build passes on the fresh MiSTer at 10.10.0.33 and authorizes proceeding to the visualizer. The accepted candidate is results/hardware-test-6d460d2/seed87/MediaPlayer_20260914.rbf, SHA-256 79f474395e08709b540431ed477ac1feaceed2f3a9222b2c326b5011ee34d362. It becomes the rollback for the waveform cycle.

#### Next Steps:

Preserve the accepted punctuation RBF and build the separately simulated waveform source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 120 COMMIT Unreleased 6d460d2 2026-09-14T20:16:11-07:00

#### Coming From:

Unreleased 2498125

#### Purpose:

Package and report the completed subtitle punctuation builds.

#### Outcome:

All three clean seeds compile. Explicit four-corner report inspection finds seed 52 fails setup by 0.062 ns despite the timing script returning zero; seeds 61 and 87 pass setup, hold, recovery, removal and pulse width. All three pass 273 CDC register checks and ten native reset-release path checks. Recommended seed 87 has setup +0.518 ns and hold +0.117 ns, with 38138 placed ALMs, 46365 registers, 509 M10Ks, 62 DSPs and four PLLs. Seed 61 uses 38060 ALMs with setup +0.236 ns and hold +0.110 ns. Seed 52 uses 38147 ALMs. Hash-verified RBFs and resource/timing reports are packaged in results/hardware-test-6d460d2; seed 52 has an explicit timing-failed marker. These binaries include punctuation fixes but no waveform visualizer. Hardware acceptance remains pending.

#### Next Steps:

Have the user test seed 87 with the three SRT files and MPG/FLAC regression cases on 10.10.0.33; retain the separately committed waveform for a later build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 119 COMMIT Unreleased 2498125 2026-09-14T20:01:26-07:00

#### Coming From:

Unreleased 6d460d2

#### Purpose:

Implement a new stereo waveform visualizer for native music playback.

#### Outcome:

Implemented a read-only post-volume native PCM tap and cyan/orange mirrored stereo waveform behind the HDMI player overlay and OSD. Four-sample averaging feeds a 256-point history, with a separate vertical-blank snapshot and interpolated traces to avoid tearing and gaps. Source epoch changes discard old history; silence flattens traces and movie RGB/sync bypass carries an equal seven-cycle delay. Standalone Quartus mapping succeeds with zero warnings, estimating 455 ALMs, 730 registers, two M10Ks and four DSPs; this is not full-core placement or timing. Simulations pass asynchronous stereo history, silence, replacement, complete-frame constant-signal pixel oracles and RGB/sync bypass at 480p, 720p and 1080p. Native integration verifies 1024 ordered tap pairs alongside I2S/SPDIF, pause, EOF and HDMI restoration. Evidence and PNG previews are in results/waveform and results/waveform-native. Spectrum remains deferred until waveform hardware acceptance; the punctuation batch is unchanged.

#### Next Steps:

Review the RTL previews, then include this source in the next hardware build and qualify full-core timing, resource use and music/movie replacement on 10.10.0.33.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_waveform_visualizer.sv
- rtl/platform/media_native_audio.sv
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_media_native_audio.sv
- tools/test_media_waveform_visualizer.sv
- tools/verify_waveform_visualizer.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 118 COMMIT Unreleased 6d460d2 2026-09-14T19:57:08-07:00

#### Coming From:

Unreleased 6d460d2

#### Purpose:

Build the subtitle punctuation corrections for hardware validation on the fresh MiSTer installation.

#### Outcome:

The user authorizes three clean Quartus builds of source 6d460d2 using the standard seeds 52, 61 and 87. The source includes apostrophe, quotation-mark and dialogue-dash normalization already verified against 3130 real subtitle cues. The normal build helper will run compilation and four-corner timing and CDC audits for each seed. The test MiSTer is now 10.10.0.33, with official Main 20260912 and Linux image 260912 verified on the fresh installation. No automatic RBF deployment is requested.

#### Next Steps:

Check the three build results, package the best timing-qualified candidate and have the user verify punctuation, subtitles, movie playback and native FLAC on hardware.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 117 COMMIT Unreleased 6d460d2 2026-09-14T18:57:23-07:00

#### Coming From:

Unreleased 3aff0f9

#### Purpose:

Normalize the dialogue punctuation found in the user's SRT files.

#### Outcome:

Inspection of the three now-available root GIT HDD SRT files confirms dialogue-leading UTF-8 en dashes caused question marks, alongside curly apostrophes, em dashes and double quotation marks. Extended normalization maps U+2013/U+2014 to hyphen and U+201C/U+201D to ASCII double quote, with standalone Windows-1252 equivalents; the prior apostrophe fix is retained. Parser punctuation/boundary tests pass and lint has no warnings. A reusable complete-file RTL replay compares normalized text and timestamps against an independent Python oracle. All 1162 A New Hope, 1019 Empire Strikes Back and 949 Return of the Jedi cues pass, totaling 3130, with zero parser warnings. Evidence and source-file hashes are in results/srt-punctuation. User SRT files remain untouched. This source is queued for the next build; no new RBF batch was started.

#### Next Steps:

Include both punctuation corrections in the next authorized hardware build and verify those same SRT files on the MiSTer.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- rtl/media_srt_parser.sv
- tools/test_media_srt_parser.sv
- tools/test_srt_file.sv
- tools/verify_srt_files.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 116 COMMIT Unreleased 3aff0f9 2026-09-14T18:53:35-07:00

#### Coming From:

Unreleased 6bfcea3

#### Purpose:

Display common typographic apostrophes using the existing subtitle apostrophe glyph.

#### Outcome:

Confirmed the existing font includes ASCII apostrophe while the parser replaces non-ASCII UTF-8 with a question mark. The exact reported SRT encoding remains unconfirmed. The parser now normalizes UTF-8 U+2018/U+2019 and standalone Windows-1252 0x91/0x92 to ASCII apostrophe. It replaces only the allocated fallback cell after a complete matching UTF-8 sequence and clears partial decoding at line/tag boundaries, preserving unsupported-character fallback and preventing next-line consumption. Parser tests pass ASCII, both curly encodings, unsupported sequences, truncation, tag boundaries, the final available column and overflow without corrupting existing text. Streaming subtitle controller regressions also pass with cue boundaries, pause/visibility, seeking, EOF, retiming and replacement. Evidence is results/subtitle-apostrophes. No RBF was built; the completed timing-qualified 6bfcea3 candidates are unchanged.

#### Next Steps:

Include the parser correction in the next authorized build and confirm the reported subtitle file displays its apostrophes correctly on hardware.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- rtl/media_srt_parser.sv
- tools/test_media_srt_parser.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 115 COMMIT Unreleased 6bfcea3 2026-09-14T18:35:03-07:00

#### Coming From:

Unreleased 6bfcea3

#### Purpose:

Qualify and package all four approved UI and native FLAC builds.

#### Outcome:

All MEDIUM seeds 52/61/87 and HIGH seed 87 compile and pass setup, hold, recovery, removal and pulse-width checks at all four corners, plus CDC audits with all ten native reset-release stage paths still timed. Recommended HIGH seed 87 uses 37220 placed ALMs, 32652 estimated ALMs, 46210 registers, 509 M10Ks, 62 DSPs and four PLLs. Worst margins are setup +0.349 ns, hold +0.098 ns, recovery +2.891 ns, removal +0.186 ns and pulse width +0.925 ns. It saves 936 placed ALMs versus MEDIUM seed 87 (38156), with unchanged RAM/DSP/PLL counts, and leaves 4690 ALMs, 44 M10Ks, 50 DSPs and two PLLs. MEDIUM seed 52 uses 38134 ALMs with setup +0.431 ns and hold +0.075 ns; seed 61 uses 38174 with +0.292/+0.113 ns; seed 87 has +0.285/+0.116 ns. Compile times are 916.3/921.7/928.9 seconds for MEDIUM 87/61/52 and 902.5 seconds for HIGH 87. Hash-verified packages are results/hardware-test-6bfcea3 and results/hardware-test-6bfcea3-packing-high, with the combined comparison in the normal package. Recommended HIGH RBF SHA-256 is 912ed6a148869d34960bff3796ddf511746cdd850bfff0e708c6db10c0f867c8. Integer fonts, centered taller bar, direct subtitle pages, Load media and media handoff repair are all included. Hardware acceptance is pending; no core was deployed automatically.

#### Next Steps:

Have the user test HIGH seed 87 with all four MPG files, subtitles and direct controls, UI at supported resolutions, native FLAC and active/paused MPG/FLAC replacement. Preserve b639ccc seed 52 rollback and compare any reported regressions against the normal timing-qualified candidates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 114 COMMIT Unreleased 6bfcea3 2026-09-14T18:16:48-07:00

#### Coming From:

Unreleased 6bfcea3

#### Purpose:

Run one additional maximum-packing build alongside the approved UI timing batch.

#### Outcome:

The user requests one more Quartus build with the best seed and maximum effort. Seed 87 has the best previous setup margin and uses the same archived 6bfcea3 source as the ongoing three-seed batch. An isolated HIGH ALM_REGISTER_PACKING_EFFORT run is now compiling under results/build-6bfcea3-packing-high-20260914-181622 with six workers and the existing STANDARD FIT and HIGH PERFORMANCE EFFORT settings. The tracked QSF and three MEDIUM build snapshots are unchanged. The experiment helper is copied into the evidence directory; full four-corner timing and CDC/reset-release audits run after compilation. No savings or timing pass is claimed before completion.

#### Next Steps:

Compare actual placed ALMs, RAM, timing and compile time with the MEDIUM seed 87 build, and package the best fully passing candidate for hardware validation.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 113 COMMIT Unreleased 6bfcea3 2026-09-14T18:09:48-07:00

#### Coming From:

Unreleased df2d7a6

#### Purpose:

Build the approved integer-font and centered-bar UI with complete timing qualification.

#### Outcome:

Commit 6bfcea3 combines the approved integer-font and centered-bar UI with scoped native power-up reset constraints. Previous recovery failures were from sysmem init_reset_n and its fitted duplicates to async-assert/sync-release chains. The additional source-to-chain exception leaves ordinary datapaths and all ten reset-release stage transitions timed, now enforced by the audit. New bar-layout registers join the existing same-enable four-cycle scene constraint. Reanalysis of the earlier seed 87 fit passes all four corners: setup +0.335 ns, hold +0.104 ns, recovery +2.529 ns, removal +0.186 ns and pulse width +0.925 ns; proof reports are isolated under results/timing-native-reset-proof. Native audio simulation again passes 1024 exact I2S/SPDIF pairs, pause, position, drained EOF and HDMI restoration. The prior full UI/subtitle simulation passed all pixel and maximum-length cases. Clean integrated seeds 52/61/87 are running in results/build-6bfcea3-20260914-181205; fitted area, final timing and hardware acceptance for this source remain pending.

#### Next Steps:

Finish all three clean builds and check every timing corner and CDC audit. Package the best passing seed for UI, native audio, subtitles and movie replacement regressions; investigate remaining violations if necessary.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- docs/TEST_INSTRUCTIONS.md
- tools/phase1p_timing.tcl

#### Status:

- [ ] Built
- [ ] Passed

---

## 112 COMMIT Unreleased df2d7a6 2026-09-14T17:55:26-07:00

#### Coming From:

Unreleased bbc3e8a

#### Purpose:

Center a taller progress bar below the subtitle area in simulation.

#### Outcome:

Implemented an 18-logical-pixel progress bar centered between the reserved lower subtitle background edge and screen bottom, with centered black clocks and scaled fill padding. At 480p the bar is 18 pixels high at y=458, at 720p 27 pixels at y=688, and at 1080p 40 pixels at y=1032; lower margins are 4, 5 and 8 pixels respectively. Position remains fixed when subtitles are hidden. Layout uses existing sequential arithmetic. All full-frame UI/subtitle comparisons pass with zero mismatched pixels, including maximum-length lines at all resolutions, and RTL lint has no warnings. Full PNG frames and native detail crops are under results/ui-centered-bar/screenshots. The completed 3f393c5 candidates were packaged and seed 87 handed off separately; neither this bar change nor integer fonts is included in those RBFs. No new FPGA build was started.

#### Next Steps:

Have the user review the updated simulated layout and test the separate seed 87 value-page candidate. Include the font/bar changes only in the next authorized RBF build.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- rtl/media_ui_scene.sv
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 111 COMMIT Unreleased 3f393c5 2026-09-14T17:55:26-07:00

#### Coming From:

Unreleased bbc3e8a

#### Purpose:

Record the completed direct subtitle value-page builds.

#### Outcome:

All three seeds compiled and produced RBFs under results/hardware-test-3f393c5. Preferred seed 87 uses 37969 placed ALMs, 509 M10Ks, 62 DSPs and four PLLs; worst setup +0.335 ns, hold +0.104 ns and recovery -11.237 ns. Seed 52 has setup +0.068 ns, hold +0.078 ns and recovery -11.746 ns with 38111 ALMs. Seed 61 has setup -0.350 ns, hold +0.098 ns and recovery -11.205 ns with 38094 ALMs. No seed fully passes timing; fixes remain deferred. These builds include direct timing pages, Load media and FLAC-to-MPG handoff repair, but exclude bbc3e8a integer font previews. Hardware acceptance is pending.

#### Next Steps:

Test seed 87 with direct subtitle actions, picker and FLAC/MPG replacement; retain b639ccc seed 52 rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 110 COMMIT Unreleased bbc3e8a 2026-09-14T17:44:28-07:00

#### Coming From:

Unreleased 3f393c5

#### Purpose:

Simulate integer font scaling and produce exact-resolution UI previews for review.

#### Outcome:

Implemented integer glyph replication at 480p/720p/1080p using 1x/2x/3x scales, with unchanged overlay anchors and colors. Expanded the 3x coordinate bank to 2048 entries and glyph height to 21 pixels; widened text span and fixed the existing six-bit subtitle length truncation at 64 characters. All full-frame UI and subtitle oracle comparisons pass with zero mismatched pixels, including 64-character lines at all three resolutions. HPS transport, subtitle timing/controller and overlay lifetime regressions pass; RTL lint has no warnings. Native-resolution PNG frames and detail crops are exported under results/ui-integer-final/screenshots by tools/export_ui_simulation_previews.py from production-RTL renders on a solid background. These are simulations, not HDMI captures. The running 3f393c5 RBF builds are unchanged; no additional build batch or fitted-resource claim is made.

#### Next Steps:

Have the user review full-resolution screenshots and integer font sizing before including this preview change in an authorized hardware build. Continue reporting the separate 3f393c5 value-menu builds when requested.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_coordinates.mem
- rtl/media_ui_scene.sv
- tools/export_ui_simulation_previews.py
- tools/make_overlay_roms.py
- tools/test_media_player_overlay.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 109 COMMIT Unreleased 3f393c5 2026-09-14T17:34:06-07:00

#### Coming From:

Unreleased da59ce0

#### Purpose:

Replace cycling subtitle timing options with directly selectable value pages in the next combined build.

#### Outcome:

Commit 3f393c5 replaces both cycling options with direct value pages using stock Main T actions and retained timing codes. Each page has 51 values, a Subtitles return link and Main Back, totaling 53 selectable rows. Offset spans -5.0 to +5.0 seconds in 0.2-second steps; speed spans 0.50x to 1.50x in 0.02x steps, with defaults first. The source includes 78c919f Load media *.MPG,FL* and the previous FLAC-to-MPG fix. All 102 actions and repeated defaults pass actual HPS status transport with exact resulting subtitle time and unrelated status preservation. Menu readback, all 10,201 arithmetic setting pairs plus boundaries, streaming retiming and full-frame rendering pass, as does strict selection-module lint. The memory handoff regression still passes while the original wiring reproduces the stall. Clean seeds 52/61/87 are running in results/build-3f393c5-20260914-173653. No new hardware acceptance or timing closure is claimed.

#### Next Steps:

Finish and report three builds with resource and timing results. Test direct value selection, long-list scrolling and parent navigation, subtitle timing, file picker and FLAC/MPG replacement on hardware. Timing fixes remain deferred by user instruction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_subtitle_menu.svh
- MediaPlayer_top_00.svh
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_subtitle_select.sv
- rtl/media_subtitle_select_map.svh
- tools/make_subtitle_menu.py
- tools/test_media_subtitle_hps_io.sv
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 108 COMMIT Unreleased da59ce0 2026-09-14T17:26:11-07:00

#### Coming From:

Unreleased 78c919f

#### Purpose:

Record completed subtitle-control and FLAC-to-MPG handoff builds for hardware testing.

#### Outcome:

All three clean da59ce0 seeds compiled and completed timing audits, with verified RBF hashes packaged under results/hardware-test-da59ce0. Preferred seed 61 uses 38024 placed ALMs, 509 M10Ks, 62 DSPs, four PLLs and 46034 registers; free capacity is 3886 ALMs, 44 M10Ks, 50 DSPs and two PLLs. Its worst four-corner setup is +0.283 ns, hold +0.103 ns, recovery -11.027 ns, removal +0.124 ns and pulse width +0.925 ns. Seed 87 uses 38138 ALMs with setup +0.195 ns, hold +0.104 ns and recovery -11.163 ns. Seed 52 uses 38031 ALMs with setup -0.246 ns, hold +0.093 ns and recovery -11.490 ns. No seed fully passes timing; fixes remain deferred by user instruction. The same-seed 61 resource delta versus b3e4f1d is +45 placed ALMs, +2 M10Ks and +1 DSP. These RBFs include subtitle controls and the memory handoff fix but not the later 78c919f picker label. Hardware acceptance is pending.

#### Next Steps:

Test seed 61 with active and paused FLAC-to-MPG replacement, reverse switching, subtitle visibility/offset/speed and the four movie regressions. Preserve accepted b639ccc seed 52 as rollback and carry the queued Load media label into the next build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 107 COMMIT Unreleased 78c919f 2026-09-14T17:11:12-07:00

#### Coming From:

Unreleased da59ce0

#### Purpose:

Rename the media picker and limit its displayed filters to MPG and FLAC for the next build.

#### Outcome:

The user requests Load media *.MPG,FLAC. Stock Main automatically appends extensions in three-character groups, so the compatible core-only entry is S0,MPGFL*,Load media and displays Load media *.MPG,FL*. The FL* wildcard still includes FLAC files; the picker no longer advertises M2V. Do not inject duplicate suffix text or change Main. The running da59ce0 three-seed build snapshots remain unchanged.

#### Next Steps:

The production menu, matching fixture and instructions are updated; full block-RAM HPS menu readback and file-slot isolation pass. Include this change in the next build after the running da59ce0 batch.

#### Files Modified:

- MediaPlayer_top_00.svh
- tools/test_media_subtitle_hps_io.sv
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 106 COMMIT Unreleased b3e4f1d 2026-09-14T16:50:07-07:00

#### Coming From:

Unreleased b3e4f1d

#### Purpose:

Record the completed first production FLAC builds and their timing qualification.

#### Outcome:

All three clean b3e4f1d seeds 52/61/87 compiled and completed timing audits. Setup and hold pass across all four corners, but recovery fails in the new selected audio and native CD clock domains, so no seed is fully timing-qualified. Seed 87 has setup +0.354 ns, hold +0.102 ns and recovery -12.538 ns; it uses 37919 placed ALMs, 507 M10Ks, 61 DSPs and four PLLs. Seed 61 uses 37979 ALMs with setup +0.284 ns, hold +0.112 ns and recovery -12.210 ns. Seed 52 uses 38066 ALMs with setup +0.080 ns, hold +0.094 ns and recovery -12.691 ns. Resource counts other than ALMs are common to all three. RBFs and the complete report are packaged under results/hardware-test-b3e4f1d. Physical native 44.1 kHz output remains untested. The separate pending subtitle work targets the user's final 0.50x to 1.50x speed range and is absent from these build snapshots.

#### Next Steps:

Inspect and correct audio reset-recovery paths before claiming timing closure, and bundle the prepared subtitle controls into the next authorized FLAC build. Preserve the accepted b639ccc seed 52 rollback and perform native audio plus four-movie hardware regression before acceptance.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 105 COMMIT Unreleased da59ce0 2026-09-14T16:40:32-07:00

#### Coming From:

Unreleased b3e4f1d

#### Purpose:

Move subtitles into a stock Main submenu with visibility, offset and speed controls.

#### Outcome:

Commit da59ce0 implements the stock Main subtitle submenu with SRT loading, visibility, offset -5.0 to +5.0 seconds in 0.1-second steps and the final speed range 0.50x to 1.50x in 0.01x steps. Absolute serial timing arithmetic and streaming-reader restart preserve video/audio behavior; menu text uses block RAM. All 10,201 setting pairs plus boundary cases, reader retiming, actual HPS menu readback, strict timing-module lint and full-frame rendering pass. The FLAC-to-MPG fix feeds physical DDR busy to the quiesced movie arbiter so it can report idle and release music mode. The production-wiring handoff regression passes four round trips with delayed responses, music drain, physical busy and inactive grant exclusion; the original wiring reproduces the reported stall. Native audio regression passes 1024 exact I2S/SPDIF pairs, pause, position, EOF and HDMI restoration. Clean seeds 52/61/87 are building under results/build-da59ce0-20260914-170543. Prior seed 87 audio was accepted by the user, but its replacement deadlock prevented full acceptance. Timing fixes are deferred by explicit user instruction.

#### Next Steps:

Finish and report the three combined builds, including resources and timing without claiming closure. Have the user test subtitle controls and active/paused FLAC-to-MPG replacement plus the four movie regressions. Preserve b639ccc seed 52 rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_subtitle_menu.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_06.svh
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_subtitle_time.sv
- rtl/media_subtitles.sv
- sys/hps_io.sv
- tools/make_subtitle_menu.py
- tools/test_media_format_handoff.sv
- tools/test_media_subtitle_hps_io.sv
- tools/test_media_subtitle_time.sv
- tools/test_media_subtitles.sv
- tools/verify_media_format_handoff.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 104 COMMIT Unreleased b3e4f1d 2026-09-14T15:59:29-07:00

#### Coming From:

Unreleased bfdafe2

#### Purpose:

Integrate standalone native FLAC playback into the production mounted-file and platform paths.

#### Outcome:

Commit b3e4f1d integrates content-based FLAC selection, mutually exclusive drained DDR ownership, a vendor PCM CDC FIFO, native 44.1 kHz clock/output and stock Main HDMI configuration handoffs, source-sample timestamps, Space pause, volume and drained EOF. The common picker uses FL* to accommodate stock Main's three-character extension patterns. Movie decoding and its existing filter/output path remain intact; FLAC seeking and additional music processing remain later gates. Native component tests and production integration pass, including 1024 exact stereo I2S/SPDIF samples, pause, simulated Main register overwrite/reapplication, final-sample drain and movie restoration. Movie audio, pause/seek, mounted-reader duration/FLAC detection and subtitle/overlay regressions pass. Preliminary timing review corrected output-clock exclusivity and native reset release. The vendor automatic switch wrapper starts on unavailable PLL input zero, so production now explicitly gates off, selects PLL input 2/3, then reenables through synchronized requests. The integration bench executes that sequencing RTL and rejects enabled selection changes or short clock pulses. Superseded 95af4d3 and fa041b0 runs were cancelled before hardware handoff. The user requests the usual three builds; clean b3e4f1d seeds 52/61/87 are running in results/build-b3e4f1d-20260914-163106. No new RBF, fitted area, timing acceptance or physical native-HDMI qualification is claimed yet.

#### Next Steps:

Finish the three builds, audit all timing corners and physical resources, and package the best candidate for native-rate hardware and four-movie regression tests. Preserve b639ccc seed 52 as rollback. Qualify real HPS I2C busy behavior and HDMI playback on the board; stock Main, no resampling and a shared boundary for future 44.1 kHz WAV remain mandatory.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- docs/FLAC_OUTPUT_INTEGRATION.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/media_music_time.sv
- rtl/audio/media_pcm_i2s.sv
- rtl/media_duration_probe.sv
- rtl/media_keyboard_control.sv
- rtl/platform/media_audio_clocks.sv
- rtl/platform/media_audio_rate_control.sv
- rtl/platform/media_hdmi_audio_control.sv
- rtl/platform/media_native_audio.sv
- sys/emu_ports.vh
- sys/spdif.v
- sys/sys_top.v
- tools/build_three_seeds.py
- tools/phase1p_timing.tcl
- tools/test_media_duration_reader.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_music_time.sv
- tools/test_media_native_audio.sv
- tools/test_media_pcm_i2s.sv
- tools/verify_flac_integration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 103 COMMIT Unreleased bfdafe2 2026-09-14T15:29:03-07:00

#### Coming From:

Unreleased 7c197c9

#### Purpose:

Connect CRC-admitted FLAC frames to bounded DDR ownership and develop native output integration.

#### Outcome:

Commit bfdafe2 connects the FLAC parser to two external provisional/committed DDR frame banks and exact stereo PCM tokens, using 1 MiB within the inactive video FIFO region. Cancellation retains held requests and drains old responses before reuse. All 55 complete corpus files pass through modeled DDR to original PCM; the 63-case suite also covers five cancellation phases, zero-latency reads, shared-sink EOF/position and CRC failure. Native I2S tests verify 1024 exact stereo samples, 512-clock cadence, pause and last-bit drain. Connected HDMI control tests prove exclusive register access, read-modify-write/readback of 44.1/48/inherited 96 kHz output settings, simulated Main overwrite/reapplication and fault recovery. A clock-stretch timeout now generates STOP after recovery rather than leaving ownership stuck. Native PLL and vendor selector fit after using Cyclone V PLL inputs 2/3. Isolated fits use 1953 placed ALMs, two M10Ks and one DSP for decoder/store/stereo; 225 ALMs for connected HDMI control; and 78 ALMs for PCM/I2S, totaling 2256 before production integration. The clock probe uses two PLLs including the existing movie PLL. Strict lint and five native component/connected tests pass. Evidence is results/flac/ddr, results/flac/native-audio and their documented isolated fit directories. No files.qip or production top-level changes, full-core build or playable FLAC RBF are claimed; accepted b639ccc seed 52 remains unchanged.

#### Next Steps:

Wire mounted-file content selection, shared DDR ownership and PCM CDC into production; connect real drain/clock acknowledgements and the native clock/output/filter path. Then build a hardware candidate to qualify actual HPS I2C busy behavior, native HDMI clock/rate and clean movie/music transitions. Preserve existing 48 kHz MP2 and inherited platform 96 kHz output; retain the format-independent PCM boundary for future 44.1 kHz WAV. Do not equate isolated fits or simulated HPS traffic with whole-core timing or hardware acceptance.

#### Files Modified:

- docs/FLAC_FEASIBILITY.md
- docs/FLAC_OUTPUT_INTEGRATION.md
- docs/FLAC_PLAN.md
- rtl/audio/flac/flac_ddr_decoder.sv
- rtl/audio/flac/flac_frame_store.sv
- rtl/audio/media_pcm_i2s.sv
- rtl/platform/hdmi_audio_config.sv
- rtl/platform/hdmi_i2c_write_watch.sv
- rtl/platform/i2c_register_master.sv
- rtl/platform/media_audio_clocks.sv
- rtl/platform/media_audio_rate_control.sv
- rtl/platform/media_hdmi_audio_control.sv
- tools/i2c_register_model.svh
- tools/synth_flac_clock.py
- tools/synth_flac_predict.py
- tools/test_flac_ddr.sv
- tools/test_hdmi_audio_config.sv
- tools/test_hdmi_i2c_write_watch.sv
- tools/test_media_audio_rate_control.sv
- tools/test_media_hdmi_audio_control.sv
- tools/test_media_pcm_i2s.sv
- tools/verify_flac_ddr.py
- tools/verify_native_audio.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 102 COMMIT Unreleased 7c197c9 2026-09-14T15:14:08-07:00

#### Coming From:

Unreleased 36587f6

#### Purpose:

Implement complete native FLAC framing with hardware CRC admission and stereo reconstruction.

#### Outcome:

Commit 7c197c9 adds native FLAC metadata/frame parsing, canonical coded numbering, header CRC-8, frame CRC-16, padding and length validation, plus exact independent/left-side/right-side/mid-side stereo reconstruction. Samples remain provisional until an explicit whole-frame commit; store faults suppress handshakes on the same cycle. Complete-file RTL tests pass 73 cases: all 55 corpus files plus eight constructed stereo/numbering streams and ten fault cases. The 63 valid streams compare 3890965 stereo sample pairs directly with original PCM, with stalls and reset/replay in each; damaged frames are not admitted. The isolated framing/subframe/MAC fit uses 1746 placed ALMs, 1753 estimated ALMs, 859 registers, two M10Ks and one DSP, including prior decoder resources. The separate stereo unit and memory/output integration are excluded from this figure. RTL lint and test compilation pass; evidence is results/flac/stream and results/flac/stream-fit. No production files.qip integration, full-core build or playable FLAC RBF is claimed; b639ccc seed 52 remains accepted. STREAMINFO MD5 is not checked.

#### Next Steps:

Implement bounded DDR provisional/committed frame ownership and connect admitted samples to the shared PCM sink. Complete native 44.1 kHz clock and HDMI control integration before hardware handoff. Preserve existing movie behavior and the common PCM boundary for future WAV without implementing WAV parsing in this cycle.

#### Files Modified:

- docs/FLAC_FEASIBILITY.md
- docs/FLAC_FRAME_CONTRACT.md
- rtl/audio/flac/flac_stereo.sv
- rtl/audio/flac/flac_stream_decoder.sv
- tools/synth_flac_predict.py
- tools/test_flac_stream.sv
- tools/verify_flac_stream.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 101 COMMIT Unreleased 36587f6 2026-09-14T15:01:56-07:00

#### Coming From:

Unreleased 09a4d66

#### Purpose:

Implement streamed FLAC subframe parsing and reconstruction against independent test vectors.

#### Outcome:

Commit 36587f6 implements streamed RFC 9639 subframe decoding for coded 16/17-bit CD channels: constant/verbatim, fixed orders 0–4, LPC orders 1–32, wasted bits, both Rice widths, escaped residuals including zero width, partition constraints and signed range checks. It reuses the serial MAC with synchronous 32x16 coefficient and 32x17 history M10Ks. Constructed vectors first pass 83 cases; real first-frame corpus testing passes 193 cases. Full-corpus Verilator regression passes 3173 cases covering every frame of all 55 files, original PCM lengths, short final blocks, input/output stalls and 3160 midstream reset/replays. There are 7777824 complete-subframe expected samples and 7964966 provisional transfers including replayed prefixes; malformed cases may emit provisional samples before rejection. The independent offline parser validates header/frame CRCs and stereo reconstruction against original PCM before supplying coded-channel expectations. Outer framing/CRC commit and stereo joining remain software responsibilities in this harness, not implemented FPGA behavior. Isolated Quartus fitting includes the MAC and uses 1160 placed ALMs, 1154 estimated ALMs, 396 registers, two M10Ks and one DSP; no need to add the standalone MAC cost again. Strict RTL lint passes with the intentional unconnected status port excluded. Evidence is results/flac/subframe-full-corpus and results/flac/subframe-fit. No production files.qip change, integrated core build or playable FLAC RBF is claimed.

#### Next Steps:

Implement FPGA outer metadata/frame headers, CRC admission and DDR-backed stereo/frame ownership, then connect validated PCM to the shared sink. Continue native HDMI transaction and HPS interface integration before hardware handoff. Preserve native 44.1 kHz FLAC, future WAV adapter compatibility, 48 kHz movie input and the existing platform output option without claiming 96 kHz input decoding. Accepted b639ccc seed 52 remains the hardware baseline.

#### Files Modified:

- docs/FLAC_FEASIBILITY.md
- rtl/audio/flac/flac_subframe.sv
- tools/flac_reference.py
- tools/test_flac_subframe.sv
- tools/verify_flac_subframe.py
- tools/synth_flac_predict.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 100 COMMIT Unreleased 09a4d66 2026-09-14T14:54:34-07:00

#### Coming From:

Unreleased 6d564e9

#### Purpose:

Establish a codec-independent native PCM playback boundary for FLAC and future WAV.

#### Outcome:

The user authorizes continuing and requires that future native 44100 Hz WAV share the playback framework. Commit 09a4d66 adds a standalone codec-independent signed stereo PCM sink with source-sample position, serializer fetch timing, initial prefill, pause, EOF drain, restart/cancel and functional starvation handling. Simulation passes 202 exact samples plus empty EOF, replacement/seek offset and cancellation; Verilator lint passes. FLAC and future WAV use the same sample/EOF token contract, with format parsing and file seeking upstream; WAV parsing is deliberately not implemented yet. A separate HDMI I2C ownership prototype passes active/repeated-START, slave ACK/stretching, driver isolation, STOP release and reset tests. The prototype is not a real Cyclone V HPS controller model or a complete native-audio register writer; real bus-busy/timeout behavior, reset recovery and register shadow/reapply remain integration gates. Three-stage bus-input synchronizers carry recognition attributes. Both prototypes remain outside files.qip, so the accepted production movie core is unchanged. Documentation corrects the 96 kHz ambiguity: input support is 48 kHz MP2, with native 44.1 kHz FLAC planned; the inherited 96 kHz platform output option is not a 96 kHz media decoder and is not removed. Evidence is results/flac/pcm-sink and results/flac/i2c-owner; interfaces and limitations are recorded in docs/PCM_PLAYBACK_CONTRACT.md and docs/FLAC_FEASIBILITY.md. No new playable FLAC RBF or production build was generated.

#### Next Steps:

Continue full FLAC byte/bit parsing and validated frame delivery through the shared PCM boundary, together with the native HDMI transaction controller and actual HPS interface validation. Keep future WAV limited to a later adapter using this same PCM contract. Preserve accepted b639ccc seed 52 and do not claim native HDMI playback until integration and hardware checks pass.

#### Files Modified:

- docs/FLAC_PLAN.md
- docs/FLAC_FEASIBILITY.md
- docs/PCM_PLAYBACK_CONTRACT.md
- rtl/audio/media_pcm_sink.sv
- rtl/platform/hdmi_i2c_owner.sv
- tools/test_media_pcm_sink.sv
- tools/verify_media_pcm_sink.py
- tools/test_hdmi_i2c_owner.sv
- tools/verify_hdmi_i2c_owner.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 99 COMMIT Unreleased 6d564e9 2026-09-14T14:31:40-07:00

#### Coming From:

Unreleased ba9e0d8

#### Purpose:

Begin authorized FLAC feasibility and simulation implementation.

#### Outcome:

The user authorizes implementation and then explicitly selects native 44.1 kHz FLAC while preserving 48 and 96 kHz platform modes; conversion is excluded. Commit 6d564e9 adds a standalone serial FLAC prediction primitive and reproducible simulation/corpus/Quartus probes, with no production integration. Python integer comparisons pass 4097 vectors including orders 0–32, 17-bit side-channel history, residual/range checks and backpressure, plus 33 reset cancellation points; Verilator lint passes. Isolated virtual-pin prediction fitting uses 150 placed ALMs, 192 estimated ALMs, 106 registers, one DSP and zero M10Ks; this is not full decoder area or production timing. A deterministic 55-file corpus reproduces all original PCM through independent source comparisons; two damaged cases are rejected. Local FFmpeg emits no samples for the large-block noise file, while reference flac 1.5.0 decodes it exactly; the manifest records this secondary-reference limitation. A separate dual-PLL probe fits with two PLLs and 18 registers; fitter frequencies are 24.576 and 22.579199 MHz. The proposed native path retains the movie clock and adds one CD PLL, but current whole-core PLL placement and HDMI operation are unproven. ADV7513 documentation confirms automatic CTS and the channel-status rate field; the remaining native-output gate is an FPGA/HPS I2C owner or proxy that preserves Main traffic and restores/reapplies audio configuration correctly. Proposed frame storage reuses 1 MiB of the inactive compressed-video FIFO's reserved DDR range, subject to explicit drain/ownership testing. RFC 9639 and ADV7513 references are catalogued. Evidence is results/flac and docs/FLAC_FEASIBILITY.md. No playable FLAC RBF exists yet; accepted b639ccc seed 52 remains current.

#### Next Steps:

Implement and simulate the serialized HDMI audio-control path, validating HPS contention, ACK/NACK, reads, resets and reconnects before platform integration. Continue the FLAC bitstream/parser, memory ownership and full-file PCM comparison work using the corpus. Preserve native 44.1 kHz plus existing 48/96 kHz; no resampler and no removal of 96 kHz. Whole-core builds and hardware validation follow meaningful integration gates rather than treating isolated fits as a completed player.

#### Files Modified:

- docs/FLAC_PLAN.md
- docs/FLAC_FEASIBILITY.md
- rtl/audio/flac/flac_predict_mac.sv
- tools/make_flac_tests.py
- tools/synth_flac_clock.py
- tools/synth_flac_predict.py
- tools/test_flac_predict.sv
- tools/verify_flac_predict.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 98 COMMIT Unreleased ba9e0d8 2026-09-14T14:28:21-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Document the staged standalone CD-quality FLAC implementation plan.

#### Outcome:

Added docs/FLAC_PLAN.md and updated the shared-IDCT test instructions to reflect user acceptance. The plan preserves stock Main and standalone 44100 Hz, 16-bit stereo FLAC with exact decoded PCM, normal encoder settings, pause/seek, shared progress UI and drain-to-startup EOF. The current 24.576 MHz audio clock and 48/96 kHz platform output require an early native-44.1-kHz feasibility decision; a high-quality 160/147 converter is a separately disclosed alternative, not bit-perfect HDMI. Plan a serial predictor, CRC-validated frames, bounded M10K queues and DDR-backed channel storage after a memory ownership audit, with full CD-format block/order handling rather than a silently restricted 4096-only decoder. RFC 9639 was consulted as the normative FLAC source and is not yet in core-reference.md; add its controlled reference before RTL implementation. Four gates cover output/resource feasibility, standalone sample equivalence, integrated continuous playback and controls/UI with four-movie regressions. Proposed whole-feature budgets are 3500 ALMs, 28 M10Ks and 12 DSPs, not measured resource estimates. No FLAC RTL or new builds were started.

#### Next Steps:

Review the plan with the user and begin feasibility/output qualification when implementation is authorized. Retain accepted b639ccc MEDIUM seed 52, keep PCM fidelity distinct from output conversion, and measure fitted costs before full integration.

#### Files Modified:

- docs/FLAC_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 97 COMMIT Unreleased b639ccc 2026-09-14T14:26:52-07:00

#### Coming From:

Unreleased db4bc3f

#### Purpose:

Record hardware acceptance of shared-IDCT seed 52.

#### Outcome:

The user reports that the latest build passes everything. Accept the preferred b639ccc MEDIUM seed 52 shared-IDCT candidate as the new hardware baseline, with corrected audit revision db4bc3f, RBF SHA-256 a9244b912ad3acd127366e10d6470fc509ccc3d0c63b29b1a031f6674d7b9f95, 35908 placed ALMs, 512 M10Ks, 59 DSPs, and four-corner setup/hold minima +0.645/+0.081 ns. This supersedes the pending acceptance recorded in entry 96. Retain 7eb5088 MEDIUM seed 61 as the previous rollback. The user also requests a FLAC implementation plan; no FLAC implementation or additional builds are authorized by this planning step.

#### Next Steps:

Draft the standalone 44100 Hz, 16-bit stereo FLAC plan against this accepted baseline, including output-rate handling, bounded on-chip memory, exact sample verification, playback controls and video regression gates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 96 COMMIT Unreleased db4bc3f 2026-09-14T14:12:56-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Correct shared-IDCT physical-register auditing and qualify the existing three fitted builds.

#### Outcome:

Audit-only commit db4bc3f corrects the false failure: Quartus replicated transform_index bits with ~DUPLICATE suffixes inside the sole shared engine. All three fitted b639ccc designs have six logical bits, with 11/12/10 physical registers for seeds 52/61/87. The revised check requires exactly the expected engine hierarchy and six logical indices, records physical names and rejects missing bits, additional engines and unknown suffixes in mutation checks. Existing fitted databases were re-audited without RTL, constraint or RBF changes; hashes match the original compilation outputs. All seeds retain eight intermediate and three staging M10Ks, 183 CDC stages, scene enable and diagnostic-removal checks. Four-corner minima (setup/hold/recovery/removal/pulse width ns) are seed 52 +0.645/+0.081/+3.337/+0.214/+0.925, seed 61 +0.458/+0.048/+2.565/+0.182/+0.925, seed 87 -0.102/+0.105/+3.330/+0.235/+0.925. Thus 52/61 pass and 87 fails cold-corner setup. Preferred seed 52 uses 35908 placed ALMs, 512 M10Ks and 59 DSPs, saving 1136/13/16 versus accepted 7eb5088 MEDIUM seed 61 and leaving 6002/41/53 free. Packaged original b639ccc RBFs and build-info.json identify db4bc3f separately as timing_audit_revision. Evidence is results/build-b639ccc-20260914-135047; original failed timing logs and status are preserved. No full compilation of this audit-only commit was necessary; b639ccc compiled successfully and hardware acceptance remains pending.

#### Next Steps:

Test results/hardware-test-b639ccc/seed52/MediaPlayer_20260914.rbf on Fellow, Groove, Jiggler and Star Wars at both refresh rates, covering opening, motion, audio, pause/seek, reset/file replacement, subtitles/filters and EOF. Preserve accepted 7eb5088 MEDIUM seed 61 as rollback; do not start extra timing-fix builds without direction.

#### Files Modified:

- tools/phase1p_timing.tcl
- tools/audit_three_seeds.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 95 COMMIT Unreleased b639ccc 2026-09-14T14:03:21-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Record the standalone CD-quality FLAC music playback target.

#### Outcome:

The user clarifies that FLAC restores the music-player side for the user's own standalone files, not movie audio, and sets the acceptance target: a CD-ripped WAV converted to FLAC should play perfectly. The initial profile is 44100 Hz, 16-bit stereo PCM, reconstructed sample-for-sample with the original WAV before optional output filters or volume processing, with correct playback rate and no dropped/repeated samples or buffer underruns. Ordinary compatible FLAC encoder compression settings must work without a special encoding recipe; a fixed-predictor-only demonstration is insufficient. Validate lossless decoding, channel reconstruction and continuous playback against original WAV samples, plus pause/seek/EOF behavior. High-resolution and multichannel FLAC are outside this initial target. The xavieran/fLaCPGA reference was inspected at a724a18b6205b192bd42977186b669d467b0aa9b: its integrated frame path is restricted to mono and hardcoded 4096-sample blocks, with LPC code separate from the subframe path. It is an architectural reference, not a complete compatible decoder or measured Cyclone V resource estimate. No FLAC RTL is implemented by this scope update; shared-IDCT builds remain independent and the accepted video baseline stays 7eb5088 MEDIUM seed 61.

#### Next Steps:

Use this CD-quality profile for the FLAC design and test corpus, covering ordinary compression settings, metadata, channel coding, block sizes and final short blocks within the target. Measure a standalone decoder implementation before claiming it fits alongside the video player; preserve current video functionality and existing shared-IDCT build work.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 94 COMMIT Unreleased b639ccc 2026-09-14T13:49:03-07:00

#### Coming From:

Unreleased 54d64d2

#### Purpose:

Correct shared-IDCT Quartus syntax compatibility and restart the authorized three-seed batch.

#### Outcome:

The user explicitly authorizes building again, superseding the previous stop. Source b639ccc adds an explicit generate/endgenerate region and separately declared genvar around the shared coefficient banks; no arithmetic, arbitration or memory behavior changes. The existing differential suite again passes 79008 exact samples. Isolated full-design Quartus 17 analysis/elaboration succeeds with zero errors in 41 seconds after supplying the normal generated build_id.v header; evidence is under results/shared-idct-quartus-preflight and /tmp/shared-idct-quartus-preflight.log. Source is committed and pushed; clean MEDIUM seeds 52/61/87 restart under /tmp/shared-idct-build-restart.log. Full compilation, timing and hardware acceptance remain pending. The accepted 7eb5088 MEDIUM seed 61 and failed 54d64d2 batch are preserved.

#### Next Steps:

Monitor the b639ccc batch and audit all corners, placed/estimated ALMs, RAM/DSP savings, one shared IDCT engine with eight intermediate and three staging M10Ks, and existing 183-stage CDC/removal checks. Package the preferred RBF for four-file hardware acceptance at both refresh settings. Retain 7eb5088 MEDIUM seed 61 as rollback; do not launch extra timing-fix batches without direction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_shared_idct.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 93 COMMIT Unreleased 54d64d2 2026-09-14T13:45:57-07:00

#### Coming From:

Unreleased 54d64d2

#### Purpose:

Record the user's build stop and the already-terminated shared-IDCT batch.

#### Outcome:

The user explicitly says to stop the builds. Process inspection finds no running build runner or Quartus process: all three 54d64d2 seeds had already failed after about seven seconds with compile exit 3. The primary error is Quartus 17 syntax rejection at mpeg2_h262_shared_idct.sv line 56 near the module-level for generate loop, followed by cascading declarations. Simulation passes do not establish Quartus compatibility. No RBF was produced. No fixes, retries or further builds are performed after the stop instruction; accepted 7eb5088 MEDIUM seed 61 remains the hardware baseline.

#### Next Steps:

Await user direction before continuing implementation or restarting builds. Preserve failed logs under results/build-54d64d2-20260914-134450 and /tmp/shared-idct-build.log; inspect explicit generate/endgenerate syntax when work is resumed.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 92 COMMIT Unreleased 54d64d2 2026-09-14T13:22:12-07:00

#### Coming From:

Unreleased 7eb5088

#### Purpose:

Reduce duplicated IDCT hardware with measured shared transform service.

#### Outcome:

The user authorizes the deferred shared-IDCT reduction while the isolated packing run continues. Source 54d64d2 routes intra/P/B clients to one unchanged arithmetic engine, preserving immediate uncontended strobes and using three M10K coefficient banks, sparse masks and round-robin service for contention. Per-client completion/error state and global reset cancellation preserve ownership. Production selects external service; standalone wrappers retain local engines for offline tests. Simulation-only traces measure 288 intra, 1053 P and 1418 B blocks with no overlap in the mixed sample and 5518 request/completion event cycles identical to dedicated engines. The shared-unit oracle passes 79008 exact samples, independent producers, single-cycle sparse blocks, 220 reset offsets and malformed input recovery. Arithmetic/storage equivalence passes 164020 cycles and 52128 samples. Three-client repeated seeks, paired EOF and 50 Hz cases each retain 423936 pixel comparisons and identical reconstruction/cycle accounting. Adding real intra demand exposed the old stubbed-intra fixed cycle budget in both baseline and shared EOF tests; the variant now requires paired baseline accounting instead. The 16 MiB Pee Strike prefix passes normal opening plus ten-second forward seek with shared DDR and intra demand, then confirms audio/video progress without underrun or timestamp warning at cycle 432419997. This harness models bounded ideal CDC and initialized I reference pixels, not a complete physical intra DDR path; independent transform oracles establish numerical equivalence. Expected savings are 16 DSPs and 13 M10Ks; actual ALM savings await fitting. Source is pushed and clean MEDIUM seeds 52/61/87 run under /tmp/shared-idct-build.log. Fitted checks require exactly one six-bit IDCT index, eight intermediate M10Ks and three staging M10Ks alongside all existing CDC/diagnostic-removal audits. Meanwhile 7eb5088 HIGH seed 61 completes in 767.7 seconds: 36245 actual ALMs, 31461 estimated ALMs, 44768 registers, 525 M10Ks, 75 DSPs, setup -0.021 ns and hold +0.114 ns. Its 799 placed-ALM saving comes with failed setup, so accepted MEDIUM 7eb5088 seed 61 remains baseline. The HIGH RBF is hash-verified and separately packaged under results/hardware-test-7eb5088-packing-high/seed61 with a timing-failure marker; no deployment or further HIGH run is performed.

#### Next Steps:

Audit the three 54d64d2 builds for shared-engine and memory inference, timing and resources using accepted MEDIUM 7eb5088 seed 61 baseline 37044 ALMs/525 M10Ks and all diagnostic-removal requirements. Package the best RBF for four-file hardware acceptance at both refresh settings, including pause/seek/reset/replacement, subtitles/filters and EOF. Keep accepted baseline and failed HIGH experiment distinct. No additional timing-fix batches without user direction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- docs/SHARED_IDCT.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_idct.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_shared_idct.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/replay_mpg_seek.py
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_shared_idct.sv
- tools/verify_decoder_timing.py
- tools/verify_shared_idct.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 91 COMMIT Unreleased 7eb5088 2026-09-14T13:19:19-07:00

#### Coming From:

Unreleased 78c82f1

#### Purpose:

Run one isolated maximum-register-packing comparison of the accepted seed 61 core.

#### Outcome:

The user requests a dense packing run. Reuse the previous single-seed packing build helper against clean archived source 7eb5088, with seed 61, six workers and ALM_REGISTER_PACKING_EFFORT HIGH instead of MEDIUM. Keep source RTL and the tracked QSF unchanged. The accepted MEDIUM baseline uses 37044 actual ALMs, 31325 estimated ALMs, 44804 registers, 525 M10Ks and 75 DSPs with setup +0.334 ns and hold +0.074 ns. The prior bcddb20 HIGH experiment saved no ALMs, but the current design differs substantially; measure again without promising savings. Run compilation and all existing four-corner, CDC and diagnostic-removal audits. Evidence will use a distinct results/build-7eb5088-packing-high directory and /tmp/gate3-packing-high.log. This is an experimental build request, not acceptance of its eventual RBF.

#### Next Steps:

Compare final placed and estimated ALMs, RAM, DSP, registers and timing against accepted 7eb5088 MEDIUM seed 61. Package the experiment separately: do not run the normal packaging helper unmodified because its source/seed destination would overwrite the accepted RBF. Keep the accepted MEDIUM artifact and hardware acceptance intact. Report results before any additional build or default-setting change. The previous displayed timing table had a transcription error: fast -40 C recovery is +4.898 ns in the audit JSON, not +4.950 ns; the reported minimum recovery +3.668 ns is unchanged.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 90 COMMIT Unreleased 78c82f1 2026-09-14T13:10:02-07:00

#### Coming From:

Unreleased a206435

#### Purpose:

Record gate-three hardware acceptance and the completed diagnostic-removal cycle.

#### Outcome:

The user reports all tests pass after the preferred 7eb5088 seed 61 handoff, completing the three-gate diagnostic-removal cycle including the compact black-clock progress bar and lowered subtitles. Seed 61 becomes the hardware-accepted baseline; its packaged RBF hash is verified and local build metadata records acceptance. Source 7eb5088 retains four-corner timing qualification, setup +0.334 ns, hold +0.074 ns, 37044 actual ALMs, 31325 estimated ALMs, 525 M10Ks and 75 DSPs, leaving 4866 ALMs and 28 M10Ks. Functional protection and playback remain; standalone diagnostic modules are retained only for offline simulation where applicable. Test instructions and the removal plan record completion; this documentation commit leaves the accepted 7eb5088 hardware unchanged. No source logic changes, new builds, deployment or release are requested.

#### Next Steps:

Use 7eb5088 seed 61 as the accepted baseline for future authorized work and retain 100ab07 seed 87 as rollback; no further diagnostic-removal gate remains.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---
