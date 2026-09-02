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
versioned form. Menu-capable launches use `isomenu:` or `dvdmenu:`; the
corresponding `iso:` and `dvd:` routes retain longest-title playback.

Main optionally passes `--control-fd FD`, a private version-one
`SOCK_SEQPACKET` channel separate from standard output.  Player-one Left and
Right request previous or next chapter and a ready/go barrier prevents any
pre-jump byte from crossing the reset download session. Start pause/resume is
owned by Main as a stdout transport hold, so no pause byte enters the FPGA
protocol. Keyboard P/N use the same previous/next actions and Space uses the
same pause action while the MiSTer OSD is closed.

Ordinary file-backed `.mpg` and `.mpeg` Program Streams additionally accept
Alt+Left/Right for 10-second jumps, Ctrl+Left/Right for 60-second jumps, and
Ctrl+Alt+Left/Right for 300-second jumps. The helper records at most one
timestamped video-PES source offset per half second while playing. A forward
jump beyond that sparse index extends it with a packet-length-aware scan that
emits no media; backward and already-indexed jumps use binary lookup. The
selected timestamp is clamped at file boundaries, the file is repositioned,
and demux/audio/scheduler queues are discarded behind the existing READY/GO
download barrier. The normal random-access filter then withholds output until
it has a sequence header, an I picture, and the following reference picture.
Standalone `.mp3`, `.wav`, `.flac` and `.ogg` files accept the same fixed
jumps. Their decoders poll the control channel between bounded PCM chunks,
seek on the output sample-frame timeline, and restart the audio-interface
publisher at the absolute target behind the same READY/GO reset. Raw `.m2v`,
ISO, and optical-disc routes reject these seek commands in this boundary.

Menu-mode sources use the same channel for directional, activate and root-menu
commands. Root calls and button activations that enter a title use the ready/go
barrier.  An activation that remains in menu space receives a distinct
menu-continuation acknowledgment, so Main preserves the resident video frame
while the helper advances the overlay. Highlight-only moves likewise do not
reset the video stream. Main maps player-one
D-pad/A/Start/Select and keyboard arrows/Enter/M while an authored menu is
active.

The helper writes one annotated transport to standard output. Reserved H.262
codes distinguish picture timestamps, fixed signed 16-bit PCM samples, a clean
audio-end token, and length-bounded DVD overlay records. Main brokers those bytes through its existing file path
without parsing them and remains the sole FPGA SPI owner. The FPGA strips the
records before H.262 decode, applies PCM FIFO backpressure, and owns final sample
pacing and audio/video output. Diagnostics go to standard error. Explicit
`--pcm-out` remains a host-verification path and does not change hardware
ownership. Main's isolated broker exposes a source-string launch function, so
file, longest-title and authored-menu routes retain the same process, pipe and
FPGA-transfer ownership.

## Source boundary

`media_source` is a pull interface with read, character-read, rewind, seek,
error and close operations. The current backends implement `file:`, `iso:` and
`dvd:` plus their `isomenu:` and `dvdmenu:` counterparts. The ISO backend uses stream callbacks for an absolute image path. The
direct backend requires an absolute device path such as `dvd:/dev/sr0` and lets
libdvdnav/libdvdread/libdvdcss own optical-device access, CSS authentication and
sector reads; no filesystem mount is required. The `iso:` and `dvd:` routes
choose the longest described DVD-Video title and expose its cells in
program-chain playback order as one sequential Program Stream. The source retains the selected title,
chapter count and declared duration and converts a title exit, replay or
backward chapter or cell transition into clean end-of-stream before libdvdnav
can expose a following navigation domain or second traversal. The declared
duration remains selection and diagnostic metadata rather than a byte-cutoff:
some authored program chains legitimately deliver their terminal VOBU after
the chapter-description duration. All three dependencies are linked into the
static helper, so
target-installed libraries cannot change this behavior. At every initial or
reset-causing DVD random-access boundary, the helper withholds video until a
sequence header, an I reference and the following I/P reference are all
present. Contextless pictures before that sequence and open-GOP B pictures
between the I and following reference have their start codes neutralized while
all byte positions and timestamp records remain stable; the complete sequence
context and every later authored picture remain unchanged. This delegates CSS
access to libdvdcss and is not a claim of CSS conformance.

The direct optical backend retains one authenticated libdvdnav session across
signature and stream preflight rewinds. Only after preflight, a producer thread
fills an 8 MiB HPS-RAM byte ring and playback starts with at least 4 MiB queued
unless the title is shorter. Consumer order is exact; end-of-stream and read
errors cross the same synchronized boundary. Waits of at least 100 ms and final
producer/consumer totals are diagnostic output. ISO and ordinary file sources
remain synchronous and byte-identical, and none of this buffer consumes FPGA
memory.

The menu routes instead preserve libdvdnav first-play behavior, VM domain
transitions, authored finite or indefinite stills, button state, CLUT changes
and root-menu calls. DVD private-stream subpicture packets are reassembled and
decoded into a packed 720x480 two-bit plane; normal/highlight palettes and the
inclusive button rectangle travel separately so highlight motion does not
reload the plane. A displayed libdvdnav button forces menu compositing even
when the packet also carries a later scheduled stop that the clockless helper
has already parsed. Future work may add optical-device discovery beyond the
explicit `/dev/sr0` launcher. Angles, track selection and general seeking
remain separate work.

