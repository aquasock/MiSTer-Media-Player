## 133 COMMIT Unreleased ??? 2026-09-14T23:13:32-07:00

#### Coming From:

Unreleased e481f40

#### Purpose:

Shorten playback UI visibility to three seconds and the largest keyboard seek to one minute.

#### Outcome:

The user authorizes changing the shared audio/video UI inactivity timeout from ten to three seconds and Ctrl+Alt+Arrow jumps from five minutes to one minute. Keep controls visible during active seeking and preserve the existing ten-second and thirty-second jumps. Update the existing control regressions and current usage documentation.

#### Next Steps:

Check exact timeout boundaries, keyboard modifier behavior and FLAC target translation, then commit the change for the next hardware build.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- docs/FLAC_PLAN.md
- rtl/media_ui_state.sv
- rtl/media_keyboard_control.sv
- tools/test_media_ui_state.sv
- tools/test_media_keyboard_control.sv
- tools/test_flac_seek_keyboard.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 132 COMMIT Unreleased e481f40 2026-09-14T22:39:47-07:00

#### Coming From:

Unreleased 64722d0

#### Purpose:

Add an FFT-driven Fire visualizer alongside O-scope with an audio-only selection submenu.

#### Outcome:

Implemented the audio-only Visualizers submenu with Type choices O-scope and Fire; the user clarified that O-scope names the existing two ribbons, which remain pixel-identical. Fire uses an original 256-point Hann-windowed fixed-point radix-2 FFT, L+jR stereo packing and mirrored-bin absolute magnitudes, 32 frequency bands and a logarithmic flame intensity. The analyzer only observes the post-volume native PCM tap and has no ready output or stream DDR access. Complete spectra cross through a coalescing mailbox and publish during vertical blank; both renderers have nine matched pixel stages, retain the audio aspect viewport and remain below the existing UI/OSD. Mode changes commit at frame boundaries. Ten FFT cases match every complex bin and display level against an independent integer oracle, including opposite-phase stereo, noise and cancellation during analysis. Twelve complete-render cases pass both aspect modes at 480p/720p/1080p, exact movie and O-scope bypass, silence and live mode switching. Final RTL previews are in results/fire/final-render; an earlier flat-palette preview was shown to the user before the final gradient. Standalone final fit uses 1216 estimated ALMs (1381 placed), 2517 registers, six M10Ks and twelve DSPs for both visualizers together: approximately 675 estimated ALMs, four M10Ks and eight DSPs beyond the prior standalone O-scope. Short delay pipes stay in registers. Full-core Analysis and Elaboration passes; full fit/timing and hardware remain pending. Commit e481f40 is the source for the authorized three HIGH-packing builds, seeds 52/61/87.

#### Next Steps:

Inspect the three build results, all four timing corners and CDC audits, package the best candidate, and have the user test Fire/O-scope selection, audio-only menu visibility, aspect, silence/pause, seeks, EOF and MPG regression files.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/FIRE_VISUALIZER.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_audio_fft.sv
- rtl/media_audio_visualizers.sv
- rtl/media_fft_band_end.hex
- rtl/media_fft_twiddle.hex
- rtl/media_fft_window.hex
- rtl/media_fire_renderer.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/make_fire_tables.py
- tools/phase1p_timing.tcl
- tools/test_media_audio_fft.sv
- tools/test_media_fire_visualizers.sv
- tools/verify_fire_fft.py
- tools/verify_fire_visualizers.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 131 COMMIT Unreleased 64722d0 2026-09-14T22:27:22-07:00

#### Coming From:

Unreleased 64722d0

#### Purpose:

Qualify and package the combined audio graphics and menu correction builds.

#### Outcome:

All three HIGH-packing 64722d0 builds compile and pass independent four-corner setup, hold, recovery, removal and minimum pulse-width checks. All also pass 309 configuration CDC register checks and ten reset-release paths. Recommend seed 52 for strongest setup margin: setup +0.536 ns, hold +0.056 ns, recovery +3.962 ns, removal +0.214 ns and pulse width +0.925 ns. It uses 38318 placed ALMs (34100 estimated), 48646 registers, 516 M10Ks, 68 DSPs and four PLLs, leaving 3592 physical ALMs and 37 M10Ks. Seed 61 has setup +0.187 ns and hold +0.110 ns with 38180 placed ALMs; seed 87 has +0.190/+0.114 ns with 38166 placed ALMs. Hash-verified packages and JSON reports are under results/hardware-test-64722d0. Recommended seed 52 SHA-256 is d4ed65e484ec12bd5bd69eb559bea8226ee1bad032fc09ed2e3963f4c25f6344. These RBFs include the aspect and menu fixes plus earlier CD navigation and FLAC seeking. Hardware acceptance remains pending; nothing was automatically deployed. During the preceding discussion, metadata inspection confirmed the GIT HDD Beethoven Symphony No.6 (1st movement).flac contains STREAMINFO, comments and padding but no seek table, so current FLAC seeking uses beginning-of-file fallback for that file.

#### Next Steps:

Have the user test seed 52 for audio aspect switching, video-only menu disabling, paused playback, CD N/P navigation, FLAC seek jumps, EOF and MPG/FLAC replacement, then rerun the four MPG hardware regression files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 130 COMMIT Unreleased 64722d0 2026-09-14T22:07:33-07:00

#### Coming From:

Unreleased 64722d0

#### Purpose:

Build the combined audio aspect-ratio and video-only menu corrections.

#### Outcome:

The user authorizes the next three-core build cycle. Build source 64722d0 includes the d3c416a viewport correction and audio-mode menu disabling, together with the earlier CD track navigation and FLAC seeking. The tracked working tree is clean and synchronized with origin/master, HIGH ALM packing is enabled, and no previous Quartus build remains active. Launch clean source archives for seeds 52, 61 and 87 with the standard build supervisor. The completed 36085f6 seed 87 remains available for comparison. No RBF is automatically deployed.

#### Next Steps:

After compilation, inspect resources, all four timing corners and configuration/reset audits, package the best candidate, then have the user test aspect switching, disabled menu controls, CD navigation, FLAC seeking and MPG regression files.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 129 COMMIT Unreleased 64722d0 2026-09-14T22:03:44-07:00

#### Coming From:

Unreleased 36085f6

#### Purpose:

Disable video-only menu settings while native audio playback is active.

#### Outcome:

Stock Main menu-mask bit zero now follows music_play_request, and D0 prefixes disable Color matrix, Refresh rate and every generated subtitle menu entry during native audio playback, including pause and flattened-menu mode. Aspect ratio and Load media remain available. EOF/reset or video replacement restores access without modifying saved settings. The subtitle generator and generated file agree, and Quartus full-core Analysis and Elaboration passes. The cached stock Main parser confirms D applies both rendering and action rejection before page handling. No full RBF build was launched; this correction and d3c416a aspect layout await the next build cycle. Evidence is results/audio-menu/elaboration.log.

#### Next Steps:

Build the combined audio aspect and menu corrections, then verify disabled rows during playing/paused FLAC and restored controls after EOF/reset or MPG replacement.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_subtitle_menu.svh
- MediaPlayer_top_00.svh
- docs/TEST_INSTRUCTIONS.md
- tools/make_subtitle_menu.py

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

##