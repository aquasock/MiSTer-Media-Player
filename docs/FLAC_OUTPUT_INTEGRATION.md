# FLAC memory and native-output integration boundary

The decoder now connects to a real RTL external-frame-store controller through
`flac_ddr_decoder`. Native digital serialization and the HDMI control hierarchy
are implemented and tested separately. These blocks are not yet wired into
`files.qip`, the mounted-file router or `sys_top`; there is no new playable
FLAC RBF from this development cycle.

## External frame storage

`flac_frame_store` reserves two 65,536-word banks beginning at 64-bit word
address `0x06080000`: byte addresses `0x30400000..0x304fffff`, exactly 1 MiB.
This is inside the existing compressed-video FIFO region, so production must
assign that region exclusively to music after the movie clients have drained.
It does not require a larger SDRAM board or a full frame in M10K memory.

Each word holds signed coded channel zero in its low 32-bit lane and channel
one in its high lane. Both carry a sign-extended 17-bit sample. Sequential
channel writes use byte enables `0x0f` and `0xf0`; no read-modify-write is
needed. A CRC-admitted frame becomes readable only after the final write is
accepted. Reading combines both lanes through `flac_stereo`; canonical sign
extension and stereo output range are checked before producing PCM.

The two banks alternate in decode and playback order. A committed bank cannot
be overwritten and is not released until its last PCM token is accepted.
Backpressure stops parsing when both banks are owned. No audio from a
provisional frame is exposed. EOF is a separate token after all committed
samples, using the same interface as future WAV playback.

`mem_read`/`mem_write`, address, data and byte enables remain held across busy.
A read may return with acceptance or later; only one read is outstanding.
`cancel` invalidates audio ownership but retains a held bus command and drains
any accepted response before `start_ready`/`quiescent`. Do not block that
pending transaction with an outer quiesce gate: it would prevent cancellation
from completing. Switch bus ownership only after both old and new clients are
quiescent. Ordinary file replacement uses cancellation, not an immediate
reset of this memory client. Global reset requires resetting the memory port
or otherwise proving all old responses retired.

A new start resets the outer decoder even after clean EOF. The surrounding
controller must flush the PCM CDC FIFO too: store quiescence does not imply
that downstream queued audio has finished playing. Decoder errors are terminal
until cancellation/restart; session control must turn them into a clean stop.

## Native digital output

`media_pcm_i2s` consumes the shared PCM tokens in a clock domain running at
512 times the source sample rate. At 22.5792 MHz it transmits native 44.1 kHz,
16-bit stereo I2S. It fetches from `media_pcm_sink`, waits a clock for the
sample update, and then serializes it with the standard one-bit LRCLK delay.
Pause is latched at a frame boundary. EOF completion waits until the final
right-channel LSB has been sampled, before permitting an output handoff.

This module is the exact, unfiltered digital boundary. It does not implement
volume/filter routing, analog output, SPDIF, a clock-crossing FIFO, or file
selection. Production integration must preserve movie audio/filter behavior
and explicitly connect the intended music output path. It must not substitute
44.1-to-48 kHz conversion. The shared PCM contract still supports later WAV.

`media_audio_clocks` adds the 22.5792 MHz PLL and uses the vendor glitch-free
clock selector. Cyclone V requires PLL outputs on selector inputs 2 and 3;
inputs 0 and 1 are clock-pin inputs. The existing movie clock remains running
and continues to clock movie timing and STC. The isolated clock probe includes
the existing movie PLL plus the new CD PLL: two PLLs total in that probe,
only one additional PLL relative to the current core.

## HDMI ownership and rate changes

`media_hdmi_audio_control` connects four functions:

- `hdmi_i2c_owner` preserves HPS access normally and grants an exclusive local
  lease only after STOP and bus-free time. HPS sees a busy bus during the lease.
- `hdmi_i2c_write_watch` detects acknowledged HPS register writes to ADV7513.
  Reads, pointer-only writes, NACKed writes and local transactions do not
  retrigger native setup.
- `hdmi_audio_config` reads, modifies, writes and verifies five registers:
  automatic CTS at `0x0a`, sampling-rate status at `0x15`, and N at `0x01..03`.
  It preserves unrelated fields and uses N=6272 for CD, 6144 for movie 48 kHz,
  and 12288 for the inherited 96 kHz output setting. It rejects a different
  audio input selection instead of overwriting it.
- `media_audio_rate_control` mutes, waits for the PCM drain acknowledgement,
  selects the clock, waits for a matching clock-ready acknowledgement, then
  waits for HPS activity to settle before configuration. A target change during
  a transaction cannot release output using a stale success. Failures remain
  muted; returning to movie mode or a later HPS write permits retry.

The generic I2C register master handles ACK/NACK, repeated START for reads,
clock stretching and readback. A clock timeout records failure and waits for
SCL to recover before generating a real STOP. Simply releasing both wires
would leave the ownership gate tracking an unfinished transaction. If the
physical bus never recovers, ownership remains held; do not declare success
or hand it to another master. Do not reset this controller on ordinary file
changes: finish its transaction and then restore the requested movie mode.

The caller must supply real, synchronized `clients_idle`, `clock_ready` and
`clock_applied_cd` acknowledgements. Tying these high is only a component-test
abstraction. The production clock/serializer/FIFO handoff must generate them.

The bit-level device model demonstrates native entry, Main rewriting the
48 kHz register during music, automatic native reapplication, return to 48/96,
and failure recovery. It does not model Linux's actual HPS I2C driver timeout
policy or an HDMI receiver. Those remain hardware acceptance requirements.

