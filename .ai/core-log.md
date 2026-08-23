## 352 COMMIT Unreleased 6cfad2c 2026-08-22T18:55:40-07:00

#### Coming From:

Unreleased 902f367

#### Purpose:

Restore the accepted seed-nine ALM packing setting after the isolated high-effort experiment increased logic and reduced decoder timing margin.

#### Outcome:

Commit `6cfad2c` changes only `ALM_REGISTER_PACKING_EFFORT` from the rejected `HIGH` value back to the accepted `MEDIUM` value. The resulting `MediaPlayer.qsf` is byte-equivalent to accepted source commit `873a962`, preserving seed nine, all decoder RTL and the complete diagnostic architecture. The connected MiSTer was never changed by the rejected experiment and still held the exact 4,212,728-byte accepted seed-nine RBF; retrieving it reproduced SHA-256 `96c7e815ac2f5d47501184b2da07c7f1aef824ed4f689c2c70998cafc88adb0a`, and that verified image has replaced the rejected build in local `output_files` without another upload.

#### Next Steps:

Treat the accepted medium-packing seed-nine source and RBF as restored. Do not retry the global high-packing setting; continue logic-reduction work only under a separately approved boundary, with repeated MPEG lookup-table storage as the next candidate and the complete diagnostic architecture retained.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
## 351 COMMIT Unreleased 902f367 2026-08-22T18:42:36-07:00

#### Coming From:

Unreleased 873a962

#### Purpose:

Test whether higher Quartus ALM register-packing effort can recover logic while preserving the accepted seed-nine decoder and its complete diagnostic architecture.

#### Outcome:

Commit `902f367` changes only `ALM_REGISTER_PACKING_EFFORT` from `MEDIUM` to `HIGH` and leaves the seed-nine RTL, memory topology and complete diagnostic architecture unchanged. The incremental smart compile skips synthesis and completes in 10 minutes 28 seconds with zero errors and 19 warnings. It preserves 3,228,103 memory bits, 408 RAM blocks and 65 DSP blocks, but logic increases from 34,861 to 34,884 ALMs while registers decrease from 51,835 to 51,718. Every timing category remains positive, although decoder setup narrows from plus 0.160 ns to plus 0.113 ns; HDMI setup is plus 0.371 ns, HPS setup plus 1.313 ns, video setup plus 6.692 ns, hold plus 0.245 ns, recovery plus 3.959 ns, removal plus 0.649 ns and pulse width plus 1.122 ns. The 4,188,268-byte RBF has SHA-256 `c61b274a5b7c0cf783fcdc5cda8e33f7be61ca9e6c93b0bfbe18610fa6229dab`. Higher packing therefore costs 23 ALMs and 0.047 ns of the narrow decoder margin instead of recovering logic, so the artifact is rejected and was not uploaded.

#### Next Steps:

Restore `ALM_REGISTER_PACKING_EFFORT` to the accepted `MEDIUM` value, keep seed nine and all RTL and diagnostics unchanged, and do not hardware-test the rejected high-packing artifact. Treat the result as evidence that Quartus's theoretical dense-packing recovery is not available through this global effort knob on the current design; investigate the repeated MPEG lookup tables as the next low-risk logic-reduction candidate only after a separate proposal is approved.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 350 COMMIT Unreleased 873a962 2026-08-22T18:31:11-07:00

#### Coming From:

Unreleased 873a962

#### Purpose:

Hardware-qualify the timing-clean seed-nine residual-store optimization against the essential v0.6.0 playback gate.

#### Outcome:

The exact 4,212,728-byte seed-nine RBF from Entry 349, SHA-256 `96c7e815ac2f5d47501184b2da07c7f1aef824ed4f689c2c70998cafc88adb0a`, was installed persistently on the connected MiSTer and retrieved byte-for-byte identical before testing. The P-skip and motion stream accepts all 180,948 bytes, completes two reference pictures and one display swap with zero errors and zero cadence outliers. The B-prediction stream accepts all 185,054 bytes, completes three reference plus two B pictures, five displays and four swaps, reaches sequence-end quiet and reports zero errors and zero outliers. The repeated multi-slice stream completes the same three-reference plus two-B count, reaches sequence-end quiet with zero errors and zero outliers, and correctly accepts 185,394 transport bytes for its odd 185,393-byte file because the established 16-bit ingress supplies one pad byte. The squirrel stress clip accepts all 2,603,570 bytes, completes 121 reference plus 239 B pictures, reaches sequence-end quiet and presentation complete with zero errors and zero cadence outliers; its eight-bit display and swap counters wrap from 360 and 359 to 104 and 103 as established, and the corrected 359-interval rate is 23.991197 fps. The user watched the stress clip and reports that the squirrel sequence looked perfect. Seed nine therefore passes hardware without decoder, cadence, presentation or terminal regression, completing Stage 1 while recovering 130 RAM blocks from the v0.6.0 baseline.

#### Next Steps:

Treat source commit `873a962`, metadata commit following this entry and the currently installed seed-nine RBF as the accepted post-v0.6.0 residual-store baseline. Preserve the clean Quartus state and the rejected seed-eight state until routine archival is approved. Begin substantive v0.7.0 work only under a new approved boundary, retaining the four essential streams and the exact 408-block topology as regression gates.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 349 COMMIT Unreleased 873a962 2026-08-22T18:13:23-07:00

#### Coming From:

Unreleased fca45b3

#### Purpose:

Try one final fully clean fitter seed for the unchanged Stage 1 residual-store design.

#### Outcome:

Commit `873a962` changes only the Quartus fitter seed from eight to nine and leaves the RTL and simulations unchanged. A fully clean Quartus 17.0.2 compile from empty build directories completes in 12 minutes 17 seconds with zero errors and 154 warnings. The shared array remains exactly 65,536 by 16 bits, both descriptor tables remain at 1,024 entries, and the Stage 1 resource result is preserved at 3,228,103 block-memory bits and 408 RAM blocks, with 34,861 ALMs, 51,835 registers and 65 DSP blocks. Seed nine closes every timing category: HDMI setup is plus 0.311 ns, decoder setup plus 0.160 ns, HPS setup plus 1.601 ns, video setup plus 6.729 ns, hold plus 0.242 ns, recovery plus 3.973 ns, removal plus 0.599 ns and pulse width plus 1.122 ns, all with zero total negative slack. The 4,212,728-byte RBF has SHA-256 `96c7e815ac2f5d47501184b2da07c7f1aef824ed4f689c2c70998cafc88adb0a` and is the first deployable artifact of the reduced-store cycle.

#### Next Steps:

Install only the exact seed-nine RBF identified above on the connected MiSTer, verify the persistent copy byte-for-byte, and run the four essential v0.6.0 playback files. Record hardware acceptance in a new entry because this build entry is now settled; mark the Stage 1 optimization passed only if all four streams retain the accepted playback behavior without decoder, cadence, presentation or terminal regressions.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 348 COMMIT Unreleased fca45b3 2026-08-22T17:55:50-07:00

#### Coming From:

Unreleased 208d48e

#### Purpose:

Select fitter seed eight for the unchanged Stage 1 residual-store design and seek a timing-clean hardware-validation artifact.

#### Outcome:

Commit `fca45b3` changes only the Quartus fitter seed from ten to eight and leaves the RTL and tests unchanged. A fully clean Quartus 17.0.2 compile from empty build directories completes in 12 minutes 31 seconds with zero errors and 155 warnings, infers the shared array exactly at 65,536 by 16 bits and both descriptor tables at 1,024 entries, and preserves the Stage 1 resource target at 3,228,103 block-memory bits and 408 RAM blocks. The fit uses 34,780 ALMs, 51,821 registers and 65 DSP blocks. Decoder setup is plus 0.338 ns, video setup plus 7.515 ns and HPS setup plus 1.980 ns; hold is plus 0.249 ns, recovery plus 3.832 ns, removal plus 0.573 ns and pulse width plus 1.122 ns. The untouched HDMI PLL clock nevertheless misses setup by 0.127 ns with 1.429 ns total negative slack, so seed eight fails the all-positive gate. The 4,213,508-byte RBF has SHA-256 `71ce52da8c677f6ccc2087f1bbe4a6fd52cad4e155305443ec2b792c4d346026`; it was not uploaded and the connected MiSTer remains on its previously accepted build.

#### Next Steps:

Stop this attempt as agreed and do not hardware-test or distribute the seed-eight artifact. Preserve the reports as evidence that the reduced 408-block topology is stable across seeds ten and eight, while the framework HDMI path remains placement-sensitive. Before another build, obtain approval for a new commit boundary choosing either the next clean fitter-seed candidate or a targeted HDMI timing-closure change; keep the decoder RTL and already-passing functional regressions unchanged.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---
## 347 COMMIT Unreleased 208d48e 2026-08-22T17:40:04-07:00

#### Coming From:

v0.6.0 26805e8

#### Purpose:

Right-size the shared spatial-residual store while preserving the complete hardware-qualified v0.6.0 MPEG-2 decoding envelope.

#### Outcome:

Commit `208d48e` halves each physical residual bank from 1,024 to 512 descriptor blocks, narrows each bank slot from ten to nine bits and the shared sample address from seventeen to sixteen bits, halves both descriptor tables to 1,024 entries, and adds simulation-only row-capacity, address-bank, capture-versus-execution and mutually exclusive P/B writer checks. A deterministic focused regression fills both banks to the complete supported maximum of 270 ordered descriptors, verifies all 34,560 sample writes and the four bank-boundary samples, then proves descriptor 271 raises the expected error without writing. The focused P and B regressions retain exact Icarus cycle and sample counts with zero errors, and the generic live B-picture soak completes with exact publication, persistence and swap counts and zero decoder, prediction, writer or presentation errors. Quartus infers the shared array exactly at 65,536 by 16 bits and both descriptor tables at 1,024 entries. Compared with the qualified v0.6.0 baseline, block-memory use falls from 4,306,375 to 3,228,103 bits and from 538 to 408 RAM blocks, recovering 1,078,272 bits and 130 M10Ks: 128 from the shared array and two from the descriptor tables. The first incremental seed-ten compile and a preserved fully clean seed-ten retry are byte-identical at RBF SHA-256 `1094210440467c558a88e1788d50229256a437a83ae5fb7e234bcdd6da8e5ee6` and reproduce the same fit. Decoder setup is plus 0.184 ns, video setup plus 8.598 ns, HPS setup plus 0.732 ns, hold plus 0.257 ns, recovery plus 3.659 ns, removal plus 0.533 ns and pulse width plus 1.122 ns, but the untouched placement-sensitive HDMI framework clock misses setup by 0.083 ns with 1.315 ns total negative slack. The artifact is therefore not deployable and was not installed even though the functional and resource objectives pass.

#### Next Steps:

Obtain approval to add a fitter-seed change to this cycle and perform one fully clean seed-eight build, which is the strongest documented next candidate because it previously closed the same HDMI path at plus 0.368 ns. Preserve commit `208d48e` and all functional tests unchanged, require the exact 408-block memory topology and positive timing in every category, and stop without hardware deployment if seed eight fails. If it closes, resolve the seed setting in source and metadata, upload only that exact timing-clean RBF to the connected MiSTer, then run the four essential v0.6.0 playback files before marking this pre-v0.7.0 optimization passed.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_p_motion_residual_raster_engine.sv
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- tools/streams/tb_h262_p_intra_macroblocks.sv
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_residual_store_capacity.sv
- tools/streams/run_h262_residual_store_capacity.sh

#### Status:

- [ ] Built
- [ ] Passed

---
## 346 VERSION v0.6.0 26805e8 2026-08-22T09:18:14-07:00

#### Coming From:

Unreleased ae51759

#### Purpose:

Record the verified publication of the hardware-qualified real-stream MPEG-2 playback milestone as pre-release v0.6.0.

#### Outcome:

GitHub published `MiSTer Media Player v0.6.0` at 2026-08-22T09:18:14-07:00 as a non-draft pre-release at `https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.6.0`. Annotated tag object `2f69a48d91815faae7a3cc14d837d431ee84dcd2` peels to the exact audited release commit `26805e8c93710189507330c339edcb1304991b9a`; synthesized source remains baseline `b64ec6a91a6986a124b86765a9817b809c8948a1`. The online release body is byte-for-byte identical to committed `docs/RELEASE_NOTES_v0.6.0.md` at SHA-256 `dbc49e9c5fdba0ddd00bd24cf6b6120b32ad03016d232829ed85301e36ba2b48`. The sole uploaded asset is `MediaPlayer_20260822.rbf`, reported uploaded as 4,455,376 bytes; an independent GitHub download reproduces SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10` and is byte-identical to the packaged, clean-build and preserved incremental images. This closes the seven-step v0.6.0 release plan with the accepted 60 MHz decoder, mixed-width 32 KiB ingress, native frame-rate codes one through three, focused four-stream gate, and full-length visual qualification intact.

#### Next Steps:

Treat v0.6.0 as the immutable published baseline, retain the external release package and preserved seed-ten build until routine archival is explicitly approved, and resume future development under a fresh Unreleased boundary. Any new decoder, cadence, transport, audio, control or DVD work belongs after this version boundary and must not alter the `v0.6.0` tag or release asset.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 345 COMMIT Unreleased ae51759 2026-08-22T09:09:58-07:00

#### Coming From:

Unreleased ae51759

#### Purpose:

Perform the final v0.6.0 release audit and establish the exact commit for the annotated release tag as the fifth step of the approved plan.

#### Outcome:

The final audit passes at synchronized local, tracking, and GitHub commit `7e2e8811b5e22a37967c30d2e7d900a4a2508a8d` with a clean tracked worktree. Every change after synthesized baseline `b64ec6a91a6986a124b86765a9817b809c8948a1` is confined to `.ai/core-log.md`, `CHANGELOG.md`, `README.md`, and `docs/RELEASE_NOTES_v0.6.0.md`; no Quartus, RTL, top-level, QSF, QPF, QIP or framework source differs. The protected README section remains exactly 5,540 bytes at SHA-256 `c86635095cfee8c36636802872e75932580309a3cb58d6513a44758b43d515b3`. Changelog date and artifact identity, release-note baseline and qualification figures, README links, supported-format boundary and FFmpeg recipe all agree. The packaged RBF passes `SHA256SUMS`, retains its exact 4,455,376-byte size, and is byte-identical to both clean and incremental accepted outputs. No local tag, remote tag, or GitHub release named `v0.6.0` exists, so the name is available. The metadata commit resolving this audit is the exact tag target for step six.

#### Next Steps:

Have the user create annotated tag `v0.6.0` at the exact post-audit metadata commit reported with this entry, push that tag, and publish the GitHub pre-release titled `MiSTer Media Player v0.6.0` using `docs/RELEASE_NOTES_v0.6.0.md`, attaching only the verified `MediaPlayer_20260822.rbf` binary. Make no repository commit between this audit and tag creation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 344 COMMIT Unreleased ae51759 2026-08-22T09:04:12-07:00

#### Coming From:

Unreleased ae51759

#### Purpose:

Package and independently verify the qualified v0.6.0 RBF as the fourth step of the approved release plan.

#### Outcome:

The external directory `/run/media/vash/GIT/MiSTer-Media-Player-v0.6.0-release-20260822` now contains `MediaPlayer_20260822.rbf`, `SHA256SUMS`, and local human-readable `RELEASE_INFO.txt` metadata. The date-coded RBF is exactly 4,455,376 bytes, passes its checksum file at SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`, and is byte-for-byte identical to both the current clean `output_files/MediaPlayer.rbf` and the preserved accepted incremental image. The metadata identifies the required `v0.6.0` annotated tag, `MiSTer Media Player v0.6.0` pre-release title, synthesized baseline `b64ec6a`, and the sole binary asset that must be uploaded. The package remains outside the Git worktree and no generated artifact was committed.

#### Next Steps:

Proceed to step five by auditing the complete online release documentation, protected README section, repository synchronization, absence of a `v0.6.0` tag or release, and packaged asset one final time, then identify the exact commit the user should tag in step six. No rebuild is necessary because packaging preserved the already built and hardware-accepted binary exactly.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 343 COMMIT Unreleased ae51759 2026-08-22T08:55:25-07:00

#### Coming From:

Unreleased 5f09e92

#### Purpose:

Finalize the public README for v0.6.0 and add the accepted user-facing FFmpeg conversion command as the third step of the approved release plan.

#### Outcome:

Commit `ae51759` presents v0.6.0 as the current published milestone, links the new release notes, updates remaining qualification and diagnostic wording, and adds the exact no-frame-counter FFmpeg command previously used for the accepted full Big Buck Bunny conversion. The command forces 720x480 square-pixel 4:2:0 elementary video at exact 24 fps with two B pictures and a strict 24-picture GOP, preserves source aspect ratio with black padding, removes audio, and includes a shell guard that appends the required H.262 sequence-end code only when FFmpeg omits it. A short generated input verifies that the published command produces progressive 720x480 `yuv420p` MPEG-2 at exact 24 fps and terminates in `000001b7`. The protected AI-assisted-development section remains exactly 5,540 bytes and byte-for-byte identical at SHA-256 `c86635095cfee8c36636802872e75932580309a3cb58d6513a44758b43d515b3`, and the README commit was pushed.

#### Next Steps:

Proceed to step four by copying the already qualified clean `MediaPlayer.rbf` to the date-coded release filename, verify its exact size and checksum against both accepted build states, and stage a release-package directory without committing the generated binary to the source tree. No build or hardware validation is required for this README-only commit.

#### Files Modified:

- README.md

#### Status:

- [ ] Built
- [ ] Passed

---
## 342 COMMIT Unreleased 5f09e92 2026-08-22T08:50:43-07:00

#### Coming From:

Unreleased fe0393d

#### Purpose:

Create the final v0.6.0 release-notes document as the second step of the approved seven-step release plan.

#### Outcome:

Commit `5f09e92` adds a self-contained v0.6.0 release-notes document covering the real-stream milestone, its qualified raw progressive 4:2:0 input boundary, native frame-rate codes one through three, decoder and compressed-ingress changes, corrected presentation behavior, exact clean-build timing and resource figures, focused and full-length MiSTer validation, known limitations, and the required `MediaPlayer_20260822.rbf` size and checksum. It distinguishes implementation limits from H.262 limits, identifies `b64ec6a` as the synthesized source baseline, states that later documentation does not alter the qualified RTL, records the four focused stream checksums, and notes the formally exposed `.ai` workflow. All stated artifact, hardware and timing figures were checked against the accepted logs and current clean RBF before the documentation commit was pushed.

#### Next Steps:

Proceed to step three by changing the README from release-candidate language to the final v0.6.0 published-milestone presentation, linking these release notes and adding the user-facing FFmpeg conversion command requested in place of a Python recipe. Preserve the 5,540-byte AI-assisted-development section byte-for-byte; no build or additional hardware validation is required for this release-notes-only commit.

#### Files Modified:

- docs/RELEASE_NOTES_v0.6.0.md

#### Status:

- [ ] Built
- [ ] Passed

---
## 341 COMMIT Unreleased fe0393d 2026-08-22T08:46:15-07:00

#### Coming From:

Unreleased a6e25b4

#### Purpose:

Write the final v0.6.0 milestone entry in the public changelog as the first step of the approved seven-step release plan.

#### Outcome:

Commit `fe0393d` replaces the empty Unreleased placeholder with a dated v0.6.0 milestone recording the accepted real-stream decoder, corrected presentation and terminal behavior, expanded motion-vector range, 60 MHz decode and mixed-width 32 KiB ingress, native frame-rate codes one through three, clean-build timing and resources, focused and full-length hardware qualification, release artifact identity, and explicit implementation limits. The Unreleased heading remains available for later work, the documentation passes whitespace and structure checks, and the commit was pushed to the online repository. The user's revised release plan drops the deferred Python conversion recipe and instead reserves a plain FFmpeg command for the later README step; this commit changes no README content.

#### Next Steps:

Proceed to step two by writing `docs/RELEASE_NOTES_v0.6.0.md` from the same qualified seed-ten evidence, including supported inputs, known limits, build and hardware results, and the exact release artifact identity. No build or additional hardware validation is required for this changelog-only commit.

#### Files Modified:

- CHANGELOG.md

#### Status:

- [ ] Built
- [ ] Passed

---
## 340 COMMIT Unreleased a6e25b4 2026-08-22T08:32:00-07:00

#### Coming From:

Unreleased 036a717

#### Purpose:

Update the public README with the current v0.6.0 release-candidate status while preserving the newly published AI-assisted-development section verbatim.

#### Outcome:

Commit `a6e25b4` updates only README content outside the protected AI-assisted-development range. It distinguishes v0.5.0 as the current published release from v0.6.0 as the hardware-qualified release candidate, summarizes the candidate's 60 MHz decoder and mixed-width 32 KiB ingress, documents paced frame-rate codes one through three and the unsupported higher codes, records the byte-identical clean and incremental RBF, timing closure, focused hardware regressions and full-length visual qualification, and brings the release, architecture, build, diagnostic and roadmap text forward to the accepted decoder baseline. The protected section remains exactly 5,540 bytes and byte-for-byte identical at SHA-256 `c86635095cfee8c36636802872e75932580309a3cb58d6513a44758b43d515b3`, and the documentation commit was pushed to the online repository.

#### Next Steps:

No build or hardware validation is required because this commit changes only Markdown documentation. Use the README as the current public v0.6.0 candidate-status summary, preserve the AI-assisted-development section verbatim, and update the changelog and release notes when the user approves final v0.6.0 publication.

#### Files Modified:

- README.md

#### Status:

- [ ] Built
- [ ] Passed

---
## 339 COMMIT Unreleased 036a717 2026-08-22T08:24:43-07:00

#### Coming From:

Unreleased b64ec6a

#### Purpose:

Publish the user's supplied AI-assisted-development section verbatim in the repository README.

#### Outcome:

Commit `036a717` copies the complete 5,540-byte `AI-assisted development in v0.6.0.md` attachment into the top-level `README.md` immediately before the existing Contributing section. A direct byte-range comparison proves the published section is identical to the supplied content, including every heading, paragraph, list item, inline code span, URL, emphasis marker and its intentional whitespace-only indented line; both ranges have SHA-256 `c86635095cfee8c36636802872e75932580309a3cb58d6513a44758b43d515b3`. The attachment was treated strictly as content rather than as project instructions, and the documentation commit was pushed to the online repository.

#### Next Steps:

No build or hardware validation is required because this commit changes only Markdown documentation. Preserve the section verbatim in future README edits unless the user supplies a revision.

#### Files Modified:

- README.md

#### Status:

- [ ] Built
- [ ] Passed

---
## 338 COMMIT Unreleased b64ec6a 2026-08-22T08:15:10-07:00

#### Coming From:

Unreleased b64ec6a

#### Purpose:

Qualify the timing-clean seed-ten release candidate with a preserved incremental state, an independent clean build and the four-file essential hardware regression suite.

#### Outcome:

The complete accepted incremental build state was moved intact to `/run/media/vash/GIT/mmp_seed10_incremental.iRW65u`, including `db`, `incremental_db`, `output_files` and `phase1p_timing_reports`, and its RBF retained SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`. Quartus then rebuilt the identical seed-ten source completely from scratch in 12 minutes 36 seconds with zero errors. The clean result is byte-for-byte identical to the preserved incremental RBF and reproduces every implementation figure exactly: plus 0.303 ns global setup, plus 0.386 ns decoder setup, plus 8.066 ns video setup, plus 0.244 ns hold, plus 3.706 ns recovery, plus 0.768 ns removal and plus 1.122 ns pulse width, with 34,565 ALMs, 50,960 registers, 4,306,375 memory bits, 538 RAM blocks and 65 DSP blocks. The clean artifact then passes all four essential hardware regressions. The P-skip/motion case accepts all 180,948 bytes and completes both pictures; B-prediction accepts all 185,054 bytes and completes all five pictures; multi-slice completes all five pictures with zero errors while correctly accepting one transport pad byte for its odd 185,393-byte length; and the 15-second squirrel clip accepts all 2,603,570 bytes, completes 121 reference plus 239 B pictures, reaches sequence-end quiet at a corrected 23.991197 fps and reports zero errors and zero cadence outliers. Its eight-bit display and swap counters wrap from 360 and 359 to 104 and 103 as established. One initial screenshot was read before its PNG write completed, but a delayed retry passed and exposed no core failure.

#### Next Steps:

Use the current clean RBF or the preserved incremental RBF interchangeably for release because they are the exact same binary, and retain the preserved build directory until the release is tagged and packaged. Treat the four essential hardware regressions, the native-23.976 telemetry gate and the full Emperor visual run as the v0.6.0 decoder baseline. A later tooling cleanup may teach the generic cadence runner about 16-bit odd-byte padding, eight-bit counter wrap and partially written screenshots, but those automation limits do not block the core release.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 337 COMMIT Unreleased b64ec6a 2026-08-22T07:52:35-07:00

#### Coming From:

Unreleased b64ec6a

#### Purpose:

Record final human acceptance of native `24000/1001` playback on the exact full-length Emperor movie.

#### Outcome:

The user manually selects the existing 642,033,469-byte `40. 2000 - The Emperor's New Groove.m2v` on the MiSTer using the timing-clean seed-ten RBF from commit `b64ec6a` and reports that all tests pass, the video looks perfect, and any slowdown or speedup is imperceptible. Its motion quality is judged as good as the already accepted native-rate Big Buck Bunny baseline. This closes the original accelerated-playback defect with both the Entry 336 telemetry result of 120 pictures at 23.964000 fps and direct human observation of the exact affected movie. One tooling boundary is also established: automatic MGL injection of this 642 MB file remains on a black screen with a slowly advancing loading bar, while ordinary manual file selection uses the working streaming path and plays correctly; that MGL behavior is not a decoder or cadence failure.

#### Next Steps:

Treat direct frame-rate code one, exact 24 fps and 25 fps presentation as accepted for the v0.6.0 decoder boundary. Preserve manual file selection for full-length regression viewing, keep the deterministic short hardware telemetry gate for automation, and leave frame-rate codes four through eight for explicit future support rather than silently treating them as paced.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 336 COMMIT Unreleased b64ec6a 2026-08-22T07:27:40-07:00

#### Coming From:

Unreleased 8517927

#### Purpose:

Find a timing-clean placement for the unchanged native-23.976-fps design by retrying its incremental Quartus fit with seed ten.

#### Outcome:

Seed twelve leaves the decoder positive but misses a standing global framework path by 0.094 ns, while seed eleven closes that placement differently but misses the 60 MHz decoder by 0.131 ns. Commit `b64ec6a` changes only the reproducible fitter seed from eleven to ten and reuses synthesis exactly as intended. The incremental fit completes in 10 minutes 27 seconds with zero errors and positive timing at plus 0.303 ns global setup, plus 0.386 ns decoder setup, plus 8.066 ns video setup, plus 0.244 ns hold, plus 3.706 ns recovery, plus 0.768 ns removal and plus 1.122 ns pulse width. It uses 34,565 ALMs, 50,960 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,455,376-byte RBF has SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`, matches after persistent installation, and is the only image from this cadence cycle installed on the MiSTer. A temporary 720-by-480 native-23.976 control initially demonstrated that raw FFmpeg output requires the standard sequence-end marker to flush its final reorder state; after the marker was appended, hardware accepted all 1,488,156 bytes, recognized frame-rate code one, completed all 120 pictures and 119 swaps in 4.965782 seconds at 23.964000 fps, reached sequence-end quiet and reported zero errors and zero cadence-gap outliers. The user's exact Emperor movie was then launched from its existing MiSTer path with the verified core.

#### Next Steps:

Have the user confirm that the full Emperor movie now runs at normal wall-clock speed and remains visually smooth during motion and credits. Keep frame-rate codes four through eight as explicit future support decisions; this commit deliberately adds only native `24000/1001` alongside the already accepted exact-24 and 25-fps paths.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---
## 335 COMMIT Unreleased 8517927 2026-08-22T07:13:52-07:00

#### Coming From:

Unreleased 04873f7

#### Purpose:

Find a timing-clean placement for the unchanged native-23.976-fps design by retrying its incremental Quartus fit with seed eleven.

#### Outcome:

Commit `04873f7` passes every focused and integrated simulation gate, but its incremental seed-twelve fit is not deployable. Quartus completes with zero errors and the affected 60 MHz decoder clock remains positive at plus 0.040 ns while the 40 MHz video clock remains positive at plus 7.414 ns, but a standing global framework path misses setup by 0.094 ns. Hold is plus 0.243 ns, recovery plus 3.050 ns, removal plus 0.697 ns and minimum pulse width plus 1.122 ns. The rejected 4,462,820-byte RBF has SHA-256 `1b3bbd125561b4c6d9787730db022b396ab3982009718741706b286254b5c7c1` and was not installed. Commit `8517927` changes only the reproducible fitter seed from twelve to eleven and reuses synthesis exactly as intended, but its incremental fit also fails timing: the global and decoder minimum becomes minus 0.131 ns with eleven same-clock decoder violations while video remains plus 7.069 ns. Hold is plus 0.260 ns, recovery plus 3.997 ns, removal plus 0.617 ns and pulse width plus 1.122 ns. The rejected seed-eleven fit uses 34,594 ALMs, 51,017 registers, 4,306,375 memory bits, 538 RAM blocks and 65 DSP blocks; its 4,458,208-byte RBF has SHA-256 `170c64ec789dfc3ef2d4e4d1e377db7728b70dc448e50038563ea48ea8d32341` and was not installed.

#### Next Steps:

Keep the validated cadence RTL unchanged and retry incrementally with seed ten, which is the next documented candidate and previously missed the 60 MHz decoder by only 0.073 ns before later ingress changes. Require every timing category positive and do not install either rejected seed-eleven or seed-twelve image.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 334 COMMIT Unreleased 04873f7 2026-08-22T06:30:47-07:00

#### Coming From:

Unreleased 374ef38

#### Purpose:

Add exact native `24000/1001` presentation cadence for H.262 frame-rate code one without changing decoder execution or the accepted exact-24/25-fps paths.

#### Outcome:

The presentation scheduler now supports frame-rate code one with the exact reduced 22,608-over-56,875 refresh-window credit ratio, mathematically identical to `663168 * 24000` over `40000000 * 1001`, and reseeds only when entering or leaving that reduced scale so exact-24/25 behavior remains cycle-identical. The hardware cadence profiler now recognizes code one under the same legal three-refresh diagnostic window. Focused simulation delivered 479 presentations over 1,206 windows for 23.976 fps, 240 over 603 for exact 24, and 250 over 603 for 25 fps; the profiler, transport, mixed-width FIFO, and complete 72-picture live-raster soak all passed with zero decoder or presentation errors. An untouched `374ef38` comparison proved the soak's prior 6,519,997-clock assertion was already stale while both baseline and this commit complete identically at 6,519,996 clocks, so the test-only constant was corrected without changing decoder behavior.

#### Next Steps:

Build `04873f7` incrementally from the accepted clean seed-twelve database, require positive global, decoder, video, hold, recovery, removal and pulse-width timing, install only the timing-clean image, and validate a bounded native-23.976 cadence stream plus the exact Emperor movie at correct wall-clock speed with no dropped frames.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 333 COMMIT Unreleased 374ef38 2026-08-22T06:25:25-07:00

#### Coming From:

Unreleased 374ef38

#### Purpose:

Determine whether the user's visibly accelerated playback of `40. 2000 - The Emperor's New Groove.m2v` is encoded into the file or caused by the current presentation scheduler.

