## 648 COMMIT Unreleased 5fb7d5d 2026-08-27T21:08:11-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Recover M10K blocks by widening the P and B residual coefficient memories to the Cyclone V native twenty-bit mode.

#### Outcome:

This entry is written as a plan and its commit does not exist yet. Investigation of the Aug 26 fitter report establishes that block-memory efficiency in this design is governed by data width rather than by capacity. A Cyclone V M10K holds 10,240 bits but reaches that only in the five, ten and twenty bit modes that use the parity bits; narrower widths cap at 8,192. Measured across every inferred memory in our own build, widths of twenty and forty achieve 10,240 bits per block while widths of one, sixteen, nineteen and thirty-five achieve exactly 8,192, and the existing twenty-bit `residual_block_mem` is the one memory already at full efficiency. Two memories dominate: `residual_coeff_mem` in the P path and its counterpart in the B path, each declared nineteen bits deep by 32,768 entries and each costing 76 blocks against a theoretical 64. Padding both to twenty bits is expected to recover roughly twelve blocks each, about twenty-four in total, against the 41 free blocks recorded in entry 609. The change is a pure width change with no functional effect: both paths store a six-bit coefficient index in bits eighteen down to thirteen and a signed thirteen-bit level in bits twelve down to zero, every consumer slices those fields explicitly, and the nineteen-bit write expressions zero-extend into the wider word. Four declarations change, being each memory and its read register, and no consumer is touched. Two candidates found during the same investigation are deliberately excluded. The audio `pcm_fifo` would yield only three blocks and would require padding and slicing a `dcfifo` on an audio path already qualified and shipped in v0.8.0, which is a poor trade against re-qualification. Folding the P path's separate one-bit `residual_coeff_last_mem` into the new bit nineteen would eliminate a further four-block memory, but that flag is written retroactively at address `count` minus one, decoupled from the coefficient write, so it needs a read-modify-write or a second port and is design work rather than padding. Both remain available later. Nothing is built or changed yet, so both status boxes are unchecked, and the recovery figure is a prediction from the report rather than a measured fit result.

#### Next Steps:

Make the four declaration changes, commit them as the source commit for this cycle, and replace this entry's placeholder hash. Then build on the build PC and compare the fitter report against the shipped v0.8.0 figures of 31,464 ALMs, 512 of 553 M10K and positive 0.243 nanoseconds setup, confirming that M10K falls by approximately twenty-four blocks, that the two memories now report 10,240 bits per block, and that no timing category regresses. Treat an unchanged block count as the inference not selecting twenty-bit mode rather than as a disproven finding, and inspect the implementation width before making any further change. Because HDMI setup has roughly two percent headroom and responds to placement, a negative setup result should be met with a reseed rather than a restructure, consistent with the position recorded in the entry 370 cycle. Hardware validation needs a decode regression proving the residual path is unaffected, since a mis-sliced coefficient would corrupt picture content rather than raise an error flag. Keep the recovered blocks unallocated until interlaced sub-gate scoping decides what they fund; the entry 608 buffer deepening at roughly twenty-six blocks and the remaining interlaced gates of entry 609 are both candidates and neither is approved. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh

#### Status:

- [ ] Built
- [ ] Passed

---

## 647 COMMIT Unreleased 2045c34 2026-08-27T20:26:43-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Close the seven-fixture Buildroot beta matrix with AC-3 S/PDIF passthrough and record the user's acceptance.

#### Outcome:

The user reports the run was perfect and the woofer channel audible. Helper-first retrieval preserved a log distinct from both the entry 645 decode run and the entry 646 DTS run, verified by hash before the screenshot was taken. The helper identifies the correct fixture, reports `spdif` IEC 61937 passthrough, locates AC-3 on private substream `0x80` rather than the decoded stereo mode of entry 645, carries 375 audio frames and 576,000 emitted samples as the burst carrier, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,835 completed transport bytes with no acknowledged fallback payload and zero slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault at FIFO peak 127, zero timestamp conflicts of either kind, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. Every one of those counters matches the standard-MiSTer capture in entry 627, including identical video bytes, AC-3 frame count, emitted samples, transport bytes and pipe reads, and the final raster is pixel-identical across all 280,064 pixels outside the telemetry overlay. Only delivered frames per second differs. Entry 627 captured this run before installing the current Main and reports profile version one `credit_fast_v1` against this run's version two, so transport-layer timing figures are not comparable while the counters are. The audible LFE matches AC-3 S/PDIF behaviour on standard MiSTer recorded in entries 621 and 626 and contrasts with entry 646, where the same receiver does not reproduce DTS LFE despite measured content in the bursts, confirming that observation as a device property rather than an output-path fault. With this run the matrix is complete and the user accepts it. That acceptance covers the seven fixtures and their modes on the pinned beta using unchanged v0.8.0 binaries, and nothing further: the unisolated test-four screenshot variation, the unchecked filesystem dirty flag, the uncontrolled boot-time input warnings, the single-frame scope of every pixel comparison, and the older-Main provenance of the entry 626 and 627 audio baselines all remain explicitly outside it. A one-page findings report was written for the Buildroot maintainer and moved by the user to a local path for private delivery; it is not committed to the repository and states these same limits. Built remains unchecked because no new build occurs.

#### Next Steps:

Decide whether the findings report should be committed to the repository or remain a private communication, since it currently exists only outside version control. If the collaboration proceeds, re-running this matrix against future beta drops is cheap because the fixtures and capture script are deterministic and committed. The unisolated test-four screenshot variation and the filesystem dirty-flag warning remain open and should each be scoped as their own investigation with user approval rather than folded into any future acceptance. The longer-term question of retiring the ARM helper by moving source, demux, timeline and audio codec responsibilities onto the platform stays a discussion item and not approved work. The next MediaPlayer development milestone remains unapproved and should be scoped separately, with the interlaced decoding gaps of entry 609 still open and out of scope. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 646 COMMIT Unreleased 2045c34 2026-08-27T20:14:53-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate DTS S/PDIF passthrough on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports test six works perfectly and clarifies that the woofer did not play. Helper-first retrieval preserved a log distinct from the test five capture, followed by a fresh uniquely named screenshot. The helper identifies the correct fixture, reports `spdif` IEC 61937 passthrough for AC-3 and DTS, locates DTS on private substream `0x88`, carries 1125 audio frames, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,868 completed transport bytes with no acknowledged fallback payload and zero slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,038 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault at FIFO peak 127, zero timestamp conflicts of either kind, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. Comparison against the standard-MiSTer capture in entry 626 matches on every completion, error, cadence and audio counter, including identical video bytes, DTS frame count, emitted sample count, transport bytes and pipe reads; only delivered frames per second differs, by under two thousandths of a frame per second. As with entry 645, entry 626 predates the current Main and reports profile version one `credit_fast_v1` against this run's version two `credit_step_v1`, so transport-layer timing figures between them are not comparable while the counters are. The final raster is pixel-identical to the standard baseline across all 280,064 pixels outside the telemetry overlay. This entry corrects a prediction stated before the run: passthrough was expected to emit no PCM, but IEC 61937 carries the compressed bursts inside the PCM stream, so the 576,000 emitted samples are the burst carrier rather than decoded audio, and the standard baseline reports the identical figure. The absent woofer is the receiver behaviour already recorded in entries 621 and 626, where measurement established LFE present in the emitted bursts at 1267.3 RMS, so it remains a device observation rather than a core limitation or a Buildroot regression. Passed records this functional test only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local and only `.ai/current_results/entry646_buildroot_test6_dts_spdif_status.json` is published.

#### Next Steps:

The core is already in S/PDIF, so replay test_5_audio_ac3_51.mpg in that mode to close the last untested path in the seven-fixture matrix, retaining its helper log before another file overwrites it and taking a separate uniquely named screenshot; entry 627 holds the standard-MiSTer AC-3 S/PDIF baseline. Expect the helper to report passthrough on substream `0x80` rather than the decoded stereo mode of entry 645, and expect a non-zero emitted sample count as the IEC 61937 carrier. Progressive is already covered by entry 639 for I/P/B and entry 644 for all-I and needs no replay. Once that run is accepted the user may declare the matrix accepted, which should be recorded as acceptance of the seven fixtures only, with the unisolated test-four screenshot variation and the unchecked filesystem dirty flag carried forward as separate open items explicitly outside that scope. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 645 COMMIT Unreleased 2045c34 2026-08-27T20:03:12-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate AC-3 5.1 decode to HDMI on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports test five passes everything. Helper-first retrieval preserved the log before any further playback, followed by a fresh uniquely named screenshot. The helper identifies the correct fixture at `games/MediaPlayer/Buildroot_beta/test_5_audio_ac3_51.mpg`, reports HDMI decoded stereo PCM, locates AC-3 on private substream `0x80`, decodes 375 audio frames to 576,000 samples and emits all 576,000, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,835 completed transport bytes with no acknowledged fallback payload and no slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero timestamp advance and delay conflicts, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. The fixture shares test one's bar video by design, which is why its accepted video byte count matches entry 640 exactly; that is the generator's definition rather than a repeat of the entry 639 stale-fixture error. Comparison against the standard-MiSTer capture in entry 626 matches on every completion, error, cadence and audio counter, including identical video bytes, AC-3 frame count, emitted samples, transport bytes and pipe reads; only delivered frames per second and cadence seconds differ, by about 1.3 milliseconds across a twelve second run. Entry 626 was captured under the older profile version one `credit_fast_v1` transport while this run uses profile version two `credit_step_v1`, so transport-layer timing figures between them are not comparable. The final raster is pixel-identical to the standard baseline across all 280,064 pixels outside the telemetry overlay; this is a single-frame comparison on static bar content and does not isolate the entry 644 progressive screenshot variation nor establish full playback pixel qualification. Independent read-only readback confirms the unchanged Main, helper, RBF, kernel and this fixture against the card manifest. Bob was the requested deinterlacer and the audible channel sweep relies on the user's report, since telemetry attests neither. The user hears the channel sweep reproduce correctly and reports the soundbar's woofer working properly, which confirms that low frequency content survives the downmix. It does not establish LFE delivery over HDMI: the AC-3 stereo downmix discards LFE by design, so the woofer output is the soundbar's own bass management applied to the stereo pair, and discrete LFE remains a question for the S/PDIF passthrough run. Passed records this functional test only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local and only `.ai/current_results/entry645_buildroot_test5_ac3_hdmi_status.json` is published.

#### Next Steps:

Switch the core's audio mode to S/PDIF and replay test_5_audio_ac3_51.mpg as an AC-3 passthrough run, retaining its helper log before another file overwrites it and taking a separate uniquely named screenshot; entry 627 holds the standard-MiSTer S/PDIF baseline for that comparison. Then run test_6_audio_dts_51.mpg as DTS S/PDIF passthrough to close the seven-fixture matrix. Expect the passthrough runs to report no decoded PCM, so do not treat an absent sample count as a fault. Keep overall beta qualification open until both remaining audio runs are accepted, and retain the unisolated test-four screenshot variation and the unresolved filesystem dirty-flag check as separate open items rather than folding either into this result. Do not begin a source fix or attribute anything to Buildroot without evidence and approval for a revised plan. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 644 COMMIT Unreleased 2045c34 2026-08-27T19:55:50-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate progressive all-I test four with user-reported Weave and HDMI audio on the Buildroot beta.

#### Outcome:

The user reports everything passes in Weave. Helper-first retrieval and a fresh screenshot confirm the correct fixture and valid schema-19 telemetry: 360 reference and displayed pictures, zero B pictures, 359 swaps, 12,057,601 accepted video bytes, zero decoder or presentation errors, no audio underrun or PCM protocol fault, sequence end and quiet completion. Six timestamp-advance conflicts, zero delay conflicts and zero native deadline-gap and gap-outlier counters match entry 628's standard-MiSTer test-four rerun. Largest display intervals are about 49.7 milliseconds on both systems; zero native deadline-gap counters do not establish perfect progressive cadence. The helper confirms HDMI decoded output, 576,000 emitted PCM samples and exit zero; all 888 pipe reads reconcile to 14,546,422 completed transport bytes without acknowledged fallback payload. Readback verifies the unchanged runtime, kernel and fixture, and the comparator's Main, RBF and fixture identities match. An additional final-raster comparison is inconclusive: outside telemetry, the first screenshot differs from the standard baseline at 8,820 of 433,920 pixels, all at x modulo eight equal to one. A second screenshot without replay differs from the first at 4,418 pixels and from the standard at 8,816, with unchanged telemetry and helper log. The source of this variation is not isolated, so neither pixel equivalence nor a Buildroot regression is established. Weave selection and appearance rely on the user's report. Passed records functional acceptance only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local; only .ai/current_results/entry644_buildroot_test4_status.json is published.

#### Next Steps:

Run test_5_audio_ac3_51.mpg with Bob and HDMI audio, then retain the completed screen for collection before testing AC-3 S/PDIF and DTS S/PDIF separately. Confirm the expected audible channel sweep; the HDMI downmix intentionally omits LFE. Keep overall beta qualification open pending the remaining audio matrix, and retain the unisolated test-four screenshot variation as a separate video-quality caveat alongside the unresolved filesystem dirty-flag check. Do not begin a source fix or attribute either observation to Buildroot without evidence and approval for a revised investigation. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 643 COMMIT Unreleased 2045c34 2026-08-27T19:51:27-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate test three's separate Weave and HDMI playback on the Buildroot beta.

#### Outcome:

The user explicitly reports completing Weave with everything passing. Helper-first retrieval preserves a log distinct from the Bob run, followed by a fresh uniquely named screenshot. Valid schema-19 telemetry confirms 360 reference and displayed pictures, zero B pictures, 359 swaps and 12,073,185 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are absent; the three largest recorded display intervals are each 2,002,000 clocks. Sequence end, completed presentation and quiet termination are asserted. Helper exit is zero, all 889 pipe reads reconcile to 14,562,019 completed transport bytes, and no acknowledged fallback payload is reported. HDMI decoded output and 576,000 emitted PCM samples are confirmed. Completion, error and cadence counters match the Bob run; scaler selection and appearance rely on the user's report rather than telemetry. Readback verifies the unchanged Main, helper, RBF, kernel and fixture. Both requested test-three modes now have separately captured accepted runs. Passed is scoped to Weave; Built remains unchecked because no new build occurs. No deployment, playback, mode change, reload or reboot is initiated by the agent. Raw captures stay local; only .ai/current_results/entry643_buildroot_test3_weave_status.json is published.

