## 329 COMMIT Unreleased 374ef38 2026-08-22T04:33:13-07:00

#### Coming From:

Unreleased b426ba4

#### Purpose:

Deliver wide MiSTer file transfers without per-word software stalls by replacing the serializer with a native 16-bit-write and 8-bit-read asynchronous FIFO.

#### Outcome:

Commit `374ef38` removes the per-word serializer and uses Intel's native `dcfifo_mixed_widths`, retaining exactly 32 KiB while accepting consecutive 16-bit MiSTer transfers and presenting ordered 8-bit decoder bytes. The actual Intel behavioral primitive test proves low-byte-first ordering, three back-to-back words, read-side empty and asynchronous reset; transport drains sixteen bytes, the scheduler preserves exact 24 and 25 fps cadence with a minimum two-window gap, and profiler schema four passes with checksum `e82b643d`. The exact quality-six dense stream passes the full raster replay at 134,979,997 cycles with all 1,430,191 source bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental seed-twelve Quartus build completes in 12 minutes 55 seconds with zero errors and positive timing at plus 0.049 ns global and decoder setup, plus 7.752 ns video setup, plus 0.243 ns hold, plus 3.800 ns recovery, plus 0.613 ns removal and plus 1.122 ns pulse width. It uses 35,146 ALMs, 51,998 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,463,616-byte RBF has SHA-256 `566ecf44d65c9d483be247ae942280d23269b7100ce0d75ef3b8a5bc4bdf2dbc`, matches after persistent installation and needs no clean rebuild. After rebooting the MiSTer to clear Entry 328's wedged loader, the five-second hardware run presents all 120 pictures in 4.989397 seconds at 23.850578 fps with zero errors and zero gap outliers; its 1,430,192 accepted-byte count is the expected single padding byte for the odd-length source. The full 7:15-through-7:30 run accepts exactly 2,603,570 bytes, reaches sequence end and terminal quiet, decodes 121 reference plus 239 B pictures for all 360 pictures, and reports zero errors and zero gap outliers across the former 7:22 failure. Its eight-bit display and swap counters wrap to 104 and 103 as expected. The user watches the ordinary clip and reports that the issue appears fixed, pending repeated visual confirmation.

#### Next Steps:

Replay the ordinary 7:15-through-7:30 clip as often as the user needs to confirm the wooden-spike motion visually, then rerun the ten-minute Big Buck Bunny baseline with the accepted artifact. Preserve the cadence overlay as a diagnostic tool but treat its eight-bit display/swap counter wrapping and odd-length WIDE padding as acquisition-validator limitations rather than decoder failures. Investigate reducing the design's 538-of-553 RAM-block occupancy separately, without shrinking buffers whose capacity is now proven necessary for smooth dense MPEG-2 transfer.

#### Files Modified:

- rtl/mpeg2_stream_fifo.sv
- tools/streams/tb_mpeg2_stream_word_unpacker.sv

#### Status:

- [x] Built
- [x] Passed

---
## 328 COMMIT Unreleased b426ba4 2026-08-22T04:17:21-07:00

#### Coming From:

Unreleased 76326a1

#### Purpose:

Find a timing-clean placement for the proven wide-ingress design by retrying its incremental Quartus fit with seed twelve.

#### Outcome:

Commit `b426ba4` changes only the fitter seed from eleven to twelve and reuses synthesis as intended. The incremental build completes in 11 minutes 58 seconds with zero errors and positive timing at plus 0.331 ns global setup, plus 0.350 ns decoder setup, plus 8.286 ns video setup, plus 0.252 ns hold, plus 3.950 ns recovery, plus 0.800 ns removal and plus 1.122 ns pulse width. It uses 34,883 ALMs, 51,966 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,449,372-byte RBF has SHA-256 `d4d31f23f9d4405c070acc589fcbf7fcb059164b6dabd51bf7b4d96aad1c31c5`, verifies after persistent installation and proves seed twelve is a timing-clean placement. Hardware then exposes a functional ingress flaw before telemetry can run: the word unpacker asserts host wait for every accepted 16-bit word while emitting its upper byte. Although that pause lasts only one 20 MHz FPGA clock, it forces the MiSTer file loader through a software wait/retry round trip for every two bytes, so the 1,430,191-byte control does not finish loading within the acquisition window and the screenshot command cannot execute. The artifact is therefore not passed despite clean timing.

#### Next Steps:

Keep timing-clean seed twelve and replace the per-word serializer with the FPGA vendor's native mixed-width asynchronous FIFO, writing complete 16-bit host words and reading ordered 8-bit decoder bytes while asserting host wait only when the reservoir is genuinely full. Simulate the actual primitive model for byte order, consecutive words, full backpressure and reset, then rerun the focused and exact-stream regressions and build incrementally. Accept only positive timing and a real hardware load that consumes all bytes, reaches terminal quiet with zero errors and removes the 7:22 outliers.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 327 COMMIT Unreleased 76326a1 2026-08-22T03:54:46-07:00

#### Coming From:

Unreleased a25d772

#### Purpose:

Prevent host-transfer starvation in the 7:22 squirrel burst by carrying two compressed bytes per MiSTer file-I/O transaction while preserving the decoder's byte stream.

#### Outcome:

Entry 326's full 7:15-through-7:30 hardware capture localizes the visible defect to display ordinals 175, 176 and 178, exactly the user's 7:22 interval, with gaps of 149.213 ms, 66.317 ms and 82.896 ms. Commit `76326a1` enables the local MiSTer framework's standard `WIDE=1` file-transfer mode and adds a write-domain unpacker that emits the lower-addressed byte before the upper byte into the unchanged 32 KiB asynchronous FIFO while applying host wait across the second byte and downstream backpressure. The focused unpacker test proves exact byte order, consecutive transfers, reset and a three-cycle stalled high byte; transport drains all sixteen control bytes, the scheduler retains exact 24 and 25 fps cadence with a minimum two-window gap, and profiler schema four passes with checksum `e82b643d`. The quality-six dense stream passes the full raster replay at 134,979,997 cycles with all 1,430,191 bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental seed-eleven Quartus build then completes in 14 minutes with zero errors, using 34,827 ALMs, 51,970 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks, but is rejected because the 60 MHz decoder clock misses setup by 0.694 ns with total negative slack 12.266 ns. Video setup remains plus 8.184 ns, hold plus 0.260 ns, recovery plus 4.139 ns, removal plus 0.637 ns and pulse width plus 1.122 ns. The rejected 4,461,408-byte RBF has SHA-256 `0afac0e312bf7280932107c4210c9bce2c5b68ddcab898ffa6623c29c3a3d55b` and is not installed, so hardware behavior is not yet measured.

#### Next Steps:

Keep the functionally proven wide ingress unchanged and retry only the fitter with seed twelve because the source change disturbed the previously placement-sensitive 60 MHz decoder paths while every non-setup category remains positive. Rebuild incrementally and accept only zero errors with positive global, decoder, video, hold, recovery, removal and pulse-width timing. If seed twelve closes, verify and install the exact RBF, then rerun both the five-second quality-six control and full 7:15-through-7:30 hardware capture, requiring zero errors and no outliers at ordinals 175 through 178 before asking the user to inspect 7:22. If it does not close, return the decoder to its proven 54 MHz rate rather than repeatedly fitting a clock increase that hardware did not materially improve.

#### Files Modified:

- MediaPlayer_top_00.svh
- rtl/mpeg2_stream_fifo.sv
- tools/streams/tb_mpeg2_stream_word_unpacker.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 326 COMMIT Unreleased a25d772 2026-08-22T03:35:21-07:00

#### Coming From:

Unreleased a5a42f9

#### Purpose:

Find a timing-clean placement for the unchanged 60 MHz decoder design by retrying its incremental Quartus fit with seed eleven.

#### Outcome:

Commit `a25d772` changes only the fitter seed from ten to eleven and reuses synthesis as intended. The incremental Quartus build completes in 13 minutes 10 seconds with zero errors and positive timing at plus 0.296 ns global setup, plus 0.355 ns decoder setup, plus 8.030 ns video setup, plus 0.258 ns hold, plus 2.688 ns recovery, plus 0.677 ns removal and plus 1.122 ns pulse width. It uses 35,065 ALMs, 51,820 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,461,836-byte RBF has SHA-256 `15d5b3144608dbe7148ea4c2a822a714f569413f70657e8f4c8e9f8b4ff373cd` and verifies after persistent installation. Hardware remains correct but does not close the visible defect: the exact quality-six five-second control accepts all 1,430,191 bytes and presents all 120 pictures and 119 swaps with zero errors and terminal quiet, yet retains five cadence outliers and essentially unchanged 22.445238 fps delivery. A full 7:15-through-7:30 capture accepts all 2,603,570 bytes, decodes 239 B and 121 reference pictures for all 360 pictures with zero errors and terminal quiet; its eight-bit display counters wrap to 104 pictures and 103 swaps, while the three largest outliers occur at ordinals 175, 176 and 178, exactly 7.3 seconds after the clip begins and therefore at the user's 7:22 scene. Those gaps last 149.213 ms, 66.317 ms and 82.896 ms, and the largest snapshots show an empty FIFO while the decoder is ready, confirming compressed-input starvation rather than picture loss or I-frame-only presentation.

#### Next Steps:

Keep the timing-clean seed-eleven fit and 60 MHz decoder, but treat the squirrel defect as not passed. Enable the MiSTer `hps_io` interface's standard 16-bit file-transfer mode and serialize each accepted little-endian word into the existing 8-bit, 32 KiB asynchronous FIFO so each host transaction carries two compressed bytes without increasing the design's 97-percent RAM-block usage. Prove byte order, backpressure and consecutive-word handling in a focused simulation, rerun transport, scheduler, profiler and exact-stream regressions, build incrementally with seed eleven and require all timing categories positive, then rerun both the five-second quality-six control and the full 7:15-through-7:30 hardware capture before asking the user to inspect 7:22 again.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 325 COMMIT Unreleased a5a42f9 2026-08-22T03:17:24-07:00

#### Coming From:

Unreleased e5e7d86

#### Purpose:

Close the remaining dense-scene presentation deficit by raising the decoder and DDR service clock from 54 MHz to 60 MHz without changing video cadence.

#### Outcome:

Entry 324 proves that compressed-input restart latency was real but not the only bottleneck. Enlarging the FIFO improves the exact quality-six squirrel control from 20.993581 to 22.417636 fps and reduces its worst display gap from 182.371 ms to 132.634 ms, yet seven cadence outliers remain. The new largest threshold snapshot has FIFO data pending while the decoder is not ready, so further input buffering cannot close the deficit, and the fitted design already consumes 538 of 553 RAM blocks. Commit `a5a42f9` changes only the decoder and DDR service PLL output from 54 MHz to an exact 60 MHz while preserving the independent 40 MHz video clock, recalibrates profiler time units and thresholds from 54,000 to 60,000 kHz, and updates the timing extractor and profiler regression accordingly. Transport and native-rate scheduler tests remain exact, and profiler schema four passes with checksum `e82b643d`. The incremental seed-ten Quartus build finishes in 13 minutes 20 seconds with zero errors, using 34,990 ALMs, 51,852 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. Hold is plus 0.262 ns, recovery plus 3.820 ns, removal plus 0.789 ns and pulse width plus 1.122 ns, but the 60 MHz decoder clock misses setup by 0.073 ns on two paths with total negative slack 0.114 ns. The rejected 4,457,632-byte RBF has SHA-256 `fcc971e39ea20399839070c13b31d34eba9dbdcde7a7e19685e862d21fad49aa` and is not installed.

#### Next Steps:

Retry the unchanged 60 MHz design with fitter seed eleven because the seed-ten miss is only 0.073 ns and all non-decoder categories are positive. Rebuild incrementally and accept only zero errors with positive global, decoder, video, hold, recovery, removal and pulse-width timing. If the fit closes, verify and install the exact RBF, rerun the quality-six 120-picture hardware control, and require all 1,430,191 bytes, 120 pictures and 119 swaps, zero errors, terminal quiet and zero cadence outliers before handing 7:15 through 7:30 back to the user. If seed eleven still misses, inspect whether the failing pair shares a narrow combinational source before choosing another seed or a pipeline repair.

#### Files Modified:

- rtl/pll/pll_0002.v
- rtl/pll.v
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 324 COMMIT Unreleased e5e7d86 2026-08-22T02:57:30-07:00

#### Coming From:

Unreleased 25f05dd

#### Purpose:

Prevent dense real-content pictures from starving presentation by replacing the 256-byte HPS-to-decoder FIFO with a practical compressed-stream reservoir.

#### Outcome:

The user confirms the native-rate ending credits are completely smooth, closing the deterministic cadence symptom, but identifies a clean apparent frame skip at 7:22 as the wooden spikes approach. An exact native-rate 7:20-to-7:25 hardware control reproduces the remaining defect with all 1,430,191 bytes accepted, all 120 pictures and 119 swaps eventually presented, no error flags and nine cadence outliers; its three largest display gaps are 182.371 ms, 165.792 ms and 132.634 ms. The two largest threshold snapshots show the decoder ready while the compressed-stream FIFO is empty, and the source around that point retains a normal I/B/B/P order while individual coded pictures abruptly grow to tens of kilobytes. Lowering encode density from quality six to quality ten reduces the stream from 1,430,191 to 948,786 bytes and improves delivered cadence from 20.993581 to 22.684969 fps, but still leaves four outliers as large as 116.054 ms, confirming buffering sensitivity without providing an acceptable conversion-only repair. Commit `e5e7d86` therefore enlarges the asynchronous HPS-to-decoder FIFO from 256 bytes to 32,768 bytes without changing its clock-domain crossing or reset configuration. The exact dense scene passes the full raster replay at 134,979,997 cycles with all 1,430,191 bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental Quartus build completes in 12 minutes 33 seconds with zero errors and positive timing at plus 0.432 ns global setup, plus 1.672 ns decoder setup, plus 8.133 ns video setup, plus 0.243 ns hold, plus 3.551 ns recovery, plus 0.702 ns removal and plus 0.462 ns pulse width. It uses 34,685 ALMs, 51,232 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,454,764-byte RBF has SHA-256 `68274574806ce74331f32f90ea82084b67c40db0f43adea45a9910f0994a5e70` and verifies after persistent installation. Hardware proves the reservoir is beneficial but insufficient: outliers fall from nine to seven, the worst gap falls from 182.371 ms to 132.634 ms and delivered cadence improves from 20.993581 to 22.417636 fps, but the new largest snapshot has compressed data pending while the decoder is not ready, exposing decode throughput as the next binding limit.

#### Next Steps:

Keep the enlarged reservoir because its hardware improvement is measured, but do not treat the squirrel defect as passed. Raise only the decoder and DDR service clock from 54 MHz to the PLL-compatible 60 MHz while preserving the independent 40 MHz presentation raster and its exact native cadence. Update profiler clock units and timeout thresholds so the hardware evidence remains dimensionally correct, update the timing extraction to identify the new period, and require the focused and full regressions before another incremental build. The current fit has plus 1.672 ns decoder slack against the 18.518 ns period, so the 16.667 ns target is close enough to require real post-fit proof rather than assumption; accept and install only a zero-error, fully positive-timing artifact, then require the exact quality-six scene to reach all 120 pictures and 119 swaps with zero errors, terminal quiet and zero cadence outliers.

#### Files Modified:

- rtl/mpeg2_stream_fifo.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 323 COMMIT Unreleased 25f05dd 2026-08-22T02:19:15-07:00

#### Coming From:

Unreleased cc39b46

#### Purpose:

Retry the unchanged native-24-fps design with fitter seed ten after seed nine misses timing only on the standing HDMI framework path.

#### Outcome:

Changing only the reproducible fitter seed from nine to ten closes the standing placement-sensitive HDMI path. The incremental smart-recompile build finishes in 9 minutes 46 seconds with zero errors and positive timing at plus 0.170 ns global setup, plus 1.045 ns decoder setup, plus 7.882 ns video setup, plus 0.248 ns hold, plus 3.441 ns recovery, plus 0.697 ns removal and plus 0.462 ns minimum pulse width. It uses 34,494 ALMs, 51,056 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks. The accepted 4,372,048-byte RBF has SHA-256 `ea31820acc9a8db2bc7cbe95fa1dfa4f1ebbfae79d8b0e4f03a95a4dad73d42d`, is installed persistently as `/media/fat/MediaPlayer.rbf` and verifies byte-for-byte over FTP. Hardware accepts all 1,070,782 bytes of the native-rate control and reports frame-rate code two, exactly 250 displayed pictures, 249 swaps, 85 reference pictures, 165 B pictures, terminal quiet, no error flags and no cadence-gap outliers; 249 measured display intervals span 10.384474 seconds for 23.978103 fps, the expected finite-sample result around the exact 24 fps accumulator. The complete 14,315-picture native stream also verifies after upload with SHA-256 `015c8811932ce8b324af6ccd9e235cd621307aa43fcaf62b413b93badba52de5` and is launched for the user's direct visual comparison.

