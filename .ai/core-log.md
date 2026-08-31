## 787 COMMIT Unreleased ??? 2026-08-30T19:40:26-07:00

#### Coming From:

Unreleased b71cc8b

#### Purpose:

Add direct main-feature playback from the absolute USB optical-device path `/dev/sr0` without staging a DVD ISO.

#### Outcome:

The user reprioritizes direct USB DVD access because ripping and transferring ISO images dominates development time, keeps the deployed source-`eb7bed6` Blazing Saddles audio-boundary test running at 25 minutes, and connects the Coming to America DVD drive to the MiSTer.  Read-only absolute-path FTP inspection finds `/dev/sr0` and `/dev/cdrom -> sr0`; `/dev/sr0` is a removable root:`cdrom` block device with mode 0660 and 16,461,784 reported 512-byte sectors, backed by an HL-DT-ST DVDRAM GP63EX70 revision RF01.  Every `/media/usb0` through `/media/usb7` directory is empty, so the disc is not filesystem-mounted, but direct libdvdnav/libdvdread/libdvdcss access should use the block device and does not require a mount.  The proposed helper boundary will implement only the already reserved explicit source `dvd:/dev/sr0`, use libdvdnav's device-opening path so libdvdcss owns optical authentication and sector reads, and reuse the accepted longest-title, initial random-access, PTS epoch, scheduler and one-traversal behavior.  Patched Main will recognize a small `USB DVD Drive.dvd` launcher in the existing MediaPlayer file list and translate it to that exact source string.  Menus, chapter controls, track selection, subpictures, DVD LPCM and physical-disc ejection remain outside this commit; Main and helper change, but the FPGA, seed-19 RBF and Quartus project do not.

#### Next Steps:

Implement the shared ISO/direct-device navigation source with absolute-device validation and rewind, add the launcher mapping and documentation, and require native ISO, MPG and VOB regressions before cross-building one helper and one patched Main from exact source.  Do not alter the MiSTer while the current Blazing Saddles run is active.  After its 48:25 gate passes and telemetry is captured, preserve both installed executables, deploy each through unique candidate upload and readback followed by same-directory rename and final readback, install only the tiny launcher under the absolute MediaPlayer directory, and reboot or reload as required.  The first physical-disc gate is a bounded Coming to America launch proving direct device open, CSS key acquisition, valid longest-title Program Stream output, continuous HDMI audio and video, and representative S/PDIF output; extend the run only after optical latency and read stability are demonstrated.

#### Files Modified:

- CHANGELOG.md
- README.md
- assets/USB DVD Drive.dvd
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c
- host/arm/media_source.c
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 786 COMMIT Unreleased b71cc8b 2026-08-30T19:13:48-07:00

#### Coming From:

Unreleased eb7bed6

#### Purpose:

Bound longest-title ISO playback to one selected-title traversal so post-title navigation cannot restart or enter another DVD domain.

#### Outcome:

The user authorizes continued development while the deployed source-`eb7bed6` Blazing Saddles boundary soak runs and separately prepares a genuinely encrypted ISO for the following qualification gate.  Native testing rejects source `ef2a7e9` because libdvdnav reports a legitimate large time regression at each new chapter, and rejects the narrower source `bee9541` duration cutoff because Coming to America reaches its described 606,390,000-tick duration on a payload block, continues authored title cells through approximately 630,129,000 ticks and otherwise leaves a 1,565-byte AC-3 tail.  Final source `b71cc8b` therefore treats duration as selection and diagnostic metadata, retains the selected title plus monotonic chapter and cell structure, and converts only a title exit or backward chapter or cell replay into clean end-of-stream before following-domain payload is exposed; rewind restores the boundary.  Accelerated complete native runs end once and drain cleanly for Blazing Saddles at 3,823,399,998 video bytes, 11,150 timestamps and 267,482,112 PCM samples, Coming to America at 4,239,456,995 bytes, 14,807 timestamps and 336,433,152 samples, and The Big Lebowski at 5,509,816,546 bytes, 14,558 timestamps and 338,021,376 samples.  The accepted 2,097,152-byte ISO opening remains byte-identical at SHA-256 `396b0db1`, the five-minute MPG remains exactly 224,185,582 bytes at `45401ab3`, and a 299,980,757-byte VOB decode compares byte-for-byte at `677ce1bb`.  One ARM GNU 10.2 build from exact full source `b71cc8bedc112444b79a1d4af2e8b185b6bf0373` produces an 847,156-byte stripped static EABI5 helper with SHA-256 `603f4c05fd6ca687b6dc33c70e97b19fe34a96a320d6a91042f41bd78fb584e7` and no dynamic section; the expected static-libdvdcss `getpwuid` warning remains.  No Quartus build, MiSTer deployment, Main, FPGA, RBF, media or configuration change occurs.

#### Next Steps:

Let the currently deployed `eb7bed6` Blazing Saddles soak pass the prior 48:25 audio boundary and capture its terminal telemetry before changing the running helper.  Then preserve the installed helper and stage-deploy exact candidate `603f4c05` with candidate readback, same-directory rename and final readback; qualify one complete selected title through its clean end so the title-exit boundary itself is hardware-proven.  When the user supplies the encrypted ISO, first independently prove it contains CSS-scrambled sectors, then require a clean complete native opening and a representative HDMI and S/PDIF MiSTer run without changing Main, the seed-19 RBF or FPGA source.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_source.c

#### Status:

- [x] Built
- [ ] Passed

---

## 785 COMMIT Unreleased eb7bed6 2026-08-30T19:08:17-07:00

#### Coming From:

Unreleased eb7bed6

#### Purpose:

Deploy the ISO PTS epoch-normalization helper with verified rollback preservation for hardware qualification.

#### Outcome:

The first deployment attempt before the reboot writes nothing because the MiSTer still answers ping and accepts TCP connections on ports 21 and 22 but neither FTP nor SSH produces a service banner; the user then confirms that the MiSTer had locked up and reboots it.  After reboot, FTP recovers normally.  An independent download verifies the previously active 817,700-byte helper at SHA-256 `536250b8c4e0baba71f1d73e4e0476b8adc23025b447a33bacacb187327af1b5`.  The exact source-`eb7bed668f39c97b79a691b2c721fe42283e19f0` candidate is 847,156 bytes with SHA-256 `f16e83fa2c89b3ed3071e9fa3d40355a67e85e9a5a3634ba055a5c2a7835f8db`; candidate upload and independent absolute-path FTP readback reproduce both values.  A same-directory FTP rename preserves the old helper as `/media/fat/linux/MediaPlayer_Helper.pre_eb7bed6_536250b8`, activates the candidate as `/media/fat/linux/MediaPlayer_Helper`, and a final independent readback again reproduces the exact 847,156-byte length and `f16e83fa2c89b3ed3071e9fa3d40355a67e85e9a5a3634ba055a5c2a7835f8db` digest.  No candidate staging name remains.  Main, the seed-19 RBF, media and configuration remain unchanged; no Quartus build occurs.

#### Next Steps:

Reload MediaPlayer and play the Blazing Saddles ISO from the beginning over HDMI through at least the prior 2,905-second or approximately 48:25 failure boundary, preferably continuing to about 51 minutes; briefly confirm representative S/PDIF output as well.  Accept the timestamp correction only if video remains stable, audio remains continuous and telemetry does not appear at that boundary, then leave the resulting telemetry displayed for one capture.  A complete end-of-title run is not yet required because the separate post-title navigation loop remains deliberately deferred; after this boundary passes, implement the title-duration stop before returning to genuinely scrambled-ISO qualification.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 784 COMMIT Unreleased eb7bed6 2026-08-30T18:21:34-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Normalize DVD ISO presentation timestamps across VOB or cell discontinuities so long-title audio scheduling remains continuous.

#### Outcome:

Source `eb7bed6` adds an ISO-only PTS epoch normalizer with an explicitly documented ten-second implementation guard: ordinary decode-order reversals pass through unchanged, while a material backward reset is translated before both scheduler admission and FPGA timestamp-record generation so its first timestamp follows the preceding maximum by one 90 kHz tick.  A focused exact-source native harness preserves a 45,000-tick reorder, maps a synthetic large reset to one new epoch and leaves non-ISO timestamps unchanged.  The accelerated real Blazing Saddles scheduler test reaches the captured boundary, maps raw PTS 32,764 to normalized PTS 261,466,438 immediately after the prior 261,466,437 maximum, and continues growing its PCM target from 139,227,264 through 255,009,280 frames with zero held backlog rather than freezing at entry 783's 139,443,456-frame target.  The unchanged five-minute MPG again produces exactly 224,185,582 bytes with SHA-256 `45401ab3`, and the first 16 MiB of scheduled ISO transport compares byte-for-byte with the accepted CSS-enabled opening capture.  One static ARM GNU 10.2 build from exact full source `eb7bed668f39c97b79a691b2c721fe42283e19f0` produces an 847,156-byte stripped EABI5 helper with SHA-256 `f16e83fa` and no dynamic section; the expected static-libdvdcss `getpwuid` link warning remains.  The accelerated run separately shows that after the declared 501,030,000-tick title duration libdvdnav follows post-title protection or navigation commands into another epoch and eventually exceeds the two-MiB video lookahead; that end-of-title behavior predates this correction and is reserved for a later host-only boundary rather than expanding the timestamp fix.  No Quartus build or MiSTer deployment occurs.

#### Next Steps:

After explicit user authorization, preserve the installed helper and deploy exact candidate SHA-256 `f16e83fa` by candidate upload, readback, same-directory rename and final readback.  Replay Blazing Saddles past the 2,905-second boundary over HDMI and S/PDIF and accept this correction only if video remains stable, audio remains continuous and telemetry records no underrun.  Then separately bound the selected ISO source to its declared longest-title duration so post-title protection or navigation commands cannot loop into a second traversal, and resume genuinely scrambled-ISO qualification only after both long-title gates pass.

#### Files Modified:

- CHANGELOG.md
- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 783 COMMIT Unreleased 0711d3d 2026-08-30T16:25:29-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Reject the provisional full-title Blazing Saddles ISO soak and localize its late audio-only failure without disturbing the running movie.

#### Outcome:

