## 150 COMMIT Unreleased 68f32c7 2026-09-15T03:44:48-07:00

#### Coming From:

Unreleased c3549fe

#### Purpose:

Revert the c3549fe carry-select scaler rewrite that caused the setup timing failure recorded in entry 149.

#### Outcome:

sys/ascal.vhd's poly_final and poly_sum_bound are reverted to the plain single-adder-plus-clip form that was the last timing-passing baseline at 3a72b70; per-corner setup reports for all three c3549fe seeds identified this exact path, ascal's o_v_poly_t to o_v_poly_pix vertical polyphase sum on the pll_hdmi divider clock, as the sole failing category, with the carry-select rewrite costing more in routing and duplicated clip logic on this 85%-ALM, 99%-M10K device than the shorter logic-level count saved. tools/verify_scaler_poly_sum.py is removed since it validated only the now-reverted poly_sum_bound function, and the CHANGELOG.md Unreleased entry claiming a shortened carry-select polyphase sum is corrected. The XY-256 geometry and the banked-RAM feedback fabric register from c3549fe are both untouched, since neither appeared in any violating path. Source 68f32c7 is committed; the standard three-seed rebuild has not yet been launched.

#### Next Steps:

Launch the standard HIGH-packing three-seed rebuild of 68f32c7 and confirm all four timing corners pass on at least one seed before offering a hardware candidate.

#### Files Modified:

- CHANGELOG.md
- sys/ascal.vhd

#### Status:

- [ ] Built
- [ ] Passed

---

## 149 COMMIT Unreleased c3549fe 2026-09-15T03:19:34-07:00

#### Coming From:

Unreleased c3549fe

#### Purpose:

Report the three completed c3549fe full-core builds and their per-corner setup timing results.

#### Outcome:

All three HIGH-packing builds (seeds 52/61/87) compiled and fit successfully under supervisor PID 1275015, each landing at roughly 35,600-35,700 placed ALMs (85%), 51,400-51,700 registers, 546 of 553 RAM blocks (99%), 75 DSPs and four PLLs. The build script's timing_exit and stage:complete fields reflect only quartus_sta's process exit code and do not indicate whether timing closed; reading the actual per-corner setup reports shows all three seeds still violate setup on the pll_hdmi divclk path in corners 0 and 1, the same path c3549fe's fabric register was intended to repair. Seed52 shows -0.953 ns and -1.507 ns, seed61 shows -1.020 ns and -1.549 ns, and seed87 shows -0.597 ns and -1.108 ns; corners 2 and 3 pass on all three seeds, and hold, recovery, removal and minimum pulse width pass on every corner for every seed. None of the three seeds close timing, so none qualify as a hardware candidate by the project's own standard; seed87 is the least-bad of the three. At the user's explicit instruction, seed87's RBF is being deployed to the test MiSTer for hardware evaluation despite the open setup violation.

#### Next Steps:

Investigate why the fabric register added in c3549fe did not close setup on the HDMI PLL divider clock in corners 0 and 1, and determine whether the scaler polyphase carry-select change or the banked-RAM feedback break is the remaining contributor. Collect the user's hardware observations from the seed87 RBF and factor them into the next fix attempt.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 148 COMMIT Unreleased c3549fe 2026-09-15T02:45:34-07:00

#### Coming From:

Unreleased 06256f8

#### Purpose:

Double XY rendering resolution within available RAM and repair the observed HDMI timing paths.

#### Outcome:

Implemented 256 by 256 XY coordinates and three-bit phosphor storage in separate bit planes, with seven-sweep saturating decay and unchanged native PCM mapping, square aspect layout and nine-stage output latency. Registered XY, FFT and Waveforms geometry and added a fabric register within the existing three-cycle fade transaction to break banked RAM feedback timing. Replaced the scaler polyphase final sum with a carry-select equivalent without changing latency. Line tests pass all octants, endpoints, clearing and decay, including continuous full-span 44.1 kHz traffic at 25.2 MHz with both 50/60 Hz fade deadlines. Seven full-frame raster oracles pass every coordinate and palette pixel; visualizer integration and movie bypass pass at 480p/720p/1080p, with unchanged non-XY previews. GHDL passes 1048576 boundary/carry cases and one million random scaler sum pairs. Calibration before/after RTL PNGs and evidence are under results/xy-256. Standalone all-visualizer fitting passes all corners, minimum setup +0.071 ns, using 1625 placed ALMs, 1449 estimated, 2646 registers, 230996 memory bits, 31 M10Ks and ten DSPs; against the previous fit this adds twelve placed ALMs and sixteen M10Ks. Full-core RAM projects to 546 of 553 blocks; actual full fit remains pending. Source c3549fe is pushed and three HIGH-packing seeds 52/61/87 are running under supervisor PID 1275015. No RBF has been deployed. The preceding 06256f8 batch compiled but failed setup in every seed, and user-confirmed N-SPHERES playback remains evidence for the earlier hardware candidate.

