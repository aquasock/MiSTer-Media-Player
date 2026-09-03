## 909 COMMIT Unreleased ??? 2026-09-02T17:54:21-07:00

#### Coming From:

Unreleased 8c90e2d

#### Purpose:

Preserve the resident DVD picture when an authored indefinite submenu activation produces only a replacement overlay.

#### Outcome:

The approved helper-only boundary will replace the ambiguous raw Program Stream start-code count with destination evidence from the bounded output stage and the helper's emitted H.262 picture scanner.  An active finite-still stage will retain its existing commit-and-delay behavior, an empty indefinite stage will retain cancellation and continuation, a stage containing an emitted H.262 picture will retain stale-reserve discard plus the READY/GO decoder barrier, and a nonempty indefinite stage containing only overlay or audio records will gain an explicit commit-and-continuation result that preserves Main's resident picture.  The source-`8c90e2d` redundant-root and unsupported-LPCM behavior, genuine video-bearing activation path, Main, visualizer, transport protocol, RTL and RBF remain unchanged.

#### Next Steps:

Extend the output-stage classifier with the explicit overlay-only continuation result, drive it from actual emitted picture marks, and make that result commit the staged records before acknowledging `MENU_CONTINUE` without reserve discard or decoder reset.  Add a focused 26-record, 86,664-byte overlay-only transaction matching the Coming to America evidence plus retained empty, finite and picture-bearing cases; run strict native, sanitizer, analyzer, reserve, staging, menu-hop, overlay, random-access, audio, seek and visualizer regressions, then build and verify an exact static ARMv7 helper for physical retest.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/output_stage.c
- host/arm/output_stage.h
- tools/test_output_stage.c

#### Status:

- [ ] Built
- [ ] Passed

---

## 908 COMMIT Unreleased 8c90e2d 2026-09-02T17:50:47-07:00

#### Coming From:

Unreleased 8c90e2d

#### Purpose:

Qualify the source-`8c90e2d` helper on Coming to America's authored Scene Selections submenu and isolate its black freeze.

#### Outcome:

The user's physical Coming to America run rejects source `8c90e2d` as a complete DVD-menu compatibility boundary.  Root-menu navigation remains active for approximately 89 seconds, three Right commands select button four, and activation command `0x08` succeeds at 97.841139 seconds, starts the bounded destination stage and reaches an authored indefinite still after 249 generic Program Stream start codes.  The helper incorrectly treats that raw count as proof of a replacement video stream, discards 3,917,940 bytes from the old reserve, sends READY, resets Main and commits 26 staged records totaling 86,664 bytes; that total is exhausted exactly by one overlay style record, one clear, one configuration, twenty-two plane-data records and one commit, with no H.262 picture or PCM record.  Main therefore receives the new selector plane after blanking the resident video but has no replacement picture to display, matching the completely black 559-byte screenshot, while the helper remains alive in the indefinite still through the 254.403587-second capture endpoint without a fatal error.  The 6,152,722-byte log and screenshot have SHA-256 `10ceecceead32b51aff4d22fed0ab816c95e2c50cee070d7ad9b972258a07e27` and `1799af730e4ee79b5cdfe65960df9323dfc4c9d01f44b29fa2fbd549718fea49`; the unchanged 2,818-byte telemetry decode failure at SHA-256 `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004` contains no hardware snapshot and adds no FPGA fault evidence.

#### Next Steps:

Preserve the source-`8c90e2d` redundant-root and unsupported-LPCM fixes, Main, the RBF and the overlay protocol.  After user approval, classify pending indefinite menu activation from actual validated H.262 picture output rather than generic start-code count: an overlay-only destination must commit its staged overlay to the live resident presentation and acknowledge menu continuation without reserve discard, READY/GO or decoder reset, while a genuine video-bearing destination retains the existing staged stream-hop barrier and empty or finite still paths remain unchanged.  Add exact overlay-only coverage matching the observed 26 records and 86,664 bytes, retain true-video, empty and finite-stage regressions, rerun the complete helper and sanitizer suites, and build only a new ARM helper for Coming to America, Blazing Saddles, The Big Lebowski and forum-disc testing.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 907 COMMIT Unreleased 8c90e2d 2026-09-02T08:26:19-07:00

#### Coming From:

Unreleased 8c90e2d

#### Purpose:

Bundle the source-`8c90e2d` DVD menu compatibility helper with its matched runtime set and physical-drive launcher for hardware testing.

#### Outcome:

`host/build/MiSTer_Media_Player_8c90e2d.zip` contains the exact static ARMv7 helper from source `8c90e2d`, source-`46638c7` Main, source-`5327358` visualizer pack, timing-qualified source-`dfe1057` `MediaPlayer_20260901.rbf`, `games/MediaPlayer/USB DVD Drive.dvd`, installation and source-provenance notes, the project licence and all seven bundled dependency licences.  A fresh extraction contains sixteen files, all fifteen manifest entries pass SHA-256 verification, both executables retain mode 755, the helper and launcher are byte-identical to their verified source artifacts, and ZIP integrity reports no errors.  The 6,481,417-byte archive has SHA-256 `02ce7dae21297423c1ac1fc0afe45744d8a8ab431e3bfcc9dec9347f85216a0d`.

#### Next Steps:

Extract the archive to the MiSTer paths documented in `INSTALL.txt`, preserve the installed rollback files, reboot because the matched Main is included, and run the source-`8c90e2d` Blazing Saddles redundant-root test, the forum disc's LPCM-menu survival and AC-3 title test, and ordinary Coming to America plus The Big Lebowski menu regressions before accepting the helper on hardware.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 906 COMMIT Unreleased 8c90e2d 2026-09-02T07:56:41-07:00

#### Coming From:

Unreleased fddab62

#### Purpose:

Preserve an already-active DVD root menu and keep unsupported private audio from terminating otherwise playable DVD navigation.

#### Outcome:

The helper now queries libdvdnav's current title and menu identity before a root-menu command; an already-active root menu returns continuation status `already-root` without a VM jump, output discard or decoder barrier, while title-to-root and submenu-to-root navigation retain the existing hop.  DVD private audio substreams `0x90` through `0xaf` are now skipped with one bounded diagnostic per substream instead of terminating video and navigation; the forum capture's `0xa0` DVD LPCM menu can therefore remain silent while the established AC-3 selection is preserved for subsequent title playback.  Deterministic regressions reproduced the prior fatal `0xa0` behavior and then proved complete H.262 output with no fabricated PCM, 100 root-menu identity and reserve repetitions, 20 LPCM and overlay repetitions, all four real audio seek/timer formats, the complete native helper suite, and ASAN/UBSAN coverage.  The exact static ARMv7 artifact `host/build/MediaPlayer_Helper_MenuCompat_8c90e2d` is 961,956 bytes with SHA-256 `1cad3ba0a5beefb4090126e99f2cfd35fd83a5d8fe44c36c0764033f38338f3b`; Main, RTL, the visualizer, the transport capability string and RBF are unchanged.

