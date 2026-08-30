# MiSTer Media Player v0.8.0 release notes

v0.8.0 adds a bounded 720x480 interlaced all-I path with native 480i presentation, AC-3 decode, and AC-3 or DTS passthrough to S/PDIF. The v0.7.0 Program Stream, PTS, and ARM-helper foundation is unchanged.

This remains a developer-oriented pre-release with a deliberately bounded subset rather than general MPEG-2 systems or video conformance. Read the limitations before reporting a file as broken: most material that fails does so because of picture structure, not encoding quality.

## Publication and provenance

[v0.8.0](https://github.com/aquasock/MiSTer-Media-Player/releases/tag/v0.8.0) was published on 2026-08-27 at 17:41:16 America/Phoenix (`2026-08-27T17:41:16-07:00`) as a pre-release. The annotated tag resolves to `af43de2`; all three runtime binaries reproduce from source baseline `2f1d32c`.

The standalone release-notes file was added afterward in `035807a`. Subsequent documentation corrections describe the existing release without moving its tag or changing its assets. GitHub source archives therefore reflect the tagged documentation, while the current notes include these corrections.

## Highlights

- Bounded 720x480 interlaced frame-picture, frame-DCT, all-I decoding with preserved top- or bottom-field-first order and native 480i timing.
- AC-3 decode in the ARM helper through pinned liba52, downmixed to stereo using the stream's own coefficients.
- AC-3 and DTS passthrough to S/PDIF as IEC 61937 bursts, so an external decoder receives the original bitstream. DTS is passthrough only; there is no DTS decoder.
- An `Audio output` menu option selecting HDMI or S/PDIF, muting the output it does not drive.
- Seven hand-test Program Streams covering field order, Bob versus Weave, progressive all-I and progressive I/P/B, and AC-3 and DTS 5.1 channel sweeps.
- Media transfers no longer hold Main's event loop for long periods, which had made the menu sluggish on low-bitrate files.

## Required runtime files

The RBF, helper, and patched Main form one matched release. Do not mix them with components from another build.

| Release path | Install path | Size | SHA-256 |
| --- | --- | ---: | --- |
| `MediaPlayer_20260827.rbf` | `/media/fat/MediaPlayer_20260827.rbf` | 4,332,740 | `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce` |
| `linux/MediaPlayer_Helper` | `/media/fat/linux/MediaPlayer_Helper` | 399,340 | `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8` |
| `MiSTer` | `/media/fat/MiSTer` | 1,170,340 | `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9` |

Main is patched and is not optional: it passes the core's `Audio output` selection to the helper and yields during backpressured transfers to keep the menu responsive. An older Main may display the core's option without passing its selection to the helper. The helper must be executable. Back up the current files, install all three, and reboot before the first test.

## Supported v0.8.0 subset

The two video paths differ sharply and are stated separately.

- Progressive: 4:2:0 I, P and B pictures through 720x480.
- Interlaced: 720x480 at `30000/1001` only, 4:2:0, **I-pictures only**, frame-structured, frame DCT and frame prediction only, top- or bottom-field-first, no `repeat_first_field`.
- H.262 frame-rate codes 1 through 5; codes 6 through 8 are rejected before transport.
- Raw `.m2v` elementary streams or bounded MPEG-2 Program Streams.
- Audio decode: MPEG Layer II at 44.1 or 48 kHz, and AC-3 at 48 kHz, to stereo.
- Audio passthrough: AC-3 and DTS to S/PDIF for an external decoder.

## Known limitations

- Field pictures, field DCT, interlaced P and B pictures, `repeat_first_field` (3:2 pulldown) and 576i are all rejected before decode. Most commercial DVDs use several of these and will not play.
- The AC-3 stereo downmix discards LFE. Discrete surround requires passthrough and an external decoder.
- Only the first audio track is played. Track switching needs a control channel that protocol one does not implement.
- Passthrough carries the bitstream untouched, so volume and mixing do not apply to it, and the unused output is muted rather than duplicated.
- On material whose peak coded picture is large enough, one or two display slots are missed at that picture and appear as a repeated frame rather than a dropped one. This is a property of input buffer depth against peak picture size. The qualified full-length fixture hits it once, at a scene cut, and it was not visible in normal viewing.
- Sharp colour transitions carry one blended pixel column that an independent software decoder does not produce, consistent with horizontal chroma upsampling in the display path. It is obvious on synthetic colour bars and subtle on ordinary material, and it is not specific to any picture type.
- **Comprehensive playback pixel accuracy remains unqualified.** Decoder reconstruction has simulation comparisons, and a targeted hardware-screenshot comparison against the same software-decoded frame found the chroma-edge difference above. That measurement is not a full playback pixel-validation suite; the exact cause of the blended column remains unproven.
- The framework scaler retains little setup margin. At fitter seed 16 its horizontal accumulator missed timing by 0.070 ns once this release's audio routing was added; seed 17 places it at +0.243 ns. The next change that adds comparable logic may expose it again.
- Seeking, scrubbing, pause/resume, DVD navigation, and optical-drive integration are not implemented.

## Reproducible qualification

All three binaries were rebuilt from source baseline `2f1d32c` and reproduced byte for byte: the RBF from a clean export of tracked files only, and the helper and Main from a wiped dependency directory with a freshly extracted toolchain.

- FPGA toolchain: Quartus Prime Lite 17.0.2 Build 602, fitter seed 17.
- ARM toolchain: `gcc-arm-10.2-2020.11-x86_64-arm-none-linux-gnueabihf`.
- MiSTer Main upstream baseline: `0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f`.
- minimp3 baseline `ea99364f61c14656440e8d77e9c233ccf3124633`; liba52 baseline 0.7.4.

## Quartus and timing

- 0 errors, 208 warnings, with the warning identifier set identical to the accepted build: none new, none missing.
- Fit: 31,464 ALMs (75%), 50,273 registers, 4,048,355 block-memory bits (71%), 512 RAM blocks (93%), 67 DSP blocks, 3 PLLs.
- Timing positive in every required category with zero total negative slack: +0.243 ns setup, +0.251 ns hold, +2.865 ns recovery, +0.564 ns removal, +0.925 ns minimum pulse width.

## Host and audio regressions

- Host suites pass on the release binaries: cadence decoder layout, eleven DVD ceiling tests, and the Main integration profile covering 168 RTL cases, 96 burst cases, 20 step-resume cases and guarded fault cases.
- Synthetic AC-3 decode against an independent decoder: maximum sample difference 3, correlation 0.999999972. A separate commercial AC-3 track comparison had maximum difference 299, RMS difference 2.60 and correlation 0.999976; the synthetic figure is not a bound on all material.
- AC-3 downmix placement: front channels hard left and right, centre equally in both, surrounds on their own side attenuated, LFE absent.
- Passthrough: bursts carry source frames byte for byte, verified for both AC-3 and DTS, and on a commercial DVD AC-3 track as well as synthetic fixtures.
- MPEG Layer II remains byte-identical on the full-length fixture across both audio output modes.

## Hardware evidence

- The seven hand tests each completed 360 of 360 pictures with zero error flags. Native interlaced runs had zero deadline gaps; those native timing counters do not establish progressive cadence, whose different presentation timing was recorded separately.
- Interlaced top- and bottom-field-first, Bob versus Weave, progressive all-I and progressive I/P/B all played correctly; the progressive I/P/B test displayed 121 reference and 239 B pictures.
- AC-3 was confirmed audible through both HDMI decode and S/PDIF passthrough, the latter reproducing LFE on a receiver for the first time.
- Audio claims marked as measured come from decoder comparison; claims about how playback sounded are user reports and are not independently measured.
- One receiver tested here reproduces LFE from AC-3 but not from DTS, although the transmitted DTS provably carries it. That is a device observation, not a core limitation.

The hand tests used the released RBF and helper hashes. Tests one through six were initially captured with the older Main; the released Main's yield fix was separately confirmed on test one after installation, followed by progressive tests four and seven. The public package contains that released Main, RBF and helper. A confirmation hardware run following installation from the final package remains unrecorded. Publication and binary identity do not constitute a new hardware test.

## Packaging

`MiSTer_Media_Player_v0.8.0.zip` contains the three runtime files, `SHA256SUMS`, `INSTALL.txt`, `SOURCE.txt`, and licences for the project, minimp3 and liba52. Generated test media is not shipped.

- Download size: **2,867,028 bytes**.
- ZIP SHA-256: `5f55b49eb863f74a777b548b4f42b744a9130b4161f176b687ca297deeffcaf3`.
- Total uncompressed member size: 5,948,567 bytes. Earlier engineering notes incorrectly used this as the ZIP size.

The public ZIP passes its integrity checks, and all files covered by its `SHA256SUMS` match the retained package checksums. The runtime sizes and hashes above identify the released files; later documentation edits do not replace the installation or provenance files inside the ZIP.
