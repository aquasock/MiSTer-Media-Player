# Contributing

Thanks for your interest in MiSTer Media Player.

This project is under active hardware development. Small, reviewable changes with clear hardware intent are strongly preferred over broad rewrites.

## Development principles

- Treat ITU-T H.262 / ISO/IEC 13818-2 as authoritative for MPEG-2 Video syntax and decoding behavior.
- Treat ITU-T H.222.0 / ISO/IEC 13818-1 as authoritative for systems/program-stream work.
- Keep implementation limits separate from standards requirements.
- Preserve the active clean decoder under `rtl/mpeg2_new/`.
- Do not re-enable the frozen `rtl/mpeg2fpga/` implementation unless a change specifically requires it.
- Keep clock-domain crossings explicit and intentional.
- Avoid broad timing exceptions that hide real paths.
- Prefer small hardware phases that can be synthesized, timed, and tested independently.

## Building and validation

Use Quartus Prime 17.0.x with the `MediaPlayer.qpf` project.

For meaningful RTL changes:

```bash
quartus_sh --flow compile MediaPlayer
quartus_sta -t tools/phase1p_timing.tcl
```

A pull request that changes active RTL should describe:

- what behavior changed;
- why the change is needed;
- which clock domains are affected;
- whether DDR addressing or frame ownership changed;
- Quartus compile result;
- relevant setup/recovery/hold results;
- which diagnostic streams were tested on MiSTer hardware;
- any visible regression or resource-use change.

If hardware testing was not possible, say so explicitly.

## Source organization

Add active Quartus source files to `files.qip`; do not rely on Quartus IDE project-file edits to discover new RTL automatically.

The `sys/` directory is MiSTer framework code and should be changed only when framework integration specifically requires it.

## RTL style

Follow the style of the surrounding SystemVerilog. Favor explicit state and handshakes over clever implicit behavior.

Comments should explain architectural intent, standards interpretation, CDC assumptions, temporary implementation constraints, or non-obvious arithmetic. Avoid comments that merely restate the code.

Existing comments prefixed with `kate -` mark intentional project-specific source edits or implementation boundaries. Preserve them when the reason still applies.

## Commit and pull-request scope

Keep unrelated cleanup out of functional decoder changes. When a phase changes behavior, prefer one focused commit that leaves the repository in a buildable state.

Use concise commit subjects written as commands or results, for example:

```text
Add alternate H262 frame bank
Harden framebuffer line CDC
Pipeline H262 IDCT column pass
```

## Reporting bugs

For decoder or hardware issues, include as much of the following as possible:

- MiSTer hardware configuration;
- exact commit tested;
- input stream or reproduction procedure;
- expected and observed image/USER behavior;
- Quartus Flow/Fitter/STA summaries;
- focused `tools/phase1p_timing.tcl` output when relevant;
- a photo or short capture if the failure is visual.

Do not attach copyrighted commercial media unless you have the right to redistribute it. Prefer minimal synthetic streams that reproduce the problem.
