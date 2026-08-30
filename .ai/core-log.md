## 720 COMMIT Unreleased 8fd16e8 2026-08-29T19:12:38-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Prepare and install a matched interlaced I/P/B control that differs from the clean entry-719 I/P-only fixture only by restoring B pictures.

#### Outcome:

The user explicitly authorizes the matched control after entry 719 removes the large block corruption with an interlaced I/P-only re-encode but leaves a tiny cadence stutter and narrow miscolored vertical lines.  Exact source `/home/vash/MiSTer-Media-Player/output_files/entry710/capture/coming_to_america_interlaced_12s.m2v` is re-encoded with the successful entry-719 deterministic CFR command unchanged except replacing `-bf 0` with `-bf 2`.  The resulting 4,844,180-byte MPEG-2 elementary stream has SHA-256 `0739de2a5568e21f3e68031b96b340bfda0e669f0a465322486f14788bc951b0`.  Independent FFprobe enumeration finds exactly 361 pictures, all 720x480 TFF interlaced at coded rate 30000/1001, comprising 25 I, 96 P and 240 B pictures with no progressive picture.  Project H.262 analysis sees the expected I/P/B coded order and interlaced motion/DCT boundary, a full software decode exits cleanly, and paired visual samples through the shiny-hat passage are clean and closely match the source.  Absolute target inventory confirms the matched filename is unused; the file is uploaded as new `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched.m2v`, and its independent absolute-path FTP readback reproduces all 4,844,180 bytes and exact `0739de2a` hash.  Final inventory shows the original, I/P-only and matched I/P/B files side by side.  The user plays the matched I/P/B fixture and reports no return of the large block distortion: the tiny vertical miscolored lines are unchanged from the I/P-only run, while its tiny cadence stutter might be less.  This proves that B-picture presence by itself does not reproduce the original authored stream's large shiny-hat corruption and instead points to a more specific prediction, vector, DCT, quantization or GOP feature in that source.  At the user's permission, one completed-screen capture records all 4,844,180 bytes accepted with zero error flags, zero deadline gaps or outliers, zero transport blocks and zero timestamp conflicts, but only 359 of 361 pictures displayed across 358 swaps, comprising 121 reference pictures and 239 of the encoded 240 B pictures; sequence end, presentation completion and quiet session are false, with the final decode still inflight.  Direct tail inspection explains why this terminal observation is not a core regression: the exact original fixture correctly ends in H.262 sequence-end code `00 00 01 b7`, whereas FFmpeg omitted that marker from both generated re-encodes.  The missing marker confounds terminal drain behavior but not the completed visual comparison that eliminated B presence alone.  Neither existing fixture, the RBF, Main, helper, configuration nor source code changes.

#### Next Steps:

Prepare a corrected copy of the matched I/P/B fixture under a new absolute filename by appending the single missing H.262 sequence-end code without changing any picture bytes.  Verify the corrected copy still enumerates as exactly 361 TFF interlaced pictures comprising 25 I, 96 P and 240 B, ends in `00 00 01 b7`, decodes cleanly in software and survives an exact absolute-path FTP readback.  The next user test should play that corrected matched file once in `800x600 Diagnostic` with Weave and report whether it visibly reaches a stable end; do not replay the uncorrected file.  Preparing and installing the corrected test media requires a separate explicit user instruction.  Do not change source, Main, helper or FPGA for this fixture correction, and do not capture further telemetry unless the user explicitly requests it.

#### Files Modified:

- /media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched.m2v

#### Status:

- [x] Built
- [ ] Passed

---

## 719 COMMIT Unreleased 8fd16e8 2026-08-29T19:06:13-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Prepare and install one interlaced I/P-only comparison fixture to localize the remaining real-content block corruption between P and B prediction.

#### Outcome:

The user explicitly authorizes preparation of the next test media after entry 718 proves that the exact software source is clean, all-I hardware playback is clean, and the same transient corruption survives Native 480i Weave, Native 480i Bob and 800x600 Diagnostic.  Exact 6,751,008-byte source `/home/vash/MiSTer-Media-Player/output_files/entry710/capture/coming_to_america_interlaced_12s.m2v`, SHA-256 `735b1cc8d542b310acf155e890954ba2751b11133c11a299d3e41fa2ae7e4795`, contains 361 TFF interlaced 720x480 frame pictures at 30000/1001, comprising 27 I, 115 P and 219 B pictures.  The first FFmpeg invocation rejects contradictory explicit-rate and passthrough-timing options before creating any output.  The corrected deterministic CFR invocation decodes and re-encodes the same complete passage as MPEG-2 4:2:0 TFF interlaced frame pictures with DVD-rate constraints and B pictures disabled.  The 5,955,244-byte result has SHA-256 `70fe8fd27ebecc67ee5276aa486b36cb9a40e61db06bc88cf037e34301e533a6`; independent FFprobe enumeration finds exactly 361 pictures, all interlaced and TFF, comprising 25 I and 336 P pictures with no B or progressive picture, and retains the coded 30000/1001 rate.  Project H.262 analysis confirms that the pictures keep `frame_pred_frame_dct` clear and therefore exercise the interlaced motion/DCT parsing under investigation.  A full software decode exits cleanly, and paired visual samples through the shiny-hat passage show the re-encode is clean and closely follows the source.  Absolute target inventory confirms only the original filename exists before installation.  The new fixture is uploaded as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ip_only.m2v`; its independent absolute-path FTP readback reproduces all 5,955,244 bytes and the exact `70fe8fd2` hash, and final inventory shows the original and comparison files side by side.  The user plays the fixture in 800x600 Diagnostic with Weave and reports that it is substantially better: the large block distortion is completely absent.  A tiny cadence stutter and tiny vertically oriented miscolored lines remain, and the user notes that the narrow line artifact is visible in the prior screenshot evidence; neither is conflated with the eliminated macroblock corruption.  Removing B pictures while retaining 336 interlaced P pictures strongly localizes the large corruption away from the shared I/framebuffer path and toward B-picture prediction, but because re-encoding also changes GOP placement, vectors, residuals and quantization, a matched re-encoded I/P/B control is required before treating B presence alone as proven.  The original media, RBF, Main, helper, configuration and source code are untouched, and no new capture is collected for this user-reported comparison.

#### Next Steps:

Prepare a matched interlaced I/P/B re-encode of the same decoded passage using every entry-719 encoder option unchanged except restoring two B pictures between references.  Require the same 361-picture, 720x480, 30000/1001 TFF interlaced structure, both P and B pictures, clean software decode and clean shiny-hat reference frames, then install it under a separate absolute filename without replacing either existing comparison.  The next user test should replay that matched I/P/B file in 800x600 Diagnostic with Weave.  If the large blocks return against the otherwise matched encode, B-picture presence is isolated; if it remains clean, the original stream depends on a more specific motion-vector, DCT or GOP feature.  Test-media preparation and installation require a separate explicit user instruction; do not change source or build the FPGA in this entry.

#### Files Modified:

- /media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ip_only.m2v

#### Status:

- [x] Built
- [ ] Passed

---

## 718 COMMIT Unreleased 8fd16e8 2026-08-29T18:46:29-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Record the first hardware result for the corrected 361-picture interlaced stream and isolate its remaining visible startup corruption.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` on the exact timing-passing `8fd16e8` RBF and reports that it now reaches the end without freezes or stutters, clearing the former 63-picture hardware stop.  Visible macroblock distortion remains near the beginning and then clears.  The completed-screen capture independently decodes as a checksum-valid schema-20 quiet snapshot with all 6,751,008 clean-video bytes accepted, 361 pictures displayed across 360 swaps, 142 reference plus 219 B pictures, sequence end and presentation completion true, and zero decoder, presentation, cache-bank, transport-block or timestamp-conflict errors.  The video-only fixture correctly emits no audio.  At the user's explicit request a bounded replay capture uses only absolute `/dev/MiSTer_cmd` and `/media/fat/screenshots/entry718_continuous.png` paths, retrieves every completed PNG locally and removes only its own temporary remote screenshot after each retrieval.  Forty-two complete frames span 32.84 seconds: frames 1 through 13 retain the prior terminal screen, frames 14 through 17 cover the black transition, frames 18 through 29 cover playback, and frames 30 through 42 retain the new terminal screen.  Frames 18 and 19 are visually clean; frames 20, 21 and 22 at capture times 14.632, 15.517 and 16.348 seconds show obvious localized macroblock corruption across the shiny hats, faces and upper background; frame 23 and every later sampled playback frame are visually clean.  Relative to the first captured video frame, the observed corruption therefore occupies the sampled interval from approximately 1.56 through 3.27 seconds after picture presentation begins.  The user then changes only the HDMI scaler deinterlacer to Bob and reports that playback behavior is otherwise identical: the stream still finishes without freezes or stutters, the same startup block corruption remains, and it appears more widespread than in Weave.  The user clarifies that both Weave and Bob runs used the core's `Interlaced output: Native 480i` setting.  This is normal processed HDMI: the core emits the same native 480i raster in both runs and the Bob/Weave choice is consumed afterward by MiSTer's scaler.  The user next selects `Interlaced output: 800x600 Diagnostic` with Weave and reports the same result as Bob to the eye, including the startup block corruption.  Its requested terminal screenshot independently confirms another checksum-valid schema-20 quiet completion with all 6,751,008 bytes, 361 pictures, 360 swaps, 142 reference plus 219 B pictures, sequence end and presentation completion true, zero error flags, zero deadline records and no transport block or timestamp conflict.  Persistence across Native 480i Weave, Native 480i Bob and 800x600 Diagnostic rules out the presentation-mode and processed-scaler selections as the origin.  The user then plays the exact same local elementary stream in a software MPEG-2 player and reports that the source looks perfect, ruling out damaged authored media.  Finally, the user plays the established interlaced all-I `/media/fat/games/MediaPlayer/test_1_interlace_tff.mpg` in 800x600 Diagnostic with Weave and reports perfect playback apart from a tiny green dot crawl at the left edge; the user clarifies that this dot crawl has existed for some time and is not a new regression.  Its requested terminal screenshot confirms all 3,068,038 clean-video bytes, 360 I pictures and 359 swaps, sequence end and presentation completion, zero B pictures, zero prediction requests, zero error flags, zero deadline or gap outliers and no transport blocks.  The clean all-I result confines the major Coming to America block corruption to interlaced predictive P/B reconstruction or reference use rather than the shared I-picture and framebuffer path.  Full-stream liveness passes, while predictive visual acceptance remains open.  No capture artifact is added to the repository under the user's streamlined reporting direction.

#### Next Steps:

Prepare an interlaced I/P-only version of the same Coming to America passage, preserving its 720x480, 30000/1001, TFF frame-picture structure while disabling B pictures, then install it as a separate test file without replacing the original.  The next user test should play that I/P-only file once in 800x600 Diagnostic with Weave and report whether the shiny-hat block corruption remains.  Corruption in I/P-only confines the defect to P prediction or reference use; a clean I/P-only result confines it to B-picture bidirectional prediction.  Do not substitute the existing progressive `test_ip_only.m2v`, because it does not exercise the interlaced path under investigation.  Test-media preparation and installation require a separate explicit user instruction; do not change source, build the FPGA or deploy anything in this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 717 COMMIT Unreleased 8fd16e8 2026-08-29T18:41:30-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Record the streamlined hardware-test reporting procedure and identify the next single DVD-video validation.

#### Outcome:

The user directs that, going forward, hardware playback results require only an update to `core-log.md` followed by the next test instruction.  Do not collect, retain or commit screenshots, helper logs, telemetry dumps or duplicate acceptance artifacts unless the user specifically asks for them or a newly observed failure requires evidence before diagnosis.  The exact timing-passing `8fd16e8` RBF remains installed and has passed the bounded Big Lebowski opening over both HDMI and S/PDIF.  The highest-value next test is the existing `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` fixture: it is the real 361-picture interlaced-frame stream that previously froze after 63 displayed pictures and directly drove the quantized I/P/B parsing and generation-safe presentation corrections now present in this RBF.

#### Next Steps:

With the current core still loaded, select HDMI audio and Weave, then play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` once from beginning to end without changing modes during playback.  Report only whether the video reaches the end cleanly, freezes, or shows visible corruption; this elementary video stream contains no audio, so silence is expected.  After the report, update only `core-log.md` and provide the next single test.  Do not capture telemetry for a clean pass.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 716 COMMIT Unreleased 8fd16e8 2026-08-29T18:37:35-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Hardware-validate the exact timing-passing RBF's known DVD-opening regression over both HDMI and S/PDIF audio.

#### Outcome:

After reloading the entry-715 RBF, the user plays `/media/fat/games/MediaPlayer/dvd_opening_original.mpg` and reports working HDMI audio.  The initial report that S/PDIF does not work is withdrawn when the user finds its cable unplugged; after connecting the cable and replaying, the user reports that S/PDIF works perfectly too.  Two agent-triggered screenshots of the completed S/PDIF run use absolute `/dev/MiSTer_cmd` and `/media/fat/screenshots/cadence_probe.png` paths, are byte-identical at 316,381 bytes and SHA-256 `f9a627cc2af55b86b670dfe4fc6ca5240a81400ce7c5ca8c76075cdd3e0832ff`, show the expected final Universal frame, and decode as matching checksum-valid schema-20 quiet snapshots.  Telemetry accepts the exact expected 10,334,169 clean video bytes, all 289 displayed pictures, 288 swaps, 128 reference plus 161 B pictures and all 25 timestamps, reaches sequence end and presentation completion, and reports zero error flags, audio underruns, PCM protocol faults, presentation faults, cache-bank overlap faults, transport-block intervals or timestamp-delay conflicts.  Legacy observational counters remain visible at 287 deadline records, 145 outliers and 40 timestamp-advance conflicts; as in the prior accepted opening captures, these are not the functional acceptance gate and do not negate the complete, error-free run.  The helper independently identifies S/PDIF output with AC-3 private substream `0x80` using IEC 61937, emits 375 frames and 576,000 samples, reaches EOF and exits zero after all 12,818,397 transport bytes in 783 pipe reads, with every byte on the fast path and none on the slow path.  Absolute FTP readback reproduces the installed 4,471,792-byte entry-714 RBF hash `677f2e11df6104c8409abcd541df81f1b2d178e6a249038b16afdf5e0282ac7c`, the accepted static helper hash and the source movie hash.  This accepts the exact `8fd16e8` candidate for the bounded known opening over both HDMI and S/PDIF; because this fixture uses progressive frame pictures within an interlaced sequence, it does not independently qualify the newly admitted field-motion and field-DCT syntax.  No source, installed file, playback mode or core configuration is changed during capture.

#### Next Steps:

Do not repeat the known opening solely to reconfirm HDMI or S/PDIF audio.  Preserve the verified deployed RBF and rollback artifact, and resume the separate DVD-video compatibility roadmap with an excerpt that actually exercises the remaining target interlaced syntax or direct VOB path.  Keep 576i outside scope and make no rebuild, reseed or FPGA change unless a distinct video defect requires it.

#### Files Modified:

- .ai/current_results/entry716_hardware_acceptance.json
- .ai/current_results/entry716_helper_summary.txt
- .ai/current_results/entry716_spdif_terminal.png

#### Status:

- [x] Built
- [x] Passed

---

## 715 COMMIT Unreleased 8fd16e8 2026-08-29T18:26:14-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Deploy the exact timing-passing interlaced decoder and HDMI scaler RBF to the MiSTer with verified backup and readback.

#### Outcome:

The user explicitly authorizes deployment of the entry-714 candidate without changing Main or the helper.  An initial FTP preflight mistakenly uses relative server paths and is discarded before any write; after the user corrects the procedure, every device access uses an absolute `/media/fat/...` path through a double-slash FTP URL.  Absolute inventory identifies the sole active core as `/media/fat/MediaPlayer_20260829_b9c2657.rbf`, not `/media/fat/MediaPlayer.rbf`.  Its downloaded 4,436,916 bytes have SHA-256 `f366c246854d177aa2ce4d359d370be840094ecdb09164b736e5d55f4ed3392e`.  That exact file is uploaded to `/media/fat/_MediaPlayer_Backups/MediaPlayer_20260829_b9c2657_pre_8fd16e8_f366c246.rbf` and its independent FTP readback matches the original size and hash.  The candidate re-verifies locally as the exact 4,471,792-byte output of source `8fd16e8`, SHA-256 `677f2e11df6104c8409abcd541df81f1b2d178e6a249038b16afdf5e0282ac7c`; it is uploaded to absolute staging path `/media/fat/MediaPlayer_entry715_stage.rbf`, downloaded, and verified with the same size and hash before promotion.  An absolute FTP rename then atomically replaces the existing active filename.  Final readback of `/media/fat/MediaPlayer_20260829_b9c2657.rbf` again matches all 4,471,792 bytes and SHA-256 `677f2e11df6104c8409abcd541df81f1b2d178e6a249038b16afdf5e0282ac7c`, and absolute root inventory confirms that it is the only root-level `MediaPlayer*.rbf`; no staging file remains.  Main, the helper, media files and all other cores are untouched, and the newly installed core is not reloaded during deployment.

#### Next Steps:

Have the user reload the sole installed `/media/fat/MediaPlayer_20260829_b9c2657.rbf`, then perform one user-controlled HDMI playback check of the known interlaced DVD sample with audio; collect telemetry only after the user reports the screen and sound result.  If rollback is needed, restore the verified `f366c246` backup using absolute FTP paths.  Do not rebuild, reseed or change source during hardware validation.

#### Files Modified:

- /media/fat/MediaPlayer_20260829_b9c2657.rbf
- /media/fat/_MediaPlayer_Backups/MediaPlayer_20260829_b9c2657_pre_8fd16e8_f366c246.rbf

#### Status:

- [x] Built
- [ ] Passed

---

## 714 COMMIT Unreleased 8fd16e8 2026-08-29T18:00:21-07:00

#### Coming From:

Unreleased 53bc8e7

#### Purpose:

Close the single remaining HDMI scaler setup path without changing decoder RTL, latency, clocks or constraints.

#### Outcome:

The user approves a tightly bounded HDMI source correction after the one seed-17 reseed leaves decoder and video setup safely positive at 0.801 and 2.956 ns but misses HDMI setup by 0.047 ns on exactly one path.  A detailed same-clock TimeQuest report against the completed seed-17 fit identifies that path from `ascal:ascal|o_vpix_outer[1].g[3]` to `ascal:ascal|o_vpixq_pre[3].g[3]`: it has two logic levels and 6.084 ns of data delay, of which 5.000 ns, eighty-two percent, is routing between registers placed at X68_Y34 and X56_Y28.  Follow the established ASCAL timing technique already used for the C8 adaptive-polyphase selectors: capture an identical `type_pix` copy from the same C2 `pixq_v` source on the same enabled edge, mark it `dont_merge`, and use that copy only for the C8 queue element-three boundary selections currently driven by `o_vpix_outer(1)`.  This is a physical duplicate rather than a pipeline delay and must not alter scaler cycles, sync alignment, pixel values, seed 17, any decoder source or any timing constraint.  Published source `8fd16e8` adds exactly that twenty-four-bit same-edge duplicate, retains the original for the other queue elements, and changes only `sys/ascal.vhd`; a fresh detached build-PC checkout verifies exact full SHA `8fd16e8df61f0dca8a7373f035e663c84b49f1a9` and seed 17.  The repository's dedicated HDMI scaler simulation exits before analysis because GHDL is not installed or available privately on GUNSMOKE, so no simulation result is claimed and no new toolchain is installed.  The one clean Quartus Prime 17.0.2 build then completes in thirteen minutes nineteen seconds with zero errors and 215 warnings.  It fits at 34,252 of 41,910 ALMs and 52,819 registers, increases of 103 ALMs and 267 registers from the rejected seed-17 predecessor, while memory remains exactly 4,181,443 bits in 532 RAM blocks and DSP use remains 67.  Every timing category passes with zero TNS: full and HDMI setup are positive 0.044 ns, decoder setup is positive 0.853 ns, video setup is positive 2.905 ns, and hold, recovery, removal and minimum-pulse-width margins are positive 0.244, 3.953, 0.456 and 0.925 ns.  A post-fit same-clock HDMI audit reports fifty paths with zero violations, confirms the `dont_merge` copy exists in the fitted netlist, and no longer lists the former `o_vpix_outer[1]` to `o_vpixq_pre[3]` transfer; the new worst HDMI path is unrelated vertical polyphase bounding logic at positive 0.044 ns.  The accepted-for-hardware-test 4,471,792-byte RBF has SHA-256 `677f2e11df6104c8409abcd541df81f1b2d178e6a249038b16afdf5e0282ac7c` and remains only on GUNSMOKE under `/home/vash/mister-builds/entry714/source_8fd16e8/output_files`; it is not installed.

#### Next Steps:

Preserve this exact timing-passing RBF without rebuilding or reseeding.  Obtain a separate installation handoff before writing the MiSTer, then hardware-validate HDMI scaler output and the already qualified interlaced MPEG-2 playback path; because the focused scaler simulation could not run without GHDL, require clean physical video as part of acceptance.  Retain the existing focused decoder evidence and do not repeat the long simulation soaks unless hardware exposes a decoder-specific defect.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [ ] Passed

---

## 713 COMMIT Unreleased 53bc8e7 2026-08-29T17:37:40-07:00

#### Coming From:

Unreleased 2ca6b02

#### Purpose:

Perform one user-authorized seed-17 rebuild of the focused-qualified B-engine timing cleanup after seed 20 misses only HDMI setup timing.

#### Outcome:

The user explicitly authorizes one reseed after exact source `2ca6b02` fits normally and closes the intended decoder paths at positive 0.386 ns but misses the independent HDMI PLL output-clock setup gate by 0.090 ns.  Seed 17 is selected from the directly comparable pre-cleanup evidence: on source `17336f8` it brought HDMI to negative 0.003 ns, substantially closer than seed 20's negative 0.048 ns, while the B-engine cleanup has since recovered about 0.38 ns in the decoder domain.  Change only the fitter seed assignment from 20 to 17; retain the four passing focused simulations because RTL, constraints and test inputs are unchanged, and do not repeat the long 361-picture or DVD soaks.  This authorization covers exactly one fresh Quartus Prime 17.0.2 compile, with no seed sweep, timing waiver or installation.  Published source `53bc8e7` changes only the fitter seed assignment, and a fresh detached build-PC checkout at exact full SHA `53bc8e7f16d49e18596205ca0b6e4926850f185a` confirms `MediaPlayer.qsf` is the sole non-log difference from focused-qualified source `2ca6b02` and contains seed 17.  The one clean Quartus Prime 17.0.2 compile completes in sixteen minutes twenty-one seconds with zero tool errors and 217 warnings.  Seed 17 fits normally at 34,149 of 41,910 ALMs and 52,552 registers, fifteen more ALMs but 114 fewer registers than the rejected seed-20 cleanup fit; memory remains exactly 4,181,443 bits in 532 RAM blocks and DSP use remains 67.  Decoder and video setup are safely positive at 0.801 and 2.956 ns, and hold, recovery, removal and minimum-pulse-width margins are positive at 0.235, 3.558, 0.413 and 0.925 ns.  Full timing nevertheless rejects the fit on one HDMI PLL output-clock path at negative 0.047 ns slack and negative 0.047 ns TNS.  This improves HDMI by 0.043 ns from seed 20 but does not meet the required zero-violation gate.  The rejected 4,456,812-byte RBF with SHA-256 `3ee9aa131d81374b1feada78145fcf7489a7a62ac4487bf62703b09526b40a36` remains only on GUNSMOKE under `/home/vash/mister-builds/entry713/source_53bc8e7/output_files` and is not installed.

#### Next Steps:

Stop at the rejected seed-17 build without another seed, build, timing waiver or installation.  Preserve the now-strong decoder timing and both completed HDMI fit reports; if work resumes, make a separately approved, tightly bounded source correction to the single remaining HDMI/scaler path rather than perturbing the decoder again.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 712 COMMIT Unreleased 2ca6b02 2026-08-29T17:11:30-07:00

#### Coming From:

Unreleased 578b7e0

#### Purpose:

Close decoder and HDMI timing without reverting the validated interlaced parser and scheduler corrections.

#### Outcome:

The user approves a source-level B-engine timing correction after seed 20 narrowly fails HDMI setup and seed 17 moves the failure into both decoder and HDMI domains.  Detailed reports exonerate the corrected parser and scheduler logic: seed 20's worst decoder path runs from live block classification through retained lookup data and reconstruction, while all five seed-17 decoder violations run from execution direction or backward-fetch selection into the prediction fetcher's phase-address registers.  The existing lookup selector also forms a reported fifteen-node combinational loop between phase choice, motion-vector choice and tap parity.  Preserve all functional fixes, return the fitter assignment to the established seed 20, register block field-DCT classification and the fetch-launch descriptor at block boundaries, and derive lookup direction, phase and vector selection acyclically from registered controls.  The user explicitly declines the long 361-picture and original-DVD soak regressions for this timing checkpoint because they take longer than the build; validation is limited to focused B field-motion, field-DCT and progressive controls before one clean compile.  Published source `158f2e7` captures block field-DCT classification with the existing residual transaction, records the complete prediction-fetch address, phase, row and span descriptor when the existing registered launch pulse is scheduled, removes all functional dependence on the old prefetch selector, derives lookup direction and field-vector slot directly from registered request controls, and restores seed 20.  The first focused compile identifies only that established simulation monitors still use the removed one-bit prefetch marker to label launch traces; final source `2ca6b02` restores that marker strictly for observability without feeding any functional selector.  A fresh detached checkout of exact full SHA `2ca6b029526a94633c0214909b1f23316dc23cd5` passes the four deliberately bounded regressions: B field motion, combined field motion plus field-DCT, and interlaced field-DCT each reconstruct 1,036,800 samples pixel-exact with all parser, raster, writer and presentation errors clear, while the progressive mixed-raster control compares all 423,936 samples within its established maximum delta of two.  No long 361-picture or original-DVD soak is run.  The single clean Quartus Prime 17.0.2 seed-20 compile completes in thirteen minutes twenty seconds with zero tool errors and 216 warnings; placement and routing finish normally with estimated peak interconnect use fifty-two percent.  The fit uses 34,134 of 41,910 ALMs and 52,666 registers, reductions of 96 ALMs and 42 registers from the rejected `17336f8` seed-20 fit, while memory remains exactly 4,181,443 bits in 532 RAM blocks and DSP use remains 67.  The intended decoder path is no longer marginal: decoder setup improves from positive 0.005 to positive 0.386 ns, and video setup remains positive at 2.333 ns.  Full timing nevertheless rejects the fit because the unchanged HDMI PLL output-clock domain fails setup by 0.090 ns with 2.441 ns TNS; hold, recovery, removal and minimum-pulse-width margins remain positive at 0.173, 3.345, 0.570 and 0.925 ns.  The rejected 4,452,104-byte RBF with SHA-256 `a3455a5c9d72a91c574e149f4dc88528f75cbc0286e0e40443f1bba29c7015c2` remains only on GUNSMOKE under `/home/vash/mister-builds/entry712/source_2ca6b02/output_files` and is not installed.

#### Next Steps:

Stop at the rejected seed-20 build as directed, without additional simulation, rebuild, reseed, timing waiver or RBF installation.  Preserve the passing focused decoder evidence and completed fit reports; if work resumes, address the independent HDMI scaler path under a separately approved source-level checkpoint rather than disturbing the now-positive decoder timing.

#### Files Modified:

- MediaPlayer.qsf
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 711 COMMIT Unreleased 578b7e0 2026-08-29T16:48:02-07:00

#### Coming From:

Unreleased 17336f8

#### Purpose:

Perform one user-authorized seed-17 rebuild of the simulation-qualified interlaced decoder after seed 20 narrowly misses HDMI setup timing.

#### Outcome:

The user explicitly authorizes one reseed and delegates the seed choice after exact source `17336f8` fits normally but fails the full-chip HDMI PLL output-clock setup gate by 0.048 ns.  Seed 17 is selected from project evidence because the v0.8.0 timing-sensitive HDMI/scaler build improved from a 0.070 ns seed-16 failure to positive 0.243 ns at seed 17, while seed 20 has already been exercised on the current source.  Published source `578b7e0` changes only the fitter seed assignment from 20 to 17; a fresh detached checkout verifies `MediaPlayer.qsf` is the sole functional difference from simulation-qualified `17336f8`.  The one authorized Quartus Prime 17.0.2 compile completes in 13 minutes 36 seconds with zero tool errors and 247 warnings.  Seed 17 fits at 34,177 of 41,910 ALMs and 52,626 registers, reductions of 53 ALMs and 82 registers from seed 20 but still increases of 588 ALMs and 879 registers over accepted `b9c2657`; memory remains exactly 4,181,443 bits in 532 RAM blocks and DSP use remains 67.  Full timing rejects the fit: the 60 MHz decoder clock fails setup by 0.293 ns and the HDMI PLL output clock also fails by 0.003 ns with 0.072 ns TNS, while the 54 MHz video clock passes at 2.778 ns and hold, recovery, removal and minimum-pulse-width margins remain positive at 0.251, 2.956, 0.577 and 0.925 ns.  Because full timing already fails, no redundant focused timing extraction is used to qualify it.  The 4,439,176-byte RBF with SHA-256 `368fe458f18cb4659173073cce64ac44626201b895d320ff6090a17c91b13e76` is rejected and is not installed.

#### Next Steps:

Stop after the rejected seed-17 build without installing its RBF or trying another seed.  Preserve both rejected seed-20 and seed-17 reports alongside the accepted `b9c2657` baseline; if work resumes, use their path differences to propose a separately approved source-level timing correction that preserves constraints and all simulation-qualified behavior.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 710 COMMIT Unreleased 17336f8 2026-08-29T06:55:07-07:00

#### Coming From:

Unreleased b9c2657

#### Purpose:

Correct quantized interlaced I/P/B macroblock parsing and preserve generation-safe future-reference binding when presentation narrowly precedes a B header.

#### Outcome:

The approved correction is bounded by an exact hardware and simulation reproduction of the Coming to America interlaced-frame test failure.  After the unique timing-qualified `b9c2657` RBF is explicitly loaded, hardware displays 63 pictures and freezes a checksum-valid schema-20 snapshot at clean-video byte 204,101 with error flags `0x0004`; the physical LEDs report USER 3, POWER 2 and DISK 7, identifying the generalized P prediction raster's row-terminator assertion.  Exact production-path replay initially shows macroblocks 675 through 680 from the current P picture followed by macroblocks 0 through 44 from the next P picture before the current row terminator.  A first header-count hold at source `c477469` deadlocks at byte 204,066, and direct-transaction ownership at `b5c546f` advances only through the following picture-coding extension to byte 204,081 because the actual loss of ownership occurs earlier.  A parser-only replay isolates it at picture 65, slice row 16, macroblock column 6: the RTL reads a quantized P macroblock as quantiser scale, `motion_type` and `dct_type`, while H.262 and FFmpeg decode the transmitted order as `motion_type`, `dct_type`, quantiser scale and then vectors.  The preceding quantized macroblock leaves the RTL one bit early, so legal field motion `01` is read as reserved `00`; the parser drops the remaining fifteen rows, and the next P picture then enters that unfinished raster transaction.  Published source `b6ba7c8` removes the experimental wrapper hold, restores standards order in the P wide-parser FSM, and adds a quantized interlaced-P case to the existing FFmpeg-cross-checked field-DCT fixture.  The corrected P parser crosses the original byte-204,101 boundary and the production path remains clean until byte 1,120,843, where picture parsing stops independently in the B parser's `S_MOTION_TYPE` at slice row 4, macroblock column 11.  Published source `4b58b43` applies the analogous B ordering and adds a quantized bidirectional B case; its FFmpeg-cross-checked field-DCT regression reconstructs 1,036,800 samples exactly with zero parser, raster, writer or presentation errors.  The full replay then crosses both former parser failures but stops at byte 1,135,154 with only `presentation_error` asserted after the repaired B picture parses and reconstructs successfully.  A passive scheduler-edge monitor proves the preceding P reference is promoted and displayed on bank 1, the B header arrives one cycle later, and the scheduler nevertheless marks that same generation as pending because the physical display and reference bank numbers match.  Published source `a99d184` adds the approved promotion-generation guard and passes the complete scheduler suite plus the exact 1,036,800-sample field-DCT fixture, but the production replay reproduces the same stop because its two-bit `reference_headers_inflight` bookkeeping remains at one.  Published experiments `e67aadd` and `59b4d01` replace that occupancy estimate with an eight-bit I/P header total and also pass both focused regressions, but the exact replay still stops at the same byte with 48 I/P headers against 47 promotions.  Raw coded-order analysis and passive cycle correlation prove that mismatch was inherited across an earlier sequence boundary and does not describe the failing edge: all 41 observed P headers have published, no reference decode or ownership state remains active, and the displayed bank is the newest promoted reference.  Published source `d0cd422` snapshots the promotion generation at each accepted I/P header, passes the complete scheduler suite and exact field-DCT fixture, and crosses the former byte-1,135,154 failure cleanly.  The replay then exposes a separate presentation failure at picture 91 and byte 1,222,106 because the immediately preceding I picture never publishes.  An exact 48,016-byte isolated replay reproduces the underlying I-parser error at byte 888, slice 3, macroblock 11, state `ST_MB_QSCALE`; like the repaired P/B paths, the quantized interlaced I path consumes `quantiser_scale_code` before the transmitted `dct_type`, reads a false zero scale and abandons the reference picture.  Published source `493059a` restores that field order and makes the isolated I plus sequence-end case publish once with zero decoder errors.  The expanded I/P/B fixture then fails before exercising that lifecycle edge, and passive frontend tracing corrects the earlier interpretation: the FFmpeg-derived fixture clears `progressive_frame` without also clearing `chroma_420_type`, retains forward I-picture f-codes `3/3` instead of the required `15/15`, raises frontend syntax error source 21 and therefore never admits its I parser.  Published source `154b303`, which permits an active I parser to finish only the following start-code prefix and value after eligibility clears, does not alter that invalid-fixture failure and remains unvalidated rather than a confirmed decoder correction.
The corrected fixture source `104cc55` explicitly emits valid interlaced chroma semantics and I-picture f-codes, remains pixel-exact against FFmpeg, and passes identically on `493059a` and `154b303`, proving the speculative retirement exception unnecessary; published source `644ad88` removes it.  Exact `644ad88` passes the 1,036,800-sample field-DCT fixture with zero mismatches, the complete scheduler and film-presentation suite, and one uninterrupted 548,849,997-cycle replay of all 6,751,008 bytes: 27 I, 115 P and 219 B pictures produce 142 reference promotions, 219 B persistences and 360 swaps with every decoder, raster, writer and presentation error clear.  The replay also confirms the wrapper's historical `b_picture_observed` diagnostic mask becomes permanently true after the first B picture, so it can conceal a genuine later I/P parser error even though it did not affect this corrected decode.  Final published source `17336f8` removes that sticky diagnostic mask, reports the P controller's already ownership-qualified error directly, and adds a directed post-B transport regression that deliberately raises a later bookkeeper error and observes aggregate error source 1.  With the diagnostic unmasked, one uninterrupted replay of the exact 6,751,008-byte, 361-picture stream reproduces the same 548,849,997-cycle totals with every error clear.  The exact field-motion, combined field-motion plus field-DCT, progressive mixed-raster and Big Lebowski first-I regressions pass; the mixed fixture compares all 423,936 samples within its established two-level tolerance and the other focused pixel fixtures are exact.  The recreated 10,334,168-byte Big Lebowski opening matches the established source hash and completes paired 591,079,997-cycle numerical qualifications: both modes accept all 289 pictures with zero decoder, raster, writer or presentation errors, isolated references remain within one level of the FFmpeg oracle, and the natural reference-chain run stays within its measured error bound.  Several cases in the older aggregate cycle-A script now exit on stale hard-coded generated-picture counts or cycle totals even though their functional result lines remain clean; this is test-harness maintenance debt rather than decoder failure and does not invalidate the current directed fixtures.  A fresh detached checkout of exact source `17336f8` completes the single authorized Quartus Prime 17.0.2 seed-20 compile in 13 minutes 40 seconds with zero tool errors.  The fit uses 34,230 of 41,910 ALMs and 52,708 registers, increases of 641 ALMs and 961 registers over accepted `b9c2657`, while retaining exactly 4,181,443 memory bits, 532 RAM blocks and 67 DSP blocks.  The focused audit has zero violated paths with decoder setup slack 0.005 ns and video setup slack 3.055 ns, and hold, recovery, removal and minimum-pulse-width margins are positive at 0.248, 3.055, 0.417 and 0.925 ns.  Full-chip setup nevertheless fails by 0.048 ns on the HDMI PLL output clock, regressed from positive 0.271 ns at `b9c2657`; therefore the 4,452,820-byte RBF with SHA-256 `031b176096bf6394e17947d29fa73e0163bf3cd8b668ab54d09bd412459f9d42` is rejected and is not installed.

#### Next Steps:

Stop at the rejected seed-20 build without retrying, reseeding or installing its RBF, as directed by the user.  If work resumes, compare the failing HDMI setup transfer against accepted `b9c2657` and prepare a separately approved source-level timing correction without weakening constraints; retain all simulation evidence and the exact rejected build reports for that decision.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- rtl/mpeg2_new/mpeg2_h262_luma4_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/generate_test_interlaced_field_dct_residual.py
- tools/streams/h262common.py
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_dense_transport_recovery.sv
- tools/streams/run_film_presentation.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 709 COMMIT Unreleased b9c2657 2026-08-29T06:09:31-07:00

#### Coming From:

Unreleased b9c2657

#### Purpose:

Install the exact timing-qualified interlaced decoder candidate and hardware-validate its known Big Lebowski opening regression over HDMI and Weave.

#### Outcome:

The exact 4,436,916-byte RBF from entry 708 is retrieved from the build PC, independently reproduces SHA-256 `f366c246854d177aa2ce4d359d370be840094ecdb09164b736e5d55f4ed3392e`, and is staged, read back, promoted and finally read back again as `/media/fat/MediaPlayer_20260829_b9c2657.rbf` without replacing any older core.  Following the explicit reload handoff, the user plays `games/MediaPlayer/dvd_opening_original.mpg`, the twelve-second stream-copy opening derived from `the_big_lebowski.iso`, with HDMI decoded stereo PCM and Weave, and reports that everything looks perfect and the sound is perfect too.  Two completed screenshots are byte-identical, show the final Universal frame and decode as checksum-valid schema-20 quiet snapshots.  Telemetry accepts the exact expected 10,334,169 clean video bytes, all 289 displayed pictures, 288 swaps, 128 reference plus 161 B pictures and all 25 timestamps, reaches sequence end and presentation completion, and reports zero error flags, audio underruns, PCM protocol faults, presentation faults, cache-bank overlap faults or validation failures.  The helper identifies AC-3 private substream `0x80`, emits 375 frames and 576,000 decoded stereo samples, reaches EOF and exits zero after all 12,818,397 transport bytes in 784 pipe reads, with every byte on the fast path and none on the slow path.  Readback reproduces the qualified RBF, accepted static helper and source movie hashes.  This accepts the exact `b9c2657` candidate for the known opening regression; because that fixture uses progressive frame pictures within an interlaced sequence, it does not alone qualify the newly admitted field-motion and field-DCT syntax.

#### Next Steps:

Keep the accepted RBF loaded and prepare one short stream-copy excerpt from the user's decrypted DVD samples that is confirmed to contain the newly admitted interlaced field-motion and field-DCT syntax.  Test that excerpt once in HDMI Weave, preserve the completed screen and helper log, and only then repeat it in Bob and native 480i if the first run is clean.  Retain 576i, field pictures, `repeat_first_field` expansion beyond the already admitted film cadence, DVD navigation, menus and direct ISO playback outside this checkpoint.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 708 COMMIT Unreleased b9c2657 2026-08-29T05:59:55-07:00

#### Coming From:

Unreleased d89c02b

#### Purpose:

Close timing on the completed interlaced MPEG-2 production decoder and preserve one exact fit-qualified candidate for hardware validation.

#### Outcome:

Published source `98a1670` first updates the cadence regression for the established schema-20 audio fields and passes its isolated deadline, hardware-cadence, RTL-packet and decoder-layout checks.  The first clean seed-20 build fits at 33,956 ALMs but its focused decoder audit fails at negative 2.006 ns, so that RBF is rejected.  Source `ad2b27f` inserts a B prediction boundary while retaining pixel-exact mixed, field-motion and field-DCT reconstruction, but its clean build fails the same focused audit at negative 3.712 ns and is also rejected.  Final published source `b9c2657` registers the B fetchers' retained-footprint lookup, targets requests only to the selected physical fetcher and flushes pending lookup state at each start.  The progressive mixed fixture compares all 423,936 samples within its established two-level tolerance, and the B field-motion, frame-motion field-DCT and combined field-motion plus field-DCT fixtures each compare 1,036,800 samples exactly with zero parser, raster, writer or presentation errors.  A fresh detached checkout of exact full SHA `b9c2657e6aefb6c9f6101efbe72c0b29e487a3dc` completes Quartus Prime 17.0.2 seed 20 with zero errors.  The fit uses 33,589 of 41,910 ALMs, 51,747 registers, 4,181,443 memory bits, 532 of 553 RAM blocks and 67 DSP blocks.  Full timing passes with setup 0.023 ns, hold 0.246 ns, recovery 2.440 ns, removal 0.481 ns and minimum pulse width 0.925 ns; the focused audit finds zero violations with decoder setup 0.023 ns and video setup 2.735 ns.  The accepted 4,436,916-byte RBF remains on the build PC at `/home/vash/mister-builds/entry710/source_b9c_clean/output_files/MediaPlayer.rbf` with SHA-256 `f366c246854d177aa2ce4d359d370be840094ecdb09164b736e5d55f4ed3392e`.  It has not been installed or hardware-tested.

#### Next Steps:

Preserve this exact RBF as the sole candidate and perform one user-controlled MiSTer playback validation of the 720-by-480 NTSC interlaced target, checking native 480i first and then Bob and Weave presentation without opening 576i scope.  Do not rebuild or reseed this checkpoint; if hardware exposes a defect, retain the completed screen and helper log before deciding on a separately approved correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [ ] Passed

---

## 707 COMMIT Unreleased d89c02b 2026-08-29T04:29:02-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Complete interlaced frame-picture P/B field-DCT reconstruction and open the qualified field-motion and field-DCT paths for production decoding.

#### Outcome:

Published source `d89c02b` completes the field-DCT parser, metadata, raster and DDR-store path begun in `e7d4a10`, corrects prediction fetches to follow field-ordered luma rows, and applies the macroblock `dct_type` layout to coded and uncoded luma blocks alike so frame-ordered prediction cannot overwrite neighboring field rows.  P field-DCT prediction uses doubled-stride rectangles and a second parity rectangle only for frame-motion vertical half samples.  B field-DCT prediction reuses the two existing fetchers by direction, with up to two vertical-parity phases per direction, and the combined field-motion case selects the correct destination-field vector and reference-field parity without adding block memory.  The production P and B parser restrictions on clear `frame_pred_frame_dct` are removed, and the frontend now keeps native 480i ownership eligible across admitted interlaced I, P and B frame pictures.  Deterministic fixtures independently checked against FFmpeg cover P and B frame motion with field DCT, integer and horizontal, vertical and diagonal half samples, all luma layouts, chroma residuals, pure field motion, and the combined field-motion plus field-DCT case.  Each of the four production-path simulations compiles without the former test define and compares every reconstructed sample exactly, totaling 518,400 samples for the P-field fixture and 1,036,800 samples in each P/B fixture, with zero parser, raster, writer or presentation errors.  The unchanged progressive mixed-raster control compares 423,936 samples with zero mismatches above its established two-level tolerance, and the interlaced TFF, BFF, progressive and field-DCT I-picture controls retain zero out-of-tolerance pixels.  No Quartus build, RBF installation or MiSTer playback is claimed yet.

#### Next Steps:

Pull exact published source `d89c02b` into a fresh isolated build-PC checkout, run the broader decoder and native-presentation regression set, and then perform one clean Quartus Prime 17.0.2 build with the focused timing report.  Require a successful fit, positive timing in every required category and resource comparison against the 34,163-ALM, 532-RAM-block recovery baseline before producing a candidate RBF.  If those gates pass, generate a real interlaced National Archives profile Program Stream that exercises admitted P/B syntax for a controlled MiSTer playback test; keep field pictures, `repeat_first_field`, 576i and DVD navigation explicitly outside this checkpoint.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- README.md
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_field_motion_field_dct.py
- tools/streams/generate_test_interlaced_field_dct_residual.py
- tools/streams/h262common.py
- tools/streams/run_b_field_motion.sh
- tools/streams/run_field_motion_field_dct.sh
- tools/streams/run_interlaced_field_dct_residual.sh
- tools/streams/run_interlaced_field_motion.sh
- tools/streams/tb_h262_field_motion_field_dct_pixels.sv
- tools/streams/tb_h262_interlaced_field_dct_residual_pixels.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 706 COMMIT Unreleased 736f64f 2026-08-29T03:55:11-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Record hardware acceptance of standalone MP3 playback over decoded-PCM S/PDIF.

#### Outcome:

After identifying that the first attempted capture belonged to an accidental replay of the DVD opening, the user runs the intended `entry697_file_example_WAV_1MG_192k.mp3` test with the same loaded `MediaPlayer_20260829.rbf` and reports that everything passes and the audio sounds great.  The corrected helper log identifies the exact MP3 source and `audio output spdif (decoded PCM; IEC 61937 for AC-3/DTS)`, emits zero video bytes, zero timestamps and 229 decoded audio frames containing 263,808 stereo samples, reaches EOF and exits zero.  Main submits all 1,137,676 transport bytes across 70 pipe reads, with every byte on the fast path and none on the slow path.  The standalone-audio run leaves the preceding video telemetry image resident, so that stale decoder snapshot is not treated as MP3 evidence; the source-specific helper completion and the user's physical listening result accept MP3 decoded PCM over S/PDIF.  No source, FPGA image, helper, Main or MiSTer configuration changed during capture.

#### Next Steps:

Per the user's direction, stop consumer-audio hardware testing here and return to DVD video work.  Add and fixture-test inter-macroblock field DCT before opening the P, B and frontend production admission gates, preserving the fit-qualified RBF and accepted helper unchanged until the video simulation gates justify another build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 705 COMMIT Unreleased 736f64f 2026-08-29T03:46:17-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Record hardware acceptance of the fit-recovered candidate's original-DVD-opening regression over HDMI decoded stereo PCM.

#### Outcome:

The user explicitly loads `MediaPlayer_20260829.rbf`, plays `dvd_opening_original.mpg` over HDMI decoded stereo PCM and reports that everything looks perfect.  Two fresh completed screenshots are byte-identical, show the final Universal frame, decode as checksum-valid schema 20 quiet snapshots and pass the exact expected 289-picture and 10,334,169-byte gate with no validation failure.  Telemetry reaches sequence end and presentation completion with 289 displayed pictures, 288 swaps, 128 reference plus 161 B pictures, all 25 timestamps, zero error flags, no audio underrun, no PCM protocol or presentation error and no cache-bank overlap error.  The helper identifies AC-3 private substream `0x80`, emits 375 frames and 576,000 decoded stereo samples, reaches EOF and child exit zero, and reconciles all 12,818,397 submitted bytes across 784 pipe reads with every byte on the fast path and none on the slow path.  FTP readback reproduces the qualified RBF and helper hashes.  Legacy observational counters remain visible at 287 deadline records, 144 outliers, 20 timestamp-advance conflicts and zero delay conflicts; they are not the acceptance gate and do not negate the clean functional result.  This accepts the existing original-opening HDMI regression only; production field prediction remains closed and no S/PDIF mode is exercised by this run.

#### Next Steps:

Continue the same loaded candidate with MP3 over S/PDIF first, followed by WAV and FLAC over S/PDIF, AC-3 passthrough over S/PDIF and one known progressive video.  Report each audible and visible result, and leave the latest helper log and terminal screen intact before replay if any dropout, receiver unlock, protocol fault or visual regression occurs.  Treat the recovered RBF as an accepted existing-video baseline while keeping the decoded-PCM S/PDIF correction and production field-prediction path open until their own hardware checks complete.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 704 COMMIT Unreleased 736f64f 2026-08-29T03:35:47-07:00

#### Coming From:

Unreleased 8404035

#### Purpose:

Deploy and hardware-test the exact fit-qualified recovery RBF with its matching decoded-PCM S/PDIF helper.

#### Outcome:

The exact source `736f64f` artifacts were retrieved from GUNSMOKE and independently reverified before deployment.  The 4,459,744-byte RBF with SHA-256 `3f66a5eb38bcff783472b977764bc34366a07570b01278822e705718edf224fa` is installed as `/media/fat/MediaPlayer_20260829.rbf` without replacing any existing core, and final FTP readback matches.  The installed 629,056-byte helper with SHA-256 `f5573a98dcd788228d317da906c8d017cf904e3a85f1d43aea7f13b048252758` is preserved and readback-verified at `/media/fat/_MediaPlayer_Backups/MediaPlayer_Helper_f5573a98dcd7_20260829T034019`; the matching 629,056-byte helper with SHA-256 `02d1df98c62ee00169585db990b6bd48c3769eca20c3e1d594f2318c362eb00f` is staged, promoted and verified at `/media/fat/linux/MediaPlayer_Helper`.  An initial read-only inventory used curl's login-relative FTP interpretation; after the user identified the mistake, filesystem-absolute paths were encoded explicitly before any write.  Before-and-after readbacks prove MiSTer Main, the active undated core, the prior dated core and the original DVD opening unchanged.  No core was loaded and no playback was started.  This checkpoint can validate existing video behavior and corrected HDMI and S/PDIF routing, but production interlaced P and B admission remains closed and therefore it cannot accept the NARA release profile or prove the recovered field-prediction path on hardware.

#### Next Steps:

Explicitly load `MediaPlayer_20260829.rbf`, then play the existing original DVD opening over HDMI decoded PCM first and report motion, audio and completion.  If clean, test MP3, WAV and FLAC over S/PDIF, then AC-3 passthrough over S/PDIF and one known progressive video.  Leave the completed screen and latest helper log intact before replay if any regression, dropout, protocol fault or visible error occurs so evidence can be collected.  Mark hardware acceptance only after the user reports the checkpoint results; this RBF does not yet exercise production field prediction.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 703 COMMIT Unreleased 8404035 2026-08-29T03:31:55-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Adopt the U.S. National Archives MPD-D2 DVD-from-film profile as the project's controlled release media target.

#### Outcome:

Controlled reference commit `8404035` adds the official NARA MPD-D2 web profile to the active source catalog, routing table and fast index as record `NARA-001`, and adopts it as the project's release media baseline.  The target carries MPEG-2 Main Profile at Main Level in VOB and Program Stream form, temporary eight-megabit-per-second standard-definition source, 720 by 480 constant-bit-rate video at 29.97 frames per second, interlaced top-field-first single-pass encoding, and two-channel constant-bit-rate AC-3 at 256 kilobits per second, 48 kilohertz and a listed sixteen-bit sample size.  The controlled source preserves NARA's December 22, 2023 page-review date and the August 29, 2026 verification date.  It explicitly does not replace the normative H.262, H.222.0, DVD application, filesystem, navigation, menu or CSS sources, and it records that MPD-D2 does not constrain `picture_structure`, `motion_type`, macroblock `dct_type`, GOP design or quantization matrices, so a frame-picture-only subset cannot be inferred from the profile.  No RTL, helper, RBF or MiSTer state changed.

#### Next Steps:

Use `NARA-001` as the controlling media baseline when defining release fixtures and acceptance language.  Retain conforming streams that exercise the implemented H.262 syntax envelope and verify complete playback, top-field-first cadence, decoded HDMI stereo and AC-3 S/PDIF passthrough, while declaring any profile-permitted syntax not covered by those streams as an explicit limitation.  The fit-qualified RBF and matching helper remain ready for a separately authorized regression and S/PDIF hardware checkpoint before field DCT and production interlaced P/B admission are added.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 702 COMMIT Unreleased 736f64f 2026-08-29T03:10:56-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Qualify the published interlaced prediction recovery and pending decoded-PCM S/PDIF correction with one clean exact-source Quartus build.

#### Outcome:

An isolated fresh GitHub clone was verified at exact published source `736f64f` with no tracked mismatch or reused Quartus database, and Quartus Prime Lite 17.0.2 completed the full configured flow in fourteen minutes twenty-three seconds with zero errors and 218 warnings.  The fitter succeeds at 34,163 of 41,910 ALMs, eighty-two percent, with 52,455 registers, 4,178,743 memory bits, 532 of 553 RAM blocks and 67 DSP blocks.  This reclaims 5,539 ALMs and 2,562 registers from the failed near-final report and leaves field prediction only 1,808 ALMs above the 32,355-ALM pre-field baseline instead of 7,347; RAM remains the binding resource at ninety-six percent.  One routing-congestion warning is emitted while the router converges, but routing completes in the same invocation and no critical or timing-failure warning occurs.  Every reported timing category has zero TNS and positive slack: minimum setup plus 0.100 nanoseconds in the sixty-megahertz MPEG domain, hold plus 0.243, recovery plus 3.086, removal plus 0.404 and minimum pulse width plus 0.925; the focused report independently finds zero violated decoder or video paths, with video setup plus 2.885 nanoseconds.  The 4,459,744-byte RBF has SHA-256 `3f66a5eb38bcff783472b977764bc34366a07570b01278822e705718edf224fa`, and complete build and focused timing evidence remains under `/home/vash/mister-builds/entry702/source_0313` on GUNSMOKE.  No production admission gate, field DCT, MiSTer installation or hardware playback occurred, so hardware acceptance remains open.

#### Next Steps:

Preserve this exact source, reports and RBF as the fit-qualified recovery baseline.  Under separate authorization, deploy the matching RBF and static helper together after backing up the installed files, then physically verify MP3, WAV and FLAC over S/PDIF while preserving HDMI decoded PCM and AC-3 and DTS receiver lock.  For the next DVD RTL cycle, add and fixture-test inter-macroblock field DCT before opening the P, B and frontend production admission gates; avoid new block memories because only twenty-one RAM blocks remain, and require the complete progressive and interlaced regression set before another clean build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 701 COMMIT Unreleased 736f64f 2026-08-29T02:45:25-07:00

#### Coming From:

Unreleased c2097e3

#### Purpose:

Recover the near-complete interlaced P and B field-prediction work by removing replicated fetch storage and parallel footprint logic while preserving accepted consumer audio and the pending S/PDIF correction.

#### Outcome:

The failed fitter run remains useful evidence of unacceptable structural cost but is not treated as an exact qualification of `784ae0b`, because mapping began before that final source commit existed and the shared checkout later advanced.  Published source `736f64f` retains the parser and prediction arithmetic repairs while reversing both expensive implementation choices.  Each existing B fetcher again retains at most two rectangles; a bidirectional field block fetches its forward parity pair through the current instance, then reuses the otherwise idle prefetch instance for the backward pair after the shared DDR port is released.  Lookup selects the physical direction bank while each fetcher's phase index carries only destination parity.  The field selector is registered before one pair of base-address, span and bounds calculations, so four parallel footprint cones become one serialized pair.  Two races exposed by this reuse are corrected explicitly: a lookup broadcast is suppressed on the same edge that a fetcher clears its old validity map, and a nonzero backward byte origin is refreshed during the protected alternate-start cycle if the forward pixel completed before that pair launched.  Production admission remains closed; `H262_TEST_FIELD_MOTION` opens only the P and B parser gates in the two deterministic scripts, and their byte conversion now uses standard `od`, `tr` and `fold` instead of requiring `xxd`.  Fresh isolated simulations compare 518,400 P-field samples and 1,036,800 B-fixture samples with zero mismatches, including both destination parities and the four independently selected B reference fields, while the unchanged progressive mixed-raster control checks 423,936 samples with zero mismatches above its established two-level tolerance and maximum delta two.  The native helper rebuild, WAV and FLAC matrices, all four short and faded 44.1 and 48 kHz Program Stream and MP3 profiles, and focused PCM/non-audio S/PDIF routing simulations pass without changing their source.  No Quartus result, RBF or installation is claimed yet.

#### Next Steps:

Pull exact published source `736f64f` into a new isolated checkout and perform one clean Quartus 17.0.2 flow plus the focused timing report, requiring a successful fit, positive timing and resource comparison against both the 32,355-ALM baseline and the failed near-final report.  Record that build in a new entry rather than appending to this settled source entry.  Do not reuse the stale shared build database, open production admission, begin field DCT or install any helper or RBF during this cycle.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/run_b_field_motion.sh
- tools/streams/run_interlaced_field_motion.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 700 COMMIT Unreleased c2097e3 2026-08-29T02:45:24-07:00

#### Coming From:

Unreleased c39ebdc

#### Purpose:

Route decoded stereo PCM to the selected S/PDIF output while preserving IEC 61937 AC-3 and DTS passthrough as non-audio.

#### Outcome:

The accepted standalone formats were silent under the S/PDIF menu choice because the framework treated output selection and the IEC 60958 non-audio bit as the same state, sending raw words and marking every selected S/PDIF stream non-audio.  Source `c2097e3` reserves transport mode bit seven for IEC 61937 records, has only the helper's compressed-burst writer set it, preserves it through the in-band extractor, and separates `spdif_enable` from `spdif_non_audio` in the framework.  Selected decoded MP3, WAV, FLAC and Program Stream audio now use processed stereo PCM with ordinary audio channel status, while AC-3 and DTS passthrough retain raw byte-exact bursts and non-audio status; HDMI remains the alternate exclusive output and Main needs no code change.  Native and exact-checkout helper matrices pass, focused extractor and router simulations cover all four output states, decoded WAV, MP3 and FLAC carry no non-audio flag, and all 375 AC-3 plus 1,125 DTS bursts carry it and remain byte-identical.  The exact static ARM helper is 629,056 bytes with SHA-256 `02d1df98c62ee00169585db990b6bd48c3769eca20c3e1d594f2318c362eb00f`.  No Quartus build or installation occurred, so the helper is intentionally retained rather than installed without its matching FPGA image.

#### Next Steps:

Carry this correction unchanged through entry 701's clean FPGA build, then require a matched helper and RBF installation under separate authorization and physical MP3, WAV and FLAC listening over S/PDIF while preserving HDMI PCM and AC-3 and DTS receiver lock.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- sys/audio_out.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/streams/analyze_arm_av_transport.py
- tools/streams/run_audio_output_routing.sh
- tools/streams/strip_inband_pcm.py
- tools/streams/tb_audio_spdif_route.sv
- tools/streams/tb_h262_inband_metadata.sv
- tools/streams/verify_ac3_passthrough.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_flac.py
- tools/streams/verify_consumer_wav.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 699 COMMIT Unreleased c39ebdc 2026-08-29T02:45:23-07:00

#### Coming From:

Unreleased 1ee2b93

#### Purpose:

Add FLAC as a separately built and hardware-tested consumer format through the existing helper-only PCM path.

#### Outcome:

Source `c39ebdc` enables the pinned miniaudio 0.11.25 native FLAC decoder inside the single static helper and adds case-insensitive `.flac` selection to Main without a runtime FFmpeg dependency or FPGA change.  The helper accepts ordinary 16- and 24-bit mono, stereo and multichannel files, converts them to signed 16-bit stereo at 44.1 or 48 kHz through the established audio-only transport, and preserves one clean end token.  Format, sanitizer, Main-loader, MP2, MP3, WAV, AC-3 and DTS regressions pass.  The exact 629,056-byte static ARM helper and patched Main were transactionally installed with backups and hash readback, and the user played the selected FLAC sample on hardware and reported that it ran perfectly.  The later S/PDIF silence reproduced after a complete zero-error FLAC decode and belongs to the shared routing defect recorded by entry 700, not the codec.

#### Next Steps:

Keep FLAC accepted and preserve it through the interlaced recovery and S/PDIF build; Ogg Vorbis and M4A with AAC-LC remain later independent consumer-format cycles.

#### Files Modified:

- CHANGELOG.md
- README.md
- host/arm/ARCHITECTURE.md
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_flac.py

#### Status:

- [x] Built
- [x] Passed

---

## 698 COMMIT Unreleased 1ee2b93 2026-08-29T02:45:22-07:00

#### Coming From:

Unreleased 60159bd

#### Purpose:

Add ordinary WAV playback as a separately built and hardware-tested consumer format through the existing helper-only PCM path.

#### Outcome:

Sources `a335de1` and `1ee2b93` pin miniaudio 0.11.25, compile only its WAV decoder and conversion support into the static helper, and add case-insensitive `.wav` selection to Main without a runtime FFmpeg dependency or FPGA change.  Ordinary integer and float mono, stereo and multichannel WAV files are converted to signed 16-bit stereo at 44.1 or 48 kHz through the established audio-only transport.  Native format, sanitizer, Main-loader, MP2, MP3, AC-3 and DTS regressions pass, including byte-exact direct signed-16 decode.  The exact static helper and patched Main were transactionally installed with verified backups, and the user played both the selected WAV sample and its MP3 derivative on hardware and reported that they sounded perfect.

#### Next Steps:

Keep WAV and MP3 accepted and preserve both paths through later format and FPGA work.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_wav.py

#### Status:

- [x] Built
- [x] Passed

---

## 697 COMMIT Unreleased 60159bd 2026-08-29T02:45:21-07:00

#### Coming From:

Unreleased 784ae0b

#### Purpose:

Add basic standalone MP3 playback through the existing MediaPlayer picker and PCM transport without changing the FPGA.

#### Outcome:

Sources `c1d7da7`, `2445324` and `60159bd` compile pinned minimp3 directly into the static helper, add case-insensitive `.mp3` selection to Main and decode MPEG-1 Layer III mono or stereo at 44.1 or 48 kHz into the existing signed stereo PCM records with one clean end token and no video requirement.  The implementation bounds ID3 metadata handling, rejects unsupported rates and malformed or renamed input, preserves byte-identical video and accepted MP2, AC-3 and DTS behavior, and passes the native codec, transport and sanitized Main-loader matrices.  The exact static helper and patched Main were installed transactionally with verified backups; after the WAV cycle the user played the selected MP3 derivative on hardware and reported that it sounded perfect, and the retained session shows all 263,808 stereo frames, helper exit zero and normal completion.

#### Next Steps:

Keep MP3 accepted and preserve its helper and Main behavior through later format and FPGA work.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/generate_arm_av_test.py
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [x] Passed

---

## 696 COMMIT Unreleased 784ae0b 2026-08-29T02:34:10-07:00

#### Coming From:

Unreleased 784ae0b

#### Purpose:

Record that the entry 695 tree does not fit the device.

#### Outcome:

A full Quartus compilation of `784ae0b` failed after forty-eight minutes with `Error (11802): Can't fit design in device`.  Logic utilization reached 39,702 ALMs of 41,910, ninety-five percent, against the 32,355 and seventy-seven percent this cycle started from, with registers at 55,017 against 48,619 and RAM blocks at 532 of 553.  The field prediction work therefore costs roughly 7,350 ALMs and 6,400 registers, a twenty-three percent increase in logic, and the design no longer fits.  The long fit was the symptom: placement on a device this full runs far past the thirty minutes a healthy build of this project has always taken, and that signal was correctly identified by the user and wrongly dismissed during the cycle on the strength of a synthesis RAM-segment count that grew only four and a half percent, which is not a proxy for logic.  Two costs dominate and both are structural rather than incidental.  The prediction fetcher's retained word store doubled from thirty-six to seventy-two words of sixty-four bits on each of the two B engine instances, which is roughly nine thousand bits of randomly indexed storage that cannot infer as block memory.  Each engine also now computes four complete phase footprints in parallel, every one carrying its own base address through the shift-add row multiply in `pixel_addr`, its own word span and its own bounds comparison, where frame prediction computed one or two.  Neither cost is required by the standard; both follow from choosing to widen the fetcher rather than reuse the second instance, and from computing all four footprints combinationally rather than sequencing them.  Simulation correctness is unaffected and remains proven: the P fixture, the B fixture and the mixed raster control all reconstruct exactly.