During the uninterrupted complete `/media/fat/games/MediaPlayer/Blazing Saddles.iso` run on the installed source-`0711d3d` helper, the user reports that video remains clean and running but HDMI audio begins crackling after the earlier five-minute acceptance.  The matching live helper log names longest title 2 and decoded HDMI PCM, while its scheduler stays real-time and ahead of the sink until elapsed 2,904.822639 seconds; there `max_video_pts` reaches 261,466,437 ticks or 2,905.182633 seconds and never advances again even though admitted video grows from 1,993,452,669 to 2,107,305,716 bytes.  Over the following 181 seconds the fixed PCM target remains 139,443,456 frames, held decoded PCM grows from 3,072 to 5,106,816 frames and emitted PCM falls 5,069,458 frames or 105.614 seconds behind the 48 kHz wall-clock expectation.  The 720x480 raw capture `/tmp/entry783_iso_audio_crackle_raw.png`, 371,166 bytes and SHA-256 `8c86977c`, has 64 valid schema-20 rows, parity and checksum `0e6258d6`; its sticky first-error state occurs at STC second 2,906 with hardware error `0x0400`, audio FIFO floor zero and exactly one recorded underrun, while decoder, PCM protocol, presentation, cache-overlap and transport-block errors remain clear.  The 1,920x1,080 visible capture `/tmp/entry783_iso_audio_crackle.png`, 573,794 bytes and SHA-256 `eafe7684`, preserves an undamaged active movie frame, and the 75,163,498-byte live helper log has SHA-256 `538bed37`.  Independent read-only FFprobe inspection of the same title finds its DVD packet position resetting from 3,368,974 to 14 at normalized PTS 2,904.623278 seconds, immediately bounding the frozen raw-PTS horizon to a VOB or cell transition.  The evidence therefore identifies an ISO-only host scheduler timestamp-discontinuity defect: the helper rejects every post-transition raw PTS as older than its permanent maximum, so its byte-guard fallback cannot sustain audio even though video continues.  This does not implicate the MPEG-2 decoder, FPGA resources, S/PDIF framing, CSS support or the undeployed source-`81a1002` candidate, and it overturns entry 781's provisional full-ISO acceptance without changing any installed file or repository source.

#### Next Steps:

Keep the accepted seed-19 RBF, Main and decoder unchanged, and do not deploy the encrypted-ISO candidate yet.  Add an ISO-scoped PTS epoch normalizer that recognizes a large backward discontinuity while tolerating ordinary decode-order reordering, advances both scheduler and in-band video timestamps monotonically across the DVD boundary and leaves MPG/VOB behavior byte-identical.  Reproduce the boundary with a compact native discontinuity fixture, run the existing native MPG and decrypted-ISO regressions, rebuild only the ARM helper, then preserve and stage-deploy it for a Blazing Saddles replay through at least the 2,905-second boundary on HDMI and S/PDIF.  Resume genuinely scrambled-ISO validation only after that long-run gate passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 782 COMMIT Unreleased 81a1002 2026-08-30T15:41:39-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Add encrypted DVD ISO main-feature playback through a pinned host-side libdvdcss dependency without expanding into physical discs or menus.

#### Outcome:

The user selects encrypted ISO files as the next target and agrees that technical decryption and licensing or distribution policy remain separate concerns.  Source `81a1002` replaces the deliberate unencrypted-only libdvdread patch with reproducibly pinned libdvdcss 1.6.0 native and ARM builds, configures libdvdread with CSS support, directly links the static library beneath the existing callback-backed `iso:` source and clears inherited Meson compiler arguments so a reused build directory cannot silently retain `MMP_DISABLE_DVDCSS`.  Official VideoLAN material identifies the dependency as transparent encrypted DVD block access under GPLv2; its 83,640-byte source archive is independently verified at SHA-256 `7ea556c8`.  Exact native regression proves the decrypted Blazing Saddles ISO opening remains byte-identical at 1,123,504 bytes and SHA-256 `66b84e51`, including its two discarded open-GOP leading B pictures, while the ordinary five-minute MPG remains byte-identical at 224,185,582 bytes and SHA-256 `45401ab3`.  The exact ARM build succeeds as an 847,156-byte stripped, statically linked EABI5 helper with SHA-256 `620c8af3` and no dynamic section.  A raw sector scan finds no scrambled PES sectors in any available Coming To America, Blazing Saddles or The Big Lebowski ISO, so those already-decrypted images cannot validate the new decryption path and the candidate is intentionally not deployed.  This remains an implementation dependency rather than a substitute for the unavailable authorized DVD CCA specification, and no CSS-conformance claim is made.

#### Next Steps:

Provide an authorized genuinely CSS-scrambled raw ISO fixture, confirm that it contains nonzero scrambled PES sectors, prove native sector decryption and a complete valid opening, and compare against an independently decrypted control when feasible.  If that gate passes, preserve the installed helper, deploy this exact candidate by verified staging and same-directory rename, and qualify the same encrypted ISO on HDMI and S/PDIF without changing Main, the seed-19 RBF or FPGA source.

#### Files Modified:

- CHANGELOG.md
- README.md
- docs/BUILDING.md
- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/libdvdread-disable-css.patch
- host/arm/media_source.c
- host/build_arm_stack.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 781 COMMIT Unreleased 0711d3d 2026-08-30T15:36:06-07:00

#### Coming From:

Unreleased 0711d3d

#### Purpose:

Accept the corrected Blazing Saddles ISO startup on hardware and define the next DVD feature boundary.

#### Outcome:

The user reports that the complete Blazing Saddles ISO now starts normally, continues beyond five minutes with clean visible playback and raises no fatal telemetry, explicitly accepts the ISO initial random-access correction as working and elects to leave the title playing to completion.  This clears the deterministic first-GOP failure fixed by source `0711d3d`: the installed helper safely discarded the two unavailable open-GOP leading B pictures and crossed far beyond the former 7,997-byte prediction-error stop without a core, Main or configuration change.  Full-title completion remains useful soak evidence but is not required to establish that the bounded startup correction passed its hardware gate.

#### Next Steps:

Let the current title continue and record its terminal result when available, then target encrypted ISO files within the existing main-feature `iso:` backend rather than physical discs or interactive menus.  Keep that work host-only and preserve longest-title selection, ordinary decrypted ISO playback, Main and FPGA behavior; first choose an acceptable CSS dependency and distribution boundary, add the controlled CSS reference required by project policy, prove native decryption against an authorized encrypted-image fixture, then build and deploy only the helper for HDMI and S/PDIF hardware qualification.  Interactive menus remain later because they additionally require navigation control, subpicture rendering, button highlights, still-frame behavior and remote-control input.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 780 COMMIT Unreleased 0711d3d 2026-08-30T15:15:47-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Make decrypted DVD ISO title starts safe when an authored open GOP begins with B pictures whose earlier reference lies outside the selected title boundary.

#### Outcome:

The first hardware launch of the complete 6,501,636,096-byte Blazing Saddles image opened the unencrypted ISO, selected longest title 2 at 5,567 seconds and identified AC-3 substream `0x80`, but schema-20 telemetry stopped after the initial I picture with prediction error `0x0004`; native comparison then proved the ISO retained decode-order B0 and B1 pictures whose earlier reference lies before the selected title, while the hardware-passed remux begins I2, P5, B3 and B4.  Source `0711d3d` adds a bounded ISO-only initial random-access filter that holds the existing scheduler queue through the second I/P reference and neutralizes only those unavailable leading B pictures without changing byte positions, timestamps, ordinary files, Main or FPGA logic.  The native build reports exactly two discarded pictures and produces I2, P5, B3 and B4 at its opening, a complete-GOP FFmpeg decode has no errors, and the ordinary five-minute Blazing Saddles MPG output remains byte-identical at SHA-256 `45401ab3`.  The exact 817,700-byte static ARM helper from `0711d3d`, SHA-256 `536250b8`, is installed by verified staging and same-directory rename with matching final readback; the previous `73d2f507` helper is preserved in both the backup directory and `/media/fat/linux/MediaPlayer_Helper.pre_0711d3d_73d2f507`.  The accepted source-`205bbd7` seed-19 RBF and ISO-capable Main remain unchanged, and hardware replay of the corrected helper is pending.

#### Next Steps:

Relaunch the same Blazing Saddles ISO in Native 480i at 16:9, Bob and HDMI and confirm that picture and audio begin normally without fatal telemetry; if that startup gate passes, let the title run long enough to confirm sustained playback and then check S/PDIF without rebuilding the core.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---

## 779 COMMIT Unreleased 205bbd7 2026-08-30T14:31:18-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Capture and independently verify the accepted NARA MPD-D2 qualification control on the installed source-`205bbd7` core.

#### Outcome:

At the user's request, one screenshot and the matching helper log are collected from the completed `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob` run; the visible terminal frame confirms that this adopted NARA-named qualification file contains the Blazing Saddles footage referenced by the user.  The helper identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,200,545 bytes through the fast path in 299.946401 seconds at 1.207551 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero.  The 639,401-byte screenshot `/tmp/entry779_nara_mpd_d2_qualification_5min_pass.png`, SHA-256 `518e59b9673258da6e1fca55af759d6ac02f6c2ff3ae5d589cd1de792f64d677`, visibly preserves a clean final western scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `bfb4da57` matches; the terminal no-progress snapshot accepts 300,095,133 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 12,330,598-byte helper log has SHA-256 `b2e3ccb3ce427162adea35ccdceca6226a76ad19fca7e5f3d3279dcc0744ccc4`.  This replaces the user-report-only NARA evidence in entry 778 with a complete captured control result and changes no source, installed file, playback mode or configuration.

#### Next Steps:

Keep source `205bbd7`, fitter seed 19, the installed RBF, native 480i mode and current decoder capability boundary unchanged.  All three adopted five-minute frame-picture MPD-D2 VOBs now have accepted results, and each captured run shows real-time completion with no audio starvation; field-picture MPEG-2 remains intentionally deferred.  If the user wants to resume the previously paused roadmap, scope decrypted ISO playback as a host-side input and navigation boundary first, without an FPGA rebuild unless later evidence proves one necessary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 778 COMMIT Unreleased 205bbd7 2026-08-30T14:27:08-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Resolve the adopted NARA control filename and accept the complete three-file MPD-D2 decoder-throughput gate on source `205bbd7`.

#### Outcome:

The user clarifies that the NARA file named in the preceding positive report is exactly `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob`, so the earlier statement that it is good is assigned to that adopted control rather than to a separate Blazing Saddles fixture.  Together with entries 776 and 777, source `205bbd7` now passes the complete targeted native-480i MPD-D2 gate: NARA is user-reported clean, while the formerly worst-stuttering Coming to America and Big Lebowski VOBs both complete in approximately 299.93 seconds with perfect user-observed video and audio, all 362,080,761 transport bytes on the fast path, every AC-3 frame and PCM sample emitted, and checksum-valid schema-20 telemetry showing zero hardware errors, audio underruns, transport blocks, deadline gaps and cadence outliers.  This directly clears the sustained decoder-backpressure and ordered-audio-starvation failure that previously began near 56 seconds for Coming to America and 33 seconds for Big Lebowski.  The installed 4,440,192-byte seed-19 RBF remains SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`; no source, installed file, playback mode or configuration changes.

#### Next Steps:

Keep source `205bbd7`, fitter seed 19, the installed RBF, native 480i mode and current decoder capability boundary unchanged.  The frame-picture MPD-D2 VOB compatibility and real-time throughput gate is accepted; field-picture MPEG-2 remains intentionally deferred.  If the user wants to resume the previously paused roadmap, scope decrypted ISO playback as a host-side input and navigation boundary first, without an FPGA rebuild unless later evidence proves one necessary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 777 COMMIT Unreleased 205bbd7 2026-08-30T14:25:12-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Accept the formerly stuttering Big Lebowski MPD-D2 VOB on the installed source-`205bbd7` core and retain the user's separate control-file report without assuming an ambiguous filename.

#### Outcome:

The user reports that `/media/fat/games/MediaPlayer/the_big_lebowski_mpd_d2_5min.vob` runs perfectly and leaves its terminal telemetry visible for one requested capture; this file previously developed severe audio stutter near 33 seconds.  The matching helper log identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,080,761 bytes through the fast path in 299.931120 seconds at 1.207213 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero; the earlier nominal HDMI run on the previous decoder required 309.292 seconds and accumulated the same starvation deficit.  The 561,604-byte screenshot `/tmp/entry777_lebowski_mpd_d2_5min_pass.png`, SHA-256 `17a66fd1e1e2b1b9be0db3a86378778061f75fefbdb23b026838a9b270372617`, visibly preserves the clean intended terminal toilet scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `9d09b149` matches; the terminal no-progress snapshot accepts 299,975,349 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 12,195,247-byte helper log has SHA-256 `e22a4be8861fa1ab7274a4b5e7dcaecdac414590956d3b97986e74fb072a04f2`.  The user separately states that “Blazing Saddles is good (the NARA file)”; because Blazing Saddles and the NARA qualification VOB are distinct known fixtures, this exact positive report is retained without assigning it to one filename.  No further screenshot is requested, and no source, installed file, playback mode or configuration changes.

#### Next Steps:

Keep the installed source-`205bbd7` core and native 480i mode unchanged.  Confirm whether the user's “Blazing Saddles is good (the NARA file)” report refers to `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob`, a Blazing Saddles fixture, or both; run only any still-unverified adopted control and report its exact filename and result.  Coming to America and Big Lebowski have now both cleared their former sustained audio-starvation failures, so do not rebuild or alter the decoder.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 776 COMMIT Unreleased 205bbd7 2026-08-30T14:22:25-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Accept the previously worst-stuttering Coming to America MPD-D2 VOB on the installed source-`205bbd7` core and quantify removal of the sustained audio-starvation failure.

#### Outcome:

The user chooses `/media/fat/games/MediaPlayer/coming_to_america_mpd_d2_5min.vob` first because it previously developed severe audio stutter near 56 seconds and its opening song makes defects easiest to hear, then reports that the complete run is now perfect and leaves the terminal telemetry visible for collection.  The matching helper log identifies S/PDIF decoded-PCM output and the exact VOB, submits all 362,080,761 bytes through the fast path in 299.928360 seconds at 1.207224 MB/s, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF and exits zero; the prior failing run required 308.544 seconds and audibly starved.  The 795,454-byte screenshot `/tmp/entry776_coming_mpd_d2_5min_pass.png`, SHA-256 `a37601e8f1cc65160c57397e5cf92ebe300c7b95036b4f83cb76d0e0d771353b`, visibly preserves a clean final pool scene.  Its 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `883c99bf` matches; the terminal no-progress snapshot accepts 299,975,349 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, audio underruns, PCM protocol errors, presentation errors, cache overlaps, transport blocks, deadline gaps, cadence outliers or timestamp conflicts.  The 13,383,575-byte helper log has SHA-256 `6cf89dd8da88b9d49e8d6b8d9b75baee6ebd950bc2e460c8ed138b1048481314`.  A later redundant raw-screenshot request occurred after the user had changed media and is explicitly excluded; no source, installed file, playback mode or configuration change is attributed to this accepted capture.

#### Next Steps:

Keep the installed source-`205bbd7` core and native 480i mode unchanged.  When ready, run `/media/fat/games/MediaPlayer/the_big_lebowski_mpd_d2_5min.vob` once for five uninterrupted minutes with HDMI audio and check S/PDIF for a representative interval if convenient, then leave its terminal telemetry visible for one requested capture; afterward repeat the NARA MPD-D2 control.  Do not capture or interrupt unrelated playback, and do not change or rebuild the FPGA.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 775 COMMIT Unreleased 205bbd7 2026-08-30T14:09:33-07:00

#### Coming From:

Unreleased 205bbd7

#### Purpose:

Install the timing-clean source-`205bbd7` seed-19 RBF with an independently verified rollback and leave hardware acceptance pending.

#### Outcome:

At the user's explicit authorization, the archived 4,440,192-byte source-`205bbd7` seed-19 RBF is staged from the build PC and independently reconfirmed at SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  Absolute FTP inventory finds exactly one installed core, `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; independent readback proves that it contains the accepted 4,461,996-byte source-`cee1a9e` build at SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`.  That exact readback is preserved as `/media/fat/_MediaPlayer_Backups/MediaPlayer_205bbd7_pre_cee1a9e_162c788d.rbf`, and a separate absolute-path download compares byte-for-byte.  The single installed filename is then replaced in place with the source-`205bbd7` candidate; both the install helper's verification and a second independent absolute-path readback reproduce all 4,440,192 bytes and the complete `7f60ec43` hash.  No Main, helper, media, menu configuration or repository source changes, and the running FPGA remains unchanged until the user reloads the core.

#### Next Steps:

Reload MediaPlayer from the MiSTer menu so the installed source-`205bbd7` RBF configures the FPGA, retain native 480i mode, and begin with the NARA MPD-D2 five-minute control over HDMI while also checking S/PDIF for a representative interval.  If the control remains clean, test the Coming to America and Big Lebowski MPD-D2 VOBs in separate uninterrupted five-minute runs and preserve telemetry after each; accept the candidate only if video is stable, audio is continuous apart from the previously accepted allowance of one isolated FIFO underrun, and telemetry is clean.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 774 COMMIT Unreleased 205bbd7 2026-08-30T13:13:46-07:00

#### Coming From:

Unreleased 9f10b55

#### Purpose:

Repair the two seed-19 decoder setup-path families in the registered B-picture lookup implementation without changing its throughput, memory use or reconstruction behavior.

#### Outcome:

Source `205bbd7` cuts the two entry-773 timing cones without changing lookup latency or memory structures.  The fetcher now uses a synthesis-preserved one-bit descriptor occupancy register for response-side direct/pop selection while its multi-bit count remains only on request-capacity and accounting paths; zero-latency, delayed, backpressured and simultaneous issue/response protocol cases all pass.  The B engine captures field-DCT slot and destination-row geometry with the existing execution metadata and uses a constant luma plane for field-DCT launch addresses, removing live `blk[1]` from that failed address path.  Exhaustive B motion math, B field motion, field-motion plus field-DCT, interlaced field-DCT residual, interlaced field motion, mixed pixel oracle, cadence, reorder, timestamp, all reference-overlap cases and the complete native-480i suite pass.  The mixed oracle checks 423,936 samples with zero mismatches outside its established two-level bound, preserves 69,556 DDR reads and remains exactly 1,239,997 cycles.  Exact generic-content simulations complete Coming to America in 128,169,997 cycles or 43.6507 cycles per byte and The Big Lebowski in 136,499,997 cycles or 46.7185 cycles per byte; each completes all 24 P and 58 B pictures with every decoder, reconstruction, writer, presentation and publication error flag clear and remains below the 49.7-cycle real-time boundary.  At the user's explicit authorization, exactly one clean Quartus Prime 17.0.2 build of detached source `205bbd7` completes at pinned seed 19 with no reseed or second compile.  Analysis, fitting, assembly, TimeQuest and Phase-1P report extraction complete successfully using 33,760 of 41,910 ALMs, 52,284 registers, 4,181,443 memory bits in exactly 532 of 553 RAM blocks and 67 DSP blocks.  Every reported timing category is positive: worst setup 0.006 ns, hold 0.244 ns, recovery 4.342 ns, removal 0.500 ns and minimum pulse width 0.925 ns, with zero TNS; the targeted 60 MHz decoder setup domain improves to 1.463 ns with zero violated paths and the 54 MHz video domain is 1.792 ns with zero violated paths.  The preserved 4,440,192-byte RBF has SHA-256 `7f60ec43cfffa75108c39c7d21fff727c0f1dddccd844a318e1b7cc5795c6970`.  It remains archived only on the build PC and is not installed or launched on the MiSTer.

#### Next Steps:

Keep the currently accepted core installed and do not deploy the archived source-`205bbd7`, seed-19 RBF until the user separately authorizes installation.  After authorization, install and verify that exact hash, then run the NARA MPD-D2 control and the Coming to America and Big Lebowski MPD-D2 VOBs in native 480i, checking HDMI and S/PDIF and preserving telemetry after each uninterrupted five-minute run.  Accept the candidate only if video remains stable, audio remains continuous apart from the previously accepted allowance of one isolated FIFO underrun, and telemetry shows clean decoder, reconstruction, writer, presentation and publication state.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 773 COMMIT Unreleased 9f10b55 2026-08-30T07:19:22-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Use simulation-only B-picture stall attribution to select one direct zero-M10K throughput correction and one final FPGA build.

#### Outcome:

Source `9f10b55` implements an ordered lookup-issue cursor in the B raster engine and a throughput-one mode in the retained-footprint fetcher while preserving registered lookup addresses and data and adding no M10Ks.  The exact Coming-to-America and Lebowski three-second natural-content windows complete in 128,169,632 cycles and 136,495,456 cycles, or 43.65 and 46.72 cycles per input byte, improving total throughput by 22.8 and 20.5 percent over the registered baseline and clearing the calculated 49.7-cycle real-time boundary with all decoder, reconstruction, writer, presentation and cursor-order error flags clear.  Exact motion, field-DCT, cadence, reorder, timestamp, overlap and native-480i regressions pass; the mixed pixel oracle checks 423,936 samples with zero mismatches outside its established two-level bound and preserves 69,556 DDR reads.  Exactly one clean Quartus Prime 17.0.2 build is attempted at pinned seed 19.  Analysis, fitting, assembly and timing-report extraction complete, using 34,051 of 41,910 ALMs, 52,664 registers, 4,181,443 memory bits in 532 of 553 RAM blocks and 67 DSP blocks, but the build gate rejects the RBF because the 60 MHz decoder setup slack is negative 0.176 ns with 23 violated paths; hold, recovery, removal and minimum-pulse-width margins remain positive 0.242, 3.847, 0.528 and 0.925 ns, and the 54 MHz video setup margin is positive 2.654 ns.  The leading path runs from `block_fetcher1|descriptor_count[2]` to `block_fetcher1|word_data[20][24]`; a second violated family runs from `b_probe|blk[1]` into `fetch_launch_phase1_base_addr`.  The rejected 4,452,080-byte RBF has SHA-256 `95b109a92aec3b2c39304997c72fa51a391fbbdcbe05e811c307b497f1f1b136`; it is not installed, and no reseed or second compile is performed.

#### Next Steps:

Keep the accepted artifact installed on the test MiSTer and do not deploy this timing-failed RBF.  Use the extracted seed-19 path reports and RTL simulation to prepare a narrowly bounded timing correction that breaks the descriptor-control-to-`word_data` path and simplifies the `blk`-to-launch-address path without reducing the measured throughput, changing reconstruction semantics, adding M10Ks or changing the seed.  Present that source boundary for approval before any further implementation or Quartus compile; the next approved candidate must repeat the exact functional and natural-window simulation gates before one timing build is considered.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part1.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part2.svh
- rtl/mpeg2_new/mpeg2_h262_b_bidirectional_raster_engine_part3.svh
- rtl/mpeg2_new/mpeg2_h262_prediction_block_fetcher.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 772 COMMIT Unreleased 0a9d48a 2026-08-30T07:15:38-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Capture the controlled Coming to America MPD-D2 failure and distinguish audio starvation from visible video-cadence failure and from insufficient buffering.

#### Outcome:

The user leaves the completed uninterrupted S/PDIF run of `/media/fat/games/MediaPlayer/coming_to_america_mpd_d2_5min.vob` untouched for collection and reiterates that only audio stutters while video remains rock solid.  The 796,193-byte screenshot `/tmp/entry772_coming_mpd_d2_telemetry.png`, SHA-256 `250135e768052a0ccc58f951c1322fa361375f02a65d5e812929fe1c0fbdb05b`, has 64 valid schema-20 headers, indices and parity bits and matching checksum `c4aeaacf`; its sticky first-underrun snapshot occurs at 56.079121 seconds after accepting 55,768,576 clean-video bytes, with 1,671 displayed pictures and 1,670 swaps, consistent with real-time video cadence at the audible failure.  The decoder input is intrinsically stalled for 94.498 percent of session cycles, divided into 6.363 percent I, 22.237 percent P and 65.899 percent B-picture stall, while presentation hold contributes only 3.777 percent, destination hold is zero and presentation hold has scratch availability for only 668 cycles.  This differs from Lebowski's 85.208-percent intrinsic and 13.042-percent presentation split but preserves the common approximately 98.3-percent total inability to accept transport bytes and dominant B-picture contribution, disproving a third presentation scratch frame as a general correction.  The matching 7,598,795-byte helper log `/tmp/entry772_coming_mpd_d2_telemetry.log`, SHA-256 `ec8bb543428ab4f4b8f920e287b65dfad64ec622b23264ec67a3caf275a02c95`, names the exact VOB and S/PDIF path, eventually emits all 14,400,000 samples and submits all 362,080,761 bytes through the fast path, but requires 308.544 seconds; its worst 10-, 20- and 30-second transport windows are only 1.112, 1.120 and 1.122 MB/s against the approximately 1.207 MB/s real-time requirement.  The 16,384-frame audio FIFO already provides approximately 341 milliseconds of reserve, so more buffering would postpone rather than remove sustained starvation; the accepted fit uses 532 of 553 M10Ks, leaving 21, and no additional M10Ks are indicated.  This corrects entry 771's overly broad wording: decoder-side shared-transport backpressure starves ordered audio ingress, but the hardware evidence does not show visible video cadence loss.

#### Next Steps:

Keep the accepted seed-19 RBF, host binaries, ISO deployment and all existing FIFO depths unchanged.  The smallest useful correction cycle should target B-picture intrinsic decode throughput with zero new M10Ks, preserve reconstruction arithmetic and presentation behavior, and use the unused schema-20 telemetry words to attribute B stalls among compressed-bit parsing, residual replay, prediction and row-retirement waits if static analysis cannot justify a direct scheduling overlap.  Record and obtain approval for that source boundary before implementation, then run exact simulation regressions, one clean seed-19 Quartus build with full timing and resource gates, and the NARA control plus both natural-content VOBs through five-minute HDMI and S/PDIF validation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 771 COMMIT Unreleased 0a9d48a 2026-08-30T06:57:06-07:00

#### Coming From:

Unreleased 0a9d48a

#### Purpose:

Reject the natural-content MPD-D2 VOB gate and identify the repeatable S/PDIF collapse as sustained real-time decoder-throughput loss.

#### Outcome:

The user corrects the preliminary VOB acceptance: the NARA qualification VOB and existing MPG fixtures play perfectly, but `the_big_lebowski_mpd_d2_5min.vob` begins severe S/PDIF stutter with telemetry near 33 seconds and `coming_to_america_mpd_d2_5min.vob` near 56 seconds.  A controlled uninterrupted Lebowski rerun reproduces collapse to near silence, temporary full recovery, a second collapse and another recovery without reload or reboot.  The exact helper log names the correct VOB and S/PDIF path; by 205.999972 seconds it has emitted 9,460,224 samples against 9,887,998 wall-clock samples, a 427,774-sample or 8.91-second deficit, while its maximum video PTS represents only 197.397 seconds of media.  At 206.58 seconds Main has submitted 238,139,400 bytes, about 1.153 MB/s, entirely through the verified fast path.  Reanalysis of the earlier apparent Lebowski HDMI pass shows that it required 309.292 seconds to transport 300.038 seconds of media and accumulated the same approximately 426,000-sample scheduler deficit; schema-20 error `0x0400` is a sticky first-underrun indication, not a count proving only one isolated underrun.  In contrast, NARA remained about 21,000 samples ahead and completed in 300.006 seconds.  Independent FFprobe comparison finds matching continuous timestamps and required 8,000,000-bit/s, 720x480, 30000/1001 TFF properties across all three MPD-D2 VOBs, while the two passing natural-content MPG video payloads are only 5,398,682 and 6,525,205 bits/s.  The evidence therefore localizes the failure to content-dependent clean-video ingest or decoder drain throughput below real time on sustained natural-content 8 Mbps input, with the ordered helper scheduler then starving audio; it does not support file corruption, permanent FIFO fill, S/PDIF framing failure or authored timestamp discontinuity.  Captures `/tmp/entry771_lebowski_mpd_d2_spdif_stutter.png`, `/tmp/entry771_lebowski_mpd_d2_spdif_recovered.png` and `/tmp/entry771_lebowski_mpd_d2_spdif_second_collapse.png` hash `1a251f44`, `2adcdf3c` and `b6dd0351`; their corresponding helper-log snapshots hash `73638139`, `17344fcb` and `ddab1a0b`.  No installed file, repository source or target configuration changes, and ISO deployment is paused at the user's direction.

#### Next Steps:

Keep the accepted seed-19 RBF and all installed host binaries unchanged and do not proceed with ISO installation.  Use the retained natural-content streams and logs for an offline stage-throughput analysis, then propose the smallest measurable correction that raises sustained frame-picture MPD-D2 decode above real time without reducing the adopted constant 8 Mbps qualification requirement.  Any new diagnostic media, RTL instrumentation, timing-sensitive optimization or Quartus rebuild requires a separately recorded and approved commit boundary.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 770 COMMIT Unreleased 0a9d48a 2026-08-30T06:28:45-07:00

#### Coming From:

Unreleased 1e8c44f

#### Purpose:

Add a bounded unencrypted DVD ISO source that automatically plays the longest title through the existing Program Stream pipeline.

#### Outcome:

The user explicitly authorizes image-file playback while the final Coming to America VOB hardware run proceeds and supplies three full images on the authorized build PC.  Source `6af108f` adds `.iso` selection and `iso:` routing in Main, a rewindable helper source that uses pinned VideoLAN `libdvdread` 7.1.1 and `libdvdnav` 7.0.0 to read UDF and IFO metadata and expose the longest title in program-chain order, explicit scrambled-PES rejection, architecture documentation and a tracked patch that forces libdvdread's builtin unencrypted reader instead of linked or dynamically discovered libdvdcss.  The first native build exposed only a malformed upstream-patch hunk count, corrected by `0128efe`; debugger evidence then showed that libdvdnav 7.0.0 drops caller stream callbacks in `dvdnav_reset`, so `85ca285` safely reopens the same image and title on rewind.  Final source `0a9d48a` narrowly suppresses libdvdread's ignored x86-only `gcc_struct` attribute warning at the ARM helper boundary.  Native validation fully processes The Big Lebowski title 1, 7,036.1 seconds, 5,529,130,715 video bytes and 220,760 AC-3 frames with exit zero; bounded probes start clean decoding of Coming to America title 1 and correctly select Blazing Saddles title 2.  Exact-commit native, static ARM and pinned Main builds pass; the 817,700-byte helper hashes `b7ccc160`, has no dynamic section and no undefined `dlopen`, `dlsym` or dvdcss symbol, while the 1,170,340-byte Main hashes `01229bc5` and contains both the ISO selector vector and `iso:` route.  Menus, navigation controls, subtitles, track switching, direct optical-disc access and CSS remain unsupported, and no FPGA source, RBF or target installation changes.

#### Next Steps:

First capture and record the user's completed Coming to America VOB result without disturbing its target evidence.  Then preserve the installed helper and Main, install the exact `b7ccc160` helper and `01229bc5` Main with byte-identical readback, reboot to activate Main, place one supplied unencrypted ISO on MiSTer-accessible storage, and run the first hardware gate in Native 480i with HDMI before checking S/PDIF.  Do not rebuild or replace the accepted seed-19 FPGA artifact.

#### Files Modified:

- host/arm/ARCHITECTURE.md
- host/arm/Makefile
- host/arm/libdvdread-disable-css.patch
- host/arm/media_player_helper.c
- host/arm/media_player_protocol.h
- host/arm/media_source.c
- host/arm/media_source.h
- host/build_arm_stack.sh
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 769 COMMIT Unreleased 1e8c44f 2026-08-30T06:12:22-07:00

#### Coming From:

Unreleased 8623431

#### Purpose:

Pin fitter seed 19 in the source-controlled Quartus project without changing decoder capability or rebuilding the accepted FPGA artifact.

#### Outcome:

The user directs that decoder capability remain at the accepted boundary and explicitly requests correction of the repository QSF to the established fitter seed.  Source `1e8c44f` changes the sole `MediaPlayer.qsf` `SEED` assignment from 17 to 19 so a future clean build selects the proven seed by default; the exact diff contains one replacement line and no decoder, timing-constraint or project-setting change.  The installed and hardware-accepted RBF was already produced by overriding the fitter to seed 19 and passed complete timing, so this source-control correction neither modifies nor reconfigures that artifact.  No Quartus build or target installation is performed, and Main, helper, media, Native 480i configuration and the active two-title VOB tests remain untouched.

#### Next Steps:

Continue the two installed MPD-D2 VOB hardware tests one title at a time and preserve their completed screens for capture.  Do not run Quartus or replace the accepted installed seed-19 RBF now; a clean build and regression are required only when a new release artifact is intentionally produced from this updated project.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [ ] Built
- [ ] Passed

---

## 768 COMMIT Unreleased 8623431 2026-08-30T06:08:24-07:00

#### Coming From:

Unreleased 8623431

#### Purpose:

Create, verify and install five-minute MPD-D2 qualification VOBs for Coming to America and The Big Lebowski.

#### Outcome:

The user requests that the two remaining DVD sources be tested exactly like the accepted Blazing Saddles MPD-D2 VOB.  FFmpeg's DVD-video demuxer identifies title 1 as the main feature for both `/home/vash/Videos/Coming Toamerica Ac/VIDEO_TS`, 6,737.666667 seconds, and `/home/vash/Videos/the_big_lebowski.iso`, 7,036.100000 seconds, with 720x480 MPEG-2 video and English six-channel AC-3 first.  Their first five minutes are stream-copied without transcoding into isolated staging files of 222,027,776 bytes at SHA-256 `687bd2ebb757d4b34faf0f531e1f2ddb4c4e4747b1f33cd1da9aeb05b646d4cc` and 264,787,968 bytes at SHA-256 `8fe852c10630d989448e3fb6afedf9e48d82a255c58c02815be06ff0ca494afe`.  The committed `mpd-d2-create` tool produces separate 300.038401-second VOBs; independent `mpd-d2-verify` runs accept all 8,992 720x480, 30000/1001, top-field-first MPEG-2 Main Profile/Main Level pictures at 8 Mbps, all 9,375 stereo 48 kHz AC-3 frames at 256 Kbps, manifest provenance and complete software decode for each file.  `/media/fat/games/MediaPlayer/coming_to_america_mpd_d2_5min.vob` is 313,421,824 bytes with SHA-256 `38289443906634ea9b499511bbad080e60a3960b418c3995e80c3da0e60d839a`; `/media/fat/games/MediaPlayer/the_big_lebowski_mpd_d2_5min.vob` is 313,421,824 bytes with SHA-256 `12a9c19c9f8be8ba06d36056fea8aebd99aa70e9bc3416b593af008e32a054a6`.  Absolute target inventory proves both names absent before upload, and independent downloads reproduce every byte and both exact hashes.  Repository source, the installed seed-19 RBF, Main, helper, existing media and Native 480i configuration remain unchanged.

#### Next Steps:

Test one file at a time in Native 480i with `16:9`, Bob and HDMI.  Play Coming to America through its full five-minute EOF, verify picture, cadence, audio and synchronization, check S/PDIF for a representative portion, and leave the completed screen untouched for telemetry and helper-log capture.  Only after that result is captured, repeat the same full run and audio-output checks for The Big Lebowski so evidence cannot be mixed between titles.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 767 COMMIT Unreleased 8623431 2026-08-30T05:57:10-07:00

#### Coming From:

Unreleased 8623431

#### Purpose:

Accept corrected VOB selection and complete the retained frame-picture NARA MPD-D2 hardware playback gate.

#### Outcome:

After rebooting into the exact `61766c5e` Main built from source `8623431`, the user confirms that `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob` is visible, launches normally, and plays its complete five minutes with perfect picture and sound; the user also checks S/PDIF and reports that it works.  The 639,643-byte scaled EOF capture `/tmp/entry766_nara_mpd_d2_hdmi_pass.png`, SHA-256 `76724924c69d3c199fd1ea0ef2d83de3a4c874460d12ef2a53e9f928f40c790f`, and 405,141-byte native 720x480 capture `/tmp/entry766_nara_mpd_d2_hdmi_raw.png`, SHA-256 `f32983f568bae9e24bdad3359ccfabe4b12939a414cdb816d9524f84c03eb128`, visibly preserve a clean final frame.  All 64 schema-20 records have valid headers, indices and parity, and checksum `c46d8e97` matches; the no-progress EOF snapshot accepts 300,095,133 clean-video bytes, records 2,998 reference pictures, 8,991 displayed pictures and 8,990 swaps, and reports zero hardware error flags, zero presentation errors, zero transport blocks and zero audio FIFO underruns.  It records one 4,004,000-cycle cadence gap near displayed picture 77: the passive deadline record attributes the missed window to the candidate becoming ready 67,134 cycles later, with no input starvation or writer-capacity block, and the user reports no visible defect.  The 7,313,085-byte HDMI helper log `/tmp/entry766_nara_mpd_d2_hdmi_pass.log`, SHA-256 `68a8af73a3182273c54bf9ce47b9e872072190614c5dd854b88600e728f9498b`, names the exact VOB, selects decoded stereo PCM, emits all 9,375 AC-3 frames and 14,400,000 samples, reaches EOF, exits zero, and submits all 362,200,545 annotated transport bytes on the fast path.  This accepts source `8623431`, native VOB selection, the adopted frame-picture MPD-D2 fixture, HDMI and S/PDIF playback; field-picture MPEG-2 remains the previously disclosed deferred limitation.

#### Next Steps:

Prepare the final reproducibility and release-qualification boundary by pinning fitter seed 19 in the QSF, retaining Native 480i as the sole product mode, documenting the accepted MPD-D2 frame-picture scope and deferred field-picture limitation, and then performing a clean from-scratch seed-19 Quartus release build and regression gate before any version tag or GitHub release.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 766 COMMIT Unreleased 8623431 2026-08-30T05:41:38-07:00

#### Coming From:

Unreleased 65e8af3

#### Purpose:

Correct the incomplete MiSTer Main file-selector support that prevents installed `.vob` media from appearing in the MediaPlayer menu.

#### Outcome:

The exact 313,542,656-byte qualification file is installed as `/media/fat/games/MediaPlayer/nara_mpd_d2_qualification_5min.vob` with byte-identical target readback and SHA-256 `a7eb4c2fff0a4e15bc4ad9b2b2a3b4cff63ec87d79a59e8ba99fef7b6193cc0b`.  The `.vob`-capable Main from source `65e8af3` is installed at `/media/fat/MiSTer` with byte-identical readback and SHA-256 `40e15ff2c89dc1580a0bcb746deeb8186ebfcc0ef1155f6ac9ce17cba8125d41`, while the replaced Main is independently preserved under `_MediaPlayer_Backups`.  The user's hardware gate reports that the menu cannot see the new VOB.  Static inspection identifies the exact omission: `mediaplayer_handles_file()` accepts `.vob` after selection, but the MediaPlayer-specific three-character extension vector passed into `SelectFile()` remained `M2VMPGMP3WAVFLC` and therefore filtered VOB files before selection.  Source `8623431` adds only the missing `VOB` token to that vector.  A clean pinned Main rebuild from exact commit `8623431` passes on the authorized build PC and produces a stripped 1,170,340-byte ARM EABI5 hard-float executable with SHA-256 `61766c5eae1817607d6700b6403b59af1d05964c23cc2c8572afbb2ba03e19d3`.  The generated media, helper, FPGA and Native 480i configuration remain unchanged.

#### Next Steps:

Preserve the currently installed `40e15ff2` Main before replacing it with the exact `61766c5e` candidate, require byte-identical target readback, reboot to activate the corrected Main, and first confirm that the exact qualification VOB is visible and launches before resuming the five-minute HDMI and S/PDIF playback gates.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 765 COMMIT Unreleased 65e8af3 2026-08-30T05:19:43-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Add exact NARA MPD-D2 media creation and verification plus native `.vob` selection through the pinned MiSTer Main integration.

#### Outcome:

The user explicitly approved the exact frame-picture MPD-D2 qualification plan and deferred field-picture decoding as a disclosed limitation.  Commit `e6462db` added `.vob` to the pinned Main file dispatcher and added deterministic `mpd-d2-create` and strict `mpd-d2-verify` commands for the adopted NARA properties: an 8 Mbps single-pass MPEG-2 Main Profile/Main Level intermediate, 720x480 at 30000/1001, interlaced top-field-first frame pictures, documented 16-bit stereo PCM source, 48 kHz 256 Kbps constant-bit-rate AC-3 and VOB/Program Stream output.  Local syntax, rejection-path, full-decode, per-frame interlace and two-run byte-determinism checks passed with a generated two-second fixture.  The first pinned Main build exposed an incorrect new-file hunk count after the `.vob` line was added; commit `65e8af3` corrected only that patch metadata.  A fresh exact-commit build on the authorized build PC then passed and produced a stripped ARM EABI5 hard-float executable, 1,170,340 bytes, SHA-256 `40e15ff2c89dc1580a0bcb746deeb8186ebfcc0ef1155f6ac9ce17cba8125d41`.

#### Next Steps:

Generate the retained five-minute MPD-D2 qualification VOB from the validated Blazing Saddles source, require the committed verifier and a complete software decode to pass, and preserve its manifest and hashes.  Preserve and independently hash the installed MiSTer Main before replacing it with the built candidate, verify both Main and VOB by target readback, then reboot to activate Main and complete HDMI and S/PDIF hardware playback gates.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/media.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 764 COMMIT Unreleased cee1a9e 2026-08-30T05:14:01-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Capture and accept the complete five-minute Blazing Saddles hardware run and begin exact NARA MPD-D2 qualification work.

#### Outcome:

The user completes `/media/fat/games/MediaPlayer/blazing_saddles_first_5min.mpg` on the installed timing-clean seed-19 RBF in Native 480i at `16:9` and reports that picture and audio remain perfect through EOF, completing the requested three-title five-minute commercial-DVD compatibility set.  The 614,629-byte scaled capture `/tmp/entry764_blazing_saddles_5min_pass.png`, SHA-256 `fe6dee37ca7ae821f24e6695a2c8d86a2ca5a41e35d14dee7ab56ae33e19c04e`, and the 391,623-byte native 720x480 capture `/tmp/entry764_blazing_saddles_5min_raw.png`, SHA-256 `b225eaf2a3b6a0e7f45f1d761fa2b331cf3d0746a6a31497d652cafee6753251`, visibly preserve the clean final scene.  All 64 schema-20 telemetry records have valid headers, row indices and parity, and checksum `dd0752bc` matches; the no-progress EOF snapshot accepts 224,180,164 clean-video bytes, records 2,400 reference pictures, 7,194 displayed pictures and 7,193 swaps, and reports zero aggregate hardware errors, zero transport blocks and zero audio FIFO underruns.  The 14,514,247-byte helper log `/tmp/entry764_blazing_saddles_5min_pass.log`, SHA-256 `35be1c1d31a76a28dd94d4573cd452eda4ee7013902584234e36bc7260cce144`, names the exact file, selects HDMI decoded stereo PCM, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, reaches EOF, exits zero and submits all 286,285,586 transport bytes on the fast path.  The user authorizes the remaining adopted NARA MPD-D2 qualification steps; no source, RBF, helper, media or mode change occurs during this capture.

#### Next Steps:

Add deterministic media tooling that creates and strictly verifies a retained NARA MPD-D2 qualification VOB/Program Stream with MPEG-2 Main Profile/Main Level 720x480 constant-bit-rate 30000/1001 interlaced top-field-first video and two-channel 48 kHz 256 Kbps constant-bit-rate AC-3 from a documented 16-bit source.  Verify complete independent software decode and every machine-checkable profile property, retain exact hashes and provenance, install the resulting fixture with independent readback, and test it completely in Native 480i over HDMI decoded stereo and S/PDIF AC-3 passthrough.  Field pictures remain an explicit limitation and are outside this cycle.  After that hardware gate, pin fitter seed 19 in the QSF, perform the clean release build and timing analysis, and update stale release documentation.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 763 COMMIT Unreleased cee1a9e 2026-08-30T05:05:10-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Install and verify the approved five-minute Blazing Saddles main-feature compatibility stream for hardware testing.

#### Outcome:

FFmpeg's DVD-video demuxer selects title 2, the 5,567-second Blazing Saddles main feature, from `/home/vash/Videos/Blazing Saddles/VIDEO_TS` and stream-copies its first five minutes through the VOB/MPEG-2 program-stream muxer without transcoding.  The resulting `/tmp/blazing_saddles_first_5min.mpg` is 244,019,200 bytes, 300.149844 seconds and SHA-256 `e045ec4d52f5fee6bb2e57d887341697244c0886d35b734131ff171101535879`; it contains exactly 7,195 original 720x480 anamorphic 16:9 MPEG-2 pictures and 9,375 original 48 kHz six-channel English AC-3 frames.  Complete software video and audio decode exits zero; FFmpeg's null-output muxer reports repeated equal AC-3 timestamps at several DVD cell boundaries without any codec decode failure, so that authored timing remains intentionally present for the hardware compatibility test.  Absolute FTP inventory proves `/media/fat/games/MediaPlayer/blazing_saddles_first_5min.mpg` absent before upload, and independent absolute-path download reproduces all 244,019,200 bytes, the exact `e045ec4d` hash and a byte-identical comparison.  The pre-existing `blazing_saddles_main_av_15min.mpg` remains untouched, as do both earlier five-minute files, the DVD sources, repository source, FPGA, seed-19 RBF, Main, helper and Native 480i configuration.

#### Next Steps:

Keep the installed seed-19 RBF and Native 480i mode unchanged, select `16:9`, begin with HDMI audio, and play `/media/fat/games/MediaPlayer/blazing_saddles_first_5min.mpg` once from beginning to end.  During that same run, verify S/PDIF for a representative portion if convenient, then report whether launch, picture integrity, cadence, audio and synchronization remain perfect for the full five minutes and whether playback returns normally at EOF.  Leave the completed screen untouched for immediate screenshot, telemetry and helper-log capture.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 762 COMMIT Unreleased cee1a9e 2026-08-30T05:00:54-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Prepare the remaining commercial-DVD five-minute compatibility test and record fitter seed 19 as the required setting for future builds.

#### Outcome:

The user confirms that the accepted RBF was built with fitter seed 19 and directs that seed 19 be used going forward, resolving the reproducibility choice left by entry 761; this decision does not require rebuilding or replacing the already accepted installed artifact during the present media-only test.  Read-only inventory on the build PC identifies Blazing Saddles as the sole remaining DVD source under `/home/vash/Videos`, and FFmpeg's DVD-video demuxer identifies title 2 as the 5,567-second main feature with 720x480 anamorphic 16:9 MPEG-2 video and English six-channel AC-3 as its primary audio.  The approved plan is to stream-copy only the first five minutes of that main feature into an MPEG program stream, verify its exact streams, duration and complete software decode, install it under a new absolute filename in `/media/fat/games/MediaPlayer`, and independently verify the installed bytes before requesting one Native 480i hardware run.  The DVD sources, repository, FPGA, installed RBF, Main, helper and existing media remain unchanged at this proposal boundary.

#### Next Steps:

Create `blazing_saddles_first_5min.mpg` on the build PC from DVD title 2 with only the primary MPEG-2 video and English AC-3 stream, without transcoding.  Require a duration of approximately 300 seconds, correct 720x480 anamorphic 16:9 metadata, a clean complete software decode and recorded size and SHA-256; then upload it to `/media/fat/games/MediaPlayer/blazing_saddles_first_5min.mpg` and prove an independent readback byte-for-byte before asking the user to play it once in Native 480i at 16:9.  Before any later Quartus build, change the repository QSF from seed 17 to the now-required seed 19 as part of that build's source boundary.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 761 COMMIT Unreleased cee1a9e 2026-08-30T04:52:39-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Capture and accept the complete five-minute Coming to America hardware run on the timing-clean seed-19 build.

#### Outcome:

The user completes `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` on the installed 4,461,996-byte seed-19 RBF with SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6` in Native 480i, selects `16:9`, and reports that the menu, video, cadence and audio are perfect, including both HDMI and S/PDIF output.  The 760,234-byte scaled capture `/tmp/entry761_coming_to_america_5min_pass.png`, SHA-256 `3264087262cba98c011e63e6948f9e43bb6d74c88b583977feb916025b1e9b26`, and the 481,208-byte native 720x480 capture `/tmp/entry761_coming_to_america_5min_raw.png`, SHA-256 `c2811cbe6df8b1c1468724ddf1f4ac57ee401547cda8e8e278496c1cc167f312`, visibly preserve a clean final frame at the requested aspect ratio.  Every header, row index and parity bit in the raw capture's 64-record schema-20 telemetry is valid, and its XOR checksum `a5aeeea2` matches.  The end-of-run no-progress snapshot accepts 202,450,560 clean-video bytes, records 2,539 reference pictures, 7,193 displayed pictures and 7,192 swaps, and has zero aggregate hardware error flags, zero transport blocks and zero audio FIFO underruns.  The matching 8,501,618-byte helper log `/tmp/entry761_coming_to_america_5min_pass.log`, SHA-256 `d4c3693bd3392938dbd25931deefcb907c90ce0afcba36ad42a97ef2977d1ce1`, names the exact five-minute file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, emits all 9,375 audio frames and 14,400,000 PCM samples, reaches EOF, exits zero, and submits all 264,556,180 transport bytes on the fast path.  This hardware result accepts the progressive-film field-DCT admission correction, the simplified production menu, 16:9 presentation, HDMI audio, S/PDIF audio and the timing-clean seed-19 artifact without any source, RBF, helper, media or mode change during the test or capture.

