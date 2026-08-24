## 391 COMMIT Unreleased 9a7a982 2026-08-23T21:47:50-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Hardware-qualify complete irregular timestamp presentation on the corrected ordinary I/P control.

#### Outcome:

After a reboot, `15A_pts_irregular_ordinary_short.m2v` passes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven snapshot accepts the exact 184,677 decoder bytes after stripping five metadata records, associates all five timestamps, decodes and displays all five reference pictures with four swaps, and ends for quiet reason one with sequence end, session quiet and presentation complete true. Decoder and presentation error flags are zero, frame waiting and both holds are false, the pending scheduler slot is empty and no reorder, queued or promotion state remains. Displayed PTS low bits are the final record's expected `0x4fc`. The irregular schedule is proven by a 0.198950-second final interval and two 0.049738-second intervals rather than uniform 25-fps fallback cadence. This closes the ordinary timestamp gate on source `9a7a982` and the exact Entry-389 RBF without a source change.

#### Next Steps:

Reboot the MiSTer and run `16A_pts_reordered_b_short.m2v`, then report all three LEDs and leave the final image loaded for capture. Require all five coded-order timestamps to associate with their physical reference or scratch banks, three reference plus two B pictures to display in I, B, P, B, P order with four swaps and irregular timing, and sequence-end quiet with complete scheduler retirement and zero errors before proceeding to unannotated fallback controls.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 390 COMMIT Unreleased 9a7a982 2026-08-23T21:44:51-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Interpret the first irregular-PTS hardware run and replace timestamp controls whose final deadlines exceeded the cadence profiler's forced terminal-snapshot window.

#### Outcome:

After a reboot into the exact Entry-389 RBF, the user runs `15_pts_irregular_ordinary.m2v`, reports visible skips and USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven capture proves that all five in-band records associate and all five reference pictures decode with zero decoder or presentation errors; accepted decoder bytes are the original 184,677-byte elementary stream because the 45 metadata bytes are correctly stripped before that counter. Timestamp presentation is visibly active: the captured gaps include 0.248688 seconds followed by 0.049738 seconds, matching the intended uneven schedule rather than the 25-fps fallback. This first control does not qualify terminal presentation because its final PTS is one second after the anchor, beyond the profiler's approximately 0.825-second forced terminal deadline; the frozen snapshot therefore contains four displays, three swaps, displayed PTS low bits `0x4fc`, session quiet false and the fifth timestamped reference retained in the released pending slot without any error flag. Two replacement controls retain irregular and coded-order-reordered timestamps but move the final deadlines inside that diagnostic window. Exact FTP retrieval verifies 184,722-byte `15A_pts_irregular_ordinary_short.m2v` at SHA-256 `d2b5d8305dc628d200f5be2bd947f7054498a0cd9dd41a3e8ad51589df116ab8` and 185,194-byte `16A_pts_reordered_b_short.m2v` at SHA-256 `3a9c50be14cbaeb3aa39491fb0330c5c7a3ac3c2a1964e0f760b751a7fe9dd04`. No source or RBF change is made.

#### Next Steps:

Reboot the MiSTer and run `15A_pts_irregular_ordinary_short.m2v`; require five associated records, five decoded and displayed reference pictures, four swaps, sequence-end quiet, presentation complete, zero errors and visibly uneven timing, then leave the final image loaded for capture. If it passes, reboot and run `16A_pts_reordered_b_short.m2v`, requiring display-order I, B, P, B, P timing with three reference plus two B completions, five displays, four swaps, clean B-generation retirement and zero errors before the unannotated controls.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 389 COMMIT Unreleased 9a7a982 2026-08-23T21:08:18-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Present timestamped pictures against the proven audio-derived 90 kHz system-time tick while preserving the accepted free-running cadence for pictures without timestamps.

#### Outcome:

Commit `9a7a982` synchronizes only the proven single-bit audio-derived 90 kHz tick into the decoder domain and advances a local 33-bit timeline anchored exactly once by the first in-band timestamp after each download reset. Modulo half-range comparison holds future candidates, admits equality and late candidates at the first safe swap, and leaves individually missing timestamps on the unchanged exact 23.976, 24, 25, 29.97 or 30 fps cadence; an early timestamped presentation clears partial cadence credit so fallback cannot burst on the next refresh. Timestamp ownership now retains separate values and validity for all reference and B-scratch banks, commits B timestamps on actual persistence and queries the scheduler's retained candidate identity. Focused simulation passes first-record anchor, reset re-anchor, modulo wrap, late, future, missing, reference and reordered scratch ownership, timestamp gating, no-burst fallback and every established cadence count. Full-pipeline P-only, B-reordered, repeated multi-slice, dense-residual, mixed-macroblock and long-GOP replays complete with exact publication and persistence counts and zero errors; mixed and long dense-publication tests retain zero overwrites. The explicit coded-picture-order timestamp-list injector mode passes normal and oversize-rejection controls. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 34 seconds with zero errors and 154 warnings, using 35,666 ALMs, 52,202 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. Every timing category is positive with zero endpoint TNS: global setup is plus 0.200 ns, decoder setup plus 0.773 ns, host setup plus 1.158 ns, video setup plus 7.769 ns, hold plus 0.253 ns, recovery plus 2.709 ns, removal plus 0.633 ns and pulse width plus 1.122 ns. The 4,196,032-byte RBF has SHA-256 `68be8a9d899a06b6861a9d9ceaf07e41747d1865133940aad39849f4b14c9211`; it is installed persistently and retrieved byte-for-byte identical. Irregular ordinary test `15_pts_irregular_ordinary.m2v`, SHA-256 `0003a68e9377ce30ce77bfd8f4bd9e70edf2937b227021f4219efcd12027891b`, and reordered-B test `16_pts_reordered_b.m2v`, SHA-256 `bde3a06fb5012667a548fec6de1730e96a1c15c3c548cda85e0982af0bd7a309`, are also installed and retrieved exactly.

#### Next Steps:

Reboot the MiSTer so the new persistent RBF loads, then run `15_pts_irregular_ordinary.m2v` and verify that all five pictures appear in order with intentionally uneven pauses and clean terminal completion; record all three LEDs and leave the final image loaded for telemetry. After that capture, reboot and run `16_pts_reordered_b.m2v`, requiring the display-order I, B, P, B, P sequence to retain its deliberately uneven timing without a dropped or prematurely exposed future reference. Finish with reboot-isolated unannotated `06_p_f_code_range.m2v` and `04_b_bidirectional.m2v` controls to prove unchanged cadence fallback before marking this source passed. PCM output remains the next feature boundary.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/inject_inband_metadata.py
- tools/streams/tb_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_picture_timestamp.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 388 COMMIT Unreleased 2b1a170 2026-08-23T21:06:21-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Qualify deliberate mid-picture truncation and immediate no-reboot baseline recovery, completing the full hardware regression pack for the queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the exact 100,000-byte `99_EXPECTED_FAILURE_truncated_stream.m2v` stops visibly on frame seven with USER, DISK and POWER all steady off rather than claiming normal completion. Its launch-free schema-seven snapshot accepts all 100,000 bytes, decodes four reference plus five B pictures, displays eight pictures with seven swaps and freezes for reason three, `fatal_or_no_progress`, with sequence end false, session quiet false, presentation complete false, an unfinished future reference and decode still in flight. Decoder and presentation error flags remain zero, correctly distinguishing deliberate source truncation from a syntax fault. Without rebooting, the user immediately loads the exact odd-length `01_i_baseline.m2v`; it passes with USER steady on, DISK two blinks and POWER steady on. The recovery snapshot accepts 726,704 transport bytes including the expected pad, decodes and displays all four references with three swaps, freezes for quiet reason one and reports sequence end, session quiet, presentation complete, zero errors, no frame waiting and no reorder, queued, promotion, pending-frame or terminal-boundary state. The three long all-I gaps are decode-throughput observations only and no picture is lost. This proves that the truncated transfer leaves no stale state across a normal selector reload and completes the regression pack: tests one through fourteen, the expected failure and its no-reboot recovery all meet their specified hardware, visual and telemetry gates on source `2b1a170` and RBF SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`.

#### Next Steps:

Treat source `2b1a170` and its installed RBF as the accepted complete-regression boundary for ordinary and B-picture presentation. Prepare the next source-change proposal for timestamp-driven presentation against the proven system-time clock while retaining free-running cadence for unannotated streams, with focused association, wrap, missing-timestamp, seek-reset, B-reorder and full-pipeline controls; obtain user approval before changing source, and keep the PCM sink as the following feature boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 387 COMMIT Unreleased 2b1a170 2026-08-23T21:00:19-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the complete 14,315-picture native-24 endurance stream and prepare the final expected-failure recovery gate.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 78,010,162-byte `14_bbb_full_native24_user_recipe.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that the full playback looked good. The steady USER state again classifies the DISK indication as normal final GOP progress. The launch-free schema-seven capture freezes for quiet reason one with exactly 78,010,162 accepted bytes and the expected eight-bit wraps from 4,773 reference pictures, 9,542 B pictures, 14,315 displays and 14,314 swaps to 165, 70, 235 and 234. Frame-rate code two, 596 system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers are present. Correcting the 32-bit cadence-cycle counter by its eight expected wraps yields 596.428 measured seconds and 23.999549 displayed swaps per second. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact 100,000-byte `99_EXPECTED_FAILURE_truncated_stream.m2v`, SHA-256 `0375c1d73625fdeb80f995c194ba8220f25894aa093012a67f325d390aae536a`, was reproduced as the documented prefix of test eleven, installed in the MiSTer file directory and retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer and load `99_EXPECTED_FAILURE_truncated_stream.m2v` through the normal file selector. Wait until it stops making progress, record the terminal image and all three LEDs, leave it loaded and request telemetry capture; it must not report ordinary sequence-end quiet completion because the file ends inside a picture without a sequence-end marker. After that capture, do not reboot and immediately load `01_i_baseline.m2v`; recovery passes only if baseline completes normally with USER steady on, and all three recovery LEDs plus launch-free telemetry must be recorded before closing the regression pack.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 386 COMMIT Unreleased 2b1a170 2026-08-23T20:39:08-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify fifteen seconds of visually observed native-24 real-video stress across wrapped presentation counters and prepare the exact full endurance stream.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 2,603,570-byte `13_bbb_squirrel_15sec_native24_q6.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that playback looked good. The steady USER state again classifies the DISK indication as normal final GOP progress. The launch-free schema-seven capture freezes for quiet reason one with exactly 2,603,570 accepted bytes, 121 reference plus 239 B pictures, and the expected eight-bit wraps from 360 displays and 359 swaps to 104 and 103. Frame-rate code two, fifteen system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers are present; correcting the wrapped swap count gives 23.988 displayed swaps per second across the measured interval. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The pre-existing 84,423,309-byte full file on the MiSTer did not match test fourteen and its temporary numbered alias was removed. Regenerating from the local 480p source with the documented deterministic recipe plus the required terminal sequence-end marker produced the authoritative 78,010,162-byte `14_bbb_full_native24_user_recipe.m2v`, SHA-256 `3b048a180dbe2bc98a6160e7103b0f5acfd41d6875c34154730ef1da75d64f1a`; it was installed under the numbered name and retrieved byte-for-byte identical. Its 14,315 pictures comprise 597 I, 4,176 P and 9,542 B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `14_bbb_full_native24_user_recipe.m2v` through the normal file selector for the complete nine-minute-fifty-six-second endurance run. Watch smooth pans, the squirrel sequence, rolling credits and clean terminal behavior, then report all three LEDs and leave the completed image loaded for telemetry capture. Require 4,773 reference plus 9,542 B pictures, 14,315 displays and 14,314 swaps represented by eight-bit wraps to 165 references, 70 B pictures, 235 displays and 234 swaps, exactly 78,010,162 accepted bytes, sequence-end quiet, complete presentation retirement and zero errors before the expected-failure and no-reboot recovery test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 385 COMMIT Unreleased 2b1a170 2026-08-23T20:36:08-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify five seconds of visually observed dense real-video motion with complete native-24 presentation telemetry on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 1,404,944-byte `12_bbb_squirrel_5sec_native24_q6.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that playback looked good. The steady USER state classifies the DISK indication as the normal final GOP-progress code, which the launch-free schema-seven capture confirms: exactly 1,404,944 transport bytes are accepted, forty-one reference plus seventy-nine B pictures decode, and all 120 pictures display with 119 swaps. The snapshot freezes for quiet reason one with frame-rate code two, five system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers at a measured 23.902 displayed swaps per second. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 2,603,570-byte `13_bbb_squirrel_15sec_native24_q6.m2v`, SHA-256 `9257ffadc24eb6696fc9760f3253764b396c993dfc3640e921c97611bad2edce`, was retrieved from the MiSTer byte-exact; its 360 pictures comprise fifteen I, 106 P and 239 B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `13_bbb_squirrel_15sec_native24_q6.m2v` through the normal file selector, watch the complete fifteen-second squirrel and wooden-spike sequence for continuous motion without clean frame skips, then report all three LEDs and leave the completed image loaded for telemetry capture. Require 121 reference plus 239 B pictures, 360 displays and 359 swaps represented by the established eight-bit counter wraps to 104 and 103, exactly 2,603,570 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before deciding how to stage the full endurance test fourteen.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 384 COMMIT Unreleased 2b1a170 2026-08-23T20:33:01-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the seventy-two-picture long-GOP ownership, reordering and publication sequence on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 791,528-byte `11_compat_long_gop.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on. Because USER remains steady, the DISK indication is the normal final GOP-progress code rather than an error sub-code, which the launch-free schema-seven capture confirms: exactly 791,528 transport bytes are accepted, twenty-five reference plus forty-seven B pictures decode, and all seventy-two pictures display with seventy-one swaps. The snapshot freezes for quiet reason one with sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers at a measured 25.026 displayed swaps per second. Ranked telemetry observes the repeated scratch, pending-frame, reorder, queued-generation, promotion and presentation-hold states, while the terminal snapshot has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 1,404,944-byte `12_bbb_squirrel_5sec_native24_q6.m2v`, SHA-256 `dea6b42228158ec4fe43a3cacde71876a21b1fdf3ec9eb37c0c23bf72be2cc84`, was retrieved from the MiSTer byte-exact; its 120 pictures comprise five I, thirty-six P and seventy-nine B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `12_bbb_squirrel_5sec_native24_q6.m2v` through the normal file selector, watch the complete five-second dense-motion clip for continuity, then report all three LEDs and leave the completed image loaded for telemetry capture. Require forty-one reference plus seventy-nine B pictures, all 120 displays, 119 swaps, exactly 1,404,944 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before proceeding to the fifteen-second stress in test thirteen.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 383 COMMIT Unreleased 2b1a170 2026-08-23T20:29:33-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify mixed intra, predicted, skipped and residual macroblocks across repeated B-picture ownership sequences on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 366,071-byte `10_compat_mixed_macroblocks.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 366,072 transport bytes including the expected pad, decoding nine reference plus fifteen B pictures and displaying all twenty-four pictures with twenty-three swaps. Sequence end, session quiet and presentation complete are true with zero decoder or presentation errors and zero cadence outliers at a measured 24.365 displayed swaps per second. Ranked telemetry observes scratch presentation, pending ordinary frames, active B reordering, queued generations, promotion and presentation hold during the repeated ownership sequence, while the terminal snapshot has no active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 791,528-byte `11_compat_long_gop.m2v`, SHA-256 `39dd3e889d1baa42e4d65fc2d6ca7a04c58c2ac38de0a5b1dba00e6585836d96`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its seventy-two pictures comprise three I, twenty-two P and forty-seven B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `11_compat_long_gop.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require twenty-five reference plus forty-seven B pictures, all seventy-two displays, seventy-one swaps, exactly 791,528 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before proceeding to the five-second squirrel stress in test twelve.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 382 COMMIT Unreleased 2b1a170 2026-08-23T20:27:02-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify complete decoding and presentation under the compatibility pack's maximum coefficient and residual traffic.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 2,875,985-byte `09_compat_dense_residual.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 2,875,986 transport bytes including the expected pad, decoding five reference plus seven B pictures and displaying all twelve pictures with eleven swaps. Sequence end, session quiet and presentation complete are all true with zero decoder or presentation errors, no frame waiting and no reorder, queued, promotion, pending-frame or terminal-boundary work remaining. The maximum-residual stress records seven cadence outliers and a 4.940 displayed-swap rate across the measured interval, with the largest decode-limited gaps at approximately 0.414, 0.370 and 0.298 seconds; these are retained as throughput evidence rather than presentation loss because every picture and swap completes exactly once and terminal ownership is clean. The exact odd-length 366,071-byte `10_compat_mixed_macroblocks.m2v`, SHA-256 `ad1d9e81f0f7544ac16a1aaddb85ef9e1065333c1fdd305aa3cf275aa1ccc289`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its twenty-four pictures comprise two I, seven P and fifteen B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `10_compat_mixed_macroblocks.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require nine reference plus fifteen B pictures, all twenty-four displays, twenty-three swaps, 366,072 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test eleven; record cadence outliers as throughput evidence without conflating them with the exact completion gate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 381 COMMIT Unreleased 2b1a170 2026-08-23T20:24:44-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify repeated multi-slice decoding and presentation on the accepted ordinary queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 185,393-byte `08_compat_multi_slice.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 185,394 transport bytes including the expected pad, decoding three reference plus two B pictures, displaying all five pictures with four swaps and reaching sequence end, session quiet and presentation complete with zero decoder or presentation errors and zero cadence outliers. Ranked telemetry observes the expected active reorder, scratch display, queued generation and promotion state before the terminal reference, while the final snapshot has no active reorder, queued generation, promotion, pending frame or terminal boundary. This preserves repeated-slice parsing, B ownership and complete presentation under the new ordinary-reference hold. The exact 2,875,985-byte `09_compat_dense_residual.m2v`, SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its twelve pictures comprise one I, four P and seven B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `09_compat_dense_residual.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require five reference plus seven B pictures, all twelve displays, eleven swaps, 2,875,986 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test ten.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 380 COMMIT Unreleased 2b1a170 2026-08-23T20:21:34-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Confirm that the accepted ordinary queue-capacity fix preserves complete B-picture decoding, reordering and presentation across independent forward and backward motion-vector ranges.

#### Outcome:

After a MiSTer power cycle, the authoritative 185,054-byte `07_b_f_code_range.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one with all 185,054 bytes accepted, three reference plus two B pictures decoded, all five pictures displayed, four swaps, sequence end, session quiet, presentation complete, zero decoder and presentation errors and zero cadence outliers. Ranked telemetry observes the active B-reorder path with scratch presentation, queued generation, promotion and presentation hold before the terminal fifth display, then confirms all reorder, queued, promotion, pending-frame and terminal-boundary state retired in the final snapshot. Test seven therefore preserves the established B ownership contract under the new ordinary-reference backpressure and passes the full hardware gate. The next authoritative 185,393-byte `08_compat_multi_slice.m2v`, SHA-256 `bcd25c393f42aa1ccb8dc076a87ad14560357db4613093c93472d49d13ec3be8`, was generated locally, installed in the MiSTer file directory and retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer and load `08_compat_multi_slice.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require three reference plus two B pictures, all five displays, four swaps, 185,394 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test nine.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 379 COMMIT Unreleased 2b1a170 2026-08-23T20:18:20-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the ordinary presentation queue-capacity fix with two reboot-isolated executions of the stream that exposed the deterministic dropped display.

#### Outcome:

The exact installed 4,173,788-byte RBF for `2b1a170`, SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`, passes `06_p_f_code_range.m2v` twice after separate MiSTer power cycles. The user reports USER steady on, DISK steady off and POWER steady on for both runs. Both launch-free schema-seven captures freeze for quiet reason one with exactly 184,678 accepted transport bytes including the odd-byte pad, five reference pictures, five displayed pictures, four swaps, sequence end, session quiet, presentation complete, zero presentation errors, zero decoder error flags and zero cadence outliers. Both finish on reference bank one with no frame waiting, input or destination hold, pending scheduler work or active reorder state; their three ranked cadence gaps also agree at 2,984,256, 2,984,256 and 1,989,504 decoder cycles despite normal variation in decode and host-transfer stalls. This reverses the prior repeatable four-display and three-swap hardware failure and proves that the ordinary queue-capacity hold prevents publication overwrite without disturbing terminal retirement. Telemetry capture is now non-interactive by bypassing the stale local key-only SSH stanza with an isolated SSH configuration and retrieving the screenshot through the established automatic FTP connection. The exact 185,054-byte test-seven stream already on the MiSTer was independently retrieved at the authoritative SHA-256 `d0aad59a546114c7fe36680902c2bb912c7bcc2a43201ae9d0fd790d6f877725`.

#### Next Steps:

Continue the numeric hardware regression with `07_b_f_code_range.m2v`, which exercises independent forward and backward B-picture motion-vector ranges. Power-cycle before loading it through the normal file selector, record all three LEDs, leave the completed image loaded for launch-free telemetry, and require all five pictures to display with four swaps, sequence-end quiet, complete B-path retirement and zero errors before proceeding to test eight.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 378 COMMIT Unreleased 2b1a170 2026-08-23T19:55:34-07:00

#### Coming From:

Unreleased 292981f

#### Purpose:

Prevent rapid ordinary I/P publications from overwriting an undisplayed queued reference before its cadence slot.

#### Outcome:

The exact authoritative `06_p_f_code_range.m2v` exposed the same deterministic hardware failure after two isolated reboots: 184,678 accepted transport bytes, five reference pictures, zero decoder errors, sequence-end quiet and presentation complete, but only four displayed pictures and three swaps. Commit `2b1a170` prevents ordinary pending-slot overwrite by holding input after a released non-B reference differs from the current display; the initial same-bank reference remains exempt to avoid startup deadlock and the established B-reorder hold remains unchanged. The focused scheduler regression passes rapid three-bank publication and retirement at all five supported cadence rates. Full-pipeline replay of test six at the hardware-equivalent 994,752-cycle display interval now completes five publications, five displayed identities and four swaps with 184,677 file bytes and zero errors; the established ordinary-P, B-containing and repeated-multi-slice controls also pass, and the schema-seven cadence-profiler checksum remains `eb2b643d`. The seed-eleven Quartus 17.0.2 build completed in 11 minutes 50 seconds with zero errors and 154 warnings, using 34,673 ALMs, 51,930 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. Every timing category is positive with zero endpoint TNS: plus 0.293 ns HDMI setup, plus 0.713 ns host setup, plus 1.005 ns decoder setup, plus 8.399 ns video setup, plus 0.261 ns hold, plus 3.533 ns recovery, plus 0.605 ns removal and plus 1.122 ns pulse width. The 4,173,788-byte RBF has SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`; it was installed persistently on the MiSTer and retrieved byte-for-byte identical through the automatic non-interactive connection.

#### Next Steps:

Power-cycle the MiSTer and run `06_p_f_code_range.m2v` twice, rebooting between runs and leaving each completed video loaded for telemetry capture. Require USER steady on, DISK steady off and POWER steady on together with a quiet schema-seven snapshot containing 184,678 accepted transport bytes including the odd-byte pad, five reference pictures, five displayed identities, four swaps, sequence end, session quiet, presentation complete and zero error flags. Do not proceed to test seven until both isolated runs pass.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/run_live_raster_soak_verilator.sh

#### Status:

- [x] Built
- [ ] Passed

---
## 377 COMMIT Unreleased 292981f 2026-08-23T19:32:29-07:00

#### Coming From:

Unreleased 292981f

#### Purpose:

Record isolated hardware acceptance of generic terminal completion across all-I, P-only and B-containing streams.

#### Outcome:

The exact 4,188,704-byte RBF for `292981f`, SHA-256 `1258735da72354789e0fddabc44ed0b06185c0e00919f1a23c40e983f3c69e31`, remained installed for three reboot-isolated normal-selector tests. `01_i_baseline.m2v` passed with USER steady on, DISK two blinks and POWER steady on; launch-free schema-seven telemetry froze for quiet reason one with sequence end, session quiet, presentation complete, zero errors, four reference pictures, four displayed pictures, three swaps and 726,704 accepted bytes including the expected odd-byte pad. `02_p_motion_residual.m2v` passed with USER steady on, DISK steady off and POWER steady on; its quiet snapshot reports sequence end, session quiet, presentation complete, zero errors, two reference pictures, two displayed pictures, one swap, 181,134 accepted bytes and final picture type P. `04_b_bidirectional.m2v` passed with USER steady on, DISK steady off and POWER steady on; its quiet snapshot reports sequence end, session quiet, presentation complete, zero errors, three reference plus two B pictures displayed, four swaps and 185,150 accepted bytes including the expected pad. Ranked-gap telemetry captured the B run with presentation completion false while reorder work remained, followed by a final gap with presentation completion true, reorder false and session quiet true, proving that the generic fix preserves B-path ownership and retirement behavior. The user rebooted between every file load. A dedicated local RSA key and non-interactive BatchMode SSH configuration were prepared outside the repository with password and keyboard-interactive authentication disabled; they were intentionally not tested after preparation because the user requested no further MiSTer contacts in this turn, so any failed future key-only connection will stop instead of prompting.

#### Next Steps:

Treat `292981f` and its installed RBF as the accepted generic terminal-telemetry boundary. On the next explicitly needed device contact, try only the prepared key-based connection and stop silently if it is unavailable. Resume timestamp-driven presentation against the proven system clock while retaining free-running cadence for unannotated streams, then implement the PCM sink as the subsequent feature boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 376 COMMIT Unreleased 292981f 2026-08-23T19:00:57-07:00

#### Coming From:

Unreleased 0f7edd5

#### Purpose:

Make terminal presentation completion generic so all-I and P-only streams reach the same quiet telemetry snapshot path as B-containing streams.

#### Outcome:

Commit `292981f` initializes the scheduler's presentation-complete state high while no B-reordering run exists, clears it on the first B header, and retains the established restoration only after scratch pictures and the future reference retire. This fixes all-I and P-only quiet telemetry without weakening the top-level drain predicate or changing B ownership and cadence behavior. The focused scheduler test explicitly proves I-only and P-only completion, B-header revocation, B-run restoration and all five supported cadence rates; the schema-seven cadence-profiler test retains quiet, forced, fatal and no-progress capture with checksum `eb2b643d`. Full-pipeline generic P, B and repeated-multi-slice replays retain exact row, picture, publication and presentation counts with zero errors; the all-I replay reaches four pictures, four publications, three swaps and generic presentation complete with zero errors, but its reusable generic bench remains inapplicable because that bench unconditionally requires prediction reads and reconstruction for every stream. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 25 seconds with zero errors and 155 warnings. Every timing category is positive with zero endpoint TNS: plus 0.330 ns HDMI setup, plus 1.029 ns decoder setup, plus 1.246 ns host setup, plus 7.960 ns video setup, plus 0.252 ns hold, plus 4.145 ns recovery, plus 0.610 ns removal and plus 1.122 ns pulse width. It uses 34,549 ALMs, 51,860 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. The 4,188,704-byte RBF has SHA-256 `1258735da72354789e0fddabc44ed0b06185c0e00919f1a23c40e983f3c69e31` and was installed persistently on the MiSTer, then retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer, run `01_i_baseline`, `02_p_motion_residual` and `04_b_bidirectional` through the normal file selector, and record USER, DISK and POWER for every stream. Leave each completed video open long enough to read launch-free telemetry, requiring quiet snapshot reason one, sequence end, session quiet, presentation complete and zero error flags; the B stream must also retain its established complete presentation state. Do not accept the source commit until those hardware results pass.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 375 COMMIT Unreleased 0f7edd5 2026-08-23T18:47:02-07:00

#### Coming From:

Unreleased dea60bc

#### Purpose:

Make the hardware regression pack self-contained, checksum-verifiable and explicit about the three-LED acceptance evidence required for every stream.

#### Outcome:

Commit `0f7edd5` places the complete regression instructions, three-LED results template, fifteen stream checksums and canonical compatibility manifest under `docs/`, identifies the currently accepted `dea60bc` RBF exactly, requires USER, DISK and POWER readings for every normal and recovery run, and records the exact generation commands for the squirrel stresses and full-movie recipe. The new verifier accepts only the exact fifteen-file stream set, checks every payload digest, validates the canonical manifest hash, portable paths, four-case structure and per-case stream identities, accepts the original release-candidate manifest only by its exact known legacy digest, and rejects an incomplete pack. Regeneration proved tests `01` through `11` byte-identical to their recorded hashes; the five-second start-440, fifteen-second start-435 and no-frame-counter full-movie recipes reproduce their three hashes; and the first 100,000 bytes of test `11` reproduce test `99`. The compatibility generator now records repository-relative paths, constrains FFmpeg debug decoding to one thread, and retries until its macroblock inventory accounts for every expected 45-by-30 picture row, which removes the discovered manifest-only nondeterminism; two complete runs produced the same canonical manifest SHA-256 `ae0d767f9ee6e95cd68d4224b40ce4d45a246df435707a6f9afa8cb09b75c822`. Both Python files compile cleanly, whitespace checks pass and no Quartus build or new RBF is required because compiled FPGA source is unchanged. The launch-free telemetry fault remains separately scoped: the top-level quiet gate incorrectly requires B-path completion for all-I and P-only streams.

#### Next Steps:

Open a separate generic terminal-quiet telemetry cycle that derives presentation completion from the active stream path rather than requiring B-path completion unconditionally. Cover all-I, P-only and B-containing terminal cases in focused simulation, build a timing-clean RBF, install it byte-verifiably, and confirm on hardware that launch-free telemetry freezes for quiet completion while the accepted USER, DISK and POWER behavior remains unchanged.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/RESULTS_TEMPLATE.txt
- docs/SHA256SUMS
- docs/compatibility_manifest.json
- tools/streams/generate_test_progressive_compatibility.py
- tools/streams/verify_regression_pack.py

#### Status:

- [x] Built
- [ ] Passed

---
## 374 COMMIT Unreleased dea60bc 2026-08-23T18:40:19-07:00

#### Coming From:

Unreleased dea60bc

#### Purpose:

Hardware-qualify the repaired in-band metadata boundary and displayed-frame timestamp association with explicit LED and launch-free telemetry evidence.

#### Outcome:

The exact 4,209,348-byte RBF for `dea60bc`, SHA-256 `6d86641ca5c9460c9025961ccff0403438f7034949f3046b8ee2c0592fde9afc`, was uploaded persistently and retrieved byte-for-byte identical. After a power cycle, plain `04_b_bidirectional` passed twice with USER steady on, POWER steady on and DISK steady off, reversing the reproducible USER one blink and DISK fifteen syntax failure on `27ad1b3` and proving the pulse-valid repair on the P-ownership hold that exposed it. After another power cycle, the unannotated 726,703-byte `01_i_baseline` passed with USER steady on, POWER steady on and DISK two blinks; schema-seven telemetry reports four displayed pictures, zero associations, zero displayed timestamp, zero error flags and sequence end. The deterministic 726,739-byte annotated companion was found already installed, reproduced byte-identically from the committed injector, and duplicated under the visible name `01A_ANNOTATED_4PTS.m2v`; after another power cycle it passed with the same successful LED state, four associations, displayed timestamp low bits `0x223`, four displayed pictures, zero error flags and sequence end. This proves records cross the ordinary file path, survive the repaired backpressure boundary, are stripped without changing decoded bytes, bind to all four pictures and follow frame ownership to the displayed frame. Both launch-free snapshots froze on the profiler's forced terminal timeout before `session_quiet` and `presentation_complete` became true, while the later LED acceptance snapshot was successful, so those frozen fields remain a profiler timing limitation rather than a decoder failure. The proposed `quartus_sh --write_settings_files=off` edit from Entry 372 must not be made as written: Quartus 17 rejects that shell option, and the normal flow output proves its map, fit and assembler children already run with settings writes disabled.

#### Next Steps:

Treat `dea60bc` and the installed RBF as the accepted timestamp-association boundary. The next repository-only cycle should place the regression instructions, result template, checksums and compatibility manifest under `docs/`, require USER, POWER and DISK observations for every hardware stream, regenerate the pack from committed generators, and correct the launch-free snapshot trigger so terminal fields are captured after quiet rather than by forced timeout. After that reproducibility boundary is accepted, resume timestamp-driven presentation against the proven system clock while retaining free-running cadence for unannotated streams.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 373 COMMIT Unreleased dea60bc 2026-08-23T18:08:10-07:00

#### Coming From:

Unreleased 3ae9885

#### Purpose:

Restore the decoder's pulse-valid ingress contract across the in-band metadata extractor after hardware bisection identifies repeated-byte parsing during a P-picture ownership hold.

#### Outcome:

The user reports USER one blink, DISK fifteen blinks and POWER steady on for plain `04_b_bidirectional` on the installed `27ad1b3` image. The LED hierarchy identifies the first failure as frontend syntax error source fifteen, while POWER zero is the expected absence of a nested source for a syntax error. Because `27ad1b3` differs from the earlier accepted image at the compressed-data boundary only by `mpeg2_h262_inband_metadata`, this completes the bisection. Static tracing finds the specific contract mismatch: the extractor retained `stream_valid` as a level while `mpeg2_new_stream_ready` was false, but the established frontend and parser advance on every cycle of `stream_valid`, so the ownership hold replayed one byte into syntax parsing. A focused regression using the real transport convention in which input valid is derived from readiness reproduces six accepted bytes as eight visible byte cycles on the pre-fix RTL. Commit `dea60bc` retains the pending byte internally while presenting output valid only on the actual decoder transfer; the regression then reports exactly six visible cycles. The extractor unit test, timestamp association test, transport-gate test and schema-seven cadence-profiler test all pass, and a 550,316-byte elementary-stream replay with five inserted records emits the source byte-identically with all five timestamps extracted. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 46 seconds with zero errors, 154 warnings and every timing category positive: plus 0.372 ns HDMI setup, plus 0.840 ns decoder setup, plus 0.928 ns host setup, plus 8.766 ns video setup, plus 0.251 ns hold, plus 4.400 ns recovery, plus 0.493 ns removal and plus 1.122 ns pulse width. It uses 34,968 ALMs, 51,912 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks; the 4,209,348-byte RBF has SHA-256 `6d86641ca5c9460c9025961ccff0403438f7034949f3046b8ee2c0592fde9afc`.

#### Next Steps:

Install only the exact RBF identified above. Hardware validation must begin with plain `04_b_bidirectional`, requiring USER steady on rather than the syntax error now measured, and must then exercise the unannotated control and annotated timestamp stream. Add explicit USER, POWER and DISK readings to the repository regression instructions as a subsequent tooling and documentation boundary so plausible still images can no longer count as a pass without LED evidence.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/tb_h262_inband_metadata.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 372 COMMIT Unreleased 3ae9885 2026-08-23T17:44:42-07:00

#### Coming From:

Unreleased 2d555f7

#### Purpose:

Carry in-band timestamps through frame ownership to the displayed frame, and record the regression and procedural gaps that validating it exposed.

#### Outcome:

`09765db` added `mpeg2_h262_picture_timestamp`, which captures a timestamp at the picture start following its record, holds it while that picture decodes and commits it to the frame bank the picture lands in, so reading by `display_frame_bank` yields the timestamp of the displayed frame despite decode reordering; completion is detected as a toggle of `active_frame_bank`, which the bookkeeper inverts only on persistence. `0a6baf3` then corrected a real defect: the module had been bound to the frontend's `picture_seen`, which is a sticky level set at the first picture and cleared only by reset rather than a per-picture pulse, so the pending timestamp was cleared in the same cycle it arrived and nothing was ever associated. Simulation passed that broken design because the test drove `picture_seen` as a pulse, testing the assumption rather than the signal; binding moved to `mpeg2_new_picture_header_classified_now`, a genuine one-cycle header pulse, with explicit handling for a record completing in the same cycle as its picture start. `3ae9885` added `read_hardware_cadence.py`, which triggers a screenshot and decodes it without launching anything, because `run_hardware_cadence.py` drives MGL and the command FIFO and its captures have repeatedly disagreed with normal operation. Telemetry moved to schema seven, word thirty-five reporting the associated count and the displayed frame's low timestamp bits, checksum `eb2b643d`. The build closed at plus 0.256 ns HDMI and plus 0.753 ns decoder. Hardware validation then produced three findings that matter more than the feature. First, device state silently invalidated an hour of measurement: the archived `c9bc2ef8` image, bit-identical to one validated earlier the same day, began failing streams it had previously passed, and a power cycle restored it completely; every result taken in that window, including a syntax error and a `fatal_or_no_progress` snapshot on the annotated stream, measured nothing about the design. Second, with a rebooted machine and two repetitions, plain `04_b_bidirectional` fails on `0a6baf3` reporting syntax error source fifteen and passes on `c9bc2ef8`, so a genuine regression exists in this development run and is not caused by annotation: the injector places records at all five true picture starts, the RTL file replay reproduces the source byte for byte, and the stream's I picture carries conformant `FFFF` f_codes, so source fifteen indicates a misparse rather than a bad file. Third, this defect has been invisible because every prior validation was visual and no cycle in this log has ever read the diagnostic LEDs; `04` is five pictures, so a fault after the first still presents a plausible still image. The LED encoding, read from RTL rather than assumed, is that `LED_USER` steady on means no error latched and the stream accepted, N blinks means error flag N with one being syntax, and `LED_DISK` reports the error sub-code when USER blinks but the final GOP progress stage when USER is steady, so the disk indication cannot be interpreted without the user indication. Bisection is under way: `7c29f33` cannot serve as a midpoint because it misses timing at minus 0.202 ns and a violation could itself corrupt parsing, so `27ad1b3` was rebuilt, reproduced byte-identically at `6e075113...`, and is installed to determine whether the ingress extractor or the later timestamp work introduced the fault.

#### Next Steps:

Read the LEDs for plain `04_b_bidirectional` on the installed `27ad1b3` image. A failure implicates the in-band extractor, which is the only change between that image and the archived one touching the data path, and which inserted a three-byte pipeline between the FIFO and the decoder where `mpeg2_new_stream_ready` carries a P-ownership hold written when FIFO position and decoder position were the same instant. A pass implicates the timestamp module of `09765db` and `0a6baf3`, which is supposed to be observational and would therefore not be. Whichever it is, reproduce it in simulation before repairing it, driving the real handshake in which valid is derived from ready and the ownership hold stalls mid-stream, because both defects found in this cycle were hidden by tests that modelled assumptions about signals rather than the signals themselves. Add the LED reading to the regression procedure as a required per-stream observation with the encoding recorded, since the procedure already names the USER LED as the positive completion diagnostic and never said to look at it. Move `TEST_INSTRUCTIONS.md`, `RESULTS_TEMPLATE.txt`, `SHA256SUMS` and `compatibility_manifest.json` into `docs/`, because the regression procedure currently exists only in an untracked Desktop directory and a fresh clone cannot reproduce the validation inputs, which is the third instance this session of the workflow depending on something outside the repository. Regenerate the regression streams from the committed generators in `tools/streams/` and compare them against the pack's `SHA256SUMS` to confirm the pack is reproducible. Add `--write_settings_files=off` to the compile command in `tools/build.sh`, because a crashed flow wrote 298 lines of generated pin assignments into the tracked `MediaPlayer.qsf`.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/read_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_picture_timestamp.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 371 COMMIT Unreleased 2d555f7 2026-08-23T16:00:17-07:00

#### Coming From:

Unreleased 3f279dd

#### Purpose:

Supply the harness that injects in-band metadata records and prove the extraction path end to end on hardware.

#### Outcome:

The restored `3f279dd` netlist rebuilt to RBF SHA-256 `6e075113416bf8bb891d2b00ee96a9748441bb42ce2a10dec81ef93b37a8fb13`, byte-identical to `27ad1b3`, with 35,055 ALMs, 51,819 registers, plus 0.138 ns HDMI setup and plus 0.933 ns decoder setup, confirming both that the revert restored ASCAL exactly and that determinism continues to hold. The user validated that image and every stream passed, accepting the metadata extractor as harmless to plain elementary streams, which was the property at risk because the four-byte detection window holds the `sequence_end_code` at end of transfer and a broken flush would have truncated every stream. This commit adds tools only and required no rebuild. `inject_inband_metadata.py` annotates an elementary stream by inserting a nine-byte record before each picture start, refusing outright to process a file that already contains `0x000001B0` so a stream cannot be annotated twice, and `tb_h262_inband_metadata_file.sv` replays an annotated stream and its unannotated source through the extractor, requiring the emitted bytes to equal the source exactly, with stream paths and lengths passed as plusargs so any file can be used. Annotating the four-picture `01_i_baseline` produced exactly four records and a file thirty-six bytes larger, and an independently written stripper reduced it to a byte-identical copy of the original. The file replay then drove all 726,739 annotated bytes through the RTL with backpressure applied every 977 bytes and reproduced all 726,703 source bytes exactly, extracting four records with a final timestamp of `0x7A223`. That predicted the hardware result before it was measured, which it matched exactly: the annotated stream reports four records and low timestamp bits `0x223` with zero error flags, while the unannotated control over the same core and the same picture content reports zero records and zero timestamp. Metadata therefore travels from a file, over the ordinary `ioctl_download` path, through the sliding-window detector, is stripped ahead of the decoder and unpacked with its timestamp intact, with no side channel, no daemon, no `Main_MiSTer` change and no kernel work. Two harness limitations were observed and are not defects in the core: `run_hardware_cadence.py` reports picture and byte counts that do not match the stream it was given, the same discrepancy the archived seed ten image reproduces, and its snapshots were taken before terminal quiet so `sequence_end_seen` reads false.

#### Next Steps:

Carry the extracted timestamp into frame ownership and present on it against the system time clock, anchoring from the first record in a stream and retaining free-running cadence for streams that carry none, which is the change that genuinely risks presentation regressions and now has both a proven clock and a proven metadata path beneath it. Extend the injector to derive timestamps from a real cadence rather than a fixed step once presentation consumes them, so the injected values describe the stream instead of merely exercising the path. The PCM sink follows with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Continue checking the weakest margin across all clocks after each addition, reseeding rather than restructuring when the HDMI domain is the category that fails. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery, and delete the six compiled but uninstantiated modules for navigability.

#### Files Modified:

- tools/streams/inject_inband_metadata.py
- tools/streams/tb_h262_inband_metadata_file.sv

#### Status:

- [x] Built
- [x] Passed

---
## 370 COMMIT Unreleased 3f279dd 2026-08-23T15:32:17-07:00

#### Coming From:

Unreleased 19022d9

#### Purpose:

Restore the sequential ASCAL divide tail after speculation proved a net loss, and record that the HDMI domain is now a reseed rather than a restructure problem.

#### Outcome:

Investigating why the HDMI domain absorbs every addition produced the answer that reframes four cycles of work. That clock runs at 148.54 MHz against a measured Fmax of 151.65 MHz, two percent of headroom, on a `5CSEBA6U23I7` industrial speed-grade seven part, at a rate fixed by the 1080p pixel standard rather than chosen. `ascal` occupies 2,030 ALMs of 35,055, under six percent, against 28,163 for `emu`, so it is neither large nor crowding anything out; it fails first because it is the only clock with no room to absorb a placement shuffle. The decoder by contrast runs at 60 MHz against 63.56 MHz Fmax with 16.7 ns of budget and is healthy. Lowering the output clock would double every budget in that domain, but `video_mode` belongs to the user's `MiSTer.ini` and the core cannot force it; constraining the build to 720p would leave the bitstream unverified for anyone running 1080p, and would sacrifice the scanline and shadow-mask granularity that is much of why this community runs higher output resolutions. `19022d9` then attempted the fifth ASCAL fix by speculation, computing the four possible results of the final two non-restoring divide steps in parallel from `div_v` rather than serially, which is valid because successive add and subtract on 21-bit unsigned are associative including wraparound, and which avoided adding a pipeline stage the depth-matched horizontal pipeline could not have absorbed without realigning `o_copyv`, `o_dcptv_clr`, `o_dcptv_inc` and `o_hpixq`. It worked locally: the divider path left the worst five entirely. It failed globally: the three extra 21-bit adders cost 157 ALMs and raised peak interconnect from 69.6 to 72.4 percent, HDMI setup fell from plus 0.138 ns to minus 0.129 ns at seed eleven, and a second seed reached only plus 0.121 ns, still short of what the unmodified netlist already held. Trading area for logic depth stopped paying because depth is no longer what binds; the paths now surfacing are one and zero logic levels, register to wire to register, with nothing combinational left to precompute, duplicate or speculate. This commit therefore reverts `19022d9` and restores `27ad1b3`'s ASCAL exactly, confirmed by diff. The wider conclusion is recorded deliberately: four structural fixes held because their paths had depth to remove, and the fifth did not because its path did not. HDMI is from here a domain where seed selection is the appropriate tool rather than an evasion, because the seed acts on placement and placement is now the whole mechanism. That is a genuine reversal of the position taken at entry 363, and it applies only to this clock domain; the decoder remains one where a marginal path should be fixed rather than reseeded.

#### Next Steps:

Rebuild at seed eleven and confirm the restored netlist returns to approximately plus 0.138 ns HDMI setup and plus 0.933 ns decoder setup with every category positive. Then validate on MiSTer together with the metadata channel of `27ad1b3`, requiring every raw elementary-stream regression to decode exactly as before, which it should because those streams are plain `.m2v` containing no records and the extractor is invisible to them. Supply the throwaway HPS-side harness that injects records so `inband_count` and the low timestamp bits can be confirmed against an injected value in the schema six snapshot. Presentation on timestamp against the proven clock follows, anchoring from the first record and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Check the weakest margin across all clocks after each addition rather than the decoder alone, and when HDMI is the category that fails, reseed rather than restructure.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 369 COMMIT Unreleased 27ad1b3 2026-08-23T15:03:04-07:00

#### Coming From:

Unreleased c25f3d9

#### Purpose:

Carry picture metadata in band with the elementary stream so the HPS can supply timestamps without a side channel.

#### Outcome:

`EXT_BUS` was investigated as the metadata channel and rejected on a dependency rather than a technical obstacle. It is available to the core, unconnected at `MediaPlayer_top_00.svh`, and its wiring is straightforward, but it carries Main_MiSTer's `user_io` transactions, so something in that binary must issue them; cores that use it have matching support there. Building the metadata path on it would make this project depend on changes to software it does not own, the same class of external dependency as the kernel configuration needed for USB optical media, and nothing in this repository sets a precedent to follow. The ingress byte path needs no such permission and is already proven to 14,315 pictures with working backpressure, so records are framed in band instead. The marker is `0x000001B0`, a reserved H.262 start code that no encoder emits, and start-code emulation prevention guarantees the `0x000001` prefix cannot occur inside payload, so raw elementary streams contain no records and pass through untouched; compatibility is a property of the framing rather than a mode to select. Each record carries five payload bytes holding a 33-bit timestamp with `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame`, the fields interlaced operation will need, so the wire format will not require revision when field pictures are implemented. Detection uses a four-byte sliding window rather than a match counter, which makes overlapping prefixes correct without special cases because the window always holds the true last four bytes. An end-of-transfer flush was required and reinstated using the same download-active synchroniser `c4d9631` used, because without it the final three bytes of every stream would remain in the window and the `sequence_end_code` would never reach the decoder. The focused test proved five properties and caught two real defects in the process: markers were never detected in steady state because the window counter ran past the value the check compared against, and the byte immediately preceding every record was silently dropped, which would have corrupted the bitstream once per timestamp and presented as a decoder fault. It now passes byte-identical passthrough of a stream containing a real start code and an overlapping `00 00 00 01` run, record extraction with exact timestamp and flag decode, rejection of the near-miss `0x000001B1`, the overlapping-prefix record, and backpressure without loss or reordering. The cadence snapshot moves to schema six, word thirty-five's spare bits carrying the record count and the low eleven timestamp bits so an injected value can be matched exactly rather than merely seen to be non-zero. The build closes every category with HDMI setup plus 0.138 ns and decoder setup plus 0.933 ns, the highest recorded, using 35,055 ALMs, 51,819 registers and RBF SHA-256 `6e075113416bf8bb891d2b00ee96a9748441bb42ce2a10dec81ef93b37a8fb13`. The 159 added registers cost 0.257 ns on a clock they do not touch, which is the placement sensitivity this log has been tracking rather than anything specific to this change; average interconnect actually fell to 40.3 percent with peak flat at 69.6 percent, confirming the design is not becoming globally congested.

#### Next Steps:

Investigate why the HDMI domain absorbs every addition before continuing, since four ASCAL paths have now surfaced in sequence. Then supply the throwaway HPS-side harness that injects records so `inband_count` and the low timestamp bits can be confirmed on hardware, and check that the raw elementary-stream regression is unchanged, which it should be because every stream on the MiSTer is plain `.m2v` containing no records and the extractor is therefore invisible to them. Presentation on timestamp against the proven clock follows, anchoring from the first record and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_inband_metadata.sv

#### Status:

- [x] Built
- [x] Passed

---
## 368 COMMIT Unreleased c25f3d9 2026-08-23T13:55:44-07:00

#### Coming From:

Unreleased ed3310b

#### Purpose:

Remove the per-pixel vertical size comparisons from the ASCAL pixel-queue select so the HDMI boundary reaches the seed variance it must survive.

#### Outcome:

Commit `ed3310b` built clean and delivered what it was for, moving HDMI setup from plus 0.054 ns to plus 0.254 ns while every other category stayed positive, using 34,458 ALMs, the lowest of this development run. Decoder setup fell from plus 0.911 ns to plus 0.448 ns in the same fit, which is placement variance within the roughly 0.5 ns spread already measured rather than an effect of a change that touched only ASCAL's vertical counter; the figure that matters is the weakest margin anywhere in the design, and that improved almost fivefold. The bottleneck then relocated to `o_vacpt` feeding `o_vpixq_pre` at four logic levels and 5.790 ns, where the CYCLE 8 pixel-queue select compared `to_integer(o_vacpt)` against `o_ivsize` twice. That call needed a different technique from the previous two fixes: unlike the line-boundary wrap, this block executes on every pixel clock while `o_vacpt` advances only once per line, so a plainly registered predicate would have been stale for the first pixel of every line and would have produced a genuine artifact at the bottom image boundary rather than a theoretical one. This commit therefore updates both predicates in lockstep with `o_vacpt` at each of its two mutually exclusive assignment sites, giving zero skew because predicate and counter change on the same clock. The one behavioural difference from the combinational original is recorded in the code rather than left implicit: the predicates lag by a single line if `o_ivsize` changes while `o_vacpt` does not advance, which occurs only at a mode change where scaler output is transient. Synthesis returned an unchanged register count rather than the expected two additional registers, which could not by itself confirm the predicates survived as registers, so the fit was allowed to settle the question and did: HDMI setup reaches plus 0.395 ns with decoder setup plus 0.473 ns, host bridge plus 1.393 ns, hold plus 0.259 ns, recovery plus 3.950 ns, removal plus 0.677 ns and pulse width plus 1.122 ns, using 34,980 ALMs and 52,123 registers, with RBF SHA-256 `f52f8859277eda230f0bd9b565ca906fdc85debaf8f5014b4659d959182f2ad6`. Across the three ASCAL fixes the weakest margin anywhere moved from plus 0.054 ns to plus 0.254 ns to plus 0.395 ns, a sevenfold improvement from three small and individually precedented changes. The user validated that image on hardware and every stream passed, which accepts all three together: the polyphase select duplication of `cea1d62`, the vertical wrap predicate of `ed3310b` and the pixel-queue selects here, all of which sit in the live video output path where a defect would appear as wrong geometry, unstable sync or bottom-edge artefacts rather than as a decoder error. This is a deliberate stopping point for HDMI work, because the worst remaining path runs from `o_v_poly_phase` to `o_v_poly_t` at 5.907 ns with zero logic levels, a pure register-to-register wire with nothing combinational left to precompute; improving it would require placement control or pipelining the scaler datapath, which is a materially larger change than any taken here.

#### Next Steps:

Resume 0.7.0 with the HDMI boundary no longer the constraint that breaks each addition. Bring up `EXT_BUS`, unconnected at `MediaPlayer_top_00.svh`, together with the throwaway HPS-side harness that exercises it, and define the picture metadata wire protocol carrying the 33-bit timestamp with reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, keeping protocol and harness in one cycle because a protocol with nothing to talk to cannot be tested. Presentation on timestamp against the proven clock follows, anchoring from the first timestamp and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Watch the weakest margin after each addition rather than the decoder alone, since the lesson of this run is that the binding path moves. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, mixed macroblocks, multi-slice, full endurance and the truncation case with its no-reboot recovery, and delete the six compiled but uninstantiated modules for navigability with no timing expectation attached.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 367 COMMIT Unreleased ed3310b 2026-08-23T13:17:21-07:00

#### Coming From:

Unreleased cea1d62

#### Purpose:

Remove the vertical-total comparison from the ASCAL sweep's cycle-critical wrap path so the HDMI boundary has margin the next change can survive.

#### Outcome:

Hardware validation of `cea1d62` passed every stream the user observed, which clears three things at once: the presentation time base introduced by `7c29f33` runs correctly on real hardware, the polyphase select duplication of `cea1d62` is proven in the video path rather than merely closing timing, and the schema five snapshot decodes with its new fields intact, having reported fifteen seconds for a fifteen second stream. A picture-count discrepancy raised by `run_hardware_cadence.py`, which reported one hundred four displayed pictures against an expected three hundred sixty, was investigated and is a harness artifact rather than a defect: the archived and independently validated seed ten image `c9bc2ef8` produces the identical complaint, so the expected count passed to that tool does not match what its MGL launch path actually plays. That image also decoded as schema four against the new build's schema five, confirming the decoder script handles both. The remaining concern was margin rather than correctness, because HDMI closed at only plus 0.054 ns against roughly 0.4 ns of measured seed variance on that path, meaning the next addition would break it. Querying the fit rather than guessing showed all five worst HDMI paths are the same one and are not the kind just fixed: `o_vcpt_pre3` bit zero to bit five, four logic levels and 6.352 ns, which is arithmetic depth inside a counter rather than distance between placements. The vertical sweep wrapped by evaluating `o_vcpt_pre3+1>=o_vtotal` inside the line-boundary branch, placing an increment, a twelve-bit comparison and a three-way mux on a single path. This commit precomputes that predicate into a register in the same process, exactly the technique commit 182 used for `o_vcpt_pre2_at_vmin` a few lines above, leaving only the increment and the mux in the critical cycle. Registering it is safe because `o_vcpt_pre3` advances once per line, hundreds of clocks apart, so the registered predicate always reflects the current count when the boundary arrives; only a mode change could make it lag by one clock, where output is transient regardless. Synthesis is clean at zero errors and an unchanged one hundred thirty-five warnings for exactly one additional register.

#### Next Steps:

Build at seed eleven and require every timing category positive with HDMI setup materially above the plus 0.054 ns it held, since the purpose of this change is margin rather than closure, and record whether the worst HDMI path relocates again. Confirm on MiSTer that every raw elementary-stream regression still passes, because this touches the vertical sweep that generates output timing and a defect would appear as wrong geometry or lost sync rather than as a decoder error. If HDMI margin is then comfortable, resume 0.7.0 by bringing up `EXT_BUS` together with the throwaway HPS-side harness that exercises it, defining the picture metadata wire protocol with the timestamp and the reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, then presentation on timestamp against the proven clock, then the PCM sink. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 366 COMMIT Unreleased cea1d62 2026-08-23T06:01:06-07:00

#### Coming From:

Unreleased 7c29f33

#### Purpose:

Duplicate the ASCAL polyphase select registers so the stage-eight mux stops driving the worst HDMI setup path.

#### Outcome:

Adding the presentation time base at `7c29f33` compiled cleanly but did not close: the HDMI framework clock missed setup at minus 0.202 ns while the decoder held plus 0.453 ns, one hundred eighteen extra registers having been enough to re-roll placement on a path whose margin was already below its variance. Every violated path lay inside `sys/ascal.vhd` rather than in decoder logic, the worst running from `o_v_poly_use_adaptive` to `o_h_poly_phase` at two logic levels, 6.481 ns of data delay and minus 0.253 ns of clock skew, almost all of it wire. The cause is structural rather than unlucky: both polyphase selects are produced at stage C3 and consumed by muxes at C3, C4 and C8, so one register drives consumers spread far enough apart that no placement serves them all. This commit adds a second copy of each select for the C8 consumer, driven from the identical expression in the identical process stage and marked `dont_merge` so Quartus cannot fold them back together. They are duplicates rather than delays, so behaviour is bit-identical and no skew appears at a mode change; the only thing that changes is that the fitter may place a copy beside the C8 mux. The precedent commit `a2debaa` pipelined an ASCAL predicate by realigning it across stages, which suits a value that changes per line, whereas these selects are static between mode changes and duplication is provably equivalent. Synthesis confirms the duplicates survive at exactly two additional registers. The result closes every timing category: HDMI setup recovers from minus 0.202 ns to plus 0.054 ns, and decoder setup reaches plus 0.911 ns, the highest this log has recorded and above the plus 0.572 ns that `2dc52d7` held, with host bridge plus 0.560 ns, video plus 8.191 ns, hold plus 0.211 ns, recovery plus 3.831 ns, removal plus 0.836 ns and pulse width plus 1.122 ns. The fit uses 34,754 ALMs of 41,910 and 51,734 registers in an 11 minute 42 second flow, and the 4,159,388-byte RBF has SHA-256 `c69a26ca1d3a099d93f93755f2bb9a22b8b2bfda22e29a994c6538f7aa29ac93`. Two structural fixes in this development run have now each held where seed selection did not: the registered reference delivery of `ebf372e` and this duplication. The honest qualification is that plus 0.054 ns of HDMI margin sits well below the roughly 0.4 ns seed variance measured on that path, so the design closes but the HDMI boundary is not yet robust to the next change.

#### Next Steps:

Confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, since no image containing the presentation time base has yet run on hardware, and read the schema five snapshot after a ten minute run requiring the seconds field to report six hundred, which measures the clock rate directly. Then decide whether to spend one more cycle on the HDMI boundary before continuing, because plus 0.054 ns will not survive the next addition and the same duplication pattern very likely applies to whatever path is now worst inside ASCAL; identifying it costs one timing query rather than a build. Afterwards resume 0.7.0 with `EXT_BUS` brought up alongside the throwaway HPS-side harness that exercises it, defining the picture metadata wire protocol with the timestamp and the reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, then presentation on timestamp against the proven clock, then the PCM sink. Before release qualification, complete the regression pack left unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 365 COMMIT Unreleased 7c29f33 2026-08-23T05:31:52-07:00

#### Coming From:

Unreleased 9af69b4

#### Purpose:

Introduce the FPGA-owned 90 kHz presentation time base and extract the picture metadata interlaced operation will need, without altering when frames are presented.

#### Outcome:

Seed eleven closes every timing category at plus 0.676 ns decoder setup, plus 0.347 ns on the HDMI framework path, plus 1.539 ns host bridge and plus 7.283 ns video, with a 9 minute 14 second fitter and RBF SHA-256 `3e5f4384c6a4fa263a53cb77de57f7b936bf7a8f214015e3820d868acb390a0a`, satisfying the two-closing-seed gate from entry 363 and becoming the working seed. A third sample widens measured decoder variance to roughly 0.52 ns across seeds nine, ten and eleven at plus 0.460, plus 0.152 and plus 0.676, so the worst observed margin remains below the variance and seed nine still does not close. Hardware validation of seed ten passed the prediction-focused subset and cleared the registered reference delivery of `ebf372e`. This commit opens 0.7.0 under the user's constraint that interlaced operation is deferred while the pipeline must not need redesigning to accept it. It adds `mpeg2_h262_system_time_clock`, anchored to the 24.576 MHz `CLK_AUDIO` domain that `sys/audio_out.sv` clocks samples out on rather than to the pixel clock, so externally decoded audio will be consumed drift-free by construction once the PCM sink exists and every correction falls on the video side where a field of tolerance exists. The counter runs natively at 180 kHz rather than 90 kHz because a field period is not an integral number of 90 kHz ticks: at 29.97 Hz a frame is 3003 and a field 1501.5, whereas in half-ticks a field is 3003, a frame 6006 and a `repeat_first_field` frame 9009, all exact, which is what makes 3:2 pulldown expressible later without reworking the arithmetic. The divide is exact rather than approximate because 180000/24576000 reduces to 15/2048, so an eleven-bit accumulator incremented by fifteen overflows exactly 180000 times per second, and the 90 kHz view is that counter shifted right so the two cannot disagree. Simulation measures rather than restates this: one simulated second yields exactly 180000 half-ticks, exactly 90000 ticks and exactly one seconds pulse, the anchor load lands exactly and restarts the accumulator phase, and a paused clock does not advance. The frontend now extracts `top_field_first` from `payload_next[15]` and `repeat_first_field` from `payload_next[9]`, both already inside the five-byte `picture_coding_extension` window it captures and neither previously present anywhere in the tree. Only a single bit crosses clock domains: the clock emits a 1 Hz pulse that crosses into `clk_mpeg2` through a two-flop synchroniser and is counted there, because synchronising a multi-bit counter risks tearing across a carry and a thirty-three bit gray decode would be a thirty-three level XOR chain, a new timing problem on a design that spent this run recovering margin. The cadence snapshot moves to schema five, the formerly reserved low half of word nineteen carrying the seconds count and both field flags, with checksum moving from `e82b643d` to `e92b643d` exactly as the single changed format byte predicts. Two scope reductions were taken against the approved plan and both are recorded rather than absorbed: presentation swaps remain free-running because changing presentation timing is the riskiest available change and wants a proven clock beneath it, and the HPS-readable clock and picture metadata wire protocol are deferred because `EXT_BUS` is unconnected at `MediaPlayer_top_00.svh` and no HPS-side code exists to read either, so neither could be verified this cycle. Synthesis is clean at zero errors and an unchanged one hundred thirty-five warnings for 49,479 registers against 49,361.

#### Next Steps:

Build at seed eleven, require every timing category positive, and confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, which should hold by construction because no presentation behaviour changed. Read the schema five snapshot after a ten minute run and require the seconds field to report six hundred, which measures the presentation clock rate directly on hardware; the field flags should read whatever the stream carries and are not yet consumed. The following cycle brings up `EXT_BUS` together with the throwaway HPS-side harness that exercises it, defining the picture metadata wire protocol with the 33-bit timestamp and reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, because a protocol with nothing to talk to cannot be tested and designing it blind invites revising it later. Presentation on timestamp against the proven clock follows, anchoring from the first timestamp and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Before release qualification, complete the regression pack left unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_system_time_clock.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_system_time_clock.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 364 COMMIT Unreleased 9af69b4 2026-08-23T05:01:06-07:00

#### Coming From:

Unreleased 85b4c17

#### Purpose:

Confirm with a second fitter seed that this netlist closes timing repeatably rather than on one favourable placement.

#### Outcome:

Seed ten closed every timing category on `85b4c17`, the first fully closing fit since the Program Stream demux was removed. Decoder setup is plus 0.152 ns, the HDMI framework path plus 0.210 ns, host bridge plus 0.754 ns, video plus 7.556 ns, with hold plus 0.248 ns, recovery plus 4.021 ns, removal plus 0.759 ns and pulse width plus 1.122 ns, using 34,947 ALMs of 41,910, 51,833 registers and unchanged memory and DSP, built in a 12 minute 37 second flow with a 10 minute 26 second fitter. The 4,145,288-byte RBF with SHA-256 `c9bc2ef8061722c4b21803eef2464453be3be475474a290f766511485382af1f` was installed on the MiSTer together with seven regression streams, and the user reports every test passing, which clears the one unvalidated change of this development run: the extra delivery cycle that `ebf372e` introduced on the shared reference path feeding both the mixed and bidirectional prediction engines. The validated set was the prediction-focused subset, namely intra baseline, B bidirectional, B f-code range, P motion residual, P visual discriminator and the five and fifteen second dense-motion squirrel stresses; the multi-slice, dense residual, mixed macroblock, long GOP and full endurance files, the deliberate truncation case and its no-reboot recovery re-run were not exercised and remain outstanding before any release qualification. Comparing seed nine and seed ten on this identical netlist finally measures genuine seed-to-seed variance rather than inferring it: decoder setup moves from plus 0.460 ns to plus 0.152 ns and the HDMI path from minus 0.053 ns to plus 0.210 ns, a spread near 0.3 ns on both, which is roughly half the 0.6 ns figure entry 361 assumed and confirms that figure was measuring the removal of the demux rather than placement variance. That result is not comfortable. Decoder margin at seed ten is plus 0.152 ns against a 0.3 ns spread, so margin remains smaller than variance, and seed nine is a known non-closing seed on this exact netlist, meaning the design closes on some placements and not others. This commit changes only the fitter seed from ten to eleven.

#### Next Steps:

Require every timing category positive at seed eleven. Two closing seeds out of three attempted would establish that closure is reproducible enough to resume feature work, while a second failure would establish the opposite and force the margin question back open with the knowledge that block RAM conversion of the fetched-word store is unavailable in this toolchain. Record both seeds' decoder and HDMI slacks either way, since these are the first controlled variance measurements this project has. Before release qualification, complete the regression pack that tonight's run left unexercised, in particular the long GOP, dense residual and full endurance streams and the truncation case with its no-reboot recovery. Once closure is established, 0.7.0 resumes with the system time clock anchored to the 24.576 MHz audio domain and the PCM sink, both of which will need a small throwaway HPS-side harness to inject synthetic timestamps and a test tone because no daemon exists yet. The six compiled but uninstantiated modules remain worth deleting for navigability with no timing expectation attached, and renaming the decode modules that carry probe names remains worthwhile after 0.7.0.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 363 COMMIT Unreleased 85b4c17 2026-08-23T04:32:28-07:00

#### Coming From:

Unreleased ebf372e

#### Purpose:

Close the standing HDMI framework setup path with fitter seed ten now that the decoder reports no violated paths.

#### Outcome:

The registered reference-word delivery added by `ebf372e` worked as intended. Decoder setup moves from minus 0.060 ns with two violated paths to plus 0.460 ns with none of fifty violated, the targeted route disappears from the report entirely, and the worst remaining decoder path relocates to `tap_index` feeding `out_reg` inside `mpeg2_h262_b_bidirectional_raster_engine`. Area and iteration cost both improve sharply: 34,931 ALMs of 41,910 against 35,932 at `2dc52d7`, 51,895 registers, unchanged memory and DSP, a fitter time of 9 minutes 3 seconds and a total flow of 11 minutes 4 seconds, the fastest of this development run. The image is nonetheless unusable because a single path now misses on the `pll_hdmi` clock at minus 0.053 ns with total negative slack of minus 0.053 ns, which is the same standing HDMI framework path entry 319 recorded when seed eight missed and seed nine closed it. That path lies in the MiSTer framework under `sys/` rather than in decoder logic, so seed selection is the available remedy rather than an evasion of a design defect. Converting the thirty-six by sixty-four fetched-word store to inferred block RAM was attempted three ways and abandoned: duplicating the array in place, lifting each copy into an isolated always block with an unconditional registered read after confirming that consumers gate on `block_lookup_valid` and the focused test never inspects data on an invalid lookup, and finally an explicit `ramstyle` attribute. Every attempt produced 53,969 registers against 49,361 and no additional memory bits, because Quartus 17.0.2 Lite will not recognise a store only thirty-six entries deep, so the 2,304 registers that restructuring would have recovered are not available. The plus 1.2 ns decoder gate recorded in entry 361 is also withdrawn here as unsound: it was derived by doubling a 0.6 ns spread measured between `2dc52d7` and `3771f19`, two structurally different netlists, which measures the effect of removing the demux rather than seed-to-seed variance on a fixed design. It is replaced by requiring two consecutive fits at different seeds in which every timing category closes.

#### Next Steps:

Build at seed ten and require every timing category positive, then repeat at a third seed and require the same, because the replacement gate is two consecutive closing fits at different seeds on this netlist rather than a fixed slack target derived from an unsound spread. Record the decoder and HDMI slacks from both so that genuine seed-to-seed variance on this design is measured for the first time. Confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, since the extra delivery cycle affects the shared reference path used by both the mixed and bidirectional engines and no hardware run has yet exercised it. Should seed ten also miss on the HDMI path, treat the framework path as structurally marginal at this occupancy rather than sampling further seeds, and revisit it against the area that gating the two genuine telemetry modules would return. Only once two seeds close does 0.7.0 resume with the system time clock and the PCM sink, and the six compiled but uninstantiated modules remain worth deleting for navigability with no timing expectation attached.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---
## 362 COMMIT Unreleased ebf372e 2026-08-23T04:07:40-07:00

#### Coming From:

Unreleased 4be2b8f

#### Purpose:

Break the route-dominated reference-word delivery path by registering it between the shared reference cache and the prediction block fetchers.

#### Outcome:

Commit `4be2b8f` first corrected an error in the preceding sweep: `mpeg2_h262_reference_pipeline_probe_plan.sv` is pulled in by an `include` directive rather than listed in `files.qip`, so absence from that file does not prove a source is dead, and synthesis rejected the tree in five seconds until it was restored. With that fixed the deletion is proven inert, because synthesis of `4be2b8f` reports 49,295 registers, 3,228,103 memory bits, 65 DSP blocks, 145 pins and one hundred thirty-five warnings, every figure identical to the tree before twenty-four files and all seven duplicate module definitions were removed. A classification pass then overturned this log's earlier assumption that diagnostics were a large share of the design. Tracing what each module's outputs actually reach, rather than trusting its name, shows `mpeg2_h262_luma4_probe` is the intra slice and macroblock parser driving `quantiser_scale_code`, `macroblock_address_increment` and coefficient data, `mpeg2_h262_reference_read_probe` instantiates three decode engines, and the `two_picture_probe` and `p_diagnostic_controller` group carries decode mode selection; only the cadence profiler and the final GOP progress probe are genuine telemetry, together about 588 lines of 12,514 live. Six further modules totalling 2,412 lines are compiled but instantiated nowhere, so they are already optimised away and cost no area. Gating diagnostics is therefore not a margin lever and has been abandoned as one. The failing path itself is not logic-deep: one logic level, 0.792 ns of cell delay and 15.253 ns of routing across fifty-eight elements, ninety-five percent wire, because a thirty-six by sixty-four word store cannot pack near the cache. Converting that store to inferred block RAM was attempted and reverted: Quartus inferred nothing and simply duplicated the array, raising registers to 53,903, because the read is conditional and the array shares a large always block with a reset branch. This commit instead registers the shared cache word together with both ownership-qualified ready strobes, so ownership is still resolved in the cycle the word is produced and only delivery moves by one clock, costing sixty-six registers for 49,361 total with memory and DSP unchanged and zero synthesis errors. The fetchers track outstanding requests through their descriptor queue rather than a fixed response latency, which the focused fetcher test already exercises in both its zero-latency and delayed cases.

#### Next Steps:

Build at seed nine and require decoder setup materially above the plus 0.572 ns that `2dc52d7` held, then repeat at a second seed, because the standing gate before any 0.7.0 feature work resumes is plus 1.2 ns on two consecutive fits at different seeds against a measured fit-to-fit spread near 0.6 ns. Confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, since the extra delivery cycle touches the shared reference path used by both the mixed and bidirectional engines. If margin remains short, restructure the word store for genuine block RAM inference as its own scoped cycle, lifting the memory into an isolated always block and making the read unconditional, which is safe because consumers already gate on `block_lookup_valid`; that would remove 2,304 registers as well as the routing pressure. Separately and with no timing expectation, delete the six compiled but uninstantiated modules for navigability. Renaming the decode modules that carry probe names remains worthwhile after 0.7.0, since that naming has now produced two incorrect recommendations in one session.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 361 COMMIT Unreleased d7c5a8f 2026-08-23T03:25:34-07:00

#### Coming From:

Unreleased 9bfdb21

#### Purpose:

Restore fitter seed nine so the preserved `2dc52d7` placement can be reused, and delete the twenty-five source files Quartus never compiles.

#### Outcome:

Rebuilding `2dc52d7` from source at seed nine confirmed this project's builds are deterministic and regenerated the post-fit database that no backup contained. Every fit metric reproduced exactly: 35,932 ALMs, 52,421 registers, 3,228,103 memory bits, 408 RAM blocks, 65 DSP blocks, a 4,231,288-byte RBF, plus 0.375 ns global setup, plus 0.572 ns decoder setup, plus 7.280 ns video setup and plus 0.246 ns hold, with the fitter taking 10 minutes 33 seconds against 25 minutes 16 seconds for a cold fit of the post-revert tree. Its SHA-256 is `97762a5fe44faaca5b00c6954fc0e5a451d457683273ef21e3d7f28ce73734c3` rather than the recorded `d4f19c0d...` for one benign reason: `sys/build_id.tcl` writes `build_id.v` with a day-granularity `BUILD_DATE`, so an image built on a later calendar day differs by six characters and nothing else. That invalidates the byte-identical RBF gate written into entries 359 and 360, which is superseded here by a gate requiring identical ALM, register, memory, RAM and DSP counts together with every timing slack matching to three decimals. The rebuild also settled a more serious question. Fit-to-fit spread on this design is roughly 0.6 ns, established by `3771f19` reaching minus 0.060 ns decoder setup while carrying 437 fewer ALMs than `2dc52d7` at plus 0.572 ns, so the best margin ever recorded is smaller than the run-to-run variance and timing closure has been luck rather than engineering for several commits. Feature work is therefore suspended until decoder setup reaches plus 1.2 ns on two consecutive fits at different seeds. This commit accordingly abandons seed selection as a closure strategy and returns the seed from ten to nine so the preserved placement applies, and deletes the twenty-five files absent from `files.qip`, which resolves all seven duplicate module definitions because the base-named file is the dead copy in every case. Neither change alters the compiled netlist.

#### Next Steps:

Build warm from the restored database and determine whether the placement that held plus 0.572 ns survives removal of the Program Stream demux, since the cold seed-nine fit discarded that placement and found a worse one. Confirm at the same time that synthesis reports unchanged register and ALM counts, which proves the deleted files were genuinely inert. If margin remains below plus 1.2 ns, classify the diagnostic-named modules by tracing whether every output terminates in telemetry rather than by name, because `mpeg2_h262_reference_read_probe` instantiates the decode pipeline and `wide_seen` selects decode mode, then gate only what that trace proves is instrumentation, which also narrows placement variance by reducing total logic. If margin is still short after that, register the `mpeg2_h262_reference_word_cache` to `mpeg2_h262_b_bidirectional_raster_engine` path in the same manner `2dc52d7` registered the transport boundary for plus 0.357 ns. Only once two consecutive different-seed fits hold plus 1.2 ns does 0.7.0 resume with the system time clock and the PCM sink.

#### Files Modified:

- MediaPlayer.qsf
- rtl/mpeg2_new/mpeg2_h262_ddram_store.sv
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_syntax_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller.sv
- rtl/mpeg2_new/mpeg2_h262_p_luma_macroblock_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_parser.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_two_mb_copy_engine.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_aligned.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_multimb.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_plan.sv
- rtl/mpeg2_new/mpeg2_h262_reference_read_probe.sv
- rtl/mpeg2_new/mpeg2_h262_slice_probe.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_multimb.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_publish.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 360 COMMIT Unreleased 9bfdb21 2026-08-23T02:22:50-07:00

#### Coming From:

Unreleased 3771f19

#### Purpose:

Retry decoder setup closure with fitter seed ten after seed nine leaves two decoder paths marginally violated.

#### Outcome:

This commit changes only the reproducible Quartus fitter seed in `MediaPlayer.qsf` from nine to ten, altering no source, no constraint and no assignment other than that single value, so any change in the result is attributable entirely to fitter placement and routing rather than to design content. It follows the precedent set at entry 319, where moving from seed eight to seed nine closed a seed-sensitive boundary that no design change was required to fix. The condition being addressed is narrow: at seed nine the `3771f19` fit misses decoder setup by minus 0.060 ns with total negative slack of minus 0.061 ns across two violated paths of fifty, while every other timing category is comfortably positive, which is the signature of one marginal path rather than a congested or structurally slow design. Both violated paths run from `mpeg2_h262_reference_word_cache` into `mpeg2_h262_b_bidirectional_raster_engine`, and because those modules carry probe names while actually instantiating the decode pipeline, and the contributing `wide_seen` term selects decode mode rather than reporting telemetry, neither path would be removed by gating diagnostics. The fitter runtime baseline for this design is 25 minutes 16 seconds at eighty-five percent ALM occupancy, so a seed sweep is affordable in a way it was not at the one hour routes seen before the Program Stream demux was removed.

#### Next Steps:

Require all timing categories positive with decoder setup restored toward the plus 0.572 ns held at `2dc52d7`, and treat the violation as structural rather than seed-sensitive if two or three seeds fail in succession, in which case the reference cache to bidirectional engine path is registered properly instead of continuing to sample seeds. Once a seed closes, confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, and record the accepted RBF hash, because that image becomes the byte-identical reference for the cycle that deletes the twenty-five source files Quartus never compiles and resolves all seven duplicate module definitions. A measured cycle then gates the live diagnostic modules behind a compile-time parameter and reports area, timing and fitter-runtime deltas against the 25 minute 16 second baseline, after which the 0.7.0 plan is re-baselined before presentation work resumes with the system time clock and the PCM sink.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
## 359 COMMIT Unreleased 3771f19 2026-08-23T01:44:52-07:00

#### Coming From:

Unreleased 058f0a3

#### Purpose:

Return video ingress to an elementary-stream-only path by removing the hardware Program Stream demux, so demultiplexing, navigation and timestamp extraction can move to the HPS.

#### Outcome:

Following the complexity reevaluation, the user set the architectural boundary at elementary stream in and video out: the FPGA owns H.262 decode, presentation timing and the output path, while everything upstream of the elementary stream, meaning file and disc access, CSS, DVD navigation, demultiplexing and audio, moves to Linux. This commit reverts the hardware Program Stream path introduced by `c4d9631` and extended by `058f0a3`, deleting `mpeg2_h222_program_stream_demux.sv` and its two focused testbenches, removing the demux instantiation and wiring from the top level, dropping its `files.qip` entry, and reverting the cadence snapshot PTS association fields in the profiler, the top-level packing and `decode_hardware_cadence.py`, since those fields would read zero with no demux present and the presentation clock will define its own telemetry against HPS-supplied timestamps. The intervening commit `2dc52d7` is deliberately retained: it hardens `mpeg2_h262_stream_transport_gate.sv`, which first appeared in `a559d43` and belongs to the elementary-stream path rather than the Program Stream path, and it carries a plus 0.357 ns global setup improvement that would be lost for no benefit. The motivation is that real DVD media relies on navigation packs, multi-angle interleaving and seamless branching, which are ordinary software problems and unpleasant RTL, and that moving demultiplexing to Linux removes the unresolved missing `MPEG_program_end_code` truncation question entirely while narrowing the fabric toward the decoder that `core.md` names as the project thesis. The elementary-stream ingress path being restored is the original and better-tested one, already present in the top level and previously selected automatically. Commit `058f0a3` never produced a bitstream, because its clean compile reached synthesis in 2 minutes 5 seconds and was terminated by the user during routing at one hour thirteen minutes, so no hardware image or timing data exists for it. Commit `3771f19` performs that revert: the restored top level connects the stream FIFO directly to the transport gate and the decoder as it did before `c4d9631`, the file selector returns to accepting `M2V` only because the fabric no longer parses Program Streams, and the two clock and reset connections added by `2dc52d7` are re-applied to the retained transport gate. No dangling reference to the demux, its systems error codes or its PTS signals remains anywhere in the sources or in `files.qip`. The focused cadence profiler test passes at schema four with checksum `e82b643d` and the transport gate test retains its sixteen-byte sticky drain. Quartus Analysis and Synthesis succeeds in 1 minute 54 seconds with zero errors and one hundred thirty-five warnings, and register count falls from 49,784 to 49,295, returning 489 registers to the device. The full compile then succeeded with zero errors in 27 minutes 26 seconds, of which the fitter took 25 minutes 16 seconds, a decisive improvement over the abandoned `058f0a3` route that was still running at one hour thirteen minutes. It uses 35,495 ALMs of 41,910, down from 35,932 at `2dc52d7`, with 52,845 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks unchanged, and produced a 4,218,380-byte RBF with SHA-256 `983a8a286ad89f8ad7885b9cc5c9ccdc7b7a1005cc5722960d882456c930c798`. That image is not usable: the decoder clock misses setup at minus 0.060 ns with total negative slack of minus 0.061 ns across two violated paths of fifty, a regression from the plus 0.572 ns held at `2dc52d7` even though this build carries less logic, which is cold-route variance at eighty-five percent occupancy rather than an effect of the revert. Every other category is positive, including plus 0.244 ns HDMI setup, plus 0.620 ns host bridge setup, plus 6.959 ns video setup and positive hold, recovery, removal and pulse width throughout. Both violated paths run from `mpeg2_h262_reference_word_cache` into `mpeg2_h262_b_bidirectional_raster_engine` inside modules named as probes that in fact instantiate the decode pipeline, and the contributing `wide_seen` term is a mode-select control rather than telemetry, so gating diagnostics would not remove either path.

#### Next Steps:

Retry closure with fitter seed ten, which is the established remedy in this log for a single marginal path and was used at entry 319 to close a seed-sensitive boundary by moving from seed eight to seed nine, and treat the violation as structural rather than seed-sensitive only if two or three seeds fail in succession, in which case the reference cache to bidirectional engine path is registered properly instead. Once a seed closes timing, confirm on MiSTer that every raw elementary-stream regression decodes exactly as before with unchanged picture and swap counts, zero decoder errors and clean terminal completion, and record the accepted RBF hash, because that image becomes the byte-identical reference for the following cycle. That next cycle deletes the twenty-five source files Quartus never compiles, which also resolves all seven duplicate module definitions, and is gated on producing an RBF whose SHA-256 matches the accepted one exactly. A measured cycle then gates the remaining live diagnostic modules behind a compile-time parameter and reports the area, timing and fitter-runtime deltas against the 25 minute 16 second baseline established here, after which the 0.7.0 plan is re-baselined. Presentation work then resumes: a 90 kHz system time clock in fabric as a fractional accumulator anchored to the 24.576 MHz audio domain that `sys/audio_out.sv` already uses, fed picture timestamps supplied by the HPS rather than extracted in fabric, retaining free-running cadence for streams presented without timestamps, followed by the PCM sink with its elastic FIFO and underrun telemetry, then clean-build release qualification and the `v0.7.0` pre-release tag. Both of those cycles require a small throwaway HPS-side harness to inject synthetic timestamps and a test tone, since no daemon exists to supply them. Version 0.7.0 remains a single RBF containing no audio decoder.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h222_program_stream_demux.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h222_program_stream_demux.sv
- tools/streams/tb_h222_program_stream_demux_file.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 358 COMMIT Unreleased 058f0a3 2026-08-22T22:22:14-07:00

#### Coming From:

Unreleased 2dc52d7

#### Purpose:

Capture validated 33-bit video PTS values, associate them with the first H.262 picture start that begins in each selected PES packet, and expose the result through passive hardware telemetry without changing presentation cadence.

#### Outcome:

Commit `058f0a3` extends the bounded Program Stream demux to reconstruct the five-byte 90 kHz PTS after its existing prefix and marker validation, clears the picture-start match register at every PES payload boundary so a prefix cannot be borrowed from the preceding packet, and pulses a single-cycle association only when the first complete `0x00000100` picture start begins inside a packet that carried a PTS. Raw elementary streams and selected PES packets without PTS retain their exact byte path. The previously reserved zero bits of the existing 38-word cadence snapshot now carry an eight-bit saturating association count and the complete latest 33-bit PTS across words eighteen, nineteen and thirty-five, preserving the overlay dimensions, schema, checksum, scheduler state and every existing diagnostic field; the RTL packing and the `decode_hardware_cadence.py` unpacking were verified consistent field by field. Every focused simulation passes: the demux unit test proves raw replay, pack and PES extraction under backpressure and error codes two, five, nine and ten; the cadence profiler retains schema four and checksum `e82b643d`; and the transport gate retains its sixteen-byte sticky drain. A real 1,447,940-byte FFmpeg Program Stream was validated against an independently written H.222.0 clause 2.5 reference extractor that shares no code with the RTL, and the RTL reproduced it exactly at 1,430,191 payload bytes, byte-identical to the source elementary stream, with seventy-seven PTS associations and a latest PTS of `77ef2`. One apparent discrepancy was resolved rather than accepted: FFprobe reports seventy-nine frames carrying PTS, but only seventy-seven PES packets carry one in the actual bytes, the remaining two values being FFmpeg reorder interpolations rather than stream-carried timestamps. A separate pre-existing behaviour was identified and confirmed unchanged at `2dc52d7`, so it is not a regression of this commit: the demux raises truncation error ten for any Program Stream that ends without an `MPEG_program_end_code`, even when every pack and packet structure completes exactly at end of file, which the FFmpeg VOB muxer does not emit by default. No FPGA image exists for this commit. The local incremental database was deliberately wiped for a from-scratch compile, which reached synthesis success with zero errors and one hundred thirty-five warnings and then entered routing before being terminated by the user at forty minutes against a documented twelve to fourteen minute clean-build history; it reported zero Quartus errors at termination and was an abandoned run, not a build failure. The complete accepted `2dc52d7` build state remains preserved outside the repository.

#### Next Steps:

Restore the preserved `2dc52d7` database and build `058f0a3` incrementally at seed nine, which is the cadence every accepted cycle in this log has used, since a clean from-scratch compile is required only at release qualification and its cost has grown sharply as the device passes eighty-six percent of available logic. Require all timing categories positive and compare decoder setup against the preserved plus 0.572 ns baseline, then verify on MiSTer that the five-second Program Stream reports the independently expected seventy-seven associations and latest PTS `77ef2` while retaining one hundred twenty pictures, one hundred nineteen swaps, zero errors and clean terminal completion. Treat the growing fitter runtime as evidence worth watching, because a fit this congested may not hold decoder setup margin. Decide separately, outside this cycle, whether the truncation error on a missing program end code should remain an error or become a tolerated clean end, since it rejects otherwise well-formed muxer output. If accepted, the following cycle will carry associated PTS through frame ownership and add an anchored presentation clock before enabling timestamp-driven swaps.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h222_program_stream_demux.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h222_program_stream_demux.sv
- tools/streams/tb_h222_program_stream_demux_file.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 357 COMMIT Unreleased 2dc52d7 2026-08-22T21:53:25-07:00

#### Coming From:

Unreleased c4d9631

#### Purpose:

Break the route-dominated fatal-error feedback through compressed ingress with a registered sticky transport-fault boundary while leaving clean-stream decode data unchanged.

#### Outcome:

Commit `2dc52d7` adds one sticky decoder-clock fault register inside the existing stream transport gate, breaking the route-dominated combinational path from B replay diagnostics through compressed ingress into the P parser while leaving clean-stream bytes and ready-valid backpressure unchanged; a newly detected fatal event begins fail-open draining on the following clock and remains latched until reset. The focused transport-gate test proves clean combinational flow, one-cycle fault capture, sixteen-byte sticky drain and reset recovery; Program Stream unit and real-file extraction tests remain exact, and reusable B-prediction and multi-slice decoder soaks pass with zero errors. The incremental seed-nine Quartus 17.0.2 build completes with zero errors and improves global setup from plus 0.018 ns to plus 0.375 ns and decoder setup from plus 0.026 ns to plus 0.572 ns, with plus 7.280 ns video setup, plus 0.246 ns hold, plus 4.355 ns recovery, plus 0.573 ns removal and plus 1.122 ns pulse width. It uses 35,932 ALMs, 52,421 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks; the 4,231,288-byte RBF has SHA-256 `d4f19c0d35cf972b34cafdc41c51571f937974c1b05d10fa2cfa6af3fb5658ee`. Direct MiSTer qualification passes B prediction, repeated multi-slice, the 120-picture Program Stream and the 360-picture squirrel stress with zero decoder errors, sequence end, presentation completion and quiet terminal state, including the established odd-byte transport pad and eight-bit counter-wrap conventions. Because the strict decoder audit has no violated paths and gains plus 0.546 ns over the preserved baseline, the user-authorized clean fallback is unnecessary; the exact incremental build is preserved outside the repository, installed persistently and retrieved byte-for-byte from the MiSTer.

#### Next Steps:

Treat this exact image as the accepted timing-hardened Program Stream boundary and retain the preserved `c4d9631` build as a rollback point. The more invasive registered P/B work path is not justified while decoder setup remains comfortably positive; proceed with validated PES timestamp capture and PTS-driven presentation scheduling as a separate bounded cycle, retaining raw elementary-stream compatibility, the diagnostic architecture and the full timing and hardware gates.

#### Files Modified:

- MediaPlayer_top_00.svh
- rtl/mpeg2_new/mpeg2_h262_stream_transport_gate.sv
- tools/streams/tb_h262_stream_transport_gate.sv

#### Status:

- [x] Built
- [x] Passed

---
## 356 COMMIT Unreleased c4d9631 2026-08-22T20:42:22-07:00

#### Coming From:

Unreleased f5e3b83

#### Purpose:

Add a bounded H.222.0 MPEG-2 Program Stream and video PES ingress layer while preserving raw elementary-stream playback.

#### Outcome:

Commit `c4d9631` places a bounded ready-valid H.222.0 parser between the accepted 32 KiB input FIFO and unchanged H.262 decoder, auto-detects MPEG-2 Program Streams from their initial pack start code, and otherwise replays the four probe bytes before exact raw `.m2v` pass-through. It validates MPEG-2 pack fixed fields and stuffing, skips declared system headers and non-selected packets, selects the first `0xE0` through `0xEF` video stream ID, validates bounded MPEG-2 PES optional headers and timestamp markers, emits only video payload, distinguishes program end, and reports malformed or truncated systems input without adding bulk storage. Focused Icarus tests prove raw replay, pack and PES extraction under backpressure and error codes two, five and ten; a real 1,423,364-byte FFmpeg Program Stream extracts and emits the exact 1,404,944-byte source payload in both software and RTL. Reusable Verilator runs retain exact B-prediction, multi-slice and five-second squirrel results. The incremental seed-nine Quartus 17.0.2 image reproduces byte-for-byte after a temporary diagnostic-counter experiment is reverted by `cf234d7`: it completes with zero errors at plus 0.018 ns global setup, plus 0.026 ns decoder setup, plus 7.114 ns video setup, plus 0.249 ns hold, plus 3.800 ns recovery, plus 0.488 ns removal and plus 1.122 ns pulse width, using 35,335 ALMs, 51,502 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. The 4,221,088-byte RBF has SHA-256 `89f26ed3571e3bf03038025c25508857df54019e1113d0636bd33dfc79542041`. Matched raw and Program Stream MiSTer runs each deliver the same 1,404,944 decoder bytes, 41 reference pictures, 79 B pictures, 120 displayed pictures and 119 swaps with zero errors and clean terminal completion; the four established hardware regressions retain complete reference-plus-B counts and zero errors, including the known odd-byte transport pad and eight-bit display-counter wrap conventions. The exact RBF and visible `STEP2_SQUIRREL_PROGRAM_STREAM.mpg` test are installed and retrieved byte-identically, the full build state is preserved outside the repository, and documentation commit `15ede96` records the new v0.7.0 boundary without changing the protected AI-assisted-development section. Real PTS scheduling, audio decoding, MPEG-1 systems syntax, Program Stream Map interpretation and corruption resynchronization remain deferred.

#### Next Steps:

Preserve this timing-clean Program Stream image as the rollback boundary. As a separate timing-hardening cycle, replace the route-dominated shared P/B replay selection with a one-entry registered ready-valid work packet that carries its selector, motion and residual fields atomically; require randomized stall equivalence, every focused decoder regression, positive timing with materially improved 60 MHz margin and unchanged hardware playback before acceptance. After that boundary is stable, capture validated PES timestamps and connect real PTS-driven scheduling without adding audio or broadening the systems subset in the same change.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h222_program_stream_demux.sv
- tools/streams/tb_h222_program_stream_demux.sv
- tools/streams/tb_h222_program_stream_demux_file.sv

#### Status:

- [x] Built
- [x] Passed

---
## 355 COMMIT Unreleased f5e3b83 2026-08-22T20:39:28-07:00

#### Coming From:

Unreleased f5e3b83

#### Purpose:

Record final user visual acceptance of the native 30000/1001 and exact-30-fps v0.7.0 cadence controls.

#### Outcome:

The user watched the correctly installed `TEST_2997.m2v` and `TEST_30.m2v` controls on the connected MiSTer and reports that both look identical and perfect. The user cannot reliably perceive the approximately 0.1 percent difference between the two rates over these short samples and explicitly accepts the direct hardware cadence measurements as the authoritative distinction. This completes human visual acceptance alongside Entry 354's exact scheduler proofs, positive timing, complete picture counts, clean terminal state, zero decoder errors and established four-stream hardware regression pass. The earlier manual file-copy issue affected only curl's relative FTP destination under `/root`; the automated hardware runner used absolute FTP commands and its qualification evidence remains valid, while the visible SD-card RBF and test files are now checksum-verified under `/media/fat`.

#### Next Steps:

Treat native frame-rate codes one through five as the accepted progressive cadence baseline for v0.7.0 and begin the separately bounded H.222.0 Program Stream pack and PES ingress milestone without changing raw elementary-stream compatibility.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 354 COMMIT Unreleased f5e3b83 2026-08-22T19:44:58-07:00

#### Coming From:

Unreleased 6cfad2c

#### Purpose:

Add exact native 30000/1001 and 30-fps presentation cadence as the first substantive v0.7.0 milestone.

#### Outcome:

Commit `f5e3b83` extends the accepted presentation accumulator and cadence profiler to H.262 frame-rate codes four and five using exact reduced `30000/1001` and exact 30-fps ratios, while leaving decode order, ownership, ingress, the 60 MHz decoder clock and diagnostic architecture unchanged. Focused scheduler proofs produce exactly 599 and 600 presentations across matching 1,206-window trials and verify safe fractional-scale reseeding; profiler verification, Verilator lint and the established raster regressions pass. The incremental seed-nine Quartus 17.0.2 build completes with zero errors and positive timing at plus 0.184 ns global setup, plus 0.279 ns decoder setup, plus 7.404 ns video setup, plus 0.241 ns hold, plus 3.666 ns recovery, plus 0.758 ns removal and plus 1.122 ns pulse width. It uses 34,975 ALMs, 52,068 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks; the 4,200,652-byte RBF has SHA-256 `98c73c1b23499e5461fa789b3b77fbf59d798e957b9f7e9357bf6d932009a615`. Direct MiSTer controls identify rate codes four and five correctly, present every picture, terminate cleanly and report zero decoder errors; the 29.97-fps control measures 29.912 fps, while the exact-30 control demonstrates the expected cadence after finite startup delay. The accepted P skip/motion, B prediction, repeated multi-slice and 15-second squirrel hardware gates all retain complete decode and presentation counts, zero decoder errors and zero cadence outliers, including the established odd-byte transport pad and eight-bit counter wrap cases. The exact RBF and both visual rate controls were installed and retrieved byte-for-byte identical, and documentation commit `3d3ce2c` records the active v0.7.0 status without changing the published v0.6.0 qualification.

#### Next Steps:

Have the user visually compare the installed 29.97- and exact-30-fps controls. Preserve this timing-clean 408-RAM-block build as the first accepted v0.7.0 implementation boundary, then begin the approved H.222.0 Program Stream pack and PES ingress work as a separate cycle without disturbing raw elementary-stream playback.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 353 COMMIT Unreleased 5ab290d 2026-08-22T19:30:00-07:00

#### Coming From:

Unreleased 6cfad2c

#### Purpose:

Audit the controlled reference library for the immediate v0.7.0 cadence and MPEG-2 Program Stream, PES and timestamp work.

#### Outcome:

Commit `5ab290d` reduces `core-reference.md` from 2,071 to 443 lines while preserving and indexing all 26 established H.262 decoder records. It removes the premature USB, optical-drive, HDMI, CD/VCD and broad future-format catalogs, and replaces the oversized DVD, filesystem, CSS and audio sections with concise deferred source boundaries. It adds H262-027 for exact 24000/1001, 24, 25, 30000/1001, 30, 50, 60000/1001 and 60 frame-rate signalling plus 11 H.222.0 records covering Program Stream packs and termination, SCR and pack stuffing, system headers, bounded Program Stream PES packets, stream IDs, optional-header flags, PTS/DTS units and wrap, H.262 timestamp association and reorder timing, Program Stream Maps and data alignment. The audit also identifies the official freely available H.222.0 (06/2021) text as the consulted baseline while retaining H.222.0 (04/2025) as the current paywalled edition whose delta must be checked before a v10 conformance claim. All eight YAML blocks parse, every active record has an explicit source identifier and exact clause/table reference, all 38 record IDs are unique and indexed, and the required `core-syntax.md` audit passes with no format or policy conflict.

#### Next Steps:

Use H262-027 when extending cadence beyond the accepted native-24 path. Use H222-001 through H222-011 as the controlled starting point for Program Stream, PES and real timestamp work, and recheck the H.222.0 2025 edition delta before making a current-edition conformance claim. Restore detailed DVD, filesystem, CSS, audio or Transport Stream references only when one of those milestones is explicitly approved.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---
## 352 COMMIT Unreleased 6cfad2c 2026-08-22T18:55:40-07:00

#### Coming From:

Unreleased 902f367

#### Purpose:

Restore the accepted seed-nine ALM packing setting after the isolated high-effort experiment increased logic and reduced decoder timing margin.

#### Outcome:

Commit `6cfad2c` changes only `ALM_REGISTER_PACKING_EFFORT` from the rejected `HIGH` value back to the accepted `MEDIUM` value. The resulting `MediaPlayer.qsf` is byte-equivalent to accepted source commit `873a962`, preserving seed nine, all decoder RTL and the complete diagnostic architecture. The connected MiSTer was never changed by the rejected experiment and still held the exact 4,212,728-byte accepted seed-nine RBF; retrieving it reproduced SHA-256 `96c7e815ac2f5d47501184b2da07c7f1aef824ed4f689c2c70998cafc88adb0a`, and that verified image has replaced the rejected build in local `output_files` without another upload.

#### Next Steps:

Treat the accepted medium-packing seed-nine source and RBF as restored. Do not retry the global high-packing setting; continue logic-reduction work only under a separately approved boundary, with repeated MPEG lookup-table storage as the next candidate and the complete diagnostic architecture retained.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