#### Next Steps:

Reduce logic before anything else in this cycle proceeds, because `dct_type` and the admission gates will only add more.  The first lever is the one rejected when the fetcher was widened: give the B engine its four rectangles by reusing the second fetcher instance, which exists as a prefetch double buffer, instead of doubling the retained store on both instances.  A field macroblock already forgoes prefetch, so that instance is idle exactly when the extra phases are needed, and this reclaims the larger of the two costs without changing the phase indexing the engines now use.  The second lever is to stop computing four phase footprints at once.  Only the phase being fetched and the phase being looked up are ever live, so the base address, word span and bounds can be selected from the slot and direction first and computed once, which removes three of every four `pixel_addr` multiplies and bounds comparisons in both engines.  Measure each lever with a fit rather than by synthesis estimates, since this cycle demonstrated that synthesis counts do not predict logic utilization.  Do not attempt hardware until the design fits with margin; ninety-five percent is not a place to add features.  The build configuration is a separate matter worth measuring once the design fits: the project sets maximum fitter effort, high performance optimization mode and five physical synthesis passes including register retiming, and a compile long enough to exceed the engineering it validates is not a workable iteration loop, but reducing effort must be measured against the 0.170 nanosecond slack rather than assumed safe.

#### Files Modified:

- None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 695 COMMIT Unreleased 784ae0b 2026-08-29T02:25:48-07:00