#### Next Steps:

Inspect the three full-core build results and every timing corner, package the best candidate and have the user validate scope detail, fading, track-first progress behavior, filters and the MPG/FLAC regression set.

#### Files Modified:

- CHANGELOG.md
- docs/FIRE_VISUALIZER.md
- docs/TEST_INSTRUCTIONS.md
- rtl/media_fire_renderer.sv
- rtl/media_waveform_visualizer.sv
- rtl/media_xy_visualizer.sv
- sys/ascal.vhd
- tools/test_media_fire_visualizers.sv
- tools/test_media_xy_raster.sv
- tools/test_media_xy_visualizer.sv
- tools/verify_fire_visualizers.py
- tools/verify_scaler_poly_sum.py
- tools/verify_xy_audio_preview.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 147 COMMIT Unreleased 06256f8 2026-09-15T02:02:31-07:00

#### Coming From:

Unreleased 06256f8

#### Purpose:

Launch the authorized three-core build of shorter XY persistence and revised audio progress behavior.

#### Outcome:

The user authorizes three Quartus builds after converting the oscilloscope calibration file. Converted /home/vash/Desktop/calibration-8s.wav from 192 kHz sixteen-bit stereo to 44.1 kHz sixteen-bit stereo FLAC using a 64-tap-size resampling filter, compression level eight and 4096-sample frames. Output is /home/vash/Desktop/calibration-8s.flac, with 352800 samples per channel and eight-second duration; flac integrity testing passes. Stereo X/Y channels remain separate, but resampling can reduce fine drawing detail. Launch source 06256f8 using the standard seeds 52/61/87 with HIGH ALM packing. This includes source faf37ec shorter XY persistence and track-first automatic UI, with track-only pause/seek feedback. Prior source 3a72b70 seed61 remains the timing-qualified hardware candidate. No RBF deployment is authorized or performed; new fit and timing results are pending.

#### Next Steps:

Inspect all timing corners and CDC audits when the builds finish, report final resources, package the best passing candidate and have the user test the calibration FLAC, shorter trails and revised progress behavior.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 146 COMMIT Unreleased 06256f8 2026-09-15T01:49:24-07:00

#### Coming From:

Unreleased faf37ec

#### Purpose:

Show track progress before album progress and restrict seek and pause feedback to three seconds of track progress.

#### Outcome:

Implemented initial playback and natural transitions as three seconds of track progress followed by three seconds of album progress. Pause/resume and manual seek activity interrupt either phase with only three seconds of track feedback. Active seeks keep the track-relative preview visible and restart three seconds on landing, with target previews clamped to the current track bounds. The existing track-origin converter output is connected to UI state; no decoder or seek targeting changes were made. A pending flag suppresses the track metadata refresh and loaded transition after a seek, preventing an unwanted album phase, while later natural transitions still show both phases. Unavailable track duration is shown as unknown until metadata is ready. Exact unit tests pass phase boundaries, both pause transitions, seeking preview bounds, delayed metadata and loaded recovery, timeout and replacement, with unchanged video tests. The real-cue integration passes natural transitions, current-track F-keys from both views, pause and file replacement. Renderer-state lint and diff checks pass; evidence is under results/track-first-ui. Source 06256f8 is pushed and includes the preceding shorter XY persistence change. No Quartus build or deployment was started. The user clarified that the 4:3 comment was an aspect-accuracy question, not a requested default change; aspect behavior remains unchanged.

#### Next Steps:

Wait for user authorization before Quartus builds, then qualify timing and have the user check track-first automatic feedback, track-only manual feedback and shorter XY trails.

