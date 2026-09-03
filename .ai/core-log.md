## 938 COMMIT Unreleased ??? 2026-09-03T02:28:26-07:00

#### Coming From:

Unreleased 490dc02

#### Purpose:

Normalize each qualifying malformed DVD H.262 sequence boundary across PES fragmentation instead of correcting only the session's initial random-access group.

#### Outcome:

Implementation approved from entry 937's physical proof that source `490dc02` corrects and displays The Big Lebowski's first authored still but leaves the immediately following seven-second still unchanged, where the decoder repeats the same source-21 failure after exactly 188 new accepted bytes.  The change will remain helper-only and preserve the decoder, Main, RBF, stream length, offsets and every conforming or out-of-scope picture while carrying bounded elementary-stream syntax state across DVD video PES payloads and delaying only the byte needed to validate `progressive_frame` before conditionally setting its preceding `chroma_420_type` bit.

#### Next Steps:

Implement a DVD/ISO video-payload normalizer that recognizes valid 4:2:0 sequence extensions, initial I pictures and complete-frame picture coding extensions across arbitrary PES splits, emits all bytes in original order with bounded one-byte lookahead, flushes or discards that held byte at the existing terminal and navigation boundaries, and logs every correction.  Extend the focused production regression with two consecutive captured malformed still prefixes split at every critical header boundary plus conforming, interlaced, non-I and non-4:2:0 controls; extend the Icarus regression to admit both normalized stills without source 21; run strict, sanitizer, analyzer, DVD navigation/output and audio integration suites; then build one static ARM helper for physical Big Lebowski startup, title, Root Menu and repeated-menu testing with Blazing Saddles and Coming to America regression checks.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_h262_restart_normalization.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 937 COMMIT Unreleased 490dc02 2026-09-03T00:41:17-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Normalize The Big Lebowski's nonconforming 4:2:0 progressive-frame chroma flag at the helper's buffered initial I-picture boundary.

#### Outcome:

Implemented the helper-only compatibility normalization approved from entry 936's byte-exact physical evidence.  Immediately after successful random-access filtering, the helper now changes only `chroma_420_type` from zero to one when the buffered restart has a valid 4:2:0 sequence extension and a valid initial complete-frame progressive I-picture coding extension; conforming streams and out-of-scope malformed streams remain byte-identical, stream length and every offset remain unchanged, and the exact offset plus before/after byte are logged.  The captured 191-byte Big Lebowski prefix changes only byte 185 from `0xc0` to `0xc1` and is idempotent.  Its original form raises RTL syntax source 21, while the corrected form reaches the first slice with no syntax error and is accepted as a supported phase-1/native-film picture.  Strict focused C, ASan/UBSan, GCC analyzer, DVD random-access/menu-hop/overlay/SPU/staging/reserve/program-stream, audio seek/UI/visualizer, native static-helper capability and private audio/LPCM tests passed.  The exact ARM release artifact also passed its capability probe and real MP3/WAV/FLAC/Ogg visualizer integration (378/381 pictures and one clear record per file).  No Main, RBF or visualizer change was made.  Built `host/build/MediaPlayer_Helper_ChromaFix_490dc02`, 966052 bytes, SHA-256 `0d99ce70d703eb9486052f8673474aed0b85446e321b73d0d640573f79d3d2c0`.  Physical testing rejects this build for The Big Lebowski while confirming Blazing Saddles remains accepted.  The helper normalizes the first three-second authored still at offset 185 from `0xc0` to `0xc1`; telemetry proves that picture completes, displays and reaches presentation completion with no overlay or presentation fault.  After the still expires, libdvdnav supplies a second seven-second still but `iso_start_filter_active` is already clear, so the normalization is not revisited.  Telemetry then latches H.262 error flag `0x0001` at 5,670 accepted bytes: exactly the first corrected still's 5,473 bytes plus its nine-byte terminal tail plus 188 bytes of the next stream, reproducing the prior source-21 acceptance boundary.  The helper remains alive and continues supplying more than 122 MB, excluding CSS, drive, helper-exit and transport starvation failures.  The 1,178,545-byte log, 1,514-byte screenshot and checksum-valid 441-byte schema-21 sidecar have SHA-256 `9a7607eeeb9ab9030dc8c9d00f1ca03947bc74e91b142374f3cf10c7e347215e`, `3b8e91889e3b2ae78208151f07361f2b540d3f911c330c2916702cb2915d143c` and `4cdc025cc7864ab8449aee283afca0ec433e4e540f04ec8358b3673bae966ad3`.

#### Next Steps:

The next helper-only change should apply the identical narrow normalization at every qualifying DVD elementary-video sequence/I-picture boundary rather than only the session's first random-access group.  Preserve the one-bit 4:2:0/progressive-I gating, byte count, offsets, decoder, RBF and Main; handle start codes and extension fields split across PES payloads with bounded state; and log each correction.  Add regressions containing two consecutive captured malformed stills, deliberately split every relevant header across payload boundaries, plus conforming and out-of-scope controls.  Require both stills to clear source 21 in Icarus before another ARM helper build and physical Big Lebowski startup, title, Root Menu and repeated-menu test, while retaining Blazing Saddles and Coming to America acceptance.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_h262_restart_normalization.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 936 COMMIT Unreleased ac13724 2026-09-03T00:38:42-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Use the source-`ac13724` physical-disc diagnostics to identify The Big Lebowski's common startup and Root Menu H.262 rejection.

#### Outcome:

The user reports that the complete forum ZIP works perfectly on a fresh MiSTer, and after creating that installation's initially absent `/media/fat/screenshots` directory the intended capture succeeds.  The startup still terminal-filters 5,473 bytes and the Root Menu still terminal-filters 128,368 bytes, both with sequence offset zero and I-picture offset 170; their 256-byte prefixes are identical through byte 190 and first differ only in slice payload byte 191, after the decoder has already failed.  Both carry a 720-by-480, aspect-code-two, rate-code-four sequence with valid marker, sequence extension `148200010000` identifying profile/level `0x48`, non-progressive sequence and 4:2:0 chroma, followed by the same I frame and picture-coding extension `8ffff3c080`: all four `f_code` values are 15, picture structure is frame, frame prediction is set, concealment is clear, `progressive_frame` is one and `chroma_420_type` is zero.  Project reference H262-033 and H.262 6.3.10 require `chroma_420_type` to equal `progressive_frame` for 4:2:0; the frontend's source-21 check is the unique early check violated by these fields, and it evaluates on stream byte 186 immediately before the first slice at byte 187, matching the reset session's 188 accepted bytes, error flag `0x0001`, and zero completed or displayed pictures.  The helper remains alive beyond 386 seconds and Main submits more than 912 MB, excluding a transport or helper failure.  The 6,497,185-byte log, 1,451-byte screenshot and 376-byte checksum-valid schema-21 sidecar have SHA-256 `140890eff54f08712d07da8d9bf4d85034c8b3e5038195047c11ad181a958c0d`, `8cfc68f0bb767f52ce2ac7ca38d101ff349639b3b7e21bd1d5a80f979e58ce97` and `a720e6a6355b778971f8138b56e9940e55045d21babde553343919f9cb1d6c46`.

#### Next Steps:

After user approval, preserve the decoder, RBF, Main, random-access structure, byte count and every conforming stream while adding one helper-side compatibility normalization at the already-buffered initial I-picture boundary: only when a parsed sequence extension identifies 4:2:0 and the parsed frame-picture coding extension has `progressive_frame=1` with the nonconforming `chroma_420_type=0`, change that one field from zero to one and log the exact offset and before/after byte.  Add captured-header and conforming-control regressions proving only byte 185 changes from `0xc0` to `0xc1`, simulate the frontend to prove source 21 clears and the first slice is admitted, run the full strict, sanitizer, analyzer, DVD, LPCM and audio suites, build only a new static ARM helper, then retest both Big Lebowski stills plus the accepted Blazing Saddles and Coming to America menu routes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 935 COMMIT Unreleased ac13724 2026-09-03T00:16:48-07:00

#### Coming From:

Unreleased ac13724

#### Purpose:

Bundle the source-`ac13724` H.262 restart diagnostic helper with its matched runtime set and physical-drive launcher for forum testing.

#### Outcome:

`host/build/MiSTer_Media_Player_H262Diag_ac13724.zip` contains the exact source-`ac13724` static ARMv7 diagnostic helper, accepted source-`3689cca` Main, current source-`366a227` interlaced visualizer pack, timing-qualified source-`dfe1057` `MediaPlayer_20260901.rbf`, `games/MediaPlayer/USB DVD Drive.dvd`, diagnostic installation and source-provenance notes, the project licence and all seven bundled dependency licences.  It is explicitly identified as an unreleased diagnostic community test rather than a tagged or fixed release.  A fresh extraction contains sixteen files, all fifteen manifest entries pass SHA-256 verification, both executables retain mode 755, and the helper, Main, visualizer, RBF and launcher are byte-identical to their qualified inputs; ZIP integrity reports no errors.  The 6,578,930-byte archive has SHA-256 `ceb791f59ccc8db2d9702fb6631b9705a793d645fa8b2532560d5eeab26777ef`.

#### Next Steps:

Upload `host/build/MiSTer_Media_Player_H262Diag_ac13724.zip` to the forum and have the tester follow `INSTALL.txt`: enable telemetry, start The Big Lebowski, leave the failed startup visible briefly, press Root Menu once and leave that failed screen visible briefly, then return the helper log, telemetry screenshot and decoded sidecar.  Keep this package labeled diagnostic until those two bounded H.262 prefixes identify the compatibility correction and subsequent hardware testing qualifies a fixed build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 934 COMMIT Unreleased ac13724 2026-09-03T00:01:33-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Capture the exact common H.262 header construct rejected near byte 188 in The Big Lebowski's startup and Root Menu stills without changing playback behavior.

#### Outcome:

Source `ac13724` retains every filtered byte and existing publication decision while logging at most the first 256 post-filter bytes plus bounded parsed sequence-header, sequence-extension, picture-header and picture-coding-extension fields for each successful initial random-access group.  A focused production-translation-unit regression proves the collector extracts 720x480 sequence, I-picture and raw extension fields without changing one input byte; the existing terminal-still regressions additionally prove the emitted picture bytes remain exact.  Strict native compilation and DVD random-access, menu-hop, reserve, staging, overlay, SPU, Program Stream seek, audio seek/UI/visualizer and private-audio/LPCM-skip suites pass, as do Address/Undefined sanitizers, GCC analyzer, native static build and the MP3/WAV/FLAC/Ogg real-helper seek/visualizer suite against both native and ARM executables.  The local static stripped ARMv7 diagnostic helper `host/build/MediaPlayer_Helper_H262Diag_ac13724` is 966,052 bytes with SHA-256 `15dc2ddb7d55fedac950ac3ce7401d56340a2d032edda45c1578c3cd04f986a1`; its capabilities match the accepted helper.  No decoder, Main, RBF, visualizer, media byte or scheduling behavior changed.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_H262Diag_ac13724` as `/media/fat/linux/MediaPlayer_Helper`, enable telemetry, start The Big Lebowski and leave its failed startup visible briefly, then press Root Menu once and leave that failed screen visible briefly.  Return the updated results folder; its log should contain two `H262 restart diagnostic` prefixes and two `H262 restart fields` records, allowing the exact common byte-187/188 decoder rejection to be identified before any compatibility normalization is proposed.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 933 COMMIT Unreleased 932dc22 2026-09-02T23:59:04-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Determine whether Root Menu recovers The Big Lebowski's failed startup or independently reproduces its decoder rejection.

#### Outcome:

Root Menu performs a genuine second navigation attempt rather than merely redisplaying the first latched telemetry state.  At 113.253892 seconds Main sends command `0x09`; libdvdnav reports a successful root hop, the helper enters the menu, discards 4,180,090 reserved bytes, returns READY at 113.302508 seconds and releases the reset/GO barrier at 113.313835 seconds.  The destination then reaches its authored 15-second menu still and terminal-finalizes a new group with sequence offset 0, I-picture offset 170 and next reference offset 128,368.  The new checksum-valid schema-21 snapshot nevertheless records the same H.262 syntax flag `0x0001`, only 188 accepted bytes, and zero completed, displayed or reference pictures and swaps; the preceding independent startup snapshot failed at 187 bytes with the same sequence and I-picture offsets.  The helper remains alive, continues publishing menu highlights and has supplied 870,570,274 bytes by the 370.83-second capture endpoint, proving that the reset succeeds but both authored stills share an early H.262 construct rejected by the decoder.  Therefore entry 932's proposed non-menu-only gating could avoid the first failure but cannot make this root menu work and must not be shipped as the complete correction.  The 6,131,013-byte log, 1,451-byte barcode screenshot and 376-byte sidecar have SHA-256 `0334960b4723a0f4559d11ed89d3d660f916d109f574f8a3160896a7b17081e7`, `cd46075c074321026dd213f5514271b5502899e3325397b9f9e37bd0cc6f71a0` and `a720e6a6355b778971f8138b56e9940e55045d21babde553343919f9cb1d6c46`.  No runtime source was changed.

#### Next Steps:

Do not implement the entry-932 gating alone.  After user approval, make one diagnostic helper build that logs a bounded byte-exact prefix and parsed sequence, picture and extension fields for each initial random-access group before publication, without changing the bytes, decoder, Main, RBF, visualizer or timing.  Reproduce Big Lebowski startup and Root Menu once with that helper, identify the exact common construct at the 187/188-byte boundary against the frontend's 22 syntax-source checks, and then propose the narrowest helper-side compatibility normalization that preserves ordinary DVD streams and all accepted Blazing Saddles and Coming to America menu behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 932 COMMIT Unreleased 932dc22 2026-09-02T23:55:22-07:00

#### Coming From:

Unreleased 932dc22

#### Purpose:

Accept the helper-only visualizer blend and localize The Big Lebowski's fresh failure to its initial non-menu authored still.

#### Outcome:

The user accepts source `932dc22`'s visualizer presentation.  The matched Big Lebowski capture instead isolates an independent DVD startup failure: after CSS setup and title inventory, the disc remains outside a menu and reaches a three-second authored still; the generalized terminal finalizer releases its 5,482-byte one-picture H.262 payload at sequence offset 0 and I-picture offset 170, appends sequence end plus drain, and Main submits the resulting 5,490 bytes.  The checksum-valid schema-21 snapshot records H.262 syntax error flag `0x0001` after only 187 accepted video bytes, zero completed or displayed pictures and zero swaps.  The helper neither crashes nor stalls: it proceeds through the following seven-second still and continues generating title video and audio, while Main has submitted 183,236,608 bytes by the 92.55-second capture endpoint with no transport block or audio underrun.  Source `9c00a20` broadened terminal still finalization from pending menu activations to every initial-filter still to repair direct Root Menu one-picture backgrounds; that now exposes this decoder-rejected non-menu first-play picture instead of retaining it behind the startup filter until a later complete random-access group supersedes it.  The 1,519,541-byte log, 1,445-byte telemetry barcode screenshot and 337-byte decoded sidecar have SHA-256 `8be2813b811564546c1ce79e4bf444fede5ff4cafac48f00ebb7bcda1cbeabc5`, `da9debc380f82fdfe9a656d5b8786310764e9582cd11f75a27ab6bf83337c067` and `4192d812816d56e8f24e2e7750c021efff272c61b614082df942fc9445b1811a`.  No runtime source was changed.

#### Next Steps:

After user approval, keep terminal finalization for an active DVD menu or pending authored menu activation, but leave an initial non-menu finite still queued under the existing random-access filter so a later complete sequence/I/reference group can replace its decoder entry point.  Add production-path regressions proving that a non-menu first-play still does not release or clear the filter, a direct Root Menu one-picture still still receives the terminal tail, and pending finite and indefinite menu activations retain their current staged policies.  Run strict random-access, overlay, navigation, staging, LPCM, audio and sanitizer suites, build one static ARMv7 helper without changing Main, the decoder, RBF, visualizer asset or accepted visualizer cadence, then retest Big Lebowski startup plus Blazing Saddles and Coming to America menu entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 931 COMMIT Unreleased 932dc22 2026-09-02T23:23:00-07:00

#### Coming From:

Unreleased 366a227

#### Purpose:

Minimize the striped standalone-audio interface artifact with helper-only overlay transparency and a covered-visualizer brightness limit while preserving the accepted animation cadence.

#### Outcome:

Source `932dc22` makes standalone-audio overlay palette index zero fully transparent, the dark panel color alpha `0xa0`, and both border/text colors opaque, so missed or background-only rows expose the continuously decoded visualizer while retained UI detail reads as a translucent scanline-style HUD.  While that overlay is visible, the already-scheduled GOP selector limits the displayed grade to level 3 of 7; the existing ten-second CLEAR restores the full zero-through-seven loudness range, and activity or seek reapplies the cap without changing `due_gops`, GOP phase, source frame rate, slice size or service cadence.  Focused strict and ASAN/UBSAN tests prove exact palette alpha, covered attack `1,2,3,3...`, revealed recovery `4,5,6,7`, and renewed capping after activity and seek; GCC analyzer passes both changed translation units.  Native real-helper tests pass MP3, WAV, FLAC and Ogg with 378 through 381 decoded pictures and one CLEAR each, and the final ARMv7 helper passes the same four formats with 372 through 381 pictures and one CLEAR each.  GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_Scanline_932dc22` at SHA-256 `a87a6a81e21996735abc0d218d9d301ad8e349f96b0eeb8d891a172b86c70b09`.  The visualizer asset, decoder, Main and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_Scanline_932dc22` using executable mode, preserving the installed visualizer pack, Main and timing-qualified RBF.  Play standalone audio and require the first ten seconds to show a readable translucent scanline-style interface with the disruptive full-width dark bars removed or materially minimized; after the existing CLEAR, require the normal full-brightness visualizer.  Press Space during playback and pause, require the interface to return immediately over the animation with its quieter brightness ceiling, and confirm that the visualizer motion rate remains constant in both states and returns to full range after another ten seconds without input.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- host/arm/media_player_helper.c
- tools/test_audio_visualizer.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [x] Passed

---

## 930 COMMIT Unreleased 366a227 2026-09-02T23:10:33-07:00

#### Coming From:

Unreleased 366a227

#### Purpose:

Record the first native-interlaced visualizer result and localize the striped player interface visible during its ten-second cover interval.

#### Outcome:

The user confirms that source `366a227` now preserves the intended state transition: during the first ten seconds the player overlay is selected, and at the timer boundary it clears completely to the accepted visualizer with normal audio.  Hardware rejects the covered presentation because the 423,052-byte screenshot at SHA-256 `00e3908c7dbd9095a8cc7c5400d2d91d2cf68d5b54203b5b640b76481d83fdd5` shows the interface broken into horizontal stripes with the moving visualizer visible between them.  The matching 150,175-byte log at SHA-256 `faf3d160f2e2441ef95773365f4d83111afc30604b4c8334fa2c2f7247384bf4` proves that the helper loads the new pack, publishes one complete 86,400-byte opaque overlay by 0.329255 seconds, keeps it visible through the 5.850755-second capture and starts valid timed refreshes without an early clear or protocol error.  The checksum-valid schema-21 snapshot at SHA-256 `06d2baf746d976507f2de88d1475c2fa59986af06e4a4b371e9db26dc464846f` reports one successful plane and video-domain publication with zero bad commits, but only 14,302 returned overlay row tags and 7,732,126 matched active pixels; at this elapsed native-480i cadence a continuously available plane would have approximately 79,000 row opportunities and 57 million active pixels.  Static localization explains that shortfall: the DDR arbiter grants every simultaneous presentation read ahead of the overlay line-cache reader, so continuous decoded-video readout starves most one-row-ahead overlay fetches, the two parity request slots collapse obsolete rows, and every unmatched row deliberately falls through to base video.  The prior progressive pack merely hid this pre-existing full-motion overlay bandwidth boundary by leaving native overlay composition disabled.

#### Next Steps:

After user approval, preserve source `366a227`, the helper, asset, decoder behavior and ten-second timing while making one bounded RBF-only arbitration correction: allow a pending overlay line-cache read to win one descriptor grant ahead of a simultaneous presentation request, after which the overlay engine must receive its fixed 23-word row and cannot request another until that response completes.  Extend the arbiter regression to prove the single bounded overlay grant and exact response ownership under a continuously asserted display reader, add an integrated native-raster stress test requiring every visible row tag and opaque sample to match while full-motion presentation reads continue, run the retained decoder, DDR, overlay and audio simulations on the build PC, perform a clean timing-qualified Quartus build, then repeat the first-ten-second audio test and require a solid interface with no base-video stripes before the normal clear reveals the visualizer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 929 COMMIT Unreleased 366a227 2026-09-02T22:47:52-07:00

#### Coming From:

Unreleased 9c00a20

#### Purpose:

Keep the standalone-audio player interface visible for its intended first ten seconds by making the optional visualizer stream compatible with the existing native-480i overlay path.

#### Outcome:

Fresh hardware evidence accepts audio playback, the radial animation and its loudness response, while the Main trace proves that the helper commits the opaque player overlay near startup and does not clear it until approximately 10.15 seconds.  Source `366a227` makes every generated visualizer GOP declare an interlaced sequence and three top-field-first interlaced frame pictures so the unchanged native-480i compositor displays that initial plane, and the helper now rejects packs that omit those declarations or signal progressive sequence or picture content.  Strict focused, AddressSanitizer and UndefinedBehaviorSanitizer tests accept the interlaced fixture and reject both progressive flag classes; GCC analyzer passes.  The 3,740,562-byte generated pack contains 160 indexed GOPs, and a deliberately level-switched sample decodes as 60 top-field-first interlaced 720-by-480 pictures at 30000/1001 without FFmpeg errors.  Native and final ARMv7 real-helper runs pass MP3, WAV, FLAC and Ogg with 378 through 381 decoded selected pictures and exactly one ten-second overlay clear, while the final ARM helper rejects the former progressive pack and all four formats retain the full-frame interface fallback.  GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_Visualizer480i_366a227` at SHA-256 `ea2004223d160dd2377144b85e311c9e594e541fca2ab856e83ce3f99b1291e2`; `host/build/MediaPlayer_Visualizer_366a227.mmpvis` has SHA-256 `448407cdd7e6c79fbe13cbb435241116127f726aca5af9f99d75b32fc2519f47`.  Main, RTL, RBF, decoder, audio transport, timer and accepted animation are unchanged.

