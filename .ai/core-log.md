## 575 COMMIT Unreleased deced5c 2026-08-27T00:44:54-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Measure assertion-to-first-byte latency on a verified cold run using the instrumented `deced5c` binary and test the dead-time inference of entry 572.

#### Outcome:

The power cycle is verified by a single new syslogd start at 07:41:02 UTC replacing the 07:25:17 boot, the user played once and stopped, and the helper log survived at 205,355 bytes. The timestamped record format itself proves the instrumented binary is the one that ran. The run came up clean, with zero cadence outliers, zero missed deadlines, 449 pictures, 448 swaps, all 15,150,646 bytes accepted and zero error flags, and its cadence counters are indistinguishable from earlier uninstrumented clean runs, so no behavioural change is evident, though one sample cannot prove the instrumentation non-invasive. The measurement the boundary was built for reads `first_byte latency_us=37556 would_block=672`, or 37.6 milliseconds from download assertion to first submitted byte, which falls inside the 13.9 to 63.8 millisecond band entry 572 inferred and therefore confirms that inference by direct measurement. The timestamps also permit the delivery curve to be computed for the first time from all 3,699 read records rather than inferred from telemetry arithmetic, and it shows that delivery is not a constant-rate process. It bursts at about 1.43 times realtime, 1,442,776 bytes per second from 97 to 199 milliseconds and 1,446,123 from 199 to 298, then decays through 1.28 and 1.06 times realtime and settles at consumption-paced realtime, finishing the whole session at 1,017,538 bytes per second. Because the ordinal five and six deadlines fall at roughly 200 to 270 milliseconds, they sit inside the burst, so treating delivery as constant-rate is valid for the startup window that matters but not for the session as a whole. That measured burst rate of about 1,443,000 bytes per second supersedes the 1,392,000 figure derived arithmetically in entries 571 and 572, which was 3.7 percent low, and the correction is self-validating: recomputing warm dead times at the measured rate tightens their spread from plus or minus 1.2 milliseconds to plus or minus 0.35 across five independent sessions, constraining the rate to about one percent. This corrects entry 572, which stated that warm dead time is zero. It is not; warm dead time is a consistent 8.0 to 8.7 milliseconds, averaging about 8.3, and the apparent zero was an artefact of the low rate estimate absorbing the real warm latency. The cold-versus-warm separation is unaffected and in fact widens, with cold dead times recomputing to 21.9, 35.3, 68.1 and 68.7 milliseconds against that 8.3 baseline. The most important result, however, is negative and must not be smoothed over. Dead time does not predict the outcome. This run measured 37.6 milliseconds and was clean, while entry 568 gapped at 35.3 and block 1 run 1 gapped at 21.9, and block 3 run 1 missed twice at 68.1. Dead time is therefore necessary context but not a sufficient predictor of a missed deadline, exactly paralleling entry 569 where starvation magnitude also failed to predict the miss. The most likely remaining variable is phase alignment between byte arrival and where the cadence deadline falls, which no existing counter measures. Cold outcomes now stand at three gapped and two clean across five verified cold runs. The burst rate is measured from this one cold run and warm runs remain uninstrumented, so their burst rate is supported by the residual cluster rather than measured directly, and the measured-latency population is one. Evidence is `.ai/current_results/entry575_cold_arm_helper.log`, `entry575_cold_terminal.png` and `entry575_cold_capture.json`.

#### Next Steps:

Do not propose the helper-side priming correction yet, because the justification for it has weakened rather than strengthened. Priming would reduce dead time from tens of milliseconds toward the warm baseline, but a run at 37.6 milliseconds was clean while runs at 21.9 and 35.3 gapped, so reducing dead time alone is not established to eliminate the miss and could be built and deployed without fixing anything. Gather measured latencies paired with outcomes instead, which the instrument now makes cheap: repeat the verified power cycle, single playback and immediate log fetch several times for cold samples, and separately instrument warm runs by fetching the helper log after a replay, so both populations carry measured rather than assumed latency. Six to eight paired samples should show whether any latency threshold separates clean from gapped runs or whether the outcome is independent of latency, which would confirm phase alignment as the operative variable and move the boundary again. If latency proves not to separate the populations, the next instrumentation step is to record, at each early cadence deadline, the phase between the most recent byte arrival and the deadline itself, which is an FPGA-side counter rather than a host-side one and would require a Quartus build. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Do not raise the per-poll chunk budget, which entry 572 ruled out and which the measured burst curve confirms is not limiting during the window that matters. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 574 COMMIT Unreleased deced5c 2026-08-27T00:40:07-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Back up and replace the host-side MiSTer main binary with the instrumented `deced5c` build under explicit user approval.

#### Outcome:

The user explicitly approved deployment and explicitly asked for a backup first, so standing RBF authorization was neither needed nor relied upon; this replaces a system binary rather than a core image and was treated accordingly. The existing `/media/fat/MiSTer` was read back in full over FTP at 1,166,244 bytes, its length checked against the server's own size report, written to disk and then re-hashed from disk, giving SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`. That backup is held at `/home/vash/mister-builds/entry573-deced5c/` outside the repository, because a 1.1-megabyte system binary does not belong in git, and restoring it is a single FTP upload should the instrumented build misbehave. Deployment avoided writing into the running binary's inode. The new image was uploaded to `/media/fat/MiSTer.new`, that staged copy was read back in full and hash-compared before anything was renamed, and only then was it renamed over the live path, which unlinks the old inode while the running process keeps its own. A fresh independent FTP connection then read back the entire active file. Staged and active readbacks both return 1,166,244 bytes with SHA-256 `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, matching the build exactly, no staging file remains, and permissions read as `-rwxr-xr-x`. The replaced and replacing binaries are both 1,166,244 bytes; since their hashes differ, the identical length is coincidental alignment in a stripped image and not a failed or partial write. The FPGA bitstream is untouched. No Quartus build was performed for this boundary and the qualified `2acabc5` image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains installed at `/media/fat/MediaPlayer.rbf`. The replacement takes effect on the next boot, since the currently running process retains the old inode until then. No playback has yet been run against the instrumented binary, so this entry records deployment only; the instrumentation is intended to be purely observational with no behavioural change, and that expectation is not yet confirmed on hardware. Evidence is `.ai/current_results/entry574_deployment.json`.

#### Next Steps:

Have the user power-cycle at the wall, load the core, play the file once and then stop without replaying, so `/tmp/MediaPlayer_ARM.log` survives for collection; a replay overwrites it, which is exactly how the cold log was lost in entry 571. Verify the power cycle from `/tmp/messages` rather than from recollection, since that check has already contradicted the reported procedure twice. Fetch the helper log first and the cadence screenshot second, then confirm three things: that the measured assertion-to-first-byte latency falls within the 13.9 to 63.8 millisecond band inferred in entry 572, that the timestamped blocked-poll records account for that interval rather than leaving it unexplained, and that cadence behaviour is unchanged from the uninstrumented build so the observation is confirmed non-invasive. Because entry 572 showed cold is not deterministic, with three of four verified cold runs gapping and one clean, expect to repeat this for at least two further verified cold samples before the dead-time distribution is usable. If the measurement confirms the inference, propose the helper-side correction of priming the media source before asserting download as a separate approved boundary. Hold the startup-absorption candidate in reserve and treat its margin as unsafe, the 64-KiB queue covering 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget, which entry 572 ruled out. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 573 COMMIT Unreleased deced5c 2026-08-27T00:31:44-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Instrument the ARM helper diagnostic log with monotonic timestamps and an explicit first-byte latency record so the cold startup dead time inferred in entry 572 becomes a measured quantity.

#### Outcome:

The approved plan is now committed as `deced5c` and built. Entry 572 established that steady delivery is a constant 1,392,000 bytes per second in every measured thermal state and that the cold defect is dead time before the first byte, inferred at 13.9 to 63.8 milliseconds by comparing each deadline record's elapsed time against the byte count it should have taken at that rate. That inference rests on telemetry arithmetic and on an 85 Hz poll rate that was never measured, so the correction to be made first is instrumentation rather than repair. The change is confined to `mediaplayer.cpp` as carried by `host/main_mister/0001-mediaplayer-arm-loader.patch`, which creates that file wholly, so the edit is contained to one new-file hunk whose line count is recomputed mechanically. A monotonic microsecond clock is added using `clock_gettime` with `CLOCK_MONOTONIC`, a session reference is taken in `diagnostic_open` before the first line is written so that the `start` record reads as time zero, and every diagnostic line is prefixed with elapsed microseconds composed into the same buffer as the message so that a single write call still emits a single line. The moment of download assertion is recorded, and on the transition of the read-event counter from zero to one a dedicated record reports the elapsed time from assertion to first submitted byte together with the would-block count accumulated in that interval. Nothing in the decode path, the FPGA image, the presentation scheduler, the startup controller or the 64-KiB queue is touched, the four-chunk per-poll budget is deliberately left alone because entry 572 ruled it out, and no behavioural change is intended, only observation. The FPGA bitstream is unaffected, so no Quartus build is required and the existing qualified `2acabc5` RBF with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains the installed image. Deployment is therefore host-side only and consists of the rebuilt MiSTer main binary and helper, and that is a materially different and more invasive operation than the RBF replacement covered by standing authorization, since it replaces a system binary rather than a core image; it must be approved separately by the user before anything is written to the target. The change is built and verified. `git apply --check` accepted the regenerated single-hunk patch against the pinned Main_MiSTer commit `0a8fb44`, the hunk line count moving from 275 to 304, and the build completed with the official ARM GNU 10.2 toolchain reporting version 10.2.1 20201103 rather than the distribution cross-compiler, producing a 1,166,244-byte stripped ARM EABI5 binary whose MD5 is `cba107ea2c4ea39bfb1bce755b262ca6`. The only two matches for error text in the build log are the zstd source filenames `error_private.c`, so the build is clean. The instrumentation is confirmed present in the binary by the literal strings `t=%llu ` and `first_byte latency_us=%llu would_block=%u count=%d`. The edited logic was additionally compiled and executed standalone against a harness that injected a five-millisecond delay before the first byte, and the resulting record read `first_byte latency_us=5059 would_block=670`, so the measurement path is correct to within harness resolution. One pre-existing property was observed and deliberately left alone: `diagnostic_write` truncates at its 1,024-byte buffer and loses the trailing newline when a message overflows, causing the next record to concatenate. That behaviour is inherited from the original implementation, the timestamp prefix consumes only about eight of those bytes, and real records run near sixty characters, so it is immaterial here and correcting it is out of scope for this boundary.

#### Next Steps:

Build the ARM stack with MiSTer's official ARM GNU 10.2 toolchain, never a distribution cross-compiler, and confirm the patch applies cleanly to the pinned Main_MiSTer commit `0a8fb44` before proposing deployment. Obtain explicit user approval for replacing the host-side MiSTer main binary and helper, since standing authorization covers the RBF only, and preserve a means of restoring the current binaries before any write. Once deployed, verify a power cycle from `/tmp/messages` rather than from recollection, play once, stop, and fetch `/tmp/MediaPlayer_ARM.log` before any replay overwrites it, then confirm that the measured assertion-to-first-byte latency falls within the 13.9 to 63.8 millisecond band inferred in entry 572 and that the timestamped record of blocked polls accounts for it. Gather at least two further verified cold samples so the dead-time distribution acquires a tail rather than four points. If the measurement confirms the inference, propose the helper-side correction of priming the media source before asserting download as a separate approved boundary, since it removes the dead time rather than hiding it. Hold the startup-absorption candidate in reserve and treat its margin as unsafe, the 64-KiB queue covering 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 572 COMMIT Unreleased 2acabc5 2026-08-27T00:28:08-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Capture the ARM helper log from a verified cold run before any replay overwrites it, and determine whether cold delivery is limited by the per-poll budget or by EAGAIN.

#### Outcome:

The power cycle is verified by a single new syslogd start at 07:25:17 UTC replacing the 07:16:20 boot, and the user played once and stopped so the helper log survived. The cold run itself came up clean, with zero cadence outliers, zero missed deadlines, 449 pictures, 448 swaps, all 15,150,646 bytes accepted and zero error flags, which establishes that cold is not deterministic: of four verified cold runs, three gapped and this one did not. The helper log answers the question it was fetched for. Cold records 670 would-block events against 190 in the warm entry 570 log, but in both files every logged instance carries a submitted count of zero and precedes the first byte, and after read event one neither log records another. EAGAIN therefore never occurs during steady delivery in either thermal state, the four-chunk per-poll budget is binding in both, and the entire cold penalty is concentrated before the first byte, where cold shows three and a half times as many blocked polls as warm. That result forced a re-examination of the telemetry, and it corrects entry 571. Comparing each deadline record's measured elapsed time against the time its accepted-byte count requires at the warm steady rate of 1,392,000 bytes per second isolates a residual dead time before delivery effectively begins. Across five independent warm sessions that residual is zero within plus or minus 1.2 milliseconds, which both validates the rate and shows that warm delivery starts immediately. Across the four cold deadline records the residual is 13.9, 27.8, 60.7 and 63.8 milliseconds, and it tracks severity, since 63.8 milliseconds produced two missed deadlines while 27.8 and 13.9 produced one each. Entry 571 stated that on a cold start the upstream feed runs at 0.94 times realtime and below the rate the stream requires. That is wrong and is superseded here. The feed does not run slow; steady delivery is 1,392,000 bytes per second in every measured state. The apparent 0.94 figure divided accepted bytes by elapsed time and thereby folded the pre-first-byte stall into an apparent rate. The defect is a late start, not a slow feed. The practical consequence is that raising the four-chunk per-poll budget or the buffer size in `mediaplayer_poll()` would not correct anything, because steady throughput was never the limiting quantity, and that candidate is now ruled out. Two candidates remain. The first is to reduce cold first-byte latency on the helper side, for example by priming or reading ahead in the media source before the download is asserted. The second is to absorb the dead time before the first cadence slot in the startup controller, noting that the 64-KiB clean video queue holds 64.9 milliseconds of stream at nominal rate and therefore only just covers the worst observed 63.8 milliseconds. The second candidate returns the boundary to the startup controller that entries 569 and 571 had ruled out, but now with a quantified requirement rather than the byte threshold that entry 569 correctly rejected. This entry's own cold run contributes no dead-time datapoint because it was clean, so its contribution is the would-block count alone, and cold sampling remains at four samples. The 85 Hz poll rate is inferred from throughput arithmetic rather than measured in MiSTer main, so the warm residuals validate the resulting rate but not its decomposition into chunk count and poll frequency, and the helper log still carries no timestamps, so the 670 blocked polls cannot be converted to a duration and the dead time is inferred from telemetry arithmetic rather than measured on the ARM side. Evidence is `.ai/current_results/entry572_cold_terminal.png`, `entry572_cold_arm_helper.log` and `entry572_cold_capture.json`.

#### Next Steps:

Obtain user approval for a delivery-side plan before any source change, since the evidence now supports a bounded correction and the standing workflow requires the plan on record first. The proposal is to instrument before correcting: add timestamps to the helper diagnostic log and record the elapsed time from download assertion to first submitted byte, which converts the inferred dead time into a measured one and costs nothing in the decode path, then confirm on one cold run that the measured first-byte latency matches the 13.9 to 63.8 millisecond band inferred here. With that confirmed, prefer the helper-side correction of priming the media source before asserting download, because it removes the dead time rather than hiding it and leaves the FPGA startup controller and the 64-KiB queue untouched. Hold the startup-absorption candidate in reserve for the case where first-byte latency proves irreducible, and note that it has almost no margin, since the queue covers 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget. Gather at least two further verified cold samples alongside the instrumented run so the dead-time distribution has a usable tail rather than four points, verifying each power cycle from `/tmp/messages` rather than from recollection, and fetch the helper log after the first playback of each. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged until a plan is approved. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 571 COMMIT Unreleased 2acabc5 2026-08-27T00:23:26-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Capture a verified cold-after-power-cycle block and identify the mechanism behind the delivery ceiling measured in entries 569 and 570.

#### Outcome:

The power cycle is verified by three independent signals rather than by recollection, which matters because the two previously reported reboots were not reboots. The still-running block 2 poller logged an FTP timeout at 00:16:27 local, exactly the dropout absent both earlier times; `/tmp/messages` restarted with a single syslogd entry at 07:16:20 UTC replacing the 06:56:52 boot; and `/tmp/MediaPlayer_ARM.log` disappeared with the tmpfs wipe, confirming the page cache was cleared. Six sessions were captured, the first genuinely cold and the remaining five warm replays with no reboot between them. The cold run is the worst session recorded to date and the first with more than one missed deadline. It reports two cadence outliers and two missed deadlines, at display picture ordinals five and six, with gaps of 4,004,000 and 6,006,000 cycles and a total cadence excess of 8,192,931 cycles, or 136.5 milliseconds. The first miss moved earlier to ordinal five, which no previous session showed. The decisive number is the feed rate at that ordinal-five deadline: 191,088 bytes had been delivered by 12,066,520 session cycles, which is 950,173 bytes per second, or 0.94 times realtime against the 1,010,157 bytes per second the stream requires. On a cold start the upstream feed is running below realtime, so the decoder cannot keep up because the data is not arriving fast enough, and the miss is a genuine delivery shortfall rather than a scheduler or writer fault. By the ordinal-six deadline the feed has recovered to 1,076,291 bytes per second, or 1.07 times realtime, and every run after the first is clean, so one replay is enough to leave the failing region. All six sessions still accept all 15,150,646 bytes and display 449 pictures with 448 swaps at zero error flags, and writer capacity blocked and upstream FIFO pending are false in both cold deadline records, so the writer and DDR path remain clean throughout. The delivery ceiling itself has now been located in source rather than inferred. `mediaplayer_poll()` in `host/main_mister/0001-mediaplayer-arm-loader.patch` reads into a 4,096-byte buffer under `while (chunks++ < 4)`, so it moves at most 16,384 bytes per poll. At the implied 85 polls per second that is 1,392,000 bytes per second, precisely the 1.38 times realtime ceiling measured warm in entries 566, 567 and 569. That cap is binding rather than incidental, and the archived helper log proves it: after startup the parent never receives EAGAIN, since all 190 would-block events carry a submitted count of zero and occur before the first byte is sent, so the read loop always exits by exhausting its four-chunk budget and never by running out of data. The cross-check agrees, with 3,699 reads at four per poll giving about 925 polls across a roughly 10.9 second delivery window for a 15.0 second stream. The delivery path therefore has about 38 percent headroom over realtime when warm and falls below realtime when cold, and that band is where the startup race is decided. One capture defect is recorded: an over-broad `pkill` pattern terminated the poller mid-block and had to be restarted, though a direct probe confirmed the screen still held run four at that moment and no session was lost. The single most important missing measurement is the helper log for a cold run, which was overwritten by the subsequent replays before it could be fetched; without it, it is not known whether cold delivery is limited by read latency inside the four-chunk budget or by EAGAIN against a slower helper, and those two point at different fixes. Evidence is `.ai/current_results/entry571_block3_run1` through `run6` and the consolidated `entry571_block3_series.json`.

#### Next Steps:

Take one more verified power cycle and fetch `/tmp/MediaPlayer_ARM.log` immediately after the first playback and before any replay, since that single file discriminates between a read-latency limit inside the four-chunk budget and an EAGAIN limit against a slower helper, and the two imply different corrections. Confirm the power cycle from `/tmp/messages` as was done here rather than from recollection. With that measurement in hand, propose a bounded delivery-side plan for user approval before touching source: if the budget is binding while cold, raising the per-poll chunk count or the buffer size in `mediaplayer_poll()` lifts the ceiling directly and is a small, contained change to the MiSTer main patch; if EAGAIN dominates while cold, the correction belongs in the helper's own read path or in readahead instead, and raising the poll budget would achieve nothing. Do not change the FPGA startup controller, which entries 569 and 571 together have now shown is not the operative boundary, and do not commit any source change until the plan is approved. Consider adding timestamps to the helper diagnostic log as part of whichever change is approved, since its present lack of timing is the main limit on the delivery evidence. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 570 COMMIT Unreleased 2acabc5 2026-08-27T00:14:52-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Collect a second repeated-run block and establish whether the ordinal-six miss survives a fresh start.

#### Outcome:

All five block 2 sessions are clean, reporting zero cadence outliers and zero missed deadlines while accepting all 15,150,646 bytes and displaying 449 pictures with 448 swaps, zero error flags and quiet terminals. The interpretation, however, is not the one the user expected, and the difference matters more than the result. The user reports rebooting before these five runs, but the device evidence does not support a Linux reboot. Both `/tmp` and `/run` are tmpfs and are recreated empty at boot, and `/tmp/messages` is the syslog and begins at boot. That file's first line is `Aug 27 06:56:52 MiSTer syslog.info syslogd started`, it runs unbroken through 07:13:46, and it contains exactly one syslogd start, while every boot-time daemon pidfile carries an mtime of 06:56. `/tmp/CORENAME` and `/tmp/RBFNAME` were restamped at 07:09. The MiSTer clock runs UTC against the agent's America/Phoenix local time, so 06:56:52 UTC is 23:56:52 local and 07:09 UTC is 00:09 local. Linux therefore booted once, before block 1, and remained up continuously across both blocks; what preceded block 2 was a core reload at 07:09 UTC, which reconfigures the FPGA but does not restart Linux and does not clear the page cache. Block 2 consequently ran against a cache already warmed by block 1's five reads of the same file, which makes it the strongest support so far for the read-latency mechanism rather than evidence that a cold start is clean. The same timeline confirms the other direction: block 1 capture 1 was taken 82 seconds after the verified boot and is a genuine cold-after-boot sample, and it gapped with 1,103,135 starved cycles. One conflict is left open and must not be smoothed over. Block 1 capture 5 was warm and still lost the ordinal-six slot at the full 1.38 times realtime feed rate, while all five block 2 runs at equal or greater warmth are clean, so page-cache warmth alone does not explain the difference and core-reload freshness may be a second factor that the present data cannot separate. A new and previously unrecorded evidence source was found during this work: the ARM helper writes `/tmp/MediaPlayer_ARM.log`, rewritten per playback, and the final block 2 run's copy is archived. It shows the helper reading the file in uniform 4,096-byte chunks, 3,699 reads for the whole 15,150,646 bytes, finishing on end of file with child exit code zero. Its blocking behaviour is the significant part. All 190 would-block events occur before the first byte is submitted, since every logged instance carries a submitted count of zero and the highest logged power of two is 128 against a total of 190, and after the first read event the helper never blocks writing to the FPGA again. The FPGA-side input FIFO is therefore never full during steady delivery, which establishes that ARM-side file read throughput is the limiting factor and is consistent with the 1.38 times realtime ceiling measured in entry 569. The 4,096-byte read granularity is the first concrete delivery-side mechanism identified and is a candidate cause of that ceiling. No genuine power-cycle sample has been taken since entry 568, whose own reboot predates the current syslog and cannot now be verified. The helper log carries no timestamps, so it establishes granularity and blocking but not read latency, and page-cache state remains unmeasured. Per the user's decision, entry 564 is dropped as evidence because its load history is not recalled, and the entry 569 ordinal ambiguity is resolved in favour of five captures mapping to five runs. Evidence is `.ai/current_results/entry570_block2_run1` through `run5`, the consolidated `entry570_block2_series.json` and the archived `entry570_arm_helper.log`.

#### Next Steps:

Take the genuine cold sample that is still missing by having the user fully power-cycle the MiSTer at the wall rather than reloading the core or using a menu reset, then play the file five times, so a verified cold-after-power-cycle block can be compared against block 1's verified cold-after-boot capture and entry 568's unverifiable one. Confirm the reboot afterward from `/tmp/messages` rather than from recollection, since that check is cheap and has now twice contradicted the reported procedure. Then run the separation experiment the open conflict requires: after a warm block that has produced a gap, reload only the core without rebooting and replay, which isolates core-reload freshness from page-cache warmth as the operative variable. The planned FTP cache-warming test is now partly redundant for confirming that warmth helps and should be reserved for the case where the power-cycle block comes up cold and gapped, where it would still discriminate mechanism. Pursue the ARM helper log as a first-class evidence source in parallel, since it is the only view of the delivery side: determine from the helper source whether the 4,096-byte read size is fixed or configurable and whether a larger read or readahead would lift the 1.38 times realtime ceiling, and add timestamps to that log if a diagnostic change is later approved. Do not propose a source change until the cold and core-reload cases are separated. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 569 COMMIT Unreleased 2acabc5 2026-08-27T00:04:40-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Collect a repeated-run series from a single reboot to establish the starvation range and determine whether a zero-gap run is reachable on this build.

#### Outcome:

The user rebooted, loaded the core and played the same file in Weave repeatedly, reporting five runs since that reboot. Capture was automated by polling the FTP screenshot trigger and archiving any completed quiet session whose telemetry checksum had not been seen before. Before trusting the series the capture path itself was controlled: six consecutive probes of a static post-run screen returned byte-identical PNGs and identical decoded telemetry, so the capture is deterministic and the five distinct checksums recorded are five distinct sessions rather than repeated reads of one. The poller has one defect worth recording, which is that it exited on reaching a preset four-sample target while the user was still running, so the fifth session was recovered only by a manual probe; the sample cap must be removed before the next block. Absolute run ordinals remain unconfirmed. The user believes the first run was missed, but five distinct sessions were captured and no FTP dropout was logged during the window, which means no reboot occurred inside it, so either the five captures are runs one through five or run one was missed and a sixth run occurred. Capture order is certain and every trend below is order-based and unaffected by that ambiguity. All five sessions pass every acceptance term, accepting all 15,150,646 bytes and displaying 449 pictures with 448 swaps, zero error flags, quiet terminal and presentation complete. The central result is that a zero-gap run is reachable on this build: the fourth capture reported zero cadence outliers and zero missed deadlines, matching entry 564 and establishing that the defect is intermittent rather than universal. Across the capture order, starvation at the ordinal-six deadline falls monotonically through 1,103,135, 1,079,350 and 1,043,165 cycles, then the clean run with no record, then 555,422 cycles, while bytes accepted at that deadline rise monotonically through 312,328, 324,224, 335,258 and 379,200. That is the warming signature the cold-versus-warm inference predicted. The feed rate, however, does not warm continuously; it saturates at about 1.38 times realtime, roughly 1,392,000 bytes per second, with captures two, three and five all at 1.38 exactly as entries 566 and 567 were, and only the colder captures below it at 1.30 and 1.22. That is a ceiling of the delivery path rather than a continuum. Most importantly, warming does not prevent the miss. The fifth capture had the least starvation of any gapped run at 9.26 milliseconds and the highest byte delivery at 379,200, and still lost the ordinal-six slot by the same 4,004,000 cycles. Starvation magnitude therefore does not predict whether the slot is lost, and the ordinal-six miss is a marginal timing race against one specific deadline rather than a simple bandwidth deficit. This materially revises the entry 568 reading that framed the problem as prefill depth alone. Every gap in this block is exactly 4,004,000 cycles, two nominal intervals, leaving entry 568's 6,006,000-cycle gap still the only one of its size, and the writer and DDR path stays clean in every gapped capture with upstream FIFO pending, writer busy and writer capacity blocked all false. Cold sampling remains weak at two samples across all work to date, and those two disagree substantially at 1,659,347 and 1,103,135 cycles. Evidence is the five capture pairs under `.ai/current_results` named `entry569_block1_run1` through `run4` and `entry569_block1_onscreen`, with the consolidated series, capture-method validation and scope limits in `entry569_block1_series.json`.

#### Next Steps:

Resolve the run-ordinal ambiguity with the user before treating the first capture as a cold sample, since that single value is what separates the two competing cold figures. Then run at least two further blocks with the sample cap removed, each a full reboot followed by five uninterrupted replays, so cold sampling reaches a usable count and the zero-gap rate can be estimated rather than inferred from two isolated clean runs. Because starvation magnitude has now been shown not to predict the miss, the more valuable experiment is the one already proposed but not yet run: reboot, load the core, read the media file over FTP to populate the page cache, then play once, which tests the read-latency mechanism directly instead of by correlation. That still requires the media path on the MiSTer, which the user has not yet supplied and which was not found under the obvious locations. Also obtain whether entry 564 was preceded by a reboot, or drop it as evidence. Do not propose a source change yet. The marginal-race result means a release gate conditioned on accepted bytes or queue occupancy alone would not have saved the fifth capture, so any startup-controller boundary must be sized against the deadline timing rather than against a byte threshold, and the delivery ceiling of 1.38 times realtime should be characterised before deciding whether the correct boundary is the startup controller or the ARM-side feed. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 568 COMMIT Unreleased 2acabc5 2026-08-26T23:48:12-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Test the entry 567 hypothesis that the ordinal-six starvation is a warm-reload effect by capturing a cold first Weave run after a full MiSTer reboot.

#### Outcome:

The user rebooted the MiSTer, loaded the core, loaded the file and let it finish, giving the cold first-run sample entry 567 asked for. The stale 476,501-byte probe survived the reboot and was deleted through FTP and confirmed absent before triggering; the new capture is 476,520 bytes with SHA-256 `ac379d4724df8320197fd5686be22a19c58e9b8ff6463aa965d5b50cf33560f8` and a checksum of 4,176,697,056, distinct from all prior sessions. Every acceptance term still passes: all 15,150,646 bytes accepted, 449 pictures displayed with 448 swaps, sequence end seen, presentation complete, quiet terminal reason one, zero error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. The hypothesis is refuted, and refuted in the opposite direction from the one proposed. The cold run does not come up clean; it produces the worst gap measured so far. The single outlier is again at display picture ordinal six but is 6,006,000 cycles, or 100.1 milliseconds, which is three nominal intervals rather than the two seen in both warm runs. Every upstream indicator moves the same way. Input starved cycles since the previous swap rises to 1,659,347, or 27.66 milliseconds, against roughly 1,072,000 cycles or 17.85 milliseconds in entries 566 and 567, an increase of about 55 percent. Accepted bytes at the deadline falls to 296,838 from 323,580 and 331,179, so materially fewer bytes had been delivered by the same deadline. Candidate ready delay rises to 3,230,418 cycles from 592,128 and 271,690. Meanwhile the writer and DDR path stay clean exactly as before, with upstream FIFO pending, writer busy and writer capacity blocked all false and zero capacity-blocked cycles, and writer wait and decoder stall totals sit within the same narrow band as the other three runs. The starvation magnitude therefore tracks how cold the media source is rather than any session rearm state, which is consistent with ARM-side file read latency during startup and inconsistent with the delivery-rearm boundary entry 567 nominated. The guarded startup did not absorb the deficit: presentation hold total is the lowest of all four runs at 26,390,166 cycles, so the guard released on readiness while the feed was still behind, and the residual non-gap startup excess of 2,580,696 cycles remains below the clean entry 564 run's 3,002,892. Ranked gaps two and three are exactly 2,002,000 cycles in this run as in every other, confirming once more that steady-state cadence after the startup hitch is nominal and that the whole defect is confined to initial prefill depth ahead of the first cadence deadline. This is one cold sample and does not establish a cold-run rate. Entry 564 is now the only zero-gap run out of four and its load history was never recorded, so it cannot be classified as cold or warm and cannot anchor either hypothesis. Page-cache state is not measured by this telemetry, so the read-latency explanation is inference from the starvation and byte-delivery figures rather than direct measurement. Deinterlace mode and load history are not encoded in the snapshot and rest on the user's report. No source change or build was performed for this entry, and no reload, reboot, MGL launch, media change or configuration change was made during capture. Evidence is `.ai/current_results/entry568_cold_weave_terminal.png` and `entry568_cold_weave_capture.json`, the latter carrying the full decode, the four-run series, the ordinal-six comparisons and these scope limits.

#### Next Steps:

The boundary is now initial prefill depth ahead of the first cadence deadline, not delivery rearm and not the presentation scheduler, so the remaining evidence needed is the size of the deficit rather than more mode or reload permutations. Have the user take two or three further cold runs, each after a full reboot, and two or three further warm replays, capturing telemetry after every single one and stating which is which, so the cold and warm starvation windows acquire a range instead of one sample each and so it can be established whether any run still reaches zero gaps under known conditions. Ask specifically whether the entry 564 run was preceded by a reboot, since reclassifying it would settle whether a clean run is reachable at all on this build. With that range in hand the fix boundary can be sized directly: the guarded startup controller currently releases the first picture on readiness alone, and the measured 27.66-millisecond cold starvation window against a 33.37-millisecond cadence slot indicates the release gate needs a minimum accepted-bytes or queue-occupancy condition in addition to readiness, which is a bounded change to the startup controller rather than to the queue depth or the scheduler. Extend the existing drained-FIFO warm-load simulation cases to model both measured starvation windows before proposing that change, and do not commit source until the user approves the revised plan. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged in the meantime. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 567 COMMIT Unreleased 2acabc5 2026-08-26T23:43:47-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the hardware telemetry from the user's Weave-mode run of `2acabc5` to determine whether the entry 566 ordinal-six gap depends on deinterlace mode.

#### Outcome:

The user accepted the entry 566 result, played a file in Weave mode and left the terminal telemetry on screen. The stale 476,509-byte probe from entry 566 was deleted through FTP and confirmed absent before triggering, and the new capture is 476,501 bytes with SHA-256 `57f242d044e927970686a0534a8b2a0ce859558b4a72921a0aae54900d17ed65`; its checksum of 4,099,361,451 and session length of 903,162,447 cycles both differ from entry 566, so this is a distinct session and not a stale re-read. The Weave run is functionally identical to the Bob run in every acceptance term. It accepts all 15,150,646 bytes, displays 449 pictures with 448 swaps, sees sequence end, completes presentation and terminates quietly with reason one, reporting zero error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. It also reproduces the defect exactly: one cadence outlier and one missed deadline, again at display picture ordinal six, again a 4,004,000-cycle interval of 66.7333 milliseconds that is precisely two nominal intervals, with ranked gaps two and three at exactly 2,002,000 cycles so that steady-state cadence away from the hitch is nominal. The ordinal-six deadline record carries the same upstream starvation signature as entry 566. Input starved cycles since the previous swap is 1,070,840 against 1,075,462 in Bob, a difference of only 4,622 cycles or 0.077 milliseconds, and in both runs the candidate is not presentable while upstream FIFO pending, writer busy and writer capacity blocked are all false with zero capacity-blocked cycles and a last reference completion age of about 3,912,352 cycles after five completed references. The micro-state differs only in which side of the same starvation is sampled: this run shows decoder ready false with decoder input pending true, whereas entry 566 showed decoder ready true with decoder input pending false, and the candidate ready delay is 271,690 rather than 592,128 cycles. Two independent sessions in opposite deinterlace modes producing the same ordinal, the same gap magnitude and the same starvation window establish that the defect is reproducible and that Bob versus Weave is not the variable; the failure is upstream delivery during early startup, not the presentation scheduler, the writer, DDR capacity or the deinterlacer. Total cadence excess over 448 nominal intervals is 4,393,879 cycles, of which 2,002,000 is the lost slot and 2,391,879 is the guarded startup hold, which sits between entry 566's 2,053,370 and the clean entry 564 run's 3,002,892 and therefore shows no startup regression. The 29.823923-fps aggregate again begins at first reference completion and includes that hold, so it is not a steady-state rate. Deinterlace mode is not encoded in the snapshot, so the Weave attribution rests on the user's report, and it is not known whether this was a cold first load or a warm reload. Two samples establish reproducibility rather than a rate, and entry 564 remains a clean counter-example under the same source. No reload, reboot, MGL launch, media change or configuration change was made during capture, and no source change or build was performed for this entry. Evidence is `.ai/current_results/entry567_weave_terminal.png` and `entry567_weave_capture.json`, the latter carrying the full decode, the entry 564 and 566 comparisons, the ordinal-six record diff and these scope limits.

#### Next Steps:

Stop collecting mode variations, because mode has been eliminated as a factor, and instead determine whether the ordinal-six starvation correlates with load history. Have the user power-cycle or reload the core and capture telemetry after the very first playback of a fresh core load, then after each of several successive replays without reloading, recording the run ordinal alongside each capture, so it can be established whether entry 564's clean result was specifically a cold first run and whether the starvation appears only on warm rearm. That distribution is the missing evidence needed to choose a boundary. If cold runs are clean and warm runs starve, the investigation belongs in ARM-side delivery rearm across successive sessions and the existing drained-FIFO warm-load simulation cases should be extended to model the measured 1,070,840-to-1,075,462-cycle starvation window before any RTL change is proposed; if cold runs starve too, the boundary is initial prefill depth ahead of the first cadence slot instead. Do not propose a source change until that data exists. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 566 COMMIT Unreleased 2acabc5 2026-08-26T23:38:54-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the hardware telemetry from the user's repeated-load Bob test of `2acabc5` after they reported playback appearing slower.

#### Outcome:

The user replayed the same file several times in Bob mode without rebooting, reported that after a few runs it seemed to run slowly, and left the final run's terminal telemetry on screen. The stale 476,291-byte `cadence_probe.png` was deleted through FTP and confirmed absent before a new screenshot was triggered, so this is a genuinely fresh capture at 476,509 bytes with SHA-256 `11955026d61bd37806f994b4ed784e8f69227622fc51b10f5e16e9987c898eee`. The captured session still accepts all 15,150,646 bytes, displays 449 pictures with 448 swaps, sees sequence end, completes presentation and terminates quietly with reason one, zero aggregate error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. Unlike the clean entry 564 run, however, both the ranked-gap and actual missed-deadline counters are one rather than zero. The single outlier and the single deadline record are the same event at display picture ordinal six, a 4,004,000-cycle interval of 66.7333 milliseconds, which is exactly two nominal intervals and therefore one frame held for an extra field pair. Ranked gaps two and three are exactly 2,002,000 cycles, so steady-state cadence away from that one hitch is nominal and the entry 559 miss at ordinal 348 does not recur. The ordinal-six deadline record is diagnostic: at 323,580 accepted bytes the decoder is ready, the candidate is not presentable, decoder input pending, upstream FIFO pending, writer busy and writer capacity blocked are all false, writer capacity blocked cycles since the previous swap is zero, candidate ready delay is 592,128 cycles and input starved cycles since the previous swap is 1,075,462, or about 17.9 milliseconds. That signature is upstream input starvation during early startup, not a decoder, writer or DDR capacity stall, and it is the same failure class as the legacy picture-six gap that the 64-KiB clean-video queue and guarded startup were meant to close. The startup guard itself did not regress: presentation hold total fell from 27,400,352 to 27,074,752 cycles and the residual non-gap cadence excess fell from 3,002,892 to 2,053,370 cycles, so of the 4,055,370-cycle total excess over 448 nominal intervals, 2,002,000 is the single dropped slot and the remainder is a slightly shorter guarded startup wait than the accepted run. The 29.835129-fps aggregate again starts at first reference completion and includes that startup hold, so it must not be read as steady-state slowness; the honest statement is one lost frame near the start, not a globally slower run. Schema nineteen telemetry is per-session and this snapshot covers only the most recent completed session, so the earlier repeats in which the user first noticed the problem are not captured and cannot be reconstructed, and neither Bob/Weave selection, loaded-file identity nor position within the repeat sequence is encoded in the snapshot. No reload, reboot, MGL launch, media change or configuration change was made during capture, and no source change or build was performed for this entry. Evidence is `.ai/current_results/entry566_bob_repeat_terminal.png` and `entry566_bob_repeat_capture.json`, the latter carrying the full decode, the entry 564 comparison, the interval arithmetic and these scope limits.

#### Next Steps:

Do not commit a speculative fix on one sample. Have the user repeat the load several times again and capture telemetry after each individual run rather than only the last, so the distribution of ordinal-six starvation across cold and warm loads is measured instead of inferred, and have them note which run number each capture belongs to along with whether the perceived slowness tracks the captured gap. Also ask whether the reported slowness persisted visually through a whole run or was a brief hitch near the start, since the telemetry supports only the latter. If repeated captures confirm that ordinal-six input starvation returns on warm reloads while the first load after core load is clean, the boundary to investigate is upstream ARM-side delivery rearm across successive sessions rather than the presentation scheduler or the startup guard, and the existing drained-FIFO warm-load simulation cases should be extended to model the measured 1,075,462-cycle starvation window before any RTL change is proposed. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Bob/Weave switching has still not been reported on and remains outstanding, analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 565 COMMIT Unreleased 2acabc5 2026-08-26T23:21:45-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the current accepted build, recovery context and outstanding validation for an agent handover requested by the user.

#### Outcome:

The current production source is `2acabc5457171f342a06f93b1edfb1c361748ce8`, with all source changes committed on master; subsequent commits are project-memory updates. The installed and user-loaded `/media/fat/MediaPlayer.rbf` is the qualified 4,346,416-byte image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`. The user says playback looks perfect. Entry 564 is the latest hardware acceptance: the requested clean Bob run of `bbb_480i_tff_15s_8mbps.m2v` accepts all 15,150,646 bytes, displays all 449 pictures with 448 swaps, terminates quietly and reports zero errors, zero cadence outliers and zero missed deadlines. The previous misses at pictures six and 348 are absent, and the maximum post-first-swap interval is exactly 2,002,000 clocks, consistent with 29.970030-fps steady playback. The aggregate 29.870022-fps figure includes startup because schema nineteen timestamps first reference completion rather than first visibility; do not treat it as renewed slowness. The user accepts the now-black idle background, which is the RGB startup mask, not a new sync or raster change. Preserve the earlier continuous-HS/VS framebuffer fix from `30d300a`, the 64-KiB clean-video queue and the guarded readiness-based startup controller. The controller waits for another presentable picture or short-file sequence end, releases the first cached picture at a complete field-pair boundary, then observes the acknowledged window high and low before enabling swaps; this last guard is essential because the preceding `134b401` controller fails the deliberately skewed CDC test. Timestamp/PCM records, incompatible pictures and non-native sessions bypass the reserve. The final build uses seed 16 and has positive setup, hold, recovery, removal and pulse-width margins of 0.141, 0.249, 3.830, 0.531 and 0.925 ns, with 512 of 553 RAM blocks occupied. The eleven-scenario simulation matrix covers 540 matching reconstructed pictures, full-file and dense-pause cases, alternate phases, drained-FIFO warm sessions, short EOF and modeled DDR pressure; the native suite and updated skew test pass. These are not an exact physical host/HDMI replay, partial-transfer cancellation test or independent pixel oracle. Build, validation and deployment manifests are `.ai/current_results/entry562_build.json`, `entry562_validation.json` and `entry562_deployment.json`; the latest screenshot and complete hardware decode are `entry564_bob_terminal.png` and `entry564_bob_capture.json`. GUNSMOKE is available through the configured SSH alias `mister-build`; the clean official build and RBF are under `/home/vash/mister-builds/entry562-2acabc5`, final simulation reports under `/home/vash/mister-builds/entry562-results`, and the unchanged native-suite log under `/home/vash/mister-builds/entry561-results`. The simulation checkout `/home/vash/mister-builds/entry561-sim` has a historical detached HEAD and modified files whose final source identity was verified; use published GitHub source for subsequent official builds. The superseded `entry561-134b401` build was stopped and must not be deployed. The Pi repository has no outstanding tracked source edits; eleven older untracked diagnostic PNGs were deliberately left untouched. No new source change or build is pending. The user requested this handover before performing the remaining repeated-load/mode-switch checks, so their result must not be assumed.

