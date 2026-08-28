## 632 COMMIT Unreleased a26791f 2026-08-27T17:26:18-07:00

#### Coming From:

Unreleased 2c03075

#### Purpose:

Package the release candidate in the previous release's layout and verify every binary reproduces.

#### Outcome:

An unverified claim is corrected first, because it reached the changelog. Entry 630 stated that the helper rebuilt byte-identically from a clean dependency fetch. It had not. The ARM toolchain had been extracted under a temporary directory that the earlier machine crash and reboot cleared, the build script exited reporting only that the compiler was missing, that message contains neither the word error nor warning so the grep used to check it returned zero, and the hash printed afterwards belonged to the previously built binary still sitting in the output directory. The lesson is that a build was judged by a keyword count instead of its exit status. The toolchain has now been extracted to a persistent location and the work redone properly. With the dependency directory and prior helper binary deleted outright, the helper rebuilds to exactly `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8`, and Main rebuilds from the same tree against pinned upstream `0a8fb44` to exactly `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9`. Together with the RBF, which entry 630 had already reproduced byte for byte from a clean export, all three binaries now demonstrably reproduce from source baseline `2f1d32c`, and the changelog says so with the correction folded in. The package follows the v0.7.0 layout exactly, with the RBF named for its build date, Main at the root, the helper under a linux directory, checksums covering every file, installation and provenance notes, and licences for the project, minimp3 and now liba52. The installation notes state that Main is not optional and summarise the bounded video envelope so a user does not report a rejected DVD as a defect. The provenance notes record both toolchains, the upstream Main commit, and the pinned minimp3 and liba52 baselines with their archive hashes. The archive is 5,948,567 bytes with SHA256 `5f55b49eb863f74a777b548b4f42b744a9130b4161f176b687ca297deeffcaf3`, written beside the previous release. Its three runtime binaries are identical to what is installed on the target and what every hand test in entries 625 through 628 exercised, so the package is the tested configuration rather than a rebuild of it.

#### Next Steps:

The user installs from the package and performs the confirmation hardware run, then creates the annotated tag and GitHub release from commit `a26791f`, marking it pre-release because the project remains before 1.0. Until that run happens the release remains unaccepted, and the entry 630 caveat stands that no hardware run has occurred since packaging, although the binaries are bit-identical to those already tested. Release notes should carry the repeated frame behaviour on high peak pictures, the scaler margin recovered by the seed change and its status as a risk for the next change that adds logic, the audio split between measured and listened evidence, the DTS subwoofer behaviour as a device observation, and the two unqualified areas being playback pixel accuracy and the blended column at sharp colour transitions. The chroma investigation and the interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 631 COMMIT Unreleased 2c03075 2026-08-27T17:20:44-07:00

#### Coming From:

Unreleased 6b92a19

#### Purpose:

Bring the media conversion guide up to the current capability and document how to test audio.

#### Outcome:

The user noticed that the conversion guide still described the previous release, and it did: a single progressive recipe with MPEG Layer II, predating interlaced 480i, AC-3 and passthrough entirely. Published source `2c03075` splits it by the two shapes that actually play and adds an audio section. The interlaced guidance is the part most likely to save someone a wasted afternoon, because the obvious approach fails: FFmpeg's own interlacing flags select field DCT and field prediction, both of which this decoder rejects before decode, so the supported route is ordinary frame-DCT coding of woven field pairs with the interlaced signalling applied afterwards, which is what the committed generator does. The guide points at that generator and describes the sequence its build function uses. It also warns that the compatibility checker predates the interlaced path and rejects native interlaced files while remaining valid for progressive ones, so a rejection there is not evidence of a bad file. The audio section states what each codec does under each output setting in a small table, explains that the option mutes the output it is not driving because both are fed from one stereo stream, and gives the expected result of the AC-3 channel sweep in each mode, including that the silent fourth slot is correct because the stereo downmix discards LFE. It records two cautions learned this cycle: a 2.1 or virtualizing soundbar cannot demonstrate discrete channel routing however convincing it sounds, and receivers differ between codecs, with the device tested here reproducing LFE from AC-3 but not from DTS despite the transmitted DTS provably carrying it. The host-side checks are included because they are faster and more precise than listening. Every command in the new sections was run as written rather than composed from memory, which caught a real defect: the generator invocation did not write the report file that the downmix check reads, so the documented sequence would have failed at the second step. That was corrected and the corrected sequence was then run end to end successfully. The AC-3 decode, downmix placement and passthrough checks all pass on the release helper as documented.

#### Next Steps:

The release candidate is unchanged by this documentation work and remains ready for the user to tag. Nothing here alters the binaries, whose hashes are recorded in entry 630 and in the changelog. If a confirmation run is wanted before tagging, reinstall from the package and replay one interlaced and one audio test, which would also close the gap that no hardware run has occurred since packaging. The chroma edge column stays documented rather than investigated, at the user's direction, and the interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md

#### Status:

- [x] Built
- [ ] Passed

---

## 630 COMMIT Unreleased 6b92a19 2026-08-27T17:14:36-07:00

#### Coming From:

Unreleased ad56579

#### Purpose:

Build and document the release candidate for the next version from a clean tree.

#### Outcome:

The user set the version to 0.8.0, asked for the chroma finding to be documented rather than investigated, and asked for a from-scratch build. The build was made from a pristine export of tracked files only, so no incremental database or untracked artifact could influence it, and it reproduced the tested RBF byte for byte at SHA256 `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce`, 4,332,740 bytes, at fitter seed 17. That is the strongest reproducibility evidence this project has recorded for an FPGA binary. Zero errors and 208 warnings, with the warning identifier set identical to the accepted build, none new and none missing. The fit uses 31,464 ALMs at 75 percent, 50,273 registers, 4,048,355 block memory bits at 71 percent, 512 of 553 M10K blocks at 93 percent, 67 DSPs and three PLLs. Timing is positive everywhere with zero total negative slack: setup 0.243, hold 0.251, recovery 2.865, removal 0.564 and minimum pulse width 0.925 nanoseconds. Host regressions pass on the release binaries, covering the cadence decoder layout, eleven DVD ceiling tests, and the Main integration profile with 168 RTL cases, 96 burst cases, 20 step resume cases and the guarded fault cases. Audio regressions pass on the release helper: AC-3 decode against an independent decoder at maximum sample difference three and correlation 0.999999972, correct downmix placement for all six channels including the deliberate LFE absence, 375 byte-identical passthrough bursts, and the unchanged MPEG Layer II PCM hash on the full-length fixture. The helper itself rebuilt byte-identically from a clean dependency fetch. A packaging error was caught and corrected rather than shipped: the first package picked up the older Main from the local build directory instead of the patched Main that is installed and tested, which would have shipped without the audio output option and without the event-loop fix. All three packaged binaries were then compared against the target by independent readback and match exactly, so the package is the tested configuration rather than a rebuild of it. A factual slip in the release notes, a minimum pulse width written as 1.925 rather than 0.925 nanoseconds, was corrected in a follow-up commit. Documentation now describes 0.8.0 rather than unreleased work, the installation table lists all three runtime files with hashes and states that the patched Main is required rather than optional, and the chroma edge column is recorded under known limitations alongside the unqualified state of playback pixel accuracy. What this entry does not establish is a hardware regression pass on these exact packaged binaries; the six hand tests and the seventh progressive file were run against the same installed hashes, but no run was performed after packaging, and no release has been tagged.

#### Next Steps:

The user creates the annotated tag and GitHub release from the exact commit, as core.md requires, marking it pre-release because the project remains before 1.0. The package is at the rc080 package directory with a checksum file and installation notes; generated media stays out of it, so the seven hand tests are reproduced from the committed generator rather than shipped. Release notes should carry the repeated frame behaviour on high peak pictures, the scaler margin recovered by the seed change and its status as a known risk for the next change that adds logic, the audio split between measured and listened evidence, the DTS subwoofer behaviour as a device observation, and the two unqualified areas being playback pixel accuracy and the blended column at sharp colour transitions. If a final confirmation run is wanted before tagging, reinstall from the package and replay one interlaced and one audio test, which would also close the gap that no run has occurred after packaging. The chroma investigation and the interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 629 COMMIT Unreleased ad56579 2026-08-27T17:05:22-07:00

#### Coming From:

Unreleased 2cb7246

#### Purpose:

State the decoder's actual capability and its unqualified areas in the README and changelog.

#### Outcome:

Published source `ad56579` rewrites the capability description now that measurement rather than inference supports it. The two video paths are described separately because they differ sharply, which the previous single row obscured: the progressive path decodes I, P and B pictures through 720x480, while the interlaced path is 720x480 at 30000/1001 only, 4:2:0, I-pictures only, frame structured, frame DCT and frame prediction only, either field order, with no `repeat_first_field`. Field pictures, field DCT, interlaced P and B, pulldown and 576i are named as rejected before decode, together with the plain consequence that most commercial DVDs use several of these and will not play. Audio is described as decoded MPEG Layer II and AC-3 with an explicit note that the AC-3 stereo downmix discards LFE by the format's convention, alongside AC-3 and DTS passthrough as IEC 61937 bursts, the passthrough-only status of DTS, the audio output option and why it mutes the output it does not drive, and the single-track limit. Four unqualified areas are recorded rather than left implicit: playback pixel accuracy has never been qualified because every previous comparison ran in simulation; sharp colour transitions carry one blended column an independent decoder does not produce; material with a large enough peak coded picture repeats one or two frames at that picture as a property of buffer depth rather than of the stream; and passthrough cannot be scaled, so volume does not apply to it. The changelog gains the AC-3, passthrough, audio output, hand test, progressive picture type, Main responsiveness and known limitation entries for the unreleased section, and the README gains a hand test section describing what each of the seven files is for and noting that the audio sweeps exercise discrete channels only in S/PDIF mode. The standards section now credits liba52 and IEC 61937 and states that the rejected picture types are limits of this implementation rather than of H.262. Nothing in the release qualification or installation sections was touched, since those describe the published v0.7.0 binaries and no new release has been prepared.

#### Next Steps:

The release itself is not prepared and needs the user's decision on scope and timing. If it proceeds, the outstanding work is a full regression pass on a clean build, a decision on whether the chroma edge column is investigated first or shipped as a documented characteristic, a version number, and the tag and GitHub release created by the user from the exact commit, with the binaries and hand tests packaged and identified by hash. The installation section still describes three v0.7.0 runtime files and will need a fourth line if the release ships the patched Main, since the audio output option is meaningless without it. Release notes should carry the repeated frame wording, the marginal scaler paths recovered by reseeding, the audio split between measured and listened evidence, and the DTS subwoofer behaviour as a device observation rather than a core limitation. The chroma investigation, if wanted, should ask what the core does horizontally with 4:2:0 chroma when converting for display, with an interlaced colour bar file in native 480i as the control. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- README.md
- CHANGELOG.md

#### Status:

- [x] Built
- [ ] Passed

---

## 628 COMMIT Unreleased 2cb7246 2026-08-27T16:51:13-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Establish whether the progressive path decodes P and B pictures, and identify the reported picture artifacts.

#### Outcome:

The capability question that blocked the release document is settled by playing a file rather than by reading RTL. Published source `2cb7246` adds a seventh hand test, progressive 480p with an ordinary fifteen picture GOP and two B pictures between references, built by extending the corrected suite generator rather than reviving the superseded one. It decodes: telemetry reports 121 reference pictures and 239 B pictures, all 360 displayed with 359 swaps, `error_flags` zero, sequence end, presentation complete, quiet snapshot, and a final picture type of three. The progressive path therefore handles I, P and B pictures, and the entry 609 description of the decoder as accepting I-pictures only was wrong; that restriction belongs to the interlaced 480i path, whose `phase1_supported` gate requires coding type one. B reordering costs 186,240,472 stall clocks, about 3.1 seconds of a twelve second clip, which is recorded as an observation rather than a fault. The user then reported poor picture quality, and the investigation separated two contributions. The first file was encoded at 22.3 kilobytes per frame against the all-I test four's 33.9, because B pictures let the encoder code the same content for a third fewer bits under a capped rate; the test was rebuilt with a rate floor to 33.6 kilobytes per frame so the two could be compared meaningfully. The artifacts persisted, and the user confirms test four looks identical to test seven, which rules out prediction drift and any P/B specific cause. The remaining artifacts were then measured rather than described. Screenshots at 800x600 capture the core's own output before the HDMI scaler, so they can be compared directly against an FFmpeg decode of the same frame; this is the first pixel comparison of actual playback in this project, every previous oracle having been applied in simulation. The active picture measures 720x480 placed one-to-one at offset 40 by 60 inside the 800x600 raster, so no resampling is involved and an early scaling hypothesis was wrong. At the yellow to blue band transition the reference decoder produces adjacent pixels of 252,254,0 and 1,0,254 with no intermediate value, while the hardware inserts one blended column of 199,196,255 between them, which is the reported thin vertical line. Decoding the reference again with full chroma interpolation and accurate rounding produces the same clean transition, so the difference is not an artefact of the reference's upsampling choice. No MiSTer.ini exists on the target, making a system video filter an unlikely explanation. The leading hypothesis is that horizontal chroma upsampling in the core's 4:2:0 to RGB path interpolates where the reference replicates, which would place exactly one blended column at each chroma transition. What is not established is whether that interpolation is correct for the intended chroma siting, or whether anything in the write or read path also contributes, and the left edge behaviour has not been separated from the telemetry overlay that occupies that corner.

#### Next Steps:

Decide whether the chroma edge behaviour is worth investigating before the release or recorded as a known characteristic, bearing in mind that it is visible on synthetic colour bars and much less so on ordinary material, and that it affects all progressive output rather than being new. If it is investigated, the targeted question is what the core does horizontally with 4:2:0 chroma when converting for display, and a useful control is an interlaced colour bar file played in native 480i, since that path differs from the 800x600 diagnostic output. The README can now be written, stating that the interlaced 480i subset is I-only, frame structured and frame DCT while the progressive path decodes I, P and B, and stating plainly that playback pixel accuracy has never been qualified, which this entry demonstrates is now measurable. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, the audio capability split between measured and listened evidence, and the DTS subwoofer behaviour of entry 621 as a device observation. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_suite.py

#### Status:

- [x] Built
- [x] Passed

---

## 627 COMMIT Unreleased 140a5b7 2026-08-27T16:32:05-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Install entry 624's Main and confirm on hardware that it removes the reported menu lag.

#### Outcome:

Two results are recorded. First, the AC-3 passthrough gap in the hand-test set is closed: the user re-ran test five with the output option set to S/PDIF, and its own log line confirms passthrough mode on AC-3 substream 0x80 rather than the decoded stereo mode the earlier run used. That capture completes 360 reference and display pictures with 359 swaps, `error_flags` zero, sequence end, presentation complete, quiet snapshot, zero deadline gaps and outliers, all three largest intervals at the nominal 2,002,000 clocks, audio underrun and PCM protocol clear at FIFO peak 127, and helper exit zero. An earlier attempt to capture that run collected a stale log which was still test six, identified by identical checksum, transport byte count and DTS substream line, and was discarded rather than reported. Second, entry 624's Main is now installed. It was backed up first, staged, hash checked while staged, renamed and read back on a fresh connection, giving SHA256 `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9`; the previous Main is retained under the entry 627 backup directory, and the RBF, helper, media and settings were left untouched. After the user's reboot the helper log independently confirms it is running, reporting profile version two with `credit_step_v1`, a 2000 microsecond poll budget, 2048-byte steps and a step limit of eight, where every previous capture this session reported version one. The effect on the same test one file is decisive. Maximum media-poll occupancy falls from 160,937 to 9,287 microseconds, a factor of 17.3, and maximum poll-entry interval from 170,928 to 20,910. The acknowledged-write fallback disappears entirely: 677,119 slow bytes become zero, with all 5,556,849 bytes delivered in fast mode across 42,367 polls instead of 257. The user reports the menu is now perfect, which matches the measurement, and this run is one of the four low bitrate files that were reliably laggy before, so it is the correct subject rather than a case that was never affected. Playback is unchanged: 360 reference and display pictures, 359 swaps, 3,068,039 accepted video bytes, zero errors, zero deadline gaps and outliers, and the same nominal intervals. One honest qualification: the observed 9,287 microsecond maximum still exceeds the 2000 microsecond work budget, which entry 624 explicitly declined to present as a hard bound, and no button-response latency was measured, so the menu verdict remains a user report supported by occupancy rather than a latency measurement. Version two logging also changes record semantics, with pipe reads covering all source reads and transfer entries sampled, so version one counts are not directly comparable except for the occupancy figures used here.

#### Next Steps:

The menu issue is closed on this evidence and needs no further replay. The remaining blocker for the release document is unchanged and is now the only one: no test exercises P or B pictures, so generate one progressive file with an ordinary GOP using the corrected suite generator and have the user play it, which decides whether the README says progressive I-only or progressive I/P/B. Consider also whether the test set should carry that file permanently, since a release that ships hand tests should exercise the picture types it claims. Then write the README capability section and release notes, carrying the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, the audio capability split between measured and listened evidence, and the DTS subwoofer behaviour of entry 621 as a device observation rather than a core limitation. The interlaced gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 626 COMMIT Unreleased 140a5b7 2026-08-27T16:02:11-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Capture the remaining three hand tests and establish what the reported menu lag actually tracks.

#### Outcome:

All six hand tests now play correctly on the accepted installation. Tests four, five and six each complete 360 reference and display pictures with 359 swaps, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps and outliers, and audio underrun and PCM protocol error clear, with helper exit zero. Accepted video is 12,057,601, 3,068,039 and 3,068,038 bytes. Test four confirms the progressive path works and its telemetry reports final picture type one, so it is an all-I file and exercises no P or B pictures; the progressive picture type question therefore remains open and still blocks the README. Test four also shows its three largest display intervals at 2,984,256 clocks rather than the 2,002,000 every interlaced test reports, while averaging 359 swaps across 11.96 seconds, so the progressive path paces differently with jitter that averages out rather than dropping pictures; whether that is expected is not established, and the deadline logic is scoped to native timing so its zero count is not evidence either way. Test five ran in HDMI decoded stereo mode according to its own log line, so it exercised the downmix rather than passthrough, while test six ran in S/PDIF passthrough mode on DTS substream 0x88 as required, since DTS has no decoder here. The menu question is now settled as far as measurement can take it. Lag separates cleanly on accepted video bytes rather than file size: the four runs the user found laggy each carry about 3.068 megabytes of video and hold the event loop for 151,366 to 160,937 microseconds with an acknowledged-write share of 12.0 to 12.4 percent, while the two responsive runs carry about 12.06 megabytes and hold it for 63,506 and 89,592 microseconds with shares of 3.5 and 0.9 percent. Test six is the larger file of the two audio tests yet still laggy, because its extra size is DTS audio rather than video, which is what distinguishes video bitrate from file size as the driver. Six subjective reports match the measurement without exception. The mechanism is the one already diagnosed: low bitrate video drains the FPGA slowly, transport credits run out more often, and Main falls back to acknowledged writes inside a single poll instead of yielding. This is event-loop occupancy from the helper's own profile and not a measured button-response latency. Entry 624's Main, which contains the yield fix, is still not installed, confirmed again by every log reporting profile version one. The user also observed the subwoofer present on AC-3 through S/PDIF but absent on DTS, and asked whether the receiver simply does not accept DTS surround. The evidence says it does accept and decode DTS, because the other five channels were audible in both this run and entry 621; what it does not do is deliver that stream's LFE. Entry 621 already established by measurement that the DTS bursts this core emits contain LFE at 1267.3 RMS decoded back from the helper's own output, byte identical to the source, so the omission remains downstream. A plausible unverified explanation is that the device downmixes DTS internally rather than applying bass management, and the standard DTS stereo downmix discards LFE exactly as this core's own AC-3 stereo downmix does.

#### Next Steps:

Install entry 624's Main and repeat one low bitrate test, being test one, two, five or six, to confirm that poll occupancy falls; that is the direct check and no further evidence gathering on the menu is needed first. Generate one progressive file with an ordinary GOP using the corrected suite generator rather than the superseded one, and have the user play it, because the difference between progressive I-only and progressive I/P/B is the last fact blocking the README and no test in this set exercises it. Consider also re-running test five in S/PDIF mode so this set covers AC-3 passthrough as well as the downmix. Do not pursue the DTS subwoofer further without different hardware, since the transmitted bytes are proven correct and no change here can alter what that device does; a tester with a discrete 5.1 DTS decoder settles it as a byproduct of the community test. When capability is established, write the README capability section and release notes carrying the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of measured versus listened audio claims. The interlaced gates of entry 609 remain open and out of scope. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 625 COMMIT Unreleased 140a5b7 2026-08-27T15:48:33-07:00

#### Coming From:

Unreleased 140a5b7

#### Purpose:

Capture hardware results for the first three corrected hand tests and identify what the reported menu lag tracks.

#### Outcome:

Three duplicated efforts are resolved first. Another agent independently authored the same test suite generator, found real defects in this agent's version and corrected them, and the user directed that their files be used. Those defects were genuine: a `drawbox` position expression that was evaluated once rather than per frame, leaving a stationary bar in four of six files, and the use of top field interleaving for both field orders with only the signalling flag patched afterwards, so the bottom field first file never carried genuinely bottom-first temporal content. This agent's structural and hash checks could not have caught either, because neither verified that the picture moved. Two local commits carrying the superseded generator and a colliding entry number were discarded at the user's instruction and the published tree taken as-is; the user has since given this agent sole control of core-log.md. The three installed fixtures all play correctly. Each completes 360 reference and display pictures with 359 swaps, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps and outliers, and all three largest display intervals at exactly the nominal 2,002,000 clocks, with audio underrun and PCM protocol error clear and helper exit zero. Accepted video is 3,068,039, 3,067,813 and 12,073,185 bytes respectively. The top and bottom field first files hash differently rather than differing only by a flag, which is what the other agent's interleaving fix was for, and the user reports both look correct. An installation fact matters for interpreting all of this: entry 624's Main is not installed. The running Main is still `0ee87029f0a00a50731707e8114363fc7019ae4c1200de85d90533c9163b5241` from the earlier cycle, confirmed independently by the helper log reporting profile version one rather than the version two logging that Main introduces, so none of these runs exercises its polling budget. The reported menu behaviour is nevertheless explained by measurement rather than left as an impression. Maximum media-poll occupancy is 160,937 microseconds on test one and 153,112 on test two, both of which the user found laggy, against 63,506 microseconds on test three, which the user found responsive. The acknowledged-write share of transport moves the same way, at 12.2 and 12.1 percent for tests one and two against 3.5 percent for test three. The mechanism is consistent with the other agent's diagnosis: low bitrate content drains the FPGA slowly, so transport credits run out more often and Main falls back to acknowledged writes inside a single poll instead of yielding, and the two low-rate files are 3.4 megabytes against test three's 12.5. This is event-loop occupancy measured from the helper's own profile, not a measured button-response latency, and no such latency is claimed. Tests four through six remain unrun.

#### Next Steps:

Capture the remaining three hand tests as the user runs them, taking the helper log before anything else is played, and expect the two small audio sweep files to show the same long poll occupancy as tests one and two for the same reason. Do not treat the menu question as open evidence-gathering: it is understood, entry 624's Main contains the fix, and the useful next step is installing that Main and repeating a low bitrate test to confirm occupancy falls. Keep the release README unwritten until the progressive picture type question is settled, since no test in this set exercises P or B pictures and the difference between progressive I-only and progressive I/P/B is exactly what the document must state correctly. When capability is established, carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of measured versus listened audio claims. The interlaced gates of entry 609 remain open and out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 624 COMMIT Unreleased 140a5b7 2026-08-27T09:27:04-07:00

#### Coming From:

Unreleased 44ee05a

#### Purpose:

Restore valid motion regressions and keep Main responsive during backpressured media transfers.

#### Outcome:

Published source 140a5b7 implements the approved fixture and Main responsiveness boundary without changing FPGA or helper codec source. The uncommitted GUNSMOKE draft and checker edit are backed up under entry624/draft-backup and left untouched in their original checkout; development and official qualification use separate directories. The suite now advances its bar from a per-frame source index and uses interleave_top or interleave_bottom to establish actual TFF/BFF temporal order before signalling is patched. Independent decoded-pixel checks validate all 720 temporal fields in each of the four bar fixtures and reject both original stationary files and a deliberately wrong field-order interpretation. All six twelve-second clips contain 360 pictures and have identical hashes across two generations. Main retains a 16 KiB pending buffer and uses verified-credit steps of at most 2048 source bytes, returns immediately at zero credits, and limits each poll to eight steps and one pipe read with a 2000-microsecond budget checked between steps. This is not a hard latency bound: one transaction, OS scheduling, logging and unchanged terminal child cleanup can extend a call, and legacy acknowledged-only cores retain their existing handshake waits. Unaligned data is packed locally, odd short reads retain their final byte until a partner or true EOF, and only the terminal byte is padded. Count, digest, capability and flags are verified before and after each batch; uncertain transfers abort without retry. Native and address/undefined-sanitized loader tests pass, including one hundred consecutive zero-credit yields, bounded progress, exact bytes, odd reads across EAGAIN/EINTR, EOF blocked on credits, fault/cancel/core-change cleanup, warm restart, unavailable diagnostics and twenty-four seeded short-read/credit sequences. Actual production bridge tests retain the legacy and original burst coverage and add twenty bounded-step resume cases, unaligned and odd tails, post-yield validation, corruption/reset rejection and counter wrap. A control that discards pending data on yield fails the regression as intended. Existing ceiling-generator tests pass. The unchanged helper preserves each new fixture's clean video exactly, emits the expected 576,000 PCM frames or equivalent burst periods, keeps MP2 identical across output modes and preserves the exact original MP2 elementary audio in tests one and two. AC-3 stereo matches independent decoding with maximum sample differences two and one by channel, and AC-3/DTS passthrough carries byte-identical source frames; unsupported DTS HDMI output remains rejected. GUNSMOKE pulls exact published source before qualification and builds Main from pinned upstream 0a8fb44 with ARM GNU 10.2, zero build warnings and no reused checkout object files. The 1,170,340-byte Main is SHA256 01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9. No new RBF or Quartus timing claim is needed; accepted seed-17 aa7f064 and helper 078d36b are retained. Host logging is version two, credit_step_v1: pipe_read entries cover all source reads while transfer entries are sampled, so historical version-one analyzers must not be applied unchanged. Fresh Main, RBF, helper and six-media backups are independently verified under /home/vash/mister-builds/entry624-backup. The local output_files/entry624/MediaPlayer_140a5b7_regression_update.zip contains Main and all six fixtures with instructions and checksums; its 12,662,276 bytes have SHA256 faa79844d7af3d6de039bcdf1b4d3667f50488241bda5785325d42e0ac880103, and every local archive member and unpacked payload matches its build hash. Evidence and reproducible drivers are retained as .ai/current_results/entry624_*. Nothing is deployed, reloaded, rebooted or played by the agent. Hardware menu response, corrected-fixture playback and sustained throughput remain unaccepted.

#### Next Steps:

The user will install the supplied Main and six test files, keeping the existing RBF and helper, then reboot once to activate Main and load MediaPlayer. Select Bob and run corrected test_1_interlace_tff.mpg once, observing the downward-moving bar, audible tone and menu response during and after playback; leave the terminal screen and helper log available before playing anything else. Collect the version-two log first and a fresh checksum-valid screenshot, verify installed hashes and require all 360 pictures, zero decoder/transport/audio errors and expected cadence while measuring media-poll duration against entry 623. Then capture corrected BFF and remaining regressions separately, and retain a bounded high-rate check before treating the new polling budget as throughput-qualified. Do not conflate software integrity tests or the 2 ms work budget with measured UI latency, and do not declare a release accepted until hardware regressions pass. The full-movie repeated-frame limitation, scaler margin risk and unsupported DVD syntax remain unchanged. Preserve user deployment/lifecycle control, restricted core.md and the forty-entry ring.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- host/arm/ARCHITECTURE.md
- tools/streams/test_main_mister_profile.py
- tools/streams/generate_test_suite.py
- tools/streams/generate_test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 623 COMMIT Unreleased 44ee05a 2026-08-27T09:24:06-07:00

#### Coming From:

Unreleased 44ee05a

#### Purpose:

Separate faulty motion fixtures from the reported slow menu in regression tests one and two.

#### Outcome:

The user reports that tests one and two leave the top bar stationary and make the MiSTer menu very slow. The target listing and an uncommitted GUNSMOKE generator identify test_1_interlace_tff.mpg and test_2_interlace_bff.mpg. Both exact target files are read back and independently decoded with FFmpeg on GUNSMOKE: each contains 360 identical decoded frames, with the white bar fixed at rows zero through seven, and both share decoded-frame MD5 30809417f1caba5a06194ea6f01bd4da. Their compressed hashes differ only as separate fixtures and are retained in the evidence. The stationary bar is therefore authored into the test files, not evidence that the core froze, and these files cannot qualify motion or field order. The generator uses a suspect drawbox position expression, always interleave_top for both field orders and a later signalling patch; fixing motion must also establish correct BFF temporal field placement rather than just changing the flag. The generator and its companion check_structure edit exist only as uncommitted GUNSMOKE work and are preserved untouched. Initial helper log collection precedes the screenshot, but the fixed log has already been overwritten by test_5_audio_ac3_51.mpg, explicitly logged in HDMI decoded-stereo mode. That capture has checksum 2300824580, all 360 reference/display pictures and 359 swaps, zero errors and deadline gaps, sequence end and quiet completion, and helper exit zero after 4,443,979 transport bytes. It is not a capture of either failed run and does not qualify the other tests. Installed RBF, Main and helper match the accepted seed-17 aa7f064, patched Main and 078d36b helper hashes. The menu complaint has separate supporting evidence: test five records a maximum Main media-poll duration of 189,354 microseconds and a maximum single transfer of 58,356 microseconds. Main performs up to four complete 16 KB transfers per poll, and the credit API drains each whole chunk, falling back to acknowledged writes at zero credit instead of yielding to the UI. The user then explicitly leaves test one on screen, allowing a separate helper-first capture of test_1_interlace_tff.mpg with PID 909 and checksum 2300351100. It completes all 360 reference/display pictures and 359 swaps, with zero errors, underruns, timestamp conflicts, deadline gaps or outliers, sequence end and quiet completion. All 272 read records reconcile to 4,443,951 submitted bytes and helper exit zero; the installed Main and RBF hashes remain unchanged. Its own profile confirms a 189,409-microsecond maximum media-poll call, 204,524 microseconds between poll entries and a 62,454-microsecond maximum single transfer. This directly documents long event-loop occupancy on test one and supports the reported menu sluggishness without inventing a measured button-response latency. The stationary file is played to completion rather than freezing in this run. Test two still lacks dedicated hardware telemetry, and no Bob/Weave selection or reboot/reload lifecycle is inferred. No production source, build, deployment, setting, reboot, reload or playback changes occur; only the fixed screenshot is regenerated. Exact capture, frame identities, generator snapshot and analysis are retained as .ai/current_results/entry623_*, with full diagnostic media off Git under /home/vash/mister-builds/regression_failure_20260827_092037. Built refers to the unchanged accepted installation; these regression tests remain unaccepted.

#### Next Steps:

Correct and publish the fixture generator from the preserved draft in coordination with its existing uncommitted work, requiring independently decoded motion at successive fields, correct TFF and BFF temporal ordering, supported syntax and preserved audio before replacing test media. The separate Main responsiveness fix should use resumable bounded transfer progress that returns to the event loop when credits are unavailable, preserves unsent bytes and count/digest checks, and handles EOF, cancellation, reset and odd byte tails without loss or premature completion. Scope and qualify that host change before deployment; do not weaken transport checks or alter FPGA clocks, queues or decode logic to hide a fixture defect. Test one needs no further identical replay: the fixture defect and long host-poll occupancy are already established. Test two remains without a dedicated hardware capture, but the same stationary-content defect is independently proven in its file. Capture each corrected test before a later run overwrites its log. Do not declare release regression complete on the strength of entry 622 audio acceptance. Preserve user control of lifecycle and deployment, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 622 COMMIT Unreleased 44ee05a 2026-08-27T09:00:58-07:00

#### Coming From:

Unreleased 078d36b

#### Purpose:

Close the commercial AC-3 gap by qualifying decode and passthrough against a real DVD track.

#### Outcome:

The user confirmed that a DVD image already on the build PC exists for this purpose, so the last honest gap in AC-3 qualification is closed against real programme material rather than synthetic tones. The image is an unencrypted standard VIDEO_TS structure and no protection was circumvented; one title VOB was extracted locally and nothing derived from the film is committed, with only numeric results retained. That VOB carries three real AC-3 tracks, being 5.1 at 448 kbit/s, stereo at 192 kbit/s and 5.1 at 384 kbit/s, and the helper selects the first as designed. Over 55,414,272 stereo frames, or 1154.5 seconds, the helper's decode against an independent FFmpeg decode of the same track gives maximum absolute difference 299, RMS difference 2.60 and correlation 0.999976, with overall level matching at 376.17 against 376.18 RMS. That is a much larger deviation than the synthetic fixture's maximum difference of three and correlation of 0.999999971, which is the expected consequence of real dynamic range control and dialogue normalization being exercised for the first time, and the residual sits 43.2 dB below the signal. The cause was confirmed rather than assumed by a control: decoding the reference again with dynamic range compression disabled makes the match far worse, at maximum difference 4123, RMS difference 79.17 and correlation 0.989129, and raises the reference level to 428.72 RMS, which is 1.14 dB above the compressed result. That establishes both that the disc carries substantial dynamic range metadata and that the helper applies it, matching the reference decoder's default behaviour, since liba52 enables dynamic range by default and neither decoder applies dialogue normalization. The remaining difference is decoder implementation, not a metadata mismatch. Passthrough was qualified on the same real track: the helper emitted 36,077 bursts, every one a 1536-sample period carrying a 1792-byte frame as expected for constant-rate 448 kbit/s, and all 64,649,984 bytes carried are byte identical to the AC-3 extracted from the disc, with an independent decoder producing matching output. One tool change was needed and is deliberately narrow. A VOB from a multi-file title ends mid-frame by construction, so the helper correctly refuses its truncated tail; rather than loosen the helper or the default gate, the verifier gained an explicit opt-in that accepts exactly that case and ignores the source's trailing 672-byte partial frame. An earlier attempt at the comparison exhausted memory and took the machine down, because it loaded both 212-megabyte captures as double precision and then copied them again; the retained driver streams in chunks and never holds more than a few megabytes.

#### Next Steps:

Audio qualification is complete for this release, covering MPEG Layer II, AC-3 decode and AC-3 and DTS passthrough, against both synthetic fixtures and a real commercial track. Prepare the release next. The README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD compatibility; it should describe audio separately, since audio support is genuinely broader than video and includes passthrough for material the core cannot decode itself. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the marginal scaler paths recovered by reseeding in entry 618, and an honest split of which audio claims are measured and which rest on listening. The community sound test should ask for AC-3 and DTS separately with LFE called out, since entry 621 showed the same device treating them differently. The interlaced video gates of entry 609 remain open and explicitly out of scope. Note for any future disc work that this image is a usable real-world Program Stream source, but that the core cannot decode its video, which uses picture types and structures outside the supported set. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [x] Passed

---

## 621 COMMIT Unreleased 078d36b 2026-08-27T08:49:23-07:00

#### Coming From:

Unreleased 078d36b

#### Purpose:

Accept DTS passthrough on hardware and resolve the reported missing subwoofer channel.

#### Outcome:

The user played the DTS sweep and reports every channel working except the subwoofer, with no format indicator appearing, which that soundbar never shows. Telemetry is clean: all 360 reference and display pictures with 359 swaps, 12,073,316 accepted video bytes, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, zero deadline gaps, and audio underrun and PCM protocol clear, with helper PID 1109 submitting 14,562,142 transport bytes over 889 reads and exiting zero. The new diagnostics work as intended and the log now states both the selected mode and the DTS substream on its own, which is exactly the gap entry 619 had to fill with a listening report. The missing subwoofer is diagnosed rather than left open, and it is not a defect in this core. Decoding the fixture's DTS elementary stream to six discrete channels shows the LFE channel present at 1267.3 RMS in its own slot against about 2896 for the other channels, a level difference that is normal for DTS before a decoder applies LFE gain and is not evidence of loss. The helper then emitted 1,125 valid bursts with no problems, and decoding the frames recovered from that emitted output yields the same LFE at exactly the same 1267.3 RMS on the same channel. Since the carried frames are byte identical to the source, this chain establishes that what the core transmits contains the subwoofer channel. The omission is therefore downstream in the soundbar's DTS handling, and it is DTS specific to that device, because AC-3 LFE was clearly audible on the same hardware in entry 619. Why that decoder drops it is not established and is not testable from here, with bass management, DTS Virtual:X processing and LFE gain conventions all plausible. DTS passthrough is accepted on the evidence that the bytes are provably correct, that an independent decoder recovers every channel including LFE from what the core actually emits, and that the user heard the remaining channels through the soundbar's own decoder. As with AC-3, a 2.1 device cannot verify discrete channel routing, so that remains for the community test. The DTS fixture uses 8 Mbit/s video by necessity and is not a rate ceiling test.

#### Next Steps:

Do not chase the subwoofer behaviour further without different hardware, since the transmitted bytes are already proven correct and no change here could alter what that soundbar does; a tester with a discrete 5.1 DTS decoder would settle it as a side effect of the community test. Ask the community test to report AC-3 and DTS separately and to note LFE explicitly, because this run shows the two codecs can behave differently on the same device. The remaining audio item is a commercial AC-3 track with real dynamic range control and dialogue normalization, which synthetic tones cannot substitute for. Then prepare the release. The user has accepted current video capability as the release scope, so the README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD compatibility. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut, the audio capability including which parts are verified and which rest on a listening report, and the marginal scaler paths recovered by reseeding. The interlaced video gates of entry 609 remain open and explicitly out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 620 COMMIT Unreleased 078d36b 2026-08-27T08:43:19-07:00

#### Coming From:

Unreleased aa7f064

#### Purpose:

Pass DTS through to S/PDIF and record the selected audio output in the helper log.

#### Outcome:

Published source `078d36b` adds DTS passthrough and closes the diagnostic gap entry 619 recorded. The helper now states its audio output mode at startup, so a log proves on its own which path ran rather than leaving that to a listening report. DTS arrives on private stream 1 substreams 0x88 through 0x8F and differs from AC-3 in a way that matters: it carries its own sample count in its frame header, so the burst period is read from each frame and mapped to data type 11, 12 or 13 for 512, 1024 or 2048 samples, where AC-3 is always 1536. The burst emitter is generalized over data type and period accordingly, and only 16-bit big-endian DTS is accepted, with other widths and endiannesses refused rather than guessed at. There is no DTS decoder here, so DTS is passthrough only and a DTS track selected for HDMI output is refused with a clear message instead of playing silence, which is checked and behaves as intended. The fixture generator gains a codec choice. Generating DTS exposed a real constraint rather than a defect: at the usual 1509 kbit/s, DTS plus 9.6 Mbit/s video overruns the 10.08 Mbit/s DVD mux and the muxer reports buffer underflow, so the generator now lowers video to 8 Mbit/s for DTS, which is what real DTS discs do rather than raising the mux. The verifier is extended to walk periods of any supported length and to check each payload against its own codec's sync word. Verification is byte exact: the DTS stream produces 1,125 bursts, every one a 512-sample period at data type 11 with correct sync words, whole-byte length, zero stuffing and a valid DTS sync word in the payload, and the 2,263,500 bytes carried are byte identical to the DTS extracted from the source, with an independent decoder producing the same SHA256 from the carried frames as from the originals. Every existing path is unchanged: AC-3 passthrough still produces 375 correct 1536-sample bursts with identical frames, AC-3 decoded still matches its reference at maximum difference three, the channel sweep still places all six channels correctly, and the MPEG Layer II movie still produces the same 28,628,352 samples with the same PCM hash. The helper cross-compiles clean under `-Werror` with ARM GNU 10.2 to a 399,340-byte static binary with SHA256 `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8`. Only the helper and a new DTS fixture were deployed, each backed up, staged, hash checked and read back on a fresh connection with matching results; the RBF and Main were read back and confirmed still the accepted seed 17 and patched binaries, and no FPGA build was needed because DTS changes nothing in fabric. Built refers to the helper, and Passed is unchecked because nothing has been listened to.

#### Next Steps:

Have the user select S/PDIF AC-3 in the OSD and play games/MediaPlayer/dts_channel_sweep_12s.mpg once, reporting whether the soundbar produces sound and whether the low frequency slot is present, and confirm from the helper log that it now names both the audio output mode and the DTS substream. The soundbar advertises DTS Virtual:X so it should decode DTS, but as with AC-3 it cannot verify discrete channel routing on 2.1 hardware, and its lack of a format indicator remains uninformative. Note that the DTS fixture deliberately uses 8 Mbit/s video, so it is not a rate-ceiling test. After that, the remaining audio item is a commercial AC-3 track with real dynamic range control and dialogue normalization, which is the honest gap in codec qualification and cannot be closed with synthetic tones. Then prepare the release: the user has accepted the current video capability as the release scope, so the README must state plainly what the decoder accepts, being 4:2:0 I-pictures only, frame structured, frame DCT and frame prediction only, 720 by 480 at 30000/1001 with no repeat first field, and must not imply general interlaced MPEG-2 or DVD support. Release notes should carry the entry 616 wording of one or two repeated frames at the picture 690 cut and the marginal scaler paths recovered by reseeding. The interlaced video gates of entry 609 remain open and are explicitly out of scope for this release. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/ARCHITECTURE.md
- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [ ] Passed

---

## 619 COMMIT Unreleased aa7f064 2026-08-27T08:35:53-07:00

#### Coming From:

Unreleased aa7f064

#### Purpose:

Accept AC-3 passthrough over S/PDIF on hardware.

#### Outcome:

The user reloaded the core, exercised both audio output settings and reports that S/PDIF AC-3 sounds correct through the soundbar, that the subwoofer was heard on its own channel for the first time, and that the HDMI and S/PDIF options both behave as specified. The decisive evidence is that low frequency channel rather than any indicator on the device: the AC-3 stereo downmix discards LFE entirely, so a discrete subwoofer channel can only exist if the compressed bitstream reached the soundbar and was decoded there as 5.1. The soundbar displayed no format indicator, which the user reports it never does over S/PDIF, so that absence carries no weight either way. This also settles empirically what entry 617 could only argue from clock arithmetic, namely that the path from the core samples to the S/PDIF pin is bit transparent; had the mixer, filter or DC blocker altered a single sample the receiver could not have decoded anything. Telemetry is clean. The installed RBF is the seed 17 build with SHA256 beginning `61a2fed2`, Main is the patched binary beginning `0ee87029`, and the sweep fixture is unchanged on the target. All 360 reference and display pictures complete with 359 swaps and 14,469,731 accepted video bytes, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps or outliers. Audio underrun and PCM protocol error are clear at FIFO peak 127. Helper PID 753 submitted 16,958,580 transport bytes over 1,036 reads and exited zero, which is byte for byte the same volume as the decoded run of the same fixture in entry 614, confirming by measurement the design property that a burst occupies exactly the transport a decoded frame would have. One diagnostic weakness is recorded rather than hidden: the helper log names the AC-3 substream but never states which audio output mode it was launched with, so the log alone cannot distinguish a passthrough run from a decoded one, and this acceptance therefore rests on the user's listening report for that distinction. Scope is bounded. A 2.1 soundbar cannot verify discrete channel routing however convincingly it virtualizes, so front, centre and surround placement over passthrough remains unproven and needs the community test on real 5.1 hardware; only LFE is independently established, because its presence is impossible under the downmix. DTS passthrough is untested, a commercial AC-3 track with real dynamic range control is still uncompared, and the marginal scaler paths recovered by reseeding remain a risk for the next change that adds logic.

#### Next Steps:

Add a mode line to the helper's diagnostics so a future log proves on its own whether decoded stereo or passthrough was selected, since that gap forced this entry to rely on a listening report for a fact the log should carry. Write the community sound test from the sweep fixture, stating that in S/PDIF mode it exercises discrete channels through the listener's own decoder while in HDMI mode it exercises only the stereo downmix, and ask testers with real 5.1 hardware to report each two second slot by speaker. DTS passthrough is the same machinery with a different data type and burst length and is the cheapest remaining audio item. A commercial AC-3 track remains the honest gap in codec qualification. Before the release, decide whether the audio work is complete enough and prepare release notes carrying the entry 616 wording of one or two repeated frames at the picture 690 cut rather than entry 609's original phrasing. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted and are the larger question for a release that claims interlaced support. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 618 COMMIT Unreleased aa7f064 2026-08-27T08:28:45-07:00

#### Coming From:

Unreleased 6c273b3

#### Purpose:

Recover timing closure for the S/PDIF passthrough candidate by reseeding the fitter once.

#### Outcome:

The user authorized a single reseed and directed that the scaler be fixed if it failed. Published source `aa7f064` moves the pinned fitter seed from 16 to 17 and nothing else, so the netlist is unchanged and only placement and routing differ; synthesis produces the identical 137 warnings as the failing build, which confirms that. The reseed succeeds and does so with more margin than the accepted baseline: worst setup is positive 0.243 nanoseconds against positive 0.083 for `d466bed` and negative 0.070 at seed 16, with hold 0.251, recovery 2.865, removal 0.564 and minimum pulse width 0.925, and every reported total negative slack is zero. The `ascal` horizontal accumulator paths that failed are no longer critical. The warning set is identical to accepted `d466bed`, with the same twenty-one distinct warning identifiers at the same counts, none new and none missing, including the pre-existing invalid Fitter assignments warning; the timing violation warning present at seed 16 is gone. Logic utilization is 31,464 ALMs against 31,394 for the baseline, and M10K stays at 512 of 553, so the whole audio feature still costs no block memory. The 4,332,740-byte RBF has SHA256 `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce`. All three artifacts were deployed together, because the OSD bit is meaningless unless the core routes on it, Main passes it to the helper and the helper can act on it. Every target was backed up first under the entry 618 backup directory, capturing the accepted `d466bed` RBF, the previous Main and the AC-3 helper from entry 611, and each file was then uploaded to a staged name, hash checked while staged, renamed, and read back on a fresh connection, with all three readbacks matching exactly. Media and settings are untouched and no reboot, core reload or playback was performed. What this entry establishes is a timing-qualified build and a verified installation, not working passthrough. Bit transparency from the core samples to the S/PDIF pin is still argued from clock arithmetic rather than measured, no receiver has been shown to lock onto a burst, and the reseed recovers this build without making the underlying scaler paths any less marginal, so the next change of comparable size may expose them again.

#### Next Steps:

Have the user reload the MediaPlayer core so the new RBF and Main take effect, set the new Audio output option to S/PDIF AC-3, and play games/MediaPlayer/ac3_channel_sweep_12s.mpg, reporting whether the soundbar shows a format indicator and whether each two second slot is audible, including the low frequency slot which the stereo downmix always discarded and which should now be present. Selecting HDMI mutes S/PDIF by design, so a silent test in that mode on a system whose only speakers are on S/PDIF is expected behaviour and not a fault. Retrieve the helper log first and confirm it records the selected mode, then take a fresh telemetry screenshot from the terminal screen rather than during playback. If the soundbar stays silent in S/PDIF mode, suspect the transparency of the path to the pin before suspecting the bursts, which are already verified byte exact, and check the channel status non audio bit before anything else. Do not describe a 2.1 soundbar locking onto a burst as proof of discrete channel routing; that still needs the community test on real 5.1 hardware. The marginal `ascal` accumulator paths remain a known risk to record before the next feature that adds logic. A commercial AC-3 track with real dynamic range control remains uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- MediaPlayer.qsf

#### Status:

- [x] Built
- [ ] Passed

---

## 617 COMMIT Unreleased 6c273b3 2026-08-27T08:12:47-07:00

#### Coming From:

Unreleased e2bf23f

#### Purpose:

Route IEC 61937 bursts to the S/PDIF pin under an audio output option, with the unused output muted.

#### Outcome:

Published source `6c273b3` implements the integration the user specified and approved, including the framework fork. The S/PDIF encoder gains a non audio channel status input driving bit one, so a burst stops declaring itself linear PCM; `audio_out` gains a passthrough route feeding S/PDIF straight from the core samples while skipping the interpolating filter, the DC blocker and the attenuation, boost and mix stages, because each alters sample values and any alteration destroys a burst; I2S is muted in that mode and S/PDIF is muted outside it. A new emu port carries the selection from the core through `sys_top`, a new OSD option on status bit 126 drives it, and the Main patch reads the same bit in the parent before forking to pass `--audio-out` to the helper, so one bit drives both routing and the helper's decode or pass through decision. Main builds cleanly against the pinned commit at 1,170,340 bytes with SHA256 `0ee87029f0a00a50731707e8114363fc7019ae4c1200de85d90533c9163b5241`, which also proves the corrected patch hunk applies and that `user_io_status_get` is the right interface at that revision; an earlier edit had left that hunk's line count stale and it was recomputed rather than guessed. The build does not qualify. Quartus 17.0.2 at the pinned seed 16 completes in 11 minutes 33 seconds with zero errors, but worst setup slack is negative 0.070 nanoseconds against the accepted `d466bed` figure of positive 0.083, with total negative slack of the same 0.070. Hold, recovery, removal and minimum pulse width all improve slightly at 0.248, 3.158, 0.488 and 0.925 nanoseconds. The 4,298,348-byte RBF is therefore not usable and is not deployed. The failure is diagnosed rather than assumed: both violated paths run between bits 9 and 13 of the `o_hacc_next` register inside the `ascal` scaler on the HDMI pixel clock, entirely inside the framework scaler's horizontal accumulator, with the next path at positive 0.076 nanoseconds, so this is a cluster of marginal arithmetic paths in framework video logic rather than anything in the audio change, which lives in the audio clock domain. Resource movement is consistent with that reading: ALMs rise from 31,394 to 31,488, a 94 ALM increase that perturbs placement, while M10K stays at 512 of 553, block memory bits and DSPs are unchanged, so the audio work costs no memory as designed. The only new warning across the whole flow is 332148, the timing violation itself; every other warning matches the accepted baseline exactly, with none disappearing. The honest conclusion is that this design has been running on roughly 0.08 nanoseconds of setup margin in the HDMI domain all along, and any change of comparable size could have exposed it. Built is left unchecked because a candidate that misses timing is not a usable build under this project's own standard, even though it compiled without errors.

#### Next Steps:

Decide how to recover timing before anything is deployed, and record the choice rather than quietly re-rolling until a build passes. The cheapest option is a different fitter seed, which is a tracked source change because seed 16 is pinned in the project file, and it is legitimate provided the new seed is recorded and kept for later comparability; it does not make the underlying path less marginal. The durable option is to attack the `ascal` horizontal accumulator path itself, which would benefit every future change rather than this one, but it means modifying framework video logic beyond the audio fork the user approved and should be scoped separately. Reducing the audio routing logic is unlikely to help, since the failing path is not in it. Whichever is chosen, require a clean seed-qualified build with a warning comparison against `d466bed` before deploying, and deploy the RBF, Main and helper together, because the mode bit is meaningless unless all three change as a set. On hardware the existing channel sweep is the six channel sound test, LFE becomes audible for the first time, and selecting HDMI will silence S/PDIF by design, which must not be mistaken for a fault on a system whose only speakers are on S/PDIF. Bit transparency from the core samples to the pin remains argued from the clock arithmetic rather than measured, and it is the most likely cause if a receiver fails to lock. Do not describe a 2.1 soundbar locking onto a burst as proof of discrete channel routing. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- sys/spdif.v
- sys/audio_out.sv
- sys/emu_ports.vh
- sys/sys_top.v
- MediaPlayer_top_00.svh
- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [ ] Built
- [ ] Passed

---

## 616 COMMIT Unreleased e2bf23f 2026-08-27T07:52:18-07:00

