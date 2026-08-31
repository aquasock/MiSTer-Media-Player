## 821 COMMIT Unreleased 53ccc04 2026-08-31T07:45:34-07:00

#### Coming From:

Unreleased e99cb28

#### Purpose:

Make authored DVD-menu highlights visible and preserve the resident video frame across overlay-only menu transitions without changing the FPGA build.

#### Outcome:

Source `53ccc04` makes displayed libdvdnav button state authoritative over a later scheduled subpicture stop, classifies successful activation as either a menu continuation or stream hop, adds control event `0x84` for the continuation, and makes Main defer its download reset until that decision arrives.  Menu continuations discard only stale helper block and still state while preserving the FPGA's resident video frame; title exits and root calls retain the ready, discard, reset and go barrier.  The focused scheduled-stop/highlight and stream-hop/menu-continuation tests pass, and the exact native helper builds with `-Werror`.  The corrected Coming to America authored-directory harness completes in 1.67 seconds with all six commands, three real directional transitions, one root ready barrier, one activation continuation acknowledgment, 17 overlay commits, 1,468,899 plane bytes, 1,311 visible highlighted states and 4,637 nonzero pixels in the largest selected rectangle.  Exact source `53ccc04` builds a 904,564-byte static stripped ARMv7 helper at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f` and a 1,174,492-byte patched Main at SHA-256 `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496` under `/home/vash/MiSTer-Media-Player-53ccc04/host/build`; RTL, QSF, RBF and Quartus are unchanged.

#### Next Steps:

The user should manually replace `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MediaPlayer_Helper` and the MiSTer root `MiSTer` executable with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MiSTer`, preserve the installed RBF, verify the recorded SHA-256 values and executable modes, then restart MediaPlayer.  Press `M`, verify that a visible highlight moves among all authored buttons, activate Scene Selection and confirm its submenu retains the background instead of going black, then activate a title and confirm its stream-hop barrier starts playback cleanly; leave the resulting screen and helper log available if any failure occurs.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/dvd_spu.c
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 820 COMMIT Unreleased e99cb28 2026-08-31T07:37:10-07:00

#### Coming From:

Unreleased e99cb28

#### Purpose:

Capture the source-`e99cb28` physical-menu result and isolate invisible selection and black submenu activation from DVD navigation itself.

#### Outcome:

Absolute-path readback verifies that the installed 904,564-byte helper is the exact source-`e99cb28` candidate at SHA-256 `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`, and its unique command diagnostics prove the running helper receives every keyboard arrow.  Across two runs the physical disc reports four authored buttons and repeatedly performs real transitions among buttons 1 through 4 with valid changing rectangles and selection palette `000feb80`; the final activation occurs on button 4 at rectangle 439,389 through 574,436, then completes a zero-tail ready barrier, emits a new subpicture and enters an indefinite still without a decoder fatal.  The 890,796-byte menu capture `/tmp/entry820_menu_no_highlight.png`, SHA-256 `d50b24341f0e0bd222608ba28c5e3261498b485e4a061e10c4fea6d235adc09b`, visibly identifies button 4 as Scene Selection while showing no selected-button highlight; its matching 2,840,191-byte log has SHA-256 `232052663a079b1a20db76d4b76416f940222f1c0417b324fa2bf2143c3e20de`.  Native read-only analysis of the same Coming to America authored fixture proves the helper's decoded plane contains nonzero pixels inside every changing button rectangle, but the root-menu configuration is published with menu set and visible clear because the subpicture decoder applies a later scheduled stop command immediately; the highlight pixels therefore cannot be composited.  The 31,888-byte post-activation capture `/tmp/entry820_same_menu_result.png`, SHA-256 `a36561c61b8a985cf20d67457a5ddf07bc65a925ea629ecea512ac324c89c84f`, and matching 3,259,439-byte log at SHA-256 `f713f582018d492013318f394f13f4159a61bc68b6632348b8a8fd343c21ce25` show the separate black submenu result.  Main currently deasserts download and resets the decoder before every activation command, so button 4's overlay-only Scene Selection transition loses the menu background frame that the authored indefinite still expects to retain.  Static RTL inspection confirms the white and black lower-left block is the existing always-on cadence telemetry overlay after a snapshot, not a DVD overlay corruption or post-Enter fatal.  Source `e99cb28` is rejected on hardware for visible menu interaction; no source, target file, Main, RBF or configuration is changed during collection.

#### Next Steps:

Keep RTL, QSF, RBF and Quartus frozen.  After user approval, make a bounded helper-and-Main change: a displayed libdvdnav highlight must force the decoded menu overlay visible despite a later unscheduled stop command, and activation must be classified before Main resets download so menu-to-menu overlay-only transitions preserve the resident video frame while title exits retain the existing clean decoder barrier.  Add native regressions that require visible root-menu style, nonzero highlighted pixels and distinct menu-continue versus stream-hop acknowledgments, then rebuild only the helper and patched Main for physical testing; removing or hiding the cadence telemetry block remains a deferred RBF concern.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 819 COMMIT Unreleased e99cb28 2026-08-31T07:01:17-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Synchronize DVD menu commands and selected-button highlighting to the displayed NAV packet while making directional transitions directly testable.

#### Outcome:

Source `e99cb28` retains a decoded copy of each delivered DVD NAV PCI, invalidates it across rewinds, chapter changes and successful menu hops, and uses that stable packet for directional selection, activation and highlight lookup instead of libdvdnav's potentially ahead current PCI.  Ordinary selected buttons now use the selection palette rather than the activation palette, and every root, direction and activation command logs the packet logical-block number, button count, before, authored target and after button numbers, status, highlight rectangle and palette.  The strict native helper builds with `-Werror`; the focused stale-tail test additionally proves retained-PCI invalidation, selection-palette choice, rectangle recovery and authored-target lookup; and the retained fragmented subpicture, palette, alpha, highlight and rejection test passes.  The strengthened Blazing Saddles authored-DVD harness records all six commands and real transitions Right 1-to-2 and Left 1-to-4 while preserving two ready barriers, both clean zero-tail hops and the overlay stream.  The closer Coming to America authored fixture also passes with Down 1-to-2, Left 2-to-1 and Up 1-to-4, twenty overlay configurations, 443 data records carrying 1,728,196 bytes and 1,574 style updates.  Exact detached source `e99cb28` reproducibly builds a 904,564-byte static stripped ARMv7 EABI5 helper at `/home/vash/MiSTer-Media-Player-e99cb28/host/build/MediaPlayer_Helper`, SHA-256 `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`; Main, RTL, QSF, RBF and Quartus are unchanged.

#### Next Steps:

The user should manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-e99cb28/host/build/MediaPlayer_Helper`, verify the destination SHA-256 is `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`, restart MediaPlayer and press `M` during first-play.  At the root menu, exercise all four arrows before Enter and leave the resulting screen visible; hardware acceptance requires visible selection movement wherever the logged authored target differs, command logs whose before and after values match that movement, clean root and activation hops, and no black dead end, diagnostic raster or decoder error.

#### Files Modified:

- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 818 COMMIT Unreleased 0e70319 2026-08-31T06:54:47-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Capture the exact source-`0e70319` physical-disc result after root-menu entry, directional input and Enter activation.

#### Outcome:

The user reports that keyboard `M` reaches the physical disc's menu, the arrow keys still cause no visible change, and Enter leaves a black screen.  The 30,212-byte matching capture `/tmp/entry818_menu_enter_black.png` has SHA-256 `7a50ed345aa27e73fef99d4a64f3704ef2752923cd58c82b553913631be70f82`, and the 11,543,671-byte helper log `/tmp/entry818_menu_enter_black_arm_helper.log` has SHA-256 `6d08df11102a2d437e062284d779af76a2fdb727ff1b877f2faefdcc8e9151b3`.  The capture is a black native active frame rather than an 800-by-600 telemetry raster, while the active source-`0e70319` helper records both root and activation hops with `discarded_block_tail=0`, completes both Main/helper ready barriers and remains alive without any fatal, decoder error or `0x0200` B-presentation failure.  The final activation does not produce a menu-leave transition; instead libdvdnav emits another overlay update and enters an indefinite authored still, so the stale-tail crash gate passes but full menu interaction does not.  Existing logs do not identify individual directional commands, selected button numbers or highlight rectangles, and the native harness only counted generic style events, so it cannot establish whether the helper used the NAV PCI synchronized to the displayed menu or merely returned a visually unchanged selection.

#### Next Steps:

Keep Main, RTL, QSF, RBF and Quartus frozen.  The next bounded helper-only cycle should log every direction and activation with the before and after button numbers, NAV logical-block number, authored neighbor and highlight rectangle, strengthen the native harness to require a real selection transition, and retain the NAV PCI associated with the displayed packet for button selection and activation instead of relying on libdvdnav's potentially ahead current PCI; rebuild and retest this same physical menu before expanding menu support.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 817 COMMIT Unreleased 0e70319 2026-08-31T06:43:56-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Verify that the user's manual helper replacement installed and launched the exact source-`0e70319` candidate before renewed menu testing.

#### Outcome:

Absolute-path FTP readback now reproduces `/media/fat/linux/MediaPlayer_Helper` as the expected 904,564-byte static ARMv7 executable at SHA-256 `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`, exactly matching `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` on the build PC rather than entry 816's identically sized old helper at `a00173f6`.  Read-only SSH inspection reports remote mode `755` and one active helper process, PID 767; hashing `/proc/767/exe` independently returns the same full `c8a39413` digest, proving the running process was launched from the replacement rather than retaining the deleted predecessor inode.  This verifies deployment only and makes no repository source, Main, RBF, playback option or target-file change by the agent; menu hardware acceptance remains pending.

#### Next Steps:

With the exact source-`0e70319` helper now active, press keyboard `M` during first-play, test Up, Down, Left and Right at the root menu before pressing Space, and leave any resulting screen visible.  Require `discarded_block_tail` logs for successful root and activation hops, visible highlight movement wherever the authored menu links adjacent buttons, successful activation without the `0x0200` B-presentation raster, and continued native 480i; capture the matching screen and helper log before accepting the candidate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 816 COMMIT Unreleased 0e70319 2026-08-31T06:23:51-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Capture the first reported menu-direction and activation result and verify whether the source-`0e70319` helper actually produced it.

#### Outcome:

The user reports that keyboard `M` now reaches the physical disc's root menu, none of the keyboard arrow keys causes a visible change there, and Space activation produces the diagnostic screen left visible for collection.  Main records root command `0x09` at 100.597697 seconds and activation command `0x08` at 129.365372 seconds; both helper ready/go barriers complete, with activation discarding 105,816 pending Main bytes before the helper emits another subpicture overlay and enters an indefinite authored still.  The 31,913-byte screenshot `/tmp/entry816_menu_activate_failure.png`, SHA-256 `c07d08ce0ffb238f319f483e772d787f0409c665be0258e6356f0ddd04bb1a0b`, has all 64 schema-20 headers, row indices and parity bits valid and checksum `d8861e13` matching.  Its fatal snapshot accepts only 18,182 bytes and runs 24,263 decoder clocks in a new 30000/1001 B-picture session at temporal reference 7 before latching exactly error `0x0200` with presentation-error state asserted; no syntax, reconstruction, writer, cache, transport-block or timestamp-conflict error appears.  The 6,666,888-byte matching log has SHA-256 `5349d190bc9bd01c4bcaf342ad6f465c0f97d480f6b887db77c699c48e77969c`.  Absolute-path readback proves this is not a test of source `0e70319`: installed `/media/fat/linux/MediaPlayer_Helper` is the previous 904,564-byte source-`a9899e0` helper at SHA-256 `a00173f62ec4a8b0d126ef48695e299b2fecf4e836bff28abdc1107fe62eac7c`, not the identically sized source-`0e70319` candidate at `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`.  The missing `discarded_block_tail` log independently confirms the old helper ran, so neither the activation failure nor the arrow-key observation accepts or rejects the new helper.

