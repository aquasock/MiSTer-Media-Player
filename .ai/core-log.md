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

## 535 COMMIT Unreleased 164c7e6 2026-08-26T05:12:51-07:00

#### Coming From:

Unreleased 1f80432

#### Purpose:

Record the first Big Buck Bunny Bob hardware result from the accepted-luma-write versus raw-DDR-read diagnostic.

#### Outcome:

The user completed `/media/fat/games/MediaPlayer/bbb_480i_tff_15s_8mbps.m2v` in Bob on the exact `164c7e6` diagnostic RBF and left its terminal image displayed before the separate MiSTer Main installation. The untouched screenshot `.ai/current_results/entry533_bbb_tff_bob_8mbps_terminal.png` was triggered and retrieved through ordinary authenticated FTP at 479,905 bytes and SHA-256 `6543b7be8fd03f65fdb15da628c8a89ab1e24d73089cd3556554ec4bdc61733a`. The core accepts all 15,150,646 source bytes and its wrapped counters reconstruct 449 framebuffer generations and displayed pictures with 448 publications and swaps. Those 448 presentation intervals span 919,176,899 decoder cycles or 15.319615 seconds, delivering 29.243555 pictures per second. Top-field-first is preserved, sequence end and presentation completion are present, the session freezes normally for quiet reason one and every aggregate, presentation, destination, cache-overlap, prefill, region and phase error is clear. Both field comparisons reach 255 valid samples in physical region zero with zero mismatches: the first-field accepted-write and raw-return fingerprints are both `25e325e3`, and the second-field pair are both `bdc0bdc0`. The diagnostic objective therefore passes and proves that the selected raw DDR data is byte-consistent with the accepted framebuffer writes for both parities during this real-content run; the user's visual verdict for this exact run remains to be recorded before choosing the next behavioral boundary.

#### Next Steps:

Obtain the user's visual report for this exact Bob playback, specifically whether old frames or horizontal lines remained. If the symptom remained, do not change DDR storage or readback: combine this equality with the existing correct line-cache fingerprints and the four-picture reconstruction result to review scheduler display-bank and generation selection against the accepted write provenance before proposing one bounded correction. Independently restart the MiSTer when convenient and validate the newly installed Main default-directory change recorded in entry 534.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 534 COMMIT Unreleased 1f80432 2026-08-26T04:59:18-07:00

#### Coming From:

Unreleased 164c7e6

#### Purpose:

Make the Media Player file selector open the core's resolved games directory instead of a previously selected path.

#### Outcome:

