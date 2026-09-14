# Production diagnostic removal plan

Status: proposed, not implemented. The user accepts b05b76f seed 87's EOF and
layout behavior. Preserve that RBF as the hardware rollback baseline:
37,410 placed ALMs, 527/553 M10Ks, 75/112 DSPs, setup +0.358 ns, hold +0.099 ns.
The later 6688db2 audio warning tolerance is simulation-tested only.

## Boundary

Remove diagnostic reporting and test hardware from the production core while
retaining everything needed to decode, synchronize, seek, drain, or reject bad
input safely. Keep simulation assertions, exact-file replay tools, pixel/PCM
oracles and archived Git source available for engineering. No new diagnostic
menu or alternate diagnostic RBF is needed. Do not delete modules by name:
several modules named `probe` and `diagnostic` contain production decoding.

## Changes, in two reviewable commits and one build batch

1. Separate functional dependencies from reporting.
   - Expose named scheduler `pending_frame_valid` and `reorder_active` outputs
     for seek/EOF instead of consuming debug_state bits 26 and 0. Preserve their
     exact logic; this is an interface cleanup, not a scheduler rewrite.
   - Trace each status output to its consumers. Keep physical EOF, input and
     PCM finished signals, generation tags, byte position, active FIFO levels,
     parser validation, transport timeouts, backpressure and DDR ownership.
   - In particular, retain `mp2_finished_sync` even when removing the adjacent
     sample-count and warning synchronizers. Keep the 90 kHz clock used by
     presentation/EOF while retiring the profiler-only one-second counter.

2. Remove reporting and standalone test hardware from the production graph.
   - Remove the cadence profiler instance, compact/detailed snapshot registers,
     snapshot-trigger timers, serializer, pixel coordinates and telemetry RGB
     overlay. Route existing framebuffer RGB directly to core video outputs;
     preserve sync/DE alignment and the separate player/subtitle overlay.
   - Remove the 256-bit media telemetry mailbox, minimum-reservoir tracking,
     reporting-only request/completion/max-wait counters, audio sample-count
     crossing and other observation-only counters/flags. Retain live reader
     timeout state, not its historical maximum statistic.
   - Remove the Audio test menu, test tone source, test-only FIFOs/control
     mailboxes/output adapter and output-selection mux. Route decoded MP2 PCM
     directly to the existing MiSTer audio ports. Leave unused status bits
     reserved to avoid renumbering saved aspect/color/refresh/subtitle settings.
   - Remove dead legacy success/LED diagnostic expressions and unused details.
     Disconnect observation-only leaf outputs so synthesis can prune their
     logic; retain simulation visibility where useful. Verify actual pruning
     in the mapped/fitted netlist rather than assuming disconnected ports save
     resources. The 6688db2 timestamp-warning adjustment needs no dedicated
     hardware build if its only consumer is removed in this work.
   - Retain fatal decode/transport checks that gate reads or inhibit a clean EOF.
     Do not turn malformed input into apparent successful completion. Reporting
     can disappear without making those conditions stop protecting playback.
   - Update files.qip, timing scripts, documentation and exact CDC audit counts
     for removed instances; retain checks for every surviving synchronizer.
     Remove only constraints whose endpoints were removed, not broad timing
     exceptions or retained safety checks.

## Validation gates

Before a hardware build, require unchanged mixed I/P/B reconstruction pixels,
PCM sample sequence and cadence, actual-file openings, pause and all seek
sizes/directions, EOF drain/new-file races, duration and subtitle lifecycle,
and full-frame player overlay checks. Cover invalid input and host/DDR stalls
so removal does not bypass cancellation, quarantine, reset or ownership rules.
Use simulation-only observers for evidence; screen telemetry is no longer a
verification mechanism. Verify old Audio test status bits cannot override PCM.

Build clean seeds 52/61/87 once both commits pass tests. Audit all four timing
corners, remaining CDC stages and fitted resources. Confirm the profiler,
telemetry mailbox and audio test generator are absent from the hardware.
Report actual placed ALMs, estimated ALMs, M10Ks and DSPs separately against
b05b76f; report measured savings, not a promised percentage. Some dead source
logic is already optimized away, and placement varies between seeds.

Hardware acceptance: use Fellow, Groove, Jiggler and Star Wars; check startup,
OSD and filters, aspect/color/refresh, pause/short/long/reverse seeks, SRT load
and cue timing, replacement movies and clean EOF at 50/59.94 Hz. Verify no
telemetry pattern or test-tone menu remains and no audio/video/UI behavior has
changed. Preserve b05b76f seed 87 until this candidate is accepted.
