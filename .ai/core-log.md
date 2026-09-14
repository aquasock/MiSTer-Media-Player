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

## 74 COMMIT Unreleased ffafc79 2026-09-14T09:09:57-07:00

#### Coming From:

Unreleased 1d58018

#### Purpose:

Lower the playback progress strip by one bar height and show only clock values in its three fields.

#### Outcome:

Implemented the requested 14-reference-pixel downward shift for track, fill and three centered clocks, removing their static prefixes. Elapsed, total and remaining retain their left-to-right order; unknown fields retain dashes. Separate pause/seek status and retained auxiliary provider behavior are unchanged. Updated the preview, pixel oracle, plan, test instructions and changelog. All nine full-frame cases pass at 480p, 720p and 1080p, totaling 5414400 matching pixels, plus retained-provider lifetime, UI state and 518 enabled-divider cases. Source ffafc79 is pushed and clean seeds 52, 61 and 87 are compiling; supervisor output is /tmp/ui-lower-clocks-build.log. No hardware deployment occurred. The user's statement that everything looks good follows the encoding correction; it is not treated as explicit acceptance of a particular duration RBF.

#### Next Steps:

Audit the completed three-seed timing and resource results, package the best qualified RBF and have the user check clock centering, bottom margin, unknown times and playback controls on hardware.

#### Files Modified:

- rtl/media_ui_scene.sv
- tools/verify_player_overlay.py
- docs/ui/overlay-preview.html
- docs/UI_OVERLAY_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 73 COMMIT Unreleased 1d58018 2026-09-14T08:49:53-07:00

#### Coming From:

Unreleased 9076405

#### Purpose:

Document revised duration build qualification and reproduce the reported conversion cadence failure.

#### Outcome:

All 3d48cc5 builds completed. Seeds 61 and 87 pass all four timing corners, 159 CDC registers and scene-enable audits; seed 52 fails setup at -0.381 ns. Preferred seed 87 has setup +0.427 ns, hold +0.107 ns, 37715 actual ALMs, 520 M10Ks and 69 DSPs, leaving 4195 ALMs and 33 M10Ks. Its packaged RBF is results/hardware-test-3d48cc5/seed87/MediaPlayer_20260914.rbf with verified SHA-256 d6f66b6870113e53e46f8d229b11c90b0d0f8870e5c6cb621cc99cf1991a80e7. Hardware acceptance remains pending. Separately, full-start 68-second fellow conversion reproduces 477 dropped and 475 duplicated frames inside the fps filter; millisecond timestamps near a half-frame phase explain the failure. Removing that filter and using output -r:v 24000/1001 -fps_mode:v cfr eliminates reported synchronization drops/duplicates. Groove's corrected moving sample advances through every source frame; fellow's dark opening makes low-resolution image matching ambiguous, so no exact pixel-oracle claim is made for it. Thread count variants do not explain the failure; one encoder thread accounts for approximately 3.6 percent of 28 logical CPUs. The committed bounded reproduction tool was run successfully on fellow and reproduced both outcomes. Full movie originals remain unchanged; no hardware deployment or additional builds occurred.

#### Next Steps:

Have the user test the corrected short encoding and timing-qualified seed 87, including Groove duration and existing playback controls; retain tested b00920a seed 52 as rollback. Select encoding frame rate to match each source and keep unknown duration when bounded evidence is unavailable.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/ENCODING_CADENCE.md
- tools/reproduce_encode_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 72 COMMIT Unreleased 9076405 2026-09-14T08:31:24-07:00

#### Coming From:

Unreleased 3d48cc5

#### Purpose:

Provide the best completed duration candidate for the user's requested early hardware test.

#### Outcome:

After being informed that all 9076405 seeds fail setup, the user requests the best completed RBF to test. Seed 87 has the least negative setup at -0.184 ns and hold +0.115 ns. Its verified binary is results/hardware-test-9076405/seed87/MediaPlayer_20260914.rbf with SHA-256 d2bb095a9bd33018f0519aeb0f1c80c989de929a70536ad8fa7d75f8678d509c. Per-seed TESTING.md identifies this as timing-unqualified exploratory testing and asks the user to check Groove's approximately 01:18:25 total and remaining time, pause/seeks and file changes. The revised 3d48cc5 seeds continue compiling under results/build-3d48cc5-20260914-082959. No automatic deployment or hardware acceptance occurred.

#### Next Steps:

Review the user's early hardware results and finish corrected 3d48cc5 build qualification before recommending a timing-qualified replacement; retain tested b00920a seed 52 as rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 71 COMMIT Unreleased 3d48cc5 2026-09-14T08:14:32-07:00

#### Coming From:

Unreleased 9076405

#### Purpose:

Qualify the duration correction and remove the decimal formatter timing bottleneck.

#### Outcome:

Clean 9076405 seeds 52, 61 and 87 have passed synthesis and are fitting. Additional media checks expose an oracle limitation: ffprobe leaves the final reference picture of test_progressive_mpg.mpg untimestamped despite decoding it. Extend the test-only comparison to count decoded display frames after the last available timestamp, independently of the RTL temporal-reference arithmetic. The updated comparison confirms 30.03 seconds for both test_progressive_mpg.mpg and test_av_sync.mpg; fellow_fixed.mpg also passes its bounded-tail comparison. No RTL change or new build is needed for this test-tool correction. All three completed builds pass CDC and scene-enable audits but fail setup by -0.335, -0.295 and -0.184 ns; actual ALMs are 37721, 37686 and 37677 with unchanged 520 M10Ks and 69 DSPs. Seed 52 fails an existing scaler path; seeds 61 and 87 fail retimed combinational decimal divisions inside the UI formatter. The corrected formatter reuses the existing enabled sequential divider for decimal digit conversion, eliminating the combinational /10 and %10 networks. All 5,414,400 pixel comparisons, provider lifetime/state checks and 518 divider cases pass; the duration RTL remains unchanged from its eight successful real-file comparisons. Clean three-seed qualification follows. In response to the user font question, a standalone character sheet is generated directly from the unchanged font ROM; it contains 54 visible glyphs.

#### Next Steps:

Complete corrected build qualification, then record the preferred RBF hash, resources and hardware instructions without changing the MiSTer automatically.

#### Files Modified:

- MediaPlayer.sdc
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/font-sheet.html
- rtl/media_ui_scene.sv
- tools/make_font_sheet.py
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 70 COMMIT Unreleased 9076405 2026-09-14T08:02:17-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Recover bounded duration for sparse-timestamp progressive program streams.

#### Outcome:

The user clarified that loading must remain fast and unknown duration is acceptable when bounded evidence is insufficient. The corrected observer uses progressive picture temporal references to reconstruct timestamps within anchored groups, unwrap reference-picture indices across modulo-1024 transitions and position B-pictures before their future reference. Late B-picture timestamps can backfill an earlier-coded reference endpoint, and anchored group endpoints carry into following unannotated groups. One serial multiplier computes offsets without DSPs. Conflicting anchors beyond one 90 kHz tick, unsupported/mixed rates, malformed endpoints and genuinely unanchored windows remain unknown. Existing byte budgets, reader ownership and watchdog are unchanged. All 32 synthetic cases, shared-reader remount/error/timeout and above-4-GiB tests, and Verilator lint pass. Exact bounded head/tail comparisons against independently decoded frames pass Groove, Star Wars LOWER, Pee Strike and fellow; Groove differs by three quarter-ticks, the other endpoints match exactly. Evidence is under results/ui-duration-sparse. No hardware deployment occurred.

#### Next Steps:

