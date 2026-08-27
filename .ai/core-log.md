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

## 608 COMMIT Unreleased d466bed 2026-08-27T06:39:56-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Measure the pipeline's compressed read-ahead and test whether it explains the single missed slot.

#### Outcome:

The read-ahead is fixed by two declarations and needed no simulation to measure. The dual-clock `mpeg2_stream_fifo` holds 16,384 sixteen-bit words, exactly 32,768 bytes, and the `mpeg2_h262_clean_video_queue` holds a 65,536-byte eight-bit `scfifo`, giving 98,304 bytes of compressed storage ahead of the decoder, or 2.4551 frame periods at the declared 40,040 bytes per frame period. That falsifies the entry 607 hypothesis, which predicted a depth between 3.118 and 3.754 frame periods; the real depth is below both, so trough depth and read-ahead alone cannot discriminate picture 690 from the twenty-five comparably thin points the hardware absorbed. Following the pre-registered branch, helper delivery timing was examined next. An initial attempt to locate the failure by program-stream file offset was wrong and is recorded here as a correction: the helper demuxes on the HPS and its submitted counter aggregates video, PCM and metadata, so it cannot be indexed by file offsets, and the first mapping pointed at 20.2 seconds instead of the true 23.09-second event. Repeating the measurement in wall time shows delivery is steady and rules out a transport stall. Both runs move 839,409,548 transport bytes at 1,407,367 and 1,407,386 bytes per second, with median inter-read gaps of 11.463 and 11.468 milliseconds, ninety-ninth percentile gaps of 20.986 and 20.966, and maxima of 41.289 and 41.309 milliseconds occurring at 404.57 seconds in both runs rather than near the failure. No gap in either run approaches the 81.92 milliseconds needed to drain the buffer at the declared rate, and the largest gap in the whole 22-to-24-second window is 23.511 milliseconds in Weave and 20.889 in Bob, ordinary against their own percentiles. Delivery is therefore consumption-paced and rate-matched, which is the missing term. Because the transport never runs a large lead, a picture bigger than the buffer must stream in while it is being decoded, and the slot is missed when that streaming time exceeds one frame period, giving a threshold of 138,344 bytes. Applied to all 17,876 pictures, exactly one picture in the film exceeds it: picture 690 at 150,316 bytes, predicting 9.977 milliseconds of starvation against 11.295 measured in Weave and 11.660 in Bob, and predicting exactly one missed slot per run, which is what both runs recorded. The model also explains the non-events, since picture 7602 at 136,350 bytes and picture 13253 at 124,846 bytes fall below the threshold despite 13253 sitting at a deeper VBV trough. This fit should be treated as strong but not settled, because the margin between the one predicted miss and the runner-up is only 1,994 bytes, about 1.4 percent, so a modest error in the assumed consumption rate or in the one-frame-period decode assumption would change the prediction to two misses or none. The relevant headroom for any fix is memory rather than logic: the accepted build uses 512 of 553 M10K blocks at 93 percent, with block memory bits at 71 percent and ALMs at 75 percent, so only 41 M10K blocks remain. This entry performs no build and no hardware run, and its Built and Passed marks refer to the unchanged, already-accepted `d466bed`. Evidence and the exact drivers are retained as `.ai/current_results/entry608_*`.

#### Next Steps:

Obtain user approval before any RTL change, since the defect is one repeated frame in a ten-minute film and the only credible fix consumes most of the remaining memory headroom. The proposal to approve or reject is to raise `mpeg2_stream_fifo` from 16,384 to 32,768 sixteen-bit words, taking the stream FIFO from 32,768 to 65,536 bytes and total read-ahead to 131,072 bytes, or 3.2741 frame periods, which lifts the miss threshold to 171,112 bytes and clears the film's largest picture by 20,796 bytes. The estimated cost is roughly 26 additional M10K blocks against 41 free, taking utilization from 93 percent toward 98 percent, so fit and timing closure are the real risks and a clean build with a warning comparison against `d466bed` must gate acceptance. Growing the clean video queue instead is worse, because doubling it needs about 103 blocks and does not fit, and a non-power-of-two depth is riskier than the dual-clock alternative. Before building, extend the existing overlap and queue tests to cover the deeper FIFO and add a bounded simulation driven by the actual picture 690 bytes at consumption pace, requiring the missed slot to disappear at the new depth and to persist at the old one. If fit or timing fails, the fallback is to accept the single repeated frame and record it as a known limitation rather than to trade away presentation or prediction memory. Keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 607 COMMIT Unreleased d466bed 2026-08-27T06:33:10-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Explain the deterministic missed display slot at picture 692 from the fixture itself, without new hardware runs.

#### Outcome:

Offline parsing of the delivered fixture reproduces its structure exactly, recovering all 17,876 pictures and all 715,713,077 video bytes across 360,872 packs, so the analysis operates on the same bytes the hardware accepted. The mux rate field is a single constant value of 25,200, equal to 10.08 Mbps, with zero SCR regressions, so there is no pack schedule discontinuity or transport anomaly anywhere near the failure point. The declared sequence header carries a 9,600,000 bit per second video rate and a 1,835,008-bit VBV, giving exactly 40,040 bytes of delivery per frame period; the encoder holds most pictures at precisely that size, so the stream is genuinely constant rate and only cuts produce spikes. Picture 690 is 150,316 bytes, the single largest coded picture in the entire film and 3.754 frame periods of delivery at the declared rate, immediately followed by picture 691 at 95,308 bytes, or 2.380 frame periods. Those two pictures alone carry 245,624 bytes where the constant rate supplies 80,080, and they sit at the scene cut around 23.05 seconds. A constant-arrival VBV trace over the whole film shows zero underflow, confirming the stream is legal, but occupancy falls from a steady 82.544 percent to 34.467 percent at picture 690 and 10.372 percent at picture 691, which is where the hardware missed its slot with 691 references completed. The simple explanation that the trough alone causes the miss does not survive the whole-film trace, and this entry records that correction rather than the partial result. The global minimum is picture 13255 at 10.368 percent, marginally deeper than picture 691, and twenty-six pictures fall below twenty percent occupancy across the film, including a cluster at 13253 through 13257. Hardware missed exactly one slot in both runs and nothing at 13256, so VBV depth by itself does not predict the failure and twenty-five comparably thin points were absorbed. The feature unique to the failure is peak single-picture delivery burden rather than trough depth: picture 690 needs 3.754 frame periods of constant-rate delivery against 3.118 for the 124,846-byte picture 13253, and no other picture in the film exceeds it. The working hypothesis is therefore that the pipeline's effective read-ahead covers roughly three frame periods of worst-case single-picture delivery and picture 690 alone exceeds it, which is consistent with the recorded eleven and a half milliseconds of input starvation, the writer still busy at the deadline and the absence of any presentation, ownership, timestamp or capacity fault in either capture. This remains an inference from stream structure and existing telemetry; the read-ahead depth has not been measured directly in RTL or simulation, and no production change is justified by this entry alone. Evidence and the exact probe and trace drivers are retained as `.ai/current_results/entry607_*`. The entry 605 and 606 commits were pushed to the online repository after the user granted push permission from the build PC, and no source, deployed file, setting or playback was touched by this analysis.

#### Next Steps:

Measure the pipeline's actual input read-ahead in frame periods, in simulation against the real bytes rather than by inspection, and compare it with the 3.754 frame period worst case that picture 690 imposes and the 3.118 frame period second worst at picture 13253. If the measured depth falls between those two figures the hypothesis is confirmed and the useful production boundary is to deepen upstream buffering toward the declared 1,835,008-bit VBV, sized in frame periods of worst-case delivery, leaving presentation queues, clocks, startup and throughput untouched. If the measured depth is well above 3.754 frame periods the hypothesis is wrong and helper delivery timing during the spike becomes the next suspect, in which case the existing helper profile records should be examined before any RTL work. Either way, define the acceptance criteria before editing RTL, prefer a bounded simulation using the actual 690 spike over another full-length physical run, and keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 606 COMMIT Unreleased d466bed 2026-08-27T06:28:14-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Close the remaining mode gap by replaying the full-movie fixture in Bob on the accepted candidate.

#### Outcome:

The user played the same film once in Bob as a warm replay with no core reload and no reboot, reporting picture and sound indistinguishable from the Weave run. The single syslog boot line remains 12:51:01 UTC, so this is a genuine same-boot comparison against entry 605 rather than a fresh-session repeat. The installed RBF still hashes to `d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a` for source `d466bed`, Main and the 739,065,873-byte fixture are unchanged, and a new helper PID 1339, a fresh helper log beginning at its own start line rather than extending the Weave capture, and packet checksum 1370572003 identify a distinct run. Bob matches Weave on every acceptance quantity: 17,876 reference pictures, 17,876 displayed pictures, 17,875 swaps, 715,713,077 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot and zero timestamp conflicts, with all 839,409,548 transport bytes submitted over 51,235 reads, 800 sampled ACK records and helper exit zero at 596.431673 seconds. Audio underrun and PCM protocol error are clear at FIFO peak 127, and the same saturated `pcm_sample_count` and `associated_count` fields again prevent any independent whole-film audio count. The important new result is that Bob reproduces the single missed display slot at exactly the same place as Weave: one 4,004,000-clock interval, 66.733333 milliseconds, at displayed picture 692 of 17,876, about 23.09 seconds in, with 691 completed references at both deadlines and accepted-byte positions of 27,778,070 in Bob against 27,772,349 in Weave, a difference of only 5,721 bytes. Both records show the writer busy without capacity blocking, no presentable candidate, the upstream FIFO pending and comparable input starvation of 699,593 clocks in Bob and 677,670 in Weave, with presentation hold, presentation error and both timestamp candidate signals false in each; the modes differ only in `decoder_ready`, false in Bob and true in Weave, and in candidate ready delay, 1,489,404 against 1,721,347 clocks. Two independent runs missing the same slot at the same bitstream position establish this as a deterministic, content-locked upstream delivery event rather than ambient jitter, and it remains outside the ownership and timestamp logic repaired this cycle. Deinterlacing mode has no measurable effect on delivery: helper would-block totals differ, 320 in Bob against 574 in Weave, as does first delivery at 23.465 against 42.017 milliseconds, but both are startup-phase effects and the reconstructed spans agree closely at 596.479325 and 596.476807 seconds against the 596.462533-second fixture, both after eight wraps of the 32-bit session timer, giving 29.967510 and 29.967636 true aggregate FPS. Reported cadence and FPS remain wrapping artifacts and must not be read directly. Picture and sound quality, synchronization and menu behavior are accepted from the user's report in both modes without independent measurement, and no pixel oracle was applied. This closes mode coverage for `d466bed` on this fixture; it does not qualify AC-3, interlaced P/B or field DCT, navigation, ISO or disk playback, or general commercial-DVD compatibility. Evidence and the exact capture and analysis drivers are retained as `.ai/current_results/entry606_*`, with the helper log stored losslessly under its original hash. Sixty-eight stale untracked result images from entries already outside the ring were deleted at the user's instruction, and the entry 605 commit remains unpushed because the environment refused the push operation. No production source, deployed file, setting, reboot, reload or playback occurred during collection; only the fixed screenshot was replaced.

#### Next Steps:

Both modes are now accepted for this fixture, so no further full-length replay is needed to compare them. The next boundary is to explain the picture 692 slot, which is cheap to attack offline because it is deterministic: measure the coded picture sizes and pack arrival schedule of the fixture in the neighbourhood of video byte 27.77 million and displayed picture 692, and determine whether an oversized picture, a rate spike or a pack-schedule discontinuity starves the decoder for the observed eleven and a half milliseconds. Only after that measurement should any production change be considered, and queue sizes, clocks, startup and throughput must not be tuned on the strength of one missed slot in 17,875. Because saturated audio counters cannot prove whole-film audio integrity, define acceptable audio evidence before any audio-focused cycle. Keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates with acceptance criteria agreed in advance, leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 605 COMMIT Unreleased d466bed 2026-08-27T06:12:39-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Validate the timestamp-aware native overlap fix against the full-movie 480i audio/video endurance fixture on hardware.

#### Outcome:

The user deployed the entry 604 candidate, reloaded from a clean reboot, selected Weave and played the full film once, reporting correct audio, video, sync and menu behavior throughout with no freeze. The helper log was retrieved first, then the fixed screenshot was deleted, regenerated and re-fetched, and installed artifacts were read back on a fresh connection. The installed 4,354,700-byte RBF is SHA256 `d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a`, matching published source `d466bed` exactly; Main remains `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`, identical to the entry 604 pre-deployment backup, and the fixture is still 739,065,873 bytes at `beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642`. The single syslog boot line at 12:51:01 UTC is consistent with the reported clean reboot. Schema-nineteen telemetry decodes with valid parity and checksum 1372493136 and reports 17,876 reference pictures, 17,876 displayed pictures and 17,875 swaps, exactly the entry 602 fixture count, with `error_flags` zero, `presentation_error` clear, sequence end seen, presentation complete, quiet snapshot reason and zero timestamp advance or delay conflicts. Accepted video is 715,713,077 bytes, byte-exact against the qualified demuxed payload. Helper PID 907 submitted all 839,409,548 expected transport bytes over 51,234 reads with 800 sampled ACK records, 837,544,742 fast and 1,864,806 acknowledged bytes reconciling to the total, EOF at 596.439564 seconds and exit code zero, so the entry 603 fatal drain signature does not recur. The entry 603 freeze at 81 displayed pictures and 2.740979 seconds is cleared. One deadline gap and one outlier are recorded: a single 4,004,000-clock interval, 66.733333 milliseconds, at displayed picture 692 of 17,876, roughly 3.9 percent into the film; the gap record's ordinal field is only eight bits and its value 180 aliases to that same picture. At that deadline the decoder was ready but no candidate was presentable, the writer was busy without capacity blocking, the upstream FIFO was pending and 677,670 clocks of input starvation had accumulated since the previous swap with a 1,721,347-clock candidate ready delay at 27,772,349 accepted bytes, while presentation hold, presentation error and both timestamp candidate signals were false. That identifies one source-delivery starvation slot, not the ownership or timestamp guard this cycle repaired, and it cost 33.366667 milliseconds across the whole film. The 32-bit 60 MHz session timer wrapped eight times, so the reported 23.814501-second cadence and 750.593107 aggregate FPS are wrapping artifacts; the reconstructed span is 35,788,608,404 clocks or 596.476807 seconds against the 596.462533-second fixture, giving 29.967636 true aggregate FPS versus the 29.970030 nominal rate, with a 856,404-clock residual over 17,875 intervals. Audio underrun and PCM protocol error are clear with PCM FIFO peak 127, but `pcm_sample_count` at 16,383 and `associated_count` at 255 are saturated fields and are not whole-film totals, so telemetry does not independently count audio frames. Sync, sound and menu response are accepted from the user's report without independent measurement, and no pixel oracle was applied to playback; the retained still is the telemetry packet itself, not a video frame. Of 574 total helper would-block events, only eleven are individually logged at power-of-two gates, all before first delivery at 42.017 milliseconds with nothing submitted, so a complete absence of steady would-block is not proven. This accepts `d466bed` for one Weave full-movie combined-rate soak from a clean reboot; it does not qualify Bob, warm replay, AC-3, interlaced P/B or field DCT, navigation, ISO or disk playback, or general commercial-DVD compatibility. Evidence and the exact capture and analysis drivers are retained as `.ai/current_results/entry605_*`, with the helper log stored losslessly compressed under its original hash. No production source, deployed file, setting, reboot, reload or playback occurred during collection; only the fixed screenshot was replaced.

#### Next Steps:

Retain `d466bed` as the accepted baseline and preserve the entry 604 restoration pair. No further identical Weave replay is needed to reconfirm this result. The next useful boundaries, in order, are a Bob full-movie run of the same fixture to close the mode gap, then an investigation of the single starvation slot at picture 692 to decide whether helper delivery or upstream buffering deserves a production change, using the existing telemetry rather than new instrumentation if possible. Do not tune throughput, clocks, startup or queue sizes on the strength of one missed slot in 17,875. Because saturated audio counters cannot prove whole-film audio integrity, define what would constitute acceptable audio evidence before any audio-focused cycle, and keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates with acceptance criteria set in advance. Leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 604 COMMIT Unreleased d466bed 2026-08-27T05:41:11-07:00

#### Coming From:

Unreleased 6669b70

#### Purpose:

Allow timestamped native all-I playback to use the bounded ordinary frame queue without false ownership aborts.

#### Outcome:

Published source d466bed removes the per-candidate timestamp-active restriction from native all-I overlap admission and secondary retention, while preserving the three-bank ownership and capacity guards, P/B and mode exclusions, cadence floor and timestamp-due gate. The existing native ownership test gains a second top with production timestamp association and timeline modules, connected through the existing runner. Before the user's scope change, its ten timestamp/ownership cases and the legacy ownership case pass; the old scheduler fails the new case and a mutant bypassing timestamp-due fails the future-PTS check as expected. The exact first 100 full-movie access units with helper timestamps complete all 100 pictures with zero errors or missed slots in the modeled video pipeline; this excludes physical PCM, HPS, scaler and CDC behavior. Nine completed focused/reconstruction regression jobs and the shared P/B raster test also pass. The user then explicitly skips A/V simulations and narrows this run to an RBF build and timing checks, retaining deployment responsibility. Remaining long A/V, pressure, two ceiling simulations and the unfinished native suite are stopped; none is claimed as a completed pass, and the original full qualification plan is not fulfilled. GUNSMOKE pulls exact published source d466bed into a clean build directory and completes Quartus 17.0.2 seed 16 in 730.0 seconds with 0 errors and 208 warnings. The normalized warning set has no additions versus accepted f615ce0 and there are no newly ignored timing filters. Worst reported setup is +0.083 ns, hold +0.240 ns, recovery +3.088 ns, removal +0.456 ns and minimum pulse width +0.925 ns, with every reported TNS zero. The 4,354,700-byte RBF has SHA256 d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a; its Pi copy at output_files/entry604/MediaPlayer.rbf is independently hash-verified. No candidate is uploaded to the MiSTer, activated or played by the agent. Earlier read-only backups of the installed f615ce0 RBF and retained Main are verified and persisted under /home/vash/mister-builds/entry604-backup; Main, media and settings remain untouched by this cycle. Bounded build reports, completed evidence, cancellation scope and reproducible drivers are retained as .ai/current_results/entry604_*, with raw logs compressed losslessly. Built is checked; hardware Passed remains unchecked.

#### Next Steps:

The user will deploy the supplied RBF and reload the MediaPlayer core, then replay the unchanged games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg with audio. Record the selected Bob/Weave mode and reload lifecycle explicitly, observe whether playback passes the former opening freeze and continues through the end with sound, sync and a responsive menu, and leave telemetry ready. On the next report, retrieve the helper log first and a fresh checksum-valid screenshot, verify the installed candidate hash and inspect presentation and audio errors, counts and deadline records. Hardware acceptance and long A/V simulation remain open; do not describe positive FPGA timing or the completed opening model as proof that the full movie or commercial DVDs play correctly. Use modular per-frame timing and full picture/transport counts because the 32-bit 60 MHz session timer wraps during the full film. Retain restoration artifacts, restricted core.md and the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv
- tools/streams/run_native_480i_timing.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 603 COMMIT Unreleased 6669b70 2026-08-27T05:37:49-07:00

#### Coming From:

Unreleased 6669b70

#### Purpose:

Diagnose the abrupt early native-480i audio/video freeze reported in both Bob and Weave.

#### Outcome:

The user reports that both modes stop near the beginning, with audible initial audio, good-looking video at the correct speed until an instant freeze and a responsive menu. Only the most recent run remains available; its mode is not specified and is not encoded in schema nineteen, so do not assign this capture to either mode or infer identical counters for both. The helper log is captured first, followed by a fresh checksum/parity-valid telemetry image and Main/RBF readbacks. The sole error flag is 0x0200, presentation_error, with 83 references decoded, 81 pictures displayed and 80 swaps. The fatal snapshot occurs at 164,458,727 decoder clocks, or 2.740979 seconds, with a 2.679818-second startup-inclusive presentation span, no deadline gaps or outliers and three largest steady intervals of 2,002,001 clocks. Decoder, reconstruction, writer, PCM protocol and audio-underrun error bits are clear at that snapshot. The 32-bit timer has not wrapped. Sequence end is absent and the session is not quiet; presentation_complete being high only describes the idle B-reorder transaction, not completion of this all-I movie. The retained image shows the opening cloud/trees scene. The source media still reads back as exactly 739,065,873 bytes with SHA256 beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642, and installed Main/f615ce0 RBF hashes are unchanged. A later helper log is an exact extension of the first capture and preserves PID 2210 through successful EOF after 213.060 seconds. All 51,234 reads, 800 sampled ACK records and 839,409,548 expected helper transport bytes reconcile without transport fault. This is the documented fail-open drain after a fatal scheduler error, not evidence that the remaining movie played; the snapshot accepted-byte count remains latched at 3,265,982. The same Linux boot as the prior captures is retained, without independently asserting absence of a core reload between the user's two mode tests. Inspection identifies an inconsistent native ordinary-queue policy: overlap admission uses timestamp_candidate_active as if it were a session-mode indicator, but that signal is false before a pending reference is released even in an anchored A/V session. The next I header both admits overlap and releases the old candidate, activating its timestamp; if the next frame completes before the old candidate presents, a legitimate third-bank secondary is retained and the timestamp/secondary guard then raises the fatal presentation error. Unmodified production timestamp ownership, timeline and scheduler modules reproduce that transition with all three bank identities distinct; raw and serialized controls avoid it. An integrated real I-decoder, reconstruction, writer, publication and timestamp/scheduler observer then uses the exact first 100 movie access units and helper timestamps, appending only a terminal sequence end. It reproduces the same guard at 80 decoded and 78 displayed pictures, with every other pipeline error clear. That is three pictures earlier than hardware, not an exact physical-cycle replay: source delivery, DDR readiness, 90 kHz ticks and swap phase are modeled and PCM/HPS/scaler/CDC timing is excluded. The same 100-picture video with timestamps removed completes all 6,480,000 DDR words and 810,000 blocks, preserves every display identity and has zero missed slots. Disabling overlap in the timestamped control also completes correctly, but produces six 4,004,000-clock intervals at displayed ordinals 49, 53, 54, 58, 59 and 63, adding 0.2002 seconds. It is therefore an inadequate smooth-playback fix. Every first-100 timestamp is present; the first omitted explicit timestamp in full-file qualification is zero-based picture 681 and cannot explain this early freeze. The full A/V hardware test fails while the previously accepted bounded video-only ceiling result remains valid. Exact logs are stored losslessly compressed with original hashes, alongside screenshots, analyses and reproduction drivers as .ai/current_results/entry603_*; the complete diagnostic workspace is /home/vash/mister-builds/entry603. No production source, media, installed file, mode, reboot, reload or playback is changed during investigation; only the fixed screenshot is replaced. Built reflects the unchanged baseline and compiled diagnostic models, and hardware Passed remains unchecked.

#### Next Steps:

The next useful production boundary is to make the bounded native all-I ordinary frame queue timestamp-aware while preserving its three-bank ownership, P/B exclusions, cadence floor and timestamp due gate. Do not merely suppress presentation_error, drop timestamp records, disable timestamps/audio or serialize native A/V, since the controls show either lost protection or renewed missed slots. Before editing RTL, record the precise fix and regression plan, then extend existing ownership/presentation tests with real timestamp association and timeline transitions, pending/secondary publication races, early and late timestamps, missing records, reset/new-file behavior and ordered terminal drain. Require the actual opening prefix and a longer combined stream to complete without errors or extra slots, retain the exact video-only ceiling and supported P/B regressions, then obtain a clean timing-qualified RBF and verify backups and staged deployment before the user's next run. Keep the current installation and full-movie fixture available as the reproducible failing baseline. No further identical Bob/Weave replay is needed to identify this fault; mode-specific hardware acceptance and the full physical A/V soak remain open. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 602 COMMIT Unreleased 6669b70 2026-08-27T05:10:55-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Prepare a reproducible full-movie native-480i audio/video endurance fixture near the DVD combined-rate target.

#### Outcome:

Published fixture source 6669b70 adds the deterministic full-source native-480i/MP2 generator, parameterizes the existing CBR checker without changing its 9.8 Mbps default, bounds the signalling-patch extension read and extends the existing tests. GUNSMOKE pulls that exact source and passes all eleven focused tests, a clean native build of the unchanged helper and a regression of the exact accepted 449-picture 9.8 Mbps fixture, including rejection of a wrong bitrate header. A first candidate remux produced timestamp warnings; the final generator instead encodes the Program Stream directly, then changes only equal-length video payload signalling while preserving its PES headers, timestamps, audio and packet schedule. A four-second candidate passes before full generation. The complete 596.458333-second source AVI, SHA256 4fc75fa403994e7c313da139d93a5aebdbda27cc951616aa4e480db6877c9850, produces 17,876 supported 720x480 TFF all-I frame-DCT pictures at 30000/1001 covering 596.462533 seconds, with the original soundtrack transcoded to 192 kbps 48 kHz stereo MP2. The output bbb_full_480i_tff_av_10080kbps.mpg is 739,065,873 bytes, SHA256 beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642. All decoded YUV planes are equal before and after the signalling patch; the program demuxes to the exact 715,713,077-byte qualified video and unchanged MP2 payload. The 9.6 Mbps video averages 9,599,437.175 bit/s, with zero underflow/overflow in the existing narrow constant-arrival VBV witness and maximum occupancy 1,834,917.333 of 1,835,008 bits. Every one of 360,872 pack headers signals the 10.08 Mbps mux target, adjacent SCR-paced arrivals satisfy the declared rate check and the whole pack span averages 9,906,567.467 bit/s. Picture-consumption windows may exceed the arrival rate using VBV buffering; this is not a full T-STD or DVD application-conformance certificate. The generic v0.7 compatibility checker has an obsolete native-interlaced rejection and is not claimed as a passing gate. Full helper scheduling preserves exact video/PTS and PCM hashes across explicit and in-band modes, emits 839,409,548 transport bytes and all 28,628,352 stereo PCM frames, has initial/steady batches of 5,504/2,048 frames, a 4,048-byte maximum steady PCM-free video gap, zero measured audio deficit and one PCM end marker. An initial diagnostic incorrectly required one PTS record per picture; the corrected exact byte-position mapping proves all 17,776 emitted timestamps refer to the proper picture, all intervals are 3,003 or 6,006 ticks and only 100 individual pictures lack a separate timestamp. No picture bytes are lost, and first/last mappings cover the full movie. Comparing all 57,256,704 signed sample values against an independent FFmpeg decode yields maximum difference two, RMS 0.503652 and correlation 0.999999979, with exact sample-count agreement and 596.424 seconds of audio. The new media is deployed through a unique stage and full independent readback hashes before and after rename; the installed Main and f615ce0 RBF match their prior hashes before and after transfer. No source RTL, production helper/Main/RBF, settings, reboot, reload or playback is changed. Reproducible media stays off Git; manifests, checks and exact diagnostic/deployment drivers are retained as .ai/current_results/entry602_*, with full media under /home/vash/mister-builds/entry602. Built reflects software generation and helper compilation, not a new FPGA build. Hardware Passed remains unchecked.

#### Next Steps:

Have the user select Bob and play games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg once in its entirety without rebooting or reloading, checking audible sound, A/V sync through the end, visible slowdown or corruption and menu response during and after playback, then leave the terminal telemetry ready. Retrieve the helper log first and acquire a fresh parity/checksum-valid screenshot. Require all 17,876 reference/display pictures, expected swaps and exact transport completion, inspect native deadline gaps and audio error/underflow state, and distinguish final audio-tail behavior from steady faults. The 32-bit 60 MHz session timer wraps every 71.582788 seconds, so do not use terminal aggregate FPS or elapsed time without wrap accounting; full picture counters, modular per-frame gaps, helper completion and user observations remain the useful evidence. Audio frame telemetry is also not an unsaturated whole-film sample total. Record the chosen mode and lifecycle explicitly. This single combined high-rate physical soak does not qualify the other mode, AC-3, interlaced P/B or field DCT, navigation, ISO/disk playback or full commercial-DVD compatibility. Preserve accepted f615ce0 and its restoration artifacts, restricted core.md and the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_av_soak.py
- tools/streams/generate_test_dvd_ceiling.py
- tools/streams/generate_test_interlaced_i_frames.py
- tools/streams/test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 601 COMMIT Unreleased f615ce0 2026-08-27T05:04:37-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Confirm the DVD-ceiling cadence result in Bob and resolve the preceding run's Weave attribution.

#### Outcome:

The user explicitly confirms that the new run is Bob and entry 600 was Weave, resolving that entry's mode uncertainty without rewriting its historical record. The Bob helper log is retrieved first, followed by a newly generated parity/checksum-valid schema-nineteen screenshot and full Main/RBF/media readbacks. The installed f615ce0 RBF, retained Main and exact 18,402,691-byte ceiling fixture match entry 600 byte-for-byte. New helper PID 1568, helper hash a34a6fdc1f960654ced490c2e2392f956d8131b83fc1a576a1656410446c3a54 and telemetry checksum 4215072064 identify a distinct run, while the same 11:26:59 UTC Linux boot establishes no system reboot between the captures. The packet does not encode the mode or running bitstream hash, and no independent absence-of-core-reload proof is claimed. All 1,124 chunks and seventeen sampled ACK records reconcile; all 18,402,691 source bytes arrive with the expected single padded byte giving 18,402,692 FPGA-accepted bytes, no transport fault and helper exit zero. Both confirmed modes complete 449 reference/display pictures and 448 swaps with zero error flags, zero deadline gaps, zero outliers, no deadline records and normal EOF/quiet completion. Each mode's three largest steady intervals are exactly 2,002,000 clocks, or 33.366667 milliseconds. The old a4f2769 extra intervals at 167 and 346 remain absent in both new runs. Bob's startup-inclusive span is 14.996120 seconds at 29.874393 aggregate fps versus Weave's 14.991394 seconds at 29.883811; the 4.726100-millisecond difference lies in initial admission and does not indicate recurring Bob lateness. Bob's presentation hold is 5,529,868 cycles versus 5,246,150, and writer wait is 15,288,984 versus 15,282,414. All 165 Bob EAGAIN events precede first delivery, with no steady EAGAIN. Credit-fast transport carries 18,373,724 fast bytes and 28,967 acknowledged bytes in 902,794 bursts and 918,402 queries, with all guarded accounting intact; these consumption-paced statistics are not a maximum bus-bandwidth measurement. The fresh still shows the expected final foliage/spikes scene without an obvious large artifact; full-playback visual or pixel correctness is not inferred from it. The earlier Weave menu report remains valid, while this message does not separately report Bob menu behavior or playback appearance. The capacity-safe writer-retirement fix is accepted for this bounded two-mode 9.8 Mbps video-ceiling fixture and same-boot replay. Passed does not imply a long physical soak, combined audio/video qualification or complete DVD compatibility. Evidence and exact collection/analysis drivers are retained as .ai/current_results/entry601_*. No production source, deployed files, settings, reboot, core reload or playback is changed during collection; only the fixed screenshot is replaced.

#### Next Steps:

Retain f615ce0 as the accepted baseline for the measured ceiling-cadence fix and preserve the independently verified a4f2769 restoration artifacts. No further identical short replay is required merely to reconfirm the cleared 167/346 misses. The next useful qualification boundary is longer physical playback and the separate 10.08 Mbps combined-stream/audio/PTS and remaining DVD syntax/features, with scope and acceptance criteria defined before new production work. Keep mode-specific UI and visual claims limited to user reports, leave lifecycle/playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 600 COMMIT Unreleased f615ce0 2026-08-27T05:00:35-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Validate the first hardware DVD-ceiling replay after the capacity-safe early writer acknowledgement change.

