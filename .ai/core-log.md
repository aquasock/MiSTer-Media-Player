## 482 COMMIT Unreleased ??? 2026-08-24T15:29:53-07:00

#### Coming From:

Unreleased 46bf297

#### Purpose:

Admit and prove pixel reconstruction for the exact native-480i interlaced frame-DCT all-I subset established by the deterministic TFF/BFF fixtures, without yet changing video timing or claiming native output support.

#### Outcome:

Pending implementation and qualification. Extend the frontend capability gate only when sequence and picture state match 720x480, 30000/1001, 4:2:0, complete I-frame pictures, frame prediction/DCT, no concealment vectors, `progressive_sequence=0`, `progressive_frame=0`, `chroma_420_type=0` and `repeat_first_field=0`; preserve either authored `top_field_first` value. Carry `chroma_420_type` as explicit captured state rather than relying only on the existing syntax comparison. Reuse the current frame raster, inverse quantizer, IDCT, intra reconstruction and full-frame storage mapping because the approved subset does not introduce field-DCT or field-motion syntax. Add a dedicated end-to-end RTL regression for both generated streams that checks accepted headers, all four reconstructed pictures, component coordinates and decoded samples against the FFmpeg oracle. Keep the existing 800x600 progressive diagnostic presentation and keep the user-facing compatibility checker at an explicit unsupported boundary until native 480i timing/presentation is implemented.

#### Next Steps:

Implement the bounded common/progressive/interlaced I-picture capability predicates and explicit chroma field, then add and run the full reconstruction regression for TFF and BFF. Re-run the existing progressive I fixture and current parser/stream regressions to prove the original gate and reconstruction path are unchanged. Commit only if both field orders reconstruct successfully and unsupported interlaced syntax remains excluded. After this commit is proven, prepare the separate native 480i timing, field-aware chroma presentation and MiSTer field-signalling proposal; stop for approval if reconstruction evidence requires field-DCT, field pictures, repeat-first-field, P/B changes or another material scope expansion.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- tools/streams/tb_h262_interlaced_i_reconstruction.sv
- tools/streams/run_interlaced_i_reconstruction.sh
- supporting regression/oracle generation source if required

#### Status:

- [ ] Built
- [ ] Passed

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
## 458 COMMIT Unreleased 1a6e6b4 2026-08-24T08:59:05-07:00

#### Coming From:

Unreleased 2054426

#### Purpose:

Record that the residual cadence cost tracks timestamp record placement rather than presentation, and build the control that separates the record from where it lands.

#### Outcome:

The user ran `25_bbb_opening24_gop_pts.m2v` and reports the stutter gone, with ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,920 bytes at SHA-256 `4cf3439106759505629e761981abfcc7ccdc05e3648df08586bb6ced939e3949` and the run is indistinguishable from the unannotated control: zero aggregate error flags, all 577 pictures displayed with 576 swaps, sequence end, presentation complete, normal quiet reason one, zero gap outliers, and the same three largest display gaps of 49,738 microseconds at display ordinals three, four and six that the raw control produced. Presentation hold is 778,283,682 cycles against the raw control's 781,845,922, and decoder stall 655,665,458 against 655,685,975. Twenty-six timestamps cost nothing measurable; 551 cost 21 outliers and a 116.054-millisecond worst gap. The residue therefore scales with record placement and is not a property of timestamp-driven presentation, because this control is timestamp-driven, associates 24 timestamps and still presents exactly as the unannotated video does.

One counter separates the two candidate mechanisms more sharply than the outlier count does. Accepted transport bytes are 3,138,618 for the raw control and 3,138,618 for this one, both exactly the video's own length after extraction, but 3,138,619 for the 551-record control and for the audio-video file, which is one byte more than the video contains. The two streams that accept a spurious byte are precisely the two that carry a record immediately after video ending in `00 00 01`, and the two that accept the exact count are the two with no such adjacency. That is direct evidence that record extraction mishandles a record placed on a start-code prefix, injecting a byte into the elementary stream the decoder then has to absorb, rather than evidence that records cost pipeline time in proportion to their number.

