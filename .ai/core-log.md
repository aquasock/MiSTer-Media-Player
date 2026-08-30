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

## 721 COMMIT Unreleased 8fd16e8 2026-08-29T19:19:47-07:00

#### Coming From:

Unreleased 8fd16e8

#### Purpose:

Prepare and install a sequence-end-corrected copy of the matched interlaced I/P/B comparison fixture.

#### Outcome:

The user explicitly authorizes correcting the entry-720 generated fixture after its hardware capture shows no large block corruption but stalls two pictures short because FFmpeg omitted the terminal H.262 sequence-end code.  Preserve the existing matched and I/P-only fixtures unchanged; copy the exact matched I/P/B stream, append only `00 00 01 b7`, and install the result under a new absolute filename.  This test-media-only correction does not authorize source, RBF, Main, helper or configuration changes.

#### Next Steps:

Verify that the corrected local stream differs only by the four appended bytes, ends in the required sequence-end code, retains exactly 361 720x480 TFF interlaced pictures comprising 25 I, 96 P and 240 B, and decodes completely in software.  Upload it as `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_ipb_matched_end.m2v` using an absolute FTP path, verify an independent absolute-path readback byte for byte, then have the user play that file once in `800x600 Diagnostic` with Weave and report whether it visibly reaches a stable end.  Do not capture telemetry unless the user explicitly requests it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

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