Commit `1f80432` confines the change to one hunk in the pinned MiSTer Main patch. When MediaPlayer opens its generic file selector, Main now passes `user_io_get_core_path(NULL, 1)` so its established storage and prefix rules resolve `/media/fat/games/MediaPlayer`; every other core retains its remembered `Selected_F` behavior. The complete patch applies cleanly to pinned Main commit `0a8fb44`, and the FPGA RBF and ARM media helper are unchanged. The official Arm GNU 10.2-2020.11 archive verifies at the established SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a` and identifies as GCC 10.2.1. Two clean GUNSMOKE builds are byte-identical, each producing a 1,166,244-byte ARM EABI5 executable at SHA-256 `0ec0d60bf415dc96765e20f00df838e4f3d1b5a7d1e70490e8daad174b20ee26`. Deployment waited until the user's active playback and terminal capture were complete. Because Linux rejected an in-place write of the running executable as text-busy, the resolved `/media/fat/MiSTer` path was directly deleted and rewritten in one FTP session with automatic local recovery available; independent readback is byte-identical at the expected size and hash. No MiSTer backup, rollback or staging filename was created, and no restart was triggered.

#### Next Steps:

Restart the MiSTer when convenient, reload MediaPlayer and open its media selector. Hardware acceptance requires the selector to begin in `/media/fat/games/MediaPlayer`, permit the intended file to be selected normally and leave another core's remembered selector path unchanged. The installed executable is already verified, but the entry remains unpassed until that post-restart behavior is observed.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 533 COMMIT Unreleased 164c7e6 2026-08-26T04:54:09-07:00

#### Coming From:

Unreleased 5de0e1d

#### Purpose:

Build and directly install the scoped accepted-write-versus-raw-read diagnostic for one Big Buck Bunny Bob hardware discriminator.

#### Outcome:

The scope review confirms that commit `164c7e6` adds one passive accepted-luma-write through raw-DDR-read comparison path: ten runtime source files carry the observation through existing interfaces and seven files provide directed tests and diagnostic decoding, while no signal feeds the decoder, scheduler, framebuffer ownership, DDR write control, line-cache control or video output. The previously interrupted canonical seventy-two-picture mixed-I/P/B live-raster regression now completes in 6,529,997 cycles with twenty-five reference publications, forty-seven B pictures, seventy-one swaps and every decoder, reconstruction, DDR, cache, presentation and ownership error clear. The real Big Buck Bunny four-picture reconstruction comparison also passes all 2,073,600 positioned samples within the established one-LSB transform tolerance in 7,837,323 cycles. The retained-state Quartus Prime 17.0.2 build completes in 11:08 with zero errors and 172 warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.021, 0.260, 3.793, 0.542 and 0.925 nanoseconds; focused decoder setup and recovery are positive 1.202 and 11.265 nanoseconds and focused video setup is positive 2.626 nanoseconds, all with zero violated paths. The fit uses 31,240 of 41,910 ALMs, 49,445 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,225,296-byte RBF has SHA-256 `b5ce400b43311a74b0607137bce4498685490b74e5d08587538a68e7cdce8d96`. It was copied from the designated GUNSMOKE checkout and directly replaced only `/media/fat/MediaPlayer.rbf` through ordinary FTP; independent readback is byte-identical at the same size and hash, and no MediaPlayer backup, rollback or staging filename exists.

#### Next Steps:

Reload the Media Player core, choose Bob, leave the native timing pattern Off and replay only `/media/fat/games/MediaPlayer/bbb_480i_tff_15s_8mbps.m2v`. Report whether old frames still reappear during otherwise smooth playback and leave the terminal image displayed. Retrieve and decode that terminal image through ordinary FTP. A write-versus-read mismatch places the stale content in accepted writer packing, physical DDR addressing, storage or readback; equality proves the selected framebuffer contains exactly what was written and moves the correction boundary to scheduler bank or generation selection without another diagnostic layout.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 532 COMMIT Unreleased 5de0e1d 2026-08-26T04:35:28-07:00

#### Coming From:

Unreleased 164c7e6

#### Purpose:

Establish the commercial-DVD-rate Bob and Weave behavior and verify real Big Buck Bunny I-picture reconstruction before another RTL change.

#### Outcome:

The exact fifteen-second 720x480 top-field-first all-I Big Buck Bunny fixture contains 449 pictures at 30000/1001 and 8 Mb/s target, 9 Mb/s maximum and 1,835 kb buffer settings; it is 15,150,646 bytes with SHA-256 `04758691e3e51c72ca2e7c3723b4dda2fbd473783425215df8ec2dcb5585cbe0`, and the signalling patch leaves FFmpeg's decoded YCbCr planes unchanged. On the active `5de0e1d` hardware, Bob accepts every byte and produces 449 displayed pictures and 448 swaps over 15.323544 seconds, or 29.236 pictures per second; Weave produces the same counts over 15.328045 seconds, or 29.227 pictures per second. The user reports both modes run at speed with a responsive MiSTer menu, but both retain old-frame ghosting; the apparent approximately 60 Hz Weave flicker is specifically old frames rapidly reappearing rather than a separate brightness or sync defect. Both terminal captures have every aggregate, decoder, cache-tag, cache-content, region, phase, prefill and overlap error clear. The selected Bob and Weave terminal evidence has SHA-256 `f6f1934392ef40ce4668319281d8fc64904af3b193622252aaf73e23e6ecd049` and `54c1771a2dc01f4dfd4c0fe6116e9fa4307a35ad7db0c169da0f07e8bf24d157`. A four-picture sequence-ended excerpt is 147,746 bytes with SHA-256 `32148a07ad51aaa9472bd4ffc6993cdee638d884e4e8903b5144054186a99654`; the existing complete parser, inverse-quantization, IDCT and reconstruction simulation on GUNSMOKE produces all 2,073,600 positioned YCbCr samples, has zero samples outside the established one-LSB transform tolerance and completes in 7,837,323 cycles below the 8,008,000-cycle four-picture real-time limit. The MPEG-2 I-picture decode and reconstruction path is therefore correct for this real content and the remaining stale-frame defect is later in framebuffer generation or presentation selection. The earlier accidental run of a different file is excluded from this result.

#### Next Steps:

Do not change the decoder or add another independently named diagnostic. Review the already committed but unbuilt accepted-write-versus-raw-read instrumentation at `164c7e6` against the newly isolated stale-frame presentation failure and reduce it if any signal does not directly distinguish framebuffer generation ownership from stale bank selection. Only after that scope review should the single consolidated diagnostic receive an incremental Quartus build and direct replacement of `/media/fat/MediaPlayer.rbf`; hardware acceptance remains smooth Bob and Weave without any old picture reappearing, while native bypass remains deferred for community validation after progressive presentation is correct.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 531 COMMIT Unreleased 164c7e6 2026-08-26T02:39:38-07:00

#### Coming From:

Unreleased 5de0e1d

#### Purpose:

Maintain one consolidated current hardware diagnostic while distinguishing accepted luma framebuffer writes from the raw DDR data later returned for display.

#### Outcome:

Commit `164c7e6` implements the accepted-write-versus-raw-read diagnostic in the single current hardware layout, including position-sensitive fingerprints, physical-region and generation validity, first-mismatch evidence and directed clean, corrupted-data and invalid-provenance controls. The implementation changed seventeen source and regression files with 892 insertions and 60 deletions. Focused decoder, unit, native and reconstruction simulations passed, but the canonical seventy-two-picture live-raster run was interrupted before completion and no Quartus build or MiSTer deployment was performed. The active MiSTer image therefore remains the exact `5de0e1d` build. The user subsequently raised a valid scope concern because the passive diagnostic touched substantially more files than expected for the remaining visual defect, so this commit is recorded but parked pending a scope review rather than treated as authorization to build or deploy it.

#### Next Steps:

Do not build or deploy `164c7e6` until the new commercial-DVD-rate Bob and Weave evidence is recorded and the instrumentation scope is reviewed against the now clearer stale-frame symptom. Retain one current diagnostic layout and remove or defer any signal that does not directly distinguish accepted framebuffer content and generation ownership from later raw reads and displayed bank selection.

#### Files Modified:

- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_luma_write_fingerprint.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_luma_write_fingerprint.sv
- tools/streams/tb_interlaced_420_cache_mapping.sv
- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 530 COMMIT Unreleased 5de0e1d 2026-08-26T02:28:14-07:00

#### Coming From:

Unreleased 5de0e1d

#### Purpose:

Resolve the registered-cache-read alignment hardware run and identify the next evidence boundary for the remaining second-field and horizontal-line corruption.

#### Outcome:

The user reloaded the exact `5de0e1d` image and ran `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while the corrected burst acquired ninety-five fresh screenshots over thirty seconds. The user reports that the prior extra bar on the right is no longer visible while the left bar sweeps, so the registered-address correction materially improves the duplicated or frozen bar symptom, but explicitly reports that the second field is still visibly wrong and thin grey horizontal lines remain throughout moving content; the image is therefore not accepted. Schema sixteen accepts all 5,007,304 bytes, reaches sequence end, presentation completion and normal quiet reason one, and its wrapped counters represent 300 framebuffer resets, 299 publications, 300 displayed pictures and 299 swaps. Every aggregate, cache-overlap, prefill, region and phase error is clear. Both field tag-mismatch and content-mismatch counters are exactly zero across 255 reported fingerprints per field; the terminal first-field raw and displayed fingerprints are both `f964952b`, and the second-field pair are both `8c26df67`. This is the expected change from entry 527's saturated raw-versus-cache mismatches and proves the corrected cache RAM write and registered readout now preserve every fingerprinted luma line, but it does not prove that the luma bytes arriving from DDR were originally written correctly. The selected live evidence `.ai/current_results/entry530_schema16_live_lines.png` is 9,828 bytes with SHA-256 `2b307a525e8b808c61f09bfff0e3643611f6e4e6d63b43438739c61815c678a8` and preserves the reported horizontal fragments; `.ai/current_results/entry530_schema16_terminal.png` is 12,478 bytes with SHA-256 `162ef1bb6119d2423a675cff82e9b5955fc668c6eea4fbbc982f06258d033462` and contains blocky lower-left content absent from the authored terminal frame. The cache-alignment correction therefore passes its narrow raw-versus-cache objective, while the overall native hardware result remains failed and the next distinction is accepted framebuffer writes versus later raw DDR returns.