Commit `1a6e6b4` builds the control that decides between those two readings. `strip_inband_pcm.py` can now defer a record by one video byte when it would otherwise land on a start-code prefix, which preserves the record count at 551, the offsets of every other record, all 577 pictures and the exact video at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. The generated `26_bbb_opening24_pts_noprefix.m2v` is 3,143,577 bytes at SHA-256 `d94e9780fdb86680edd484ed5f1e68381abdd7ee18a24e8c3e9195c779a49cf0`, the same length as the dense control, and a scan before extraction now finds exactly 577 picture start codes rather than 579. The helper passes it through byte-identically under native and sanitized builds, and regenerating both earlier controls after the change reproduces the installed files exactly. Only that file was installed, by the same staged roundtrip, with the `9f83805` helper confirmed still resident and no RBF, Main or other media file touched.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `26_bbb_opening24_pts_noprefix.m2v`, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. It carries the same 551 records as the control that produced 21 outliers, differing only in that none of them sits on a start-code prefix. A clean run with 3,138,618 accepted bytes proves the residue is the adjacency and makes the correction a helper-side one, never placing a record where the preceding bytes end in `00 00 01`, which also removes 66 such adjacencies from the audio-video transport and must then be retested there. A run that still produces about 21 outliers proves the cost is per-record and independent of placement, which leaves the spurious byte as a second and separate defect in extraction. Either result leaves the dominant mechanism untouched and architectural: with PCM present the shared byte path is paced by the audio sink, presentation hold collapses from roughly 780,000,000 cycles to 12,376,681, and correcting that means deepening `audio_pcm_fifo` past any lead the helper can produce or buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate`, both Quartus work to be chosen on resource and timing numbers.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 457 COMMIT Unreleased 2054426 2026-08-24T08:53:01-07:00

#### Coming From:

Unreleased 386d3c1

#### Purpose:

Measure the residual record-carrying cadence cost against record density, after the timestamp-only control isolated PCM gating as the dominant mechanism.

#### Outcome:

The user ran `24_bbb_opening24_pts_only.m2v` and reports the stutter mostly gone but still present, and still worse than the audio-free control played in the past, with ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,928 bytes at SHA-256 `46e4a18ef82db01fb8d275389deda76664df91ee94b8881de1fa53b8d011d15a`, with zero aggregate error flags, all 3,138,619 bytes accepted, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. The control answers the question it was built for, and the split is lopsided. Presentation hold returns to 783,626,293 cycles against the raw control's 781,845,922 and the audio-video file's 12,376,681, and presentation stall to 775,473,833 against 777,671,229 and 11,794,180. Decoder stall is 655,681,763 against the raw control's 655,685,975, a difference of four thousand cycles in six hundred and fifty million. Removing PCM from a stream that keeps the same video bytes, the same 551 timestamps at the same offsets and the same record extraction restores the decoder's slack completely.

The outlier count falls from 170 to 21 while the raw control's is zero, so the two mechanisms are now separated and measured. Real-time PCM sink gating destroys the decoder's reservoir and accounts for roughly 149 of the 170 outliers: with PCM present the shared path advances only as fast as the 48 kHz sink drains, the decoder can never run ahead, and every picture whose decode overruns its frame interval is late. That is why bounding delivery order and filling the compressed FIFO both failed to help; neither can create slack on a path that is paced by an audio sink, and the helper has no way to reach it. The remaining 21 outliers belong to the records themselves, because this control has full slack and still misses deadlines the identical unannotated video never missed. Its largest gaps are 116.054 milliseconds at display ordinal 65 with no compressed input pending and the scheduler reporting a released pending frame, 82.896 milliseconds at ordinal 196 with both scratch banks pending during a closed reorder run, and 66.317 milliseconds at ordinal 28 with the decoder not ready. `hold_scratch_available_cycles` also rises to 6,963,478 against the raw control's 2,984,470, so the scratch pool is being held longer when records are present even though nothing is starved.

The transport-level adjacency recorded in entry 456 is now a candidate mechanism for that residue rather than a curiosity. This control carries 551 timestamp records and two picture start codes that its video does not contain, and it produces 21 outliers; the audio-video transports carry the same timestamps plus more than a million PCM records, present 59 and 66 such adjacencies before extraction, and produce 139 and 170. The correlation is suggestive but not proof, because record count, adjacency count and PCM gating all rise together and only gating has been isolated so far.

The density control was approved and built. Commit `2054426` teaches `strip_inband_pcm.py` to keep only the first timestamp of each group, which changes record count without touching a single video byte: `25_bbb_opening24_gop_pts.m2v` is 3,138,852 bytes at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0` and carries 26 timestamps against the 551 of `24_bbb_opening24_pts_only.m2v`. Removing its timestamps reduces it to the same accepted video at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`, the helper passes it through byte-identically under native and sanitized builds, and regenerating the dense control after the change reproduces the installed file exactly, so the tool's existing behaviour is unchanged. Only that file was installed, by the same staged roundtrip, with the `9f83805` helper confirmed still resident; no RBF, Main or other media file was touched.

One confound has to be stated rather than discovered later. The sparse control carries 577 picture start codes before extraction, exactly what its video contains, because both of the entry 456 adjacencies happened to belong to dropped records. It therefore varies record count and adjacency count together, from 551 and two to 26 and zero. A fall in outliers is consistent with either a per-record cost or the adjacency, and separating those two would need a third control that keeps 551 records while avoiding the adjacency; no change in outliers rules out both and leaves the presentation timeline itself, which is the more valuable answer and the reason to run this control first.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `25_bbb_opening24_gop_pts.m2v`, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. The measurement is the outlier count against 21 for 551 records, zero for no records and 170 for the audio-video file, with presentation hold expected to stay near the raw control's 781,845,922 cycles because this control has no PCM and therefore no gating. An outlier count falling roughly with record count makes the residue a per-record cost in extraction or the decoder pipeline, and the follow-up is a 551-record control built to avoid the two adjacencies, which separates the record from where it lands. An unchanged count of about 21 makes the residue a property of timestamp-driven presentation, and the follow-up is FPGA-side at the `pending_frame_released` state seen at ordinal 65 and the both-banks-pending reorder state at ordinal 196. Either way the dominant mechanism is unchanged and still architectural: the shared byte path is paced by the audio sink whenever PCM is present, and correcting it means either deepening `audio_pcm_fifo` beyond any lead the helper can produce or buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, both of which are Quartus work to be chosen on resource and timing numbers.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 456 COMMIT Unreleased 386d3c1 2026-08-24T08:41:14-07:00

#### Coming From:

Unreleased 9f83805

#### Purpose:

Separate in-band records from real-time PCM gating with a timestamp-only control derived from the helper's own transport, before any FPGA work begins.

#### Outcome:

The user reran `23_bbb_opening24_exact_av.mpg` on the `9f83805` helper and reports audio synchronization still good, the stutter slightly worse, and ordinary terminal indication with USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,938 bytes at SHA-256 `99b09546a25c7c104bd5e0c304b68170487620f8d403140392dd4bdf6e065ba4`. Correctness is unchanged and complete: zero aggregate error flags, no underrun, no PCM protocol error, all 3,138,619 bytes accepted, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. The startup budget did what it was measured to do on the host and did not do what it was predicted to do on hardware. First presentation returns to 2,275,519 cycles against the raw control's 2,275,460, so the fuller lead costs nothing at startup and the user confirms synchronization is unaffected, which settles the one risk that bounded the budget. But the outlier count falls only from 174 to 170, the largest gap grows from 182.371 to 431.059 milliseconds, and the session lengthens from 24.044 to 24.369 seconds.

Presentation hold rises from 7,967,197 to 12,376,681 cycles, a 55 percent improvement on a quantity that must reach roughly 781,845,922 to match the smooth raw control. Tripling the compressed-FIFO lead moved the deficit by less than two percent of the distance, so the missing slack is not the lead and cannot be bought with more of it. Decode work remains identical across all three runs, with decoder stall at 655,685,975 raw, 644,013,299 on `cf1d173` and 643,974,167 now, and intra, predicted and bidirectional stalls matching to within three percent throughout. The hypothesis recorded in entry 455 is therefore refuted by its own acceptance test, and delivery ordering is exonerated as the cause of the cadence: two independent transport corrections, one bounding delivery order and one filling the sink FIFO, both leave the outlier count essentially where it was while decode work never changes.

The remaining evidence points inside the FPGA. The two largest reordered gaps at picture ordinals fifteen and 33 repeat their `cf1d173` signature exactly, at 198.950 milliseconds each with `decoder_ready` true, compressed input pending, `scratch_available` false, a reorder run active, a decode in flight and a future frame pending, which is scratch exhaustion during reorder rather than any shortage of bytes. The new largest gap at ordinal fourteen has the opposite signature, 431.059 milliseconds with scratch available, the decoder ready and the scheduler reporting presentation complete, so it is a scheduler state question rather than a resource one. `hold_scratch_available_cycles` also falls from 3,397,412 to 582,616 while the lead grew, which is consistent with the scratch pool, not the byte path, being what the audio-video case runs out of.

That control was approved and is built by `strip_inband_pcm.py` in commit `386d3c1`, which removes only the PCM records from the helper's own output rather than rebuilding the stream, so the timestamps land at exactly the elementary-stream offsets hardware saw. The generated `24_bbb_opening24_pts_only.m2v` is 3,143,577 bytes at SHA-256 `2a58632d3efbb4581d1cf3434d3dbe1d39f4f1ee2f4561cfdc2f47b7d0c13d39`, matching the video and timestamp byte count the analyzer measured for the audio-video transport, and carries all 551 timestamp records with 1,154,304 PCM records removed. Removing the timestamps as well reduces it to the accepted raw control at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`, so the video is provably the same 577 pictures that already played smoothly. The helper passes the file through byte-identically under both native and sanitized builds, since an elementary stream takes no scheduling. Only that file was installed, by the same staged roundtrip; the `9f83805` helper was confirmed still resident and unchanged, and no RBF, Main or existing media file was touched.

