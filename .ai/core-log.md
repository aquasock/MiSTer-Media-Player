## 439 COMMIT Unreleased 3814243 2026-08-24T06:26:40-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Close focused hardware qualification of the bounded-lookahead scheduler on the formerly repeatable 48 kHz starvation control.

#### Outcome:

The user reports that `00_good_480p_48k.mpg` now works with audio and video perfectly synchronized, neither repeatable crackle present and no reported picture stutter. USER and POWER are solid on and DISK blinks eleven times, the normal final-GOP progress state. The launch-free 800x600 schema-eight capture is 104,785 bytes at SHA-256 `4845b6ab2e9f858d3061371adf0479357da034b46bbe86dfc30f9870f7d5fa50`. It closes the static proof with zero aggregate error flags, `audio_underrun` false, `pcm_protocol_error` false and decoder, presentation and destination errors all clear. All 582,742 accepted transport bytes reach the core, 44 timestamps associate, seventeen reference plus 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen, presentation completes and the snapshot freezes for normal quiet reason one with no pending decode, reorder, promotion, scratch, future-reference or terminal-boundary work. PCM sample count saturates the telemetry field at 16,383 and FIFO peak saturates at 127 or more without starvation. First presentation occurs after 2,430,554 decoder cycles or 40.5 milliseconds, the final picture presents after 1.959 seconds and the session becomes quiet after 2.057 seconds. The cadence profiler records every picture with an aggregate 24.494 delivered frames per second; its three largest decode-limited intervals are 99.475 milliseconds at periodic picture ordinals eleven, 23 and 35, but they drop no picture, leave no state or error and produced no user-reported visible stutter. This accepts helper source `3814243` and active helper SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` for the repaired 48 kHz control while retaining timing-clean RBF source `091b150`.

#### Next Steps:

Without rebooting, run only `01_good_480p_44k.mpg` with Audio Test Off. Report beginning audio-video alignment, any crackle or dropout, any visible picture stutter, whether audio extends beyond the final picture and all three final LEDs, then leave its final image loaded for schema-eight capture. Do not begin the six expected-failure recovery pairs until the 44.1 kHz control also has zero audio underrun, PCM protocol, presentation, decoder and aggregate error telemetry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 438 COMMIT Unreleased 3814243 2026-08-24T06:23:08-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Install the exact bounded-lookahead helper with byte-verified rollback while leaving the timing-clean FPGA and qualification media unchanged.

#### Outcome:

Read-only retrieval first confirmed the installed 361,452-byte helper at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. Candidate `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` was uploaded as `/media/fat/linux/MediaPlayer_Helper.stage.3814243`, retrieved and compared byte-for-byte before any active-name mutation. The prior helper was then atomically renamed to `/media/fat/linux/MediaPlayer_Helper.backup.pre-scheduler.9afe2f0`, the verified stage was promoted, and FTP metadata independently confirms active mode `0755`, owner and group root and size 361,452 bytes. Separate post-promotion retrievals reproduce the candidate hash for the active helper and `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54` for the rollback. The active 4,126,828-byte RBF remains unchanged at SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`, and active `00_good_480p_48k.mpg` remains unchanged at SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5`. Main and every other media file were untouched, no reboot occurred and no playback was launched.

#### Next Steps:

Without rebooting, leave Audio Test Off and run only `00_good_480p_48k.mpg`. Report whether audio and video begin together, whether either former crackle/dropout occurs, whether the picture stutters at the former late point, whether audio still plays beyond the final picture, and the final USER, DISK and POWER states. Leave the final image loaded for a fresh schema-eight capture. Do not run the 44.1 kHz control, any expected-failure case or the full soak until this control has zero audio underrun, PCM protocol, presentation, decoder and aggregate error flags. If the helper fails to start or behavior regresses materially, restore `MediaPlayer_Helper.backup.pre-scheduler.9afe2f0`; the RBF requires no rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 437 COMMIT Unreleased 3814243 2026-08-24T06:21:28-07:00

#### Coming From:

Unreleased 091b150

#### Purpose:

Record the failed widened-FIFO control, correlate its first repeatable crackle to an exact transport starvation boundary, and define the bounded ARM-side scheduling correction.

#### Outcome:

The user reports that corrected `00_good_480p_48k.mpg` now begins with audio and video apparently aligned, but audio still plays slightly past the final picture, both repeatable crackles/dropouts remain, and the picture stutters once with the final crackle. The terminal LEDs were USER solid on, DISK blinking eleven times and POWER solid on. A launch-free schema-eight screenshot captured the loaded final raster at displayed frame 47 while telemetry had frozen on the first error: aggregate error flags are exactly `0x0400`, meaning `audio_pcm_underrun` alone, with `pcm_protocol_error` and every video, presentation and destination error clear. The snapshot occurs at 3,516 accepted PCM samples and 218,405 clean video bytes. Exact native-helper correlation proves why the 8,192-sample FIFO cannot fix this stream: only 3,456 samples precede a 147,631-byte PCM-free video interval, and the frozen count is exactly those samples plus 60 from the resumed batch that makes starvation sticky. Commit `3814243` implements the approved bounded-lookahead correction entirely in the helper. It retains the two-picture startup boundary, queues at most 512 KiB of video, uses audio and monotonic video PTS to maintain a 2,048-sample horizon, caps the initial release at 4,096 samples, caps every steady batch at 2,048 samples and inserts a guard sample before any post-start PCM-free video span can exceed 65,535 bytes. The analyzer independently compares scheduled in-band output with an explicit-output helper pass and proves exact video, PTS and PCM preservation without retaining the full transport in memory. On the failed 48 kHz control, the initial batch is 3,200 samples, the maximum steady batch is 2,048, the maximum PCM-free video span falls to 38,446 bytes, the terminal audio batch is 238 samples, and peak lookahead is 242,876 video bytes plus 4,078 PCM samples. The 44.1 kHz control has the same span and batch bounds. The 596-second soak reproduces a deterministic 342,199,090-byte transport at SHA-256 `3364dac5631d266adfb726c0bd26751e66ad069dd06c5ca23433d9c28c3df93d`, with all 84,543,918 video/PTS bytes at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and all 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`; its initial batch is 5,504, steady batches are at most 2,048, maximum gap is 64,768 bytes and peak video lookahead is 370,338 bytes. Short and faded fixtures at both rates preserve exact sample counts, clean ends, maximum sample error two and correlation rounding to one under native and address-and-undefined sanitizers. The nine-case envelope retains exactly three passes and six intended failures, the full soak remains a strict pass, and two official GCC 10.2.1 builds are byte-identical. The 361,452-byte static stripped ARM EABI5 helper has SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576`. No RTL, RBF, Main or media changed.

#### Next Steps:

Retrieve and hash the currently installed helper before mutation. Preserve it under an exact new rollback name, upload candidate `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` through a staging name, retrieve it byte-identically, mark it executable and promote it only after rollback exists. Leave the timing-clean `091b150` RBF, Main and every installed media file unchanged. Then run only `00_good_480p_48k.mpg` without rebooting, report alignment, both former crackle locations, any visible stutter, the final audio tail and all three LEDs, and leave the final image loaded for a fresh schema-eight capture. Do not continue to the 44.1 kHz control or any failure case until this control completes with no audio underrun or other telemetry error.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/analyze_arm_av_transport.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 436 COMMIT Unreleased 091b150 2026-08-24T05:47:31-07:00

#### Coming From:

Unreleased 091b150

#### Purpose:

Install the exact timing-clean starvation correction and corrected media while preserving byte-verified rollback.

#### Outcome:

Read-only retrieval first confirmed that the MiSTer still held accepted RBF SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` and unchanged helper SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. Candidate RBF `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea` was uploaded under a staging name, retrieved and compared byte-for-byte before promotion. All nine corrected qualification files were independently uploaded to a staging directory, retrieved and compared byte-for-byte, including the full 100,059,153-byte soak. The prior failed media set is preserved without mutation as `/media/fat/games/MediaPlayer/v0.7_qualification.failed.9afe2f0`; the accepted RBF is preserved exactly as `/media/fat/MediaPlayer.backup.pre-pcm-depth.047f5b2.rbf`; and the verified staging names were promoted only after those rollbacks existed. Post-promotion retrieval confirms active `/media/fat/MediaPlayer.rbf` at `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`, its rollback at `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the helper still at `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`, and active `00_good_480p_48k.mpg` at corrected SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5`. The remaining active media carry the exact Entry-435 hashes, including unchanged truncated-case hash `5ea02141a0be7846389b378f996f67e986bfef2a60dc289f9a7df6ab78f829ce` and full-soak hash `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. Main is unchanged, the running core remains the previous image until reboot, and no playback was launched.

#### Next Steps:

Power-cycle the MiSTer once to load the installed candidate, set Audio Test to Off, and run only corrected `00_good_480p_48k.mpg`. Report whether audio starts aligned with the opening video, whether either of the two repeatable crackles or any dropout remains, and the final state of USER, DISK and POWER after the file reaches its clean end. Do not run `01`, any expected-failure case or the full soak yet. If this control fails, leave the final image loaded and do not reboot so schema-eight telemetry can be captured; the exact RBF rollback is `MediaPlayer.backup.pre-pcm-depth.047f5b2.rbf` and the failed prior media remain in `v0.7_qualification.failed.9afe2f0`.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 435 COMMIT Unreleased 091b150 2026-08-24T05:26:02-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Eliminate deterministic PCM starvation and require clean terminal framing for user-converted Program Streams.

#### Outcome:

Commit `091b150` makes the H.262 sequence-end code and MPEG Program Stream end code mandatory compatibility conditions, adds one shared idempotent finalizer to every Program Stream generator, and widens the asynchronous PCM FIFO from 4,096 to 8,192 stereo samples for 170.7 milliseconds of capacity at 48 kHz while retaining the exact 2,048-sample startup threshold. The focused FIFO simulation accepts and drains all 8,192 samples in order across independent clocks, explicitly remains non-full after the obsolete 4,096 boundary, and reaches the correct full and empty limits; the output-adapter simulation preserves below-threshold silence, short-stream release, sticky true underrun and false-underrun-free clean termination. The static PCM verifier preserves all four pinned proof-tone hashes and both sample schedulers. The nine-case envelope regenerates twice byte-identically with all three good cases passing and all six bad cases failing as intended; removing the final 17 bytes from the 48 kHz control now reports both missing terminal conditions, finalization reconstructs the exact file and a second finalization changes nothing. Corrected 48 and 44.1 kHz controls have SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5` and `417db70be8cadc8ca829984d149cb0a5ccda82b0dfc065869578789290a1c83e`. All four short and faded ARM fixtures now carry Program Stream ends, regenerate byte-identically, pass the strict checker, and pass native plus address-and-undefined-sanitized helper verification at both sample rates with byte-identical video, exact PCM lengths, maximum sample error two, correlation rounding to one, one clean audio end and every failure path preserved. The full movie remains a strict pass and byte-identical at SHA-256 `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. The sole Quartus 17.0.2 candidate completes in 10 minutes 4 seconds with zero errors and 146 warnings. It uses 28,918 ALMs, 44,607 registers, 3,523,027 memory bits, 446 RAM blocks, 65 DSP blocks and three PLLs: exactly 143,360 additional memory bits and 17 RAM blocks versus accepted `047f5b2`, with 270 fewer ALMs and 278 fewer registers from fitter variance. Every endpoint TNS is zero with positive setup slack of 0.090 nanoseconds HDMI, 1.613 host, 1.844 decoder, 2.976 SPI, 7.405 video, 8.530 FPGA clock one, 11.824 FPGA clock two, 14.127 audio and 18.893 main; worst hold is 0.247, recovery 4.227, removal 0.460 and minimum pulse width 1.122 nanoseconds. The dedicated Phase-1P reports find zero violations across 100 same-clock decoder paths, 80 same-clock video paths and 30 decoder recovery paths. The 4,126,828-byte RBF has SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`.

#### Next Steps:

Retrieve and verify the currently installed RBF and helper before mutation. Preserve the accepted `047f5b2` RBF under a new exact rollback name, upload candidate `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea` through a staging name and retrieve it byte-identically before the rename, and replace the failed `9afe2f0` qualification directory with the corrected deterministic media while retaining its exact rollback directory. Leave Main and helper unchanged. Then power-cycle and run only corrected `00_good_480p_48k.mpg` with Audio Test Off, reporting audio-video alignment, any crackle or dropout and all three terminal LEDs; do not continue to `01` or any expected-failure case until that control is clean.

#### Files Modified:

- MediaPlayer_top_00.svh
- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_fifo.sv
- tools/streams/verify_d2_pcm_path.py
- tools/streams/check_media_compatibility.py
- tools/streams/finalize_program_stream.py
- tools/streams/generate_arm_av_test.py
- tools/streams/generate_compatibility_corpus.sh
- tools/streams/generate_test_big_buck_bunny.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 434 COMMIT Unreleased 9afe2f0 2026-08-24T05:24:13-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Record the failed first user-media control and isolate its repeatable crackle and absent terminal diagnostics.

#### Outcome:

The user power-cycled and ran `00_good_480p_48k.mpg` with Audio Test Off. Audio began roughly one second after video by the user's estimate, cracked twice at repeatable points, and USER, DISK and POWER all remained off, so the first control fails and the remaining qualification sequence is stopped. Host comparison rules out damaged decoded audio: the installed-source helper produces all 96,768 stereo samples at byte-identical length to FFmpeg with maximum sample error two, RMS error 0.5040, correlation `0.999999969`, and MPEG-frame boundary jumps of 167 counts against 168 in the reference. The terminal failure is independent and deterministic: the video's last bytes contain no sequence-end code, yet `check_media_compatibility.py` reports PASS and only emits a note, so the core cannot reach the sequence-ended quiet state that publishes the LED diagnostic. Static transport evidence isolates the crackle to starvation rather than decoding. After startup the helper emits 34,560 consecutive samples and then a 147,748-byte span with no PCM record; the 4,096-sample FPGA FIFO covers only 85.3 milliseconds, while the accepted hardware's 185,149-byte first-picture path completed in 155 milliseconds, predicting about 124 milliseconds for this span before allowing for decode backpressure. `audio_pcm_output_adapter` drives both channels to zero when the FIFO empties and resumes on the next sample, producing two deterministic amplitude edges and setting underrun only after data returns, exactly matching a repeatable two-edge crackle. This is an inference because the missing sequence end prevented telemetry capture. The full soak is exposed to the same problem, with measured post-start PCM-free spans up to 137,625 bytes. FFmpeg mux-rate changes are not a sufficient repair: they reduce this short control's gap at selected rates but produce spans up to 180,106 bytes at 5 Mbit/s and 1,883,117 bytes at 2.4 Mbit/s on the full movie. The reported startup offset remains approximate and should be measured from a recording after terminal framing and underrun are corrected rather than conflated with either defect.

#### Next Steps:

Do not run `01` or any expected-failure case on the current media set. The revised boundary needs user approval because it changes the approved host-only plan: make sequence-end presence a required compatibility condition, generate both the sequence-end video PES and Program Stream end for every good control, and increase the PCM FIFO from 4,096 to 8,192 samples so the current conversion recipe has 170.7 milliseconds of reserve without changing the 2,048-sample startup threshold. Prove the widened dual-clock FIFO, unchanged startup timing, underrun behavior and termination in focused simulation, run the full host regression, perform one timing-clean Quartus build, replace the RBF and corrected media with exact rollback, and repeat only `00_good_480p_48k.mpg` before resuming qualification. If the predicted resource or timing cost is not acceptable, the alternative is a larger ARM-side demux scheduler that reorders PCM throughout long video PES runs rather than relying on FFmpeg mux settings.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 433 COMMIT Unreleased 9afe2f0 2026-08-24T05:10:12-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Install the reproducible helper and complete v0.7 qualification media set while preserving exact rollback state.

#### Outcome:

Read-only retrieval first confirmed the MiSTer remained on accepted RBF SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` and helper SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0`. The official-toolchain `9afe2f0` helper was uploaded under a staging name, downloaded and confirmed byte-identical at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`, marked executable through the FTP server and installed, with its predecessor preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-user-media.3f4b272`. A new `/media/fat/games/MediaPlayer/v0.7_qualification` directory contains the 48 kHz control at `b140c76c61da3c8ec46baf90548f290db7657661cc39b2cb0b3e80510531a2dd`, the 44.1 kHz control at `bd3935aa35100544ce4d5fe06b8d9de0e8f48f1a606cd2419f7abcc4c8891c50`, six expected-failure cases at `e4140672b46214b300b1ca558d0a8005dee035bb79ec44ec7c75d341714e89df`, `3f7f2df8eb0c16dedf10fa3059184aab17067cae61305c5994706842fef79f57`, `98965d3223b50258d2e673e5d58786ae1b4152df758f9e9decf10f90a68c48d0`, `ee485d5693caf90304ca348bdedbae5b9ac0559ed383d3e796f811428a6fccb6`, `c4f986798e64081f0128c167a30ab62226ed2f1aa9959cf4e99da49cd21d86cb` and `5ea02141a0be7846389b378f996f67e986bfef2a60dc289f9a7df6ab78f829ce`, and the full soak at `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. Every remote file was retrieved and compared byte-for-byte before the staging area was discarded. Main and the accepted FPGA image are unchanged, no playback was launched, and the obsolete RBFs and older helper backups called out in Entry 430 remain untouched because their deletion was reserved for the user.

#### Next Steps:

Power-cycle once, set Audio Test to Off and run `00_good_480p_48k.mpg` followed by `01_good_480p_44k.mpg`. If both pass, run each numbered bad case for at most ten seconds and immediately replay `00_good_480p_48k.mpg` without rebooting; record the visible result and all three LEDs for both halves of every pair, treating an unavailable menu or failed control as a wedge. After all six pairs pass, power-cycle once and run `20_bbb_full_48k.mpg` through its complete 9:56 duration, checking opening alignment, scene transitions, the high-motion sequence near 7:22, credits and the audio tail, then leave the final image loaded for schema-eight capture. Roll back to `MediaPlayer_Helper.backup.pre-user-media.3f4b272` if the new helper itself fails to start.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 432 COMMIT Unreleased 9afe2f0 2026-08-24T04:58:03-07:00

#### Coming From:

Unreleased 1102830

#### Purpose:

Make the user-converted playback boundary reproducible and prepare the hardware failure sweep and full-length audio-video soak.

#### Outcome:

Commit `9afe2f0` makes the user-media qualification boundary reproducible without changing FPGA RTL or MiSTer Main. The official MiSTer ARM GNU 10.2 archive verifies at its previously recorded SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a`, identifies as GCC 10.2.1, and produces two byte-identical 361,452-byte static ARM EABI5 helpers at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. The helper's capabilities now advertise both 44.1 and 48 kHz, and the permanent generator and verifier exercise both short and faded profiles at each rate. Native and address-and-undefined-sanitized runs all preserve byte-identical video, one clean PCM end, maximum sample error two and correlation rounding to one; the 44.1 kHz paths carry mode byte one for 9,216 and 132,480 samples, while the 48 kHz paths carry mode byte three for 10,368 and 144,000 samples. Two independent generations reproduce the established 48 kHz fixture hash and the new 44.1 kHz fixture hash `8f522f8cc37be5e7a45f32599c5227946b6d1386cb93b452dfae0d37ef8987ff`, and the nine-case envelope corpus retains three passes and six expected failures. `generate_test_big_buck_bunny.py` preserves byte-identical video-only output and adds an opt-in Program Stream mode that verifies its demuxed video against the same sequence-ended elementary stream, carries source audio as stereo MPEG Layer II, writes the final sequence end in a bounded video PES and terminates with a Program Stream end code. The full local source at SHA-256 `4fc75fa403994e7c313da139d93a5aebdbda27cc951616aa4e480db6877c9850` generates a 100,059,153-byte, 14,315-picture, 596.458-second Program Stream at SHA-256 `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. The helper strips 13,401 timestamp records to reproduce all 84,423,309 FFmpeg-demuxed video bytes exactly and decodes 28,628,352 stereo PCM frames byte-for-byte in length against FFmpeg, with maximum sample error two, RMS error 0.5037 and correlation `0.999999979`.

#### Next Steps:

Install the exact official-toolchain helper with rollback preserved, then place the generated 44.1 and 48 kHz good controls, six bad cases and full-length soak Program Stream on the MiSTer. Hardware acceptance requires both good controls to play, every bad case to avoid ordinary success and recover immediately through the 48 kHz control without a reboot, and the full movie to complete with stable audio-video alignment, clean audio, normal LEDs and zero PCM protocol, underrun, presentation, decoder or aggregate error telemetry. No Quartus build is required because this commit changes no FPGA source.

#### Files Modified:

- host/arm/media_player_protocol.h
- tools/streams/generate_arm_av_test.py
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/verify_arm_av_pipeline.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 431 COMMIT Unreleased 1102830 2026-08-24T04:50:33-07:00

#### Coming From:

Unreleased 3f4b272

#### Purpose:

Accept 44.1 kHz audio and add a host-side input envelope checker with a deterministic corpus, as the first step toward user-converted playback.

#### Outcome:

The v0.7.0 goal is that users convert their own media with FFmpeg and test it, so the likely failure is an unsupported input rather than a decoder defect. Commit `1102830` addresses the two host-side halves of that. Adding 44.1 kHz proved to be a host-only change: `mpeg2_h262_inband_metadata` already extracts the rate bit from the record's mode byte, the top level already routes it, and `audio_pcm_output_adapter` already selects its phase step between `RATE_48000` and `RATE_44100`, so the entire FPGA path supported 44.1 kHz and only the helper rejected it. The helper now accepts 44,100 as well as 48,000 Hz and sets the mode bit from the decoded rate rather than hardcoding 48 kHz stereo, drains the pending queue before adopting a changed rate so held samples cannot be mislabelled, and reports the supported set when it refuses. Verification on a generated 44.1 kHz Program Stream shows 132,480 records all carrying mode byte one, while the accepted 48 kHz fixture still emits 144,000 records carrying mode byte three and its emitted stream is byte-identical to the previous build, so no 48 kHz behaviour changed. No FPGA rebuild is required. `check_media_compatibility.py` reports, before a file reaches hardware, whether it lies inside the implementation envelope, naming the FFmpeg option that fixes each problem: geometry against 720 by 480 and 45 by 30 macroblocks, frame-rate codes against the paced set one through five with codes six through eight named as unpaced, the progressive 4:2:0 frontend conditions delegated to the existing `analyze_h262_compatibility` so there is one video parser, and audio codec, sample rate and channel count. `generate_compatibility_corpus.sh` builds nine deterministic cases and asserts each verdict, and all nine agree: three good cases pass and six bad ones fail. Building that corpus immediately found a defect in the checker rather than in the core. Its Program Stream demultiplexer implemented only the MPEG-1 PES header form, so on the MPEG-2 PES packets FFmpeg actually emits it mis-stripped every packet and reported a valid video-only file as failing on picture 45. A checker that rejects good files is worse than none, since it sends users chasing a defect that does not exist. The demultiplexer now mirrors `parse_pes_header` in the helper exactly, and its output is byte-identical to FFmpeg's own demux of the same file. That defect also affected the analysis recorded in entry 428, which is corrected here: the fixture's video elementary stream is 185,149 bytes and its first picture spans 179,859 of them, not the 183,120 and 177,830 recorded there. The conclusion is unchanged at 97.1 percent, and the corrected total now matches the decoder's own reported `accepted_bytes` of 185,149 exactly, which the earlier figure did not.

#### Next Steps:

The 44.1 kHz helper cannot reach hardware yet. The user has directed that the official MiSTer ARM GNU 10.2 compiler be used from now on, and only the distribution's `arm-linux-gnueabihf-gcc` is present on the workstation, so no ARM binary was built or installed this cycle and the installed helper remains `3f4b272` at SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0`. Obtain that toolchain before the next helper installation. The remaining v0.7.0 work is the hardware half of the failure sweep and the long-duration audio-video soak. For the sweep, place the corpus's six bad cases on the MiSTer and require each to fail visibly and recoverably rather than wedging the core, which is the specific risk entry 425 demonstrated is real. For the soak, the acceptance target is full Big Buck Bunny playback with audio, which needs a source carrying audio; `generate_test_big_buck_bunny.py` expects `big_buck_bunny_480p_stereo.avi` beside it and does not fetch it, so the user must supply that file, and the generator must then be extended to mux MPEG Layer II audio into a Program Stream rather than emitting a silent elementary stream. That soak is the first test of audio-video drift beyond three seconds and of the startup lead on content whose first picture is small.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/check_media_compatibility.py
- tools/streams/generate_compatibility_corpus.sh

