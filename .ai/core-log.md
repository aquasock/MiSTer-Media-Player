## 844 COMMIT Unreleased 924cb21 2026-08-31T19:48:07-07:00

#### Coming From:

Unreleased c787835

#### Purpose:

Build and verify the Main-only 500 millisecond stream-hop drain diagnostic for physical FIFO-residue testing.

#### Outcome:

The exact clean source checkout `924cb217c1617a3c466df28094616758c3ad2644` on build PC `10.10.0.42` applies both pinned Main patches in order and builds Main successfully with MiSTer's pinned GNU 10.2.1 ARM toolchain.  The uniquely preserved `/home/vash/MiSTer-Media-Player-924cb21/host/build/MiSTer_StreamHopDrain_924cb21` and local `host/build/MiSTer_StreamHopDrain_924cb21` are byte-identical 1,178,588-byte stripped dynamically linked 32-bit ARM EABI5 executables at SHA-256 `6f49f425dae7e789c2f54b919fcc99fdb0f804e0ebbb60996f7c235e799bdf65`; the binary contains the required `stream hop drain release_to_rearm_us` marker.  The source checkout remains clean, and no helper, RBF, MiSTer installation, media or running process changes during this build.

#### Next Steps:

The user will manually replace only `/media/fat/MiSTer` with local `host/build/MiSTer_StreamHopDrain_924cb21`, restore executable mode if needed, verify the exact size and SHA-256, and reboot while preserving the installed ordinary helper and source-`f5f650f` RBF.  Start the physical DVD and perform at least twenty consecutive `M` root-menu reloads; acceptance requires every completed hop to log `release_to_rearm_us` at or above 500,000, continued menu video and selector operation, and no schema-21 `0x0200` raster, while any recurrence rejects residual FIFO drain as a sufficient remedy.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 843 COMMIT Unreleased 924cb21 2026-08-31T19:45:27-07:00

#### Coming From:

Unreleased 64f5156

#### Purpose:

Restore clean applicability of the pinned Main patch stack without changing the approved stream-hop drain experiment.

#### Outcome:

The exact source-`64f5156` Main build stops before compilation because the following overlay-trace patch retains context around the original transfer-profile declarations and the first patch inserted the new drain constants inside that context.  No compiler, link, binary or target result is produced.  Source `924cb21` relocates only those two declarations ahead of the retained context, preserving the same 500 millisecond behavior, log format, helper, RBF and submitted bytes; the complete first patch is structurally valid and whitespace-clean, and exact ARM compilation remains pending.

#### Next Steps:

Rebuild Main from exact source `924cb21` on build PC `10.10.0.42`, verify the resulting ARM executable and diagnostic marker, and then return to entry 842's unchanged twenty-hop physical acceptance test.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 842 COMMIT Unreleased 64f5156 2026-08-31T19:40:09-07:00

#### Coming From:

Unreleased 3c68242

#### Purpose:

Test whether residual pre-hop bytes in the FPGA input FIFO cause the intermittent root-menu B-picture presentation failure without rebuilding the RBF.

#### Outcome:

The user approves and source `64f5156` implements a Main-only diagnostic after one physical session completes repeated root-menu reloads before a later identical hop fails with only `0x0200`; the failing reset session accepts 18,937 bytes, recognizes a B picture at temporal reference ten while frame-rate code remains zero, and therefore reaches a picture header before parsing the new sequence header.  The helper reports the same valid sequence, intra and following-reference boundary on the successful and failing menu-to-menu hops, while static inspection proves that each `ioctl_download` rising edge resets the MPEG decoder but leaves the 32 KiB dual-clock input FIFO intact until a full core reset.  Main now timestamps every chapter or menu download release, waits until at least 500 milliseconds have elapsed before the next rising edge, and logs the measured release-to-rearm interval without changing the helper, RBF or submitted stream bytes; the complete pinned patch is structurally valid and whitespace-clean, while exact ARM compilation remains pending.

#### Next Steps:

Build and verify one uniquely named ARM Main from exact source `64f5156`, then preserve the installed helper and source-`f5f650f` RBF while manually replacing only Main and rebooting.  Hardware acceptance requires at least twenty consecutive `M` root-menu reloads without the schema-21 `0x0200` raster, with each log recording a download-off interval of at least 500 milliseconds; any recurrence rejects the drain hypothesis and returns to exact scheduler-source instrumentation.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 841 COMMIT Unreleased f5f650f 2026-08-31T19:20:09-07:00

#### Coming From:

Unreleased 647c36e

#### Purpose:

Build and qualify the ordinary ARM helper that restores the authored DVD selector while preserving the accepted Main and RBF.

#### Outcome:

The exact clean checkout `f5f650f87109193e90c664175b1785e721134d26` on build PC `10.10.0.42` builds the normal native helper with strict warnings and passes its capability smoke test plus the focused fragmented-subpicture, selected-histogram, scheduled-stop, random-access and menu-hop regressions.  The same exact source builds the ordinary ARM helper without defining `MMP_DVD_OVERLAY_PROBE` under MiSTer's pinned GNU 10.2.1 toolchain.  `/home/vash/MiSTer-Media-Player-f5f650f/host/build/MediaPlayer_Helper` is a 908,660-byte stripped static 32-bit ARM EABI5 hard-float executable with no dynamic section, contains no `probe=solid-index1-magenta` marker and has SHA-256 `7818463017de063ba72846429c60816b967444b0137dcd2f156d9902ae96e96b`.  The artifact is copied byte-identically to local `host/build/MediaPlayer_Helper` for the user's manual transfer.  No repository source, Main, RBF, MiSTer file, running process or playback setting changes during this build.

#### Next Steps:

The user will exit the MediaPlayer core so the probe helper is no longer running, manually replace only `/media/fat/linux/MediaPlayer_Helper` with local `host/build/MediaPlayer_Helper`, create no backup, preserve Main and `/media/fat/MediaPlayer_20260831_f5f650f.rbf`, restore executable mode if the transfer client clears it, and verify the installed file is 908,660 bytes with SHA-256 `7818463017de063ba72846429c60816b967444b0137dcd2f156d9902ae96e96b`.  Restart the DVD, enter the root menu and move among all four buttons; acceptance requires the solid magenta rectangle to disappear and the sparse authored highlight to follow the selector, after which collect a fresh screenshot and helper log.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 840 COMMIT Unreleased f5f650f 2026-08-31T19:16:30-07:00

#### Coming From:

Unreleased 648c0ed

#### Purpose:

Accept the retained DVD overlay transfer repair on physical hardware and define the helper-only boundary that restores the authored menu selector.

#### Outcome:

The user's physical source-`f5f650f` capture accepts the repaired RBF for its targeted transfer fault.  The checksum-valid schema-21 snapshot at SHA-256 `f218fbd3946c0b59db43b6aa46a86059a90adbb70750fb18dfc1f030ae55829e` reports one config, 22 data records, one commit, two styles, one clear, zero rejected commits, one accepted commit and one plane publication; all 86,400 plane bytes reach the engine, all 10,800 DDR words complete with byte lane zero, and the engine is ready with no protocol error or pending publication.  The video domain counts 88,800 highlighted samples, all 88,800 with nonzero alpha and all 88,800 opaque magenta.  The 1,920-by-1,080 screenshot at SHA-256 `ed6e5b3920d5007ff0176bb6d5f2e20124c25888c8820dc22ef0fa13f1ed77fa` contains exactly 34,560 magenta pixels in one 320-by-108 rectangle from output coordinate 830,876 through 1,149,983, precisely scaling the helper log's current DVD rectangle 311,389 through 430,436.  The 2,286,369-byte Main/helper log at SHA-256 `3167ce45cd803779dcfe328a9235f9fb0c7e74a558e6b9a3b4a20c41f4a338d7` records successful style movement among the authored button rectangles.  The solid rectangle is the intentionally installed `MMP_DVD_OVERLAY_PROBE` helper output, while ordinary source already emits the real decoded two-bit plane and authored palette; no further RBF or source correction is indicated for this selector restoration.

#### Next Steps:

From an exact clean source-`f5f650f` checkout on build PC `10.10.0.42`, run the focused subpicture, random-access and menu-hop regressions, build the ordinary ARM helper without `MMP_DVD_OVERLAY_PROBE`, and verify it is a stripped static ARMv7 executable with no dynamic section.  Preserve Main and `MediaPlayer_20260831_f5f650f.rbf`, stop the running helper by exiting the core, replace only `/media/fat/linux/MediaPlayer_Helper` under the user's no-backup policy, verify the installed bytes by readback, then restart the DVD and require a sparse authored selector that follows all menu choices without any solid magenta rectangle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 839 COMMIT Unreleased f5f650f 2026-08-31T16:56:30-07:00

#### Coming From:

Unreleased 667d284

#### Purpose:

Build and qualify the exact source-`f5f650f` retained DVD overlay handshake correction for physical MiSTer testing.

#### Outcome:

The exact clean source checkout `f5f650f87109193e90c664175b1785e721134d26` passes the strengthened metadata extractor regression, the complete 86,400-byte integrated stalled-DDR regression, and the retained overlay-engine, DDR-arbiter and schema-21 snapshot regressions under Icarus Verilog on build PC `10.10.0.42`.  Quartus Prime 17.0.2 seed 20 completes synthesis, fitting, assembly and the project timing gate with zero errors; global setup, hold, recovery, removal and minimum-pulse-width slacks are respectively positive at 0.321, 0.243, 3.618, 0.605 and 0.925 nanoseconds, while the dedicated 60 MHz decoder and 54 MHz video checks have 0.491 and 1.385 nanoseconds of setup slack and no violations.  The fit uses 34,710 ALMs, 54,437 registers, 4,187,011 block-memory bits and 70 DSP blocks.  The uniquely preserved `output_files/MediaPlayer_20260831_f5f650f.rbf` is 4,456,796 bytes with SHA-256 `4c57f9350b3c553d322395d0d4c0f7cc78dc14f8d7be863a251c83d10af647f7`, identical on the build PC and in the local workspace.  No Main, helper, MiSTer installation, media or playback setting changes at this build boundary.

#### Next Steps:

Preserve the installed Main and helper, upload only `MediaPlayer_20260831_f5f650f.rbf` as a new file rather than overwriting the current rollback, load that core, restart the DVD, enter the root menu and move the selector several times.  Require visible opaque-magenta highlight pixels, then wait at least two seconds and collect fresh telemetry, screenshot and Main/helper log; schema 21 should report one good and zero bad commits, one plane publication, 86,400 submitted and accepted plane bytes, 10,800 DDR words and nonzero alpha and magenta sample counters.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 838 COMMIT Unreleased f5f650f 2026-08-31T16:39:27-07:00

#### Coming From:

Unreleased 6dbbaf6

#### Purpose:

Preserve the repaired DVD overlay handshake while restoring positive global setup timing after the first exact-source fit.

#### Outcome:

Exact source `4821744` remains functionally accepted by all five focused overlay simulations, but its clean Quartus Prime 17.0.2 seed-20 build is rejected by the project timing gate at global setup slack negative 0.441 nanoseconds.  The dedicated 60 MHz decoder and 54 MHz video domains remain violation-free at positive 0.557 and 2.529 nanoseconds, and hold, recovery, removal and minimum-pulse-width slacks remain positive.  A read-only fifty-path TimeQuest report proves every reported violation is the unrelated HDMI-domain scaler path from `ascal|o_vacpt` through its address DSP terminals, while the changed elastic extractor slot added a simultaneous ready-transfer replacement path into upstream readiness and perturbed packing.  Source `f5f650f` retains every overlay byte but makes the one-entry output slot non-elastic: upstream stops whenever the slot is occupied and resumes on the cycle after the engine accepts it, removing the new combinational ready path at the cost of one harmless decoder-clock bubble per overlay byte.  The strengthened extractor and complete 86,400-byte integrated stalled-DDR tests pass again, as do the retained engine, arbiter and snapshot regressions, with the integrated test still requiring all 10,800 DDR writes, an accepted plane publication and opaque-magenta video output.

#### Next Steps:

Check out exact source `f5f650f` on build PC `10.10.0.42`, rerun all five focused regressions from that clean source, then perform a second clean Quartus Prime 17.0.2 seed-20 build.  Reject any RBF unless global setup, hold, recovery, removal and minimum-pulse-width timing are all positive and both dedicated decoder and video timing reports contain no violations.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 837 COMMIT Unreleased 4821744 2026-08-31T16:18:01-07:00

#### Coming From:

Unreleased 6e0df01

#### Purpose:

Prevent loss of DVD overlay plane bytes when the FPGA overlay engine backpressures the in-band metadata extractor for a DDR write.

#### Outcome:

The user approves and source `4821744` implements the RBF-only correction after physical schema 21 proves 4,238 of 86,400 known-pattern plane bytes disappear specifically between the extractor output and the overlay engine, causing one rejected commit, zero plane publications and zero alpha or magenta samples.  The extractor's overlay output is now a conventional retained valid, data, start and last slot that remains stable until an actual ready transfer, permits replacement in the same cycle only when the current byte is accepted, and leaves the upstream FIFO stopped whenever that slot cannot advance.  The strengthened extractor regression proves all record fields remain stable across alternating ready stalls.  A new integrated regression drives the complete config, 22 data records, 86,400 all-`0x55` plane bytes and commit through the extractor and engine under deterministic DDR writer stalls; it requires exactly 10,800 accepted writes, byte-exact first and last DDR words, one accepted and zero rejected commits, one plane publication and opaque-magenta video output.  The integrated test and retained extractor, engine, DDR-arbiter and schema-21 snapshot tests all pass under Icarus Verilog on build PC `10.10.0.42`, with warnings limited to inherited timescales.  Main, the helper, the B9 record format, DDR addressing, cache policy, palette, rectangle, blend function and schema-21 observability remain unchanged.

#### Next Steps:

Check out exact source `4821744` on build PC `10.10.0.42`, rerun all five focused overlay regressions from that clean source, perform one clean Quartus Prime 17.0.2 seed-20 build, require positive setup, hold, recovery, removal and minimum-pulse-width timing, and preserve a uniquely named replacement RBF while leaving the installed Main, helper and source-`d4ed809` rollback unchanged.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/test_dvd_overlay_metadata.sv
- tools/test_dvd_overlay_integrated.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 836 COMMIT Unreleased d4ed809 2026-08-31T16:15:48-07:00

#### Coming From:

Unreleased 43a1c22

#### Purpose:

Use the first physical schema-21 capture to localize the invisible known-pattern DVD highlight within the FPGA overlay pipeline.

#### Outcome:

The checksum-valid 883-byte schema-21 capture at SHA-256 `c146d2775a491c4ce8a652a9370a80fe718e0ff55109a546b40cc9d09b19c86b` proves that the extractor presents one config, 22 data records, one commit and two style records to the overlay engine, but only 82,162 of the required 86,400 plane bytes arrive.  The engine completes 10,270 DDR words and retains two further byte lanes instead of the required 10,800 complete words, sets its protocol-error flag, counts one rejected and zero accepted commits, leaves the display bank unchanged and publishes no plane.  It nevertheless publishes both styles with visible and menu flags, exact rectangle 135,397 through 208,436 and internal opaque-magenta entry one `ffff00ff`; the video domain receives three style or clear publications, saturates the row-tag counter, observes 5,989,983 row-matched samples and 51,800 samples inside the highlight rectangle, but sees exactly zero nonzero-alpha and zero opaque-magenta samples because the rejected commit leaves it reading the initial zero-valued plane bank.  Capture reason one fires after the intended 59,999,999 settle clocks.  The independently saved Main/helper log at SHA-256 `8ed4759ce04eee7794706239609a9fdfa134cdf5fe7c16211e534bbf77e02db0` still proves all 86,400 all-`0x55` bytes entered the FPGA ingress FIFO with FNV-1a `f8555d45`, zero order errors and `probe_complete=1`; the 1,920-by-1,080 screenshot at SHA-256 `b3606148234c83f7fe35d8b9f36d05fa3441b74a4ac3222db90720a629158d71` visibly confirms no magenta overlay.  Static inspection identifies the loss mechanism: `mpeg2_h262_inband_metadata` registers each overlay byte as a one-cycle pulse while gating its input with the overlay engine's current combinational ready signal, so on a cycle that the engine accepts the eighth byte and raises its registered DDR-write pending state, the extractor can already consume and schedule the following byte against the old ready value; that pulse is presented while the engine is not ready and has no retained-valid storage.  The fault is therefore the extractor-to-engine ready/valid boundary inside the FPGA, not Main, the ingress FIFO, DDR arbitration, row-cache publication or the final compositor.

#### Next Steps:

After user approval, replace the pulse-only overlay output with a conventional retained valid/data/start/last register whose valid bit clears only on an actual engine-ready transfer, derive extractor input readiness from the availability of that output slot, and add an integrated regression that drives the complete 86,400-byte plane through the extractor and engine while injecting DDR writer stalls.  Require exactly 86,400 engine plane bytes, 10,800 accepted DDR writes, one accepted and zero rejected commits, one plane publication, nonzero alpha and opaque-magenta video samples, then build a timing-clean RBF without changing Main, the helper, the record protocol or rendering semantics.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 835 COMMIT Unreleased d4ed809 2026-08-31T16:04:26-07:00

#### Coming From:

Unreleased b5e49db

#### Purpose:

Build and qualify the exact source-`d4ed809` DVD overlay pipeline diagnostic RBF for physical MiSTer testing.

#### Outcome:

The exact clean source checkout `d4ed809999e6efd6891b2522ede6aefbed24a75f` passes the focused all-`0x55` overlay-engine regression, retained metadata extractor and arbiter regressions, and both settled-commit and no-commit-fallback snapshot paths under Icarus Verilog on build PC `10.10.0.42`.  Quartus Prime 17.0.2 seed 20 completes synthesis, fitting, assembly and the project timing gate with zero errors; global setup, hold, recovery, removal and minimum-pulse-width slacks are respectively positive at 0.018, 0.244, 3.816, 0.593 and 0.925 nanoseconds, while the dedicated 60 MHz decoder and 54 MHz video checks have 0.871 and 1.932 nanoseconds of setup slack and no violations.  The schema-21 Gray-code source-to-first-synchronizer exception resolves without an ignored-filter warning.  The fit uses 34,791 ALMs, 54,483 registers, 4,187,011 block-memory bits in 535 RAM blocks and 70 DSP blocks.  The uniquely preserved `output_files/MediaPlayer_20260831_d4ed809.rbf` is 4,468,560 bytes with SHA-256 `6ea1615feec15a2c229ad10331bdfd48f955f76e48adaa69effe9c77e09ee45b`, identical on the build PC and in the local workspace.

#### Next Steps:

Preserve the installed `MiSTer_OverlayTrace` Main and `MediaPlayer_Helper_OverlayProbe` helper, upload only `MediaPlayer_20260831_d4ed809.rbf` as a new file rather than overwriting the current rollback, load that core, start the physical DVD, enter the root menu, move the selector several times, wait at least two seconds after the first menu commit, then collect a fresh `telemetry.txt`, screenshot and Main/helper log.  Require checksum-valid schema 21 with word 37 equal to `4f564c31`; its words 38 through 54 will localize the first stage that fails to advance, while visible opaque magenta would independently prove the final compositor path.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 834 COMMIT Unreleased d4ed809 2026-08-31T15:36:39-07:00

#### Coming From:

Unreleased 0e89c73

#### Purpose:

Localize the physically absent known-pattern DVD highlight inside the FPGA after its byte-exact ingress FIFO acceptance.

#### Outcome:

The user approves and source `d4ed809` implements the first RBF observability change after source `0e89c73` proves the complete all-index-one plane, opaque-magenta palette, visible menu configuration, commit and moving style records enter the FPGA FIFO with matching accepted-word count and rolling digest but produce no magenta screen pixels.  The helper, Main, in-band record protocol, overlay control, DDR addresses, cache behavior, compositor and fitter seed remain unchanged.  Passive saturating counters now report accepted config, data, commit, style and clear records, all engine record and plane bytes, accepted DDR writes, valid and rejected commits, line-cache fills, memory-domain plane and style publications, synchronized video-domain publication and row-tag arrivals, row-tag-matched samples, highlighted samples, nonzero-alpha samples and exact opaque-magenta samples.  Schema 21 maps this evidence into words 37 through 54, suppresses the unrelated first-error snapshot, captures one decoder-clock second after any commit reaches the engine, and falls back after thirty active seconds if no commit arrives.  Each video counter crosses back as separately valid registered Gray code through two explicit synchronizer stages, with only the source-to-first-stage path cut.  The focused exact all-`0x55` engine simulation writes and reads 86,400 bytes through 10,800 DDR words, publishes the probe plane and style, renders opaque magenta, clears back to base video and requires every schema-21 stage to advance; the retained extractor and arbiter tests pass, and the new trigger regression passes both settled-commit and no-commit fallback paths under Icarus Verilog with warnings limited to pre-existing inherited timescales.

#### Next Steps:

Check out exact source `d4ed809` on build PC `10.10.0.42`, rerun all four focused overlay regressions there, perform one clean Quartus Prime 17.0.2 seed-20 build, require positive setup, hold, recovery, removal and minimum-pulse-width timing plus resolved schema-21 CDC constraints, and provide a uniquely named diagnostic RBF while preserving the installed target files until the user replaces only the RBF.

#### Files Modified:

- MediaPlayer.sv
- MediaPlayer.sdc
- rtl/mpeg2_new/mpeg2_h262_dvd_overlay.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/test_dvd_overlay_engine.sv
- tools/test_dvd_overlay_snapshot.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 833 COMMIT Unreleased 0e89c73 2026-08-31T15:30:28-07:00

#### Coming From:

Unreleased 0e89c73

#### Purpose:

Determine whether the complete known-pattern DVD overlay stream reaches the FPGA ingress FIFO before the physically absent menu highlight.

#### Outcome:

The source-`0e89c73` physical-disc result proves one complete synthetic overlay frame crossed the helper, Main, SPI file-transfer path and FPGA ingress acceptance boundary without corruption or backpressure failure, while the rendered menu still contains no magenta selection pixels.  The 1,321,892-byte Main/helper log at SHA-256 `ec8523c89cd34d22821c6c5a2666158d6754a3c08d5375f8e1687c053299de18` records config flags `3`, rectangle `135,397` through `208,436`, opaque-magenta highlight entry one, 22 data records, exactly 86,400 data bytes, FNV-1a `f8555d45`, zero non-`0x55` bytes, zero order errors and `probe_complete=1`; its 26 successfully submitted style changes follow 26 root or directional menu commands through all four authored rectangles, and no `transport_fault` occurs.  Because `user_io_file_tx_data_step` verifies each batch against the FPGA FIFO's returned accepted-word counter and rolling digest before the verifier receives those bytes, this clears not only helper construction and Main forwarding but also physical acceptance into the FPGA ingress FIFO.  The 745,871-byte 1,920-by-1,080 screenshot at SHA-256 `7ee61103f6fae63fe62ced7716dea093fc00be3b5949dfcbd200ce297b023287` visibly shows the active menu and unobscured button area with no magenta rectangle.  The 792-byte schema-20 matrix text at SHA-256 `fc469765c947ca4910204205dd29347e1c05460e2c833ecdf299ccb3467f3436` passes all row framing and checksum `70fb7917`; word 19 again contains only audio-underrun flag `0x0400`, and its 209,628,414 decoder clocks or 3.494 seconds precede the first submitted overlay config at 12.847 seconds, so that sticky snapshot cannot report later overlay state.  A verifier-only oversized B9 candidate with length 65,503 appears at byte offset 28,625,926 about 23 seconds after the valid commit and cannot explain the initial failure; because the bounded Main verifier recognizes only B9 framing while the FPGA extractor also consumes B0, B1 and B6 payloads atomically, this later candidate is not evidence by itself that hardware saw an invalid overlay record.  The remaining defect is strictly downstream of the accepted FPGA FIFO write, in FIFO read or in-band extraction, overlay command handling and DDR publication/cache, or final video-domain style publication and blending.

#### Next Steps:

Do not modify the helper or Main again for this fault because the source-`0e89c73` evidence exhausts their observable transport boundary.  After explicit user approval, add an FPGA-observability-only schema that captures after a valid overlay commit or style change instead of freezing on the earlier audio underrun and positively counts extractor config, data, commit and style records, engine plane bytes and accepted DDR writes, initial and moving row-cache fills, style publications, row-tag matches and opaque blend samples; strengthen the focused simulation to require those counters across the known all-`0x55` magenta probe, then build one timing-clean diagnostic RBF while preserving the current helper, Main and rendering behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 832 COMMIT Unreleased 0e89c73 2026-08-31T14:59:02-07:00

#### Coming From:

Unreleased f515341

#### Purpose:

Prove whether Main submits each complete helper-generated DVD overlay record to successful FPGA ioctl transfers without changing the submitted stream or the RBF.

#### Outcome:

The user approves and source `0e89c73` implements the Main-only observability boundary after the known opaque helper probe produces two complete synthetic overlay frames and 152 moving style records but the physical menu displays no magenta pixels.  A second patch against pinned Main source `0a8fb44` adds a bounded streaming verifier after, and only after, each successful `user_io_file_tx_data_step` consumption so it observes the exact byte sequence Main reports as submitted while leaving its contents, chunking, credit protocol, pacing and control behavior unchanged.  The verifier recognizes overlay markers and declared lengths across arbitrary pipe and ioctl boundaries, retains only bounded configuration and style state, validates frame command order, counts data records and bytes, calculates FNV-1a over the submitted plane, counts non-`0x55` probe bytes, suppresses repeated identical style logs, and reports changed selections plus every commit and session summary.  A focused build of the exact patched header with C++11 strict warnings passes when every byte is fed separately and again in 37-byte chunks, recognizing the complete 22-record, 86,400-byte probe at FNV-1a `f8555d45`, rejecting a one-byte corruption, zero and oversized lengths, data and commit before config, an interrupted frame, an unknown command and a repeated style.  Both Main patches apply cleanly in order and the complete exact-source ARM Main build succeeds with MiSTer's GNU 10.2 toolchain.  `/home/vash/MiSTer-Media-Player-0e89c73/host/build/MiSTer_OverlayTrace` is a 1,178,588-byte stripped dynamically linked ARMv7 EABI5 hard-float executable at SHA-256 `872050d44266d74c28e302a54336f409426fbca235ce3384c3b1735eb1aa6356` and contains the required commit and summary markers.  The helper, kernel, ioctl implementation, FPGA source, QSF and seed-20 RBF remain untouched.

#### Next Steps:

Replace only `/media/fat/MiSTer` with `/home/vash/MiSTer-Media-Player-0e89c73/host/build/MiSTer_OverlayTrace` from the build PC, preserving the currently installed diagnostic helper and seed-20 RBF, verify the 1,178,588-byte destination and SHA-256 `872050d44266d74c28e302a54336f409426fbca235ce3384c3b1735eb1aa6356`, restore executable permission if needed, and perform a normal MiSTer reboot because Main changes.  Restart the physical DVD, enter the root menu, move through several buttons and capture the fresh `/tmp/MediaPlayer_ARM.log` plus screenshot.  A decisive successful submission has `overlay_submit config` with `probe_payload=1`, `overlay_submit commit` with 22 data records, 86,400 data bytes, FNV-1a `f8555d45`, zero non-`0x55` bytes, zero order errors and `probe_complete=1`, followed by moving style rectangles; if those exact lines coexist with no magenta rectangle, userspace Main is cleared and the remaining boundary is kernel-to-FPGA delivery or live FPGA processing.

#### Files Modified:

- host/build_arm_stack.sh
- host/main_mister/0002-mediaplayer-overlay-trace.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 831 COMMIT Unreleased f515341 2026-08-31T14:51:34-07:00

#### Coming From:

Unreleased f515341

#### Purpose:

Determine whether a known opaque DVD overlay plane generated by the helper appears on the physical menu without changing Main or the RBF.

#### Outcome:

The user's source-`f515341` physical-disc capture shows no moving magenta selection rectangle anywhere on the menu, including after 30 successful right or left navigation commands traverse all four authored buttons and finish on `SET UP`.  The 2,234,774-byte helper and Main log at SHA-256 `6d15b61ee5c0390739d08189b33d0c3e3f16aac7293f78fc18b0979abcd0cf7f` proves the uniquely marked probe ran: both real-plane dumps contain exactly 480 distinct 180-byte rows and 86,400 bytes, independently reproduce FNV-1a `c23cad52`, and are followed by two completed overlay-frame emissions, two config records and 152 style records.  Every synthetic record reports visible and menu flags set, transparent normal colors, opaque magenta highlight index one, an all-index-one selected histogram and the correct moving rectangles containing 2,960, 3,640, 5,760 or 6,528 drawable pixels; no helper write or protocol failure is logged.  The matching 1,920-by-1,080 screenshot at SHA-256 `d9149dc8d47ac36795180e5756a7e61d157deb83a58a74df833465a7a53e734e` visibly contains the menu and cadence matrix but no magenta pixels at the unobscured final `SET UP` rectangle.  The 792-byte schema-20 matrix text at SHA-256 `fc48a1f9753d0eede8ac8b9d68deac32e922a908097863a62e7fac38b65289de` passes every prefix, row index, parity bit and checksum `7172fa5b`; word 19 contains only error flag `0x0400`, the audio FIFO underrun, and its 208,201,221 session cycles or 3.470 seconds precede the first overlay emission about 5.62 seconds after the root-menu stream hop, so the sticky snapshot cannot report the later overlay transport or engine state.  This hardware failure rules out the real subpicture plane, palette, selection state and helper record construction but cannot distinguish Main's userspace forwarding from the kernel ioctl, live in-band extraction, DDR publication or final blend.

#### Next Steps:

Leave the diagnostic helper, Main and seed-20 RBF unchanged until the user approves a Main-only observability boundary.  Add a bounded streaming parser immediately after each successful Main ioctl submission that recognizes complete overlay records across transfer boundaries, validates command order and declared lengths, counts exactly 86,400 data bytes, hashes the transmitted synthetic plane against FNV-1a `f8555d45`, and records config, commit and moving-style payloads without changing any submitted byte.  Build and install only a uniquely named Main diagnostic; if it proves the complete records reached every successful ioctl call while the rectangle remains absent, the remaining boundary is kernel-to-FPGA delivery or live FPGA processing and an RBF observability build becomes necessary, while any missing or malformed record remains fixable entirely on the host side.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 830 COMMIT Unreleased f515341 2026-08-31T11:13:16-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Distinguish a real DVD subpicture-plane defect from a downstream transport or rendering failure without modifying Main or the RBF.

#### Outcome:

The user approves and source `f515341` implements the helper-only known-pattern probe after source `673b6d7` proves the real menu state contains 267 through 279 drawable pixels but the unchanged hardware displays none, while exact installed-RTL simulation renders a complete bottom-menu rectangle correctly under an idle DDR model.  Ordinary builds remain behavior-identical, and compile-time definition `MMP_DVD_OVERLAY_PROBE` alone enables a separately named artifact that logs all 480 rows of each real 86,400-byte two-bit plane with its FNV-1a hash, retains the authored visible and menu flags plus moving selection rectangle, and transmits an all-index-one plane with a transparent normal palette and opaque magenta highlight index one.  Strict default and probe compilation, capability smoke tests, focused subpicture, random-access and menu-hop regressions, and a byte-level probe framing test all pass locally.  On the exact detached build-PC checkout, the authored-menu harness passes root, all four directions, activation, visible-highlight and control-acknowledgment coverage; it observes 17 complete overlay commits, 1,303 visible highlight events and the expected 6,528-pixel solid selected rectangle.  The normal and probe ARM outputs both build with MiSTer's GNU 10.2 toolchain; the uniquely named probe is a 908,660-byte stripped static ARMv7 hard-float executable with no dynamic section at SHA-256 `2b7de20983d9b9f2b2fe561d5ca78e33b94d3f099f6bdd0a88b31c3980118ef5`.  No decoder, scheduler, navigation, record framing, Main, RTL, QSF, RBF or installed target file is changed by the implementation itself.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, then replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-f515341/host/build/MediaPlayer_Helper_OverlayProbe` from the build PC, restore executable permission if needed, and verify the destination is 908,660 bytes with SHA-256 `2b7de20983d9b9f2b2fe561d5ca78e33b94d3f099f6bdd0a88b31c3980118ef5`.  Preserve Main and the installed seed-20 RBF.  Restart the physical DVD, reach its menu, move the selected item several times and capture a fresh helper log plus screenshot; the log must contain `probe=solid-index1-magenta` and the bounded real-plane dump.  A solid magenta rectangle following the selection localizes the defect to the real plane or its delivery pattern, while another completely absent rectangle moves the next non-RBF investigation to Main's helper-to-ioctl forwarding.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 829 COMMIT Unreleased 673b6d7 2026-08-31T11:01:48-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Exhaust non-RBF methods for isolating the missing authored-menu selection after the helper proves it emits drawable pixels.

