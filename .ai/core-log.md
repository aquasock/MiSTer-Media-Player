## 593 COMMIT Unreleased feb50c2 2026-08-27T03:34:43-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Prepare and qualify a reproducible DVD-ceiling video fixture for the unchanged guarded-transport hardware pair.

#### Outcome:

The user-approved diagnostic source is feb50c2; it changes only the new generator and its focused tests, with no production difference from a4f2769. GUNSMOKE pulled that exact Pi-published source and generated the same 449-picture 720x480 TFF all-I scene twice using FFmpeg 8.0.1-3ubuntu2. The retained 34,919,166-byte source has SHA-256 90976c09e12dfe03243d5c8daccf65ecc98b4d0008cb5489e96c73f667434979. Both official outputs are bit-identical and match the candidate: 18,402,691 bytes, SHA-256 3e0a850a7dbbbbd05747208f97f436c8bae8120e124f05e78b8467c555a4b065. Both full software decodes produce identical YCbCr hashes, and the existing interlaced-signalling patch does not change any decoded plane. All 449 pictures remain within the admitted frame-DCT interlaced all-I structure. Encoder rate, minimum and maximum are 9,800,000 bits per second, with a 1,835,008-bit buffer matching FFmpeg's DVD-target setting. Every repeated sequence header is checked, including Main Profile/Main Level, bitrate, buffer and frame-rate extension. A narrow constant-arrival buffer witness based on H.262 6.3.9 and Annex C supplies data at exactly 9.8 Mbps, starts decoding after 140.428 milliseconds, and removes complete access units at 30000/1001 cadence. It records no underflow or overflow; peak occupancy is 1,834,992 bits, and header-delay disagreement is at most 1.657 ticks at 90 kHz, within the check's two-tick quantization allowance. The file's coded bits divided by its 14.981633-second picture duration average 9.826801 Mbps; this is not the arrival rate because initial buffering supplies bits before the first decode. Thirty-frame coded-demand windows range from 9.116763 to 10.768967 Mbps, and the largest access unit is 143,171 bytes; the buffer trajectory checks these bursts rather than incorrectly requiring every frame/window to fit a flat rate. Seven focused tests pass, covering exact cadence and EOF, underflow, overflow, delay drift and quantization, invalid inputs and access-unit prefix/end accounting. This is a scoped engineering buffering check, not a general MPEG VBV verifier or formal DVD application-conformance test. No new RTL simulation, FPGA build or ARM build was performed because production behavior is unchanged. The qualified file was staged at /media/fat/games/MediaPlayer/bbb_480i_tff_15s_9800kbps.m2v.new, completely read back on a separate FTP connection, renamed to bbb_480i_tff_15s_9800kbps.m2v and independently read back again with matching size/hash; staging absence was confirmed. Complete installed Main/RBF reads still match the qualified a4f2769 hashes. Existing media and binaries were not overwritten, and no reboot, core reload, configuration change or playback was performed. Evidence is .ai/current_results/entry593_fixture.json, entry593_qualification.json, entry593_tests.log and entry593_deployment.json; durable source, both generated copies and logs are on GUNSMOKE under /home/vash/mister-builds/entry593. Built denotes successful diagnostic generation/qualification; hardware acceptance is still pending.

#### Next Steps:

Ask the user to play bbb_480i_tff_15s_9800kbps.m2v once from games/MediaPlayer using the same installed core and display mode, without needing a reboot, and to check menu responsiveness during playback before leaving terminal telemetry displayed. Retrieve the helper log first, then a freshly triggered screenshot and full decode. Require runtime credit_fast_v1 and mode 2, all 18,402,691 source bytes delivered, all 449 pictures and 448 swaps, no transport integrity/decoder errors, normal EOF and quiet completion, zero post-startup missed deadlines/outliers and steady 2,002,000-clock intervals at 60 MHz. This fixture has an odd byte count: the final payload byte uses an acknowledged word with zero padding, so reconcile ACK words with rounded-up byte counts and distinguish any observed final transport padding from source bytes instead of reusing entry 591's all-even-chunk assumptions. Interpret schema nineteen aggregate timestamps as startup-inclusive and evaluate actual post-first-swap deadline/gap telemetry for cadence. Preserve the first run before any cold/warm follow-up, then scope the 10.08 Mbps combined-stream/audio-and-timing gate separately; passing this clip will not establish full DVD compatibility. Keep the 18.65 Mbps file optional, leave production at a4f2769, preserve its restoration copies and credit/integrity/startup/sync protections, retain user control of lifecycle and playback, keep core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_dvd_ceiling.py
- tools/streams/test_dvd_ceiling.py

#### Status:

- [x] Built
- [ ] Passed

---

## 592 COMMIT Unreleased a4f2769 2026-08-27T03:29:04-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Refocus performance acceptance on DVD-Video bitrate ceilings rather than the higher-rate diagnostic fixture.

#### Outcome:

The user clarifies that proper commercial DVD playback is the objective and asks to validate the maximum bitrate a DVD can deliver. This supersedes entry 591's proposed priority of further optimization for the 18.65 Mbps file: that file is retained as optional stress evidence, not a required DVD acceptance gate. The working SD DVD-Video targets are 9.8 Mbps for video, or 1,225,000 bytes per second, and 10.08 Mbps for the combined program stream, or 1,260,000 bytes per second. The combined rate is a shared budget, not an allowance added to video. The project reference was consulted first; it explicitly defers exact DVD application constraints to authorized DVD FLLC Part 2 and Part 3 books, which were not available. Adobe's primary DVD authoring primer, Japanese March-2004 edition, page 14, independently supports these two numerical targets at `https://www.adobe.com/jp/motion/pdfs/DVD_Primer.pdf#page=14`. This is supporting vendor guidance, not a substitute for the controlled DVD books or a formal application-conformance claim, so the restricted core and controlled reference remain unchanged. Scope, citation and validation criteria are retained in `.ai/current_results/entry592_dvd_rate_scope.json`. Entry 591 establishes clean steady playback of the 8 Mbps fixture only; neither the 9.8 Mbps video ceiling nor the 10.08 Mbps combined ceiling has been validated. Bitrate alone also does not bound decoder work or prove support for every DVD picture structure. The compressed disc-input budget must not become a hard cap on the internal helper-to-FPGA path, which can carry protocol framing and expanded decoded audio. No new fixture, source change, build, deployment, reboot, reload or playback was performed in this scope review. The qualified a4f2769 pair and restoration copies remain the baseline; Built refers to its existing qualification and Passed remains unchecked for the new ceiling target.

#### Next Steps:

Prepare a deterministic near-ceiling 9.8 Mbps video regression on GUNSMOKE within the currently supported picture subset, preserving a committed generation recipe and checking actual encoded rate, headers, buffering constraints and software decode rather than relying on the filename or encoder target alone. Validate steady nominal cadence, complete picture/byte counts, zero decoder and transport errors, startup and warm-load behavior, and menu responsiveness on hardware, leaving lifecycle and playback control with the user. Then qualify the 10.08 Mbps combined-stream budget with supported audio and timing when that boundary is ready, accounting for internal framing and decoded PCM traffic and retaining reasonable measured margin. Keep full commercial-DVD compatibility separate from this rate gate: interlaced P/B, field-picture/DCT, NTSC/PAL and film cadence, audio/PTS, navigation and other pending application features require their own coverage. Do not resume production optimization solely to pass the 18.65 Mbps stress file. If an in-scope ceiling test identifies a defect, propose a bounded revision based on that evidence while preserving credits, integrity checks, queue capacities, guarded startup, continuous HDMI sync and black idle. Keep core.md unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 591 COMMIT Unreleased a4f2769 2026-08-27T03:21:12-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Validate the guarded transport on the qualified 8 Mbps elementary stream after a warm file load.

#### Outcome:

The user reports running the requested file without rebooting and says playback looked good. The helper log identifies `bbb_480i_tff_15s_8mbps.m2v`, runtime `transport=credit_fast_v1` and mode 2; its new child/session data and the unchanged 10:08:35 UTC Linux boot corroborate a new run without an intervening system reboot. This does not independently establish whether a core reload or mode switch occurred. The log was collected before a fresh screenshot, and complete host/FPGA readbacks retain both qualified `a4f2769` hashes. All 15,150,646 bytes, 449 reference/display pictures and 448 swaps complete with zero aggregate errors, no transport integrity abort, normal helper exit, sequence end and quiet terminal presentation. All 925 chunk byte totals, fast/slow counts, batch/query totals and fourteen payload-ACK samples reconcile. Fast transfers carry 15,029,026 bytes, or 99.1973 percent; 121,620 bytes use acknowledged single-word progress. There are zero actual post-startup deadline misses, zero cadence outliers and no retained missed-deadline records. The three largest measured post-first-swap intervals are exactly 2,002,000 decoder clocks, or 33.366667 milliseconds, matching steady 29.970030-fps cadence and the qualified entry-564 8 Mbps acceptance. The raw aggregate is 29.891489 fps across 14.987544 seconds because schema nineteen assigns its starting timestamp on first reference completion, before visible release, so it includes startup reserve and raster alignment; its 39.277-millisecond excess over 448 nominal intervals is not evidence of steady slowdown. This also corrects entry 590's description of its aggregate as first-to-last presentation and its implication that the entire excess duration was cadence delay: those aggregate measurements include startup, but that run's 77 actual post-startup missed intervals and 66.733-millisecond maximum gaps still independently establish remaining high-bitrate lateness. Matched delivery averages 1,016,885 B/s, paced by this smaller stream's downstream consumption rather than establishing raw link capacity. The host issues 885,783 fast batches averaging 16.967 bytes and 947,518 status queries; this confirms small available-credit grants under steady consumption, not a throughput regression compared with the larger file. All 340 helper EAGAIN events occur before first delivery. Data-bearing polls average 64.028 milliseconds and peak at 114.117 milliseconds; these measure Main-loop blocking exposure, and current menu responsiveness is still not separately confirmed by the user's visual report. Capture, complete decode, checked analysis and prior qualified-file comparison are preserved as `.ai/current_results/entry591_*`. No source, deployed binary, configuration, lifecycle or playback action was changed during collection. This entry passes the scoped warm 8 Mbps hardware regression and preserves its prior steady cadence; it does not pass the high-bitrate fixture, all display modes, arbitrary cancellation or the remaining unsupported feature set.

#### Next Steps:

Retain `a4f2769` and the restoration pair as the tested guarded-transport baseline, with entry 590 preserving the larger-file improvement and entry 591 closing the requested warm 8 Mbps regression. Obtain a separate report of menu responsiveness during playback without requesting another identical file run unless a new diagnostic question requires it. For further performance work, propose and obtain approval for a focused investigation of the remaining high-bitrate decoder-side processing/backpressure, using the retained ready/input/writer evidence to distinguish internal decode waits from output pressure and status-query overhead before changing production behavior. Preserve credit and integrity checks, both FIFO sizes, guarded startup, continuous HDMI sync and black idle. Keep unsupported interlaced P/B, field-picture/DCT, audio/PTS, mode-switch/cancellation coverage and historical assertion drift explicitly outside this acceptance, leave reboot/playback control with the user, keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 590 COMMIT Unreleased a4f2769 2026-08-27T03:13:17-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Verify guarded fast-block activation and measure the first high-bitrate hardware run against the acknowledged baseline.

#### Outcome:

The user reports no visible slowdown. The helper log was retrieved first, followed by a freshly triggered screenshot and complete host/FPGA readbacks; both installed hashes match qualified `a4f2769`, and a new Linux boot at 10:08:35 UTC plus runtime `transport=credit_fast_v1` and mode 2 corroborate activation. All 34,919,166 bytes, 449 pictures and 448 swaps complete with zero decoder error flags, normal helper exit, sequence end and quiet terminal presentation. There is no transport integrity abort, and all 2,132 logged chunk byte/count/checksum completions and batch/query totals reconcile. Fast transfers carry 34,896,748 bytes, or 99.9358 percent; the remaining 22,418 bytes use acknowledged single-word progress at zero credit. Compared with entry 587, matched completed-chunk delivery rises from 1,578,252 to 1,988,891 B/s, a 26.02 percent gain, and cadence rises from 20.248749 to 25.507040 fps. The first-to-last presentation span falls from 22.124823 to 17.563778 seconds, while complete transfer-call time falls from 21.202251 to 16.624084 seconds. Delayed eventual presentation intervals fall from 167 to 77, and the three longest retained gaps are now 66.733 milliseconds instead of a maximum 166.833 milliseconds, a 60 percent reduction consistent with the user's improved perception. Strict 30000/1001 cadence is still not met: 448 intervals would take 14.948267 seconds at nominal rate, 2.615512 seconds less than observed. The cause visible in retained deadlines has changed: the first three delayed deadlines, full-width picture ordinals 8, 11 and 14, now have both decoder input and upstream FIFO input pending, decoder not ready, zero input-starvation cycles and no presentation/destination hold; their writer-capacity blocked counts are 127, 36 and 215 cycles. Prior retained misses had ready-but-empty decoder input. The gated upstream-pending/decoder-not-ready counter covers 95.8468 percent of captured session cycles, supporting a shift toward decoder-side processing or backpressure, but it does not identify a specific arithmetic stage or exclude internal waits. Only three delayed-deadline records are retained, so their cause must not be assigned to all 77 late intervals. Host grants are predominantly small after initial 8 KiB batches: 791,350 fast batches average 44.10 bytes, with 804,691 status queries containing 5,632,837 acknowledged status-word transactions. FIFO consumption now governs small grants, and query overhead may matter; the log does not separate raw bus time, status time and downstream wait time. The 1.989 MB/s consumption-limited average is not a raw link-capacity measurement, and no 10 MB/s claim is established. All 587 helper EAGAIN events precede first delivery. Mean data-bearing poll duration improves to 32.768 milliseconds, but the maximum remains 81.485 milliseconds; these are blocking exposure rather than measured UI response, and current menu responsiveness has not been separately reported. The eight-bit largest-gap ordinals remain ambiguous after 256 pictures; do not confuse them with full-width deadline ordinals. Capture, decoded packet, helper log and checked comparison are stored as `.ai/current_results/entry590_*`. No production source, installed binary, configuration, reboot, reload or playback was changed during collection. Transport functionality and substantial improvement are verified, but full high-bitrate cadence acceptance and the separate 8 Mbps regression remain outstanding.

#### Next Steps:

With this high-bitrate evidence preserved, ask the user to play `bbb_480i_tff_15s_8mbps.m2v` once using the same installed pair and display mode, leave telemetry displayed, and report whether the menu remains responsive. Collect its helper log before another playback, then a fresh screenshot and image checks; verify mode 2, complete byte/picture counts, no integrity/decoder errors and cadence. Keep the guarded credit and integrity protocol, both FIFO capacities, startup controller, continuous HDMI sync and black idle unchanged. Before any further decoder or transport revision, propose a focused boundary and obtain approval; the current evidence points toward downstream processing/backpressure but does not yet isolate an internal stage or justify removing safeguards. Preserve the restoration copies and outstanding unsupported interlaced P/B, field-picture/DCT, audio/PTS, cancellation and historical assertion-drift limits. Keep restricted `core.md` unchanged, retain the forty-entry ring and do not mark nominal-cadence acceptance passed from the user's visual report alone.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 589 COMMIT Unreleased a4f2769 2026-08-27T03:07:27-07:00

#### Coming From:

Unreleased a4f2769

#### Purpose:

Deploy the qualified guarded fast-block host and FPGA pair after MiSTer connectivity is restored.

#### Outcome:

The user reports that the MiSTer is connected, and FTP access to `10.10.0.30` succeeds. The active predecessors match the expected `be8502b` host and `2acabc5` FPGA hashes. Both complete images were retrieved and fsynced locally, then retained and independently hash-verified and fsynced under `/home/vash/mister-builds/entry588-backup` on GUNSMOKE as `MiSTer.prea4f2769` and `MediaPlayer.rbf.prea4f2769`. A read-only backup attempt exposed FTP transfer-mode handling after a directory listing; the procedural scripts were corrected and the complete backup pass repeated before deployment, without changing production source or artifacts. The qualified `a4f2769` candidates were staged at `/media/fat/MiSTer.new` and `/media/fat/MediaPlayer.rbf.new`, and both passed complete fresh-connection readbacks and permission checks before either rename. The active predecessors were reverified immediately before replacement. Each file rename is atomic; the pair is not, but both mixed-version combinations preserve acknowledged transfers. A further independent FTP connection verified both complete active files, executable permissions and absence of both staging paths. Installed `/media/fat/MiSTer` is 1,170,340 bytes with SHA-256 `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`; installed `/media/fat/MediaPlayer.rbf` is 4,332,748 bytes with SHA-256 `15bc3057a4f16369bc4a3dac01e30f63e5fc563a43b1922214b5b478c17c66c2`. Deployment evidence and restoration details are in `.ai/current_results/entry589_deployment.json`; corrected procedural scripts remain under `/home/vash/mister-builds/entry588/resume-scripts`. Entry 588's clean builds, regressions and positive timing qualification remain applicable; no rebuild or production change was needed. No reboot, core reload, playback, helper replacement or configuration edit occurred. The new files are installed, but runtime activation, performance and hardware acceptance are not yet verified.

#### Next Steps:

Have the user cold-power-cycle the MiSTer, load MediaPlayer and play `bbb_480i_tff_15s.m2v` once, then leave terminal telemetry displayed without replaying or running the 8 Mbps file yet. Collect `/tmp/MediaPlayer_ARM.log` first, then a fresh screenshot and complete installed-image readbacks; require a new boot, marker `transport=credit_fast_v1`, transport mode 2 with nonzero fast bytes, no integrity fault, all 34,919,166 bytes, 449 pictures, 448 swaps and zero decoder errors. Compare delivery rate, transfer time, cadence and delayed intervals against entry 587's 1,578,252 B/s, 21.202251 seconds, 20.248749 fps and 167 delayed intervals, and ask whether the meadow slowdown and menu responsiveness changed. Preserve this capture before the separate qualified 8 Mbps regression. Treat 10 MB/s as the user's earlier guess and decoder-bound playback as an unverified hypothesis. Preserve startup, continuous HDMI sync, black idle, both queue capacities and existing unsupported-feature limits; retain the restoration pair, standing qualified-deployment permission and user control of reboot/playback. Keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 588 COMMIT Unreleased a4f2769 2026-08-27T02:59:27-07:00

#### Coming From:

Unreleased be8502b

#### Purpose:

Enable bounded fast-block media transfers using FPGA FIFO credits and post-batch integrity checks while preserving the acknowledged legacy path.

#### Outcome:

