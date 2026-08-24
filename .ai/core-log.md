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
## 399 COMMIT Unreleased c9e5aff 2026-08-23T22:49:33-07:00

#### Coming From:

Unreleased a57079f

#### Purpose:

Implement the first ARM-side embedded-audio loader for MPEG Program Streams while retaining the accepted FPGA video, timestamp and MiSTer ALSA paths unchanged.

#### Outcome:

Commit `c9e5aff` implements the first ARM-side media pipeline without changing FPGA source or the accepted RBF. The helper incrementally parses MPEG-1 or MPEG-2 Program Stream and PES framing, selects the first H.262 and MPEG audio streams, emits H.262 through the existing file channel with the established in-band PTS record, decodes 48 kHz Layer II with pinned CC0 `minimp3`, and writes signed 16-bit stereo PCM through installed `aplay`; raw M2V input remains a byte-identical compatibility path. Dependencies are fetched at a pinned commit with exact SHA-256 checks instead of being vendored. The patch against official Main_MiSTer `0a8fb44` exposes M2V and MPG files only for the MediaPlayer core, starts the helper asynchronously, polls its nonblocking video pipe through Main as the sole FPGA SPI owner, terminates an old helper on replacement or reset, and removes the blocking Loading screen for both supported extensions. The deterministic generator produces the sole short H.262 plus stereo Layer II Program Stream for this cycle. Native and address-and-undefined-sanitized verification find byte-identical video after removing one PTS record, all 10,368 expected stereo PCM frames with 0.974933 correlation to FFmpeg's independent synthesis, byte-identical raw-M2V pass-through and clean rejection of a PES truncated through its first audio packet. The helper cross-compiles as a stripped static ARM EABI5 binary and patched Main cross-compiles as the expected stripped dynamic ARM EABI5 binary with the official MiSTer GCC 10.2 toolchain; the build script also reproduces a clean clone, patch application and both outputs.

#### Next Steps:

Back up and hash the installed MiSTer executable, then install the exact `c9e5aff` helper and patched Main together with `01_arm_mp2_audio.mpg`, retaining the accepted RBF unchanged. Restart Main safely and use only that one Program Stream for hardware validation, requiring immediate return from file selection without the Loading screen, normal five-picture video completion, the distinct 440 Hz left and 660 Hz right embedded tones through MiSTer ALSA, clean helper exit, zero decoder and presentation errors and a successful reset followed by replay of the same file. Leave the full video regression set deferred to release qualification. If initial A/V alignment is observably wrong, preserve this demux and decode boundary and make PTS-governed start alignment the next focused source cycle rather than changing the FPGA buffer.

#### Files Modified:

- .gitattributes
- .gitignore
- host/arm/Makefile
- host/arm/media_player_helper.c
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/generate_arm_av_test.py
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 398 COMMIT Unreleased a57079f 2026-08-23T22:30:17-07:00

#### Coming From:

Unreleased a57079f

#### Purpose:

Close focused MiSTer qualification of the codec-independent PCM output milestone under the one-video-per-build policy.

#### Outcome:

The user confirms that Audio Test Off is silent, all four 44.1 and 48 kHz mono and stereo proof modes sound correct, mode changes and core reset re-arm correctly, and the 48 kHz stereo tones continue while the sole authorized video control plays. `04_b_bidirectional.m2v` looks unchanged and finishes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven capture accepts the exact 185,150 transport bytes including the odd-byte pad, finds zero timestamp associations, decodes three reference plus two B pictures, displays all five pictures with four swaps, and ends with sequence end, session quiet and presentation complete true. Decoder and presentation errors are zero, frame waiting and both holds are false, and no decode, reorder, queued generation, promotion, scratch, future-reference, pending-frame or terminal-boundary work remains. One 0.051002-second decode-limited interval is flagged as a cadence outlier while scratch is unavailable, 0.001264 seconds longer than the two 0.049738-second ranked intervals; it drops no picture, leaves no state and produces no visible change by the user's direct observation. This accepts source `a57079f` and RBF SHA-256 `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37` as the first hardware-passed codec-independent PCM boundary, with exactly one video file used in the build cycle.

#### Next Steps:

Preserve the accepted signed 16-bit 44.1 and 48 kHz PCM valid-ready contract, dual-clock FIFO, MiSTer output adapter and timing-closed restart mailboxes as the Audio integration boundary. Before implementing compressed audio, choose the first codec and application profile, activate its authoritative standards references in `core-reference.md`, and define one materially useful decode-to-PCM hardware target; continue using one focused video file per development build and reserve the full regression suite for release qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 397 COMMIT Unreleased a57079f 2026-08-23T22:23:18-07:00

#### Coming From:

Unreleased a57079f

#### Purpose:

Install and independently verify the exact first-PCM hardware candidate before its focused MiSTer test.

#### Outcome:

The 4,214,932-byte Entry-396 `MediaPlayer.rbf` is installed persistently as `/media/fat/MediaPlayer.rbf` on the connected MiSTer through the established non-interactive transfer. An independent FTP retrieval to `/tmp/MediaPlayer_a57079f_remote.rbf` is byte-identical to the local build and reproduces SHA-256 `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`. The running core remains unchanged until the user reboots, so no unrequested launch or test occurred. This is the sole hardware image for the cycle and no second build is planned.

#### Next Steps:

Reboot the MiSTer to load the installed candidate. In the core menu, confirm Audio Test Off is silent, then select 44.1k Mono, 44.1k Stereo, 48k Mono and 48k Stereo in turn; report whether every mode is audible, whether mono is centered in both channels, whether stereo has the lower 440 Hz tone on the left and higher 660 Hz tone on the right, and whether returning to Off becomes silent. After the Audio modes pass, reset once, run only `04_b_bidirectional.m2v`, report all three LEDs and leave the final image loaded for capture; no other video file is required in this build cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 396 COMMIT Unreleased a57079f 2026-08-23T22:22:07-07:00

