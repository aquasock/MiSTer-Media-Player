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

