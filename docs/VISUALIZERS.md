# Audio visualizers

Three visual modes, selected by `PLAYER_VISUALIZER` (`status[123:122]`, a
2-bit OSD field: 0=Waveforms, 1=FFT, 2=O-Scope/XY; value 3 is unused and falls
back to Waveforms).

A naming note for anyone reading the source: the module behind the "FFT"
mode's on-screen rendering is still named `media_fire_renderer` (instance
`fire` in its parent). That's a historical name, not a current description —
the mode was originally called "Fire" and rendered as a continuous animated
flame gradient, but a later commit replaced the visual with hard-edged bar
blocks, and another renamed it to "FFT" in the OSD and project terminology
alongside introducing the O-Scope/XY mode. The module was never renamed to
match. This document uses "FFT," the current name, throughout; treat
`media_fire_renderer`/`fire` as that same thing when reading source.

All three renderer modules (`media_waveform_visualizer`, `media_fire_renderer`,
`media_xy_visualizer`) run in parallel, continuously, on the same shared,
read-only PCM tap — not just the one currently selected. `media_audio_visualizers`
just multiplexes whichever one's pixel stream reaches the output. This matters
because **Waveforms and FFT keep updating their internal history/band state
in the background even when not selected**, so switching to them shows an
already-populated display immediately. **O-Scope/XY is the exception**: its
`active` input is specifically gated by `frame_mode==2` (the selected mode),
so it clears to blank whenever it isn't the active mode and always starts
fresh when you switch to it.

Mode switches are latched at vsync (`frame_mode<=mode` on the `vs&&!vs_d`
edge) and pushed through an 18-stage pipeline register before the final mux,
so the selected pixel stream stays aligned with the fixed rendering latency
of all three paths (each renderer independently pads itself to a matching
pipeline depth — both FFT and O-Scope/XY are explicitly commented as
"nine-cycle" renderers).

---

## Waveforms

A dual-trace oscilloscope-style scope (module `media_waveform_visualizer`),
read-only and post-volume (it taps PCM after volume/mixing, and never applies
backpressure to playback).

- Every 4 audio samples are summed and stored as one history point — 256
  history points span 23.2 ms of audio at 44.1 kHz, i.e. roughly one sweep
  window per frame.
- Two RAM buffers: a live `history` array that's continuously written, and a
  `frame_history` snapshot copied from it during vertical blank. The display
  only ever reads the snapshot, so the on-screen trace can't tear mid-scan
  while new audio is still arriving.
- Left and right channels render as two independently interpolated line
  traces (teal-ish for left, orange/red for right), with glow thickness that
  scales with output resolution (1px under 600 lines, 2px under 900, 3px at
  900+).
- The horizontal mapping from a fixed 256-point history buffer to the actual
  active video width uses a small custom serial (16-cycle) divider that runs
  once per resolution change, not per pixel — keeping the real-time pixel
  path free of division.

## FFT

The display module (`media_fire_renderer`, see the naming note above) is fed
by a separate analysis module (`media_audio_fft`).

**Analysis stage** — a fully serial, iterative 256-point radix-2 decimation-in-time
FFT (one butterfly per several clock cycles through an explicit state
machine), not a parallel/pipelined core:

- Input samples are Hann-windowed (window coefficients loaded from a
  precomputed ROM at elaboration time, not computed at runtime) before the
  transform.
- Left and right channels are packed into a single complex FFT pass as
  `{L, jR}` — the standard real-signal-pair trick — and separated back out
  during magnitude computation by reading mirrored bin pairs together.
  Twiddle factors likewise come from a precomputed ROM.
- After the transform, magnitudes are log-scaled by a custom integer
  `logarithm()` function (leading-one detection, not a real log), then
  grouped into 32 log-spaced bands using a precomputed per-band bin-count
  table. Each band's top 5 bits become its displayed level. This runs
  continuously once per frame's worth of captured samples, regardless of
  which visualizer mode is selected.

**Display stage** — takes those 32 band levels and draws hard-edged blocks,
explicitly *not* interpolated or color-blended between bands (stated design
intent in the module's header comment, the opposite choice from Waveforms):

- Each band is a vertical stack of yellow blocks up to its current level,
  with an orange cap block at the top of the lit stack.
- A separate red peak-hold marker sits above the lit stack per band, decaying
  by one block every 4 video frames after holding for about half a second (a
  30-frame age counter).
- The 32-column horizontal layout is computed from a running remainder
  accumulator rather than a per-pixel divider; row geometry (grid top/pitch)
  is derived from the current resolution once per frame during blanking.

## XY-Scope

A green-phosphor-style stereo vectorscope (module `media_xy_visualizer`),
plotting left/right sample pairs against each other rather than against time.

Because it plots left-vs-right rather than amplitude-vs-time, this mode is
compatible with dedicated "oscilloscope music" — tracks composed so the
stereo channels, read as X/Y coordinates, draw a deliberate picture or shape
on a vectorscope rather than arbitrary noise (the project's own N-SPHERES
FLAC test track is exactly this kind of material, and has been used as
hardware-playback evidence in prior builds). Ordinary stereo music will still
draw *something* — the visualizer has no concept of "intentional" input — but
the recognizable-shape effect is specific to audio actually authored for
X/Y display.

- Each audio sample becomes one (x, y) point: X from the left channel, Y from
  the *inverted* right channel (both offset to unsigned via XOR 0x80).
  Consecutive points are connected with an integer Bresenham line-drawing
  state machine (explicit `error`/`dx`/`dy`/`step_x`/`step_y` registers) —
  this is real line rasterization, not just plotted dots.
- The drawing grid is 256×256 with **8 phosphor intensity levels**, stored as
  three separate 1-bit-per-pixel RAM planes (`phosphor0/1/2`) rather than one
  3-bit plane — chosen specifically so each plane packs into its own
  8192×1 M10K block (24 M10K blocks total for the three planes combined).
- Every video frame, a sweep pass walks the entire 65,536-address space and
  decrements every pixel's phosphor level by one step (floor at 0), producing
  the trailing decay/afterglow effect; freshly drawn points are written at
  the maximum level (7).
- The drawing area is always cropped to a square region centered in the
  active video (`side = min(width, height)`) regardless of the display's
  actual aspect ratio, so the scope renders as a true square on both 4:3 and
  16:9 output.
- Audio is a strictly observation-only tap, synchronized into the video clock
  domain via a single-bit toggle handoff (`sample_toggle`) rather than a
  FIFO — "the latest sample wins" if the renderer ever falls behind, per the
  module's own comment; it never stalls playback.
- As noted above, this is the one renderer actually gated by mode selection
  (`active` tied to `frame_mode==2`), so it always starts from a cleared
  screen when you switch to it, rather than showing stale trace data.