#### Outcome:

Read-only history comparison proves the installed seed-20 source-`a9899e0` overlay RTL, in-band extractor, DDR arbiter and top-level wiring are byte-identical to source `673b6d7`, so current-source simulation is representative of the installed logic.  On the build PC, all three existing exact-source simulations pass for bounded in-band extraction and backpressure, DDR arbitration and response ownership, and plane write/read plus normal and highlight blending.  The existing engine bench holds horizontal and vertical position at zero, so a temporary untracked bench additionally drives two complete 858-by-525 timing rasters, uses the physical button-four rectangle from `439,389` through `574,436`, refills every two-line cache entry through the DDR model and measures the second frame; it renders all 6,528 expected opaque highlight pixels with zero wrong pixels and no protocol error.  This rules out a deterministic coordinate, two-bit packing, palette selection, bottom-raster row-cache or blend defect under an idle DDR model, but it does not reproduce live decoder contention or prove that the hardware receives the helper's records.  No repository source, installed helper, Main, RBF or target file is changed, and the temporary simulation does not generate a bitstream.

#### Next Steps:

Prefer one helper-only discriminator before modifying the RBF: build a reversible diagnostic helper that preserves the existing transport framing while dumping each distinct real menu plane for exact software replay and substituting a known all-index-one plane with transparent normal color and an unmistakable opaque highlight color, producing a solid rectangle only inside the authored selection coordinates.  If the rectangle appears, the failure is in the real plane data or its hardware delivery pattern; if it remains absent, capture or instrument Main's helper-to-ioctl byte forwarding next, and only after both software endpoints prove the exact records should FPGA-internal counters or another RBF be required.  Preserve the current Main and seed-20 RBF throughout this helper-only test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 828 COMMIT Unreleased 673b6d7 2026-08-31T10:48:20-07:00

#### Coming From:

Unreleased 673b6d7

#### Purpose:

Determine whether the source-`673b6d7` helper emits drawable DVD selection pixels during the physical menu failure.

#### Outcome:

The user's exact source-`673b6d7` physical-disc run reaches the four-button menu, accepts eight successful navigation commands including the root hop and seven right or left moves, and displays no selection pixels by direct observation or in the matching 768,280-byte screenshot at SHA-256 `15d6f1a64c8d9623f354574d70bdd953d727f0d63d683a02b76ea4d69c2a2e6b`.  The 1,169,066-byte helper log at SHA-256 `debde6d17b1f20fdccf11d820511ba5928d13c21f1449c1136b1230348a20be8` contains one complete overlay configuration and 54 style records, all with `visible=1` and `menu=1`; the selected rectangle moves consistently from button one through four and back, and its exact plane histograms contain respectively 279, 278, 272 and 267 pixels whose mapped highlight alpha is nonzero.  All four emitted highlight entries are stable at transparent `00000000` followed by `316a5988`, `316a59bb` and `316a59ee`, so the helper has a valid nontransparent plane, palette, rectangle and selection state and the failure is downstream of DVD parsing and helper overlay generation.  The matching 792-byte schema-20 matrix text at SHA-256 `7911a2299b1cb84ad748177fbf03cccdba2d683044551fc369da261b20bb1924` passes all 64 prefixes, indices, parity bits and checksum `7023d571`, but its sticky snapshot froze at STC second three on only error `0x0400`, one audio FIFO underrun, before the first menu overlay configuration; its zero overlay extractor and engine error bits therefore cannot prove whether the later records were extracted, written, cached or blended.  No repository source, Main, helper, RBF or target file is changed while collecting or analyzing this evidence.

#### Next Steps:

Keep the accepted helper, Main and seed-20 RBF installed until the next boundary is approved.  The smallest decisive follow-up is an FPGA-observability-only schema update that captures after a menu style event rather than the earlier sticky audio underrun and positively counts overlay records, plane bytes and commits, DDR writes, row-cache fills, style publications, row-tag matches and nonzero-alpha blend samples; strengthen the overlay engine bench with a moving native raster and selection rectangle, then build only a timing-clean RBF.  These counters will distinguish missing in-band extraction, plane storage or cache delivery from final video blending without changing DVD selection, helper transport or overlay rendering behavior.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 827 COMMIT Unreleased 673b6d7 2026-08-31T10:20:37-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Prove the exact DVD highlight style and selected-region plane indices emitted by the helper before considering any FPGA or RBF change.

#### Outcome:

The user approved and source `673b6d7` implements the helper-only observability boundary after the physical menu regressed from sparse distorted selection pixels to no visible indicator.  Independent absolute-path FTP readback first proved the installed artifacts were exactly the intended 904,564-byte source-`3e4f54c` helper at SHA-256 `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, the 1,174,492-byte source-`53ccc04` Main at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, and the unchanged 4,511,756-byte seed-20 RBF at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  Every successfully emitted overlay configuration or style record now reports its visible and menu flags, inclusive highlight rectangle, four decoded RGBA entries, exact two-bit plane-index histogram inside the selected rectangle, total selected pixels and the subset whose mapped highlight alpha is nonzero; the transport bytes, decoder, scheduler, menu selection and overlay behavior are unchanged.  The strict focused subpicture test proves the exact `0,2,2,0` histogram plus invalid-bound and persistence cases, and the existing random-access and menu-hop regressions pass.  The complete native helper compiles and its capability smoke test passes after demoting only the pinned DVD headers' pre-existing ignored-`gcc_struct` attribute warning on the local AArch64 GCC 15 host; no authorized non-archived DVD image is locally available for the real-menu harness.  An exact detached build-PC checkout of `673b6d7819a666b3b3387be3b594085ff6776b12` builds only `/home/vash/MiSTer-Media-Player-673b6d7/host/build/MediaPlayer_Helper`, a 908,660-byte stripped static ARMv7 hard-float executable with no dynamic section at SHA-256 `e0960b0fb2dcd95cb7c759803ba5e3c6a873a8feb57c5e9ab2c1e23e8af36050`; Main, RTL, QSF, RBF and Quartus remain untouched.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-673b6d7/host/build/MediaPlayer_Helper` from the build PC, restore executable permission if needed, and verify the destination SHA-256 is `e0960b0fb2dcd95cb7c759803ba5e3c6a873a8feb57c5e9ab2c1e23e8af36050`.  Restart the physical DVD, reach the menu, move the selected item at least once and capture a fresh helper log containing the new `DVD overlay record=` lines; the emitted style is capable of drawing a marker only when it reports `visible=1`, at least one nonzero-alpha RGBA entry maps to a populated histogram bin, and `selected_nontransparent_pixels` is nonzero.  Preserve Main and the seed-20 RBF because this result will decide whether the missing indicator originates before or after FPGA overlay composition.

#### Files Modified:

- host/arm/dvd_spu.c
- host/arm/dvd_spu.h
- host/arm/media_player_helper.c
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 826 COMMIT Unreleased 3e4f54c 2026-08-31T10:11:41-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Qualify the source-`3e4f54c` physical-disc root-menu recovery and selected-button visibility from the user's fresh helper log, screenshot and telemetry.

#### Outcome:

The fresh physical Coming to America run reaches and continuously renders the root menu after the root navigation hop, and its helper log uniquely exercises the candidate random-access path by retaining sequence, intra and following-reference offsets 0, 296 and 7,892 with no discarded context pictures.  The 10,602,943-byte log `.ai/current_results/MediaPlayer_ARM.log`, SHA-256 `c6d87b215ad361f91d75b072313e6c04db712ca538be42ac7320a0e7c217322a`, records nine complete subpicture overlay updates and 50 successful directional transitions with valid authored highlight data; its final selection is button 3 at rectangle 311,389 through 430,436 with nontransparent palette `000ffb80`, and the helper remains active beyond 427 seconds without a malformed subpicture, helper fatal or process exit.  The matching 696,371-byte screenshot, SHA-256 `5f86fae990c98f7a6d7c469784e9663c648a15413bdcf26291781f3bd37f863f`, shows the clean menu background but no selected-button indicator in that unobscured button-3 rectangle.  The checksum-valid schema-20 telemetry at SHA-256 `d0b7c79989b398cf5e59aab0d54e2801b820be41232c47a282e64639d7aec88c` is a sticky STC-second-4 snapshot caused by one isolated `0x0400` audio underrun before menu entry, so its clear overlay error bits cannot qualify later menu activity.  This run accepts the candidate's root-menu random-access recovery but rejects visible selected-button output; the log clears libdvdnav selection, button geometry and palette acquisition while leaving the emitted physical overlay plane/style record versus FPGA compositor boundary unresolved, and no source, Main, RBF or target configuration changes during collection.

#### Next Steps:

Keep the running menu, helper, Main and frozen seed-20 RBF unchanged until the installed helper, Main and RBF hashes are independently read back.  After user approval, make a helper-only observability change that logs each emitted overlay configuration or style record together with visibility, menu flag, rectangle, decoded highlight RGBA values and selected-region plane-index histogram, then require the physical disc to prove nonzero selected pixels and a nontransparent emitted style before considering any RTL or RBF change; preserve the current root-hop filter and ignore the separately identified one-second no-progress false trigger for this boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 825 COMMIT Unreleased 3e4f54c 2026-08-31T09:12:37-07:00

#### Coming From:

Unreleased 3e4f54c

#### Purpose:

Determine whether the repeated physical-disc root-menu black screen qualifies the source-`3e4f54c` random-access correction.

#### Outcome:

The repeated test does not exercise source `3e4f54c`.  Absolute-path FTP readback shows that `/media/fat/linux/MediaPlayer_Helper` remains the 904,564-byte source-`53ccc04` helper at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, rather than the newly built 904,564-byte source-`3e4f54c` helper at `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`; the installed 1,174,492-byte Main remains the intended source-`53ccc04` executable at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`.  The 7,126,742-byte matching helper log `/tmp/entry825_root_menu_black_arm_helper.log`, SHA-256 `c5914545ef52c3eda200d93215c682cb0f40adf2d0cc905d52e399eb111be895`, independently identifies the old code by printing `DVD random access discarded 0 leading B picture(s)` at startup and after the successful zero-tail root hop instead of the candidate's sequence, intra and following-reference offsets.  The 4,809-byte grayscale capture `/tmp/entry825_root_menu_black.png`, SHA-256 `1c64413772575d21111b51ba9e8f14363179d012e6d97188422f161bb86caa02`, contains all 64 schema-20 prefixes, row indices and parity bits with matching checksum `9e4824d8`; it records 24,625 accepted bytes, 12,305,210 decoder clocks, zero completed or displayed pictures and exactly error `0x0200`, the B-picture presentation failure, on a B-picture header at temporal reference 12.  This black-screen result is valid evidence for the still-installed predecessor but neither accepts nor rejects the source-`3e4f54c` helper, and no source, Main, RBF or target configuration is changed during collection.

#### Next Steps:

Exit the MediaPlayer core or otherwise stop its running helper, obtain only `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper` from the build PC, verify its local SHA-256 is `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, and replace `/media/fat/linux/MediaPlayer_Helper`; if FileZilla refuses overwrite, delete that exact destination after the core has exited and upload the candidate under the exact same name.  Restore executable permission if needed, then require an independent destination readback matching the candidate hash before repeating the physical-disc `M` test; do not replace Main or the frozen seed-20 RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 824 COMMIT Unreleased 3e4f54c 2026-08-31T09:00:09-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Require complete MPEG-2 sequence and reference-picture context before releasing video after a DVD random-access hop.

