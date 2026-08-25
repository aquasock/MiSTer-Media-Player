## 498 COMMIT Unreleased baf5d2c 2026-08-25T01:54:16-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Reproduce, validate and install the deferred bottom-field-first light-motion fixture without changing the accepted FPGA image.

#### Outcome:

The user approved entry 497's recommendation to skip the no-longer-required moving final-mux pattern and advance to BFF hardware qualification. Two independent invocations of `generate_test_interlaced_i_frames.py --light-visual-seconds 10` reproduce every generated artifact and the complete manifest byte-for-byte. The BFF light-motion fixture contains 300 all-I 720x480 pictures at 30000/1001, is 5,007,154 bytes with encoded SHA-256 `b26d0d4090ec8c39346782918e97eb0721ba0da5670b42ef14435e385f822271`, decodes to YUV420p SHA-256 `554fbf879319392629bb1d3ac7a041358929e0ee2e8fed6a7a05862f9efa65eb`, preserves bottom-field-first `bb` signalling in all pictures and remains decoded-plane-identical before and after the signalling patch. The analyzer retains the intentional interlaced all-I candidate classification and the public compatibility checker deliberately fails because native interlaced support is not publicly enabled. No source or RBF build was needed. The active `/media/fat/MediaPlayer.rbf` was independently retrieved at the exact accepted `2601573` SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. Only the BFF media file was uploaded under a temporary name through ordinary FTP with the default `root` and `1` login and no SSH, retrieved at the local hash, promoted as `/media/fat/_cadence/native_480i_bff_light_10s.m2v`, retrieved again at the same hash and left with no staging file. Helper, Main and existing media files were not changed.

#### Next Steps:

Leave `Native timing pattern` Off, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_bff_light_10s.m2v`. Judge whether the bar continues moving smoothly to the right without field-order reversal, backstep or alternating-field judder, whether the upper and lower field markers remain orderly, and report flicker, combing, horizontal dashes or any other artifact separately from the already classified display-history ghost. Report USER, DISK and POWER after completion and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Acceptance requires all 300 pictures and 299 swaps, stable bottom-field-first telemetry, sequence end and presentation completion, zero aggregate, presentation, destination and cache-bank-overlap errors and a decoder-limited duration comparable to the accepted TFF light-motion run. Keep the public native-interlace compatibility claim disabled until this BFF result is captured; address the independent approximately 25-picture-per-second all-I throughput ceiling afterward.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 497 COMMIT Unreleased baf5d2c 2026-08-25T01:49:06-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Use the user's high-frame-rate recording to classify the step-hold ghost before spending a Quartus cycle on the proposed moving framebuffer-bypass pattern.

#### Outcome:

The user supplied `.ai/current_results/PXL_20260825_084158381.mp4`, a 68,665,532-byte, 16.631233-second 1920x1080 H.264 Pixel 8 Pro recording at an average 59.706937 frames per second and SHA-256 `d2a4d296d8dd9f86ee6cacc341992b144722b741be35b46606d441a199782386`. Frame-by-frame review confirms the naked-eye report and materially changes the diagnosis. At a representative jump, the old bar is absent before the transition, becomes visible alongside the immediately present new bar, then alternates between bright, dim and field-striped appearances before fading away over roughly nine captured 30-fps samples; during the same interval the new bar alternates between complete and field-striped appearances and then stabilizes. The two stationary horizontal references remain stable throughout. That gradual, intensity-weighted temporal decay and alternating reconstruction is characteristic of downstream field-history processing by the display scaler or deinterlacer, potentially compounded by the phone's own temporal video processing, rather than binary stale DDR or line-cache pixels. The user's direct visual observation establishes that the effect exists before the camera, while the recording exposes its temporal structure. Combined with the pair-identical decoded source, zero old-position source pixels, clean cache and destination telemetry, a clean terminal framebuffer and the static framebuffer-bypass result, this is strong enough to clear framebuffer corruption as the working diagnosis and supersedes entry 496's need to modify cache RTL. It is not a mathematical replacement for a moving final-mux bypass, but that build is now confirmation rather than a prerequisite.

#### Next Steps:

Stop and obtain approval to supersede entry 496's moving-bypass build. If approved, make no RTL or RBF change for this ghost and treat it as downstream interlace reconstruction on the present display; optionally confirm later with deinterlacing disabled, a game mode, a different native-480i display or the moving final-mux pattern if a public compatibility claim requires formal isolation. Advance the core qualification instead to the already deferred bottom-field-first hardware case: regenerate and validate the established BFF light-motion fixture byte-identically, install only that media file through staged ordinary FTP with the default MiSTer login, then run it in native 480i and capture field order, motion, LEDs and schema-nine telemetry before addressing the independent approximately 25-picture-per-second all-I throughput ceiling. Keep the public native-interlace compatibility claim disabled until BFF passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 496 COMMIT Unreleased baf5d2c 2026-08-25T01:38:31-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Record the pair-identical TFF step-hold hardware result and separate framebuffer persistence from downstream motion-adaptive interlace processing before changing cache RTL.

#### Outcome:

The user ran only `_cadence/native_480i_tff_step_hold_10s.m2v` with `Native timing pattern` Off and native 480i active. There is no flicker, combing, horizontal dashes or other steady-state artifact, and the picture looks excellent. At each discrete bar jump, however, the old position remains slightly visible for approximately half a second while the new position initially appears to be missing alternating scan lines; the new bar then becomes complete and the old position disappears fully. Playback completes and all three LED indications pass. The untouched terminal frame was captured entirely through ordinary FTP with the default MiSTer login and no SSH. `.ai/current_results/entry495_tff_step_hold.png` is 7,689 bytes with SHA-256 `37d7e8687b28b258a1b1d4e996609bb5c49f98235e72967e9e2d1f00fbde84fc`; it shows one complete current bar and no old-position residue after stabilization.

Schema nine accepts all 3,483,304 bytes, reconstructs all 300 reference and displayed pictures and 299 swaps from the wrapped counters, preserves top-field-first, reaches sequence end and presentation completion and closes normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear, and no destination holds occur. The first presentation at cycle 2,332,280 and last at cycle 706,661,049 span 704,328,769 cycles, or 11.738813 seconds and 25.471060 pictures per second. The terminal still and telemetry therefore show that the transient resolves rather than accumulating into a corrupt frame.

The fixture makes two conclusions firm. Its decoded validator proves both authored fields are identical, the current position is complete in adjacent field rows, every prior non-current position is background after a jump and the maximum adjacent-field row delta is zero; therefore neither an encoded old bar nor ordinary one-field temporal separation can last half a second. The static video-domain pattern previously proved decode and DDR traffic do not perturb native sync or the final mux. But the earlier plan's statement that persistence would by itself prove stale framebuffer content was too strong: a downstream television, scaler or capture device doing motion-adaptive deinterlacing can also retain several prior fields after a discontinuous motion step and can temporarily reconstruct only alternating lines at the new position. Because the prior bypass pattern was static, it could not distinguish that external temporal processing from the framebuffer and line caches. The clear cache-bank-overlap flag excludes only a refill into the line-cache bank currently being scanned and does not settle the broader framebuffer case.

#### Next Steps:

Stop before changing framebuffer or cache RTL and obtain approval for one moving video-domain discriminator. Extend `Native timing pattern` from Off/Static to Off/Static bars/Step-hold, with the new mode generating the same narrow field-invariant bar directly after the framebuffer, holding each position for thirty complete output frames and jumping ninety-six pixels while MPEG decode and DDR traffic continue underneath. Regress exact native timing, pair-identical fields, hold length, jump positions and unchanged static-pattern behavior, then build and install one RBF through the established staged ordinary-FTP process. Replay the same TFF file with the video-domain Step-hold mode enabled. If the approximately half-second ghost and incomplete new lines repeat, the artifact is downstream display processing and the FPGA pixel path is cleared; if the bypass bar changes cleanly while the decoded bar does not, the fault is inside framebuffer publication or line-cache generation and the following RTL cycle should instrument current display-bank identity and per-line cache generation. Continue to defer BFF, throughput optimization and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 495 COMMIT Unreleased baf5d2c 2026-08-25T01:30:20-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Create and install the pair-identical step-hold TFF fixture that distinguishes stale framebuffer pixels from authored temporal interlace and downstream display persistence.

#### Outcome:

Commit `baf5d2c` adds `--step-hold-visual-seconds` to the deterministic interlaced all-I generator without changing its established default, sustained-motion or low-complexity-motion outputs. The new source authors an eight-pixel bright bar identically in both fields, holds each position for sixty 60000/1001 source fields or thirty 30000/1001 output pictures, then jumps ninety-six pixels; two stationary horizontal references remain while alternating field markers are deliberately absent. A permanent decoded-plane validator checks every frame, proves the current bar bright in both adjacent field rows, checks every previous non-current position remains background after each jump and records zero maximum difference between representative adjacent field rows. Independent generations reproduce byte-identical TFF and BFF outputs, retain the exact four-picture baseline hashes, preserve patched-versus-unpatched decoded-plane equality, contain 300 all-I pictures with the intended field order and remain deliberately rejected by the public compatibility checker. The 3,483,304-byte TFF fixture is SHA-256 `71f00b8f8c919857fe8c92bec9f0dfd440493650573ef0ae4bc0ac4b7754f4df`; its decoded YUV420 plane hash is `cf629eaefc50ffb89d83450332cd312828390bcdc94454d45e823139edfe8544`, and nine decoded jumps contain no prior-position residue. Its byte-identical regeneration was uploaded under a staging name and retrieved at the local hash, promoted as `/media/fat/_cadence/native_480i_tff_step_hold_10s.m2v`, retrieved again at the same hash and only then had the stage removed, entirely through ordinary FTP with the default MiSTer login and no SSH. The BFF counterpart remains local and deferred. The installed RBF was independently retrieved unchanged at the exact `2601573` hash `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`; helper and Main were not touched.

#### Next Steps:

Turn `Native timing pattern` Off, keep `Interlaced output` at `Native 480i` and run only `_cadence/native_480i_tff_step_hold_10s.m2v`. The narrow white bar should remain fixed for about one authored second and then jump ninety-six pixels nine times; after each jump judge whether the old position disappears immediately or within one field or frame, or remains visibly stuck for a material fraction of the next hold, and note any comb, flicker or horizontal dashes. Report USER, DISK and POWER and leave the final image loaded for an FTP-only schema-nine capture. Immediate clean disappearance places the earlier continuous-motion shadow in ordinary interlaced temporal presentation or downstream display processing, while persistence into the hold proves stale framebuffer, cache or frame-bank content and requires a targeted field/cache identity RTL diagnostic. Continue to defer BFF, throughput optimization and any public native-interlace compatibility claim.

#### Files Modified:

- tools/streams/generate_test_interlaced_i_frames.py

#### Status:

- [x] Built
- [ ] Passed

---
## 494 COMMIT Unreleased 2601573 2026-08-25T01:26:01-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Record the native timing-pattern hardware discriminator and relocate the remaining motion artifacts to framebuffer or field-content presentation.

#### Outcome:

The user enabled `Native timing pattern`, kept native 480i active and replayed `_cadence/native_480i_tff_light_10s.m2v`; the eight static vertical bars remained absolutely unchanged throughout playback and looked as if no file had been launched, while USER and POWER stayed solid and DISK blinked twice. The untouched terminal pattern was captured entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry493_native_timing_pattern.png` is 7,336 bytes with SHA-256 `8a34c6f8bd0de81cc8f6bd9f02a165626e7a629c547f7d294f26da16140a61da`. The image shows eight clean full-height bars with stable vertical boundaries and no short horizontal dashes or changing ghost edge. Schema nine proves the apparently static view concealed a complete active decode: all 5,007,304 bytes were accepted, the wrapped counters represent 300 reference and displayed pictures and 299 swaps, top-field-first stayed stable, sequence end and presentation completion occurred and the snapshot closed normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. The 299 presentation intervals span 716,738,843 cycles from cycle 2,378,246 to 719,117,089, or 11.945647 seconds and 25.030037 pictures per second, materially identical to the normal-video run's 25.044486 pictures per second. Decoder and DDRAM traffic therefore continued without perturbing the video-domain pattern, decisively excluding the native sync clock, field cadence and final output mux as the cause of playback-induced flicker, transient dashes or moving ghost content. Earlier progressive and native terminal stills also show the same completed 32-pixel-wide authored bar with bright interior and combed boundaries, so a still cannot distinguish the user's live persistence report from normal temporal field separation; the remaining diagnostic boundary is dynamic framebuffer and field-content presentation, while the independent approximately 25-picture decoder ceiling remains below the 29.97-picture source.

#### Next Steps:

Stop before changing RTL and obtain approval for one content-only framebuffer discriminator. Extend the deterministic interlaced generator with a narrow bar whose two authored fields are identical and whose position holds for approximately one second before a large discrete step, then generate and upload only the TFF fixture through ordinary FTP without changing the accepted RBF. Long static holds remove continuous-motion and bar-width ambiguity: if the old position disappears within the next field or frame and each held position is clean, the original comb and apparent shadow are authored temporal interlace or downstream display processing; if the old position persists materially into the hold, the framebuffer cache or frame-bank handoff is retaining stale pixels and the next RTL cycle should instrument field and cache identity. Keep `Native timing pattern` Off for that fixture, continue to defer BFF and do not make a public native-interlace compatibility claim. Treat the separate 25-picture-per-second decoder throughput ceiling as a later optimization rather than mixing it into this artifact discriminator.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 493 COMMIT Unreleased 2601573 2026-08-25T01:20:24-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Record the three-bank native TFF hardware result and advance to the framebuffer-independent timing-pattern discriminator.

#### Outcome:

The user reloaded the exact `2601573` image, left `Native timing pattern` Off and ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode. Playback feels faster but still lags the nominal source, flicker is reduced but remains, the transient one-pixel-high short dashes are gone, combing remains and the moving vertical bar can leave a temporarily stationary shadow while it continues rightward. USER and POWER are solid and DISK blinks twice. The untouched terminal screenshot was triggered and retrieved entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry492_tff_native480i_overlap.png` is 11,867 bytes with SHA-256 `2d8a9ae24dc9d5ffc7d38d1707a197694c29f239a808c18bcb3e3d4a58985d84`. Schema nine accepts all 5,007,304 bytes and its wrapped counters represent all 300 reference and displayed pictures and 299 swaps, with stable top-field-first signalling, sequence end, presentation completion and normal quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. The first presentation is at cycle 2,378,291 and the last at 718,703,629, so the 299 intervals span 716,325,338 cycles, 11.938756 seconds or 25.044486 pictures per second. The overlap therefore removes the prior deterministic 15.004885-picture serialization and exceeds the predicted approximately 20.10-picture baseline because that earlier progressive measurement also included ordinary presentation waiting; the remaining approximately 40-millisecond decoder throughput is still below the 29.97-picture source and explains the residual lag. Presentation hold collapses from the prior run's hundreds of millions of cycles to 108,513 cycles, while the disappearance of the short dashes and reduced flicker show that their severity was coupled to the old stop-and-resume schedule even though the clear cache-overlap flag still rules out only the monitored same-bank refill collision. The still preserves the authored interlaced edge structure but cannot determine whether the reported temporary moving shadow is an intended field-time separation or stale pixel delivery; the static timing pattern is now the required discriminator.

#### Next Steps:

Without changing the RBF, enable `Native timing pattern`, keep `Interlaced output` at `Native 480i` and replay only `_cadence/native_480i_tff_light_10s.m2v`. The moving source will be hidden behind eight static vertical color bars while decoder and DDRAM activity continue, so judge whether the bars flicker, acquire transient horizontal dashes, shimmer at their vertical boundaries or leave any changing ghost edge; report USER, DISK and POWER and leave the terminal pattern image loaded for a second FTP-only capture. Stable bars with ordinary telemetry will place the remaining comb and moving shadow in framebuffer or field-content presentation rather than native sync timing, while flickering or changing bars will retain the timing/output path as the cause. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 492 COMMIT Unreleased 2601573 2026-08-25T01:09:18-07:00

#### Coming From:

Unreleased f6f2fe4

#### Purpose:

Remove the avoidable native all-I decode/presentation serialization and add a framebuffer-independent native timing pattern for the remaining flicker and short-line isolation.

#### Outcome:

Commit `2601573` implements the approved bounded native correction and diagnostic. The presentation scheduler permits exactly one native, untimestamped, frame-rate-code-four I picture to decode into the existing third ordinary frame region while its released predecessor waits for a complete-frame native swap boundary. Admission requires the decode bank to differ from both the visible and pending banks, retains the completed-bank identity for the whole transaction, rejects any destination change into the visible bank, rejects completion before the predecessor presents and leaves timestamped, progressive, P, B and scratch-frame behavior on the established serialized paths. A measured-latency integration regression models the hardware's approximately 50-millisecond all-I decode time across twenty real native frame windows: the old path reproduces ten decoded and ten displayed pictures, or approximately 15 fps, while the overlap path produces thirteen decoded and thirteen displayed pictures, or the decoder-limited approximately 20 fps, with no presentation error. Separate negative cases prove that a P header cannot enter the exception, a displayed-bank destination is fatal and premature completion cannot overwrite the pending predecessor.

The new `Native timing pattern` menu option selects eight field-invariant vertical bars only when native output is active. It replaces the final framebuffer RGB, data-enable and sync source while the decoder, DDRAM, cache refill, scheduler and cadence profiler continue running underneath, so playback with the pattern enabled distinguishes native timing/output artifacts from framebuffer and line-cache pixel delivery without changing the 480i raster. The pattern contains no horizontal one-line detail and its RTL regression proves blanking, sync passthrough, all eight bar boundaries and structural field invariance. Exact TFF and BFF timing, field order, exhaustive interlaced 4:2:0 mapping, measured presentation latency, safe/unsafe ordinary ownership, ordinary and delayed cache refill, schema-nine cadence profiling and decoding, scheduler rate codes one through five, timestamp cadence floor, dense three-bank publication, the progressive live-raster DDR soak and TFF/BFF/progressive reconstruction all pass. The legacy Cycle-A wrapper retains its established three fixed-expectation nonzero cases, while every emitted functional result remains complete and error-free.

The clean from-scratch Quartus Prime 17.0.2 build finishes in 11:07 with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.386, +0.245, +4.208, +0.566 and +0.925 nanoseconds. Focused decoder setup and recovery margins are +0.881 and +11.444 nanoseconds, and video setup is +2.076 nanoseconds, with zero violated paths. The fit uses 29,554 of 41,910 ALMs, 45,539 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks and three PLLs. The 4,195,444-byte RBF has SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. Installation used only ordinary FTP with the default `root` / `1` login and no SSH keys. The prior active 4,192,152-byte RBF was independently retrieved at SHA-256 `9f60f116d145fde30e93de7db17bfc525168db0e5781f7d167f04ee2b5c01904` and preserved byte-identically as `/media/fat/MediaPlayer.rbf.rollback-pre-2601573`. The new image was uploaded under a staging name, retrieved at its local hash, promoted, retrieved again from `/media/fat/MediaPlayer.rbf` at the same hash and only then had the temporary stage removed. Helper, Main and media files were not changed.

#### Next Steps:

Reload the Media Player core, leave `Native timing pattern` Off, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_tff_light_10s.m2v`. Observe the apparent duration, motion continuity, approximately 60 Hz flicker and transient one-pixel-high short dashes, report USER, DISK and POWER and leave the final image loaded for an FTP-only schema-nine capture. Acceptance is all 300 pictures and 299 swaps with zero aggregate and ownership errors, and a presentation span near the established approximately 14.87-second decoder-limited progressive result rather than the previous approximately 19.93-second serialized native result. After that normal-video capture, enable `Native timing pattern`, replay the same file and report whether the bars themselves flicker or acquire transient short lines; do not run that second isolation view before the normal telemetry is captured. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_native_timing_pattern.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_native_480i_presentation_integration.sv
- tools/streams/tb_native_480i_timing_pattern.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 491 COMMIT Unreleased f6f2fe4 2026-08-25T00:24:32-07:00

#### Coming From:

Unreleased f6f2fe4

#### Purpose:

Record the cadence-corrected native TFF hardware result, test the new cache-bank-overlap hypothesis and identify the remaining half-rate mechanism.

#### Outcome:

The user reloaded the exact `f6f2fe4` image, ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode and reports approximately the same speed as before, unchanged approximately 60 Hz flicker and the same quantity of transient tiny horizontal lines during playback. USER and POWER remain solid and DISK blinks twice. The untouched terminal screenshot was triggered and retrieved entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry490_tff_light_native480i_cadencefix.png` is 11,945 bytes with SHA-256 `1af6b303238d82fa3fc03840ad92c93afe0402923b100ef462a7eb0417c61d1a`. Schema nine accepts all 5,007,304 bytes, reconstructs 300 reference and displayed pictures and 299 swaps from the wrapped counters, preserves stable `top_field_first=1`, sees sequence end and presentation completion and reaches normal quiet reason one. Every aggregate, decoder, presentation, destination, cache, audio-underrun and PCM-protocol error is clear, including the new `cache_bank_overlap_error`; the tested same-bank active-scan refill collision therefore did not occur. First presentation is at 2,378,243 cycles and the last at 1,197,988,906 cycles, so the 299 intervals occupy 1,195,610,663 cycles, or 19.926844 seconds and 15.004885 pictures per second. This is materially identical to entry 489's 14.988809 pictures per second and proves the cadence-window separation did not remove the half-rate behavior. The integrated regression's immediate synthetic feeder hid the actual limiting interaction. The same fixture's progressive diagnostic baseline takes 14.874526 seconds, or approximately 49.75 milliseconds per decoded picture. Native output offers a complete-frame presentation boundary every 33.37 milliseconds, but `ordinary_reference_waiting` asserts `presentation_hold` while one decoded reference waits for that boundary. Decode therefore resumes only after presentation, completes approximately 49.75 milliseconds later, misses the immediately following native frame boundary and waits to the next one; the serial decode-plus-window quantization deterministically becomes about 66.73 milliseconds per picture, or 14.99 pictures per second. The synthetic feeder publishes a new completed frame immediately after the pending slot clears and thus proves cadence arithmetic without modeling measured decode latency or the real hold. The settled raster does not contain the transient short lines, and the clear overlap flag rules out only the specific monitored collision rather than every cache or output-path mechanism.

#### Next Steps:

With explicit user approval, replace the immediate-feeder integration case with a measured-latency ordinary-reference regression that reproduces the current approximately 15-picture-per-second native result through the real `presentation_hold` path. Then use the already implemented third ordinary DDR frame region to permit exactly one queued ordinary reference while a prior reference awaits its safe complete-frame boundary, with explicit ownership assertions preventing decode from targeting the displayed or pending bank and with all established I, P and B presentation regressions retained. The corrected measured-latency regression must approach the decoder-limited approximately 20.10-picture-per-second baseline without changing native field order or the 59.94-field raster. In the same diagnostic build, add a selectable native video-domain timing pattern that bypasses decoder DDR and line caches while preserving the exact 480i timing, so one hardware run can determine whether the flicker and transient short lines originate in the timing/output path or only during framebuffer refill. Rebuild and install only after timing closure, then rerun the TFF fixture for cadence and the bypass pattern for artifact isolation. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 490 COMMIT Unreleased f6f2fe4 2026-08-25T00:16:30-07:00

#### Coming From:

Unreleased 8d9043a

#### Purpose:

Correct native 480i frame admission to one presentation per authored frame and add a passive diagnostic for line-cache refill overlap.

#### Outcome:

Commits `6f4e1aa` and `f6f2fe4` implement and close the approved native TFF correction. Native timing now raises the cadence window at logical sample zero of the vertical-blanking tail and raises the frame-admission window one complete logical 13.5 MHz sample later, so the synchronized scheduler applies the second-field credit before testing the physical bank swap. The integrated 54 MHz timing to 60 MHz scheduler regression observes twelve fields, six frame windows and six presentations at 30000/1001 with no coincident cadence and admission pulses; the established synthetic scheduler rates remain unchanged for all five supported rate codes. The framebuffer now passively synchronizes active scan and selected Y/C cache-bank levels into the memory domain and latches a telemetry-only overlap error if a completed DDR refill writes the bank currently being scanned. The ordinary-latency live-raster test remains clear at latency 64 while the forced-delay case deterministically latches overlap at latency 3400, and the schema-nine decoder exposes the new flag. Exact TFF and BFF field timing, exhaustive interlaced cache mapping, stable field-order controls, scheduler rates, cadence profiling, telemetry decoding and fixture generation all pass. The first full compile exposed only the three intentional first-stage 54-to-60 MHz diagnostic synchronizer paths; `f6f2fe4` adds narrowly scoped timing exceptions for those destinations, leaving all second stages and functional logic timed. The exact `f6f2fe4` rebuild completes with zero errors and 144 warnings, 29,434 of 41,910 ALMs, 3,655,139 of 5,662,720 memory bits and 65 of 112 DSP blocks. Worst-case global setup, hold, recovery and removal margins are respectively 0.593, 0.243, 3.336 and 0.531 ns; the decoder and video setup margins are 1.453 and 2.848 ns. The 4,192,152-byte RBF has SHA-256 `9f60f116d145fde30e93de7db17bfc525168db0e5781f7d167f04ee2b5c01904`. It was uploaded, retrieved byte-identically under a staging name and promoted entirely through ordinary FTP with the default MiSTer login and no SSH. `/media/fat/MediaPlayer.rbf` retrieves at the exact new hash, while the known prior 4,210,740-byte image is preserved as `/media/fat/MediaPlayer.rbf.rollback-20260825T0015` at SHA-256 `5544bb48bea6d0f066b01f09f63087d46e7a52438ca60b6872b9f452ef213c09`.

#### Next Steps:

Reload the Media Player core, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_tff_light_10s.m2v`. Judge whether playback is materially closer to the progressive diagnostic duration rather than the prior approximately twenty-second half-rate native run, whether the approximately 60 Hz flicker and transient one-pixel-high short dashes are gone or changed, and whether motion and field combing remain orderly. Report USER, DISK and POWER after completion and leave the final image loaded for an FTP-only schema-nine capture. Acceptance requires approximately 20.10 displayed pictures per second for this decoder-limited fixture, all 300 pictures and 299 swaps, zero aggregate errors and a clear new cache-bank-overlap flag. Continue to defer BFF and any public native-interlace compatibility claim until this TFF result passes.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_02.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_video_output_timing.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/tb_native_480i_presentation_integration.sv
- tools/streams/tb_native_480i_timing.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [ ] Passed

---
## 489 COMMIT Unreleased 8d9043a 2026-08-24T23:35:44-07:00

#### Coming From:

Unreleased 8d9043a

#### Purpose:

Record the native TFF comparison, identify the exact half-rate native admission defect and distinguish the authored reference lines from transient cache-like playback artifacts.

#### Outcome:

The user ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode and reports that the comb-like artifacts improved relative to the progressive weave, the approximately 60 Hz flicker returned and the apparent playback rate seemed similar. USER and POWER remained solid and DISK blinked twice. The user sees two authored full-width gray reference lines, but separately observes many transient one-pixel-high, roughly fifteen-pixel-long horizontal dashes across the screen only while native playback is active; these are not the fixture's reference lines and are absent from the settled terminal still. The 720x480 screenshot was triggered and retrieved entirely through ordinary FTP using the default MiSTer login and no SSH; `.ai/current_results/entry488_tff_light_native480i.png` is 11,916 bytes with SHA-256 `74788181ac9642ef09bba56d2cd70bddf9c0895167f1d1bb9740f7812e891363`. Schema nine accepts all 5,007,304 bytes, reports 300 reference and displayed pictures and 299 swaps after modulo-counter interpretation, preserves stable `top_field_first=1`, sees sequence end and presentation completion and reaches normal quiet reason one with every aggregate, decoder, presentation, destination, cache, audio-underrun and PCM-protocol error clear. First presentation occurs at 2,378,252 cycles and the last at 1,199,271,231 cycles, so the 299 intervals occupy 1,196,892,979 cycles, or 19.948216 seconds. Native presentation therefore sustains 14.988809 pictures per second, materially slower than the same stream's 20.101481-picture progressive diagnostic baseline; the visual rate estimate does not distinguish that difference. RTL inspection identifies the exact deterministic cause. On the non-first native field, `display_field_window` and `display_frame_window` rise together and cross identically into the scheduler as simultaneous cadence and swap pulses. After a presentation, rate-code-four credit is zero; the first field adds 5,652, then the second-field swap evaluates the old 5,652 against the due threshold of 5,723 before its coincident tick is applied, misses that frame window and updates credit to 11,304. The following native frame is therefore admitted, producing one swap every four fields and the measured 14.99-picture rate. The existing native scheduler test incorrectly applies two field ticks and then a separate frame-window pulse, so it proves intended arithmetic but not actual integrated pulse ordering. The settled still shows only the authored full-width references and expected field weave; it cannot capture the transient short dashes. The line-cache error bit currently detects a reader falling more than one complete line behind but does not identify a cache bank being refilled while that same bank is still scanned, leaving a plausible refill-deadline blind spot. The unused 135 MHz PLL output cannot safely replace the current 60 MHz shared decoder/DDRAM clock without a new clock-domain boundary, so the user's historical clock observation is relevant evidence but not yet a safe direct fix.

#### Next Steps:

With explicit user approval, create one bounded native-presentation correction and diagnostic commit. Separate the native frame-window assertion from the second-field cadence assertion by a deterministic logical-sample interval inside vertical blanking, preserving the scheduler's established progressive arithmetic while ensuring the second field's credit is visible before physical bank admission. Replace the synthetic native scheduler test with an integrated timing-to-scheduler regression that reproduces the current simultaneous-pulse half-rate failure and proves one 30000/1001 presentation per two fields after correction. Add a passive sticky line-cache bank-overlap diagnostic and a native delayed-DDR live-raster stress case so the next hardware run can distinguish an actual refill collision from an output-clock symptom without changing clocks or cache depth speculatively. Rebuild and install the exact RBF, rerun only the light TFF fixture in Native 480i, require the decoder-limited rate to match the approximately 20.10-picture progressive baseline rather than 14.99, report flicker and transient dashes and leave the result for FTP-only capture. Continue to defer BFF and the public interlaced compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 488 COMMIT Unreleased 8d9043a 2026-08-24T23:22:04-07:00

#### Coming From:

Unreleased 8d9043a

#### Purpose:

Record the low-complexity TFF progressive-baseline result and separate expected temporal weave combing from the measured full-D1 all-I throughput ceiling.

#### Outcome:

The user ran `_cadence/native_480i_tff_light_10s.m2v` with `Interlaced output` set to `800x600 Diagnostic` and reports that it looked good for interlaced material, the prior flicker disappeared, motion looked good, the duration seemed close to ten seconds and USER and POWER remained solid while DISK blinked twice. The user also saw dot crawl on vertical edges and the apparent non-alignment or comb of the two fields, which limited fine motion judgment. The final 800x600 screenshot was triggered and retrieved entirely through ordinary FTP using the default MiSTer login and no SSH; `.ai/current_results/entry487_tff_light_diagnostic.png` is 19,667 bytes with SHA-256 `fbf4dca1fcf6bd87280888fbeaba24905bac1c53d3e0fb76f939dc024ae6edc8`. The visible schema-nine record accepts all 5,007,304 source bytes, reports 300 reference and displayed pictures and 299 swaps after interpreting the eight-bit picture and swap counters modulo 256, preserves stable `top_field_first=1`, sees sequence end and presentation completion and reaches normal quiet reason one. Aggregate, decoder, presentation, destination, audio-underrun and PCM-protocol errors are all clear, and no scheduler work remains. First presentation occurs at 2,378,246 cycles and the last at 894,849,788 cycles, so 299 swap intervals occupy 892,471,542 cycles, or 14.874526 seconds at 60 MHz. The actual sustained rate is 20.101 pictures per second, not 29.97; the helper's direct 2.891-fps value is invalid after the display counter wraps. This improves materially over the detailed fixture's 14.992 pictures per second but still fails the intended real-time baseline. The screenshot shows the authored four-pixel temporal separation between the top and bottom scanlines of the moving vertical bar. Because the diagnostic output deliberately weaves fields captured at successive 60000/1001 source times into one progressive frame, that comb is expected and does not by itself indicate reversed field order or misplaced cache lines. The no-flicker result provides a useful progressive-output comparison, but full-D1 all-I decode throughput remains a confounder and native interlace is not yet passed.

#### Next Steps:

Revise the isolation sequence rather than generating another nominally real-time full-D1 all-I stream. With explicit user approval, run the same `_cadence/native_480i_tff_light_10s.m2v` once in `Native 480i` mode and compare its live bar edge, comb or dot crawl, flicker and motion directly against this captured progressive weave baseline; leave the final image loaded for an FTP-only capture. Treat that run only as a presentation-quality comparison at the measured approximately 20.1-picture decode rate, not as a 29.97-fps cadence qualification. If native presentation removes or materially reduces the weave comb, keep native timing unchanged and plan decoder-throughput or interlaced predictive-picture work separately. If it does not, add a decoder-independent native field-rate raster diagnostic before changing presentation timing. Continue to defer BFF and the public interlaced compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 487 COMMIT Unreleased 8d9043a 2026-08-24T23:14:45-07:00

#### Coming From:

Unreleased 5568aa9

#### Purpose:

Create and install a deterministic low-complexity interlaced motion fixture that can separate decoder throughput from progressive-versus-native presentation quality.

#### Outcome:

Commit `8d9043a` extends the existing interlaced all-I generator with an optional low-complexity 720x480 source while preserving the established detailed and four-picture defaults. The source runs at 60000/1001 pictures per second and contains broad flat regions, two stationary horizontal sharpness references, a high-contrast vertical bar moving four pixels per source field and alternating upper/lower field markers; FFmpeg weaves pairs into 30000/1001 frame-DCT all-I TFF or BFF pictures before the established signalling-only patch. `--light-visual-seconds 10` deterministically reproduces a 300-picture, 5,007,304-byte TFF stream with encoded SHA-256 `f45995d8786ffd229baaf8085e68f33a7866771d7038525fe0b6accdc7a0a2d7`, decoded-plane SHA-256 `2fbaaafa949092fd2025633390258989b6bb931ee0b0f3ae48bd125ab431ccb1` and `tt` signalling. Its 5,007,154-byte BFF companion has encoded SHA-256 `b26d0d4090ec8c39346782918e97eb0721ba0da5670b42ef14435e385f822271`, decoded-plane SHA-256 `554fbf879319392629bb1d3ac7a041358929e0ee2e8fed6a7a05862f9efa65eb` and `bb` signalling. A second independent generation reproduces both streams and the complete manifest byte-for-byte; patched and unpatched decoded YCbCr planes are identical, every picture is I coded, authored field order is stable and the analyzer retains the intentional candidate classification. Native field-order locking and rejection, exhaustive interlaced 4:2:0 cache mapping, exact TFF/BFF field timing, schema-nine cadence profiling and dual-layout telemetry decoding all pass. No RTL or RBF changed, so the already installed exact `5568aa9` image remains the applicable hardware. Only the TFF fixture was uploaded through ordinary FTP with the default `root` / `1` login as `/media/fat/_cadence/native_480i_tff_light_10s.m2v`; independent FTP retrieval is byte-identical at 5,007,304 bytes and SHA-256 `f45995d8786ffd229baaf8085e68f33a7866771d7038525fe0b6accdc7a0a2d7`. The BFF artifact remains local and deferred.

#### Next Steps:

Set `Interlaced output` to `800x600 Diagnostic` and run only `_cadence/native_480i_tff_light_10s.m2v`. Observe whether the clip lasts approximately ten seconds, whether the bar traverses smoothly without jumps or pauses, and whether the bar edge and two horizontal reference lines look sharp; report softness, flicker and USER, DISK and POWER at completion, then leave the final image loaded for an FTP-only schema-nine capture. Do not switch to Native 480i or run BFF until the progressive baseline is captured and proves approximately 29.97 pictures per second with zero errors.

#### Files Modified:

- tools/streams/generate_test_interlaced_i_frames.py

#### Status:

- [x] Built
- [ ] Passed

---
## 486 COMMIT Unreleased 5568aa9 2026-08-24T23:08:41-07:00

#### Coming From:

Unreleased 5568aa9

#### Purpose:

Record the sustained native-480i TFF hardware result, accept the complete native telemetry and capture diagnostics, and identify all-I decode throughput as a confounder before field-order qualification.

#### Outcome:

The user watched the complete `_cadence/native_480i_tff_10s.m2v` run in Native 480i mode and reports smooth playback with no visible jumps or dropped frames or fields, correct crop, some apparent softness and what resembles 60 Hz flicker. USER and POWER remain solid and DISK blinks twice at the terminal image. The 720x480 screenshot was triggered and retrieved entirely through ordinary authenticated FTP using the default MiSTer login and no SSH; `.ai/current_results/entry485_native480i_tff_10s.png` is 116,611 bytes with SHA-256 `e0961e226beaa193d086f42b15697f140553e9d4232eb1fabc540a8ef97798a7`. Its complete visible schema-nine record reports all 13,145,582 accepted transport writes for the 13,145,581-byte source, 300 reference and displayed pictures, 299 physical-frame swaps, stable `top_field_first=1`, rate code four, sequence end, presentation completion and quiet reason-one termination. Aggregate, decoder, presentation, destination, audio-underrun and PCM-protocol errors are all clear; no decode, reorder, promotion, future-reference, scratch or terminal-boundary work remains. First presentation occurs at 2,629,099 cycles and the last at 1,199,249,429 cycles, so the 299 swap intervals occupy 1,196,620,330 cycles, or 19.943672 seconds at 60 MHz. The actual sustained rate is therefore 14.992 pictures per second; the decoded display counter wraps modulo 256, so the helper's uncorrected 2.156-fps display is not applicable to this 300-picture run. The visual observation and counters agree that the scheduler does not discard pictures or fields: it preserves order and holds each decoded frame until the next one is available. This complex 720x480 all-I visual fixture therefore overloads the present decoder at roughly half the authored 29.97-picture rate and cannot qualify authored native field cadence, softness or flicker. The final still contains the expected weave of temporally separated fields and proves that the full native telemetry layout is now observable. DISK code two remains the passive third-I progress indication rather than an error. Native output remains unpassed, and BFF is deferred.

#### Next Steps:

Do not change native timing or run the BFF fixture from this result. Prepare a deterministic low-complexity 720x480 frame-DCT all-I TFF motion fixture with flat regions, high-contrast moving geometry and explicit field-order cues so the existing decoder can sustain the authored 30000/1001 picture rate. First run that same fixture in the 800x600 Diagnostic mode to establish real-time decode throughput and a progressive visual baseline, then run it in Native 480i mode and compare sharpness, flicker, motion direction and terminal telemetry. Proceed to the corresponding BFF fixture only after the TFF stream completes in approximately ten seconds with approximately 29.97 pictures per second, zero errors and no visible drops. Keep the public interlaced compatibility claim disabled.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 485 COMMIT Unreleased 5568aa9 2026-08-24T22:41:28-07:00

#### Coming From:

Unreleased 2bb8def

#### Purpose:

Create a diagnostic-only native-480i qualification boundary with sustained deterministic motion, fully visible telemetry and FTP-only capture while leaving presentation behavior unchanged.

#### Outcome:

Commit `5568aa9` adds diagnostic-only native-480i qualification support without changing native timing, field order, framebuffer mapping, cadence scheduling or compatibility classification. The deterministic generator retains the exact four-picture TFF and BFF artifacts and their established encoded and decoded hashes by default, while `--visual-seconds 10` produces separate 300-picture all-I motion clips. The 13,145,581-byte TFF visual stream has SHA-256 `4d7c14225ac6b12d37e74f5d682edbe6c6be649096db558d01629f4920f51b95`, decoded-plane SHA-256 `8847d3ea81ed81b9a14f0affb87b3751d7539957934563f9b15dc874708a31bc` and `tt` signalling. The 13,168,691-byte BFF stream has SHA-256 `1c53638979aef7a60f3a4c343d8229935c336035c637bc6cf94073675c165fe5`, decoded-plane SHA-256 `d46058ca79418905f41d50c225b12d4750a84015e7050adde9136cb211266228` and `bb` signalling. Each signalling patch is independently proven not to alter decoded YCbCr planes, and the public checker deliberately continues to reject both streams. The cadence profiler now uses the already-video-domain native-mode observation only to place its unchanged 38-row schema-nine overlay at line 324 instead of line 444; permanent RTL and Python tests prove the full record at both 720x480 and 800x600. The screenshot helper now writes its command directly to `/dev/MiSTer_cmd` through authenticated FTP and retrieves the result through FTP, with no SSH dependency; a live trigger and retrieval against the installed MiSTer succeeds. Native TFF/BFF geometry, exhaustive interlaced cache mapping, field-order locking, profiler, dual-layout decoder, scheduler rates and field/frame cadence, picture timestamps, end-to-end TFF/BFF/progressive reconstruction, field-DCT rejection and the 72-picture progressive live-raster soak all pass with their established deterministic results. A clean Quartus 17.0.2 build completes in 10:50 with zero errors and 144 established warnings. Global TNS is zero; focused decoder setup/recovery slack is 1.808/11.798 ns and video setup slack is 2.446 ns. Fitter use is 29,641 ALMs, 45,683 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks and 3 PLLs. The 4,210,740-byte RBF has SHA-256 `5544bb48bea6d0f066b01f09f63087d46e7a52438ca60b6872b9f452ef213c09`.

#### Next Steps:

Push the exact source and metadata commits, then install the exact RBF plus both generated ten-second clips through ordinary FTP using the default MiSTer login and verify all remote hashes. Reload the core and run only the longer TFF clip in Native 480i mode. Observe the full motion interval for display lock, field combing, direction-dependent judder, repeated or missing motion, crop and terminal LEDs, then leave the final image loaded. Trigger and retrieve the native schema-nine capture entirely through FTP and use its complete terminal record together with the live observation to decide whether presentation behavior needs correction. Do not run BFF until the TFF result is captured and understood, and keep the public interlaced compatibility claim disabled.

#### Files Modified:

- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/generate_test_interlaced_i_frames.py
- tools/streams/read_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [ ] Passed

---
## 484 COMMIT Unreleased 2bb8def 2026-08-24T22:33:38-07:00

#### Coming From:

Unreleased 2bb8def

#### Purpose:

Record the first native-480i TFF hardware result without overclaiming its very short visual fixture or the clipped diagnostic overlay.

#### Outcome:

The user loaded `_cadence/native_480i_tff.m2v` in Native 480i mode and reports that the display accepted an interlaced picture, the image filled the vertical screen area, visible interlacing artifacts appeared, playback stopped after roughly one second, the MiSTer remained responsive, USER was solid, DISK blinked twice and POWER was solid. The final 720x480 image was triggered and retrieved entirely through ordinary FTP with the default `root` / `1` login and no SSH; `.ai/current_results/entry483_native480i_tff_failure.png` is 127,692 bytes with SHA-256 `7d658ebde64f06818e1c02f2ad4cafd4452ddb79a8830a8c658c603865f1d7ba`. The capture proves native raster activation and shows the expected temporally separated edges of a 60000/1001 source woven into interlaced fields, but it cannot establish live field-order quality from a still image. The generated fixture contains only four 30000/1001 pictures, or about 0.133 seconds of coded video, so its apparent short stop is expected and it is too brief for a useful live-motion judgment. USER solid and POWER solid indicate the bounded decode was accepted; DISK code two is the passive final-GOP progress probe arming on the third I picture and observing its publication, not a decoder error. The schema-nine overlay still begins at diagnostic line 444 and therefore extends below the 480-line native raster; only its first rows appear in this capture and the full terminal record cannot be decoded. Native output remains unpassed because visible deinterlacing quality, sustained field cadence and BFF behavior are not yet established.

#### Next Steps:

Before changing presentation behavior, prepare a bounded diagnostic proposal that generates longer deterministic TFF and BFF motion fixtures, moves the fixed telemetry block into the visible native raster while retaining its 800x600 position, teaches the decoder to read either layout and changes the screenshot trigger to write `/dev/MiSTer_cmd` through authenticated FTP rather than SSH. Rebuild and install that observability candidate, then run the longer TFF clip first to distinguish correct display deinterlacing from a field-order or field-cadence fault; defer BFF until TFF is captured and understood. Keep the public interlaced compatibility claim disabled.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 483 COMMIT Unreleased 2bb8def 2026-08-24T16:09:09-07:00

#### Coming From:

Unreleased 4c4d0e3

#### Purpose:

Implement and qualify the first native 720x480 interlaced presentation path for the already-proven stable-field-order, frame-DCT all-I subset, while retaining an explicit progressive diagnostic fallback and making no SDI or processing-bypass claim.

#### Outcome:

Commit `2bb8def` adds a selectable native 720x480 interlaced presentation path for the bounded frame-DCT all-I subset. A 54 MHz video domain provides an exact divide-by-four 13.5 MHz logical sample cadence, 858-sample lines, two 262.5-line fields with continuous half-line phase, 720x480 active video, negative sync and field identity on `VGA_F1`; the existing 800x600 progressive diagnostic path remains selectable. The frontend publishes an exact accepted-picture field-order event, physical frame banks retain their own `top_field_first` metadata, a session lock rejects an unexpected field-order change, and the scheduler now advances cadence every field while allowing physical frame-bank swaps only at the authored first-field frame boundary. The DDR presentation cache maps even/odd luma lines by displayed field and shares each interlaced 4:2:0 chroma row across the corresponding two same-field luma lines. Focused RTL regressions pass stable TFF, stable BFF, field-order-change rejection and reset cases; both field orders each produce four fields with 225,225 logical field ticks, 172,800 active samples, 2,574 sync samples and a 429-sample half-line, while exhaustive cache tests cover 960 luma and 480 chroma line sequences. Scheduler, picture-timestamp, cadence-profiler, dense-publication and progressive live-raster regressions pass. End-to-end reconstruction remains within the established one-LSB IDCT tolerance for all 2,073,600 component samples in each four-picture fixture: TFF has 9,442 one-LSB differences and BFF has 9,632, with zero larger differences; the progressive control likewise has zero differences beyond one LSB. The compatibility checker deliberately continues to report the new streams unsupported pending hardware proof. A clean Quartus 17.0.2 synthesis, fit, assembly and TimeQuest build completes with zero errors; global endpoint TNS is zero, focused decoder setup/recovery slack is 1.506/10.530 ns and video setup slack is 2.503 ns. Fitter use is 29,361 ALMs, 45,247 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks and 3 PLLs. The 4,209,032-byte RBF has SHA-256 `71462f2ded90f4d40c7502cd58d07e99620d51a3e00f5b58ccfcd38d24e1833e`. Field pictures, field-DCT, repeat-first-field, interlaced P/B pictures, the public compatibility claim and all external processing/SDI work remain unsupported.

#### Next Steps:

Install the exact RBF and deterministic TFF/BFF fixtures by plain FTP using the default MiSTer username and password, with no SSH keys. Reload the core and test TFF first in Native 480i mode, checking display lock, field order, combing or judder, crop and LED state, then capture the final image. Test BFF separately only after the TFF capture using the same observations. Keep the public compatibility claim disabled until both field orders pass on hardware; retain the 800x600 diagnostic mode for isolation and do not claim SDI or processing bypass. Field pictures, field-DCT, repeat-first-field and interlaced P/B pictures remain later milestones.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_native_field_order.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- rtl/mpeg2_video_output_timing.sv
- rtl/pll/pll_0002.v
- tools/phase1p_timing.tcl
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_h262_picture_timestamp.sv
- tools/streams/tb_interlaced_420_cache_mapping.sv
- tools/streams/tb_native_480i_timing.sv
- tools/streams/tb_native_field_order.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 482 COMMIT Unreleased 4c4d0e3 2026-08-24T15:29:53-07:00

#### Coming From:

Unreleased 46bf297

#### Purpose:

Admit and prove pixel reconstruction for the exact native-480i interlaced frame-DCT all-I subset established by the deterministic TFF/BFF fixtures, without yet changing video timing or claiming native output support.

#### Outcome:

Commit `4c4d0e3` admits only the approved 720x480, 30000/1001, 4:2:0, all-I, frame-picture/frame-DCT interlaced subset. The frontend now captures `chroma_420_type` explicitly and requires `progressive_sequence=0`, `progressive_frame=0`, `chroma_420_type=0`, `repeat_first_field=0`, frame prediction/DCT, valid I-picture syntax and no concealment vectors; either authored `top_field_first` value is preserved. Progressive acceptance remains under its original predicate, and field pictures, field-DCT pictures, repeat-first-field and unsupported motion syntax remain excluded. A new end-to-end RTL bench exercises the live frontend, I-picture parser/bookkeeper, inverse quantizer, IDCT and intra reconstruction against independent FFmpeg planar-YCbCr oracles. The TFF fixture reconstructs all 4 pictures and 2,073,600 component samples with 9,442 one-LSB differences, zero samples beyond the established one-LSB IDCT tolerance and maximum delta 1. The BFF fixture reconstructs all 4 pictures and 2,073,600 samples with 9,632 one-LSB differences, zero beyond tolerance and maximum delta 1. The released progressive all-I control reconstructs all 4 pictures and 2,073,600 samples with 69,671 one-LSB differences, zero beyond tolerance and maximum delta 1. A valid interlaced field-DCT negative control reaches the frontend but never asserts phase-one acceptance and reconstructs zero pictures. Current and exact pre-change `6636e8b` Cycle-A parser-equivalence runs produce byte-identical deterministic result lines across all eight cases; the same three legacy fixed-expectation wrapper exits occur on both revisions and remain outside the release gate. Quartus 17.0.2 synthesis, fitting, assembly and TimeQuest complete with zero errors. Focused timing reports zero violations with 1.748 ns decoder setup slack, 10.182 ns decoder recovery slack and 8.519 ns video setup slack; global endpoint TNS is zero. Fitter use is 29,134 ALMs, 45,135 registers, 3,655,139 block-memory bits, 464 RAM blocks and 65 DSP blocks. The resulting RBF is 4,186,320 bytes with SHA-256 `49ff363a6ab284f301ac30d96e3a976fafc0208317afd7fa486435ad6110b0fa`. Presentation deliberately remains the existing 800x600 progressive diagnostic path, and the user-facing compatibility checker still reports these streams unsupported until native 480i output is proven.

#### Next Steps:

Prepare the separate native 480i timing and presentation proposal. Add standards-correct alternating field timing with the required half-line relationship, use authored `top_field_first` only to choose the first displayed field, map the reconstructed frame into field-aware luma and 4:2:0 chroma presentation, drive MiSTer field signalling, and retain the current progressive diagnostic path as a selectable fallback until hardware proof passes. Keep field pictures, field-DCT, repeat-first-field, P/B interlacing and the user-facing compatibility claim out of scope. Qualify timing in RTL before installing any candidate RBF by plain FTP for visual TFF/BFF hardware testing.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- tools/streams/tb_h262_interlaced_i_reconstruction.sv
- tools/streams/run_interlaced_i_reconstruction.sh

#### Status:

- [x] Built
- [x] Passed

---
## 481 COMMIT Unreleased 46bf297 2026-08-24T15:22:14-07:00

#### Coming From:

VERSION v0.7.0 0064148

#### Purpose:

Establish the standards and deterministic-regression foundation for the first bounded native-interlaced I-frame milestone without changing current playback behavior.

#### Outcome:

Commit `46bf297` adds controlled H.262 records for interlaced sequence/frame semantics, macroblock height, picture structure, authored first-field order, frame-DCT/frame-prediction, repeat/chroma constraints, field-period output and interlaced 4:2:0 sample organization. The new deterministic generator produces four-picture 720x480 all-I elementary streams at 30000/1001 for both TFF and BFF. The TFF artifact is 157,688 bytes at SHA-256 `61ba1555df74e63fbfed83dbe674cd31a4886505193c6dcc7d4fe104d2cbe828`; FFprobe reports field order `tt`, and its decoded YCbCr planes hash to `3984cdfe2e8f98ac2b9734f7e484976c2200faf6363a380df1e21176161ae392`. The BFF artifact is 160,157 bytes at SHA-256 `6da990f80eb349928cd9ee843094bbb2faeedbd2d8bf9c1a874cb71ab89a69b6`; FFprobe reports `bb`, and its decoded planes hash to `2927bb2b3ce1327e8055cbb5516657cef9b7e7b9ae8869af094f47cca6933ae3`. In both cases the signalling-only patch leaves decoded YCbCr bytes identical to the unpatched frame-DCT source. The analyzer recognizes exactly the approved 4:2:0 interlaced all-I frame-picture envelope while continuing to classify ordinary progressive regressions unchanged. The user-facing compatibility checker deliberately reports both new streams unsupported until RTL playback is enabled, preventing a premature support claim. Python compilation, generator assertions, manifest assertions, independent FFmpeg decode, FFprobe field-order checks, current checker-boundary checks and regeneration of the existing progressive compatibility corpus all pass. Generated media remains ignored and reproducible from committed source.

#### Next Steps:

Prepare the next Unreleased source proposal to open only the I-picture frontend capability gate for the proven 720x480 interlaced frame-DCT subset and add RTL regression coverage that reconstructs both generated fixtures against the recorded FFmpeg plane hashes while leaving field presentation on the existing progressive diagnostic display. Do not enable the compatibility checker or native output claim until that decoder proof passes. Native 480i timing, field-aware chroma presentation and MiSTer field signalling remain the following separately qualified commit.

#### Files Modified:

- .ai/core-reference.md
- .gitignore
- tools/streams/analyze_h262_compatibility.py
- tools/streams/check_media_compatibility.py
- tools/streams/generate_test_interlaced_i_frames.py

#### Status:

- [x] Built
- [x] Passed

---
## 480 VERSION v0.7.0 0064148 2026-08-24T14:39:58-07:00

#### Coming From:

Unreleased 37d913b

#### Purpose:

Record publication and independent verification of the v0.7.0 annotated tag, GitHub pre-release and matched runtime archive.

#### Outcome:

The annotated `v0.7.0` tag object is `3e6d994d588a027b7e9b5fcbb8b0ba2950ae3472` and resolves exactly to release commit `0064148502356b70bde7fc700ca3c81c3744576d`. GitHub reports a published, non-draft pre-release named `v0.7.0` at `https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.7.0`, published 2026-08-24T21:36:33Z. The release asset was downloaded independently from GitHub: `MiSTer_Media_Player_v0.7.0.zip` is exactly 2,749,946 bytes with SHA-256 `bae3c3c17d2381cb91e2baff98ec9cf22fed88b04d01bc1349574ae57b917377`, matching the locally qualified archive. Its compressed-data test passes for all eight entries, and its internal `SHA256SUMS` identifies the qualified 4,184,380-byte `MediaPlayer_20260824.rbf` at `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`, 1,166,244-byte patched `MiSTer` at `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`, and executable 361,452-byte `linux/MediaPlayer_Helper` at `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`, plus installation, provenance and license files. A separate loose RBF is deliberately unnecessary for this milestone because all three runtime components are a matched set; distributing the verified archive as the sole binary asset reduces partial-install mismatch risk while the tagged source archives remain available automatically. The four-file hardware gate, clean FPGA build, host qualification, tag target, release notes and published binary are consequently complete and mutually consistent.

#### Next Steps:

Treat v0.7.0 and its published archive as immutable. Begin any later work under a new Unreleased proposal, retain the exact `9a5eea3` FPGA and `acdbf8b` helper baselines for reproduction, and do not replace the tag or asset in place; publish a new semantic version if a released file ever needs to change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 479 COMMIT Unreleased 37d913b 2026-08-24T14:24:41-07:00

#### Coming From:

Unreleased eab57b7

#### Purpose:

Accept the completed four-file v0.7.0 hardware release gate and finalize the public qualification record.

#### Outcome:

After a fresh power cycle, the user watched `20_bbb_full_48k.mpg` through its natural end and reports that everything passes, including the opening, transitions, high-motion sequence and rolling credits, with USER solid on, DISK blinking eleven times and POWER solid on. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry479_release_gate_full_soak.png` is 8,156 bytes with SHA-256 `08b075111ee41b2621db28abfde247ca676764ef6d78f5ed79c144e173418d7d`. Schema nine accepts all 84,423,309 H.262 bytes, and its wrapped counters correspond exactly to all 4,773 reference plus 9,542 B pictures, all 14,315 displayed pictures and 14,314 swaps. PCM sample and FIFO-peak telemetry saturate normally, aggregate error flags are zero, audio underrun and PCM protocol error are clear, sequence end is seen, presentation completes and the session freezes for normal quiet reason one at STC second 596. The credits window records zero gap outliers; its three largest gaps are each 2,984,256 decoder cycles or 49.7376 milliseconds, with 147 passive timestamp-advance opportunities and zero delay conflicts. Every terminal decoder, destination, presentation, reorder, scratch, promotion and future-reference state is clear. Together with the accepted power-cycle 48 kHz control, no-reboot video-only stream and no-reboot 44.1 kHz recovery control, this completes the exact four-file release gate on the reproducible RBF, helper and Main. Commit `37d913b` updates `README.md`, `CHANGELOG.md` and `docs/RELEASE_NOTES_v0.7.0.md` with the passed results and capture hashes. The internal package checksums still pass, and the unchanged 2,749,946-byte `MiSTer_Media_Player_v0.7.0.zip` retains SHA-256 `bae3c3c17d2381cb91e2baff98ec9cf22fed88b04d01bc1349574ae57b917377`.

#### Next Steps:

After this metadata commit is pushed, have the user create the annotated `v0.7.0` tag at the exact resulting `origin/master` commit and publish a GitHub pre-release using `docs/RELEASE_NOTES_v0.7.0.md`. Attach `host/build/MiSTer_Media_Player_v0.7.0.zip` and the loose `host/build/release-v0.7.0/MediaPlayer_20260824.rbf`; do not attach the generated regression media. After the tag and pre-release exist, verify their target and asset hashes, add the required VERSION record and leave `Unreleased` empty for the next milestone.

#### Files Modified:

- README.md
- CHANGELOG.md
- docs/RELEASE_NOTES_v0.7.0.md

#### Status:

- [x] Built
- [x] Passed

---
## 478 COMMIT Unreleased eab57b7 2026-08-24T14:11:18-07:00

#### Coming From:

Unreleased eab57b7

#### Purpose:

Accept no-reboot 44.1 kHz audio recovery from the silent Program Stream as the third v0.7.0 release-gate test.

#### Outcome:

Without rebooting after the accepted zero-PCM session, the user reports that `01_good_480p_44k.mpg` passes with USER solid on, DISK blinking eleven times and POWER solid on. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry478_release_gate_44k_recovery.png` is 104,593 bytes with SHA-256 `4220305dabf9759e02c8f6c573fffb7768a43a338055d8a27ea77058f5fc8b8f`. Schema nine proves that audio delivery restarted: PCM sample count and FIFO high-water fields reach their healthy saturated telemetry values, while audio underrun, PCM protocol error and aggregate error flags remain clear. The core accepts the complete 582,741-byte H.262 payload, associates five timestamps, decodes seventeen reference and 31 B pictures, displays all 48 pictures with 47 swaps, records zero display-gap outliers, sees sequence end, completes presentation and freezes for normal quiet reason one at STC second two. Every decoder, destination, presentation, reorder, scratch, promotion, future-reference and terminal state is clear. This passes test three of the exact four-file v0.7.0 release gate and proves the required 48 kHz audio-video to silent to 44.1 kHz audio-video sequence without reboot.

#### Next Steps:

Power-cycle the MiSTer once, leave Audio Test Off and run only `20_bbb_full_48k.mpg` through its natural 9:56 end. Watch opening motion and sync, scene transitions, the high-motion squirrel sequence near 7:22 and the rolling credits, requiring no crackle, dropout, drift, repeated sections, corruption or recurring cadence jump. After completion, report audio-video behavior and all three LEDs, then leave the final image loaded for schema-nine capture. Do not replay or launch another file before the final evidence is retrieved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 477 COMMIT Unreleased eab57b7 2026-08-24T14:08:55-07:00

#### Coming From:

Unreleased eab57b7

#### Purpose:

Accept silent Program Stream playback as the second v0.7.0 release-gate test and advance to no-reboot 44.1 kHz recovery.

#### Outcome:

Without rebooting after the accepted 48 kHz control, the user reports that `02_good_video_only.mpg` passes with USER solid on, DISK blinking eleven times and POWER solid on. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry477_release_gate_video_only.png` is 104,561 bytes with SHA-256 `9f9d3fccab5e20c6b0e932065b3960e5b4f80ff30ed0d13cc6bf50c7591df586`. Schema nine reports exactly zero delivered PCM samples, no audio underrun or PCM protocol error, zero aggregate errors and no display-gap outlier. It accepts the established 582,742 MiSTer transfer-byte count for the 582,741-byte demultiplexed H.262 payload, associates five timestamps, decodes seventeen reference and 31 B pictures, displays all 48 pictures with 47 swaps over 1.959896 seconds at 23.980870 frames per second, sees sequence end, completes presentation and freezes for normal quiet reason one at STC second two. Every decoder, destination, presentation, reorder, scratch, promotion, future-reference and terminal state is clear. The FIFO high-water telemetry remains saturated from the preceding audio session because that top-level diagnostic is reset only with the core, but the session PCM counter is zero and the user heard the required silence. This passes test two of the exact four-file v0.7.0 release gate.

#### Next Steps:

Without rebooting, run only `01_good_480p_44k.mpg` with Audio Test Off. Require audio to restart immediately and remain aligned, crackle-free and dropout-free after the zero-PCM session, with all 48 pictures and 47 swaps, healthy PCM activity, zero aggregate, decoder, presentation, underrun and protocol errors, sequence end, presentation completion and normal quiet reason one. Report all three terminal LEDs and leave the final image loaded for capture. Do not begin the full soak until this recovery transition is accepted.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 476 COMMIT Unreleased eab57b7 2026-08-24T14:06:42-07:00

#### Coming From:

Unreleased eab57b7

#### Purpose:

Accept the v0.7.0 release gate's power-cycle 48 kHz audio-video control and advance to silent Program Stream playback.

#### Outcome:

After the required power cycle, the user reports that `00_good_480p_48k.mpg` passes with USER solid on, DISK blinking eleven times and POWER solid on. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry476_release_gate_48k.png` is 104,559 bytes with SHA-256 `f57df09f5f3da51e9eceec797e52fd5369fe5a35324566b382cd56c602bf7cd0`. Schema nine accepts the complete 582,741-byte H.262 payload, associates five timestamps, decodes seventeen reference and 31 B pictures, and displays all 48 pictures with 47 swaps. PCM sample count and FIFO peak saturate their healthy telemetry fields, while aggregate error flags are zero, audio underrun and PCM protocol error are clear, no display-gap outlier is recorded, sequence end is seen, presentation completes and the session freezes for normal quiet reason one at STC second two. Decoder, presentation, destination, reorder, scratch, promotion, future-reference and terminal state are clean. This passes test one of the exact four-file v0.7.0 release gate on the reproducible release binaries.

#### Next Steps:

Without rebooting, run only `02_good_video_only.mpg` with Audio Test Off. Require the complete picture to play silently, USER and POWER solid on, no audio output, all 48 pictures and 47 swaps, zero PCM samples, zero aggregate, decoder, presentation, underrun and protocol errors, sequence end, presentation completion and normal quiet reason one. Report all three terminal LEDs and leave the final image loaded for capture. Do not run the 44.1 kHz recovery control until this silent session is captured.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 475 COMMIT Unreleased eab57b7 2026-08-24T14:01:04-07:00

#### Coming From:

Unreleased acdbf8b

#### Purpose:

Qualify and package the reproducible v0.7.0 release candidate from the accepted FPGA and host baselines.

#### Outcome:

Commit `eab57b7` updates `README.md`, `CHANGELOG.md` and new `docs/RELEASE_NOTES_v0.7.0.md` for the matching RBF, patched Main and ARM helper release. A clean from-scratch Quartus Prime 17.0.2 build completes with zero errors and reproduces the accepted 4,184,380-byte RBF exactly at SHA-256 `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`; global setup, hold, recovery, removal and minimum-pulse-width slack are respectively +0.311, +0.238, +3.365, +0.497 and +1.122 ns, with +1.782 ns decoder setup, +11.294 ns decoder recovery and +8.284 ns video setup. The fit uses 29,325 ALMs, 45,259 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks and three PLLs. The focused RTL suites pass picture timestamps, PTS timeline, codes-one-through-five scheduling and cadence floor, transport gating, download re-arm, system clock, in-band metadata, clean-video queuing, audio output, the 8,192-frame FIFO and schema-nine telemetry. The optional legacy Cycle-A wrapper is not a current release gate: its three reported failures are stale fixture/inventory or fixed-cycle signature expectations, while the emitted functional result counters are complete and error-free. Native and sanitized helper qualification, the exact 14,315-picture transport soak, two byte-identical official-toolchain helper builds and two byte-identical patched-Main builds retain the accepted results. The assembled archive `host/build/MiSTer_Media_Player_v0.7.0.zip` is 2,749,946 bytes at SHA-256 `bae3c3c17d2381cb91e2baff98ec9cf22fed88b04d01bc1349574ae57b917377`; its internal `SHA256SUMS` verifies the date-coded RBF, Main, executable `linux/MediaPlayer_Helper`, installation guide, source provenance and both licenses. Generated regression media is excluded. Read-only plain-FTP verification with the default MiSTer login and no SSH keys already proves that the active RBF, helper and Main are the exact release bytes, so no installation mutation is needed before the final gate.

#### Next Steps:

Power-cycle the MiSTer and run exactly four files in order: `00_good_480p_48k.mpg`, `02_good_video_only.mpg`, `01_good_480p_44k.mpg` without reboot after the silent file, and `20_bbb_full_48k.mpg` after a fresh power cycle. Capture schema-nine telemetry and all three LED states for each, require correct video and audio behavior with zero aggregate, decoder, presentation, PCM protocol and underrun errors, then update the release notes to record the passed gate and have the user create the annotated `v0.7.0` tag and GitHub pre-release from the exact final commit.

#### Files Modified:

- README.md
- CHANGELOG.md
- docs/RELEASE_NOTES_v0.7.0.md

#### Status:

- [x] Built
- [ ] Passed

---
## 474 COMMIT Unreleased acdbf8b 2026-08-24T13:36:45-07:00

#### Coming From:

Unreleased acdbf8b

#### Purpose:

Accept immediate audio-video recovery after the silent Program Stream and establish the v0.7.0 release-qualification boundary.

#### Outcome:

Without rebooting after the accepted video-only session, the user ran `00_good_480p_48k.mpg` and reports that everything looked and sounded good, followed by USER and POWER solid on and DISK blinking eleven times. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry474_av_recovery_after_video_only.png` is 104,628 bytes with SHA-256 `a12f6a89eecf177e1c1a345a2c2f346abb13c0fa5c58f1843a482725205a334f`. Schema nine accepts the complete 582,741-byte H.262 payload, associates five timestamps, decodes all seventeen reference and 31 B pictures, displays all 48 pictures with 47 swaps, saturates the healthy PCM sample and FIFO-peak telemetry fields, and reports zero aggregate errors, no audio underrun or PCM protocol error, sequence end, presentation completion and normal quiet reason one at STC second two. No decode, reorder, scratch, promotion, future-reference or terminal work remains. This passes the required no-reboot transition from a zero-PCM session to ordinary 48 kHz audio-video playback and completes functional hardware acceptance of helper source `acdbf8b` with FPGA source `9a5eea3`.

#### Next Steps:

After approval, qualify v0.7.0 from the exact accepted source boundary with a clean from-scratch Quartus 17.0.2 build, the standard Phase-1P timing reports, the complete focused and host regression suites, and a reproducible official-toolchain helper build. Verify the release RBF and helper hashes, then update `README.md`, `CHANGELOG.md` and new v0.7.0 release notes to describe bounded Program Stream input, MPEG Layer II audio, real PTS scheduling, the exact-cadence correction, supported limits, hardware validation and timing/resource results. Package the date-coded RBF and matching helper from the final documentation commit, install the exact candidate through plain FTP with rollback preserved, run the release hardware gate, and only after it passes have the user create the annotated `v0.7.0` tag and GitHub pre-release from that exact commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 473 COMMIT Unreleased acdbf8b 2026-08-24T13:30:57-07:00

#### Coming From:

Unreleased acdbf8b

#### Purpose:

Accept silent video-only Program Stream playback in hardware and advance to the immediate audio-video recovery control.

#### Outcome:

The user reports that `02_good_video_only.mpg` played correctly, ending with USER and POWER solid on and DISK blinking eleven times. The final image was triggered and retrieved exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry473_video_only_program_stream.png` is 104,593 bytes with SHA-256 `ce53ec3dde8cf964f09d7e80a497be4d516c6bfbf02cb767f1c43cdf1a96409c`. Schema nine reports zero aggregate errors, no audio underrun or PCM protocol error, zero PCM samples, all seventeen reference and 31 B pictures decoded, all 48 pictures displayed with 47 swaps, sequence end, presentation completion and ordinary quiet reason one at STC second two, with no pending decoder or scheduler work. The accepted-byte counter is 582,742 rather than Entry 472's stated 582,741: host demux proves the video-only, 48 kHz and 44.1 kHz controls contain the identical 582,741-byte H.262 payload at SHA-256 `079d7c7393ce2bb80fe716f927733c3aa5e492a4812922bc9b10b6dd9e25330a`, while every prior hardware capture of that payload also reports 582,742 accepted transfer bytes, so Entry 472 mixed the host payload size with the established MiSTer hardware count rather than identifying a regression. This hardware-accepts the bounded silent-stream fallback in helper source `acdbf8b` while retaining accepted FPGA source `9a5eea3`.

#### Next Steps:

Without rebooting, run only `00_good_480p_48k.mpg` with Audio Test Off and report audio-video alignment, any crackle or dropout and all three terminal LEDs, then leave its final image loaded for capture. Require the established 582,742 accepted transfer bytes, all 48 pictures and 47 swaps, audio present without underrun or PCM protocol error, zero aggregate errors, sequence end, presentation completion and normal quiet reason one. A clean result proves immediate recovery from the no-PCM session and freezes `acdbf8b` with `9a5eea3` for the clean v0.7.0 release-qualification build; any failure requires retaining this accepted video-only evidence and diagnosing session re-arm before release work.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 472 COMMIT Unreleased acdbf8b 2026-08-24T13:12:04-07:00

#### Coming From:

Unreleased 9a5eea3

#### Purpose:

Make video-only MPEG Program Streams play silently while preserving bounded audio-video scheduling and explicit rejection of unsupported audio.

#### Outcome:

The baseline failure reproduced exactly: `good_video_only.mpg` emitted only the 28,672-byte startup lead, exited one and reported the 524,288-byte video lookahead limit. Commit `acdbf8b` distinguishes that silent stream from supported and unsupported audio without changing the transport format. Before MPEG Layer II appears, reaching the bounded video queue now releases the retained bytes byte-exactly and commits to silent video; a shorter silent stream takes the same path at end of input, while MPEG audio arriving after that bounded decision fails rather than starting permanently late. Private-stream-one packets are parsed far enough to reject the established AC-3, DTS and LPCM substream range explicitly, while a permanent synthetic subpicture case proves other private packets remain ignored. The 591,889-byte video-only corpus file now succeeds with all 582,741 demuxed H.262 bytes plus six ordered timestamp records for a 582,795-byte transport and no PCM or end record; `bad_audio_codec.mpg` fails with the intended MPEG Layer II requirement. All short and faded fixtures at 44.1 and 48 kHz pass under native and address-and-undefined-sanitized helpers with byte-identical video, exact audio lengths, maximum sample error two, correlation rounding to one and clean ends. Frame-rate codes one through five, codes six through eight rejection, split-PES rejection, raw M2V, protocol and source failures all retain their contracts, and the regenerated nine-case checker corpus remains three passes and six intended failures. The full soak is unchanged at 207,888,468 transport bytes with SHA-256 `d3ea5074ad9158ddde451151ed36f1ebad948cb19c8d8216ea97e8a67731eeb4`, 84,423,309 clean-video bytes, 598 timestamps, video-and-record SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81`, all 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, zero audio deficit, a 2,048-frame maximum steady batch and 4,052-byte maximum PCM-free video span. The official ARM GNU 10.2.1 archive verifies at its pinned SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a`, and two independent builds are byte-identical: the 361,452-byte static stripped ARM EABI5 helper has SHA-256 `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`. Installation used plain FTP with the default MiSTer login and no SSH keys. The prior active helper verified at SHA-256 `d61e69ea2240c23419abb9162a06159f9b6c527e838c9a6e52f0bd1855588d34` and is preserved byte-identically as `/media/fat/linux/MediaPlayer_Helper.backup.pre-video-only.6dece4c`; the staged and final active helper both verify at the new hash with mode 755. The accepted `9a5eea3` RBF remains byte-identical at SHA-256 `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`, Main and every pre-existing media file are unchanged, and the missing video-only control was added as `/media/fat/games/MediaPlayer/v0.7_qualification/02_good_video_only.mpg` at 591,889 bytes and SHA-256 `a3e675cad7b3142d2ea25d5b27d2e84e898572c0b6d080bbd2b0a3d01ac76a95` through staged roundtrip verification.

#### Next Steps:

Power-cycle once, set Audio Test to Off and run only `02_good_video_only.mpg`. It must present the complete two-second 720x480 video silently rather than returning at the former lookahead boundary, end with ordinary LEDs and settle to a clean schema-nine image with zero audio sample count, no audio underrun or PCM protocol error, all 582,741 clean-video bytes accepted, all 48 pictures displayed, sequence end and presentation completion. Leave that final image loaded for capture before running anything else. If it passes, replay `00_good_480p_48k.mpg` without reboot and require the established aligned, crackle-free 48 kHz control with all 48 pictures, audio present, zero errors and immediate recovery; then freeze `acdbf8b` with accepted FPGA source `9a5eea3` for the clean v0.7.0 release-qualification build. Any video-only failure calls for helper rollback to `/media/fat/linux/MediaPlayer_Helper.backup.pre-video-only.6dece4c` without changing the RBF.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 471 COMMIT Unreleased 9a5eea3 2026-08-24T13:10:34-07:00

#### Coming From:

Unreleased 9a5eea3

#### Purpose:

Accept the timestamp cadence floor on a complete hardware soak and establish the release-candidate presentation baseline.

#### Outcome:

The user watched `20_bbb_full_48k.mpg` end to end on `9a5eea3` and reports perfectly smooth motion with no jumps even in the credits, followed by USER and POWER solid on and DISK blinking eleven times. The final screenshot was captured exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry471_full_soak_pts_cadence_floor.png` is 8,145 bytes with SHA-256 `5648ae703647ba1996a0615e6770b40c30ea9175df5e43bc798a694682a41f01`. Schema nine accepts all 84,423,309 clean-video bytes, reports zero aggregate errors, no audio underrun or PCM protocol error, sequence end, presentation completion and normal quiet reason one at STC second 597; the eight-bit display counters wrap exactly as expected for all 14,315 pictures and 14,314 swaps to 235 and 234. The credits-window result is stronger than the visual observation alone: gap outliers fall from thirty on `8c59ddb` to zero, and all three largest gaps are now 2,984,256 decoder cycles or 49.7376 milliseconds rather than 3,979,008 cycles or 66.3168 milliseconds. The profiler records 149 timestamp-advance opportunities and zero delay opportunities because it observes the PTS-due versus cadence-early condition rather than a completed swap; after the correction a retained timestamp may remain in that condition across more than one raster window while the mandatory cadence floor blocks it, so this larger passive count does not represent early presentation. The absence of late-window outliers, clean terminal evidence and user's smooth-credits report together accept `9a5eea3` and confirm that the former approximately one-second cadence was caused by sparse timestamps replacing the exact-rate admission gate.

#### Next Steps:

Freeze `9a5eea3` as the accepted FPGA functional baseline and preserve `/media/fat/MediaPlayer.backup.pre-pts-floor.8c59ddb.rbf` until release qualification is complete. Before starting broader decoder features, close or explicitly document the remaining host-side video-only Program Stream boundary, where `good_video_only.mpg` currently reaches the helper's 512 KiB lookahead error instead of playing or reporting the intended missing-audio condition. Then qualify v0.7.0 from an exact release-candidate commit with a clean from-scratch Quartus 17.0.2 build, Phase-1P timing reports, the complete hardware regression pack, supported 44.1 and 48 kHz controls, expected-failure recovery sweep and final audio-video soak; update README, changelog and release notes to describe the now-proven Program Stream, audio and PTS behavior, package the date-coded RBF and matching helper, and have the user create the annotated `v0.7.0` tag and GitHub pre-release from that exact commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 470 COMMIT Unreleased 9a5eea3 2026-08-24T12:38:50-07:00

#### Coming From:

Unreleased 8c59ddb

#### Purpose:

Prevent sparse presentation timestamps from advancing pictures ahead of the exact-rate cadence while retaining their ability to delay future pictures.

#### Outcome:

Commit `9a5eea3` makes the cadence accumulator a mandatory presentation floor: a timestamped candidate now presents only when both the exact-rate cadence slot and its PTS are due, while an untimestamped candidate continues using cadence alone. The old timestamp-only early-admission branch and its partial-credit reset are gone; picture ownership, B-picture reordering, scratch allocation, cadence constants, timestamp association, transport, profiler and audio logic are unchanged. The directed scheduler proof holds an already-due timestamp while cadence is early, admits it on the first cadence-due window, preserves a future timestamp's ability to delay through safe windows, prevents the following untimestamped candidate from bursting, includes timestamped swaps in the minimum-gap invariant, and retains exact counts of 479, 240, 250, 599 and 600 presentations for 23.976, 24, 25, 29.97 and 30 fps respectively. Picture timestamp, PTS timeline, transport gate, download rearm, system clock, in-band metadata, clean-video queue, PCM output, 8,192-frame PCM FIFO and schema-nine profiler regressions all pass. Quartus 17.0.2 completes in ten minutes 31 seconds with zero errors and 147 established warnings. Timing is met with global worst setup slack 0.311 nanoseconds, hold 0.238, recovery 3.365, removal 0.497 and minimum pulse width 1.122; Phase-1P reports find decoder same-clock setup slack 1.782 across 100 paths with none violated, decoder recovery 11.294 and video same-clock setup 8.284 across 80 paths with none violated. The fit uses 29,325 ALMs, 45,259 registers, 3,655,139 memory bits at 65 percent, 464 of 553 RAM blocks at 84 percent and 65 DSP blocks. The 4,184,380-byte RBF is SHA-256 `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`. Installation used plain FTP with the default MiSTer login and no SSH keys: the prior active `8c59ddb` image first verified at SHA-256 `c2ebbfa10935d43ff0d7e66ae0c6468b63385f29ff5a154f9a50b8725dfa5ea1`, its rollback copy verifies byte-identically as `/media/fat/MediaPlayer.backup.pre-pts-floor.8c59ddb.rbf`, the staged candidate and final active image both verified byte-identically at the new hash, and the temporary staged file was removed; helper, Main and media files are unchanged.

#### Next Steps:

Power-cycle once to load `9a5eea3`, set Audio Test to Off and run `20_bbb_full_48k.mpg` end to end without interruption, watching the credits specifically for the former approximately one-second beat and leaving the final diagnostic image loaded for capture. Require all 84,423,309 clean-video bytes and all 14,315 pictures to complete, sequence end and quiet reason one, aggregate errors zero, and both audio underrun and PCM protocol error clear. Schema nine's `timestamp_advance_conflicts` counter observes the PTS-due versus cadence-early opportunity rather than an actual swap, so it may still report approximately 97 after this correction; the scheduler now suppresses those opportunities by construction. If the user sees smooth credits and correctness remains clean, accept `9a5eea3`; if the cadence remains, preserve this result and investigate the separately measured 66.3168-millisecond scratch-unavailable reorder gaps rather than revisiting timestamp admission. Roll back to `/media/fat/MediaPlayer.backup.pre-pts-floor.8c59ddb.rbf` for any correctness, completion or audio regression.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 469 COMMIT Unreleased 8c59ddb 2026-08-24T12:33:55-07:00

#### Coming From:

Unreleased 8c59ddb

#### Purpose:

Capture the schema-nine full-soak credits window and identify the mechanism behind the remaining visible cadence.

#### Outcome:

The user again sees the slight credits cadence on the diagnostic image. The completed screenshot was captured exclusively through plain FTP with the default MiSTer login and no SSH keys; `.ai/current_results/entry469_full_soak_credits_window.png` is 8,102 bytes with SHA-256 `747774eafd35e0239072f090a3dc27492bf9628a86fe828a02f4388b8cc8381d`. Schema nine passes every correctness invariant: all 84,423,309 clean-video bytes were accepted, aggregate error flags are zero, audio underrun and PCM protocol error are clear, sequence end was seen, presentation completed, and the snapshot closed normally for quiet reason one at STC second 596. The late window begins at second 500 and records 97 timestamp-advance conflicts but zero timestamp-delay conflicts. That is one early-admission conflict per 0.990 seconds across the 96-second observation window, matching the approximately one-second beat the user sees and directly isolating it to the timestamp-to-cadence handoff. Each conflict is an eligible raster window where the sparse PTS says the candidate is due while the exact-rate cadence accumulator says it is not yet due. The current scheduler lets the timestamp replace the cadence gate, displays that picture early, and clears partial cadence credit, so each roughly one-second timestamp can perturb otherwise exact 24 fps pacing. The three largest late-window gaps are all 3,979,008 decoder cycles or 66.3168 milliseconds with a cadence slot ready but no presentable candidate and no scratch bank available; thirty late outliers therefore also preserve evidence of reorder pressure, but that signature cannot explain the one-second periodicity as closely as the 97 timestamp conflicts do. The observational `8c59ddb` image is consequently accepted: it leaves playback and all transport/audio completion invariants unchanged and distinguishes the residual mechanism as designed.

#### Next Steps:

Make the narrow timestamp-admission correction only after approval: retain the exact-rate cadence gate as a mandatory floor, allowing a timestamped candidate to wait when its PTS is not due but never allowing an already-due sparse PTS to advance the candidate before the next cadence slot. Preserve every ownership, reorder, scratch-bank, accumulator-rate and audio-path rule. Prove in scheduler simulation that the 97 advance-conflict class no longer causes an early swap, that a future timestamp can still delay presentation, and that all supported free-running cadence sequences remain bit-exact; then run the focused regressions, build, install through plain FTP with an exact rollback, and repeat the full movie. Hardware acceptance requires the credits beat to disappear without reintroducing audio underrun, completion errors, missing pictures or a new timestamp-delay stall.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 468 COMMIT Unreleased 8c59ddb 2026-08-24T12:18:50-07:00

#### Coming From:

Unreleased cd8d78a

#### Purpose:

Add passive late-window cadence telemetry that distinguishes timestamp admission conflicts from scratch-scheduler stalls during the movie credits.

#### Outcome:

Commit `8c59ddb` implements the approved diagnostic without changing a presentation or transport decision. The schema-nine profiler begins a distinct gap timeline at the first display after STC second 500, ranks only later gaps, retains timestamp-active, timestamp-due, free-cadence, candidate-presentable and swap-window state in the previously reserved gap metadata bits, and uses the former promotion-hold word for saturated counts of exact timestamp-delay and timestamp-advance conflicts at eligible raster windows. The scheduler exports its existing cadence-slot and presentable-candidate terms through combinational observation outputs only. The fixed thirty-eight-word overlay, aggregate completion, byte, picture, audio, error and terminal fields remain intact, and the decoder remains backward-compatible with schema eight while interpreting the new fields in schema nine. Simulation proves that large pre-window gaps are excluded, both conflict directions are counted only at or after the gate, ranked threshold-crossing state and checksum survive, the exported scheduler terms are exact mirrors and every supported cadence remains unchanged; the picture timestamp, PTS timeline, scheduler, transport gate, download rearm, system clock, extractor, clean-video queue, PCM output and 8,192-frame PCM FIFO regressions pass. Quartus 17.0.2 completes in nine minutes 58 seconds with zero errors and 147 warnings. Timing is met with global worst setup slack 0.467 nanoseconds, hold 0.249, recovery 3.992, removal 0.515 and minimum pulse width 1.122; Phase-1P reports find decoder same-clock setup slack 1.249 across 100 paths with none violated, decoder recovery 11.433 and video same-clock setup 6.940. The fit uses 29,174 ALMs, 45,103 registers, 3,655,139 memory bits at 65 percent, 464 of 553 RAM blocks at 84 percent and 65 DSP blocks, so the observational change adds no RAM and the small ALM and register decreases from `cd8d78a` are fitter variance. The 4,169,564-byte RBF is SHA-256 `c2ebbfa10935d43ff0d7e66ae0c6468b63385f29ff5a154f9a50b8725dfa5ea1`. Installation used plain FTP with the default MiSTer login and no SSH keys: the active `cd8d78a` image first verified at SHA-256 `39106371e9f26a5a0bc62e703bd5df33f9ea07882fc8d8002cb7e0bc6e9b55f3`, the staged diagnostic roundtrip verified byte-identically, the new active image verifies at the candidate hash, and `cd8d78a` is preserved exactly as `/media/fat/MediaPlayer.backup.pre-credits-window.cd8d78a.rbf`; helper, Main and media files are unchanged.

#### Next Steps:

Power-cycle once to load `8c59ddb`, set Audio Test to Off and run `20_bbb_full_48k.mpg` once without interruption, watching the credits for the same tiny cadence and leaving the final image loaded for a schema-nine capture. Require playback to remain otherwise unchanged, all 84,423,309 clean-video bytes and 14,315 pictures to complete, sequence end and quiet reason one, aggregate errors zero, and both audio underrun and PCM protocol error clear. A nonzero timestamp-delay or timestamp-advance count correlated with the ranked post-500-second gaps selects the timestamp-to-cadence handoff for the next fix; zero conflicts with scratch-unavailable or reorder scheduler state selects scratch ownership. Any correctness or audio regression rejects the diagnostic immediately and should be rolled back to `/media/fat/MediaPlayer.backup.pre-credits-window.cd8d78a.rbf` before further work.

#### Files Modified:

- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 467 COMMIT Unreleased cd8d78a 2026-08-24T11:44:23-07:00

#### Coming From:

Unreleased cd8d78a

#### Purpose:

Record the clean-video queue's complete hardware soak and separate the eliminated audio failure from the remaining slight credits cadence.

#### Outcome:

The user watched `20_bbb_full_48k.mpg` end to end on `cd8d78a` and reports only a tiny cadence in the credits, with USER and POWER solid on and DISK blinking eleven times. The final screenshot was captured exclusively through plain FTP with the default MiSTer `root` login and no SSH keys; the 8,093-byte file is SHA-256 `f25b0935d55afd3caaa5dfd15dfeb3d249e1942cf6eedd39e2992bac17c6d4ad`. This is the first successful full soak: all 84,423,309 clean-video bytes were accepted instead of freezing at the repeated 35,705,169-byte boundary, aggregate error flags are zero instead of `0x0400`, `audio_pcm_underrun` and PCM protocol error are clear, sequence end was seen, presentation completed and the snapshot closed normally for quiet reason one at an STC of 596 seconds. The eight-bit display counters wrap exactly as expected for all 14,315 pictures and 14,314 swaps, to 235 and 234 respectively, while the timestamp and reference-picture counters saturate or wrap without an error. The largest recorded display gap is now 116.054 milliseconds at ordinal fourteen instead of 431.059 milliseconds, while the next two remain 82.896 milliseconds at ordinals fifteen and seventeen; gap outliers total 224 over the completed movie. The post-extraction queue therefore passes its hardware objective and removes the deterministic audio starvation without removing the residual visual cadence, confirming those were separate faults rather than two observations of one event.

#### Next Steps:

Retain `cd8d78a` as the accepted audio-path baseline and stop before another RTL change. Analyze the remaining presentation cadence against the completed soak's 224 gap outliers, scheduler ownership and scratch-bank availability, using the unchanged 82.896-millisecond ordinal-fifteen and ordinal-seventeen events as the stable signature; propose a narrowly bounded presentation-scheduler change and obtain approval before implementation. Preserve `/media/fat/MediaPlayer.backup.pre-clean-video-queue.6dece4c.rbf` until that follow-on is independently accepted, and keep the current helper, Main and media files unchanged so the next comparison remains controlled.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 466 COMMIT Unreleased cd8d78a 2026-08-24T11:31:01-07:00

#### Coming From:

Unreleased cd8d78a

#### Purpose:

Record the clean-video queue's first hardware diagnostic and decide whether it is safe to proceed to the full soak.

#### Outcome:

The user reports that `23_bbb_opening24_exact_av.mpg` looks the same as the already perfect `6dece4c` run, with USER and POWER solid on and DISK blinking eleven times. The completed screenshot was captured exclusively through plain FTP with the default MiSTer `root` login and no SSH keys; the 545,933-byte file is SHA-256 `f8093abe08bf43974a9c45e94d22f294db4a3f7203efa8f0c01f46edbb46203d`. Schema eight is clean: aggregate error flags are zero, audio underrun and PCM protocol error are false, all 3,138,619 clean-video bytes were accepted, all 194 reference plus 383 B pictures decoded, all 577 pictures displayed with 576 swaps, all 24 timestamps associated, sequence end was seen, presentation completed and the snapshot closed normally for quiet reason one. The queue preserved the exact accepted-byte and timestamp contracts while materially reducing the transient it was sized to absorb: the largest startup display gap fell from 431.059 milliseconds on `6dece4c` to 116.054 milliseconds on `cd8d78a`; the following two 82.896-millisecond gaps remain bit-identical, gap outliers move from thirteen to fourteen, decoder stall remains effectively unchanged at 646,766,052 cycles against 646,658,859, and presentation hold rises from 267,676,803 to 279,210,653 cycles. This passes the short diagnostic and rules out companion timestamp-position corruption, but it does not yet prove that the queue can prevent the deterministic full-soak audio underrun.

#### Next Steps:

Without changing or rebooting the installed image, run `20_bbb_full_48k.mpg` end to end, observe audio and video through the opening, body, high-motion sequence near 7:22, credits and closing sting, report any crackle, dropout or residual cadence plus all three LED states, and leave the final image loaded for another schema-eight capture. Primary acceptance is a normal quiet completion with aggregate error flags zero, `audio_pcm_underrun` and PCM protocol error clear, sequence end seen and all 14,315 pictures accounted for; the visual report separately decides whether the queue also improves the slight credits cadence that survived `6dece4c`. A repeated fatal snapshot at accepted byte 35,705,169 means the post-extraction depth did not isolate the audio path sufficiently and should be analyzed before any further RTL change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 465 COMMIT Unreleased cd8d78a 2026-08-24T11:25:18-07:00

#### Coming From:

Unreleased 6dece4c

#### Purpose:

Decouple clean video from in-band PCM after extraction with a bounded timing-clean queue while preserving timestamp-to-picture ordering.

#### Outcome:

The entry 464 boundary was approved and is commit `cd8d78a`. A 16 KiB clean-video FIFO now sits after `mpeg2_h262_inband_metadata`, so a decoder ownership stall can queue video while the extractor continues crossing later PCM records into the existing audio FIFO; at the full-soak video's measured 138 KiB/s elementary-stream rate this is 115.9 milliseconds, beyond the repeated 82.896-millisecond stalls that exhaust the helper's 4,096-frame or 85.3-millisecond audio reserve, without paying for the unrelated 431-millisecond startup transient. Timestamp ordering could not be assumed: permanent host analysis found only 4,017 clean video bytes between the closest two of the soak's 598 records. A sixteen-entry companion FIFO therefore carries each PTS with its absolute clean-byte position and releases it only when the decoder reaches that position, while a new metadata readiness handshake holds a record's final byte if that companion queue fills. The integrated simulation holds the decoder for the entire input burst, proves three PCM frames still cross, then drains all 160 clean bytes byte-identically and releases two timestamps at exact byte positions 32 and 96; the extractor separately proves metadata backpressure without loss, and the picture timestamp, presentation timeline, scheduler, transport gate, download rearm, system clock, cadence profiler, PCM output and 8,192-frame PCM FIFO regressions pass. The full helper analysis preserves 84,423,309 clean video bytes, 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, 598 timestamps, a 4,052-byte maximum PCM-free span, zero audio deficit and the established 207,888,468-byte transport. Quartus 17.0.2 completes in ten minutes 24 seconds with zero errors and timing met: worst setup slack is 0.512 nanoseconds, hold 0.248, recovery 3.805, removal 0.600 and minimum pulse width 1.122, while the Phase-1P reports show decoder setup 1.519 nanoseconds over 100 same-clock paths with none violated, decoder recovery 10.785 and video setup 7.124. The design uses 29,316 ALMs, 45,115 registers, 3,655,139 memory bits at 65 percent, 464 of 553 RAM blocks at 84 percent and 65 DSP blocks; the queue itself costs 132,112 bits and eighteen RAM blocks, exactly sixteen for video and two for timestamp positions. The 4,196,780-byte RBF is SHA-256 `39106371e9f26a5a0bc62e703bd5df33f9ea07882fc8d8002cb7e0bc6e9b55f3` and was installed through plain FTP after staged roundtrip verification, with the previous 4,110,808-byte `6dece4c` image preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-clean-video-queue.6dece4c.rbf` at SHA-256 `ee7ff41b5cf76693f491d72999b0caa39abd36ff1a2ae7921a2ad7aabb58e940`; the helper, Main and every media file are unchanged.

