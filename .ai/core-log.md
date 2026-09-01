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

## 835 COMMIT Unreleased d4ed809 2026-08-31T16:04:26-07:00

#### Coming From:

Unreleased b5e49db

#### Purpose:

Build and qualify the exact source-`d4ed809` DVD overlay pipeline diagnostic RBF for physical MiSTer testing.

#### Outcome:

The exact clean source checkout `d4ed809999e6efd6891b2522ede6aefbed24a75f` passes the focused all-`0x55` overlay-engine regression, retained metadata extractor and arbiter regressions, and both settled-commit and no-commit-fallback snapshot paths under Icarus Verilog on build PC `10.10.0.42`.  Quartus Prime 17.0.2 seed 20 completes synthesis, fitting, assembly and the project timing gate with zero errors; global setup, hold, recovery, removal and minimum-pulse-width slacks are respectively positive at 0.018, 0.244, 3.816, 0.593 and 0.925 nanoseconds, while the dedicated 60 MHz decoder and 54 MHz video checks have 0.871 and 1.932 nanoseconds of setup slack and no violations.  The schema-21 Gray-code source-to-first-synchronizer exception resolves without an ignored-filter warning.  The fit uses 34,791 ALMs, 54,483 registers, 4,187,011 block-memory bits in 535 RAM blocks and 70 DSP blocks.  The uniquely preserved `output_files/MediaPlayer_20260831_d4ed809.rbf` is 4,468,560 bytes with SHA-256 `6ea1615feec15a2c229ad10331bdfd48f955f76e48adaa69effe9c77e09ee45b`, identical on the build PC and in the local workspace.

#### Next Steps:

Preserve the installed `MiSTer_OverlayTrace` Main and `MediaPlayer_Helper_OverlayProbe` helper, upload only `MediaPlayer_20260831_d4ed809.rbf` as a new file rather than overwriting the current rollback, load that core, start the physical DVD, enter the root menu, move the selector several times, wait at least two seconds after the first menu commit, then collect a fresh `telemetry.txt`, screenshot and Main/helper log.  Require checksum-valid schema 21 with word 37 equal to `4f564c31`; its words 38 through 54 will localize the first stage that fails to advance, while visible opaque magenta would independently prove the final compositor path.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 834 COMMIT Unreleased d4ed809 2026-08-31T15:36:39-07:00

#### Coming From:

Unreleased 0e89c73

#### Purpose:

Localize the physically absent known-pattern DVD highlight inside the FPGA after its byte-exact ingress FIFO acceptance.

#### Outcome:

The user approves and source `d4ed809` implements the first RBF observability change after source `0e89c73` proves the complete all-index-one plane, opaque-magenta palette, visible menu configuration, commit and moving style records enter the FPGA FIFO with matching accepted-word count and rolling digest but produce no magenta screen pixels.  The helper, Main, in-band record protocol, overlay control, DDR addresses, cache behavior, compositor and fitter seed remain unchanged.  Passive saturating counters now report accepted config, data, commit, style and clear records, all engine record and plane bytes, accepted DDR writes, valid and rejected commits, line-cache fills, memory-domain plane and style publications, synchronized video-domain publication and row-tag arrivals, row-tag-matched samples, highlighted samples, nonzero-alpha samples and exact opaque-magenta samples.  Schema 21 maps this evidence into words 37 through 54, suppresses the unrelated first-error snapshot, captures one decoder-clock second after any commit reaches the engine, and falls back after thirty active seconds if no commit arrives.  Each video counter crosses back as separately valid registered Gray code through two explicit synchronizer stages, with only the source-to-first-stage path cut.  The focused exact all-`0x55` engine simulation writes and reads 86,400 bytes through 10,800 DDR words, publishes the probe plane and style, renders opaque magenta, clears back to base video and requires every schema-21 stage to advance; the retained extractor and arbiter tests pass, and the new trigger regression passes both settled-commit and no-commit fallback paths under Icarus Verilog with warnings limited to pre-existing inherited timescales.

#### Next Steps:

Check out exact source `d4ed809` on build PC `10.10.0.42`, rerun all four focused overlay regressions there, perform one clean Quartus Prime 17.0.2 seed-20 build, require positive setup, hold, recovery, removal and minimum-pulse-width timing plus resolved schema-21 CDC constraints, and provide a uniquely named diagnostic RBF while preserving the installed target files until the user replaces only the RBF.