#### Outcome:

Source `3e4f54c` moves the helper's initial DVD random-access logic into a focused filter that withholds each initial or reset-causing stream until it has a complete sequence header, an I reference and the following I/P reference, neutralizes every start code in contextless pictures before that sequence plus pre-I and open-GOP leading-B pictures while preserving byte positions and timestamp records, and logs the retained offsets and discarded-picture counts.  The deterministic regression proves a prior contextless P picture, a post-sequence pre-I P picture and a leading B picture are hidden while the qualifying sequence/I/P group is retained, and rejects an incomplete group without a following reference.  The exact native helper builds with `-Werror`; the focused random-access, subpicture and menu-hop tests pass; and the strengthened Coming to America authored-directory harness completes root navigation, all four directional commands and menu continuation while requiring and observing a post-root restart group at sequence, I and following-reference offsets 0, 296 and 7,892, with 17 overlay commits, 1,468,899 plane bytes, 1,335 visible highlighted states and a 4,637-pixel selected region.  Exact detached source `3e4f54c902dbb27a89c3d32eb25df2954bf43a88` produces a 904,564-byte stripped static ARMv7 EABI5 helper at `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper`, SHA-256 `c4c47141205c99ade8a9ed266574beb9d072dce827d508efbff47694bb2ce197`, with no dynamic section; Main, RTL, QSF, the frozen seed-20 RBF and Quartus are unchanged.

#### Next Steps:

Stop the running MediaPlayer helper or exit the core, manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-3e4f54c/host/build/MediaPlayer_Helper`, restore executable mode if the transfer client clears it, and verify the exact size and SHA-256 before restarting.  Preserve the installed source-`53ccc04` Main and frozen seed-20 RBF, load the physical Coming to America disc, press `M` during first-play and require the root menu to replace the black screen without a decoder diagnostic; if it appears, leave the menu visible for a capture before separately returning to entry 822's fragmented `SET UP` highlight defect.

#### Files Modified:

- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/dvd_random_access.c
- host/arm/dvd_random_access.h
- host/arm/media_player_helper.c
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_random_access.c

#### Status:

- [x] Built
- [ ] Passed

---

## 823 COMMIT Unreleased 53ccc04 2026-08-31T08:34:42-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Capture and isolate the exact-source black-screen failure produced by a physical-disc root-menu command after correcting the Main deployment.

#### Outcome:

Absolute-path readback verifies the intended artifact combination before interpretation: the installed 904,564-byte helper is exact source `53ccc04` at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, the 1,174,492-byte Main is exact source `53ccc04` at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, and the unchanged 4,511,756-byte seed-20 RBF remains `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  The user presses keyboard `M` during physical-disc playback and receives a black diagnostic raster instead of the root menu.  The 31,878-byte 1920-by-1080 scaled capture `/tmp/entry823_root_menu_black.png`, SHA-256 `90df9d893e1875eab6a97663de564c254d7c4ea810b176ec0397bf1fb12e35fc`, decodes with all 64 schema-20 headers, row indices and parity bits valid and checksum `1ffb896e` matching.  Its fatal snapshot accepts only 16,467 video bytes and runs 19,694 decoder clocks without a first presentation before latching exactly error `0x0002`, the phase-one probe error; the retained current header is a P picture while frame-rate code and completed-picture count remain zero, and every syntax, prediction, inverse-quantization, IDCT, reconstruction, writer, cache, presentation, audio and DVD-overlay error bit is clear.  The matching 1,578,363-byte helper log at SHA-256 `4e50195d8d16a41138d9e679e4a22518fd1dab109afc9af5991fd207dce4f08b` proves that root navigation succeeds, discards zero partial-block bytes, is classified as a stream hop, completes the new Main/helper ready barrier with 59,752 pending Main bytes discarded, rearms the random-access filter with zero leading B pictures, publishes six subpicture overlays and continues transferring hundreds of megabytes without a helper fatal.  This rejects source `53ccc04` on the physical root-menu gate and localizes the black screen to the reset FPGA session beginning without sufficient independent sequence and reference-picture context rather than to deployment, Main/helper deadlock or an overlay fault; entry 822's fragmented selected-button result remains a separate open defect.

#### Next Steps:

Keep the exact source-`53ccc04` Main, helper and frozen seed-20 RBF unchanged and do not use this failed session for further menu commands.  After user approval, make a bounded helper-only random-access correction that withholds every reset-causing DVD stream hop until complete independently decodable sequence context and an intra reference are present, add a real authored-disc regression reproducing the root call from the observed mid-first-play position and require its first outgoing video to decode cleanly, then rebuild only the helper and repeat `M`; do not change Main, RTL, QSF, the RBF or the separately open overlay-highlight path in that boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 822 COMMIT Unreleased 53ccc04 2026-08-31T08:18:13-07:00

#### Coming From:

Unreleased 53ccc04

#### Purpose:

Capture the first physical-disc selected-button result from the source-`53ccc04` helper and identify the exact installed artifact combination that produced it.

#### Outcome:

The user enters the Coming to America root menu with keyboard `M`, moves the selection to `SET UP` and reports that the barely visible indicator appears distorted.  The 795,417-byte 1920-by-1080 scaled capture `/tmp/entry822_setup_selected_distorted.png`, SHA-256 `3da0f2580528471e099035487beba1a2d0258d5cca4584b26633f055539dbc20`, preserves the menu background and shows a cyan-green selection rendered as sparse horizontal fragments across `SET UP`; the large black-and-white lower-left cadence telemetry block is the previously identified diagnostic overlay rather than the selected-button bitmap.  Its matching 2,679,653-byte helper log at SHA-256 `aad53eecef30d4b3e78ed114a5b15c05469e3073813f5506ab50d9f6f46b5df8` records a successful authored Right transition from button 1 to button 2 with exact rectangle 212,397 through 302,436 and selection palette `000feb80`, two menu commands, two subpicture overlay updates and no fatal or helper exit.  Absolute-path readback identifies a mixed deployment: the 904,564-byte installed helper is the exact source-`53ccc04` candidate at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f`, and the 4,511,756-byte RBF remains the expected frozen seed-20 image at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`, but the 1,174,492-byte installed Main is the older source-`a9899e0` binary at `a276aadcdc5aad4034bc40ee2dff52596fd44876156e24f16289d5a339411636` rather than source `53ccc04` Main at `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`.  The valid button transition and correctly bounded but visibly fragmented highlight reject the visible-indicator hardware gate for this helper-and-RBF combination, while the mixed Main means menu-continuation activation and background preservation are not tested.

#### Next Steps:

Do not use this mixed installation to test submenu activation because the older Main retains the unconditional reset that can black the resident menu frame.  After user approval, replace only `/media/fat/MiSTer` with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MiSTer`, require SHA-256 `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496`, reboot and verify the running artifact combination before repeating the `SET UP` selection capture; if the same bounded horizontal fragmentation remains, keep Main and the helper frozen and isolate the overlay plane packing, line-cache addressing and authored SPU field layout before considering any FPGA change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 821 COMMIT Unreleased 53ccc04 2026-08-31T07:45:34-07:00

#### Coming From:

Unreleased e99cb28

#### Purpose:

Make authored DVD-menu highlights visible and preserve the resident video frame across overlay-only menu transitions without changing the FPGA build.

#### Outcome:

Source `53ccc04` makes displayed libdvdnav button state authoritative over a later scheduled subpicture stop, classifies successful activation as either a menu continuation or stream hop, adds control event `0x84` for the continuation, and makes Main defer its download reset until that decision arrives.  Menu continuations discard only stale helper block and still state while preserving the FPGA's resident video frame; title exits and root calls retain the ready, discard, reset and go barrier.  The focused scheduled-stop/highlight and stream-hop/menu-continuation tests pass, and the exact native helper builds with `-Werror`.  The corrected Coming to America authored-directory harness completes in 1.67 seconds with all six commands, three real directional transitions, one root ready barrier, one activation continuation acknowledgment, 17 overlay commits, 1,468,899 plane bytes, 1,311 visible highlighted states and 4,637 nonzero pixels in the largest selected rectangle.  Exact source `53ccc04` builds a 904,564-byte static stripped ARMv7 helper at SHA-256 `29665e7dbe7790872988d0f0d05e26487f95550128f6719f148fab2d1114c09f` and a 1,174,492-byte patched Main at SHA-256 `4015bb2a068bcc1644b7eb6ee99e29850666057576c3e7adb6750587dc03b496` under `/home/vash/MiSTer-Media-Player-53ccc04/host/build`; RTL, QSF, RBF and Quartus are unchanged.

#### Next Steps:

The user should manually replace `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MediaPlayer_Helper` and the MiSTer root `MiSTer` executable with `/home/vash/MiSTer-Media-Player-53ccc04/host/build/MiSTer`, preserve the installed RBF, verify the recorded SHA-256 values and executable modes, then restart MediaPlayer.  Press `M`, verify that a visible highlight moves among all authored buttons, activate Scene Selection and confirm its submenu retains the background instead of going black, then activate a title and confirm its stream-hop barrier starts playback cleanly; leave the resulting screen and helper log available if any failure occurs.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/dvd_spu.c
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 820 COMMIT Unreleased e99cb28 2026-08-31T07:37:10-07:00

#### Coming From:

Unreleased e99cb28

#### Purpose:

Capture the source-`e99cb28` physical-menu result and isolate invisible selection and black submenu activation from DVD navigation itself.

#### Outcome:

Absolute-path readback verifies that the installed 904,564-byte helper is the exact source-`e99cb28` candidate at SHA-256 `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`, and its unique command diagnostics prove the running helper receives every keyboard arrow.  Across two runs the physical disc reports four authored buttons and repeatedly performs real transitions among buttons 1 through 4 with valid changing rectangles and selection palette `000feb80`; the final activation occurs on button 4 at rectangle 439,389 through 574,436, then completes a zero-tail ready barrier, emits a new subpicture and enters an indefinite still without a decoder fatal.  The 890,796-byte menu capture `/tmp/entry820_menu_no_highlight.png`, SHA-256 `d50b24341f0e0bd222608ba28c5e3261498b485e4a061e10c4fea6d235adc09b`, visibly identifies button 4 as Scene Selection while showing no selected-button highlight; its matching 2,840,191-byte log has SHA-256 `232052663a079b1a20db76d4b76416f940222f1c0417b324fa2bf2143c3e20de`.  Native read-only analysis of the same Coming to America authored fixture proves the helper's decoded plane contains nonzero pixels inside every changing button rectangle, but the root-menu configuration is published with menu set and visible clear because the subpicture decoder applies a later scheduled stop command immediately; the highlight pixels therefore cannot be composited.  The 31,888-byte post-activation capture `/tmp/entry820_same_menu_result.png`, SHA-256 `a36561c61b8a985cf20d67457a5ddf07bc65a925ea629ecea512ac324c89c84f`, and matching 3,259,439-byte log at SHA-256 `f713f582018d492013318f394f13f4159a61bc68b6632348b8a8fd343c21ce25` show the separate black submenu result.  Main currently deasserts download and resets the decoder before every activation command, so button 4's overlay-only Scene Selection transition loses the menu background frame that the authored indefinite still expects to retain.  Static RTL inspection confirms the white and black lower-left block is the existing always-on cadence telemetry overlay after a snapshot, not a DVD overlay corruption or post-Enter fatal.  Source `e99cb28` is rejected on hardware for visible menu interaction; no source, target file, Main, RBF or configuration is changed during collection.

#### Next Steps:

Keep RTL, QSF, RBF and Quartus frozen.  After user approval, make a bounded helper-and-Main change: a displayed libdvdnav highlight must force the decoded menu overlay visible despite a later unscheduled stop command, and activation must be classified before Main resets download so menu-to-menu overlay-only transitions preserve the resident video frame while title exits retain the existing clean decoder barrier.  Add native regressions that require visible root-menu style, nonzero highlighted pixels and distinct menu-continue versus stream-hop acknowledgments, then rebuild only the helper and patched Main for physical testing; removing or hiding the cadence telemetry block remains a deferred RBF concern.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 819 COMMIT Unreleased e99cb28 2026-08-31T07:01:17-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Synchronize DVD menu commands and selected-button highlighting to the displayed NAV packet while making directional transitions directly testable.

#### Outcome:

Source `e99cb28` retains a decoded copy of each delivered DVD NAV PCI, invalidates it across rewinds, chapter changes and successful menu hops, and uses that stable packet for directional selection, activation and highlight lookup instead of libdvdnav's potentially ahead current PCI.  Ordinary selected buttons now use the selection palette rather than the activation palette, and every root, direction and activation command logs the packet logical-block number, button count, before, authored target and after button numbers, status, highlight rectangle and palette.  The strict native helper builds with `-Werror`; the focused stale-tail test additionally proves retained-PCI invalidation, selection-palette choice, rectangle recovery and authored-target lookup; and the retained fragmented subpicture, palette, alpha, highlight and rejection test passes.  The strengthened Blazing Saddles authored-DVD harness records all six commands and real transitions Right 1-to-2 and Left 1-to-4 while preserving two ready barriers, both clean zero-tail hops and the overlay stream.  The closer Coming to America authored fixture also passes with Down 1-to-2, Left 2-to-1 and Up 1-to-4, twenty overlay configurations, 443 data records carrying 1,728,196 bytes and 1,574 style updates.  Exact detached source `e99cb28` reproducibly builds a 904,564-byte static stripped ARMv7 EABI5 helper at `/home/vash/MiSTer-Media-Player-e99cb28/host/build/MediaPlayer_Helper`, SHA-256 `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`; Main, RTL, QSF, RBF and Quartus are unchanged.

#### Next Steps:

The user should manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-e99cb28/host/build/MediaPlayer_Helper`, verify the destination SHA-256 is `330502577a28200ad97ead837408e34dbaf04018fe510a0006ecdb7e0f3bb7df`, restart MediaPlayer and press `M` during first-play.  At the root menu, exercise all four arrows before Enter and leave the resulting screen visible; hardware acceptance requires visible selection movement wherever the logged authored target differs, command logs whose before and after values match that movement, clean root and activation hops, and no black dead end, diagnostic raster or decoder error.

