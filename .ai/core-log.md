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

## 848 COMMIT Unreleased 2de0717 2026-08-31T20:44:17-07:00

#### Coming From:

Unreleased aab7d09

#### Purpose:

Restore the last physically proven moving-purple selector userspace combination while keeping the accepted source-`f5f650f` RBF frozen.

#### Outcome:

The source-`aab7d09` physical test keeps menu video stable and proves the expected helper, Main and schema-21 overlay-capable RBF behaviors are active, but the 4,000-byte helper packetization worsens the rejected plane from the prior 21-byte deficit to 4,220 missing bytes: Main still submits 22 ordered records and all 86,400 all-`0x55` bytes with the expected hash, while the FPGA engine receives 82,180 bytes, rejects the commit and publishes no plane.  The user explicitly prioritizes a working selector over the newer menu-reliability drain if both cannot yet coexist.  Source `2de0717` restores the helper's physically proven 4,096-byte record framing and removes only Main's later 500-millisecond stream-hop drain, making both source files byte-identical to the entry-840 successful selector combination while preserving overlay tracing, navigation and the frozen source-`f5f650f` RBF.  Strict native compilation and the focused subpicture, random-access and menu-hop regressions pass, and the restored framing emits exactly 22 records carrying all 86,400 bytes with 4,096-byte maximum payloads and a 384-byte final payload.  The Raspberry Pi GNU 10.2.1 ARM toolchain builds `host/build/MediaPlayer_Helper_PurpleSelector_2de0717`, a 908,660-byte stripped static ARM EABI5 executable at SHA-256 `fd5d46f116ec41224ff9dd4c13fb62453a009ec462de9ab9b1bdfa794ff2b26c`, and `host/build/MiSTer_SelectorProven_2de0717`, a 1,178,588-byte stripped dynamic ARM EABI5 executable at SHA-256 `872050d44266d74c28e302a54336f409426fbca235ce3384c3b1735eb1aa6356`.  Both hashes exactly match the binaries used by the successful entry-840 hardware test.  The helper returns the complete protocol-one capability string and contains the required `probe=solid-index1-magenta` marker.  No RBF was built or changed; `output_files/MediaPlayer_20260831_f5f650f.rbf` remains 4,456,796 bytes at SHA-256 `4c57f9350b3c553d322395d0d4c0f7cc78dc14f8d7be863a251c83d10af647f7`.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_PurpleSelector_2de0717` and replace `/media/fat/MiSTer` with local `host/build/MiSTer_SelectorProven_2de0717`, restore executable mode if needed and verify both installed hashes.  Reboot because Main changed, load the existing `MediaPlayer_20260831_f5f650f.rbf`, restart the DVD, press `M` and move through every menu button.  Hardware acceptance requires one accepted and zero rejected overlay commit, all 86,400 plane bytes, one plane publication and a visible purple selector following directional input; intermittent menu-load failure remains an accepted temporary tradeoff for this restoration boundary and may be retried or cleared by rebooting.

#### Files Modified:

- host/arm/media_player_helper.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 847 COMMIT Unreleased aab7d09 2026-08-31T20:27:44-07:00

#### Coming From:

Unreleased 924cb21

#### Purpose:

Restore the proven moving solid-purple DVD menu selector with a helper-only overlay-packet compatibility workaround while preserving the accepted Main and frozen RBF.

#### Outcome:

The latest physical capture proves that the installed probe helper still generates the correct opaque-magenta index-one palette and moving authored button rectangles and that Main receives and submits a complete 86,400-byte all-index-one plane with 22 ordered data records, the expected hash and no source corruption.  The FPGA nevertheless receives only 86,379 plane bytes and rejects the commit without publishing a plane; the exact 21-byte deficit equals one byte for each of the 21 maximum-size 4,096-byte data records, while the final short record is accounted for.  Source `aab7d09` changes only the helper's overlay data chunk from 4,096 to 4,000 payload bytes, carrying the identical plane in 21 full records plus one 2,400-byte record while keeping every command-plus-payload record below the failing 4,097-byte edge; Main, selector generation, palette, protocol, total bytes and RBF remain unchanged.  The strict native purple-probe build and capability smoke test pass together with the focused fragmented-SPU, selected-histogram, scheduled-stop, random-access and menu-hop regressions and a framing check for exactly 22 records and 86,400 bytes.  The user's local GNU 10.2.1 ARM toolchain produces the 908,660-byte stripped static 32-bit ARM EABI5 `host/build/MediaPlayer_Helper_PurpleSelector_aab7d09` at SHA-256 `5f0bbe70fd8da1a85de39ef5a9a47917606b685b3e7a2b330ca7343db4285c1c`; it contains the `probe=solid-index1-magenta` marker and returns the complete protocol-one capability string when executed on the Raspberry Pi.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_PurpleSelector_aab7d09`, restore executable mode if needed and verify the installed size and SHA-256.  Preserve the installed Main and RBF, restart the DVD, press `M` and move through every menu button; acceptance requires reliable menu loading, a visible purple rectangle that follows every directional selection, 86,400 received plane bytes, one accepted and zero rejected commits and one published plane.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 846 COMMIT Unreleased 924cb21 2026-08-31T20:19:36-07:00

