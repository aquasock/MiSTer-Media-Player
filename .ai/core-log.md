## 992 COMMIT Unreleased ??? 2026-09-05T00:01:53-07:00

#### Coming From:

Unreleased 22b0a98

#### Purpose:

Replace the rejected title reserve drain with DVD Program Stream SCR fallback scheduling for sparse-video-PTS intervals.

#### Outcome:

The approved boundary will remove only source `22b0a98`'s ordinary-title prompt-drain behavior while retaining source `50c410a`'s bounded future-video-PTS lookahead.  The physical DVD demux will parse each MPEG-2 pack header's complete 27-MHz System Clock Reference instead of discarding it, normalize its 33-bit base and 9-bit extension across wrap and DVD navigation epochs, and use that authored multiplex clock only when it has advanced beyond the ordinary title's stale video-PTS horizon.  Video PTS remains the primary scheduler authority, SCR cannot run during menus or non-DVD Program Streams, host wall time remains excluded, exact video and PCM payload order remains unchanged, and malformed marker, extension or discontinuity state will fail or reset conservatively rather than invent timing.  Main, the protocol, RTL and the RBF will not change.

#### Next Steps:

Implement focused production-path regressions for MPEG-2 pack-header decoding, 27-MHz fractional SCR progress, multi-second sparse-video-PTS PCM continuity, normal advancing-video-PTS precedence, backward discontinuity rebasing, navigation reset, menu and non-DVD exclusion, byte-exact video and exact PCM reconstruction.  Run strict optimized, analyzer, AddressSanitizer, UndefinedBehaviorSanitizer and repeated DVD scheduler coverage plus retained DVD navigation, Program Stream seek, reserve, stage, audio, visualizer and Main contract integrations, then produce two identical stripped static GNU 10.2.1 ARMv7 helpers for a Simpsons and Futurama hardware comparison without rebuilding the RBF.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [ ] Built
- [ ] Passed

---

## 991 COMMIT Unreleased 22b0a98 2026-09-04T23:57:03-07:00

#### Coming From:

Unreleased 22b0a98

#### Purpose:

Evaluate prompt title-PCM delivery on the failing Simpsons title and determine whether the asynchronous helper reserve causes its persistent cutouts and desynchronization.

#### Outcome:

The physical source-`22b0a98` run rejects prompt title-PCM delivery as a playback correction: the user reports that audible cutouts remain and A/V desynchronization is unchanged.  Both `DVD title PTS lookahead activated` and `DVD title PCM prompt delivery activated reserve=4194304 batch=2048` occur, proving that the intended helper path ran and that the four-MiB asynchronous reserve was synchronously drained before scheduled title PCM.  Nevertheless, the checksum-valid schema-22 snapshot remains effectively the prior Simpsons state at its internally frozen 30.000-second epoch: 25,214,024 accepted bytes, 730 displayed pictures and 729 swaps at 24.366 pictures per second, 1,339,712 audio-domain dequeues or 27.910667 seconds, 66 candidate-unavailable, 994 cadence-blocked and zero timestamp-blocked windows, 1,464,734,399 decoder-stall cycles, and one sticky underrun with FIFO floor zero.  The user's later telemetry invocation does not extend these counters because the overlay snapshot itself is bounded at exactly 1,800,000,000 60-MHz session cycles.  More importantly, the continuing helper log exposes a 2.558400-second interval from Main diagnostic time 156.447116 to 159.005516 with no pipe read: across the surrounding 3.128651 seconds, emitted PCM advances only 24,064 frames or 0.501333 seconds and maximum video PTS advances only 55,556 ticks or 0.617289 seconds despite 82,304 held PCM frames and 155,923 queued video bytes.  The scheduler's wall-time deficit therefore jumps from 64,514 frames, 1.344042 seconds, to 190,625 frames, 3.971354 seconds and remains about 3.9 seconds through the final 53.277553-second sample.  This reproduces the Simpsons-specific sparse-video-PTS drought after removing reserve latency: prompt delivery cannot create timestamp authority, and a helper wall-clock substitute was already physically rejected because it lets audio run ahead of actual video presentation.  The 3,649,656-byte log, 457,475-byte screenshot and 818-byte telemetry sidecar have SHA-256 `aec8690ffa0122e4107ba832041cf69e4537b3ca34e7a8635e28b743af7999ec`, `af7483f0356d51061a7850f2fce895a8403d1d220d36fc0906292bbc76335fac` and `c87ac03de6310f9ff7da07bc536f67c1fa78bb460d641b719fb1cbc1a63c779d`.

#### Next Steps:

Do not rebuild or change the RBF.  Treat the four-MiB prompt-drain experiment as disproven and do not stack another host timing heuristic on it.  After user approval, revert only source `22b0a98`'s title prompt-delivery change while retaining source `50c410a`'s bounded future-PTS lookahead, then rebuild only the static ARM helper to restore the smaller accepted change.  The remaining Simpsons defect cannot be robustly corrected by helper scheduling alone: the source offers no advancing video timestamp during the multi-second drought, while the helper has no feedback for actual FPGA video presentation, and the previously tested wall clock advances audio independently and worsens drift.  With the user's no-RBF constraint, retain the working helper baseline for other DVDs and document Simpsons as a disc-specific limitation unless a future explicitly approved emergency implements presentation-aware A/V coordination and three-seed RBF qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 990 COMMIT Unreleased 22b0a98 2026-09-04T21:15:32-07:00

#### Coming From:

Unreleased 50c410a

#### Purpose:

Deliver PTS-authorized ordinary-title PCM promptly instead of allowing the asynchronous DVD output reserve to hide it behind seconds of older video.

#### Outcome:

Source `22b0a98` drains the physical-DVD asynchronous output reserve immediately before every PTS-authorized ordinary-title PCM batch, reusing the prompt-delivery primitive already established for automatic-menu clocked batches.  Earlier transport bytes still drain first and later video remains behind the PCM records, while the cumulative video-PTS target, 8,192-frame startup reserve, bounded future-PTS queue, eight-MiB source producer ring, menu activation staging and navigation behavior remain unchanged; no title wall clock or priority reordering was introduced.  The production translation-unit regression fills the complete four-MiB reserve behind a delayed backpressured pipe, proves the PCM call waits for prior reserve output, then compares every prior video byte, 2,048 PCM frames and later video byte in exact order.  Strict optimized, AddressSanitizer, UndefinedBehaviorSanitizer and focused analyzer builds pass, as do twenty prompt-delivery scheduler repetitions, retained DVD random-access, SPU, AC-3, Program Stream seek, reserve, stage, CDDA, audio UI, visualizer, private-audio, Main contract and real MP3, WAV, FLAC and Ogg seek integrations.  Two GNU 10.2.1 hard-float ARMv7 builds are identical and produce the 982,436-byte stripped static `host/build/MediaPlayer_Helper` with SHA-256 `723f8f151e26591e442ba4d81d18c7591e4b387a5fb3f1441b4ce51fa9631806`; it has no interpreter or dynamic section.  Main, the protocol, RTL and the RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper`, preserving executable mode; retain the installed Main and RBF.  Enable telemetry and repeat the same Simpsons route through both authored menus and the first episode for at least thirty seconds, requiring both `DVD title PTS lookahead activated` and `DVD title PCM prompt delivery activated` in the log; return the fresh log, screenshot and telemetry sidecar together with the direction and approximate amount of any remaining lip-sync error and every audible cutout.  Then spot-check Futurama to ensure its accepted playback remains okay; do not rebuild the RBF.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 989 COMMIT Unreleased 50c410a 2026-09-04T21:13:18-07:00

#### Coming From:

Unreleased 50c410a

#### Purpose:

Evaluate bounded title PTS lookahead on the failing Simpsons disc and localize the remaining audio delay and cutouts.

#### Outcome:

The physical source-`50c410a` run validates the new lookahead mechanism but does not pass playback acceptance: Futurama remains okay, while the user reports that Simpsons still has delayed audio and two audible cutouts, although the cutouts appear improved.  The title records one `DVD title PTS lookahead activated` marker and its scheduler samples retain approximately 4,048 to 417,463 queued video bytes with 57,856 to 94,848 held PCM frames, eliminating the prior capture's repeated zero-video horizon.  At a nearly byte-aligned thirty-second schema-22 point, however, the displayed state remains 732 pictures and 731 swaps at 24.411 pictures per second, with 60 candidate-unavailable, 998 cadence-blocked and zero timestamp-blocked windows, and the pending candidate remains exactly 206,487 ticks or 2.294300 seconds late.  FPGA audio consumption improves by only 10,374 frames or 216.125 milliseconds to 1,342,847 frames, 27.975979 seconds, while the matching helper progress record has already emitted 1,553,280 frames; 210,433 emitted frames or 4.384021 seconds therefore remain upstream of the PCM sink in the shared reserve, pipe and transport rather than in the helper's decoded-audio hold.  The helper's output reserve can carry four MiB of earlier interleaved video, so preserving a future PTS does not by itself make a newly scheduled PCM batch reach Main or the FPGA promptly when the Simpsons decoder applies sustained backpressure.  The sticky underrun remains set with FIFO floor zero and cannot count the user's two distinct events.  The 4,658,629-byte log, 608,901-byte screenshot and 831-byte telemetry sidecar have SHA-256 `d51bfeaaf8eed09652c06ee1b112f156c5f784b3566c4cea4ef5bcd061d0009e`, `d15e4a0756856e40ae9aee1c6ea3e58d2f86ecd202cccef19f4aeed7a7544eb3` and `27dd01a5ce8fc0bf48940531c4b4502e42a1aad85057015b9030b7cab2b83ae9`.

#### Next Steps:

Do not rebuild or change the RBF.  After user approval, make the next boundary helper-only: before each PTS-admitted ordinary-title PCM batch, drain the physical-DVD asynchronous output reserve as the accepted automatic-menu pacing path already does, so scheduled samples cannot remain behind seconds of older compressed video; retain the future-PTS queue, cumulative PTS authority, exact stream order, startup reserve, menu behavior and the physical source producer ring.  Add a production regression with a full four-MiB stalled output reserve that proves each scheduled PCM batch reaches the downstream writer before later video, retains bounded optical buffering, and converges without advancing audio independently of video PTS, then rebuild only the static ARM helper and repeat Simpsons plus Futurama.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 988 COMMIT Unreleased 50c410a 2026-09-04T18:11:54-07:00

#### Coming From:

Unreleased f597cb1

#### Purpose:

Retain bounded future video-PTS lookahead so audio-forward DVD multiplexing cannot starve scheduled PCM behind a stale video horizon.

#### Outcome:

Source `50c410a` makes the ordinary DVD title scheduler retain exactly one advancing timestamped video chunk in its existing bounded two-MiB queue, allowing an audio-forward Program Stream to reveal the next PTS horizon before the preceding video is admitted.  Untimestamped bytes before that future chunk still use the established interpolated horizon, while a second advancing PTS releases the prior one and decoded PCM remains governed only by the cumulative video-PTS target plus the existing 8,192-frame startup reserve; no title wall clock was restored.  EOF, authored stills and resident menu continuations force exact completion, and timestamp-poor input reaching queue pressure takes an explicit bounded full drain.  The new production-translation-unit regression models six Simpsons-shaped half-second horizons behind 144,000 held PCM frames, proves the modeled 48 kHz sink retains 8,064 to 8,192 frames of reserve, verifies one future PTS remains queued, exercises timestamp-free pressure and compares every video byte and emitted PCM sample exactly.  Strict optimized, AddressSanitizer, UndefinedBehaviorSanitizer and focused analyzer builds pass, as do twenty scheduler repetitions, the retained DVD random-access, SPU, AC-3, Program Stream seek, reserve, stage, CDDA, audio UI, visualizer, private-audio, Main contract and real MP3, WAV, FLAC and Ogg seek integrations.  Two GNU 10.2.1 hard-float ARMv7 builds are identical and produce the 982,436-byte stripped static `host/build/MediaPlayer_Helper` with SHA-256 `604261b240355d62dc406ff11e5ef7dee738f849009b85c2ee8ed2c01633c6d6`; it has no interpreter or dynamic section.  Main, the protocol, RTL and the RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper`, preserving executable mode; retain the installed Main and RBF.  Enable telemetry, repeat the same Simpsons route through both authored menus and the first episode for at least thirty seconds, and return the fresh log, screenshot and telemetry sidecar together with whether startup stutters or progressive desynchronization remain.  The log should contain one `DVD title PTS lookahead activated` marker during ordinary title playback.  Then spot-check the Futurama title to confirm its naturally balanced multiplex remains nearly synchronized; do not rebuild the RBF.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 987 COMMIT Unreleased f597cb1 2026-09-04T18:09:25-07:00