#### Next Steps:

Manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` from the build PC and verify the destination SHA-256 is `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`, not merely the shared 904,564-byte size.  Restart MediaPlayer, press `M` during first-play, test all four arrow directions before Space, and leave the result visible; source-`0e70319` is accepted only if its root and activation `discarded_block_tail` logs appear, the highlight moves where the authored menu offers adjacent buttons, activation avoids the `0x0200` raster, and native 480i remains active.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 815 COMMIT Unreleased 0e70319 2026-08-31T05:45:08-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Prevent stale bytes from the current DVD block from crossing successful authored-menu navigation hops into a reset decoder session.

#### Outcome:

Successful root-menu and button-activation calls now share a bounded cleanup that discards the unread tail of the current 2,048-byte libdvdnav block, clears stale terminal and still state, preserves the hop notification for the existing Main/helper ready barrier, and logs the command plus exact discarded-tail length.  The focused native regression proves both a 1,535-byte unread tail and an empty boundary are invalidated correctly, and the retained subtitle/highlight decoder test passes.  The enhanced authored-DVD navigation harness waits for active libdvdnav state rather than CSS preflight, accepts ISO files or DVD directories, and passes against the Blazing Saddles directory with one root hop, one activation hop, two ready/go barriers, directional input, two overlay configurations, 44 data records carrying 172,800 bytes, two commits and 496 style updates.  Exact detached source `0e70319` builds both the native helper and a 904,564-byte static ARMv7 hard-float `MediaPlayer_Helper` at `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` on the build PC, SHA-256 `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`; Main, RTL, QSF, RBF and Quartus remain untouched.

#### Next Steps:

The user should manually transfer only the exact ARM helper from the recorded build-PC path to `/media/fat/linux/MediaPlayer_Helper`, retain the installed Main and seed-20 RBF, then restart the core and press keyboard `M` during the early first-play trailers.  Hardware acceptance requires the root menu to appear without a freeze or 800-by-600 diagnostic raster, menu direction and activation to remain interactive, native 480i to remain active, and terminal telemetry to report no B-presentation or other errors; leave the terminal telemetry visible for collection after the run.

#### Files Modified:

- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 814 COMMIT Unreleased a9899e0 2026-08-31T05:41:30-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Correct entry 813's prefetch-thread diagnosis before implementing the approved root-menu navigation fix.

#### Outcome:

Complete inspection of `iso_prepare` proves that authored `isomenu:` and `dvdmenu:` playback intentionally bypasses the optical prefetch thread, so entry 813's statement that `iso_menu_command` races an active producer and leaves its ring undiscarded is incorrect and no source work is performed from that diagnosis.  The captured hardware evidence remains valid: root-menu command `0x09` and both control barriers complete, then the reset FPGA session trips only B-picture presentation error `0x0200` after 24,043 accepted bytes.  The actual unsafe helper boundary is narrower and directly visible in `iso_menu_command`: after successful `dvdnav_menu_call` or `dvdnav_button_activate`, it sets hop state but leaves `block_offset` and `block_size` pointing into the current 2,048-byte DVD block.  The next Program Stream pass can therefore consume a stale old-position block tail and assemble a pack or PES across the libdvdnav hop before reading the new authored position.  This corrects only the causal interpretation in entry 813; its screenshot, helper log, hashes and FPGA fault isolation are unchanged.

#### Next Steps:

Obtain approval for the corrected helper-only boundary before implementation: on successful root-menu or button-activation hops, invalidate the current DVD block, clear terminal and still state, and log the discarded block-tail byte count before returning to the existing Main/helper reset barrier.  Add a focused regression proving no pre-hop bytes survive either hop plus the existing real-image menu-navigation test, then build only the helper and repeat the early-trailer `M` hardware test without changing Main, the seed-20 RBF or Quartus source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 813 COMMIT Unreleased a9899e0 2026-08-31T05:35:17-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Capture and isolate the first hardware failure when an authored physical DVD receives the root-menu command during first-play trailers.

#### Outcome:

The source-`a9899e0` installation plays the physical disc's Viacom Paramount intro, four-language selection and three first-play trailers until its authored menu is eventually reached, proving sustained first-play video and audio before the navigation test.  After a fresh launch, keyboard `M` with the OSD closed submits root-menu command `0x09` at diagnostic time 4.138167 seconds; Main closes the download, discards 190,463 pending bytes, receives the helper's ready barrier and releases the new session, while the helper reports that the navigation barrier completes and its rearmed random-access filter discards zero leading B pictures.  The screen then freezes in the 800-by-600 diagnostic raster.  The 31,886-byte scaled screenshot `/tmp/entry813_root_menu_freeze.png`, SHA-256 `e5d61e8a547183b92a58ed5ccbd17eb73a439bd232294efdb73d02979856cc68`, contains all 64 schema-20 rows with valid headers, indices and parity and matching checksum `d80518c4`; its fatal snapshot occurs only 24,043 accepted video bytes and 443,132 decoder clocks after the navigation reset, on a 30000/1001 B picture with temporal reference 12, and reports exactly error `0x0200`, the B-picture presentation error, with the overlay extractor, overlay engine, syntax, reconstruction, writer, cache and audio error bits clear.  The matching 1,843,639-byte log `/tmp/entry813_root_menu_freeze_arm_helper.log`, SHA-256 `bb145d181f90e3642b4ac8a746067bdf6f4b2d83d1bee5e1f511e36f1997762b`, shows Main and helper continuing to transfer hundreds of megabytes after the fatal FPGA snapshot, so this is neither a Main barrier deadlock nor a helper stall.  Static inspection localizes the unsafe boundary to `iso_menu_command`: unlike accepted chapter changes, it calls the shared libdvdnav handle while the optical producer thread is active and neither stops nor discards its prefetched navigation ring before the FPGA download reset, allowing stale or concurrently spliced pre-hop bytes to open the new decoder session.  No target file, playback option or repository source changes during collection.

#### Next Steps:

Keep the seed-20 RBF and Main frozen and do not invoke another root-menu or activation hop on this running session.  Before implementation, approve a helper-only navigation-buffer correction that serializes libdvdnav hop commands with the optical producer, discards the pre-hop ring and partial block, restarts and prefills from the new authored position, and logs the discarded byte count; exercise it with a host concurrency regression and existing menu-navigation tests, then deploy only the helper and repeat the same early-trailer `M` test while requiring native 480i to remain active and all FPGA error flags to stay clear.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 812 COMMIT Unreleased a9899e0 2026-08-31T05:08:01-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Install the exact timing-clean source-`a9899e0` authored-menu RBF with its matching Main and ARM helper while preserving the accepted source-`6e44472` system for rollback.

#### Outcome:

At the user's explicit authorization, the build PC at exact source `a9899e0` produces a 904,564-byte static ARMv7 helper at SHA-256 `a00173f62ec4a8b0d126ef48695e299b2fecf4e836bff28abdc1107fe62eac7c` and a 1,174,492-byte patched ARMv7 Main at `a276aadcdc5aad4034bc40ee2dff52596fd44876156e24f16289d5a339411636`; the Raspberry Pi independently receives and verifies both artifacts together with entry 811's 4,511,756-byte seed-20 RBF at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  Predeployment absolute-path FTP readback identifies the accepted active Main as 1,174,492 bytes at `d91b570057d6cf314f5f98d7d637a8607f59fe5b61a193a40e6a615a6bab8c98`, helper as 896,372 bytes at `156917b7a165905f3cc73adf995886d05fc3f60aa301a4a31574f36ac0b06202` and source-`6e44472` RBF as 4,441,756 bytes at `5d6fc43700d935edac4e14e2f26895aed33db5fe917dd5092128a5cc18a97c20`.  In accordance with entry 811's explicit rollback requirement, independent uploads and readbacks preserve those exact predecessors as `/media/fat/MiSTer.pre_a9899e0_d91b5700`, `/media/fat/linux/MediaPlayer_Helper.pre_a9899e0_156917b7` and `/media/fat/_MediaPlayer_Backups/MediaPlayer_a9899e0_pre_6e44472_5d6fc437.rbf`.  Unique candidate uploads are independently read back byte-for-byte before same-directory renames activate all three exact source-`a9899e0` artifacts at `/media/fat/MiSTer`, `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; final absolute-path readbacks reproduce all three complete candidate hashes.  The running Main and FPGA remain the previous versions until a normal reboot and core reload, so hardware acceptance is pending.

#### Next Steps:

Perform one normal MiSTer reboot, load MediaPlayer, and begin with an authored DVD ISO or physical disc whose menus are known to work in a conventional player.  Require first-play or root-menu entry, animated menu video and audio, visible subpicture graphics and selection highlight, directional movement to distinct buttons, activation of a selected title, return to root menu, and unchanged play, pause and chapter controls; stop and report the exact observed step if a fatal telemetry flag, missing overlay, incorrect highlight or navigation failure occurs.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 811 COMMIT Unreleased a9899e0 2026-08-31T04:19:24-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Find and pin a timing-clean fitter placement for the source-`2738e99` authored-menu design without changing its logic or constraints.

#### Outcome:

The user authorizes the bounded placement-only search after source `2738e99` removed the authored-menu overlay crossing failures but seed 19 exposed negative 0.107 ns global setup slack on sixteen ordinary same-clock HDMI scaler paths.  Seed 20 is the first and only searched placement and passes, so source `a9899e0` changes only the QSF seed from 19 to 20 and stops the search without any RTL, SDC, interface or memory-allocation change.  The retained-netlist fit, assembly and timing run passes all five categories, and the required clean exact-commit Quartus build then completes analysis and synthesis with zero errors and 154 warnings, fitting with zero errors and 45 warnings, assembly with zero errors and zero warnings, and TimeQuest plus Phase-1P extraction with zero errors.  Global setup is positive 0.161 ns with zero TNS in every reported setup clock, hold is positive 0.243 ns, recovery is positive 3.980 ns, removal is positive 0.428 ns and minimum pulse width is positive 0.925 ns; the 60 MHz decoder and 54 MHz video setup domains are positive 0.925 ns and 2.564 ns with zero violated paths.  The clean fit uses 35,797 of 41,910 ALMs, 54,851 registers, 4,187,011 memory bits, 535 of 553 M10Ks and 70 of 112 DSPs, with 38 percent average and 61 percent peak interconnect usage.  The retained-netlist and clean builds produce byte-identical 4,511,756-byte RBFs at SHA-256 `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`; the clean artifact is preserved on the build PC and fetched to the Raspberry Pi but is not installed on the MiSTer.

#### Next Steps:

Keep exact source `a9899e0`, fitter seed 20 and RBF SHA-256 `02928bff` frozen as the final FPGA boundary and perform no further Quartus work unless the user explicitly reopens it after a demonstrated FPGA-only defect.  After separate deployment authorization, build or verify the matching source-`a9899e0` Main and ARM helper, preserve the accepted source-`6e44472` installation as rollback, install and read back all three candidate artifacts, then hardware-test first-play and root menus, directional selection, activation, animated menu audio and video, subpicture graphics and highlights on several differently authored ISO and physical discs; keep subsequent compatibility work in Main and the helper wherever this frozen overlay architecture permits.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 810 COMMIT Unreleased 6e44472 2026-08-31T04:13:58-07:00

#### Coming From:

Unreleased 2738e99

#### Purpose:

Capture and qualify the on-screen telemetry after the user's perfect full-disc DVD playback on the accepted source-`6e44472` installation.

#### Outcome:

The user reports that the DVD finished perfectly after extensive chapter skipping and leaves the completed session's telemetry visible for collection.  The 285,090-byte 1920-by-1080 scaled screenshot `/tmp/entry810_completed_dvd_telemetry.png`, SHA-256 `3c3a184eb5df0e8c6fe31bdddf4bd8956debbe2320dfc796bdd89787156c7dc4`, has all 64 schema-20 headers, row indices and parity bits valid and checksum `eb7a78f8` matching.  The visible raster is the sticky first-error snapshot at STC second 1,795 rather than an end-of-file snapshot: it records 1,085,445,320 accepted video bytes, 42,919 displayed pictures, 42,918 swaps, exactly one audio FIFO underrun, FIFO floor zero, zero transport blocks and no error flag other than the corresponding `0x0400` audio-underrun bit; its three retained largest gaps are each 66.733 milliseconds, with 42,917 deadline-gap events and 21,465 cadence outliers.  The matching 194,633,412-byte helper log `/tmp/entry810_completed_dvd_arm_helper.log`, SHA-256 `e0db52dc8a47949209a3574b93d5b81c359c3b0ec6cfeb9cfa3cfcacf86efa8c`, identifies direct optical title 1 with 24 chapters and HDMI decoded stereo PCM, later reaches DVD EOF and exits zero after approximately 7,014 seconds of a session that included the user's navigation; it processes 4,239,456,995 video bytes and 219,032 AC-3 frames, produces and consumes 5,096,290,304 DVD-buffer bytes with zero consumer waits, and Main submits 5,690,325,341 bytes entirely through the fast path.  The single latched underrun remains within the previously accepted isolated-underrun allowance and produced no user-perceived defect; no repository source, installed file, RBF, Main, helper, media, playback option or target configuration changes during collection.

#### Next Steps:

Keep accepted source `6e44472` and its installed artifacts unchanged as the hardware baseline, retain source `2738e99` as the uninstalled authored-menu candidate, and continue to pause implementation and build work until the user explicitly approves or declines the separately proposed bounded eight-seed fit-and-timing search.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 809 COMMIT Unreleased 2738e99 2026-08-31T03:31:31-07:00

#### Coming From:

Unreleased 8d1a5d0

#### Purpose:

Correct the authored-menu overlay clock-crossing timing boundary without weakening same-clock analysis or changing overlay behavior.

#### Outcome:

Source `2738e99` adds endpoint-specific timing exceptions only from the authored-menu overlay's stable buses and event toggles to their explicit first sampling stages in the opposite 54 MHz or 60 MHz domain, leaving every second stage, same-clock path and the clock relationship timed, and makes both overlay width conversions explicit without changing the packed-pixel address or alpha result.  TimeQuest resolves every new exception to real keepers with no ignored overlay filter, the two overlay width warnings disappear, all three focused overlay simulations pass, and eight retained mixed-raster, interlaced-I/P, field-motion, field-DCT, B-field and exhaustive B-motion regressions pass.  The one authorized clean seed-19 compile completes synthesis, fitting and assembly with zero errors; decoder setup is positive 0.975 ns, video setup is positive 1.680 ns, hold is positive 0.246 ns, recovery is positive 4.072 ns, removal is positive 0.508 ns and minimum-pulse-width is positive 0.925 ns.  The global setup gate nevertheless rejects the RBF at negative 0.107 ns with negative 0.839 ns TNS across sixteen ordinary same-clock HDMI scaler paths from `ascal|o_h_poly_t.r0` to `ascal|o_h_poly_pix.r`; this is one logic level, not an overlay crossing, and is not false-pathed.  The fit uses 35,834 of 41,910 ALMs, 535 of 553 M10Ks and 70 of 112 DSPs; the rejected 4,506,492-byte RBF hashes `9550bd2a`, is not fetched or installed, and the MiSTer remains on accepted source-`6e44472` artifacts.

#### Next Steps:

Keep source `2738e99` and the accepted source-`6e44472` MiSTer installation unchanged while obtaining approval for a separate placement-only timing boundary.  The smallest next action is a bounded fit-and-timing seed search reusing the exact synthesized `2738e99` netlist, with no RTL or constraint change, followed by pinning the first seed whose global setup, hold, recovery, removal and minimum-pulse-width margins are all positive and verifying it once in a clean full build; do not weaken the HDMI constraint or pipeline the MiSTer scaler unless the bounded seed search fails.

#### Files Modified:

- MediaPlayer.sdc
- rtl/mpeg2_new/mpeg2_h262_dvd_overlay.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 808 COMMIT Unreleased 8d1a5d0 2026-08-31T01:28:52-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Implement authored DVD-Video menu navigation and subpicture highlights through the existing libdvdnav session and a bounded FPGA DDR overlay plane.

#### Outcome:

Source `8d1a5d0` implements authored first-play, directional selection, activation and return-to-menu for ISO and optical DVD sources while preserving the accepted title, chapter, pause, audio and CSS paths.  The helper assembles fragmented DVD subpictures into a packed 720-by-480 two-bit plane with palette, alpha and highlight state; bounded in-band records feed an inactive FPGA DDR plane, an atomic commit publishes it, and a native-480i line cache composites it before the cadence diagnostic overlay without using decoder frame banks.  Focused malformed-SPU, fragmentation, palette, alpha, highlight, metadata-backpressure, overlay-engine and arbiter tests pass, the complete retained native-480i regression passes, ordinary MPG and legacy `iso:` candidate output is byte-identical to the accepted helper, and a real authored ISO navigation harness observes menu entry, menu exit, two ready barriers, two overlay commits and successful root, direction and activation behavior.  Exact-source ARM helper, Main and strict native helper builds succeed.  The one authorized clean seed-19 Quartus compile completes synthesis, fitting and assembly with same-clock setup margins of positive 0.675 ns at 60 MHz and positive 1.946 ns at 54 MHz, but final timing rejects the RBF because the new explicit two-stage overlay clock crossings lack source-to-first-stage exceptions: global setup is negative 1.951 ns, hold is negative 0.281 ns, while recovery, removal and minimum-pulse-width are positive.  The rejected RBF is not installed and the MiSTer remains on accepted source `6e44472` artifacts.

#### Next Steps:

Keep accepted source `6e44472` and its installed artifacts unchanged on the MiSTer.  Before any further source edit or Quartus build, obtain approval for a separate narrowly scoped timing-correction boundary that cuts only the stable overlay handshake buses and toggles from their source registers to the first synchronizer stages, retains timing through the second stages, and cleans the two reported overlay width-truncation warnings; then rerun focused clock-crossing and retained regressions and one clean seed-19 build, accepting an RBF only if setup, hold, recovery, removal and minimum-pulse-width are all positive.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- files.qip
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/dvd_spu.c
- host/arm/dvd_spu.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- rtl/mpeg2_new/mpeg2_dvd_overlay.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_overlay_arbiter.sv
- tools/test_dvd_overlay_engine.sv
- tools/test_dvd_overlay_metadata.sv
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 807 COMMIT Unreleased 6e44472 2026-08-31T01:20:21-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Complete hardware acceptance of the source-`6e44472` menu and mixed-film chapter corrections.

#### Outcome:

The user reports skipping throughout the physical DVD without any issue, including the previously abnormal chapters, which now look normal, and reports that the reorganized menu looks great.  Together with entry 806's perfect previous, next, play, pause, button-control, audio, video, WAV, MP3, FLAC and Ogg Vorbis results, this clears the chapter-two-to-three black-screen gate, the legacy 800x600 or vertically corrupted mixed-film chapter behavior and the OSD acceptance boundary for entries 803 through 805.  Source `6e44472`, its timing-clean seed-19 RBF, the installed Main and the installed helper are hardware-accepted; no screenshot, target capture, repository source, installed file, running playback, media or configuration changes during this report.

#### Next Steps:

Keep source `6e44472`, fitter seed 19 and the accepted installed artifacts unchanged as the current hardware baseline.  The transport controls, chapter navigation, mixed film and interlaced presentation, reorganized menu and four consumer-audio formats are accepted; choose and approve the next development or release-qualification boundary before changing source or rebuilding Quartus.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 806 COMMIT Unreleased 6e44472 2026-08-31T01:17:02-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Record the user's hardware acceptance of transport controls, button mappings, audio and video playback, and all four consumer-audio formats on the installed source-`6e44472` system.

#### Outcome:

The user reports that previous chapter, next chapter, play and pause all work perfectly, every tested button control behaves correctly, audio and video are perfect, and WAV, MP3, FLAC and Ogg Vorbis files all play properly.  At the user's direction no screenshot or other target capture is taken, and no repository source, installed file, running playback, RBF, Main, helper, media or configuration changes during this acceptance report.  This accepts the transport-control and consumer-audio portions of entries 803 through 805; the report does not independently identify the requested menu-layout checks or the chapter-specific mixed-film sequence at chapters 8, 11, 15, 17 and 23, so those narrow gates remain open.

#### Next Steps:

Confirm whether the three file actions, `16:9` default, `4:3` choice, Bob and Weave choices and unchanged audio sections appear correctly in the OSD, then explicitly verify that chapter 2 advances into chapter 3 and chapters 8, 11, 15, 17 and 23 remain in native 480i without a black screen, legacy 800x600 raster or vertical corruption.  If those checks already formed part of this test, record that confirmation without taking a screenshot; otherwise leave source `6e44472` and the installed timing-clean RBF unchanged while completing only those remaining hardware gates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 805 COMMIT Unreleased 6e44472 2026-08-31T00:16:48-07:00

#### Coming From:

Unreleased 4525ae4

#### Purpose:

Move the expanded MediaPlayer configuration string into exactly one M10K so the timing-clean decoder and video logic no longer displace the HDMI scaler into a failing placement.

#### Outcome:

Source `6e44472` changes only the sole `hps_io` instantiation to enable its existing synchronous `CONF_STR_BRAM` implementation, preserving every configuration byte, selector, status bit, menu label, scaler function, decoder path, clock and fitter seed.  A focused ROM test returns the complete byte sequence with the designed one-cycle latency, the mixed field-order test passes, and the complete native-480i startup, cache, TFF/BFF timing, Bob/Weave, pattern, overlap, PTS, presentation, fingerprint, generation, deadline and cadence suite passes after the user's build-PC reboot interrupted and invalidated the first run.  Exactly one clean Quartus Prime 17.0.2 build from the exact source commit at pinned seed 19 completes successfully using 34,034 of 41,910 ALMs, 52,553 registers, 4,184,067 memory bits in exactly 533 of 553 M10Ks and 67 of 112 DSP blocks, satisfying the user's condition of one and only one additional M10K.  Every timing category is positive with zero setup TNS: setup 0.119 ns, hold 0.246 ns, recovery 3.684 ns, removal 0.587 ns and minimum pulse width 0.925 ns; the 60 MHz decoder and 54 MHz video setup domains are positive 0.533 and 2.673 ns.  The 4,441,756-byte RBF has SHA-256 `5d6fc43700d935edac4e14e2f26895aed33db5fe917dd5092128a5cc18a97c20`, is installed at `/media/fat/MediaPlayer_20260829_b9c2657.rbf`, reproduces the exact hash by readback and is loaded on the MiSTer; hardware menu and playback acceptance remain open.

#### Next Steps:

Open the MiSTer OSD and verify the three requested file actions, 16:9 default, 4:3 choice, Bob/Weave choices and unchanged audio sections.  Launch the physical DVD, confirm unchanged play/pause, advance beyond chapter 2 and then through chapters 8, 11, 15, 17 and 23 without a black screen, legacy 800x600 raster or vertical corruption, and test one Ogg Vorbis file; preserve the helper log and telemetry before accepting entries 803 through 805 as hardware-passed.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 804 COMMIT Unreleased 4525ae4 2026-08-30T23:17:00-07:00

#### Coming From:

Unreleased de29d54