#### Next Steps:

Install only the exact helper as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main and RBF.  For Blazing Saddles, allow the automatic root menu to appear and press `M`; the background and selector must remain active and telemetry should report `status=already-root` without a navigation reserve discard or READY/GO barrier.  For the forum disc, telemetry should report that unsupported DVD LPCM substream `0xa0` is skipped, the helper must remain alive through the menu even if that menu is silent, and activating the title must restore its supported AC-3 playback.  Recheck ordinary root-menu entry, selection and title playback with Coming to America and The Big Lebowski before accepting this commit on hardware.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_private_audio_skip.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 905 COMMIT Unreleased fddab62 2026-09-02T07:49:36-07:00

#### Coming From:

Unreleased fddab62

#### Purpose:

Qualify the media-only DVD navigation barrier on physical hardware and isolate the remaining Blazing Saddles root-menu blank.

#### Outcome:

The user's physical source-`fddab62` capture accepts the media-only ownership fix: Blazing Saddles no longer terminates the helper, the root command at 13.035470 seconds discards 3,055,569 reserved bytes, navigation is ready 11.212 milliseconds later, and Main releases its decoder barrier after another 5.459 milliseconds without `Resource temporarily unavailable` or any helper error.  The disc enters a four-button menu autonomously at 11.938842 seconds, 1.096628 seconds before the user presses `M`; the root call then reports the same NAV PCI LBN 333, selected button 1 and highlight rectangle before resetting Main.  Libdvdnav re-emits the 86,400-byte overlay and reaches an indefinite menu still, but after that overlay commit every one of 245 pipe reads is at most 96 bytes and carries only overlay style records, so no replacement MPEG background follows the redundant same-menu hop and the decoder remains black.  This is distinct from the resolved output-ownership crash and from CSS setup: the helper survives for the remaining capture, while the user separately reports Coming to America and The Big Lebowski still load their menus.  The 4,153,418-byte log has SHA-256 `58b480f1d441d64729d14c1bc84e4604914c7b77c54308aad64d5f8375ca84d3`; the 559-byte black screenshot and telemetry decode failure have SHA-256 `9677a233b9b21aa34e041950e2ce422df808f6fa3a5db233eeb0c7f7bb98ee27` and `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004`.

#### Next Steps:

Preserve Main, the RBF, reserve discard, media-only ownership and normal authored menu hops.  After user approval, make the helper treat `M` as a no-op when libdvdnav already reports the root menu, retaining the queued or displayed MPEG background and current overlay rather than issuing a same-menu VM jump and decoder barrier; calls from title playback or a non-root submenu must continue through the existing hop path.  Add focused native coverage for root-menu identity, submenu-to-root transitions and title-to-root transitions, rerun all helper regressions and build a helper-only ARM artifact for physical retest.  On Blazing Saddles, allow its autonomous menu entry to finish and press `M` again while the root menu is active; acceptance requires the background and selector to remain visible, no decoder reset, responsive authored buttons and unchanged behavior on Coming to America and The Big Lebowski.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 904 COMMIT Unreleased fddab62 2026-09-02T07:11:06-07:00

#### Coming From:

Unreleased 46638c7

#### Purpose:

Keep reserve-backed physical-DVD output independent from the nonblocking descriptor's unused stdio stream at navigation barriers and shutdown.

#### Outcome:

Source `fddab62` makes helper output ownership exclusive and fixes the hardware root cause rather than masking its symptom.  Libdvdnav's default informational logger was buffering diagnostics on media stdout; the helper now uses the supported `dvdnav_open2` and `dvdnav_open_stream2` logger callback to route every diagnostic level to stderr before playback, while reserve-backed barriers select reserve drain or discard without also flushing that nonblocking descriptor's unused stdio stream and shutdown remembers reserve ownership.  The focused production regression fills the nonblocking pipe while retaining a buffered stdio sentinel: source `2bd8447` reproduces `flushing ownership navigation barrier failed: Resource temporarily unavailable`, while `fddab62` cancels 262,144 reserve bytes, leaves stdio untouched through shutdown and preserves the sentinel for an independent later flush.  One hundred strict repetitions of that path reconstruct the exact 86,400-byte overlay plane, and one hundred logger/menu-hop repetitions prove diagnostics never reach stdout and preserve immediate and delayed transition classifications.  One hundred stalled-sink reserve runs, output staging, random-access, fragmented-SPU, AC-3 recovery, Program Stream and audio-file seek, audio UI and visualizer regressions pass; reserve, staging, logger/menu-hop and production ownership paths also pass AddressSanitizer and UndefinedBehaviorSanitizer, and the reserve passes GCC analyzer.  The strict native helper builds and all four audio formats pass real READY/GO visualizer integration.  Local GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_MediaOnly_fddab62` at SHA-256 `f191264565c89e1e1115eae9a3debe186b9bf4b35556350e59bc53f88460a8e0`; it has no dynamic section and contains the media-only logger, reserve-discard and complete protocol-one capability markers.  Main source `46638c7`, the output-reserve worker, libdvdnav navigation policy, decoder, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer so the old helper stops, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_MediaOnly_fddab62`, preserve executable mode, and retain Main `MiSTer_NavDrain_46638c7`, the current visualizer asset and RBF.  Reboot, start the golden physical DVD with telemetry, and press `M` once early enough to reproduce the rejected run; acceptance requires libdvdnav diagnostics in the helper log, a navigation-reserve discard, `READY`, exactly one Main reset and `GO`, a surviving helper and a displayed root menu without `Resource temporarily unavailable`.  Then move and activate the authored selector, return to playback, press `M` again after sustained playback, exercise `N` and `P` once each, and return fresh results for physical acceptance.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 903 COMMIT Unreleased 46638c7 2026-09-02T07:07:46-07:00

#### Coming From:

Unreleased 46638c7

#### Purpose:

Record the physical result for Main's unresolved-navigation drain correction and localize the remaining root-menu failure.

#### Outcome:

The user's golden physical-DVD run rejects source `46638c7`, but proves its Main correction removed the prior pre-classification deadlock.  Main sends root-menu command `0x09` at 8.639313 seconds after submitting 3,297,484 bytes; the helper immediately reports a successful libdvdnav root command and stream hop, Main continues through pipe-read events 205 through 209 and reaches 3,377,823 submitted bytes, then the helper reports `flushing navigation barrier failed: Resource temporarily unavailable`, closes stdout and exits with code one at 8.700876 seconds.  No navigation-reserve completion, `READY`, Main reset or `GO` follows.  The 234,438-byte log at SHA-256 `8be78e6d0944ee3ad894087acfeed43b4356bd7e428073ccb6ab8afc399c1500` therefore narrows the failure to the helper's redundant post-discard `fflush`: once the physical-DVD reserve exists, every video and overlay write bypasses stdio and uses the reserve, whose worker intentionally owns the underlying descriptor in nonblocking mode, yet `discard_reserved_output` flushes the unused `FILE` after a successful reserve discard and treats its `EAGAIN` as fatal.  The 339,869-byte screenshot at SHA-256 `402f425f293bcc3e514b9419ec078d2a7bf967d6db06011e93479587891e518c` shows the resident dark DVD frame with telemetry rather than new decoder corruption, and the 675-byte schema-21 sidecar at SHA-256 `5bbd46558cbd8e698b199e615352b5c026acd83a2fcd9a572dfb4f70a293f1fa` is checksum-valid with XOR `2ef579fc`.  Source `46638c7` is retained as the correct Main boundary but is not hardware-accepted with the source-`78646bd` helper.

#### Next Steps:

Preserve Main source `46638c7`, libdvdnav behavior, decoder, visualizer, RTL and RBF.  After user approval, make one helper-only ownership correction so reserve-backed output either drains or discards the reserve and never also flushes its unused stdio stream: make normal flush select reserve drain or `fflush` exclusively, remove the post-discard `fflush`, and remember reserve ownership through shutdown so destroying the reserve is not followed by another stdio flush.  Extend the production helper-output regression with a full nonblocking pipe and buffered stdio sentinel that reproduces the current fatal `EAGAIN`, while retaining the stalled-sink discard, exact-output, menu-hop, random-access, AC-3, seek and visualizer regressions; build only a new helper locally and repeat the same early root-menu command with Main `46638c7` retained.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 902 COMMIT Unreleased 46638c7 2026-09-02T06:50:22-07:00

#### Coming From:

Unreleased 78646bd

#### Purpose:

Keep Main draining ordinary DVD output until an unresolved navigation command is classified as continuation or stream hop.

#### Outcome:

Source `46638c7` removes only `navigation_pending` from Main's post-control barrier return condition so unresolved DVD navigation follows the existing seek-decision behavior.  Main polls the private control channel first on every media poll and continues submitting old-session bytes while no decision is available; `MENU_CONTINUE` clears the pending state without a download reset, while `READY` atomically changes the state to `chapter_barrier`, lowers download and returns before any further transfer so the established pipe discard and `GO` sequence remains unchanged.  The modeled lifecycle proves that unresolved navigation continues submitting, menu continuation performs no reset, discard or `GO`, and stream-hop `READY` performs exactly one reset and `GO`; the strict test passes both optimized and AddressSanitizer/UndefinedBehaviorSanitizer builds.  Both Main patches apply in order to pinned upstream `0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f`, and local GNU 10.2.1 produced the 1,182,692-byte stripped ARMv7 hard-float executable `host/build/MiSTer_NavDrain_46638c7` at SHA-256 `e387a2283bd55e1d44d263c110ac6b068df7ef6554b810451cad9aca8321c827`.  The source-`78646bd` helper remains byte-identical at SHA-256 `aea920527750897528e06700ddf15eb0ce3429f56878af1cb016f6385e0da59b`; the decoder, helper protocol, libdvdnav policy, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer, replace only `/media/fat/MiSTer` with `host/build/MiSTer_NavDrain_46638c7`, preserve executable mode, retain the source-`78646bd` helper and existing visualizer asset/RBF, then reboot.  On the golden physical DVD, press `M` once early enough to reproduce the rejected pre-classification freeze and once after sustained playback; each classified hop must complete reserve discard, navigation `READY`, one Main reset and one `GO` without freezing.  Then activate the authored menu choice, exercise previous and next chapter once each, and return fresh telemetry-enabled results for physical acceptance.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 901 COMMIT Unreleased 78646bd 2026-09-02T06:48:08-07:00

#### Coming From:

Unreleased 78646bd

#### Purpose:

Record the first physical result for interruptible reserve discard and localize the remaining root-menu freeze to Main's pre-classification drain hold.

#### Outcome:

The user's golden physical-DVD run with the source-`78646bd` helper still freezes on the first `M`, but it no longer reaches the prior post-classification deadlock.  Main submits root command `0x09` at 5.389484 seconds after transferring 6,088,666 bytes, and the 179,060-byte log at SHA-256 `2877bfd845095dae6de6e2a0a55f01fcf3fd7255fde98f154a310a9d3964a461` ends immediately without libdvdnav's command, hop or continuation diagnostic, the new reserve-discard completion, `READY`, download reset or `GO`.  The 382,102-byte screenshot at SHA-256 `ea2f2ff083b18310376c1ff9142fcad6ff79eeceb8ea66b84d49a6f929a5ce1e` is another intact resident frame rather than decoder corruption, and the 675-byte schema-21 sidecar at SHA-256 `ebc29db93702f67d2d2a73d12d0de5cde6c252bf473da6da343ac29f3586342d` is checksum-valid.  Static control-flow comparison proves the earlier circular wait now occurs before command classification: Main returns from every poll while `navigation_pending`, the helper is blocked producing into the undrained reserve and pipe, and its single program-stream thread therefore cannot return to `control_read_command`; ordinary file seeking already avoids this exact failure by continuing media transfer while `seek_pending` until the helper decides between continuation and `READY`.  Source `78646bd` remains necessary for the later classified-hop discard boundary but is rejected alone on hardware.

#### Next Steps:

Preserve the source-`78646bd` helper, libdvdnav behavior, decoder, RTL, RBF and visualizer asset.  After user approval, make one bounded Main correction that treats unresolved DVD navigation like the existing unresolved seek decision: poll the control channel first, continue ordinary transfer while only `navigation_pending` remains, and stop immediately when `READY` converts it into the existing reset barrier; `MENU_CONTINUE` will retain byte-exact uninterrupted output, while a stream hop can only send old-session bytes before the helper's reserve discard and Main's subsequent reset remove them.  Extend the modeled Main lifecycle test to require submitted bytes during unresolved navigation, zero discard or reset on continuation, and exactly one reset plus `GO` on `READY`; apply and compile the complete patch stack against pinned upstream, build only a new Main locally, and repeat the same first `M` with the source-`78646bd` helper.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 900 COMMIT Unreleased 78646bd 2026-09-02T06:26:43-07:00

#### Coming From:

Unreleased 5327358

#### Purpose:

Make physical-DVD navigation discard interrupt an output record blocked on Main without changing continuation output or decoder behavior.

