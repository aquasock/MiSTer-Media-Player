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

## 521 COMMIT Unreleased bfb9361 2026-08-25T20:30:53-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Correct the deployment-path diagnosis and install the verified schema-fourteen candidate rollback-safe.

#### Outcome:

Entry 520's reported active-image mismatch came from using a relative FTP URL with curl's single-directory method, which resolved a different server object containing the user-identified bad compile rather than the authoritative absolute `/media/fat/MediaPlayer.rbf`; its attempted rollback upload was rejected with FTP status 550 and changed no file. Repeating the read with the repository's established double-slash absolute URL retrieved the true active image at entry 519's exact 4,205,620-byte size and SHA-256 `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197`. After the user explicitly authorized replacement, ordinary FTP preserved and round-trip verified that image as `/media/fat/MediaPlayer.rbf.rollback-pre-bfb9361`, staged and round-trip verified the 4,188,256-byte `bfb9361` candidate at SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df`, promoted it to the absolute active path and retrieved the active and rollback files again at their respective exact hashes. The first relative stage-delete command was rejected without changing the verified files; an absolute delete removed only `MediaPlayer.rbf.stage-bfb9361`, and a final directory read confirms the stage is absent while the active and rollback names remain. No helper, media, Main or MiSTer configuration changed.

#### Next Steps:

Reload the core and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and the deinterlacer that exposes the symptom most readily. Capture a live burst and the terminal schema-fourteen snapshot from the same run, retaining the established acceptance of 300 decoded pictures, 299 swaps, quiet completion and no aggregate, presentation or phase error. Read both session-wide varied flags and signatures: a first field that never varies while the second does proves the data is already wrong when it arrives and moves the search upstream of the framebuffer, while both parities varying proves correct data arrives and is lost afterwards.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 520 COMMIT Unreleased bfb9361 2026-08-25T20:00:21-07:00

#### Coming From:

Unreleased 2668c8f

#### Purpose:

Repair and complete the session-wide per-field luma-content diagnostic so its telemetry is structurally valid and independently regression-protected.

#### Outcome:

The user approved continuation after recovery reproduced the uncommitted schema-fourteen profiler regression failure and identified it as an unintended no-progress test snapshot rather than an asserted design error: the added luma-return stimulus extended a deliberately short test interval beyond the sixty-four-cycle watchdog while none of those passive diagnostic events are, or should become, production session progress. Commit `afdece5` supplies one genuine decoder-byte acceptance inside that directed scenario while leaving the production watchdog unchanged, exports each raw native luma return from the framebuffer and accumulates per-parity signature, reference and varied state across the entire profiler session. It also corrects snapshot word forty to exactly thirty-two bits, adds an independently summed elaboration-time width guard, advances the cadence format to schema fourteen and labels schema-fourteen content evidence as session scoped while retaining schema-thirteen, schema-ten and legacy decoding at their original layouts. Icarus and Verilator accepted a packed-structure implementation of the width-safe word, but the first Quartus Prime 17.0.2 analysis rejected that syntax; no image was produced from it. Correction commit `bfb9361` expresses the same independently sized payload through explicit vector slices compatible with the target compiler. The focused profiler passes schema fourteen at checksum `e2266429`; decoder layout passes schema fourteen, thirteen, ten and legacy at their established 428/308/43, 428/308/43, 436/316/41 and 444/324/38 origins and word counts. The complete native suite passes field order, mapping, exact TFF and BFF timing, Bob and Weave selection, timing-pattern isolation, ownership, the long presentation integration, every cache mode, the profiler and decoder. Its long integration retains twenty windows and forty fields, ten serialized, thirteen overlapped and twenty-one accelerated decoded pictures with twenty accelerated presentations, plus eight decoded and eight presented terminal pictures with empty terminal state. TFF, BFF and progressive reconstruction pass at 7,926,459, 7,948,706 and 13,048,137 cycles with zero out-of-tolerance pixels, field-DCT rejection passes at 82,326 cycles, and the canonical mixed I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B-picture persistences, seventy-one swaps and every error clear. A clean from-scratch Quartus Prime 17.0.2 build of `bfb9361` completes in 11 minutes 2 seconds with zero errors and 143 warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.281, 0.244, 3.271, 0.595 and 0.925 nanoseconds with zero endpoint total negative slack. Focused decoder setup and recovery are positive 1.617 and 6.784 nanoseconds and focused video setup is positive 2.959 nanoseconds, all with zero violated paths; only the established unmatched `RESET` filter remains. Fit uses 29,706 ALMs, 45,755 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. A timing-netlist probe finds all eight bits of both session signatures and both varied-state keepers; the reference and seen intermediates are optimized into that retained logic. The 4,188,256-byte RBF has SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df`. Deployment stopped before any write because two independent ordinary-FTP reads found the active `/media/fat/MediaPlayer.rbf` to be a stable but unrecognized 4,200,652-byte file at SHA-256 `98c73c1b23499e5461fa789b3b77fbf59d798e957b9f7e9357bf6d932009a615`, rather than entry 519's logged 4,205,620-byte `2668c8f` image at `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197`. No remote file was changed.

