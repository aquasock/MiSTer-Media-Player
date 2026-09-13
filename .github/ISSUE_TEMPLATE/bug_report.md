---
name: Bug report
about: Report a reproducible decoder, build, timing, or hardware issue
title: ""
labels: bug
assignees: ""
---

## Summary

Describe the problem clearly.

## Commit tested

Provide the exact commit SHA.

## Hardware / environment

- MiSTer / DE10-Nano configuration:
- Quartus version:
- Relevant peripherals or storage path:

## Input / reproduction

Describe the stream or steps needed to reproduce the issue. Prefer a small redistributable diagnostic stream when possible.

## Expected behavior

What should happen?

## Observed behavior

What actually happens?

## Build and timing evidence

Include relevant Quartus Flow/Fitter/STA results and `tools/phase1p_timing.tcl` output when applicable.

## Hardware evidence

State which test streams were tried, USER LED behavior, and whether the image is stable. Attach a photo/capture when useful.

## Additional notes

Include any suspected clock-domain, DDR, parser, arithmetic, or presentation relationship.
