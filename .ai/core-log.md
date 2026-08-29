## 710 COMMIT Unreleased ??? 2026-08-29T06:55:07-07:00

#### Coming From:

Unreleased b9c2657

#### Purpose:

Correct quantized interlaced I/P/B macroblock parsing and preserve generation-safe future-reference binding when presentation narrowly precedes a B header.

#### Outcome:

The approved correction is bounded by an exact hardware and simulation reproduction of the Coming to America interlaced-frame test failure.  After the unique timing-qualified `b9c2657` RBF is explicitly loaded, hardware displays 63 pictures and freezes a checksum-valid schema-20 snapshot at clean-video byte 204,101 with error flags `0x0004`; the physical LEDs report USER 3, POWER 2 and DISK 7, identifying the generalized P prediction raster's row-terminator assertion.  Exact production-path replay initially shows macroblocks 675 through 680 from the current P picture followed by macroblocks 0 through 44 from the next P picture before the current row terminator.  A first header-count hold at source `c477469` deadlocks at byte 204,066, and direct-transaction ownership at `b5c546f` advances only through the following picture-coding extension to byte 204,081 because the actual loss of ownership occurs earlier.  A parser-only replay isolates it at picture 65, slice row 16, macroblock column 6: the RTL reads a quantized P macroblock as quantiser scale, `motion_type` and `dct_type`, while H.262 and FFmpeg decode the transmitted order as `motion_type`, `dct_type`, quantiser scale and then vectors.  The preceding quantized macroblock leaves the RTL one bit early, so legal field motion `01` is read as reserved `00`; the parser drops the remaining fifteen rows, and the next P picture then enters that unfinished raster transaction.  Published source `b6ba7c8` removes the experimental wrapper hold, restores standards order in the P wide-parser FSM, and adds a quantized interlaced-P case to the existing FFmpeg-cross-checked field-DCT fixture.  The corrected P parser crosses the original byte-204,101 boundary and the production path remains clean until byte 1,120,843, where picture parsing stops independently in the B parser's `S_MOTION_TYPE` at slice row 4, macroblock column 11.  Published source `4b58b43` applies the analogous B ordering and adds a quantized bidirectional B case; its FFmpeg-cross-checked field-DCT regression reconstructs 1,036,800 samples exactly with zero parser, raster, writer or presentation errors.  The full replay then crosses both former parser failures but stops at byte 1,135,154 with only `presentation_error` asserted after the repaired B picture parses and reconstructs successfully.  A passive scheduler-edge monitor proves the preceding P reference is promoted and displayed on bank 1, the B header arrives one cycle later, and the scheduler nevertheless marks that same generation as pending because the physical display and reference bank numbers match.  Published source `a99d184` adds the approved promotion-generation guard and passes the complete scheduler suite plus the exact 1,036,800-sample field-DCT fixture, but the production replay reproduces the same stop because its two-bit `reference_headers_inflight` bookkeeping remains at one.  Published experiments `e67aadd` and `59b4d01` replace that occupancy estimate with an eight-bit I/P header total and also pass both focused regressions, but the exact replay still stops at the same byte with 48 I/P headers against 47 promotions.  Raw coded-order analysis and passive cycle correlation prove that mismatch was inherited across an earlier sequence boundary and does not describe the failing edge: all 41 observed P headers have published, no reference decode or ownership state remains active, and the displayed bank is the newest promoted reference.  Published source `d0cd422` snapshots the promotion generation at each accepted I/P header, passes the complete scheduler suite and exact field-DCT fixture, and crosses the former byte-1,135,154 failure cleanly.  The replay then exposes a separate presentation failure at picture 91 and byte 1,222,106 because the immediately preceding I picture never publishes.  An exact 48,016-byte isolated replay reproduces the underlying I-parser error at byte 888, slice 3, macroblock 11, state `ST_MB_QSCALE`; like the repaired P/B paths, the quantized interlaced I path consumes `quantiser_scale_code` before the transmitted `dct_type`, reads a false zero scale and abandons the reference picture.  Published source `493059a` restores that field order and makes the isolated I plus sequence-end case publish once with zero decoder errors.  The expanded I/P/B fixture then fails before exercising that lifecycle edge, and passive frontend tracing corrects the earlier interpretation: the FFmpeg-derived fixture clears `progressive_frame` without also clearing `chroma_420_type`, retains forward I-picture f-codes `3/3` instead of the required `15/15`, raises frontend syntax error source 21 and therefore never admits its I parser.  Published source `154b303`, which permits an active I parser to finish only the following start-code prefix and value after eligibility clears, does not alter that invalid-fixture failure and remains unvalidated rather than a confirmed decoder correction.

#### Next Steps:

Extend the shared fixture patcher to set `chroma_420_type` explicitly and to permit the required `15/15` forward f-codes for I pictures, then regenerate the interlaced I/P/B fixture with valid native-480i semantics and independently confirm it with FFmpeg.  Compare that corrected fixture on `493059a` and `154b303` to determine whether the narrow start-code retirement change is necessary, retain or revert it according to that evidence, and require the scheduler suite to pass.  Then rerun the exact 6,751,008-byte production-path stream from byte zero and require all 361 pictures to complete with no I, P, B, raster, writer or presentation error before the established mixed, field-motion, field-DCT and original DVD regressions.  If those gates pass, perform one clean Quartus seed-20 build with focused decoder and video timing audit; if timing fails, stop without retrying or reseeding.  Install and hardware-test a resulting timing-clean RBF only after readback verification.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- rtl/mpeg2_new/mpeg2_h262_luma4_probe.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/generate_test_interlaced_field_dct_residual.py
- tools/streams/h262common.py
- tools/streams/tb_h262_film_reorder_timestamp.sv
- tools/streams/run_film_presentation.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 709 COMMIT Unreleased b9c2657 2026-08-29T06:09:31-07:00

#### Coming From:

Unreleased b9c2657