#### Next Steps:

Identify or explicitly authorize replacement of the unrecognized active RBF before deployment. If replacement is approved, preserve that exact 4,200,652-byte file as `/media/fat/MediaPlayer.rbf.rollback-pre-bfb9361`, retrieve and verify the rollback copy at SHA-256 `98c73c1b23499e5461fa789b3b77fbf59d798e957b9f7e9357bf6d932009a615`, stage and round-trip verify the `bfb9361` candidate, promote it, verify the active file at SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df` and remove only the temporary stage. Leave helper, media, Main and MiSTer configuration untouched. Reload the core and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with a live burst, reading both session-wide varied flags and signatures from the same symptom-bearing run. A first field whose returns never vary across the whole session while the second field's do proves the data is already wrong when it arrives and moves the search upstream of the framebuffer; both parities varying proves correct data arrives and is lost afterwards.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 519 COMMIT Unreleased 2668c8f 2026-08-25T19:53:29-07:00

#### Coming From:

Unreleased 7356e4a

#### Purpose:

Observe the luma content DDR returns for each field parity.

#### Outcome:

This commit folds every returned luma word into a per-parity signature and sets a varied flag when any word differs from the first that parity saw, attributing each word by `fetch_line[0]` against `first_field_mem`. Reading `fetch_line` also cleared one long-standing assigned-but-never-read warning, so the build reports 143 rather than the established 144. A clean build completed in 10 minutes 31 seconds with zero errors, global setup, hold, recovery, removal and minimum-pulse-width margins of positive 0.230, 0.253, 2.888, 0.689 and 0.925 nanoseconds, focused decoder setup and recovery of positive 1.735 and 11.737 and focused video setup of positive 2.346, all with zero violated paths, a fit of 29,440 ALMs and 45,469 registers, and every new register confirmed present by netlist probe. The 4,205,620-byte RBF has SHA-256 `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197` and was installed rollback-safe with `7356e4a` preserved. The first hardware attempt read schema twelve because the core had not been reloaded; the file on the card was verified correct and the run repeated after a reload. That repeat produced the clearest symptom capture so far, showing both presentations in one session: the first field blank at pre-playback level 24 with no bar for roughly eight seconds, then a transition, then the first field frozen on a picture with a stationary bar parked at x=112 through x=143 while the odd field continued sweeping, then correct content in both parities at terminal drain. The content counters from that run are void. Word forty was concatenated as eight, eight, one, one, six, three and three bits, which totals thirty rather than thirty-two, so the assignment zero-extended on the left and every field decoded two bits from its intended position. The reported varied flags and signatures are therefore meaningless, and the earlier explanation attributing their inconsistency to per-generation latching was wrong. The directed profiler regression did not catch it because it compared an equally malformed thirty-bit literal against the same wire, the same class of blind spot as the overlay case in entry 516 where a test validated the defect instead of detecting it. Schema twelve is unaffected and entry 518's conclusions stand, because its word forty totalled eight, eight, ten, three and three bits, which is exactly thirty-two. The padding has since been corrected to eight bits and a session-wide rework moves the accumulation into the profiler, whose reset scope is the session rather than the generation, so a parity that never receives varying data reports varied low regardless of which generation precedes terminal quiet. That rework lints clean but its directed regression currently fails with snapshot reason three, the fatal-error path, at 12.159 microseconds whenever the luma-return stimulus is present; the failure time is identical for a two-cycle and a three-cycle stimulus task, which rules out the no-progress budget that caused two earlier regression failures, and the mechanism is not yet understood. Nothing of that rework is committed. It remains uncommitted in the working tree so it is not lost, and the installed image remains `2668c8f`, which runs and captures normally but whose word-forty fields must not be read.

#### Next Steps:

Root-cause the profiler regression failure before anything else, since snapshot reason three means an error flag is asserting during the luma-return stimulus and that must be understood rather than worked around. Then complete the session-wide content rework on top of the corrected thirty-two-bit padding, and add a width check to the regression so a malformed snapshot word fails on its own rather than being confirmed by a matching malformed expectation, which is the specific gap that let both this defect and the entry 516 overlay defect reach a build. Rebuild, reinstall rollback-safe and repeat the fixture with a burst, reading the two varied flags and two signatures alongside burst frames from the same run. A first field whose returns never vary across the whole session while the second field's do proves the data is already wrong when it arrives and moves the search upstream of the framebuffer entirely; both parities varying proves correct data arrives and is lost afterwards, which would be the first evidence pointing downstream of the fetch. Retain the standing observation that the symptom presents in two forms, so a single run's flags do not generalize.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 518 COMMIT Unreleased 7356e4a 2026-08-25T19:52:53-07:00

#### Coming From:

Unreleased 3e91073

#### Purpose:

Record which DDR region each field parity's fetch actually resolves into.

#### Outcome:

Entry 517 showed the framebuffer requesting every first-field row correctly and receiving pre-playback content, so this commit observes the one thing no counter recorded: which of the five DDR regions the top-level offset steers each fetch into. The framebuffer emits a plain row address and `mpeg2_new_display_frame_offset` is added combinationally at issue time, so a native frame readout spanning two vertical periods could in principle straddle a display swap and resolve its two parities differently. The top level now samples the region on each parity's fetch edge and the profiler latches both and counts generations where they disagree; all of it is `clk_mpeg2` logic and none enters the video domain. Schema twelve retires the per-parity displayed-line counters, which entry 517 proved uninformative by reading two hundred forty against two hundred forty while the field carried no picture, and reuses their bits for the two regions and a mismatch count at the same forty-three words. Retiring them also removed two video-domain toggles, two three-stage synchronizers and two timing exceptions, which is why this build has more margin than the one before it. A clean Quartus Prime 17.0.2 build completed in 10 minutes 35 seconds with zero errors and the established 144 warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.343, 0.252, 3.420, 0.572 and 0.925 nanoseconds, with global setup above the accepted `9573923` baseline rather than merely matching it. Focused decoder setup and recovery are positive 1.608 and 11.174 nanoseconds and focused video setup is positive 3.117 nanoseconds, all with zero violated paths, and a timing-netlist probe confirms every new register survives. The fit uses 29,399 ALMs and 45,254 registers. The 4,223,092-byte RBF has SHA-256 `2d011ce350f427f0d3c4eb147825947c6bf93a9ec7fc4e8a0771f1a86cc3ed58` and was installed rollback-safe over ordinary FTP with `3e91073` preserved. On hardware the symptom reproduced across fourteen live burst frames with the first field blank at pre-playback level and the odd field sweeping normally, while the counters reported 242 first-field and 240 second-field fetches, region one for both parities, zero region mismatches across all three hundred generations and zero phase errors. Both parities therefore resolve into the same region in every generation, the straddled-swap mechanism does not occur, and the banked address path is exonerated along with readout sequencing, field phase and per-parity fetch service. A static read then eliminated the writer structurally rather than by measurement: `mpeg2_h262_ddram_store_420p.sv` uses the identical base, bank offsets and ninety-word row stride as the reader, and snaps each block origin to a multiple of eight so every write covers eight consecutive frame rows and cannot populate one parity without the other.

#### Next Steps:

Observe the luma content DDR returns for each parity, since every measurement so far has observed control rather than data and all of it has been correct. Fold each returned luma word into a per-parity signature and set a flag when any returned word differs from the first that parity saw, attributing the word by the fetch address parity. Keep the accumulation on the decoder clock, publish it in the existing forty-three words, and read it alongside burst frames from the same run because the symptom presents in two forms: a first field blank at pre-playback level, and a first field frozen on a picture.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [x] Passed

---

## 517 COMMIT Unreleased 3e91073 2026-08-25T18:48:23-07:00

#### Coming From:

Unreleased 3e91073

#### Purpose:

Read the new per-field evidence on hardware and determine whether framebuffer field readout is actually at fault.

#### Outcome:

The instrumented `3e91073` image was installed rollback-safe and run against `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and Bob, while a live burst sampled the core's raster at roughly 2.4 hertz. Schema eleven decoded on hardware for the first time at forty-three words from the moved native origin. Its verdict is that field readout is correct and entry 515's classification is superseded. The last generation was served 242 first-field and 240 second-field luma line fetches, presented 240 lines of each parity, and recorded zero generations of per-parity line imbalance and zero field-phase errors, while the established counters remained at 300 framebuffer resets, 299 publications, zero prefill misses and zero superseded generations. The 242 figure confirms the counter rather than contradicting it, because the two prefill luma lines are the sequence-zero and sequence-one rows and both therefore carry first-field parity by construction. The session itself was ordinary, with the complete 5,007,304-byte stream accepted, 300 decoded pictures, 300 displayed and 299 swaps across 599,116,647 cycles or 9.985277 seconds, top-field-first, sequence end seen, presentation complete, quiet reason one and every error clear. Against that, the burst shows the first field carrying no picture at all. Fourteen distinct live frames each place the moving bar on odd rows only, and the even rows sit at background level 24, which is the pre-playback screen rather than the fixture's level 19; a sweep found zero even-row pixels above background anywhere outside the reference rows and the telemetry overlay. Only the terminal frame shows both parities agreeing at the authored weave. The framebuffer therefore requests every first-field row, on the correct lines, in the correct field phase, and receives pre-playback content: the addresses are right and what they resolve to is wrong. Evidence is `.ai/current_results/entry517_stale_first_field_live.png` at 10,031 bytes with SHA-256 `a6ff293687eca203b3660e4881ffb0884e04676975aaeaab8633a090fcee566c` and `.ai/current_results/entry517_field_readout_counters.png` at 12,262 bytes with SHA-256 `bb02eca2ea6ce2364146f48a13c83ca14c487d579fec586abba117963d1a91d0`. A static read of the address path identifies the mechanism this evidence points at without proving it. The framebuffer emits a plain row address and the top level adds `mpeg2_new_display_frame_offset` combinationally at the instant each fetch is issued, selecting between five distinct DDR regions for bank zero, bank one, bank two and the two scratch areas. The framebuffer has no knowledge of which region its correct row lands in, and a native frame readout is uniquely exposed because its 480-entry sequence spans two vertical periods and can therefore straddle a display-bank swap, leaving the two fields resolved into different regions while every framebuffer counter still reads perfectly. No existing signal records which region a fetch resolved into, so this is invisible to all present telemetry. Commit `3e91073` passes its objective: the instrumentation was built to decide this question and it decided it against the standing hypothesis.

