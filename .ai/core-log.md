## 100 COMMIT Unreleased ??? 2026-09-14T14:54:34-07:00

#### Coming From:

Unreleased 6d564e9

#### Purpose:

Establish a codec-independent native PCM playback boundary for FLAC and future WAV.

#### Outcome:

The user authorizes continuing and asks that later native 44100 Hz WAV support be accommodated without implementing WAV now. Correct the earlier wording: production movie input supports 48000 Hz MP2; the inherited 96 kHz platform output option is not 96 kHz media decoding. Preserve that platform option without claiming a supported 96 kHz input profile. Implement and simulate a format-independent PCM sink with source-sample position, tick-driven consumption, pause, EOF drain and cancellation, so FLAC and future PCM WAV can share output controls. Keep format parsing and file seeking outside the sink. Continue native HDMI work subject to bus ownership validation; no resampling.

#### Next Steps:

Verify exact emitted sample order, pause/resume, last-sample duration, starvation and reset/seek cancellation. Document the shared PCM contract and native-output integration requirements; preserve accepted b639ccc production behavior until the integrated path is ready.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 99 COMMIT Unreleased 6d564e9 2026-09-14T14:31:40-07:00

#### Coming From:

Unreleased ba9e0d8

#### Purpose:

Begin authorized FLAC feasibility and simulation implementation.

#### Outcome:

The user authorizes implementation and then explicitly selects native 44.1 kHz FLAC while preserving 48 and 96 kHz platform modes; conversion is excluded. Commit 6d564e9 adds a standalone serial FLAC prediction primitive and reproducible simulation/corpus/Quartus probes, with no production integration. Python integer comparisons pass 4097 vectors including orders 0–32, 17-bit side-channel history, residual/range checks and backpressure, plus 33 reset cancellation points; Verilator lint passes. Isolated virtual-pin prediction fitting uses 150 placed ALMs, 192 estimated ALMs, 106 registers, one DSP and zero M10Ks; this is not full decoder area or production timing. A deterministic 55-file corpus reproduces all original PCM through independent source comparisons; two damaged cases are rejected. Local FFmpeg emits no samples for the large-block noise file, while reference flac 1.5.0 decodes it exactly; the manifest records this secondary-reference limitation. A separate dual-PLL probe fits with two PLLs and 18 registers; fitter frequencies are 24.576 and 22.579199 MHz. The proposed native path retains the movie clock and adds one CD PLL, but current whole-core PLL placement and HDMI operation are unproven. ADV7513 documentation confirms automatic CTS and the channel-status rate field; the remaining native-output gate is an FPGA/HPS I2C owner or proxy that preserves Main traffic and restores/reapplies audio configuration correctly. Proposed frame storage reuses 1 MiB of the inactive compressed-video FIFO's reserved DDR range, subject to explicit drain/ownership testing. RFC 9639 and ADV7513 references are catalogued. Evidence is results/flac and docs/FLAC_FEASIBILITY.md. No playable FLAC RBF exists yet; accepted b639ccc seed 52 remains current.

#### Next Steps:

Implement and simulate the serialized HDMI audio-control path, validating HPS contention, ACK/NACK, reads, resets and reconnects before platform integration. Continue the FLAC bitstream/parser, memory ownership and full-file PCM comparison work using the corpus. Preserve native 44.1 kHz plus existing 48/96 kHz; no resampler and no removal of 96 kHz. Whole-core builds and hardware validation follow meaningful integration gates rather than treating isolated fits as a completed player.

#### Files Modified:

- docs/FLAC_PLAN.md
- docs/FLAC_FEASIBILITY.md
- rtl/audio/flac/flac_predict_mac.sv
- tools/make_flac_tests.py
- tools/synth_flac_clock.py
- tools/synth_flac_predict.py
- tools/test_flac_predict.sv
- tools/verify_flac_predict.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 98 COMMIT Unreleased ba9e0d8 2026-09-14T14:28:21-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Document the staged standalone CD-quality FLAC implementation plan.

#### Outcome:

Added docs/FLAC_PLAN.md and updated the shared-IDCT test instructions to reflect user acceptance. The plan preserves stock Main and standalone 44100 Hz, 16-bit stereo FLAC with exact decoded PCM, normal encoder settings, pause/seek, shared progress UI and drain-to-startup EOF. The current 24.576 MHz audio clock and 48/96 kHz platform output require an early native-44.1-kHz feasibility decision; a high-quality 160/147 converter is a separately disclosed alternative, not bit-perfect HDMI. Plan a serial predictor, CRC-validated frames, bounded M10K queues and DDR-backed channel storage after a memory ownership audit, with full CD-format block/order handling rather than a silently restricted 4096-only decoder. RFC 9639 was consulted as the normative FLAC source and is not yet in core-reference.md; add its controlled reference before RTL implementation. Four gates cover output/resource feasibility, standalone sample equivalence, integrated continuous playback and controls/UI with four-movie regressions. Proposed whole-feature budgets are 3500 ALMs, 28 M10Ks and 12 DSPs, not measured resource estimates. No FLAC RTL or new builds were started.

#### Next Steps:

Review the plan with the user and begin feasibility/output qualification when implementation is authorized. Retain accepted b639ccc MEDIUM seed 52, keep PCM fidelity distinct from output conversion, and measure fitted costs before full integration.

#### Files Modified:

- docs/FLAC_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 97 COMMIT Unreleased b639ccc 2026-09-14T14:26:52-07:00

#### Coming From:

Unreleased db4bc3f

#### Purpose:

Record hardware acceptance of shared-IDCT seed 52.

#### Outcome:

The user reports that the latest build passes everything. Accept the preferred b639ccc MEDIUM seed 52 shared-IDCT candidate as the new hardware baseline, with corrected audit revision db4bc3f, RBF SHA-256 a9244b912ad3acd127366e10d6470fc509ccc3d0c63b29b1a031f6674d7b9f95, 35908 placed ALMs, 512 M10Ks, 59 DSPs, and four-corner setup/hold minima +0.645/+0.081 ns. This supersedes the pending acceptance recorded in entry 96. Retain 7eb5088 MEDIUM seed 61 as the previous rollback. The user also requests a FLAC implementation plan; no FLAC implementation or additional builds are authorized by this planning step.

#### Next Steps:

Draft the standalone 44100 Hz, 16-bit stereo FLAC plan against this accepted baseline, including output-rate handling, bounded on-chip memory, exact sample verification, playback controls and video regression gates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 96 COMMIT Unreleased db4bc3f 2026-09-14T14:12:56-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Correct shared-IDCT physical-register auditing and qualify the existing three fitted builds.

#### Outcome:

Audit-only commit db4bc3f corrects the false failure: Quartus replicated transform_index bits with ~DUPLICATE suffixes inside the sole shared engine. All three fitted b639ccc designs have six logical bits, with 11/12/10 physical registers for seeds 52/61/87. The revised check requires exactly the expected engine hierarchy and six logical indices, records physical names and rejects missing bits, additional engines and unknown suffixes in mutation checks. Existing fitted databases were re-audited without RTL, constraint or RBF changes; hashes match the original compilation outputs. All seeds retain eight intermediate and three staging M10Ks, 183 CDC stages, scene enable and diagnostic-removal checks. Four-corner minima (setup/hold/recovery/removal/pulse width ns) are seed 52 +0.645/+0.081/+3.337/+0.214/+0.925, seed 61 +0.458/+0.048/+2.565/+0.182/+0.925, seed 87 -0.102/+0.105/+3.330/+0.235/+0.925. Thus 52/61 pass and 87 fails cold-corner setup. Preferred seed 52 uses 35908 placed ALMs, 512 M10Ks and 59 DSPs, saving 1136/13/16 versus accepted 7eb5088 MEDIUM seed 61 and leaving 6002/41/53 free. Packaged original b639ccc RBFs and build-info.json identify db4bc3f separately as timing_audit_revision. Evidence is results/build-b639ccc-20260914-135047; original failed timing logs and status are preserved. No full compilation of this audit-only commit was necessary; b639ccc compiled successfully and hardware acceptance remains pending.

#### Next Steps:

Test results/hardware-test-b639ccc/seed52/MediaPlayer_20260914.rbf on Fellow, Groove, Jiggler and Star Wars at both refresh rates, covering opening, motion, audio, pause/seek, reset/file replacement, subtitles/filters and EOF. Preserve accepted 7eb5088 MEDIUM seed 61 as rollback; do not start extra timing-fix builds without direction.

#### Files Modified:

- tools/phase1p_timing.tcl
- tools/audit_three_seeds.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 95 COMMIT Unreleased b639ccc 2026-09-14T14:03:21-07:00

#### Coming From:

Unreleased b639ccc

#### Purpose:

Record the standalone CD-quality FLAC music playback target.

#### Outcome:

The user clarifies that FLAC restores the music-player side for the user's own standalone files, not movie audio, and sets the acceptance target: a CD-ripped WAV converted to FLAC should play perfectly. The initial profile is 44100 Hz, 16-bit stereo PCM, reconstructed sample-for-sample with the original WAV before optional output filters or volume processing, with correct playback rate and no dropped/repeated samples or buffer underruns. Ordinary compatible FLAC encoder compression settings must work without a special encoding recipe; a fixed-predictor-only demonstration is insufficient. Validate lossless decoding, channel reconstruction and continuous playback against original WAV samples, plus pause/seek/EOF behavior. High-resolution and multichannel FLAC are outside this initial target. The xavieran/fLaCPGA reference was inspected at a724a18b6205b192bd42977186b669d467b0aa9b: its integrated frame path is restricted to mono and hardcoded 4096-sample blocks, with LPC code separate from the subframe path. It is an architectural reference, not a complete compatible decoder or measured Cyclone V resource estimate. No FLAC RTL is implemented by this scope update; shared-IDCT builds remain independent and the accepted video baseline stays 7eb5088 MEDIUM seed 61.

#### Next Steps:

Use this CD-quality profile for the FLAC design and test corpus, covering ordinary compression settings, metadata, channel coding, block sizes and final short blocks within the target. Measure a standalone decoder implementation before claiming it fits alongside the video player; preserve current video functionality and existing shared-IDCT build work.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 94 COMMIT Unreleased b639ccc 2026-09-14T13:49:03-07:00

#### Coming From:

Unreleased 54d64d2

#### Purpose:

Correct shared-IDCT Quartus syntax compatibility and restart the authorized three-seed batch.

#### Outcome:

The user explicitly authorizes building again, superseding the previous stop. Source b639ccc adds an explicit generate/endgenerate region and separately declared genvar around the shared coefficient banks; no arithmetic, arbitration or memory behavior changes. The existing differential suite again passes 79008 exact samples. Isolated full-design Quartus 17 analysis/elaboration succeeds with zero errors in 41 seconds after supplying the normal generated build_id.v header; evidence is under results/shared-idct-quartus-preflight and /tmp/shared-idct-quartus-preflight.log. Source is committed and pushed; clean MEDIUM seeds 52/61/87 restart under /tmp/shared-idct-build-restart.log. Full compilation, timing and hardware acceptance remain pending. The accepted 7eb5088 MEDIUM seed 61 and failed 54d64d2 batch are preserved.

#### Next Steps:

Monitor the b639ccc batch and audit all corners, placed/estimated ALMs, RAM/DSP savings, one shared IDCT engine with eight intermediate and three staging M10Ks, and existing 183-stage CDC/removal checks. Package the preferred RBF for four-file hardware acceptance at both refresh settings. Retain 7eb5088 MEDIUM seed 61 as rollback; do not launch extra timing-fix batches without direction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_shared_idct.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 93 COMMIT Unreleased 54d64d2 2026-09-14T13:45:57-07:00

#### Coming From:

Unreleased 54d64d2

#### Purpose:

Record the user's build stop and the already-terminated shared-IDCT batch.

#### Outcome:

The user explicitly says to stop the builds. Process inspection finds no running build runner or Quartus process: all three 54d64d2 seeds had already failed after about seven seconds with compile exit 3. The primary error is Quartus 17 syntax rejection at mpeg2_h262_shared_idct.sv line 56 near the module-level for generate loop, followed by cascading declarations. Simulation passes do not establish Quartus compatibility. No RBF was produced. No fixes, retries or further builds are performed after the stop instruction; accepted 7eb5088 MEDIUM seed 61 remains the hardware baseline.

#### Next Steps:

Await user direction before continuing implementation or restarting builds. Preserve failed logs under results/build-54d64d2-20260914-134450 and /tmp/shared-idct-build.log; inspect explicit generate/endgenerate syntax when work is resumed.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 92 COMMIT Unreleased 54d64d2 2026-09-14T13:22:12-07:00

#### Coming From:

Unreleased 7eb5088

#### Purpose:

Reduce duplicated IDCT hardware with measured shared transform service.

#### Outcome:

The user authorizes the deferred shared-IDCT reduction while the isolated packing run continues. Source 54d64d2 routes intra/P/B clients to one unchanged arithmetic engine, preserving immediate uncontended strobes and using three M10K coefficient banks, sparse masks and round-robin service for contention. Per-client completion/error state and global reset cancellation preserve ownership. Production selects external service; standalone wrappers retain local engines for offline tests. Simulation-only traces measure 288 intra, 1053 P and 1418 B blocks with no overlap in the mixed sample and 5518 request/completion event cycles identical to dedicated engines. The shared-unit oracle passes 79008 exact samples, independent producers, single-cycle sparse blocks, 220 reset offsets and malformed input recovery. Arithmetic/storage equivalence passes 164020 cycles and 52128 samples. Three-client repeated seeks, paired EOF and 50 Hz cases each retain 423936 pixel comparisons and identical reconstruction/cycle accounting. Adding real intra demand exposed the old stubbed-intra fixed cycle budget in both baseline and shared EOF tests; the variant now requires paired baseline accounting instead. The 16 MiB Pee Strike prefix passes normal opening plus ten-second forward seek with shared DDR and intra demand, then confirms audio/video progress without underrun or timestamp warning at cycle 432419997. This harness models bounded ideal CDC and initialized I reference pixels, not a complete physical intra DDR path; independent transform oracles establish numerical equivalence. Expected savings are 16 DSPs and 13 M10Ks; actual ALM savings await fitting. Source is pushed and clean MEDIUM seeds 52/61/87 run under /tmp/shared-idct-build.log. Fitted checks require exactly one six-bit IDCT index, eight intermediate M10Ks and three staging M10Ks alongside all existing CDC/diagnostic-removal audits. Meanwhile 7eb5088 HIGH seed 61 completes in 767.7 seconds: 36245 actual ALMs, 31461 estimated ALMs, 44768 registers, 525 M10Ks, 75 DSPs, setup -0.021 ns and hold +0.114 ns. Its 799 placed-ALM saving comes with failed setup, so accepted MEDIUM 7eb5088 seed 61 remains baseline. The HIGH RBF is hash-verified and separately packaged under results/hardware-test-7eb5088-packing-high/seed61 with a timing-failure marker; no deployment or further HIGH run is performed.

#### Next Steps:

Audit the three 54d64d2 builds for shared-engine and memory inference, timing and resources using accepted MEDIUM 7eb5088 seed 61 baseline 37044 ALMs/525 M10Ks and all diagnostic-removal requirements. Package the best RBF for four-file hardware acceptance at both refresh settings, including pause/seek/reset/replacement, subtitles/filters and EOF. Keep accepted baseline and failed HIGH experiment distinct. No additional timing-fix batches without user direction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- docs/SHARED_IDCT.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_idct.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_shared_idct.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/replay_mpg_seek.py
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_shared_idct.sv
- tools/verify_decoder_timing.py
- tools/verify_shared_idct.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 91 COMMIT Unreleased 7eb5088 2026-09-14T13:19:19-07:00

#### Coming From:

Unreleased 78c82f1

#### Purpose:

Run one isolated maximum-register-packing comparison of the accepted seed 61 core.

#### Outcome:

The user requests a dense packing run. Reuse the previous single-seed packing build helper against clean archived source 7eb5088, with seed 61, six workers and ALM_REGISTER_PACKING_EFFORT HIGH instead of MEDIUM. Keep source RTL and the tracked QSF unchanged. The accepted MEDIUM baseline uses 37044 actual ALMs, 31325 estimated ALMs, 44804 registers, 525 M10Ks and 75 DSPs with setup +0.334 ns and hold +0.074 ns. The prior bcddb20 HIGH experiment saved no ALMs, but the current design differs substantially; measure again without promising savings. Run compilation and all existing four-corner, CDC and diagnostic-removal audits. Evidence will use a distinct results/build-7eb5088-packing-high directory and /tmp/gate3-packing-high.log. This is an experimental build request, not acceptance of its eventual RBF.

#### Next Steps:

Compare final placed and estimated ALMs, RAM, DSP, registers and timing against accepted 7eb5088 MEDIUM seed 61. Package the experiment separately: do not run the normal packaging helper unmodified because its source/seed destination would overwrite the accepted RBF. Keep the accepted MEDIUM artifact and hardware acceptance intact. Report results before any additional build or default-setting change. The previous displayed timing table had a transcription error: fast -40 C recovery is +4.898 ns in the audit JSON, not +4.950 ns; the reported minimum recovery +3.668 ns is unchanged.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 90 COMMIT Unreleased 78c82f1 2026-09-14T13:10:02-07:00

#### Coming From:

Unreleased a206435

#### Purpose:

Record gate-three hardware acceptance and the completed diagnostic-removal cycle.

#### Outcome:

The user reports all tests pass after the preferred 7eb5088 seed 61 handoff, completing the three-gate diagnostic-removal cycle including the compact black-clock progress bar and lowered subtitles. Seed 61 becomes the hardware-accepted baseline; its packaged RBF hash is verified and local build metadata records acceptance. Source 7eb5088 retains four-corner timing qualification, setup +0.334 ns, hold +0.074 ns, 37044 actual ALMs, 31325 estimated ALMs, 525 M10Ks and 75 DSPs, leaving 4866 ALMs and 28 M10Ks. Functional protection and playback remain; standalone diagnostic modules are retained only for offline simulation where applicable. Test instructions and the removal plan record completion; this documentation commit leaves the accepted 7eb5088 hardware unchanged. No source logic changes, new builds, deployment or release are requested.

#### Next Steps:

Use 7eb5088 seed 61 as the accepted baseline for future authorized work and retain 100ab07 seed 87 as rollback; no further diagnostic-removal gate remains.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---

## 89 COMMIT Unreleased a206435 2026-09-14T13:07:28-07:00

#### Coming From:

Unreleased 7eb5088

#### Purpose:

Document and package gate-three build qualification for hardware testing.

#### Outcome:

All three 7eb5088 builds complete in 15.1-15.2 minutes. Seeds 61 and 87 pass all four timing corners; seed 52 fails setup at -0.191 ns. All pass 183 CDC stages, formatter enables, profiler/reporting absence and eleven test-audio removal checks with movie PCM, FIFO and finished synchronization retained. Preferred seed 61 has setup +0.334 ns and hold +0.074 ns, uses 37044 actual ALMs, 31325 estimated ALMs, 44804 registers, 525 M10Ks, 75 DSPs and three PLLs. This saves 282 placed ALMs, 495 estimated ALMs and two M10Ks against accepted gate-two seed 87, leaving 4866 ALMs and 28 M10Ks. Seed 87 uses 36916 actual/31285 estimated ALMs with setup +0.083 ns and hold +0.115 ns. Seed 52 uses 37029 actual/31287 estimated ALMs with hold +0.114 ns. Hash-verified RBFs are packaged under results/hardware-test-7eb5088; seed 52 is marked timing failed. Preferred seed61/MediaPlayer_20260914.rbf SHA-256 is bbd4c36588e5db22343e5e688ef177ed1f54ce24cb4206b8d76332e1d74b84fc. Hardware acceptance is pending; no deployment or additional timing-fix builds are performed.

#### Next Steps:

Qualification is documented and pushed; have the user repeat Fellow, Groove, Jiggler and Star Wars at both refresh rates, checking black clocks on the lowered bar, lowered subtitles, absent status labels and Audio test menu, audio/filters, pause/seek, replacement and EOF. Retain accepted gate-two 100ab07 seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 88 COMMIT Unreleased 7eb5088 2026-09-14T12:45:21-07:00

#### Coming From:

Unreleased 0ad4b1b

#### Purpose:

Remove gate-three Audio test hardware and consolidate playback clocks onto the progress bar.

#### Outcome:

The user reports all gate-two hardware tests pass and authorizes gate three plus compact UI changes. Source 7eb5088 removes the Audio test menu, tone generator, test PCM FIFO, mode/restart mailboxes, reset/control state, adapter and output mux; movie PCM connects directly to MiSTer outputs. Old status bits 1–3 stay reserved. Black elapsed/total/remaining clocks share the bar; Paused/Seeking character generation and status payload bits are removed. The bar and subtitles move down one 14-pixel logical line, preserving activity visibility, seek previews, subtitles and functional pause/seek. Twelve player and five subtitle full-frame cases pass at 480p/720p/1080p. Controls, reader-error seek retirement, subtitle transport/lifetime and EOF pass; mixed and seek-EOF oracles each check 423936 pixels without mismatches. Audio checks 48384 stereo pairs within one PCM unit of FFmpeg, exact pause/seek sequences and 30 PTS records without warning or underrun. Static bindings prove old Audio test bits cannot override movie PCM. Fitted audits require 11 test-hardware patterns absent and three functional PCM groups present, plus the existing 183 CDC checks. Source is pushed and clean seeds 52/61/87 run under /tmp/gate3-build.log. Gate-two 100ab07 seed 87 is hardware accepted and retained as rollback; no core is deployed.

#### Next Steps:

Audit all three builds for timing, retained PCM and CDC, test-hardware absence and resources; package the preferred RBF for the user's four-file hardware acceptance. Use audit_three_seeds.py with --require-no-profiler --require-no-reporting --require-no-audio-test and gate-two baseline 37326 ALMs/527 M10Ks. Do not launch extra timing-fix builds without direction.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_ui_scene.sv
- rtl/media_ui_state.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/test_media_ui_state.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 87 COMMIT Unreleased 0ad4b1b 2026-09-14T12:36:07-07:00

#### Coming From:

Unreleased 100ab07

#### Purpose:

Qualify and package gate-two builds for the user's four-file hardware test.

#### Outcome:

All 100ab07 seeds complete in 15.1-15.6 minutes and pass four timing corners, 183 CDC stage checks, scene-enable checks, zero-profiler audit and all 17 reporting-removal patterns. Seeds 52/61/87 have setup +0.072/+0.188/+0.344 ns, hold +0.116/+0.115/+0.106 ns, actual ALMs 37325/37366/37326 and estimated ALMs 31844/31900/31820. All retain 527 M10Ks, 75 DSPs and three PLLs. Preferred seed 87 leaves 4584 ALMs and 26 M10Ks, with resources essentially flat versus gate-one seed 52: +59 placed and +33 estimated ALMs despite verified reporting-register removal. No further savings should be claimed from this gate. Hash-verified candidates are under results/hardware-test-100ab07; preferred seed87/MediaPlayer_20260914.rbf SHA-256 is 297690c42da92880077be53601e23a7a7fc8c6d4d90fc50105577f0c7f288dba. Audio test remains for gate three. No additional builds, timing fixes or deployment were performed; gate-two hardware acceptance is pending.

#### Next Steps:

Have the user test Fellow, Groove, Jiggler and Star Wars with playback, pause/seek, subtitles, OSD/filters, file replacement and EOF at both output rates; await authorization before gate three. Retain gate-one seed 52 and accepted b05b76f seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 86 COMMIT Unreleased 100ab07 2026-09-14T12:09:09-07:00

#### Coming From:

Unreleased a406feb

#### Purpose:

Implement gate-two reporting removal and frozen MPEG2FPGA repository cleanup.

#### Outcome:

The user authorizes gate two after the gate-one candidate handoff. Source 100ab07 removes the reporting mailbox, minimum-reservoir tracking, audio warning/sample-count crossings, whole-second reporting, dead LED-success expressions and 70 unconsumed decoder observation connections. Standalone module observation ports remain for simulation; a 17-pattern fitted audit requires their selected reporting registers absent in production. Seek/EOF now use identical named pending-frame/reorder state outputs. A dependency review found reader failure also traveled through the old telemetry bus into seek control; a dedicated one-bit reader_error_config mailbox preserves that function and the mandatory CDC total stays 183. Live timeout quarantine, fatal checks, PCM-finished crossing, generation/byte position, 90 kHz ticks and Audio test remain. The inactive 57-file MPEG2FPGA tree and two wrappers are deleted, with provenance and retained licensing documented. Mixed I/P/B EOF and seek-to-EOF/ownership oracles each pass 423936 pixels with no mismatch; controls, reader fault/quarantine, raster/refresh, subtitle/UI and independent reader-error CDC/seek retirement pass. Audio checks 48384 sample pairs within one PCM unit of FFmpeg, exact pause/seek output and 30 PTS records without underrun or timestamp warning. Evidence is under results/gate2-*. Source is pushed and clean seeds 52/61/87 run under /tmp/gate2-build.log. No core is deployed and no gate-three work starts. Timing will be reported without extra closure builds per the user's preference.

#### Next Steps:

Audit and package gate-two timing, remaining CDC, reporting-register absence and resources; provide the preferred RBF for Fellow, Groove, Jiggler and Star Wars. Retain gate-one seed 52 and explicitly hardware-accepted b05b76f seed 87; wait for user authorization before gate three.

#### Files Modified:

- CHANGELOG.md
- CONTRIBUTING.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- README.md
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/LEGACY_MPEG2FPGA.md
- docs/MPEG2_NEW_DECODER.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/mpeg2_ddram_bridge.sv
- rtl/mpeg2_decoder.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2fpga/README.md
- rtl/mpeg2fpga/compat/generic_dpram.v
- rtl/mpeg2fpga/compat/generic_fifo_dc.v
- rtl/mpeg2fpga/compat/generic_fifo_sc_b.v
- rtl/mpeg2fpga/compat/wrappers.v
- rtl/mpeg2fpga/mpeg2/fifo_size.v
- rtl/mpeg2fpga/mpeg2/framestore.v
- rtl/mpeg2fpga/mpeg2/framestore_request.v
- rtl/mpeg2fpga/mpeg2/framestore_response.v
- rtl/mpeg2fpga/mpeg2/fwft.v
- rtl/mpeg2fpga/mpeg2/getbits.v
- rtl/mpeg2fpga/mpeg2/idct.v
- rtl/mpeg2fpga/mpeg2/iquant.v
- rtl/mpeg2fpga/mpeg2/mem_addr.v
- rtl/mpeg2fpga/mpeg2/mem_codes.v
- rtl/mpeg2fpga/mpeg2/mixer.v
- rtl/mpeg2fpga/mpeg2/modeline.v
- rtl/mpeg2fpga/mpeg2/motcomp.v
- rtl/mpeg2fpga/mpeg2/motcomp_addrgen.v
- rtl/mpeg2fpga/mpeg2/motcomp_dctcodes.v
- rtl/mpeg2fpga/mpeg2/motcomp_dcttype.v
- rtl/mpeg2fpga/mpeg2/motcomp_motvec.v
- rtl/mpeg2fpga/mpeg2/motcomp_picbuf.v
- rtl/mpeg2fpga/mpeg2/motcomp_recon.v
- rtl/mpeg2fpga/mpeg2/mpeg2video.v
- rtl/mpeg2fpga/mpeg2/osd.v
- rtl/mpeg2fpga/mpeg2/pixel_queue.v
- rtl/mpeg2fpga/mpeg2/probe.v
- rtl/mpeg2fpga/mpeg2/read_write.v
- rtl/mpeg2fpga/mpeg2/regfile.v
- rtl/mpeg2fpga/mpeg2/regfile_codes.v
- rtl/mpeg2fpga/mpeg2/resample.v
- rtl/mpeg2fpga/mpeg2/resample_addrgen.v
- rtl/mpeg2fpga/mpeg2/resample_bilinear.v
- rtl/mpeg2fpga/mpeg2/resample_codes.v
- rtl/mpeg2fpga/mpeg2/resample_dta.v
- rtl/mpeg2fpga/mpeg2/reset.v
- rtl/mpeg2fpga/mpeg2/rld.v
- rtl/mpeg2fpga/mpeg2/syncgen.v
- rtl/mpeg2fpga/mpeg2/syncgen_intf.v
- rtl/mpeg2fpga/mpeg2/synchronizer.v
- rtl/mpeg2fpga/mpeg2/timescale.v
- rtl/mpeg2fpga/mpeg2/vbuf.v
- rtl/mpeg2fpga/mpeg2/vlc_tables.v
- rtl/mpeg2fpga/mpeg2/vld.v
- rtl/mpeg2fpga/mpeg2/vld_codes.v
- rtl/mpeg2fpga/mpeg2/watchdog.v
- rtl/mpeg2fpga/mpeg2/wrappers.v
- rtl/mpeg2fpga/mpeg2/xfifo_sc.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo144.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo216.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo_dc.v
- rtl/mpeg2fpga/mpeg2/xilinx_fifo_sc.v
- rtl/mpeg2fpga/mpeg2/yuv2rgb.v
- rtl/mpeg2fpga/mpeg2/zigzag_table.v
- rtl/mpeg2fpga/mpeg2fpga.qip
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/test_reader_error_seek.sv
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 85 COMMIT Unreleased a406feb 2026-09-14T12:07:01-07:00

#### Coming From:

Unreleased 8e418b3

#### Purpose:

Qualify and package diagnostic-removal gate one for the user's four-file hardware test.

#### Outcome:

All 8e418b3 seeds compile and pass all four timing corners, 183 CDC checks, scene-enable checks and zero-profiler-register audits. Seed 52 is preferred with setup +0.397 ns and hold +0.114 ns; seeds 61/87 have setup +0.397/+0.197 ns and hold +0.099/+0.089 ns. Actual ALMs are 37267/37169/37350 and estimated ALMs 31787/31731/31708, with unchanged 527 M10Ks and 75 DSPs. Compared with accepted b05b76f seed 87, preferred gate-one seed 52 saves 964 estimated ALMs but only 143 placed ALMs because packing differs. The reporting mailbox survives this gate and all six stages remain audited; profiler hardware is absent. Hash-verified candidates and notes are under results/hardware-test-8e418b3; preferred seed52/MediaPlayer_20260914.rbf SHA-256 is 78501002b4e4d9669635ffa30e9f744e47103baf0e12740e09594f2a40c625a8. The user says not to pursue timing closure now; no fixes or extra builds were needed or started. They additionally authorize frozen MPEG2FPGA reference cleanup at gate two; the plan records checking unused wrappers and retaining required attribution. Gate-one hardware acceptance is pending; no core was deployed.

#### Next Steps:

Have the user test Fellow, Groove, Jiggler and Star Wars including no telemetry, black transparent status text, audio/video, controls, subtitles and EOF at both output rates. Proceed to reporting-source and frozen-reference cleanup only after gate-one acceptance; retain b05b76f seed 87 as rollback.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 84 COMMIT Unreleased 8e418b3 2026-09-14T11:46:01-07:00

#### Coming From:

Unreleased e9f9bfb

#### Purpose:

Implement diagnostic-removal gate one and transparent black playback status text.

#### Outcome:

Source 8e418b3 implements gate one of the user-approved three hardware gates: removes the cadence profiler instance, frozen snapshot/telemetry rendering, unused RGB declarations, production QIP inclusion and obsolete snapshot CDC exceptions. Framebuffer RGB now passes directly to the existing video outputs with unchanged sync/DE; seek/EOF scheduler debug bits, reporting-source RTL, functional errors and Audio test remain. The fitted audit requires zero profiler registers; the telemetry-only mailbox may be naturally pruned, but every surviving stage and all functional mailboxes remain checked. The user's additional status change renders Paused/Seeking in opaque black with transparent glyph gaps instead of a white inset, preserving progress fill, coordinates and subtitle backdrops. Twelve player frame cases and five subtitle frame cases pass with zero pixel mismatches at 480p/720p/1080p; parser, transport, subtitle lifecycle, UI lifetime/divider, playback/audio and 64-check EOF/session regressions pass. Mixed I/P/B EOF qualification passes with 423936 pixel comparisons and zero mismatches. Generated empty/full status previews were inspected. The source and updated three-gate plan are pushed; clean seeds 52/61/87 are running under /tmp/gate1-build.log. No core is deployed. Gate two and gate three remain blocked on separate user hardware acceptance, with accepted b05b76f seed 87 retained as rollback.

#### Next Steps:

Audit all corners, profiler absence, remaining CDC and resource usage; package the strongest passing RBF for Fellow, Groove, Jiggler and Star Wars tests. Wait for gate-one hardware acceptance before removing reporting sources or Audio test.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- docs/DIAGNOSTIC_REMOVAL_PLAN.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_overlay_compositor.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 83 COMMIT Unreleased e9f9bfb 2026-09-14T11:40:39-07:00

#### Coming From:

Unreleased 6688db2

#### Purpose:

Record hardware acceptance of the EOF core and plan safe production diagnostic removal.

#### Outcome:

The user reports the latest EOF core passes, accepting b05b76f seed 87's startup return, session clearing and layout as the new rollback baseline. Its package metadata is marked accepted. Source e9f9bfb adds a proposed removal plan only; no RTL is changed and no new builds start. The inventory identifies the cadence snapshot/overlay, 256-bit telemetry mailbox, reporting-only counters and CDC, profiler-only seconds clock and Audio test generator/transport/menu. Seek and EOF consume scheduler debug bits 26 and 0, so named functional outputs must replace them before debug cleanup. Decoder modules named probe/diagnostic, fatal checks, timeouts, byte positions, generations, FIFO flow control, PCM finished synchronization and the 90 kHz timebase must remain. Proposed implementation is two reviewable commits followed by one three-seed batch, with pixel/PCM/control/subtitle regressions and post-fit proof of removal. Simulation tooling remains; the unbuilt audio warning tolerance becomes unnecessary in production when its reporting consumer is removed. Baseline is 37410 actual ALMs, 527 M10Ks and 75 DSPs; savings must be measured rather than promised.

#### Next Steps:

Present the plan for implementation approval, then remove reporting hardware while preserving functional safety and qualify seeds 52, 61 and 87 against accepted b05b76f.

#### Files Modified:

- docs/DIAGNOSTIC_REMOVAL_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 82 COMMIT Unreleased 6688db2 2026-09-14T11:22:33-07:00

#### Coming From:

Unreleased b05b76f

#### Purpose:

Reproduce and correct the startup audio timestamp warning observed on Fellow and Groove.

#### Outcome:

Source 6688db2 changes only the audio timestamp warning tolerance from two to 90 ticks (1 ms); sample scheduling and underrun detection are unchanged. Exact first-MiB replays reproduce Fellow and Groove at sample 4608 before consumption (hardware count 4609): second audio PES PTS is 56477 instead of the continuous sample-grid value 56492, a 15-tick/167-us backward step. Jiggler and Star Wars have the aligned timestamp and no warning. Before/after replays of all four files preserve identical PCM, video bytes and PTS output and now have no warning or underrun. Seven directed cases cover zero/two/15/90-tick tolerance, retained warnings at 91/900 ticks, timestamp wrap, exact 512-clock cadence and 6912 sample pairs each. Playback, EOF/session and generated-MPG PCM/PTS, pause and seek regressions pass. The timed MPG bench now uses production 60/24.576 MHz clocks rather than 100/40.96 MHz. Evidence is in results/audio-startup-before, results/audio-startup-after, results/audio-tolerance-controls.json and results/audio-tolerance-mpg.json. The unchanged EOF source b05b76f finished all builds: seeds 52 and 87 pass four corners, 183 CDC registers and scene-enable checks; seed 61 misses setup by 0.009 ns. Preferred EOF seed 87 has setup +0.358 ns, hold +0.099 ns, 37410 actual ALMs, 527 M10Ks and 75 DSPs, leaving 4500 ALMs and 26 M10Ks. Packaged results/hardware-test-b05b76f/seed87/MediaPlayer_20260914.rbf has SHA-256 e9ac8007db6a50877ea9ebc7b666b7879f0c30954bf168beefe3569fff08b093. It does not include the audio warning fix. No new Quartus batch or hardware deployment was started for 6688db2.

#### Next Steps:

Have the user validate EOF and layout with b05b76f seed 87, retain accepted ec56250 seed 87 as rollback, and include 6688db2 in the next hardware build to confirm startup telemetry stays absent on Fellow/Groove.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- rtl/audio/mp2_pcm_output.sv
- tools/replay_audio_startup.py
- tools/test_mp2_timestamp_tolerance.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 81 COMMIT Unreleased b05b76f 2026-09-14T10:59:57-07:00

#### Coming From:

Unreleased b5a17cf

#### Purpose:

Return completed playback to the startup state after safely draining audio and video.

#### Outcome:

Source b05b76f implements EOF-only closure; resume is dropped. Physical EOF, completed ingress, drained presentation and finished audio gate a final source-frame interval, then a generation-tagged mailbox closes the logical file through the existing safe restart path. This clears subtitle association, times, controls and startup-message suppression; pause, seek and preflight block closure, and new mounts take priority over stale completion. The 64-check EOF/session test passes for five source frame rates, longer audio, pause/seek/probe inhibition, activity restart, stale completion, simultaneous replacement and delayed host/DDR retirement. The real mixed I/P/B pipeline completes EOF with 423936 pixel comparisons and zero mismatches. Existing playback/audio, reader/session and subtitle lifecycle regressions pass. Source is pushed and clean seeds 52/61/87 are running under /tmp/eof-build.log. The preceding b5a17cf layout batch is also qualified: all seeds pass four corners and 171 CDC checks; setup is +0.508/+0.436/+0.313 ns, hold +0.113/+0.098/+0.076 ns and actual ALMs 38593/38727/38559, with unchanged 527 M10Ks and 75 DSPs. Layout-only candidates are packaged under results/hardware-test-b5a17cf, preferred seed 52; layout hardware acceptance remains pending. No core was deployed.

#### Next Steps:

Audit and package the EOF build timing/resources, then test clean completion, subtitle clearing, longer audio tails, paused EOF, seek endpoints and replacement movies at both output rates. Retain hardware-accepted ec56250 seed 87 as rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_eof_control.sv
- tools/audit_three_seeds.py
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_media_eof_control.sv
- tools/verify_decoder_timing.py
- tools/verify_playback_controls.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 80 COMMIT Unreleased b5a17cf 2026-09-14T10:42:12-07:00

#### Coming From:

Unreleased 47630c7

#### Purpose:

Rearrange the hardware-accepted subtitle overlay around the progress bar.

#### Outcome:

The user reports everything works perfectly after the ec56250 seed 87 handoff, accepting the subtitle baseline. Source b5a17cf implements their requested layout: reference clocks y=469 below the unchanged [452,466) progress track, Paused/Seeking y=455 on the bar, and subtitle lines y=417/431, two 14-pixel lines below the previous positions. Text palette one provides dark status lettering on a light inset; rectangle palette one retains the existing subtitle backdrop alpha blend. Twelve player-frame cases and five subtitle-frame cases pass with zero pixel mismatches at 480p, 720p and 1080p, including status over empty/full/unknown progress, controls hiding and stale cue epochs. Parser, two-drive transport, pause/seek controller, retained-provider and 518 divider checks also pass. Preview, subtitle notes, test instructions and changelog are updated. Source is pushed and clean seeds 52, 61 and 87 are starting under /tmp/subtitle-layout-build.log. Subtitle parsing and playback behavior are unchanged; no new core was deployed.

#### Next Steps:

Audit completed timing and resources, package the preferred qualified RBF, then have the user confirm bottom margins, status contrast and subtitle positioning. Retain accepted ec56250 seed 87 as rollback.

#### Files Modified:

- CHANGELOG.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html
- rtl/media_overlay_compositor.sv
- rtl/media_ui_scene.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 79 COMMIT Unreleased 47630c7 2026-09-14T10:30:19-07:00

#### Coming From:

Unreleased ec56250

#### Purpose:

Qualify and package the manually loaded subtitle builds for hardware testing.

#### Outcome:

All ec56250 seeds compile and pass all four timing corners, 171 CDC registers and scene-enable checks. Seeds 52/61/87 have setup +0.116/+0.136/+0.338 ns, hold +0.115/+0.108/+0.110 ns and actual placed ALMs 37536/38678/38773. All use 527 M10Ks and 75 DSPs, adding seven RAM blocks and six DSPs and leaving 26 M10Ks free. Fitter confirms four subtitle-reader RAM blocks and two parser buffers, with the overlay hierarchy rising from 15 to 16. Estimated ALMs 33032/32933/32936 exceed baseline ffafc79 seed 87's 31987; seed 52's lower physical occupancy reflects packing rather than a functional logic reduction. Preferred seed 87 has the strongest setup margin; seed 52 is a passing lower-occupancy alternative. Hash-verified RBFs and testing notes are under results/hardware-test-ec56250, including Subtitle Test.srt. Preferred seed87/MediaPlayer_20260914.rbf SHA-256 is 765fc4eea7ec7e5a4d2701a3ac470d0f6e4dacadfaef4acd5f771b517bb59752. The audit tool now accepts a scope string instead of incorrectly describing subtitle builds as framework-only. No hardware deployment or acceptance occurred.

#### Next Steps:

Have the user test manual SRT selection, cue timing, pause and all seek sizes/directions, Off/On, file changes, controls hiding and subtitle placement at supported HDMI resolutions. Retain ffafc79 seed 87 as rollback; session resume and EOF policy remain separate release tasks.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- tools/audit_three_seeds.py

#### Status:

- [x] Built
- [ ] Passed

---

## 78 COMMIT Unreleased ec56250 2026-09-14T09:56:47-07:00

#### Coming From:

Unreleased c4b40c4

#### Purpose:

Implement manually loaded SRT subtitles through stock Main and the existing shared overlay.

#### Outcome:

Source ec56250 adds stock Main S1 mounted SRT loading and an On/Off control. A serialized drive owner isolates movie/SRT response writes through the trailing hps_io pipeline. Bounded streaming parsing retains two 63-character lines and timestamps rather than a whole-file database; headers support CRLF/LF and a final cue at EOF, tags are stripped, and non-ASCII UTF-8 codepoints use question-mark fallback. The existing font now covers all printable ASCII without enlarging its ROM. New subtitle reads yield to duration probing, seeks and low movie buffering. Acknowledged commands cross two audited configuration mailboxes into the retained shared-overlay provider, with independent visibility, dark backdrops and seek/file epochs. New movies clear association; seeks drain and rescan at the actual landing position. The user additionally requests lowering Paused/Seeking one line; status is y=417 at 480p and subtitle lines y=389/403, leaving clocks/bar unchanged. Parser, actual two-drive hps_io, asynchronous controller/command transfer, pause, Off/On, both seek directions, in-flight new-movie cancellation, reload and video-priority tests pass. Nine existing full-frame player cases and five subtitle cases at 480p/720p/1080p pass with zero mismatches, plus provider lifetime/state and 518 divider cases. Existing reader cancellation, timeout quarantine and session regressions pass; parser/controller lint is clean. Source is pushed and clean seeds 52, 61 and 87 are starting under /tmp/subtitle-build.log. Require 171 CDC audit registers. No RBF is qualified or deployed yet.

#### Next Steps:

Check synthesis RAM inference, final resources and all-corner timing for the three seeds, package the best qualified RBF and test with the generated Subtitle Test.srt plus real movie subtitles. Retain ffafc79 seed 87 as rollback; session resume and EOF policy remain separate release tasks.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- README.md
- docs/SUBTITLES.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/font-sheet.html
- docs/ui/overlay-preview.html
- files.qip
- rtl/media_overlay_font.mem
- rtl/media_player_overlay.sv
- rtl/media_sd_owner.sv
- rtl/media_srt_parser.sv
- rtl/media_subtitle_cdc.sv
- rtl/media_subtitles.sv
- rtl/media_ui_scene.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/audit_three_seeds.py
- tools/make_subtitle_test.py
- tools/phase1p_timing.tcl
- tools/test_media_player_overlay.sv
- tools/test_media_srt_parser.sv
- tools/test_media_subtitle_hps_io.sv
- tools/test_media_subtitles.sv
- tools/test_media_ui_lifetime.sv
- tools/verify_player_overlay.py
- tools/verify_subtitles.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 77 COMMIT Unreleased c4b40c4 2026-09-14T09:51:43-07:00