#### Next Steps:

Treat source `cee1a9e` and the installed seed-19 `162c788d` RBF as the accepted Coming to America compatibility boundary, preserve the verified `bc79d56a` rollback, and do not reopen the corrected progressive-film admission path based on this title.  Before a future clean build intended for release reproducibility, explicitly decide whether to pin fitter seed 19 in `MediaPlayer.qsf` and rebuild; otherwise await the user's next compatibility target or release instruction.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 760 COMMIT Unreleased cee1a9e 2026-08-30T04:40:08-07:00

#### Coming From:

Unreleased cee1a9e

#### Purpose:

Install the timing-clean seed-19 RBF with an independently verified target rollback and begin the approved Coming to America hardware validation.

#### Outcome:

After the user instructs continuation because seed 19 passes timing, local artifact verification reconfirms the 4,461,996-byte `output_files/MediaPlayer.rbf` at SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`.  Absolute FTP inventory finds exactly one installed core, `/media/fat/MediaPlayer_20260829_b9c2657.rbf`; independent readback proves that it is the expected 4,456,984-byte `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837` timing-clean known-good build.  That exact readback is uploaded under the new rollback path `/media/fat/_MediaPlayer_Backups/MediaPlayer_cee1a9e_pre_seed19_bc79d56a.rbf`, and a second independent download reproduces the complete `bc79d56a` hash.  The single installed filename is then replaced in place with the seed-19 RBF, and the install helper's independent absolute-path readback reproduces all bytes and exact `162c788d` hash.  No Main, helper, media, configuration or source file changes, and the current FPGA remains unchanged until the user reloads the core.

#### Next Steps:

Reload MediaPlayer from the MiSTer menu so the newly installed RBF configures the FPGA.  Confirm the visible menu contains `Aspect Ratio` with `4:3` and `16:9`, `Deinterlacer Mode` with `Bob` and `Weave`, the existing `Audio Test` choices, and `Audio Output` with `HDMI` and `S/PDIF`, with no 800x600 or timing-pattern options.  Select `4:3`, `Bob` and `HDMI`, then play the unchanged `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` once for five minutes and report whether it launches immediately and whether video, cadence, HDMI audio and synchronization remain clean.  Leave the completed screen untouched for capture if any failure occurs; do not replay Big Lebowski unless this run succeeds and a control is materially needed.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 759 COMMIT Unreleased cee1a9e 2026-08-30T03:36:32-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Admit legal progressive-film pictures using field DCT, simplify the product menu, remove the obsolete 800x600 diagnostic mode, and produce a timing-clean Quartus build.

#### Outcome:

Source `cee1a9e` removes only the erroneous `frame_pred_frame_dct` prerequisite from progressive-film admission and documents that a clear flag admits macroblock-level field DCT and prediction handled by the existing downstream parser.  The menu now exposes `Aspect Ratio` as `4:3` or `16:9`, `Deinterlacer Mode` as `Bob` or `Weave`, the unchanged `Audio Test` choices, and `Audio Output` as `HDMI` or `S/PDIF`; Bob and 4:3 are the zero/default selections.  The obsolete 800x600, native timing-pattern and pattern-motion controls and top-level pattern mux are removed, Native 480i no longer depends on their saved status bits, and no hidden stale selection can reactivate them.  The exact 91,436-byte Coming to America first-I/P prefix accepts every byte, retires all 30 P rows, publishes both references and one swap, and completes with zero decoder, raster, writer or presentation errors.  Film cadence, reorder timestamps, reference-overlap ownership, native field order, all repeated-field cache cases, combined P/B field motion plus field DCT, interlaced P/B field-DCT residuals, B field motion, progressive mixed-raster pixels, native timing, startup, cache refill, generation, presentation integration, deadline and cadence-profiler regressions all pass.  A clean GitHub worktree build with the pinned `260829` build ID compiles at 34,156 of 41,910 ALMs, 52,529 registers, 4,181,443 memory bits and 67 DSP blocks.  Default fitter seed 17 misses only thirteen generic MiSTer `ascal` HDMI paths by at most 0.084 ns while decoder and video setup remain positive 0.986 and 3.164 ns; command-line seed 18 improves the global miss to 0.042 ns but is rejected.  At the user's instruction to stop after the current reseed and build, seed 19 is the final attempt and passes the complete gate with setup, hold, recovery, removal and minimum-pulse-width margins of positive 0.124, 0.231, 3.936, 0.541 and 0.925 ns; decoder and video setup are positive 0.462 and 2.378 ns.  The 4,461,996-byte timing-clean RBF has SHA-256 `162c788d2fa121f340ab6649ef94b25e97f31a44ee552928bb89e32b147059a6`; its 253,929-byte STA report has SHA-256 `b3fe3cd5f8b8a71dac42df1cfdf63387fd7fa4120713550a5caa789bf28c4b38`.  The prior `bc79d56a` RBF is preserved locally as `output_files/MediaPlayer-bc79d56a-known-good.rbf`.  No RBF is installed on the MiSTer, no further reseed or source cleanup is attempted, and the repository QSF remains at seed 17 because the user stops work after this seed-19 artifact.

#### Next Steps:

Stop after the completed seed-19 build as instructed.  Do not install the RBF, reseed again, edit shared MiSTer scaler RTL, remove stale SDC lines or change the QSF without a new user instruction.  When work resumes, decide explicitly whether to deploy the fully identified seed-19 `162c788d` artifact as built or first pin seed 19 in `MediaPlayer.qsf` and repeat a clean full build for source-controlled placement reproducibility.  The first hardware validation of this functional change should use the unchanged five-minute Coming to America program stream in Native 480i, verify the requested menu labels and both aspect/deinterlacer choices, and leave the known-good `bc79d56a` rollback intact; do not repeat Big Lebowski unless Coming succeeds and a control is materially needed.

#### Files Modified:

- MediaPlayer.sv
- rtl/mpeg2_new/mpeg2_h262_frontend.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 758 COMMIT Unreleased 4e54e9d 2026-08-30T03:31:07-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Capture the completed five-minute Big Lebowski HDMI control and record the user's separate S/PDIF result on the unchanged timing-clean core.

#### Outcome:

The user authorizes capture after the complete HDMI run of `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` and explicitly reports that S/PDIF also works perfectly.  The 550,558-byte scaled capture `/tmp/entry758_big_lebowski_5min_hdmi_pass.png`, SHA-256 `fba8e5c8bb85fba397ea29883fa789e461592bf70edf685f4cb6fdab6466731e`, visibly preserves the clean intended final toilet scene without corruption.  The matching 7,647,957-byte helper log `/tmp/entry758_big_lebowski_5min_hdmi_pass.log`, SHA-256 `b5ab8d05ef08507b7688ac764aea6433549f3b93f5434b645cd686a9df2917c7`, names the exact five-minute file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, emits all 9,375 AC-3 frames and 14,400,000 PCM samples, carries 244,700,748 video bytes with 616 timestamps, reaches helper EOF and exits zero after submitting all 306,800,752 in-band transport bytes with every byte on the fast path.  The native 720x480 capture `/tmp/entry758_big_lebowski_5min_hdmi_raw.png` is 381,718 bytes with SHA-256 `77b6f4d082444683401c38af7f75762f5dcd54c76b3d4ef645c558c98e30939b`.  Its checksum-valid schema-20 telemetry is an earlier sticky fatal snapshot rather than a terminal snapshot: at approximately 173 seconds it records exactly one PCM FIFO underrun, error flag `0x0400`, and freezes its counters at 151,212,826 accepted clean-video bytes even though the visible video and helper continue through the five-minute end.  Before that event it records no syntax, phase-one, prediction, inverse-quantization, IDCT, reconstruction, DDR store/cache, presentation, PCM-protocol or cache-overlap error and no transport block.  The user reports no audible HDMI defect, while the independent S/PDIF run is explicitly perfect, and explicitly accepts a single HDMI FIFO underrun for now.  This accepts the complete five-minute Big Lebowski video, HDMI and S/PDIF playback boundary; the one-count FIFO event remains documented without blocking the current video-compatibility work.  No source, RBF, helper, media or mode changes during either run or capture.

#### Next Steps:

Do not replay Big Lebowski solely to reconfirm video or audio.  Keep the explicitly accepted one-count HDMI FIFO-underrun observation separate from the proven Coming to America video admission defect and off the current critical path.  After user approval, implement entry 757's one-line `phase1_native_film_i_frame` correction and deterministic progressive-film field-DCT I/P regression, run the focused and existing regression sets, then perform a clean Quartus build and full timing analysis before any target deployment.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 757 COMMIT Unreleased 4e54e9d 2026-08-30T03:26:58-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Reproduce the Coming to America first-GOP failure offline, identify its exact decoder prerequisite, and propose the narrow production correction without changing the repository RTL or installed core.

#### Outcome:

The preserved 202,450,560-byte elementary video is cut only at authored picture boundaries and terminated with `sequence_end_code`: the exact first-I control is 71,636 bytes with SHA-256 `cb100a65df844a372376b30e4dcf0ef5b960fb1c4200300a35b6b0b4522e4914`, and the exact first-I/P reproducer is 91,436 bytes with SHA-256 `7530a3ce8a89ea29bf93188894a07c1e3f8af6958f4c48e87627b8c7f150b4a2`.  The unchanged RTL replay of the I/P prefix fails after exactly 73,774 accepted bytes, identical to hardware.  It has parsed all 45 macroblocks of P slice row 1 but enters the P raster with `reference_valid=0`, raising raster-engine source 9 and top-level phase-one source 2 before any P row or picture publishes.  This proves that neither dense slice syntax nor the P macroblock parser is the initiating defect.  The opening reference I picture has `progressive_sequence=0`, `progressive_frame=1`, `chroma_420_type=1` and `frame_pred_frame_dct=0`.  Although the existing I parser and raster already implement the resulting macroblock `dct_type`, `mpeg2_h262_frontend.sv` admits a progressive film I picture in an interlaced sequence only when `frame_pred_frame_dct=1`; consequently this legal reference I is skipped, and the following P picture exposes the missing reference.  This is consistent with project references H262-028, H262-032 and H262-033: an interlaced sequence may contain a progressive frame picture, `frame_pred_frame_dct=1` is a restriction to frame DCT/prediction rather than a validity requirement here, and 4:2:0 requires `chroma_420_type` to equal `progressive_frame`.  In an isolated build-PC worktree only, removing `frame_pred_frame_dct` from `phase1_native_film_i_frame` changes no parser, raster, prediction or presentation logic.  The same exact I/P prefix then accepts all 91,436 bytes, applies 1,565,007 cycles of decoder backpressure while the I reference completes, retires all 30 P rows, publishes two reference pictures, presents one swap and finishes with zero decoder, raster, writer or presentation errors.  The 2,248-byte baseline log `/tmp/entry757_baseline_first_ip.log` has SHA-256 `199716d784264291cd5ba707f90691e38a8e5e2dd421f060eaf7559e1281ca0a`; the 4,190-byte diagnostic-gate log `/tmp/entry757_gate_probe_first_ip.log` has SHA-256 `80a6390b02173d61bd1645726efa13b9595217d1a8d3d1cbb7ca1ac9b5841732`.  Production source, the installed RBF, helper, target files and target mode remain unchanged.

#### Next Steps:

After user approval, remove only the erroneous `frame_pred_frame_dct` conjunct from `phase1_native_film_i_frame`.  Add a deterministic, source-generated progressive-film field-DCT I/P regression that proves the I reference publishes before P-row execution, then run it alongside the existing progressive-film frame-DCT control, interlaced field-DCT, P/B field-motion plus field-DCT, cadence, reference-overlap and presentation regressions.  If those pass, commit the RTL and regression change, perform one clean Quartus build plus full timing analysis on the build PC, install the timing-passing RBF with rollback preserved, and hardware-test the unchanged Coming to America five-minute file followed by a Big Lebowski control.  Do not deploy the temporary diagnostic worktree or ask the user to replay either file before a timing-clean production build exists.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 756 COMMIT Unreleased 4e54e9d 2026-08-30T03:16:42-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Extend corrected-core hardware validation to two five-minute commercial-DVD feature openings in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` from beginning to end and reports that it works perfectly, accepting five continuous minutes of video, cadence, HDMI AC-3 decode and A/V synchronization on the exact installed `bc79d56a` candidate.  The user then plays `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg`, reports failure at launch and leaves the exact run untouched for collection.  The valid helper log names that file, selects HDMI decoded stereo PCM and AC-3 private substream `0x80`, and shows no helper launch, container-recognition or audio-routing failure.  The 25,318-byte scaled screenshot `/tmp/entry756_coming_to_america_5min_run.png`, SHA-256 `4fc4d3fcc3b8206f7780705652446419fed7173468f13a93eeddb83ee07da0ba`, preserves the black no-picture result; its matching 601,366-byte helper log has SHA-256 `8a16db2b3f6d6a298559f309ad14e8e533e6ee641bd884197477884c429b3782`.  A separate raw 9,313-byte telemetry screenshot `/tmp/entry756_coming_to_america_5min_run_unscaled.png`, SHA-256 `db61b053496660d3bccb1f9a13a07b4ac274053690d53272cc9b3b2d7d370d68`, decodes with a valid schema-20 checksum: only 73,774 clean-video bytes are accepted, zero reference, B or display pictures complete, first and last presentation cycles remain zero, sequence end and quiet state are false, and snapshot reason is fatal/no-progress.  The sole hardware error is `0x0002`, `phase1_probe_error`; metadata shows the decoder has entered P temporal reference 2 before stopping.  There is no audio underrun, PCM protocol error, presentation error, cache overlap error, transport block or timestamp conflict.  Exact H.262 inventory explains why the earlier approximately twelve-second excerpt can pass while this feature opening fails.  The passed excerpt begins with true interlaced pictures (`progressive_frame=0`, `frame_pred_frame_dct=0`), while the passed Big Lebowski opening begins with progressive pictures that disable interlaced macroblock tools (`progressive_frame=1`, `frame_pred_frame_dct=1`).  This failing opening begins with progressive pictures that admit interlaced DCT and motion syntax (`progressive_frame=1`, `frame_pred_frame_dct=0`); its dense first I picture has 30 slices with maximum 2,400-byte payload, followed immediately by the failing P temporal reference 2 with 30 slices and maximum 2,112-byte payload.  The evidence therefore establishes a new first-GOP phase-one boundary in the progressive-frame/interlaced-tool combination or its dense first-P syntax; it does not reopen the corrected negative-odd field-motion result and does not implicate the program-stream or AC-3 launch path.  Two earlier collections made while the user was viewing other content are explicitly excluded from evidence.  No source, RBF, Main, helper, playback mode or installed media changes during this result.