#### Next Steps:

Power-cycle once to load `cd8d78a`, set Audio Test to Off and run `23_bbb_opening24_exact_av.mpg`, then leave its final image loaded for a schema-eight capture. Require intact audio, smooth video, zero aggregate, PCM protocol, decoder, presentation and destination errors, no audio underrun, all 577 pictures displayed with sequence end and presentation complete, and timestamp association unchanged; a picture-count or timestamp failure means the companion position queue is wrong and calls for immediate rollback to `MediaPlayer.backup.pre-clean-video-queue.6dece4c.rbf`. If that diagnostic is clean, run `20_bbb_full_48k.mpg` end to end and compare the slight credits cadence separately from the fatal condition: primary acceptance is a quiet completion with `audio_pcm_underrun` clear, sequence end and all 14,315 pictures accounted for, while the visual comparison decides whether the queue also affects the residual presentation beat.

#### Files Modified:

- MediaPlayer_top_00.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/analyze_arm_av_transport.py
- tools/streams/tb_h262_clean_video_queue.sv
- tools/streams/tb_h262_inband_metadata.sv
- tools/streams/tb_h262_inband_metadata_file.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 464 COMMIT Unreleased 6dece4c 2026-08-24T10:58:31-07:00

#### Coming From:

Unreleased 6dece4c

#### Purpose:

Record that packed PCM materially improves the visible full-soak cadence but leaves the deterministic audio underrun and its surviving presentation-gap signature unresolved.

#### Outcome:

The user completed `20_bbb_full_48k.mpg` on the packed-record `6dece4c` image and reports that the roughly one-second cadence is now only slight in the credits and looks substantially better overall. A fresh schema-eight screenshot was triggered and retrieved exclusively through plain FTP with the default MiSTer `root` login, without SSH or keys. The 8,112-byte capture is SHA-256 `14226d6bd2b4e690786d9b560ef2f2673af4694ac4679679b7431b71e7b31e98`. It froze for fatal-or-no-progress reason three with aggregate flags exactly `0x0400`, a real `audio_pcm_underrun`; PCM protocol, presentation and destination errors remain clear. The freeze occurs at exactly 35,705,169 accepted clean-video bytes, the same boundary as the `14e0629` soak in entry 461, while gap outliers move only from 132 to 131 and the three largest gaps remain bit-identical at 431.059 milliseconds at display ordinal fourteen and 82.896 milliseconds at ordinals fifteen and seventeen. Packing therefore removed enough shared-path overhead to produce a clear visual improvement, but the exact repeated underrun boundary separates that fatal condition from aggregate record bandwidth and the unchanged gap signature leaves the presentation residue in place. The previously named `mpeg2_h262_stream_transport_gate` is not itself a valid PCM buffering location because its interface sees only the pre-extractor FIFO and decoder ready/valid state; PCM becomes visible only inside `mpeg2_h262_inband_metadata`.

#### Next Steps:

Stop before changing RTL and obtain approval for a revised isolation boundary. The proposed next cycle is to decouple record extraction from decoder backpressure at the actual split point by adding and testing a bounded post-extraction clean-video queue, allowing the extractor to continue reaching PCM records while the decoder temporarily refuses video; size and resource cost must be established before choosing a depth, and the existing pre-extractor clock-domain FIFO must remain sufficient for safe ingress. Deepening `audio_pcm_fifo` is secondary because the fit already uses 446 of 553 RAM blocks and a larger sink only extends the starvation threshold without removing the coupling. Acceptance remains a complete quiet soak with `audio_pcm_underrun` clear, sequence end and all 14,315 pictures accounted for, followed by the 24-second diagnostic and elementary-stream controls to prove that the queue changes neither video bytes nor presentation order; the user's residual credits cadence must also be compared separately because this capture proves it is no longer equivalent to the underrun.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 463 COMMIT Unreleased 6dece4c 2026-08-24T10:41:16-07:00

#### Coming From:

Unreleased 6dece4c

#### Purpose:

Record that the packed record format decodes correctly on hardware and leaves the 24-second diagnostic where it already was, so the soak decides it.

#### Outcome:

The user power-cycled onto the `6dece4c` image and reports `23_bbb_opening24_exact_av.mpg` looking perfect with no stutter at all and normal LEDs. The capture is 545,953 bytes at SHA-256 `706c546680d8f67053c5cd2f37fdefbd43d6deb354b2fca2bc7a94ccb0516fcd`. The format contract holds, which was the first thing this commit had to prove: `pcm_protocol_error` is false, so the extractor and the helper agree about the frame count, aggregate error flags are zero, there is no underrun, all 3,138,619 transport bytes are accepted, 194 reference plus 383 B pictures decode, all 577 pictures display with 576 swaps, sequence end is seen, presentation completes and the snapshot is the normal quiet reason one. A record carrying sixteen frames is decoded into sixteen sample events with the audio intact, on hardware, at a third of the previous path bandwidth.

The cadence counters are unchanged rather than improved, and that should be stated plainly against the acceptance this commit was given. Gap outliers are 13, exactly what `14e0629` measured; presentation hold is 267,676,803 cycles against 266,426,934; decoder stall 646,658,859 against 644,608,100; `hold_scratch_available_cycles` is bit-identical at 2,984,466; and the three largest gaps are the same 431.059 milliseconds at display ordinal fourteen and 82.896 at ordinals fifteen and seventeen. The acceptance recorded in entry 462 was that the outlier count fall below 13 on this file, and it did not. What the user sees as perfect is consistent with the counters: the remaining gaps sit within the first second, where a single hitch during the opening fade is far less visible than the once-per-second beat that record density used to produce across the whole run.

This file was therefore already at its floor before the format change, and cannot separate a bandwidth improvement from no improvement. The soak can, because that is where both surviving symptoms live: the once-per-second beat the user still saw in the credits under `14e0629`, and an underrun that has stood at 21.74, 62.2 and 39.3 seconds across three helpers without ever being attacked at its cause. A 39.2 percent smaller transport and 94 percent fewer records change the shared path's occupancy by more than any previous cycle, and ten minutes is the only measurement that reaches it.

#### Next Steps:

Run `20_bbb_full_48k.mpg` end to end without rebooting and report the cadence through the body and the credits, audio and video alignment at the opening, the high-motion sequence near 7:22 and the closing sting, any crackle or dropout, and all three LEDs, then leave the final image loaded for a schema-eight capture. Acceptance is a quiet snapshot rather than the fatal one the last two soaks produced, with `audio_pcm_underrun` clear, all 14,315 pictures accounted for after eight-bit wrap and sequence end seen. If the underrun is gone, `6dece4c` is the first commit to clear both hardware symptoms and the next question is release qualification rather than diagnosis. If it survives, the remaining candidates are buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so a full video FIFO cannot block audio, and deepening `audio_pcm_fifo`, which the fit report now shows would compete for RAM blocks already at 81 percent. If the credits still beat once a second while the underrun clears, the presentation scratch scheduler is the remaining target, measured against the `scratch_available` and `pending_frame_released` evidence at ordinals fourteen and fifteen.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 462 COMMIT Unreleased 6dece4c 2026-08-24T10:37:34-07:00

#### Coming From:

Unreleased fccb003

#### Purpose:

Carry a run of PCM frames per in-band record, and restore the startup lead the soak measured as an audio-margin gain.

#### Outcome:

The user played `20_bbb_full_48k.mpg` end to end on the `fccb003` helper and reports the once-per-second cadence unchanged with everything else looking and sounding good. The capture is 8,106 bytes at SHA-256 `e12d519815f2474752442c8a6247bdf978f437fd966cf6eb42ed90d285467f45` and the profiler again froze on a fatal condition whose sole aggregate flag is `0x0400`, a real `audio_pcm_underrun`, with PCM protocol, presentation and destination errors clear. It froze at 22,570,377 accepted bytes of 342,083,863, which is 39.3 seconds into the movie against 62.2 seconds under `14e0629` and 21.74 seconds under `f2b2e02`. Removing the startup byte budget brought the underrun forward by 23 seconds, so entry 461's hypothesis is refuted: keeping the compressed FIFO full does not starve the audio sink, and the lead was helping the audio margin even though entry 456 measured it doing nothing for cadence. Every helper change so far has pushed the underrun later, and this one pushed it back.

The arithmetic explains why no helper setting can close this, and it should have been derived earlier. The steady horizon keeps audio at most `PCM_SCHEDULE_RESERVE_FRAMES` ahead, which is 4,096 frames or 85 milliseconds, so the sink's 8,192-frame FIFO is by construction never more than half full. The display gaps this investigation has been chasing are 82.896 milliseconds at their most common and 431.059 at their worst. A path stall longer than the cushion drains the sink, and the cushion cannot exceed the FIFO's 170 milliseconds even if the reserve were raised to fill it, which would reintroduce the full-FIFO blocking that entry 453 set out to remove. The underrun and the cadence are therefore the same defect measured at two sinks: while the shared path is stalled, video misses its deadline and audio drains, and the only reason the underrun moves at all is that each helper change alters how often the path stalls.

Path occupancy explains where the stalls come from. At nine bytes per stereo frame the audio records carry 422 KiB/s while the video they share the path with carries 138 KiB/s, so audio is three quarters of everything crossing, and 48,000 records per second cross a boundary that entries 459 and 460 measured as costing presentation time per record. Packing many frames into one record attacks both: four frames per record cuts the audio to 234 KiB/s and 12,000 records per second, sixteen frames to 199 KiB/s and 3,000 records per second, against a floor of 192 KiB/s for the samples themselves. Sixteen frames per record removes 94 percent of the records and 53 percent of the audio bandwidth.

Both were approved and are commit `6dece4c`, the first FPGA change of this line. The PCM mode byte's six unused bits now carry a frame count, so one record delivers `{count,rate,stereo}` and then that many frames of `{left,right}`; a count of zero is exactly the earlier single-frame encoding, so a transport produced before this change decodes unchanged. `mpeg2_h262_inband_metadata` reads the count, emits one sample event per frame and still holds each frame's final byte until the sink can accept it, so backpressure reaches the producer at frame granularity rather than record granularity; a count above the supported 32 is reported sticky and consumed as one frame, which is what a malformed record did before. The helper packs sixteen frames per record and `PCM_STARTUP_VIDEO_BYTES` is restored at 28,672 bytes, recorded now as the audio-margin measure entry 462 measured rather than the cadence measure entry 455 introduced it as.

The extended `tb_h262_inband_metadata` simulation passes: a three-frame record yields three sample events and leaves the video either side of it untouched, every frame of a two-frame run waits for the sink in turn under held readiness without loss or duplication and with the correct rate and stereo bits, and a count past the supported run is consumed and reported. The Quartus compile is clean at nine minutes 57 seconds with zero errors, and timing is met with worst-case setup slack 0.435 nanoseconds, hold 0.242 and recovery 4.416, while the Phase-1P extraction reports decoder setup worst slack 1.627 nanoseconds over 100 paths with none violated, decoder recovery 11.225 and video setup 7.833. The design fits at 44,722 registers, 3,523,027 memory bits at 62 percent and 446 of 553 RAM blocks at 81 percent.

