## 679 COMMIT Unreleased ??? 2026-08-28T12:38:01-07:00

#### Coming From:

Unreleased e6ca129

#### Purpose:

Perform one approved seed-only rebuild after seed 18 missed HDMI setup timing.

#### Outcome:

The user authorizes a reseed following entry 678. Change only the Quartus fitter seed from 18 to 19 in MediaPlayer.qsf, preserving production RTL, clocks, timing constraints, physical buffers, Main, helper, test fixtures and the approved terminal-cut qualification boundary. Verify the complete source difference and retain the already qualified native and paired numerical evidence because no functional or simulation input changes. Use a separate clean build directory at /home/vash/mister-builds/entry679/FPGA and retain the failed seed-18 build intact. This authorization covers one new compile, not an automatic seed sweep; if compilation or any timing category fails, pause again without installation or further retries.

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

## 653 COMMIT Unreleased 4777c59 2026-08-27T22:34:30-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Confirm P and B picture decoding is unchanged on the field-DCT bitstream and localise the entry 644 screenshot variation.

#### Outcome:

The user replayed test seven, the only fixture exercising P and B pictures, and reports it looks and sounds perfect. Helper-first collection preserved a log distinct from the test one capture and identifies `test_7_progressive_ipb.mpg` with 11,954,879 bytes of video, 500 audio frames and 576,000 emitted samples, exit zero, and all 882 pipe reads reconciling to 14,439,298 completed transport bytes. Every schema-19 counter matches the entry 628 capture taken on the released `61a2fed2` bitstream, including 11,954,645 accepted video bytes, 121 reference and 239 B pictures, 360 displayed pictures, 359 swaps, final picture type three, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero deadline gaps, and the distinctive twenty-four timestamp advance conflicts and single gap outlier that fixture has always produced; only the largest recorded gap differs, by two clocks. The raster comparison produced the more valuable result. The first capture differed from the released-bitstream baseline at 7,640 of 382,992 compared pixels, every one at x modulo eight equal to one, which is exactly the signature entry 644 recorded and could not isolate. A second screenshot taken without replaying anything, with the core counters verified identical between the two captures, is pixel-identical to that baseline with zero mismatches, while differing from the first capture at the same 7,640 positions. An unchanged completed frame therefore yields both a pixel-exact capture and a differing one. That establishes two things entry 644 left open: the decoded content on this bitstream is identical to what the released bitstream produced, so P and B reconstruction is unaffected by the writer's capture-counter and untruncated-origin changes; and the variation lies in the screenshot capture or readback path rather than in the decoder or the framebuffer content, since neither changed between the two captures. The mechanism within that path is still not identified and the observation remains open on that narrower basis. Entry 644's conclusion that the variation must not be attributed to the operating system or to any source change is confirmed rather than overturned. Passed records this regression only. Tests one and seven have now passed on this bitstream; tests two through six remain unreplayed, and the two items carried from the build remain open, being the unexplained decrease of 372 ALMs and 912 registers and the HDMI setup margin at positive 0.126 nanoseconds.

#### Next Steps:

Treat the raster comparison for progressive content as requiring a repeat capture, because a single screenshot can differ from an identical frame; compare the best of two captures rather than reporting the first as a regression. Replay test four, the progressive all-I control, and optionally tests two, three, five and six, though those carry the same bar and line content already covered by test one's pixel-identical result. Only when the remaining fixtures pass should the field-DCT gate be treated as closed and any release considered. Investigate the capture-path variation as its own scoped question rather than inside a decoder cycle, since it now has a specific signature of every eighth pixel column and a reproducible test of capturing the same frame twice. Resolve the unexplained logic decrease before starting the next feature, and keep the reduced HDMI setup margin visible, reseeding rather than restructuring if a later change pushes that category negative. Interlaced P and B for interlaced streams remain the gate that would make commercial discs play and are unstarted; the deferred field-picture gate still needs either a non-ffmpeg generator or a real disc sample. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 652 COMMIT Unreleased 4777c59 2026-08-27T22:30:33-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Confirm the field-DCT bitstream leaves frame-DCT reconstruction unchanged on the first existing fixture.

#### Outcome:

The user replayed test one and reports it looked perfect; two independent comparisons agree and close the first part of the regression entry 651 left open. Helper-first collection preserved a log distinct from the field-DCT capture, verified by hash before the screenshot, and identifies `test_1_interlace_tff.mpg` with 3,071,260 bytes of video, 500 audio frames and 576,000 emitted samples, exit zero, and all 340 pipe reads reconciling to 5,556,849 completed transport bytes with no fallback and zero slow-path bytes, which is byte for byte the transport entry 640 recorded for the same fixture. Valid schema-19 telemetry records 360 reference and displayed pictures, 359 swaps, 3,068,039 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero native deadline gaps and gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion, all matching the entry 640 record exactly. The raster is the substantive check because the writer's capture-row counter and untruncated block origin affect frame-DCT blocks as well as field-DCT ones, and a reconstruction fault would corrupt pixels while every counter stayed clean. Against ffmpeg's decode of the same file, 279,072 compared pixels outside the telemetry overlay and image column zero give 270,444 exact matches and 8,628 differing by one unit of luma rounding, with none differing by more than one. Against entry 645's capture, which was taken on the released `61a2fed2` bitstream and carries the same bar video content, 279,552 compared pixels give zero mismatches, so this fixture's output is pixel-identical to what the released bitstream produced. The entry 640 screenshot itself was not available for comparison because it was written to the Buildroot beta card, which is no longer installed; the released-bitstream comparison substitutes for it and is the stronger test since it isolates the bitstream change rather than the operating system. Column zero was excluded from the reference comparison on the same basis as entry 651, where identical blanking was shown on the released bitstream. Passed records this regression only. Six fixtures remain unreplayed, and the two items carried from the build remain open: the unexplained decrease of 372 ALMs and 912 registers, and the HDMI setup margin at positive 0.126 nanoseconds.