#### Files Modified:

- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 818 COMMIT Unreleased 0e70319 2026-08-31T06:54:47-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Capture the exact source-`0e70319` physical-disc result after root-menu entry, directional input and Enter activation.

#### Outcome:

The user reports that keyboard `M` reaches the physical disc's menu, the arrow keys still cause no visible change, and Enter leaves a black screen.  The 30,212-byte matching capture `/tmp/entry818_menu_enter_black.png` has SHA-256 `7a50ed345aa27e73fef99d4a64f3704ef2752923cd58c82b553913631be70f82`, and the 11,543,671-byte helper log `/tmp/entry818_menu_enter_black_arm_helper.log` has SHA-256 `6d08df11102a2d437e062284d779af76a2fdb727ff1b877f2faefdcc8e9151b3`.  The capture is a black native active frame rather than an 800-by-600 telemetry raster, while the active source-`0e70319` helper records both root and activation hops with `discarded_block_tail=0`, completes both Main/helper ready barriers and remains alive without any fatal, decoder error or `0x0200` B-presentation failure.  The final activation does not produce a menu-leave transition; instead libdvdnav emits another overlay update and enters an indefinite authored still, so the stale-tail crash gate passes but full menu interaction does not.  Existing logs do not identify individual directional commands, selected button numbers or highlight rectangles, and the native harness only counted generic style events, so it cannot establish whether the helper used the NAV PCI synchronized to the displayed menu or merely returned a visually unchanged selection.

#### Next Steps:

Keep Main, RTL, QSF, RBF and Quartus frozen.  The next bounded helper-only cycle should log every direction and activation with the before and after button numbers, NAV logical-block number, authored neighbor and highlight rectangle, strengthen the native harness to require a real selection transition, and retain the NAV PCI associated with the displayed packet for button selection and activation instead of relying on libdvdnav's potentially ahead current PCI; rebuild and retest this same physical menu before expanding menu support.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 817 COMMIT Unreleased 0e70319 2026-08-31T06:43:56-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Verify that the user's manual helper replacement installed and launched the exact source-`0e70319` candidate before renewed menu testing.

#### Outcome:

Absolute-path FTP readback now reproduces `/media/fat/linux/MediaPlayer_Helper` as the expected 904,564-byte static ARMv7 executable at SHA-256 `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`, exactly matching `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` on the build PC rather than entry 816's identically sized old helper at `a00173f6`.  Read-only SSH inspection reports remote mode `755` and one active helper process, PID 767; hashing `/proc/767/exe` independently returns the same full `c8a39413` digest, proving the running process was launched from the replacement rather than retaining the deleted predecessor inode.  This verifies deployment only and makes no repository source, Main, RBF, playback option or target-file change by the agent; menu hardware acceptance remains pending.

#### Next Steps:

With the exact source-`0e70319` helper now active, press keyboard `M` during first-play, test Up, Down, Left and Right at the root menu before pressing Space, and leave any resulting screen visible.  Require `discarded_block_tail` logs for successful root and activation hops, visible highlight movement wherever the authored menu links adjacent buttons, successful activation without the `0x0200` B-presentation raster, and continued native 480i; capture the matching screen and helper log before accepting the candidate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 816 COMMIT Unreleased 0e70319 2026-08-31T06:23:51-07:00

#### Coming From:

Unreleased 0e70319

#### Purpose:

Capture the first reported menu-direction and activation result and verify whether the source-`0e70319` helper actually produced it.

#### Outcome:

The user reports that keyboard `M` now reaches the physical disc's root menu, none of the keyboard arrow keys causes a visible change there, and Space activation produces the diagnostic screen left visible for collection.  Main records root command `0x09` at 100.597697 seconds and activation command `0x08` at 129.365372 seconds; both helper ready/go barriers complete, with activation discarding 105,816 pending Main bytes before the helper emits another subpicture overlay and enters an indefinite authored still.  The 31,913-byte screenshot `/tmp/entry816_menu_activate_failure.png`, SHA-256 `c07d08ce0ffb238f319f483e772d787f0409c665be0258e6356f0ddd04bb1a0b`, has all 64 schema-20 headers, row indices and parity bits valid and checksum `d8861e13` matching.  Its fatal snapshot accepts only 18,182 bytes and runs 24,263 decoder clocks in a new 30000/1001 B-picture session at temporal reference 7 before latching exactly error `0x0200` with presentation-error state asserted; no syntax, reconstruction, writer, cache, transport-block or timestamp-conflict error appears.  The 6,666,888-byte matching log has SHA-256 `5349d190bc9bd01c4bcaf342ad6f465c0f97d480f6b887db77c699c48e77969c`.  Absolute-path readback proves this is not a test of source `0e70319`: installed `/media/fat/linux/MediaPlayer_Helper` is the previous 904,564-byte source-`a9899e0` helper at SHA-256 `a00173f62ec4a8b0d126ef48695e299b2fecf4e836bff28abdc1107fe62eac7c`, not the identically sized source-`0e70319` candidate at `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`.  The missing `discarded_block_tail` log independently confirms the old helper ran, so neither the activation failure nor the arrow-key observation accepts or rejects the new helper.

#### Next Steps:

Manually replace only `/media/fat/linux/MediaPlayer_Helper` with `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` from the build PC and verify the destination SHA-256 is `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`, not merely the shared 904,564-byte size.  Restart MediaPlayer, press `M` during first-play, test all four arrow directions before Space, and leave the result visible; source-`0e70319` is accepted only if its root and activation `discarded_block_tail` logs appear, the highlight moves where the authored menu offers adjacent buttons, activation avoids the `0x0200` raster, and native 480i remains active.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 815 COMMIT Unreleased 0e70319 2026-08-31T05:45:08-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Prevent stale bytes from the current DVD block from crossing successful authored-menu navigation hops into a reset decoder session.

#### Outcome:

Successful root-menu and button-activation calls now share a bounded cleanup that discards the unread tail of the current 2,048-byte libdvdnav block, clears stale terminal and still state, preserves the hop notification for the existing Main/helper ready barrier, and logs the command plus exact discarded-tail length.  The focused native regression proves both a 1,535-byte unread tail and an empty boundary are invalidated correctly, and the retained subtitle/highlight decoder test passes.  The enhanced authored-DVD navigation harness waits for active libdvdnav state rather than CSS preflight, accepts ISO files or DVD directories, and passes against the Blazing Saddles directory with one root hop, one activation hop, two ready/go barriers, directional input, two overlay configurations, 44 data records carrying 172,800 bytes, two commits and 496 style updates.  Exact detached source `0e70319` builds both the native helper and a 904,564-byte static ARMv7 hard-float `MediaPlayer_Helper` at `/home/vash/MiSTer-Media-Player-0e70319/host/build/MediaPlayer_Helper` on the build PC, SHA-256 `c8a39413c5131ddfa26947013986e2088f0e72fa618f2ff6dd85fdb4bc7d3baf`; Main, RTL, QSF, RBF and Quartus remain untouched.

#### Next Steps:

The user should manually transfer only the exact ARM helper from the recorded build-PC path to `/media/fat/linux/MediaPlayer_Helper`, retain the installed Main and seed-20 RBF, then restart the core and press keyboard `M` during the early first-play trailers.  Hardware acceptance requires the root menu to appear without a freeze or 800-by-600 diagnostic raster, menu direction and activation to remain interactive, native 480i to remain active, and terminal telemetry to report no B-presentation or other errors; leave the terminal telemetry visible for collection after the run.