#### Coming From:

Unreleased f597cb1

#### Purpose:

Compare the nearly synchronized Futurama title against the failing Simpsons title and identify the disc-level property that exposes the host scheduler.

#### Outcome:

The source-`f597cb1` Futurama run proves the Simpsons failure is not a general RBF format or clock defect.  Both titles enter 720-by-480 NTSC MPEG-2 with frame-rate code four, the same interlaced-sequence and progressive-picture repeat-field startup form, and 48 kHz AC-3, while Futurama actually supplies more compressed data in the thirty-second snapshot.  Their decisive difference is delivery shape: Simpsons scheduler samples retain approximately 62,000 to 86,000 already-decoded PCM frames while queued video repeatedly reaches zero, whereas Futurama has zero median held PCM, a maximum of only 5,248 frames and 121,559 bytes of median future video queue.  Futurama consequently dequeues 1,427,422 PCM frames or 29.737958 seconds during its first thirty seconds, against Simpsons' 27.759854 seconds, and has only 29 candidate-unavailable presentation windows against 60.  Simpsons is also costlier to decode despite accepting fewer bytes: its 1,465,925,354 stall cycles are 58.012 cycles per accepted byte against Futurama's 40.110, about 44.6 percent higher, and its 201 B pictures consume about 32.8 percent more B-stall cycles per picture than Futurama's 200.  Futurama still records one startup FIFO starvation and transient display gaps, matching the user's report that synchronization drifts slightly and returns, but over 171.937972 seconds its PCM and video-PTS progress differ by only 0.117078 seconds and its one DVD PTS discontinuity is normalized without failure.  This combination identifies Simpsons as an audio-forward or more burstily multiplexed Program Stream paired with higher-cost pictures: the helper drains after every PES and repeatedly loses future video-PTS lookahead, so it holds abundant decoded AC-3 behind a stale video horizon while the small FPGA FIFO empties and the slower picture path intermittently lacks a candidate.  The 5,990,963-byte log, 339,121-byte screenshot and 857-byte telemetry sidecar have SHA-256 `ed7e004c1fa255b00a3b4c50a8b9a398ffa3217765d1067976ba8330b34c8947`, `d8ce7c087649c578cfe683794304e41cf28429a17c31982ab5ccd836b5f27660` and `2956e7b1362b3058474aa95817743229c963331b2cdb8cf9ceafd38de285872b`.

#### Next Steps:

Keep the installed RBF and all RTL unchanged.  After user approval, make the next boundary helper-only: retain a bounded future video-PTS horizon across PES packets instead of draining the video queue immediately after each packet, so an audio-forward mux such as Simpsons can schedule its already-decoded PCM smoothly without using host wall time or changing the cumulative PTS-derived rate.  Add production-path fixtures that alternate long AC-3-forward regions with sparse, expensive video PES timestamps and model a 48 kHz 16,384-frame sink, prove no startup starvation, bounded queues, exact elementary-stream bytes and convergence after burst timing, then build only the static ARM helper for comparative Simpsons and Futurama tests; do not build or modify an RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 986 COMMIT Unreleased f597cb1 2026-09-04T17:56:01-07:00

#### Coming From:

Unreleased f597cb1

#### Purpose:

Evaluate schema-22 on the repeated Simpsons title run and separate the persistent audio lead from its newly audible PCM stutters.

#### Outcome:

The physical source-`f597cb1` run validates the passive schema-22 instrumentation but rejects playback acceptance: the user reports the same progressive audio lead and more audible stutters, concentrated near title startup and disappearing as playback settles.  The checksum-valid thirty-second snapshot records 732 displayed pictures and 731 swaps at 24.415 pictures per second, 1,332,473 actual audio-domain dequeues or 27.759854 seconds of 48 kHz PCM, a pending timestamped picture 206,487 ticks or 2.294300 seconds behind the audio-derived STC, and 60 candidate-unavailable, 998 cadence-blocked and zero timestamp-blocked presentation windows.  The zero timestamp block count excludes future-PTS admission waits, while 60 unavailable windows, 319 display-gap outliers up to 83.448433 milliseconds and 1,465,925,354 decoder-stall cycles establish intermittent decoder or presentation unavailability; the displayed-frame PTS itself was invalid at the frozen snapshot, so the fixed startup component of the 2.294-second candidate lateness cannot be separated from accumulated lateness in this capture.  Host scheduling still does not run audio fast: across 94.112970 seconds of title logging, emitted PCM advances 93.496000 seconds at 0.993447 real time while maximum video PTS advances 93.760333 seconds at 0.996253 real time, and the helper's PCM lead over that PTS shrinks by about 0.264 seconds.  The stutter is an independent startup-fill defect rather than continuing transport failure: the FIFO floor reaches zero with no shared-transport block and audible continuity recovers after the pipeline settles, but `audio_pcm_output_adapter` leaves `underrun` sticky after the first starvation recovery, so Main's edge counter is structurally limited to one event per reset and does not contradict multiple early dropouts.  The 5,745,413-byte log, 586,785-byte screenshot and 831-byte telemetry sidecar have SHA-256 `1ba4d981d6d017193761c196fdab1e0a966f5b7dfbbf57645c8f5fcd971bd671`, `91e3830fbeb45436f81153e7eaf34edcbd4615152d8623e22625d29ce98dc515` and `11b27f0f1bfcbb5863861975d5f8b0a8c48f514a2cf75d3da8f2078d6bee74c0`.

#### Next Steps:

Do not restore a helper wall-clock floor or otherwise make PCM run independently of video PTS.  After user approval, treat the remaining synchronization work as an emergency functional RTL boundary: coordinate audio startup with the first presentable video and adequate PCM prefill, design and simulate bounded late-picture recovery against the audio presentation clock while retaining the early timestamp gate and native field-order rules, and make underrun reporting count distinct starvation episodes.  Keep the accepted helper's long-term PTS-derived rate unchanged, build an RBF only after focused startup and presentation regressions pass, and qualify that functional build across three seeds before another physical Simpsons test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 985 COMMIT Unreleased f597cb1 2026-09-04T16:42:49-07:00

#### Coming From:

Unreleased 0a2e2af

#### Purpose:

Add passive schema-22 A/V progress telemetry that distinguishes decoder availability, cadence gating and timestamp gating without changing playback behavior.

#### Outcome:

Source `f597cb1` preserves every schema-21 overlay and audio word while assigning the five previously zero words 58 through 62 to passive A/V synchronization evidence: full-width display progress, a Gray-synchronized audio-domain PCM dequeue count, signed displayed and pending PTS lateness against the audio-derived STC, and saturating presentation-window counts categorized as unavailable candidate, cadence gate or future timestamp.  No diagnostic output feeds playback logic.  The five host decoder regressions and Python compilation pass, and the extended Icarus visibility regression proves schema selection, all five packed words, signed lateness and retained hidden/live overlay behavior.  The fixed build seed `260829` completes synthesis, fit and assembly with zero errors; the timing gate passes global setup at `+0.095 ns`, hold at `+0.243 ns`, recovery at `+3.136 ns`, removal at `+0.660 ns` and minimum pulse width at `+0.925 ns`.  The resulting 4,478,968-byte `output_files/MediaPlayer_AVSyncDiag_f597cb1.rbf` has matching local/build-PC SHA-256 `80b4a075166f8a4ea078482ee6b75250641e3f0740cd4fc350479b180459cafd`.  At the user's direction this exceptional diagnostic build was allowed to finish after the normal policy was clarified: diagnostic RBF rebuilds are otherwise prohibited, and any future necessary RBF rebuild must be treated as an emergency requiring three-seed qualification.

#### Next Steps:

Manually upload only `output_files/MediaPlayer_AVSyncDiag_f597cb1.rbf`, retaining the current source-`0a2e2af` Main and helper, enable telemetry and repeat the same Simpsons first-episode route for at least 30 seconds after playback starts.  Return the fresh log, screenshot and telemetry sidecar plus the audible synchronization result; schema 22 must quantify displayed pictures versus consumed PCM and show whether accumulated lateness comes from decoder availability, native-film cadence or timestamp gating before any functional correction is proposed.  Do not initiate another RBF build for ordinary diagnostics; reserve any future build for an explicitly approved emergency and qualify it across three seeds.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/decode-hardware-telemetry.py
- tools/test_hardware_telemetry.py
- tools/test_telemetry_visibility.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 984 COMMIT Unreleased 0a2e2af 2026-09-04T16:37:40-07:00

#### Coming From:

Unreleased 0a2e2af

#### Purpose:

Use the fresh rollback capture to determine whether the remaining progressive Simpsons desynchronization originates in helper PCM scheduling or FPGA video presentation.

#### Outcome:

The fresh physical capture accepts the source-`0a2e2af` rollback for audible continuity but not A/V synchronization: the user reports no cutouts, yet audio still moves progressively ahead of video.  The log contains no rejected title-clock marker and records 195 title scheduling samples across 238.246268 seconds; over that interval emitted PCM advances only 236.906667 seconds at 0.994377 real time and the maximum video PTS advances 237.320422 seconds at 0.996114 real time, while the helper's apparent lead over its wall-time diagnostic shrinks from 2.926312 to 1.586708 seconds.  Host PCM delivery is therefore not running fast and another helper wall-clock correction would move in the wrong direction.  The checksum-valid 30-second schema-21 FPGA snapshot instead records zero shared-transport blocks, 1,465,356,865 decoder-backpressure cycles, 251,102,880 presentation-stall cycles, 319 display-gap outliers with the three largest at 83.448450, 83.384883 and 66.733333 milliseconds, 93 timestamp-advance conflicts and zero timestamp-delay conflicts.  This localizes the accumulating error to video decode or presentation failing to maintain the audio-derived STC, but schema 21 reuses the full-width display-counter words for overlay telemetry and leaves only wrapping eight-bit display counts, so the exact displayed-frame rate and accumulated displayed-PTS lateness cannot yet be recovered.  The snapshot still latches one PCM underrun with FIFO floor zero and no transport block, but its count remains one and the user heard no cutout, making it a launch transient rather than the progressive drift mechanism.  The 7,871,841-byte log, 611,591-byte screenshot and 779-byte sidecar have SHA-256 `b995097f6e8146169a69d7b78ba9f836195d292a6335a2fde5f8bb81f790481b`, `b35a5f2bbc9ea92543dc3faac92d0ec48055c9530ee44782351918dc4acc6e24` and `01e9b2c95ca225cc6d492ad336b2a5cb72150a1c5528be67f0ee53aff9ffe9af`.

#### Next Steps:

Retain source `0a2e2af` and do not change helper PCM scheduling.  After user approval, add a nonfunctional schema-22 presentation diagnostic using the currently zero deadline words 58 through 62 to retain full-width displayed-picture and PCM-consumption counts, the audio-derived STC versus displayed and pending picture PTS, and separate missed-presentation causes for unavailable decode output, cadence gating and timestamp gating; update the screenshot decoder and focused telemetry simulations, then build only a diagnostic RBF while keeping Main and the helper unchanged.  A 30-second Simpsons title capture will then distinguish insufficient decoder throughput from native-film cadence mismatch and quantify whether the eventual correction belongs in late-video catch-up or presentation-aware audio holding before any functional synchronization change is attempted.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 983 COMMIT Unreleased 0a2e2af 2026-09-04T15:49:33-07:00

#### Coming From:

Unreleased d007afd

#### Purpose:

Remove the rejected physical-DVD title wall-clock PCM floor and restore presentation-timestamp scheduling without disturbing the accepted automatic-menu pacing path.

#### Outcome:

Source `0a2e2af` cleanly reverses only `d007afd`: it removes the physical-title clock state, target, hold-ceiling pacing and regression, restores the automatic-menu-specific elapsed-frame and wait helpers, and restores the associated architecture and changelog text.  All four affected source files are byte-identical to source `715ff18`, so its accepted automatic-menu clock and navigation behavior remain intact; Main, decoder, visualizer, protocol, RTL and RBF are unchanged.  The strict optimized native helper build passes, as do the focused production-translation-unit DVD overlay and scheduling regression, AddressSanitizer with leak detection disabled for the ptrace environment, UndefinedBehaviorSanitizer, private DVD LPCM skip, and real MP3, WAV, FLAC and Ogg seek integrations.  Two GNU 10.2.1 hard-float ARMv7 builds are identical and reproduce the prior 982,436-byte stripped static `host/build/MediaPlayer_Helper` with SHA-256 `5bfcd9e13d87f1e0683c64e3d55bd9c54e997261ce89405f6614c614dc0cd62d`; it has no interpreter or dynamic section, and the native helper reports the expected protocol-one capability surface.  No speculative title-boundary correction was added because the returned artifacts remain the old source-`715ff18` capture.

#### Next Steps:

Exit MediaPlayer and manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper`, preserving executable mode; retain the installed Main, RBF and visualizer.  Enable telemetry and repeat the same two-menu Simpsons first-episode route long enough to verify that audio no longer develops a progressive lead, then replace all three files in `.ai/current_results` with the fresh log, screenshot and telemetry output.  Report whether brief cutouts remain; if so, use the new title-boundary evidence for a separate presentation-clock-safe diagnostic before continuing with Futurama menu, Audio CD and ordinary-audio checks.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 982 COMMIT Unreleased d007afd 2026-09-04T07:29:00-07:00

#### Coming From:

Unreleased d007afd

#### Purpose:

Evaluate the physical-DVD title PCM wall-clock floor against the user's repeat Simpsons run and verify that the returned capture belongs to the tested helper.

#### Outcome:

The user's direct listening result rejects source `d007afd`: episode audio is worse, runs ahead and progressively loses synchronization with video.  This is the failure mode expected when `CLOCK_MONOTONIC` is treated as a lower bound for PCM delivery but the DVD video presentation or shared FPGA transport advances more slowly than host wall time; the floor can admit audio that the presentation timeline has not earned.  The apparent starvation interval in the prior source-`715ff18` log therefore did not justify an independent title clock and may instead reflect deliberate synchronization to the slower presentation timeline, while the brief cutout remains a separate boundary or refill problem.  The files presently in `.ai/current_results` are not the new source-`d007afd` run: their timestamps remain 06:31:47 through 06:31:49, their three SHA-256 values exactly match entry 979's pre-fix source-`715ff18` capture, and the log contains no `DVD title PCM clock started` marker.  Consequently the new drift cannot be quantified from the current folder, but the audible progressive desynchronization is sufficient to fail the wall-clock correction.  No source or returned artifact was changed.

#### Next Steps:

Stop using the source-`d007afd` helper for normal playback and restore the prior source-`715ff18` helper if immediate usability is required.  Replace the three files in `.ai/current_results` with the actual source-`d007afd` run so its clock start, scheduling slope and telemetry can be measured.  After explicit user approval, revert the physical-DVD title wall-clock floor while retaining the accepted automatic-menu work, then instrument and address the brief title-boundary cutout without advancing audio independently of the presentation clock; repeat the Simpsons route before the remaining Futurama, Audio CD and ordinary-audio checks.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 981 COMMIT Unreleased d007afd 2026-09-04T07:11:42-07:00

#### Coming From:

Unreleased 715ff18

#### Purpose:

Prevent sparse physical-DVD title timestamps from starving the PCM sink when decoded audio is already available.

#### Outcome:

Source `d007afd` adds a physical-DVD title PCM clock without changing Main, the protocol, decoder, visualizer, RTL or RBF.  After the ordinary startup hold releases, the helper anchors emitted frames to `CLOCK_MONOTONIC` at the selected sample rate and uses the greater of that floor and the existing video-PTS target, rounded down to the established 128-frame refill unit and emitted in at most 2,048-frame batches.  Video PTS therefore remains the primary authority when it advances, while the captured high-byte, sparse-PTS interval can no longer consume the FPGA's fixed audio lead despite held decoded PCM.  A fast optical source waits at the existing decoded-audio ceiling until PTS or elapsed time earns another batch.  Explicit menu state and the automatic-menu epoch exclude the new title clock, non-physical Program Streams remain unchanged, and every navigation or stream-boundary reset clears the anchor while preserving the physical-source identity.  The production-translation-unit regression covers sparse PTS, sample-clock rate limiting, the hold ceiling, advancing-PTS takeover, menu exclusion, non-physical exclusion and navigation reset.  Strict optimized, AddressSanitizer with leak detection disabled for the ptrace environment, UndefinedBehaviorSanitizer and focused GCC analyzer runs pass, as do twenty production repetitions, one hundred menu-hop repetitions, fifty reserve and stage repetitions, retained DVD random-access, SPU, AC-3, Program Stream seek, CDDA, audio UI, visualizer, private-LPCM and static Main checks, plus real MP3, WAV, FLAC and Ogg seek, pause and visualizer integrations.  The strict native build passes with the established host-only `-Wno-attributes` exception.  Two identical GNU 10.2.1 builds produced the 982,436-byte stripped static hard-float ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `b8a61f0d82c5affbfe3bd415d7f1e01374ffc464a1d53c88327e5c875a4e427a`; it has no dynamic section and the native helper retains the protocol-one capability surface.

#### Next Steps:

Exit MediaPlayer and manually replace only `/media/fat/linux/MediaPlayer_Helper` with `host/build/MediaPlayer_Helper`, preserving executable mode; retain the installed Main, RBF and visualizer.  Enable telemetry and repeat the same two-menu Simpsons first-episode route, requiring one `DVD title PCM clock started` record after the title boundary, continuous episode audio, sustained advancing playback and a fresh schema-21 snapshot with PCM underrun zero.  Then spot-check Futurama root and nested menus to confirm their existing automatic-menu fallback, followed by Audio CD and one ordinary audio file, and return the updated results before hardware acceptance.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 980 COMMIT Unreleased 715ff18 2026-09-04T06:45:38-07:00

#### Coming From:

Unreleased 715ff18

#### Purpose:

Confirm the source-`715ff18` title audio cutouts and isolate the PCM starvation mechanism.

#### Outcome:

The user confirms that brief audio cutouts were audible during the Simpsons episode, so the schema-21 title snapshot's sole error flag `0x0400`, PCM FIFO floor zero and latched underrun are a real source-`715ff18` regression rather than an incidental diagnostic.  The title scheduler exposes the mechanism between 551.857780 and 555.773724 seconds: across 3.915944 seconds of wall time it emits only 50,560 PCM frames, or 1.053333 seconds at 48 kHz, while its real-time diagnostic budget advances 187,966 frames.  The prior 120,600-frame lead is exhausted and leaves a 16,806-frame, 350.125-millisecond deficit.  This is not an optical, helper, decoder or transport stall: Main performs 248 reads totaling 4,063,232 bytes during the interval, the helper retains 66,560 to 77,440 decoded PCM frames, and only the title's maximum video PTS advances slowly by about one second.  Normal title scheduling therefore underfeeds the sink when a high-byte, sparse-video-PTS interval occurs even though decoded PCM is available.  The automatic-menu real-time pacing correction remains validated and the two Space presses continue to represent two distinct authored menus.

#### Next Steps:

After user approval, add a physical-DVD normal-title monotonic PCM lower bound that admits already-decoded held audio only as the exact selected sample-rate clock earns it, retains video PTS as the primary ordering authority, resets at navigation and stream boundaries, and leaves file, ISO and automatic-menu scheduling unchanged.  Add production-path regressions for sparse or stalled title video PTS, fast-decode rate limiting, PTS resumption, navigation reset and unchanged automatic-menu pacing; then run the strict optimized, analyzer, sanitizer, repetition and retained integration suites and build only a new static ARM helper locally.  Hardware acceptance will repeat the same two-menu Simpsons route and require continuous episode audio with schema-21 underrun zero, followed by Futurama menu, Audio CD and ordinary-audio spot checks.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 979 COMMIT Unreleased 715ff18 2026-09-04T06:34:19-07:00

#### Coming From:

Unreleased 715ff18

#### Purpose:

Complete the source-`715ff18` Simpsons title-launch test and distinguish the apparent freeze from the disc's authored navigation path.

#### Outcome:

The updated physical capture proves that the first Space press did not skip a menu or freeze the decoder: it activated button one in a six-button menu at PCI LBN 367 and entered a distinct five-button authored submenu at PCI LBN 966 while deliberately retaining the resident decoder frame.  The similar static background made that intermediate state appear frozen, but its changed highlight geometry and repeated valid overlay commits identify a live submenu.  Source `715ff18` then sustains that state for 406.508705 seconds until the second Space press while holding PCM near the 96,000-frame watermark; Main submits 124,486,314 bytes at a bounded mean 306,233 bytes per second with no helper error, hold-limit failure or memory runaway.  The second Activate command at 518.723125 seconds selects button one in the five-button submenu, libdvdnav reports a menu hop and leaves menu space at 518.797622 seconds, Main releases the ordinary navigation barrier at 518.805154 seconds, and the helper qualifies a fresh sequence, I picture and following reference before starting the episode.  The screenshot visibly shows episode playback, and the capture continues for 295.724162 seconds with 301,806,776 more submitted bytes, advancing video PTS and no decoder, presentation, overlay, PCM-protocol or transport error.  The checksum-valid schema-21 title snapshot records 25,271,780 accepted bytes, 220 displayed pictures, 219 swaps and no transport block, but it latches one PCM underrun with a zero FIFO floor and error flag `0x0400`; this is the only remaining anomaly and was not reported audibly by the user.  The 15,107,244-byte log, 1,519,205-byte screenshot and 779-byte sidecar have SHA-256 `55e5dd122ebffb333984e816010ce003b081e89be10f3fe617ed3fdc6cbd3178`, `325109c827a903d90d35bd8e5400ebe0862f6446346c958542ea8e4fad74fb0f` and `8427ea7911dec9ddd19b44651a0bd5d3670174a3e6195968c2972107cc5280e2`.

#### Next Steps:

Retain source `715ff18` and its two-step menu behavior.  Confirm whether any brief audio dropout was audible when the episode began, then repeat one fresh Simpsons title launch with telemetry to determine whether the single startup underrun is reproducible; require zero underruns before final acceptance, or isolate the title-boundary PCM refill if it repeats.  Complete the planned Futurama root and nested-menu check plus Audio CD and ordinary-audio spot checks without changing the proven real-time fallback or DVD navigation classification from this successful title launch.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 978 COMMIT Unreleased 715ff18 2026-09-04T06:24:37-07:00

#### Coming From:

Unreleased 715ff18

#### Purpose:

Evaluate the source-`715ff18` real-time PCM fallback and provisional continuation on the physical Simpsons first-episode route.

#### Outcome:

The fresh physical capture partially accepts source `715ff18` while leaving the title transition untested.  Main sends the capture's only Activate command at 112.214420 seconds, libdvdnav accepts button one but remains in menu space, and PCM pressure promptly rebases PTS 45,045 above prior PTS 647,273, commits the exact 193,064-byte stage, preserves the resident decoder with 183,808 held frames and acknowledges the provisional continuation at 112.388301 seconds.  The new fallback reports `rate=48000`; over the following 30.442892 seconds Main submission grows by 9,701,232 bytes at a mean 318,670 bytes per second instead of the prior source-rate runaway, the helper remains alive, and there is no hold-limit failure, signal-nine termination, helper error or overlay ordering error.  The destination publishes distinct overlay geometry and valid commits at 112.829373 and 135.179779 seconds while the screenshot continues to show the episode-selection menu.  No second navigation command, menu leave, delayed provisional stream boundary or title payload occurs before capture, so the reported static picture is an unresolved same-menu authored state rather than evidence that the host path stopped; the checksum-valid schema-21 snapshot is the earlier root-menu capture with 4,885,648 accepted bytes, 124 displayed pictures, 123 swaps and zero decoder, presentation, PCM, underrun, transport or overlay errors, and therefore does not independently characterize the post-activation decoder interval.  The 4,824,330-byte log, 600,183-byte screenshot and 844-byte sidecar have SHA-256 `39be84978ce3767aa5e51f3f1ab591d52491ff0b230d3a9a73a85e66d13f784d`, `f67cd7c2741b84f166fcbb90df3afd1943cd177210091af6202dc77c4dd69228` and `8468f22cbff5cfbae5ccc869779dc7e922f911144bd717358509df2bc6d01a74`.

#### Next Steps:

Retain source `715ff18` and repeat the same route, but after the destination episode menu and its new highlight settle, press Space a second time and keep the capture running through either title playback or a bounded failure.  Require a second `DVD navigation command=0x08`, a later menu leave followed by `DVD delayed activation provisional stream boundary`, one drained decoder boundary and sustained episode video with advancing PTS; if the second command is recorded but menu state still never leaves or the title still does not start, use that evidence to propose a consumer-synchronous DVD domain, PGC or title-transition discriminator rather than weakening the now-proven real-time PCM pacing.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 977 COMMIT Unreleased 715ff18 2026-09-04T05:49:51-07:00

#### Coming From:

Unreleased 36dc0ac

#### Purpose:

Clock the source-`36dc0ac` automatic-menu PCM fallback in real time while retaining a bounded path from provisional resident-context continuation to a later DVD title barrier.

#### Outcome:

Source `715ff18` replaces automatic-menu fallback's source/SPI-rate drain with an explicit monotonic sample budget at the selected PCM rate.  It retains one bounded initial release to the established low watermark, admits later batches only as real elapsed time earns them, drains the physical-DVD output reserve before each admitted batch so it reaches Main promptly, and waits in interrupt-safe two-millisecond intervals only when fast decode exceeds the hard hold ceiling.  Any advancing video PTS clears the fallback and restores the ordinary timestamp scheduler.  A PCM-only deferred-activation release is now provisional: Main receives the committed resident-context prefix immediately, while a separate DVD follow-up flag survives until libdvdnav reports a later menu exit and then requests the existing asynchronous stream-boundary handshake; video pressure remains a final continuation and a later navigation command supersedes stale provisional state.  The production regression proves a fast burst cannot drain without clock budget, exact backdated 48 kHz allowance drains to the watermark, the hard ceiling stays bounded, and a provisional continuation later selects `STREAM_BOUNDARY`; strict optimized and ASAN/UBSAN runs pass, GCC analysis reports only the established audio-overlay allocation false positive, and twenty production repetitions, one hundred menu-hop repetitions, retained reserve/stage/DVD/audio unit tests, static Main contracts, twenty private-LPCM integrations and real MP3, WAV, FLAC, Ogg, pause-barrier and idle-visualizer integrations pass.  GNU 10.2.1 produced the 982,436-byte stripped static hard-float ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `5bfcd9e13d87f1e0683c64e3d55bd9c54e997261ce89405f6614c614dc0cd62d`; it has no dynamic section and retains the protocol-one capability surface.  Main, protocol, decoder, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`715ff18` artifact, preserving executable mode; Main, RBF and visualizer remain installed as-is.  Repeat the same Simpsons root-menu and first-episode selection and require `pressure=pcm ... provisional=1`, one fallback activation containing `rate=48000`, bounded rather than source-rate PCM progress, and—if that authored branch later leaves menu space—a `DVD delayed activation provisional stream boundary` record before episode payload.  Require the episode to start and continue without the previous frozen frame, runaway Main submission, signal-nine termination or helper error, then spot-check Futurama root/nested menus, Audio CD and one ordinary audio file and return the updated results before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 976 COMMIT Unreleased 36dc0ac 2026-09-04T05:41:53-07:00

#### Coming From:

Unreleased 36dc0ac

#### Purpose:

Evaluate the source-`36dc0ac` PCM-pressure continuation on the physical Simpsons DVD and isolate the reported first-episode freeze.

#### Outcome:

The physical result rejects source `36dc0ac` while proving that its new pressure boundary removes the previous delay and memory exhaustion.  Main sends Activate at 134.012841 seconds, libdvdnav accepts button one but remains in menu space, and the helper reaches PCM pressure almost immediately: it rebases PTS 45,045 above prior PTS 647,273, commits the exact 193,064-byte stage, preserves the resident decoder with 183,808 held frames at the 192,000-frame ceiling and acknowledges continuation at 134.152018 seconds.  The restored automatic-menu fallback then exposes a false pacing assumption: because video PTS remains fixed at 647,274, every newly decoded AC-3 packet is drained toward the 96,000-frame watermark as fast as the source and SPI path accept it.  In 93.626 seconds the helper emits 55,625,472 PCM frames where a 48 kHz clock accounts for 4,494,031, a 12.38-times overrun, and Main submission grows from 25,739,948 to more than 276 million bytes while only 4,770,764 video bytes advance.  No menu leave, delayed hop or second navigation command occurs before capture, so the helper is still replaying the authored menu rather than loading the episode.  The checksum-valid schema-21 snapshot independently excludes an RTL decoder freeze: during its 4.293-second window the decoder accepts 4,885,648 bytes, displays 124 pictures with 123 swaps and remains decode-active, with no PCM protocol error or audio underrun.  Its `0x2000` error is the overlay protocol flag after the fast loop publishes repeated style/configuration records, not an H.262 or PCM failure.  The 7,770,561-byte log, 242,955-byte screenshot and 844-byte sidecar have SHA-256 `ab81a858da3698f19f75db7223d358db23672e1641177293e3c49c316c122945`, `9845554240c28b57768256e61ba52f1e1e093bf1905545e464c278009e366e1d` and `544460c424dbf34fb10dce93923c656b2772b5ad0e27005d86722baa2bcf7e94`.  No runtime source was changed.

#### Next Steps:

After user approval, replace the fallback's source-rate drain with an explicit monotonic 48 kHz budget: retain the initial bounded release, admit only elapsed-clock PCM thereafter, and wait at the existing hold ceiling so a fast optical source cannot outrun playback or grow memory.  Treat a PCM-pressure resident-context release as provisional rather than erasing the delayed activation classification; continue watching libdvdnav until a later menu leave requests the existing decoder barrier, or a proven continuing menu resolves the activation, while a superseding command remains able to cancel it.  Extend the production regression with a source that supplies AC-3 much faster than real time and require emitted PCM to stay within its startup allowance plus elapsed clock, held PCM to remain bounded and a delayed menu-to-title transition to retain its stream-hop barrier.  Retain the video-pressure continuation, qualified restart, still, Futurama, Audio CD and ordinary-audio controls, then build only a new local ARM helper for another Simpsons first-episode run; Main, RTL and the RBF should remain unchanged.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 975 COMMIT Unreleased 36dc0ac 2026-09-04T05:19:48-07:00

#### Coming From:

Unreleased cd484ba

#### Purpose:

Bound deferred same-menu activation audio and restore sink-paced menu scheduling after the resident-context continuation commits.

#### Outcome:

Source `36dc0ac` adds the existing PCM hold ceiling as a second decision pressure for a deferred activation that remains in menu space without qualifying an independent MPEG-2 restart group.  A low-bitrate branch now rebases its staged timestamps and commits its exact finite prefix before enabling live output, releases the startup hold, acknowledges continuation without resetting Main, and restores the automatic-menu epoch so the established sink-paced fallback drains toward its watermark and keeps the hard hold invariant active; video pressure retains the same continuation path, while qualified restarts and actual menu-to-title exits retain their decoder barriers.  The production-translation-unit regression drives the real private AC-3 PES path with PCM pressure at 16,384 frames while video remains at 32,776 queued bytes, proves the 32,780-byte two-record stage commits first, validates both streams at rebased PTS 900,001, observes the continuation event, and verifies byte-exact interleaved video and PCM while the hold settles at the 8,192-frame test watermark.  Strict optimized and AddressSanitizer plus UndefinedBehaviorSanitizer runs pass, as do GCC analysis apart from the known audio-overlay allocation false positive, twenty production repetitions, one hundred menu-hop repetitions, fifty reserve and stage repetitions, retained DVD, AC-3, CDDA, audio UI, visualizer, seek and static Main tests.  GNU 10.2.1 produced the 978,340-byte stripped static ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `8411bc5d73179ba1cff9a32fa2ce8bbd1095353d188c2893d833094bee5d8c28`; it has no dynamic section and passes its protocol-one capability probe plus real MP3, WAV, FLAC, Ogg, pause-barrier, idle-visualizer and private-audio integrations.  Main, protocol, decoder, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`36dc0ac` artifact and leave the current per-core Main, RBF and visualizer in place.  Repeat the same Simpsons launch and root-menu selection, require a prompt `DVD menu activation preserved resident decoder context pressure=pcm` record with held PCM near 183,808 frames followed by `automatic menu PCM fallback activated`, confirm the episode-selection menu appears without the prior 36.65-second delay, then activate and play the first episode without signal-nine termination or `helper-error`.  Retest Futurama root and nested menus plus title playback, spot-check Audio CD and ordinary audio playback, and return the updated results for hardware qualification.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 974 COMMIT Unreleased cd484ba 2026-09-04T05:17:58-07:00

#### Coming From:

Unreleased cd484ba

#### Purpose:

Evaluate the source-`cd484ba` context-preserving Simpsons menu activation on physical MiSTer hardware and isolate its remaining delay and failure.

#### Outcome:

The physical Simpsons run proves source `cd484ba` crosses the former two-megabyte deadlock and reaches the next authored menu, but rejects the complete activation behavior.  Main sends the only recorded Activate command at 100.605542 seconds, libdvdnav remains in menu space, and the helper starts its deferred stage with prior PTS 647,273; at 136.779520 seconds it rebases the destination's first PTS 45,045 by 602,229 ticks, commits 4,094,728 staged bytes and 14,848 records, acknowledges the unqualified continuation at 137.254611 seconds and preserves the resident decoder.  That 36.65-second interval accounts for the reported slow transition.  The continuation then leaves video PTS fixed at 647,274 while decoded AC-3 PCM grows from 33,475,584 held frames to 113,378,816 frames, approximately 453.5 MiB of stereo samples, because `start_pending_menu_activation()` clears `automatic_menu_epoch` and the new fallback does not restore it; both the established sink-paced menu fallback and its 192,000-frame safety check are therefore disabled.  Linux terminates the helper with signal nine at 181.191730 seconds, consistent with exhausting the target's approximately 492 MiB visible RAM, and Main reports `helper-error`.  The screenshot shows the destination's `PLAY EPISODE` menu with its selector rather than title playback, and no second navigation command reached the helper.  The checksum-valid schema-21 snapshot covers an earlier 30-second session with 5,122,483 accepted bytes, 131 displayed pictures, 130 swaps, zero decoder errors, zero transport blocks and zero audio underruns, so it does not contradict the later host-side exhaustion.  The 5,718,761-byte log, 308,326-byte screenshot and 740-byte sidecar have SHA-256 `e31c33e3d19531094e8d951e785729dce29b955fab8e0ea0e4aeb9bf24135b70`, `740cf96bbee3222f8235304d7e3b66c93b9ed04e48e47d315d0c4d6846befba8` and `4fb87049d01c8d7d1df9e5198fa6d2972382d87df7258767784f37f201fd87b0`.  No runtime source was changed.

#### Next Steps:

After user approval, add audio pressure as a second bounded same-menu activation decision so a context-dependent branch commits before decoded PCM exceeds the existing hold ceiling instead of waiting only for two megabytes of video.  Commit and acknowledge the finite activation stage first, then restore the automatic-menu epoch so the established live sink-paced fallback drains toward its 96,000-frame watermark without filling the eight-megabyte stage; retain the current video guard, timestamp rebase, qualified restart barrier and menu-to-title barrier.  Add a production regression whose low-bitrate menu reaches PCM pressure before video pressure and proves bounded staging, prompt continuation acknowledgment, exact output, sink-paced PCM and a stable hold, while retaining the source-`cd484ba` video-pressure case and all qualified restart, still, title, DVD and audio controls; then build only a new local ARM helper for the same Simpsons route.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 973 COMMIT Unreleased cd484ba 2026-09-04T04:34:35-07:00

#### Coming From:

Unreleased 8a86b77

#### Purpose:

Prevent deferred same-menu DVD activations from deadlocking behind the initial random-access filter and video-queue bound.

#### Outcome:

Source `cd484ba` retains the existing two-megabyte video-queue guard and qualified restart barriers while adding a context-preserving fallback for deferred button activations that remain in menu space without supplying a complete sequence-header, I-picture and following-reference startup group.  At queue pressure the helper rebases all queued, pending, audio and triggering video timestamps above the prior live epoch, releases only the initial random-access filter, drains the exact interleaved stream through the normal scheduler into the existing activation stage, commits it to the resident decoder and acknowledges continuation; actual menu-to-title exits and independently decodable motion-menu restarts keep their established decoder barriers.  The production-translation-unit regression drives this through the real PES, H.262 filter, bounded queue, scheduler, stage and control-event path, verifies two megabytes of byte-exact video and rebased in-band PTS records, and passes optimized, AddressSanitizer plus UndefinedBehaviorSanitizer and twenty repeated runs.  Retained DVD random-access, SPU, menu-hop, overlay, reserve, staging, AC-3, CDDA, audio UI, visualizer and seek tests pass, including one hundred menu-hop runs, static Main contracts and final-ARM real MP3, WAV, FLAC, Ogg, pause-barrier and private-audio integrations.  GNU 10.2.1 produced the 978,340-byte stripped static ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `7cd8427fd955beb81ba35c7fa2ff34e09cd8214f4872f9d8f9695187dcd560e4`; it has no dynamic section and passes its protocol-one capability probe.  Main, protocol, visualizer, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`cd484ba` artifact and leave the current per-core Main, RBF and visualizer in place.  Reproduce the same Simpsons route through its first-episode menu activation and require `DVD menu activation deferred`, `DVD menu continuation PTS rebased` and `DVD menu activation preserved resident decoder context` without `video lookahead limit exceeded` or helper termination, then select and play the episode.  Retest Futurama root-menu arrival, selector motion, nested episode selection and title playback, spot-check an Audio CD and ordinary audio file, and return the updated result set for hardware qualification.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 972 COMMIT Unreleased 8a86b77 2026-09-04T04:31:41-07:00

#### Coming From:

Unreleased 8a86b77

#### Purpose:

Accept the completed Audio CD presentation and localize The Simpsons first-episode stall without changing runtime source.

#### Outcome:

The user reports that source `8a86b77`'s Audio CD title, aligned metadata, placeholders and default artwork look good, completing the current audio-player work.  The fresh physical Simpsons DVD run independently rejects the button-activation path: Main sends menu activate at 171.246404 seconds, libdvdnav accepts button one and remains in menu space, and the helper begins its 8 MiB deferred activation stage before resetting navigation scheduling with the initial random-access filter active.  The destination then supplies 2,097,152 bytes without a complete sequence-header, I-picture and following-reference startup group, so `scheduler_drain()` admits none of that queued video to the stage and the helper deliberately exits at 207.840268 seconds on its 2 MiB lookahead guard.  Main reports helper-error with exit code one after 33,710,172 submitted bytes; this is a helper state-machine deadlock rather than an RTL syntax stall or frozen process.  The stage's 4 MiB motion-menu decision is unreachable while the filter holds all video behind the smaller queue bound, and the existing motion-stage regression bypasses both the filter and queue.  The checksum-valid schema-21 snapshot covers an earlier healthy 30-second epoch with 5,107,715 accepted bytes, 128 displayed pictures, 127 swaps and zero decoder, presentation, PCM, underrun or transport errors, so it does not contradict the later host-side failure.  The 8,503,411-byte log, 350,644-byte screenshot and 766-byte sidecar have SHA-256 `f8fabeea0079268de9da7a8facc2f7be8a3231d2bef4b22c58c3ff83265fe45c`, `90c77634fcbb8bc143df68bc306016d8de895bf73b7d28212d2c451fd5cd4187` and `a3f2e0eae728a1d7e12b67712b2f3492074b0c7b02f4158fb103723ca887ba8d`.  No runtime source was changed.

#### Next Steps:

After user approval, keep the 2 MiB runaway guard and distinguish restart-qualified staged activations from menu continuations that require the resident decoder context.  When an activation remains in menu space but cannot form an independent random-access group before the queue bound, release that activation through a context-preserving continuation path and acknowledge it without resetting Main; retain the existing barrier for a qualified staged restart or an actual menu-to-title exit.  Add a production-path regression that reaches this bound through the real filter and queue, plus controls for Futurama staged stills, qualified motion-menu hops, overlay-only continuation and title launch, then build only a local static ARM helper.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 971 COMMIT Unreleased 8a86b77 2026-09-04T04:09:25-07:00

#### Coming From:

Unreleased 2ab755b

#### Purpose:

Present coherent Audio CD metadata with aligned labels and a built-in default disc image.

#### Outcome:

Source `8a86b77` uses the existing TOC-backed playlist state as the Audio CD presentation discriminator and formats the title from the same selected physical track byte as the corresponding `TRACK nn` row, preventing title and selector drift across beginning, middle and end changes.  A shared metadata-row renderer right-aligns TITLE, ARTIST and ALBUM before one fixed colon column, keeps artist and album at `---`, and preserves the ordinary-file title placeholder.  The prior empty artwork box now contains a bounded concentric-disc graphic and `AUDIO CD` caption; its ellipse width compensates for the native mode's 8:9 pixel aspect and requires no asset or protocol change.  Strict optimized and ASAN/UBSAN pixel tests pass selector/title changes `09` to `01` to `18`, all three aligned colons, both retained placeholders, default-art palette and bounds, ordinary-file fallback, timing and progress; GCC analyzer, CDDA reader tests, static Main contracts and native real-helper integrations also pass.  GNU 10.2.1 produced the 978,340-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `2e87ba05eb6e5dcce4f42712626e19f773126a683d529672ae23a4f25b8d42e2`, and that exact artifact passes idle plus MP3, WAV, FLAC, Ogg and pause integration.  Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`8a86b77` artifact, preserving executable mode, then re-enter the core and load a physical Audio CD.  Require the default disc image to stay inside the album-art box, all three metadata colons to align, TITLE to match the selected playlist row through natural, previous and next track changes, and ARTIST plus ALBUM to remain `---`; spot-check the accepted timing fields and one ordinary audio file before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- tools/test_audio_ui_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 970 COMMIT Unreleased 2ab755b 2026-09-04T04:08:26-07:00

#### Coming From:

Unreleased 2ab755b

#### Purpose:

Record hardware acceptance of Audio CD track-relative timing and define the requested metadata alignment and default-art boundary.

#### Outcome:

The user reports that source `2ab755b` looks good on the test MiSTer, accepting active-track elapsed, remaining, total and progress plus the complete album-duration playlist clock delivered by entry 969.  The next requested Audio CD presentation boundary is to mirror the selected `TRACK nn` playlist label in the title field, retain `---` placeholders for artist and album, align the title, artist and album colons on one vertical axis, and replace the empty artwork placeholder with a built-in default Audio CD image.  Existing CDDA transport, timing, selector behavior, visualizer lifecycle and ordinary audio-file presentation remain unchanged.

#### Next Steps:

Proceed with a separate approved helper-only proposal that gives the renderer an Audio CD presentation mode, derives the title from the same selected physical TOC track used by the playlist, aligns the metadata labels without changing their established scale, draws a deterministic default disc image inside the existing artwork viewport, and validates both CD and ordinary-file frames without rebuilding Main or the RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 969 COMMIT Unreleased 2ab755b 2026-09-04T03:50:52-07:00

#### Coming From:

Unreleased 04360e9

#### Purpose:

Give Audio CD playback track-relative elapsed, remaining and total clocks plus a whole-album playlist-duration clock.

#### Outcome:

Source `2ab755b` preserves the absolute concatenated CDDA cursor for reading and seeking but exposes the active audio track's logical start and length from the filtered TOC.  The audio UI atomically carries that window with the selected physical track, so `ELAPSED`, `REMAIN`, the existing `TRACK` total field and the progress bar are track-relative while `PLAYLIST` shows the duration of the complete filtered audio program.  Partial track and album seconds retain the established upward duration rounding, elapsed time retains completed-second truncation, data-track gaps remain excluded, and ordinary audio files retain their file-relative clocks and placeholder playlist summary.  Strict optimized and ASAN/UBSAN reader and pixel tests pass mixed-mode timing, invalid ranges, fractional durations and an exact `00:21` elapsed, `00:41` remaining, `01:02` track, `05:02` playlist and 224-of-652 progress case; GCC analyzer, static Main contracts and native real-helper visualizer/pause integrations pass.  GNU 10.2.1 produced the 978,340-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `6d13a20e9c4d5fd23f3c71522d1e1be1b23d10b7fd406e757aa2dba55321d4e4`, and that exact artifact passes idle plus MP3, WAV, FLAC, Ogg and pause integration.  Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit MediaPlayer and replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`2ab755b` artifact, preserving executable mode, then re-enter the core and load a physical Audio CD.  Verify that elapsed and remaining restart at each natural or requested track boundary, `TRACK` remains that track's total length, `PLAYLIST` remains the album's combined audio duration, and the progress bar restarts per track; also spot-check previous, next and fixed seeks plus one ordinary audio file before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- tools/test_audio_ui_output.c
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 968 COMMIT Unreleased 04360e9 2026-09-04T03:50:04-07:00

#### Coming From:

Unreleased 04360e9

#### Purpose:

Record hardware acceptance of the TOC-backed Audio CD playlist and define the requested per-track and whole-album timing semantics.

#### Outcome:

The user reports that source `04360e9` looks good on the test MiSTer, accepting the `TRACK nn` playlist population, moving selection and six-row scrolling window delivered by entry 967.  The next requested display boundary is now explicit for Audio CD playback: `ELAPSED` is elapsed time within the selected track, `REMAIN` is time left within that track, `TOTAL` is that track's complete duration, and `PLAYLIST` is the complete duration of every filtered audio track on the disc.  Existing controls, playlist labels, current-track selection, audio transport and ordinary audio-file timing remain unchanged.

#### Next Steps:

Proceed with a separate approved helper-only proposal that exposes current-track start and duration from the CD TOC, derives the four requested clocks from the existing absolute CDDA sample position, and validates boundary, seek, natural-transition and mixed-mode behavior without rebuilding Main or the RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 967 COMMIT Unreleased 04360e9 2026-09-04T03:25:13-07:00

#### Coming From:

Unreleased e0f6f9a

#### Purpose:

Populate the Audio CD playlist with the disc track sequence and keep the playing track selected near the vertical center without changing transport controls.

#### Outcome:

The test MiSTer reports `/dev/cdrom` linked to `/dev/sr0` and a drive with Audio CD playback support; its existing source-`e0f6f9a` helper was actively consuming the inserted disc, so no competing live-drive process was started.  Final source `04360e9` exposes ordered physical audio-track numbers from the already filtered Red Book TOC and configures the audio UI with stable `TRACK 01`-style rows.  The six-row window selects the playing entry, targets the fourth visible row when both sides permit, clamps cleanly at the first and last tracks, preserves gaps when mixed-mode data tracks are excluded, and follows natural playback, fixed seeks and existing previous or next track changes without altering controls.  Before an Audio CD pause barrier, the current overlay is republished so revealing a UI that timed out on an earlier track cannot show a stale selector.  Strict optimized pixel and reader tests cover middle, beginning and end windows plus mixed-number numbering and invalid inputs; AddressSanitizer and UndefinedBehaviorSanitizer pass with leak detection disabled because LeakSanitizer is unavailable under the local ptrace wrapper, GCC analyzer passes, the complete native helper compiles with the established host-only `-Wno-attributes` exception, static Main routing and NTSC checks pass, and real-helper idle plus MP3, WAV, FLAC and Ogg visualizer, seek and pause integrations remain clean.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `cb06ef1bd73e12f47741c723ad88aaa2485f1df48be9ff2ccbad06a11382661a`; Main, protocol, visualizer pack, RTL and RBF are unchanged.

#### Next Steps:

Exit the MediaPlayer core, replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`04360e9` artifact and preserve executable mode, then re-enter the core and load the inserted Audio CD.  Require every TOC entry to appear as `TRACK nn`, the playing row to move on P/N or player-one Left/Right and on a natural track boundary, and a disc with more than six tracks to keep middle selections on the fourth row while clamping the window near either end.  After the overlay has timed out on a later track, press Space once and require the refreshed UI to identify that current track before audio and visualizer hold, then resume and spot-check fixed seeks, ordinary audio playback and Video DVD startup before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_ui.c
- host/arm/audio_ui.h
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- tools/test_audio_ui_output.c
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 966 COMMIT Unreleased e0f6f9a 2026-09-04T03:16:49-07:00

#### Coming From:

Unreleased e0f6f9a

#### Purpose:

Record hardware acceptance of the overlay-first audio pause barrier and scope selectable visualizer-pack support against the current decoder-safe asset format.

#### Outcome:

The user reports that source `e0f6f9a` works perfectly on MiSTer, accepting the first-Space overlay reveal, stopped audio and visualizer, and second-Space resume behavior; this closes the hardware check left open by entry 965.  Alternate visualizers can reuse the current version-two `.mmpvis` container and generator while changing the underlying 720-by-480 artwork or animation, provided all eight steady grades, seven rising transitions and seven falling transitions remain phase-aligned native-interlaced MPEG-2 closed GOPs with the validated three-picture structure.  Production currently opens only `/media/fat/linux/MediaPlayer_Visualizer.mmpvis`, although tests may override it through `MMP_VISUALIZER_PATH`.  Manual replacement therefore works now without another build, while an on-screen `Load Visualizer` file picker would require a small `CONF_STR` addition and thus one Quartus/RBF build, plus isolated Main path selection and helper launch plumbing; no decoder datapath or visualizer format change is inherently required.  Hot-swapping during active audio would need a larger live-control transaction, whereas selecting while idle and applying the choice to the next helper launch is the safer first boundary.

#### Next Steps:

Preserve source `e0f6f9a` and its accepted runtime artifacts.  If selectable visualizers are approved, first create several deterministic version-two packs from distinct source animations and add a session-scoped `Load Visualizer` picker that validates the selected `.mmpvis`, restarts the idle helper immediately and uses the choice for subsequent audio-file and Audio CD launches; defer active-song hot-swapping and optional persistent configuration until the basic selection route is hardware-proven, and perform only one Quartus seed for the required menu-string RBF change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 965 COMMIT Unreleased e0f6f9a 2026-09-04T02:52:38-07:00

#### Coming From:

Unreleased 889f4ea

#### Purpose:

Make the first Play/Pause press reveal the standalone-audio player UI before holding audio and visualizer transport, with deterministic resume behavior and no RTL change.

#### Outcome:

The user hardware-accepts source `889f4ea` as visibly smoothing the eight-level visualizer transitions, then reports that after the audio-player overlay has timed out the first Space press pauses music and the visualizer without revealing the UI, while the second Space resumes both and makes the UI appear.  Source `e0f6f9a` fixes the diagnosed ordering defect with an audio-only `PAUSE` and `PAUSE_READY` barrier: the helper reveals the resident overlay style, flushes all preceding in-band output, acknowledges and waits for the existing `GO`, while isolated Main drains through acknowledgment and pipe quiescence before setting the transport hold.  The next Play/Pause press releases the same emitted-audio frame with `GO`, so the visualizer and music remain stopped during pause and the ten-second overlay interval advances only after resume.  The optimized and AddressSanitizer plus UndefinedBehaviorSanitizer production-path integrations prove that `STYLE` precedes readiness, output remains byte-stable while held and all MP3, WAV, FLAC and Ogg paths resume; focused audio UI, visualizer, seek, CDDA, Main lifecycle, native-480i and static routing tests pass, the complete Main patch stack applies and compiles against pinned upstream `0a8fb44`, and the visualizer analyzer test remains clean.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `34227d89d11c28bb7d0a2206e87462d9c17315f0dd521c34e0c8bc2e4fbc7ae7` and the 1,186,780-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `1a333b83f43e71789922befcc828fc705480d7dafe85022b7591d0b18028b4f8`; the accepted visualizer pack and RBF remain byte-identical.

#### Next Steps:

Exit the MediaPlayer core, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MiSTer_MediaPlayer` with the two source-`e0f6f9a` artifacts, preserve executable mode and reboot because Main changed; retain `MediaPlayer_Visualizer.mmpvis` and `MediaPlayer_20260904.rbf`.  Play an audio file past the ten-second overlay timeout, press Space once and require the UI to appear before music and visualizer motion both stop, press Space again and require both to resume with the UI clearing after ten resumed playback seconds, then repeat with an Audio CD and spot-check DVD and MPEG-2 takeover before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_main_cdda.py
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 964 COMMIT Unreleased 889f4ea 2026-09-04T02:17:33-07:00

#### Coming From:

Unreleased 8d0ab99

#### Purpose:

Replace visible whole-GOP visualizer grade steps with deterministic three-frame crossfades while retaining the existing eight-level response and legacy-pack compatibility.

#### Outcome:

Source `889f4ea` adds version-two visualizer index handling with eight steady variants, seven adjacent upward transitions and seven adjacent downward transitions, each containing twenty phase-aligned, three-picture native-interlaced closed GOPs.  The helper selects a transition GOP whenever its existing hysteretic one-level slew rises or falls and retains the old steady-stream behavior for version-one packs; idle level zero, the overlay cap, transport slicing, RMS thresholds and media lifecycle are unchanged.  The generator applies the grade ramp per frame and verifies all 440 index entries plus exact file-size accounting before publishing.  Independent FFmpeg decoding measures the first zero-to-one rise at mean luma 56.3227, 61.6911 and 63.2825 between steady endpoints 52.8588 and 63.1943, while the reverse transition measures 61.7344, 56.5000 and 53.0892.  Optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer selector tests pass, with LeakSanitizer unavailable under the local ptrace wrapper; strict native compilation, audio UI, seek and exact-pack idle plus MP3, WAV, FLAC and Ogg integrations pass for both version one and version two.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `f2ab5cd997363ec678371674c13e14428ae79ea81a1d883a13dfa4ed2ace3e95`, and deterministic generation produced the 11,201,580-byte `host/build/MediaPlayer_Visualizer.mmpvis` with SHA-256 `4e1c4f6eeaf2e6b781401b15902b60bd4d38e8254f4f5220a3133b3f5d84753f`; Main, protocol, RTL and RBF remain unchanged.

#### Next Steps:

Exit the MediaPlayer core so the idle helper is not using either file, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/linux/MediaPlayer_Visualizer.mmpvis` with the two new artifacts, preserve executable mode on the helper, and retain the current `MiSTer_MediaPlayer` and `MediaPlayer_20260904.rbf`.  Re-enter the core to verify the steady idle loop, play an audio file or Audio CD past the ten-second overlay timeout and compare several loud and quiet passages for smooth approximately 100-millisecond grade transitions in both directions, then confirm DVD and MPEG-2 takeover before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/audio_visualizer.c
- host/arm/audio_visualizer.h
- tools/generate-audio-visualizer.py
- tools/test_audio_visualizer.c

#### Status:

- [x] Built
- [ ] Passed

---

## 963 COMMIT Unreleased 8d0ab99 2026-09-04T01:53:01-07:00

#### Coming From:

Unreleased 8d0ab99

#### Purpose:

Evaluate the first idle-visualizer hardware run and diagnose the reported sputtering DVD-menu audio.

#### Outcome:

The user confirms that source `8d0ab99` displays the visualizer while the core is idle and that a physical Coming to America DVD reaches its visible authored menu, establishing idle startup and DVD takeover on hardware.  The fresh helper log proves this playback launched with `audio output spdif`, selected AC-3 private substream `0x80`, and therefore emitted IEC 61937 AC-3 bursts for an external S/PDIF decoder rather than decoded stereo PCM; equipment interpreting those bursts as ordinary audio produces the reported sputtering or noise.  The source change did not alter status bit 126 or its HDMI/S/PDIF mapping, and the checksum-valid schema-21 capture reports 59 displayed pictures, 58 swaps, zero PCM protocol errors, zero audio underruns and zero transport blocks, so it supplies no evidence of an idle-handoff PCM residue or transport starvation.  The menu screenshot and overlay telemetry are valid, with one complete 86,400-byte overlay plane and no overlay protocol error.  The 938,734-byte log, 691,864-byte screenshot and 844-byte sidecar have SHA-256 `3b95414481949f5300d0daad613c87177bd3da30f5b6bbca3483655bfe4d914c`, `435f70170d31f7aebb0d246394c8b452c905b3fa2339096ee712098c1f06c010` and `9b60f83b41228a9c1c9026ad9281de3d78e470624bb6d3ea040e06884c3b21af`; no runtime source was changed.

#### Next Steps:

Set the core menu's `Audio Output` option to `HDMI`, reload the same DVD and capture fresh results while the menu plays; the new helper log must say `audio output hdmi (decoded stereo PCM)`.  If that run is clean, treat the sputtering as expected undecoded S/PDIF passthrough and continue idle-background qualification through DVD, MPEG-2, audio-file and Audio CD takeover and return; if it still sputters with HDMI proven in the log, diagnose the decoded-PCM scheduler from that trace before proposing a source change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 962 COMMIT Unreleased 8d0ab99 2026-09-04T01:23:00-07:00

#### Coming From:

Unreleased 3e4f7ea

#### Purpose:

Keep the existing MPEG-2 visualizer loop active whenever the MediaPlayer core is idle while preserving immediate video takeover and the current ten-second audio-player overlay.

#### Outcome:

Source `8d0ab99` adds an `idle:` helper source that validates and continuously emits the existing closed-GOP visualizer pack at its encoded cadence from a monotonic-time virtual sample clock without silent PCM or an audio-player overlay.  Isolated Main now starts that background after recognizing the MediaPlayer core, replaces it for every physical-disc or file selection, and restores it after playback finishes or fails while preserving the prior replay source and the established audio-file and Audio CD overlay timeout.  A failed idle helper or missing asset is suppressed until a successful media cycle or core reload so it cannot create a polling fork loop.  Strict native, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer coverage passes together with focused idle pacing, audio UI, audio-file, CDDA, DVD, seek, output and Main lifecycle regressions, and the complete Main patch stack applies and cross-builds against pinned upstream `0a8fb44`.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `f4d392f08d2538b9b2c38e285cb4925f6bc10133915060acd97f6aa7f8559696` and the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `58971dd7b558238fe6dafca269c36d5e595e7ff326e32ee6e3f50a093b006aa1`; no RBF, RTL, menu-string or visualizer-asset change was required.

#### Next Steps:

Exit MediaPlayer, replace `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MiSTer_MediaPlayer` with the two new build artifacts, preserve executable permissions, retain the accepted `MediaPlayer_20260904.rbf`, visualizer pack and per-core INI, and reboot because Main changed.  Validate that the visualizer appears on core entry and behind the OSD, DVD and MPEG-2 sources take over immediately, audio-file and Audio CD playback retain the player overlay for about ten seconds before revealing the visualizer, and the idle background returns after finite playback before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_audio_file_seek.py
- tools/test_main_cdda.py
- tools/test_main_seek_lifecycle.cpp

#### Status:

- [x] Built
- [ ] Passed

---

## 961 COMMIT Unreleased 3e4f7ea 2026-09-04T00:07:31-07:00

#### Coming From:

Unreleased 3b2a0ca

#### Purpose:

Replace marker-file optical launching with a hierarchical loader menu that starts physical DVD and Audio CD media directly while retaining separate DVD ISO, MPEG-2 video and audio file pickers.

#### Outcome:

The user reports that source `3b2a0ca` successfully plays a physical Audio CD, accepting the underlying CDDA path for the tested disc.  Source `cde9841` replaces marker-file launching with MiSTer's numbered menu pages for `Load Physical Disc` and `Load Disc Image`; physical `Video DVD` and `Audio CD` now invoke `dvdmenu:/dev/sr0` and `cdda:/dev/sr0` directly through isolated Main, the image submenu exposes an ISO-filtered `Video DVD` browser, and `Load MPEG-2 Video File` and `Load Audio File` remain immediate filtered browsers.  All routes normalize to FPGA stream index one, Audio CD image support remains deliberately omitted pending a CUE/BIN or equivalent backend, and the obsolete `.dvd` and `.cd` marker assets are removed without changing the helper, decoder RTL or media protocol.  The patched Main stack applies cleanly to pinned upstream Main `0a8fb44`, focused direct-loader and retained NTSC-native static contracts pass, and GNU 10.2.1 produced the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `35ac7ca233bf1cdf074409ed781b6ee0367a63e31f00d394b5e0eced26a5a8e4`; the existing helper remains the accepted 974,244-byte artifact with SHA-256 `35a369ed1c3f30197f0ce663da67a0c171dbf132c34d6c131c859aa626663dd7`.  Seed 25 failed only global setup at negative 0.110 ns while hold, recovery, removal, minimum pulse width, decoder setup and video setup remained positive; the single authorized seed-26 commit `3e4f7ea` passes global setup at positive 0.143 ns, hold at positive 0.146 ns, recovery at positive 3.818 ns, removal at positive 0.470 ns, minimum pulse width at positive 0.925 ns, decoder setup at positive 0.841 ns and video setup at positive 2.541 ns with 38 percent average and 57 percent peak interconnect usage.  The accepted 4,470,016-byte `host/build/MediaPlayer_20260904.rbf` has SHA-256 `4896c2b50345e3f29c72435dce0c4188ae2b502465eeb59c37c25930002103b8`; the new menu integration awaits MiSTer hardware validation.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_20260904.rbf` as `/media/fat/MediaPlayer_20260904.rbf` and install `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer`, while retaining the existing helper, visualizer and per-core INI.  Remove `/media/fat/games/MediaPlayer/Video DVD.dvd`, `/media/fat/games/MediaPlayer/Audio CD.cd` and any obsolete `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`, then reboot and validate both physical-disc choices, DVD ISO selection, MPEG-2 file loading, audio file loading, DVD menus and playback, Audio CD transport, Bob or Weave output and the experimental native-NTSC path before marking this source hardware-passed.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- MediaPlayer.sv
- README.md
- assets/Audio CD.cd
- assets/Video DVD.dvd
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 960 COMMIT Unreleased 3b2a0ca 2026-09-03T22:32:01-07:00

#### Coming From:

Unreleased 5fc7a1e

#### Purpose:

Add direct physical Audio CD playback through the existing standalone-audio interface and combine its picker change with the pending naming RBF build.

#### Outcome:

Source `184b2fa` adds the `Audio CD.cd` marker to the existing audio picker, maps it in isolated Main to `cdda:/dev/sr0`, inventories the disc table of contents through Linux optical-drive controls, skips data tracks and reads audio sectors digitally as native 44.1 kHz signed stereo PCM for the existing audio UI, visualizer and in-band transport.  The helper exposes playable tracks as one continuous timeline, retains fixed-time seeking and maps previous or next commands to audio-track boundaries through the established READY/GO lifecycle; the decoder RTL and transport protocol are unchanged.  Focused CDDA optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer coverage passes, as do strict native compilation, the isolated Main CDDA contract and retained AC-3, file-audio, UI, visualizer, DVD random-access, SPU, reserve, staging, Program Stream seek, Main seek, LPCM-skip and real MP3, WAV, FLAC and Ogg integrations.  GNU 10.2.1 produced the 974,244-byte static stripped ARMv7 `host/build/MediaPlayer_Helper` with SHA-256 `35a369ed1c3f30197f0ce663da67a0c171dbf132c34d6c131c859aa626663dd7` and the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `06339d6b5ac2fa216c2be47062ba7e5d8b178c0bd4aa950562c25ea3fedfdc3f`.  The initial seed-24 Quartus build failed only global setup at negative 0.606 ns while decoder and video setup passed at positive 0.984 ns and positive 1.097 ns; the single authorized source-`3b2a0ca` seed-25 retry passes global setup at positive 0.118 ns, hold at positive 0.247 ns, recovery at positive 3.578 ns, removal at positive 0.580 ns, minimum pulse width at positive 0.925 ns, decoder setup at positive 0.250 ns and video setup at positive 1.662 ns, with peak interconnect reduced from 67 percent to 60 percent.  Its worst path is the pre-existing `ascal` vertical-accept-to-address DSP calculation, whose 6.596 ns data delay is 78 percent cell delay and 22 percent routing rather than a general interconnect failure.  The resulting 4,477,416-byte `host/build/MediaPlayer_20260903.rbf` has SHA-256 `686957247693c1556aee9018ff4be19e08e1969225fe35e1063ffb67c597d74e`; no physical Audio CD was available for local hardware acceptance.

#### Next Steps:

Exit MediaPlayer, install `host/build/MediaPlayer_20260903.rbf` as `/media/fat/MediaPlayer_20260903.rbf`, `host/build/MiSTer_MediaPlayer` as executable `/media/fat/MiSTer_MediaPlayer`, `host/build/MediaPlayer_Helper` as executable `/media/fat/linux/MediaPlayer_Helper`, `assets/Video DVD.dvd` as `/media/fat/games/MediaPlayer/Video DVD.dvd` and `assets/Audio CD.cd` as `/media/fat/games/MediaPlayer/Audio CD.cd`, remove the obsolete `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`, preserve the current visualizer and per-core INI, then reboot.  Load an Audio CD through the audio picker and require clean first-track playback, UI and visualization, previous and next track selection, fixed-time seeking, pause and end-of-disc behavior, including a mixed-mode disc if available; then confirm ordinary DVD loading, menus, chapter controls, Bob or Weave output and the retained experimental native-NTSC mode before marking this source hardware-passed.  Treat a future scaler timing-improvement cycle separately by investigating the registered `ascal` address-DSP path rather than weakening the timing gate.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.qsf
- MediaPlayer.sv
- README.md
- assets/Audio CD.cd
- docs/BUILDING.md
- docs/TEST_INSTRUCTIONS.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/cdda_audio.c
- host/arm/cdda_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_cdda_audio.c
- tools/test_main_cdda.py

#### Status:

- [x] Built
- [ ] Passed

---

## 959 COMMIT Unreleased 5fc7a1e 2026-09-03T22:22:02-07:00

#### Coming From:

Unreleased d34c292

#### Purpose:

Rename the DVD picker and physical-drive launcher to concise user-facing labels without changing playback routing.

#### Outcome:

Source `5fc7a1e` replaces the core-menu label `Run DVD-Video` with `Load Disk`, renames the tracked launcher from `USB DVD Drive.dvd` to `Video DVD.dvd`, and updates current setup and testing documentation plus the Unreleased changelog.  Patched Main continues mapping every selected `.dvd` file to `dvdmenu:/dev/sr0`, so the helper protocol, source selection and DVD playback behavior remain unchanged; the immutable v0.9.0 release manifests and package hashes retain the historical launcher name they actually shipped.  Static checks confirm the new menu string, asset contents and extension routing, and the source commit is pushed without staging the user's unrelated local changes.

#### Next Steps:

Retain source `5fc7a1e` as the naming boundary and incorporate its pending RBF change into the approved Audio CD development cycle rather than performing a separate Quartus compile.  The combined cycle should add `.cd` picker support and physical CDDA playback, rebuild the affected Main and helper, then perform one clean timing-gated Quartus build with the established seed unless timing requires the single authorized reseed.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- assets/USB DVD Drive.dvd
- assets/Video DVD.dvd
- docs/BUILDING.md
- docs/MEDIA_CONVERSION.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 958 COMMIT Unreleased d34c292 2026-09-03T21:59:59-07:00

#### Coming From:

Unreleased d34c292

#### Purpose:

Package the source-`d34c292` native NTSC output boundary for controlled HDMI, HDMI-to-SDI and analog forum testing.

#### Outcome:

The 1,378,292-byte forum archive `host/build/MiSTer_MediaPlayer_NTSC480i_d34c292.zip` has SHA-256 `621cf865c1561f6f87a3ded01bc3c95f00416acd508f2b561e5c4a7dc4aaefdc` and passes ZIP integrity plus every internal SHA-256 check.  It contains the source-`d34c292` 1,182,684-byte `MiSTer_MediaPlayer`, the source-`f93c6ba` 970,148-byte static helper needed for the latest automatic-menu pacing behavior, the per-core INI fragment, source provenance, project and dependency licences, and a dedicated installation, rollback and reporting guide.  The guide separates ordinary Bob/Weave HDMI as the control, native 525i59.94 direct HDMI for sinks that explicitly accept 480i, HDMI-to-SDI through the Decimator MD-LX with downstream external processing, and native 15 kHz RGB or YPbPr analog output; it warns that a blank unsupported HDMI monitor is inconclusive and that scaled screenshots are not a reliable Direct Video capture.  The unchanged RBF, visualizer and USB DVD launcher are intentionally absent so testers retain their installed matched v0.9.0 set, and the official `/media/fat/MiSTer` is never replaced.

#### Next Steps:

Distribute `MiSTer_MediaPlayer_NTSC480i_d34c292.zip` as an unreleased forum hardware test and have each tester verify the archive manifest, preserve the official Main, install the two isolated executables and report the exact display, converter and processor models.  Require a normal Bob/Weave HDMI control first, then record whether direct HDMI or the MD-LX identifies and locks 480i or 525i at 59.94 Hz, whether menus, titles and audio remain continuous, whether 4:3 and 16:9 are identified correctly, and whether field motion reaches the external processor intact; compare with a 15 kHz analog CRT where available and return the results before changing the ADV7513 policy.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 957 COMMIT Unreleased d34c292 2026-09-03T21:18:06-07:00

#### Coming From:

Unreleased f93c6ba

#### Purpose:

Expose the proven native NTSC raster as standards-signalled 525i59.94 HDMI for external processing through the Decimator MD-LX.

#### Outcome:

Source `d34c292` adds an experimental NTSC-only direct-HDMI boundary to the isolated patched Main without changing the decoder, helper or RBF.  It activates only for the reported `MediaPlayer` core with per-core `direct_video=1`, divides the core's 54 MHz ADV7513 input clock by two, samples every 13.5 MHz content pixel twice at 27 MHz, advertises manual x2 pixel repetition without multiplying that already-correct link clock, selects negative-sync CTA VIC 6 or 7 from status bit 121, identifies BT.601 and limited RGB, forces the full-to-limited CSC and uses CTS 27,000 for 48 or 96 kHz audio.  Generic Main behavior remains behind the existing branches, the aspect and AVI state refresh without a scaler mode change, the tracked INI fragment leaves Direct Video commented by default, and the README and architecture document the initial native-interlaced-only test boundary.  The new static register-policy test passes, all three Main patches apply cleanly in order to pinned upstream `0a8fb44`, and GNU 10.2.1 builds the 1,182,684-byte stripped ARMv7 `host/build/MiSTer_MediaPlayer` with SHA-256 `6aeded222240b6abd324b5d1525ce88d4ef6d56984a80c1d9d0332aaa2675462`.

#### Next Steps:

Replace only `/media/fat/MiSTer_MediaPlayer`, retain the accepted helper and RBF, add `direct_video=1` beneath the existing `[MediaPlayer]` section, reboot and test native-interlaced NTSC DVD material through MiSTer's HDMI port and the Decimator MD-LX.  Require the MD-LX and downstream processor to identify and hold 525i59.94, confirm continuous picture and HDMI audio through menus and title playback, exercise both 4:3 and 16:9 signalling, inspect field motion for intact interlace rather than Bob or Weave, and remove `direct_video=1` after the test because progressive and standalone-audio output are intentionally not qualified in this first boundary; return the updated results before considering 576i, 60.000 Hz or a live core-menu switch.

#### Files Modified:

- CHANGELOG.md
- README.md
- assets/MiSTer_MediaPlayer.ini.fragment
- docs/ARCHITECTURE.md
- host/build_arm_stack.sh
- host/main_mister/0003-mediaplayer-ntsc-480i-hdmi.patch
- tools/test_main_ntsc_480i.py

#### Status:

- [x] Built
- [ ] Passed

---

## 956 COMMIT Unreleased f93c6ba 2026-09-03T20:32:38-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Keep automatic-menu PCM below its safety ceiling without recreating the long downstream audio lead.

#### Outcome:

Source `f93c6ba` retains source `67ce19d`'s reserve-drain pacing boundary and replaces its fixed one-batch fallback ceiling with pressure-driven 2,048-frame runs.  Each stalled-timestamp automatic-menu pass drains held PCM to a low watermark equal to half the configured hold limit when that is above the existing 8,192-frame scheduling reserve, which is 96,000 frames at the default four-second limit; the normal advancing-timestamp scheduler, ordinary title reserve, overlay priority and transport byte order remain unchanged.  This gives the default route two seconds of hold-limit headroom, bounds the initial sink-paced catch-up from the observed 183,808 frames to approximately 1.83 seconds, and makes subsequent work proportional to each newly decoded Program Stream audio burst instead of permitting a net-growing hold.  The production fixture proves that one fallback pass drains 48,000 held frames to its 24,000-frame test watermark through the real reserve, then absorbs a further 12,000-frame burst while preserving the watermark and every emitted sample; the retained long-menu and advancing-PTS controls pass.  Strict optimized, AddressSanitizer with leak detection disabled for the ptrace environment, UndefinedBehaviorSanitizer and GCC analyzer checks pass apart from the known audio-overlay allocation false positive, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests.  Twenty repeated production runs, one hundred menu-hop runs, fifty output-reserve runs and twenty LPCM-skip integrations pass, and real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `70cfc0c59957bfaf8ca1b536f3746537c76e4108551a4b28c359a3ebcefa8785`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`f93c6ba` artifact and retain the current per-core Main, RBF and visualizer.  Let Futurama run through all intros into its root menu, require one fallback diagnostic containing `watermark=96000 reserve=8192 paced_batch=2048`, and confirm the menu appears and animates with continuous intelligible audio, a responsive selector, no hold-limit diagnostic and no helper termination.  Exercise its nested episode menu and selected-title playback, then repeat automatic-menu entry on several other discs and return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 955 COMMIT Unreleased 67ce19d 2026-09-03T20:28:11-07:00

#### Coming From:

Unreleased 67ce19d

#### Purpose:

Qualify source `67ce19d` on Futurama's automatic root-menu transition and isolate its failure before menu playback.

#### Outcome:

The physical source-`67ce19d` run rejects the one-batch fallback admission policy while validating its sink-pacing boundary.  All three finite intro boundaries complete, the silent-video lookahead classifies and releases, the automatic menu inherits the continuous scheduling epoch at 41.085422 seconds, the first translated audio and video horizon remains fixed at PTS 647,273, and a valid 86,400-byte overlay plane commits without ordering error.  Fallback activates at 41.376416 seconds with 183,808 held PCM frames and no timestamp-derived audio due; draining the output reserve before each scheduled run succeeds, but admitting only one 2,048-frame batch per Program Stream scheduler pass is slightly slower than the disc's decoded AC-3 bursts.  Held PCM consequently rises to 193,024 frames, crosses the unchanged 192,000-frame safety ceiling about 4.37 seconds later, and deliberately terminates the helper with exit status one at 45.764969 seconds before the menu can play.  Main reports `helper-error`; there is no reserve-pacing failure, audio underrun, PCM protocol error, decoder error or overlay ordering error.  The checksum-valid schema-21 snapshot is an earlier settled-overlay capture with 127 displayed pictures, 126 swaps, zero decoder and PCM errors, zero underruns and one valid visible menu overlay; the later screenshot shows the black post-exit diagnostic display.  The 1,083,151-byte log, 11,711-byte screenshot and 844-byte telemetry sidecar have SHA-256 `c74ffb51e544a2ab233fc66164d2ec00694e6c14fba86c4b3c4757e3a842add0`, `915763d7b660d4b82ef007c02f78f655c43c59c3dff4eccea59c6769a9c1b4f8` and `335b0923d031579f9cfb03c19d8320563c5089243b762857569ca1a72ad05f46`.

#### Next Steps:

Retain the source-`67ce19d` reserve-drain pacing boundary but replace its fixed one-batch ceiling after user approval with a pressure-driven bounded burst that emits sink-paced 2,048-frame runs until held PCM reaches a safe low watermark below the four-second ceiling.  Bound each admission interval so menu input remains responsive, add production regressions in which a single Program Stream packet decodes more PCM than one batch and verify that held audio falls rather than grows under a stalled timestamp, then rerun strict native, analyzer, sanitizer and retained DVD/audio suites and build only a new static ARM helper for Futurama plus the broader physical-disc menu test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 954 COMMIT Unreleased 67ce19d 2026-09-03T20:08:11-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Bound automatic-menu fallback output latency across physical DVDs without weakening normal title buffering.

#### Outcome:

Source `67ce19d` adds one fallback-aware PCM emission boundary: while a physical DVD's automatic menu is using sink pacing, each scheduled PCM run first drains the asynchronous output reserve, and the fallback itself admits at most one 2,048-frame batch per scheduler pass.  This prevents the four-megabyte normal lane from absorbing approximately twenty seconds of decoded PCM and lets the pipe and unchanged FPGA FIFO credit establish delivery rate, while ordinary advancing-timestamp scheduling, normal title use of the complete optical-stall reserve, overlay priority and byte order remain unchanged.  The production regression starts with 24,000 held frames, proves the first exhausted-target pass emits exactly one batch, repeatedly reaches the exact 8,192-frame reserve and reconstructs all 15,808 emitted stereo frames sample-for-sample through the real reserve; its advancing-PTS control restores the original scheduler.  Strict optimized, AddressSanitizer, UndefinedBehaviorSanitizer and GCC analyzer checks pass, as do the native helper capability probe, retained DVD random-access, SPU, menu-hop, overlay, stage, output-reserve, AC-3, LPCM-skip, audio UI, visualizer and seek tests, twenty repeated production runs, one hundred menu-hop runs and fifty output-reserve runs.  Real MP3, WAV, FLAC and Ogg seek integrations pass with and without the visualizer.  GNU 10.2.1 builds the 970,148-byte stripped static ARMv7 helper `host/build/MediaPlayer_Helper` with SHA-256 `6b7524f082e81e3b6f9e49064deea7950804438485bed366e7089b1b434b2da7`; Main, protocol, RTL and RBF are unchanged.

#### Next Steps:

Replace only `/media/fat/linux/MediaPlayer_Helper` with the source-`67ce19d` artifact and retain the current per-core Main, RBF and visualizer.  Test Futurama plus several other physical DVDs that previously delayed at automatic menus; each affected route should log one fallback activation containing `paced_batch=2048`, reach moving menu video and a usable selector without the prior long apparent freeze, retain continuous intelligible audio and show no pacing failure, hold-limit diagnostic, underrun or helper termination.  Launch titles and exercise chapter navigation on at least one disc to confirm the unchanged ordinary reserve path, then return the updated log, screenshot and telemetry for hardware qualification.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- tools/test_dvd_overlay_output.c

#### Status:

- [x] Built
- [ ] Passed

---

## 953 COMMIT Unreleased 5f1cf92 2026-09-03T19:51:25-07:00

#### Coming From:

Unreleased 5f1cf92

#### Purpose:

Qualify source `5f1cf92` across Futurama's automatic root menu, nested episode-selection menus and selected-title playback.

#### Outcome:

The physical source-`5f1cf92` run passes hardware validation.  All three finite intro boundaries drain and release, automatic menu entry at 35.059491 seconds preserves the continuous decoder epoch, and the bounded fallback activates with 183,808 held PCM frames before settling near its 8,192-frame reserve without a hold-limit diagnostic, signal-nine termination or audio underrun.  The root menu initially appears frozen while the output path consumes an approximately 1.16 to 1.21 million-frame PCM scheduling lead, about 24 to 25 seconds, but then animates normally and accepts directional input; this is observable catch-up latency rather than a decoder deadlock.  Root-menu activation, nested episode-selection transitions and their overlay transactions complete, the final selection leaves the menu at 327.905704 seconds, and the chosen episode sustains advancing presentation timestamps for more than ninety seconds with over 77 MiB of helper video delivered.  The user confirms the menus are navigable and the selected episode looks and sounds good.  The checksum-valid schema-21 snapshot reports 128 displayed pictures, 127 swaps, zero decoder and PCM protocol errors, zero audio underruns and a valid overlay, while the updated screenshot visibly captures episode playback.  The 17,823,653-byte log, 1,386,067-byte screenshot and 818-byte telemetry sidecar have SHA-256 `4e31c76f52ab03fa55a38027c314064306d4ff9ac8d8b5a3056666d35e41eea7`, `e6511bd6c54ccab344419b1c703b38d61430c1073790293f1d11fef66e0273ce` and `9e6ede6ae979d7a24a16133f9ec1237dc3c4f4dda7bc444c4a84494f26052633`.

#### Next Steps:

Retain source `5f1cf92` and its helper as the accepted hardware baseline.  Treat the initial automatic-menu catch-up as a future latency optimization rather than reopening the functional fix, and broaden physical-disc regression to other automatic menus, still menus and supported title audio before the next release boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
