# Progressive MPG and FPGA MP2 architecture

The hardware-accepted video boundary is `9233f07` seed 52, recovered from
`a57079f`. Stock Main owns file selection and acknowledged 16-bit transfers.
The 32 KiB input CDC FIFO, H.262 decoder and 800x600 output remain the baseline.

The Program Stream demux selects the first video and audio IDs. Raw video
bypasses the new reservoirs. MPG video enters an 8 MiB DDR ring at physical
0x30400000–0x30bfffff, above the framebuffer regions ending at 0x3027ffff.
Each word carries one compressed byte, a sparse PTS tag, or EOF; capacity is
1 MiB of compressed video. This allows input to reach audio packets while
video presentation is blocked. The existing arbiter retains display,
prediction and frame-write priority, with a fourth low-priority stream client
and explicit response ownership. No new DDR timing exception is added.

Queued PTS tags expand into the existing internal metadata format. The metadata
extractor preserves the decoder's accepted-byte pulse contract. A separate
binder watches picture prefixes at that accepted-byte boundary, so a PES that
starts inside a preceding picture header cannot timestamp that picture. A
prefix split across PES packets belongs to the packet containing its first
byte. Existing picture-bank ownership carries bound timestamps through B-frame
reordering. Missing individual picture PTS use the established cadence fallback.

A 1,024-word compressed-audio FIFO feeds the MP2 decoder's bounded frame buffer.
The decoder parses allocation, SCFSI and scalefactors, unpacks grouped samples,
requantizes, and performs serialized cosine-matrix/polyphase synthesis.
Shared arithmetic takes about 0.6 million 60 MHz cycles per 1,152-sample frame,
against a 1.44 million-cycle 48 kHz playback budget. Coefficients use Q30
requantization and Q16 cosine/window values; subbands/history use Q20.
The derived window retains its MIT PL_MPEG attribution under tools/reference.
The Python reference and FFmpeg are test tools, never runtime components.

A 4,096-word PCM CDC FIFO carries stereo samples and frame timestamps into
24.576 MHz CLK_AUDIO. A one-shot origin FIFO initializes its clock to the same
first-video-PTS-minus-100-ms origin used by video presentation. Output waits
for the first audio PTS and consumes one sample pair every 512 clocks. Both
clocks derive from CLK_AUDIO; crossing latency is less than a 90 kHz tick.
The initial preroll is a bounded implementation choice, not general adaptive
buffering. Underflow and late frame timestamps are sticky diagnostics; arbitrary
seeks/discontinuities are not recovered. Session reset flushes compressed data,
PCM, synthesis history, timestamps and counters. Test-tone selection uses the
existing independent PCM path and does not flush movie decoding.

EOF is ordered behind video in DDR and behind the final PCM sample. Missing
H.262 sequence end is inserted for Program Streams only. Audio EOF silences the
sink without reporting a normal end as an underrun. Schema-eight telemetry
adds decoded MP2 frames, actually consumed sample pairs, and audio status.
Sample-consumption events cross domains as a single-bit toggle, not a torn
multi-bit count. Error bits 10–13 report demux, MP2 decode, underrun and timestamp
failures respectively. Raw schema-seven screen captures remain decodable.