Build clean seeds 52, 61 and 87, audit all four corners and 159 CDC registers plus scene enable, compare incremental resources with tested b00920a seed 52 and package the best qualified candidate.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_timeline.sv
- rtl/media_duration_window.sv
- tools/test_media_duration_window.sv
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 69 COMMIT Unreleased b00920a 2026-09-14T07:58:54-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Record successful playback-control tests and explain Groove's unknown duration.

#### Outcome:

The user confirms pause/resume, forward/backward seeking and ten-second overlay hiding including while paused all work properly. Groove.mpg on the GIT HDD shows dashes for Total and Remaining. Exact 64 KiB head and 4 MiB tail replay through the current duration-window RTL reproduces the fallback: head origin 48754, healthy matching stream 224, no parser or syntax error, complete final packet boundary, but unqualified_tail remains set because a picture after the maximum observed presentation timestamp has no independently associated PTS. A later timestamped reordered picture does not exceed that maximum and cannot clear this conservative guard. This is expected behavior of the current probe, not evidence that the file cannot play; ffprobe obtains a duration using its broader stream analysis. Evidence is retained under results/ui-overlay/groove-duration. No RTL, RBF or media changes were made; overall acceptance remains pending while testing continues.

#### Next Steps:

Continue user hardware testing and retain the conservative unknown-duration behavior unless a separate improvement to timestamp association and endpoint qualification is requested.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 68 COMMIT Unreleased b00920a 2026-09-14T07:53:13-07:00

#### Coming From:

Unreleased aa8d067

#### Purpose:

Record the first successful hardware playback and time-field test of the shared overlay.

#### Outcome:

The user is testing the supplied overlay core and reports that Star Wars - EPISODE IV - A New Hope - Despecialized - LOWER.mpg from the GIT HDD works perfectly and the time fields update properly. This records a successful file-specific hardware test of the supplied b00920a seed 52 candidate. The user has not yet reported completion of the remaining pause/seek, unknown-duration, file-switch and HDMI-mode checks; overall candidate acceptance remains pending. No source or binary changes were made.

#### Next Steps:

Continue the current hardware test, especially pause/resume and seeking with time-field updates, automatic hiding, OSD/filter coexistence and switching files without retaining the previous duration.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 67 COMMIT Unreleased aa8d067 2026-09-14T07:41:06-07:00

#### Coming From:

Unreleased 9f16364

#### Purpose:

Document and package the timing-qualified shared-overlay hardware candidate.

#### Outcome:

Clean b00920a seeds 52, 61 and 87 all pass four-corner setup, hold, recovery, removal and pulse-width timing, 159 preserved CDC registers and the corrected scene-enable audit from 9f16364. Minimum setup is +0.135, +0.100 and +0.028 ns; minimum hold is +0.096, +0.069 and +0.111 ns. Actual placed ALMs are 37450, 37424 and 37503, with 520 M10Ks, 69 DSPs and three PLLs. All meet the initial incremental budget. Preferred seed 52 is packaged at results/hardware-test-b00920a/seed52/MediaPlayer_20260914.rbf with SHA-256 bf7e9aff272e5f819e16358dba90d2d05e18b9ca78436df6e3cd204e1d520973, per-seed build metadata, README and TESTING instructions. It leaves 4460 actual ALMs and 33 M10Ks free. Documentation distinguishes estimated logic from actual placement and audit-tool revision from unchanged binary source. Hardware-accepted 3ff27c8 seed 52 remains rollback. No deployment or hardware acceptance occurred.

#### Next Steps:

Have the user test duration, progress, pause/seek feedback and OSD/filter coexistence at the supported HDMI modes.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md

#### Status:

- [x] Built
- [ ] Passed

---

## 66 COMMIT Unreleased 9f16364 2026-09-14T07:38:35-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Qualify the completed overlay builds with an audit that recognizes fitted counter duplicates.

#### Outcome:

All three b00920a seeds compile successfully, using 37450, 37424 and 37503 actual placed ALMs for seeds 52, 61 and 87, with 520 M10Ks and 69 DSPs. These meet the initial incremental resource budgets. The new scene-enable audit stops before all-corner reporting because its two-register wildcard also returns routing duplicates. A direct fitted-netlist query confirms the two original scene_phase bits and one duplicate of each, plus 1144 scoped formatter registers. Audit revision 9f16364 requires both original bits, accepts only explicitly named routing copies and reports those separately. RTL, timing constraints and fitted binaries are unchanged. Qualification is rerunning on the existing archives; status.json records the original audit failure and the new audit-tool revision separately from the RBF source. Hardware acceptance remains pending.

#### Next Steps:

Complete all-corner and CDC qualification, package the best passing seed and update hardware instructions with measured resources, timing and its exact RBF hash.

#### Files Modified:

- tools/phase1p_timing.tcl

#### Status:

- [x] Built
- [ ] Passed

---

## 65 COMMIT Unreleased b00920a 2026-09-14T07:02:57-07:00

#### Coming From:

Unreleased 287cf6b

#### Purpose:

Remove the remaining identified pixel-path arithmetic bottlenecks before final overlay qualification.

#### Outcome:

Additional isolated timing analysis of fitted 5373dae finds the unchanged alpha blend also fails by -6.017 ns, independent of coordinate divisions and scene formatting. The 287cf6b batch passes synthesis but is stopped early during fitting to avoid completing another known-incomplete timing fix. Its status and cancellation reason are retained under results/build-287cf6b-20260914-065802. Replace the fixed dark-palette blend with synchronous byte lookup tables and pipeline the bounds, object selection and coordinate subtraction separately. These corrections preserve the approved pixels and shared provider design while using the reserved RAM budget; existing 287cf6b duration guards, coordinate/staging RAM and enabled formatter remain the basis. The completed correction uses ten aligned pixel registers, separately registered axis comparisons and qualification, precomputed object enables and ROM palette blending. Exact-width binary font and coordinate ROMs avoid padded storage. The isolated 148.5 MHz compositor fit passes all reported corners and shows +0.861 ns setup and +0.381 ns hold on the detailed default-model internal-register reports, with 12 M10Ks and no DSPs; this is not full-core qualification. All 5,414,400 full-frame pixel comparisons, varying-color alpha checks, lifetime/state tests and 518 enabled divider cases pass. ROM regeneration is exact. No hardware deployment or acceptance occurred.

#### Next Steps:

Run clean full-core seeds 52, 61 and 87 from b00920a. Require all-corner timing, 159 CDC registers and the real four-clock scene-enable audit, then measure actual resource usage before packaging a candidate.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_overlay_blend_b.hex
- rtl/media_overlay_blend_rg.hex
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_coordinates.hex
- rtl/media_overlay_coordinates.mem
- rtl/media_overlay_font.hex
- rtl/media_overlay_font.mem
- tools/make_overlay_roms.py
- tools/test_media_player_overlay.sv
- tools/verify_overlay_timing.py
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 64 COMMIT Unreleased 287cf6b 2026-09-14T06:34:44-07:00

#### Coming From:

Unreleased 5373dae

#### Purpose:

Tighten duration qualification and correct any measured implementation issues before delivering the shared overlay.

#### Outcome:

Initial 5373dae seeds all compile and pass the 159-register CDC audit but fail all-corner HDMI setup at minimum -14.139, -13.905 and -13.197 ns for 52, 61 and 87. Actual placed ALMs are 38206, 38125 and 38228, exceeding the initial 2000-ALM incremental budget by 432, 351 and 454; RAM totals 510 M10Ks and DSPs 81. Evidence and explicitly failed handoffs are under results/build-5373dae-20260914-062804 and results/hardware-test-5373dae. Critical paths are cascaded pixel-coordinate divisions and formatter arithmetic. Corrected source 287cf6b uses a synchronous coordinate ROM, RAM staging descriptors copied during vertical blanking, six-stage aligned RGB/sync processing, one serialized layout/progress multiplier and a split restoring divider. Scene construction advances on a real modulo-four HDMI clock enable; narrowly scoped multicycle constraints cover only registers sharing that enable, while snapshot inputs, provider writes, publication and pixel logic remain single-cycle. A pending latch retains short compositor acknowledgements. Duration guards reject malformed head evidence and differing selected video-stream IDs between windows; an adversarial test first demonstrates the missing guard then passes with the correction. Full 4.7-million-pixel overlay oracles, independent visibility and retained-provider lifetime tests, 518 wide divider cases, ROM regeneration checks, bounded reader/remount/timeout recovery, real-file duration comparison and existing program-stream ingress tests pass. TimeQuest accepts the scoped constraint syntax; new fitted enable-counter and register-set audits are required. Clean corrected seeds 52, 61 and 87 are now compiling. No candidate was deployed or hardware accepted.

#### Next Steps:

Audit corrected builds across all corners, the 159 CDC registers and real four-clock enable endpoints, then measure actual placed ALMs and M10Ks against the initial budgets. Resolve any remaining failures before recommending an RBF. Package the best qualified seed with hardware test instructions, retaining accepted 3ff27c8 seed 52 as rollback.

#### Files Modified:

- MediaPlayer.sdc
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_probe.sv
- rtl/media_duration_window.sv
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_coordinates.hex
- rtl/media_player_overlay.sv
- rtl/media_ui_divider.sv
- rtl/media_ui_scene.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- tools/audit_three_seeds.py
- tools/make_overlay_roms.py
- tools/phase1p_timing.tcl
- tools/test_media_duration_reader.sv
- tools/test_media_player_overlay.sv
- tools/test_media_ui_divider.sv
- tools/test_media_ui_lifetime.sv
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 63 COMMIT Unreleased 5373dae 2026-09-14T06:07:40-07:00

#### Coming From:

Unreleased ea05269

#### Purpose:

Implement the approved shared playback overlay and bounded timestamp duration probe for hardware validation.

#### Outcome:

Source 5373dae implements the shared post-filter, pre-menu HDMI compositor with eight bounded text objects, four rectangles, synchronous glyph/text RAM, five-stage aligned RGB and sync delay, frame-boundary publication and stale session/seek epoch rejection. A retained synthetic-provider interface reserves future text functionality without subtitle loading or cue selection. The controls reproduce the historical progress bar and Elapsed, Total and Remaining fields, pause/seek feedback, independent ten-second wall-clock hiding and explicit unknown duration. A bounded 64 KiB head and 4 MiB tail preflight reuses the existing mounted reader RAM, validates PES timestamps, retains the maximum presentation PTS plus the frame period, and quarantines outstanding responses on cancellation or timeout. Reader integration testing caught and fixed a FINISH-state validity gate; the complete encoded sample now matches the independently calculated endpoint. Full-frame pixel oracles pass at 480p, 720p and 1080p, including unknown/hidden controls and progress endpoints. Scene lifetime, retained-provider, epoch, wall-clock, reordered/wrapped timestamp, large-file reader, remount, malformed response and timeout recovery tests pass. Existing transport/session, decoder pixel and real-file direct-seek regressions pass. Evidence is under results/ui-overlay. Resource and timing qualification remain pending; standard clean seeds 52, 61 and 87 are now compiling. No deployment occurred.

#### Next Steps:

Audit all four timing corners, 159 expected CDC synchronizer registers and actual placed ALMs versus the accepted 35774-ALM baseline; compare M10Ks with 508 baseline and the planned 2000-ALM/12-M10K incremental budgets. Correct any new synthesis or timing failures, package the best qualified RBF and have the user validate startup preflight, fields, pause/seek, menu/filter priority, file changes and EOF. Keep accepted 3ff27c8 seed 52 as rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_probe.sv
- rtl/media_duration_window.sv
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_font.hex
- rtl/media_player_overlay.sv
- rtl/media_ui_divider.sv
- rtl/media_ui_scene.sv
- rtl/media_ui_state.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_media_duration_reader.sv
- tools/test_media_duration_window.sv
- tools/test_media_player_overlay.sv
- tools/test_media_ui_lifetime.sv
- tools/test_media_ui_state.sv
- tools/verify_player_overlay.py
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 62 COMMIT Unreleased ea05269 2026-09-14T05:41:58-07:00

#### Coming From:

Unreleased 3ff27c8

#### Purpose:

Design one playback overlay for progress and timing fields with a shared rendering framework for future subtitles.

#### Outcome:

The user requested bundling wishlist items 1, 2 and 7 into one UI layer while explicitly excluding subtitle implementation from the first build. Historical af7f570 audio_ui.c and media_player_helper.c supply the reference: Elapsed left, Total center, Remaining right in HH:MM:SS at y422 above the x32/y438/656-by-14 bar, muted blue-gray track and pale fill/text from the final video-overlay palette. The old font lacks lowercase despite mixed-case labels, so the preview adds readable lowercase in the same pixel style. Design commit ea05269 adds docs/UI_OVERLAY_PLAN.md and an interactive local HTML preview covering aspect, output size, pause/seek, unknown duration and a future subtitle-region guide. Its JavaScript executes across three output sizes and three picture aspects with a mocked DOM/canvas; this is not browser pixel validation. The proposed compositor sits after HDMI scaling/filters/shadow mask and before the existing MiSTer menu, with small text/glyph storage, frame-atomic scene publication, independent controls/subtitle visibility and no decoder-bank ownership or playback backpressure. The user selected a bounded timestamp probe with unknown total/remaining when unavailable; byte-ratio duration estimation is excluded. The plan covers head/tail probes, reordered PTS, endpoint qualification, large-file offsets, response retirement and session invalidation. Initial implementation budgets are 2000 additional actual ALMs and 12 M10Ks, not measured costs. No RTL, duration probe, subtitle parser, HDMI mode change or RBF was implemented; hardware-accepted runtime baseline remains 3ff27c8 seed 52. This commit completes design artifacts only.

#### Next Steps:

Use the documented design as the implementation boundary for the shared overlay, progress/time fields and duration probe, retaining existing controls and standard HDMI timing/frequency requirements. Before compilation require renderer, asynchronous scene-publication, duration-probe/late-response and existing decoder/seek regressions, then the standard three-seed timing/resource audit. Subtitle loading, decoding and cue selection remain deferred. No builds are running.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html

#### Status:

- [ ] Built
- [ ] Passed

---

## 61 COMMIT Unreleased 3ff27c8 2026-09-14T05:13:13-07:00

#### Coming From:

Unreleased 3ff27c8

#### Purpose:

Record hardware acceptance of the IDCT intermediate RAM conversion as the new baseline.

#### Outcome:

The user reports everything works perfectly with the recommended 3ff27c8 seed 52 candidate. Passed records that user-reported hardware acceptance; detailed file and control coverage was not enumerated. The accepted RBF remains results/hardware-test-3ff27c8/seed52/MediaPlayer_20260914.rbf with verified SHA-256 236c9817ccfd04b10e23ff0ee052f2c11e5a39d7fcfdb88e3e42b29e969406f1. Its handoff metadata and README now record acceptance, and documentation commit e76bc84 updates the changelog and test instructions. This establishes the 35774 actual placed ALM, 508 M10K, 69 DSP seed 52 build as the current accepted baseline, with 45 M10Ks free. Runtime RTL is unchanged and no builds or deployment were performed. The requirement for standard HDMI timings and frequencies remains in force for future film-cadence work.