#### Next Steps:

Stop before another behavioral correction and obtain approval for a schema-seventeen write-to-read provenance diagnostic. Fingerprint each accepted luma DDR writer word with its physical bank, row and word position, retain completed per-line expected fingerprints by framebuffer generation, and compare them against the already observed raw DDR return for the same published bank, row and generation before the line enters the cache. Preserve schema sixteen through legacy decoding and add directed controls proving clean equality, one accepted-write or readback corruption as a content mismatch, and wrong bank, row or generation as provenance mismatches; run the complete native, reconstruction and canonical live-raster suites before an incremental Quartus build. A write-versus-read mismatch localizes the remaining corruption to writer packing, address acceptance, DDR storage or region ownership, while equality moves the boundary upstream into reconstructed pixels or downstream beyond the already-cleared cache and requires a separate output-coordinate discriminator. Continue direct verified replacement of only `/media/fat/MediaPlayer.rbf` with no backup, rollback or staging files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 529 COMMIT Unreleased 5de0e1d 2026-08-26T02:19:45-07:00

#### Coming From:

Unreleased 5de0e1d

#### Purpose:

Install and verify the exact registered-cache-read alignment image without creating any backup, rollback or staging file.

#### Outcome:

The exact 4,252,684-byte `5de0e1d` RBF was copied from the designated GUNSMOKE checkout to the Raspberry Pi and independently retained SHA-256 `9260f3c36d4515f03bee4f0ecb24af6c7dc9e4dfb4ff387ec5e841bca39ad96c`. Python `ftplib` used an absolute `STOR /media/fat/MediaPlayer.rbf` command to directly replace only the active image, then a new FTP session independently retrieved the same absolute path. Candidate and readback are both 4,252,684 bytes, carry the exact expected hash and compare byte-for-byte with exit zero. A directory check finds no filename containing backup, rollback or stage, so deployment created no auxiliary remote file and did not change helper, media, Main or MiSTer configuration.

