## 761 COMMIT Unreleased cee1a9e 2026-08-30T04:52:39-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Capture and accept the complete five-minute Coming to America hardware run on the timing-clean seed-19 build.

#### Outcome:

The user completes `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` on the installed 4,461,996-byte seed-19 RBF with SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6` in Native 480i, selects `16:9`, and reports that the menu, video, cadence and audio are perfect, including both HDMI and S/PDIF output.  The 760,234-byte scaled capture `/tmp/entry761_coming_to_america_5min_pass.png`, SHA-256 `3264087262cba98c011e63e6948f9e43bb6d74c88b583977feb916025b1e9b26`, and the 481,208-byte native 720x480 capture `/tmp/entry761_coming_to_america_5min_raw.png`, SHA-256 `c2811cbe6df8b1c1468724ddf1f4ac57ee401547cda8e8e278496c1cc167f312`, visibly preserve a clean final frame at the requested aspect ratio.  Every header, row index and parity bit in the raw capture's 64-record schema-20 telemetry is valid, and its XOR checksum `a5aeeea2` matches.  The end-of-run no-progress snapshot accepts 202,450,560 clean-video bytes, records 2,539 reference pictures, 7,193 displayed pictures and 7,192 swaps, and has zero aggregate hardware error flags, zero transport blocks and zero audio FIFO underruns.  The matching 8,501,618-byte helper log `/tmp/entry761_coming_to_america_5min_pass.log`, SHA-256 `d4c3693bd3392938dbd25931deefcb907c90ce0afcba36ad42a97ef2977d1ce1`, names the exact five-minute file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, emits all 9,375 audio frames and 14,400,000 PCM samples, reaches EOF, exits zero, and submits all 264,556,180 transport bytes on the fast path.  This hardware result accepts the progressive-film field-DCT admission correction, the simplified production menu, 16:9 presentation, HDMI audio, S/PDIF audio and the timing-clean seed-19 artifact without any source, RBF, helper, media or mode change during the test or capture.

#### Next Steps:

Treat source `cee1a9e` and the installed seed-19 `162c788d` RBF as the accepted Coming to America compatibility boundary, preserve the verified `bc79d56a` rollback, and do not reopen the corrected progressive-film admission path based on this title.  Before a future clean build intended for release reproducibility, explicitly decide whether to pin fitter seed 19 in `MediaPlayer.qsf` and rebuild; otherwise await the user's next compatibility target or release instruction.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 760 COMMIT Unreleased cee1a9e 2026-08-30T04:40:08-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Install the timing-clean seed-19 RBF with an independently verified target rollback and begin the approved Coming to America hardware validation.

#### Outcome:

After the user instructs continuation because seed 19 passes timing, local artifact verification reconfirms the 4,461,996-byte `output_files/MediaPlayer.rbf` at SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`.  Absolute FTP inventory finds exactly one installed core, `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; independent readback proves that it is the expected 4,456,984-byte `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837` timing-clean known-good build.  That exact readback is uploaded under the new rollback path `/media/fat/_MediaPlayer_Backups/MediaPlayer_cee1a9e_pre_seed19_bc79d56a.rbf`, and a second independent download reproduces the complete `bc79d56a` hash.  The single installed filename is then replaced in place with the seed-19 RBF, and the install helper's independent absolute-path readback reproduces all bytes and exact `162c788d` hash.  No Main, helper, media, configuration or source file changes, and the current FPGA remains unchanged until the user reloads the core.

#### Next Steps:

Reload MediaPlayer from the MiSTer menu so the newly installed RBF configures the FPGA.  Confirm the visible menu contains `Aspect Ratio` with `4:3` and `16:9`, `Deinterlacer Mode` with `Bob` and `Weave`, the existing `Audio Test` choices, and `Audio Output` with `HDMI` and `S/PDIF`, with no 800x600 or timing-pattern options.  Select `4:3`, `Bob` and `HDMI`, then play the unchanged `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` once for five minutes and report whether it launches immediately and whether video, cadence, HDMI audio and synchronization remain clean.  Leave the completed screen untouched for capture if any failure occurs; do not replay Big Lebowski unless this run succeeds and a control is materially needed.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 759 COMMIT Unreleased cee1a9e 2026-08-30T03:36:32-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Admit legal progressive-film pictures using field DCT, simplify the product menu, remove the obsolete 800x600 diagnostic mode, and produce a timing-clean Quartus build.

#### Outcome:

Source `cee1a9e` removes only the erroneous `frame_pred_frame_dct` prerequisite from progressive-film admission and documents that a clear flag admits macroblock-level field DCT and prediction handled by the existing downstream parser.  The menu now exposes `Aspect Ratio` as `4:3` or `16:9`, `Deinterlacer Mode` as `Bob` or `Weave`, the unchanged `Audio Test` choices, and `Audio Output` as `HDMI` or `S/PDIF`; Bob and 4:3 are the zero/default selections.  The obsolete 800x600, native timing-pattern and pattern-motion controls and top-level pattern mux are removed, Native 480i no longer depends on their saved status bits, and no hidden stale selection can reactivate them.  The exact 91,436-byte Coming to America first-I/P prefix accepts every byte, retires all 30 P rows, publishes both references and one swap, and completes with zero decoder, raster, writer or presentation errors.  Film cadence, reorder timestamps, reference-overlap ownership, native field order, all repeated-field cache cases, combined P/B field motion plus field DCT, interlaced P/B field-DCT residuals, B field motion, progressive mixed-raster pixels, native timing, startup, cache refill, generation, presentation integration, deadline and cadence-profiler regressions all pass.  A clean GitHub worktree build with the pinned `260829` build ID compiles at 34,156 of 41,910 ALMs, 52,529 registers, 4,181,443 memory bits and 67 DSP blocks.  Default fitter seed 17 misses only thirteen generic MiSTer `ascal` HDMI paths by at most 0.084 ns while decoder and video setup remain positive 0.986 and 3.164 ns; command-line seed 18 improves the global miss to 0.042 ns but is rejected.  At the user's instruction to stop after the current reseed and build, seed 19 is the final attempt and passes the complete gate with setup, hold, recovery, removal and minimum-pulse-width margins of positive 0.124, 0.231, 3.936, 0.541 and 0.925 ns; decoder and video setup are positive 0.462 and 2.378 ns.  The 4,461,996-byte timing-clean RBF has SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`; its 253,929-byte STA report has SHA-256 `b3fe3cd5f8b8a71dac42df1cfdf63387fd7fa4120713550a5caa789bf28c4b38`.  The prior `bc79d56a` RBF is preserved locally as `output_files/MediaPlayer-bc79d56a-known-good.rbf`.  No RBF is installed on the MiSTer, no further reseed or source cleanup is attempted, and the repository QSF remains at seed 17 because the user stops work after this seed-19 artifact.

#### Next Steps:

Stop after the completed seed-19 build as instructed.  Do not install the RBF, reseed again, edit shared MiSTer scaler RTL, remove stale SDC lines or change the QSF without a new user instruction.  When work resumes, decide explicitly whether to deploy the fully identified seed-19 `162c788d` artifact as built or first pin seed 19 in `MediaPlayer.qsf` and repeat a clean full build for source-controlled placement reproducibility.  The first hardware validation of this functional change should use the unchanged five-minute Coming to America program stream in Native 480i, verify the requested menu labels and both aspect/deinterlacer choices, and leave the known-good `bc79d56a` rollback intact; do not repeat Big Lebowski unless Coming succeeds and a control is materially needed.

#### Files Modified:

- MediaPlayer.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 758 COMMIT Unreleased 4e54e9d 2026-08-30T03:31:07-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Capture the completed five-minute Big Lebowski HDMI control and record the user's separate S/PDIF result on the unchanged timing-clean core.

#### Outcome:

The user authorizes capture after the complete HDMI run of `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` and explicitly reports that S/PDIF also works perfectly.  The 550,558-byte scaled capture `/tmp/entry758_big_lebowski_5min_hdmi_pass.png`, SHA-256 `fba8e5c8bb85fba397ea29883fa789e461592bf70edf685f4cb6fdab6466731e`, visibly preserves the clean intended final toilet scene without corruption.  The matching 7,647,957-byte helper log `/tmp/entry758_big_lebowski_5min_hdmi_pass.log`, SHA-256 `b5ab8d05ef08507b7688ac764aea6433549f3b93f5434b645cd686a9df2917c7`, names the exact five-minute file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, carries 244,700,748 video bytes with 616 timestamps, reaches helper EOF and exits zero after submitting all 306,800,752 in-band transport bytes with every byte on the fast path.  The native 720x480 capture `/tmp/entry758_big_lebowski_5min_hdmi_raw.png` is 381,718 bytes with SHA-256 `77b6f4d082444683401c38af7f75762f5dcd54c76b3d4ef645c558c98e30939b`.  Its checksum-valid schema-20 telemetry is an earlier sticky fatal snapshot rather than a terminal snapshot: at approximately 173 seconds it records exactly one PCM FIFO underrun, error flag `0x0400`, and freezes its counters at 151,212,826 accepted clean-video bytes even though the visible video and helper continue through the five-minute end.  Before that event it records no syntax, phase-one, prediction, inverse-quantization, IDCT, reconstruction, DDR store/cache, presentation, PCM-protocol or cache-overlap error and no transport block.  The user reports no audible HDMI defect, while the independent S/PDIF run is explicitly perfect, and explicitly accepts a single HDMI FIFO underrun for now.  This accepts the complete five-minute Big Lebowski video, HDMI and S/PDIF playback boundary; the one-count FIFO event remains documented without blocking the current video-compatibility work.  No source, RBF, helper, media or mode changes during either run or capture.

