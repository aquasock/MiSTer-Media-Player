# Changelog

All notable project milestones are documented here.

This project is still in active pre-release development. Published milestone releases use semantic version numbers, while unreleased work remains organized by development phase.

## Unreleased

### Changed

- Fixed deferred DVD button activations that remain in menu space and continue
  an existing MPEG-2 sequence without repeating an independently decodable
  startup group. At the existing video-queue guard, the helper now rebases the
  staged timestamps above the prior live epoch and commits the exact queued
  stream through the resident decoder instead of aborting before its larger
  motion-menu decision threshold; qualified restarts and title exits retain
  their decoder barriers.
- Filled the Audio CD metadata panel from the existing TOC selection: title now
  mirrors the active `TRACK nn` playlist row, artist and album retain `---`, and
  all three colons align. Audio CDs also receive a built-in aspect-corrected
  disc image in the artwork viewport without adding an external asset.
- Changed Audio CD timing from the concatenated-disc clock to the active track:
  elapsed, remaining, track total and the progress bar now follow the selected
  TOC span, while the playlist clock reports the total duration of all audio
  tracks on the disc. Ordinary standalone-audio file timing is unchanged.
- Populated the Audio CD player playlist from the drive TOC with `TRACK 01`-style
  labels. The playing track is selected across natural boundaries, previous or
  next track changes and fixed seeks, while a six-row window keeps it near the
  vertical center when list boundaries permit; controls are unchanged.
- Changed standalone-audio pause ordering so the first Space or Start press
  reveals the player overlay, drains that in-band style update, and only then
  holds audio and visualizer transport at a helper/Main pause barrier. Resume
  releases the held helper with the existing `GO`; DVD and MPEG-2 pause remain
  the original immediate Main-side transport hold.
- Replaced whole-GOP audio-visualizer grade steps with version-two transition
  GOPs. Each adjacent rise or fall now crosses between grades over three
  frames while preserving the eight-level RMS response, native-interlaced
  closed-GOP stream safety and compatibility with existing version-one packs.
- Replaced marker-file optical launching with `Load Physical Disc` and
  `Load Disc Image` submenus. Patched Main now starts physical Video DVD and
  Audio CD media directly, the image submenu exposes only DVD ISO files, and
  separate MPEG-2 video and audio choices open their filtered browsers
  immediately.

### Added

- Added an always-on idle visualizer lifecycle without changing the FPGA. When
  the MediaPlayer core is loaded, isolated Main starts the existing visualizer
  pack through a monotonic-time helper source; DVD or MPEG-2 playback replaces
  it, audio retains the ten-second player overlay, and the idle loop returns
  after playback. A failed idle launch is not retried until a media cycle or
  core reload prevents a missing helper or pack from causing a restart loop.
- Added direct Audio CD playback from `/dev/sr0`. The helper inventories audio
  tracks, skips data tracks, reads CDDA
  sectors as 44.1 kHz stereo PCM, and reuses the standalone-audio interface,
  visualizer, fixed seeking, pause/replay lifecycle and previous/next controls.
- Added an experimental MediaPlayer-only NTSC 480i direct-HDMI mode to the
  isolated patched Main. With `direct_video=1` in the `[MediaPlayer]` INI
  section, the ADV7513 consumes the core's proven native 525-line raster at a
  divided 27 MHz input clock, advertises VIC 6 or 7 with BT.601 and limited RGB,
  reports two samples per content pixel, and uses matching 48/96 kHz audio CTS.
  This first boundary targets HDMI-to-SDI lock testing and does not add PAL,
  576i, HD-SDI, or a live Bob/Weave/Raw menu switch.

## [0.9.0] - 2026-09-03 — DVD navigation, native video and consumer-audio milestone

Encrypted ISO and direct USB-disc DVD-Video playback with authored menus,
expanded native 480i decoding, native 480p, file/audio seeking, standalone
consumer audio, the MPEG-2 visualizer and production telemetry.

- Release package: `MiSTer_Media_Player_v0.9.0.zip`, 6,580,818 compressed
  bytes, SHA-256
  `e8bc8e0c25291df85d6d53ad2688995d30ce156c547b7315b08058052863e1f9`.
  Its 16 files total 10,476,902 uncompressed bytes; all 15 manifest entries and
  ZIP integrity pass, and Main/helper retain executable mode.
- The project owner accepted the exact runtime set through functional and
  regression testing and directed that it be packaged without rebuilding.
  The source-`dfe1057` RBF was already a clean, reproducible, timing-qualified
  Quartus build; package assembly preserves every accepted artifact byte for
  byte.

### Added