#### Coming From:

Unreleased a57079f

#### Purpose:

Bind the first PCM milestone to its single timing-clean Quartus candidate and exact hardware image.

#### Outcome:

Source `a57079f` completes the single authorized seed-eleven Quartus 17.0.2 build in 13 minutes 16 seconds with zero errors and 146 warnings. It uses 36,009 ALMs, 52,657 registers, 3,236,819 memory bits, 410 RAM blocks, 65 DSP blocks and three PLLs, a delta of 343 ALMs, 455 registers, 8,716 memory bits, two RAM blocks and zero DSP blocks from the accepted timestamp build. Every timing category is positive with zero endpoint TNS: plus 0.175 ns HDMI setup, plus 0.658 ns host setup, plus 0.857 ns decoder setup, plus 7.520 ns video setup, plus 13.183 ns audio setup, plus 0.248 ns hold, plus 4.293 ns global recovery, plus 10.425 ns decoder recovery, plus 37.782 ns audio recovery, plus 0.597 ns removal and plus 1.122 ns minimum pulse width. The dedicated Phase-1P reports find zero violations across 100 same-clock decoder paths, 80 same-clock video paths and 30 decoder recovery paths. This confirms that the timing-closed Audio control mailboxes avoid the recovery and cross-clock setup failures previously found in the companion implementation. The resulting 4,214,932-byte `MediaPlayer.rbf` has SHA-256 `ad04f9f73c0fb98309588f8c212c6ccad71c80b254a2a284f637672a73350d37`.

#### Next Steps:

Install the exact RBF persistently on the MiSTer and retrieve it byte-identically before testing. Verify Audio Test Off is silent, each 44.1 and 48 kHz mono mode is centered and duplicated to both channels, each stereo mode carries the 440 Hz left and 660 Hz right proof tones, mode changes and reset re-arm cleanly, and use only `04_b_bidirectional.m2v` as the one video regression for this build cycle with the normal LED and telemetry gate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 395 COMMIT Unreleased a57079f 2026-08-23T22:02:41-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Integrate the first codec-independent signed PCM output milestone without changing the accepted video or timestamp paths.

#### Outcome:

Commit `a57079f` adds a deterministic signed 16-bit PCM valid-ready source, mono and stereo modes at 44.1 and 48 kHz, a 256-sample dual-clock FIFO, and a MiSTer output adapter clocked by the existing 24.576 MHz audio domain. The OSD exposes four proof-tone modes while Off is silent. Atomic mode-change tokens cross from the HPS control clock to the source and output clocks through dedicated asynchronous mailboxes, while the data FIFO alone receives a synchronized asynchronous clear and all ordinary Audio state resets locally; the restart duration is extended beyond the FIFO-clear window and video file-session reset remains independent. This reuses the companion Audio repository's hardware-proven PCM modules and its later timing-closed control-transfer structure, adapted onto accepted source `9a7a982` without changing the audio-derived presentation clock, H.262 decoder, Program Stream ingress, framebuffer or diagnostics. The deterministic verifier passes all four pinned 8,192-sample hashes under continuous, periodic, bursty and pseudorandom-like readiness, exact reset re-arm, exact 48 kHz division and the bounded 557-or-558-clock 44.1 kHz schedule; both synthesizable arithmetic modules are warning-free under focused Verilator lint. This boundary establishes only a codec-independent PCM sink and proof source and makes no compressed-audio standards claim. Per the user's updated validation policy, each development build uses exactly one focused video file, while the full regression set is reserved for release qualification.

#### Next Steps:

Build source `a57079f` once with Quartus and run the complete Phase-1P timing review, requiring nonnegative global, decoder, host, video, hold, recovery, removal and pulse-width results with zero endpoint TNS. If the build is clean, install and retrieve the exact RBF, then hardware-test Off plus all four proof-tone modes, mode changes and reset while using only `04_b_bidirectional.m2v` as the single video non-regression file for this build cycle.

#### Files Modified:

- MediaPlayer_top_00.svh
- files.qip
- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- rtl/audio/audio_pcm_test_source.sv
- tools/streams/verify_d2_pcm_path.py

#### Status:

- [ ] Built
- [ ] Passed

---
## 394 COMMIT Unreleased 9a7a982 2026-08-23T21:58:43-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Close hardware qualification of timestamp presentation with the unannotated reordered-B fallback control.

#### Outcome:

After a reboot, unannotated `04_b_bidirectional.m2v` passes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven snapshot accepts the exact 185,150 transport bytes including the odd-byte pad, finds zero timestamp associations and zero displayed timestamp bits, decodes three reference plus two B pictures, and displays all five pictures with four swaps. Its ranked intervals include two exact 0.049738-second free-running gaps and the expected 0.046910-second decode-limited B interval with zero cadence outliers. Sequence end, session quiet and presentation complete are true; decoder and presentation errors are zero; frame waiting and both holds are false; and the terminal scheduler has no active reorder, decode, queued generation, promotion, pending scratch or reference frame, or terminal boundary. Together with the accepted irregular ordinary and reordered-B timestamp controls and the unannotated P fallback control, this proves source `9a7a982` and the exact Entry-389 RBF preserve raw elementary-stream playback while presenting annotated pictures by their associated timestamps. The timestamp feature is hardware-passed.

#### Next Steps:

Treat source `9a7a982` and its installed RBF as the accepted timestamp-presentation boundary. Begin PCM audio as a separate controlled feature cycle, preserving the accepted elementary-stream and timestamp regression gates and proposing its exact ingress, buffering, clocking and output scope before changing source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 393 COMMIT Unreleased 9a7a982 2026-08-23T21:56:19-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Hardware-qualify free-running cadence fallback on the unannotated P-picture range control after timestamp presentation was added.

#### Outcome:

After a reboot, unannotated `06_p_f_code_range.m2v` passes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven snapshot accepts the exact 184,678 transport bytes including the odd-byte pad, finds zero timestamp associations and zero displayed timestamp bits, decodes and displays all five reference pictures with four swaps, and finishes on the expected final P picture with temporal reference four. Sequence end, session quiet and presentation complete are true; decoder and presentation errors are zero; frame waiting and both holds are false; and no decode, reorder, queued, promotion, pending-frame or terminal-boundary work remains. All three ranked gaps are ordinary frame-rate-code-three fallback intervals at 0.049738, 0.049738 and 0.033158 seconds, the delivered rate is 25.076 fps and the outlier count is zero. This proves that adding timestamp-driven presentation did not disturb unannotated P-picture cadence or terminal retirement on source `9a7a982` and the exact Entry-389 RBF.

#### Next Steps:

Reboot and run unannotated `04_b_bidirectional.m2v`, report all three LEDs and leave the final image loaded for capture. Require zero timestamp associations, three reference plus two B pictures displayed with four swaps at normal free-running cadence, sequence-end quiet, presentation complete, zero errors and complete reorder-scheduler retirement; if it passes, mark source `9a7a982` hardware-passed and begin the PCM feature cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 392 COMMIT Unreleased 9a7a982 2026-08-23T21:51:18-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Hardware-qualify timestamp association and presentation across reordered B-picture scratch and reference ownership.

#### Outcome:

After a reboot, `16A_pts_reordered_b_short.m2v` passes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven snapshot accepts the exact 185,149 decoder bytes after stripping five metadata records, associates all five timestamps, decodes three reference and two B pictures, and displays all five pictures with four swaps. Sequence end, session quiet and presentation complete are true; decoder and presentation error flags are zero; frame waiting and both holds are false; and the terminal scheduler has no reorder, run-closed, decode-inflight, scratch, future-reference, queued, promotion, pending-frame or terminal-boundary work remaining. The final decoded picture is B type with temporal reference three while displayed PTS low bits are `0x110`, the final display-order future reference's timestamp, proving that presentation timestamps follow physical-bank ownership and display order rather than decode completion order. The irregular gaps include 0.040088 and 0.016579 seconds through B-picture reordering followed by the expected 0.215530-second wait for the final future reference. This closes the reordered-B timestamp gate on source `9a7a982` and the exact Entry-389 RBF without a source change.

#### Next Steps:

Reboot and run unannotated `06_p_f_code_range.m2v`, report all three LEDs and leave the final image loaded for capture, then repeat after another reboot with unannotated `04_b_bidirectional.m2v`. Require both files to preserve their accepted free-running fallback cadence and terminal state without in-band timestamp records; if both pass, mark source `9a7a982` hardware-passed and begin the PCM feature cycle.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 391 COMMIT Unreleased 9a7a982 2026-08-23T21:47:50-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Hardware-qualify complete irregular timestamp presentation on the corrected ordinary I/P control.

#### Outcome:

After a reboot, `15A_pts_irregular_ordinary_short.m2v` passes with USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven snapshot accepts the exact 184,677 decoder bytes after stripping five metadata records, associates all five timestamps, decodes and displays all five reference pictures with four swaps, and ends for quiet reason one with sequence end, session quiet and presentation complete true. Decoder and presentation error flags are zero, frame waiting and both holds are false, the pending scheduler slot is empty and no reorder, queued or promotion state remains. Displayed PTS low bits are the final record's expected `0x4fc`. The irregular schedule is proven by a 0.198950-second final interval and two 0.049738-second intervals rather than uniform 25-fps fallback cadence. This closes the ordinary timestamp gate on source `9a7a982` and the exact Entry-389 RBF without a source change.

#### Next Steps:

Reboot the MiSTer and run `16A_pts_reordered_b_short.m2v`, then report all three LEDs and leave the final image loaded for capture. Require all five coded-order timestamps to associate with their physical reference or scratch banks, three reference plus two B pictures to display in I, B, P, B, P order with four swaps and irregular timing, and sequence-end quiet with complete scheduler retirement and zero errors before proceeding to unannotated fallback controls.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 390 COMMIT Unreleased 9a7a982 2026-08-23T21:44:51-07:00

#### Coming From:

Unreleased 9a7a982

#### Purpose:

Interpret the first irregular-PTS hardware run and replace timestamp controls whose final deadlines exceeded the cadence profiler's forced terminal-snapshot window.

#### Outcome:

After a reboot into the exact Entry-389 RBF, the user runs `15_pts_irregular_ordinary.m2v`, reports visible skips and USER steady on, DISK steady off and POWER steady on. The launch-free schema-seven capture proves that all five in-band records associate and all five reference pictures decode with zero decoder or presentation errors; accepted decoder bytes are the original 184,677-byte elementary stream because the 45 metadata bytes are correctly stripped before that counter. Timestamp presentation is visibly active: the captured gaps include 0.248688 seconds followed by 0.049738 seconds, matching the intended uneven schedule rather than the 25-fps fallback. This first control does not qualify terminal presentation because its final PTS is one second after the anchor, beyond the profiler's approximately 0.825-second forced terminal deadline; the frozen snapshot therefore contains four displays, three swaps, displayed PTS low bits `0x4fc`, session quiet false and the fifth timestamped reference retained in the released pending slot without any error flag. Two replacement controls retain irregular and coded-order-reordered timestamps but move the final deadlines inside that diagnostic window. Exact FTP retrieval verifies 184,722-byte `15A_pts_irregular_ordinary_short.m2v` at SHA-256 `d2b5d8305dc628d200f5be2bd947f7054498a0cd9dd41a3e8ad51589df116ab8` and 185,194-byte `16A_pts_reordered_b_short.m2v` at SHA-256 `3a9c50be14cbaeb3aa39491fb0330c5c7a3ac3c2a1964e0f760b751a7fe9dd04`. No source or RBF change is made.

