# MiSTer Media Player v0.6.0 release notes

v0.6.0 advances MiSTer Media Player from deterministic 720x480 I/P/B regressions to sustained playback of real progressive 4:2:0 MPEG-2 Video elementary streams. The milestone adds native `24000/1001`, exact-24-fps, and 25-fps presentation cadence and fixes the compressed-input starvation, GOP-boundary stutters, and end-of-stream stalls exposed by full-length video.

This remains a developer-oriented pre-release and intentionally covers a narrower subset than general MPEG-2 Video / ITU-T H.262 conformance.

## Highlights

- Reworked the MiSTer compressed-data path around 16-bit host writes into a 32 KiB mixed-width asynchronous FIFO while retaining 8-bit decoder consumption and explicit backpressure.
- Raised the decoder clock from 54 MHz to 60 MHz and pipelined prediction, coefficient, reference-cache, and DDR work to sustain demanding real-stream pictures.
- Extended independently signaled P horizontal/vertical motion-vector `f_code` support to 1..9 with a 13-bit vector datapath.
- Extended independently signaled B forward/backward horizontal/vertical motion-vector `f_code` support to 1..5.
- Corrected long-GOP parsing, reference ownership, future-reference binding, repeated-GOP publication, queued-B presentation, persistence accounting, and final-reference release.
- Overlapped reference-picture decoding with B-picture presentation without surrendering retained-bank ownership, B scratch isolation, display ordering, or blanking-aligned publication.
- Added native presentation pacing for H.262 frame-rate code 2 / exact 24 fps and exact rational pacing for frame-rate code 1 / `24000/1001`, alongside the accepted frame-rate code 3 / 25-fps path.
- Added hardware cadence telemetry covering accepted bytes, decoded reference and B pictures, presentation swaps, elapsed playback rate, sequence-end state, decoder errors, and cadence outliers.
- Formally exposed the repository's `.ai` project-control workflow and recovery bootstrap for contributors who want to experiment with repository-driven AI-assisted FPGA development.

## Supported v0.6.0 development subset

- Raw MPEG-2 Video elementary-stream input (`.m2v`).
- Progressive frame pictures with 4:2:0 chroma.
- Hardware-proven geometry up to 720x480 / 45x30 macroblocks on the accepted paths.
- Continuous I/P/B decode and coded-order/display-order presentation on the qualified streams.
- H.262 frame-rate codes 1, 2, and 3: `24000/1001`, exact 24 fps, and 25 fps.
- P forward horizontal/vertical `f_code` values from 1 through 9.
- B forward/backward horizontal/vertical `f_code` values from 1 through 5; deterministic range regressions cover values 1 through 4.
- Signed motion vectors, predictor reset/reuse, H.262 wraparound, integer and half-sample interpolation, and 4:2:0 chroma-vector scaling.
- P/B coded-block-pattern selection, bounded non-intra residual parsing and reconstruction, quantiser changes, and the established inverse-transform path.
- Two retained planar MiSTer DDR3 I/P reference banks plus a separate B scratch region, display-write protection, and blanking-aligned publication.
- Full 8-bit Y/Cb/Cr reconstruction and fixed 800x600 diagnostic video output.
- Synthetic 33-bit / 90 kHz elementary-stream presentation timing.

These are implementation limits, not limits of ITU-T H.262 / ISO/IEC 13818-2.

## Known limitations

The following remain outside the v0.6.0 supported development subset:

- H.262 frame-rate codes 4 through 8: 29.97, 30, 50, 59.94, and 60 fps. These rates are not cadence-paced, so playback follows the decoder's unpaced rate rather than the encoded cadence.
- Interlaced frame or field pictures and broader H.262 picture structures.
- Chroma formats other than 4:2:0.
- General arbitrary MPEG-2/H.262 playback outside the qualified progressive envelope.
- MPEG-2 Program Stream (`.mpg` / `.mpeg`), Transport Stream, VOB, or other container demux.
- H.222.0 PES-derived timestamps and real PTS scheduling.
- Audio decode or playback.
- Seeking, scrubbing, pause/resume, DVD navigation, and direct optical-disc playback.
- A consumer-facing playback UI; the LEDs, loading display, diagnostic matrix, and fixed output timing remain engineering diagnostics.