Validating the control surfaced a transport property worth recording on its own. The compatibility checker reads the annotated file as 579 pictures with two of them missing a coding extension, against 577 in the unannotated control, and the two extra picture start codes sit exactly where a record follows video whose last three bytes are `00 00 01`: the record's own leading zero completes a picture start code that the video did not contain. The same adjacency exists in the shipped audio-video transports, where a scan taken before record extraction sees 636 picture start codes under `f2b2e02` and 643 under `9f83805` rather than 577, because PCM records are inserted at far more points than timestamps are. Stripping records restores the exact video in every case, so a byte-serial extractor that strips before parsing is unaffected, and the hardware displayed exactly 577 pictures in both audio-video runs, which argues that picture counting happens after extraction. It nonetheless means the record insertion point is not neutral to a parser reading the stream ahead of extraction, and that the count of such adjacencies rose with each of the two transport corrections while the outlier count did not fall. Whether that is coincidence or mechanism is precisely what the installed control now separates.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `24_bbb_opening24_pts_only.m2v`, which has no audio by construction, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. The comparison is against the raw control's zero outliers and 781,845,922 cycles of presentation hold, and against the 170 outliers and 12,376,681 cycles measured on the audio-video file whose video bytes and timestamps this control reproduces exactly. A smooth run places the defect in PCM sink gating and its interaction with the reorder and scratch logic, and the next work is FPGA-side. A stuttering run places it in timestamp-driven presentation or in record extraction itself, reproducible with no audio at all, and the immediate follow-up is then a second control with the timestamps removed to separate the records from the presentation timeline they carry. Either way, do not change the helper again until this control has answered, because two transport corrections have now been spent on a mechanism that has not been isolated.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 455 COMMIT Unreleased 9f83805 2026-08-24T08:26:32-07:00

#### Coming From:

Unreleased f870d98

#### Purpose:

Give the decoder its compressed-FIFO reservoir back by ending the startup video lead on a byte budget, after paired captures showed the stutter is lost presentation slack rather than delivery.

#### Outcome:

The user ran `23_bbb_opening24_exact_av.mpg` on the `cf1d173` helper and reports the stutter still present, audio and video still aligned, and ordinary terminal indication with USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,898 bytes at SHA-256 `1e4aa14922109364934c65cddcc80030f03c27ec56fc2f31fa1ca207fe44cb4d`, taken over FTP because this workstation's SSH client can no longer authenticate to the MiSTer; the screenshot command was written to `/dev/MiSTer_cmd` through the FTP data path instead, which is a working substitute for the documented capture route. Half the acceptance criteria are met. Aggregate error flags are zero, `audio_pcm_underrun` and `pcm_protocol_error` are both false, all 3,138,619 transport bytes are accepted, 194 reference plus 383 B pictures decode, all 577 pictures display with 576 swaps after eight-bit wrap, sequence end is seen, presentation completes and the snapshot is the normal quiet reason one with the PCM count and FIFO peak saturated. The sticky underrun that entry 451 measured at 21.74 seconds is gone from a file that reproduces its exact opening bytes with audio.

The cadence is not fixed and is worse in peak terms: 174 display gaps cross the outlier threshold in 24.044 seconds, against 139 in the first 21.74 seconds of the full soak, and the three largest are 10,942,272 cycles or 182.371 milliseconds at picture ordinal fifteen, 9,947,520 cycles or 165.792 milliseconds at ordinal 33, and 6,963,264 cycles or 116.054 milliseconds at ordinal five. Their signature has changed from entry 451, where the largest gaps recorded `decoder_ready` false with compressed input pending. Every large gap here records `decoder_ready` true with input pending, and the two largest add `scratch_available` false with a reorder run in flight, a decode in flight and a future frame pending. The decoder is neither starved of bytes nor unable to accept them.

Retrieving the entry 453 raw capture from the MiSTer and decoding it beside this one settles the mechanism, because both runs present the same 577 pictures from byte-identical H.262 through the same FPGA image. Decode work is the same to within three percent: decoder stall 655,685,975 cycles raw against 644,013,299 with audio, intra stall 61,907,556 against 61,920,490, predicted stall 197,169,953 against 195,855,651, bidirectional stall 396,608,466 against 386,237,158, and prediction requests identical at 59,531,848. One pair of counters differs by two orders of magnitude: presentation hold falls from 781,845,922 cycles, 13.03 seconds or 54 percent of the raw session, to 7,967,197 cycles or 0.13 seconds, and presentation stall falls from 777,671,229 to 4,569,905. The raw run spends half its time waiting to present because the decoder is far ahead; the audio-video run never waits because the decoder is never ahead. Both deliver 577 pictures in about 24 seconds, so average throughput is identical and only the slack differs.

That slack is the compressed video FIFO's fill, and it is set at startup rather than in steady state. `rtl/mpeg2_stream_fifo.sv` holds 32 KiB, about 0.25 seconds at this stream's 130,776 bytes per second. Without audio the helper writes video as fast as the FPGA accepts it, so that FIFO sits full and absorbs every picture whose decode exceeds one 41.667-millisecond frame interval; the raw run's largest gap is 49.738 milliseconds and it never crosses the threshold. With audio sharing the path, the accepted two-picture startup boundary releases audio after only 5,301 video bytes, so the FIFO stabilises near sixteen percent full and the shared path then runs at real time, leaving no reservoir for decode-time variance. Steady-state interleaving cannot recover a lead it never established, which is why bounding delivery order corrected the audio without touching the cadence.