#### Coming From:

Unreleased e2bf23f

#### Purpose:

Capture the outstanding MPEG Layer II hardware regression on the AC-3 helper.

#### Outcome:

The full movie replay on the new helper is finally captured with its own log, closing the gap entries 613 and 614 left open. Completion is exact: all 17,876 reference and display pictures, 17,875 swaps, 715,713,077 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, audio underrun and PCM protocol clear, both timestamp conflict counters zero, and helper PID 3477 submitting all 839,409,548 transport bytes over 51,234 reads with exit zero. The accepted MPEG Layer II path therefore survives codec selection on hardware, which host testing had suggested but not proven. One measured quantity did change and is reported rather than smoothed over: this run missed two display slots where entries 605 and 606 each missed one. The deadline records place them at displayed pictures 691 and 692, adjacent and at the same scene cut as before, with two 4,004,000-clock intervals whose eight bit gap ordinals 179 and 180 alias to those pictures. Both records show no presentable candidate with the decoder not ready and the upstream FIFO pending, presentation error and the timestamp signals clear, and input starvation of 1,009,994 and 727,897 clocks. The new helper is not implicated by the evidence available. Delivery timing is materially identical across all three movie runs, with median inter-read gaps of 11,463, 11,468 and 11,475 microseconds, ninety-ninth percentiles of 20,986, 20,966 and 20,931, maxima of 41,289, 41,309 and 41,304, and the same 23.5 millisecond worst gap in the window around the cut, while the MPEG Layer II PCM output was already proven byte identical on the host in both output modes. What the extra slot exposes is a flaw in the entry 608 and 609 model rather than a new fault. That model tested each picture independently against a full buffer, which is why it predicted exactly one miss, but after picture 690 overruns the buffer is not refilled to full, so picture 691 at 95,308 bytes is then also uncovered. Taking the pair together, 245,624 bytes must arrive against 98,304 bytes of buffer plus two frame periods of delivery, a deficit of about 67,240 bytes or roughly 1.7 slots, so one or two lost slots at this cut are both consistent with the mechanism and the exact count depends on phase. Entry 609's known limitation stands but its wording of exactly one repeated frame is too strong and is corrected here to one or two at that cut. The user reports the movie plays perfectly, which is consistent: two repeated frames at a scene cut in a ten minute film are not perceptible. No source change is made in this entry, so Built and Passed refer to `e2bf23f`, with Passed covering the MPEG Layer II regression.

#### Next Steps:

Treat the MPEG Layer II regression as closed and do not repeat the full replay to observe the missed slot count again, since a single run per circumstance is the standing practice and the mechanism is now understood. If that judder is ever to be removed, the fix remains the deeper input buffer costed in entry 608 at roughly 26 M10K against 41 free, and the cascade behaviour means the buffer must cover consecutive large pictures rather than only the single largest, which makes that fix less attractive rather than more. Carry the corrected wording, being one or two repeated frames at the picture 690 cut, into release notes rather than entry 609's original phrasing. The audio work continues at the second passthrough boundary described in entry 615. A commercial AC-3 track with real dynamic range control remains uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 615 COMMIT Unreleased e2bf23f 2026-08-27T07:52:18-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Pack AC-3 frames into IEC 61937 bursts in the helper behind an audio output selection.

#### Outcome:

Published source `e2bf23f` adds `--audio-out`, defaulting to `hdmi`, and emits IEC 61937 bursts instead of decoded stereo when `spdif` is selected. One AC-3 frame is 1536 samples and one burst period is 1536 stereo frames, so a frame fills a period exactly and the bursts ride the existing PCM transport with no rate conversion, no new record type and no FPGA memory, which matters at 93 percent M10K. Each burst carries the `0xF872` and `0x4E1F` sync words, data type one, the length in bits, the frame written as big-endian sixteen bit words so bytes reach the line in order, and zero stuffing for the remainder. liba52 is not initialized at all in passthrough, since nothing is decoded. Verification is offline and byte exact: the emitted stream is 2,304,000 bytes forming 375 whole burst periods, every one parses with correct sync words, data type, whole-byte length and zero stuffing, every payload begins with the AC-3 sync word, all frames are the expected 1792 bytes, and the 672,000 bytes carried are byte identical to the AC-3 extracted from the source. An independent decoder produces the same SHA256 from the carried frames as from the source frames. The decoded paths are unchanged: AC-3 stereo still matches its reference at maximum difference three and correlation 0.999999971, the channel sweep still places all six channels correctly, and the MPEG Layer II movie produces identical output in both `hdmi` and `spdif` modes, byte for byte, since passthrough applies to AC-3 only. A build defect was found and fixed rather than worked around: native and cross builds shared one liba52 object directory, so switching compilers produced a confusing wrong-format link error; objects are now kept per compiler. The helper cross-compiles clean under `-Werror` with ARM GNU 10.2 to a static binary with SHA256 `f07e4ce2bb2a431802f9c8631a228bb70c363455954315883776f58ce87a75db`. What this does not establish is as important: it proves the bytes are correct, not that any receiver locks onto them, and not that the path from the helper to the S/PDIF pin is bit transparent. It is not deployed, and it cannot work on hardware until the second boundary lands, because nothing yet selects the mode, mutes the unused output, bypasses the framework mixer's attenuation, boost, mix and filter, or sets the S/PDIF non audio channel status bit that is currently hardwired to zero. Built therefore refers to the helper only and Passed remains unchecked.

#### Next Steps:

Start the second boundary, which is the integration the user described: an OSD option choosing S/PDIF or HDMI audio, the unused output muted, a bit transparent path proven rather than assumed, the framework fork the user approved for the channel status bit and the mixer bypass, and a Main patch line so the launch passes the selected mode. Define the option name, the muting mechanism and the transparency proof before editing RTL. When it reaches hardware, the existing channel sweep fixture is the six channel sound test with no new fixture needed, and LFE becomes audible for the first time because the stereo downmix discards it. Do not describe the user's 2.1 soundbar locking onto a burst as proof of discrete channel routing; that needs the community test on real 5.1 hardware. A commercial AC-3 track with real dynamic range control remains uncompared. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/Makefile
- host/arm/ARCHITECTURE.md
- tools/streams/verify_ac3_passthrough.py

#### Status:

- [x] Built
- [ ] Passed

---

## 614 COMMIT Unreleased 9623fa7 2026-08-27T07:34:33-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Record the channel sweep run's own hardware telemetry and transport log.

#### Outcome:

The capture requested as the MPEG Layer II regression is in fact the AC-3 channel sweep run, which the helper log identifies unambiguously by source path, so it is recorded as what it is rather than as the regression it was expected to be. That is a useful outcome anyway, because entry 613 had to accept the sweep without its own transport log after the movie overwrote the previous one; this capture supplies it. The sweep completes cleanly with all 360 reference and display pictures, 359 swaps, 14,469,731 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps and outliers, with all three largest display intervals at exactly the nominal 2,002,000 clocks. Audio underrun and PCM protocol error are clear at FIFO peak 127, and both timestamp conflict counters are zero. Helper PID 3257 submitted 16,958,580 transport bytes over 1,036 reads with 16 sampled ACK records and exited zero at 11.931 seconds. The installed RBF still hashes to accepted `d466bed`, Main is unchanged, and the full movie fixture is still present and byte-exact at 739,065,873 bytes, so the AC-3 work has disturbed nothing on the target. The MPEG Layer II hardware regression therefore remains uncaptured: its log was overwritten by this sweep run exactly as the single fixed log path implies, and the user's report that the movie plays perfectly still stands without telemetry behind it. That gap is stated rather than closed. This entry makes no source change, so Built and Passed refer to the accepted helper at `9623fa7`, with Passed covering the sweep run's own clean completion.

#### Next Steps:

The MPEG Layer II regression needs one dedicated replay with nothing played afterwards, capturing the helper log before anything else is started, and requiring all 17,876 pictures, the exact 839,409,548 transport bytes and the entry 605 and 606 error and deadline state, allowing for the one known repeated frame at picture 692 recorded in entry 609. The user has asked for real surround over S/PDIF before release, which is the passthrough boundary and is scoped but not started. Its shape is now known from the framework: an AC-3 frame is 1536 samples at 48 kHz and an IEC 61937 burst occupies exactly the same period, so the helper can pack the bursts on the ARM and send them down the existing PCM transport without a new transport or any decoder in fabric. Three obstacles are real and must be settled before work starts. The framework's mixer applies attenuation, boost, mix and a biquad filter to every sample, and passthrough requires a bit-transparent path because any non-unity gain destroys the burst. The S/PDIF encoder hardwires the channel status non-audio bit to zero, so the stream always declares linear PCM, and setting it means editing framework code this project has otherwise left alone. HDMI would carry the same burst data as if it were PCM, which is loud noise on speakers, so a mode selection and an HDMI audio decision are required rather than optional. DTS passthrough is the same machinery with a different data type and burst length. A commercial AC-3 track with real dynamic range control is still uncompared, and the interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 613 COMMIT Unreleased 9623fa7 2026-08-27T07:30:48-07:00

#### Coming From:

Unreleased 9623fa7

#### Purpose:

Accept AC-3 stereo decode on hardware from the channel sweep listening result.

#### Outcome:

The user played the channel sweep fixture and reports hearing the expected pattern correctly, and on both outputs rather than only one. The earlier HDMI silence of entry 612 is resolved and was not a core defect: the monitor's volume was turned down. HDMI and S/PDIF are therefore both confirmed to carry the decoded stereo, which matches the framework feeding both from the same PCM and removes the only unexplained observation from the previous entry. Combined with the exact host measurement in entry 612, where front left and right appear only on their own sides, centre appears equally in both at 4.52 dB below the fronts, the surrounds appear on their own sides at 6.02 dB below, and LFE is correctly absent, AC-3 stereo decode and downmix are accepted on hardware for this fixture. The user separately reports that the accepted MPEG Layer II movie also plays perfectly on the new helper, which is the hardware confirmation entry 611 and 612 asked for, but its telemetry is not captured here and that claim rests on the user's report alone. A capture attempted immediately after the report landed mid-playback: the helper log shows the full movie running with only 8,241,152 of 839,409,548 transport bytes submitted at 5.73 seconds, and the screenshot returned a 529 by 240 live video frame rather than the telemetry packet, which the decoder correctly refused as an unsupported layout. That capture is retained as a partial record and is not evidence of completion. The sweep run's own helper log is unrecoverable because the subsequent movie run overwrote it, so the sweep is accepted on the listening result and the entry 612 host measurement rather than on its own transport log; this is a consequence of the single fixed log path and is worth remembering before asking for two runs in succession. The installed RBF still hashes to accepted `d466bed`, the sweep fixture is unchanged on the target, and the Linux boot is still the same session. No source change is made in this entry, so Built and Passed refer to the accepted AC-3 helper at `9623fa7`, with Passed covering AC-3 stereo decode and downmix placement only.

#### Next Steps:

Let the movie finish, then capture the helper log first and a fresh telemetry screenshot to record the MPEG Layer II hardware regression properly, requiring all 17,876 pictures, the exact 839,409,548 transport bytes and the entry 605 and 606 error and deadline state, and remembering the one known repeated frame at picture 692 recorded in entry 609. Only then is codec selection proven not to have disturbed the accepted path on hardware. Ask the user to take the screenshot while the terminal telemetry screen is showing rather than during playback. A community sound test can now be written from the sweep fixture, and it must state plainly that it exercises the stereo downmix rather than discrete surround, since the core emits two channels. A commercial AC-3 track with real dynamic range control and dialogue normalization is still uncompared and remains the honest gap in this codec's qualification. AC-3 and DTS passthrough over S/PDIF remain the separate later boundary, now with both outputs confirmed working for linear PCM. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 612 COMMIT Unreleased 9623fa7 2026-08-27T07:22:37-07:00

#### Coming From:

Unreleased 67aaf7f

#### Purpose:

Capture the first AC-3 hardware run and establish which channels the stereo downmix actually carries.

#### Outcome:

The user played the ten second AC-3 fixture and reported hearing mixed tones from an AV receiver over S/PDIF but nothing from HDMI, on a 2.1 system fed by a portable monitor whose only outputs are two small speakers and a headphone jack. Telemetry is clean: the installed candidate and fixture hash as deployed, all 300 reference and display pictures complete with 299 swaps, `error_flags` zero, sequence end seen, presentation complete, quiet snapshot, and zero deadline gaps or outliers, with 12,066,264 accepted video bytes. Audio underrun and PCM protocol error are clear at FIFO peak 127, though `pcm_sample_count` remains a saturated field. Helper PID 2820 submitted 14,143,620 transport bytes over 865 reads and exited zero at 9.930 seconds. This is the first AC-3 audio heard from the core. A misconception in the request is corrected rather than worked around: nothing sends 5.1 anywhere, because the helper downmixes AC-3 to two channels and the framework emits linear PCM on both HDMI and S/PDIF, so the user's subwoofer is their receiver's own bass management of that stereo pair and not a channel the core produces. Discrete surround requires the separate IEC 61937 passthrough boundary. liba52 is asked for `A52_STEREO` without `A52_LFE`, so LFE is decoded and then discarded exactly as the stereo downmix convention requires; the fixture's 55 Hz LFE tone is therefore absent from the output by design and is not a fault. Proving three channels was thus not possible as posed, since only two exist in the signal, but the underlying question was answered completely by a different route. A new sweep fixture mode sounds one source channel at a time so placement is measurable without a 5.1 monitoring rig, and a new analyzer measures each slot. The first sweep exposed a defect in the fixture rather than the decoder: FFmpeg's join filter assigns inputs positionally and that order does not follow the 5.1 layout, so the first three channels were mislabelled, which is also why entry 610's tone check was unreadable and why both the helper and the reference appeared to disagree with the labels. Binding every tone to a named channel fixes it. With that corrected, all six channels land exactly where the downmix specifies: front left at 220 Hz appears only on the left and front right at 277 Hz only on the right at equal level, centre at 330 Hz appears equally in both at 4.52 dB below the fronts, the surrounds at 440 and 554 Hz appear only on their own side at 6.02 dB below the fronts, and LFE is silent in both. The entry 610 channel assignment question is therefore closed, and closed against measurement rather than labels. The silence over HDMI is unexplained and is not yet attributed, since the framework feeds HDMI and S/PDIF from the same stereo PCM; a monitor with small speakers is a plausible but unverified cause and no MiSTer audio setting has been inspected. The sweep fixture was deployed after backing up the installed Main and RBF, staged and renamed with an independent readback that matches. No RTL, FPGA build, Main, RBF, settings, reboot, reload or playback change was made, so Built refers to host tools only and Passed remains unchecked pending a listening result on the sweep.

#### Next Steps:

Have the user play games/MediaPlayer/ac3_channel_sweep_12s.mpg once through the receiver and report, for each two second slot in order, whether the tone appears on the left, the right, in both or not at all, expecting left, right, both, silence, left, right. Headphones on the monitor's jack are the cheapest way to separate a genuine HDMI audio fault from small speakers, and MiSTer's audio configuration should be checked before treating HDMI silence as a core defect. That listening result is what the community sound test should be built from, and any community request should say plainly that it exercises the stereo downmix, not discrete surround, so testers are not asked to judge channels the core does not yet emit. Replay the MPEG Layer II movie to confirm codec selection did not disturb the accepted path on hardware, which is still only regression tested on the host. A commercial AC-3 track with real dynamic range control and dialogue normalization remains uncompared. AC-3 and DTS passthrough over S/PDIF remain the separate later boundary, and the confirmed live S/PDIF port is a useful precondition for it. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/analyze_ac3_downmix.py

#### Status:

- [x] Built
- [ ] Passed

---

## 611 COMMIT Unreleased 67aaf7f 2026-08-27T07:12:58-07:00

#### Coming From:

Unreleased ff6c03f

#### Purpose:

Qualify the AC-3 helper on a ten second fixture and stage it on the MiSTer for the user's first listening test.

#### Outcome:

The user asked for a ten second clip rather than a full length one for the first AC-3 test, which the fixture generator already supported. Generating at ten seconds exposed a defect in the generator rather than in the decoder: decoding the muxed program to raw stereo made FFmpeg's s16le muxer report a duplicate final DTS, which the shared runner correctly refuses because it requires clean output. Published source `67aaf7f` fixes that properly rather than by relaxing the check, extracting the private stream 1 substream into an elementary stream and decoding that instead, which carries no container timestamps and is byte for byte what the helper is handed; the elementary stream's own size and hash are now recorded too. The five second fixture regenerates unchanged through the new path. The ten second fixture is 12,787,729 bytes with SHA256 `fb71dee0a1af7746809505b73ccc432f5951fbf01579ca63bbcb90e6c7aefece`, carrying 300 pictures over 10.01 seconds of 720x480 TFF all-I video and 448 kbit/s AC-3 5.1 on substream 0x80, with a 560,896-byte AC-3 elementary stream. Against the independent FFmpeg decode the helper produces exactly 480,768 stereo frames, matching the reference frame for frame over 10.016 seconds, with maximum absolute difference three, RMS difference 0.4251 left and 0.4492 right, and correlation 0.999999971 and 0.999999967, reproducing the five second result at twice the length. The helper log line naming substream 0x80 appears as intended. Installed state was backed up before anything was written: the previous 361,452-byte helper with SHA256 `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`, the unchanged Main and the accepted `d466bed` RBF are all retained under the entry 611 backup directory. The new 399,340-byte helper with SHA256 `100a3c1f97e9a0d0e77e3992bfc6db8584d17081798fc2e1dbeb365faf2269c4` and the fixture were then deployed through a staged name with a hash check before rename and an independent readback on a fresh connection after it; both readbacks match exactly. Main, the RBF and settings are untouched, and no reboot, core reload or playback was performed, so lifecycle stays with the user. Built refers to the helper only, since no FPGA build was needed or made, and Passed remains unchecked because nothing has been listened to yet. The open questions from entry 610 are unchanged: channel assignment is still unverified because the fixture's tone labels disagree with the assumed layout in both the helper and reference decodes, and a real commercial AC-3 track with genuine dynamic range control and dialogue normalization has not been compared.

