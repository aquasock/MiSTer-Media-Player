## 956 COMMIT Unreleased f93c6ba 2026-09-03T20:32:38-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Keep automatic-menu PCM below its safety ceiling without recreating the long downstream audio lead.

#### Outcome:

Source `f93c6ba` retains source `67ce19d`'s reserve-drain pacing boundary and replaces its fixed one-batch fallback ceiling with pressure-driven 2,048-frame runs.  Each stalled-timestamp automatic-menu pass drains held PCM to a low watermark equal to half the configured hold limit when that is above the existing 8,192-frame scheduling reserve, which is 96,000 frames at the default four-second limit; the normal advancing-timestamp scheduler, ordinary title reserve, overlay priority and transport byte order remain unchanged.  This gives the default route two seconds of hold-limit headroom, bounds the initial sink-paced catch-up from the observed 183,808 frames to approximately 1.83 seconds, and makes subsequent work proportional to each newly decoded Program Stream audio burst instead of permitting a net-growing hold.  The production fixture proves that one fallback pass drains 48,000 held frames to its 24,000-frame test watermark through the real reserve, then absorbs a further 12,000-frame burst while preserving the watermark and every emitted sample; the retained long-menu and advancing-PTS controls pass.  Strict optimized, AddressSanitizer with leak detection disabled for the ptrace environment, UndefinedBehaviorSanitizer and GCC analyzer checks pass apart from the known audio-overlay allocation false positive, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests.  Twenty repeated production runs, one hundred menu-hop runs, fifty output-reserve runs and twenty LPCM-skip integrations pass, and real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `70cfc0c59957bfaf8ca1b536f3746537c76e4108551a4b28c359a3ebcefa8785`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`f93c6ba` artifact and retain the current per-core Main, RBF and visualizer.  Let Futurama run through all intros into its root menu, require one fallback diagnostic containing `watermark=96000 reserve=8192 paced_batch=2048`, and confirm the menu appears and animates with continuous intelligible audio, a responsive selector, no hold-limit diagnostic and no helper termination.  Exercise its nested episode menu and selected-title playback, then repeat automatic-menu entry on several other discs and return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 955 COMMIT Unreleased 67ce19d 2026-09-03T20:28:11-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Qualify source `67ce19d` on Futurama's automatic root-menu transition and isolate its failure before menu playback.

#### Outcome:

The physical source-`67ce19d` run rejects the one-batch fallback admission policy while validating its sink-pacing boundary.  All three finite intro boundaries complete, the silent-video lookahead classifies and releases, the automatic menu inherits the continuous scheduling epoch at 41.085422 seconds, the first translated audio and video horizon remains fixed at PTS 647,273, and a valid 86,400-byte overlay plane commits without ordering error.  Fallback activates at 41.376416 seconds with 183,808 held PCM frames and no timestamp-derived audio due; draining the output reserve before each scheduled run succeeds, but admitting only one 2,048-frame batch per Program Stream scheduler pass is slightly slower than the disc's decoded AC-3 bursts.  Held PCM consequently rises to 193,024 frames, crosses the unchanged 192,000-frame safety ceiling about 4.37 seconds later, and deliberately terminates the helper with exit status one at 45.764969 seconds before the menu can play.  Main reports `helper-error`; there is no reserve-pacing failure, audio underrun, PCM protocol error, decoder error or overlay ordering error.  The checksum-valid schema-21 snapshot is an earlier settled-overlay capture with 127 displayed pictures, 126 swaps, zero decoder and PCM errors, zero underruns and one valid visible menu overlay; the later screenshot shows the black post-exit diagnostic display.  The 1,083,151-byte log, 11,711-byte screenshot and 844-byte telemetry sidecar have SHA-256 `c74ffb51e544a2ab233fc66164d2ec00694e6c14fba86c4b3c4757e3a842add0`, `915763d7b660d4b82ef007c02f78f655c43c59c3dff4eccea59c6769a9c1b4f8` and `335b0923d031579f9cfb03c19d8320563c5089243b762857569ca1a72ad05f46`.

#### Next Steps:

Retain the source-`67ce19d` reserve-drain pacing boundary but replace its fixed one-batch ceiling after user approval with a pressure-driven bounded burst that emits sink-paced 2,048-frame runs until held PCM reaches a safe low watermark below the four-second ceiling.  Bound each admission interval so menu input remains responsive, add production regressions in which a single Program Stream packet decodes more PCM than one batch and verify that held audio falls rather than grows under a stalled timestamp, then rerun strict native, analyzer, sanitizer and retained DVD/audio suites and build only a new static ARM helper for Futurama plus the broader physical-disc menu test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 954 COMMIT Unreleased 67ce19d 2026-09-03T20:08:11-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Bound automatic-menu fallback output latency across physical DVDs without weakening normal title buffering.

#### Outcome:

Source `67ce19d` adds one fallback-aware PCM emission boundary: while a physical DVD's automatic menu is using sink pacing, each scheduled PCM run first drains the asynchronous output reserve, and the fallback itself admits at most one 2,048-frame batch per scheduler pass.  This prevents the four-megabyte normal lane from absorbing approximately twenty seconds of decoded PCM and lets the pipe and unchanged FPGA FIFO credit establish delivery rate, while ordinary advancing-timestamp scheduling, normal title use of the complete optical-stall reserve, overlay priority and byte order remain unchanged.  The production regression starts with 24,000 held frames, proves the first exhausted-target pass emits exactly one batch, repeatedly reaches the exact 8,192-frame reserve and reconstructs all 15,808 emitted stereo frames sample-for-sample through the real reserve; its advancing-PTS control restores the original scheduler.  Strict optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer checks pass, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests, twenty repeated production runs, one hundred menu-hop runs and fifty output-reserve runs.  Real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `6b7524f082e81e3b6f9e49064deea7950804438485bed366e7089b1b434b2da7`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`67ce19d` artifact and retain the current per-core Main, RBF and visualizer.  Test Futurama plus several other physical DVDs that previously delayed at automatic menus; each affected route should log one fallback activation containing `paced_batch=2048`, reach moving menu video and a usable selector without the prior long apparent freeze, retain continuous intelligible audio and show no pacing failure, hold-limit diagnostic, underrun or helper termination.  Launch titles and exercise chapter navigation on at least one disc to confirm the unchanged ordinary reserve path, then return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 953 COMMIT Unreleased 5f1cf92 2026-09-03T19:51:25-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Qualify source `5f1cf92` across Futurama's automatic root menu, nested episode-selection menus and selected-title playback.