#### Status:

- [x] Built
- [ ] Passed

---
## 430 COMMIT Unreleased 3f4b272 2026-08-24T04:34:03-07:00

#### Coming From:

Unreleased 3f4b272

#### Purpose:

Record hardware acceptance of the helper's startup video lead and the collapse of the video startup offset.

#### Outcome:

The user power-cycled, ran `02_arm_mp2_faded_tones.mpg` with Audio Test Off and reports it working, with USER steady on, DISK steady off and POWER steady on. The schema-eight capture at SHA-256 `6daa2113e83baad9f0c9a5d90fa6b36d62e8b47243da1fda17b0bf5e3879cd26` reports `first_present_cycle` 9,307,288 at the 60 MHz decoder clock, so the first picture now presents 0.155 seconds into the session against 1.372 seconds on `047f5b2`, removing 1.217 seconds of black screen and reducing the offset by a factor of 8.8. All five pictures are displayed by 0.312 seconds. Audio follows its 2,048-sample reserve once PCM begins, so video now leads by a margin small enough to be imperceptible rather than trailing audio by a second, which is the alignment the user asked for. Every decode and audio invariant is unchanged: 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete with no presentation error, saturated PCM sample count 16,383, saturated FIFO peak of 127 or greater, no audio underrun, no PCM protocol error and zero aggregate error flags, freezing for quiet reason one with session quiet true at system-time second three. Session length rises from 3.015 to 3.224 seconds, which is expected now that the video burst precedes the PCM drain instead of being interleaved through it. The residual 0.155 seconds is transfer and decode of the 185 kilobyte payload, whose intra frame is 97 percent of it, and is no longer the real-time PCM throttle; that is the floor for this fixture rather than a defect. The ARM binary built with the undocumented `arm-linux-gnueabihf-gcc` 15.2 toolchain ran correctly, so the deviation recorded in entry 429 is proven harmless in this instance, though it remains unreproducible until the documented ARM GNU 10.2 compiler is available. `047f5b2` therefore stands as the accepted FPGA image and `3f4b272` as the accepted helper.

#### Next Steps:

Resume the deferred FPGA work: define and prove the response to a prolonged ARM producer stall after playback has begun, coordinating any pause or recovery with video presentation, and note that entry 425 established the constraint any such design must respect, since holding the PCM sink stalls the shared byte path and starves video. Housekeeping remains outstanding on the MiSTer, where `MediaPlayer.failed.d9022e6.rbf`, `MediaPlayer.reverted.62e8ccf.rbf` and the undocumented `MediaPlayer_test.rbf` are all obsolete or unaccounted for and should be removed by the user, along with the superseded helper backups. Obtain the documented ARM toolchain so helper builds become reproducible. Consider separately whether the nine-byte-per-sample in-band record format should carry multiple samples per record, since it inflates the audio roughly sevenfold against its compressed source and is the reason the shared path throttles at all; that is now a bandwidth question rather than a startup one.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 429 COMMIT Unreleased 3f4b272 2026-08-24T04:30:48-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Delay the in-band audio at startup by leading video ahead of it in the helper's emission order, and revert the presentation anchor that changed nothing.

#### Outcome:

Commit `dc862e1` reverts `62e8ccf`, so the functional RTL is byte-identical to accepted `047f5b2` again, and the MiSTer was returned to that image with `/media/fat/MediaPlayer.rbf` verifying at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`; the reverted build is retained as `MediaPlayer.reverted.62e8ccf.rbf`. Commit `3f4b272` implements the delay where it can work. The helper previously emitted each decoded sample as a nine-byte in-band record the moment it existed, so PCM records preceded the video bytes behind them and throttled those bytes to real time through the FPGA's `pcm_ready` gate. It now queues decoded PCM and writes video immediately, releasing the queue once the first picture is complete, detected by counting picture start codes in the emitted video, or once a bound of four seconds of audio is buffered, whichever comes first. The bound exists only to keep the buffer finite and had to be generous: an initial one-second bound ended the lead early and left the offset unchanged, because this fixture's intra frame is 97 percent of its video payload and sits behind 69,120 samples. Releasing on the first picture rather than on a fixed delay keeps the effect to startup, so steady-state interleaving is untouched and audio is not left permanently trailing video. Local measurement on `02_arm_mp2_faded_tones.mpg` shows the PCM emitted before the first picture completes falling from 69,120 samples to zero, so the modelled video delay falls from 1.440 seconds to zero against 1.372 seconds measured on hardware, a model error of five percent. The first PCM record now appears at emitted byte 185,158, after all video. Audio should therefore begin after its 2,048-sample reserve, about 43 milliseconds in, leaving video marginally ahead rather than a second behind. Three integrity checks hold: the in-band PCM payload reconstructed from the emitted records is byte-identical to the helper's own `--pcm-out` output, so the audio is delayed and not altered; that `--pcm-out` output is byte-identical to the unmodified helper, confirming the file path is untouched and that its long-standing difference from the FFmpeg reference is pre-existing and unrelated; and an elementary stream with no audio passes through byte-identical, since the queue never engages without PCM. The ARM helper was cross-compiled, verified byte-identical after upload and installed at SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0` with mode 755, its predecessor preserved as `/media/fat/linux/MediaPlayer_Helper.backup.pre-video-lead.104c5ff`. One deviation must be recorded: the documented toolchain is MiSTer Main's ARM GNU 10.2 compiler, but only `arm-linux-gnueabihf-gcc` 15.2 was available, and with no qemu on the workstation the ARM binary could not be executed before installation. It is statically linked and stripped, but it is unproven until it runs.

#### Next Steps:

Power-cycle the MiSTer, since the wedged core from `d9022e6` and the reverted `62e8ccf` are both still resident until a cold start, then run `02_arm_mp2_faded_tones.mpg` with Audio Test Off. Require video to appear essentially at once rather than 1.37 seconds late, audio to follow within about 43 milliseconds, tones to stay clean and separated with smooth fades, and LEDs to remain normal. If the helper fails to start at all, suspect the toolchain deviation first and roll back to `MediaPlayer_Helper.backup.pre-video-lead.104c5ff` before suspecting the lead logic. Capture a schema-eight snapshot over FTP and require `first_present_cycle` to collapse from 82,301,563 to a small fraction while the decode evidence holds at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags, with no audio underrun. Confirm separately that an older `.m2v` file is unaffected. Once accepted, delete `MediaPlayer.failed.d9022e6.rbf` and `MediaPlayer.reverted.62e8ccf.rbf`, obtain the documented ARM toolchain so helper builds are reproducible, and resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- host/arm/media_player_helper.c
- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_pts_presentation_timeline.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 428 COMMIT Unreleased 62e8ccf 2026-08-24T04:19:35-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Record that the presentation anchor did not move the startup offset and identify the real cause as real-time PCM pacing of the shared byte path.

#### Outcome:

The user recorded the run at 120 frames per second. Frame analysis places the blackout at 1.117 seconds and the first picture at 2.483 seconds, so the black screen lasts 1.366 seconds, and Goertzel analysis of the 440 and 660 Hz tones places audio onset near 1.50 seconds, leaving audio about one second ahead of video. A schema-eight capture of `62e8ccf` reports `first_present_cycle` 82,322,655 against 82,301,563 for `047f5b2`, a difference of 21,092 cycles or 0.35 milliseconds, so the anchor change moved nothing measurable and the hypothesis behind entry 426 was wrong. The same capture contains the evidence that should have refuted it before the build: `presentation_hold_total_cycles` is 5,728,829, only 0.095 seconds, so the timestamp admission gate was never holding pictures for anything like 1.372 seconds. The first picture was simply not available yet, and the reason is byte delivery. The helper emits each decoded PCM sample as a nine-byte in-band record, expanding 36,756 compressed audio bytes into 1,296,000 bytes and making PCM roughly 88 percent of the emitted stream, while `mpeg2_h262_inband_metadata` gates `input_ready` on `pcm_ready` and `MediaPlayer_top_00.svh` derives that from the PCM FIFO not being full. The shared byte path is therefore throttled to real-time 48 kHz sample delivery once the FIFO fills, which also explains the session lasting 180,910,349 cycles, or 3.015 seconds, for a three-second clip. The fixture makes this severe because its first picture is an intra frame spanning video elementary-stream bytes 30 through 177,860, which is 97.1 percent of all 183,120 video bytes, so almost the entire video payload must cross that throttled path before anything can be displayed. Two independent predictions confirm the mechanism. Only 2,042 audio bytes, or 8,000 samples, remain after the first picture completes, predicting 0.1667 seconds for the remaining four pictures against 0.1657 seconds measured, an error of 0.6 percent. Untimestamped `.m2v` files carry no PCM records, are never throttled, and start immediately, exactly as the user observes. This also explains why the reverted `d9022e6` deadlocked rather than merely delaying: holding the PCM sink stops the only path video bytes have.

#### Next Steps:

Do not pursue further FPGA-side changes for this offset until the emission order is fixed, because the throttle is a real-time sample rate rather than a byte volume and no reachable FIFO depth can absorb it; buffering the 2.8 seconds of PCM that precede the first picture would need roughly 4.7 megabits against 2.28 megabits of free block memory. The correct fix belongs in the ARM helper, which has ample Linux memory and full control of emission order: it should keep video bytes ahead of PCM records rather than emitting each sample as soon as it is decoded, holding only enough PCM in flight to keep the FPGA's 2,048-sample reserve fed. That is a host-side change costing no FPGA logic or timing, consistent with the user's instruction not to spend either on this offset. Decide separately whether to keep or revert `62e8ccf`, which costs 35 ALMs, changed nothing measurable on this fixture, and is defensible only as a correctness improvement for streams whose first metadata timestamp differs from their first picture timestamp. Consider also reducing the nine-byte-per-sample in-band record format, which inflates the stream roughly sevenfold against the compressed audio it replaces, though that is a bandwidth question and not the cause of this offset.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 427 COMMIT Unreleased 62e8ccf 2026-08-24T04:07:06-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Install the first-picture presentation anchor through staged, hash-verified replacement while preserving exact rollback state.

#### Outcome:

Installation used the FTP path with download-and-hash round trips in place of on-device hashing. Before installation `/media/fat/MediaPlayer.rbf` verified at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the accepted `047f5b2` restored after the `d9022e6` rollback, and both the staging and rollback names for this cycle were absent. The new RBF was uploaded as `MediaPlayer.upload.62e8ccf.rbf`, downloaded back and confirmed byte-identical to the local build, after which the displaced file was renamed to its rollback name and the staged file renamed into place. `/media/fat/MediaPlayer.rbf` now verifies at SHA-256 `74913cd13a7ecaa3748461da755041b32f47c61e9b3ec64643f7ae15e28c4336` and its predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-anchor.047f5b2.rbf`. The helper remains at `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a`. The failed `d9022e6` image remains set aside as `/media/fat/MediaPlayer.failed.d9022e6.rbf` and should be deleted once this cycle is accepted. No playback was launched and no `sync` could be issued, so the currently loaded core remains the prior in-memory RBF until reboot and the writes depend on the server flushing before the next power cycle.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require that video now starts immediately rather than 1.372 seconds late, that audio and video begin together, that the tones stay clean and separated with smooth fades, and that USER is steady on, DISK steady off and POWER steady on; then leave the completed image loaded for a schema-eight capture triggered over FTP. That capture must show `first_present_cycle` collapse from 82,301,563 to a small fraction of it while the accepted decode evidence is unchanged at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file still behaves exactly as before, since it never anchors the timeline. If any residual offset remains it is now the PCM startup reserve fill rather than the presentation gate, and should be measured before being treated as a defect.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 426 COMMIT Unreleased 62e8ccf 2026-08-24T04:06:21-07:00

#### Coming From:

Unreleased 4220cdc

#### Purpose:

Remove the video startup offset at its source by anchoring the presentation timeline to the first picture rather than the first metadata record.

#### Outcome:

`mpeg2_h262_pts_presentation_timeline` anchored `stc_90k` to the first in-band metadata timestamp, so the origin became whatever timestamp appeared first in the multiplex and any first picture whose own timestamp sat ahead of that origin waited the difference before the scheduler could admit it. Hardware telemetry measured that wait directly on `047f5b2` as `first_present_cycle` 82,301,563 at the 60 MHz decoder clock, or 1.372 seconds of black screen while ungated audio played. Commit `62e8ccf` anchors on the first candidate instead, taking `candidate_pts` as the origin, which makes the first picture due at once and leaves every later interval unchanged because intervals are differences in which the origin cancels. The `metadata_valid` and `metadata_pts` ports are removed; the in-band timestamp still feeds the association module that produces `candidate_pts`, so nothing upstream is pruned. This replaces the reverted audio-delay approach of `d9022e6`, which deadlocked, and costs roughly a mux and a condition rather than the buffer that approach would have required. The blast radius was checked before building rather than after: `anchored` and `stc_90k` are driven at `MediaPlayer_top_05.svh` and consumed nowhere else, so the only outputs reaching logic are `candidate_active` and `candidate_due` into the scheduler's admission gate, and because the timeline is a pure input to an admission decision with no back-pressure anywhere in its path it cannot create the circular stall that wedged `d9022e6`. A stream without timestamps never presents a valid candidate, never anchors and keeps the scheduler's free-running cadence exactly as before. The rewritten `tb_h262_pts_presentation_timeline` passes with the first candidate placed at 123,480 ticks, the measured hardware offset, requiring it to be due immediately and requiring the following picture to still wait its full 3,003 ticks; modulo two-to-the-33 wrap, late timestamps, individually missing timestamps and seek re-anchoring all still hold. The full eight-testbench parser and presentation regression is byte-identical to the accepted `047f5b2` baseline. The build completed in 9 minutes 28 seconds with zero errors and 257 warnings and uses 29,056 ALMs at 69 percent, 44,565 registers, 3,379,667 memory bits, 429 RAM blocks and 65 DSP blocks, a cost of 35 ALMs over `047f5b2` with 57 fewer registers where the metadata anchor path was removed. Worst-case setup slack recovers to 0.681 nanoseconds on `pll_hdmi` against 0.162 on `d9022e6` and 0.500 on `047f5b2`, with total negative slack of zero on every clock, which confirms that the tight path on the previous build was fitter placement variance in HDMI output logic rather than a consequence of either change.

#### Next Steps:

Install the resulting RBF at SHA-256 `74913cd13a7ecaa3748461da755041b32f47c61e9b3ec64643f7ae15e28c4336` and run `02_arm_mp2_faded_tones.mpg` with Audio Test Off, requiring that video now starts immediately instead of 1.372 seconds late, that audio and video begin together, that the tones stay clean and separated with smooth fades and that LEDs remain normal. Capture a schema-eight snapshot by writing a screenshot command to `/dev/MiSTer_cmd` over FTP and require `first_present_cycle` to fall to a small fraction of its previous 82,301,563 while the accepted decode evidence is unchanged at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file is unaffected. Any residual audio-ahead-of-video offset is now the PCM startup reserve fill time rather than the presentation gate, and should be measured before it is treated as a defect. Once accepted, resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_pts_presentation_timeline.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 425 COMMIT Unreleased 4220cdc 2026-08-24T03:45:41-07:00

#### Coming From:

Unreleased d9022e6

#### Purpose:

Record the hardware failure of the audio start gate, its root cause, and the rollback and revert that restore the accepted state.

#### Outcome:

Running `02_arm_mp2_faded_tones.mpg` on `d9022e6` hung the machine: the user reported a black screen with a short code in the corner and no playback. A screenshot command written to `/dev/MiSTer_cmd` over FTP was accepted but produced no file while ordinary FTP directory listing still worked, so MiSTer Main was wedged rather than Linux, and no schema-eight telemetry could be taken. Static tracing identifies a deadlock that the approved approach makes unavoidable in the current architecture, and the error is in the premise rather than in the implementation. The gate assumed audio and video are independently gated, but they share one back-pressured byte path. `MediaPlayer_top_00.svh` assigns `audio_pcm_ready` from `!audio_pcm_fifo_full` and forwards it to `mpeg2_new_inband_pcm_ready`, while `mpeg2_h262_inband_metadata.sv` includes `(!pcm_payload_final || pcm_ready)` in its `input_ready` term, so the in-band extractor stops accepting bytes from the HPS stream whenever the PCM sink is full. Holding the PCM output therefore fills the FIFO, deasserts `pcm_ready`, stalls the shared byte path, starves the video elementary stream, prevents any picture from decoding or presenting, and so prevents `video_started` from ever asserting, which holds the PCM output. The five-second bound does eventually release audio, but only after the decoder has been byte-starved for five seconds, by which point the core and Main are wedged. `tb_audio_pcm_output_adapter` could not have caught this because it drives the FIFO directly with no in-band extractor and no shared stream in the loop, so the adapter is correct in isolation and wrong in place. The MiSTer was rolled back over FTP: the failed image is retained as `/media/fat/MediaPlayer.failed.d9022e6.rbf`, and `/media/fat/MediaPlayer.rbf` verifies once more at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the accepted `047f5b2`. Commit `4220cdc` reverts both `946e81f` and `d9022e6` so that master's functional RTL is byte-identical to `047f5b2` again, retaining only the correction to the stale comment in `MediaPlayer_top_00.svh` that wrongly described presentation as free-running.

#### Next Steps:

The approved audio-delay approach cannot be implemented on the FPGA side without a buffer large enough to absorb the offset, because any hold on the PCM sink stalls video through the shared path; at 48 kHz stereo the measured 1.372-second offset is roughly 2.3 megabits in the current 35-bit sample format against about 2.28 megabits of free block memory, so it does not fit. Two viable directions remain and the user must choose before any further change. The first is to move the delay into the ARM helper, which has ample Linux memory and controls the byte stream directly, withholding PCM records for a lead while continuing to emit video bytes so the shared path never stalls. The second, and the cheaper and more standard of the two, is to remove the offset at its source: `mpeg2_h262_pts_presentation_timeline` anchors `stc_90k` to the first in-band metadata timestamp, so a picture whose own timestamp sits ahead of that anchor waits the difference, and anchoring instead to the first picture candidate would present the first picture immediately while preserving every subsequent interval, at a cost of roughly a mux and a condition rather than the logic and timing the user declined to spend. Take no further hardware action until that choice is made; the MiSTer needs a power cycle to load the restored `047f5b2`.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 424 COMMIT Unreleased d9022e6 2026-08-24T03:38:48-07:00

#### Coming From:

Unreleased d9022e6

#### Purpose:

Install the audio start gate through staged, hash-verified replacement while preserving exact rollback state.

#### Outcome:

Installation again used the FTP path with download-and-hash round trips in place of on-device hashing, since key-based SSH is still rejected. Before installation `/media/fat/MediaPlayer.rbf` verified at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, matching accepted `047f5b2`, and both the staging and rollback names were absent. The new RBF was uploaded as `MediaPlayer.upload.d9022e6.rbf`, downloaded back and confirmed byte-identical to the local build at SHA-256 `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5`, after which the displaced file was renamed to its rollback name and the staged file renamed into place. `/media/fat/MediaPlayer.rbf` now verifies at `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5` and its predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-audio-gate.047f5b2.rbf`. The helper remains at `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a` and the faded fixture at `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`, both byte-identical. No playback was launched, so the currently loaded core remains the prior in-memory RBF until reboot. As in the previous installation no `sync` could be issued, so the writes depend on the server flushing before the next power cycle.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require that audio and video now begin together rather than audio leading by roughly 1.4 seconds, that the tones stay clean and separated with smooth fades, that USER is steady on, DISK steady off and POWER steady on, and that no video artefact appears; then leave the completed image loaded so a schema-eight capture can be taken by writing a screenshot command to `/dev/MiSTer_cmd` over FTP. That capture must still report 185,149 accepted elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero aggregate error flags, and its `first_present_cycle` should be close to the 82,301,563 recorded for `047f5b2` since video timing is deliberately unchanged. Separately confirm an older `.m2v` file still starts immediately. Treat any video artefact as a candidate for a fitter seed retune before treating it as a functional defect, because `pll_hdmi` slack is 0.162 nanoseconds this build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 423 COMMIT Unreleased d9022e6 2026-08-24T03:19:14-07:00

#### Coming From:

Unreleased 047f5b2

#### Purpose:

Hold the PCM output until the first picture is presented so audio and video begin together on timestamped streams.

#### Outcome:

Audio began as soon as the startup reserve filled while video waited for the PTS-gated presentation timeline, so on a Program Stream audio led video by the first picture's timestamp offset. Rather than force video to present early, which would mean altering the presentation gate Entry 389 established and spending logic and timing margin on a path the user has accepted as correct, this cycle delays the audio instead. `MediaPlayer_top_05.svh` gains a decoder-domain sticky flag that sets on the first genuine display swap, detected from a change in the scheduler's `display_frame_bank`, `display_scratch` or `display_scratch_bank` outputs exactly as the cadence profiler detects one, but derived independently so that gating the profiler out later cannot silently remove it. That single bit crosses into `CLK_AUDIO` through a two-flop synchronizer in `MediaPlayer_top_00.svh`, consistent with the existing rule that only single bits cross between the decoder and audio domains. `audio_pcm_output_adapter` gains a `video_started` input qualifying only its initial transition out of idle, so mid-stream starvation, the accepted-end release for short clips and the audio-tail completion are unchanged. Holding audio cannot stall what video waits on, because the System Time Clock is a free-running accumulator on `CLK_AUDIO` whose `run` input is tied high and which therefore advances regardless of PCM consumption. Restoring telemetry proved decisive for sizing the bounded wait that prevents permanent silence when video never presents. Key-based SSH remains rejected, but `/dev/MiSTer_cmd` is writable over FTP, so uploading a one-line command file to it triggers a screenshot with no shell at all; the decoded schema-eight snapshot of the accepted `047f5b2` image reports 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete, saturated PCM sample count 16,383, saturated FIFO peak 127, no underrun, no PCM protocol error, zero aggregate error flags and a quiet reason-one freeze with session quiet true. It also reports `first_present_cycle` 82,301,563 at the 60 MHz decoder clock, placing the first picture 1.372 seconds into the session and measuring the reported delay directly. The initial two-second bound was therefore only 0.63 seconds clear of a real video start and its 26-bit parameter capped at 2.73 seconds, so a file with a larger timestamp offset would have hit the timeout and silently restored the very lead the gate removes; commit `d9022e6` widens the parameter to 27 bits and sets the bound to five seconds, which bounds silence without ever approaching a legitimate presentation. All six `tb_audio_pcm_output_adapter` cases pass, including the four predating the gate, which confirms the accepted paths are unchanged. The build completed in 9 minutes 31 seconds with zero errors and uses 29,188 ALMs at 70 percent, 44,885 registers, 3,379,667 memory bits, 429 RAM blocks and 65 DSP blocks, a cost of 167 ALMs over `047f5b2` for a flag, a synchronizer and one counter. Worst-case setup slack falls to 0.162 nanoseconds on the 152.21 MHz `pll_hdmi` domain with total negative slack of zero, while the decoder domain improves from 1.562 to 1.938 nanoseconds and every other domain holds at or above 1.6; the tightened path is in HDMI output logic this cycle does not touch, so it is fitter placement variance rather than a consequence of the change, but it is thinner than the 0.476 and 0.500 of the two preceding accepted builds and should be watched.

#### Next Steps:

Install the resulting RBF at SHA-256 `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5` and run `02_arm_mp2_faded_tones.mpg` with Audio Test Off, requiring that audio and video now begin together rather than audio leading by roughly 1.4 seconds, that the tones stay clean and separated with smooth fades, that LEDs remain normal and that a schema-eight capture still reports five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file still starts immediately, since it carries no timestamps and no audio for the gate to wait on, and that its video is not held by the bounded wait. If any video artefact appears, retune the fitter seed before treating it as a functional defect, because the `pll_hdmi` margin is the thinnest of the recent accepted builds. Once accepted, resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 422 COMMIT Unreleased 047f5b2 2026-08-24T03:19:13-07:00