#### Purpose:

Keep native 480i presentation active when one interlaced-sequence chapter mixes ordinary interlaced and progressive film frame pictures.

#### Outcome:

Source `4525ae4` makes native field-order tracking sticky after any progressive frame appears in a supported interlaced sequence and allows either supported ordinary-interlaced or film-frame pictures to retain native ownership, while preserving the pre-transition fixed-order mismatch guard and every existing syntax, timing and decoder-error rejection.  Focused ordinary-to-film, film-to-ordinary, per-picture field-order, pure-interlaced mismatch and reset tests pass, followed by the complete native-480i timing, cache, cadence, presentation, mixed-raster, I/P/B, field-motion, field-DCT and exhaustive B-motion regressions.  Exactly one clean Quartus Prime 17.0.2 build is attempted at pinned seed 19 from the exact source commit.  Analysis, fitting, assembly and timing extraction complete using 34,072 of 41,910 ALMs, 52,748 registers, 4,181,443 memory bits in 532 of 553 M10Ks and 67 of 112 DSP blocks, but the global timing gate rejects the RBF because setup slack is negative 0.480 ns with TNS negative 2.373 ns; hold, recovery, removal and minimum-pulse-width margins remain positive 0.249, 4.034, 0.586 and 0.925 ns.  The targeted 60 MHz decoder and 54 MHz video domains remain clean at 0.263 and 3.055 ns, while detailed extraction localizes the violations to the unrelated 148.54 MHz HDMI scaler address path led by `ascal|o_adrs_pre[11]` to `ascal|o_adrs[12]`.  The rejected 4,459,620-byte RBF has SHA-256 `1444f6512e910a8b662767b98d98b5f8970c83823deb2e22cbd954336b4805db`; it is not installed, and no reseed or second compile is performed.

#### Next Steps:

Keep the accepted RBF installed and do not deploy this timing-failed artifact.  Use the extracted seed-19 HDMI scaler paths and the accepted source-`205bbd7` timing baseline to prepare a separately approved, narrowly bounded timing correction that restores positive global setup margin without changing the mixed-film behavior, menu semantics, scaler function or seed; repeat the functional regressions before one further clean build is considered, then install only a five-category timing-clean RBF and perform the pending chapter, menu and Ogg hardware gates.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- rtl/mpeg2_new/mpeg2_h262_native_field_order.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 803 COMMIT Unreleased de29d54 2026-08-30T22:48:28-07:00

#### Coming From:

Unreleased 6de2778

#### Purpose:

Correct host-side chapter audio recovery and reorganize the MediaPlayer menu with functional Ogg Vorbis playback before the separately approved FPGA mixed-mode boundary.

#### Outcome:

Source `de29d54` reorganizes the core menu into separate DVD-Video, MPEG-2 and consumer-audio selectors, makes 16:9 the default aspect ratio, preserves the existing Bob/Weave and audio choices, teaches the pinned Main selector about `.flac`, `.mpeg` and `.ogg`, and adds functional Ogg Vorbis decode through pinned stb_vorbis source.  Chapter resets now retain the established Program Stream codec and AC-3 or DTS private substream; HDMI AC-3 decoding scans forward at most 64 KiB and rebuilds liba52 after a rejected boundary candidate instead of terminating.  Native WAV, MP3, FLAC and 44.1/48 kHz Ogg tests are deterministic, an intentionally damaged AC-3 Program Stream resynchronizes and completes, and the exact Coming Toamerica DVD folder passes chapter 1 to 2 and 2 to 3 with substream `0x80` retained and bounded recovery logged at both barriers.  Exact source builds reproduce a 896,372-byte static ARM helper at SHA-256 `156917b7a165905f3cc73adf995886d05fc3f60aa301a4a31574f36ac0b06202` and a 1,174,492-byte Main at SHA-256 `d91b570057d6cf314f5f98d7d637a8607f59fe5b61a193a40e6a615a6bab8c98`; both are directly installed without backups, independently read back, mode 755, and a verified reboot activates Main.  The installed RBF remains unchanged, so the new menu and mixed native-video behavior are not yet active and hardware playback acceptance remains open.

#### Next Steps:

Proceed with entry 804's separately approved mixed film/interlaced native-480i source and seed-19 FPGA boundary so one readback-verified RBF activates both the new menu and the presentation correction.  Hardware acceptance must then confirm chapter navigation beyond chapter 2, stable native presentation at chapters 8, 11, 15, 17 and 23, unchanged play/pause, correct 16:9 default and selector layout, and functional Ogg playback; capture the helper log and telemetry before settling either entry as passed.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 802 COMMIT Unreleased 6de2778 2026-08-30T22:43:15-07:00

#### Coming From:

Unreleased 6de2778

#### Purpose:

Reject the first source-`6de2778` hardware control gate and isolate the chapter-three black-screen exit from the reported legacy-raster chapter starts.

#### Outcome:

The user confirms that play/pause now works correctly, but advancing from chapter 2 to chapter 3 leaves a black screen, and reports that earlier successful navigation made chapters 8, 11, 15, 17 and 23 render through the old 800x600 diagnostic raster with vertical downward corruption.  The live 708,865-byte helper log `/tmp/entry802_chapter2_black_arm_helper.log`, SHA-256 `74362cec8a0a54ea6938cf416e32479d83eaef36a490be8eed20ee096d1ac234`, proves that Main submits the next-chapter command, releases download, discards old bytes, and completes the helper ready/go barrier; libdvdnav reports current chapter 2, target chapter 3 of 24 and refills the direct-device ring to 4 MiB in 169,671 microseconds, but liba52 then reports `undecodable AC-3 block`, the helper closes stdout and exits with code 1, and Main completes the session after only 20,463,192 submitted bytes.  The 20,481-byte 1440x1080 scaled screenshot `/tmp/entry802_chapter2_black.png`, SHA-256 `bf55329fbfae9db50343401f8974a0b98bd19c53f39be228fa969159f26da000`, is completely black.  The same log shows a separate deterministic track-selection defect: initial playback chooses AC-3 substream `0x80`, while the chapter-one-to-two jump chooses `0x81` because the reset forgets the established track and reclaims whichever private substream arrives first.  Read-only FFprobe analysis of the matching build-PC title confirms three valid AC-3 tracks, finds `0x81` before `0x80` at the chapter-two boundary, and decodes all tracks in chapters 1 through 3 without error, localizing the fatal block to helper chapter-start synchronization rather than damaged authored audio.  The exact five reported legacy-raster chapters independently share a second signature absent from adjacent chapters: each starts with an interlaced I-picture and immediately continues with progressive film P and B pictures.  The FPGA native-field-order tracker explicitly rejects such mixed film/interlaced sessions by latching mismatch and withdrawing native 480i, which selects the 800x600 fallback; correcting that behavior requires an RBF boundary.  This rejects chapter navigation beyond chapter 2 while accepting the new play/pause binding, and changes no repository source, installed file, Main, helper, RBF, FPGA configuration, media, playback option or running process during collection.

#### Next Steps:

Stop the source-`6de2778` acceptance cycle and obtain approval for a revised two-boundary plan.  First make a helper-only correction that retains the established audio substream across chapter changes, resynchronizes cleanly at the first complete access unit and treats a bad candidate frame as a bounded resynchronization event rather than terminating otherwise valid playback; prove deterministic chapter-one-through-three control, all three authored AC-3 track boundaries, HDMI decode and S/PDIF passthrough without changing Main or the RBF.  Separately, after explicit RBF authorization, extend native field-order ownership to this observed mixed film/interlaced frame-picture sequence without accepting field pictures or weakening decoder error gates, run focused mixed-mode and complete native-480i simulations, perform one clean seed-19 Quartus build with full timing and resource gates, then hardware-test chapters 8, 11, 15, 17 and 23 for stable native output and clean telemetry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 801 COMMIT Unreleased 6de2778 2026-08-30T22:30:02-07:00

#### Coming From:

Unreleased 6de2778

#### Purpose:

Record the user's simplified deployment policy for future Main and MediaPlayer Helper replacements.

#### Outcome:

The user directs that future deployments of `/media/fat/MiSTer` and `/media/fat/linux/MediaPlayer_Helper` must not create rollback, predecessor or backup copies because either binary can be reproduced from the GitHub source.  Deployment should first attempt to upload the verified new artifact directly to its exact absolute destination; if the FTP server refuses replacement, delete only that exact destination and immediately upload the verified artifact at the same path.  Post-upload readback verification and the normal Main reboot requirement remain applicable, while this directive does not alter RBF handling.  Existing backup files are not removed by this instruction, and no source, installed file, process, Main, helper or RBF changes while recording it.

#### Next Steps:

Continue the source-`6de2778` control qualification already requested in entry 800.  For every later Main or MediaPlayer Helper deployment, do not create a backup or staged rollback: verify the build artifact locally, attempt direct replacement at `/media/fat/MiSTer` or `/media/fat/linux/MediaPlayer_Helper`, fall back to deletion of only the refused destination followed by immediate upload, independently read back the installed bytes, and reboot only when Main changes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 800 COMMIT Unreleased 6de2778 2026-08-30T22:27:54-07:00

#### Coming From:

Unreleased 6de2778

#### Purpose:

Deploy the corrected Main input bindings with an exact rollback while leaving the accepted helper and FPGA image unchanged.

#### Outcome:

The exact build-PC artifact for source `6de2778` is independently staged on the Raspberry Pi and reproduced as a 1,174,492-byte stripped ARMv7 Main at SHA-256 `3443716313e4f7eb5ed58ea97d785f0d788471ef66f23151c6405b2ac4455f04`.  Absolute-path predeployment FTP readback proves the active Main is the expected 1,174,492-byte source-`151e10a` binary at `b98af001791800647b8ae4c6c0850d19061fe8b24edbe8cad307bbb9c2759990`, the helper is the expected 863,540-byte binary at `ceef50a6c2d706ae40c4992ee6d47d687a3ea0eced4e61567032b9599d14d2a7`, and `/media/fat/MediaPlayer_20260829_b9c2657.rbf` is the accepted 4,440,192-byte seed-19 image at `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  Independent readbacks verify the rollback and candidate before same-directory FTP renames preserve the exact predecessor as `/media/fat/MiSTer.pre_6de2778_b98af001` and activate the candidate at `/media/fat/MiSTer`; the staging name is consumed by the rename.  One normal MiSTer reboot loads the new Main, and post-reboot absolute-path readback reproduces active Main `34437163`, rollback Main `b98af001`, unchanged helper `ceef50a6` and unchanged seed-19 RBF `7f60ec43`.  No helper, RBF, RTL, QSF, FPGA configuration, launcher, media or playback option changes.

#### Next Steps:

Launch `/media/fat/games/MediaPlayer/USB DVD Drive.dvd` with a physical DVD and close the MiSTer OSD.  On the keyboard press Space once, wait about two seconds and press Space once again; require one clean pause and one clean synchronized resume, then press N once and P once and require exactly one next-chapter and one previous-chapter action.  Repeat pause/resume with physical player-one Start and confirm player-one D-pad Right and Left still perform one next and previous chapter action.  Report any missing, repeated or wrong-direction response and whether HDMI or S/PDIF audio and video remain synchronized after each resume or chapter barrier.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 799 COMMIT Unreleased 6de2778 2026-08-30T22:23:36-07:00

#### Coming From:

Unreleased 151e10a

#### Purpose:

Bind the requested keyboard and physical controller controls to the existing ARM-side DVD playback actions without changing the helper or FPGA image.

#### Outcome:

Source `6de2778` adds only Main input translations: keyboard Space maps to play/pause, P maps to previous chapter, N maps to next chapter, and physical player-one Start maps to play/pause, while the accepted player-one D-pad Left and Right chapter path remains unchanged.  Main consumes recognized press, release and repeat events only while MediaPlayer playback is active and the MiSTer OSD is closed, and triggers an action only on the initial press so one held or repeated input cannot toggle or jump multiple times.  The shared semantic action handler removes the unreachable virtual `JOY_START` dependency and retains the existing pause hold and helper ready/go chapter barrier without changing `CONF_STR`, helper protocol, helper source, RTL, QSF or RBF.  The regenerated patch applies cleanly to pinned Main commit `0a8fb44`, and exact project source `6de2778de2b2b6cd1cea81ae4784c0457fadd36a` builds successfully with pinned ARM GNU 10.2 into a stripped 1,174,492-byte ARMv7 Main at SHA-256 `3443716313e4f7eb5ed58ea97d785f0d788471ef66f23151c6405b2ac4455f04`.  No Quartus build, helper build, MiSTer deployment, RBF, media, playback option or running process changes at this build boundary.

#### Next Steps:

Preserve the active 1,174,492-byte source-`151e10a` Main at SHA-256 `b98af001791800647b8ae4c6c0850d19061fe8b24edbe8cad307bbb9c2759990` as a unique absolute-path rollback, stage and independently verify the source-`6de2778` Main, activate Main only, reboot once and prove that the helper and accepted seed-19 RBF remain byte-identical.  Then launch physical-DVD playback with the OSD closed and require keyboard Space and controller Start each to pause and resume exactly once, keyboard P/N and controller Left/Right each to change one chapter in the requested direction, and resumed HDMI or S/PDIF audio and video to remain synchronized.

#### Files Modified:

- CHANGELOG.md
- README.md
- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 798 COMMIT Unreleased 151e10a 2026-08-30T22:12:01-07:00

#### Coming From:

Unreleased 151e10a

#### Purpose:

Record the first hardware control test and identify why pause receives no keyboard or controller input while chapter navigation works.

#### Outcome:

The user reports that previous and next chapter appear to work correctly but play/pause does nothing after trying the keyboard and every controller button.  The live 8,152,023-byte diagnostic log `/tmp/entry798_pause_input_failure.log`, SHA-256 `604f3ffcf18bb3acc61cb4636e02799b4513554bb043f47d57af1b7724abdd85`, independently records 23 next-chapter commands and nine previous-chapter commands, all followed by successful helper-ready and Main release barriers with no chapter, control-channel or helper-EOF fault; it records zero `playback paused` and zero `playback resumed` events.  Static comparison against the exact pinned Main source identifies the binding defect: `JOY_START` is an alias for virtual core button four, not the physical controller Start control, while MediaPlayer's `CONF_STR` declares no joystick buttons.  Closed-OSD Main therefore forwards directional bits to `user_io_digital_joystick`, which explains the working Left and Right controls, but does not assign any physical keyboard or controller button to virtual button four, so the pause branch can never observe its requested bit.  The official VLC 3.0 hotkey documentation identifies Space as Play/Pause, N as Next and P as Previous; the user explicitly limits the requested VLC alignment to those keyboard assignments rather than any VLC playback behavior, architecture or library.  Main can translate those three raw keyboard events and the physical controller Start event into the existing transport actions without changing `CONF_STR`, the helper or RBF.  This accepts the deployed previous and next chapter path, rejects only the pause binding, and changes no source, installed file, RBF, helper, Main, playback option or running process during diagnosis.

#### Next Steps:

Add only Main-side input translations with the existing OSD-closed and active-playback guards: keyboard Space toggles play/pause, P requests the previous chapter and N requests the next chapter, while physical controller Start toggles play/pause and controller D-pad Left and Right retain their accepted chapter actions.  Do not adopt any other VLC behavior or change `CONF_STR`, helper, RTL or RBF.  Build and host-test patched Main, preserve the currently deployed source-`151e10a` Main as rollback, activate the new Main, reboot once, then require each keyboard and controller command to act exactly once and resume synchronized physical-DVD playback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 797 COMMIT Unreleased 151e10a 2026-08-30T22:02:27-07:00

#### Coming From:

Unreleased 627b329

#### Purpose:

Deploy the ARM-side DVD pause and chapter-control binaries with verified rollback preservation while leaving the accepted FPGA image unchanged.

#### Outcome:

After accepting entry 796's single imperceptible audio FIFO underrun, the user explicitly authorizes trying the source-`151e10a` controls.  The synchronized build-PC checkout supplies the recorded 863,540-byte static ARMv7 helper at SHA-256 `ceef50a6c2d706ae40c4992ee6d47d687a3ea0eced4e61567032b9599d14d2a7` and 1,174,492-byte dynamically linked ARMv7 Main at `b98af001791800647b8ae4c6c0850d19061fe8b24edbe8cad307bbb9c2759990`; independent Raspberry Pi staging reproduces both hashes and sizes.  Absolute-path predeployment readback identifies the active helper as the 859,444-byte source-`627b329` binary at `ff3b4f41d81a070ad4ef5226dd3380ab12bb409118b1e6981af4c95b3138f7a6`, the active Main as the 1,170,396-byte source-`531f741` binary at `e428c8b097b70f15e9452781433bd9afbf84c33d4b94da575dea8fe127ccc9d6`, and `/media/fat/MediaPlayer_20260829_b9c2657.rbf` as the accepted 4,440,192-byte seed-19 image at `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  Unique candidate uploads at `/media/fat/linux/MediaPlayer_Helper.candidate_151e10a_ceef50a6` and `/media/fat/MiSTer.candidate_151e10a_b98af001` are independently read back and verified before activation.  Same-directory FTP renames preserve the active predecessors as `/media/fat/linux/MediaPlayer_Helper.pre_151e10a_ff3b4f41` and `/media/fat/MiSTer.pre_151e10a_e428c8b0`, activate both candidates, and remove both staging names.  A normal MiSTer reboot loads the new Main; post-reboot absolute-path readback again reproduces exact active helper `ceef50a6`, active Main `b98af001` and unchanged seed-19 RBF `7f60ec43`, while directory inventory retains both exact rollback names.  No RTL, QSF, RBF, FPGA configuration, launcher, media or menu option changes.

#### Next Steps:

Load MediaPlayer and launch `/media/fat/games/MediaPlayer/USB DVD Drive.dvd` with a physical DVD, keep the OSD closed, and allow normal synchronized playback to establish.  Press player-one Start once, hold the pause for about two seconds, press Start again and require clean resumed video and HDMI or S/PDIF audio; then press Right once and require a clean move to the next chapter, followed by Left once and require a clean return to the previous chapter.  Report whether each control acts once, reaches the intended chapter, resumes synchronized playback and avoids a lockup; one sticky audio-underrun event remains acceptable, but any stale pre-jump frame, wrong chapter, missing response or sustained audio defect requires immediate capture before another command.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 796 COMMIT Unreleased 627b329 2026-08-30T21:55:20-07:00

#### Coming From:

Unreleased 151e10a

#### Purpose:

Capture and qualify the unattended long-running physical-DVD telemetry event without disturbing playback.

#### Outcome:

The user reports no visible or audible issue during the long-running physical-DVD playback and leaves the still-advancing movie and telemetry untouched for collection.  The live helper log identifies `dvd:/dev/sr0`, selects longest title 1 with 23 chapters and duration 633,249,000 ticks, uses HDMI decoded stereo PCM and AC-3 substream `0x80`, performs one CSS key scan, two authenticated navigation resets and a 4 MiB reserve in the 8 MiB ring with 1.877412 seconds of prefill, then delivers first verified transport 13.224510 seconds after launch.  The checksum-valid schema-20 raw capture latches at STC second 118 after 91,592,308 clean-video bytes with exactly one audio FIFO underrun and FIFO floor zero; its only aggregate hardware error is the corresponding sticky `0x0400` bit, with zero cache overlap, PCM protocol, presentation or transport-block errors.  The saved snapshot also records 2,509 displayed pictures, 2,508 swaps, 2,507 deadline events, 1,256 gap outliers and largest retained gaps of 150.182, 116.815 and 83.448 milliseconds, so it is not a zero-cadence-event capture even though no presentation error latched and the user perceived no defect.  The helper remains healthy through 1,040.583821 seconds of scheduled playback, more than fifteen minutes beyond the sticky event, with 50,001,408 samples emitted versus 49,948,023 expected, 450,130 queued video bytes and 811,471,313 video bytes processed; Main remains live through diagnostic time 1,055.717654 seconds, has submitted 1,027,706,880 bytes, records no HPS-ring consumer wait, limits the largest 16 KiB pipe-read interval to 224.081 milliseconds and the slowest read call to 11.384 milliseconds, and has no EOF, exit or process fault.  The 805,468-byte scaled screenshot `/tmp/entry796_long_dvd_telemetry.png` has SHA-256 `df8a4592bce681485af1e299485d096e07608fef7e457f663949c25e1f65fa07`; the 470,557-byte native capture `/tmp/entry796_long_dvd_telemetry_raw.png` has SHA-256 `e93817cbe68ca5c424c2a5058c706722a3d0a0f495650b0e0a4a0ae43a6d35b7` and telemetry checksum `712abb32`; and the 26,395,877-byte helper log `/tmp/entry796_long_dvd_arm_helper.log` has SHA-256 `4f24638795eed54d0c1e88ebccb90d3765c8c587e3e1b01fc26f543f21396ca3`.  This is the previously accepted allowance of one isolated audio FIFO underrun rather than a reproduced optical starvation or sustained audio failure, and no source, installed file, RBF, Main, helper, media, playback option or running process changes during collection.

#### Next Steps:

Let the current movie continue without further capture because the event is fully characterized and playback remains healthy.  Treat source `627b329` as hardware-passed for buffered encrypted physical-DVD playback under the user's accepted single-underrun allowance; after playback ends and the user explicitly authorizes deployment, preserve and verify the active source-`627b329` Main and helper as unique absolute-path rollbacks, install the already built source-`151e10a` Main and helper together without changing the seed-19 RBF, reboot for Main, and qualify Start pause/resume plus Right and Left chapter navigation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 795 COMMIT Unreleased 151e10a 2026-08-30T21:34:22-07:00

#### Coming From:

Unreleased 627b329

#### Purpose:

Add ARM-side previous chapter, next chapter and play/pause controls without changing the FPGA image.

#### Outcome:

Source `151e10a` maps player-one Left and Right to previous and next chapter and Start to pause or resume only during active playback with the MiSTer OSD closed.  Main creates a private nonblocking `SOCK_SEQPACKET` control channel, releases the current download for a chapter request, drains every old pending and pipe byte, resets transport-credit state, then reasserts download only after the helper's ready event and releases the helper with an explicit go command.  The helper retains the authenticated libdvdnav handle, stops and flushes the direct-device HPS ring, restarts the requested chapter with `dvdnav_part_play`, resets Program Stream, audio, scheduler, random-access and PTS state, and waits at that barrier before producing the new chapter.  Start pause/resume is an intentional Main-side transport hold that preserves the process and navigation session; the documented limitation remains that a long hold can trigger the current FPGA audio-underrun telemetry because this boundary adds no core pause state.  A native socket harness proves a two-second pause and resumed byte flow, next-chapter and previous-chapter barriers on both `iso:` and direct-device-compatible `dvd:` input; the direct run discards and refills the 8 MiB ring at each jump without reopening navigation.  The unchanged five-minute Coming to America VOB repeats 299,980,757 video bytes, 601 timestamps, 9,375 AC-3 frames and 14,400,000 PCM samples, and the MPG smoke completes normally.  A complete buffered Blazing Saddles direct run performs one CSS scan, two authenticated resets, zero consumer waits, repeats 3,823,399,998 video bytes, 11,150 timestamps, 174,142 AC-3 frames, 267,482,112 PCM samples and one expected PTS discontinuity, and reproduces the exact accepted transport SHA-256 `d407c03833d0b2e2326037b0a7f9041c2292eb23d6d75ac37dc08df8c0d95553`.  ARM GNU 10.2 builds the 863,540-byte static ARMv7 helper at SHA-256 `ceef50a6c2d706ae40c4992ee6d47d687a3ea0eced4e61567032b9599d14d2a7` and the 1,174,492-byte patched Main at SHA-256 `b98af001791800647b8ae4c6c0850d19061fe8b24edbe8cad307bbb9c2759990`; the strict native helper is 1,589,632 bytes at SHA-256 `bfd8222eeb43857420dcfcb086802c4e258d7ba1e178b852f6c3f4530d55958b`.  No RTL, QSF, Quartus command, RBF, MiSTer file or running physical-disc test changes.