#### Next Steps:

Instrument the region a fetch actually resolves into, keeping every new observation inside the decoder clock domain so that none of it competes with the framework scaler for video-domain placement, which is what cost three rebuilds in the previous cycle. The display bank, display scratch and scratch bank levels already live on that clock, as do the two per-parity fetch toggles the framebuffer exports, so the top level can latch the region in effect on each first-field and each second-field fetch edge and compare them per generation. Retire the per-parity displayed-line counters, which have now demonstrably served their purpose by reading two hundred forty against two hundred forty with zero imbalance while the field carried no picture at all, and reuse their bits for the two observed regions and a count of generations whose two parities resolved differently. Publish this as schema twelve at the same forty-three words so the snapshot does not grow, update the telemetry decoder and its layout test for both schema twelve and the existing schema eleven and ten, extend the profiler regression with a directed case where the two parities disagree, then clean-build with focused timing and confirm by netlist probe that every new register survives and no timing exception is left unmatched before installing rollback-safe. Two differing regions localize the defect to the banked address path and justify a bounded correction there, while identical regions in every generation clear that path and move the investigation to whatever populates the first field's rows.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 516 COMMIT Unreleased 3e91073 2026-08-25T18:31:59-07:00

#### Coming From:ff

Unreleased 9573923

#### Purpose:

Instrument the per-field framebuffer readout invariants that whole-picture counters cannot observe.

#### Outcome:

Entry 515 placed the fault in framebuffer field readout, and this cycle adds passive evidence for it. The framebuffer exports a sticky per-generation field-phase error, one toggle per displayed line of each parity from the video domain, and one toggle per launched luma DDR line fetch of each parity from the memory domain, which is `clk_mpeg2` itself and therefore needs no synchronizer. Three-stage synchronizers carry the video-domain levels to the decoder domain and `MediaPlayer.sdc` cuts only their stage-zero paths, matching the convention `69a4f20` established. Cadence schema ten becomes schema eleven at forty-three words: one appended word packs four saturating eight-bit per-generation figures for first-field and second-field DDR fetches and displayed lines, a second carries sixteen-bit counts of generations whose per-parity line counts disagreed and of field-phase errors, and the checksum moves to word forty-two. A native field presents two hundred forty lines and is served two hundred forty luma rows, so eight bits carry the ordinary range while two hundred fifty-five reports saturation, which arises only when one generation spans several displayed frames. Both overlay origins move eight rows up to 428 and 308 so the final row stays flush with the diagnostic and native rasters. The Python decoder accepts schema eleven while schema ten and legacy schema nine still decode at their original origins. Reaching this state required three corrections, all recorded here rather than hidden. Commit `9bff941` appended three words but did not extend the overlay's per-word case statement or its fixed height, so nothing read words forty-one through forty-three and synthesis correctly deleted the entire phase-error synchronizer chain, the fetch toggles, the per-generation latches and both counters; a `get_keepers` probe returned zero keepers for every one of them, and the only symptom in an otherwise clean build was an ignored-filter warning naming `mpeg2_new_framebuffer_phase_error_sync[0]`. The profiler regression had passed because it asserts against the snapshot register directly and never exercised the overlay decode, so `5c6c311` added the missing branches, raised the height and introduced a row-coverage regression that walks every word row checking the decoded index, the rendered word and that the row lies inside the overlay height; reinstating the short height proves it fails. That build restored all keepers but global setup fell to negative 0.082 nanoseconds entirely inside MiSTer's `ascal` scaler. Packing to forty-three words in `0d2aead` unexpectedly grew the fit to 29,680 ALMs and left setup at negative 0.091 with the critical path relocated inside `ascal`, proving word count was not the cost. Commit `3e91073` instead removed the video-domain arithmetic by replacing a nine-bit expected-index adder and equality comparator with a single constant magnitude compare: the replica's own position names its field, so comparing that parity against the raster parity detects a retained or misaligned field without computing the index. A clean Quartus Prime 17.0.2 build from empty generated state completed in 10 minutes 47 seconds with zero errors and the established 144 warnings, none attributable to the new logic. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.252, 0.244, 4.132, 0.589 and 0.925 nanoseconds, with global setup exactly matching the accepted `9573923` build. Focused decoder setup and recovery are positive 1.646 and 11.735 nanoseconds and focused video setup is positive 2.811 nanoseconds, all with zero violated paths. Only the pre-existing `RESET` filter remains unmatched, and a timing-netlist probe confirms every new register survives. The fit uses 29,448 ALMs, 45,442 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,219,576-byte RBF has SHA-256 `05e3a5b564ca49554707d39205749f9b96dec8028fcfe68a562b30d921f0aa54`. The complete native suite passes all thirteen cases including the new row-coverage check, and TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles with field-DCT rejection at 82,326 cycles. The live raster soak still fails its historical 6,529,997-cycle assertion against an observed 6,529,996 with every other figure clean; it compiles none of the files this cycle changed, so the drift entry 511 documented remains outstanding and independent. No decoder, scheduler, cache, presentation or native timing behavior changes.

