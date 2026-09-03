# Building and Testing

## Requirements

- Intel/Altera Quartus Prime 17.0.x; current release builds use Lite 17.0.2 Build 602
- MiSTer-compatible DE10-Nano target hardware
- the repository cloned with its `sys/` framework content present
- ARM GNU 10.2 for the helper and patched MiSTer Main, plus a native C compiler for host verification
- FFmpeg and FFprobe for media inspection and conversion

The project file is `MediaPlayer.qpf` and the active source list is maintained in `files.qip`.

Run the commands below from the Raspberry Pi checkout. `tools/build.sh` syncs the source to the `mister-build` Quartus machine, runs the compile and timing gates there, then retrieves the verified RBF. A documentation-only change does not require rebuilding unchanged runtime binaries.

## Full Quartus build

From the repository root:

```bash
tools/build.sh
```

The project is configured to generate an RBF under `output_files/`.

A full compile is required after meaningful active RTL, source-list, constraints, PLL/clocking, or top-level integration changes.

## Focused timing validation

After a successful compile, run:

```bash
tools/build.sh timing
```

This script reports the timing views used during Phase 1P closure, including the active decoder and video clock domains and focused same-clock paths.

Do not treat a successful functional compile as sufficient when a change can affect timing, reset release, clock-domain crossings, DDR arbitration, or frame-cache control.

## Hardware validation

The current [hardware test instructions](TEST_INSTRUCTIONS.md) cover MPEG files,
standalone audio, DVD ISO/direct-disc startup, authored menus, scene selection,
chapters, pause/resume, telemetry and repeated navigation. Real commercial DVD
testing complements the deterministic host and simulation suite because disc
authoring and optical-drive behavior cannot be represented by one fixture.

Install the matched RBF, helper and patched Main as described in the [README](../README.md#installation). Record installed hashes and playback observations; collect the helper log before another playback overwrites it, followed by a fresh scaled screenshot.

## Helper and Main builds

From the repository root on the build PC:

```bash
tools/build.sh host native
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc tools/build.sh host arm
ARM_CC=/path/to/arm-none-linux-gnueabihf-gcc tools/build.sh host main
```

The outputs are `host/build/media_player_helper.native`,
`host/build/MediaPlayer_Helper`, and `host/build/MiSTer`. The script pins
minimp3, miniaudio, stb_vorbis, liba52, libdvdcss, libdvdread, libdvdnav and
upstream Main and verifies fetched dependencies. The DVD libraries are linked
statically into the helper; encrypted ISO or disc support does not use a
target-installed `libdvdcss.so`. Check each command's exit status before using
an output: the presence of an older binary or the absence of the word "error"
in a log does not prove a successful build. Keep the toolchain in a persistent
location.

Generate the optional standalone-audio visualizer pack with FFmpeg:

```bash
python3 tools/generate-audio-visualizer.py \
  host/build/MediaPlayer_Visualizer.mmpvis
```

The helper validates the pack signature, index, GOP structure and native
interlaced picture metadata before using it. The target install path is
`/media/fat/linux/MediaPlayer_Visualizer.mmpvis`; a missing or rejected pack
falls back to the full-frame audio interface.

The deterministic menu boundary tests are `tools/test_dvd_spu.c`,
`tools/test_dvd_random_access.c` plus the three
`tools/test_dvd_overlay_*.sv` benches. With an authorized local image,
`tools/test_dvd_menu_navigation.py HELPER IMAGE.iso` additionally exercises
real first-play/root navigation, highlight motion, activation, ready/go
barriers and complete overlay-plane transport without accessing the MiSTer.

Direct optical playback additionally requires the launcher at the exact target
path `/media/fat/games/MediaPlayer/USB DVD Drive.dvd`. Patched Main maps that
file to `dvd:/dev/sr0`; the helper requires the source path to be absolute and
opens the block device directly through libdvdnav. A filesystem mount is not a
prerequisite. Verify `/dev/sr0` exists and is readable before testing.
Direct-disc playback reuses the authenticated navigation session across
preflight and then starts an 8 MiB asynchronous RAM ring with a 4 MiB initial
reserve. `MMP_DVD_TEST_STALL_AFTER_BYTES` and `MMP_DVD_TEST_STALL_MS` are
native-test fault-injection controls; production launchers must leave them
unset. This is a helper-only facility and does not require a Main or Quartus
build.

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

The v0.9.0 candidate's existing timing-qualified RBF provenance, source
composition and open release gates are recorded in the
[v0.9.0 release notes](RELEASE_NOTES_v0.9.0.md). Release qualification requires
a clean tracked-source export, wiped generated/dependency directories, a fresh
Quartus build, fresh ARM/Main/visualizer artifacts, checksum comparison and a
final hardware pass. Reproducing a binary does not itself constitute a new
hardware run.

## Known presentation limitation

A hardware-screenshot comparison found a blended pixel column at sharp colour transitions that the independent decoder did not produce. Chroma upsampling is a hypothesis, not a proven cause. Comprehensive playback pixel qualification remains open; distinguish this recorded observation from new corruption introduced by a candidate.