#### Next Steps:

Reload the Media Player core, prepare `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i and reply ready. Start playback immediately when prompted while the corrected thirty-second burst deletes the prior screenshot before every trigger, then leave the terminal image displayed for schema-sixteen capture. Report whether both field bars now move together with the authored four-pixel separation and whether the many horizontal grey fragments are gone; acceptance also requires zero schema-sixteen tag and content mismatch counts, 300 pictures, 299 swaps and every aggregate, overlap, prefill, phase and region error clear.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 528 COMMIT Unreleased 5de0e1d 2026-08-26T01:36:57-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Expose and correct any native line-cache registered-address or byte-lane alignment defect hidden by the constant-data regression stimulus.

#### Outcome:

The position-varying regression reproduced the hardware defect before any RTL change: every eighth luma pixel failed at lane seven because the registered M10K read address had already advanced to the following word, beginning at x=7 where expected byte `cb` was read as the next word's `cc`, then repeating at x=15, x=23 and every subsequent word boundary; both completed field fingerprints mismatched. Commit `5de0e1d` drives both luma and chroma cache addresses from the already delayed source coordinates, aligning the registered RAM word with the separately delayed byte-lane selector, and expands the regression to generate distinct values for every DDR word and all eight lanes while comparing every displayed luma byte against its exact physical row, word and lane. Position-varying TFF and BFF controls then complete all 720 bytes of every line with zero mismatches, one injected cache bit produces exactly one mismatch at x=80, word ten, lane zero, and the forced wrong-bank control remains tag-only. The complete native suite passes field order, mapping, exact TFF/BFF timing, Bob and Weave control, pattern isolation, ownership, the measured presentation integration, ordinary/delayed/late-prefill cache modes, schema sixteen and all retained decoder layouts. TFF, BFF and progressive reconstruction remain at 7,926,459, 7,948,706 and 13,048,137 cycles with zero out-of-tolerance pixels, field-DCT rejection remains at 82,326 cycles and the canonical seventy-two-picture mixed-I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B pictures, seventy-one swaps and every error clear. The requested retained-state incremental Quartus Prime 17.0.2 build completes in ten minutes thirty seconds with zero errors and 143 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.230, 0.244, 4.356, 0.570 and 0.925 nanoseconds with zero endpoint negative slack; focused decoder setup and recovery are positive 1.139 and 11.267 nanoseconds and focused video setup is positive 2.778 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains. The fitted netlist retains all twelve delayed x-coordinate bits and all thirteen delayed y-coordinate bits used by the corrected cache address path; synthesis merges the redundant luma lane register into those identical coordinate keepers. The fit uses 30,460 ALMs, 48,582 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,252,684-byte RBF has SHA-256 `9260f3c36d4515f03bee4f0ecb24af6c7dc9e4dfb4ff387ec5e841bca39ad96c`.

#### Next Steps:

Copy the exact `5de0e1d` RBF from the designated GUNSMOKE checkout to the Raspberry Pi, directly replace only `/media/fat/MediaPlayer.rbf` through absolute-path ordinary FTP without creating backup, rollback or staging files, and verify the active image by independent readback. Reload the core, run `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while the corrected thirty-second burst captures fresh live frames, then decode unchanged schema sixteen from the same run. Hardware acceptance requires both field bars to advance with the authored four-pixel separation, no missing or frozen parity, no horizontal stale fragments, zero tag and content mismatch counts, all 300 pictures and 299 swaps and every aggregate, overlap, prefill, phase and region error clear.