#### Next Steps:

Preserve the running `9573923` image as `/media/fat/MediaPlayer.rbf.rollback-pre-3e91073` through ordinary FTP with the default `root` and `1` login, round-trip verify both it and the staged candidate, promote the candidate, verify the promoted file at its exact hash and remove only the temporary stage while leaving helper, media, Main and MiSTer configuration untouched. Then run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and the deinterlacer that ghosts most readily, and capture the terminal raster along with a live burst through `/dev/MiSTer_cmd`. Acceptance requires the established 300 decoded pictures, 299 swaps, normal quiet completion and no aggregate or presentation error, with the new evidence read alongside. Balanced per-parity DDR fetch counts with zero phase errors would clear field readout and force the investigation back upstream to what writes the frame, while a starved first-field fetch count during a generation the burst shows frozen would localize the defect to the refill path and justify a bounded correction there. Report the per-generation figures with the burst evidence before any behavioral change is proposed.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 515 COMMIT Unreleased 9573923 2026-08-25T11:32:46-07:00

#### Coming From:fff

Unreleased 9573923

#### Purpose:

Locate the native ghost by capturing the core's own raster during live playback instead of only after it ends.

#### Outcome:

Every prior capture in this investigation was terminal, so the intermittent ghost had never been measured while visible. Bursts of screenshot triggers issued through the MiSTer's ordinary-FTP view of `/dev/MiSTer_cmd` with the default `root` and `1` login now sample the live raster at roughly 2.4 hertz. The decisive fixture burst returned twenty-four distinct live frames of `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i. Decomposed by field, the bottom field advances its bar every single frame across the full sweep while the top field holds one position for 4.2 seconds at x=512 through x=543, jumps once and then holds the next for 4.6 seconds at x=632 through x=663. Each frozen top-field bar measures exactly thirty-two columns by one hundred seventy-six rows, the exact authored field-bar geometry, so it is a cleanly retained picture rather than a smear. An earlier burst independently caught the same asymmetry with content instead of position: at playback start the top field carried the entire previous screen at background level 24 while the bottom field carried live video at level 19, and two frames 0.8 seconds apart both showed it, which excludes the ordinary sixteen-millisecond inter-field sampling offset of an interlaced screenshot. That evidence is `.ai/current_results/entry515_live_ghost_two_bars.png` at 13,565 bytes with SHA-256 `4c6ad022c14e55a586270072a1807b5d02a2b4d5e2e1d6153dc35e975ca26c82`, `.ai/current_results/entry515_field_freeze_early.png` at 13,233 bytes with SHA-256 `d0387b6c4c423ff737ee3eff426b79759a27bde5b936392667f6252c252baaed` and `.ai/current_results/entry515_field_freeze_midrun.png` at 10,864 bytes with SHA-256 `69ac1b3517d343d8de3683c79d1596f08a6288fe17b0187af00d59586a0eefe1`. The pattern control settles the boundary. With Native timing pattern On and motion Moving the same burst returned fifty-five distinct frames over forty-six seconds at background exactly `(16,16,16)`, reference rows 120, 121, 360 and 361 and sixteen-pixel bars at the authored positions; forty-eight of them place both fields at the identical x with 3,840 bright pixels each, and the seven that differ are jump instants between adjacent authored positions which resolve to a united bar by the next sample 0.42 seconds later. The pattern therefore proves the capture path, final mux, native sync, MiSTer's processed-HDMI Bob path and the display all track a moving object within one field time, while decoded video retains a stale field for over two hundred forty field times through the same chain. Its evidence is `.ai/current_results/entry515_pattern_control_locked.png` at 7,721 bytes with SHA-256 `71ac91a908a494bce09f7ecbf32c0b8c3ca617e44e4fc8b001a13df52adc05e6` and `.ai/current_results/entry515_pattern_control_transition.png` at 9,850 bytes with SHA-256 `ac115389e3cc3ea33df5d552903f09c5f4fd77477511eda8fff294ed3b871153`. Because the pattern bypasses the framebuffer, DDR and line cache while video does not, the fault is field readout, confirming the classification entry 514 assigned. A static read of `rtl/mpeg2_luma_framebuffer.sv` mapped the mechanism but did not identify the defect, and it disproved the leading hypothesis: the 480-entry presentation sequence is not free to sit at an arbitrary raster phase, because the per-generation reset zeroes `line_done_sequence_mem` and the event advancing it is gated on `picture_present_rd`, which asserts only at the authored first-field origin, so entry zero is anchored to the correct field by construction. The monitored reader-fell-behind and same-bank refill collision detectors also remain clear in every run, so neither is the cause.