#### Next Steps:

Preserve the exact failing program stream and installed RBF.  Before changing production source, extract a byte-exact elementary prefix through the first failing P picture and reproduce the `phase1_probe_error` offline with the existing detailed source/detail observability.  Compare an exact first-I-only control, the failing first-I/P prefix, the passed twelve-second excerpt and the passed Big Lebowski opening to separate progressive-frame plus interlaced-tool admission from slice-density or a specific macroblock mode.  Propose the narrow correction and its focused regression expansion for user approval before editing RTL or building another RBF; do not request another hardware replay of the unchanged failing file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 755 COMMIT Unreleased 4e54e9d 2026-08-30T03:02:28-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected DVD opening over HDMI and S/PDIF in Native 480i, then prepare the requested five-minute feature tests.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/dvd_opening_original.mpg` on the exact installed `bc79d56a` candidate in Native 480i and reports that video and audio are both perfect over HDMI and S/PDIF.  At the user's explicit request, `/tmp/entry755_dvd_opening_hdmi_spdif_native480i_pass.png` captures the clean completed Universal frame at 432,337 bytes with SHA-256 `29e524999c6a26dbd437b07a8a5a13e56f6a72fb47996d43ef0de4ac74ce9a8d`.  This accepts the known DVD program-stream and AC-3 boundary on the corrected core without changing the RBF, Main, helper or Native 480i mode.  The user next requests five minutes each of The Big Lebowski and Coming to America.  FFmpeg's DVD-video demuxer auto-selects the confirmed 7,036.1-second Big Lebowski feature from `/home/vash/Videos/the_big_lebowski.iso` and the confirmed 6,737.667-second Coming to America feature from `/home/vash/Videos/Coming Toamerica Ac/VIDEO_TS`; each first-five-minute excerpt is remuxed by stream copy to an MPEG-2 VOB/program stream with its original 720x480 MPEG-2 video and six-channel AC-3 audio.  The resulting Big Lebowski file is 264,787,968 bytes, 300.149833 seconds and SHA-256 `8fe852c10630d989448e3fb6afedf9e48d82a255c58c02815be06ff0ca494afe`; the Coming to America file is 222,027,776 bytes, 300.099789 seconds and SHA-256 `687bd2ebb757d4b34faf0f531e1f2ddb4c4e4747b1f33cd1da9aeb05b646d4cc`.  Complete software video/audio decode exits zero for both.  Authenticated absolute FTP installs the two previously absent filenames shown below, and independent downloads compare byte-for-byte with their staged sources.  The user reports independently backing up and deleting every other file in `/media/fat/games/MediaPlayer`; treat that cleanup as intentional and do not restore removed media.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Select HDMI audio and play `/media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg` once from beginning to end.  Report whether video motion and cadence remain clean for the full five minutes, whether audio remains clean and synchronized, and whether playback returns normally at the end.  Test `/media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg` only after recording the first result so any failure remains attributable to one title.

#### Files Modified:

- /media/fat/games/MediaPlayer/the_big_lebowski_first_5min.mpg
- /media/fat/games/MediaPlayer/coming_to_america_first_5min.mpg

#### Status:

- [x] Built
- [x] Passed

---

## 754 COMMIT Unreleased 4e54e9d 2026-08-30T02:51:05-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected original authored I/P/B stream in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` from beginning to end in Native 480i and reports that it looks and runs perfectly, with no large block corruption, freeze or stutter.  This is the original 6,751,008-byte authored elementary stream containing all 361 pictures, comprising 27 I, 115 P and 219 B pictures over its normal approximately twelve-second presentation.  It therefore extends the accepted exact P81 and B-stripped I/P results through the complete forward- and bidirectionally-predicted hardware path at normal coded duration.  At the user's explicit request, `/tmp/entry754_authored_ipb_native480i_pass.png` captures the clean terminal frame at 533,067 bytes with SHA-256 `13a9d27889ebf0ded78b4f44abcace0cbbfb205687fe29d74ea9f67de1597f15`.  No RBF, media, Main, helper or configuration change occurs.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Select HDMI audio and play `/media/fat/games/MediaPlayer/dvd_opening_original.mpg` once from beginning to end, then report whether video, cadence and audio are all clean.  This checks the known DVD program-stream transport and audio integration boundary on the corrected core without changing playback mode or requesting another elementary-video diagnostic.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 753 COMMIT Unreleased 4e54e9d 2026-08-30T02:48:43-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected full authored I/P reference chain in Native 480i.

