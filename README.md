# MiSTer Media Player

An experimental media-player core for [MiSTer FPGA](https://github.com/MiSTer-devel/Main_MiSTer), with a standards-driven MPEG-2 Video / ITU-T H.262 decoder implemented primarily in FPGA logic.

> **Development status:** active, pre-release, developer-oriented. **v0.8.0 is the current milestone**, adding a bounded 720x480 interlaced frame-DCT all-I path with native 480i presentation, AC-3 decode, and AC-3/DTS passthrough over S/PDIF, on the v0.7.0 Program Stream, PTS, and ARM-helper foundation.

## Current status

The active decoder is the clean H.262 implementation under `rtl/mpeg2_new/`. v0.7.0 provides:

- raw MPEG-2 Video elementary-stream playback and a bounded H.222.0 MPEG-2 Program Stream path for `.mpg` and `.mpeg` files;
- a matching ARM helper that demultiplexes Program Streams, decodes MPEG Layer II audio to signed stereo PCM, and transports video, picture PTS, and PCM to the FPGA;
- byte-exact raw `.m2v` pass-through with a synthetic 90 kHz fallback timeline;
- Program Stream picture PTS driving the FPGA 90 kHz presentation timeline;
- cadence as a mandatory floor: PTS may delay a picture but never presents it earlier than its encoded H.262 frame cadence;
- hardware-qualified H.262 frame-rate codes 1 through 5: `24000/1001`, exact 24, 25, `30000/1001`, and exact 30 fps;
- MPEG Layer II audio at 44.1 kHz and 48 kHz through an 8,192-frame stereo PCM FIFO;
- a clean-video queue so decoder backpressure cannot prevent timely PCM delivery;
- continuous progressive 4:2:0 I/P/B decoding, retained DDR3 reference banks, separate B scratch storage, and coded-order/display-order presentation;
- full 8-bit Y, Cb, and Cr reconstruction with limited-range BT.601 presentation;
- clean Program Stream and raw-stream terminal handling, including reordered-picture flush and one explicit PCM end marker.
- a 720x480 interlaced frame-picture, frame-DCT, all-I subset with preserved top- or bottom-field-first order and native 480i timing;
- AC-3 decode to stereo, and AC-3 or DTS passthrough to S/PDIF as IEC 61937 bursts for an external decoder.

The supported subset is intentionally bounded while the architecture is being proven. These are implementation limits, not limits of H.262 or H.222.0.

| Area | Current implementation |
| --- | --- |
| Input | Raw MPEG-2 Video `.m2v`, or bounded MPEG-2 Program Stream `.mpg` / `.mpeg` through the ARM helper |
| Video, progressive | 4:2:0 I, P and B pictures through 720x480 |
| Video, interlaced | 720x480 at 30000/1001 only, 4:2:0, **I-pictures only**, frame-structured, frame DCT and frame prediction only, top- or bottom-field-first, no `repeat_first_field` |
| Picture types | Coded-order/display-order presentation with B reordering |
| Presentation rates | H.262 frame-rate codes 1..5; codes 6..8 are rejected before transport |
| Program Stream timing | Picture PTS on a 33-bit / 90 kHz FPGA timeline with cadence-floor enforcement |
| Raw-stream timing | Synthetic 33-bit / 90 kHz cadence derived from H.262 frame-rate metadata |
| Audio | MPEG Layer II at 44.1 or 48 kHz, and AC-3 at 48 kHz, decoded by the helper to stereo. The AC-3 stereo downmix discards LFE, as the format specifies |
| Audio passthrough | AC-3 and DTS carried to S/PDIF as IEC 61937 bursts for an external decoder. DTS is passthrough only; there is no DTS decoder |
| Audio output | A menu option selects HDMI or S/PDIF. The unused output is muted, because both are fed from one stereo stream |
| Audio buffering | Packed signed PCM records into an 8,192-frame stereo FPGA FIFO |
| Frame storage | Two retained planar MiSTer DDR3 I/P banks plus a distinct B scratch region |
| Video output | 800x600 progressive diagnostic output, or native 480i for supported interlaced input |

The frozen `rtl/mpeg2fpga/` tree remains historical reference material and is not part of the active Quartus build.

## Installation

v0.8.0 requires three matching runtime files. Back up the existing files before replacing them.

| Release file | MiSTer destination | SHA-256 |
| --- | --- | --- |
| `MediaPlayer_20260827.rbf` | `/media/fat/MediaPlayer_20260827.rbf` | `61a2fed28425a461c8b886bdf809e3ef76a320e5688bb22a816135c36ef981ce` |
| `MiSTer` | `/media/fat/MiSTer` | `01a15750476f3616385fe98dee2d4d832f34823df5ddfc7098966a5b786efad9` |
| `MediaPlayer_Helper` | `/media/fat/linux/MediaPlayer_Helper` | `f6206ba01459eefcc40b26d3d5b3b6ca4f70e496fbeadc317254f86f19f370c8` |

`MiSTer` is a patched Main and is not optional: without it there is no `Audio output` menu option, and media transfers hold the event loop long enough to make the menu sluggish on low-bitrate files. The helper must be executable. Reboot after installing Main. Mixing v0.8.0 components with a different Main, helper, or RBF is unsupported.

## Release qualification

The qualified FPGA source baseline is commit `9a5eea3`; the host/helper source baseline is commit `acdbf8b`. Later release-documentation commits do not alter those binaries.

A clean Quartus Prime 17.0.2 build reproduced the already accepted RBF byte-for-byte:

- size: 4,184,380 bytes;
- SHA-256: `484328e51c6e764890bf2bdcd947448e2eaaaac2c603e93da28009475e44dafc`;
- Quartus errors: 0;
- global setup: +0.311 ns;
- global hold: +0.238 ns;
- global recovery: +3.365 ns;
- global removal: +0.497 ns;
- minimum pulse width: +1.122 ns;
- decoder setup: +1.782 ns with no violations;
- decoder recovery: +11.294 ns with no violations;
- video setup: +8.284 ns with no violations.

Two independent ARM helper builds were byte-identical at 361,452 bytes with SHA-256 `c99237246416ecd8278d90ff6e15e7a00cd8ab1d49c960b8c77fbe00f4ba0483`. Two independent patched-Main builds were byte-identical at 1,166,244 bytes with SHA-256 `16517a9927c659616796b45c8e2488da2a26f0595c91418ed09dc0eb7a5787aa`.

Native and sanitized host qualification covers exact video preservation, PTS placement, 44.1/48 kHz PCM output, video-only input, unsupported input rejection, clean terminal behavior, recovery without reboot, bounded batching, and the full 14,315-picture audio-video soak.

The final four-file MiSTer release gate passed on the exact release binaries:

1. `00_good_480p_48k.mpg` — normal 48 kHz audio-video startup.
2. `02_good_video_only.mpg` — video-only Program Stream.
3. `01_good_480p_44k.mpg` — 44.1 kHz recovery immediately after silent playback.
4. `20_bbb_full_48k.mpg` — complete audio-video cadence and endurance soak.

All four runs ended with USER and POWER solid, DISK blinking its normal eleven-count progress code, sequence end, presentation completion, and zero aggregate, decoder, presentation, PCM protocol, or underrun errors. The complete soak delivered all 14,315 pictures and 14,314 swaps with zero credits-window cadence outliers; the user reported smooth playback and credits with no remaining jump.

## Releases

Milestone releases use semantic-version tags on GitHub. RBF assets retain the normal MiSTer date-coded naming convention.

Current milestone:

- **v0.7.0** — bounded Program Stream input, real picture PTS, MPEG Layer II audio through the ARM helper, native 23.976/24/25/29.97/30-fps cadence, clean video/PCM queuing, and full-length audio-video playback; binary `MediaPlayer_20260824.rbf`.

Previous milestone:

- **v0.6.0** — sustained progressive 720x480 real-stream I/P/B playback with native 23.976/24/25-fps cadence; binary `MediaPlayer_20260822.rbf`.

See [the v0.7.0 release notes](docs/RELEASE_NOTES_v0.7.0.md) for asset hashes, qualification details, and known limits.

## Converting media with FFmpeg

Two shapes play: a progressive Program Stream, and the narrower interlaced 480i
subset. Pick by what you want on screen, and read Known limitations first — most
material that fails does so because of picture structure, not encoding quality.

### Progressive

Progressive 720x480 4:2:0 with I, P and B pictures, plus MPEG Layer II or AC-3
audio. This exact-24-fps, 48 kHz recipe is a suitable starting point:

```bash
ffmpeg -hide_banner -y \
  -i "input.mp4" \
  -map 0:v:0 -map 0:a:0 \
  -vf "fps=24,scale=720:480:force_original_aspect_ratio=decrease:flags=bicubic,pad=720:480:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1" \
  -c:v mpeg2video -pix_fmt yuv420p -threads 1 -flags +bitexact \
  -g 24 -bf 2 -q:v 6 -qmin 2 -qmax 12 \
  -sc_threshold 1000000000 -mpv_flags +strict_gop \
  -c:a mp2 -ar 48000 -ac 2 -b:a 192k \
  -f vob "output.mpg"

python3 tools/streams/finalize_program_stream.py "output.mpg"
python3 tools/streams/check_media_compatibility.py "output.mpg"
```

Use `-an` and omit the audio codec options for a video-only Program Stream. Raw
`.m2v` elementary streams remain supported. The finalizer supplies the required
H.262 sequence-end and Program Stream end markers when absent.

For AC-3 instead, replace the audio options with `-c:a ac3 -ar 48000 -ac 6 -b:a
448k`. A 5.1 track is only heard as 5.1 through S/PDIF passthrough; in HDMI mode
it is downmixed to stereo and its LFE is discarded.

### Interlaced 480i

The interlaced path is deliberately narrow: 720x480 at 30000/1001, 4:2:0,
**I-pictures only**, frame-structured, frame DCT and frame prediction only.

FFmpeg's interlacing flags will not produce it. `-flags +ildct` selects field
DCT and `+ilme` selects field prediction, and both are rejected before decode.
The supported shape is ordinary frame-DCT coding of woven field pairs, with the
interlaced signalling applied afterwards. Use the committed generator, which
does exactly that and verifies the result:

```bash
python3 tools/streams/generate_test_suite.py --output-dir /tmp/suite --duration 12
```

It also builds the seven hand tests described under Diagnostic streams. To
convert your own material, follow the same sequence its `build` function uses:
encode at 60000/1001, weave with `tinterlace=mode=interleave_top` (or
`interleave_bottom` for bottom-field-first), encode all-I with `-g 1 -bf 0`, then
patch the signalling with `generate_test_interlaced_i_frames.patch_interlaced_signalling`.

`check_media_compatibility.py` predates the interlaced path and rejects native
interlaced files. It remains a valid gate for progressive streams; for
interlaced ones, use the structure check the generator performs instead.

## Architecture

```text
MiSTer Main file selection
          |
          v
MediaPlayer_Helper
Program Stream demux / MP2 decode / picture PTS
          |
          v
packed video + PTS + PCM transport
          |
          +-----------------------+
          |                       |
          v                       v
clean-video queue          8,192-frame PCM FIFO
          |                       |
          v                       v
H.262 FPGA decoder       MiSTer stereo audio output
          |
          v
DDR reference/B-scratch storage
          |
          v
cadence floor + 90 kHz PTS scheduler
          |
          v
800x600 diagnostic or native 480i video output
```

Raw `.m2v` files bypass Program Stream demux and audio decoding while retaining the same FPGA H.262 path.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`host/arm/ARCHITECTURE.md`](host/arm/ARCHITECTURE.md) for design details.

