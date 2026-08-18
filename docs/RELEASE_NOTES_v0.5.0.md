# MiSTer Media Player v0.5.0 release notes

v0.5.0 expands the hardware-proven MiSTer Media Player development subset to 720x480 progressive 4:2:0 I/P/B regression streams and independently applies picture-signaled P/B motion-vector `f_code` values from 1 through 4. The milestone remains developer-oriented and intentionally narrower than general MPEG-2/H.262 conformance.

## Highlights

- Widened the bounded B parser and raster path from the earlier small diagnostic geometry to 45x30 macroblocks / 720x480.
- Generalized B coded-block-pattern and residual handling across all six 4:2:0 blocks, with ordinary run/level VLCs, Escape syntax, quantiser behavior, inverse transform, and prediction-plus-residual reconstruction inside the established storage caps.
- Generalized B macroblock-address increments, escaped gaps, internal skipped macroblocks, and restricted same-row slice coverage within the accepted progressive envelope.
- Consolidated the full-width P path around deterministic 720x480 streams and completed sequence-end handling, leading skipped macroblocks, macroblock-address Escape coverage, up to 32 residual descriptors, reference reads, persistence, publication, and presentation.
- Generalized P forward horizontal/vertical and B forward/backward horizontal/vertical `f_code` fields independently from 1 through 4. The parsers consume zero through three residual bits per applicable component and apply signed H.262 reconstruction, predictor reuse or independence, and wraparound.
- Added pixel-verified P and B `f_code` range streams covering unequal component fields, nonzero residuals, positive and negative vectors, predictor reuse, and range-boundary wraparound.
- Added a visible P-presentation discriminator whose accepted image has four quadrants divided by horizontal and vertical center seams.
- Reworked the board-LED diagnostics into a settled post-stream snapshot. Accepted streams report USER and POWER solid with DISK dark, avoiding mutable overlapping playback-time indications.
- Corrected the vendored ASCAL `MODE[4]` width mismatch and pipelined its vertical boundary comparison, preserving positive HDMI timing margin in the release-candidate build.

## Current supported development subset

- Raw MPEG-2 Video elementary-stream input (`.m2v`).
- Progressive frame pictures with 4:2:0 chroma on the hardware-proven paths.
- Deterministic I, P, and B regression coverage up to 720x480 / 45x30 macroblocks.
- Independently signaled P horizontal/vertical and B forward/backward horizontal/vertical `f_code` values from 1 through 4.
- Signed motion vectors, predictor reset/reuse, H.262 wraparound, integer and half-sample interpolation, and 4:2:0 chroma-vector scaling.
- P and B coded-block-pattern selection, bounded non-intra residual parsing and reconstruction, quantiser changes, and the established inverse-transform path.
- Two retained planar MiSTer DDR3 I/P reference banks plus a distinct B scratch region, with display-write protection and blanking-aligned publication.
- Mixed I/P/B coded-order and display-order handling on the accepted streams.
- Full 8-bit Y/Cb/Cr reconstruction and fixed 800x600 diagnostic video output.
- Synthetic 33-bit / 90 kHz elementary-stream presentation timing metadata.

These are implementation limits, not limits of ITU-T H.262 / ISO/IEC 13818-2.

## Known limitations

The following remain outside the v0.5.0 supported development subset:

- General arbitrary MPEG-2/H.262 playback outside the hardware-proven deterministic regression envelope.
- Interlaced frame or field pictures and broader H.262 picture structures.
- Chroma formats other than 4:2:0.
- Removal of the current parser, residual-descriptor, coefficient-event, geometry, and diagnostic resource caps.
- MPEG-2 Program Stream (`.mpg` / `.mpeg`) demux and H.222.0 PES-derived timestamps.
- Audio decode or playback.
- DVD/VOB navigation and direct optical-disc playback.
- A consumer-facing playback UI; the current LEDs and fixed output timing remain engineering diagnostics.

## Release qualification

The fresh GitHub-clone qualification checkout is:

`424eec43b0d0b4f8085e6591a15543eafab394e7`

The synthesized RTL was last changed by:

`b1bde49df3831669b577a1ed78404e026f19382d`

The qualification checkout was cloned from GitHub `master` with no prior Quartus databases or output files and compiled from scratch using Quartus Prime 17.0.2 Lite for Cyclone V `5CSEBA6U23I7`. Quartus Flow, Fitter, Assembler, and TimeQuest completed successfully with no Critical Warning and zero endpoint TNS.

The resulting RBF has SHA-256:

`a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`

That fresh-clone RBF is bit-for-bit identical to the Commit-194 RBF already accepted on MiSTer hardware. The later release-documentation commits do not change synthesized RTL.

## Authoritative hardware regression

The seven-stream matrix below replaces the former nine-stream matrix as the release gate going forward. All seven streams passed on MiSTer hardware with USER and POWER solid, DISK dark, and accepted images:

- `test_i_baseline.m2v` — continuous 720x480 all-I baseline; SHA-256 `ac7183a653be10aa44c2a1083f87abc77a971916a69678e9cf528de4dd2bff55`.
- `test_p_motion_residual.m2v` — P half-sample motion, coded-block-pattern residuals, and quantiser changes; SHA-256 `ad72f15d69b03c830208e786bcda21622b06cda83a74c91c3121808b14117f96`.
- `test_p_mba_escape.m2v` — ordinary and escaped P macroblock-address gaps plus leading skips; SHA-256 `ca2d050ce6a32ffa4a7360c142ff619b615c13b0a691bb85144008a934159948`.
- `test_b_bidirectional.m2v` — mixed I/P/B order, forward/backward/bidirectional prediction, residuals, and predictor independence; SHA-256 `4886ad9f0f6363c018edce6095e757151a435a4ee9f016e71a3c9a5851de3196`.
- `test_p_visual_discriminator.m2v` — visible P publication with four quadrants and both center seams; SHA-256 `e1ed0a7da39b52b9633124bc2d142e2b84f307d8e7d42781541bdf3d891c3a34`.
- `test_p_f_code_range.m2v` — independent P horizontal/vertical `f_code` 1..4, residual bits, signs, reuse, wraparound, and chained references; SHA-256 `b6a9ad050171446b2c55cd18e37d0727063858d49f4c4bdad6a817894fc6d437`.
- `test_b_f_code_range.m2v` — independent B forward/backward horizontal/vertical `f_code` 1..4 across two B reference pairs; SHA-256 `70da72fd53a1e3a6c2ac5b87bcf26dbfbf7398fb6ae526903d06e0402d54dacd`.

All seven generators were rerun from the fresh release clone and reproduced these hashes while passing their FFmpeg/shared-model pixel-exact or established IDCT-tolerance checks.

## Quartus / timing

- ALMs: 31,625 / 41,910 (75%)
- Registers: 42,223
- Block memory bits: 592,333 / 5,662,720 (10%)
- RAM blocks: 90 / 553 (16%)
- DSP blocks: 69 / 112 (62%)
- PLLs: 3 / 6 (50%)
- Global setup slack: +0.387 ns
- Global hold slack: +0.207 ns
- Global recovery slack: +3.756 ns
- Global removal slack: +0.601 ns
- Minimum pulse-width slack: +0.462 ns
- Decoder-clock setup slack: +2.012 ns
- Endpoint TNS: 0 for every reported setup and hold clock
- Critical Warnings: 0

TimeQuest continues to report the established incomplete external-I/O constraint warning class; the accepted qualification has positive reported setup, hold, recovery, removal, and minimum-pulse-width slack with zero endpoint TNS.

## Audio integration

The companion MiSTer Media Player Audio repository remains integration-compatible at commit:

`fd90c775a129995544ea7aa9d9369408d949ca63`

Audio is not included in this video-core release.

## MiSTer binary

The release binary follows the normal MiSTer date-coded naming convention:

`MediaPlayer_20260817.rbf`

Do not rename the binary to include the semantic version. The user-packaged RBF attached to the GitHub pre-release should match SHA-256 `a3eeeb285c427f313987ce6c62cdef560d6293defb1841e96c66aab026d63d8e`.
