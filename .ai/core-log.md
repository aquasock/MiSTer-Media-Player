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
## 374 COMMIT Unreleased dea60bc 2026-08-23T18:40:19-07:00

#### Coming From:

Unreleased dea60bc

#### Purpose:

Hardware-qualify the repaired in-band metadata boundary and displayed-frame timestamp association with explicit LED and launch-free telemetry evidence.

#### Outcome:

The exact 4,209,348-byte RBF for `dea60bc`, SHA-256 `6d86641ca5c9460c9025961ccff0403438f7034949f3046b8ee2c0592fde9afc`, was uploaded persistently and retrieved byte-for-byte identical. After a power cycle, plain `04_b_bidirectional` passed twice with USER steady on, POWER steady on and DISK steady off, reversing the reproducible USER one blink and DISK fifteen syntax failure on `27ad1b3` and proving the pulse-valid repair on the P-ownership hold that exposed it. After another power cycle, the unannotated 726,703-byte `01_i_baseline` passed with USER steady on, POWER steady on and DISK two blinks; schema-seven telemetry reports four displayed pictures, zero associations, zero displayed timestamp, zero error flags and sequence end. The deterministic 726,739-byte annotated companion was found already installed, reproduced byte-identically from the committed injector, and duplicated under the visible name `01A_ANNOTATED_4PTS.m2v`; after another power cycle it passed with the same successful LED state, four associations, displayed timestamp low bits `0x223`, four displayed pictures, zero error flags and sequence end. This proves records cross the ordinary file path, survive the repaired backpressure boundary, are stripped without changing decoded bytes, bind to all four pictures and follow frame ownership to the displayed frame. Both launch-free snapshots froze on the profiler's forced terminal timeout before `session_quiet` and `presentation_complete` became true, while the later LED acceptance snapshot was successful, so those frozen fields remain a profiler timing limitation rather than a decoder failure. The proposed `quartus_sh --write_settings_files=off` edit from Entry 372 must not be made as written: Quartus 17 rejects that shell option, and the normal flow output proves its map, fit and assembler children already run with settings writes disabled.

#### Next Steps:

Treat `dea60bc` and the installed RBF as the accepted timestamp-association boundary. The next repository-only cycle should place the regression instructions, result template, checksums and compatibility manifest under `docs/`, require USER, POWER and DISK observations for every hardware stream, regenerate the pack from committed generators, and correct the launch-free snapshot trigger so terminal fields are captured after quiet rather than by forced timeout. After that reproducibility boundary is accepted, resume timestamp-driven presentation against the proven system clock while retaining free-running cadence for unannotated streams.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 373 COMMIT Unreleased dea60bc 2026-08-23T18:08:10-07:00

#### Coming From:

Unreleased 3ae9885

#### Purpose:

Restore the decoder's pulse-valid ingress contract across the in-band metadata extractor after hardware bisection identifies repeated-byte parsing during a P-picture ownership hold.

#### Outcome:

The user reports USER one blink, DISK fifteen blinks and POWER steady on for plain `04_b_bidirectional` on the installed `27ad1b3` image. The LED hierarchy identifies the first failure as frontend syntax error source fifteen, while POWER zero is the expected absence of a nested source for a syntax error. Because `27ad1b3` differs from the earlier accepted image at the compressed-data boundary only by `mpeg2_h262_inband_metadata`, this completes the bisection. Static tracing finds the specific contract mismatch: the extractor retained `stream_valid` as a level while `mpeg2_new_stream_ready` was false, but the established frontend and parser advance on every cycle of `stream_valid`, so the ownership hold replayed one byte into syntax parsing. A focused regression using the real transport convention in which input valid is derived from readiness reproduces six accepted bytes as eight visible byte cycles on the pre-fix RTL. Commit `dea60bc` retains the pending byte internally while presenting output valid only on the actual decoder transfer; the regression then reports exactly six visible cycles. The extractor unit test, timestamp association test, transport-gate test and schema-seven cadence-profiler test all pass, and a 550,316-byte elementary-stream replay with five inserted records emits the source byte-identically with all five timestamps extracted. The seed-eleven Quartus 17.0.2 build completes in 12 minutes 46 seconds with zero errors, 154 warnings and every timing category positive: plus 0.372 ns HDMI setup, plus 0.840 ns decoder setup, plus 0.928 ns host setup, plus 8.766 ns video setup, plus 0.251 ns hold, plus 4.400 ns recovery, plus 0.493 ns removal and plus 1.122 ns pulse width. It uses 34,968 ALMs, 51,912 registers, 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks; the 4,209,348-byte RBF has SHA-256 `6d86641ca5c9460c9025961ccff0403438f7034949f3046b8ee2c0592fde9afc`.