#### Next Steps:

Exit MediaPlayer, replace `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_Visualizer480i_366a227` using executable mode and replace `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` with `host/build/MediaPlayer_Visualizer_366a227.mmpvis`, while preserving the installed Main and timing-qualified RBF.  Play standalone audio and require the normal interface to remain visible for the first ten playback seconds before the visualizer appears; then pause or seek, require immediate interface restoration, resume and require another complete ten-second delay before the visualizer returns.  Confirm clean audio and the accepted animation and loudness response, then return fresh telemetry-enabled results for hardware acceptance.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- tools/generate-audio-visualizer.py
- tools/test_audio_visualizer.c

#### Status:

- [x] Built
- [ ] Passed

---

## 928 COMMIT Unreleased 9c00a20 2026-09-02T22:31:00-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Complete picture-bearing motion-menu transitions before their activation stage fills and publish terminal one-picture DVD menus after every navigation route.

#### Outcome:

Source `9c00a20` preserves the 4 MiB classification boundary but expands the bounded activation stage to 8 MiB, statically reserving at least one complete 2 MiB video-queue drain beyond that decision; a pending picture-qualified motion menu still in the menu domain now requests the existing staged READY/GO hop at the watermark and publishes its bytes atomically after the decoder reset instead of failing at capacity.  DVD still waiting now applies the existing byte-exact terminal random-access finalizer whenever an initial filter retains queued video, independent of deferred activation state, so direct Root Menu transitions such as the reproduced long-running Blazing Saddles route receive the H.262 sequence end and five transport-drain bytes while staged destinations retain their prior publication policy.  New production-path regressions verify the exact unstaged terminal tail, the accepted 3,797,120-byte finite-still classification below the watermark and an exact 4 MiB motion-menu commit; strict native DVD, staging, reserve, random-access, overlay, audio, visualizer, LPCM-skip and seek suites pass locally and on the build PC, including 20 focused and 50 staging/menu-hop local repetitions plus focused ASAN and UBSAN on both hosts.  GCC analyzer finds no change-related fault after demoting its pre-existing audio-overlay allocation warning.  ARM GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 helper `host/build/MediaPlayer_Helper_MenuTransitions_9c00a20` with SHA-256 `cbd5359271c10c2788b66b83d21fc21f82631e7b77c49e2697b715bfc805f143`; Main, RTL, the RBF and libdvdnav policy are unchanged.

#### Next Steps:

Exit MediaPlayer and install only `host/build/MediaPlayer_Helper_MenuTransitions_9c00a20` as `/media/fat/linux/MediaPlayer_Helper` with executable mode while preserving the installed Main, visualizer asset and timing-qualified RBF.  On The Big Lebowski, enter Scene Selection, change pages, play a scene, return to the menu, resume the saved title position, re-enter Scene Selection and change pages again; acceptance requires a logged `DVD picture-bearing motion menu requires staged stream hop` at or beyond 4 MiB, READY/GO completion and continued navigation without `No space left on device`.  On Blazing Saddles, play for several minutes and press Root Menu; acceptance requires a logged terminal random-access group and authored-still drain followed by a visible responsive menu.  Retain shorter Coming to America Scene Selection, ordinary chapter, forum-disc LPCM-menu and title-audio checks before marking this source hardware-passed.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 927 COMMIT Unreleased 6b63c91 2026-09-02T22:16:01-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Diagnose Blazing Saddles' reproducible black decoder state after returning from long-running title playback to its root menu.

#### Outcome:

The fresh telemetry-enabled trace disproves a helper crash: after approximately 619.78 seconds of healthy playback, Root Menu succeeds, enters the menu domain, discards the old reserve and completes READY/GO in about 29 milliseconds; Main then receives and publishes a complete 86,400-byte selector overlay, while the helper remains alive and continues polling through the 679.72-second capture endpoint.  The new root destination reaches an authored indefinite still, but produces no `random access`, scheduler-progress or terminal-finalizer diagnostic after the barrier even though its overlay changes repeatedly.  This uniquely matches a single-picture menu stream retained by the helper's initial random-access filter: `wait_dvd_still()` calls `iso_finalize_terminal_random_access()` only when `activation_pending` is true, whereas Root Menu is classified immediately as `MEDIA_SOURCE_DVD_STREAM_HOP`, clears that flag and resets the decoder before reaching the still.  Consequently the queued picture receives neither the valid H.262 sequence end nor its five transport-drain bytes, no menu video crosses to Main and the screen remains black with the independently valid selector state unable to make a visible composite.  The 15,514,884-byte log, 559-byte all-black screenshot and 2,818-byte no-matrix sidecar have SHA-256 `2e25ec68e38676f4d221b37ca24c9365a5aa2ed4b25bb1ae51c28c3063ac595e`, `1fa718e5c800529417461bd164f5afadd65ec82288dd97ce9c34c334f65a91b1` and `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004`.  No runtime source was changed.

#### Next Steps:

After user approval, make one helper-only commit containing both diagnosed boundaries.  Generalize terminal DVD-still finalization so any active initial random-access filter with queued video, including a direct Root Menu hop, receives the existing sequence-end and transport-drain tail before waiting; retain activation staging only as the destination publication policy.  Separately give picture-bearing deferred motion-menu staging bounded headroom beyond the existing 4 MiB decision watermark and promote such a destination through the existing staged READY/GO stream-hop path before `ENOSPC`.  Add exact production-path regressions for an unstaged Root Menu one-picture indefinite still, the existing staged terminal still, an over-watermark motion menu with byte-exact post-barrier commit, the accepted 3,797,120-byte finite-still route below the watermark and overlay-only continuation, then run strict native, sanitizer, analyzer, DVD navigation, staging, random-access, overlay, LPCM, audio and seek suites locally and on the build PC before producing one static ARM helper for the specified Big Lebowski and Blazing Saddles hardware routes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 926 COMMIT Unreleased 6b63c91 2026-09-02T22:10:56-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Qualify a fresh live Blazing Saddles run and decide whether its preceding unlogged black attempt warrants a bundled source correction.

#### Outcome:

The new telemetry-enabled run is healthy through the live capture endpoint: Blazing Saddles starts `dvdmenu:/dev/sr0`, automatically enters its authored root menu, publishes a complete overlay and responds to a later Root Menu request with `already-root` plus `MENU_CONTINUE`, preserving the resident frame.  Activation leaves the menu, completes the existing READY/GO navigation barrier and begins movie playback; Next Chapter then succeeds from current title 2 part 1 to resolved title 2 part 2 and releases its barrier normally.  At 67.288 seconds Main remains actively reading and transferring helper output, with approximately 56.2 MB submitted and no helper EOF, child exit, control error, staging failure or transport failure.  The checksum-valid schema-21 snapshot measures 200 pictures and 199 swaps over 29.940731 seconds, a completed presentation with no decoder error, zero audio underruns, zero transport blocks and no overlay protocol error.  The visible 1,920-by-1,080 movie screenshot, 2,224,070-byte log and 766-byte sidecar have SHA-256 `98815a3c19614ae4bab11aa350524bf51d519b0de2de5d5b6a069f4a01d2edad`, `615eb08ed3c7eace5cb8809384357af3e3d9d2a1399652adb65be4df3e7fed22` and `f1c4dab826a2e841ae0840776c39e42da3165d40a1cb3777b075de459e1261c6`.  Because a telemetry-active helper crash would ordinarily leave Main's child-wait and exit diagnostics, the earlier attempt's missing log cannot establish a helper crash; the same build and disc now complete the route, so no reproducible Blazing Saddles defect or defensible second code change exists.

#### Next Steps:

Do not bundle a speculative Blazing Saddles change.  Preserve this run as acceptance of its startup, root-menu continuation, title launch and active-program chapter hop, and make the next approved helper boundary only the already-diagnosed Big Lebowski picture-bearing motion-menu staging promotion from entry 924.  Retest Big Lebowski Scene Selection as the primary acceptance route while retaining this exact Blazing Saddles route, Coming to America's finite and indefinite Scene Selection paths, ordinary movie chapters and the forum disc's LPCM-menu behavior; if the black Blazing Saddles attempt recurs with a fresh log, diagnose that trace as a separate reproducible boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 925 COMMIT Unreleased 6b63c91 2026-09-02T21:56:19-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Record Blazing Saddles' successful first source-`6b63c91` run and determine whether the supplied second-run evidence can diagnose its root-menu hang.

#### Outcome:

The user reports that Blazing Saddles initially booted, entered its menu, played and accepted chapter skips, further qualifying the corrected helper installation and active-program chapter path, but that a subsequent core reload produced a black hang after Root Menu.  Only `mister-screenshot.png` is fresh at 21:53; it is an all-black 1,920-by-1,080 image with no telemetry matrix, 559 bytes and SHA-256 `d964cb7603836826beb6afaa57ff6343531871568ec91a4fcc0cd55365f6ee73`.  `MediaPlayer_ARM.log` and `telemetry.txt` retain their 21:24 timestamps and exact hashes from the preceding Big Lebowski Scene Selection run, so their staging-capacity failure and schema-21 snapshot cannot be attributed to Blazing Saddles.  The collection script saves the screenshot before retrieving `/tmp/MediaPlayer_ARM.log` and exits under `set -e` if that retrieval fails, leaving the prior local log and sidecar untouched; the observed file combination therefore indicates that no fresh helper log was available to the collection, consistent with telemetry not being active for this attempt.  The current evidence cannot distinguish a helper failure, a Main/helper synchronization wait or an authored first-play delay, and no runtime source was changed.

#### Next Steps:

Hold the approved combined-build boundary until a fresh trace identifies the second correction.  Enable telemetry before loading Blazing Saddles, launch the disc, reproduce Root Menu from the black state, capture while it remains hung and verify that `.ai/current_results/MediaPlayer_ARM.log` receives the new run's timestamp rather than retaining the Big Lebowski file; if collection again stops after the screenshot, first confirm that `/tmp/MediaPlayer_ARM.log` exists on MiSTer.  Once fresh evidence is present, classify the exact navigation boundary and combine its narrow helper-side correction with the already-proposed bounded Big Lebowski motion-menu staging promotion, then run both discs plus Coming to America and the forum disc through the full regression and ARM build boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 924 COMMIT Unreleased 6b63c91 2026-09-02T21:28:47-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Qualify the corrected source-`6b63c91` installation on The Big Lebowski and diagnose its Scene Selection failure.

#### Outcome:

The user confirms that the checksum-correct helper restores The Big Lebowski startup, root-menu operation and chapter skipping during movie playback, accepting the active-program chapter correction and disproving a source regression in the prior immediate crash.  The fresh trace then enters the root menu, preserves responsive highlights, selects button one and successfully begins a deferred Scene Selection activation at 102.416959 seconds.  Post-activation output contains a qualified H.262 sequence and reference group, but this authored motion-menu destination produces neither a menu-domain exit nor a DVD still before the 4,194,304-byte atomic activation stage fills; at 107.881250 seconds the helper deliberately exits with `staging scheduled video failed: No space left on device`, after which Main reports a normal exit-code-one helper error.  The message describes the in-memory bounded stage, not filesystem storage.  The screenshot correctly retains the last root-menu picture because no partial destination was published, while its checksum-valid schema-21 snapshot shows a completed overlay plane, no overlay protocol error and the last stable decoder state; the later single audio-underrun flag accompanies the terminated stream rather than identifying the cause.  The 3,054,475-byte log, 564,283-byte screenshot and 844-byte sidecar have SHA-256 `af8f741463cd36f3400e96e186cb4d6e46d7a4bf91b8327af526a7eb4db6003c`, `74a5447d25dbc3fea1bb6d21959be684129b420b9b907ed03878674f65b6a522` and `7fa1f1f937f6a629cd748d9a896815e128aff1b78d39b16770bfeaa72a4ea8f3`.  No runtime source was changed.

#### Next Steps:

After user approval, preserve the accepted chapter, menu, finite-still and overlay-only behavior while adding a bounded capacity-pressure decision for picture-bearing motion-menu activations: retain 4 MiB as the decision threshold, give the stage sufficient bounded headroom for one deepest scheduler drain, and when a pending menu destination remains in the menu domain with a qualified picture group at that threshold, promote it through the existing staged READY/GO stream-hop path instead of reaching `ENOSPC`.  Add production-path coverage for an over-threshold motion menu with byte-exact post-barrier commit, retain the accepted 3,797,120-byte finite-still case below the threshold and all overlay-only classifications, then run strict native, sanitizer, analyzer, DVD navigation, staging, random-access, overlay, LPCM, audio and seek regressions locally and on the build PC before producing a new static ARM helper for Big Lebowski Scene Selection plus the retained Coming to America, Blazing Saddles and forum-disc routes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 923 COMMIT Unreleased 6b63c91 2026-09-02T21:16:43-07:00

#### Coming From:

Unreleased 6b63c91

#### Purpose:

Diagnose The Big Lebowski's immediate startup failure after installing the source-`6b63c91` chapter-navigation helper.

#### Outcome:

The fresh physical-disc run starts `dvdmenu:/dev/sr0`, forks helper PID 784 and asserts download, but helper stdout reaches EOF at 13.002 seconds and Main reaps the helper with signal 11 at 13.076 seconds after zero reads and zero submitted media bytes.  No libdvdnav title, CSS or chapter diagnostic appears, proving that the new chapter-control path is never reached.  A read-only FTP retrieval of `/media/fat/linux/MediaPlayer_Helper` finds the expected 961,956-byte length but SHA-256 `7d1ab3b073e9b120cdc285110a94c5ed47c78779cf61a21d60d17f0d8773346e`, rather than the released artifact's `556b706c8c8b4fc60a4e11c21adb62ebb40daec4201d3f4c0052d8275b59fabb`.  Bytes 1 through 458,752 exactly match the good artifact, with prefix SHA-256 `abd7f0665e7bdc22dbf3fd395e849efffdffe725a876289ebf2afb68c7fc0007`; the first difference is byte 458,753 and 428,092 bytes differ through byte 961,454.  The installed image also retains the old absolute chapter-control diagnostic and lacks the new active-VM diagnostic.  This is deterministic evidence of an interrupted in-place upload that left a hybrid new-prefix/old-tail ELF, fully explaining the immediate segmentation fault without indicating a source regression.  The supplied 1,940-byte log, 559-byte all-black screenshot and 2,818-byte no-telemetry sidecar have SHA-256 `99c947fd325de9d1f77bd95a0f6fbbfc4e9c596ba150f749cb75227669410f9c`, `d203038ddaadf5db6adf11901b670ba6930afc8dce176332662184b49780d50a` and `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004`.  A fresh exact copy of the good build-PC artifact has been restored locally as `host/build/MediaPlayer_Helper_ChapterVM_6b63c91`.