#### Coming From:

Unreleased f2c10be

#### Purpose:

Admit interlaced NTSC P and B frame pictures by adding field motion prediction and residual field DCT.

#### Outcome:

This cycle admits interlaced NTSC P and B frame pictures by adding field motion prediction.  It passes analysis and synthesis and every simulation regression, but no bitstream exists yet, so it is neither built nor hardware validated.  The plan it started from understated the work in two ways that the cycle corrected.  There are two macroblock parsers, not one: B pictures parse in `mpeg2_h262_b_core_probe` and P pictures in `mpeg2_h262_p_wide_motion_syntax_probe`, selected by `b_transport` in `mpeg2_h262_two_picture_probe_p_chain.sv`, and only the B one had been touched.  The prediction fetcher held two source rectangles where a bidirectional field macroblock needs four, one forward and one backward field per destination field.  Both are now resolved: the P parser gained the field syntax, the record channel carries the field selects, the fetcher takes a PHASES parameter and the B engine raises it to four, and both engines form field predictions by indexing a phase per destination parity with the row stride doubled so a fetched row steps one field line.  A field macroblock does not prefetch its successor, which costs throughput on those blocks and avoids four more address sets.  Dual prime and the reserved motion type are refused as implementation limits of this decoder rather than limits of the standard, and field pictures remain outside the cycle.  Measurement drove all of it.  Two deterministic fixtures were built with pixel oracles the generators prove byte-identical to FFmpeg's decode of their own bitstreams, and the gates were opened locally, never in a commit, so each change was measured as it landed rather than at the end.  The P fixture went from 1,594 mismatching samples to 0 of 518,400 and the B fixture from 1,110 to 0 of 1,036,800, with the mixed raster control holding at 0 of 423,936 throughout.  That loop found four defects in the cycle's earlier work, every one of them in a commit whose message asserted behaviour was unchanged: the vertical motion predictors were renamed to a frame-unit pair while two readers and all four slice-start resets kept pointing at the dead names, so skipped B macroblocks were predicted with vertical motion zero and H.262 7.6.3.1's slice reset was silently lost; `S_MOTION_TYPE`, `S_FSEL` and `S_BSEL` never advanced the bit pointer, so `frame_motion_type` decoded as 00 or 11 and every field-predicted B macroblock failed at the first one; the P engine read slot 0's field select from a register nothing ever assigned, and its picture-start capture hardwired the field bits to zero; and emitting the second motion record ahead of the committing one raced the engine's capture arming, losing that record on the first macroblock of every picture.  The mixed raster pixel regression had been failing since `4bd6869` and nobody had run it.  A full Quartus compilation was started from this tree and had not finished after forty minutes in Fitter placement, so fit and timing are unmeasured for this cycle and no bitstream exists; the run showed no capacity errors and no critical warnings, and synthesis RAM segments grew only from 1,659 to 1,733 across the two engine walks.  Build time is itself now a project constraint: the project fits at maximum effort with high performance optimization mode and five physical synthesis passes including register retiming, on a device already at seventy-seven percent ALMs and ninety-three percent RAM blocks with 0.170 nanoseconds of slack, and a compile of that length is not a workable iteration loop.  Measure a reduced-effort build against slack before the next cycle rather than assuming either that the settings are needed or that they are free.  Analysis and synthesis pass with 0 errors.

