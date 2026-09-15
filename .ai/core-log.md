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

## 89 COMMIT Unreleased a206435 2026-09-14T13:07:28-07:00

#### Coming From:

Unreleased 7eb5088

#### Purpose:

Document and package gate-three build qualification for hardware testing.

#### Outcome:

All three 7eb5088 builds complete in 15.1-15.2 minutes. Seeds 61 and 87 pass all four timing corners; seed 52 fails setup at -0.191 ns. All pass 183 CDC stages, formatter enables, profiler/reporting absence and eleven test-audio removal checks with movie PCM, FIFO and finished synchronization retained. Preferred seed 61 has setup +0.334 ns and hold +0.074 ns, uses 37044 actual ALMs, 31325 estimated ALMs, 44804 registers, 525 M10Ks, 75 DSPs and three PLLs. This saves 282 placed ALMs, 495 estimated ALMs and two M10Ks against accepted gate-two seed 87, leaving 4866 ALMs and 28 M10Ks. Seed 87 uses 36916 actual/31285 estimated ALMs with setup +0.083 ns and hold +0.115 ns. Seed 52 uses 37029 actual/31287 estimated ALMs with hold +0.114 ns. Hash-verified RBFs are packaged under results/hardware-test-7eb5088; seed 52 is marked timing failed. Preferred seed61/MediaPlayer_20260914.rbf SHA-256 is bbd4c36588e5db22343e5e688ef177ed1f54ce24cb4206b8d76332e1d74b84fc. Hardware acceptance is pending; no deployment or additional timing-fix builds are performed.

#### Next Steps:

Qualification is documented and pushed; have the user repeat Fellow, Groove, Jiggler and Star Wars at both refresh rates, checking black clocks on the lowered bar, lowered subtitles, absent status labels and Audio test menu, audio/filters, pause/seek, replacement and EOF. Retain accepted gate-two 100ab07 seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 88 COMMIT Unreleased 7eb5088 2026-09-14T12:45:21-07:00

#### Coming From:

Unreleased 0ad4b1b

#### Purpose:

Remove gate-three Audio test hardware and consolidate playback clocks onto the progress bar.

#### Outcome:

The user reports all gate-two hardware tests pass and authorizes gate three plus compact UI changes. Source 7eb5088 removes the Audio test menu, tone generator, test PCM FIFO, mode/restart mailboxes, reset/control state, adapter and output mux; movie PCM connects directly to MiSTer outputs. Old status bits 1–3 stay reserved. Black elapsed/total/remaining clocks share the bar; Paused/Seeking character generation and status payload bits are removed. The bar and subtitles move down one 14-pixel logical line, preserving activity visibility, seek previews, subtitles and functional pause/seek. Twelve player and five subtitle full-frame cases pass at 480p/720p/1080p. Controls, reader-error seek retirement, subtitle transport/lifetime and EOF pass; mixed and seek-EOF oracles each check 423936 pixels without mismatches. Audio checks 48384 stereo pairs within one PCM unit of FFmpeg, exact pause/seek sequences and 30 PTS records without warning or underrun. Static bindings prove old Audio test bits cannot override movie PCM. Fitted audits require 11 test-hardware patterns absent and three functional PCM groups present, plus the existing 183 CDC checks. Source is pushed and clean seeds 52/61/87 run under /tmp/gate3-build.log. Gate-two 100ab07 seed 87 is hardware accepted and retained as rollback; no core is deployed.

#### Next Steps:

Audit all three builds for timing, retained PCM and CDC, test-hardware absence and resources; package the preferred RBF for the user's four-file hardware acceptance. Use audit_three_seeds.py with --require-no-profiler --require-no-reporting --require-no-audio-test and gate-two baseline 37326 ALMs/527 M10Ks. Do not launch extra timing-fix builds without direction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_ui_scene.sv
- rtl/media_ui_state.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/test_media_ui_state.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 87 COMMIT Unreleased 0ad4b1b 2026-09-14T12:36:07-07:00

#### Coming From:

Unreleased 100ab07

#### Purpose:

Qualify and package gate-two builds for the user's four-file hardware test.

#### Outcome:

All 100ab07 seeds complete in 15.1-15.6 minutes and pass four timing corners, 183 CDC stage checks, scene-enable checks, zero-profiler audit and all 17 reporting-removal patterns. Seeds 52/61/87 have setup +0.072/+0.188/+0.344 ns, hold +0.116/+0.115/+0.106 ns, actual ALMs 37325/37366/37326 and estimated ALMs 31844/31900/31820. All retain 527 M10Ks, 75 DSPs and three PLLs. Preferred seed 87 leaves 4584 ALMs and 26 M10Ks, with resources essentially flat versus gate-one seed 52: +59 placed and +33 estimated ALMs despite verified reporting-register removal. No further savings should be claimed from this gate. Hash-verified candidates are under results/hardware-test-100ab07; preferred seed87/MediaPlayer_20260914.rbf SHA-256 is 297690c42da92880077be53601e23a7a7fc8c6d4d90fc50105577f0c7f288dba. Audio test remains for gate three. No additional builds, timing fixes or deployment were performed; gate-two hardware acceptance is pending.

#### Next Steps:

Have the user test Fellow, Groove, Jiggler and Star Wars with playback, pause/seek, subtitles, OSD/filters, file replacement and EOF at both output rates; await authorization before gate three. Retain gate-one seed 52 and accepted b05b76f seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 86 COMMIT Unreleased 100ab07 2026-09-14T12:09:09-07:00

#### Coming From:

Unreleased a406feb

#### Purpose:

Implement gate-two reporting removal and frozen MPEG2FPGA repository cleanup.

#### Outcome:

The user authorizes gate two after the gate-one candidate handoff. Source 100ab07 removes the reporting mailbox, minimum-reservoir tracking, audio warning/sample-count crossings, whole-second reporting, dead LED-success expressions and 70 unconsumed decoder observation connections. Standalone module observation ports remain for simulation; a 17-pattern fitted audit requires their selected reporting registers absent in production. Seek/EOF now use identical named pending-frame/reorder state outputs. A dependency review found reader failure also traveled through the old telemetry bus into seek control; a dedicated one-bit reader_error_config mailbox preserves that function and the mandatory CDC total stays 183. Live timeout quarantine, fatal checks, PCM-finished crossing, generation/byte position, 90 kHz ticks and Audio test remain. The inactive 57-file MPEG2FPGA tree and two wrappers are deleted, with provenance and retained licensing documented. Mixed I/P/B EOF and seek-to-EOF/ownership oracles each pass 423936 pixels with no mismatch; controls, reader fault/quarantine, raster/refresh, subtitle/UI and independent reader-error CDC/seek retirement pass. Audio checks 48384 sample pairs within one PCM unit of FFmpeg, exact pause/seek output and 30 PTS records without underrun or timestamp warning. Evidence is under results/gate2-*. Source is pushed and clean seeds 52/61/87 run under /tmp/gate2-build.log. No core is deployed and no gate-three work starts. Timing will be reported without extra closure builds per the user's preference.

#### Next Steps:

Audit and package gate-two timing, remaining CDC, reporting-register absence and resources; provide the preferred RBF for Fellow, Groove, Jiggler and Star Wars. Retain gate-one seed 52 and explicitly hardware-accepted b05b76f seed 87; wait for user authorization before gate three.

#### Files Modified:

- CHANGELOG.md
- CONTRIBUTING.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- README.md
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/LEGACY_MPEG2FPGA.md
- docs/MPEG2_NEW_DECODER.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/mpeg2_ddram_bridge.sv
- rtl/mpeg2_decoder.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2fpga/README.md
- rtl/mpeg2fpga/compat/generic_dpram.v
- rtl/mpeg2fpga/compat/generic_fifo_dc.v
- rtl/mpeg2fpga/compat/generic_fifo_sc_b.v
- rtl/mpeg2fpga/compat/wrappers.v
- rtl/mpeg2fpga/mpeg2/fifo_size.v
- rtl/mpeg2fpga/mpeg2/framestore.v
- rtl/mpeg2fpga/mpeg2/framestore_request.v
- rtl/mpeg2fpga/mpeg2/framestore_response.v
- rtl/mpeg2fpga/mpeg2/fwft.v
- rtl/mpeg2fpga/mpeg2/getbits.v
- rtl/mpeg2fpga/mpeg2/idct.v
- rtl/mpeg2fpga/mpeg2/iquant.v
- rtl/mpeg2fpga/mpeg2/mem_addr.v
- rtl/mpeg2fpga/mpeg2/mem_codes.v
- rtl/mpeg2fpga/mpeg2/mixer.v
- rtl/mpeg2fpga/mpeg2/modeline.v
- rtl/mpeg2fpga/mpeg2/motcomp.v
- rtl/mpeg2fpga/mpeg2/motcomp_addrgen.v
- rtl/mpeg2fpga/mpeg2/motcomp_dctcodes.v
- rtl/mpeg2fpga/mpeg2/motcomp_dcttype.v
- rtl/mpeg2fpga/mpeg2/motcomp_motvec.v
- rtl/mpeg2fpga/mpeg2/motcomp_picbuf.v
- rtl/mpeg2fpga/mpeg2/motcomp_recon.v
- rtl/mpeg2fpga/mpeg2/mpeg2video.v
- rtl/mpeg2fpga/mpeg2/osd.v
- rtl/mpeg2fpga/mpeg2/pixel_queue.v
- rtl/mpeg2fpga/mpeg2/probe.v
- rtl/mpeg2fpga/mpeg2/read_write.v
- rtl/mpeg2fpga/mpeg2/regfile.v
- rtl/mpeg2fpga/mpeg2/regfile_codes.v
- rtl/mpeg2fpga/mpeg2/resample.v
- rtl/mpeg2fpga/mpeg2/resample_addrgen.v
- rtl/mpeg2fpga/mpeg2/resample_bilinear.v
- rtl/mpeg2fpga/mpeg2/resample_codes.v
- rtl/mpeg2fpga/mpeg2/resample_dta.v
- rtl/mpeg2fpga/mpeg2/reset.v
- rtl/mpeg2fpga/mpeg2/rld.v
- rtl/mpeg2fpga/mpeg2/syncgen.v
- rtl/mpeg2fpga/mpeg2/syncgen_intf.v
- rtl/mpeg2fpga/mpeg2/synchronizer.v
- rtl/mpeg2fpga/mpeg2/timescale.v
- rtl/mpeg2fpga/mpeg2/vbuf.v
- rtl/mpeg2fpga/mpeg2/vlc_tables.v
- rtl/mpeg2fpga/mpeg2/vld.v
- rtl/mpeg2fpga/mpeg2/vld_codes.v
- rtl/mpeg2fpga/mpeg2/watchdog.v
- rtl/mpeg2fpga/mpeg2/wrappers.v
- rtl/mpeg2fpga/mpeg2/xfifo_sc.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo144.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo216.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo_dc.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo_sc.v
- rtl/mpeg2fpga/mpeg2/yuv2rgb.v
- rtl/mpeg2fpga/mpeg2/zigzag_table.v
- rtl/mpeg2fpga/mpeg2fpga.qip
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/test_reader_error_seek.sv
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 85 COMMIT Unreleased a406feb 2026-09-14T12:07:01-07:00

#### Coming From:

Unreleased 8e418b3

#### Purpose:

Qualify and package diagnostic-removal gate one for the user's four-file hardware test.

#### Outcome:

All 8e418b3 seeds compile and pass all four timing corners, 183 CDC checks, scene-enable checks and zero-profiler-register audits. Seed 52 is preferred with setup +0.397 ns and hold +0.114 ns; seeds 61/87 have setup +0.397/+0.197 ns and hold +0.099/+0.089 ns. Actual ALMs are 37267/37169/37350 and estimated ALMs 31787/31731/31708, with unchanged 527 M10Ks and 75 DSPs. Compared with accepted b05b76f seed 87, preferred gate-one seed 52 saves 964 estimated ALMs but only 143 placed ALMs because packing differs. The reporting mailbox survives this gate and all six stages remain audited; profiler hardware is absent. Hash-verified candidates and notes are under results/hardware-test-8e418b3; preferred seed52/MediaPlayer_20260914.rbf SHA-256 is 78501002b4e4d9669635ffa30e9f744e47103baf0e12740e09594f2a40c625a8. The user says not to pursue timing closure now; no fixes or extra builds were needed or started. They additionally authorize frozen MPEG2FPGA reference cleanup at gate two; the plan records checking unused wrappers and retaining required attribution. Gate-one hardware acceptance is pending; no core was deployed.

#### Next Steps:

Have the user test Fellow, Groove, Jiggler and Star Wars including no telemetry, black transparent status text, audio/video, controls, subtitles and EOF at both output rates. Proceed to reporting-source and frozen-reference cleanup only after gate-one acceptance; retain b05b76f seed 87 as rollback.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 84 COMMIT Unreleased 8e418b3 2026-09-14T11:46:01-07:00

#### Coming From:

Unreleased e9f9bfb

#### Purpose:

Implement diagnostic-removal gate one and transparent black playback status text.

#### Outcome:

Source 8e418b3 implements gate one of the user-approved three hardware gates: removes the cadence profiler instance, frozen snapshot/telemetry rendering, unused RGB declarations, production QIP inclusion and obsolete snapshot CDC exceptions. Framebuffer RGB now passes directly to the existing video outputs with unchanged sync/DE; seek/EOF scheduler debug bits, reporting-source RTL, functional errors and Audio test remain. The fitted audit requires zero profiler registers; the telemetry-only mailbox may be naturally pruned, but every surviving stage and all functional mailboxes remain checked. The user's additional status change renders Paused/Seeking in opaque black with transparent glyph gaps instead of a white inset, preserving progress fill, coordinates and subtitle backdrops. Twelve player frame cases and five subtitle frame cases pass with zero pixel mismatches at 480p/720p/1080p; parser, transport, subtitle lifecycle, UI lifetime/divider, playback/audio and 64-check EOF/session regressions pass. Mixed I/P/B EOF qualification passes with 423936 pixel comparisons and zero mismatches. Generated empty/full status previews were inspected. The source and updated three-gate plan are pushed; clean seeds 52/61/87 are running under /tmp/gate1-build.log. No core is deployed. Gate two and gate three remain blocked on separate user hardware acceptance, with accepted b05b76f seed 87 retained as rollback.

#### Next Steps:

Audit all corners, profiler absence, remaining CDC and resource usage; package the strongest passing RBF for Fellow, Groove, Jiggler and Star Wars tests. Wait for gate-one hardware acceptance before removing reporting sources or Audio test.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_overlay_compositor.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 83 COMMIT Unreleased e9f9bfb 2026-09-14T11:40:39-07:00

#### Coming From:

Unreleased 6688db2

#### Purpose:

Record hardware acceptance of the EOF core and plan safe production diagnostic removal.

#### Outcome:

The user reports the latest EOF core passes, accepting b05b76f seed 87's startup return, session clearing and layout as the new rollback baseline. Its package metadata is marked accepted. Source e9f9bfb adds a proposed removal plan only; no RTL is changed and no new builds start. The inventory identifies the cadence snapshot/overlay, 256-bit telemetry mailbox, reporting-only counters and CDC, profiler-only seconds clock and Audio test generator/transport/menu. Seek and EOF consume scheduler debug bits 26 and 0, so named functional outputs must replace them before debug cleanup. Decoder modules named probe/diagnostic, fatal checks, timeouts, byte positions, generations, FIFO flow control, PCM finished synchronization and the 90 kHz timebase must remain. Proposed implementation is two reviewable commits followed by one three-seed batch, with pixel/PCM/control/subtitle regressions and post-fit proof of removal. Simulation tooling remains; the unbuilt audio warning tolerance becomes unnecessary in production when its reporting consumer is removed. Baseline is 37410 actual ALMs, 527 M10Ks and 75 DSPs; savings must be measured rather than promised.

#### Next Steps:

Present the plan for implementation approval, then remove reporting hardware while preserving functional safety and qualify seeds 52, 61 and 87 against accepted b05b76f.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 82 COMMIT Unreleased 6688db2 2026-09-14T11:22:33-07:00

#### Coming From:

Unreleased b05b76f

#### Purpose:

Reproduce and correct the startup audio timestamp warning observed on Fellow and Groove.

#### Outcome:

Source 6688db2 changes only the audio timestamp warning tolerance from two to 90 ticks (1 ms); sample scheduling and underrun detection are unchanged. Exact first-MiB replays reproduce Fellow and Groove at sample 4608 before consumption (hardware count 4609): second audio PES PTS is 56477 instead of the continuous sample-grid value 56492, a 15-tick/167-us backward step. Jiggler and Star Wars have the aligned timestamp and no warning. Before/after replays of all four files preserve identical PCM, video bytes and PTS output and now have no warning or underrun. Seven directed cases cover zero/two/15/90-tick tolerance, retained warnings at 91/900 ticks, timestamp wrap, exact 512-clock cadence and 6912 sample pairs each. Playback, EOF/session and generated-MPG PCM/PTS, pause and seek regressions pass. The timed MPG bench now uses production 60/24.576 MHz clocks rather than 100/40.96 MHz. Evidence is in results/audio-startup-before, results/audio-startup-after, results/audio-tolerance-controls.json and results/audio-tolerance-mpg.json. The unchanged EOF source b05b76f finished all builds: seeds 52 and 87 pass four corners, 183 CDC registers and scene-enable checks; seed 61 misses setup by 0.009 ns. Preferred EOF seed 87 has setup +0.358 ns, hold +0.099 ns, 37410 actual ALMs, 527 M10Ks and 75 DSPs, leaving 4500 ALMs and 26 M10Ks. Packaged results/hardware-test-b05b76f/seed87/MediaPlayer_20260914.rbf has SHA-256 e9ac8007db6a50877ea9ebc7b666b7879f0c30954bf168beefe3569fff08b093. It does not include the audio warning fix. No new Quartus batch or hardware deployment was started for 6688db2.

#### Next Steps:

Have the user validate EOF and layout with b05b76f seed 87, retain accepted ec56250 seed 87 as rollback, and include 6688db2 in the next hardware build to confirm startup telemetry stays absent on Fellow/Groove.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- rtl/audio/mp2_pcm_output.sv
- tools/replay_audio_startup.py
- tools/test_mp2_timestamp_tolerance.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 81 COMMIT Unreleased b05b76f 2026-09-14T10:59:57-07:00

#### Coming From:

Unreleased b5a17cf

#### Purpose:

Return completed playback to the startup state after safely draining audio and video.

#### Outcome:

Source b05b76f implements EOF-only closure; resume is dropped. Physical EOF, completed ingress, drained presentation and finished audio gate a final source-frame interval, then a generation-tagged mailbox closes the logical file through the existing safe restart path. This clears subtitle association, times, controls and startup-message suppression; pause, seek and preflight block closure, and new mounts take priority over stale completion. The 64-check EOF/session test passes for five source frame rates, longer audio, pause/seek/probe inhibition, activity restart, stale completion, simultaneous replacement and delayed host/DDR retirement. The real mixed I/P/B pipeline completes EOF with 423936 pixel comparisons and zero mismatches. Existing playback/audio, reader/session and subtitle lifecycle regressions pass. Source is pushed and clean seeds 52/61/87 are running under /tmp/eof-build.log. The preceding b5a17cf layout batch is also qualified: all seeds pass four corners and 171 CDC checks; setup is +0.508/+0.436/+0.313 ns, hold +0.113/+0.098/+0.076 ns and actual ALMs 38593/38727/38559, with unchanged 527 M10Ks and 75 DSPs. Layout-only candidates are packaged under results/hardware-test-b5a17cf, preferred seed 52; layout hardware acceptance remains pending. No core was deployed.

#### Next Steps:

Audit and package the EOF build timing/resources, then test clean completion, subtitle clearing, longer audio tails, paused EOF, seek endpoints and replacement movies at both output rates. Retain hardware-accepted ec56250 seed 87 as rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_eof_control.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_media_eof_control.sv
- tools/verify_decoder_timing.py
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 80 COMMIT Unreleased b5a17cf 2026-09-14T10:42:12-07:00

#### Coming From:

Unreleased 47630c7

#### Purpose:

Rearrange the hardware-accepted subtitle overlay around the progress bar.

#### Outcome:

The user reports everything works perfectly after the ec56250 seed 87 handoff, accepting the subtitle baseline. Source b5a17cf implements their requested layout: reference clocks y=469 below the unchanged [452,466) progress track, Paused/Seeking y=455 on the bar, and subtitle lines y=417/431, two 14-pixel lines below the previous positions. Text palette one provides dark status lettering on a light inset; rectangle palette one retains the existing subtitle backdrop alpha blend. Twelve player-frame cases and five subtitle-frame cases pass with zero pixel mismatches at 480p, 720p and 1080p, including status over empty/full/unknown progress, controls hiding and stale cue epochs. Parser, two-drive transport, pause/seek controller, retained-provider and 518 divider checks also pass. Preview, subtitle notes, test instructions and changelog are updated. Source is pushed and clean seeds 52, 61 and 87 are starting under /tmp/subtitle-layout-build.log. Subtitle parsing and playback behavior are unchanged; no new core was deployed.