#### Files Modified:

- MediaPlayer.sv
- MediaPlayer.sdc
- rtl/mpeg2_new/mpeg2_h262_dvd_overlay.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/test_dvd_overlay_engine.sv
- tools/test_dvd_overlay_snapshot.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 833 COMMIT Unreleased 0e89c73 2026-08-31T15:30:28-07:00

#### Coming From:

Unreleased 0e89c73

#### Purpose:

Determine whether the complete known-pattern DVD overlay stream reaches the FPGA ingress FIFO before the physically absent menu highlight.

#### Outcome:

The source-`0e89c73` physical-disc result proves one complete synthetic overlay frame crossed the helper, Main, SPI file-transfer path and FPGA ingress acceptance boundary without corruption or backpressure failure, while the rendered menu still contains no magenta selection pixels.  The 1,321,892-byte Main/helper log at SHA-256 `ec8523c89cd34d22821c6c5a2666158d6754a3c08d5375f8e1687c053299de18` records config flags `3`, rectangle `135,397` through `208,436`, opaque-magenta highlight entry one, 22 data records, exactly 86,400 data bytes, FNV-1a `f8555d45`, zero non-`0x55` bytes, zero order errors and `probe_complete=1`; its 26 successfully submitted style changes follow 26 root or directional menu commands through all four authored rectangles, and no `transport_fault` occurs.  Because `user_io_file_tx_data_step` verifies each batch against the FPGA FIFO's returned accepted-word counter and rolling digest before the verifier receives those bytes, this clears not only helper construction and Main forwarding but also physical acceptance into the FPGA ingress FIFO.  The 745,871-byte 1,920-by-1,080 screenshot at SHA-256 `7ee61103f6fae63fe62ced7716dea093fc00be3b5949dfcbd200ce297b023287` visibly shows the active menu and unobscured button area with no magenta rectangle.  The 792-byte schema-20 matrix text at SHA-256 `fc469765c947ca4910204205dd29347e1c05460e2c833ecdf299ccb3467f3436` passes all row framing and checksum `70fb7917`; word 19 again contains only audio-underrun flag `0x0400`, and its 209,628,414 decoder clocks or 3.494 seconds precede the first submitted overlay config at 12.847 seconds, so that sticky snapshot cannot report later overlay state.  A verifier-only oversized B9 candidate with length 65,503 appears at byte offset 28,625,926 about 23 seconds after the valid commit and cannot explain the initial failure; because the bounded Main verifier recognizes only B9 framing while the FPGA extractor also consumes B0, B1 and B6 payloads atomically, this later candidate is not evidence by itself that hardware saw an invalid overlay record.  The remaining defect is strictly downstream of the accepted FPGA FIFO write, in FIFO read or in-band extraction, overlay command handling and DDR publication/cache, or final video-domain style publication and blending.

#### Next Steps:

Do not modify the helper or Main again for this fault because the source-`0e89c73` evidence exhausts their observable transport boundary.  After explicit user approval, add an FPGA-observability-only schema that captures after a valid overlay commit or style change instead of freezing on the earlier audio underrun and positively counts extractor config, data, commit and style records, engine plane bytes and accepted DDR writes, initial and moving row-cache fills, style publications, row-tag matches and opaque blend samples; strengthen the focused simulation to require those counters across the known all-`0x55` magenta probe, then build one timing-clean diagnostic RBF while preserving the current helper, Main and rendering behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 832 COMMIT Unreleased 0e89c73 2026-08-31T14:59:02-07:00

#### Coming From:

Unreleased f515341

#### Purpose:

Prove whether Main submits each complete helper-generated DVD overlay record to successful FPGA ioctl transfers without changing the submitted stream or the RBF.

#### Outcome:

The user approves and source `0e89c73` implements the Main-only observability boundary after the known opaque helper probe produces two complete synthetic overlay frames and 152 moving style records but the physical menu displays no magenta pixels.  A second patch against pinned Main source `0a8fb44` adds a bounded streaming verifier after, and only after, each successful `user_io_file_tx_data_step` consumption so it observes the exact byte sequence Main reports as submitted while leaving its contents, chunking, credit protocol, pacing and control behavior unchanged.  The verifier recognizes overlay markers and declared lengths across arbitrary pipe and ioctl boundaries, retains only bounded configuration and style state, validates frame command order, counts data records and bytes, calculates FNV-1a over the submitted plane, counts non-`0x55` probe bytes, suppresses repeated identical style logs, and reports changed selections plus every commit and session summary.  A focused build of the exact patched header with C++11 strict warnings passes when every byte is fed separately and again in 37-byte chunks, recognizing the complete 22-record, 86,400-byte probe at FNV-1a `f8555d45`, rejecting a one-byte corruption, zero and oversized lengths, data and commit before config, an interrupted frame, an unknown command and a repeated style.  Both Main patches apply cleanly in order and the complete exact-source ARM Main build succeeds with MiSTer's GNU 10.2 toolchain.  `/home/vash/MiSTer-Media-Player-0e89c73/host/build/MiSTer_OverlayTrace` is a 1,178,588-byte stripped dynamically linked ARMv7 EABI5 hard-float executable at SHA-256 `872050d44266d74c28e302a54336f409426fbca235ce3384c3b1735eb1aa6356` and contains the required commit and summary markers.  The helper, kernel, ioctl implementation, FPGA source, QSF and seed-20 RBF remain untouched.

#### Next Steps:

Replace only `/media/fat/MiSTer` with `/home/vash/MiSTer-Media-Player-0e89c73/host/build/MiSTer_OverlayTrace` from the build PC, preserving the currently installed diagnostic helper and seed-20 RBF, verify the 1,178,588-byte destination and SHA-256 `872050d44266d74c28e302a54336f409426fbca235ce3384c3b1735eb1aa6356`, restore executable permission if needed, and perform a normal MiSTer reboot because Main changes.  Restart the physical DVD, enter the root menu, move through several buttons and capture the fresh `/tmp/MediaPlayer_ARM.log` plus screenshot.  A decisive successful submission has `overlay_submit config` with `probe_payload=1`, `overlay_submit commit` with 22 data records, 86,400 data bytes, FNV-1a `f8555d45`, zero non-`0x55` bytes, zero order errors and `probe_complete=1`, followed by moving style rectangles; if those exact lines coexist with no magenta rectangle, userspace Main is cleared and the remaining boundary is kernel-to-FPGA delivery or live FPGA processing.

#### Files Modified:

- host/build_arm_stack.sh
- host/main_mister/0002-mediaplayer-overlay-trace.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 831 COMMIT Unreleased f515341 2026-08-31T14:51:34-07:00

#### Coming From:

Unreleased f515341

#### Purpose:

Determine whether a known opaque DVD overlay plane generated by the helper appears on the physical menu without changing Main or the RBF.

#### Outcome:

The user's source-`f515341` physical-disc capture shows no moving magenta selection rectangle anywhere on the menu, including after 30 successful right or left navigation commands traverse all four authored buttons and finish on `SET UP`.  The 2,234,774-byte helper and Main log at SHA-256 `6d15b61ee5c0390739d08189b33d0c3e3f16aac7293f78fc18b0979abcd0cf7f` proves the uniquely marked probe ran: both real-plane dumps contain exactly 480 distinct 180-byte rows and 86,400 bytes, independently reproduce FNV-1a `c23cad52`, and are followed by two completed overlay-frame emissions, two config records and 152 style records.  Every synthetic record reports visible and menu flags set, transparent normal colors, opaque magenta highlight index one, an all-index-one selected histogram and the correct moving rectangles containing 2,960, 3,640, 5,760 or 6,528 drawable pixels; no helper write or protocol failure is logged.  The matching 1,920-by-1,080 screenshot at SHA-256 `d9149dc8d47ac36795180e5756a7e61d157deb83a58a74df833465a7a53e734e` visibly contains the menu and cadence matrix but no magenta pixels at the unobscured final `SET UP` rectangle.  The 792-byte schema-20 matrix text at SHA-256 `fc48a1f9753d0eede8ac8b9d68deac32e922a908097863a62e7fac38b65289de` passes every prefix, row index, parity bit and checksum `7172fa5b`; word 19 contains only error flag `0x0400`, the audio FIFO underrun, and its 208,201,221 session cycles or 3.470 seconds precede the first overlay emission about 5.62 seconds after the root-menu stream hop, so the sticky snapshot cannot report the later overlay transport or engine state.  This hardware failure rules out the real subpicture plane, palette, selection state and helper record construction but cannot distinguish Main's userspace forwarding from the kernel ioctl, live in-band extraction, DDR publication or final blend.