Commit `9f83805` was approved and implements exactly that. The lead now ends only when the second picture start has been seen and 28,672 video bytes have crossed, so a payload smaller than the budget keeps its existing boundary and real content gets the reservoir. Measured on the transports, the startup video lead rises from 5,301 to 28,609 clean bytes on the diagnostic and from 1,280 to 28,654 on both controls, while the short and faded fixtures are unchanged at 179,893 because their intra picture is larger than the budget and their second picture start still ends the lead. The full soak reproduces every established payload figure exactly: 342,199,090 transport bytes, video and timestamps at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f`, PCM at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, steady batches within 2,048 and PCM-free video spans within 4,052 bytes. The audio margin improved rather than regressed: the deepest audio deficit over the whole movie falls from 7,374 frames to zero, because the lead leaves audio permanently further ahead of the sink than it was. All four fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope corpus is unchanged at three passes and six intended failures with identical exit statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `9c20dc699cf1c2fd8e28aa78ba9d4c754def62fe0ff0df51b32df21614a7dde6`. Only the helper was installed, through the same staged roundtrip verification, with the previous helper preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-startup-lead.cf1d173`; RTL, RBF, Main and every media file are untouched and no playback was launched.

One consequence has to be watched on hardware rather than asserted from the host. The lead is 0.22 seconds of video at this stream's rate, so if the core presents pictures as they arrive rather than against its own timeline, audio will begin that much after video and the offset will persist. The raw control presented 577 pictures in 24.006 seconds and the audio-video run in 24.044, which is the source cadence in both cases and indicates timeline-paced presentation, so the expectation is a fuller FIFO and unchanged synchronization. A perceptible lag of audio behind video is therefore the specific failure this budget can introduce, and it bounds how large the budget may grow.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `23_bbb_opening24_exact_av.mpg` again. The acceptance question is whether the outlier count falls from 174 toward the raw control's zero, so report visible stutter, whether audio still starts with the picture rather than noticeably behind it, and all three LEDs, then leave the final image loaded for a schema-eight capture. The capture must keep aggregate errors, underrun and PCM protocol errors clear with all 577 pictures displayed, and presentation hold should rise from 7,967,197 cycles toward the raw control's 781,845,922. If the outlier count falls but audio now trails the picture, reduce the budget rather than abandoning it. If the outlier count does not fall at all, delivery is exonerated and the remaining cause is the presentation scratch scheduler, with the `scratch_available` false evidence at ordinals fifteen and 33 as the starting point for FPGA work. If it passes, rerun `20_bbb_full_48k.mpg` end to end before any release consideration.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
## 454 COMMIT Unreleased f870d98 2026-08-24T08:12:56-07:00

#### Coming From:

Unreleased cf1d173

#### Purpose:

Build the exact-byte 24-second audio-video opening diagnostic and install it with the `cf1d173` helper under staged verification and preserved rollback.

#### Outcome:

`extract_program_stream_opening.py` cuts a Program Stream at a picture boundary without disturbing what it carries: packs and PES packets are copied verbatim, only the packet holding the first picture past the cut is rewritten to shorten its declared length to the payload retained, and the audio packets that follow are carried forward until the audio covers the picture kept, because a cut taken on video alone ends with less audio than picture and the sink would drain that shortfall as an underrun the source never had. Seven audio packets are appended for 1,155,456 samples against the 1,154,000 the 577 pictures require. The generated `23_bbb_opening24_exact_av.mpg` is 3,765,903 bytes at SHA-256 `d4b3ba1f02be1bd06a89e6f7b06f3ecf533ba0a09c8d7453056a501dadf0f585`, passes the compatibility checker at 720x480, frame-rate code two, 25 I plus 169 P plus 383 B pictures and 48 kHz stereo MPEG Layer II, and its demuxed video is byte-identical to the accepted raw control from entry 452 at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. The same H.262 bytes that played perfectly without audio are therefore now under test with their own audio and nothing else changed.

That file is a direct discriminator between the two helpers rather than a general soak. Under the installed `f2b2e02` helper it reproduces the failure signature in 24 seconds: the audio deficit reaches 8,894 frames at 22.8 seconds, above the 8,192-frame sink FIFO, and the maximum PCM-free video span is 62,716 bytes. Under `cf1d173` the deficit never becomes positive at all, the maximum PCM-free video span is 4,052 bytes and steady batches stay within the accepted 2,048, with the transport carrying all 3,143,577 video and timestamp bytes and all 1,154,304 PCM frames and one clean end. The native and address-and-undefined-sanitized helpers agree.

Installation was staged and verified at every step, and the FPGA image, MiSTer Main and every existing media file are untouched. The installed helper was first downloaded and confirmed to be exactly `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58`, which a fresh official-toolchain rebuild of the `f2b2e02` source reproduces byte for byte, so the rollback path is proven rather than assumed. Those exact bytes were preserved as `/media/fat/linux/MediaPlayer_Helper.backup.pre-delivery-order.f2b2e02` and read back for comparison. The new helper was uploaded under a staging name, downloaded and confirmed byte-identical at SHA-256 `d40a3eeb8c5dfa1f41ee7a82ee7966b310ec458da789972ca7025f75866117f2`, then promoted, made executable and read back again at the same hash. The diagnostic was placed in `/media/fat/games/MediaPlayer/v0.7_qualification` by the same staged path and verified after promotion. No playback was launched.

#### Next Steps:

Power-cycle the MiSTer, set Audio Test to Off and run only `23_bbb_opening24_exact_av.mpg`. Acceptance is zero audible crackle or dropout, no repeated or late frames through the full 24 seconds, audio and video aligned at the end, and ordinary USER, DISK and POWER states; leave the final image loaded for a schema-eight capture and require zero aggregate, decoder, presentation, destination, PCM protocol and underrun flags with all 577 pictures displayed. If audio still underruns on this file, the delivery-order correction is insufficient and the next boundary is audio lookahead depth rather than interleaving, with the exact rollback available as `MediaPlayer_Helper.backup.pre-delivery-order.f2b2e02`. If it passes, run `20_bbb_full_48k.mpg` end to end and require completion without underrun or repeated-frame cadence, watching the high-motion sequence near 7:22 and the quiet stretch near 5:00, where host analysis still measures the deepest remaining audio excursion at 7,374 frames.

#### Files Modified:

- tools/streams/extract_program_stream_opening.py

#### Status:

- [x] Built
- [ ] Passed

---
## 453 COMMIT Unreleased cf1d173 2026-08-24T08:06:55-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Bound in-band delivery order to the sink FIFO after exact-byte isolation placed both the cadence regression and the sticky underrun in helper pacing.

#### Outcome:

The user ran `22_bbb_opening24_exact_video.m2v` without rebooting and reports completely smooth motion, ending with USER and POWER solid on and DISK blinking eleven times. The completed 800x600 capture is 545,901 bytes at SHA-256 `50eb09fefb6f822bda693365ee2619ad4d24354205766ce40b25ce63fc7988b8`. Schema-eight telemetry accepts all 3,138,618 bytes with zero aggregate, presentation, destination, PCM protocol or underrun errors, sequence end, presentation completion and normal quiet reason one. The eight-bit counters reconstruct exactly to 25 I plus 169 P plus 383 B pictures, all 577 displays and 576 swaps. Those 576 intervals span 24.006454 seconds for 23.994 delivered frames per second. No gap exceeds the 3,000,000-cycle or 50-millisecond outlier threshold; the three largest are all 2,984,256 cycles or 49.738 milliseconds. Because this raw stream is copied from the failed Program Stream's exact H.262 opening, the paired result conclusively excludes encoded scene complexity, source timestamps, decoder throughput and the current FPGA image: the same bytes are smooth without PCM, while the audio-video form produces 139 outliers up to 116.054 milliseconds and an audio underrun within 21.74 seconds.

The transport structure explains both defects. The full file carries 14,315 video packets averaging 5,898 bytes but 28,628,352 audio samples, nearly 2,000 samples per video packet. The current helper may therefore place as many as 2,048 consecutive PCM records before one whole video packet. Once the 8,192-sample FPGA FIFO fills, that batch backpressures the shared byte path for approximately 42.7 milliseconds before the compressed picture can advance, adding an audio-sized pause to a raw decoder interval already measured near 49.7 milliseconds. Conversely, the existing single-sample guard before as many as 65,535 video bytes cannot refill enough audio to survive a difficult picture, which accounts for the sticky underrun. This is ordering granularity in the helper rather than corrupt content or insufficient FIFO capacity.

Commit `cf1d173` implements the approved correction with two constants revised on measured evidence, and the revision was approved before anything was committed or installed. The startup release, the 256-byte video slicing, the 4,096-frame steady reserve and the 128-frame refill after at most 4,096 PCM-free video bytes are all as approved. The approved 128-frame steady batch cap is not, because it makes audio admission a function of the video byte rate: 128 frames per 256-byte slice is half a frame per byte, while the movie needs an average of 0.34 and as much as 5.99 during the near-static second at 300 seconds, where video falls to 8,018 bytes per second over a full second and 4,608 over half a second. Built exactly as approved, the helper ended the soak 317,982 frames behind and delivered only 28,319,234 of 28,628,352 samples before the final video byte, a deeper starvation than the one being corrected. The cap therefore stays at the accepted 2,048 frames, which with the 4,096-frame reserve keeps peak occupancy at 6,144 against an 8,192-frame sink FIFO so a batch never waits for room, and the horizon is now served when the video queue is empty as well, so a quiet scene cannot throttle audio through its own byte rate.

The analyzer gained the measurement that decides this class of defect: at every timestamp record it compares the audio that has crossed against what the sink has consumed by then, and fails above the 8,192-frame FIFO depth documented in `rtl/audio/audio_pcm_fifo.sv`. Applied to the installed `f2b2e02` helper it reproduces the hardware failure rather than describing it: the deficit holds at 4,578 frames of surplus for the whole movie, then spikes to 8,750 frames at 21.7 seconds and 8,894 at 21.9 seconds, which exceeds the 8,192-frame FIFO exactly where entry 451's telemetry froze on `audio_pcm_underrun`. Under `cf1d173` the worst deficit anywhere in the movie is 7,374 frames at 461.3 seconds, and at 21.7 seconds the sink is 2,626 frames ahead instead of behind. The maximum PCM-free video span falls from 64,768 to 4,052 bytes and no admitted video run exceeds 256 bytes, while the transport remains 342,199,090 bytes with video and timestamps at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and PCM at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, both unchanged.

Host qualification is complete and no installed file has been touched. Short and faded fixtures at 48 and 44.1 kHz and both controls pass under native and address-and-undefined-sanitized helpers, and a helper built from `f2b2e02` produces byte-identical video, timestamp and PCM payloads on all six, so only the interleaving changed. The nine-case envelope corpus retains three passes and six intended failures, and every failure case returns the same exit status and message as the baseline helper. Two official GCC 10.2.1 builds are byte-identical; the 361,452-byte static stripped ARM EABI5 helper has SHA-256 `d40a3eeb8c5dfa1f41ee7a82ee7966b310ec458da789972ca7025f75866117f2`. One pre-existing defect was observed and not changed: a Program Stream carrying no decodable MPEG Layer II audio, including `good_video_only.mpg` and `bad_audio_codec.mpg`, fails on the 512 KiB video lookahead limit rather than the intended missing-audio message, identically on both helpers.

#### Next Steps:

Build the copied-stream 24-second audio-video opening diagnostic from `20_bbb_full_48k.mpg`, then install only the `cf1d173` helper and that file through staged roundtrip verification with the exact `f2b2e02` helper preserved for rollback, leaving RTL, RBF, Main and every existing media file unchanged. Require zero audio underrun, zero cadence outliers above the 3,000,000-cycle threshold, clean synchronization and ordinary LEDs on that diagnostic before the full soak is repeated. If the diagnostic passes, rerun `20_bbb_full_48k.mpg` end to end and require completion with no underrun, no repeated-frame cadence, stable alignment through the high-motion sequence near 7:22 and the credits, and a schema-eight capture with zero aggregate, decoder, presentation and destination errors. The residual host measurement to watch is the 7,374-frame deficit at 461.3 seconds, which is within the FIFO but is the deepest remaining excursion; if hardware shows an underrun there rather than at 21.7 seconds, the next boundary is audio lookahead depth rather than delivery order. Separately, the missing-audio Program Stream path should report its own error instead of the lookahead limit.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/analyze_arm_av_transport.py

#### Status:

- [x] Built
- [ ] Passed

---
## 452 COMMIT Unreleased f2b2e02 2026-08-24T07:31:54-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Isolate the failed Program Stream cadence from decoder throughput with an audio-free high-motion control, then prepare an exact-byte opening comparison before changing pacing code.

#### Outcome:

Before touching the MiSTer, the user recorded the completed full soak's ordinary terminal indication: USER and POWER solid on with DISK blinking eleven times. Without rebooting, the exact installed `13_bbb_squirrel_15sec_native24_q6.m2v` then played its 7:15–7:30 high-motion sequence perfectly with no visible stutter and no audio by design, ending with the same ordinary LEDs. The completed 800x600 capture is 508,980 bytes at SHA-256 `3cc49f8b2180b90f4ebce63f0875fd82eae7eb60c04f840ecb558713e9c40d20`; an initial 425,984-byte retrieval occurred before the screenshot finished writing and was discarded rather than analyzed. Schema-eight telemetry reports zero aggregate errors, no audio underrun or PCM protocol error, all 2,603,570 bytes accepted, 121 reference plus 239 B pictures decoded, sequence end, presentation completion and normal quiet reason one. The eight-bit display counters wrap exactly as expected for all 360 pictures and 359 swaps. Reconstructing that wrap gives 359 intervals over 14.960773 seconds, or 23.996 frames per second. No display gap crosses the 50-millisecond outlier threshold, and the three largest are all only 2,984,256 cycles or 49.738 milliseconds. This is a sharp contrast with the audio-video soak's 139 threshold crossings and 116.054-millisecond repeated-frame gaps within its first 21.74 seconds, and proves the current decoder and RBF can sustain demanding 24 fps content when PCM is absent.