#### Outcome:

The physical source-`5f1cf92` run passes hardware validation.  All three finite intro boundaries drain and release, automatic menu entry at 35.059491 seconds preserves the continuous decoder epoch, and the bounded fallback activates with 183,808 held PCM frames before settling near its 8,192-frame reserve without a hold-limit diagnostic, signal-nine termination or audio underrun.  The root menu initially appears frozen while the output path consumes an approximately 1.16 to 1.21 million-frame PCM scheduling lead, about 24 to 25 seconds, but then animates normally and accepts directional input; this is observable catch-up latency rather than a decoder deadlock.  Root-menu activation, nested episode-selection transitions and their overlay transactions complete, the final selection leaves the menu at 327.905704 seconds, and the chosen episode sustains advancing presentation timestamps for more than ninety seconds with over 77 MiB of helper video delivered.  The user confirms the menus are navigable and the selected episode looks and sounds good.  The checksum-valid schema-21 snapshot reports 128 displayed pictures, 127 swaps, zero decoder and PCM protocol errors, zero audio underruns and a valid overlay, while the updated screenshot visibly captures episode playback.  The 17,823,653-byte log, 1,386,067-byte screenshot and 818-byte telemetry sidecar have SHA-256 `4e31c76f52ab03fa55a38027c314064306d4ff9ac8d8b5a3056666d35e41eea7`, `e6511bd6c54ccab344419b1c703b38d61430c1073790293f1d11fef66e0273ce` and `9e6ede6ae979d7a24a16133f9ec1237dc3c4f4dda7bc444c4a84494f26052633`.

#### Next Steps:

Retain source `5f1cf92` and its helper as the accepted hardware baseline.  Treat the initial automatic-menu catch-up as a future latency optimization rather than reopening the functional fix, and broaden physical-disc regression to other automatic menus, still menus and supported title audio before the next release boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 952 COMMIT Unreleased 5f1cf92 2026-09-03T18:36:35-07:00

#### Coming From:

Unreleased 0df8570

#### Purpose:

Bound automatic-menu PCM scheduling when a repeated video timestamp exhausts the normal timestamp-derived audio target.

#### Outcome:

Source `5f1cf92` preserves the continuous automatic-menu decoder epoch and normal advancing-PTS scheduler while recognizing three equivalent stalled-horizon conditions confined to that epoch: video remaining at the first audio PTS, a repeated video PTS, or 256 KiB of delivered video without a PTS advance.  After the timestamp-derived target is exhausted, decoded PCM above the existing 8,192-frame reserve drains completely as individually bounded 2,048-frame batches through the unchanged output and FPGA FIFO-credit path; any later PTS advance disables fallback before the new target is evaluated.  A post-drain 48,000-frame hold invariant now reports and rejects an impossible growing queue instead of allowing host memory exhaustion.  The production test delivers 100,000 patterned stereo frames with exact sample reconstruction, an exact terminal reserve and more than 2 MiB of byte-exact continuous menu video under repeated PTS, verifies the advancing-PTS control remains on its original 2,048-frame timestamp batch, and exercises the hard-limit rejection.  Strict optimized, GCC analyzer, AddressSanitizer, UndefinedBehaviorSanitizer, twenty repeated production runs, native helper, DVD random-access, SPU, menu-hop, output reserve and staging, AC-3 resynchronization, unsupported-LPCM, audio UI, visualizer and seek tests pass.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `a919e4f202d9de9ce996fdfbacbe11c6da815d21e043af0e1f6a6446e2d591f1`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`5f1cf92` artifact and retain the current per-core Main and RBF, then rerun Futurama disc one through the complete intro into its moving menu.  Confirm one `automatic menu PCM fallback activated` diagnostic, continuous intelligible audio without periodic bursts, a responsive selector, held PCM remaining near the 8,192-frame reserve rather than growing by millions of frames, no hold-limit diagnostic and no signal-nine termination; return the updated helper/Main log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 951 COMMIT Unreleased 0df8570 2026-09-03T18:32:13-07:00

#### Coming From:

Unreleased 0df8570

#### Purpose:

Qualify the continuous automatic-menu epoch on Futurama disc one and isolate its remaining burst-audio failure.

#### Outcome:

The physical source-`0df8570` run validates the continuous decoder correction but rejects its audio scheduling.  All three finite intro boundaries complete, automatic menu entry at 43.904862 seconds produces the new helper-only scheduling and PTS epochs without a fourth Main decoder reset, the menu becomes visible and animated, and the user confirms its selector responds.  The checksum-valid schema-21 capture reports 128 displayed pictures and 127 swaps in 4.423730 seconds, zero decoder flags, zero PCM protocol errors and a valid overlay; Main records eighty-two complete overlay commits with no ordering error and no video lookahead failure.  At menu entry the first raw PTS 45,045 is translated to 647,273, equal to the later maximum video horizon, so the audio target remains fixed at the 8,192-frame reserve for the entire run.  The scheduler consequently emits only its 128-frame safety refill per 4,096 video bytes, averaging about 4,270 frames per second instead of 48,000 and matching the reported periodic distorted bursts, while AC-3 decode accumulates unchecked: the final progress record has emitted 591,360 frames but holds 118,129,152 frames, approximately 472.5 MiB of stereo PCM.  Linux then kills the helper with signal nine at 187.177284 seconds, consistent with exhausting the target's approximately 492 MiB visible RAM.  The 4,060,455-byte log, 637,658-byte screenshot and 844-byte telemetry sidecar have SHA-256 `f22b5b1808ac1bb94b8c19440e4c19079410d7c3fed86b5dff1f06925148dbba`, `1bdd9d344bb5b18584c6f04b258b7397b9285806ae4c0f995fcf986c11ed86dc` and `1322af6836d63a481d2fbab7b4815c84a6c95a6a38792eaeba79a139f3a47f19`.