#### Outcome:

The user plays `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` from beginning to end in Native 480i and reports that it looks perfect with no large block corruption.  Its fast run is expected: the byte-exact diagnostic retains 27 I and 115 P pictures but removes all 219 B pictures, so its 142 coded pictures present in about 4.7 seconds at 30000/1001 rather than the original twelve-second duration.  This is fixture construction, not a decoder cadence failure.  At the user's explicit request, `/tmp/entry753_authored_ip_native480i_pass.png` captures the clean terminal frame at 532,998 bytes with SHA-256 `6761b2b91538abccc26827c966813d6fbf855f66fd5801701f8cb6cb97597fa4`.  Together with the exact P81 acceptance, this clears the corrected forward-predicted reference chain through the complete authored I/P derivative.  No RBF, media, Main, helper or configuration change occurs.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s.m2v` once from beginning to end and report whether it runs for its normal approximately twelve seconds without large block corruption, freeze or stutter.  This restores the original 219 B pictures and is the next full authored I/P/B hardware gate; the elementary video stream contains no audio.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 752 COMMIT Unreleased 4e54e9d 2026-08-30T02:45:48-07:00

#### Coming From:

Unreleased 4e54e9d

#### Purpose:

Accept the corrected P81 hardware frame in Native 480i and make that the sole product video mode.