The approved coordinated implementation is source `a4f2769`. Main remains the sole FPGA I/O owner and uses the existing fast-block primitive only after an opt-in status query grants conservative input-FIFO credit, capped at 4096 words; commands and status remain acknowledged. Coherent snapshots expose credit, accepted-word count, a rolling 16-bit rotate/XOR checksum and ready/overflow flags. Main verifies every batch before additional data, aborts on mismatches without retrying uncertain bytes, preserves legacy/narrow/unaligned/odd-tail handling and uses one acknowledged word of progress when credit is zero. Session state resets even when logging is unavailable, and runtime telemetry distinguishes fast bytes, slow bytes, batch/query totals and detailed fault observations with marker `transport=credit_fast_v1`. The checksum can collide and is not a cryptographic integrity guarantee. The vendor Cyclone V model exposed a real near-full hazard: after a partial-byte read, a wrapped zero write-used count could advertise empty capacity before the count caught up. Credit now trusts a zero count only when write-domain empty agrees. Both literal-default and Cyclone V vendor models pass 26,878 credit batches each, full and partial-byte transitions, asynchronous clock ratios, pointer wrap, reset readiness, sticky overflow attempts and exact byte/count/checksum checks; effective modeled full capacity is respectively 32,766 and 32,768 bytes. The existing 32-word nominal reserve remains, giving at least 31 words relative to the default model's effective capacity. Real-host/extracted handshake and FIO qualification passes 288 guarded cases across narrow, legacy-wide and capable-wide configurations at four modeled register delays, plus 168 original-versus-ACK-bulk cases in each of the three configurations and explicit zero/full-credit, counter-wrap, coherent-snapshot, lost/corrupt-word, reset, bad credit/count/digest/capability and no-second-batch fault cases. Forty native ACK transport cases and complete loader scenarios pass both normally and under ASan/UBSan; RTL simulations are not sanitizer-instrumented. These model timings are protocol stress conditions, not physical throughput estimates. GUNSMOKE pulled the exact Pi-published source, matched candidate files and repeated official qualification. The existing native-video suite passes startup, field order, presentation overlap, sync/reset, cache/fingerprint/generation and cadence packet checks; the clean-video queue test passes 85,696 bytes, four metadata records and three PCM samples. The clean ARM build using pinned Main `0a8fb44` and official GCC 10.2.1 completes in 4.43 seconds with zero warnings/errors, producing 1,170,340 bytes and SHA-256 `3841e2cc6eef4bfc9e46a7ffa075aff76b65d5405f81efb1355373292b35846f`. The clean Quartus 17.0.2 seed-16 build completes in 712.06 seconds with 0 errors and 208 warnings; reviewed worst slacks are setup 0.217 ns, hold 0.249 ns, recovery 3.559 ns, removal 0.574 ns, minimum pulse width 0.925 ns, all TNS are zero and no new ignored timing filters appear; normalized warning messages are identical to the baseline. FPGA output is 4,332,748 bytes with SHA-256 `15bc3057a4f16369bc4a3dac01e30f63e5fc563a43b1922214b5b478c17c66c2`. Deployment could not begin because the MiSTer at `10.10.0.30` was unreachable from the Pi; the attempted FTP connection failed before login or any remote write. No predecessor backup was collected this cycle and neither candidate was installed. The user was asked to power on or reconnect the MiSTer and leave it at the menu. Qualified candidates and reports remain under `/home/vash/mister-builds/entry588` on GUNSMOKE, with matching Pi copies under `/tmp/entry588-reports`. The previously deployed host remains the last verified `be8502b` and FPGA `2acabc5`; current device state has not been reverified. Evidence is retained as `.ai/current_results/entry588_*`. The ingest FIFO capacity, separate 64 KiB clean-video queue, startup controller, decoder arithmetic, continuous HDMI sync and black idle are unchanged. The user's earlier 10 MB/s figure remains only a guess, and decoder-bound playback remains a hypothesis. Hardware acceptance is not claimed.

#### Next Steps:

Once the user restores MiSTer connectivity at `10.10.0.30`, resume verified paired deployment under standing permission without changing source: retrieve and hash-check the active predecessors, retain fsynced local and persistent GUNSMOKE restoration copies, stage and independently read back both candidates, rename and independently verify the complete active files and permissions. Leave lifecycle control with the user, then request one cold run of `bbb_480i_tff_15s.m2v`. Collect its log before a fresh screenshot, require `transport=credit_fast_v1`, mode 2, nonzero fast bytes, no integrity fault and complete byte/picture counts, and compare delivery/cadence with entry 587. Capture that run before the outstanding qualified 8 Mbps regression; no speedup or decoder-bound claim is established yet. Retain prior unsupported interlaced P/B, field-picture/DCT, audio/PTS, cancellation and assertion-drift limitations, keep restricted `core.md` unchanged and maintain the forty-entry ring.

#### Files Modified:

- MediaPlayer_top_00.svh
- host/arm/ARCHITECTURE.md
- host/main_mister/0001-mediaplayer-arm-loader.patch
- rtl/mpeg2_stream_fifo.sv
- sys/hps_io.sv
- tools/streams/tb_mpeg2_stream_fifo_burst.sv
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 587 COMMIT Unreleased be8502b 2026-08-27T02:22:06-07:00

#### Coming From:

Unreleased be8502b

#### Purpose:

Measure the first hardware run of the acknowledged bulk preload path and determine whether its host-side savings resolve high-bitrate playback.

#### Outcome:

The user reports that everything looks the same and leaves the image ready. The helper log was collected first, followed by a freshly triggered screenshot and complete host/FPGA readbacks. A new Linux boot at 09:17:15 UTC and runtime `transport=ack_bulk_preload_v1` establish activation of `be8502b`; the complete installed host hash remains `da213d6bd9cc89a9af736a0bb029f9ebadd6e6a62382728ae1bacc07a381f909`, and FPGA `2acabc5` is unchanged. All 34,919,166 bytes, 449 pictures and 448 swaps complete with zero decoder error flags, normal helper exit and a quiet completed presentation. There is a real but insufficient measured gain over entry 585: matched completed-chunk delivery rises from 1,427,221 to 1,578,252 bytes per second, or 10.58 percent, while cadence improves from 18.315332 to 20.248749 fps and from 24.460381 to 22.124823 seconds. Delayed presentation intervals fall from 186 to 167, but the two largest retained holds remain 166.833 milliseconds, consistent with the user's lack of perceptible improvement. The median unsampled full 16 KiB transfer falls from 10,780 to 9,196 microseconds, confirming that the changed word loop saved time; complete transfer-call duration falls from 23.585322 to 21.202251 seconds. Transfers and ACK waits still consume 96.36 percent of measured media-poll time, whereas pipe reads consume 0.724867 seconds or 3.29 percent. All 590 EAGAIN events occur before the first completed chunk. The 533 data-bearing polls average 41.273 milliseconds, but the maximum poll remains 81.209 milliseconds; these are blocking exposure rather than direct UI latency. Across the same 270,336 sampled words, extended ACK-low polling now occurs in seven of thirty-three chunks rather than one, with a maximum of 76 GPI reads and no uninitialized indication. Faster delivery meeting downstream flow control more often is plausible, but samples do not measure total FIFO-wait duration or establish its precise cause. The first three retained delayed deadlines find decoder input ready but empty and upstream FIFO empty; their writer-capacity blocked counts are 22, zero and 255 cycles, not all zero. The aggregate decoder-stall counter increases, but RTL gates that count on input pending and decoder not ready, so greater input availability can change its coverage and this alone is not evidence of a decoder regression. Supply remains only 67.71 percent of the file's average demand, requiring another 47.68 percent increase merely to meet that average; the largest meadow picture still needs about 161 milliseconds of bytes at this mean rate against 33.367 milliseconds per nominal frame. Preserve the eight-bit largest-gap ordinal ambiguity: raw codes 95, 98 and 15 are not unique absolute positions in this 449-picture file. The old spikes problem remains historical progressive bring-up context, not the current comparison. Capture, helper log, full decode and checked analysis are stored as `.ai/current_results/entry587_*`; no source, deployed binary, media, configuration or lifecycle was changed. Hardware cadence acceptance still fails, and neither the qualified 8 Mbps regression nor a separate current menu assessment is claimed. The user also asks about another agent's alternative delivery path and a possible 10 MB/s rate. Entries 579 and 580 identify the likely reference as `spi_block_write` through `fpga_spi_fast_block_write`, which uses the same physical GPIO-style link but omits per-word ACK reads; entry 581 already explains why that cannot be substituted without FIFO flow control. The present preload path still waits for both ACK phases. The helper currently writes to a pipe and Main owns FPGA I/O, so this is a Main transport choice rather than an existing direct-helper mode. Main also has lightweight-bridge register access, but a dedicated receiver or shared-memory/DMA route would be a distinct implementation. No measured 10 MB/s result for this target was found in the reviewed evidence, and that figure must remain unverified.

#### Next Steps:

Do not repeat the same hardware condition or expect another minor host-loop reduction to provide the missing throughput. Prefer investigating the existing fast-block primitive with an explicitly approved coordinated host/FPGA transport change that amortizes acknowledgements across bounded bursts backed by conservatively reported ingest-FIFO capacity, with documented strobe ordering and drain guarantees, reset and legacy fallback behavior, and overflow plus byte-count verification. The existing ingest FIFO is a separate 32 KiB mixed-width FIFO; preserve the 64 KiB clean-video queue and do not confuse or enlarge the two as a substitute for transport work. Qualification must include protocol and clock-domain/backpressure tests, the full relevant FPGA regressions, a clean Quartus build and timing review before deployment; faster transport must not be promised to remove every downstream decoder limit. Obtain approval before implementing that material protocol revision, while retaining standing publication and qualified deployment permissions. Keep `be8502b` as the current measured comparison point, preserve startup, continuous HDMI sync and black idle behavior, leave reboot and playback to the user, and retain the outstanding 8 Mbps and unsupported-feature boundaries. Keep restricted `core.md` unchanged and preserve the forty-entry ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 586 COMMIT Unreleased be8502b 2026-08-27T02:05:53-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Reduce MediaPlayer host transfer overhead with a bulk word loop that preloads the next payload during the acknowledged low phase while preserving FPGA flow control.

#### Outcome:

The approved host-only implementation is source `be8502b`. MediaPlayer now uses a dedicated bulk primitive that prepares the next payload only after the current word's ACK-high, lowers the strobe with that payload and waits for ACK-low before its next rising edge. The ordinary non-media transfer and `fpga_spi` functions remain byte-identical to pinned upstream Main_MiSTer `0a8fb44`; no FPGA source or image was changed. For a full 16 KiB wide chunk the data loop issues 16,385 GPO writes instead of 24,576, retaining both ACK phases, final low-clock cached state, little-endian packing, unaligned input safety, padded odd tails and narrow transfers. Sampled and unsampled template specializations retain every-sixty-fourth-chunk ACK profiling, and logs identify `transport=ack_bulk_preload_v1`. Forty native transport cases pass, including unchanged rising-edge payloads and ACK-read traces, exact write counts, final GPO and reset exits at the first, middle and final word; the uninitialized messages in these test reports are deliberate injected cases. Loader coverage retains four-read polling, byte identity, sampling, EAGAIN, EOF accounting, errno preservation, warm reset, core change, external stop and unavailable diagnostics. Native tests pass both normally and under ASan/UBSan. A new optional RTL mode compiles the actual clock/ACK and download blocks extracted from existing `sys_top.v` and `hps_io.sv` with Verilator, then runs both original and bulk host functions against 168 narrow and 168 wide cases with four bridge latencies, a two-word sink that reaches full, independent wait and vs_wait intervals, consecutive chunks, odd tails, exact download addresses and release. All pass; an initial simulator teardown failure after passing narrow cases was fixed by destroying the model before the thread-local Verilator context, without changing production logic. After source publication from the Pi, GUNSMOKE pulled exact `be8502b`, verified both source hashes against the tested candidate, repeated all qualification and built from zero generated objects with official ARM GNU 10.2.1 20201103. The clean compile completed in 4.17 seconds with zero compiler warnings or errors, producing a 1,166,244-byte ARMv7 hard-float binary with SHA-256 `da213d6bd9cc89a9af736a0bb029f9ebadd6e6a62382728ae1bacc07a381f909`. Its complete Pi copy matches the build report. The previous `32ba178` host image was retrieved, hashed and fsynced locally, then retained and independently verified at `/home/vash/mister-builds/entry586-backup/MiSTer.prebe8502b` on GUNSMOKE. The candidate was staged at `/media/fat/MiSTer.new`, read back through a fresh FTP connection and verified executable before rename; another fresh connection retrieved the active binary with exact matching bytes and hash, confirmed executable permissions and absence of the stage. Full FPGA readbacks before and after retain the qualified `2acabc5` hash. No reboot, core reload, playback, helper or configuration change occurred. Build, regression and deployment records are retained under `.ai/current_results/entry586_*`. This is a tested and deployed optimization candidate, not yet an active-process verification, measured speedup or hardware acceptance; simulator bridge delays are test conditions rather than a physical performance model.

#### Next Steps:

Have the user power-cycle, load the core and play `bbb_480i_tff_15s.m2v` once, then stop without replaying and leave terminal telemetry displayed. Fetch the helper log before the screenshot, verify a new boot and `transport=ack_bulk_preload_v1`, and compare delivery, transfer duration, sampled ACK behavior and cadence against entry 585's 1,427,221 bytes per second, 23.585322 seconds of transfer, 18.315332 fps and 186 delayed presentation intervals. Confirm full byte/picture counts, zero error flags, whether the meadow slowdown improves and current menu responsiveness. Collect that run before requesting the separate qualified 8 Mbps regression so its log is not overwritten. The reduced register-write count is not a promise to meet the file's 2.33 MB/s demand; if host-only headroom is insufficient, propose an explicitly approved FPGA transport revision rather than removing ACK protection. Preserve the existing startup controller, 64 KiB clean-video queue, continuous HDMI sync and black idle behavior, and retain all prior unsupported interlaced, audio/PTS, cancellation and assertion-drift limitations. Continue routine publication and qualified host deployment under standing permission with backup/readback safeguards, keep reboot and playback with the user and preserve restricted `core.md` plus the forty-entry ring.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 585 COMMIT Unreleased 32ba178 2026-08-27T01:59:36-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Validate the first cold profiling run and identify whether helper reads, acknowledged FPGA transfers or other main-loop work dominate high-bitrate playback.

#### Outcome:

After the user reported the screen ready, the helper log was fetched before a fresh terminal screenshot. Syslog records a new Linux boot at 08:52:25 UTC versus entry 581's 08:23:32; it corroborates the requested reboot but does not independently prove power removal or playback count. The runtime log contains `profile_version=1`, and full host and FPGA readbacks retain entry 584's expected hashes, establishing that host source `32ba178` is now running against unchanged FPGA `2acabc5`. All 34,919,166 bytes and 449 pictures complete, with 448 swaps, zero decoder error flags, normal helper exit and quiet completed presentation. Cadence still fails: 24.460381 seconds, 18.315332 fps and 186 delayed presentation intervals, compared with entry 581's 18.335712 fps and 185 intervals. Matched completed-chunk endpoints yield 1,427,221 bytes per second, only 0.049 percent below the prior run and far below the file's 2,330,798-byte-per-second average demand. Profiling directly separates the cost: 2,132 transfers consume 23.585322 seconds, or 96.68 percent of 24.394209 seconds inside media polls; all pipe reads consume 0.730964 seconds, or 3.00 percent, and other measured in-poll work accounts for 0.077923 seconds. The 485 EAGAIN events all precede the first successful chunk. Actual accounting records 533 data-bearing polls, averaging 45.759 milliseconds with an 80.498-millisecond maximum across all polls; these are blocking exposure, not direct UI latency. Thirty-three sampled chunks cover 270,336 words. In 32 chunks both ACK phases require at most two GPI reads per word, with nearly two reads typical; high or low wait-word counts merely mean more than one read and must not be mislabeled FIFO-full stalls. Sample event 768 is exceptional: ACK-low takes up to 72 reads, totaling 55,330 low-phase reads across 8,192 words, and nearby unsampled transfers also slow. This confirms actual extended ACK polling while leaving the cause and unsampled wait distribution unresolved. The ordinary handshake and bridge path therefore remain the useful optimization target, but eliminating flow control is unsafe. The first successful read occurs 39.694 milliseconds after download assertion and the first entire chunk completes at 51.494 milliseconds, keeping the legacy first-byte label distinct. Sampled full chunks have a 3.66 percent higher median transfer cost than unsampled chunks; these are unpaired measurements, and one nearly unchanged aggregate run cannot quantify instrumentation overhead. The retained first three delayed deadlines show ready-but-empty decoder input and empty upstream FIFO, with writer-capacity blocking of zero, zero and nine cycles. The user's earlier responsive-menu observation belongs to entry 581; current menu responsiveness remains unreported. The user subsequently identified the meadow as the current worst section and clarified that the spikes comparison refers to old progressive bring-up, not another recent run. Build-PC frame extraction from the hash-verified fixture identifies picture 350 as dense ground foliage viewed from above, with the clip's largest encoded span of 253,632 bytes, requiring about 178 milliseconds at measured mean supply against 33.367 milliseconds per nominal frame. This supports the reported meadow slowdown without establishing a relation to the old progressive issue. A source-review correction is also required: the largest-gap metadata holds only an eight-bit picture ordinal, so raw codes 93, 94 and 95 are ambiguous between pictures 93 through 95 and 349 through 351 in this 449-picture clip; the wrapped candidates coincide with the largest pictures and reported meadow scene, but the snapshot alone cannot prove that mapping. The three retained largest intervals are each 166.833 milliseconds. Capture, decode, helper log and checked analysis are retained as `.ai/current_results/entry585_*`. No production source, deployed binary, configuration or lifecycle was changed; the profiling works as a diagnostic, but smooth-playback acceptance and the qualified 8 Mbps regression remain outstanding.

#### Next Steps:

Prepare the next approved implementation boundary around a flow-controlled bulk transfer path that reduces per-word bridge overhead while preserving ACK/backpressure, byte order, odd tails, core readiness and reset handling, and ordinary non-media transports. Do not increase buffers again or substitute unchecked fast writes. Establish protocol and byte-trace equivalence plus delayed-backpressure tests and build with the official ARM toolchain before qualified host deployment; if adequate headroom requires an FPGA transport-protocol change, obtain approval for that material revision before implementing it. Retain the user's standing evidence/source publication and host-deployment permissions without repeating those questions, while keeping backup, staging and independent readback safeguards. Do not request another identical hardware run merely for statistics. After a changed candidate is available, validate one high-bitrate run and the outstanding qualified 8 Mbps case, and confirm whether the meadow slowdown improves and obtain a current menu-responsiveness report. Keep the existing startup controller, 64 KiB clean-video queue, continuous HDMI sync and black idle behavior unchanged, leave reboot and playback to the user, preserve restricted `core.md` and the forty-entry ring, and retain the unresolved interlaced, audio/PTS, cancellation and assertion-drift limitations from prior entries.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 584 COMMIT Unreleased 32ba178 2026-08-27T01:52:36-07:00

#### Coming From:

Unreleased 32ba178

#### Purpose:

Publish and install the verified host-transfer profiling build and record standing user authorization for future source publication and host deployment.

#### Outcome:

The user explicitly approved publishing the profiling source to GitHub and installing the host binary with backup and full readback, then stated that approval is not needed going forward. This extends entry 582's evidence-publication permission to source-code publication in `aquasock/MiSTer-Media-Player` and qualified host-system-binary replacement during approved project development, without repeating publication or deployment permission questions; preserve build and regression qualification, restoration data, staged verification and independent active readback. Existing requirements to keep `core.md` restricted, obtain approval for materially revised development plans and leave reboot or playback to the user remain unchanged. Source `32ba178` and its build report were pushed from the Pi, and GUNSMOKE pulled published master `41cb150`; both source-file hashes and the complete candidate binary were verified against the exact tested build, resolving entry 583's unpublished-candidate limitation without changing its source. Before writing to the target, the current 1,166,244-byte `/media/fat/MiSTer` was fully retrieved, checked against the server size and SHA-256 `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`, flushed to local disk, then copied and independently re-hashed in persistent storage at `/home/vash/mister-builds/entry584-backup/MiSTer.pre32ba178` on GUNSMOKE. The profiling candidate was uploaded to the previously absent `/media/fat/MiSTer.new`, read back completely through a fresh FTP session, checked byte-for-byte and confirmed executable before being renamed over `/media/fat/MiSTer`. The predecessor hash was rechecked immediately before rename. A separate fresh session then retrieved the complete active file: all 1,166,244 bytes match SHA-256 `1aae53b0209e873b1edfe20f60bad10c2c4cd5ce1e21f7f40eea81be313facb9`, permissions remain `-rwxr-xr-x` and no staging file remains. Full FPGA readbacks before and after retain the qualified `2acabc5` hash `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`. No helper, media, configuration, core lifecycle or Linux lifecycle was changed. The running host process retains its old inode until the user reboots, so this records verified deployment rather than runtime activation, throughput improvement or hardware acceptance. The deployment manifest is `.ai/current_results/entry584_deployment.json`; the latest hardware observation remains entry 581 with the subsequently confirmed responsive menu.

#### Next Steps:

Have the user power-cycle the MiSTer, load the core and play `bbb_480i_tff_15s.m2v` once under the same conditions as entry 581, then stop without replaying and leave terminal telemetry displayed. Fetch `/tmp/MediaPlayer_ARM.log` before the screenshot and verify the new boot plus `profile_version=1`, per-read timing and sampled ACK records to establish runtime activation. Compare separate read and transfer durations, actual data-bearing poll timing, ACK read distributions and cadence with the prior 16 KiB run before selecting an optimization; retain the profiling overhead and sampling limitations from entry 583. Full byte and picture counts, error status and interface responsiveness still gate acceptance, and the qualified 8 Mbps regression remains outstanding. Apply the new standing publication and host-deployment permission to subsequent approved cycles without asking again for those routine actions, while retaining the verification safeguards and keeping the FPGA startup, queue, sync and timing unchanged unless a separate plan is approved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 583 COMMIT Unreleased 32ba178 2026-08-27T01:37:49-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Separate helper pipe-read time, acknowledged FPGA-transfer cost and main-loop blocking with bounded host-side profiling.

#### Outcome:

Local source `32ba178` implements the approved host profiling in the existing pinned Main_MiSTer integration patch and adds one focused regression. The 16 KiB buffer, four-chunk limit, ordinary unsampled transfer function, both ACK phases and odd-byte handling are preserved. Per-read records separate pipe-read and complete-transfer time; session summaries count actual polls, data-bearing polls, time inside polls and entry intervals. Every sixty-fourth successful read uses a separately instrumented mirror of the acknowledged word function, reporting high and low ACK-read totals, wait-word counts and maxima without additional register accesses or per-word clocks or logging. First successful pipe read is now distinguished from the legacy first-byte label, which still means first completed chunk. Tests compile the real patched functions against deterministic mocks: fourteen transport cases match the upstream register and framing trace for delayed ACKs, wide and narrow lengths, odd tails and uninitialized-FPGA exits, while the loader test verifies a sixty-six-chunk session, byte identity, sampling, four-read budget, EAGAIN, errno preservation, EOF accounting, idle behavior, warm reset, core change, external stop and unavailable diagnostic output. Both ordinary and address/undefined-behavior sanitizer runs pass, including a repeat against the exact committed candidate archive on GUNSMOKE. The user confirms that the menu remained responsive during entry 581's video playback. Source publication was separately blocked by the execution approval policy because entry 582 authorizes evidence publication but not new source-code publication; no attempt was made to bypass that gate. The build PC pulled published master `7eca031`, then an isolated candidate build used the exact unpublished `32ba178` archive against Main_MiSTer `0a8fb44` with official ARM GNU 10.2.1 20201103. It compiled 113 source files from an empty generated-object state in 4.11 seconds with zero compiler warnings or errors, producing a 1,166,244-byte ARMv7 hard-float binary with SHA-256 `1aae53b0209e873b1edfe20f60bad10c2c4cd5ce1e21f7f40eea81be313facb9`; its Pi scratch copy matches exactly and the expected profiling strings are present. The only unrelated upstream difference is a non-source miniz changelog line-ending conversion. Build, ordinary-test and sanitized-test reports plus the compiler log are retained under `.ai/current_results/entry583_*`, with the isolated build at `/home/vash/mister-builds/entry583-32ba178` and candidate Pi binary at `/tmp/entry583-reports/MiSTer`. This is a diagnostic candidate, not a throughput fix or hardware acceptance. Clock and logging overhead remain unmeasured on hardware, sampled ACK counts are not direct wait durations and may miss unsampled stalls, and poll intervals are not direct UI latency. No MiSTer binary, helper, FPGA image, configuration or lifecycle was changed.

#### Next Steps:

Obtain explicit approval to publish the two profiling source files to `aquasock/MiSTer-Media-Player` and to replace the host-system binary `/media/fat/MiSTer`; these are separate from standing evidence-publication and RBF permissions. Once approved, publish the local source and build-result commits from the Pi, verify GitHub and build-PC source identity, retain and hash the current host binary, stage the verified candidate, independently check the staged bytes, rename over the active path and read back the complete active image through a fresh FTP session. Leave reboot and playback to the user. Request one cold high-bitrate run, fetch the helper log before the screenshot and inspect read time, transfer time, sampled ACK loops and actual media-poll timing before choosing a correction. Confirm complete byte and picture counts, unchanged error status and whether instrumentation materially changes cadence. Retain the pending 8 Mbps regression and preserve FIFO backpressure, byte order, odd tails and the unchanged FPGA startup, queue, sync and timing behavior. Do not publish local commits or deploy the host binary until their explicit approvals are obtained.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch
- tools/streams/test_main_mister_profile.py

#### Status:

- [x] Built
- [ ] Passed

---

## 582 COMMIT Unreleased ad364bf 2026-08-27T01:33:33-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Record standing user authorization to publish this project's diagnostic evidence and project-log updates to its GitHub repository.

#### Outcome:

After entry 581's publication was blocked pending explicit consent for its diagnostic logs and screen content, the user approved uploading those files and the log update to `aquasock/MiSTer-Media-Player` and stated that this may be done automatically going forward. This is standing authorization to commit and push project-related diagnostic logs, telemetry captures and screenshots, associated analysis and project-log updates to that same GitHub repository during the normal project workflow, without asking separately for publication each time. Continue to inspect the payload and exclude credentials, private keys and unrelated personal or system data. This approval concerns evidence publication; it does not approve the proposed host-transfer profiling or optimization cycle, replacement of the MiSTer system binary, new hardware actions or edits to restricted `core.md`. Entry 581 remains the latest hardware result: the 16 KiB host buffer is active but high-bitrate playback fails cadence acceptance, and the FPGA image remains unchanged. No new build or hardware test was performed for this authorization record.

#### Next Steps:

Publish the pending entry-581 evidence and this authorization record from the Raspberry Pi checkout to GitHub master, verify the remote commit and retain this standing publication permission in future recovery context. Apply it to subsequent relevant evidence and log updates without an additional publication question. Obtain approval for the separate host-transfer profiling and safe optimization proposal before changing production source or deploying a host binary, retain required backpressure and byte handling, and keep the unresolved hardware acceptance and 8 Mbps regression visible. Preserve `core.md`, the existing untracked screenshots and the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 581 COMMIT Unreleased ad364bf 2026-08-27T01:30:00-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Validate the larger host delivery buffer on one cold high-bitrate playback and identify the remaining transfer boundary.

#### Outcome:

The user reports a cold reboot followed by one playback that runs perfectly in some places and very slowly in others. The new syslog start at 08:23:32 UTC, replacing the previously collected 08:05:14 start, corroborates the reboot. The helper log was fetched before a fresh screenshot, with only the old fixed screenshot deleted before triggering. Full readbacks confirm the recorded `ad364bf` host binary and unchanged `2acabc5` FPGA image, and the exact 34,919,166-byte media file matches SHA-256 `90976c09e12dfe03243d5c8daccf65ecc98b4d0008cb5489e96c73f667434979`. Schema nineteen validates all 449 pictures, 448 swaps, sequence end, quiet presentation completion and zero aggregate errors, but records 185 delayed presentation intervals over 24.433194 seconds, averaging 18.335712 fps; the three largest holds are 200.2, 166.833 and 166.833 milliseconds at ordinals 95, 93 and 94. The buffer change is active: 2,131 reads contain 16,384 bytes and the final read contains 4,862, with normal helper exit and no pipe EAGAIN after the first completed chunk. Matched completed-read endpoints measure 1,427,919 bytes per second and an inferred 21.7955 four-read polls per second, versus entry 578's 1,420,489 and 86.7080. Four times the chunk size therefore yields only about half a percent more throughput while the inferred poll rate falls fourfold; the high-bitrate acceptance fails. This corrects entries 577 through 580's causal attribution to a fixed poll budget: agreement between throughput and a poll rate derived from the same read count is substantially algebraic, not independent evidence that poll frequency remains fixed. The data support transfer cost scaling with bytes, but do not separate bridge overhead from legitimate FPGA wait. The verified stream's picture spans range from 27,190 to 253,632 bytes against approximately 47,645 delivered bytes per nominal frame interval, consistent with alternating smooth and slow passages rather than a continuously wrong raster clock. Source review also revises the proposed fast-write follow-on: `fpga_spi` waits for both ACK high and ACK low, and this core's input FIFO full signal controls that acknowledgement through `ioctl_wait` and `sys_top`; `spi_block_write` omits those waits and also lacks the wide-mode odd-byte tail handling of `spi_write`. It must not be substituted blindly. Absence of helper-pipe EAGAIN does not prove absence of FPGA backpressure. The logged first-byte latency of 45,532 microseconds is actually assertion to first completed chunk because logging follows transmission, so it includes the larger chunk's transfer time. The 185 counter counts delayed presentation intervals, not every missed frame slot. Last-three-read spans inside individual polls have a 33.772-millisecond median and 67.404-millisecond maximum, establishing exposure to UI service delays but not a measured UI response. No production source, deployed binary, configuration or lifecycle was changed. Capture, full decode, helper log, fixture analysis, comparisons and source-review limitations are retained in the five entry-581 evidence files under `.ai/current_results`; the media readback occurred after the completed cold test and warms cache for subsequent non-rebooted playback.

#### Next Steps:

Obtain approval for a bounded host-transfer profiling and safe optimization cycle rather than raising the buffer again or replacing acknowledged writes with unchecked fast writes. Measure pipe read and transfer durations separately at chunk boundaries, sampled ACK-loop statistics and actual poll or UI service duration without per-word logging, then distinguish bridge overhead from FIFO wait before choosing a correction that preserves backpressure, byte order and odd-tail handling. Any subsequent host-system-binary deployment requires explicit approval, retained restoration data and verified staged replacement plus full readback; standing RBF permission does not cover it. Ask whether the interface remained responsive during this run, and retain one qualified 8 Mbps fixture regression as outstanding rather than assuming it passed. Respect one run per changed circumstance. Keep FPGA startup, the 64-KiB clean-video queue, continuous HDMI sync and black startup background unchanged; analog work remains excluded and the previously recorded interlaced, audio, cancellation and assertion-drift limitations remain unresolved. Preserve `core.md` and the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 580 COMMIT Unreleased ad364bf 2026-08-27T01:06:04-07:00

#### Coming From:

Unreleased ad364bf

#### Purpose:

Record the current state, findings and outstanding validation for an agent handover requested by the user.

#### Outcome:

The current source is `ad364bf`, built and deployed but not yet hardware-validated. The FPGA bitstream was not rebuilt at any point in this cycle: the qualified `2acabc5` image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains installed at `/media/fat/MediaPlayer.rbf`, and every change since has been host-side. The deployed `/media/fat/MiSTer` is `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`, 1,166,244 bytes, verified by full readback on a fresh connection. Three restore points are retained under `/home/vash/mister-builds/entry573-deced5c/`: the pre-instrumentation original `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`, the instrumented `deced5c` build `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, and the current one; restoration is a single FTP upload. This cycle began from a report that repeated playback ran slowly and ended by locating the delivery ceiling in source. The established mechanism is that `mediaplayer_poll()` in `host/main_mister/0001-mediaplayer-arm-loader.patch` moved at most four chunks of 4,096 bytes per poll at an implied 86.2 to 86.7 polls per second, and that budget matched measured delivery to about a hundredth of a percent across three independent measurements spanning two files whose demands differ by 2.3 times and both thermal states. The cap binds because the helper always has data ready: in every log examined, every would-block event carries a submitted count of zero and precedes the first byte, and the parent never sees EAGAIN during steady delivery. The qualified 15,150,646-byte file demands 1,010,157 bytes per second and so had roughly 1.4 times headroom, leaving only startup at risk, while the 34,919,166-byte file demands 2,330,798 and was throttled to 18.2 frames per second with 187 to 188 missed deadlines across two runs; warming that file halved its blocked polls and cut 9.2 milliseconds of first-byte latency yet moved delivery by 0.6 percent and changed nothing else, which cleanly separates read latency, governing startup only, from the per-poll budget, governing steady throughput. Four earlier conclusions in this log were corrected by later evidence and a handover must not re-adopt them: entry 568's prefill-depth framing, the accepted-bytes release gate floated around entry 569 and disproved by its own capture 5, entry 571's claim that the cold feed runs at 0.94 times realtime, which was an averaging artefact hiding a late start rather than a slow feed, and entry 572's twin claims that warm dead time is zero, since it is about 8.3 milliseconds once the burst rate is measured rather than derived, and that the per-poll budget could be ruled out, which entries 577 and 578 contradict by direct measurement. One important negative result stands unexplained: measured first-byte latency does not predict whether a cold run gaps, since 37.6 milliseconds was clean while 21.9 and 35.3 gapped and 68 gapped twice, so phase alignment between byte arrival and the early cadence deadline remains the leading hypothesis and no counter measures it. On the qualified file, cold boot plays perfectly about half the time, two clean against two gapped among strictly verified cold boots and three gapped counting the unverifiable entry 568, and a failure costs one or two dropped frames inside the first 270 milliseconds with steady-state cadence nominal in every session ever measured. A project-level consequence should not be lost: the old ceiling of about 1.41 megabytes per second left only twelve percent headroom over DVD peak program-stream rate of about 1.26, which is less than startup dead time already consumes and excludes audio demultiplexing. Practical notes for the successor: the MiSTer is at 10.10.0.30 over ordinary FTP with the default credentials, its clock runs UTC against the project's America/Phoenix local time, `/tmp/MediaPlayer_ARM.log` is rewritten per playback and must be fetched before any replay, and reboots must be verified from `/tmp/messages` rather than from recollection because the reported procedure has contradicted the device twice, a core reload being mistaken for a Linux reboot. The capture path was itself controlled: six consecutive probes of a static screen returned byte-identical images. The polling capture scripts lived in an ephemeral session scratchpad and would need rewriting; `tools/streams/read_hardware_cadence.py` and `decode_hardware_cadence.py` remain the committed tools. Note also that this agent ran on GUNSMOKE rather than the Raspberry Pi, so the `core.md` response-loop LED steps were inoperative and pushes were made from the build PC contrary to the stated convention.

#### Next Steps:

Resume at the pending validation, which the user has already been asked to perform: power-cycle, play `bbb_480i_tff_15s.m2v` once and stop, then fetch `/tmp/MediaPlayer_ARM.log` before the cadence screenshot. Confirm first that the per-read `count` field reports 16,384 rather than 4,096, which is the only available runtime proof that the buffer change took effect, since a stack allocation cannot be verified by string extraction in a stripped image. Then derive the poll rate from read count divided by four divided by elapsed span and treat it as the discriminating measurement: a rate holding near 86 Hz means the ceiling has risen toward 5.7 megabytes per second and the delivered frame rate should climb toward 29.97 with the missed-deadline count collapsing, whereas a rate falling proportionally toward 22 Hz means the read-back word loop dominates and the buffer size was not the operative constraint. In that second case the identified follow-on is already characterised: `spi_write` calls `spi_w`, which resolves to `fpga_spi` and performs a bridge read-back per sixteen-bit word, while `spi_block_write` wraps `fpga_spi_fast_block_write`, which issues two posted writes per word with no read-back and is already used by the IDE, x86, CDTV and Akiko paths; propose that as a separate approved boundary rather than adopting it silently. Also replay the qualified 15,150,646-byte file once to confirm the change has not disturbed previously accepted behaviour, and ask the user whether interface responsiveness has degraded, since a longer `mediaplayer_poll` delays `HandleUI`, `OsdUpdate` and `input_poll` in the same free-running main loop and that cost was never bounded in advance. Respect the user's diagnostic cadence, which is one run per circumstance rather than repeated samples for statistics; design each hardware request as a single run changing one condition and say what it would discriminate. Do not restore the per-poll budget ruling-out from entry 572, do not revive the accepted-bytes release gate, and do not change the FPGA startup controller, the 64-KiB clean video queue, the continuous HDMI sync fix or the black startup background. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain unsupported or unresolved. Keep `core.md` unchanged and preserve the forty-entry log ring.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 579 COMMIT Unreleased ad364bf 2026-08-27T01:01:12-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Raise the bytes moved per poll in `mediaplayer_poll()` by enlarging the read buffer from 4,096 to 16,384 bytes so the measured delivery ceiling rises above the rate a high-bitrate stream demands.

#### Outcome:

The approved plan is committed as `ad364bf`, built and deployed. Entries 577 and 578 established by three independent measurements that delivery is capped at four chunks of 4,096 bytes per poll at an implied 86.2 to 86.7 polls per second, matching measured throughput to about a hundredth of a percent each time, and that the cap binds because the helper always has data ready and the parent never sees EAGAIN during steady delivery. The change enlarges the buffer to 16,384 bytes while leaving the chunk count at four, which raises the arithmetic ceiling from about 1.42 to about 5.7 megabytes per second and moves the same bytes in a quarter as many read and transmit calls. Two checks were made before proposing it. `user_io_file_tx_data` performs no internal chunking, consisting only of `EnableFpga`, a command byte, `spi_write` and `DisableFpga`, so larger blocks are accepted and the per-call FPGA framing is amortised rather than repeated. The main loop in `main.cpp` is free-running with no sleep, calling `user_io_poll`, `frame_timer`, `input_poll`, `HandleUI` and `OsdUpdate` in sequence, so the poll rate is set by how long that work takes rather than by a timer, and spending longer in `mediaplayer_poll` necessarily slows every other item. That is the principal risk and it is not eliminated by this change, only bounded and measured. The relevant cost is that `spi_write` is a word-at-a-time loop calling `spi_w`, which resolves to `fpga_spi` and performs a read-back per sixteen-bit word, stalling on the HPS-to-FPGA bridge each time, so 4,096 bytes costs 2,048 bridge round trips and a full poll costs 8,192. Enlarging the buffer quadruples the bytes per poll but also quadruples that word-loop time, so the net gain depends on what fraction of the 11.5-millisecond poll period that loop currently occupies, which has not been measured. This makes the change a discriminating experiment as well as a correction: the instrumentation added in `deced5c` reports read counts and elapsed time, from which the poll rate is derived directly, so if the rate holds near 86 Hz the ceiling rises toward 5.7 megabytes per second, whereas if it collapses proportionally toward 22 Hz the word-loop dominates and the buffer size is not the operative constraint. In that second case the identified answer is already in hand and would be proposed separately: `spi_block_write` wraps `fpga_spi_fast_block_write`, which issues two posted register writes per word with no read-back, and it is already used for bulk transfers by the IDE, x86, CDTV and Akiko paths, while `user_io_file_tx_data` alone still uses the slow read-back loop. That change is deliberately not made here because it alters the FPGA transfer path rather than a local buffer size. No FPGA rebuild is required and the qualified `2acabc5` bitstream with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` is unaffected. Deployment replaces the host-side MiSTer main binary again, and both prior binaries are retained for restoration, the pre-instrumentation original and the `deced5c` instrumented build, under `/home/vash/mister-builds/entry573-deced5c/`. The change is a single line, the buffer declaration in `mediaplayer_poll()`, and the hunk line count is unchanged at 304. `git apply --check` accepted it against pinned Main_MiSTer commit `0a8fb44` and the build completed with ARM GNU 10.2.1 20201103 reporting no errors, producing a 1,166,244-byte stripped ARM EABI5 binary with MD5 `295a3f2473360c46f4b946922fc1cbc2` and SHA-256 `a850ec3fc8c78b6ed72e3421858f9e3c40a5d2a4ff59a533d52dd0df47213a86`. Because the buffer is a stack allocation in a stripped image its size cannot be confirmed by string extraction, so verification is deferred to runtime, where the instrumented log's per-read `count` field must report 16,384 rather than 4,096. Deployment followed the established procedure and additionally confirmed before overwriting that the target held exactly the retained `deced5c` restore point rather than an unrecorded state. The staged upload was hash-verified before the rename and the active path was then read back in full over a fresh connection, returning 1,166,244 bytes with the matching SHA-256 and leaving no staging file. Three restore points are now retained under `/home/vash/mister-builds/entry573-deced5c/`: the pre-instrumentation original with SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`, the instrumented `deced5c` build, and this one.