#### Next Steps:

After user approval, preserve the source-`0df8570` continuous decoder/menu transition and normal advancing-PTS scheduler, but add an automatic-menu-only PCM fallback for an exhausted timestamp target: after startup, when decoded audio exceeds the existing reserve and the video horizon schedules nothing, emit the excess in bounded batches through the unchanged PCM transport so FPGA FIFO credit supplies the real-time 48 kHz backpressure instead of allowing an unbounded host queue.  Add a hard bounded-hold invariant and diagnostics, extend the production regression with repeated or nonadvancing menu video PTS plus sustained decoded PCM to prove continuous exact sample delivery, bounded memory, byte-exact video and unchanged advancing-PTS behavior, rerun strict native, analyzer, sanitizer and retained DVD/audio suites, then build only a new static ARM helper for another Futurama menu test; Main, protocol, RTL and RBF should remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 950 COMMIT Unreleased 0df8570 2026-09-03T17:53:57-07:00

#### Coming From:

Unreleased d7d5ab2

#### Purpose:

Carry a live silent-video decoder session continuously into an automatic DVD menu while starting a fresh synchronized helper scheduling epoch.

#### Outcome:

Source `0df8570` removes the automatic silent-video-to-menu READY/GO boundary while retaining every finite-still and explicit-navigation decoder boundary.  Silent-video release now includes the H.262 compatibility filter's pending byte in its capacity decision and flushes that byte through the bounded queue before switching to immediate output, preserving exact order.  Automatic menu entry keeps the live FPGA decoder and resident frame, rearms only helper audio and bounded scheduling state, leaves the initial sequence/I/reference filter disabled, and establishes one explicit PTS offset shared by menu video and audio above the preceding DVD timestamp.  The production regression releases a near-2 MiB silent first-play fixture byte-exactly, then schedules more than 2 MiB of picture-bearing menu video with no new sequence header alongside synchronized AC-3 without reaching the lookahead limit.  Optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer builds pass, as do the strict native static helper and retained DVD random-access, menu-hop, SPU, reserve, staging, unsupported-LPCM, audio UI, visualizer and seek tests.  GNU 10.2.1 builds the 966,052-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `af73f0d5ae8104ef05fa3270b51a5da3bf92b39189cd32fc9219b5d2ac0efb6c`; Main remains source `d7d5ab2`, and the protocol, decoder RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`0df8570` artifact, retain the source-`d7d5ab2` per-core Main and existing RBF, then rerun Futurama disc one through all finite intro stills, the complete 20th Century animation and the moving menu.  Confirm that menu entry produces the new `DVD automatic menu scheduling epoch continued` and `DVD automatic menu PTS epoch` diagnostics, no fourth Main decoder boundary, no `video lookahead limit exceeded`, visible menu motion and selector response; return the resulting log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 949 COMMIT Unreleased d7d5ab2 2026-09-03T17:49:51-07:00

#### Coming From:

Unreleased d7d5ab2

#### Purpose:

Qualify the boundary odd-byte correction on Futurama disc one and isolate the later black failure during its 20th Century transition.

#### Outcome:

The physical source-`d7d5ab2` run validates the corrected Main boundary path but rejects the complete host behavior.  All three finite first-play stills now finish and cross one decoder boundary each, the first two observed odd tails each log `pipe quiescent odd_tail=1` and submit their final byte, and every boundary reaches `released after drain`; the third session then qualifies a normal sequence/I/P restart group, releases 2,096,389 queued silent-video bytes and visibly advances into the 20th Century animation.  At 40.445047 seconds libdvdnav enters menu space while that live video session is still progressing, and the helper requests a fourth decoder boundary; Main drains 76,372 remaining bytes, resets the healthy decoder at 41.727776 seconds and leaves a black display.  The fresh menu epoch emits no H.262 restart diagnostic because its next 2,097,152 bytes never contain the sequence-header/I/reference combination required only after a decoder reset, although the helper accepts AC-3, publishes nine complete 86,400-byte overlay planes and remains responsive to an Up command that changes button one to four.  At 85.968714 seconds the queued video reaches the implementation guard and `video lookahead limit exceeded` deliberately exits the helper with code one.  Checksum-valid schema-21 telemetry confirms zero pictures and swaps in the reset session, nine valid overlay commits with no protocol error, and no audio underrun or transport block; the black 1,920-by-1,080 screenshot retains only the telemetry raster.  The 1,707,301-byte log, 1,557-byte screenshot and 480-byte telemetry sidecar have SHA-256 `9ec5ac166630067398f71e8226ed2c2b7a49f0cc68639ce43effc59bd3101789`, `5b3b2acf3c879c741b48e7d7a9c6c89b2ffc73f65b7ad1af633f7903491c421b` and `c5c1c9ba9f37749c4f0fa08b16d9ad56761fc12579b5b63b3739cd0509618f`.

#### Next Steps:

After user approval, preserve all finite-still decoder boundaries and the source-`d7d5ab2` Main correction, but stop resetting the already-live FPGA decoder solely because the continuous first-play video enters menu space.  Replace that automatic boundary with a helper-only audio and scheduling epoch transition that drains any pending H.262 normalization byte in original order, retains continuous decoder context and the resident picture, does not re-enable the initial random-access filter, and keeps the new menu's audio/video PTS relationship valid without a backward FPGA timestamp.  Add a production-path regression whose post-transition video exceeds 2 MiB without a new sequence header, proving byte-exact continuous delivery, bounded scheduling, synchronized AC-3 admission, overlay continuation and no Main READY/GO; retain finite-still boundaries, explicit navigation hops, late-audio rejection and sanitizer coverage, then build only a new ARM helper and retest Futurama through the complete animation into its moving menu.  Main, protocol, RTL and RBF should remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 948 COMMIT Unreleased d7d5ab2 2026-09-03T16:51:15-07:00

#### Coming From:

Unreleased ae533a1

#### Purpose:

Submit the final odd byte of an autonomous DVD boundary after nonblocking pipe quiescence instead of returning before the existing transport path.

#### Outcome:

Source `d7d5ab2` corrects the single Main control-flow defect demonstrated by the Futurama trace: after an autonomous boundary, nonblocking pipe quiescence with one buffered byte now falls through to the existing transport routine, which submits that real byte in a zero-padded 16-bit word, while ordinary non-boundary lone bytes remain held and `EINTR` remains nonterminal.  A later empty-pipe observation permits the existing reset and GO handshake, so no media byte is discarded and the control protocol, helper, RTL and RBF are unchanged.  The lifecycle regression covers ordinary hold, interrupted read, boundary odd-byte submission, empty-pipe release, exact byte accounting and a single reset/GO; optimized, AddressSanitizer plus UndefinedBehaviorSanitizer and GCC analyzer runs pass.  The production overlay-output regression passes optimized, AddressSanitizer and UndefinedBehaviorSanitizer runs, the patch applies cleanly to pinned Main `0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f`, and two local GNU 10.2.1 ARM builds are byte-identical.  The resulting 1,182,692-byte ARMv7 executable `host/build/MiSTer_MediaPlayer` has SHA-256 `250f065859f30150a4b8226072b254ff81f76e27e1b926d1c63ede0ef48bc121`; the unchanged 966,052-byte helper has SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72`.  The 1,335,713-byte archive `host/build/MiSTer_MediaPlayer_BoundaryByte_d7d5ab2.zip` has SHA-256 `0ef5a03055e39a52ea185064ca32b1a74c53f67fe0309200f72d0f38d6086783`; ZIP integrity, fresh extraction, executable modes and its five-file manifest verify.

#### Next Steps:

Leave `/media/fat/MiSTer` untouched, install the archive's `MiSTer_MediaPlayer` and `linux/MediaPlayer_Helper` at the paths documented in `INSTALL.txt`, merge only its `[MediaPlayer]` fragment, set both executables to mode 755 and reboot.  Retest Futurama through every finite first-play still into its visible moving menu with synchronized AC-3 and responsive activation.  The log should show the helper boundary request and Main boundary pending; when an odd tail exists it should then show `DVD stream boundary pipe quiescent odd_tail=1`, a one-byte transfer, `DVD stream boundary released after drain`, and helper release rather than repeated would-block polling.  Collect a fresh Main/helper log, screenshot and telemetry for acceptance or further isolation.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 947 COMMIT Unreleased ae533a1 2026-09-03T16:48:14-07:00

#### Coming From:

Unreleased ae533a1

#### Purpose:

Qualify the isolated-Main stream-boundary build on Futurama disc one and isolate its first finite-still freeze.

#### Outcome:

The physical source-`ae533a1` run confirms that the per-core Main selection works, but rejects the stream-boundary handshake as implemented.  Main starts the `MediaPlayer` core through its alternate executable and the helper completes the first authored ten-second FBI still, sends the autonomous boundary event and waits for GO.  Main receives that event at 20.234007 seconds after submitting 224,682 bytes, but retains one buffered byte and never records `DVD stream boundary released after drain`; more than four million later would-block polls submit no additional data through the 227-second capture endpoint.  The visible FBI frame and checksum-valid schema-21 snapshot show that this is a host-handshake deadlock rather than a decoder failure: the FPGA accepted 224,669 decoder bytes, exactly the 224,665-byte authored video plus the four-byte sequence end, completed and displayed its one I picture, reports sequence end, presentation complete and session quiet, and has zero decoder errors, transport blocks, PCM samples or audio underruns.  The five following zero bytes are implementation-only transport drain; four crossed Main before the terminal decoder stopped returning input credit and the fifth remains in Main's pipe buffer, so the current requirement that every boundary byte receive FPGA credit can never become true.  The 5,630,162-byte log, 685,317-byte screenshot and 441-byte telemetry sidecar have SHA-256 `24ff68036d13b73d674dca1bf349a5fb2041d4de4343ef3f0bbe8ac041732d45`, `afcb6905c04398c9bcf6f2aef795d55bbcc85c990000d90908b6bc88f6c84f3e` and `dfb936ef46bc9eb7324357e82d356be24c3f7646d4bc6183ba5e07e7880bfa52`.

#### Next Steps:

After user approval, distinguish a finite terminal boundary from an automatic silent-menu boundary on the control channel and give only the terminal form an explicit five-byte discardable-tail contract.  Main must continue submitting all meaningful queued media, then after pipe quiescence accept at most the declared number of remaining zero tail bytes, record their exact count, reset download once and send GO; a nonzero byte, an oversized remainder or any residue on the automatic boundary must fail rather than be hidden.  Extend the Main regression with the observed one-byte no-credit remainder plus zero-, partial- and malformed-tail cases, retain the helper production-path and sanitizer suites, rebuild the patched per-core Main and static ARM helper locally, and retest Futurama through every finite intro still into its moving menu without changing the RBF or RTL.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 946 COMMIT Unreleased ae533a1 2026-09-03T16:22:52-07:00

#### Coming From:

Unreleased ce5a826

#### Purpose:

Install the patched Main only for MediaPlayer so development testing no longer replaces the official system-wide MiSTer executable.

#### Outcome:

Source `ae533a1` makes `host/build/MiSTer_MediaPlayer` the canonical patched-Main output and adds a merge-only `MiSTer.ini` fragment containing the core-reported `[MediaPlayer]` section and `main=MiSTer_MediaPlayer`.  Current build and hardware-test guidance now installs that executable at `/media/fat/MiSTer_MediaPlayer`, retains `/media/fat/MiSTer` for every other core and explains the automatic return to official Main when the Menu core loads; the published v0.9.0 records remain unchanged as historical package provenance.  The pinned-Main build applies and compiles locally with GNU 10.2.1, shell syntax and the exact fragment contract pass, and the renamed 1,182,692-byte binary is byte-identical to the tested source-`ce5a826` Main at SHA-256 `99084bc5db9062e2984ec93f40158f4bfd4c265300b314c7a7ddbd6e8081f706`; the matched 966,052-byte helper remains SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72`.  The host-only test archive `host/build/MiSTer_MediaPlayer_StreamBoundary_ae533a1.zip` contains the two executables, merge fragment, installation and provenance notes plus a five-entry manifest; ZIP integrity and a fresh-extraction manifest check pass.  It is 1,335,862 bytes at SHA-256 `ab9601a2c1c1f08c42aeec842187d822d0b69ea8bb4ddd697c3a7ec42b18697c`.  Helper behavior, Main behavior, RTL, RBF and visualizer are unchanged from `ce5a826`.