#### Outcome:

Absolute FTP readback proves `/media/fat/MediaPlayer_20260829_b9c2657.rbf` already contains the exact timing-passing 4,456,984-byte candidate with SHA-256 `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837`, while the verified rollback `/media/fat/_MediaPlayer_Backups/MediaPlayer_20260829_8fd16e8_pre_7a25189_677f2e11.rbf` retains the prior 4,471,792-byte `677f2e11` build.  No redundant write is performed.  The user reloads the corrected core, plays the exact P81 checkpoint in Native 480i and reports that the thin horizontal corruption crossing the right-hand subject's mouth is gone.  At the user's explicit request, `/tmp/entry752_p81_native480i_pass.png` captures the clean held frame at 490,336 bytes with SHA-256 `c31737d705a4915af0afe62c79c327ae76bccbc563d3f14348cc865204f69df2`.  This hardware result accepts the negative-odd field-motion predictor correction at the exact first-failure boundary.  The user also confirms that development and the final product use Native 480i only; the `800x600 Diagnostic` scaler mode has no product purpose and must not be requested in future tests.

#### Next Steps:

Keep the exact installed RBF and Native 480i mode unchanged.  Play `/media/fat/games/MediaPlayer/coming_to_america_interlaced_12s_authored_ip_only.m2v` once from beginning to end and report whether any large block corruption remains during or after the shiny-hat passage.  This extends the accepted P81 boundary through the longer authored I/P reference chain; do not use or request diagnostic mode.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 751 COMMIT Unreleased 4e54e9d 2026-08-30T02:38:19-07:00