One encoding variable remains because the existing squirrel clip begins a fresh audio-free encode at 7:15 rather than reusing the failed Program Stream's exact bytes. A final bounded discriminator was therefore produced without source changes: `22_bbb_opening24_exact_video.m2v` is the first 577 pictures copied byte-for-byte from `20_bbb_full_48k.mpg`'s H.262 stream, followed only by a sequence-end code. The 3,138,618-byte file passes the 720x480 frame-rate-code-two envelope at 25 I, 169 P and 383 B pictures and has SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. It was uploaded under a staging name, retrieved byte-identically, promoted only after verification and retrieved again at the same hash. Helper, RBF, Main and every existing media file remain unchanged, and no playback was launched during installation.

#### Next Steps:

Without rebooting, run only `22_bbb_opening24_exact_video.m2v`. Report whether its 24-second motion is continuous or shows the repeated-frame cadence seen during the opening of `20_bbb_full_48k.mpg`, plus USER, DISK and POWER at the end, then leave its final image loaded for schema-eight capture. A clean exact-byte raw run will conclusively place both the cadence regression and the soak's early underrun in shared in-band PCM/video pacing; matching stutter will instead identify the encoded opening's decoder workload. Do not replay the full Program Stream or run another file before capture.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 451 COMMIT Unreleased f2b2e02 2026-08-24T07:22:11-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Close the full audio-video soak with quantified cadence and audio evidence, distinguish authored end-sting level from helper decode, and select the shortest isolating follow-up.

#### Outcome:

The user completed `20_bbb_full_48k.mpg` without replay. Audio stayed synchronized for the full 9:56 and had no crackle or audible stutter during the body, but video showed definite brief repeated or late frames roughly every quarter to half second, more frequently than once per second. At the closing iris immediately before the final plate, the audio sounded as if it blew out. The untouched terminal screenshot is 8,050 bytes at SHA-256 `4ad16a8fc108fe0935fd48651e688c35af97988612357cced397de6a8334290e` and correctly shows the final black raster, but schema-eight telemetry had frozen on the first fatal condition about 21.74 seconds into playback. Its sole aggregate flag is `0x0400`, a real `audio_pcm_underrun`; PCM protocol, presentation and destination errors remain clear. At that freeze 2,876,134 transport bytes had been accepted and 139 display gaps had already exceeded the profiler's 3,000,000-cycle or 50-millisecond outlier threshold. The three largest gaps are each 6,963,264 cycles or 116.054 milliseconds at picture ordinals nine, 57 and 81; all record `decoder_ready` false and compressed-input FIFO pending while scratch space is available and neither presentation nor destination holds. The eight-bit long-run picture counters wrap, but their states and the 16-bit outlier count prove frequent decoder-input lateness rather than source timestamp jitter or a presentation hold, matching the user's observation while the audio-owned timeline preserves long-term sync.

Main's retained 3,972,939-byte log at SHA-256 `90ceb8a7ac772cf2822ad4311e3d6b08e111068ea5cef6ddcd7b8934c87ef810` proves complete host delivery despite that hardware freeze: helper exit is zero, all 342,199,090 deterministic transport bytes arrive over 83,545 reads with 667 transient would-block results, all 84,543,918 video and PTS bytes and all 28,628,352 PCM frames are emitted, and the established scheduler peaks remain 370,338 video bytes plus 6,654 samples. The final-sting decode is not invented by the helper. Helper and FFmpeg outputs are both exactly 28,628,352 stereo frames; across the entire movie and every measured tail window the helper differs by at most two signed sixteen-bit counts with approximately 0.504-count RMS error. At 579.946 seconds, 16.478 seconds before the end and coincident with the user's closing-iris marker, both decodes reach full scale on the same four samples. That loud transient is therefore present in the encoded source and the ARM decode preserves it, though the independent early hardware underrun means the overall playback path still fails the clean-audio requirement. The soak fails release acceptance on both frequent cadence outliers and sticky underrun even though it completes, stays synchronized and avoids audible body crackle.

#### Next Steps:

Before any source or installed-state change, record the soak's final USER, DISK and POWER states, then run only the already installed `13_bbb_squirrel_15sec_native24_q6.m2v` without rebooting. Its exact 2,603,570-byte SHA-256 is `9257ffadc24eb6696fc9760f3253764b396c993dfc3640e921c97611bad2edce`, it contains 360 audio-free pictures from the 7:15–7:30 high-motion sequence and it passes the same video envelope. Report whether its motion is continuous or shows the same repeated-frame cadence, especially at the wooden spikes near 7:22, plus all three final LEDs, then leave its final image loaded for schema-eight capture. A smooth raw clip isolates the defect to shared in-band PCM/video pacing; matching stutter instead isolates it to decoder throughput or a decoder-side regression. Do not replay the ten-minute Program Stream.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 450 COMMIT Unreleased f2b2e02 2026-08-24T07:11:14-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Preserve the first in-progress full-soak cadence observation without disturbing playback or conflating it with audio-video drift.

#### Outcome:

During the uninterrupted `20_bbb_full_48k.mpg` run, the user reports suspected microstutters while audio remains synchronized, then confirms that brief repeated or late video frames accurately describe the visible behavior. No mid-run screenshot was triggered because host screenshot work could perturb the very cadence under observation. Read-only inspection proves the authored source is not timestamp-jittered: all 14,315 video pictures span 596.416666 seconds with every adjacent presentation timestamp separated uniformly by either 0.041666 or 0.041667 seconds at exact 24 fps. The compatibility checker also retains a strict pass at 720x480, frame-rate code two, 597 I, 4,176 P and 9,542 B pictures with 48 kHz stereo MPEG Layer II audio. The observation is consistent with the already captured two-second controls, whose three largest decoder-limited display intervals recur at GOP picture ordinals eleven, 23 and 35 and reach 5,968,512 decoder cycles or 99.475 milliseconds despite zero error flags and complete picture counts. Uniform source timing plus continuing audio sync therefore points to transient decoder/presentation lateness that repeats the prior frame, not accumulating timeline drift; the final long-run snapshot is still required to quantify its frequency and exclude a worse high-motion or terminal failure.

#### Next Steps:

Continue the current soak without pausing, replaying or triggering a screenshot. Note whether the repeated-frame effect becomes more obvious during the high-motion sequence near 7:22, smooth camera motion or rolling credits, and whether audio remains synchronized throughout. After the full 9:56 reaches its natural end, report crackle, dropout, drift, visible corruption, the repeated-frame behavior and USER, DISK and POWER, then leave the final image loaded for schema-eight capture before any other input.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 449 COMMIT Unreleased f2b2e02 2026-08-24T07:05:26-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Complete the six-case input-envelope failure sweep with explicit truncated-stream rejection and immediate known-good recovery.

#### Outcome:

Without rebooting after the corrected 50 fps pair, the user loaded `15_bad_truncated.mpg`; it settles on a blank screen with USER blinking eight times, DISK solid off and POWER solid on, the same explicit decoder-failure indication as the unsupported geometry cases rather than ordinary success or a wedge. Immediate return to `00_good_480p_48k.mpg` passes like the established controls. The untouched 800x600 recovered-control capture is 104,740 bytes at SHA-256 `cd77217789074dbe3273f773dbf6723e0e62014e065ea7894bb3ea4402578393`. Its schema-eight telemetry reports all 582,742 accepted transport bytes, 44 associated timestamps, seventeen reference plus 31 B pictures, all 48 pictures displayed and 47 swaps. Sequence end and presentation completion are true; aggregate errors are zero, audio underrun and PCM protocol error are false, all decoder, presentation and destination errors are clear, and no decode, reorder, scratch, promotion, future-reference or terminal-boundary work remains at the normal quiet reason-one snapshot. First presentation occurs at 2,430,404 cycles, the final picture at 1.961 seconds and quiet completion at 2.057 seconds, with delivered cadence 24.469 frames per second. All six intended failure cases have now failed visibly without wedging the MiSTer, and every one has recovered immediately to a telemetry-clean 48 kHz control without reboot.

#### Next Steps:

Power-cycle once, set Audio Test to Off and run only `20_bbb_full_48k.mpg` through its complete 9:56 duration. Check opening audio-video alignment, ordinary scene transitions, the high-motion sequence near 7:22, credits and the final audio tail; report any crackle, dropout, progressive drift, visible stutter or corruption and all three terminal LEDs. Leave the final image loaded for a schema-eight capture. Do not replay the soak or any other file before that capture.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 448 COMMIT Unreleased f2b2e02 2026-08-24T07:02:00-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Hardware-qualify the corrected rejection of the 50 fps envelope case and immediate recovery to the known-good 48 kHz control.

#### Outcome:

With the exact `f2b2e02` helper active and without rebooting, the user ran `14_bad_rate_50.mpg`; it now behaves like the other helper-side failures, showing a black screen with no sound and USER, DISK and POWER all off rather than playing to ordinary success. The user immediately selected `00_good_480p_48k.mpg` without rebooting and reports perfect playback, with USER and POWER solid on and DISK blinking eleven times. The untouched 800x600 recovered-control capture is 104,786 bytes at SHA-256 `56bc682f106ff0b1b8363f4046d5b63299316d5fab4822b6332be63cf1174857`. Schema-eight telemetry proves clean re-arm after the new preflight rejection: all 582,742 transport bytes are accepted, 44 timestamps associate, seventeen reference plus 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen and presentation completes. Aggregate error flags are zero, audio underrun and PCM protocol error are false, every decoder, presentation and destination error is clear, and the quiet reason-one snapshot has no pending scheduler state. First presentation occurs after 2,431,574 decoder cycles, the final picture after 1.957 seconds and quiet completion after 2.057 seconds; delivered cadence is 24.530 frames per second. This passes the corrected fifth failure-and-recovery pair and hardware-accepts the conservative maximum-30-fps runtime boundary.

#### Next Steps:

Without rebooting, run only `15_bad_truncated.mpg` for no more than ten seconds and report the screen, sound and USER, DISK and POWER states. It must fail without claiming ordinary success or wedging the menu. Immediately select `00_good_480p_48k.mpg` again without rebooting and report alignment, sound, picture and all three LEDs, leaving the final image loaded for one last recovered-control capture. Do not start `20_bbb_full_48k.mpg` until this sixth and final failure pair passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 447 COMMIT Unreleased f2b2e02 2026-08-24T06:57:42-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Install the exact helper-side H.262 rate preflight with a byte-verified rollback while leaving the accepted FPGA image and qualification media unchanged.

#### Outcome:

Read-only retrieval first confirmed `/media/fat/linux/MediaPlayer_Helper` at the accepted 361,452-byte SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` and `/media/fat/MediaPlayer.rbf` unchanged at 4,126,828-byte SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`. Candidate `f2b2e02` was uploaded as `/media/fat/linux/MediaPlayer_Helper.stage.f2b2e02`, marked executable, retrieved and compared byte-for-byte at SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58` before any active-name mutation. The current helper was then preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-rate-gate.3814243` and the verified stage promoted. Independent post-promotion retrieval reproduces the candidate hash for the active mode-0755 helper and the predecessor hash for the rollback. The RBF remains byte-identical, as do `00_good_480p_48k.mpg` at SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5` and `14_bad_rate_50.mpg` at SHA-256 `6a698ada56937d19a4b1215f3f79f9ee6a4f7a9e46a9305119b6956c07aa8fcb`. Main and every other media file were untouched, and no playback or reboot occurred during installation.

#### Next Steps:

Without rebooting, run only `14_bad_rate_50.mpg` and wait no more than ten seconds. It must return promptly without displaying the video or producing the ordinary successful USER-solid, DISK-eleven-blink and POWER-solid combination; report the screen, sound and all three LEDs. Then immediately select `00_good_480p_48k.mpg` without rebooting and report alignment, sound, picture and all three LEDs, leaving its final image loaded for launch-free capture. Do not run `15_bad_truncated.mpg` or `20_bbb_full_48k.mpg` until this corrected rejection-and-recovery pair passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 446 COMMIT Unreleased f2b2e02 2026-08-24T06:48:23-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Close the recovered-control half of the unexpected 50 fps success and define the conservative release-boundary correction.

#### Outcome:

The user immediately replayed `00_good_480p_48k.mpg` after the unexpectedly successful rate-code-six stream and reports normal playback with USER and POWER solid on and DISK blinking eleven times. The launch-free recovered-control capture is 104,769 bytes at SHA-256 `c96ccf4db6e5f39434e12d881aca4241e6ef8510cc662ee07a0800f867577006`; schema-eight telemetry reports the complete 48-picture, 47-swap control with zero aggregate, decoder, presentation or audio errors and normal quiet completion. Commit `f2b2e02` now makes the helper's runtime boundary match the offline checker without changing RTL, Main, media or the transport protocol. A read-only first pass incrementally scans only the selected H.262 elementary video stream, preserves scanner state across Program Stream PES boundaries, validates the first sequence header and rewinds before the normal demux can emit video or decode PCM. Codes one through five remain accepted, while codes six through eight and every other out-of-range code fail clearly before either standard-output transport or an explicit PCM file receives a byte. Permanent verifier cases cover all five accepted raw codes, all three rejected raw codes, a rate-code-six sequence header split across two video PES packets and the generated `bad_rate_50.mpg` envelope case with zero-byte rejection outputs. Short and faded fixtures at 48 and 44.1 kHz pass under native and address-and-undefined-sanitized helpers with byte-identical video, exact established PCM lengths, maximum sample error two, correlation rounding to one and one clean end. The nine-case compatibility corpus retains exactly three passes and six intended failures. Bounded scheduling is unchanged for both controls, and the 596-second soak reproduces transport SHA-256 `3364dac5631d266adfb726c0bd26751e66ad069dd06c5ca23433d9c28c3df93d`, video/PTS SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and PCM SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, with its established 64,768-byte maximum PCM-free video gap and 2,048-sample maximum steady batch. Two official GCC 10.2.1 builds are byte-identical; the 361,452-byte static stripped ARM EABI5 helper has SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58`. No installed file has changed.