## Building

The FPGA project targets Quartus Prime 17.0.x:

```bash
quartus_sh --flow compile MediaPlayer
quartus_sta -t tools/phase1p_timing.tcl
```

Build the ARM helper and matching patched Main with the ARM GNU 10.2 compiler used by MiSTer Main:

```bash
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc host/build_arm_stack.sh --arm
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc host/build_arm_stack.sh --main
```

The build script pins the minimp3 revision, MiSTer Main revision, dependency hashes, and Main patch. Release candidates require reproducible FPGA, helper, and Main binaries plus host and MiSTer regression evidence.

## Known limitations

- Program Stream support is bounded; MPEG Transport Stream, DVD/VOB navigation, private-stream audio, subpictures, and arbitrary systems-layer layouts are not supported.
- Decoded audio is MPEG Layer II at 44.1 or 48 kHz and AC-3 at 48 kHz. Other codecs and sample rates are rejected. Only the first audio track is played; track switching needs a control channel that protocol one does not implement.
- AC-3 is downmixed to stereo for decoded output, which discards LFE by the format's own convention. Discrete surround requires passthrough and an external decoder.
- Passthrough carries the bitstream untouched, so nothing may scale it. The audio output option therefore mutes the output it is not driving, and volume control does not apply to a passthrough stream.
- Progressive 4:2:0 video is released through 720x480 and decodes I, P and B pictures. The interlaced path is far narrower: 720x480 at 30000/1001 only, I-pictures only, frame-structured, frame DCT and frame prediction only. Field pictures, field DCT, interlaced P and B pictures, `repeat_first_field` (3:2 pulldown), and 576i are all rejected before decode. Most commercial DVDs use several of these and will not play.
- Playback pixel accuracy has never been qualified. Every pixel comparison in this project's history was performed in simulation; correctness of what actually reaches the screen rests on inspection.
- Sharp colour transitions show one blended pixel column that an independent software decoder does not produce, consistent with horizontal chroma upsampling in the display path. It is obvious on synthetic colour bars and subtle on ordinary material, and it is not specific to any picture type.
- On material whose peak coded picture is large enough, one or two display slots are missed at that picture, shown as a repeated frame rather than a dropped one. This is a property of input buffer depth against peak picture size, not of the stream; the qualified full-length fixture hits it once, at a scene cut.
- H.262 frame-rate codes 6 through 8 (50, 59.94, and 60 fps) are rejected.
- Seeking, scrubbing, pause/resume, DVD navigation, and optical-drive integration are not implemented.
- Output offers two interlaced tiers. Normal processed HDMI sends native 480i timing into MiSTer's scaler and lets the `HDMI scaler deinterlacer` menu choose Weave or Bob. The external-processing tier preserves native 480i fields; truly unscaled HDMI additionally requires MiSTer's separate `direct_video` setting, which the core menu cannot enable.
- Files should be opened through the normal MiSTer file menu; MGL injection is not a qualified loading method.