#### Coming From:

Unreleased 304e4dc

#### Purpose:

Record the user's revised next-release requirements.

#### Outcome:

The user replaces the preceding playlist and automatic matching-name subtitle proposal with session-only resume from last position, predictable EOF behavior and subtitles from a separate SRT selected through a menu entry. The earlier clarification that resume lasts only while the core stays loaded remains in force. Keep stock Main; playlists, N/P playlist navigation and automatic SRT discovery are not part of this target. Audio-track selection remains excluded. The UI plan records this scope and remaining design questions for resume identity, EOF draining and bounded subtitle parsing, storage and character coverage. No RTL changes, additional builds or hardware deployment occurred; ffafc79 seed 87 remains timing-qualified but not yet explicitly hardware accepted.

#### Next Steps:

Plan and implement the revised target using existing seek, duration and shared-overlay infrastructure, validating file transitions, EOF, pause and seek subtitle synchronization before release qualification.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 76 COMMIT Unreleased 304e4dc 2026-09-14T09:45:46-07:00

#### Coming From:

Unreleased 0d13908

#### Purpose:

Record completed lowered-overlay build qualification and provide the preferred hardware candidate.

#### Outcome:

All ffafc79 seeds compile and pass four-corner timing, 159 CDC registers and scene-enable audits. Seeds 52, 61 and 87 have minimum setup +0.196, +0.224 and +0.371 ns and hold +0.097, +0.103 and +0.110 ns. Preferred seed 87 uses 37713 actual ALMs, 520 M10Ks, 69 DSPs and 47317 registers, leaving 4197 ALMs and 33 M10Ks. This is two fewer placed ALMs than 3d48cc5 seed 87, effectively unchanged resource usage. Its verified RBF is results/hardware-test-ffafc79/seed87/MediaPlayer_20260914.rbf with SHA-256 3d229f28cb7e12b0cde1f2da716754f6c307a80f94678e5668303f9896c93f0d. Per-seed testing notes and top-level instructions are ready; no deployment or hardware acceptance occurred. Subsequent user release requirements are M3U playlists with N/P navigation, automatic advance and final return to idle; session-only resume while the core stays loaded; predictable EOF; and matching-name separate SRT subtitles. Automatic filesystem access through stock Main remains unresolved. Image/package loading and manual subtitle selection were discussed as RBF-only alternatives, not approved replacements for the requested loose-file workflow. No feature implementation or shared-IDCT optimization was started.

#### Next Steps:

Have the user validate the lower bar and clock-only fields on seed 87; resolve the file-access workflow before implementing playlist and automatic subtitle loading.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 75 COMMIT Unreleased 0d13908 2026-09-14T09:25:00-07:00

#### Coming From:

Unreleased ffafc79

#### Purpose:

Remove audio-track selection from planned player scope at the user's request.

#### Outcome:

The user explicitly declines audio-track selection after its purpose is explained. The UI plan now excludes a soundtrack selector and resource reservations for track switching, retaining the other six original features. Subtitle playback remains deferred. This documentation-only change does not alter RTL, running builds or hardware. The preceding read-only shared-IDCT investigation remains under results/shared-idct-audit/findings.md; no sharing implementation is authorized by this scope decision.

#### Next Steps:

Complete the existing lowered-overlay build qualification and retain the revised feature scope for future planning.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 74 COMMIT Unreleased ffafc79 2026-09-14T09:09:57-07:00

#### Coming From:

Unreleased 1d58018

#### Purpose:

Lower the playback progress strip by one bar height and show only clock values in its three fields.

#### Outcome:

Implemented the requested 14-reference-pixel downward shift for track, fill and three centered clocks, removing their static prefixes. Elapsed, total and remaining retain their left-to-right order; unknown fields retain dashes. Separate pause/seek status and retained auxiliary provider behavior are unchanged. Updated the preview, pixel oracle, plan, test instructions and changelog. All nine full-frame cases pass at 480p, 720p and 1080p, totaling 5414400 matching pixels, plus retained-provider lifetime, UI state and 518 enabled-divider cases. Source ffafc79 is pushed and clean seeds 52, 61 and 87 are compiling; supervisor output is /tmp/ui-lower-clocks-build.log. No hardware deployment occurred. The user's statement that everything looks good follows the encoding correction; it is not treated as explicit acceptance of a particular duration RBF.

#### Next Steps:

Audit the completed three-seed timing and resource results, package the best qualified RBF and have the user check clock centering, bottom margin, unknown times and playback controls on hardware.

#### Files Modified:

- rtl/media_ui_scene.sv
- tools/verify_player_overlay.py
- docs/ui/overlay-preview.html
- docs/UI_OVERLAY_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 73 COMMIT Unreleased 1d58018 2026-09-14T08:49:53-07:00

#### Coming From:

Unreleased 9076405

#### Purpose:

Document revised duration build qualification and reproduce the reported conversion cadence failure.

#### Outcome:

All 3d48cc5 builds completed. Seeds 61 and 87 pass all four timing corners, 159 CDC registers and scene-enable audits; seed 52 fails setup at -0.381 ns. Preferred seed 87 has setup +0.427 ns, hold +0.107 ns, 37715 actual ALMs, 520 M10Ks and 69 DSPs, leaving 4195 ALMs and 33 M10Ks. Its packaged RBF is results/hardware-test-3d48cc5/seed87/MediaPlayer_20260914.rbf with verified SHA-256 d6f66b6870113e53e46f8d229b11c90b0d0f8870e5c6cb621cc99cf1991a80e7. Hardware acceptance remains pending. Separately, full-start 68-second fellow conversion reproduces 477 dropped and 475 duplicated frames inside the fps filter; millisecond timestamps near a half-frame phase explain the failure. Removing that filter and using output -r:v 24000/1001 -fps_mode:v cfr eliminates reported synchronization drops/duplicates. Groove's corrected moving sample advances through every source frame; fellow's dark opening makes low-resolution image matching ambiguous, so no exact pixel-oracle claim is made for it. Thread count variants do not explain the failure; one encoder thread accounts for approximately 3.6 percent of 28 logical CPUs. The committed bounded reproduction tool was run successfully on fellow and reproduced both outcomes. Full movie originals remain unchanged; no hardware deployment or additional builds occurred.

#### Next Steps:

Have the user test the corrected short encoding and timing-qualified seed 87, including Groove duration and existing playback controls; retain tested b00920a seed 52 as rollback. Select encoding frame rate to match each source and keep unknown duration when bounded evidence is unavailable.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/ENCODING_CADENCE.md
- tools/reproduce_encode_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 72 COMMIT Unreleased 9076405 2026-09-14T08:31:24-07:00

#### Coming From:

Unreleased 3d48cc5

#### Purpose:

Provide the best completed duration candidate for the user's requested early hardware test.

#### Outcome:

After being informed that all 9076405 seeds fail setup, the user requests the best completed RBF to test. Seed 87 has the least negative setup at -0.184 ns and hold +0.115 ns. Its verified binary is results/hardware-test-9076405/seed87/MediaPlayer_20260914.rbf with SHA-256 d2bb095a9bd33018f0519aeb0f1c80c989de929a70536ad8fa7d75f8678d509c. Per-seed TESTING.md identifies this as timing-unqualified exploratory testing and asks the user to check Groove's approximately 01:18:25 total and remaining time, pause/seeks and file changes. The revised 3d48cc5 seeds continue compiling under results/build-3d48cc5-20260914-082959. No automatic deployment or hardware acceptance occurred.

#### Next Steps:

Review the user's early hardware results and finish corrected 3d48cc5 build qualification before recommending a timing-qualified replacement; retain tested b00920a seed 52 as rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 71 COMMIT Unreleased 3d48cc5 2026-09-14T08:14:32-07:00

#### Coming From:

Unreleased 9076405

#### Purpose:

Qualify the duration correction and remove the decimal formatter timing bottleneck.

#### Outcome:

Clean 9076405 seeds 52, 61 and 87 have passed synthesis and are fitting. Additional media checks expose an oracle limitation: ffprobe leaves the final reference picture of test_progressive_mpg.mpg untimestamped despite decoding it. Extend the test-only comparison to count decoded display frames after the last available timestamp, independently of the RTL temporal-reference arithmetic. The updated comparison confirms 30.03 seconds for both test_progressive_mpg.mpg and test_av_sync.mpg; fellow_fixed.mpg also passes its bounded-tail comparison. No RTL change or new build is needed for this test-tool correction. All three completed builds pass CDC and scene-enable audits but fail setup by -0.335, -0.295 and -0.184 ns; actual ALMs are 37721, 37686 and 37677 with unchanged 520 M10Ks and 69 DSPs. Seed 52 fails an existing scaler path; seeds 61 and 87 fail retimed combinational decimal divisions inside the UI formatter. The corrected formatter reuses the existing enabled sequential divider for decimal digit conversion, eliminating the combinational /10 and %10 networks. All 5,414,400 pixel comparisons, provider lifetime/state checks and 518 divider cases pass; the duration RTL remains unchanged from its eight successful real-file comparisons. Clean three-seed qualification follows. In response to the user font question, a standalone character sheet is generated directly from the unchanged font ROM; it contains 54 visible glyphs.