#### Outcome:

No source changed. A read-only inspection of the 642,033,469-byte file on the MiSTer identifies 720-by-480 progressive Main Profile 4:2:0 video with 16:9 display aspect and direct frame rate `24000/1001`, which is H.262 `frame_rate_code` one. This is not a 29.97-fps stream, and its 0.1-percent difference from exact 24 fps cannot itself explain an obvious speedup.

The cause is explicit in the current RTL. The frontend timeline correctly recognizes rate code one and assigns its exact 15,015 quarter-90-kHz-tick duration, but `mpeg2_h262_b_presentation_scheduler.sv` declares only rate codes two and three—exact 24 and 25 fps—as cadence-supported. For every other code, `cadence_slot` is unconditionally true and the scheduler reseeds its credit at each swap window, so decoded pictures publish as soon as they are ready instead of at their encoded cadence. The user's report that the film runs fast without visible frame drops is therefore consistent with unpaced presentation and provides encouraging evidence that the decoder sustains this stream's workload; it is not evidence of correct 23.976-fps timing.

#### Next Steps:

Add native `24000/1001` cadence support as the next narrowly scoped scheduler change, using an exact rational credit step rather than treating it as 24 fps. Extend the scheduler and cadence-profiler regressions for H.262 rate code one, build incrementally, require all timing categories positive, then replay this exact movie and compare its wall-clock duration and smooth motion. Keep direct 29.97, 30, 50, 59.94 and 60 fps as separately explicit support decisions rather than silently leaving them unpaced.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---
## 332 COMMIT Unreleased 374ef38 2026-08-22T06:14:03-07:00

#### Coming From:

Unreleased 374ef38

#### Purpose:

Generate a complete, ordered v0.6.0 release-candidate hardware regression pack for the user to copy to the MiSTer and validate manually.

#### Outcome:

No source changed. The seven authoritative hardware streams were regenerated from their deterministic generators and passed their built-in geometry, syntax, pixel-model and FFmpeg-decode checks. The supplemental v0.6.0 corpus regenerated four 720-by-480 progressive 4:2:0 cases covering repeated same-row slices, dense residual traffic, mixed macroblocks and a 72-picture long GOP; its manifest records the exact FFmpeg version, commands, structure and checksums.

Two native-24-fps quality-six Big Buck Bunny controls were generated directly from `big_buck_bunny_480p_stereo.avi`: the fresh 120-picture 7:20-through-7:25 control is 1,404,944 bytes with SHA-256 `dea6b422`, and the 360-picture 7:15-through-7:30 control is 2,603,570 bytes with SHA-256 `9257ffad`, exactly reproducing the established full-scene artifact. The user's no-frame-counter, aspect-preserving full-movie recipe is included as a 14,315-picture, 78,010,162-byte endurance stream with SHA-256 `3b048a18`. A 100,000-byte mid-picture truncation of the long-GOP case is clearly labeled as an expected failure for the no-reboot recovery gate.

The assembled local folder `regression_tests_v0.6.0_rc_20260822` contains fourteen numbered normal-playback streams, the numbered expected-failure stream, `SHA256SUMS`, generator metadata, human-readable test instructions and a results template. Every normal stream passes checksum verification, has the required `000001b7` sequence end, reports the expected picture count and completes an FFmpeg decode. The truncated case intentionally lacks the end marker. Generated binary artifacts remain untracked and are not committed.

#### Next Steps:

Have the user copy the pack to the MiSTer and run files 01 through 14 in order on the already verified clean release candidate. Require ordinary completion with no freeze, corruption or abnormal ending; specifically require the P visual discriminator's four-quadrant final image, continuous squirrel/wooden-spike motion, smooth full-movie pans and credits, and clean terminal behavior. Run file 99 last, wait for its expected diagnostic/no-progress state, then load file 01 again without rebooting and require normal completion. Record the results before accepting the v0.6.0 decoder regression gate.

#### Files Modified:

None. Generated regression artifacts are intentionally untracked.

#### Status:

- [x] Built
- [ ] Passed

---
## 331 COMMIT Unreleased 374ef38 2026-08-22T05:43:51-07:00

#### Coming From:

Unreleased 374ef38

#### Purpose:

Qualify the accepted mixed-width MPEG-2 ingress image as an exact clean-build release candidate rather than relying on its incremental Quartus build.

#### Outcome:

The previous `db`, `incremental_db` and `output_files` directories were moved intact to `/tmp/mmp_clean_build.QMl28H`, and Quartus then rebuilt seed twelve completely from scratch. Full compilation completed in 13 minutes 44 seconds with zero errors. Every required timing category is positive: global and decoder setup are plus 0.049 ns, video setup is plus 7.752 ns, hold is plus 0.243 ns, recovery is plus 3.800 ns, removal is plus 0.613 ns and minimum pulse width is plus 1.122 ns. The clean fit uses 35,146 ALMs, 51,998 registers, 4,306,375 block-memory bits, 538 of 553 RAM blocks and 65 DSP blocks.

The resulting 4,463,616-byte `MediaPlayer.rbf` has SHA-256 `566ecf44d65c9d483be247ae942280d23269b7100ce0d75ef3b8a5bc4bdf2dbc`, exactly matching the previously installed incremental image that passed the focused five-second and full fifteen-second squirrel tests and the user's repeated visual inspection. Because the images are bit-for-bit identical, the MiSTer already runs the clean release-candidate bits and was deliberately not interrupted while the user tests additional converted media.

#### Next Steps:

Continue broad hardware playback testing with user-selected files on the already installed, bit-identical clean release candidate. Record any reproducible decode artefact, cadence problem, freeze or terminal failure with its source properties and timestamp. Do not rebuild or replace the image unless a new defect requires a source change.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 330 COMMIT Unreleased 374ef38 2026-08-22T05:01:06-07:00

#### Coming From:

Unreleased 374ef38

#### Purpose:

Record the user's repeated visual acceptance of the mixed-width MPEG-2 ingress fix at the exact Big Buck Bunny squirrel failure scene.

#### Outcome:

After the automated five-second dense-stream and full 7:15-through-7:30 hardware captures both report zero gap outliers, zero errors and complete picture counts, the ordinary clip is replayed for the user without acquisition interruption. The user watches the wooden-spike approach again and reports that it looks perfect. This resolves Entry 329's pending repeated visual confirmation and accepts commit `374ef38` as the fix for the clean frame drops previously visible at 7:22.

#### Next Steps:

Run the full ten-minute native-24-fps Big Buck Bunny baseline with the accepted persistent image and have the user watch for cadence stutter, dense-motion frame loss, decode artefacts, freezes and terminal behavior. Keep RAM-block reduction as a separate optimization because the validated 32 KiB ingress reservoir must not be weakened while investigating the design's 538-of-553 M10K occupancy.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 329 COMMIT Unreleased 374ef38 2026-08-22T04:33:13-07:00

#### Coming From:

Unreleased b426ba4

#### Purpose:

Deliver wide MiSTer file transfers without per-word software stalls by replacing the serializer with a native 16-bit-write and 8-bit-read asynchronous FIFO.

#### Outcome:

Commit `374ef38` removes the per-word serializer and uses Intel's native `dcfifo_mixed_widths`, retaining exactly 32 KiB while accepting consecutive 16-bit MiSTer transfers and presenting ordered 8-bit decoder bytes. The actual Intel behavioral primitive test proves low-byte-first ordering, three back-to-back words, read-side empty and asynchronous reset; transport drains sixteen bytes, the scheduler preserves exact 24 and 25 fps cadence with a minimum two-window gap, and profiler schema four passes with checksum `e82b643d`. The exact quality-six dense stream passes the full raster replay at 134,979,997 cycles with all 1,430,191 source bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental seed-twelve Quartus build completes in 12 minutes 55 seconds with zero errors and positive timing at plus 0.049 ns global and decoder setup, plus 7.752 ns video setup, plus 0.243 ns hold, plus 3.800 ns recovery, plus 0.613 ns removal and plus 1.122 ns pulse width. It uses 35,146 ALMs, 51,998 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,463,616-byte RBF has SHA-256 `566ecf44d65c9d483be247ae942280d23269b7100ce0d75ef3b8a5bc4bdf2dbc`, matches after persistent installation and needs no clean rebuild. After rebooting the MiSTer to clear Entry 328's wedged loader, the five-second hardware run presents all 120 pictures in 4.989397 seconds at 23.850578 fps with zero errors and zero gap outliers; its 1,430,192 accepted-byte count is the expected single padding byte for the odd-length source. The full 7:15-through-7:30 run accepts exactly 2,603,570 bytes, reaches sequence end and terminal quiet, decodes 121 reference plus 239 B pictures for all 360 pictures, and reports zero errors and zero gap outliers across the former 7:22 failure. Its eight-bit display and swap counters wrap to 104 and 103 as expected. The user watches the ordinary clip and reports that the issue appears fixed, pending repeated visual confirmation.

#### Next Steps:

Replay the ordinary 7:15-through-7:30 clip as often as the user needs to confirm the wooden-spike motion visually, then rerun the ten-minute Big Buck Bunny baseline with the accepted artifact. Preserve the cadence overlay as a diagnostic tool but treat its eight-bit display/swap counter wrapping and odd-length WIDE padding as acquisition-validator limitations rather than decoder failures. Investigate reducing the design's 538-of-553 RAM-block occupancy separately, without shrinking buffers whose capacity is now proven necessary for smooth dense MPEG-2 transfer.

#### Files Modified:

- rtl/mpeg2_stream_fifo.sv
- tools/streams/tb_mpeg2_stream_word_unpacker.sv

#### Status:

- [x] Built
- [x] Passed

---
## 328 COMMIT Unreleased b426ba4 2026-08-22T04:17:21-07:00

#### Coming From:

Unreleased 76326a1

#### Purpose:

Find a timing-clean placement for the proven wide-ingress design by retrying its incremental Quartus fit with seed twelve.

#### Outcome:

Commit `b426ba4` changes only the fitter seed from eleven to twelve and reuses synthesis as intended. The incremental build completes in 11 minutes 58 seconds with zero errors and positive timing at plus 0.331 ns global setup, plus 0.350 ns decoder setup, plus 8.286 ns video setup, plus 0.252 ns hold, plus 3.950 ns recovery, plus 0.800 ns removal and plus 1.122 ns pulse width. It uses 34,883 ALMs, 51,966 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,449,372-byte RBF has SHA-256 `d4d31f23f9d4405c070acc589fcbf7fcb059164b6dabd51bf7b4d96aad1c31c5`, verifies after persistent installation and proves seed twelve is a timing-clean placement. Hardware then exposes a functional ingress flaw before telemetry can run: the word unpacker asserts host wait for every accepted 16-bit word while emitting its upper byte. Although that pause lasts only one 20 MHz FPGA clock, it forces the MiSTer file loader through a software wait/retry round trip for every two bytes, so the 1,430,191-byte control does not finish loading within the acquisition window and the screenshot command cannot execute. The artifact is therefore not passed despite clean timing.

#### Next Steps:

Keep timing-clean seed twelve and replace the per-word serializer with the FPGA vendor's native mixed-width asynchronous FIFO, writing complete 16-bit host words and reading ordered 8-bit decoder bytes while asserting host wait only when the reservoir is genuinely full. Simulate the actual primitive model for byte order, consecutive words, full backpressure and reset, then rerun the focused and exact-stream regressions and build incrementally. Accept only positive timing and a real hardware load that consumes all bytes, reaches terminal quiet with zero errors and removes the 7:22 outliers.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 327 COMMIT Unreleased 76326a1 2026-08-22T03:54:46-07:00

#### Coming From:

Unreleased a25d772

#### Purpose:

Prevent host-transfer starvation in the 7:22 squirrel burst by carrying two compressed bytes per MiSTer file-I/O transaction while preserving the decoder's byte stream.

#### Outcome:

Entry 326's full 7:15-through-7:30 hardware capture localizes the visible defect to display ordinals 175, 176 and 178, exactly the user's 7:22 interval, with gaps of 149.213 ms, 66.317 ms and 82.896 ms. Commit `76326a1` enables the local MiSTer framework's standard `WIDE=1` file-transfer mode and adds a write-domain unpacker that emits the lower-addressed byte before the upper byte into the unchanged 32 KiB asynchronous FIFO while applying host wait across the second byte and downstream backpressure. The focused unpacker test proves exact byte order, consecutive transfers, reset and a three-cycle stalled high byte; transport drains all sixteen control bytes, the scheduler retains exact 24 and 25 fps cadence with a minimum two-window gap, and profiler schema four passes with checksum `e82b643d`. The quality-six dense stream passes the full raster replay at 134,979,997 cycles with all 1,430,191 bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental seed-eleven Quartus build then completes in 14 minutes with zero errors, using 34,827 ALMs, 51,970 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks, but is rejected because the 60 MHz decoder clock misses setup by 0.694 ns with total negative slack 12.266 ns. Video setup remains plus 8.184 ns, hold plus 0.260 ns, recovery plus 4.139 ns, removal plus 0.637 ns and pulse width plus 1.122 ns. The rejected 4,461,408-byte RBF has SHA-256 `0afac0e312bf7280932107c4210c9bce2c5b68ddcab898ffa6623c29c3a3d55b` and is not installed, so hardware behavior is not yet measured.

#### Next Steps:

Keep the functionally proven wide ingress unchanged and retry only the fitter with seed twelve because the source change disturbed the previously placement-sensitive 60 MHz decoder paths while every non-setup category remains positive. Rebuild incrementally and accept only zero errors with positive global, decoder, video, hold, recovery, removal and pulse-width timing. If seed twelve closes, verify and install the exact RBF, then rerun both the five-second quality-six control and full 7:15-through-7:30 hardware capture, requiring zero errors and no outliers at ordinals 175 through 178 before asking the user to inspect 7:22. If it does not close, return the decoder to its proven 54 MHz rate rather than repeatedly fitting a clock increase that hardware did not materially improve.

#### Files Modified:

- MediaPlayer_top_00.svh
- rtl/mpeg2_stream_fifo.sv
- tools/streams/tb_mpeg2_stream_word_unpacker.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 326 COMMIT Unreleased a25d772 2026-08-22T03:35:21-07:00

#### Coming From:

Unreleased a5a42f9

#### Purpose:

Find a timing-clean placement for the unchanged 60 MHz decoder design by retrying its incremental Quartus fit with seed eleven.

#### Outcome:

Commit `a25d772` changes only the fitter seed from ten to eleven and reuses synthesis as intended. The incremental Quartus build completes in 13 minutes 10 seconds with zero errors and positive timing at plus 0.296 ns global setup, plus 0.355 ns decoder setup, plus 8.030 ns video setup, plus 0.258 ns hold, plus 2.688 ns recovery, plus 0.677 ns removal and plus 1.122 ns pulse width. It uses 35,065 ALMs, 51,820 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,461,836-byte RBF has SHA-256 `15d5b3144608dbe7148ea4c2a822a714f569413f70657e8f4c8e9f8b4ff373cd` and verifies after persistent installation. Hardware remains correct but does not close the visible defect: the exact quality-six five-second control accepts all 1,430,191 bytes and presents all 120 pictures and 119 swaps with zero errors and terminal quiet, yet retains five cadence outliers and essentially unchanged 22.445238 fps delivery. A full 7:15-through-7:30 capture accepts all 2,603,570 bytes, decodes 239 B and 121 reference pictures for all 360 pictures with zero errors and terminal quiet; its eight-bit display counters wrap to 104 pictures and 103 swaps, while the three largest outliers occur at ordinals 175, 176 and 178, exactly 7.3 seconds after the clip begins and therefore at the user's 7:22 scene. Those gaps last 149.213 ms, 66.317 ms and 82.896 ms, and the largest snapshots show an empty FIFO while the decoder is ready, confirming compressed-input starvation rather than picture loss or I-frame-only presentation.

#### Next Steps:

Keep the timing-clean seed-eleven fit and 60 MHz decoder, but treat the squirrel defect as not passed. Enable the MiSTer `hps_io` interface's standard 16-bit file-transfer mode and serialize each accepted little-endian word into the existing 8-bit, 32 KiB asynchronous FIFO so each host transaction carries two compressed bytes without increasing the design's 97-percent RAM-block usage. Prove byte order, backpressure and consecutive-word handling in a focused simulation, rerun transport, scheduler, profiler and exact-stream regressions, build incrementally with seed eleven and require all timing categories positive, then rerun both the five-second quality-six control and the full 7:15-through-7:30 hardware capture before asking the user to inspect 7:22 again.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 325 COMMIT Unreleased a5a42f9 2026-08-22T03:17:24-07:00

#### Coming From:

Unreleased e5e7d86

#### Purpose:

Close the remaining dense-scene presentation deficit by raising the decoder and DDR service clock from 54 MHz to 60 MHz without changing video cadence.

#### Outcome:

Entry 324 proves that compressed-input restart latency was real but not the only bottleneck. Enlarging the FIFO improves the exact quality-six squirrel control from 20.993581 to 22.417636 fps and reduces its worst display gap from 182.371 ms to 132.634 ms, yet seven cadence outliers remain. The new largest threshold snapshot has FIFO data pending while the decoder is not ready, so further input buffering cannot close the deficit, and the fitted design already consumes 538 of 553 RAM blocks. Commit `a5a42f9` changes only the decoder and DDR service PLL output from 54 MHz to an exact 60 MHz while preserving the independent 40 MHz video clock, recalibrates profiler time units and thresholds from 54,000 to 60,000 kHz, and updates the timing extractor and profiler regression accordingly. Transport and native-rate scheduler tests remain exact, and profiler schema four passes with checksum `e82b643d`. The incremental seed-ten Quartus build finishes in 13 minutes 20 seconds with zero errors, using 34,990 ALMs, 51,852 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. Hold is plus 0.262 ns, recovery plus 3.820 ns, removal plus 0.789 ns and pulse width plus 1.122 ns, but the 60 MHz decoder clock misses setup by 0.073 ns on two paths with total negative slack 0.114 ns. The rejected 4,457,632-byte RBF has SHA-256 `fcc971e39ea20399839070c13b31d34eba9dbdcde7a7e19685e862d21fad49aa` and is not installed.

#### Next Steps:

Retry the unchanged 60 MHz design with fitter seed eleven because the seed-ten miss is only 0.073 ns and all non-decoder categories are positive. Rebuild incrementally and accept only zero errors with positive global, decoder, video, hold, recovery, removal and pulse-width timing. If the fit closes, verify and install the exact RBF, rerun the quality-six 120-picture hardware control, and require all 1,430,191 bytes, 120 pictures and 119 swaps, zero errors, terminal quiet and zero cadence outliers before handing 7:15 through 7:30 back to the user. If seed eleven still misses, inspect whether the failing pair shares a narrow combinational source before choosing another seed or a pipeline repair.

#### Files Modified:

- rtl/pll/pll_0002.v
- rtl/pll.v
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/phase1p_timing.tcl
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 324 COMMIT Unreleased e5e7d86 2026-08-22T02:57:30-07:00

#### Coming From:

Unreleased 25f05dd

#### Purpose:

Prevent dense real-content pictures from starving presentation by replacing the 256-byte HPS-to-decoder FIFO with a practical compressed-stream reservoir.

#### Outcome:

The user confirms the native-rate ending credits are completely smooth, closing the deterministic cadence symptom, but identifies a clean apparent frame skip at 7:22 as the wooden spikes approach. An exact native-rate 7:20-to-7:25 hardware control reproduces the remaining defect with all 1,430,191 bytes accepted, all 120 pictures and 119 swaps eventually presented, no error flags and nine cadence outliers; its three largest display gaps are 182.371 ms, 165.792 ms and 132.634 ms. The two largest threshold snapshots show the decoder ready while the compressed-stream FIFO is empty, and the source around that point retains a normal I/B/B/P order while individual coded pictures abruptly grow to tens of kilobytes. Lowering encode density from quality six to quality ten reduces the stream from 1,430,191 to 948,786 bytes and improves delivered cadence from 20.993581 to 22.684969 fps, but still leaves four outliers as large as 116.054 ms, confirming buffering sensitivity without providing an acceptable conversion-only repair. Commit `e5e7d86` therefore enlarges the asynchronous HPS-to-decoder FIFO from 256 bytes to 32,768 bytes without changing its clock-domain crossing or reset configuration. The exact dense scene passes the full raster replay at 134,979,997 cycles with all 1,430,191 bytes, 36 P pictures, 79 B pictures, 41 reference publications, 119 swaps and zero errors. The incremental Quartus build completes in 12 minutes 33 seconds with zero errors and positive timing at plus 0.432 ns global setup, plus 1.672 ns decoder setup, plus 8.133 ns video setup, plus 0.243 ns hold, plus 3.551 ns recovery, plus 0.702 ns removal and plus 0.462 ns pulse width. It uses 34,685 ALMs, 51,232 registers, 4,306,375 memory bits, 538 of 553 RAM blocks and 65 DSP blocks. The accepted 4,454,764-byte RBF has SHA-256 `68274574806ce74331f32f90ea82084b67c40db0f43adea45a9910f0994a5e70` and verifies after persistent installation. Hardware proves the reservoir is beneficial but insufficient: outliers fall from nine to seven, the worst gap falls from 182.371 ms to 132.634 ms and delivered cadence improves from 20.993581 to 22.417636 fps, but the new largest snapshot has compressed data pending while the decoder is not ready, exposing decode throughput as the next binding limit.

#### Next Steps:

Keep the enlarged reservoir because its hardware improvement is measured, but do not treat the squirrel defect as passed. Raise only the decoder and DDR service clock from 54 MHz to the PLL-compatible 60 MHz while preserving the independent 40 MHz presentation raster and its exact native cadence. Update profiler clock units and timeout thresholds so the hardware evidence remains dimensionally correct, update the timing extraction to identify the new period, and require the focused and full regressions before another incremental build. The current fit has plus 1.672 ns decoder slack against the 18.518 ns period, so the 16.667 ns target is close enough to require real post-fit proof rather than assumption; accept and install only a zero-error, fully positive-timing artifact, then require the exact quality-six scene to reach all 120 pictures and 119 swaps with zero errors, terminal quiet and zero cadence outliers.

#### Files Modified:

- rtl/mpeg2_stream_fifo.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 323 COMMIT Unreleased 25f05dd 2026-08-22T02:19:15-07:00

#### Coming From:

Unreleased cc39b46

#### Purpose:

Retry the unchanged native-24-fps design with fitter seed ten after seed nine misses timing only on the standing HDMI framework path.

#### Outcome:

Changing only the reproducible fitter seed from nine to ten closes the standing placement-sensitive HDMI path. The incremental smart-recompile build finishes in 9 minutes 46 seconds with zero errors and positive timing at plus 0.170 ns global setup, plus 1.045 ns decoder setup, plus 7.882 ns video setup, plus 0.248 ns hold, plus 3.441 ns recovery, plus 0.697 ns removal and plus 0.462 ns minimum pulse width. It uses 34,494 ALMs, 51,056 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks. The accepted 4,372,048-byte RBF has SHA-256 `ea31820acc9a8db2bc7cbe95fa1dfa4f1ebbfae79d8b0e4f03a95a4dad73d42d`, is installed persistently as `/media/fat/MediaPlayer.rbf` and verifies byte-for-byte over FTP. Hardware accepts all 1,070,782 bytes of the native-rate control and reports frame-rate code two, exactly 250 displayed pictures, 249 swaps, 85 reference pictures, 165 B pictures, terminal quiet, no error flags and no cadence-gap outliers; 249 measured display intervals span 10.384474 seconds for 23.978103 fps, the expected finite-sample result around the exact 24 fps accumulator. The complete 14,315-picture native stream also verifies after upload with SHA-256 `015c8811932ce8b324af6ccd9e235cd621307aa43fcaf62b413b93badba52de5` and is launched for the user's direct visual comparison.

#### Next Steps:

Have the user judge smooth field pans and the rolling credits in the full native-rate movie, where the former once-per-second repeated-picture hitch should now be absent. Keep the squirrel sequence at 7:20 through 7:25 as a separately attributable transport and decode-throughput stress case, since removing the deterministic rate-conversion repeats does not remove that scene's measured input burst. Preserve both native and forced-rate movies for an immediate visual comparison if the residual cadence is ambiguous.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [x] Passed

---
## 322 COMMIT Unreleased cc39b46 2026-08-22T01:52:41-07:00

#### Coming From:

Unreleased 74cff5b

#### Purpose:

Add exact 24 fps presentation cadence and generate Big Buck Bunny at its native frame rate without duplicated pictures.

#### Outcome:

Commit `cc39b46` adds exact frame-rate-code-two credit to the saturating pixel-clock presentation accumulator while preserving code three and extends cadence outlier capture to both rates. Focused tests deliver exactly 240 native-rate pictures and the existing 250 pictures across the same 603 raster windows with a minimum two-window gap, and profiler schema four retains checksum `e82b5cad` while capturing code-two outliers. The native 250-picture BBB encode has frame-rate code two, maps all 250 source pictures without inserted duplicates and completes all 1,070,782 bytes in the full Verilator raster at 225,134,082 cycles with 74 P pictures, 165 B pictures, 85 reference publications, 249 swaps and zero errors. The existing 25 fps corpus remains exact at 6,519,997 cycles. The complete native stream is 720 by 480, 14,315 pictures, 84,423,309 bytes, SHA-256 `015c8811932ce8b324af6ccd9e235cd621307aa43fcaf62b413b93badba52de5`, frame-rate code two and a valid sequence-end marker. The incremental seed-nine Quartus build finishes in 11 minutes 28 seconds with zero errors and 147 warnings, using 34,391 ALMs, 51,100 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks, but it is rejected because the standing HDMI framework path misses setup by 0.180 ns; decoder and video setup remain positive at plus 1.322 ns and plus 6.621 ns, with hold plus 0.246 ns, recovery plus 3.834 ns, removal plus 1.020 ns and pulse width plus 0.462 ns. The rejected 4,384,288-byte RBF has SHA-256 `e48f74cdab417336e434c81a2a8b6548a880f6f4099879bf8693cc2671bc5a02` and is not installed.

#### Next Steps:

Retry the unchanged design with a new documented fitter seed because seed nine misses only the standing placement-sensitive HDMI framework path. Require positive timing before installing any artifact, then run a short native 24 fps hardware cadence gate and the complete movie so the user can determine whether the exact once-per-second duplicate hitch is gone while keeping the separate 7:20-to-7:25 transport burst under observation.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 321 COMMIT Unreleased 74cff5b 2026-08-22T01:02:36-07:00