#### Next Steps:

Run test_4_progressive.mpg with HDMI audio and preserve its completed screen for separate helper-first collection. Then complete AC-3 HDMI decode, AC-3 S/PDIF passthrough and DTS S/PDIF passthrough as separate runs. Keep overall beta qualification open until the remaining matrix is accepted and the storage dirty-flag warning as a separate unresolved filesystem check. Preserve unchanged runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 642 COMMIT Unreleased 2045c34 2026-08-27T19:45:33-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate test three's requested Bob and HDMI playback on the Buildroot beta.

#### Outcome:

The user reports test three passes. Helper-first retrieval and a fresh screenshot identify the scrolling-band fixture and provide valid schema-19 telemetry with 360 reference and displayed pictures, zero B pictures, 359 swaps and 12,073,185 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are absent. All three largest recorded display intervals are 2,002,000 clocks, with sequence end, completed presentation and quiet termination asserted. Helper exit is zero and all pipe reads reconcile to 14,562,019 completed transport bytes, without acknowledged fallback payload. HDMI decoded output is confirmed; Bob was requested and the user accepts that run, but telemetry does not independently identify the scaler selection or LED colors. The helper reports 576,000 emitted PCM frames. Independent readback confirms the fixture and unchanged Main, helper, RBF and kernel. Passed is scoped to the requested Bob test; no new build occurs, so Built stays unchecked. No deployment, mode change, reload, reboot or playback is initiated by the agent. Raw data remains in ignored local results and only .ai/current_results/entry642_buildroot_test3_bob_status.json is published.

#### Next Steps:

Switch HDMI scaler deinterlacer to Weave and replay test_3_deinterlace_bob_weave.mpg with HDMI audio, preserving a separate helper log and fresh terminal screenshot afterward. The user must judge the deinterlacing appearance because the terminal telemetry does not identify the HDMI scaler mode. Then complete the progressive all-I test four and separate AC-3 HDMI, AC-3 S/PDIF and DTS S/PDIF runs. Keep the storage dirty-flag warning as a separate unresolved check and leave overall beta qualification open until the matrix is complete. Preserve runtime identities, user control of hardware lifecycle, local-only raw captures, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 641 COMMIT Unreleased 2045c34 2026-08-27T19:42:33-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate corrected interlaced BFF playback on the Buildroot beta.

#### Outcome:

The user reports that corrected test two passes. Helper-first collection and a fresh uniquely named screenshot identify that exact run, with valid schema-19 telemetry confirming bottom-field-first signalling, 360 reference and displayed pictures, zero B pictures, 359 swaps and 3,067,813 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are all absent. The three largest recorded display intervals are each the nominal 2,002,000 clocks, and sequence end, completed presentation and quiet termination are asserted. Helper exit is zero; pipe reads reconcile to all 5,556,652 completed transport bytes, with no acknowledged fallback payload. The helper confirms HDMI decoded audio and reports 576,000 emitted PCM frames. Bob was requested and the user accepts the requested run, but telemetry does not independently identify the scaler selection or LED colors. Read-only verification confirms the corrected fixture and unchanged Main, helper, RBF and kernel hashes. Together with entry 640, both interlaced field orders now have accepted bounded playback runs on the beta, alongside entry 639's progressive I/P/B result. No source, build, deployment, mode change, reload, reboot or playback is initiated by the agent. Built remains unchecked because no new build occurs; Passed is scoped to this BFF clip. Raw captures remain local and only .ai/current_results/entry641_buildroot_test2_status.json is published.

#### Next Steps:

Run test_3_deinterlace_bob_weave.mpg with Bob and HDMI first, retain its helper log and terminal screenshot, then repeat in Weave with separate captures. Finish test four's progressive all-I control and the AC-3 HDMI, AC-3 S/PDIF and DTS S/PDIF runs before claiming the full seven-fixture compatibility matrix. Keep the filesystem dirty-flag warning as a separate unresolved check and do not treat single-run timing values as performance qualification. Preserve the tested beta and runtime identities, user control of hardware lifecycle, local-only raw reports, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 640 COMMIT Unreleased 2045c34 2026-08-27T19:39:38-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate the corrected interlaced TFF playback fixture on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports that corrected test one now passes. Helper-first collection and a fresh uniquely named screenshot confirm that exact file completed under the unchanged released runtime. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, no decoder or presentation error, no audio underrun or PCM protocol fault, zero timestamp conflicts, zero missed native display deadlines and no gap outliers. Each of the three recorded largest display intervals is the nominal 2,002,000 clocks. Sequence end, presentation completion and quiet termination are set. Helper exit is zero and all pipe reads reconcile to 5,556,849 completed transport bytes. HDMI decoded audio is confirmed by the helper; Bob was the requested setting and the user reports passing that run, but the telemetry does not independently attest the scaler setting or LED colors. Independent readback confirms the corrected fixture, RBF, Main, helper and kernel identities. Completion, error and native-cadence indicators match the recorded standard-MiSTer test-one result. Combined with entry 639, this establishes successful bounded interlaced all-I and progressive I/P/B runs on the beta; it is not the full compatibility matrix. No build, deployment, mode change, reload, reboot or playback is initiated by the agent. Built stays unchecked because no new build occurs; Passed records only this user-accepted TFF test. Raw captures and detailed comparison remain local, with only .ai/current_results/entry640_buildroot_test1_status.json published.

#### Next Steps:

Continue with corrected test_2_interlace_bff.mpg under the same requested Bob and HDMI settings, capture it before another file overwrites its helper log, then qualify Bob versus Weave and the AC-3 decode, AC-3 passthrough and DTS passthrough modes separately. Keep the initial single-frame progressive pixel comparison distinct from comprehensive video quality and do not infer performance improvements from one run's timing values. The storage dirty-flag warning remains a separate unresolved check. Preserve the known runtime and beta identities, user control of hardware lifecycle, local-only raw reports, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 639 COMMIT Unreleased 2045c34 2026-08-27T19:36:01-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Capture the beta's progressive playback result and correct the stale bar fixtures mistakenly selected during card preparation.

#### Outcome:

The user reports stationary bars in tests one and two, then leaves test seven displayed and describes behavior as matching standard MiSTer. Helper-first collection and a uniquely named screenshot preserve that run without a reload. Valid schema-19 telemetry shows all 360 progressive pictures displayed, comprising 121 reference and 239 B pictures, with 359 swaps, zero decoder or presentation error, no audio underrun or PCM protocol fault, sequence end and quiet completion. Helper exit is zero and the pipe reads reconcile exactly to the completed transport. Comparison with the recorded standard-MiSTer run uses the same test-seven file and runtime hashes: completion indicators, the existing timestamp-conflict count and gap-outlier count agree, while individual timing measurements differ. The final raster is pixel-identical outside the telemetry rectangle, which is a single-frame comparison rather than full playback pixel qualification or a performance benchmark. The stationary bars are an agent preparation error: entry 636 copied superseded pre-fix files, and entry 638 checked their hashes against the stale manifest instead of verifying corrected content. Both old tests contain 360 identical decoded frames and 360 I-pictures, so the defect is authored content, not a requirement for interlaced P/B support. The already-qualified corrected files from source 140a5b7 are rechecked against entry 624's manifest, including every temporal field position for each bar fixture, and only tests one, two, five and six plus their manifest and explanatory metadata are replaced through verified staging and fresh readback. Tests three, four and seven and all runtime/OS binaries remain unchanged; all twenty-three current manifest checks pass and the captured test-seven helper log remains unchanged. The historical pre-boot manifest is retained and explicitly labeled as predating this correction. No new source, build, reboot, reload or playback is performed by the agent. Raw captures and detailed diagnostics remain in ignored local results; only .ai/current_results/entry639_buildroot_playback_status.json is published. The progressive compatibility result is positive, but overall hardware acceptance stays open pending corrected interlaced and remaining audio tests.

#### Next Steps:

Replay only corrected test_1_interlace_tff.mpg with Bob deinterlacing and HDMI audio, leaving synthetic audio and native timing patterns off, and retain the completed core state for helper-first collection and a fresh terminal screenshot. Confirm moving fields, audible tone, menu response and all three LEDs before widening the matrix. The corrected file requires only the supported interlaced all-I path; interlaced P/B remains unsupported and out of scope. Preserve the beta and original-runtime identities, the separate unresolved filesystem warning, local-only raw reports, restricted core.md and the forty-entry ring. Do not misclassify the stale-fixture observation as a new OS or FPGA regression or claim comprehensive compatibility from one progressive clip.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 638 COMMIT Unreleased 2045c34 2026-08-27T19:26:03-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Record the user's input clarification and prepare the first isolated playback check on the Buildroot beta.

#### Outcome:

The user attributes the startup input difficulty to local device selection and reports that the MiSTer worked normally, so the earlier input warnings are not recorded as a confirmed beta regression. The user requests a single-file playback experiment. Read-only preflight confirms that test_1_interlace_tff.mpg still matches its existing generation manifest and contains the expected 360-picture, approximately twelve-second test. The selected boundary is the unchanged released runtime, Bob deinterlacing and HDMI audio, with synthetic audio and native timing patterns disabled. No playback is started remotely and no new playback result or helper capture is available at this point. No source, runtime, kernel or filesystem changes are made, no build occurs, and hardware playback acceptance remains open.

#### Next Steps:

The user loads MediaPlayer_20260827.rbf, selects the agreed modes and plays only test_1_interlace_tff.mpg from games/MediaPlayer/Buildroot_beta. After completion, leave the core loaded and do not start another file or reload it; report motion, sound, menu response and all three LEDs. Retrieve the helper log before it is overwritten and obtain a fresh terminal screenshot while the completed core state still exists, before returning to Scripts or otherwise changing cores. Review the 360-picture completion, transport accounting and cadence before widening the test matrix. Keep the filesystem warning as a separate unresolved check, keep raw device reports local, and preserve user control of hardware lifecycle and restricted core.md.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 637 COMMIT Unreleased 2045c34 2026-08-27T19:21:47-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Record the first QMTech boot capture under the pinned Buildroot beta and identify the remaining compatibility gates.

#### Outcome:

The user boots the prepared card and runs the capture script. Read-only retrieval confirms the pinned Linux 6.18.46 kernel, the expected memory limit, network reachability and all twenty-three runtime-manifest checks; independent readback matches the prepared Main, helper, RBF, kernel and manifest. No playback evidence is present. The script's zero status covers its narrow checks and does not classify kernel warnings. A dirty-volume warning remains uninvestigated by a filesystem scan and does not by itself establish corruption. Input initialization warnings occurred while the user was switching USB controllers and keyboards to find a working device, so the capture is not a controlled peripheral regression test and no final working input combination is confirmed. Raw device and network details remain in ignored local results; only a minimal summary is published as .ai/current_results/entry637_buildroot_boot_status.json. No device writes, repairs, reboot, source changes or new build are performed. Basic OS bring-up is established, while hardware playback acceptance remains unchecked.

#### Next Steps:

Confirm the final working input device and use that stable configuration for the agreed first playback: test_1_interlace_tff.mpg with HDMI audio and Bob mode. Preserve the helper log and a fresh terminal screenshot before another playback, and record selected modes, LEDs, sound, motion and menu response. Keep the dirty-volume warning open for a separately controlled filesystem check; do not repair a mounted filesystem or trigger a reboot automatically. MediaPlayer FPGA transport, cadence and audio/video correctness remain unqualified until playback evidence is reviewed. Keep raw device reports local unless the user explicitly approves publication, preserve the original working card and user control of hardware lifecycle, and maintain restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 636 COMMIT Unreleased 2045c34 2026-08-27T19:05:44-07:00

#### Coming From:

Unreleased 036252a

#### Purpose:

Prepare an isolated Buildroot MiSTer compatibility experiment using the unchanged v0.8.0 runtime.

#### Outcome:

Source 2045c34 adds the bounded environment and helper-log capture script, which passes host shell syntax and syntax under the actual beta image's ARM BusyBox shell. The isolated build-PC investigation pins mcfbytes/Buildroot_MiSTer v2026.08.25-beta at 1f15c25, verifies its archive, rootfs, kernel and configuration hashes, and selects normal Linux 6.18.46 with glibc 2.43 rather than RT. The unchanged released v0.8.0 Main passes all fifteen upstream ABI checks with zero failures or skips: its twelve libraries resolve, and unprivileged QEMU startup reaches the expected denied /dev/mem access. A separate loader trace succeeds, and the released static ARM helper successfully processes the existing AC-3 HDMI and DTS passthrough fixtures under QEMU. These are userspace checks against the build PC's kernel, not execution of the beta kernel or FPGA validation. At the user's explicit direction, all old files on the identified removable card's data partition are removed without backup; the existing partition layout and raw bootloader partition are not rewritten. The clean card receives the pinned rootfs and kernel, the three unchanged release binaries, the current MiSTer's menu and boot MAC copied by read-only FTP, default settings without the old ConsoleMode redirect, all seven hash-verified 360-picture fixtures, the capture script, provenance and instructions. After a fresh read-only remount, all twenty-eight files totaling 606,264,008 bytes match their prepared hashes, partition boundaries are unchanged, no unexpected files remain, and the card is safely unmounted. Pre-boot checks include linux.img; runtime checks exclude that image and editable boot/display settings because a login remounts the rootfs writable. No installer, updater, updateboot, repartitioner, production write, reboot or playback is performed. No new FPGA or ARM build occurs and hardware acceptance remains open, so both status boxes are unchecked. Detailed hashes, ABI output, helper results and card verification are retained in .ai/current_results/entry636_buildroot_compatibility.json.

#### Next Steps:

The user powers down the QMTech, inserts the prepared card and boots it, then runs Scripts/Buildroot_Compatibility.sh to retain the environment report and confirm kernel 6.18.46, mem=511M, runtime hashes and network access. Start MediaPlayer_20260827.rbf with test_1_interlace_tff.mpg from games/MediaPlayer/Buildroot_beta, HDMI audio and Bob mode, recording menu response, motion, sound and all three LEDs; preserve its helper log and a fresh terminal screenshot before another playback. Only after basic bring-up succeeds continue the remaining TFF/BFF, Bob/Weave, progressive I/P/B, AC-3 decode and AC-3/DTS passthrough matrix. The real FPGA bridges, memory reservation, cadence, peripheral behavior and QMTech-specific boot remain unqualified despite the userspace pass. Keep ordinary update scripts out of this experiment because they may overwrite patched Main or Linux; rollback is a powered-off swap to the untouched original working card. Record subsequent hardware evidence in a new entry, retain the forty-entry ring and restricted core.md, and leave broader decoder development out of scope.

#### Files Modified:

- tools/streams/capture_buildroot_environment.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 635 COMMIT Unreleased 036252a 2026-08-27T18:37:08-07:00

#### Coming From:

v0.8.0 af43de2

#### Purpose:

Reconcile the current documentation and published release text with the verified v0.8.0 state.

#### Outcome:

Published documentation commit 036252a reconciles the README, changelog, current build and architecture guides, v0.8.0 release notes and hardware instructions with the actual release. It replaces stale v0.7.0 qualification figures, labels older design and regression procedures as historical, corrects the tag and ZIP-size descriptions, and records the current seven-test and profile-version-two collection workflow. Historical versioned notes, old regression checksums and retained settled log entries remain unchanged. The suite generator changes only its module documentation, comments and descriptive accepted_video manifest label so progressive test seven is no longer described as all-I; an AST comparison confirms that media-generation logic is unchanged. Main is correctly described as passing the core's audio mode to the helper, rather than creating the core menu option. The unsupported-private-audio claim is removed for the supported AC-3/DTS paths, and synthetic AC-3 comparison figures are distinguished from the commercial-track results. The documentation now acknowledges entry 628's measured hardware-screenshot pixel comparison while leaving comprehensive playback pixel qualification and the chroma root cause open. It also narrows entry 634's shorthand about tested runtime hashes: tests one through six were initially captured with older Main, while the final Main was tested separately on test one and subsequent progressive runs; RBF/helper hashes match throughout. Twenty local links and anchors and eighteen shell blocks pass structural or syntax checks, Python syntax and the actual manifest expression pass, and documented runtime/ZIP hashes and sizes match the public-package audit. GitHub release text is updated from the committed notes with its Full Changelog destination retained, and a fresh readback matches exactly after newline normalization. Title, publication time, tag, pre-release flags and asset metadata are unchanged, and remote tag object and target remain the original values. The forty-entry core-syntax audit passes with no unresolved proposal. No new media, runtime binaries, build, device capture, deployment or playback is produced. Built refers to the existing reproduced binaries and successful Python syntax check, not a new Quartus run; hardware Passed remains unchecked. Bounded verification evidence is retained as .ai/current_results/entry635_documentation_audit.json.

#### Next Steps:

Documentation cleanup and publication recording are complete. Confirm with the user whether the final package-install hardware run occurred before recording that gate as passed; do not infer a run from identical binary hashes. The next development milestone remains unapproved and should be scoped separately, with the broader interlaced decoding gaps, memory headroom and scaler timing risk visible. Leave the published v0.8.0 tag and ZIP intact, keep the current Unreleased changelog section for subsequent work, preserve restricted core.md and the forty-entry ring, and retain user control of deployment and hardware lifecycle.

#### Files Modified:

- README.md
- CHANGELOG.md
- docs/RELEASE_NOTES_v0.8.0.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- docs/MPEG2_NEW_DECODER.md
- host/arm/ARCHITECTURE.md
- tools/streams/generate_test_suite.py

#### Status:

- [x] Built
- [ ] Passed

---

## 634 VERSION v0.8.0 af43de2 2026-08-27T18:29:23-07:00

#### Coming From:

Unreleased 035807a

#### Purpose:

Record the published v0.8.0 pre-release and verify its public package against the qualified artifacts.

#### Outcome:

GitHub reports MiSTer Media Player v0.8.0 published at 2026-08-27T17:41:16-07:00 as a non-draft pre-release. Its annotated tag resolves to af43de2, not the 035807a documentation commit requested by entry 633; the intervening source difference is only the release-notes file and project log, with no runtime change. The public ZIP downloads successfully, passes its CRC checks and has SHA256 5f55b49eb863f74a777b548b4f42b744a9130b4161f176b687ca297deeffcaf3, matching entry 632. Its compressed size is 2,867,028 bytes; entry 632's 5,948,567-byte figure is the total uncompressed member size, not the archive size. All eight payload and documentation hashes match entry 632, and the internal SHA256SUMS file matches its retained copy exactly. The RBF, Main and helper therefore match the qualified source baseline 2f1d32c. Publication is verified separately from hardware acceptance: the existing hand tests used these runtime hashes, but a confirmation run following installation from the final package remains unrecorded. No new build, device capture, deployment or playback is performed. Built refers to the previously reproduced runtime artifacts and Passed remains unchecked for that outstanding confirmation. Evidence is retained in .ai/current_results/entry634_release_audit.json; the published tag and assets are preserved.

#### Next Steps:

Complete the user-requested documentation cleanup, describing the actual published tag and source baseline without moving the tag or replacing assets, and record corrections in new log entries rather than rewriting settled history. Update current guides that still describe v0.7.0 or completed features as future work, distinguish the entry 628 hardware pixel comparison from comprehensive pixel qualification, and preserve unsupported-feature and timing limitations. Confirm the final package-install hardware run with the user before claiming that gate passed. Leave the next development milestone unapproved and maintain restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 633 COMMIT Unreleased 035807a 2026-08-27T17:31:09-07:00

#### Coming From:

Unreleased a26791f

#### Purpose:

Write the release notes for the version the user is publishing.

#### Outcome:

Published source `035807a` adds the release notes under docs, following the structure of previous releases so the set reads consistently: highlights, the matched runtime files with sizes and hashes, the supported subset, known limitations, reproducible qualification, Quartus and timing, host and audio regressions, hardware evidence, and packaging. Two departures from the previous release's notes are deliberate. The supported subset is stated as two separate paths rather than one, because progressive decodes I, P and B pictures while the interlaced path is restricted to I-pictures only at 720x480 and `30000/1001`, frame structured with frame DCT, and presenting them as a single envelope would misdescribe both. The limitations section names what is rejected before decode, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, and states the consequence plainly, that most commercial DVDs use several of these and will not play. Four things are recorded that a release document could easily have omitted: that playback pixel accuracy has never been qualified because every previous comparison ran in simulation, that sharp colour transitions carry one blended column an independent decoder does not produce, that the repeated frame on high peak pictures is a buffer depth property rather than a stream fault, and that the framework scaler retains little setup margin and may be exposed again by the next change of comparable size. The hardware evidence section separates measured claims from reported ones, so decoder comparison figures and user listening reports are not conflated, and records the receiver that reproduces LFE from AC-3 but not DTS as a device observation rather than a core limitation. The notes are a documentation commit and do not alter any binary, which the provenance file already states; the tag should nevertheless point at this commit rather than an earlier one so the published documentation state includes them.

#### Next Steps:

The user tags and publishes from commit `035807a`, marking the release pre-release because the project remains before 1.0, then performs the confirmation hardware run from the installed package. Until that run happens the release remains unaccepted in this log, although the packaged binaries are bit-identical to those every hand test exercised. After publication, record the tag and release outcome and reset the changelog's unreleased section for the next cycle. The chroma edge column stays documented rather than investigated, at the user's direction. The interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and are the natural scope for the next milestone, since they are what stands between this core and ordinary DVD material. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- docs/RELEASE_NOTES_v0.8.0.md

#### Status:

- [x] Built
- [ ] Passed

---

## 632 COMMIT Unreleased a26791f 2026-08-27T17:26:18-07:00

#### Coming From:

Unreleased 2c03075

#### Purpose:

Package the release candidate in the previous release's layout and verify every binary reproduces.

#### Outcome:

An unverified claim is corrected first, because it reached the changelog. Entry 630 stated that the helper rebuilt byte-identically from a clean dependency fetch. It had not. The ARM toolchain had been extracted under a temporary directory that the earlier machine crash and reboot cleared, the build script exited reporting only that the compiler was missing, that message contains neither the word error nor warning so the grep used to check it returned zero, and the hash printed afterwards belonged to the previously built binary still sitting in the output directory. The lesson is that a build was judged by a keyword count instead of its exit status. The toolchain has now been extracted to a persistent location and the work redone properly. With the dependency directory and prior helper binary deleted outright, the helper rebuilds to exactly `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8`, and Main rebuilds from the same tree against pinned upstream `0a8fb44` to exactly `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9`. Together with the RBF, which entry 630 had already reproduced byte for byte from a clean export, all three binaries now demonstrably reproduce from source baseline `2f1d32c`, and the changelog says so with the correction folded in. The package follows the v0.7.0 layout exactly, with the RBF named for its build date, Main at the root, the helper under a linux directory, checksums covering every file, installation and provenance notes, and licences for the project, minimp3 and now liba52. The installation notes state that Main is not optional and summarise the bounded video envelope so a user does not report a rejected DVD as a defect. The provenance notes record both toolchains, the upstream Main commit, and the pinned minimp3 and liba52 baselines with their archive hashes. The archive is 5,948,567 bytes with SHA256 `5f55b49eb863f74a777b548b4f42b744a9130b4161f176b687ca297deeffcaf3`, written beside the previous release. Its three runtime binaries are identical to what is installed on the target and what every hand test in entries 625 through 628 exercised, so the package is the tested configuration rather than a rebuild of it.

#### Next Steps:

The user installs from the package and performs the confirmation hardware run, then creates the annotated tag and GitHub release from commit `a26791f`, marking it pre-release because the project remains before 1.0. Until that run happens the release remains unaccepted, and the entry 630 caveat stands that no hardware run has occurred since packaging, although the binaries are bit-identical to those already tested. Release notes should carry the repeated frame behaviour on high peak pictures, the scaler margin recovered by the seed change and its status as a risk for the next change that adds logic, the audio split between measured and listened evidence, the DTS subwoofer behaviour as a device observation, and the two unqualified areas being playback pixel accuracy and the blended column at sharp colour transitions. The chroma investigation and the interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 631 COMMIT Unreleased 2c03075 2026-08-27T17:20:44-07:00

#### Coming From:

Unreleased 6b92a19

#### Purpose:

Bring the media conversion guide up to the current capability and document how to test audio.

#### Outcome:

The user noticed that the conversion guide still described the previous release, and it did: a single progressive recipe with MPEG Layer II, predating interlaced 480i, AC-3 and passthrough entirely. Published source `2c03075` splits it by the two shapes that actually play and adds an audio section. The interlaced guidance is the part most likely to save someone a wasted afternoon, because the obvious approach fails: FFmpeg's own interlacing flags select field DCT and field prediction, both of which this decoder rejects before decode, so the supported route is ordinary frame-DCT coding of woven field pairs with the interlaced signalling applied afterwards, which is what the committed generator does. The guide points at that generator and describes the sequence its build function uses. It also warns that the compatibility checker predates the interlaced path and rejects native interlaced files while remaining valid for progressive ones, so a rejection there is not evidence of a bad file. The audio section states what each codec does under each output setting in a small table, explains that the option mutes the output it is not driving because both are fed from one stereo stream, and gives the expected result of the AC-3 channel sweep in each mode, including that the silent fourth slot is correct because the stereo downmix discards LFE. It records two cautions learned this cycle: a 2.1 or virtualizing soundbar cannot demonstrate discrete channel routing however convincing it sounds, and receivers differ between codecs, with the device tested here reproducing LFE from AC-3 but not from DTS despite the transmitted DTS provably carrying it. The host-side checks are included because they are faster and more precise than listening. Every command in the new sections was run as written rather than composed from memory, which caught a real defect: the generator invocation did not write the report file that the downmix check reads, so the documented sequence would have failed at the second step. That was corrected and the corrected sequence was then run end to end successfully. The AC-3 decode, downmix placement and passthrough checks all pass on the release helper as documented.

#### Next Steps:

The release candidate is unchanged by this documentation work and remains ready for the user to tag. Nothing here alters the binaries, whose hashes are recorded in entry 630 and in the changelog. If a confirmation run is wanted before tagging, reinstall from the package and replay one interlaced and one audio test, which would also close the gap that no hardware run has occurred since packaging. The chroma edge column stays documented rather than investigated, at the user's direction, and the interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md

#### Status:

- [x] Built
- [ ] Passed

---

## 630 COMMIT Unreleased 6b92a19 2026-08-27T17:14:36-07:00

#### Coming From:

Unreleased ad56579

#### Purpose:

Build and document the release candidate for the next version from a clean tree.

#### Outcome:

The user set the version to 0.8.0, asked for the chroma finding to be documented rather than investigated, and asked for a from-scratch build. The build was made from a pristine export of tracked files only, so no incremental database or untracked artifact could influence it, and it reproduced the tested RBF byte for byte at SHA256 `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce`, 4,332,740 bytes, at fitter seed 17. That is the strongest reproducibility evidence this project has recorded for an FPGA binary. Zero errors and 208 warnings, with the warning identifier set identical to the accepted build, none new and none missing. The fit uses 31,464 ALMs at 75 percent, 50,273 registers, 4,048,355 block memory bits at 71 percent, 512 of 553 M10K blocks at 93 percent, 67 DSPs and three PLLs. Timing is positive everywhere with zero total negative slack: setup 0.243, hold 0.251, recovery 2.865, removal 0.564 and minimum pulse width 0.925 nanoseconds. Host regressions pass on the release binaries, covering the cadence decoder layout, eleven DVD ceiling tests, and the Main integration profile with 168 RTL cases, 96 burst cases, 20 step resume cases and the guarded fault cases. Audio regressions pass on the release helper: AC-3 decode against an independent decoder at maximum sample difference three and correlation 0.999999972, correct downmix placement for all six channels including the deliberate LFE absence, 375 byte-identical passthrough bursts, and the unchanged MPEG Layer II PCM hash on the full-length fixture. The helper itself rebuilt byte-identically from a clean dependency fetch. A packaging error was caught and corrected rather than shipped: the first package picked up the older Main from the local build directory instead of the patched Main that is installed and tested, which would have shipped without the audio output option and without the event-loop fix. All three packaged binaries were then compared against the target by independent readback and match exactly, so the package is the tested configuration rather than a rebuild of it. A factual slip in the release notes, a minimum pulse width written as 1.925 rather than 0.925 nanoseconds, was corrected in a follow-up commit. Documentation now describes 0.8.0 rather than unreleased work, the installation table lists all three runtime files with hashes and states that the patched Main is required rather than optional, and the chroma edge column is recorded under known limitations alongside the unqualified state of playback pixel accuracy. What this entry does not establish is a hardware regression pass on these exact packaged binaries; the six hand tests and the seventh progressive file were run against the same installed hashes, but no run was performed after packaging, and no release has been tagged.