- Added authored DVD first-play and root-menu navigation for ISO images and
  direct `/dev/sr0` playback. The helper follows libdvdnav menu state, decodes
  DVD subpicture RLE and authored CLUT/alpha/highlight data, and sends bounded
  double-buffered overlay records to a native-480i FPGA compositor. Main maps
  player-one D-pad/A/Start/Select and keyboard arrows/Enter/M to directional,
  activate and root-menu controls through the existing ready/go barrier.
- Added longest-title playback from decrypted or CSS-encrypted DVD ISO files.
  The static helper pins libdvdcss 1.6.0 beneath libdvdread/libdvdnav, with no
  target-installed shared-library dependency and no Main or FPGA change.  ISO
  PTS epochs are normalized across VOB or cell clock restarts so long-title
  audio scheduling remains continuous, and longest-title playback ends after
  one declared traversal instead of following post-title navigation commands.
- Added direct longest-title playback from the absolute USB optical-device path
  `/dev/sr0`, using the same pinned CSS, navigation, timestamp and audio paths
  without requiring an ISO image or filesystem mount.
- Added player-one Left/Right previous and next chapter controls for DVD ISO and
  direct optical playback through a private Main/helper ready-go channel.  The
  helper retains the authenticated navigation handle while both sides flush the
  old byte stream before Main resets the existing FPGA download boundary.
- Added player-one Start pause/resume as an ARM-side transport hold.  It keeps
  the helper and optical navigation session alive without an RBF change; a long
  pause may still set the FPGA's existing audio-underrun telemetry.
- Added keyboard Space play/pause and P/N previous/next chapter bindings, and
  corrected physical player-one Start so it reaches the same Main-side pause
  action without changing the helper or FPGA image.
- Added 720x480 interlaced frame-picture I/P/B decoding with frame or field
  motion, frame or field DCT, repeat-first-field scheduling and mixed ordinary
  interlaced/progressive-film frames. Deterministic fixtures cover the syntax
  and reconstruction paths, and the current timing-qualified RBF has been
  exercised with commercial DVD material.
- Added helper-only RIFF WAVE playback through the existing MediaPlayer picker and PCM transport. Pinned miniaudio source is compiled into the static helper to convert ordinary PCM/float mono, stereo or multichannel WAV input to 44.1 or 48 kHz signed stereo without an FPGA change.
- Added helper-only FLAC playback through the existing MediaPlayer picker and PCM transport. The same statically compiled miniaudio dependency converts 16- or 24-bit mono, stereo or multichannel FLAC input to 44.1 or 48 kHz signed stereo without an FPGA change.
- Added helper-only Ogg Vorbis playback through a dedicated audio picker. The
  miniaudio backend uses pinned stb_vorbis source and converts decoded audio to
  44.1 or 48 kHz signed stereo without a target runtime library or FPGA change.
- Added `.vob` selection and transactional fixed-step seeking for `.mpg` and
  `.mpeg` Program Streams, with 10-second, 1-minute and 5-minute keyboard jumps.
- Added an ARM-rendered standalone-audio interface with elapsed, total and
  remaining time, duration-relative progress, matching fixed-step seeking and
  replay-ready end-of-file behavior.
- Added an optional helper-driven MPEG-2 audio visualizer. Eight validated
  color/brightness grades follow decoded-PCM loudness while the player overlay
  remains visible for ten seconds after playback starts or user input.
- Added default-off production telemetry. Enabling it before playback exposes
  the hardware snapshot and writes the combined Main/helper log to
  `/tmp/MediaPlayer_ARM.log`.

### Changed

- Reorganized the core menu into separate DVD-Video, MPEG-2 video and consumer
  audio pickers; made 16:9 the default aspect ratio while retaining 4:3; and
  kept the existing Bob/Weave, Audio Test and Audio Output choices.
- Chapter changes now retain the established Program Stream codec and DVD
  private audio substream. AC-3 decode performs a bounded 64 KiB rescan and
  decoder reinitialization after a rejected boundary frame instead of exiting
  playback or selecting a different track because its PES arrived first.
- Native 480i ownership now remains active when an interlaced sequence moves
  between ordinary interlaced and progressive film frame pictures. Per-picture
  field order and repeat metadata drive film scheduling after that transition;
  field pictures and existing syntax, timing and decoder-error gates remain
  rejected.
- Direct USB-DVD playback now reuses its authenticated libdvdnav session across
  helper preflight rewinds instead of reopening and rescanning CSS keys. After
  preflight it reads through an 8 MiB asynchronous HPS-RAM ring with a 4 MiB
  launch reserve, insulating playback from transient optical-read stalls
  without consuming FPGA memory or changing file and ISO paths.
- Replaced the old progressive diagnostic raster with native 720x480p output at
  `60000/1001`, while supported interlaced material retains native 480i output.
- Made clean `.mpg`, `.mpeg` and standalone-audio EOF retain the final display
  in a paused replay-ready state; Play restarts the same file from its beginning.
- Hardened direct optical playback with session reuse, interruptible output
  discard and staged transitions for slow or picture-bearing authored menus.