## Evidence and reproduction

```sh
python3 tools/verify_flac_ddr.py --output results/flac/ddr --corpus results/flac/corpus
python3 tools/verify_native_audio.py --output results/flac/native-audio
python3 tools/synth_flac_predict.py --top flac_ddr_decoder --output results/flac/ddr-fit
python3 tools/synth_flac_predict.py --top media_hdmi_audio_control --output results/flac/hdmi-control-fit
python3 tools/synth_flac_predict.py --top media_pcm_i2s --output results/flac/native-i2s-fit
python3 tools/synth_flac_clock.py --switch-output --output results/flac/clock-switch-fit
```

The DDR suite compares all 55 complete corpus files with original PCM through
stalled writes and delayed reads. Directed tests cover cancellation during a
held write, held read, response wait, pending PCM and response delivery; a
zero-latency read; shared-sink sample position/EOF; and frame CRC rejection.
At an assumed 60 MHz, the slowest ordinary corpus case runs about 14.5 times
real time under this memory model. That excludes host I/O and production CDC
and is not a measured hardware throughput guarantee.

The native-output suite compares 1,024 stereo samples decoded from the serial
wire, checks 512-clock sample cadence, pause and final-bit drain. It tests the
individual I2C functions and their connected control hierarchy. Strict RTL
lint passes. Vendor PLL/selector fitting validates device feasibility;
portable serializer simulation does not validate analog clock waveforms.

| Isolated block | Placed ALMs | Registers | M10Ks | DSPs |
| --- | ---: | ---: | ---: | ---: |
| FLAC decoder, stereo and external frame controller | 1,953 | 1,032 | 2 | 1 |
| Connected HDMI control | 225 | 202 | 0 | 0 |
| Shared PCM sink and native I2S | 78 | 119 | 0 | 0 |

These fit areas sum to 2,256 ALMs before full-core integration. Do not add the
previous standalone decoder/MAC figures again. The clock probe additionally
uses two PLLs and 20 registers, with 10 estimated ALMs including its sample
clock counters. The remaining PCM CDC queue, mounted-file/session routing,
production output/filter selection and integrated placement are not included.
Virtual-I/O fits do not establish whole-core timing closure. The accepted
b639ccc seed 52 remains the hardware rollback.

## Production candidate wiring

The production mounted-file preflight recognizes `fLaC` at byte zero, cancels
and drains its head read, then starts playback from byte zero. Stock Main uses
three-character extension patterns, so the common file picker uses
`M2VMPGFL*`; decoder selection relies on content, not that wildcard.
Movie and FLAC DDR clients are mutually exclusive. The route changes only
while the session controller holds decoder reset and both clients report
quiescent. Cancelled requests and responses retain their old route until drained.

A 256-token vendor dual-clock FIFO connects the decoder's 60 MHz domain to
native 22.5792 MHz PCM/I2S. The selected output clock acknowledges actual edges
and settled mode through a mailbox. Movie I2S drains two muted frames; CD
acknowledges a silent sample boundary. The controller waits a minimum 2048
reference-clock cycles before accepting a drain acknowledgement. HPS writes
pause CD consumption until native HDMI settings are reapplied and verified.
The native SPDIF encoder advertises 44.1 kHz. EOF waits beyond the final I2S
bit for the SPDIF tail before returning the core to startup.

This first candidate includes Space pause, source-sample elapsed/total times,
volume, clean EOF and replacement. FLAC arrow-key seeking is disabled until
its separate seek gate. Music uses the native exact PCM path with volume;
movie IIR/DC/filter/mix processing remains on its unchanged 48/96 kHz platform
path. Additional music filtering is not part of this candidate. STREAMINFO
with zero total samples displays unknown total/remaining. Corrupt or unsupported
music stops and returns to startup; no diagnostic overlay is added.

Run the integration checks with:

```sh
python3 tools/verify_flac_integration.py --output results/flac/production-integration
python3 tools/verify_ui_duration.py --output results/flac/movie-duration-regression
python3 tools/verify_playback_controls.py --output results/flac/playback-regression.json
python3 tools/verify_direct_seek.py --output results/flac/movie-seek-regression
```

The integration test uses the vendor FIFO model and independent 60/20/50 MHz
and native/movie audio clocks, with a functional PLL/selector model. It checks
1024 exact I2S words and SPDIF sample captures, pause, a simulated Main register
write during playback, source position, final-sample drain and movie-rate
restoration. It does not qualify physical HPS I2C or HDMI interoperability.

The native clock monitor uses per-domain reset release. Generated clocks at
the vendor selector output are physically exclusive; the two original PLL
domains retain their existing CDC checks. The SDC requires the selector nodes
to resolve uniquely, and the post-fit audit requires both generated clocks and
all new reset/signal synchronizer stages. A preliminary map timing review found
and corrected impossible cross-mode paths before the first routed candidate.

The final clock wrapper explicitly gates output off, waits sixteen 50 MHz
cycles, selects PLL input 2 or 3, waits sixteen more cycles, then reenables
output through three-stage per-PLL enable synchronizers. The vendor automatic
switch wrapper is disabled because its internal select register powers up at
input zero; with PLLs only on 2/3 it cannot clock itself into a valid selection.
The integration simulation now executes the actual production sequencing RTL,
models only the PLL and hard falling-edge gate, and rejects selection while
the output gate is enabled or an output-clock pulse shorter than 20 ns.