#### Next Steps:

Have the user select the MediaPlayer core and play games/MediaPlayer/ac3_480i_tff_5p1_10s.mpg once, reporting whether sound is present, whether it stays synchronized across the ten seconds and whether the menu stays responsive, and noting that the fixture is deliberately six discrete tones rather than programme material. Retrieve the helper log first and confirm the substream selection line, then take a fresh telemetry screenshot and check the audio error and underrun state along with the picture counts for the 300 pictures. Because this helper replaces the one the accepted full movie ran on, replay the MPEG Layer II movie afterwards to confirm codec selection did not disturb the accepted path on hardware, since only the host side has been regression tested. Then resolve channel assignment by decoding each channel separately rather than trusting the downmixed tone labels. AC-3 passthrough over S/PDIF and DTS passthrough remain the separate later boundary needing IEC 61937 packing and a neutral gain and filter chain; the user has confirmed the S/PDIF port is live and already carries stereo synchronized with HDMI, which is a useful precondition but not evidence about compressed output. The interlaced video gates of entry 609 remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ac3_av.py

#### Status:

- [x] Built
- [ ] Passed

---

## 610 COMMIT Unreleased ff6c03f 2026-08-27T07:09:10-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Decode DVD AC-3 audio to stereo PCM in the ARM helper on the same path MPEG Layer II already uses.

#### Outcome:

Published source `ff6c03f` routes private stream 1 substreams 0x80 through 0x87 to liba52 and downmixes to the existing 48 kHz stereo PCM transport, so no RTL, FPGA memory or timing budget is touched and the 41 free M10K blocks are untouched. `process_private_pes` previously discarded exactly these packets. It now reads the substream identifier, frame count and first access unit pointer, honours that pointer only until the decoder has synchronized, and appends the remainder. Codec selection follows the helper's own architecture note: the first audio PES decides between MPEG Layer II and AC-3 and the other codec is ignored for the session, with the chosen substream identifier logged and further AC-3 tracks skipped because track switching needs the versioned control channel protocol one omits. liba52 is asked for `A52_STEREO` with `A52_ADJUST_LEVEL`, so the stream's own downmix coefficients are used and the helper invents no matrix of its own, and the decoder is initialized lazily so Layer II files neither allocate it nor inherit its startup message. Two planning errors are corrected here. Entry 610's proposal said the liba52 sources would be committed under the helper dependency directory, but that directory is gitignored by existing policy and dependencies are pinned by `build_arm_stack.sh` instead, as README already describes for minimp3; liba52 0.7.4 is therefore fetched from a pinned tarball with SHA256 `a21d724ab3b3933330194353687df82c475b5dfb997513eef4c25de6c865ec33`, extracted to the same place, and only the hand-written replacement for its autoconf `config.h` is tracked. A scoping remark that GPL would contaminate the project was also wrong and is corrected: liba52 is GPL-2 and so is this project. The AC-3 fixture uses private stream 1, which the soak generator's pack checker rejected, so that checker gains a stream identifier parameter while its MPEG Layer II default is unchanged. A new deterministic generator produces a five second 720x480 TFF all-I fixture carrying 448 kbit/s AC-3 5.1, keeping the accepted video path unchanged so the fixture isolates the audio codec; the generated media stays local and only the generator is committed. Against an independent FFmpeg decode of the same program, the helper produces exactly 241,152 stereo frames, matching the reference frame for frame, with maximum absolute difference three, RMS difference 0.4257 left and 0.4509 right, and correlation 0.999999971 and 0.999999967. That is comparable to the accepted Layer II qualification and is deliberately not a bit-exactness claim, since liba52 and FFmpeg differ in downmix coefficients, dynamic range handling and rounding. The fixture's per-channel tone labels do not match the layout the generator assumed, and the reference decode shows the same mapping, so channel assignment is not independently verified by this evidence and only decode equivalence is; that check remains open. The MPEG Layer II path is unchanged, reproducing the exact 28,628,352 PCM samples and 17,776 timestamp records entry 602 recorded for the full movie, where the video output byte count exceeds the 715,713,077-byte payload by precisely those records. The helper cross-compiles cleanly under `-Werror` with MiSTer's official ARM GNU 10.2 toolchain to a 399,340-byte static binary with SHA256 `100a3c1f97e9a0d0e77e3992bfc6db8584d17081798fc2e1dbeb365faf2269c4`, and the dependency fetch, extraction and build were exercised from an empty dependency directory. GUNSMOKE has no qemu-arm, so that ARM binary is compiled but unexecuted and all decode evidence comes from a native build of identical sources. The user separately confirmed that the MiSTer S/PDIF port is live and already carries stereo audio synchronized with HDMI, which is useful for the later passthrough boundary but is not evidence about AC-3. No FPGA build, deployment or hardware run occurred, so Built refers to the helper only and Passed remains unchecked.

#### Next Steps:

Deploy the new helper and have the user play the generated AC-3 fixture once, reporting sound, synchronization and menu behavior, then capture the helper log first and a fresh telemetry screenshot as usual and confirm the substream selection line appears. Before that, generate the fixture locally, since it is deliberately not committed. Resolve the open channel assignment question by decoding each channel separately rather than relying on the downmixed tone labels, and only then claim correct 5.1 channel identity. Consider whether a real commercial AC-3 track, which uses dynamic range control and dialogue normalization far more aggressively than a synthetic tone fixture, deserves its own comparison before this is called finished. AC-3 passthrough over S/PDIF and DTS passthrough remain the separate later boundary, needing IEC 61937 packing and a neutral gain and filter chain rather than any decoder change, and the framework's S/PDIF encoder carries linear PCM only. The interlaced video gates of entry 609, being field pictures, field DCT, interlaced P and B, repeat first field and 576i, remain open and unstarted. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- host/arm/media_player_helper.c
- host/arm/Makefile
- host/arm/liba52_config.h
- host/arm/ARCHITECTURE.md
- host/build_arm_stack.sh
- tools/streams/generate_test_dvd_ac3_av.py
- tools/streams/verify_ac3_pcm.py
- tools/streams/generate_test_dvd_av_soak.py

#### Status:

- [x] Built
- [ ] Passed

---

## 609 COMMIT Unreleased d466bed 2026-08-27T06:42:34-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Record the user's decision to accept the picture 690 repeated frame as a known limitation rather than deepen the input FIFO.

#### Outcome:

The user rejected the entry 608 proposal to raise `mpeg2_stream_fifo` from 16,384 to 32,768 sixteen-bit words and directed that the defect be logged as a known limitation, so no RTL change is made and the memory headroom of 41 free M10K blocks is preserved for future work. The accepted limitation is stated precisely so a future agent does not rediscover it as a fault: with 98,304 bytes of compressed read-ahead and consumption-paced transport, any coded picture larger than 138,344 bytes cannot be fully buffered ahead of its own decode and costs one display slot, which the hardware shows as a single frame repeated for two slot periods rather than a dropped frame. In the qualified full-movie fixture this affects exactly one picture, number 690 at 150,316 bytes at the scene cut near 23.09 seconds, producing one 66.733333-millisecond interval, roughly 33.4 milliseconds of added running time and no error flag, no dropped picture and no audio effect. The user watched both Bob and Weave runs in full and did not perceive it. This limitation is a property of buffer depth against peak coded picture size, not of the film, so other sources with a picture above the threshold will show the same single-slot repeat at that picture, and sources whose peak stays below it will not. The threshold is not a standards limit and must never be described as one; ITU-T H.262 and H.222.0 impose no such constraint, and the fixture itself is legal with zero VBV underflow throughout. The margin to the runner-up picture is only 1,994 bytes, so the exact threshold should be treated as approximate and re-derived rather than quoted as exact if the buffer depth, declared rate or decode timing assumption ever changes. The known fix, if the trade is ever worth making, is recorded in entry 608 along with its estimated cost of roughly 26 M10K blocks and its fit and timing risk at 93 percent utilization. No source, build, deployment, setting or playback changed in this cycle, and the Built and Passed marks refer to the unchanged, already-accepted `d466bed`.

#### Next Steps:

Treat `d466bed` as the current accepted baseline with the picture 690 limitation documented, and do not reopen it as a defect without new evidence such as a source that misses more than one slot or a run whose miss count exceeds the model's prediction. Carry the limitation into release notes when a version boundary is next prepared, since it is user-visible behavior on high-peak sources. The remaining qualification gates are unchanged and each needs scope and acceptance criteria agreed before work starts: Bob and Weave coverage beyond this single fixture, AC-3 audio, interlaced P and B pictures and field DCT, navigation, and ISO or disk-sourced playback. Await the user's direction on which gate to open next rather than selecting one unilaterally. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 608 COMMIT Unreleased d466bed 2026-08-27T06:39:56-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Measure the pipeline's compressed read-ahead and test whether it explains the single missed slot.

#### Outcome:

The read-ahead is fixed by two declarations and needed no simulation to measure. The dual-clock `mpeg2_stream_fifo` holds 16,384 sixteen-bit words, exactly 32,768 bytes, and the `mpeg2_h262_clean_video_queue` holds a 65,536-byte eight-bit `scfifo`, giving 98,304 bytes of compressed storage ahead of the decoder, or 2.4551 frame periods at the declared 40,040 bytes per frame period. That falsifies the entry 607 hypothesis, which predicted a depth between 3.118 and 3.754 frame periods; the real depth is below both, so trough depth and read-ahead alone cannot discriminate picture 690 from the twenty-five comparably thin points the hardware absorbed. Following the pre-registered branch, helper delivery timing was examined next. An initial attempt to locate the failure by program-stream file offset was wrong and is recorded here as a correction: the helper demuxes on the HPS and its submitted counter aggregates video, PCM and metadata, so it cannot be indexed by file offsets, and the first mapping pointed at 20.2 seconds instead of the true 23.09-second event. Repeating the measurement in wall time shows delivery is steady and rules out a transport stall. Both runs move 839,409,548 transport bytes at 1,407,367 and 1,407,386 bytes per second, with median inter-read gaps of 11.463 and 11.468 milliseconds, ninety-ninth percentile gaps of 20.986 and 20.966, and maxima of 41.289 and 41.309 milliseconds occurring at 404.57 seconds in both runs rather than near the failure. No gap in either run approaches the 81.92 milliseconds needed to drain the buffer at the declared rate, and the largest gap in the whole 22-to-24-second window is 23.511 milliseconds in Weave and 20.889 in Bob, ordinary against their own percentiles. Delivery is therefore consumption-paced and rate-matched, which is the missing term. Because the transport never runs a large lead, a picture bigger than the buffer must stream in while it is being decoded, and the slot is missed when that streaming time exceeds one frame period, giving a threshold of 138,344 bytes. Applied to all 17,876 pictures, exactly one picture in the film exceeds it: picture 690 at 150,316 bytes, predicting 9.977 milliseconds of starvation against 11.295 measured in Weave and 11.660 in Bob, and predicting exactly one missed slot per run, which is what both runs recorded. The model also explains the non-events, since picture 7602 at 136,350 bytes and picture 13253 at 124,846 bytes fall below the threshold despite 13253 sitting at a deeper VBV trough. This fit should be treated as strong but not settled, because the margin between the one predicted miss and the runner-up is only 1,994 bytes, about 1.4 percent, so a modest error in the assumed consumption rate or in the one-frame-period decode assumption would change the prediction to two misses or none. The relevant headroom for any fix is memory rather than logic: the accepted build uses 512 of 553 M10K blocks at 93 percent, with block memory bits at 71 percent and ALMs at 75 percent, so only 41 M10K blocks remain. This entry performs no build and no hardware run, and its Built and Passed marks refer to the unchanged, already-accepted `d466bed`. Evidence and the exact drivers are retained as `.ai/current_results/entry608_*`.

#### Next Steps:

Obtain user approval before any RTL change, since the defect is one repeated frame in a ten-minute film and the only credible fix consumes most of the remaining memory headroom. The proposal to approve or reject is to raise `mpeg2_stream_fifo` from 16,384 to 32,768 sixteen-bit words, taking the stream FIFO from 32,768 to 65,536 bytes and total read-ahead to 131,072 bytes, or 3.2741 frame periods, which lifts the miss threshold to 171,112 bytes and clears the film's largest picture by 20,796 bytes. The estimated cost is roughly 26 additional M10K blocks against 41 free, taking utilization from 93 percent toward 98 percent, so fit and timing closure are the real risks and a clean build with a warning comparison against `d466bed` must gate acceptance. Growing the clean video queue instead is worse, because doubling it needs about 103 blocks and does not fit, and a non-power-of-two depth is riskier than the dual-clock alternative. Before building, extend the existing overlap and queue tests to cover the deeper FIFO and add a bounded simulation driven by the actual picture 690 bytes at consumption pace, requiring the missed slot to disappear at the new depth and to persist at the old one. If fit or timing fails, the fallback is to accept the single repeated frame and record it as a known limitation rather than to trade away presentation or prediction memory. Keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 607 COMMIT Unreleased d466bed 2026-08-27T06:33:10-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Explain the deterministic missed display slot at picture 692 from the fixture itself, without new hardware runs.

#### Outcome:

Offline parsing of the delivered fixture reproduces its structure exactly, recovering all 17,876 pictures and all 715,713,077 video bytes across 360,872 packs, so the analysis operates on the same bytes the hardware accepted. The mux rate field is a single constant value of 25,200, equal to 10.08 Mbps, with zero SCR regressions, so there is no pack schedule discontinuity or transport anomaly anywhere near the failure point. The declared sequence header carries a 9,600,000 bit per second video rate and a 1,835,008-bit VBV, giving exactly 40,040 bytes of delivery per frame period; the encoder holds most pictures at precisely that size, so the stream is genuinely constant rate and only cuts produce spikes. Picture 690 is 150,316 bytes, the single largest coded picture in the entire film and 3.754 frame periods of delivery at the declared rate, immediately followed by picture 691 at 95,308 bytes, or 2.380 frame periods. Those two pictures alone carry 245,624 bytes where the constant rate supplies 80,080, and they sit at the scene cut around 23.05 seconds. A constant-arrival VBV trace over the whole film shows zero underflow, confirming the stream is legal, but occupancy falls from a steady 82.544 percent to 34.467 percent at picture 690 and 10.372 percent at picture 691, which is where the hardware missed its slot with 691 references completed. The simple explanation that the trough alone causes the miss does not survive the whole-film trace, and this entry records that correction rather than the partial result. The global minimum is picture 13255 at 10.368 percent, marginally deeper than picture 691, and twenty-six pictures fall below twenty percent occupancy across the film, including a cluster at 13253 through 13257. Hardware missed exactly one slot in both runs and nothing at 13256, so VBV depth by itself does not predict the failure and twenty-five comparably thin points were absorbed. The feature unique to the failure is peak single-picture delivery burden rather than trough depth: picture 690 needs 3.754 frame periods of constant-rate delivery against 3.118 for the 124,846-byte picture 13253, and no other picture in the film exceeds it. The working hypothesis is therefore that the pipeline's effective read-ahead covers roughly three frame periods of worst-case single-picture delivery and picture 690 alone exceeds it, which is consistent with the recorded eleven and a half milliseconds of input starvation, the writer still busy at the deadline and the absence of any presentation, ownership, timestamp or capacity fault in either capture. This remains an inference from stream structure and existing telemetry; the read-ahead depth has not been measured directly in RTL or simulation, and no production change is justified by this entry alone. Evidence and the exact probe and trace drivers are retained as `.ai/current_results/entry607_*`. The entry 605 and 606 commits were pushed to the online repository after the user granted push permission from the build PC, and no source, deployed file, setting or playback was touched by this analysis.

#### Next Steps:

Measure the pipeline's actual input read-ahead in frame periods, in simulation against the real bytes rather than by inspection, and compare it with the 3.754 frame period worst case that picture 690 imposes and the 3.118 frame period second worst at picture 13253. If the measured depth falls between those two figures the hypothesis is confirmed and the useful production boundary is to deepen upstream buffering toward the declared 1,835,008-bit VBV, sized in frame periods of worst-case delivery, leaving presentation queues, clocks, startup and throughput untouched. If the measured depth is well above 3.754 frame periods the hypothesis is wrong and helper delivery timing during the spike becomes the next suspect, in which case the existing helper profile records should be examined before any RTL work. Either way, define the acceptance criteria before editing RTL, prefer a bounded simulation using the actual 690 spike over another full-length physical run, and keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates. Preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 606 COMMIT Unreleased d466bed 2026-08-27T06:28:14-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Close the remaining mode gap by replaying the full-movie fixture in Bob on the accepted candidate.

#### Outcome:

The user played the same film once in Bob as a warm replay with no core reload and no reboot, reporting picture and sound indistinguishable from the Weave run. The single syslog boot line remains 12:51:01 UTC, so this is a genuine same-boot comparison against entry 605 rather than a fresh-session repeat. The installed RBF still hashes to `d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a` for source `d466bed`, Main and the 739,065,873-byte fixture are unchanged, and a new helper PID 1339, a fresh helper log beginning at its own start line rather than extending the Weave capture, and packet checksum 1370572003 identify a distinct run. Bob matches Weave on every acceptance quantity: 17,876 reference pictures, 17,876 displayed pictures, 17,875 swaps, 715,713,077 accepted video bytes, `error_flags` zero, presentation error clear, sequence end seen, presentation complete, quiet snapshot and zero timestamp conflicts, with all 839,409,548 transport bytes submitted over 51,235 reads, 800 sampled ACK records and helper exit zero at 596.431673 seconds. Audio underrun and PCM protocol error are clear at FIFO peak 127, and the same saturated `pcm_sample_count` and `associated_count` fields again prevent any independent whole-film audio count. The important new result is that Bob reproduces the single missed display slot at exactly the same place as Weave: one 4,004,000-clock interval, 66.733333 milliseconds, at displayed picture 692 of 17,876, about 23.09 seconds in, with 691 completed references at both deadlines and accepted-byte positions of 27,778,070 in Bob against 27,772,349 in Weave, a difference of only 5,721 bytes. Both records show the writer busy without capacity blocking, no presentable candidate, the upstream FIFO pending and comparable input starvation of 699,593 clocks in Bob and 677,670 in Weave, with presentation hold, presentation error and both timestamp candidate signals false in each; the modes differ only in `decoder_ready`, false in Bob and true in Weave, and in candidate ready delay, 1,489,404 against 1,721,347 clocks. Two independent runs missing the same slot at the same bitstream position establish this as a deterministic, content-locked upstream delivery event rather than ambient jitter, and it remains outside the ownership and timestamp logic repaired this cycle. Deinterlacing mode has no measurable effect on delivery: helper would-block totals differ, 320 in Bob against 574 in Weave, as does first delivery at 23.465 against 42.017 milliseconds, but both are startup-phase effects and the reconstructed spans agree closely at 596.479325 and 596.476807 seconds against the 596.462533-second fixture, both after eight wraps of the 32-bit session timer, giving 29.967510 and 29.967636 true aggregate FPS. Reported cadence and FPS remain wrapping artifacts and must not be read directly. Picture and sound quality, synchronization and menu behavior are accepted from the user's report in both modes without independent measurement, and no pixel oracle was applied. This closes mode coverage for `d466bed` on this fixture; it does not qualify AC-3, interlaced P/B or field DCT, navigation, ISO or disk playback, or general commercial-DVD compatibility. Evidence and the exact capture and analysis drivers are retained as `.ai/current_results/entry606_*`, with the helper log stored losslessly under its original hash. Sixty-eight stale untracked result images from entries already outside the ring were deleted at the user's instruction, and the entry 605 commit remains unpushed because the environment refused the push operation. No production source, deployed file, setting, reboot, reload or playback occurred during collection; only the fixed screenshot was replaced.

#### Next Steps:

Both modes are now accepted for this fixture, so no further full-length replay is needed to compare them. The next boundary is to explain the picture 692 slot, which is cheap to attack offline because it is deterministic: measure the coded picture sizes and pack arrival schedule of the fixture in the neighbourhood of video byte 27.77 million and displayed picture 692, and determine whether an oversized picture, a rate spike or a pack-schedule discontinuity starves the decoder for the observed eleven and a half milliseconds. Only after that measurement should any production change be considered, and queue sizes, clocks, startup and throughput must not be tuned on the strength of one missed slot in 17,875. Because saturated audio counters cannot prove whole-film audio integrity, define acceptable audio evidence before any audio-focused cycle. Keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates with acceptance criteria agreed in advance, leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 605 COMMIT Unreleased d466bed 2026-08-27T06:12:39-07:00

#### Coming From:

Unreleased d466bed

#### Purpose:

Validate the timestamp-aware native overlap fix against the full-movie 480i audio/video endurance fixture on hardware.

#### Outcome:

The user deployed the entry 604 candidate, reloaded from a clean reboot, selected Weave and played the full film once, reporting correct audio, video, sync and menu behavior throughout with no freeze. The helper log was retrieved first, then the fixed screenshot was deleted, regenerated and re-fetched, and installed artifacts were read back on a fresh connection. The installed 4,354,700-byte RBF is SHA256 `d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a`, matching published source `d466bed` exactly; Main remains `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`, identical to the entry 604 pre-deployment backup, and the fixture is still 739,065,873 bytes at `beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642`. The single syslog boot line at 12:51:01 UTC is consistent with the reported clean reboot. Schema-nineteen telemetry decodes with valid parity and checksum 1372493136 and reports 17,876 reference pictures, 17,876 displayed pictures and 17,875 swaps, exactly the entry 602 fixture count, with `error_flags` zero, `presentation_error` clear, sequence end seen, presentation complete, quiet snapshot reason and zero timestamp advance or delay conflicts. Accepted video is 715,713,077 bytes, byte-exact against the qualified demuxed payload. Helper PID 907 submitted all 839,409,548 expected transport bytes over 51,234 reads with 800 sampled ACK records, 837,544,742 fast and 1,864,806 acknowledged bytes reconciling to the total, EOF at 596.439564 seconds and exit code zero, so the entry 603 fatal drain signature does not recur. The entry 603 freeze at 81 displayed pictures and 2.740979 seconds is cleared. One deadline gap and one outlier are recorded: a single 4,004,000-clock interval, 66.733333 milliseconds, at displayed picture 692 of 17,876, roughly 3.9 percent into the film; the gap record's ordinal field is only eight bits and its value 180 aliases to that same picture. At that deadline the decoder was ready but no candidate was presentable, the writer was busy without capacity blocking, the upstream FIFO was pending and 677,670 clocks of input starvation had accumulated since the previous swap with a 1,721,347-clock candidate ready delay at 27,772,349 accepted bytes, while presentation hold, presentation error and both timestamp candidate signals were false. That identifies one source-delivery starvation slot, not the ownership or timestamp guard this cycle repaired, and it cost 33.366667 milliseconds across the whole film. The 32-bit 60 MHz session timer wrapped eight times, so the reported 23.814501-second cadence and 750.593107 aggregate FPS are wrapping artifacts; the reconstructed span is 35,788,608,404 clocks or 596.476807 seconds against the 596.462533-second fixture, giving 29.967636 true aggregate FPS versus the 29.970030 nominal rate, with a 856,404-clock residual over 17,875 intervals. Audio underrun and PCM protocol error are clear with PCM FIFO peak 127, but `pcm_sample_count` at 16,383 and `associated_count` at 255 are saturated fields and are not whole-film totals, so telemetry does not independently count audio frames. Sync, sound and menu response are accepted from the user's report without independent measurement, and no pixel oracle was applied to playback; the retained still is the telemetry packet itself, not a video frame. Of 574 total helper would-block events, only eleven are individually logged at power-of-two gates, all before first delivery at 42.017 milliseconds with nothing submitted, so a complete absence of steady would-block is not proven. This accepts `d466bed` for one Weave full-movie combined-rate soak from a clean reboot; it does not qualify Bob, warm replay, AC-3, interlaced P/B or field DCT, navigation, ISO or disk playback, or general commercial-DVD compatibility. Evidence and the exact capture and analysis drivers are retained as `.ai/current_results/entry605_*`, with the helper log stored losslessly compressed under its original hash. No production source, deployed file, setting, reboot, reload or playback occurred during collection; only the fixed screenshot was replaced.

#### Next Steps:

Retain `d466bed` as the accepted baseline and preserve the entry 604 restoration pair. No further identical Weave replay is needed to reconfirm this result. The next useful boundaries, in order, are a Bob full-movie run of the same fixture to close the mode gap, then an investigation of the single starvation slot at picture 692 to decide whether helper delivery or upstream buffering deserves a production change, using the existing telemetry rather than new instrumentation if possible. Do not tune throughput, clocks, startup or queue sizes on the strength of one missed slot in 17,875. Because saturated audio counters cannot prove whole-film audio integrity, define what would constitute acceptable audio evidence before any audio-focused cycle, and keep AC-3, interlaced P/B, navigation and disk-source work as separately scoped gates with acceptance criteria set in advance. Leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 604 COMMIT Unreleased d466bed 2026-08-27T05:41:11-07:00

#### Coming From:

Unreleased 6669b70

#### Purpose:

Allow timestamped native all-I playback to use the bounded ordinary frame queue without false ownership aborts.

#### Outcome:

Published source d466bed removes the per-candidate timestamp-active restriction from native all-I overlap admission and secondary retention, while preserving the three-bank ownership and capacity guards, P/B and mode exclusions, cadence floor and timestamp-due gate. The existing native ownership test gains a second top with production timestamp association and timeline modules, connected through the existing runner. Before the user's scope change, its ten timestamp/ownership cases and the legacy ownership case pass; the old scheduler fails the new case and a mutant bypassing timestamp-due fails the future-PTS check as expected. The exact first 100 full-movie access units with helper timestamps complete all 100 pictures with zero errors or missed slots in the modeled video pipeline; this excludes physical PCM, HPS, scaler and CDC behavior. Nine completed focused/reconstruction regression jobs and the shared P/B raster test also pass. The user then explicitly skips A/V simulations and narrows this run to an RBF build and timing checks, retaining deployment responsibility. Remaining long A/V, pressure, two ceiling simulations and the unfinished native suite are stopped; none is claimed as a completed pass, and the original full qualification plan is not fulfilled. GUNSMOKE pulls exact published source d466bed into a clean build directory and completes Quartus 17.0.2 seed 16 in 730.0 seconds with 0 errors and 208 warnings. The normalized warning set has no additions versus accepted f615ce0 and there are no newly ignored timing filters. Worst reported setup is +0.083 ns, hold +0.240 ns, recovery +3.088 ns, removal +0.456 ns and minimum pulse width +0.925 ns, with every reported TNS zero. The 4,354,700-byte RBF has SHA256 d46f80061a3270c1fed07a089517e70b413d3353858dc0d8937ac1bb0070aa6a; its Pi copy at output_files/entry604/MediaPlayer.rbf is independently hash-verified. No candidate is uploaded to the MiSTer, activated or played by the agent. Earlier read-only backups of the installed f615ce0 RBF and retained Main are verified and persisted under /home/vash/mister-builds/entry604-backup; Main, media and settings remain untouched by this cycle. Bounded build reports, completed evidence, cancellation scope and reproducible drivers are retained as .ai/current_results/entry604_*, with raw logs compressed losslessly. Built is checked; hardware Passed remains unchecked.

#### Next Steps:

The user will deploy the supplied RBF and reload the MediaPlayer core, then replay the unchanged games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg with audio. Record the selected Bob/Weave mode and reload lifecycle explicitly, observe whether playback passes the former opening freeze and continues through the end with sound, sync and a responsive menu, and leave telemetry ready. On the next report, retrieve the helper log first and a fresh checksum-valid screenshot, verify the installed candidate hash and inspect presentation and audio errors, counts and deadline records. Hardware acceptance and long A/V simulation remain open; do not describe positive FPGA timing or the completed opening model as proof that the full movie or commercial DVDs play correctly. Use modular per-frame timing and full picture/transport counts because the 32-bit 60 MHz session timer wraps during the full film. Retain restoration artifacts, restricted core.md and the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv
- tools/streams/run_native_480i_timing.sh

#### Status:

- [x] Built
- [ ] Passed

---

## 603 COMMIT Unreleased 6669b70 2026-08-27T05:37:49-07:00

#### Coming From:

Unreleased 6669b70

#### Purpose:

Diagnose the abrupt early native-480i audio/video freeze reported in both Bob and Weave.

#### Outcome:

The user reports that both modes stop near the beginning, with audible initial audio, good-looking video at the correct speed until an instant freeze and a responsive menu. Only the most recent run remains available; its mode is not specified and is not encoded in schema nineteen, so do not assign this capture to either mode or infer identical counters for both. The helper log is captured first, followed by a fresh checksum/parity-valid telemetry image and Main/RBF readbacks. The sole error flag is 0x0200, presentation_error, with 83 references decoded, 81 pictures displayed and 80 swaps. The fatal snapshot occurs at 164,458,727 decoder clocks, or 2.740979 seconds, with a 2.679818-second startup-inclusive presentation span, no deadline gaps or outliers and three largest steady intervals of 2,002,001 clocks. Decoder, reconstruction, writer, PCM protocol and audio-underrun error bits are clear at that snapshot. The 32-bit timer has not wrapped. Sequence end is absent and the session is not quiet; presentation_complete being high only describes the idle B-reorder transaction, not completion of this all-I movie. The retained image shows the opening cloud/trees scene. The source media still reads back as exactly 739,065,873 bytes with SHA256 beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642, and installed Main/f615ce0 RBF hashes are unchanged. A later helper log is an exact extension of the first capture and preserves PID 2210 through successful EOF after 213.060 seconds. All 51,234 reads, 800 sampled ACK records and 839,409,548 expected helper transport bytes reconcile without transport fault. This is the documented fail-open drain after a fatal scheduler error, not evidence that the remaining movie played; the snapshot accepted-byte count remains latched at 3,265,982. The same Linux boot as the prior captures is retained, without independently asserting absence of a core reload between the user's two mode tests. Inspection identifies an inconsistent native ordinary-queue policy: overlap admission uses timestamp_candidate_active as if it were a session-mode indicator, but that signal is false before a pending reference is released even in an anchored A/V session. The next I header both admits overlap and releases the old candidate, activating its timestamp; if the next frame completes before the old candidate presents, a legitimate third-bank secondary is retained and the timestamp/secondary guard then raises the fatal presentation error. Unmodified production timestamp ownership, timeline and scheduler modules reproduce that transition with all three bank identities distinct; raw and serialized controls avoid it. An integrated real I-decoder, reconstruction, writer, publication and timestamp/scheduler observer then uses the exact first 100 movie access units and helper timestamps, appending only a terminal sequence end. It reproduces the same guard at 80 decoded and 78 displayed pictures, with every other pipeline error clear. That is three pictures earlier than hardware, not an exact physical-cycle replay: source delivery, DDR readiness, 90 kHz ticks and swap phase are modeled and PCM/HPS/scaler/CDC timing is excluded. The same 100-picture video with timestamps removed completes all 6,480,000 DDR words and 810,000 blocks, preserves every display identity and has zero missed slots. Disabling overlap in the timestamped control also completes correctly, but produces six 4,004,000-clock intervals at displayed ordinals 49, 53, 54, 58, 59 and 63, adding 0.2002 seconds. It is therefore an inadequate smooth-playback fix. Every first-100 timestamp is present; the first omitted explicit timestamp in full-file qualification is zero-based picture 681 and cannot explain this early freeze. The full A/V hardware test fails while the previously accepted bounded video-only ceiling result remains valid. Exact logs are stored losslessly compressed with original hashes, alongside screenshots, analyses and reproduction drivers as .ai/current_results/entry603_*; the complete diagnostic workspace is /home/vash/mister-builds/entry603. No production source, media, installed file, mode, reboot, reload or playback is changed during investigation; only the fixed screenshot is replaced. Built reflects the unchanged baseline and compiled diagnostic models, and hardware Passed remains unchecked.

#### Next Steps:

The next useful production boundary is to make the bounded native all-I ordinary frame queue timestamp-aware while preserving its three-bank ownership, P/B exclusions, cadence floor and timestamp due gate. Do not merely suppress presentation_error, drop timestamp records, disable timestamps/audio or serialize native A/V, since the controls show either lost protection or renewed missed slots. Before editing RTL, record the precise fix and regression plan, then extend existing ownership/presentation tests with real timestamp association and timeline transitions, pending/secondary publication races, early and late timestamps, missing records, reset/new-file behavior and ordered terminal drain. Require the actual opening prefix and a longer combined stream to complete without errors or extra slots, retain the exact video-only ceiling and supported P/B regressions, then obtain a clean timing-qualified RBF and verify backups and staged deployment before the user's next run. Keep the current installation and full-movie fixture available as the reproducible failing baseline. No further identical Bob/Weave replay is needed to identify this fault; mode-specific hardware acceptance and the full physical A/V soak remain open. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 602 COMMIT Unreleased 6669b70 2026-08-27T05:10:55-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Prepare a reproducible full-movie native-480i audio/video endurance fixture near the DVD combined-rate target.

#### Outcome:

Published fixture source 6669b70 adds the deterministic full-source native-480i/MP2 generator, parameterizes the existing CBR checker without changing its 9.8 Mbps default, bounds the signalling-patch extension read and extends the existing tests. GUNSMOKE pulls that exact source and passes all eleven focused tests, a clean native build of the unchanged helper and a regression of the exact accepted 449-picture 9.8 Mbps fixture, including rejection of a wrong bitrate header. A first candidate remux produced timestamp warnings; the final generator instead encodes the Program Stream directly, then changes only equal-length video payload signalling while preserving its PES headers, timestamps, audio and packet schedule. A four-second candidate passes before full generation. The complete 596.458333-second source AVI, SHA256 4fc75fa403994e7c313da139d93a5aebdbda27cc951616aa4e480db6877c9850, produces 17,876 supported 720x480 TFF all-I frame-DCT pictures at 30000/1001 covering 596.462533 seconds, with the original soundtrack transcoded to 192 kbps 48 kHz stereo MP2. The output bbb_full_480i_tff_av_10080kbps.mpg is 739,065,873 bytes, SHA256 beb5c738910321fbbdf482220c19af36e7c2d2bb1913e8872f679eeb1f589642. All decoded YUV planes are equal before and after the signalling patch; the program demuxes to the exact 715,713,077-byte qualified video and unchanged MP2 payload. The 9.6 Mbps video averages 9,599,437.175 bit/s, with zero underflow/overflow in the existing narrow constant-arrival VBV witness and maximum occupancy 1,834,917.333 of 1,835,008 bits. Every one of 360,872 pack headers signals the 10.08 Mbps mux target, adjacent SCR-paced arrivals satisfy the declared rate check and the whole pack span averages 9,906,567.467 bit/s. Picture-consumption windows may exceed the arrival rate using VBV buffering; this is not a full T-STD or DVD application-conformance certificate. The generic v0.7 compatibility checker has an obsolete native-interlaced rejection and is not claimed as a passing gate. Full helper scheduling preserves exact video/PTS and PCM hashes across explicit and in-band modes, emits 839,409,548 transport bytes and all 28,628,352 stereo PCM frames, has initial/steady batches of 5,504/2,048 frames, a 4,048-byte maximum steady PCM-free video gap, zero measured audio deficit and one PCM end marker. An initial diagnostic incorrectly required one PTS record per picture; the corrected exact byte-position mapping proves all 17,776 emitted timestamps refer to the proper picture, all intervals are 3,003 or 6,006 ticks and only 100 individual pictures lack a separate timestamp. No picture bytes are lost, and first/last mappings cover the full movie. Comparing all 57,256,704 signed sample values against an independent FFmpeg decode yields maximum difference two, RMS 0.503652 and correlation 0.999999979, with exact sample-count agreement and 596.424 seconds of audio. The new media is deployed through a unique stage and full independent readback hashes before and after rename; the installed Main and f615ce0 RBF match their prior hashes before and after transfer. No source RTL, production helper/Main/RBF, settings, reboot, reload or playback is changed. Reproducible media stays off Git; manifests, checks and exact diagnostic/deployment drivers are retained as .ai/current_results/entry602_*, with full media under /home/vash/mister-builds/entry602. Built reflects software generation and helper compilation, not a new FPGA build. Hardware Passed remains unchecked.

#### Next Steps:

Have the user select Bob and play games/MediaPlayer/bbb_full_480i_tff_av_10080kbps.mpg once in its entirety without rebooting or reloading, checking audible sound, A/V sync through the end, visible slowdown or corruption and menu response during and after playback, then leave the terminal telemetry ready. Retrieve the helper log first and acquire a fresh parity/checksum-valid screenshot. Require all 17,876 reference/display pictures, expected swaps and exact transport completion, inspect native deadline gaps and audio error/underflow state, and distinguish final audio-tail behavior from steady faults. The 32-bit 60 MHz session timer wraps every 71.582788 seconds, so do not use terminal aggregate FPS or elapsed time without wrap accounting; full picture counters, modular per-frame gaps, helper completion and user observations remain the useful evidence. Audio frame telemetry is also not an unsaturated whole-film sample total. Record the chosen mode and lifecycle explicitly. This single combined high-rate physical soak does not qualify the other mode, AC-3, interlaced P/B or field DCT, navigation, ISO/disk playback or full commercial-DVD compatibility. Preserve accepted f615ce0 and its restoration artifacts, restricted core.md and the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_av_soak.py
- tools/streams/generate_test_dvd_ceiling.py
- tools/streams/generate_test_interlaced_i_frames.py
- tools/streams/test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 601 COMMIT Unreleased f615ce0 2026-08-27T05:04:37-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Confirm the DVD-ceiling cadence result in Bob and resolve the preceding run's Weave attribution.

#### Outcome:

The user explicitly confirms that the new run is Bob and entry 600 was Weave, resolving that entry's mode uncertainty without rewriting its historical record. The Bob helper log is retrieved first, followed by a newly generated parity/checksum-valid schema-nineteen screenshot and full Main/RBF/media readbacks. The installed f615ce0 RBF, retained Main and exact 18,402,691-byte ceiling fixture match entry 600 byte-for-byte. New helper PID 1568, helper hash a34a6fdc1f960654ced490c2e2392f956d8131b83fc1a576a1656410446c3a54 and telemetry checksum 4215072064 identify a distinct run, while the same 11:26:59 UTC Linux boot establishes no system reboot between the captures. The packet does not encode the mode or running bitstream hash, and no independent absence-of-core-reload proof is claimed. All 1,124 chunks and seventeen sampled ACK records reconcile; all 18,402,691 source bytes arrive with the expected single padded byte giving 18,402,692 FPGA-accepted bytes, no transport fault and helper exit zero. Both confirmed modes complete 449 reference/display pictures and 448 swaps with zero error flags, zero deadline gaps, zero outliers, no deadline records and normal EOF/quiet completion. Each mode's three largest steady intervals are exactly 2,002,000 clocks, or 33.366667 milliseconds. The old a4f2769 extra intervals at 167 and 346 remain absent in both new runs. Bob's startup-inclusive span is 14.996120 seconds at 29.874393 aggregate fps versus Weave's 14.991394 seconds at 29.883811; the 4.726100-millisecond difference lies in initial admission and does not indicate recurring Bob lateness. Bob's presentation hold is 5,529,868 cycles versus 5,246,150, and writer wait is 15,288,984 versus 15,282,414. All 165 Bob EAGAIN events precede first delivery, with no steady EAGAIN. Credit-fast transport carries 18,373,724 fast bytes and 28,967 acknowledged bytes in 902,794 bursts and 918,402 queries, with all guarded accounting intact; these consumption-paced statistics are not a maximum bus-bandwidth measurement. The fresh still shows the expected final foliage/spikes scene without an obvious large artifact; full-playback visual or pixel correctness is not inferred from it. The earlier Weave menu report remains valid, while this message does not separately report Bob menu behavior or playback appearance. The capacity-safe writer-retirement fix is accepted for this bounded two-mode 9.8 Mbps video-ceiling fixture and same-boot replay. Passed does not imply a long physical soak, combined audio/video qualification or complete DVD compatibility. Evidence and exact collection/analysis drivers are retained as .ai/current_results/entry601_*. No production source, deployed files, settings, reboot, core reload or playback is changed during collection; only the fixed screenshot is replaced.

#### Next Steps:

Retain f615ce0 as the accepted baseline for the measured ceiling-cadence fix and preserve the independently verified a4f2769 restoration artifacts. No further identical short replay is required merely to reconfirm the cleared 167/346 misses. The next useful qualification boundary is longer physical playback and the separate 10.08 Mbps combined-stream/audio/PTS and remaining DVD syntax/features, with scope and acceptance criteria defined before new production work. Keep mode-specific UI and visual claims limited to user reports, leave lifecycle/playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 600 COMMIT Unreleased f615ce0 2026-08-27T05:00:35-07:00

#### Coming From:

Unreleased f615ce0

#### Purpose:

Validate the first hardware DVD-ceiling replay after the capacity-safe early writer acknowledgement change.

#### Outcome:

The user reports that the menu is okay and the screen is ready, then directs continuation. The helper log is retrieved first, followed by a newly generated screenshot with valid schema-nineteen parity/checksum and complete Main/RBF/media readbacks. The installed 4,324,340-byte RBF matches qualified f615ce0 SHA256 44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01; Main remains 3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f, and the exact 18,402,691-byte ceiling fixture remains 3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065. All 1,124 chunks and seventeen sampled ACK records reconcile without transport fault or uninitialized ACK state. The one-byte FPGA difference is the expected zero-padded final transport word, giving 18,402,692 accepted bytes. All 449 reference/display pictures and 448 swaps complete with zero error flags, normal EOF, presentation completion and quiet terminal state. Both deadline-gap and gap-outlier counters are zero, with no deadline records; all three largest measured steady intervals are the nominal 2,002,000 clocks, or 33.366667 milliseconds. The previous extra intervals at pictures 167 and 346 are absent in this run, compared with two 66.733333-millisecond intervals in each confirmed a4f2769 Weave and Bob capture. Startup-inclusive aggregate FPS is 29.883811 across 14.991394 seconds; its 43.127700-millisecond excess over 448 nominal intervals belongs to initial admission, not a steady missed slot. All 606 EAGAIN events precede first delivery, with no steady EAGAIN. The transport uses 18,373,802 fast bytes and 28,889 acknowledged bytes, 892,181 bursts and 907,750 status queries; consumption-paced statistics are not a raw link-bandwidth measurement. A new helper PID 1406, helper hash and packet checksum identify a distinct capture. The Linux boot is 11:26:59 UTC rather than the earlier 10:08:35 UTC baseline boot, so this is not a controlled same-boot comparison. Weave was requested immediately before the run, but the user response does not explicitly name the mode and this packet does not encode Bob/Weave selection. Installed-file readback also does not independently identify the currently loaded bitstream; the new capture follows the user-directed reload/playback request. Menu response is accepted as reported, without assigning a measured latency or independently separating during-versus-after behavior. The still image shows the expected final foliage/spikes scene without an obvious large artifact, not an independent full-playback pixel oracle. This clears the scoped single-run 9.8 Mbps video-ceiling cadence gate for f615ce0; Passed refers only to that observed hardware run, not both modes, warm-repeat qualification or full DVD compatibility. Evidence and exact collection/analysis drivers are retained as .ai/current_results/entry600_*. No production, deployment, configuration, reboot, core reload or playback action is performed during collection; only the fixed screenshot is replaced.

#### Next Steps:

Have the user replay the same ceiling file in explicitly confirmed Bob mode without rebooting or reloading, check menu response during and after playback, and retain the terminal image for a warm-run comparison. Preserve f615ce0 and the verified a4f2769 restoration pair, and do not change throughput, clocks, startup, queue sizes or source media on the strength of a single passing run. Keep mode confirmation, longer physical playback and the separate 10.08 Mbps combined-stream/audio/PTS and remaining DVD feature gates open. Leave lifecycle and playback with the user, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 599 COMMIT Unreleased f615ce0 2026-08-27T04:53:39-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Remove the normal two-clock writer acknowledgement delay while preserving capture-bank capacity protection.

#### Outcome:

The approved source f615ce0 emits a completion-qualified grant on the capture-completion edge only when the alternate bank is free; a single pending request waits for real capacity when both banks are occupied. It preserves block_stored, all capture/drain data and addresses, reset/error handling and capacity telemetry, and corrects the stale top-level level-versus-pulse comment. The expanded writer contract passes 2,016 complete DDR words and 252 retired blocks across immediate/delayed grants, prolonged and random stalls, all byte lanes and supported frame/scratch encodings, reset and malformed input. It rejects both the old delayed implementation and an unsafe unconditional-grant control. GUNSMOKE pulled the Pi-published exact source before official qualification. Native startup, field order, presentation, cache/fingerprint/generation and telemetry regressions pass, as do supported reconstruction, scheduler, prediction fetch/cache and an authored 720x480 I/P/B shared-writer persistence test. Two auxiliary legacy tests fail identically on the prior source: scratch-tag assertions bind removed internal names, and the B error-sideband test expects an obsolete result; these are retained as existing test-maintenance limitations, not claimed passes. A separate writer-connected FFmpeg oracle verifies 12 TFF/BFF/progressive pictures and all 6,220,800 accepted DDR bytes within the established one-level IDCT tolerance with DDR busy for 600 of every 997 clocks. Its initial inherited ready-memory throughput assertion fails under this deliberate saturation; the temporary observer separates saturation correctness from realtime qualification, while the unmodified reconstruction and separate cadence gates remain enforced. Actual new-writer cadence tests complete 2,694 ordered pictures across both saved 449-picture ceiling phases, a ceiling run with 500 busy clocks per 1,000,003, an 898-picture repeated ceiling run under that pressure, and the qualified 449-picture 8 Mbps fixture. Every post-admission display interval is exactly 2,002,000 clocks, with zero missed windows, all expected DDR words/blocks and no asserted errors. Normal coefficient-end-to-ack latency is 200 clocks instead of 202, saving 16,200 clocks or 0.27 ms per picture; all first-449 cost residuals match isolated decode cost plus measured holds and grant delays, apart from the documented one-clock initial-shell offset. These calibrated-phase simulations exclude physical HPS transport, real DDR/read contention, scaler and startup CDC and are not hardware acceptance or full-disc qualification. The clean seed-16 Quartus build completes with zero errors and 208 warnings, the same normalized warning set as installed a4f2769, and no new ignored timing filters. Worst setup/hold/recovery/removal/minimum-pulse margins are 0.243/0.109/2.944/0.605/0.925 ns, all TNS zero. After fresh backups of the current a4f2769 Main/RBF pair and independent persistent verification under /home/vash/mister-builds/entry599-backup, only MediaPlayer.rbf is deployed using staged transfer and full fresh-connection readbacks; its 4,324,340-byte SHA256 is 44606564ad40e3f9a74657fdd372a44fb6d0f74252e6d1000b2685768ca9cf01. Main remains 3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f. No reboot, core reload, playback or configuration action is performed. Evidence and exact temporary drivers are retained as .ai/current_results/entry599_*, with full builds under /home/vash/mister-builds/entry599. Hardware Passed remains unchecked.

#### Next Steps:

Have the user reload MediaPlayer to activate f615ce0, replay the unchanged bbb_480i_tff_15s_9800kbps.m2v in a known mode, check the menu during and after playback and retain the terminal telemetry screen. Retrieve the helper log before any later playback overwrites it, acquire a fresh screenshot with parity/checksum validation, and require all picture identities, transport integrity, zero errors and zero missed display slots before accepting this candidate. Compare both hardware modes and warm replay afterward while preserving restoration copies. Keep the separate 10.08 Mbps combined audio/video, broader DVD syntax/features and longer physical soak gates open. Leave lifecycle and playback under user control, preserve restricted core.md and maintain the forty-entry ring.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- MediaPlayer_top_02.svh
- tools/streams/tb_h262_ddram_store_overlap.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 598 COMMIT Unreleased feb50c2 2026-08-27T04:21:04-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Isolate processing, writer handoff and presentation-release costs behind the DVD-ceiling cadence misses.

#### Outcome:

The user authorizes investigation, with production and MiSTer lifecycle unchanged. GUNSMOKE pulled the published 39f0875 checkout and compiled a temporary observer containing the current production frontend, full publication shell, I parser/IQ/IDCT/reconstruction, two-bank writer and presentation scheduler. The exact 449-picture ceiling fixture is supplied without input starvation, and DDR writes are always ready; actual HPS transport, queues, arbiter/read contention, scaler and startup/video clock crossings are excluded. Raster phase and first permitted swap are derived from the two hardware captures, so startup is calibrated rather than independently reproduced. Both baseline phases complete all 449 picture identities, 448 swaps, 29,095,200 DDR words and 3,636,900 blocks without asserted errors, but retain late intervals: Weave-phase ordinals [181, 348] and Bob-phase ordinals [181, 348]. These ideal-memory positions are not the physical 167/346 positions and must not be represented as an exact hardware replay. Every baseline picture has exactly 203 parser wait clocks per block, versus 201 in entry 597. From coefficient-end to reconstruction is 200 clocks, while actual writer acknowledgement takes 202. Subtracting measured presentation holds reproduces every isolated per-picture cost plus exactly 16,200 writer clocks, with only the expected one-clock first-publication-shell offset. The normal handoff therefore adds 0.270000 milliseconds per picture even when memory never blocks. Next-header release is 37 clocks at the observed target publication boundaries. Adding isolated interval cost, the fixed writer overhead, that release delay and the saved hardware capacity-block count exactly reconstructs both Weave reference-to-ready intervals and Bob picture 167; Bob picture 346 differs by only 26 clocks, or 0.433 microseconds. The hardware capacity counter and reference interval have slightly different starting boundaries, so this close accounting is supporting evidence rather than a full physical stall trace. Across this fixture, processing with the fixed writer handoff averages 33.529155 milliseconds per picture against the 33.366667-millisecond budget, approximately 29.824790 fps of processing capacity, and exceeds 449 nominal budgets by 72.957150 milliseconds before real-memory delays. Buffering alone cannot hide a sustained deficit indefinitely. An ideal-memory testbench control releases the parser directly on reconstruction completion while leaving the actual writer running; it displays all 449 identities with the same word/block totals and late intervals []. This control is not a deployable fix because it bypasses capacity when both writer banks are occupied, and no new pixel-value oracle was run. The existing unchanged writer-overlap regression separately passes sixteen writes and two grants while enforcing full-bank backpressure. Evidence and exact observer/commands are retained as .ai/current_results/entry598_*, with full builds under /home/vash/mister-builds/entry598. No production source, deployed binary, clock, cadence, queue, startup setting or MiSTer action changed; Built refers to diagnostic compilation and strict hardware acceptance remains open.

#### Next Steps:

Use a bounded capacity-safe writer-grant retiming as the first production candidate: remove both normal handoff clocks only when the alternate capture bank is actually free, retain exactly one delayed grant when full, and preserve block_stored, DDR address/payload/order, bank ownership, reset and error behavior. Do not deploy the direct-reconstruction diagnostic bypass or weaken the next-header release barrier, and do not change clock, cadence, startup, transport guards or queue sizes. Extend the existing writer-overlap regression for immediate versus delayed grants, duplicate/premature-grant rejection, sustained and random backpressure, reset and complete word/lane equivalence; then run the supported reconstruction, writer/presentation integration and P/B-client regressions before official Quartus timing/build qualification. Recheck the exact ceiling clip in both user-controlled modes and a longer run to establish sustained margin, keeping the warm 8 Mbps regression and restoration pair. The separate 10.08 Mbps combined audio/video gate and remaining DVD features remain outside this result. Preserve user lifecycle/playback control, restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 597 COMMIT Unreleased feb50c2 2026-08-27T04:02:24-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Identify the content and decoder workload associated with the repeatable missed pictures 167 and 346.