#### Next Steps:

Do not replay Big Lebowski solely to reconfirm video or audio.  Keep the explicitly accepted one-count HDMI FIFO-underrun observation separate from the proven Coming to America video admission defect and off the current critical path.  After user approval, implement entry 757's one-line `phase1_native_film_i_frame` correction and deterministic progressive-film field-DCT I/P regression, run the focused and existing regression sets, then perform a clean Quartus build and full timing analysis before any target deployment.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 757 COMMIT Unreleased 4e54e9d 2026-08-30T03:26:58-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Reproduce the Coming to America first-GOP failure offline, identify its exact decoder prerequisite, and propose the narrow production correction without changing the repository RTL or installed core.

#### Outcome:

The preserved 202,450,560-byte elementary video is cut only at authored picture boundaries and terminated with `sequence_end_code`: the exact first-I control is 71,636 bytes with SHA-256 `cb100a65df844a372376b30e4dcf0ef5b960fb1c4200300a35b6b0b4522e4914`, and the exact first-I/P reproducer is 91,436 bytes with SHA-256 `7530a3ce8a89ea29bf93188894a07c1e3f8af6958f4c48e87627b8c7f150b4a2`.  The unchanged RTL replay of the I/P prefix fails after exactly 73,774 accepted bytes, identical to hardware.  It has parsed all 45 macroblocks of P slice row 1 but enters the P raster with `reference_valid=0`, raising raster-engine source 9 and top-level phase-one source 2 before any P row or picture publishes.  This proves that neither dense slice syntax nor the P macroblock parser is the initiating defect.  The opening reference I picture has `progressive_sequence=0`, `progressive_frame=1`, `chroma_420_type=1` and `frame_pred_frame_dct=0`.  Although the existing I parser and raster already implement the resulting macroblock `dct_type`, `mpeg2_h262_frontend.sv` admits a progressive film I picture in an interlaced sequence only when `frame_pred_frame_dct=1`; consequently this legal reference I is skipped, and the following P picture exposes the missing reference.  This is consistent with project references H262-028, H262-032 and H262-033: an interlaced sequence may contain a progressive frame picture, `frame_pred_frame_dct=1` is a restriction to frame DCT/prediction rather than a validity requirement here, and 4:2:0 requires `chroma_420_type` to equal `progressive_frame`.  In an isolated build-PC worktree only, removing `frame_pred_frame_dct` from `phase1_native_film_i_frame` changes no parser, raster, prediction or presentation logic.  The same exact I/P prefix then accepts all 91,436 bytes, applies 1,565,007 cycles of decoder backpressure while the I reference completes, retires all 30 P rows, publishes two reference pictures, presents one swap and finishes with zero decoder, raster, writer or presentation errors.  The 2,248-byte baseline log `/tmp/entry757_baseline_first_ip.log` has SHA-256 `199716d784264291cd5ba707f90691e38a8e5e2dd421f060eaf7559e1281ca0a`; the 4,190-byte diagnostic-gate log `/tmp/entry757_gate_probe_first_ip.log` has SHA-256 `80a6390b02173d61bd1645726efa13b9595217d1a8d3d1cbb7ca1ac9b5841732`.  Production source, the installed RBF, helper, target files and target mode remain unchanged.

#### Next Steps:

After user approval, remove only the erroneous `frame_pred_frame_dct` conjunct from `phase1_native_film_i_frame`.  Add a deterministic, source-generated progressive-film field-DCT I/P regression that proves the I reference publishes before P-row execution, then run it alongside the existing progressive-film frame-DCT control, interlaced field-DCT, P/B field-motion plus field-DCT, cadence, reference-overlap and presentation regressions.  If those pass, commit the RTL and regression change, perform one clean Quartus build plus full timing analysis on the build PC, install the timing-passing RBF with rollback preserved, and hardware-test the unchanged Coming to America five-minute file followed by a Big Lebowski control.  Do not deploy the temporary diagnostic worktree or ask the user to replay either file before a timing-clean production build exists.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 756 COMMIT Unreleased 4e54e9d 2026-08-30T03:16:42-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Extend corrected-core hardware validation to two five-minute commercial-DVD feature openings in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` from beginning to end and reports that it works perfectly, accepting five continuous minutes of video, cadence, HDMI AC-3 decode and A/V synchronization on the exact installed `bc79d56a` candidate.  The user then plays `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg`, reports failure at launch and leaves the exact run untouched for collection.  The valid helper log names that file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, and shows no helper launch, container-recognition or audio-routing failure.  The 25,318-byte scaled screenshot `/tmp/entry756_coming_to_america_5min_run.png`, SHA-256 `4fc4d3fcc3b8206f7780705652446419fed7173468f13a93eeddb83ee07da0ba`, preserves the black no-picture result; its matching 601,366-byte helper log has SHA-256 `8a16db2b3f6d6a298559f309ad14e8e533e6ee641bd884197477884c429b3782`.  A separate raw 9,313-byte telemetry screenshot `/tmp/entry756_coming_to_america_5min_run_unscaled.png`, SHA-256 `db61b053496660d3bccb1f9a13a07b4ac274053690d53272cc9b3b2d7d370d68`, decodes with a valid schema-20 checksum: only 73,774 clean-video bytes are accepted, zero reference, B or display pictures complete, first and last presentation cycles remain zero, sequence end and quiet state are false, and snapshot reason is fatal/no-progress.  The sole hardware error is `0x0002`, `phase1_probe_error`; metadata shows the decoder has entered P temporal reference 2 before stopping.  There is no audio underrun, PCM protocol error, presentation error, cache overlap error, transport block or timestamp conflict.  Exact H.262 inventory explains why the earlier approximately twelve-second excerpt can pass while this feature opening fails.  The passed excerpt begins with true interlaced pictures (`progressive_frame=0`, `frame_pred_frame_dct=0`), while the passed Big Lebowski opening begins with progressive pictures that disable interlaced macroblock tools (`progressive_frame=1`, `frame_pred_frame_dct=1`).  This failing opening begins with progressive pictures that admit interlaced DCT and motion syntax (`progressive_frame=1`, `frame_pred_frame_dct=0`); its dense first I picture has 30 slices with maximum 2,400-byte payload, followed immediately by the failing P temporal reference 2 with 30 slices and maximum 2,112-byte payload.  The evidence therefore establishes a new first-GOP phase-one boundary in the progressive-frame/interlaced-tool combination or its dense first-P syntax; it does not reopen the corrected negative-odd field-motion result and does not implicate the program-stream or AC-3 launch path.  Two earlier collections made while the user was viewing other content are explicitly excluded from evidence.  No source, RBF, Main, helper, playback mode or installed media changes during this result.

#### Next Steps:

Preserve the exact failing program stream and installed RBF.  Before changing production source, extract a byte-exact elementary prefix through the first failing P picture and reproduce the `phase1_probe_error` offline with the existing detailed source/detail observability.  Compare an exact first-I-only control, the failing first-I/P prefix, the passed twelve-second excerpt and the passed Big Lebowski opening to separate progressive-frame plus interlaced-tool admission from slice-density or a specific macroblock mode.  Propose the narrow correction and its focused regression expansion for user approval before editing RTL or building another RBF; do not request another hardware replay of the unchanged failing file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 755 COMMIT Unreleased 4e54e9d 2026-08-30T03:02:28-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected DVD opening over HDMI and S/PDIF in Native 480i, then prepare the requested five-minute feature tests.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/dvd_opening_original.mpg` on the exact installed `bc79d56a` candidate in Native 480i and reports that video and audio are both perfect over HDMI and S/PDIF.  At the user's explicit request, `/tmp/entry755_dvd_opening_hdmi_spdif_native480i_pass.png` captures the clean completed Universal frame at 432,337 bytes with SHA-256 `29e524999c6a26dbd437b07a8a5a13e56f6a72fb47996d43ef0de4ac74ce9a8d`.  This accepts the known DVD program-stream and AC-3 boundary on the corrected core without changing the RBF, Main, helper or Native 480i mode.  The user next requests five minutes each of The Big Lebowski and Coming to America.  FFmpeg's DVD-video demuxer auto-selects the confirmed 7,036.1-second Big Lebowski feature from `/home/vash/Videos/the_big_lebowski.iso` and the confirmed 6,737.667-second Coming to America feature from `/home/vash/Videos/Coming Toamerica Ac/VIDEO_TS`; each first-five-minute excerpt is remuxed by stream copy to an MPEG-2 VOB/program stream with its original 720x480 MPEG-2 video and six-channel AC-3 audio.  The resulting Big Lebowski file is 264,787,968 bytes, 300.149833 seconds and SHA-256 `8fe852c10630d989448e3fb6afedf9e48d82a255c58c02815be06ff0ca494afe`; the Coming to America file is 222,027,776 bytes, 300.099789 seconds and SHA-256 `687bd2ebb757d4b34faf0f531e1f2ddb4c4e4747b1f33cd1da9aeb05b646d4cc`.  Complete software video/audio decode exits zero for both.  Authenticated absolute FTP installs the two previously absent filenames shown below, and independent downloads compare byte-for-byte with their staged sources.  The user reports independently backing up and deleting every other file in `/media/fat/games/MediaPlayer`; treat that cleanup as intentional and do not restore removed media.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Select HDMI audio and play `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` once from beginning to end.  Report whether video motion and cadence remain clean for the full five minutes, whether audio remains clean and synchronized, and whether playback returns normally at the end.  Test `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` only after recording the first result so any failure remains attributable to one title.

