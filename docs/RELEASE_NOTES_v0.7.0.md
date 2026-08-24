# MiSTer Media Player v0.7.0 release notes

v0.7.0 adds bounded MPEG-2 Program Stream playback, MPEG Layer II audio, real picture-PTS presentation, and a matching MiSTer ARM helper. Raw MPEG-2 Video elementary streams remain supported through their byte-exact path.

This remains a developer-oriented pre-release with a deliberately bounded subset rather than general MPEG-2 systems or video conformance.

## Highlights

- Bounded `.mpg` / `.mpeg` Program Stream demultiplexing in the ARM helper.
- MPEG Layer II audio decoded to signed stereo PCM at 44.1 or 48 kHz.
- Picture PTS transported to the FPGA and applied on its 33-bit / 90 kHz presentation timeline.
- Encoded frame cadence remains a mandatory floor; PTS may delay a picture but never advances it early.
- Native pacing for H.262 frame-rate codes 1 through 5: `24000/1001`, exact 24, 25, `30000/1001`, and exact 30 fps.
- Clean-video and PCM queues that keep audio delivery independent of decoder backpressure.
- Byte-exact raw `.m2v` playback with synthetic H.262-derived timing.
- Clean recovery without reboot between audio-video and video-only files.

## Required runtime files

The RBF, helper, and patched Main form one matched release. Do not mix them with components from another build.

| Release path | Install path | Size | SHA-256 |
| --- | --- | ---: | --- |
| `MediaPlayer_20260824.rbf` | `/media/fat/MediaPlayer_20260824.rbf` | 4,184,380 | `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc` |
| `linux/MediaPlayer_Helper` | `/media/fat/linux/MediaPlayer_Helper` | 361,452 | `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483` |
| `MiSTer` | `/media/fat/MiSTer` | 1,166,244 | `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa` |

The helper must be executable. Back up the current Main and Media Player files, install all three matching files, and reboot before the first test.

## Supported v0.7.0 subset

- Raw MPEG-2 Video elementary streams or bounded MPEG-2 Program Streams.
- Progressive frame pictures with 4:2:0 chroma.
- Hardware-qualified video geometry through 720x480 / 45x30 macroblocks.
- Continuous supported I/P/B decode and coded-order/display-order presentation.
- H.262 frame-rate codes 1 through 5.
- Program Stream picture PTS or synthetic raw-stream presentation timing.
- MPEG Layer II audio at 44.1 or 48 kHz; stereo is the hardware-qualified path.
- Two retained DDR3 I/P reference banks, separate B scratch storage, and blanking-aligned presentation.

## Known limitations

- MPEG Transport Stream, DVD/VOB navigation, subpictures, private-stream audio, and arbitrary Program Stream layouts are unsupported.
- Audio codecs other than MPEG Layer II and sample rates other than 44.1/48 kHz are rejected.
- Interlaced pictures, chroma formats other than 4:2:0, and H.262 frame-rate codes 6 through 8 are outside the release envelope.
- Seeking, scrubbing, pause/resume, DVD navigation, and optical-drive integration are not implemented.
- Video output remains the fixed 800x600 engineering presentation path.
- Files must be opened through the normal MiSTer file menu; MGL injection is not qualified.

## Reproducible qualification

- FPGA source baseline: `9a5eea3`.
- Host/helper source baseline: `acdbf8b`.
- MiSTer Main upstream baseline: `0a8fb44ccec6d69c8b7f158abd5fe8065ab2bf4f` plus `host/main_mister/0001-mediaplayer-arm-loader.patch`.
- ARM toolchain: GNU Arm 10.2.1, archive SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a`.
- minimp3 baseline: `ea99364f61c14656440e8d77e9c233ccf3124633` with pinned source and license hashes.

Two clean ARM helper builds and two patched-Main builds were byte-identical. The currently installed target helper and Main also match the hashes above.

Native and ASAN/UBSAN host tests passed exact-video, picture-PTS, PCM, video-only, unsupported-input rejection, source-path, terminal, rate-gate, recovery, and protocol cases. The full 14,315-picture soak produced exact scheduled video and PCM hashes, one clean PCM end marker, bounded batching, zero audio deficit, and clean terminal state.

## Quartus and timing

A clean Quartus Prime 17.0.2 build reproduced the installed and hardware-accepted RBF byte-for-byte.

- ALMs: 29,325 / 41,910 (70%)
- Registers: 45,259
- Block memory: 3,655,139 / 5,662,720 bits (65%)
- RAM blocks: 464 / 553 (84%)
- DSP blocks: 65 / 112 (58%)
- PLLs: 3 / 6 (50%)
- Global setup slack: +0.311 ns
- Global hold slack: +0.238 ns
- Global recovery slack: +3.365 ns
- Global removal slack: +0.497 ns
- Minimum pulse-width slack: +1.122 ns
- Decoder setup slack: +1.782 ns, no violations
- Decoder recovery slack: +11.294 ns, no violations
- Video setup slack: +8.284 ns, no violations
- Quartus errors: 0

TimeQuest retains the established incomplete external-I/O constraint warning class. Every required internal timing category is positive with zero endpoint TNS.

## Four-file MiSTer release gate

Generated regression media is deliberately excluded from the release package. The final gate uses these exact local files:

| Order | File | Size | SHA-256 | Purpose |
| ---: | --- | ---: | --- | --- |
| 1 | `00_good_480p_48k.mpg` | 690,193 | `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5` | Normal 48 kHz audio-video startup after reboot |
| 2 | `02_good_video_only.mpg` | 591,889 | `a3e675cad7b3142d2ea25d5b27d2e84e898572c0b6d080bbd2b0a3d01ac76a95` | Video-only Program Stream |
| 3 | `01_good_480p_44k.mpg` | 690,193 | `417db70be8cadc8ca829984d149cb0a5ccda82b0dfc065869578789290a1c83e` | 44.1 kHz recovery immediately after silent playback |
| 4 | `20_bbb_full_48k.mpg` | 100,059,153 | `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357` | Complete 14,315-picture cadence, sync, credits, and endurance soak |

Every run must complete with correct video and audio behavior, USER solid on, POWER solid on, no diagnostic error flags, and a captured schema-nine result. DISK may blink its final progress code when USER indicates success.

## Packaging

The public archive contains:

- `MediaPlayer_20260824.rbf`
- `MiSTer`
- `linux/MediaPlayer_Helper`
- `SHA256SUMS`
- `INSTALL.txt`
- `SOURCE.txt`
- `LICENSE`
- `LICENSE.minimp3`

The public regression `.mpg` files are not included. Source is available from the tagged repository state, and `SOURCE.txt` records the exact binary-producing baselines.
