# FLAC feasibility and simulation evidence

Baseline is hardware-accepted b639ccc MEDIUM seed 52. The user requires native
44.1 kHz FLAC and existing 48 kHz MP2 movie input, using stock Main. The
inherited 96 kHz output option is not 96 kHz media decoding and is not removed.
No resampler is planned. Production RTL/file lists have not been changed by
these isolated probes; no new playable FLAC RBF is available yet.

## Arithmetic primitive

`rtl/audio/flac/flac_predict_mac.sv` accumulates streamed history/coefficient
pairs using one multiplier. It supports order 0–32, signed 17-bit history,
signed 16-bit coefficients, nonnegative prediction shift, signed 32-bit
residual and 40-bit accumulation. It checks final signed 16/17-bit range.
A 17-bit history sample times a 16-bit coefficient needs at most 33 bits;
32 taps need at most 38, so 40 leaves headroom. Format-level coefficient and
residual restrictions remain the future parser's responsibility. Valid
responses hold under backpressure; reset cancels partial reconstruction.

`python3 tools/verify_flac_predict.py --output results/flac/predict`
passes 4097 vectors against independent Python integer arithmetic, with
stalled taps/results and 33 reset cancellation points. Verilator lint passes.
This does not yet exercise FLAC bitstream parsing or complete decoded files.

`python3 tools/synth_flac_predict.py --output results/flac/predict-fit`
fitted 150 placed ALMs, 192 estimated ALMs, 106 registers, one DSP and zero
M10Ks on 5CSEBA6U23I7. This uses virtual data/clock ports: the clock virtual-pin
warning means this is an arithmetic area probe, not a production timing
qualification. Whole-core integration can change placement and counts.
A worst-order sample requires 32 accepted taps plus control cycles; memory
service and bit decoding still require separate throughput measurement.

## Deterministic corpus

`python3 tools/make_flac_tests.py --output results/flac/corpus --flac /path/to/flac`
generates silence, full-scale extremes, ramps, two independent tones and seeded
noise. Each source has 70003 stereo samples to exercise non-full final blocks.
There are 55 exact PCM pairs: reference encoder levels 0–8, large blocks up to
65535 with order-32 allowed, and FFmpeg encoding. Two damaged streams are
confirmed rejected by the reference decoder. Generated binaries stay local;
manifest.json records settings, tool versions, expected PCM and file hashes.
Encoder options permit features but do not prove every syntax variant was
actually emitted; handcrafted syntax vectors remain required.

Reference flac 1.5.0 reproduces all originals exactly. The local FFmpeg
build returned empty output, despite exit zero, for the noise stream
with 65535-sample blocks. The reference decoder reproduces that same file
exactly. The manifest records secondary-decoder agreement separately;
ordinary-block mismatches remain fatal. FFmpeg-created streams are checked
with the independent reference decoder. These are corpus checks, not an
FPGA decoder PASS.

## Native clock and HDMI path

Source inspection: sys/audio_out.sv uses 24.576 MHz to produce 48/96 kHz;
sys/pll_audio/pll_audio_0002.v defines the PLL; sys/sys_top.v exposes the HPS
I2C peripheral directly at HDMI_I2C_SCL/SDA. Upstream stock Main video.cpp,
inspected during this work, programs 0x15 with 48/96 kHz channel status and
N=6144/12288. It selects automatic CTS with 0x0A[7]=0, so the written manual
CTS registers do not determine clock regeneration in that mode.

