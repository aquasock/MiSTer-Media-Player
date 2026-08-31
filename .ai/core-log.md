## 808 COMMIT Unreleased ??? 2026-08-31T01:28:52-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Implement authored DVD-Video menu navigation and subpicture highlights through the existing libdvdnav session and a bounded FPGA DDR overlay plane.

#### Outcome:

The user explicitly approves the full menu-support boundary outlined in entry 794 while continuing ordinary DVD playback observation against the accepted source-`6e44472` baseline.  The planned source keeps pinned libdvdnav as the DVD virtual-machine and button-navigation owner, starts ISO and direct optical playback through authored first-play behavior, extends the private Main/helper channel for directional selection, activation and return-to-menu, preserves finite and indefinite still-menu interaction, and retains the accepted title, chapter, pause, audio and CSS paths.  The helper will assemble and decode the selected DVD subpicture stream into packed two-bit pixels, carry palette, alpha and highlight state over a length-bounded in-band record, and the FPGA will store the 720-by-480 overlay in a dedicated unused DDR region, read it through an explicit arbiter client and composite it at native video coordinates before the existing cadence diagnostic overlay.  This avoids an impossible full-screen M10K allocation and does not repurpose decoder frame banks.  The authorized DVD-Video application books remain unavailable in `core-reference.md`, so implementation will use the exact pinned VideoLAN APIs and retained-disc behavior without claiming formal DVD-Video conformance.

#### Next Steps:

Implement the host navigation, SPU decoder, protocol, Main input bindings, in-band overlay records, DDR writer and display compositor as one hardware-useful boundary.  Prove malformed and fragmented SPU rejection, palette and alpha mapping, button-highlight changes, still-menu control, title entry and return-to-menu, overlay clearing across hops and session resets, byte-identical ordinary file and main-title playback, and DDR arbitration without decoder starvation; then run the complete accepted host and RTL regressions before one clean pinned-seed-19 Quartus build.  Install only an RBF with positive setup, hold, recovery, removal and minimum-pulse-width margins together with matching Main and helper binaries, then qualify authored menus, chapters, audio and video on retained ISO and physical-disc sources.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- MediaPlayer.sv
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
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

#### Status:

- [ ] Built
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

## 781 COMMIT Unreleased 0711d3d 2026-08-30T15:36:06-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Accept the corrected Blazing Saddles ISO startup on hardware and define the next DVD feature boundary.

#### Outcome:

The user reports that the complete Blazing Saddles ISO now starts normally, continues beyond five minutes with clean visible playback and raises no fatal telemetry, explicitly accepts the ISO initial random-access correction as working and elects to leave the title playing to completion.  This clears the deterministic first-GOP failure fixed by source `0711d3d`: the installed helper safely discarded the two unavailable open-GOP leading B pictures and crossed far beyond the former 7,997-byte prediction-error stop without a core, Main or configuration change.  Full-title completion remains useful soak evidence but is not required to establish that the bounded startup correction passed its hardware gate.

#### Next Steps:

Let the current title continue and record its terminal result when available, then target encrypted ISO files within the existing main-feature `iso:` backend rather than physical discs or interactive menus.  Keep that work host-only and preserve longest-title selection, ordinary decrypted ISO playback, Main and FPGA behavior; first choose an acceptable CSS dependency and distribution boundary, add the controlled CSS reference required by project policy, prove native decryption against an authorized encrypted-image fixture, then build and deploy only the helper for HDMI and S/PDIF hardware qualification.  Interactive menus remain later because they additionally require navigation control, subpicture rendering, button highlights, still-frame behavior and remote-control input.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 780 COMMIT Unreleased 0711d3d 2026-08-30T15:15:47-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Make decrypted DVD ISO title starts safe when an authored open GOP begins with B pictures whose earlier reference lies outside the selected title boundary.

#### Outcome:

The first hardware launch of the complete 6,501,636,096-byte Blazing Saddles image opened the unencrypted ISO, selected longest title 2 at 5,567 seconds and identified AC-3 substream `0x80`, but schema-20 telemetry stopped after the initial I picture with prediction error `0x0004`; native comparison then proved the ISO retained decode-order B0 and B1 pictures whose earlier reference lies before the selected title, while the hardware-passed remux begins I2, P5, B3 and B4.  Source `0711d3d` adds a bounded ISO-only initial random-access filter that holds the existing scheduler queue through the second I/P reference and neutralizes only those unavailable leading B pictures without changing byte positions, timestamps, ordinary files, Main or FPGA logic.  The native build reports exactly two discarded pictures and produces I2, P5, B3 and B4 at its opening, a complete-GOP FFmpeg decode has no errors, and the ordinary five-minute Blazing Saddles MPG output remains byte-identical at SHA-256 `45401ab3`.  The exact 817,700-byte static ARM helper from `0711d3d`, SHA-256 `536250b8`, is installed by verified staging and same-directory rename with matching final readback; the previous `73d2f507` helper is preserved in both the backup directory and `/media/fat/linux/MediaPlayer_Helper.pre_0711d3d_73d2f507`.  The accepted source-`205bbd7` seed-19 RBF and ISO-capable Main remain unchanged, and hardware replay of the corrected helper is pending.

#### Next Steps:

Relaunch the same Blazing Saddles ISO in Native 480i at 16:9, Bob and HDMI and confirm that picture and audio begin normally without fatal telemetry; if that startup gate passes, let the title run long enough to confirm sustained playback and then check S/PDIF without rebuilding the core.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 779 COMMIT Unreleased 205bbd7 2026-08-30T14:31:18-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Capture and independently verify the accepted NARA MPD-D2 qualification control on the installed source-`205bbd7` core.

#### Outcome:

At the user's request, one screenshot and the matching helper log are collected from the completed `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob` run; the visible terminal frame confirms that this adopted NARA-named qualification file contains the Blazing Saddles footage referenced by the user.  The helper identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,200,545 bytes through the fast path in 299.946401 seconds at 1.207551 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero.  The 639,401-byte screenshot `/tmp/entry779_nara_mpd_d2_qualification_5min_pass.png`, SHA-256 `518e59b9673258da6e1fca55af759d6ac02f6c2ff3ae5d589cd1de792f64d677`, visibly preserves a clean final western scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `bfb4da57` matches; the terminal no-progress snapshot accepts 300,095,133 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 12,330,598-byte helper log has SHA-256 `b2e3ccb3ce427162adea35ccdceca6226a76ad19fca7e5f3d3279dcc0744ccc4`.  This replaces the user-report-only NARA evidence in entry 778 with a complete captured control result and changes no source, installed file, playback mode or configuration.

#### Next Steps:

Keep source `205bbd7`, fitter seed 19, the installed RBF, native 480i mode and current decoder capability boundary unchanged.  All three adopted five-minute frame-picture MPD-D2 VOBs now have accepted results, and each captured run shows real-time completion with no audio starvation; field-picture MPEG-2 remains intentionally deferred.  If the user wants to resume the previously paused roadmap, scope decrypted ISO playback as a host-side input and navigation boundary first, without an FPGA rebuild unless later evidence proves one necessary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 778 COMMIT Unreleased 205bbd7 2026-08-30T14:27:08-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Resolve the adopted NARA control filename and accept the complete three-file MPD-D2 decoder-throughput gate on source `205bbd7`.

#### Outcome:

The user clarifies that the NARA file named in the preceding positive report is exactly `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob`, so the earlier statement that it is good is assigned to that adopted control rather than to a separate Blazing Saddles fixture.  Together with entries 776 and 777, source `205bbd7` now passes the complete targeted native-480i MPD-D2 gate: NARA is user-reported clean, while the formerly worst-stuttering Coming to America and Big Lebowski VOBs both complete in approximately 299.93 seconds with perfect user-observed video and audio, all 362,080,761 transport bytes on the fast path, every AC-3 frame and PCM sample emitted, and checksum-valid schema-20 telemetry showing zero hardware errors, audio underruns, transport blocks, deadline gaps and cadence outliers.  This directly clears the sustained decoder-backpressure and ordered-audio-starvation failure that previously began near 56 seconds for Coming to America and 33 seconds for Big Lebowski.  The installed 4,440,192-byte seed-19 RBF remains SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`; no source, installed file, playback mode or configuration changes.

#### Next Steps:

Keep source `205bbd7`, fitter seed 19, the installed RBF, native 480i mode and current decoder capability boundary unchanged.  The frame-picture MPD-D2 VOB compatibility and real-time throughput gate is accepted; field-picture MPEG-2 remains intentionally deferred.  If the user wants to resume the previously paused roadmap, scope decrypted ISO playback as a host-side input and navigation boundary first, without an FPGA rebuild unless later evidence proves one necessary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 777 COMMIT Unreleased 205bbd7 2026-08-30T14:25:12-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Accept the formerly stuttering Big Lebowski MPD-D2 VOB on the installed source-`205bbd7` core and retain the user's separate control-file report without assuming an ambiguous filename.

#### Outcome:

The user reports that `/media/fat/games/MediaPlayer/the_big_lebowski_mpd_d2_5min.vob` runs perfectly and leaves its terminal telemetry visible for one requested capture; this file previously developed severe audio stutter near 33 seconds.  The matching helper log identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,080,761 bytes through the fast path in 299.931120 seconds at 1.207213 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero; the earlier nominal HDMI run on the previous decoder required 309.292 seconds and accumulated the same starvation deficit.  The 561,604-byte screenshot `/tmp/entry777_lebowski_mpd_d2_5min_pass.png`, SHA-256 `17a66fd1e1e2b1b9be0db3a86378778061f75fefbdb23b026838a9b270372617`, visibly preserves the clean intended terminal toilet scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `9d09b149` matches; the terminal no-progress snapshot accepts 299,975,349 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 12,195,247-byte helper log has SHA-256 `e22a4be8861fa1ab7274a4b5e7dcaecdac414590956d3b97986e74fb072a04f2`.  The user separately states that “Blazing Saddles is good (the NARA file)”; because Blazing Saddles and the NARA qualification VOB are distinct known fixtures, this exact positive report is retained without assigning it to one filename.  No further screenshot is requested, and no source, installed file, playback mode or configuration changes.

#### Next Steps:

Keep the installed source-`205bbd7` core and native 480i mode unchanged.  Confirm whether the user's “Blazing Saddles is good (the NARA file)” report refers to `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob`, a Blazing Saddles fixture, or both; run only any still-unverified adopted control and report its exact filename and result.  Coming to America and Big Lebowski have now both cleared their former sustained audio-starvation failures, so do not rebuild or alter the decoder.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 776 COMMIT Unreleased 205bbd7 2026-08-30T14:22:25-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Accept the previously worst-stuttering Coming to America MPD-D2 VOB on the installed source-`205bbd7` core and quantify removal of the sustained audio-starvation failure.

#### Outcome:

The user chooses `/media/fat/games/MediaPlayer/coming_to_america_mpd_d2_5min.vob` first because it previously developed severe audio stutter near 56 seconds and its opening song makes defects easiest to hear, then reports that the complete run is now perfect and leaves the terminal telemetry visible for collection.  The matching helper log identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,080,761 bytes through the fast path in 299.928360 seconds at 1.207224 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero; the prior failing run required 308.544 seconds and audibly starved.  The 795,454-byte screenshot `/tmp/entry776_coming_mpd_d2_5min_pass.png`, SHA-256 `a37601e8f1cc65160c57397e5cf92ebe300c7b95036b4f83cb76d0e0d771353b`, visibly preserves a clean final pool scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `883c99bf` matches; the terminal no-progress snapshot accepts 299,975,349 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 13,383,575-byte helper log has SHA-256 `6cf89dd8da88b9d49e8d6b8d9b75baee6ebd950bc2e460c8ed138b1048481314`.  A later redundant raw-screenshot request occurred after the user had changed media and is explicitly excluded; no source, installed file, playback mode or configuration change is attributed to this accepted capture.

#### Next Steps:

Keep the installed source-`205bbd7` core and native 480i mode unchanged.  When ready, run `/media/fat/games/MediaPlayer/the_big_lebowski_mpd_d2_5min.vob` once for five uninterrupted minutes with HDMI audio and check S/PDIF for a representative interval if convenient, then leave its terminal telemetry visible for one requested capture; afterward repeat the NARA MPD-D2 control.  Do not capture or interrupt unrelated playback, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 775 COMMIT Unreleased 205bbd7 2026-08-30T14:09:33-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Install the timing-clean source-`205bbd7` seed-19 RBF with an independently verified rollback and leave hardware acceptance pending.

#### Outcome:

At the user's explicit authorization, the archived 4,440,192-byte source-`205bbd7` seed-19 RBF is staged from the build PC and independently reconfirmed at SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  Absolute FTP inventory finds exactly one installed core, `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; independent readback proves that it contains the accepted 4,461,996-byte source-`cee1a9e` build at SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`.  That exact readback is preserved as `/media/fat/_MediaPlayer_Backups/MediaPlayer_205bbd7_pre_cee1a9e_162c788d.rbf`, and a separate absolute-path download compares byte-for-byte.  The single installed filename is then replaced in place with the source-`205bbd7` candidate; both the install helper's verification and a second independent absolute-path readback reproduce all 4,440,192 bytes and the complete `7f60ec43` hash.  No Main, helper, media, menu configuration or repository source changes, and the running FPGA remains unchanged until the user reloads the core.

#### Next Steps:

Reload MediaPlayer from the MiSTer menu so the installed source-`205bbd7` RBF configures the FPGA, retain native 480i mode, and begin with the NARA MPD-D2 five-minute control over HDMI while also checking S/PDIF for a representative interval.  If the control remains clean, test the Coming to America and Big Lebowski MPD-D2 VOBs in separate uninterrupted five-minute runs and preserve telemetry after each; accept the candidate only if video is stable, audio is continuous apart from the previously accepted allowance of one isolated FIFO underrun, and telemetry is clean.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 774 COMMIT Unreleased 205bbd7 2026-08-30T13:13:46-07:00

#### Coming From:

Unreleased 9f10b55

#### Purpose:

Repair the two seed-19 decoder setup-path families in the registered B-picture lookup implementation without changing its throughput, memory use or reconstruction behavior.

#### Outcome:

Source `205bbd7` cuts the two entry-773 timing cones without changing lookup latency or memory structures.  The fetcher now uses a synthesis-preserved one-bit descriptor occupancy register for response-side direct/pop selection while its multi-bit count remains only on request-capacity and accounting paths; zero-latency, delayed, backpressured and simultaneous issue/response protocol cases all pass.  The B engine captures field-DCT slot and destination-row geometry with the existing execution metadata and uses a constant luma plane for field-DCT launch addresses, removing live `blk[1]` from that failed address path.  Exhaustive B motion math, B field motion, field-motion plus field-DCT, interlaced field-DCT residual, interlaced field motion, mixed pixel oracle, cadence, reorder, timestamp, all reference-overlap cases and the complete native-480i suite pass.  The mixed oracle checks 423,936 samples with zero mismatches outside its established two-level bound, preserves 69,556 DDR reads and remains exactly 1,239,997 cycles.  Exact generic-content simulations complete Coming to America in 128,169,997 cycles or 43.6507 cycles per byte and The Big Lebowski in 136,499,997 cycles or 46.7185 cycles per byte; each completes all 24 P and 58 B pictures with every decoder, reconstruction, writer, presentation and publication error flag clear and remains below the 49.7-cycle real-time boundary.  At the user's explicit authorization, exactly one clean Quartus Prime 17.0.2 build of detached source `205bbd7` completes at pinned seed 19 with no reseed or second compile.  Analysis, fitting, assembly, TimeQuest and Phase-1P report extraction complete successfully using 33,760 of 41,910 ALMs, 52,284 registers, 4,181,443 memory bits in exactly 532 of 553 RAM blocks and 67 DSP blocks.  Every reported timing category is positive: worst setup 0.006 ns, hold 0.244 ns, recovery 4.342 ns, removal 0.500 ns and minimum pulse width 0.925 ns, with zero TNS; the targeted 60 MHz decoder setup domain improves to 1.463 ns with zero violated paths and the 54 MHz video domain is 1.792 ns with zero violated paths.  The preserved 4,440,192-byte RBF has SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  It remains archived only on the build PC and is not installed or launched on the MiSTer.

#### Next Steps:

Keep the currently accepted core installed and do not deploy the archived source-`205bbd7`, seed-19 RBF until the user separately authorizes installation.  After authorization, install and verify that exact hash, then run the NARA MPD-D2 control and the Coming to America and Big Lebowski MPD-D2 VOBs in native 480i, checking HDMI and S/PDIF and preserving telemetry after each uninterrupted five-minute run.  Accept the candidate only if video remains stable, audio remains continuous apart from the previously accepted allowance of one isolated FIFO underrun, and telemetry shows clean decoder, reconstruction, writer, presentation and publication state.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 773 COMMIT Unreleased 9f10b55 2026-08-30T07:19:22-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Use simulation-only B-picture stall attribution to select one direct zero-M10K throughput correction and one final FPGA build.

#### Outcome:

Source `9f10b55` implements an ordered lookup-issue cursor in the B raster engine and a throughput-one mode in the retained-footprint fetcher while preserving registered lookup addresses and data and adding no M10Ks.  The exact Coming-to-America and Lebowski three-second natural-content windows complete in 128,169,632 cycles and 136,495,456 cycles, or 43.65 and 46.72 cycles per input byte, improving total throughput by 22.8 and 20.5 percent over the registered baseline and clearing the calculated 49.7-cycle real-time boundary with all decoder, reconstruction, writer, presentation and cursor-order error flags clear.  Exact motion, field-DCT, cadence, reorder, timestamp, overlap and native-480i regressions pass; the mixed pixel oracle checks 423,936 samples with zero mismatches outside its established two-level bound and preserves 69,556 DDR reads.  Exactly one clean Quartus Prime 17.0.2 build is attempted at pinned seed 19.  Analysis, fitting, assembly and timing-report extraction complete, using 34,051 of 41,910 ALMs, 52,664 registers, 4,181,443 memory bits in 532 of 553 RAM blocks and 67 DSP blocks, but the build gate rejects the RBF because the 60 MHz decoder setup slack is negative 0.176 ns with 23 violated paths; hold, recovery, removal and minimum-pulse-width margins remain positive 0.242, 3.847, 0.528 and 0.925 ns, and the 54 MHz video setup margin is positive 2.654 ns.  The leading path runs from `block_fetcher1|descriptor_count[2]` to `block_fetcher1|word_data[20][24]`; a second violated family runs from `b_probe|blk[1]` into `fetch_launch_phase1_base_addr`.  The rejected 4,452,080-byte RBF has SHA-256 `95b109a92aec3b2c39304997c72fa51a391fbbdcbe05e811c307b497f1f1b136`; it is not installed, and no reseed or second compile is performed.

#### Next Steps:

Keep the accepted artifact installed on the test MiSTer and do not deploy this timing-failed RBF.  Use the extracted seed-19 path reports and RTL simulation to prepare a narrowly bounded timing correction that breaks the descriptor-control-to-`word_data` path and simplifies the `blk`-to-launch-address path without reducing the measured throughput, changing reconstruction semantics, adding M10Ks or changing the seed.  Present that source boundary for approval before any further implementation or Quartus compile; the next approved candidate must repeat the exact functional and natural-window simulation gates before one timing build is considered.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 772 COMMIT Unreleased 0a9d48a 2026-08-30T07:15:38-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Capture the controlled Coming to America MPD-D2 failure and distinguish audio starvation from visible video-cadence failure and from insufficient buffering.

#### Outcome:

The user leaves the completed uninterrupted S/PDIF run of `/media/fat/games/MediaPlayer/coming_to_america_mpd_d2_5min.vob` untouched for collection and reiterates that only audio stutters while video remains rock solid.  The 796,193-byte screenshot `/tmp/entry772_coming_mpd_d2_telemetry.png`, SHA-256 `250135e768052a0ccc58f951c1322fa361375f02a65d5e812929fe1c0fbdb05b`, has 64 valid schema-20 headers, indices and parity bits and matching checksum `c4aeaacf`; its sticky first-underrun snapshot occurs at 56.079121 seconds after accepting 55,768,576 clean-video bytes, with 1,671 displayed pictures and 1,670 swaps, consistent with real-time video cadence at the audible failure.  The decoder input is intrinsically stalled for 94.498 percent of session cycles, divided into 6.363 percent I, 22.237 percent P and 65.899 percent B-picture stall, while presentation hold contributes only 3.777 percent, destination hold is zero and presentation hold has scratch availability for only 668 cycles.  This differs from Lebowski's 85.208-percent intrinsic and 13.042-percent presentation split but preserves the common approximately 98.3-percent total inability to accept transport bytes and dominant B-picture contribution, disproving a third presentation scratch frame as a general correction.  The matching 7,598,795-byte helper log `/tmp/entry772_coming_mpd_d2_telemetry.log`, SHA-256 `ec8bb543428ab4f4b8f920e287b65dfad64ec622b23264ec67a3caf275a02c95`, names the exact VOB and S/PDIF path, eventually emits all 14,400,000 samples and submits all 362,080,761 bytes through the fast path, but requires 308.544 seconds; its worst 10-, 20- and 30-second transport windows are only 1.112, 1.120 and 1.122 MB/s against the approximately 1.207 MB/s real-time requirement.  The 16,384-frame audio FIFO already provides approximately 341 milliseconds of reserve, so more buffering would postpone rather than remove sustained starvation; the accepted fit uses 532 of 553 M10Ks, leaving 21, and no additional M10Ks are indicated.  This corrects entry 771's overly broad wording: decoder-side shared-transport backpressure starves ordered audio ingress, but the hardware evidence does not show visible video cadence loss.

#### Next Steps:

Keep the accepted seed-19 RBF, host binaries, ISO deployment and all existing FIFO depths unchanged.  The smallest useful correction cycle should target B-picture intrinsic decode throughput with zero new M10Ks, preserve reconstruction arithmetic and presentation behavior, and use the unused schema-20 telemetry words to attribute B stalls among compressed-bit parsing, residual replay, prediction and row-retirement waits if static analysis cannot justify a direct scheduling overlap.  Record and obtain approval for that source boundary before implementation, then run exact simulation regressions, one clean seed-19 Quartus build with full timing and resource gates, and the NARA control plus both natural-content VOBs through five-minute HDMI and S/PDIF validation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 771 COMMIT Unreleased 0a9d48a 2026-08-30T06:57:06-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Reject the natural-content MPD-D2 VOB gate and identify the repeatable S/PDIF collapse as sustained real-time decoder-throughput loss.

#### Outcome:

The user corrects the preliminary VOB acceptance: the NARA qualification VOB and existing MPG fixtures play perfectly, but `the_big_lebowski_mpd_d2_5min.vob` begins severe S/PDIF stutter with telemetry near 33 seconds and `coming_to_america_mpd_d2_5min.vob` near 56 seconds.  A controlled uninterrupted Lebowski rerun reproduces collapse to near silence, temporary full recovery, a second collapse and another recovery without reload or reboot.  The exact helper log names the correct VOB and S/PDIF path; by 205.999972 seconds it has emitted 9,460,224 samples against 9,887,998 wall-clock samples, a 427,774-sample or 8.91-second deficit, while its maximum video PTS represents only 197.397 seconds of media.  At 206.58 seconds Main has submitted 238,139,400 bytes, about 1.153 MB/s, entirely through the verified fast path.  Reanalysis of the earlier apparent Lebowski HDMI pass shows that it required 309.292 seconds to transport 300.038 seconds of media and accumulated the same approximately 426,000-sample scheduler deficit; schema-20 error `0x0400` is a sticky first-underrun indication, not a count proving only one isolated underrun.  In contrast, NARA remained about 21,000 samples ahead and completed in 300.006 seconds.  Independent FFprobe comparison finds matching continuous timestamps and required 8,000,000-bit/s, 720x480, 30000/1001 TFF properties across all three MPD-D2 VOBs, while the two passing natural-content MPG video payloads are only 5,398,682 and 6,525,205 bits/s.  The evidence therefore localizes the failure to content-dependent clean-video ingest or decoder drain throughput below real time on sustained natural-content 8 Mbps input, with the ordered helper scheduler then starving audio; it does not support file corruption, permanent FIFO fill, S/PDIF framing failure or authored timestamp discontinuity.  Captures `/tmp/entry771_lebowski_mpd_d2_spdif_stutter.png`, `/tmp/entry771_lebowski_mpd_d2_spdif_recovered.png` and `/tmp/entry771_lebowski_mpd_d2_spdif_second_collapse.png` hash `1a251f44`, `2adcdf3c` and `b6dd0351`; their corresponding helper-log snapshots hash `73638139`, `17344fcb` and `ddab1a0b`.  No installed file, repository source or target configuration changes, and ISO deployment is paused at the user's direction.

#### Next Steps:

Keep the accepted seed-19 RBF and all installed host binaries unchanged and do not proceed with ISO installation.  Use the retained natural-content streams and logs for an offline stage-throughput analysis, then propose the smallest measurable correction that raises sustained frame-picture MPD-D2 decode above real time without reducing the adopted constant 8 Mbps qualification requirement.  Any new diagnostic media, RTL instrumentation, timing-sensitive optimization or Quartus rebuild requires a separately recorded and approved commit boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 770 COMMIT Unreleased 0a9d48a 2026-08-30T06:28:45-07:00

#### Coming From:

Unreleased 1e8c44f

#### Purpose:

Add a bounded unencrypted DVD ISO source that automatically plays the longest title through the existing Program Stream pipeline.

#### Outcome:

The user explicitly authorizes image-file playback while the final Coming to America VOB hardware run proceeds and supplies three full images on the authorized build PC.  Source `6af108f` adds `.iso` selection and `iso:` routing in Main, a rewindable helper source that uses pinned VideoLAN `libdvdread` 7.1.1 and `libdvdnav` 7.0.0 to read UDF and IFO metadata and expose the longest title in program-chain order, explicit scrambled-PES rejection, architecture documentation and a tracked patch that forces libdvdread's builtin unencrypted reader instead of linked or dynamically discovered libdvdcss.  The first native build exposed only a malformed upstream-patch hunk count, corrected by `0128efe`; debugger evidence then showed that libdvdnav 7.0.0 drops caller stream callbacks in `dvdnav_reset`, so `85ca285` safely reopens the same image and title on rewind.  Final source `0a9d48a` narrowly suppresses libdvdread's ignored x86-only `gcc_struct` attribute warning at the ARM helper boundary.  Native validation fully processes The Big Lebowski title 1, 7,036.1 seconds, 5,529,130,715 video bytes and 220,760 AC-3 frames with exit zero; bounded probes start clean decoding of Coming to America title 1 and correctly select Blazing Saddles title 2.  Exact-commit native, static ARM and pinned Main builds pass; the 817,700-byte helper hashes `b7ccc160`, has no dynamic section and no undefined `dlopen`, `dlsym` or dvdcss symbol, while the 1,170,340-byte Main hashes `01229bc5` and contains both the ISO selector vector and `iso:` route.  Menus, navigation controls, subtitles, track switching, direct optical-disc access and CSS remain unsupported, and no FPGA source, RBF or target installation changes.

#### Next Steps:

First capture and record the user's completed Coming to America VOB result without disturbing its target evidence.  Then preserve the installed helper and Main, install the exact `b7ccc160` helper and `01229bc5` Main with byte-identical readback, reboot to activate Main, place one supplied unencrypted ISO on MiSTer-accessible storage, and run the first hardware gate in Native 480i with HDMI before checking S/PDIF.  Do not rebuild or replace the accepted seed-19 FPGA artifact.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/libdvdread-disable-css.patch
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 769 COMMIT Unreleased 1e8c44f 2026-08-30T06:12:22-07:00

#### Coming From:

Unreleased 8623431

#### Purpose:

Pin fitter seed 19 in the source-controlled Quartus project without changing decoder capability or rebuilding the accepted FPGA artifact.

#### Outcome:

The user directs that decoder capability remain at the accepted boundary and explicitly requests correction of the repository QSF to the established fitter seed.  Source `1e8c44f` changes the sole `MediaPlayer.qsf` `SEED` assignment from 17 to 19 so a future clean build selects the proven seed by default; the exact diff contains one replacement line and no decoder, timing-constraint or project-setting change.  The installed and hardware-accepted RBF was already produced by overriding the fitter to seed 19 and passed complete timing, so this source-control correction neither modifies nor reconfigures that artifact.  No Quartus build or target installation is performed, and Main, helper, media, Native 480i configuration and the active two-title VOB tests remain untouched.

#### Next Steps:

Continue the two installed MPD-D2 VOB hardware tests one title at a time and preserve their completed screens for capture.  Do not run Quartus or replace the accepted installed seed-19 RBF now; a clean build and regression are required only when a new release artifact is intentionally produced from this updated project.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