- Preserved DVD menu state across overlay-only submenus, finite and indefinite
  stills, unsupported private audio, scene-page changes and title/menu returns.
- Skip unsupported DVD LPCM/private audio without terminating navigation, so a
  silent LPCM menu can still lead to a title with supported audio.
- Added a narrowly gated helper compatibility normalization for malformed DVD
  4:2:0 progressive-frame chroma flags, including repeated authored stills;
  conforming streams remain byte-identical.
- Reconciled current release, build, architecture and test guidance with the published v0.8.0 package; labelled older design and regression instructions as historical.
- Corrected v0.8.0 tag provenance, compressed ZIP size, the role of patched Main, and the distinction between a targeted hardware pixel comparison and comprehensive playback qualification. Runtime code, the release tag and packaged binaries are unchanged.

## [0.8.0] - 2026-08-27 — Interlaced 480i, AC-3 and passthrough milestone

Bounded 720x480 interlaced all-I playback with native 480i presentation, AC-3 decode, and AC-3/DTS passthrough to S/PDIF.

- Published as a pre-release on 2026-08-27 at 17:41:16 America/Phoenix. Annotated tag `v0.8.0` resolves to `af43de2`; all three runtime binaries use source baseline `2f1d32c`. The standalone release notes were added in later documentation commit `035807a`, without changing the tagged runtime source.
- Public package: `MiSTer_Media_Player_v0.8.0.zip`, 2,867,028 compressed bytes, SHA-256 `5f55b49eb863f74a777b548b4f42b744a9130b4161f176b687ca297deeffcaf3`. Its uncompressed members total 5,948,567 bytes. The downloaded ZIP and payload hashes match the qualified package.
- A clean from-scratch Quartus Prime 17.0.2 build reproduced the tested RBF byte-for-byte: 4,332,740 bytes, SHA-256 `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce`, fitter seed 17.
- The clean fit uses 31,464 ALMs (75%), 50,273 registers, 4,048,355 block-memory bits (71%), 512 RAM blocks (93%), 67 DSP blocks, and 3 PLLs.
- Timing is positive in every required category with zero total negative slack: +0.243 ns setup, +0.251 ns hold, +2.865 ns recovery, +0.564 ns removal, +0.925 ns minimum pulse width.
- The fitter seed moved from 16 to 17. At seed 16 the framework scaler's horizontal accumulator missed setup by 0.070 ns once the audio routing added logic; that path retains little margin and is a known risk for future changes.
- All three binaries were rebuilt from source baseline `2f1d32c` and reproduced byte for byte: the RBF from a clean export of tracked files only, and the helper and Main from a wiped dependency directory with a freshly extracted toolchain.
- ARM helper SHA-256 `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8`.
- Patched Main SHA-256 `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9`, built from pinned upstream `0a8fb44` with ARM GNU 10.2.
- Added liba52 0.7.4 as a pinned dependency for AC-3 decode, fetched by `host/build_arm_stack.sh` with its archive SHA-256 verified, and shipped its licence alongside minimp3's.
- Host regressions pass on the release binaries: cadence decoder layout, eleven DVD ceiling tests, and the Main integration profile including 168 RTL cases, 96 burst cases, 20 step-resume cases and guarded fault cases.
- Audio regressions pass on the release helper: AC-3 decode against an independent decoder at maximum sample difference 3 and correlation 0.999999972, correct downmix placement for all six channels including LFE absence, byte-identical passthrough bursts, and the unchanged MPEG Layer II PCM hash on the full-length fixture.