#### Next Steps:

Complete corrected build qualification, then record the preferred RBF hash, resources and hardware instructions without changing the MiSTer automatically.

#### Files Modified:

- MediaPlayer.sdc
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- docs/ui/font-sheet.html
- rtl/media_ui_scene.sv
- tools/make_font_sheet.py
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 70 COMMIT Unreleased 9076405 2026-09-14T08:02:17-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Recover bounded duration for sparse-timestamp progressive program streams.

#### Outcome:

The user clarified that loading must remain fast and unknown duration is acceptable when bounded evidence is insufficient. The corrected observer uses progressive picture temporal references to reconstruct timestamps within anchored groups, unwrap reference-picture indices across modulo-1024 transitions and position B-pictures before their future reference. Late B-picture timestamps can backfill an earlier-coded reference endpoint, and anchored group endpoints carry into following unannotated groups. One serial multiplier computes offsets without DSPs. Conflicting anchors beyond one 90 kHz tick, unsupported/mixed rates, malformed endpoints and genuinely unanchored windows remain unknown. Existing byte budgets, reader ownership and watchdog are unchanged. All 32 synthetic cases, shared-reader remount/error/timeout and above-4-GiB tests, and Verilator lint pass. Exact bounded head/tail comparisons against independently decoded frames pass Groove, Star Wars LOWER, Pee Strike and fellow; Groove differs by three quarter-ticks, the other endpoints match exactly. Evidence is under results/ui-duration-sparse. No hardware deployment occurred.

#### Next Steps:

Build clean seeds 52, 61 and 87, audit all four corners and 159 CDC registers plus scene enable, compare incremental resources with tested b00920a seed 52 and package the best qualified candidate.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_timeline.sv
- rtl/media_duration_window.sv
- tools/test_media_duration_window.sv
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 69 COMMIT Unreleased b00920a 2026-09-14T07:58:54-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Record successful playback-control tests and explain Groove's unknown duration.

#### Outcome:

The user confirms pause/resume, forward/backward seeking and ten-second overlay hiding including while paused all work properly. Groove.mpg on the GIT HDD shows dashes for Total and Remaining. Exact 64 KiB head and 4 MiB tail replay through the current duration-window RTL reproduces the fallback: head origin 48754, healthy matching stream 224, no parser or syntax error, complete final packet boundary, but unqualified_tail remains set because a picture after the maximum observed presentation timestamp has no independently associated PTS. A later timestamped reordered picture does not exceed that maximum and cannot clear this conservative guard. This is expected behavior of the current probe, not evidence that the file cannot play; ffprobe obtains a duration using its broader stream analysis. Evidence is retained under results/ui-overlay/groove-duration. No RTL, RBF or media changes were made; overall acceptance remains pending while testing continues.

#### Next Steps:

Continue user hardware testing and retain the conservative unknown-duration behavior unless a separate improvement to timestamp association and endpoint qualification is requested.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 68 COMMIT Unreleased b00920a 2026-09-14T07:53:13-07:00

#### Coming From:

Unreleased aa8d067

#### Purpose:

Record the first successful hardware playback and time-field test of the shared overlay.

#### Outcome:

The user is testing the supplied overlay core and reports that Star Wars - EPISODE IV - A New Hope - Despecialized - LOWER.mpg from the GIT HDD works perfectly and the time fields update properly. This records a successful file-specific hardware test of the supplied b00920a seed 52 candidate. The user has not yet reported completion of the remaining pause/seek, unknown-duration, file-switch and HDMI-mode checks; overall candidate acceptance remains pending. No source or binary changes were made.

#### Next Steps:

Continue the current hardware test, especially pause/resume and seeking with time-field updates, automatic hiding, OSD/filter coexistence and switching files without retaining the previous duration.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 67 COMMIT Unreleased aa8d067 2026-09-14T07:41:06-07:00

#### Coming From:

Unreleased 9f16364

#### Purpose:

Document and package the timing-qualified shared-overlay hardware candidate.

#### Outcome:

Clean b00920a seeds 52, 61 and 87 all pass four-corner setup, hold, recovery, removal and pulse-width timing, 159 preserved CDC registers and the corrected scene-enable audit from 9f16364. Minimum setup is +0.135, +0.100 and +0.028 ns; minimum hold is +0.096, +0.069 and +0.111 ns. Actual placed ALMs are 37450, 37424 and 37503, with 520 M10Ks, 69 DSPs and three PLLs. All meet the initial incremental budget. Preferred seed 52 is packaged at results/hardware-test-b00920a/seed52/MediaPlayer_20260914.rbf with SHA-256 bf7e9aff272e5f819e16358dba90d2d05e18b9ca78436df6e3cd204e1d520973, per-seed build metadata, README and TESTING instructions. It leaves 4460 actual ALMs and 33 M10Ks free. Documentation distinguishes estimated logic from actual placement and audit-tool revision from unchanged binary source. Hardware-accepted 3ff27c8 seed 52 remains rollback. No deployment or hardware acceptance occurred.

#### Next Steps:

Have the user test duration, progress, pause/seek feedback and OSD/filter coexistence at the supported HDMI modes.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md

#### Status:

- [x] Built
- [ ] Passed

---

## 66 COMMIT Unreleased 9f16364 2026-09-14T07:38:35-07:00

#### Coming From:

Unreleased b00920a

#### Purpose:

Qualify the completed overlay builds with an audit that recognizes fitted counter duplicates.

#### Outcome:

All three b00920a seeds compile successfully, using 37450, 37424 and 37503 actual placed ALMs for seeds 52, 61 and 87, with 520 M10Ks and 69 DSPs. These meet the initial incremental resource budgets. The new scene-enable audit stops before all-corner reporting because its two-register wildcard also returns routing duplicates. A direct fitted-netlist query confirms the two original scene_phase bits and one duplicate of each, plus 1144 scoped formatter registers. Audit revision 9f16364 requires both original bits, accepts only explicitly named routing copies and reports those separately. RTL, timing constraints and fitted binaries are unchanged. Qualification is rerunning on the existing archives; status.json records the original audit failure and the new audit-tool revision separately from the RBF source. Hardware acceptance remains pending.

#### Next Steps:

Complete all-corner and CDC qualification, package the best passing seed and update hardware instructions with measured resources, timing and its exact RBF hash.

#### Files Modified:

- tools/phase1p_timing.tcl

#### Status:

- [x] Built
- [ ] Passed

---

## 65 COMMIT Unreleased b00920a 2026-09-14T07:02:57-07:00

#### Coming From:

Unreleased 287cf6b

#### Purpose:

Remove the remaining identified pixel-path arithmetic bottlenecks before final overlay qualification.

#### Outcome:

Additional isolated timing analysis of fitted 5373dae finds the unchanged alpha blend also fails by -6.017 ns, independent of coordinate divisions and scene formatting. The 287cf6b batch passes synthesis but is stopped early during fitting to avoid completing another known-incomplete timing fix. Its status and cancellation reason are retained under results/build-287cf6b-20260914-065802. Replace the fixed dark-palette blend with synchronous byte lookup tables and pipeline the bounds, object selection and coordinate subtraction separately. These corrections preserve the approved pixels and shared provider design while using the reserved RAM budget; existing 287cf6b duration guards, coordinate/staging RAM and enabled formatter remain the basis. The completed correction uses ten aligned pixel registers, separately registered axis comparisons and qualification, precomputed object enables and ROM palette blending. Exact-width binary font and coordinate ROMs avoid padded storage. The isolated 148.5 MHz compositor fit passes all reported corners and shows +0.861 ns setup and +0.381 ns hold on the detailed default-model internal-register reports, with 12 M10Ks and no DSPs; this is not full-core qualification. All 5,414,400 full-frame pixel comparisons, varying-color alpha checks, lifetime/state tests and 518 enabled divider cases pass. ROM regeneration is exact. No hardware deployment or acceptance occurred.

#### Next Steps:

Run clean full-core seeds 52, 61 and 87 from b00920a. Require all-corner timing, 159 CDC registers and the real four-clock scene-enable audit, then measure actual resource usage before packaging a candidate.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_overlay_blend_b.hex
- rtl/media_overlay_blend_rg.hex
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_coordinates.hex
- rtl/media_overlay_coordinates.mem
- rtl/media_overlay_font.hex
- rtl/media_overlay_font.mem
- tools/make_overlay_roms.py
- tools/test_media_player_overlay.sv
- tools/verify_overlay_timing.py
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 64 COMMIT Unreleased 287cf6b 2026-09-14T06:34:44-07:00

#### Coming From:

Unreleased 5373dae

#### Purpose:

Tighten duration qualification and correct any measured implementation issues before delivering the shared overlay.

#### Outcome:

Initial 5373dae seeds all compile and pass the 159-register CDC audit but fail all-corner HDMI setup at minimum -14.139, -13.905 and -13.197 ns for 52, 61 and 87. Actual placed ALMs are 38206, 38125 and 38228, exceeding the initial 2000-ALM incremental budget by 432, 351 and 454; RAM totals 510 M10Ks and DSPs 81. Evidence and explicitly failed handoffs are under results/build-5373dae-20260914-062804 and results/hardware-test-5373dae. Critical paths are cascaded pixel-coordinate divisions and formatter arithmetic. Corrected source 287cf6b uses a synchronous coordinate ROM, RAM staging descriptors copied during vertical blanking, six-stage aligned RGB/sync processing, one serialized layout/progress multiplier and a split restoring divider. Scene construction advances on a real modulo-four HDMI clock enable; narrowly scoped multicycle constraints cover only registers sharing that enable, while snapshot inputs, provider writes, publication and pixel logic remain single-cycle. A pending latch retains short compositor acknowledgements. Duration guards reject malformed head evidence and differing selected video-stream IDs between windows; an adversarial test first demonstrates the missing guard then passes with the correction. Full 4.7-million-pixel overlay oracles, independent visibility and retained-provider lifetime tests, 518 wide divider cases, ROM regeneration checks, bounded reader/remount/timeout recovery, real-file duration comparison and existing program-stream ingress tests pass. TimeQuest accepts the scoped constraint syntax; new fitted enable-counter and register-set audits are required. Clean corrected seeds 52, 61 and 87 are now compiling. No candidate was deployed or hardware accepted.

#### Next Steps:

Audit corrected builds across all corners, the 159 CDC registers and real four-clock enable endpoints, then measure actual placed ALMs and M10Ks against the initial budgets. Resolve any remaining failures before recommending an RBF. Package the best qualified seed with hardware test instructions, retaining accepted 3ff27c8 seed 52 as rollback.

#### Files Modified:

- MediaPlayer.sdc
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_probe.sv
- rtl/media_duration_window.sv
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_coordinates.hex
- rtl/media_player_overlay.sv
- rtl/media_ui_divider.sv
- rtl/media_ui_scene.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- tools/audit_three_seeds.py
- tools/make_overlay_roms.py
- tools/phase1p_timing.tcl
- tools/test_media_duration_reader.sv
- tools/test_media_player_overlay.sv
- tools/test_media_ui_divider.sv
- tools/test_media_ui_lifetime.sv
- tools/verify_player_overlay.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 63 COMMIT Unreleased 5373dae 2026-09-14T06:07:40-07:00

#### Coming From:

Unreleased ea05269

#### Purpose:

Implement the approved shared playback overlay and bounded timestamp duration probe for hardware validation.

#### Outcome:

Source 5373dae implements the shared post-filter, pre-menu HDMI compositor with eight bounded text objects, four rectangles, synchronous glyph/text RAM, five-stage aligned RGB and sync delay, frame-boundary publication and stale session/seek epoch rejection. A retained synthetic-provider interface reserves future text functionality without subtitle loading or cue selection. The controls reproduce the historical progress bar and Elapsed, Total and Remaining fields, pause/seek feedback, independent ten-second wall-clock hiding and explicit unknown duration. A bounded 64 KiB head and 4 MiB tail preflight reuses the existing mounted reader RAM, validates PES timestamps, retains the maximum presentation PTS plus the frame period, and quarantines outstanding responses on cancellation or timeout. Reader integration testing caught and fixed a FINISH-state validity gate; the complete encoded sample now matches the independently calculated endpoint. Full-frame pixel oracles pass at 480p, 720p and 1080p, including unknown/hidden controls and progress endpoints. Scene lifetime, retained-provider, epoch, wall-clock, reordered/wrapped timestamp, large-file reader, remount, malformed response and timeout recovery tests pass. Existing transport/session, decoder pixel and real-file direct-seek regressions pass. Evidence is under results/ui-overlay. Resource and timing qualification remain pending; standard clean seeds 52, 61 and 87 are now compiling. No deployment occurred.

#### Next Steps:

Audit all four timing corners, 159 expected CDC synchronizer registers and actual placed ALMs versus the accepted 35774-ALM baseline; compare M10Ks with 508 baseline and the planned 2000-ALM/12-M10K incremental budgets. Correct any new synthesis or timing failures, package the best qualified RBF and have the user validate startup preflight, fields, pause/seek, menu/filter priority, file changes and EOF. Keep accepted 3ff27c8 seed 52 as rollback.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- docs/UI_OVERLAY_PLAN.md
- files.qip
- rtl/media_duration_probe.sv
- rtl/media_duration_window.sv
- rtl/media_overlay_compositor.sv
- rtl/media_overlay_font.hex
- rtl/media_player_overlay.sv
- rtl/media_ui_divider.sv
- rtl/media_ui_scene.sv
- rtl/media_ui_state.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/phase1p_timing.tcl
- tools/test_media_duration_reader.sv
- tools/test_media_duration_window.sv
- tools/test_media_player_overlay.sv
- tools/test_media_ui_lifetime.sv
- tools/test_media_ui_state.sv
- tools/verify_player_overlay.py
- tools/verify_ui_duration.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 62 COMMIT Unreleased ea05269 2026-09-14T05:41:58-07:00

#### Coming From:

Unreleased 3ff27c8

#### Purpose:

Design one playback overlay for progress and timing fields with a shared rendering framework for future subtitles.

#### Outcome:

The user requested bundling wishlist items 1, 2 and 7 into one UI layer while explicitly excluding subtitle implementation from the first build. Historical af7f570 audio_ui.c and media_player_helper.c supply the reference: Elapsed left, Total center, Remaining right in HH:MM:SS at y422 above the x32/y438/656-by-14 bar, muted blue-gray track and pale fill/text from the final video-overlay palette. The old font lacks lowercase despite mixed-case labels, so the preview adds readable lowercase in the same pixel style. Design commit ea05269 adds docs/UI_OVERLAY_PLAN.md and an interactive local HTML preview covering aspect, output size, pause/seek, unknown duration and a future subtitle-region guide. Its JavaScript executes across three output sizes and three picture aspects with a mocked DOM/canvas; this is not browser pixel validation. The proposed compositor sits after HDMI scaling/filters/shadow mask and before the existing MiSTer menu, with small text/glyph storage, frame-atomic scene publication, independent controls/subtitle visibility and no decoder-bank ownership or playback backpressure. The user selected a bounded timestamp probe with unknown total/remaining when unavailable; byte-ratio duration estimation is excluded. The plan covers head/tail probes, reordered PTS, endpoint qualification, large-file offsets, response retirement and session invalidation. Initial implementation budgets are 2000 additional actual ALMs and 12 M10Ks, not measured costs. No RTL, duration probe, subtitle parser, HDMI mode change or RBF was implemented; hardware-accepted runtime baseline remains 3ff27c8 seed 52. This commit completes design artifacts only.

#### Next Steps:

Use the documented design as the implementation boundary for the shared overlay, progress/time fields and duration probe, retaining existing controls and standard HDMI timing/frequency requirements. Before compilation require renderer, asynchronous scene-publication, duration-probe/late-response and existing decoder/seek regressions, then the standard three-seed timing/resource audit. Subtitle loading, decoding and cue selection remain deferred. No builds are running.

#### Files Modified:

- docs/UI_OVERLAY_PLAN.md
- docs/ui/overlay-preview.html

#### Status:

- [ ] Built
- [ ] Passed

---

## 61 COMMIT Unreleased 3ff27c8 2026-09-14T05:13:13-07:00

#### Coming From:

Unreleased 3ff27c8

#### Purpose:

Record hardware acceptance of the IDCT intermediate RAM conversion as the new baseline.

#### Outcome:

The user reports everything works perfectly with the recommended 3ff27c8 seed 52 candidate. Passed records that user-reported hardware acceptance; detailed file and control coverage was not enumerated. The accepted RBF remains results/hardware-test-3ff27c8/seed52/MediaPlayer_20260914.rbf with verified SHA-256 236c9817ccfd04b10e23ff0ee052f2c11e5a39d7fcfdb88e3e42b29e969406f1. Its handoff metadata and README now record acceptance, and documentation commit e76bc84 updates the changelog and test instructions. This establishes the 35774 actual placed ALM, 508 M10K, 69 DSP seed 52 build as the current accepted baseline, with 45 M10Ks free. Runtime RTL is unchanged and no builds or deployment were performed. The requirement for standard HDMI timings and frequencies remains in force for future film-cadence work.

#### Next Steps:

Use 3ff27c8 seed 52 as the baseline for subsequent changes and retain dc1dfc2 seed 52 as the previous rollback. Investigate stock Main and scaler support for standard 23.976/24 Hz HDMI timing modes before proposing any film-cadence implementation; do not infer authorization for another implementation or build from this acceptance report.

#### Files Modified:

- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [x] Passed

---