#### Outcome:

Source `78646bd` makes the physical-DVD reserve writer own its output descriptor in nonblocking mode, poll ordinary backpressure in bounded ten-millisecond intervals and restore the original descriptor flags at teardown.  Once libdvdnav definitively requests a stream-hop discard, the worker now cancels the unwritten suffix of an active record together with both queued lanes instead of waiting forever for Main to drain that record; Main's existing barrier still discards the already-written pipe prefix before `GO`, while a request resolved as `MENU_CONTINUE` never invokes discard and retains complete byte-exact delivery.  One hundred strict focused runs reproduce a full pipe with no reader, require discard in under 500 milliseconds, account for every pipe and canceled byte, reject stale bytes after the barrier and preserve ordinary records, priority order and descriptor flags; the same boundary passes AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer checks, and output staging passes one hundred retained runs.  Production overlay output passes twenty exact 86,400-byte reconstructions, and DVD menu-hop, random-access, fragmented-SPU, AC-3 recovery and Program Stream seek regressions pass.  The native helper builds and reports the complete protocol-one capability set.  GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_NavDiscard_78646bd` at SHA-256 `aea920527750897528e06700ddf15eb0ce3429f56878af1cb016f6385e0da59b`; it has no dynamic section, and Main, libdvdnav policy, H.262 decoding, RTL, RBF and the source-`5327358` visualizer asset are unchanged.

#### Next Steps:

Exit MediaPlayer so the existing helper stops, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_NavDiscard_78646bd`, restore executable mode if needed, and verify the recorded size and SHA-256 while preserving the installed Main, visualizer asset and timing-qualified RBF.  On the golden physical DVD, press `M` once within approximately four seconds as in the rejected run and again after sustained playback; each stream hop must log reserve discard, navigation `READY`, Main reset and `GO` without freezing.  Then activate the authored menu choice, exercise previous and next chapter once each, and confirm a menu-space continuation retains its resident frame and selector without losing output; return fresh telemetry-enabled results for physical acceptance.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/output_reserve.c
- tools/test_output_reserve.c

#### Status:

- [x] Built
- [ ] Passed

---

## 899 COMMIT Unreleased 5327358 2026-09-02T06:23:24-07:00

#### Coming From:

Unreleased 5327358

#### Purpose:

Record the physical root-menu freeze and localize it to a circular wait at the DVD navigation output-reserve boundary.

#### Outcome:

The user's golden physical-DVD run starts successfully from `/dev/sr0`, inventories title one with 24 chapters, authenticates the disc, enters menu mode and submits 4,160,412 media bytes before Main sends root-menu command `0x09` at 4.024721 seconds.  Libdvdnav accepts the command, reports status `ok`, classifies a root stream hop at logical block 3395 and discards a 2,034-byte source-block tail, after which the helper log ends without the expected reserve-discard completion, navigation `READY`, Main download reset or `GO`; the 370,504-byte screenshot at SHA-256 `541ca0729e1eb2d4efe82823dc431540ca3d3177ac1821e48354d9f54c6da70f` consequently shows the last valid resident DVD frame rather than decoder corruption, and the matching 136,144-byte log has SHA-256 `7503f2162194a8547033ef1c1455077db0dd6a2bf2199cd337b017a78d4a0d2a`.  The 675-byte schema-21 telemetry sidecar at SHA-256 `1aac888676af9d1e6aa73af44e5ded3ab3737cb027c6cfdffc3a0b2c64b518c8` is checksum-valid.  Static localization identifies a timing-dependent circular wait inherited from the accepted DVD path: once `navigation_pending` is set, Main returns before draining helper stdout until it receives `READY`, while `output_reserve_discard` cannot let the helper send `READY` until its writer finishes the active record, and that writer can remain blocked on the undrained stdout pipe; pressing `M` early while the four-megabyte reserve is active exposes the race, independently of the audio-visualizer changes.

#### Next Steps:

Preserve libdvdnav behavior, the decoder, RTL, RBF, menu-continuation semantics and the accepted visualizer work.  After user approval, make one bounded navigation-transport correction that prevents the reserve writer from blocking discard completion while Main is waiting for `READY`, without discarding valid output when root or activation resolves as `MENU_CONTINUE`; add a deterministic filled-pipe regression that issues a root hop during an active multi-write record and requires bounded discard completion, exactly one `READY` and clean `GO`, retain the existing continuation case byte-for-byte, rebuild the helper and any required Main component locally, then repeat an early `M`, later `M`, activation and chapter-hop sequence on the golden disc.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 898 COMMIT Unreleased 5327358 2026-09-02T06:17:38-07:00

#### Coming From:

Unreleased 5327358

#### Purpose:

Record the eight-grade physical result and separate its remaining transition discontinuity from the unexpected startup-delay behavior.

#### Outcome:

The user's physical source-`5327358` run accepts the eight-grade visual range and loudness mapping: compared with four grades, intensity changes are easier to follow and quiet music remains dark and muted while louder, faster passages become brighter.  Hardware still rejects the transition itself because every selected three-picture GOP is encoded at one complete grade, so even the bounded adjacent-level slew necessarily cuts at a GOP boundary; additional envelope smoothing cannot remove that coded-picture discontinuity.  The user also reports that the visualizer appears as soon as music starts rather than after ten seconds.  No new result files were captured, and the source inactivity code remains unchanged and requests its first overlay CLEAR only after ten emitted-audio seconds, so current evidence cannot distinguish an interface overlay that never becomes visible from one that appears and is cleared early.

#### Next Steps:

Preserve the accepted radial animation, eight endpoint/intermediate grades, loudness thresholds, hysteresis, Main, RTL and timing-qualified RBF.  After user confirmation of whether the normal player screen never appears or appears briefly, make one helper-and-asset boundary: encode eight steady grade families plus the fourteen legal adjacent up/down transition families, interpolate each transition across its three pictures, and have the existing one-step selector choose a transition GOP so every old-to-new boundary is continuous while playback bandwidth remains unchanged.  Extend the real-helper regression to count emitted PCM frames at the first overlay CLEAR and require exactly ten seconds after launch and activity; if that passes but hardware starts visibly animated, correct initial overlay/video ordering, while an early software CLEAR requires fixing the inactivity epoch instead.  Audit the resulting versioned pack against the sixteen-megabyte loader ceiling, decode every steady and transition path with FFmpeg, rebuild only the helper and asset locally, and repeat the same FLAC passage.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 897 COMMIT Unreleased 5327358 2026-09-02T05:57:42-07:00

#### Coming From:

Unreleased 532bd8e

#### Purpose:

Smooth the accepted audio visualizer's loudness response without changing its underlying animation, transport or decoder path.

#### Outcome:

Source `5327358` preserves the exact two-second radial animation and its accepted darkest and brightest grades while expanding the synchronized pack from four to eight linearly interpolated grades.  The helper now separates the RMS target from the emitted grade, applies a one-eighth deadband around seven fixed thresholds and moves by at most one adjacent grade when each independent three-picture GOP begins, so near-threshold audio cannot chatter and a large loudness change becomes a bounded ramp of roughly one grade per 100 milliseconds.  Strict focused, AddressSanitizer and UndefinedBehaviorSanitizer tests prove fast attack, slow decay, hysteresis and the one-step maximum; GCC analyzer passes, and the audited 3,560,506-byte pack contains 160 valid indexed GOPs with payloads from 15,918 through 27,389 bytes and a deliberately switched stream that FFmpeg decodes without error.  Native and exact GNU 10.2 ARMv7 real-helper runs pass MP3, WAV, FLAC and Ogg Vorbis with two seek barriers, one boundary continuation, overlay inactivity clear and 378 through 381 decodable selected pictures; the unchanged no-pack fallback also passes all four formats.  The final 961,956-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_VisualizerSmooth_5327358` has SHA-256 `a7fb85e60882ba40ee5363cd467bb8daa3cfe97cd419b46fae253e8d6500a04d`, and `host/build/MediaPlayer_Visualizer_5327358.mmpvis` has SHA-256 `d4625fadb089ba84f3d9e64b1ff104db3e8ebc65a96b35e14b3727f165ec31d3`; Main, the protocol, RTL and the timing-qualified RBF are unchanged.

