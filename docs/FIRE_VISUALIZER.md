# Native audio visualizers

Stock Main exposes **Visualizers:** during native audio playback. The submenu's
Type row selects **Waveforms** (the mirrored stereo ribbons, default), **FFT**
(the separate yellow spectrum blocks with orange caps), or **O-Scope** (stereo XY). The page is hidden while video is loaded and at idle. Selection persists
across file changes, and video rendering is independent of the selected mode.

All three displays observe the existing post-volume native PCM tap. They have no audio
ready output, never access stream DDR, and cannot delay decoded audio. They render
inside the selected aspect rectangle, before the existing progress UI and OSD.
All renderer paths have nine pixel-clock stages; mode changes publish at vertical
sync. The waveform implementation itself is unchanged.

## FFT analysis

The original FFT uses 256 native stereo sample pairs, a symmetric Hann window and
an iterative radix-2 DIT butterfly. It stores L+jR in one complex transform, then
combines absolute real/imaginary components of mirrored bins for stereo energy.
This avoids cancellation of opposite-phase channels. Each stage divides by two;
Q15 coefficients and truncation are checked exactly against a software model.
The displayed magnitude is an approximation, not a calibrated power spectrum.

The 32 bands have fine spacing at the low end and progressively wider spacing
at higher frequencies. At 44.1 kHz, bins are approximately 172.3 Hz apart. DC and
the Nyquist bin are excluded. This first version does not resolve deep bass into
many separate bands. Logarithmic intensity drives 32 independent columns with
31 lit-height steps plus zero. Each column consists of separate rectangular
blocks, with its highest lit block solid orange and every lower block solid
yellow. There is no interpolation between bands, color blending or procedural
turbulence. Frequency increases from left to right. A remainder accumulator
spreads all 32 columns evenly across the selected viewport; integer row spacing
scales the blocks for each output resolution. The lowest block reaches the
viewport bottom, including its final pixel row; the progress UI renders above it.
The renderer uses no multipliers.

Acquisition takes about 5.8 ms. It pauses while the reusable FFT engine computes
(less than 1 ms), without pausing audio. A coalescing mailbox publishes a complete
32-band snapshot; the renderer commits its band RAM during vertical blank.
Visible response also includes frame refresh and display latency. Silence and
pause extinguish FFT after the current analysis window; media replacement clears
the analysis state. No randomized data is added to the FFT signal itself.

## Reproducible checks

- `python3 tools/make_fire_tables.py --check`
- `python3 tools/verify_fire_fft.py --output results/fire/fft`
- `python3 tools/verify_fire_visualizers.py --output results/fire/render`

The FFT test compares all 256 complex bins and all 32 displayed levels for silence,
DC, low/mid/high tones, one-sided stereo, opposite-phase stereo and deterministic
noise. The full renderer test checks Waveforms pixel equivalence, no flames during
silence, full HDMI timing, aspect clipping, UI placement and exact movie bypass
at 480p, 720p and 1080p. PNG previews come from RTL simulation, not artwork.

## Standalone resource check

The original continuous-flame O-scope/FFT/Fire block fitted standalone at 1,216 estimated ALMs
(1,381 placed), 2,517 registers, six M10Ks and twelve DSP blocks. Compared with
the earlier standalone O-scope estimate of 541 ALMs, two M10Ks and four DSPs,
this suggests approximately 675 extra estimated ALMs, four M10Ks and eight DSPs.
Full-core placement can differ; the next three-seed batch determines actual
resource use and timing. Short video-delay pipelines explicitly stay in registers
to avoid wasting whole RAM blocks on tiny shift registers.

### Quantized-block comparison

With identical standalone project settings, the new renderer uses about 210
estimated ALMs versus 305 previously, 528 registers versus 846, one M10K in
both versions, and zero DSPs versus two. Both complete visualizers together
use 1,129 estimated ALMs (1,268 placed), 2,177 registers, seven M10Ks and ten
DSPs versus 1,216 estimated ALMs (1,381 placed), 2,517 registers, six M10Ks and
twelve DSPs before. The extra M10K is Quartus inferring a short `ypos` shift
register in the unchanged O-scope as RAM in this fit; Fire itself retains one
M10K and stores 160 bits instead of 512. These are standalone comparisons;
full-core packing and RAM inference may differ.

The block-render regression additionally checks that every nonempty band has
exactly one orange cap above yellow blocks, plus a thin solid red peak marker without blending.

## O-Scope XY phosphor

Left-channel amplitude sets horizontal position; right-channel amplitude sets
vertical position (positive upwards). A centered square inside the selected
aspect viewport displays a 128 by 128 intensity map. Connected sample traces
use integer Bresenham line drawing and sixteen green phosphor intensity levels.
An idle-port sweep subtracts one intensity level per frame, yielding roughly a
quarter-second trail at 60 Hz. A stationary signal produces a stationary spot;
unrelated stereo channels produce a cloud, while correlated channels produce
lines or loops. This is a stereo vectorscope, not an FFT or time-domain ribbon.

A coherent sample/toggle mailbox crosses from the native PCM clock to video.
If rendering falls behind, the newest pending point replaces the old pending
point; audio is never held. The map uses dual-port M10K RAM, one port for drawing,
clearing and fading and the other for display. Mode entry clears the previous
trace. Rendering and mode selection retain nine pixel stages. The palette is
black to bright green, with a small red/blue component at the brightest levels.
No new external DDR access, PLL or audio processing is introduced.

`tools/test_media_xy_visualizer.sv` compares line endpoints and all line
orientations with an independent integer reference and checks every decay level
and memory clearing. `tools/verify_fire_visualizers.py` runs that bench together
with full-frame waveform/FFT/XY and movie-bypass checks and exports PNG previews.

### FFT peak-hold markers

Each band has a thin red horizontal marker, as tall as the vertical block gap
(minimum one pixel). It rises immediately to a new peak, holds for 30 video
frames, then falls one block every four frames. At 59.94 Hz this is about a
half-second hold and a two-second full-height fall. The live orange/yellow
blocks remain independent beneath it. A short inactive pulse clears retained
peaks on the next frame so file replacement does not inherit the old album.

Peak height and age share the existing band M10K with the live level: 32 by
16 bits instead of 32 by 5 bits. A two-cycle blanking pass reads and updates
one band at a time. No new multiplier or RAM block is needed for peak tracking.
`tools/test_media_fft_peaks.sv` checks all bands, attack, exact hold/decay cadence,
silence and clearing; the render regression checks cap thickness and placement.

### Three-mode resource estimate

Standalone fitting of all three modes uses 1,440 estimated ALMs (1,613
placed), 2,511 registers, 99,924 memory data bits, 15 M10Ks and ten DSPs.
Against the previous two-mode block renderer, the combined change adds
311 estimated ALMs (345 placed), eight M10Ks and no DSPs. The red peak
markers alone add 29 estimated ALMs (38 placed), 22 registers and 352
data bits inside the existing band RAM. These are standalone deltas;
the full-core build determines final packing and timing.
