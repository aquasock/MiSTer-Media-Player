## 693 COMMIT Unreleased ??? 2026-08-28T21:05:09-07:00

#### Coming From:

Unreleased 9956c8e

#### Purpose:

Measure how long the shared transport byte path stays blocked by video so the audio starvation fix can be sized from a real number.

#### Outcome:

This entry is the approved plan for the cycle and its commit does not exist yet. Entry 692 exonerated the helper and located the fault in the FPGA, at the single gate on the shared transport byte path in mpeg2_h262_inband_metadata.sv, where input_ready requires stream_ready, so a full clean video queue halts the whole byte path and every PCM record queued behind the held video byte stalls with it. The clean video queue is 65,536 bytes and the audio FIFO is 8,192 frames, which is 170 milliseconds at forty-eight kilohertz, so audio survives only as long as the path is blocked for less than that. The one quantity that decides the correction is unmeasured: the distribution and maximum of the continuous interval during which the extractor is blocked. Simulation cannot supply it, because reaching the eighty-four second failure point would require roughly five billion cycles against the three seconds entry 687 could afford, so the measurement has to come from hardware counters. This cycle therefore adds free-running profiler counters for the longest continuous blocked interval, the number of blocked intervals above a threshold, and the minimum audio FIFO level reached, latched into the existing snapshot alongside the first error flag, and extends the screenshot decoder to report them. It changes no datapath, no FIFO size, no scheduling decision and no output byte, so playback behavior is expected to be identical apart from the new telemetry. A Quartus build and one two-minute hardware run past the failure point follow, and the measured maximum blocked interval then decides between a bounded video lookahead that lets the extractor reach the next PCM record, a deeper audio FIFO justified by that number rather than chosen to be larger, and separating audio from video backpressure outright. No correction is designed before that number exists.

#### Next Steps:

Build the counters, compile in Quartus, install the resulting RBF after separate user authorization with the current accepted bitstream backed up, and run the same file over S/PDIF for about two minutes while capturing the log and snapshot. Read the maximum blocked interval against the 170 millisecond audio budget and choose the correction from it in the following cycle, preferring a fix that removes the coupling over one that widens a buffer, since widening only moves the threshold and both entry 687 and entry 688 already warned against it. Keep the helper at 9956c8e for that run so the two sides remain separable, and treat the profiler's first-error snapshot latch as a known limitation that hides recurrence until a counted underrun record replaces it. The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

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

## 680 COMMIT Unreleased c124aa5 2026-08-28T12:54:31-07:00

#### Coming From:

Unreleased c124aa5

#### Purpose:

Record the approved seed-19 rebuild and its remaining HDMI setup violation.

#### Outcome:

Source c124aa5 changes exactly one assignment, Quartus seed 18 to 19, with all functional sources, simulation inputs, clocks and timing constraints unchanged. The build PC pulls the published source into a fresh checkout and revalidates all retained native, paired and focused evidence hashes; both native analyzers reproduce their qualified results using only the approved terminal-cut exception, and all six qualification tests pass. One clean Quartus 17.0.2 seed-19 compile finishes in 763.2 seconds with zero errors and 206 warnings, but fails setup timing on csync_hdmi csync_vs to hs in the HDMI domain at minus 0.013 ns slack and TNS. This is a different path from seed 18's minus 0.002 ns scaler RAM-output failure. MPEG setup passes at plus 1.186 ns and video setup at plus 2.953 ns; every other timing category passes, with minimum hold plus 0.246 ns, recovery plus 3.492 ns, removal plus 0.629 ns and pulse width plus 0.925 ns. Resources are 33,005 ALMs, 52,220 registers, 4,054,267 RAM bits, 514 of 553 M10Ks and 67 DSPs. All four eight-bit inverse-quantization weight boundaries and expected film CDC endpoints remain present. Warning sets are unchanged from seed 18, including the existing unused last_bound_reference_count and timing-failure warnings. The rejected RBF is 4,373,716 bytes with SHA256 7b47518c472e52c4953cc516fdea316072b4438a6be84c6fb9e92d69d34b6b98 and stays on the build PC without packaging or installation. The MiSTer is reachable this turn, and read-only FTP hashes confirm Main, helper, original opening and existing dated and undated cores match the recorded files; no device write, reload or playback occurs. Complete build data remains at /home/vash/mister-builds/entry679/FPGA, with local reports under output_files/entry679 and committed evidence under .ai/current_results/entry680_*. No second reseed is attempted.

#### Next Steps:

Pause after this single authorized reseed and obtain renewed approval before another build or any logic or timing-constraint change. Compare HDMI placement and margins across the retained seed-18 and seed-19 paths: the negative slack moved from the scaler RAM output to sync control, while MPEG decode remains positive. Preserve all qualification evidence and the unchanged strict timing gate. Do not install either rejected image; original-audio hardware validation awaits a timing-passing candidate.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 679 COMMIT Unreleased c124aa5 2026-08-28T12:38:01-07:00

#### Coming From:

Unreleased e6ca129

#### Purpose:

Perform one approved seed-only rebuild after seed 18 missed HDMI setup timing.

#### Outcome:

The user authorizes a reseed following entry 678. Source c124aa5 changes only the seed assignment from 18 to 19; the single-line diff is verified and published, and the build has not yet started. Change only the Quartus fitter seed from 18 to 19 in MediaPlayer.qsf, preserving production RTL, clocks, timing constraints, physical buffers, Main, helper, test fixtures and the approved terminal-cut qualification boundary. Verify the complete source difference and retain the already qualified native and paired numerical evidence because no functional or simulation input changes. Use a separate clean build directory at /home/vash/mister-builds/entry679/FPGA and retain the failed seed-18 build intact. This authorization covers one new compile, not an automatic seed sweep; if compilation or any timing category fails, pause again without installation or further retries.

#### Next Steps:

Publish the seed-only source, pull it on the build PC, verify retained qualification and run one fresh seed-19 compile. Audit every timing category, warning changes, resources and retained weight-register and film CDC boundaries. If every gate passes, package the dated RBF and use the existing installation authorization only after preserving the old core and verifying FTP readback on the reachable MiSTer. Leave core loading, original-audio playback and hardware acceptance to the user. Record the outcome and pause on any build or timing failure.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---

## 678 COMMIT Unreleased e6ca129 2026-08-28T12:35:54-07:00

#### Coming From:

Unreleased e6ca129

#### Purpose:

Record the single approved seed-18 build and pause on its HDMI setup timing failure.

#### Outcome:

Both retained full native traces qualify at e6ca129 with the explicitly approved fixture-pinned one-field terminal-cut exception, while their strict raw cadence results remain false and every interior cadence, metadata, timestamp, cache and paired numerical check remains intact. The gate verifies simulation and synthesis inputs unchanged from e876bf3, and all six exception tests pass locally and on the build PC. One clean Quartus 17.0.2 seed-18 compile from the published e6ca129 source finishes in 975.0 seconds with zero errors and 206 warnings. Quartus internally increases routing optimization after two initially unrouted signals and ultimately fits within this same invocation; no manual retry occurs. The build fails timing on one HDMI scaler RAM-output-to-o_hpixs.g[1] path at minus 0.002 ns setup and minus 0.002 ns TNS, with neighboring paths at plus 0.003 and plus 0.015 ns. MPEG setup is plus 1.374 ns and video setup is plus 2.498 ns. All other timing categories pass, with minimum hold plus 0.172 ns, recovery plus 4.000 ns, removal plus 0.548 ns and pulse width plus 0.925 ns. Resources are 32,924 ALMs, 52,170 registers, 4,054,267 RAM bits, 514 of 553 M10Ks and 67 DSPs. All four eight-bit inverse-quantization weight boundaries and expected film CDC endpoints remain present. Warning comparison adds only the assigned-but-unused last_bound_reference_count warning and the timing-failure warning; fitter warnings are unchanged. The rejected RBF is 4,383,728 bytes with SHA256 9a61f9f8becce917a0941a196e1fa2d0134d52d658c68cf221843decfc137e84 and remains on the build PC without packaging or deployment. Evidence is retained under .ai/current_results/entry678_* and output_files/entry675, with the complete build at /home/vash/mister-builds/entry675/FPGA. The earlier read-only MiSTer preflight again returned no route to host; no device writes, core loads or playback occur. Work pauses at the timing gate as requested, with no seed retry, timing waiver or further source change.

#### Next Steps:

Reevaluate the HDMI scaler RAM-output path and its neighboring low-margin paths before proposing a further approved timing-closure cycle. The observed failure is in unchanged scaler logic rather than the MPEG decode clock domain, but the tiny negative slack remains a failure and must not be waived. Preserve the qualified decoder source and all raw simulation evidence. Do not install this RBF or start another build without renewed approval. Hardware playback of the original opening with audio remains pending a timing-passing candidate and a reachable MiSTer.

#### Files Modified:

- tools/streams/analyze_original_dvd_timing.py
- tools/streams/test_original_dvd_timing.py
- docs/testing_original_dvd_opening.md

#### Status:

- [x] Built
- [ ] Passed

---

## 677 COMMIT Unreleased e6ca129 2026-08-28T12:14:27-07:00

#### Coming From:

Unreleased e876bf3

#### Purpose:

Apply the approved narrow terminal-cut qualification exception and perform one clean seed-18 FPGA build.

#### Outcome:

The user approves proceeding with the build after the request to accept only the verified one-field adjustment at the artificial clip ending. Source e6ca129 adds the explicit fixture-pinned exception, negative mutations and documentation; all six analyzer tests pass locally. The strict result and raw mismatch remain unchanged while the separate qualification result records the opt-in exception. Preserve the strict simulation result and all raw mismatches, add an explicit opt-in qualification result pinned to the tested fixture and final P285-to-I288 transition, and require that the final picture was already ready at the missed boundary. Missing or duplicate pictures, metadata and timestamp errors, incomplete terminal hold, cache errors, other cadence gaps, larger terminal gaps and unknown fixtures must still fail. Validate the exception against the complete retained traces and negative mutations. Production RTL, simulation inputs, clocks, physical buffers, constraints, Main, helper and seed remain identical to the fully simulated e876bf3 boundary. Reuse the verified native and paired numerical evidence only after confirming all simulation and synthesis inputs are unchanged. No FPGA build has yet started.

#### Next Steps:

Publish the approved qualification change and its exact final source hash, verify both existing complete traces with the explicit exception, then pull that source on the build PC and perform the single fresh seed-18 Quartus compile using the prepared entry675 build directory. Audit all setup, hold, recovery, removal and pulse-width categories, warning changes, resources and retained register/CDC boundaries. Stop without seed retries if compilation or timing fails. Package only a qualified timing-passing RBF; installation remains authorized only with backup and FTP readback verification when the MiSTer is reachable, and playback remains user controlled.

#### Files Modified:

- tools/streams/analyze_original_dvd_timing.py
- tools/streams/test_original_dvd_timing.py
- docs/testing_original_dvd_opening.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 676 COMMIT Unreleased e876bf3 2026-08-28T05:22:54-07:00

#### Coming From:

Unreleased e9041b2

#### Purpose:

Record complete drain-overlap qualification and the verified terminal-cut exception requiring approval before a build.

#### Outcome:

Production e9041b2 and final test source e876bf3 complete both ideal and contended native opening runs with all 289 pictures once in display order, 288 swaps, all 25 associated timestamps, correct complete descriptors, clear cache/phase/overlap flags and zero interior cadence mismatches. The formerly late B116 now completes 101,729 decoder clocks before its selection boundary in the contended case. Focused I/P/B/end drain ownership, earlier completion and timestamp cases, broad scheduler, native integration and mixed-raster controls pass. The film fixture is corrected to assert reference completion when scratch is displayed, matching the production top-level wiring; the prior admission assertion now requires distinct future, primary and decode identities instead of forbidding the newly bounded transaction. Paired reconstruction passes all 149,817,600 samples per case with unchanged source fingerprint 3548c9a1f2489b0ba37c77d27367e0143c8434598667a06866126434317429e8 and pixel CSVs identical to entry 665, preserving isolated maximum one, real-reference maximum five, 102 old fixed-two exceedances and zero measured propagation-bound violations. The unchanged strict cadence gate still rejects both runs because the final P285-to-I288 transition takes four fields instead of three. An exact-prefix comparison against the source VOB proves the 12-second cut stops after open-GOP I288 with temporal reference two and omits following coded B289 and B290, which belong before that I in display order. Those omitted pictures carry five authored fields; removing them creates the only field-parity discontinuity in the fixture. I288 is already decoded well before the boundary and waits one additional physical field to preserve its bottom-first descriptor. H.262 clauses 6.3.10 and 7.12 are rechecked against the existing official controlled edition; this hold is a display recovery for the edited cut, not a general standard allowance. The user has been asked to approve only that verified one-field terminal exception while retaining every other gate, and has not yet responded. No exception is applied, no Quartus build has started and no MiSTer write occurs. Two read-only FTP attempts to 10.10.0.30 fail with no route to host. Detailed evidence and source-check scripts are retained under .ai/current_results/entry676_* and output_files/entry675; all test processes have completed on the build PC.

#### Next Steps:

Wait for explicit approval before changing the qualification boundary for the one-field terminal-cut adjustment. Preserve strict raw analysis as failing and keep this verified fixture exception separate from actual deadline misses; do not waive any interior gap, missing picture, metadata, timestamp, cache or numerical failure. If approved, encode and test a narrow reproducible exception, publish the exact final build source, then perform the single clean seed-18 Quartus build with timing, resource and warning audits. Prepared build scripts are under /home/vash/mister-builds/entry675 but have not run. Pause on build failure without seed retries. Install only after qualification and timing pass and the MiSTer is reachable, preserving old cores with FTP readback verification, and leave original-audio replay and hardware acceptance to the user. If the exception is declined, obtain an approved complete-GOP fixture boundary before proceeding.

#### Files Modified:

- tools/streams/tb_h262_film_reorder_timestamp.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 675 COMMIT Unreleased e9041b2 2026-08-28T04:58:36-07:00

#### Coming From:

Unreleased 18d9189

#### Purpose:

Complete the approved third-bank reference ownership work across a closed B-run drain.

#### Outcome:

Implementation e9041b2 adds the guarded drain transaction and I/P/B/end ownership tests; focused validation is starting. The 18d9189 full-opening comparisons remain unchanged while running. Both retain every observed picture and descriptor, and ideal memory has no cadence mismatch so far, but contended memory exposes coded B115-to-B116 taking four fields instead of two. B116 completes 4,845 decoder clocks after its required selection boundary, while the ideal case completes 18,194 clocks before it. Neither B transaction has presentation hold; the preceding P112 was held for 2,699,879 clocks while a completed B run still presented its scratch and future frames. Refine the already approved I/P/B overlap ownership without adding physical banks: once all old B prediction work is complete, allow the next ordinary reference into a bank distinct from the retained future, primary pending and actual displayed ordinary frame, while retaining its completion in the existing secondary slot. Preserve display protection until scratch presentation releases the old bank, block any further reference payload at full capacity, and retain a following B classification until the old future retires. New I/P/B/end transition checks must cover the retained three-bank identities and ordered resume. No arithmetic, clock, constraint, seed, Main, helper or device change is planned, and no FPGA build has started.

#### Next Steps:

Publish and exercise the drain refinement with focused timestamp, scheduler, native and mixed controls. Let the fixed-source 18d9189 runs finish as comparison evidence and preserve their numerical fingerprints before pulling the build-PC checkout. Require replacement complete ideal and contended native traces to satisfy the unchanged strict cadence gate and repeat paired numerical qualification on the final source before the single clean seed-18 FPGA build. If those gates or the build do not pass, do not install or retry seeds; retain the evidence and reevaluate any further change against the approved boundary.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/run_film_presentation.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 674 COMMIT Unreleased 18d9189 2026-08-28T04:44:23-07:00

#### Coming From:

Unreleased 30f3c6d

#### Purpose:

Record complete retirement-fix evidence and qualify corrected B lookahead before the authorized FPGA build.

#### Outcome:

Both full retirement-only native runs at dd0dc52 finish with 289 unique ordered publications, 288 swaps, all 25 associated timestamps, no descriptor or timestamp mismatches, clear cache/phase/overlap flags and pixel reports byte-identical to entry 665. They still have nineteen cadence delays totaling forty-one extra fields and are not timing passes. The approved P-overlap source 30f3c6d removes the initial ordinary-P delays, but its later full traces expose a remaining P80-to-B82 miss because B payload waits unnecessarily for primary presentation; those runs are stopped with their partial failure evidence retained. Production refinement d70b18f allows B scratch decode after the secondary reference completes while keeping the older ordinary reference first in presentation order, and holds any following I/P payload until that older presentation frees the display bank. Focused I/P-to-B cases before, with and after completion, late completion after primary display, full-slot backpressure, following-I protection, timestamps, film cache, scheduler rates and native timing integration pass at c4aec5e. Two test-fixture corrections enable native overlap explicitly and wrap the physical reference bank over three regions; neither weakens the ownership assertions. Paired reconstruction runs on 024158a and d5274d7 both pass with unchanged source fingerprints and CSVs identical to entry 665, preserving isolated maximum error one, real-reference maximum five, 102 old fixed-two exceedances and zero measured propagation-bound violations. Final source 18d9189 changes only documentation after the latest tested RTL. Full final native runs and paired reconstruction are next, using /home/vash/mister-builds/entry673. No Quartus build or MiSTer write has occurred. A read-only FTP attempt to 10.10.0.30 returns no route to host; the user has been asked to power it on for eventual installation.

#### Next Steps:

Pull the final source into both build-PC checkouts, run ideal_v2 and contended_v2 with the strict full-trace gate and repeat paired reconstruction without changing its source during execution. Require all 289 pictures once in order, correct complete descriptors and timestamps, zero authored-cadence mismatches and preserved pixel bounds. Only after every gate passes perform the single clean seed-18 Quartus build and timing/resource/warning audit, then preserve existing cores and install by verified FTP readback if the MiSTer is reachable. Pause on build failure without seed retries, and leave loading and original-audio playback to the user.

#### Files Modified:

- docs/testing_original_dvd_opening.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 673 COMMIT Unreleased 30f3c6d 2026-08-28T04:19:48-07:00

#### Coming From:

Unreleased dd0dc52

#### Purpose:

Extend ordinary reference decode overlap to P pictures using existing frame banks with explicit I/P/B transition ownership.

#### Outcome:

Implementation 30f3c6d extends the existing ordinary overlap to I/P headers, retains early B classification until the older ordinary reference presents, then binds the secondary reference before admitting B payload. Focused validation is starting in a separate checkout while comparison runs remain unchanged. The user explicitly approves the expanded overlap boundary after the full-opening trace exposes ordinary P serialization missing authored field slots despite repaired metadata ownership. Preserve the existing three ordinary reference regions and two scratch regions, permit a P transaction only when its destination is distinct from every retained or displayed ordinary frame, and retain completed primary and secondary identities until classification and presentation permit their retirement. Handle following I, P, B and sequence-end events across early, coincident and late completion without overwriting pending references or binding the wrong future reference. Prepare transition tests while the refined retirement runs finish; keep fixed-source numerical evidence separate from subsequent source changes. Clocks, physical buffers, timing constraints, placement seed, decoder arithmetic, Main and helper remain unchanged. No new build or installation is yet performed.

#### Next Steps:

Publish this approved expansion, finish the active checks, implement and exercise explicit reference-slot admission and secondary-to-B ownership handoff, and retain strict display-bank protection and terminal draining. Re-run focused ownership, timestamp and film tests, both complete 289-picture native memory cases and the paired reconstruction qualification on the final source. Require each picture once in display order, complete per-picture metadata and authored cadence before one clean Quartus build and full timing and warning review. Install only a verified timing-passing candidate with backup and FTP readback hashes, leave replay user controlled, and pause without speculative seed changes if build qualification fails.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/run_film_presentation.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 672 COMMIT Unreleased dd0dc52 2026-08-28T04:19:05-07:00

#### Coming From:

Unreleased 024158a

#### Purpose:

Record the refined early-reference release correction and the full native qualification gate while simulation remains in progress.

#### Outcome:

Initial production fix 024158a passes both entry-670 reduced failures, the metadata handoff matrix, film cache cases and the broad scheduler regression. Its native runs expose a further instance of the same classification-retirement failure: an early P header one clock before I-picture 60 completes fails to release that I, allowing its pending identity to be overwritten. Refined production source 197338a retains reference-header completion permission, and the new EARLY_P_RELEASE regression plus all existing film and scheduler controls pass. Test source dd0dc52 adds full descriptor and ordinary-bank ownership tracing, bounded retirement assertions and a strict simulation gate for complete ordered publication, metadata and authored cadence. The two superseded native runs are stopped by targeted SIGTERM after retaining their failures; no complete-run pass is claimed for them. Replacement ideal and contended runs use dd0dc52 in /home/vash/mister-builds/entry671/ideal_v2 and contended_v2 from the separate /home/vash/mister-builds/entry669/native_source checkout. Paired numerical and broader native controls continue on the unchanged 024158a source in the main build-PC checkout, which must not be pulled until their fingerprint check completes. A distinct cadence limitation is also measured in the first run: ordinary P decoding is serialized until predecessor presentation, and picture 41 completes 12,105 decoder clocks after its due window, causing two extra fields; other P and reference-plus-B readiness misses recur. Extending ordinary third-bank overlap beyond its deliberate I-only rule has been proposed to the user and is not yet approved. No Quartus build, clock, buffer, constraint, seed, Main, helper or MiSTer change occurs.

#### Next Steps:

Finish the refined full-opening tests and numerical controls, retain exact source versions and evidence, and correct any remaining admission or retirement failures within the approved boundary. Do not accept a run merely because all pictures decode: require unique ordered publication, full descriptors, timestamps and authored cadence. Obtain explicit approval before extending the ordinary overlap rule to P pictures with I/P/B transition ownership tests. Keep the FPGA build and installation blocked until all qualification gates pass; if an approved clean build later fails, pause without seed retries.

#### Files Modified:

- tools/streams/tb_h262_live_native_presentation.svh
- tools/streams/analyze_original_dvd_timing.py
- tools/streams/test_original_dvd_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 671 COMMIT Unreleased 024158a 2026-08-28T04:04:55-07:00

#### Coming From:

Unreleased c8bd628

#### Purpose:

Correct DVD picture admission and completion metadata ownership before qualifying and installing a new playback candidate.

#### Outcome:

The user approves the production fix, focused and full-opening validation, one clean timing-audited FPGA build and verified installation. Initial implementation 024158a retains a separate retiring descriptor, blocks a following reference payload during B drain, preserves its release classification and removes stale promotion-count permission to bind an already displayed reference. Focused validation is in progress; no FPGA build or installation is yet performed. Entry 670 establishes reference over-admission during B drain and an early following-header race in reference binding and metadata retirement. Preserve retiring picture identity, timestamp validity and field descriptors until persistence; distinguish accepted header classification from payload capacity; retain same-edge release events and bind an early B header to its actual completing reference. Keep decoder arithmetic, physical buffers, clocks, constraints, Main, helper and placement seed unchanged. Development and commits remain on the Pi master branch, with resource-intensive checks and compilation on the build PC at 10.10.0.42. Installation on MiSTer 10.10.0.30 is conditional on passing simulation and timing, and playback remains user controlled.

#### Next Steps:

Publish this approved proposal, implement the scheduler and metadata-owner correction, and require both reduced failures to pass alongside existing film, timestamp and ownership regressions. Run the full 289-picture original opening under both documented memory-service cases, requiring each picture once in display order with its own metadata and authored cadence, plus unchanged paired numerical bounds. Only after these gates pass, publish the exact build source and perform one clean Quartus build with timing, resource and warning review. If the build fails, pause for reevaluation without seed retries. If it passes, preserve the installed candidates, transfer and hash-verify the new core without changing Main or helper, and provide original-audio replay instructions and recorded evidence. Stop for approval if new findings materially change this boundary.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/tb_h262_picture_timestamp.sv
- tools/streams/run_film_presentation.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 670 COMMIT Unreleased c8bd628 2026-08-28T03:19:40-07:00

#### Coming From:

Unreleased 77859f9

#### Purpose:

Record full native-film reproduction of the original DVD stutter and isolate reference-admission and metadata-retirement failures.

#### Outcome:

The approved diagnostic completes on GUNSMOKE without changing production RTL, Main, helper, clocks, constraints, placement seed or the MiSTer. Native trace binaries use source e029f4f, numerical controls use 94b60b2, reduced regressions use 5548e4e and final analysis uses c8bd628. Both complete 289-picture runs, with one-cycle DDR reads and with sixteen-cycle reads plus sixteen busy cycles per 256-cycle period, produce 280 framebuffer publications, 279 bank swaps and 278 unique pictures: eleven decoded pictures are skipped and coded pictures 71 and 95 are repeated. The three largest bank-selection gaps match hardware ordinals 57, 71 and 89 and durations 116.815, 100.100 and 83.448 milliseconds to within one decoder clock. Both runs also match the hardware's 24 associated timestamps. The unique-picture counts are simulation evidence; the hardware barcode itself does not identify each picture. Seventeen published I-pictures carry stale TFF/RFF flags and the first picture loses PTS validity. A reduced admission test fails because a following P payload is permitted while the pending reference slot remains occupied during B drain. A second reduced test fails when a B header arrives one clock before its I-reference completion: the scheduler retains an older P bank and the metadata owner drops the retiring I descriptor. Both default controls pass. The full paired reconstruction qualification passes all 149,817,600 samples per run with unchanged source fingerprints; its CSVs and both native real-reference CSVs match entry 665 exactly, preserving maximum isolated error one, maximum real-reference error five, 102 samples above the old fixed-two bound and zero measured propagation-bound violations. Native cache, phase and overlap error flags remain clear. All twenty-five helper timestamps agree with authored cadence within 2.5 ticks, so the earlier terminal-gap caveat must not be applied to this actual transport as an explanation for the pauses. Initial harness attempts exposed a missing test RAM model, excessive legacy logging and a fast-soak watchdog limit of 10,000 cycles; the model is reused, logging bounded and native waits given a four-field diagnostic watchdog while the old default limit remains unchanged. Detailed traces, reduced failures, passing controls, source fingerprints and analysis are retained under .ai/current_results/entry670_* and output_files/entry669; PC working evidence remains in /home/vash/mister-builds/entry669. No new Quartus build or hardware acceptance is claimed.

#### Next Steps:

Obtain approval for a production fix that preserves retiring picture identity, PTS and field descriptors across the following-header handoff, blocks following P/I payloads when reference capacity is occupied, and binds early B headers to the actual completing reference. Require both reduced regressions to pass and all 289 pictures to publish once in order with correct metadata and authored film cadence under both memory cases, while retaining the paired numerical bounds. Only then perform a clean timing-audited FPGA build and retest original audio playback; additional shared audio-delivery coupling remains unexcluded. Do not change buffers, clocks or placement seeds speculatively.

#### Files Modified:

- tools/streams/analyze_original_dvd_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 669 COMMIT Unreleased 77859f9 2026-08-28T02:38:57-07:00

#### Coming From:

Unreleased 6c1b621

#### Purpose:

Trace the complete original DVD opening with native film timing and original timestamps to isolate silent playback stutter.

#### Outcome:

Diagnostic source 77859f9 is published after the user approves simulation and diagnosis before another FPGA build. The source extends the existing full-opening raster test with an opt-in native presentation path using the production timing generator, picture timestamp owner, presentation timeline and framebuffer publication feedback, keeping the production RTL unchanged. Preserve original elementary bytes and sparse timestamp positions through deterministic fixture preparation, add unique picture identity and readiness/publication traces, and exercise shared display/prediction memory service with explicit model parameters. Retain the default reconstruction regression and its measured error bounds. Treat any discrepancy first as either a harness fidelity issue or a production behavior to isolate, not automatic proof of the hardware root cause. The diagnostic development runs on GUNSMOKE; no MiSTer replay, configuration change, deployment, Quartus compile or seed change is approved in this boundary.

#### Next Steps:

Publish the diagnostic source from the Pi, pull it on the build PC, run the complete 289-picture opening with native field cadence and original PTS, and compare controlled memory-service conditions. Trace decode completion, candidate readiness, ownership holds, field eligibility and actual framebuffer publication using identities wider than the old eight-bit counters. Separate legal two/three-field holds and the terminal timestamp gap from missed presentation opportunities, verify the old numerical checks still apply, and record a reproducible explanation or remaining evidence gap before proposing a production fix.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_live_native_presentation.svh
- tools/streams/prepare_original_dvd_timing.py
- tools/streams/run_original_dvd_timing.sh
- tools/streams/analyze_original_dvd_timing.py
- docs/testing_original_dvd_opening.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 668 COMMIT Unreleased 6c1b621 2026-08-28T02:36:27-07:00

#### Coming From:

Unreleased 6c1b621

#### Purpose:

Capture silent original-opening stutter and identify the remaining native-film timing coverage gap.

#### Outcome:

The user reports several severe stutters near the beginning of the silent comparison, improving toward the end, with the diagnostic overlay available. The helper log confirms dvd_opening_video_only.mpg, and FTP readback verifies the unchanged silent stream, dated candidate, preserved undated core and Main. Two screenshots are byte-identical and produce matching checksum-valid schema-19 telemetry. Unlike entry 667's early audio-underrun snapshot, this run reaches quiet sequence end with presentation complete, zero error flags, zero PCM samples, 128 reference pictures and 161 B pictures, accounting for all 289 coded pictures. Stutter therefore persists without audio; audio processing is not a necessary cause, although additional coupling in the original run remains possible. The profiler reports 280 display pictures and 279 swaps over 12.8823 seconds, but source inspection shows these are derived from first-reference completion and bank/scratch selection changes rather than unique picture publications, so the difference does not establish nine dropped pictures. Its three largest bank-change gaps are 116.8151, 100.1 and 83.4484 milliseconds at recorded ordinals 57, 71 and 89. Their retained threshold-crossing states show upstream data pending, decoder not ready, no presentable candidate and neither presentation nor destination hold; these samples prioritize video readiness and ownership/cadence investigation without proving one cause or the state throughout each gap. The fixed-29.97-frame deadline and outlier counts are not valid failure totals for two/three-field film pictures. Main completes all 10,334,393 video-plus-PTS bytes at log time 12.758744 seconds, with helper exit zero and no slow-path bytes. Review of the full-opening numerical runner reveals that its scheduler ties native film, field/publication feedback and timestamp inputs off and uses synthetic 10,000-cycle swap windows; that reconstruction pass does not cover integrated hardware film timing. Existing focused film tests remain valid within their narrower scope. Capture, helper log, decoded telemetry and source-grounded analysis are retained under .ai/current_results/entry668_*. No production source, device configuration, build or playback action is changed, and hardware acceptance remains open.

#### Next Steps:

Obtain approval to extend the existing simulation coverage for the complete original opening with native field cadence, original timestamps, publication feedback and realistic memory contention, tracing unique picture identity, decode readiness, ownership holds, cadence eligibility and actual publication. Reproduce and isolate the video stall before selecting a production fix or another FPGA build; distinguish legal three-field holds and the known terminal timestamp gap from real misses, and reconcile the bank-derived counters against actual publications. Preserve the numerical reconstruction bounds and then retest the original audio path. No new files or user replay are needed for the evidence already collected.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 667 COMMIT Unreleased 6c1b621 2026-08-28T02:26:37-07:00

#### Coming From:

Unreleased 6c1b621

#### Purpose:

Capture original-opening playback with correlated audio/video stutter and prepare an unchanged-video silent comparison.

#### Outcome:

Following the instruction to load the dated candidate, the user reports that the original opening plays and the picture looks good when motion is smooth, but video stutters roughly every second and audio becomes scratchy at the same moments; the diagnostic overlay appears during playback and at the end. Two screenshots are byte-identical and show the Universal opening image. Checksum-valid schema-19 telemetry is an early latched error snapshot at 1.79571835 decoder-session seconds, not final playback totals: 327,302 accepted video bytes, 41 displayed pictures, 40 swaps, 23 reference and 20 B pictures, frame-rate code four, and error flags 0x0400 for audio underrun alone. Syntax, decode, reconstruction, buffer-ownership, PCM protocol and presentation error bits are clear at that instant, which does not prove the remainder of playback error-free or quantify image accuracy. The overlay profiler captures any nonzero error flag immediately and cannot update its totals afterward, explaining its appearance before playback finishes. PCM sample count 16,383 and FIFO-peak value 127 are saturated diagnostic fields, not actual buffer capacity; the PCM FIFO has 8,192 stereo samples. The 39 native deadline events use a fixed 29.97-frame expectation and cannot be treated as film-cadence failures without adapting interpretation to two/three-field pictures. The helper identifies the original clip and HDMI stereo PCM, transfers all 12,818,502 bytes in about 12.854 seconds, exits zero and reports no slow-path bytes; maximum poll occupancy is 7,558 microseconds and maximum poll-entry interval 20,867. Regenerated native transport matches the prior SHA256 exactly. Mapping its record positions onto sampled Main receipts finds uneven PCM delivery, including a 136.389-millisecond sampled interval containing 1,120 stereo frames against 6,547 frames of nominal consumption; this is not a gap with no transfers, not an audio-FIFO occupancy trace, and does not determine which side of the shared path caused starvation. Source inspection confirms that a pending blocked video byte or a full PCM sink can both stop the common extractor, so audio/video coupling is a plausible hypothesis, not yet the root cause. A separate silent Program Stream replaces 334 audio PES packets with equal-length padding while preserving all 5,109 video PES packets, their timestamps and pack positions. Original and silent helper outputs match all 10,334,393 video-plus-PTS bytes exactly, FFprobe finds only MPEG-2 video, and silent PCM output is empty. The new dvd_opening_video_only.mpg is installed with staged and final FTP readback SHA256 f30a2c7fb1f8e4a1647f8c49375ca72b21375195a2d0f15723c82539e8ecb4e5. No core, Main, helper, setting, source or build change is made and no replay is started by the agent. Capture, timing analysis and diagnostic generation/deployment manifests are retained under .ai/current_results/entry667_*, with local diagnostic reproduction material in output_files/entry667 and build-PC evidence in /home/vash/mister-builds/entry667. Hardware acceptance remains open.

#### Next Steps:

Have the user play dvd_opening_video_only.mpg once on the same dated candidate in Weave, expect silence, compare the stutter, and leave the final screen and helper log intact for capture. Smooth silent playback would implicate the audio/shared-delivery interaction; persisting stutter would require examining video decode and film presentation independently as well. The comparison preserves video and timestamps but intentionally selects the helper's silent scheduling path, so it does not by itself separate AC-3 computation from PCM scheduling or FIFO coupling. Preserve this first-underrun evidence and avoid another FPGA build or speculative buffer change until the comparison guides a proposed fix.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 666 COMMIT Unreleased 6c1b621 2026-08-28T02:14:41-07:00

#### Coming From:

Unreleased 6c1b621

#### Purpose:

Record verified candidate installation and preserve the first Weave capture while the loaded core remains unconfirmed.

#### Outcome:

The user explicitly authorizes installation, and the agent adds MediaPlayer_20260828.rbf and games/MediaPlayer/dvd_opening_original.mpg over FTP using separate staging names, hash-verified readback and rename. Final readback matches the qualified candidate and original opening exactly. Existing MediaPlayer.rbf remains the known-good 4777c59 image, and Main, helper and MediaPlayer_OLD.rbf remain byte-identical; no reload or playback is initiated by the agent. The user then reports transferring the files and seeing no playback in Weave mode, asks for a screenshot, and subsequently says the wrong file may have been run. Two captured screenshots are byte-identical and show a blank picture with the diagnostic overlay. Checksum-valid schema-19 telemetry reports fatal_or_no_progress after 141 accepted video bytes and 1,639 session cycles, error flags 1, frame-rate code 8, zero pictures, swaps and PCM samples, and PCM FIFO peak 127. The helper log identifies dvd_opening_original.mpg with HDMI decoded stereo, completes all 12,818,502 transport bytes and exits zero; both files on the SD card still match the package. The logical RBFNAME and CORENAME records both say MediaPlayer, but Main derives them from the core configuration string, so they cannot distinguish the preserved core from the dated candidate or prove which bitstream was running. This is an unconfirmed-core failed run, not acceptance or a confirmed regression of source 6c1b621. Installation, screenshots, decoded telemetry, helper log and capture manifest are retained under .ai/current_results/entry666_*. No source change, rebuild, replay or configuration change is made during capture.

#### Next Steps:

Have the user explicitly load MediaPlayer_20260828.rbf and then select dvd_opening_original.mpg once, keeping Weave and HDMI decoded stereo for a comparable test. No file recopy is needed. Preserve the next helper log and terminal state before replay and collect a new two-screenshot capture. Confirm the loaded candidate before attributing the early rejection to decoder logic or proposing changes; keep the narrow HDMI timing margin visible and preserve user control of playback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 665 COMMIT Unreleased 6c1b621 2026-08-28T02:00:43-07:00

#### Coming From:

Unreleased 6c1b621

#### Purpose:

Record clean-build qualification and prepare the original DVD opening for user-controlled hardware testing.

#### Outcome:

Seed-only source 6c1b621 retains the qualified decoder from 3e287b3 and changes only placement seed 17 to 18. Source 6c1b621 is pulled from GitHub on GUNSMOKE and built from a fresh checkout with Quartus 17.0.2, seed 18, without reused build databases. Compilation completes in 770.6 seconds with zero errors and 204 warnings. Every timing category is positive with zero total negative slack: setup 0.065, hold 0.193, recovery 4.424, removal 0.634 and minimum pulse width 0.925 nanoseconds. HDMI remains the binding setup category at positive 0.065 nanoseconds, while decoder and video setup are positive 1.414 and 2.420; this narrow margin is kept visible rather than treated as ample headroom. The user requested a pause if seed 18 failed; it passes, and no further seed attempt is run. Resource use is 32,983 ALMs, 52,424 registers, 4,054,267 block-memory bits, 514 of 553 RAM blocks and 67 DSP blocks; the previous accepted source used 512 RAM blocks and had positive 0.126-nanosecond worst HDMI setup slack. The loop-index latch and ignored async_reg warnings are absent after the correction; normalized synthesis-warning differences against the verified 4777c59 baseline are widened motion arithmetic covered by exhaustive tests and renamed open-drain buffer nodes. TimeQuest confirms the protected intra and non-intra weight register banks survive in both P and B transforms, with their input and output paths timed. The prefetch correction matches 122,992 cycles across 384 coefficient cases and preserves transform throughput. The unchanged-source paired runner completes on this exact published source: all 289 pictures and 149,817,600 samples are checked, isolated comparison has maximum difference 1, and real decoded references have maximum predicted difference 5 with 102 samples above the old fixed-two comparison but no measured propagation-bound violation. This does not claim bit-exact reconstruction or a pass under the old fixed-two threshold. Exact publication, ownership and error checks pass. Film-cache generation changes also pass in both field orders with 512-cycle DDR response latency. Entry 660's focused reconstruction, film presentation, audio and transport checks remain applicable; the direct-byte parser matches the previous qualified parser cycle by cycle for gapped and continuous input, and the three new CDC exceptions are limited to verified source-to-first-stage paths with all later stages still timed. The RBF has 4,392,652 bytes and SHA256 2e834957fed5bbb246074d975d44247b9e81508eab04ea27445aa6a935ed916c. The locally verified output_files/entry664/MediaPlayer_6c1b621_dvd_opening_test.zip contains the dated candidate core and original compressed opening, with unchanged Main and helper omitted, manual test instructions and per-file checksums; the archive has 12,778,976 bytes and SHA256 822783066af325680b81a6813185c2a5af697458b6965638ded2f35c8009956d. Numeric build, qualification and package evidence is retained under .ai/current_results/entry665_*. The Pi and GitHub source are synchronized. No file is deployed to the MiSTer and no reload, playback, listening, physical field-cadence or A/V synchronization acceptance is claimed.

#### Next Steps:

Have the user preserve the known-good core, copy and load the dated candidate, copy dvd_opening_original.mpg to games/MediaPlayer, and play it once with HDMI decoded stereo PCM while keeping the current Bob/Weave selection. Collect the helper log and terminal telemetry before any replay or different file overwrites them, and record visible motion, music, field stability and menu response. The requested twelve-second stream copy retains a later reference picture and a terminal timestamp gap, so distinguish a final hold from a mid-stream failure. After the first capture, test replay, the other Bob/Weave setting and AC-3 passthrough separately. Hardware acceptance remains open, as do whole-title playback, arbitrary interlaced P/B syntax, ISO/IFO navigation and menus. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 664 COMMIT Unreleased 6c1b621 2026-08-28T01:44:41-07:00

#### Coming From:

Unreleased 3e287b3

#### Purpose:

Reseed the unchanged decoder after weight prefetch closes MPEG timing and only the known HDMI scaler path remains negative.

#### Outcome:

Seed-only source 6c1b621 is published from the Pi; its sole production difference is MediaPlayer.qsf seed 17 to 18. The clean source-3e287b3 build completes in 781.6 seconds with zero errors and 205 warnings. Decoder setup improves to positive 1.486 nanoseconds and video setup to positive 2.775, but HDMI setup remains negative 0.274 with total negative slack of 6.576 on the existing ascal vertical-address path. Hold, recovery, removal and minimum pulse width are positive 0.253, 3.368, 0.529 and 0.925. Fitted resources are 32,856 ALMs, 52,359 registers, 4,054,267 memory bits, 514 of 553 RAM blocks and 67 DSP blocks. TimeQuest finds all four eight-bit prefetched weight banks, input setup at least positive 4.798 and output setup at least positive 2.853; all film CDC endpoints match and subsequent synchronizer stages have positive 15.531 setup. Both exact-source opening checks pass all 289 pictures and 149,817,600 samples, preserving the isolated one-level and measured real-reference propagation bounds, with no decoder or ownership errors. The failed RBF is not packaged or deployed. Entry 655's recorded response for marginal HDMI placement applies: change only the fitter seed from 17 to 18, leaving all RTL, clocks and timing constraints unchanged, publish that source and perform another clean build. Reports and the failed image remain under /home/vash/mister-builds/entry663.

#### Next Steps:

Pull published seed-only source 6c1b621 on GUNSMOKE, rerun the clean build and paired opening checks, and audit every timing category, warning difference, register boundary and synchronization endpoint again. Package only a fully timing-positive candidate with a locally verified checksum, preserve the known-good core and leave deployment and playback to the user. No decoder feature or acceptance bound is expanded.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---

## 663 COMMIT Unreleased 3e287b3 2026-08-28T01:24:48-07:00

#### Coming From:

Unreleased 3828608

#### Purpose:

Register prefetched P/B quantization weights to close the remaining matrix-RAM timing path without changing transform cadence.

#### Outcome:

Correction 3e287b3 is published from the Pi after all 384 coefficient cases and 122,992 cycle-by-cycle comparisons match the previous transform, including coefficient values, output timing, busy state and errors. Independent matrix vectors pass all 36,864 coefficients, and the six-picture matrix-transition raster checks all 3,110,400 samples within one level. The protected weight registers preload during the existing commit phase without adding cycles. Source 3828608 passes the complete paired original-opening qualification and completes a clean Quartus build in 704.7 seconds with zero errors, but remains blocked from deployment by negative 1.100-nanosecond decoder setup. The byte-parser and three CDC corrections resolve their prior failures; video setup is positive 2.136 and HDMI setup positive 0.310. Hold, recovery, removal and minimum pulse width are positive 0.246, 3.813, 0.418 and 0.925. Fitted resources are 31,301 ALMs, 48,891 registers, 4,056,315 memory bits, 518 of 553 RAM blocks and 67 DSP blocks. Detailed TimeQuest paths now start at the B transform's intra-matrix RAM and pass through the shared inverse-quantization result logic. The correction preloads weight zero while idle and the next natural-index weight during each coefficient's existing commit phase, using preserved data registers protected from retiming. The default non-intra fast path and the custom/intra two-phase schedule must keep their existing cycles and values. No extra timing exception, clock reduction, feature expansion, deployment or hardware acceptance is proposed. The failed build and reports remain under /home/vash/mister-builds/entry662/results.

#### Next Steps:

Pull published source 3e287b3 on GUNSMOKE, build from a fresh exact-source checkout and rerun the complete paired original-opening qualification. Require all timing categories positive and retained register-stage evidence before packaging any RBF; keep all prior failures visible and preserve restricted core.md and user control of the MiSTer.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- tools/streams/run_quant_transform_equivalence.sh
- docs/testing_original_dvd_opening.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 662 COMMIT Unreleased 3828608 2026-08-28T00:55:35-07:00

#### Coming From:

Unreleased 4a27f80

#### Purpose:

Close the matrix parser byte-path timing and constrain the three verified film synchronization inputs.

#### Outcome:

Timing correction 3828608 is committed and published from the Pi. Direct byte assembly replaces the eight-bit combinational state walk without adding acceptance latency. Cycle-by-cycle differential tests match every exposed output, write event and both matrix memories for 1,860 gapped-input cycles and 613 continuous-input cycles. Matrix-state tests pass 384 checks in each mode and all 36,864 inverse-quantization coefficients pass; the six-picture matrix-transition raster compares all 3,110,400 samples within one level. All endpoints of the three new CDC constraints match the old fitted netlist; applying only those constraints makes video setup positive 2.171 nanoseconds and later synchronizer stages positive 10.363 while leaving the original decoder failure at negative 6.587, demonstrating that the parser path is not hidden. The clean source-4a27f80 build completes in 807.9 seconds with zero compilation errors but fails timing, so its RBF is not a test candidate. It uses 32,741 ALMs, 49,045 registers, 4,056,315 memory bits, 518 of 553 RAM blocks and 67 DSP blocks. Hold, recovery, removal and minimum pulse width are positive at 0.246, 3.346, 0.445 and 0.925 nanoseconds; worst decoder setup is negative 6.587, video setup negative 1.494 and HDMI setup positive 0.002. Detailed TimeQuest reports locate the dominant failure on a 19-level path from the clean-video FIFO output to the matrix observer's FLAG state and matrix write address. The byte-wide interface currently expands an eight-bit state-machine walk combinationally, which must be replaced by direct byte assembly and bounded load-flag handling without adding byte-acceptance latency. Separate failing paths are the registered film-mode level to film_mode_video_sync stage zero, progressive_chroma_mem to progressive_chroma_r1, and registered native field/active levels to native_field_sync stage zero. These are the first sampling stages of the newly implemented synchronization and stable-descriptor transfers, and the correction will mirror existing narrowly scoped source-to-first-stage exceptions while preserving all later-stage and decoder timing. Both earlier synthesis-warning defects are gone. The paired numerical runner passes on exact published 4a27f80, and its isolated and real-reference CSV files are byte-identical to 0c17678: all 289 pictures and 149,817,600 samples, isolated maximum difference one, real-reference maximum five with 102 samples above the old fixed-two threshold and no measured propagation-bound violations. Delayed-DDR film generation tests pass in both field orders. Complete failed-build reports and path audits remain under /home/vash/mister-builds/entry661/results; no deployment or hardware acceptance occurs. This is timing closure of the approved matrix and film implementation, not an expanded playback feature.

#### Next Steps:

Pull the published timing correction on GUNSMOKE, perform a new clean build and exact-source full-opening paired regression, and require matched constraint endpoints, no hidden later-stage paths, positive timing in every category, and a clean build from newly published exact source on GUNSMOKE before packaging. Do not reseed as a substitute for repairing the 19-level parser path or use a timing-failing RBF. Preserve restricted core.md, existing evidence and user control of the MiSTer.

#### Files Modified:

- MediaPlayer.sdc
- docs/testing_original_dvd_opening.md
- rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv
- tools/streams/run_quant_matrices.sh
- tools/streams/run_quant_matrix_equivalence.sh
- tools/streams/tb_h262_quant_matrices.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 661 COMMIT Unreleased 4a27f80 2026-08-28T00:35:47-07:00

#### Coming From:

Unreleased 0c17678

#### Purpose:

Correct Quartus 17 synthesis annotations and the matrix parser loop-index initialization before hardware qualification.

#### Outcome:

Source correction 4a27f80 is committed and published from the Pi after all 384 parser-state checks and 36,864 coefficient comparisons pass again. The first clean build of published source 0c17678 completes Analysis and Synthesis but exposes two avoidable warnings. The new film-mode and field synchronizers use async_reg, which Quartus 17 explicitly ignores; the correction uses the same Altera SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS attribute already applied to neighboring synchronization chains. The matrix observer's combinational loop index is unassigned on its start-code bypass path, so it receives a default value before the loop; all functional parser outputs already have defaults, and the loop overwrites its index before use. Neither edit changes decoder arithmetic, syntax admission or field scheduling. The superseded fitter is stopped deliberately rather than qualifying an image with the ignored attributes. Its successful synthesis reports 47,251 registers, 4,056,315 memory bits and 67 DSP blocks; these are not fitted resource or timing acceptance. The source-0c17678 paired DVD rerun remains isolated and may finish for evidence, but the corrected source requires its own clean build and final numerical check. No deployment or hardware result is claimed, and this correction remains within the approved opening scope.

#### Next Steps:

Pull the published correction on GUNSMOKE and use a fresh exact-source checkout for a clean Quartus 17 build and paired opening qualification. Confirm both new warning classes disappear, inspect remaining warnings against the verified 4777c59 baseline, require all timing categories positive, and only then package the original opening and candidate RBF for user-controlled testing. Preserve the superseded reports and restricted core.md.

#### Files Modified:

- MediaPlayer_top_04.svh
- rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 660 COMMIT Unreleased 0c17678 2026-08-28T00:30:28-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Record full original-opening numerical qualification and publish the approved film-frame source for a clean build.

#### Outcome:

Both full-opening simulations complete all 289 coded pictures and 149,817,600 reconstructed samples, with 25 I, 103 P and 161 B pictures, exact publication and ownership checks, and zero decoder errors. The isolated run replaces only already-compared, persisted reference pictures with FFmpeg samples and bounds every I/P/B sample to one level; its maximum difference is one. The real-reference run retains all RTL pictures: 102 predicted samples exceed the old fixed two-level comparison, the maximum difference is five, and none exceeds the measured maximum error of the actual reference bank plus the independently verified one-level transform allowance. This is a paired propagation check, not a claim that the old fixed-two comparison passed or that oracle references represent hardware playback. Interpolation, averaging and clipping cannot amplify the largest integer input error; the retained-reference error is measured rather than assigned a growing arbitrary GOP tolerance. The new paired runner requires both checks and unchanged source. A final synthesis precaution makes the two signed divisions explicit constant-divisor branches; the 384-case coefficient suite and matrix-transition and progressive pixel controls pass again afterward, and the exact published source will receive another complete paired run. Focused tests cover all downloaded-matrix states, 36,864 I/P/B coefficients, 1,441,440 motion combinations, 1,024 chroma cases, f_code-six reconstruction, quantized B types, intra predictor reset, and first-intra B routing. The latter reproduces an existing missing-descriptor failure at coded picture 284 and passes after the fix. Matrix changes across I/P/B and a new sequence pass all 3,110,400 samples within one level. Field-DCT and existing I controls pass; native regressions pass. Integrated film scheduler, bank metadata and 90-kHz timeline tests prove I/B/B/P reorder, 3/2/3/2 fields, missing PTS, terminal drain and replay. Strengthened RGB assertions pass 345,600 samples over two fields and 518,400 over three fields for both orders; earlier luma fingerprints alone were not RGB proof. Ordinary generation controls also complete with zero simulator exit status; their Verilator concatenated-format messages print as decimal text, so a grep for PASS incorrectly returns nonzero and is not a functional failure. AC-3 passthrough is byte exact, PCM has 576,000 stereo frames with maximum differences 17/20 and correlations above 0.99999, and transport preserves 10,334,168 clean video bytes, 25 PTS records and all PCM with queue bounds passing. The twelve-second copy retains a later final reference picture, giving 722 film fields and a terminal PTS gap; this is kept rather than altering encoded content. Detailed logs remain on GUNSMOKE under /home/vash/mister-builds/entry656/results. No Quartus build, deployment, listening, physical cadence or A/V synchronization acceptance is claimed.

#### Next Steps:

Complete the exact-published-source paired rerun and clean Quartus 17 build, audit warnings and all timing categories, then prepare a checksummed candidate and original opening for user-controlled testing. If timing fails on the marginal HDMI domain, follow the recorded reseed policy rather than assume placement savings are headroom. Keep the old fixed comparison and failed diagnostics visible, retain first-failure reproducers, and record build and hardware results in new entries without rewriting this checkpoint.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 659 COMMIT Unreleased 4777c59 2026-08-28T00:02:07-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Record implementation progress and remaining qualification gates for the approved original DVD-opening cycle.

#### Outcome:

The approved drafts remain uncommitted on the Raspberry Pi and are tested in an isolated export at /home/vash/mister-builds/entry656/dev on GUNSMOKE; the active checkout and MiSTer are not modified. Preparation preserves the selected compressed video and first AC-3 track byte for byte and produces 289 coded pictures. Generic matrix parsing and inverse quantization pass 384 matrix-state checks and 384 coefficient cases, while the first original I picture matches all 518,400 reference samples exactly. Motion arithmetic passes 1,441,440 signed reconstruction cases and 1,024 chroma cases. Full-raster synthetic f_code-six and quantized B fixtures pass with maximum pixel difference one. Original playback first exposes three omitted legal quantized non-intra B macroblock types, then an existing failure to reset all B motion predictors after intra macroblocks, which sends a prediction outside the frame at coded picture 107. The latter has a focused synthetic reproducer that fails before the reset and passes after it, with all 1,555,200 I/P/B samples within one level of FFmpeg; these complete existing quantizer and motion behavior inside the approved opening boundary. Native 480i regressions and focused film cadence, progressive-chroma cache, metadata and field-order tests pass, but integrated original-film presentation is not yet qualified. Both AC-3 passthrough and software PCM comparison pass; PCM has 576,000 stereo frames, maximum differences 17 and 20, and correlations above 0.99999. These are software results, not listening or synchronization acceptance. Earlier original-stream runs contain unresolved pixel deviations, and an attempted oracle-reference refresh diagnostic is not accepted as decoder evidence. The full original run with real RTL reference pictures and the predictor fix is now running. An added field-DCT harness test initially misinterprets the writer's row-stride contract and omits sequence end; the corrected harness is being verified. No source commit, Quartus build, deployment or hardware acceptance is claimed. Entry 656 remains the single open proposal.

#### Next Steps:

Finish the original pixel comparison without relaxing tolerances to hide defects, complete integrated per-picture film cadence and timestamp ownership, matrix-change lifetime and terminal/replay checks, and rerun affected controls. Retain numeric results under the isolated PC results directory and commit deterministic generators rather than movie-derived media. Once the source and regressions qualify, publish from the Pi, resolve entry 656, pull exact published source on GUNSMOKE and perform the required clean Quartus 17 build and timing/resource audit before asking the user to deploy. Preserve restricted core.md, old artifacts, the forty-entry ring and user control of the MiSTer.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 658 COMMIT Unreleased 4777c59 2026-08-27T23:24:29-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Record approval to add stream-defined quantization matrices to the original DVD-opening cycle.

#### Outcome:

The user approves the matrix expansion identified in entry 657 and directs implementation to proceed. Entry 656 remains the single open source proposal, now including generic intra and non-intra matrix loading, initialization, persistence, inverse-scan addressing and use by all I/P/B inverse-quantization consumers. This approval does not extend the twelve-second original-video and first-track AC-3 boundary to whole-title qualification, rare interlaced macroblock syntax or DVD navigation. The untested B-motion draft and harness connection remain local and no new implementation has been made since the pause. No build or hardware result is claimed.

#### Next Steps:

Verify the controlled H.262 matrix semantics, implement and test matrix handling without hardcoded film weights, then complete the approved film admission, B-vector range and per-picture field-cadence and chroma work. Require synthetic matrix and motion boundaries, original opening pixel comparisons, AC-3 and timestamp checks, existing regressions and a clean build from published source on GUNSMOKE before handing files to the user for hardware testing. Preserve user control of deployment and playback, restricted core.md, pre-existing artifacts and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 657 COMMIT Unreleased 4777c59 2026-08-27T23:19:49-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Pause the approved DVD-opening cycle after discovering unsupported custom quantization matrices in its first sequence header.

#### Outcome:

The approved entry 656 plan is published as 75c3410 and GUNSMOKE pulls it before an isolated test export is created. The first original DVD sequence header sets both load_intra_quantiser_matrix and load_non_intra_quantiser_matrix. An exact bit-offset probe verifies sixty-four intra weights ranging from eight to twenty-one and sixty-four non-intra weights all equal to eight, rather than the decoder's default matrices. Entry 656's header inventory did not inspect these fields, so its proposed scope was incomplete. The frontend marks downloaded matrices unsupported, the I inverse-quantizer rejects them, and the P/B transform path uses hardcoded default weights. Original compressed playback therefore needs matrix parsing, lifetime handling and programmable weights through every relevant transform consumer, which materially expands the approved work and requires user approval under core.md. Implementation stops on that finding. Local uncommitted drafts widen the B-motion parser, transport and raster arithmetic and update the shared authoring helper; they are untested and are not pushed or copied over the active build checkout. The only simulation run uses the existing progressive fixture and the testbench's missing frame_pred_frame_dct connection repaired, with no B-width changes. It compares 423,936 predicted samples with zero differences above the existing tolerance and maximum difference two, and all completion and error counters match the baseline, but exits nonzero because 1,239,997 cycles differs from the fixture's hardcoded 1,239,996 assertion. This establishes a useful pixel control, not a passing regression suite or an intra reconstruction proof, because that bench seeds reference I pictures from the oracle. No original-film excerpt is generated, no Quartus build occurs, and no deployment or playback is performed. The open proposal remains entry 656 with its single placeholder; restricted core.md and pre-existing artifacts are untouched.

#### Next Steps:

Obtain approval to add stream-defined intra and non-intra quantization matrices to the same original twelve-second video and AC-3 milestone before continuing implementation. If approved, first extend the source inventory to matrix loads and changes, check the controlled H.262 matrix rules, and test default initialization, sequence and extension updates, intra and non-intra weights, inverse-scan indexing and matrix ownership through pipelined I/P/B reconstruction. Preserve generic matrix handling rather than hardcoding this film's tables or changing its encoded video. Resume the B-range, per-picture pulldown and chroma work only inside the approved expanded plan, repair the test harness with explicit coverage for its actual boundary, and require the originally agreed regression, clean-build and hardware gates. Keep whole-title, rare interlaced syntax and DVD navigation outside the opening scope. Do not claim any of the uncommitted drafts or the failed cycle-count assertion as qualified source; preserve the local draft for continuation, user hardware control and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 656 COMMIT Unreleased 0c17678 2026-08-27T23:13:11-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Enable the original twelve-second DVD opening with AC-3 as a bounded native film-frame playback milestone.

#### Outcome:

The approved cycle is implemented as source 0c17678, including the matrix expansion approved in entry 658. Generic sequence and extension matrix downloads feed I and shared P/B inverse quantization, with default reset, persistence, natural-index addressing and fail-closed validation. B motion supports f_code six end to end, the three legal quantized non-intra B macroblock types are decoded, all B motion predictors reset after an intra macroblock, and an intra first B macroblock selects the B engine before its descriptor is consumed. P/B header capture preserves picture coding controls across quantization-matrix extensions. The frontend admits the bounded progressive-film subset in a 480i sequence; physical picture banks retain top-field-first, repeat-first-field and progressive-chroma metadata independently of PTS, and the scheduler presents two or three fields while respecting candidate parity and timestamp floors. The framebuffer selects progressive chroma rows for film and keeps ordinary interlaced mapping. Deterministic preparation, numerical comparison and focused regressions are committed; no movie-derived media is published. Source is committed and pushed only from the Pi. Qualification details and the explicit numerical comparison limits are recorded in entry 660. Whole-title playback, arbitrary interlaced P/B syntax, ISO/IFO navigation and menus remain outside scope. A clean Quartus build and hardware acceptance are still pending.

#### Next Steps:

Pull exact published source on GUNSMOKE, repeat paired original-opening qualification, and perform a clean Quartus 17 build with every timing category positive and a comparison against 512 of 553 M10K and the previous positive 0.126-nanosecond HDMI setup margin. Record build results in a new entry and hand verified files to the user for deployment and playback; do not infer hardware acceptance from simulations. Preserve restricted core.md, existing artifacts and user control of the MiSTer.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- docs/testing_original_dvd_opening.md
- files.qip
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv
- rtl/mpeg2_new/mpeg2_h262_native_field_order.sv
- rtl/mpeg2_new/mpeg2_h262_p_non_intra_transform.sv
- rtl/mpeg2_new/mpeg2_h262_p_residual_pipeline_420.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- rtl/mpeg2_new/mpeg2_h262_quant_matrices.sv
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- rtl/mpeg2_video_output_timing.sv
- tools/streams/generate_quant_matrix_vectors.py
- tools/streams/generate_test_b_f_code_range.py
- tools/streams/generate_test_b_intra_motion_reset.py
- tools/streams/generate_test_b_quantized.py
- tools/streams/generate_test_matrix_transitions.py
- tools/streams/h262common.py
- tools/streams/prepare_frame_pixel_oracle.py
- tools/streams/prepare_original_dvd_opening.py
- tools/streams/run_b_motion_math.sh
- tools/streams/run_film_presentation.sh
- tools/streams/run_full_frame_pixels.sh
- tools/streams/run_interlaced_i_reconstruction.sh
- tools/streams/run_mixed_raster_pixels.sh
- tools/streams/run_original_dvd_i.sh
- tools/streams/run_original_dvd_pixels.sh
- tools/streams/run_original_dvd_qualification.sh
- tools/streams/run_quant_matrices.sh
- tools/streams/tb_h262_b_motion_math.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_film_cadence.sv
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/tb_h262_input_cadence.sv
- tools/streams/tb_h262_interlaced_i_reconstruction.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_picture_timestamp.sv
- tools/streams/tb_h262_quant_matrices.sv
- tools/streams/tb_h262_quant_matrix_iq.sv
- tools/streams/tb_hdmi_scaler_stimulus.sv
- tools/streams/tb_interlaced_420_cache_mapping.sv
- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/tb_native_480i_presentation_integration.sv
- tools/streams/tb_native_field_order.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 655 COMMIT Unreleased 4777c59 2026-08-27T22:47:56-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Resolve the three items carried open from the field-DCT cycle.

#### Outcome:

All three are investigated read-only, with no source, build, deployment or hardware change. The unexplained logic decrease is resolved and was never a correctness signal. Running Analysis and Synthesis alone on the pre-change source at `3e89189` and comparing with the field-DCT build shows 46,832 registers against 46,846, a rise of exactly fourteen, which is what the change calls for: the `dct_type` register, the three-bit capture row counter, the two per-bank field flags, the six bits gained by no longer truncating the block origin across two banks, and a little plumbing. Nothing was pruned. The decrease is entirely a fitter effect, because the fitter adds registers over synthesis through duplication for fanout and packing and added 3,441 in the baseline against 2,515 here, simply choosing less duplication for a different placement; the ALM decrease follows from the same cause. The consequence is recorded so it is not misused: the apparent saving is not real, must not be banked against future features, and will move again with a different seed or the next change. The HDMI setup margin needs no separate mechanism. Its slack of positive 0.126 nanoseconds sits an order of magnitude below the next worst domain at positive 1.382, and its Fmax of 151.38 megahertz against a 148.5 megahertz clock is about 1.9 percent of headroom, matching the roughly two percent entry 370 measured. The 0.117 nanosecond erosion is placement pressure from added logic on the one domain with no room to absorb it, which is exactly that entry's finding, and the recorded response of reseeding rather than restructuring stands. One earlier reading is corrected: the `general[1]` Fmax of 60.7 megahertz was briefly treated as alarming, but that domain's slack is positive 2.043 nanoseconds and the restricted Fmax column does not represent headroom. The capture variation is characterised far enough to act on and then deliberately left alone. Between two captures of an identical unchanged frame the differences occupy ninety columns spaced exactly eight apart from x equal to 41, across all 480 rows of the active area; since 720-wide content is centred in an 800-wide display from x equal to 40, this is x modulo eight equal to one in video coordinates, the second pixel of each eight-pixel group and one byte lane of each 64-bit word. Magnitudes run from one to 255, are content dependent and chroma dominated, with sampled pairs showing red unchanged while green swings fully. With entry 653's finding that one capture matched a released-bitstream baseline exactly while counters stayed identical, this is a readback or display-path instability on a fixed byte lane rather than decode or framebuffer content. It is recorded as costing measurement reliability rather than picture quality: there is no evidence it affects playback, the user reports both affected fixtures play perfectly and they are the most detailed fixtures where the deltas are largest, while entry 644 nearly recorded a false regression from it and entry 653 nearly repeated that. The mitigation of capturing a completed frame twice and comparing the best of the two is proven on two fixtures and costs seconds.

#### Next Steps:

Do not spend a development cycle on the capture variation's root cause; use the two-capture method for every raster comparison and revisit only if visible shimmer is reported on real content, at which point it becomes a quality question rather than a measurement one. Do not treat the reduced ALM and register figures as headroom when scoping the next feature, because they are a placement artifact rather than a saving; the 41 free block-memory blocks recorded in entry 609 remain the real memory budget. Keep the HDMI setup margin visible as the binding timing constraint and reseed rather than restructure if a later change pushes that category negative. With these three closed, the field-DCT cycle has no open technical items, though a release-grade regression would still want tests two, three, five and six replayed. The next decoder milestone remains unapproved and unscoped: interlaced P and B is the gate that would make commercial discs play, and the deferred field-picture gate needs either a non-ffmpeg generator or a real disc sample because ffmpeg cannot encode field pictures, which is a choice for the user. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 654 COMMIT Unreleased 4777c59 2026-08-27T22:39:00-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Confirm progressive all-I decoding is unchanged on the field-DCT bitstream and close the practical regression.

#### Outcome:

The user replayed test four and reports video and audio are good. Helper-first collection preserved a log distinct from the test seven capture and identifies `test_4_progressive.mpg` with 12,060,823 bytes of video, 500 audio frames and 576,000 emitted samples, exit zero, and all 888 pipe reads reconciling to 14,546,422 completed transport bytes, which is byte for byte the transport entry 644 recorded. Every schema-19 counter matches that entry exactly, including 12,057,601 accepted video bytes, 360 reference and displayed pictures, zero B pictures, 359 swaps, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero deadline gaps and gap outliers, and the distinctive six timestamp advance conflicts this fixture has always produced; the three largest recorded intervals differ by at most one clock. Raster equality is deliberately not claimed for this fixture and the reason is recorded rather than glossed. Entry 644's capture was written to the Buildroot card, which is no longer installed, so no local baseline raster exists; and these captures are 800 by 600 scaled from 720 by 480, so the reference-decode comparison used for test one cannot apply without replicating the scaler. What was measured instead is capture stability, and it reproduces the entry 653 finding on the fixture where entry 644 first saw it: two screenshots of the same completed frame, taken without replaying anything, differ at 4,144 of 382,992 compared pixels, every one at x modulo eight equal to one, against the 4,418 entry 644 recorded for the same fixture. Acceptance therefore rests on counter and transport equality with entry 644 plus the user's visual report, and on the coverage argument that test one's interlaced all-I and test seven's progressive I/P/B both produced pixel-exact matches against released-bitstream baselines and together bracket the paths this fixture exercises. Three fixtures have now passed on this bitstream. Tests two, three, five and six remain unreplayed but carry the same bar and line content that test one already matched pixel for pixel, so the practical regression for the writer's capture-counter and untruncated-origin changes is complete. Three items remain open and none is resolved by this entry: the unexplained decrease of 372 ALMs and 912 registers, the HDMI setup margin at positive 0.126 nanoseconds, and the capture-path variation whose mechanism is still unidentified.

#### Next Steps:

The field-DCT gate can be treated as functionally accepted for development purposes on the strength of tests one, four and seven, while remembering that this gate decodes field DCT and does not make commercial discs play. Do not prepare a release on this basis: the unexplained logic decrease should be understood first, because a release should not ship a resource change nobody can account for, and tests two, three, five and six would need replaying for a release-grade regression. Investigate the capture-path variation as its own scoped question, since it now has a specific signature of every eighth pixel column, a reproducible test of capturing an unchanged frame twice, and consistent magnitudes across two fixtures. Keep the reduced HDMI setup margin visible and reseed rather than restructure if a later change pushes that category negative. The next decoder milestone remains unapproved and unscoped; interlaced P and B is the gate that would make commercial discs play, and the deferred field-picture gate still needs either a non-ffmpeg generator or a real disc sample because ffmpeg cannot encode field pictures. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---