The transport shrinks without changing what it carries. The soak falls from 342,083,863 to 207,888,468 bytes, 39.2 percent smaller, with roughly 1,789,000 records where there were 28,628,352, while PCM remains 28,628,352 frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, video and timestamps at SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81` and clean video at 84,423,309 bytes. Every bound holds: steady batches within 2,048, PCM-free video spans within 4,052 bytes, audio deficit zero and the startup lead back at 28,654 bytes. The permanent verifier passes at both profiles and both sample rates with maximum sample error two and correlation rounding to one, all fixtures and controls pass under native and address-and-undefined-sanitized helpers, the nine-case envelope retains three passes and six intended failures, and two official GCC 10.2.1 builds are byte-identical at SHA-256 `d61e69ea2240c23419abb9162a06159f9b6c527e838c9a6e52f0bd1855588d34`.

The RBF and the helper were installed together because the frame count is a contract between them, each staged, verified by download, promoted and verified again. The FPGA image is 4,110,808 bytes at SHA-256 `ee7ff41b5cf76693f491d72999b0caa39abd36ff1a2ae7921a2ad7aabb58e940` with its predecessor preserved as `/media/fat/MediaPlayer.backup.pre-pcm-run.091b150.rbf` at SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`, and the helper's predecessor as `/media/fat/linux/MediaPlayer_Helper.backup.pre-pcm-run.fccb003`. Main and every media file are unchanged.

#### Next Steps:

Power-cycle so the new FPGA image loads, set Audio Test to Off and run `23_bbb_opening24_exact_av.mpg`, then leave the final image loaded for a schema-eight capture. Acceptance is the outlier count falling below the 13 measured under `14e0629` with no audio underrun, no PCM protocol error and all 577 pictures displayed; a PCM protocol error would mean the two sides disagree about the frame count and calls for rolling both files back together rather than either alone. Then run `20_bbb_full_48k.mpg` end to end, where the acceptance is a quiet snapshot rather than a fatal one, since the underrun has stood at 21.74, 62.2 and 39.3 seconds across three helpers and this is the first change to attack the bandwidth causing it. If the underrun survives, the remaining candidates are buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so a full video FIFO cannot block audio, and deepening `audio_pcm_fifo`, which the fit now shows would cost RAM blocks already at 81 percent. If the cadence residue survives, the presentation scratch scheduler is next, measured against the `scratch_available` and `pending_frame_released` evidence at display ordinals fourteen and fifteen.

#### Files Modified:

- host/arm/media_player_helper.c
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/analyze_arm_av_transport.py
- tools/streams/strip_inband_pcm.py
- tools/streams/tb_h262_inband_metadata.sv
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 461 COMMIT Unreleased fccb003 2026-08-24T09:31:39-07:00

#### Coming From:

Unreleased 14e0629

#### Purpose:

Revert the startup byte budget after the soak cleared the drift risk and returned an underrun at 62 seconds.

#### Outcome:

The user played `20_bbb_full_48k.mpg` end to end on the `14e0629` helper and reports audio and video perfectly in sync throughout, confirmed by watching the credits, with a small once-per-second cadence still visible and ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. That answers the question the soak was run for: coalescing timestamps to one per encoded group does not cost alignment over ten minutes, so extrapolation across a group is sound and `14e0629` stands on its drift risk. The capture is 8,108 bytes at SHA-256 `52a27c69794e4b1177f8377e1923b249943d6326eaef2a65919777fcf8817ba9`, small because the final raster is black, and it shows the profiler frozen rather than quiet: the snapshot reason is fatal or no progress and the sole aggregate flag is `0x0400`, a real `audio_pcm_underrun`, with PCM protocol, presentation and destination errors all clear. It froze at 35,705,169 accepted transport bytes of 342,083,863, which is 62.2 seconds into the movie, and had already counted 132 gap outliers by then.

The underrun is therefore not fixed on long content, only moved. Entry 451 measured it at 21.74 seconds under `f2b2e02`; it now arrives at 62.2 seconds under a helper whose host analysis reports an audio deficit of zero across the entire movie. That contradiction is informative rather than a measurement error, because the host model asks whether audio crosses ahead of the video timeline and cannot see the other direction of the same coupling: when the compressed video FIFO is full, video bytes block the shared path and the PCM records queued behind them wait, so the sink can starve while the producer is comfortably ahead of schedule. The 24-second diagnostic never reaches that state and shows no underrun; the movie does, twice, at different points under two different helpers.

That makes the startup byte budget from entry 455 a suspect rather than a neutral change. It exists to keep the compressed FIFO as full as possible, which is precisely the condition under which video blocks PCM, and entry 456 already measured that it bought no cadence improvement at all: outliers moved from 174 to 170 and presentation hold from 7,967,197 to 12,376,681 cycles, less than two percent of the distance to the raw control. It is a change that has not paid for itself and that plausibly makes the audio side worse. The cadence residue is unchanged in shape, with the largest gaps still 431.059 milliseconds at display ordinal fourteen and 82.896 at ordinals fifteen and seventeen, the same signature seen under every audio-video helper so far.

The revert was approved and is commit `fccb003`, which removes `PCM_STARTUP_VIDEO_BYTES` and ends the lead on the second picture again while leaving the delivery-order bounds from `cf1d173` and the timestamp coalescing from `14e0629` untouched. The startup lead returns to 5,301 bytes on the diagnostic and 20,564 on both controls, and each of those is exactly four bytes past that stream's second picture start code, which sits at 5,297 and 20,560 respectively. That corrects entry 455, which reported the controls' lead rising from 1,280 bytes: 1,280 was their initial PCM batch, not their lead, and their lead under the two-picture boundary has always been 20,564. The diagnostic figure of 5,301 in that entry was right.

Everything else is unchanged, which is the point of a revert. Removing PCM from the new helper's transport still yields exactly `25_bbb_opening24_gop_pts.m2v` at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0`, the 26-record layout hardware presented with zero outliers, so the lead never touched record placement. The soak keeps 598 timestamps, 84,423,309 clean video bytes, 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, video and timestamps at SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81`, a 342,083,863-byte transport, steady batches within 2,048, PCM-free spans within 4,052 bytes and an audio deficit of zero. All fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope retains three passes and six intended failures with identical statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `dbcbd74a84cb7cb57583c5ac0d4dfb0b5e695148c350551295bb4f4b299338cb`. Only the helper was installed, with `14e0629` preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-lead-revert.14e0629`; no RBF, Main or media file changed.

#### Next Steps:

Run `20_bbb_full_48k.mpg` end to end and report where the underrun lands, which is the only question this commit asks. The comparison is the 62.2-second freeze under `14e0629` and the 21.74-second freeze under `f2b2e02`; a later freeze or a clean quiet snapshot confirms that keeping the compressed FIFO full starves the audio sink through the shared path, while an underrun at the same point exonerates the lead, which stays reverted either way because it was never measured to help. Report audio and video alignment through the credits again, any crackle or dropout, the visible cadence and all three LEDs, then leave the final image loaded for a schema-eight capture. Whatever the result, the dominant cadence mechanism is unchanged and FPGA-side, ordered by the evidence in entry 461: carrying many samples per PCM record, which cuts record count and path bandwidth together and is the only candidate that addresses cadence and underrun at once; buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so a full video FIFO cannot block audio; and deepening `audio_pcm_fifo`, which raises the starvation threshold without changing the coupling that causes it.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
## 460 COMMIT Unreleased 14e0629 2026-08-24T09:14:42-07:00

#### Coming From:

Unreleased 14e0629

#### Purpose:

Record that timestamp coalescing removed the per-second beat and most of the audio-video cadence defect, and hold the result until the ten-minute soak proves alignment.

#### Outcome:

The user ran `23_bbb_opening24_exact_av.mpg` on the `14e0629` helper and reports it running correctly with the beat gone, reserving judgement until the credits are seen, with all LEDs normal. The capture is 545,909 bytes at SHA-256 `840f9b69781815cea1ee38006d0f7346d97d9403c42389e7d2897c2e2b24fd9e`, and it carries the largest single improvement this investigation has produced. Gap outliers fall from 170 to 13 over 24 seconds, presentation hold rises from 12,376,681 to 266,426,934 cycles, presentation stall from 11,794,180 to 262,253,206 and `hold_scratch_available_cycles` from 582,616 to 2,984,466, which is within four cycles of the smooth raw control's 2,984,470. Correctness is unchanged and complete: zero aggregate error flags, no underrun, no PCM protocol error, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. Accepted transport bytes are 3,138,618, exactly the video's own length, so the spurious byte that both 551-record streams accepted is gone with the records that caused it.

The improvement is larger than this cycle predicted and the prediction was wrong in an informative way. Entry 459 measured 21 outliers attributable to 551 records on a stream with no PCM and expected the audio-video file to fall from 170 to about 149. It fell to 13. A record therefore does not cost a fixed amount: on a path already saturated by real-time PCM gating each timestamp costs far more than it does on an idle one, so the two mechanisms compound rather than add. That also revises the accounting recorded in entry 457, where 149 of the 170 outliers were attributed to gating alone; the honest split is that gating remains the enabling condition, since presentation hold is still 266,426,934 against the raw control's 781,845,922, but record density was the larger lever on this content.

Thirteen outliers remain and their shape is unchanged. The largest is 431.059 milliseconds at display ordinal fourteen with the decoder ready, input pending, scratch available and the scheduler reporting presentation complete, the same ordinal and the same signature as the worst gap under `9f83805`. The second and third are 82.896 milliseconds at ordinals fifteen and seventeen, one with both a reorder run and a decode in flight and no scratch available, one with the decoder not ready. Presentation slack at a third of the raw control's is consistent with a path still paced by the audio sink.

#### Next Steps:

Run `20_bbb_full_48k.mpg` end to end before this commit is called good. Cadence is not what the soak is for: sparse timestamps mean presentation extrapolates across a whole encoded group rather than a packet, so the question is whether audio and video are still aligned through the credits and at the final plate, and drift is what would send `14e0629` back to `MediaPlayer_Helper.backup.pre-timestamp-coalesce.9f83805`. Report alignment at the opening, at the high-motion sequence near 7:22, through the credits and at the closing sting, plus any crackle, dropout or visible corruption and all three LEDs, then leave the final image loaded for a schema-eight capture requiring zero aggregate, decoder, presentation, destination, underrun and PCM protocol errors with all 14,315 pictures accounted for after eight-bit wrap. If alignment holds, the remaining cadence work is the dominant mechanism and it is FPGA-side, with three candidates to cost against resource and timing numbers: deepening `audio_pcm_fifo` past any lead the helper can produce, buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, and carrying many samples per PCM record, which after this result is the most attractive of the three because it reduces record count and path bandwidth at the same time.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 459 COMMIT Unreleased 14e0629 2026-08-24T09:10:04-07:00

#### Coming From:

Unreleased 1a6e6b4

#### Purpose:

Coalesce the helper's timestamp records to the density hardware has already run cleanly, after record placement was ruled out and record count was not.

#### Outcome:

The user ran `26_bbb_opening24_pts_noprefix.m2v` and reports a stutter about once a second, resembling the cadence beat seen in earlier 24 and 25 frame-per-second work, with LEDs unchanged at USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,908 bytes at SHA-256 `e50bd5345423e36abec4895d9be9d5ca8e83a08e3a657996afa72e9cc5c11eaa`, and it reproduces the 551-record control rather than improving on it: 21 gap outliers again, the same three largest gaps of 116.054 milliseconds at display ordinal 65, 82.896 at ordinal 196 and 66.317 at ordinal 28, the same 3,138,619 accepted bytes and a bit-identical `hold_scratch_available_cycles` of 6,963,478. Forty-four decoded fields match exactly and the sixteen that differ do so in the fourth significant figure or below. Moving every record off a start-code prefix changed nothing.

That refutes the adjacency reading recorded in entry 458, and the accepted-byte evidence with it: this control has no record on a prefix, presents 577 picture start codes to a pre-extraction scan and still accepts 3,138,619 bytes, so the spurious byte tracks record count rather than record placement and is not the mechanism it looked like. What survives is simpler and is now measured three times over. Zero records give zero outliers, 26 records give zero outliers, and 551 records give 21 outliers whether or not any of them sits on a prefix. The residual cost is per record, at roughly one late presentation for every 26 records carried, and at 551 records over 24 seconds that lands close enough to one per second to be exactly the beat the user describes. Presentation slack is not involved: presentation hold is 783,657,982 cycles against the raw control's 781,845,922, so the decoder has its full reservoir and still misses these deadlines.

The helper's own record density is therefore a defect rather than a fixed cost. It emits one timestamp per video PES packet carrying a timestamp, which is 551 records for 24 seconds of this mux, while the FPGA presented the same 577 pictures perfectly from 26 timestamps and associated 24 of them. Nothing in presentation needed the other 525.

Commit `14e0629` was approved and implements it. A timestamp is written when a sequence or group start code has passed since the last one, or after `PTS_MAX_PICTURE_GAP` pictures so a stream carrying neither boundary still receives one periodically; presentation reconstructs display order from each picture's own temporal reference in between. The timeline itself is untouched, because a chunk still carries its timestamp for the audio horizon whether or not a record is written for it, and both the scheduled and explicit output paths gate identically so the transport contract does not depend on which one produced it. Record counts fall from 551 to 26 on the diagnostic, from 48 to six on both controls, from one to one on the short and faded fixtures and from 13,401 to 598 on the full soak, which is one per encoded group rather than one per timestamped packet.

The strongest host proof is an equality rather than a bound. Removing PCM from the new helper's transport for the diagnostic yields exactly `25_bbb_opening24_gop_pts.m2v` at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0`, the 26-record control that hardware has already presented with zero gap outliers and the same three largest display gaps as unannotated video. The helper now produces that record layout by construction rather than by filtering. Everything else holds: clean video is unchanged at 84,423,309 bytes for the soak and reduces to SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a` on the diagnostic, PCM remains 28,628,352 frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, the startup lead stays at 28,654 bytes, steady batches within 2,048, PCM-free spans within 4,052 bytes and the audio deficit at zero. The soak transport shrinks from 342,199,090 to 342,083,863 bytes, exactly the 12,803 records no longer written, and its video and timestamp stream is now SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81`, which supersedes the long-established `db00682b` figure for that quantity while the video underneath it is unchanged. All fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope retains three passes and six intended failures with identical statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `3a46ee0cba082e970948078c9f6675aca47c2cbe6b02262b90daca653e0a5333`. Only the helper was installed, with `9f83805` preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-timestamp-coalesce.9f83805`; no RBF, Main or media file changed.

#### Next Steps:

Power-cycle, set Audio Test to Off and run `23_bbb_opening24_exact_av.mpg`, the audio-video diagnostic rather than a control, since the helper now produces the proven record layout itself. Require the once-per-second beat to be gone and report what remains, plus all three LEDs, leaving the final image loaded for a schema-eight capture; the expectation is the outlier count falling from 170 by the 21 that record density accounted for, with presentation hold still collapsed near 12,376,681 cycles because PCM gating is untouched. Then run `20_bbb_full_48k.mpg` end to end, because sparse timestamps mean presentation extrapolates for longer and only ten minutes can show whether audio and video are still aligned at the end; drift there, not cadence, is what would send this change back. After that the remaining work is the dominant mechanism and it is FPGA-side, with three candidates to cost against resources and timing: deepening `audio_pcm_fifo` past any lead the helper can produce, buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, and carrying many samples per PCM record, which would cut audio path bandwidth and the per-record cost this cycle measured at the price of a transport format change on both sides.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