#### Next Steps:

Exit the core and ensure no MediaPlayer helper process is running, then copy `host/build/MediaPlayer_Helper_ChapterVM_6b63c91` to `/media/fat/linux/MediaPlayer_Helper`, set mode 755 and read the installed file back before launching the core.  Require the read-back SHA-256 to equal `556b706c8c8b4fc60a4e11c21adb62ebb40daec4201d3f4c0052d8275b59fabb`; if it does not, repeat the transfer rather than testing a mixed executable.  Once verified, rerun The Big Lebowski startup and its failing menu-launched chapter route, then provide fresh telemetry-enabled results to qualify source `6b63c91`.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 922 COMMIT Unreleased 6b63c91 2026-09-02T20:55:28-07:00

#### Coming From:

Unreleased 3689cca

#### Purpose:

Make DVD chapter controls follow the currently playing authored program chain so menu-launched alternate titles cannot terminate playback.

#### Outcome:

Source `6b63c91` replaces `iso_change_chapter()`'s initial-longest-title equality guard and absolute `dvdnav_part_play()` replay with libdvdnav's relative previous- and next-program operations against the active DVD VM path.  The selected-main-title metadata remains unchanged, while accepted hops still stop and reset the direct-device prefetch, clear the old block and menu state, restart the producer and enter the existing helper/Main reserve-discard plus READY/GO decoder barrier.  Rejected requests leave the source block boundary intact and now report direction, current title and part, buffered-byte count and libdvdnav detail; successful requests report both current and resolved title/part, making a future physical trace conclusive.  The focused production-unit test proves Previous on inventoried title 1, Next on a menu-launched title 7, preservation of the selected-title metadata, rejected-search state retention, menu-domain rejection and invalid-direction rejection.  Strict optimized, UndefinedBehaviorSanitizer, AddressSanitizer with host-incompatible leak scanning disabled, and GCC analyzer checks pass, as do the native helper build, retained AC-3, audio seek, Program Stream seek, DVD random-access, SPU, reserve, staging, menu, overlay-output, LPCM-skip, audio UI and visualizer coverage, real MP3, WAV, FLAC and Ogg integrations with and without the visualizer, one hundred menu/chapter, random-access and staging repetitions, and twenty overlay-output and LPCM-skip repetitions.  Build PC `10.10.0.42` repeats strict sanitizer and analyzer coverage plus one hundred menu/chapter runs, builds the exact native helper, passes all four real standalone-audio seeks and LPCM skip, and the retained Icarus test reconstructs thirteen stream bytes and the exact overlay payload while observing the live sequence end.  Its available fixtures include no DVD-Video image suitable for the alternate-title route.  GNU 10.2.1 builds the stripped static ARMv7 hard-float helper `host/build/MediaPlayer_Helper_ChapterVM_6b63c91`; it is 961,956 bytes, has no dynamic section and has SHA-256 `556b706c8c8b4fc60a4e11c21adb62ebb40daec4201d3f4c0052d8275b59fabb`.  Main, protocol, decoder RTL, visualizer assets and RBF are unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_ChapterVM_6b63c91` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining source-`3689cca` Main, the current visualizer pack and timing-qualified RBF; no reboot is required after stopping and relaunching the core, although rebooting is acceptable.  On The Big Lebowski, repeat the menu route that previously launched video and failed at Next Chapter, then require repeated Next and Previous requests to produce successful current/resolved-title diagnostics, READY/GO barrier completion, clean-picture restart and continued input response without `chapter control failed` or `control-error`.  Retest the accepted Coming to America second-visit Scene Selection route, Blazing Saddles root-menu loading and the forum disc's silent LPCM menu followed by supported title audio, then provide a fresh telemetry-enabled log and screenshot for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_source.c
- tools/test_dvd_menu_hop.c

#### Status:

- [x] Built
- [ ] Passed

---

## 921 COMMIT Unreleased 3689cca 2026-09-02T20:51:04-07:00

#### Coming From:

Unreleased 3689cca

#### Purpose:

Qualify the synchronized Coming to America Scene Selection route and diagnose The Big Lebowski's slow startup, slow menu presentation and fatal chapter-forward request.

#### Outcome:

The user reports that the exact second-visit Coming to America Scene Selection route now works, providing hardware acceptance of source `3689cca` for the directional menu-decision deadlock fixed by entry 920.  The fresh physical-disc Big Lebowski run starts `dvdmenu:/dev/sr0`, identifies title 1 as the 23-chapter longest title and remains alive through normal video, root-menu entry, four directional selections, activation and the resulting stream hop.  Its apparent 21.54-second startup is divided between approximately 10.29 seconds spent by libdvdnav retrieving CSS keys and inventorying titles and approximately 10.26 seconds of authored three- and seven-second first-play stills before the first qualified video byte; the root-menu command itself reaches READY in 55.86 milliseconds and releases its barrier in 68.11 milliseconds, after which the disc declares an authored 15-second menu still.  At 96.566683 seconds, a Next Chapter command discards 112,125 stale bytes, but `iso_change_chapter()` rejects the request and the helper reports `chapter control failed`; Main then correctly records `control-error`, stops the helper and releases download.  Because libdvdnav prints no `dvdnav_part_play()` range or VM error, the evidence is consistent with the preceding guard rejecting a valid current DVD title that differs from the initially inventoried longest title after authored menu navigation.  The current chapter implementation requires `current_title == state->title` and then calls absolute `dvdnav_part_play(state->title, target)`, so it cannot navigate an alternate title or program chain launched by a DVD menu.  The all-black 1,920-by-1,080 screenshot contains no telemetry matrix and the sidecar contains the decoder's expected no-telemetry error.  The 2,630,142-byte log, 559-byte screenshot and 2,818-byte sidecar have SHA-256 `d114fa9c24227738fd69c8dba96b59247f40af032546e4ada2ae36654838f89d`, `12c8ca81f403f6edaecb60d88b1c580ddbb0353ce8b9d16f349164fb4f724f19` and `dc87b7c521cd9445bafb7ff475db4c6850d0db4402f67c945ce9163e169f0004`.

#### Next Steps:

After user approval, preserve the proven menu synchronization and replacement-stream barrier but change physical-DVD and ISO chapter requests to libdvdnav's relative previous/next-program navigation against the current program chain instead of requiring and replaying the initially selected longest title.  Log the current title and part before the request plus libdvdnav's diagnostic string on failure, reset and restart the direct-device buffer only after a successful hop, and add focused tests covering the original longest title, a menu-launched alternate title, boundary failure and both directions.  Rebuild the static ARM helper, run strict native, sanitizer, analyzer, DVD navigation, random-access, staging, overlay, audio and seek regressions, exercise the equivalent transition in the build-PC simulator where its fixture permits, and then retest Big Lebowski title and chapter navigation on hardware while retaining Coming to America, Blazing Saddles and forum-disc menu regressions.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 920 COMMIT Unreleased 3689cca 2026-09-02T20:31:21-07:00

#### Coming From:

Unreleased 7186fb4

#### Purpose:

Synchronize every directional DVD menu command with an explicit continuation or stream-hop decision so authored auto-actions cannot deadlock Main and the helper.

#### Outcome:

Source `621dff7` removes Main's highlight-only directional bypass and marks every DVD menu command as a pending navigation decision.  The menu source now classifies ordinary, invalid and library-rejected directional selections as `MEDIA_SOURCE_DVD_MENU_CONTINUE`, causing the helper's existing acknowledgment path to preserve the resident stream, while authored auto-actions retain the existing READY/GO reset, drain and replacement-stream barrier.  The navigation integration driver now sends only one menu action at a time and requires one explicit decision per action, and the modeled Main regression rejects any reintroduction of the directional bypass.  Source `3689cca` corrects only the generated new-file hunk length exposed by the first pinned-Main application attempt and is the final build source.  Strict native helper and modeled Main builds, GCC analyzer, AddressSanitizer and UndefinedBehaviorSanitizer checks, all retained DVD random-access, SPU, overlay, reserve, staging, LPCM-skip, AC-3, Program Stream seek, audio UI, timer and visualizer tests, real MP3, WAV, FLAC and Ogg seek integrations, one hundred menu-hop, Main lifecycle, random-access and staging repetitions, and twenty overlay-output repetitions pass locally.  On build PC `10.10.0.42`, one hundred exact-source menu-hop and Main lifecycle repetitions pass, the live sequence-end Icarus regression reconstructs thirteen stream bytes and the exact overlay payload, and GNU 10.2.1 builds both final ARMv7 binaries against pinned Main `0a8fb44`.  The static stripped 961,956-byte helper `host/build/MediaPlayer_Helper_MenuSync_3689cca` has SHA-256 `88a348aefe8e27dac2adafc613ef4126ae053aaa8375f1b8e1e049cb3a3ab898`; the dynamically linked stripped 1,182,692-byte Main `host/build/MiSTer_MenuSync_3689cca` has SHA-256 `1b3387170083be269831bf4c3a828f1cce6bcb3b93c519d8cde32cb9768bedf9`.  The available small ISO is not DVD-Video, while the scripted Big Lebowski driver issues Root during that disc's initial three-second first-play still and is rejected before entering a menu, so neither fixture substitutes for the required physical route test; decoder RTL, the visualizer asset and the timing-qualified RBF are unchanged.

#### Next Steps:

Install `host/build/MediaPlayer_Helper_MenuSync_3689cca` as `/media/fat/linux/MediaPlayer_Helper` with executable mode and `host/build/MiSTer_MenuSync_3689cca` as `/media/fat/MiSTer`, then reboot while retaining the current visualizer pack and timing-qualified RBF.  On Coming to America, repeat the exact reported route: enter Scene Selection, move among scenes, play one, return to the menu, use Play to resume the saved movie point, enter Scene Selection again, and advance from scene 4 to the next page.  Require ordinary arrows to update highlights without resetting, every authored page action to complete its READY/GO transition without an unexpected `0x81`, and subsequent input to remain responsive.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback and the forum disc's silent LPCM menu followed by supported AC-3 title playback, then provide a fresh log, screenshot and telemetry snapshot.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_source.c
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 919 COMMIT Unreleased 7186fb4 2026-09-02T20:16:16-07:00

#### Coming From:

Unreleased 7186fb4

#### Purpose:

Diagnose the second-visit Coming to America Scene Selection stall when a directional auto-action advances to the next page.

#### Outcome:

The user's source-`7186fb4` run proves the directional target and helper-side auto-action fix work: on the second Scene Selection visit, Right from button 4 selects authored button 15, recognizes `auto_action_mode`, explicitly activates it and stages a complete 311,502-byte one-picture indefinite menu replacement.  The apparent decoder stall is a deterministic Main/helper control-protocol deadlock immediately afterward.  Because Main marks only Enter and Root Menu as pending navigation commands, it handles a directional command as highlight-only; the helper returns READY (`0x81`) for the auto-action stream hop, Main logs it as an unexpected event instead of resetting the download and sending GO, and the helper thereafter logs Down and Left controls as ignored while waiting for GO.  The screenshot retains a correctly decoded Scene Selection page, and its checksum-valid schema-21 telemetry reports 224,829 accepted bytes, one completed reference and displayed picture, a recognized sequence end, completed presentation and no decoder, presentation, PCM or overlay protocol errors.  The helper remains alive and polling, which distinguishes this from the prior helper exit.  The 3,389,750-byte log, 729,406-byte screenshot and 597-byte telemetry report have SHA-256 `a3c73e8e20e60a1d77f4c352a8dd2f0a46a34997400b369f16f78ae8bc204630`, `cb4301d6bb2c687c5fadfcd4c1f45908fd2c91014f2091665f6c222a55c6e165` and `055501f2a8bac9a1565e2d4e6df6e71368101da27067629c49a8432dfc471eb6`.

#### Next Steps:

After user approval, make every accepted DVD menu direction a pending navigation transaction in Main and have the helper explicitly return MENU_CONTINUE for ordinary no-hop directional moves, while retaining READY for directional auto-action hops.  Main should preserve the resident stream on MENU_CONTINUE and execute the existing reset, drain and GO barrier on READY.  Add focused protocol coverage for both replies, rebuild Main and the static ARM helper, run strict native, sanitizer, analyzer, menu-hop, staging, random-access, overlay, audio and seek regressions, then exercise the exact resume-to-menu-to-next-page route on hardware and retain the existing disc regressions.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 918 COMMIT Unreleased 7186fb4 2026-09-02T20:06:39-07:00

#### Coming From:

Unreleased 101aa4a

#### Purpose:

Handle authored directional DVD auto-actions as real navigation transitions without allowing a rejected arrow input to terminate playback.

#### Outcome:

Source `7186fb4` replaces libdvdnav's opaque directional convenience calls with the equivalent public target-selection operation against the helper's already-derived authored link.  A valid target carrying `auto_action_mode` is then explicitly activated and routed through the same existing menu-pending or stream-hop classification used by Enter, ensuring the old NAV packet is invalidated and the destination is consumed before another command; normal targets remain highlight-only, invalid links are ignored, and a library-rejected arrow now logs `ignored-error` and returns a no-hop result instead of killing the helper.  Enter activation reuses the factored classification without changing its behavior.  The focused regression covers valid and invalid target bounds plus auto-action classification, and passes under optimization, AddressSanitizer and UndefinedBehaviorSanitizer; the changed source passes GCC analyzer and a strict native helper build.  Twenty terminal-overlay, one hundred random-access, one hundred staging, one hundred local menu-hop, twenty unsupported-LPCM and real MP3, WAV, FLAC and Ogg seek integrations pass alongside the focused AC-3, audio-seek, audio-UI, visualizer, DVD SPU, reserve and Program Stream seek checks.  An isolated exact-source build-PC checkout completes another one hundred menu-hop repetitions and the retained live sequence-end/overlay Icarus regression.  The 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_MenuAuto_7186fb4` has SHA-256 `8a7d511846c160c0d4b4c0727fb420e76d147abcad8049384fc79b0d5e619411`; the proven terminal still drain, Main, protocol, decoder, RTL, visualizer and RBF are unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_MenuAuto_7186fb4` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  Reproduce the Coming to America Scene Selection route, navigate repeatedly across its scene pages, specifically exercise the prior Left auto-action from the first scene button followed by another direction, and require every authored background and highlight to update without helper exit; activate a scene, return to the root menu and repeat.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback and the forum disc's silent LPCM menu followed by supported AC-3 title playback, then provide a fresh log, screenshot and telemetry snapshot for qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_source.c
- tools/test_dvd_menu_hop.c

#### Status:

- [x] Built
- [ ] Passed

---

## 917 COMMIT Unreleased 101aa4a 2026-09-02T19:58:11-07:00

#### Coming From:

Unreleased 101aa4a

#### Purpose:

Qualify the terminal DVD still drain on Coming to America and isolate the later navigation hang after repeated Scene Selection input.

#### Outcome:

The user's physical source-`101aa4a` run validates the drain-tail boundary: multiple Scene Selection page activations update their authored backgrounds and overlays correctly, and the final 1,920-by-1,080 screenshot visibly shows the authored 9-through-12 scene page with a valid highlight.  Its checksum-valid schema-21 snapshot reports 224,821 decoder-accepted bytes from the final 224,817-byte authored still plus nine-byte terminal tail, proving the complete sequence end crossed the five-byte retained transport depth; `sequence_end_seen` and presentation completion are true, exactly one reference picture and one displayed picture completed, and decoder, presentation, PCM and overlay protocol errors are all clear.  The later apparent decoder hang is instead a deterministic helper exit: a Left command on NAV LBN 33,886 reports authored target 12 but returns highlight 2, which matches libdvdnav's directional auto-action path executing a button command and leaving that NAV packet; because the helper classified every successful arrow as highlight-only, it did not enter its existing pending-menu transition path.  The next Down command reused the departed NAV, libdvdnav returned an error, the helper exited with status one at 47.685666 seconds, and Main ended the download with reason `helper-error` while retaining the last good frame.  Before that exit the session delivered four complete overlay planes, fifty-three styles with thirty-three visual changes, and multiple successful staged still hops.  The 1,217,814-byte log, 752,950-byte screenshot and 597-byte telemetry report have SHA-256 `3bbb7824fefc4de517f97b6254890ff330fff3059757f86cd8bb87bd5558a961`, `ef5004a72a027b5263b087775f0beebcaf98bd518eb861a412c43ca48031e85f` and `cefcfd8a9389a429f290567c9f5e4b1205a9979047ba04f7f5fb6345c8dbd031`.

#### Next Steps:

Preserve the proven terminal still drain, staged decoder barrier, overlay continuation, Main, protocol, decoder, RTL, visualizer and RBF.  After user approval, replace libdvdnav's four directional convenience calls with explicit selection of the already-derived authored target, inspect that target's `auto_action_mode`, activate it when required, and classify the resulting action through the same existing menu-pending or stream-hop path used by Enter so a new NAV packet is consumed before later input.  Treat an independently rejected directional input as an ignored no-op rather than terminating the helper, while retaining fatal handling for activation and root-menu failures.  Extend the menu-hop regression with valid, invalid and auto-action authored targets, rerun strict native and GNU 10.2.1 ARM builds plus sanitizer, analyzer, navigation, staging, random-access, overlay, audio and seek coverage, and build only a new static ARMv7 helper for repeated Scene Selection paging and retained Blazing Saddles, The Big Lebowski and forum-disc tests.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 916 COMMIT Unreleased 101aa4a 2026-09-02T19:47:06-07:00

#### Coming From:

Unreleased a0cdd43

#### Purpose:

Correct and execute the live sequence-end metadata regression on the authorized simulation PC before hardware testing the terminal DVD still drain.

#### Outcome:

The first exact-source Icarus Verilog 12.0 run on build PC `10.10.0.42` rejected the new regression because its blocking assignment updated the observed stream window before the detector expression shifted the current byte a second time; this was test instrumentation, not helper or extractor behavior.  Source `101aa4a` changes only that detector to compare the already-updated 32-bit window.  A clean isolated checkout of exact source `101aa4a` then compiles and passes `test_dvd_overlay_metadata.sv`, reconstructing thirteen clean stream bytes, preserving the three-byte `02 de ad` overlay payload under backpressure, and observing the complete `00 00 01 b7` sequence end while `input_end` remains low.  The GNU 10.2.1 ARM rebuild succeeds and produces the byte-identical 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_SceneDrain_101aa4a` at SHA-256 `9cde18ced068f6b39865a24f79ade13a3c07810324c185d1df6cf3d54a422d33`; source `a0cdd43` remains the helper implementation boundary, and Main, protocol, decoder, RTL, visualizer and RBF remain unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_SceneDrain_101aa4a` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  On Coming to America, enter Scene Selection and require its authored background plus selector to appear, remain responsive and launch a selected scene; return to the root menu and repeat the transition.  With telemetry enabled, require at least 224,828 decoder-accepted bytes for this still, sequence-end recognition, one completed reference picture and one displayed picture.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback and the forum disc's silent LPCM menu followed by supported AC-3 title playback, then provide a fresh log, screenshot and telemetry snapshot for qualification.

#### Files Modified:

- tools/test_dvd_overlay_metadata.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 915 COMMIT Unreleased a0cdd43 2026-09-02T19:41:21-07:00

#### Coming From:

Unreleased d75327e

#### Purpose:

Drain the complete terminal DVD still sequence-end marker through the live transport lookahead so the decoder can publish the authored menu background.

#### Outcome:

Source `a0cdd43` replaces the terminal still's isolated four-byte sequence-end write with one exact nine-byte tail containing the unchanged standard `00 00 01 b7` marker followed by five zero-valued implementation drain bytes.  The drain applies only after terminal random-access filtering qualifies and stages an authored sequence-plus-I still; ordinary random access, overlay-only continuation, decoder interpretation, Main, protocol, visualizer, RTL and RBF remain unchanged.  The production-path regression requires byte-identical authored video, the exact nine-byte tail, two staged records, one emitted picture mark and picture-bearing hop classification, while the metadata regression requires the complete sequence end to emerge before `input_end` during a live session.  Strict native and GNU 10.2.1 ARM builds pass, as do AddressSanitizer and UndefinedBehaviorSanitizer coverage, the helper analyzer apart from its suppressed pre-existing audio-overlay allocation false positive, focused AC-3, audio-seek, audio-UI, visualizer, DVD random-access, SPU, reserve, stage, menu-hop and Program Stream seek tests, twenty terminal-overlay repetitions, one hundred random-access, staging and menu-hop repetitions, twenty unsupported-LPCM integrations, and real MP3, WAV, FLAC and Ogg seek integrations.  The Raspberry Pi has no installed RTL simulator, so the new metadata regression is source-reviewed but was not executed locally.  The 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_SceneDrain_a0cdd43` has SHA-256 `9cde18ced068f6b39865a24f79ade13a3c07810324c185d1df6cf3d54a422d33`.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_SceneDrain_a0cdd43` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  On Coming to America, enter Scene Selection and require its authored background plus selector to appear, remain responsive and launch a selected scene; return to the root menu and repeat the transition.  With telemetry enabled, a captured failure or success should now show at least 224,828 decoder-accepted bytes for this still, sequence-end recognition, one completed reference picture and one displayed picture.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback and the forum disc's silent LPCM menu followed by supported AC-3 title playback; a simulation-capable run should execute the added metadata regression before any future RBF boundary.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_metadata.sv
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 914 COMMIT Unreleased d75327e 2026-09-02T19:23:06-07:00

#### Coming From:

Unreleased d75327e

#### Purpose:

Qualify source `d75327e` on Coming to America's Scene Selection submenu and isolate why its authored background remains black.

#### Outcome:

The user's physical source-`d75327e` run reproduces the black authored background with the correct green Scene Selection selector visible and responsive.  Terminal random-access filtering again qualifies a sequence at offset zero and one I picture at offset 106 in 224,824 authored bytes, then stages 139 records totaling 311,501 bytes after appending the four-byte H.262 sequence-end marker; the prior build staged 138 records and 311,497 bytes, proving the exact terminator reached the helper's bounded activation transaction.  The checksum-valid schema-21 snapshot nevertheless reports only 224,823 decoder-accepted bytes, exactly five fewer than the 224,828 authored-plus-terminator bytes sent, while sequence-end recognition, completed reference pictures, displayed pictures and swaps all remain zero and 209,739 stall cycles remain inside the unfinished I picture with no decoder error flags.  The replacement overlay independently completes one clear, configuration and commit with twenty-two data records and 86,400 plane bytes, no protocol error and the expected visible rectangle.  The hardware count and RTL source agree that the terminator is retained behind the in-band extractor and downstream delivery lookahead because `input_end` cannot assert while the live indefinite DVD-menu session remains open; the 1,834,541-byte log, 5,456-byte screenshot and 571-byte telemetry report have SHA-256 `dd40b250b253492d83c6254254dc70001e82fdc47d25303ce63c17ceeb1141b2`, `4c69b6424bee7b913cb7cf0e7c16db2607fbad595f63eaab006adc0649701c04` and `f34038759b19fa823ad3e2f458dad2c86f62a0c62ba0d334e75c41d3c799e671`.

#### Next Steps:

After user approval, preserve the qualified authored bytes and append five zero-valued transport drain bytes after the sequence-end marker only for a terminal DVD still activation, allowing the complete four-byte marker to cross the observed five-byte lookahead while leaving the session alive for overlay and navigation commands.  Extend the production-path regression to require the exact nine-byte terminal tail and add focused metadata-path coverage proving sequence-end delivery before `input_end`, then rerun strict native, GNU 10.2.1 ARM, sanitizer, analyzer, staging, random-access, overlay, menu-hop, audio and seek suites and build only a new static ARMv7 helper.  Retest Coming to America Scene Selection for its authored background, responsive selector and scene launch, followed by Blazing Saddles, The Big Lebowski and the forum disc; Main, protocol, decoder interpretation, RTL, visualizer and RBF remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 913 COMMIT Unreleased d75327e 2026-09-02T19:06:18-07:00

#### Coming From:

Unreleased efe2a76

#### Purpose:

Terminate a qualified single-picture DVD menu stream so the existing decoder completes and publishes its authored still background.

#### Outcome:

Source `d75327e` appends the standard four-byte H.262 `sequence_end_code` after terminal random-access filtering qualifies and drains an authored sequence-plus-I group into the pending DVD activation stage.  The terminator remains inside the same bounded transaction before its established READY/GO barrier, provides the non-slice delimiter required to close the final `picture_data()` region, and asserts the decoder's existing one-picture end-of-sequence publication path without fabricating a picture or changing authored picture bytes.  The production-path regression proves the exact input sequence and I picture remain byte-identical, exactly one `00 00 01 b7` record follows them, the emitted picture count remains one and the stage retains picture-bearing hop classification.  Strict native, GNU 10.2.1 ARM, full helper sanitizer and analyzer builds pass, as do focused and retained random-access, overlay, staging, reserve, menu-hop, DVD SPU, AC-3, LPCM-skip, Program Stream seek, audio UI, timer and visualizer checks; high-risk repetitions complete at 100 random-access, 20 terminal overlay, 100 staging, 100 menu-hop and 20 LPCM-skip runs, and real MP3, WAV, FLAC and Ogg seek integrations pass.  The 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_SceneEnd_d75327e` has SHA-256 `fc5545cf2f652c5d92bc0cfd9fa77205fdc25fe9c5d823c47d30689f32c19ce5`; ordinary random access, overlay-only continuation, Main, protocol, decoder logic, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_SceneEnd_d75327e` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  On Coming to America, enter Scene Selection and require its authored background plus selector to appear, remain responsive and launch a selected scene; return to the root menu and repeat entry to cover the full transition.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback, and the forum disc's silent LPCM menu followed by supported AC-3 title playback; if Scene Selection remains black, collect a fresh helper/Main log, screenshot and schema-21 telemetry to verify sequence-end recognition, one completed reference picture and one displayed picture.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 912 COMMIT Unreleased efe2a76 2026-09-02T19:04:18-07:00

#### Coming From:

Unreleased efe2a76

#### Purpose:

Qualify terminal single-picture DVD menu delivery on Coming to America and isolate the remaining black background.

#### Outcome:

The user's physical source-`efe2a76` run improves the Scene Selection transition from a stale root-menu background to the correct replacement selector over black, but does not yet display the authored background.  Activation succeeds at 20.065338 seconds, terminal filtering finds a sequence at offset zero and one I picture at offset 106 in 224,824 queued video bytes, the helper records one emitted picture, and the existing barrier commits 138 staged records totaling 311,497 bytes.  The checksum-valid schema-21 snapshot confirms 224,819 accepted decoder bytes and final picture type I, but reports zero completed reference pictures, zero displayed pictures, zero swaps and no sequence end; all 209,923 decoder stall cycles belong to the unfinished I picture while error flags remain clear.  In contrast, the replacement overlay completes exactly one clear, configuration and commit with twenty-two data records and 86,400 plane bytes, no protocol error, and the visible rectangle shown in the 1,920-by-1,080 screenshot.  Source inspection matches the hardware evidence: the picture parser completes `picture_data()` only after observing a following non-slice start code, and native one-picture startup already uses `sequence_end_seen` to publish an end-of-stream frame.  The 1,038,477-byte log, 5,516-byte screenshot and 571-byte telemetry report have SHA-256 `e427eb237cb56a26fae0625aed228f7e2d7a44ed83d66a42aaa5d67521358b27`, `1abfda3f3895ff4e1c0919735b66f83b82ad37051b4c80cd349e9ba122b14b57` and `4286d8d8a1eb0c75774891f03ad1c24178099464dd100c178de9752db68a1530`.

#### Next Steps:

Preserve terminal sequence-plus-I qualification, ordinary open-ended random access, overlay-only continuation, Main, protocol, decoder, RTL and RBF.  After user approval, append the valid four-byte H.262 `sequence_end_code` only after a terminal authored-still group qualifies and drains into the activation stage, so the existing parser closes the final slice region and native startup releases the completed one-picture frame; do not synthesize a second picture or alter decoder interpretation.  Extend the production-path still regression to require the exact terminator after unchanged authored bytes, retain ordinary I/P, terminal I-only, trailing-B and overlay-only coverage, rerun strict native, sanitizer, analyzer, staging, reserve, menu-hop, audio and seek suites with repeated high-risk cases, and build only a new static ARMv7 helper for another Coming to America Scene Selection test plus retained Blazing Saddles, The Big Lebowski and forum-disc regressions.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 911 COMMIT Unreleased efe2a76 2026-09-02T18:46:53-07:00

#### Coming From:

Unreleased 338c4d5

#### Purpose:

Release an independently decodable single-picture DVD menu background when its authored still boundary completes the startup group.

#### Outcome:

Source `efe2a76` adds an explicit terminal mode to DVD random-access filtering so an authored still bounds a complete sequence-plus-I group without inventing the later I/P reference required during open-ended streaming.  Terminal filtering retains the sequence and I picture, neutralizes contextless pictures before it and unsafe trailing B pictures, and leaves a sequence without an I picture pending; the helper invokes it only for a pending DVD menu activation at an actual still event, drains a qualified picture into the existing activation stage, and reuses the established picture-bearing READY/GO barrier.  Ordinary open-ended filtering still refuses the same I-only group, and source `338c4d5` overlay-only continuation remains selected when no video is queued or no sequence/I group qualifies.  Strict native and GNU 10.2.1 ARM builds pass along with the random-access analyzer and sanitizer checks, production-path terminal-still staging, output-stage and reserve sanitizers, AC-3 recovery, DVD SPU, menu-hop, Program Stream seek, audio UI/timer/visualizer units, all four real standalone-audio seek integrations, 100 random-access repetitions, 20 overlay/still repetitions, 100 stage repetitions, 100 menu-hop repetitions and 20 unsupported-LPCM repetitions.  The resulting 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_SceneStill_efe2a76` has SHA-256 `c0dd48b3926a58b9425e708acd7fb02f964e4936f2acb71f1aa05dc8e1706731`; Main, decoder, visualizer, protocol, RTL and RBF are unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_SceneStill_efe2a76` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  On Coming to America, enter Scene Selection and require its authored background to replace the root-menu frame while its selector remains responsive; activate a scene, return to the root menu and repeat entry to exercise both picture-bearing and overlay-only transitions.  Retest Blazing Saddles root-menu loading, The Big Lebowski menu/title playback, and the forum disc's silent LPCM menu followed by supported AC-3 title playback; for any failure collect a fresh helper/Main log, screenshot and schema-21 telemetry without reusing prior captures.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/dvd_random_access.c
- host/arm/dvd_random_access.h
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_dvd_random_access.c

#### Status:

- [x] Built
- [ ] Passed

---

## 910 COMMIT Unreleased 338c4d5 2026-09-02T18:42:42-07:00

#### Coming From:

Unreleased 338c4d5

#### Purpose:

Qualify source `338c4d5` on Coming to America's authored Scene Selection submenu and isolate its retained stale background.

#### Outcome:

The user's physical run partially validates source `338c4d5`: Coming to America's root menu remains responsive, three Right commands select button four, activation succeeds at 20.903318 seconds, and the helper enters Scene Selection without the prior black reset or freeze.  The destination again reaches an indefinite still after 249 generic Program Stream start codes with zero emitted pictures and exactly 26 staged overlay records totaling 86,664 bytes; the new path commits those records, reports `overlay-indefinite-still`, and Main preserves the resident frame at 21.449442 seconds without READY/GO, a reserve discard, a fatal error, an audio underrun or an overlay protocol error.  The 726,845-byte screenshot visibly retains the root-menu background behind the newly selected submenu state, matching the user's report that Scene Selection backgrounds do not update.  Source inspection identifies the remaining boundary: every DVD navigation reset enables the initial random-access filter, that filter deliberately waits for an I picture plus a later I/P reference, and an authored single-picture still can reach its terminal still event with the complete sequence and I frame still queued rather than emitted or staged.  The 1,274,033-byte log, screenshot and 844-byte checksum-valid schema-21 telemetry report have SHA-256 `9b690188ccaad68ae7680fcc65843b03b6c6b7aca192884f2e6413f8c16061b0`, `238fb6333307a29408d98f76f32cdd3583de061e010305d8d29ae5bdc42359fb` and `aa1db16a7eb1c8fc76a9cbd67d3b4ba123a8ea0649087c27188af33e5353c8ed`.

#### Next Steps:

Preserve source `338c4d5` overlay-only continuation, genuine multi-picture activation hops, Main, RBF, decoder and protocol.  After user approval, extend DVD random-access filtering with an explicit authored-end finalization that accepts a complete sequence-plus-I still picture without requiring a later reference, neutralizes unsafe pre-context and trailing B pictures, and remains unavailable during ordinary streaming; invoke that finalization only when a DVD activation reaches its authored still boundary, drain the qualified queued video into the existing stage, and let its real picture mark select the established decoder barrier.  Add focused incomplete-stream, finalized-I-only, trailing-B, overlay-only and ordinary I/P regressions, rerun the complete helper and sanitizer suites, and build only a new ARM helper for Coming to America plus retained Blazing Saddles, The Big Lebowski and forum-disc testing.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 909 COMMIT Unreleased 338c4d5 2026-09-02T17:54:21-07:00

#### Coming From:

Unreleased 8c90e2d

#### Purpose:

Preserve the resident DVD picture when an authored indefinite submenu activation produces only a replacement overlay.

#### Outcome:

Source `338c4d5` replaces the ambiguous raw Program Stream start-code count with destination evidence from the bounded output stage and the helper's emitted H.262 picture scanner.  A nonempty indefinite activation containing no emitted picture now commits its staged overlay through the live session and acknowledges `MENU_CONTINUE` without stale-reserve discard, READY/GO or decoder reset; finite, empty and genuine picture-bearing destinations retain their prior commit, cancel and staged-hop behavior.  The focused regression reconstructs the Coming to America transaction as exactly 26 priority records and 86,664 bytes and proves byte-exact continuation, while 100 staging repetitions, 100 menu-hop repetitions, 20 overlay reconstructions, 20 unsupported-LPCM runs, strict native builds, GCC analyzer, AddressSanitizer and UndefinedBehaviorSanitizer checks, DVD random-access and SPU tests, AC-3 recovery, Program Stream seek, audio UI, timer, visualizer and all four real standalone-audio integrations pass.  GNU 10.2.1 produced the 961,956-byte static stripped ARMv7 hard-float helper `host/build/MediaPlayer_Helper_SceneContinue_338c4d5` at SHA-256 `6af407d0d0b8abfba1d9302ca6eb8f51ab7319bd729ff9fa98f300e7dc817a25`; the source-`8c90e2d` redundant-root and unsupported-LPCM behavior, Main, RBF, decoder, visualizer and protocol remain unchanged.

#### Next Steps:

Install only `host/build/MediaPlayer_Helper_SceneContinue_338c4d5` as `/media/fat/linux/MediaPlayer_Helper` with executable mode, retaining the current Main, visualizer pack and timing-qualified RBF.  On Coming to America, enter Scene Selections and require the existing background plus replacement selector to remain visible and responsive without a navigation reset; then activate a scene to prove a genuine video-bearing destination still uses the decoder barrier.  Retest Blazing Saddles at its already-active root menu, The Big Lebowski menu and title playback, and the forum disc's silent LPCM menu followed by supported AC-3 title playback before accepting the helper on hardware.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/output_stage.c
- host/arm/output_stage.h
- tools/test_output_stage.c

#### Status:

- [x] Built
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