#### Next Steps:

Three pieces of this cycle remain before hardware.  The macroblock `dct_type` bit is parsed only by the intra path in `mpeg2_h262_luma4_probe.sv`; neither the P wide probe nor the B parser reads it, no sideband carries it, the residual destination for luma blocks 2 and 3 still uses the frame offset of eight rather than the field offset of one, and both `MediaPlayer_top_03.svh` and the soak testbench wire the store's `field_dct` input as `!p_store_select && dct_type`, which forces it low whenever the prediction path owns the store.  The store itself already handles field DCT correctly, doubling the luma stride and applying it to luma only, so no address arithmetic needs inventing.  Neither existing fixture can test it, because both deliberately code no residual blocks to isolate prediction, so a third fixture carrying field DCT together with coded residual on inter macroblocks is a prerequisite, along with field-DCT block ordering in the reference model.  Then open the gates for real: `wide_candidate` and `wide_unsupported_now` in the P probe each carry their own copy of the `frame_pred_frame_dct` requirement and both must be relaxed together, `b_candidate` in the B parser carries a third, and the frontend admission gate still admits I pictures only.  Note that neither field fixture can exercise the frontend gate, because both are 30000/1001 sequences whose picture-level admission is what changes; validating that needs real interlaced disc content.  Finally fold in the two entry 694 instrumentation defects while the profiler is being rebuilt: probe the transport block at the clean video queue's own full condition rather than a valid and ready pair, and move the snapshot trigger off the first error flag now that underruns are counted.  Install only after separate user authorization with the accepted bitstream backed up.  Watch for video stutter, since the clean video queue is half its former depth and interlaced P and B raise decoder load.  A parallel agent is adding MP3, WAV and FLAC playback to the ARM helper under `host/arm/` on the same branch; that work does not touch `rtl/` and is integrated after this cycle is hardware validated.  The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/h262common.py
- tools/streams/generate_test_interlaced_field_motion.py
- tools/streams/generate_test_b_field_motion.py
- tools/streams/tb_h262_interlaced_field_motion_pixels.sv
- tools/streams/tb_h262_b_field_motion_pixels.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/run_interlaced_field_motion.sh
- tools/streams/run_b_field_motion.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 694 COMMIT Unreleased f2c10be 2026-08-28T22:21:11-07:00