#### Files Modified:

- rtl/mpeg2_luma_framebuffer.sv
- tools/streams/tb_native_480i_cache_refill.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 527 COMMIT Unreleased 98ee2dc 2026-08-26T01:20:30-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Resolve the schema-sixteen hardware result and distinguish wrong native cache-line provenance from corruption of correctly tagged cache bytes.

#### Outcome:

The user reloaded the exact `98ee2dc` image and, after stopping one false start made with the wrong media, ran `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while the corrected burst deleted the fixed remote screenshot before every trigger. The thirty-second burst retrieved ninety-three fresh PNGs: fourteen byte-identical pre-playback frames, thirty distinct live frames numbered fourteen through forty-three and forty-nine byte-identical terminal frames. The fixture authors a thirty-two-pixel bar that advances four pixels per source field and alternating upper and lower field markers. At representative active rows 200 and 201, frames fourteen through thirty-three contain no bright first-parity bar while the other parity advances around the screen. In frame thirty-four the missing parity appears at x=360 through x=391 and remains fixed there through frame forty-three, while the other parity continues from x=357 through x=516 with a wrap during the interval. The live images therefore preserve both observed failure forms in one run: a missing field followed by one stale field bar, split moving edges and many horizontal comb-like fragments. The user's initial impression that playback might have been smoother was explicitly withdrawn as uncertain because of the time since the prior run, so no performance change is claimed for this passive diagnostic image. Schema sixteen accepts all 5,007,304 source bytes and its wrapped counters represent 300 reference and displayed pictures and 299 swaps. The 299 presentation intervals span 599,534,823 cycles, 9.992247 seconds or 29.923 pictures per second. The session reaches sequence end, presentation completion and normal quiet reason one with every aggregate, cache-overlap, prefill, region and phase error clear; it records 300 framebuffer resets, 299 publications and 242/240 terminal-generation field fetches. Both per-field content-mismatch counters saturate at 255 while both tag-mismatch counters remain exactly zero. The first mismatch for the authored first field expects and carries row two, bank one and generation one; the other field likewise expects and carries row three, bank one and generation one. Both first mismatches compare raw fingerprint `001fffe0` with displayed-cache fingerprint `001fffc0`, an XOR difference of exactly `00000020`. The terminal first-field raw/display pair is `f964952b`/`e855bf21` and the second-field pair is `8c26df67`/`ab1ec443`. Correct row, bank and generation tags with independently wrong bytes on at least 255 lines of each parity rule out refill ownership and source-row selection and place the defect in cache RAM write, registered read-address or byte-lane alignment. The selected evidence is `.ai/current_results/entry527_schema16_live_missing_field.png` at 9,790 bytes with SHA-256 `0447f759660eb50926fb97d56d6e9bc446f0b92716b7a83027e2631f32530869`, `.ai/current_results/entry527_schema16_live_field_appears.png` at 11,836 bytes with SHA-256 `74528360d21de793e95505301abc725c6fe2834ae05e7d0b6cd1e42a2fd936f1`, `.ai/current_results/entry527_schema16_live_stale_split.png` at 11,297 bytes with SHA-256 `0805c00621d72e25e48bfccfe2ab4bf4e71326e52c9425c77c9dd06d51180357` and `.ai/current_results/entry527_schema16_terminal.png` at 12,691 bytes with SHA-256 `9064b4493e439cfd76cc58ebf5603da16317c6da2e082f251f52f9949df7460c`. Source review also exposes a regression blind spot: the ordinary cache test returns the same 64-bit value for every word, so its realistic registered-address model cannot reveal a word-position or byte-lane shift except for the separately injected bit. The implementation uses a clock-registered M10K read address and a separately delayed byte-lane selector, making a position-varying timing regression the next evidence boundary before another hardware-only schema.

#### Next Steps:

Stop before changing behavior and obtain approval for one bounded cache-read alignment cycle. On the designated GUNSMOKE checkout, strengthen the native cache regression with distinct bytes in every lane and position-varying 64-bit words while retaining the real four-read-clock pixel cadence, TFF and BFF field order, wrap and refill timing. Require the current RTL either to reproduce a raw-versus-displayed mismatch at an exact word/lane boundary or to pass bit-exactly. If it reproduces, correct only the proven registered-read-address and byte-lane pipeline alignment, require all 720 bytes of every line to compare exactly, rerun the complete native, reconstruction and canonical live-raster suites, then perform an incremental Quartus build and use unchanged schema sixteen for hardware acceptance. If the stronger regression does not reproduce the hardware signature, stop without a behavioral change and propose schema seventeen with per-byte-lane raw/display fingerprints. Continue direct verified replacement of only `/media/fat/MediaPlayer.rbf` with no backup, rollback or staging files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 526 COMMIT Unreleased 98ee2dc 2026-08-26T00:56:34-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Install and verify the exact schema-sixteen image without creating any backup, rollback or staging file.

#### Outcome:

The exact 4,239,056-byte `98ee2dc` RBF was copied from the designated GUNSMOKE checkout to the Raspberry Pi and independently retained SHA-256 `ef78d18bb5f8fe974e1b132df73305878e1da99fd72f602a28c223fb295c8825`. Two initial `curl` uploads were rejected with FTP status 550 and changed nothing because curl interpreted the URL relative to the server login directory `/root`; the established Python `ftplib` absolute-path operation then wrote directly to `/media/fat/MediaPlayer.rbf` with no intermediate remote filename. An initial curl readback likewise fetched the unrelated historical `/root/MediaPlayer.rbf`, which exposed the path interpretation rather than an installation failure. Absolute-path `ftplib` readback of `/media/fat/MediaPlayer.rbf` returns exactly 4,239,056 bytes at the candidate hash and compares byte-identically with the local build. No backup, rollback or staging file was created or modified.

#### Next Steps:

Reload the Media Player core, prepare `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i and reply ready. Start playback immediately when prompted while a corrected thirty-second burst deletes the prior screenshot before every trigger, then leave the terminal image loaded for absolute-path schema-sixteen capture and decoding. Report whether the first-field bar remains frozen and whether the grey line fragments remain visible.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 525 COMMIT Unreleased 98ee2dc 2026-08-25T23:27:33-07:00