#### Coming From:

Unreleased 985ac76

#### Purpose:

Keep the development quiet snapshot open until the scheduler has presented its already-released terminal pending frame.

#### Outcome:

Commit `74cff5b` adds the scheduler's existing `pending_frame_valid` state to the development-only quiet qualification and changes no decoder, scheduler, cadence, display or loading-bar decision. The focused scheduler and profiler regressions pass. The incremental seed-nine Quartus build completes in 12 minutes 23 seconds with zero errors and positive timing at plus 0.053 ns global setup, plus 1.402 ns decoder setup, plus 7.570 ns video setup, plus 0.250 ns hold, plus 4.052 ns recovery, plus 0.537 ns removal and plus 0.462 ns pulse width. It uses 34,507 ALMs, 51,081 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; the 4,416,296-byte RBF has SHA-256 `95862c4ecede2bb20316a24dabc87aaa16f89a94cc9d363ad47573db3f42571d`. Hardware controls finish exactly at 48/47 and 72/71 with zero errors and zero outliers. Two full-stream runs consume all 1,178,034 bytes and finally report the exact 250 pictures, 249 swaps, terminal quiet, no pending scheduler state and zero errors, proving the former early freeze and final-reference drain are fixed. Both full runs record one reproducible startup-only outlier before picture two while the decoder is not ready, 50.952 ms and 50.115 ms respectively; pictures three through 250 contain no outliers, and the user reports visually smooth playback and a safer-looking ending. The exact RBF is installed persistently as `/MediaPlayer.rbf` and verified byte-for-byte over FTP, but release acceptance remains open for the startup gap and the requested full-movie endurance observation. The complete 596.46-second AVI is converted outside the repository to a 720-by-480, 25 fps, 14,911-frame elementary stream with two B frames, 85,680,318 bytes, SHA-256 `10df778a6329b7ab6e3ebda98010b47e4f57ad77f74de3c1a454f95a514383e0` and a valid sequence-end marker; it is uploaded and launched on the MiSTer without screenshot polling for the user's direct baseline test.

#### Next Steps:

Have the user watch the complete 9-minute-56-second baseline and report any freeze, stutter, corruption, loading-bar stall or abnormal ending. Keep release acceptance open until that endurance result is known and the reproducible startup-only gap is either accepted explicitly or corrected. After the baseline, add the requested simple human-readable Python conversion recipe with plain FFmpeg arguments, no framework and clear actual-output validation, then expand release coverage across supported frame rates, aspect ratios, motion levels, GOP structures, sizes and malformed-input failure behavior.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 320 COMMIT Unreleased 985ac76 2026-08-22T00:37:52-07:00

#### Coming From:

Unreleased 04a532c

#### Purpose:

Release a final reference publication retained during an overlapping B-picture drain when sequence end has already removed its classification barrier.

#### Outcome:

Commit `985ac76` retains sequence end across an active reordered run and applies that terminal permission when the run preserves a concurrently decoded reference as ordinary pending display work. The new focused case fails before the fix and passes after it alongside all prior scheduler orders with a minimum presentation gap of two. Real 48-, 72- and 250-picture Verilator replays consume every byte and retain exact swap counts of 47, 71 and 249 with zero errors; the full stream finishes 1,178,034 bytes at 222,767,587 cycles. The incremental seed-nine Quartus build completes in 13 minutes 52 seconds with zero errors and positive timing at plus 0.330 ns global setup, plus 1.679 ns decoder setup, plus 6.688 ns video setup, plus 0.246 ns hold, plus 3.749 ns recovery, plus 0.697 ns removal and plus 0.462 ns pulse width. It uses 34,285 ALMs, 51,047 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; the 4,400,432-byte RBF has SHA-256 `9b4a3e0ce83b8a145ac53ec915cf9ec1e2a0bb7bf1f7726ff4ec9e9d6fb38d7a`. Hardware controls again pass exactly at 48/47 and 72/71 with zero errors and zero outliers. The full stream remains visually smooth and the user describes its ending as safer; telemetry proves the behavioral fix by changing the final pending reference from unreleased to released, but the quiet snapshot still latches at 249/248 only 1,023 clocks after `presentation_complete`, before the released frame's next cadence window.

#### Next Steps:

Keep the accepted scheduler correction and extend only the development quiet qualification to require that no pending frame remains. Rebuild incrementally and repeat hardware validation so telemetry waits through the final cadence swap instead of sampling the correct release early.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 319 COMMIT Unreleased 04a532c 2026-08-22T00:24:17-07:00

#### Coming From:

Unreleased 385ead5

#### Purpose:

Retry the unchanged terminal cadence snapshot qualification with fitter seed nine after seed eight misses timing only on the standing HDMI framework path.

#### Outcome:

Commit `04a532c` changes only the reproducible Quartus fitter seed from eight to nine. The incremental smart compile skips unchanged synthesis, finishes in 9 minutes 43 seconds with zero errors and closes the seed-sensitive HDMI framework path at plus 0.179 ns global setup; decoder and video setup are plus 1.270 ns and plus 6.459 ns, with hold plus 0.246 ns, recovery plus 4.295 ns, removal plus 0.586 ns and pulse width plus 0.462 ns. The fit uses 34,609 ALMs, 51,269 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; its 4,366,308-byte RBF has SHA-256 `41bf2d21c121204e873b8a09b9b39014364e95b669381a8097ea69595e763587`. Hardware controls remain exact at 48 pictures and 47 swaps and at 72 pictures and 71 swaps, with both reporting terminal quiet, zero errors and zero cadence outliers. The full stream consumes all 1,178,034 bytes, decodes 250 pictures, reaches sequence end and is visually smooth through the authored black ending according to the user, but the corrected quiet snapshot proves one terminal reference remains behind the classification barrier: it reports 249 pictures, 248 swaps, `presentation_complete`, zero errors and zero outliers with `pending_frame_valid` still set.

#### Next Steps:

Preserve the visually accepted seed-nine result but do not install it as final. Add a focused scheduler case for sequence end arriving before an overlapping final reference can leave the classification barrier, then release that already-decoded reference without changing ordinary GOP scheduling and repeat the incremental build and three hardware gates.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---
## 318 COMMIT Unreleased 385ead5 2026-08-22T00:09:56-07:00

#### Coming From:

Unreleased d95baa6

#### Purpose:

Require the development cadence snapshot to wait for terminal presentation completion so the full 250-picture hardware run is not sampled two cadence slots early.

#### Outcome:

Commit `385ead5` adds `presentation_complete` to the development-only quiet qualification and leaves the bounded forced-terminal snapshot path intact. The focused cadence-profiler regression passes its quiet, forced, fatal and no-progress cases with schema-four checksum `e82b5cad`. The incremental Quartus 17.0.2 compile completes in 11 minutes 59 seconds with zero errors and 147 warnings, but the fit is rejected before hardware deployment because global setup is minus 0.105 ns on the standing seed-sensitive HDMI framework clock; decoder and video setup remain positive at plus 0.569 ns and plus 7.555 ns, with hold plus 0.245 ns, recovery plus 3.289 ns, removal plus 0.709 ns and minimum pulse width plus 0.462 ns. Seed eight uses 34,569 ALMs, 51,316 registers, 4,046,279 memory bits, 507 RAM blocks and 65 DSP blocks; its rejected 4,409,220-byte RBF has SHA-256 `502b306668c15f4ba0becdb34313737ccd6f8ccd5140e86885fe25a34bdfdb0c` and was not uploaded.

#### Next Steps:

Retry the unchanged design incrementally with fitter seed nine, explicitly recording that any timing closure is seed-dependent. Only a build with zero errors and positive global, decoder, video, hold, recovery, removal and pulse-width slack may proceed to the same three hardware clips.

#### Files Modified:

- MediaPlayer_top_07.svh

#### Status:

- [ ] Built
- [ ] Passed

---
## 317 COMMIT Unreleased d95baa6 2026-08-21T23:50:22-07:00

#### Coming From:

Unreleased 3c80bef

#### Purpose:

Implement exact B-picture f_code five motion support so the 250-picture compatibility stream no longer leaves an unowned B transaction.

#### Outcome:

Commit `d95baa6` extends the B parser and raster path from f_code one through four to exact f_code five support. Predictors, residual reconstruction and emitted forward/backward vectors are signed 9-bit values, the raster motion record is widened from 34 to 38 bits, and an explicit B transport qualifier distinguishes direction records from ordinary P residual sample indices while the vectors travel independently of the 16-bit residual sideband. The deterministic range generator now exercises one through five, including signed 9-bit wraparound, and FFmpeg verifies both authored B pictures pixel-exact; the parser-window and residual-streaming regressions pass with zero errors and the latter retains its exact 1,286,071-cycle Icarus count. The canonical fixed-count 72-picture raster remains exactly 6,519,997 cycles, the scheduler cadence remains one, three and two with a minimum presentation gap of two, and real 48-, 72- and 250-picture Verilator runs consume every byte and terminate with zero decoder, raster, ownership or presentation errors. The 250-picture run finishes all 1,178,034 bytes with 74 P pictures, 165 B pictures, 85 reference publications and 249 display swaps, proving both the former picture-80 stop and the terminal non-quiet state are gone in simulation. The loading bar and scheduler behavior are unchanged.

#### Next Steps:

Build `d95baa6` incrementally as requested without clearing Quartus compilation databases, require zero errors and positive timing, install the exact RBF on the connected MiSTer, and run the 48-, 72- and 250-picture hardware clips. Accept the repair only if each consumes every byte, presents every picture through terminal quiet, reports zero error flags and preserves the accepted GOP cadence; retain the loading bar as the diagnostic requested by the user.

#### Files Modified:

- MediaPlayer_top_01.svh
- MediaPlayer_top_02.svh
- MediaPlayer_top_04.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part3.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part4.svh
- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part5.svh
- rtl/mpeg2_new/mpeg2_h262_reference_pipeline_probe_rearm.sv
- rtl/mpeg2_new/mpeg2_h262_two_picture_probe_p_chain.sv
- tools/streams/generate_test_b_f_code_range.py
- tools/streams/h262common.py
- tools/streams/tb_h262_b_residual_streaming.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [ ] Built
- [ ] Passed

---
## 316 COMMIT Unreleased 3c80bef 2026-08-21T22:34:28-07:00

#### Coming From:

Unreleased 3c80bef

#### Purpose:

Review the user's recorded 72-picture playback and classify the loading-bar rate changes observed after the GOP-stutter repair.

#### Outcome:

The 11.712-second 59.94-fps phone recording contains two complete plays of the 72-picture stream. The MiSTer loading overlay covers the principal motion and the uncovered opening content changes too little for the recording to provide frame-accurate cadence proof by itself, but both passes advance through all source content without an obvious prolonged freeze at the former 24-picture GOP boundaries; this supports the user's qualified visual assessment that the stutter is gone and agrees with Entry 315's stronger hardware telemetry of 72 pictures, 71 swaps and zero cadence outliers. The loading-bar acceleration and deceleration is explained by the current transport rather than by display cadence: the standard HPS file transfer is stopped through `ioctl_wait` whenever the core's 256-byte dual-clock input FIFO is full, while decoder, prediction, persistence and presentation work consume bytes at variable rates. The bar therefore represents accepted file-byte progress and naturally advances in bursts as the FIFO fills and drains, with GOP-correlated rate changes expected because reference and B-picture work impose different backpressure. It is not presently a functional bug because progress remains monotonic, all bytes are accepted and display cadence remains legal; reversal, failure to complete or a coincident display outlier would change that classification.

#### Next Steps:

Accept the Entry 315 GOP-stutter repair and retain the bursty loading bar as a documented transport and user-interface characteristic rather than changing the scheduler again. Proceed separately to the 250-picture non-quiet terminal presentation state, preserving incremental builds and the accepted 48- and 72-picture cadence gates for every candidate.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 315 COMMIT Unreleased 3c80bef 2026-08-21T21:54:45-07:00

#### Coming From:

Unreleased 9367b7e

#### Purpose:

Defer a queued B-picture header until the already-admitted new-GOP I reference publishes instead of treating that transient ordering as a fatal presentation error.

#### Outcome:

Commit `3c80bef` adds one bounded deferred queued-B transaction to the presentation scheduler. When a B header reaches a closed run while the admitted I/P overlap is still open but either its reference publication or a scratch destination is temporarily unavailable, the scheduler consumes and retains that one classification event, asserts presentation backpressure before payload, and completes ordinary queued-generation admission atomically once both resources are safe. Duplicate deferred headers, non-overlap resource exhaustion, promotion conflicts, decode failures and ownership failures remain errors. Focused scheduler verification covers delayed I publication, old-generation retirement, scratch release, atomic promotion and duplicate rejection; the cadence-profiler regression passes, Verilator lint has only standing testbench warnings, the canonical complete raster finishes all 291,641 bytes with 25 pictures and 71 swaps, and the real 72-picture dense-order run finishes all 243,306 bytes with 22 P pictures, 47 B pictures, 25 reference publications and no presentation or ownership error. The requested incremental Quartus 17.0.2 build completes in 12 minutes 15 seconds with zero errors and positive timing at plus 0.633 ns global setup, plus 1.133 ns decoder setup, plus 6.373 ns video setup, plus 0.240 ns hold, plus 3.761 ns recovery, plus 1.210 ns removal and plus 0.462 ns minimum pulse width. It uses 34,525 ALMs and 51,222 registers; the 4,394,724-byte RBF has SHA-256 `2761fa1edf0dff4edfd38b5c33ae191f2e62e5b242606b51c81dffef1e781ccf`. Hardware accepts the repair: the 48-picture clip consumes all 125,948 bytes and displays 48 pictures with 47 swaps at 25.045 fps, while the 72-picture clip consumes all 243,306 bytes and displays 72 pictures with 71 swaps at 24.957 fps; both reach sequence end with zero error flags and zero cadence outliers, eliminating the measured GOP-boundary stutters. The exact RBF is installed persistently as `/MediaPlayer.rbf`, verified byte-for-byte over FTP, and restored as the active core. The additional 250-picture run still does not publish terminal telemetry within 120 seconds, confirming that its previously deferred non-quiet terminal state remains separate from the now-fixed GOP stutters.

#### Next Steps:

Have the user visually confirm smooth playback on the installed core. Then treat the 250-picture non-quiet terminal state as a separate presentation-finalization task: capture or reproduce its terminal bank and scheduler ownership state without changing the accepted GOP repair, add a focused terminal regression, and continue to use incremental builds for every hardware candidate.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 314 COMMIT Unreleased 9367b7e 2026-08-21T21:33:01-07:00

#### Coming From:

Unreleased f3f2395

#### Purpose:

Capture the rejected I-overlap build's hardware state when playback terminates before the MPEG sequence-end marker.

#### Outcome:

Commit `9367b7e` leaves decode, scheduling, frame ownership and presentation behavior untouched while allowing the schema-four cadence profiler to snapshot after either a sticky fatal error or one decoder-clock second without byte, persistence, display, prediction or writer progress. Focused Icarus verification covers quiet, forced-terminal, fatal and no-progress capture with valid checksums, and Verilator lint passes with only standing testbench warnings. The incremental Quartus 17.0.2 build completes in 12 minutes 41 seconds with zero errors and positive timing at plus 0.253 ns global setup, plus 1.311 ns decoder setup, plus 7.273 ns video setup, plus 0.248 ns hold, plus 3.619 ns recovery, plus 0.880 ns removal and plus 0.462 ns minimum pulse width. It uses 34,520 ALMs and 51,206 registers; the 4,415,436-byte RBF has SHA-256 `a7e34a96d69a551aab24e042f53ac4bf152b6e3713000d0efc2f31ac52d8919b`. Hardware capture succeeds and proves the rejected Entry 313 behavior is a scheduler fail-stop, not a deadlock or reference corruption: only 84,756 of 125,948 bytes are accepted, 10 references and 15 B pictures complete, 23 pictures and 22 swaps are displayed, cadence remains legal at 24.787 fps with zero gap outliers, and error flags are exactly `0x0200`, the presentation-error bit. The terminal scheduler state retains `overlap_decode_open=1` and `pending_frame_valid=1` after clearing the active run, which identifies the queued B admission failure: the following B header arrived while the new-GOP I overlap was open but before its reference publication was visible, and the scheduler treated that transient absence as fatal. The known-working Entry 312 RBF with SHA-256 `af63bb9c8433247d4b5b54ab511efd12d9e2aaec8cf664e021e48c7b4fcb1b31` was restored on the MiSTer after capture.

#### Next Steps:

Replace the queued-run fail-stop only for this proven transient. When a B header reaches a closed run with `overlap_decode_open` set but no overlap publication yet, latch one deferred queued-B request and assert presentation backpressure after that header so the already accepted I picture may finish publishing without allowing B payload bytes to outrun scratch-bank ownership. Complete the ordinary queued admission atomically when `frame_waiting` or `pending_frame_valid` supplies the I reference, preserve scratch-exhaustion and duplicate-request cases as genuine errors, and add a focused case in which B classification precedes delayed I publication. Keep the Entry 313 I-overlap behavior otherwise unchanged, build incrementally as requested, and require the 48- and 72-picture hardware clips to finish with every byte and picture, zero errors and zero GOP outliers before persistent installation.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/tb_h262_hardware_cadence_profiler.sv

#### Status:

- [x] Built
- [x] Passed

---
## 313 COMMIT Unreleased f3f2395 2026-08-21T21:08:56-07:00

#### Coming From:

Unreleased 242d151

#### Purpose:

Allow the I-picture beginning a new GOP to decode through the existing reference-overlap window so the presentation pipeline does not drain at each GOP boundary.

#### Outcome:

Commit `f3f2395` adds an explicit accepted I-picture header event beside the existing P-picture event and allows either supported reference type to open the scheduler's single overlap decode transaction when a B run closes. Focused scheduler, dense publication-order and complete raster simulation pass with zero functional errors, including delayed I publication into the third reference bank, and the canonical 72-picture raster completes 69,999 cycles sooner at 6,519,997 cycles. A fully clean Quartus 17.0.2 build completes with zero errors; the required 54 MHz decoder and 40 MHz video paths have positive setup margins of 1.133 ns and 7.144 ns respectively, although the default whole-design report retains a minus 0.084 ns setup warning on a standing framework path. The 4,411,644-byte RBF has SHA-256 `482afd7eb6b9757408fccbb3ec6f525850d0438f4a17e79dbe2403cc5ba8481c`. Hardware rejects the repair: the 48-picture clip reaches the first GOP boundary near picture 24 and then freezes permanently on the retained frame. Because the stream never reaches its sequence-end marker, schema-four telemetry never snapshots and the automated run correctly reports no valid telemetry rather than a cadence result. The simulation abstraction therefore missed a hardware-only liveness or ownership condition in the new I-overlap path, and this RBF is not accepted or installed persistently.

#### Next Steps:

Capture the hardware failure before attempting another functional repair. Extend the development cadence snapshot so a fatal decoder result or a bounded no-progress timeout can publish telemetry without requiring the sequence-end marker, then reproduce the 48-picture freeze and decode the terminal error flags, scheduler ownership state, accepted-byte position and displayed-picture count. Use that evidence to distinguish a reference-bank collision, a fail-open diagnostic rejection and a true decoder deadlock, restore the known-working diagnostic RBF after capture if necessary, and do not accept or install `f3f2395`.

#### Files Modified:

- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv

#### Status:

- [x] Built
- [ ] Passed

---