#### Files Modified:

- /media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg
- /media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg

#### Status:

- [x] Built
- [x] Passed

---

## 754 COMMIT Unreleased 4e54e9d 2026-08-30T02:51:05-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected original authored I/P/B stream in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` from beginning to end in Native 480i and reports that it looks and runs perfectly, with no large block corruption, freeze or stutter.  This is the original 6,751,008-byte authored elementary stream containing all 361 pictures, comprising 27 I, 115 P and 219 B pictures over its normal approximately twelve-second presentation.  It therefore extends the accepted exact P81 and B-stripped I/P results through the complete forward- and bidirectionally-predicted hardware path at normal coded duration.  At the user's explicit request, `/tmp/entry754_authored_ipb_native480i_pass.png` captures the clean terminal frame at 533,067 bytes with SHA-256 `13a9d27889ebf0ded78b4f44abcace0cbbfb205687fe29d74ea9f67de1597f15`.  No RBF, media, Main, helper or configuration change occurs.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Select HDMI audio and play `/media/fat/games/MediaPlayer/dvd_opening_original.mpg` once from beginning to end, then report whether video, cadence and audio are all clean.  This checks the known DVD program-stream transport and audio integration boundary on the corrected core without changing playback mode or requesting another elementary-video diagnostic.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 753 COMMIT Unreleased 4e54e9d 2026-08-30T02:48:43-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected full authored I/P reference chain in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` from beginning to end in Native 480i and reports that it looks perfect with no large block corruption.  Its fast run is expected: the byte-exact diagnostic retains 27 I and 115 P pictures but removes all 219 B pictures, so its 142 coded pictures present in about 4.7 seconds at 30000/1001 rather than the original twelve-second duration.  This is fixture construction, not a decoder cadence failure.  At the user's explicit request, `/tmp/entry753_authored_ip_native480i_pass.png` captures the clean terminal frame at 532,998 bytes with SHA-256 `6761b2b91538abccc26827c966813d6fbf855f66fd5801701f8cb6cb97597fa4`.  Together with the exact P81 acceptance, this clears the corrected forward-predicted reference chain through the complete authored I/P derivative.  No RBF, media, Main, helper or configuration change occurs.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` once from beginning to end and report whether it runs for its normal approximately twelve seconds without large block corruption, freeze or stutter.  This restores the original 219 B pictures and is the next full authored I/P/B hardware gate; the elementary video stream contains no audio.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 752 COMMIT Unreleased 4e54e9d 2026-08-30T02:45:48-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected P81 hardware frame in Native 480i and make that the sole product video mode.

#### Outcome:

Absolute FTP readback proves `/media/fat/MediaPlayer_20260829_b9c2657.rbf` already contains the exact timing-passing 4,456,984-byte candidate with SHA-256 `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837`, while the verified rollback `/media/fat/_MediaPlayer_Backups/MediaPlayer_20260829_8fd16e8_pre_7a25189_677f2e11.rbf` retains the prior 4,471,792-byte `677f2e11` build.  No redundant write is performed.  The user reloads the corrected core, plays the exact P81 checkpoint in Native 480i and reports that the thin horizontal corruption crossing the right-hand subject's mouth is gone.  At the user's explicit request, `/tmp/entry752_p81_native480i_pass.png` captures the clean held frame at 490,336 bytes with SHA-256 `c31737d705a4915af0afe62c79c327ae76bccbc563d3f14348cc865204f69df2`.  This hardware result accepts the negative-odd field-motion predictor correction at the exact first-failure boundary.  The user also confirms that development and the final product use Native 480i only; the `800x600 Diagnostic` scaler mode has no product purpose and must not be requested in future tests.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` once from beginning to end and report whether any large block corruption remains during or after the shiny-hat passage.  This extends the accepted P81 boundary through the longer authored I/P reference chain; do not use or request diagnostic mode.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 751 COMMIT Unreleased 4e54e9d 2026-08-30T02:38:19-07:00

#### Coming From:

Unreleased 7a25189

#### Purpose:

Qualify the cleaned field-motion correction with the known timing-clean placement and prepare its corrected RBF for hardware test.

#### Outcome:

Following repository cleanup at `9aeabac`, source `4e54e9d` pins build ID `260829`, the last timing-clean placement input, without changing decoder RTL.  A checksum-only comparison proves the complete functional local source identical to the clean build-PC tree except for later `.ai` metadata and generated build files.  Quartus Prime 17.0.2 completes successfully at 34,094 of 41,910 ALMs, 52,524 registers, 4,181,443 memory bits in 532 RAM blocks and 67 DSP blocks.  Full timing has zero negative slack and zero setup TNS: HDMI setup is positive 0.055 ns, decoder setup is positive 0.454 ns, video setup is positive 2.346 ns, and worst-case hold, recovery, removal and minimum-pulse-width margins are positive 0.243, 3.376, 0.526 and 0.925 ns.  Fresh isolated reruns of P field motion, bidirectional B field motion, combined field motion plus field-DCT, interlaced P/B field-DCT residuals and the progressive mixed-raster control check 4,052,736 reconstructed samples within their established exact or two-level bounds with zero decoder, raster, writer or presentation errors.  Film cadence, all reference-overlap and reorder cases, timestamps, native field order and all four TFF/BFF repeated-field cache cases also pass.  The resulting 4,456,984-byte `output_files/MediaPlayer.rbf` has SHA-256 `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837`; it is not installed on the MiSTer.

#### Next Steps:

Preserve this exact RBF and do not rebuild or reseed it.  After a separate installation authorization, back up the currently installed core, deploy this candidate with exact readback, reload it, and play the existing byte-exact P81 checkpoint in `800x600 Diagnostic` with Weave.  Inspect the held frame for the mouth-level horizontal corruption; if it is absent, continue with a longer authored I/P stream to confirm that later reference propagation is also corrected.

#### Files Modified:

- tools/build.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 750 COMMIT Unreleased 7a25189 2026-08-30T02:38:18-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Correct negative odd vertical field-motion predictor division in the production P and B decoders.

#### Outcome:

The exact byte-verified P81 production replay first reaches the user's mouth-level corruption with a maximum sample error of 124 and traces the predictive chain back to field-motion reference addressing rather than inverse quantization, IDCT, residual addition or saturation.  The P and B parsers stored vertical predictors in frame units but converted them to field units with truncation toward zero; H.262 `DIV` instead rounds toward minus infinity, so each negative odd predictor selected a reference row one field sample too low and the error propagated through later P references.  Source `1fbe21a` replaces both conversions with signed arithmetic right shifts, and `7a25189` corrects the associated B-path comment without functional change.  Replaying the exact 942,600-byte P81 fixture after the correction accepts all 44 pictures and 43 swaps with every lifecycle error clear, checks all 19,180,800 predictive samples with zero mismatches above the established one-level transform tolerance, reduces maximum P/P81 error to one and produces an empty high-delta P81 trace.  The remaining harness nonzero exit is confined to two earlier independent intra-IDCT comparisons with established maxima of four and seventeen and is not part of the predictive corruption.  The exact P80 and P81 fixture hashes remain `ae8e43eb` and `37fa9030`.

#### Next Steps:

Retain the arithmetic correction and its exact P81 evidence, keep the cleaned repository structure, and close timing without changing decoder behavior.  Require the focused interlaced P/B field-motion and field-DCT regressions, the progressive control and the broader presentation suite to remain within their established bounds before preparing any RBF for the user.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 749 COMMIT Unreleased 6196869 2026-08-29T20:50:07-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Authorize an exact offline production-path replay and bounded correction for the first P81 mouth-level corruption.

#### Outcome:

The user explicitly authorizes the entry-748 next step.  Use the byte-verified P81-ending authored I/P checkpoint, its clean consecutive P80 predecessor and independently decoded FFmpeg YUV 4:2:0 pixels.  First adapt or invoke the existing full-frame production-path harness to reproduce P81 without changing decode RTL, locate the first differing component and coordinate, and correlate it with the exact owning macroblock syntax and reconstruction arithmetic.  Only after a deterministic mismatch exists may source change, and any correction must remain bounded to its proven cause, add exact P80/P81 regression coverage, preserve the existing interlaced P/B field-motion and field-DCT regressions, and avoid Quartus until simulation is pixel-exact.  No source, FPGA, RBF, Main, helper, installed media or configuration change occurs in this authorization entry.

#### Next Steps:

Run the exact P81 production-path replay with a software oracle and machine-readable pixel report.  Establish the first mismatch before editing RTL, then inspect the associated prediction, residual, inverse-quantization, IDCT and saturation values.  Implement only the correction justified by that trace and run the exact P80/P81 gate plus the focused and broader decoder regressions.  Record source and test outcomes in new entries; do not start Quartus or request another MiSTer test in this cycle.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 748 COMMIT Unreleased 6196869 2026-08-29T20:47:36-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record the user's exact spatial localization of the first P81 corruption.

#### Outcome:

While the captured P81 terminal frame remains displayed, the user identifies the first corruption precisely as the thin horizontal line crossing the mouth of the man on the right.  This is the onset within P81, not merely a later consequence elsewhere in the frame.  The location is visible in the preserved `/tmp/entry747_p81_first_corrupt.png` evidence and replaces the broader earlier description of a central disturbance.  Combined with clean P80 and the exact byte-preserved P81 checkpoint, this provides both temporal and spatial bounds for offline comparison: the first affected authored picture is P81 and its first visible damaged region is the right-hand subject's mouth-level horizontal strip.  The clean schema-20 lifecycle and zero fault counters from entry 747 remain unchanged.  No new capture, source, FPGA, RBF, Main, helper, installed media or configuration change occurs.

#### Next Steps:

Do not request another hardware checkpoint.  Replay exact P81 after its clean P80 reference in the production-path RTL simulation and compare against the software oracle, prioritizing the mouth-level macroblock row and finding the first differing luma or chroma sample within that row.  Correlate the first mismatch with the owning macroblock's prediction mode, vectors, quantiser scale, coded-block pattern, DCT type, coefficient values and reconstruction saturation.  Require a bounded reproduction and pixel-exact regression before any RTL correction or Quartus build; the next user test should be a corrected RBF only after those gates pass.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 747 COMMIT Unreleased 6196869 2026-08-29T20:46:34-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept and preserve the exact first corrupted authored P picture at P81.

#### Outcome:

The user performs the requested consecutive comparison and reports P80 clean and P81 as the first picture where corruption begins, then leaves P81 displayed for capture.  The 382,785-byte screenshot `/tmp/entry747_p81_first_corrupt.png`, SHA-256 `80e3310aabae0571b087b7703f7452c6b829556b5f06fe849aa5efe0e6b04e75`, visibly preserves the first central horizontal disturbance in the shiny-hat passage.  Its checksum-valid schema-20 snapshot accepts all 942,600 bytes, displays all 44 retained reference pictures across 43 swaps, ends on P temporal reference 8, sees sequence end and presentation completion, reaches quiet state and drains the scheduler.  The 1.7376-second presentation reports zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  Because P80 and P81 are consecutive byte-exact authored P units in the same I/P-only reference chain, this establishes an exact hardware boundary with no intervening B picture, GOP or sequence transition: P80 is clean and P81 is the first affected reconstruction.  Later P82 through P115 progressively amplify the damage.  No source, FPGA, RBF, Main, helper, installed media or configuration changes during capture.

#### Next Steps:

Stop hardware checkpoint playback.  Use the exact P81-ending stream and clean P80 predecessor for an offline production-path RTL replay against a software oracle, requiring localization of the first differing macroblock, block and component before changing RTL.  Correlate that location with P81 motion vectors, quantiser changes, coded-block pattern, DCT type, coefficient magnitude and saturation behavior, specifically testing the user's observation that a bright highlight appears to poison the remainder of a block.  The next MiSTer test should occur only after a bounded source correction passes the exact P80/P81 pixel regression; do not rebuild Quartus merely to gather more evidence.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 746 COMMIT Unreleased 6196869 2026-08-29T20:45:04-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Complete the user's requested consecutive P80, P81, P82 and P83 terminal-frame comparison set.

#### Outcome:

The user explicitly requests comparison of P80, P81, P82 and P83.  P80 and P82 were already installed and independently verified.  Using unchanged source `6196869` and the exact original authored stream, generate the two missing endpoints.  P81 ends on byte-identical zero-based source P81, removes 38 complete B units and preserves 7 I plus 37 P units unchanged; its 942,600 bytes have SHA-256 `37fa9030c1d209e7c13721b6f4a1dbf28b793f8aebc3d163fc268c824cd417a0`.  P83 ends on byte-identical source P83, removes the same 38 B units and preserves 7 I plus 39 P units unchanged; its 1,024,516 bytes have SHA-256 `fe97fed338493e668e4de2553322af25f991ca08067823fd2bd9420127da7b00`.  Independent FFprobe enumeration confirms respectively 44 and 46 720x480 pictures at 30000/1001 with no B picture; both end with the required single `00 00 01 b7` sequence-end code and complete full FFmpeg software decode without error.  Absolute FTP inventory proves both new names absent; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p81_checkpoint.m2v` and `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p83_checkpoint.m2v`, followed by independent absolute-path FTP readback, reproduces each exact byte count, SHA-256 and terminal sequence end.  The MiSTer now holds the complete verified consecutive P80-through-P83 comparison set.  No source, FPGA, RBF, Main, helper, existing media or configuration changes.