#### Next Steps:

Replay tests two through seven on this bitstream, prioritising test seven because it is the only fixture exercising P and B pictures and test four because it is the progressive all-I control, and compare each against its reference decode rather than against a beta-card screenshot that no longer exists. Only when those pass should the field-DCT gate be treated as closed. Continue to suspect the capture counter and the untruncated origin before the field mapping if anything regresses. Resolve the unexplained logic decrease before starting the next feature rather than banking it, and keep the reduced HDMI setup margin visible, reseeding rather than restructuring if a later change pushes that category negative. Interlaced P and B remain the gate that would make commercial discs play and are unstarted; the deferred field-picture gate still needs either a non-ffmpeg generator or a real disc sample, and that choice needs the user's direction. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 651 COMMIT Unreleased 4777c59 2026-08-27T22:23:27-07:00

#### Coming From:

Unreleased 4777c59

#### Purpose:

Record hardware acceptance of the field-DCT gate against the reference decode.

#### Outcome:

The user reports the fixture played perfectly and the reference-decode comparison confirms it. The generator was first corrected: it lacked `-y`, so a second run blocked on ffmpeg's overwrite prompt while `capture_output` hid the prompt, which presented as a hang; commit `ceadfd2` adds `-y`, gives ffmpeg no stdin, prints a banner per stage and passes `-stats`, and the fixed script reproduces the fixture byte-identically in about four seconds. Source `4777c59` was built and deployed as RBF `9730e0ba61adbcd5`, replacing the released `61a2fed28425a461` after the installed copy was verified as the expected release, backed up to the card and to the build PC, staged under a temporary name, hash-checked while staged, renamed and read back on a fresh connection; Main and the helper were not touched because this commit changes no software. Helper-first collection confirms the correct fixture at `games/MediaPlayer/test_field_dct.m2v`, video of 3,028,039 bytes exactly matching the generated file, no audio, exit zero and all 185 pipe reads reconciling to the completed transport with no fallback and zero slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,028,040 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero timestamp conflicts, zero native deadline gaps and gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. The decisive evidence is the raster. The released bitstream refused this stream outright because `phase1_supported` required `frame_pred_frame_dct`, so playing at all establishes the gate is open, and comparison against ffmpeg's decode of the same file establishes it is correct rather than merely accepted. Across 279,072 compared pixels, excluding the telemetry overlay with its one-column left edge and image column zero, 272,780 match exactly, 6,292 differ by one unit of luma rounding and none differ by more than one. The woven bar occupies the non-contiguous rows 40, 42, 44, 45, 46, 47, 49 and 51 in both, which is the structure a mishandled `dct_type` would destroy since the two interpretations differ precisely where the bit is set. One difference is real and is not attributable to this change: image column zero is black in hardware where the reference is bright, on those eight bar rows only, with column one onward matching. Entries 645 and 646, captured on the released bitstream with the same bar content, show identical column-zero blanking, so it is a pre-existing display-path left-edge behaviour. Two items from the build remain open and are carried rather than closed: logic fell 372 ALMs and 912 registers while a feature was added, which is unexplained, and setup slack fell 0.117 nanoseconds to positive 0.126 on the HDMI domain. Passed records this fixture only. The seven existing fixtures have not been replayed on this bitstream, so the regression that the writer's capture-counter and untruncated-origin changes demand is outstanding, and field DCT decoding does not make commercial discs play because interlaced P and B remain the gate that does.

#### Next Steps:

Replay the seven existing fixtures on this bitstream and confirm their final rasters remain pixel-identical to the recorded baselines, because the capture row counter and the untruncated block origin affect frame-DCT blocks as well and a reconstruction fault corrupts pixels while every counter stays clean; suspect those two changes before the field mapping if anything regresses. Until that regression passes, do not treat the field-DCT gate as closed or prepare any release. Resolve the unexplained logic decrease before the next feature rather than banking it as a saving, and keep the reduced HDMI setup margin visible, reseeding rather than restructuring if a later change pushes that category negative. The deferred field-picture gate still needs either a non-ffmpeg generator or a real disc sample because ffmpeg cannot encode field pictures, and that choice needs the user's direction. Interlaced P and B, `repeat_first_field` and 576i remain unstarted and unscoped. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 650 COMMIT Unreleased 4777c59 2026-08-27T22:08:18-07:00

