# OSD access during playback: proposed next build

Status: implementation authorized and implemented; simulation validated, Quartus builds and hardware acceptance pending.

Base: source `07b8688`; seed 87 passed all four timing corners.

## Objective and boundary

Play MPG and M2V files while stock Main remains able to open its OSD and change audio/video filters. Opening the menu must not pause playback. Deliver the file-reader and session-control foundations for later play/pause and seeking, without exposing unfinished controls in this build.

Stock Main's `user_io_file_mount` opens generic files, and `user_io_poll` services bounded sector requests. This provides a plausible stock-Main solution; throughput and menu responsiveness on the installed binary still require hardware validation. Reference: https://github.com/MiSTer-devel/Main_MiSTer/blob/master/user_io.cpp (`user_io_file_mount`, `user_io_poll`). The existing local `sys/hps_io.sv` exposes the needed block interface.

## File transport

Replace the `F1` download menu entry with a slot-zero mounted-file entry using the same MPG/M2V extensions and user-facing Open label. Wire the existing `img_mounted`, `img_size`, `sd_lba`, `sd_blk_cnt`, `sd_rd`, `sd_ack` and buffer signals. Keep writes disabled. Confirm mount-menu syntax and the installed Main's behavior before integration; no custom Main or helper process is part of the design.

Implement a separate `media_file_reader` in `clk_sys`. Use 512-byte sectors, parameterized bounded batches (initial target 4 KiB, up to the interface's 16 KiB transaction limit), one outstanding request, and staging RAM that can accept the entire response without downstream backpressure. Main must never wait for decoder consumption during a sector response. Interpret acknowledgement start, streamed writes and transaction completion separately; do not release staging storage until its valid data is consumed.

Reuse the existing 32 KiB ingress reservoir where practical. Reserve staging capacity before issuing reads and prefetch according to occupancy. Measure latency and reserve needs before selecting final batch and watermark values; do not assume 32 KiB covers arbitrary menu/storage delays. If more buffering is required, account for the existing DDR clients and FPGA memory budget explicitly.

Track file size and byte position with 64-bit counters, checking the representable LBA range before conversion. Deliver exactly `img_size` bytes, including odd-length final words; discard sector padding. Empty files, request timeout, unmount and fatal decode failures receive explicit handling. The generic stock protocol can return zero-filled blocks on host read failure without a distinct error indication; do not claim reliable detection of every storage error.

## Playback session and stream contract

Introduce a session controller with acknowledged start/restart, quiesce, flush and ready transitions. Transport supplies ordered bytes with valid/ready, an explicit start position/session identity, and an ordered EOF indication. An idle bus or empty reservoir is never EOF. EOF reaches the demultiplexer only after all valid file bytes have drained.

Replace the `ioctl_download`-based rearm and end detection in `MediaPlayer_top_00.svh`. Keep container detection, demultiplexing, decoder and PCM behavior stable except for the restart integration required by the new source. Handle the ingress reservoir's current global-reset-only behavior explicitly.

On replacement/reset: stop new requests, complete or discard the outstanding host response, quiesce memory clients, flush compressed/PCM/metadata queues and decoder reference state, acknowledge reset release across domains, then prefill and start the new session. Local generation tracking plus draining outstanding transfers prevents old responses from entering a new session; the stock SD protocol itself carries no generation tag. Keep raster and OSD service running throughout. Re-anchor audio and video together after restart.

## Accommodating later controls

Pause is a presentation operation, separate from transport throttling. Leave a controller command boundary for pause/resume and a common playback-time hold/rebase mechanism for video scheduling and audio output. A future pause must retain the displayed frame, preserve queued media, output silence without consuming movie samples, and resume without timestamp catch-up. Physical video/audio clocks keep running. Merely stopping file reads is insufficient because queues already contain media. This build does not advertise pause until all those consumers honor it.

For seeking, make the reader's start byte offset an explicit input, exercised through the testbench now. Distinguish fetched/consumed byte positions from the displayed timestamp; byte position is not elapsed playback time. Reuse the quiesce/flush/session-start path for later repositioning. A future seek controller will locate a decodable entry point with required sequence/reference context, restart parsing there, decode forward without presentation to the target, and establish a new shared A/V timeline. Timestamp-to-offset indexing, GOP/open-GOP handling and the user seek interface belong to that later milestone. Arbitrary byte jumps and simple bitrate estimates are not sufficient for accurate MPEG seeking.

## Implementation areas

- Add `rtl/media_file_reader.sv` and `rtl/media_session_control.sv` with focused testbenches and a deterministic verifier under `tools/`.
- Update `MediaPlayer_top_00.svh`, the source-file manifest and ingress FIFO interface for mount wiring, byte-valid tail handling, session events and reservoir occupancy.
- Update `MediaPlayer_av.svh` and reset/DDR integration only where required for coordinated session replacement; preserve ordinary playback behavior.
- Extend telemetry with read requests/completions, wait latency, reservoir minimum, bytes delivered, session/restart state and transport failure reason, preserving or explicitly versioning its schema.
- Extend timing constraints and fitted synchronizer audit for every new clock crossing; document user behavior and hardware test procedure.

## Validation and acceptance

Simulate delayed and bursty host responses, full downstream stalls, exact byte ordering, sector/batch boundaries, odd lengths, empty files and EOF. Exercise replacement/reset during a response and DDR activity, proving stale bytes and completions cannot contaminate the next session. Test reader starts at nonzero offsets and request suspension/resumption as transport primitives, without claiming end-user seek or pause support.

Run existing ingress, MPEG/MP2 playback, video cadence/sync and OSD regressions. Run clean seeds 52/61/87 after committing the implementation, with fitted CDC audits and explicit available operating-corner setup/hold/recovery/removal/pulse-width checks. Require a timing-qualified candidate before normal acceptance testing.

On hardware with the installed stock Main, repeatedly open/close the OSD during dense MPG and M2V playback, adjust audio/video filters, navigate the file selector, replace/restart files, and reach EOF. Check audible continuity, frame/cadence continuity, A/V sync, menu response and new transport telemetry. Confirm which Main binary actually runs because the previously read MiSTer.ini contains a `main=MiSTer_MediaPlayer` override; do not silently treat that filename as proof of either stock or custom behavior. No change to the ini is part of this proposal.

Success means menu access and filter adjustment during uninterrupted playback using stock Main, with safe repeated loads and EOF, timing passed, and the session/offset interfaces ready for later playback controls.

## Implemented choices

The reader stages up to eight 512-byte sectors (4 KiB) before emitting bytes into a 32 KiB byte/EOF FIFO. Decoder consumption begins after 4 KiB prefill, or after the EOF token has been offered for a shorter file. An ordered ninth-bit EOF token excludes sector padding and crosses the same FIFO as the payload. One outstanding host transaction is permitted. A five-second timeout records error 1 and quarantines the transaction until its late response finishes; error 2 denotes a malformed response and error 3 an unsupported size/offset. Main does not report ordinary filesystem read errors distinctly through this protocol.

Session control uses preserved three-stage request/acknowledgement synchronizers. Quiesce stops all DDR grants while the descriptor queue drains. The decoder is then held in reset; the source waits for both that acknowledgement and host retirement before releasing the FIFO and starting the next session. User reset follows this path and retains the mounted file. A cold core reset remains the global reset boundary. Opening OSD does not request quiesce or pause.

Schema 9 has 49 words at overlay origin (8,280), including the existing audio fields and eight transport words before the checksum. A coalescing mailbox carries observational transport counters atomically to the profiler; they are not playback control inputs. The 84-register fitted audit covers all configuration/session control synchronizers. Source-read suspension and offset starts are tested primitives; user-facing pause and seek remain intentionally unexposed pending the later timeline/index implementation.

Simulation validates the reader against actual hps_io slot-zero status and WIDE transfers (the bench declares two slots to avoid Icarus's single-element unpacked-array port limitation; slot one is inactive). It also validates exact tails, offsets, cancellation and timeout quarantine, DDR drain ordering, and FFmpeg video/PTS/PCM fidelity with periodic 2 ms host delays. Ingress/PCM queues in the timed integration test are ideal bounded models; physical CDC and full reconstructed video still require Quartus and hardware validation.
