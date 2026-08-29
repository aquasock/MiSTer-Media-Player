# ARM Media Helper Architecture

The helper is the source, container and codec boundary for MediaPlayer. MiSTer
Main remains a transport broker and the FPGA remains responsible for H.262
decode, presentation timing and final audio/video output.

## Stable launch contract

Protocol version one uses:

```text
MediaPlayer_Helper --protocol 1 --source file:/absolute/path/movie.mpg
```

`--capabilities` prints the implemented and reserved source types. Bare paths
remain accepted for transition and local verification, but Main uses the
versioned form.

The helper writes one annotated transport to standard output. Reserved H.262
codes distinguish picture timestamps, fixed signed 16-bit PCM samples, and a
clean audio-end token. Main brokers those bytes through its existing file path
without parsing them and remains the sole FPGA SPI owner. The FPGA strips the
records before H.262 decode, applies PCM FIFO backpressure, and owns final sample
pacing and audio/video output. Diagnostics go to standard error. Explicit
`--pcm-out` remains a host-verification path and does not change hardware
ownership. Main's isolated broker exposes a source-string launch function; its
current file-selector wrapper constructs `file:` while a later disc-menu action
can pass `dvd:` without changing process, pipe or FPGA-transfer ownership.

## Source boundary

`media_source` is a pull interface with read, character-read, rewind, seek,
error and close operations. The current backend implements `file:`. `dvd:` is recognized
as a reserved source and deliberately returns unsupported without opening,
mounting or reading the device.

A future DVD backend may turn title and program-chain navigation into a logical
byte stream without changing Program Stream parsing. It will own optical-device
discovery, ISO9660/UDF access, VIDEO_TS and IFO interpretation, VOB program-chain
assembly and any CSS policy. Those responsibilities do not belong in Main or
the FPGA.

## Pipeline boundaries

The current implementation contains these logical stages even where they still
share a compilation unit:

1. Source: `file:` now; `dvd:` and `iso:` later.
2. Container: raw M2V pass-through or MPEG Program Stream/PES demultiplexing.
3. Timeline: PTS extraction and FPGA in-band timestamp records, with future
   discontinuity events for title, cell and seek transitions.
4. Audio codec: MPEG Layer II on stream ids 0xC0-0xDF, standalone MPEG-1
   Layer III, RIFF WAVE and FLAC files, and AC-3 on private stream 1 substreams 0x80-0x87, all
   behind codec selection rather than output-specific decode paths. MPEG audio
   is decoded by the pinned minimp3 source compiled directly into the static
   helper binary; MP3 support adds no runtime library. A Program Stream codec
   is decided by the first audio PES seen and the other is ignored for the
   rest of the session; only the first
   AC-3 substream is played, because track switching needs the versioned
   control channel protocol one omits. AC-3 is downmixed to stereo by liba52
   using the stream's own coefficients. DTS on substreams 0x88-0x8F is
   passthrough only, since no DTS decoder is present; a DTS track selected for
   HDMI output is refused rather than played as silence. DVD LPCM is still
   later.
5. Audio output: `--audio-out hdmi` (default) sends decoded stereo to HDMI.
   `--audio-out spdif` sends decoded MP2, MP3, WAV and FLAC stereo as ordinary
   S/PDIF PCM. For AC-3 and DTS it bypasses the decode stage and emits IEC 61937
   bursts instead, carried unchanged on the existing PCM transport and marked
   by the transport's independent non-audio flag. AC-3 uses
   a fixed 1536-sample burst period; DTS carries its own sample count and uses
   512, 1024 or 2048 with the matching data type, so the period is read from
   the frame rather than assumed. The selection is made at launch because the decoder
   runs here, so only this process can choose what to emit. A burst is only
   audible as surround if nothing downstream scales it: any gain, mix or filter
   between here and the S/PDIF pin destroys it.
6. Outputs: one annotated H.262-plus-PCM transport to Main, with the FPGA owning
   the separate video and PCM sinks after record extraction.

Standalone `.mp3` is an audio-only use of the same output contract: the helper
skips bounded ID3v2 and terminal ID3v1 metadata, decodes MPEG-1 Layer III mono
or stereo at 44.1 or 48 kHz, and emits PCM records followed by the ordinary
audio-end token. No H.262 bytes or picture timestamps are required. CBR and VBR
share this path. MPEG-1 32 kHz and MPEG-2/2.5 lower-rate extensions are refused
until a separately qualified helper-side resampler exists.

Standalone `.wav` uses the same audio-only contract. The pinned miniaudio WAV
decoder reads through `media_source` callbacks in bounded chunks and converts
ordinary integer or floating-point mono, stereo or multichannel input to signed
16-bit stereo. Sample rates in the 44.1 kHz family emit at 44.1 kHz; other
accepted rates emit at 48 kHz. This conversion deliberately serves predictable
consumer playback rather than bit-perfect or discrete-surround output. The
dependency is compiled into the static helper with device, engine, resource
manager, encoder, threading, runtime linking and MP3 code disabled.

Standalone `.flac` follows the WAV audio-only contract and uses miniaudio's
FLAC decoder through the same bounded `media_source` callbacks. Sixteen- and
24-bit mono, stereo or multichannel input is converted to signed 16-bit stereo;
44.1 kHz-family rates emit at 44.1 kHz and other accepted rates emit at 48 kHz.
The decoder is compiled directly into the static helper and adds no runtime
library or FPGA dependency.

Future play, pause, seek, title, chapter, angle, audio-track and subtitle-track
commands require a versioned control channel. They are intentionally not
implemented in protocol one; adding that channel must not change the source,
container, codec or output ownership above.

## Deferred DVD scope

Recognizing `dvd:` in protocol one is an architectural reservation, not DVD
support. v0.8.0 already supports file-based AC-3 decode and AC-3/DTS passthrough,
plus a bounded interlaced all-I video path in the FPGA. Mounting a disc,
navigating titles, handling encryption, DVD LPCM, subpictures, track switching
and broader interlaced decoding remain deferred. These require separately
approved development scopes; accepting some DVD audio payloads does not make
the current source backend or video decoder DVD-compatible.

## Main to FPGA guarded fast-block transport

The helper launch/stdout contract is unchanged. Main owns all FPGA transfers.
`credit_fast_v1` uses the existing GPIO fast-block primitive on a wide, capable
MediaPlayer core; it is not DMA, a new physical bridge, or helper-direct access.
Ordinary non-media file transfers retain their original acknowledged path.

MediaPlayer opts into `hps_io` parameter `MEDIA_BURST=1`. Under the file-I/O
select, command `0x57` and six zero dummy words return these seven 16-bit words
in order. Every command/status word uses the ordinary acknowledged primitive.

| Return | Meaning |
| --- | --- |
| 0 | Magic `0x4D50` |
| 1 | Protocol/version `0xB001` |
| 2 | Available credit, in 16-bit words, maximum 4096 |
| 3, 4 | Accepted-word counter, low then high halves |
| 5 | Rolling 16-bit digest |
| 6 | Bit 0 ready, bit 1 sticky overflow; other bits zero |

Credit, counter, digest and flags are latched together when the command arrives.
The counter and digest advance only on accepted writes to elementary-stream
index 1. Digest starts at zero and updates as `rotate_left_16(digest, 1) XOR word`.
Words are little-endian with a zero high byte for an acknowledged odd tail.
This inexpensive checksum detects the tested corruptions but can collide; it is
neither a cryptographic hash nor a complete proof against arbitrary corruption.
Counters wrap modulo 2^32. Reset clears both and the overflow latch. Ready stays
low for 32 write clocks after reset and also requires an active index-1 download.

The ingest FIFO remains 16384 nominal 16-bit words (32 KiB), with a byte reader
in the decoder clock domain. This is separate from the unchanged 64 KiB clean
video queue. Credit uses the write-domain used count, subtracts 32 words of
nominal free-space headroom, clamps to 4096 and returns zero while full or not
ready. A zero used count is valid only when the write-domain empty flag agrees;
this prevents a full-counter wrap followed by a partial-byte read from falsely
granting empty-FIFO credit. The vendor simulation model can assert full at 16383 words with its
literal default family, leaving 31 effective words of headroom; the tests check
both that default and the Cyclone V family model. Synchronized read progress may
understate capacity, which is safe. Main is the only writer and may spend a
snapshot only once; no other producer may consume the advertised space.

At session start Main probes capability. Narrow or older cores retain the
acknowledged payload path; its handshake waits are not covered by the new
verified-credit yield guarantee. The old blocking burst API remains available
for compatibility callers. Ordinary non-media SPI and FIO functions are unchanged.

The media loader uses `user_io_file_tx_data_step`, which sends at most one
2048-byte batch per call and never more words than the verified credit. Zero
credit returns successfully with zero bytes consumed, allowing Main to process
its menu before trying again. Unaligned input is packed into aligned local words;
an odd final byte gets a zero high byte. No acknowledged payload fallback is
used for a capable core, including at zero credit.

A persistent 16 KiB buffer retains unsent bytes across polls. At most one pipe
read and eight transfer steps occur per poll, with a 2000-microsecond elapsed
budget checked between steps even when logging is unavailable. This is a work
budget, not a hard realtime bound: a status transaction, current step, scheduler
preemption, logging and the existing terminal/child cleanup can extend a call.
Short odd pipe reads retain their last byte until another read or EOF; only the
true final byte is padded. EOF releases download only after pending bytes drain.
Cancellation, read errors and core changes discard pending state before restart.

An acknowledged status transaction follows each batch, after the final low and
select release, so the FIO pipeline drains before the snapshot. Main checks
accepted count, digest, capability, ready and overflow before and after a batch,
including after a zero-credit yield. Any mismatch stops the session; an uncertain
partial batch is never retried. Counter and digest state resets for a new session,
even when the diagnostic log cannot be opened. The FPGA protocol is unchanged.

`/tmp/MediaPlayer_ARM.log` now identifies `profile_version=2` and
`transport=credit_step_v1`. `pipe_read` records describe actual source reads;
`transfer` records sample the first four and every 64th verified transfer step.
Submitted bytes advance after each verified step, not only after a whole pipe
chunk. `tx_calls` counts productive steps, while `tx_us` and `tx_max_us` also
include queries that yield without payload. `ack_chunks` counts sampled steps;
capable-core payloads are fast writes, not acknowledged data. Summary counters
retain fast/slow bytes, batch counts, queries and mode (0 probe, 1 legacy,
2 guarded). Sum all pipe-read counts and compare with the final submitted total
on successful EOF; do not treat sampled transfer records as a complete byte log
or parse these logs with the historical version-one read-record analyzer.
On the corrected test-one fixture, the installed version-two Main reduced
maximum measured media-poll occupancy from 160,937 to 9,287 microseconds, with
zero acknowledged payload bytes and all 360 pictures displayed. The user
reported normal menu response. This is one measured workload, not a hard
2,000-microsecond latency bound or a sustained-throughput guarantee for every
source. Broader changes still require their own hardware qualification.

On the build PC, run `tools/streams/test_main_mister_profile.py --main-source
<Main_MiSTer checkout> --rtl`, then repeat with `--sanitize`. The RTL mode uses
actual extracted Main functions, clock/ACK logic and FIO logic with modeled
sink capacity. The separate `tb_mpeg2_stream_fifo_burst.sv` qualifies the actual
FIFO wrapper against the installed Quartus `altera_mf.v`; compile once normally
and once with `-DFIFO_CYCLONE_V`. The vendor model is not redistributed.