#### Coming From:

Unreleased 3e89189

#### Purpose:

Open the field-DCT gate by accepting all-I frame pictures coded with `frame_pred_frame_dct` clear.

#### Outcome:

This entry replaces an earlier field-picture plan that carried the same number and was corrected before work began, because the user directs that fixtures and per-step tests use standard ffmpeg commands and measurement shows that requirement selects the gate. FFmpeg's `mpeg2video` encoder never emits field pictures: an encode with `+ilme` and `+ildct` produced fifteen picture coding extensions all carrying `picture_structure` equal to `2'b11`. The same tool produces field DCT natively, so a single all-intra `+ildct` encode isolates it with no prediction and no second scan table. Committed generator `48d992b` writes `test_field_dct.m2v` from one ffmpeg command and verifies geometry, frame rate code four, 4:2:0, cleared `progressive_sequence`, and that all 360 pictures are intra and frame-structured with `frame_pred_frame_dct`, `alternate_scan`, `intra_vlc_format`, `repeat_first_field`, `chroma_420_type` and `progressive_frame` at the expected values; it decodes independently to reject a stationary fixture and encodes a frame-DCT control to show the flag changed the bitstream. Source `4777c59` relaxes the `frame_pred_frame_dct` term in `phase1_supported`, which is safe because `picture_coding_type` still admits only I pictures so field prediction cannot arise and `picture_structure` still refuses field pictures. The macroblock layer gains one state consuming the `dct_type` bit after `macroblock_type` and any `quantiser_scale_code` and before the first block; `mpeg2_h262_intra_recon` maps blocks two and three one line down rather than eight when it is set; and the writer walks luma rows by 180 instead of 90. Two writer changes affect every block rather than only field-DCT ones and are the first place to look if the existing fixtures regress: the capture row index moves from `pixel_y[2:0]` to a sequential counter because rows two apart alias in the low three bits, and the block origin is no longer truncated to an eight-row boundary, which was a no-op for frame DCT but would discard the odd base row of a field-DCT pair. The bounds check now validates the last row written rather than the first, which is stricter and rejects a frame-DCT origin at row 476 that previously passed and wrote past the plane. The clean build succeeds with zero errors. Block memory is unchanged at 512 of 553, confirming the gate costs no additional M10K against the 41 free blocks. Timing closes in every category with all total negative slack zero: setup positive 0.126, hold 0.245, recovery 3.357, removal 0.632 and minimum pulse width 0.925 nanoseconds. Setup falls 0.117 nanoseconds against the shipped baseline on the HDMI domain that entry 370 established has roughly two percent headroom, so it remains the category to watch and a reseed rather than a restructure is the recorded response if a later change pushes it negative. Logic falls to 31,092 ALMs and 49,361 registers, 372 and 912 below the baseline. That decrease while adding a feature is not explained and is recorded as unexplained rather than rationalised; attempts to attribute it from the fitter and synthesis reports were inconclusive because those reports do not enumerate internal register names, and a check that appeared to show the new logic pruned was invalid for the same reason. The RBF is `9730e0ba61adbcd5` and differs from the released `61a2fed28425a461`, so the netlist did change. Acceptance moved from a telemetry counter to a reference-decode comparison at the user's direction: no ffmpeg command reports whether a macroblock actually set `dct_type`, and all sixty-four snapshot words are occupied, so a counter would have required stealing a deadline-record slot or a sixty-fifth word and a geometry change. Comparing the completed hardware raster against ffmpeg's decode of the same fixture is stronger, because a decoder that ignored `dct_type` would scramble exactly the macroblocks that used it, and the bar content is `cb=128:cr=128` so the chroma-edge difference of the release notes cannot confound it. Built records the successful compile; hardware acceptance is unstarted.

#### Next Steps:

Deploy this RBF only, since no software changed, backing up the installed `MediaPlayer.rbf` first and verifying the staged copy by hash before and after rename. Have the user generate `test_field_dct.m2v` locally and play it, then compare the completed raster against ffmpeg's decode of that same file, and separately confirm the seven existing fixtures still complete with final rasters pixel-identical to their recorded baselines, because the writer changes touch frame-DCT blocks too and a reconstruction fault corrupts pixels while every counter stays clean. Treat acceptance of this fixture as evidence that field DCT decodes, not that discs play: interlaced P and B remain the gate that changes that, and every other interlaced gate only ever decodes I pictures until it exists. If the existing fixtures regress, suspect the capture counter and the untruncated origin before the field mapping. Resolve the unexplained logic decrease before the next feature rather than carrying it forward as an assumed saving. The deferred field-picture gate still needs either a non-ffmpeg generator or a real disc sample, and that choice needs the user's direction. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_luma4_probe.sv
- rtl/mpeg2_new/mpeg2_h262_intra_recon.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_picture_bookkeeper.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 649 COMMIT Unreleased 5fb7d5d 2026-08-27T21:27:18-07:00

#### Coming From:

Unreleased 5fb7d5d

#### Purpose:

Record that widening the residual coefficient memories recovers no M10K because synthesis strips the unused bit.

#### Outcome:

The entry 648 plan is disproven by a clean from-scratch build of `5fb7d5d` after removing `db` and `incremental_db`. The compile is successful with zero errors, and every figure is identical to the shipped v0.8.0 baseline: 31,464 ALMs, 50,273 registers, 512 of 553 M10K, and setup, hold, recovery, removal and minimum pulse width at positive 0.243, 0.251, 2.865, 0.564 and 0.925 nanoseconds with all total negative slack zero. The RBF is byte-identical to the released `61a2fed28425a461`, which alone establishes that the netlist did not change. The fitter report explains why: both coefficient memories still infer at 32,768 by 19 with 622,592 implementation bits, and the generated altsyncram's internal multiplexer is nineteen bits wide. Nothing writes bit nineteen because the write expressions are nineteen bits and zero-extend, and nothing reads it because every consumer slices bits eighteen down to thirteen and twelve down to zero, so the bit is constant and synthesis removes it. Declaring a wider array cannot select the twenty-bit mode; the twentieth bit must carry live data. The underlying measurement from entry 648 stands and is unaffected: an M10K reaches 10,240 bits only in the five, ten and twenty bit modes, our own build shows widths of twenty and forty achieving that against 8,192 for widths of one, sixteen, nineteen and thirty-five, and the existing twenty-bit `residual_block_mem` remains the one memory at full efficiency. What is disproven is the padding shortcut, not the efficiency finding. The consequence differs per path. The B path has nothing to place in the new bit because its own comment records that it already folded its last-flag into a pointer, so no saving is available there by this route. The P path can still gain roughly sixteen blocks by folding the separate one-bit `residual_coeff_last_mem` into bit nineteen, which both makes the bit live and deletes a four-block memory, taking 80 blocks to 64; that requires handling the retroactive write at address `count` minus one and is design work rather than padding. The harder repacking candidates are unaffected because repacking uses the extra bits by construction. This build also corrects a stale figure: the Aug 26 report used during investigation showed 464 blocks because `clean_video_queue` was then 16,384 by 8 at 16 blocks and is now 65,536 by 8 at 64, which accounts for the whole difference to 512. Two operational errors are recorded rather than hidden. A first compile launched detached was wrongly judged killed, a second was started against the same project, and the resulting database contention failed analysis and synthesis with zero errors reported; both were stopped and the intermediates removed before the clean run. A `pkill` pattern also matched the agent's own shell and terminated a command mid-sequence. Neither touched tracked source, the repository or the baselines. Nothing is deployed because the bitstream is identical to what is already installed, so no hardware test is possible or meaningful, and the free-block position is unchanged at 41 with the entry 608 buffer deepening still costed at roughly twenty-six blocks and the picture 690 repeated-frame limitation still accepted.

#### Next Steps:

Decide whether to revert `5fb7d5d`, which is recommended because the widened declarations are inert and a future reader could mistake them for a working optimization, and whether to scope the P path merge as its own cycle for roughly sixteen blocks. Do not attempt the same padding on any other memory, and treat width alone as insufficient evidence for any future M10K estimate; only a change that makes the extra bits carry data will move the block count. If more memory is wanted after that, the repacking candidates remain, being the 65,536 by 16 `shared_residual_store` at roughly twenty-five blocks, `stream_fifo` at six and `video_fifo` at three, each requiring address arithmetic rather than declaration changes, and the two identical 32,768 by 19 controller stores remain the largest single prize at seventy-six blocks if they are ever shown not to be simultaneously live. Keep the interlaced gates of field pictures, field DCT, interlaced P and B, `repeat_first_field` and 576i unstarted and unscoped until a memory budget exists, since those gates are what any recovered blocks would fund. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 648 COMMIT Unreleased 5fb7d5d 2026-08-27T21:08:11-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Recover M10K blocks by widening the P and B residual coefficient memories to the Cyclone V native twenty-bit mode.

#### Outcome:

This entry is written as a plan and its commit does not exist yet. Investigation of the Aug 26 fitter report establishes that block-memory efficiency in this design is governed by data width rather than by capacity. A Cyclone V M10K holds 10,240 bits but reaches that only in the five, ten and twenty bit modes that use the parity bits; narrower widths cap at 8,192. Measured across every inferred memory in our own build, widths of twenty and forty achieve 10,240 bits per block while widths of one, sixteen, nineteen and thirty-five achieve exactly 8,192, and the existing twenty-bit `residual_block_mem` is the one memory already at full efficiency. Two memories dominate: `residual_coeff_mem` in the P path and its counterpart in the B path, each declared nineteen bits deep by 32,768 entries and each costing 76 blocks against a theoretical 64. Padding both to twenty bits is expected to recover roughly twelve blocks each, about twenty-four in total, against the 41 free blocks recorded in entry 609. The change is a pure width change with no functional effect: both paths store a six-bit coefficient index in bits eighteen down to thirteen and a signed thirteen-bit level in bits twelve down to zero, every consumer slices those fields explicitly, and the nineteen-bit write expressions zero-extend into the wider word. Four declarations change, being each memory and its read register, and no consumer is touched. Two candidates found during the same investigation are deliberately excluded. The audio `pcm_fifo` would yield only three blocks and would require padding and slicing a `dcfifo` on an audio path already qualified and shipped in v0.8.0, which is a poor trade against re-qualification. Folding the P path's separate one-bit `residual_coeff_last_mem` into the new bit nineteen would eliminate a further four-block memory, but that flag is written retroactively at address `count` minus one, decoupled from the coefficient write, so it needs a read-modify-write or a second port and is design work rather than padding. Both remain available later. Nothing is built or changed yet, so both status boxes are unchecked, and the recovery figure is a prediction from the report rather than a measured fit result.

#### Next Steps:

Make the four declaration changes, commit them as the source commit for this cycle, and replace this entry's placeholder hash. Then build on the build PC and compare the fitter report against the shipped v0.8.0 figures of 31,464 ALMs, 512 of 553 M10K and positive 0.243 nanoseconds setup, confirming that M10K falls by approximately twenty-four blocks, that the two memories now report 10,240 bits per block, and that no timing category regresses. Treat an unchanged block count as the inference not selecting twenty-bit mode rather than as a disproven finding, and inspect the implementation width before making any further change. Because HDMI setup has roughly two percent headroom and responds to placement, a negative setup result should be met with a reseed rather than a restructure, consistent with the position recorded in the entry 370 cycle. Hardware validation needs a decode regression proving the residual path is unaffected, since a mis-sliced coefficient would corrupt picture content rather than raise an error flag. Keep the recovered blocks unallocated until interlaced sub-gate scoping decides what they fund; the entry 608 buffer deepening at roughly twenty-six blocks and the remaining interlaced gates of entry 609 are both candidates and neither is approved. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh

#### Status:

- [ ] Built
- [ ] Passed

---

## 647 COMMIT Unreleased 2045c34 2026-08-27T20:26:43-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Close the seven-fixture Buildroot beta matrix with AC-3 S/PDIF passthrough and record the user's acceptance.

#### Outcome:

The user reports the run was perfect and the woofer channel audible. Helper-first retrieval preserved a log distinct from both the entry 645 decode run and the entry 646 DTS run, verified by hash before the screenshot was taken. The helper identifies the correct fixture, reports `spdif` IEC 61937 passthrough, locates AC-3 on private substream `0x80` rather than the decoded stereo mode of entry 645, carries 375 audio frames and 576,000 emitted samples as the burst carrier, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,835 completed transport bytes with no acknowledged fallback payload and zero slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault at FIFO peak 127, zero timestamp conflicts of either kind, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. Every one of those counters matches the standard-MiSTer capture in entry 627, including identical video bytes, AC-3 frame count, emitted samples, transport bytes and pipe reads, and the final raster is pixel-identical across all 280,064 pixels outside the telemetry overlay. Only delivered frames per second differs. Entry 627 captured this run before installing the current Main and reports profile version one `credit_fast_v1` against this run's version two, so transport-layer timing figures are not comparable while the counters are. The audible LFE matches AC-3 S/PDIF behaviour on standard MiSTer recorded in entries 621 and 626 and contrasts with entry 646, where the same receiver does not reproduce DTS LFE despite measured content in the bursts, confirming that observation as a device property rather than an output-path fault. With this run the matrix is complete and the user accepts it. That acceptance covers the seven fixtures and their modes on the pinned beta using unchanged v0.8.0 binaries, and nothing further: the unisolated test-four screenshot variation, the unchecked filesystem dirty flag, the uncontrolled boot-time input warnings, the single-frame scope of every pixel comparison, and the older-Main provenance of the entry 626 and 627 audio baselines all remain explicitly outside it. A one-page findings report was written for the Buildroot maintainer and moved by the user to a local path for private delivery; it is not committed to the repository and states these same limits. Built remains unchecked because no new build occurs.

#### Next Steps:

Decide whether the findings report should be committed to the repository or remain a private communication, since it currently exists only outside version control. If the collaboration proceeds, re-running this matrix against future beta drops is cheap because the fixtures and capture script are deterministic and committed. The unisolated test-four screenshot variation and the filesystem dirty-flag warning remain open and should each be scoped as their own investigation with user approval rather than folded into any future acceptance. The longer-term question of retiring the ARM helper by moving source, demux, timeline and audio codec responsibilities onto the platform stays a discussion item and not approved work. The next MediaPlayer development milestone remains unapproved and should be scoped separately, with the interlaced decoding gaps of entry 609 still open and out of scope. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 646 COMMIT Unreleased 2045c34 2026-08-27T20:14:53-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate DTS S/PDIF passthrough on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports test six works perfectly and clarifies that the woofer did not play. Helper-first retrieval preserved a log distinct from the test five capture, followed by a fresh uniquely named screenshot. The helper identifies the correct fixture, reports `spdif` IEC 61937 passthrough for AC-3 and DTS, locates DTS on private substream `0x88`, carries 1125 audio frames, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,868 completed transport bytes with no acknowledged fallback payload and zero slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,038 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault at FIFO peak 127, zero timestamp conflicts of either kind, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. Comparison against the standard-MiSTer capture in entry 626 matches on every completion, error, cadence and audio counter, including identical video bytes, DTS frame count, emitted sample count, transport bytes and pipe reads; only delivered frames per second differs, by under two thousandths of a frame per second. As with entry 645, entry 626 predates the current Main and reports profile version one `credit_fast_v1` against this run's version two `credit_step_v1`, so transport-layer timing figures between them are not comparable while the counters are. The final raster is pixel-identical to the standard baseline across all 280,064 pixels outside the telemetry overlay. This entry corrects a prediction stated before the run: passthrough was expected to emit no PCM, but IEC 61937 carries the compressed bursts inside the PCM stream, so the 576,000 emitted samples are the burst carrier rather than decoded audio, and the standard baseline reports the identical figure. The absent woofer is the receiver behaviour already recorded in entries 621 and 626, where measurement established LFE present in the emitted bursts at 1267.3 RMS, so it remains a device observation rather than a core limitation or a Buildroot regression. Passed records this functional test only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local and only `.ai/current_results/entry646_buildroot_test6_dts_spdif_status.json` is published.

#### Next Steps:

The core is already in S/PDIF, so replay test_5_audio_ac3_51.mpg in that mode to close the last untested path in the seven-fixture matrix, retaining its helper log before another file overwrites it and taking a separate uniquely named screenshot; entry 627 holds the standard-MiSTer AC-3 S/PDIF baseline. Expect the helper to report passthrough on substream `0x80` rather than the decoded stereo mode of entry 645, and expect a non-zero emitted sample count as the IEC 61937 carrier. Progressive is already covered by entry 639 for I/P/B and entry 644 for all-I and needs no replay. Once that run is accepted the user may declare the matrix accepted, which should be recorded as acceptance of the seven fixtures only, with the unisolated test-four screenshot variation and the unchecked filesystem dirty flag carried forward as separate open items explicitly outside that scope. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 645 COMMIT Unreleased 2045c34 2026-08-27T20:03:12-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate AC-3 5.1 decode to HDMI on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports test five passes everything. Helper-first retrieval preserved the log before any further playback, followed by a fresh uniquely named screenshot. The helper identifies the correct fixture at `games/MediaPlayer/Buildroot_beta/test_5_audio_ac3_51.mpg`, reports HDMI decoded stereo PCM, locates AC-3 on private substream `0x80`, decodes 375 audio frames to 576,000 samples and emits all 576,000, exits zero on end of file, and reconciles all 340 pipe reads to 5,556,835 completed transport bytes with no acknowledged fallback payload and no slow-path bytes. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, top-field-first signalling, zero decoder and presentation errors, no audio underrun or PCM protocol fault, zero timestamp advance and delay conflicts, zero native deadline gaps, zero gap outliers, three largest display intervals each at the nominal 2,002,000 clocks, and sequence end with quiet completion. The fixture shares test one's bar video by design, which is why its accepted video byte count matches entry 640 exactly; that is the generator's definition rather than a repeat of the entry 639 stale-fixture error. Comparison against the standard-MiSTer capture in entry 626 matches on every completion, error, cadence and audio counter, including identical video bytes, AC-3 frame count, emitted samples, transport bytes and pipe reads; only delivered frames per second and cadence seconds differ, by about 1.3 milliseconds across a twelve second run. Entry 626 was captured under the older profile version one `credit_fast_v1` transport while this run uses profile version two `credit_step_v1`, so transport-layer timing figures between them are not comparable. The final raster is pixel-identical to the standard baseline across all 280,064 pixels outside the telemetry overlay; this is a single-frame comparison on static bar content and does not isolate the entry 644 progressive screenshot variation nor establish full playback pixel qualification. Independent read-only readback confirms the unchanged Main, helper, RBF, kernel and this fixture against the card manifest. Bob was the requested deinterlacer and the audible channel sweep relies on the user's report, since telemetry attests neither. The user hears the channel sweep reproduce correctly and reports the soundbar's woofer working properly, which confirms that low frequency content survives the downmix. It does not establish LFE delivery over HDMI: the AC-3 stereo downmix discards LFE by design, so the woofer output is the soundbar's own bass management applied to the stereo pair, and discrete LFE remains a question for the S/PDIF passthrough run. Passed records this functional test only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local and only `.ai/current_results/entry645_buildroot_test5_ac3_hdmi_status.json` is published.

#### Next Steps:

Switch the core's audio mode to S/PDIF and replay test_5_audio_ac3_51.mpg as an AC-3 passthrough run, retaining its helper log before another file overwrites it and taking a separate uniquely named screenshot; entry 627 holds the standard-MiSTer S/PDIF baseline for that comparison. Then run test_6_audio_dts_51.mpg as DTS S/PDIF passthrough to close the seven-fixture matrix. Expect the passthrough runs to report no decoded PCM, so do not treat an absent sample count as a fault. Keep overall beta qualification open until both remaining audio runs are accepted, and retain the unisolated test-four screenshot variation and the unresolved filesystem dirty-flag check as separate open items rather than folding either into this result. Do not begin a source fix or attribute anything to Buildroot without evidence and approval for a revised plan. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 644 COMMIT Unreleased 2045c34 2026-08-27T19:55:50-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate progressive all-I test four with user-reported Weave and HDMI audio on the Buildroot beta.

#### Outcome:

The user reports everything passes in Weave. Helper-first retrieval and a fresh screenshot confirm the correct fixture and valid schema-19 telemetry: 360 reference and displayed pictures, zero B pictures, 359 swaps, 12,057,601 accepted video bytes, zero decoder or presentation errors, no audio underrun or PCM protocol fault, sequence end and quiet completion. Six timestamp-advance conflicts, zero delay conflicts and zero native deadline-gap and gap-outlier counters match entry 628's standard-MiSTer test-four rerun. Largest display intervals are about 49.7 milliseconds on both systems; zero native deadline-gap counters do not establish perfect progressive cadence. The helper confirms HDMI decoded output, 576,000 emitted PCM samples and exit zero; all 888 pipe reads reconcile to 14,546,422 completed transport bytes without acknowledged fallback payload. Readback verifies the unchanged runtime, kernel and fixture, and the comparator's Main, RBF and fixture identities match. An additional final-raster comparison is inconclusive: outside telemetry, the first screenshot differs from the standard baseline at 8,820 of 433,920 pixels, all at x modulo eight equal to one. A second screenshot without replay differs from the first at 4,418 pixels and from the standard at 8,816, with unchanged telemetry and helper log. The source of this variation is not isolated, so neither pixel equivalence nor a Buildroot regression is established. Weave selection and appearance rely on the user's report. Passed records functional acceptance only; Built remains unchecked because no new build occurs. No deployment, mode change, replay, reload or reboot is initiated. Raw captures remain local; only .ai/current_results/entry644_buildroot_test4_status.json is published.

#### Next Steps:

Run test_5_audio_ac3_51.mpg with Bob and HDMI audio, then retain the completed screen for collection before testing AC-3 S/PDIF and DTS S/PDIF separately. Confirm the expected audible channel sweep; the HDMI downmix intentionally omits LFE. Keep overall beta qualification open pending the remaining audio matrix, and retain the unisolated test-four screenshot variation as a separate video-quality caveat alongside the unresolved filesystem dirty-flag check. Do not begin a source fix or attribute either observation to Buildroot without evidence and approval for a revised investigation. Preserve runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 643 COMMIT Unreleased 2045c34 2026-08-27T19:51:27-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate test three's separate Weave and HDMI playback on the Buildroot beta.

#### Outcome:

The user explicitly reports completing Weave with everything passing. Helper-first retrieval preserves a log distinct from the Bob run, followed by a fresh uniquely named screenshot. Valid schema-19 telemetry confirms 360 reference and displayed pictures, zero B pictures, 359 swaps and 12,073,185 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are absent; the three largest recorded display intervals are each 2,002,000 clocks. Sequence end, completed presentation and quiet termination are asserted. Helper exit is zero, all 889 pipe reads reconcile to 14,562,019 completed transport bytes, and no acknowledged fallback payload is reported. HDMI decoded output and 576,000 emitted PCM samples are confirmed. Completion, error and cadence counters match the Bob run; scaler selection and appearance rely on the user's report rather than telemetry. Readback verifies the unchanged Main, helper, RBF, kernel and fixture. Both requested test-three modes now have separately captured accepted runs. Passed is scoped to Weave; Built remains unchecked because no new build occurs. No deployment, playback, mode change, reload or reboot is initiated by the agent. Raw captures stay local; only .ai/current_results/entry643_buildroot_test3_weave_status.json is published.

#### Next Steps:

Run test_4_progressive.mpg with HDMI audio and preserve its completed screen for separate helper-first collection. Then complete AC-3 HDMI decode, AC-3 S/PDIF passthrough and DTS S/PDIF passthrough as separate runs. Keep overall beta qualification open until the remaining matrix is accepted and the storage dirty-flag warning as a separate unresolved filesystem check. Preserve unchanged runtime identities, user control of hardware lifecycle, local-only raw data, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 642 COMMIT Unreleased 2045c34 2026-08-27T19:45:33-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate test three's requested Bob and HDMI playback on the Buildroot beta.

#### Outcome:

The user reports test three passes. Helper-first retrieval and a fresh screenshot identify the scrolling-band fixture and provide valid schema-19 telemetry with 360 reference and displayed pictures, zero B pictures, 359 swaps and 12,073,185 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are absent. All three largest recorded display intervals are 2,002,000 clocks, with sequence end, completed presentation and quiet termination asserted. Helper exit is zero and all pipe reads reconcile to 14,562,019 completed transport bytes, without acknowledged fallback payload. HDMI decoded output is confirmed; Bob was requested and the user accepts that run, but telemetry does not independently identify the scaler selection or LED colors. The helper reports 576,000 emitted PCM frames. Independent readback confirms the fixture and unchanged Main, helper, RBF and kernel. Passed is scoped to the requested Bob test; no new build occurs, so Built stays unchecked. No deployment, mode change, reload, reboot or playback is initiated by the agent. Raw data remains in ignored local results and only .ai/current_results/entry642_buildroot_test3_bob_status.json is published.

#### Next Steps:

Switch HDMI scaler deinterlacer to Weave and replay test_3_deinterlace_bob_weave.mpg with HDMI audio, preserving a separate helper log and fresh terminal screenshot afterward. The user must judge the deinterlacing appearance because the terminal telemetry does not identify the HDMI scaler mode. Then complete the progressive all-I test four and separate AC-3 HDMI, AC-3 S/PDIF and DTS S/PDIF runs. Keep the storage dirty-flag warning as a separate unresolved check and leave overall beta qualification open until the matrix is complete. Preserve runtime identities, user control of hardware lifecycle, local-only raw captures, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 641 COMMIT Unreleased 2045c34 2026-08-27T19:42:33-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate corrected interlaced BFF playback on the Buildroot beta.

#### Outcome:

The user reports that corrected test two passes. Helper-first collection and a fresh uniquely named screenshot identify that exact run, with valid schema-19 telemetry confirming bottom-field-first signalling, 360 reference and displayed pictures, zero B pictures, 359 swaps and 3,067,813 accepted video bytes. Decoder and presentation errors, audio underrun, PCM protocol faults, timestamp conflicts, native deadline gaps and gap outliers are all absent. The three largest recorded display intervals are each the nominal 2,002,000 clocks, and sequence end, completed presentation and quiet termination are asserted. Helper exit is zero; pipe reads reconcile to all 5,556,652 completed transport bytes, with no acknowledged fallback payload. The helper confirms HDMI decoded audio and reports 576,000 emitted PCM frames. Bob was requested and the user accepts the requested run, but telemetry does not independently identify the scaler selection or LED colors. Read-only verification confirms the corrected fixture and unchanged Main, helper, RBF and kernel hashes. Together with entry 640, both interlaced field orders now have accepted bounded playback runs on the beta, alongside entry 639's progressive I/P/B result. No source, build, deployment, mode change, reload, reboot or playback is initiated by the agent. Built remains unchecked because no new build occurs; Passed is scoped to this BFF clip. Raw captures remain local and only .ai/current_results/entry641_buildroot_test2_status.json is published.

#### Next Steps:

Run test_3_deinterlace_bob_weave.mpg with Bob and HDMI first, retain its helper log and terminal screenshot, then repeat in Weave with separate captures. Finish test four's progressive all-I control and the AC-3 HDMI, AC-3 S/PDIF and DTS S/PDIF runs before claiming the full seven-fixture compatibility matrix. Keep the filesystem dirty-flag warning as a separate unresolved check and do not treat single-run timing values as performance qualification. Preserve the tested beta and runtime identities, user control of hardware lifecycle, local-only raw reports, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---

## 640 COMMIT Unreleased 2045c34 2026-08-27T19:39:38-07:00

#### Coming From:

Unreleased 2045c34

#### Purpose:

Validate the corrected interlaced TFF playback fixture on the Buildroot beta against the recorded standard-MiSTer result.

#### Outcome:

The user reports that corrected test one now passes. Helper-first collection and a fresh uniquely named screenshot confirm that exact file completed under the unchanged released runtime. Valid schema-19 telemetry records 360 reference and displayed pictures, zero B pictures, 359 swaps, 3,068,039 accepted video bytes, no decoder or presentation error, no audio underrun or PCM protocol fault, zero timestamp conflicts, zero missed native display deadlines and no gap outliers. Each of the three recorded largest display intervals is the nominal 2,002,000 clocks. Sequence end, presentation completion and quiet termination are set. Helper exit is zero and all pipe reads reconcile to 5,556,849 completed transport bytes. HDMI decoded audio is confirmed by the helper; Bob was the requested setting and the user reports passing that run, but the telemetry does not independently attest the scaler setting or LED colors. Independent readback confirms the corrected fixture, RBF, Main, helper and kernel identities. Completion, error and native-cadence indicators match the recorded standard-MiSTer test-one result. Combined with entry 639, this establishes successful bounded interlaced all-I and progressive I/P/B runs on the beta; it is not the full compatibility matrix. No build, deployment, mode change, reload, reboot or playback is initiated by the agent. Built stays unchecked because no new build occurs; Passed records only this user-accepted TFF test. Raw captures and detailed comparison remain local, with only .ai/current_results/entry640_buildroot_test1_status.json published.

#### Next Steps:

Continue with corrected test_2_interlace_bff.mpg under the same requested Bob and HDMI settings, capture it before another file overwrites its helper log, then qualify Bob versus Weave and the AC-3 decode, AC-3 passthrough and DTS passthrough modes separately. Keep the initial single-frame progressive pixel comparison distinct from comprehensive video quality and do not infer performance improvements from one run's timing values. The storage dirty-flag warning remains a separate unresolved check. Preserve the known runtime and beta identities, user control of hardware lifecycle, local-only raw reports, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [x] Passed

---
