# Building and Testing

## Requirements

- Intel/Altera Quartus Prime 17.0.x; the v0.8.0 release used Lite 17.0.2 Build 602
- MiSTer-compatible DE10-Nano target hardware
- the repository cloned with its `sys/` framework content present
- ARM GNU 10.2 for the helper and patched MiSTer Main, plus a native C compiler for host verification
- Python 3, FFmpeg and Pillow for the applicable media-generation and telemetry tools

The project file is `MediaPlayer.qpf` and the active source list is maintained in `files.qip`.

In the standard project environment, run Quartus, simulations, media generation and other intensive checks on the build PC. Pull the published source there before official qualification; publish commits from the Raspberry Pi checkout. A documentation-only change does not require rebuilding unchanged runtime binaries.

## Full Quartus build

From the repository root:

```bash
quartus_sh --flow compile MediaPlayer
```

The project is configured to generate an RBF under `output_files/`.

A full compile is required after meaningful active RTL, source-list, constraints, PLL/clocking, or top-level integration changes.

## Focused timing validation

After a successful compile, run:

```bash
quartus_sta -t tools/phase1p_timing.tcl
```

This script reports the timing views used during Phase 1P closure, including the active decoder and video clock domains and focused same-clock paths.

Do not treat a successful functional compile as sufficient when a change can affect timing, reset release, clock-domain crossings, DDR arbitration, or frame-cache control.

## Hardware validation

The current [v0.8.0 hand-test instructions](TEST_INSTRUCTIONS.md#v080-hand-tests) cover field order, Bob/Weave, progressive I and I/P/B, AC-3 decode, and AC-3/DTS passthrough. Generate media locally with the committed scripts under `tools/streams/`; the release ZIP does not contain the test files. Older all-I and regression-pack streams remain useful focused controls, not a substitute for current integration testing.

Install the matched RBF, helper and patched Main as described in the [README](../README.md#installation). Hardware lifecycle and playback remain user-controlled. Record installed hashes, selected modes, reboot/reload state and all three LEDs; collect the helper log before another playback overwrites it, followed by a fresh checksum-valid schema-19 terminal screenshot. Do not infer completion or cadence from a plausible still image or one LED alone.

## Helper and Main builds

From the repository root on the build PC:

```bash
host/build_arm_stack.sh --native
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc host/build_arm_stack.sh --arm
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc host/build_arm_stack.sh --main
```

The outputs are `host/build/media_player_helper.native`, `host/build/MediaPlayer_Helper`, and `host/build/MiSTer`. The script pins minimp3, miniaudio, liba52 and upstream Main and verifies fetched dependencies. Check each command's exit status before using an output: the presence of an older binary or the absence of the word "error" in a log does not prove a successful build. Keep the toolchain in a persistent location.

## Acceptance checklist for active RTL changes

Before considering a hardware phase complete:

1. Quartus Flow completes successfully.
2. Fitter completes successfully.
3. Standard TimeQuest setup/hold/recovery/removal results are reviewed.
4. `tools/phase1p_timing.tcl` is rerun when the architecture or placement can materially change.
5. The agreed hardware matrix covers the changed behavior and relevant existing video, audio, cadence and transport paths.
6. Completion, picture counts and error flags are checked against the exact fixture; native deadline counters are not a progressive cadence oracle.
7. The displayed image is checked for new flicker, corruption, color shifts, line/cache artifacts, or instability.
8. Resource growth is reviewed when a change adds meaningful logic, memory, or DSP use.

## Quartus source-file discipline

Add or remove active RTL in `files.qip` manually. Avoid adding source files through the Quartus GUI in a way that causes them to be emitted into `MediaPlayer.qsf` instead.

The active build deliberately excludes the frozen `rtl/mpeg2fpga/` reference implementation.

## Clean builds

Quartus-generated directories and reports are ignored by `.gitignore`, including `db/`, `incremental_db/`, and `output_files/`.

For release qualification or suspicious incremental behavior, use a fresh checkout or export of the exact tracked source with no reused Quartus database or prior output binaries. Preserve the previous qualified artifacts. Compare new hashes only after all required commands exit successfully.

v0.8.0 reproduced all three binaries from `2f1d32c`; its published tag is `af43de2`. Source and toolchain provenance, seed 17, runtime hashes and measured timing are recorded in the [v0.8.0 release notes](RELEASE_NOTES_v0.8.0.md). Reproducing a binary does not constitute a new hardware run.

## Known presentation limitation

A hardware-screenshot comparison found a blended pixel column at sharp colour transitions that the independent decoder did not produce. Chroma upsampling is a hypothesis, not a proven cause. Comprehensive playback pixel qualification remains open; distinguish this recorded observation from new corruption introduced by a candidate.