#### Coming From:

Unreleased 047f5b2

#### Purpose:

Record the hardware acceptance of the block-memory row buffers and the audio-leads-video startup offset it exposed.

#### Outcome:

The user rebooted with Audio Test Off, ran `02_arm_mp2_faded_tones.mpg` and reported that it works well, with audio sounding fine and starting correctly, USER steady on, DISK steady off and POWER steady on. The 7,082-ALM recovery in `047f5b2` therefore carries no audible or visible decode regression and the block-memory conversion is hardware-accepted. The run did expose a startup offset that the user states is new: video now begins one to two seconds after audio on the Program Stream, while older elementary-stream `.m2v` files still start their video immediately. No schema-eight snapshot could be captured because triggering a screenshot writes to `/dev/MiSTer_cmd` over SSH and key authentication to the MiSTer is failing, so this acceptance rests on the user's direct observation and the LED states rather than on decoded telemetry. Static tracing locates the mechanism in the presentation gate rather than in the parser: `mpeg2_h262_b_presentation_scheduler` selects `timestamp_candidate_due` in place of the free-running cadence slot whenever a picture owns a timestamp, and `mpeg2_h262_pts_presentation_timeline` drives that gate from a decoder-domain timeline anchored once by the first in-band timestamp and advanced by the 90 kHz tick synchronized out of `CLK_AUDIO`. An elementary stream carries no timestamps, so its pictures present on cadence with no wait, while a Program Stream holds each picture until the timeline reaches its presentation time. Audio is not gated at all, so it begins as soon as the startup reserve fills and leads video by the first picture's timestamp offset. A stale comment in `MediaPlayer_top_00.svh` still states that nothing consumes the presentation clock and that presentation remains free-running; that was true at Entry 389 but the timeline module is now wired in at `MediaPlayer_top_05.svh` and the comment should not be trusted. The user has decided that the video delay itself is acceptable and must not be closed at the cost of logic or timing, and that audio should instead be held back to match it.

#### Next Steps:

Hold the PCM output adapter's initial start until the presentation side has actually displayed its first picture, so audio and video begin together without touching the parser, the presentation gate or the timeline. Restore key-based SSH access to the MiSTer so that screenshot triggering, on-device hash verification and `sync` become available again, since without a shell no schema-eight telemetry can be decoded and every install depends on the FTP fallback flushing on its own. Correct the stale free-running presentation comment in `MediaPlayer_top_00.svh` when the next change touches that file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 421 COMMIT Unreleased 047f5b2 2026-08-24T03:07:31-07:00

#### Coming From:

Unreleased 047f5b2

#### Purpose:

Install the headroom-recovery RBF through staged, hash-verified replacement while preserving exact rollback state.

#### Outcome:

Key-based SSH to the MiSTer failed for both `mister-media-player` and `mister-media-player-rsa`, each rejected as `Permission denied (publickey,password,keyboard-interactive)` while the stored host key still matched, so the device is the same machine but no longer accepts the recorded keys and its `authorized_keys` appears to have been cleared. The installation therefore used the FTP path already committed in `tools/build.sh` and substituted download-and-hash round trips for on-device hashing, which verifies the bytes actually stored rather than the bytes believed sent. Before installation the reachable MiSTer matched the accepted state exactly, with `/media/fat/MediaPlayer.rbf` at SHA-256 `b48d06e1b0f42e3465f48a1d89b10d0eb032edddcb4e02f8aab84c14854a75df`, the helper at `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a` and the faded fixture at `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`, and with both the staging and rollback names absent. The new RBF was uploaded as `MediaPlayer.upload.047f5b2.rbf`, downloaded back and confirmed byte-identical to the local build at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, after which the displaced file was renamed to its rollback name and the staged file renamed into place. `/media/fat/MediaPlayer.rbf` now verifies at `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` and its predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-row-ram.d70591c.rbf`. The helper and both audio fixtures remain unchanged and no playback was launched, so the currently loaded core remains the prior in-memory RBF until reboot. Two conditions are outstanding and were not present in earlier cycles: no `sync` could be issued because that requires a shell, so the writes rely on the server flushing before the next power cycle, and an undocumented `MediaPlayer_test.rbf` sits in `/media/fat` that no log entry accounts for.

#### Next Steps:

Restore key-based SSH access before the next installation cycle, since without a shell neither `sync` nor on-device verification is available and the FTP fallback cannot guarantee a flush. Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require the accepted five-picture video, the same clean lower left and higher right tones with smooth fades, USER steady on, DISK steady off, POWER steady on and no visible regression, then leave the completed image loaded for schema-eight capture before any replay or other file. The snapshot must still report 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end and presentation complete, with zero PCM protocol, underrun and aggregate error flags and a quiet reason-one freeze with session quiet true. Because the parser change is behavior-preserving and was proven byte-identical in simulation, any deviation should be treated as evidence against the block-memory conversion rather than as an audio regression.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 420 COMMIT Unreleased 047f5b2 2026-08-24T02:34:47-07:00

#### Coming From:

Unreleased d70591c

#### Purpose:

Recover fitter headroom by moving the two 512-byte slice row buffers out of distributed registers into block memory without altering parser behavior.

#### Outcome:

Fitter evidence from `d70591c` recorded 36,103 of 41,910 ALMs at 86 percent, and that build had already required a seed retune to close, so ALMs were the only binding resource. Entity accounting placed 29,242 ALMs inside `emu`, of which `mpeg2_h262_two_picture_probe` held 15,893 across the near-identical `b_core_probe` at 7,650 and `p_diagnostic_controller` at 7,619, while `mpeg2_h262_p_wide_motion_syntax_probe` alone held 5,101 ALMs against 5,267 registers. Static inspection isolated the mechanism: `mpeg2_h262_b_core_probe_part0.svh` and `mpeg2_h262_p_wide_motion_syntax_probe_part0.svh` each declared a 512-entry byte array named `row_bytes` read combinationally as `row_bytes[parse_byte_index][parse_bit_index]`, forcing 4,096 flops and a 512-to-one byte multiplexer into distributed logic per instance. Commit `047f5b2` converts both arrays to inferred block memory with an unconditional registered read placed ahead of the reset branch and addressed one byte in front of the bit pointer, which is safe because `parse_byte_index` advances only when `parse_bit_index` reaches zero and is therefore stable throughout the cycle preceding every byte boundary regardless of gaps in bit consumption. Entries zero and one moved to discrete registers so the chunk rollover needs no second write port, and the two carried bytes now come from shadow registers written alongside the array instead of a combinational read of its final two entries. Analysis and Synthesis confirms both arrays inferred as `altsyncram` rather than falling back to registers. The build completed in 9 minutes 37 seconds with zero errors and 257 warnings and uses 29,021 ALMs, 44,622 registers, 3,379,667 memory bits, 429 RAM blocks, 65 DSP blocks and three PLLs, recovering 7,082 ALMs and dropping utilization from 86 to 69 percent for two additional RAM blocks, well beyond the 2,500 to 4,000 estimate. `mpeg2_h262_two_picture_probe` falls to 8,609, `b_core_probe` to 3,977, `p_diagnostic_controller` to 4,007 and `wide_general_probe` to 1,500 against 1,163 registers, while `emu` falls to 22,049. Worst-case setup slack improves from 0.476 to 0.500 nanoseconds with total negative slack of zero on every clock. Equivalence was established before the build by a committed differential script that replays fixed streams through the eight Icarus testbenches instantiating these probes: every result line is byte-identical between unmodified and modified RTL, including all cycle counts, so the registered read adds no parser latency. The rollover path is genuinely covered, with eight P and eight B window refills in `tb_h262_parser_windows` and 291,641 bytes across 25 pictures in `tb_h262_live_raster_soak`. The script deliberately excludes `tb_h262_row_streaming` because its Entry 204 assertions require a dense capacity fixture exceeding 1,526 blocks and 32,768 coefficient events at 1,350 macroblocks that no committed generator reproduces, leaving it without a clean baseline to differentiate against.

#### Next Steps:

Install the resulting RBF at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` through the usual staged, hash-verified replacement, preserving the displaced `b48d06e1b0f42e3465f48a1d89b10d0eb032edddcb4e02f8aab84c14854a75df` under a commit-specific rollback name and leaving Main, the helper and both audio fixtures byte-identical. After one reboot, run only `02_arm_mp2_faded_tones.mpg` with Audio Test Off and require the accepted five-picture video, the same clean separated tones with smooth fades, USER steady on, DISK steady off and POWER steady on, then leave the completed image loaded for a schema-eight capture that must still report 185,149 accepted elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end and presentation complete with zero PCM protocol, underrun and aggregate error flags. Because the recovery landed at 69 percent, gating `mpeg2_h262_hardware_cadence_profiler` behind a compile-time parameter stays deferred and its 1,881 ALMs remain in reserve. Once the headroom is confirmed on hardware, resume the deferred audio work by defining and proving the response to a prolonged ARM producer stall after playback has begun, coordinating any pause or recovery with video presentation so Linux delay cannot silently create permanent audio-video drift.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part3.svh
- tools/streams/run_cycle_a_parser_equivalence.sh

#### Status:

- [x] Built
- [ ] Passed

---
## 419 COMMIT Unreleased d70591c 2026-08-24T02:20:34-07:00

#### Coming From:

Unreleased d70591c

#### Purpose:

Hardware-accept deterministic PCM startup reserve and audio-aware terminal completion with the sole faded Program Stream.

#### Outcome:

After rebooting with Audio Test Off, the user ran only `02_arm_mp2_faded_tones.mpg` and reported perfect sound, perfect video, USER steady on, DISK steady off and POWER steady on. The untouched 800-by-600 capture at SHA-256 `3062a977f2392a938f97604f2e3fe0f75ec3bc0d82deda273fa77d0af387b69b` shows the accepted final raster. Its schema-eight snapshot freezes for quiet reason one at system-time second three with session quiet true, directly reversing the prior reason-two timeout at second two while audio was active. It reports the expected saturated PCM sample count of 16,383 for the 144,000-sample file, saturated FIFO peak of 127 or greater, no audio underrun, no PCM protocol error and zero aggregate error flags. Video remains exact at 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end and presentation complete with no presentation error or residual scheduler ownership. Source `d70591c` and RBF SHA-256 `b48d06e1b0f42e3465f48a1d89b10d0eb032edddcb4e02f8aab84c14854a75df` are therefore the hardware-accepted startup-prefill and audio-tail telemetry boundary.

#### Next Steps:

Keep `d70591c` installed as the accepted audio-reserve baseline. The next isolated FPGA cycle should define and prove the response to a genuinely prolonged ARM producer stall after playback has begun, coordinating any pause or recovery with video presentation so Linux delay cannot silently create permanent audio-video drift. Continue using one video file for that development build and reserve the complete regression set for release qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 418 COMMIT Unreleased d70591c 2026-08-24T02:17:00-07:00

#### Coming From:

Unreleased d70591c

#### Purpose:

Install the timing-clean PCM-prefill RBF while preserving all non-FPGA artifacts and exact rollback state.

#### Outcome:

Before installation the reachable MiSTer matched the accepted state exactly: Main SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`, RBF `414f7fae21e628e978ff331f701f0c1435f4742ef27d3928e3ad168cbbda9498`, helper `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a`, short audio fixture `94a8ff0223dd1acba4d59fc1785741522c4361956f17848bf9ebbb8c0a503fe7` and faded fixture `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`; both staging and rollback names were absent. The new RBF was uploaded under its commit-specific temporary name, independently verified, atomically installed and synchronized. `/media/fat/MediaPlayer.rbf` now verifies at SHA-256 `b48d06e1b0f42e3465f48a1d89b10d0eb032edddcb4e02f8aab84c14854a75df`, and its displaced predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-pcm-prefill.d70591c.rbf`. Main, helper and both fixtures remain unchanged, no playback was launched, and the currently loaded core remains the prior in-memory RBF until reboot.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require the same clean lower left and higher right tones with smooth fades, the same correct video, USER steady on, DISK steady off, POWER steady on and no visible regression; then leave the completed image loaded for schema-eight capture before any replay or other file. The snapshot should retain zero PCM protocol, underrun and aggregate errors while freezing for quiet reason one with session quiet true after the audio tail, rather than the prior forced reason two while audio was still active.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 417 COMMIT Unreleased d70591c 2026-08-24T01:30:00-07:00