#### Files Modified:

- host/arm/media_source.c
- tools/test_dvd_menu_hop.c
- tools/test_dvd_menu_navigation.py

#### Status:

- [x] Built
- [ ] Passed

---

## 814 COMMIT Unreleased a9899e0 2026-08-31T05:41:30-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Correct entry 813's prefetch-thread diagnosis before implementing the approved root-menu navigation fix.

#### Outcome:

Complete inspection of `iso_prepare` proves that authored `isomenu:` and `dvdmenu:` playback intentionally bypasses the optical prefetch thread, so entry 813's statement that `iso_menu_command` races an active producer and leaves its ring undiscarded is incorrect and no source work is performed from that diagnosis.  The captured hardware evidence remains valid: root-menu command `0x09` and both control barriers complete, then the reset FPGA session trips only B-picture presentation error `0x0200` after 24,043 accepted bytes.  The actual unsafe helper boundary is narrower and directly visible in `iso_menu_command`: after successful `dvdnav_menu_call` or `dvdnav_button_activate`, it sets hop state but leaves `block_offset` and `block_size` pointing into the current 2,048-byte DVD block.  The next Program Stream pass can therefore consume a stale old-position block tail and assemble a pack or PES across the libdvdnav hop before reading the new authored position.  This corrects only the causal interpretation in entry 813; its screenshot, helper log, hashes and FPGA fault isolation are unchanged.

#### Next Steps:

Obtain approval for the corrected helper-only boundary before implementation: on successful root-menu or button-activation hops, invalidate the current DVD block, clear terminal and still state, and log the discarded block-tail byte count before returning to the existing Main/helper reset barrier.  Add a focused regression proving no pre-hop bytes survive either hop plus the existing real-image menu-navigation test, then build only the helper and repeat the early-trailer `M` hardware test without changing Main, the seed-20 RBF or Quartus source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 813 COMMIT Unreleased a9899e0 2026-08-31T05:35:17-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Capture and isolate the first hardware failure when an authored physical DVD receives the root-menu command during first-play trailers.

#### Outcome:

The source-`a9899e0` installation plays the physical disc's Viacom Paramount intro, four-language selection and three first-play trailers until its authored menu is eventually reached, proving sustained first-play video and audio before the navigation test.  After a fresh launch, keyboard `M` with the OSD closed submits root-menu command `0x09` at diagnostic time 4.138167 seconds; Main closes the download, discards 190,463 pending bytes, receives the helper's ready barrier and releases the new session, while the helper reports that the navigation barrier completes and its rearmed random-access filter discards zero leading B pictures.  The screen then freezes in the 800-by-600 diagnostic raster.  The 31,886-byte scaled screenshot `/tmp/entry813_root_menu_freeze.png`, SHA-256 `e5d61e8a547183b92a58ed5ccbd17eb73a439bd232294efdb73d02979856cc68`, contains all 64 schema-20 rows with valid headers, indices and parity and matching checksum `d80518c4`; its fatal snapshot occurs only 24,043 accepted video bytes and 443,132 decoder clocks after the navigation reset, on a 30000/1001 B picture with temporal reference 12, and reports exactly error `0x0200`, the B-picture presentation error, with the overlay extractor, overlay engine, syntax, reconstruction, writer, cache and audio error bits clear.  The matching 1,843,639-byte log `/tmp/entry813_root_menu_freeze_arm_helper.log`, SHA-256 `bb145d181f90e3642b4ac8a746067bdf6f4b2d83d1bee5e1f511e36f1997762b`, shows Main and helper continuing to transfer hundreds of megabytes after the fatal FPGA snapshot, so this is neither a Main barrier deadlock nor a helper stall.  Static inspection localizes the unsafe boundary to `iso_menu_command`: unlike accepted chapter changes, it calls the shared libdvdnav handle while the optical producer thread is active and neither stops nor discards its prefetched navigation ring before the FPGA download reset, allowing stale or concurrently spliced pre-hop bytes to open the new decoder session.  No target file, playback option or repository source changes during collection.

#### Next Steps:

Keep the seed-20 RBF and Main frozen and do not invoke another root-menu or activation hop on this running session.  Before implementation, approve a helper-only navigation-buffer correction that serializes libdvdnav hop commands with the optical producer, discards the pre-hop ring and partial block, restarts and prefills from the new authored position, and logs the discarded byte count; exercise it with a host concurrency regression and existing menu-navigation tests, then deploy only the helper and repeat the same early-trailer `M` test while requiring native 480i to remain active and all FPGA error flags to stay clear.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 812 COMMIT Unreleased a9899e0 2026-08-31T05:08:01-07:00

#### Coming From:

Unreleased a9899e0

#### Purpose:

Install the exact timing-clean source-`a9899e0` authored-menu RBF with its matching Main and ARM helper while preserving the accepted source-`6e44472` system for rollback.

#### Outcome:

At the user's explicit authorization, the build PC at exact source `a9899e0` produces a 904,564-byte static ARMv7 helper at SHA-256 `a00173f62ec4a8b0d126ef48695e299b2fecf4e836bff28abdc1107fe62eac7c` and a 1,174,492-byte patched ARMv7 Main at `a276aadcdc5aad4034bc40ee2dff52596fd44876156e24f16289d5a339411636`; the Raspberry Pi independently receives and verifies both artifacts together with entry 811's 4,511,756-byte seed-20 RBF at `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`.  Predeployment absolute-path FTP readback identifies the accepted active Main as 1,174,492 bytes at `d91b570057d6cf314f5f98d7d637a8607f59fe5b61a193a40e6a615a6bab8c98`, helper as 896,372 bytes at `156917b7a165905f3cc73adf995886d05fc3f60aa301a4a31574f36ac0b06202` and source-`6e44472` RBF as 4,441,756 bytes at `5d6fc43700d935edac4e14e2f26895aed33db5fe917dd5092128a5cc18a97c20`.  In accordance with entry 811's explicit rollback requirement, independent uploads and readbacks preserve those exact predecessors as `/media/fat/MiSTer.pre_a9899e0_d91b5700`, `/media/fat/linux/MediaPlayer_Helper.pre_a9899e0_156917b7` and `/media/fat/_MediaPlayer_Backups/MediaPlayer_a9899e0_pre_6e44472_5d6fc437.rbf`.  Unique candidate uploads are independently read back byte-for-byte before same-directory renames activate all three exact source-`a9899e0` artifacts at `/media/fat/MiSTer`, `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; final absolute-path readbacks reproduce all three complete candidate hashes.  The running Main and FPGA remain the previous versions until a normal reboot and core reload, so hardware acceptance is pending.

#### Next Steps:

Perform one normal MiSTer reboot, load MediaPlayer, and begin with an authored DVD ISO or physical disc whose menus are known to work in a conventional player.  Require first-play or root-menu entry, animated menu video and audio, visible subpicture graphics and selection highlight, directional movement to distinct buttons, activation of a selected title, return to root menu, and unchanged play, pause and chapter controls; stop and report the exact observed step if a fatal telemetry flag, missing overlay, incorrect highlight or navigation failure occurs.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 811 COMMIT Unreleased a9899e0 2026-08-31T04:19:24-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Find and pin a timing-clean fitter placement for the source-`2738e99` authored-menu design without changing its logic or constraints.

#### Outcome:

The user authorizes the bounded placement-only search after source `2738e99` removed the authored-menu overlay crossing failures but seed 19 exposed negative 0.107 ns global setup slack on sixteen ordinary same-clock HDMI scaler paths.  Seed 20 is the first and only searched placement and passes, so source `a9899e0` changes only the QSF seed from 19 to 20 and stops the search without any RTL, SDC, interface or memory-allocation change.  The retained-netlist fit, assembly and timing run passes all five categories, and the required clean exact-commit Quartus build then completes analysis and synthesis with zero errors and 154 warnings, fitting with zero errors and 45 warnings, assembly with zero errors and zero warnings, and TimeQuest plus Phase-1P extraction with zero errors.  Global setup is positive 0.161 ns with zero TNS in every reported setup clock, hold is positive 0.243 ns, recovery is positive 3.980 ns, removal is positive 0.428 ns and minimum pulse width is positive 0.925 ns; the 60 MHz decoder and 54 MHz video setup domains are positive 0.925 ns and 2.564 ns with zero violated paths.  The clean fit uses 35,797 of 41,910 ALMs, 54,851 registers, 4,187,011 memory bits, 535 of 553 M10Ks and 70 of 112 DSPs, with 38 percent average and 61 percent peak interconnect usage.  The retained-netlist and clean builds produce byte-identical 4,511,756-byte RBFs at SHA-256 `02928bff70b25eb0e0b1a6b8f24afec0dfe687f2524754b33fe13f4ed3014e9d`; the clean artifact is preserved on the build PC and fetched to the Raspberry Pi but is not installed on the MiSTer.

#### Next Steps:

Keep exact source `a9899e0`, fitter seed 20 and RBF SHA-256 `02928bff` frozen as the final FPGA boundary and perform no further Quartus work unless the user explicitly reopens it after a demonstrated FPGA-only defect.  After separate deployment authorization, build or verify the matching source-`a9899e0` Main and ARM helper, preserve the accepted source-`6e44472` installation as rollback, install and read back all three candidate artifacts, then hardware-test first-play and root menus, directional selection, activation, animated menu audio and video, subpicture graphics and highlights on several differently authored ISO and physical discs; keep subsequent compatibility work in Main and the helper wherever this frozen overlay architecture permits.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 810 COMMIT Unreleased 6e44472 2026-08-31T04:13:58-07:00

#### Coming From:

Unreleased 2738e99

#### Purpose:

Capture and qualify the on-screen telemetry after the user's perfect full-disc DVD playback on the accepted source-`6e44472` installation.

#### Outcome:

The user reports that the DVD finished perfectly after extensive chapter skipping and leaves the completed session's telemetry visible for collection.  The 285,090-byte 1920-by-1080 scaled screenshot `/tmp/entry810_completed_dvd_telemetry.png`, SHA-256 `3c3a184eb5df0e8c6fe31bdddf4bd8956debbe2320dfc796bdd89787156c7dc4`, has all 64 schema-20 headers, row indices and parity bits valid and checksum `eb7a78f8` matching.  The visible raster is the sticky first-error snapshot at STC second 1,795 rather than an end-of-file snapshot: it records 1,085,445,320 accepted video bytes, 42,919 displayed pictures, 42,918 swaps, exactly one audio FIFO underrun, FIFO floor zero, zero transport blocks and no error flag other than the corresponding `0x0400` audio-underrun bit; its three retained largest gaps are each 66.733 milliseconds, with 42,917 deadline-gap events and 21,465 cadence outliers.  The matching 194,633,412-byte helper log `/tmp/entry810_completed_dvd_arm_helper.log`, SHA-256 `e0db52dc8a47949209a3574b93d5b81c359c3b0ec6cfeb9cfa3cfcacf86efa8c`, identifies direct optical title 1 with 24 chapters and HDMI decoded stereo PCM, later reaches DVD EOF and exits zero after approximately 7,014 seconds of a session that included the user's navigation; it processes 4,239,456,995 video bytes and 219,032 AC-3 frames, produces and consumes 5,096,290,304 DVD-buffer bytes with zero consumer waits, and Main submits 5,690,325,341 bytes entirely through the fast path.  The single latched underrun remains within the previously accepted isolated-underrun allowance and produced no user-perceived defect; no repository source, installed file, RBF, Main, helper, media, playback option or target configuration changes during collection.