#### Next Steps:

In `800x600 Diagnostic` with Weave selected, play the four checkpoints in exact order P80, P81, P82 and P83, inspecting each stable terminal frame for the first faint strip or flicker.  Report each one as clean or affected.  This direct consecutive comparison identifies the first corrupted authored P picture and the next-frame propagation without inference from motion during a longer run.  Do not capture telemetry unless the user leaves a newly identified boundary frame displayed, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 745 COMMIT Unreleased 6196869 2026-08-29T20:43:05-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the P82 and P84 boundary results, preserve the held P82 evidence and authorize exact adjacent P81/P83 checkpoints.

#### Outcome:

The user leaves P82 displayed and describes it as almost at the corruption boundary, then reports that P84 is visibly worse in the same progressive manner as later checkpoints.  The 388,216-byte screenshot `/tmp/entry745_p82_checkpoint_boundary.png`, SHA-256 `ccdfaf191b7e0f715e047eb399d13f670c0fad860a891b76897bc783671c7304`, preserves the subtle P82 terminal frame; its small central disturbances are too close to the separate long-standing fine-line artifact for the screenshot alone to classify confidently, so the user's live boundary observation remains controlling.  Its checksum-valid schema-20 snapshot accepts all 983,588 bytes, displays all 45 retained reference pictures across 44 swaps, ends on P temporal reference 9, sees sequence end and presentation completion, reaches quiet state and drains the scheduler.  The 1.7961-second presentation reports zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  Clean P80, boundary P82, worse P84 and first clear strip by P85 demonstrate progressive corruption within the consecutive authored P chain.  Choose exact adjacent retained endpoints P81 and P83 to resolve the first affected picture and document its immediate growth.  No source, FPGA, RBF, Main, helper, installed media or configuration changes during capture.

#### Next Steps:

Using unchanged source `6196869`, generate byte-exact I/P checkpoints ending separately at zero-based coded P81 and P83.  Preserve every retained unit, remove only complete B units, append one terminal sequence-end code, prove exact terminal-picture identity and clean full software decode, then install under distinct absolute MiSTer paths with exact FTP readback.  The user should play P81 first and P83 second in `800x600 Diagnostic` with Weave, reporting even a barely visible strip or flicker.  With clean P80, P81 determines whether onset is P81 or P82, while P83 records the first step of propagation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 744 COMMIT Unreleased 6196869 2026-08-29T20:40:52-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the final onset-search checkpoints ending at P82 and P84.

#### Outcome:

Using unchanged source `6196869` and the exact original authored stream, generate the authorized pair.  The P82 stream ends on byte-identical zero-based source P82, removes 38 complete B units and preserves 7 I plus 38 P units unchanged; its 983,588 bytes have SHA-256 `04cbfe0fef0d2aa10dcf260daf7c2ef848b2c13012e1e42be87e2757dee58927`.  The P84 stream ends on byte-identical source P84, removes the same 38 B units and preserves 7 I plus 40 P units unchanged; its 1,075,936 bytes have SHA-256 `f905bd22168353dd78300d3431e14d4c2289944284d77cedca41ae0dd2d5f24c`.  Independent FFprobe enumeration confirms respectively 45 and 47 720x480 pictures at 30000/1001 with no B picture; both end with the required single `00 00 01 b7` sequence-end code and complete full FFmpeg software decode without error.  Absolute FTP inventory proves both new names absent; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p82_checkpoint.m2v` and `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p84_checkpoint.m2v`, followed by independent absolute-path FTP readback, reproduces each exact byte count, SHA-256 and terminal sequence end.  No source, FPGA, RBF, Main, helper, existing media or configuration changes.

#### Next Steps:

In `800x600 Diagnostic` with Weave selected, play P82 first and watch for even one faint horizontal strip or flicker in its live passage and stable terminal frame; then play P84 and make the same observation.  Report `P82 clean` or `P82 flicker`, followed by `P84 clean` or `P84 flicker`.  Combined with clean P80 and affected P85, these results identify the first affected authored P picture.  Do not capture telemetry unless the user explicitly leaves a failure displayed for evidence, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 743 COMMIT Unreleased 6196869 2026-08-29T20:38:36-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the P85 and I88 hardware results, preserve the held P85 evidence and authorize the final two-picture onset search.

#### Outcome:

The user reports that P85 shows the first faint strip-like flicker, estimates that onset may be two or three frames earlier, and reports greater distortion by I88.  The user leaves P85 displayed for capture.  The 401,809-byte screenshot `/tmp/entry743_p85_checkpoint_first_flicker.png`, SHA-256 `d6478d2d0d770642a96a263e9af4370ead986a2a32cd5356221c4f486209bcd1`, preserves the subtle terminal P85 evidence in the shiny-hat passage.  Its checksum-valid schema-20 snapshot accepts all 1,105,168 bytes, displays all 48 retained reference pictures across 47 swaps, ends on P temporal reference 14, sees sequence end and presentation completion, reaches quiet state and drains the scheduler.  The 1.9249-second presentation reports zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  With P80 previously clean and P85 now the first clearly reported flicker, the onset is within the consecutive retained P80-through-P85 chain; the stronger I88 result shows that damage is already present before the new GOP reference rather than beginning at P91.  Choose P82 and P84 as the two most informative retained endpoints.  No source, FPGA, RBF, Main, helper, installed media or configuration changes during capture.

#### Next Steps:

Using unchanged source `6196869`, generate byte-exact I/P checkpoints ending separately at zero-based coded P82 and P84.  Preserve every retained unit, remove only complete B units, append one terminal sequence-end code, prove exact terminal-picture identity and clean full software decode, then install under distinct absolute MiSTer paths with exact FTP readback.  The user should play P82 first and P84 second in `800x600 Diagnostic` with Weave and report even a single faint strip or flicker separately.  Together with clean P80 and corrupt P85, those two results identify the first affected P picture without an FPGA change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 742 COMMIT Unreleased 6196869 2026-08-29T20:35:17-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the GOP-boundary checkpoints ending at P85 and I88.

#### Outcome:

Using unchanged source `6196869` and the exact original authored stream, generate the authorized pair.  The P85 stream ends on byte-identical zero-based source P85, removes 38 complete B units and preserves 7 I plus 41 P units unchanged; its 1,105,168 bytes have SHA-256 `d31c51a5c94df9bee1025f3acf510c60f05872274f6af5815a4c3bd717bff369`.  The I88 stream ends on byte-identical source I88 after removing 40 complete B units and preserves 8 I plus 41 P units unchanged; its 1,153,180 bytes have SHA-256 `efb95578db11f2dabb6b8d174bbd7e3e02f2cc184d8045ee96f1b8eeb00eee6f`.  Independent FFprobe enumeration confirms respectively 48 and 49 720x480 pictures at 30000/1001 with no B picture; both end with the required single `00 00 01 b7` sequence-end code and complete full FFmpeg software decode without error.  Absolute FTP inventory proves both new names absent; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p85_checkpoint.m2v` and `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_i88_checkpoint.m2v`, followed by independent absolute-path FTP readback, reproduces each exact byte count, SHA-256 and terminal sequence end.  No source, FPGA, RBF, Main, helper, existing media or configuration changes.

#### Next Steps:

In `800x600 Diagnostic` with Weave selected, play P85 first and inspect its stable terminal frame for the central corruption seen at P91; then play I88 and inspect its stable terminal frame separately.  Report `P85 clean` or `P85 corrupt`, followed by `I88 clean` or `I88 corrupt`.  If both are clean, the first corrupted retained frame is exactly P91, the first P picture dependent on I88.  Do not capture telemetry unless the user explicitly requests it, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 741 COMMIT Unreleased 6196869 2026-08-29T20:33:13-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept corrupt P91 and P97 hardware results, preserve the held P91 evidence and choose the next exact GOP-boundary checkpoints.

#### Outcome:

The user reports that visible corruption begins in the middle of the P91 screen and that P97 develops more distortion later, then explicitly leaves P91 displayed for capture.  The 382,659-byte screenshot `/tmp/entry741_p91_checkpoint_corrupt.png`, SHA-256 `ed2834357328cbccf311af3825346e2b733c49ff8cd6d13b6767d4579ffa38df`, visibly records the central horizontal corrupted region across the otherwise recognizable shiny-hat scene.  Its checksum-valid schema-20 snapshot accepts all 1,179,288 bytes, displays all 50 retained reference pictures across 49 swaps, ends on P temporal reference 5, sees sequence end and presentation completion, reaches quiet state and drains the scheduler.  The 2.0250-second presentation reports zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  Thus the corruption is reconstructed pixel content despite an internally clean lifecycle.  Exact coded order around the boundary is P80 through P85, B86 and B87, I88, B89 and B90, then corrupt P91.  P91 is therefore the first retained P after the new I88 reference; P85 and I88 are the highest-value next endpoints for separating corruption inherited before the GOP reset from corruption introduced by that I reference or its first dependent P.  No source, FPGA, RBF, Main, helper, installed media or configuration changes during capture.

#### Next Steps:

Using unchanged source `6196869`, generate byte-exact I/P checkpoints ending separately at zero-based coded P85 and I88.  Preserve every retained unit, remove only complete B units, append one terminal sequence-end code, prove exact terminal-picture identity and clean full software decode, then install under distinct absolute MiSTer paths with exact FTP readback.  The user should play P85 first and I88 second in `800x600 Diagnostic` with Weave.  If both are clean while P91 is corrupt, the onset is exactly the first P dependent on clean I88; if I88 is already corrupt, investigate the new intra reference.  Do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 740 COMMIT Unreleased 6196869 2026-08-29T20:30:00-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the two finer authored I/P checkpoints ending at P91 and P97.

#### Outcome:

Using unchanged source `6196869` and the exact original authored stream, generate the authorized two-file batch.  The P91 stream ends on byte-identical zero-based source P91, removes 42 complete B units and preserves 8 I plus 42 P units unchanged; its 1,179,288 bytes have SHA-256 `80faae0bc0ef0bf3ba0b932fb1de6e0cf35368a108fc27bb55477019515b7add`.  The P97 stream ends on byte-identical source P97, removes 46 complete B units and preserves 8 I plus 44 P units unchanged; its 1,230,916 bytes have SHA-256 `40bc0591eb7b8a1581d51bf47fea92184b5c1aea14303f477f5e73521c15ca44`.  Independent FFprobe enumeration confirms respectively 50 and 52 720x480 pictures at 30000/1001, each with no B picture; both end with the required single `00 00 01 b7` sequence-end code and complete full FFmpeg software decode without error.  Absolute FTP inventory proves both new names absent; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p91_checkpoint.m2v` and `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p97_checkpoint.m2v`, followed by independent absolute-path FTP readback, reproduces each exact byte count, SHA-256 and terminal sequence end.  No source, FPGA, RBF, Main, helper, existing media or configuration changes.

#### Next Steps:

In `800x600 Diagnostic` with Weave selected, play P91 first and inspect both the live passage and stable terminal framebuffer for block corruption, especially whether a bright highlight poisons the rest of its block.  Then play P97 and make the same observation.  Report `P91 clean` or `P91 corrupt`, followed by `P97 clean` or `P97 corrupt`; this will narrow the onset within the clean-P80 to corrupt-P100 interval.  Do not capture telemetry unless the user explicitly requests it, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 739 COMMIT Unreleased 6196869 2026-08-29T20:28:15-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the corrupt P115 result and authorize two finer authored I/P checkpoints between clean P80 and corrupt P100.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p115_checkpoint.m2v` after the corrupt P100 test and reports greater block distortion around the shiny-hat passage.  The corruption therefore persists and worsens beyond P100 rather than belonging only to the P100 terminal frame.  The user specifically observes that the extremely bright highlight appears to corrupt the remainder of its block, as though that reconstruction path is overloaded.  Treat that as a visual clue toward coefficient, reconstruction-arithmetic or clipping behavior, not yet as a proven cause.  Together with clean P80, the hardware boundary remains after P80 and no later than P100.  Source coded ordinals 90 and 95 are B pictures and cannot terminate the byte-exact I/P fixture; choose retained P ordinals 91 and 97 as the two useful finer checkpoints.  No telemetry is requested or collected, and no source, FPGA, RBF, Main, helper, media or configuration changes occur while accepting the result.

#### Next Steps:

Using unchanged source `6196869`, generate byte-exact I/P checkpoints ending separately at zero-based coded P91 and P97.  For each, preserve every retained I/P unit, remove only complete B units, append one terminal sequence-end code, prove exact terminal-picture identity and clean full software decode, then install under distinct new absolute MiSTer paths with exact FTP readback.  The user should play P91 first and P97 second in `800x600 Diagnostic` with Weave and report each as clean or corrupt, noting whether a bright point poisons the rest of its block.  Do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 738 COMMIT Unreleased 6196869 2026-08-29T20:25:19-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record the first hardware result from the two-file P100/P115 checkpoint batch and direct the second test.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p100_checkpoint.m2v` in the requested diagnostic configuration and reports that it fails: large block distortion is visible at P100, with a smaller distortion event also visible shortly before the terminal frame.  Combined with the accepted clean P80 result, this brackets the first observed authored I/P corruption to after P80 and no later than P100.  Because P100 contains the exact retained authored I/P prefix and independently software-decodes cleanly, the result remains evidence against malformed checkpoint construction.  P115 remains installed and untested.  No telemetry is requested or collected, and no source, FPGA, RBF, Main, helper, media or configuration changes are made.

#### Next Steps:

Play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p115_checkpoint.m2v` next in `800x600 Diagnostic` with Weave selected and report whether its stable terminal framebuffer is clean or corrupt.  This distinguishes corruption that persists beyond P100 from a transient event before choosing finer checkpoints between P80 and P100.  Do not capture telemetry unless the user explicitly requests it, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 737 COMMIT Unreleased 6196869 2026-08-29T20:23:51-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the two requested later authored I/P checkpoints ending at P100 and P115.

#### Outcome:

Using unchanged checkpoint source `6196869` and the exact original authored stream, generate the requested two-file batch.  The P100 stream ends on the byte-identical zero-based source P100, removes 48 complete B units, preserves 8 I plus 45 P units unchanged and contains exactly 53 720x480 TFF interlaced pictures at 30000/1001; its 1,255,936 bytes have SHA-256 `69d9c388a77f5afed5bbe10f8b4a9e5ba97426e1172720a5e31075c47462f9f4`.  The P115 stream ends on the byte-identical source P115, removes 58 complete B units, preserves 9 I plus 49 P units unchanged and contains exactly 58 pictures with the same format; its 1,409,104 bytes have SHA-256 `f4062400df99d5795de14197cf711b9673a60171e5a63b1756cf653302e1a3e6`.  Each contains no B picture, ends with the required single `00 00 01 b7` sequence-end code and completes an independent full FFmpeg software decode without error.  Absolute FTP inventory first proves both filenames absent; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p100_checkpoint.m2v` and `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p115_checkpoint.m2v`, followed by independent absolute-path FTP readback, reproduces each exact byte count, SHA-256 and terminal sequence end.  No source, FPGA, RBF, Main, helper, existing media or configuration changes.

#### Next Steps:

In `800x600 Diagnostic` with Weave selected, play the P100 checkpoint first and inspect its stable terminal framebuffer for the remembered large block corruption; then play P115 and inspect its stable terminal framebuffer separately.  Report `P100 clean` or `P100 corrupt`, followed by `P115 clean` or `P115 corrupt`.  Do not capture telemetry unless the user explicitly requests it, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 736 COMMIT Unreleased 6196869 2026-08-29T20:20:41-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the clean P80 checkpoint and authorize a two-file jump to P100 and P115.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p80_checkpoint.m2v`, reports no large block distortion, leaves the terminal screen for capture, and requests two farther checkpoint files in the next batch.  The capture accepts all 896,496 bytes, displays all 43 pictures across 42 swaps, ends on P temporal reference 7, sees sequence end and presentation completion, reaches quiet state and fully drains the scheduler.  Its 1.6945-second presentation records zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  The 401,549-byte screenshot `/tmp/entry735_p80_checkpoint_completed.png`, SHA-256 `33ba7d64a4f0e5a442cab982a8c59a70af8c3d84c43f1c2e27e47382c58ab233`, shows exact stable bright-passage P80 without the large macroblock corruption; the separate narrow vertical-line artifact remains visible.  At the user's explicit batching request, choose P100 at the end of the next authored GOP and P115 at the end of the following GOP, materially advancing beyond P80 while keeping both endpoints on retained P pictures.  No source, installed media, RBF, Main, helper or configuration changes during capture.

#### Next Steps:

Using unchanged source `6196869`, generate byte-exact I/P checkpoints ending separately at zero-based coded P100 and P115.  For each, preserve every retained I/P unit, remove only complete B units, append one terminal sequence-end code, prove exact terminal-picture identity and clean software decode, and install under distinct new absolute filenames with exact FTP readback.  The user should then play both in order in `800x600 Diagnostic` with Weave and report large block corruption separately for the stable P100 and P115 terminal frames.  Do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 735 COMMIT Unreleased 6196869 2026-08-29T20:16:55-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the byte-exact authored I/P P80 checkpoint.

#### Outcome:

Using unchanged source `6196869` and the exact original authored stream, checkpoint mode ends immediately after zero-based coded P80, proves its terminal picture byte-identical to source P80, removes 38 complete B units from the retained prefix, and preserves 7 I plus 36 P units unchanged.  The resulting 896,496-byte stream has SHA-256 `ae8e43eb20d4f1260ef6c0ba933c66e0323a4995e8872bdc3222d33685adb4aa`; independent FFprobe enumeration confirms exactly 43 720x480 TFF interlaced pictures at 30000/1001 comprising 7 I and 36 P with no B or progressive picture, its tail is the single required `00 00 01 b7` sequence end, and a complete FFmpeg software decode exits without an error.  Independent software extraction of the terminal frame confirms P80 is a clean bright shiny-hat passage suitable for visible comparison.  Absolute FTP inventory proves the new filename absent, then installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p80_checkpoint.m2v` and independent absolute-path readback reproduce all 896,496 bytes, the exact `ae8e43eb` hash and terminal sequence end.  No source, existing media, FPGA, Main, helper or configuration changes.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p80_checkpoint.m2v` once and inspect the stable terminal framebuffer after its intentionally short live passage.  Report whether the held bright-passage P80 frame contains large block corruption.  If corrupt, search backward within P74 through P80; if clean, move later in the bright passage.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 734 COMMIT Unreleased 6196869 2026-08-29T20:15:15-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Prepare and install the byte-exact authored I/P checkpoint ending on P80.

#### Outcome:

The user explicitly authorizes the entry-733 jump to P80 after clean P66 and P69 prove the earlier dark fade is not where the remembered large distortion occurs.  Reuse unchanged source `6196869` and the exact original authored stream.  Generate an I/P prefix ending immediately after zero-based coded P80, remove only complete B units within the retained prefix, preserve every retained I and P unit byte-for-byte, append exactly one sequence-end code, and install it under a new absolute MiSTer filename.  Leave every existing fixture, FPGA, Main, helper and configuration unchanged.

#### Next Steps:

Require exact P80 termination, only 720x480 TFF interlaced I/P pictures, one terminal sequence end and a clean complete software decode.  Require independent absolute-path FTP readback equality after installation.  Then have the user play the intentionally short checkpoint once in `800x600 Diagnostic` with Weave and inspect the stable bright-passage P80 framebuffer for large block corruption.  If corrupt, search backward within P74 through P80; if clean, move later in the bright passage.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 733 COMMIT Unreleased 6196869 2026-08-29T20:13:51-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Move the next authored P checkpoint from P71 to the brighter P80 shiny-hat passage.

#### Outcome:

After clean P66 and P69 terminal checkpoints, the user says the observed large distortion likely occurred later in playback and asks to skip farther forward.  The request supersedes entry 732's proposed P71 checkpoint before any P71 media is generated or installed.  Static source order identifies I73 as the next independent clean reference followed by consecutive P74 through P84; P80 is the seventh P after that reset and lies in the brighter shiny-hat passage, making it a materially better visible checkpoint than continuing through the earlier dark fade one picture at a time.  Existing source, generated fixtures, FPGA, Main, helper and configuration remain unchanged.

#### Next Steps:

Use unchanged source `6196869` to generate and install a byte-exact I/P checkpoint ending at zero-based coded P80.  Preserve every retained I/P unit, remove only B units, append one terminal sequence-end code, verify exact P80 termination and clean software decode, and require absolute-path FTP readback equality.  The next hardware test should inspect the stable terminal P80 framebuffer for the large block distortion.  If P80 is corrupt, search backward within the P74 through P80 chain; if it is clean, move later in the bright passage.  Test-media generation and installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 732 COMMIT Unreleased 6196869 2026-08-29T20:12:18-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the clean P69 terminal checkpoint and advance the authored P-chain search to P71.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p69_checkpoint.m2v` and reports no large block distortion.  The requested terminal capture proves all 405,108 bytes are accepted, all 32 pictures display across 31 swaps, final picture type is P with temporal reference 9, sequence end and presentation completion are true, the session is quiet and the scheduler is fully drained.  The 1.1509-second presentation records zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  The 329,070-byte screenshot `/tmp/entry731_p69_checkpoint_completed.png`, SHA-256 `2a6e8b739feac7b60a4e7d164943234bcc1e427e2b4da2c9e92e8f26b0348e23`, shows the intended stable P69 fade-stage framebuffer without large macroblock corruption; the previously separated narrow vertical-line artifact remains visible and is not counted as the block defect.  Exact P66 and P69 are therefore clean, narrowing the first large authored P corruption to P70 through P72.  No source, installed media, RBF, Main, helper or configuration changes during capture.

#### Next Steps:

Use unchanged source `6196869` to generate and install a byte-exact I/P checkpoint ending at zero-based coded P71, the midpoint of the remaining P70 through P72 interval.  Preserve every retained I/P unit, remove only B units, append one terminal sequence-end code, verify exact P71 termination and clean software decode, and require absolute-path FTP readback equality.  The next hardware test should inspect the stable terminal P71 framebuffer.  Corruption narrows first onset to P70 or P71; a clean result isolates P72.  Test-media generation and installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 731 COMMIT Unreleased 6196869 2026-08-29T20:09:50-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record verified construction and installation of the byte-exact authored I/P P69 checkpoint.

#### Outcome:

Using unchanged source `6196869` and the exact 6,751,008-byte original authored stream, checkpoint mode ends immediately after zero-based coded P69, proves its terminal picture byte-identical to the source, removes 38 complete B units from the retained prefix, and preserves 6 I plus 26 P units unchanged.  The resulting 405,108-byte stream has SHA-256 `cca9041bfc8274c29b04c286dca8de07618d24f0c13827d19c8c63d2b546672a`; independent FFprobe enumeration confirms exactly 32 720x480 TFF interlaced pictures at 30000/1001 comprising 6 I and 26 P with no B or progressive picture, its tail is the single required `00 00 01 b7` sequence end, and a complete FFmpeg software decode exits without an error.  Absolute FTP inventory proves the new filename absent, then installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p69_checkpoint.m2v` and independent absolute-path readback reproduce all 405,108 bytes, the exact `cca9041b` hash and terminal sequence end.  No source, existing media, FPGA, Main, helper or configuration changes.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p69_checkpoint.m2v` once and inspect the stable terminal framebuffer after its intentionally short live passage.  Report whether the held P69 frame contains large block corruption.  Corruption narrows onset to P67 through P69; a clean result narrows it to P70 through P72.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 730 COMMIT Unreleased 6196869 2026-08-29T20:08:11-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Prepare and install the byte-exact authored I/P checkpoint ending on P69.

#### Outcome:

The user explicitly authorizes the entry-729 P69 checkpoint after exact P66 completes cleanly.  Reuse source `6196869` and the exact original authored stream without modifying either.  Generate an I/P prefix ending immediately after zero-based coded P69, remove only complete B units within that retained prefix, preserve every retained I and P unit byte-for-byte, append exactly one sequence-end code, and install it under a new absolute MiSTer filename.  Leave every existing fixture, FPGA, Main, helper and configuration unchanged.

#### Next Steps:

Require the tool to prove exact P69 termination, enumerate only 720x480 TFF interlaced I/P pictures, retain one terminal sequence end and decode completely in software.  Require independent absolute-path FTP readback equality after installation.  Then have the user play the intentionally short checkpoint once in `800x600 Diagnostic` with Weave and inspect its stable terminal P69 framebuffer for large block corruption; corruption narrows onset to P67 through P69, while a clean result narrows it to P70 through P72.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 729 COMMIT Unreleased 6196869 2026-08-29T20:06:15-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Accept the clean P66 terminal checkpoint and advance the bounded authored P-chain search to P69.

#### Outcome:

The user initially reports that the P66 checkpoint ends early, then confirms no visible block corruption.  The short playback is intentional rather than a failure: the fixture contains only the 29 retained I/P pictures required to reach P66, and the requested terminal capture proves all 273,704 bytes are accepted, all 29 pictures display across 28 swaps, final picture type is P with temporal reference 6, sequence end and presentation completion are true, the session is quiet and the scheduler is fully drained.  The measured presentation span is 0.9928 seconds at 28.202 pictures per second, with zero error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  The 290,814-byte screenshot `/tmp/entry728_p66_checkpoint_completed.png`, SHA-256 `5db4847dbc17108c5ae1b0cfec86b01fabba4ebec3f6972fccd89be9e3504e96`, shows the intended dark fade-stage P66 terminal framebuffer without large macroblock corruption.  Because that final framebuffer remains onscreen after the sub-second decode, the short live passage does not limit its inspection.  The first corrupt authored P frame is therefore after P66 within the initial consecutive P chain.  No source, installed media, RBF, Main, helper or configuration changes during capture.

#### Next Steps:

Use the existing source `6196869` checkpoint mode to generate a second byte-exact I/P prefix ending at zero-based coded P69, midway through the remaining P67 through P72 interval.  Preserve every retained I/P unit, remove only complete B units, append one terminal sequence-end code, verify exact P69 termination and clean software decode, then install under a new absolute filename with exact readback.  The next hardware test should inspect the stable terminal P69 framebuffer rather than the intentionally short live passage.  A corrupt P69 narrows onset to P67 through P69; a clean P69 narrows it to P70 through P72.  Test-media generation and installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 728 COMMIT Unreleased 6196869 2026-08-29T20:01:31-07:00

#### Coming From:

Unreleased 23defaa

#### Purpose:

Add source-picture checkpoint generation and install a byte-exact authored I/P stream held on P66.

#### Outcome:

The user explicitly authorizes the entry-727 P-chain checkpoint.  Source `6196869` extends `tools/streams/strip_h262_b_pictures.py` with optional `--stop-after-source-picture`, requiring a non-negative in-range zero-based ordinal that is included by `--keep-types` and rejecting checkpoint repetition so predictive reference evolution cannot change.  Default generation still reproduces the exact 4,045,136-byte `5f16247b` I/P output, and held-I generation still reproduces the exact 12,658,036-byte `3c28c3e9` output.  Applied at source picture 66, the tool retains the original prefix through exact coded P66, removes 38 complete B units, preserves 6 I and 23 P units byte-for-byte, discards every later source byte and appends one terminal `00 00 01 b7`.  The 273,704-byte checkpoint has SHA-256 `1c1ec0b0d0f327565a19d5fe4b5008c939c51d5ab6396fae0f994f2a45dcb9dc`; independent FFprobe enumeration confirms exactly 29 720x480 TFF interlaced pictures at 30000/1001 comprising 6 I and 23 P with no B or progressive picture, the final output picture is proved identical to source P66, and a complete FFmpeg software decode exits without an error.  Absolute FTP inventory proves the new filename absent, then installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p66_checkpoint.m2v` and independent absolute-path readback reproduce all 273,704 bytes, the exact `1c1ec0b0` hash and terminal sequence end.  Existing media, FPGA, Main, helper and configuration remain unchanged, and no Quartus build is needed.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_p66_checkpoint.m2v` once and leave its terminal frame onscreen.  Report whether the stable final P66 frame contains large block corruption.  Corruption places the first failure at or before P66; a clean terminal frame places it after P66 and permits a bounded later checkpoint.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

- tools/streams/strip_h262_b_pictures.py

#### Status:

- [x] Built
- [ ] Passed

---

## 727 COMMIT Unreleased 23defaa 2026-08-29T19:55:00-07:00

#### Coming From:

Unreleased 23defaa

#### Purpose:

Accept the clean authored I-only hardware result and define a terminal P-chain checkpoint for the corrupt passage.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_i_only_hold.m2v`, reports no large block distortion, and confirms playback finishes.  At the user's explicit request, the completed screenshot is collected locally as `/tmp/entry726_authored_i_only_hold_completed.png`, 416,390 bytes with SHA-256 `77c3b5c2156bef1d744391ed17d92d0de65a472de1c3bb6adac80a21db5a8129`; it shows a clean held authored I frame without the prior large macroblock corruption.  Its checksum-valid schema-20 telemetry accepts all 12,658,036 bytes, displays all 270 I pictures across 269 swaps, sees the terminal sequence end, reaches presentation completion and quiet state, drains the scheduler, and records zero B pictures, prediction requests, error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks or timestamp conflicts.  The intentionally high-rate all-I stream takes 12.4203 seconds and delivers 21.658 pictures per second rather than its nominal nine seconds, confirming measured decoder pressure, but the complete error-free drain and repeated clean authored I pixels make that speed effect orthogonal to the block diagnosis.  Combined with entry 725's corrupted byte-exact I/P run, this isolates the large artifact to original authored P-picture prediction, P residual reconstruction or P reference evolution rather than I decoding, B decoding or shared intra handling.  No source, installed media, RBF, Main, helper or configuration changes during capture.

#### Next Steps:

Extend the deterministic transformer with a source-picture checkpoint mode and create one byte-exact I/P prefix ending immediately after zero-based coded picture 66, the sixth consecutive P picture after the clean authored I at picture 60 and a visible midpoint of the initial shiny-hat fade.  Remove B units from the retained prefix, preserve every required I and P unit unchanged, append exactly one sequence-end code, verify clean software decode, and install it under a new absolute filename.  Its final P66 framebuffer will remain visible after completion.  The next hardware test should report whether that held terminal P frame contains large block corruption; corruption places the first failure at or before P66, while a clean terminal frame places it after P66 and permits a bounded checkpoint search.  Tool modification and installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 726 COMMIT Unreleased 23defaa 2026-08-29T19:45:40-07:00

#### Coming From:

Unreleased aef121f

#### Purpose:

Extend the deterministic picture-unit transformer and install a held byte-exact authored I-only diagnostic stream.

#### Outcome:

The user explicitly authorizes the entry-725 I-only isolation.  Source `23defaa` extends `tools/streams/strip_h262_b_pictures.py` without changing its default B-strip behavior: `--keep-types` selects I or I/P units, `--repeat-retained` accepts only a positive count, the original `strip_b_pictures` API remains, and output picture units are checked byte-for-byte against the selected source units in order.  Regenerating the entry-724 default produces the exact prior 4,045,136 bytes and `5f16247b` hash, proving backward compatibility; a zero repeat is rejected without creating output.  Applying `--keep-types I --repeat-retained 10` to the exact original authored stream removes all 115 P and 219 B units and repeats each of its 27 independent I-picture units ten times without altering any repeated coded-picture byte.  The resulting 12,658,036-byte stream has SHA-256 `3c28c3e9c388a929d661de5c344dc1569e6ea82c7c7efa05bd08c83d840dfdfd`; independent FFprobe enumeration finds exactly 270 720x480 TFF interlaced I pictures at 30000/1001 with no P, B or progressive picture, the tail retains exactly one `00 00 01 b7` sequence end, and a complete FFmpeg software decode exits without an error.  Its approximately nine-second all-I presentation averages 11.24 megabits per second, so cadence and error status remain observational boundaries.  Absolute FTP inventory proves the new filename absent, then installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_i_only_hold.m2v` and independent absolute-path readback reproduce all 12,658,036 bytes, the exact `3c28c3e9` hash and terminal sequence end.  Existing media, FPGA, Main, helper and configuration remain unchanged, and no Quartus build is needed.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_i_only_hold.m2v` once.  Each of the 27 distinct source I frames is held for about one third of a second; report whether any held frame shows large block corruption and whether playback reaches the end.  A clean visual result isolates P prediction or P residual reconstruction, while corruption implicates an authored I-picture or shared intra/quantization feature.  Minor cadence pressure is possible because the byte-exact all-I stream averages 11.24 megabits per second; do not conflate a stutter with block corruption, and do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

- tools/streams/strip_h262_b_pictures.py

#### Status:

- [x] Built
- [ ] Passed

---

## 725 COMMIT Unreleased aef121f 2026-08-29T19:43:26-07:00

#### Coming From:

Unreleased aef121f

#### Purpose:

Record the authored I/P-only corruption result and isolate original I-picture reconstruction from P-picture prediction next.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` and reports visible block corruption.  Because source `aef121f` removed every complete B-picture unit while proving all 27 I and 115 P picture units byte-for-byte identical to the clean software source, the original large artifact does not require B decoding, bidirectional prediction or B presentation.  This supersedes entry 719's preliminary localization from a full re-encode and narrows the hardware defect to authored I/P content, most likely P forward prediction, its reference selection, or its residual reconstruction; stream-level signalling shared by those retained pictures remains a secondary possibility.  The intentionally shortened cadence does not alter retained coded pixels, and no screenshot or telemetry is needed to establish the user's positive visual observation.  No source, installed media, RBF, Main, helper or configuration changes.

#### Next Steps:

Extend the deterministic transformer to create a byte-exact authored I-only diagnostic that removes every P and B unit and repeats each retained I-picture unit enough times to hold each independent frame visibly without altering its coded bytes.  Preserve required sequence and GOP signalling, retain exactly one terminal sequence-end code, prove all 27 distinct source I units byte-identical, and require a clean complete software decode before installation under a new absolute filename.  The next hardware test should play that held I-only stream once in `800x600 Diagnostic` with Weave.  A clean result isolates P prediction or P residual reconstruction; corruption would implicate an authored I-picture or shared intra/quantization feature.  Tool modification and test-media installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 724 COMMIT Unreleased aef121f 2026-08-29T19:26:37-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Add a deterministic test-media tool and install a bit-exact B-stripped derivative of the original authored interlaced stream.

#### Outcome:

The user explicitly authorizes the entry-723 isolation test.  Source `aef121f` adds only `tools/streams/strip_h262_b_pictures.py`, a narrowly scoped deterministic H.262 elementary-stream transformer that identifies complete picture units from picture, GOP, sequence-header and sequence-end boundaries, removes only units whose picture coding type is B, verifies retained picture-unit identity internally, and rejects B-free, malformed, non-terminal or multiply terminated inputs.  Applied to the exact 6,751,008-byte original authored source with SHA-256 `735b1cc8d542b310acf155e890954ba2751b11133c11a299d3e41fa2ae7e4795`, it creates a 4,045,136-byte derivative with SHA-256 `5f16247b130198999581b153bd53d174336476839baa7b2a3c8d59df3e8b444f`.  The tool proves all retained picture units byte-identical, preserves all 27 I and 115 P pictures, removes all 219 B pictures, and retains exactly one terminal `00 00 01 b7` sequence-end code.  Independent FFprobe enumeration confirms exactly 142 720x480 TFF interlaced pictures at 30000/1001 with no B or progressive picture, and a complete FFmpeg software decode exits without an error.  Absolute FTP inventory proves the new filename absent before upload; installation as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` and independent absolute-path readback reproduce all 4,045,136 bytes, the exact `5f16247b` hash and terminal sequence end.  The original and re-encoded fixtures, FPGA, Main, helper and configuration remain unchanged, and no Quartus build is needed for this test-media tool.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` once and report whether any large shiny-hat corruption appears.  The file intentionally runs for only about 4.7 seconds and motion will be jerky because all B pictures are absent; neither behavior is a defect.  Large corruption in this byte-exact retained path implicates original authored P/reference reconstruction, while a clean result isolates the original B-picture units.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

- tools/streams/strip_h262_b_pictures.py

#### Status:

- [x] Built
- [ ] Passed

---

## 723 COMMIT Unreleased 8fd16e8 2026-08-29T19:25:05-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Accept the corrected matched I/P/B hardware run and define the next authored-stream isolation test.

#### Outcome:

The user reports that `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched_end.m2v` looks visually the same as the prior matched run: the large shiny-hat macroblock corruption remains absent, while the previously observed narrow vertical artifacts remain.  At the user's explicit request, one completed screenshot is collected locally as `/tmp/entry722_ipb_matched_end_completed.png`, 334,485 bytes with SHA-256 `a4c476c9012cd21f7ced7eaacd939455fbf22cdea97d086b8dc4eab46e398781`; it visibly retains the narrow vertical line artifacts and the long-standing tiny green crawl at the left edge but shows no large corrupted blocks.  Its checksum-valid schema-20 telemetry accepts all 4,844,184 bytes and displays all 361 encoded pictures across 360 swaps, comprising 121 reference pictures and all 240 B pictures.  Sequence end, presentation completion and quiet session are true, the scheduler is fully drained, and error flags, presentation faults, cache overlap faults, deadline gaps, cadence outliers, transport blocks and timestamp conflicts are all zero.  The measured presentation span is 12.0259 seconds at 29.935 displayed pictures per second.  This clean terminal result proves the four-byte correction resolved only the generated fixture's terminal-drain confound and confirms that ordinary B-picture presence is insufficient to reproduce the original authored stream's large corruption; no source, RBF, Main, helper, configuration or installed media changes during capture.

#### Next Steps:

Prepare one bit-exact B-stripped derivative of the original authored `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v`: preserve every sequence, GOP, I-picture and P-picture byte unchanged, remove only complete B-picture units, and retain exactly one terminal sequence-end code.  Verify that the resulting 142 I/P pictures are byte-for-byte the original coded units and decode cleanly in software, then install it under a new absolute filename.  The next hardware test should play that deliberately shorter and jerkier authored I/P stream once in `800x600 Diagnostic` with Weave and report whether any large shiny-hat corruption remains.  Corruption would implicate original P/reference reconstruction; a clean result would isolate the original B-picture units without conflating the result with a full re-encode.  Test-media preparation and installation require a separate explicit user instruction; do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 722 COMMIT Unreleased 8fd16e8 2026-08-29T19:22:06-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Record the verified construction and installation of the sequence-end-corrected matched interlaced I/P/B fixture.

#### Outcome:

Following the authorized entry-721 plan, `/tmp/coming_to_america_interlaced_12s_ipb_matched_end.m2v` is created from the exact entry-720 matched file by appending only the four bytes `00 00 01 b7`.  The original is 4,844,180 bytes with SHA-256 `0739de2a5568e21f3e68031b96b340bfda0e669f0a465322486f14788bc951b0`; the corrected copy is 4,844,184 bytes with SHA-256 `0a3a2ed8612aa292bf77eb61d920a780b4063868192bc54bda91f369e3a18221`, and bytewise prefix comparison proves every original byte unchanged.  The corrected tail is the required H.262 sequence-end code, FFprobe still enumerates exactly 361 720x480 TFF interlaced pictures at 30000/1001 comprising 25 I, 96 P and 240 B, and a complete FFmpeg software decode exits without an error.  Absolute FTP inventory first proves the new filename absent, then the fixture is uploaded as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched_end.m2v`; independent absolute-path readback reproduces all 4,844,184 bytes, the exact `0a3a2ed8` hash and the terminal sequence-end code.  Both prior comparison fixtures, source, RBF, Main, helper and configuration remain unchanged.

#### Next Steps:

With `Interlaced output` at `800x600 Diagnostic` and Weave selected, play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched_end.m2v` once and report whether it reaches a stable end, whether the large shiny-hat block corruption remains absent, and whether the tiny vertical lines or cadence stutter differ from the prior matched run.  This is an elementary video stream, so silence is expected.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