#### Next Steps:

Audit completed timing and resources, package the preferred qualified RBF, then have the user confirm bottom margins, status contrast and subtitle positioning. Retain accepted ec56250 seed 87 as rollback.

#### Files Modified:

- CHANGELOG.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html
- rtl/media_overlay_compositor.sv
- rtl/media_ui_scene.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 79 COMMIT Unreleased 47630c7 2026-09-14T10:30:19-07:00

#### Coming From:

Unreleased ec56250

#### Purpose:

Qualify and package the manually loaded subtitle builds for hardware testing.

#### Outcome:

All ec56250 seeds compile and pass all four timing corners, 171 CDC registers and scene-enable checks. Seeds 52/61/87 have setup +0.116/+0.136/+0.338 ns, hold +0.115/+0.108/+0.110 ns and actual placed ALMs 37536/38678/38773. All use 527 M10Ks and 75 DSPs, adding seven RAM blocks and six DSPs and leaving 26 M10Ks free. Fitter confirms four subtitle-reader RAM blocks and two parser buffers, with the overlay hierarchy rising from 15 to 16. Estimated ALMs 33032/32933/32936 exceed baseline ffafc79 seed 87's 31987; seed 52's lower physical occupancy reflects packing rather than a functional logic reduction. Preferred seed 87 has the strongest setup margin; seed 52 is a passing lower-occupancy alternative. Hash-verified RBFs and testing notes are under results/hardware-test-ec56250, including Subtitle Test.srt. Preferred seed87/MediaPlayer_20260914.rbf SHA-256 is 765fc4eea7ec7e5a4d2701a3ac470d0f6e4dacadfaef4acd5f771b517bb59752. The audit tool now accepts a scope string instead of incorrectly describing subtitle builds as framework-only. No hardware deployment or acceptance occurred.

#### Next Steps:

Have the user test manual SRT selection, cue timing, pause and all seek sizes/directions, Off/On, file changes, controls hiding and subtitle placement at supported HDMI resolutions. Retain ffafc79 seed 87 as rollback; session resume and EOF policy remain separate release tasks.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- tools/audit_three_seeds.py

#### Status:

- [x] Built
- [ ] Passed

---

## 78 COMMIT Unreleased ec56250 2026-09-14T09:56:47-07:00

#### Coming From:

Unreleased c4b40c4

#### Purpose:

Implement manually loaded SRT subtitles through stock Main and the existing shared overlay.

#### Outcome:

Source ec56250 adds stock Main S1 mounted SRT loading and an On/Off control. A serialized drive owner isolates movie/SRT response writes through the trailing hps_io pipeline. Bounded streaming parsing retains two 63-character lines and timestamps rather than a whole-file database; headers support CRLF/LF and a final cue at EOF, tags are stripped, and non-ASCII UTF-8 codepoints use question-mark fallback. The existing font now covers all printable ASCII without enlarging its ROM. New subtitle reads yield to duration probing, seeks and low movie buffering. Acknowledged commands cross two audited configuration mailboxes into the retained shared-overlay provider, with independent visibility, dark backdrops and seek/file epochs. New movies clear association; seeks drain and rescan at the actual landing position. The user additionally requests lowering Paused/Seeking one line; status is y=417 at 480p and subtitle lines y=389/403, leaving clocks/bar unchanged. Parser, actual two-drive hps_io, asynchronous controller/command transfer, pause, Off/On, both seek directions, in-flight new-movie cancellation, reload and video-priority tests pass. Nine existing full-frame player cases and five subtitle cases at 480p/720p/1080p pass with zero mismatches, plus provider lifetime/state and 518 divider cases. Existing reader cancellation, timeout quarantine and session regressions pass; parser/controller lint is clean. Source is pushed and clean seeds 52, 61 and 87 are starting under /tmp/subtitle-build.log. Require 171 CDC audit registers. No RBF is qualified or deployed yet.

#### Next Steps:

Check synthesis RAM inference, final resources and all-corner timing for the three seeds, package the best qualified RBF and test with the generated Subtitle Test.srt plus real movie subtitles. Retain ffafc79 seed 87 as rollback; session resume and EOF policy remain separate release tasks.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- README.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/font-sheet.html
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_overlay_font.mem
- rtl/media_player_overlay.sv
- rtl/media_sd_owner.sv
- rtl/media_srt_parser.sv
- rtl/media_subtitle_cdc.sv
- rtl/media_subtitles.sv
- rtl/media_ui_scene.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/audit_three_seeds.py
- tools/make_subtitle_test.py
- tools/phase1p_timing.tcl
- tools/test_media_player_overlay.sv
- tools/test_media_srt_parser.sv
- tools/test_media_subtitle_hps_io.sv
- tools/test_media_subtitles.sv
- tools/test_media_ui_lifetime.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 77 COMMIT Unreleased c4b40c4 2026-09-14T09:51:43-07:00

#### Coming From:

Unreleased 304e4dc

#### Purpose:

Record the user's revised next-release requirements.

#### Outcome:

The user replaces the preceding playlist and automatic matching-name subtitle proposal with session-only resume from last position, predictable EOF behavior and subtitles from a separate SRT selected through a menu entry. The earlier clarification that resume lasts only while the core stays loaded remains in force. Keep stock Main; playlists, N/P playlist navigation and automatic SRT discovery are not part of this target. Audio-track selection remains excluded. The UI plan records this scope and remaining design questions for resume identity, EOF draining and bounded subtitle parsing, storage and character coverage. No RTL changes, additional builds or hardware deployment occurred; ffafc79 seed 87 remains timing-qualified but not yet explicitly hardware accepted.

#### Next Steps:

Plan and implement the revised target using existing seek, duration and shared-overlay infrastructure, validating file transitions, EOF, pause and seek subtitle synchronization before release qualification.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 76 COMMIT Unreleased 304e4dc 2026-09-14T09:45:46-07:00

#### Coming From:

Unreleased 0d13908

#### Purpose:

Record completed lowered-overlay build qualification and provide the preferred hardware candidate.

#### Outcome:

All ffafc79 seeds compile and pass four-corner timing, 159 CDC registers and scene-enable audits. Seeds 52, 61 and 87 have minimum setup +0.196, +0.224 and +0.371 ns and hold +0.097, +0.103 and +0.110 ns. Preferred seed 87 uses 37713 actual ALMs, 520 M10Ks, 69 DSPs and 47317 registers, leaving 4197 ALMs and 33 M10Ks. This is two fewer placed ALMs than 3d48cc5 seed 87, effectively unchanged resource usage. Its verified RBF is results/hardware-test-ffafc79/seed87/MediaPlayer_20260914.rbf with SHA-256 3d229f28cb7e12b0cde1f2da716754f6c307a80f94678e5668303f9896c93f0d. Per-seed testing notes and top-level instructions are ready; no deployment or hardware acceptance occurred. Subsequent user release requirements are M3U playlists with N/P navigation, automatic advance and final return to idle; session-only resume while the core stays loaded; predictable EOF; and matching-name separate SRT subtitles. Automatic filesystem access through stock Main remains unresolved. Image/package loading and manual subtitle selection were discussed as RBF-only alternatives, not approved replacements for the requested loose-file workflow. No feature implementation or shared-IDCT optimization was started.

#### Next Steps:

Have the user validate the lower bar and clock-only fields on seed 87; resolve the file-access workflow before implementing playlist and automatic subtitle loading.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 75 COMMIT Unreleased 0d13908 2026-09-14T09:25:00-07:00

#### Coming From:

Unreleased ffafc79

#### Purpose:

Remove audio-track selection from planned player scope at the user's request.

#### Outcome:

The user explicitly declines audio-track selection after its purpose is explained. The UI plan now excludes a soundtrack selector and resource reservations for track switching, retaining the other six original features. Subtitle playback remains deferred. This documentation-only change does not alter RTL, running builds or hardware. The preceding read-only shared-IDCT investigation remains under results/shared-idct-audit/findings.md; no sharing implementation is authorized by this scope decision.

#### Next Steps:

Complete the existing lowered-overlay build qualification and retain the revised feature scope for future planning.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