#### Purpose:

Install the exact timing-qualified interlaced decoder candidate and hardware-validate its known Big Lebowski opening regression over HDMI and Weave.

#### Outcome:

The exact 4,436,916-byte RBF from entry 708 is retrieved from the build PC, independently reproduces SHA-256 `f366c246854d177aa2ce4d359d370be840094ecdb09164b736e5d55f4ed3392e`, and is staged, read back, promoted and finally read back again as `/media/fat/MediaPlayer_20260829_b9c2657.rbf` without replacing any older core.  Following the explicit reload handoff, the user plays `games/MediaPlayer/dvd_opening_original.mpg`, the twelve-second stream-copy opening derived from `the_big_lebowski.iso`, with HDMI decoded stereo PCM and Weave, and reports that everything looks perfect and the sound is perfect too.  Two completed screenshots are byte-identical, show the final Universal frame and decode as checksum-valid schema-20 quiet snapshots.  Telemetry accepts the exact expected 10,334,169 clean video bytes, all 289 displayed pictures, 288 swaps, 128 reference plus 161 B pictures and all 25 timestamps, reaches sequence end and presentation completion, and reports zero error flags, audio underruns, PCM protocol faults, presentation faults, cache-bank overlap faults or validation failures.  The helper identifies AC-3 private substream `0x80`, emits 375 frames and 576,000 decoded stereo samples, reaches EOF and exits zero after all 12,818,397 transport bytes in 784 pipe reads, with every byte on the fast path and none on the slow path.  Readback reproduces the qualified RBF, accepted static helper and source movie hashes.  This accepts the exact `b9c2657` candidate for the known opening regression; because that fixture uses progressive frame pictures within an interlaced sequence, it does not alone qualify the newly admitted field-motion and field-DCT syntax.

#### Next Steps:

Keep the accepted RBF loaded and prepare one short stream-copy excerpt from the user's decrypted DVD samples that is confirmed to contain the newly admitted interlaced field-motion and field-DCT syntax.  Test that excerpt once in HDMI Weave, preserve the completed screen and helper log, and only then repeat it in Bob and native 480i if the first run is clean.  Retain 576i, field pictures, `repeat_first_field` expansion beyond the already admitted film cadence, DVD navigation, menus and direct ISO playback outside this checkpoint.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 708 COMMIT Unreleased b9c2657 2026-08-29T05:59:55-07:00

#### Coming From:

Unreleased d89c02b

#### Purpose:

Close timing on the completed interlaced MPEG-2 production decoder and preserve one exact fit-qualified candidate for hardware validation.

#### Outcome:

Published source `98a1670` first updates the cadence regression for the established schema-20 audio fields and passes its isolated deadline, hardware-cadence, RTL-packet and decoder-layout checks.  The first clean seed-20 build fits at 33,956 ALMs but its focused decoder audit fails at negative 2.006 ns, so that RBF is rejected.  Source `ad2b27f` inserts a B prediction boundary while retaining pixel-exact mixed, field-motion and field-DCT reconstruction, but its clean build fails the same focused audit at negative 3.712 ns and is also rejected.  Final published source `b9c2657` registers the B fetchers' retained-footprint lookup, targets requests only to the selected physical fetcher and flushes pending lookup state at each start.  The progressive mixed fixture compares all 423,936 samples within its established two-level tolerance, and the B field-motion, frame-motion field-DCT and combined field-motion plus field-DCT fixtures each compare 1,036,800 samples exactly with zero parser, raster, writer or presentation errors.  A fresh detached checkout of exact full SHA `b9c2657e6aefb6c9f6101efbe72c0b29e487a3dc` completes Quartus Prime 17.0.2 seed 20 with zero errors.  The fit uses 33,589 of 41,910 ALMs, 51,747 registers, 4,181,443 memory bits, 532 of 553 RAM blocks and 67 DSP blocks.  Full timing passes with setup 0.023 ns, hold 0.246 ns, recovery 2.440 ns, removal 0.481 ns and minimum pulse width 0.925 ns; the focused audit finds zero violations with decoder setup 0.023 ns and video setup 2.735 ns.  The accepted 4,436,916-byte RBF remains on the build PC at `/home/vash/mister-builds/entry710/source_b9c_clean/output_files/MediaPlayer.rbf` with SHA-256 `f366c246854d177aa2ce4d359d370be840094ecdb09164b736e5d55f4ed3392e`.  It has not been installed or hardware-tested.

#### Next Steps:

Preserve this exact RBF as the sole candidate and perform one user-controlled MiSTer playback validation of the 720-by-480 NTSC interlaced target, checking native 480i first and then Bob and Weave presentation without opening 576i scope.  Do not rebuild or reseed this checkpoint; if hardware exposes a defect, retain the completed screen and helper log before deciding on a separately approved correction.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [ ] Passed

---

## 707 COMMIT Unreleased d89c02b 2026-08-29T04:29:02-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Complete interlaced frame-picture P/B field-DCT reconstruction and open the qualified field-motion and field-DCT paths for production decoding.

#### Outcome:

Published source `d89c02b` completes the field-DCT parser, metadata, raster and DDR-store path begun in `e7d4a10`, corrects prediction fetches to follow field-ordered luma rows, and applies the macroblock `dct_type` layout to coded and uncoded luma blocks alike so frame-ordered prediction cannot overwrite neighboring field rows.  P field-DCT prediction uses doubled-stride rectangles and a second parity rectangle only for frame-motion vertical half samples.  B field-DCT prediction reuses the two existing fetchers by direction, with up to two vertical-parity phases per direction, and the combined field-motion case selects the correct destination-field vector and reference-field parity without adding block memory.  The production P and B parser restrictions on clear `frame_pred_frame_dct` are removed, and the frontend now keeps native 480i ownership eligible across admitted interlaced I, P and B frame pictures.  Deterministic fixtures independently checked against FFmpeg cover P and B frame motion with field DCT, integer and horizontal, vertical and diagonal half samples, all luma layouts, chroma residuals, pure field motion, and the combined field-motion plus field-DCT case.  Each of the four production-path simulations compiles without the former test define and compares every reconstructed sample exactly, totaling 518,400 samples for the P-field fixture and 1,036,800 samples in each P/B fixture, with zero parser, raster, writer or presentation errors.  The unchanged progressive mixed-raster control compares 423,936 samples with zero mismatches above its established two-level tolerance, and the interlaced TFF, BFF, progressive and field-DCT I-picture controls retain zero out-of-tolerance pixels.  No Quartus build, RBF installation or MiSTer playback is claimed yet.