#### Next Steps:

Use 3ff27c8 seed 52 as the baseline for subsequent changes and retain dc1dfc2 seed 52 as the previous rollback. Investigate stock Main and scaler support for standard 23.976/24 Hz HDMI timing modes before proposing any film-cadence implementation; do not infer authorization for another implementation or build from this acceptance report.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---

## 60 COMMIT Unreleased 3ff27c8 2026-09-14T05:09:29-07:00

#### Coming From:

Unreleased 3ff27c8

#### Purpose:

Qualify and deliver the IDCT intermediate RAM conversion hardware candidate.

#### Outcome:

All three clean 3ff27c8 builds finish; seeds 52 and 87 pass all four timing corners, while seed 61 fails setup at -0.152 ns in the slow -40C corner. All pass the 153-register CDC audit. Seeds 52 and 87 have minimum setup/hold +0.133/+0.110 and +0.067/+0.074 ns. Actual placed ALMs are 35774, 35923 and 35876 for seeds 52, 61 and 87, versus estimates 29791, 29693 and 29634; all use 508 M10Ks, 69 DSPs and three PLLs. Each fitter report confirms 24 distinct physical intermediate M10K sites despite requested type AUTO in its RAM table. Preferred seed 52 saves 2016 actually placed ALMs versus accepted dc1dfc2 seed 52, reducing placement from 90.2 to 85.4 percent; estimated utilization drops from 76.2 to 71.1 percent. RAM rises by 24 blocks and leaves 45 free; registers total 43508. Synthesis IDCT instances remove 4608 registers and 1382 combinational ALUTs with unchanged arithmetic and output cycles. Full validation evidence is under results/idct-storage and results/build-3ff27c8-20260914-045213. Hash-verified handoffs are under results/hardware-test-3ff27c8, with seed 61 visibly marked timing-failed. Preferred seed52/MediaPlayer_20260914.rbf SHA-256 is 236c9817ccfd04b10e23ff0ee052f2c11e5a39d7fcfdb88e3e42b29e969406f1. Documentation commit 863e254 records the candidate. No hardware acceptance or deployment occurred. While builds ran, the user requested better film cadence and clarified that only standard HDMI timings and refresh frequencies are acceptable. Exact 24 and 23.976 fps need consideration separately; 50 and 59.94 Hz cannot evenly repeat either. Standard 1080p23.976/24 is an investigation candidate, subject to stock Main/scaler and display compatibility verification; no new refresh mode was implemented.

#### Next Steps:

Have the user validate seed 52 playback at both existing refresh rates, OSD/aspect/filters, repeated short and long seeks both directions, paused seeks, reload and EOF, retaining accepted dc1dfc2 seed 52 as rollback. For future film cadence work, verify complete standardized HDMI timing modes including blanking, sync and pixel clock through stock Main before proposing an implementation. No additional builds are running.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 59 COMMIT Unreleased 3ff27c8 2026-09-14T04:48:02-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Move IDCT intermediate storage into banked M10K memory while preserving transform arithmetic and cycle behavior.

#### Outcome:

Source 3ff27c8 moves the intermediate array of all three IDCT instances into eight synchronous 8-by-24 M10K row banks per instance, leaving coefficients and arithmetic unchanged. Column-ahead prefetch preserves all external output cycles against dc1dfc2 in a differential test covering signed impulses, dense extremes, 512 random sparse blocks, 133 reset offsets, simultaneous input controls and overlap errors. The test compares 164020 cycles and observes 783 completed blocks and 52128 samples including aborted transforms. The mixed I/P/B pixel oracle passes 423936 comparisons with zero mismatches within its allowed numerical tolerance and passes paused seeks with display ownership. Exact Pee Strike direct restart through shared DDR passes at cycle 40027997 with elapsed_q 3663660, matching the baseline recovery point. Evidence is under results/idct-storage. Tested source was committed and pushed before clean seeds 52, 61 and 87 started under results/build-3ff27c8-20260914-045213 with six workers each. No new RBF or measured resource saving is available yet; hardware-accepted dc1dfc2 seed 52 is retained.

#### Next Steps:

Finish all three builds and verify 24 intermediate banks infer M10K. Compare actual placed ALMs and total RAM blocks with dc1dfc2, require all timing corners and the 153-register CDC audit, then package the preferred passing candidate for hardware playback and seek validation. Do not deploy automatically.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_idct.sv
- tools/test_idct_storage.sv
- tools/verify_idct_storage.py
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 58 COMMIT Unreleased dc1dfc2 2026-09-14T04:41:39-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Record hardware acceptance and investigate optimization techniques in the original upstream decoder.

#### Outcome:

The user reports everything works perfectly like before with the delivered dc1dfc2 seed 52 row-buffer candidate. Passed records that reported playback acceptance; detailed file/key/EOF coverage was not enumerated. Its build-info now records hardware acceptance. The user requested comparison with mrchrisster/MiSTer_MPEG2; upstream main was pinned to 11d1aa2d11649d0c4048d1b33fb1d2abc84771ef and inspected from a read-only clone. Active local files.qip selects mpeg2_new, while upstream idct.v is byte-identical to the dormant local mpeg2fpga IDCT. Useful adaptation candidates are upstream's RAM-backed transpose storage and shared streamed transform pipeline. Current three active IDCT instances total 4196 combinational ALUTs, 7971 registers and 24 DSP blocks with no block memory; this is total module cost, not forecast savings. Their eight parallel reads mean RAM banking or prefetch needs design work, and upstream's two-RAM count cannot be copied as a local budget. The current intra inverse quantizer also holds qfs/reconstructed arrays in registers and totals 1073 combinational ALUTs, 1776 registers and six DSP blocks; a RAM-backed or streamed adaptation is another candidate. A shared IDCT would require overlap/throughput and seek-ownership proof. Upstream VLC tables are combinational too, so no ready-made ROM saving was found. Different transform widths, rounding and output clipping prevent claiming a drop-in replacement; current audio, PTS and seek behavior must remain. Findings and source references are saved in results/upstream-optimization-audit/findings.md. No source optimization, build or deployment was performed.

#### Next Steps:

Present the bounded opportunities and select an approved optimization boundary before implementation. Prefer retaining current transform arithmetic while redesigning storage, or first converting the simpler inverse-quantizer buffers; require numerical equivalence, pixel-oracle and seek recovery tests, then measured RAM/ALM and timing qualification. Retain accepted dc1dfc2 seed 52 as baseline.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 57 COMMIT Unreleased dc1dfc2 2026-09-14T04:33:57-07:00

#### Coming From:

Unreleased dc1dfc2

#### Purpose:

Qualify the row-buffer RAM builds and deliver the preferred seed 52 candidate.

#### Outcome:

All three clean dc1dfc2 seeds pass all four timing corners and the 153-register CDC audit, with both 512-by-8 row arrays confirmed as M10K in each synthesis report. Seeds 52, 61 and 87 have minimum setup +0.437, +0.322 and +0.303 ns and hold +0.089, +0.086 and +0.091 ns respectively; recovery, removal and pulse width also pass. Their actual placed ALMs are 37790, 37813 and 37878, while ALMs-needed estimates are 31925, 31938 and 31904; do not conflate these metrics. All use 484 RAM blocks, 69 DSP blocks and three PLLs. Preferred seed 52 uses 48362 registers and reduces actual placed ALMs by 3355 against accepted bcddb20 seed 61, at a cost of two additional M10K blocks; the intervening audio-menu removal is included. Estimated utilization is 76.2 percent while actual placement is 90.2 percent. Total compile/audit durations are 901.1, 905.0 and 889.6 seconds. Hash-verified handoffs and instructions are under results/hardware-test-dc1dfc2; preferred seed52/MediaPlayer_20260914.rbf has SHA-256 7eb9a5bebc66423885d5865a40dc55ab24f28d3ff6f4743f05c3ebd394358ce6. Documentation commit 29a54d3 identifies the candidate; runtime source remains dc1dfc2. No hardware acceptance, deployment or further build was performed.

#### Next Steps:

Have the user test seed 52 for normal playback, repeated short/long seeks both directions, paused seeks/resume, reload and EOF, confirming clean video, synchronized audio and removal of the diagnostic audio menu. Preserve accepted bcddb20 seed 61 as rollback and leave additional RAM conversions unstarted until requested.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 56 COMMIT Unreleased dc1dfc2 2026-09-14T04:11:41-07:00

#### Coming From:

Unreleased 1349c82

#### Purpose:

Restore the P and B parser row-buffer block-memory conversion to recover logic capacity.

#### Outcome:

Source dc1dfc2 restores the seven-file historical 047f5b2 conversion to current progressive RTL. Both 512-byte row arrays use synchronous M10K reads, one-byte-ahead prefetch and shadow head/tail bytes so the two-byte rollover needs no extra RAM write port or combinational read. Five supported differential parser/transport cases pass against baseline 1349c82 with identical RESULT lines and reported cycle counts: P/B intra, B residual streaming, eight P and eight B window refills, and abort recovery. A new strict runner rejects failed baselines and isolates legacy generator output; two historical dense-stream fixture/test pairings were found to fail unchanged baseline count assertions and are explicitly excluded rather than counting matching failures as success. Current full I/P/B reconstruction with display ownership and repeated paused seeks passes 423936 pixel comparisons with zero mismatches; actual Pee Strike direct restart at the ten-second target resumes audio and video with shared DDR and no reported errors. These models use ideal bounded queues and do not prove vendor RAM inference or physical timing. Evidence is under results/row-buffer. The source was committed and pushed before clean seeds 52, 61 and 87 started at 2026-09-14T04:17:03-07:00 with six workers each under results/build-dc1dfc2-20260914-041703. Packing remains MEDIUM and menu-ROM storage is unchanged. The result checker requires 153 CDC registers and separately reports actual placed ALMs. No RBF is ready yet, no current savings are claimed and the MiSTer was not changed.

#### Next Steps:

Finish the three builds, confirm both row arrays infer M10K, compare actual placed ALMs and RAM usage with bcddb20 while noting the included audio-menu removal, and audit every timing corner plus 153 CDC registers. Package the best candidate for user validation of playback and repeated forward/backward seeks, keeping the hardware-accepted bcddb20 seed 61 as rollback.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/verify_row_buffer_equivalence.py
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 55 COMMIT Unreleased 1349c82 2026-09-14T04:07:41-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Remove the diagnostic seek-audio menu switch while retaining normal compressed-audio bypass.

#### Outcome:

The user authorized removing the Seek audio bypass menu entry during a read-only historical RAM optimization audit. Source 1349c82 removes the option and its one-bit CDC mailbox, connects MP2 seeking directly to media_seeking and removes the obsolete mailbox from the timing audit, reducing required synchronizer checks from 159 to 153. The existing bypass algorithm and full-frame synthesis preroll are preserved; saved status bit seven no longer affects behavior. MP2 quantizer and joint-stereo tests pass exact resumed PCM comparisons across two reset sessions, normal and wrapped timestamps, and one-byte, 582-byte and false-header 1604-byte startup prefixes. Evidence is under results/menu-removal. No builds or hardware changes were made. Separately, Git history confirms that progressive restoration 9233f07 lost the 047f5b2 parser row-buffer BRAM conversion and 6e44472 configuration-ROM BRAM enable. Current P and B row_bytes arrays are each 512 by 8 with combinational reads, and CONF_STR_BRAM defaults to zero. Historical entry 420 records 7082 fewer estimated ALMs and two additional RAM blocks for the row-buffer conversion, followed by hardware acceptance in entry 422; those historical savings are not a current-build prediction. Large residual plans and shared residual storage already use M10K. The attempted 19-to-20-bit coefficient padding in 5fb7d5d saved nothing because synthesis removed the unused bit and was reverted by 3e89189. No RAM conversion is authorized or implemented in this menu-removal boundary.

#### Next Steps:

Menu removal is ready for the next build; adapt future build summaries to 153 CDC checks. Recommend porting the historical row-buffer conversion with differential parser and current seeking tests, followed by the smaller configuration-ROM change, as the next resource-recovery work.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_av.svh
- tools/phase1p_timing.tcl
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 54 COMMIT Unreleased bcddb20 2026-09-14T03:59:43-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record the completed seed 61 maximum-packing comparison.

#### Outcome:

The single HIGH-packing bcddb20 seed 61 experiment compiled and passes all four timing corners and the 159-register CDC audit. Minimum setup is +0.028 ns, hold +0.111 ns, recovery +2.751 ns, removal +0.112 ns and pulse width +0.925 ns. It places 41230 ALMs versus 41145 in the original MEDIUM seed 61, an increase of 85; ALMs-needed estimates are 41329 versus 41223. Registers are 56346 versus 56345, with 482 RAM blocks, 69 DSPs and three PLLs unchanged. HIGH therefore offers no area benefit and less setup margin than the original +0.205 ns candidate. Compile took 1145 seconds and compile plus audit 1226.7 seconds versus 1424.1 seconds for the original; HIGH ran alone while the original ran alongside two seeds, so elapsed time does not isolate packing effort. The separate experimental RBF at results/hardware-test-bcddb20-packing-high/seed61/MediaPlayer_20260914.rbf is hash verified as 4cd4eadd5ee8a3eef1ed11158d8d3157d2002cc47389d5e47e43971681f0fa82. Comparison JSON, exact settings diff and timing evidence are retained under results/build-bcddb20-packing-high-20260914-033800. No source settings, baseline RBF or MiSTer state were changed, and no additional builds were started. Built refers to the successful HIGH experiment; Passed remains unchecked because hardware acceptance applies only to the original MEDIUM candidate.

#### Next Steps:

Retain the user's hardware-accepted MEDIUM seed 61 as preferred and leave production packing effort unchanged. Any further area reduction should be separately planned from resource evidence rather than assuming HIGH packing reduces occupied logic.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 53 COMMIT Unreleased bcddb20 2026-09-14T03:41:24-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record hardware acceptance of the direct-seek seed 61 candidate.

#### Outcome:

The user reports that the core works well and seeking is rock solid and decently fast with the delivered bcddb20 seed 61 candidate. Passed records this reported playback/seek acceptance, not an independently enumerated matrix of files, keys or EOF cases. Its local build-info now records that scope. The separate maximum-packing experiment remains independent and is not accepted by this feedback. The user also asked what lies behind the black seek display: media_seeking holds the framebuffer reader/cache in reset, which forces RGB black while raster timing continues. Probe passes scan container/video headers without codec reconstruction; after selecting a restart point, the decoder reconstructs the short lead-in and reuses released frame banks. There is no intact live picture under an overlay; removing reset/blanking alone would expose invalid or changing data and can interfere with the display-bank release that fixed seeking. No playback source or hardware state was changed.

#### Next Steps:

Answer the seek-blanking question and finish the separately authorized single-seed packing experiment, comparing placed ALMs and timing against this accepted baseline. Any request to retain the last image or show seek previews requires a separate design preserving safe frame-bank ownership.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 52 COMMIT Unreleased bcddb20 2026-09-14T03:38:42-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Compare maximum ALM register packing effort against the timing-passing seed 61 build.

#### Outcome:

While testing the core, the user authorized exactly one additional build of passing seed 61 at maximum packing effort. A clean bcddb20 export started at 2026-09-14T03:38:00-07:00 under results/build-bcddb20-packing-high-20260914-033800. ALM_REGISTER_PACKING_EFFORT changes from MEDIUM to HIGH, the highest documented level; source, seed, six-worker count and all other effective QSF settings match the passing seed 61 baseline. The exact QSF comparison is asserted and saved as settings.diff alongside experiment.json and the single-seed runner. The runner compiles then runs the existing timing audit. Its result checker processes seed 61 only, requires 159 CDC registers and packages to a separate hardware-test-bcddb20-packing-high directory so the user's current candidate remains intact. Local master and GitHub were verified synchronized. No source settings or MiSTer state were changed, and no other seeds were launched.

#### Next Steps:

Finish this single build and compare actual placed ALMs separately from ALMs-needed and dense-packing estimates, plus registers, RAM, DSPs, all timing corners and the 159-register CDC audit. Report any savings and timing tradeoff; do not select the experiment over the existing candidate without evaluating both. Hardware feedback for the original bcddb20 seed 61 remains pending.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 51 COMMIT Unreleased bcddb20 2026-09-14T03:36:49-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record completed direct-seek timing qualification and deliver the preferred seed 61 candidate.

#### Outcome:

All three bcddb20 builds compiled and passed the 159-register CDC audit. Seed 61 passes all four timing corners with minimum setup +0.205 ns, hold +0.066 ns, recovery +2.388 ns, removal +0.098 ns and pulse width +0.925 ns. It uses 41223 ALMs, 56345 registers, 482 RAM blocks, 69 DSP blocks and three PLLs. The preferred RBF is results/hardware-test-bcddb20/seed61/MediaPlayer_20260914.rbf, hash verified as 98a3957e92ffb71112a31d373082854673a45c97fb5c5169c2b48971e75a2f24. Seeds 52 and 87 fail setup at -0.377 and -0.327 ns respectively; their other timing categories pass, and their packaged files are explicitly unqualified. Batch durations were 1294, 1424 and 1254 seconds for seeds 52, 61 and 87. Per-corner evidence remains under results/build-bcddb20-20260914-031001; the handoff includes checksums, build-info files and testing instructions. Documentation commit d3f141e identifies the candidate and corrects the remaining stale reference to the removed seek-fault observer; runtime source remains bcddb20. The earlier 90 percent baseline was an ALMs-needed estimate: 0b6eb0e seed 87 physically placed 40431 ALMs, versus 41119 in bcddb20 seed 87, a 688-ALM increase across playback/seek development. Most of the apparent percentage jump came from changed dense-packing recovery estimates. No new build or deployment was started.

#### Next Steps:

Have the user load seed 61 and test short and long direct seeks in both directions, paused seeks and resume, first-time distant destinations, EOF, reload, OSD access and audio alignment. Hardware acceptance remains pending; retain a229a01 seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 50 COMMIT Unreleased bcddb20 2026-09-14T03:10:33-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Build the telemetry-reduced direct-seek core with three placement seeds.

#### Outcome:

The user authorized the next build batch. Local master and GitHub were verified synchronized, and clean exports of source bcddb20 started at 2026-09-14T03:10:01-07:00 with seeds 52, 61 and 87 and six workers each under results/build-bcddb20-20260914-031001. Only seed and worker settings differ from committed source. The per-batch result checker now requires 159 CDC registers and identifies bcddb20 as its source, with all four timing corners still mandatory. Compilation is running; no new RBF or measured resource savings are available yet. The MiSTer remains unchanged.

#### Next Steps:

Finish the authorized batch, inspect resource fit and all timing classes, and package the best completed RBF with source, seed, checksum and qualification status. Retain the prior a229a01 seed 87 rollback and let the user load and validate the selected new build.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 49 COMMIT Unreleased bcddb20 2026-09-14T03:08:16-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Remove the added seek-fault telemetry hardware to recover placement capacity.

#### Outcome:

Source bcddb20 removes production instantiation of the persistent seek-fault observer, its 449-bit clock-domain mailbox and screen renderer, connects RGB directly to the retained cadence output, and removes the observer file from the Quartus project. Those three removed instances accounted for 712 combinational ALUTs and 1291 registers in the previous seed 87 synthesis hierarchy; these are attribution figures, not measured new fitted savings. Compact playback-health telemetry, audio comparison controls and playback/seek control signals remain. Standalone historical observer RTL/tests and screenshot decoding remain available outside the production project. The timing audit removes only the deleted mailbox and now requires 159 synchronizer registers instead of 165. Current testing instructions distinguish historical seek snapshots from current production behavior. Compact/detailed retained-field equivalence, actual RGB screenshot decoding, corruption rejection and legacy schemas pass. Direct-seek observer, VBR/bounded search, open-GOP byte filtering and asynchronous paused forward/backward restart regressions also pass. Evidence is under results/telemetry-removal. No Quartus build or hardware deployment was performed.

#### Next Steps:

Build source bcddb20 when authorized, measure actual fit and resource savings, and require all timing corners plus the 159-register CDC audit before selecting a hardware candidate. The old build-summary helper requires 165 checks and must be adapted for this source. Preserve a229a01 seed 87 as the timing-qualified rollback.

#### Files Modified:

- MediaPlayer_top_07.svh
- files.qip
- tools/phase1p_timing.tcl
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 48 COMMIT Unreleased 3ab6615 2026-09-14T03:06:59-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Record the completed reduced-source placement results and remaining device-capacity shortfall.

#### Outcome:

All three source 3ab6615 builds failed fitter LAB capacity and produced no RBF. Seeds 52, 61 and 87 required 4196, 4209 and 4192 LABs respectively against 4191 available, leaving seed 87 one LAB over capacity. The partial fitter ALM estimates were 41561, 41708 and 41542; these are incomplete-fit figures, not successful placement or timing qualification. Seed 87 synthesis confirms the observer dropped from 429 to 314 registers and 77 to 74 combinational ALUTs, while search logic dropped from 487 to 417 ALUTs with 332 registers unchanged. Thus the two edited modules saved 115 registers and 73 combinational ALUTs. The previous seed 87 required 4198 LABs; the reduction helped packing but did not yield a legal fit. Timing and fitted CDC qualification could not run. Evidence and failure-summary.json are under results/build-3ab6615-20260914-025405. No further builds were launched and the MiSTer was not changed.

#### Next Steps:

Plan another bounded resource reduction to create packing margin before repeating the three-seed build, preserving seek behavior and existing regression coverage. The prior a229a01 seed 87 remains the timing-qualified hardware rollback; there is no new direct-seek binary to test.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 47 COMMIT Unreleased 3ab6615 2026-09-14T02:54:33-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Build and qualify the reduced direct-seek source using the standard three placement seeds.

#### Outcome:

The user authorized proceeding with builds after the reduction tests passed. GitHub and local master were verified synchronized, then clean exports of source 3ab6615 started at 2026-09-14T02:54:05-07:00 for seeds 52, 61 and 87, with six workers each, under results/build-3ab6615-20260914-025405. Only seed and worker settings differ from committed source. The batch runs compile followed by focused timing; result packaging requires all four timing corners and the 165-register CDC audit. No replacement RBF exists yet and the MiSTer has not been changed.