#### Next Steps:

Follow `core.md` recovery policy and resume with the remaining hardware test, not another speculative fix: ask the user to replay the same file several times without rebooting and switch Bob/Weave, reporting any flicker, pacing or load problem and leaving final telemetry visible. Capture through ordinary FTP only at MiSTer `10.10.0.30`; delete only `/media/fat/screenshots/cadence_probe.png` before triggering a new screenshot to prevent stale-file reuse, then decode with the existing cadence tools. Do not remotely reload, reboot or launch through MGL. Standing authorization permits future direct active-RBF replacement only after a qualified build and fresh complete FTP readback, without backup or staging files. Keep HDMI at the user's existing 1080p configuration and keep analog diagnostics excluded. If repeated loads and Bob/Weave also pass, close the bounded all-I HDMI cadence correction and obtain approval for the next audio/PTS qualification or broader interlaced implementation boundary. Interlaced P/B, field pictures and field-DCT remain unsupported; partial-transfer cancellation and the old 6,529,996-versus-6,529,997 live-raster assertion drift remain unvalidated or unresolved. Do not reuse entry 550's unvalidated pixel harness as a passed oracle. Keep `core.md` unchanged, preserve the forty-entry log ring and publish future approved plans before editing production source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 564 COMMIT Unreleased 2acabc5 2026-08-26T23:19:26-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Validate the guarded startup and larger input queue against the requested clean Bob hardware run.

#### Outcome:

The user reports that playback looks perfect and observes that the former grey 800x600 background is now solid black, without considering that a defect. A fresh FTP screenshot was triggered after deleting only the old fixed screenshot target; its schema-nineteen checksum validates all 15,150,646 bytes, 449 decoded and displayed pictures, 448 swaps, sequence end, presentation completion and quiet terminal reason one with zero aggregate errors. Both ranked-gap and actual missed-deadline counters are zero, the deadline-record array is empty, and all three largest measured post-first-swap intervals are exactly 2,002,000 decoder clocks, or 33.366667 milliseconds. The previous picture-six and picture-348 missed windows from entry 559 therefore do not recur in this run, consistent with the user's visual acceptance and the intended steady 29.970030-fps schedule. The raw aggregate remains 29.870022 fps because schema nineteen starts at first reference completion and includes startup buffering and raster alignment; its 899,898,892-cycle span exceeds 448 nominal intervals by 3,002,892 clocks, or 50.0482 milliseconds, without any post-startup gap. This is not evidence of slower steady playback. The black idle background follows directly from the RGB startup mask remaining active before picture release; DE, HS, VS and the idle timing generator are unchanged. This entry passes the requested clean Bob elementary-stream hardware case, not all interlaced formats or repeated-load conditions. Bob selection and loaded-source identity follow the user's preceding reload/run workflow rather than being encoded in the screenshot. No core, media, configuration or lifecycle change was made during capture. Evidence is `.ai/current_results/entry564_bob_terminal.png`, 476,291 bytes with SHA-256 `c442dd2144982f65b4bc19d0cdd07c1399936133e8e30f6ec90fcd6a1feeaf2b`, and `entry564_bob_capture.json`, including the complete decode, comparison, calculations and scope limitations.

#### Next Steps:

Have the user replay the same file multiple times without rebooting and test Bob/Weave switching, leaving the final telemetry visible and reporting any flicker, pacing change or loading problem. Preserve the accepted clean-run behavior and black startup background. If those checks also pass, close the current HDMI cadence correction for the bounded all-I path and move to a separately approved audio/PTS qualification boundary before broader interlaced P/B, field-coding and format work. Partial-transfer cancellation and the pre-existing live-raster assertion drift remain outside this hardware acceptance, and analog diagnostics remain excluded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 563 COMMIT Unreleased 2acabc5 2026-08-26T23:13:49-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Qualify and deploy the guarded native startup and larger input queue for the next clean HDMI cadence test.

#### Outcome:

Source `2acabc5` completes a clean Quartus 17.0.2 Lite build from empty generated state on GUNSMOKE in 722.51 seconds with seed 16, zero errors and 208 warnings. All timing classes are positive: setup 0.141 ns, hold 0.249 ns, recovery 3.830 ns, removal 0.531 ns, minimum pulse width 0.925 ns; every reported total negative slack is zero. The fit uses 31,304 ALMs, 49,685 registers, 4,048,355 block-memory bits, 512 RAM blocks and 67 DSP blocks. All sixteen unmatched diagnostic/reset timing filters are inherited from the installed schema-nineteen source; none of the new startup crossings is unmatched, and the tracked build source remains unchanged. Eleven simulation scenarios cover 540 reconstructed pictures across thirteen sessions, with every picture fingerprint matching its corresponding full-source baseline picture. The full 449-picture run under a synthetic thirty-millisecond host-resume pause has zero post-startup gaps; its visibility-based span is 896,896,004 decoder cycles, approximately 29.970030 pictures per second, with a few clocks of observation skew. The dense source-340-through-355 excerpt passes a forty-five-millisecond pause without the three legacy gaps, as do alternate phases, three drained-FIFO warm loads, periodic DDR pressure and one/two-picture EOF cases. The legacy 16-KiB/no-reserve control still reproduces its expected picture-six gap. The 24-phase deliberately skewed startup test passes, while the previous controller fails the same control by replacing the first bank at its initial visible boundary. The native suite exits successfully in 839.54 seconds; its timing, framebuffer, ownership and profiler source is unchanged by the guard correction, and its changed initial startup invocation is superseded by the separately passing corrected test. The queue capacity/wrap regression passes 85,696 bytes, four ordered timestamps and three PCM samples. The pipeline model uses synthetic host pauses, behavioral FIFO visibility and synthetic field windows, not a measured hardware trace or full HDMI raster; fingerprints establish scheduling invariance rather than an independent pixel oracle. Schema nineteen's aggregate still starts at first reference completion and includes startup buffering, so steady swap intervals and deadline counts remain the hardware cadence criterion. The 4,346,416-byte RBF has SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` and was directly installed at `/media/fat/MediaPlayer.rbf` under standing authorization. A fresh independent FTP connection read back the entire active image with matching size and hash; no backup, staging file, reload, reboot or media/configuration change was made. Build, validation and deployment evidence is in the three entry-562 JSON files under `.ai/current_results`; full logs and traces remain under `/home/vash/mister-builds/entry562-results` and the clean build directory `/home/vash/mister-builds/entry562-2acabc5`. Hardware acceptance is pending, partial-transfer cancellation is not covered by the drained-FIFO warm test, and the pre-existing live-raster assertion drift remains unresolved.

#### Next Steps:

Have the user reload the installed `2acabc5` core, select Bob and play `bbb_480i_tff_15s_8mbps.m2v` once without mode or menu changes, then leave terminal telemetry visible for a fresh capture. Check all 449 pictures and 448 swaps, terminal completion, zero aggregate errors and zero deadline gaps, especially the prior ordinals six and 348; distinguish the deliberate startup wait from steady playback cadence. If the clean run passes, repeat loads and Bob/Weave switching before claiming the cadence issue resolved. Keep analog diagnostics out of scope and preserve the accepted continuous HDMI sync fix.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 562 COMMIT Unreleased 2acabc5 2026-08-26T22:55:24-07:00

#### Coming From:

Unreleased 134b401

#### Purpose:

Make the first complete visible field pair independent of relative synchronizer latency before qualifying the startup candidate for hardware.

#### Outcome:

Source `2acabc5` adds an explicit observed-window guard to the approved startup implementation. After the video-domain visibility acknowledgement arrives, the decoder must observe the synchronized first window high and then low before allowing any swap, removing dependence on the relative arrival order of two independent synchronizers. The first visible bank therefore remains for a complete field pair even when the window crossing is delayed. The directed test alternates ordinary and deliberately delayed window crossings across 24 readiness phases and passes full-first-pair, short EOF, warm download rearm, interrupted startup, bypass and Bob/Weave controls. As a negative control, the same skew test fails the previous 134b401 controller with shown and first-swap boundary both seven, proving it detects the race. The correction does not change intended frame timing, queue size, sync, ownership or timestamp policy. The superseded build and unfinished full simulation were stopped without deployment; completed initial-candidate tests remain evidence only for that source. A fresh empty-state Quartus build and full real-pipeline simulation matrix are now running for 2acabc5. The existing native suite continues with unchanged timing, framebuffer, scheduler and profiler source, and the changed startup controller/test has been separately rerun. Hardware acceptance remains pending.

#### Next Steps:

Finish the corrected-source full-file, dense-excerpt, input-pause, phase, short-file and warm-load matrix with pixel-identity comparison, and verify the unchanged native-suite source provenance plus the separately updated startup result. Require a successful clean build with positive setup, hold, recovery, removal and pulse-width margins before direct active-image replacement and independent full FTP readback. Record those outcomes in a new entry and leave reload and the clean Bob run to the user.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_native_startup.sv
- MediaPlayer_top_05.svh
- tools/streams/tb_h262_native_startup.sv
- tools/streams/tb_h262_input_cadence.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 561 COMMIT Unreleased 134b401 2026-08-26T22:44:26-07:00

#### Coming From:

Unreleased c4628b5

#### Purpose:

Increase resilience to delivery pauses with a larger clean-video queue and coherent readiness-based startup for native elementary-stream playback.

#### Outcome:

Source `134b401` implements the approved 64-KiB clean-video queue and native 29.97-fps elementary-stream startup reserve. It waits for a second presentable picture or terminal sequence end, unmasks the cached first bank at a complete field-pair edge and admits scheduler swaps only after that edge's synchronized visibility acknowledgement. HS, VS, DE, framebuffer sync sampling, raster clocks and ownership remain unchanged. Extracted timestamp or PCM records, non-I headers, syntax/probe errors and non-native or other-cadence sessions bypass the reserve; bypass is sticky until a new download. The actual eight-cycle download-rearm controller passes 24 readiness phases, short EOF, progressive and cadence bypass, interrupted startup and Bob/Weave controls. The extended queue test retains all 65,536 bytes at capacity and passes 85,696 ordered bytes across wrap with four correctly positioned timestamp records and three PCM samples. The first eight-picture real-pipeline run under a synthetic thirty-millisecond host-resume pause has zero missed windows or deadline gaps, with initial visibility at cycle 4,198,676 and the first actual swap one full frame later. An initial test harness wired the profiler to the old synthetic window instead of the new synchronized window and incorrectly reported six gaps; aligning that passive tap to production resolves the discrepancy without changing production control. Full-file, dense-excerpt, alternate-phase, drained-FIFO warm-session and native-suite checks are running on GUNSMOKE. Schema nineteen still measures its aggregate from first reference completion; its post-first-swap deadline records exclude startup, and the harness additionally reports visibility-based spans. This is input-pause resilience, not faster decoding or an exact replay of the hardware picture-348 miss. No Quartus build or hardware replacement has completed yet.

#### Next Steps:

Finish the full-file fingerprint, pause, reload and native regressions, pull the published source from GitHub into an empty build checkout on GUNSMOKE and require positive setup, hold, recovery, removal and pulse-width timing plus a fitting memory allocation. Record qualification and any subsequent findings in a new entry, then directly replace the active MiSTer image under standing authorization and verify a fresh full FTP readback. Leave reload to the user and request one clean Bob run before repeated-load and Bob/Weave checks. The separate live-raster assertion drift remains unresolved and partial-transfer HPS cancellation is not covered by the drained-FIFO warm test.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_native_startup.sv
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- MediaPlayer.sdc
- files.qip
- tools/streams/tb_h262_input_cadence.sv
- tools/streams/run_input_cadence.py
- tools/streams/tb_h262_clean_video_queue.sv
- tools/streams/tb_h262_native_startup.sv
- tools/streams/run_native_480i_timing.sh
- README.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 560 COMMIT Unreleased c4628b5 2026-08-26T22:38:14-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Evaluate input buffering and startup reserve with the real decode pipeline before selecting a cadence correction.

#### Outcome:

The user approved the simulation work recommended after entry 559. Source `c4628b5` adds a reproducible real-frontend, I reconstruction, writer, scheduler and profiler harness through the production HPS FIFO wrapper, transport gate, metadata extractor and clean-video queue. Behavioral FIFO primitives provide bounded showahead storage, byte ordering and synchronized pointer visibility; they are not cycle-exact Intel or physical CDC models. The final direct-input control matches entry 557's header, completion and presentation traces cycle for cycle. Twenty-five scenarios pass byte/order, sample-count, bank-generation, final-drain and counter-partition checks, and all 1,543 reconstructed pictures have fingerprints matching the corresponding pictures in the full-stream baseline; these fingerprints are scheduling-invariance checks, not a new independent pixel oracle. Full 449-picture runs complete in approximately 695 seconds each. The default queues have only the known picture-six gap; adding a synthetic thirty-millisecond host-resume pause increases its critical input wait to 886,005 clocks and produces additional service delay elsewhere, but still does not reproduce the hardware picture-348 miss. A simulation-only 64-KiB clean-video queue plus startup reserve eliminates post-startup gaps across all 449 pictures under that scenario. In a separate excerpt of the exact source pictures 340 through 355, starting with fresh decoder state and a forty-five-millisecond resume pause, default buffering produces gaps on source pictures 348, 349 and 352; the combined experiment removes all three with identical picture fingerprints. This excerpt is not a replay of the hardware state or host trace. Smaller-buffer, alternate-phase, periodic-DDR-busy and full-reset repeated-session controls pass their checks; the one-picture terminal case drains correctly. A deliberately sparse two-picture control distinguishes 47,826 clocks of transform overlap from critical byte waits, validating why the earlier hardware ready/empty count cannot all be treated as critical delay. The startup experiment suppresses raw frame windows: in the tested phases two suppressions move the first actual swap by one frame, or 33.367 milliseconds. It moves the early hold into startup and does not accelerate decoding or shorten the full-stream completion time. Production startup must instead release display and timing coherently based on readiness; the raw-window experiment must not be copied blindly. Warm partial download rearm, Bob/Weave interaction, physical host scheduling and full HDMI/DDR behavior are not newly validated here. Results, commands, hashes and limitations are preserved in `.ai/current_results/entry560_input_simulation.json`, with complete per-case reports and CSV traces under `/home/vash/mister-builds/entry560-results`. All production RTL, constraints and the installed `31a87b6` image remain unchanged. No Quartus build or new hardware acceptance was performed.

#### Next Steps:

Request approval to implement and hardware-test a 64-KiB clean-video queue with readiness-based startup reserve, preserving continuous HDMI sync, field-pair timing, ownership and byte/metadata ordering. Treat the simulation as evidence for resilience to input delivery pauses, not proof that the exact hardware picture-348 cause has been recovered. Define initial display release and cadence measurement explicitly so startup buffering is not mistaken for a playback-speed correction, and preserve audio/timestamp semantics rather than applying the elementary-stream experiment indiscriminately. Extend the relevant startup, short-file, warm-reload and native-mode regressions, then require a clean successful Quartus build with every timing class positive before the standing-authorized replacement and fresh complete FTP readback. Repeat the known clean Bob file before subsequent Bob/Weave and repeated-load checks.

#### Files Modified:

- tools/streams/tb_h262_input_cadence.sv
- tools/streams/run_input_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 559 COMMIT Unreleased 31a87b6 2026-08-26T22:13:16-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Read the first hardware deadline capture and distinguish missing presentation candidates from scheduler refusal.

#### Outcome:

The user reported the requested file run complete and telemetry ready. A fresh FTP screenshot, after removing only the old fixed screenshot target, validates as schema nineteen with checksum and full counters: all 15,150,646 bytes, 449 decoded/display pictures and 448 swaps, sequence end and presentation completion, and zero aggregate error flags. Two confirmed doubled intervals are explicitly associated with full picture ordinals six and 348; the earlier modulo-bank inference is now directly corroborated. Neither candidate was presentable at its actual missed window, with only five and 347 completed references respectively, and neither presentation nor destination hold was asserted. Candidate six became ready 28.854 milliseconds late, while candidate 348 became ready only 0.297 milliseconds late; each missed window added one 33.367-millisecond frame period. The preceding swap-to-deadline intervals contain 13.594 and 15.129 milliseconds with the decoder ready but its clean-video queue empty, versus zero and 36 clocks of writer-capacity blocking. In both records, the clean-video queue had a byte available at the captured deadline itself, when the decoder was busy. These measurements identify late candidate production and substantial earlier input-availability gaps, not an on-time candidate rejected at either window. They do not yet prove a specific host-refill cause: the one-byte bitreader can advertise readiness while the parser is in `ST_WAIT_PIPELINE`, so input-ready/empty time can overlap transform work and must not all be counted as critical-path delay. The counters cover only the previous display interval, and writer-capacity blocking does not measure every DDR-service delay. The 347-completion to 348-readiness interval is 61.911 milliseconds in hardware versus 44.903 milliseconds between completions in the ideal-input/DDR simulation, an additional 17.008 milliseconds; the different initial raster phase and unobserved host schedule prevent treating that comparison as an exact replay. At picture 348's deadline the accepted stream position is just 83 bytes before the next picture header. The input path has a 32-KiB HPS FIFO followed by the metadata extractor and a 16-KiB clean-video queue, providing a concrete next simulation boundary without changing HDMI timing. Overall cadence is 29.806318 pictures per second over 15.030370 seconds; two doubled gaps contribute 66.733 milliseconds, while another 15.370 milliseconds comes from the first-reference-completion versus later-swap timestamp basis. The screenshot and complete decode, calculations and limitations are retained in `.ai/current_results/entry559_bob_terminal.png` and `entry559_bob_capture.json`; screenshot SHA-256 is `50571f4d7558c24fee23cced747f39d5a80b3ee887d9bb03411c8633b0d9ea17`. No production source, active image, display settings or core lifecycle changed during capture. The diagnostic yielded useful hardware evidence, but the remaining cadence issue is not resolved and this elementary stream does not validate audio synchronization.

#### Next Steps:

Request approval for the next cadence cycle: extend the real-pipeline simulation with the existing HPS ingress, extractor and clean-video queues, separating critical byte waits from transform overlap and varying refill pauses within the measured evidence rather than claiming an invented host trace is ground truth. Compare startup reserve, input buffering and bounded decode-headroom improvements, preserving byte/pixel identity, end-of-stream draining, repeated-load behavior, Bob/Weave transitions and the accepted continuous HDMI sync. Select a playback change only after its benefit and limits are demonstrated; then require existing regressions, a clean positive-timing build and independently verified deployment before another hardware test. No additional screenshot is needed before that simulation work.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 558 COMMIT Unreleased 31a87b6 2026-08-26T22:07:06-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Qualify and deploy the approved passive deadline diagnostic while retaining the accepted HDMI sync correction.

#### Outcome:

Source `31a87b6` completed a clean Quartus 17.0.2 Lite build on GUNSMOKE in 688.32 seconds with seed 16, zero errors and 208 warnings. Every timing class is positive: setup 0.240 ns, hold 0.252 ns, recovery 3.363 ns, removal 0.567 ns, minimum pulse width 0.925 ns; all reported total negative slack values are zero. The 4,280,760-byte image has SHA-256 `3ab905467e890366a091a31884639cce6a79626413f5eb16f72a8d0756b702b5`. The full existing native-video script exited successfully, including presentation overlap, continuous sync across generation resets, both field orders, cache fault controls, three-generation ownership with delayed memory, writer fingerprints and the schema-nineteen recorder/screenshot round trip. Separate queue and writer availability tests also pass. The simulated tracked source outside metadata is byte-identical to the official build checkout. An additional real frontend, reconstruction, writer, scheduler and profiler simulation of the exact first eight source pictures reproduces only the picture-six miss: its candidate becomes ready 669,812 decoder clocks, or 11.164 milliseconds, after the missed window, with zero decoder-input starvation and zero writer-capacity blocking. This validates recorder attribution under ideal input and DDR availability, not the cause of the hardware picture-348 gap. The accepted framebuffer, timing generator, scheduler, scaler, constraints and seed remain unchanged from `30d300a`; this is a diagnostic image, not a cadence fix. Under the user's standing replacement authorization, the active `/media/fat/MediaPlayer.rbf` was replaced directly over FTP, and an independent fresh connection read back the entire image with matching size and SHA-256. No core reload or reboot was triggered. Build, validation and deployment evidence is preserved in the three entry-557 JSON files under `.ai/current_results`, with full reports and test artifacts under `/home/vash/mister-builds/entry557-31a87b6` and `/home/vash/mister-builds/entry557-diagnostics`. Hardware validation remains pending. The separate live-raster soak's previously recorded assertion drift was not addressed or reported as passing. In response to the user's roadmap question, the recommended later sequence is current 480i HDMI and audio/timestamp qualification, interlaced P/B and field-coding support, then broader cadence and format coverage; those later implementation changes are not part of this approval.

#### Next Steps:

Have the user reload the core, select Bob and play `bbb_480i_tff_15s_8mbps.m2v` once without further menu or mode changes, leaving terminal telemetry visible. Capture and validate schema nineteen, then inspect the full picture ordinals, actual missed-window readiness, clean-queue starvation and writer-capacity blocking before proposing a playback change. Preserve the accepted HDMI sync behavior and leave analog diagnostics out of scope. After this clean case, retain repeated file loads and Bob/Weave switching as regression conditions. Require a measured explanation and an approved fix before claiming the remaining cadence issue is resolved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 557 COMMIT Unreleased 31a87b6 2026-08-26T21:45:31-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Capture decoder-input and presentation readiness at missed native frame deadlines without changing playback behavior.

#### Outcome:

The user approved the passive diagnostic build proposed in entry 556. Source `31a87b6` implements schema nineteen using the unchanged sixty-four-word overlay geometry and common cadence/error counters, replacing the retired framebuffer-detail payload with full sixteen-bit picture/swap counts and the first three confirmed missed-deadline records. Each record retains the upcoming display ordinal, completed-reference count, exact window state, completion age, decoder-input starvation and writer-capacity stall counts, accepted byte position and subsequent candidate readiness delay. The observer samples the window bus coherently, waits one further clock for the scheduler's registered bank change, and retains a miss only if a later presentation confirms that the gap eventually ended. This avoids both an on-time swap being misclassified from its old bank and terminal idle consuming record slots. Availability is tapped directly before the decoder instead of inferred from the upstream HPS FIFO; writer-capacity blocking is observed separately from its acknowledgement pulse and DDR busy level. The continuous HDMI sync fix, raster, decoder arithmetic, scheduler admission/ownership, memory transactions and queue control are unchanged. The extended RTL test passes exact window-state retention, eleven measured input-starvation cycles, writer attribution, late and already-ready candidates, on-time swaps, ordinal 348, multiple windows in one gap, bounded record retention, terminal idle and session/mode reset. A saved RTL packet decodes correctly through a rendered screenshot with ordinals three, four and 348, and the Python suite also passes legacy layouts, full 449-picture counts/rate and saturation handling. Queue and writer tests prove the new availability taps against real retained bytes and a blocked two-bank drain. Retired framebuffer fields are explicitly unavailable in schema nineteen rather than decoded as errors. The unchanged native-video regression is still running; no official Quartus image has yet been built or deployed. The user's question about using simulation alone was answered with the remaining boundary: the integrated ideal-input/DDR simulation does not reproduce the hardware picture-348 delay, so measured hardware wait evidence is needed before claiming its cause.

#### Next Steps:

Implement the passive taps and event recorder, extend the existing profiler and screenshot-decoder tests for exact-boundary capture, late readiness, input-versus-writer attribution, ordinal wrap, on-time presentation, terminal idle and repeated-session reset, and retain the native sync regressions. Commit the validated source from the Pi and pull it into a clean GUNSMOKE build directory. Require a successful Quartus build with positive timing in every class before directly replacing the active MiSTer image under the standing authorization, verifying the complete image through independent FTP readback and leaving core reload to the user. Request one clean Bob playback for the new capture before exercising repeated loads or Bob/Weave changes.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_clean_video_queue.sv
- tools/streams/tb_h262_ddram_store_overlap.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/test_decode_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 556 COMMIT Unreleased 30d300a 2026-08-26T21:40:34-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Compare a rebooted single Bob run with the warm-session cadence result and extend the reproduction through the production writer and publication scheduler.

#### Outcome:

The user rebooted the MiSTer, loaded the core, selected Bob and played the established clip once without reported playback interaction. A fresh FTP screenshot, obtained after deleting only the fixed old screenshot target, validates as schema eighteen and is preserved in `.ai/current_results/entry556_bob_cold_terminal.png`; its SHA-256 is `08c04b672a845736dd5f6f65f27225bc324676842abf7638d0a9d5790161d489`. All 15,150,646 bytes are accepted, sequence end and presentation completion are reached, and aggregate and framebuffer integrity error counters remain zero. The source's 449 pictures and the wrapped display counts plus 448 publications support 448 swaps over 15.053786 seconds, averaging 29.759956 pictures per second. Three doubled gaps contribute 100.100 milliseconds of excess duration, with another 5.419 milliseconds attributable to the initial reference-completion versus later-swap timestamp basis. The reset count is 449, not 448: generation reset includes native mode changes as well as swaps, so never substitute that counter as the swap count; one extra native-entry reset is consistent with the cold start but was not individually traced. Repeated loads and Bob/Weave switching are therefore not necessary to trigger the recurring gap. Entry 555's ordinal ambiguity can also be narrowed using the existing bank metadata: under ordered all-I presentation from bank zero, the previous display bank is the upcoming picture ordinal minus two modulo three. The stored display banks uniquely select pictures six, seven and 348 from their eight-bit ordinals six, seven and 92; the warm run similarly selects six and 348. This is a source-invariant inference, not a newly captured per-picture hardware trace. The FIFO-pending flag observes the upstream HPS FIFO, not the separate sixteen-kibibyte clean-video queue, so an empty flag alone does not prove decoder starvation. A temporary integrated observer on GUNSMOKE now executes the unchanged production frontend, three-bank publication shell, I reconstruction, two-bank DDR writer and native scheduler together, checking exact sample counts, all error flags, picture identity order and final store totals. With always-available decoder input, always-ready DDR writes and exact field/frame pulses, all 449 pictures and 29,095,200 accepted DDR words pass in 446.85 seconds. Only picture six has a doubled interval; picture 348 completes 1,003,299 clocks, or 16.722 milliseconds, before its presentation window. The expanded simulation thus reproduces the early decode overrun but neither the additional cold picture-seven gap nor the recurring hardware picture-348 gap. Physical host transfer, extraction/clean-queue availability, DDR arbitration/read contention and full raster behavior remain outside this simulation. An optimized observer agrees with ninety-three events from the initial slower observer before that superseded run was stopped; the stopped run is not reported as a pass. Capture analysis, simulation results and diagnostic hashes are preserved in the two entry-556 JSON files, with observer sources and full CSV logs under `/home/vash/mister-builds/entry556-cadence-analysis`. No production RTL, settings, constraints or active image changed, and the accepted HDMI flicker correction remains intact.

#### Next Steps:

Request approval for one passive cadence-telemetry build that records the full picture ordinal and readiness at the actual missed swap window, including decoder-side clean-queue availability, writer capacity and candidate publication timing, instead of relying on a later threshold snapshot or the upstream FIFO alone. Keep the accepted HDMI sync behavior and scheduler ownership unchanged, qualify the telemetry decoder and event capture in simulation, and require a successful build with positive timing before the already-authorized direct image replacement and independent readback. First repeat this clean Bob case; retain repeated loads and Bob/Weave switching as subsequent regression conditions rather than assuming they caused the cold-run gap. Do not claim that all remaining delay is explained or apply a playback-clock adjustment from these results.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 555 COMMIT Unreleased 30d300a 2026-08-26T21:17:18-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Identify the remaining native playback cadence shortfall without changing the hardware-validated HDMI path.

#### Outcome:

The user requested a cadence investigation and clarified that entry 554's terminal capture followed repeated file loads and Bob/Weave changes, not a reboot and single launch; treat it as a warm session. The 448 measured intervals exceed their ideal duration by 4,260,958 decoder cycles, or 71.016 milliseconds: two doubled frame gaps account for 66.733 milliseconds and the first-reference-completion to later-swap timing basis accounts for the remaining 4.283 milliseconds. This is not evidence of a continuously slow raster clock. An unchanged-scheduler control with the existing ideal I feeder passes one thousand consecutive frame windows with no denial or gap at both four- and five-clock field-to-frame-window delays. A temporary observer generated from the existing interlaced-I reconstruction bench then processes the exact 449-picture clip through the production I parser, inverse quantizer, IDCT and reconstruction, checking 518,400 samples per picture and every pipeline error. It completes 866,735,142 simulated cycles in 226 seconds on GUNSMOKE. This excludes host transport, physical DDR persistence and presentation, so its timings are optimistic decode bounds, not a complete hardware reproduction. Thirty-three pictures individually exceed the 2,002,000-clock frame budget; average reconstruction is 32.172 milliseconds, picture six needs 48.587 milliseconds, and picture 348 needs 44.632 milliseconds. Across all pictures the measured cost fits 1,626,640 fixed clocks plus 9.00008 clocks per source byte with less than ninety-five clocks of residual error, matching the current bitreader's eight serial bit-consume cycles followed by a byte-refill bubble. Most overruns can be absorbed by buffering. Replaying these measured costs, compressed one thousand to one, through the actual scheduler with three ordinary banks reproduces the picture-six doubled interval near the captured raster phase, while different initial phases absorb it behind a longer initial interval. The second hardware gap is not reproduced: its stored eight-bit ordinal 92 could mean picture 92 or 348, and the expensive 347-through-349 group is a candidate rather than proof because the optimistic replay still absorbs it. No inference about mode switching or reload state has been accepted as a cause. A single Bob replay without menu or mode changes during playback, without reboot, has been requested to isolate that remaining difference. `.ai/current_results/entry555_cadence_analysis.json` retains the measurements, bounds and diagnostic hashes; the generated observer sources, complete per-picture CSV and control logs are preserved on GUNSMOKE under `/home/vash/mister-builds/entry555-cadence-analysis`. No production source, constraints, settings or active RBF changed, and entry 554's flicker acceptance remains valid; this cadence investigation is not yet closed.

#### Next Steps:

Capture the requested untouched Bob replay after the user reports completion, deleting the old screenshot target first, and compare its gap count, intervals and wrapped ordinals with the warm-session capture. If the second gap persists, extend the existing reproduction with the missing persistence or transport timing before changing scheduler ownership; if it appears only with interaction, exercise repeated loads and Bob/Weave switching as the user requested. Preserve `30d300a` and continuous raster sync. Treat parsing/transform throughput and startup buffering as candidate improvement boundaries only after the remaining gap is explained; neither a faster clock nor a new HDMI sync change is justified by this evidence.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 554 COMMIT Unreleased 30d300a 2026-08-26T21:03:11-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Record hardware acceptance of the framebuffer sync correction in both HDMI deinterlacing modes.

#### Outcome:

After reloading the deployed `30d300a` image, the user reports no flicker and smooth playback in both Bob and Weave, confirming the bounded hardware objective of entry 552. The user's initial impression of faster playback was explicitly withdrawn, so no speed correction or further speed investigation is requested. A fresh screenshot of the most recent Bob terminal state was obtained after deleting only the previous fixed screenshot target; `.ai/current_results/entry554_bob_terminal.png` is 476,506 bytes with SHA-256 `de017a4bd453bb6569beafe656509e42893eb3c38d10d545462dbc592af903fb`. Schema eighteen accepts all 15,150,646 bytes of the established Big Buck Bunny clip, reaches sequence end and presentation completion, freezes normally for quiet, and reports zero aggregate, presentation, cache-overlap, prefill, unpublished-reset, region, phase, tag, content or write-read mismatch errors. Both field fingerprints match their accepted-write expectations. Independent probing of the exact MiSTer file on GUNSMOKE verifies the known source checksum, 449 decoded pictures, frame-rate code four in all 449 sequence headers and zero rate-extension numerator and denominator fields, confirming 30000/1001 through H262-027. The eight-bit display counts wrap to 193 pictures and 192 swaps; corroborating sixteen-bit reset and publication counters are both 448. The resulting 448 intervals span 901,156,958 decoder cycles, or 15.019283 seconds at sixty megahertz, averaging 29.828322 pictures per second with two 66.733-millisecond gap outliers. The generic telemetry decoder's uncorrected delivered-fps field uses the wrapped counter and must not be taken literally for this run. Full telemetry, source-probe evidence and count interpretation are retained in `.ai/current_results/entry554_hardware_acceptance.json`. No RTL, settings, active image or playback state was changed during this inspection. Hardware acceptance here covers the observed flicker and smooth Bob/Weave playback, not every remaining media-player feature or the unrelated live-raster assertion drift.

#### Next Steps:

Keep `30d300a` as the hardware-validated baseline for the HDMI flicker correction and preserve its qualified build artifact and independent deployment checksum. Await the user's next requested development objective rather than changing cadence in response to the withdrawn speed impression. Future image replacements during approved development remain authorized under entry 553, with timing qualification and independent readback retained.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 553 COMMIT Unreleased 30d300a 2026-08-26T20:56:41-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Deploy the timing-qualified framebuffer sync correction and record the user's standing authorization for future core-image replacements.

#### Outcome:

The user explicitly authorized replacing the active image and stated that the agent may do so going forward. This is standing permission to directly replace this project's `/media/fat/MediaPlayer.rbf` during approved development cycles after successful build and positive timing checks, with independent full-file readback, without asking separately for replacement permission each time. The source remains `30d300a`; no source changes or additional build were needed. The Pi artifact was checked against the entry 552 build manifest, then uploaded directly through standard FTP, replacing the previous 4,248,544-byte image with the qualified 4,244,104-byte image. A new FTP connection independently read the complete destination and verified SHA-256 `d676cb58cb22d991a0638bd0dab2885f7b1bcdd87d23e085910ab05dd1acec57`, exactly matching the build-PC and Pi copies. No backup, staging copy or rollback file was created on the MiSTer, and no reload or reboot was triggered. `.ai/current_results/entry552_deployment.json` retains the transfer, independent verification and authorization record. The user has been shown actual before/after simulator output; the test's moving bar deliberately offsets the second field by four source pixels, so the corrected Weave image still exhibits expected motion combing and is not a sharpness comparison. Hardware acceptance remains pending actual HDMI playback.

#### Next Steps:

Ask the user to reload MediaPlayer, confirm stable HDMI lock before playback, and run the established Big Buck Bunny file at 1080p in Weave and Bob, checking whether the stale-field sticking and flicker are gone and whether any alignment defect remains. Record the user's observations in the next entry without treating successful transfer or simulation as hardware acceptance. Future timing-qualified image replacements within approved development work are already authorized; continue direct replacement and independent readback verification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 552 COMMIT Unreleased 30d300a 2026-08-26T20:05:04-07:00

#### Coming From:

Unreleased 558efef

#### Purpose:

Reproduce the observed stale-field HDMI hold in a simulation of the actual MiSTer scaler before proposing a behavioral correction.

#### Outcome:

The user approved the HDMI-only reproduction cycle and confirmed 1080p output. GHDL was unpacked privately on GUNSMOKE; direct behavioral execution of the unchanged scaler stopped on a natural-range underflow before video, so the harness synthesizes the actual VHDL into hardware-width Verilog and runs it with Verilator. The production timing generator, framebuffer output controls, sync-fix and scanline pipeline are retained, synthetic RGB labels replace only picture content, and a checked Avalon model supplies the scaler memory. Initial runs without generation resets did not reproduce the fault. Adding the real four-decoder-clock framebuffer reset at each frame window reproduces missing or retained content despite continuously advancing source pictures: the old path produces seventy-six scaler-input sync pulses for fifty-one source fields, all thirty-seven checked steady frames fail, and retained content reaches twenty-two pictures of age. The cause is the framebuffer's reset branch forcing active-low native HS and VS low while the independent timing generator continues, creating an extra vertical sync on each swap and rotating scaler buffers without a newly written field. This qualifies entry 550's output-stage exclusion: the moving-pattern bypass does not exercise framebuffer output controls during generation resets. The bounded correction keeps video_de, video_hs and video_vs sampling the same current-pixel inputs at the same clock-enable phase during picture/cache resets; RGB reset, decode, ownership, scaler logic and constraints are unchanged. The identical corrected 1080p run produces exactly fifty-one sync pulses for fifty-one fields and passes all thirty-seven checked frames with every output pixel accounted for and no identity older than two pictures. Bob, progressive and identical-field controls pass; an intentional twenty-three-slot source hold produces one settled Weave image for forty output frames and then resumes motion; deliberately stale source content still fails only the stale-field checks. A BFF startup case exposed an artificial two-megabyte limit in the memory model, corrected to the full eight megabytes per bank; BFF with memory stalls then passes twenty checked frames, and repeated before/after Weave runs match the earlier reports exactly for their first thirty-two frames, with all twenty-one checked frames failing before and passing after. The existing cache regression's new sync case fails on unchanged RTL at 380.619 nanoseconds and passes sixteen reset pulses after correction; ordinary refill, slow refill, late prefill, both field-order fingerprint and three-generation controls, and delayed generation reads all pass. Summaries, input hashes and output report hashes are retained in `.ai/current_results/entry552_hdmi_simulation.json`. This reproduces a stale-field failure mechanism, not the exact camera cadence or television processing; startup mode-lock frames are explicitly excluded. Publication of the initially prepared plan was denied by the approval system; the user subsequently explicitly approved committing and pushing master and proceeding to the official build. Source commit `30d300a` was published from the Pi and cloned into a fresh GUNSMOKE build directory. The unchanged seed-sixteen Quartus configuration completed in 685.70 seconds with zero errors and 148 warnings. Every reported timing class is positive: global setup 0.127, hold 0.216, recovery 3.908, removal 0.536 and minimum pulse width 0.925 nanoseconds, with zero total negative slack. The fit uses 31,653 ALMs, 50,399 registers, 3,655,139 block-memory bits, 464 RAM blocks and 67 DSP blocks. The generated RBF is 4,244,104 bytes with SHA-256 `d676cb58cb22d991a0638bd0dab2885f7b1bcdd87d23e085910ab05dd1acec57`, copied to the Pi as `/tmp/MediaPlayer_entry552_30d300a.rbf`; `.ai/current_results/entry552_build.json` retains all clock/class margins and build provenance. Deployment was rejected by the approval system because publishing and building did not explicitly authorize replacing the active MiSTer image. No upload or reload occurred, and hardware acceptance remains pending.