#### Next Steps:

Install only the exact RBF identified above. Hardware validation must begin with plain `04_b_bidirectional`, requiring USER steady on rather than the syntax error now measured, and must then exercise the unannotated control and annotated timestamp stream. Add explicit USER, POWER and DISK readings to the repository regression instructions as a subsequent tooling and documentation boundary so plausible still images can no longer count as a pass without LED evidence.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/tb_h262_inband_metadata.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 372 COMMIT Unreleased 3ae9885 2026-08-23T17:44:42-07:00

#### Coming From:

Unreleased 2d555f7

#### Purpose:

Carry in-band timestamps through frame ownership to the displayed frame, and record the regression and procedural gaps that validating it exposed.

#### Outcome:

`09765db` added `mpeg2_h262_picture_timestamp`, which captures a timestamp at the picture start following its record, holds it while that picture decodes and commits it to the frame bank the picture lands in, so reading by `display_frame_bank` yields the timestamp of the displayed frame despite decode reordering; completion is detected as a toggle of `active_frame_bank`, which the bookkeeper inverts only on persistence. `0a6baf3` then corrected a real defect: the module had been bound to the frontend's `picture_seen`, which is a sticky level set at the first picture and cleared only by reset rather than a per-picture pulse, so the pending timestamp was cleared in the same cycle it arrived and nothing was ever associated. Simulation passed that broken design because the test drove `picture_seen` as a pulse, testing the assumption rather than the signal; binding moved to `mpeg2_new_picture_header_classified_now`, a genuine one-cycle header pulse, with explicit handling for a record completing in the same cycle as its picture start. `3ae9885` added `read_hardware_cadence.py`, which triggers a screenshot and decodes it without launching anything, because `run_hardware_cadence.py` drives MGL and the command FIFO and its captures have repeatedly disagreed with normal operation. Telemetry moved to schema seven, word thirty-five reporting the associated count and the displayed frame's low timestamp bits, checksum `eb2b643d`. The build closed at plus 0.256 ns HDMI and plus 0.753 ns decoder. Hardware validation then produced three findings that matter more than the feature. First, device state silently invalidated an hour of measurement: the archived `c9bc2ef8` image, bit-identical to one validated earlier the same day, began failing streams it had previously passed, and a power cycle restored it completely; every result taken in that window, including a syntax error and a `fatal_or_no_progress` snapshot on the annotated stream, measured nothing about the design. Second, with a rebooted machine and two repetitions, plain `04_b_bidirectional` fails on `0a6baf3` reporting syntax error source fifteen and passes on `c9bc2ef8`, so a genuine regression exists in this development run and is not caused by annotation: the injector places records at all five true picture starts, the RTL file replay reproduces the source byte for byte, and the stream's I picture carries conformant `FFFF` f_codes, so source fifteen indicates a misparse rather than a bad file. Third, this defect has been invisible because every prior validation was visual and no cycle in this log has ever read the diagnostic LEDs; `04` is five pictures, so a fault after the first still presents a plausible still image. The LED encoding, read from RTL rather than assumed, is that `LED_USER` steady on means no error latched and the stream accepted, N blinks means error flag N with one being syntax, and `LED_DISK` reports the error sub-code when USER blinks but the final GOP progress stage when USER is steady, so the disk indication cannot be interpreted without the user indication. Bisection is under way: `7c29f33` cannot serve as a midpoint because it misses timing at minus 0.202 ns and a violation could itself corrupt parsing, so `27ad1b3` was rebuilt, reproduced byte-identically at `6e075113...`, and is installed to determine whether the ingress extractor or the later timestamp work introduced the fault.