#### Next Steps:

Keep accepted source `6e44472` and its installed artifacts unchanged as the hardware baseline, retain source `2738e99` as the uninstalled authored-menu candidate, and continue to pause implementation and build work until the user explicitly approves or declines the separately proposed bounded eight-seed fit-and-timing search.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 809 COMMIT Unreleased 2738e99 2026-08-31T03:31:31-07:00

#### Coming From:

Unreleased 8d1a5d0

#### Purpose:

Correct the authored-menu overlay clock-crossing timing boundary without weakening same-clock analysis or changing overlay behavior.

#### Outcome:

Source `2738e99` adds endpoint-specific timing exceptions only from the authored-menu overlay's stable buses and event toggles to their explicit first sampling stages in the opposite 54 MHz or 60 MHz domain, leaving every second stage, same-clock path and the clock relationship timed, and makes both overlay width conversions explicit without changing the packed-pixel address or alpha result.  TimeQuest resolves every new exception to real keepers with no ignored overlay filter, the two overlay width warnings disappear, all three focused overlay simulations pass, and eight retained mixed-raster, interlaced-I/P, field-motion, field-DCT, B-field and exhaustive B-motion regressions pass.  The one authorized clean seed-19 compile completes synthesis, fitting and assembly with zero errors; decoder setup is positive 0.975 ns, video setup is positive 1.680 ns, hold is positive 0.246 ns, recovery is positive 4.072 ns, removal is positive 0.508 ns and minimum-pulse-width is positive 0.925 ns.  The global setup gate nevertheless rejects the RBF at negative 0.107 ns with negative 0.839 ns TNS across sixteen ordinary same-clock HDMI scaler paths from `ascal|o_h_poly_t.r0` to `ascal|o_h_poly_pix.r`; this is one logic level, not an overlay crossing, and is not false-pathed.  The fit uses 35,834 of 41,910 ALMs, 535 of 553 M10Ks and 70 of 112 DSPs; the rejected 4,506,492-byte RBF hashes `9550bd2a`, is not fetched or installed, and the MiSTer remains on accepted source-`6e44472` artifacts.

#### Next Steps:

Keep source `2738e99` and the accepted source-`6e44472` MiSTer installation unchanged while obtaining approval for a separate placement-only timing boundary.  The smallest next action is a bounded fit-and-timing seed search reusing the exact synthesized `2738e99` netlist, with no RTL or constraint change, followed by pinning the first seed whose global setup, hold, recovery, removal and minimum-pulse-width margins are all positive and verifying it once in a clean full build; do not weaken the HDMI constraint or pipeline the MiSTer scaler unless the bounded seed search fails.

#### Files Modified:

- MediaPlayer.sdc
- rtl/mpeg2_new/mpeg2_h262_dvd_overlay.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 808 COMMIT Unreleased 8d1a5d0 2026-08-31T01:28:52-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Implement authored DVD-Video menu navigation and subpicture highlights through the existing libdvdnav session and a bounded FPGA DDR overlay plane.

#### Outcome:

Source `8d1a5d0` implements authored first-play, directional selection, activation and return-to-menu for ISO and optical DVD sources while preserving the accepted title, chapter, pause, audio and CSS paths.  The helper assembles fragmented DVD subpictures into a packed 720-by-480 two-bit plane with palette, alpha and highlight state; bounded in-band records feed an inactive FPGA DDR plane, an atomic commit publishes it, and a native-480i line cache composites it before the cadence diagnostic overlay without using decoder frame banks.  Focused malformed-SPU, fragmentation, palette, alpha, highlight, metadata-backpressure, overlay-engine and arbiter tests pass, the complete retained native-480i regression passes, ordinary MPG and legacy `iso:` candidate output is byte-identical to the accepted helper, and a real authored ISO navigation harness observes menu entry, menu exit, two ready barriers, two overlay commits and successful root, direction and activation behavior.  Exact-source ARM helper, Main and strict native helper builds succeed.  The one authorized clean seed-19 Quartus compile completes synthesis, fitting and assembly with same-clock setup margins of positive 0.675 ns at 60 MHz and positive 1.946 ns at 54 MHz, but final timing rejects the RBF because the new explicit two-stage overlay clock crossings lack source-to-first-stage exceptions: global setup is negative 1.951 ns, hold is negative 0.281 ns, while recovery, removal and minimum-pulse-width are positive.  The rejected RBF is not installed and the MiSTer remains on accepted source `6e44472` artifacts.

#### Next Steps:

Keep accepted source `6e44472` and its installed artifacts unchanged on the MiSTer.  Before any further source edit or Quartus build, obtain approval for a separate narrowly scoped timing-correction boundary that cuts only the stable overlay handshake buses and toggles from their source registers to the first synchronizer stages, retains timing through the second stages, and cleans the two reported overlay width-truncation warnings; then rerun focused clock-crossing and retained regressions and one clean seed-19 build, accepting an RBF only if setup, hold, recovery, removal and minimum-pulse-width are all positive.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer.sv
- README.md
- docs/ARCHITECTURE.md
- docs/BUILDING.md
- files.qip
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/dvd_spu.c
- host/arm/dvd_spu.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- rtl/mpeg2_new/mpeg2_dvd_overlay.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_arbiter.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/test_dvd_menu_navigation.py
- tools/test_dvd_overlay_arbiter.sv
- tools/test_dvd_overlay_engine.sv
- tools/test_dvd_overlay_metadata.sv
- tools/test_dvd_spu.c

#### Status:

- [x] Built
- [ ] Passed

---

## 807 COMMIT Unreleased 6e44472 2026-08-31T01:20:21-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Complete hardware acceptance of the source-`6e44472` menu and mixed-film chapter corrections.

#### Outcome:

The user reports skipping throughout the physical DVD without any issue, including the previously abnormal chapters, which now look normal, and reports that the reorganized menu looks great.  Together with entry 806's perfect previous, next, play, pause, button-control, audio, video, WAV, MP3, FLAC and Ogg Vorbis results, this clears the chapter-two-to-three black-screen gate, the legacy 800x600 or vertically corrupted mixed-film chapter behavior and the OSD acceptance boundary for entries 803 through 805.  Source `6e44472`, its timing-clean seed-19 RBF, the installed Main and the installed helper are hardware-accepted; no screenshot, target capture, repository source, installed file, running playback, media or configuration changes during this report.

#### Next Steps:

Keep source `6e44472`, fitter seed 19 and the accepted installed artifacts unchanged as the current hardware baseline.  The transport controls, chapter navigation, mixed film and interlaced presentation, reorganized menu and four consumer-audio formats are accepted; choose and approve the next development or release-qualification boundary before changing source or rebuilding Quartus.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 806 COMMIT Unreleased 6e44472 2026-08-31T01:17:02-07:00

#### Coming From:

Unreleased 6e44472

#### Purpose:

Record the user's hardware acceptance of transport controls, button mappings, audio and video playback, and all four consumer-audio formats on the installed source-`6e44472` system.

#### Outcome:

The user reports that previous chapter, next chapter, play and pause all work perfectly, every tested button control behaves correctly, audio and video are perfect, and WAV, MP3, FLAC and Ogg Vorbis files all play properly.  At the user's direction no screenshot or other target capture is taken, and no repository source, installed file, running playback, RBF, Main, helper, media or configuration changes during this acceptance report.  This accepts the transport-control and consumer-audio portions of entries 803 through 805; the report does not independently identify the requested menu-layout checks or the chapter-specific mixed-film sequence at chapters 8, 11, 15, 17 and 23, so those narrow gates remain open.

#### Next Steps:

Confirm whether the three file actions, `16:9` default, `4:3` choice, Bob and Weave choices and unchanged audio sections appear correctly in the OSD, then explicitly verify that chapter 2 advances into chapter 3 and chapters 8, 11, 15, 17 and 23 remain in native 480i without a black screen, legacy 800x600 raster or vertical corruption.  If those checks already formed part of this test, record that confirmation without taking a screenshot; otherwise leave source `6e44472` and the installed timing-clean RBF unchanged while completing only those remaining hardware gates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 805 COMMIT Unreleased 6e44472 2026-08-31T00:16:48-07:00

#### Coming From:

Unreleased 4525ae4

#### Purpose:

Move the expanded MediaPlayer configuration string into exactly one M10K so the timing-clean decoder and video logic no longer displace the HDMI scaler into a failing placement.

#### Outcome:

Source `6e44472` changes only the sole `hps_io` instantiation to enable its existing synchronous `CONF_STR_BRAM` implementation, preserving every configuration byte, selector, status bit, menu label, scaler function, decoder path, clock and fitter seed.  A focused ROM test returns the complete byte sequence with the designed one-cycle latency, the mixed field-order test passes, and the complete native-480i startup, cache, TFF/BFF timing, Bob/Weave, pattern, overlap, PTS, presentation, fingerprint, generation, deadline and cadence suite passes after the user's build-PC reboot interrupted and invalidated the first run.  Exactly one clean Quartus Prime 17.0.2 build from the exact source commit at pinned seed 19 completes successfully using 34,034 of 41,910 ALMs, 52,553 registers, 4,184,067 memory bits in exactly 533 of 553 M10Ks and 67 of 112 DSP blocks, satisfying the user's condition of one and only one additional M10K.  Every timing category is positive with zero setup TNS: setup 0.119 ns, hold 0.246 ns, recovery 3.684 ns, removal 0.587 ns and minimum pulse width 0.925 ns; the 60 MHz decoder and 54 MHz video setup domains are positive 0.533 and 2.673 ns.  The 4,441,756-byte RBF has SHA-256 `5d6fc43700d935edac4e14e2f26895aed33db5fe917dd5092128a5cc18a97c20`, is installed at `/media/fat/MediaPlayer_20260829_b9c2657.rbf`, reproduces the exact hash by readback and is loaded on the MiSTer; hardware menu and playback acceptance remain open.

#### Next Steps:

Open the MiSTer OSD and verify the three requested file actions, 16:9 default, 4:3 choice, Bob/Weave choices and unchanged audio sections.  Launch the physical DVD, confirm unchanged play/pause, advance beyond chapter 2 and then through chapters 8, 11, 15, 17 and 23 without a black screen, legacy 800x600 raster or vertical corruption, and test one Ogg Vorbis file; preserve the helper log and telemetry before accepting entries 803 through 805 as hardware-passed.

#### Files Modified:

- MediaPlayer.sv

#### Status:

- [x] Built
- [ ] Passed

---