#### Next Steps:

Have the user judge smooth field pans and the rolling credits in the full native-rate movie, where the former once-per-second repeated-picture hitch should now be absent. Keep the squirrel sequence at 7:20 through 7:25 as a separately attributable transport and decode-throughput stress case, since removing the deterministic rate-conversion repeats does not remove that scene's measured input burst. Preserve both native and forced-rate movies for an immediate visual comparison if the residual cadence is ambiguous.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---
## 322 COMMIT Unreleased cc39b46 2026-08-22T01:52:41-07:00

#### Coming From:

Unreleased 74cff5b

#### Purpose:

Add exact 24 fps presentation cadence and generate Big Buck Bunny at its native frame rate without duplicated pictures.

#### Outcome:

Commit `cc39b46` adds exact frame-rate-code-two credit to the saturating pixel-clock presentation accumulator while preserving code three and extends cadence outlier capture to both rates. Focused tests deliver exactly 240 native-rate pictures and the existing 250 pictures across the same 603 raster windows with a minimum two-window gap, and profiler schema four retains checksum `e82b5cad` while capturing code-two outliers. The native 250-picture BBB encode has frame-rate code two, maps all 250 source pictures without inserted duplicates and completes all 1,070,782 bytes in the full Verilator raster at 225,134,082 cycles with 74 P pictures, 165 B pictures, 85 reference publications, 249 swaps and zero errors. The existing 25 fps corpus remains exact at 6,519,997 cycles. The complete native stream is 720 by 480, 14,315 pictures, 84,423,309 bytes, SHA-256 `015c8811932ce8b324af6ccd9e235cd621307aa43fcaf62b413b93badba52de5`, frame-rate code two and a valid sequence-end marker. The incremental seed-nine Quartus build finishes in 11 minutes 28 seconds with zero errors and 147 warnings, using 34,391 ALMs, 51,100 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks, but it is rejected because the standing HDMI framework path misses setup by 0.180 ns; decoder and video setup remain positive at plus 1.322 ns and plus 6.621 ns, with hold plus 0.246 ns, recovery plus 3.834 ns, removal plus 1.020 ns and pulse width plus 0.462 ns. The rejected 4,384,288-byte RBF has SHA-256 `e48f74cdab417336e434c81a2a8b6548a880f6f4099879bf8693cc2671bc5a02` and is not installed.

#### Next Steps:

Retry the unchanged design with a new documented fitter seed because seed nine misses only the standing placement-sensitive HDMI framework path. Require positive timing before installing any artifact, then run a short native 24 fps hardware cadence gate and the complete movie so the user can determine whether the exact once-per-second duplicate hitch is gone while keeping the separate 7:20-to-7:25 transport burst under observation.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 321 COMMIT Unreleased 74cff5b 2026-08-22T01:02:36-07:00

#### Coming From:

Unreleased 985ac76

#### Purpose:

Keep the development quiet snapshot open until the scheduler has presented its already-released terminal pending frame.

#### Outcome:

Commit `74cff5b` adds the scheduler's existing `pending_frame_valid` state to the development-only quiet qualification and changes no decoder, scheduler, cadence, display or loading-bar decision. The focused scheduler and profiler regressions pass. The incremental seed-nine Quartus build completes in 12 minutes 23 seconds with zero errors and positive timing at plus 0.053 ns global setup, plus 1.402 ns decoder setup, plus 7.570 ns video setup, plus 0.250 ns hold, plus 4.052 ns recovery, plus 0.537 ns removal and plus 0.462 ns pulse width. It uses 34,507 ALMs, 51,081 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; the 4,416,296-byte RBF has SHA-256 `95862c4ecede2bb20316a24dabc87aaa16f89a94cc9d363ad47573db3f42571d`. Hardware controls finish exactly at 48/47 and 72/71 with zero errors and zero outliers. Two full-stream runs consume all 1,178,034 bytes and finally report the exact 250 pictures, 249 swaps, terminal quiet, no pending scheduler state and zero errors, proving the former early freeze and final-reference drain are fixed. Both full runs record one reproducible startup-only outlier before picture two while the decoder is not ready, 50.952 ms and 50.115 ms respectively; pictures three through 250 contain no outliers, and the user reports visually smooth playback and a safer-looking ending. The exact RBF is installed persistently as `/MediaPlayer.rbf` and verified byte-for-byte over FTP, but release acceptance remains open for the startup gap and the requested full-movie endurance observation. The complete 596.46-second AVI is converted outside the repository to a 720-by-480, 25 fps, 14,911-frame elementary stream with two B frames, 85,680,318 bytes, SHA-256 `10df778a6329b7ab6e3ebda98010b47e4f57ad77f74de3c1a454f95a514383e0` and a valid sequence-end marker; it is uploaded and launched on the MiSTer without screenshot polling for the user's direct baseline test.

#### Next Steps:

Have the user watch the complete 9-minute-56-second baseline and report any freeze, stutter, corruption, loading-bar stall or abnormal ending. Keep release acceptance open until that endurance result is known and the reproducible startup-only gap is either accepted explicitly or corrected. After the baseline, add the requested simple human-readable Python conversion recipe with plain FFmpeg arguments, no framework and clear actual-output validation, then expand release coverage across supported frame rates, aspect ratios, motion levels, GOP structures, sizes and malformed-input failure behavior.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 320 COMMIT Unreleased 985ac76 2026-08-22T00:37:52-07:00

#### Coming From:

Unreleased 04a532c

#### Purpose:

Release a final reference publication retained during an overlapping B-picture drain when sequence end has already removed its classification barrier.

#### Outcome:

Commit `985ac76` retains sequence end across an active reordered run and applies that terminal permission when the run preserves a concurrently decoded reference as ordinary pending display work. The new focused case fails before the fix and passes after it alongside all prior scheduler orders with a minimum presentation gap of two. Real 48-, 72- and 250-picture Verilator replays consume every byte and retain exact swap counts of 47, 71 and 249 with zero errors; the full stream finishes 1,178,034 bytes at 222,767,587 cycles. The incremental seed-nine Quartus build completes in 13 minutes 52 seconds with zero errors and positive timing at plus 0.330 ns global setup, plus 1.679 ns decoder setup, plus 6.688 ns video setup, plus 0.246 ns hold, plus 3.749 ns recovery, plus 0.697 ns removal and plus 0.462 ns pulse width. It uses 34,285 ALMs, 51,047 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; the 4,400,432-byte RBF has SHA-256 `9b4a3e0ce83b8a145ac53ec915cf9ec1e2a0bb7bf1f7726ff4ec9e9d6fb38d7a`. Hardware controls again pass exactly at 48/47 and 72/71 with zero errors and zero outliers. The full stream remains visually smooth and the user describes its ending as safer; telemetry proves the behavioral fix by changing the final pending reference from unreleased to released, but the quiet snapshot still latches at 249/248 only 1,023 clocks after `presentation_complete`, before the released frame's next cadence window.

#### Next Steps:

Keep the accepted scheduler correction and extend only the development quiet qualification to require that no pending frame remains. Rebuild incrementally and repeat hardware validation so telemetry waits through the final cadence swap instead of sampling the correct release early.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 319 COMMIT Unreleased 04a532c 2026-08-22T00:24:17-07:00

#### Coming From:

Unreleased 385ead5

#### Purpose:

Retry the unchanged terminal cadence snapshot qualification with fitter seed nine after seed eight misses timing only on the standing HDMI framework path.

#### Outcome:

Commit `04a532c` changes only the reproducible Quartus fitter seed from eight to nine. The incremental smart compile skips unchanged synthesis, finishes in 9 minutes 43 seconds with zero errors and closes the seed-sensitive HDMI framework path at plus 0.179 ns global setup; decoder and video setup are plus 1.270 ns and plus 6.459 ns, with hold plus 0.246 ns, recovery plus 4.295 ns, removal plus 0.586 ns and pulse width plus 0.462 ns. The fit uses 34,609 ALMs, 51,269 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; its 4,366,308-byte RBF has SHA-256 `41bf2d21c121204e873b8a09b9b39014364e95b669381a8097ea69595e763587`. Hardware controls remain exact at 48 pictures and 47 swaps and at 72 pictures and 71 swaps, with both reporting terminal quiet, zero errors and zero cadence outliers. The full stream consumes all 1,178,034 bytes, decodes 250 pictures, reaches sequence end and is visually smooth through the authored black ending according to the user, but the corrected quiet snapshot proves one terminal reference remains behind the classification barrier: it reports 249 pictures, 248 swaps, `presentation_complete`, zero errors and zero outliers with `pending_frame_valid` still set.

#### Next Steps:

Preserve the visually accepted seed-nine result but do not install it as final. Add a focused scheduler case for sequence end arriving before an overlapping final reference can leave the classification barrier, then release that already-decoded reference without changing ordinary GOP scheduling and repeat the incremental build and three hardware gates.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 318 COMMIT Unreleased 385ead5 2026-08-22T00:09:56-07:00

#### Coming From:

Unreleased d95baa6

#### Purpose:

Require the development cadence snapshot to wait for terminal presentation completion so the full 250-picture hardware run is not sampled two cadence slots early.

#### Outcome:

Commit `385ead5` adds `presentation_complete` to the development-only quiet qualification and leaves the bounded forced-terminal snapshot path intact. The focused cadence-profiler regression passes its quiet, forced, fatal and no-progress cases with schema-four checksum `e82b5cad`. The incremental Quartus 17.0.2 compile completes in 11 minutes 59 seconds with zero errors and 147 warnings, but the fit is rejected before hardware deployment because global setup is minus 0.105 ns on the standing seed-sensitive HDMI framework clock; decoder and video setup remain positive at plus 0.569 ns and plus 7.555 ns, with hold plus 0.245 ns, recovery plus 3.289 ns, removal plus 0.709 ns and minimum pulse width plus 0.462 ns. Seed eight uses 34,569 ALMs, 51,316 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; its rejected 4,409,220-byte RBF has SHA-256 `502b306668c15f4ba0becdb34313737ccd6f8ccd5140e86885fe25a34bdfdb0c` and was not uploaded.

#### Next Steps:

Retry the unchanged design incrementally with fitter seed nine, explicitly recording that any timing closure is seed-dependent. Only a build with zero errors and positive global, decoder, video, hold, recovery, removal and pulse-width slack may proceed to the same three hardware clips.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 317 COMMIT Unreleased d95baa6 2026-08-21T23:50:22-07:00

#### Coming From:

Unreleased 3c80bef

#### Purpose:

Implement exact B-picture f_code five motion support so the 250-picture compatibility stream no longer leaves an unowned B transaction.

#### Outcome:

Commit `d95baa6` extends the B parser and raster path from f_code one through four to exact f_code five support. Predictors, residual reconstruction and emitted forward/backward vectors are signed 9-bit values, the raster motion record is widened from 34 to 38 bits, and an explicit B transport qualifier distinguishes direction records from ordinary P residual sample indices while the vectors travel independently of the 16-bit residual sideband. The deterministic range generator now exercises one through five, including signed 9-bit wraparound, and FFmpeg verifies both authored B pictures pixel-exact; the parser-window and residual-streaming regressions pass with zero errors and the latter retains its exact 1,286,071-cycle Icarus count. The canonical fixed-count 72-picture raster remains exactly 6,519,997 cycles, the scheduler cadence remains one, three and two with a minimum presentation gap of two, and real 48-, 72- and 250-picture Verilator runs consume every byte and terminate with zero decoder, raster, ownership or presentation errors. The 250-picture run finishes all 1,178,034 bytes with 74 P pictures, 165 B pictures, 85 reference publications and 249 display swaps, proving both the former picture-80 stop and the terminal non-quiet state are gone in simulation. The loading bar and scheduler behavior are unchanged.

#### Next Steps:

Build `d95baa6` incrementally as requested without clearing Quartus compilation databases, require zero errors and positive timing, install the exact RBF on the connected MiSTer, and run the 48-, 72- and 250-picture hardware clips. Accept the repair only if each consumes every byte, presents every picture through terminal quiet, reports zero error flags and preserves the accepted GOP cadence; retain the loading bar as the diagnostic requested by the user.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/generate_test_b_f_code_range.py
- tools/streams/h262common.py
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 316 COMMIT Unreleased 3c80bef 2026-08-21T22:34:28-07:00

#### Coming From:

Unreleased 3c80bef

#### Purpose:

Review the user's recorded 72-picture playback and classify the loading-bar rate changes observed after the GOP-stutter repair.

#### Outcome:

The 11.712-second 59.94-fps phone recording contains two complete plays of the 72-picture stream. The MiSTer loading overlay covers the principal motion and the uncovered opening content changes too little for the recording to provide frame-accurate cadence proof by itself, but both passes advance through all source content without an obvious prolonged freeze at the former 24-picture GOP boundaries; this supports the user's qualified visual assessment that the stutter is gone and agrees with Entry 315's stronger hardware telemetry of 72 pictures, 71 swaps and zero cadence outliers. The loading-bar acceleration and deceleration is explained by the current transport rather than by display cadence: the standard HPS file transfer is stopped through `ioctl_wait` whenever the core's 256-byte dual-clock input FIFO is full, while decoder, prediction, persistence and presentation work consume bytes at variable rates. The bar therefore represents accepted file-byte progress and naturally advances in bursts as the FIFO fills and drains, with GOP-correlated rate changes expected because reference and B-picture work impose different backpressure. It is not presently a functional bug because progress remains monotonic, all bytes are accepted and display cadence remains legal; reversal, failure to complete or a coincident display outlier would change that classification.

#### Next Steps:

Accept the Entry 315 GOP-stutter repair and retain the bursty loading bar as a documented transport and user-interface characteristic rather than changing the scheduler again. Proceed separately to the 250-picture non-quiet terminal presentation state, preserving incremental builds and the accepted 48- and 72-picture cadence gates for every candidate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 315 COMMIT Unreleased 3c80bef 2026-08-21T21:54:45-07:00

#### Coming From:

Unreleased 9367b7e

#### Purpose:

Defer a queued B-picture header until the already-admitted new-GOP I reference publishes instead of treating that transient ordering as a fatal presentation error.

#### Outcome:

Commit `3c80bef` adds one bounded deferred queued-B transaction to the presentation scheduler. When a B header reaches a closed run while the admitted I/P overlap is still open but either its reference publication or a scratch destination is temporarily unavailable, the scheduler consumes and retains that one classification event, asserts presentation backpressure before payload, and completes ordinary queued-generation admission atomically once both resources are safe. Duplicate deferred headers, non-overlap resource exhaustion, promotion conflicts, decode failures and ownership failures remain errors. Focused scheduler verification covers delayed I publication, old-generation retirement, scratch release, atomic promotion and duplicate rejection; the cadence-profiler regression passes, Verilator lint has only standing testbench warnings, the canonical complete raster finishes all 291,641 bytes with 25 pictures and 71 swaps, and the real 72-picture dense-order run finishes all 243,306 bytes with 22 P pictures, 47 B pictures, 25 reference publications and no presentation or ownership error. The requested incremental Quartus 17.0.2 build completes in 12 minutes 15 seconds with zero errors and positive timing at plus 0.633 ns global setup, plus 1.133 ns decoder setup, plus 6.373 ns video setup, plus 0.240 ns hold, plus 3.761 ns recovery, plus 1.210 ns removal and plus 0.462 ns minimum pulse width. It uses 34,525 ALMs and 51,222 registers; the 4,394,724-byte RBF has SHA-256 `2761fa1edf0dff4edfd38b5c33ae191f2e62e5b242606b51c81dffef1e781ccf`. Hardware accepts the repair: the 48-picture clip consumes all 125,948 bytes and displays 48 pictures with 47 swaps at 25.045 fps, while the 72-picture clip consumes all 243,306 bytes and displays 72 pictures with 71 swaps at 24.957 fps; both reach sequence end with zero error flags and zero cadence outliers, eliminating the measured GOP-boundary stutters. The exact RBF is installed persistently as `/MediaPlayer.rbf`, verified byte-for-byte over FTP, and restored as the active core. The additional 250-picture run still does not publish terminal telemetry within 120 seconds, confirming that its previously deferred non-quiet terminal state remains separate from the now-fixed GOP stutters.

#### Next Steps:

Have the user visually confirm smooth playback on the installed core. Then treat the 250-picture non-quiet terminal state as a separate presentation-finalization task: capture or reproduce its terminal bank and scheduler ownership state without changing the accepted GOP repair, add a focused terminal regression, and continue to use incremental builds for every hardware candidate.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 314 COMMIT Unreleased 9367b7e 2026-08-21T21:33:01-07:00

#### Coming From:

Unreleased f3f2395

#### Purpose:

Capture the rejected I-overlap build's hardware state when playback terminates before the MPEG sequence-end marker.

#### Outcome:

Commit `9367b7e` leaves decode, scheduling, frame ownership and presentation behavior untouched while allowing the schema-four cadence profiler to snapshot after either a sticky fatal error or one decoder-clock second without byte, persistence, display, prediction or writer progress. Focused Icarus verification covers quiet, forced-terminal, fatal and no-progress capture with valid checksums, and Verilator lint passes with only standing testbench warnings. The incremental Quartus 17.0.2 build completes in 12 minutes 41 seconds with zero errors and positive timing at plus 0.253 ns global setup, plus 1.311 ns decoder setup, plus 7.273 ns video setup, plus 0.248 ns hold, plus 3.619 ns recovery, plus 0.880 ns removal and plus 0.462 ns minimum pulse width. It uses 34,520 ALMs and 51,206 registers; the 4,415,436-byte RBF has SHA-256 `a7e34a96d69a551aab24e042f53ac4bf152b6e3713000d0efc2f31ac52d8919b`. Hardware capture succeeds and proves the rejected Entry 313 behavior is a scheduler fail-stop, not a deadlock or reference corruption: only 84,756 of 125,948 bytes are accepted, 10 references and 15 B pictures complete, 23 pictures and 22 swaps are displayed, cadence remains legal at 24.787 fps with zero gap outliers, and error flags are exactly `0x0200`, the presentation-error bit. The terminal scheduler state retains `overlap_decode_open=1` and `pending_frame_valid=1` after clearing the active run, which identifies the queued B admission failure: the following B header arrived while the new-GOP I overlap was open but before its reference publication was visible, and the scheduler treated that transient absence as fatal. The known-working Entry 312 RBF with SHA-256 `af63bb9c8433247d4b5b54ab511efd12d9e2aaec8cf664e021e48c7b4fcb1b31` was restored on the MiSTer after capture.

#### Next Steps:

Replace the queued-run fail-stop only for this proven transient. When a B header reaches a closed run with `overlap_decode_open` set but no overlap publication yet, latch one deferred queued-B request and assert presentation backpressure after that header so the already accepted I picture may finish publishing without allowing B payload bytes to outrun scratch-bank ownership. Complete the ordinary queued admission atomically when `frame_waiting` or `pending_frame_valid` supplies the I reference, preserve scratch-exhaustion and duplicate-request cases as genuine errors, and add a focused case in which B classification precedes delayed I publication. Keep the Entry 313 I-overlap behavior otherwise unchanged, build incrementally as requested, and require the 48- and 72-picture hardware clips to finish with every byte and picture, zero errors and zero GOP outliers before persistent installation.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 313 COMMIT Unreleased f3f2395 2026-08-21T21:08:56-07:00

#### Coming From:

Unreleased 242d151

#### Purpose:

Allow the I-picture beginning a new GOP to decode through the existing reference-overlap window so the presentation pipeline does not drain at each GOP boundary.

#### Outcome:

Commit `f3f2395` adds an explicit accepted I-picture header event beside the existing P-picture event and allows either supported reference type to open the scheduler's single overlap decode transaction when a B run closes. Focused scheduler, dense publication-order and complete raster simulation pass with zero functional errors, including delayed I publication into the third reference bank, and the canonical 72-picture raster completes 69,999 cycles sooner at 6,519,997 cycles. A fully clean Quartus 17.0.2 build completes with zero errors; the required 54 MHz decoder and 40 MHz video paths have positive setup margins of 1.133 ns and 7.144 ns respectively, although the default whole-design report retains a minus 0.084 ns setup warning on a standing framework path. The 4,411,644-byte RBF has SHA-256 `482afd7eb6b9757408fccbb3ec6f525850d0438f4a17e79dbe2403cc5ba8481c`. Hardware rejects the repair: the 48-picture clip reaches the first GOP boundary near picture 24 and then freezes permanently on the retained frame. Because the stream never reaches its sequence-end marker, schema-four telemetry never snapshots and the automated run correctly reports no valid telemetry rather than a cadence result. The simulation abstraction therefore missed a hardware-only liveness or ownership condition in the new I-overlap path, and this RBF is not accepted or installed persistently.

#### Next Steps:

Capture the hardware failure before attempting another functional repair. Extend the development cadence snapshot so a fatal decoder result or a bounded no-progress timeout can publish telemetry without requiring the sequence-end marker, then reproduce the 48-picture freeze and decode the terminal error flags, scheduler ownership state, accepted-byte position and displayed-picture count. Use that evidence to distinguish a reference-bank collision, a fail-open diagnostic rejection and a true decoder deadlock, restore the known-working diagnostic RBF after capture if necessary, and do not accept or install `f3f2395`.

#### Files Modified:

- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 312 COMMIT Unreleased 242d151 2026-08-21T20:45:10-07:00

#### Coming From:

Unreleased b777f30

#### Purpose:

Capture the exact scheduler and hold state at each GOP-correlated cadence outlier so the visible stutters can be fixed without conflating them with the separate 250-frame terminal failure.

#### Outcome:

Commit `242d151` leaves decoder and scheduler behaviour unchanged and adds schema-four threshold-crossing context to each ranked cadence gap, including the upcoming display ordinal, scheduler word, holds, FIFO, decoder readiness, scratch availability, frame publication and bank state. Focused Icarus and Verilator checks pass, the scheduler regression remains unchanged, and the overlay decoder proves that threshold state is retained even when signals change before the eventual swap. The fully clean Quartus 17.0.2 build completes with zero errors and positive timing at plus 0.577 ns global setup, plus 0.928 ns decoder setup, plus 6.520 ns video setup, plus 0.249 ns hold, plus 3.830 ns recovery, plus 0.694 ns removal and plus 0.462 ns minimum pulse width. It uses 34,571 ALMs, 51,255 registers, 4,040,879 memory bits, 506 RAM blocks and 65 DSP blocks; the 4,350,716-byte RBF has SHA-256 `af63bb9c8433247d4b5b54ab511efd12d9e2aaec8cf664e021e48c7b4fcb1b31`. MiSTer validation accepts every byte and picture with zero error flags: 48 frames has one 4,476,384-cycle or 82.896 ms gap before picture 25, while 72 frames has the same gap before picture 25 and an 8,057,491-cycle or 149.213 ms gap before picture 49. At all three threshold samples the decoder is ready but the FIFO is empty, presentation is complete, and the scheduler has no active or queued run, decode, frame, hold or promotion. Source correlation identifies the GOP-specific admission defect: the non-B header closes the prior B run, but `overlap_decode_open` is enabled only for a P-picture, so the I-picture beginning each new GOP cannot decode through the existing presentation overlap and the pipeline drains before it is admitted.

#### Next Steps:

Propose a narrow scheduler change that allows an accepted I-picture header, as well as the existing P-picture header, to open the one-reference overlap transaction while a closed B run is presented. Prove in focused scheduler and complete raster regressions that the rotating third reference destination cannot overwrite the displayed or prediction-owned banks, then require a clean timing-qualified build and hardware replay with zero outliers at pictures 25 and 49. Keep the 250-frame terminal trigger and terminal repair deferred until the GOP stutters are eliminated.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/run_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 311 COMMIT Unreleased b777f30 2026-08-21T20:05:37-07:00

#### Coming From:

Unreleased 95a0ab1

#### Purpose:

Measure the GOP-correlated stutters and the unresolved 250-frame terminal presentation state with diagnostic-only hardware telemetry.

#### Outcome:

Commit `b777f30` extends the cadence snapshot without changing decode, ownership, scheduling or display decisions. Schema version three retains the existing aggregates, ranks the three largest inter-display-swap gaps with displayed-picture ordinals, counts gaps beyond the 25 fps cadence window, tags quiet versus forced snapshots, and records terminal banks, holds and scheduler flags. Verilator and Icarus lint pass, the focused scheduler regression is unchanged, and the profiler bench proves both quiet and forced snapshot paths. A fully clean Quartus 17.0.2 build completes in 11 minutes 51 seconds with zero errors, zero Critical Warnings and 146 warnings. Every timing category is positive at plus 0.500 ns global setup, plus 1.145 ns decoder setup, plus 6.922 ns video setup, plus 0.247 ns hold, plus 4.331 ns recovery, plus 1.022 ns removal and plus 0.462 ns minimum pulse width. The fit uses 34,258 ALMs, 50,579 registers, 4,040,879 memory bits, 506 RAM blocks and 65 DSP blocks; the 4,394,640-byte RBF has SHA-256 `727ed77da160070fcfca5fb644060b3501f46f4546c0babd5a7f43c2a7451cca`. Hardware confirms the GOP correlation directly: the 48-frame clip completes with zero errors and one 82.896 ms outlier before displayed picture 25, while the 72-frame clip completes with zero errors and two outliers, 82.896 ms before picture 25 and 149.213 ms before picture 49. The full clip again holds the image matching frame 78 but publishes no forced snapshot, proving it stops before `sequence_end_seen` rather than merely failing to drain after sequence end. Hardware automation also exposed that current MiSTer MGL paths are resolved relative to `games/MediaPlayer` and that requesting screenshots during the MGL delay can prevent file injection; absolute paths and early polling produce the black screen independently on both this RBF and the previously proven seed-eight control.

#### Next Steps:

Do not change scheduler behaviour. Obtain approval for one diagnostic correction: let the forced snapshot arm when accepted bytes and display swaps are both stagnant for a bounded interval while compressed input remains pending, without requiring `sequence_end_seen`, and update the hardware runner to use a games-folder-relative MGL path and defer its first screenshot until after file injection and playback. Rebuild and rerun the same three clips; the 48- and 72-frame results must remain exact enough to preserve the measured outlier ordinals, and the full clip must finally expose the byte count, display count, bank mismatch and scheduler flags at its frame-78 hold before any behavioural repair is proposed.

#### Files Modified:

- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 310 COMMIT Unreleased 95a0ab1 2026-08-21T19:55:45-07:00

#### Coming From:

Unreleased 95a0ab1

#### Purpose:

Correct Entry 309's hardware interpretation using the user's continuous observation and the settled LED diagnostic encoding.

#### Outcome:

Entry 309's claim that the 250-frame clip permanently freezes on frame 78 is superseded. The automated runner captured only post-playback still images and aggregate terminal telemetry, so it could not observe transient motion discontinuities or establish the instant at which playback stopped; matching the terminal image to encoded frame 78 identifies the content left in the displayed bank, not when that bank became visible. The user observes the same underlying symptom on all three clips: playback stutters and then continues, once in the 48-frame prefix and twice in the 72-frame prefix, at equal intervals and at the same content positions, with the 250-frame run similar. That count aligns exactly with the generator's 24-frame GOP structure, one internal GOP boundary in 48 frames and two in 72, making the GOP transition the leading correlation but not yet a proven mechanism. The LED reports narrow the terminal states. On 48 frames, USER and POWER steady on with DISK off is clean acceptance. On 72 frames, USER and POWER steady on with DISK blinking eleven is also clean acceptance; DISK eleven is the success-side final-GOP progress marker for future-reference presentation, not an error. On 250 frames, USER and DISK steady off with POWER blinking five means no decoder error latched but acceptance failed because `completed_frame_bank` differs from `display_frame_bank`. The missing 250-frame telemetry therefore reflects a terminal presentation state that never becomes quiet, not proof of a fatal midstream decode or presentation error. The reported 24.04 and 23.54 fps figures are whole-run averages that fold the discrete stutters into one rate and cannot distinguish otherwise normal cadence between them.

#### Next Steps:

Do not change decoder or scheduler behaviour until the discontinuity is measured directly. Extend the observational cadence profiler to record the largest inter-display-swap gaps, the displayed-picture ordinals on each outlier and a count of gaps exceeding the legal 25 fps cadence window, then make it publish a tagged terminal snapshot after a bounded post-sequence delay even when `session_quiet` never asserts. That single diagnostic build should prove whether the pauses occur at displayed pictures 24 and 48, distinguish decode starvation from cadence scheduling, and expose the 250-frame terminal bank and scheduler state. Obtain user approval for this revised diagnostic plan before modifying RTL.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 309 COMMIT Unreleased 95a0ab1 2026-08-21T19:36:06-07:00

#### Coming From:

Unreleased 95a0ab1

#### Purpose:

Hardware-validate the seed-eight build against the 48-frame control, the 72-frame f_code target and the full 250-frame diagnostic clip.

#### Outcome:

The exact `output_files/MediaPlayer.rbf` artifact recorded in Entry 308, SHA-256 `ca2df257334be5f0a73218fbddd9da0f8c28fe9da237fc0f5754d81ab694448d`, passes the functional boundary on the connected MiSTer. The 48-frame control accepts all 125,948 bytes, displays 48 pictures with 47 swaps and 17 references, reports zero error flags and completes telemetry validation at 24.038869 fps. The 72-frame target accepts all 243,306 bytes, displays all 72 pictures with 71 swaps and 25 references, reports zero error flags and completes telemetry validation at 23.539979 fps. Both captured final frames are visually clean, so the Entry 306 selection-gate repair is accepted on hardware and seed eight is a valid deployable fit for it. The full 250-frame clip does not complete: after 35 seconds it has never published the telemetry prefix and permanently holds a visually clean displayed frame. Matching the HDMI capture against all encoded pictures identifies the held image as frame 78, about 3.08 seconds into the 25 fps stream, and a second capture five seconds later is byte identical. This reproduces the separate presentation-path failure already isolated in simulation rather than the old decode halt. A second issue is confirmed independently of that failure: even successful real-content clips deliver only 24.04 and 23.54 fps rather than the target 25 fps, with presentation hold dominating their telemetry.

#### Next Steps:

Characterise the 250-frame failure at the presentation layer by locating the exact module and error code that raise `presentation_error` at simulation byte 310,630, keeping probe, prediction and writer clear as already measured and using hardware frame 78 as the external reproduction boundary. Do not revisit the Entry 306 decode gates, which now pass both simulation and hardware. Once the presentation failure is fixed, rerun these same three hardware clips and then return to the measured sub-25-fps throughput and scratch-pool limit as the next performance boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 308 COMMIT Unreleased 95a0ab1 2026-08-21T18:50:13-07:00

#### Coming From:

Unreleased 6bea8f9

#### Purpose:

Retry the unchanged Entry 306 design with fitter seed eight to determine whether the HDMI PLL timing miss is placement variance.

#### Outcome:

Seed eight closes timing with no RTL change, so `6bea8f9` is deployable for hardware testing through source commit `95a0ab1`, but timing is explicitly recorded as closed by seed rather than by design. A fully clean Quartus 17.0.2 compile from emptied `db`, `incremental_db` and `output_files` completes in 11 minutes 47 seconds with zero errors, zero Critical Warnings and 147 reported warnings. Worst-case setup is plus 0.368 ns on the HDMI PLL clock, recovering 0.473 ns from seed seven's minus 0.105 ns and exceeding seed seven's plus 0.295 ns on Entry 305 by 0.073 ns. Every domain remains positive: decoder setup is plus 1.513 ns against plus 1.030 ns on Entry 307, HPS bridge plus 1.744 ns against plus 1.364 ns and video plus 7.191 ns against plus 6.399 ns. Worst hold is plus 0.246 ns, recovery plus 3.107 ns, removal plus 0.692 ns and minimum pulse width plus 0.462 ns. Placement changes resource estimates without changing the implemented design. Seed eight uses 33,715 ALMs and 49,850 registers against 33,790 and 49,832 on seed seven, while block memory remains exactly 4,040,879 bits and 506 RAM blocks at 92 percent, with 65 DSP blocks. The RBF is 4,378,580 bytes with SHA-256 `ca2df257334be5f0a73218fbddd9da0f8c28fe9da237fc0f5754d81ab694448d`. It remains in `output_files/MediaPlayer.rbf` and was not uploaded automatically. This result confirms the Entry 307 inference that the miss was placement variance, while also confirming the larger warning: a 0.473 ns swing from a seed alone means the HDMI margin is placement-sensitive and is not robust design margin.

#### Next Steps:

Hardware-test `output_files/MediaPlayer.rbf` as the seed-eight build of the Entry 306 functional change. The software evidence remains Entry 306's completed 72-frame run and byte-identical corpus and 48-frame regressions; hardware acceptance is still required before Passed can be checked. After that result is recorded, return to the full 250-frame clip's presentation failure at byte 310,630 by locating the module and code that raise `presentation_error`, with probe, prediction and writer already measured clear, and keep the seed-sensitive HDMI margin as a standing constraint for the planned timing refactor.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 307 COMMIT Unreleased 6bea8f9 2026-08-21T18:39:00-07:00

#### Coming From:

Unreleased 6bea8f9

#### Purpose:

Qualify the Entry 306 gate fixes with a fully clean Quartus build and record that they do not close timing.

#### Outcome:

The commit compiles but fails timing, so it is not deployable as it stands and Entry 306's ticked Built box should be read as compiling and simulating cleanly rather than as closing timing. A fully clean Quartus 17.0.2 compile from wiped `db`, `incremental_db` and `output_files` completes in 11 minutes 40 seconds with zero errors and 132 warnings, but raises one Critical Warning, 332148, timing requirements not met. Worst-case setup slack is minus 0.105 ns with total negative slack of minus 0.816 ns. No artifact was uploaded.

The violation is not in the changed logic. It falls on the HDMI PLL clock, which belongs to the MiSTer framework and is untouched by this work, while every domain this commit affects stays healthy: the decoder reads plus 1.030 ns against plus 1.099 ns at Entry 305, the HPS bridge plus 1.364 ns against plus 1.557 ns and the video domain plus 6.399 ns against plus 7.107 ns. The design also became smaller rather than larger, falling from 33,978 to 33,790 ALMs and from 49,993 to 49,832 registers, with block memory bits and RAM blocks unchanged at 4,040,879 and 506. The change itself was one comparison constant widened from four to nine and one additional term on a six-bit index compare, so a 0.4 ns swing on an untouched clock accompanied by a reduction in logic is not plausibly a direct consequence of it and is far more likely fitter placement variance. That remains an inference and is recorded as one: what is certain is only that the preceding commit built at plus 0.295 ns and this one builds at minus 0.105 ns under identical settings and seed.

The relevant history is that this is the second time this class of miss has occurred. The entry preceding 289 records a build missing at minus 0.074 ns on a standing framework clock while the decoder and video clocks stayed clean, closed by changing the fitter seed alone with no source change. The seed is currently seven, which is already the value that closed that earlier miss. The margin on this clock has sat between roughly plus 0.15 and plus 0.30 ns for several builds and has now gone negative twice from unrelated changes, which means it is not a working margin but noise, and a build that passes only at a particular seed does not establish that the design closes timing.

#### Next Steps:

Obtain a decision before rebuilding, because the two available paths differ in what they prove. Trying a different fitter seed follows documented precedent and would unblock immediately at roughly twelve minutes per attempt, but a pass obtained that way must be recorded as closed by seed rather than by design, and with margin this thin it says little about the next change. The alternative is to treat the thin HDMI margin as the finding it appears to be and bring forward the timing half of the refactor the user has already planned for after the streaming work, rather than continuing to layer changes onto a design that fails on placement reshuffling. The functional position is unaffected either way and remains as Entry 306 recorded it: the 72 frame clip decodes to completion with no errors, both regression gates are byte identical, and the full 250 frame clip now reaches byte 310,630 and stops on `presentation_error` with probe, prediction and writer all clear. That presentation failure is still the next functional target and is untouched by this build result.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---
## 306 COMMIT Unreleased 6bea8f9 2026-08-21T17:58:05-07:00

#### Coming From:

Unreleased a9cd69c

#### Purpose:

Clear the byte 158,381 halt by making the engine selection gates agree with the widened f_code range and with the engine's own rearm.

#### Outcome:

Two further gates in `mpeg2_h262_reference_pipeline_probe_rearm.sv` were holding the pipeline, both of them duplicates of decisions taken correctly elsewhere, and with them corrected the 72 frame clip decodes to completion. The halt raised no error code at all, so a freeze detector was added to dump every stage's state at the instant progress stopped rather than waiting out the bench timeout. That snapshot showed the producer blocked on a row bank with two rows outstanding, the engine still parked on picture fifteen's completion, the scheduler idle with every resource free, and neither engine selected.

The first gate was `general_p_f_code_supported`, which repeated the f_code range check that Entry 304 widened in the syntax probe and was missed there. The parser therefore accepted an f_code five picture and produced rows for it while this gate silently refused to select the engine that consumes them, which is exactly why the symptom was a codeless freeze rather than a reported rejection. Widening it to one through nine converted the freeze into a diagnosable error, prediction source two detail seven. Reading that against the right table, as Entry 303 requires, `probe_error_detail` for source two is the raster engine's own `error_source`, so this is engine error seven, the row-completion arithmetic.

The second gate was `general_detect_now`, which selected the engine only on sideband index `6'h3e`. A motion record is `6'h3e` when inter and `6'h3b` when intra, and the engine's own `new_picture_metadata` rearm already accepted both, so the two disagreed. Picture sixteen is the first P picture after the GOP boundary I picture and opens with intra macroblocks, whose records never selected the engine and were dropped. The measurement is exact: 20,295 motion records presented across the run, 20,257 captured, 38 dropped, and those 38 are the only drops anywhere. The row that failed reported `motion_count` of seven against an `mb_width` of 45, and 45 less 38 is seven. Accepting `6'h3b` alongside `6'h3e` closes it.

The 72 frame clip now consumes all 243,306 bytes with 22 P and 47 B pictures, 25 published references, presentation complete and no errors. Both regression gates are unchanged: the 128 by 96 corpus soak reproduces every golden value at 6,589,997 cycles and the 48 frame clip is byte identical at 37,649,997 cycles, both with no errors. On the full 250 frame clip the decode path is now clean well past the old failure, advancing from byte 156,882 to byte 310,630 with 24 P pictures and 720 P rows, where it stops on `presentation_error` with the probe, prediction and writer sources all clear. That is a different subsystem from anything addressed here.

#### Next Steps:

Characterise the presentation failure on the full clip by the same method, which means finding which module raises `presentation_error` and reading its code against that module's own table before proposing anything. The decode path being clear at that point is a useful boundary: probe, prediction and writer all report zero, so the fault is in presentation or scheduling rather than in parsing or reconstruction. Run a clean Quartus build against this commit before any hardware work, since the user's standing requirement is that timing stay positive, and the Entry 305 figures are the comparison, worst case setup plus 0.295 ns with RAM blocks already at 92 percent. Timing and RAM block recovery are deliberately deferred until the streaming halt is fully resolved, at which point a refactor to reclaim block memory is planned. Note also that the bench still cannot express success for any geometry other than the corpus, so a clean 720 by 480 completion ends in a golden value failure and must be read from `LIVE_RASTER_RESULT` instead.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 305 COMMIT Unreleased a9cd69c 2026-08-21T17:08:54-07:00

#### Coming From:

Unreleased a9cd69c

#### Purpose:

Qualify the f_code widening with a fully clean Quartus build before any further work is layered on it.

#### Outcome:

The change builds cleanly and closes timing, so the Entry 304 commit is valid on hardware terms as well as in simulation. A fully clean Quartus 17.0.2 compile from wiped `db`, `incremental_db` and `output_files` completes in 11 minutes 38 seconds with zero errors, zero Critical Warnings and 132 standing warnings, four fewer than the 136 recorded for the Entry 289 build. The artifact is 4,350,372 bytes with SHA-256 `9cbbab880843376873869078d5898c66b489fe1a9f1737e6f018c9f3af04f7f6`. It was not uploaded to the MiSTer, since nothing here has been hardware-validated yet.

Every timing corner is positive. Worst-case setup is plus 0.295 ns on the HDMI PLL clock, which is MiSTer framework logic rather than anything this change touches, and compares with plus 0.151 ns on the Entry 289 build. The decoder domain reads plus 1.099 ns against plus 1.172 ns, the video domain plus 7.107 ns against plus 7.689 ns, hold plus 0.248 ns against plus 0.246 ns, removal plus 0.903 ns against plus 0.915 ns and worst recovery plus 3.232 ns. The decoder and video domains therefore lose 0.073 ns and 0.582 ns respectively while retaining substantial margin, and the binding corner is not in the changed logic. One caveat is recorded rather than glossed: the entry preceding 289 documents a build that missed at minus 0.074 ns on a framework clock and was closed by changing only the fitter seed, so seed-to-seed variation on this design is of the same order as the worst-case margin. A positive result at plus 0.295 ns means this change did not break timing; it does not establish that the margin is comfortable, and the same caution applies to any future change of similar size.

Resource growth is exactly what the change predicts and nothing more. Logic rises from 33,621 to 33,978 ALMs at 81 percent utilisation and registers from 49,362 to 49,993. Block memory rises from 4,027,379 to 4,040,879 bits, a difference of 13,500 bits, which is precisely the ten added bits of `motion_mem` multiplied by its 1,350 macroblock depth. RAM blocks rise by two to 506 of 553 at 92 percent and DSP blocks are unchanged at 65. The RAM block figure is the one to watch: at 92 percent occupancy a further widening of any macroblock-indexed memory has little headroom before the fitter is forced to spill.

#### Next Steps:

Return to the stall at byte 158,381 with the build qualification settled. Nothing about this result changes the plan recorded in Entry 304: identify which module raises which code before proposing a mechanism, and keep in view that the same clip encoded at motion search sixteen reaches byte 157,552 and raises prediction error source two detail eight, a different signature from the current codeless timeout that must not be assumed to be the same defect. Hardware validation of this commit is deliberately not attempted, because the clip it was written to support still does not decode to completion and a hardware run would prove nothing that simulation has not already shown. Treat 92 percent RAM block occupancy as a standing constraint when scoping any further datapath widening.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 304 COMMIT Unreleased a9cd69c 2026-08-21T16:46:47-07:00

#### Coming From:

Unreleased c5c5581

#### Purpose:

Implement forward f_code five through nine in the wide motion path so the decoder stops rejecting real content.

#### Outcome:

The limit was never a validation rule to relax but a datapath width running from the parser to the raster engine, and all of it is now thirteen bits. H.262 sets the vector range at plus or minus sixteen shifted left by `f_code-1`, which reaches plus or minus 4,096 at f_code nine, so thirteen signed bits is the exact requirement. In the probe the residual accumulator was three bits, capping `r_size` at three and therefore f_code at four; it and its shift register are now eight bits, `reconstruct_mv` takes an eight-bit residual with an eighteen-bit internal reconstruction and returns thirteen bits, and the predictor, current vector and event outputs are thirteen bits. The picture coding extension gate that accepted only one through four now accepts one through nine, in both the acceptance term and the rejection announcement so the two cannot disagree.

Carrying the wider vector to the raster engine needed a routing change rather than a wider sideband. The shared residual sideband value is sixteen bits and also carries coefficients, so it cannot hold two thirteen-bit components and widening it would have reached the whole residual path. The controller already produced thirteen-bit `p_forward_vector_x` and `p_forward_vector_y` for the prediction path and the reference probe already received them, so the engine now takes a dedicated motion vector channel from those same wires, combinationally aligned with the sideband, while the sideband index continues to identify a record as motion. The engine's motion memory widens from seventeen to twenty-seven bits to hold the intra flag and two thirteen-bit components, and the chroma half-vector function and the integer and half-pel splits widen with it. The packed sideband value for motion records is now a placeholder, since nothing reads it.

Both regression gates pass. The 128 by 96 corpus soak reproduces every golden value exactly, including 132 P rows, 22 P and 47 B pictures, 25 published references, 50,688 reference writes and 372,696 DDR reads, with no errors. Its cycle count reads 6,589,997 rather than the recorded 6,589,996, but a control run of stock RTL under the same simulator reads 6,589,997 as well, so the difference belongs to Verilator rather than to this change. The 48 frame clip that already decoded cleanly is byte for byte unchanged at 37,649,997 cycles with no errors.

On the failing clip the rejection is gone. Picture sixteen with f_code five is accepted, no unsupported-feature report is raised, and the decoder advances from byte 156,882 to byte 158,381 with fifteen P and thirty-three B pictures decoded and eighteen published. It then stalls and reaches the bench's two hundred million cycle limit, so this commit removes the capability limit without yet making the clip play to completion.

#### Next Steps:

Characterise the stall at byte 158,381 before assuming it belongs to this change, and characterise it by the method Entry 303 established rather than by inference: identify which module raises which code, read that code against that module's own table, and only then propose a mechanism. Two facts already bound the question. The same clip encoded with the motion search capped at sixteen, which keeps f_code at four or below, previously reached byte 157,552 and raised prediction error source two detail eight, so a defect exists just past this point that is reachable without f_code five at all and is therefore not introduced here. The current stall produces no error code at all, only a timeout, which is a different signature from that one and must not be assumed to be the same defect. A Quartus compile should also be run against this commit before any hardware work, since the motion memory grew from seventeen to twenty-seven bits per entry and the resulting M10K and timing cost has not been measured.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 303 COMMIT Unreleased c5c5581 2026-08-21T16:16:12-07:00

#### Coming From:

Unreleased 003ed48

#### Purpose:

Name the term in the producer's picture-start condition that is not satisfied for P picture sixteen, as Entry 302 required.

#### Outcome:

The term is named and it is not in the producer at all. Error source ten has been misread throughout entries 296 to 302. The figure reported as `shell=10/10/0` is `probe_error_source` from the publication shell, not the raster engine's `error_source`, and in `mpeg2_h262_two_picture_probe_p_chain.sv` line 255 that code is `p_unsupported_raw`, an unsupported-feature rejection. It is not the row-execution watchdog. The watchdog was never involved: it is armed exactly 450 times, once per row, its last arm is at cycle 35,860,936 and would not expire until cycle 52,638,151, and the fatal occurs at cycle 39,800,139. The fatal also reports `pred=0/0`, meaning the prediction and raster path raises no error whatsoever. Every mechanism proposed in entries 297 through 301, and the five repairs written against them, addressed subsystems that were working correctly.

Direct instrumentation of the rejection gives the cause in one line. At cycle 39,800,134 the wide probe evaluates P picture sixteen and reports it unsupported with a forward f_code of five in both axes, at a supported geometry of 45 by 30 macroblocks. The probe implements f_code up to four, the limit Entry 292 already recorded as a coverage gap, and the clip's motion becomes large enough at that picture for the encoder to select five. The producer then parks in `R_SUCCESS` with `proof_done` set and correctly emits nothing further, which is the behaviour that was misread as a deadlock. It also explains why the 48 frame prefix completes cleanly: it ends before any picture requires f_code five. The `--me-range` option found uncommitted in the working tree at the start of this work was evidently an earlier session reaching the same conclusion.

Re-encoding the same 72 frames with the encoder's motion search capped at sixteen removes the rejection entirely and confirms the diagnosis: the publication error disappears, reported as `shell=0/0/0`, and picture sixteen is accepted. A different and deeper defect is then reached at byte 157,552, `pred=2/8`, in the prediction path at the same picture. Constraining f_code therefore moves the boundary rather than clearing it.

#### Next Steps:

Decide the scope question first, because the two paths differ in size and only the user can choose. Implementing forward f_code five and above in the wide motion probe is the real fix, since commercial content will use the full range and the project's stated goal is DVD playback, but it is a parser change of unknown size. Capping the encoder's motion search is not a fix at all, only a way to keep exercising the rest of the pipeline, and it should be treated as a diagnostic aid rather than as a passing result. Whichever is chosen, the next failure is already located and reproducible: with f_code constrained the decoder reaches prediction error source two, detail eight, at byte 157,552 on picture sixteen, and that should be characterised the same way this one finally was, by identifying which module raises the code and what the code means before proposing any mechanism. Note for that work that error codes in this design are per-module and are not interchangeable; reading one module's code against another module's table is what cost entries 296 through 302.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 302 COMMIT Unreleased 003ed48 2026-08-21T16:07:24-07:00

#### Coming From:

Unreleased c792ca8

#### Purpose:

Measure the cycle ordering of the completion events, as Entry 301 required before any further repair.

#### Outcome:

The measurement invalidates the premise of entries 298 through 301 and none of the repairs those entries proposed should be pursued. The picture-completion latch is not defective. Capturing the exact cycles of every relevant event shows all fifteen pictures completing correctly and identically, fifteen completion pulses for fifteen pictures. Picture one is representative: `final_row_queued` rises at cycle 939,584 with two rows outstanding, the P engine's picture-persistence edge and the final P-sourced retire both arrive at cycle 976,999 with `b_select` low and `row_produced` low, and completion asserts at cycle 977,000 with the outstanding count at zero. Picture fifteen behaves the same way at cycle 35,883,918. Completion therefore fires on the genuine P event, not on a coincidence.

Entry 298's central claim, that picture completion is triggered by spurious B retires arriving by luck, is wrong and is superseded. The B retires do reach the counter and do walk it down to the value the equality test reads, but the event that actually satisfies the latch is the P engine's own final-row persistence. This was verifiable at any point by recording when the events occur rather than inferring it from counts, which is what Entry 301 required and what should have been done before Entry 299 proposed a repair.

Rewriting the latch to key directly on picture persistence, with the row retire source left as found, confirms this independently: the failure is byte-for-byte identical to the stock signature at byte 156,882, because the change is a no-op on behaviour that was already correct. The contamination measurements from Entry 301 stand as measurements, 727 row retires against 240 genuine and 24 picture-persistence pulses against 8, and every contaminated picture-persistence pulse is observed at `final_row_queued` low, outside the completion window. They are real defects in signal routing but they are not the cause of this deadlock.