#### Next Steps:

The user creates the annotated tag and GitHub release from the exact commit, as core.md requires, marking it pre-release because the project remains before 1.0. The package is at the rc080 package directory with a checksum file and installation notes; generated media stays out of it, so the seven hand tests are reproduced from the committed generator rather than shipped. Release notes should carry the repeated frame behaviour on high peak pictures, the scaler margin recovered by the seed change and its status as a known risk for the next change that adds logic, the audio split between measured and listened evidence, the DTS subwoofer behaviour as a device observation, and the two unqualified areas being playback pixel accuracy and the blended column at sharp colour transitions. If a final confirmation run is wanted before tagging, reinstall from the package and replay one interlaced and one audio test, which would also close the gap that no run has occurred after packaging. The chroma investigation and the interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 629 COMMIT Unreleased ad56579 2026-08-27T17:05:22-07:00

#### Coming From:

Unreleased 2cb7246

#### Purpose:

State the decoder's actual capability and its unqualified areas in the README and changelog.

#### Outcome:

Published source `ad56579` rewrites the capability description now that measurement rather than inference supports it. The two video paths are described separately because they differ sharply, which the previous single row obscured: the progressive path decodes I, P and B pictures through 720x480, while the interlaced path is 720x480 at 30000/1001 only, 4:2:0, I-pictures only, frame structured, frame DCT and frame prediction only, either field order, with no `repeat_first_field`. Field pictures, field DCT, interlaced P and B, pulldown and 576i are named as rejected before decode, together with the plain consequence that most commercial DVDs use several of these and will not play. Audio is described as decoded MPEG Layer II and AC-3 with an explicit note that the AC-3 stereo downmix discards LFE by the format's convention, alongside AC-3 and DTS passthrough as IEC 61937 bursts, the passthrough-only status of DTS, the audio output option and why it mutes the output it does not drive, and the single-track limit. Four unqualified areas are recorded rather than left implicit: playback pixel accuracy has never been qualified because every previous comparison ran in simulation; sharp colour transitions carry one blended column an independent decoder does not produce; material with a large enough peak coded picture repeats one or two frames at that picture as a property of buffer depth rather than of the stream; and passthrough cannot be scaled, so volume does not apply to it. The changelog gains the AC-3, passthrough, audio output, hand test, progressive picture type, Main responsiveness and known limitation entries for the unreleased section, and the README gains a hand test section describing what each of the seven files is for and noting that the audio sweeps exercise discrete channels only in S/PDIF mode. The standards section now credits liba52 and IEC 61937 and states that the rejected picture types are limits of this implementation rather than of H.262. Nothing in the release qualification or installation sections was touched, since those describe the published v0.7.0 binaries and no new release has been prepared.

#### Next Steps:

The release itself is not prepared and needs the user's decision on scope and timing. If it proceeds, the outstanding work is a full regression pass on a clean build, a decision on whether the chroma edge column is investigated first or shipped as a documented characteristic, a version number, and the tag and GitHub release created by the user from the exact commit, with the binaries and hand tests packaged and identified by hash. The installation section still describes three v0.7.0 runtime files and will need a fourth line if the release ships the patched Main, since the audio output option is meaningless without it. Release notes should carry the repeated frame wording, the marginal scaler paths recovered by reseeding, the audio split between measured and listened evidence, and the DTS subwoofer behaviour as a device observation rather than a core limitation. The chroma investigation, if wanted, should ask what the core does horizontally with 4:2:0 chroma when converting for display, with an interlaced colour bar file in native 480i as the control. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 628 COMMIT Unreleased 2cb7246 2026-08-27T16:51:13-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Establish whether the progressive path decodes P and B pictures, and identify the reported picture artifacts.

#### Outcome:

The capability question that blocked the release document is settled by playing a file rather than by reading RTL. Published source `2cb7246` adds a seventh hand test, progressive 480p with an ordinary fifteen picture GOP and two B pictures between references, built by extending the corrected suite generator rather than reviving the superseded one. It decodes: telemetry reports 121 reference pictures and 239 B pictures, all 360 displayed with 359 swaps, `error_flags` zero, sequence end, presentation complete, quiet snapshot, and a final picture type of three. The progressive path therefore handles I, P and B pictures, and the entry 609 description of the decoder as accepting I-pictures only was wrong; that restriction belongs to the interlaced 480i path, whose `phase1_supported` gate requires coding type one. B reordering costs 186,240,472 stall clocks, about 3.1 seconds of a twelve second clip, which is recorded as an observation rather than a fault. The user then reported poor picture quality, and the investigation separated two contributions. The first file was encoded at 22.3 kilobytes per frame against the all-I test four's 33.9, because B pictures let the encoder code the same content for a third fewer bits under a capped rate; the test was rebuilt with a rate floor to 33.6 kilobytes per frame so the two could be compared meaningfully. The artifacts persisted, and the user confirms test four looks identical to test seven, which rules out prediction drift and any P/B specific cause. The remaining artifacts were then measured rather than described. Screenshots at 800x600 capture the core's own output before the HDMI scaler, so they can be compared directly against an FFmpeg decode of the same frame; this is the first pixel comparison of actual playback in this project, every previous oracle having been applied in simulation. The active picture measures 720x480 placed one-to-one at offset 40 by 60 inside the 800x600 raster, so no resampling is involved and an early scaling hypothesis was wrong. At the yellow to blue band transition the reference decoder produces adjacent pixels of 252,254,0 and 1,0,254 with no intermediate value, while the hardware inserts one blended column of 199,196,255 between them, which is the reported thin vertical line. Decoding the reference again with full chroma interpolation and accurate rounding produces the same clean transition, so the difference is not an artefact of the reference's upsampling choice. No MiSTer.ini exists on the target, making a system video filter an unlikely explanation. The leading hypothesis is that horizontal chroma upsampling in the core's 4:2:0 to RGB path interpolates where the reference replicates, which would place exactly one blended column at each chroma transition. What is not established is whether that interpolation is correct for the intended chroma siting, or whether anything in the write or read path also contributes, and the left edge behaviour has not been separated from the telemetry overlay that occupies that corner.

#### Next Steps:

Decide whether the chroma edge behaviour is worth investigating before the release or recorded as a known characteristic, bearing in mind that it is visible on synthetic colour bars and much less so on ordinary material, and that it affects all progressive output rather than being new. If it is investigated, the targeted question is what the core does horizontally with 4:2:0 chroma when converting for display, and a useful control is an interlaced colour bar file played in native 480i, since that path differs from the 800x600 diagnostic output. The README can now be written, stating that the interlaced 480i subset is I-only, frame structured and frame DCT while the progressive path decodes I, P and B, and stating plainly that playback pixel accuracy has never been qualified, which this entry demonstrates is now measurable. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, the audio capability split between measured and listened evidence, and the DTS subwoofer behaviour of entry 621 as a device observation. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_suite.py

#### Status:

- [x] Built
- [x] Passed

---

## 627 COMMIT Unreleased 140a5b7 2026-08-27T16:32:05-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Install entry 624's Main and confirm on hardware that it removes the reported menu lag.

#### Outcome:

Two results are recorded. First, the AC-3 passthrough gap in the hand-test set is closed: the user re-ran test five with the output option set to S/PDIF, and its own log line confirms passthrough mode on AC-3 substream 0x80 rather than the decoded stereo mode the earlier run used. That capture completes 360 reference and display pictures with 359 swaps, `error_flags` zero, sequence end, presentation complete, quiet snapshot, zero deadline gaps and outliers, all three largest intervals at the nominal 2,002,000 clocks, audio underrun and PCM protocol clear at FIFO peak 127, and helper exit zero. An earlier attempt to capture that run collected a stale log which was still test six, identified by identical checksum, transport byte count and DTS substream line, and was discarded rather than reported. Second, entry 624's Main is now installed. It was backed up first, staged, hash checked while staged, renamed and read back on a fresh connection, giving SHA256 `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9`; the previous Main is retained under the entry 627 backup directory, and the RBF, helper, media and settings were left untouched. After the user's reboot the helper log independently confirms it is running, reporting profile version two with `credit_step_v1`, a 2000 microsecond poll budget, 2048-byte steps and a step limit of eight, where every previous capture this session reported version one. The effect on the same test one file is decisive. Maximum media-poll occupancy falls from 160,937 to 9,287 microseconds, a factor of 17.3, and maximum poll-entry interval from 170,928 to 20,910. The acknowledged-write fallback disappears entirely: 677,119 slow bytes become zero, with all 5,556,849 bytes delivered in fast mode across 42,367 polls instead of 257. The user reports the menu is now perfect, which matches the measurement, and this run is one of the four low bitrate files that were reliably laggy before, so it is the correct subject rather than a case that was never affected. Playback is unchanged: 360 reference and display pictures, 359 swaps, 3,068,039 accepted video bytes, zero errors, zero deadline gaps and outliers, and the same nominal intervals. One honest qualification: the observed 9,287 microsecond maximum still exceeds the 2000 microsecond work budget, which entry 624 explicitly declined to present as a hard bound, and no button-response latency was measured, so the menu verdict remains a user report supported by occupancy rather than a latency measurement. Version two logging also changes record semantics, with pipe reads covering all source reads and transfer entries sampled, so version one counts are not directly comparable except for the occupancy figures used here.

#### Next Steps:

The menu issue is closed on this evidence and needs no further replay. The remaining blocker for the release document is unchanged and is now the only one: no test exercises P or B pictures, so generate one progressive file with an ordinary GOP using the corrected suite generator and have the user play it, which decides whether the README says progressive I-only or progressive I/P/B. Consider also whether the test set should carry that file permanently, since a release that ships hand tests should exercise the picture types it claims. Then write the README capability section and release notes, carrying the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, the audio capability split between measured and listened evidence, and the DTS subwoofer behaviour of entry 621 as a device observation rather than a core limitation. The interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 626 COMMIT Unreleased 140a5b7 2026-08-27T16:02:11-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Capture the remaining three hand tests and establish what the reported menu lag actually tracks.

#### Outcome:

All six hand tests now play correctly on the accepted installation. Tests four, five and six each complete 360 reference and display pictures with 359 swaps, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps and outliers, and audio underrun and PCM protocol error clear, with helper exit zero. Accepted video is 12,057,601, 3,068,039 and 3,068,038 bytes. Test four confirms the progressive path works and its telemetry reports final picture type one, so it is an all-I file and exercises no P or B pictures; the progressive picture type question therefore remains open and still blocks the README. Test four also shows its three largest display intervals at 2,984,256 clocks rather than the 2,002,000 every interlaced test reports, while averaging 359 swaps across 11.96 seconds, so the progressive path paces differently with jitter that averages out rather than dropping pictures; whether that is expected is not established, and the deadline logic is scoped to native timing so its zero count is not evidence either way. Test five ran in HDMI decoded stereo mode according to its own log line, so it exercised the downmix rather than passthrough, while test six ran in S/PDIF passthrough mode on DTS substream 0x88 as required, since DTS has no decoder here. The menu question is now settled as far as measurement can take it. Lag separates cleanly on accepted video bytes rather than file size: the four runs the user found laggy each carry about 3.068 megabytes of video and hold the event loop for 151,366 to 160,937 microseconds with an acknowledged-write share of 12.0 to 12.4 percent, while the two responsive runs carry about 12.06 megabytes and hold it for 63,506 and 89,592 microseconds with shares of 3.5 and 0.9 percent. Test six is the larger file of the two audio tests yet still laggy, because its extra size is DTS audio rather than video, which is what distinguishes video bitrate from file size as the driver. Six subjective reports match the measurement without exception. The mechanism is the one already diagnosed: low bitrate video drains the FPGA slowly, transport credits run out more often, and Main falls back to acknowledged writes inside a single poll instead of yielding. This is event-loop occupancy from the helper's own profile and not a measured button-response latency. Entry 624's Main, which contains the yield fix, is still not installed, confirmed again by every log reporting profile version one. The user also observed the subwoofer present on AC-3 through S/PDIF but absent on DTS, and asked whether the receiver simply does not accept DTS surround. The evidence says it does accept and decode DTS, because the other five channels were audible in both this run and entry 621; what it does not do is deliver that stream's LFE. Entry 621 already established by measurement that the DTS bursts this core emits contain LFE at 1267.3 RMS decoded back from the helper's own output, byte identical to the source, so the omission remains downstream. A plausible unverified explanation is that the device downmixes DTS internally rather than applying bass management, and the standard DTS stereo downmix discards LFE exactly as this core's own AC-3 stereo downmix does.

#### Next Steps:

Install entry 624's Main and repeat one low bitrate test, being test one, two, five or six, to confirm that poll occupancy falls; that is the direct check and no further evidence gathering on the menu is needed first. Generate one progressive file with an ordinary GOP using the corrected suite generator rather than the superseded one, and have the user play it, because the difference between progressive I-only and progressive I/P/B is the last fact blocking the README and no test in this set exercises it. Consider also re-running test five in S/PDIF mode so this set covers AC-3 passthrough as well as the downmix. Do not pursue the DTS subwoofer further without different hardware, since the transmitted bytes are proven correct and no change here can alter what that device does; a tester with a discrete 5.1 DTS decoder settles it as a byproduct of the community test. When capability is established, write the README capability section and release notes carrying the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of measured versus listened audio claims. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 625 COMMIT Unreleased 140a5b7 2026-08-27T15:48:33-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Capture hardware results for the first three corrected hand tests and identify what the reported menu lag tracks.

#### Outcome:

Three duplicated efforts are resolved first. Another agent independently authored the same test suite generator, found real defects in this agent's version and corrected them, and the user directed that their files be used. Those defects were genuine: a `drawbox` position expression that was evaluated once rather than per frame, leaving a stationary bar in four of six files, and the use of top field interleaving for both field orders with only the signalling flag patched afterwards, so the bottom field first file never carried genuinely bottom-first temporal content. This agent's structural and hash checks could not have caught either, because neither verified that the picture moved. Two local commits carrying the superseded generator and a colliding entry number were discarded at the user's instruction and the published tree taken as-is; the user has since given this agent sole control of core-log.md. The three installed fixtures all play correctly. Each completes 360 reference and display pictures with 359 swaps, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps and outliers, and all three largest display intervals at exactly the nominal 2,002,000 clocks, with audio underrun and PCM protocol error clear and helper exit zero. Accepted video is 3,068,039, 3,067,813 and 12,073,185 bytes respectively. The top and bottom field first files hash differently rather than differing only by a flag, which is what the other agent's interleaving fix was for, and the user reports both look correct. An installation fact matters for interpreting all of this: entry 624's Main is not installed. The running Main is still `0ee87029f0a00a50731707e8114363fc7019ae4c1200de85d90533c9163b5241` from the earlier cycle, confirmed independently by the helper log reporting profile version one rather than the version two logging that Main introduces, so none of these runs exercises its polling budget. The reported menu behaviour is nevertheless explained by measurement rather than left as an impression. Maximum media-poll occupancy is 160,937 microseconds on test one and 153,112 on test two, both of which the user found laggy, against 63,506 microseconds on test three, which the user found responsive. The acknowledged-write share of transport moves the same way, at 12.2 and 12.1 percent for tests one and two against 3.5 percent for test three. The mechanism is consistent with the other agent's diagnosis: low bitrate content drains the FPGA slowly, so transport credits run out more often and Main falls back to acknowledged writes inside a single poll instead of yielding, and the two low-rate files are 3.4 megabytes against test three's 12.5. This is event-loop occupancy measured from the helper's own profile, not a measured button-response latency, and no such latency is claimed. Tests four through six remain unrun.

#### Next Steps:

Capture the remaining three hand tests as the user runs them, taking the helper log before anything else is played, and expect the two small audio sweep files to show the same long poll occupancy as tests one and two for the same reason. Do not treat the menu question as open evidence-gathering: it is understood, entry 624's Main contains the fix, and the useful next step is installing that Main and repeating a low bitrate test to confirm occupancy falls. Keep the release README unwritten until the progressive picture type question is settled, since no test in this set exercises P or B pictures and the difference between progressive I-only and progressive I/P/B is exactly what the document must state correctly. When capability is established, carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of measured versus listened audio claims. The interlaced gates of entry 609 remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 624 COMMIT Unreleased 140a5b7 2026-08-27T09:27:04-07:00

#### Coming From:

Unreleased 44ee05a

#### Purpose:

Restore valid motion regressions and keep Main responsive during backpressured media transfers.

#### Outcome:

Published source 140a5b7 implements the approved fixture and Main responsiveness boundary without changing FPGA or helper codec source. The uncommitted GUNSMOKE draft and checker edit are backed up under entry624/draft-backup and left untouched in their original checkout; development and official qualification use separate directories. The suite now advances its bar from a per-frame source index and uses interleave_top or interleave_bottom to establish actual TFF/BFF temporal order before signalling is patched. Independent decoded-pixel checks validate all 720 temporal fields in each of the four bar fixtures and reject both original stationary files and a deliberately wrong field-order interpretation. All six twelve-second clips contain 360 pictures and have identical hashes across two generations. Main retains a 16 KiB pending buffer and uses verified-credit steps of at most 2048 source bytes, returns immediately at zero credits, and limits each poll to eight steps and one pipe read with a 2000-microsecond budget checked between steps. This is not a hard latency bound: one transaction, OS scheduling, logging and unchanged terminal child cleanup can extend a call, and legacy acknowledged-only cores retain their existing handshake waits. Unaligned data is packed locally, odd short reads retain their final byte until a partner or true EOF, and only the terminal byte is padded. Count, digest, capability and flags are verified before and after each batch; uncertain transfers abort without retry. Native and address/undefined-sanitized loader tests pass, including one hundred consecutive zero-credit yields, bounded progress, exact bytes, odd reads across EAGAIN/EINTR, EOF blocked on credits, fault/cancel/core-change cleanup, warm restart, unavailable diagnostics and twenty-four seeded short-read/credit sequences. Actual production bridge tests retain the legacy and original burst coverage and add twenty bounded-step resume cases, unaligned and odd tails, post-yield validation, corruption/reset rejection and counter wrap. A control that discards pending data on yield fails the regression as intended. Existing ceiling-generator tests pass. The unchanged helper preserves each new fixture's clean video exactly, emits the expected 576,000 PCM frames or equivalent burst periods, keeps MP2 identical across output modes and preserves the exact original MP2 elementary audio in tests one and two. AC-3 stereo matches independent decoding with maximum sample differences two and one by channel, and AC-3/DTS passthrough carries byte-identical source frames; unsupported DTS HDMI output remains rejected. GUNSMOKE pulls exact published source before qualification and builds Main from pinned upstream 0a8fb44 with ARM GNU 10.2, zero build warnings and no reused checkout object files. The 1,170,340-byte Main is SHA256 01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9. No new RBF or Quartus timing claim is needed; accepted seed-17 aa7f064 and helper 078d36b are retained. Host logging is version two, credit_step_v1: pipe_read entries cover all source reads while transfer entries are sampled, so historical version-one analyzers must not be applied unchanged. Fresh Main, RBF, helper and six-media backups are independently verified under /home/vash/mister-builds/entry624-backup. The local output_files/entry624/MediaPlayer_140a5b7_regression_update.zip contains Main and all six fixtures with instructions and checksums; its 12,662,276 bytes have SHA256 faa79844d7af3d6de039bcdf1b4d3667f50488241bda5785325d42e0ac880103, and every local archive member and unpacked payload matches its build hash. Evidence and reproducible drivers are retained as .ai/current_results/entry624_*. Nothing is deployed, reloaded, rebooted or played by the agent. Hardware menu response, corrected-fixture playback and sustained throughput remain unaccepted.

#### Next Steps:

The user will install the supplied Main and six test files, keeping the existing RBF and helper, then reboot once to activate Main and load MediaPlayer. Select Bob and run corrected test_1_interlace_tff.mpg once, observing the downward-moving bar, audible tone and menu response during and after playback; leave the terminal screen and helper log available before playing anything else. Collect the version-two log first and a fresh checksum-valid screenshot, verify installed hashes and require all 360 pictures, zero decoder/transport/audio errors and expected cadence while measuring media-poll duration against entry 623. Then capture corrected BFF and remaining regressions separately, and retain a bounded high-rate check before treating the new polling budget as throughput-qualified. Do not conflate software integrity tests or the 2 ms work budget with measured UI latency, and do not declare a release accepted until hardware regressions pass. The full-movie repeated-frame limitation, scaler margin risk and unsupported DVD syntax remain unchanged. Preserve user deployment/lifecycle control, restricted core.md and the forty-entry ring.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- host/arm/ARCHITECTURE.md
- tools/streams/test_main_mister_profile.py
- tools/streams/generate_test_suite.py
- tools/streams/generate_test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 623 COMMIT Unreleased 44ee05a 2026-08-27T09:24:06-07:00

#### Coming From:

Unreleased 44ee05a

#### Purpose:

Separate faulty motion fixtures from the reported slow menu in regression tests one and two.

#### Outcome:

The user reports that tests one and two leave the top bar stationary and make the MiSTer menu very slow. The target listing and an uncommitted GUNSMOKE generator identify test_1_interlace_tff.mpg and test_2_interlace_bff.mpg. Both exact target files are read back and independently decoded with FFmpeg on GUNSMOKE: each contains 360 identical decoded frames, with the white bar fixed at rows zero through seven, and both share decoded-frame MD5 30809417f1caba5a06194ea6f01bd4da. Their compressed hashes differ only as separate fixtures and are retained in the evidence. The stationary bar is therefore authored into the test files, not evidence that the core froze, and these files cannot qualify motion or field order. The generator uses a suspect drawbox position expression, always interleave_top for both field orders and a later signalling patch; fixing motion must also establish correct BFF temporal field placement rather than just changing the flag. The generator and its companion check_structure edit exist only as uncommitted GUNSMOKE work and are preserved untouched. Initial helper log collection precedes the screenshot, but the fixed log has already been overwritten by test_5_audio_ac3_51.mpg, explicitly logged in HDMI decoded-stereo mode. That capture has checksum 2300824580, all 360 reference/display pictures and 359 swaps, zero errors and deadline gaps, sequence end and quiet completion, and helper exit zero after 4,443,979 transport bytes. It is not a capture of either failed run and does not qualify the other tests. Installed RBF, Main and helper match the accepted seed-17 aa7f064, patched Main and 078d36b helper hashes. The menu complaint has separate supporting evidence: test five records a maximum Main media-poll duration of 189,354 microseconds and a maximum single transfer of 58,356 microseconds. Main performs up to four complete 16 KB transfers per poll, and the credit API drains each whole chunk, falling back to acknowledged writes at zero credit instead of yielding to the UI. The user then explicitly leaves test one on screen, allowing a separate helper-first capture of test_1_interlace_tff.mpg with PID 909 and checksum 2300351100. It completes all 360 reference/display pictures and 359 swaps, with zero errors, underruns, timestamp conflicts, deadline gaps or outliers, sequence end and quiet completion. All 272 read records reconcile to 4,443,951 submitted bytes and helper exit zero; the installed Main and RBF hashes remain unchanged. Its own profile confirms a 189,409-microsecond maximum media-poll call, 204,524 microseconds between poll entries and a 62,454-microsecond maximum single transfer. This directly documents long event-loop occupancy on test one and supports the reported menu sluggishness without inventing a measured button-response latency. The stationary file is played to completion rather than freezing in this run. Test two still lacks dedicated hardware telemetry, and no Bob/Weave selection or reboot/reload lifecycle is inferred. No production source, build, deployment, setting, reboot, reload or playback changes occur; only the fixed screenshot is regenerated. Exact capture, frame identities, generator snapshot and analysis are retained as .ai/current_results/entry623_*, with full diagnostic media off Git under /home/vash/mister-builds/regression_failure_20260827_092037. Built refers to the unchanged accepted installation; these regression tests remain unaccepted.

#### Next Steps:

Correct and publish the fixture generator from the preserved draft in coordination with its existing uncommitted work, requiring independently decoded motion at successive fields, correct TFF and BFF temporal ordering, supported syntax and preserved audio before replacing test media. The separate Main responsiveness fix should use resumable bounded transfer progress that returns to the event loop when credits are unavailable, preserves unsent bytes and count/digest checks, and handles EOF, cancellation, reset and odd byte tails without loss or premature completion. Scope and qualify that host change before deployment; do not weaken transport checks or alter FPGA clocks, queues or decode logic to hide a fixture defect. Test one needs no further identical replay: the fixture defect and long host-poll occupancy are already established. Test two remains without a dedicated hardware capture, but the same stationary-content defect is independently proven in its file. Capture each corrected test before a later run overwrites its log. Do not declare release regression complete on the strength of entry 622 audio acceptance. Preserve user control of lifecycle and deployment, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 622 COMMIT Unreleased 44ee05a 2026-08-27T09:00:58-07:00

#### Coming From:

Unreleased 078d36b

#### Purpose:

Close the commercial AC-3 gap by qualifying decode and passthrough against a real DVD track.

#### Outcome:

The user confirmed that a DVD image already on the build PC exists for this purpose, so the last honest gap in AC-3 qualification is closed against real programme material rather than synthetic tones. The image is an unencrypted standard VIDEO_TS structure and no protection was circumvented; one title VOB was extracted locally and nothing derived from the film is committed, with only numeric results retained. That VOB carries three real AC-3 tracks, being 5.1 at 448 kbit/s, stereo at 192 kbit/s and 5.1 at 384 kbit/s, and the helper selects the first as designed. Over 55,414,272 stereo frames, or 1154.5 seconds, the helper's decode against an independent FFmpeg decode of the same track gives maximum absolute difference 299, RMS difference 2.60 and correlation 0.999976, with overall level matching at 376.17 against 376.18 RMS. That is a much larger deviation than the synthetic fixture's maximum difference of three and correlation of 0.999999971, which is the expected consequence of real dynamic range control and dialogue normalization being exercised for the first time, and the residual sits 43.2 dB below the signal. The cause was confirmed rather than assumed by a control: decoding the reference again with dynamic range compression disabled makes the match far worse, at maximum difference 4123, RMS difference 79.17 and correlation 0.989129, and raises the reference level to 428.72 RMS, which is 1.14 dB above the compressed result. That establishes both that the disc carries substantial dynamic range metadata and that the helper applies it, matching the reference decoder's default behaviour, since liba52 enables dynamic range by default and neither decoder applies dialogue normalization. The remaining difference is decoder implementation, not a metadata mismatch. Passthrough was qualified on the same real track: the helper emitted 36,077 bursts, every one a 1536-sample period carrying a 1792-byte frame as expected for constant-rate 448 kbit/s, and all 64,649,984 bytes carried are byte identical to the AC-3 extracted from the disc, with an independent decoder producing matching output. One tool change was needed and is deliberately narrow. A VOB from a multi-file title ends mid-frame by construction, so the helper correctly refuses its truncated tail; rather than loosen the helper or the default gate, the verifier gained an explicit opt-in that accepts exactly that case and ignores the source's trailing 672-byte partial frame. An earlier attempt at the comparison exhausted memory and took the machine down, because it loaded both 212-megabyte captures as double precision and then copied them again; the retained driver streams in chunks and never holds more than a few megabytes.

#### Next Steps:

Audio qualification is complete for this release, covering MPEG Layer II, AC-3 decode and AC-3 and DTS passthrough, against both synthetic fixtures and a real commercial track. Prepare the release next. The README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD compatibility; it should describe audio separately, since audio support is genuinely broader than video and includes passthrough for material the core cannot decode itself. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of which audio claims are measured and which rest on listening. The community sound test should ask for AC-3 and DTS separately with LFE called out, since entry 621 showed the same device treating them differently. The interlaced video gates of entry 609 remain open and explicitly out of scope. Note for any future disc work that this image is a usable real-world Program Stream source, but that the core cannot decode its video, which uses picture types and structures outside the supported set. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [x] Passed

---

## 621 COMMIT Unreleased 078d36b 2026-08-27T08:49:23-07:00

#### Coming From:

Unreleased 078d36b

#### Purpose:

Accept DTS passthrough on hardware and resolve the reported missing subwoofer channel.

#### Outcome:

The user played the DTS sweep and reports every channel working except the subwoofer, with no format indicator appearing, which that soundbar never shows. Telemetry is clean: all 360 reference and display pictures with 359 swaps, 12,073,316 accepted video bytes, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps, and audio underrun and PCM protocol clear, with helper PID 1109 submitting 14,562,142 transport bytes over 889 reads and exiting zero. The new diagnostics work as intended and the log now states both the selected mode and the DTS substream on its own, which is exactly the gap entry 619 had to fill with a listening report. The missing subwoofer is diagnosed rather than left open, and it is not a defect in this core. Decoding the fixture's DTS elementary stream to six discrete channels shows the LFE channel present at 1267.3 RMS in its own slot against about 2896 for the other channels, a level difference that is normal for DTS before a decoder applies LFE gain and is not evidence of loss. The helper then emitted 1,125 valid bursts with no problems, and decoding the frames recovered from that emitted output yields the same LFE at exactly the same 1267.3 RMS on the same channel. Since the carried frames are byte identical to the source, this chain establishes that what the core transmits contains the subwoofer channel. The omission is therefore downstream in the soundbar's DTS handling, and it is DTS specific to that device, because AC-3 LFE was clearly audible on the same hardware in entry 619. Why that decoder drops it is not established and is not testable from here, with bass management, DTS Virtual:X processing and LFE gain conventions all plausible. DTS passthrough is accepted on the evidence that the bytes are provably correct, that an independent decoder recovers every channel including LFE from what the core actually emits, and that the user heard the remaining channels through the soundbar's own decoder. As with AC-3, a 2.1 device cannot verify discrete channel routing, so that remains for the community test. The DTS fixture uses 8 Mbit/s video by necessity and is not a rate ceiling test.

#### Next Steps:

Do not chase the subwoofer behaviour further without different hardware, since the transmitted bytes are already proven correct and no change here could alter what that soundbar does; a tester with a discrete 5.1 DTS decoder would settle it as a side effect of the community test. Ask the community test to report AC-3 and DTS separately and to note LFE explicitly, because this run shows the two codecs can behave differently on the same device. The remaining audio item is a commercial AC-3 track with real dynamic range control and dialogue normalization, which synthetic tones cannot substitute for. Then prepare the release. The user has accepted current video capability as the release scope, so the README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD compatibility. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the audio capability including which parts are verified and which rest on a listening report, and the marginal scaler paths recovered by reseeding. The interlaced video gates of entry 609 remain open and explicitly out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 620 COMMIT Unreleased 078d36b 2026-08-27T08:43:19-07:00

#### Coming From:

Unreleased aa7f064

#### Purpose:

Pass DTS through to S/PDIF and record the selected audio output in the helper log.

#### Outcome:

Published source `078d36b` adds DTS passthrough and closes the diagnostic gap entry 619 recorded. The helper now states its audio output mode at startup, so a log proves on its own which path ran rather than leaving that to a listening report. DTS arrives on private stream 1 substreams 0x88 through 0x8F and differs from AC-3 in a way that matters: it carries its own sample count in its frame header, so the burst period is read from each frame and mapped to data type 11, 12 or 13 for 512, 1024 or 2048 samples, where AC-3 is always 1536. The burst emitter is generalized over data type and period accordingly, and only 16-bit big-endian DTS is accepted, with other widths and endiannesses refused rather than guessed at. There is no DTS decoder here, so DTS is passthrough only and a DTS track selected for HDMI output is refused with a clear message instead of playing silence, which is checked and behaves as intended. The fixture generator gains a codec choice. Generating DTS exposed a real constraint rather than a defect: at the usual 1509 kbit/s, DTS plus 9.6 Mbit/s video overruns the 10.08 Mbit/s DVD mux and the muxer reports buffer underflow, so the generator now lowers video to 8 Mbit/s for DTS, which is what real DTS discs do rather than raising the mux. The verifier is extended to walk periods of any supported length and to check each payload against its own codec's sync word. Verification is byte exact: the DTS stream produces 1,125 bursts, every one a 512-sample period at data type 11 with correct sync words, whole-byte length, zero stuffing and a valid DTS sync word in the payload, and the 2,263,500 bytes carried are byte identical to the DTS extracted from the source, with an independent decoder producing the same SHA256 from the carried frames as from the originals. Every existing path is unchanged: AC-3 passthrough still produces 375 correct 1536-sample bursts with identical frames, AC-3 decoded still matches its reference at maximum difference three, the channel sweep still places all six channels correctly, and the MPEG Layer II movie still produces the same 28,628,352 samples with the same PCM hash. The helper cross-compiles clean under `-Werror` with ARM GNU 10.2 to a 399,340-byte static binary with SHA256 `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8`. Only the helper and a new DTS fixture were deployed, each backed up, staged, hash checked and read back on a fresh connection with matching results; the RBF and Main were read back and confirmed still the accepted seed 17 and patched binaries, and no FPGA build was needed because DTS changes nothing in fabric. Built refers to the helper, and Passed is unchecked because nothing has been listened to.

#### Next Steps:

Have the user select S/PDIF AC-3 in the OSD and play games/MediaPlayer/dts_channel_sweep_12s.mpg once, reporting whether the soundbar produces sound and whether the low frequency slot is present, and confirm from the helper log that it now names both the audio output mode and the DTS substream. The soundbar advertises DTS Virtual:X so it should decode DTS, but as with AC-3 it cannot verify discrete channel routing on 2.1 hardware, and its lack of a format indicator remains uninformative. Note that the DTS fixture deliberately uses 8 Mbit/s video, so it is not a rate-ceiling test. After that, the remaining audio item is a commercial AC-3 track with real dynamic range control and dialogue normalization, which is the honest gap in codec qualification and cannot be closed with synthetic tones. Then prepare the release: the user has accepted the current video capability as the release scope, so the README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD support. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut and the marginal scaler paths recovered by reseeding. The interlaced video gates of entry 609 remain open and are explicitly out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/ARCHITECTURE.md
- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [ ] Passed

---

## 619 COMMIT Unreleased aa7f064 2026-08-27T08:35:53-07:00

#### Coming From:

Unreleased aa7f064

#### Purpose:

Accept AC-3 passthrough over S/PDIF on hardware.

#### Outcome:

The user reloaded the core, exercised both audio output settings and reports that S/PDIF AC-3 sounds correct through the soundbar, that the subwoofer was heard on its own channel for the first time, and that the HDMI and S/PDIF options both behave as specified. The decisive evidence is that low frequency channel rather than any indicator on the device: the AC-3 stereo downmix discards LFE entirely, so a discrete subwoofer channel can only exist if the compressed bitstream reached the soundbar and was decoded there as 5.1. The soundbar displayed no format indicator, which the user reports it never does over S/PDIF, so that absence carries no weight either way. This also settles empirically what entry 617 could only argue from clock arithmetic, namely that the path from the core samples to the S/PDIF pin is bit transparent; had the mixer, filter or DC blocker altered a single sample the receiver could not have decoded anything. Telemetry is clean. The installed RBF is the seed 17 build with SHA256 beginning `61a2fed2`, Main is the patched binary beginning `0ee87029`, and the sweep fixture is unchanged on the target. All 360 reference and display pictures complete with 359 swaps and 14,469,731 accepted video bytes, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps or outliers. Audio underrun and PCM protocol error are clear at FIFO peak 127. Helper PID 753 submitted 16,958,580 transport bytes over 1,036 reads and exited zero, which is byte for byte the same volume as the decoded run of the same fixture in entry 614, confirming by measurement the design property that a burst occupies exactly the transport a decoded frame would have. One diagnostic weakness is recorded rather than hidden: the helper log names the AC-3 substream but never states which audio output mode it was launched with, so the log alone cannot distinguish a passthrough run from a decoded one, and this acceptance therefore rests on the user's listening report for that distinction. Scope is bounded. A 2.1 soundbar cannot verify discrete channel routing however convincingly it virtualizes, so front, centre and surround placement over passthrough remains unproven and needs the community test on real 5.1 hardware; only LFE is independently established, because its presence is impossible under the downmix. DTS passthrough is untested, a commercial AC-3 track with real dynamic range control is still uncompared, and the marginal scaler paths recovered by reseeding remain a risk for the next change that adds logic.

#### Next Steps:

Add a mode line to the helper's diagnostics so a future log proves on its own whether decoded stereo or passthrough was selected, since that gap forced this entry to rely on a listening report for a fact the log should carry. Write the community sound test from the sweep fixture, stating that in S/PDIF mode it exercises discrete channels through the listener's own decoder while in HDMI mode it exercises only the stereo downmix, and ask testers with real 5.1 hardware to report each two second slot by speaker. DTS passthrough is the same machinery with a different data type and burst length and is the cheapest remaining audio item. A commercial AC-3 track remains the honest gap in codec qualification. Before the release, decide whether the audio work is complete enough and prepare release notes carrying the entry 616 wording of one or two repeated frames at the picture 690 cut rather than entry 609's original phrasing. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted and are the larger question for a release that claims interlaced support. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 618 COMMIT Unreleased aa7f064 2026-08-27T08:28:45-07:00

#### Coming From:

Unreleased 6c273b3

#### Purpose:

Recover timing closure for the S/PDIF passthrough candidate by reseeding the fitter once.

#### Outcome:

The user authorized a single reseed and directed that the scaler be fixed if it failed. Published source `aa7f064` moves the pinned fitter seed from 16 to 17 and nothing else, so the netlist is unchanged and only placement and routing differ; synthesis produces the identical 137 warnings as the failing build, which confirms that. The reseed succeeds and does so with more margin than the accepted baseline: worst setup is positive 0.243 nanoseconds against positive 0.083 for `d466bed` and negative 0.070 at seed 16, with hold 0.251, recovery 2.865, removal 0.564 and minimum pulse width 0.925, and every reported total negative slack is zero. The `ascal` horizontal accumulator paths that failed are no longer critical. The warning set is identical to accepted `d466bed`, with the same twenty-one distinct warning identifiers at the same counts, none new and none missing, including the pre-existing invalid Fitter assignments warning; the timing violation warning present at seed 16 is gone. Logic utilization is 31,464 ALMs against 31,394 for the baseline, and M10K stays at 512 of 553, so the whole audio feature still costs no block memory. The 4,332,740-byte RBF has SHA256 `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce`. All three artifacts were deployed together, because the OSD bit is meaningless unless the core routes on it, Main passes it to the helper and the helper can act on it. Every target was backed up first under the entry 618 backup directory, capturing the accepted `d466bed` RBF, the previous Main and the AC-3 helper from entry 611, and each file was then uploaded to a staged name, hash checked while staged, renamed, and read back on a fresh connection, with all three readbacks matching exactly. Media and settings are untouched and no reboot, core reload or playback was performed. What this entry establishes is a timing-qualified build and a verified installation, not working passthrough. Bit transparency from the core samples to the S/PDIF pin is still argued from clock arithmetic rather than measured, no receiver has been shown to lock onto a burst, and the reseed recovers this build without making the underlying scaler paths any less marginal, so the next change of comparable size may expose them again.

#### Next Steps:

Have the user reload the MediaPlayer core so the new RBF and Main take effect, set the new Audio output option to S/PDIF AC-3, and play games/MediaPlayer/ac3_channel_sweep_12s.mpg, reporting whether the soundbar shows a format indicator and whether each two second slot is audible, including the low frequency slot which the stereo downmix always discarded and which should now be present. Selecting HDMI mutes S/PDIF by design, so a silent test in that mode on a system whose only speakers are on S/PDIF is expected behaviour and not a fault. Retrieve the helper log first and confirm it records the selected mode, then take a fresh telemetry screenshot from the terminal screen rather than during playback. If the soundbar stays silent in S/PDIF mode, suspect the transparency of the path to the pin before suspecting the bursts, which are already verified byte exact, and check the channel status non audio bit before anything else. Do not describe a 2.1 soundbar locking onto a burst as proof of discrete channel routing; that still needs the community test on real 5.1 hardware. The marginal `ascal` accumulator paths remain a known risk to record before the next feature that adds logic. A commercial AC-3 track with real dynamic range control remains uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 617 COMMIT Unreleased 6c273b3 2026-08-27T08:12:47-07:00

#### Coming From:

Unreleased e2bf23f

#### Purpose:

Route IEC 61937 bursts to the S/PDIF pin under an audio output option, with the unused output muted.

#### Outcome:

Published source `6c273b3` implements the integration the user specified and approved, including the framework fork. The S/PDIF encoder gains a non audio channel status input driving bit one, so a burst stops declaring itself linear PCM; `audio_out` gains a passthrough route feeding S/PDIF straight from the core samples while skipping the interpolating filter, the DC blocker and the attenuation, boost and mix stages, because each alters sample values and any alteration destroys a burst; I2S is muted in that mode and S/PDIF is muted outside it. A new emu port carries the selection from the core through `sys_top`, a new OSD option on status bit 126 drives it, and the Main patch reads the same bit in the parent before forking to pass `--audio-out` to the helper, so one bit drives both routing and the helper's decode or pass through decision. Main builds cleanly against the pinned commit at 1,170,340 bytes with SHA256 `0ee87029f0a00a50731707e8114363fc7019ae4c1200de85d90533c9163b5241`, which also proves the corrected patch hunk applies and that `user_io_status_get` is the right interface at that revision; an earlier edit had left that hunk's line count stale and it was recomputed rather than guessed. The build does not qualify. Quartus 17.0.2 at the pinned seed 16 completes in 11 minutes 33 seconds with zero errors, but worst setup slack is negative 0.070 nanoseconds against the accepted `d466bed` figure of positive 0.083, with total negative slack of the same 0.070. Hold, recovery, removal and minimum pulse width all improve slightly at 0.248, 3.158, 0.488 and 0.925 nanoseconds. The 4,298,348-byte RBF is therefore not usable and is not deployed. The failure is diagnosed rather than assumed: both violated paths run between bits 9 and 13 of the `o_hacc_next` register inside the `ascal` scaler on the HDMI pixel clock, entirely inside the framework scaler's horizontal accumulator, with the next path at positive 0.076 nanoseconds, so this is a cluster of marginal arithmetic paths in framework video logic rather than anything in the audio change, which lives in the audio clock domain. Resource movement is consistent with that reading: ALMs rise from 31,394 to 31,488, a 94 ALM increase that perturbs placement, while M10K stays at 512 of 553, block memory bits and DSPs are unchanged, so the audio work costs no memory as designed. The only new warning across the whole flow is 332148, the timing violation itself; every other warning matches the accepted baseline exactly, with none disappearing. The honest conclusion is that this design has been running on roughly 0.08 nanoseconds of setup margin in the HDMI domain all along, and any change of comparable size could have exposed it. Built is left unchecked because a candidate that misses timing is not a usable build under this project's own standard, even though it compiled without errors.

#### Next Steps:

Decide how to recover timing before anything is deployed, and record the choice rather than quietly re-rolling until a build passes. The cheapest option is a different fitter seed, which is a tracked source change because seed 16 is pinned in the project file, and it is legitimate provided the new seed is recorded and kept for later comparability; it does not make the underlying path less marginal. The durable option is to attack the `ascal` horizontal accumulator path itself, which would benefit every future change rather than this one, but it means modifying framework video logic beyond the audio fork the user approved and should be scoped separately. Reducing the audio routing logic is unlikely to help, since the failing path is not in it. Whichever is chosen, require a clean seed-qualified build with a warning comparison against `d466bed` before deploying, and deploy the RBF, Main and helper together, because the mode bit is meaningless unless all three change as a set. On hardware the existing channel sweep is the six channel sound test, LFE becomes audible for the first time, and selecting HDMI will silence S/PDIF by design, which must not be mistaken for a fault on a system whose only speakers are on S/PDIF. Bit transparency from the core samples to the pin remains argued from the clock arithmetic rather than measured, and it is the most likely cause if a receiver fails to lock. Do not describe a 2.1 soundbar locking onto a burst as proof of discrete channel routing. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- sys/spdif.v
- sys/audio_out.sv
- sys/emu_ports.vh
- sys/sys_top.v
- MediaPlayer_top_00.svh
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 616 COMMIT Unreleased e2bf23f 2026-08-27T07:52:18-07:00

#### Coming From:

Unreleased e2bf23f

#### Purpose:

Capture the outstanding MPEG Layer II hardware regression on the AC-3 helper.

#### Outcome:

The full movie replay on the new helper is finally captured with its own log, closing the gap entries 613 and 614 left open. Completion is exact: all 17,876 reference and display pictures, 17,875 swaps, 715,713,077 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, audio underrun and PCM protocol clear, both timestamp conflict counters zero, and helper PID 3477 submitting all 839,409,548 transport bytes over 51,234 reads with exit zero. The accepted MPEG Layer II path therefore survives codec selection on hardware, which host testing had suggested but not proven. One measured quantity did change and is reported rather than smoothed over: this run missed two display slots where entries 605 and 606 each missed one. The deadline records place them at displayed pictures 691 and 692, adjacent and at the same scene cut as before, with two 4,004,000-clock intervals whose eight bit gap ordinals 179 and 180 alias to those pictures. Both records show no presentable candidate with the decoder not ready and the upstream FIFO pending, presentation error and the timestamp signals clear, and input starvation of 1,009,994 and 727,897 clocks. The new helper is not implicated by the evidence available. Delivery timing is materially identical across all three movie runs, with median inter-read gaps of 11,463, 11,468 and 11,475 microseconds, ninety-ninth percentiles of 20,986, 20,966 and 20,931, maxima of 41,289, 41,309 and 41,304, and the same 23.5 millisecond worst gap in the window around the cut, while the MPEG Layer II PCM output was already proven byte identical on the host in both output modes. What the extra slot exposes is a flaw in the entry 608 and 609 model rather than a new fault. That model tested each picture independently against a full buffer, which is why it predicted exactly one miss, but after picture 690 overruns the buffer is not refilled to full, so picture 691 at 95,308 bytes is then also uncovered. Taking the pair together, 245,624 bytes must arrive against 98,304 bytes of buffer plus two frame periods of delivery, a deficit of about 67,240 bytes or roughly 1.7 slots, so one or two lost slots at this cut are both consistent with the mechanism and the exact count depends on phase. Entry 609's known limitation stands but its wording of exactly one repeated frame is too strong and is corrected here to one or two at that cut. The user reports the movie plays perfectly, which is consistent: two repeated frames at a scene cut in a ten minute film are not perceptible. No source change is made in this entry, so Built and Passed refer to `e2bf23f`, with Passed covering the MPEG Layer II regression.

#### Next Steps:

Treat the MPEG Layer II regression as closed and do not repeat the full replay to observe the missed slot count again, since a single run per circumstance is the standing practice and the mechanism is now understood. If that judder is ever to be removed, the fix remains the deeper input buffer costed in entry 608 at roughly 26 M10K against 41 free, and the cascade behaviour means the buffer must cover consecutive large pictures rather than only the single largest, which makes that fix less attractive rather than more. Carry the corrected wording, being one or two repeated frames at the picture 690 cut, into release notes rather than entry 609's original phrasing. The audio work continues at the second passthrough boundary described in entry 615. A commercial AC-3 track with real dynamic range control remains uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 615 COMMIT Unreleased e2bf23f 2026-08-27T07:52:18-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Pack AC-3 frames into IEC 61937 bursts in the helper behind an audio output selection.

#### Outcome:

Published source `e2bf23f` adds `--audio-out`, defaulting to `hdmi`, and emits IEC 61937 bursts instead of decoded stereo when `spdif` is selected. One AC-3 frame is 1536 samples and one burst period is 1536 stereo frames, so a frame fills a period exactly and the bursts ride the existing PCM transport with no rate conversion, no new record type and no FPGA memory, which matters at 93 percent M10K. Each burst carries the `0xF872` and `0x4E1F` sync words, data type one, the length in bits, the frame written as big-endian sixteen bit words so bytes reach the line in order, and zero stuffing for the remainder. liba52 is not initialized at all in passthrough, since nothing is decoded. Verification is offline and byte exact: the emitted stream is 2,304,000 bytes forming 375 whole burst periods, every one parses with correct sync words, data type, whole-byte length and zero stuffing, every payload begins with the AC-3 sync word, all frames are the expected 1792 bytes, and the 672,000 bytes carried are byte identical to the AC-3 extracted from the source. An independent decoder produces the same SHA256 from the carried frames as from the source frames. The decoded paths are unchanged: AC-3 stereo still matches its reference at maximum difference three and correlation 0.999999971, the channel sweep still places all six channels correctly, and the MPEG Layer II movie produces identical output in both `hdmi` and `spdif` modes, byte for byte, since passthrough applies to AC-3 only. A build defect was found and fixed rather than worked around: native and cross builds shared one liba52 object directory, so switching compilers produced a confusing wrong-format link error; objects are now kept per compiler. The helper cross-compiles clean under `-Werror` with ARM GNU 10.2 to a static binary with SHA256 `f07e4ce2bb2a431802f9c8631a228bb70c363455954315883776f58ce87a75db`. What this does not establish is as important: it proves the bytes are correct, not that any receiver locks onto them, and not that the path from the helper to the S/PDIF pin is bit transparent. It is not deployed, and it cannot work on hardware until the second boundary lands, because nothing yet selects the mode, mutes the unused output, bypasses the framework mixer's attenuation, boost, mix and filter, or sets the S/PDIF non audio channel status bit that is currently hardwired to zero. Built therefore refers to the helper only and Passed remains unchecked.

#### Next Steps:

Start the second boundary, which is the integration the user described: an OSD option choosing S/PDIF or HDMI audio, the unused output muted, a bit transparent path proven rather than assumed, the framework fork the user approved for the channel status bit and the mixer bypass, and a Main patch line so the launch passes the selected mode. Define the option name, the muting mechanism and the transparency proof before editing RTL. When it reaches hardware, the existing channel sweep fixture is the six channel sound test with no new fixture needed, and LFE becomes audible for the first time because the stereo downmix discards it. Do not describe the user's 2.1 soundbar locking onto a burst as proof of discrete channel routing; that needs the community test on real 5.1 hardware. A commercial AC-3 track with real dynamic range control remains uncompared. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/Makefile
- host/arm/ARCHITECTURE.md
- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [ ] Passed

---

## 614 COMMIT Unreleased 9623fa7 2026-08-27T07:34:33-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Record the channel sweep run's own hardware telemetry and transport log.

#### Outcome:

The capture requested as the MPEG Layer II regression is in fact the AC-3 channel sweep run, which the helper log identifies unambiguously by source path, so it is recorded as what it is rather than as the regression it was expected to be. That is a useful outcome anyway, because entry 613 had to accept the sweep without its own transport log after the movie overwrote the previous one; this capture supplies it. The sweep completes cleanly with all 360 reference and display pictures, 359 swaps, 14,469,731 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps and outliers, with all three largest display intervals at exactly the nominal 2,002,000 clocks. Audio underrun and PCM protocol error are clear at FIFO peak 127, and both timestamp conflict counters are zero. Helper PID 3257 submitted 16,958,580 transport bytes over 1,036 reads with 16 sampled ACK records and exited zero at 11.931 seconds. The installed RBF still hashes to accepted `d466bed`, Main is unchanged, and the full movie fixture is still present and byte-exact at 739,065,873 bytes, so the AC-3 work has disturbed nothing on the target. The MPEG Layer II hardware regression therefore remains uncaptured: its log was overwritten by this sweep run exactly as the single fixed log path implies, and the user's report that the movie plays perfectly still stands without telemetry behind it. That gap is stated rather than closed. This entry makes no source change, so Built and Passed refer to the accepted helper at `9623fa7`, with Passed covering the sweep run's own clean completion.

#### Next Steps:

The MPEG Layer II regression needs one dedicated replay with nothing played afterwards, capturing the helper log before anything else is started, and requiring all 17,876 pictures, the exact 839,409,548 transport bytes and the entry 605 and 606 error and deadline state, allowing for the one known repeated frame at picture 692 recorded in entry 609. The user has asked for real surround over S/PDIF before release, which is the passthrough boundary and is scoped but not started. Its shape is now known from the framework: an AC-3 frame is 1536 samples at 48 kHz and an IEC 61937 burst occupies exactly the same period, so the helper can pack the bursts on the ARM and send them down the existing PCM transport without a new transport or any decoder in fabric. Three obstacles are real and must be settled before work starts. The framework's mixer applies attenuation, boost, mix and a biquad filter to every sample, and passthrough requires a bit-transparent path because any non-unity gain destroys the burst. The S/PDIF encoder hardwires the channel status non-audio bit to zero, so the stream always declares linear PCM, and setting it means editing framework code this project has otherwise left alone. HDMI would carry the same burst data as if it were PCM, which is loud noise on speakers, so a mode selection and an HDMI audio decision are required rather than optional. DTS passthrough is the same machinery with a different data type and burst length. A commercial AC-3 track with real dynamic range control is still uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 613 COMMIT Unreleased 9623fa7 2026-08-27T07:30:48-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Accept AC-3 stereo decode on hardware from the channel sweep listening result.

#### Outcome:

The user played the channel sweep fixture and reports hearing the expected pattern correctly, and on both outputs rather than only one. The earlier HDMI silence of entry 612 is resolved and was not a core defect: the monitor's volume was turned down. HDMI and S/PDIF are therefore both confirmed to carry the decoded stereo, which matches the framework feeding both from the same PCM and removes the only unexplained observation from the previous entry. Combined with the exact host measurement in entry 612, where front left and right appear only on their own sides, centre appears equally in both at 4.52 dB below the fronts, the surrounds appear on their own sides at 6.02 dB below, and LFE is correctly absent, AC-3 stereo decode and downmix are accepted on hardware for this fixture. The user separately reports that the accepted MPEG Layer II movie also plays perfectly on the new helper, which is the hardware confirmation entry 611 and 612 asked for, but its telemetry is not captured here and that claim rests on the user's report alone. A capture attempted immediately after the report landed mid-playback: the helper log shows the full movie running with only 8,241,152 of 839,409,548 transport bytes submitted at 5.73 seconds, and the screenshot returned a 529 by 240 live video frame rather than the telemetry packet, which the decoder correctly refused as an unsupported layout. That capture is retained as a partial record and is not evidence of completion. The sweep run's own helper log is unrecoverable because the subsequent movie run overwrote it, so the sweep is accepted on the listening result and the entry 612 host measurement rather than on its own transport log; this is a consequence of the single fixed log path and is worth remembering before asking for two runs in succession. The installed RBF still hashes to accepted `d466bed`, the sweep fixture is unchanged on the target, and the Linux boot is still the same session. No source change is made in this entry, so Built and Passed refer to the accepted AC-3 helper at `9623fa7`, with Passed covering AC-3 stereo decode and downmix placement only.

#### Next Steps:

Let the movie finish, then capture the helper log first and a fresh telemetry screenshot to record the MPEG Layer II hardware regression properly, requiring all 17,876 pictures, the exact 839,409,548 transport bytes and the entry 605 and 606 error and deadline state, and remembering the one known repeated frame at picture 692 recorded in entry 609. Only then is codec selection proven not to have disturbed the accepted path on hardware. Ask the user to take the screenshot while the terminal telemetry screen is showing rather than during playback. A community sound test can now be written from the sweep fixture, and it must state plainly that it exercises the stereo downmix rather than discrete surround, since the core emits two channels. A commercial AC-3 track with real dynamic range control and dialogue normalization is still uncompared and remains the honest gap in this codec's qualification. AC-3 and DTS passthrough over S/PDIF remain the separate later boundary, now with both outputs confirmed working for linear PCM. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 612 COMMIT Unreleased 9623fa7 2026-08-27T07:22:37-07:00

#### Coming From:

Unreleased 67aaf7f

#### Purpose:

Capture the first AC-3 hardware run and establish which channels the stereo downmix actually carries.

#### Outcome:

The user played the ten second AC-3 fixture and reported hearing mixed tones from an AV receiver over S/PDIF but nothing from HDMI, on a 2.1 system fed by a portable monitor whose only outputs are two small speakers and a headphone jack. Telemetry is clean: the installed candidate and fixture hash as deployed, all 300 reference and display pictures complete with 299 swaps, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps or outliers, with 12,066,264 accepted video bytes. Audio underrun and PCM protocol error are clear at FIFO peak 127, though `pcm_sample_count` remains a saturated field. Helper PID 2820 submitted 14,143,620 transport bytes over 865 reads and exited zero at 9.930 seconds. This is the first AC-3 audio heard from the core. A misconception in the request is corrected rather than worked around: nothing sends 5.1 anywhere, because the helper downmixes AC-3 to two channels and the framework emits linear PCM on both HDMI and S/PDIF, so the user's subwoofer is their receiver's own bass management of that stereo pair and not a channel the core produces. Discrete surround requires the separate IEC 61937 passthrough boundary. liba52 is asked for `A52_STEREO` without `A52_LFE`, so LFE is decoded and then discarded exactly as the stereo downmix convention requires; the fixture's 55 Hz LFE tone is therefore absent from the output by design and is not a fault. Proving three channels was thus not possible as posed, since only two exist in the signal, but the underlying question was answered completely by a different route. A new sweep fixture mode sounds one source channel at a time so placement is measurable without a 5.1 monitoring rig, and a new analyzer measures each slot. The first sweep exposed a defect in the fixture rather than the decoder: FFmpeg's join filter assigns inputs positionally and that order does not follow the 5.1 layout, so the first three channels were mislabelled, which is also why entry 610's tone check was unreadable and why both the helper and the reference appeared to disagree with the labels. Binding every tone to a named channel fixes it. With that corrected, all six channels land exactly where the downmix specifies: front left at 220 Hz appears only on the left and front right at 277 Hz only on the right at equal level, centre at 330 Hz appears equally in both at 4.52 dB below the fronts, the surrounds at 440 and 554 Hz appear only on their own side at 6.02 dB below the fronts, and LFE is silent in both. The entry 610 channel assignment question is therefore closed, and closed against measurement rather than labels. The silence over HDMI is unexplained and is not yet attributed, since the framework feeds HDMI and S/PDIF from the same stereo PCM; a monitor with small speakers is a plausible but unverified cause and no MiSTer audio setting has been inspected. The sweep fixture was deployed after backing up the installed Main and RBF, staged and renamed with an independent readback that matches. No RTL, FPGA build, Main, RBF, settings, reboot, reload or playback change was made, so Built refers to host tools only and Passed remains unchecked pending a listening result on the sweep.

#### Next Steps:

Have the user play games/MediaPlayer/ac3_channel_sweep_12s.mpg once through the receiver and report, for each two second slot in order, whether the tone appears on the left, the right, in both or not at all, expecting left, right, both, silence, left, right. Headphones on the monitor's jack are the cheapest way to separate a genuine HDMI audio fault from small speakers, and MiSTer's audio configuration should be checked before treating HDMI silence as a core defect. That listening result is what the community sound test should be built from, and any community request should say plainly that it exercises the stereo downmix, not discrete surround, so testers are not asked to judge channels the core does not yet emit. Replay the MPEG Layer II movie to confirm codec selection did not disturb the accepted path on hardware, which is still only regression tested on the host. A commercial AC-3 track with real dynamic range control and dialogue normalization remains uncompared. AC-3 and DTS passthrough over S/PDIF remain the separate later boundary, and the confirmed live S/PDIF port is a useful precondition for it. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/analyze_ac3_downmix.py

#### Status:

- [x] Built
- [ ] Passed

---

## 611 COMMIT Unreleased 67aaf7f 2026-08-27T07:12:58-07:00

#### Coming From:

Unreleased ff6c03f

#### Purpose:

Qualify the AC-3 helper on a ten second fixture and stage it on the MiSTer for the user's first listening test.

#### Outcome:

The user asked for a ten second clip rather than a full length one for the first AC-3 test, which the fixture generator already supported. Generating at ten seconds exposed a defect in the generator rather than in the decoder: decoding the muxed program to raw stereo made FFmpeg's s16le muxer report a duplicate final DTS, which the shared runner correctly refuses because it requires clean output. Published source `67aaf7f` fixes that properly rather than by relaxing the check, extracting the private stream 1 substream into an elementary stream and decoding that instead, which carries no container timestamps and is byte for byte what the helper is handed; the elementary stream's own size and hash are now recorded too. The five second fixture regenerates unchanged through the new path. The ten second fixture is 12,787,729 bytes with SHA256 `fb71dee0a1af7746809505b73ccc432f5951fbf01579ca63bbcb90e6c7aefece`, carrying 300 pictures over 10.01 seconds of 720x480 TFF all-I video and 448 kbit/s AC-3 5.1 on substream 0x80, with a 560,896-byte AC-3 elementary stream. Against the independent FFmpeg decode the helper produces exactly 480,768 stereo frames, matching the reference frame for frame over 10.016 seconds, with maximum absolute difference three, RMS difference 0.4251 left and 0.4492 right, and correlation 0.999999971 and 0.999999967, reproducing the five second result at twice the length. The helper log line naming substream 0x80 appears as intended. Installed state was backed up before anything was written: the previous 361,452-byte helper with SHA256 `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`, the unchanged Main and the accepted `d466bed` RBF are all retained under the entry 611 backup directory. The new 399,340-byte helper with SHA256 `100a3c1f97e9a0d0e77e3992bfc6db8584d17081798fc2e1dbeb365faf2269c4` and the fixture were then deployed through a staged name with a hash check before rename and an independent readback on a fresh connection after it; both readbacks match exactly. Main, the RBF and settings are untouched, and no reboot, core reload or playback was performed, so lifecycle stays with the user. Built refers to the helper only, since no FPGA build was needed or made, and Passed remains unchecked because nothing has been listened to yet. The open questions from entry 610 are unchanged: channel assignment is still unverified because the fixture's tone labels disagree with the assumed layout in both the helper and reference decodes, and a real commercial AC-3 track with genuine dynamic range control and dialogue normalization has not been compared.

#### Next Steps:

Have the user select the MediaPlayer core and play games/MediaPlayer/ac3_480i_tff_5p1_10s.mpg once, reporting whether sound is present, whether it stays synchronized across the ten seconds and whether the menu stays responsive, and noting that the fixture is deliberately six discrete tones rather than programme material. Retrieve the helper log first and confirm the substream selection line, then take a fresh telemetry screenshot and check the audio error and underrun state along with the picture counts for the 300 pictures. Because this helper replaces the one the accepted full movie ran on, replay the MPEG Layer II movie afterwards to confirm codec selection did not disturb the accepted path on hardware, since only the host side has been regression tested. Then resolve channel assignment by decoding each channel separately rather than trusting the downmixed tone labels. AC-3 passthrough over S/PDIF and DTS passthrough remain the separate later boundary needing IEC 61937 packing and a neutral gain and filter chain; the user has confirmed the S/PDIF port is live and already carries stereo synchronized with HDMI, which is a useful precondition but not evidence about compressed output. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ac3_av.py

#### Status:

- [x] Built
- [ ] Passed

---

## 610 COMMIT Unreleased ff6c03f 2026-08-27T07:09:10-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Decode DVD AC-3 audio to stereo PCM in the ARM helper on the same path MPEG Layer II already uses.

#### Outcome:

Published source `ff6c03f` routes private stream 1 substreams 0x80 through 0x87 to liba52 and downmixes to the existing 48 kHz stereo PCM transport, so no RTL, FPGA memory or timing budget is touched and the 41 free M10K blocks are untouched. `process_private_pes` previously discarded exactly these packets. It now reads the substream identifier, frame count and first access unit pointer, honours that pointer only until the decoder has synchronized, and appends the remainder. Codec selection follows the helper's own architecture note: the first audio PES decides between MPEG Layer II and AC-3 and the other codec is ignored for the session, with the chosen substream identifier logged and further AC-3 tracks skipped because track switching needs the versioned control channel protocol one omits. liba52 is asked for `A52_STEREO` with `A52_ADJUST_LEVEL`, so the stream's own downmix coefficients are used and the helper invents no matrix of its own, and the decoder is initialized lazily so Layer II files neither allocate it nor inherit its startup message. Two planning errors are corrected here. Entry 610's proposal said the liba52 sources would be committed under the helper dependency directory, but that directory is gitignored by existing policy and dependencies are pinned by `build_arm_stack.sh` instead, as README already describes for minimp3; liba52 0.7.4 is therefore fetched from a pinned tarball with SHA256 `a21d724ab3b3933330194353687df82c475b5dfb997513eef4c25de6c865ec33`, extracted to the same place, and only the hand-written replacement for its autoconf `config.h` is tracked. A scoping remark that GPL would contaminate the project was also wrong and is corrected: liba52 is GPL-2 and so is this project. The AC-3 fixture uses private stream 1, which the soak generator's pack checker rejected, so that checker gains a stream identifier parameter while its MPEG Layer II default is unchanged. A new deterministic generator produces a five second 720x480 TFF all-I fixture carrying 448 kbit/s AC-3 5.1, keeping the accepted video path unchanged so the fixture isolates the audio codec; the generated media stays local and only the generator is committed. Against an independent FFmpeg decode of the same program, the helper produces exactly 241,152 stereo frames, matching the reference frame for frame, with maximum absolute difference three, RMS difference 0.4257 left and 0.4509 right, and correlation 0.999999971 and 0.999999967. That is comparable to the accepted Layer II qualification and is deliberately not a bit-exactness claim, since liba52 and FFmpeg differ in downmix coefficients, dynamic range handling and rounding. The fixture's per-channel tone labels do not match the layout the generator assumed, and the reference decode shows the same mapping, so channel assignment is not independently verified by this evidence and only decode equivalence is; that check remains open. The MPEG Layer II path is unchanged, reproducing the exact 28,628,352 PCM samples and 17,776 timestamp records entry 602 recorded for the full movie, where the video output byte count exceeds the 715,713,077-byte payload by precisely those records. The helper cross-compiles cleanly under `-Werror` with MiSTer's official ARM GNU 10.2 toolchain to a 399,340-byte static binary with SHA256 `100a3c1f97e9a0d0e77e3992bfc6db8584d17081798fc2e1dbeb365faf2269c4`, and the dependency fetch, extraction and build were exercised from an empty dependency directory. GUNSMOKE has no qemu-arm, so that ARM binary is compiled but unexecuted and all decode evidence comes from a native build of identical sources. The user separately confirmed that the MiSTer S/PDIF port is live and already carries stereo audio synchronized with HDMI, which is useful for the later passthrough boundary but is not evidence about AC-3. No FPGA build, deployment or hardware run occurred, so Built refers to the helper only and Passed remains unchecked.

#### Next Steps:

Deploy the new helper and have the user play the generated AC-3 fixture once, reporting sound, synchronization and menu behavior, then capture the helper log first and a fresh telemetry screenshot as usual and confirm the substream selection line appears. Before that, generate the fixture locally, since it is deliberately not committed. Resolve the open channel assignment question by decoding each channel separately rather than relying on the downmixed tone labels, and only then claim correct 5.1 channel identity. Consider whether a real commercial AC-3 track, which uses dynamic range control and dialogue normalization far more aggressively than a synthetic tone fixture, deserves its own comparison before this is called finished. AC-3 passthrough over S/PDIF and DTS passthrough remain the separate later boundary, needing IEC 61937 packing and a neutral gain and filter chain rather than any decoder change, and the framework's S/PDIF encoder carries linear PCM only. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/Makefile
- host/arm/liba52_config.h
- host/arm/ARCHITECTURE.md
- host/build_arm_stack.sh
- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/verify_ac3_pcm.py
- tools/streams/generate_test_dvd_av_soak.py

#### Status:

- [x] Built
- [ ] Passed

---

## 609 COMMIT Unreleased d466bed 2026-08-27T06:42:34-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Record the user's decision to accept the picture 690 repeated frame as a known limitation rather than deepen the input FIFO.

#### Outcome:

The user rejected the entry 608 proposal to raise `mpeg2_stream_fifo` from 16,384 to 32,768 sixteen-bit words and directed that the defect be logged as a known limitation, so no RTL change is made and the memory headroom of 41 free M10K blocks is preserved for future work. The accepted limitation is stated precisely so a future agent does not rediscover it as a fault: with 98,304 bytes of compressed read-ahead and consumption-paced transport, any coded picture larger than 138,344 bytes cannot be fully buffered ahead of its own decode and costs one display slot, which the hardware shows as a single frame repeated for two slot periods rather than a dropped frame. In the qualified full-movie fixture this affects exactly one picture, number 690 at 150,316 bytes at the scene cut near 23.09 seconds, producing one 66.733333-millisecond interval, roughly 33.4 milliseconds of added running time and no error flag, no dropped picture and no audio effect. The user watched both Bob and Weave runs in full and did not perceive it. This limitation is a property of buffer depth against peak coded picture size, not of the film, so other sources with a picture above the threshold will show the same single-slot repeat at that picture, and sources whose peak stays below it will not. The threshold is not a standards limit and must never be described as one; ITU-T H.262 and H.222.0 impose no such constraint, and the fixture itself is legal with zero VBV underflow throughout. The margin to the runner-up picture is only 1,994 bytes, so the exact threshold should be treated as approximate and re-derived rather than quoted as exact if the buffer depth, declared rate or decode timing assumption ever changes. The known fix, if the trade is ever worth making, is recorded in entry 608 along with its estimated cost of roughly 26 M10K blocks and its fit and timing risk at 93 percent utilization. No source, build, deployment, setting or playback changed in this cycle, and the Built and Passed marks refer to the unchanged, already-accepted `d466bed`.

#### Next Steps:

Treat `d466bed` as the current accepted baseline with the picture 690 limitation documented, and do not reopen it as a defect without new evidence such as a source that misses more than one slot or a run whose miss count exceeds the model's prediction. Carry the limitation into release notes when a version boundary is next prepared, since it is user-visible behavior on high-peak sources. The remaining qualification gates are unchanged and each needs scope and acceptance criteria agreed before work starts: Bob and Weave coverage beyond this single fixture, AC-3 audio, interlaced P and B pictures and field DCT, navigation, and ISO or disk-sourced playback. Await the user's direction on which gate to open next rather than selecting one unilaterally. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