#### Coming From:

Unreleased ad0d5ec

#### Purpose:

Restore the proven moving solid-purple DVD menu selector entirely in the ARM helper while freezing the accepted RBF and reliable Main menu-load behavior.

#### Outcome:

The user defines the current source-`f5f650f` RBF as complete for the required product scope because playback, chapter and menu stream hops, software-directed DVD navigation and overlay rendering have all been physically demonstrated, with the residual intermittent overlay-plane shortfall treated as a software compatibility constraint rather than an FPGA release blocker.  The existing opt-in `MMP_DVD_OVERLAY_PROBE` implementation already provides the required behavior by sending an all-index-one plane with a transparent normal palette, opaque magenta highlight palette and the authored moving button rectangle, so no source, RBF or Main change is needed.  On the Raspberry Pi, the user's installed GNU 10.2.1 ARM toolchain builds the current helper locally with that definition into `host/build/MediaPlayer_Helper` and the byte-identical uniquely named `host/build/MediaPlayer_Helper_PurpleSelector_924cb21`; both are 908,660-byte stripped static 32-bit ARM EABI5 executables at SHA-256 `fd5d46f116ec41224ff9dd4c13fb62453a009ec462de9ab9b1bdfa794ff2b26c`, contain the required `probe=solid-index1-magenta` marker and return the complete protocol-one capability string when executed.  A strict native equivalent build and the focused fragmented-SPU, selected-histogram, scheduled-stop, random-access and menu-hop regressions pass; the prior ordinary helper is preserved locally as `host/build/MediaPlayer_Helper_Authored_f5f650f`.

#### Next Steps:

Exit the MediaPlayer core so the running helper stops, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper_PurpleSelector_924cb21`, restore executable mode if needed and verify the installed size and SHA-256.  Preserve the installed Main and RBF, restart the DVD, press `M` and move through every menu button; acceptance requires the menu to continue loading reliably and one solid purple selector rectangle to follow the arrow keys.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 845 COMMIT Unreleased 924cb21 2026-08-31T19:59:36-07:00

#### Coming From:

Unreleased 132ee3f

#### Purpose:

Evaluate the Main-only 500 millisecond stream-hop drain diagnostic across the user's repeated physical root-menu reloads without conflating video-hop stability with selector-plane delivery.

#### Outcome:

The user's updated physical capture contains fifteen consecutive `M` root-menu commands, fifteen ready barriers, fifteen chapter-barrier releases and fifteen measured drain intervals tightly bounded from 500,064 through 500,067 microseconds against the 500,000-microsecond target.  Every reload preserves the authored menu video, no schema-21 `0x0200` B-picture presentation failure or fatal transport event occurs, and the final screenshot remains on the correct menu instead of the former black raster, providing strong 15-of-15 evidence for residual pre-hop FIFO bytes as the intermittent video failure.  This does not yet satisfy entry 844's stated twenty-reload threshold, and it is not a clean selector result: the checksum-valid final matrix reports one rejected and zero accepted overlay commits, only 86,379 of 86,400 plane bytes, 10,797 complete DDR words plus three byte lanes, no plane publication and the sticky overlay-engine protocol flag `0x2000`; the Main trace independently sees the helper submit all 86,400 bytes with the expected `c23cad52` FNV-1a, so the absent selector is a separate FPGA-side overlay-delivery failure rather than recurrence of the menu-video fault.

#### Next Steps:

Preserve the working Main drain diagnostic and source-`f5f650f` RBF while treating the black-screen and selector faults independently.  Complete five additional consecutive root-menu reloads to close the predeclared twenty-hop video acceptance boundary, but first use the exact 21-byte physical shortfall and retained extractor handshake to define the smallest RBF diagnostic or correction for the intermittent overlay loss; require a fresh matrix with 86,400 plane bytes, 10,800 DDR words, one accepted and zero rejected commits, one plane publication, no `0x2000` flag and a visibly moving authored selector.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 844 COMMIT Unreleased 924cb21 2026-08-31T19:48:07-07:00

#### Coming From:

Unreleased c787835

#### Purpose:

Build and verify the Main-only 500 millisecond stream-hop drain diagnostic for physical FIFO-residue testing.

#### Outcome:

The exact clean source checkout `924cb217c1617a3c466df28094616758c3ad2644` on build PC `10.10.0.42` applies both pinned Main patches in order and builds Main successfully with MiSTer's pinned GNU 10.2.1 ARM toolchain.  The uniquely preserved `/home/vash/MiSTer-Media-Player-924cb21/host/build/MiSTer_StreamHopDrain_924cb21` and local `host/build/MiSTer_StreamHopDrain_924cb21` are byte-identical 1,178,588-byte stripped dynamically linked 32-bit ARM EABI5 executables at SHA-256 `6f49f425dae7e789c2f54b919fcc99fdb0f804e0ebbb60996f7c235e799bdf65`; the binary contains the required `stream hop drain release_to_rearm_us` marker.  The source checkout remains clean, and no helper, RBF, MiSTer installation, media or running process changes during this build.

#### Next Steps:

The user will manually replace only `/media/fat/MiSTer` with local `host/build/MiSTer_StreamHopDrain_924cb21`, restore executable mode if needed, verify the exact size and SHA-256, and reboot while preserving the installed ordinary helper and source-`f5f650f` RBF.  Start the physical DVD and perform at least twenty consecutive `M` root-menu reloads; acceptance requires every completed hop to log `release_to_rearm_us` at or above 500,000, continued menu video and selector operation, and no schema-21 `0x0200` raster, while any recurrence rejects residual FIFO drain as a sufficient remedy.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 843 COMMIT Unreleased 924cb21 2026-08-31T19:45:27-07:00

#### Coming From:

Unreleased 64f5156

#### Purpose:

Restore clean applicability of the pinned Main patch stack without changing the approved stream-hop drain experiment.

#### Outcome:

The exact source-`64f5156` Main build stops before compilation because the following overlay-trace patch retains context around the original transfer-profile declarations and the first patch inserted the new drain constants inside that context.  No compiler, link, binary or target result is produced.  Source `924cb21` relocates only those two declarations ahead of the retained context, preserving the same 500 millisecond behavior, log format, helper, RBF and submitted bytes; the complete first patch is structurally valid and whitespace-clean, and exact ARM compilation remains pending.

#### Next Steps:

Rebuild Main from exact source `924cb21` on build PC `10.10.0.42`, verify the resulting ARM executable and diagnostic marker, and then return to entry 842's unchanged twenty-hop physical acceptance test.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 842 COMMIT Unreleased 64f5156 2026-08-31T19:40:09-07:00

#### Coming From:

Unreleased 3c68242

#### Purpose:

Test whether residual pre-hop bytes in the FPGA input FIFO cause the intermittent root-menu B-picture presentation failure without rebuilding the RBF.

#### Outcome:

The user approves and source `64f5156` implements a Main-only diagnostic after one physical session completes repeated root-menu reloads before a later identical hop fails with only `0x0200`; the failing reset session accepts 18,937 bytes, recognizes a B picture at temporal reference ten while frame-rate code remains zero, and therefore reaches a picture header before parsing the new sequence header.  The helper reports the same valid sequence, intra and following-reference boundary on the successful and failing menu-to-menu hops, while static inspection proves that each `ioctl_download` rising edge resets the MPEG decoder but leaves the 32 KiB dual-clock input FIFO intact until a full core reset.  Main now timestamps every chapter or menu download release, waits until at least 500 milliseconds have elapsed before the next rising edge, and logs the measured release-to-rearm interval without changing the helper, RBF or submitted stream bytes; the complete pinned patch is structurally valid and whitespace-clean, while exact ARM compilation remains pending.

#### Next Steps:

Build and verify one uniquely named ARM Main from exact source `64f5156`, then preserve the installed helper and source-`f5f650f` RBF while manually replacing only Main and rebooting.  Hardware acceptance requires at least twenty consecutive `M` root-menu reloads without the schema-21 `0x0200` raster, with each log recording a download-off interval of at least 500 milliseconds; any recurrence rejects the drain hypothesis and returns to exact scheduler-source instrumentation.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 841 COMMIT Unreleased f5f650f 2026-08-31T19:20:09-07:00

#### Coming From:

Unreleased 647c36e

#### Purpose:

Build and qualify the ordinary ARM helper that restores the authored DVD selector while preserving the accepted Main and RBF.

#### Outcome:

The exact clean checkout `f5f650f87109193e90c664175b1785e721134d26` on build PC `10.10.0.42` builds the normal native helper with strict warnings and passes its capability smoke test plus the focused fragmented-subpicture, selected-histogram, scheduled-stop, random-access and menu-hop regressions.  The same exact source builds the ordinary ARM helper without defining `MMP_DVD_OVERLAY_PROBE` under MiSTer's pinned GNU 10.2.1 toolchain.  `/home/vash/MiSTer-Media-Player-f5f650f/host/build/MediaPlayer_Helper` is a 908,660-byte stripped static 32-bit ARM EABI5 hard-float executable with no dynamic section, contains no `probe=solid-index1-magenta` marker and has SHA-256 `7818463017de063ba72846429c60816b967444b0137dcd2f156d9902ae96e96b`.  The artifact is copied byte-identically to local `host/build/MediaPlayer_Helper` for the user's manual transfer.  No repository source, Main, RBF, MiSTer file, running process or playback setting changes during this build.

#### Next Steps:

The user will exit the MediaPlayer core so the probe helper is no longer running, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper`, create no backup, preserve Main and `/media/fat/MediaPlayer_20260831_f5f650f.rbf`, restore executable mode if the transfer client clears it, and verify the installed file is 908,660 bytes with SHA-256 `7818463017de063ba72846429c60816b967444b0137dcd2f156d9902ae96e96b`.  Restart the DVD, enter the root menu and move among all four buttons; acceptance requires the solid magenta rectangle to disappear and the sparse authored highlight to follow the selector, after which collect a fresh screenshot and helper log.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 840 COMMIT Unreleased f5f650f 2026-08-31T19:16:30-07:00