#### Next Steps:

Pull exact published source `d89c02b` into a fresh isolated build-PC checkout, run the broader decoder and native-presentation regression set, and then perform one clean Quartus Prime 17.0.2 build with the focused timing report.  Require a successful fit, positive timing in every required category and resource comparison against the 34,163-ALM, 532-RAM-block recovery baseline before producing a candidate RBF.  If those gates pass, generate a real interlaced National Archives profile Program Stream that exercises admitted P/B syntax for a controlled MiSTer playback test; keep field pictures, `repeat_first_field`, 576i and DVD navigation explicitly outside this checkpoint.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_03.svh
- MediaPlayer_top_04.svh
- README.md
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/generate_test_field_motion_field_dct.py
- tools/streams/generate_test_interlaced_field_dct_residual.py
- tools/streams/h262common.py
- tools/streams/run_b_field_motion.sh
- tools/streams/run_field_motion_field_dct.sh
- tools/streams/run_interlaced_field_dct_residual.sh
- tools/streams/run_interlaced_field_motion.sh
- tools/streams/tb_h262_field_motion_field_dct_pixels.sv
- tools/streams/tb_h262_interlaced_field_dct_residual_pixels.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 706 COMMIT Unreleased 736f64f 2026-08-29T03:55:11-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Record hardware acceptance of standalone MP3 playback over decoded-PCM S/PDIF.

#### Outcome:

After identifying that the first attempted capture belonged to an accidental replay of the DVD opening, the user runs the intended `entry697_file_example_WAV_1MG_192k.mp3` test with the same loaded `MediaPlayer_20260829.rbf` and reports that everything passes and the audio sounds great.  The corrected helper log identifies the exact MP3 source and `audio output spdif (decoded PCM; IEC 61937 for AC-3/DTS)`, emits zero video bytes, zero timestamps and 229 decoded audio frames containing 263,808 stereo samples, reaches EOF and exits zero.  Main submits all 1,137,676 transport bytes across 70 pipe reads, with every byte on the fast path and none on the slow path.  The standalone-audio run leaves the preceding video telemetry image resident, so that stale decoder snapshot is not treated as MP3 evidence; the source-specific helper completion and the user's physical listening result accept MP3 decoded PCM over S/PDIF.  No source, FPGA image, helper, Main or MiSTer configuration changed during capture.

#### Next Steps:

Per the user's direction, stop consumer-audio hardware testing here and return to DVD video work.  Add and fixture-test inter-macroblock field DCT before opening the P, B and frontend production admission gates, preserving the fit-qualified RBF and accepted helper unchanged until the video simulation gates justify another build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 705 COMMIT Unreleased 736f64f 2026-08-29T03:46:17-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Record hardware acceptance of the fit-recovered candidate's original-DVD-opening regression over HDMI decoded stereo PCM.

#### Outcome:

The user explicitly loads `MediaPlayer_20260829.rbf`, plays `dvd_opening_original.mpg` over HDMI decoded stereo PCM and reports that everything looks perfect.  Two fresh completed screenshots are byte-identical, show the final Universal frame, decode as checksum-valid schema 20 quiet snapshots and pass the exact expected 289-picture and 10,334,169-byte gate with no validation failure.  Telemetry reaches sequence end and presentation completion with 289 displayed pictures, 288 swaps, 128 reference plus 161 B pictures, all 25 timestamps, zero error flags, no audio underrun, no PCM protocol or presentation error and no cache-bank overlap error.  The helper identifies AC-3 private substream `0x80`, emits 375 frames and 576,000 decoded stereo samples, reaches EOF and child exit zero, and reconciles all 12,818,397 submitted bytes across 784 pipe reads with every byte on the fast path and none on the slow path.  FTP readback reproduces the qualified RBF and helper hashes.  Legacy observational counters remain visible at 287 deadline records, 144 outliers, 20 timestamp-advance conflicts and zero delay conflicts; they are not the acceptance gate and do not negate the clean functional result.  This accepts the existing original-opening HDMI regression only; production field prediction remains closed and no S/PDIF mode is exercised by this run.

#### Next Steps:

Continue the same loaded candidate with MP3 over S/PDIF first, followed by WAV and FLAC over S/PDIF, AC-3 passthrough over S/PDIF and one known progressive video.  Report each audible and visible result, and leave the latest helper log and terminal screen intact before replay if any dropout, receiver unlock, protocol fault or visual regression occurs.  Treat the recovered RBF as an accepted existing-video baseline while keeping the decoded-PCM S/PDIF correction and production field-prediction path open until their own hardware checks complete.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 704 COMMIT Unreleased 736f64f 2026-08-29T03:35:47-07:00

#### Coming From:

Unreleased 8404035

#### Purpose:

Deploy and hardware-test the exact fit-qualified recovery RBF with its matching decoded-PCM S/PDIF helper.

#### Outcome:

The exact source `736f64f` artifacts were retrieved from GUNSMOKE and independently reverified before deployment.  The 4,459,744-byte RBF with SHA-256 `3f66a5eb38bcff783472b977764bc34366a07570b01278822e705718edf224fa` is installed as `/media/fat/MediaPlayer_20260829.rbf` without replacing any existing core, and final FTP readback matches.  The installed 629,056-byte helper with SHA-256 `f5573a98dcd788228d317da906c8d017cf904e3a85f1d43aea7f13b048252758` is preserved and readback-verified at `/media/fat/_MediaPlayer_Backups/MediaPlayer_Helper_f5573a98dcd7_20260829T034019`; the matching 629,056-byte helper with SHA-256 `02d1df98c62ee00169585db990b6bd48c3769eca20c3e1d594f2318c362eb00f` is staged, promoted and verified at `/media/fat/linux/MediaPlayer_Helper`.  An initial read-only inventory used curl's login-relative FTP interpretation; after the user identified the mistake, filesystem-absolute paths were encoded explicitly before any write.  Before-and-after readbacks prove MiSTer Main, the active undated core, the prior dated core and the original DVD opening unchanged.  No core was loaded and no playback was started.  This checkpoint can validate existing video behavior and corrected HDMI and S/PDIF routing, but production interlaced P and B admission remains closed and therefore it cannot accept the NARA release profile or prove the recovered field-prediction path on hardware.

#### Next Steps:

Explicitly load `MediaPlayer_20260829.rbf`, then play the existing original DVD opening over HDMI decoded PCM first and report motion, audio and completion.  If clean, test MP3, WAV and FLAC over S/PDIF, then AC-3 passthrough over S/PDIF and one known progressive video.  Leave the completed screen and latest helper log intact before replay if any regression, dropout, protocol fault or visible error occurs so evidence can be collected.  Mark hardware acceptance only after the user reports the checkpoint results; this RBF does not yet exercise production field prediction.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 703 COMMIT Unreleased 8404035 2026-08-29T03:31:55-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Adopt the U.S. National Archives MPD-D2 DVD-from-film profile as the project's controlled release media target.

#### Outcome:

Controlled reference commit `8404035` adds the official NARA MPD-D2 web profile to the active source catalog, routing table and fast index as record `NARA-001`, and adopts it as the project's release media baseline.  The target carries MPEG-2 Main Profile at Main Level in VOB and Program Stream form, temporary eight-megabit-per-second standard-definition source, 720 by 480 constant-bit-rate video at 29.97 frames per second, interlaced top-field-first single-pass encoding, and two-channel constant-bit-rate AC-3 at 256 kilobits per second, 48 kilohertz and a listed sixteen-bit sample size.  The controlled source preserves NARA's December 22, 2023 page-review date and the August 29, 2026 verification date.  It explicitly does not replace the normative H.262, H.222.0, DVD application, filesystem, navigation, menu or CSS sources, and it records that MPD-D2 does not constrain `picture_structure`, `motion_type`, macroblock `dct_type`, GOP design or quantization matrices, so a frame-picture-only subset cannot be inferred from the profile.  No RTL, helper, RBF or MiSTer state changed.

#### Next Steps:

Use `NARA-001` as the controlling media baseline when defining release fixtures and acceptance language.  Retain conforming streams that exercise the implemented H.262 syntax envelope and verify complete playback, top-field-first cadence, decoded HDMI stereo and AC-3 S/PDIF passthrough, while declaring any profile-permitted syntax not covered by those streams as an explicit limitation.  The fit-qualified RBF and matching helper remain ready for a separately authorized regression and S/PDIF hardware checkpoint before field DCT and production interlaced P/B admission are added.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 702 COMMIT Unreleased 736f64f 2026-08-29T03:10:56-07:00

#### Coming From:

Unreleased 736f64f

#### Purpose:

Qualify the published interlaced prediction recovery and pending decoded-PCM S/PDIF correction with one clean exact-source Quartus build.

#### Outcome:

An isolated fresh GitHub clone was verified at exact published source `736f64f` with no tracked mismatch or reused Quartus database, and Quartus Prime Lite 17.0.2 completed the full configured flow in fourteen minutes twenty-three seconds with zero errors and 218 warnings.  The fitter succeeds at 34,163 of 41,910 ALMs, eighty-two percent, with 52,455 registers, 4,178,743 memory bits, 532 of 553 RAM blocks and 67 DSP blocks.  This reclaims 5,539 ALMs and 2,562 registers from the failed near-final report and leaves field prediction only 1,808 ALMs above the 32,355-ALM pre-field baseline instead of 7,347; RAM remains the binding resource at ninety-six percent.  One routing-congestion warning is emitted while the router converges, but routing completes in the same invocation and no critical or timing-failure warning occurs.  Every reported timing category has zero TNS and positive slack: minimum setup plus 0.100 nanoseconds in the sixty-megahertz MPEG domain, hold plus 0.243, recovery plus 3.086, removal plus 0.404 and minimum pulse width plus 0.925; the focused report independently finds zero violated decoder or video paths, with video setup plus 2.885 nanoseconds.  The 4,459,744-byte RBF has SHA-256 `3f66a5eb38bcff783472b977764bc34366a07570b01278822e705718edf224fa`, and complete build and focused timing evidence remains under `/home/vash/mister-builds/entry702/source_0313` on GUNSMOKE.  No production admission gate, field DCT, MiSTer installation or hardware playback occurred, so hardware acceptance remains open.

#### Next Steps:

Preserve this exact source, reports and RBF as the fit-qualified recovery baseline.  Under separate authorization, deploy the matching RBF and static helper together after backing up the installed files, then physically verify MP3, WAV and FLAC over S/PDIF while preserving HDMI decoded PCM and AC-3 and DTS receiver lock.  For the next DVD RTL cycle, add and fixture-test inter-macroblock field DCT before opening the P, B and frontend production admission gates; avoid new block memories because only twenty-one RAM blocks remain, and require the complete progressive and interlaced regression set before another clean build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 701 COMMIT Unreleased 736f64f 2026-08-29T02:45:25-07:00

#### Coming From:

Unreleased c2097e3

#### Purpose:

Recover the near-complete interlaced P and B field-prediction work by removing replicated fetch storage and parallel footprint logic while preserving accepted consumer audio and the pending S/PDIF correction.

#### Outcome:

The failed fitter run remains useful evidence of unacceptable structural cost but is not treated as an exact qualification of `784ae0b`, because mapping began before that final source commit existed and the shared checkout later advanced.  Published source `736f64f` retains the parser and prediction arithmetic repairs while reversing both expensive implementation choices.  Each existing B fetcher again retains at most two rectangles; a bidirectional field block fetches its forward parity pair through the current instance, then reuses the otherwise idle prefetch instance for the backward pair after the shared DDR port is released.  Lookup selects the physical direction bank while each fetcher's phase index carries only destination parity.  The field selector is registered before one pair of base-address, span and bounds calculations, so four parallel footprint cones become one serialized pair.  Two races exposed by this reuse are corrected explicitly: a lookup broadcast is suppressed on the same edge that a fetcher clears its old validity map, and a nonzero backward byte origin is refreshed during the protected alternate-start cycle if the forward pixel completed before that pair launched.  Production admission remains closed; `H262_TEST_FIELD_MOTION` opens only the P and B parser gates in the two deterministic scripts, and their byte conversion now uses standard `od`, `tr` and `fold` instead of requiring `xxd`.  Fresh isolated simulations compare 518,400 P-field samples and 1,036,800 B-fixture samples with zero mismatches, including both destination parities and the four independently selected B reference fields, while the unchanged progressive mixed-raster control checks 423,936 samples with zero mismatches above its established two-level tolerance and maximum delta two.  The native helper rebuild, WAV and FLAC matrices, all four short and faded 44.1 and 48 kHz Program Stream and MP3 profiles, and focused PCM/non-audio S/PDIF routing simulations pass without changing their source.  No Quartus result, RBF or installation is claimed yet.

#### Next Steps:

Pull exact published source `736f64f` into a new isolated checkout and perform one clean Quartus 17.0.2 flow plus the focused timing report, requiring a successful fit, positive timing and resource comparison against both the 32,355-ALM baseline and the failed near-final report.  Record that build in a new entry rather than appending to this settled source entry.  Do not reuse the stale shared build database, open production admission, begin field DCT or install any helper or RBF during this cycle.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/run_b_field_motion.sh
- tools/streams/run_interlaced_field_motion.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 700 COMMIT Unreleased c2097e3 2026-08-29T02:45:24-07:00

#### Coming From:

Unreleased c39ebdc

#### Purpose:

Route decoded stereo PCM to the selected S/PDIF output while preserving IEC 61937 AC-3 and DTS passthrough as non-audio.

#### Outcome:

The accepted standalone formats were silent under the S/PDIF menu choice because the framework treated output selection and the IEC 60958 non-audio bit as the same state, sending raw words and marking every selected S/PDIF stream non-audio.  Source `c2097e3` reserves transport mode bit seven for IEC 61937 records, has only the helper's compressed-burst writer set it, preserves it through the in-band extractor, and separates `spdif_enable` from `spdif_non_audio` in the framework.  Selected decoded MP3, WAV, FLAC and Program Stream audio now use processed stereo PCM with ordinary audio channel status, while AC-3 and DTS passthrough retain raw byte-exact bursts and non-audio status; HDMI remains the alternate exclusive output and Main needs no code change.  Native and exact-checkout helper matrices pass, focused extractor and router simulations cover all four output states, decoded WAV, MP3 and FLAC carry no non-audio flag, and all 375 AC-3 plus 1,125 DTS bursts carry it and remain byte-identical.  The exact static ARM helper is 629,056 bytes with SHA-256 `02d1df98c62ee00169585db990b6bd48c3769eca20c3e1d594f2318c362eb00f`.  No Quartus build or installation occurred, so the helper is intentionally retained rather than installed without its matching FPGA image.

#### Next Steps:

Carry this correction unchanged through entry 701's clean FPGA build, then require a matched helper and RBF installation under separate authorization and physical MP3, WAV and FLAC listening over S/PDIF while preserving HDMI PCM and AC-3 and DTS receiver lock.

#### Files Modified:

- CHANGELOG.md
- MediaPlayer_top_00.svh
- README.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- sys/audio_out.sv
- sys/emu_ports.vh
- sys/sys_top.v
- tools/streams/analyze_arm_av_transport.py
- tools/streams/run_audio_output_routing.sh
- tools/streams/strip_inband_pcm.py
- tools/streams/tb_audio_spdif_route.sv
- tools/streams/tb_h262_inband_metadata.sv
- tools/streams/verify_ac3_passthrough.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_flac.py
- tools/streams/verify_consumer_wav.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 699 COMMIT Unreleased c39ebdc 2026-08-29T02:45:23-07:00

#### Coming From:

Unreleased 1ee2b93

#### Purpose:

Add FLAC as a separately built and hardware-tested consumer format through the existing helper-only PCM path.

#### Outcome:

Source `c39ebdc` enables the pinned miniaudio 0.11.25 native FLAC decoder inside the single static helper and adds case-insensitive `.flac` selection to Main without a runtime FFmpeg dependency or FPGA change.  The helper accepts ordinary 16- and 24-bit mono, stereo and multichannel files, converts them to signed 16-bit stereo at 44.1 or 48 kHz through the established audio-only transport, and preserves one clean end token.  Format, sanitizer, Main-loader, MP2, MP3, WAV, AC-3 and DTS regressions pass.  The exact 629,056-byte static ARM helper and patched Main were transactionally installed with backups and hash readback, and the user played the selected FLAC sample on hardware and reported that it ran perfectly.  The later S/PDIF silence reproduced after a complete zero-error FLAC decode and belongs to the shared routing defect recorded by entry 700, not the codec.

#### Next Steps:

Keep FLAC accepted and preserve it through the interlaced recovery and S/PDIF build; Ogg Vorbis and M4A with AAC-LC remain later independent consumer-format cycles.

