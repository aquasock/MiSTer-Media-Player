## 513 COMMIT Unreleased 9573923 2026-08-25T09:58:18-07:00

#### Coming From:

Unreleased 69a4f20

#### Purpose:

Add a moving final-mux native pattern that distinguishes FPGA field-readout retention from MiSTer scaler or display retention.

#### Outcome:

The user approved the revised diagnostic after review of `.ai/current_results/PXL_20260825_160322728.mp4`, a 56,383,735-byte 13.564622-second Pixel 8 Pro recording at SHA-256 `267561d6246d06ce7ec03f533e979b6b1bd7e15c27fffa8bc01b9f8154adaec6`. The ordinary full-height bar moves and wraps throughout the active playback, while a separate upper-half bar remains fixed at one horizontal position for nearly the entire ten-second session and disappears abruptly when playback completes and the terminal overlay returns. This is not a brief Bob tradeoff, rolling-shutter duplicate or panel afterimage. The paired schema-ten capture accepts the complete 5,007,304-byte stream, represents all 300 pictures and 299 swaps in its wrapped counters, records 300 framebuffer resets, 299 publications, zero superseded unpublished generations, zero prefill misses, a maximum 2,002,005-cycle publication latency, three regular 2,002,000-cycle ranked gaps, normal quiet completion and no error. Commit `9573923` retains the established status-bit-123 static bars and adds status bit 125 as a separately synchronized Static/Moving submode. Moving mode emits a sixteen-pixel pair-identical bar at x positions 48 through 624, holds each for exactly thirty complete frame-window edges, advances ninety-six pixels and wraps through seven positions; pair-identical horizontal references use the common field-row coordinate. This source remains after the framebuffer mux and before the cadence overlay, so decoder, DDR and line-cache pixels are absent while native sync, field signalling and MiSTer's processed-HDMI path remain active. Destination-scoped timing exceptions cut only the two asynchronous menu sources entering stage zero. Directed tests prove unchanged static colors, blanking and sync passthrough, exact hold, jump and wrap behavior, no double-count from a held frame-window level and identical TFF/BFF content. The complete native suite passes field order, mapping, timing, Bob/Weave control, ownership, accelerated presentation, cache refill and schema-ten telemetry; TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, field-DCT rejection remains 82,326 cycles and the canonical mixed I/P/B raster remains exactly 6,529,997 cycles with every error clear. No decoder, scheduler, framebuffer, cache or native timing behavior changes. A clean Quartus Prime 17.0.2 build from empty generated state completed in 10 minutes 45 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.252, 0.251, 3.650, 0.630 and 0.925 nanoseconds. Focused decoder setup and recovery are positive 0.913 and 11.075 nanoseconds and focused video setup is positive 2.661 nanoseconds, all with zero violated paths. Both native menu synchronizer exceptions match without an empty-filter warning. The fit uses 29,271 ALMs, 45,209 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,220,300-byte RBF has SHA-256 `03bb6a504538fd7e62b2877a428e2e570841ccb3d2d834674f163dd580d76642`.

#### Next Steps:

Run a clean Quartus Prime 17.0.2 build from an empty database and require positive global setup, hold, recovery, removal and minimum-pulse-width margins plus positive focused decoder and video timing. If timing closes, stage and round-trip verify the exact RBF through ordinary FTP, preserve the installed `69a4f20` image as rollback and promote only the diagnostic candidate while leaving helper, media, Main and MiSTer configuration untouched. Hardware validation will replay `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` in Bob with Native timing pattern On and Native pattern motion Moving: a retained bar will place the fault downstream in MiSTer's processed-HDMI scaler or display, while clean jumps will place it in FPGA field-specific framebuffer cache or readout.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_00.svh`
- `MediaPlayer_top_01.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_native_timing_pattern.sv`
- `tools/streams/tb_native_480i_timing_pattern.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 512 COMMIT Unreleased 69a4f20 2026-08-25T08:40:51-07:00

#### Coming From:

Unreleased 52a5a64

#### Purpose:

Constrain only the asynchronous first stages of the new framebuffer telemetry synchronizers and restore clean timing without hiding their synchronous delivery paths.

#### Outcome:

The clean Quartus Prime 17.0.2 build of `52a5a64` completed in 10 minutes 34 seconds with zero errors and produced an RBF, but global setup failed at negative 1.883 nanoseconds and is not eligible for installation. Focused timing proved the established same-clock decoder paths remained positive at 1.457 nanoseconds and video paths remained positive at 2.611 nanoseconds. The only two violations were the intentional 54 MHz video-domain `picture_present_rd` and `prefill_deadline_missed_rd` levels entering stage zero of their respective three-stage 60 MHz synchronizers. Their raw asynchronous phase relationship created a 1.850-nanosecond TimeQuest relationship which must not be treated as a synchronous transfer. Commit `69a4f20` adds two destination-scoped false paths to stage zero only, matching the existing project convention for mode, cadence, download, snapshot and cache synchronizers. TimeQuest matches both keepers without an empty-filter warning; stages zero-to-one and one-to-two remain fully timed, and no RTL, diagnostic meaning, clock or functional behavior changes. A second clean Quartus build from an empty database completed in 10 minutes 30 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.206, 0.253, 3.189, 0.461 and 0.925 nanoseconds. Focused decoder setup and recovery are positive 1.873 and 11.235 nanoseconds and focused video setup is positive 3.225 nanoseconds, all with zero violated paths. The fit uses 29,133 ALMs, 44,992 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,237,424-byte RBF has SHA-256 `57cee7a30c9802c256398cbf44875c5c2118b4b912aca0ef08e103467068c673`. Ordinary FTP with the default `root` and `1` login retrieved the active `48c2c87` image at its exact known `a4e7678719072f0790d8bce74f5c29e329eedb8ef5d6163245c2de8328756332` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-69a4f20`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact new hash. The temporary stage is absent; helper, media, Main and MiSTer configuration are unchanged.