#### Next Steps:

Leave the diagnostic helper, Main and seed-20 RBF unchanged until the user approves a Main-only observability boundary.  Add a bounded streaming parser immediately after each successful Main ioctl submission that recognizes complete overlay records across transfer boundaries, validates command order and declared lengths, counts exactly 86,400 data bytes, hashes the transmitted synthetic plane against FNV-1a `f8555d45`, and records config, commit and moving-style payloads without changing any submitted byte.  Build and install only a uniquely named Main diagnostic; if it proves the complete records reached every successful ioctl call while the rectangle remains absent, the remaining boundary is kernel-to-FPGA delivery or live FPGA processing and an RBF observability build becomes necessary, while any missing or malformed record remains fixable entirely on the host side.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 830 COMMIT Unreleased f515341 2026-08-31T11:13:16-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Distinguish a real DVD subpicture-plane defect from a downstream transport or rendering failure without modifying Main or the RBF.

#### Outcome:

The user approves and source `f515341` implements the helper-only known-pattern probe after source `673b6d7` proves the real menu state contains 267 through 279 drawable pixels but the unchanged hardware displays none, while exact installed-RTL simulation renders a complete bottom-menu rectangle correctly under an idle DDR model.  Ordinary builds remain behavior-identical, and compile-time definition `MMP_DVD_OVERLAY_PROBE` alone enables a separately named artifact that logs all 480 rows of each real 86,400-byte two-bit plane with its FNV-1a hash, retains the authored visible and menu flags plus moving selection rectangle, and transmits an all-index-one plane with a transparent normal palette and opaque magenta highlight index one.  Strict default and probe compilation, capability smoke tests, focused subpicture, random-access and menu-hop regressions, and a byte-level probe framing test all pass locally.  On the exact detached build-PC checkout, the authored-menu harness passes root, all four directions, activation, visible-highlight and control-acknowledgment coverage; it observes 17 complete overlay commits, 1,303 visible highlight events and the expected 6,528-pixel solid selected rectangle.  The normal and probe ARM outputs both build with MiSTer's GNU 10.2 toolchain; the uniquely named probe is a 908,660-byte stripped static ARMv7 hard-float executable with no dynamic section at SHA-256 `2b7de20983d9b9f2b2fe561d5ca78e33b94d3f099f6bdd0a88b31c3980118ef5`.  No decoder, scheduler, navigation, record framing, Main, RTL, QSF, RBF or installed target file is changed by the implementation itself.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, then replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-f515341/host/build/MediaPlayer_Helper_OverlayProbe` from the build PC, restore executable permission if needed, and verify the destination is 908,660 bytes with SHA-256 `2b7de20983d9b9f2b2fe561d5ca78e33b94d3f099f6bdd0a88b31c3980118ef5`.  Preserve Main and the installed seed-20 RBF.  Restart the physical DVD, reach its menu, move the selected item several times and capture a fresh helper log plus screenshot; the log must contain `probe=solid-index1-magenta` and the bounded real-plane dump.  A solid magenta rectangle following the selection localizes the defect to the real plane or its delivery pattern, while another completely absent rectangle moves the next non-RBF investigation to Main's helper-to-ioctl forwarding.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 829 COMMIT Unreleased 673b6d7 2026-08-31T11:01:48-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Exhaust non-RBF methods for isolating the missing authored-menu selection after the helper proves it emits drawable pixels.

#### Outcome:

Read-only history comparison proves the installed seed-20 source-`a9899e0` overlay RTL, in-band extractor, DDR arbiter and top-level wiring are byte-identical to source `673b6d7`, so current-source simulation is representative of the installed logic.  On the build PC, all three existing exact-source simulations pass for bounded in-band extraction and backpressure, DDR arbitration and response ownership, and plane write/read plus normal and highlight blending.  The existing engine bench holds horizontal and vertical position at zero, so a temporary untracked bench additionally drives two complete 858-by-525 timing rasters, uses the physical button-four rectangle from `439,389` through `574,436`, refills every two-line cache entry through the DDR model and measures the second frame; it renders all 6,528 expected opaque highlight pixels with zero wrong pixels and no protocol error.  This rules out a deterministic coordinate, two-bit packing, palette selection, bottom-raster row-cache or blend defect under an idle DDR model, but it does not reproduce live decoder contention or prove that the hardware receives the helper's records.  No repository source, installed helper, Main, RBF or target file is changed, and the temporary simulation does not generate a bitstream.