The defect lies in whatever should begin P picture sixteen after picture fifteen completes normally. Picture fifteen completes, four further B-sourced persistence pulses follow, the sixteenth P header is seen by the publication shell, and the producer then emits nothing at all. In this stream P picture sixteen is the first P picture of the third GOP and follows an I picture; P picture nine holds the same position in the second GOP and decodes correctly, so position within the GOP is not by itself the discriminator.

#### Next Steps:

Instrument the producer's picture-start path rather than anything downstream of it. Capture `picture_capture`, `picture_count`, `current_picture_is_p`, `wide_candidate`, `geometry_supported`, `producer_rearm_pending` and `proof_done` in the wide probe across the start of picture sixteen, and compare that trace against the start of picture fifteen, which succeeds, and picture nine, which occupies the equivalent position in the previous GOP and also succeeds. The question is narrow and factual: which term in the probe's picture-start condition is not satisfied for picture sixteen. Do not propose a repair until that term is named. Five repairs have now been attempted across entries 297 to 302 and every one addressed a subsystem that measurement later showed to be working correctly, so the standing instruction is to identify the failing term by observation first and to treat any hypothesis not grounded in a recorded cycle as unproven.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 301 COMMIT Unreleased c792ca8 2026-08-21T16:01:57-07:00

#### Coming From:

Unreleased dc7da26

#### Purpose:

Implement the differential completion latch approved in Entry 300 and record why it and its successor both fail.

#### Outcome:

Two further repairs were written and neither works, so neither is committed, and one factual claim in the two preceding entries must be corrected. Entry 299 stated that nothing resets `outstanding_rows` at a picture boundary and Entry 300 repeated it; both are wrong. The per-picture initialisation block in part three of the wide probe has always contained `outstanding_rows<=0`, so the counter's zero point was defined all along and the offset theory those entries were built on had no basis. The corresponding correction applied in Entry 300 was a duplicate of an existing line.

The differential latch was implemented as specified: a `rows_owed` counter latched at the final row from the then-current outstanding count plus one, decremented on each P-sourced retire, with completion firing as it reaches one. Instrumenting it shows the counter behaving exactly as designed and the repair still failing at byte 30,477. At the final row `rows_owed` latches to two, one retire arrives and takes it to one, and it then holds at one for 22,644 traced cycles while no further retire ever appears. The conclusion is firm and it invalidates the whole family of counting repairs: the final row's persistence is never delivered to the producer as a countable retire, so no arithmetic over retire events can express picture completion regardless of how the counter is defined.

The successor attempt keyed the latch on the engine's picture-level persistence instead of on any count, routing the controller's existing `p_persistence_complete` into the probe as a new input. It also fails at byte 30,477, though the event itself is present: the signal pulses exactly once for the picture, so the latch and the pulse are failing to overlap and the remaining question is one of cycle ordering rather than of a missing event. Reverting to the recorded state and counting the same signals on the stock design then produced the most useful measurement of this cycle. Over the first eight P pictures the P engine's own `mixed_persisted_edge` fires exactly eight times, once per picture, while the `p_persistence_complete` the producer actually receives fires twenty-four times. Both of the persistence signals reaching the P producer are `b_select` muxed and carry B events, the row-level one at 727 against 240 and the picture-level one at 24 against 8, and the attempted repair was wired to the contaminated one.

#### Next Steps:

Route the P engine's own `mixed_persisted_edge` to the producer rather than the muxed `p_persistence_complete`, since it is measured at exactly one pulse per P picture and is the only uncontaminated picture-completion event available. Before wiring it, establish the cycle ordering that defeated the previous attempt by capturing the exact cycles on which `final_row_queued` rises, the persistence pulse occurs, and `row_produced` asserts across picture one's tail; a one-cycle pulse tested against a condition that also requires `!row_produced` has no second chance, and that is the most likely reason a present event failed to latch. Keep the dedicated `p_row_persisted` row-level source as part of the same change, since the row credit remains contaminated three to one and still drives backpressure. Four repairs have now failed. Do not write a fifth without first recording the ordering measurement, because every failure so far has come from assuming when a signal arrives rather than observing it.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 300 COMMIT Unreleased dc7da26 2026-08-21T15:36:44-07:00

#### Coming From:

Unreleased 7daf716

#### Purpose:

Apply the three coupled corrections approved in Entry 299 and record what they did.

#### Outcome:

The approved change was written in full and does not work, so it is not committed. All three corrections were applied together: a dedicated `p_row_persisted` output carrying `mix_row_persisted` driving the producer's `row_retired`, a clear of `outstanding_rows` in the per-picture initialisation block so its zero point is defined, and a widening to three bits with saturating increment and decrement. The failure moved from byte 156,882 to byte 30,477, which is the same forward move both Entry 297 attempts produced, and the run ends in the bench's two hundred million cycle timeout rather than the watchdog.

Instrumenting the corrected design settles what is actually wrong with the approved plan. Over picture one the counts are exactly balanced and correct: thirty rows produced, thirty retires delivered, thirty P engine persistence pulses, and thirty of those with `mixed_select` asserted. The pipeline then halts without processing a second picture. Balanced accounting and a defined zero point are therefore not sufficient, and the premise of Entry 299 was wrong. The completion latch's comparison of `outstanding_rows` against the literal one is the wrong mechanism irrespective of where the counter is zeroed, because it asks an absolute question of a running count whose value at the final retire depends on how far the engine's persistence lags the producer's parsing. It is satisfiable only by coincidence, which is precisely what the spurious B retires were supplying.

Reverting restored the recorded signature exactly, and the stock run now quantifies the routing defect precisely. The producer emits 390 rows, the P engine persists 390 rows, and 390 of those carry `mixed_select`, yet the producer's retire input receives 1,171 events. The excess 781 are B-sourced. The P side of the accounting has never been in doubt at any point in this investigation; only the retire input and the completion latch are defective.

#### Next Steps:

Replace the completion condition with a differential test rather than an absolute one, and keep `outstanding_rows` for bank backpressure only. When the producer emits the picture's final row, latch the number of retires still owed at that instant, decrement that latched value on each P-sourced retire, and fire completion when it reaches zero. Expressed that way the latch cannot be affected by how far persistence lags parsing, by the counter's zero point, or by any constant offset, and it fires on the final row's own retire rather than on a coincidence. The dedicated `p_row_persisted` retire source from Entry 299 remains necessary and should be applied with it, since a differential count is still corrupted by 781 foreign decrements. Do not reuse `outstanding_rows` to carry completion semantics. Validate on the failing clip, the 48 frame prefix, and the corpus soak whose 6,589,996 cycle count must not move. Three repairs have now failed, all of them by substituting one signal or zero point while leaving the absolute comparison in place, so a candidate that does not remove that comparison should not be attempted.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 299 COMMIT Unreleased 7daf716 2026-08-21T15:17:00-07:00

#### Coming From:

Unreleased 7ba1184

#### Purpose:

Record why the Entry 297 repairs failed and what the picture-completion latch must be changed to instead.

#### Outcome:

The failure of both Entry 297 repairs is now explained and is not what that entry assumed. Narrowing the retire input to P-sourced persistence and tracing the completion latch's own terms shows that exactly one retire arrives while `final_row_queued` is asserted, and it arrives with `outstanding_rows` at two rather than the one the latch requires. The latch misses by a single count, the counter settles at one, and the producer holds `row_waiting` for the remaining twenty-two thousand traced cycles without another retire. Since Entry 298 established that produce and P-sourced retire are exactly balanced at thirty each for every picture, the discrepancy is a constant offset that `outstanding_rows` acquires before the first picture completes and never sheds, because nothing resets it at a picture boundary. The spurious B retires wash that offset out by walking the wrapped two-bit counter through every value, which is why the original wiring appears to work; an accurate counter preserves the offset permanently and the latch can never match.

The defect is therefore threefold and the three parts are coupled. The retire input carries B-engine persistence into a P-only credit counter, the counter is two bits and wraps rather than saturating, and the completion latch tests that counter for an absolute value of one while nothing guarantees the counter's zero point. No one of these can be corrected alone: removing the corruption alone moves the failure from byte 156,882 forward to byte 30,477, which is what both Entry 297 attempts did.

#### Next Steps:

Apply the three corrections together as one change, since they are only correct in combination. Give the reference probe a dedicated `p_row_persisted` output carrying `mix_row_persisted` and drive the wide probe's `row_retired` from it, so the credit counter sees only P-sourced persistence. Clear `outstanding_rows` when a new picture begins so its zero point is defined and no startup offset can survive into the first completion. Widen `outstanding_rows` beyond two bits so that it saturates rather than wraps and a miscount can never alias to a valid value. With a defined zero point and a balanced thirty against thirty per picture, the existing test for one at the final retire becomes exact rather than a coincidence, and no change to the latch expression itself is required. Validate on the failing clip, on the 48 frame prefix that already completes cleanly, and on the 128 by 96 corpus soak, whose golden values including the 6,589,996 cycle count must not move. Await user approval before writing this, since it changes a contract rather than correcting a wire.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 298 COMMIT Unreleased 7ba1184 2026-08-21T15:10:54-07:00

#### Coming From:

Unreleased 221db79

#### Purpose:

Settle the row-bank credit contract left open by Entry 297 by counting both engines' produce and retire events on one timebase.

#### Outcome:

The contract is settled and the defect is larger than Entry 297 described. `row_produced` is `wide_row_produced`, the P parser's own row-final marker, so it is genuinely P-side and fires once per P row. Counting confirms the P side is already correct: every P picture in the failing clip produces exactly thirty rows and receives exactly thirty P-sourced retires, fourteen pictures in a row without deviation. `outstanding_rows` is therefore meant to track P rows outstanding, and the roughly sixty B-sourced retires each picture also receives are unambiguously spurious, 897 of them against 450 legitimate ones across the run.

The consequence is not merely a corrupted count. The picture-completion latch in the wide probe fires on `row_retired&&final_row_queued&&(outstanding_rows==1)&&!row_produced`, and that is the only path that sets `wide_complete_now` and `proof_done` and so the only path that lets the producer rearm for the next picture. Because `outstanding_rows` is two bits it wraps rather than saturates, and the stream of spurious B retires walks it three, two, one, zero, three continuously. Every picture's retire tail is B-sourced, and pictures one through fourteen pass through the value one sixteen times each, twenty-three times for picture eight. One of those spurious events eventually coincides with `final_row_queued` and completes the picture. Picture completion in this design is therefore triggered by B-engine retires arriving by luck, not by the P engine persisting its own final row. Picture fifteen receives only seven such passes before that GOP's B pictures are exhausted, the coincidence never occurs, picture fifteen never completes, the producer never rearms and emits nothing for picture sixteen, and the raster engine's watchdog raises error source 10 after its full `24'hffffff` wait.

This also explains why both repairs attempted in Entry 297 failed earlier rather than later. Removing the B retires removes precisely the events that were completing pictures, so the failure moved forward to byte 30,477 instead of 156,882. The two defects are coupled: the routing error supplies the corruption, and the completion latch depends on that corruption to fire at all. Neither can be fixed alone.

#### Next Steps:

Replace the completion trigger rather than clean the counter, and obtain approval before writing it because this changes a contract rather than correcting a wire. Picture completion should latch when the P engine persists the row that the producer marked final, tracked explicitly as its own event, instead of being inferred from a shared count reaching a particular value. With that in place the retire input can be narrowed to P-sourced persistence and `outstanding_rows` can be widened or made to saturate, since it would then serve only as bank backpressure and no longer carry completion semantics. Validate any candidate on the failing clip, on the 48 frame prefix that already completes cleanly, and on the 128 by 96 corpus soak whose golden values must not move. Note also that the bench cannot currently express success for any geometry other than the corpus, so a clean 720 by 480 run still ends in a golden-value `$fatal` and that must be fixed before the clip can be certified as playing to completion.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 297 COMMIT Unreleased 221db79 2026-08-21T14:54:26-07:00

#### Coming From:

Unreleased 489aa0d

#### Purpose:

Determine why the raster engine's row-execution watchdog fires at P picture 16 of the Big Buck Bunny clip.

#### Outcome:

The cause is established by direct observation and is a shared-signal defect rather than anything in the parser. The P syntax probe tracks row-bank credit in `outstanding_rows`, incrementing on `row_produced` and decrementing on `row_retired`. That `row_retired` input arrives from `p_row_persistence_complete`, which is wired to the reference probe's `row_persisted` output, and that output is `b_select?b_row_persisted:(mixed_select&&mix_row_persisted)`. While `b_select` is high the P producer therefore receives B row persistence as its own retire event. Tracing the boundary shows exactly that: a long run of retire pulses each carrying `b_select=1` and `b_rowpers=1` while the P engine's own `mix_rowpers` stays low, with `row_produced` never asserting. Since `outstanding_rows` is only two bits it does not saturate but wraps, and the trace shows it walking three, two, one, zero, three repeatedly. The producer parks in parser state 21, emits no sideband event whatsoever for picture 16, and the raster engine, correctly armed and waiting on `new_picture_metadata`, sits until its `24'hffffff` watchdog expires and raises error source 10. The same wiring is present in `MediaPlayer_top_02.svh`, so this is a defect in the design and not an artifact of the bench.

One hypothesis formed during this work was disproven by its own instrument before it could be acted on. Because the engine only rearms on a motion record, it appeared that picture 16 might open with a non-motion sideband event. Logging the opening events of every P picture shows pictures one through fifteen each opening with index `3e` and `motion=1` at the exact moment `persisted` is high and `active` and `desc_active` are low, while picture 16 produces no logged event at all. The rearm condition is satisfied and waiting; nothing is presented to it.

Two candidate repairs were tried and both are worse, so neither is committed. Giving the P producer a dedicated retire derived from `mixed_select&&mix_row_persisted` and then from `mix_row_persisted` alone each moved the failure much earlier, to a bench timeout at byte 30,477 rather than the deadlock at byte 156,882. The P producer therefore depends on receiving the shared retire events rather than merely being corrupted by them, which means the row-bank credit is an entangled resource between the P and B engines and not a simple miswire. The working tree was returned to the recorded state and the original failure signature confirmed to reproduce.

#### Next Steps:

Establish what the row-bank credit contract is meant to be before attempting a third repair, since two have now failed for the same reason: the accounting is shared between two engines that produce and retire rows independently, and no single-signal substitution can express that. Determine whether `outstanding_rows` is intended to count only the P producer's own outstanding rows, in which case the B retires are spurious and the P producer's dependence on them is a second defect layered on the first, or whether it is intended to count a genuinely shared bank pool, in which case the two-bit width is wrong and the counter needs to saturate rather than wrap. Instrument both engines' produce and retire events on one timebase across several picture boundaries before choosing. Separately, the user has directed that compatibility with the existing structure is not required and that the work should be shaped around what the SuperStation needs; this entanglement is a reasonable argument for replacing the shared credit path rather than patching it, but the SuperStation target is still not described anywhere in the repository and must be defined first.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 296 COMMIT Unreleased 489aa0d 2026-08-21T14:37:48-07:00

#### Coming From:

Unreleased 3992070

#### Purpose:

Retarget the regression loop onto a real 720 by 480 clip that must play to completion, and make that clip fast enough to iterate against.

#### Outcome:

The source is now `big_buck_bunny_480p_stereo_10s.avi`, encoded by the committed generator at 720 by 480, 25 fps, 250 frames, GOP 24 with two B pictures and encoder default quality, giving `test_bbb_10s_480p.m2v` at 1,178,034 bytes with sha256 `b392b65d`. The encode was validated against ffmpeg and the project analyzer before any simulation time was spent on it, so a bench failure is attributable to the decoder rather than to the stream. Note that the bench previously capped `MAX_STREAM_BYTES` at one mebibyte, which is why the preceding interrupted session was encoding at `q8` with `me_range 16` and landing just under that limit; that was shrinking the encode to fit the bench rather than testing the content, and the cap is now a define defaulting to four mebibytes.

The decisive change is the simulator. Icarus interprets this design at roughly 21,300 cycles per second, which puts the 250 picture replay beyond two hours and makes a deadlock investigation impractical. The same bench and the same file list built under Verilator 5.032 completes in 45 seconds, a factor of about forty, and reproduces the failure bit for bit: identical `byte=156882`, identical `shell=10/10/0`, identical `p_rows=450` and `p_pictures=15`. That equivalence is what licenses using the faster build. Both drivers are committed so either can be run.