#### Next Steps:

Build with MiSTer's official ARM GNU 10.2 toolchain, never the distribution cross-compiler, confirm the patch applies cleanly to pinned Main_MiSTer commit `0a8fb44`, and deploy host-side with the existing staged-upload, verify, rename and full-readback procedure. Validation is a single replay of `bbb_480i_tff_15s.m2v`, whose 2,330,798 bytes per second demand exceeded the old ceiling and produced 187 to 188 missed deadlines at about 18.2 frames per second across two runs. Read the helper log first and derive the poll rate from read count and elapsed span, then compare measured delivery against the new budget arithmetic of four chunks of 16,384 bytes at the observed rate. Success is delivery above the file's demand with the delivered frame rate rising toward 29.97 and the missed-deadline count collapsing; a poll rate that falls proportionally instead indicates the read-back word loop dominates and moves the boundary to `spi_block_write`. Also confirm on the qualified 15,150,646-byte file that the change has not disturbed the previously accepted behaviour, and watch for any user-visible loss of interface responsiveness, since a longer `mediaplayer_poll` delays `HandleUI`, `OsdUpdate` and `input_poll` in the same loop. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 578 COMMIT Unreleased deced5c 2026-08-27T00:56:47-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Replay the larger file warm to test entry 577's recorded prediction that page-cache warming would not relieve a stream whose demand exceeds the per-poll delivery ceiling.

#### Outcome:

No power cycle preceded this run and the syslog still shows the single 07:41:02 UTC boot, so the page cache retained the larger file from entry 577. The prediction recorded before the run is confirmed on every term. Delivery was predicted at about 1,412,000 bytes per second and measured 1,420,655, a change of 0.6 percent; the delivered rate was predicted near 18.1 frames per second and measured 18.2343; the missed-deadline count was predicted to remain in the same order as 188 and measured 187; and first-byte latency was predicted to fall and did, from 23,749 to 14,560 microseconds. The warming itself is unmistakable and behaved exactly as page-cache warming should, halving the blocked polls that precede the first byte from 384 to 185 and cutting 9.2 milliseconds from first-byte latency, yet none of that reached the outcome. The session still accepts all 34,919,166 bytes and displays 449 pictures with 448 swaps at zero error flags, still runs 24.57 seconds for 15.0 seconds of content, and still shows its three largest gaps at 12,012,000, 10,010,000 and 10,010,000 cycles around ordinals 93 to 96. The separation this establishes is clean and is the point of the run: read latency governs startup only, and the per-poll budget governs steady throughput, so warming a file that demands more than the ceiling changes when playback begins and nothing about how it proceeds. The delivery arithmetic closes for a third time. This run implies 86.7 polls per second against 86.2 in entry 577, and four chunks of 4,096 bytes at 86.7 Hz is 1,420,791 bytes per second against a measured 1,420,655, agreeing to 0.010 percent. Across three independent measurements now, spanning two files whose demands differ by a factor of 2.3 and two thermal states, the implied poll rate sits between 86.2 and 86.7 Hz and the four-chunk budget arithmetic matches measured delivery to about a hundredth of a percent each time. The delivery ceiling is therefore established as a property of the per-poll budget rather than of the media, the filesystem, the helper or the FPGA, and entry 572's ruling-out of that candidate, already corrected in entry 577, is now contradicted by direct measurement under two thermal conditions. One risk remains entirely unassessed and must gate any correction: `mediaplayer_poll()` is called from `user_io_poll()`, so spending longer inside it delays every other responsibility of the MiSTer main loop, and nothing in this work has examined what that costs. Per the user's diagnostic cadence this is one run per condition, only three of the 187 deadline records are retained by the snapshot, and the poll rate is still inferred from read counts and elapsed time rather than measured inside MiSTer main. Evidence is `.ai/current_results/entry578_bigfile_warm_arm_helper.log`, `entry578_bigfile_warm_terminal.png` and `entry578_bigfile_warm_capture.json`.

#### Next Steps:

Seek user approval for a bounded delivery-side change before implementing it. The proposal is to raise the bytes moved per poll in `mediaplayer_poll()` within `host/main_mister/0001-mediaplayer-arm-loader.patch` by enlarging the read buffer from 4,096 to 16,384 bytes while leaving the chunk count at four, which raises the ceiling from about 1.42 to about 5.7 megabytes per second and, because it moves the same bytes in a quarter as many read and transmit calls, should reduce rather than increase the per-byte time spent in the function. Size the target against DVD peak program-stream rate of 10.08 Mbps or about 1.26 megabytes per second with real margin rather than against this one test file, since the present twelve percent headroom over DVD peak is less than startup dead time already consumes. Before proposing the edit, examine whether `user_io_file_tx_data` accepts larger blocks without internal chunking that would negate the benefit, and estimate the added worst-case time per `user_io_poll` call against whatever else that loop must service, because that is the principal risk and is currently unexamined. No Quartus build is required and the qualified `2acabc5` bitstream is unaffected. Validation would be a single replay of this same larger file, checking measured delivery against the new budget arithmetic and confirming the delivered frame rate rises toward nominal. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 577 COMMIT Unreleased deced5c 2026-08-27T00:53:02-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Play the higher-bitrate `bbb_480i_tff_15s.m2v` once to test whether the startup defect is delivery-bound.

#### Outcome:

The larger file is 34,919,166 bytes against 15,150,646 for the qualified file, carrying the same 449 pictures of the same 29.97 fps content at roughly 2.3 times the bitrate. No power cycle preceded this run; the syslog still shows the single 07:41:02 UTC boot, so it followed the entry 575 cold run on the same uptime. The user reports it played a lot slower, and the telemetry agrees emphatically. The session records 188 cadence outliers and 188 missed deadlines against the zero to two seen on the qualified file, a delivered rate of 18.1195 frames per second against a nominal 29.9700, and a cadence span of 1,483,483,716 cycles or 24.72 seconds for content that should occupy 15.0. The three largest gaps are 12,012,000, 10,010,000 and 10,010,000 cycles at ordinals 94, 93 and 95, six and five nominal intervals respectively, and the misses are spread through the session rather than confined to startup. The file nonetheless plays correctly and completely, accepting all 34,919,166 bytes, displaying all 449 pictures with 448 swaps, reaching sequence end and presentation completion with a quiet terminal and zero error flags; it is throttled, not corrupted. The instrumented helper log closes the mechanism completely. Delivery ran flat at the ceiling for the whole session, with segment rates between 1,393,653 and 1,442,109 bytes per second from 199 milliseconds through 24.7 seconds and no burst-then-decay shape, because demand exceeds supply throughout rather than only at startup. The whole-session delivery rate is 1,412,269 bytes per second across 8,526 reads. Dividing those reads by the four-chunk budget gives 2,132 polls over 24.726 seconds, an implied poll rate of 86.2 Hz, and four chunks of 4,096 bytes at 86.2 Hz is 1,412,404 bytes per second, agreeing with the measured delivery to 0.01 percent. The stream demands 2,330,798 bytes per second, giving a deficit ratio of 0.6059, and the observed frame rate ratio of 18.1195 over 29.9700 is 0.6046, agreeing to 0.2 percent. Playback is therefore throttled to exactly the delivery deficit. As before, all 384 would-block events carry a submitted count of zero and precede the first byte, so the helper always had data ready and the parent never saw EAGAIN during steady delivery, confirming that the parent's per-poll budget rather than the helper or the filesystem is the binding constraint. This corrects entry 572, which concluded that raising the four-chunk per-poll budget would not correct anything because steady throughput was never the limiting quantity, and listed that candidate as ruled out. That conclusion holds only for the qualified file, whose 1,010,157 bytes per second demand sits below the ceiling; it is false in general, and for any stream above roughly 1.41 megabytes per second the per-poll budget is precisely what throttles playback. A project-level consequence follows and should not be buried. The measured ceiling of about 1.41 megabytes per second is marginal for the stated long-term goal of commercial DVD playback, since DVD peak video bitrate is 9.8 Mbps or about 1.225 megabytes per second and a full program stream may reach 10.08 Mbps or about 1.26, leaving roughly twelve percent headroom, which is less than the startup dead time already consumes and takes no account of audio demultiplexing. Only three of the 188 deadline records are retained by the snapshot, at ordinals seven, eight and nine, and the 86.2 Hz poll rate remains inferred from read counts and elapsed time rather than measured inside MiSTer main, though it now agrees across two files with very different demands. Whether raising the per-poll budget is safe with respect to MiSTer main's other responsibilities has not been assessed and is not proposed here. Evidence is `.ai/current_results/entry577_bigfile_arm_helper.log`, `entry577_bigfile_terminal.png` and `entry577_bigfile_capture.json`.

#### Next Steps:

The user intends one further run of the same larger file, which is now a genuine test rather than a repeat, because the page cache holds the file after this run while the constraint identified here is the per-poll budget and not read latency. The prediction to be recorded before that data arrives is that warming will change nothing material: first-byte latency should fall from its 23,749 microseconds toward the warm baseline, but the delivery rate should stay near 1,412,000 bytes per second, the delivered frame rate should stay near 18.1 and the missed-deadline count should remain in the same order. If instead the warm run recovers substantially, the per-poll budget is not the whole constraint and this entry's arithmetic is wrong somewhere. After that, propose a bounded delivery-side change for approval rather than implementing it: raise the per-poll chunk count or the buffer size in `mediaplayer_poll()` within `host/main_mister/0001-mediaplayer-arm-loader.patch`, sized against DVD peak program-stream rate with real margin rather than against this one test file, and assess first whether spending longer in that function starves MiSTer main's other per-poll work, which is the obvious risk and has not been examined. That change would need no Quartus build and would be validated by replaying this same larger file and checking the delivery rate against the new budget arithmetic. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 576 COMMIT Unreleased deced5c 2026-08-27T00:48:31-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Record the user's revised diagnostic cadence and state the cold-boot behaviour of `2acabc5` as it currently stands.

#### Outcome:

The user has cut the diagnostic cadence and this supersedes the Next Steps of entry 575, which proposed collecting six to eight paired latency and outcome samples. That plan is withdrawn. Their instruction is that going forward the file is run once under different circumstances rather than repeatedly under the same one, on the grounds that each sample costs a manual power cycle, core load and playback and that varying the condition returns more per run than repeating it. Future hardware requests must therefore be designed as a single run that changes one condition and must state what that one run would discriminate; if a conclusion genuinely requires repetition, say so and let the user decide rather than scheduling the repeats. The user also asked directly whether the file plays perfectly on a cold boot, and on the present evidence it does not, though the defect is narrow. Across strictly verified cold boots, where the power cycle was confirmed from `/tmp/messages` or from a live FTP dropout rather than from recollection, block 1 run 1 and block 3 run 1 gapped with one and two missed deadlines while entries 572 and 575 were clean, giving two clean and two gapped; entry 568 also gapped but its reboot predates the syslog that was later checked and cannot be verified, which would make it three gapped of five. Cold boot therefore plays perfectly roughly half the time. What a failure costs is one or two dropped frames inside the first 270 milliseconds at display picture ordinals five and six, and nothing after. In every session ever measured, gapped or clean, the second and third ranked display gaps are exactly 2,002,000 cycles, so steady-state cadence past the startup region is nominal without exception, and every run completes with all 15,150,646 bytes accepted, 449 pictures, 448 swaps and zero error flags. Warm replays are clean in every sample except the block 1 series, where the media was still warming across successive runs. No source change, build or deployment was made for this entry. The installed FPGA image remains the qualified `2acabc5` bitstream with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`, and the installed host binary remains the instrumented `deced5c` build with SHA-256 `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, whose pre-deployment backup is held at `/home/vash/mister-builds/entry573-deced5c/`.

#### Next Steps:

Await the user's choice of the next single circumstance to test rather than proposing a sampling programme. The open question is unchanged and is stated in entry 575: measured first-byte latency does not predict whether a cold run gaps, since 37.6 milliseconds was clean while 21.9 and 35.3 milliseconds gapped, so phase alignment between byte arrival and the early cadence deadline remains the most likely operative variable and no current counter measures it. The single most discriminating circumstance available without a new build is playing the higher-bitrate `bbb_480i_tff_15s.m2v`, which is 34,919,166 bytes against 15,150,646 for the qualified file and therefore demands about 2,327,944 bytes per second, well above the 1,443,000 bytes per second burst rate measured in entry 575. If the defect is delivery-bound that file should fail consistently and severely rather than intermittently, and if it plays as well as the smaller file then delivery rate is not the operative constraint and the boundary moves to the FPGA side. Do not deploy the helper-side priming correction, which entry 575 showed is not yet justified. Do not raise the per-poll chunk budget. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 575 COMMIT Unreleased deced5c 2026-08-27T00:44:54-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Measure assertion-to-first-byte latency on a verified cold run using the instrumented `deced5c` binary and test the dead-time inference of entry 572.

#### Outcome:

The power cycle is verified by a single new syslogd start at 07:41:02 UTC replacing the 07:25:17 boot, the user played once and stopped, and the helper log survived at 205,355 bytes. The timestamped record format itself proves the instrumented binary is the one that ran. The run came up clean, with zero cadence outliers, zero missed deadlines, 449 pictures, 448 swaps, all 15,150,646 bytes accepted and zero error flags, and its cadence counters are indistinguishable from earlier uninstrumented clean runs, so no behavioural change is evident, though one sample cannot prove the instrumentation non-invasive. The measurement the boundary was built for reads `first_byte latency_us=37556 would_block=672`, or 37.6 milliseconds from download assertion to first submitted byte, which falls inside the 13.9 to 63.8 millisecond band entry 572 inferred and therefore confirms that inference by direct measurement. The timestamps also permit the delivery curve to be computed for the first time from all 3,699 read records rather than inferred from telemetry arithmetic, and it shows that delivery is not a constant-rate process. It bursts at about 1.43 times realtime, 1,442,776 bytes per second from 97 to 199 milliseconds and 1,446,123 from 199 to 298, then decays through 1.28 and 1.06 times realtime and settles at consumption-paced realtime, finishing the whole session at 1,017,538 bytes per second. Because the ordinal five and six deadlines fall at roughly 200 to 270 milliseconds, they sit inside the burst, so treating delivery as constant-rate is valid for the startup window that matters but not for the session as a whole. That measured burst rate of about 1,443,000 bytes per second supersedes the 1,392,000 figure derived arithmetically in entries 571 and 572, which was 3.7 percent low, and the correction is self-validating: recomputing warm dead times at the measured rate tightens their spread from plus or minus 1.2 milliseconds to plus or minus 0.35 across five independent sessions, constraining the rate to about one percent. This corrects entry 572, which stated that warm dead time is zero. It is not; warm dead time is a consistent 8.0 to 8.7 milliseconds, averaging about 8.3, and the apparent zero was an artefact of the low rate estimate absorbing the real warm latency. The cold-versus-warm separation is unaffected and in fact widens, with cold dead times recomputing to 21.9, 35.3, 68.1 and 68.7 milliseconds against that 8.3 baseline. The most important result, however, is negative and must not be smoothed over. Dead time does not predict the outcome. This run measured 37.6 milliseconds and was clean, while entry 568 gapped at 35.3 and block 1 run 1 gapped at 21.9, and block 3 run 1 missed twice at 68.1. Dead time is therefore necessary context but not a sufficient predictor of a missed deadline, exactly paralleling entry 569 where starvation magnitude also failed to predict the miss. The most likely remaining variable is phase alignment between byte arrival and where the cadence deadline falls, which no existing counter measures. Cold outcomes now stand at three gapped and two clean across five verified cold runs. The burst rate is measured from this one cold run and warm runs remain uninstrumented, so their burst rate is supported by the residual cluster rather than measured directly, and the measured-latency population is one. Evidence is `.ai/current_results/entry575_cold_arm_helper.log`, `entry575_cold_terminal.png` and `entry575_cold_capture.json`.