#### Next Steps:

Await the user's completion of the current physical-disc qualification and explicit deployment authorization.  Then preserve and independently verify the installed Main and helper as unique absolute-path rollbacks, stage and read back exact source-`151e10a` candidate hashes, activate both binaries, reboot because Main changes, and leave the seed-19 RBF untouched.  Hardware-test Start pause/resume first with the known underrun-telemetry caveat, then Right to chapter two and Left back to chapter one on an inserted DVD; require clean download-session resets, valid video and synchronized HDMI or S/PDIF audio after each barrier.

#### Files Modified:

- CHANGELOG.md
- README.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 794 COMMIT Unreleased 627b329 2026-08-30T21:27:52-07:00

#### Coming From:

Unreleased 627b329

#### Purpose:

Determine whether standard authored DVD-Video menus can be added through the existing static VideoLAN helper stack without changing the FPGA image.

#### Outcome:

The user defines the target as each disc's authored DVD-Video menus, including chapter selection, directional navigation, activation and return-to-menu, while requiring that any feature needing an `.rbf` change be held.  The pinned static libdvdnav 7.0.0 already implements the DVD virtual machine, first-play and menu calls, directional button selection, activation, chapter searches and NAV-packet button definitions, so neither libVLC nor another navigation library is needed.  The existing helper deliberately selects the longest title, skips still and wait events, discards menu navigation events and sends only MPEG-2 video plus audio through a one-way Main pipe.  A Main-to-helper control pipe can carry controller commands without FPGA work, and authored menu background video can use the current decoder, but the visible selected-button state is a DVD SPU bitmap/highlight layer.  The current core has no SPU decoder or overlay plane, the HPS never receives decoded FPGA frames for software composition, and Main's available OSD is a text-row interface rather than a DVD bitmap compositor.  A complete authored-menu implementation therefore requires an FPGA overlay change; no source, Main, helper, RBF, installed file or running physical-disc test is changed.

#### Next Steps:

Hold authored DVD menus until the user explicitly permits an RBF feature boundary.  Preserve libdvdnav 7.0.0 as the navigation engine when that work resumes, add the bidirectional controller path and SPU decoder together with a bounded overlay design, and avoid any claim of DVD-Video menu conformance until the applicable authorized specification is available.  In the meantime, continue the current physical-disc compatibility qualification or choose a separate helper/Main-only feature such as direct previous and next chapter controls if desired.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 793 COMMIT Unreleased 627b329 2026-08-30T21:17:28-07:00

#### Coming From:

Unreleased 531f741

#### Purpose:

Deploy the authenticated-reset and direct-DVD HPS-ring helper with verified rollback preservation.

#### Outcome:

The user reports that the source-`531f741` Coming to America physical-disc control remains perfect at 15 minutes after its repeated first-minute pause and explicitly authorizes deployment.  The exact source-`627b329` build-PC artifact is retrieved and independently verified as an 859,444-byte statically linked ARMv7 helper at SHA-256 `ff3b4f41d81a070ad4ef5226dd3380ab12bb409118b1e6981af4c95b3138f7a6`.  Immediate absolute-path readback confirms `/media/fat/linux/MediaPlayer_Helper` still contains the 847,156-byte predecessor at `d5067fa1d924f066b9a48ec581e34a392616fef39268df811622621a2a92bb25`.  The candidate is uploaded only as `/media/fat/linux/MediaPlayer_Helper.candidate_627b329_ff3b4f41`, independently downloaded and compared byte-for-byte, then same-directory FTP renames preserve the predecessor as `/media/fat/linux/MediaPlayer_Helper.pre_627b329_d5067fa1` and activate the candidate at `/media/fat/linux/MediaPlayer_Helper`.  Final independent readbacks reproduce the full active `ff3b4f41` and rollback `d5067fa1` hashes and sizes, and directory inventory proves the candidate staging name is gone.  Main, the seed-19 RBF, USB DVD launcher, media and configuration remain untouched.  Any helper process already running when the rename occurs continues its old executable inode until that playback exits; the next launch will use the newly installed candidate without a MiSTer reboot.

#### Next Steps:

Stop any playback that began before this deployment, then launch `/media/fat/games/MediaPlayer/USB DVD Drive.dvd` once with the same Coming to America disc.  Expect one CSS key scan, two `DVD reset authenticated navigation` lines and one `DVD buffer ready` line before first transport; report selection-to-picture time and whether audio or video pauses around 55 seconds after playback begins.  If any pause occurs, leave playback and telemetry running for immediate helper-log capture so the candidate's reserve and consumer-wait diagnostics can measure it directly.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 792 COMMIT Unreleased 531f741 2026-08-30T21:12:55-07:00

#### Coming From:

Unreleased 627b329

#### Purpose:

Capture the repeated first-minute physical-DVD pause and verify which helper produced the run.

#### Outcome:

The user reports that a new Coming to America physical-disc run takes about the same time to start, pauses at the same playback point for perceptibly less time without an audible drive spin-down, and then resumes perfect video and audio; the user leaves playback and telemetry running for immediate capture.  Absolute-path FTP readback proves that this run is not using source `627b329`: `/media/fat/linux/MediaPlayer_Helper` remains the prior 847,156-byte source-`531f741` helper at SHA-256 `d5067fa1d924f066b9a48ec581e34a392616fef39268df811622621a2a92bb25`, rather than the built 859,444-byte buffered candidate at `ff3b4f41`.  The live log independently confirms the old path by recording three complete CSS key scans and none of the candidate's authenticated-reset, prefill or buffer-wait diagnostics.  First verified transport arrives 56.942903 seconds after launch, then the only producer gap over 500 milliseconds spans 2.608982 seconds from pipe-read event 3,171 at diagnostic time 112.246762 seconds to event 3,172 at 114.855744 seconds, or 55.301187 seconds after first transport; this closely repeats entry 790's 2.471110-second interruption at approximately the same playback point and shows that the optical pause is deterministic enough to qualify the candidate against.  The 752,307-byte scaled screenshot `/tmp/entry792_coming_to_america_usb_buffer_pause.png` has SHA-256 `a0d0203b6cb3d1e15db77663c67cfa4a4de2bb004e836959c0f94c9af5995583` and visibly preserves a clean active frame after recovery.  The 6,032,092-byte helper log `/tmp/entry792_coming_to_america_usb_buffer_pause_arm_helper.log` has SHA-256 `d12f0813efdfebb4ab0ed3f6ca4e117a7e0c57834679418cff70b5daa99a0b6f`.  Because the buffered helper was never installed, this result neither supports the theory that its launch changes cancel each other nor tests whether its ring shortens the pause; no repository, MiSTer file, RBF, Main, launcher or playback configuration changes during collection.

#### Next Steps:

Let the user's current recovered movie continue without interruption.  After the user stops playback and explicitly authorizes deployment, preserve the installed `d5067fa1` helper, stage and independently read back exact candidate `ff3b4f41` at absolute MiSTer paths, activate it by same-directory rename, and verify the final active hash.  Then launch the same physical disc once and require one CSS key scan, two authenticated resets, a logged 4 MiB prefill and uninterrupted audio and video across approximately 55 seconds after first transport; compare the candidate's measured launch and any consumer wait directly with this valid old-helper control.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 791 COMMIT Unreleased 627b329 2026-08-30T20:42:55-07:00

#### Coming From:

Unreleased 531f741

#### Purpose:

Remove redundant physical-DVD CSS rescans and mask bounded optical read stalls with asynchronous HPS-side buffering.

#### Outcome:

The user extended the first Coming to America physical-disc run to approximately 40 minutes and reported rock-solid synchronized video and audio after the single captured startup pause, confirmed HDMI, S/PDIF, `4:3`, `16:9`, Bob and Weave, and heard no further drive speed transition; no additional capture was required.  Source `627b32961567d60e3f4ac85a22a60faaea9559c3` implements the approved helper-only boundary: direct `dvd:` sources retain one authenticated libdvdnav session across both signature and Program Stream preflight rewinds, then start an asynchronous 8 MiB HPS-RAM byte ring with a 4 MiB launch reserve, synchronized end and error propagation, bounded-wait diagnostics and orderly producer shutdown.  ISO and ordinary file sources remain synchronous, the native-only environment fault injection is compiled out of ARM, and no Main, FPGA, RBF or M10K changes occur.  The strict native build succeeds and produces a 1,585,280-byte binary at SHA-256 `c38e79a1`; the direct full-title Blazing Saddles regression performs exactly one CSS key scan, two authenticated resets and a 10,411-microsecond image prefill, completes with the prior exact 3,823,399,998 video bytes, 11,150 picture timestamps, 174,142 audio frames, 267,482,112 PCM samples and one expected PTS discontinuity, and reports 4,648,355,840 produced and consumed source bytes with zero waits.  A second complete run injects a 3,000-millisecond producer pause after 8 MiB while the first 16 MiB drains at approximately 1 MiB per second; the reserve hides the pause with zero waits and both runs emit the identical 4,976,916,975-byte transport at SHA-256 `d407c038`.  The unchanged ISO backend repeats the exact full-title video, timestamp, audio and PCM counts; an ordinary 100,059,136-byte MPG completes with 84,428,687 video bytes, 598 timestamps, 24,851 audio frames and 28,628,352 PCM samples; and the existing Coming to America five-minute VOB completes with the expected 299,980,757 video bytes, 601 timestamps, 9,375 AC-3 frames and 14,400,000 PCM samples.  ARM GNU 10.2 cross-build succeeds with `-Werror` and produces one 859,444-byte static ARMv7 helper at SHA-256 `ff3b4f41d81a070ad4ef5226dd3380ab12bb409118b1e6981af4c95b3138f7a6`; the build PC's full `/tmp` tmpfs was bypassed safely by routing compiler temporaries into ignored `host/build/tmp` on the GIT volume.

#### Next Steps:

Await explicit deployment authorization.  Then preserve the installed helper, transfer source-`627b329` helper SHA-256 `ff3b4f41` as a unique absolute-path candidate, independently read it back, activate it by same-directory rename with final absolute-path readback, and leave Main, the seed-19 RBF and launcher unchanged.  Repeat the Coming to America physical-disc launch gate and compare CSS scan count, time from selection to picture, logged 4 MiB reserve and continuous playback through the former first-minute pause; accept this entry only after stable hardware video and HDMI or S/PDIF audio are observed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_source.c
- host/arm/media_source.h

#### Status:

- [x] Built
- [ ] Passed

---

## 790 COMMIT Unreleased 531f741 2026-08-30T20:28:46-07:00

#### Coming From:

Unreleased 531f741

#### Purpose:

Capture and qualify the first encrypted physical-DVD playback from the direct `/dev/sr0` source.

#### Outcome:

After the verified source-`531f741` deployment and reboot, selecting `/media/fat/games/MediaPlayer/USB DVD Drive.dvd` launches exact source `dvd:/dev/sr0`, authenticates the commercial Coming to America disc through libdvdcss, finds eight title sets, selects longest title 1 with 24 chapters and duration 606,390,000 ticks, identifies AC-3 substream `0x80`, and produces correct Native 480i HDMI video and decoded stereo audio.  The user reports a long initial black-screen wait, then working playback; the log measures first transport at 98.617794 seconds because the initial open and the helper's signature and program-stream preflight rewinds each reopen navigation and repeat the complete CSS key scan, taking approximately 30, 31 and 31 seconds.  About 55 seconds after transport begins, successful 16 KiB pipe production pauses once for 2.471110 seconds from diagnostic time 153.915751 to 156.386861, matching the user's report that the drive audibly changed state and the screen briefly froze before the unchanged stream recovered exactly.  No other producer gap exceeds 74.603 milliseconds through diagnostic time 339.254331, and the user reports perfect continued picture and synchronized audio with no further starvation at approximately ten minutes.  The 663,329-byte scaled capture `/tmp/entry790_coming_to_america_usb_dvd_first_hiccup.png` has SHA-256 `8f8b7f1f`; the 568,469-byte native capture `/tmp/entry790_coming_to_america_usb_dvd_first_hiccup_raw.png` has `3c70cdee` and preserves a clean active frame.  All 64 schema-20 rows have valid prefix, index and parity and checksum `b447fda2` matches; the STC-second-155 no-progress snapshot accepts 40,458,960 clean-video bytes and reports zero hardware error flags, zero audio underruns and zero transport blocks.  The 8,519,837-byte helper log has SHA-256 `dc318e6c` and contains no read, transport or process fault.  Read-only Linux state reports `/sys/class/block/sr0/device/power/control` as `on`, runtime status `active`, autosuspend delay `-1`, device state `running` and block readahead 128 KiB; pinned libdvdnav readahead is synchronous and adaptively ranges from four to 512 2,048-byte sectors.  The user and agent therefore treat the single recovered pause as an optical-drive firmware or synchronous cache-refill event outside the decoder and transport path, and no buffer change is justified without recurrence.  This accepts direct encrypted physical-DVD launch, CSS authentication, main-title selection, HDMI playback and starvation recovery without an FPGA, helper, Main, RBF, media or configuration change during the run.

#### Next Steps:

Keep the current direct-DVD implementation unchanged unless optical starvation recurs on this or another disc.  The user may continue the feature as an extended soak and should check representative S/PDIF output when convenient; no further capture is required unless another pause or fatal telemetry occurs.  Treat the slow initial launch separately from the recovered playback pause: after explicit approval, reuse the authenticated libdvdnav session across the two preflight rewinds so the same disc is not scanned for CSS keys three times, and require native ISO and direct-source byte regressions plus one helper-only build without Quartus.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 789 COMMIT Unreleased 531f741 2026-08-30T20:14:46-07:00

#### Coming From:

Unreleased eb7bed6

#### Purpose:

Deploy the direct USB DVD helper, patched Main and optical-drive launcher with independently verified rollback preservation.

#### Outcome:

After the user stops the accepted Blazing Saddles run and explicitly authorizes deployment, the build PC remains at exact source `531f741ff4831f30b748957bcc4d2d605ea3614f` and reproduces the recorded artifacts: the 847,156-byte static helper has SHA-256 `d5067fa1d924f066b9a48ec581e34a392616fef39268df811622621a2a92bb25`, and the 1,170,396-byte patched Main has `e428c8b097b70f15e9452781433bd9afbf84c33d4b94da575dea8fe127ccc9d6`.  Absolute-path readback identifies the installed predecessor helper as 847,156 bytes at `f16e83fa2c89b3ed3071e9fa3d40355a67e85e9a5a3634ba055a5c2a7835f8db` and Main as 1,170,340 bytes at `01229bc57680d84651cc907ace880332d18347f0afc08c9c7ab5fc9197c3eefe`.  Unique helper and Main candidate uploads and independent readbacks match their source bytes.  The first launcher upload attempt stops before any activation because the repository FTP helper does not encode spaces in URLs; direct FTP with encoded spaces then installs and reads back the 111-byte launcher at SHA-256 `4757d49e9d1b94d88f554b3bd3157ed5d2064caaa65a6cf0f856e8ab6fbe2d2e`.  Same-directory absolute FTP renames preserve the predecessors as `/media/fat/linux/MediaPlayer_Helper.pre_531f741_f16e83fa` and `/media/fat/MiSTer.pre_531f741_01229bc5`, activate the new files at `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MiSTer`, and install `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`.  Final independent readbacks reproduce all five active and rollback sizes and hashes, and no candidate staging name remains.  The seed-19 RBF, FPGA, media and configuration remain unchanged; the old Main process continues in memory until reboot, so physical-disc qualification has not begun.

#### Next Steps:

Have the user perform one normal MiSTer reboot so `/media/fat/MiSTer` becomes the running Main, then verify the active Main, helper and launcher again by absolute-path readback.  Load the existing MediaPlayer core, select `USB DVD Drive.dvd`, and begin a bounded Coming to America physical-disc gate from `dvd:/dev/sr0` using HDMI first; require successful device open, CSS authentication, longest-title selection, immediate valid video and audio, stable optical reads and no fatal telemetry, then check representative S/PDIF output before extending the run.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 788 COMMIT Unreleased eb7bed6 2026-08-30T20:08:02-07:00

#### Coming From:

Unreleased 531f741

#### Purpose:

Capture and qualify the deployed ISO PTS epoch correction across the prior Blazing Saddles long-title audio failure boundary.

#### Outcome:

The uninterrupted `/media/fat/games/MediaPlayer/Blazing Saddles.iso` run on the installed source-`eb7bed6` helper uses S/PDIF decoded PCM and remains visibly clean, audibly perfect and synchronized by the user's direct observation beyond 51 minutes and again at approximately 53 minutes.  The helper records exactly one ISO epoch correction, mapping raw PTS 32,764 to normalized PTS 261,466,438 after the preceding maximum, then immediately advances through 261,601,573 and continues with zero held audio backlog instead of freezing at the old 139,443,456-sample target.  At the 3,114.412548-second captured horizon it has emitted 149,546,496 samples against a 149,491,802-sample wall-clock expectation, remains 54,694 samples ahead, advances its audio target to 149,537,536 and its video PTS to 280,392,846, and reports no transport, read or process fault.  The complete 582,704-byte scaled capture `/tmp/entry788_blazing_saddles_51min_boundary.png` has SHA-256 `981c8476`; the 407,765-byte native capture `/tmp/entry788_blazing_saddles_53min_boundary_raw.png` has SHA-256 `fe944f1e` and preserves a clean active frame.  All 64 schema-20 records in the native capture have valid prefix, row index and parity and checksum `94f83f3a` matches; its sticky first-error snapshot occurs at STC second 3,004 rather than the prior failing second 2,906, accepts 2,053,638,876 clean-video bytes, and contains only hardware error `0x0400`, exactly one audio FIFO underrun and FIFO floor zero, with zero transport blocks and no decoder, PCM-protocol, presentation, cache-overlap or video error.  The user previously accepted one isolated audio FIFO underrun, and unlike the old failure this event causes no audible degradation, accumulating starvation or A/V drift.  The 82,683,392-byte read-only helper-log capture `/tmp/entry788_blazing_saddles_51min_boundary_arm_helper.log` has SHA-256 `ce13db73`.  This hardware result accepts the source-`eb7bed6` PTS epoch correction across its required long-title boundary without changing the running movie, FPGA, seed-19 RBF, Main, helper, media or configuration.

#### Next Steps:

Allow the current movie to continue without agent interaction for as long as the user wants; no further capture is required for this boundary.  After the user finishes or explicitly authorizes interruption, preserve the installed Main and helper and deploy the already built source-`531f741` USB DVD artifacts through unique candidate uploads, independent absolute-path readbacks, same-directory renames and final readbacks, install the launcher only at `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`, reboot, and begin the bounded physical Coming to America disc gate from `dvd:/dev/sr0`.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 787 COMMIT Unreleased 531f741 2026-08-30T19:40:26-07:00

#### Coming From:

Unreleased b71cc8b

#### Purpose:

Add direct main-feature playback from the absolute USB optical-device path `/dev/sr0` without staging a DVD ISO.

#### Outcome:

The MiSTer drive is confirmed by read-only absolute-path inspection as the removable root:`cdrom` block device `/dev/sr0`, with `/dev/cdrom -> sr0`, 16,461,784 reported 512-byte sectors and model HL-DT-ST DVDRAM GP63EX70 revision RF01; no `/media/usb0` through `/media/usb7` filesystem mount is required.  Source `531f741` adds the explicit `dvd:` media-source backend, requires an absolute device path, opens it directly through libdvdnav so libdvdread and statically linked libdvdcss own optical authentication and sector reads, and reuses longest-title selection, initial random-access filtering, PTS epoch normalization, scheduling, rewind and one-traversal termination.  Patched Main recognizes the `USB DVD Drive.dvd` launcher under `/media/fat/games/MediaPlayer` and maps it only to `dvd:/dev/sr0`; capabilities now advertise `sources=file,iso,dvd`.  A full native direct-backend traversal against the existing Blazing Saddles image selects title 2, emits 3,823,399,998 video bytes, 11,150 timestamps and 267,482,112 PCM samples, handles one expected PTS discontinuity, and stops once at title exit with stream SHA-256 `58badf9c`.  The first Main attempt exposes a full 7.7 GiB `/tmp`; relocating `TMPDIR` to `/run/media/vash/GIT/.mmp-entry787-main-tmp` then exposes and corrects the new-file patch hunk count before a clean pinned-upstream build.  Exact outputs are a 1,580,488-byte native helper at SHA-256 `b63e2e46`, an 847,156-byte stripped static ARM EABI5 helper at `d5067fa1`, and a 1,170,396-byte stripped dynamically linked ARM EABI5 Main at `e428c8b0`; the expected upstream packed-attribute and static-libdvdcss `getpwuid` warnings remain.  Menus, chapters, track selection, subpictures, DVD LPCM and ejection remain outside this commit, and no FPGA, seed-19 RBF, Quartus, MiSTer executable, media or configuration change occurs.

#### Next Steps:

Do not alter the MiSTer while the deployed source-`eb7bed6` Blazing Saddles test is active; let it pass the prior 48:25 boundary, preferably reach about 51 minutes, and capture its displayed telemetry first.  Then preserve both installed executables, deploy the exact helper and Main through unique candidate uploads and independent absolute-path readbacks followed by same-directory renames and final readbacks, and install the launcher only at `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`.  Reboot before the first bounded physical Coming to America disc launch, and require direct `/dev/sr0` open, CSS key acquisition, valid longest-title Program Stream output, continuous HDMI audio and video, and representative S/PDIF output before extending the run.

#### Files Modified:

- CHANGELOG.md
- README.md
- assets/USB DVD Drive.dvd
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 786 COMMIT Unreleased b71cc8b 2026-08-30T19:13:48-07:00

#### Coming From:

Unreleased eb7bed6

#### Purpose:

Bound longest-title ISO playback to one selected-title traversal so post-title navigation cannot restart or enter another DVD domain.

#### Outcome:

The user authorizes continued development while the deployed source-`eb7bed6` Blazing Saddles boundary soak runs and separately prepares a genuinely encrypted ISO for the following qualification gate.  Native testing rejects source `ef2a7e9` because libdvdnav reports a legitimate large time regression at each new chapter, and rejects the narrower source `bee9541` duration cutoff because Coming to America reaches its described 606,390,000-tick duration on a payload block, continues authored title cells through approximately 630,129,000 ticks and otherwise leaves a 1,565-byte AC-3 tail.  Final source `b71cc8b` therefore treats duration as selection and diagnostic metadata, retains the selected title plus monotonic chapter and cell structure, and converts only a title exit or backward chapter or cell replay into clean end-of-stream before following-domain payload is exposed; rewind restores the boundary.  Accelerated complete native runs end once and drain cleanly for Blazing Saddles at 3,823,399,998 video bytes, 11,150 timestamps and 267,482,112 PCM samples, Coming to America at 4,239,456,995 bytes, 14,807 timestamps and 336,433,152 samples, and The Big Lebowski at 5,509,816,546 bytes, 14,558 timestamps and 338,021,376 samples.  The accepted 2,097,152-byte ISO opening remains byte-identical at SHA-256 `396b0db1`, the five-minute MPG remains exactly 224,185,582 bytes at `45401ab3`, and a 299,980,757-byte VOB decode compares byte-for-byte at `677ce1bb`.  One ARM GNU 10.2 build from exact full source `b71cc8bedc112444b79a1d4af2e8b185b6bf0373` produces an 847,156-byte stripped static EABI5 helper with SHA-256 `603f4c05fd6ca687b6dc33c70e97b19fe34a96a320d6a91042f41bd78fb584e7` and no dynamic section; the expected static-libdvdcss `getpwuid` warning remains.  No Quartus build, MiSTer deployment, Main, FPGA, RBF, media or configuration change occurs.

#### Next Steps:

Let the currently deployed `eb7bed6` Blazing Saddles soak pass the prior 48:25 audio boundary and capture its terminal telemetry before changing the running helper.  Then preserve the installed helper and stage-deploy exact candidate `603f4c05` with candidate readback, same-directory rename and final readback; qualify one complete selected title through its clean end so the title-exit boundary itself is hardware-proven.  When the user supplies the encrypted ISO, first independently prove it contains CSS-scrambled sectors, then require a clean complete native opening and a representative HDMI and S/PDIF MiSTer run without changing Main, the seed-19 RBF or FPGA source.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_source.c

#### Status:

- [x] Built
- [ ] Passed

---

## 785 COMMIT Unreleased eb7bed6 2026-08-30T19:08:17-07:00

#### Coming From:

Unreleased eb7bed6

#### Purpose:

Deploy the ISO PTS epoch-normalization helper with verified rollback preservation for hardware qualification.

#### Outcome:

The first deployment attempt before the reboot writes nothing because the MiSTer still answers ping and accepts TCP connections on ports 21 and 22 but neither FTP nor SSH produces a service banner; the user then confirms that the MiSTer had locked up and reboots it.  After reboot, FTP recovers normally.  An independent download verifies the previously active 817,700-byte helper at SHA-256 `536250b8c4e0baba71f1d73e4e0476b8adc23025b447a33bacacb187327af1b5`.  The exact source-`eb7bed668f39c97b79a691b2c721fe42283e19f0` candidate is 847,156 bytes with SHA-256 `f16e83fa2c89b3ed3071e9fa3d40355a67e85e9a5a3634ba055a5c2a7835f8db`; candidate upload and independent absolute-path FTP readback reproduce both values.  A same-directory FTP rename preserves the old helper as `/media/fat/linux/MediaPlayer_Helper.pre_eb7bed6_536250b8`, activates the candidate as `/media/fat/linux/MediaPlayer_Helper`, and a final independent readback again reproduces the exact 847,156-byte length and `f16e83fa2c89b3ed3071e9fa3d40355a67e85e9a5a3634ba055a5c2a7835f8db` digest.  No candidate staging name remains.  Main, the seed-19 RBF, media and configuration remain unchanged; no Quartus build occurs.

#### Next Steps:

Reload MediaPlayer and play the Blazing Saddles ISO from the beginning over HDMI through at least the prior 2,905-second or approximately 48:25 failure boundary, preferably continuing to about 51 minutes; briefly confirm representative S/PDIF output as well.  Accept the timestamp correction only if video remains stable, audio remains continuous and telemetry does not appear at that boundary, then leave the resulting telemetry displayed for one capture.  A complete end-of-title run is not yet required because the separate post-title navigation loop remains deliberately deferred; after this boundary passes, implement the title-duration stop before returning to genuinely scrambled-ISO qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 784 COMMIT Unreleased eb7bed6 2026-08-30T18:21:34-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Normalize DVD ISO presentation timestamps across VOB or cell discontinuities so long-title audio scheduling remains continuous.

#### Outcome:

Source `eb7bed6` adds an ISO-only PTS epoch normalizer with an explicitly documented ten-second implementation guard: ordinary decode-order reversals pass through unchanged, while a material backward reset is translated before both scheduler admission and FPGA timestamp-record generation so its first timestamp follows the preceding maximum by one 90 kHz tick.  A focused exact-source native harness preserves a 45,000-tick reorder, maps a synthetic large reset to one new epoch and leaves non-ISO timestamps unchanged.  The accelerated real Blazing Saddles scheduler test reaches the captured boundary, maps raw PTS 32,764 to normalized PTS 261,466,438 immediately after the prior 261,466,437 maximum, and continues growing its PCM target from 139,227,264 through 255,009,280 frames with zero held backlog rather than freezing at entry 783's 139,443,456-frame target.  The unchanged five-minute MPG again produces exactly 224,185,582 bytes with SHA-256 `45401ab3`, and the first 16 MiB of scheduled ISO transport compares byte-for-byte with the accepted CSS-enabled opening capture.  One static ARM GNU 10.2 build from exact full source `eb7bed668f39c97b79a691b2c721fe42283e19f0` produces an 847,156-byte stripped EABI5 helper with SHA-256 `f16e83fa` and no dynamic section; the expected static-libdvdcss `getpwuid` link warning remains.  The accelerated run separately shows that after the declared 501,030,000-tick title duration libdvdnav follows post-title protection or navigation commands into another epoch and eventually exceeds the two-MiB video lookahead; that end-of-title behavior predates this correction and is reserved for a later host-only boundary rather than expanding the timestamp fix.  No Quartus build or MiSTer deployment occurs.

#### Next Steps:

After explicit user authorization, preserve the installed helper and deploy exact candidate SHA-256 `f16e83fa` by candidate upload, readback, same-directory rename and final readback.  Replay Blazing Saddles past the 2,905-second boundary over HDMI and S/PDIF and accept this correction only if video remains stable, audio remains continuous and telemetry records no underrun.  Then separately bound the selected ISO source to its declared longest-title duration so post-title protection or navigation commands cannot loop into a second traversal, and resume genuinely scrambled-ISO qualification only after both long-title gates pass.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 783 COMMIT Unreleased 0711d3d 2026-08-30T16:25:29-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Reject the provisional full-title Blazing Saddles ISO soak and localize its late audio-only failure without disturbing the running movie.

#### Outcome:

During the uninterrupted complete `/media/fat/games/MediaPlayer/Blazing Saddles.iso` run on the installed source-`0711d3d` helper, the user reports that video remains clean and running but HDMI audio begins crackling after the earlier five-minute acceptance.  The matching live helper log names longest title 2 and decoded HDMI PCM, while its scheduler stays real-time and ahead of the sink until elapsed 2,904.822639 seconds; there `max_video_pts` reaches 261,466,437 ticks or 2,905.182633 seconds and never advances again even though admitted video grows from 1,993,452,669 to 2,107,305,716 bytes.  Over the following 181 seconds the fixed PCM target remains 139,443,456 frames, held decoded PCM grows from 3,072 to 5,106,816 frames and emitted PCM falls 5,069,458 frames or 105.614 seconds behind the 48 kHz wall-clock expectation.  The 720x480 raw capture `/tmp/entry783_iso_audio_crackle_raw.png`, 371,166 bytes and SHA-256 `8c86977c`, has 64 valid schema-20 rows, parity and checksum `0e6258d6`; its sticky first-error state occurs at STC second 2,906 with hardware error `0x0400`, audio FIFO floor zero and exactly one recorded underrun, while decoder, PCM protocol, presentation, cache-overlap and transport-block errors remain clear.  The 1,920x1,080 visible capture `/tmp/entry783_iso_audio_crackle.png`, 573,794 bytes and SHA-256 `eafe7684`, preserves an undamaged active movie frame, and the 75,163,498-byte live helper log has SHA-256 `538bed37`.  Independent read-only FFprobe inspection of the same title finds its DVD packet position resetting from 3,368,974 to 14 at normalized PTS 2,904.623278 seconds, immediately bounding the frozen raw-PTS horizon to a VOB or cell transition.  The evidence therefore identifies an ISO-only host scheduler timestamp-discontinuity defect: the helper rejects every post-transition raw PTS as older than its permanent maximum, so its byte-guard fallback cannot sustain audio even though video continues.  This does not implicate the MPEG-2 decoder, FPGA resources, S/PDIF framing, CSS support or the undeployed source-`81a1002` candidate, and it overturns entry 781's provisional full-ISO acceptance without changing any installed file or repository source.

#### Next Steps:

Keep the accepted seed-19 RBF, Main and decoder unchanged, and do not deploy the encrypted-ISO candidate yet.  Add an ISO-scoped PTS epoch normalizer that recognizes a large backward discontinuity while tolerating ordinary decode-order reordering, advances both scheduler and in-band video timestamps monotonically across the DVD boundary and leaves MPG/VOB behavior byte-identical.  Reproduce the boundary with a compact native discontinuity fixture, run the existing native MPG and decrypted-ISO regressions, rebuild only the ARM helper, then preserve and stage-deploy it for a Blazing Saddles replay through at least the 2,905-second boundary on HDMI and S/PDIF.  Resume genuinely scrambled-ISO validation only after that long-run gate passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 782 COMMIT Unreleased 81a1002 2026-08-30T15:41:39-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Add encrypted DVD ISO main-feature playback through a pinned host-side libdvdcss dependency without expanding into physical discs or menus.

#### Outcome:

The user selects encrypted ISO files as the next target and agrees that technical decryption and licensing or distribution policy remain separate concerns.  Source `81a1002` replaces the deliberate unencrypted-only libdvdread patch with reproducibly pinned libdvdcss 1.6.0 native and ARM builds, configures libdvdread with CSS support, directly links the static library beneath the existing callback-backed `iso:` source and clears inherited Meson compiler arguments so a reused build directory cannot silently retain `MMP_DISABLE_DVDCSS`.  Official VideoLAN material identifies the dependency as transparent encrypted DVD block access under GPLv2; its 83,640-byte source archive is independently verified at SHA-256 `7ea556c8`.  Exact native regression proves the decrypted Blazing Saddles ISO opening remains byte-identical at 1,123,504 bytes and SHA-256 `66b84e51`, including its two discarded open-GOP leading B pictures, while the ordinary five-minute MPG remains byte-identical at 224,185,582 bytes and SHA-256 `45401ab3`.  The exact ARM build succeeds as an 847,156-byte stripped, statically linked EABI5 helper with SHA-256 `620c8af3` and no dynamic section.  A raw sector scan finds no scrambled PES sectors in any available Coming To America, Blazing Saddles or The Big Lebowski ISO, so those already-decrypted images cannot validate the new decryption path and the candidate is intentionally not deployed.  This remains an implementation dependency rather than a substitute for the unavailable authorized DVD CCA specification, and no CSS-conformance claim is made.

#### Next Steps:

Provide an authorized genuinely CSS-scrambled raw ISO fixture, confirm that it contains nonzero scrambled PES sectors, prove native sector decryption and a complete valid opening, and compare against an independently decrypted control when feasible.  If that gate passes, preserve the installed helper, deploy this exact candidate by verified staging and same-directory rename, and qualify the same encrypted ISO on HDMI and S/PDIF without changing Main, the seed-19 RBF or FPGA source.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/libdvdread-disable-css.patch
- host/arm/media_source.c
- host/build_arm_stack.sh

#### Status:

- [x] Built
- [ ] Passed

---