#### Next Steps:

Exit MediaPlayer so its helper stops, replace `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_VisualizerSmooth_5327358`, restore executable mode if needed, and replace `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` with `host/build/MediaPlayer_Visualizer_5327358.mmpvis`, verifying both recorded sizes and hashes while preserving the installed source-`532bd8e` Main and current timing-qualified RBF.  Replay the same dynamic FLAC passage through quiet, moderate, loud and peak sections; acceptance requires the unchanged gently blending radial animation and dark-to-bright correlation, but each loudness response must now appear as a smooth short pulse or ramp without the prior abrupt grade cuts or near-threshold flicker.  Confirm user activity still restores the interface and another ten seconds reveals the visualizer, then capture a fresh screenshot and telemetry-enabled log for acceptance or any remaining response issue.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- host/arm/audio_visualizer.h
- tools/generate-audio-visualizer.py
- tools/test_audio_visualizer.c

#### Status:

- [x] Built
- [ ] Passed

---

## 896 COMMIT Unreleased 532bd8e 2026-09-02T05:42:18-07:00

#### Coming From:

Unreleased 532bd8e

#### Purpose:

Record the first physical audio-visualizer result and localize its visible color and brightness snapping.

#### Outcome:

The user's physical FLAC run accepts the source-`532bd8e` visualizer as a functional and visually appealing MPEG background: the synchronized radial color pattern moves continuously, the ten-second inactivity path reaches it, and the 708,093-byte screenshot at SHA-256 `8bcc72a81f281ff1eab5b5b4efeda0fad9c2ef036ce0dcfb2d90d2f04b6b9e64` shows a clean decoded frame with the two-bit interface overlay and visible telemetry.  The matching 1,893,060-byte Main/helper log at SHA-256 `4418b5547d4e7791cc2c2695668522d8578f9bf1cec0fa7fae96a720ea31e9d4` proves the intended visualizer asset loaded, a 44.1-kHz FLAC session remained active through approximately 64.7 seconds and Main continued submitting media without a helper, transport or decoder failure; the 766-byte checksum-valid schema-21 word dump has SHA-256 `4ee1a9cd22d31b63663002b49963dc9cc5346060c532b5b2b453cdc90426a8cc`.  Hardware rejects only the response quality: color or brightness appears to snap unpredictably while the underlying pattern changes gently.  Static localization shows that the prototype selects one of four widely separated brightness, contrast and saturation grades at every independent three-picture GOP from an RMS envelope with fixed thresholds and no hysteresis, so ordinary threshold crossings create the observed abrupt cuts; this is deterministic loudness quantization rather than damaged MPEG data or random decoder behavior.

#### Next Steps:

Preserve Main, RTL, the timing-qualified RBF, the inactivity and overlay paths, and the legal synchronized independent-GOP architecture.  After user approval, refine only the helper and generated visualizer asset to use eight closely spaced grades across the accepted range, threshold hysteresis and a one-grade-per-GOP slew limit so rapid loudness changes become short ramps and near-threshold material cannot chatter; add deterministic attack, decay, deadband and maximum-step tests, rebuild the ARM helper and asset locally, verify the deliberately switched stream with FFmpeg, then repeat the same dynamic FLAC passage and require continuous motion with visibly smoother loudness-correlated pulses and no abrupt grade cuts.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 895 COMMIT Unreleased 532bd8e 2026-09-02T04:45:00-07:00

#### Coming From:

Unreleased 7e152d5

#### Purpose:

Prototype an inactivity-triggered standalone-audio visualizer by coupling PCM loudness to synchronized legal MPEG-2 loop variants while preserving the normal player interface and existing decoder behavior.

#### Outcome:

Source `532bd8e` adds a deterministic four-level visualizer pack generator and a bounded ARM runtime that validates every indexed payload as one sequence-led, closed, intra-starting legal H.262 GOP, computes a fast-attack and slow-decay stereo RMS envelope, selects a complete synchronized color grade at each loop phase, and admits at most 4,096 video bytes at a PCM boundary with two GOPs of lead.  The accepted player interface is quantized into the existing opaque two-bit DVD overlay, remains visible with elapsed, total, remaining and progress updates, clears after ten emitted-audio seconds without activity, restores from its resident plane when Main reports pause or resume, and republishes completely after every seek reset and at clean EOF; a missing or invalid pack retains the prior full-color framebuffer UI.  The generated 1,751,247-byte pack has twenty three-picture GOPs at each of four levels, its deliberately level-switched stream decodes without FFmpeg errors as 720-by-480 at 30000/1001, and a twelve-second modeled transport measured approximately 0.49 MB/s including PCM, video and overlay against the prior physical path's approximately 0.82 MB/s.  Strict unit, sanitizer, fallback and real-helper regressions pass; native and exact ARMv7 helpers pass MP3, WAV, FLAC and Ogg with two READY/GO seeks, one boundary continuation, post-reset overlay republishing, one inactivity clear and 369 to 375 decodable selected pictures, while the patched Main applies to pinned upstream and compiles with GNU 10.2.  GNU 10.2 produced the 961,956-byte static ARMv7 helper `host/build/MediaPlayer_Helper_Visualizer_532bd8e` at SHA-256 `6b7079525f87907e8c45241f28501cd8ee01eae00b0ebcf1357b9b1c03f1d836`, the 1,182,692-byte ARMv7 Main `host/build/MiSTer_Visualizer_532bd8e` at SHA-256 `f2da76ee4882faa0192e086ca12882959c3bb26fea403de0facfc3c73c768d57`, and `host/build/MediaPlayer_Visualizer_532bd8e.mmpvis` at SHA-256 `2024e8d4e4536bb45662d9e8787d3cf098583442bc24d6aa12a73a4db4dbf85a`; the H.262 decoder, display protocol, RTL and timing-qualified RBF are unchanged.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_Helper_Visualizer_532bd8e` as `/media/fat/linux/MediaPlayer_Helper`, `host/build/MiSTer_Visualizer_532bd8e` as `/media/fat/MiSTer`, and `host/build/MediaPlayer_Visualizer_532bd8e.mmpvis` as `/media/fat/linux/MediaPlayer_Visualizer.mmpvis`, preserve executable mode on the two programs and the current timing-qualified RBF, then reboot because Main changed.  Play a dynamic standalone audio track and require the normal player interface for the first ten seconds, a seamless moving background afterward, visible color and brightness response to quiet, normal, loud and peak passages without damaged frames, interface restoration and a fresh ten-second delay after resume or seek, correct timers after seeking, and a completed interface at clean EOF before Play restarts the file.  Spot-check all four standalone formats and temporarily rename the pack once to confirm fallback to the accepted full-color screen; report acceptance or place fresh Main/helper logs and screenshots in `.ai/current_results` for any failure.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/audio_visualizer.c
- host/arm/audio_visualizer.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/generate-audio-visualizer.py
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c
- tools/test_audio_visualizer.c
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 894 COMMIT Unreleased 7e152d5 2026-09-02T03:50:37-07:00

#### Coming From:

Unreleased 09b1d28

#### Purpose:

Center the standalone-audio elapsed and remaining displays and replace the disabled track-time placeholder with the decoded track duration.

#### Outcome:

Source `7e152d5` replaces the combined left-aligned timing string and disabled track placeholder with three independently centered fields spanning the progress-bar width: `ELAPSED`, `TRACK` and `REMAIN`, all rendered with the same font scale on vertical baseline 412.  The fixed track duration derives from decoded PCM-frame length and sample rate and rounds partial final seconds up like remaining time, while elapsed retains completed-second truncation.  Pixel-level regressions verify all three values at their computed horizontal centers during 44.1 and 48 kHz playback, after seeking and at a fractional-second clean completion where elapsed is 100 seconds, total is 101 seconds and remaining is zero; the renderer and full helper pass AddressSanitizer/UndefinedBehaviorSanitizer coverage, and native plus final ARM real-helper runs pass MP3, WAV, FLAC and Ogg with exact final values and valid transaction boundaries.  GNU 10.2 produced the 957,860-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_TrackTime_7e152d5` with SHA-256 `495606437ef2d855546d8a1906b8a375b8666984f10a9e267f7d563ee9f75859`; the source-`09b1d28` Main, replay behavior, protocol, RTL and timing-qualified RBF are unchanged.

#### Next Steps:

Exit MediaPlayer so the running helper stops, install `host/build/MediaPlayer_Helper_TrackTime_7e152d5` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, and preserve `host/build/MiSTer_ReplayReady_09b1d28` as `/media/fat/MiSTer` plus the current timing-qualified RBF.  Play a standalone audio file and confirm that elapsed, total track and remaining time are horizontally centered in three balanced regions and vertically aligned on one baseline, that total remains fixed while elapsed and remaining update and seek correctly, and that clean EOF still shows full progress with zero remaining before Play restarts the file.  Report hardware acceptance or place a fresh screenshot and Main/helper log in `.ai/current_results` for any discrepancy.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 893 COMMIT Unreleased 09b1d28 2026-09-02T02:46:35-07:00

#### Coming From:

Unreleased 4063cf0

#### Purpose:

Replace ordinary-file clean-EOF retention with a replay-ready paused state while preserving the final valid presentation.

#### Outcome:

Source `09b1d28` makes a clean ordinary MPG or standalone-audio EOF replay-ready and paused while preserving the final valid resident frame; the next Play input relaunches the retained source and index through the normal fresh-download path from byte zero, while selecting another file, explicitly stopping, leaving the core, a failed helper exit and ISO/DVD completion clear or bypass replay state as appropriate.  Standalone audio now completes by draining the already-open projected final UI frame from its current byte offset through exactly one COMMIT, eliminating the nested BEGIN and hybrid YUV frame demonstrated by entry 892 while preserving exact full progress, final elapsed time and zero remaining time.  Strict focused seek, Program Stream, AC-3, DVD, staging, renderer and modeled Main lifecycle tests pass, sanitizer coverage passes, the patch applies to pinned upstream and the exact-source ARMv7 Main compiles, and the final ARM helper passes real MP3, WAV, FLAC and Ogg runs with valid transaction boundaries and exact final UI state.  GNU 10.2 produced the 957,860-byte static ARMv7 helper `host/build/MediaPlayer_Helper_ReplayReady_09b1d28` with SHA-256 `380ca98301de0a0b2ae84cede46523a5254fbf8046bd9868f76c2a02653f46c3` and the 1,182,692-byte ARMv7 Main `host/build/MiSTer_ReplayReady_09b1d28` with SHA-256 `6c6ace67a1114d609ca339e0aa11cb71756a149257896169c8d72f7cab75c784`; RTL, RBF, codecs, DVD behavior and accepted timing are unchanged.

#### Next Steps:

Install both `host/build/MediaPlayer_Helper_ReplayReady_09b1d28` as `/media/fat/linux/MediaPlayer_Helper` with executable mode and `host/build/MiSTer_ReplayReady_09b1d28` as `/media/fat/MiSTer`, preserving the current timing-qualified RBF.  On hardware, let a standalone audio file reach natural EOF and confirm that the final undistorted UI remains visible with full progress, correct elapsed time and zero remaining time, then press Play and require the same file to restart from the beginning; repeat natural EOF and Play restart with an ordinary MPG, and confirm that an oversized standalone-audio seek remains a no-op without interrupting playback.  Report acceptance or place fresh Main/helper logs and a screenshot in `.ai/current_results` for any discrepancy.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 892 COMMIT Unreleased 4063cf0 2026-09-02T02:40:18-07:00

#### Coming From:

Unreleased 4063cf0

#### Purpose:

Record physical rejection of the clean standalone-audio EOF presentation and localize the distorted retained frame.

#### Outcome:

The fresh physical standalone-audio run rejects source `4063cf0` as a complete EOF fix while confirming that its Main lifecycle correction works: all 14 requested seeks receive one helper READY event and one Main reset, playback reaches natural EOF, the helper exits normally with status zero, Main records `finish reason=eof-retained` with download still asserted and no control, transport, read or process failure occurs.  The 2,527,165-byte combined log at SHA-256 `d66ccd4e85d476bd47c8c148ce707b4c3f440b986800d0946e91eddc82349503` instead proves that the final synchronous UI function starts command `0x10` at stream offset 33,322,040 while the ordinary UI frame opened at offset 33,186,232 still has only 24 of 127 data records, or 98,304 of 518,400 bytes, submitted.  The FPGA audio-UI receiver rejects a second BEGIN while `frame_open` is set but preserves the old write index, then accepts enough bytes from the new full frame to finish and commit a hybrid YUV buffer; the 19,322-byte 1,920-by-1,080 screenshot at SHA-256 `c5aac8ce6de56d320b913907206c13ae7f80ff7ad43402117241aa88a68b83b2` visibly shows the resulting shifted and repeated interface planes.  This is a helper publication-state fault introduced by the exact-final-frame addition, not a decoder crash, seek reset, failed clean-EOF retention or FPGA timing fault.  The 2,818-byte telemetry sidecar at SHA-256 `53805e1c7c4f1f4d44f0f0fa390382eb331781268afda439bb41aac8ac8e8456` contains no supported telemetry matrix and adds no contrary evidence.  MPG natural EOF was not exercised by this result set.

#### Next Steps:

Obtain approval for a helper-only correction that makes final UI completion drain the already-open projected final frame from its current byte offset through one COMMIT instead of resetting host state and emitting a second BEGIN.  Extend the renderer regression to complete a partially published final frame with exactly one BEGIN, 127 total data records, one COMMIT, full progress and zero remaining time, and make the real-helper parser reject nested BEGIN events so this hardware failure is reproducible locally.  Rebuild only the ARM helper, preserve source-`4063cf0` Main and the timing-qualified RBF, then repeat standalone-audio natural EOF and separately verify that an ordinary MPG retains its final frame.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 891 COMMIT Unreleased 4063cf0 2026-09-02T01:51:36-07:00

#### Coming From:

Unreleased e05ede0

#### Purpose:

Make valid and boundary standalone-file seeks transactional, preserve the resident presentation at clean EOF, and replace standalone-audio time placeholders with real elapsed and remaining counters.

#### Outcome:

Source `4063cf0` adds the `audio-file-seek-v2` continuation event and makes Main defer every file-seek reset until the helper returns READY, so exact-end and past-end standalone-audio requests now complete with zero resets while valid standalone-audio and Program Stream targets retain one reset and GO barrier.  Main distinguishes a clean ordinary `file:` helper exit from errors and leaves download asserted for the final MPG frame or completed audio interface; ISO/DVD EOF, nonzero or signaled exits, transport failures, explicit stop and core changes retain teardown.  The audio renderer now derives elapsed floor-seconds and remaining ceiling-seconds from its absolute PCM timeline, republishes both after seeks and synchronously commits an exact full-progress, zero-remaining frame before clean audio EOF.  Strict focused tests pass for seek arithmetic, Program Stream indexing, AC-3 resynchronization, DVD random access, menu hops, SPU, output reserve/staging, UI rendering and modeled Main lifecycle; the renderer and real helper also pass AddressSanitizer/UndefinedBehaviorSanitizer coverage, and native plus final ARM real-file runs pass MP3, WAV, FLAC and Ogg with two valid READY/GO seeks, one continuation no-op and exact final timers.  The patched Main applies to pinned upstream and compiles as ARMv7.  GNU 10.2 produced the 957,860-byte static ARMv7 helper `host/build/MediaPlayer_Helper_SeekEOFTime_4063cf0` with SHA-256 `3263c64789add0cbcba67410f08dee2b65441331c82e2b36978b3fa956a3d485` and the 1,178,588-byte ARMv7 Main `host/build/MiSTer_SeekEOFTime_4063cf0` with SHA-256 `a513ca83b806c61593283c215384d2a397a44d791a0c9841d7f2f288b1d20fef`; RTL, RBF, codecs and accepted timing are unchanged.

#### Next Steps:

Exit MediaPlayer and install `host/build/MediaPlayer_Helper_SeekEOFTime_4063cf0` as `/media/fat/linux/MediaPlayer_Helper` with executable mode and `host/build/MiSTer_SeekEOFTime_4063cf0` as `/media/fat/MiSTer`, preserving the current timing-qualified RBF.  Validate one valid forward and backward seek plus an oversized forward no-op in standalone audio, confirm elapsed, remaining and progress move together and reach exact completion without black, then play an ordinary MPG through natural EOF and require its final frame to remain instead of black.  Report hardware acceptance or place fresh Main/helper logs and a screenshot in `.ai/current_results` for any discrepancy; DVD behavior needs only a smoke check because its lifecycle and RBF are unchanged.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_audio_ui_output.c
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 890 COMMIT Unreleased e05ede0 2026-09-02T01:45:42-07:00

#### Coming From:

Unreleased e05ede0

#### Purpose:

Record physical rejection of the oversized standalone-audio seek no-op and localize the apparently crashing black end state shared by FLAC and MPG playback.

#### Outcome:

The fresh 8,190,216-byte combined Main/helper log at SHA-256 `43714a1990debf89f5b455fbcc8636e7cf0e3b9199add230a506cba717ced8f8` proves that source `e05ede0` preserves three valid ten-second forward seeks, two valid one-minute forward seeks, one valid five-minute forward seek and four valid ten-second backward seeks, each with its READY/GO barrier and continued FLAC playback.  The final five-minute forward command at 132.644028 seconds is correctly rejected by the helper at frame 24,173,800 of 32,108,544, but patched Main has already toggled download, set `chapter_barrier` and begun discarding helper output before it sends every seek command.  Because the helper's boundary no-op sends neither READY nor a continuation event, Main never releases that barrier, submits no byte beyond 96,983,816 and repeatedly drains all later PCM and audio-interface records without hardware pacing; the helper consequently races through the remaining file and reaches EOF only 8.173783 seconds later.  It exits normally with wait status `0x0`, no signal, fatal report or transport fault, so this is not a process crash, but Main releases download and the 1,920-by-1,080 screenshot at SHA-256 `d29ecd17bc05dc3f2f280ad4ea2d85a6b69bc4b9d611efd648687dde93f12146` is completely black, reproducing the user's apparent end-of-file crash.  The user additionally reports the same visible behavior when an MPG reaches its end; there is no fresh MPG log in this result set, but static inspection confirms that every ordinary helper EOF, regardless of file type, calls Main's shared `finish_download`, deasserts download and therefore removes the resident presentation.  The unchanged 2,818-byte telemetry sidecar at SHA-256 `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004` contains no diagnostic matrix and adds no FPGA fault evidence.  This rejects `e05ede0` as a complete hardware fix, exposes the missing Main/helper seek-decision handshake that the helper-only real-file regression did not model and separately identifies the black clean-EOF presentation as a shared lifecycle policy rather than an MPG or audio decoder crash.

#### Next Steps:

Preserve the current timing-qualified RBF and treat two corrections as separate approval boundaries.  First, make seek decision a distinct helper/Main protocol phase: Main sends a requested jump without toggling download or discarding output, the helper reports an explicit no-op continuation when the target is the current boundary, and only a valid target's READY event makes Main reset download, discard the old session boundary and send GO; an integrated patched-Main regression must require zero reset, zero barrier and continued submitted output for exact-end and past-end requests while retaining exactly one reset and READY/GO barrier for every valid seek.  Second, after the user selects the desired clean-EOF behavior, change the shared Main lifecycle so normal FLAC, other standalone audio and MPG completion no longer looks like a crash, with focused coverage distinguishing a successful exit from a signaled or nonzero helper failure.  Build only the helper and patched Main locally, preserve the RBF and repeat physical FLAC plus MPG validation after the approved boundaries.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 889 COMMIT Unreleased e05ede0 2026-09-02T00:31:57-07:00

#### Coming From:

Unreleased e580270

#### Purpose:

Prevent oversized forward jumps in standalone audio files from terminating playback at the exact end and appearing to freeze the core.

#### Outcome:

The fresh hardware log localizes the reported Ogg incident to the shared audio seek boundary rather than the Ogg parser, decoder or FPGA: a sixty-second jump from frame 1,526,440 in a 3,309,167-frame 44.1-kHz file clamped to exact EOF, after which the helper exited normally with status zero and Main left a black display following its reset.  Source `e05ede0` makes any standalone-audio forward target that would reach or pass exact EOF resolve to the current frame, and the helper consumes that command before marking a seek pending, touching the decoder or entering the READY/GO reset barrier.  Focused strict and AddressSanitizer/UndefinedBehaviorSanitizer arithmetic tests cover exact-end, past-end and overflow cases; real-helper regressions against native and final ARM builds prove valid forward and backward seeks still use exactly two barriers while an oversized sixty-second jump uses no third barrier and playback continues for MP3, WAV, FLAC and Ogg Vorbis.  The GNU 10.2 build produces the 953,764-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_AudioSeekEOF_e05ede0` with SHA-256 `cdc9cb350c7f4e87aac2cd33a991d8bc32ff2ccd52d492fca41374abde0cbc4a`; Main, RTL, RBF, ordinary MPG seeking, DVD navigation and valid standalone-audio seeks are unchanged.