### Native elementary-stream startup

The clean-video queue holds up to 64 KiB. For native 29.97-fps all-I video
without PTS or PCM records, the first cached picture stays black until a second
picture is presentable (or sequence end arrives for a one-picture file). It is
then shown at a complete field-pair boundary, with swaps starting on subsequent
boundaries. HS, VS, DE and the raster clock stay continuous. This adds startup
reserve; it does not change playback speed or accelerate decoding. Timestamped
video, audio and other modes bypass the reserve. A new download rearms it;
Bob/Weave changes do not.

Schema 19 still timestamps its first presentation at **first reference decode
completion**, so its aggregate rate includes startup wait. Use the subsequent
swap intervals and deadline-gap counts to assess steady cadence. The simulation
runner additionally reports `visible_start_cycle` and `visible_span_cycles`;
its FIFO/host/DDR and field-window models are not a full HDMI hardware replay.

## Diagnostic streams

Generated binary media remains local and is not included in the public release. The four release-gate Program Streams are reproducible through the committed generators and are identified by SHA-256 in the release notes.

### Hand tests

`tools/streams/generate_test_suite.py` builds seven short Program Streams meant to be watched and listened to rather than scored automatically. Each is chosen to make one failure mode obvious: a bar sweeping down the frame for interlaced top- and bottom-field-first order, scrolling bands that separate Weave from Bob, progressive all-I and progressive I/P/B, and AC-3 and DTS 5.1 channel sweeps that sound one channel at a time. The audio sweeps exercise discrete channels only in S/PDIF mode, where the listener's own decoder does the work; in HDMI mode they exercise the stereo downmix, in which LFE is absent by design.