#### Outcome:

The user reports that the menu is okay and the screen is ready, then directs continuation. The helper log is retrieved first, followed by a newly generated screenshot with valid schema-nineteen parity/checksum and complete Main/RBF/media readbacks. The installed 4,324,340-byte RBF matches qualified f615ce0 SHA256 44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01; Main remains 3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f, and the exact 18,402,691-byte ceiling fixture remains 3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065. All 1,124 chunks and seventeen sampled ACK records reconcile without transport fault or uninitialized ACK state. The one-byte FPGA difference is the expected zero-padded final transport word, giving 18,402,692 accepted bytes. All 449 reference/display pictures and 448 swaps complete with zero error flags, normal EOF, presentation completion and quiet terminal state. Both deadline-gap and gap-outlier counters are zero, with no deadline records; all three largest measured steady intervals are the nominal 2,002,000 clocks, or 33.366667 milliseconds. The previous extra intervals at pictures 167 and 346 are absent in this run, compared with two 66.733333-millisecond intervals in each confirmed a4f2769 Weave and Bob capture. Startup-inclusive aggregate FPS is 29.883811 across 14.991394 seconds; its 43.127700-millisecond excess over 448 nominal intervals belongs to initial admission, not a steady missed slot. All 606 EAGAIN events precede first delivery, with no steady EAGAIN. The transport uses 18,373,802 fast bytes and 28,889 acknowledged bytes, 892,181 bursts and 907,750 status queries; consumption-paced statistics are not a raw link-bandwidth measurement. A new helper PID 1406, helper hash and packet checksum identify a distinct capture. The Linux boot is 11:26:59 UTC rather than the earlier 10:08:35 UTC baseline boot, so this is not a controlled same-boot comparison. Weave was requested immediately before the run, but the user response does not explicitly name the mode and this packet does not encode Bob/Weave selection. Installed-file readback also does not independently identify the currently loaded bitstream; the new capture follows the user-directed reload/playback request. Menu response is accepted as reported, without assigning a measured latency or independently separating during-versus-after behavior. The still image shows the expected final foliage/spikes scene without an obvious large artifact, not an independent full-playback pixel oracle. This clears the scoped single-run 9.8 Mbps video-ceiling cadence gate for f615ce0; Passed refers only to that observed hardware run, not both modes, warm-repeat qualification or full DVD compatibility. Evidence and exact collection/analysis drivers are retained as .ai/current_results/entry600_*. No production, deployment, configuration, reboot, core reload or playback action is performed during collection; only the fixed screenshot is replaced.

#### Next Steps:

Have the user replay the same ceiling file in explicitly confirmed Bob mode without rebooting or reloading, check menu response during and after playback, and retain the terminal image for a warm-run comparison. Preserve f615ce0 and the verified a4f2769 restoration pair, and do not change throughput, clocks, startup, queue sizes or source media on the strength of a single passing run. Keep mode confirmation, longer physical playback and the separate 10.08 Mbps combined-stream/audio/PTS and remaining DVD feature gates open. Leave lifecycle and playback with the user, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 599 COMMIT Unreleased f615ce0 2026-08-27T04:53:39-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Remove the normal two-clock writer acknowledgement delay while preserving capture-bank capacity protection.

#### Outcome:

The approved source f615ce0 emits a completion-qualified grant on the capture-completion edge only when the alternate bank is free; a single pending request waits for real capacity when both banks are occupied. It preserves block_stored, all capture/drain data and addresses, reset/error handling and capacity telemetry, and corrects the stale top-level level-versus-pulse comment. The expanded writer contract passes 2,016 complete DDR words and 252 retired blocks across immediate/delayed grants, prolonged and random stalls, all byte lanes and supported frame/scratch encodings, reset and malformed input. It rejects both the old delayed implementation and an unsafe unconditional-grant control. GUNSMOKE pulled the Pi-published exact source before official qualification. Native startup, field order, presentation, cache/fingerprint/generation and telemetry regressions pass, as do supported reconstruction, scheduler, prediction fetch/cache and an authored 720x480 I/P/B shared-writer persistence test. Two auxiliary legacy tests fail identically on the prior source: scratch-tag assertions bind removed internal names, and the B error-sideband test expects an obsolete result; these are retained as existing test-maintenance limitations, not claimed passes. A separate writer-connected FFmpeg oracle verifies 12 TFF/BFF/progressive pictures and all 6,220,800 accepted DDR bytes within the established one-level IDCT tolerance with DDR busy for 600 of every 997 clocks. Its initial inherited ready-memory throughput assertion fails under this deliberate saturation; the temporary observer separates saturation correctness from realtime qualification, while the unmodified reconstruction and separate cadence gates remain enforced. Actual new-writer cadence tests complete 2,694 ordered pictures across both saved 449-picture ceiling phases, a ceiling run with 500 busy clocks per 1,000,003, an 898-picture repeated ceiling run under that pressure, and the qualified 449-picture 8 Mbps fixture. Every post-admission display interval is exactly 2,002,000 clocks, with zero missed windows, all expected DDR words/blocks and no asserted errors. Normal coefficient-end-to-ack latency is 200 clocks instead of 202, saving 16,200 clocks or 0.27 ms per picture; all first-449 cost residuals match isolated decode cost plus measured holds and grant delays, apart from the documented one-clock initial-shell offset. These calibrated-phase simulations exclude physical HPS transport, real DDR/read contention, scaler and startup CDC and are not hardware acceptance or full-disc qualification. The clean seed-16 Quartus build completes with zero errors and 208 warnings, the same normalized warning set as installed a4f2769, and no new ignored timing filters. Worst setup/hold/recovery/removal/minimum-pulse margins are 0.243/0.109/2.944/0.605/0.925 ns, all TNS zero. After fresh backups of the current a4f2769 Main/RBF pair and independent persistent verification under /home/vash/mister-builds/entry599-backup, only MediaPlayer.rbf is deployed using staged transfer and full fresh-connection readbacks; its 4,324,340-byte SHA256 is 44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01. Main remains 3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f. No reboot, core reload, playback or configuration action is performed. Evidence and exact temporary drivers are retained as .ai/current_results/entry599_*, with full builds under /home/vash/mister-builds/entry599. Hardware Passed remains unchecked.

#### Next Steps:

Have the user reload MediaPlayer to activate f615ce0, replay the unchanged bbb_480i_tff_15s_9800kbps.m2v in a known mode, check the menu during and after playback and retain the terminal telemetry screen. Retrieve the helper log before any later playback overwrites it, acquire a fresh screenshot with parity/checksum validation, and require all picture identities, transport integrity, zero errors and zero missed display slots before accepting this candidate. Compare both hardware modes and warm replay afterward while preserving restoration copies. Keep the separate 10.08 Mbps combined audio/video, broader DVD syntax/features and longer physical soak gates open. Leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- MediaPlayer_top_02.svh
- tools/streams/tb_h262_ddram_store_overlap.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 598 COMMIT Unreleased feb50c2 2026-08-27T04:21:04-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Isolate processing, writer handoff and presentation-release costs behind the DVD-ceiling cadence misses.

#### Outcome:

The user authorizes investigation, with production and MiSTer lifecycle unchanged. GUNSMOKE pulled the published 39f0875 checkout and compiled a temporary observer containing the current production frontend, full publication shell, I parser/IQ/IDCT/reconstruction, two-bank writer and presentation scheduler. The exact 449-picture ceiling fixture is supplied without input starvation, and DDR writes are always ready; actual HPS transport, queues, arbiter/read contention, scaler and startup/video clock crossings are excluded. Raster phase and first permitted swap are derived from the two hardware captures, so startup is calibrated rather than independently reproduced. Both baseline phases complete all 449 picture identities, 448 swaps, 29,095,200 DDR words and 3,636,900 blocks without asserted errors, but retain late intervals: Weave-phase ordinals [181, 348] and Bob-phase ordinals [181, 348]. These ideal-memory positions are not the physical 167/346 positions and must not be represented as an exact hardware replay. Every baseline picture has exactly 203 parser wait clocks per block, versus 201 in entry 597. From coefficient-end to reconstruction is 200 clocks, while actual writer acknowledgement takes 202. Subtracting measured presentation holds reproduces every isolated per-picture cost plus exactly 16,200 writer clocks, with only the expected one-clock first-publication-shell offset. The normal handoff therefore adds 0.270000 milliseconds per picture even when memory never blocks. Next-header release is 37 clocks at the observed target publication boundaries. Adding isolated interval cost, the fixed writer overhead, that release delay and the saved hardware capacity-block count exactly reconstructs both Weave reference-to-ready intervals and Bob picture 167; Bob picture 346 differs by only 26 clocks, or 0.433 microseconds. The hardware capacity counter and reference interval have slightly different starting boundaries, so this close accounting is supporting evidence rather than a full physical stall trace. Across this fixture, processing with the fixed writer handoff averages 33.529155 milliseconds per picture against the 33.366667-millisecond budget, approximately 29.824790 fps of processing capacity, and exceeds 449 nominal budgets by 72.957150 milliseconds before real-memory delays. Buffering alone cannot hide a sustained deficit indefinitely. An ideal-memory testbench control releases the parser directly on reconstruction completion while leaving the actual writer running; it displays all 449 identities with the same word/block totals and late intervals []. This control is not a deployable fix because it bypasses capacity when both writer banks are occupied, and no new pixel-value oracle was run. The existing unchanged writer-overlap regression separately passes sixteen writes and two grants while enforcing full-bank backpressure. Evidence and exact observer/commands are retained as .ai/current_results/entry598_*, with full builds under /home/vash/mister-builds/entry598. No production source, deployed binary, clock, cadence, queue, startup setting or MiSTer action changed; Built refers to diagnostic compilation and strict hardware acceptance remains open.

#### Next Steps:

Use a bounded capacity-safe writer-grant retiming as the first production candidate: remove both normal handoff clocks only when the alternate capture bank is actually free, retain exactly one delayed grant when full, and preserve block_stored, DDR address/payload/order, bank ownership, reset and error behavior. Do not deploy the direct-reconstruction diagnostic bypass or weaken the next-header release barrier, and do not change clock, cadence, startup, transport guards or queue sizes. Extend the existing writer-overlap regression for immediate versus delayed grants, duplicate/premature-grant rejection, sustained and random backpressure, reset and complete word/lane equivalence; then run the supported reconstruction, writer/presentation integration and P/B-client regressions before official Quartus timing/build qualification. Recheck the exact ceiling clip in both user-controlled modes and a longer run to establish sustained margin, keeping the warm 8 Mbps regression and restoration pair. The separate 10.08 Mbps combined audio/video gate and remaining DVD features remain outside this result. Preserve user lifecycle/playback control, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 597 COMMIT Unreleased feb50c2 2026-08-27T04:02:24-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Identify the content and decoder workload associated with the repeatable missed pictures 167 and 346.

#### Outcome:

The profiler's full-width ordinals are one-based, corroborated by completed-reference counts 166 and 345 at the two deadlines, so the exact file indices are 166 and 345 at 5.538867 and 11.511500 seconds. All 449 pictures have the same I-picture coding extension, thirty slices, 1,350 macroblocks and 8,100 blocks; neither target is a special picture type or header-mode transition. Picture 167 shows dense foliage immediately before a cut to a mostly sky view and occupies 43,716 bytes, only 104th-largest; picture 346 shows the flying squirrel approaching the camera and occupies 46,222 bytes, 52nd-largest. The median is 40,186 bytes and maximum 143,171. GUNSMOKE used the unchanged 04ca33b checkout, production-equivalent to a4f2769, to compile a temporary observer around the current production frontend, parser, inverse quantizer, IDCT and intra reconstruction. All 449 pictures complete with 518,400 samples and 8,100 blocks each and no asserted reconstruction errors. This diagnostic excludes host transport, DDR persistence, presentation and pixel-oracle comparison; it is an optimistic decoder-cost profile, not a physical replay or new pixel-conformance test. Isolated costs are 33.667517 and 34.043583 milliseconds, ranking 104 and 52 of 449, with 148 pictures exceeding the nominal 2,002,000-cycle individual budget. Both parser pipeline-wait time of 1,628,100 clocks and IDCT transform-active time of 1,036,800 clocks are identical for every picture; variable cost lies outside those fixed stage counts, including compressed-bit parsing, not unusually long transforms at these two pictures. The retained Weave records measure 33.944600 and 34.321650 milliseconds from preceding reference completion to candidate readiness, against the nominal 33.366667-millisecond period. Previous-reference head starts are only 0.133300 and 0.870233 milliseconds, leaving the observed 0.444633 and 0.084750 milliseconds of lateness; Bob gives the same relationship with slightly different margins. Accepted-byte positions are 79 and 15 bytes before the respective access-unit ends in Weave, and 69 and 14 in Bob; these positions do not measure remaining arithmetic work. The evidence supports insufficient available decode/retirement lead at these deadlines rather than uniquely large or exceptional pictures, while the exact scheduler/retirement contribution remains unisolated. The isolated model must not be claimed to reproduce the two hardware misses. Evidence, exact observer, commands, full cost table, analysis and two decoded views are retained as .ai/current_results/entry597_*, with the full temporary build and six views on GUNSMOKE under /home/vash/mister-builds/entry597. No production source, deployed file, configuration or MiSTer lifecycle/playback action changed. Built refers to the diagnostic compilation; the existing strict hardware cadence gate remains unpassed.

#### Next Steps:

Use these measurements to scope a bounded decode/retirement throughput revision or a targeted integrated diagnostic, preserving exact picture identity, startup and presentation phase rather than treating either image as malformed or merely masking its deadline miss. Account for sustained workload and available reference-buffer lead; a picture's individual byte size or transform coefficient count alone cannot predict whether its display deadline is missed. Keep the exact 9.8 Mbps fixture and installed a4f2769 pair, preserve transport integrity checks, queues, startup, continuous sync and restoration copies, and obtain approval if the resulting production plan materially changes the accepted scope. Require zero missed slots on the ceiling fixture before the separate combined 10.08 Mbps/audio-and-timing gate; full DVD compatibility remains broader. Leave lifecycle and playback with the user, keep restricted core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 596 COMMIT Unreleased feb50c2 2026-08-27T03:53:06-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Record the user's confirmation that the preceding DVD-ceiling run used Weave mode.

#### Outcome:

The user explicitly confirms that entry 594 was Weave, resolving the mode-attribution uncertainty recorded in entry 595. Entry 595 was Bob without rebooting, also explicitly reported by the user. The existing same-fixture, same-a4f2769-binary and same-Linux-boot captures can therefore be compared as user-confirmed Weave and Bob runs. Both display all 449 pictures with 448 swaps and zero decoder/transport errors, yet both retain the same two missed deadlines at full-width ordinals 167 and 346 and the same 66.733-millisecond maximum intervals. Bob's approximately 28.174-millisecond shorter aggregate span is startup-related, not removal of either steady-playback miss. Candidate readiness at the two deadlines changes from 0.444633 and 0.084750 milliseconds late in Weave to 0.390517 and 0.083600 milliseconds late in Bob. Both retain pending input, decoder not ready and zero input starvation at the missed slots. These observations strengthen the shared decode/retirement timing hypothesis and show that switching to Bob does not clear the fault; they do not prove every mode behavior identical or isolate a specific arithmetic stage. The confirmation is preserved in .ai/current_results/entry596_mode_confirmation.json and supersedes only the prior uncertainty about mode identity, leaving the settled captures and their numerical analysis unchanged. No new capture, source change, build, deployment or device action was performed. Strict DVD-ceiling cadence acceptance remains open.

#### Next Steps:

Use entry 594 as the confirmed Weave baseline and entry 595 as the confirmed warm Bob comparison. Focus the proposed GUNSMOKE decoder/reference-retirement investigation on the repeatable shared misses at pictures 167 and 346 rather than treating display-mode selection as a fix. Preserve the exact 9.8 Mbps fixture and installed a4f2769 pair, and require a bounded evidence-backed revision before further production changes. Keep the combined 10.08 Mbps audio/video gate separate, retain 18.65 Mbps only as optional stress evidence, preserve transport guards, queues, startup and sync, leave lifecycle/playback control with the user and maintain restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 595 COMMIT Unreleased feb50c2 2026-08-27T03:51:42-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Compare the user-reported warm Bob-mode DVD-ceiling run with the preceding hardware capture.

#### Outcome:

The user explicitly reports Bob mode and no reboot. The helper log was collected first, followed by a fresh checksum-valid schema-nineteen screenshot and complete media/Main/RBF readbacks. The qualified 9.8 Mbps fixture and installed a4f2769 hashes are unchanged; the same 10:08:35 UTC Linux boot corroborates no system reboot, while new helper PID 1730, log hash and telemetry checksum confirm a distinct run. Bob attribution comes from the user because the packet does not encode the selected deinterlace mode. Entry 594's mode was not explicitly confirmed, so this must not be described as a controlled Bob-versus-Weave comparison. Completion and steady timing are unchanged: all 18,402,691 source bytes, the expected padded FPGA count of 18,402,692, 449 reference/display pictures and 448 swaps, zero errors or transport integrity aborts, normal EOF and quiet completion. There are again exactly two deadline misses and two outliers at full-width picture ordinals 167 and 346, both with 66.733-millisecond intervals; other intervals remain nominal. The second ranked-gap ordinal is the expected wrapped value 90. Both missed deadlines again show input and upstream data waiting, decoder not ready, no input-starvation cycles and no presentation/destination hold. Candidate readiness improves slightly from 0.444633 to 0.390517 milliseconds late at 167 and from 0.084750 to 0.083600 milliseconds late at 346, but both still miss their slots. Writer-capacity blocked time is 236 and 525 cycles. The startup-inclusive aggregate rises from 29.704965 to 29.760561 fps because the aggregate span is 28.174 milliseconds shorter; presentation hold falls by 28.073 milliseconds, consistent with different startup hold/alignment rather than improved steady cadence. Both runs still add 66.733 milliseconds from the same two extra frame periods. The transport remains credit_fast_v1 mode 2, with all 1,124 chunk totals and seventeen ACK samples reconciled. Fast payload is 18,385,038 bytes, or 99.9041 percent, across 916,130 batches averaging 20.068 bytes and 926,081 queries. All 164 EAGAIN events are before first delivery. Consumption-paced delivery is 1,226,799 bytes per second versus 1,224,493 previously; mean data-bearing poll time is 53.234 versus 53.262 milliseconds, and maximum is 77.614 versus 79.040 milliseconds. These small transport variations do not establish a mode-dependent speedup or raw link capacity. No new menu-response report was provided; the preceding report established after-playback response only. Recurrence at the same two picture ordinals with the same ready/input signature strengthens the case for a repeatable content-linked downstream margin issue without identifying a particular arithmetic stage. Full capture and checked comparison are retained as .ai/current_results/entry595_*. No production source, binary, configuration, reboot, reload or playback changed during collection. Strict DVD-ceiling cadence acceptance remains open.

#### Next Steps:

Retain both ceiling captures and the exact feb50c2-generated clip, and prioritize a focused GUNSMOKE investigation of decode and reference-retirement timing at pictures 167 and 346 before proposing a production revision. Do not infer a Bob/Weave cause from the unconfirmed prior mode or treat the aggregate FPS increase as removal of steady lateness. Another identical hardware replay should have a specific new diagnostic question; the current two captures already establish repeatability at both ordinals. Keep the 9.8 Mbps video gate and later 10.08 Mbps combined-stream/audio-and-timing gate separate, retain 18.65 Mbps only as optional stress evidence, and preserve current production a4f2769 with its transport guards, queue sizes, startup/sync behavior and restoration copies. Keep user control of lifecycle and playback, restricted core.md unchanged and the forty-entry ring intact.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 594 COMMIT Unreleased feb50c2 2026-08-27T03:48:08-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Verify completion and presentation timing of the first DVD-ceiling video hardware run.

#### Outcome:

The user says playback looked perfect and the menu remains responsive after playback; this does not confirm menu response during playback. The helper log identifies bbb_480i_tff_15s_9800kbps.m2v, runtime credit_fast_v1 and transport mode 2. The log was retrieved before replacing the fixed screenshot and collecting a fresh checksum-valid schema-nineteen packet. Complete media and installed Main/RBF readbacks retain the qualified fixture and a4f2769 hashes, and the same 10:08:35 UTC Linux boot confirms no intervening system reboot since the prior warm run; core reload and display-mode selection are not independently encoded. All 18,402,691 source bytes, 449 reference/display pictures and 448 swaps complete with zero aggregate decoder errors, no transport integrity fault, normal helper exit, sequence end and quiet presentation completion. All 1,124 chunks and seventeen sampled ACK records reconcile with cumulative counters. The final 3,459-byte chunk consists of 3,458 fast bytes and one acknowledged tail byte; its wide-word zero padding explains the FPGA count of 18,402,692 accepted bytes, with no missing source byte. Fast blocks carry 18,385,220 bytes or 99.9051 percent; acknowledged payload accounts for 17,471 bytes in 8,736 words, including the single padded tail. There are 913,967 fast batches averaging 20.116 bytes and 923,827 status queries. Matched completed-chunk delivery is 1,224,493 bytes per second, consumption-paced rather than a raw capacity measurement. All 169 EAGAIN events precede first delivery. Data-bearing polls average 53.262 milliseconds and peak at 79.040 milliseconds; these are blocking exposure, not measured UI latency. Strict cadence does not pass: two actual post-startup deadline misses and two outliers correspond to 66.733-millisecond intervals, while the third-largest interval is nominal 33.366667 milliseconds. All pictures are displayed; two preceding pictures are held for an extra nominal period, totaling 66.733 milliseconds of added hold. Both missed deadlines are retained at full-width ordinals 167 and 346; the second largest-gap ordinal wraps to 90 and must not be mistaken for picture 90. At both deadlines input and upstream data are pending, decoder_ready is false, the candidate is not presentable, interval input-starvation is zero and neither presentation nor destination hold is asserted. The candidates become presentable 26,678 and 5,085 decoder cycles after the deadline, or 0.444633 and 0.084750 milliseconds. Writer-capacity blocked time is only 353 and 412 cycles, respectively, but the evidence does not isolate a particular arithmetic stage or exclude internal waits. These are downstream processing/retirement margin misses rather than observed empty-input delivery stalls. The raw 29.704965-fps aggregate spans 15.081654 seconds and includes startup; after subtracting the two known extra intervals, its remaining excess over nominal is 66.654 milliseconds of startup-inclusive timing, not further steady slowdown. Evidence is retained as .ai/current_results/entry594_*; no source, deployment, configuration, reboot, reload or playback changed during collection. This run is complete and visually accepted by the user but does not meet the agreed zero-deadline-miss ceiling gate, so Passed remains unchecked.

#### Next Steps:

Keep the exact feb50c2-generated 9.8 Mbps fixture and installed a4f2769 pair as the baseline. Propose a focused investigation of decoder and reference-retirement timing around the two retained misses, using the exact stream and existing GUNSMOKE simulation harnesses to distinguish decode work, internal waits and final publication latency before a production revision. Preserve full-rate cadence rather than masking missed deadlines in telemetry. Do not raise the test bitrate or return to making the optional 18.65 Mbps stress file an acceptance requirement. Clear these two in-scope late intervals, then validate the separate 10.08 Mbps combined-stream gate with supported audio and timing; current video completion does not pass that integration boundary or the remaining DVD feature set. If another hardware run is needed, give it a specific diagnostic purpose and preserve its helper log before replay. Keep after-playback and during-playback menu reports distinct. Preserve credits and integrity checks, both queue capacities, guarded startup, continuous HDMI sync, black idle and restoration copies, leave lifecycle/playback control with the user, keep restricted core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 593 COMMIT Unreleased feb50c2 2026-08-27T03:34:43-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Prepare and qualify a reproducible DVD-ceiling video fixture for the unchanged guarded-transport hardware pair.

#### Outcome:

The user-approved diagnostic source is feb50c2; it changes only the new generator and its focused tests, with no production difference from a4f2769. GUNSMOKE pulled that exact Pi-published source and generated the same 449-picture 720x480 TFF all-I scene twice using FFmpeg 8.0.1-3ubuntu2. The retained 34,919,166-byte source has SHA-256 90976c09e12dfe03243d5c8daccf65ecc98b4d0008cb5489e96c73f667434979. Both official outputs are bit-identical and match the candidate: 18,402,691 bytes, SHA-256 3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065. Both full software decodes produce identical YCbCr hashes, and the existing interlaced-signalling patch does not change any decoded plane. All 449 pictures remain within the admitted frame-DCT interlaced all-I structure. Encoder rate, minimum and maximum are 9,800,000 bits per second, with a 1,835,008-bit buffer matching FFmpeg's DVD-target setting. Every repeated sequence header is checked, including Main Profile/Main Level, bitrate, buffer and frame-rate extension. A narrow constant-arrival buffer witness based on H.262 6.3.9 and Annex C supplies data at exactly 9.8 Mbps, starts decoding after 140.428 milliseconds, and removes complete access units at 30000/1001 cadence. It records no underflow or overflow; peak occupancy is 1,834,992 bits, and header-delay disagreement is at most 1.657 ticks at 90 kHz, within the check's two-tick quantization allowance. The file's coded bits divided by its 14.981633-second picture duration average 9.826801 Mbps; this is not the arrival rate because initial buffering supplies bits before the first decode. Thirty-frame coded-demand windows range from 9.116763 to 10.768967 Mbps, and the largest access unit is 143,171 bytes; the buffer trajectory checks these bursts rather than incorrectly requiring every frame/window to fit a flat rate. Seven focused tests pass, covering exact cadence and EOF, underflow, overflow, delay drift and quantization, invalid inputs and access-unit prefix/end accounting. This is a scoped engineering buffering check, not a general MPEG VBV verifier or formal DVD application-conformance test. No new RTL simulation, FPGA build or ARM build was performed because production behavior is unchanged. The qualified file was staged at /media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v.new, completely read back on a separate FTP connection, renamed to bbb_480i_tff_15s_9800kbps.m2v and independently read back again with matching size/hash; staging absence was confirmed. Complete installed Main/RBF reads still match the qualified a4f2769 hashes. Existing media and binaries were not overwritten, and no reboot, core reload, configuration change or playback was performed. Evidence is .ai/current_results/entry593_fixture.json, entry593_qualification.json, entry593_tests.log and entry593_deployment.json; durable source, both generated copies and logs are on GUNSMOKE under /home/vash/mister-builds/entry593. Built denotes successful diagnostic generation/qualification; hardware acceptance is still pending.

#### Next Steps:

Ask the user to play bbb_480i_tff_15s_9800kbps.m2v once from games/MediaPlayer using the same installed core and display mode, without needing a reboot, and to check menu responsiveness during playback before leaving terminal telemetry displayed. Retrieve the helper log first, then a freshly triggered screenshot and full decode. Require runtime credit_fast_v1 and mode 2, all 18,402,691 source bytes delivered, all 449 pictures and 448 swaps, no transport integrity/decoder errors, normal EOF and quiet completion, zero post-startup missed deadlines/outliers and steady 2,002,000-clock intervals at 60 MHz. This fixture has an odd byte count: the final payload byte uses an acknowledged word with zero padding, so reconcile ACK words with rounded-up byte counts and distinguish any observed final transport padding from source bytes instead of reusing entry 591's all-even-chunk assumptions. Interpret schema nineteen aggregate timestamps as startup-inclusive and evaluate actual post-first-swap deadline/gap telemetry for cadence. Preserve the first run before any cold/warm follow-up, then scope the 10.08 Mbps combined-stream/audio-and-timing gate separately; passing this clip will not establish full DVD compatibility. Keep the 18.65 Mbps file optional, leave production at a4f2769, preserve its restoration copies and credit/integrity/startup/sync protections, retain user control of lifecycle and playback, keep core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ceiling.py
- tools/streams/test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 592 COMMIT Unreleased a4f2769 2026-08-27T03:29:04-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Refocus performance acceptance on DVD-Video bitrate ceilings rather than the higher-rate diagnostic fixture.

#### Outcome:

The user clarifies that proper commercial DVD playback is the objective and asks to validate the maximum bitrate a DVD can deliver. This supersedes entry 591's proposed priority of further optimization for the 18.65 Mbps file: that file is retained as optional stress evidence, not a required DVD acceptance gate. The working SD DVD-Video targets are 9.8 Mbps for video, or 1,225,000 bytes per second, and 10.08 Mbps for the combined program stream, or 1,260,000 bytes per second. The combined rate is a shared budget, not an allowance added to video. The project reference was consulted first; it explicitly defers exact DVD application constraints to authorized DVD FLLC Part 2 and Part 3 books, which were not available. Adobe's primary DVD authoring primer, Japanese March-2004 edition, page 14, independently supports these two numerical targets at `https://www.adobe.com/jp/motion/pdfs/DVD_Primer.pdf#page=14`. This is supporting vendor guidance, not a substitute for the controlled DVD books or a formal application-conformance claim, so the restricted core and controlled reference remain unchanged. Scope, citation and validation criteria are retained in `.ai/current_results/entry592_dvd_rate_scope.json`. Entry 591 establishes clean steady playback of the 8 Mbps fixture only; neither the 9.8 Mbps video ceiling nor the 10.08 Mbps combined ceiling has been validated. Bitrate alone also does not bound decoder work or prove support for every DVD picture structure. The compressed disc-input budget must not become a hard cap on the internal helper-to-FPGA path, which can carry protocol framing and expanded decoded audio. No new fixture, source change, build, deployment, reboot, reload or playback was performed in this scope review. The qualified a4f2769 pair and restoration copies remain the baseline; Built refers to its existing qualification and Passed remains unchecked for the new ceiling target.

#### Next Steps:

Prepare a deterministic near-ceiling 9.8 Mbps video regression on GUNSMOKE within the currently supported picture subset, preserving a committed generation recipe and checking actual encoded rate, headers, buffering constraints and software decode rather than relying on the filename or encoder target alone. Validate steady nominal cadence, complete picture/byte counts, zero decoder and transport errors, startup and warm-load behavior, and menu responsiveness on hardware, leaving lifecycle and playback control with the user. Then qualify the 10.08 Mbps combined-stream budget with supported audio and timing when that boundary is ready, accounting for internal framing and decoded PCM traffic and retaining reasonable measured margin. Keep full commercial-DVD compatibility separate from this rate gate: interlaced P/B, field-picture/DCT, NTSC/PAL and film cadence, audio/PTS, navigation and other pending application features require their own coverage. Do not resume production optimization solely to pass the 18.65 Mbps stress file. If an in-scope ceiling test identifies a defect, propose a bounded revision based on that evidence while preserving credits, integrity checks, queue capacities, guarded startup, continuous HDMI sync and black idle. Keep core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 591 COMMIT Unreleased a4f2769 2026-08-27T03:21:12-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Validate the guarded transport on the qualified 8 Mbps elementary stream after a warm file load.

#### Outcome:

The user reports running the requested file without rebooting and says playback looked good. The helper log identifies `bbb_480i_tff_15s_8mbps.m2v`, runtime `transport=credit_fast_v1` and mode 2; its new child/session data and the unchanged 10:08:35 UTC Linux boot corroborate a new run without an intervening system reboot. This does not independently establish whether a core reload or mode switch occurred. The log was collected before a fresh screenshot, and complete host/FPGA readbacks retain both qualified `a4f2769` hashes. All 15,150,646 bytes, 449 reference/display pictures and 448 swaps complete with zero aggregate errors, no transport integrity abort, normal helper exit, sequence end and quiet terminal presentation. All 925 chunk byte totals, fast/slow counts, batch/query totals and fourteen payload-ACK samples reconcile. Fast transfers carry 15,029,026 bytes, or 99.1973 percent; 121,620 bytes use acknowledged single-word progress. There are zero actual post-startup deadline misses, zero cadence outliers and no retained missed-deadline records. The three largest measured post-first-swap intervals are exactly 2,002,000 decoder clocks, or 33.366667 milliseconds, matching steady 29.970030-fps cadence and the qualified entry-564 8 Mbps acceptance. The raw aggregate is 29.891489 fps across 14.987544 seconds because schema nineteen assigns its starting timestamp on first reference completion, before visible release, so it includes startup reserve and raster alignment; its 39.277-millisecond excess over 448 nominal intervals is not evidence of steady slowdown. This also corrects entry 590's description of its aggregate as first-to-last presentation and its implication that the entire excess duration was cadence delay: those aggregate measurements include startup, but that run's 77 actual post-startup missed intervals and 66.733-millisecond maximum gaps still independently establish remaining high-bitrate lateness. Matched delivery averages 1,016,885 B/s, paced by this smaller stream's downstream consumption rather than establishing raw link capacity. The host issues 885,783 fast batches averaging 16.967 bytes and 947,518 status queries; this confirms small available-credit grants under steady consumption, not a throughput regression compared with the larger file. All 340 helper EAGAIN events occur before first delivery. Data-bearing polls average 64.028 milliseconds and peak at 114.117 milliseconds; these measure Main-loop blocking exposure, and current menu responsiveness is still not separately confirmed by the user's visual report. Capture, complete decode, checked analysis and prior qualified-file comparison are preserved as `.ai/current_results/entry591_*`. No source, deployed binary, configuration, lifecycle or playback action was changed during collection. This entry passes the scoped warm 8 Mbps hardware regression and preserves its prior steady cadence; it does not pass the high-bitrate fixture, all display modes, arbitrary cancellation or the remaining unsupported feature set.

#### Next Steps:

Retain `a4f2769` and the restoration pair as the tested guarded-transport baseline, with entry 590 preserving the larger-file improvement and entry 591 closing the requested warm 8 Mbps regression. Obtain a separate report of menu responsiveness during playback without requesting another identical file run unless a new diagnostic question requires it. For further performance work, propose and obtain approval for a focused investigation of the remaining high-bitrate decoder-side processing/backpressure, using the retained ready/input/writer evidence to distinguish internal decode waits from output pressure and status-query overhead before changing production behavior. Preserve credit and integrity checks, both FIFO sizes, guarded startup, continuous HDMI sync and black idle. Keep unsupported interlaced P/B, field-picture/DCT, audio/PTS, mode-switch/cancellation coverage and historical assertion drift explicitly outside this acceptance, leave reboot/playback control with the user, keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 590 COMMIT Unreleased a4f2769 2026-08-27T03:13:17-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Verify guarded fast-block activation and measure the first high-bitrate hardware run against the acknowledged baseline.

#### Outcome:

The user reports no visible slowdown. The helper log was retrieved first, followed by a freshly triggered screenshot and complete host/FPGA readbacks; both installed hashes match qualified `a4f2769`, and a new Linux boot at 10:08:35 UTC plus runtime `transport=credit_fast_v1` and mode 2 corroborate activation. All 34,919,166 bytes, 449 pictures and 448 swaps complete with zero decoder error flags, normal helper exit, sequence end and quiet terminal presentation. There is no transport integrity abort, and all 2,132 logged chunk byte/count/checksum completions and batch/query totals reconcile. Fast transfers carry 34,896,748 bytes, or 99.9358 percent; the remaining 22,418 bytes use acknowledged single-word progress at zero credit. Compared with entry 587, matched completed-chunk delivery rises from 1,578,252 to 1,988,891 B/s, a 26.02 percent gain, and cadence rises from 20.248749 to 25.507040 fps. The first-to-last presentation span falls from 22.124823 to 17.563778 seconds, while complete transfer-call time falls from 21.202251 to 16.624084 seconds. Delayed eventual presentation intervals fall from 167 to 77, and the three longest retained gaps are now 66.733 milliseconds instead of a maximum 166.833 milliseconds, a 60 percent reduction consistent with the user's improved perception. Strict 30000/1001 cadence is still not met: 448 intervals would take 14.948267 seconds at nominal rate, 2.615512 seconds less than observed. The cause visible in retained deadlines has changed: the first three delayed deadlines, full-width picture ordinals 8, 11 and 14, now have both decoder input and upstream FIFO input pending, decoder not ready, zero input-starvation cycles and no presentation/destination hold; their writer-capacity blocked counts are 127, 36 and 215 cycles. Prior retained misses had ready-but-empty decoder input. The gated upstream-pending/decoder-not-ready counter covers 95.8468 percent of captured session cycles, supporting a shift toward decoder-side processing or backpressure, but it does not identify a specific arithmetic stage or exclude internal waits. Only three delayed-deadline records are retained, so their cause must not be assigned to all 77 late intervals. Host grants are predominantly small after initial 8 KiB batches: 791,350 fast batches average 44.10 bytes, with 804,691 status queries containing 5,632,837 acknowledged status-word transactions. FIFO consumption now governs small grants, and query overhead may matter; the log does not separate raw bus time, status time and downstream wait time. The 1.989 MB/s consumption-limited average is not a raw link-capacity measurement, and no 10 MB/s claim is established. All 587 helper EAGAIN events precede first delivery. Mean data-bearing poll duration improves to 32.768 milliseconds, but the maximum remains 81.485 milliseconds; these are blocking exposure rather than measured UI response, and current menu responsiveness has not been separately reported. The eight-bit largest-gap ordinals remain ambiguous after 256 pictures; do not confuse them with full-width deadline ordinals. Capture, decoded packet, helper log and checked comparison are stored as `.ai/current_results/entry590_*`. No production source, installed binary, configuration, reboot, reload or playback was changed during collection. Transport functionality and substantial improvement are verified, but full high-bitrate cadence acceptance and the separate 8 Mbps regression remain outstanding.

#### Next Steps:

With this high-bitrate evidence preserved, ask the user to play `bbb_480i_tff_15s_8mbps.m2v` once using the same installed pair and display mode, leave telemetry displayed, and report whether the menu remains responsive. Collect its helper log before another playback, then a fresh screenshot and image checks; verify mode 2, complete byte/picture counts, no integrity/decoder errors and cadence. Keep the guarded credit and integrity protocol, both FIFO capacities, startup controller, continuous HDMI sync and black idle unchanged. Before any further decoder or transport revision, propose a focused boundary and obtain approval; the current evidence points toward downstream processing/backpressure but does not yet isolate an internal stage or justify removing safeguards. Preserve the restoration copies and outstanding unsupported interlaced P/B, field-picture/DCT, audio/PTS, cancellation and historical assertion-drift limits. Keep restricted `core.md` unchanged, retain the forty-entry ring and do not mark nominal-cadence acceptance passed from the user's visual report alone.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 589 COMMIT Unreleased a4f2769 2026-08-27T03:07:27-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Deploy the qualified guarded fast-block host and FPGA pair after MiSTer connectivity is restored.

#### Outcome:

The user reports that the MiSTer is connected, and FTP access to `10.10.0.30` succeeds. The active predecessors match the expected `be8502b` host and `2acabc5` FPGA hashes. Both complete images were retrieved and fsynced locally, then retained and independently hash-verified and fsynced under `/home/vash/mister-builds/entry588-backup` on GUNSMOKE as `MiSTer.prea4f2769` and `MediaPlayer.rbf.prea4f2769`. A read-only backup attempt exposed FTP transfer-mode handling after a directory listing; the procedural scripts were corrected and the complete backup pass repeated before deployment, without changing production source or artifacts. The qualified `a4f2769` candidates were staged at `/media/fat/MiSTer.new` and `/media/fat/MediaPlayer.rbf.new`, and both passed complete fresh-connection readbacks and permission checks before either rename. The active predecessors were reverified immediately before replacement. Each file rename is atomic; the pair is not, but both mixed-version combinations preserve acknowledged transfers. A further independent FTP connection verified both complete active files, executable permissions and absence of both staging paths. Installed `/media/fat/MiSTer` is 1,170,340 bytes with SHA-256 `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`; installed `/media/fat/MediaPlayer.rbf` is 4,332,748 bytes with SHA-256 `15bc3057a4f16369bc4a3dac01e30f63e5fc563a43b1922214b5b478c17c66c2`. Deployment evidence and restoration details are in `.ai/current_results/entry589_deployment.json`; corrected procedural scripts remain under `/home/vash/mister-builds/entry588/resume-scripts`. Entry 588's clean builds, regressions and positive timing qualification remain applicable; no rebuild or production change was needed. No reboot, core reload, playback, helper replacement or configuration edit occurred. The new files are installed, but runtime activation, performance and hardware acceptance are not yet verified.

#### Next Steps:

Have the user cold-power-cycle the MiSTer, load MediaPlayer and play `bbb_480i_tff_15s.m2v` once, then leave terminal telemetry displayed without replaying or running the 8 Mbps file yet. Collect `/tmp/MediaPlayer_ARM.log` first, then a fresh screenshot and complete installed-image readbacks; require a new boot, marker `transport=credit_fast_v1`, transport mode 2 with nonzero fast bytes, no integrity fault, all 34,919,166 bytes, 449 pictures, 448 swaps and zero decoder errors. Compare delivery rate, transfer time, cadence and delayed intervals against entry 587's 1,578,252 B/s, 21.202251 seconds, 20.248749 fps and 167 delayed intervals, and ask whether the meadow slowdown and menu responsiveness changed. Preserve this capture before the separate qualified 8 Mbps regression. Treat 10 MB/s as the user's earlier guess and decoder-bound playback as an unverified hypothesis. Preserve startup, continuous HDMI sync, black idle, both queue capacities and existing unsupported-feature limits; retain the restoration pair, standing qualified-deployment permission and user control of reboot/playback. Keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 588 COMMIT Unreleased a4f2769 2026-08-27T02:59:27-07:00

#### Coming From:

Unreleased be8502b

#### Purpose:

Enable bounded fast-block media transfers using FPGA FIFO credits and post-batch integrity checks while preserving the acknowledged legacy path.

#### Outcome:

The approved coordinated implementation is source `a4f2769`. Main remains the sole FPGA I/O owner and uses the existing fast-block primitive only after an opt-in status query grants conservative input-FIFO credit, capped at 4096 words; commands and status remain acknowledged. Coherent snapshots expose credit, accepted-word count, a rolling 16-bit rotate/XOR checksum and ready/overflow flags. Main verifies every batch before additional data, aborts on mismatches without retrying uncertain bytes, preserves legacy/narrow/unaligned/odd-tail handling and uses one acknowledged word of progress when credit is zero. Session state resets even when logging is unavailable, and runtime telemetry distinguishes fast bytes, slow bytes, batch/query totals and detailed fault observations with marker `transport=credit_fast_v1`. The checksum can collide and is not a cryptographic integrity guarantee. The vendor Cyclone V model exposed a real near-full hazard: after a partial-byte read, a wrapped zero write-used count could advertise empty capacity before the count caught up. Credit now trusts a zero count only when write-domain empty agrees. Both literal-default and Cyclone V vendor models pass 26,878 credit batches each, full and partial-byte transitions, asynchronous clock ratios, pointer wrap, reset readiness, sticky overflow attempts and exact byte/count/checksum checks; effective modeled full capacity is respectively 32,766 and 32,768 bytes. The existing 32-word nominal reserve remains, giving at least 31 words relative to the default model's effective capacity. Real-host/extracted handshake and FIO qualification passes 288 guarded cases across narrow, legacy-wide and capable-wide configurations at four modeled register delays, plus 168 original-versus-ACK-bulk cases in each of the three configurations and explicit zero/full-credit, counter-wrap, coherent-snapshot, lost/corrupt-word, reset, bad credit/count/digest/capability and no-second-batch fault cases. Forty native ACK transport cases and complete loader scenarios pass both normally and under ASan/UBSan; RTL simulations are not sanitizer-instrumented. These model timings are protocol stress conditions, not physical throughput estimates. GUNSMOKE pulled the exact Pi-published source, matched candidate files and repeated official qualification. The existing native-video suite passes startup, field order, presentation overlap, sync/reset, cache/fingerprint/generation and cadence packet checks; the clean-video queue test passes 85,696 bytes, four metadata records and three PCM samples. The clean ARM build using pinned Main `0a8fb44` and official GCC 10.2.1 completes in 4.43 seconds with zero warnings/errors, producing 1,170,340 bytes and SHA-256 `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`. The clean Quartus 17.0.2 seed-16 build completes in 712.06 seconds with 0 errors and 208 warnings; reviewed worst slacks are setup 0.217 ns, hold 0.249 ns, recovery 3.559 ns, removal 0.574 ns, minimum pulse width 0.925 ns, all TNS are zero and no new ignored timing filters appear; normalized warning messages are identical to the baseline. FPGA output is 4,332,748 bytes with SHA-256 `15bc3057a4f16369bc4a3dac01e30f63e5fc563a43b1922214b5b478c17c66c2`. Deployment could not begin because the MiSTer at `10.10.0.30` was unreachable from the Pi; the attempted FTP connection failed before login or any remote write. No predecessor backup was collected this cycle and neither candidate was installed. The user was asked to power on or reconnect the MiSTer and leave it at the menu. Qualified candidates and reports remain under `/home/vash/mister-builds/entry588` on GUNSMOKE, with matching Pi copies under `/tmp/entry588-reports`. The previously deployed host remains the last verified `be8502b` and FPGA `2acabc5`; current device state has not been reverified. Evidence is retained as `.ai/current_results/entry588_*`. The ingest FIFO capacity, separate 64 KiB clean-video queue, startup controller, decoder arithmetic, continuous HDMI sync and black idle are unchanged. The user's earlier 10 MB/s figure remains only a guess, and decoder-bound playback remains a hypothesis. Hardware acceptance is not claimed.

#### Next Steps:

Once the user restores MiSTer connectivity at `10.10.0.30`, resume verified paired deployment under standing permission without changing source: retrieve and hash-check the active predecessors, retain fsynced local and persistent GUNSMOKE restoration copies, stage and independently read back both candidates, rename and independently verify the complete active files and permissions. Leave lifecycle control with the user, then request one cold run of `bbb_480i_tff_15s.m2v`. Collect its log before a fresh screenshot, require `transport=credit_fast_v1`, mode 2, nonzero fast bytes, no integrity fault and complete byte/picture counts, and compare delivery/cadence with entry 587. Capture that run before the outstanding qualified 8 Mbps regression; no speedup or decoder-bound claim is established yet. Retain prior unsupported interlaced P/B, field-picture/DCT, audio/PTS, cancellation and assertion-drift limitations, keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

- MediaPlayer_top_00.svh
- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- rtl/mpeg2_stream_fifo.sv
- sys/hps_io.sv
- tools/streams/tb_mpeg2_stream_fifo_burst.sv
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 587 COMMIT Unreleased be8502b 2026-08-27T02:22:06-07:00

#### Coming From:

Unreleased be8502b

#### Purpose:

Measure the first hardware run of the acknowledged bulk preload path and determine whether its host-side savings resolve high-bitrate playback.

#### Outcome:

The user reports that everything looks the same and leaves the image ready. The helper log was collected first, followed by a freshly triggered screenshot and complete host/FPGA readbacks. A new Linux boot at 09:17:15 UTC and runtime `transport=ack_bulk_preload_v1` establish activation of `be8502b`; the complete installed host hash remains `da213d6bd9cc89a9af736a0bb029f9ebadd6e6a62382728ae1bacc07a381f909`, and FPGA `2acabc5` is unchanged. All 34,919,166 bytes, 449 pictures and 448 swaps complete with zero decoder error flags, normal helper exit and a quiet completed presentation. There is a real but insufficient measured gain over entry 585: matched completed-chunk delivery rises from 1,427,221 to 1,578,252 bytes per second, or 10.58 percent, while cadence improves from 18.315332 to 20.248749 fps and from 24.460381 to 22.124823 seconds. Delayed presentation intervals fall from 186 to 167, but the two largest retained holds remain 166.833 milliseconds, consistent with the user's lack of perceptible improvement. The median unsampled full 16 KiB transfer falls from 10,780 to 9,196 microseconds, confirming that the changed word loop saved time; complete transfer-call duration falls from 23.585322 to 21.202251 seconds. Transfers and ACK waits still consume 96.36 percent of measured media-poll time, whereas pipe reads consume 0.724867 seconds or 3.29 percent. All 590 EAGAIN events occur before the first completed chunk. The 533 data-bearing polls average 41.273 milliseconds, but the maximum poll remains 81.209 milliseconds; these are blocking exposure rather than direct UI latency. Across the same 270,336 sampled words, extended ACK-low polling now occurs in seven of thirty-three chunks rather than one, with a maximum of 76 GPI reads and no uninitialized indication. Faster delivery meeting downstream flow control more often is plausible, but samples do not measure total FIFO-wait duration or establish its precise cause. The first three retained delayed deadlines find decoder input ready but empty and upstream FIFO empty; their writer-capacity blocked counts are 22, zero and 255 cycles, not all zero. The aggregate decoder-stall counter increases, but RTL gates that count on input pending and decoder not ready, so greater input availability can change its coverage and this alone is not evidence of a decoder regression. Supply remains only 67.71 percent of the file's average demand, requiring another 47.68 percent increase merely to meet that average; the largest meadow picture still needs about 161 milliseconds of bytes at this mean rate against 33.367 milliseconds per nominal frame. Preserve the eight-bit largest-gap ordinal ambiguity: raw codes 95, 98 and 15 are not unique absolute positions in this 449-picture file. The old spikes problem remains historical progressive bring-up context, not the current comparison. Capture, helper log, full decode and checked analysis are stored as `.ai/current_results/entry587_*`; no source, deployed binary, media, configuration or lifecycle was changed. Hardware cadence acceptance still fails, and neither the qualified 8 Mbps regression nor a separate current menu assessment is claimed. The user also asks about another agent's alternative delivery path and a possible 10 MB/s rate. Entries 579 and 580 identify the likely reference as `spi_block_write` through `fpga_spi_fast_block_write`, which uses the same physical GPIO-style link but omits per-word ACK reads; entry 581 already explains why that cannot be substituted without FIFO flow control. The present preload path still waits for both ACK phases. The helper currently writes to a pipe and Main owns FPGA I/O, so this is a Main transport choice rather than an existing direct-helper mode. Main also has lightweight-bridge register access, but a dedicated receiver or shared-memory/DMA route would be a distinct implementation. No measured 10 MB/s result for this target was found in the reviewed evidence, and that figure must remain unverified.

#### Next Steps:

Do not repeat the same hardware condition or expect another minor host-loop reduction to provide the missing throughput. Prefer investigating the existing fast-block primitive with an explicitly approved coordinated host/FPGA transport change that amortizes acknowledgements across bounded bursts backed by conservatively reported ingest-FIFO capacity, with documented strobe ordering and drain guarantees, reset and legacy fallback behavior, and overflow plus byte-count verification. The existing ingest FIFO is a separate 32 KiB mixed-width FIFO; preserve the 64 KiB clean-video queue and do not confuse or enlarge the two as a substitute for transport work. Qualification must include protocol and clock-domain/backpressure tests, the full relevant FPGA regressions, a clean Quartus build and timing review before deployment; faster transport must not be promised to remove every downstream decoder limit. Obtain approval before implementing that material protocol revision, while retaining standing publication and qualified deployment permissions. Keep `be8502b` as the current measured comparison point, preserve startup, continuous HDMI sync and black idle behavior, leave reboot and playback to the user, and retain the outstanding 8 Mbps and unsupported-feature boundaries. Keep restricted `core.md` unchanged and preserve the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 586 COMMIT Unreleased be8502b 2026-08-27T02:05:53-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Reduce MediaPlayer host transfer overhead with a bulk word loop that preloads the next payload during the acknowledged low phase while preserving FPGA flow control.

#### Outcome:

The approved host-only implementation is source `be8502b`. MediaPlayer now uses a dedicated bulk primitive that prepares the next payload only after the current word's ACK-high, lowers the strobe with that payload and waits for ACK-low before its next rising edge. The ordinary non-media transfer and `fpga_spi` functions remain byte-identical to pinned upstream Main_MiSTer `0a8fb44`; no FPGA source or image was changed. For a full 16 KiB wide chunk the data loop issues 16,385 GPO writes instead of 24,576, retaining both ACK phases, final low-clock cached state, little-endian packing, unaligned input safety, padded odd tails and narrow transfers. Sampled and unsampled template specializations retain every-sixty-fourth-chunk ACK profiling, and logs identify `transport=ack_bulk_preload_v1`. Forty native transport cases pass, including unchanged rising-edge payloads and ACK-read traces, exact write counts, final GPO and reset exits at the first, middle and final word; the uninitialized messages in these test reports are deliberate injected cases. Loader coverage retains four-read polling, byte identity, sampling, EAGAIN, EOF accounting, errno preservation, warm reset, core change, external stop and unavailable diagnostics. Native tests pass both normally and under ASan/UBSan. A new optional RTL mode compiles the actual clock/ACK and download blocks extracted from existing `sys_top.v` and `hps_io.sv` with Verilator, then runs both original and bulk host functions against 168 narrow and 168 wide cases with four bridge latencies, a two-word sink that reaches full, independent wait and vs_wait intervals, consecutive chunks, odd tails, exact download addresses and release. All pass; an initial simulator teardown failure after passing narrow cases was fixed by destroying the model before the thread-local Verilator context, without changing production logic. After source publication from the Pi, GUNSMOKE pulled exact `be8502b`, verified both source hashes against the tested candidate, repeated all qualification and built from zero generated objects with official ARM GNU 10.2.1 20201103. The clean compile completed in 4.17 seconds with zero compiler warnings or errors, producing a 1,166,244-byte ARMv7 hard-float binary with SHA-256 `da213d6bd9cc89a9af736a0bb029f9ebadd6e6a62382728ae1bacc07a381f909`. Its complete Pi copy matches the build report. The previous `32ba178` host image was retrieved, hashed and fsynced locally, then retained and independently verified at `/home/vash/mister-builds/entry586-backup/MiSTer.prebe8502b` on GUNSMOKE. The candidate was staged at `/media/fat/MiSTer.new`, read back through a fresh FTP connection and verified executable before rename; another fresh connection retrieved the active binary with exact matching bytes and hash, confirmed executable permissions and absence of the stage. Full FPGA readbacks before and after retain the qualified `2acabc5` hash. No reboot, core reload, playback, helper or configuration change occurred. Build, regression and deployment records are retained under `.ai/current_results/entry586_*`. This is a tested and deployed optimization candidate, not yet an active-process verification, measured speedup or hardware acceptance; simulator bridge delays are test conditions rather than a physical performance model.

#### Next Steps:

Have the user power-cycle, load the core and play `bbb_480i_tff_15s.m2v` once, then stop without replaying and leave terminal telemetry displayed. Fetch the helper log before the screenshot, verify a new boot and `transport=ack_bulk_preload_v1`, and compare delivery, transfer duration, sampled ACK behavior and cadence against entry 585's 1,427,221 bytes per second, 23.585322 seconds of transfer, 18.315332 fps and 186 delayed presentation intervals. Confirm full byte/picture counts, zero error flags, whether the meadow slowdown improves and current menu responsiveness. Collect that run before requesting the separate qualified 8 Mbps regression so its log is not overwritten. The reduced register-write count is not a promise to meet the file's 2.33 MB/s demand; if host-only headroom is insufficient, propose an explicitly approved FPGA transport revision rather than removing ACK protection. Preserve the existing startup controller, 64 KiB clean-video queue, continuous HDMI sync and black idle behavior, and retain all prior unsupported interlaced, audio/PTS, cancellation and assertion-drift limitations. Continue routine publication and qualified host deployment under standing permission with backup/readback safeguards, keep reboot and playback with the user and preserve restricted `core.md` plus the forty-entry ring.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 585 COMMIT Unreleased 32ba178 2026-08-27T01:59:36-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Validate the first cold profiling run and identify whether helper reads, acknowledged FPGA transfers or other main-loop work dominate high-bitrate playback.

#### Outcome:

After the user reported the screen ready, the helper log was fetched before a fresh terminal screenshot. Syslog records a new Linux boot at 08:52:25 UTC versus entry 581's 08:23:32; it corroborates the requested reboot but does not independently prove power removal or playback count. The runtime log contains `profile_version=1`, and full host and FPGA readbacks retain entry 584's expected hashes, establishing that host source `32ba178` is now running against unchanged FPGA `2acabc5`. All 34,919,166 bytes and 449 pictures complete, with 448 swaps, zero decoder error flags, normal helper exit and quiet completed presentation. Cadence still fails: 24.460381 seconds, 18.315332 fps and 186 delayed presentation intervals, compared with entry 581's 18.335712 fps and 185 intervals. Matched completed-chunk endpoints yield 1,427,221 bytes per second, only 0.049 percent below the prior run and far below the file's 2,330,798-byte-per-second average demand. Profiling directly separates the cost: 2,132 transfers consume 23.585322 seconds, or 96.68 percent of 24.394209 seconds inside media polls; all pipe reads consume 0.730964 seconds, or 3.00 percent, and other measured in-poll work accounts for 0.077923 seconds. The 485 EAGAIN events all precede the first successful chunk. Actual accounting records 533 data-bearing polls, averaging 45.759 milliseconds with an 80.498-millisecond maximum across all polls; these are blocking exposure, not direct UI latency. Thirty-three sampled chunks cover 270,336 words. In 32 chunks both ACK phases require at most two GPI reads per word, with nearly two reads typical; high or low wait-word counts merely mean more than one read and must not be mislabeled FIFO-full stalls. Sample event 768 is exceptional: ACK-low takes up to 72 reads, totaling 55,330 low-phase reads across 8,192 words, and nearby unsampled transfers also slow. This confirms actual extended ACK polling while leaving the cause and unsampled wait distribution unresolved. The ordinary handshake and bridge path therefore remain the useful optimization target, but eliminating flow control is unsafe. The first successful read occurs 39.694 milliseconds after download assertion and the first entire chunk completes at 51.494 milliseconds, keeping the legacy first-byte label distinct. Sampled full chunks have a 3.66 percent higher median transfer cost than unsampled chunks; these are unpaired measurements, and one nearly unchanged aggregate run cannot quantify instrumentation overhead. The retained first three delayed deadlines show ready-but-empty decoder input and empty upstream FIFO, with writer-capacity blocking of zero, zero and nine cycles. The user's earlier responsive-menu observation belongs to entry 581; current menu responsiveness remains unreported. The user subsequently identified the meadow as the current worst section and clarified that the spikes comparison refers to old progressive bring-up, not another recent run. Build-PC frame extraction from the hash-verified fixture identifies picture 350 as dense ground foliage viewed from above, with the clip's largest encoded span of 253,632 bytes, requiring about 178 milliseconds at measured mean supply against 33.367 milliseconds per nominal frame. This supports the reported meadow slowdown without establishing a relation to the old progressive issue. A source-review correction is also required: the largest-gap metadata holds only an eight-bit picture ordinal, so raw codes 93, 94 and 95 are ambiguous between pictures 93 through 95 and 349 through 351 in this 449-picture clip; the wrapped candidates coincide with the largest pictures and reported meadow scene, but the snapshot alone cannot prove that mapping. The three retained largest intervals are each 166.833 milliseconds. Capture, decode, helper log and checked analysis are retained as `.ai/current_results/entry585_*`. No production source, deployed binary, configuration or lifecycle was changed; the profiling works as a diagnostic, but smooth-playback acceptance and the qualified 8 Mbps regression remain outstanding.

#### Next Steps:

Prepare the next approved implementation boundary around a flow-controlled bulk transfer path that reduces per-word bridge overhead while preserving ACK/backpressure, byte order, odd tails, core readiness and reset handling, and ordinary non-media transports. Do not increase buffers again or substitute unchecked fast writes. Establish protocol and byte-trace equivalence plus delayed-backpressure tests and build with the official ARM toolchain before qualified host deployment; if adequate headroom requires an FPGA transport-protocol change, obtain approval for that material revision before implementing it. Retain the user's standing evidence/source publication and host-deployment permissions without repeating those questions, while keeping backup, staging and independent readback safeguards. Do not request another identical hardware run merely for statistics. After a changed candidate is available, validate one high-bitrate run and the outstanding qualified 8 Mbps case, and confirm whether the meadow slowdown improves and obtain a current menu-responsiveness report. Keep the existing startup controller, 64 KiB clean-video queue, continuous HDMI sync and black idle behavior unchanged, leave reboot and playback to the user, preserve restricted `core.md` and the forty-entry ring, and retain the unresolved interlaced, audio/PTS, cancellation and assertion-drift limitations from prior entries.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 584 COMMIT Unreleased 32ba178 2026-08-27T01:52:36-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Publish and install the verified host-transfer profiling build and record standing user authorization for future source publication and host deployment.

#### Outcome:

The user explicitly approved publishing the profiling source to GitHub and installing the host binary with backup and full readback, then stated that approval is not needed going forward. This extends entry 582's evidence-publication permission to source-code publication in `aquasock/MiSTer-Media-Player` and qualified host-system-binary replacement during approved project development, without repeating publication or deployment permission questions; preserve build and regression qualification, restoration data, staged verification and independent active readback. Existing requirements to keep `core.md` restricted, obtain approval for materially revised development plans and leave reboot or playback to the user remain unchanged. Source `32ba178` and its build report were pushed from the Pi, and GUNSMOKE pulled published master `41cb150`; both source-file hashes and the complete candidate binary were verified against the exact tested build, resolving entry 583's unpublished-candidate limitation without changing its source. Before writing to the target, the current 1,166,244-byte `/media/fat/MiSTer` was fully retrieved, checked against the server size and SHA-256 `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`, flushed to local disk, then copied and independently re-hashed in persistent storage at `/home/vash/mister-builds/entry584-backup/MiSTer.pre32ba178` on GUNSMOKE. The profiling candidate was uploaded to the previously absent `/media/fat/MiSTer.new`, read back completely through a fresh FTP session, checked byte-for-byte and confirmed executable before being renamed over `/media/fat/MiSTer`. The predecessor hash was rechecked immediately before rename. A separate fresh session then retrieved the complete active file: all 1,166,244 bytes match SHA-256 `1aae53b0209e873b1edfe20f60bad10c2c4cd5ce1e21f7f40eea81be313facb9`, permissions remain `-rwxr-xr-x` and no staging file remains. Full FPGA readbacks before and after retain the qualified `2acabc5` hash `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`. No helper, media, configuration, core lifecycle or Linux lifecycle was changed. The running host process retains its old inode until the user reboots, so this records verified deployment rather than runtime activation, throughput improvement or hardware acceptance. The deployment manifest is `.ai/current_results/entry584_deployment.json`; the latest hardware observation remains entry 581 with the subsequently confirmed responsive menu.

#### Next Steps:

Have the user power-cycle the MiSTer, load the core and play `bbb_480i_tff_15s.m2v` once under the same conditions as entry 581, then stop without replaying and leave terminal telemetry displayed. Fetch `/tmp/MediaPlayer_ARM.log` before the screenshot and verify the new boot plus `profile_version=1`, per-read timing and sampled ACK records to establish runtime activation. Compare separate read and transfer durations, actual data-bearing poll timing, ACK read distributions and cadence with the prior 16 KiB run before selecting an optimization; retain the profiling overhead and sampling limitations from entry 583. Full byte and picture counts, error status and interface responsiveness still gate acceptance, and the qualified 8 Mbps regression remains outstanding. Apply the new standing publication and host-deployment permission to subsequent approved cycles without asking again for those routine actions, while retaining the verification safeguards and keeping the FPGA startup, queue, sync and timing unchanged unless a separate plan is approved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 583 COMMIT Unreleased 32ba178 2026-08-27T01:37:49-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Separate helper pipe-read time, acknowledged FPGA-transfer cost and main-loop blocking with bounded host-side profiling.