#### Files Modified:

- rtl/media_ui_state.sv
- MediaPlayer_top_00.svh
- tools/test_media_ui_state.sv
- tools/test_audio_track_ui.sv
- README.md
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 145 COMMIT Unreleased faf37ec 2026-09-15T01:46:18-07:00

#### Coming From:

Unreleased 3a72b70

#### Purpose:

Shorten XY O-Scope persistence to expose individual traces while preserving stereo geometry.

#### Outcome:

Implemented two-level saturating phosphor decay in the existing XY buffer, reducing untouched trace lifetime from fifteen to eight sweeps, approximately 250 to 133 ms at 60 Hz. Native stereo mapping, amplitude response, 128 by 128 resolution, palette and memory dimensions remain unchanged. The updated simulation passes exact connected-line geometry, stationary samples, eight-sweep disappearance, saturation for all sixteen stored intensities and replacement clearing. Strict renderer lint and diff checks pass. Evidence is under results/xy-short-persistence. Source is committed and pushed; no Quartus build or deployment was performed as explicitly requested. Actual visual preference remains for the next hardware test. Circular artistic mapping remains unimplemented.

#### Next Steps:

Wait for user authorization to include this change in a Quartus build, then assess whether the shorter trail makes individual wires clearer on hardware.

#### Files Modified:

- rtl/media_xy_visualizer.sv
- tools/test_media_xy_visualizer.sv
- docs/FIRE_VISUALIZER.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 144 COMMIT Unreleased 3a72b70 2026-09-15T01:25:52-07:00

#### Coming From:

Unreleased 3a72b70

#### Purpose:

Qualify the three completed XY O-Scope and FFT peak-hold builds and package the passing candidate.

#### Outcome:

All three HIGH-packing builds compile successfully. Seed61 passes all four timing corners with setup +0.006 ns, hold +0.077 ns, recovery +3.491 ns, removal +0.163 ns and minimum pulse width +0.925 ns; setup margin is narrow. Seed52 fails setup at -0.017 ns with hold +0.047 ns, while seed87 fails setup at -0.194 ns and hold at -0.022 ns. All seeds pass 327 configuration CDC register checks and ten reset-release paths. Recommend seed61, using 39414 placed ALMs, 35757 estimated ALMs, 51568 registers, 4027450 memory data bits, 530 M10Ks, 75 DSPs and four PLLs. This leaves 2496 unoccupied ALMs, 23 M10Ks, 37 DSPs and two PLLs. Against prior e44a72d seed61 the change is -35 placed ALMs, +497 estimated ALMs, +689 registers, +65992 memory bits, eight additional M10Ks and unchanged DSP/PLL use, illustrating variation in packing. Verified packages and full JSON reports are under results/hardware-test-3a72b70; seed61 RBF SHA-256 is e0b925e7b318834ce2423a2653c99deb26220a114b4ebc1c0493a58543110d17. No RBF was deployed, no new builds were started and hardware acceptance remains pending.

#### Next Steps:

Have the user test seed61 for all three visualizers, FFT baseline and peak markers, aspect settings, mode/file switching, album/track UI, seeking and the four MPG regression files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 143 COMMIT Unreleased 3a72b70 2026-09-15T00:52:10-07:00

#### Coming From:

Unreleased e44a72d

#### Purpose:

Add a green stereo XY O-Scope, rename the other visualizers and align FFT bars to the bottom with red peak-hold markers.

#### Outcome:

Implemented Waveforms, FFT and O-Scope selections with frame-boundary mode changes and matched nine-pixel latency. The new stereo XY renderer connects native PCM samples into a 128 by 128 four-bit phosphor map, with sixteen green intensity levels and frame-based fading. Its mailbox never backpressures audio and a new mandatory CDC audit covers the crossing. FFT bands now reach the viewport bottom, and thin red peak markers share the existing band RAM: immediate attack, 30-frame hold, then one block down every four frames, with clearing on inactive file transitions. All nineteen renderer cases pass at 480p, 720p and 1080p for both aspect settings, including unchanged Waveforms/movie pixels, mode switching, cap geometry and UI previews. Independent benches pass all XY line directions and decay levels and FFT peak attack/hold/decay/replacement. Standalone fitting uses 1440 estimated ALMs, 1613 placed, 2511 registers, 99924 memory bits, fifteen M10Ks and ten DSPs. Against the prior two-mode fit this adds 311 estimated ALMs, 345 placed and eight M10Ks with no DSP increase; the markers alone add 29 estimated ALMs and no RAM blocks or DSPs. Evidence is under results/xy-scope/peaks-render and results/xy-scope/synthesis. Source 3a72b70 is pushed and three HIGH-packing builds are running for seeds 52/61/87, supervisor PID 1146514. The earlier e44a72d album/track UI batch completed: seeds 52 and 87 pass all corners, seed61 fails setup at -0.019 ns, and every CDC audit passes. Seed52 uses 39114 placed ALMs, 522 M10Ks and 75 DSPs, with setup/hold +0.243/+0.055 ns; its verified package is under results/hardware-test-e44a72d. No RBF was deployed and neither cycle has hardware acceptance.

#### Next Steps:

Qualify full-core resource use, all timing corners and CDC audits when these three builds finish, then have the user test the three visualizers, FFT peaks and baseline, both aspect settings and existing playback/UI behavior.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/FIRE_VISUALIZER.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_audio_visualizers.sv
- rtl/media_fire_renderer.sv
- rtl/media_xy_visualizer.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_media_fft_peaks.sv
- tools/test_media_fire_visualizers.sv
- tools/test_media_xy_visualizer.sv
- tools/verify_fire_visualizers.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 142 COMMIT Unreleased e44a72d 2026-09-15T00:32:27-07:00

#### Coming From:

Unreleased c0a41cf

#### Purpose:

Show album progress followed by track progress for six seconds on audio activity and natural track changes.

#### Outcome:

Implemented audio progress as three seconds of album values followed by three seconds of current-track values, including automatic activation on natural track transitions. The user corrected the initial F-key plan: F1-F8 must always divide the current audio track, regardless of display phase; video remains whole-file. A background observer shares the existing cue RAM read port only while navigation is idle, publishing current start/end and one change pulse per transition without stalling playback. Cue-less FLAC uses the whole file as one track. Extended the shared serial sample-time converter to five album/track values using the exact 400/49 ratio with appropriate rounding; F1 maps back to the exact track-start sample, and shortcuts wait for refreshed track times. No second divider or cue RAM was added. Audio UI activity restarts the six-second sequence; active seeks retain the album preview and landing starts six seconds again. Movie UI remains three seconds. Exact timer checks, all sample-time rounding/saturation cases, modifier/bounds/OSD/held-key tests, four direct-video-seek tests, eight playback tests and all 28 FLAC album tests pass. A new integration bench verifies natural transitions and current-track F-keys during both album and track display, pause and replacement. Evidence is under results/audio-track-ui. Source e44a72d is pushed and three HIGH-packing builds are launched for seeds 52/61/87, supervisor PID 1122432. Full fit, timing and hardware acceptance remain pending.

#### Next Steps:

Qualify all build corners and CDC audits, report resource use, and have the user test album/track progress phases, automatic track transitions, current-track F-keys and all prior video/audio behavior.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- rtl/audio/flac/flac_album_control.sv
- rtl/audio/media_music_time.sv
- rtl/media_keyboard_control.sv
- rtl/media_ui_state.sv
- tools/test_audio_track_ui.sv
- tools/test_direct_seek_restart.sv
- tools/test_flac_album_control.sv
- tools/test_flac_seek_keyboard.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_music_time.sv
- tools/test_media_ui_state.sv
- tools/test_playback_restart.sv
- tools/verify_flac_album.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 141 COMMIT Unreleased c0a41cf 2026-09-15T00:16:20-07:00

#### Coming From:

Unreleased 8298662

#### Purpose:

Qualify the completed F-key and quantized Fire batches and report full-core resources.

#### Outcome:

Both batches complete. All d2487b8 seeds pass four-corner timing; setup/hold minima are +0.361/+0.069 ns for 52, +0.530/+0.045 ns for 61 and +0.121/+0.093 ns for 87. For the newer c0a41cf block Fire batch, seeds 52 and 87 pass all four corners while 61 fails setup at -0.064 ns. Recommend c0a41cf seed87: setup +0.261 ns, hold +0.064 ns, recovery +3.844 ns, removal +0.224 ns and minimum pulse width +0.925 ns. Seed52 has setup +0.089 ns and hold +0.095 ns. Every build passes 321 configuration CDC register checks and ten reset-release paths. Latest seed87 uses 39064 placed ALMs (34834 estimated), 50655 registers, 3961458 memory data bits, 522 M10Ks, 74 DSPs and four PLLs, leaving 2846 physical ALMs, 31 M10Ks, 38 DSPs and two PLLs. Compared with d2487b8 seed87, quantized Fire saves 67 placed ALMs, 144 estimated ALMs, 262 registers, 352 memory bits and two DSPs with no additional M10K. Packages with hash verification and JSON reports are under results/hardware-test-d2487b8 and results/hardware-test-c0a41cf. Recommended seed87 RBF SHA-256 is 58ffeb0830986ad291dcdb30bec1d494728b0b3069dbf2422c8c0830442016cb. All latest player changes are included; no RBF was deployed and hardware acceptance remains pending.

#### Next Steps:

Have the user test c0a41cf seed87 for discrete Fire and O-scope, all keyboard seeks and pause states, duration gating, CD tracks, aspect, EOF, file replacement and the four MPG regression files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 140 COMMIT Unreleased 8298662 2026-09-15T00:12:47-07:00

#### Coming From:

Unreleased 1da2774

#### Purpose:

Extend album creation to convert mixed audio formats into the core's native CD profile.

#### Outcome:

Extended bundle_flac_album.py to accept common audio formats including FLAC, WAV, AIFF, MP3, AAC/M4A, Ogg, Opus, WMA, APE and WavPack in filename order. FFmpeg replaces the FLAC-only decoder and produces 44100 Hz sixteen-bit stereo using its native resampler with a 64-tap filter and triangular dithering when conversion requires it. Already-compatible CD FLAC and WAV samples remain exact in regression. Each unaligned track gets at most 587 zero samples appended for valid embedded CD boundaries, reported to the user; no source samples are removed. Existing sources and outputs remain protected, and verified album encoding retains the bounded seek table. Added tools/verify_flac_bundler.py with seven source fixtures covering lossless CD data, 48/96 kHz high-depth inputs, MP3, mono AAC and an unaligned WAV. It checks sample-exact CD segments, all track offsets and padding, metadata, source hashes and overwrite refusal; all pass with evidence in results/flac-bundler-mixed. The script copy beside the user's Groovehouse album tracks is updated after checking it matched the prior version. No user conversion was run and no RBF build is needed.

#### Next Steps:

Run python3 bundle_flac_album.py in a track folder as before; the installed script now requires ffmpeg and flac. Continue the independent hardware build qualification.

#### Files Modified:

- tools/bundle_flac_album.py
- tools/verify_flac_bundler.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 139 COMMIT Unreleased 1da2774 2026-09-15T00:08:18-07:00

#### Coming From:

Unreleased f874dcd

#### Purpose:

Require an explicit album filename operand for the FLAC splitter.

#### Outcome:

Updated split_flac_album.py to require an album path operand and removed automatic folder scanning. Input can name any compatible embedded-cue CD FLAC; output still goes beside the script. Added a clear missing-file error and refreshed usage text. Help, missing-operand rejection and missing-file checks pass; the unchanged explicit-input split path was already sample-exact in the preceding round-trip validation. The user's companion copy in the Groovehouse album folder is updated. Source 1da2774 is pushed; no album conversion or RBF build was started.

#### Next Steps:

Use python3 split_flac_album.py followed by the quoted input FLAC path; continue the existing hardware build qualification independently.

#### Files Modified:

- tools/split_flac_album.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 138 COMMIT Unreleased f874dcd 2026-09-15T00:04:19-07:00

#### Coming From:

Unreleased 17abc57

#### Purpose:

Add a standalone companion that splits embedded-cue album FLACs into adjacent track files.

#### Outcome:

Added tools/split_flac_album.py. Without arguments it locates exactly one adjacent FLAC containing an embedded CUESHEET; an optional explicit album path resolves ambiguity. It validates CD-format track boundaries, decodes once to a temporary WAV and re-encodes sample-exact track slices with verification and seek points into the script directory. Generic names such as 01 - Track 01.flac are necessary because the bundler did not retain original song titles or filenames. Existing outputs are refused and the album is preserved. A three-track generated bundle/split round trip confirms every original PCM sample and track length, unchanged source hash, automatic selection among loose tracks, overwrite refusal and explicit-path use from a different working directory; evidence is under results/flac-splitter. A copy is placed at /run/media/vash/ROCKBOX/Audio/Artists/Groovehouse – Elmúlt A Nyár/split_flac_album.py. The user's album has not been split automatically. This host utility requires no new RBF build.

#### Next Steps:

The user can run python3 split_flac_album.py beside the album, or supply an explicit album path; continue monitoring the independently queued hardware builds.

#### Files Modified:

- tools/split_flac_album.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 137 COMMIT Unreleased 17abc57 2026-09-14T23:57:03-07:00

#### Coming From:

Unreleased c0a41cf

#### Purpose:

Provide a standalone Python utility that bundles adjacent CD-format FLAC tracks into a core-compatible album.

#### Outcome:

Added tools/bundle_flac_album.py as a standalone no-argument utility that reads adjacent FLAC tracks in filename order and writes a folder-named album FLAC. It assumes CD-format sources, streams decoded PCM through a temporary WAV, embeds CD track markers and up to 400 evenly spaced seek points plus track points to stay within the core's 512-point capacity, and verifies FLAC encoding. Source tracks remain unchanged and existing output is refused. A generated three-track Unicode-path fixture passes exact concatenated-PCM comparison, embedded CD CUESHEET and SEEKTABLE checks, unchanged-source hashes and overwrite refusal; evidence is under results/flac-bundler. A copy is placed beside the user's tracks at /run/media/vash/ROCKBOX/Audio/Artists/Groovehouse – Elmúlt A Nyár/bundle_flac_album.py. The user's album conversion was not run. Source 17abc57 is pushed; this utility does not require an RBF rebuild.

#### Next Steps:

The user can run python3 bundle_flac_album.py from the album folder and load the resulting single FLAC for playback, seeking and N/P navigation; continue monitoring the separately queued hardware builds.

#### Files Modified:

- tools/bundle_flac_album.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 136 COMMIT Unreleased c0a41cf 2026-09-14T23:43:41-07:00

#### Coming From:

Unreleased a77a2da

#### Purpose:

Replace continuous Fire flames with quantized spectrum blocks and two solid colors.

#### Outcome:

Replaced interpolated procedural flames with 32 independent columns of discrete spectrum blocks, with only the highest lit block in each band orange and every lower block yellow as the user clarified. Removed band blending, continuous shading, animation turbulence and renderer multipliers. A remainder accumulator maps all 32 columns across the viewport and integer scanline counters form the block grid. The unchanged FFT supplies quantized heights; the renderer retains nine-cycle latency, frame snapshots, aspect clipping and the existing UI. All twelve full-render cases pass at 480p, 720p and 1080p, including exact original O-scope and movie bypass, silence and live mode switching. Added assertions require exactly one orange cap per nonempty column and yellow below, with no blended colors. Final previews are in results/fire-blocks/final-render. Standalone Fire drops from 305.2 to 209.8 estimated ALMs, 846 to 528 registers and two to zero DSPs, retaining one M10K. Combined standalone visualizers use 1129 estimated ALMs, 1268 placed ALMs, 2177 registers, seven M10Ks and ten DSPs versus 1216/1381/2517/six/twelve previously. The extra combined M10K is a short ypos pipe inferred in the unchanged O-scope, not additional Fire storage; full-core inference remains to be measured. Source c0a41cf is pushed. Three HIGH-packing builds are queued after d2487b8 through results/fire-blocks/queue-build.py, PID 1031607. Full-core fit, timing and hardware remain pending.

#### Next Steps:

Inspect and qualify the queued c0a41cf batch, report actual full-core resource differences, and have the user test the orange-cap block Fire together with all playback shortcuts.

#### Files Modified:

- rtl/media_fire_renderer.sv
- tools/verify_fire_visualizers.py
- docs/FIRE_VISUALIZER.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 135 COMMIT Unreleased a77a2da 2026-09-14T23:35:48-07:00

#### Coming From:

Unreleased d2487b8

#### Purpose:

Qualify the completed shorter-UI and one-minute-seek build batch and report resources.

#### Outcome:

All three a77a2da HIGH-packing builds complete in approximately sixteen to seventeen minutes. Independent four-corner checks qualify seeds 61 and 87; seed 52 fails setup at -0.187 ns. Recommend seed 61 with worst setup +0.460 ns, hold +0.114 ns, recovery +2.808 ns, removal +0.172 ns and minimum pulse width +0.925 ns. Seed 87 has setup +0.011 ns and hold +0.109 ns. All pass 321 configuration CDC register checks and ten reset-release paths. Seed 61 uses 39128 placed ALMs, 34950 estimated ALMs, 51051 total registers, 3961810 block-memory data bits, 522 M10Ks, 76 DSP blocks and four PLLs, leaving 2782 physical ALMs, 31 M10Ks, 36 DSPs and two PLLs. Hash-verified RBFs and reports are packaged under results/hardware-test-a77a2da; seed61 SHA-256 is 05dfcd392a7e20270e94e10fd0be981d0abfda4917676c0807ddc7ca164d6484. The queued d2487b8 batch with F1-F8 shortcuts automatically started at 23:32:42 in results/build-d2487b8-20260914-233242 and is still compiling. Nothing was deployed and hardware acceptance remains pending.

#### Next Steps:

Finish and qualify the d2487b8 batch, then offer its best candidate for combined Fire, UI timeout, relative seek and F-key hardware tests.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 134 COMMIT Unreleased d2487b8 2026-09-14T23:21:00-07:00

#### Coming From:

Unreleased a77a2da

#### Purpose:

Add F1 through F8 absolute seeks to eight equal runtime section starts for audio and video.

#### Outcome:

Implemented F1 through F8 as absolute seeks to zero through seven eighths of the duration for audio and video. The shared keyboard uses the qualified duration and validity from the UI scene, so unknown or contradicted durations are rejected without another file scan. Widened shift/add arithmetic prevents overflow without a multiplier. Tests cover every key with ordinary, short, uneven and maximum durations, paused and playing states, held and busy keys, OSD suppression, seek gating and file replacement. The production video seek-search/restart simulation passes absolute beginning, middle and late-file jumps with asynchronous configuration and DDR retirement. All 27 FLAC album cases pass, including all eight sample targets. All eight playback regressions pass; the unchanged timestamp-tolerance test initially exceeded its sixty-second wall limit under concurrent Quartus load and passes when rerun with a three-hundred-second allowance. Source d2487b8 is pushed and includes Fire, the three-second UI timeout and one-minute modified-arrow jumps. Three HIGH-packing builds are queued after the active a77a2da batch by results/runtime-keys/queue-build.py, supervisor PID 1000726. Full compile, timing and hardware validation remain pending.

#### Next Steps:

Inspect the queued d2487b8 seeds 52, 61 and 87 when complete, qualify timing and package a hardware candidate for audio/video function-key and visualizer checks.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- MediaPlayer_top_00.svh
- rtl/media_keyboard_control.sv
- tools/test_media_keyboard_control.sv
- tools/test_flac_seek_keyboard.sv
- tools/test_playback_restart.sv
- tools/test_direct_seek_restart.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 133 COMMIT Unreleased a77a2da 2026-09-14T23:13:32-07:00

#### Coming From:

Unreleased e481f40

#### Purpose:

Shorten playback UI visibility to three seconds and the largest keyboard seek to one minute.

#### Outcome:

Implemented the shared audio/video UI inactivity timeout of three seconds and Ctrl+Alt+Arrow jumps of one minute. Active seeking keeps the controls visible; ordinary arrows remain ten seconds and Ctrl+Arrow remains thirty seconds. Exact timeout boundary checks pass while paused and after seek completion. Keyboard checks cover both modifier sides, backward clamping, OSD and held-key suppression. All eight playback-control regressions and the complete FLAC album/navigation/PCM landing suite pass, including the updated sixty-second keyboard targets. Source a77a2da is pushed and the standard three HIGH-packing builds are launched with Fire included. Full fit, timing and hardware validation remain pending.

#### Next Steps:

Inspect seeds 52, 61 and 87, qualify timing and package the best RBF for hardware checks of the shorter UI timeout and one-minute seeks in both media modes.

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