#### Coming From:

Unreleased 648c0ed

#### Purpose:

Accept the retained DVD overlay transfer repair on physical hardware and define the helper-only boundary that restores the authored menu selector.

#### Outcome:

The user's physical source-`f5f650f` capture accepts the repaired RBF for its targeted transfer fault.  The checksum-valid schema-21 snapshot at SHA-256 `f218fbd3946c0b59db43b6aa46a86059a90adbb70750fb18dfc1f030ae55829e` reports one config, 22 data records, one commit, two styles, one clear, zero rejected commits, one accepted commit and one plane publication; all 86,400 plane bytes reach the engine, all 10,800 DDR words complete with byte lane zero, and the engine is ready with no protocol error or pending publication.  The video domain counts 88,800 highlighted samples, all 88,800 with nonzero alpha and all 88,800 opaque magenta.  The 1,920-by-1,080 screenshot at SHA-256 `ed6e5b3920d5007ff0176bb6d5f2e20124c25888c8820dc22ef0fa13f1ed77fa` contains exactly 34,560 magenta pixels in one 320-by-108 rectangle from output coordinate 830,876 through 1,149,983, precisely scaling the helper log's current DVD rectangle 311,389 through 430,436.  The 2,286,369-byte Main/helper log at SHA-256 `3167ce45cd803779dcfe328a9235f9fb0c7e74a558e6b9a3b4a20c41f4a338d7` records successful style movement among the authored button rectangles.  The solid rectangle is the intentionally installed `MMP_DVD_OVERLAY_PROBE` helper output, while ordinary source already emits the real decoded two-bit plane and authored palette; no further RBF or source correction is indicated for this selector restoration.

#### Next Steps:

From an exact clean source-`f5f650f` checkout on build PC `10.10.0.42`, run the focused subpicture, random-access and menu-hop regressions, build the ordinary ARM helper without `MMP_DVD_OVERLAY_PROBE`, and verify it is a stripped static ARMv7 executable with no dynamic section.  Preserve Main and `MediaPlayer_20260831_f5f650f.rbf`, stop the running helper by exiting the core, replace only `/media/fat/linux/MediaPlayer_Helper` under the user's no-backup policy, verify the installed bytes by readback, then restart the DVD and require a sparse authored selector that follows all menu choices without any solid magenta rectangle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 839 COMMIT Unreleased f5f650f 2026-08-31T16:56:30-07:00