#### Next Steps:

Read the LEDs for plain `04_b_bidirectional` on the installed `27ad1b3` image. A failure implicates the in-band extractor, which is the only change between that image and the archived one touching the data path, and which inserted a three-byte pipeline between the FIFO and the decoder where `mpeg2_new_stream_ready` carries a P-ownership hold written when FIFO position and decoder position were the same instant. A pass implicates the timestamp module of `09765db` and `0a6baf3`, which is supposed to be observational and would therefore not be. Whichever it is, reproduce it in simulation before repairing it, driving the real handshake in which valid is derived from ready and the ownership hold stalls mid-stream, because both defects found in this cycle were hidden by tests that modelled assumptions about signals rather than the signals themselves. Add the LED reading to the regression procedure as a required per-stream observation with the encoding recorded, since the procedure already names the USER LED as the positive completion diagnostic and never said to look at it. Move `TEST_INSTRUCTIONS.md`, `RESULTS_TEMPLATE.txt`, `SHA256SUMS` and `compatibility_manifest.json` into `docs/`, because the regression procedure currently exists only in an untracked Desktop directory and a fresh clone cannot reproduce the validation inputs, which is the third instance this session of the workflow depending on something outside the repository. Regenerate the regression streams from the committed generators in `tools/streams/` and compare them against the pack's `SHA256SUMS` to confirm the pack is reproducible. Add `--write_settings_files=off` to the compile command in `tools/build.sh`, because a crashed flow wrote 298 lines of generated pin assignments into the tracked `MediaPlayer.qsf`.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_picture_timestamp.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/read_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_picture_timestamp.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 371 COMMIT Unreleased 2d555f7 2026-08-23T16:00:17-07:00

#### Coming From:

Unreleased 3f279dd

#### Purpose:

Supply the harness that injects in-band metadata records and prove the extraction path end to end on hardware.

#### Outcome:

The restored `3f279dd` netlist rebuilt to RBF SHA-256 `6e075113416bf8bb891d2b00ee96a9748441bb42ce2a10dec81ef93b37a8fb13`, byte-identical to `27ad1b3`, with 35,055 ALMs, 51,819 registers, plus 0.138 ns HDMI setup and plus 0.933 ns decoder setup, confirming both that the revert restored ASCAL exactly and that determinism continues to hold. The user validated that image and every stream passed, accepting the metadata extractor as harmless to plain elementary streams, which was the property at risk because the four-byte detection window holds the `sequence_end_code` at end of transfer and a broken flush would have truncated every stream. This commit adds tools only and required no rebuild. `inject_inband_metadata.py` annotates an elementary stream by inserting a nine-byte record before each picture start, refusing outright to process a file that already contains `0x000001B0` so a stream cannot be annotated twice, and `tb_h262_inband_metadata_file.sv` replays an annotated stream and its unannotated source through the extractor, requiring the emitted bytes to equal the source exactly, with stream paths and lengths passed as plusargs so any file can be used. Annotating the four-picture `01_i_baseline` produced exactly four records and a file thirty-six bytes larger, and an independently written stripper reduced it to a byte-identical copy of the original. The file replay then drove all 726,739 annotated bytes through the RTL with backpressure applied every 977 bytes and reproduced all 726,703 source bytes exactly, extracting four records with a final timestamp of `0x7A223`. That predicted the hardware result before it was measured, which it matched exactly: the annotated stream reports four records and low timestamp bits `0x223` with zero error flags, while the unannotated control over the same core and the same picture content reports zero records and zero timestamp. Metadata therefore travels from a file, over the ordinary `ioctl_download` path, through the sliding-window detector, is stripped ahead of the decoder and unpacked with its timestamp intact, with no side channel, no daemon, no `Main_MiSTer` change and no kernel work. Two harness limitations were observed and are not defects in the core: `run_hardware_cadence.py` reports picture and byte counts that do not match the stream it was given, the same discrepancy the archived seed ten image reproduces, and its snapshots were taken before terminal quiet so `sequence_end_seen` reads false.