#### Next Steps:

Use ordinary FTP with the default `root` and `1` login to verify the active image remains the accepted `48c2c87` RBF, preserve it as `/media/fat/MediaPlayer.rbf.rollback-pre-69a4f20`, round-trip verify a staged `69a4f20` image, promote it and remove only the temporary stage while leaving helper, media, Main and MiSTer configuration untouched. Then repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` in Bob up to three times and leave the first ghosted run's terminal raster displayed for capture. A nonzero prefill miss, superseded unpublished reset or excessive publication latency correlated with the ghost will justify a narrow cache-publication correction; complete publication with regular ranked gaps will clear this FPGA boundary and retain the downstream-display diagnosis.

#### Files Modified:

- `MediaPlayer.sdc`

#### Status:

- [x] Built
- [ ] Passed

---

## 511 COMMIT Unreleased 52a5a64 2026-08-25T08:00:22-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Instrument the intermittent native framebuffer publication boundary without changing decoder, scheduler, cache or output behavior.

#### Outcome:

Commit `52a5a64` adds only passive native framebuffer-publication evidence. The framebuffer exports its video-domain picture-present level and a per-generation sticky indication that the authored first-field origin arrived before the six-line cache prefill was ready; three-stage synchronizers carry both levels to the 60 MHz decoder domain while the existing scheduler-generated framebuffer reset supplies the generation boundary. Cadence schema ten expands from thirty-eight to forty-one words without repurposing the established MPEG, prediction, PCM, scheduler or error fields. Its appended words count generation resets, picture publications, resets which supersede an unpublished generation, prefill deadline misses and maximum reset-to-publication latency, and the checksum moves to word forty. Ranked gaps and timestamp conflicts begin at STC second zero in this diagnostic hardware instance. The overlay moves eight pixels upward to retain all rows inside both diagnostic and native rasters, while the Python decoder accepts both new schema-ten positions and the two legacy schema-nine positions. Directed tests proved an ordinary ready-first publication, a deliberately late prefill which records a miss without publishing unready pixels, and a three-reset/two-publication sequence with one superseded generation; the profiler retained exact counts, nonzero latency and a valid checksum, and both schema versions decoded from both raster layouts. The complete native suite passed field order, exact 4:2:0 mapping, TFF and BFF timing, Bob and Weave control, timing pattern, ordinary ownership, twenty-window accelerated presentation, ordinary and delayed cache refill and the new late-prefill case. All five scheduler frame rates and native field cadence passed. TFF, BFF and progressive reconstruction retained zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, and field-DCT rejection remained 82,326 cycles. The canonical seventy-two-picture mixed I/P/B raster completed all twenty-five reference publications, forty-seven B-picture persistences and seventy-one swaps with exact DDR and reconstruction accounting and zero errors at 6,529,996 cycles. Its historical assertion expects 6,529,997 cycles, but an untouched archived `48c2c87` source snapshot replayed against the exact same 291,641-byte fixture produced the identical cycle-by-cycle trace, identical 6,529,996 terminal count and identical sole assertion, proving the one-cycle expectation drift predates and is independent of this observational commit. No unrelated decoder test was changed or relaxed.

#### Next Steps:

Run a clean Quartus Prime 17.0.2 build and focused timing analysis, preserve the currently installed `48c2c87` image as rollback through ordinary FTP with the default `root` and `1` login, round-trip verify and promote the `52a5a64` diagnostic image, and leave helper, media, Main and MiSTer configuration untouched. Repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` in Bob up to three times and leave the first ghosted run's terminal raster displayed for ordinary-FTP capture. A nonzero prefill miss, superseded unpublished reset or excessive publication latency correlated with the ghost will justify a narrow cache-publication correction; complete publication with regular ranked gaps will clear this FPGA boundary and retain the downstream-display diagnosis.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [ ] Built
- [ ] Passed

---

## 510 COMMIT Unreleased 48c2c87 2026-08-25T07:56:37-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Capture the repeated TFF Bob comparison and determine whether the intermittent native ghost depends on Weave field history.

#### Outcome:

The user changed only HDMI scaler deinterlacer from Weave to Bob, retained Native timing pattern Off and Interlaced output Native 480i, and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` three consecutive times on the exact installed `48c2c87` image. One of the three runs showed the intermittent ghost earlier in the stream, so Weave's multi-field reconstruction history is not its sole cause. Bob is otherwise mostly perfect while the bar moves left to right; the approximately 60 Hz flicker and fuzzy stationary bar are the expected Bob tradeoff from displaying one field at a time rather than reconstructing full vertical detail. All LEDs pass. The untouched terminal screenshot from the run which ghosted was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry509_terminal_drain_bob.png` is 11,976 bytes with SHA-256 `08b22c2e3cb3cfc470ab7a77586d5e45d5ea8f6794550dcf9ed1b21cb93b4b87`. Schema nine accepts all 5,007,304 bytes and its wrapped counts represent exactly 300 decoded pictures, 300 displayed pictures and 299 swaps. Those 299 intervals span 598,786,877 decoder cycles or 9.979781 seconds and deliver 29.960576 pictures per second. Top-field-first remains correct, sequence end is seen, presentation completes, the session reaches quiet reason one and every aggregate, presentation, destination and cache-bank-overlap error is clear. The terminal raster is the correct final authored weave and contains no retained old position. Scheduler ownership and cadence therefore remain clean even in a Bob run where the user saw the live ghost. The current profiler's zero ranked gaps cannot clear an intermittent early-run stall because its hardware instance deliberately begins gap ranking at STC second 500 for the former full-movie credits investigation, far beyond this ten-second fixture. A plausible remaining boundary is the variable reset-and-prefill interval between a scheduler display-bank swap and the framebuffer's next field-origin publication; missing that cache-ready deadline would be invisible to the current swap counter and could affect Bob and Weave alike.

#### Next Steps:

Stop before changing presentation or cache behavior and obtain approval for one observational diagnostic RBF. Begin ranked display-gap capture at STC second zero for short native fixtures and extend the hardware snapshot without repurposing existing MPEG, audio or prediction fields to record framebuffer publication count, authored field origins missed while the post-swap prefill is not ready, maximum swap-to-publication latency and a compact cache refill deadline state. Update the telemetry decoder and focused profiler, framebuffer and native integration regressions, then clean-build and install through rollback-safe ordinary FTP. Repeat the TFF light-motion fixture in Bob up to three times and capture the first run which ghosts. A nonzero missed-origin or excessive publication latency correlated with that run will justify a narrow prefetch/publication correction; exact framebuffer publication with regular ranked scheduler gaps will clear the FPGA delivery path and leave the residual to the downstream display. Do not alter Bob, Weave, native timing or scheduler ownership in the diagnostic commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 509 COMMIT Unreleased 48c2c87 2026-08-25T07:29:58-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Capture the terminal-drain hardware result and separate its accepted presentation completion from the remaining intermittent display-history ghost and faint moving-line artifact.

#### Outcome:

The user reloaded the installed `48c2c87` image and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Playback is materially better and the prior pervasive ghosting is almost gone, but one intermittent event near mid-run retained an old image for a noticeable interval, and the user can still barely see the transient short horizontal lines while the movie is moving; those lines are now gray. USER and POWER are solid and DISK blinks twice. The untouched terminal screenshot was triggered, retrieved and decoded entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry508_terminal_drain_hardware.png` is 11,909 bytes with SHA-256 `6db00f683783d9fbe2aea7579b9e30c228c82ecb47c6e182a2e534b27b593320`. Schema nine accepts all 5,007,304 bytes, and its wrapped reference, display and swap counts of 44, 44 and 43 represent exactly 300 decoded pictures, 300 displayed pictures and 299 swaps. The 299 presentation intervals span 599,109,027 decoder cycles or 9.985150 seconds and deliver 29.944466 pictures per second. Top-field-first remains correct, sequence end is seen, presentation completes, the session reaches quiet reason one and every aggregate, presentation, destination and cache-bank-overlap error is clear. The final raster contains the correct authored last-field weave at x=512 through x=543 and x=516 through x=547 rather than an old terminal position. Commit `48c2c87` therefore passes its bounded terminal-drain objective and eliminates the prior missing final picture. The clean swap count and cadence place the remaining intermittent stuck appearance below scheduler ownership; together with the previously analyzed pair-identical step-hold recording, its working classification remains downstream Weave or display field-history processing. The live-only gray dashes remain unresolved because the terminal still cannot retain them and the cache-bank overlap diagnostic excludes only the monitored same-bank refill collision.

#### Next Steps:

Keep the exact installed `48c2c87` image, Native timing pattern Off and Interlaced output Native 480i, change only HDMI scaler deinterlacer from Weave to Bob and run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` three consecutive times. Report whether any old bar or image persists during any run, whether the faint gray horizontal dashes remain, and the final USER, DISK and POWER states, then leave the last terminal image displayed for another ordinary-FTP capture. Bob removes Weave's multi-field reconstruction history while retaining the decoder, scheduler, DDR frame banks and line-cache path: disappearance of the intermittent ghost with unchanged clean cadence will confirm the established downstream-history classification, while gray dashes in both modes will isolate the next cycle to line-cache delivery instrumentation. Do not change RTL or native timing before this comparison.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 508 COMMIT Unreleased 48c2c87 2026-08-25T04:26:41-07:00

#### Coming From:

Unreleased c78bd15

#### Purpose:

Guarantee that native all-I sequence end releases and presents the final queued picture across every completion, promotion and swap race.

#### Outcome:

The user approved a bounded terminal-drain correction after entry 507 materially improved playback but ended with USER and DISK off and POWER blinking once. The two Pixel 8 Pro recordings `.ai/current_results/PXL_20260825_111447318.mp4` and `.ai/current_results/PXL_20260825_111514313.mp4` are respectively 52,996,175 bytes over 12.844311 seconds at 59.715153 captured frames per second with SHA-256 `7beb985475df4639fb4606302445a24ac2b6ed558553c57b16d8744e84a3fa02`, and 56,185,455 bytes over 13.629356 seconds at 59.503914 captured frames per second with SHA-256 `cf15f7d59e07356dcd0fd92c74d790ebd18b42c6c5f63dc2b89caf9d41e598e1`. Both show the bright bar advancing and wrapping at the corrected rate while retaining the already classified downstream Weave/display-history ghosts. The untouched ordinary-FTP schema-nine capture `.ai/current_results/entry507_tff_light_secondary_queue.png` is 11,841 bytes with SHA-256 `d029cdd623391ff27611b014456e8bbcc2406b860a71f7d392d22408d7de503d`. It accepts all 5,007,304 bytes, decodes all 300 reference pictures as the wrapped count 44, but displays only 299 with 298 swaps as wrapped counts 43 and 42. Those 298 intervals span 597,055,088 decoder cycles and deliver 29.946985 pictures per second with zero aggregate or presentation error and sequence end seen, but terminal quiet remains false because one pending ordinary identity is valid and unreleased. Pixel inspection independently finds the penultimate authored field positions at x=504 and approximately x=508 rather than the final x=512 and x=516 positions. Commit `48c2c87` makes native ordinary sequence-end permission sticky until the primary and secondary identities drain, including terminal events before, coincident with and after secondary completion or promotion. The finite accelerated integration case decoded and presented all eight pictures and finished with no primary, secondary, terminal-latch or hold state. The official native suite passed with forty field ticks, twenty frame windows, the existing ten-picture serialized and thirteen-picture overlapped controls, twenty-one decoded and twenty presented accelerated pictures, ordinary and delayed cache refill, schema-nine cadence telemetry and decoder layout. The full scheduler regression also preserved all cadence rates, timestamp behavior, B-picture ordering and starvation handling. TFF and BFF reconstruction passed with zero out-of-tolerance pixels at 7,926,459 and 7,948,706 cycles, progressive passed at 13,048,137 cycles, field-DCT rejection passed at 82,326 cycles and canonical mixed I/P/B live-raster playback remained exactly 6,529,997 cycles with all error flags clear. A clean Quartus Prime 17.0.2 build completed in 10 minutes 44 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.160, +0.248, +2.959, +0.368 and +0.925 nanoseconds; focused decoder setup and recovery are +1.519 and +11.273 nanoseconds and focused video setup is +3.227 nanoseconds, all with zero violated paths. The fit uses 28,968 ALMs, 44,679 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,151,600-byte RBF has SHA-256 `a4e7678719072f0790d8bce74f5c29e329eedb8ef5d6163245c2de8328756332`. Ordinary FTP with the default `root` and `1` login retrieved the active `c78bd15` image at its exact known `e8e71ce25ba6dd9d783bacb4b62a237bdd0de4d98a8891b00dd5bf82bb80636f` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-48c2c87`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage is absent; helper, Main, media and MiSTer configuration are unchanged.

#### Next Steps:

Run a clean Quartus build and focused timing analysis, preserve `c78bd15` as rollback through ordinary FTP, install the byte-verified image and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Acceptance requires all 300 pictures and 299 swaps, normal quiet completion, no aggregate or presentation error and passing LEDs.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv`
- `tools/streams/tb_native_ordinary_overlap_ownership.sv`
- `tools/streams/tb_native_480i_presentation_integration.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 507 COMMIT Unreleased c78bd15 2026-08-25T03:43:42-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Retain two pending native all-I frames safely when optimized decode momentarily outruns the 29.97-fps presentation boundary.

#### Outcome:

Commit `c78bd15` retains one completed secondary native all-I identity while its predecessor still owns the primary pending slot. It admits only the next safe I-picture classification boundary, then applies payload backpressure until the predecessor presents and the freed display bank becomes the resumed decode destination. Duplicate pending-bank and displayed-bank reuse remain fatal, while P pictures still cannot enter the exception. The accelerated 480i integration model repeatedly exercised this queue with one-field decode latency and completed twenty frame windows with forty field ticks, twenty-one decoded pictures, twenty ordered presentations and no scheduler error. The former three-field controls remained exactly ten serialized and thirteen overlapped decoded/presented pictures. Native cache/cadence tests passed, TFF and BFF reconstruction remained within one code value with zero out-of-tolerance pixels at 7,926,459 and 7,948,706 cycles, the progressive control passed at 13,048,137 cycles, and the canonical mixed I/P/B live-raster result remained exactly 6,529,997 cycles with all decoder, reconstruction and presentation checks clear. A clean Quartus Prime 17.0.2 build completed in 10 minutes 36 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.321, +0.246, +3.444, +0.634 and +0.925 nanoseconds; focused decoder setup and recovery are +1.805 and +9.741 nanoseconds and focused video setup is +2.729 nanoseconds, all with zero violated paths. The fit uses 29,124 ALMs, 44,427 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,150,888-byte RBF has SHA-256 `e8e71ce25ba6dd9d783bacb4b62a237bdd0de4d98a8891b00dd5bf82bb80636f`. Ordinary FTP with the default `root` and `1` login retrieved the active `f866ce2` image at its exact known `acc28e644100e0452e45fcfe9749762d3a690ca8d6da9479cc4a2ac23d736b7b` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-c78bd15`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage is absent; helper, Main, media and MiSTer configuration are unchanged.

#### Next Steps:

Restart hardware validation at `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Confirm that the complete moving bar now reaches the right edge, that presentation remains smooth and stable, and that USER/DISK/POWER all report pass before marking this entry passed.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv`
- `tools/streams/tb_native_ordinary_overlap_ownership.sv`
- `tools/streams/tb_native_480i_presentation_integration.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 506 COMMIT Unreleased f866ce2 2026-08-25T03:40:25-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Capture the first optimized TFF Weave hardware run and distinguish decoder throughput from presentation ownership.

#### Outcome:

The user opened `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, the renamed HDMI scaler deinterlacer set to Weave and Interlaced output set to Native 480i. The image looks better, but the moving bar stops before crossing the screen; USER and DISK are solid off and POWER blinks once. The untouched image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry506_tff_light_weave_throughput.png` is 12,014 bytes with SHA-256 `9d17a5d3523c7f090576e99516b51d9e7bd4590b482c8972846abee379cbcaef`.

Schema nine freezes for fatal-or-no-progress reason three after accepting only 283,775 of 5,007,304 bytes, decoding seventeen I pictures and displaying fifteen with fourteen swaps; sequence end and session quiet are absent. The first-to-last presentation span is 28,123,416 decoder clocks or 0.4687236 seconds, delivering 29.868349 pictures per second across the short fourteen-interval window. Top-field-first remains correct, audio and PCM errors are clear, no cache-bank or destination overlap error appears and the decode/presentation result otherwise remains coherent. The sole aggregate bit is `0x0200`, `presentation_error`. At the freeze, the scheduler has a released primary pending frame while the optimized overlap decode has already completed the next frame; `pending_frame_valid` and `pending_frame_released` are both set, `ordinary_reference_decode_open` has just closed and the current scheduler intentionally treats completion before predecessor presentation as fatal. The prior measured-latency regression modeled a three-field or approximately 50-millisecond decode and explicitly asserted this early completion must fail. Removing the IQ replay shortened a light all-I picture enough to reach that formerly impossible state. The throughput fix therefore succeeds, but exposes a latent one-slot ordinary-presentation queue limit rather than a decoder, field-order, scaler-mode or pixel fault.

#### Next Steps:

Do not run Bob or BFF on `f866ce2`; they will reach the same field-order-independent scheduler boundary. Obtain approval for one bounded presentation-queue correction that preserves the direct IQ-to-IDCT throughput. Extend only native untimestamped frame-rate-code-four all-I ordinary ownership from one pending identity to the two pending identities physically supported by the three ordinary DDR banks: if an overlap decode completes before its predecessor presents, retain the completed bank in a secondary slot, stop further payload before any bank can be reused, promote that slot when the predecessor swaps and resume into the newly freed bank. Add an accelerated integration regression that reproduces the seventeen-decoded/fifteen-displayed failure, proves sustained 29.97-fps presentation with bounded backpressure and validates premature completion as safe only in this exact native all-I class; retain fatal guards for displayed-bank reuse, bank duplication, P/B, timestamps and all non-native modes. Re-run the complete native, reconstruction and mixed I/P/B suites, clean-build, install through rollback-safe ordinary FTP and restart the four-mode hardware matrix from TFF Weave.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 505 COMMIT Unreleased f866ce2 2026-08-25T03:34:13-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Place the native-interlace cadence fixtures under the MiSTer MediaPlayer directory for convenient hardware validation.

#### Outcome:

The existing `/media/fat/_cadence` directory was copied, not moved, to `/media/fat/MediaPlayer/_cadence` using only ordinary FTP with the default MiSTer `root` and `1` login and no SSH. All eighteen files were downloaded from the original folder, uploaded into the new folder and downloaded again; every source and destination SHA-256 pair matched. The copied set includes the TFF and BFF light-motion fixtures required for commit `f866ce2`, the longer interlaced fixtures, the step-hold diagnostic, the preserved cadence RBF and the existing MGL controls. The original `/media/fat/_cadence` contents remain intact, and no RBF, Main, helper, configuration or media outside the new copy was changed.

#### Next Steps:

Reload the installed `f866ce2` core, leave `Native timing pattern` Off, choose `HDMI scaler deinterlacer` Weave and `Interlaced output` Native 480i, then open `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v`. Report motion smoothness, ghosting or flicker and all three LED states, and leave the terminal image displayed for an ordinary-FTP schema-nine capture. Follow with TFF Bob, BFF Weave and BFF Bob only after each preceding result is captured.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 504 COMMIT Unreleased f866ce2 2026-08-25T03:04:24-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Remove the serialized inverse-quantization replay that limits full-D1 all-I playback and publish the approved two-tier output wording.

#### Outcome:

Commit `f866ce2` streams each finalized inverse-quantized coefficient directly into the already-idle IDCT instead of first storing and replaying the complete 64-coefficient block. The parser continues to wait for completed reconstruction before admitting another block, so coefficient order, saturation, mismatch control, IDCT arithmetic and block ownership remain unchanged. The TFF four-picture reconstruction falls from 10,000,059 to 7,926,459 clocks and BFF falls from 10,022,306 to 7,948,706: both remove exactly 2,073,600 clocks, equal to 64 clocks times 8,100 blocks times four pictures. At 60 MHz those results correspond to approximately 30.28 and 30.19 pictures per second including the regression's framing overhead and pass the new 8,008,000-clock four-picture implementation gate for 29.97 fps. All 2,073,600 TFF samples retain the established 9,442 one-LSB differences, all BFF samples retain 9,632, the progressive control retains 69,671 and every case has zero pixels outside the one-LSB IDCT tolerance; the field-DCT rejection control also remains exact. The complete native suite passes stable TFF/BFF order, exhaustive 4:2:0 cache mapping, exact half-line timing, Bob/Weave selection, timing-pattern isolation, safe ownership, measured-latency overlap, ordinary/delayed refill behavior and schema-nine telemetry. The canonical 72-picture mixed I/P/B live-raster soak remains bit-exact at its 6,529,997-clock signature with all publication, prediction, DDR and presentation counters correct and every error clear. The menu now names `HDMI scaler deinterlacer`, and the README, architecture, decoder notes and changelog document processed-HDMI Bob/Weave separately from Native 480i plus MiSTer's external `direct_video` requirement.

A clean Quartus Prime 17.0.2 build completes in 10 minutes 23 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.128, +0.251, +3.352, +0.449 and +0.925 nanoseconds; focused 60 MHz decoder setup and recovery are +1.543 and +11.393 nanoseconds and focused video setup is +2.658 nanoseconds, all with zero violated paths. The fit uses 28,969 ALMs, 44,696 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs, reducing the prior Bob/Weave build by 599 ALMs and 819 registers with unchanged memory. The 4,171,412-byte RBF has SHA-256 `acc28e644100e0452e45fcfe9749762d3a690ca8d6da9479cc4a2ac23d736b7b`. Ordinary FTP with the default `root` and `1` login and no SSH first retrieved the active `4e4da3a` image at its known `94d194e36f7deeacaf899934547860366a8649455e8c4f0d15ac51e478d90aff` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-f866ce2`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage was removed; Main, helper, media and MiSTer configuration are unchanged.