Full-length files should be selected through the normal MiSTer file menu. Automatic MGL injection of the 642 MB qualification stream did not enter the normal streaming path and is not a supported loading method.

## Release qualification

The synthesized release-candidate source baseline is:

`b64ec6a`

A complete accepted incremental Quartus state was preserved before an independent clean/from-scratch build of the same seed-ten source. Both builds produced the exact same RBF. Later release-documentation commits do not alter the qualified RTL.

The clean build used Quartus Prime 17.0.2 Lite for Cyclone V `5CSEBA6U23I7`. Quartus Flow, Fitter, Assembler, and TimeQuest completed with zero errors and zero endpoint TNS.

The resulting 4,455,376-byte RBF has SHA-256:

`e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`

## Focused hardware regression

The four-file v0.6.0 gate passed on the target MiSTer with complete stream and picture progress, sequence-end completion, and zero decoder errors. The long cadence stress clip additionally reported zero cadence outliers:

- `01_p_skips_and_motion.m2v` — P skip/motion regression; 180,948 bytes, 2 pictures; SHA-256 `ca2d050ce6a32ffa4a7360c142ff619b615c13b0a691bb85144008a934159948`.
- `02_b_prediction_range.m2v` — B forward/backward/bidirectional prediction regression; 185,054 bytes, 5 pictures; SHA-256 `d0aad59a546114c7fe36680902c2bb912c7bcc2a43201ae9d0fd790d6f877725`.
- `03_multi_slice.m2v` — repeated multi-slice regression; 185,393 bytes, 5 pictures; SHA-256 `bcd25c393f42aa1ccb8dc076a87ad14560357db4613093c93472d49d13ec3be8`. The 16-bit transport correctly supplies one final pad byte for its odd stream length.
- `04_bbb_squirrel_15sec.m2v` — native-rate high-motion/large-picture stress clip; 2,603,570 bytes, 121 reference plus 239 B pictures; SHA-256 `9257ffadc24eb6696fc9760f3253764b396c993dfc3640e921c97611bad2edce`.

The 15-second stress clip reached sequence-end quiet at a measured 23.991197 fps with zero decoder errors and zero cadence-gap outliers. Its 8-bit display and swap diagnostics wrap as expected after 255 and do not indicate dropped pictures.

## Full-length playback validation

Two full-length real-video paths supplement the focused telemetry gate:

- The complete native-rate Big Buck Bunny movie was inspected through high-motion scenes, camera pans, scene transitions, and rolling credits. It completed with sharp transitions, smooth credits, and no recurring one-second stutter.
- A separate 642,033,469-byte 720x480 progressive Main Profile 4:2:0 stream with direct `24000/1001` timing was manually selected through the normal MiSTer file menu. The complete movie played at a visually correct rate with smooth motion and no observed dropped-frame defect.

The high-motion Big Buck Bunny scene around the wooden-spike sequence was the principal decoder-throughput stress point. The accepted 60 MHz decoder and mixed-width 32 KiB ingress remove the clean frame drops seen by earlier builds.

## Quartus / timing

- ALMs: 34,565 / 41,910 (82%)
- Registers: 50,960
- Block memory bits: 4,306,375 / 5,662,720 (76%)
- RAM blocks: 538 / 553 (97%)
- DSP blocks: 65 / 112 (58%)
- PLLs: 3 / 6 (50%)
- Global setup slack: +0.303 ns
- Decoder-clock setup slack: +0.386 ns
- Video-clock setup slack: +8.066 ns
- Global hold slack: +0.244 ns
- Global recovery slack: +3.706 ns
- Global removal slack: +0.768 ns
- Minimum pulse-width slack: +1.122 ns
- Endpoint TNS: 0 for every reported timing category
- Quartus errors: 0

TimeQuest continues to report the established incomplete external-I/O constraint warning class. The accepted qualification has positive reported setup, hold, recovery, removal, and minimum-pulse-width slack with zero endpoint TNS.

## MiSTer binary

The release binary follows the normal MiSTer date-coded naming convention:

`MediaPlayer_20260822.rbf`

Do not rename the binary to include the semantic version. The RBF attached to the GitHub pre-release must be exactly 4,455,376 bytes and match SHA-256 `e95e9ec43cb11917d5a904fdd8016bcc23dcbe2d8f36f678544f42ad1a6d5f10`.
