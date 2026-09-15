# Native audio visualizers

Stock Main exposes **Visualizers:** during native audio playback. The submenu's
Type row selects **O-scope** (the existing mirrored stereo ribbons, default) or
**Fire**. The page is hidden while video is loaded and at idle. Selection persists
across file changes, and video rendering is independent of the selected mode.

Both displays observe the existing post-volume native PCM tap. They have no audio
ready output, never access stream DDR, and cannot delay decoded audio. They render
inside the selected aspect rectangle, before the existing progress UI and OSD.
Both renderer paths have nine pixel-clock stages; mode changes publish at vertical
sync. The waveform implementation itself is unchanged.

## Fire analysis

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
scales the blocks for each output resolution. The renderer uses no multipliers.

Acquisition takes about 5.8 ms. It pauses while the reusable FFT engine computes
(less than 1 ms), without pausing audio. A coalescing mailbox publishes a complete
32-band snapshot; the renderer commits its band RAM during vertical blank.
Visible response also includes frame refresh and display latency. Silence and
pause extinguish Fire after the current analysis window; media replacement clears
the analysis state. No randomized data is added to the FFT signal itself.

## Reproducible checks

- `python3 tools/make_fire_tables.py --check`
- `python3 tools/verify_fire_fft.py --output results/fire/fft`
- `python3 tools/verify_fire_visualizers.py --output results/fire/render`

The FFT test compares all 256 complex bins and all 32 displayed levels for silence,
DC, low/mid/high tones, one-sided stereo, opposite-phase stereo and deterministic
noise. The full renderer test checks O-scope pixel equivalence, no flames during
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
exactly one orange cap above yellow blocks, with no other colors or blending.