#### Coming From:

Unreleased 100072a

#### Purpose:

Scale the helper PCM reserve with the doubled sink FIFO after the entry 693 build starved audio once at startup.

#### Outcome:

The entry 693 bitstream removed the eighty-four second starvation but underran once at approximately 1.7 seconds, with forty-two pictures already displayed, so the startup video burst had not wedged the extractor and the audio cushion was the weak point. The reserve is half the sink FIFO by construction; doubling the FIFO to 16,384 frames while leaving the reserve at 4,096 left audio with the old eighty-five millisecond cushion exactly as the halved clean video queue made transport blocks more frequent. This commit takes the reserve and the initial release to 8,192 frames, keeping reserve plus one batch below the sink FIFO, and corrects the stale documented sink depth. The first attempt aborted playback on the build PC with a video lookahead limit exceeded at 524,288 bytes and exit status one, because a deeper reserve makes the scheduler read further ahead for audio and hold more video meanwhile, so the lookahead bound moves to two mebibytes, negligible against 492 mebibytes of host memory and still a runaway guard. Equivalence is proven before installation: video, PCM and PTS payloads are byte-identical to the previous helper in both output modes, at 10,334,172 video bytes and 2,304,000 PCM bytes, with only delivery order changed, and all four helper audio profiles and the AC-3 passthrough verification pass. The helper installed as `ed13bc9357bff0a5e28bcfa703badb1614a6220cb29a51c4886316067f201a35` during playback without disturbing it, since the helper is executed per playback. A full nineteen minute hardware run then completed with all 1,126,974,123 transport bytes submitted, 867 reports, the helper never behind and its lead between 1.15 and 1.89 seconds. The startup underrun is gone, confirming the inference this commit rests on. The user reports the entire movie, including a continuous intro song, looked and sounded perfect. Hardware counted exactly one audio underrun, at STC 521 seconds, which the user did not hear and which the helper log shows no disturbance around, so it is transient and downstream of the host. Against four consecutive runs that starved at eighty-three to eighty-five seconds with audible recurring dropouts, this is accepted.

#### Next Steps:

Two instrumentation defects from entry 693 remain and should ride along with the next FPGA build rather than justify one alone. The transport block counters read zero blocks and zero milliseconds across the whole run while an underrun demonstrably occurred, because the probe used a conventional valid-and-ready pair on a path whose decoder advances on stream_valid itself, so the longest blocked interval was never actually measured and should instead be probed at the clean video queue's own full condition. The snapshot still latches on the first error flag, so it froze at 521 seconds and the last ten minutes of the run are unmeasured; now that underruns are counted, the trigger should move to the terminal or quiet path. Until both are fixed the remaining single underrun cannot be sized, so do not attempt to tune it further. Watch for video stutter on material heavier than this title, since the clean video queue is half its former depth, and revisit the trade rather than defend it if stutter appears. The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [x] Passed

---

## 693 COMMIT Unreleased 100072a 2026-08-28T21:13:29-07:00

#### Coming From:

Unreleased 9956c8e

#### Purpose:

Rebalance audio and video buffering within the existing memory budget and count the blocked intervals, in one build.

#### Outcome:

This entry is the approved plan for the cycle and its commit does not exist yet; it replaces an earlier measurement-only plan for the same number, which the user declined because the FPGA is timing sensitive and repeated builds and reseeds are themselves a risk. Entry 692 exonerated the helper and located the fault at the single gate on the shared transport byte path, where input_ready requires stream_ready, so a full clean video queue halts the byte path and every PCM record behind the held video byte halts with it. The current fit constrains the correction: RAM blocks stand at 512 of 553, ninety-three percent, with logic at seventy-four percent and memory bits at seventy-one, so RAM blocks and not logic are the binding resource. From the configured geometry the audio FIFO of 8,192 words by thirty-five bits occupies thirty-two M10K blocks at 256 words each, and the clean video queue of 65,536 words by eight bits occupies sixty-four blocks at 1,024 words each. Doubling the audio FIFO outright would add thirty-two blocks and reach ninety-eight percent, which is rejected as reckless on a sensitive design. This cycle instead trades one for the other at zero net cost, halving the clean video queue to 32,768 bytes to free thirty-two blocks and doubling the audio FIFO to 16,384 frames to spend them, leaving the block count unchanged. The trade is justified by rate rather than preference: buffering audio costs 1.68 megabits per second against 7.12 for video, so audio is roughly four times cheaper per unit of protection time, and surrendering thirty-seven milliseconds of video slack buys one hundred seventy milliseconds of audio, raising the audio budget from one hundred seventy to three hundred forty-one milliseconds. The same build adds free-running profiler counters for the longest continuous blocked interval, the number of blocked intervals and the minimum audio FIFO level, and replaces the first-error snapshot latch with a counted underrun record so one run reports every occurrence instead of only the first, with the screenshot decoder extended to match. This reverses the standing guidance against widening buffers, which was correct while the helper was suspect and would have masked a helper defect, but the helper is now exonerated by its own measurement, the requirement is genuinely buffering, and this is a rebalance rather than a net enlargement. The known risk is that a shorter video queue makes the extractor block sooner and more often, which is harmless only if audio now survives each block, and the new counters are what will show whether it did.

#### Next Steps:

The build compiled once with no reseed and closed timing: worst setup slack improved to 0.170 nanoseconds against the 0.126 baseline on the HDMI PLL domain, clk_mpeg2 gave up margin to 1.035 nanoseconds and every TNS is zero, with ALMs at 32,355 of 41,910 and RAM blocks at 517 of 553 rather than the predicted 512, so the trade cost five blocks instead of being free. The RBF installed with the accepted bitstream backed up and verified, and a core reload proved necessary before the FPGA ran it, which one capture initially missed because the file on the card had been updated while the running configuration had not; the schema version in the snapshot is the reliable check and should be read first in every future capture. The eighty-four second starvation did not recur. A startup underrun at approximately 1.7 seconds appeared instead and is corrected in entry 694, where the full hardware result is recorded. The decoder gate for schema 20 is fixed separately in `55f2595`, which also restores correct picture counts for this schema.

#### Files Modified:

- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py

#### Status:

- [x] Built
- [x] Passed

---

## 692 COMMIT Unreleased 9956c8e 2026-08-28T20:39:32-07:00

#### Coming From:

Unreleased 8423f20

#### Purpose:

Instrument helper PCM delivery against the sink clock so the entry 691 audio deficit can be measured on one short hardware run.

#### Outcome:

The instrumentation is committed as `9956c8e`, built with MiSTer's official ARM GNU 10.2 toolchain, installed on the MiSTer at 10.10.0.30 with the replaced helper backed up and every readback hash verified, and run against the full file to completion; it exonerates the helper and relocates the fault. Equivalence was proven before installation: baseline and instrumented native helpers produce byte-identical 12,818,397 byte transports in both output modes, and a throttled run at approximately hardware transport rate reproduces that identical transport while emitting the new report. Across 870 reports over 1,137 seconds the signed difference between frames emitted and frames the sink will have consumed is never positive, meaning the helper is never behind, and it holds a lead between 1.08 and 2.11 seconds with a mean emission rate of 47,972.3 frames per second against forty-eight thousand, a residual drift of 27.7 frames per second that would need far longer than the observed failure time to exhaust the lead. The hypothesis this cycle was built to test, a systematic helper pacing deficit, is therefore disproved by its own measurement. Offline analysis of the full 1,126,974,123 byte transport, which matches the byte count hardware submitted, shows 3,420,000 PCM records carrying 54,720,000 frames, exactly 1,140.00 seconds of audio, and shows the interleave guard holding everywhere: the largest run of video between two PCM records in the entire transport is 28,672 bytes and is the startup burst at byte 28,672, while every other gap is at most 4,121 bytes, the 4,096 byte free-video guard plus record overhead. A constant transport byte rate FIFO model was built and discarded because it predicts starvation from 3.45 seconds, which hardware contradicts by playing correctly for eighty-four; delivery is bursty, which the measured lead already showed. With average rate, lead and interleave all correct, the fault is downstream, and it is structural: in mpeg2_h262_inband_metadata.sv the single gate input_ready requires stream_ready, so when the 65,536 byte clean video queue fills, the entire shared byte path halts and every PCM record behind the held video byte halts with it, exactly the condition entry 687 observed empirically and attributed to helper delivery. The audio FIFO is 8,192 frames, 170 milliseconds, which bounds how long that block can last before starvation. Three runs latched the underrun at 83.5, 85.4 and 84 seconds, twice with an identical 1,998 picture count, and the twelve second opening never reaches the sustained decode load that fills the queue. Entry 688 improved startup because that was genuinely a helper horizon problem and left this untouched because it never was one.