#### Files Modified:

- CHANGELOG.md
- README.md
- host/arm/ARCHITECTURE.md
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_flac.py

#### Status:

- [x] Built
- [x] Passed

---

## 698 COMMIT Unreleased 1ee2b93 2026-08-29T02:45:22-07:00

#### Coming From:

Unreleased 60159bd

#### Purpose:

Add ordinary WAV playback as a separately built and hardware-tested consumer format through the existing helper-only PCM path.

#### Outcome:

Sources `a335de1` and `1ee2b93` pin miniaudio 0.11.25, compile only its WAV decoder and conversion support into the static helper, and add case-insensitive `.wav` selection to Main without a runtime FFmpeg dependency or FPGA change.  Ordinary integer and float mono, stereo and multichannel WAV files are converted to signed 16-bit stereo at 44.1 or 48 kHz through the established audio-only transport.  Native format, sanitizer, Main-loader, MP2, MP3, AC-3 and DTS regressions pass, including byte-exact direct signed-16 decode.  The exact static helper and patched Main were transactionally installed with verified backups, and the user played both the selected WAV sample and its MP3 derivative on hardware and reported that they sounded perfect.

#### Next Steps:

Keep WAV and MP3 accepted and preserve both paths through later format and FPGA work.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/consumer_audio.c
- host/arm/consumer_audio.h
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_consumer_wav.py

#### Status:

- [x] Built
- [x] Passed

---

## 697 COMMIT Unreleased 60159bd 2026-08-29T02:45:21-07:00

#### Coming From:

Unreleased 784ae0b

#### Purpose:

Add basic standalone MP3 playback through the existing MediaPlayer picker and PCM transport without changing the FPGA.

#### Outcome:

Sources `c1d7da7`, `2445324` and `60159bd` compile pinned minimp3 directly into the static helper, add case-insensitive `.mp3` selection to Main and decode MPEG-1 Layer III mono or stereo at 44.1 or 48 kHz into the existing signed stereo PCM records with one clean end token and no video requirement.  The implementation bounds ID3 metadata handling, rejects unsupported rates and malformed or renamed input, preserves byte-identical video and accepted MP2, AC-3 and DTS behavior, and passes the native codec, transport and sanitized Main-loader matrices.  The exact static helper and patched Main were installed transactionally with verified backups; after the WAV cycle the user played the selected MP3 derivative on hardware and reported that it sounded perfect, and the retained session shows all 263,808 stereo frames, helper exit zero and normal completion.

#### Next Steps:

Keep MP3 accepted and preserve its helper and Main behavior through later format and FPGA work.

#### Files Modified:

- README.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/generate_arm_av_test.py
- tools/streams/test_main_mister_profile.py
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [x] Passed

---

## 696 COMMIT Unreleased 784ae0b 2026-08-29T02:34:10-07:00

#### Coming From:

Unreleased 784ae0b

#### Purpose:

Record that the entry 695 tree does not fit the device.

#### Outcome:

A full Quartus compilation of `784ae0b` failed after forty-eight minutes with `Error (11802): Can't fit design in device`.  Logic utilization reached 39,702 ALMs of 41,910, ninety-five percent, against the 32,355 and seventy-seven percent this cycle started from, with registers at 55,017 against 48,619 and RAM blocks at 532 of 553.  The field prediction work therefore costs roughly 7,350 ALMs and 6,400 registers, a twenty-three percent increase in logic, and the design no longer fits.  The long fit was the symptom: placement on a device this full runs far past the thirty minutes a healthy build of this project has always taken, and that signal was correctly identified by the user and wrongly dismissed during the cycle on the strength of a synthesis RAM-segment count that grew only four and a half percent, which is not a proxy for logic.  Two costs dominate and both are structural rather than incidental.  The prediction fetcher's retained word store doubled from thirty-six to seventy-two words of sixty-four bits on each of the two B engine instances, which is roughly nine thousand bits of randomly indexed storage that cannot infer as block memory.  Each engine also now computes four complete phase footprints in parallel, every one carrying its own base address through the shift-add row multiply in `pixel_addr`, its own word span and its own bounds comparison, where frame prediction computed one or two.  Neither cost is required by the standard; both follow from choosing to widen the fetcher rather than reuse the second instance, and from computing all four footprints combinationally rather than sequencing them.  Simulation correctness is unaffected and remains proven: the P fixture, the B fixture and the mixed raster control all reconstruct exactly.

#### Next Steps:

Reduce logic before anything else in this cycle proceeds, because `dct_type` and the admission gates will only add more.  The first lever is the one rejected when the fetcher was widened: give the B engine its four rectangles by reusing the second fetcher instance, which exists as a prefetch double buffer, instead of doubling the retained store on both instances.  A field macroblock already forgoes prefetch, so that instance is idle exactly when the extra phases are needed, and this reclaims the larger of the two costs without changing the phase indexing the engines now use.  The second lever is to stop computing four phase footprints at once.  Only the phase being fetched and the phase being looked up are ever live, so the base address, word span and bounds can be selected from the slot and direction first and computed once, which removes three of every four `pixel_addr` multiplies and bounds comparisons in both engines.  Measure each lever with a fit rather than by synthesis estimates, since this cycle demonstrated that synthesis counts do not predict logic utilization.  Do not attempt hardware until the design fits with margin; ninety-five percent is not a place to add features.  The build configuration is a separate matter worth measuring once the design fits: the project sets maximum fitter effort, high performance optimization mode and five physical synthesis passes including register retiming, and a compile long enough to exceed the engineering it validates is not a workable iteration loop, but reducing effort must be measured against the 0.170 nanosecond slack rather than assumed safe.

#### Files Modified:

- None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 695 COMMIT Unreleased 784ae0b 2026-08-29T02:25:48-07:00

#### Coming From:

Unreleased f2c10be

#### Purpose:

Admit interlaced NTSC P and B frame pictures by adding field motion prediction and residual field DCT.