- Added a bounded 720x480 4:2:0 interlaced all-I frame-picture path with frame DCT, consistent TFF/BFF preservation, and native 480i timing.
- Added two explicit interlaced presentation tiers: MiSTer scaler processing with selectable Weave/Bob, and untouched native 480i for `direct_video`, external processing, and eventual HDMI-to-SDI conversion.
- Removed a redundant 64-clock inverse-quantization block replay by streaming finalized coefficients directly into the idle IDCT, restoring full-D1 all-I throughput headroom for 29.97-fps material without changing decoded pixels.
- Added AC-3 decode in the ARM helper through a pinned liba52 dependency, on DVD private stream 1 substreams `0x80`-`0x87`, downmixed to stereo using the stream's own coefficients. Verified against an independent decoder on both synthetic fixtures and a commercial DVD track, the latter confirming that dynamic range control is applied.
- Added AC-3 and DTS passthrough to S/PDIF as IEC 61937 bursts, so an external decoder receives the original bitstream. Verified byte-identical on synthetic fixtures and a commercial DVD track. DTS is passthrough only; a DTS track selected for HDMI output is refused rather than played as silence.
- Added an `Audio output` menu option selecting HDMI or S/PDIF, muting the output it does not drive, and forked the framework audio path so a passthrough burst reaches the S/PDIF pin unaltered and is announced as non-PCM.
- Fixed S/PDIF selection for decoded MP2, MP3, WAV and FLAC: decoded samples now use ordinary PCM channel status, while only AC-3/DTS IEC 61937 bursts are announced as non-audio.
- Added a set of seven hand-test Program Streams covering interlaced TFF and BFF field order, Bob versus Weave deinterlacing, progressive all-I and progressive I/P/B, and AC-3 and DTS 5.1 channel sweeps.
- Confirmed on hardware that the progressive path decodes I, P and B pictures, correcting an earlier description of the decoder as accepting I-pictures only; that restriction applies to the interlaced 480i path.
- Reduced Main's media-transfer event-loop occupancy, which had reached about 160 ms per poll on low-bitrate material and made the menu sluggish; measured maximum poll time fell by roughly seventeen times and the acknowledged-write fallback disappeared.
- Known limitation recorded: sharp colour transitions show one blended pixel column that an independent software decoder does not produce, and playback pixel accuracy remains unqualified.
- A targeted hardware-screenshot pixel comparison measured that chroma-edge difference; earlier wording that all pixel comparisons were simulated was incorrect. Comprehensive playback pixel qualification remains open.
- The hand tests used the released RBF/helper hashes; the final Main was separately exercised after the initial six-test capture. A confirmation run after installation from the final package remains unrecorded. Publication and package verification do not close that gate.

## [0.7.0] - 2026-08-24 — Program Stream audio and PTS milestone

Hardware-qualified bounded MPEG-2 Program Stream playback with MPEG Layer II audio, real picture-PTS scheduling, and a matching MiSTer ARM helper.