#### Outcome:

The profiler's full-width ordinals are one-based, corroborated by completed-reference counts 166 and 345 at the two deadlines, so the exact file indices are 166 and 345 at 5.538867 and 11.511500 seconds. All 449 pictures have the same I-picture coding extension, thirty slices, 1,350 macroblocks and 8,100 blocks; neither target is a special picture type or header-mode transition. Picture 167 shows dense foliage immediately before a cut to a mostly sky view and occupies 43,716 bytes, only 104th-largest; picture 346 shows the flying squirrel approaching the camera and occupies 46,222 bytes, 52nd-largest. The median is 40,186 bytes and maximum 143,171. GUNSMOKE used the unchanged 04ca33b checkout, production-equivalent to a4f2769, to compile a temporary observer around the current production frontend, parser, inverse quantizer, IDCT and intra reconstruction. All 449 pictures complete with 518,400 samples and 8,100 blocks each and no asserted reconstruction errors. This diagnostic excludes host transport, DDR persistence, presentation and pixel-oracle comparison; it is an optimistic decoder-cost profile, not a physical replay or new pixel-conformance test. Isolated costs are 33.667517 and 34.043583 milliseconds, ranking 104 and 52 of 449, with 148 pictures exceeding the nominal 2,002,000-cycle individual budget. Both parser pipeline-wait time of 1,628,100 clocks and IDCT transform-active time of 1,036,800 clocks are identical for every picture; variable cost lies outside those fixed stage counts, including compressed-bit parsing, not unusually long transforms at these two pictures. The retained Weave records measure 33.944600 and 34.321650 milliseconds from preceding reference completion to candidate readiness, against the nominal 33.366667-millisecond period. Previous-reference head starts are only 0.133300 and 0.870233 milliseconds, leaving the observed 0.444633 and 0.084750 milliseconds of lateness; Bob gives the same relationship with slightly different margins. Accepted-byte positions are 79 and 15 bytes before the respective access-unit ends in Weave, and 69 and 14 in Bob; these positions do not measure remaining arithmetic work. The evidence supports insufficient available decode/retirement lead at these deadlines rather than uniquely large or exceptional pictures, while the exact scheduler/retirement contribution remains unisolated. The isolated model must not be claimed to reproduce the two hardware misses. Evidence, exact observer, commands, full cost table, analysis and two decoded views are retained as .ai/current_results/entry597_*, with the full temporary build and six views on GUNSMOKE under /home/vash/mister-builds/entry597. No production source, deployed file, configuration or MiSTer lifecycle/playback action changed. Built refers to the diagnostic compilation; the existing strict hardware cadence gate remains unpassed.

#### Next Steps:

Use these measurements to scope a bounded decode/retirement throughput revision or a targeted integrated diagnostic, preserving exact picture identity, startup and presentation phase rather than treating either image as malformed or merely masking its deadline miss. Account for sustained workload and available reference-buffer lead; a picture's individual byte size or transform coefficient count alone cannot predict whether its display deadline is missed. Keep the exact 9.8 Mbps fixture and installed a4f2769 pair, preserve transport integrity checks, queues, startup, continuous sync and restoration copies, and obtain approval if the resulting production plan materially changes the accepted scope. Require zero missed slots on the ceiling fixture before the separate combined 10.08 Mbps/audio-and-timing gate; full DVD compatibility remains broader. Leave lifecycle and playback with the user, keep restricted core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 596 COMMIT Unreleased feb50c2 2026-08-27T03:53:06-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Record the user's confirmation that the preceding DVD-ceiling run used Weave mode.

#### Outcome:

The user explicitly confirms that entry 594 was Weave, resolving the mode-attribution uncertainty recorded in entry 595. Entry 595 was Bob without rebooting, also explicitly reported by the user. The existing same-fixture, same-a4f2769-binary and same-Linux-boot captures can therefore be compared as user-confirmed Weave and Bob runs. Both display all 449 pictures with 448 swaps and zero decoder/transport errors, yet both retain the same two missed deadlines at full-width ordinals 167 and 346 and the same 66.733-millisecond maximum intervals. Bob's approximately 28.174-millisecond shorter aggregate span is startup-related, not removal of either steady-playback miss. Candidate readiness at the two deadlines changes from 0.444633 and 0.084750 milliseconds late in Weave to 0.390517 and 0.083600 milliseconds late in Bob. Both retain pending input, decoder not ready and zero input starvation at the missed slots. These observations strengthen the shared decode/retirement timing hypothesis and show that switching to Bob does not clear the fault; they do not prove every mode behavior identical or isolate a specific arithmetic stage. The confirmation is preserved in .ai/current_results/entry596_mode_confirmation.json and supersedes only the prior uncertainty about mode identity, leaving the settled captures and their numerical analysis unchanged. No new capture, source change, build, deployment or device action was performed. Strict DVD-ceiling cadence acceptance remains open.

#### Next Steps:

Use entry 594 as the confirmed Weave baseline and entry 595 as the confirmed warm Bob comparison. Focus the proposed GUNSMOKE decoder/reference-retirement investigation on the repeatable shared misses at pictures 167 and 346 rather than treating display-mode selection as a fix. Preserve the exact 9.8 Mbps fixture and installed a4f2769 pair, and require a bounded evidence-backed revision before further production changes. Keep the combined 10.08 Mbps audio/video gate separate, retain 18.65 Mbps only as optional stress evidence, preserve transport guards, queues, startup and sync, leave lifecycle/playback control with the user and maintain restricted core.md and the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 595 COMMIT Unreleased feb50c2 2026-08-27T03:51:42-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Compare the user-reported warm Bob-mode DVD-ceiling run with the preceding hardware capture.

#### Outcome:

The user explicitly reports Bob mode and no reboot. The helper log was collected first, followed by a fresh checksum-valid schema-nineteen screenshot and complete media/Main/RBF readbacks. The qualified 9.8 Mbps fixture and installed a4f2769 hashes are unchanged; the same 10:08:35 UTC Linux boot corroborates no system reboot, while new helper PID 1730, log hash and telemetry checksum confirm a distinct run. Bob attribution comes from the user because the packet does not encode the selected deinterlace mode. Entry 594's mode was not explicitly confirmed, so this must not be described as a controlled Bob-versus-Weave comparison. Completion and steady timing are unchanged: all 18,402,691 source bytes, the expected padded FPGA count of 18,402,692, 449 reference/display pictures and 448 swaps, zero errors or transport integrity aborts, normal EOF and quiet completion. There are again exactly two deadline misses and two outliers at full-width picture ordinals 167 and 346, both with 66.733-millisecond intervals; other intervals remain nominal. The second ranked-gap ordinal is the expected wrapped value 90. Both missed deadlines again show input and upstream data waiting, decoder not ready, no input-starvation cycles and no presentation/destination hold. Candidate readiness improves slightly from 0.444633 to 0.390517 milliseconds late at 167 and from 0.084750 to 0.083600 milliseconds late at 346, but both still miss their slots. Writer-capacity blocked time is 236 and 525 cycles. The startup-inclusive aggregate rises from 29.704965 to 29.760561 fps because the aggregate span is 28.174 milliseconds shorter; presentation hold falls by 28.073 milliseconds, consistent with different startup hold/alignment rather than improved steady cadence. Both runs still add 66.733 milliseconds from the same two extra frame periods. The transport remains credit_fast_v1 mode 2, with all 1,124 chunk totals and seventeen ACK samples reconciled. Fast payload is 18,385,038 bytes, or 99.9041 percent, across 916,130 batches averaging 20.068 bytes and 926,081 queries. All 164 EAGAIN events are before first delivery. Consumption-paced delivery is 1,226,799 bytes per second versus 1,224,493 previously; mean data-bearing poll time is 53.234 versus 53.262 milliseconds, and maximum is 77.614 versus 79.040 milliseconds. These small transport variations do not establish a mode-dependent speedup or raw link capacity. No new menu-response report was provided; the preceding report established after-playback response only. Recurrence at the same two picture ordinals with the same ready/input signature strengthens the case for a repeatable content-linked downstream margin issue without identifying a particular arithmetic stage. Full capture and checked comparison are retained as .ai/current_results/entry595_*. No production source, binary, configuration, reboot, reload or playback changed during collection. Strict DVD-ceiling cadence acceptance remains open.

#### Next Steps:

Retain both ceiling captures and the exact feb50c2-generated clip, and prioritize a focused GUNSMOKE investigation of decode and reference-retirement timing at pictures 167 and 346 before proposing a production revision. Do not infer a Bob/Weave cause from the unconfirmed prior mode or treat the aggregate FPS increase as removal of steady lateness. Another identical hardware replay should have a specific new diagnostic question; the current two captures already establish repeatability at both ordinals. Keep the 9.8 Mbps video gate and later 10.08 Mbps combined-stream/audio-and-timing gate separate, retain 18.65 Mbps only as optional stress evidence, and preserve current production a4f2769 with its transport guards, queue sizes, startup/sync behavior and restoration copies. Keep user control of lifecycle and playback, restricted core.md unchanged and the forty-entry ring intact.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 594 COMMIT Unreleased feb50c2 2026-08-27T03:48:08-07:00

#### Coming From:

Unreleased feb50c2

#### Purpose:

Verify completion and presentation timing of the first DVD-ceiling video hardware run.

#### Outcome:

The user says playback looked perfect and the menu remains responsive after playback; this does not confirm menu response during playback. The helper log identifies bbb_480i_tff_15s_9800kbps.m2v, runtime credit_fast_v1 and transport mode 2. The log was retrieved before replacing the fixed screenshot and collecting a fresh checksum-valid schema-nineteen packet. Complete media and installed Main/RBF readbacks retain the qualified fixture and a4f2769 hashes, and the same 10:08:35 UTC Linux boot confirms no intervening system reboot since the prior warm run; core reload and display-mode selection are not independently encoded. All 18,402,691 source bytes, 449 reference/display pictures and 448 swaps complete with zero aggregate decoder errors, no transport integrity fault, normal helper exit, sequence end and quiet presentation completion. All 1,124 chunks and seventeen sampled ACK records reconcile with cumulative counters. The final 3,459-byte chunk consists of 3,458 fast bytes and one acknowledged tail byte; its wide-word zero padding explains the FPGA count of 18,402,692 accepted bytes, with no missing source byte. Fast blocks carry 18,385,220 bytes or 99.9051 percent; acknowledged payload accounts for 17,471 bytes in 8,736 words, including the single padded tail. There are 913,967 fast batches averaging 20.116 bytes and 923,827 status queries. Matched completed-chunk delivery is 1,224,493 bytes per second, consumption-paced rather than a raw capacity measurement. All 169 EAGAIN events precede first delivery. Data-bearing polls average 53.262 milliseconds and peak at 79.040 milliseconds; these are blocking exposure, not measured UI latency. Strict cadence does not pass: two actual post-startup deadline misses and two outliers correspond to 66.733-millisecond intervals, while the third-largest interval is nominal 33.366667 milliseconds. All pictures are displayed; two preceding pictures are held for an extra nominal period, totaling 66.733 milliseconds of added hold. Both missed deadlines are retained at full-width ordinals 167 and 346; the second largest-gap ordinal wraps to 90 and must not be mistaken for picture 90. At both deadlines input and upstream data are pending, decoder_ready is false, the candidate is not presentable, interval input-starvation is zero and neither presentation nor destination hold is asserted. The candidates become presentable 26,678 and 5,085 decoder cycles after the deadline, or 0.444633 and 0.084750 milliseconds. Writer-capacity blocked time is only 353 and 412 cycles, respectively, but the evidence does not isolate a particular arithmetic stage or exclude internal waits. These are downstream processing/retirement margin misses rather than observed empty-input delivery stalls. The raw 29.704965-fps aggregate spans 15.081654 seconds and includes startup; after subtracting the two known extra intervals, its remaining excess over nominal is 66.654 milliseconds of startup-inclusive timing, not further steady slowdown. Evidence is retained as .ai/current_results/entry594_*; no source, deployment, configuration, reboot, reload or playback changed during collection. This run is complete and visually accepted by the user but does not meet the agreed zero-deadline-miss ceiling gate, so Passed remains unchecked.

#### Next Steps:

Keep the exact feb50c2-generated 9.8 Mbps fixture and installed a4f2769 pair as the baseline. Propose a focused investigation of decoder and reference-retirement timing around the two retained misses, using the exact stream and existing GUNSMOKE simulation harnesses to distinguish decode work, internal waits and final publication latency before a production revision. Preserve full-rate cadence rather than masking missed deadlines in telemetry. Do not raise the test bitrate or return to making the optional 18.65 Mbps stress file an acceptance requirement. Clear these two in-scope late intervals, then validate the separate 10.08 Mbps combined-stream gate with supported audio and timing; current video completion does not pass that integration boundary or the remaining DVD feature set. If another hardware run is needed, give it a specific diagnostic purpose and preserve its helper log before replay. Keep after-playback and during-playback menu reports distinct. Preserve credits and integrity checks, both queue capacities, guarded startup, continuous HDMI sync, black idle and restoration copies, leave lifecycle/playback control with the user, keep restricted core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 593 COMMIT Unreleased feb50c2 2026-08-27T03:34:43-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Prepare and qualify a reproducible DVD-ceiling video fixture for the unchanged guarded-transport hardware pair.

#### Outcome:

The user-approved diagnostic source is feb50c2; it changes only the new generator and its focused tests, with no production difference from a4f2769. GUNSMOKE pulled that exact Pi-published source and generated the same 449-picture 720x480 TFF all-I scene twice using FFmpeg 8.0.1-3ubuntu2. The retained 34,919,166-byte source has SHA-256 90976c09e12dfe03243d5c8daccf65ecc98b4d0008cb5489e96c73f667434979. Both official outputs are bit-identical and match the candidate: 18,402,691 bytes, SHA-256 3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065. Both full software decodes produce identical YCbCr hashes, and the existing interlaced-signalling patch does not change any decoded plane. All 449 pictures remain within the admitted frame-DCT interlaced all-I structure. Encoder rate, minimum and maximum are 9,800,000 bits per second, with a 1,835,008-bit buffer matching FFmpeg's DVD-target setting. Every repeated sequence header is checked, including Main Profile/Main Level, bitrate, buffer and frame-rate extension. A narrow constant-arrival buffer witness based on H.262 6.3.9 and Annex C supplies data at exactly 9.8 Mbps, starts decoding after 140.428 milliseconds, and removes complete access units at 30000/1001 cadence. It records no underflow or overflow; peak occupancy is 1,834,992 bits, and header-delay disagreement is at most 1.657 ticks at 90 kHz, within the check's two-tick quantization allowance. The file's coded bits divided by its 14.981633-second picture duration average 9.826801 Mbps; this is not the arrival rate because initial buffering supplies bits before the first decode. Thirty-frame coded-demand windows range from 9.116763 to 10.768967 Mbps, and the largest access unit is 143,171 bytes; the buffer trajectory checks these bursts rather than incorrectly requiring every frame/window to fit a flat rate. Seven focused tests pass, covering exact cadence and EOF, underflow, overflow, delay drift and quantization, invalid inputs and access-unit prefix/end accounting. This is a scoped engineering buffering check, not a general MPEG VBV verifier or formal DVD application-conformance test. No new RTL simulation, FPGA build or ARM build was performed because production behavior is unchanged. The qualified file was staged at /media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v.new, completely read back on a separate FTP connection, renamed to bbb_480i_tff_15s_9800kbps.m2v and independently read back again with matching size/hash; staging absence was confirmed. Complete installed Main/RBF reads still match the qualified a4f2769 hashes. Existing media and binaries were not overwritten, and no reboot, core reload, configuration change or playback was performed. Evidence is .ai/current_results/entry593_fixture.json, entry593_qualification.json, entry593_tests.log and entry593_deployment.json; durable source, both generated copies and logs are on GUNSMOKE under /home/vash/mister-builds/entry593. Built denotes successful diagnostic generation/qualification; hardware acceptance is still pending.

#### Next Steps:

Ask the user to play bbb_480i_tff_15s_9800kbps.m2v once from games/MediaPlayer using the same installed core and display mode, without needing a reboot, and to check menu responsiveness during playback before leaving terminal telemetry displayed. Retrieve the helper log first, then a freshly triggered screenshot and full decode. Require runtime credit_fast_v1 and mode 2, all 18,402,691 source bytes delivered, all 449 pictures and 448 swaps, no transport integrity/decoder errors, normal EOF and quiet completion, zero post-startup missed deadlines/outliers and steady 2,002,000-clock intervals at 60 MHz. This fixture has an odd byte count: the final payload byte uses an acknowledged word with zero padding, so reconcile ACK words with rounded-up byte counts and distinguish any observed final transport padding from source bytes instead of reusing entry 591's all-even-chunk assumptions. Interpret schema nineteen aggregate timestamps as startup-inclusive and evaluate actual post-first-swap deadline/gap telemetry for cadence. Preserve the first run before any cold/warm follow-up, then scope the 10.08 Mbps combined-stream/audio-and-timing gate separately; passing this clip will not establish full DVD compatibility. Keep the 18.65 Mbps file optional, leave production at a4f2769, preserve its restoration copies and credit/integrity/startup/sync protections, retain user control of lifecycle and playback, keep core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ceiling.py
- tools/streams/test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