#### Coming From:

Unreleased 104c5ff

#### Purpose:

Add deterministic PCM startup prefill and defer terminal telemetry until embedded audio has drained cleanly.

#### Outcome:

Commit `d70591c` exposes the FIFO's read-domain occupancy and holds normal playback until 2,048 samples provide approximately 42.7 milliseconds of reserve at 48 kHz. A synchronized accepted-end level releases complete clips shorter than the threshold without deadlock, and a synchronized consumed-end result keeps embedded-audio sessions terminally pending until the clean end token drains; raw video and FPGA test modes retain their previous completion behavior. The profiler pauses only its forced nonquiet timeout for that explicit audio tail, while fatal errors still snapshot immediately. Focused proofs pass reserve gating, short-stream release, genuine post-start underrun detection, empty-before-end completion, audio-deferred telemetry, later forced telemetry and fatal priority. The first clean seed-eleven fit exposed an unrelated pre-existing decoder path at minus 0.109 ns, so the final boundary records deterministic fitter seed twelve without changing logic. The exact committed configuration then repeated a full Quartus 17.0.2 flow in 13 minutes 29 seconds with zero errors and zero endpoint TNS: global setup is plus 0.476 ns, decoder setup plus 0.683 ns, video setup plus 7.868 ns, hold plus 0.254 ns, recovery plus 4.420 ns, removal plus 0.653 ns and pulse width plus 1.122 ns. The build uses 36,103 ALMs, 52,687 registers, 3,371,475 memory bits, 427 RAM blocks and 65 DSP blocks; the 4,206,432-byte RBF has SHA-256 `b48d06e1b0f42e3465f48a1d89b10d0eb032edddcb4e02f8aab84c14854a75df`.

#### Next Steps:

Verify the MiSTer's current Main, RBF, helper and faded test identities, then stage and independently hash only the exact new RBF, preserve the displaced RBF under a commit-specific rollback name and leave Main, helper and both audio fixtures byte-identical. After reboot, run only `02_arm_mp2_faded_tones.mpg` with Audio Test Off and require unchanged clean separated sound and video, normal LEDs, zero audio errors and a quiet reason-one snapshot after the three-second audio tail rather than the prior forced reason-two snapshot.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- MediaPlayer.qsf
- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/tb_audio_pcm_output_adapter.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/verify_d2_pcm_path.py

#### Status:

- [x] Built
- [ ] Passed

---
## 416 COMMIT Unreleased 104c5ff 2026-08-24T01:25:12-07:00

#### Coming From:

Unreleased 104c5ff

#### Purpose:

Hardware-accept continuous ARM-decoded embedded audio after the minimp3 incremental-state repair.

#### Outcome:

After rebooting with Audio Test Off, the user ran only `02_arm_mp2_faded_tones.mpg` and reported perfect sound, correct channel separation, perfect video, USER steady on, DISK steady off and POWER steady on. This reverses the audible crackly onset on the pre-fix helper and confirms that eliminating the measured MPEG audio frame-boundary discontinuities fixes real hardware playback. The untouched 800-by-600 capture at SHA-256 `53660f47bcd2412645f818e375deaea5b07ab002e0235f123e5a338767c89896` shows the accepted final raster. Its schema-eight snapshot reports the expected saturated PCM sample count of 16,383 for the 144,000-sample file, saturated FIFO peak telemetry of 127 or greater, no audio underrun, no PCM protocol error and zero aggregate error flags; video retains 185,149 accepted elementary-stream bytes, three reference plus two B pictures, five displayed pictures, four swaps, sequence end and presentation complete with no presentation error. The video-centric profiler froze by forced terminal timeout at system-time second two while audio data was still draining, so its frozen `session_quiet` is false; the user's clean three-second listening result and the live steady LEDs provide the later terminal acceptance evidence. Commit `104c5ff`, helper SHA-256 `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a` and the installed FPGA path are therefore the accepted continuous embedded-PCM boundary.

#### Next Steps:

The next FPGA cycle should add a defined startup prefill threshold and make terminal telemetry audio-aware so a long audio tail defers the forced video timeout until the clean audio-end token drains; prove both with the single faded Program Stream and retain zero underrun or protocol errors. A later isolated cycle should coordinate a genuinely prolonged producer starvation event with presentation timing rather than silently allowing audio and video to drift. Continue using one video file per development build cycle and reserve the full regression pack for release qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 415 COMMIT Unreleased 104c5ff 2026-08-24T01:21:11-07:00

#### Coming From:

Unreleased 104c5ff

#### Purpose:

Install the continuity-corrected helper and sole longer audio-quality fixture while preserving the accepted FPGA, Main and rollback state.

#### Outcome:

Before installation the reachable MiSTer matched every expected identity: Main SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`, RBF `414f7fae21e628e978ff331f701f0c1435f4742ef27d3928e3ad168cbbda9498`, helper `04f9683cf02c5ed2268743cb0ff28570e1a36c71ad3f362c80f1359c89a2af4d` and original audio test `94a8ff0223dd1acba4d59fc1785741522c4361956f17848bf9ebbb8c0a503fe7`; all staging, target and rollback names for this cycle were absent. The repaired helper and faded test were uploaded under commit-specific temporary names, independently verified, atomically installed and synchronized. `/media/fat/linux/MediaPlayer_Helper` now verifies at SHA-256 `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a`, reports the unchanged protocol-one capabilities, and its displaced predecessor is preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-continuity.104c5ff`. `/media/fat/games/MediaPlayer/02_arm_mp2_faded_tones.mpg` verifies at SHA-256 `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`. Main, RBF and `01_arm_mp2_audio.mpg` remain byte-identical, and no playback was launched during installation.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Expect approximately 250 milliseconds of silence, a gentle onset, about two seconds of sustained lower 440 Hz left and higher 660 Hz right tones without periodic ticks or crackle, a gentle release and trailing silence while the accepted final video frame remains visible. Report sound quality, channel separation, video appearance and USER, DISK and POWER, then leave the final image loaded for schema-eight capture before any replay or other file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 414 COMMIT Unreleased 104c5ff 2026-08-24T01:15:36-07:00

#### Coming From:

Unreleased 22d2142

#### Purpose:

Preserve minimp3 synthesis continuity across incrementally delivered MPEG Layer II frames without changing the established PCM transport or FPGA path.

#### Outcome:

Commit `104c5ff` makes each incremental minimp3 call transactional by snapshotting `mp3dec_t`, restoring it whenever the current bytes cannot safely commit a frame, and retaining the undecided bytes until following input proves the frame boundary. End-of-input decoding now uses the exact remaining bytes rather than synthetic zero padding, eliminating the failed next-header comparison that cleared synthesis history. The verifier's original strict correlation floor is restored because the prior faded-profile relaxation measured this defect rather than legitimate decoder variance. Both short and faded profiles pass with native and address-and-undefined sanitized helpers: video remains byte-identical, one clean end token is emitted, sample counts remain exactly 10,368 and 144,000 stereo frames, maximum difference from FFmpeg falls from more than 5,000 to 2 and correlation rounds to `1.000000`. The repaired faded decode's worst 1,152-sample boundary jumps are 234 left and 352 right, matching the reference at 234 and 353 with no jump over 1,024; the pre-fix values were 4,080 and 4,115. Two official GCC 10.2 builds are byte-identical; the 357,356-byte static ARM EABI5 helper has SHA-256 `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a`. PCM format, transport, FPGA source and Main are unchanged, so no Quartus or Main build is required.

#### Next Steps:

Verify the current MiSTer helper, RBF, Main and original test file, then stage and independently hash only the repaired helper and `02_arm_mp2_faded_tones.mpg`; preserve the current helper for rollback and leave the accepted RBF, Main and original file byte-identical. After reboot, run only the faded file and require clean leading silence, gradual onset, sustained separated tones without periodic crackle, gradual release, accepted video, normal LEDs and zero schema-eight errors, then leave the final image loaded for launch-free capture.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 413 COMMIT Unreleased 22d2142 2026-08-24T01:08:05-07:00

#### Coming From:

Unreleased 8bbd55c

#### Purpose:

Create one longer faded embedded-audio fixture that isolates sustained PCM quality on the accepted hardware without changing Main, the helper or FPGA source.

#### Outcome:

Commit `22d2142` adds explicit short and faded profiles while retaining the exact accepted five-picture video. Two complete generations are deterministic, and the short Program Stream and both references remain byte-identical at their established hashes. The new 260,096-byte `02_arm_mp2_faded_tones.mpg` has SHA-256 `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`; it decodes to exactly 144,000 stereo samples across three seconds with zero-valued leading and trailing silence, rising and falling fade windows, sustained 440 Hz left and 660 Hz right tones and approximately 46 dB channel separation. Its demuxed video is byte-identical to the accepted reference. Extending the verifier to measure MPEG audio frame boundaries then converted the user's slight crackle into a deterministic defect: the current helper jumps by 4,080 counts left and 4,115 right to zero at some 1,152-sample boundaries in both the short and faded fixtures, while FFmpeg's continuous references remain at or below 234 left and 353 right. Static inspection isolates the mechanism: when an incremental buffer ends on a complete frame or incomplete next frame, minimp3 may clear its synthesis state while searching for an unverifiable next header, and the helper consumes or retains that call without restoring the decoder state. The quality file was deliberately not installed because asking the user to confirm a known discontinuity would add no evidence; the MiSTer and all installed artifacts remain unchanged.

#### Next Steps:

Open a helper-only repair cycle that snapshots and restores `mp3dec_t` whenever an incremental call cannot safely consume a frame, retains the last complete frame until a following header is available, and decodes the final exact-sized frame at end of input without synthetic padding. Require both profiles to retain exact sample counts, clean end framing and their existing correlations while reducing helper boundary jumps below the reference-derived limits. Build the static ARM helper twice with the official GCC 10.2 toolchain, install only that helper with rollback preserved, then upload the existing faded-quality file and run it as the sole hardware video for the cycle; no RBF or Main change is indicated.

#### Files Modified:

- tools/streams/generate_arm_av_test.py
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 412 COMMIT Unreleased 8bbd55c 2026-08-24T01:06:03-07:00

#### Coming From:

Unreleased 8bbd55c

#### Purpose:

Hardware-qualify the first FPGA-owned playback of ARM-decoded embedded audio and preserve the brief onset-quality observation.

#### Outcome:

After rebooting into the installed `8bbd55c` RBF and helper, the user ran `01_arm_mp2_audio.mpg` several times to hear its deliberately short audio and reported both tones audible with correct channel separation, the lower tone on the left and higher tone on the right, while the video remained visually correct. The user heard a slight crackly onset that sounded attributable to hearing only the beginning of the approximately 0.2-second fixture, then left the final run loaded with USER steady on, DISK steady off and POWER steady on. The untouched 800-by-600 capture at SHA-256 `04840e9c76c0f0fa90df7200b4692eaa1041330977b6483b8941ba9927b2de4f` shows the accepted completed raster. Its schema-eight quiet snapshot reports all 10,368 PCM samples extracted, saturated peak FIFO telemetry of 127 or greater, no audio underrun, no PCM protocol error and zero aggregate error flags; video reports 185,149 accepted elementary-stream bytes, three reference plus two B pictures, five displayed pictures, four swaps, sequence end, session quiet and presentation complete. The captured run therefore proves the helper-to-FPGA PCM transport, left-right sample ordering and MiSTer audio output without Linux ALSA, and rules out FIFO starvation as the cause of its reported onset texture.

#### Next Steps:

Treat `8bbd55c` as the accepted embedded-PCM transport boundary. Before changing the playback path for the onset observation, generate one longer Program Stream with silence or a short fade before and after sustained channel-identity tones and run only that file on the current build; a clean sustained body would identify the crackle as the deliberately abrupt short fixture, while persistent crackle would justify inspecting sample continuity at record boundaries. After that diagnostic, add startup FIFO prefill and coordinated prolonged-starvation handling before claiming 0.7.0 audio is resilient to Linux scheduling delays, continuing the user's rule of one video file per development build cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 411 COMMIT Unreleased 8bbd55c 2026-08-24T00:58:17-07:00

