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

`media_source` is a pull interface with read, character-read, rewind, error and
close operations. The current backend implements `file:`. `dvd:` is recognized
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
4. Audio codec: MPEG Layer II on stream ids 0xC0-0xDF and AC-3 on private
   stream 1 substreams 0x80-0x87, both behind codec selection rather than
   source-specific decode paths. The codec is decided by the first audio PES
   seen and the other is ignored for the rest of the session; only the first
   AC-3 substream is played, because track switching needs the versioned
   control channel protocol one omits. AC-3 is downmixed to stereo by liba52
   using the stream's own coefficients. DVD LPCM is still later. Passing a
   compressed bitstream through to S/PDIF is a separate output concern, not a
   codec one: it would bypass this decode stage entirely.
5. Outputs: one annotated H.262-plus-PCM transport to Main, with the FPGA owning
   the separate video and PCM sinks after record extraction.

Future play, pause, seek, title, chapter, angle, audio-track and subtitle-track
commands require a versioned control channel. They are intentionally not
implemented in protocol one; adding that channel must not change the source,
container, codec or output ownership above.

## Deferred DVD scope

Recognizing `dvd:` in protocol one is an architectural reservation, not DVD
support. Mounting the connected disc, navigating titles, handling encryption,
decoding AC-3 or LPCM, rendering subpictures and supporting interlaced content
remain separate approved development phases after embedded file audio works.

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
acknowledged bulk preload path for the session. A capable core receives no more
than the current credit through `fpga_spi_fast_block_write`: data-low/strobe-high
posted writes per word and a final low, with acknowledged command framing.
Unaligned buffers and odd tails use the byte-safe acknowledged path. Zero
credit causes one acknowledged word of progress before another query.

An acknowledged status transaction follows each batch, after the final low and
select release, so the FIO pipeline drains before the snapshot. Main checks
accepted count, digest, capability, ready and overflow before sending more data.
Any mismatch stops the session and kills the helper process group before
waiting; an uncertain partial batch is never retried. A reset between chunks
therefore fails validation instead of silently resuming. Session state resets
even when the diagnostic log cannot be opened. A new host with an older FPGA
falls back, and the new FPGA preserves the old acknowledged host protocol.

`/tmp/MediaPlayer_ARM.log` identifies `transport=credit_fast_v1` and records fast
bytes, acknowledged bytes, batch counts, status queries and transport mode
(0 unprobed, 1 legacy, 2 guarded). Faults include the verified prior byte total
and attempted bytes for the failed chunk. Submitted-byte accounting advances
only for completely verified chunks. Every-64th-chunk ACK profiling covers only
acknowledged payload fallback, not fast data or status commands. Transfer time
includes queries and checksum work. Hardware delivery rate and decoder limits
must be measured; the modeled register spacing is not a throughput prediction.

On the build PC, run `tools/streams/test_main_mister_profile.py --main-source
<Main_MiSTer checkout> --rtl`, then repeat with `--sanitize`. The RTL mode uses
actual extracted Main functions, clock/ACK logic and FIO logic with modeled
sink capacity. The separate `tb_mpeg2_stream_fifo_burst.sv` qualifies the actual
FIFO wrapper against the installed Quartus `altera_mf.v`; compile once normally
and once with `-DFIFO_CYCLONE_V`. The vendor model is not redistributed.