The [ADV7513 Programming Guide, Rev B](https://www.analog.com/media/en/technical-documentation/user-guides/adv7513_programming_guide.pdf),
sections 4.4.2–4.4.3, specifies automatic CTS from actual audio/video clocks,
N=6272 for non-coherent 44.1 kHz sources, and channel status rate in 0x15[7:4].
Thus the transmitter supports native CD audio. Merely changing the serializer
clock leaves inconsistent channel status and is insufficient qualification.

Candidate architecture: retain the movie PLL and add a 22.5792 MHz CD PLL
(one of the three currently free PLLs), divide by 512 for CD sample timing,
and switch the serializer source only while muted/reset with acknowledged
configuration. Do not re-clock movie PTS/STC logic. Test PLL lock loss, rapid
file switching, both 96k settings and rate-correct FIFO consumption. Hardware
must confirm lock stability, output clock quality and receiver acceptance.

`tools/synth_flac_clock.py` builds an isolated dual-PLL probe from the existing
platform PLL template. It establishes whether Quartus can place both requested
frequencies on this device. It passes with two PLLs, 18 registers, zero RAM
and zero DSPs; the fitter reports 24.576 MHz and 22.579199 MHz (displayed
rounding versus the requested 22.579200 MHz). It does not establish compatibility with current
whole-core PLL locations or implement a glitch-free output switch.

The remaining HDMI control task is a serialized FPGA/HPS I2C owner or proxy
that preserves Main's ordinary video/EDID traffic, applies native audio
register changes, and handles Main rewriting audio setup after reconnects.
Preserve unrelated register bits and restore Main's requested 48/96 kHz on
exit from music. The bridge needs independent tests of ACK/NACK, reads,
repeated starts, clock stretching, resets and concurrent requests before
production integration. A second unsynchronized I2C writer is not acceptable.
Native HDMI operation is not yet demonstrated; this is the open feasibility
gate, not a claim that stock Main must be replaced.

## DDR capacity and ownership

Production decoder addresses are 64-bit words. Frame/scratch storage begins
at 0x06000000 (byte 0x30000000) with five 0x10000-word regions through
0x0604ffff. The compressed-video FIFO starts at 0x06080000 with 2^20 words,
ending at 0x0617ffff. These are existing core-managed allocations.

A proposed music layout reuses only the inactive compressed-video FIFO
region: two frame banks, each 65536 words, with two signed 32-bit channel
slots per word. That holds the full 65535-sample stereo block including its
17-bit coded side channel, within 1 MiB total. Small on-chip burst buffers
provide streaming access. This is a proposed reuse of reserved memory, not
a new claim on HPS memory or a need for extra SDRAM hardware.

Before music access is enabled, stop MPEG ingress/FIFO traffic, drain all
accepted DDR requests, invalidate old queue ownership and hide movie pixels.
The display and prediction clients must remain disabled until their own
fresh movie session starts. Reset/cancel must not reassign an outstanding
read response. CRC-validated frame banks become visible to PCM output only
after commit; a bank cannot be reused while audio still owns it. These
ownership rules are not implemented or simulated by the arithmetic probe.

## Shared PCM and bus-ownership prototypes

`media_pcm_sink` is a format-independent PCM consumer for FLAC and later
44.1 kHz PCM WAV. Its simulation passes 202 exact sample transfers with
startup prefill, pause, EOF interval accounting, empty-file completion,
starvation, restart at a sample offset and cancellation. It consumes only
serializer fetch ticks and needs no FLAC fields. Its clock, CDC FIFO, format
parser and native serializer integration remain separate work. See
[PCM_PLAYBACK_CONTRACT.md](PCM_PLAYBACK_CONTRACT.md).

`hdmi_i2c_owner` prototypes exclusive pin ownership. It observes START/STOP,
requires bus-free time before granting, routes slave ACK/stretching to HPS
normally, and isolates HPS drivers while local control holds the bus. HPS
sees SCL low while isolated. Simulated active and repeated-START transfers,
ACK, clock stretching, local ownership, STOP release and reset pass.
This is not a transaction writer, register shadow/replay controller, or model
of the Cyclone V HPS controller. Its real bus-busy and timeout behavior is an
explicit integration gate. Release/cancellation of a local transaction must
complete STOP before returning ownership; resetting mid-transaction requires
bus recovery at the integration layer. Neither prototype is in files.qip.

Reproduce with:

```sh
python3 tools/verify_media_pcm_sink.py --output results/flac/pcm-sink
python3 tools/verify_hdmi_i2c_owner.py --output results/flac/i2c-owner
```

## Streamed subframe decoder

`rtl/audio/flac/flac_subframe.sv` now parses subframe bits and reconstructs
coded 16/17-bit channel samples. It implements constant/verbatim coding,
fixed prediction orders 0–4, LPC orders 1–32, wasted bits, both Rice parameter
widths, partition validation, zero-width escaped partitions, signed residual
reconstruction and output range checks. It uses the existing prediction MAC,
with synchronous coefficient and history M10Ks and no full-frame on-chip array.

The initial synthetic suite passes 83 cases and 77498 provisional transfers,
including malformed type/wasted/shift/truncated streams. The first-frame
corpus run passes 193 cases and 1059248 provisional transfers across all
55 reference/FFmpeg files. The offline oracle parses framing and CRCs,
reconstructs stereo and checks it against original PCM before providing coded
channel expectations to RTL. Tests compare output sample order and exact
consumed bit count under input/output stalls. Outer headers, stereo joining,
frame CRC commit and DDR output are still software/model responsibilities;
these results do not yet constitute a complete FPGA FLAC decoder.

An isolated Quartus subframe fit, **including** its prediction MAC, uses
1160 placed ALMs, 1154 estimated ALMs, 396 registers, two M10Ks and one DSP.
The two inferred M10Ks hold 32x16 coefficients and 32x17 sample history.
Do not add the earlier standalone MAC figure again. As with that probe,
virtual ports make this area evidence rather than whole-core timing closure.

Reproduce with:

```sh
python3 tools/verify_flac_subframe.py --output results/flac/subframe
python3 tools/verify_flac_subframe.py --output results/flac/subframe-corpus --corpus results/flac/corpus --verilator
python3 tools/verify_flac_subframe.py --output results/flac/subframe-full-corpus --corpus results/flac/corpus --frames-per-file 0 --verilator
python3 tools/synth_flac_predict.py --output results/flac/subframe-fit --top flac_subframe
```

The full-corpus mode also compares final short blocks and complete decoded
lengths with original PCM. Reset/replay injection restarts selected subframes
midstream to detect stale predictor/history state. Malformed syntax is rejected;
CRC admission and a system-level work watchdog remain outer-frame concerns.

Full-corpus result: 3173 cases pass, with 7964966 provisional transfers
(including replayed prefixes) and 3160 reset/replays. All frames of all 55
files, their exact original PCM lengths and their final short subframes are
checked. The RTL receives real subframe bits; headers, CRC validation and
stereo recombination are still checked by the offline oracle. No production
file support is implied. Strict Verilator RTL lint passes with intentional
unconnected status-port warnings excluded.

## Complete native framing prototype

`flac_stream_decoder` now performs native metadata and frame parsing around
`flac_subframe`, including header CRC-8, frame CRC-16, canonical frame/sample
numbers, contiguous positioning and total-length checks. Coded samples remain
provisional until frame commit. `flac_stereo` reconstructs all four stereo
assignments with signed overflow rejection. The ownership interface is defined
in [FLAC_FRAME_CONTRACT.md](FLAC_FRAME_CONTRACT.md).

The complete-file suite compares every admitted left/right sample directly
with the original PCM from all 55 corpus files. It additionally constructs
fixed/variable frames for each stereo mode with explicit/inherited 44.1 kHz
rates, signed extremes and unknown totals. Stalls and midstream reset/replay
exercise the byte, sample and frame ownership interfaces. Bad CRCs, bad
numbering, unsupported profiles, truncated input and store faults are rejected.

Reproduce with:

```sh
python3 tools/verify_flac_stream.py --output results/flac/stream --corpus results/flac/corpus
python3 tools/synth_flac_predict.py --output results/flac/stream-fit --top flac_stream_decoder
```

The modeled frame store is testbench memory, not synthesized on-chip storage.
No DDR adapter or native HDMI output is implied by these complete-file tests.
The decoder does not check STREAMINFO MD5. Production movie RTL and the
accepted b639ccc hardware candidate remain unchanged.

The completed suite passes **73 cases**: 55 full corpus files, eight
constructed stereo/numbering streams and ten fault cases. The 63 valid
streams compare **3,890,965 stereo sample pairs** (7,781,930 individual
samples), excluding replayed prefixes. Every valid stream exercises reset
and replay. No bad first frame is committed after CRC or store failure;
a damaged final frame preserves only the earlier valid prefix.

The isolated framing/subframe/MAC fit uses **1,746 placed ALMs**, 1,753
estimated ALMs, 859 registers, **two M10Ks and one DSP**. These figures include
the previous subframe and MAC resources; do not add them again. The separate
stereo combinational unit, DDR transport, PCM buffering, clock handoff and
HDMI control are outside this fit. Virtual I/O fitting is area evidence, not
integrated timing closure. RTL lint is clean with the intentional unconnected
MAC status port excluded.
