# Shared IDCT transform service

The accepted 7eb5088 design has separate intra, P-residual and B-residual
IDCT engines. Their arithmetic already shares its two passes, and their
intermediate arrays already occupy eight M10Ks per engine. This change shares
one complete arithmetic engine across the three clients; it does not count
those earlier optimizations again or change transform precision/rounding.

The three production producers allow one outstanding block each. Intra waits
for reconstruction/DDR completion; P and B replay state machines wait for their
own transform completion before issuing the next block. The shared service
rejects a second outstanding request instead of overwriting a pending block.

An idle engine accepts coefficient strobes immediately, preserving uncontended
capture and sample cycles. Concurrent clients capture into independent 64×12
coefficient banks. A written-coefficient mask supplies zero for sparse entries
without clearing RAM. Completed buffered blocks receive round-robin service,
with pending blocks preferred over fresh arrivals. Only that block's client
receives output-valid/completion/error; completion remains asserted until the
client starts its next block. A reset invalidates every capture, pending block,
ownership and completion, and resets the arithmetic pipeline. No old result
can be delivered into the new decoder session.

Standalone transform wrappers retain the original local engine by default for
existing offline tests. Production explicitly selects external service at the
top level. No hardware telemetry is added: transaction traces require the
simulation-only H262_IDCT_TRACE define.

## Validation

- `python3 tools/verify_shared_idct.py --output results/shared-idct/unit-final`
  compares three independent original engines with the shared service: concurrent
  dense/sparse signed blocks, independent producers immediately reusing their
  own slots, single-cycle blocks, 220 reset offsets and malformed input recovery.
  The completed run compares 79,008 samples exactly.
- `python3 tools/verify_idct_storage.py --baseline 7eb5088 --output results/shared-idct/arithmetic`
  verifies unchanged arithmetic and standalone timing over 164,020 cycles,
  783 completed blocks, 52,128 samples and 133 reset offsets.
- The mixed reconstruction harness now optionally models actual intra IQ/IDCT
  demand and completion. I-picture pixels still use its initialized reference
  image; intra numerical correctness comes from the independent transform test.
  This is not a model of the complete intra DDR writer or vendor CDC.
- Use `tools/verify_decoder_timing.py --idct-intra --idct-trace` for baseline
  demand and add `--shared-idct` for shared service. The measured 288 intra,
  1,053 P and 1,418 B blocks have peak outstanding concurrency one. All 5,518
  request/completion event cycles match between dedicated and shared runs.
  This workload observation alone is not proof of mutual exclusion; the shared
  service and concurrent-producer tests handle overlapping arrivals explicitly.
- Paired EOF and 50 Hz paused/repeated seek cases use `--baseline-log` to require
  identical full reconstruction accounting and total cycle counts. Each checks
  423,936 P/B pixel samples without mismatches. The original fixed cycle budget
  applies only to the old stubbed-intra, 59.94 Hz harness. Adding real intra work
  changes that budget identically with dedicated or shared engines.
- Exact-file combined MPG replay supports `--shared-idct --idct-intra`, together
  with `--shared-ddr --display-ownership`, to check audio and post-seek video
  progress through the existing bounded simulation memory model.

The 16 MiB Pee Strike prefix (SHA-256
`04923fd8f0013879e2afddcbb792da21010db4befab68de576430ce3e2a51aea`)
passes normal opening plus a ten-second forward reconstruction seek through
shared DDR with intra demand enabled. The replay confirms post-seek audio and
video progress without underrun or timestamp warning at cycle 432,419,997;
evidence is in `results/shared-idct/pee-replay`. This is a bounded simulation,
not a full-movie or physical-hardware acceptance result.

## Resource qualification and hardware test

The structural target is one IDCT engine (eight intermediate M10Ks and eight
DSPs) plus three staging M10Ks, replacing three engines (24 intermediate M10Ks
and 24 DSPs). Expected net memory saving is 13 M10Ks and arithmetic saving is
16 DSPs. Final ALM savings depend on arbitration, coefficient masks/muxes and
placement; no fitted saving is claimed before compilation.

Timing audit must find exactly one six-bit IDCT transform index. The fitter
packaging audit must confirm eight intermediate M10Ks and three staging M10Ks,
as well as existing CDC, scene-enable and diagnostic-removal checks.

Retain hardware-accepted 7eb5088 MEDIUM seed 61. Test Fellow, Groove, Jiggler
and Star Wars at both refresh settings: startup, dense motion, audio/video
continuity, pause/resume, all seek sizes/directions, repeated seeks and reset,
file replacement, subtitles/filters and clean EOF. No change to UI is intended.