#### Next Steps:

Exit MediaPlayer and install `host/build/MediaPlayer_Helper_AudioSeekEOF_e05ede0` as `/media/fat/linux/MediaPlayer_Helper` with executable mode while preserving the installed source-`72bdccc` Main and timing-qualified RBF.  Reopen the short Ogg file and repeatedly issue one-minute and five-minute forward jumps that exceed its remaining duration; acceptance requires uninterrupted playback and an unchanged audio interface with no black-screen reset, then spot-check one valid backward and forward jump and another standalone format before reporting hardware acceptance or collecting fresh telemetry-enabled evidence for any discrepancy.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_file_seek.c
- host/arm/media_player_helper.c
- tools/test_audio_file_seek.c
- tools/test_audio_file_seek.py

#### Status:

- [x] Built
- [ ] Passed

---

## 888 COMMIT Unreleased e580270 2026-09-01T23:49:02-07:00

#### Coming From:

Unreleased 9397fa7

#### Purpose:

Make the standalone-audio progress bar represent the current absolute track position instead of repeating once per minute.

#### Outcome:

Source `e580270` replaces the accepted layout's repeating one-minute activity ruler with true track-relative progress for standalone MP3, WAV, FLAC and Ogg Vorbis playback.  Once the decoder establishes its output-frame length, a one-time consumer callback configures the UI; the renderer retains the absolute PCM-frame position, projects it to the next one-hertz publication, rescales after every fixed seek and clamps at the exact end.  An overflow-safe binary search maps even a `UINT64_MAX` timeline across the existing 652-pixel interior without wide-integer target support.  MP3, WAV and FLAC use miniaudio's reported length; callback-mode Ogg Vorbis returns a successful zero length, so file media sources now support end-relative seeking and the consumer reads at most the final 65,307-byte Ogg page, requiring a version-zero end-of-stream page ending exactly at EOF and using its authoritative granule position without scanning or decoding the whole file.  Strict and AddressSanitizer/UndefinedBehaviorSanitizer renderer tests pass at 44.1 and 48 kHz with exact one-quarter, one-half, 37-second seek, complete and maximum-64-bit progress checks; their first two frame hashes are `ea64e99d` and `eb334e45`.  Clean and fully instrumented real-helper regressions pass forward and backward seeking for all four formats while matching the UI duration to the decoder timeline; each twelve-second fixture reports 529,200/44,100 or 576,000/48,000 frames as appropriate.  The inspected deterministic YCbCr preview has SHA-256 `9fc41135e21762c078b570b553defe05b3fb9db8cbaabdb25cc480fc94157ad7`, and its PNG conversion has SHA-256 `242ea03862c9f20a48f329e0cd6f5144654057b781e0840940af3f1cc2ecfb5e`.  The GNU 10.2 build produces the 953,764-byte static ARMv7 helper `host/build/MediaPlayer_Helper_AudioProgress_e580270` with SHA-256 `e18854df1f64c6dd61b50c6f7b3463f2e88f5f1ad5f89f9213369a9e7c9295b4`; the accepted layout, displayed time placeholders, one-hertz cadence, bounded interleaving, atomic publication, codecs, audio priority, controls, Main, RTL, RBF, video and DVD paths remain unchanged.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_Helper_AudioProgress_e580270` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, and preserve the installed source-`72bdccc` Main and timing-qualified RBF.  Re-enter the core and play a track with a known duration long enough to distinguish file-relative motion from the former one-minute repeat; acceptance requires the bar to begin near zero, advance monotonically in proportion to the full track, jump to the correct fraction after ten-second, one-minute and five-minute seeks in either direction, and approach the right edge at the end while audio remains clean.  Spot-check MP3, WAV, FLAC and Ogg Vorbis where practical, then report hardware acceptance or enable telemetry before playback and collect a fresh screenshot and helper/Main log for any discrepancy.

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

- [x] Built
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