#### Outcome:

Local source `32ba178` implements the approved host profiling in the existing pinned Main_MiSTer integration patch and adds one focused regression. The 16 KiB buffer, four-chunk limit, ordinary unsampled transfer function, both ACK phases and odd-byte handling are preserved. Per-read records separate pipe-read and complete-transfer time; session summaries count actual polls, data-bearing polls, time inside polls and entry intervals. Every sixty-fourth successful read uses a separately instrumented mirror of the acknowledged word function, reporting high and low ACK-read totals, wait-word counts and maxima without additional register accesses or per-word clocks or logging. First successful pipe read is now distinguished from the legacy first-byte label, which still means first completed chunk. Tests compile the real patched functions against deterministic mocks: fourteen transport cases match the upstream register and framing trace for delayed ACKs, wide and narrow lengths, odd tails and uninitialized-FPGA exits, while the loader test verifies a sixty-six-chunk session, byte identity, sampling, four-read budget, EAGAIN, errno preservation, EOF accounting, idle behavior, warm reset, core change, external stop and unavailable diagnostic output. Both ordinary and address/undefined-behavior sanitizer runs pass, including a repeat against the exact committed candidate archive on GUNSMOKE. The user confirms that the menu remained responsive during entry 581's video playback. Source publication was separately blocked by the execution approval policy because entry 582 authorizes evidence publication but not new source-code publication; no attempt was made to bypass that gate. The build PC pulled published master `7eca031`, then an isolated candidate build used the exact unpublished `32ba178` archive against Main_MiSTer `0a8fb44` with official ARM GNU 10.2.1 20201103. It compiled 113 source files from an empty generated-object state in 4.11 seconds with zero compiler warnings or errors, producing a 1,166,244-byte ARMv7 hard-float binary with SHA-256 `1aae53b0209e873b1edfe20f60bad10c2c4cd5ce1e21f7f40eea81be313facb9`; its Pi scratch copy matches exactly and the expected profiling strings are present. The only unrelated upstream difference is a non-source miniz changelog line-ending conversion. Build, ordinary-test and sanitized-test reports plus the compiler log are retained under `.ai/current_results/entry583_*`, with the isolated build at `/home/vash/mister-builds/entry583-32ba178` and candidate Pi binary at `/tmp/entry583-reports/MiSTer`. This is a diagnostic candidate, not a throughput fix or hardware acceptance. Clock and logging overhead remain unmeasured on hardware, sampled ACK counts are not direct wait durations and may miss unsampled stalls, and poll intervals are not direct UI latency. No MiSTer binary, helper, FPGA image, configuration or lifecycle was changed.

#### Next Steps:

Obtain explicit approval to publish the two profiling source files to `aquasock/MiSTer-Media-Player` and to replace the host-system binary `/media/fat/MiSTer`; these are separate from standing evidence-publication and RBF permissions. Once approved, publish the local source and build-result commits from the Pi, verify GitHub and build-PC source identity, retain and hash the current host binary, stage the verified candidate, independently check the staged bytes, rename over the active path and read back the complete active image through a fresh FTP session. Leave reboot and playback to the user. Request one cold high-bitrate run, fetch the helper log before the screenshot and inspect read time, transfer time, sampled ACK loops and actual media-poll timing before choosing a correction. Confirm complete byte and picture counts, unchanged error status and whether instrumentation materially changes cadence. Retain the pending 8 Mbps regression and preserve FIFO backpressure, byte order, odd tails and the unchanged FPGA startup, queue, sync and timing behavior. Do not publish local commits or deploy the host binary until their explicit approvals are obtained.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 582 COMMIT Unreleased ad364bf 2026-08-27T01:33:33-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Record standing user authorization to publish this project's diagnostic evidence and project-log updates to its GitHub repository.

#### Outcome:

After entry 581's publication was blocked pending explicit consent for its diagnostic logs and screen content, the user approved uploading those files and the log update to `aquasock/MiSTer-Media-Player` and stated that this may be done automatically going forward. This is standing authorization to commit and push project-related diagnostic logs, telemetry captures and screenshots, associated analysis and project-log updates to that same GitHub repository during the normal project workflow, without asking separately for publication each time. Continue to inspect the payload and exclude credentials, private keys and unrelated personal or system data. This approval concerns evidence publication; it does not approve the proposed host-transfer profiling or optimization cycle, replacement of the MiSTer system binary, new hardware actions or edits to restricted `core.md`. Entry 581 remains the latest hardware result: the 16 KiB host buffer is active but high-bitrate playback fails cadence acceptance, and the FPGA image remains unchanged. No new build or hardware test was performed for this authorization record.

#### Next Steps:

Publish the pending entry-581 evidence and this authorization record from the Raspberry Pi checkout to GitHub master, verify the remote commit and retain this standing publication permission in future recovery context. Apply it to subsequent relevant evidence and log updates without an additional publication question. Obtain approval for the separate host-transfer profiling and safe optimization proposal before changing production source or deploying a host binary, retain required backpressure and byte handling, and keep the unresolved hardware acceptance and 8 Mbps regression visible. Preserve `core.md`, the existing untracked screenshots and the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 581 COMMIT Unreleased ad364bf 2026-08-27T01:30:00-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Validate the larger host delivery buffer on one cold high-bitrate playback and identify the remaining transfer boundary.

#### Outcome:

The user reports a cold reboot followed by one playback that runs perfectly in some places and very slowly in others. The new syslog start at 08:23:32 UTC, replacing the previously collected 08:05:14 start, corroborates the reboot. The helper log was fetched before a fresh screenshot, with only the old fixed screenshot deleted before triggering. Full readbacks confirm the recorded `ad364bf` host binary and unchanged `2acabc5` FPGA image, and the exact 34,919,166-byte media file matches SHA-256 `90976c09e12dfe03243d5c8daccf65ecc98b4d0008cb5489e96c73f667434979`. Schema nineteen validates all 449 pictures, 448 swaps, sequence end, quiet presentation completion and zero aggregate errors, but records 185 delayed presentation intervals over 24.433194 seconds, averaging 18.335712 fps; the three largest holds are 200.2, 166.833 and 166.833 milliseconds at ordinals 95, 93 and 94. The buffer change is active: 2,131 reads contain 16,384 bytes and the final read contains 4,862, with normal helper exit and no pipe EAGAIN after the first completed chunk. Matched completed-read endpoints measure 1,427,919 bytes per second and an inferred 21.7955 four-read polls per second, versus entry 578's 1,420,489 and 86.7080. Four times the chunk size therefore yields only about half a percent more throughput while the inferred poll rate falls fourfold; the high-bitrate acceptance fails. This corrects entries 577 through 580's causal attribution to a fixed poll budget: agreement between throughput and a poll rate derived from the same read count is substantially algebraic, not independent evidence that poll frequency remains fixed. The data support transfer cost scaling with bytes, but do not separate bridge overhead from legitimate FPGA wait. The verified stream's picture spans range from 27,190 to 253,632 bytes against approximately 47,645 delivered bytes per nominal frame interval, consistent with alternating smooth and slow passages rather than a continuously wrong raster clock. Source review also revises the proposed fast-write follow-on: `fpga_spi` waits for both ACK high and ACK low, and this core's input FIFO full signal controls that acknowledgement through `ioctl_wait` and `sys_top`; `spi_block_write` omits those waits and also lacks the wide-mode odd-byte tail handling of `spi_write`. It must not be substituted blindly. Absence of helper-pipe EAGAIN does not prove absence of FPGA backpressure. The logged first-byte latency of 45,532 microseconds is actually assertion to first completed chunk because logging follows transmission, so it includes the larger chunk's transfer time. The 185 counter counts delayed presentation intervals, not every missed frame slot. Last-three-read spans inside individual polls have a 33.772-millisecond median and 67.404-millisecond maximum, establishing exposure to UI service delays but not a measured UI response. No production source, deployed binary, configuration or lifecycle was changed. Capture, full decode, helper log, fixture analysis, comparisons and source-review limitations are retained in the five entry-581 evidence files under `.ai/current_results`; the media readback occurred after the completed cold test and warms cache for subsequent non-rebooted playback.

#### Next Steps:

Obtain approval for a bounded host-transfer profiling and safe optimization cycle rather than raising the buffer again or replacing acknowledged writes with unchecked fast writes. Measure pipe read and transfer durations separately at chunk boundaries, sampled ACK-loop statistics and actual poll or UI service duration without per-word logging, then distinguish bridge overhead from FIFO wait before choosing a correction that preserves backpressure, byte order and odd-tail handling. Any subsequent host-system-binary deployment requires explicit approval, retained restoration data and verified staged replacement plus full readback; standing RBF permission does not cover it. Ask whether the interface remained responsive during this run, and retain one qualified 8 Mbps fixture regression as outstanding rather than assuming it passed. Respect one run per changed circumstance. Keep FPGA startup, the 64-KiB clean-video queue, continuous HDMI sync and black startup background unchanged; analog work remains excluded and the previously recorded interlaced, audio, cancellation and assertion-drift limitations remain unresolved. Preserve `core.md` and the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 580 COMMIT Unreleased ad364bf 2026-08-27T01:06:04-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Record the current state, findings and outstanding validation for an agent handover requested by the user.

#### Outcome:

The current source is `ad364bf`, built and deployed but not yet hardware-validated. The FPGA bitstream was not rebuilt at any point in this cycle: the qualified `2acabc5` image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains installed at `/media/fat/MediaPlayer.rbf`, and every change since has been host-side. The deployed `/media/fat/MiSTer` is `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`, 1,166,244 bytes, verified by full readback on a fresh connection. Three restore points are retained under `/home/vash/mister-builds/entry573-deced5c/`: the pre-instrumentation original `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`, the instrumented `deced5c` build `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, and the current one; restoration is a single FTP upload. This cycle began from a report that repeated playback ran slowly and ended by locating the delivery ceiling in source. The established mechanism is that `mediaplayer_poll()` in `host/main_mister/0001-mediaplayer-arm-loader.patch` moved at most four chunks of 4,096 bytes per poll at an implied 86.2 to 86.7 polls per second, and that budget matched measured delivery to about a hundredth of a percent across three independent measurements spanning two files whose demands differ by 2.3 times and both thermal states. The cap binds because the helper always has data ready: in every log examined, every would-block event carries a submitted count of zero and precedes the first byte, and the parent never sees EAGAIN during steady delivery. The qualified 15,150,646-byte file demands 1,010,157 bytes per second and so had roughly 1.4 times headroom, leaving only startup at risk, while the 34,919,166-byte file demands 2,330,798 and was throttled to 18.2 frames per second with 187 to 188 missed deadlines across two runs; warming that file halved its blocked polls and cut 9.2 milliseconds of first-byte latency yet moved delivery by 0.6 percent and changed nothing else, which cleanly separates read latency, governing startup only, from the per-poll budget, governing steady throughput. Four earlier conclusions in this log were corrected by later evidence and a handover must not re-adopt them: entry 568's prefill-depth framing, the accepted-bytes release gate floated around entry 569 and disproved by its own capture 5, entry 571's claim that the cold feed runs at 0.94 times realtime, which was an averaging artefact hiding a late start rather than a slow feed, and entry 572's twin claims that warm dead time is zero, since it is about 8.3 milliseconds once the burst rate is measured rather than derived, and that the per-poll budget could be ruled out, which entries 577 and 578 contradict by direct measurement. One important negative result stands unexplained: measured first-byte latency does not predict whether a cold run gaps, since 37.6 milliseconds was clean while 21.9 and 35.3 gapped and 68 gapped twice, so phase alignment between byte arrival and the early cadence deadline remains the leading hypothesis and no counter measures it. On the qualified file, cold boot plays perfectly about half the time, two clean against two gapped among strictly verified cold boots and three gapped counting the unverifiable entry 568, and a failure costs one or two dropped frames inside the first 270 milliseconds with steady-state cadence nominal in every session ever measured. A project-level consequence should not be lost: the old ceiling of about 1.41 megabytes per second left only twelve percent headroom over DVD peak program-stream rate of about 1.26, which is less than startup dead time already consumes and excludes audio demultiplexing. Practical notes for the successor: the MiSTer is at 10.10.0.30 over ordinary FTP with the default credentials, its clock runs UTC against the project's America/Phoenix local time, `/tmp/MediaPlayer_ARM.log` is rewritten per playback and must be fetched before any replay, and reboots must be verified from `/tmp/messages` rather than from recollection because the reported procedure has contradicted the device twice, a core reload being mistaken for a Linux reboot. The capture path was itself controlled: six consecutive probes of a static screen returned byte-identical images. The polling capture scripts lived in an ephemeral session scratchpad and would need rewriting; `tools/streams/read_hardware_cadence.py` and `decode_hardware_cadence.py` remain the committed tools. Note also that this agent ran on GUNSMOKE rather than the Raspberry Pi, so the `core.md` response-loop LED steps were inoperative and pushes were made from the build PC contrary to the stated convention.

#### Next Steps:

Resume at the pending validation, which the user has already been asked to perform: power-cycle, play `bbb_480i_tff_15s.m2v` once and stop, then fetch `/tmp/MediaPlayer_ARM.log` before the cadence screenshot. Confirm first that the per-read `count` field reports 16,384 rather than 4,096, which is the only available runtime proof that the buffer change took effect, since a stack allocation cannot be verified by string extraction in a stripped image. Then derive the poll rate from read count divided by four divided by elapsed span and treat it as the discriminating measurement: a rate holding near 86 Hz means the ceiling has risen toward 5.7 megabytes per second and the delivered frame rate should climb toward 29.97 with the missed-deadline count collapsing, whereas a rate falling proportionally toward 22 Hz means the read-back word loop dominates and the buffer size was not the operative constraint. In that second case the identified follow-on is already characterised: `spi_write` calls `spi_w`, which resolves to `fpga_spi` and performs a bridge read-back per sixteen-bit word, while `spi_block_write` wraps `fpga_spi_fast_block_write`, which issues two posted writes per word with no read-back and is already used by the IDE, x86, CDTV and Akiko paths; propose that as a separate approved boundary rather than adopting it silently. Also replay the qualified 15,150,646-byte file once to confirm the change has not disturbed previously accepted behaviour, and ask the user whether interface responsiveness has degraded, since a longer `mediaplayer_poll` delays `HandleUI`, `OsdUpdate` and `input_poll` in the same free-running main loop and that cost was never bounded in advance. Respect the user's diagnostic cadence, which is one run per circumstance rather than repeated samples for statistics; design each hardware request as a single run changing one condition and say what it would discriminate. Do not restore the per-poll budget ruling-out from entry 572, do not revive the accepted-bytes release gate, and do not change the FPGA startup controller, the 64-KiB clean video queue, the continuous HDMI sync fix or the black startup background. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain unsupported or unresolved. Keep `core.md` unchanged and preserve the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 579 COMMIT Unreleased ad364bf 2026-08-27T01:01:12-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Raise the bytes moved per poll in `mediaplayer_poll()` by enlarging the read buffer from 4,096 to 16,384 bytes so the measured delivery ceiling rises above the rate a high-bitrate stream demands.

#### Outcome:

The approved plan is committed as `ad364bf`, built and deployed. Entries 577 and 578 established by three independent measurements that delivery is capped at four chunks of 4,096 bytes per poll at an implied 86.2 to 86.7 polls per second, matching measured throughput to about a hundredth of a percent each time, and that the cap binds because the helper always has data ready and the parent never sees EAGAIN during steady delivery. The change enlarges the buffer to 16,384 bytes while leaving the chunk count at four, which raises the arithmetic ceiling from about 1.42 to about 5.7 megabytes per second and moves the same bytes in a quarter as many read and transmit calls. Two checks were made before proposing it. `user_io_file_tx_data` performs no internal chunking, consisting only of `EnableFpga`, a command byte, `spi_write` and `DisableFpga`, so larger blocks are accepted and the per-call FPGA framing is amortised rather than repeated. The main loop in `main.cpp` is free-running with no sleep, calling `user_io_poll`, `frame_timer`, `input_poll`, `HandleUI` and `OsdUpdate` in sequence, so the poll rate is set by how long that work takes rather than by a timer, and spending longer in `mediaplayer_poll` necessarily slows every other item. That is the principal risk and it is not eliminated by this change, only bounded and measured. The relevant cost is that `spi_write` is a word-at-a-time loop calling `spi_w`, which resolves to `fpga_spi` and performs a read-back per sixteen-bit word, stalling on the HPS-to-FPGA bridge each time, so 4,096 bytes costs 2,048 bridge round trips and a full poll costs 8,192. Enlarging the buffer quadruples the bytes per poll but also quadruples that word-loop time, so the net gain depends on what fraction of the 11.5-millisecond poll period that loop currently occupies, which has not been measured. This makes the change a discriminating experiment as well as a correction: the instrumentation added in `deced5c` reports read counts and elapsed time, from which the poll rate is derived directly, so if the rate holds near 86 Hz the ceiling rises toward 5.7 megabytes per second, whereas if it collapses proportionally toward 22 Hz the word-loop dominates and the buffer size is not the operative constraint. In that second case the identified answer is already in hand and would be proposed separately: `spi_block_write` wraps `fpga_spi_fast_block_write`, which issues two posted register writes per word with no read-back, and it is already used for bulk transfers by the IDE, x86, CDTV and Akiko paths, while `user_io_file_tx_data` alone still uses the slow read-back loop. That change is deliberately not made here because it alters the FPGA transfer path rather than a local buffer size. No FPGA rebuild is required and the qualified `2acabc5` bitstream with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` is unaffected. Deployment replaces the host-side MiSTer main binary again, and both prior binaries are retained for restoration, the pre-instrumentation original and the `deced5c` instrumented build, under `/home/vash/mister-builds/entry573-deced5c/`. The change is a single line, the buffer declaration in `mediaplayer_poll()`, and the hunk line count is unchanged at 304. `git apply --check` accepted it against pinned Main_MiSTer commit `0a8fb44` and the build completed with ARM GNU 10.2.1 20201103 reporting no errors, producing a 1,166,244-byte stripped ARM EABI5 binary with MD5 `295a3f2473360c46f4b946922fc1cbc2` and SHA-256 `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`. Because the buffer is a stack allocation in a stripped image its size cannot be confirmed by string extraction, so verification is deferred to runtime, where the instrumented log's per-read `count` field must report 16,384 rather than 4,096. Deployment followed the established procedure and additionally confirmed before overwriting that the target held exactly the retained `deced5c` restore point rather than an unrecorded state. The staged upload was hash-verified before the rename and the active path was then read back in full over a fresh connection, returning 1,166,244 bytes with the matching SHA-256 and leaving no staging file. Three restore points are now retained under `/home/vash/mister-builds/entry573-deced5c/`: the pre-instrumentation original with SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`, the instrumented `deced5c` build, and this one.