#### Next Steps:

Carry the extracted timestamp into frame ownership and present on it against the system time clock, anchoring from the first record in a stream and retaining free-running cadence for streams that carry none, which is the change that genuinely risks presentation regressions and now has both a proven clock and a proven metadata path beneath it. Extend the injector to derive timestamps from a real cadence rather than a fixed step once presentation consumes them, so the injected values describe the stream instead of merely exercising the path. The PCM sink follows with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Continue checking the weakest margin across all clocks after each addition, reseeding rather than restructuring when the HDMI domain is the category that fails. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery, and delete the six compiled but uninstantiated modules for navigability.

#### Files Modified:

- tools/streams/inject_inband_metadata.py
- tools/streams/tb_h262_inband_metadata_file.sv

#### Status:

- [x] Built
- [x] Passed

---
## 370 COMMIT Unreleased 3f279dd 2026-08-23T15:32:17-07:00

#### Coming From:

Unreleased 19022d9

#### Purpose:

Restore the sequential ASCAL divide tail after speculation proved a net loss, and record that the HDMI domain is now a reseed rather than a restructure problem.

#### Outcome:

Investigating why the HDMI domain absorbs every addition produced the answer that reframes four cycles of work. That clock runs at 148.54 MHz against a measured Fmax of 151.65 MHz, two percent of headroom, on a `5CSEBA6U23I7` industrial speed-grade seven part, at a rate fixed by the 1080p pixel standard rather than chosen. `ascal` occupies 2,030 ALMs of 35,055, under six percent, against 28,163 for `emu`, so it is neither large nor crowding anything out; it fails first because it is the only clock with no room to absorb a placement shuffle. The decoder by contrast runs at 60 MHz against 63.56 MHz Fmax with 16.7 ns of budget and is healthy. Lowering the output clock would double every budget in that domain, but `video_mode` belongs to the user's `MiSTer.ini` and the core cannot force it; constraining the build to 720p would leave the bitstream unverified for anyone running 1080p, and would sacrifice the scanline and shadow-mask granularity that is much of why this community runs higher output resolutions. `19022d9` then attempted the fifth ASCAL fix by speculation, computing the four possible results of the final two non-restoring divide steps in parallel from `div_v` rather than serially, which is valid because successive add and subtract on 21-bit unsigned are associative including wraparound, and which avoided adding a pipeline stage the depth-matched horizontal pipeline could not have absorbed without realigning `o_copyv`, `o_dcptv_clr`, `o_dcptv_inc` and `o_hpixq`. It worked locally: the divider path left the worst five entirely. It failed globally: the three extra 21-bit adders cost 157 ALMs and raised peak interconnect from 69.6 to 72.4 percent, HDMI setup fell from plus 0.138 ns to minus 0.129 ns at seed eleven, and a second seed reached only plus 0.121 ns, still short of what the unmodified netlist already held. Trading area for logic depth stopped paying because depth is no longer what binds; the paths now surfacing are one and zero logic levels, register to wire to register, with nothing combinational left to precompute, duplicate or speculate. This commit therefore reverts `19022d9` and restores `27ad1b3`'s ASCAL exactly, confirmed by diff. The wider conclusion is recorded deliberately: four structural fixes held because their paths had depth to remove, and the fifth did not because its path did not. HDMI is from here a domain where seed selection is the appropriate tool rather than an evasion, because the seed acts on placement and placement is now the whole mechanism. That is a genuine reversal of the position taken at entry 363, and it applies only to this clock domain; the decoder remains one where a marginal path should be fixed rather than reseeded.