A 48 frame prefix of the same clip decodes cleanly and completely, consuming all 125,948 bytes across 15 P and 31 B pictures with `error=0/0/0/0` and presentation complete. The `$fatal` that follows it is not a decode failure but the bench's hardcoded golden values for the 128 by 96 corpus, which cannot apply to a 720 by 480 stream; the bench currently has no way to express success for any other geometry. The full clip fails at P picture 16 with raster error source 10, which is the row execution watchdog rather than any parsing or accounting check, after waiting the full `24'hffffff` cycles for a persistence that never arrives. The stall state places the engine at `mbi=1349`, `col=44`, `mrow=29`, `blk=5` and `ei=63`, which is the final element of the final block of the final macroblock of the final row, with `motion_count` equal to `motion_end` at 1350 and capture already advanced to row 30. Nothing is pending or requested, the reference is valid and geometry is fine, so the picture is fully accounted for and only the completion handshake fails to fire.

Entry 294 is superseded. Its duplicate detector keyed on the residual sideband index, which is the fixed class code `6'h3e` for non-intra and `6'h3b` for intra and is therefore constant across any run of skipped macroblocks by construction. Tracing the 11 bit `wide_motion_index` instead, which is the only field that can separate a repeat from a skip run, records zero true repeats across 13,501 emissions while finding 1,506 back to back emissions whose index advances by one, in 202 runs of which the longest is 43. The run length histogram contains eight runs of exactly seven, which are the events Entry 294 reported as seven or more identical intakes. The producer emits one record per macroblock as contracted, the held assertion described in entries 293 through 295 does not exist, and the producer side repair those entries queued up must not be written.

#### Next Steps:

Instrument the row persistence handshake at the end of a picture and compare P picture 16 against P picture 15, which persists correctly, rather than proposing a mechanism from the stall state. The scheduler reports `run_closed` with no decode in flight, a pending future frame on bank 2 and `scratch1_pending` set, which is consistent with bank rotation being involved, but that is a correlation and the recent history of this investigation is four mechanisms rejected by their own controls. Separately, give the bench a way to express completion for a geometry other than the corpus, since the current golden constants make a clean 720 by 480 run indistinguishable from a failure. The user has directed that compatibility with the existing MiSTer Media Player structure is no longer required and that this work should be shaped around what the SuperStation needs; that target is not yet described anywhere in the repository and must be defined before any rearchitecture is attempted.

#### Files Modified:

- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/run_live_raster_soak.sh
- tools/streams/run_live_raster_soak_verilator.sh
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 295 COMMIT Unreleased 3992070 2026-08-21T13:04:45-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Retarget the thirteen RTL standards citations that name the absent `core-standards.md` so they resolve against `core-reference.md`.

#### Outcome:

Entry 289 recorded that thirteen RTL files cite `core-standards.md` as their standards authority while that file is absent from the repository, leaving the conformance rationale for those modules unrecoverable. Its absence is confirmed, and this commit closes the gap by pointing the citations at `core-reference.md`, which `core.md` already names as the project's authoritative reference library.

The retarget was checked before it was made rather than assumed to be a straight rename. `core-reference.md` declares `source_id: H262` in its controlled source catalog and carries atomic conformance records `H262-001` through `H262-026` in section 10.2, and every identifier the RTL headers cite resolves there to a real `record_id`: `H262-006`, `H262-010` and `H262-014` named in the B core probe, and the `H262-007` to `H262-022` range named in the wide motion syntax probe. The identifiers were therefore never wrong and no conformance claim needed re-deriving; only the filename was stale. That makes this a repair of a broken pointer rather than a change of authority, which matters because a citation that silently named a missing file was indistinguishable from one that had never been substantiated.

The two filenames are the same length, so no header comment rewrapped and each file's diff is a single token on a single line. Every changed line was verified to be a `//` comment before committing, so the synthesized netlist cannot differ from `cba5371` and no Quartus build was run; the Built box is left unchecked rather than carrying a tick that no compile earned. One cosmetic inconsistency was left as found to keep the diff minimal: two of the thirteen headers write the path as `.ai/core-reference.md` while the other eleven name the file bare.

#### Next Steps:

Resume the Entry 294 line of work, which is unaffected by this commit and remains the v0.6.0 blocker. Entry 294 established that the raster engine consumes motion validity as a level and that the producer holds `wide_motion_valid` asserted across a picture boundary, multiplying one event into seven or more identical motion records and inflating `motion_count` past what the row-completion test can satisfy. The instruction there was to establish why the assertion is held before changing anything, and that remains the next action. The emission state machine is in the wide motion syntax probe, which sets `motion_event_valid` at two sites and clears it at two others, and it reaches the controller as `wide_motion_valid` through the `wide_general_probe` instance; trace its state across the duplicated run and determine whether the hold expresses a stall that should instead withhold validity, or a genuine repeat that a downstream handshake was expected to absorb. Prefer the producer-side fix if both are viable, since an accept handshake would change a contract the rest of the design already satisfies. Three gaps recorded earlier still stand and are not addressed here: the routine regression gate runs a 128 by 96 frame against a 720 by 480 target, no corpus stream exercises the queued admission path, and the artifact on the MiSTer has not been hardware-validated since Entry 289.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_aligned_motion_syntax_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_four_mb_two_row_copy_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_four_mb_two_row_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_macroblock_420_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_plan_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_residual_parser_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_two_mb_copy_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_two_mb_syntax_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 294 COMMIT Unreleased cba5371 2026-08-21T04:06:03-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Determine whether the raster engine consumes motion validity as a level or an edge, and confirm on a single timebase whether the held producer assertion is what corrupts the picture.

#### Outcome:

No source changed. The mechanism is established directly and survives its control, which none of the four earlier candidates did.

The consumer is level sensitive. The match chain in `mpeg2_h262_p_motion_residual_raster_engine.sv` is entered under `capture_enable && residual_valid` evaluated every clock, with no edge detection anywhere in the path, so any cycle in which validity is high and the index is a motion index executes the motion branch and increments `motion_count`. The producer is expected to answer that with one cycle per record, and it does so almost everywhere: counting sideband validity per clock yields exactly forty-five records in every row of the failing 720 by 480 stream, a figure only reachable when each record occupies a single cycle.

At the failure the producer does not honour that contract. Instrumenting the engine to detect a motion record ingested on consecutive cycles with an identical index and value records a run of seven or more identical intakes of index `6'h3e` with value zero, one per clock, driving `motion_count` from two to seven within row zero, and 4,468 duplicate intakes in total before the error is raised. The corpus control run over the same instrumented build records zero duplicates. That contrast is the whole finding: a held validity assertion is silently multiplied into spurious motion records by a level-sensitive intake, `motion_count` inflates, and the row-completion test that requires exactly `capture_motion_base` plus `mb_width` can no longer be satisfied. This accounts for both reachable errors from one cause, source seven directly through the corrupted row arithmetic and source eight through the boundary state that follows from it, which matches the suspicion recorded in Entry 291 that the two were not independent limits.

The earlier per-row measurement of exactly forty-five records is not contradicted. It was taken over the first eight rows of the first picture, where the producer is well behaved; the duplication appears in a later picture, so both observations are correct and describe different parts of the stream.

#### Next Steps:

Establish why the producer holds the assertion before changing anything, because the fix differs by cause and this is the point at which four previous attempts went wrong. The contract is not in doubt: every other producer path emits one cycle per event and the consumer is level gated throughout and works, so a held assertion is the defect rather than a consumer that should have edge detected. What is not yet known is whether the hold is a stall condition being expressed incorrectly, in which case the producer should withhold validity while stalled, or a genuine repeat that some downstream handshake was expected to absorb. Trace the producer's motion emission state machine across the duplicated run and identify what keeps it asserted. Only then choose between suppressing the repeat at the source and adding an accept handshake, and prefer the source fix if both are viable, since an added handshake would change a contract that the rest of the design already satisfies. When a candidate exists, gate it on the corpus soak, the focused scheduler regression, the 720 by 480 clip that already decodes cleanly, and this failing clip, and record that the corpus cannot detect a regression in this path because it never exercises the duplication at all.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 293 COMMIT Unreleased cba5371 2026-08-21T03:52:49-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Bisect the raster engine failure by capturing the event sequence that precedes it, rather than proposing a fifth mechanism from stream properties.

#### Outcome:

No source changed. The bisect locates the failure at a picture boundary and produces the first direct observation of an anomaly rather than another inference. A ring buffer holding the last twenty-four residual events, dumped at the instant `error` first asserts, shows the failing picture completing correctly and the fault arriving immediately afterwards. Event 80,093 carries index `6'h3f` with value `A2FF`, the picture-final row marker, at row twenty-nine with `motion_count` at 1,350, which is exactly forty-five by thirty and therefore a complete and correctly accounted picture. The next two events carry the identical value `0x00a4` on two different indices, `6'h3e` and then `6'h3f`, the second arriving after the engine has already reset to `motion_count` one and row zero for the following picture. The engine has no metadata interpretation for `6'h3f` carrying that value in that state, so it falls through its match chain to source eight. Nothing about the picture's content is implicated; the fault is in what crosses the sideband between one picture and the next.

Tracing both legs of the producer mux in `mpeg2_h262_p_diagnostic_controller_rearm.sv` shows the mechanism on the producer side. Immediately after the residual leg presents the `A2FF` marker, `wide_motion_valid` asserts and remains asserted for five consecutive cycles, emitting an identical intra motion record on index `6'h3b` with value zero each time. Single-cycle assertion is the norm everywhere else, which is established independently by the per-row count: the same stream produces exactly forty-five motion records in every row, and that figure is only reachable if each record occupies one cycle. A record held for five cycles at the picture boundary is therefore anomalous, and it is the first mechanism in this investigation observed directly rather than deduced.

Two caveats are recorded so the next step does not build on sand. The two traces use different counters, the ring buffer counting residual events accepted at the engine and the mux trace counting sideband validity at the producer, so their event numbers are not aligned and the held assertion has not yet been proven to be the same instant as the misread event. It is also not yet established whether the consumer edge-detects motion validity, in which case a held assertion would be harmless and the fault would lie elsewhere in the same window.

#### Next Steps:

Align the two observations on a single timebase before proposing any repair, then determine whether the consumer treats `wide_motion_valid` as a level or an edge. Those two facts together decide the fix: if validity is consumed as a level and the producer holds it across a picture boundary, the defect is the held assertion and belongs to the producer's boundary sequencing; if the consumer edge-detects, the held assertion is benign and the misread `6'h3f` event must have another origin in the same handful of cycles. Continue to instrument rather than repair, since four mechanisms have now been rejected by their own controls and the one surviving lead is still only a correlation in time. The unsupported-feature report from Entry 289 is unaffected by any of this and remains committed and built.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 292 COMMIT Unreleased cba5371 2026-08-21T03:26:14-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Compare motion record emission against macroblock count per row to decide whether the skipped-macroblock defect lies in the producer or the consumer.

#### Outcome:

No source changed. The comparison rejects the hypothesis it was designed to test and exposes a weakness in the regression suite that is more consequential than the bug being chased.

The producer's motion accounting is correct. Counting emissions on the motion sideband indices shows the failing 720 by 480 stream producing exactly forty-five motion records in every row, which is precisely its `mb_width`, sustained across at least the first eight rows and three hundred and sixty records before the failure occurs. Skipped macroblocks are therefore already carrying motion records, the row-completion arithmetic in `mpeg2_h262_p_motion_residual_raster_engine.sv` is being satisfied, and the leading-skip explanation offered in Entry 291 is not supported. That entry's inference from a first coded macroblock of forty was a correlation drawn from residual metadata only; it did not account for the motion sideband, which is emitted separately and completely.

The control run produced the finding that matters. The corpus soak stream reports eight motion records per row, not forty-five, because `test_live_raster_soak.m2v` is 128 by 96. The regression that has been treated throughout this work as the authoritative gate, the one held at exactly 6,589,996 cycles across every change since Entry 285, exercises an eight by six macroblock frame. The hardware target and every real stream is 720 by 480, which is forty-five by thirty, so the fast gate covers a frame roughly thirty times smaller in macroblock count than the content the core is meant to play. `test_compat_long_gop.m2v` is genuinely 720 by 480, but a complete replay of it costs thirty to forty-five minutes against roughly four for the soak, so the small stream is what actually runs on most changes. This does not invalidate any recorded result, since each measurement is accurate for the stream it was taken on, but it does mean the routine gate is far weaker evidence of 720 by 480 correctness than its use throughout this log implies, and it is a further instance of the coverage problem already recorded for f_code above four and for the queued admission path.

#### Next Steps:

Locate the failure by row rather than by hypothesis. The stream survives at least eight complete rows with correct motion accounting before raising source eight, so capture the engine's full state at the transition into the failing row and compare it against the same transition in a row that succeeds, rather than reasoning forward from stream properties again. Three successive hypotheses have now been rejected by their own controls, which is the method working but also a signal to stop proposing mechanisms and start bisecting the failure point directly. Separately, promote a 720 by 480 stream to the routine gate. The soak's speed advantage comes from a frame size that no longer represents the target, so either generate a short 720 by 480 soak whose replay cost is acceptable or accept the longer run on changes that touch the P or raster paths; continuing to certify those paths on a 128 by 96 frame will keep producing green regressions that say little about real content.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 291 COMMIT Unreleased cba5371 2026-08-21T03:12:15-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Determine whether the unrecognised residual event that raises raster error source eight originates in the producer or in sideband routing.

#### Outcome:

No source changed. Both hypotheses from Entry 290 are now settled, and one conclusion formed during this work was disproven by its own control before it could be acted on.

The routing hypothesis is rejected. `mpeg2_h262_reference_pipeline_probe_rearm.sv` does mux two producers into the engine's residual input, a plan adapter and the shared `p_residual_sample_*` path, and `mpeg2_h262_two_picture_probe_p_chain.sv` muxes the B sideband onto that same shared path under `b_transport` while the consumer gates it with a different signal, `b_select`, computed in another module from unrelated state. That asymmetry looked like a leak. Instrumenting every cycle where `b_transport` is high, `b_select` is low and a residual sample is valid records zero such cycles across the failing stream, so no B sideband reaches the P engine and the plan adapter emits only `A2FF` on the metadata index. Neither is the source.

The producer is emitting the event, but the reason is not the one it first appeared to be. Tracing every metadata-class emission shows that at `G_SAMPLES` the pipeline forwards the transform output directly with `replay_index<=tidx`, so coefficient positions sixty through sixty-three occupy indices `6'h3c` through `6'h3f`, the same indices the raster engine reads as macroblock number, block identity and row marker. That collision is real, but it is not the defect: the corpus control emits exactly the same pattern, index `6'h3f` at that state carrying coefficient value `0xffff`, twenty-six such events in the same window as the failing stream, and it decodes cleanly. The index space is overloaded by design and disambiguated by consumer state, so the failure is a state disagreement rather than an encoding collision.

The discriminator is visible in the first event each stream produces. The corpus begins at macroblock zero, while the failing picture's first coded macroblock is number forty, so it opens with forty consecutive skipped macroblocks. At the point of failure the consumer holds `capture_desc_count` at zero, `desc_active` and `sample_expected` both low and `motion_count` at one, meaning coefficients arrived before any descriptor established what to expect. Leading skipped macroblocks are therefore the property that separates the two streams, which also fits the row-completion check that raises error source seven on a different encode, since that check requires exactly `mb_width` motion records per completed row and skipped macroblocks carry none. An earlier attempt to test this by adding encoder noise to suppress skipping was inconclusive for an unrelated reason: it raised picture density enough to trip a different limit before the skip path was reached.

#### Next Steps:

Establish how the producer and consumer are meant to account for skipped macroblocks before changing either. Trace the motion record stream against macroblock numbers across a row for both streams and determine whether the producer emits a record for a skipped macroblock, whether the consumer expects one, and which of the two the row-completion arithmetic assumes. That single comparison decides whether the defect is a missing synthesis of skipped-macroblock motion records in the producer or an incorrect expectation in the consumer's row accounting, and the fix differs completely between them. Do not add a pattern arm to the engine's match chain, because the chain is not the problem; the corpus proves the same events are accepted when the consumer is in the expected state. Note for the eventual scope decision that the two reachable errors, source seven and source eight, now appear to share this single cause rather than being independent limits, which would make the family smaller than Entry 290 estimated.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 290 COMMIT Unreleased cba5371 2026-08-21T02:33:40-07:00

#### Coming From:

Unreleased cba5371

#### Purpose:

Isolate which condition in the P motion residual raster engine rejects dense real-content pictures, instrumenting only and changing no RTL.

#### Outcome:

No source changed. The step narrows the defect substantially and disproves the hypothesis it started from, but does not close it. The leading hypothesis was the documented bound of sixteen coded blocks and sixty-four coefficient events quoted in the wide probe header. That bound belongs to a different module: the raster engine's own capacity limit is `MAX_BANK_BLOCKS` at 1024, far above anything these streams reach, so capacity is not the mechanism.

Instrumenting the engine also shows the problem is broader than a single condition. The engine carries sixteen distinct error sources, and different real-content encodes reach different ones. The clip that failed in Entry 288 raised source seven, a row-completion consistency check; a clip encoded from the same source at quality eight with motion search capped to sixteen instead raises source eight at input byte 35,722, well before any f_code gate is reached. Source eight is not a bounds check at all. It is the terminal `else` of a chain of `else if` arms that match residual metadata patterns, so it means the engine received a sideband event whose shape it does not recognise.

