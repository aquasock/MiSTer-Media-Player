# Progressive player architecture

The runtime starts from `a57079f`, whose seed-11 rebuild was accepted on
hardware on 2026-09-13. Stock Main owns normal file selection and acknowledged
16-bit file transfers. The 32 KiB asynchronous FIFO, hps_io, reset crossings,
DDR ownership and decoder retain the baseline implementation.

`mpeg2_program_stream_ingress` detects a four-byte pack prefix or replays all
bytes as raw elementary video. Its demultiplexer comes from `3713581`, with
elastic output registers added so withdrawing ready cannot discard a byte.
The first video/audio IDs are selected independently; extra tracks are skipped.
Compressed audio is drained without decoding in this stage.

The baseline metadata extractor converts valid/ready to the decoder's
accepted-byte pulse contract. Raw private timestamp records retain their old
behavior. PES timestamps are not yet bound to pictures; presentation uses
encoded cadence. Correct PES-to-picture association and audio synchronization
belong to MP2 integration, not to attaching a timestamp to whichever picture
happens to be decoding when a PES arrives.

Physical EOF drains retained bytes before appending a missing video sequence
end; raw streams are unchanged. The metadata window flushes normally and the
B-picture scheduler can release its final reference. Demux errors join the
existing fatal transport drain and cadence error flags bit 10.

H.262 parsing, inverse quantization, IDCT, I/P/B reconstruction and planar
DDR3 frame storage/readback retain the accepted baseline. Decode is 60 MHz;
the 800x600 raster is 40 MHz. PCM test output uses 24.576 MHz. No new clock
domain or timing exception is introduced. Supported video is progressive
4:2:0 through 720x480 at codes 1–5. Native progressive 480p is a later stage.