#### Outcome:

This cycle admits interlaced NTSC P and B frame pictures by adding field motion prediction.  It passes analysis and synthesis and every simulation regression, but no bitstream exists yet, so it is neither built nor hardware validated.  The plan it started from understated the work in two ways that the cycle corrected.  There are two macroblock parsers, not one: B pictures parse in `mpeg2_h262_b_core_probe` and P pictures in `mpeg2_h262_p_wide_motion_syntax_probe`, selected by `b_transport` in `mpeg2_h262_two_picture_probe_p_chain.sv`, and only the B one had been touched.  The prediction fetcher held two source rectangles where a bidirectional field macroblock needs four, one forward and one backward field per destination field.  Both are now resolved: the P parser gained the field syntax, the record channel carries the field selects, the fetcher takes a PHASES parameter and the B engine raises it to four, and both engines form field predictions by indexing a phase per destination parity with the row stride doubled so a fetched row steps one field line.  A field macroblock does not prefetch its successor, which costs throughput on those blocks and avoids four more address sets.  Dual prime and the reserved motion type are refused as implementation limits of this decoder rather than limits of the standard, and field pictures remain outside the cycle.  Measurement drove all of it.  Two deterministic fixtures were built with pixel oracles the generators prove byte-identical to FFmpeg's decode of their own bitstreams, and the gates were opened locally, never in a commit, so each change was measured as it landed rather than at the end.  The P fixture went from 1,594 mismatching samples to 0 of 518,400 and the B fixture from 1,110 to 0 of 1,036,800, with the mixed raster control holding at 0 of 423,936 throughout.  That loop found four defects in the cycle's earlier work, every one of them in a commit whose message asserted behaviour was unchanged: the vertical motion predictors were renamed to a frame-unit pair while two readers and all four slice-start resets kept pointing at the dead names, so skipped B macroblocks were predicted with vertical motion zero and H.262 7.6.3.1's slice reset was silently lost; `S_MOTION_TYPE`, `S_FSEL` and `S_BSEL` never advanced the bit pointer, so `frame_motion_type` decoded as 00 or 11 and every field-predicted B macroblock failed at the first one; the P engine read slot 0's field select from a register nothing ever assigned, and its picture-start capture hardwired the field bits to zero; and emitting the second motion record ahead of the committing one raced the engine's capture arming, losing that record on the first macroblock of every picture.  The mixed raster pixel regression had been failing since `4bd6869` and nobody had run it.  A full Quartus compilation was started from this tree and had not finished after forty minutes in Fitter placement, so fit and timing are unmeasured for this cycle and no bitstream exists; the run showed no capacity errors and no critical warnings, and synthesis RAM segments grew only from 1,659 to 1,733 across the two engine walks.  Build time is itself now a project constraint: the project fits at maximum effort with high performance optimization mode and five physical synthesis passes including register retiming, on a device already at seventy-seven percent ALMs and ninety-three percent RAM blocks with 0.170 nanoseconds of slack, and a compile of that length is not a workable iteration loop.  Measure a reduced-effort build against slack before the next cycle rather than assuming either that the settings are needed or that they are free.  Analysis and synthesis pass with 0 errors.

#### Next Steps:

Three pieces of this cycle remain before hardware.  The macroblock `dct_type` bit is parsed only by the intra path in `mpeg2_h262_luma4_probe.sv`; neither the P wide probe nor the B parser reads it, no sideband carries it, the residual destination for luma blocks 2 and 3 still uses the frame offset of eight rather than the field offset of one, and both `MediaPlayer_top_03.svh` and the soak testbench wire the store's `field_dct` input as `!p_store_select && dct_type`, which forces it low whenever the prediction path owns the store.  The store itself already handles field DCT correctly, doubling the luma stride and applying it to luma only, so no address arithmetic needs inventing.  Neither existing fixture can test it, because both deliberately code no residual blocks to isolate prediction, so a third fixture carrying field DCT together with coded residual on inter macroblocks is a prerequisite, along with field-DCT block ordering in the reference model.  Then open the gates for real: `wide_candidate` and `wide_unsupported_now` in the P probe each carry their own copy of the `frame_pred_frame_dct` requirement and both must be relaxed together, `b_candidate` in the B parser carries a third, and the frontend admission gate still admits I pictures only.  Note that neither field fixture can exercise the frontend gate, because both are 30000/1001 sequences whose picture-level admission is what changes; validating that needs real interlaced disc content.  Finally fold in the two entry 694 instrumentation defects while the profiler is being rebuilt: probe the transport block at the clean video queue's own full condition rather than a valid and ready pair, and move the snapshot trigger off the first error flag now that underruns are counted.  Install only after separate user authorization with the accepted bitstream backed up.  Watch for video stutter, since the clean video queue is half its former depth and interlaced P and B raise decoder load.  A parallel agent is adding MP3, WAV and FLAC playback to the ARM helper under `host/arm/` on the same branch; that work does not touch `rtl/` and is integrated after this cycle is hardware validated.  The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_p_diagnostic_controller_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv
- tools/streams/h262common.py
- tools/streams/generate_test_interlaced_field_motion.py
- tools/streams/generate_test_b_field_motion.py
- tools/streams/tb_h262_interlaced_field_motion_pixels.sv
- tools/streams/tb_h262_b_field_motion_pixels.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/run_interlaced_field_motion.sh
- tools/streams/run_b_field_motion.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 694 COMMIT Unreleased f2c10be 2026-08-28T22:21:11-07:00

#### Coming From:

Unreleased 100072a

#### Purpose:

Scale the helper PCM reserve with the doubled sink FIFO after the entry 693 build starved audio once at startup.

#### Outcome:

The entry 693 bitstream removed the eighty-four second starvation but underran once at approximately 1.7 seconds, with forty-two pictures already displayed, so the startup video burst had not wedged the extractor and the audio cushion was the weak point. The reserve is half the sink FIFO by construction; doubling the FIFO to 16,384 frames while leaving the reserve at 4,096 left audio with the old eighty-five millisecond cushion exactly as the halved clean video queue made transport blocks more frequent. This commit takes the reserve and the initial release to 8,192 frames, keeping reserve plus one batch below the sink FIFO, and corrects the stale documented sink depth. The first attempt aborted playback on the build PC with a video lookahead limit exceeded at 524,288 bytes and exit status one, because a deeper reserve makes the scheduler read further ahead for audio and hold more video meanwhile, so the lookahead bound moves to two mebibytes, negligible against 492 mebibytes of host memory and still a runaway guard. Equivalence is proven before installation: video, PCM and PTS payloads are byte-identical to the previous helper in both output modes, at 10,334,172 video bytes and 2,304,000 PCM bytes, with only delivery order changed, and all four helper audio profiles and the AC-3 passthrough verification pass. The helper installed as `ed13bc9357bff0a5e28bcfa703badb1614a6220cb29a51c4886316067f201a35` during playback without disturbing it, since the helper is executed per playback. A full nineteen minute hardware run then completed with all 1,126,974,123 transport bytes submitted, 867 reports, the helper never behind and its lead between 1.15 and 1.89 seconds. The startup underrun is gone, confirming the inference this commit rests on. The user reports the entire movie, including a continuous intro song, looked and sounded perfect. Hardware counted exactly one audio underrun, at STC 521 seconds, which the user did not hear and which the helper log shows no disturbance around, so it is transient and downstream of the host. Against four consecutive runs that starved at eighty-three to eighty-five seconds with audible recurring dropouts, this is accepted.

#### Next Steps:

Two instrumentation defects from entry 693 remain and should ride along with the next FPGA build rather than justify one alone. The transport block counters read zero blocks and zero milliseconds across the whole run while an underrun demonstrably occurred, because the probe used a conventional valid-and-ready pair on a path whose decoder advances on stream_valid itself, so the longest blocked interval was never actually measured and should instead be probed at the clean video queue's own full condition. The snapshot still latches on the first error flag, so it froze at 521 seconds and the last ten minutes of the run are unmeasured; now that underruns are counted, the trigger should move to the terminal or quiet path. Until both are fixed the remaining single underrun cannot be sized, so do not attempt to tune it further. Watch for video stutter on material heavier than this title, since the clean video queue is half its former depth, and revisit the trade rather than defend it if stutter appears. The HDMI session of the bounded opening remains outstanding from entry 690.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [x] Passed

---

## 693 COMMIT Unreleased 100072a 2026-08-28T21:13:29-07:00

#### Coming From:

Unreleased 9956c8e

#### Purpose:

Rebalance audio and video buffering within the existing memory budget and count the blocked intervals, in one build.

#### Outcome:

This entry is the approved plan for the cycle and its commit does not exist yet; it replaces an earlier measurement-only plan for the same number, which the user declined because the FPGA is timing sensitive and repeated builds and reseeds are themselves a risk. Entry 692 exonerated the helper and located the fault at the single gate on the shared transport byte path, where input_ready requires stream_ready, so a full clean video queue halts the byte path and every PCM record behind the held video byte halts with it. The current fit constrains the correction: RAM blocks stand at 512 of 553, ninety-three percent, with logic at seventy-four percent and memory bits at seventy-one, so RAM blocks and not logic are the binding resource. From the configured geometry the audio FIFO of 8,192 words by thirty-five bits occupies thirty-two M10K blocks at 256 words each, and the clean video queue of 65,536 words by eight bits occupies sixty-four blocks at 1,024 words each. Doubling the audio FIFO outright would add thirty-two blocks and reach ninety-eight percent, which is rejected as reckless on a sensitive design. This cycle instead trades one for the other at zero net cost, halving the clean video queue to 32,768 bytes to free thirty-two blocks and doubling the audio FIFO to 16,384 frames to spend them, leaving the block count unchanged. The trade is justified by rate rather than preference: buffering audio costs 1.68 megabits per second against 7.12 for video, so audio is roughly four times cheaper per unit of protection time, and surrendering thirty-seven milliseconds of video slack buys one hundred seventy milliseconds of audio, raising the audio budget from one hundred seventy to three hundred forty-one milliseconds. The same build adds free-running profiler counters for the longest continuous blocked interval, the number of blocked intervals and the minimum audio FIFO level, and replaces the first-error snapshot latch with a counted underrun record so one run reports every occurrence instead of only the first, with the screenshot decoder extended to match. This reverses the standing guidance against widening buffers, which was correct while the helper was suspect and would have masked a helper defect, but the helper is now exonerated by its own measurement, the requirement is genuinely buffering, and this is a rebalance rather than a net enlargement. The known risk is that a shorter video queue makes the extractor block sooner and more often, which is harmless only if audio now survives each block, and the new counters are what will show whether it did.

#### Next Steps:

The build compiled once with no reseed and closed timing: worst setup slack improved to 0.170 nanoseconds against the 0.126 baseline on the HDMI PLL domain, clk_mpeg2 gave up margin to 1.035 nanoseconds and every TNS is zero, with ALMs at 32,355 of 41,910 and RAM blocks at 517 of 553 rather than the predicted 512, so the trade cost five blocks instead of being free. The RBF installed with the accepted bitstream backed up and verified, and a core reload proved necessary before the FPGA ran it, which one capture initially missed because the file on the card had been updated while the running configuration had not; the schema version in the snapshot is the reliable check and should be read first in every future capture. The eighty-four second starvation did not recur. A startup underrun at approximately 1.7 seconds appeared instead and is corrected in entry 694, where the full hardware result is recorded. The decoder gate for schema 20 is fixed separately in `55f2595`, which also restores correct picture counts for this schema.

#### Files Modified:

- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py

#### Status:

- [x] Built
- [x] Passed

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