#### Next Steps:

Reboot the MiSTer and run `15A_pts_irregular_ordinary_short.m2v`; require five associated records, five decoded and displayed reference pictures, four swaps, sequence-end quiet, presentation complete, zero errors and visibly uneven timing, then leave the final image loaded for capture. If it passes, reboot and run `16A_pts_reordered_b_short.m2v`, requiring display-order I, B, P, B, P timing with three reference plus two B completions, five displays, four swaps, clean B-generation retirement and zero errors before the unannotated controls.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 389 COMMIT Unreleased 9a7a982 2026-08-23T21:08:18-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Present timestamped pictures against the proven audio-derived 90 kHz system-time tick while preserving the accepted free-running cadence for pictures without timestamps.

#### Outcome:

Commit `9a7a982` synchronizes only the proven single-bit audio-derived 90 kHz tick into the decoder domain and advances a local 33-bit timeline anchored exactly once by the first in-band timestamp after each download reset. Modulo half-range comparison holds future candidates, admits equality and late candidates at the first safe swap, and leaves individually missing timestamps on the unchanged exact 23.976, 24, 25, 29.97 or 30 fps cadence; an early timestamped presentation clears partial cadence credit so fallback cannot burst on the next refresh. Timestamp ownership now retains separate values and validity for all reference and B-scratch banks, commits B timestamps on actual persistence and queries the scheduler's retained candidate identity. Focused simulation passes first-record anchor, reset re-anchor, modulo wrap, late, future, missing, reference and reordered scratch ownership, timestamp gating, no-burst fallback and every established cadence count. Full-pipeline P-only, B-reordered, repeated multi-slice, dense-residual, mixed-macroblock and long-GOP replays complete with exact publication and persistence counts and zero errors; mixed and long dense-publication tests retain zero overwrites. The explicit coded-picture-order timestamp-list injector mode passes normal and oversize-rejection controls. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 34 seconds with zero errors and 154 warnings, using 35,666 ALMs, 52,202 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. Every timing category is positive with zero endpoint TNS: global setup is plus 0.200 ns, decoder setup plus 0.773 ns, host setup plus 1.158 ns, video setup plus 7.769 ns, hold plus 0.253 ns, recovery plus 2.709 ns, removal plus 0.633 ns and pulse width plus 1.122 ns. The 4,196,032-byte RBF has SHA-256 `68be8a9d899a06b6861a9d9ceaf07e41747d1865133940aad39849f4b14c9211`; it is installed persistently and retrieved byte-for-byte identical. Irregular ordinary test `15_pts_irregular_ordinary.m2v`, SHA-256 `0003a68e9377ce30ce77bfd8f4bd9e70edf2937b227021f4219efcd12027891b`, and reordered-B test `16_pts_reordered_b.m2v`, SHA-256 `bde3a06fb5012667a548fec6de1730e96a1c15c3c548cda85e0982af0bd7a309`, are also installed and retrieved exactly.

#### Next Steps:

Reboot the MiSTer so the new persistent RBF loads, then run `15_pts_irregular_ordinary.m2v` and verify that all five pictures appear in order with intentionally uneven pauses and clean terminal completion; record all three LEDs and leave the final image loaded for telemetry. After that capture, reboot and run `16_pts_reordered_b.m2v`, requiring the display-order I, B, P, B, P sequence to retain its deliberately uneven timing without a dropped or prematurely exposed future reference. Finish with reboot-isolated unannotated `06_p_f_code_range.m2v` and `04_b_bidirectional.m2v` controls to prove unchanged cadence fallback before marking this source passed. PCM output remains the next feature boundary.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_05.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/inject_inband_metadata.py
- tools/streams/tb_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_picture_timestamp.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 388 COMMIT Unreleased 2b1a170 2026-08-23T21:06:21-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Qualify deliberate mid-picture truncation and immediate no-reboot baseline recovery, completing the full hardware regression pack for the queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the exact 100,000-byte `99_EXPECTED_FAILURE_truncated_stream.m2v` stops visibly on frame seven with USER, DISK and POWER all steady off rather than claiming normal completion. Its launch-free schema-seven snapshot accepts all 100,000 bytes, decodes four reference plus five B pictures, displays eight pictures with seven swaps and freezes for reason three, `fatal_or_no_progress`, with sequence end false, session quiet false, presentation complete false, an unfinished future reference and decode still in flight. Decoder and presentation error flags remain zero, correctly distinguishing deliberate source truncation from a syntax fault. Without rebooting, the user immediately loads the exact odd-length `01_i_baseline.m2v`; it passes with USER steady on, DISK two blinks and POWER steady on. The recovery snapshot accepts 726,704 transport bytes including the expected pad, decodes and displays all four references with three swaps, freezes for quiet reason one and reports sequence end, session quiet, presentation complete, zero errors, no frame waiting and no reorder, queued, promotion, pending-frame or terminal-boundary state. The three long all-I gaps are decode-throughput observations only and no picture is lost. This proves that the truncated transfer leaves no stale state across a normal selector reload and completes the regression pack: tests one through fourteen, the expected failure and its no-reboot recovery all meet their specified hardware, visual and telemetry gates on source `2b1a170` and RBF SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`.

#### Next Steps:

Treat source `2b1a170` and its installed RBF as the accepted complete-regression boundary for ordinary and B-picture presentation. Prepare the next source-change proposal for timestamp-driven presentation against the proven system-time clock while retaining free-running cadence for unannotated streams, with focused association, wrap, missing-timestamp, seek-reset, B-reorder and full-pipeline controls; obtain user approval before changing source, and keep the PCM sink as the following feature boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 387 COMMIT Unreleased 2b1a170 2026-08-23T21:00:19-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the complete 14,315-picture native-24 endurance stream and prepare the final expected-failure recovery gate.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 78,010,162-byte `14_bbb_full_native24_user_recipe.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that the full playback looked good. The steady USER state again classifies the DISK indication as normal final GOP progress. The launch-free schema-seven capture freezes for quiet reason one with exactly 78,010,162 accepted bytes and the expected eight-bit wraps from 4,773 reference pictures, 9,542 B pictures, 14,315 displays and 14,314 swaps to 165, 70, 235 and 234. Frame-rate code two, 596 system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers are present. Correcting the 32-bit cadence-cycle counter by its eight expected wraps yields 596.428 measured seconds and 23.999549 displayed swaps per second. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact 100,000-byte `99_EXPECTED_FAILURE_truncated_stream.m2v`, SHA-256 `0375c1d73625fdeb80f995c194ba8220f25894aa093012a67f325d390aae536a`, was reproduced as the documented prefix of test eleven, installed in the MiSTer file directory and retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer and load `99_EXPECTED_FAILURE_truncated_stream.m2v` through the normal file selector. Wait until it stops making progress, record the terminal image and all three LEDs, leave it loaded and request telemetry capture; it must not report ordinary sequence-end quiet completion because the file ends inside a picture without a sequence-end marker. After that capture, do not reboot and immediately load `01_i_baseline.m2v`; recovery passes only if baseline completes normally with USER steady on, and all three recovery LEDs plus launch-free telemetry must be recorded before closing the regression pack.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 386 COMMIT Unreleased 2b1a170 2026-08-23T20:39:08-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify fifteen seconds of visually observed native-24 real-video stress across wrapped presentation counters and prepare the exact full endurance stream.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 2,603,570-byte `13_bbb_squirrel_15sec_native24_q6.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that playback looked good. The steady USER state again classifies the DISK indication as normal final GOP progress. The launch-free schema-seven capture freezes for quiet reason one with exactly 2,603,570 accepted bytes, 121 reference plus 239 B pictures, and the expected eight-bit wraps from 360 displays and 359 swaps to 104 and 103. Frame-rate code two, fifteen system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers are present; correcting the wrapped swap count gives 23.988 displayed swaps per second across the measured interval. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The pre-existing 84,423,309-byte full file on the MiSTer did not match test fourteen and its temporary numbered alias was removed. Regenerating from the local 480p source with the documented deterministic recipe plus the required terminal sequence-end marker produced the authoritative 78,010,162-byte `14_bbb_full_native24_user_recipe.m2v`, SHA-256 `3b048a180dbe2bc98a6160e7103b0f5acfd41d6875c34154730ef1da75d64f1a`; it was installed under the numbered name and retrieved byte-for-byte identical. Its 14,315 pictures comprise 597 I, 4,176 P and 9,542 B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `14_bbb_full_native24_user_recipe.m2v` through the normal file selector for the complete nine-minute-fifty-six-second endurance run. Watch smooth pans, the squirrel sequence, rolling credits and clean terminal behavior, then report all three LEDs and leave the completed image loaded for telemetry capture. Require 4,773 reference plus 9,542 B pictures, 14,315 displays and 14,314 swaps represented by eight-bit wraps to 165 references, 70 B pictures, 235 displays and 234 swaps, exactly 78,010,162 accepted bytes, sequence-end quiet, complete presentation retirement and zero errors before the expected-failure and no-reboot recovery test.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 385 COMMIT Unreleased 2b1a170 2026-08-23T20:36:08-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify five seconds of visually observed dense real-video motion with complete native-24 presentation telemetry on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 1,404,944-byte `12_bbb_squirrel_5sec_native24_q6.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on, and the user reports that playback looked good. The steady USER state classifies the DISK indication as the normal final GOP-progress code, which the launch-free schema-seven capture confirms: exactly 1,404,944 transport bytes are accepted, forty-one reference plus seventy-nine B pictures decode, and all 120 pictures display with 119 swaps. The snapshot freezes for quiet reason one with frame-rate code two, five system-time seconds, sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers at a measured 23.902 displayed swaps per second. The terminal scheduler has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 2,603,570-byte `13_bbb_squirrel_15sec_native24_q6.m2v`, SHA-256 `9257ffadc24eb6696fc9760f3253764b396c993dfc3640e921c97611bad2edce`, was retrieved from the MiSTer byte-exact; its 360 pictures comprise fifteen I, 106 P and 239 B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `13_bbb_squirrel_15sec_native24_q6.m2v` through the normal file selector, watch the complete fifteen-second squirrel and wooden-spike sequence for continuous motion without clean frame skips, then report all three LEDs and leave the completed image loaded for telemetry capture. Require 121 reference plus 239 B pictures, 360 displays and 359 swaps represented by the established eight-bit counter wraps to 104 and 103, exactly 2,603,570 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before deciding how to stage the full endurance test fourteen.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 384 COMMIT Unreleased 2b1a170 2026-08-23T20:33:01-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the seventy-two-picture long-GOP ownership, reordering and publication sequence on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative even-length 791,528-byte `11_compat_long_gop.m2v` passes with USER steady on, DISK eleven blinks and POWER steady on. Because USER remains steady, the DISK indication is the normal final GOP-progress code rather than an error sub-code, which the launch-free schema-seven capture confirms: exactly 791,528 transport bytes are accepted, twenty-five reference plus forty-seven B pictures decode, and all seventy-two pictures display with seventy-one swaps. The snapshot freezes for quiet reason one with sequence end, session quiet, presentation complete, zero decoder or presentation errors and zero cadence outliers at a measured 25.026 displayed swaps per second. Ranked telemetry observes the repeated scratch, pending-frame, reorder, queued-generation, promotion and presentation-hold states, while the terminal snapshot has no frame waiting, active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 1,404,944-byte `12_bbb_squirrel_5sec_native24_q6.m2v`, SHA-256 `dea6b42228158ec4fe43a3cacde71876a21b1fdf3ec9eb37c0c23bf72be2cc84`, was retrieved from the MiSTer byte-exact; its 120 pictures comprise five I, thirty-six P and seventy-nine B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `12_bbb_squirrel_5sec_native24_q6.m2v` through the normal file selector, watch the complete five-second dense-motion clip for continuity, then report all three LEDs and leave the completed image loaded for telemetry capture. Require forty-one reference plus seventy-nine B pictures, all 120 displays, 119 swaps, exactly 1,404,944 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before proceeding to the fifteen-second stress in test thirteen.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 383 COMMIT Unreleased 2b1a170 2026-08-23T20:29:33-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify mixed intra, predicted, skipped and residual macroblocks across repeated B-picture ownership sequences on the accepted queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 366,071-byte `10_compat_mixed_macroblocks.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 366,072 transport bytes including the expected pad, decoding nine reference plus fifteen B pictures and displaying all twenty-four pictures with twenty-three swaps. Sequence end, session quiet and presentation complete are true with zero decoder or presentation errors and zero cadence outliers at a measured 24.365 displayed swaps per second. Ranked telemetry observes scratch presentation, pending ordinary frames, active B reordering, queued generations, promotion and presentation hold during the repeated ownership sequence, while the terminal snapshot has no active reorder, queued generation, promotion, pending frame or terminal boundary. The exact even-length 791,528-byte `11_compat_long_gop.m2v`, SHA-256 `39dd3e889d1baa42e4d65fc2d6ca7a04c58c2ac38de0a5b1dba00e6585836d96`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its seventy-two pictures comprise three I, twenty-two P and forty-seven B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `11_compat_long_gop.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require twenty-five reference plus forty-seven B pictures, all seventy-two displays, seventy-one swaps, exactly 791,528 accepted transport bytes, sequence-end quiet, complete presentation retirement and zero errors before proceeding to the five-second squirrel stress in test twelve.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 382 COMMIT Unreleased 2b1a170 2026-08-23T20:27:02-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify complete decoding and presentation under the compatibility pack's maximum coefficient and residual traffic.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 2,875,985-byte `09_compat_dense_residual.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 2,875,986 transport bytes including the expected pad, decoding five reference plus seven B pictures and displaying all twelve pictures with eleven swaps. Sequence end, session quiet and presentation complete are all true with zero decoder or presentation errors, no frame waiting and no reorder, queued, promotion, pending-frame or terminal-boundary work remaining. The maximum-residual stress records seven cadence outliers and a 4.940 displayed-swap rate across the measured interval, with the largest decode-limited gaps at approximately 0.414, 0.370 and 0.298 seconds; these are retained as throughput evidence rather than presentation loss because every picture and swap completes exactly once and terminal ownership is clean. The exact odd-length 366,071-byte `10_compat_mixed_macroblocks.m2v`, SHA-256 `ad1d9e81f0f7544ac16a1aaddb85ef9e1065333c1fdd305aa3cf275aa1ccc289`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its twenty-four pictures comprise two I, seven P and fifteen B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `10_compat_mixed_macroblocks.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require nine reference plus fifteen B pictures, all twenty-four displays, twenty-three swaps, 366,072 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test eleven; record cadence outliers as throughput evidence without conflating them with the exact completion gate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 381 COMMIT Unreleased 2b1a170 2026-08-23T20:24:44-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify repeated multi-slice decoding and presentation on the accepted ordinary queue-capacity fix.