#### Next Steps:

Instrument the per-field invariants the static read identified, all of which are currently unmeasured because existing telemetry counts whole pictures and therefore cannot see a single stale field. Derive the true presentation sequence index in the video domain from the raster position as the authored-parity field line or two hundred forty plus that line, compare it against the memory-domain `line_done_sequence_mem`, and record mismatch count, the first mismatching pair and maximum drift. Add per-parity displayed-line counts for each generation so that a frozen top field appears directly as an imbalance against the expected two hundred forty and two hundred forty, record whether publication ever asserts on the wrong raster parity, and count DDR line refills served to each field. Extend the hardware snapshot from schema ten to schema eleven by appending words only, without repurposing any established MPEG, prediction, PCM, scheduler or error field, exactly as `52a5a64` extended schema nine to ten, and move the checksum accordingly. Update the telemetry decoder and its tests, add focused framebuffer and native integration regressions covering an ordinary locked sequence and a deliberately stalled field, retain the complete native and scheduler suites, then run a clean Quartus Prime 17.0.2 build with focused timing analysis and install through rollback-safe ordinary FTP. Repeat the fixture with the live burst and require the new counters to identify which invariant breaks when the top field freezes. No presentation, cache, scheduler or native timing behavior may change in this observational commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 514 COMMIT Unreleased 9573923 2026-08-25T11:06:08-07:00