#### Coming From:

Unreleased 4e4db95

#### Purpose:

Distinguish incorrect native line-cache provenance from corruption of correctly selected cache content.

#### Outcome:

Commit `98ee2dc` implements schema sixteen without changing cache control or presentation behavior. Every completed native luma fill now publishes a stable per-bank raw fingerprint, physical row, bank and eight-bit framebuffer generation tag across a bundled-data toggle handshake; the video side latches the selected tag, fingerprints all seven hundred twenty returned cache bytes and reports mutually exclusive tag or content mismatch evidence per line. The profiler preserves the first tag and content mismatch separately for each authored field, adds four saturating mismatch counters, advances the overlay to sixty-one words and retains schema fifteen through legacy decoding. The initial clean TFF line test exposed a diagnostic-only startup gap in which the delayed publication qualifier omitted pixel zero of the first displayed line and left its tag at reset generation zero; the same source commit corrects that qualifier and all four directed controls then pass, with TFF and BFF equality, one injected byte producing content-only mismatch and a forced wrong bank producing tag-only mismatch. The complete native suite passes its established field-order, mapping, timing, presentation, refill, profiler and decoder gates; TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, field-DCT rejection remains at 82,326 cycles and the canonical seventy-two-picture mixed I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B pictures, seventy-one swaps and every error clear. A from-scratch Quartus Prime 17.0.2 build completes in ten minutes fifty seconds with zero errors and 143 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.352, 0.245, 4.056, 0.590 and 0.925 nanoseconds with zero endpoint negative slack; focused decoder setup and recovery are positive 1.509 and 10.903 nanoseconds and focused video setup is positive 3.328 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains, and timing-netlist probes find every sampled schema-sixteen generation, synchronized tag, provenance toggle, mismatch counter, metadata and fingerprint register group. The fit uses 30,748 ALMs, 48,766 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,239,056-byte RBF has SHA-256 `ef78d18bb5f8fe974e1b132df73305878e1da99fd72f602a28c223fb295c8825`.

#### Next Steps:

Copy the exact `98ee2dc` RBF to the Raspberry Pi, directly replace only `/media/fat/MediaPlayer.rbf` on the MiSTer without creating backup, rollback or staging files and verify the active image by readback. Reload the core, prepare `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i, then acquire a corrected fresh screenshot burst during playback and decode schema sixteen from the same run. A tag mismatch identifies wrong refill ownership, row, bank or generation; matching tags with a content mismatch identifies cache RAM write, address or byte-lane read corruption. Preserve generated Quartus state and use incremental builds for future cycles as directed by the user.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `MediaPlayer.sdc`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_interlaced_420_cache_mapping.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 524 COMMIT Unreleased 4e4db95 2026-08-25T21:43:10-07:00

#### Coming From:

Unreleased 4e4db95

#### Purpose:

Resolve the schema-fifteen hardware result and identify which side of the raw-DDR-to-displayed-cache boundary loses field content.

#### Outcome:

The user reloaded the directly installed `4e4db95` image and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while an agent-triggered burst sampled the live raster. The first burst retrieved the same pre-existing terminal PNG fifty-four times because its quarter-second settle interval allowed the fixed remote filename to be fetched before the new screenshot replaced it; deleting that exact remote screenshot before each subsequent trigger made stale reuse impossible. The corrected thirty-second burst returned twenty-five fresh screenshots, the first eight distinct and live and the final seventeen one byte-identical quiet snapshot. Across all eight live frames the authored first field is cleanly frozen at x=72 through x=103 for the complete 176-row bar, while the other field advances through x positions 424, 48, 360, 648, 272, 584, 208 and 496; the user independently confirms the screen behaved as before with one bar stuck on the left and the other moving right. Schema fifteen from the same run accepts all 5,007,304 bytes, records 299 framebuffer resets and publications, sequence end, presentation completion and quiet reason one, and keeps every aggregate, cache-overlap, prefill, region and phase error clear. The final generation retains 242 first-field and 240 second-field fetches. Its completed first-field raw and displayed fingerprints are respectively `f964952b` and `e855bf31`, while the second-field pair is `8c26df67` and `ab1ec443`; both completion counters and both mismatch counters saturate at 255, proving at least 255 independently completed mismatches for each parity rather than a terminal-only anomaly. The raw DDR-return byte stream therefore does not survive the line-cache write and post-cache readout boundary in either field, while the gross visual retention remains asymmetric to the first field. This passes the schema-fifteen diagnostic objective and localizes the fault inside cache population, bank ownership, address selection or readout rather than the decoder, DDR region, native raster, final mux or processed-HDMI capture path. Evidence is `.ai/current_results/entry524_stale_first_field_live_early.png` at 11,113 bytes with SHA-256 `2131b1178899856a454a033721c11143c822160259219d6e1e23a44a3624a000`, `.ai/current_results/entry524_stale_first_field_live_late.png` at 11,120 bytes with SHA-256 `d254713100fad7b6a8a410e0d0f0e625e797d7c7c2cec8bc85e298571d239d88` and `.ai/current_results/entry524_schema15_terminal.png` at 12,484 bytes with SHA-256 `b4b78e8d4415f66de5fbc6f6be3795e410ed2e96ad4b95454239fee948157e62`.

#### Next Steps:

Stop before changing behavior and obtain approval for one schema-sixteen cache-provenance boundary. At completion of each luma-line fill, retain the raw line fingerprint, physical source row, cache bank and framebuffer generation; synchronize only completed stable per-bank tags to the video domain, latch the applicable tag before each displayed line begins and compare its expected row and raw line fingerprint with the post-cache bytes completed at that line's end. Preserve the first tag mismatch and first content mismatch separately for each authored field and count each class without feeding cache control. Directed simulation must prove correct TFF and BFF tag/content matches, a wrong-bank tag failure and a one-byte cache-content failure, while the full native, reconstruction and canonical live-raster suites remain exact. A hardware tag mismatch would identify refill ownership or bank selection, while matching tags with differing content would isolate the dual-clock RAM write, word address or byte-lane read pipeline. Continue direct verified replacement of only `/media/fat/MediaPlayer.rbf` with no backup, rollback or staging files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 523 COMMIT Unreleased 4e4db95 2026-08-25T20:41:57-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Correlate each symptom-bearing generation's complete DDR-return luma content with the luma actually read from the line cache for display.

#### Outcome:

The pre-change thirty-second burst acquired forty-nine screenshots at approximately 1.6 frames per second, with seventeen distinct live frames followed by thirty-two byte-identical terminal frames. Both field bars advance during the live interval but are commonly separated by roughly twenty-four pixels rather than the authored four-pixel weave offset, and short horizontal grey edge fragments accompany one field, proving a field-age mismatch rather than one field remaining constant for the entire session. Commit `4e4db95` adds a passive position-sensitive thirty-two-bit fingerprint over all eight bytes of every native luma DDR return and the same byte sequence read from the post-cache display path, separated by authored field and framebuffer generation. Completed video-domain fingerprints cross as stable bundled data behind a three-stage toggle synchronizer, only the source-to-first-stage paths are cut, and the memory domain publishes raw, displayed and mismatch evidence without feeding cache, decoder, scheduler or presentation control. Cadence schema fifteen expands to forty-eight words at diagnostic and native origins 408 and 288, preserves words zero through forty-one, records the four most recent fingerprints and four saturating completion or mismatch counts, retains schema fourteen through legacy decoding, checks every overlay row and independently guards the packed count width. Directed TFF and BFF cache runs each produce two matching completions, an intentionally corrupted cache byte produces exactly one mismatch, and the complete native suite, interlaced reconstruction suite and canonical mixed I/P/B live-raster suite pass, the latter retaining exactly 6,529,997 cycles, twenty-five publications, forty-seven B-picture persistences, seventy-one swaps and no errors. A clean Quartus Prime 17.0.2 build from empty generated state completes in eleven minutes four seconds with zero errors and 143 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.172, 0.245, 3.999, 0.591 and 0.925 nanoseconds with zero endpoint negative slack; focused decoder setup and recovery are positive 1.311 and 11.527 nanoseconds and focused video setup is positive 2.987 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains, and a timing-netlist probe finds every new raw, displayed and mismatch register. The fit uses 30,027 ALMs, 46,948 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,207,656-byte RBF has SHA-256 `f53a686f0775b6bf1fce6be14669c2fe9761e2f6edcdcd5fd4d972b744711b93` and was written directly to `/media/fat/MediaPlayer.rbf`; an immediate ordinary-FTP readback matches its size and hash exactly. At the user's direction, all twenty `MediaPlayer.backup.*` and `MediaPlayer.rbf.rollback*` files were deleted from the MiSTer, the prior active file was not disturbed during that cleanup, and future installations will directly replace and verify the active file without creating backup, rollback or staging copies.

#### Next Steps:

Reload the installed `4e4db95` image, run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while an agent-triggered thirty-second screenshot burst captures the live fault, then decode schema fifteen from that same run. A raw-versus-displayed mismatch localizes corruption to the line-cache write or readout boundary; equality while the field-age mismatch is visible moves the investigation after the cache output. Record the hardware result in a new entry because this source and build boundary is now settled, and continue replacing the active RBF directly without creating backup, rollback or staging files.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `MediaPlayer.sdc`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_interlaced_420_cache_mapping.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 522 COMMIT Unreleased bfb9361 2026-08-25T20:39:25-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Interpret the first schema-fourteen hardware result and define the next evidence boundary without mistaking session-wide variation for generation-correlated correctness.

#### Outcome:

After reloading the installed `bfb9361` image, the user ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` and reports that what appeared to be the second field was duplicated, with the established ghosting and tiny horizontal grey lines still visible during playback. The terminal screenshot `.ai/current_results/entry522_schema14_terminal.png` was triggered and retrieved through ordinary authenticated FTP at 12,278 bytes and SHA-256 `7803856948fb73b61b332a0525fbf89289ef90b3dd0c41d4dbec63567ce5cfc2`. Schema fourteen accepts all 5,007,304 source bytes and its wrapped counters reconstruct 300 reference and displayed pictures with 299 swaps across 599,290,215 cycles, or 29.935413 pictures per second. Sequence end, presentation completion and quiet reason one are present; all error flags are clear. The framebuffer reports 300 generation resets, 299 publications, zero unpublished resets, zero prefill misses, a 2,002,004-cycle maximum publication latency, 242 first-field and 240 second-field fetches in the terminal generation, region one for both fields, zero region mismatches and zero phase errors. Both session-wide varied flags are set and the first-field and second-field signatures are respectively `0x37` and `0x03`. This disproves only a parity returning one constant sampled byte for the entire session. Entries 520 and 521 stated the stronger inference too broadly: the current signature XORs only byte lane zero of each returned sixty-four-bit word and aggregates all generations, so activity outside the symptom-bearing interval can set varied and a terminal snapshot cannot prove that the correct position-dependent field content arrived during the duplicated or ghosted frame. The result therefore passes the schema-fourteen diagnostic objective but does not yet place the loss definitively on either side of the DDR return; it narrows the required correlation to the raw-return, line-cache write and displayed-cache-read boundary.

#### Next Steps:

Do not make a behavioral correction from the coarse signatures. Prepare a bounded schema-fifteen diagnostic that computes generation-correlated, position-sensitive luma fingerprints over all eight bytes of every raw DDR return and over the corresponding post-cache displayed luma samples for each field parity, transfers only completed stable fingerprints across the video-to-decoder clock boundary and counts raw-versus-displayed mismatches without feeding control logic. Retain the established fetch, region, phase, publication and error evidence, add directed tests that prove matching TFF and BFF fields compare equal and an intentionally corrupted cache word compares unequal, preserve schema-fourteen through legacy decoding and run the complete native, reconstruction and live-raster suites before any clean build. If timing closes, repeat the same fixture while an agent-triggered live screenshot burst captures the visible duplication and read the correlated fingerprints from that same run; a mismatch localizes the defect to cache write/readout, while equality moves the search after the cache output.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