#### Outcome:

After a MiSTer power cycle, the authoritative odd-length 185,393-byte `08_compat_multi_slice.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one after accepting 185,394 transport bytes including the expected pad, decoding three reference plus two B pictures, displaying all five pictures with four swaps and reaching sequence end, session quiet and presentation complete with zero decoder or presentation errors and zero cadence outliers. Ranked telemetry observes the expected active reorder, scratch display, queued generation and promotion state before the terminal reference, while the final snapshot has no active reorder, queued generation, promotion, pending frame or terminal boundary. This preserves repeated-slice parsing, B ownership and complete presentation under the new ordinary-reference hold. The exact 2,875,985-byte `09_compat_dense_residual.m2v`, SHA-256 `f8e05f5cfd0c0385566bbc3e4133d9f42cb5547933d92e24b0d87eec3fa0a79e`, was installed in the MiSTer file directory and retrieved byte-for-byte identical; its twelve pictures comprise one I, four P and seven B pictures.

#### Next Steps:

Power-cycle the MiSTer and load `09_compat_dense_residual.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require five reference plus seven B pictures, all twelve displays, eleven swaps, 2,875,986 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test ten.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 380 COMMIT Unreleased 2b1a170 2026-08-23T20:21:34-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Confirm that the accepted ordinary queue-capacity fix preserves complete B-picture decoding, reordering and presentation across independent forward and backward motion-vector ranges.

#### Outcome:

After a MiSTer power cycle, the authoritative 185,054-byte `07_b_f_code_range.m2v` passes with USER steady on, DISK steady off and POWER steady on. Its launch-free schema-seven capture freezes for quiet reason one with all 185,054 bytes accepted, three reference plus two B pictures decoded, all five pictures displayed, four swaps, sequence end, session quiet, presentation complete, zero decoder and presentation errors and zero cadence outliers. Ranked telemetry observes the active B-reorder path with scratch presentation, queued generation, promotion and presentation hold before the terminal fifth display, then confirms all reorder, queued, promotion, pending-frame and terminal-boundary state retired in the final snapshot. Test seven therefore preserves the established B ownership contract under the new ordinary-reference backpressure and passes the full hardware gate. The next authoritative 185,393-byte `08_compat_multi_slice.m2v`, SHA-256 `bcd25c393f42aa1ccb8dc076a87ad14560357db4613093c93472d49d13ec3be8`, was generated locally, installed in the MiSTer file directory and retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer and load `08_compat_multi_slice.m2v` through the normal file selector, then report all three LEDs and leave the completed image loaded for telemetry capture. Require three reference plus two B pictures, all five displays, four swaps, 185,394 accepted transport bytes including the expected odd-byte pad, sequence-end quiet, complete presentation retirement and zero errors before proceeding to test nine.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 379 COMMIT Unreleased 2b1a170 2026-08-23T20:18:20-07:00

#### Coming From:

Unreleased 2b1a170

#### Purpose:

Hardware-qualify the ordinary presentation queue-capacity fix with two reboot-isolated executions of the stream that exposed the deterministic dropped display.

#### Outcome:

The exact installed 4,173,788-byte RBF for `2b1a170`, SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`, passes `06_p_f_code_range.m2v` twice after separate MiSTer power cycles. The user reports USER steady on, DISK steady off and POWER steady on for both runs. Both launch-free schema-seven captures freeze for quiet reason one with exactly 184,678 accepted transport bytes including the odd-byte pad, five reference pictures, five displayed pictures, four swaps, sequence end, session quiet, presentation complete, zero presentation errors, zero decoder error flags and zero cadence outliers. Both finish on reference bank one with no frame waiting, input or destination hold, pending scheduler work or active reorder state; their three ranked cadence gaps also agree at 2,984,256, 2,984,256 and 1,989,504 decoder cycles despite normal variation in decode and host-transfer stalls. This reverses the prior repeatable four-display and three-swap hardware failure and proves that the ordinary queue-capacity hold prevents publication overwrite without disturbing terminal retirement. Telemetry capture is now non-interactive by bypassing the stale local key-only SSH stanza with an isolated SSH configuration and retrieving the screenshot through the established automatic FTP connection. The exact 185,054-byte test-seven stream already on the MiSTer was independently retrieved at the authoritative SHA-256 `d0aad59a546114c7fe36680902c2bb912c7bcc2a43201ae9d0fd790d6f877725`.

#### Next Steps:

Continue the numeric hardware regression with `07_b_f_code_range.m2v`, which exercises independent forward and backward B-picture motion-vector ranges. Power-cycle before loading it through the normal file selector, record all three LEDs, leave the completed image loaded for launch-free telemetry, and require all five pictures to display with four swaps, sequence-end quiet, complete B-path retirement and zero errors before proceeding to test eight.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 378 COMMIT Unreleased 2b1a170 2026-08-23T19:55:34-07:00

#### Coming From:

Unreleased 292981f

#### Purpose:

Prevent rapid ordinary I/P publications from overwriting an undisplayed queued reference before its cadence slot.

#### Outcome:

The exact authoritative `06_p_f_code_range.m2v` exposed the same deterministic hardware failure after two isolated reboots: 184,678 accepted transport bytes, five reference pictures, zero decoder errors, sequence-end quiet and presentation complete, but only four displayed pictures and three swaps. Commit `2b1a170` prevents ordinary pending-slot overwrite by holding input after a released non-B reference differs from the current display; the initial same-bank reference remains exempt to avoid startup deadlock and the established B-reorder hold remains unchanged. The focused scheduler regression passes rapid three-bank publication and retirement at all five supported cadence rates. Full-pipeline replay of test six at the hardware-equivalent 994,752-cycle display interval now completes five publications, five displayed identities and four swaps with 184,677 file bytes and zero errors; the established ordinary-P, B-containing and repeated-multi-slice controls also pass, and the schema-seven cadence-profiler checksum remains `eb2b643d`. The seed-eleven Quartus 17.0.2 build completed in 11 minutes 50 seconds with zero errors and 154 warnings, using 34,673 ALMs, 51,930 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. Every timing category is positive with zero endpoint TNS: plus 0.293 ns HDMI setup, plus 0.713 ns host setup, plus 1.005 ns decoder setup, plus 8.399 ns video setup, plus 0.261 ns hold, plus 3.533 ns recovery, plus 0.605 ns removal and plus 1.122 ns pulse width. The 4,173,788-byte RBF has SHA-256 `b19010473eb8f414b85b9ae11d0b3f29abc26dae560c115a1da29754cd23f491`; it was installed persistently on the MiSTer and retrieved byte-for-byte identical through the automatic non-interactive connection.

#### Next Steps:

Power-cycle the MiSTer and run `06_p_f_code_range.m2v` twice, rebooting between runs and leaving each completed video loaded for telemetry capture. Require USER steady on, DISK steady off and POWER steady on together with a quiet schema-seven snapshot containing 184,678 accepted transport bytes including the odd-byte pad, five reference pictures, five displayed identities, four swaps, sequence end, session quiet, presentation complete and zero error flags. Do not proceed to test seven until both isolated runs pass.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/run_live_raster_soak_verilator.sh

#### Status:

- [x] Built
- [ ] Passed

---
## 377 COMMIT Unreleased 292981f 2026-08-23T19:32:29-07:00

#### Coming From:

Unreleased 292981f

#### Purpose:

Record isolated hardware acceptance of generic terminal completion across all-I, P-only and B-containing streams.

#### Outcome:

The exact 4,188,704-byte RBF for `292981f`, SHA-256 `1258735da72354789e0fddabc44ed0b06185c0e00919f1a23c40e983f3c69e31`, remained installed for three reboot-isolated normal-selector tests. `01_i_baseline.m2v` passed with USER steady on, DISK two blinks and POWER steady on; launch-free schema-seven telemetry froze for quiet reason one with sequence end, session quiet, presentation complete, zero errors, four reference pictures, four displayed pictures, three swaps and 726,704 accepted bytes including the expected odd-byte pad. `02_p_motion_residual.m2v` passed with USER steady on, DISK steady off and POWER steady on; its quiet snapshot reports sequence end, session quiet, presentation complete, zero errors, two reference pictures, two displayed pictures, one swap, 181,134 accepted bytes and final picture type P. `04_b_bidirectional.m2v` passed with USER steady on, DISK steady off and POWER steady on; its quiet snapshot reports sequence end, session quiet, presentation complete, zero errors, three reference plus two B pictures displayed, four swaps and 185,150 accepted bytes including the expected pad. Ranked-gap telemetry captured the B run with presentation completion false while reorder work remained, followed by a final gap with presentation completion true, reorder false and session quiet true, proving that the generic fix preserves B-path ownership and retirement behavior. The user rebooted between every file load. A dedicated local RSA key and non-interactive BatchMode SSH configuration were prepared outside the repository with password and keyboard-interactive authentication disabled; they were intentionally not tested after preparation because the user requested no further MiSTer contacts in this turn, so any failed future key-only connection will stop instead of prompting.

#### Next Steps:

Treat `292981f` and its installed RBF as the accepted generic terminal-telemetry boundary. On the next explicitly needed device contact, try only the prepared key-based connection and stop silently if it is unavailable. Resume timestamp-driven presentation against the proven system clock while retaining free-running cadence for unannotated streams, then implement the PCM sink as the subsequent feature boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 376 COMMIT Unreleased 292981f 2026-08-23T19:00:57-07:00

#### Coming From:

Unreleased 0f7edd5

#### Purpose:

Make terminal presentation completion generic so all-I and P-only streams reach the same quiet telemetry snapshot path as B-containing streams.

#### Outcome:

Commit `292981f` initializes the scheduler's presentation-complete state high while no B-reordering run exists, clears it on the first B header, and retains the established restoration only after scratch pictures and the future reference retire. This fixes all-I and P-only quiet telemetry without weakening the top-level drain predicate or changing B ownership and cadence behavior. The focused scheduler test explicitly proves I-only and P-only completion, B-header revocation, B-run restoration and all five supported cadence rates; the schema-seven cadence-profiler test retains quiet, forced, fatal and no-progress capture with checksum `eb2b643d`. Full-pipeline generic P, B and repeated-multi-slice replays retain exact row, picture, publication and presentation counts with zero errors; the all-I replay reaches four pictures, four publications, three swaps and generic presentation complete with zero errors, but its reusable generic bench remains inapplicable because that bench unconditionally requires prediction reads and reconstruction for every stream. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 25 seconds with zero errors and 155 warnings. Every timing category is positive with zero endpoint TNS: plus 0.330 ns HDMI setup, plus 1.029 ns decoder setup, plus 1.246 ns host setup, plus 7.960 ns video setup, plus 0.252 ns hold, plus 4.145 ns recovery, plus 0.610 ns removal and plus 1.122 ns pulse width. It uses 34,549 ALMs, 51,860 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks. The 4,188,704-byte RBF has SHA-256 `1258735da72354789e0fddabc44ed0b06185c0e00919f1a23c40e983f3c69e31` and was installed persistently on the MiSTer, then retrieved byte-for-byte identical.

#### Next Steps:

Power-cycle the MiSTer, run `01_i_baseline`, `02_p_motion_residual` and `04_b_bidirectional` through the normal file selector, and record USER, DISK and POWER for every stream. Leave each completed video open long enough to read launch-free telemetry, requiring quiet snapshot reason one, sequence end, session quiet, presentation complete and zero error flags; the B stream must also retain its established complete presentation state. Do not accept the source commit until those hardware results pass.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 375 COMMIT Unreleased 0f7edd5 2026-08-23T18:47:02-07:00

#### Coming From:

Unreleased dea60bc

#### Purpose:

Make the hardware regression pack self-contained, checksum-verifiable and explicit about the three-LED acceptance evidence required for every stream.

#### Outcome:

Commit `0f7edd5` places the complete regression instructions, three-LED results template, fifteen stream checksums and canonical compatibility manifest under `docs/`, identifies the currently accepted `dea60bc` RBF exactly, requires USER, DISK and POWER readings for every normal and recovery run, and records the exact generation commands for the squirrel stresses and full-movie recipe. The new verifier accepts only the exact fifteen-file stream set, checks every payload digest, validates the canonical manifest hash, portable paths, four-case structure and per-case stream identities, accepts the original release-candidate manifest only by its exact known legacy digest, and rejects an incomplete pack. Regeneration proved tests `01` through `11` byte-identical to their recorded hashes; the five-second start-440, fifteen-second start-435 and no-frame-counter full-movie recipes reproduce their three hashes; and the first 100,000 bytes of test `11` reproduce test `99`. The compatibility generator now records repository-relative paths, constrains FFmpeg debug decoding to one thread, and retries until its macroblock inventory accounts for every expected 45-by-30 picture row, which removes the discovered manifest-only nondeterminism; two complete runs produced the same canonical manifest SHA-256 `ae0d767f9ee6e95cd68d4224b40ce4d45a246df435707a6f9afa8cb09b75c822`. Both Python files compile cleanly, whitespace checks pass and no Quartus build or new RBF is required because compiled FPGA source is unchanged. The launch-free telemetry fault remains separately scoped: the top-level quiet gate incorrectly requires B-path completion for all-I and P-only streams.

#### Next Steps:

Open a separate generic terminal-quiet telemetry cycle that derives presentation completion from the active stream path rather than requiring B-path completion unconditionally. Cover all-I, P-only and B-containing terminal cases in focused simulation, build a timing-clean RBF, install it byte-verifiably, and confirm on hardware that launch-free telemetry freezes for quiet completion while the accepted USER, DISK and POWER behavior remains unchanged.

#### Files Modified:

- docs/TEST_INSTRUCTIONS.md
- docs/RESULTS_TEMPLATE.txt
- docs/SHA256SUMS
- docs/compatibility_manifest.json
- tools/streams/generate_test_progressive_compatibility.py
- tools/streams/verify_regression_pack.py

#### Status:

- [x] Built
- [ ] Passed

---