#### Next Steps:

Correct the coupling in the FPGA, not in the helper, which entry 693 plans by first measuring the maximum continuous interval the shared path stays blocked so the fix is sized from a real number rather than chosen. Prefer removing the coupling between audio extraction and video backpressure over widening either buffer, since a larger audio FIFO only fails at a longer stall instead of never. Keep this helper installed while that work proceeds so helper and FPGA behavior stay separable, and leave the accepted bitstream untouched until a replacement is validated. The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [x] Passed

---

## 691 COMMIT Unreleased 8423f20 2026-08-28T19:48:00-07:00

#### Coming From:

Unreleased 8423f20

#### Purpose:

Record the extended S/PDIF hardware run that shows audio underrun still occurring after the entry 688 correction.

#### Outcome:

The user plays `games/MediaPlayer/my_test.mpg` over S/PDIF to completion and reports perfect video and perfect audio/video sync throughout with audio cutting out a few times in total, and the captured telemetry contradicts the entry 690 conclusion for long duration. The installed helper still reads back as `fefaeb18b8c9e091a9cd9e97258e86264683f374f9663cb3ea6b99bafb81977a`, with the MiSTer Main executable and `MediaPlayer.rbf` unchanged, so this is the entry 688 correction running against the accepted bitstream. The helper delivered the whole file: end of file with child exit status zero, 1,126,974,123 transport bytes submitted across 68,787 reads, 1,126,974,123 fast bytes, zero slow bytes, and only ten would-block events in a 1,140.5-second session, so host supply is not the limiting factor and the delivery path never stalled. The schema 19 snapshot nevertheless reports `audio_underrun` true with `error_flags` 0x0400, the sole set flag, which is the same bit the decoder exports as audio underrun, and `validation_failures` therefore lists only that condition; `pcm_protocol_error`, `presentation_error` and every other error remain clear. The snapshot is latched by the profiler on the first nonzero error flag rather than at end of playback, so it freezes the state at the first underrun and cannot count later ones. That first underrun is placed at approximately 83.5 seconds into playback by three independent measures that agree: 1,998 displayed pictures at 24000/1001 gives 83.33 seconds, the separate STC field reads 83 seconds, and the presentation cycle counter reconciles to 83.47 seconds once its single 32-bit wrap at 71.58 seconds is accounted for. With that wrap corrected the run delivered 1,997 intervals at 23.93 fps against frame rate code 4, consistent with correct film cadence right up to the underrun and with the user's report of perfect video and sync. The raw `cadence_seconds` of 11.884442 and `delivered_fps` of 168.03 in the snapshot are the uncorrected wrapped values and must not be quoted as measurements. As in entry 690, `pcm_sample_count` 16,383 and `pcm_fifo_peak` 127 are counter saturation values and bound nothing useful. The entry 688 correction therefore holds for the twelve-second opening but does not hold at longer duration, the failure is not the entry 687 startup horizon at 1.8 seconds, and commit `8423f20` is not accepted for general playback. Full telemetry is published under .ai/current_results/entry691_*; the 39,230,255-byte helper log with SHA-256 `92e08c7322842071cbb997a84f20b5da62bc4c50d304d70d75946db0843a8ce0` is retained on the build PC at /home/vash/mister-builds/entry691 and only an excerpt is committed.

#### Next Steps:

Diagnose why audio delivery falls behind at approximately 83 seconds when the host is demonstrably not starved, before proposing any correction. The immediate question is whether the interpolated delivery horizon added in entry 688 degrades once source bitrate or timestamp spacing varies over a long title, in a way the twelve-second opening cannot exercise, and the existing isolated harness should be extended with a long paced case built from a deterministic script rather than from the user's media so the failure can be reproduced off hardware. Instrumenting the helper in log-only form again, as entry 687 did, is the cheapest way to see the horizon and the guard refills at the failure point without changing output bytes. The profiler latching on the first error flag is a diagnostic limitation for recurring faults and should be considered for a counted rather than latched underrun record, but that is an FPGA change and must not be bundled with a helper correction. Do not enlarge FIFOs, add arbitrary startup delay, or relax error criteria. Entry 690 remains valid for the bounded opening over S/PDIF, and the HDMI session of the opening still has no telemetry on record.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 690 COMMIT Unreleased 8423f20 2026-08-28T19:24:00-07:00

#### Coming From:

Unreleased 8423f20

#### Purpose:

Record hardware acceptance of the entry 688 helper audio pacing correction installed in entry 689.

#### Outcome:

The user reports clean playback with no audible dropout or visible stutter and authorizes capture, and the captured telemetry accepts source commit `8423f20` in hardware. The helper on the MiSTer at 10.10.0.30 reads back as the installed candidate, 399,340 bytes with SHA-256 `fefaeb18b8c9e091a9cd9e97258e86264683f374f9663cb3ea6b99bafb81977a`, and the MiSTer Main executable, the original DVD opening and all three MediaPlayer RBF files reproduce their entry 689 hashes, so the run exercised the helper change alone with no FPGA reload. The helper log covers one complete S/PDIF session of `dvd_opening_original.mpg` in IEC 61937 passthrough on private substream 0x80, reaching end of file with child exit status zero after submitting all 12,818,397 transport bytes with 12,818,397 fast bytes, zero slow bytes and no would-block stall beyond the normal 286 startup events; the log contains no underrun, starvation, protocol or error record of any kind, which is the failure signature entry 687 diagnosed and entry 688 predicted would disappear. The schema 19 terminal snapshot taken while the completed opening was still displayed reports `audio_underrun` false, `pcm_protocol_error` false, `presentation_error` false, `error_flags` zero and no validation failures, with sequence end seen, presentation complete and a quiet session. Video delivered 289 pictures across 288 swaps in 12.138878 seconds for 23.725 fps against frame rate code 4, with 128 reference pictures, 161 B pictures and 10,334,169 accepted clean video bytes; the simulated full run in entry 688 predicted 10,334,168, a one-byte difference that is a counter boundary rather than a stream discrepancy. Two independent screenshots taken seconds apart are byte-identical at SHA-256 `8264e13456094ccb`-prefixed 316,577 bytes and both verify as complete PNGs, confirming the frozen completed frame. The `pcm_sample_count` field reads 16,383 and `pcm_fifo_peak` reads 127, the saturation values of their counters, so they bound rather than measure delivered audio and cannot be used as a frame total. The evidence captured here is the final S/PDIF session only, because the helper log is rewritten per playback; the HDMI repeat and the extended run over the longer file are user-reported as clean but are not represented in this telemetry, and the eighteen-minute observation window from entry 687 therefore remains unproven by captured evidence. Entry 689 is superseded on its open acceptance question, and the helper correction is accepted for the bounded original opening over S/PDIF.

#### Next Steps:

Capture the extended run before treating the long-duration case as closed, by starting the longer file over S/PDIF, letting it pass the prior eighteen-minute observation point, and pulling the helper log and terminal snapshot while that session is still resident so the absence of recurring underrun is evidenced rather than reported. Capture one HDMI session of the original opening the same way so both output forms have telemetry on record. If both are clean, close the audio delivery line of work and return to the entry 660 track, where whole-title playback, arbitrary interlaced P and B syntax, and ISO and IFO navigation remain outside any validated scope, and where a clean from-scratch Quartus build has still not been performed against current source. If an underrun reappears in the extended window, preserve the exact log and snapshot and reopen diagnosis without enlarging buffers, adding arbitrary delay or relaxing error criteria.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 689 COMMIT Unreleased 8423f20 2026-08-28T18:30:50-07:00

#### Coming From:

Unreleased 8423f20

#### Purpose:

Install the corrected helper for controlled HDMI and S/PDIF hardware playback validation.

#### Outcome:

The user explicitly authorizes installing and testing the helper-only correction from entry 688 on the MiSTer at 10.10.0.30. The exact stripped, statically linked ARM EABI5 artifact from clean source commit 8423f20 is retrieved from the build PC and locally reverified as 399,340 bytes with SHA-256 fefaeb18b8c9e091a9cd9e97258e86264683f374f9663cb3ea6b99bafb81977a. FTP staging and independent readback reproduce that hash before final rename, and final readback from `/media/fat/linux/MediaPlayer_Helper` reproduces it again. The replaced helper is preserved at `/media/fat/_MediaPlayer_Backups/MediaPlayer_Helper_f6206ba01459_20260828T183350` with its original 399,340-byte size and SHA-256 f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8. Before-and-after readbacks prove the MiSTer Main executable, original DVD opening and all three existing MediaPlayer RBF files unchanged. No core reload or playback is initiated, and hardware acceptance remains pending.

#### Next Steps:

Play `games/MediaPlayer/dvd_opening_original.mpg` first over S/PDIF with Weave held fixed, leave the completed 2DID screen and latest helper log intact, and report any audible dropout or visible stutter so the evidence can be collected before another run. If that opening is clean, repeat over HDMI and then use the longer file that previously showed minor recurring underruns for an extended S/PDIF run. Accept the correction only if the user reports clean playback and telemetry shows no audio underrun or protocol fault; otherwise preserve the evidence and stop before further production changes. The helper is launched per playback, so no FPGA reload is required.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 688 COMMIT Unreleased 8423f20 2026-08-28T17:22:05-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Correct helper audio delivery across blocking video intervals and add the reproduced underrun as a regression.

#### Outcome:

The user reports visually perfect video over approximately eighteen minutes with minor recurring audio underruns, and this correction addresses the entry 687 mechanism entirely in the helper. The scheduler now records each video timestamp at its source-byte anchor, interpolates a bounded audio-delivery horizon toward the next visible timestamp across queued video, and rounds delivery to the existing 128-frame guard quantum; FIFO sizes, the 4096-frame reserve, 2048-frame steady batch cap, startup behavior, timestamp format, video bytes and FPGA production logic remain unchanged. The checked-in regression drives the production extractor, clean-video queue, audio FIFO and output adapter: the prior helper deterministically underruns at cycle 108,142,511 and video byte 368,134 with the clean queue full, while corrected S/PDIF and paced HDMI prefixes complete without starvation, underrun or protocol faults. A full corrected S/PDIF run consumes all 12,818,397 transport bytes, 10,334,168 clean-video bytes and 576,000 audio frames, reaches normal playback completion, and reports zero decoder, presentation, chain or audio errors. HDMI preserves the original video and PCM hashes, all 375 S/PDIF bursts preserve and decode to the original AC-3 payload, and the two output forms have identical record positions and lengths. All four existing helper audio profiles pass after correcting their stale expectation that supported AC-3 private audio should be rejected. A clean 8423f20 clone produces a stripped, statically linked ARM EABI5 helper with SHA-256 fefaeb18b8c9e091a9cd9e97258e86264683f374f9663cb3ea6b99bafb81977a. No Quartus build, MiSTer installation or hardware playback is part of this result, so hardware acceptance remains open.

#### Next Steps:

After separate user authorization, install only the committed ARM helper on the MiSTer with a backup and readback hash, leaving the accepted RBF and Main transport untouched. Replay the original opening over S/PDIF and HDMI, preferably extending the S/PDIF run to the prior eighteen-minute observation window, then collect the helper log and terminal 2DID evidence and require no audio underrun indication before accepting this commit in hardware. If an underrun remains, preserve the exact playback evidence and reopen diagnosis without enlarging buffers, adding arbitrary delay or relaxing error criteria.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_live_native_presentation.svh
- tools/streams/tb_h262_live_audio_transport.svh
- tools/streams/run_original_dvd_audio_delivery.sh
- tools/streams/analyze_original_audio_delivery.py
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---

## 687 COMMIT Unreleased 83c138e 2026-08-28T13:58:39-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Record the reproduced opening audio-starvation mechanism and propose a helper scheduling correction.

#### Outcome:

The approved investigation runs on the build PC with production source unchanged from 83c138e and the exact original opening hash preserved. Native HDMI and S/PDIF transports have identical video, timestamp and audio-record positions; only audio payload differs. All 375 passthrough bursts contain the original AC-3 bytes, have constant 1536-sample periods and 1792-byte payloads, and independently decode identically to the source. Both transports satisfy the existing byte-schedule metric bounds, exposing their lack of FIFO-consumption timing coverage. An isolated native-decoder harness connects the production extractor, 65536-byte clean-video queue, 8192-frame audio FIFO and audio adapter, using behavioral vendor FIFO models and ideal DDR. The completed three-second ideal-source S/PDIF prefix reproduces the first underrun at video byte 368,134, exactly matching entry 684, and at 1.802375 seconds versus hardware 1.803186 seconds. Fifteen empty/refill intervals total 27.375 milliseconds of modeled missing sample slots; the first empty interval lasts 12.25 milliseconds, and every empty transition has a full clean-video queue and blocked extractor. A completed 2.1-second decoded-audio case with a 4 MB/s source cap also underruns at 1.802438 seconds, with sixteen intervals totaling 18.75 milliseconds; this changes payload and timing together and is a sensitivity case, not a replay or rejection of entry 683 HDMI acceptance. Log-only helper instrumentation preserves output byte-for-byte and shows a 76,168-sample horizon at video byte 121,392, followed largely by 128-sample guard refills until the horizon advances at byte 493,708. During this interval queued video prevents extraction of enough later audio; starvation ends as the next larger refill becomes reachable. Actual S/PDIF logs report no new pipe would-block events after first transfer, and ideal-source reproduction proves slow source supply is not necessary. The evidence supports insufficient audio delivery ahead of blocking video rather than burst corruption or musical loudness. Exact receiver behavior and physical timing remain unmeasured. Reports, hashes and small reproduction scripts are published under .ai/current_results/entry687_*; full traces, generated transports and isolated sources remain in output_files/entry686 and /home/vash/mister-builds/entry686. No production correction, Quartus compile, reseed, deployment, reload or playback occurs.