#### Next Steps:

Retrieve and verify the currently installed helper before mutation, preserve it under a new exact rollback name, upload helper SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58` through a commit-specific staging name and retrieve it byte-identically before promotion. Leave RBF, Main and every media file unchanged, and do not launch playback during installation. Then run only `14_bad_rate_50.mpg`; require a prompt non-successful return with no ordinary pass LEDs, immediately replay `00_good_480p_48k.mpg` without reboot and require the established aligned, crackle-free control with USER and POWER solid and DISK blinking eleven times. Leave `15_bad_truncated.mpg` and the full soak deferred until that corrected fifth pair passes.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 445 COMMIT Unreleased 3814243 2026-08-24T06:44:59-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Record the unexpected ordinary success of the nominally unsupported 50 fps envelope case and stop qualification before changing its classification.

#### Outcome:

The user ran `14_bad_rate_50.mpg` and left its final image loaded because it appeared and sounded to play completely without issue; USER and POWER were solid on and DISK blinked eleven times, exactly the ordinary-success indication that this expected-failure case was intended not to claim. The untouched 800x600 schema-eight capture is 104,817 bytes at SHA-256 `39c966722977b69841d1913da05e5312ebdca2eda036730953a82f429d06b45d`. It confirms genuine successful playback rather than a misleading LED state: frame-rate code six is retained, all 1,071,430 accepted transport bytes arrive, 92 timestamps associate, 34 reference plus 66 B pictures decode, all 100 pictures display with 99 swaps, delivered cadence is 50.921 frames per second, audio underrun and PCM protocol error are false, aggregate, decoder, presentation and destination errors are zero, sequence end is seen and the session reaches normal quiet reason one with no pending state. The PTS presentation path explains the checker mismatch. Timestamped candidates use the 90 kHz audio-derived timeline instead of the scheduler's free-running cadence table, while `check_media_compatibility.py` still rejects codes six through eight solely because that fallback table implements only codes one through five. Hardware therefore proves this specific timestamped 50 fps file is functional, but the planned six-failure envelope has only four accepted failures so far and its policy cannot be changed from one two-second observation without a bounded decision and additional coverage.

#### Next Steps:

Do not run `15_bad_truncated.mpg` yet. Immediately replay `00_good_480p_48k.mpg` without rebooting and report alignment, sound, picture and all three LEDs so the fifth pair's recovery half is still recorded. After that control is captured, choose a new approved boundary: either keep the advertised 30 fps maximum and enforce it before ordinary hardware success, or qualify timestamped 50 fps as a separate supported Program Stream profile with sustained cadence, audio alignment and raw-M2V fallback distinctions. Do not infer support for 59.94 or 60 fps from this result.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 444 COMMIT Unreleased 3814243 2026-08-24T06:41:18-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify explicit decoder rejection and recovery for the out-of-envelope 720x576 PAL geometry case.

#### Outcome:

The user reports that `13_bad_geometry_pal.mpg` behaves exactly like the preceding geometry test: a black screen, USER blinking eight times, DISK solid off and POWER solid on, followed by an immediate successful `00_good_480p_48k.mpg` replay without reboot. The launch-free recovered-control capture is 104,787 bytes at SHA-256 `bac9bc0944d06035259c84abf05ff7bd5cffb683955b7fb9ca7d6127608f7fd7`. Schema-eight telemetry proves the PAL-height error was cleared: aggregate flags are zero, audio underrun and PCM protocol error are false, all decoder, presentation and destination errors are clear, all 582,742 transport bytes are accepted, 44 timestamps associate, seventeen reference plus 31 B pictures decode and all 48 pictures display with 47 swaps. Sequence end, presentation complete and normal quiet reason one are true with no pending scheduler state and saturated healthy PCM activity. This accepts the fourth recovery pair and independently confirms geometry diagnostic code eight and clean next-stream re-arm for both excessive width-height and excessive-height-only cases.

#### Next Steps:

Without rebooting, run `14_bad_rate_50.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `15_bad_truncated.mpg` until this fifth pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 443 COMMIT Unreleased 3814243 2026-08-24T06:39:27-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify explicit decoder rejection and recovery for the out-of-envelope 1280x720 geometry case.

#### Outcome:

Loading `12_bad_geometry_720p.mpg` produces a black screen with USER blinking eight times, DISK solid off and POWER solid on. This is an explicit non-success diagnostic for the unsupported geometry rather than a silent wedge. The user immediately returns to `00_good_480p_48k.mpg` without rebooting and reports the same successful behavior as the established controls. The launch-free recovered-control capture is 104,724 bytes at SHA-256 `bc2ceab2ea3eab4ed419a2c0f5349f9f45582ccf0e8e70ffc4a3a1ad39cf2935`. Its schema-eight telemetry proves complete re-arm: zero aggregate flags, audio underrun and PCM protocol error false, all decoder, presentation and destination errors clear, all 582,742 transport bytes accepted, 44 timestamps associated, seventeen reference plus 31 B pictures decoded and all 48 pictures displayed with 47 swaps. Sequence end, presentation complete and normal quiet reason one are true with every pending scheduler state clear and saturated healthy PCM activity. This accepts the third recovery pair and proves that geometry error code eight is confined to the invalid stream and cleared by the next download start.

#### Next Steps:

Without rebooting, run `13_bad_geometry_pal.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `14_bad_rate_50.mpg` until this fourth pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed
