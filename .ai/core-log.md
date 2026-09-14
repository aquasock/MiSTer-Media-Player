## 51 COMMIT Unreleased bcddb20 2026-09-14T03:36:49-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Record completed direct-seek timing qualification and deliver the preferred seed 61 candidate.

#### Outcome:

All three bcddb20 builds compiled and passed the 159-register CDC audit. Seed 61 passes all four timing corners with minimum setup +0.205 ns, hold +0.066 ns, recovery +2.388 ns, removal +0.098 ns and pulse width +0.925 ns. It uses 41223 ALMs, 56345 registers, 482 RAM blocks, 69 DSP blocks and three PLLs. The preferred RBF is results/hardware-test-bcddb20/seed61/MediaPlayer_20260914.rbf, hash verified as 98a3957e92ffb71112a31d373082854673a45c97fb5c5169c2b48971e75a2f24. Seeds 52 and 87 fail setup at -0.377 and -0.327 ns respectively; their other timing categories pass, and their packaged files are explicitly unqualified. Batch durations were 1294, 1424 and 1254 seconds for seeds 52, 61 and 87. Per-corner evidence remains under results/build-bcddb20-20260914-031001; the handoff includes checksums, build-info files and testing instructions. Documentation commit d3f141e identifies the candidate and corrects the remaining stale reference to the removed seek-fault observer; runtime source remains bcddb20. The earlier 90 percent baseline was an ALMs-needed estimate: 0b6eb0e seed 87 physically placed 40431 ALMs, versus 41119 in bcddb20 seed 87, a 688-ALM increase across playback/seek development. Most of the apparent percentage jump came from changed dense-packing recovery estimates. No new build or deployment was started.

#### Next Steps:

Have the user load seed 61 and test short and long direct seeks in both directions, paused seeks and resume, first-time distant destinations, EOF, reload, OSD access and audio alignment. Hardware acceptance remains pending; retain a229a01 seed 87 as rollback.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 50 COMMIT Unreleased bcddb20 2026-09-14T03:10:33-07:00

#### Coming From:

Unreleased bcddb20

#### Purpose:

Build the telemetry-reduced direct-seek core with three placement seeds.

#### Outcome:

The user authorized the next build batch. Local master and GitHub were verified synchronized, and clean exports of source bcddb20 started at 2026-09-14T03:10:01-07:00 with seeds 52, 61 and 87 and six workers each under results/build-bcddb20-20260914-031001. Only seed and worker settings differ from committed source. The per-batch result checker now requires 159 CDC registers and identifies bcddb20 as its source, with all four timing corners still mandatory. Compilation is running; no new RBF or measured resource savings are available yet. The MiSTer remains unchanged.

#### Next Steps:

Finish the authorized batch, inspect resource fit and all timing classes, and package the best completed RBF with source, seed, checksum and qualification status. Retain the prior a229a01 seed 87 rollback and let the user load and validate the selected new build.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 49 COMMIT Unreleased bcddb20 2026-09-14T03:08:16-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Remove the added seek-fault telemetry hardware to recover placement capacity.

#### Outcome:

Source bcddb20 removes production instantiation of the persistent seek-fault observer, its 449-bit clock-domain mailbox and screen renderer, connects RGB directly to the retained cadence output, and removes the observer file from the Quartus project. Those three removed instances accounted for 712 combinational ALUTs and 1291 registers in the previous seed 87 synthesis hierarchy; these are attribution figures, not measured new fitted savings. Compact playback-health telemetry, audio comparison controls and playback/seek control signals remain. Standalone historical observer RTL/tests and screenshot decoding remain available outside the production project. The timing audit removes only the deleted mailbox and now requires 159 synchronizer registers instead of 165. Current testing instructions distinguish historical seek snapshots from current production behavior. Compact/detailed retained-field equivalence, actual RGB screenshot decoding, corruption rejection and legacy schemas pass. Direct-seek observer, VBR/bounded search, open-GOP byte filtering and asynchronous paused forward/backward restart regressions also pass. Evidence is under results/telemetry-removal. No Quartus build or hardware deployment was performed.

#### Next Steps:

Build source bcddb20 when authorized, measure actual fit and resource savings, and require all timing corners plus the 159-register CDC audit before selecting a hardware candidate. The old build-summary helper requires 165 checks and must be adapted for this source. Preserve a229a01 seed 87 as the timing-qualified rollback.

#### Files Modified:

- MediaPlayer_top_07.svh
- files.qip
- tools/phase1p_timing.tcl
- CHANGELOG.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 48 COMMIT Unreleased 3ab6615 2026-09-14T03:06:59-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Record the completed reduced-source placement results and remaining device-capacity shortfall.

#### Outcome:

All three source 3ab6615 builds failed fitter LAB capacity and produced no RBF. Seeds 52, 61 and 87 required 4196, 4209 and 4192 LABs respectively against 4191 available, leaving seed 87 one LAB over capacity. The partial fitter ALM estimates were 41561, 41708 and 41542; these are incomplete-fit figures, not successful placement or timing qualification. Seed 87 synthesis confirms the observer dropped from 429 to 314 registers and 77 to 74 combinational ALUTs, while search logic dropped from 487 to 417 ALUTs with 332 registers unchanged. Thus the two edited modules saved 115 registers and 73 combinational ALUTs. The previous seed 87 required 4198 LABs; the reduction helped packing but did not yield a legal fit. Timing and fitted CDC qualification could not run. Evidence and failure-summary.json are under results/build-3ab6615-20260914-025405. No further builds were launched and the MiSTer was not changed.

#### Next Steps:

Plan another bounded resource reduction to create packing margin before repeating the three-seed build, preserving seek behavior and existing regression coverage. The prior a229a01 seed 87 remains the timing-qualified hardware rollback; there is no new direct-seek binary to test.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 47 COMMIT Unreleased 3ab6615 2026-09-14T02:54:33-07:00

#### Coming From:

Unreleased 3ab6615

#### Purpose:

Build and qualify the reduced direct-seek source using the standard three placement seeds.

#### Outcome:

The user authorized proceeding with builds after the reduction tests passed. GitHub and local master were verified synchronized, then clean exports of source 3ab6615 started at 2026-09-14T02:54:05-07:00 for seeds 52, 61 and 87, with six workers each, under results/build-3ab6615-20260914-025405. Only seed and worker settings differ from committed source. The batch runs compile followed by focused timing; result packaging requires all four timing corners and the 165-register CDC audit. No replacement RBF exists yet and the MiSTer has not been changed.

#### Next Steps:

Inspect synthesis and fitting resource usage, finish the three builds and timing audits, then package the best completed candidate with exact source, seed, hash and qualification status. Preserve failed artifacts and the a229a01 seed 87 rollback. Hardware testing remains with the user; do not deploy automatically.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 46 COMMIT Unreleased 3ab6615 2026-09-14T02:49:40-07:00

#### Coming From:

Unreleased 2fac1cb

#### Purpose:

Reduce duplicate direct-seek registers and search arithmetic after placement exceeded device capacity.

#### Outcome:

Source 3ab6615 removes 115 duplicate register bits by using seek-point output fields as candidate storage until found validates them, then freezing the result. Search midpoint calculation uses one widened sum instead of subtraction plus addition; the timestamp-distance borrow also supplies the before-target comparison. Offset and timestamp widths, PTS association, probe limits and tagged restart handshakes are retained. The new observer regression passes timestamp association, late PTS rejection, stalled input, stable publication, reset and addresses above 4 GiB. Existing VBR, timestamp-wrap, bounded fallback, open-GOP filtering and asynchronous paused forward/backward restart tests pass. All four actual Pee Strike prefix probes exactly match the prior implementation, including landing addresses, byte counts and probe counts; the 300-second case is bounded-prefix EOF fallback, not full-movie playback. Evidence is under results/direct-seek/reduction. The user requested stopping seeds 52 and 61, but both had already exited with fitter capacity failures before the stop attempt; no Quartus jobs remain. Seed 87 had required 4198 LABs against 4191 available. No new RBF was produced, and no new builds or deployment were started. Physical resource savings and timing are not measured by these simulations.

#### Next Steps:

Keep Quartus builds on hold until requested, then compile the reduced source and audit resource fit, timing and all 165 CDC registers before packaging a candidate for hardware acceptance. The previous a229a01 seed 87 remains the available timing-qualified rollback.

#### Files Modified:

- rtl/media_seek_point.sv
- rtl/media_seek_search.sv
- tools/test_media_seek_point.sv
- tools/verify_direct_seek.py

#### Status:

- [ ] Built
- [ ] Passed

---


## 45 COMMIT Unreleased 2fac1cb 2026-09-14T02:31:21-07:00

#### Coming From:

Unreleased 2fac1cb

#### Purpose:

Build the direct-seek implementation after functional validation.

#### Outcome:

The clean source 2fac1cb seed 52/61/87 batch is running under results/build-2fac1cb-20260914-022936. Final two-header MP2 resynchronization passes exact PCM comparisons after one-byte, 582-byte and plausible-false-header 1604-byte prefixes in both reset sessions, alongside compressed-seek history tests. The actual Pee Strike shared-DDR replay resumes at 10.01 seconds with bypass On and 20.02 seconds with bypass Off, without decoder or audio errors; the Off run was repeated with final two-header verification. Normal opening playback also completes and advances both audio and video. Actual prefix searches use three to five probes for 5-, 10- and 20-second targets; the 10-second search consumes 1387169 bytes rather than decoding the opening interval. Directed tests cover VBR, offsets above 4 GiB, timestamp wrap, bounded fallback, EOF, new-file invalidation, asynchronous configuration and retirement, repeated paused forward/backward commands, and open-GOP/PTS byte filtering. These simulations use bounded ideal queues and periodic display ownership, not full vendor CDC or HDMI hardware models. All functional checks are complete; synthesis, fit and timing qualification are pending. The prior a229a01 seed 87 remains available, and the MiSTer has not been reloaded by the agent.

#### Next Steps:

Finish the authorized three-seed batch, audit all corners and 165 CDC registers, compare resources against a229a01, and package the best completed RBF for user hardware testing. Do not start extra placement batches or deploy automatically.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 44 COMMIT Unreleased 2fac1cb 2026-09-14T01:57:50-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Implement direct timestamp-guided file seeking in both directions for the next build.

#### Outcome:

The user-approved revised plan is implemented in 2fac1cb and pushed. Both MPG directions now search byte positions without codec reconstruction, locate timestamped sequence-header/I-picture restart points, and decode a short lead-in. Searches use at most 18 probes with a 4 MiB reader-progress cap per probe; no usable timestamp or raw M2V falls back to byte-zero reconstruction. The reader offset and DDR-drain handshake are retained, with tagged configuration acknowledged before reset release, stale probe replies excluded, and movie timestamp origin preserved. Direct startup discards leading open-GOP B-pictures requiring an unavailable reference and validates two consecutive MP2 headers to recover from partial audio frames. Tests pass for VBR search, offsets over 4 GiB, PTS wrap, EOF fallback, new-file invalidation, asynchronous repeated forward/backward paused seeks, metadata byte filtering and exact PCM recovery after malformed/partial prefixes. Actual Pee Strike prefix probes find 5-, 10- and 20-second destinations in three to five probes. Combined shared-DDR/display-ownership reconstruction resumes at 10.01 seconds with audio bypass enabled; the 20.02-second bypass-disabled run is being repeated with final two-header audio validation. The normal opening playback regression is also finishing. Evidence is under results/direct-seek. User reports no freeze so far with prior bank-release seed 87; new source hardware acceptance and timing/resource qualification remain pending.

#### Next Steps:

Finish the running A/V regressions and compile the next source candidate using the standard three seeds. Audit timing and 165 CDC registers, package the best RBF, and let the user test short and long jumps in both directions, paused destinations, EOF and audio alignment. Do not deploy automatically or start further placement batches without a new request.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- README.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/mp2_decoder.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- rtl/media_seek_point.sv
- rtl/media_seek_search.sv
- rtl/media_seek_video_filter.sv
- rtl/media_session_control.sv
- rtl/mpeg2_new/mpeg2_h262_program_stream_demux.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/phase1p_timing.tcl
- tools/replay_mpg_seek.py
- tools/streams/mpg_replay_control.svh
- tools/streams/mpg_replay_ingress.svh
- tools/test_direct_seek_restart.sv
- tools/test_media_playback_control.sv
- tools/test_media_seek_probe.sv
- tools/test_media_seek_search.sv
- tools/test_media_seek_video_filter.sv
- tools/test_mp2_decoder.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_direct_seek.py
- tools/verify_mp2_seek.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 43 COMMIT Unreleased a229a01 2026-09-14T01:47:05-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Stop the final remaining build at the user's request.

#### Outcome:

Terminated the verified a229a01 build process group; no Quartus jobs remain. Seed 52 had progressed from fitting to timing analysis before cancellation, with compilation completed in 1638.2 seconds; its results are preserved but timing qualification is incomplete. Completed seeds 61 and 87 and their handoff artifacts remain intact. Seed 87 remains the recommended timing-qualified RBF at results/hardware-test-a229a01/seed87/MediaPlayer_20260914.rbf, with minimum setup slack +0.104 ns and all 147 CDC checks passing. The local batch status and handoff README record cancellation, superseding entry 42's instruction to finish seed 52. Hardware acceptance remains pending.

#### Next Steps:

Await the user's seed 87 hardware results. Do not start further builds unless requested.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 42 COMMIT Unreleased a229a01 2026-09-14T01:42:00-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Provide the first timing-qualified RBF containing the seek display-bank release.

#### Outcome:

Seed 87 of the clean a229a01 batch passes all four timing corners: setup +0.104 ns, hold +0.077 ns, recovery +3.845 ns, removal +0.155 ns and pulse width +0.925 ns, with all 147 CDC registers verified. It uses 41216 ALMs, 56163 registers, 480 RAM blocks, 69 DSPs and three PLLs. The hash-verified handoff is results/hardware-test-a229a01/seed87/MediaPlayer_20260914.rbf, SHA-256 b0c4fd56e4051d7898010c2895880d017bcb84a52d7906871675317494b59e7c. Compilation and timing took 1158.6 seconds. Seed 61 finished in 1198 seconds but misses setup by 0.370 ns; all other timing categories and its CDC audit pass. Seed 52 is still fitting. Synthesis adds 67 combinational ALUTs compared with diagnostic source 6eb49e1, with unchanged registers, memory bits, DSPs and PLLs before placement. Documentation commit 89cf3da updates test instructions to the qualified RBF; runtime source remains a229a01. The prior diagnostic seed 61 eventually completed with setup -4.551 ns and is superseded for testing. No new placement batch was started beyond the user-authorized fixed-source three seeds. The MiSTer has not been reloaded or deployed by the agent.

#### Next Steps:

Let the user test seed 87 against the captured Pee Strike freeze and repeated/paused/backward/EOF seeks. Finish auditing the already-running seed 52 without starting further builds. Hardware acceptance remains pending.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 41 COMMIT Unreleased a229a01 2026-09-14T01:18:38-07:00

#### Coming From:

Unreleased a229a01

#### Purpose:

Build the simulation-verified seek display-bank release for hardware testing.

#### Outcome:

The user has now authorized proceeding after the source-only fix, lifting the build hold for this cycle. The standard clean seed 52/61/87 batch will use exact committed source a229a01. Normal playback, repeated retained seeks, EOF seeking, pixel oracles and DDR ownership/drain regressions already pass; no source changes are planned before this batch. The original diagnostic seed 61 is finishing timing independently and does not contain the fix.

#### Next Steps:

Compile the three fixed candidates, audit all timing corners and 147 CDC registers, package hash-verified RBFs, and identify the best completed candidate for the user. Do not deploy or start another placement batch without a further user request.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 40 COMMIT Unreleased a229a01 2026-09-14T01:08:20-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Release stale display-bank ownership during seeking after outstanding DDR reads drain.

#### Outcome:

Source a229a01 adds an optional explicit display-bank release to the DDR arbiter and enables it only for media_seeking in the production core. The retained bank guard clears after outstanding reads drain and DDR is not busy; a same-cycle accepted display request takes precedence. Descriptor ownership, reconstruction state and compressed streams are preserved, and ordinary pause does not release protection. A twin-arbiter transaction regression reproduces the old blocked-write behavior and verifies the fix across all five frame regions, queued display bursts, prediction/stream responses, DDR busy, acceptance priority and re-acquisition. Reconstruction now includes periodic display requests with seek gating: the release-disabled control fails prediction liveness, while the fix completes normal playback, both retained seeks with paused-bank checks and EOF seeking, with 423936 checked pixel samples and zero oracle mismatches in each passing case. Existing DDR routing and mounted-reader/session-restart regressions pass. The exact MPG replay also accepts the display-ownership model and compiles with shared-DDR mode; no additional full movie run is claimed for this source. The pixel runner now requires an explicit completed-oracle marker so a diagnostic watchdog exit cannot be misreported as success. Evidence is under results/seek-display-release. Source is committed and pushed, but no Quartus build or new RBF was produced under the user's instruction. Hardware confirmation and final timing/resource qualification remain pending.

#### Next Steps:

Keep new builds on hold until the user requests them. When a fixed RBF is available, repeat the captured Pee Strike seek near 18.45 seconds, then repeated forward/backward and paused seeks, resume and EOF behavior; preserve first-fault telemetry if any freeze remains.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_06.svh
- docs/TEST_INSTRUCTIONS.md
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- tools/replay_mpg_seek.py
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_seek_display_ownership.sv
- tools/verify_decoder_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 39 COMMIT Unreleased 6eb49e1 2026-09-14T01:07:15-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Record the first detailed hardware seek fault and the display-bank ownership mechanism consistent with it.

#### Outcome:

The user confirms 01 - Pee Strike.mpg is frozen after one seek. The checksum-valid screenshot under results/telemetry-20260914-010332 contains both legacy and persistent seek telemetry. The first observed error is 0x0004, specifically the prediction/reconstruction aggregate bit, with prediction source three and detail nine: the B-picture raster engine timeout. The syntax/publication-chain probe source and P probe source are zero. Entry errors were zero; capture occurred 67432806 decoder cycles, approximately 1.124 seconds, after seek entry, while seeking remained active with audio bypass enabled. Elapsed time was 18.5185 seconds and target 28.4517667 seconds. Video RAM held 1048576 unread words, compressed audio and PCM queues were empty, and audio/transport error flags were clear. Inspection found that forward seek resets the display framebuffer while preserving the DDR arbiter, whose last accepted display-bank ownership remains valid until reset or another display read. A focused simulation of the unchanged arbiter reproduces indefinite scratch-writer blocking after display reads stop and drain, and releases writes when another display bank is accepted. This is a concrete mechanism consistent with the B timeout, not yet an end-to-end reproduction of this hardware occurrence; the snapshot does not expose writer wait or retained reader-bank state and seed 52 is not timing qualified. The shared-DDR combined replay also completed its 2.2-to-12.2-second seek without errors, but lacks display-reader ownership, explaining why that comparison does not test this mechanism. The capture, focused harness, simulation log and diagnosis are preserved together. No runtime source change or additional build was started.

#### Next Steps:

Propose retiring display-bank protection during seek only after outstanding display reads have drained, preserving normal and paused-frame protection. Validate actual seek/display ownership transitions with a regression before any future build; respect the user's instruction not to start more builds.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 38 COMMIT Unreleased 6eb49e1 2026-09-14T01:01:15-07:00

#### Coming From:

Unreleased 6eb49e1

#### Purpose:

Hand off the best completed seek diagnostic RBF and record cancellation of additional builds.

#### Outcome:

The user requested no more builds and to test the best completed RBF. The extra seed 53/62/88 batch under results/build-6eb49e1-20260914-005934 was stopped after verifying its process identity. Original seed 61 remains compiling. Seed 52 is the best completed diagnostic candidate under results/hardware-test-6eb49e1/seed52/MediaPlayer_20260914.rbf, hash verified as 9cabb95b1f045dae7a074f3c918ef8dbbc03b293a5842ca088ef776debfa6047. Its setup slack is -0.264 ns; hold, recovery, removal, pulse width and all 147 CDC checks pass. It uses 40900 ALMs, 55848 registers, 480 RAM blocks, 69 DSPs and three PLLs. Seed 87 misses setup by 1.205 ns. Neither is timing qualified or hardware accepted. Tools-only commits 11d7bac and e02f2a5 correct replay clock ratios, require post-seek audio/video progress, decode full PCM occupancy and add optional production shared-DDR arbitration. The original three combined MPG/audio replays completed the exact Pee Strike 2.2-to-12.2-second seek with audio/video resumption and no reported errors, including audio bypass disabled and varied host stalls/seek phase. A shared-DDR comparison is still running after correcting a behavioral memory-index width limitation before playback; this harness issue is not a hardware freeze reproduction. Hardware source remains 6eb49e1 and the freeze cause remains unresolved.

#### Next Steps:

Let the user test seed 52 with Seek audio bypass On, preserve the first-fault screenshot if it freezes, then reload and compare Off. Do not start more builds. Check the already-running original seed 61 and shared-DDR replay when results are needed.

#### Files Modified:

- tools/replay_mpg_seek.py
- tools/streams/decode_hardware_cadence.py
- tools/streams/mpg_replay_control.svh
- tools/streams/mpg_replay_ingress.svh
- tools/verify_seek_diagnostics.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---

## 37 COMMIT Unreleased 6eb49e1 2026-09-14T00:24:33-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Diagnose the hardware seek freeze with persistent first-fault telemetry and combined program-stream replay.

#### Outcome:

Source 6eb49e1 adds a fourteen-word first-observed seek snapshot, decoder subcodes, seek state, timestamps and queue observations; the new observer survives pause and decoder restart and clears on reset or a fresh file. A diagnostic OSD option disables only compressed MP2 frame bypass for comparison within one RBF. Actual RTL overlay pixels decode successfully, first-fault retention and seek timeout regressions pass, legacy telemetry compatibility passes, and the existing MPG audio/PTS oracle remains exact with no audio errors. The combined exact-file replay includes mounted input, demux, bounded queues, MP2 output, video reconstruction and PTS scheduling, with ideal CDC and separate compressed-video DDR service explicitly outside the hardware-equivalence claim. Source is pushed and the clean seed 52/61/87 batch has started. No freeze fix or hardware acceptance is claimed.

#### Next Steps:

Complete the timing/resource audit and exact-file bypass/seek-phase/storage-stall comparisons, then provide a qualified diagnostic RBF for user hardware testing. Retain first-fault evidence before changing the playback algorithm.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/av_stream_fifo.sv
- rtl/audio/mp2_pcm_fifo.sv
- rtl/media_seek_diagnostics.sv
- rtl/mpeg2_new/mpeg2_av_ddr_fifo.sv
- tools/phase1p_timing.tcl
- tools/replay_mpg_seek.py
- tools/streams/decode_hardware_cadence.py
- tools/streams/mpg_replay_control.svh
- tools/streams/mpg_replay_ingress.svh
- tools/test_av_ddr_fifo.sv
- tools/test_media_seek_diagnostics.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/verify_seek_diagnostics.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 36 COMMIT Unreleased aad072a 2026-09-14T00:15:26-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the freeze telemetry reproduced with fellow.

#### Outcome:

The user reports making fellow freeze. The fresh screenshot and checksum-valid schema-10 decode are under results/telemetry-20260914-001450. Error flags are 0x2004: the same aggregate decoder probe error 0x0004 plus audio timestamp error 0x2000. Audio underrun, MP2 decoding error and transport error are zero; EOF is false. The final recorded picture type is P with temporal reference eleven, unlike the B-picture states in the Pee Strike captures. The snapshot reports 967021 played audio sample pairs, 1259 processed audio frames, transport position 2656842 and 649 completed requests in generation two. The common aggregate decoder error now occurs on both tested movies, while the audio underrun is not consistent across failures. This supports investigating a shared playback/seek path rather than treating the issue as specific to Pee Strike, but does not establish an exact cause or first-fault order. The loaded state was preserved.

#### Next Steps:

Use both captures to guide combined MPG/audio reproduction and add decoder error subcode plus first-fault visibility; do not attribute the failure to audio underrun alone.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 35 COMMIT Unreleased aad072a 2026-09-14T00:13:44-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record decoded telemetry from the repeated freeze on the latest RBF.

#### Outcome:

The user reports both tested RBFs freeze alike and reran the latest candidate until telemetry appeared. The fresh screenshot and checksum-valid schema-10 decode are under results/telemetry-20260914-001304. Error flags are 0x3004: aggregate decoder probe error 0x0004, MP2 output underrun 0x1000 and MP2 output timestamp error 0x2000. Transport error and MP2 decoding error remain zero; EOF is false. The latched snapshot shows 104 associated pictures, 37 reference pictures, final B-picture temporal reference nine, 224 processed audio frames, 157321 played audio sample pairs, 4204428 transport bytes and 1027 requests/completions in generation two. Profiler session_cycles and accepted_bytes are both two following the seek reset; these are not whole-file counts or evidence of two-byte total progress. The same aggregate decoder error recurs across the reported seed tests, but this snapshot cannot order the video and audio faults or identify the decoder subcode. The prior seed-87 snapshot had the decoder error without either audio flag. The loaded state was preserved and no playback changes were made.

#### Next Steps:

Use the repeated decoder failure as the primary reproduction target, include combined MPG/audio flow and host stalls, and capture error subcodes and first-fault ordering rather than infer causality from the latched summary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 34 COMMIT Unreleased aad072a 2026-09-14T00:05:22-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the repeated seek freeze on timing-qualified seed 88.

#### Outcome:

The user reports that seed 88 froze in the same way after seeking. Fresh screenshots at 00:03:48 and 00:04:30 on September 14 show pixel-identical nonblack movie frames, confirming no visible frame change across 42 seconds. Neither screenshot contains decodable telemetry, so the previous seed-87 error 0x0004 cannot be assigned to this occurrence. Evidence and comparison.json are under results/telemetry-20260914-000348 and results/telemetry-20260914-000430. Passing all timing corners has not resolved the observed freeze; root cause remains undetermined. The core and loaded file were left untouched. Seed 88 remains timing qualified but fails hardware playback-control acceptance.

#### Next Steps:

Extend the exact-file reproduction to the combined MPG/audio buffering path and add bounded playback-control state and decoder error subcode visibility if required to distinguish seek, pause, starvation and fatal decoder states.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 33 COMMIT Unreleased aad072a 2026-09-13T23:54:38-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record timing-qualified seed 88 and the first exact-file seek replay comparison.

#### Outcome:

The additional aad072a placement batch completed. Seed 88 passes all four timing corners with setup +0.084 ns, hold +0.103 ns, recovery +3.150 ns, removal +0.231 ns and pulse width +0.925 ns, and passes the 135-register CDC audit. It uses 40462 ALMs, 54737 registers, 480 RAM blocks, 69 DSPs and three PLLs; its RBF SHA-256 is 983a08a8f3b90befc3ea66a4fd9e64393493f7effca1cb62db43716d3522d52e. Seeds 53 and 62 fail setup at -0.131 and -0.059 ns respectively, with other timing categories and CDC passing. Batch times are 1210 to 1221 seconds. Seed 88 is hash verified and marked preferred under results/hardware-test-aad072a, with the unresolved seed-87 decoder failure explicitly documented. An exact-file video-only simulation of Pee Strike completed ordinary playback to four seconds and a forward seek from about 2.2 to 12.2 seconds without the hardware decoder error. Evidence is under results/seek-repro-pee, including bounded-stream provenance, extracted diagnostic harness, logs and diagnosis.json. This is a decoder/reconstruction comparison, not full MPG/audio buffering or FPGA timing reproduction. The initial short-fixture watchdog stopped before the seek; final runs disabled that cutoff and required explicit boundary completion. A log-reading wrapper exceeded memory after baseline simulation completed, but its underlying log records successful completion. The root cause remains unresolved and seed 88 is not hardware accepted. No reset, reload or deployment was performed.

#### Next Steps:

Compare the same early Right-arrow seek on timing-qualified seed 88; if the failure persists, extend the exact-file reproduction to MPG/audio buffering and expose the decoder error subcode needed to isolate it.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 32 COMMIT Unreleased aad072a 2026-09-13T18:40:17-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record faster successful seeks and the early forward-seek decoder failure in Pee Strike.

#### Outcome:

The user requested the best first-batch RBF and received hash-verified aad072a seed 87 with its -0.010 ns setup miss explicitly disclosed. The user reports successful skips are faster, but one Right-arrow press a few seconds into 01 - Pee Strike.mpg froze playback. Captures under results/telemetry-20260913-183433 and results/telemetry-20260913-183457 contain the same schema-10 snapshot with error_flags 0x0004, which maps to the aggregate decoder probe error. MP2 decode, timestamp and underrun flags and transport error are zero. The latched record shows 69 associated pictures, 25 reference pictures, final B-picture temporal reference 22, 105519 audio samples and transport generation two; counters are snapshot values, not live progress. The user identified the exact non-lower MPG. The Git drive contains its MP4 and lower MPG, so a bounded 16 MiB prefix of the exact 887078912-byte MiSTer file was retrieved into results/seek-repro-pee. Its video is progressive 720x480 at 30000/1001. A diagnostic replay of the first 450 pictures is being prepared with a forward seek around 2.2 seconds and detailed decoder error reporting. No reset, reload or deployment was performed. Additional placement seeds 53/62/88 remain running, but timing qualification alone cannot establish that this decoder failure is fixed.

#### Next Steps:

Compare ordinary playback and an in-flight forward seek on the exact opening stream, isolate the aggregate decoder error source, and validate a correction before hardware acceptance; finish the existing placement reports separately.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 31 COMMIT Unreleased aad072a 2026-09-13T18:30:07-07:00

#### Coming From:

Unreleased aad072a

#### Purpose:

Record the first seek-acceleration build results and continue timing qualification.

#### Outcome:

All three aad072a seeds compile and pass the 135-register CDC audit, but none passes setup at every corner. Seed 52 uses 40401 ALMs and 54723 registers with setup -0.311 ns on scaler pixel unpacking; seed 61 uses 40612 ALMs and 54703 registers with setup -0.382 ns on scaler vertical polyphase rounding; seed 87 uses 40339 ALMs and 54709 registers with setup -0.010 ns on scaler horizontal position to picture-enable. Hold, recovery, removal and pulse width pass in all seeds. All retain 480 RAM blocks, 69 DSPs and three PLLs. Synthesis versus 17743f8 uses 147 fewer combinational ALUTs and 30 more registers, with unchanged block memory bits and DSP/PLL counts. Full build plus audits took 1157 to 1197 seconds. Evidence and explicitly unqualified RBFs are under results/build-aad072a-20260913-180758 and results/hardware-test-aad072a. A second clean placement batch of seeds 53, 62 and 88 from the identical aad072a source is running under results/build-aad072a-20260913-182853; playback logic and timing constraints are unchanged. No candidate has been deployed or hardware accepted.

#### Next Steps:

Finish the additional placement batch and deliver a timing-qualified seek acceleration candidate; if no seed qualifies, address the reported scaler timing paths before qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 30 COMMIT Unreleased aad072a 2026-09-13T17:56:12-07:00

#### Coming From:

Unreleased 17743f8

#### Purpose:

Reduce forward seek latency by retaining the current decoder session and validate repeated MPG seeks.

#### Outcome:

Committed and pushed aad072a. Forward seeks retain the live decoder session; backward seeks keep the byte-zero retirement handshake and ignore old-session completion until the new reader starts. Every seek refreshes its audio destination instead of retaining the previous landing time. MP2 frames ending at least 24 ms before the target bypass decoding and synthesis; at least one decoded frame restores finite synthesis history before playback. Tests pass repeated retained-session I/P/B seeks with zero reconstruction mismatches, EOF clamping, three forward/backward asynchronous control cycles with delayed DDR/host retirement, all key modifiers and paused state. The MPG regression bypasses 16 audio frames, resumes at the exact expected sample with no audio errors, preserves all 307021 video bytes and validates 30 picture timestamps. Independent quantizer/joint-stereo tests verify exact post-preroll PCM across timestamp wrap and two reset sessions. Legacy MP2, mounted reader, OSD, raster, refresh and CDC regressions pass. Evidence is under results/build-aad072a-20260913-180758/regressions; clean seeds 52/61/87 are compiling. The user confirms the previous black-screen seek eventually resumed and the earlier display duplication was a monitor issue; previous pause is accepted, faster seeks remain untested on hardware.

#### Next Steps:

Finish all three builds and timing/CDC audits, deliver a qualified RBF, and compare forward skip duration near the start and late in fellow.mpg; verify backward seeks, paused seeks, EOF and audible continuity.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- README.md
- docs/OSD_PLAYBACK_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- rtl/audio/mp2_decoder.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_playback_control.sv
- tools/test_mp2_decoder.sv
- tools/test_mpg_audio_ingress.sv
- tools/test_mpg_audio_playback.sv
- tools/test_playback_restart.sv
- tools/verify_mp2_seek.py
- tools/verify_mpg_audio.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 29 COMMIT Unreleased 17743f8 2026-09-13T17:24:06-07:00

#### Coming From:

Unreleased 62f4741

#### Purpose:

Deliver timing-qualified keyboard pause and seek candidates from the completed three-seed build.

#### Outcome:

All three clean 17743f8 seeds compile and pass the expanded 135-register CDC audit. Seed 52 passes all timing categories at all four corners with minimum setup +0.065 ns, hold +0.116 ns, recovery +2.865 ns, removal +0.260 ns and pulse width +0.925 ns; it is the preferred candidate and uses 40233 ALMs, 54615 registers, 480 RAM blocks, 69 DSPs and three PLLs. Its RBF SHA-256 is be8e0a26c4b3df7d12eb35db4a83067457ae8111551ec9310201cc509fe07607. Seed 61 also passes, with setup +0.005 ns, hold +0.108 ns, recovery +2.611 ns, removal +0.217 ns and pulse width +0.925 ns, using 40530 ALMs and 54621 registers. Seed 87 uses 40413 ALMs and 54622 registers but fails setup at -0.481 ns from ASCAL vertical position to output VS; its other timing categories pass. Total compile plus timing durations are 1161, 1111 and 1169 seconds for seeds 52, 61 and 87. Relative to compact source 0b6eb0e, synthesis adds 906 combinational ALUTs and 534 registers with unchanged memory bits, DSPs and PLLs; larger fitted ALM differences include placement effects. Evidence is under results/build-17743f8-20260913-170250 and hash-verified RBFs plus explicit timing status and instructions are under results/hardware-test-17743f8. The extended EOF seek oracle lands on the last frame with zero pixel mismatches and explicitly completes its paused-display check. Seven-minute numbered raw/MPG clips are under results/playback-control-tests. No new core has been deployed or hardware accepted; 0b6eb0e seed 87 remains the accepted baseline.

#### Next Steps:

Have the user load the preferred seed 52 and verify Space pause/resume, all three Left/Right seek sizes, paused seeking, EOF clamps, repeated commands, OSD isolation, audio continuity and both output refresh rates using the documented vsync_adjust=1 override; record landing times and reconstruction latency.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 28 COMMIT Unreleased 62f4741 2026-09-13T17:17:06-07:00

#### Coming From:

Unreleased 58f74d7

#### Purpose:

Document the required HDMI refresh override and align setup guidance with current playback features.

#### Outcome:

Committed and pushed 62f4741 documenting [MediaPlayer] vsync_adjust=1 even when the global setting is zero. Official MiSTer video documentation confirms mode one follows core refresh while zero uses configured output timing and can introduce repeat/drop cadence conversion. README now describes accepted compact baseline 0b6eb0e seed 87, fully manual aspect and refresh, color matrix selection, keyboard controls pending hardware validation and reconstruction-seek latency. The hardware instructions include the override and no longer claim pause/seek are unexposed. Whitespace review passes; documentation-only changes require no FPGA build and do not modify the running 17743f8 batch.

#### Next Steps:

Use the documented per-core refresh override and finish the current build handoff for hardware playback-control testing.

#### Files Modified:

- README.md
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 27 COMMIT Unreleased 58f74d7 2026-09-13T17:10:11-07:00

#### Coming From:

Unreleased 17743f8

#### Purpose:

Require successful seek-controller completion in the full I/P/B EOF reconstruction regression.

#### Outcome:

Committed and pushed 58f74d7: the full mixed-pixel bench now supports a seek beyond the file end as well as the existing frame-ten seek. Both modes verify the expected landing time and retained paused display bank; control-mode drain observation is extended so the bench cannot finish before the pause/seek checks complete. An explicit completion assertion prevents the pixel oracle alone from being mistaken for control acceptance. The extended EOF mode lands on frame 23 of the 24-picture stream with zero pixel mismatches, no decoder/presentation errors and clean control completion. These are test-only changes and do not change the 17743f8 RBF being built.

#### Next Steps:

Finish the 17743f8 build batch and deliver timing-qualified hardware candidates with the extended regression evidence; the test-only commit requires no separate FPGA build.

#### Files Modified:

- tools/streams/tb_h262_live_raster_soak.sv
- tools/verify_decoder_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 26 COMMIT Unreleased 17743f8 2026-09-13T17:02:36-07:00

#### Coming From:

Unreleased 6b22b6e

#### Purpose:

Retain the frame-rounded seek destination through the audio acknowledgement handoff.

#### Outcome:

Committed and pushed 17743f8 to latch the frame-rounded destination until the next decoder reset. The added assertion fails on 6b22b6e and passes on the corrected controller, including all five source rates and all three seek intervals. All focused keyboard, asynchronous restart, PCM pause/seek, timestamp wrap and legacy sink checks pass. The canceled 6b22b6e process group was confirmed stopped, and replacement clean seeds 52/61/87 are running under results/build-17743f8-20260913-170250. All three pass synthesis; seed 87 reports 52905 synthesized registers with unchanged 3754315 memory bits, 69 DSPs and three PLLs. Fitted utilization and timing remain pending. Seven-minute 25/29.97 fps counter clips were generated with the committed make_cadence_motion_tests.py --seconds 420 under results/playback-control-tests; all four raw/MPG files pass full decode and frame-count checks. No playback-controls RBF is hardware accepted.

#### Next Steps:

Finish all seeded builds and timing/CDC audits, retain the seven-minute counter media for hardware checks, and extend the reconstruction regression to require explicit end-of-file seek completion.

#### Files Modified:

- rtl/media_playback_control.sv
- tools/test_media_playback_control.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 25 COMMIT Unreleased 6b22b6e 2026-09-13T16:38:32-07:00

#### Coming From:

Unreleased 6da4771

#### Purpose:

Implement keyboard play/pause and time-based seeks using the existing stock-Main playback path.

#### Outcome:

Committed 6b22b6e implementing Space pause and Left/Right 10/30/300-second seeks with both modifier sides, OSD exclusion and typematic suppression. Playback time, queued PCM and display ownership are retained on pause; seeks reconstruct from byte zero with silent PCM discard and frame-boundary completion. Keyboard, exact rational target rounding at five rates, timestamp wrap, PCM retention/EOF, three asynchronous restart transactions, reader retirement and raw EOF closure tests pass. The real MPG oracle retains all 24192 sample pairs through a 100 ms pause with at most one code of FFmpeg error, and the mixed 24-picture I/P/B oracle has zero pixel mismatches in normal and seek/pause modes. Video/OSD regressions also pass. Full-top Verilator lint encountered an internal tool fault with vendor simulation libraries, so it was not counted as a pass. Three clean builds under results/build-6b22b6e-20260913-165629 reached fitting but were stopped after review found that the rounded audio landing time could revert to the requested time after seek acknowledgement. A new regression reproduces that defect. No RBF from this source is qualified or delivered.

#### Next Steps:

Latch the final rounded destination until the next session reset, repeat the focused regression, and rebuild the corrected source in three clean seeds.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_av.svh
- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- docs/OSD_PLAYBACK_PLAN.md
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/audio/mp2_pcm_output.sv
- rtl/media_keyboard_control.sv
- rtl/media_playback_control.sv
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- rtl/mpeg2_new/mpeg2_program_stream_ingress.sv
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_mixed_raster_pixels.sv
- tools/test_media_keyboard_control.sv
- tools/test_media_playback_control.sv
- tools/test_mp2_pcm_output.sv
- tools/test_mp2_playback_control.sv
- tools/test_mpg_audio_playback.sv
- tools/test_playback_restart.sv
- tools/test_program_stream_ingress.sv
- tools/verify_decoder_timing.py
- tools/verify_mpg_audio.py
- tools/verify_playback_controls.py
- tools/verify_program_stream_ingress.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 24 COMMIT Unreleased 6da4771 2026-09-13T16:23:17-07:00

#### Coming From:

Unreleased 6da4771

#### Purpose:

Record user acceptance of the refresh-rate comparison using the generated motion tests.

#### Outcome:

The user confirms the refresh switch is working and clearly observes smoother motion with the 29.97 fps test at 59.94 Hz. They cannot readily distinguish the two output settings with the 25 fps clip, so that visual comparison remains inconclusive rather than a failure. This accepts the observed refresh-dependent cadence benefit on the existing hardware-accepted compact core 0b6eb0e seed 87 by handoff context. No independent running-RBF hash, measured HDMI refresh, or specific raw-versus-program-stream test coverage was reported. The media generator passed its software checks; no new FPGA build was needed for this cycle.

#### Next Steps:

Retain the accepted compact core and manual refresh selection, with 59.94 Hz for 29.97 fps content and 50 Hz available for 25 fps content; no corrective implementation is indicated by this test.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 23 COMMIT Unreleased 6da4771 2026-09-13T16:01:34-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Generate deterministic motion-focused media for visual refresh-rate qualification.

#### Outcome:

Implemented the reproducible motion-test generator and produced approximately 60-second progressive 720x480 clips at 25 and 30000/1001 fps, each in raw M2V and silent-audio MPG form. Sharp constant-speed bars, panning fences and frame IDs expose uneven frame holds while keeping source speed fixed during refresh switches. All four files pass complete FFmpeg decoding and ffprobe checks for exact rate, progressive geometry and expected frame count (1500 or 1798). Representative frames were visually inspected. Media, comparison instructions, previews and SHA-256 manifests are under results/cadence-motion-tests. Python syntax and git whitespace checks pass. No RTL changed or FPGA build was required; hardware comparison of these new clips remains pending.

#### Next Steps:

Have the user compare the same 25 fps clip at 50 and 59.94 Hz, then use the 29.97 fps clip as the reverse control; close the OSD and keep filters constant during each observation. Confirm actual output refresh with display signal information when available.

#### Files Modified:

- tools/make_cadence_motion_tests.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 22 COMMIT Unreleased 0b6eb0e 2026-09-13T16:01:34-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Record user acceptance of the compact core and withdraw the reported hang as a core defect.

#### Outcome:

The user states that they caused the reported hang and instructs the agent to ignore it, then reports the new core works perfectly like the preceding core. This accepts ordinary hardware behavior of the delivered compact seed 87 by handoff context; no running hash was independently captured. The earlier freeze is no longer an open core defect. The user is still qualifying the visible refresh-rate benefit and requests more discriminating test media because the existing clips make the difference difficult to see.

#### Next Steps:

Retain compact source 0b6eb0e seed 87 as the hardware-accepted baseline and produce motion-focused media to compare 25 fps at 50/59.94 Hz.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 21 COMMIT Unreleased 0b6eb0e 2026-09-13T15:55:39-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Record completed compact-telemetry builds, measured resource savings and the clarified whole-movie failure context.

#### Outcome:

All three clean source-0b6eb0e seeds compile and pass the unchanged 108-register CDC audit. Seed 87 passes every timing category at all four corners, with minimum setup +0.082 ns, hold +0.100 ns, recovery +3.007 ns, removal +0.199 ns and pulse width +0.925 ns. Its fitted use is 37548 ALMs, 54191 registers, 480 RAM blocks and 69 DSP blocks, leaving 4362 ALMs free; its RBF SHA-256 is 17e0b04eb91fe7d75538338f171da9c8cf8e6a8d57e1c395e6fd3ad8b3137507. Seed 52 uses 40372 ALMs and fails setup at -0.011 ns in the ASCAL vertical polyphase path; seed 61 uses 40247 ALMs and fails setup at -0.493 ns in ASCAL vertical filtering. Both other seeds pass hold, recovery, removal and pulse width. Compile plus timing durations are 1119, 1081 and 1162 seconds for seeds 52, 61 and 87. Compared with dd144a3, source synthesis saves 1803 combinational ALUTs and 3021 registers without changing memory bits, DSPs or PLLs; the profiler alone falls from 3290 to 1515 synthesized ALUTs and from 5449 to 2429 registers, while fitted seed-87 profiler use is 894 ALMs. The larger reduction between the preceding qualified seed 52 and this qualified seed 87 includes placement effects. Complete evidence, regression results and copied RBFs with explicit timing status are under results/build-0b6eb0e-20260913-153453 and results/hardware-test-0b6eb0e. Separately, the user clarifies the freeze occurred in fellow.mpg at fixed 50 Hz without a switch, and this was the first test that far into the file. FTP reports 4359360512 bytes at /media/fat/games/MediaPlayer/fellow.mpg, exactly matching the historical large-file case in af7f570. That old fix enabled 64-bit ARM-helper stat() for Total/Remaining labels and did not resolve the separately noted decoder hang. The current reader uses 64-bit size and position; the saved snapshot already read 110306058 bytes, exceeding the 64393216-byte low-32-bit size, so simple size truncation does not explain that captured progress. Actual filesystem type was not established by the FTP proc-file read, and the /media/fat name is not evidence of FAT32. No freeze cause or refresh regression has been established, and no compact RBF has been deployed or hardware-accepted.

#### Next Steps:

Offer source-0b6eb0e seed 87 for compact-telemetry hardware validation with the updated decoder, retaining the detailed dd144a3 candidate and saved freeze captures for diagnosis. Confirm normal playback, retained EOF/error/audio/transport fields and OSD controls before accepting telemetry cuts. Investigate fellow.mpg separately, using reproducible position and a 59.94 Hz comparison or fresh live-state diagnostics; do not present telemetry cuts as a freeze fix. Do not use timing-failed seeds 52 or 61 as qualified artifacts.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 20 COMMIT Unreleased dd144a3 2026-09-13T15:46:46-07:00

#### Coming From:

Unreleased 0b6eb0e

#### Purpose:

Record the user's long-movie freeze report and preserve non-disruptive hardware evidence during the telemetry builds.

#### Outcome:

While separately testing the dd144a3 refresh candidate, the user reports a whole-movie file froze well into playback at 50 Hz, that other files worked at both refresh rates, and that the OSD still opens. Two fresh FTP-triggered captures 26.5 seconds apart are pixel-identical across all 720x480 pixels, confirming a stationary movie picture while Main remains responsive. Evidence is retained under results/telemetry-20260913-154407 and results/telemetry-20260913-154434, including comparison.json. Both images decode a valid schema-9 snapshot with source rate code 2 (24 fps), audio-underrun flag 0x1000, no decoder/presentation/file-reader error, no EOF, 7380 decoded MP2 frames and 8501760 played sample pairs, and audio STC 177 seconds. The profiler latches at the first triggering event, so this may be an earlier underrun snapshot rather than the freeze state; neither 177 seconds nor the wrapped FPS/cycle/picture counters establishes the freeze time or cause. The RTL underrun flag does not gate transport or playback. Large file size and 50 Hz are not established causes. No reset, file reload, deployment or mode change was performed. This is partial refresh validation with an unresolved long-file playback failure, not overall hardware acceptance; compact-telemetry source 0b6eb0e continues compiling separately and has not been installed.

#### Next Steps:

Preserve the detailed dd144a3 candidate and captured evidence for investigation, distinguish the current stall from the previously latched snapshot, and obtain a reproducible file/position or fresh live diagnostic evidence before choosing a playback fix. Complete the already authorized compact-telemetry builds and report their resources and timing without treating them as a fix for this freeze.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 19 COMMIT Unreleased 0b6eb0e 2026-09-13T15:28:53-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Reduce default observational telemetry logic while retaining essential playback-health diagnostics and an optional detailed profile.

#### Outcome:

Source 0b6eb0e implements compact schema 10 with 25 words instead of 49, retaining the approved byte/time/picture metadata, errors, one maximum gap and outlier count, basic terminal state, audio and transport-health words. Only detailed-performance outputs are excluded from the default synthesis cone; their equations remain available under MMP_DETAILED_TELEMETRY for schema-9 diagnostic builds. The overlay remains at (8,280) but is 100 pixels tall instead of 196. Side-by-side RTL tests prove every retained word equals the detailed profile at quiet EOF, all supported cadence codes, terminal timeout, fatal error, no-progress capture and pre-decode transport failure. The new verifier decodes actual compact RTL overlay RGB pixels, rejects corrupted cells, checks the command-line report, and confirms schema 7/8/9 compatibility at every retained overlay origin. Removed diagnostics are explicitly unavailable/null; the host checksum field now correctly uses the last word for every schema. Existing video, OSD, scanout, cadence, geometry, CDC, 50 Hz switching and profiler regressions pass. Decoder, audio and presentation-control RTL are unchanged. Source is pushed and seeds 52, 61 and 87 are compiling under results/build-0b6eb0e-20260913-153453, which retains regression evidence. Resource savings and timing remain pending; the user is separately testing the preceding dd144a3 seed-52 refresh build.

#### Next Steps:

Measure synthesized and fitted savings against dd144a3, complete all four timing corners and the unchanged 108-register audit for all three seeds, then deliver timing-qualified compact RBFs and capture instructions. Record the user's dd144a3 hardware feedback separately when it arrives; do not conflate that acceptance with this telemetry build.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- MediaPlayer_top_07.svh
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/verify_compact_telemetry.py
- tools/streams/run_hardware_cadence.py
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 18 COMMIT Unreleased dd144a3 2026-09-13T15:26:03-07:00

#### Coming From:

Unreleased dd144a3

#### Purpose:

Record completed manual-refresh builds, the timing-qualified candidate and the resource review requested during compilation.

#### Outcome:

All three clean source-dd144a3 builds compile and pass the 108-register fitted CDC audit. Seed 52 passes every timing category at all four operating corners, with minimum setup +0.114 ns, hold +0.018 ns, recovery +2.714 ns, removal +0.186 ns and pulse width +0.925 ns. It uses 41215 ALMs, 57400 registers, 480 RAM blocks and 69 DSP blocks; its RBF SHA-256 is 6a0720e4623c77c65e1736a729686b7c9165ef10c42265311a029dd57131de45. Seed 61 uses 41082 ALMs and fails setup at -0.004 ns in ASCAL, while seed 87 uses 41279 ALMs and fails setup at -4.958 ns from the prediction fetcher descriptor count into a reference-cache tag; their other timing classes pass. Build plus timing durations are 1353, 1267 and 1421 seconds for seeds 52, 61 and 87 respectively. Source synthesis adds 157 combinational ALUTs and 24 registers versus 24d3de0, with unchanged memory bits, DSPs and PLLs; the smaller fitted seed-52 ALM total reflects placement and is not an architectural saving. Complete evidence is under results/build-dd144a3-20260913-150109 and copied RBFs with hashes and explicit qualification status are under results/hardware-test-dd144a3. The user was given seed 52 and results/refresh-tests/README.txt; hardware acceptance is pending. During compilation the user requested resource and removable-telemetry analysis. The accepted 24d3de0 seed-52 hierarchy attributes approximately 3110 ALMs, 65 RAM blocks and 12 DSPs to identifiable audio blocks excluding shared A/V logic, and 2612 ALMs to the observational cadence profiler alone. Detailed ranked-gap history, per-picture stall and overlapping hold counters, DDR performance totals and scheduler dumps are candidates for a smaller diagnostic profile, while errors, basic cadence, audio counts/status and transport health should remain. No telemetry removal or RAM-storage redesign was authorized or implemented.

#### Next Steps:

Have the user validate the preferred dd144a3 seed 52 using the generated 25/29.97 fps MPG and M2V controls, manual refresh switches, display-rate confirmation with vsync_adjust=1, OSD/aspect/matrix/filter operation and A/V synchronization. Retain 24d3de0 seed 52 as recovery and do not present seeds 61 or 87 as timing-qualified. Further telemetry reduction remains a proposal requiring user direction and measured synthesis savings.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 17 COMMIT Unreleased dd144a3 2026-09-13T14:52:23-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Add user-selected 50 Hz progressive output alongside the accepted 59.94 Hz mode while retaining 720x480 decoding.

#### Outcome:

Source dd144a3 adds Refresh rate 59.94 Hz/50 Hz on status bit 6. Both modes use 27 MHz and 720x480 active pixels; total rasters are 858x525 and 864x625. Requests cross through a coherent mailbox and apply only at frame end; a second mailbox publishes the applied mode to the decoder before the next swap window. Exact cadence tests pass for all five source rates at both refresh rates, including 1000 presentations in 2000 windows for 25 fps/50 Hz. Pending-picture ownership and timestamp admission survive mode changes. Full raster tests pass six complete frames with four asynchronous live switches, while both fixed-mode scanout tests deliver all 345600 exact pixels despite DDR stalls and bank resets. Existing OSD, geometry, color arithmetic/control, cadence telemetry and MPG audio regressions pass; the audio oracle retains zero underrun and timestamp error. No audio or PTS clock changes are needed. Deterministic progressive 25/29.97 fps MPG and M2V hardware clips and README are under results/refresh-tests. Source is pushed and clean seeds 52, 61 and 87 are compiling under results/build-dd144a3-20260913-150109, which also retains regression evidence. The fitted audit now requires 108 preserved registers. HDMI relock and user-visible A/V behavior still require hardware validation; there is no DVD, interlaced, 576-line, gamut or gamma expansion.

#### Next Steps:

Complete the three clean builds, record all four timing corners and resources, and deliver timing-qualified RBFs with the generated refresh checks. Retain hardware-accepted 24d3de0 seed 52 as recovery until the user validates mode switching, 25 fps cadence, OSD controls and audio synchronization with vsync_adjust=1.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/mpeg2_video_720x480p.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/phase1p_timing.tcl
- tools/test_480p_scanout.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/verify_video_sync.py
- tools/test_refresh_rate.sv
- tools/make_refresh_tests.py
- docs/TEST_INSTRUCTIONS.md
- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 16 COMMIT Unreleased 24d3de0 2026-09-13T14:25:07-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Record the user's successful hardware validation of the color-matrix build.

#### Outcome:

The user reports that all tests pass and that every change outlined in the supplied README was observed on hardware. This accepts the requested visual color-matrix checks following delivery of the recommended 24d3de0 seed 52 candidate, which already passes all four timing corners and the 96-register CDC audit. Seed 52 is associated with this acceptance from the handoff context; the running RBF hash was not independently captured. The user's observation is the hardware evidence, and no additional screen capture was taken. Local acceptance metadata is retained under results/hardware-test-24d3de0/seed52. Gamma and gamut conversion remain excluded.

#### Next Steps:

Retain 24d3de0 seed 52 as the accepted baseline and await the next requested development task; no additional build or release is required for this validation cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 15 COMMIT Unreleased 24d3de0 2026-09-13T14:09:33-07:00

#### Coming From:

Unreleased 24d3de0

#### Purpose:

Record the completed color-matrix builds and timing-qualified hardware candidates.

#### Outcome:

All three clean 24d3de0 seeds compiled successfully and passed the fitted 96-register CDC audit. Seed 52 passes every timing class at all four operating corners with minimum setup +0.266 ns, hold +0.044 ns, recovery +2.335 ns, removal +0.141 ns and pulse width +0.925 ns; its SHA-256 is 256ff2b2eade4f525785364a38f989c91d32fc50178ed87d5d950d80d9c3815c. Seed 87 also passes, with setup +0.069 ns, hold +0.036 ns, recovery +3.543 ns, removal +0.188 ns and pulse width +0.925 ns; its SHA-256 is edd3f3ce51b2d4ecead3c668fd86188387806ad06ad670f82fbc9fb166c656e6. Seed 61 fails setup at -0.096 ns on the presentation-scheduler pending-bank path into the P parser; its other timing classes pass. The preferred candidate is seed 52, while the previously delivered seed 87 remains timing-qualified. RBFs, hashes and explicit timing status are under results/hardware-test-24d3de0/seed52, seed61 and seed87, with complete reports under results/build-24d3de0-20260913-134011. Synthesis adds 126 combinational ALUTs and 46 registers versus 62baf08, with unchanged block-memory bits and DSP count. Fitted seeds 52, 61 and 87 use 41274, 41004, 41011 ALMs respectively; every seed uses 480 RAM blocks and 69 DSP blocks. Total build/timing durations were approximately 1654, 1176 and 1347 seconds. Regression evidence and generated matching/untagged clips are retained; no matrix-enabled or new aspect hardware acceptance has been reported. Gamma and gamut conversion remain explicitly excluded.

#### Next Steps:

Test the preferred seed 52 with results/color-matrix-tests: Auto should match the tagged 601 and 709 clips, while the untagged 709 clip requires the manual BT.709 override. Verify frame-boundary color changes, subsequent file reload, uninterrupted OSD/filter controls and manual 4:3/16:9 aspect switching. Await hardware feedback before further implementation or release; do not treat seed 61 as timing-qualified.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 14 COMMIT Unreleased 24d3de0 2026-09-13T13:28:53-07:00

#### Coming From:

Unreleased 62baf08

#### Purpose:

Implement frame-associated BT.601/BT.709 color matrix selection with user overrides and deterministic visual tests.

#### Outcome:

Committed and pushed 24d3de0 with optional sequence-display color-matrix parsing, frame-associated reference/scratch matrix context, Auto/BT.601/BT.709 overrides and frame-boundary application through two acknowledged mailboxes. Missing/unspecified/unsupported tags use the documented BT.601 compatibility fallback. Exhaustive simulation covers all 16777216 input triples: BT.601 is exact against 62baf08 and BT.709 differs from the BT.709-6 reference by at most one RGB code. Metadata, reset, repeated/truncated descriptions, all 256 tag values, queued B pictures, simultaneous header/commit and override CDC tests pass. Colored stalled-DDR scanout checks 345600 exact pixels and continuous sync; existing video/OSD/cadence and integrated mixed I/P/B regressions also pass. Deterministic 601/709 matching clips and an untagged 709 clip are generated under results/color-matrix-tests. The consulted BT.709-6 items 3.2 through 3.4 are added to core-reference.md with notification to the user; the H.262 metadata interpretation uses the already-controlled 02/2000 baseline. Gamut and gamma conversion are explicitly excluded by the user. The independent 62baf08 seeds are now complete: seed 61 passes all four operating corners with setup +0.395 ns, hold +0.103 ns, recovery +3.149 ns, removal +0.152 ns and pulse width +0.925 ns, and all 84 audited synchronizer registers. Its RBF SHA-256 is 1d0b6dfcb917df72f567f760956280638696d866fa190362fe7f3d03357c47ff, with 41267 ALMs, 57463 registers, 480 RAM blocks and 69 DSP blocks. Seed 52 fails setup at -0.159 ns on a P-frame address path and seed 87 at -0.032 ns on scaler vertical interpolation; other timing classes and audits pass. All three files are under results/hardware-test-62baf08/, with seed 61 delivered as the timing-qualified aspect/OSD candidate and no hardware acceptance yet. Clean color seeds 52, 61 and 87 are running under results/build-24d3de0-20260913-134011; the fitted audit now requires 96 synchronizer registers. No matrix-enabled hardware result is available yet.

#### Next Steps:

Complete the three color builds, require all four operating-corner timing classes and all 96 audited registers, compare resource use against 62baf08 and provide timing-qualified candidates. Hardware should validate Auto on both tagged clips, the manual override on the untagged clip, frame-boundary changes, subsequent file reload and uninterrupted OSD/filter/aspect behavior. Continue using the delivered 62baf08 seed 61 for the independent aspect/timing hardware test.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- docs/TEST_INSTRUCTIONS.md
- files.qip
- rtl/media_color_control.sv
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_picture_color.sv
- rtl/mpeg2_new/mpeg2_ycbcr_to_rgb_bt601.sv
- tools/make_color_matrix_tests.py
- tools/phase1p_timing.tcl
- tools/test_media_color_control.sv
- tools/test_picture_color.sv
- tools/verify_color_matrix.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 13 COMMIT Unreleased 62baf08 2026-09-13T13:05:36-07:00

#### Coming From:

Unreleased a0f153a

#### Purpose:

Provide manual 4:3 and 16:9 aspect selection and repair the observed decoder and scaler setup paths.

#### Outcome:

Committed and pushed 62baf08 with exactly two user-selected aspect choices, 4:3 and 16:9; removed sequence-aspect synchronization and its obsolete exception. The actual core mailbox and platform rectangle test passes six switches across 1080p and 5:4 outputs. B-frame coordinate snapshots split launch-address arithmetic without changing request latency. The final scaler fraction step occupies an existing delay stage and registered blanking preserves transition cycles. Extracted production VHDL matches a0f153a for 250000 randomized cycles at FRAC 4, 6 and 8 across every consumed fraction stage and resolution-blanking transition; the complete scaler also analyzes successfully in GHDL. The mixed I/P/B oracle checks 423936 samples with zero tolerance violations and maximum delta two, matching a0f153a cycle counts, request counts and prefetch activity. The old bench referenced a removed arbiter diagnostic and had a one-cycle stale depth-four total; both were corrected against the baseline. OSD/raster/CDC/cadence/telemetry and mounted-reader/session regressions pass. Timed MPG audio checks 24192 stereo pairs with maximum error one, 152679 video bytes and 15 timestamps without underrun. Clean seeds 52, 61 and 87 are running under results/build-62baf08-20260913-131350; timing and hardware acceptance remain pending.

#### Next Steps:

Complete all three clean builds and the fitted 84-register CDC audit, inspect every setup/hold/recovery/removal/pulse-width operating corner, and deliver clearly labeled hardware candidates. Verify manual aspect changes and continued OSD/filter operation during playback on hardware. Do not describe a seed as timing-qualified before all corners pass.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- docs/TEST_INSTRUCTIONS.md
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- sys/ascal.vhd
- tools/streams/tb_h262_live_raster_soak.sv
- tools/verify_decoder_timing.py
- tools/verify_manual_aspect.py
- tools/verify_scaler_timing.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 012 COMMIT Unreleased a0f153a 2026-09-13T12:54:32-07:00

#### Coming From:

Unreleased a0f153a

#### Purpose:

Record completed OSD builds, accepted interactive-menu hardware behavior and the remaining setup-timing work.

#### Outcome:

All three clean a0f153a seeds compiled and passed the fitted 84-register CDC audit and explicit four-corner hold, recovery, removal and pulse-width checks. Worst setup for seeds 52, 61 and 87 is -0.200, -0.137 and -0.234 ns respectively; no build is timing-qualified. Seed 52's worst path is the 60 MHz B-frame backward-motion/address calculation into phase1_base_addr_reg; seed 61 fails HDMI scaler fraction/address logic and seed 87 fails HDMI scaler control-to-pixel logic. Their ALM counts are 41237, 40806 and 40913, with 480 RAM blocks and 69 DSP blocks each. Build and timing times were approximately 1263, 1235 and 1436 seconds. Evidence is retained in results/build-a0f153a-20260913-122739/ and all three RBFs are copied under results/hardware-test-a0f153a/seed52, seed61 and seed87 with hashes and explicit timing status. At the user's request, seed 52 SHA-256 2fe49c2d3f05dd038062b76c1026dc261b03c2e53378967c2dfb632cf084d5af was delivered despite its disclosed timing failure. The user confirmed the fix works: OSD is controllable and filters work during playback. Passed here records that accepted OSD/filter scope, not timing qualification or unreported EOF/reload testing. The user explicitly excluded DVD and interlaced playback from the project; progressive-only scope supersedes the older roadmap in core.md and historical references, without automatically editing restricted core.md. A read-only FTP check confirmed current MiSTer.ini has MediaPlayer vsync_adjust=1, global video_mode=8 and direct_video=0, and no active MediaPlayer main override in the inspected section. This config matches HDMI to the fixed 60000/1001 Hz core raster, not to each movie frame rate. Source rates 24000/1001, 24, 25 and 30 still have noninteger repetition on that raster; 30000/1001 has a two-refresh cadence. Optional progressive source-matched raster/scheduler modes were investigated only and not implemented.

#### Next Steps:

Plan a focused timing cleanup of the B-frame address calculation and HDMI scaler arithmetic/control paths, preserving decoder values, filter quality and pixel/sync alignment. Require regression checks and positive setup at every operating corner; do not loosen clocks or hide genuine synchronous paths. Keep the accepted OSD behavior and progressive-only scope. Future refresh work can target twice-source-rate outputs where displays support them while retaining 59.94 Hz compatibility mode; leave vsync_adjust=1 configured. Await the user's direction before a new implementation cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