#### Next Steps:

Inspect synthesis and fitting resource usage, finish the three builds and timing audits, then package the best completed candidate with exact source, seed, hash and qualification status. Preserve failed artifacts and the a229a01 seed 87 rollback. Hardware testing remains with the user; do not deploy automatically.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 46 COMMIT Unreleased 3ab6615 2026-09-14T02:49:40-07:00

#### Coming From:

Unreleased 2fac1cb

#### Purpose:

Reduce duplicate direct-seek registers and search arithmetic after placement exceeded device capacity.

#### Outcome:

Source 3ab6615 removes 115 duplicate register bits by using seek-point output fields as candidate storage until found validates them, then freezing the result. Search midpoint calculation uses one widened sum instead of subtraction plus addition; the timestamp-distance borrow also supplies the before-target comparison. Offset and timestamp widths, PTS association, probe limits and tagged restart handshakes are retained. The new observer regression passes timestamp association, late PTS rejection, stalled input, stable publication, reset and addresses above 4 GiB. Existing VBR, timestamp-wrap, bounded fallback, open-GOP filtering and asynchronous paused forward/backward restart tests pass. All four actual Pee Strike prefix probes exactly match the prior implementation, including landing addresses, byte counts and probe counts; the 300-second case is bounded-prefix EOF fallback, not full-movie playback. Evidence is under results/direct-seek/reduction. The user requested stopping seeds 52 and 61, but both had already exited with fitter capacity failures before the stop attempt; no Quartus jobs remain. Seed 87 had required 4198 LABs against 4191 available. No new RBF was produced, and no new builds or deployment were started. Physical resource savings and timing are not measured by these simulations.

#### Next Steps:

Keep Quartus builds on hold until requested, then compile the reduced source and audit resource fit, timing and all 165 CDC registers before packaging a candidate for hardware acceptance. The previous a229a01 seed 87 remains the available timing-qualified rollback.

#### Files Modified:

- rtl/media_seek_point.sv
- rtl/media_seek_search.sv
- tools/test_media_seek_point.sv
- tools/verify_direct_seek.py

#### Status:

- [ ] Built
- [ ] Passed

---


## 45 COMMIT Unreleased 2fac1cb 2026-09-14T02:31:21-07:00

#### Coming From:

Unreleased 2fac1cb

#### Purpose:

Build the direct-seek implementation after functional validation.

#### Outcome:

The clean source 2fac1cb seed 52/61/87 batch is running under results/build-2fac1cb-20260914-022936. Final two-header MP2 resynchronization passes exact PCM comparisons after one-byte, 582-byte and plausible-false-header 1604-byte prefixes in both reset sessions, alongside compressed-seek history tests. The actual Pee Strike shared-DDR replay resumes at 10.01 seconds with bypass On and 20.02 seconds with bypass Off, without decoder or audio errors; the Off run was repeated with final two-header verification. Normal opening playback also completes and advances both audio and video. Actual prefix searches use three to five probes for 5-, 10- and 20-second targets; the 10-second search consumes 1387169 bytes rather than decoding the opening interval. Directed tests cover VBR, offsets above 4 GiB, timestamp wrap, bounded fallback, EOF, new-file invalidation, asynchronous configuration and retirement, repeated paused forward/backward commands, and open-GOP/PTS byte filtering. These simulations use bounded ideal queues and periodic display ownership, not full vendor CDC or HDMI hardware models. All functional checks are complete; synthesis, fit and timing qualification are pending. The prior a229a01 seed 87 remains available, and the MiSTer has not been reloaded by the agent.

#### Next Steps:

Finish the authorized three-seed batch, audit all corners and 165 CDC registers, compare resources against a229a01, and package the best completed RBF for user hardware testing. Do not start extra placement batches or deploy automatically.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 44 COMMIT Unreleased 2fac1cb 2026-09-14T01:57:50-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Implement direct timestamp-guided file seeking in both directions for the next build.

#### Outcome:

The user-approved revised plan is implemented in 2fac1cb and pushed. Both MPG directions now search byte positions without codec reconstruction, locate timestamped sequence-header/I-picture restart points, and decode a short lead-in. Searches use at most 18 probes with a 4 MiB reader-progress cap per probe; no usable timestamp or raw M2V falls back to byte-zero reconstruction. The reader offset and DDR-drain handshake are retained, with tagged configuration acknowledged before reset release, stale probe replies excluded, and movie timestamp origin preserved. Direct startup discards leading open-GOP B-pictures requiring an unavailable reference and validates two consecutive MP2 headers to recover from partial audio frames. Tests pass for VBR search, offsets over 4 GiB, PTS wrap, EOF fallback, new-file invalidation, asynchronous repeated forward/backward paused seeks, metadata byte filtering and exact PCM recovery after malformed/partial prefixes. Actual Pee Strike prefix probes find 5-, 10- and 20-second destinations in three to five probes. Combined shared-DDR/display-ownership reconstruction resumes at 10.01 seconds with audio bypass enabled; the 20.02-second bypass-disabled run is being repeated with final two-header audio validation. The normal opening playback regression is also finishing. Evidence is under results/direct-seek. User reports no freeze so far with prior bank-release seed 87; new source hardware acceptance and timing/resource qualification remain pending.

#### Next Steps:

Finish the running A/V regressions and compile the next source candidate using the standard three seeds. Audit timing and 165 CDC registers, package the best RBF, and let the user test short and long jumps in both directions, paused destinations, EOF and audio alignment. Do not deploy automatically or start further placement batches without a new request.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/mp2_decoder.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- rtl/media_seek_point.sv
- rtl/media_seek_search.sv
- rtl/media_seek_video_filter.sv
- rtl/media_session_control.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/phase1p_timing.tcl
- tools/replay_mpg_seek.py
- tools/streams/mpg_replay_control.svh
- tools/streams/mpg_replay_ingress.svh
- tools/test_direct_seek_restart.sv
- tools/test_media_playback_control.sv
- tools/test_media_seek_probe.sv
- tools/test_media_seek_search.sv
- tools/test_media_seek_video_filter.sv
- tools/test_mp2_decoder.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_direct_seek.py
- tools/verify_mp2_seek.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 43 COMMIT Unreleased a229a01 2026-09-14T01:47:05-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Stop the final remaining build at the user's request.

#### Outcome:

Terminated the verified a229a01 build process group; no Quartus jobs remain. Seed 52 had progressed from fitting to timing analysis before cancellation, with compilation completed in 1638.2 seconds; its results are preserved but timing qualification is incomplete. Completed seeds 61 and 87 and their handoff artifacts remain intact. Seed 87 remains the recommended timing-qualified RBF at results/hardware-test-a229a01/seed87/MediaPlayer_20260914.rbf, with minimum setup slack +0.104 ns and all 147 CDC checks passing. The local batch status and handoff README record cancellation, superseding entry 42's instruction to finish seed 52. Hardware acceptance remains pending.

#### Next Steps:

Await the user's seed 87 hardware results. Do not start further builds unless requested.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 42 COMMIT Unreleased a229a01 2026-09-14T01:42:00-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Provide the first timing-qualified RBF containing the seek display-bank release.

#### Outcome:

Seed 87 of the clean a229a01 batch passes all four timing corners: setup +0.104 ns, hold +0.077 ns, recovery +3.845 ns, removal +0.155 ns and pulse width +0.925 ns, with all 147 CDC registers verified. It uses 41216 ALMs, 56163 registers, 480 RAM blocks, 69 DSPs and three PLLs. The hash-verified handoff is results/hardware-test-a229a01/seed87/MediaPlayer_20260914.rbf, SHA-256 b0c4fd56e4051d7898010c2895880d017bcb84a52d7906871675317494b59e7c. Compilation and timing took 1158.6 seconds. Seed 61 finished in 1198 seconds but misses setup by 0.370 ns; all other timing categories and its CDC audit pass. Seed 52 is still fitting. Synthesis adds 67 combinational ALUTs compared with diagnostic source 6eb49e1, with unchanged registers, memory bits, DSPs and PLLs before placement. Documentation commit 89cf3da updates test instructions to the qualified RBF; runtime source remains a229a01. The prior diagnostic seed 61 eventually completed with setup -4.551 ns and is superseded for testing. No new placement batch was started beyond the user-authorized fixed-source three seeds. The MiSTer has not been reloaded or deployed by the agent.

#### Next Steps:

Let the user test seed 87 against the captured Pee Strike freeze and repeated/paused/backward/EOF seeks. Finish auditing the already-running seed 52 without starting further builds. Hardware acceptance remains pending.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 41 COMMIT Unreleased a229a01 2026-09-14T01:18:38-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Build the simulation-verified seek display-bank release for hardware testing.

#### Outcome:

The user has now authorized proceeding after the source-only fix, lifting the build hold for this cycle. The standard clean seed 52/61/87 batch will use exact committed source a229a01. Normal playback, repeated retained seeks, EOF seeking, pixel oracles and DDR ownership/drain regressions already pass; no source changes are planned before this batch. The original diagnostic seed 61 is finishing timing independently and does not contain the fix.

#### Next Steps:

Compile the three fixed candidates, audit all timing corners and 147 CDC registers, package hash-verified RBFs, and identify the best completed candidate for the user. Do not deploy or start another placement batch without a further user request.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 40 COMMIT Unreleased a229a01 2026-09-14T01:08:20-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Release stale display-bank ownership during seeking after outstanding DDR reads drain.

#### Outcome:

Source a229a01 adds an optional explicit display-bank release to the DDR arbiter and enables it only for media_seeking in the production core. The retained bank guard clears after outstanding reads drain and DDR is not busy; a same-cycle accepted display request takes precedence. Descriptor ownership, reconstruction state and compressed streams are preserved, and ordinary pause does not release protection. A twin-arbiter transaction regression reproduces the old blocked-write behavior and verifies the fix across all five frame regions, queued display bursts, prediction/stream responses, DDR busy, acceptance priority and re-acquisition. Reconstruction now includes periodic display requests with seek gating: the release-disabled control fails prediction liveness, while the fix completes normal playback, both retained seeks with paused-bank checks and EOF seeking, with 423936 checked pixel samples and zero oracle mismatches in each passing case. Existing DDR routing and mounted-reader/session-restart regressions pass. The exact MPG replay also accepts the display-ownership model and compiles with shared-DDR mode; no additional full movie run is claimed for this source. The pixel runner now requires an explicit completed-oracle marker so a diagnostic watchdog exit cannot be misreported as success. Evidence is under results/seek-display-release. Source is committed and pushed, but no Quartus build or new RBF was produced under the user's instruction. Hardware confirmation and final timing/resource qualification remain pending.

#### Next Steps:

Keep new builds on hold until the user requests them. When a fixed RBF is available, repeat the captured Pee Strike seek near 18.45 seconds, then repeated forward/backward and paused seeks, resume and EOF behavior; preserve first-fault telemetry if any freeze remains.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_06.svh
- docs/TEST_INSTRUCTIONS.md
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/replay_mpg_seek.py
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_seek_display_ownership.sv
- tools/verify_decoder_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 39 COMMIT Unreleased 6eb49e1 2026-09-14T01:07:15-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Record the first detailed hardware seek fault and the display-bank ownership mechanism consistent with it.

#### Outcome:

The user confirms 01 - Pee Strike.mpg is frozen after one seek. The checksum-valid screenshot under results/telemetry-20260914-010332 contains both legacy and persistent seek telemetry. The first observed error is 0x0004, specifically the prediction/reconstruction aggregate bit, with prediction source three and detail nine: the B-picture raster engine timeout. The syntax/publication-chain probe source and P probe source are zero. Entry errors were zero; capture occurred 67432806 decoder cycles, approximately 1.124 seconds, after seek entry, while seeking remained active with audio bypass enabled. Elapsed time was 18.5185 seconds and target 28.4517667 seconds. Video RAM held 1048576 unread words, compressed audio and PCM queues were empty, and audio/transport error flags were clear. Inspection found that forward seek resets the display framebuffer while preserving the DDR arbiter, whose last accepted display-bank ownership remains valid until reset or another display read. A focused simulation of the unchanged arbiter reproduces indefinite scratch-writer blocking after display reads stop and drain, and releases writes when another display bank is accepted. This is a concrete mechanism consistent with the B timeout, not yet an end-to-end reproduction of this hardware occurrence; the snapshot does not expose writer wait or retained reader-bank state and seed 52 is not timing qualified. The shared-DDR combined replay also completed its 2.2-to-12.2-second seek without errors, but lacks display-reader ownership, explaining why that comparison does not test this mechanism. The capture, focused harness, simulation log and diagnosis are preserved together. No runtime source change or additional build was started.

#### Next Steps:

Propose retiring display-bank protection during seek only after outstanding display reads have drained, preserving normal and paused-frame protection. Validate actual seek/display ownership transitions with a regression before any future build; respect the user's instruction not to start more builds.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 38 COMMIT Unreleased 6eb49e1 2026-09-14T01:01:15-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Hand off the best completed seek diagnostic RBF and record cancellation of additional builds.

#### Outcome:

The user requested no more builds and to test the best completed RBF. The extra seed 53/62/88 batch under results/build-6eb49e1-20260914-005934 was stopped after verifying its process identity. Original seed 61 remains compiling. Seed 52 is the best completed diagnostic candidate under results/hardware-test-6eb49e1/seed52/MediaPlayer_20260914.rbf, hash verified as 9cabb95b1f045dae7a074f3c918ef8dbbc03b293a5842ca088ef776debfa6047. Its setup slack is -0.264 ns; hold, recovery, removal, pulse width and all 147 CDC checks pass. It uses 40900 ALMs, 55848 registers, 480 RAM blocks, 69 DSPs and three PLLs. Seed 87 misses setup by 1.205 ns. Neither is timing qualified or hardware accepted. Tools-only commits 11d7bac and e02f2a5 correct replay clock ratios, require post-seek audio/video progress, decode full PCM occupancy and add optional production shared-DDR arbitration. The original three combined MPG/audio replays completed the exact Pee Strike 2.2-to-12.2-second seek with audio/video resumption and no reported errors, including audio bypass disabled and varied host stalls/seek phase. A shared-DDR comparison is still running after correcting a behavioral memory-index width limitation before playback; this harness issue is not a hardware freeze reproduction. Hardware source remains 6eb49e1 and the freeze cause remains unresolved.

#### Next Steps:

Let the user test seed 52 with Seek audio bypass On, preserve the first-fault screenshot if it freezes, then reload and compare Off. Do not start more builds. Check the already-running original seed 61 and shared-DDR replay when results are needed.

#### Files Modified:

- tools/replay_mpg_seek.py
- tools/streams/decode_hardware_cadence.py
- tools/streams/mpg_replay_control.svh
- tools/streams/mpg_replay_ingress.svh
- tools/verify_seek_diagnostics.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