The captured event is precise: residual index 63, which is `6'h3f`, carrying value `0x00a4`, with `desc_active` and `sample_expected` both low, `capture_row` zero, `motion_count` one and `capture_desc_count` zero. That is the first macroblock row of the picture, so the rejection happens almost immediately rather than deep into dense content. The recognised vocabulary at index `6'h3f` is a descriptor whose top nibble is `4'hB`, or the row markers `A2FE` and `A2FF`, and `0x00a4` is none of these. The producer in `mpeg2_h262_p_residual_pipeline_420.sv` emits the macroblock number at index `6'h3c` and the intra and block identity at index `6'h3d`, and a value of `0x00a4` is a plausible macroblock number but is arriving on the index reserved for row markers. Whether that is an index and value pairing the engine does not expect, or a second producer path reaching the same consumer through the `mixed_select` routing in `mpeg2_h262_reference_pipeline_probe_rearm.sv`, is not yet established and is the next thing to determine.

#### Next Steps:

Trace the producer side rather than the consumer, recording every `replay_index` and `replay_value` pair the residual pipeline emits for the failing picture and comparing that sequence against a corpus picture that decodes cleanly. That distinguishes the two remaining explanations directly: either the producer emits `0x00a4` on index `6'h3f`, which makes this a producer defect, or it does not, which makes it a routing or arbitration defect where a second source reaches the consumer. Do not modify the engine's pattern chain before that is known, because adding an arm for an event whose origin is not understood would hide a routing fault rather than fix it. Record also that the earlier plan's framing of a single density limit was wrong: there is no single second limit, there is a family of sixteen rejection conditions of which at least two are reachable by ordinary encodes of the same source file, so the scope decision for v0.6.0 should be taken against that family rather than against one bound. The unsupported-feature report added in Entry 289 remains valuable independently, because it is what allows each of these to be identified at the picture that causes it instead of surfacing as an unrelated downstream stall.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 289 COMMIT Unreleased cba5371 2026-08-21T01:29:22-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Report an unsupported P picture as an explicit error instead of silently consuming it, so a capability gap fails loudly rather than freezing the core.

#### Outcome:

Entry 288 established that a P picture carrying f_code five is rejected by the only active P engine, that the rejection is expressed as a candidate signal which simply stays low, and that the picture is then consumed without reconstruction until the presentation scheduler fail-stops on a condition it cannot explain. That silence, not the capability gap itself, is what turned a documented subset boundary into a permanent freeze and into four misdirected repairs across Entries 284 to 287.

This commit adds a precise unsupported-feature report and changes no decode behaviour. The distinction it preserves matters, because `mpeg2_h262_p_diagnostic_controller_rearm.sv` deliberately records at its `probe_error` assembly that the historical controlled-pattern observers must not fail acceptance on their own documented subset rejections, since another observer may still own the picture. The new condition is narrower than that and does not disturb it: it fires only when no engine claims the picture at all, so nothing downstream will ever decode it. The wide motion syntax probe already evaluates every P picture's coding extension in one place and either raises `wide_candidate` or does not, so that evaluation point is where the rejection becomes knowable, and it exports a one-cycle rejection pulse rather than having the controller infer the same fact from timing. The controller raises `probe_error` with a new source code ten when that pulse arrives while no other candidate is engaged, which routes the condition through the existing acceptance and transport-drain path so the stream stops cleanly with an error flag rather than hanging with a correct final picture on screen.


Simulation confirms all four required boundaries. The complete corpus soak is byte-identical at 6,589,996 cycles with 22/22/47/47 publications and zero errors, and the focused scheduler regression is unchanged at cadence one, three, two with a minimum present gap of two and every case intact. A Big Buck Bunny clip carrying f_code five now fails at input byte 41,205, twenty bytes into the offending picture, reporting `probe_error_source` ten with `presentation_error` low; previously the same clip ran on to byte 60,823 and surfaced a presentation-scheduler error nineteen kilobytes past the real cause. The Entry 288 clip whose f_codes stay within one to four still decodes end to end at 24,049,996 cycles with zero errors, so content inside the supported envelope is unaffected. One correction was needed during implementation: routing the new condition through `p_error_raw` left it visible in diagnostics but still inert, because that path is gated by `b_picture_observed`, so the first attempt reported source ten and nonetheless hung. A hard capability gap is not a controlled-pattern observer's subset rejection and must reach acceptance ungated, which the committed version does. The fully clean Quartus 17.0.2 build completes in 11 minutes 14 seconds with zero errors, zero Critical Warnings and 136 standing warnings, at +0.151 ns global setup, +1.172 ns decoder setup, +7.689 ns video setup, +0.246 ns hold, +3.693 ns recovery, +0.915 ns removal and +0.462 ns minimum pulse slack, using 33,621 ALMs, 49,362 registers, 4,027,379 memory bits, 504 RAM blocks and 65 DSP blocks. The artifact is 4,365,644 bytes with SHA-256 `587f738006a1d4d78118be2072f255244e9b3d124136d3545bd4bc11308649ed`, and it is the first build in several cycles whose source matches the repository.

#### Next Steps:

Require the complete corpus soak to stay at exactly 6,589,996 cycles with 22/22/47/47 publications and zero errors, since no accepted stream may newly fail, and require the focused scheduler regression to remain unchanged. Require a Big Buck Bunny clip containing f_code five to report the new error instead of stalling, and require a clip whose f_codes stay within one to four, already proven decodable end to end in Entry 288 at 24,049,996 cycles with zero errors, to remain unaffected. Then rebuild, because the artifact currently on the MiSTer predates the probe fix in `73dada5` and no hardware result since then reflects committed source. After this lands, proceed to step two of the plan and isolate which term of the six-way condition raises `error_source` seven in `mpeg2_h262_p_motion_residual_raster_engine.sv`, instrumenting only and changing no RTL, with the documented bound of sixteen coded blocks and sixty-four coefficient events as the leading hypothesis. Note separately that thirteen RTL files cite `.ai/core-standards.md` as their standards authority and that file is absent from the repository, so the conformance rationale for those modules is currently unrecoverable.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 288 COMMIT Unreleased 73dada5 2026-08-21T00:44:24-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Identify why the P diagnostic controller never asserts its stream hold for the sixth P picture, which Entry 287 isolated as the reason that picture never reconstructs.

#### Outcome:

No source changed. The freeze is a decoder capability boundary, not a presentation-scheduling defect, which retires the entire line of investigation from Entry 283 onward and explains why four repairs in the scheduler could not work. Tracing the controller shows `stream_hold` reduces to `wide_parse_hold` or `raster_hold_active`, because `four_mb_parse_hold` and `legacy_parse_hold` are tied to zero and `old_stream_hold` is tied to zero. For the fifth P the trace records `wide_candidate` rising twelve cycles after the picture header and `wide_parse_hold` following thirteen cycles later, which is the backpressure that throttles the transport for the roughly 734,000 cycles that picture takes to reconstruct. For the sixth P the same trace records the header accepted and then no further transition of any kind: `wide_candidate` never rises, no engine engages, and the payload is consumed at one byte per cycle without producing a single reconstructed row.

The gate is explicit in `mpeg2_h262_p_wide_motion_syntax_probe_part3.svh`, where `wide_candidate` requires both forward f_codes to lie between one and four inclusive. Extracting the picture coding extension of every picture in the clip shows the sixth P carries f_code five in both components while every other P carries one or two, and the corpus streams never exceed four. That single picture is therefore rejected by the only P engine still active, and because rejection is expressed as a candidate signal that simply stays low rather than as an unsupported-feature error, the picture is silently swallowed. Nothing downstream can recover: it never completes, never publishes, never sets `pending_frame_valid`, and the queued-admission branch then fail-stops on exactly that condition. The silence is the more serious half of this defect, because an unsupported syntax feature that raises no error is indistinguishable at every downstream layer from a picture that is merely late, which is precisely the misreading that consumed Entries 284 through 287.

This also corrects Entry 283, which recorded f_code as eliminated. That elimination rested on a hardware test of a motion-capped stream run before the missing sequence_end_code was understood, so that stream could not have produced telemetry whatever the f_code did; the evidence was contaminated and the conclusion was wrong. Re-testing properly with both the cap and the terminator in place moves the failure rather than removing it. The capped clip now fails in simulation at input byte 42,062 inside the same sixth P with prediction error source two and detail seven, which resolves to the row-completion consistency check in `mpeg2_h262_p_motion_residual_raster_engine.sv`, where a completed row must carry exactly `mb_width` motion records. That picture therefore breaches at least two independent limits, so real content requires more than a single capability extension. Separately, the RBF currently in `output_files` and on the MiSTer was built from `1e68cf9` and predates the committed probe fix `73dada5`, so no hardware result gathered since then reflects the current source.

#### Next Steps:

Decide the scope question before writing any RTL, because it is a product decision rather than a technical one: whether v0.6.0 raises the supported f_code range to nine as H.262 permits and extends the P raster engine's row accounting, or whether it declares a documented compatibility subset and fails unsupported streams loudly instead of hanging. Both are defensible, and the second is far cheaper. Independent of that choice, make non-engagement explicit: every P engine candidate rejection should raise an unsupported-feature error that reaches the existing error flags and LED signature, so an unsupported stream reports rather than freezes, and so no future investigation mistakes a capability gap for a timing race. Only after that should the f_code range and the `mb_width` motion-record accounting be extended, each with its own bounded regression. Retain the separately identified coverage gap that no corpus stream exercises the queued admission path, both corpus streams reporting `queued=0 promoted=0`, and add a synthetic stream carrying f_code above four so this class is caught by regression rather than by the user's own media. Rebuild before any further hardware measurement.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 287 COMMIT Unreleased 73dada5 2026-08-21T00:18:53-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Establish why the P picture never publishes, which Entry 286 identified as the single unexplained fact blocking every candidate repair.

#### Outcome:

No source changed. The answer relocates the defect out of the presentation scheduler entirely, which invalidates the layer all four previous repair attempts targeted. Two hypotheses were tested and rejected before the real cause was found. The publication gate at `mpeg2_h262_two_picture_probe_p_chain.sv`, which refuses to publish while `b_picture_inflight` is high, looked like an exact match for a circular wait, but a tracer on that condition never fired once, so the picture never even reaches `base_picture_420_complete`. The stream-boundary hypothesis was also excluded by measuring byte geometry: the sixth P occupies bytes 41,185 to 60,815 and the transport stalls at 60,822, which is seven bytes into the following B picture header, so the start code that terminates the P's final slice had already been delivered and the picture was not starved of its own data.

The measured cause is that the P reconstruction path never engages for that picture at all. Tracing the probe's parser handshake shows `p_hold_effective` toggling continuously for roughly 734,000 cycles while the fifth P reconstructs, which is the backpressure that normally throttles the transport across a P picture, and shows it never asserting even once while the sixth P is consumed. The last assertion anywhere in the run occurs during the fifth P. With no backpressure the sixth P's 19,630 bytes are accepted at one byte per cycle in 19,630 cycles, and the picture-row counter confirms the consequence: it stands at exactly 150 rows for five completed pictures of thirty rows each, so the sixth P reconstructed nothing. A picture that reconstructs nothing never completes, never publishes, and never sets `pending_frame_valid`, which is precisely the condition the queued-admission branch fail-stops on.

The scheduler error recorded in Entries 284 through 286 is therefore a downstream symptom rather than the defect. This also explains why every repair failed on its own terms: deferring the run close addressed a branch never reached, holding from `overlap_decode_open` starved a P that genuinely needed its data, and deferring the queued admission with a hold at the B header livelocked because it waited on a publication that could never arrive no matter how long the wait. None of those repairs could have worked, because the picture they were all waiting for was never being decoded. The distinguishing property of that picture remains its size, 19,630 bytes against 1,157 to 3,104 for every other P in the clip and 3,388 to 4,830 across the corpus, but size alone is a correlation and the mechanism inside the controller is not yet identified. `p_hold_raw` originates in `mpeg2_h262_p_diagnostic_controller`, and its `p_picture_expected` input was checked and excluded: that signal is a sticky latch in `mpeg2_h262_picture_bookkeeper.sv` set on the first transition out of phase-1 support and never cleared, so it is high throughout.

#### Next Steps:

Trace inside `mpeg2_h262_p_diagnostic_controller` to find why it does not assert `stream_hold` for this picture, comparing its internal state directly against the fifth P where the same signal toggles normally. Its `p_picture_expected`, `p_persistence_complete` and `p_row_persistence_complete` inputs are the obvious first candidates, followed by whatever internal decision state governs `p_controls_seen` and `decision_complete` in the residual parser, since those gate the equivalent conditions there. Treat the presentation scheduler as correct until that trace shows otherwise, and do not attempt a fifth repair in that module. The three reverted scheduler experiments should not be revived even though two of them passed the corpus and the focused regression, because passing tests while fixing nothing is exactly how the first four attempts consumed a full development cycle. Retain the separately identified gap that no corpus stream exercises the queued admission path at all, both corpus streams reporting `queued=0 promoted=0`, and close it with a synthetic cross-run stream once the decode defect is understood. This remains the v0.6.0 blocker ahead of the 25 fps scratch-pool work.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 286 COMMIT Unreleased 73dada5 2026-08-20T23:47:12-07:00

#### Coming From:

Unreleased 73dada5

#### Purpose:

Trace the freeze at picture level before attempting a fifth repair, after three scheduler repairs were disproven.

#### Outcome:

No source changed. A simulation-only state tracer and the testbench's picture trace were run against the Big Buck Bunny clip on the committed baseline, and they explain the failure and the three failed repairs together. The decisive discovery is that the queued-run admission path added by Entry 269, which is where the failure occurs, has no coverage whatsoever in the regression corpus: both the long-GOP and the soak streams report `queued=0 promoted=0`, so that branch has never executed in any accepted regression. Real content is the first stream to reach it, which is why a defect there survived every prior commit.

The picture trace shows why the corpus never reaches it. In the accepted pattern the presentation run completes before the following B header arrives: at cycle 10,540,001 `presentation_complete` asserts and `reorder_active` falls, the P publishes 743,000 cycles later, `pending_frame_valid` rises, and only then does the B header appear, so the B is admitted through the ordinary fresh-run path and the queued path is bypassed entirely. In the failing sequence the run is still active when the B header arrives. The P header is accepted at cycle 13,042,608, the run closes with `overlap_decode_open` set one cycle later, the swap window at 13,050,001 leaves the run still open, and the B header arrives at 13,062,238 with `reorder_active` and `run_closed` both high. That reaches the queued-admission branch with `pending_frame_valid` low, and it fail-stops. Nothing throttles the early header because the existing `presentation_hold` expression contains `!overlap_decode_open`, and the trace confirms `presentation_hold` is low across the whole window while `queued_header_capacity` is already low.

The interval between that P header and the following B header is 19,630 cycles, which is exactly the byte length of that P picture, so the transport ran unthrottled for its entire payload. That P is the largest in the clip at 19,630 bytes against 1,157 to 3,104 bytes for every other P, while the corpus soak's P pictures are a uniform 3,388 to 4,830 bytes. Whatever the precise coupling, the distinguishing property is a P whose payload profile differs sharply from the synthetic corpus, and the earlier assumption that the trigger was simply high bidirectional density is too coarse to be the mechanism.

Three repairs were attempted, disproven and reverted before this entry, and each constrains the next. Deferring the run-closing branch left the corpus byte-identical but did not touch the failure, because instrumentation proved that branch is never reached. Holding the transport from `overlap_decode_open` was rejected immediately by the focused regression with "following P was not admitted during prior presentation", because that signal denotes a P that has just been admitted and still requires its own slice data. Deferring the queued admission and holding from the B header instead passed the focused regression with every case intact and kept the corpus at exactly 6,589,996 cycles, and it carried the Big Buck Bunny clip past the failing byte for the first time, but it then livelocked: the run completed with the admission still latched, so the retry condition could never fire, the latch never cleared and the transport stalled permanently with `presentation_hold` high. In that livelock the P never published even though its payload had been fully consumed, which is the single fact still unexplained and the reason no fourth repair is proposed here.

#### Next Steps:

Establish why that P fails to publish once the transport is held, because every remaining repair depends on the answer. If publication is reachable and merely slow, the deferred admission needs only a release path for the case where the run completes first, since the ordinary fresh-run admission is then the correct destination for the latched header. If publication genuinely requires further transport activity, then holding is unusable at any point in this window and the admission must instead be made to succeed against an unpublished reference by deferring the reference binding the way Entry 227 already does for the non-queued path. Instrument the picture-completion and writer-drain path for that specific P under a held transport to distinguish the two, rather than attempting another repair first. Separately, and independently of the fix, the absence of any corpus coverage for the queued admission path is itself a defect worth closing, because a regression suite that never executes a branch cannot protect it; a synthetic stream that forces cross-run admission would have caught this before real content did. Keep this ahead of the 25 fps scratch-pool work as the v0.6.0 blocker.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 285 COMMIT Unreleased 73dada5 2026-08-20T22:39:09-07:00

#### Coming From:

Unreleased ddcc8f3

#### Purpose:

Make a late reference publication a condition the publication probe waits for rather than fail-stops on, and locate precisely why the scheduler still fail-stops afterwards.

#### Outcome:

Only the probe layer is delivered. In `mpeg2_h262_two_picture_probe_p_chain.sv` the header-time comparison of `p_publication_count` against `p_header_count` no longer raises `publication_error`. It latches that the in-flight B transaction is waiting for its future reference, clears that state when the publication arrives, and raises the error with detail one only if the B reaches `b_persisted_now` while still waiting. This preserves the real invariant, that a B must not complete against an unpublished reference, while permitting the deferred binding Entry 227 introduced, and it matters beyond diagnostics because `b_user_success` is gated by `b_accept_error`, so a latched error permanently suppresses the completion edge the scheduler waits on. The complete corpus soak is byte-identical at 6,589,996 cycles with 22/22/47/47 publications and zero errors, and the focused scheduler regression is unchanged at cadence one, three, two with a minimum present gap of two.

The scheduler layer proposed in the previous revision of this entry was implemented, disproven and reverted, and the reasons are recorded because they constrain the correct fix. A first attempt deferred the run-closing branch when `future_reference_pending` was set, holding the transport until the publication bound. It left the corpus byte-identical but did not change the Big Buck Bunny failure at all, because instrumenting every `presentation_error` site proved that branch is never reached by this stream. That instrumentation initially misreported its site, because a blanket textual insertion of the deferred-state clear had been applied into a brace-less `else`, which made both the clear and the diagnostic unconditional; the file was reverted and the edit redone against a single audited site.

Correct instrumentation then identified the true failure exactly. It is the queued-run admission path added by Entry 269, at the branch guarded by `promotion_pending`, `pending_frame_valid` and `queued_scratch_available`, with the deciding state `pending_frame_valid=0`, `overlap_decode_open=1`, `queued_scratch_available=1`, `queued_header_capacity=0` and `presentation_hold=0`. Entry 247's overlap deliberately releases the presentation hold so one P may decode during presentation, and the existing hold expression contains `!overlap_decode_open`. When that overlapping P has not yet published, `queued_header_capacity` is low, so the next B header reaches an admission path that cannot succeed and fail-stops on a condition that is merely late. A second attempt therefore held the transport across that window. The focused scheduler regression rejected it immediately with "following P was not admitted during prior presentation", which is correct: `overlap_decode_open` denotes a P that has just been admitted and still requires its own slice data, so holding input starves it and it can never publish. The deadlock-safety argument that holds for the run-closing branch does not hold here, and the regression caught the difference. Both attempts were reverted; the committed source contains the probe change only, so the freeze is not yet fixed.

#### Next Steps:

Defer the queued admission rather than holding the transport, because holding is now proven to starve the very publication being waited for. Latch the B admission request when the queued path would fail only for the transient reasons `promotion_pending` or absent `pending_frame_valid`, leave the transport running so the overlapping P can finish parsing and publish, and complete the admission when `pending_frame_valid` or `frame_waiting` asserts. Keep `!queued_scratch_available` as a genuine fail-stop unless evidence shows it is also transient, since the Entry 282 measurement shows scratch exhaustion is a real resource limit rather than a timing artifact. The retry must not lose the B's coding-type event or its scratch-bank selection, and it must be proven against the focused regression's overlap, starvation, generation and fail-open cases before any full soak. Require the corpus soak to stay at exactly 6,589,996 cycles with zero errors and the 30-picture Big Buck Bunny clip to complete, then take a clean build and a paired hardware comparison. Treat this as the v0.6.0 blocker and keep the 25 fps scratch-pool work behind it.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 284 COMMIT Unreleased ddcc8f3 2026-08-20T21:38:55-07:00

#### Coming From:

Unreleased b9c2ddb

#### Purpose:

Determine whether the publication ordering rule that freezes real content is a correct invariant or an over-strict diagnostic, before changing any decoder logic.

#### Outcome:

It is both, and neither fix alone is sufficient. The question posed by Entry 283 is answered against the source: `mpeg2_h262_b_presentation_scheduler.sv` was given deferred future-reference binding by Entry 227, which explicitly accepts a B header arriving before its future reference publishes and binds that publication into the already open transaction when it later arrives. `mpeg2_h262_two_picture_probe_p_chain.sv` predates that capability and still fails at B header time whenever `p_publication_count` is below `p_header_count`. The two are in direct contradiction, and `MediaPlayer_top_05.svh` sides with the scheduler because its ownership hold arms only for a P successor, while the probe's own `p_hold_effective` is deliberately released as soon as a B candidate appears. Synthetic content never exposed the disagreement because its P pictures always publish before the following B header is parsed.

A simulation-only lenient probe, which counts the late-publication case instead of failing on it, isolates the two layers. The corpus control is unaffected: the complete soak replay is byte-identical at 6,589,996 cycles with 22/22/47/47 publications and zero errors, so relaxing that check does not perturb any accepted behaviour. The Big Buck Bunny clip, however, then fails one byte later at 60,823 instead of 60,822, this time with `presentation_error` from the scheduler rather than `probe_error`. The probe was therefore masking a deeper defect rather than causing the freeze by itself.

The scheduler defect is at the run-closing branch. When a non-B header arrives while `future_reference_pending` is set and no publication is arriving in that same cycle, the scheduler does not wait; it clears `reorder_active`, `run_closed` and `decode_inflight` and raises `presentation_error`. The recorded state `sched=0/0/0/2` matches that branch exactly, including the stale run count. The apparent `run_picture_count>=2` cause was excluded by checking coded order directly: the clip is `IPBBPBBPBB...` with at most two consecutive B pictures, structurally identical to both corpus streams, so no third B exists and the run simply failed to close. The single physical trigger for both failures is a P reference that publishes later than either layer assumes, which real photographic content produces because its P pictures carry far denser residuals and roughly sixteen times the bidirectional macroblock count of the synthetic corpus. Both layers respond to lateness by fail-stopping rather than by applying backpressure, and because `b_user_success` is gated by `b_accept_error`, a latched publication error also permanently suppresses the completion edge the scheduler waits on, which is why the hardware symptom is a permanent freeze with a correct final picture and a fully responsive OSD rather than a visible error.

#### Next Steps:

Treat lateness as a legal condition to be waited on rather than an illegal state to be trapped, in both layers, and change nothing else. In the scheduler, the run-closing branch should hold the pending non-B header until `future_reference_pending` clears instead of raising `presentation_error`, which requires proving that the publication is genuinely guaranteed to arrive so the hold cannot deadlock, and requires the parser backpressure to reach the transport without violating the Entry 247 overlap contract. In the probe, the header-time comparison should be replaced by a check at the point the B transaction actually binds or consumes its future reference, so that Entry 227's deferred binding is permitted while a genuine unpublished-reference consumption is still caught. Bound both changes in simulation before any Quartus build, requiring the corpus soak to stay exactly at 6,589,996 cycles with zero errors and the Big Buck Bunny clip to complete with correct publication counts, then validate on hardware with a paired control. Do not relax the probe alone, because the lenient experiment proves the scheduler fails immediately afterwards. This defect is a v0.6.0 release blocker for real content, and it should be fixed before resuming the 25 fps scratch-pool work, since a compatibility-focused player cannot ship a core that freezes after three pictures of ordinary video.

#### Files Modified:

- .gitignore
- tools/streams/generate_test_big_buck_bunny.py

#### Status:

- [x] Built
- [ ] Passed

---
## 283 COMMIT Unreleased b9c2ddb 2026-08-20T21:14:39-07:00

#### Coming From:

Unreleased 1e68cf9

#### Purpose:

Add a real-content test stream at the user's request and diagnose the reproducible playback freeze it exposes on the road to v0.6.0.

#### Outcome:

The user supplied an archived Big Buck Bunny source and asked for a playable elementary stream, which `generate_test_big_buck_bunny.py` now produces. The source is 854 pels wide and 24 fps, so it is scaled to the framebuffer's 720-pel `SRC_WIDTH` guard and resampled to frame rate code three to engage the cadence accumulator. The stream freezes on hardware after roughly three displayed pictures, reproducibly, with the MiSTer menu and OSD fully responsive and the last decoded picture retained on screen. The retained picture is visually correct with clean gradients and no artefacts, so this is a liveness defect and not a decode-correctness defect, and the user captured video confirming the OSD opens over the frozen frame. HDMI is confirmed as 1920 by 1080 at 60 Hz on the user's panel, matching the assumption recorded in Entry 281.

Two independent defects were found. The first is in the project's own tooling: FFmpeg 8.0.1 no longer emits the H.262 sequence_end_code, while the FFmpeg that produced the committed corpus did. Every committed stream ends with `000001b7`; every stream generated on the current host, including a synthetic `testsrc2` control built with the existing generator's exact flags, does not. The decoder's frontend needs that code to raise `sequence_end_seen`, and the cadence profiler publishes its telemetry overlay only once that is set, so any regenerated stream can never be measured and never quiesces. `generate_test_big_buck_bunny.py` now appends the terminator when the encoder omits it. This affects `generate_test_progressive_compatibility.py` and the other committed generators equally, which are not yet corrected, so the corpus is not currently reproducible on this host as the build environment policy intends.

The second defect is the freeze itself, and the terminator fix does not cure it. A `POST_INPUT_TRACE_CYCLES` watchdog was added to the soak testbench because the existing `STALL_TRACE_CYCLES` guard is gated by `stream_index<stream_len` and therefore cannot observe a decoder that accepts every byte and then fails to quiesce. With a 30-picture terminated clip the failure reproduces exactly in simulation at input byte 60,822 of 107,344, and it is a real error rather than a timeout: `probe_error` fires from `mpeg2_h262_two_picture_probe_p_chain.sv` with source four and publication detail one. That condition rejects a B picture header arriving while `p_publication_count` is below `p_header_count`, and the trace records six P headers observed against five publications. Because `probe_error` feeds `mpeg2_new_phase1_probe_error`, which `MediaPlayer_top_00.svh` treats as a fatal transport error, the transport drains and decoding stops permanently, which is precisely the observed freeze with a live OSD. Earlier hypotheses were eliminated with evidence: capping motion search so no f_code exceeds two did not change the failure, the macroblock symbol sets of the new and working streams are identical, the picture coding extension flags are byte-identical, no custom quantiser matrices are present, and the project's own analyser classifies both streams the same. The distinguishing property is density, since the new stream carries roughly sixteen times the bidirectional macroblock count, which lets a P picture still be persisting when the following B header is parsed.

#### Next Steps:

Establish before changing any RTL whether the publication ordering rule is correct or merely too strict for the overlap path. The rule is checked at B header time, but Entry 247 deliberately permits one P transaction to decode while a prior scratch and future sequence is presented, so a B header may legitimately be parsed while its future reference is still persisting provided the B decode itself waits for publication. Determine which of those two readings the surrounding logic actually implements, because the fix differs entirely: if the invariant is correct then the parser must be held until the observed P publishes, most likely by extending the existing `mpeg2_new_p_destination_ownership_hold`, and if the probe is too strict then it must distinguish header parsing from transaction acceptance rather than failing the transport. Do not relax a diagnostic that is protecting a genuine ordering requirement merely to make the stream play. Correct the remaining generator scripts to guarantee the sequence_end_code in the same cycle, then re-validate the corpus and the new stream on hardware with paired controls before treating v0.6.0 as reachable, and note that this liveness defect is a release blocker for real content while the synthetic corpus passes.

#### Files Modified:

- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 282 COMMIT Unreleased 1e68cf9 2026-08-20T20:17:12-07:00

#### Coming From:

Unreleased c98aeef

#### Purpose:

Replace the priority-encoded stall counters with unconditional hold, overlap and availability counters so the presentation-hold bottleneck can be attributed before any functional change is attempted.

#### Outcome:

Review of `mpeg2_h262_hardware_cadence_profiler.sv` established that the three existing stall counters cannot answer the question Entry 281 leaves open, because their attribution is a strict priority chain in which a non-ready decoder is counted first, presentation hold second and destination hold only third. The categories are therefore mutually exclusive by construction, a destination hold overlapping a presentation hold contributes nothing to `destination_stall_cycles`, and the Entry 281 claim that the third reference bank is provably idle does not follow from the zero destination stall standing since Entry 276; that claim is withdrawn. The profiler's `decoder_ready` input is confirmed to be the pre-hold `mpeg2_new_decoder_stream_ready`, so the holds do not feed back into their own counter and the existing totals remain valid for what they measure.

This commit adds five counters that increment whenever their own condition is true, independent of each other and of `fifo_pending`: total presentation hold, total destination hold, both holds together, presentation hold while a scratch destination is available, and presentation hold while a promotion is pending. Two pure observability outputs expose the scheduler's existing `queued_scratch_available` and `promotion_pending` terms; no scheduler logic, ownership rule or presentation behaviour changed. The snapshot grew from 21 to 26 words at schema version two, `OVERLAY_Y` moved from 512 to 492 and `OVERLAY_HEIGHT` from 84 to 104 so 26 four-pixel rows still end at line 596 inside the 600-line active area, and `decode_hardware_cadence.py` was updated in step. The first build was rejected before deployment: the overlay row multiplexer enumerated only rows zero to twenty, so the five new words rendered as the `default` zero and telemetry failed its checksum with a zero final word. Adding rows twenty-one to twenty-five fixed it. The second build then missed the positive-timing gate at minus 0.074 ns worst-case setup on a standing MiSTer framework clock while the decoder and video clocks stayed clean at plus 1.724 and plus 7.915 ns, the same class of miss Entry 257 recorded; that RBF was also rejected and not deployed. Changing the reproducible fitter seed from six to seven, with no source change, closed it. The accepted fully clean Quartus 17.0.2 build completes in 11 minutes 7 seconds with zero errors, zero Critical Warnings, plus 0.212 ns global setup, plus 1.417 ns decoder setup, plus 0.256 ns hold, plus 4.019 ns recovery, plus 0.683 ns removal and plus 0.462 ns minimum pulse slack, using 33,607 ALMs and 49,185 registers. Artifact SHA-256 is `525fa51f10496ff053bd2895fdd73c28c4c4c60cab224ffa4d268f07887c63f3`. The scheduler regression passes and regains the reset-aware consecutive-window monitor restored from Entry 280, reporting the 60.3165 Hz counts of one, three and two with a minimum present gap of two. The long-GOP soak replay passes on the reverted baseline at exactly 6,589,996 cycles with zero errors, reproducing the Entry 278 figure and confirming the revert restored that behaviour precisely.

Hardware reads schema two cleanly with 26 words, no validation failures, all 72 pictures, 71 swaps, 25 references, zero error flags and 23.501596 fps, confirming the instrumentation is cadence-neutral against the 23.6 fps baseline band. The result refutes both standing hypotheses. Destination hold total is exactly zero, so the hold is never asserted at all rather than merely masked by priority, and hold overlap is consequently zero; the masking mechanism was real but is not what was happening. Promotion-pending hold is 21 cycles, effectively never, so presentation hold is almost entirely `!queued_header_capacity`. Presentation hold totals 53,314,257 cycles, 32.1 percent of the session, and a scratch destination is available during only 8,057,481 of them, 15.1 percent. That bounds the proposed lookahead below the target: recovering every one of those cycles at zero cost would reach 24.7227 fps against a requirement of 9,777,856 cycles, so a one-picture lookahead cannot close long-GOP by itself. For the remaining 84.9 percent of hold cycles no scratch bank is free, which identifies the two-bank scratch pool rather than the reference destinations or the input gate as the binding resource.

#### Next Steps:

Stop pursuing the input-transport relaxation as a standalone fix, because its own ceiling is now measured at 24.7227 fps. Target the scratch pool instead, since 84.9 percent of presentation hold occurs with no scratch bank free and promotion is never the cause. Propose and bound a third scratch bank before implementing it, using the same zero-cost ceiling method that correctly rejected the destination predecode in Entry 270, and note that DDR already carries three reference banks plus two scratch banks so a sixth frame's address map and ownership tag width must be checked against the arbiter's three-bit displayed-region comparison from Entry 276. Pair any candidate with the 8,057,481-cycle lookahead saving only if both can be shown to compose, and continue to treat every projection as a lower bound because seven consecutive commits have shown removed cycles migrating into another stall category. A new real-content stream generator, `generate_test_big_buck_bunny.py`, is added at the user's request and produces a 720-by-480 25 fps long-GOP elementary stream from the archived Big Buck Bunny source; the source is 854 pels wide and 24 fps, so it is scaled to the framebuffer's 720-pel `SRC_WIDTH` limit and resampled to frame rate code three to engage the cadence accumulator. Its 250-frame default is 1,078,279 bytes and it is not yet hardware validated.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- MediaPlayer.qsf
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- tools/streams/decode_hardware_cadence.py
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [x] Passed