## Pipeline boundaries

The current implementation contains these logical stages even where they still
share a compilation unit:

1. Source: `file:`, decrypted or CSS-encrypted `iso:`/`isomenu:`, and direct
   optical `dvd:`/`dvdmenu:` through `/dev/sr0` now.
2. Container: raw M2V pass-through or MPEG Program Stream/PES demultiplexing.
3. Timeline: PTS extraction and FPGA in-band timestamp records.  An `iso:`
   title may cross VOB or cell boundaries whose raw PES clock restarts; the
   helper recognizes only a material backward jump, rebases the new ISO epoch
   onto the preceding maximum, and sends one continuous title clock to both
   its audio scheduler and the FPGA.  Ordinary MPEG decode-order timestamp
   reordering and every non-ISO source remain unchanged. Chapter changes and
   ordinary Program Stream file seeks reset helper demux, audio, scheduler and
   PTS state behind a Main download-session barrier. File seeking preserves the
   source PTS epoch; DVD chapter changes retain their discontinuity rebasing.
4. Audio codec: MPEG Layer II on stream ids 0xC0-0xDF, standalone MPEG-1
   Layer III, RIFF WAVE, FLAC and Ogg Vorbis files, and AC-3 on private stream 1 substreams 0x80-0x87, all
   behind codec selection rather than output-specific decode paths. MPEG audio
   is decoded by the pinned minimp3 source compiled directly into the static
   helper binary. Standalone MP3 uses miniaudio's bundled seek-aware MP3
   backend; neither path adds a runtime library. A Program Stream codec
   is decided by the first audio PES seen and the other is ignored for the
   rest of the session; chapter changes retain that established codec and
   private substream instead of selecting whichever PES arrives first after
   the discontinuity. Only the first AC-3 substream is played, because track switching needs the versioned
   control channel protocol one omits. AC-3 is downmixed to stereo by liba52
   using the stream's own coefficients. DTS on substreams 0x88-0x8F is
   passthrough only, since no DTS decoder is present; a DTS track selected for
   HDMI output is refused rather than played as silence. DVD LPCM is still
   later.
5. Audio output: `--audio-out hdmi` (default) sends decoded stereo to HDMI.
   `--audio-out spdif` sends decoded MP2, MP3, WAV, FLAC and Ogg Vorbis stereo as ordinary
   S/PDIF PCM. For AC-3 and DTS it bypasses the decode stage and emits IEC 61937
   bursts instead, carried unchanged on the existing PCM transport and marked
   by the transport's independent non-audio flag. AC-3 uses
   a fixed 1536-sample burst period; DTS carries its own sample count and uses
   512, 1024 or 2048 with the matching data type, so the period is read from
   the frame rather than assumed. The selection is made at launch because the decoder
   runs here, so only this process can choose what to emit. A burst is only
   audible as surround if nothing downstream scales it: any gain, mix or filter
   between here and the S/PDIF pin destroys it.
6. Outputs: one annotated H.262-plus-PCM-and-overlay transport to Main, with the
   FPGA owning the separate video, PCM and native-480i overlay sinks after
   record extraction. Overlay plane data is split into records no larger than
   4,096 payload bytes and becomes visible only after an explicit commit.

Standalone `.mp3` is an audio-only use of the same output contract: miniaudio's
bundled MP3 backend skips stream metadata, decodes MPEG-1 Layer III mono or
stereo at 44.1 or 48 kHz, provides sample-position seeking for CBR and VBR, and
emits PCM records followed by the ordinary audio-end token. No H.262 bytes or
picture timestamps are required. MPEG-1 32 kHz and MPEG-2/2.5 lower-rate
extensions remain refused.

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

Standalone `.ogg` follows the same audio-only contract. Miniaudio drives the
pinned stb_vorbis decoder through bounded `media_source` callbacks, converts
mono or multichannel Vorbis to signed 16-bit stereo, and emits at 44.1 or
48 kHz. The decoder is compiled into the static helper and has no target-side
runtime-library dependency.

Previous and next chapter, fixed ordinary-Program-Stream and standalone-audio
jumps, and authored-menu commands use the private control protocol while Start
pause/resume is a Main-side transport hold. Arbitrary scrubbing, DVD seek, title, angle,
audio-track and subtitle-track commands remain deferred. The ARM-only pause
does not suppress the FPGA audio FIFO underrun after its existing reserve
drains; that product polish requires an explicit future core pause state.
At a chapter barrier the helper discards partial decoder bytes but retains the
selected codec and DVD private substream. AC-3 decode then scans forward at
most 64 KiB, rebuilding liba52 after a rejected candidate frame, so boundary
damage cannot silently switch tracks or terminate playback immediately.

## Deferred DVD scope

The menu path implements first-play/root navigation, button highlights and the
menu subpicture plane. It does not present subtitle tracks during title
playback, switch angles, titles, audio or subtitle tracks, decode DVD LPCM,
discover drives beyond `/dev/sr0`, or eject media. Broader DVD-Video filesystem
and navigation conformance is not claimed because the project's retained
normative references do not cover those specifications. Those deferred
features require separately approved development scopes.

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