#### Next Steps:

Perform a clean Quartus Prime 17.0.2 build and the Phase-1P timing review. If fit and timing pass, stage the exact RBF through ordinary FTP with the default MiSTer `root` and `1` login, retrieve it for byte verification, preserve the current `4e4da3a` image as rollback and promote the candidate without changing Main, helper, media or MiSTer configuration. Reload the core and run the established TFF and BFF light-motion fixtures in both Weave and Bob. Hardware acceptance requires the schema-nine picture rate to reach native 29.97-fps presentation without errors or dropped pictures while retaining the already accepted field order and the expected scaler-mode visual tradeoff.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv`
- `tools/streams/tb_h262_interlaced_i_reconstruction.sv`
- `MediaPlayer_top_00.svh`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/MPEG2_NEW_DECODER.md`
- `CHANGELOG.md`

#### Status:

- [x] Built
- [ ] Passed

---

## 503 COMMIT Unreleased 4e4da3a 2026-08-25T02:59:35-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Capture the TFF processed-HDMI Bob result and complete field-order validation of the Bob/Weave control.

#### Outcome:

The user ran `_cadence/native_480i_tff_light_10s.m2v` with native 480i active and Bob selected and reports issues broadly similar to BFF Bob with slight visual differences, followed by USER and POWER solid and DISK blinking twice. The untouched terminal image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH; `.ai/current_results/entry503_tff_light_hdmi_bob.png` is 11,865 bytes with SHA-256 `9bfbb7f0595707877835dd38f8b2ab2458086fc83314b037725d742d6d3cb604`. Schema nine accepts all 5,007,304 bytes, preserves top-field-first, reaches sequence end and presentation completion, closes normally for quiet reason one and reports zero aggregate, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors. The wrapped picture and swap counters again represent all 300 pictures and 299 swaps. First presentation is cycle 2,378,246 and last is 719,313,464, so 299 intervals span 716,935,218 cycles or 11.948920 seconds and deliver 25.023181 pictures per second. This differs from BFF Bob by only 304,372 cycles or 5.072867 milliseconds across the whole run, and from the accepted TFF Weave run by only 609,880 cycles or 10.164667 milliseconds; those small decoder-runtime variations cannot explain the reported mode-specific live appearance. The TFF and BFF Bob terminal rasters are structurally equivalent apart from the expected field-marker and field-phase content, while both field orders remain logically exact. The current result therefore closes the discriminator: residual shorter shadows, more frequent visible steps and slight instability are field-order-independent behavior of MiSTer's processed-HDMI Bob reconstruction combined with the separate approximately 25-picture-per-second all-I decoder ceiling, not reversed fields or corruption. Commit `4e4da3a` passes its hardware objective because Bob and Weave are both selectable, preserve native/raw and progressive behavior and expose the intended motion-versus-stability tradeoff without correctness errors.

#### Next Steps:

Freeze the Bob/Weave control and do not attempt another deinterlacer implementation. Retain Weave for users prioritizing stable vertical detail and Bob for users prioritizing shorter motion history, while Native 480i remains the unprocessed external-processing tier. Bundle the already approved menu wording `HDMI scaler deinterlacer` and two-tier documentation with the next materially useful source build rather than spending a Quartus cycle on labels alone. The next technical proposal should address the independent approximately 25-picture-per-second full-D1 all-I throughput ceiling that now dominates the remaining visible jumps, beginning with measured decoder-stage occupancy and a bounded optimization that preserves TFF/BFF timing, field order and the now accepted scaler selection; native direct-video and eventual SDI qualification remain separate until compatible hardware is available.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 502 COMMIT Unreleased 4e4da3a 2026-08-25T02:55:54-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Capture the BFF processed-HDMI Bob result and separate decoder cadence from the scaler's deinterlacing tradeoff.