#### Next Steps:

Prefer one helper-only discriminator before modifying the RBF: build a reversible diagnostic helper that preserves the existing transport framing while dumping each distinct real menu plane for exact software replay and substituting a known all-index-one plane with transparent normal color and an unmistakable opaque highlight color, producing a solid rectangle only inside the authored selection coordinates.  If the rectangle appears, the failure is in the real plane data or its hardware delivery pattern; if it remains absent, capture or instrument Main's helper-to-ioctl byte forwarding next, and only after both software endpoints prove the exact records should FPGA-internal counters or another RBF be required.  Preserve the current Main and seed-20 RBF throughout this helper-only test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 828 COMMIT Unreleased 673b6d7 2026-08-31T10:48:20-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Determine whether the source-`673b6d7` helper emits drawable DVD selection pixels during the physical menu failure.

#### Outcome:

The user's exact source-`673b6d7` physical-disc run reaches the four-button menu, accepts eight successful navigation commands including the root hop and seven right or left moves, and displays no selection pixels by direct observation or in the matching 768,280-byte screenshot at SHA-256 `15d6f1a64c8d9623f354574d70bdd953d727f0d63d683a02b76ea4d69c2a2e6b`.  The 1,169,066-byte helper log at SHA-256 `debde6d17b1f20fdccf11d820511ba5928d13c21f1449c1136b1230348a20be8` contains one complete overlay configuration and 54 style records, all with `visible=1` and `menu=1`; the selected rectangle moves consistently from button one through four and back, and its exact plane histograms contain respectively 279, 278, 272 and 267 pixels whose mapped highlight alpha is nonzero.  All four emitted highlight entries are stable at transparent `00000000` followed by `316a5988`, `316a59bb` and `316a59ee`, so the helper has a valid nontransparent plane, palette, rectangle and selection state and the failure is downstream of DVD parsing and helper overlay generation.  The matching 792-byte schema-20 matrix text at SHA-256 `7911a2299b1cb84ad748177fbf03cccdba2d683044551fc369da261b20bb1924` passes all 64 prefixes, indices, parity bits and checksum `7023d571`, but its sticky snapshot froze at STC second three on only error `0x0400`, one audio FIFO underrun, before the first menu overlay configuration; its zero overlay extractor and engine error bits therefore cannot prove whether the later records were extracted, written, cached or blended.  No repository source, Main, helper, RBF or target file is changed while collecting or analyzing this evidence.

#### Next Steps:

Keep the accepted helper, Main and seed-20 RBF installed until the next boundary is approved.  The smallest decisive follow-up is an FPGA-observability-only schema update that captures after a menu style event rather than the earlier sticky audio underrun and positively counts overlay records, plane bytes and commits, DDR writes, row-cache fills, style publications, row-tag matches and nonzero-alpha blend samples; strengthen the overlay engine bench with a moving native raster and selection rectangle, then build only a timing-clean RBF.  These counters will distinguish missing in-band extraction, plane storage or cache delivery from final video blending without changing DVD selection, helper transport or overlay rendering behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 827 COMMIT Unreleased 673b6d7 2026-08-31T10:20:37-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Prove the exact DVD highlight style and selected-region plane indices emitted by the helper before considering any FPGA or RBF change.

#### Outcome:

The user approved and source `673b6d7` implements the helper-only observability boundary after the physical menu regressed from sparse distorted selection pixels to no visible indicator.  Independent absolute-path FTP readback first proved the installed artifacts were exactly the intended 904,564-byte source-`3e4f54c` helper at SHA-256 `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, the 1,174,492-byte source-`53ccc04` Main at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, and the unchanged 4,511,756-byte seed-20 RBF at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  Every successfully emitted overlay configuration or style record now reports its visible and menu flags, inclusive highlight rectangle, four decoded RGBA entries, exact two-bit plane-index histogram inside the selected rectangle, total selected pixels and the subset whose mapped highlight alpha is nonzero; the transport bytes, decoder, scheduler, menu selection and overlay behavior are unchanged.  The strict focused subpicture test proves the exact `0,2,2,0` histogram plus invalid-bound and persistence cases, and the existing random-access and menu-hop regressions pass.  The complete native helper compiles and its capability smoke test passes after demoting only the pinned DVD headers' pre-existing ignored-`gcc_struct` attribute warning on the local AArch64 GCC 15 host; no authorized non-archived DVD image is locally available for the real-menu harness.  An exact detached build-PC checkout of `673b6d7819a666b3b3387be3b594085ff6776b12` builds only `/home/vash/MiSTer-Media-Player-673b6d7/host/build/MediaPlayer_Helper`, a 908,660-byte stripped static ARMv7 hard-float executable with no dynamic section at SHA-256 `e0960b0fb2dcd95cb7c759803ba5e3c6a873a8feb57c5e9ab2c1e23e8af36050`; Main, RTL, QSF, RBF and Quartus remain untouched.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-673b6d7/host/build/MediaPlayer_Helper` from the build PC, restore executable permission if needed, and verify the destination SHA-256 is `e0960b0fb2dcd95cb7c759803ba5e3c6a873a8feb57c5e9ab2c1e23e8af36050`.  Restart the physical DVD, reach the menu, move the selected item at least once and capture a fresh helper log containing the new `DVD overlay record=` lines; the emitted style is capable of drawing a marker only when it reports `visible=1`, at least one nonzero-alpha RGBA entry maps to a populated histogram bin, and `selected_nontransparent_pixels` is nonzero.  Preserve Main and the seed-20 RBF because this result will decide whether the missing indicator originates before or after FPGA overlay composition.

#### Files Modified:

- host/arm/dvd_spu.c
- host/arm/dvd_spu.h
- host/arm/media_player_helper.c
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 826 COMMIT Unreleased 3e4f54c 2026-08-31T10:11:41-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Qualify the source-`3e4f54c` physical-disc root-menu recovery and selected-button visibility from the user's fresh helper log, screenshot and telemetry.

#### Outcome:

The fresh physical Coming to America run reaches and continuously renders the root menu after the root navigation hop, and its helper log uniquely exercises the candidate random-access path by retaining sequence, intra and following-reference offsets 0, 296 and 7,892 with no discarded context pictures.  The 10,602,943-byte log `.ai/current_results/MediaPlayer_ARM.log`, SHA-256 `c6d87b215ad361f91d75b072313e6c04db712ca538be42ac7320a0e7c217322a`, records nine complete subpicture overlay updates and 50 successful directional transitions with valid authored highlight data; its final selection is button 3 at rectangle 311,389 through 430,436 with nontransparent palette `000ffb80`, and the helper remains active beyond 427 seconds without a malformed subpicture, helper fatal or process exit.  The matching 696,371-byte screenshot, SHA-256 `5f86fae990c98f7a6d7c469784e9663c648a15413bdcf26291781f3bd37f863f`, shows the clean menu background but no selected-button indicator in that unobscured button-3 rectangle.  The checksum-valid schema-20 telemetry at SHA-256 `d0b7c79989b398cf5e59aab0d54e2801b820be41232c47a282e64639d7aec88c` is a sticky STC-second-4 snapshot caused by one isolated `0x0400` audio underrun before menu entry, so its clear overlay error bits cannot qualify later menu activity.  This run accepts the candidate's root-menu random-access recovery but rejects visible selected-button output; the log clears libdvdnav selection, button geometry and palette acquisition while leaving the emitted physical overlay plane/style record versus FPGA compositor boundary unresolved, and no source, Main, RBF or target configuration changes during collection.

#### Next Steps:

Keep the running menu, helper, Main and frozen seed-20 RBF unchanged until the installed helper, Main and RBF hashes are independently read back.  After user approval, make a helper-only observability change that logs each emitted overlay configuration or style record together with visibility, menu flag, rectangle, decoded highlight RGBA values and selected-region plane-index histogram, then require the physical disc to prove nonzero selected pixels and a nontransparent emitted style before considering any RTL or RBF change; preserve the current root-hop filter and ignore the separately identified one-second no-progress false trigger for this boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 825 COMMIT Unreleased 3e4f54c 2026-08-31T09:12:37-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Determine whether the repeated physical-disc root-menu black screen qualifies the source-`3e4f54c` random-access correction.

#### Outcome:

The repeated test does not exercise source `3e4f54c`.  Absolute-path FTP readback shows that `/media/fat/linux/MediaPlayer_Helper` remains the 904,564-byte source-`53ccc04` helper at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, rather than the newly built 904,564-byte source-`3e4f54c` helper at `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`; the installed 1,174,492-byte Main remains the intended source-`53ccc04` executable at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`.  The 7,126,742-byte matching helper log `/tmp/entry825_root_menu_black_arm_helper.log`, SHA-256 `c5914545ef52c3eda200d93215c682cb0f40adf2d0cc905d52e399eb111be895`, independently identifies the old code by printing `DVD random access discarded 0 leading B picture(s)` at startup and after the successful zero-tail root hop instead of the candidate's sequence, intra and following-reference offsets.  The 4,809-byte grayscale capture `/tmp/entry825_root_menu_black.png`, SHA-256 `1c64413772575d21111b51ba9e8f14363179d012e6d97188422f161bb86caa02`, contains all 64 schema-20 prefixes, row indices and parity bits with matching checksum `9e4824d8`; it records 24,625 accepted bytes, 12,305,210 decoder clocks, zero completed or displayed pictures and exactly error `0x0200`, the B-picture presentation failure, on a B-picture header at temporal reference 12.  This black-screen result is valid evidence for the still-installed predecessor but neither accepts nor rejects the source-`3e4f54c` helper, and no source, Main, RBF or target configuration is changed during collection.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, obtain only `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper` from the build PC, verify its local SHA-256 is `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, and replace `/media/fat/linux/MediaPlayer_Helper`; if FileZilla refuses overwrite, delete that exact destination after the core has exited and upload the candidate under the exact same name.  Restore executable permission if needed, then require an independent destination readback matching the candidate hash before repeating the physical-disc `M` test; do not replace Main or the frozen seed-20 RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 824 COMMIT Unreleased 3e4f54c 2026-08-31T09:00:09-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Require complete MPEG-2 sequence and reference-picture context before releasing video after a DVD random-access hop.

#### Outcome:

Source `3e4f54c` moves the helper's initial DVD random-access logic into a focused filter that withholds each initial or reset-causing stream until it has a complete sequence header, an I reference and the following I/P reference, neutralizes every start code in contextless pictures before that sequence plus pre-I and open-GOP leading-B pictures while preserving byte positions and timestamp records, and logs the retained offsets and discarded-picture counts.  The deterministic regression proves a prior contextless P picture, a post-sequence pre-I P picture and a leading B picture are hidden while the qualifying sequence/I/P group is retained, and rejects an incomplete group without a following reference.  The exact native helper builds with `-Werror`; the focused random-access, subpicture and menu-hop tests pass; and the strengthened Coming to America authored-directory harness completes root navigation, all four directional commands and menu continuation while requiring and observing a post-root restart group at sequence, I and following-reference offsets 0, 296 and 7,892, with 17 overlay commits, 1,468,899 plane bytes, 1,335 visible highlighted states and a 4,637-pixel selected region.  Exact detached source `3e4f54c902dbb27a89c3d32eb25df2954bf43a88` produces a 904,564-byte stripped static ARMv7 EABI5 helper at `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper`, SHA-256 `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, with no dynamic section; Main, RTL, QSF, the frozen seed-20 RBF and Quartus are unchanged.

#### Next Steps:

Stop the running MediaPlayer helper or exit the core, manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper`, restore executable mode if the transfer client clears it, and verify the exact size and SHA-256 before restarting.  Preserve the installed source-`53ccc04` Main and frozen seed-20 RBF, load the physical Coming to America disc, press `M` during first-play and require the root menu to replace the black screen without a decoder diagnostic; if it appears, leave the menu visible for a capture before separately returning to entry 822's fragmented `SET UP` highlight defect.

#### Files Modified:

- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/dvd_random_access.c
- host/arm/dvd_random_access.h
- host/arm/media_player_helper.c
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_random_access.c

#### Status:

- [x] Built
- [ ] Passed

---

## 823 COMMIT Unreleased 53ccc04 2026-08-31T08:34:42-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Capture and isolate the exact-source black-screen failure produced by a physical-disc root-menu command after correcting the Main deployment.

#### Outcome:

Absolute-path readback verifies the intended artifact combination before interpretation: the installed 904,564-byte helper is exact source `53ccc04` at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, the 1,174,492-byte Main is exact source `53ccc04` at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, and the unchanged 4,511,756-byte seed-20 RBF remains `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  The user presses keyboard `M` during physical-disc playback and receives a black diagnostic raster instead of the root menu.  The 31,878-byte 1920-by-1080 scaled capture `/tmp/entry823_root_menu_black.png`, SHA-256 `90df9d893e1875eab6a97663de564c254d7c4ea810b176ec0397bf1fb12e35fc`, decodes with all 64 schema-20 headers, row indices and parity bits valid and checksum `1ffb896e` matching.  Its fatal snapshot accepts only 16,467 video bytes and runs 19,694 decoder clocks without a first presentation before latching exactly error `0x0002`, the phase-one probe error; the retained current header is a P picture while frame-rate code and completed-picture count remain zero, and every syntax, prediction, inverse-quantization, IDCT, reconstruction, writer, cache, presentation, audio and DVD-overlay error bit is clear.  The matching 1,578,363-byte helper log at SHA-256 `4e50195d8d16a41138d9e679e4a22518fd1dab109afc9af5991fd207dce4f08b` proves that root navigation succeeds, discards zero partial-block bytes, is classified as a stream hop, completes the new Main/helper ready barrier with 59,752 pending Main bytes discarded, rearms the random-access filter with zero leading B pictures, publishes six subpicture overlays and continues transferring hundreds of megabytes without a helper fatal.  This rejects source `53ccc04` on the physical root-menu gate and localizes the black screen to the reset FPGA session beginning without sufficient independent sequence and reference-picture context rather than to deployment, Main/helper deadlock or an overlay fault; entry 822's fragmented selected-button result remains a separate open defect.

#### Next Steps:

Keep the exact source-`53ccc04` Main, helper and frozen seed-20 RBF unchanged and do not use this failed session for further menu commands.  After user approval, make a bounded helper-only random-access correction that withholds every reset-causing DVD stream hop until complete independently decodable sequence context and an intra reference are present, add a real authored-disc regression reproducing the root call from the observed mid-first-play position and require its first outgoing video to decode cleanly, then rebuild only the helper and repeat `M`; do not change Main, RTL, QSF, the RBF or the separately open overlay-highlight path in that boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 822 COMMIT Unreleased 53ccc04 2026-08-31T08:18:13-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Capture the first physical-disc selected-button result from the source-`53ccc04` helper and identify the exact installed artifact combination that produced it.

#### Outcome:

The user enters the Coming to America root menu with keyboard `M`, moves the selection to `SET UP` and reports that the barely visible indicator appears distorted.  The 795,417-byte 1920-by-1080 scaled capture `/tmp/entry822_setup_selected_distorted.png`, SHA-256 `3da0f2580528471e099035487beba1a2d0258d5cca4584b26633f055539dbc20`, preserves the menu background and shows a cyan-green selection rendered as sparse horizontal fragments across `SET UP`; the large black-and-white lower-left cadence telemetry block is the previously identified diagnostic overlay rather than the selected-button bitmap.  Its matching 2,679,653-byte helper log at SHA-256 `aad53eecef30d4b3e78ed114a5b15c05469e3073813f5506ab50d9f6f46b5df8` records a successful authored Right transition from button 1 to button 2 with exact rectangle 212,397 through 302,436 and selection palette `000feb80`, two menu commands, two subpicture overlay updates and no fatal or helper exit.  Absolute-path readback identifies a mixed deployment: the 904,564-byte installed helper is the exact source-`53ccc04` candidate at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, and the 4,511,756-byte RBF remains the expected frozen seed-20 image at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`, but the 1,174,492-byte installed Main is the older source-`a9899e0` binary at `a276aadcdc5aad4034bc40ee2dff52596fd44876156e24f16289d5a339411636` rather than source `53ccc04` Main at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`.  The valid button transition and correctly bounded but visibly fragmented highlight reject the visible-indicator hardware gate for this helper-and-RBF combination, while the mixed Main means menu-continuation activation and background preservation are not tested.

#### Next Steps:

Do not use this mixed installation to test submenu activation because the older Main retains the unconditional reset that can black the resident menu frame.  After user approval, replace only `/media/fat/MiSTer` with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MiSTer`, require SHA-256 `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, reboot and verify the running artifact combination before repeating the `SET UP` selection capture; if the same bounded horizontal fragmentation remains, keep Main and the helper frozen and isolate the overlay plane packing, line-cache addressing and authored SPU field layout before considering any FPGA change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

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