#### Coming From:

Unreleased 9573923

#### Purpose:

Determine whether the intermittent native ghost and the grey dash artefact originate upstream or downstream of the FPGA final mux.

#### Outcome:

The first ordinary-FTP capture of this cycle was taken while `Native timing pattern` was still Off and was initially misread as pattern output. `.ai/current_results/entry514_moving_pattern_retention.png` is 12,192 bytes with SHA-256 `146d3f343bf9c5a8607eee944a0d71ab59b6372bc9a07d1d4b30922ba4de6ac0`. Measured against entries 508 and 509 it is structurally identical to them, with background `(19,19,19)`, full-width reference rows 119 through 122 and 357 through 360 and the authored terminal weave whose even rows span x=512 through x=543 and odd rows x=516 through x=547, so it recorded decoded video rather than the diagnostic. That reading and the downstream conclusion drawn from it are withdrawn. The installed image was then verified over ordinary FTP with the default `root` and `1` login at exactly 4,220,300 bytes and SHA-256 `03bb6a504538fd7e62b2877a428e2e570841ccb3d2d834674f163dd580d76642`, confirming `9573923` was the running core and that the Moving submode existed but had not been selected. The user then set Native timing pattern On, Native pattern motion Moving, HDMI scaler deinterlacer Bob and Interlaced output Native 480i and reran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v`. The resulting `.ai/current_results/entry514_moving_pattern_on.png` is 7,676 bytes with SHA-256 `76e71cd567acd63e29049a078502de80cac2822c45c35e710370f1d79d58ab6c` and its raster is pixel-exact against the authored source: background exactly `(16,16,16)`, reference lines exactly `(80,80,80)` at rows 120, 121, 360 and 361 and one `(191,191,191)` bar occupying columns 432 through 447, exactly sixteen pixels wide and all 480 rows tall at authored position 432. A sweep for any intermediate level outside the reference rows and the telemetry overlay returned no pixel at all, so no second bar, partial bar or dash exists anywhere in the emitted frame. The user independently reports one bar only throughout live playback, correct holds, ninety-six-pixel jumps and wrap, and no grey dashes at any point in this mode. Schema ten accepted the complete 5,007,304-byte stream and represented 300 decoded pictures, 300 displayed pictures and 299 swaps across 599,436,793 cycles or 9.990613 seconds, with 300 framebuffer resets, 299 publications, zero superseded unpublished generations, zero prefill misses, a maximum 2,002,004-cycle publication latency, zero gap outliers, top-field-first, sequence end seen, presentation complete, quiet reason one and every error clear. Commit `9573923` therefore passes its diagnostic objective. Because the final mux, cadence overlay, native sync generation, MiSTer's processed-HDMI Bob path and the display together rendered a moving object with no retention whatsoever, the decoded-video ghost originates upstream of the final mux in framebuffer cache or field readout, which is the conclusion entry 513 assigned to this outcome. That inference is bounded rather than absolute because the pattern bar is pair-identical between fields and holds each position thirty frame windows, so it exercises neither inter-field difference nor per-frame motion and cannot fully exonerate downstream processing for field-differing content; entries 502, 503, 509 and 510 weaken the downstream account independently because the ghost survives both Weave and Bob. Separately, `decode_hardware_cadence.py` derives `delivered_fps` from the wrapped eight-bit swap counter rather than the reconstructed count and printed 4.303 where the true rate is 29.928 pictures per second, a reporting trap every prior entry avoided by computing the rate by hand.

#### Next Steps:

Close the remaining gap with direct evidence rather than inference by capturing the core's own raster while the ghost is live, since every capture in this investigation so far has been a terminal capture taken after playback ended. With Native timing pattern Off, Interlaced output Native 480i and whichever deinterlacer ghosts most readily, the user launches `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` and the agent bursts sixteen screenshot triggers at approximately 0.8-second intervals through the MiSTer's ordinary-FTP view of `/dev/MiSTer_cmd` into `/media/fat/screenshots`, retrieves each one and measures every raster for a second bar group, a faint column group or dash rows against the established thirty-seven-pixel authored weave baseline. A ghost present in any core-side raster places the fault upstream and justifies a following commit instrumenting framebuffer field readout, while a ghost absent from every raster during a run the user sees ghosting on the panel proves the fault is downstream and justifies extending the timing pattern with per-frame motion and a field-differing submode matching the fixture's four-pixel inter-field offset. No RTL, menu, scheduler or MiSTer configuration changes belong in this step, and the retrieved screenshots stay on the SD card unless the user asks for their removal.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 513 COMMIT Unreleased 9573923 2026-08-25T09:58:18-07:00

#### Coming From:

Unreleased 69a4f20

#### Purpose:

Add a moving final-mux native pattern that distinguishes FPGA field-readout retention from MiSTer scaler or display retention.

#### Outcome:

The user approved the revised diagnostic after review of `.ai/current_results/PXL_20260825_160322728.mp4`, a 56,383,735-byte 13.564622-second Pixel 8 Pro recording at SHA-256 `267561d6246d06ce7ec03f533e979b6b1bd7e15c27fffa8bc01b9f8154adaec6`. The ordinary full-height bar moves and wraps throughout the active playback, while a separate upper-half bar remains fixed at one horizontal position for nearly the entire ten-second session and disappears abruptly when playback completes and the terminal overlay returns. This is not a brief Bob tradeoff, rolling-shutter duplicate or panel afterimage. The paired schema-ten capture accepts the complete 5,007,304-byte stream, represents all 300 pictures and 299 swaps in its wrapped counters, records 300 framebuffer resets, 299 publications, zero superseded unpublished generations, zero prefill misses, a maximum 2,002,005-cycle publication latency, three regular 2,002,000-cycle ranked gaps, normal quiet completion and no error. Commit `9573923` retains the established status-bit-123 static bars and adds status bit 125 as a separately synchronized Static/Moving submode. Moving mode emits a sixteen-pixel pair-identical bar at x positions 48 through 624, holds each for exactly thirty complete frame-window edges, advances ninety-six pixels and wraps through seven positions; pair-identical horizontal references use the common field-row coordinate. This source remains after the framebuffer mux and before the cadence overlay, so decoder, DDR and line-cache pixels are absent while native sync, field signalling and MiSTer's processed-HDMI path remain active. Destination-scoped timing exceptions cut only the two asynchronous menu sources entering stage zero. Directed tests prove unchanged static colors, blanking and sync passthrough, exact hold, jump and wrap behavior, no double-count from a held frame-window level and identical TFF/BFF content. The complete native suite passes field order, mapping, timing, Bob/Weave control, ownership, accelerated presentation, cache refill and schema-ten telemetry; TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, field-DCT rejection remains 82,326 cycles and the canonical mixed I/P/B raster remains exactly 6,529,997 cycles with every error clear. No decoder, scheduler, framebuffer, cache or native timing behavior changes. A clean Quartus Prime 17.0.2 build from empty generated state completed in 10 minutes 45 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.252, 0.251, 3.650, 0.630 and 0.925 nanoseconds. Focused decoder setup and recovery are positive 0.913 and 11.075 nanoseconds and focused video setup is positive 2.661 nanoseconds, all with zero violated paths. Both native menu synchronizer exceptions match without an empty-filter warning. The fit uses 29,271 ALMs, 45,209 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,220,300-byte RBF has SHA-256 `03bb6a504538fd7e62b2877a428e2e570841ccb3d2d834674f163dd580d76642`. Ordinary FTP retrieved the installed `69a4f20` image at its exact known 4,237,424-byte hash `57cee7a30c9802c256398cbf44875c5c2118b4b912aca0ef08e103467068c673`, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-9573923`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact new hash. The temporary stage is absent; helper, media, Main and MiSTer configuration are unchanged.

#### Next Steps:

Reload the installed core, set HDMI scaler deinterlacer to Bob, Native timing pattern to On, Native pattern motion to Moving and Interlaced output to Native 480i, then run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` once and record the complete active interval. The direct pattern must show one sixteen-pixel bar at a time, hold each position for approximately one second, jump ninety-six pixels and wrap after seven positions while the two horizontal references remain fixed. Any second retained bar or partial bar proves the fault is downstream of the FPGA final mux in MiSTer's processed-HDMI scaler or display; clean single-bar jumps prove the FPGA final mux and downstream path and place the decoded-video fault inside field-specific framebuffer cache or readout. Report USER, DISK and POWER and leave the terminal image displayed for ordinary-FTP capture.

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