- Added a pinned, reproducible ARM helper that accepts raw MPEG-2 Video or bounded MPEG-2 Program Streams, preserves video bytes exactly, extracts picture PTS, decodes MPEG Layer II audio, and sends packed video/PTS/PCM records to the FPGA.
- Added a matching pinned MiSTer Main patch that invokes `/media/fat/linux/MediaPlayer_Helper` for Media Player files while preserving the existing raw-file path.
- Added 44.1 and 48 kHz signed stereo PCM playback through an 8,192-frame FPGA FIFO, with bounded startup and steady-state batching, explicit end markers, underrun/error telemetry, and clean no-reboot recovery between silent and audio-video files.
- Added a clean-video queue so decoder backpressure cannot block PCM delivery and cause periodic audio/video disturbance.
- Made Program Stream picture PTS drive the FPGA 33-bit / 90 kHz presentation timeline. Encoded H.262 cadence remains a mandatory floor, so PTS can delay a frame but cannot present it early.
- Extended native presentation pacing through H.262 frame-rate codes 4 and 5: exact `30000/1001` and exact 30 fps, alongside the existing `24000/1001`, exact 24, and 25 fps paths. Codes 6 through 8 are rejected before transport.
- Added deterministic Program Stream finalization, compatibility checks, input-envelope generation, helper transport analysis, PCM comparison, protocol verification, and native/sanitized host regressions.
- Qualified the full 14,315-picture Big Buck Bunny audio-video soak, including opening motion, high-motion scenes, transitions, and rolling credits. The final cadence-floor build completed without the recurring one-second credits jump.
- Passed the final four-file release gate on the exact packaged binaries: power-cycle 48 kHz audio-video startup, no-reboot video-only playback, no-reboot 44.1 kHz audio recovery, and a fresh-boot full-movie soak. Every run completed with normal LEDs and zero aggregate, decoder, presentation, PCM protocol, or underrun errors; the soak recorded zero credits-window cadence outliers.
- Preserved raw `.m2v` as a byte-exact path with synthetic H.262-derived presentation timing and clean terminal behavior.
- Release FPGA source baseline: `9a5eea3`; host/helper source baseline: `acdbf8b`.
- A clean Quartus Prime 17.0.2 build reproduced the accepted 4,184,380-byte RBF exactly, with SHA-256 `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`.
- The clean fit uses 29,325 ALMs, 45,259 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks, and 3 PLLs.
- Timing is positive in every required category: +0.311 ns global setup, +0.238 ns hold, +3.365 ns recovery, +0.497 ns removal, +1.122 ns minimum pulse width, +1.782 ns decoder setup, +11.294 ns decoder recovery, and +8.284 ns video setup.
- Reproducible release helper: 361,452 bytes, SHA-256 `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`.
- Reproducible matching Main: 1,166,244 bytes, SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`.
- The release package contains the date-coded RBF, matching Main, executable `linux/MediaPlayer_Helper`, checksums, source provenance, installation instructions, and applicable licenses. Generated regression media is not shipped.
- Current limits remain deliberate: progressive 4:2:0 video through the qualified 720x480 envelope, MPEG Layer II audio at 44.1/48 kHz, bounded Program Stream structure, fixed 800x600 output, and no seeking, pause/resume, Transport Stream, DVD navigation, subpictures, or optical-disc integration.

## [0.6.0] - 2026-08-22 — Real-stream MPEG-2 playback milestone

Hardware-qualified sustained playback of progressive 720x480 4:2:0 MPEG-2 Video elementary streams, with native `24000/1001`, exact-24-fps, and 25-fps presentation cadence.

- Reworked compressed-data ingress around a 16-bit MiSTer host path and a 32 KiB mixed-width asynchronous FIFO while retaining 8-bit decoder consumption and explicit backpressure.
- Raised the decoder clock from 54 MHz to 60 MHz and pipelined the real-stream prediction, coefficient, cache, and DDR paths needed to maintain positive timing at the higher rate.
- Extended picture-signaled P forward horizontal/vertical motion-vector `f_code` support from 1..4 to 1..9 with a 13-bit vector datapath, and extended independently signaled B forward/backward horizontal/vertical support from 1..4 to 1..5.
- Corrected long-GOP parsing, reference ownership, pending-future-reference binding, repeated-GOP publication, queued-B presentation, P/B persistence accounting, and final-reference release so streams continue across former stutter points and terminate cleanly.
- Overlapped reference-picture decoding with B-picture presentation while preserving retained-bank ownership, B scratch storage, display order, blanking-aligned publication, and protected DDR access.
- Added native H.262 frame-rate-code 2 pacing for exact 24 fps and exact rational frame-rate-code 1 pacing for `24000/1001`, alongside the existing accepted frame-rate-code 3 / 25-fps path.
- Added hardware cadence telemetry for accepted byte counts, decoded/reference/B picture counts, presentation swaps, measured frame rate, sequence-end state, decoder errors, and cadence-gap outliers.
- Qualified a focused four-stream hardware gate covering P skip/motion, B prediction, repeated multi-slice pictures, and the high-motion large-picture/long-GOP scene that originally exposed compressed-input starvation.
- Completed visual endurance qualification with the full native-rate Big Buck Bunny movie and a separate 642 MB real-world 720x480 progressive `24000/1001` stream. Both completed with smooth motion, no perceptible speed error, and no observed recurring stutter or frame-drop defect.
- Release-candidate source baseline: `b64ec6a`. A preserved incremental Quartus build and an independent clean/from-scratch Quartus Prime 17.0.2 build produced byte-identical RBFs.
- The clean build completed with zero errors and positive timing in every required category: +0.303 ns global setup, +0.386 ns decoder setup, +8.066 ns video setup, +0.244 ns hold, +3.706 ns recovery, +0.768 ns removal, and +1.122 ns minimum pulse width.
- The qualified fit uses 34,565 ALMs, 50,960 registers, 4,306,375 block-memory bits, 538 RAM blocks, and 65 DSP blocks.
- The qualified 4,455,376-byte RBF has SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`; its release asset name is `MediaPlayer_20260822.rbf`.
- Current limits remain deliberate: raw `.m2v` elementary-stream input, progressive frame pictures, 4:2:0 chroma, the proven 720x480 envelope, synthetic rather than PES-derived timing, fixed 800x600 diagnostic output, and no audio, container/program-stream demux, real PTS, seeking, pause/resume, DVD navigation, or optical-drive integration.
- H.262 frame-rate codes 4 through 8—29.97, 30, 50, 59.94, and 60 fps—remain unpaced and are not supported by this milestone.

## [0.5.0] - 2026-08-17 — 720x480 progressive P/B `f_code` milestone

Hardware-qualified 720x480 progressive 4:2:0 I/P/B regression coverage with independently picture-signaled P/B motion-vector `f_code` handling from 1 through 4.