The USER LED is the top-level completion diagnostic. For successful v0.7.0 runs, USER and POWER remain solid while DISK may report its final progress code. Exact schema-nine telemetry and all three LEDs are captured for every release-gate run.

## Project layout

- `MediaPlayer.sv` and `MediaPlayer_top_*.svh` — MiSTer top-level integration, transport, queues, audio, and presentation scheduling.
- `rtl/mpeg2_new/` — active H.262 decoder pipeline.
- `rtl/mpeg2_luma_framebuffer.sv` — DDR-backed frame readback and video-side line caching.
- `host/arm/` — ARM helper, media source, and packed transport protocol.
- `host/main_mister/` — pinned patch adding helper-based media loading to MiSTer Main.
- `tools/streams/` — deterministic media generation, finalization, compatibility, and transport analysis.
- `rtl/mpeg2fpga/` — frozen legacy reference; inactive in `files.qip`.
- `docs/` — architecture, building, testing, and release documentation.

## Development roadmap

Future work can extend the qualified envelope toward 50/59.94/60 fps, interlaced P/B and field-picture structures, field DCT, `repeat_first_field` and 576i, broader Program Stream handling, additional audio codecs and multi-track selection, qualification of playback pixel accuracy against a software decoder, improved chroma presentation, playback controls, seeking, DVD navigation, optical-drive integration, and qualification of native 480i through external HDMI-to-SDI hardware.

