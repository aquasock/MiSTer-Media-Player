# Standalone CD-quality FLAC playback plan

Planning only: no FLAC RTL or builds started. Baseline: hardware-accepted
b639ccc MEDIUM seed 52; timing audit db4bc3f. Free physical resources are
6,002 ALMs, 41 M10Ks and 53 DSP blocks. Preserve this RBF for regression.

## Acceptance target

Open a native `.flac` file containing 44,100 Hz, 16-bit stereo music using
stock Main and the RBF. A CD WAV encoded with ordinary FLAC settings must
reconstruct exactly the original PCM before output conversion, volume and
filters. Validate reference encoder compression levels 0 through 8 and
FFmpeg-generated files. Do not require a special encode command.

Retain Space pause and existing 10-second, 30-second and five-minute seeks
in both directions. Reuse the progress bar and three time fields. File
replacement forgets the previous session; EOF drains the last sample and
returns to startup. Video playback remains fully supported in the same RBF.
WAV support, music playlists, cover art, track selection, high-resolution
and multichannel audio are separate future scope.

## Format and implementation approach

Use [RFC 9639](https://www.rfc-editor.org/rfc/rfc9639.html) as the normative
format reference. It is not yet catalogued in `.ai/core-reference.md`; add
its controlled reference before implementing the decoder. The previously
inspected fLaCPGA repository is an architectural reference, not code to merge.

Implement STREAMINFO, frame headers and CRCs; constant, verbatim, fixed and
LPC subframes; both Rice methods and escape coding; wasted bits; and all
stereo channel assignments. Preserve the side channel's extra bit and use
proved accumulator widths. Handle fixed/variable blocking and final short
blocks. Skip large metadata by length without buffering album art.

The CD-rate streamable subset permits blocks through 4608 samples and LPC
orders through 12. These are subset limits, not full FLAC limits: full-format
blocks reach 65535 samples and LPC order 32. Plan storage/addressing for the
full CD stereo range using external DDR, then exercise both ordinary files
and valid non-subset examples. Any proposed compatibility reduction requires
an explicit scope decision before implementing it.

Use a serial prediction MAC, small history/coefficient RAM, a streaming bit
reader and backpressure throughout. Process channels sequentially, retain
reconstructed channel data in DDR and combine into stereo after validation.
Do not allocate two full stereo frames in scarce M10K memory. Keep compact
DDR burst buffers and PCM clock-crossing queues on chip. Only a CRC-validated
frame may be committed for playback. Double-buffer or queue frame ownership
so decoding can overlap playback without reusing audible data.

Before assigning scratch addresses, audit the existing DDR map and arbiters.
Music mode may reuse inactive video storage only with explicit ownership,
reset and stale-response protection; stopping a decoder does not reclaim
its instantiated FPGA logic. No additional SDRAM board is required by the
plan, and no unverified DDR address range is assumed available.

## Output-rate decision — first engineering gate

The current MP2 sink consumes 48 kHz PCM using the 24.576 MHz audio clock;
`sys/audio_out.sv` produces 48/96 kHz output. Connecting a 44.1 kHz FIFO to
that sink is insufficient. Separate exact FLAC decoding from output-rate
handling and verify both independently.

First assess native 44.1 kHz output entirely inside the RBF: audio clocking,
I2S/SPDIF declarations, HDMI transmitter configuration, clock crossings and
clean return to movie playback must agree under stock Main. Do not promise
bit-perfect HDMI merely because decoded PCM is exact.

If native output needs changes outside the approved RBF-only scope, present
that finding before selecting an alternative. The compatible alternative is
a measured polyphase FIR converter from 44.1 to 48 kHz (ratio 160/147), with
adequate accumulator precision, rounding and saturation. Include its memory
and DSP costs in the gate. It preserves pitch and duration but changes sample
values, so it cannot be advertised as bit-perfect digital output. Simple
sample repetition/dropping is not the proposed quality solution. Verify
frequency response, alias rejection, clipping, impulse response and duration
against a high-precision software reference, including 96 kHz platform mode.

## Integration

Extend the existing mounted-media slot to offer FLAC as well as MPEG-2;
identify the format from content and route bytes before MPEG demultiplexing.
Keep the separate subtitle slot for movies. Reuse the file reader and byte
offset requests, but make FLAC metadata/probes and movie ingress mutually
exclusive with acknowledged session ownership.

Use a music session controller and explicit PCM-source selection. Generalize
only the shared output FIFO/control interface that is necessary; preserve
movie PTS handling. FLAC elapsed time follows consumed source samples at
44,100 Hz, not decoded-ahead samples or video refresh. Total comes from
STREAMINFO's sample count; show unknown if zero, without a full-file scan.

Seeking uses valid SEEKTABLE entries when present, with bounded storage or
on-demand reads. Without one, probe byte offsets and verify candidate frame
headers, CRCs and sample/block numbering before choosing a preceding frame.
Decode/discard only the landing prefix, then resume at the requested sample.
Preserve pause through a seek; clamp start/end; cancel stale reads and queued
PCM on replacement or repeated seeks. Bound probe attempts and provide a
controlled failure instead of hanging or estimating a false position.

EOF is complete only after validated PCM and output-converter tail handling
finish. Truncated/corrupt files stop cleanly with a concise functional error;
do not restore persistent diagnostic overlays or hardware telemetry. CRC
checking is production integrity logic. PCM comparisons and stream MD5 checks
belong in offline validation initially; runtime whole-file MD5 is not required.

## Work and test gates

1. **Feasibility and output contract.** Confirm the DDR map, ordinary-file
   corpus, arithmetic widths and native-output feasibility; settle the output
   approach above. Synthesize representative parser/MAC/memory/output blocks
   before committing to full integration. Target at least twice real-time
   throughput for normal encoder output under representative DDR backpressure.
   Treat pathological unary streams with bounded failure handling.
2. **Standalone exact decoder.** Build metadata/bitstream parsing, prediction,
   channel reconstruction and frame commit. Compare every stereo sample and
   total length against original WAVs. Cover all implemented syntax, silence,
   impulses, ramps, noise, full-scale extremes, encoder levels, variable blocks,
   CRC errors, truncation, backpressure and cancellation. Measure fitted RAM
   shapes and logic; do not infer fit from logical bit counts alone.
3. **First integrated hardware candidate.** Add file opening, correct-rate
   continuous playback and clean EOF with the selected output path. Verify
   long music playback, channel identity, pitch/duration, silence/noise and
   filters; rerun Fellow, Groove, Jiggler and Star Wars at both refresh rates.
4. **Controls and UI candidate.** Complete pause, all seek sizes/directions,
   source-sample timestamps, progress and clean file replacement. Stress files
   with/without seek tables, missing totals, short tails and repeated rapid
   controls, then repeat all music and four-movie regression tests. Qualify
   all timing corners and physical resources before release.

Internal simulations need not become separate user-facing builds. Use one
hardware candidate per meaningful gate; select seed/build count when starting
that gate rather than launching builds during planning.

## Resource targets and stop conditions

Initial design budgets, **not measured estimates**: at most 3,500 additional
placed ALMs, 28 additional M10Ks and 12 additional DSP blocks for the complete
music path including output conversion and integration. That would preserve
at least 2,502 ALMs, 13 M10Ks and 41 DSPs relative to today's placement; actual
whole-core placement may differ. Prefer existing mutually exclusive buffers
where ownership can be proved, but account for any changed port requirements.

Revisit architecture before full integration if synthesis exceeds these
budgets, regular files cannot sustain playback, or stock-Main-compatible
output cannot meet the agreed quality requirement. The first task after plan
approval is feasibility/output qualification, not a full three-seed build.