#### Next Steps:

Obtain explicit user authorization to overwrite the active `/media/fat/MediaPlayer.rbf`, then directly upload the already qualified image and verify its complete SHA-256 through a fresh FTP connection, without creating backups or staging copies on the MiSTer. Ask the user to reload and validate idle lock plus the established Big Buck Bunny playback in Weave and Bob over HDMI. Record deployment and hardware results in the next entry, without marking hardware acceptance from simulation alone. The pre-existing live-raster assertion drift remains outside this correction.

#### Files Modified:

- rtl/mpeg2_luma_framebuffer.sv
- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/run_native_480i_timing.sh
- tools/streams/run_hdmi_scaler_sim.sh
- tools/streams/tb_hdmi_scaler_stimulus.sv
- tools/streams/tb_hdmi_scaler.sv
- tools/streams/check_hdmi_scaler_sim.py
- tools/streams/hdmi_scaler_simulation.md

#### Status:

- [x] Built
- [ ] Passed

---

## 551 COMMIT Unreleased 558efef 2026-08-26T19:51:11-07:00

#### Coming From:

Unreleased 558efef

#### Purpose:

Characterize the visible flicker from camera footage, including the pre-playback interval no capture had ever observed.

#### Outcome:

Two user recordings settle what the flicker actually is, and it is not what thirty entries of framebuffer instrumentation assumed. The first is `.ai/current_results/PXL_20260827_023203846.mp4`, 99,984,960 bytes with SHA-256 `f7e5f638649d567b2f440760e8482253ffc58258b6653e72eae3d1391cce4246`, 1920 by 1080 at sixty frames per second for 24.07 seconds, playback beginning near six and a half seconds. Before playback the framebuffer still presents the previous run's final picture behind the file selector, a foliage scene retained beneath the menu with the telemetry overlay at left, which is the stuck screen the user described. The transition itself is decisive: at 6.600 seconds change rises from the camera noise floor, and at 6.750 seconds one frame shows Big Buck Bunny's opening sky and bird woven line by line with the previous scene's tree trunks, two entirely different pictures interleaved on alternate scanlines. That photograph is the same defect the schema-eighteen field analysis measured as bit-identical even rows, but with the two source pictures visibly distinct rather than a subtle ghost. Retained as `.ai/current_results/entry551_pre_playback_retained_frame.png` at 1,632,365 bytes with SHA-256 `51c9bafecad1b200cfd1318bcdb2be3af4fb67575768b908562be56e03eed458` and `.ai/current_results/entry551_field_weave_two_scenes.png` at 1,613,919 bytes with SHA-256 `4e1f2627ecc9a4082be321c4033e456301ed07079ba9ebc0dea119f76e528a50`. The stale field therefore survives a generation reset, a mode change and a fresh publication, which constrains whatever holds it. The second recording is `.ai/current_results/PXL_20260827_024238007.mp4`, 30,673,309 bytes with SHA-256 `a72e6ead0e645530d4a86b6eb314051d7b0740b687c77fd72e413fcfc9e34e3d`, a high-rate capture exported as 608 frames at thirty frames per second representing 2.53 seconds of real time at 240 frames per second. Its change series autocorrelates at 0.95 for a period of four frames, so the camera is phase locked to the display's sixty hertz refresh; sampling every fourth frame removes that aliasing and leaves genuine content change at sixty hertz. In that series the defect has an unmistakable signature. Across the affected interval the change one step apart averages 21.11 while the change two steps apart averages 2.59, so the display returns to the same image every 33.3 milliseconds: it is alternating between two fixed images at sixty hertz, a thirty hertz flip, rather than advancing through the video. Normal playback in the same clip shows the opposite relation, 4.26 at one step against 5.60 at two, which is what progressing motion looks like. Sixty-one per cent of the clip is in that alternating state, in two episodes of 783 and 733 milliseconds, so a single stick lasts roughly three quarters of a second or about twenty-two frame slots. The user confirms this is the sticking they see. A plausible mechanism follows directly and is worth testing rather than assuming: if the core holds one picture and keeps emitting its two fields alternately, a Weave deinterlacer that combines the two most recently arrived fields produces one composite and then the same pair in the opposite order, two vertically offset images alternating at thirty hertz. That would make a held picture strobe rather than merely freeze, and it agrees with entry 545's observation that Bob shows the artifact at approximately twice the Weave cadence, since Bob exposes single fields at field rate. Two attempted camera analyses failed and are recorded so they are not repeated: whole-frame difference cannot separate a stuck display from a genuinely static scene, and a vertical high-frequency measure intended to detect field mismatch is flat at 0.573 to 0.585 across all 608 frames because the camera does not sample display scanlines at a fixed phase. Ordinary sixty hertz FTP rasters remain the better instrument for field content; the camera's value is temporal.

#### Next Steps:

Reconcile the two facts that must both be true. The display holds one picture for roughly seven hundred fifty milliseconds, about twenty-two slots, while schema-sixteen telemetry reports 449 pictures and 448 swaps across the fifteen second file, close to the full 29.97 rate. Either the swap presents content identical to the previous picture, or the held interval is invisible to the swap counter; both halves are measurable and one of them is wrong. Prefer that question over any further framebuffer instrument, since fetch addresses, region resolution, cache writes and the write-read fingerprints are already exact. Test the Weave field-order hypothesis directly by comparing a deliberately held picture in Weave against the same interval in Bob, which pairs fields differently, before proposing any change. The analog VGA path remains fully driven with `VGA_F1` and `VGA_SCALER` low, so a CRT on an analog board would show the raw core output with the deinterlacer wholly removed and would separate a core-side hold from a deinterlacer amplification. Do not trust the pixel harness committed in entry 550 until its progressive control passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 550 COMMIT Unreleased 558efef 2026-08-26T19:32:00-07:00

#### Coming From:

Unreleased 127f576

#### Purpose:

Test whether interlaced P reconstruction drops a field parity, which entry 549 left as the last remaining explanation for the frozen first field.

#### Outcome:

Entry 549 established that every stage from the DDR write to the screen is faithful and concluded the staleness must already exist in what the writer stored, leaving reconstruction as the only candidate and noting that no regression could observe it. Commit `558efef` builds the missing vehicle. The soak's pixel oracle was hardwired to the one hundred twenty-eight by ninety-six, twenty-four picture mixed raster through an array bound of 442,367, component offsets of 12,288 and 15,360, a picture stride of 18,432, row strides of one hundred twenty-eight and sixty-four, a coordinate guard and a temporal-reference bound. All of those now derive from `PIXEL_WIDTH`, `PIXEL_HEIGHT` and `PIXEL_PICTURES`, whose defaults reproduce the original fixture exactly, and a new wrapper overrides them to seven hundred twenty by four hundred eighty across eight pictures. Per-parity mismatch counters were added and the summary is now emitted at the freeze path as well as at ordinary completion, so an early stop no longer discards the result. The interlaced P fixture from entry 549 was validated properly: decoding the patched and unpatched streams yields byte-identical 4,147,200-byte planes, so the signalling patch is semantically neutral and the oracle is sound, a check the all-I generator performs and the P generator had originally omitted. The experiment then answered the question it was built for, against the hypothesis. Across 3,093,120 samples it recorded 216,868 mismatches with a maximum delta of 231, but split by field parity those were 67,792 of 1,031,040 even against 68,532 of 1,031,040 odd, that is 6.58 and 6.65 per cent. Errors are distributed evenly across both fields. Nothing that damages both parities equally can leave one field bit-identical for seconds while the other updates every frame, so interlaced P reconstruction does not explain the flicker and the last standing hypothesis is eliminated. The apparent seven per cent defect is itself withdrawn, because the control refutes it. Running the known-good progressive fixture through the same harness mismatches 822,919 of 1,271,808 samples, 64.7 per cent, with a maximum delta of 251 and the same even-odd symmetry, while the identical run reports the decoder healthy with twenty-five pictures, twenty-five publications, twenty-five promotions, seventy-one swaps, exact accounting and no errors. A raw FFmpeg yuv420p decode is therefore not the oracle format this mode expects, and no figure the harness produces is meaningful until that control passes; the testbench and runner are committed carrying that warning in their headers. Two hardcoded bounds were found only by the run failing, a coordinate guard rejecting x of one hundred twenty-eight and a temporal-reference bound of twenty-four, both generalization defects of this commit rather than findings. Everything trustworthy continues to show the decoder healthy: interlaced I reconstruction retains zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, the native suite passes twenty-three cases, and hardware plays the complete 15,150,646-byte file with 449 pictures, 448 swaps and every error flag clear.

#### Next Steps:

Do not trust the pixel harness until the progressive control passes; establishing the oracle format `MIXED_PIXEL_MODE` actually expects is the prerequisite for any future use, and the absence of a runner script for the existing wrapper is why the interface had to be guessed. The flicker now has no candidate: reconstruction through writer, DDR, fetch, cache, display and output stage are each verified faithful by exact measurement, yet a first field stops updating for seconds. Prefer a measurement that leaves the current path entirely rather than another instrument inside it. The analog VGA output is already fully driven including the `VGA_F1` field flag with `VGA_SCALER` low, so an analog I/O board would present the core's raw 480i to a CRT with MiSTer's scaler wholly out of the loop; that is the only available observation that no capture through the processed path can reach, and it would separate a core-side field fault from anything introduced downstream. Camera footage of the interval before playback begins is also outstanding from the user, since every burst so far starts after the first pictures are already displayed.

#### Files Modified:

- tools/streams/run_interlaced_p_pixels.sh
- tools/streams/tb_h262_interlaced_p_pixels.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [x] Passed

---

## 549 COMMIT Unreleased 127f576 2026-08-26T19:03:23-07:00

#### Coming From:

Unreleased ffd0496

#### Purpose:

Determine whether the fetched luma words reach the line cache, and locate the frozen first field once the whole read path is accounted for.

#### Outcome:

Commit `b15b251` adds the last missing read-path measurement. The framebuffer exports the cache write event where `y_cache_wr_en` is raised, carrying validity, the parity of the fetch in flight and the actual cache address, and the profiler counts words and sums addresses for each parity, latched per generation. Schema seventeen becomes schema eighteen at sixty-four words with both appended words exactly thirty-two bits and both overlay origins moved eight rows up to 344 and 224. The references are again computed rather than observed: a healthy generation writes two hundred forty-two by ninety, or 21,780, first-field words and two hundred forty by ninety, or 21,600, second-field words, with sixteen-bit address sums of 48,766 and 32,656. An address sum was chosen over the XOR used for rows because the expected XOR is zero for both parities, which is also what no writes at all would produce and so could not discriminate the case under investigation. A clean build completed in 11 minutes 23 seconds with zero errors and 148 warnings, global setup, hold, recovery, removal and minimum-pulse-width margins of positive 0.217, 0.192, 4.020, 0.621 and 0.925 nanoseconds, a fit of 31,673 ALMs and 50,112 registers with block-memory bits and RAM blocks unchanged, and a netlist probe confirming every accumulator survives. The hardware reading is unambiguous. A burst on the same run showed the first field frozen in twenty of twenty-four active transitions, the worst observed, one stretch spanning fifteen consecutive samples, while the terminal snapshot returned every value exactly at its expected figure: row XOR two and zero, no region change, two hundred forty-two and two hundred forty fetches, 21,780 and 21,600 cache writes, and address sums 48,766 and 32,656. The pre-existing write-read fingerprints agree as well, the first-field expected and raw values both reading 635,643,363 and the second-field pair both 3,183,525,312, with zero session-scoped content mismatches and zero tag mismatches. The whole chain from reconstruction through writer, DDR, fetch, cache and display is therefore verified faithful while the displayed first field is seconds old. Because the luma line cache holds two lines and is overwritten every scanline, a field cannot be frozen inside it, so the staleness must already exist in what the writer stored, and the writer cannot skip a parity since its eight-row blocks span four even and four odd rows. The defect is therefore upstream of the DDR write, in what reconstruction hands the writer. A coverage gap matching that conclusion exists and had never been noticed: pixel-accurate reconstruction is verified for interlaced I pictures by a testbench whose source list stops at `mpeg2_h262_intra_recon` and cannot decode a P picture at all, and for progressive mixed I/P/B by the soak's `MIXED_PIXEL_MODE`, whose oracle is hardwired to a one hundred twenty-eight by ninety-six, twenty-four picture raster. Interlaced P and B reconstruction at 480i, which is what the test programme stream actually contains, has never been checked by anything. Commit `127f576` adds the missing fixture generator. FFmpeg cannot be asked directly for the wanted combination, since requesting interlaced encoding produces field motion types, field DCT and f_code three, which the decoder rejects at the first P header with no P pictures reconstructed; the generator therefore encodes frame-DCT frame-motion MPEG-2 with a short GOP and small motion range and applies the all-I generator's signalling patch, yielding a 304,926-byte frame-coded interlaced sequence with picture order I P P P I P P P, f_code one by one and top-field-first. Replayed through the soak, which compiles the complete decoder, that fixture is not rejected: six picture headers, 1,304 macroblocks and 1,305 motion vectors are processed before the bench freezes having consumed the whole stream, which is consistent with an eight-picture fixture ending early rather than a proven defect. No conclusion about field content can be drawn, because the soak has no pixel oracle for this raster.

#### Next Steps:

Generalize the soak's `MIXED_PIXEL_MODE` oracle dimensions so it can accept a 720 by 480 interlaced fixture and compare reconstruction against an FFmpeg decode, then replay the new interlaced P fixture and assert that both field parities change between consecutive pictures. That work is bounded, entirely local to the build PC and needs no image, install or playback. Do not propose a correction before it reproduces: the read path is now exonerated by exact measurement, but the reconstruction hypothesis is still only the last remaining candidate rather than a demonstrated fault. Retain the observation that field-motion interlaced P is refused outright while frame-coded interlaced P decodes, since any future fixture must stay inside the supported subset to be meaningful.

#### Files Modified:

- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/generate_test_interlaced_p_frames.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [x] Passed

---

## 548 COMMIT Unreleased ffd0496 2026-08-26T19:02:46-07:00

#### Coming From:

Unreleased 008909d

#### Purpose:

Record the native luma fetch addresses and any mid-sweep display-region change, which no existing counter could observe.

#### Outcome:

Reading the live readout path found that the two facts every recent diagnosis rested on were weaker than they had been read. The region evidence added in entry 518 overwrites its latch on every fetch edge, so it preserves only each parity's last sample and the profiler compares those two survivors at the generation boundary; a bank change partway through the first field's own two hundred forty fetches is invisible whenever the final samples happen to agree, and a zero region-mismatch count therefore means only that the last fetch of each parity matched. The per-field fetch counters are attributed solely by `line_number[0]`, so a count of two hundred forty-two proves that many even-row fetches were launched and nothing about which rows; one stale row fetched two hundred forty-two times yields the identical figure and would look exactly like a frozen field. Commit `ffd0496` closes both. The framebuffer exports the raw fetch event as validity, parity and the nine-bit row, and the profiler accumulates a per-parity XOR of the row number across a generation together with a per-parity flag set when any later fetch in that generation disagrees with the region seen on the parity's first fetch. Accumulating in the profiler rather than the framebuffer keeps the generation boundary unambiguous, which is the correction entry 520 recorded. Schema sixteen becomes schema seventeen at sixty-two words with one appended word packed as nine, nine, one, one and twelve bits, verified to total exactly thirty-two after entry 519 shipped a thirty-bit word, and both overlay origins move four rows up to 352 and 232 so the final row stays flush with the diagnostic and native rasters. The expected values are computable rather than empirical: a healthy generation sweeps first-field rows zero through four hundred seventy-eight plus prefill rows zero and two, whose XOR is two, and second-field rows one through four hundred seventy-nine, whose XOR is zero. The decoder prints both against those expectations, the directed profiler regression encodes a first field with a wrong XOR and a changed region against a healthy second field, and the entry 516 overlay row-coverage check immediately caught the stale testbench origins after the layout moved, earning its place after being worthless in entry 519. A clean build completed in 11 minutes 14 seconds with zero errors and 148 warnings; global setup, hold, recovery, removal and minimum-pulse-width margins are positive 0.212, 0.247, 3.355, 0.556 and 0.925 nanoseconds, the fit uses 31,636 ALMs and 49,859 registers with block-memory bits and RAM blocks unchanged from baseline, and a netlist probe confirms every new accumulator survives. On hardware, a fifty-frame burst confirmed the first field froze during the very run measured, ten of twenty-four active transitions showing bit-identical even rows, while the terminal snapshot reported a first-field row XOR of exactly two, a second-field XOR of exactly zero, no region change on either parity, two hundred forty-two and two hundred forty fetches and region zero for both. The first field therefore fetched all two hundred forty distinct rows plus both prefill rows, in one sweep, from a single region, while displaying content seconds old. The read addressing is exonerated, which is the first evidence in this investigation pointing away from the framebuffer reader.

#### Next Steps:

Instrument the one remaining uninstrumented step between the DDR read and the screen: whether the returned words actually reach the line cache for that parity. Nothing counts cache writes today, so a fetch that issues correctly and returns correctly but never lands would read exactly as this capture does.

#### Files Modified:

- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [x] Passed

---

## 547 COMMIT Unreleased 008909d 2026-08-26T17:07:17-07:00

#### Coming From:

Unreleased 008909d

#### Purpose:

Characterize the residual playback flicker by sampling the live raster instead of relying on terminal captures and subjective description.

#### Outcome:

Fifty full-raster screenshots were triggered at 0.6-second intervals through the MiSTer's ordinary FTP view of `/dev/MiSTer_cmd` while the established Big Buck Bunny file played in Weave on the accepted `008909d` image, every target filename being deleted beforehand so a missed trigger reports as absent rather than returning a stale frame. Forty-eight arrived and captures nine through thirty-two span roughly fourteen seconds of live playback, the preceding and following captures being the identical pre-start and post-playback terminal rasters. Comparing each capture against its predecessor separately by field parity is decisive: across captures seventeen to twenty-one and again across twenty-three to thirty-one the even rows are bit-identical, a mean absolute difference of exactly zero, while the odd rows change by between 0.808 and 98.798 over the same intervals. The even field refreshed only twice in fourteen seconds, once after approximately 3.0 seconds and once after approximately 5.4 seconds, while the odd field changed at every sample. Top-field-first is set and the framebuffer derives its authored first field as the inverse of that flag, so the frozen parity is the first field. A displayed frame therefore weaves a live field against one up to several seconds old, which at field rate is the flicker the user reports and also explains the translucent second image visible in the retained evidence, where a pale disc and bird shapes from an older picture are interleaved line by line with the current scene. Retained captures are `.ai/current_results/entry546_weave_frozen_field_20.png` at 345,683 bytes with SHA-256 `04e99ef04be4146f3a7627ccc042e076e8a3fd4d156a4e5630e7d081351e44fc`, `entry546_weave_frozen_field_21.png` at 349,434 bytes with SHA-256 `261a7a9c27680c046eb3a835094ebb685c285aade8b3d774f0d284dc1dbc90fc`, which shares its even field bit-for-bit with the preceding capture, and `entry546_weave_frozen_field_22.png` at 349,936 bytes with SHA-256 `f46104e32a8d83ef9462fd60a1e5e4bb182188e801cc2ef0bd745eb612e68510`, the frame where that field finally updates. This is the same signature entries 515 through 519 pursued and never closed, and it is separate from the frame-slot misses of entry 546, since two dropped slots in 448 cannot hold a field static for seconds. The most important result is that every existing counter calls this run clean: the schema-sixteen terminal capture reports all bytes accepted, 449 pictures, 448 swaps, 242 first-field and 240 second-field line fetches from a single region, and zero region, phase, prefill, unpublished-reset, cache-overlap, presentation, audio, tag, content and accepted-write errors. The per-field instrumentation added across entries 516 to 519 does not detect a first field that has not changed in three seconds, and entry 519 already recorded that the content evidence shipped with a malformed thirty-bit snapshot word, so its clear content result has never been trustworthy.

#### Next Steps:

Do not propose a correction from this evidence alone. The measurement establishes what the defect is, that it is upstream of anything the present telemetry inspects, and that the telemetry cannot see it; it does not establish where the first field stops being refreshed. Before any behavioral change, re-establish trustworthy content evidence, since the existing content word was proven malformed and every subsequent clean reading from it is void. The decisive next measurement compares, per parity and per generation, whether the pixels delivered to the display actually change between consecutive published generations, which no current counter attempts. Prefer a burst of live captures over a terminal capture for any hardware check of this defect, because every terminal raster in this investigation has shown both fields correct while live frames were visibly wrong.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 546 COMMIT Unreleased 008909d 2026-08-26T17:06:34-07:00

#### Coming From:

Unreleased 7cdfcec

#### Purpose:

Remove the measured native-playback frame-slot misses by overlapping reconstructed-block capture with the preceding block's DDR write drain.

#### Outcome:

Commit `008909d` gives the block writer two capture banks with per-bank geometry and a pending flag, separate capture and drain pointers, and a drain-side address view so every address, bound and debug value describes the bank being written rather than the bank being filled. A new `block_accepted` output carries capacity acknowledgement while `block_stored` keeps its exact previous meaning as the DDR-completion pulse, and `pipeline_block_done` on `mpeg2_h262_two_picture_probe` now takes the capacity signal; that signal's only functional use down the chain is the parser's `ST_WAIT_PIPELINE` gate, since `two_picture_probe_p_chain` and `picture_bookkeeper` merely forward it. Reaching a working image took four builds and two hardware failures, both recorded here rather than hidden. The first candidate expressed the capture banks as a two-dimensional array, which Quartus inferred as a sixteen-by-sixty-four `altsyncram` occupying two M10K blocks and absorbing the write pointer into an M10K read-address register; the combinational read this writer requires has no M10K equivalent, iverilog models a plain array either way, and no available simulation could see the difference. That image failed on hardware and the array is now held in registers by a `ramstyle` attribute, restoring memory bits and RAM blocks to the exact `7cdfcec` figures. The second candidate still failed, at fifty-four accepted bytes and 2,057 cycles with error flag bit three, `inverse_quant_error`, which is far upstream of any DDR activity. Its cause was expressing the capacity acknowledgement as a level: `cap` clears at `block_complete`, which is exactly when the parser reaches its wait state, so the gate stood open and the parser advanced into a busy inverse-quantiser. A first repair that consumed a credit on the writer's own `block_start` was also wrong and was discarded before building, because that strobe arrives only after inverse-quant, transform and reconstruction latency, leaving the credit high across the window that matters. The accepted form keeps `block_stored`'s pulse discipline and merely moves it earlier: one grant on each rising edge of capture-bank availability, emitted strictly after the parser is already waiting and therefore no more missable than the completion pulse it replaces. The focused regression `tb_h262_ddram_store_overlap.sv` proves ordered, exact sixteen-row delivery across two overlapped blocks, refuses a third while both banks are occupied, requires a grant per freed bank and rejects the level form that failed on hardware; an earlier version of that regression passed both forms and was therefore worthless, which is recorded because the same blind spot has now appeared twice in this project. The B-presentation scheduler, four-picture interlaced reconstruction and live-raster soak testbenches are unchanged, the soak retaining its pre-existing 6,529,996 against 6,529,997 assertion drift; none of them exercise the parser gate, the soak tying `pipeline_block_done` to constant one, so no simulation available here could validate the fix. A seed-fifteen fit missed global setup at negative 0.025 nanoseconds and was rejected; advancing the reproducible placement seed to sixteen with no RTL change produced positive 0.255, 0.246, 3.504, 0.556 and 0.925 nanosecond setup, hold, recovery, removal and minimum-pulse-width margins, above the `7cdfcec` baseline's positive 0.213 setup. The fit uses 31,522 ALMs, 49,958 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs, with no inferred RAM in the store module. The 4,230,940-byte RBF has SHA-256 `65c3c901419b128b868ea6b30031261f4e4f6a019bddb7bc3387fa473de82ef0`. On hardware the established Big Buck Bunny file plays complete in Weave with all 15,150,646 bytes accepted, wrapped counters representing 449 decoded and displayed pictures with 448 swaps, sequence end seen, presentation completion, normal quiet reason one and every error flag clear. Doubled presentation gaps fall from twelve to two, at display ordinals six and ninety-two, the presentation span shortens from 921,157,194 to 901,694,453 decoder cycles or 324.4 milliseconds, and delivery rises from 29.181 to 29.811 pictures per second against the 29.970 ideal. The entry's stated acceptance bar of no doubled gaps is therefore not fully met, two remaining and the span still 2.40 slots over ideal, but the writer serialization it targeted is substantially removed.

#### Next Steps:

Treat the residual two doubled gaps as a smaller, separate throughput question and do not reopen the writer for them without new evidence. The visible flicker is not this defect and is addressed in entry 547. Before any further writer work, note that no simulation here covers the parser-to-writer handshake, because the live-raster soak ties `pipeline_block_done` to constant one and the scheduler and overlap testbenches drive the writer directly; an integration testbench that models the parser gate would have caught both hardware failures in this cycle and is the single highest-value regression this area lacks.

#### Files Modified:

- MediaPlayer.qsf
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- tools/streams/tb_h262_ddram_store_overlap.sv

#### Status:

- [x] Built
- [x] Passed

---


## 545 COMMIT Unreleased 7cdfcec 2026-08-26T15:04:12-07:00

#### Coming From:

Unreleased 7cdfcec

#### Purpose:

Record the seed-fifteen Bob comparison and determine whether the remaining visual artifact follows decoder cadence or field reconstruction cadence.

#### Outcome:

The user reran the same Big Buck Bunny test file on the exact `7cdfcec` image with HDMI scaler deinterlacer changed only from Weave to Bob. Playback frame rate still appears correct and Bob looks better overall, while both the visible flicker and the residual ghosting appear at approximately twice the Weave cadence, like the same artifact running at double speed without speeding up the movie. The user judges that the decoder is keeping up and error-free but old frames remain visibly sticky in both Bob and Weave. The fixed remote screenshot filename was deleted before triggering, so `.ai/current_results/entry545_seed15_bob_terminal.png` is a genuinely fresh Bob capture; it is 479,897 bytes with SHA-256 `e917c5ef0c9cd00f7d72509e1360b63e3f89f76b1b6c3845578d2c93d2914ddf`. Schema sixteen accepts all 15,150,646 source bytes, reaches sequence end, presentation completion and normal quiet reason one, and its wrapped counters represent 449 displayed pictures and 448 publications and swaps. The terminal generation fetches 242 first-field and 240 second-field lines from region zero with zero region, phase, prefill, unpublished-reset, cache-overlap, presentation, audio, tag, content or accepted-write-versus-raw-return errors. The Bob presentation span is 920,029,226 decoder cycles versus 921,157,194 in the preceding Weave run, a difference of only 18.799 milliseconds across the complete file, confirming that the doubled artifact cadence is not doubled decoder or scheduler speed. The result instead ties the visible rate change to Bob exposing individual fields at field cadence while Weave combines field history at frame cadence; it does not by itself establish whether the remaining severity is expected deinterlacing behavior or an additional field-content defect.

#### Next Steps:

Retain Bob as the current preferred processed-HDMI mode and make no decoder, scheduler or raster-control change from this terminal evidence. Use one short, direct visual discriminator before another build: compare the same moving interval against a software Bob and Weave reference made from the exact interlaced test stream, focusing on whether MiSTer shows only the expected Bob line-doubling and Weave motion combing or retains an older field beyond one field interval. If MiSTer matches the reference, treat the residual difference as the normal Bob-versus-Weave tradeoff; if it retains older content, propose one bounded correction at the first proven divergent field boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 544 COMMIT Unreleased 7cdfcec 2026-08-26T14:57:08-07:00

#### Coming From:

Unreleased 7cdfcec

#### Purpose:

Record hardware acceptance of the restored MiSTer raster-control phase and preserve one fresh post-playback terminal capture.

#### Outcome:

The user reloaded the exact seed-fifteen `7cdfcec` image and reports that the idle screen works normally apart from the pre-existing flicker; after running the established Big Buck Bunny test file with HDMI scaler deinterlacer set to Weave, the catastrophic whole-screen synchronization failure is gone and the screen remains capture-capable. The fixed remote screenshot filename was deleted before triggering, so `.ai/current_results/entry544_seed15_terminal.png` is genuinely fresh rather than reused evidence; it is 479,876 bytes with SHA-256 `aaf9abd06b8286463ac2cd2081540e8c89ec14de29ade0cc1d84cf35b1eef5cd`. Schema sixteen accepts all 15,150,646 source bytes, reaches sequence end, presentation completion and normal quiet reason one, and its wrapped counters represent 449 framebuffer and displayed pictures with 448 publications and swaps. The terminal generation fetches 242 first-field and 240 second-field lines from region zero with zero region, phase, prefill, unpublished-reset, cache-overlap, presentation, audio, tag, content or accepted-write-versus-raw-return errors. MiSTer's screenshot command succeeds without the prior `Scaled not available` failure. The seed-fifteen correction therefore passes its bounded scaler-lock and external raster-phase objective in Weave; it does not fix or explain the remaining motion flicker.

#### Next Steps:

Keep commit `7cdfcec`, seed fifteen and the restored undelayed `video_de`, `video_hs` and `video_vs` contract as the new hardware baseline, and do not revisit the rejected registered-control phase. Treat the remaining flicker as a separate decoded-field presentation defect. Before another behavioral change, compare this terminal evidence with the user's live observation and choose one bounded source boundary that can be tested with a compile-only check, one incremental Quartus build and a short hardware playback; do not resume the long regression suites unless a change materially requires them.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 543 COMMIT Unreleased 7cdfcec 2026-08-26T14:35:16-07:00

#### Coming From:

Unreleased 99fc1ea

#### Purpose:

Close timing for the raster-phase correction by changing only the reproducible Quartus placement seed from fourteen to fifteen.

#### Outcome:

Entry 542 proved that commit `99fc1ea` compiles cleanly and restores the established MiSTer raster-control contract, but its retained seed-fourteen fit missed global setup by 0.199 nanoseconds and was therefore not deployed. Commit `7cdfcec` changes only the reproducible Quartus seed assignment from fourteen to fifteen; framebuffer RTL, decoder behavior, clocks, constraints, diagnostics, menu, host software and MiSTer configuration are unchanged. Per the user's shortened-cycle direction, the focused cache-refill testbench elaborated successfully without running `vvp`, and no native, reconstruction or live-raster regression was run. The retained-state seed-fifteen incremental compilation reused synthesis and completed in 9 minutes 22 seconds with zero errors. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.213, 0.249, 3.598, 0.614 and 0.925 nanoseconds. The fit uses 31,407 ALMs, 49,499 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,278,588-byte RBF has SHA-256 `5895917446f140bc53130fcf4b93226fa507cd9c6b9f335c00660c7428711365` and is eligible for hardware validation.