See [`CHANGELOG.md`](CHANGELOG.md) for completed milestones.

## Standards and design policy

Video syntax and decoding behavior are developed against **ITU-T H.262 / ISO/IEC 13818-2**. Program Stream, PES, and timing work uses **ITU-T H.222.0 / ISO/IEC 13818-1**. MPEG Layer II decode is performed by the pinned minimp3 dependency.

AC-3 decode is performed by the pinned liba52 dependency, and IEC 61937 framing follows that standard for passthrough.

Implementation constraints, qualification limits, and engineering diagnostics are implementation choices rather than MPEG standard requirements. In particular, the picture types and structures this core rejects are limits of this implementation, not of H.262.

## AI-assisted development

The **AI project-control system** used to manage MiSTer-Media-Player was formally exposed with the v0.6.0 milestone for contributors interested in experimenting with it.

The `.ai` directory had already been driving much of the project's development before v0.6.0 made it a documented contributor workflow.

The basic idea is simple:

**AI agents are temporary. The repository is authoritative.**

There is a plain-text bootstrap procedure in:

`/.ai/core-bootstrap.md`

I can give that bootstrap text to a fresh AI session on a supported platform and have it recover the project state from the repository. It reads the authoritative project-control files, the recent development history, the current source state and the latest validation results.

From there I can usually just tell it:

`continue`

and development resumes from the latest recorded engineering state.

The important part is that I do **not** rely on a long-running AI conversation to remember the project correctly.

### Why the `.ai` directory exists

FPGA development can consume an enormous amount of AI context very quickly. Build logs, Quartus reports, simulation results, timing failures, diagnostic experiments and source changes all add up.