#### Outcome:

The user ran only `_cadence/native_480i_bff_light_10s.m2v` with native 480i active and Bob selected. The menu disappears normally, motion now appears to run at the right field rate, the historical shadow lags for less time but jumps more frequently and the final image is slightly unstable; USER and POWER remain solid and DISK blinks twice. The untouched terminal image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH; `.ai/current_results/entry502_bff_light_hdmi_bob.png` is 11,860 bytes with SHA-256 `3970ae3eedcc91b6fa75d2fca0fad253d6aef63d849d4708c9328bfadfabd5b0`. Schema nine accepts all 5,007,154 bytes, preserves bottom-field-first, reaches sequence end and presentation completion, closes normally for quiet reason one and reports zero aggregate, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors. The eight-bit picture and swap counters wrap to 44 and 43 exactly as expected for 300 pictures and 299 swaps. First presentation remains cycle 2,378,235 and last presentation is cycle 719,009,081, so the 299 intervals span 716,630,846 cycles or 11.943847 seconds and deliver 25.033809 pictures per second. The prior Weave run delivered 25.037584 pictures per second and finished only 108,033 decoder cycles or 1.80055 milliseconds earlier across the entire fixture, proving Bob did not materially change decoder throughput or source presentation cadence. The shorter history, more visible steps and live final-image instability instead characterize MiSTer's Bob reconstruction: it removes most long field history by expanding individual fields, at the expected cost of greater vertical jitter and reduced stable vertical detail. BFF core logic passes, while processed-HDMI Bob remains a user-selectable motion-versus-stability tradeoff rather than a universal replacement for Weave.

#### Next Steps:

Keep `Native timing pattern` Off, `HDMI deinterlacer` Bob and `Interlaced output` Native 480i, then run only `_cadence/native_480i_tff_light_10s.m2v`. Compare shadow duration, step frequency and final-image instability directly with this BFF Bob result, report all three LEDs and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Matching clean telemetry and materially similar Bob artifacts will show the residual is field-order-independent scaler behavior and complete the current Bob/Weave control validation; a strong TFF/BFF visual asymmetry would instead require checking how the framework's Bob path interprets field polarity before refining the two-tier menu. Do not change MiSTer configuration or run the native direct-video/SDI tier yet.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 501 COMMIT Unreleased 4e4da3a 2026-08-25T02:50:47-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Adopt a permanent two-tier output model serving processed-HDMI viewers and native-480i external-processing users.

#### Outcome:

The user approved two explicit product tiers going forward: a normal processed-HDMI path using MiSTer's scaler with user-selectable Bob or Weave deinterlacing, and a separate Native 480i path that preserves correctly ordered, standards-timed decoded fields for eventual HDMI-to-SDI conversion and high-end external processing. The native tier must not silently deinterlace, scale or field-combine the source, while the convenience tier may use MiSTer's existing reconstruction and should clearly identify that processing in the menu and documentation. The current `4e4da3a` build already supplies native 480i timing and the scaler's Bob/Weave request, but MiSTer's `direct_video` bypass is framework configuration supplied through `cfg[10]`, not a signal this core can switch through its own status menu. Future menu work may select and label the core's intended output tier, but documentation and UI must not imply that this alone enables raw HDMI; actual SDI qualification will use the Native 480i tier together with MiSTer's direct-video setting and a compatible converter or sink.

#### Next Steps:

Complete entry 500's installed-build validation before changing the menu again: run the BFF light-motion fixture with Bob selected, capture visual and schema-nine evidence, then repeat the TFF fixture if BFF passes. After those results settle the processed-HDMI path, propose one bounded menu and documentation refinement that names the processed control `HDMI scaler deinterlacer`, presents Native 480i as the external-processing tier, suppresses or clearly marks irrelevant combinations and documents the separate MiSTer direct-video requirement. Do not implement a core-native deinterlacer or claim SDI readiness until raw-output timing has been tested on a compatible direct-video sink or converter.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 500 COMMIT Unreleased 4e4da3a 2026-08-25T02:45:02-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Expose MiSTer's processed-HDMI Bob/Weave choice without altering native raw 480i or progressive output.

#### Outcome:

Commit `4e4da3a` replaces the hardwired `HDMI_BOB_DEINT=0` with a clock-domain-safe `HDMI deinterlacer` menu control on status bit 124, retaining Weave as the default and asserting MiSTer's existing Bob request only while native interlaced output is active; direct video continues to carry the core's raw fields and progressive output always suppresses the request. The focused selector test passes reset, native Weave, native Bob, progressive suppression and return cases. The complete native timing suite passes stable and changed-order handling, exhaustive 4:2:0 mapping, exact TFF and BFF half-line timing, timing-pattern isolation, ordinary ownership, measured-latency presentation, ordinary and delayed cache refills, cadence-profiler schema and decoder layout. TFF/BFF interlaced reconstruction also passes with zero out-of-tolerance samples and the progressive control remains distinct. The Icarus live-raster wrapper reproduced all functional counts with zero functional errors but ended one scheduler cycle below its fixed wrapper expectation; the independently regenerated input was byte-identical and the canonical Verilator live-raster run passed the exact 6,529,997-cycle expectation with every error counter clear. A clean Quartus 17.0.2 build completed in 10 minutes 59 seconds with zero errors, full-design setup, hold and recovery slack of 0.184, 0.231 and 3.194 nanoseconds, focused decoder setup and recovery slack of 1.357 and 10.515 nanoseconds and focused video setup slack of 2.432 nanoseconds. Fit uses 29,568 ALMs at 71 percent, 45,515 registers, 3,655,139 memory bits at 65 percent, 464 RAM blocks at 84 percent and 67 DSP blocks at 60 percent. The 4,184,000-byte RBF has SHA-256 `94d194e36f7deeacaf899934547860366a8649455e8c4f0d15ac51e478d90aff`; it was uploaded and retrieved under a staging name, promoted through ordinary FTP with the default `root` and `1` login and retrieved again at the exact local hash. The predecessor remains `/media/fat/MediaPlayer.rbf.rollback-pre-4e4da3a` at SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. No helper, Main, media or MiSTer configuration changed.

#### Next Steps:

Reload the core, leave `Native timing pattern` Off, select `HDMI deinterlacer` Bob and `Interlaced output` Native 480i, then run only `_cadence/native_480i_bff_light_10s.m2v`. Judge rightward motion, field-marker order, bob shimmer or vertical-detail loss and specifically whether the long historical bars and retained OSD disappear; report all three LEDs and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Acceptance requires the prior clean logical telemetry plus materially shorter field history than Weave. If BFF Bob passes, run the TFF light-motion fixture second under the same settings. Keep the public native-interlace claim disabled until both are captured, keep raw direct-video qualification separate and defer a core-native deinterlacer unless MiSTer's scaler path proves inadequate or a distinct core-generated 480p mode is approved.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- files.qip
- rtl/mpeg2_hdmi_deinterlace_control.sv
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_hdmi_deinterlace_control.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 499 COMMIT Unreleased baf5d2c 2026-08-25T02:06:54-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Capture the BFF hardware run and distinguish core field-order failure from artifacts introduced by the active MiSTer HDMI scaling path.

#### Outcome:

The user ran `_cadence/native_480i_bff_light_10s.m2v`, reports many visible issues and the expected terminal LEDs with USER solid, DISK blinking twice and POWER solid. The untouched terminal image was captured entirely through ordinary FTP with the default login and no SSH; `.ai/current_results/entry498_bff_light_native480i.png` is 11,828 bytes with SHA-256 `e08199714000955a47588255aef8aacd7b9902467458f32e891363342e825332`. Schema nine accepts exactly all 5,007,154 source bytes, reconstructs all 300 reference and displayed pictures and 299 swaps from the wrapped counters, reports stable bottom-field-first with `top_field_first=0`, reaches sequence end and presentation completion and closes normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. First presentation at cycle 2,378,235 and last at 718,901,048 span 716,522,813 cycles, or 11.942047 seconds and 25.037584 pictures per second, materially matching the accepted TFF light-motion rate.

The user's 61,120,546-byte, 14.788667-second Pixel 8 Pro recording `.ai/current_results/PXL_20260825_085714649.mp4` is SHA-256 `4646fc58721626cac3f5da1fcd0d49712f8c93632f602af7ebf90ab6203846a9` and averages 59.775504 captured frames per second. Frame-by-frame review shows the bright current bar progressing monotonically to the right with no field-order backstep or reversal, while a dim historical bar trails many source fields behind and portions of the already closed MiSTer OSD remain visible during startup. The fixture's decoded BFF planes independently place the bottom-field bar at x=40 before the top-field bar at x=44, then advance both four pixels per field; the timing and framebuffer regressions and hardware telemetry preserve that order. Because the OSD is composited after the MPEG framebuffer, its retained shapes cannot originate in decoder DDR or line caches. An ordinary-FTP inspection also finds no active `/media/fat/MiSTer.ini`; the installed example documents `direct_video=0` as the default. The run therefore feeds the core's native 480i into MiSTer's `ascal` path rather than sending raw 480i to HDMI, and `MediaPlayer_top_00.svh` currently hardwires `HDMI_BOB_DEINT=0`, selecting the scaler's weave and field-buffer path. The recording is consistent with field-history retention in that path, potentially compounded by the monitor and phone, not BFF decoding or field-order reversal. BFF logical acceptance passes, but visual acceptance through the current scaled-HDMI weave path does not.

#### Next Steps:

Stop and obtain approval for a revised bounded scaler-path commit before addressing decoder throughput. Add an `HDMI deinterlacer` menu choice using the next free status bit, retain Weave as the existing default and drive MiSTer's already implemented `HDMI_BOB_DEINT` only when native interlaced output is active and Bob is selected; direct-video raw 480i and progressive output must remain unchanged. Add a focused control regression proving progressive always requests no bob, native Weave remains zero and native Bob asserts the framework signal, retain all TFF/BFF timing, framebuffer and presentation regressions, then complete a clean Quartus build and staged ordinary-FTP installation. Rerun BFF light motion in Bob mode first and TFF light motion second, requiring monotonic motion without long historical bars or retained OSD. Do not create or alter `MiSTer.ini` and do not enable `direct_video` without separate user direction; raw-output qualification on a compatible sink remains a later, distinct test, and the public interlace claim stays disabled.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

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