#### Coming From:

Unreleased 667d284

#### Purpose:

Build and qualify the exact source-`f5f650f` retained DVD overlay handshake correction for physical MiSTer testing.

#### Outcome:

The exact clean source checkout `f5f650f87109193e90c664175b1785e721134d26` passes the strengthened metadata extractor regression, the complete 86,400-byte integrated stalled-DDR regression, and the retained overlay-engine, DDR-arbiter and schema-21 snapshot regressions under Icarus Verilog on build PC `10.10.0.42`.  Quartus Prime 17.0.2 seed 20 completes synthesis, fitting, assembly and the project timing gate with zero errors; global setup, hold, recovery, removal and minimum-pulse-width slacks are respectively positive at 0.321, 0.243, 3.618, 0.605 and 0.925 nanoseconds, while the dedicated 60 MHz decoder and 54 MHz video checks have 0.491 and 1.385 nanoseconds of setup slack and no violations.  The fit uses 34,710 ALMs, 54,437 registers, 4,187,011 block-memory bits and 70 DSP blocks.  The uniquely preserved `output_files/MediaPlayer_20260831_f5f650f.rbf` is 4,456,796 bytes with SHA-256 `4c57f9350b3c553d322395d0d4c0f7cc78dc14f8d7be863a251c83d10af647f7`, identical on the build PC and in the local workspace.  No Main, helper, MiSTer installation, media or playback setting changes at this build boundary.

#### Next Steps:

Preserve the installed Main and helper, upload only `MediaPlayer_20260831_f5f650f.rbf` as a new file rather than overwriting the current rollback, load that core, restart the DVD, enter the root menu and move the selector several times.  Require visible opaque-magenta highlight pixels, then wait at least two seconds and collect fresh telemetry, screenshot and Main/helper log; schema 21 should report one good and zero bad commits, one plane publication, 86,400 submitted and accepted plane bytes, 10,800 DDR words and nonzero alpha and magenta sample counters.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 838 COMMIT Unreleased f5f650f 2026-08-31T16:39:27-07:00

#### Coming From:

Unreleased 6dbbaf6

#### Purpose:

Preserve the repaired DVD overlay handshake while restoring positive global setup timing after the first exact-source fit.

#### Outcome:

Exact source `4821744` remains functionally accepted by all five focused overlay simulations, but its clean Quartus Prime 17.0.2 seed-20 build is rejected by the project timing gate at global setup slack negative 0.441 nanoseconds.  The dedicated 60 MHz decoder and 54 MHz video domains remain violation-free at positive 0.557 and 2.529 nanoseconds, and hold, recovery, removal and minimum-pulse-width slacks remain positive.  A read-only fifty-path TimeQuest report proves every reported violation is the unrelated HDMI-domain scaler path from `ascal|o_vacpt` through its address DSP terminals, while the changed elastic extractor slot added a simultaneous ready-transfer replacement path into upstream readiness and perturbed packing.  Source `f5f650f` retains every overlay byte but makes the one-entry output slot non-elastic: upstream stops whenever the slot is occupied and resumes on the cycle after the engine accepts it, removing the new combinational ready path at the cost of one harmless decoder-clock bubble per overlay byte.  The strengthened extractor and complete 86,400-byte integrated stalled-DDR tests pass again, as do the retained engine, arbiter and snapshot regressions, with the integrated test still requiring all 10,800 DDR writes, an accepted plane publication and opaque-magenta video output.

#### Next Steps:

Check out exact source `f5f650f` on build PC `10.10.0.42`, rerun all five focused regressions from that clean source, then perform a second clean Quartus Prime 17.0.2 seed-20 build.  Reject any RBF unless global setup, hold, recovery, removal and minimum-pulse-width timing are all positive and both dedicated decoder and video timing reports contain no violations.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 837 COMMIT Unreleased 4821744 2026-08-31T16:18:01-07:00

#### Coming From:

Unreleased 6e0df01

#### Purpose:

Prevent loss of DVD overlay plane bytes when the FPGA overlay engine backpressures the in-band metadata extractor for a DDR write.

#### Outcome:

The user approves and source `4821744` implements the RBF-only correction after physical schema 21 proves 4,238 of 86,400 known-pattern plane bytes disappear specifically between the extractor output and the overlay engine, causing one rejected commit, zero plane publications and zero alpha or magenta samples.  The extractor's overlay output is now a conventional retained valid, data, start and last slot that remains stable until an actual ready transfer, permits replacement in the same cycle only when the current byte is accepted, and leaves the upstream FIFO stopped whenever that slot cannot advance.  The strengthened extractor regression proves all record fields remain stable across alternating ready stalls.  A new integrated regression drives the complete config, 22 data records, 86,400 all-`0x55` plane bytes and commit through the extractor and engine under deterministic DDR writer stalls; it requires exactly 10,800 accepted writes, byte-exact first and last DDR words, one accepted and zero rejected commits, one plane publication and opaque-magenta video output.  The integrated test and retained extractor, engine, DDR-arbiter and schema-21 snapshot tests all pass under Icarus Verilog on build PC `10.10.0.42`, with warnings limited to inherited timescales.  Main, the helper, the B9 record format, DDR addressing, cache policy, palette, rectangle, blend function and schema-21 observability remain unchanged.

#### Next Steps:

Check out exact source `4821744` on build PC `10.10.0.42`, rerun all five focused overlay regressions from that clean source, perform one clean Quartus Prime 17.0.2 seed-20 build, require positive setup, hold, recovery, removal and minimum-pulse-width timing, and preserve a uniquely named replacement RBF while leaving the installed Main, helper and source-`d4ed809` rollback unchanged.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/test_dvd_overlay_metadata.sv
- tools/test_dvd_overlay_integrated.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 836 COMMIT Unreleased d4ed809 2026-08-31T16:15:48-07:00

#### Coming From:

Unreleased 43a1c22

#### Purpose:

Use the first physical schema-21 capture to localize the invisible known-pattern DVD highlight within the FPGA overlay pipeline.

#### Outcome:

The checksum-valid 883-byte schema-21 capture at SHA-256 `c146d2775a491c4ce8a652a9370a80fe718e0ff55109a546b40cc9d09b19c86b` proves that the extractor presents one config, 22 data records, one commit and two style records to the overlay engine, but only 82,162 of the required 86,400 plane bytes arrive.  The engine completes 10,270 DDR words and retains two further byte lanes instead of the required 10,800 complete words, sets its protocol-error flag, counts one rejected and zero accepted commits, leaves the display bank unchanged and publishes no plane.  It nevertheless publishes both styles with visible and menu flags, exact rectangle 135,397 through 208,436 and internal opaque-magenta entry one `ffff00ff`; the video domain receives three style or clear publications, saturates the row-tag counter, observes 5,989,983 row-matched samples and 51,800 samples inside the highlight rectangle, but sees exactly zero nonzero-alpha and zero opaque-magenta samples because the rejected commit leaves it reading the initial zero-valued plane bank.  Capture reason one fires after the intended 59,999,999 settle clocks.  The independently saved Main/helper log at SHA-256 `8ed4759ce04eee7794706239609a9fdfa134cdf5fe7c16211e534bbf77e02db0` still proves all 86,400 all-`0x55` bytes entered the FPGA ingress FIFO with FNV-1a `f8555d45`, zero order errors and `probe_complete=1`; the 1,920-by-1,080 screenshot at SHA-256 `b3606148234c83f7fe35d8b9f36d05fa3441b74a4ac3222db90720a629158d71` visibly confirms no magenta overlay.  Static inspection identifies the loss mechanism: `mpeg2_h262_inband_metadata` registers each overlay byte as a one-cycle pulse while gating its input with the overlay engine's current combinational ready signal, so on a cycle that the engine accepts the eighth byte and raises its registered DDR-write pending state, the extractor can already consume and schedule the following byte against the old ready value; that pulse is presented while the engine is not ready and has no retained-valid storage.  The fault is therefore the extractor-to-engine ready/valid boundary inside the FPGA, not Main, the ingress FIFO, DDR arbitration, row-cache publication or the final compositor.

#### Next Steps:

After user approval, replace the pulse-only overlay output with a conventional retained valid/data/start/last register whose valid bit clears only on an actual engine-ready transfer, derive extractor input readiness from the availability of that output slot, and add an integrated regression that drives the complete 86,400-byte plane through the extractor and engine while injecting DDR writer stalls.  Require exactly 86,400 engine plane bytes, 10,800 accepted DDR writes, one accepted and zero rejected commits, one plane publication, nonzero alpha and opaque-magenta video samples, then build a timing-clean RBF without changing Main, the helper, the record protocol or rendering semantics.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
