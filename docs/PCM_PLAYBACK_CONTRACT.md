# Shared native PCM playback boundary

This interface is implemented by the standalone `rtl/audio/media_pcm_sink.sv`
prototype. It is intended for native CD-quality FLAC now and 44.1 kHz,
16-bit stereo PCM WAV later. It is not yet part of the production core.

## Format-independent stream

A producer emits one signed 16-bit left/right pair per valid sample token,
then a separate EOF token after the final sample. An EOF token carries no
sample. The producer/FIFO holds a token until input_ready and input_valid
are both true. Samples must already be validated and reconstructed: FLAC
CRC, prediction and stereo decorrelation are upstream concerns. A WAV parser
would extract the same PCM pairs from its data chunk without FLAC machinery.

Use a common clock-crossing FIFO at integration, carrying 33 bits per token
(EOF, left, right). Reset/drain that FIFO on file changes and seek cancellation.
The sink does not discard late DDR responses or synchronize its own inputs.
All sink inputs must be in its selected audio clock domain. Keep the existing
MP2 PTS-bearing stream separate until any common output refactor is validated.

## Position and transport

A start command sets an absolute 36-bit source-sample position. Seeking finds
an appropriate byte/frame location upstream and discards any leading decoded
samples before issuing the new stream at that position. FLAC can use seek
points and frame numbering; later WAV can align a byte offset to stereo PCM
pairs. Both expose the same playback position to UI formatting.

`sample_tick` is the serializer's once-per-stereo-frame fetch request. At
integration it must occur early enough for the serializer to latch the sink's
updated output; do not connect two same-edge nonblocking updates expecting
the serializer to see the new sample immediately. The sample clock comes
from the selected native-rate PLL, never a video frame tick. This module has
no resampler or frequency generator.

Position advances when the preceding sample's output interval completes,
not when a producer decodes ahead. Pausing prevents token consumption and
position advance, and mutes output. The output boundary must coordinate pause
with serializer timing. The EOF token is consumed on the next eligible tick
after the final sample, so completion does not erase that sample early.
Finished stays asserted until restart/reset/cancel. Empty streams may finish
without producing samples. Startup permits empty prefill; starvation after
playback starts stops the sink and sets a functional error for session control.
It never silently repeats or skips source samples to catch up.

Reset/cancel wins over start and consumption, clears position/status and mutes
output. A new start replaces the old state, but it does not by itself flush
external queues: the session controller must complete the FIFO/DDR handoff
first. Upstream total duration, file-byte probing and error messages are not
part of this sample consumer.

## Future WAV adapter

Later work adds RIFF/WAVE chunk parsing, length and alignment validation,
metadata skipping and PCM data extraction. Initially accept 44100 Hz,
16-bit stereo integer PCM; validate encoding rather than assuming every WAV
file contains PCM. No WAV parser or file-menu support is added in this cycle.
The native clock, PCM queue, sink, pause/EOF behavior and UI position are shared;
FLAC metadata, frame CRCs and predictors stay confined to the FLAC adapter.