#### Coming From:

Unreleased 8bbd55c

#### Purpose:

Install the timing-clean in-band PCM RBF and ARM helper while preserving the accepted Main, test video and exact rollback artifacts.

#### Outcome:

Before installation the reachable MiSTer matched the accepted state exactly: Main SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`, RBF `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`, helper `4f6ac001a4a0455c20e1148cedf7548768258abfafb2299a3f8b171a5383fa8e` and `01_arm_mp2_audio.mpg` `94a8ff0223dd1acba4d59fc1785741522c4361956f17848bf9ebbb8c0a503fe7`. The new RBF and helper were uploaded under commit-specific temporary names, independently verified on the MiSTer, and only then installed as a pair and synchronized. `/media/fat/MediaPlayer.rbf` now verifies at SHA-256 `414f7fae21e628e978ff331f701f0c1435f4742ef27d3928e3ad168cbbda9498`, and `/media/fat/linux/MediaPlayer_Helper` verifies at `04f9683cf02c5ed2268743cb0ff28570e1a36c71ad3f362c80f1359c89a2af4d`; Main and the sole test video remain byte-identical to their accepted hashes. Exact rollback copies of the displaced RBF and helper are preserved as `/media/fat/MediaPlayer.backup.pre-inband-pcm.8bbd55c.rbf` and `/media/fat/linux/MediaPlayer_Helper.backup.pre-inband-pcm.8bbd55c`. No playback was launched, and the currently loaded core remains the prior in-memory RBF until reboot.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer, ensure Audio Test is Off and run only `01_arm_mp2_audio.mpg`. Listen for the lower 440 Hz tone in the left channel and the higher 660 Hz tone in the right channel while confirming the previously accepted five-picture video; report what is audible, whether either channel gaps or crackles, and the USER, DISK and POWER LEDs, then leave the final image loaded for schema-eight capture before any replay or additional file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 410 COMMIT Unreleased 8bbd55c 2026-08-24T00:27:49-07:00

#### Coming From:

Unreleased 8fc80ee

#### Purpose:

Transport ARM-decoded PCM in band to the FPGA-owned audio FIFO without expanding the MiSTer Main patch.

#### Outcome:

Commit `8bbd55c` replaces the helper's default dummy-ALSA sink with fixed in-band signed sixteen-bit stereo PCM records and a clean audio-end token on its existing standard-output stream while retaining explicit raw PCM files for host verification. The FPGA strips these reserved records before H.262 parsing, backpressures the last payload byte until the audio FIFO accepts it, and routes the recovered samples through the existing audio output; Audio Test modes retain their proven source, mode Off selects embedded PCM, and each download start flushes and re-arms the path. Analysis of the actual helper output showed runs of up to 4,608 samples separated by video data, so the proposed 256-sample FIFO was correctly expanded to 4,096 samples, or 85.3 milliseconds at 48 kHz, before building. Schema eight preserves the 38-word snapshot while adding sample count, saturated peak occupancy, protocol error and underrun telemetry. Native and sanitized verification recovered exactly 10,368 stereo samples with correlation `0.974933`, one clean end token, byte-identical raw M2V and correct malformed-record rejection; focused extractor, output-adapter, scheduler and telemetry simulations all pass, including terminal empty-before-end behavior without a false underrun. Two official GCC 10.2 ARM builds are byte-identical; the 357,356-byte static helper has SHA-256 `04f9683cf02c5ed2268743cb0ff28570e1a36c71ad3f362c80f1359c89a2af4d`. Quartus 17.0.2 completes in 12 minutes 48 seconds with zero errors, and every timing category is positive with zero endpoint TNS: plus 0.229 ns setup, plus 0.249 ns hold, plus 3.640 ns recovery, plus 0.619 ns removal and plus 1.122 ns pulse width; the focused decoder and video audits report plus 0.549 ns and plus 7.191 ns respectively. The build uses 35,970 ALMs, 52,897 registers, 3,371,475 memory bits, 427 RAM blocks and 65 DSP blocks; the 4,271,012-byte RBF has SHA-256 `414f7fae21e628e978ff331f701f0c1435f4742ef27d3928e3ad168cbbda9498`.

#### Next Steps:

Verify the MiSTer's currently installed Main, RBF, helper and sole test file, then install only the exact new RBF and helper through staged hash verification while retaining rollback copies and leaving Main unchanged. After reboot, run only `01_arm_mp2_audio.mpg` with Audio Test Off and require the accepted five-picture video plus the lower 440 Hz left tone and higher 660 Hz right tone, normal LEDs and zero audio error telemetry. This first hardware cycle proves audible embedded PCM transport; a subsequent cycle must add startup prefill and coordinated prolonged-starvation handling before claiming Linux scheduling cannot produce an audible gap or audio/video drift.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_07.svh
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/read_hardware_cadence.py
- tools/streams/tb_audio_pcm_output_adapter.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_inband_metadata.sv
- tools/streams/verify_arm_av_pipeline.py
- tools/streams/verify_d2_pcm_path.py

#### Status:

- [x] Built
- [ ] Passed

---
## 409 COMMIT Unreleased 8fc80ee 2026-08-24T00:23:05-07:00

#### Coming From:

Unreleased 8fc80ee

#### Purpose:

Record the first complete ARM Program Stream hardware run and isolate its silent embedded audio after successful decode.

#### Outcome:

After rebooting into the installed `8fc80ee` Main, the user ran only `01_arm_mp2_audio.mpg` and reported video matching the accepted image, no embedded audio, a working FPGA sound test, USER steady on, DISK steady off and POWER steady on. The untouched 800-by-600 screenshot at SHA-256 `58c29e09dc3eae48075064314df863404434c7e881e68a6404107c303830c78a` shows the expected completed five-picture raster and its schema-seven telemetry decodes 185,149 accepted elementary-stream bytes, one timestamp association, three reference plus two B pictures, five displayed pictures, four swaps, sequence end seen, session quiet and presentation complete with zero decoder or presentation errors. Main's retained log confirms the absolute path `file:/media/fat/games/MediaPlayer/01_arm_mp2_audio.mpg`, 185,158 submitted annotated bytes over 46 reads, clean EOF and helper exit zero. The helper reports decoding all nine MPEG Layer II frames into 10,368 stereo PCM frames, so source, demux and audio decode succeeded. Read-only ALSA enumeration exposes only card zero `Dummy PCM`; `aplay` accepts the samples and exits successfully but sends them to that discard device. The working sound test uses the proven FPGA PCM output path and therefore does not validate Linux ALSA. This isolates silence to the temporary ALSA output choice rather than the video transport, decoder, test content or MiSTer audio hardware.

#### Next Steps:

Replace the temporary ALSA sink with the user-directed FPGA-owned PCM path while avoiding another Main change. Extend the existing in-band ingress protocol with a reserved PCM record type, have the helper place decoded signed 16-bit stereo samples into those records on its current standard-output stream, and extend the FPGA extractor to remove them from H.262 while applying audio-FIFO backpressure and feeding the already hardware-proven PCM output adapter. Preserve raw M2V passthrough, timestamp records, audio test modes, reset flush, bounded FIFO occupancy and underrun telemetry; build and install only the helper and RBF, then replay the same sole Program Stream and require the two embedded channel tones with the already accepted video result.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 408 COMMIT Unreleased 8fc80ee 2026-08-24T00:17:00-07:00

#### Coming From:

Unreleased 8fc80ee

#### Purpose:

Install the absolute-path Main correction while preserving the diagnostic build and every unchanged media artifact.

#### Outcome:

Before installation the MiSTer was reachable and `/media/fat/MiSTer` matched the running diagnostic build at SHA-256 `1ee8e337e8583fdf4ac585934734fcd7d6af1f8a7130f5e1adcb7ecaebf4a1e4`; the accepted RBF, helper and sole Program Stream also matched their established hashes. The 1,166,244-byte `8fc80ee` Main was uploaded under the exact staging name `/media/fat/MiSTer.upload.8fc80ee`, independently verified at SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`, made executable and atomically installed on the FAT volume, then synchronized and verified again. The displaced diagnostic Main is preserved at `/media/fat/MiSTer.backup.pre-pathfix.b357c51` and verifies at its original SHA-256. `/media/fat/MediaPlayer.rbf`, `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/games/MediaPlayer/01_arm_mp2_audio.mpg` remain byte-identical at SHA-256 `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`, `4f6ac001a4a0455c20e1148cedf7548768258abfafb2299a3f8b171a5383fa8e` and `94a8ff0223dd1acba4d59fc1785741522c4361956f17848bf9ebbb8c0a503fe7` respectively. The old diagnostic Main remains in memory until reboot, and no playback was launched during installation.

#### Next Steps:

Keep the USB DVD drive disconnected, reboot once to start the installed `8fc80ee` Main, enter MediaPlayer and run only `01_arm_mp2_audio.mpg`. Confirm the five-picture video plays instead of remaining blank, the embedded 440 Hz left and 660 Hz right tones are audible in their correct channels, playback completes cleanly, and report USER, DISK and POWER LEDs; leave the final image loaded so the retained diagnostic log and frame can be captured before any replay or additional file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 407 COMMIT Unreleased 8fc80ee 2026-08-24T00:12:57-07:00

#### Coming From:

Unreleased b357c51

#### Purpose:

Resolve MediaPlayer menu selections to Main's established absolute storage path before starting the ARM helper.

#### Outcome:

Commit `8fc80ee` confines the correction to the isolated Main patch. `mediaplayer_start` continues rejecting unsupported extensions, then immediately copies the path returned by Main's existing `getFullPath` resolver into the helper's `file:` source specification before the resolver's shared buffer can change. This corrects the demonstrated relative-path failure without hardcoding the SD-card mount, changing the helper protocol, altering transfer behavior or adding DVD work, and preserves the same resolution behavior Main already uses for SD, USB and network-backed menu selections. The patch applies cleanly to pinned official Main commit `0a8fb44`. Two clean builds with the verified official Arm GNU 10.2-2020.11 compiler produce byte-identical 1,166,244-byte ARM EABI5 executables at SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`.

#### Next Steps:

Install only the exact Main at SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa` through staged upload and independent remote verification while preserving the current diagnostic Main for rollback. Keep the accepted RBF, helper, `01_arm_mp2_audio.mpg` and disconnected DVD untouched; after reboot, run only that Program Stream and require normal video, the embedded left and right tones, clean completion and normal LEDs before any further source cycle.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---
## 406 COMMIT Unreleased b357c51 2026-08-24T00:11:44-07:00

#### Coming From:

Unreleased b357c51

#### Purpose:

Record the diagnostic hardware result that isolated blank playback to an unresolved relative source path.

#### Outcome:

After the requested reboot and single playback of `01_arm_mp2_audio.mpg`, the user observed a blank image with USER, DISK and POWER all off, and the untouched capture confirmed a uniformly blank active frame. The installed diagnostic Main, accepted RBF, helper and test stream retained their established SHA-256 identities. `/tmp/MediaPlayer_ARM.log` proves that Main selected the helper for menu index 65 and asserted download, but passed `file:games/MediaPlayer/01_arm_mp2_audio.mpg`; because the helper starts with `/` as its working directory, it could not open that relative name and exited with code one after reporting `No such file or directory`. Main consequently recorded 633 nonblocking waits, zero successful reads and zero submitted bytes before releasing download. This result isolates the failure before SPI, FPGA decode or audio presentation and explains both the blank frame and inactive LEDs without indicating a new hardware lockup.

#### Next Steps:

For the next single-file development cycle, make Main resolve the selected menu path through its established `getFullPath` API before constructing the helper's `file:` source specification, then build a Main-only image with the official GCC 10 toolchain, install it with rollback preserved, reboot and replay only `01_arm_mp2_audio.mpg`. Do not change the RBF, helper, test stream or DVD support in this correction; using Main's existing storage resolver avoids hardcoding `/media/fat` and preserves future USB and network source handling.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 405 COMMIT Unreleased b357c51 2026-08-24T00:07:29-07:00

#### Coming From:

Unreleased b357c51

#### Purpose:

Install the reproducible Main-only handoff diagnostic while preserving exact rollback and leaving every media-path artifact unchanged.

#### Outcome:

The MiSTer recovered normally after the user disconnected the USB DVD drive, confirming that the interrupted reboot was external to this build cycle. Before installation it was reachable by network, sitting in the normal menu, and running the exact prior Main at SHA-256 `7f6ef2d299e9619250f300764836c8bf30409f7f452cd34248effda6e6536a39`; the accepted RBF, helper and test stream also matched their established hashes. The 1,166,244-byte `b357c51` diagnostic Main was uploaded under a temporary name, independently verified at SHA-256 `1ee8e337e8583fdf4ac585934734fcd7d6af1f8a7130f5e1adcb7ecaebf4a1e4`, made executable and atomically installed as `/media/fat/MiSTer`, then synchronized and verified again. The displaced source-neutral Main was preserved at `/media/fat/MiSTer.backup.pre-diagnostic.55d06ce` and verifies at its original SHA-256 `7f6ef2d299e9619250f300764836c8bf30409f7f452cd34248effda6e6536a39`; the original official Main rollback also remains present. `/media/fat/MediaPlayer.rbf`, `/media/fat/linux/MediaPlayer_Helper` and `/media/fat/games/MediaPlayer/01_arm_mp2_audio.mpg` remain byte-identical. The currently running menu process remains the prior in-memory Main until reboot, so no playback or hardware test occurred during installation.

#### Next Steps:

Keep the USB DVD drive disconnected, reboot once to start the installed diagnostic Main, enter MediaPlayer and run only `01_arm_mp2_audio.mpg`. Leave the resulting image loaded and report the USER, DISK and POWER LEDs. Do not replay, reset or launch another file until the frame and `/tmp/MediaPlayer_ARM.log` have been captured, because that single log is intended to decide whether the helper was selected, how many bytes reached SPI and why the transfer ended.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 404 COMMIT Unreleased b357c51 2026-08-23T23:46:41-07:00

#### Coming From:

Unreleased 55d06ce

#### Purpose:

Add bounded persistent diagnostics to Main's MediaPlayer helper-to-SPI broker so one replay can identify the failed handoff stage.

#### Outcome:

Commit `b357c51` confines the change to the isolated Main patch and does not alter transfer ordering, buffering, the helper protocol, decoder output or FPGA behavior. The broker creates a fresh `/tmp/MediaPlayer_ARM.log` when a source starts and records the source, index, helper process identifier, download assertion, bounded would-block events, every positive pipe read, cumulative bytes submitted through `user_io_file_tx_data`, EOF or error, download release, child wait status and every explicit stop reason. Helper standard error is redirected into the same append-only descriptor, and log-open failures remain nonfatal. Ubuntu GCC 15.2 was tried only as a local build tool and failed in untouched upstream Main because its current ARM headers and stricter C++ handling are incompatible with this pinned 2025 source; no binary was produced or installed. The user then directed the project back to MiSTer's official Arm GNU 10.2-2020.11 toolchain. The verified official archive has SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a`, identifies as GCC 10.2.1, applies the patch cleanly to Main commit `0a8fb44` and produces two byte-identical 1,166,244-byte ARM EABI5 builds at SHA-256 `1ee8e337e8583fdf4ac585934734fcd7d6af1f8a7130f5e1adcb7ecaebf4a1e4`. The expected diagnostic strings are present in the stripped artifact.

#### Next Steps:

Install only the exact `1ee8e337e8583fdf4ac585934734fcd7d6af1f8a7130f5e1adcb7ecaebf4a1e4` diagnostic Main through staged upload and independent remote hash verification, retaining the official rollback and leaving `/media/fat/MediaPlayer.rbf`, `/media/fat/linux/MediaPlayer_Helper`, `01_arm_mp2_audio.mpg` and `/dev/sr0` untouched. Reboot once, replay only `01_arm_mp2_audio.mpg`, leave the resulting frame loaded and report the LEDs; then capture the frame and retrieve `/tmp/MediaPlayer_ARM.log` before proposing any transport correction.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---
## 403 COMMIT Unreleased 55d06ce 2026-08-23T23:44:24-07:00

#### Coming From:

Unreleased 55d06ce

#### Purpose:

Record the first source-neutral ARM loader hardware failure and isolate it without changing or replaying the loaded state.

#### Outcome:

After rebooting into the exact installed Main at SHA-256 `7f6ef2d299e9619250f300764836c8bf30409f7f452cd34248effda6e6536a39`, the user selected only `01_arm_mp2_audio.mpg` and observed a split-second flash of white vertical bars followed by black video, with USER, DISK and POWER all steadily off while the MiSTer menu remained responsive. A screenshot captured from the untouched final state is uniformly blank within the active raster and contains no cadence telemetry, while all three LEDs off maps to no valid diagnostic snapshot, so the FPGA never reached a settled decoder session. The installed helper, Main, test stream and accepted RBF remain byte-identical to entry 402. Running that same installed helper independently on the MiSTer, without replaying into the FPGA, succeeds both with file outputs and with its normal `aplay` path: it emits all 185,158 video bytes, one timestamp record, nine MPEG Layer II frames and 10,368 stereo PCM frames with exit status zero. This rules out the file, Program Stream parser, MP2 decoder, ordinary MiSTer audio output and RBF identity, and confines the failure to Main's new asynchronous helper-to-SPI handoff or its lifecycle. The connected DVD remained unmounted and its boot-time protected-sector read warnings are unrelated.

#### Next Steps:

Instrument only Main's isolated MediaPlayer broker so the next replay of this same file records whether the helper was selected, the source string and index passed, every stdout read and cumulative SPI byte count, download assertion and release, child exit status and any stop reason in a temporary log retrievable without the console. Keep the accepted RBF, helper decoder, test stream and DVD untouched. Rebuild and install only Main, reboot, replay only `01_arm_mp2_audio.mpg`, capture the blank or completed frame and retrieve the log before choosing a transport fix; do not expand to another video until this handoff is understood.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 402 COMMIT Unreleased 55d06ce 2026-08-23T23:33:09-07:00

#### Coming From:

Unreleased 55d06ce

#### Purpose:

Install the source-neutral ARM helper boundary without touching the accepted RBF or connected development DVD.

#### Outcome:

The exact `55d06ce` artifacts were uploaded under temporary names, independently hash-checked, installed, synchronized and verified again. `/media/fat/MiSTer` now has SHA-256 `7f6ef2d299e9619250f300764836c8bf30409f7f452cd34248effda6e6536a39`, `/media/fat/linux/MediaPlayer_Helper` has SHA-256 `4f6ac001a4a0455c20e1148cedf7548768258abfafb2299a3f8b171a5383fa8e`, and the accepted RBF remains `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`. The original official Main rollback remains byte-identical at `/media/fat/MiSTer.backup.pre-arm-c9e5aff.7ca3cd2f`. The user rebooted during the refactor, before this replacement, so the current PID 530 process maps the deleted earlier Main image at SHA-256 `51b4e122e6bb3f1f7c62bcfb176d32528b5d08f48b04682d74e59e53fef8c900`; the newly installed source-neutral build will not execute until one additional reboot. The connected `/dev/sr0` DVD remains unmounted and no disc content was read.

#### Next Steps:

Reboot once to start the installed `55d06ce` Main, then run only `01_arm_mp2_audio.mpg`. Confirm MPG visibility, immediate return without the Loading screen, normal five-picture video, correct 440 Hz left and 660 Hz right embedded tones and all LED states, then reset and replay the same file once and leave the final image loaded. Do not select, mount or inspect the connected DVD during this cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 401 COMMIT Unreleased 55d06ce 2026-08-23T23:25:11-07:00

#### Coming From:

Unreleased c9e5aff

#### Purpose:

Make the ARM helper source-agnostic and versioned now so later USB DVD work extends the helper without expanding the MiSTer Main patch.

#### Outcome:

The connected development drive is detected by the existing MiSTer installation as USB optical device `/dev/sr0`, an HL-DT-ST DVDRAM GP63EX70, and the inserted UDF DVD is identified without mounting as `THE_BIG_LEBOWSKI`; kernel SCSI, optical block, USB storage, ISO9660 and UDF support are already present. Commit `55d06ce` does not mount, navigate, decrypt or decode that disc. It replaces the helper's direct `FILE` dependency with an operation-table media-source interface, implements `file:` plus transitional bare paths, reserves `dvd:` as a recognized but deliberately unsupported source, rejects unknown schemes and missing files, validates protocol version one, and publishes a stable machine-readable capabilities line. The architecture document fixes ownership for future source and navigation, container demux, timeline discontinuities, codec selection and outputs, while explicitly deferring every DVD feature. Main still owns SPI and its isolated broker now accepts an opaque source string; the file-selector wrapper alone constructs `file:`, so a later disc action can pass `dvd:` without changing process, pipe or FPGA-transfer ownership. Native and address-and-undefined-sanitized verification preserves byte-identical M2V, byte-identical Program Stream video after stripping one PTS record, all 10,368 PCM frames at 0.974933 correlation to FFmpeg, exact legacy-path and file-URI equivalence and clean malformed-source rejection. A clean official-toolchain build produces a stripped static ARM helper at SHA-256 `4f6ac001a4a0455c20e1148cedf7548768258abfafb2299a3f8b171a5383fa8e` and stripped patched Main at SHA-256 `7f6ef2d299e9619250f300764836c8bf30409f7f452cd34248effda6e6536a39`.

#### Next Steps:

Install the exact `55d06ce` helper and patched Main through staged, hash-verified replacement while retaining the existing pre-ARM Main backup and accepted RBF. Do not mount or inspect the connected DVD. After reboot, resume the same one-file `01_arm_mp2_audio.mpg` hardware test and require the no-Loading selection path, correct video, distinct left and right embedded tones, normal LEDs, clean exit and reset replay. DVD mounting, VIDEO_TS and IFO navigation, VOB program-chain assembly, CSS handling, chapters, menus, AC-3, LPCM, subpictures and interlace remain explicitly deferred until embedded file audio is accepted.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 400 COMMIT Unreleased c9e5aff 2026-08-23T23:11:34-07:00

#### Coming From:

Unreleased c9e5aff

#### Purpose:

Install the first ARM embedded-audio candidate while preserving an exact rollback path and the accepted FPGA image.

#### Outcome:

The running MiSTer Main at SHA-256 `7ca3cd2f224b9264d0889f593a0d77aafa5adda61910baba92c5ae401e26fcce` was copied unchanged to `/media/fat/MiSTer.backup.pre-arm-c9e5aff.7ca3cd2f` before replacement. The cross-compiled Main from official source `0a8fb44` plus the `c9e5aff` loader patch was installed as `/media/fat/MiSTer` and independently verifies at SHA-256 `51b4e122e6bb3f1f7c62bcfb176d32528b5d08f48b04682d74e59e53fef8c900`. The stripped static helper was installed executable as `/media/fat/linux/MediaPlayer_Helper` and verifies at SHA-256 `0d259064658af419ae92a838a69cc9100a33684e2b7ff132471dd9e6d46a2a7f`. The sole test file `/media/fat/games/MediaPlayer/01_arm_mp2_audio.mpg` verifies at SHA-256 `94a8ff0223dd1acba4d59fc1785741522c4361956f17848bf9ebbb8c0a503fe7`. All transfers were staged under temporary names, verified before replacement, installed, synchronized and verified again. `/media/fat/MediaPlayer.rbf` remains byte-identical to the accepted first-PCM image at SHA-256 `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`. The old Main process remains in memory until reboot, so no unrequested launch or hardware test occurred during installation.

#### Next Steps:

Reboot the MiSTer once so the patched Main starts, enter MediaPlayer and run only `01_arm_mp2_audio.mpg`. Confirm that MPG is visible, selection returns immediately without the Loading screen, the five-picture video completes normally, the 440 Hz left and 660 Hz right embedded tones are audible in their correct channels, and report USER, DISK and POWER LED states. Then reset and replay that same file once to exercise helper termination and re-arm without expanding the one-video build cycle; leave the final image loaded for capture. If the file is absent from the selector after reboot, inspect Main's runtime core-name match and extension override before changing the RBF.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
