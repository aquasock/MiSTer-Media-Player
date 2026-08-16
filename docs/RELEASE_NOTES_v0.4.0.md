# MiSTer Media Player v0.4.0 release notes

v0.4.0 is the first hardware-qualified MiSTer Media Player milestone that combines the established progressive 4:2:0 I-picture path, the generalized P-picture reconstruction path, and a bounded hardware-proven B-picture decode/presentation path. The milestone remains developer-oriented and intentionally narrower than general MPEG-2/H.262 conformance.

## Highlights

- Preserved the continuous progressive 4:2:0 all-I playback path and generalized syntax-derived P-picture reconstruction introduced during the v0.4.0 development cycle.
- Added a hardware-proven B-picture reconstruction path with forward, backward, and bidirectional prediction on deterministic mixed I/P/B regression streams.
- Added B-picture residual reconstruction, macroblock-address skip handling, reference selection, and coded-order/display-order handling for the proven progressive 4:2:0 subset.
- Added a dedicated B scratch DDR region so B reconstruction does not overwrite retained I/P references.
- Corrected DDR region identity to use the full two-bit region selector, keeping retained bank 0, retained bank 1, and B scratch distinct during display-write protection.
- Added blanking-aligned B presentation/reorder handling that retains the future P reference while presenting the intervening B picture from scratch, then publishes the retained future reference in display order.
- Corrected the consecutive-P publication-versus-presentation ownership race by pacing a following P picture until its selected destination bank is no longer display-owned, without weakening DDR write protection or changing the B reorder path.
- Consolidated the active inverse-transform implementation around a shared IDCT multiplier bank, reducing DSP use from the earlier 92-DSP development point to 68 DSP blocks while preserving accepted decode behavior.
- Retired the temporary consecutive-P first-fault/timeout/arbiter diagnostic layer after root-cause localization and restored normal USER completion behavior.

## Current supported development subset

- Raw MPEG-2 Video elementary-stream input (`.m2v`).
- Progressive frame pictures on the hardware-proven paths.
- 4:2:0 chroma.
- Continuous supported I-picture playback up to the established 720x480 diagnostic geometry.
- Generalized P-picture regression coverage at 128x96 / 8x6 macroblocks, including signed forward motion, predictor reuse/reset, integer and half-sample interpolation, coded-block-pattern selection, sparse residual placement, quantiser changes, and consecutive reconstructed-P reference use.
- Hardware-proven B-picture regression coverage at 128x96 using deterministic mixed I/P/B streams with forward, backward, and bidirectional prediction, internal macroblock skips, bounded residuals, and display reordering.
- Two retained planar MiSTer DDR3 frame banks for I/P ping-pong/reference ownership plus a separate B scratch region.
- Full 8-bit Y/Cb/Cr reconstruction.
- Fixed 800x600 diagnostic video output.
- Synthetic 33-bit / 90 kHz elementary-stream presentation timing metadata.

The P and B regression paths still have explicit engineering limits. These are implementation limits, not limits of ITU-T H.262 / ISO/IEC 13818-2.

## Known limitations

The following remain outside the v0.4.0 supported development subset:

- General arbitrary MPEG-2/H.262 P- and B-picture playback outside the hardware-proven regression envelope.
- Interlaced frame/field-picture support and broader H.262 picture structures.
- Chroma formats other than 4:2:0.
- General MPEG-2 Program Stream (`.mpg` / `.mpeg`) demux and H.222.0 PES-derived timestamps.
- Audio.
- DVD/VOB navigation and direct optical-disc playback.
- Removal of the current diagnostic geometry/resource caps.

## Release qualification

The hardware-qualified RTL baseline is:

`1370c28e3d34b1fd603c17130986bc336da29a32`

The qualification build was made from a fresh clone of GitHub `master` using Quartus Prime 17.0.2 Lite for Cyclone V `5CSEBA6U23I7`. Quartus Flow and Fitter completed successfully, the standard Phase 1P timing reports were reviewed, and setup endpoint TNS was zero.

Required MiSTer hardware regression:

- `test_p_consecutive_reference.m2v` — PASS for 20 consecutive runs with normal USER acceptance.
- `test_b_mixed_gop.m2v` — PASS.
- `test_b_core_decode.m2v` — PASS.
- `test_p_general_decode.m2v` — PASS.
- `test_all_i.m2v` — PASS.

The release-documentation commits following `1370c28` change documentation only; the synthesized RTL qualified above is unchanged.

## Quartus / timing

- ALMs: 31,782 / 41,910 (76%)
- Registers: 43,812
- Block memory bits: 461,345 / 5,662,720 (8%)
- RAM blocks: 73 / 553 (13%)
- DSP blocks: 68 / 112 (61%)
- PLLs: 3 / 6 (50%)
- Global setup slack: +0.167 ns
- Global hold slack: +0.248 ns
- Global recovery slack: +4.117 ns
- Global removal slack: +0.704 ns
- Minimum pulse-width slack: +0.462 ns
- Focused decoder setup: +1.311 ns, 0 / 100 violations
- Focused video setup: +6.987 ns, 0 / 80 violations
- Setup endpoint TNS: 0

TimeQuest continues to report the established incomplete external-I/O constraint warning class; the accepted qualification has positive reported setup/hold/recovery/removal slack and zero setup endpoint TNS.

## MiSTer binary

The release binary follows the normal MiSTer date-coded naming convention:

`MediaPlayer_20260816.rbf`

The user-built binary attached to the GitHub release should be the hardware-qualified artifact corresponding to the `1370c28` RTL baseline.