#### Coming From:

Unreleased 7a25189

#### Purpose:

Qualify the cleaned field-motion correction with the known timing-clean placement and prepare its corrected RBF for hardware test.

#### Outcome:

Following repository cleanup at `9aeabac`, source `4e54e9d` pins build ID `260829`, the last timing-clean placement input, without changing decoder RTL.  A checksum-only comparison proves the complete functional local source identical to the clean build-PC tree except for later `.ai` metadata and generated build files.  Quartus Prime 17.0.2 completes successfully at 34,094 of 41,910 ALMs, 52,524 registers, 4,181,443 memory bits in 532 RAM blocks and 67 DSP blocks.  Full timing has zero negative slack and zero setup TNS: HDMI setup is positive 0.055 ns, decoder setup is positive 0.454 ns, video setup is positive 2.346 ns, and worst-case hold, recovery, removal and minimum-pulse-width margins are positive 0.243, 3.376, 0.526 and 0.925 ns.  Fresh isolated reruns of P field motion, bidirectional B field motion, combined field motion plus field-DCT, interlaced P/B field-DCT residuals and the progressive mixed-raster control check 4,052,736 reconstructed samples within their established exact or two-level bounds with zero decoder, raster, writer or presentation errors.  Film cadence, all reference-overlap and reorder cases, timestamps, native field order and all four TFF/BFF repeated-field cache cases also pass.  The resulting 4,456,984-byte `output_files/MediaPlayer.rbf` has SHA-256 `bc79d56a00c69188cd6dc3117944ccaa3a80fa5ba8cfc6dd45f451e4f1593837`; it is not installed on the MiSTer.

#### Next Steps:

Preserve this exact RBF and do not rebuild or reseed it.  After a separate installation authorization, back up the currently installed core, deploy this candidate with exact readback, reload it, and play the existing byte-exact P81 checkpoint in `800x600 Diagnostic` with Weave.  Inspect the held frame for the mouth-level horizontal corruption; if it is absent, continue with a longer authored I/P stream to confirm that later reference propagation is also corrected.

#### Files Modified:

- tools/build.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 750 COMMIT Unreleased 7a25189 2026-08-30T02:38:18-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Correct negative odd vertical field-motion predictor division in the production P and B decoders.

#### Outcome:

The exact byte-verified P81 production replay first reaches the user's mouth-level corruption with a maximum sample error of 124 and traces the predictive chain back to field-motion reference addressing rather than inverse quantization, IDCT, residual addition or saturation.  The P and B parsers stored vertical predictors in frame units but converted them to field units with truncation toward zero; H.262 `DIV` instead rounds toward minus infinity, so each negative odd predictor selected a reference row one field sample too low and the error propagated through later P references.  Source `1fbe21a` replaces both conversions with signed arithmetic right shifts, and `7a25189` corrects the associated B-path comment without functional change.  Replaying the exact 942,600-byte P81 fixture after the correction accepts all 44 pictures and 43 swaps with every lifecycle error clear, checks all 19,180,800 predictive samples with zero mismatches above the established one-level transform tolerance, reduces maximum P/P81 error to one and produces an empty high-delta P81 trace.  The remaining harness nonzero exit is confined to two earlier independent intra-IDCT comparisons with established maxima of four and seventeen and is not part of the predictive corruption.  The exact P80 and P81 fixture hashes remain `ae8e43eb` and `37fa9030`.

#### Next Steps:

Retain the arithmetic correction and its exact P81 evidence, keep the cleaned repository structure, and close timing without changing decoder behavior.  Require the focused interlaced P/B field-motion and field-DCT regressions, the progressive control and the broader presentation suite to remain within their established bounds before preparing any RBF for the user.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_core_probe_part0.svh
- rtl/mpeg2_new/mpeg2_h262_p_wide_motion_syntax_probe_part0.svh

#### Status:

- [x] Built
- [ ] Passed

---

## 749 COMMIT Unreleased 6196869 2026-08-29T20:50:07-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Authorize an exact offline production-path replay and bounded correction for the first P81 mouth-level corruption.

#### Outcome:

The user explicitly authorizes the entry-748 next step.  Use the byte-verified P81-ending authored I/P checkpoint, its clean consecutive P80 predecessor and independently decoded FFmpeg YUV 4:2:0 pixels.  First adapt or invoke the existing full-frame production-path harness to reproduce P81 without changing decode RTL, locate the first differing component and coordinate, and correlate it with the exact owning macroblock syntax and reconstruction arithmetic.  Only after a deterministic mismatch exists may source change, and any correction must remain bounded to its proven cause, add exact P80/P81 regression coverage, preserve the existing interlaced P/B field-motion and field-DCT regressions, and avoid Quartus until simulation is pixel-exact.  No source, FPGA, RBF, Main, helper, installed media or configuration change occurs in this authorization entry.

#### Next Steps:

Run the exact P81 production-path replay with a software oracle and machine-readable pixel report.  Establish the first mismatch before editing RTL, then inspect the associated prediction, residual, inverse-quantization, IDCT and saturation values.  Implement only the correction justified by that trace and run the exact P80/P81 gate plus the focused and broader decoder regressions.  Record source and test outcomes in new entries; do not start Quartus or request another MiSTer test in this cycle.

#### Files Modified:

None.

#### Status:

- [ ] Built
- [ ] Passed

---

## 748 COMMIT Unreleased 6196869 2026-08-29T20:47:36-07:00

#### Coming From:

Unreleased 6196869

#### Purpose:

Record the user's exact spatial localization of the first P81 corruption.

#### Outcome:

While the captured P81 terminal frame remains displayed, the user identifies the first corruption precisely as the thin horizontal line crossing the mouth of the man on the right.  This is the onset within P81, not merely a later consequence elsewhere in the frame.  The location is visible in the preserved `/tmp/entry747_p81_first_corrupt.png` evidence and replaces the broader earlier description of a central disturbance.  Combined with clean P80 and the exact byte-preserved P81 checkpoint, this provides both temporal and spatial bounds for offline comparison: the first affected authored picture is P81 and its first visible damaged region is the right-hand subject's mouth-level horizontal strip.  The clean schema-20 lifecycle and zero fault counters from entry 747 remain unchanged.  No new capture, source, FPGA, RBF, Main, helper, installed media or configuration change occurs.

#### Next Steps:

Do not request another hardware checkpoint.  Replay exact P81 after its clean P80 reference in the production-path RTL simulation and compare against the software oracle, prioritizing the mouth-level macroblock row and finding the first differing luma or chroma sample within that row.  Correlate the first mismatch with the owning macroblock's prediction mode, vectors, quantiser scale, coded-block pattern, DCT type, coefficient values and reconstruction saturation.  Require a bounded reproduction and pixel-exact regression before any RTL correction or Quartus build; the next user test should be a corrected RBF only after those gates pass.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