#### Next Steps:

Copy the exact seed-fifteen RBF from the designated GUNSMOKE checkout to the Raspberry Pi, directly replace only `/media/fat/MediaPlayer.rbf` through ordinary FTP without creating a backup, rollback or staging file, and independently read back the active image to verify its size and SHA-256. Reload the core and stop at the idle screen. Hardware acceptance begins with stable scaler lock and one genuinely fresh screenshot before any media playback; if idle lock fails, immediately restore the retained exact `164c7e6` image.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 542 COMMIT Unreleased 99fc1ea 2026-08-26T14:15:33-07:00

#### Coming From:

Unreleased 00267dc

#### Purpose:

Restore MiSTer's established external raster-control phase after entry 541 proved the one-clock delay breaks scaler lock.

#### Outcome:

The user approved an accelerated corrective cycle after the exact `00267dc` hardware image made the complete idle screen repeatedly lose synchronization and prevented a fresh scaled screenshot, while direct restoration of `164c7e6` immediately returned the display to its prior stable-lock baseline. Commit `99fc1ea` removes only `pixel_en_d`, `h_sync_d` and `v_sync_d`, again drives framebuffer `video_de`, `video_hs` and `video_vs` from the established current-cycle inputs and updates the focused cache-refill test to compile against that external passthrough contract. Per the user's shortened-cycle direction, the focused testbench was elaborated successfully without running `vvp`; the long native, reconstruction and live-raster regressions were not run. One retained-state incremental Quartus compilation completed successfully in 11 minutes 13 seconds with zero errors, but TimeQuest reported global setup slack of negative 0.199 nanoseconds; hold, recovery, removal and minimum-pulse-width slack were positive 0.257, 4.275, 0.595 and 0.925 nanoseconds. The fit used 31,377 ALMs, 49,635 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The non-deployable 4,271,344-byte RBF has SHA-256 `f53a3251b4676d2176b0838b4def338800ca96dfcffe92e9f6a1d6191bf41018`. Because setup timing did not close, the RBF was not copied from GUNSMOKE or installed on MiSTer; the verified `164c7e6` image remains active.

#### Next Steps:

Stop without deploying or starting another build. If the user approves one additional incremental placement seed, change only the reproducible Quartus seed, build once on GUNSMOKE and deploy only if every reported timing class is non-negative. Hardware validation must then begin and stop at idle-screen scaler lock plus one genuinely fresh screenshot; do not play media until that gate passes.

#### Files Modified:

- rtl/mpeg2_luma_framebuffer.sv
- tools/streams/tb_native_480i_cache_refill.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 541 COMMIT Unreleased 00267dc 2026-08-26T14:11:30-07:00

#### Coming From:

Unreleased 00267dc

#### Purpose:

Record the seed-fourteen native RGB-control hardware failure and restore the last known-stable core before another source change.

#### Outcome:

The user reloaded the exact 4,248,132-byte `00267dc` image at SHA-256 `c061bf77cd2117d35d34c75d8aaee9374eb4552fee6b5f915ba351d95376ea7e` and reports that it is dramatically worse before any media is opened: the entire screen is unstable and the image appears to be repeatedly trying to exist. The MiSTer reports `Scaled not available` when asked to capture that live raster, so the unchanged `cadence_probe.png` subsequently retrieved by FTP is stale and is excluded from evidence. This behavior begins with the core's idle output and therefore precedes MPEG decoding, DDR access, Bob/Weave reconstruction and source cadence. Static comparison identifies the introduced hardware boundary: `c21912a` added `pixel_en_d`, `h_sync_d` and `v_sync_d` and drove `video_de`, `video_hs` and `video_vs` from those one-clock-delayed registers to satisfy an internal RGB-alignment assertion. Real hardware proves that contract wrong because MiSTer's downstream scaler requires the established undelayed external timing phase; no PLL or clock frequency was changed. The active `/media/fat/MediaPlayer.rbf` was directly restored from the retained exact `164c7e6` image, independently read back at 4,225,296 bytes and SHA-256 `b5ce400b43311a74b0607137bce4498685490b74e5d08587538a68e7cdce8d96`, and no backup, rollback or staging filename was created. After reloading, the user confirms the display returned to its prior stable-lock but still visually bad and flickery baseline. Entry 540 remains built but fails hardware acceptance and its RBF is withdrawn.

#### Next Steps:

Stop before another build and obtain approval for one corrective cycle with no new diagnostic schema. Strengthen the native framebuffer regression to assert the established top-level output contract separately from internal RGB sample validity, then revert only the one-clock `video_de`, `video_hs` and `video_vs` delay proven to break hardware while retaining or rejecting the first-origin publication qualifier strictly by directed simulation evidence. Rerun the focused native tests, complete native suite, reconstruction suite and canonical live-raster soak, then perform one incremental Quartus build. Hardware validation must begin with idle-screen scaler lock and a successful fresh screenshot before any media playback; only after that passes should Big Buck Bunny be retried.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 540 COMMIT Unreleased 00267dc 2026-08-26T12:43:39-07:00

#### Coming From:

Unreleased 1439bf3

#### Purpose:

Prove that generation-correct native cache content remains position-correct through chroma selection, BT.601 conversion and registered RGB output before changing RTL.

#### Outcome:

The untouched framebuffer reproduced one exact post-cache defect before any behavioral change: position- and generation-varying Y, Cb and Cr samples reached the correct BT.601 components and RGB values, but data enable and both syncs led the registered RGB by one pixel, the first active pixel appeared before publication qualified it, and each generation emitted 345,599 rather than 345,600 active RGB pixels. Commits `771daa7`, `c21912a` and `d5485a7` add the independent component/RGB oracle, qualify the first origin pixel from the ready descriptor and register output controls alongside RGB, while scoping the new monitor away from the existing intentional overlap-fault control. Ordinary TFF, ordinary BFF and 512-cycle delayed service then each pass three generations with 240/240 field lines, exactly 345,600 active RGB pixels and 411,840 output samples per generation and zero component, RGB, control, publication, tag, content, cache or generation mismatch. The complete native suite passes field order, mapping, exact timing, Bob/Weave control, pattern isolation, ownership, ordinary/delayed/late-prefill refill, every fingerprint classifier and retained profiler layout. TFF, BFF and progressive reconstruction pass at 7,926,459, 7,948,706 and 13,048,137 cycles with zero out-of-tolerance pixels, field-DCT rejection remains 82,326 cycles and the canonical mixed-I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B-picture persistences, seventy-one swaps and every error clear. The first retained-state seed-twelve fit missed setup by 0.230 nanoseconds entirely inside MiSTer's unchanged `ascal` scaler and seed thirteen reduced that miss to 0.028 nanoseconds; commit `00267dc` makes seed fourteen reproducible and removes three stale exceptions for an older aggregate fingerprint path that the current single diagnostic layout no longer consumes and synthesis removes completely, while all 434 current provenance keepers remain present. The seed-fourteen incremental fitter completes in 8 minutes 20 seconds with zero errors. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.138, 0.240, 3.787, 0.594 and 0.925 nanoseconds; focused decoder setup and recovery are positive 1.659 and 10.811 nanoseconds and focused video setup is positive 2.596 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains. The fit uses 31,580 ALMs, 49,554 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,248,132-byte RBF has SHA-256 `c061bf77cd2117d35d34c75d8aaee9374eb4552fee6b5f915ba351d95376ea7e`.

#### Next Steps:

Copy the exact `00267dc` RBF from the designated GUNSMOKE checkout to the Raspberry Pi, directly replace only `/media/fat/MediaPlayer.rbf` through ordinary FTP without creating backup, rollback or staging files and verify the active image by independent readback. Reload the core and run `/media/fat/games/MediaPlayer/bbb_480i_tff_15s_8mbps.m2v` first with HDMI scaler deinterlacer Bob and then Weave, leaving Native timing pattern Off and Interlaced output Native 480i. Hardware acceptance requires smooth full-rate playback, normal menu response, audio, no retained old frame, no vertical or horizontal distortion and no left-edge crawl; report Bob and Weave separately before marking this entry passed.

#### Files Modified:

- tools/streams/tb_native_480i_cache_refill.sv
- rtl/mpeg2_luma_framebuffer.sv
- MediaPlayer.qsf
- MediaPlayer.sdc

#### Status:

- [x] Built
- [ ] Passed

---

## 539 COMMIT Unreleased 1439bf3 2026-08-26T05:50:53-07:00

#### Coming From:

Unreleased 018093a

#### Purpose:

Prove that framebuffer publication preserves one current authored generation across both native field caches before changing RTL.

#### Outcome:

Commits `19b417d` and `1439bf3` extend only the existing native cache-refill test and runner with authored framebuffer generations `2a`, `2b` and `2c`, generation-dependent position-varying DDR bytes and assertions from publication through every displayed luma cache line. The initial use of `+SLOW` correctly reproduced that mode's intentional cache-bank-overlap fault and could not serve as a clean full-frame discriminator, so `1439bf3` leaves that established fault case unchanged and adds a separate 512-cycle delayed-but-valid service case. On the untouched framebuffer RTL, ordinary TFF, ordinary BFF and delayed TFF each publish all three generations exactly once, complete 240 first-field and 240 second-field lines per generation and report zero generation, tag, content, cache, accepted-write-versus-read or byte-position mismatch. The complete native timing runner passes exact field timing, 4:2:0 mapping, Bob and Weave control, pattern isolation, scheduler ownership and monotonic generation order, ordinary service, intentional overlap, late prefill, clean and injected fingerprint classifications, all three new publication sequences, the luma writer fingerprint, the current hardware-profiler layout and retained decoder layouts. This clears scheduler-selected generation through framebuffer publication and both native luma field caches, so no framebuffer or scheduler RTL change, Quartus build, RBF deployment, hardware diagnostic layout, menu, decoder or host change was made.

#### Next Steps:

Do not modify the presentation scheduler or framebuffer publication logic and do not run Quartus from this result. The next bounded simulation should extend the same cache-refill regression across chroma-cache selection, BT.601 conversion and the registered framebuffer RGB output, using generation- and position-dependent Y, Cb and Cr content under ordinary TFF, ordinary BFF and valid delayed service. A reproduced output mismatch should authorize only the responsible chroma address, byte-lane or RGB-valid pipeline correction; exact equality moves the remaining investigation to the existing final mux and processed-HDMI boundary without adding another hardware telemetry schema.

#### Files Modified:

- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/run_native_480i_timing.sh

#### Status:

- [x] Built
- [x] Passed

---

## 538 COMMIT Unreleased 018093a 2026-08-26T05:36:53-07:00

#### Coming From:

Unreleased d566668

#### Purpose:

Make the existing native presentation regression prove monotonic picture-generation order and correct only a reproduced scheduler replay.

#### Outcome:

The user approved entry 537's bounded scheduler-generation cycle. Commit `018093a` changes only the existing native 480i presentation integration test, tagging every completed ordinary bank with its monotonically increasing decoded generation and requiring every observed display-bank change to present exactly the next generation. The untouched scheduler passes all four paths over twenty exact native frame windows: serialized decoding presents generations one through ten, measured three-field overlap presents one through thirteen, accelerated one-field pressure presents generations one through twenty while decoding twenty-one and exercises both the secondary queue and backpressure, and the finite terminal case decodes and presents all eight generations with the queue empty. The exact run completes at 682,495,674,081 picoseconds with `generation_order=1`, no untagged bank, repeat, regression, skip or presentation error. This rejects an old-generation replay inside the current abstract ordinary-reference scheduler model and does not justify changing scheduler RTL. No Quartus build, RBF deployment, hardware diagnostic layout, menu, decoder datapath, DDR storage, line cache or host software change was made.

#### Next Steps:

Do not modify the presentation scheduler or run Quartus from this result. The next bounded investigation should carry an authored generation identity through the existing framebuffer publication simulation boundary, from the scheduler-selected display bank and reset generation to `picture_present_rd` and the two field-cache publications, and assert that both fields of each published frame use the same current generation before pixels reach the existing cache output. Reuse the present diagnostic layout and tests; only a reproduced generation mismatch should authorize a framebuffer publication correction and incremental build.

#### Files Modified:

- tools/streams/tb_native_480i_presentation_integration.sv

#### Status:

- [x] Built
- [x] Passed

---

## 537 COMMIT Unreleased d566668 2026-08-26T05:29:56-07:00

#### Coming From:

Unreleased d566668

#### Purpose:

Accept the canonical MediaPlayer selector path and define the next bounded stale-generation investigation without adding hardware diagnostics.

#### Outcome:

After restarting into the independently verified 1,166,244-byte Main executable at SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`, the user confirms that MediaPlayer now opens at the required `/media/fat/games/MediaPlayer` path, so commit `d566668` passes its hardware objective. The separate Big Buck Bunny result remains failed with both old-frame ghosting and thin horizontal lines. Existing evidence now clears real-content four-picture reconstruction, accepted framebuffer write versus raw DDR return, raw return versus line-cache output after the registered-address correction, presentation count, cadence and all monitored error flags. Static review identifies one remaining regression blind spot before a behavioral scheduler change: `tb_native_480i_presentation_integration.sv` counts changes of the two-bit display bank and verifies aggregate decoded and presented counts, but it does not tag each bank with its authored picture generation or assert monotonic displayed generation. The current test can therefore pass while a scheduler ownership race replays an older generation through a different bank, which matches the unresolved symptom class without requiring another hardware diagnostic layout.

#### Next Steps:

Obtain approval for one bounded scheduler cycle. Extend only the existing native 480i presentation integration model with generation identities carried by its three ordinary banks and assert that every presentation advances to the next authored generation under the measured three-field decoder latency, the accelerated one-field case and terminal drain. Run that test first against the current scheduler. If it exposes a replay or ordering failure, correct only the responsible ordinary-reference ownership transition and rerun the focused scheduler, native timing, framebuffer, complete reconstruction and canonical live-raster regressions before an incremental Quartus build. If generation order already passes, stop without changing RTL and return to the framebuffer publication boundary using the current diagnostic layout rather than adding another schema.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 536 COMMIT Unreleased d566668 2026-08-26T05:21:07-07:00

#### Coming From:

Unreleased 1f80432

#### Purpose:

Force MediaPlayer's selector to open the canonical games directory after the generic resolver chose the legacy root-level directory.

#### Outcome:

The user reports that the exact entry 535 Big Buck Bunny Bob run still showed both old-frame ghosting and thin horizontal lines, so the visual defect remains failed despite clean accepted-write-versus-raw-DDR-read evidence; no additional FPGA diagnostic or behavioral change is included here. The separately installed Main directory change also failed its hardware objective. Read-only FTP inspection proves that both `/media/fat/MediaPlayer` and `/media/fat/games/MediaPlayer` exist, and static review shows `user_io_get_core_path(NULL, 1)` delegates to `findGamesDir`, whose compatibility search intentionally prefers the legacy root-level core directory before `games/MediaPlayer`. Commit `d566668` corrects only the pinned Main patch: MediaPlayer's selector invocation and its internal home boundary now both use canonical relative path `games/MediaPlayer`, which resolves to `/media/fat/games/MediaPlayer` in Main's storage namespace and prevents the generic legacy resolver or remembered `Selected_F` path from redirecting the initial view. The complete patch applies cleanly to pinned Main commit `0a8fb44`; other cores, the FPGA RBF and the ARM helper remain unchanged. Two clean builds with the checksum-verified official Arm GNU 10.2 toolchain are byte-identical, each producing a 1,166,244-byte ARM EABI5 executable at SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`. Only `/media/fat/MiSTer` was directly deleted and rewritten in one ordinary-FTP session with automatic local recovery available, and independent readback matches the exact size and hash. No MiSTer backup, rollback or staging filename was created, and no restart was triggered.

#### Next Steps:

Have the user restart the MiSTer, reload MediaPlayer and open its selector repeatedly, including after entering a subdirectory and selecting a file. Hardware acceptance requires every opening to begin at `/media/fat/games/MediaPlayer` even while the legacy `/media/fat/MediaPlayer` directory remains present. After that narrow correction is accepted, resume the visual investigation from scheduler display-bank and generation selection without adding a new diagnostic layout.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---