#### Next Steps:

Do not propose the helper-side priming correction yet, because the justification for it has weakened rather than strengthened. Priming would reduce dead time from tens of milliseconds toward the warm baseline, but a run at 37.6 milliseconds was clean while runs at 21.9 and 35.3 gapped, so reducing dead time alone is not established to eliminate the miss and could be built and deployed without fixing anything. Gather measured latencies paired with outcomes instead, which the instrument now makes cheap: repeat the verified power cycle, single playback and immediate log fetch several times for cold samples, and separately instrument warm runs by fetching the helper log after a replay, so both populations carry measured rather than assumed latency. Six to eight paired samples should show whether any latency threshold separates clean from gapped runs or whether the outcome is independent of latency, which would confirm phase alignment as the operative variable and move the boundary again. If latency proves not to separate the populations, the next instrumentation step is to record, at each early cadence deadline, the phase between the most recent byte arrival and the deadline itself, which is an FPGA-side counter rather than a host-side one and would require a Quartus build. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Do not raise the per-poll chunk budget, which entry 572 ruled out and which the measured burst curve confirms is not limiting during the window that matters. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 574 COMMIT Unreleased deced5c 2026-08-27T00:40:07-07:00

#### Coming From:

Unreleased deced5c

#### Purpose:

Back up and replace the host-side MiSTer main binary with the instrumented `deced5c` build under explicit user approval.

#### Outcome:

The user explicitly approved deployment and explicitly asked for a backup first, so standing RBF authorization was neither needed nor relied upon; this replaces a system binary rather than a core image and was treated accordingly. The existing `/media/fat/MiSTer` was read back in full over FTP at 1,166,244 bytes, its length checked against the server's own size report, written to disk and then re-hashed from disk, giving SHA-256 `5a6cbf7e85682ac301d57470b8b2c952d3bbfa42af55484bd70dd0d36724ae96`. That backup is held at `/home/vash/mister-builds/entry573-deced5c/` outside the repository, because a 1.1-megabyte system binary does not belong in git, and restoring it is a single FTP upload should the instrumented build misbehave. Deployment avoided writing into the running binary's inode. The new image was uploaded to `/media/fat/MiSTer.new`, that staged copy was read back in full and hash-compared before anything was renamed, and only then was it renamed over the live path, which unlinks the old inode while the running process keeps its own. A fresh independent FTP connection then read back the entire active file. Staged and active readbacks both return 1,166,244 bytes with SHA-256 `bd182e9c26e91bb3bdb140835dbda40a0f0a8179060fa47939cbb6c073ecf1dd`, matching the build exactly, no staging file remains, and permissions read as `-rwxr-xr-x`. The replaced and replacing binaries are both 1,166,244 bytes; since their hashes differ, the identical length is coincidental alignment in a stripped image and not a failed or partial write. The FPGA bitstream is untouched. No Quartus build was performed for this boundary and the qualified `2acabc5` image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains installed at `/media/fat/MediaPlayer.rbf`. The replacement takes effect on the next boot, since the currently running process retains the old inode until then. No playback has yet been run against the instrumented binary, so this entry records deployment only; the instrumentation is intended to be purely observational with no behavioural change, and that expectation is not yet confirmed on hardware. Evidence is `.ai/current_results/entry574_deployment.json`.

#### Next Steps:

Have the user power-cycle at the wall, load the core, play the file once and then stop without replaying, so `/tmp/MediaPlayer_ARM.log` survives for collection; a replay overwrites it, which is exactly how the cold log was lost in entry 571. Verify the power cycle from `/tmp/messages` rather than from recollection, since that check has already contradicted the reported procedure twice. Fetch the helper log first and the cadence screenshot second, then confirm three things: that the measured assertion-to-first-byte latency falls within the 13.9 to 63.8 millisecond band inferred in entry 572, that the timestamped blocked-poll records account for that interval rather than leaving it unexplained, and that cadence behaviour is unchanged from the uninstrumented build so the observation is confirmed non-invasive. Because entry 572 showed cold is not deterministic, with three of four verified cold runs gapping and one clean, expect to repeat this for at least two further verified cold samples before the dead-time distribution is usable. If the measurement confirms the inference, propose the helper-side correction of priming the media source before asserting download as a separate approved boundary. Hold the startup-absorption candidate in reserve and treat its margin as unsafe, the 64-KiB queue covering 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget, which entry 572 ruled out. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 573 COMMIT Unreleased deced5c 2026-08-27T00:31:44-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Instrument the ARM helper diagnostic log with monotonic timestamps and an explicit first-byte latency record so the cold startup dead time inferred in entry 572 becomes a measured quantity.

#### Outcome:

The approved plan is now committed as `deced5c` and built. Entry 572 established that steady delivery is a constant 1,392,000 bytes per second in every measured thermal state and that the cold defect is dead time before the first byte, inferred at 13.9 to 63.8 milliseconds by comparing each deadline record's elapsed time against the byte count it should have taken at that rate. That inference rests on telemetry arithmetic and on an 85 Hz poll rate that was never measured, so the correction to be made first is instrumentation rather than repair. The change is confined to `mediaplayer.cpp` as carried by `host/main_mister/0001-mediaplayer-arm-loader.patch`, which creates that file wholly, so the edit is contained to one new-file hunk whose line count is recomputed mechanically. A monotonic microsecond clock is added using `clock_gettime` with `CLOCK_MONOTONIC`, a session reference is taken in `diagnostic_open` before the first line is written so that the `start` record reads as time zero, and every diagnostic line is prefixed with elapsed microseconds composed into the same buffer as the message so that a single write call still emits a single line. The moment of download assertion is recorded, and on the transition of the read-event counter from zero to one a dedicated record reports the elapsed time from assertion to first submitted byte together with the would-block count accumulated in that interval. Nothing in the decode path, the FPGA image, the presentation scheduler, the startup controller or the 64-KiB queue is touched, the four-chunk per-poll budget is deliberately left alone because entry 572 ruled it out, and no behavioural change is intended, only observation. The FPGA bitstream is unaffected, so no Quartus build is required and the existing qualified `2acabc5` RBF with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` remains the installed image. Deployment is therefore host-side only and consists of the rebuilt MiSTer main binary and helper, and that is a materially different and more invasive operation than the RBF replacement covered by standing authorization, since it replaces a system binary rather than a core image; it must be approved separately by the user before anything is written to the target. The change is built and verified. `git apply --check` accepted the regenerated single-hunk patch against the pinned Main_MiSTer commit `0a8fb44`, the hunk line count moving from 275 to 304, and the build completed with the official ARM GNU 10.2 toolchain reporting version 10.2.1 20201103 rather than the distribution cross-compiler, producing a 1,166,244-byte stripped ARM EABI5 binary whose MD5 is `cba107ea2c4ea39bfb1bce755b262ca6`. The only two matches for error text in the build log are the zstd source filenames `error_private.c`, so the build is clean. The instrumentation is confirmed present in the binary by the literal strings `t=%llu ` and `first_byte latency_us=%llu would_block=%u count=%d`. The edited logic was additionally compiled and executed standalone against a harness that injected a five-millisecond delay before the first byte, and the resulting record read `first_byte latency_us=5059 would_block=670`, so the measurement path is correct to within harness resolution. One pre-existing property was observed and deliberately left alone: `diagnostic_write` truncates at its 1,024-byte buffer and loses the trailing newline when a message overflows, causing the next record to concatenate. That behaviour is inherited from the original implementation, the timestamp prefix consumes only about eight of those bytes, and real records run near sixty characters, so it is immaterial here and correcting it is out of scope for this boundary.

#### Next Steps:

Build the ARM stack with MiSTer's official ARM GNU 10.2 toolchain, never a distribution cross-compiler, and confirm the patch applies cleanly to the pinned Main_MiSTer commit `0a8fb44` before proposing deployment. Obtain explicit user approval for replacing the host-side MiSTer main binary and helper, since standing authorization covers the RBF only, and preserve a means of restoring the current binaries before any write. Once deployed, verify a power cycle from `/tmp/messages` rather than from recollection, play once, stop, and fetch `/tmp/MediaPlayer_ARM.log` before any replay overwrites it, then confirm that the measured assertion-to-first-byte latency falls within the 13.9 to 63.8 millisecond band inferred in entry 572 and that the timestamped record of blocked polls accounts for it. Gather at least two further verified cold samples so the dead-time distribution acquires a tail rather than four points. If the measurement confirms the inference, propose the helper-side correction of priming the media source before asserting download as a separate approved boundary, since it removes the dead time rather than hiding it. Hold the startup-absorption candidate in reserve and treat its margin as unsafe, the 64-KiB queue covering 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

- host/main_mister/0001-mediaplayer-arm-loader.patch

#### Status:

- [x] Built
- [ ] Passed

---

## 572 COMMIT Unreleased 2acabc5 2026-08-27T00:28:08-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Capture the ARM helper log from a verified cold run before any replay overwrites it, and determine whether cold delivery is limited by the per-poll budget or by EAGAIN.

#### Outcome:

The power cycle is verified by a single new syslogd start at 07:25:17 UTC replacing the 07:16:20 boot, and the user played once and stopped so the helper log survived. The cold run itself came up clean, with zero cadence outliers, zero missed deadlines, 449 pictures, 448 swaps, all 15,150,646 bytes accepted and zero error flags, which establishes that cold is not deterministic: of four verified cold runs, three gapped and this one did not. The helper log answers the question it was fetched for. Cold records 670 would-block events against 190 in the warm entry 570 log, but in both files every logged instance carries a submitted count of zero and precedes the first byte, and after read event one neither log records another. EAGAIN therefore never occurs during steady delivery in either thermal state, the four-chunk per-poll budget is binding in both, and the entire cold penalty is concentrated before the first byte, where cold shows three and a half times as many blocked polls as warm. That result forced a re-examination of the telemetry, and it corrects entry 571. Comparing each deadline record's measured elapsed time against the time its accepted-byte count requires at the warm steady rate of 1,392,000 bytes per second isolates a residual dead time before delivery effectively begins. Across five independent warm sessions that residual is zero within plus or minus 1.2 milliseconds, which both validates the rate and shows that warm delivery starts immediately. Across the four cold deadline records the residual is 13.9, 27.8, 60.7 and 63.8 milliseconds, and it tracks severity, since 63.8 milliseconds produced two missed deadlines while 27.8 and 13.9 produced one each. Entry 571 stated that on a cold start the upstream feed runs at 0.94 times realtime and below the rate the stream requires. That is wrong and is superseded here. The feed does not run slow; steady delivery is 1,392,000 bytes per second in every measured state. The apparent 0.94 figure divided accepted bytes by elapsed time and thereby folded the pre-first-byte stall into an apparent rate. The defect is a late start, not a slow feed. The practical consequence is that raising the four-chunk per-poll budget or the buffer size in `mediaplayer_poll()` would not correct anything, because steady throughput was never the limiting quantity, and that candidate is now ruled out. Two candidates remain. The first is to reduce cold first-byte latency on the helper side, for example by priming or reading ahead in the media source before the download is asserted. The second is to absorb the dead time before the first cadence slot in the startup controller, noting that the 64-KiB clean video queue holds 64.9 milliseconds of stream at nominal rate and therefore only just covers the worst observed 63.8 milliseconds. The second candidate returns the boundary to the startup controller that entries 569 and 571 had ruled out, but now with a quantified requirement rather than the byte threshold that entry 569 correctly rejected. This entry's own cold run contributes no dead-time datapoint because it was clean, so its contribution is the would-block count alone, and cold sampling remains at four samples. The 85 Hz poll rate is inferred from throughput arithmetic rather than measured in MiSTer main, so the warm residuals validate the resulting rate but not its decomposition into chunk count and poll frequency, and the helper log still carries no timestamps, so the 670 blocked polls cannot be converted to a duration and the dead time is inferred from telemetry arithmetic rather than measured on the ARM side. Evidence is `.ai/current_results/entry572_cold_terminal.png`, `entry572_cold_arm_helper.log` and `entry572_cold_capture.json`.

#### Next Steps:

Obtain user approval for a delivery-side plan before any source change, since the evidence now supports a bounded correction and the standing workflow requires the plan on record first. The proposal is to instrument before correcting: add timestamps to the helper diagnostic log and record the elapsed time from download assertion to first submitted byte, which converts the inferred dead time into a measured one and costs nothing in the decode path, then confirm on one cold run that the measured first-byte latency matches the 13.9 to 63.8 millisecond band inferred here. With that confirmed, prefer the helper-side correction of priming the media source before asserting download, because it removes the dead time rather than hiding it and leaves the FPGA startup controller and the 64-KiB queue untouched. Hold the startup-absorption candidate in reserve for the case where first-byte latency proves irreducible, and note that it has almost no margin, since the queue covers 64.9 milliseconds against a worst observed 63.8. Do not raise the per-poll chunk budget. Gather at least two further verified cold samples alongside the instrumented run so the dead-time distribution has a usable tail rather than four points, verifying each power cycle from `/tmp/messages` rather than from recollection, and fetch the helper log after the first playback of each. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged until a plan is approved. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 571 COMMIT Unreleased 2acabc5 2026-08-27T00:23:26-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Capture a verified cold-after-power-cycle block and identify the mechanism behind the delivery ceiling measured in entries 569 and 570.

#### Outcome:

The power cycle is verified by three independent signals rather than by recollection, which matters because the two previously reported reboots were not reboots. The still-running block 2 poller logged an FTP timeout at 00:16:27 local, exactly the dropout absent both earlier times; `/tmp/messages` restarted with a single syslogd entry at 07:16:20 UTC replacing the 06:56:52 boot; and `/tmp/MediaPlayer_ARM.log` disappeared with the tmpfs wipe, confirming the page cache was cleared. Six sessions were captured, the first genuinely cold and the remaining five warm replays with no reboot between them. The cold run is the worst session recorded to date and the first with more than one missed deadline. It reports two cadence outliers and two missed deadlines, at display picture ordinals five and six, with gaps of 4,004,000 and 6,006,000 cycles and a total cadence excess of 8,192,931 cycles, or 136.5 milliseconds. The first miss moved earlier to ordinal five, which no previous session showed. The decisive number is the feed rate at that ordinal-five deadline: 191,088 bytes had been delivered by 12,066,520 session cycles, which is 950,173 bytes per second, or 0.94 times realtime against the 1,010,157 bytes per second the stream requires. On a cold start the upstream feed is running below realtime, so the decoder cannot keep up because the data is not arriving fast enough, and the miss is a genuine delivery shortfall rather than a scheduler or writer fault. By the ordinal-six deadline the feed has recovered to 1,076,291 bytes per second, or 1.07 times realtime, and every run after the first is clean, so one replay is enough to leave the failing region. All six sessions still accept all 15,150,646 bytes and display 449 pictures with 448 swaps at zero error flags, and writer capacity blocked and upstream FIFO pending are false in both cold deadline records, so the writer and DDR path remain clean throughout. The delivery ceiling itself has now been located in source rather than inferred. `mediaplayer_poll()` in `host/main_mister/0001-mediaplayer-arm-loader.patch` reads into a 4,096-byte buffer under `while (chunks++ < 4)`, so it moves at most 16,384 bytes per poll. At the implied 85 polls per second that is 1,392,000 bytes per second, precisely the 1.38 times realtime ceiling measured warm in entries 566, 567 and 569. That cap is binding rather than incidental, and the archived helper log proves it: after startup the parent never receives EAGAIN, since all 190 would-block events carry a submitted count of zero and occur before the first byte is sent, so the read loop always exits by exhausting its four-chunk budget and never by running out of data. The cross-check agrees, with 3,699 reads at four per poll giving about 925 polls across a roughly 10.9 second delivery window for a 15.0 second stream. The delivery path therefore has about 38 percent headroom over realtime when warm and falls below realtime when cold, and that band is where the startup race is decided. One capture defect is recorded: an over-broad `pkill` pattern terminated the poller mid-block and had to be restarted, though a direct probe confirmed the screen still held run four at that moment and no session was lost. The single most important missing measurement is the helper log for a cold run, which was overwritten by the subsequent replays before it could be fetched; without it, it is not known whether cold delivery is limited by read latency inside the four-chunk budget or by EAGAIN against a slower helper, and those two point at different fixes. Evidence is `.ai/current_results/entry571_block3_run1` through `run6` and the consolidated `entry571_block3_series.json`.

#### Next Steps:

Take one more verified power cycle and fetch `/tmp/MediaPlayer_ARM.log` immediately after the first playback and before any replay, since that single file discriminates between a read-latency limit inside the four-chunk budget and an EAGAIN limit against a slower helper, and the two imply different corrections. Confirm the power cycle from `/tmp/messages` as was done here rather than from recollection. With that measurement in hand, propose a bounded delivery-side plan for user approval before touching source: if the budget is binding while cold, raising the per-poll chunk count or the buffer size in `mediaplayer_poll()` lifts the ceiling directly and is a small, contained change to the MiSTer main patch; if EAGAIN dominates while cold, the correction belongs in the helper's own read path or in readahead instead, and raising the poll budget would achieve nothing. Do not change the FPGA startup controller, which entries 569 and 571 together have now shown is not the operative boundary, and do not commit any source change until the plan is approved. Consider adding timestamps to the helper diagnostic log as part of whichever change is approved, since its present lack of timing is the main limit on the delivery evidence. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 570 COMMIT Unreleased 2acabc5 2026-08-27T00:14:52-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Collect a second repeated-run block and establish whether the ordinal-six miss survives a fresh start.

#### Outcome:

All five block 2 sessions are clean, reporting zero cadence outliers and zero missed deadlines while accepting all 15,150,646 bytes and displaying 449 pictures with 448 swaps, zero error flags and quiet terminals. The interpretation, however, is not the one the user expected, and the difference matters more than the result. The user reports rebooting before these five runs, but the device evidence does not support a Linux reboot. Both `/tmp` and `/run` are tmpfs and are recreated empty at boot, and `/tmp/messages` is the syslog and begins at boot. That file's first line is `Aug 27 06:56:52 MiSTer syslog.info syslogd started`, it runs unbroken through 07:13:46, and it contains exactly one syslogd start, while every boot-time daemon pidfile carries an mtime of 06:56. `/tmp/CORENAME` and `/tmp/RBFNAME` were restamped at 07:09. The MiSTer clock runs UTC against the agent's America/Phoenix local time, so 06:56:52 UTC is 23:56:52 local and 07:09 UTC is 00:09 local. Linux therefore booted once, before block 1, and remained up continuously across both blocks; what preceded block 2 was a core reload at 07:09 UTC, which reconfigures the FPGA but does not restart Linux and does not clear the page cache. Block 2 consequently ran against a cache already warmed by block 1's five reads of the same file, which makes it the strongest support so far for the read-latency mechanism rather than evidence that a cold start is clean. The same timeline confirms the other direction: block 1 capture 1 was taken 82 seconds after the verified boot and is a genuine cold-after-boot sample, and it gapped with 1,103,135 starved cycles. One conflict is left open and must not be smoothed over. Block 1 capture 5 was warm and still lost the ordinal-six slot at the full 1.38 times realtime feed rate, while all five block 2 runs at equal or greater warmth are clean, so page-cache warmth alone does not explain the difference and core-reload freshness may be a second factor that the present data cannot separate. A new and previously unrecorded evidence source was found during this work: the ARM helper writes `/tmp/MediaPlayer_ARM.log`, rewritten per playback, and the final block 2 run's copy is archived. It shows the helper reading the file in uniform 4,096-byte chunks, 3,699 reads for the whole 15,150,646 bytes, finishing on end of file with child exit code zero. Its blocking behaviour is the significant part. All 190 would-block events occur before the first byte is submitted, since every logged instance carries a submitted count of zero and the highest logged power of two is 128 against a total of 190, and after the first read event the helper never blocks writing to the FPGA again. The FPGA-side input FIFO is therefore never full during steady delivery, which establishes that ARM-side file read throughput is the limiting factor and is consistent with the 1.38 times realtime ceiling measured in entry 569. The 4,096-byte read granularity is the first concrete delivery-side mechanism identified and is a candidate cause of that ceiling. No genuine power-cycle sample has been taken since entry 568, whose own reboot predates the current syslog and cannot now be verified. The helper log carries no timestamps, so it establishes granularity and blocking but not read latency, and page-cache state remains unmeasured. Per the user's decision, entry 564 is dropped as evidence because its load history is not recalled, and the entry 569 ordinal ambiguity is resolved in favour of five captures mapping to five runs. Evidence is `.ai/current_results/entry570_block2_run1` through `run5`, the consolidated `entry570_block2_series.json` and the archived `entry570_arm_helper.log`.

#### Next Steps:

Take the genuine cold sample that is still missing by having the user fully power-cycle the MiSTer at the wall rather than reloading the core or using a menu reset, then play the file five times, so a verified cold-after-power-cycle block can be compared against block 1's verified cold-after-boot capture and entry 568's unverifiable one. Confirm the reboot afterward from `/tmp/messages` rather than from recollection, since that check is cheap and has now twice contradicted the reported procedure. Then run the separation experiment the open conflict requires: after a warm block that has produced a gap, reload only the core without rebooting and replay, which isolates core-reload freshness from page-cache warmth as the operative variable. The planned FTP cache-warming test is now partly redundant for confirming that warmth helps and should be reserved for the case where the power-cycle block comes up cold and gapped, where it would still discriminate mechanism. Pursue the ARM helper log as a first-class evidence source in parallel, since it is the only view of the delivery side: determine from the helper source whether the 4,096-byte read size is fixed or configurable and whether a larger read or readahead would lift the 1.38 times realtime ceiling, and add timestamps to that log if a diagnostic change is later approved. Do not propose a source change until the cold and core-reload cases are separated. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 569 COMMIT Unreleased 2acabc5 2026-08-27T00:04:40-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Collect a repeated-run series from a single reboot to establish the starvation range and determine whether a zero-gap run is reachable on this build.

#### Outcome:

The user rebooted, loaded the core and played the same file in Weave repeatedly, reporting five runs since that reboot. Capture was automated by polling the FTP screenshot trigger and archiving any completed quiet session whose telemetry checksum had not been seen before. Before trusting the series the capture path itself was controlled: six consecutive probes of a static post-run screen returned byte-identical PNGs and identical decoded telemetry, so the capture is deterministic and the five distinct checksums recorded are five distinct sessions rather than repeated reads of one. The poller has one defect worth recording, which is that it exited on reaching a preset four-sample target while the user was still running, so the fifth session was recovered only by a manual probe; the sample cap must be removed before the next block. Absolute run ordinals remain unconfirmed. The user believes the first run was missed, but five distinct sessions were captured and no FTP dropout was logged during the window, which means no reboot occurred inside it, so either the five captures are runs one through five or run one was missed and a sixth run occurred. Capture order is certain and every trend below is order-based and unaffected by that ambiguity. All five sessions pass every acceptance term, accepting all 15,150,646 bytes and displaying 449 pictures with 448 swaps, zero error flags, quiet terminal and presentation complete. The central result is that a zero-gap run is reachable on this build: the fourth capture reported zero cadence outliers and zero missed deadlines, matching entry 564 and establishing that the defect is intermittent rather than universal. Across the capture order, starvation at the ordinal-six deadline falls monotonically through 1,103,135, 1,079,350 and 1,043,165 cycles, then the clean run with no record, then 555,422 cycles, while bytes accepted at that deadline rise monotonically through 312,328, 324,224, 335,258 and 379,200. That is the warming signature the cold-versus-warm inference predicted. The feed rate, however, does not warm continuously; it saturates at about 1.38 times realtime, roughly 1,392,000 bytes per second, with captures two, three and five all at 1.38 exactly as entries 566 and 567 were, and only the colder captures below it at 1.30 and 1.22. That is a ceiling of the delivery path rather than a continuum. Most importantly, warming does not prevent the miss. The fifth capture had the least starvation of any gapped run at 9.26 milliseconds and the highest byte delivery at 379,200, and still lost the ordinal-six slot by the same 4,004,000 cycles. Starvation magnitude therefore does not predict whether the slot is lost, and the ordinal-six miss is a marginal timing race against one specific deadline rather than a simple bandwidth deficit. This materially revises the entry 568 reading that framed the problem as prefill depth alone. Every gap in this block is exactly 4,004,000 cycles, two nominal intervals, leaving entry 568's 6,006,000-cycle gap still the only one of its size, and the writer and DDR path stays clean in every gapped capture with upstream FIFO pending, writer busy and writer capacity blocked all false. Cold sampling remains weak at two samples across all work to date, and those two disagree substantially at 1,659,347 and 1,103,135 cycles. Evidence is the five capture pairs under `.ai/current_results` named `entry569_block1_run1` through `run4` and `entry569_block1_onscreen`, with the consolidated series, capture-method validation and scope limits in `entry569_block1_series.json`.

#### Next Steps:

Resolve the run-ordinal ambiguity with the user before treating the first capture as a cold sample, since that single value is what separates the two competing cold figures. Then run at least two further blocks with the sample cap removed, each a full reboot followed by five uninterrupted replays, so cold sampling reaches a usable count and the zero-gap rate can be estimated rather than inferred from two isolated clean runs. Because starvation magnitude has now been shown not to predict the miss, the more valuable experiment is the one already proposed but not yet run: reboot, load the core, read the media file over FTP to populate the page cache, then play once, which tests the read-latency mechanism directly instead of by correlation. That still requires the media path on the MiSTer, which the user has not yet supplied and which was not found under the obvious locations. Also obtain whether entry 564 was preceded by a reboot, or drop it as evidence. Do not propose a source change yet. The marginal-race result means a release gate conditioned on accepted bytes or queue occupancy alone would not have saved the fifth capture, so any startup-controller boundary must be sized against the deadline timing rather than against a byte threshold, and the delivery ceiling of 1.38 times realtime should be characterised before deciding whether the correct boundary is the startup controller or the ARM-side feed. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 568 COMMIT Unreleased 2acabc5 2026-08-26T23:48:12-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Test the entry 567 hypothesis that the ordinal-six starvation is a warm-reload effect by capturing a cold first Weave run after a full MiSTer reboot.

#### Outcome:

The user rebooted the MiSTer, loaded the core, loaded the file and let it finish, giving the cold first-run sample entry 567 asked for. The stale 476,501-byte probe survived the reboot and was deleted through FTP and confirmed absent before triggering; the new capture is 476,520 bytes with SHA-256 `ac379d4724df8320197fd5686be22a19c58e9b8ff6463aa965d5b50cf33560f8` and a checksum of 4,176,697,056, distinct from all prior sessions. Every acceptance term still passes: all 15,150,646 bytes accepted, 449 pictures displayed with 448 swaps, sequence end seen, presentation complete, quiet terminal reason one, zero error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. The hypothesis is refuted, and refuted in the opposite direction from the one proposed. The cold run does not come up clean; it produces the worst gap measured so far. The single outlier is again at display picture ordinal six but is 6,006,000 cycles, or 100.1 milliseconds, which is three nominal intervals rather than the two seen in both warm runs. Every upstream indicator moves the same way. Input starved cycles since the previous swap rises to 1,659,347, or 27.66 milliseconds, against roughly 1,072,000 cycles or 17.85 milliseconds in entries 566 and 567, an increase of about 55 percent. Accepted bytes at the deadline falls to 296,838 from 323,580 and 331,179, so materially fewer bytes had been delivered by the same deadline. Candidate ready delay rises to 3,230,418 cycles from 592,128 and 271,690. Meanwhile the writer and DDR path stay clean exactly as before, with upstream FIFO pending, writer busy and writer capacity blocked all false and zero capacity-blocked cycles, and writer wait and decoder stall totals sit within the same narrow band as the other three runs. The starvation magnitude therefore tracks how cold the media source is rather than any session rearm state, which is consistent with ARM-side file read latency during startup and inconsistent with the delivery-rearm boundary entry 567 nominated. The guarded startup did not absorb the deficit: presentation hold total is the lowest of all four runs at 26,390,166 cycles, so the guard released on readiness while the feed was still behind, and the residual non-gap startup excess of 2,580,696 cycles remains below the clean entry 564 run's 3,002,892. Ranked gaps two and three are exactly 2,002,000 cycles in this run as in every other, confirming once more that steady-state cadence after the startup hitch is nominal and that the whole defect is confined to initial prefill depth ahead of the first cadence deadline. This is one cold sample and does not establish a cold-run rate. Entry 564 is now the only zero-gap run out of four and its load history was never recorded, so it cannot be classified as cold or warm and cannot anchor either hypothesis. Page-cache state is not measured by this telemetry, so the read-latency explanation is inference from the starvation and byte-delivery figures rather than direct measurement. Deinterlace mode and load history are not encoded in the snapshot and rest on the user's report. No source change or build was performed for this entry, and no reload, reboot, MGL launch, media change or configuration change was made during capture. Evidence is `.ai/current_results/entry568_cold_weave_terminal.png` and `entry568_cold_weave_capture.json`, the latter carrying the full decode, the four-run series, the ordinal-six comparisons and these scope limits.

#### Next Steps:

The boundary is now initial prefill depth ahead of the first cadence deadline, not delivery rearm and not the presentation scheduler, so the remaining evidence needed is the size of the deficit rather than more mode or reload permutations. Have the user take two or three further cold runs, each after a full reboot, and two or three further warm replays, capturing telemetry after every single one and stating which is which, so the cold and warm starvation windows acquire a range instead of one sample each and so it can be established whether any run still reaches zero gaps under known conditions. Ask specifically whether the entry 564 run was preceded by a reboot, since reclassifying it would settle whether a clean run is reachable at all on this build. With that range in hand the fix boundary can be sized directly: the guarded startup controller currently releases the first picture on readiness alone, and the measured 27.66-millisecond cold starvation window against a 33.37-millisecond cadence slot indicates the release gate needs a minimum accepted-bytes or queue-occupancy condition in addition to readiness, which is a bounded change to the startup controller rather than to the queue depth or the scheduler. Extend the existing drained-FIFO warm-load simulation cases to model both measured starvation windows before proposing that change, and do not commit source until the user approves the revised plan. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged in the meantime. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 567 COMMIT Unreleased 2acabc5 2026-08-26T23:43:47-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the hardware telemetry from the user's Weave-mode run of `2acabc5` to determine whether the entry 566 ordinal-six gap depends on deinterlace mode.

#### Outcome:

The user accepted the entry 566 result, played a file in Weave mode and left the terminal telemetry on screen. The stale 476,509-byte probe from entry 566 was deleted through FTP and confirmed absent before triggering, and the new capture is 476,501 bytes with SHA-256 `57f242d044e927970686a0534a8b2a0ce859558b4a72921a0aae54900d17ed65`; its checksum of 4,099,361,451 and session length of 903,162,447 cycles both differ from entry 566, so this is a distinct session and not a stale re-read. The Weave run is functionally identical to the Bob run in every acceptance term. It accepts all 15,150,646 bytes, displays 449 pictures with 448 swaps, sees sequence end, completes presentation and terminates quietly with reason one, reporting zero error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. It also reproduces the defect exactly: one cadence outlier and one missed deadline, again at display picture ordinal six, again a 4,004,000-cycle interval of 66.7333 milliseconds that is precisely two nominal intervals, with ranked gaps two and three at exactly 2,002,000 cycles so that steady-state cadence away from the hitch is nominal. The ordinal-six deadline record carries the same upstream starvation signature as entry 566. Input starved cycles since the previous swap is 1,070,840 against 1,075,462 in Bob, a difference of only 4,622 cycles or 0.077 milliseconds, and in both runs the candidate is not presentable while upstream FIFO pending, writer busy and writer capacity blocked are all false with zero capacity-blocked cycles and a last reference completion age of about 3,912,352 cycles after five completed references. The micro-state differs only in which side of the same starvation is sampled: this run shows decoder ready false with decoder input pending true, whereas entry 566 showed decoder ready true with decoder input pending false, and the candidate ready delay is 271,690 rather than 592,128 cycles. Two independent sessions in opposite deinterlace modes producing the same ordinal, the same gap magnitude and the same starvation window establish that the defect is reproducible and that Bob versus Weave is not the variable; the failure is upstream delivery during early startup, not the presentation scheduler, the writer, DDR capacity or the deinterlacer. Total cadence excess over 448 nominal intervals is 4,393,879 cycles, of which 2,002,000 is the lost slot and 2,391,879 is the guarded startup hold, which sits between entry 566's 2,053,370 and the clean entry 564 run's 3,002,892 and therefore shows no startup regression. The 29.823923-fps aggregate again begins at first reference completion and includes that hold, so it is not a steady-state rate. Deinterlace mode is not encoded in the snapshot, so the Weave attribution rests on the user's report, and it is not known whether this was a cold first load or a warm reload. Two samples establish reproducibility rather than a rate, and entry 564 remains a clean counter-example under the same source. No reload, reboot, MGL launch, media change or configuration change was made during capture, and no source change or build was performed for this entry. Evidence is `.ai/current_results/entry567_weave_terminal.png` and `entry567_weave_capture.json`, the latter carrying the full decode, the entry 564 and 566 comparisons, the ordinal-six record diff and these scope limits.

#### Next Steps:

Stop collecting mode variations, because mode has been eliminated as a factor, and instead determine whether the ordinal-six starvation correlates with load history. Have the user power-cycle or reload the core and capture telemetry after the very first playback of a fresh core load, then after each of several successive replays without reloading, recording the run ordinal alongside each capture, so it can be established whether entry 564's clean result was specifically a cold first run and whether the starvation appears only on warm rearm. That distribution is the missing evidence needed to choose a boundary. If cold runs are clean and warm runs starve, the investigation belongs in ARM-side delivery rearm across successive sessions and the existing drained-FIFO warm-load simulation cases should be extended to model the measured 1,070,840-to-1,075,462-cycle starvation window before any RTL change is proposed; if cold runs starve too, the boundary is initial prefill depth ahead of the first cadence slot instead. Do not propose a source change until that data exists. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 566 COMMIT Unreleased 2acabc5 2026-08-26T23:38:54-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the hardware telemetry from the user's repeated-load Bob test of `2acabc5` after they reported playback appearing slower.

#### Outcome:

The user replayed the same file several times in Bob mode without rebooting, reported that after a few runs it seemed to run slowly, and left the final run's terminal telemetry on screen. The stale 476,291-byte `cadence_probe.png` was deleted through FTP and confirmed absent before a new screenshot was triggered, so this is a genuinely fresh capture at 476,509 bytes with SHA-256 `11955026d61bd37806f994b4ed784e8f69227622fc51b10f5e16e9987c898eee`. The captured session still accepts all 15,150,646 bytes, displays 449 pictures with 448 swaps, sees sequence end, completes presentation and terminates quietly with reason one, zero aggregate error flags, no cache-bank overlap, no presentation error, no audio underrun, no PCM protocol error and no timestamp advance or delay conflicts. Unlike the clean entry 564 run, however, both the ranked-gap and actual missed-deadline counters are one rather than zero. The single outlier and the single deadline record are the same event at display picture ordinal six, a 4,004,000-cycle interval of 66.7333 milliseconds, which is exactly two nominal intervals and therefore one frame held for an extra field pair. Ranked gaps two and three are exactly 2,002,000 cycles, so steady-state cadence away from that one hitch is nominal and the entry 559 miss at ordinal 348 does not recur. The ordinal-six deadline record is diagnostic: at 323,580 accepted bytes the decoder is ready, the candidate is not presentable, decoder input pending, upstream FIFO pending, writer busy and writer capacity blocked are all false, writer capacity blocked cycles since the previous swap is zero, candidate ready delay is 592,128 cycles and input starved cycles since the previous swap is 1,075,462, or about 17.9 milliseconds. That signature is upstream input starvation during early startup, not a decoder, writer or DDR capacity stall, and it is the same failure class as the legacy picture-six gap that the 64-KiB clean-video queue and guarded startup were meant to close. The startup guard itself did not regress: presentation hold total fell from 27,400,352 to 27,074,752 cycles and the residual non-gap cadence excess fell from 3,002,892 to 2,053,370 cycles, so of the 4,055,370-cycle total excess over 448 nominal intervals, 2,002,000 is the single dropped slot and the remainder is a slightly shorter guarded startup wait than the accepted run. The 29.835129-fps aggregate again starts at first reference completion and includes that startup hold, so it must not be read as steady-state slowness; the honest statement is one lost frame near the start, not a globally slower run. Schema nineteen telemetry is per-session and this snapshot covers only the most recent completed session, so the earlier repeats in which the user first noticed the problem are not captured and cannot be reconstructed, and neither Bob/Weave selection, loaded-file identity nor position within the repeat sequence is encoded in the snapshot. No reload, reboot, MGL launch, media change or configuration change was made during capture, and no source change or build was performed for this entry. Evidence is `.ai/current_results/entry566_bob_repeat_terminal.png` and `entry566_bob_repeat_capture.json`, the latter carrying the full decode, the entry 564 comparison, the interval arithmetic and these scope limits.

#### Next Steps:

Do not commit a speculative fix on one sample. Have the user repeat the load several times again and capture telemetry after each individual run rather than only the last, so the distribution of ordinal-six starvation across cold and warm loads is measured instead of inferred, and have them note which run number each capture belongs to along with whether the perceived slowness tracks the captured gap. Also ask whether the reported slowness persisted visually through a whole run or was a brief hitch near the start, since the telemetry supports only the latter. If repeated captures confirm that ordinal-six input starvation returns on warm reloads while the first load after core load is clean, the boundary to investigate is upstream ARM-side delivery rearm across successive sessions rather than the presentation scheduler or the startup guard, and the existing drained-FIFO warm-load simulation cases should be extended to model the measured 1,075,462-cycle starvation window before any RTL change is proposed. Keep the accepted continuous HDMI sync fix, the 64-KiB clean video queue, the guarded readiness-based startup controller and the black startup background unchanged. Bob/Weave switching has still not been reported on and remains outstanding, analog diagnostics remain excluded, and interlaced P/B, field pictures, field DCT, partial-transfer cancellation and the live-raster assertion drift all remain outside this entry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 565 COMMIT Unreleased 2acabc5 2026-08-26T23:21:45-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Record the current accepted build, recovery context and outstanding validation for an agent handover requested by the user.

#### Outcome:

The current production source is `2acabc5457171f342a06f93b1edfb1c361748ce8`, with all source changes committed on master; subsequent commits are project-memory updates. The installed and user-loaded `/media/fat/MediaPlayer.rbf` is the qualified 4,346,416-byte image with SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347`. The user says playback looks perfect. Entry 564 is the latest hardware acceptance: the requested clean Bob run of `bbb_480i_tff_15s_8mbps.m2v` accepts all 15,150,646 bytes, displays all 449 pictures with 448 swaps, terminates quietly and reports zero errors, zero cadence outliers and zero missed deadlines. The previous misses at pictures six and 348 are absent, and the maximum post-first-swap interval is exactly 2,002,000 clocks, consistent with 29.970030-fps steady playback. The aggregate 29.870022-fps figure includes startup because schema nineteen timestamps first reference completion rather than first visibility; do not treat it as renewed slowness. The user accepts the now-black idle background, which is the RGB startup mask, not a new sync or raster change. Preserve the earlier continuous-HS/VS framebuffer fix from `30d300a`, the 64-KiB clean-video queue and the guarded readiness-based startup controller. The controller waits for another presentable picture or short-file sequence end, releases the first cached picture at a complete field-pair boundary, then observes the acknowledged window high and low before enabling swaps; this last guard is essential because the preceding `134b401` controller fails the deliberately skewed CDC test. Timestamp/PCM records, incompatible pictures and non-native sessions bypass the reserve. The final build uses seed 16 and has positive setup, hold, recovery, removal and pulse-width margins of 0.141, 0.249, 3.830, 0.531 and 0.925 ns, with 512 of 553 RAM blocks occupied. The eleven-scenario simulation matrix covers 540 matching reconstructed pictures, full-file and dense-pause cases, alternate phases, drained-FIFO warm sessions, short EOF and modeled DDR pressure; the native suite and updated skew test pass. These are not an exact physical host/HDMI replay, partial-transfer cancellation test or independent pixel oracle. Build, validation and deployment manifests are `.ai/current_results/entry562_build.json`, `entry562_validation.json` and `entry562_deployment.json`; the latest screenshot and complete hardware decode are `entry564_bob_terminal.png` and `entry564_bob_capture.json`. GUNSMOKE is available through the configured SSH alias `mister-build`; the clean official build and RBF are under `/home/vash/mister-builds/entry562-2acabc5`, final simulation reports under `/home/vash/mister-builds/entry562-results`, and the unchanged native-suite log under `/home/vash/mister-builds/entry561-results`. The simulation checkout `/home/vash/mister-builds/entry561-sim` has a historical detached HEAD and modified files whose final source identity was verified; use published GitHub source for subsequent official builds. The superseded `entry561-134b401` build was stopped and must not be deployed. The Pi repository has no outstanding tracked source edits; eleven older untracked diagnostic PNGs were deliberately left untouched. No new source change or build is pending. The user requested this handover before performing the remaining repeated-load/mode-switch checks, so their result must not be assumed.

#### Next Steps:

Follow `core.md` recovery policy and resume with the remaining hardware test, not another speculative fix: ask the user to replay the same file several times without rebooting and switch Bob/Weave, reporting any flicker, pacing or load problem and leaving final telemetry visible. Capture through ordinary FTP only at MiSTer `10.10.0.30`; delete only `/media/fat/screenshots/cadence_probe.png` before triggering a new screenshot to prevent stale-file reuse, then decode with the existing cadence tools. Do not remotely reload, reboot or launch through MGL. Standing authorization permits future direct active-RBF replacement only after a qualified build and fresh complete FTP readback, without backup or staging files. Keep HDMI at the user's existing 1080p configuration and keep analog diagnostics excluded. If repeated loads and Bob/Weave also pass, close the bounded all-I HDMI cadence correction and obtain approval for the next audio/PTS qualification or broader interlaced implementation boundary. Interlaced P/B, field pictures and field-DCT remain unsupported; partial-transfer cancellation and the old 6,529,996-versus-6,529,997 live-raster assertion drift remain unvalidated or unresolved. Do not reuse entry 550's unvalidated pixel harness as a passed oracle. Keep `core.md` unchanged, preserve the forty-entry log ring and publish future approved plans before editing production source.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 564 COMMIT Unreleased 2acabc5 2026-08-26T23:19:26-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Validate the guarded startup and larger input queue against the requested clean Bob hardware run.

#### Outcome:

The user reports that playback looks perfect and observes that the former grey 800x600 background is now solid black, without considering that a defect. A fresh FTP screenshot was triggered after deleting only the old fixed screenshot target; its schema-nineteen checksum validates all 15,150,646 bytes, 449 decoded and displayed pictures, 448 swaps, sequence end, presentation completion and quiet terminal reason one with zero aggregate errors. Both ranked-gap and actual missed-deadline counters are zero, the deadline-record array is empty, and all three largest measured post-first-swap intervals are exactly 2,002,000 decoder clocks, or 33.366667 milliseconds. The previous picture-six and picture-348 missed windows from entry 559 therefore do not recur in this run, consistent with the user's visual acceptance and the intended steady 29.970030-fps schedule. The raw aggregate remains 29.870022 fps because schema nineteen starts at first reference completion and includes startup buffering and raster alignment; its 899,898,892-cycle span exceeds 448 nominal intervals by 3,002,892 clocks, or 50.0482 milliseconds, without any post-startup gap. This is not evidence of slower steady playback. The black idle background follows directly from the RGB startup mask remaining active before picture release; DE, HS, VS and the idle timing generator are unchanged. This entry passes the requested clean Bob elementary-stream hardware case, not all interlaced formats or repeated-load conditions. Bob selection and loaded-source identity follow the user's preceding reload/run workflow rather than being encoded in the screenshot. No core, media, configuration or lifecycle change was made during capture. Evidence is `.ai/current_results/entry564_bob_terminal.png`, 476,291 bytes with SHA-256 `c442dd2144982f65b4bc19d0cdd07c1399936133e8e30f6ec90fcd6a1feeaf2b`, and `entry564_bob_capture.json`, including the complete decode, comparison, calculations and scope limitations.

#### Next Steps:

Have the user replay the same file multiple times without rebooting and test Bob/Weave switching, leaving the final telemetry visible and reporting any flicker, pacing change or loading problem. Preserve the accepted clean-run behavior and black startup background. If those checks also pass, close the current HDMI cadence correction for the bounded all-I path and move to a separately approved audio/PTS qualification boundary before broader interlaced P/B, field-coding and format work. Partial-transfer cancellation and the pre-existing live-raster assertion drift remain outside this hardware acceptance, and analog diagnostics remain excluded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 563 COMMIT Unreleased 2acabc5 2026-08-26T23:13:49-07:00

#### Coming From:

Unreleased 2acabc5

#### Purpose:

Qualify and deploy the guarded native startup and larger input queue for the next clean HDMI cadence test.

#### Outcome:

Source `2acabc5` completes a clean Quartus 17.0.2 Lite build from empty generated state on GUNSMOKE in 722.51 seconds with seed 16, zero errors and 208 warnings. All timing classes are positive: setup 0.141 ns, hold 0.249 ns, recovery 3.830 ns, removal 0.531 ns, minimum pulse width 0.925 ns; every reported total negative slack is zero. The fit uses 31,304 ALMs, 49,685 registers, 4,048,355 block-memory bits, 512 RAM blocks and 67 DSP blocks. All sixteen unmatched diagnostic/reset timing filters are inherited from the installed schema-nineteen source; none of the new startup crossings is unmatched, and the tracked build source remains unchanged. Eleven simulation scenarios cover 540 reconstructed pictures across thirteen sessions, with every picture fingerprint matching its corresponding full-source baseline picture. The full 449-picture run under a synthetic thirty-millisecond host-resume pause has zero post-startup gaps; its visibility-based span is 896,896,004 decoder cycles, approximately 29.970030 pictures per second, with a few clocks of observation skew. The dense source-340-through-355 excerpt passes a forty-five-millisecond pause without the three legacy gaps, as do alternate phases, three drained-FIFO warm loads, periodic DDR pressure and one/two-picture EOF cases. The legacy 16-KiB/no-reserve control still reproduces its expected picture-six gap. The 24-phase deliberately skewed startup test passes, while the previous controller fails the same control by replacing the first bank at its initial visible boundary. The native suite exits successfully in 839.54 seconds; its timing, framebuffer, ownership and profiler source is unchanged by the guard correction, and its changed initial startup invocation is superseded by the separately passing corrected test. The queue capacity/wrap regression passes 85,696 bytes, four ordered timestamps and three PCM samples. The pipeline model uses synthetic host pauses, behavioral FIFO visibility and synthetic field windows, not a measured hardware trace or full HDMI raster; fingerprints establish scheduling invariance rather than an independent pixel oracle. Schema nineteen's aggregate still starts at first reference completion and includes startup buffering, so steady swap intervals and deadline counts remain the hardware cadence criterion. The 4,346,416-byte RBF has SHA-256 `fb5f61b5b9ad934a7e19a6a9ee7cedcbd537747c2722b618902039b3698a1347` and was directly installed at `/media/fat/MediaPlayer.rbf` under standing authorization. A fresh independent FTP connection read back the entire active image with matching size and hash; no backup, staging file, reload, reboot or media/configuration change was made. Build, validation and deployment evidence is in the three entry-562 JSON files under `.ai/current_results`; full logs and traces remain under `/home/vash/mister-builds/entry562-results` and the clean build directory `/home/vash/mister-builds/entry562-2acabc5`. Hardware acceptance is pending, partial-transfer cancellation is not covered by the drained-FIFO warm test, and the pre-existing live-raster assertion drift remains unresolved.

#### Next Steps:

Have the user reload the installed `2acabc5` core, select Bob and play `bbb_480i_tff_15s_8mbps.m2v` once without mode or menu changes, then leave terminal telemetry visible for a fresh capture. Check all 449 pictures and 448 swaps, terminal completion, zero aggregate errors and zero deadline gaps, especially the prior ordinals six and 348; distinguish the deliberate startup wait from steady playback cadence. If the clean run passes, repeat loads and Bob/Weave switching before claiming the cadence issue resolved. Keep analog diagnostics out of scope and preserve the accepted continuous HDMI sync fix.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 562 COMMIT Unreleased 2acabc5 2026-08-26T22:55:24-07:00

#### Coming From:

Unreleased 134b401

#### Purpose:

Make the first complete visible field pair independent of relative synchronizer latency before qualifying the startup candidate for hardware.

#### Outcome:

Source `2acabc5` adds an explicit observed-window guard to the approved startup implementation. After the video-domain visibility acknowledgement arrives, the decoder must observe the synchronized first window high and then low before allowing any swap, removing dependence on the relative arrival order of two independent synchronizers. The first visible bank therefore remains for a complete field pair even when the window crossing is delayed. The directed test alternates ordinary and deliberately delayed window crossings across 24 readiness phases and passes full-first-pair, short EOF, warm download rearm, interrupted startup, bypass and Bob/Weave controls. As a negative control, the same skew test fails the previous 134b401 controller with shown and first-swap boundary both seven, proving it detects the race. The correction does not change intended frame timing, queue size, sync, ownership or timestamp policy. The superseded build and unfinished full simulation were stopped without deployment; completed initial-candidate tests remain evidence only for that source. A fresh empty-state Quartus build and full real-pipeline simulation matrix are now running for 2acabc5. The existing native suite continues with unchanged timing, framebuffer, scheduler and profiler source, and the changed startup controller/test has been separately rerun. Hardware acceptance remains pending.

#### Next Steps:

Finish the corrected-source full-file, dense-excerpt, input-pause, phase, short-file and warm-load matrix with pixel-identity comparison, and verify the unchanged native-suite source provenance plus the separately updated startup result. Require a successful clean build with positive setup, hold, recovery, removal and pulse-width margins before direct active-image replacement and independent full FTP readback. Record those outcomes in a new entry and leave reload and the clean Bob run to the user.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_native_startup.sv
- MediaPlayer_top_05.svh
- tools/streams/tb_h262_native_startup.sv
- tools/streams/tb_h262_input_cadence.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 561 COMMIT Unreleased 134b401 2026-08-26T22:44:26-07:00

#### Coming From:

Unreleased c4628b5

#### Purpose:

Increase resilience to delivery pauses with a larger clean-video queue and coherent readiness-based startup for native elementary-stream playback.

#### Outcome:

Source `134b401` implements the approved 64-KiB clean-video queue and native 29.97-fps elementary-stream startup reserve. It waits for a second presentable picture or terminal sequence end, unmasks the cached first bank at a complete field-pair edge and admits scheduler swaps only after that edge's synchronized visibility acknowledgement. HS, VS, DE, framebuffer sync sampling, raster clocks and ownership remain unchanged. Extracted timestamp or PCM records, non-I headers, syntax/probe errors and non-native or other-cadence sessions bypass the reserve; bypass is sticky until a new download. The actual eight-cycle download-rearm controller passes 24 readiness phases, short EOF, progressive and cadence bypass, interrupted startup and Bob/Weave controls. The extended queue test retains all 65,536 bytes at capacity and passes 85,696 ordered bytes across wrap with four correctly positioned timestamp records and three PCM samples. The first eight-picture real-pipeline run under a synthetic thirty-millisecond host-resume pause has zero missed windows or deadline gaps, with initial visibility at cycle 4,198,676 and the first actual swap one full frame later. An initial test harness wired the profiler to the old synthetic window instead of the new synchronized window and incorrectly reported six gaps; aligning that passive tap to production resolves the discrepancy without changing production control. Full-file, dense-excerpt, alternate-phase, drained-FIFO warm-session and native-suite checks are running on GUNSMOKE. Schema nineteen still measures its aggregate from first reference completion; its post-first-swap deadline records exclude startup, and the harness additionally reports visibility-based spans. This is input-pause resilience, not faster decoding or an exact replay of the hardware picture-348 miss. No Quartus build or hardware replacement has completed yet.

#### Next Steps:

Finish the full-file fingerprint, pause, reload and native regressions, pull the published source from GitHub into an empty build checkout on GUNSMOKE and require positive setup, hold, recovery, removal and pulse-width timing plus a fitting memory allocation. Record qualification and any subsequent findings in a new entry, then directly replace the active MiSTer image under standing authorization and verify a fresh full FTP readback. Leave reload to the user and request one clean Bob run before repeated-load and Bob/Weave checks. The separate live-raster assertion drift remains unresolved and partial-transfer HPS cancellation is not covered by the drained-FIFO warm test.

#### Files Modified:

- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_native_startup.sv
- MediaPlayer_top_05.svh
- MediaPlayer_top_07.svh
- MediaPlayer.sdc
- files.qip
- tools/streams/tb_h262_input_cadence.sv
- tools/streams/run_input_cadence.py
- tools/streams/tb_h262_clean_video_queue.sv
- tools/streams/tb_h262_native_startup.sv
- tools/streams/run_native_480i_timing.sh
- README.md

#### Status:

- [ ] Built
- [ ] Passed

---

## 560 COMMIT Unreleased c4628b5 2026-08-26T22:38:14-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Evaluate input buffering and startup reserve with the real decode pipeline before selecting a cadence correction.

#### Outcome:

The user approved the simulation work recommended after entry 559. Source `c4628b5` adds a reproducible real-frontend, I reconstruction, writer, scheduler and profiler harness through the production HPS FIFO wrapper, transport gate, metadata extractor and clean-video queue. Behavioral FIFO primitives provide bounded showahead storage, byte ordering and synchronized pointer visibility; they are not cycle-exact Intel or physical CDC models. The final direct-input control matches entry 557's header, completion and presentation traces cycle for cycle. Twenty-five scenarios pass byte/order, sample-count, bank-generation, final-drain and counter-partition checks, and all 1,543 reconstructed pictures have fingerprints matching the corresponding pictures in the full-stream baseline; these fingerprints are scheduling-invariance checks, not a new independent pixel oracle. Full 449-picture runs complete in approximately 695 seconds each. The default queues have only the known picture-six gap; adding a synthetic thirty-millisecond host-resume pause increases its critical input wait to 886,005 clocks and produces additional service delay elsewhere, but still does not reproduce the hardware picture-348 miss. A simulation-only 64-KiB clean-video queue plus startup reserve eliminates post-startup gaps across all 449 pictures under that scenario. In a separate excerpt of the exact source pictures 340 through 355, starting with fresh decoder state and a forty-five-millisecond resume pause, default buffering produces gaps on source pictures 348, 349 and 352; the combined experiment removes all three with identical picture fingerprints. This excerpt is not a replay of the hardware state or host trace. Smaller-buffer, alternate-phase, periodic-DDR-busy and full-reset repeated-session controls pass their checks; the one-picture terminal case drains correctly. A deliberately sparse two-picture control distinguishes 47,826 clocks of transform overlap from critical byte waits, validating why the earlier hardware ready/empty count cannot all be treated as critical delay. The startup experiment suppresses raw frame windows: in the tested phases two suppressions move the first actual swap by one frame, or 33.367 milliseconds. It moves the early hold into startup and does not accelerate decoding or shorten the full-stream completion time. Production startup must instead release display and timing coherently based on readiness; the raw-window experiment must not be copied blindly. Warm partial download rearm, Bob/Weave interaction, physical host scheduling and full HDMI/DDR behavior are not newly validated here. Results, commands, hashes and limitations are preserved in `.ai/current_results/entry560_input_simulation.json`, with complete per-case reports and CSV traces under `/home/vash/mister-builds/entry560-results`. All production RTL, constraints and the installed `31a87b6` image remain unchanged. No Quartus build or new hardware acceptance was performed.

#### Next Steps:

Request approval to implement and hardware-test a 64-KiB clean-video queue with readiness-based startup reserve, preserving continuous HDMI sync, field-pair timing, ownership and byte/metadata ordering. Treat the simulation as evidence for resilience to input delivery pauses, not proof that the exact hardware picture-348 cause has been recovered. Define initial display release and cadence measurement explicitly so startup buffering is not mistaken for a playback-speed correction, and preserve audio/timestamp semantics rather than applying the elementary-stream experiment indiscriminately. Extend the relevant startup, short-file, warm-reload and native-mode regressions, then require a clean successful Quartus build with every timing class positive before the standing-authorized replacement and fresh complete FTP readback. Repeat the known clean Bob file before subsequent Bob/Weave and repeated-load checks.

#### Files Modified:

- tools/streams/tb_h262_input_cadence.sv
- tools/streams/run_input_cadence.py

#### Status:

- [ ] Built
- [ ] Passed

---

## 559 COMMIT Unreleased 31a87b6 2026-08-26T22:13:16-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Read the first hardware deadline capture and distinguish missing presentation candidates from scheduler refusal.

#### Outcome:

The user reported the requested file run complete and telemetry ready. A fresh FTP screenshot, after removing only the old fixed screenshot target, validates as schema nineteen with checksum and full counters: all 15,150,646 bytes, 449 decoded/display pictures and 448 swaps, sequence end and presentation completion, and zero aggregate error flags. Two confirmed doubled intervals are explicitly associated with full picture ordinals six and 348; the earlier modulo-bank inference is now directly corroborated. Neither candidate was presentable at its actual missed window, with only five and 347 completed references respectively, and neither presentation nor destination hold was asserted. Candidate six became ready 28.854 milliseconds late, while candidate 348 became ready only 0.297 milliseconds late; each missed window added one 33.367-millisecond frame period. The preceding swap-to-deadline intervals contain 13.594 and 15.129 milliseconds with the decoder ready but its clean-video queue empty, versus zero and 36 clocks of writer-capacity blocking. In both records, the clean-video queue had a byte available at the captured deadline itself, when the decoder was busy. These measurements identify late candidate production and substantial earlier input-availability gaps, not an on-time candidate rejected at either window. They do not yet prove a specific host-refill cause: the one-byte bitreader can advertise readiness while the parser is in `ST_WAIT_PIPELINE`, so input-ready/empty time can overlap transform work and must not all be counted as critical-path delay. The counters cover only the previous display interval, and writer-capacity blocking does not measure every DDR-service delay. The 347-completion to 348-readiness interval is 61.911 milliseconds in hardware versus 44.903 milliseconds between completions in the ideal-input/DDR simulation, an additional 17.008 milliseconds; the different initial raster phase and unobserved host schedule prevent treating that comparison as an exact replay. At picture 348's deadline the accepted stream position is just 83 bytes before the next picture header. The input path has a 32-KiB HPS FIFO followed by the metadata extractor and a 16-KiB clean-video queue, providing a concrete next simulation boundary without changing HDMI timing. Overall cadence is 29.806318 pictures per second over 15.030370 seconds; two doubled gaps contribute 66.733 milliseconds, while another 15.370 milliseconds comes from the first-reference-completion versus later-swap timestamp basis. The screenshot and complete decode, calculations and limitations are retained in `.ai/current_results/entry559_bob_terminal.png` and `entry559_bob_capture.json`; screenshot SHA-256 is `50571f4d7558c24fee23cced747f39d5a80b3ee887d9bb03411c8633b0d9ea17`. No production source, active image, display settings or core lifecycle changed during capture. The diagnostic yielded useful hardware evidence, but the remaining cadence issue is not resolved and this elementary stream does not validate audio synchronization.

#### Next Steps:

Request approval for the next cadence cycle: extend the real-pipeline simulation with the existing HPS ingress, extractor and clean-video queues, separating critical byte waits from transform overlap and varying refill pauses within the measured evidence rather than claiming an invented host trace is ground truth. Compare startup reserve, input buffering and bounded decode-headroom improvements, preserving byte/pixel identity, end-of-stream draining, repeated-load behavior, Bob/Weave transitions and the accepted continuous HDMI sync. Select a playback change only after its benefit and limits are demonstrated; then require existing regressions, a clean positive-timing build and independently verified deployment before another hardware test. No additional screenshot is needed before that simulation work.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 558 COMMIT Unreleased 31a87b6 2026-08-26T22:07:06-07:00

#### Coming From:

Unreleased 31a87b6

#### Purpose:

Qualify and deploy the approved passive deadline diagnostic while retaining the accepted HDMI sync correction.

#### Outcome:

Source `31a87b6` completed a clean Quartus 17.0.2 Lite build on GUNSMOKE in 688.32 seconds with seed 16, zero errors and 208 warnings. Every timing class is positive: setup 0.240 ns, hold 0.252 ns, recovery 3.363 ns, removal 0.567 ns, minimum pulse width 0.925 ns; all reported total negative slack values are zero. The 4,280,760-byte image has SHA-256 `3ab905467e890366a091a31884639cce6a79626413f5eb16f72a8d0756b702b5`. The full existing native-video script exited successfully, including presentation overlap, continuous sync across generation resets, both field orders, cache fault controls, three-generation ownership with delayed memory, writer fingerprints and the schema-nineteen recorder/screenshot round trip. Separate queue and writer availability tests also pass. The simulated tracked source outside metadata is byte-identical to the official build checkout. An additional real frontend, reconstruction, writer, scheduler and profiler simulation of the exact first eight source pictures reproduces only the picture-six miss: its candidate becomes ready 669,812 decoder clocks, or 11.164 milliseconds, after the missed window, with zero decoder-input starvation and zero writer-capacity blocking. This validates recorder attribution under ideal input and DDR availability, not the cause of the hardware picture-348 gap. The accepted framebuffer, timing generator, scheduler, scaler, constraints and seed remain unchanged from `30d300a`; this is a diagnostic image, not a cadence fix. Under the user's standing replacement authorization, the active `/media/fat/MediaPlayer.rbf` was replaced directly over FTP, and an independent fresh connection read back the entire image with matching size and SHA-256. No core reload or reboot was triggered. Build, validation and deployment evidence is preserved in the three entry-557 JSON files under `.ai/current_results`, with full reports and test artifacts under `/home/vash/mister-builds/entry557-31a87b6` and `/home/vash/mister-builds/entry557-diagnostics`. Hardware validation remains pending. The separate live-raster soak's previously recorded assertion drift was not addressed or reported as passing. In response to the user's roadmap question, the recommended later sequence is current 480i HDMI and audio/timestamp qualification, interlaced P/B and field-coding support, then broader cadence and format coverage; those later implementation changes are not part of this approval.

#### Next Steps:

Have the user reload the core, select Bob and play `bbb_480i_tff_15s_8mbps.m2v` once without further menu or mode changes, leaving terminal telemetry visible. Capture and validate schema nineteen, then inspect the full picture ordinals, actual missed-window readiness, clean-queue starvation and writer-capacity blocking before proposing a playback change. Preserve the accepted HDMI sync behavior and leave analog diagnostics out of scope. After this clean case, retain repeated file loads and Bob/Weave switching as regression conditions. Require a measured explanation and an approved fix before claiming the remaining cadence issue is resolved.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 557 COMMIT Unreleased 31a87b6 2026-08-26T21:45:31-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Capture decoder-input and presentation readiness at missed native frame deadlines without changing playback behavior.

#### Outcome:

The user approved the passive diagnostic build proposed in entry 556. Source `31a87b6` implements schema nineteen using the unchanged sixty-four-word overlay geometry and common cadence/error counters, replacing the retired framebuffer-detail payload with full sixteen-bit picture/swap counts and the first three confirmed missed-deadline records. Each record retains the upcoming display ordinal, completed-reference count, exact window state, completion age, decoder-input starvation and writer-capacity stall counts, accepted byte position and subsequent candidate readiness delay. The observer samples the window bus coherently, waits one further clock for the scheduler's registered bank change, and retains a miss only if a later presentation confirms that the gap eventually ended. This avoids both an on-time swap being misclassified from its old bank and terminal idle consuming record slots. Availability is tapped directly before the decoder instead of inferred from the upstream HPS FIFO; writer-capacity blocking is observed separately from its acknowledgement pulse and DDR busy level. The continuous HDMI sync fix, raster, decoder arithmetic, scheduler admission/ownership, memory transactions and queue control are unchanged. The extended RTL test passes exact window-state retention, eleven measured input-starvation cycles, writer attribution, late and already-ready candidates, on-time swaps, ordinal 348, multiple windows in one gap, bounded record retention, terminal idle and session/mode reset. A saved RTL packet decodes correctly through a rendered screenshot with ordinals three, four and 348, and the Python suite also passes legacy layouts, full 449-picture counts/rate and saturation handling. Queue and writer tests prove the new availability taps against real retained bytes and a blocked two-bank drain. Retired framebuffer fields are explicitly unavailable in schema nineteen rather than decoded as errors. The unchanged native-video regression is still running; no official Quartus image has yet been built or deployed. The user's question about using simulation alone was answered with the remaining boundary: the integrated ideal-input/DDR simulation does not reproduce the hardware picture-348 delay, so measured hardware wait evidence is needed before claiming its cause.

#### Next Steps:

Implement the passive taps and event recorder, extend the existing profiler and screenshot-decoder tests for exact-boundary capture, late readiness, input-versus-writer attribution, ordinal wrap, on-time presentation, terminal idle and repeated-session reset, and retain the native sync regressions. Commit the validated source from the Pi and pull it into a clean GUNSMOKE build directory. Require a successful Quartus build with positive timing in every class before directly replacing the active MiSTer image under the standing authorization, verifying the complete image through independent FTP readback and leaving core reload to the user. Request one clean Bob playback for the new capture before exercising repeated loads or Bob/Weave changes.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_04.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_new/mpeg2_h262_clean_video_queue.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_hardware_cadence_profiler.sv
- tools/streams/tb_h262_clean_video_queue.sv
- tools/streams/tb_h262_ddram_store_overlap.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/test_decode_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh

#### Status:

- [ ] Built
- [ ] Passed

---

## 556 COMMIT Unreleased 30d300a 2026-08-26T21:40:34-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Compare a rebooted single Bob run with the warm-session cadence result and extend the reproduction through the production writer and publication scheduler.

#### Outcome:

The user rebooted the MiSTer, loaded the core, selected Bob and played the established clip once without reported playback interaction. A fresh FTP screenshot, obtained after deleting only the fixed old screenshot target, validates as schema eighteen and is preserved in `.ai/current_results/entry556_bob_cold_terminal.png`; its SHA-256 is `08c04b672a845736dd5f6f65f27225bc324676842abf7638d0a9d5790161d489`. All 15,150,646 bytes are accepted, sequence end and presentation completion are reached, and aggregate and framebuffer integrity error counters remain zero. The source's 449 pictures and the wrapped display counts plus 448 publications support 448 swaps over 15.053786 seconds, averaging 29.759956 pictures per second. Three doubled gaps contribute 100.100 milliseconds of excess duration, with another 5.419 milliseconds attributable to the initial reference-completion versus later-swap timestamp basis. The reset count is 449, not 448: generation reset includes native mode changes as well as swaps, so never substitute that counter as the swap count; one extra native-entry reset is consistent with the cold start but was not individually traced. Repeated loads and Bob/Weave switching are therefore not necessary to trigger the recurring gap. Entry 555's ordinal ambiguity can also be narrowed using the existing bank metadata: under ordered all-I presentation from bank zero, the previous display bank is the upcoming picture ordinal minus two modulo three. The stored display banks uniquely select pictures six, seven and 348 from their eight-bit ordinals six, seven and 92; the warm run similarly selects six and 348. This is a source-invariant inference, not a newly captured per-picture hardware trace. The FIFO-pending flag observes the upstream HPS FIFO, not the separate sixteen-kibibyte clean-video queue, so an empty flag alone does not prove decoder starvation. A temporary integrated observer on GUNSMOKE now executes the unchanged production frontend, three-bank publication shell, I reconstruction, two-bank DDR writer and native scheduler together, checking exact sample counts, all error flags, picture identity order and final store totals. With always-available decoder input, always-ready DDR writes and exact field/frame pulses, all 449 pictures and 29,095,200 accepted DDR words pass in 446.85 seconds. Only picture six has a doubled interval; picture 348 completes 1,003,299 clocks, or 16.722 milliseconds, before its presentation window. The expanded simulation thus reproduces the early decode overrun but neither the additional cold picture-seven gap nor the recurring hardware picture-348 gap. Physical host transfer, extraction/clean-queue availability, DDR arbitration/read contention and full raster behavior remain outside this simulation. An optimized observer agrees with ninety-three events from the initial slower observer before that superseded run was stopped; the stopped run is not reported as a pass. Capture analysis, simulation results and diagnostic hashes are preserved in the two entry-556 JSON files, with observer sources and full CSV logs under `/home/vash/mister-builds/entry556-cadence-analysis`. No production RTL, settings, constraints or active image changed, and the accepted HDMI flicker correction remains intact.

#### Next Steps:

Request approval for one passive cadence-telemetry build that records the full picture ordinal and readiness at the actual missed swap window, including decoder-side clean-queue availability, writer capacity and candidate publication timing, instead of relying on a later threshold snapshot or the upstream FIFO alone. Keep the accepted HDMI sync behavior and scheduler ownership unchanged, qualify the telemetry decoder and event capture in simulation, and require a successful build with positive timing before the already-authorized direct image replacement and independent readback. First repeat this clean Bob case; retain repeated loads and Bob/Weave switching as subsequent regression conditions rather than assuming they caused the cold-run gap. Do not claim that all remaining delay is explained or apply a playback-clock adjustment from these results.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 555 COMMIT Unreleased 30d300a 2026-08-26T21:17:18-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Identify the remaining native playback cadence shortfall without changing the hardware-validated HDMI path.

#### Outcome:

The user requested a cadence investigation and clarified that entry 554's terminal capture followed repeated file loads and Bob/Weave changes, not a reboot and single launch; treat it as a warm session. The 448 measured intervals exceed their ideal duration by 4,260,958 decoder cycles, or 71.016 milliseconds: two doubled frame gaps account for 66.733 milliseconds and the first-reference-completion to later-swap timing basis accounts for the remaining 4.283 milliseconds. This is not evidence of a continuously slow raster clock. An unchanged-scheduler control with the existing ideal I feeder passes one thousand consecutive frame windows with no denial or gap at both four- and five-clock field-to-frame-window delays. A temporary observer generated from the existing interlaced-I reconstruction bench then processes the exact 449-picture clip through the production I parser, inverse quantizer, IDCT and reconstruction, checking 518,400 samples per picture and every pipeline error. It completes 866,735,142 simulated cycles in 226 seconds on GUNSMOKE. This excludes host transport, physical DDR persistence and presentation, so its timings are optimistic decode bounds, not a complete hardware reproduction. Thirty-three pictures individually exceed the 2,002,000-clock frame budget; average reconstruction is 32.172 milliseconds, picture six needs 48.587 milliseconds, and picture 348 needs 44.632 milliseconds. Across all pictures the measured cost fits 1,626,640 fixed clocks plus 9.00008 clocks per source byte with less than ninety-five clocks of residual error, matching the current bitreader's eight serial bit-consume cycles followed by a byte-refill bubble. Most overruns can be absorbed by buffering. Replaying these measured costs, compressed one thousand to one, through the actual scheduler with three ordinary banks reproduces the picture-six doubled interval near the captured raster phase, while different initial phases absorb it behind a longer initial interval. The second hardware gap is not reproduced: its stored eight-bit ordinal 92 could mean picture 92 or 348, and the expensive 347-through-349 group is a candidate rather than proof because the optimistic replay still absorbs it. No inference about mode switching or reload state has been accepted as a cause. A single Bob replay without menu or mode changes during playback, without reboot, has been requested to isolate that remaining difference. `.ai/current_results/entry555_cadence_analysis.json` retains the measurements, bounds and diagnostic hashes; the generated observer sources, complete per-picture CSV and control logs are preserved on GUNSMOKE under `/home/vash/mister-builds/entry555-cadence-analysis`. No production source, constraints, settings or active RBF changed, and entry 554's flicker acceptance remains valid; this cadence investigation is not yet closed.

#### Next Steps:

Capture the requested untouched Bob replay after the user reports completion, deleting the old screenshot target first, and compare its gap count, intervals and wrapped ordinals with the warm-session capture. If the second gap persists, extend the existing reproduction with the missing persistence or transport timing before changing scheduler ownership; if it appears only with interaction, exercise repeated loads and Bob/Weave switching as the user requested. Preserve `30d300a` and continuous raster sync. Treat parsing/transform throughput and startup buffering as candidate improvement boundaries only after the remaining gap is explained; neither a faster clock nor a new HDMI sync change is justified by this evidence.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 554 COMMIT Unreleased 30d300a 2026-08-26T21:03:11-07:00

#### Coming From:

Unreleased 30d300a

#### Purpose:

Record hardware acceptance of the framebuffer sync correction in both HDMI deinterlacing modes.

#### Outcome:

After reloading the deployed `30d300a` image, the user reports no flicker and smooth playback in both Bob and Weave, confirming the bounded hardware objective of entry 552. The user's initial impression of faster playback was explicitly withdrawn, so no speed correction or further speed investigation is requested. A fresh screenshot of the most recent Bob terminal state was obtained after deleting only the previous fixed screenshot target; `.ai/current_results/entry554_bob_terminal.png` is 476,506 bytes with SHA-256 `de017a4bd453bb6569beafe656509e42893eb3c38d10d545462dbc592af903fb`. Schema eighteen accepts all 15,150,646 bytes of the established Big Buck Bunny clip, reaches sequence end and presentation completion, freezes normally for quiet, and reports zero aggregate, presentation, cache-overlap, prefill, unpublished-reset, region, phase, tag, content or write-read mismatch errors. Both field fingerprints match their accepted-write expectations. Independent probing of the exact MiSTer file on GUNSMOKE verifies the known source checksum, 449 decoded pictures, frame-rate code four in all 449 sequence headers and zero rate-extension numerator and denominator fields, confirming 30000/1001 through H262-027. The eight-bit display counts wrap to 193 pictures and 192 swaps; corroborating sixteen-bit reset and publication counters are both 448. The resulting 448 intervals span 901,156,958 decoder cycles, or 15.019283 seconds at sixty megahertz, averaging 29.828322 pictures per second with two 66.733-millisecond gap outliers. The generic telemetry decoder's uncorrected delivered-fps field uses the wrapped counter and must not be taken literally for this run. Full telemetry, source-probe evidence and count interpretation are retained in `.ai/current_results/entry554_hardware_acceptance.json`. No RTL, settings, active image or playback state was changed during this inspection. Hardware acceptance here covers the observed flicker and smooth Bob/Weave playback, not every remaining media-player feature or the unrelated live-raster assertion drift.

#### Next Steps:

Keep `30d300a` as the hardware-validated baseline for the HDMI flicker correction and preserve its qualified build artifact and independent deployment checksum. Await the user's next requested development objective rather than changing cadence in response to the withdrawn speed impression. Future image replacements during approved development remain authorized under entry 553, with timing qualification and independent readback retained.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
