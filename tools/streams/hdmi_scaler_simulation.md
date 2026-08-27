# HDMI scaler simulation

Run on the build PC with GHDL, Verilator, a C++ compiler and Python 3. No
Quartus build or MiSTer connection is required. On Ubuntu, `ghdl-mcode` provides
the GHDL executable. `GHDL=/path/to/ghdl-mcode` selects a private installation.

```bash
HDMI_SIM_BUILD_DIR=/tmp/hdmi-weave tools/streams/run_hdmi_scaler_sim.sh weave
HDMI_SIM_BUILD_DIR=/tmp/hdmi-bob tools/streams/run_hdmi_scaler_sim.sh bob
HDMI_SIM_BUILD_DIR=/tmp/hdmi-held tools/streams/run_hdmi_scaler_sim.sh hold
HDMI_SIM_BUILD_DIR=/tmp/hdmi-stale tools/streams/run_hdmi_scaler_sim.sh stale
```

The default is 1080p at approximately 60 Hz and 80 native input fields. Select
`HDMI_SIM_OUTPUT=720` or `480` for controls. Other cases are `progressive`,
`identical`, `bff` and `hold-bob`. `HDMI_SIM_BACKPRESSURE=1` adds periodic Avalon
wait states. `HDMI_SIM_FIELDS` controls run length; allow at least 32 fields for
steady-state checks, and at least 80 for the complete held-picture experiment.
Keep source picture identities below 112 pictures to avoid their 8-bit wrap.

## What is simulated

- The unchanged production `sys/ascal.vhd`, synthesized by GHDL with the
  production bank base/stride, 128-bit Avalon interface and eight fraction bits.
- Production raster generation, framebuffer output controls and reset-release
  synchronizer, `sync_fix`, and the scanline pipeline.
- A 60 MHz stimulus for the production four-cycle framebuffer swap reset,
  crossed from the frame window, plus the native-mode-change reset. There is
  one ready synthetic picture per frame window. This does **not** simulate the
  MPEG decoder or scheduler ownership decisions.
- Distinct source picture and field identities, plus a moving bar. RGB is
  inserted at the framebuffer output; the framebuffer's pixel-cache contents
  are not the source of the test pattern.
- Three scaler memory banks, accepted burst addressing, byte enables,
  queued read returns and optional backpressure. The model checks access bounds
  and burst consistency. Its initial contents are zero.

Red encodes source picture identity, green encodes field parity, and blue
carries spatial content. The output checker examines every active pixel's
identity range and legal colors, field population, total active pixels, and a
position-sensitive 64-bit frame fingerprint. Normal pipeline latency up to four
source pictures is allowed. Deliberately freezing a source field while the
independent source picture counter advances must be detected by the `stale`
negative control; that case passes only when stale-field errors are detected
without unrelated failures.

`hold` keeps both source fields unchanged for 23 source frame slots (about
767 ms) while picture slots and framebuffer resets continue, then resumes
motion. Settled Weave output must have one spatial fingerprint. Bob is allowed
to alternate the two intentionally different source fields.

## Reproducing the pre-fix failure

The old framebuffer forces negative-polarity native sync low during every
picture reset. This creates a false VS pulse in addition to the real pulse,
and the real scaler's field buffering retains stale or unwritten content.

```bash
git show 558efef:rtl/mpeg2_luma_framebuffer.sv > /tmp/framebuffer-before-sync-fix.sv
HDMI_SIM_FRAMEBUFFER=/tmp/framebuffer-before-sync-fix.sv \
HDMI_SIM_BUILD_DIR=/tmp/hdmi-before \
tools/streams/run_hdmi_scaler_sim.sh weave
```

This run is expected to fail the independent checker. The corrected source
must pass the same run without changing the scaler, clocks or picture source.
The focused existing cache regression also covers the failure through its
`+SYNC_RESET` case, included in `run_native_480i_timing.sh`.

## Evidence and limits

Each run retains source hashes, compiler versions, compile/synthesis logs,
per-frame measurements and the JSON verdict in its build directory. Set
`HDMI_SIM_DUMP=1` to save eight actual scaler output frames as PPM files,
starting at output frame 24. `HDMI_SIM_DUMP_START` and `HDMI_SIM_DUMP_COUNT`
select another interval. These generated files should not be committed.

The behavioral VHDL cannot run directly with range checks: intermediate
`natural` arithmetic underflows at startup. GHDL synthesis gives the finite
hardware widths, and Verilator evaluates that circuit with zero-initialized
state. No arithmetic expression in the production scaler is rewritten. This
is a synthesis-level digital simulation, not a Quartus post-fit simulation;
it does not model metastability, electrical timing or a television's processing.

The initial mode-lock interval and eight output frames after each detected
input-format change are reported but excluded from steady-state acceptance.
Passing therefore does not claim a clean startup image. The model uses nearest
interpolation, triple buffering, no scanline effect and no low-lag/VRR tuning.
Hardware timing closure and real HDMI playback remain separate acceptance gates.

## Entry 552 results

At 1080p, a paired 48-field run produced 76 input sync pulses for 51 source
fields before the correction, versus 51 for 51 afterward (the simulation
continues briefly after the requested field count). All 37 checked frames
failed before and passed afterward. The oldest retained identity was 22
pictures old before, and at most two pictures old after.

Bob, progressive, identical fields, a 23-slot intentional hold, and BFF with
memory stalls pass. The deliberately stale source field remains detectable.
The settled held-picture Weave interval has one spatial fingerprint across
40 output frames, then normal motion resumes.

An early memory model allocated only 2 MiB of payload per 8 MiB bank. BFF's
startup mode detection exposed that shortcut; the final model allocates all
three complete 8 MiB banks. Paired 32-field Weave runs using the final model
produce identical first 32 report rows to the earlier runs and retain the
before-fails/after-passes result. Full-allocation BFF with stalls also passes.
These tests establish a digital stale-field mechanism, not an exact replay of
the recorded 750 ms camera episode. Compact evidence is retained in
`.ai/current_results/entry552_hdmi_simulation.json`.