- Widened the bounded B syntax and raster path to 45x30 macroblocks / 720x480 while retaining separate B scratch storage and coded-order/display-order presentation.
- Generalized B residual parsing across all six 4:2:0 blocks and generalized B macroblock-address increments, escaped gaps, internal skips, and restricted same-row slice coverage within the accepted progressive envelope.
- Replaced the earlier mixed legacy/controlled P acceptance path with deterministic full-width 720x480 generators and completed generalized P parsing, raster execution, reference reads, prediction-plus-residual reconstruction, persistence, publication, and presentation through sequence end.
- Added leading P skips, macroblock-address Escape coverage, up to 32 residual descriptors, full coded-block-pattern coverage, quantiser changes, and visible P-presentation discrimination.
- Generalized P forward horizontal/vertical and B forward/backward horizontal/vertical `f_code` fields independently across values 1 through 4, including zero through three residual bits, both signs, predictor reuse/independence, H.262 wraparound, and chained references.
- Corrected the vendored ASCAL `MODE[4]` width mismatch and pipelined its vertical boundary predicate, preserving positive HDMI timing margin through the final release-candidate build.
- Replaced overlapping playback-time LED indications with a settled post-stream report and aligned acceptance with durable generalized publication/reference completion. Successful streams settle with USER and POWER solid and DISK dark.
- Established the authoritative seven-stream hardware matrix: `test_i_baseline.m2v`, `test_p_motion_residual.m2v`, `test_p_mba_escape.m2v`, `test_b_bidirectional.m2v`, `test_p_visual_discriminator.m2v`, `test_p_f_code_range.m2v`, and `test_b_f_code_range.m2v`. The former nine-stream matrix is not a release gate going forward.
- Hardware qualification accepted all seven streams with the expected LED result and clean images; the P visual discriminator retained all four quadrants and both center seams.
- Release qualification checkout: `424eec43b0d0b4f8085e6591a15543eafab394e7`; synthesized RTL baseline: `b1bde49df3831669b577a1ed78404e026f19382d`.
- The clean GitHub-clone Quartus Prime 17.0.2 build completed with no Critical Warning, zero TNS, +0.387 ns global setup, +0.207 ns global hold, +2.012 ns decoder setup, 31,625 ALMs, 42,223 registers, 592,333 block-memory bits, 90 RAM blocks, 69 DSP blocks, and 3 PLLs.
- The fresh-clone RBF is bit-identical to the already hardware-accepted Commit-194 artifact and has SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`.
- Audio project `fd90c775a129995544ea7aa9d9369408d949ca63` remains integration-compatible.
- Current limits remain deliberate: raw MPEG-2 Video elementary streams, progressive frame pictures, 4:2:0 chroma, the proven 720x480 regression envelope, synthetic rather than PES-derived timing, fixed diagnostic video output, no audio, and no DVD/program-stream navigation.

## [0.4.0] - 2026-08-16 — Progressive 4:2:0 I/P/B milestone

Hardware-qualified progressive 4:2:0 I/P/B decoding and presentation within the current bounded implementation envelope.

- Preserved the hardware-proven continuous progressive 4:2:0 all-I decode, DDR-backed presentation, blanking-aligned publication, and synthetic 90 kHz elementary-stream timing baseline from v0.3.0.
- Generalized P-picture reconstruction around syntax-derived per-macroblock motion and residual execution, including signed horizontal/vertical forward vectors, predictor reuse/reset, H.262 wrap behavior, integer and half-sample interpolation, 4:2:0 chroma-vector scaling, coded-block-pattern handling, sparse residual placement, run/level and Escape coefficient syntax, q_scale_type, alternate_scan, and quantiser-scale changes within the proven regression envelope.
- Preserved consecutive reconstructed-P reference promotion and corrected the publication-versus-presentation destination-ownership race by pacing a following P until its destination retained bank is no longer display-owned.
- Added the first hardware-proven B-picture core path with forward, backward, and bidirectional prediction, internal macroblock-address skips, bounded residual reconstruction, and 128x96 mixed I/P/B deterministic regressions.
- Added a dedicated B scratch DDR region and corrected frame-region identity to use the full two-bit region selector so retained bank 0, retained bank 1, and B scratch remain distinct under display-write protection.
- Added blanking-aligned B presentation/reorder handling that preserves the future P reference while the intervening B picture reconstructs and presents from scratch, then presents the retained future reference in display order.
- Split the large top-level integration into `MediaPlayer_top_00.svh` through `MediaPlayer_top_07.svh` without changing the MiSTer-facing top entity.
- Consolidated the active IDCT arithmetic around a shared multiplier bank, reducing DSP use from the earlier 92-DSP development point to 68 DSP blocks while preserving the accepted regression behavior.
- Added comments-only Audio-fork integration anchors without establishing a permanent ABI or altering synthesized behavior.
- Localized and corrected an intermittent consecutive-P failure to a display/reference destination-ownership race; the temporary first-fault, timeout-phase, writer, cache, and arbiter diagnostic layer was completely retired after the functional fix was accepted.
- Restored normal USER completion behavior after the diagnostic investigation.
- Hardware-qualified RTL baseline: `1370c28e3d34b1fd603c17130986bc336da29a32`.
- Release qualification used a fresh clone of GitHub `master`, Quartus Prime 17.0.2 Lite, the standard Phase 1P timing reports, and the full required MiSTer matrix: 20 consecutive passes of `test_p_consecutive_reference.m2v`, plus passes of `test_b_mixed_gop.m2v`, `test_b_core_decode.m2v`, `test_p_general_decode.m2v`, and `test_all_i.m2v`.
- Qualified fit: 31,782 / 41,910 ALMs (76%), 43,812 registers, 461,345 block-memory bits in 73 RAM blocks, 68 / 112 DSP blocks, and 3 / 6 PLLs.
- Qualified timing: global setup +0.167 ns, hold +0.248 ns, recovery +4.117 ns, removal +0.704 ns, decoder setup +1.311 ns with 0/100 violations, video setup +6.987 ns with 0/80 violations, and setup endpoint TNS 0.
- Current implementation limits remain deliberate engineering bounds: established I-picture coverage reaches 720x480, while the generalized P/B hardware regressions use 128x96 / 8x6 macroblocks. General arbitrary H.262 P/B playback, interlaced/broader picture structures, non-4:2:0 chroma, H.222.0 Program Stream/PES demux and real PTS, audio, and DVD/VOB navigation remain future work.

## [0.3.0] - 2026-08-14 — Phase 1T

Reference-picture management and the first hardware-proven predictive-picture reconstruction paths.

- Preserved the hardware-proven continuous progressive 4:2:0 all-I decode, DDR ping-pong storage, blanking-aligned publication, and synthetic 90 kHz elementary-stream timing baseline from v0.2.0.
- Added reference-picture bookkeeping and controlled reference/destination DDR-bank ownership for predictive-picture work.
- Added P-picture diagnostic syntax, motion-vector, stream-hold, and reference-read paths developed against ITU-T H.262 semantics.
- Added controlled forward-prediction reconstruction paths, including zero-vector reference copying, explicit reference sampling, and the established half-sample interpolation behavior used by the hardware diagnostics.
- Added non-intra P residual parsing, inverse quantization / transform handling, prediction-plus-residual reconstruction, and ordinary DDR persistence for the controlled supported path.
- Extended the controlled P reconstruction proof from one complete 4:2:0 macroblock to two adjacent macroblocks and then to four macroblocks over two raster rows.
- Replaced fixed macroblock-index placement in the four-macroblock path with explicit raster row/column tracking and then fed that path from live coded horizontal geometry using the H.262 `(horizontal_size + 15) / 16` macroblock-width rule.
- Preserved the existing all-I hardware regressions while adding dedicated P-picture regression streams for reference reads, residual reconstruction, two-macroblock placement, and four-macroblock/two-row placement.
- Preserved the Phase 1P timing/CDC discipline throughout the predictive-picture increments.
- Current limitation: P-picture support remains a deliberately controlled hardware-proven diagnostic subset, not general arbitrary MPEG-2 P-picture playback. B pictures are not supported.
- Current input remains raw MPEG-2 Video elementary stream data; H.222.0/MPEG program-stream demux, PES timestamps, audio, and DVD/VOB playback remain future work.

## [0.2.0] - 2026-08-12 — Phase 1S

Continuous all-I playback and presentation-timing foundation.

- Extended the single re-armed H.262 parser from two pictures to continuous supported all-I picture decode.
- Reused the two planar DDR frame banks as a repeated bank 0 / bank 1 ping-pong store.
- Protected the displayed DDR bank from reconstruction writes while it remained owned by the display reader.
- Moved repeated frame publication and framebuffer re-arm into true vertical blanking so active video remains continuous.
- Removed the old asynchronous multi-bit line-number CDC bus; the line-cache handoff now crosses only a synchronized one-bit event and derives source-line identity locally in the DDR clock domain.
- Eliminated all observed playback artifacts from the continuous-all-I diagnostic stream, including mixed-frame distortion, black flicker, the bottom-edge white bar, and faint horizontal line artifacts.
- Added the first presentation-timing metadata foundation using H.262 frame-rate information and `temporal_reference` with a 33-bit 90 kHz representation compatible with later H.222.0 PTS handling.
- Kept the current elementary-stream timing explicitly synthetic: `.m2v` input has no PES layer, so the generated schedule is not represented as a normative PES PTS.
- Hardware acceptance: `test_all_i.m2v` plays to completion with USER completion correct and no observed flicker, tearing, corruption, bars, or other image artifacts.
- Final proven Phase 1S RTL commit before release documentation: `37d6268080d6d14f2e2e2d91345bc4a0132747ee`.
- Final proven Phase 1S Quartus fit at that commit: 11,349 / 41,910 ALMs (27%), 18,231 registers, 63 / 553 RAM blocks (11%), and 55 / 112 DSP blocks (49%).
- Final focused timing at that commit: decoder setup +4.838 ns, video setup +7.945 ns, decoder recovery +15.683 ns, video recovery +21.572 ns, all with TNS 0; hold and removal checks are positive.

## [0.1.0] - 2026-08-12 — Phase 1R

First hardware-proven milestone release.

- Added an alternate DDR frame bank for the second decoded picture.
- Added explicit DDR arbitration so display reads and reconstructed-frame writes can safely share the MiSTer DDRAM interface.
- Preserved picture 1 on screen while picture 2 is decoded and stored in the alternate bank.
- Made the parser wait for DDR persistence on both pictures so second-picture completion means the full frame has been stored.
- Added controlled framebuffer re-arm and frame-bank publication after picture 2 completes.
- Proved a visible picture 1 -> picture 2 transition on MiSTer hardware.
- Hardware acceptance: USER completion correct, stable color output, no tearing observed, and no flicker observed.
- Final Quartus fit: 11,342 / 41,910 ALMs (27%), 18,142 registers, 63 / 553 RAM blocks (11%), and 55 / 112 DSP blocks (49%).
- Final focused timing: decoder setup +5.265 ns, video setup +7.619 ns, decoder recovery +16.147 ns, video recovery +21.712 ns, with TNS 0; hold and removal checks are positive.
- Published GitHub pre-release tag: `v0.1.0`.
- MiSTer binary asset: `MediaPlayer_20260812.rbf`.

## Phase 1Q — Successive I-picture decode

- Proved two consecutive supported I-picture decodes in hardware.
- Reused a single proven H.262 parser by locally re-arming it between pictures.
- Kept picture 1 stored/displayed while picture 2 traverses parser, inverse quantization, IDCT, and reconstruction.
- Removed an earlier duplicated-parser diagnostic that introduced slight color-image flicker.
- Hardware acceptance: both diagnostic streams pass, image is stable, USER completion behavior is correct.

## Phase 1P — Timing and CDC closure

- Closed the real 54 MHz decoder and 40 MHz video timing paths.
- Pipelined and balanced inverse-quantization and IDCT arithmetic where required.
- Synchronized reset release independently in each destination clock domain.
- Enabled synchronized DCFIFO asynchronous-clear handling.
- Narrowed timing exceptions to intentional synchronizer boundaries rather than broad clock-domain false paths.
- Final accepted setup and recovery reports had zero total negative slack on the decoder and video clocks.

## Phase 1O — Full-precision DDR frame storage and readback

### Phase 1Oa

- Added full-precision planar Y/Cb/Cr DDR3 writes.
- Serialized block persistence so the parser could not advance until reconstructed block data reached DDR.
- Kept the existing on-chip framebuffer active temporarily to isolate DDR-write verification.

### Phase 1Ob

- Removed the large full-picture on-chip framebuffer.
- Added DDR3 readback through small dual-clock ping-pong line caches.
- Restored full 8-bit chroma presentation.
- Moved decoder frame storage away from the MiSTer system-video DDR region after identifying an address collision.
- Reduced M10K use dramatically compared with full-frame on-chip storage.

## Phase 1N — Full color reconstruction

- Added Cb and Cr to the serialized inverse-quantization, IDCT, and reconstruction pipeline.
- Implemented 4:2:0 component storage and BT.601 YCbCr-to-RGB conversion.
- Proved the first complete color picture in hardware.
- Used a temporary reduced-chroma on-chip storage format before the later DDR architecture removed the M10K pressure.

## Phase 1M — Complete first picture

- Continued parsing across all slices of the first supported I picture.
- Correctly reset slice-local DC predictors and macroblock address state.
- Produced the first complete 720x480 grayscale MPEG-2 picture.

## Phase 1L — Complete slice decode

- Removed the temporary fixed macroblock-count stop.
- Decoded an entire slice.
- Used H.262 slice termination rather than assuming a fixed row length.

## Phase 1K — Streaming bitreader

- Replaced the bounded whole-slice capture buffer with a streaming bitreader.
- Added exact byte/bit consumption and FIFO backpressure while downstream arithmetic was busy.
- Removed an implementation capture limit that had previously appeared as a decode failure.

## Phase 1J — Multi-macroblock diagnostics

- Expanded decode beyond the first macroblock.
- Parsed Cb/Cr block syntax sufficiently to advance through consecutive 4:2:0 intra macroblocks.
- Added detailed diagnostics that localized a failure to exhaustion of the temporary slice capture buffer.

## Phase 1I — First full luma macroblock

- Decoded all four Y blocks of the first 4:2:0 intra macroblock.
- Produced a stable 16x16 decoded luma region in hardware.

## Phase 1H — Legacy decoder removed from active build

- Removed MPEG2FPGA and its DDR bridge from the active Quartus design.
- Retained the source tree only as a frozen reference implementation.
- Reduced FPGA resource usage substantially and improved hardware stability.

## Phase 1G — Independent display timing

- Decoupled display timing from the legacy decoder.
- Added a fixed 800x600 / 40 MHz diagnostic timing generator.
- Eliminated raster shifts caused by the earlier timing path.

## Earlier clean-decoder milestones

- Began a standards-driven H.262 decoder.
- Parsed slice and first intra-macroblock syntax.
- Decoded intra DC and AC VLC data, including run/level and end-of-block handling.
- Implemented inverse quantization.
- Implemented a fixed-point two-pass 8x8 IDCT.
- Displayed the first decoded 8x8 luma block.