#### Next Steps:

Build with MiSTer's official ARM GNU 10.2 toolchain, never the distribution cross-compiler, confirm the patch applies cleanly to pinned Main_MiSTer commit `0a8fb44`, and deploy host-side with the existing staged-upload, verify, rename and full-readback procedure. Validation is a single replay of `bbb_480i_tff_15s.m2v`, whose 2,330,798 bytes per second demand exceeded the old ceiling and produced 187 to 188 missed deadlines at about 18.2 frames per second across two runs. Read the helper log first and derive the poll rate from read count and elapsed span, then compare measured delivery against the new budget arithmetic of four chunks of 16,384 bytes at the observed rate. Success is delivery above the file's demand with the delivered frame rate rising toward 29.97 and the missed-deadline count collapsing; a poll rate that falls proportionally instead indicates the read-back word loop dominates and moves the boundary to `spi_block_write`. Also confirm on the qualified 15,150,646-byte file that the change has not disturbed the previously accepted behaviour, and watch for any user-visible loss of interface responsiveness, since a longer `mediaplayer_poll` delays `HandleUI`, `OsdUpdate` and `input_poll` in the same loop. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 578 COMMIT Unreleased deced5c 2026-08-27T00:56:47-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Replay the larger file warm to test entry 577's recorded prediction that page-cache warming would not relieve a stream whose demand exceeds the per-poll delivery ceiling.

#### Outcome:

No power cycle preceded this run and the syslog still shows the single 07:41:02 UTC boot, so the page cache retained the larger file from entry 577. The prediction recorded before the run is confirmed on every term. Delivery was predicted at about 1,412,000 bytes per second and measured 1,420,655, a change of 0.6 percent; the delivered rate was predicted near 18.1 frames per second and measured 18.2343; the missed-deadline count was predicted to remain in the same order as 188 and measured 187; and first-byte latency was predicted to fall and did, from 23,749 to 14,560 microseconds. The warming itself is unmistakable and behaved exactly as page-cache warming should, halving the blocked polls that precede the first byte from 384 to 185 and cutting 9.2 milliseconds from first-byte latency, yet none of that reached the outcome. The session still accepts all 34,919,166 bytes and displays 449 pictures with 448 swaps at zero error flags, still runs 24.57 seconds for 15.0 seconds of content, and still shows its three largest gaps at 12,012,000, 10,010,000 and 10,010,000 cycles around ordinals 93 to 96. The separation this establishes is clean and is the point of the run: read latency governs startup only, and the per-poll budget governs steady throughput, so warming a file that demands more than the ceiling changes when playback begins and nothing about how it proceeds. The delivery arithmetic closes for a third time. This run implies 86.7 polls per second against 86.2 in entry 577, and four chunks of 4,096 bytes at 86.7 Hz is 1,420,791 bytes per second against a measured 1,420,655, agreeing to 0.010 percent. Across three independent measurements now, spanning two files whose demands differ by a factor of 2.3 and two thermal states, the implied poll rate sits between 86.2 and 86.7 Hz and the four-chunk budget arithmetic matches measured delivery to about a hundredth of a percent each time. The delivery ceiling is therefore established as a property of the per-poll budget rather than of the media, the filesystem, the helper or the FPGA, and entry 572's ruling-out of that candidate, already corrected in entry 577, is now contradicted by direct measurement under two thermal conditions. One risk remains entirely unassessed and must gate any correction: `mediaplayer_poll()` is called from `user_io_poll()`, so spending longer inside it delays every other responsibility of the MiSTer main loop, and nothing in this work has examined what that costs. Per the user's diagnostic cadence this is one run per condition, only three of the 187 deadline records are retained by the snapshot, and the poll rate is still inferred from read counts and elapsed time rather than measured inside MiSTer main. Evidence is `.ai/current_results/entry578_bigfile_warm_arm_helper.log`, `entry578_bigfile_warm_terminal.png` and `entry578_bigfile_warm_capture.json`.

#### Next Steps:

Seek user approval for a bounded delivery-side change before implementing it. The proposal is to raise the bytes moved per poll in `mediaplayer_poll()` within `host/main_mister/0001-mediaplayer-arm-loader.patch` by enlarging the read buffer from 4,096 to 16,384 bytes while leaving the chunk count at four, which raises the ceiling from about 1.42 to about 5.7 megabytes per second and, because it moves the same bytes in a quarter as many read and transmit calls, should reduce rather than increase the per-byte time spent in the function. Size the target against DVD peak program-stream rate of 10.08 Mbps or about 1.26 megabytes per second with real margin rather than against this one test file, since the present twelve percent headroom over DVD peak is less than startup dead time already consumes. Before proposing the edit, examine whether `user_io_file_tx_data` accepts larger blocks without internal chunking that would negate the benefit, and estimate the added worst-case time per `user_io_poll` call against whatever else that loop must service, because that is the principal risk and is currently unexamined. No Quartus build is required and the qualified `2acabc5` bitstream is unaffected. Validation would be a single replay of this same larger file, checking measured delivery against the new budget arithmetic and confirming the delivered frame rate rises toward nominal. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 577 COMMIT Unreleased deced5c 2026-08-27T00:53:02-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Play the higher-bitrate `bbb_480i_tff_15s.m2v` once to test whether the startup defect is delivery-bound.

#### Outcome:

The larger file is 34,919,166 bytes against 15,150,646 for the qualified file, carrying the same 449 pictures of the same 29.97 fps content at roughly 2.3 times the bitrate. No power cycle preceded this run; the syslog still shows the single 07:41:02 UTC boot, so it followed the entry 575 cold run on the same uptime. The user reports it played a lot slower, and the telemetry agrees emphatically. The session records 188 cadence outliers and 188 missed deadlines against the zero to two seen on the qualified file, a delivered rate of 18.1195 frames per second against a nominal 29.9700, and a cadence span of 1,483,483,716 cycles or 24.72 seconds for content that should occupy 15.0. The three largest gaps are 12,012,000, 10,010,000 and 10,010,000 cycles at ordinals 94, 93 and 95, six and five nominal intervals respectively, and the misses are spread through the session rather than confined to startup. The file nonetheless plays correctly and completely, accepting all 34,919,166 bytes, displaying all 449 pictures with 448 swaps, reaching sequence end and presentation completion with a quiet terminal and zero error flags; it is throttled, not corrupted. The instrumented helper log closes the mechanism completely. Delivery ran flat at the ceiling for the whole session, with segment rates between 1,393,653 and 1,442,109 bytes per second from 199 milliseconds through 24.7 seconds and no burst-then-decay shape, because demand exceeds supply throughout rather than only at startup. The whole-session delivery rate is 1,412,269 bytes per second across 8,526 reads. Dividing those reads by the four-chunk budget gives 2,132 polls over 24.726 seconds, an implied poll rate of 86.2 Hz, and four chunks of 4,096 bytes at 86.2 Hz is 1,412,404 bytes per second, agreeing with the measured delivery to 0.01 percent. The stream demands 2,330,798 bytes per second, giving a deficit ratio of 0.6059, and the observed frame rate ratio of 18.1195 over 29.9700 is 0.6046, agreeing to 0.2 percent. Playback is therefore throttled to exactly the delivery deficit. As before, all 384 would-block events carry a submitted count of zero and precede the first byte, so the helper always had data ready and the parent never saw EAGAIN during steady delivery, confirming that the parent's per-poll budget rather than the helper or the filesystem is the binding constraint. This corrects entry 572, which concluded that raising the four-chunk per-poll budget would not correct anything because steady throughput was never the limiting quantity, and listed that candidate as ruled out. That conclusion holds only for the qualified file, whose 1,010,157 bytes per second demand sits below the ceiling; it is false in general, and for any stream above roughly 1.41 megabytes per second the per-poll budget is precisely what throttles playback. A project-level consequence follows and should not be buried. The measured ceiling of about 1.41 megabytes per second is marginal for the stated long-term goal of commercial DVD playback, since DVD peak video bitrate is 9.8 Mbps or about 1.225 megabytes per second and a full program stream may reach 10.08 Mbps or about 1.26, leaving roughly twelve percent headroom, which is less than the startup dead time already consumes and takes no account of audio demultiplexing. Only three of the 188 deadline records are retained by the snapshot, at ordinals seven, eight and nine, and the 86.2 Hz poll rate remains inferred from read counts and elapsed time rather than measured inside MiSTer main, though it now agrees across two files with very different demands. Whether raising the per-poll budget is safe with respect to MiSTer main's other responsibilities has not been assessed and is not proposed here. Evidence is `.ai/current_results/entry577_bigfile_arm_helper.log`, `entry577_bigfile_terminal.png` and `entry577_bigfile_capture.json`.

#### Next Steps:

The user intends one further run of the same larger file, which is now a genuine test rather than a repeat, because the page cache holds the file after this run while the constraint identified here is the per-poll budget and not read latency. The prediction to be recorded before that data arrives is that warming will change nothing material: first-byte latency should fall from its 23,749 microseconds toward the warm baseline, but the delivery rate should stay near 1,412,000 bytes per second, the delivered frame rate should stay near 18.1 and the missed-deadline count should remain in the same order. If instead the warm run recovers substantially, the per-poll budget is not the whole constraint and this entry's arithmetic is wrong somewhere. After that, propose a bounded delivery-side change for approval rather than implementing it: raise the per-poll chunk count or the buffer size in `mediaplayer_poll()` within `host/main_mister/0001-mediaplayer-arm-loader.patch`, sized against DVD peak program-stream rate with real margin rather than against this one test file, and assess first whether spending longer in that function starves MiSTer main's other per-poll work, which is the obvious risk and has not been examined. That change would need no Quartus build and would be validated by replaying this same larger file and checking the delivery rate against the new budget arithmetic. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 576 COMMIT Unreleased deced5c 2026-08-27T00:48:31-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Record the user's revised diagnostic cadence and state the cold-boot behaviour of `2acabc5` as it currently stands.

#### Outcome:

The user has cut the diagnostic cadence and this supersedes the Next Steps of entry 575, which proposed collecting six to eight paired latency and outcome samples. That plan is withdrawn. Their instruction is that going forward the file is run once under different circumstances rather than repeatedly under the same one, on the grounds that each sample costs a manual power cycle, core load and playback and that varying the condition returns more per run than repeating it. Future hardware requests must therefore be designed as a single run that changes one condition and must state what that one run would discriminate; if a conclusion genuinely requires repetition, say so and let the user decide rather than scheduling the repeats. The user also asked directly whether the file plays perfectly on a cold boot, and on the present evidence it does not, though the defect is narrow. Across strictly verified cold boots, where the power cycle was confirmed from `/tmp/messages` or from a live FTP dropout rather than from recollection, block 1 run 1 and block 3 run 1 gapped with one and two missed deadlines while entries 572 and 575 were clean, giving two clean and two gapped; entry 568 also gapped but its reboot predates the syslog that was later checked and cannot be verified, which would make it three gapped of five. Cold boot therefore plays perfectly roughly half the time. What a failure costs is one or two dropped frames inside the first 270 milliseconds at display picture ordinals five and six, and nothing after. In every session ever measured, gapped or clean, the second and third ranked display gaps are exactly 2,002,000 cycles, so steady-state cadence past the startup region is nominal without exception, and every run completes with all 15,150,646 bytes accepted, 449 pictures, 448 swaps and zero error flags. Warm replays are clean in every sample except the block 1 series, where the media was still warming across successive runs. No source change, build or deployment was made for this entry. The installed FPGA image remains the qualified `2acabc5` bitstream with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`, and the installed host binary remains the instrumented `deced5c` build with SHA-256 `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, whose pre-deployment backup is held at `/home/vash/mister-builds/entry573-deced5c/`.

#### Next Steps:

Await the user's choice of the next single circumstance to test rather than proposing a sampling programme. The open question is unchanged and is stated in entry 575: measured first-byte latency does not predict whether a cold run gaps, since 37.6 milliseconds was clean while 21.9 and 35.3 milliseconds gapped, so phase alignment between byte arrival and the early cadence deadline remains the most likely operative variable and no current counter measures it. The single most discriminating circumstance available without a new build is playing the higher-bitrate `bbb_480i_tff_15s.m2v`, which is 34,919,166 bytes against 15,150,646 for the qualified file and therefore demands about 2,327,944 bytes per second, well above the 1,443,000 bytes per second burst rate measured in entry 575. If the defect is delivery-bound that file should fail consistently and severely rather than intermittently, and if it plays as well as the smaller file then delivery rate is not the operative constraint and the boundary moves to the FPGA side. Do not deploy the helper-side priming correction, which entry 575 showed is not yet justified. Do not raise the per-poll chunk budget. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

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