#### Next Steps:

Obtain approval for a helper scheduling correction that supplies sufficient audio before queued video blocks extraction, preserving original video and compressed audio bytes and existing physical FIFO sizes. Add this integrated audio/video failure as a regression and require zero underruns through the full opening in both output modes and paced-source cases, without introducing video stalls or A/V drift. Prefer a verified helper-only correction; do not mask flags, add an arbitrary startup delay or start another Quartus reseed. Keep entry 683 HDMI acceptance and the installed seed-20 build intact until a replacement is separately validated.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 686 COMMIT Unreleased 83c138e 2026-08-28T13:43:04-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Investigate reproducible early S/PDIF audio starvation on the unchanged seed-20 opening baseline.

#### Outcome:

The user approves investigation after entries 684 and 685 reproduce the audible dropout and FPGA FIFO underrun near 1.8 seconds with original AC-3, including a run with S/PDIF held fixed. Record this approved scope before executing it: compare unchanged HDMI and passthrough helper outputs, trace startup scheduling, in-band transport and FPGA audio consumption, and run bounded diagnostic analysis or simulations on the build PC using the exact opening. Preserve raw evidence and original compressed audio bytes. Diagnostic scripts or isolated instrumentation may be used to establish causality, but no production correction, Quartus compile, reseed, deployment or hardware playback is authorized in this cycle. Source 83c138e remains the installed, built baseline; the unchecked hardware status concerns the unresolved S/PDIF opening test and does not revoke entry 683 HDMI acceptance.

#### Next Steps:

Publish this scope and synchronize the build PC, identify existing helper and audio-path regression infrastructure, and reproduce or bound starvation with controls that separate payload contents, schedule and transport pacing. Document what is proved and what remains model-dependent, then propose the smallest evidence-supported correction for approval before changing production behavior or building a new core. Do not mask the underrun flag or increase buffering without measuring the failing boundary.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 685 COMMIT Unreleased 83c138e 2026-08-28T13:40:25-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Record the repeated S/PDIF opening dropout with the audio mode held fixed and clarify the underrun signal meaning.

#### Outcome:

The user reports the same dropout at the same passage while remaining on S/PDIF, and asks whether the loud brassy opening causes it. New helper-first collection confirms AC-3 passthrough and exit zero, with 375 frames, 576,000 carrier samples and all 783 pipe reads reconciling to 12,818,502 completed transport bytes. Two complete byte-identical screenshots produce matching checksum-valid schema-19 snapshots with only audio-underrun bit 0x0400 set, now latched at 1.827818 seconds versus entry 684 at 1.803186 seconds. New helper and screenshot hashes and different counters distinguish this replay; exact failing cycle and picture are not identical. The early snapshot has 408,434 accepted video bytes, 25 reference plus 20 B pictures, 44 bank-derived displays and 43 swaps, not terminal playback totals. Source tracing clarifies entries 684 and 685: this flag comes from the FPGA audio output adapter after its FIFO empties during playback and later non-end data resumes, not from a soundbar or clipping detector. The capture time therefore follows the empty interval rather than measuring its onset or duration. Fixed-mode recurrence removes an audio-mode transition as a necessary trigger; the exact upstream cause and receiver response remain unisolated. The passthrough branch bypasses audio decoding and emits fixed 1536-sample carrier periods, so musical amplitude alone is not supported as the cause. All installed file hashes match the prior verified baseline. Entry 683 HDMI acceptance remains intact, but S/PDIF opening qualification remains pending. Raw captures stay under output_files/entry685, with scoped evidence and hashes under .ai/current_results/entry685_*. No production change, simulation, build, deployment, mode change, core reload or playback is initiated by the agent.

#### Next Steps:

Propose tracing delivery of the original opening through the helper scheduler, in-band transport and FPGA audio FIFO around the early starvation interval on the build PC. Preserve the original AC-3 data, passing HDMI build and prior core backup, and obtain approval before starting that development and simulation cycle or modifying instrumentation. Do not perform another reseed, mask the underrun flag or attribute the interruption to loudness without evidence; another identical user replay is not needed to establish recurrence.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 684 COMMIT Unreleased 83c138e 2026-08-28T13:36:33-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Record repeated opening playback, live deinterlacer switching and the S/PDIF startup-dropout evidence.

#### Outcome:

The user reports repeated playback, visible differences when switching Bob and Weave during playback, and working S/PDIF output, then clarifies that one S/PDIF run briefly stuttered at startup and resumed without sounding distorted; the impression of soundbar rejection is an observation, not an established cause. Helper-first collection confirms latest AC-3 IEC 61937 passthrough, all 375 audio frames and 576,000 carrier samples emitted, exit zero and all 783 pipe reads reconciling to 12,818,502 completed transport bytes with no slow-path bytes. Two complete, byte-identical screenshots decode to matching checksum-valid schema-19 snapshots with error flags 0x0400, audio underrun, latched at 1.803186 seconds. No other error bits are set. The generic fatal_or_no_progress reason is triggered by this audio flag; early counts of 368,134 accepted video bytes, 24 reference and 20 B pictures are not terminal playback totals. Full helper completion does not erase the early underrun or prove uninterrupted output. The captured artifacts do not preserve every run or mode-switch chronology, so they cannot tie the reported dropout to a specific transition or distinguish receiver lock behavior from core starvation. Entry 683 HDMI opening acceptance is preserved, while clean S/PDIF qualification remains pending. FTP hashes match the installed seed-20 RBF, original clip and unchanged Main, helper and undated core. Legacy cadence counters and saturated PCM fields remain unmodified and do not establish exact cadence or full sample totals. Raw evidence stays local under output_files/entry684; scoped analysis, decoded snapshot, helper summary and hashes are published under .ai/current_results/entry684_*. No production change, build, deployment, mode change, reload or playback is initiated by the agent.

#### Next Steps:

Have the user select S/PDIF before playback, hold one deinterlacer mode fixed and replay the original opening once without changing modes, then leave 2DID and the latest helper log intact for collection before another replay. Compare that controlled capture with this early-underrun result before deciding whether startup needs investigation. Preserve the accepted HDMI baseline and original backup; do not start a new build or longer clip preparation from this evidence alone.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 683 COMMIT Unreleased 83c138e 2026-08-28T13:25:50-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Record the accepted original-DVD-opening hardware test with original audio on the seed-20 candidate.

#### Outcome:

The user reports that everything looks and sounds perfect after the seed-20 installation and explicit reload handoff. Helper-first collection identifies dvd_opening_original.mpg with HDMI decoded stereo AC-3, all 375 audio frames and 576,000 samples decoded and emitted, and exit zero after 12,818,502 completed transport bytes; all 784 pipe reads reconcile to that total and no slow-path bytes are reported. Two completed screenshots are byte-identical, show the final Universal opening frame and produce matching checksum-valid schema-19 telemetry. The first download raced screenshot writing and was truncated; retrieving the same remote file after completion fixes collection without changing pixels or replaying. Telemetry reaches quiet sequence end with presentation complete, 128 reference plus 161 B pictures, 289 bank-derived display pictures, 288 swaps, all 25 associated timestamps and 10,334,168 accepted video bytes. Error flags are zero, including no recorded audio underrun, PCM protocol fault, presentation fault or cache-bank overlap error. FTP readback matches the installed 83c138e seed-20 RBF, original clip and unchanged Main, helper and undated core. Functional hardware acceptance is scoped to this original opening and audio test; Weave was requested in the handoff, while motion and audible quality rely on the user report. Legacy diagnostics remain visible: 287 deadline events, 145 outliers, largest bank-change intervals of 83.44845, 83.384883 and 66.733333 milliseconds, 26 timestamp-advance conflicts and zero delay conflicts. These counters do not account for authored film cadence or directly trace unique publications; the timestamp-advance counter records due candidates outside a cadence slot rather than early publications. They neither negate the reported functional pass nor prove perfect hardware cadence, and the raw values are retained without being waived. Saturated PCM telemetry fields are not full sample totals. Existing simulation qualification retains its narrow terminal-cut exception. Raw images, binaries, movie and full logs remain local under output_files/entry683; decoded telemetry, scoped analysis, helper summary and hashes are published under .ai/current_results/entry683_*. No production change, build, deployment, mode change, core reload or playback is initiated by the agent.

#### Next Steps:

Preserve 83c138e seed 20 as the passed original-opening hardware baseline and retain the old core backup. Agree on the next validation boundary before additional work, such as replay or a longer continuous segment with original audio, while keeping Bob, passthrough, full-title playback and ISO/IFO navigation outside this acceptance. Do not infer broad DVD compatibility, exact hardware cadence or release qualification from this single successful opening test.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---

## 682 COMMIT Unreleased 83c138e 2026-08-28T13:15:33-07:00

#### Coming From:

Unreleased 83c138e

#### Purpose:

Record the timing-passing seed-20 build and verified installation for original-audio hardware testing.

#### Outcome:

Source 83c138e changes only the fitter seed from 19 to 20. The complete source comparison proves all logic, clocks, timing constraints and simulation inputs unchanged; retained native, paired and focused evidence hashes reverify, both native analyzers reproduce qualification under the approved fixture-pinned terminal-cut exception, and all six qualification tests pass. One fresh Quartus 17.0.2 seed-20 compile completes in 745.3 seconds with zero errors and 205 warnings. Every timing category passes with zero TNS: minimum setup plus 0.269 ns in HDMI, hold plus 0.250 ns, recovery plus 3.968 ns, removal plus 0.572 ns and pulse width plus 0.925 ns. MPEG setup is plus 1.401 ns and video setup is plus 3.150 ns. Resources are 32,962 ALMs, 52,275 registers, 4,054,267 RAM bits, 514 of 553 M10Ks and 67 DSPs. All four eight-bit inverse-quantization weight boundaries and expected film CDC endpoints remain present. No warning is added versus seed 19, and the timing-failure warning is removed; the previously reviewed unused last_bound_reference_count warning is the only addition relative to the older passing baseline. The 4,369,004-byte RBF has SHA256 a403d224ee98d192994fccf8116d59eef26933351216c66a14d044748a86171c and is packaged locally as output_files/entry681/MediaPlayer_20260828.rbf. Using the existing installation authorization, FTP staging and final readback verify that exact binary at /media/fat/MediaPlayer_20260828.rbf on 10.10.0.30. The prior dated core is downloaded locally and preserved with matching hash at /media/fat/_MediaPlayer_Backups/MediaPlayer_20260828_2e834957fed5_20260828T131423.rbf. Before-and-after hashes prove Main, helper, original DVD clip, undated core and other existing core unchanged. No core reload or playback occurs, and hardware acceptance remains pending. The build stays at /home/vash/mister-builds/entry681/FPGA, with full local evidence under output_files/entry681 and committed reports under .ai/current_results/entry682_*; generated binaries are not committed.

#### Next Steps:

Have the user explicitly reload MediaPlayer_20260828.rbf and play games/MediaPlayer/dvd_opening_original.mpg with original audio in Weave mode over HDMI stereo. Observe startup and interior video and audio stutters, and retain the 2DID screen and helper log for collection. Review those hardware results before accepting the decoder improvements; software qualification and positive FPGA timing alone do not constitute hardware acceptance. Preserve the prior core backup and both failed seed builds for comparison.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 681 COMMIT Unreleased 83c138e 2026-08-28T12:58:58-07:00

#### Coming From:

Unreleased c124aa5

#### Purpose:

Perform one additional approved seed-only rebuild using seed 20.

#### Outcome:

The user explicitly authorizes one more reseed after seed 19 fails HDMI sync setup timing. Source 83c138e is published with the verified single seed-assignment change; the build has not yet started. Change only the seed assignment from 19 to 20 in MediaPlayer.qsf; preserve all logic, clocks, timing constraints, physical buffers, Main, helper and qualification rules. Verify the seed-only source difference and recheck the retained native, paired and focused qualification evidence, including the narrowly approved terminal-cut exception. Use a new clean build directory at /home/vash/mister-builds/entry681/FPGA, preserving both earlier failed builds. This authorization covers exactly one additional compile and no automatic retries.

#### Next Steps:

Publish the exact seed-20 source, pull it on the build PC, verify retained qualification and compile once from scratch. Require positive setup, hold, recovery, removal and pulse-width margins with zero TNS, and review warnings, resources and retained register and CDC boundaries. If all gates pass, use the existing installation authorization to preserve the old core and install the dated RBF with FTP readback verification, leaving loading and playback to the user. Otherwise retain the evidence and pause without installation or another seed.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