I found that keeping too much history in active context actually made the agents substantially worse.

The main mechanism I currently use to control this is the ring-buffer history in `.ai/core-log.md`.

I experimented with different sizes:

- ~100 entries retained too much irrelevant history and sessions became unreliable.
- ~20 entries forgot useful diagnostic history and sometimes repeated already-completed experiments.
- ~40 entries has been a good balance so far.

I may experiment with reducing that further.

The goal is to keep the agent working inside a small, relevant engineering context while the permanent project history remains in Git.

### Development philosophy

The system is designed around a few rules:

- **Agents are disposable.**
- **The repository is authoritative.**
- **The AI platform should not matter.**
- **A new session should be able to recover the project without relying on conversational memory.**
- **AI-generated changes are not trusted simply because an AI produced them.**
- **Simulation, regression tests, Quartus fitting, TimeQuest timing and real MiSTer hardware remain the validation authority.**

That last point is important.

The AI can propose RTL all day long. If the regression fails, timing fails, Quartus fails, or the MiSTer hardware fails, then the change is wrong.

### Contributing with an AI agent

If you want to experiment with AI-assisted FPGA development on this project:

1. Fork or clone:
   
   `https://github.com/aquasock/MiSTer-Media-Player`

2. Configure your **local copies** of `.ai/core.md` and `.ai/core-bootstrap.md` for your own development environment.

3. Make sure your workflow includes checking the upstream project's current `.ai/core-log.md` before making changes so your agent understands what has changed on the main project since your fork diverged.

4. Work normally on your branch and retain your build/test history.

5. If the work turns into something worth merging, open a normal contribution with both the source changes and the relevant `.ai/core-log.md` history.

The log is useful because it gives the integration agent much more than just a diff. It explains:

- what was attempted,
- what failed,
- what was measured,
- what was hardware-tested,
- and why the final implementation looks the way it does.

I experimented with this concept separately in:

`https://github.com/aquasock/MiSTer-Media-Player-Audio`

That was an early dry run with an older core.md file and did well.

### If you just want to experiment

You do not need Quartus or even an FPGA development environment just to see how the recovery system behaves.

You can copy the bootstrap text from `.ai/core-bootstrap.md` into a **fresh AI session** and let it initialize the project.

Once recovery is complete, try:

`continue`

Obviously, without the required local tools, repository permissions and Quartus environment, it will not be able to perform the complete development workflow. But it should still be able to recover and reason about the current project state.

### Security warning

One very important warning:

**Never give an unknown AI bootstrap prompt control of your development environment without reading it first.**

Treat an AI bootstrap procedure the same way you would treat an unfamiliar shell script.

Before using mine—or anyone else's—I strongly recommend:

1. Read `core-bootstrap.md`.
2. Read `core.md`.
3. Understand what resources and permissions the agent is being instructed to use.
4. Audit the rest of the `.ai` directory.
5. If possible, have a separate sandboxed session inspect it for prompt-injection tricks, hidden instructions or unexpected external actions before running it with real repository credentials.

The goal here is not “let AI loose on an FPGA project.”

It is almost the opposite:

**make the AI disposable, constrain what it is allowed to believe, preserve the engineering state outside the conversation, and require normal FPGA validation before anything becomes authoritative.**

v0.6.0 was the first release to treat this workflow itself as something the community could beta test.

## Contributing

Contributions are welcome, but this is an FPGA-first project where synthesis, timing, CDC behavior, and hardware regression testing matter as much as functional RTL changes. Please read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request.

## License

This repository includes the GNU General Public License version 2 in [`LICENSE`](LICENSE). Upstream or third-party files may retain their own copyright and license notices.

## Acknowledgements

This project is built on the MiSTer framework and began from the MiSTer core template structure. The repository also retains the earlier MPEG2FPGA implementation as a frozen reference while active development proceeds on the clean H.262 decoder.