#### Next Steps:

Rebuild at seed eleven and confirm the restored netlist returns to approximately plus 0.138 ns HDMI setup and plus 0.933 ns decoder setup with every category positive. Then validate on MiSTer together with the metadata channel of `27ad1b3`, requiring every raw elementary-stream regression to decode exactly as before, which it should because those streams are plain `.m2v` containing no records and the extractor is invisible to them. Supply the throwaway HPS-side harness that injects records so `inband_count` and the low timestamp bits can be confirmed against an injected value in the schema six snapshot. Presentation on timestamp against the proven clock follows, anchoring from the first record and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Check the weakest margin across all clocks after each addition rather than the decoder alone, and when HDMI is the category that fails, reseed rather than restructure.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 369 COMMIT Unreleased 27ad1b3 2026-08-23T15:03:04-07:00

#### Coming From:

Unreleased c25f3d9

#### Purpose:

Carry picture metadata in band with the elementary stream so the HPS can supply timestamps without a side channel.

#### Outcome:

`EXT_BUS` was investigated as the metadata channel and rejected on a dependency rather than a technical obstacle. It is available to the core, unconnected at `MediaPlayer_top_00.svh`, and its wiring is straightforward, but it carries Main_MiSTer's `user_io` transactions, so something in that binary must issue them; cores that use it have matching support there. Building the metadata path on it would make this project depend on changes to software it does not own, the same class of external dependency as the kernel configuration needed for USB optical media, and nothing in this repository sets a precedent to follow. The ingress byte path needs no such permission and is already proven to 14,315 pictures with working backpressure, so records are framed in band instead. The marker is `0x000001B0`, a reserved H.262 start code that no encoder emits, and start-code emulation prevention guarantees the `0x000001` prefix cannot occur inside payload, so raw elementary streams contain no records and pass through untouched; compatibility is a property of the framing rather than a mode to select. Each record carries five payload bytes holding a 33-bit timestamp with `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame`, the fields interlaced operation will need, so the wire format will not require revision when field pictures are implemented. Detection uses a four-byte sliding window rather than a match counter, which makes overlapping prefixes correct without special cases because the window always holds the true last four bytes. An end-of-transfer flush was required and reinstated using the same download-active synchroniser `c4d9631` used, because without it the final three bytes of every stream would remain in the window and the `sequence_end_code` would never reach the decoder. The focused test proved five properties and caught two real defects in the process: markers were never detected in steady state because the window counter ran past the value the check compared against, and the byte immediately preceding every record was silently dropped, which would have corrupted the bitstream once per timestamp and presented as a decoder fault. It now passes byte-identical passthrough of a stream containing a real start code and an overlapping `00 00 00 01` run, record extraction with exact timestamp and flag decode, rejection of the near-miss `0x000001B1`, the overlapping-prefix record, and backpressure without loss or reordering. The cadence snapshot moves to schema six, word thirty-five's spare bits carrying the record count and the low eleven timestamp bits so an injected value can be matched exactly rather than merely seen to be non-zero. The build closes every category with HDMI setup plus 0.138 ns and decoder setup plus 0.933 ns, the highest recorded, using 35,055 ALMs, 51,819 registers and RBF SHA-256 `6e075113416bf8bb891d2b00ee96a9748441bb42ce2a10dec81ef93b37a8fb13`. The 159 added registers cost 0.257 ns on a clock they do not touch, which is the placement sensitivity this log has been tracking rather than anything specific to this change; average interconnect actually fell to 40.3 percent with peak flat at 69.6 percent, confirming the design is not becoming globally congested.

#### Next Steps:

Investigate why the HDMI domain absorbs every addition before continuing, since four ASCAL paths have now surfaced in sequence. Then supply the throwaway HPS-side harness that injects records so `inband_count` and the low timestamp bits can be confirmed on hardware, and check that the raw elementary-stream regression is unchanged, which it should be because every stream on the MiSTer is plain `.m2v` containing no records and the extractor is therefore invisible to them. Presentation on timestamp against the proven clock follows, anchoring from the first record and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- rtl/mpeg2_new/mpeg2_h262_inband_metadata.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_inband_metadata.sv

#### Status:

- [x] Built
- [x] Passed

---
## 368 COMMIT Unreleased c25f3d9 2026-08-23T13:55:44-07:00

#### Coming From:

Unreleased ed3310b

#### Purpose:

Remove the per-pixel vertical size comparisons from the ASCAL pixel-queue select so the HDMI boundary reaches the seed variance it must survive.

#### Outcome:

Commit `ed3310b` built clean and delivered what it was for, moving HDMI setup from plus 0.054 ns to plus 0.254 ns while every other category stayed positive, using 34,458 ALMs, the lowest of this development run. Decoder setup fell from plus 0.911 ns to plus 0.448 ns in the same fit, which is placement variance within the roughly 0.5 ns spread already measured rather than an effect of a change that touched only ASCAL's vertical counter; the figure that matters is the weakest margin anywhere in the design, and that improved almost fivefold. The bottleneck then relocated to `o_vacpt` feeding `o_vpixq_pre` at four logic levels and 5.790 ns, where the CYCLE 8 pixel-queue select compared `to_integer(o_vacpt)` against `o_ivsize` twice. That call needed a different technique from the previous two fixes: unlike the line-boundary wrap, this block executes on every pixel clock while `o_vacpt` advances only once per line, so a plainly registered predicate would have been stale for the first pixel of every line and would have produced a genuine artifact at the bottom image boundary rather than a theoretical one. This commit therefore updates both predicates in lockstep with `o_vacpt` at each of its two mutually exclusive assignment sites, giving zero skew because predicate and counter change on the same clock. The one behavioural difference from the combinational original is recorded in the code rather than left implicit: the predicates lag by a single line if `o_ivsize` changes while `o_vacpt` does not advance, which occurs only at a mode change where scaler output is transient. Synthesis returned an unchanged register count rather than the expected two additional registers, which could not by itself confirm the predicates survived as registers, so the fit was allowed to settle the question and did: HDMI setup reaches plus 0.395 ns with decoder setup plus 0.473 ns, host bridge plus 1.393 ns, hold plus 0.259 ns, recovery plus 3.950 ns, removal plus 0.677 ns and pulse width plus 1.122 ns, using 34,980 ALMs and 52,123 registers, with RBF SHA-256 `f52f8859277eda230f0bd9b565ca906fdc85debaf8f5014b4659d959182f2ad6`. Across the three ASCAL fixes the weakest margin anywhere moved from plus 0.054 ns to plus 0.254 ns to plus 0.395 ns, a sevenfold improvement from three small and individually precedented changes. The user validated that image on hardware and every stream passed, which accepts all three together: the polyphase select duplication of `cea1d62`, the vertical wrap predicate of `ed3310b` and the pixel-queue selects here, all of which sit in the live video output path where a defect would appear as wrong geometry, unstable sync or bottom-edge artefacts rather than as a decoder error. This is a deliberate stopping point for HDMI work, because the worst remaining path runs from `o_v_poly_phase` to `o_v_poly_t` at 5.907 ns with zero logic levels, a pure register-to-register wire with nothing combinational left to precompute; improving it would require placement control or pipelining the scaler datapath, which is a materially larger change than any taken here.

#### Next Steps:

Resume 0.7.0 with the HDMI boundary no longer the constraint that breaks each addition. Bring up `EXT_BUS`, unconnected at `MediaPlayer_top_00.svh`, together with the throwaway HPS-side harness that exercises it, and define the picture metadata wire protocol carrying the 33-bit timestamp with reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, keeping protocol and harness in one cycle because a protocol with nothing to talk to cannot be tested. Presentation on timestamp against the proven clock follows, anchoring from the first timestamp and retaining free-running cadence for streams without them, then the PCM sink with its elastic FIFO, fill level and underrun telemetry and explicit seek flush. Watch the weakest margin after each addition rather than the decoder alone, since the lesson of this run is that the binding path moves. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, mixed macroblocks, multi-slice, full endurance and the truncation case with its no-reboot recovery, and delete the six compiled but uninstantiated modules for navigability with no timing expectation attached.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
## 367 COMMIT Unreleased ed3310b 2026-08-23T13:17:21-07:00

#### Coming From:

Unreleased cea1d62

#### Purpose:

Remove the vertical-total comparison from the ASCAL sweep's cycle-critical wrap path so the HDMI boundary has margin the next change can survive.

#### Outcome:

Hardware validation of `cea1d62` passed every stream the user observed, which clears three things at once: the presentation time base introduced by `7c29f33` runs correctly on real hardware, the polyphase select duplication of `cea1d62` is proven in the video path rather than merely closing timing, and the schema five snapshot decodes with its new fields intact, having reported fifteen seconds for a fifteen second stream. A picture-count discrepancy raised by `run_hardware_cadence.py`, which reported one hundred four displayed pictures against an expected three hundred sixty, was investigated and is a harness artifact rather than a defect: the archived and independently validated seed ten image `c9bc2ef8` produces the identical complaint, so the expected count passed to that tool does not match what its MGL launch path actually plays. That image also decoded as schema four against the new build's schema five, confirming the decoder script handles both. The remaining concern was margin rather than correctness, because HDMI closed at only plus 0.054 ns against roughly 0.4 ns of measured seed variance on that path, meaning the next addition would break it. Querying the fit rather than guessing showed all five worst HDMI paths are the same one and are not the kind just fixed: `o_vcpt_pre3` bit zero to bit five, four logic levels and 6.352 ns, which is arithmetic depth inside a counter rather than distance between placements. The vertical sweep wrapped by evaluating `o_vcpt_pre3+1>=o_vtotal` inside the line-boundary branch, placing an increment, a twelve-bit comparison and a three-way mux on a single path. This commit precomputes that predicate into a register in the same process, exactly the technique commit 182 used for `o_vcpt_pre2_at_vmin` a few lines above, leaving only the increment and the mux in the critical cycle. Registering it is safe because `o_vcpt_pre3` advances once per line, hundreds of clocks apart, so the registered predicate always reflects the current count when the boundary arrives; only a mode change could make it lag by one clock, where output is transient regardless. Synthesis is clean at zero errors and an unchanged one hundred thirty-five warnings for exactly one additional register.

#### Next Steps:

Build at seed eleven and require every timing category positive with HDMI setup materially above the plus 0.054 ns it held, since the purpose of this change is margin rather than closure, and record whether the worst HDMI path relocates again. Confirm on MiSTer that every raw elementary-stream regression still passes, because this touches the vertical sweep that generates output timing and a defect would appear as wrong geometry or lost sync rather than as a decoder error. If HDMI margin is then comfortable, resume 0.7.0 by bringing up `EXT_BUS` together with the throwaway HPS-side harness that exercises it, defining the picture metadata wire protocol with the timestamp and the reserved `picture_structure`, `top_field_first`, `repeat_first_field` and `progressive_frame` fields, then presentation on timestamp against the proven clock, then the PCM sink. Before release qualification, complete the regression pack still unexercised, in particular long GOP, dense residual, full endurance and the truncation case with its no-reboot recovery.

#### Files Modified:

- sys/ascal.vhd

#### Status:

- [x] Built
- [x] Passed

---
