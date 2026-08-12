# Building and Testing

## Requirements

- Intel/Altera Quartus Prime 17.0.x
- MiSTer-compatible DE10-Nano target hardware
- the repository cloned with its `sys/` framework content present

The project file is `MediaPlayer.qpf` and the active source list is maintained in `files.qip`.

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

The main diagnostic streams are stored in `tools/streams/`.

### `test_flat_gray_i.m2v`

Use this for:

- neutral grayscale decode checks;
- gross Y/Cb/Cr errors;
- color-neutrality regressions;
- stable full-frame presentation.

### `test_all_i.m2v`

Use this for:

- detailed spatial decode;
- macroblock/slice progression;
- timestamp text;
- color bars and chroma behavior;
- presentation stability.

The USER LED is currently used as a positive development diagnostic. At the Phase 1Q baseline it requires successful completion of two supported I-picture decode passes along with a healthy first-picture DDR write/read/cache presentation path and no decoder pipeline errors.

## Acceptance checklist for active RTL changes

Before considering a hardware phase complete:

1. Quartus Flow completes successfully.
2. Fitter completes successfully.
3. Standard TimeQuest setup/hold/recovery/removal results are reviewed.
4. `tools/phase1p_timing.tcl` is rerun when the architecture or placement can materially change.
5. Both primary diagnostic streams are tested on MiSTer hardware unless the change has a clearly narrower scope.
6. USER behavior is checked against the phase's intended completion condition.
7. The displayed image is checked for new flicker, corruption, color shifts, line/cache artifacts, or instability.
8. Resource growth is reviewed when a change adds meaningful logic, memory, or DSP use.

## Quartus source-file discipline

Add or remove active RTL in `files.qip` manually. Avoid adding source files through the Quartus GUI in a way that causes them to be emitted into `MediaPlayer.qsf` instead.

The active build deliberately excludes the frozen `rtl/mpeg2fpga/` reference implementation.

## Clean builds

Quartus-generated directories and reports are ignored by `.gitignore`, including `db/`, `incremental_db/`, and `output_files/`.

For suspicious incremental-build behavior, remove generated build state and perform a full compile before diagnosing RTL from stale fitter or netlist output.

## Known presentation limitation

The current video path uses nearest-neighbor 4:2:0 chroma expansion. Fine text over saturated backgrounds can therefore show warm/colored fringing. This is a known presentation-quality limitation and should be distinguished from broad decoder color corruption.
