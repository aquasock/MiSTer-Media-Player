# FLAC framing and provisional sample ownership

`flac_stream_decoder` accepts a native `fLaC` file from byte zero after reset.
The current profile is 44,100 Hz, two channels and 16 decoded bits per sample.
Its output is coded channel data for a provisional frame store. It must never
be wired straight to an audible PCM sink.

## Input and cancellation

All signals use the decoder clock. A producer presents `input_valid` and holds
its byte until `input_ready`. Valid must not depend on ready. `input_end` means
that no further bytes remain after any currently valid byte. Gaps with neither
valid nor end are allowed. STREAMINFO must be first; other metadata is skipped
without storing it. The decoder validates the profile, block limits, header
syntax, canonical coded numbers, contiguous frame/sample numbering, CRC-8,
zero padding and CRC-16. A known total sample count must match end of input.
A zero total is supported. STREAMINFO MD5 is not checked.

Reset cancels parsing and clears terminal status. The surrounding session
controller must also invalidate provisional storage and drain or discard old
memory responses before starting a new file. This block does not manage DDR
transactions, epochs, a work watchdog, file seeking or playback clocks.

## Frame store handshake

1. `begin_valid` presents stable `frame_position`, `frame_size` and
   `channel_assignment` after the header passes its CRC. The store accepts
   with `begin_ready` only when it owns enough space for that entire frame.
2. Each `sample_valid && sample_ready` transfers a signed 17-bit coded sample.
   Channel zero is emitted completely before channel one. `sample_index`
   runs from zero to `frame_size - 1` separately for each channel. The output
   remains stable when stalled. Frame sizes through 65,535 are supported.
3. `flac_stereo` combines corresponding coded samples using assignment 1
   (independent), 8 (left/side), 9 (side/right), or 10 (mid/side). Its signed
   16-bit outputs are usable only when its error output is clear. A store must
   latch any reconstruction overflow as a fault; it cannot accept clipped PCM.
4. `commit_valid` is raised only after both subframes and the frame CRC pass.
   The store asserts `commit_ready` only after all writes for this frame have
   completed successfully. Their handshake admits the whole frame for later
   PCM consumption and permits the decoder to parse another frame.
5. On any decoder error, discard the current provisional frame. Previously
   committed frames are independently valid. `store_error` terminates parsing
   and suppresses begin/sample/commit handshakes immediately, including on
   the same cycle as a prospective commit.

`finished` indicates clean input exhaustion, not that the last audible sample
has played. The future frame reader must drain committed samples through the
shared PCM sink before reporting playback EOF. `finished` and `error` remain
latched until reset; the caller must reset before presenting another file.

## Error codes

| Code | Meaning |
| --- | --- |
| 1 | Native FLAC magic mismatch |
| 2 | Metadata or unsupported STREAMINFO profile |
| 3 | Frame header, block/rate format or padding violation |
| 4 | Header CRC-8 or frame CRC-16 mismatch |
| 5 | Subframe rejection, including truncation within a subframe |
| 6 | Truncated outer input or missing samples at EOF |
| 7 | Frame/sample numbering or total-length violation |
| 8 | Frame store failure |

## Verification boundary

`tools/verify_flac_stream.py` feeds complete encoded files directly to RTL.
The testbench models provisional frame memory and uses the RTL stereo unit.
Only admitted frames are compared with the corpus's original generated PCM;
the expected audio is not reconstructed by the decoder under test. Input,
sample and ownership stalls and reset/replay are exercised. Constructed frames
cover all stereo modes, signed extremes, explicit sample rates, fixed and
variable numbering, and unknown duration. Damaged header/frame CRCs,
truncation and a simultaneous store failure must not admit the bad frame.

These tests do not demonstrate DDR correctness, native HDMI operation, or
full-core resource/timing closure. These modules are not yet in `files.qip`.