#### Next Steps:

Leave `/media/fat/MiSTer` untouched, extract the test archive, copy `MiSTer_MediaPlayer` and `linux/MediaPlayer_Helper` to the paths in `INSTALL.txt`, merge only its `[MediaPlayer]` fragment at the end of the existing `/media/fat/MiSTer.ini`, set both executables to mode 755 and reboot.  Confirm MediaPlayer enters the alternate Main and returning to the Menu core returns to official Main, then run Futurama disc one through every finite intro still into its automatic menu.  Acceptance requires continued playback after each still, visible background and moving selector, synchronized AC-3, responsive activation and fresh log, screenshot and telemetry evidence from the matched pair.

#### Files Modified:

- README.md
- assets/MiSTer_MediaPlayer.ini.fragment
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/build_arm_stack.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 945 COMMIT Unreleased ce5a826 2026-09-03T06:33:43-07:00

#### Coming From:

Unreleased cea2add

#### Purpose:

Reopen the FPGA decoder at autonomous DVD stream boundaries without discarding the completed still or hiding the late-audio synchronization failure.

#### Outcome:

Source `ce5a826` adds control event `0x86` as a coordinated helper/Main stream boundary.  Every expired finite DVD still now drains its intentional sequence-end transport, and an automatic menu transition out of a silent epoch preserves the already-consumed Program Stream start code; in both cases the helper flushes its exclusive reserve, resets demux, audio, PTS, random-access and bounded scheduling state, sends the boundary event and waits for GO.  Main continues submitting through an exact pipe-empty observation, including an odd final byte, then toggles download exactly once and releases the helper without discarding old media or clearing the overlay.  Input polls the control socket before acting and all controls are suppressed during the boundary, while a paused session still drains it.  Static inspection established that `dvdmenu:` and `isomenu:` deliberately bypass the optical prefetch ring, so their libdvdnav state is already consumer-synchronous and `media_source.c` required no change.  The focused production-translation-unit and Main lifecycle regressions pass optimized strict builds, AddressSanitizer and UndefinedBehaviorSanitizer; focused GCC analysis passes with the established audio-overlay leak false positive suppressed.  The updated patch applies to pinned Main `0a8fb44` and both local GNU 10.2.1 ARM builds succeed.  `host/build/MiSTer_StreamBoundary_ce5a826` is 1,182,692 bytes at SHA-256 `99084bc5db9062e2984ec93f40158f4bfd4c265300b314c7a7ddbd6e8081f706`; the static stripped ARMv7 `host/build/MediaPlayer_Helper_StreamBoundary_ce5a826` is 966,052 bytes at SHA-256 `32c9a5846aac94f4c1ce2c1bb36a752b5a1c71bfa4ab0bcf304170ef58645e72` and has no dynamic section.  RTL and the RBF are unchanged.

#### Next Steps:

Install the matched `MiSTer_StreamBoundary_ce5a826` and `MediaPlayer_Helper_StreamBoundary_ce5a826`, preserving the accepted RBF and visualizer, and reboot for Main.  Run Futurama disc one from first-play through all finite intro stills into the automatic menu; require one `DVD stream boundary pending` and `released after drain` pair for each terminal still, fresh accepted-byte progress after every reset, visible menu background and selector movement, synchronized AC-3, overlay records in the active telemetry session, title activation and return-to-menu.  Then recheck Blazing Saddles redundant-root behavior, Coming to America overlay-only Scene Selections, The Big Lebowski navigation and the forum disc's silent LPCM menu before accepting the matched host pair on hardware.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_dvd_overlay_output.c
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 944 COMMIT Unreleased cea2add 2026-09-03T06:15:39-07:00

#### Coming From:

Unreleased cea2add

#### Purpose:

Use the physical Futurama result to distinguish the automatic-menu scheduler correction from an earlier terminal-still decoder-session freeze.

#### Outcome:

The physical `FUTURAMA_S1D1` run rejects source `cea2add` visually but proves the helper did not freeze.  The first authored ten-second still is finalized from 224,665 bytes of sequence-plus-I video, receives sequence end and transport drain, and is the only payload the schema-21 FPGA snapshot accepts: 224,780 bytes, one I picture, one reference and one displayed picture, sequence-end seen and presentation complete, with zero decoder error flags, transport blocks or audio underruns.  Three finite-still expirations then resume the same completed download session without a READY/GO decoder reset.  The helper continues, classifies later first-play video silent, enters the menu at 40.449462 seconds, rearms source `cea2add`, selects AC-3 substream `0x80`, publishes seven complete overlay planes and accepts an Up command at 63.111029 seconds that changes the authored button from one to four; it remains alive beyond 71 seconds.  Main submits through overlay offset 9,035,621, but telemetry retains zero overlay records, zero PCM samples and the first still's 224,780 accepted bytes, proving every later video, audio and overlay record remains outside the terminal FPGA session.  The black 1,600-by-1,200 screenshot contains valid telemetry but no decoded menu background.  The 1,477,359-byte log, 2,788-byte screenshot and 441-byte sidecar have SHA-256 `19bf6160b410268650e34db63b7507c1d7f5b21396a4d9314da5ebe3fc9d7518`, `bba7649ac2ac61c546f485a5f52d6f9bd09a7b9e4b17552b7ee0aed2ea380a1d` and `abe2bbe935177401657cdb1090b2e3b8b63d3c17368ccd20e4d5a990bf57318c`.  The helper-only menu rearm is therefore insufficient because it cannot reopen an FPGA session already closed by the first finite still.

#### Next Steps:

After user approval, replace the helper-only assumption with an explicit autonomous DVD stream-boundary handshake shared by Main and the helper while retaining the decoder and RTL.  Associate buffered libdvdnav transition metadata with its consumed payload position rather than exposing producer-ahead menu state; when a finite authored still expires or a synchronized automatic menu domain begins after a terminal or silent epoch, finish the intentional old transport, notify Main without requiring a user navigation command, drain rather than discard the completed boundary, deassert and reassert download exactly once, then send GO so the helper resets demux, audio, PTS, random-access and bounded scheduling before consuming the new epoch.  Remove the unsynchronized `cea2add` post-`find_start_code` rearm.  Add regressions for multiple finite first-play stills followed by a silent segment and an automatic video-plus-AC-3 menu, verifying one decoder reset per terminal boundary, consumer-position menu notification, accepted background video, PCM and overlay records, while retaining directional continuations, explicit navigation hops, staged menus, silent Program Streams, late-audio rejection, reserve ownership, seek, audio and sanitizer coverage.  Build Main and the static ARM helper locally; no RTL simulation is required unless implementation evidence unexpectedly reaches the transport decoder.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 943 COMMIT Unreleased cea2add 2026-09-03T05:54:12-07:00

#### Coming From:

Unreleased 401148e

#### Purpose:

Rearm bounded Program Stream scheduling when a silent first-play DVD epoch automatically enters an authored menu with its own synchronized audio timeline.

#### Outcome:

Source `cea2add` fixes the stale-state cause without weakening the late-audio guard.  `process_program_stream` now refreshes libdvdnav menu state immediately after `find_start_code` exposes a new block and before that payload is processed; a false-to-true menu transition rearms output only when the preceding epoch was already classified silent.  The rearm uses the established navigation reset to reacquire initial random-access video, PTS normalization, bounded lookahead and PCM startup hold while preserving the output reserve and activation stage and emitting no decoder barrier, Main reset or overlay clear, so the prior resident frame remains available until menu video replaces it.  The production-translation-unit regression queues 2,097,144 bytes of silent first-play video with PTS 151,777, proves the old state rejects AC-3 PTS 45,045 as 106,732 ticks behind, rearms the automatic menu epoch, qualifies fresh sequence/I/P video at PTS 45,045 and accepts that synchronized AC-3 through the real private-PES path.  Strict optimized compilation, focused GCC analyzer, AddressSanitizer address checks, UndefinedBehaviorSanitizer, DVD random-access, SPU, menu-hop, overlay, reserve, staging, AC-3 recovery, Program Stream seek, private LPCM skip, audio UI, visualizer and audio-file seek tests pass; LeakSanitizer remains unavailable in the ptrace-hosted local environment.  Local GNU 10.2.1 produced the 966,052-byte static stripped ARMv7 EABI5 helper `host/build/MediaPlayer_Helper_MenuEpoch_cea2add` with SHA-256 `23547d0d777cbc666759f0623d6b7d5b899902698a95e7da98c914405926791e`; it has no dynamic section, passes its protocol-one capability probe and passes real MP3, WAV, FLAC, Ogg and private-LPCM integrations under local ARM execution.  Main, media-source navigation policy, decoder, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_MenuEpoch_cea2add`, preserve executable mode and retain the accepted v0.9.0 Main, visualizer and RBF.  Run the same `FUTURAMA_S1D1` physical disc from first-play into its automatic menu with telemetry; acceptance requires the silent lookahead record followed by `DVD menu entered` and `DVD automatic menu scheduling epoch rearmed`, a surviving helper, audible synchronized menu AC-3 and visibly moving selector highlights.  Activate a title, return to the menu and exercise each selector direction once, then return fresh log, screenshot and telemetry results.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 942 COMMIT Unreleased 401148e 2026-09-03T05:40:29-07:00

#### Coming From:

Unreleased 401148e

#### Purpose:

Use the source-`401148e` Futurama diagnostic to distinguish a safely future late-audio packet from stale silent-video state crossing an automatic DVD menu transition.

#### Outcome:

The fresh `FUTURAMA_S1D1` run reproduces the expected helper exit and supplies both bounded diagnostic records.  Before libdvdnav reports entry into the authored menu, the helper classifies the active DVD session as silent at the 2 MiB queue boundary, releasing 2,096,723 queued bytes at 2,321,525 total video bytes with two picture marks and a maximum video PTS of 151,777.  It then remains in permanent silent mode across the automatic menu-domain transition and emits 8,636,808 total video bytes before encountering the menu's valid AC-3 substream `0x80`.  That first audio packet has PTS 45,045, which is 106,732 90 kHz ticks, approximately 1.186 seconds, behind the retained video horizon; accepting it at the existing rejection point would therefore start audio late rather than restore synchronization.  The checksum-valid schema-21 snapshot again reports one completed and displayed I picture, sequence-end and presentation completion, zero decoder errors, zero transport blocks and zero audio underruns.  Main observes the expected exit-code-one helper EOF only after draining reserved output.  The 1,078,836-byte log, 637,394-byte screenshot and 441-byte sidecar have SHA-256 `5ee82e04ed9e510db88dffcafd2a70f28b3f68f341925048a3039f7e9a707ba3`, `a6a8c0694187aa92fde5509c54b4785a498276d33d785dccccb8e40cbeffe205` and `3c852112765d9bf2b432454813449353e9c66b02cf828fa31aef1acd92f408bf`.  The diagnostic succeeds and local source remains unchanged.

#### Next Steps:

After user approval, preserve the 2 MiB bound and the late-audio fail-fast guard while treating an automatic DVD transition from first-play/title space into menu space during silent-video mode as a new scheduling epoch.  Refresh the DVD menu state immediately after source reads expose the transition and before processing that payload, then rearm bounded video lookahead, the initial random-access filter, PTS state and PCM startup hold without clearing the resident frame, resetting Main or changing libdvdnav navigation.  Add a production-path regression that begins with more than 2 MiB of silent first-play video, enters a menu, and then supplies synchronized video plus AC-3, proving that the old source-`401148e` path rejects it while the corrected epoch accepts and schedules it; retain genuinely silent Program Stream completion, out-of-epoch late-audio rejection, automatic menu exit, authored still, overlay, staging, navigation, audio and sanitizer coverage.  Build only a new static ARM helper locally for Futurama menu, selector, title launch and return-to-menu testing while retaining the accepted v0.9.0 Main, RBF and visualizer.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 941 COMMIT Unreleased 401148e 2026-09-03T04:56:54-07:00

#### Coming From:

v0.9.0 b1a6dcb

#### Purpose:

Instrument and reproduce Futurama's late-menu-audio rejection so the permanent silent-video classification can be corrected without hiding an A/V synchronization failure.

#### Outcome:

The fresh `FUTURAMA_S1D1` physical-disc capture reaches its authored menu, publishes one valid still and selector overlay, and then leaves that frame resident after the helper exits normally with status one.  The checksum-valid schema-21 snapshot reports one completed and displayed I picture, sequence-end and presentation completion, zero decoder error flags, zero transport blocks and zero audio underruns.  The helper log identifies the software boundary: before any audio PES appears, the bounded 2 MiB video queue fills and `scheduler_release_silent_video()` irreversibly disables scheduling; the later valid AC-3 private substream `0x80` reaches the deliberate late-audio rejection, after which Main drains the already-reserved bytes and observes helper EOF.  Source `401148e` preserves that fail-fast behavior and every media byte while logging the exact silent-release queue, released and total-video counts, picture count and final video PTS horizon, followed by the late MPEG Layer II, AC-3 or DTS packet's PTS validity, value, horizon relation and absolute 90 kHz delta.  The focused production-translation-unit regression forces the 2 MiB boundary, proves its queued video remains byte-identical and verifies ahead, behind and untimestamped late-audio diagnostics.  Strict optimized compilation, focused GCC analyzer, AddressSanitizer, UndefinedBehaviorSanitizer, DVD random-access, SPU, overlay, reserve, output-stage, menu-hop, private-LPCM-skip, AC-3 recovery, Program Stream seek, audio UI, visualizer and audio-seek tests pass.  Real MP3, WAV, FLAC and Ogg integrations pass against both native and final ARM helpers with 378 or 381 pictures and one clear record per file.  Local GNU 10.2.1 produced the 966,052-byte static stripped ARMv7 EABI5 helper `host/build/MediaPlayer_Helper_LateAudioDiag_401148e` with SHA-256 `19020ff3e785718854fe399f23462720428012129082335f9c3c61414fa371c7`; its protocol-one capability probe passes and it has no dynamic section.  Main, decoder, RBF, visualizer and RTL are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_LateAudioDiag_401148e`, preserving executable mode and the installed Main, RBF and visualizer.  Enable telemetry, launch Futurama disc one, wait until the menu and selector appear and allow the helper to reach its expected clean rejection without needing to press a direction.  Return the fresh helper log; its `video lookahead classified silent` and expanded `AC-3 audio begins beyond` records will establish whether the first audio PTS is ahead of, equal to or behind the already-released video horizon.  Do not suppress the rejection or increase the queue from this diagnostic evidence alone; use the measured temporal relationship to propose the bounded state transition that retains genuinely silent Program Streams and synchronized late-starting DVD audio.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 940 COMMIT Unreleased 177886b 2026-09-03T03:51:20-07:00

#### Coming From:

Unreleased 7759f87

#### Purpose:

Qualify, document and package the accepted v0.9.0 runtime set for the user's GitHub release publication.

#### Outcome:

The user reports that the complete v0.9.0 functional and regression matrix looks good and accepts the exact runtime set for release.  At the user's explicit direction, packaging invoked no build: it retained the already clean, reproducible, timing-qualified source-`dfe1057` RBF and byte-identical accepted source-`3689cca` Main, source-`0f1165c` helper and source-`366a227` visualizer pack with source-`932dc22` behavior.  The helper's protocol-one capability probe passes.  `host/build/MiSTer_Media_Player_v0.9.0.zip` contains the five runtime/launcher payloads, installation and source notes, the project licence, seven dependency licences and a 15-entry SHA-256 manifest.  A fresh extraction is byte-identical to its bounded staging directory, every manifest entry passes, ZIP integrity is clean, and Main/helper retain mode 755 while all other files use mode 644.  The 6,580,818-byte archive has SHA-256 `e8bc8e0c25291df85d6d53ad2688995d30ce156c547b7315b08058052863e1f9`; its 16 files total 10,476,902 uncompressed bytes.  Source `177886b` moves the changelog into the dated v0.9.0 milestone, starts a clean Unreleased section and finalizes the README, release notes, architecture, build and test guidance with the exact package identity, accepted validation and no-rebuild provenance.  Documentation link, fence, whitespace, package-identity and staged-diff audits pass.  No tag or GitHub Release was created.

#### Next Steps:

The repository and package are ready for the project owner to create annotated tag `v0.9.0` on the final metadata commit following source `177886b`, create a GitHub pre-release titled `MiSTer Media Player v0.9.0`, attach `host/build/MiSTer_Media_Player_v0.9.0.zip`, and use `docs/RELEASE_NOTES_v0.9.0.md` as the release description.  After publication, record the tag resolution, GitHub release time and downloaded-asset verification in a VERSION entry without changing the accepted runtime payloads.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/RELEASE_NOTES_v0.9.0.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---

## 939 COMMIT Unreleased 7759f87 2026-09-03T03:19:43-07:00

#### Coming From:

Unreleased 0f1165c

#### Purpose:

Prepare the repository documentation and release-candidate notes for the v0.9.0 capability set accumulated since v0.8.0.

#### Outcome:

The user reports that the source-`0f1165c` candidate looks good and is conducting the final functional and regression pass independently.  Source `7759f87` reconciles the README, changelog, architecture, build and hardware-test documentation with the complete v0.9.0 candidate: native 480p and expanded native-480i decoding, Program Stream seeking and replay-ready EOF, standalone consumer audio and its timed visualizer overlay, encrypted ISO and direct-optical DVD playback, authored menus and scene selection, unsupported LPCM behavior, telemetry and current limitations.  It adds dedicated v0.9.0 release-candidate notes with the tested component identities, exact candidate artifact hashes and established timing/resources while explicitly reserving publication provenance for the clean release build.  It also adds a focused media-preparation guide and promotes the user's 720-by-480 exact-24-fps MPEG-2 Program Stream FFmpeg command as the project recipe.  That command produces the documented Main Profile, 4:2:0, 32:27-SAR output with a 48 kHz 320-kilobit MP2 track and also succeeds without an input audio stream; local links, code fences, whitespace and staged-diff checks pass.  No runtime source or artifact changed.

#### Next Steps:

Complete the user's functional and regression matrix, then perform the required clean/from-scratch Quartus, helper, Main and visualizer release build from the exact accepted source.  Once those artifacts reproduce and pass the final hardware gate, update the changelog from Unreleased to the dated v0.9.0 boundary, replace candidate language with final package filenames and hashes, and have the user create the annotated tag and pre-release from that exact documentation commit.  Do not tag or publish v0.9.0 before those gates close.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/RELEASE_NOTES_v0.9.0.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 938 COMMIT Unreleased 0f1165c 2026-09-03T02:28:26-07:00

#### Coming From:

Unreleased 490dc02

#### Purpose:

Normalize each qualifying malformed DVD H.262 sequence boundary across PES fragmentation instead of correcting only the session's initial random-access group.

#### Outcome:

Source `0f1165c` replaces the startup-only correction boundary with a DVD/ISO elementary-video compatibility filter that carries sequence, picture and extension syntax state across PES payloads and delays exactly one byte.  That lookahead validates `progressive_frame` before conditionally setting the preceding zero `chroma_420_type` bit on only the first valid complete-frame I picture after a 4:2:0 sequence header; stream length, byte order, offsets and timestamp-record order remain exact, navigation reset discards the old held suffix, and authored-still or ordinary stream completion flushes it.  Every correction logs its cumulative elementary-stream offset and before/after byte.  The focused C regression joins two captured malformed Big Lebowski prefixes and proves exactly offsets 185 and 380 change from `0xc0` to `0xc1` under every possible single split and one-byte fragmentation, while conforming, non-4:2:0, non-I, field and interlaced controls remain byte-identical.  Icarus reproduces source 21 on the original prefix and admits two consecutive corrected stills with supported film fields and no syntax error.  Strict native and ARM helper builds, ASan/UBSan, focused GCC analyzer, one hundred random-access, menu-hop, reserve and staging repetitions, twenty overlay and SPU repetitions, Program Stream seek, audio seek/UI/visualizer and unsupported-LPCM tests pass.  The exact ARM helper passes its capability probe and real MP3/WAV/FLAC/Ogg integration with 378 or 381 pictures and one clear record per file.  The static stripped ARMv7 EABI5 artifact `host/build/MediaPlayer_Helper_H262Stream_0f1165c` is 966052 bytes with SHA-256 `613d35de5ace0622584ae14b4540423c2c56b1f923c02c599f47b55722e21e56`; Main, RBF and visualizer are unchanged.

#### Next Steps:

Exit MediaPlayer, replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper_H262Stream_0f1165c`, preserve executable mode and retain the installed Main, visualizer and timing-qualified RBF.  With telemetry enabled, start The Big Lebowski and require correction one at elementary offset 185, a second correction when the following seven-second still begins, accepted bytes advancing beyond the former 5,670-byte failure boundary, error flags remaining zero and normal title playback beginning.  Press `m`, exercise the Root Menu and Scene Selection repeatedly, return to the title and reopen both paths, then verify each new malformed authored sequence is corrected without a helper exit or decoder latch.  Spot-check Blazing Saddles and Coming to America title, menu and chapter navigation before returning the fresh log, screenshot and telemetry sidecar.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c
- tools/test_h262_restart_normalization.sv

#### Status:

- [x] Built
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
