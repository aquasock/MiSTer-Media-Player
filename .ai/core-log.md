## 461 COMMIT Unreleased fccb003 2026-08-24T09:31:39-07:00

#### Coming From:

Unreleased 14e0629

#### Purpose:

Revert the startup byte budget after the soak cleared the drift risk and returned an underrun at 62 seconds.

#### Outcome:

The user played `20_bbb_full_48k.mpg` end to end on the `14e0629` helper and reports audio and video perfectly in sync throughout, confirmed by watching the credits, with a small once-per-second cadence still visible and ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. That answers the question the soak was run for: coalescing timestamps to one per encoded group does not cost alignment over ten minutes, so extrapolation across a group is sound and `14e0629` stands on its drift risk. The capture is 8,108 bytes at SHA-256 `52a27c69794e4b1177f8377e1923b249943d6326eaef2a65919777fcf8817ba9`, small because the final raster is black, and it shows the profiler frozen rather than quiet: the snapshot reason is fatal or no progress and the sole aggregate flag is `0x0400`, a real `audio_pcm_underrun`, with PCM protocol, presentation and destination errors all clear. It froze at 35,705,169 accepted transport bytes of 342,083,863, which is 62.2 seconds into the movie, and had already counted 132 gap outliers by then.

The underrun is therefore not fixed on long content, only moved. Entry 451 measured it at 21.74 seconds under `f2b2e02`; it now arrives at 62.2 seconds under a helper whose host analysis reports an audio deficit of zero across the entire movie. That contradiction is informative rather than a measurement error, because the host model asks whether audio crosses ahead of the video timeline and cannot see the other direction of the same coupling: when the compressed video FIFO is full, video bytes block the shared path and the PCM records queued behind them wait, so the sink can starve while the producer is comfortably ahead of schedule. The 24-second diagnostic never reaches that state and shows no underrun; the movie does, twice, at different points under two different helpers.

That makes the startup byte budget from entry 455 a suspect rather than a neutral change. It exists to keep the compressed FIFO as full as possible, which is precisely the condition under which video blocks PCM, and entry 456 already measured that it bought no cadence improvement at all: outliers moved from 174 to 170 and presentation hold from 7,967,197 to 12,376,681 cycles, less than two percent of the distance to the raw control. It is a change that has not paid for itself and that plausibly makes the audio side worse. The cadence residue is unchanged in shape, with the largest gaps still 431.059 milliseconds at display ordinal fourteen and 82.896 at ordinals fifteen and seventeen, the same signature seen under every audio-video helper so far.

The revert was approved and is commit `fccb003`, which removes `PCM_STARTUP_VIDEO_BYTES` and ends the lead on the second picture again while leaving the delivery-order bounds from `cf1d173` and the timestamp coalescing from `14e0629` untouched. The startup lead returns to 5,301 bytes on the diagnostic and 20,564 on both controls, and each of those is exactly four bytes past that stream's second picture start code, which sits at 5,297 and 20,560 respectively. That corrects entry 455, which reported the controls' lead rising from 1,280 bytes: 1,280 was their initial PCM batch, not their lead, and their lead under the two-picture boundary has always been 20,564. The diagnostic figure of 5,301 in that entry was right.

Everything else is unchanged, which is the point of a revert. Removing PCM from the new helper's transport still yields exactly `25_bbb_opening24_gop_pts.m2v` at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0`, the 26-record layout hardware presented with zero outliers, so the lead never touched record placement. The soak keeps 598 timestamps, 84,423,309 clean video bytes, 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, video and timestamps at SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81`, a 342,083,863-byte transport, steady batches within 2,048, PCM-free spans within 4,052 bytes and an audio deficit of zero. All fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope retains three passes and six intended failures with identical statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `dbcbd74a84cb7cb57583c5ac0d4dfb0b5e695148c350551295bb4f4b299338cb`. Only the helper was installed, with `14e0629` preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-lead-revert.14e0629`; no RBF, Main or media file changed.

#### Next Steps:

Run `20_bbb_full_48k.mpg` end to end and report where the underrun lands, which is the only question this commit asks. The comparison is the 62.2-second freeze under `14e0629` and the 21.74-second freeze under `f2b2e02`; a later freeze or a clean quiet snapshot confirms that keeping the compressed FIFO full starves the audio sink through the shared path, while an underrun at the same point exonerates the lead, which stays reverted either way because it was never measured to help. Report audio and video alignment through the credits again, any crackle or dropout, the visible cadence and all three LEDs, then leave the final image loaded for a schema-eight capture. Whatever the result, the dominant cadence mechanism is unchanged and FPGA-side, ordered by the evidence in entry 461: carrying many samples per PCM record, which cuts record count and path bandwidth together and is the only candidate that addresses cadence and underrun at once; buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so a full video FIFO cannot block audio; and deepening `audio_pcm_fifo`, which raises the starvation threshold without changing the coupling that causes it.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
## 460 COMMIT Unreleased 14e0629 2026-08-24T09:14:42-07:00

#### Coming From:

Unreleased 14e0629

#### Purpose:

Record that timestamp coalescing removed the per-second beat and most of the audio-video cadence defect, and hold the result until the ten-minute soak proves alignment.

#### Outcome:

The user ran `23_bbb_opening24_exact_av.mpg` on the `14e0629` helper and reports it running correctly with the beat gone, reserving judgement until the credits are seen, with all LEDs normal. The capture is 545,909 bytes at SHA-256 `840f9b69781815cea1ee38006d0f7346d97d9403c42389e7d2897c2e2b24fd9e`, and it carries the largest single improvement this investigation has produced. Gap outliers fall from 170 to 13 over 24 seconds, presentation hold rises from 12,376,681 to 266,426,934 cycles, presentation stall from 11,794,180 to 262,253,206 and `hold_scratch_available_cycles` from 582,616 to 2,984,466, which is within four cycles of the smooth raw control's 2,984,470. Correctness is unchanged and complete: zero aggregate error flags, no underrun, no PCM protocol error, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. Accepted transport bytes are 3,138,618, exactly the video's own length, so the spurious byte that both 551-record streams accepted is gone with the records that caused it.

The improvement is larger than this cycle predicted and the prediction was wrong in an informative way. Entry 459 measured 21 outliers attributable to 551 records on a stream with no PCM and expected the audio-video file to fall from 170 to about 149. It fell to 13. A record therefore does not cost a fixed amount: on a path already saturated by real-time PCM gating each timestamp costs far more than it does on an idle one, so the two mechanisms compound rather than add. That also revises the accounting recorded in entry 457, where 149 of the 170 outliers were attributed to gating alone; the honest split is that gating remains the enabling condition, since presentation hold is still 266,426,934 against the raw control's 781,845,922, but record density was the larger lever on this content.

Thirteen outliers remain and their shape is unchanged. The largest is 431.059 milliseconds at display ordinal fourteen with the decoder ready, input pending, scratch available and the scheduler reporting presentation complete, the same ordinal and the same signature as the worst gap under `9f83805`. The second and third are 82.896 milliseconds at ordinals fifteen and seventeen, one with both a reorder run and a decode in flight and no scratch available, one with the decoder not ready. Presentation slack at a third of the raw control's is consistent with a path still paced by the audio sink.

#### Next Steps:

Run `20_bbb_full_48k.mpg` end to end before this commit is called good. Cadence is not what the soak is for: sparse timestamps mean presentation extrapolates across a whole encoded group rather than a packet, so the question is whether audio and video are still aligned through the credits and at the final plate, and drift is what would send `14e0629` back to `MediaPlayer_Helper.backup.pre-timestamp-coalesce.9f83805`. Report alignment at the opening, at the high-motion sequence near 7:22, through the credits and at the closing sting, plus any crackle, dropout or visible corruption and all three LEDs, then leave the final image loaded for a schema-eight capture requiring zero aggregate, decoder, presentation, destination, underrun and PCM protocol errors with all 14,315 pictures accounted for after eight-bit wrap. If alignment holds, the remaining cadence work is the dominant mechanism and it is FPGA-side, with three candidates to cost against resource and timing numbers: deepening `audio_pcm_fifo` past any lead the helper can produce, buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, and carrying many samples per PCM record, which after this result is the most attractive of the three because it reduces record count and path bandwidth at the same time.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 459 COMMIT Unreleased 14e0629 2026-08-24T09:10:04-07:00

#### Coming From:

Unreleased 1a6e6b4

#### Purpose:

Coalesce the helper's timestamp records to the density hardware has already run cleanly, after record placement was ruled out and record count was not.

#### Outcome:

The user ran `26_bbb_opening24_pts_noprefix.m2v` and reports a stutter about once a second, resembling the cadence beat seen in earlier 24 and 25 frame-per-second work, with LEDs unchanged at USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,908 bytes at SHA-256 `e50bd5345423e36abec4895d9be9d5ca8e83a08e3a657996afa72e9cc5c11eaa`, and it reproduces the 551-record control rather than improving on it: 21 gap outliers again, the same three largest gaps of 116.054 milliseconds at display ordinal 65, 82.896 at ordinal 196 and 66.317 at ordinal 28, the same 3,138,619 accepted bytes and a bit-identical `hold_scratch_available_cycles` of 6,963,478. Forty-four decoded fields match exactly and the sixteen that differ do so in the fourth significant figure or below. Moving every record off a start-code prefix changed nothing.

That refutes the adjacency reading recorded in entry 458, and the accepted-byte evidence with it: this control has no record on a prefix, presents 577 picture start codes to a pre-extraction scan and still accepts 3,138,619 bytes, so the spurious byte tracks record count rather than record placement and is not the mechanism it looked like. What survives is simpler and is now measured three times over. Zero records give zero outliers, 26 records give zero outliers, and 551 records give 21 outliers whether or not any of them sits on a prefix. The residual cost is per record, at roughly one late presentation for every 26 records carried, and at 551 records over 24 seconds that lands close enough to one per second to be exactly the beat the user describes. Presentation slack is not involved: presentation hold is 783,657,982 cycles against the raw control's 781,845,922, so the decoder has its full reservoir and still misses these deadlines.

The helper's own record density is therefore a defect rather than a fixed cost. It emits one timestamp per video PES packet carrying a timestamp, which is 551 records for 24 seconds of this mux, while the FPGA presented the same 577 pictures perfectly from 26 timestamps and associated 24 of them. Nothing in presentation needed the other 525.

Commit `14e0629` was approved and implements it. A timestamp is written when a sequence or group start code has passed since the last one, or after `PTS_MAX_PICTURE_GAP` pictures so a stream carrying neither boundary still receives one periodically; presentation reconstructs display order from each picture's own temporal reference in between. The timeline itself is untouched, because a chunk still carries its timestamp for the audio horizon whether or not a record is written for it, and both the scheduled and explicit output paths gate identically so the transport contract does not depend on which one produced it. Record counts fall from 551 to 26 on the diagnostic, from 48 to six on both controls, from one to one on the short and faded fixtures and from 13,401 to 598 on the full soak, which is one per encoded group rather than one per timestamped packet.

The strongest host proof is an equality rather than a bound. Removing PCM from the new helper's transport for the diagnostic yields exactly `25_bbb_opening24_gop_pts.m2v` at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0`, the 26-record control that hardware has already presented with zero gap outliers and the same three largest display gaps as unannotated video. The helper now produces that record layout by construction rather than by filtering. Everything else holds: clean video is unchanged at 84,423,309 bytes for the soak and reduces to SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a` on the diagnostic, PCM remains 28,628,352 frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, the startup lead stays at 28,654 bytes, steady batches within 2,048, PCM-free spans within 4,052 bytes and the audio deficit at zero. The soak transport shrinks from 342,199,090 to 342,083,863 bytes, exactly the 12,803 records no longer written, and its video and timestamp stream is now SHA-256 `545075cdc22437cb994efde832e8f09c663ac569bf8e98d406025ef480d2cd81`, which supersedes the long-established `db00682b` figure for that quantity while the video underneath it is unchanged. All fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope retains three passes and six intended failures with identical statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `3a46ee0cba082e970948078c9f6675aca47c2cbe6b02262b90daca653e0a5333`. Only the helper was installed, with `9f83805` preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-timestamp-coalesce.9f83805`; no RBF, Main or media file changed.

#### Next Steps:

Power-cycle, set Audio Test to Off and run `23_bbb_opening24_exact_av.mpg`, the audio-video diagnostic rather than a control, since the helper now produces the proven record layout itself. Require the once-per-second beat to be gone and report what remains, plus all three LEDs, leaving the final image loaded for a schema-eight capture; the expectation is the outlier count falling from 170 by the 21 that record density accounted for, with presentation hold still collapsed near 12,376,681 cycles because PCM gating is untouched. Then run `20_bbb_full_48k.mpg` end to end, because sparse timestamps mean presentation extrapolates for longer and only ten minutes can show whether audio and video are still aligned at the end; drift there, not cadence, is what would send this change back. After that the remaining work is the dominant mechanism and it is FPGA-side, with three candidates to cost against resources and timing: deepening `audio_pcm_fifo` past any lead the helper can produce, buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, and carrying many samples per PCM record, which would cut audio path bandwidth and the per-record cost this cycle measured at the price of a transport format change on both sides.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
## 458 COMMIT Unreleased 1a6e6b4 2026-08-24T08:59:05-07:00

#### Coming From:

Unreleased 2054426

#### Purpose:

Record that the residual cadence cost tracks timestamp record placement rather than presentation, and build the control that separates the record from where it lands.

#### Outcome:

The user ran `25_bbb_opening24_gop_pts.m2v` and reports the stutter gone, with ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,920 bytes at SHA-256 `4cf3439106759505629e761981abfcc7ccdc05e3648df08586bb6ced939e3949` and the run is indistinguishable from the unannotated control: zero aggregate error flags, all 577 pictures displayed with 576 swaps, sequence end, presentation complete, normal quiet reason one, zero gap outliers, and the same three largest display gaps of 49,738 microseconds at display ordinals three, four and six that the raw control produced. Presentation hold is 778,283,682 cycles against the raw control's 781,845,922, and decoder stall 655,665,458 against 655,685,975. Twenty-six timestamps cost nothing measurable; 551 cost 21 outliers and a 116.054-millisecond worst gap. The residue therefore scales with record placement and is not a property of timestamp-driven presentation, because this control is timestamp-driven, associates 24 timestamps and still presents exactly as the unannotated video does.

One counter separates the two candidate mechanisms more sharply than the outlier count does. Accepted transport bytes are 3,138,618 for the raw control and 3,138,618 for this one, both exactly the video's own length after extraction, but 3,138,619 for the 551-record control and for the audio-video file, which is one byte more than the video contains. The two streams that accept a spurious byte are precisely the two that carry a record immediately after video ending in `00 00 01`, and the two that accept the exact count are the two with no such adjacency. That is direct evidence that record extraction mishandles a record placed on a start-code prefix, injecting a byte into the elementary stream the decoder then has to absorb, rather than evidence that records cost pipeline time in proportion to their number.

Commit `1a6e6b4` builds the control that decides between those two readings. `strip_inband_pcm.py` can now defer a record by one video byte when it would otherwise land on a start-code prefix, which preserves the record count at 551, the offsets of every other record, all 577 pictures and the exact video at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. The generated `26_bbb_opening24_pts_noprefix.m2v` is 3,143,577 bytes at SHA-256 `d94e9780fdb86680edd484ed5f1e68381abdd7ee18a24e8c3e9195c779a49cf0`, the same length as the dense control, and a scan before extraction now finds exactly 577 picture start codes rather than 579. The helper passes it through byte-identically under native and sanitized builds, and regenerating both earlier controls after the change reproduces the installed files exactly. Only that file was installed, by the same staged roundtrip, with the `9f83805` helper confirmed still resident and no RBF, Main or other media file touched.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `26_bbb_opening24_pts_noprefix.m2v`, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. It carries the same 551 records as the control that produced 21 outliers, differing only in that none of them sits on a start-code prefix. A clean run with 3,138,618 accepted bytes proves the residue is the adjacency and makes the correction a helper-side one, never placing a record where the preceding bytes end in `00 00 01`, which also removes 66 such adjacencies from the audio-video transport and must then be retested there. A run that still produces about 21 outliers proves the cost is per-record and independent of placement, which leaves the spurious byte as a second and separate defect in extraction. Either result leaves the dominant mechanism untouched and architectural: with PCM present the shared byte path is paced by the audio sink, presentation hold collapses from roughly 780,000,000 cycles to 12,376,681, and correcting that means deepening `audio_pcm_fifo` past any lead the helper can produce or buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate`, both Quartus work to be chosen on resource and timing numbers.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 457 COMMIT Unreleased 2054426 2026-08-24T08:53:01-07:00

#### Coming From:

Unreleased 386d3c1

#### Purpose:

Measure the residual record-carrying cadence cost against record density, after the timestamp-only control isolated PCM gating as the dominant mechanism.

#### Outcome:

The user ran `24_bbb_opening24_pts_only.m2v` and reports the stutter mostly gone but still present, and still worse than the audio-free control played in the past, with ordinary terminal indication of USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,928 bytes at SHA-256 `46e4a18ef82db01fb8d275389deda76664df91ee94b8881de1fa53b8d011d15a`, with zero aggregate error flags, all 3,138,619 bytes accepted, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. The control answers the question it was built for, and the split is lopsided. Presentation hold returns to 783,626,293 cycles against the raw control's 781,845,922 and the audio-video file's 12,376,681, and presentation stall to 775,473,833 against 777,671,229 and 11,794,180. Decoder stall is 655,681,763 against the raw control's 655,685,975, a difference of four thousand cycles in six hundred and fifty million. Removing PCM from a stream that keeps the same video bytes, the same 551 timestamps at the same offsets and the same record extraction restores the decoder's slack completely.

The outlier count falls from 170 to 21 while the raw control's is zero, so the two mechanisms are now separated and measured. Real-time PCM sink gating destroys the decoder's reservoir and accounts for roughly 149 of the 170 outliers: with PCM present the shared path advances only as fast as the 48 kHz sink drains, the decoder can never run ahead, and every picture whose decode overruns its frame interval is late. That is why bounding delivery order and filling the compressed FIFO both failed to help; neither can create slack on a path that is paced by an audio sink, and the helper has no way to reach it. The remaining 21 outliers belong to the records themselves, because this control has full slack and still misses deadlines the identical unannotated video never missed. Its largest gaps are 116.054 milliseconds at display ordinal 65 with no compressed input pending and the scheduler reporting a released pending frame, 82.896 milliseconds at ordinal 196 with both scratch banks pending during a closed reorder run, and 66.317 milliseconds at ordinal 28 with the decoder not ready. `hold_scratch_available_cycles` also rises to 6,963,478 against the raw control's 2,984,470, so the scratch pool is being held longer when records are present even though nothing is starved.

The transport-level adjacency recorded in entry 456 is now a candidate mechanism for that residue rather than a curiosity. This control carries 551 timestamp records and two picture start codes that its video does not contain, and it produces 21 outliers; the audio-video transports carry the same timestamps plus more than a million PCM records, present 59 and 66 such adjacencies before extraction, and produce 139 and 170. The correlation is suggestive but not proof, because record count, adjacency count and PCM gating all rise together and only gating has been isolated so far.

The density control was approved and built. Commit `2054426` teaches `strip_inband_pcm.py` to keep only the first timestamp of each group, which changes record count without touching a single video byte: `25_bbb_opening24_gop_pts.m2v` is 3,138,852 bytes at SHA-256 `83930a92f9796b5c47a7719d4b635243eb84f8226c7f937465e31a68e13365f0` and carries 26 timestamps against the 551 of `24_bbb_opening24_pts_only.m2v`. Removing its timestamps reduces it to the same accepted video at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`, the helper passes it through byte-identically under native and sanitized builds, and regenerating the dense control after the change reproduces the installed file exactly, so the tool's existing behaviour is unchanged. Only that file was installed, by the same staged roundtrip, with the `9f83805` helper confirmed still resident; no RBF, Main or other media file was touched.

One confound has to be stated rather than discovered later. The sparse control carries 577 picture start codes before extraction, exactly what its video contains, because both of the entry 456 adjacencies happened to belong to dropped records. It therefore varies record count and adjacency count together, from 551 and two to 26 and zero. A fall in outliers is consistent with either a per-record cost or the adjacency, and separating those two would need a third control that keeps 551 records while avoiding the adjacency; no change in outliers rules out both and leaves the presentation timeline itself, which is the more valuable answer and the reason to run this control first.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `25_bbb_opening24_gop_pts.m2v`, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. The measurement is the outlier count against 21 for 551 records, zero for no records and 170 for the audio-video file, with presentation hold expected to stay near the raw control's 781,845,922 cycles because this control has no PCM and therefore no gating. An outlier count falling roughly with record count makes the residue a per-record cost in extraction or the decoder pipeline, and the follow-up is a 551-record control built to avoid the two adjacencies, which separates the record from where it lands. An unchanged count of about 21 makes the residue a property of timestamp-driven presentation, and the follow-up is FPGA-side at the `pending_frame_released` state seen at ordinal 65 and the both-banks-pending reorder state at ordinal 196. Either way the dominant mechanism is unchanged and still architectural: the shared byte path is paced by the audio sink whenever PCM is present, and correcting it means either deepening `audio_pcm_fifo` beyond any lead the helper can produce or buffering a stalled PCM record aside in `mpeg2_h262_stream_transport_gate` so compressed video keeps flowing, both of which are Quartus work to be chosen on resource and timing numbers.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 456 COMMIT Unreleased 386d3c1 2026-08-24T08:41:14-07:00

#### Coming From:

Unreleased 9f83805

#### Purpose:

Separate in-band records from real-time PCM gating with a timestamp-only control derived from the helper's own transport, before any FPGA work begins.

#### Outcome:

The user reran `23_bbb_opening24_exact_av.mpg` on the `9f83805` helper and reports audio synchronization still good, the stutter slightly worse, and ordinary terminal indication with USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,938 bytes at SHA-256 `99b09546a25c7c104bd5e0c304b68170487620f8d403140392dd4bdf6e065ba4`. Correctness is unchanged and complete: zero aggregate error flags, no underrun, no PCM protocol error, all 3,138,619 bytes accepted, all 577 pictures displayed with 576 swaps, sequence end, presentation complete and normal quiet reason one. The startup budget did what it was measured to do on the host and did not do what it was predicted to do on hardware. First presentation returns to 2,275,519 cycles against the raw control's 2,275,460, so the fuller lead costs nothing at startup and the user confirms synchronization is unaffected, which settles the one risk that bounded the budget. But the outlier count falls only from 174 to 170, the largest gap grows from 182.371 to 431.059 milliseconds, and the session lengthens from 24.044 to 24.369 seconds.

Presentation hold rises from 7,967,197 to 12,376,681 cycles, a 55 percent improvement on a quantity that must reach roughly 781,845,922 to match the smooth raw control. Tripling the compressed-FIFO lead moved the deficit by less than two percent of the distance, so the missing slack is not the lead and cannot be bought with more of it. Decode work remains identical across all three runs, with decoder stall at 655,685,975 raw, 644,013,299 on `cf1d173` and 643,974,167 now, and intra, predicted and bidirectional stalls matching to within three percent throughout. The hypothesis recorded in entry 455 is therefore refuted by its own acceptance test, and delivery ordering is exonerated as the cause of the cadence: two independent transport corrections, one bounding delivery order and one filling the sink FIFO, both leave the outlier count essentially where it was while decode work never changes.

The remaining evidence points inside the FPGA. The two largest reordered gaps at picture ordinals fifteen and 33 repeat their `cf1d173` signature exactly, at 198.950 milliseconds each with `decoder_ready` true, compressed input pending, `scratch_available` false, a reorder run active, a decode in flight and a future frame pending, which is scratch exhaustion during reorder rather than any shortage of bytes. The new largest gap at ordinal fourteen has the opposite signature, 431.059 milliseconds with scratch available, the decoder ready and the scheduler reporting presentation complete, so it is a scheduler state question rather than a resource one. `hold_scratch_available_cycles` also falls from 3,397,412 to 582,616 while the lead grew, which is consistent with the scratch pool, not the byte path, being what the audio-video case runs out of.

That control was approved and is built by `strip_inband_pcm.py` in commit `386d3c1`, which removes only the PCM records from the helper's own output rather than rebuilding the stream, so the timestamps land at exactly the elementary-stream offsets hardware saw. The generated `24_bbb_opening24_pts_only.m2v` is 3,143,577 bytes at SHA-256 `2a58632d3efbb4581d1cf3434d3dbe1d39f4f1ee2f4561cfdc2f47b7d0c13d39`, matching the video and timestamp byte count the analyzer measured for the audio-video transport, and carries all 551 timestamp records with 1,154,304 PCM records removed. Removing the timestamps as well reduces it to the accepted raw control at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`, so the video is provably the same 577 pictures that already played smoothly. The helper passes the file through byte-identically under both native and sanitized builds, since an elementary stream takes no scheduling. Only that file was installed, by the same staged roundtrip; the `9f83805` helper was confirmed still resident and unchanged, and no RBF, Main or existing media file was touched.

Validating the control surfaced a transport property worth recording on its own. The compatibility checker reads the annotated file as 579 pictures with two of them missing a coding extension, against 577 in the unannotated control, and the two extra picture start codes sit exactly where a record follows video whose last three bytes are `00 00 01`: the record's own leading zero completes a picture start code that the video did not contain. The same adjacency exists in the shipped audio-video transports, where a scan taken before record extraction sees 636 picture start codes under `f2b2e02` and 643 under `9f83805` rather than 577, because PCM records are inserted at far more points than timestamps are. Stripping records restores the exact video in every case, so a byte-serial extractor that strips before parsing is unaffected, and the hardware displayed exactly 577 pictures in both audio-video runs, which argues that picture counting happens after extraction. It nonetheless means the record insertion point is not neutral to a parser reading the stream ahead of extraction, and that the count of such adjacencies rose with each of the two transport corrections while the outlier count did not fall. Whether that is coincidence or mechanism is precisely what the installed control now separates.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `24_bbb_opening24_pts_only.m2v`, which has no audio by construction, then report visible stutter and all three LEDs and leave the final image loaded for a schema-eight capture. The comparison is against the raw control's zero outliers and 781,845,922 cycles of presentation hold, and against the 170 outliers and 12,376,681 cycles measured on the audio-video file whose video bytes and timestamps this control reproduces exactly. A smooth run places the defect in PCM sink gating and its interaction with the reorder and scratch logic, and the next work is FPGA-side. A stuttering run places it in timestamp-driven presentation or in record extraction itself, reproducible with no audio at all, and the immediate follow-up is then a second control with the timestamps removed to separate the records from the presentation timeline they carry. Either way, do not change the helper again until this control has answered, because two transport corrections have now been spent on a mechanism that has not been isolated.

#### Files Modified:

- tools/streams/strip_inband_pcm.py

#### Status:

- [x] Built
- [ ] Passed

---
## 455 COMMIT Unreleased 9f83805 2026-08-24T08:26:32-07:00

#### Coming From:

Unreleased f870d98

#### Purpose:

Give the decoder its compressed-FIFO reservoir back by ending the startup video lead on a byte budget, after paired captures showed the stutter is lost presentation slack rather than delivery.

#### Outcome:

The user ran `23_bbb_opening24_exact_av.mpg` on the `cf1d173` helper and reports the stutter still present, audio and video still aligned, and ordinary terminal indication with USER solid on, DISK blinking eleven times and POWER solid on. The capture is 545,898 bytes at SHA-256 `1e4aa14922109364934c65cddcc80030f03c27ec56fc2f31fa1ca207fe44cb4d`, taken over FTP because this workstation's SSH client can no longer authenticate to the MiSTer; the screenshot command was written to `/dev/MiSTer_cmd` through the FTP data path instead, which is a working substitute for the documented capture route. Half the acceptance criteria are met. Aggregate error flags are zero, `audio_pcm_underrun` and `pcm_protocol_error` are both false, all 3,138,619 transport bytes are accepted, 194 reference plus 383 B pictures decode, all 577 pictures display with 576 swaps after eight-bit wrap, sequence end is seen, presentation completes and the snapshot is the normal quiet reason one with the PCM count and FIFO peak saturated. The sticky underrun that entry 451 measured at 21.74 seconds is gone from a file that reproduces its exact opening bytes with audio.

The cadence is not fixed and is worse in peak terms: 174 display gaps cross the outlier threshold in 24.044 seconds, against 139 in the first 21.74 seconds of the full soak, and the three largest are 10,942,272 cycles or 182.371 milliseconds at picture ordinal fifteen, 9,947,520 cycles or 165.792 milliseconds at ordinal 33, and 6,963,264 cycles or 116.054 milliseconds at ordinal five. Their signature has changed from entry 451, where the largest gaps recorded `decoder_ready` false with compressed input pending. Every large gap here records `decoder_ready` true with input pending, and the two largest add `scratch_available` false with a reorder run in flight, a decode in flight and a future frame pending. The decoder is neither starved of bytes nor unable to accept them.

Retrieving the entry 453 raw capture from the MiSTer and decoding it beside this one settles the mechanism, because both runs present the same 577 pictures from byte-identical H.262 through the same FPGA image. Decode work is the same to within three percent: decoder stall 655,685,975 cycles raw against 644,013,299 with audio, intra stall 61,907,556 against 61,920,490, predicted stall 197,169,953 against 195,855,651, bidirectional stall 396,608,466 against 386,237,158, and prediction requests identical at 59,531,848. One pair of counters differs by two orders of magnitude: presentation hold falls from 781,845,922 cycles, 13.03 seconds or 54 percent of the raw session, to 7,967,197 cycles or 0.13 seconds, and presentation stall falls from 777,671,229 to 4,569,905. The raw run spends half its time waiting to present because the decoder is far ahead; the audio-video run never waits because the decoder is never ahead. Both deliver 577 pictures in about 24 seconds, so average throughput is identical and only the slack differs.

That slack is the compressed video FIFO's fill, and it is set at startup rather than in steady state. `rtl/mpeg2_stream_fifo.sv` holds 32 KiB, about 0.25 seconds at this stream's 130,776 bytes per second. Without audio the helper writes video as fast as the FPGA accepts it, so that FIFO sits full and absorbs every picture whose decode exceeds one 41.667-millisecond frame interval; the raw run's largest gap is 49.738 milliseconds and it never crosses the threshold. With audio sharing the path, the accepted two-picture startup boundary releases audio after only 5,301 video bytes, so the FIFO stabilises near sixteen percent full and the shared path then runs at real time, leaving no reservoir for decode-time variance. Steady-state interleaving cannot recover a lead it never established, which is why bounding delivery order corrected the audio without touching the cadence.

Commit `9f83805` was approved and implements exactly that. The lead now ends only when the second picture start has been seen and 28,672 video bytes have crossed, so a payload smaller than the budget keeps its existing boundary and real content gets the reservoir. Measured on the transports, the startup video lead rises from 5,301 to 28,609 clean bytes on the diagnostic and from 1,280 to 28,654 on both controls, while the short and faded fixtures are unchanged at 179,893 because their intra picture is larger than the budget and their second picture start still ends the lead. The full soak reproduces every established payload figure exactly: 342,199,090 transport bytes, video and timestamps at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f`, PCM at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, steady batches within 2,048 and PCM-free video spans within 4,052 bytes. The audio margin improved rather than regressed: the deepest audio deficit over the whole movie falls from 7,374 frames to zero, because the lead leaves audio permanently further ahead of the sink than it was. All four fixtures at both sample rates, both controls and the diagnostic pass under native and address-and-undefined-sanitized helpers, the nine-case envelope corpus is unchanged at three passes and six intended failures with identical exit statuses and messages, and two official GCC 10.2.1 builds are byte-identical at 361,452 bytes and SHA-256 `9c20dc699cf1c2fd8e28aa78ba9d4c754def62fe0ff0df51b32df21614a7dde6`. Only the helper was installed, through the same staged roundtrip verification, with the previous helper preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-startup-lead.cf1d173`; RTL, RBF, Main and every media file are untouched and no playback was launched.

One consequence has to be watched on hardware rather than asserted from the host. The lead is 0.22 seconds of video at this stream's rate, so if the core presents pictures as they arrive rather than against its own timeline, audio will begin that much after video and the offset will persist. The raw control presented 577 pictures in 24.006 seconds and the audio-video run in 24.044, which is the source cadence in both cases and indicates timeline-paced presentation, so the expectation is a fuller FIFO and unchanged synchronization. A perceptible lag of audio behind video is therefore the specific failure this budget can introduce, and it bounds how large the budget may grow.

#### Next Steps:

Power-cycle, set Audio Test to Off and run only `23_bbb_opening24_exact_av.mpg` again. The acceptance question is whether the outlier count falls from 174 toward the raw control's zero, so report visible stutter, whether audio still starts with the picture rather than noticeably behind it, and all three LEDs, then leave the final image loaded for a schema-eight capture. The capture must keep aggregate errors, underrun and PCM protocol errors clear with all 577 pictures displayed, and presentation hold should rise from 7,967,197 cycles toward the raw control's 781,845,922. If the outlier count falls but audio now trails the picture, reduce the budget rather than abandoning it. If the outlier count does not fall at all, delivery is exonerated and the remaining cause is the presentation scratch scheduler, with the `scratch_available` false evidence at ordinals fifteen and 33 as the starting point for FPGA work. If it passes, rerun `20_bbb_full_48k.mpg` end to end before any release consideration.

#### Files Modified:

- host/arm/media_player_helper.c

#### Status:

- [x] Built
- [ ] Passed

---
## 454 COMMIT Unreleased f870d98 2026-08-24T08:12:56-07:00

#### Coming From:

Unreleased cf1d173

#### Purpose:

Build the exact-byte 24-second audio-video opening diagnostic and install it with the `cf1d173` helper under staged verification and preserved rollback.

#### Outcome:

`extract_program_stream_opening.py` cuts a Program Stream at a picture boundary without disturbing what it carries: packs and PES packets are copied verbatim, only the packet holding the first picture past the cut is rewritten to shorten its declared length to the payload retained, and the audio packets that follow are carried forward until the audio covers the picture kept, because a cut taken on video alone ends with less audio than picture and the sink would drain that shortfall as an underrun the source never had. Seven audio packets are appended for 1,155,456 samples against the 1,154,000 the 577 pictures require. The generated `23_bbb_opening24_exact_av.mpg` is 3,765,903 bytes at SHA-256 `d4b3ba1f02be1bd06a89e6f7b06f3ecf533ba0a09c8d7453056a501dadf0f585`, passes the compatibility checker at 720x480, frame-rate code two, 25 I plus 169 P plus 383 B pictures and 48 kHz stereo MPEG Layer II, and its demuxed video is byte-identical to the accepted raw control from entry 452 at SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. The same H.262 bytes that played perfectly without audio are therefore now under test with their own audio and nothing else changed.

That file is a direct discriminator between the two helpers rather than a general soak. Under the installed `f2b2e02` helper it reproduces the failure signature in 24 seconds: the audio deficit reaches 8,894 frames at 22.8 seconds, above the 8,192-frame sink FIFO, and the maximum PCM-free video span is 62,716 bytes. Under `cf1d173` the deficit never becomes positive at all, the maximum PCM-free video span is 4,052 bytes and steady batches stay within the accepted 2,048, with the transport carrying all 3,143,577 video and timestamp bytes and all 1,154,304 PCM frames and one clean end. The native and address-and-undefined-sanitized helpers agree.

Installation was staged and verified at every step, and the FPGA image, MiSTer Main and every existing media file are untouched. The installed helper was first downloaded and confirmed to be exactly `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58`, which a fresh official-toolchain rebuild of the `f2b2e02` source reproduces byte for byte, so the rollback path is proven rather than assumed. Those exact bytes were preserved as `/media/fat/linux/MediaPlayer_Helper.backup.pre-delivery-order.f2b2e02` and read back for comparison. The new helper was uploaded under a staging name, downloaded and confirmed byte-identical at SHA-256 `d40a3eeb8c5dfa1f41ee7a82ee7966b310ec458da789972ca7025f75866117f2`, then promoted, made executable and read back again at the same hash. The diagnostic was placed in `/media/fat/games/MediaPlayer/v0.7_qualification` by the same staged path and verified after promotion. No playback was launched.

#### Next Steps:

Power-cycle the MiSTer, set Audio Test to Off and run only `23_bbb_opening24_exact_av.mpg`. Acceptance is zero audible crackle or dropout, no repeated or late frames through the full 24 seconds, audio and video aligned at the end, and ordinary USER, DISK and POWER states; leave the final image loaded for a schema-eight capture and require zero aggregate, decoder, presentation, destination, PCM protocol and underrun flags with all 577 pictures displayed. If audio still underruns on this file, the delivery-order correction is insufficient and the next boundary is audio lookahead depth rather than interleaving, with the exact rollback available as `MediaPlayer_Helper.backup.pre-delivery-order.f2b2e02`. If it passes, run `20_bbb_full_48k.mpg` end to end and require completion without underrun or repeated-frame cadence, watching the high-motion sequence near 7:22 and the quiet stretch near 5:00, where host analysis still measures the deepest remaining audio excursion at 7,374 frames.

#### Files Modified:

- tools/streams/extract_program_stream_opening.py

#### Status:

- [x] Built
- [ ] Passed

---
## 453 COMMIT Unreleased cf1d173 2026-08-24T08:06:55-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Bound in-band delivery order to the sink FIFO after exact-byte isolation placed both the cadence regression and the sticky underrun in helper pacing.

#### Outcome:

The user ran `22_bbb_opening24_exact_video.m2v` without rebooting and reports completely smooth motion, ending with USER and POWER solid on and DISK blinking eleven times. The completed 800x600 capture is 545,901 bytes at SHA-256 `50eb09fefb6f822bda693365ee2619ad4d24354205766ce40b25ce63fc7988b8`. Schema-eight telemetry accepts all 3,138,618 bytes with zero aggregate, presentation, destination, PCM protocol or underrun errors, sequence end, presentation completion and normal quiet reason one. The eight-bit counters reconstruct exactly to 25 I plus 169 P plus 383 B pictures, all 577 displays and 576 swaps. Those 576 intervals span 24.006454 seconds for 23.994 delivered frames per second. No gap exceeds the 3,000,000-cycle or 50-millisecond outlier threshold; the three largest are all 2,984,256 cycles or 49.738 milliseconds. Because this raw stream is copied from the failed Program Stream's exact H.262 opening, the paired result conclusively excludes encoded scene complexity, source timestamps, decoder throughput and the current FPGA image: the same bytes are smooth without PCM, while the audio-video form produces 139 outliers up to 116.054 milliseconds and an audio underrun within 21.74 seconds.

The transport structure explains both defects. The full file carries 14,315 video packets averaging 5,898 bytes but 28,628,352 audio samples, nearly 2,000 samples per video packet. The current helper may therefore place as many as 2,048 consecutive PCM records before one whole video packet. Once the 8,192-sample FPGA FIFO fills, that batch backpressures the shared byte path for approximately 42.7 milliseconds before the compressed picture can advance, adding an audio-sized pause to a raw decoder interval already measured near 49.7 milliseconds. Conversely, the existing single-sample guard before as many as 65,535 video bytes cannot refill enough audio to survive a difficult picture, which accounts for the sticky underrun. This is ordering granularity in the helper rather than corrupt content or insufficient FIFO capacity.

Commit `cf1d173` implements the approved correction with two constants revised on measured evidence, and the revision was approved before anything was committed or installed. The startup release, the 256-byte video slicing, the 4,096-frame steady reserve and the 128-frame refill after at most 4,096 PCM-free video bytes are all as approved. The approved 128-frame steady batch cap is not, because it makes audio admission a function of the video byte rate: 128 frames per 256-byte slice is half a frame per byte, while the movie needs an average of 0.34 and as much as 5.99 during the near-static second at 300 seconds, where video falls to 8,018 bytes per second over a full second and 4,608 over half a second. Built exactly as approved, the helper ended the soak 317,982 frames behind and delivered only 28,319,234 of 28,628,352 samples before the final video byte, a deeper starvation than the one being corrected. The cap therefore stays at the accepted 2,048 frames, which with the 4,096-frame reserve keeps peak occupancy at 6,144 against an 8,192-frame sink FIFO so a batch never waits for room, and the horizon is now served when the video queue is empty as well, so a quiet scene cannot throttle audio through its own byte rate.

The analyzer gained the measurement that decides this class of defect: at every timestamp record it compares the audio that has crossed against what the sink has consumed by then, and fails above the 8,192-frame FIFO depth documented in `rtl/audio/audio_pcm_fifo.sv`. Applied to the installed `f2b2e02` helper it reproduces the hardware failure rather than describing it: the deficit holds at 4,578 frames of surplus for the whole movie, then spikes to 8,750 frames at 21.7 seconds and 8,894 at 21.9 seconds, which exceeds the 8,192-frame FIFO exactly where entry 451's telemetry froze on `audio_pcm_underrun`. Under `cf1d173` the worst deficit anywhere in the movie is 7,374 frames at 461.3 seconds, and at 21.7 seconds the sink is 2,626 frames ahead instead of behind. The maximum PCM-free video span falls from 64,768 to 4,052 bytes and no admitted video run exceeds 256 bytes, while the transport remains 342,199,090 bytes with video and timestamps at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and PCM at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, both unchanged.

Host qualification is complete and no installed file has been touched. Short and faded fixtures at 48 and 44.1 kHz and both controls pass under native and address-and-undefined-sanitized helpers, and a helper built from `f2b2e02` produces byte-identical video, timestamp and PCM payloads on all six, so only the interleaving changed. The nine-case envelope corpus retains three passes and six intended failures, and every failure case returns the same exit status and message as the baseline helper. Two official GCC 10.2.1 builds are byte-identical; the 361,452-byte static stripped ARM EABI5 helper has SHA-256 `d40a3eeb8c5dfa1f41ee7a82ee7966b310ec458da789972ca7025f75866117f2`. One pre-existing defect was observed and not changed: a Program Stream carrying no decodable MPEG Layer II audio, including `good_video_only.mpg` and `bad_audio_codec.mpg`, fails on the 512 KiB video lookahead limit rather than the intended missing-audio message, identically on both helpers.

#### Next Steps:

Build the copied-stream 24-second audio-video opening diagnostic from `20_bbb_full_48k.mpg`, then install only the `cf1d173` helper and that file through staged roundtrip verification with the exact `f2b2e02` helper preserved for rollback, leaving RTL, RBF, Main and every existing media file unchanged. Require zero audio underrun, zero cadence outliers above the 3,000,000-cycle threshold, clean synchronization and ordinary LEDs on that diagnostic before the full soak is repeated. If the diagnostic passes, rerun `20_bbb_full_48k.mpg` end to end and require completion with no underrun, no repeated-frame cadence, stable alignment through the high-motion sequence near 7:22 and the credits, and a schema-eight capture with zero aggregate, decoder, presentation and destination errors. The residual host measurement to watch is the 7,374-frame deficit at 461.3 seconds, which is within the FIFO but is the deepest remaining excursion; if hardware shows an underrun there rather than at 21.7 seconds, the next boundary is audio lookahead depth rather than delivery order. Separately, the missing-audio Program Stream path should report its own error instead of the lookahead limit.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/analyze_arm_av_transport.py

#### Status:

- [x] Built
- [ ] Passed

---
## 452 COMMIT Unreleased f2b2e02 2026-08-24T07:31:54-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Isolate the failed Program Stream cadence from decoder throughput with an audio-free high-motion control, then prepare an exact-byte opening comparison before changing pacing code.

#### Outcome:

Before touching the MiSTer, the user recorded the completed full soak's ordinary terminal indication: USER and POWER solid on with DISK blinking eleven times. Without rebooting, the exact installed `13_bbb_squirrel_15sec_native24_q6.m2v` then played its 7:15–7:30 high-motion sequence perfectly with no visible stutter and no audio by design, ending with the same ordinary LEDs. The completed 800x600 capture is 508,980 bytes at SHA-256 `3cc49f8b2180b90f4ebce63f0875fd82eae7eb60c04f840ecb558713e9c40d20`; an initial 425,984-byte retrieval occurred before the screenshot finished writing and was discarded rather than analyzed. Schema-eight telemetry reports zero aggregate errors, no audio underrun or PCM protocol error, all 2,603,570 bytes accepted, 121 reference plus 239 B pictures decoded, sequence end, presentation completion and normal quiet reason one. The eight-bit display counters wrap exactly as expected for all 360 pictures and 359 swaps. Reconstructing that wrap gives 359 intervals over 14.960773 seconds, or 23.996 frames per second. No display gap crosses the 50-millisecond outlier threshold, and the three largest are all only 2,984,256 cycles or 49.738 milliseconds. This is a sharp contrast with the audio-video soak's 139 threshold crossings and 116.054-millisecond repeated-frame gaps within its first 21.74 seconds, and proves the current decoder and RBF can sustain demanding 24 fps content when PCM is absent.

One encoding variable remains because the existing squirrel clip begins a fresh audio-free encode at 7:15 rather than reusing the failed Program Stream's exact bytes. A final bounded discriminator was therefore produced without source changes: `22_bbb_opening24_exact_video.m2v` is the first 577 pictures copied byte-for-byte from `20_bbb_full_48k.mpg`'s H.262 stream, followed only by a sequence-end code. The 3,138,618-byte file passes the 720x480 frame-rate-code-two envelope at 25 I, 169 P and 383 B pictures and has SHA-256 `100dcb7d536918263def73bc2b8e660fdb2e975221ccd9d548b0845bb853471a`. It was uploaded under a staging name, retrieved byte-identically, promoted only after verification and retrieved again at the same hash. Helper, RBF, Main and every existing media file remain unchanged, and no playback was launched during installation.

#### Next Steps:

Without rebooting, run only `22_bbb_opening24_exact_video.m2v`. Report whether its 24-second motion is continuous or shows the repeated-frame cadence seen during the opening of `20_bbb_full_48k.mpg`, plus USER, DISK and POWER at the end, then leave its final image loaded for schema-eight capture. A clean exact-byte raw run will conclusively place both the cadence regression and the soak's early underrun in shared in-band PCM/video pacing; matching stutter will instead identify the encoded opening's decoder workload. Do not replay the full Program Stream or run another file before capture.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 451 COMMIT Unreleased f2b2e02 2026-08-24T07:22:11-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Close the full audio-video soak with quantified cadence and audio evidence, distinguish authored end-sting level from helper decode, and select the shortest isolating follow-up.

#### Outcome:

The user completed `20_bbb_full_48k.mpg` without replay. Audio stayed synchronized for the full 9:56 and had no crackle or audible stutter during the body, but video showed definite brief repeated or late frames roughly every quarter to half second, more frequently than once per second. At the closing iris immediately before the final plate, the audio sounded as if it blew out. The untouched terminal screenshot is 8,050 bytes at SHA-256 `4ad16a8fc108fe0935fd48651e688c35af97988612357cced397de6a8334290e` and correctly shows the final black raster, but schema-eight telemetry had frozen on the first fatal condition about 21.74 seconds into playback. Its sole aggregate flag is `0x0400`, a real `audio_pcm_underrun`; PCM protocol, presentation and destination errors remain clear. At that freeze 2,876,134 transport bytes had been accepted and 139 display gaps had already exceeded the profiler's 3,000,000-cycle or 50-millisecond outlier threshold. The three largest gaps are each 6,963,264 cycles or 116.054 milliseconds at picture ordinals nine, 57 and 81; all record `decoder_ready` false and compressed-input FIFO pending while scratch space is available and neither presentation nor destination holds. The eight-bit long-run picture counters wrap, but their states and the 16-bit outlier count prove frequent decoder-input lateness rather than source timestamp jitter or a presentation hold, matching the user's observation while the audio-owned timeline preserves long-term sync.

Main's retained 3,972,939-byte log at SHA-256 `90ceb8a7ac772cf2822ad4311e3d6b08e111068ea5cef6ddcd7b8934c87ef810` proves complete host delivery despite that hardware freeze: helper exit is zero, all 342,199,090 deterministic transport bytes arrive over 83,545 reads with 667 transient would-block results, all 84,543,918 video and PTS bytes and all 28,628,352 PCM frames are emitted, and the established scheduler peaks remain 370,338 video bytes plus 6,654 samples. The final-sting decode is not invented by the helper. Helper and FFmpeg outputs are both exactly 28,628,352 stereo frames; across the entire movie and every measured tail window the helper differs by at most two signed sixteen-bit counts with approximately 0.504-count RMS error. At 579.946 seconds, 16.478 seconds before the end and coincident with the user's closing-iris marker, both decodes reach full scale on the same four samples. That loud transient is therefore present in the encoded source and the ARM decode preserves it, though the independent early hardware underrun means the overall playback path still fails the clean-audio requirement. The soak fails release acceptance on both frequent cadence outliers and sticky underrun even though it completes, stays synchronized and avoids audible body crackle.

#### Next Steps:

Before any source or installed-state change, record the soak's final USER, DISK and POWER states, then run only the already installed `13_bbb_squirrel_15sec_native24_q6.m2v` without rebooting. Its exact 2,603,570-byte SHA-256 is `9257ffadc24eb6696fc9760f3253764b396c993dfc3640e921c97611bad2edce`, it contains 360 audio-free pictures from the 7:15–7:30 high-motion sequence and it passes the same video envelope. Report whether its motion is continuous or shows the same repeated-frame cadence, especially at the wooden spikes near 7:22, plus all three final LEDs, then leave its final image loaded for schema-eight capture. A smooth raw clip isolates the defect to shared in-band PCM/video pacing; matching stutter instead isolates it to decoder throughput or a decoder-side regression. Do not replay the ten-minute Program Stream.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 450 COMMIT Unreleased f2b2e02 2026-08-24T07:11:14-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Preserve the first in-progress full-soak cadence observation without disturbing playback or conflating it with audio-video drift.

#### Outcome:

During the uninterrupted `20_bbb_full_48k.mpg` run, the user reports suspected microstutters while audio remains synchronized, then confirms that brief repeated or late video frames accurately describe the visible behavior. No mid-run screenshot was triggered because host screenshot work could perturb the very cadence under observation. Read-only inspection proves the authored source is not timestamp-jittered: all 14,315 video pictures span 596.416666 seconds with every adjacent presentation timestamp separated uniformly by either 0.041666 or 0.041667 seconds at exact 24 fps. The compatibility checker also retains a strict pass at 720x480, frame-rate code two, 597 I, 4,176 P and 9,542 B pictures with 48 kHz stereo MPEG Layer II audio. The observation is consistent with the already captured two-second controls, whose three largest decoder-limited display intervals recur at GOP picture ordinals eleven, 23 and 35 and reach 5,968,512 decoder cycles or 99.475 milliseconds despite zero error flags and complete picture counts. Uniform source timing plus continuing audio sync therefore points to transient decoder/presentation lateness that repeats the prior frame, not accumulating timeline drift; the final long-run snapshot is still required to quantify its frequency and exclude a worse high-motion or terminal failure.

#### Next Steps:

Continue the current soak without pausing, replaying or triggering a screenshot. Note whether the repeated-frame effect becomes more obvious during the high-motion sequence near 7:22, smooth camera motion or rolling credits, and whether audio remains synchronized throughout. After the full 9:56 reaches its natural end, report crackle, dropout, drift, visible corruption, the repeated-frame behavior and USER, DISK and POWER, then leave the final image loaded for schema-eight capture before any other input.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 449 COMMIT Unreleased f2b2e02 2026-08-24T07:05:26-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Complete the six-case input-envelope failure sweep with explicit truncated-stream rejection and immediate known-good recovery.

#### Outcome:

Without rebooting after the corrected 50 fps pair, the user loaded `15_bad_truncated.mpg`; it settles on a blank screen with USER blinking eight times, DISK solid off and POWER solid on, the same explicit decoder-failure indication as the unsupported geometry cases rather than ordinary success or a wedge. Immediate return to `00_good_480p_48k.mpg` passes like the established controls. The untouched 800x600 recovered-control capture is 104,740 bytes at SHA-256 `cd77217789074dbe3273f773dbf6723e0e62014e065ea7894bb3ea4402578393`. Its schema-eight telemetry reports all 582,742 accepted transport bytes, 44 associated timestamps, seventeen reference plus 31 B pictures, all 48 pictures displayed and 47 swaps. Sequence end and presentation completion are true; aggregate errors are zero, audio underrun and PCM protocol error are false, all decoder, presentation and destination errors are clear, and no decode, reorder, scratch, promotion, future-reference or terminal-boundary work remains at the normal quiet reason-one snapshot. First presentation occurs at 2,430,404 cycles, the final picture at 1.961 seconds and quiet completion at 2.057 seconds, with delivered cadence 24.469 frames per second. All six intended failure cases have now failed visibly without wedging the MiSTer, and every one has recovered immediately to a telemetry-clean 48 kHz control without reboot.

#### Next Steps:

Power-cycle once, set Audio Test to Off and run only `20_bbb_full_48k.mpg` through its complete 9:56 duration. Check opening audio-video alignment, ordinary scene transitions, the high-motion sequence near 7:22, credits and the final audio tail; report any crackle, dropout, progressive drift, visible stutter or corruption and all three terminal LEDs. Leave the final image loaded for a schema-eight capture. Do not replay the soak or any other file before that capture.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 448 COMMIT Unreleased f2b2e02 2026-08-24T07:02:00-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Hardware-qualify the corrected rejection of the 50 fps envelope case and immediate recovery to the known-good 48 kHz control.

#### Outcome:

With the exact `f2b2e02` helper active and without rebooting, the user ran `14_bad_rate_50.mpg`; it now behaves like the other helper-side failures, showing a black screen with no sound and USER, DISK and POWER all off rather than playing to ordinary success. The user immediately selected `00_good_480p_48k.mpg` without rebooting and reports perfect playback, with USER and POWER solid on and DISK blinking eleven times. The untouched 800x600 recovered-control capture is 104,786 bytes at SHA-256 `56bc682f106ff0b1b8363f4046d5b63299316d5fab4822b6332be63cf1174857`. Schema-eight telemetry proves clean re-arm after the new preflight rejection: all 582,742 transport bytes are accepted, 44 timestamps associate, seventeen reference plus 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen and presentation completes. Aggregate error flags are zero, audio underrun and PCM protocol error are false, every decoder, presentation and destination error is clear, and the quiet reason-one snapshot has no pending scheduler state. First presentation occurs after 2,431,574 decoder cycles, the final picture after 1.957 seconds and quiet completion after 2.057 seconds; delivered cadence is 24.530 frames per second. This passes the corrected fifth failure-and-recovery pair and hardware-accepts the conservative maximum-30-fps runtime boundary.

#### Next Steps:

Without rebooting, run only `15_bad_truncated.mpg` for no more than ten seconds and report the screen, sound and USER, DISK and POWER states. It must fail without claiming ordinary success or wedging the menu. Immediately select `00_good_480p_48k.mpg` again without rebooting and report alignment, sound, picture and all three LEDs, leaving the final image loaded for one last recovered-control capture. Do not start `20_bbb_full_48k.mpg` until this sixth and final failure pair passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 447 COMMIT Unreleased f2b2e02 2026-08-24T06:57:42-07:00

#### Coming From:

Unreleased f2b2e02

#### Purpose:

Install the exact helper-side H.262 rate preflight with a byte-verified rollback while leaving the accepted FPGA image and qualification media unchanged.

#### Outcome:

Read-only retrieval first confirmed `/media/fat/linux/MediaPlayer_Helper` at the accepted 361,452-byte SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` and `/media/fat/MediaPlayer.rbf` unchanged at 4,126,828-byte SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`. Candidate `f2b2e02` was uploaded as `/media/fat/linux/MediaPlayer_Helper.stage.f2b2e02`, marked executable, retrieved and compared byte-for-byte at SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58` before any active-name mutation. The current helper was then preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-rate-gate.3814243` and the verified stage promoted. Independent post-promotion retrieval reproduces the candidate hash for the active mode-0755 helper and the predecessor hash for the rollback. The RBF remains byte-identical, as do `00_good_480p_48k.mpg` at SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5` and `14_bad_rate_50.mpg` at SHA-256 `6a698ada56937d19a4b1215f3f79f9ee6a4f7a9e46a9305119b6956c07aa8fcb`. Main and every other media file were untouched, and no playback or reboot occurred during installation.

#### Next Steps:

Without rebooting, run only `14_bad_rate_50.mpg` and wait no more than ten seconds. It must return promptly without displaying the video or producing the ordinary successful USER-solid, DISK-eleven-blink and POWER-solid combination; report the screen, sound and all three LEDs. Then immediately select `00_good_480p_48k.mpg` without rebooting and report alignment, sound, picture and all three LEDs, leaving its final image loaded for launch-free capture. Do not run `15_bad_truncated.mpg` or `20_bbb_full_48k.mpg` until this corrected rejection-and-recovery pair passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 446 COMMIT Unreleased f2b2e02 2026-08-24T06:48:23-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Close the recovered-control half of the unexpected 50 fps success and define the conservative release-boundary correction.

#### Outcome:

The user immediately replayed `00_good_480p_48k.mpg` after the unexpectedly successful rate-code-six stream and reports normal playback with USER and POWER solid on and DISK blinking eleven times. The launch-free recovered-control capture is 104,769 bytes at SHA-256 `c96ccf4db6e5f39434e12d881aca4241e6ef8510cc662ee07a0800f867577006`; schema-eight telemetry reports the complete 48-picture, 47-swap control with zero aggregate, decoder, presentation or audio errors and normal quiet completion. Commit `f2b2e02` now makes the helper's runtime boundary match the offline checker without changing RTL, Main, media or the transport protocol. A read-only first pass incrementally scans only the selected H.262 elementary video stream, preserves scanner state across Program Stream PES boundaries, validates the first sequence header and rewinds before the normal demux can emit video or decode PCM. Codes one through five remain accepted, while codes six through eight and every other out-of-range code fail clearly before either standard-output transport or an explicit PCM file receives a byte. Permanent verifier cases cover all five accepted raw codes, all three rejected raw codes, a rate-code-six sequence header split across two video PES packets and the generated `bad_rate_50.mpg` envelope case with zero-byte rejection outputs. Short and faded fixtures at 48 and 44.1 kHz pass under native and address-and-undefined-sanitized helpers with byte-identical video, exact established PCM lengths, maximum sample error two, correlation rounding to one and one clean end. The nine-case compatibility corpus retains exactly three passes and six intended failures. Bounded scheduling is unchanged for both controls, and the 596-second soak reproduces transport SHA-256 `3364dac5631d266adfb726c0bd26751e66ad069dd06c5ca23433d9c28c3df93d`, video/PTS SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and PCM SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`, with its established 64,768-byte maximum PCM-free video gap and 2,048-sample maximum steady batch. Two official GCC 10.2.1 builds are byte-identical; the 361,452-byte static stripped ARM EABI5 helper has SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58`. No installed file has changed.

#### Next Steps:

Retrieve and verify the currently installed helper before mutation, preserve it under a new exact rollback name, upload helper SHA-256 `4b496d9725dc520bd463a4e22e22430ebb575e778cf65cfd3f9c20a8e7479a58` through a commit-specific staging name and retrieve it byte-identically before promotion. Leave RBF, Main and every media file unchanged, and do not launch playback during installation. Then run only `14_bad_rate_50.mpg`; require a prompt non-successful return with no ordinary pass LEDs, immediately replay `00_good_480p_48k.mpg` without reboot and require the established aligned, crackle-free control with USER and POWER solid and DISK blinking eleven times. Leave `15_bad_truncated.mpg` and the full soak deferred until that corrected fifth pair passes.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/verify_arm_av_pipeline.py

#### Status:

- [x] Built
- [ ] Passed

---
## 445 COMMIT Unreleased 3814243 2026-08-24T06:44:59-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Record the unexpected ordinary success of the nominally unsupported 50 fps envelope case and stop qualification before changing its classification.

#### Outcome:

The user ran `14_bad_rate_50.mpg` and left its final image loaded because it appeared and sounded to play completely without issue; USER and POWER were solid on and DISK blinked eleven times, exactly the ordinary-success indication that this expected-failure case was intended not to claim. The untouched 800x600 schema-eight capture is 104,817 bytes at SHA-256 `39c966722977b69841d1913da05e5312ebdca2eda036730953a82f429d06b45d`. It confirms genuine successful playback rather than a misleading LED state: frame-rate code six is retained, all 1,071,430 accepted transport bytes arrive, 92 timestamps associate, 34 reference plus 66 B pictures decode, all 100 pictures display with 99 swaps, delivered cadence is 50.921 frames per second, audio underrun and PCM protocol error are false, aggregate, decoder, presentation and destination errors are zero, sequence end is seen and the session reaches normal quiet reason one with no pending state. The PTS presentation path explains the checker mismatch. Timestamped candidates use the 90 kHz audio-derived timeline instead of the scheduler's free-running cadence table, while `check_media_compatibility.py` still rejects codes six through eight solely because that fallback table implements only codes one through five. Hardware therefore proves this specific timestamped 50 fps file is functional, but the planned six-failure envelope has only four accepted failures so far and its policy cannot be changed from one two-second observation without a bounded decision and additional coverage.

#### Next Steps:

Do not run `15_bad_truncated.mpg` yet. Immediately replay `00_good_480p_48k.mpg` without rebooting and report alignment, sound, picture and all three LEDs so the fifth pair's recovery half is still recorded. After that control is captured, choose a new approved boundary: either keep the advertised 30 fps maximum and enforce it before ordinary hardware success, or qualify timestamped 50 fps as a separate supported Program Stream profile with sustained cadence, audio alignment and raw-M2V fallback distinctions. Do not infer support for 59.94 or 60 fps from this result.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 444 COMMIT Unreleased 3814243 2026-08-24T06:41:18-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify explicit decoder rejection and recovery for the out-of-envelope 720x576 PAL geometry case.

#### Outcome:

The user reports that `13_bad_geometry_pal.mpg` behaves exactly like the preceding geometry test: a black screen, USER blinking eight times, DISK solid off and POWER solid on, followed by an immediate successful `00_good_480p_48k.mpg` replay without reboot. The launch-free recovered-control capture is 104,787 bytes at SHA-256 `bac9bc0944d06035259c84abf05ff7bd5cffb683955b7fb9ca7d6127608f7fd7`. Schema-eight telemetry proves the PAL-height error was cleared: aggregate flags are zero, audio underrun and PCM protocol error are false, all decoder, presentation and destination errors are clear, all 582,742 transport bytes are accepted, 44 timestamps associate, seventeen reference plus 31 B pictures decode and all 48 pictures display with 47 swaps. Sequence end, presentation complete and normal quiet reason one are true with no pending scheduler state and saturated healthy PCM activity. This accepts the fourth recovery pair and independently confirms geometry diagnostic code eight and clean next-stream re-arm for both excessive width-height and excessive-height-only cases.

#### Next Steps:

Without rebooting, run `14_bad_rate_50.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `15_bad_truncated.mpg` until this fifth pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 443 COMMIT Unreleased 3814243 2026-08-24T06:39:27-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify explicit decoder rejection and recovery for the out-of-envelope 1280x720 geometry case.

#### Outcome:

Loading `12_bad_geometry_720p.mpg` produces a black screen with USER blinking eight times, DISK solid off and POWER solid on. This is an explicit non-success diagnostic for the unsupported geometry rather than a silent wedge. The user immediately returns to `00_good_480p_48k.mpg` without rebooting and reports the same successful behavior as the established controls. The launch-free recovered-control capture is 104,724 bytes at SHA-256 `bc2ceab2ea3eab4ed419a2c0f5349f9f45582ccf0e8e70ffc4a3a1ad39cf2935`. Its schema-eight telemetry proves complete re-arm: zero aggregate flags, audio underrun and PCM protocol error false, all decoder, presentation and destination errors clear, all 582,742 transport bytes accepted, 44 timestamps associated, seventeen reference plus 31 B pictures decoded and all 48 pictures displayed with 47 swaps. Sequence end, presentation complete and normal quiet reason one are true with every pending scheduler state clear and saturated healthy PCM activity. This accepts the third recovery pair and proves that geometry error code eight is confined to the invalid stream and cleared by the next download start.

#### Next Steps:

Without rebooting, run `13_bad_geometry_pal.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `14_bad_rate_50.mpg` until this fourth pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 442 COMMIT Unreleased 3814243 2026-08-24T06:36:19-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify recovery from the unsupported 32 kHz audio-rate envelope case through an immediate known-good replay.

#### Outcome:

The user reports that `11_bad_audio_rate.mpg` produces only a black screen, with the same all-LEDs-off responsive behavior as the preceding expected failure, and does not claim ordinary success. Immediate selection of `00_good_480p_48k.mpg` without reboot works and produces the normal pass indication. The launch-free recovered-control capture is 104,724 bytes at SHA-256 `c8306c2485c40c11dd0583238ed7e903bf7ff991d57c4255e2b8dbe2817d51b0`. Schema-eight telemetry again reports zero aggregate flags, audio underrun and PCM protocol error false, all decoder, presentation and destination errors clear, all 582,742 transport bytes accepted, 44 timestamps associated, seventeen reference plus 31 B pictures decoded and all 48 pictures displayed with 47 swaps. Sequence end, presentation complete and normal quiet reason one are true with every pending scheduler state clear and saturated healthy PCM activity. This accepts the second expected-failure recovery pair and proves that rejecting the unsupported sample rate leaves Main, the helper handoff and the next valid shared audio-video transport reusable without reset.

#### Next Steps:

Without rebooting, run `12_bad_geometry_720p.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `13_bad_geometry_pal.mpg` until this third pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 441 COMMIT Unreleased 3814243 2026-08-24T06:33:13-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify recovery from the unsupported-audio-codec envelope case through an immediate known-good replay without reboot.

#### Outcome:

The user ran `10_bad_audio_codec.mpg`; USER, DISK and POWER all remained off, the file did not claim ordinary success and the MiSTer remained responsive. The user immediately selected `00_good_480p_48k.mpg` without rebooting and reports pass-indicating LEDs. The launch-free recovered-control capture is 104,729 bytes at SHA-256 `32836080d2fcebd8d452e4165207072e9681f9adbbe83d7add863bfa8b79ed53`. Schema-eight telemetry proves that the rejected AC-3 stream leaves no sticky fault: aggregate error flags are zero, audio underrun and PCM protocol error are false, decoder, presentation and destination errors are clear, all 582,742 control transport bytes are accepted, 44 timestamps associate, all seventeen reference and 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen, presentation completes and the session freezes for normal quiet reason one with every pending scheduler state clear. PCM count and peak occupancy saturate their telemetry fields without starvation. This accepts the first expected-failure recovery pair and proves that helper rejection of an unsupported codec does not wedge Main, the shared in-band path or the next valid stream.

#### Next Steps:

Without rebooting, run `11_bad_audio_rate.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; stop and report an unavailable menu, ignored input or failed control before any reboot. Do not continue to `12_bad_geometry_720p.mpg` until this second pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 440 COMMIT Unreleased 3814243 2026-08-24T06:29:29-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Qualify the bounded-lookahead scheduler on the 44.1 kHz control and open the expected-failure recovery sweep only after both supported rates are clean.

#### Outcome:

The user reports that `01_good_480p_44k.mpg` begins perfectly synchronized and completes without crackle, with USER and POWER solid on and DISK blinking eleven times. The completed 800x600 schema-eight capture is 104,739 bytes at SHA-256 `d07a9dd27157107c7eb3aacd6bc054a226d9c54673a3c0870bcce6e3b6c4e945`. It reports zero aggregate error flags, `audio_underrun` false, `pcm_protocol_error` false and every decoder, presentation and destination error clear. All 582,742 transport bytes are accepted, 44 timestamps associate, seventeen reference plus 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen and presentation completes before the snapshot freezes for normal quiet reason one. PCM count saturates at 16,383 and FIFO peak at 127 or more without starvation; every pending decode, reorder, scratch, promotion, future-reference and terminal-boundary state is clear. First presentation is 2,515,058 cycles or 41.9 milliseconds, the final picture presents after 1.939 seconds and the session reaches quiet after 2.054 seconds. Delivered cadence is 24.769 frames per second; the nine recorded decode-limited outliers include 99.475-millisecond intervals at picture ordinals 23 and 35 and 82.896 milliseconds at ordinal eleven, but all pictures display, no error or state remains and no visible stutter was reported. Together with Entry 439, both supported sample rates now pass the same corrected user-media control boundary with perfect reported alignment and no crackle.

#### Next Steps:

Begin only the first expected-failure recovery pair without rebooting. Run `10_bad_audio_codec.mpg` for no more than ten seconds, record its visible result and USER, DISK and POWER states, then immediately run `00_good_480p_48k.mpg` and record alignment, sound, picture and all three LEDs again. An explicit rejection or non-successful settlement followed by a clean control is a pass; an unavailable menu, ignored input or failed control is a wedge and must be reported before any reboot. Do not continue to `11_bad_audio_rate.mpg` until this first pair is recorded.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 439 COMMIT Unreleased 3814243 2026-08-24T06:26:40-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Close focused hardware qualification of the bounded-lookahead scheduler on the formerly repeatable 48 kHz starvation control.

#### Outcome:

The user reports that `00_good_480p_48k.mpg` now works with audio and video perfectly synchronized, neither repeatable crackle present and no reported picture stutter. USER and POWER are solid on and DISK blinks eleven times, the normal final-GOP progress state. The launch-free 800x600 schema-eight capture is 104,785 bytes at SHA-256 `4845b6ab2e9f858d3061371adf0479357da034b46bbe86dfc30f9870f7d5fa50`. It closes the static proof with zero aggregate error flags, `audio_underrun` false, `pcm_protocol_error` false and decoder, presentation and destination errors all clear. All 582,742 accepted transport bytes reach the core, 44 timestamps associate, seventeen reference plus 31 B pictures decode, all 48 pictures display with 47 swaps, sequence end is seen, presentation completes and the snapshot freezes for normal quiet reason one with no pending decode, reorder, promotion, scratch, future-reference or terminal-boundary work. PCM sample count saturates the telemetry field at 16,383 and FIFO peak saturates at 127 or more without starvation. First presentation occurs after 2,430,554 decoder cycles or 40.5 milliseconds, the final picture presents after 1.959 seconds and the session becomes quiet after 2.057 seconds. The cadence profiler records every picture with an aggregate 24.494 delivered frames per second; its three largest decode-limited intervals are 99.475 milliseconds at periodic picture ordinals eleven, 23 and 35, but they drop no picture, leave no state or error and produced no user-reported visible stutter. This accepts helper source `3814243` and active helper SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` for the repaired 48 kHz control while retaining timing-clean RBF source `091b150`.

#### Next Steps:

Without rebooting, run only `01_good_480p_44k.mpg` with Audio Test Off. Report beginning audio-video alignment, any crackle or dropout, any visible picture stutter, whether audio extends beyond the final picture and all three final LEDs, then leave its final image loaded for schema-eight capture. Do not begin the six expected-failure recovery pairs until the 44.1 kHz control also has zero audio underrun, PCM protocol, presentation, decoder and aggregate error telemetry.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 438 COMMIT Unreleased 3814243 2026-08-24T06:23:08-07:00

#### Coming From:

Unreleased 3814243

#### Purpose:

Install the exact bounded-lookahead helper with byte-verified rollback while leaving the timing-clean FPGA and qualification media unchanged.

#### Outcome:

Read-only retrieval first confirmed the installed 361,452-byte helper at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. Candidate `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` was uploaded as `/media/fat/linux/MediaPlayer_Helper.stage.3814243`, retrieved and compared byte-for-byte before any active-name mutation. The prior helper was then atomically renamed to `/media/fat/linux/MediaPlayer_Helper.backup.pre-scheduler.9afe2f0`, the verified stage was promoted, and FTP metadata independently confirms active mode `0755`, owner and group root and size 361,452 bytes. Separate post-promotion retrievals reproduce the candidate hash for the active helper and `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54` for the rollback. The active 4,126,828-byte RBF remains unchanged at SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`, and active `00_good_480p_48k.mpg` remains unchanged at SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5`. Main and every other media file were untouched, no reboot occurred and no playback was launched.

#### Next Steps:

Without rebooting, leave Audio Test Off and run only `00_good_480p_48k.mpg`. Report whether audio and video begin together, whether either former crackle/dropout occurs, whether the picture stutters at the former late point, whether audio still plays beyond the final picture, and the final USER, DISK and POWER states. Leave the final image loaded for a fresh schema-eight capture. Do not run the 44.1 kHz control, any expected-failure case or the full soak until this control has zero audio underrun, PCM protocol, presentation, decoder and aggregate error flags. If the helper fails to start or behavior regresses materially, restore `MediaPlayer_Helper.backup.pre-scheduler.9afe2f0`; the RBF requires no rollback.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 437 COMMIT Unreleased 3814243 2026-08-24T06:21:28-07:00

#### Coming From:

Unreleased 091b150

#### Purpose:

Record the failed widened-FIFO control, correlate its first repeatable crackle to an exact transport starvation boundary, and define the bounded ARM-side scheduling correction.

#### Outcome:

The user reports that corrected `00_good_480p_48k.mpg` now begins with audio and video apparently aligned, but audio still plays slightly past the final picture, both repeatable crackles/dropouts remain, and the picture stutters once with the final crackle. The terminal LEDs were USER solid on, DISK blinking eleven times and POWER solid on. A launch-free schema-eight screenshot captured the loaded final raster at displayed frame 47 while telemetry had frozen on the first error: aggregate error flags are exactly `0x0400`, meaning `audio_pcm_underrun` alone, with `pcm_protocol_error` and every video, presentation and destination error clear. The snapshot occurs at 3,516 accepted PCM samples and 218,405 clean video bytes. Exact native-helper correlation proves why the 8,192-sample FIFO cannot fix this stream: only 3,456 samples precede a 147,631-byte PCM-free video interval, and the frozen count is exactly those samples plus 60 from the resumed batch that makes starvation sticky. Commit `3814243` implements the approved bounded-lookahead correction entirely in the helper. It retains the two-picture startup boundary, queues at most 512 KiB of video, uses audio and monotonic video PTS to maintain a 2,048-sample horizon, caps the initial release at 4,096 samples, caps every steady batch at 2,048 samples and inserts a guard sample before any post-start PCM-free video span can exceed 65,535 bytes. The analyzer independently compares scheduled in-band output with an explicit-output helper pass and proves exact video, PTS and PCM preservation without retaining the full transport in memory. On the failed 48 kHz control, the initial batch is 3,200 samples, the maximum steady batch is 2,048, the maximum PCM-free video span falls to 38,446 bytes, the terminal audio batch is 238 samples, and peak lookahead is 242,876 video bytes plus 4,078 PCM samples. The 44.1 kHz control has the same span and batch bounds. The 596-second soak reproduces a deterministic 342,199,090-byte transport at SHA-256 `3364dac5631d266adfb726c0bd26751e66ad069dd06c5ca23433d9c28c3df93d`, with all 84,543,918 video/PTS bytes at SHA-256 `db00682bb603a5f575df5a1d5d0b7a580c46ca99eed028f024ac6bc37016f38f` and all 28,628,352 PCM frames at SHA-256 `337b1387b9324b6c391a3223ced8f7660bd5144267b29d3964b4ed6b282839af`; its initial batch is 5,504, steady batches are at most 2,048, maximum gap is 64,768 bytes and peak video lookahead is 370,338 bytes. Short and faded fixtures at both rates preserve exact sample counts, clean ends, maximum sample error two and correlation rounding to one under native and address-and-undefined sanitizers. The nine-case envelope retains exactly three passes and six intended failures, the full soak remains a strict pass, and two official GCC 10.2.1 builds are byte-identical. The 361,452-byte static stripped ARM EABI5 helper has SHA-256 `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576`. No RTL, RBF, Main or media changed.

#### Next Steps:

Retrieve and hash the currently installed helper before mutation. Preserve it under an exact new rollback name, upload candidate `4c0f1d2c3e9c229ccad38b683701968feac7b9f1111de20ec6b4a3f0864b2576` through a staging name, retrieve it byte-identically, mark it executable and promote it only after rollback exists. Leave the timing-clean `091b150` RBF, Main and every installed media file unchanged. Then run only `00_good_480p_48k.mpg` without rebooting, report alignment, both former crackle locations, any visible stutter, the final audio tail and all three LEDs, and leave the final image loaded for a fresh schema-eight capture. Do not continue to the 44.1 kHz control or any failure case until this control completes with no audio underrun or other telemetry error.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/analyze_arm_av_transport.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 436 COMMIT Unreleased 091b150 2026-08-24T05:47:31-07:00

#### Coming From:

Unreleased 091b150

#### Purpose:

Install the exact timing-clean starvation correction and corrected media while preserving byte-verified rollback.

#### Outcome:

Read-only retrieval first confirmed that the MiSTer still held accepted RBF SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` and unchanged helper SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. Candidate RBF `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea` was uploaded under a staging name, retrieved and compared byte-for-byte before promotion. All nine corrected qualification files were independently uploaded to a staging directory, retrieved and compared byte-for-byte, including the full 100,059,153-byte soak. The prior failed media set is preserved without mutation as `/media/fat/games/MediaPlayer/v0.7_qualification.failed.9afe2f0`; the accepted RBF is preserved exactly as `/media/fat/MediaPlayer.backup.pre-pcm-depth.047f5b2.rbf`; and the verified staging names were promoted only after those rollbacks existed. Post-promotion retrieval confirms active `/media/fat/MediaPlayer.rbf` at `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`, its rollback at `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the helper still at `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`, and active `00_good_480p_48k.mpg` at corrected SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5`. The remaining active media carry the exact Entry-435 hashes, including unchanged truncated-case hash `5ea02141a0be7846389b378f996f67e986bfef2a60dc289f9a7df6ab78f829ce` and full-soak hash `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. Main is unchanged, the running core remains the previous image until reboot, and no playback was launched.

#### Next Steps:

Power-cycle the MiSTer once to load the installed candidate, set Audio Test to Off, and run only corrected `00_good_480p_48k.mpg`. Report whether audio starts aligned with the opening video, whether either of the two repeatable crackles or any dropout remains, and the final state of USER, DISK and POWER after the file reaches its clean end. Do not run `01`, any expected-failure case or the full soak yet. If this control fails, leave the final image loaded and do not reboot so schema-eight telemetry can be captured; the exact RBF rollback is `MediaPlayer.backup.pre-pcm-depth.047f5b2.rbf` and the failed prior media remain in `v0.7_qualification.failed.9afe2f0`.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 435 COMMIT Unreleased 091b150 2026-08-24T05:26:02-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Eliminate deterministic PCM starvation and require clean terminal framing for user-converted Program Streams.

#### Outcome:

Commit `091b150` makes the H.262 sequence-end code and MPEG Program Stream end code mandatory compatibility conditions, adds one shared idempotent finalizer to every Program Stream generator, and widens the asynchronous PCM FIFO from 4,096 to 8,192 stereo samples for 170.7 milliseconds of capacity at 48 kHz while retaining the exact 2,048-sample startup threshold. The focused FIFO simulation accepts and drains all 8,192 samples in order across independent clocks, explicitly remains non-full after the obsolete 4,096 boundary, and reaches the correct full and empty limits; the output-adapter simulation preserves below-threshold silence, short-stream release, sticky true underrun and false-underrun-free clean termination. The static PCM verifier preserves all four pinned proof-tone hashes and both sample schedulers. The nine-case envelope regenerates twice byte-identically with all three good cases passing and all six bad cases failing as intended; removing the final 17 bytes from the 48 kHz control now reports both missing terminal conditions, finalization reconstructs the exact file and a second finalization changes nothing. Corrected 48 and 44.1 kHz controls have SHA-256 `1455af94803b1d9958a93fbdb978aa2a42c1d8045a9491f904ad1ad9b8ccdad5` and `417db70be8cadc8ca829984d149cb0a5ccda82b0dfc065869578789290a1c83e`. All four short and faded ARM fixtures now carry Program Stream ends, regenerate byte-identically, pass the strict checker, and pass native plus address-and-undefined-sanitized helper verification at both sample rates with byte-identical video, exact PCM lengths, maximum sample error two, correlation rounding to one, one clean audio end and every failure path preserved. The full movie remains a strict pass and byte-identical at SHA-256 `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. The sole Quartus 17.0.2 candidate completes in 10 minutes 4 seconds with zero errors and 146 warnings. It uses 28,918 ALMs, 44,607 registers, 3,523,027 memory bits, 446 RAM blocks, 65 DSP blocks and three PLLs: exactly 143,360 additional memory bits and 17 RAM blocks versus accepted `047f5b2`, with 270 fewer ALMs and 278 fewer registers from fitter variance. Every endpoint TNS is zero with positive setup slack of 0.090 nanoseconds HDMI, 1.613 host, 1.844 decoder, 2.976 SPI, 7.405 video, 8.530 FPGA clock one, 11.824 FPGA clock two, 14.127 audio and 18.893 main; worst hold is 0.247, recovery 4.227, removal 0.460 and minimum pulse width 1.122 nanoseconds. The dedicated Phase-1P reports find zero violations across 100 same-clock decoder paths, 80 same-clock video paths and 30 decoder recovery paths. The 4,126,828-byte RBF has SHA-256 `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea`.

#### Next Steps:

Retrieve and verify the currently installed RBF and helper before mutation. Preserve the accepted `047f5b2` RBF under a new exact rollback name, upload candidate `1fe3f61a8286e42e38db4c50eef6a112f31106590e6cdbcc6715fff82544b4ea` through a staging name and retrieve it byte-identically before the rename, and replace the failed `9afe2f0` qualification directory with the corrected deterministic media while retaining its exact rollback directory. Leave Main and helper unchanged. Then power-cycle and run only corrected `00_good_480p_48k.mpg` with Audio Test Off, reporting audio-video alignment, any crackle or dropout and all three terminal LEDs; do not continue to `01` or any expected-failure case until that control is clean.

#### Files Modified:

- MediaPlayer_top_00.svh
- rtl/audio/audio_pcm_fifo.sv
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_fifo.sv
- tools/streams/verify_d2_pcm_path.py
- tools/streams/check_media_compatibility.py
- tools/streams/finalize_program_stream.py
- tools/streams/generate_arm_av_test.py
- tools/streams/generate_compatibility_corpus.sh
- tools/streams/generate_test_big_buck_bunny.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 434 COMMIT Unreleased 9afe2f0 2026-08-24T05:24:13-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Record the failed first user-media control and isolate its repeatable crackle and absent terminal diagnostics.

#### Outcome:

The user power-cycled and ran `00_good_480p_48k.mpg` with Audio Test Off. Audio began roughly one second after video by the user's estimate, cracked twice at repeatable points, and USER, DISK and POWER all remained off, so the first control fails and the remaining qualification sequence is stopped. Host comparison rules out damaged decoded audio: the installed-source helper produces all 96,768 stereo samples at byte-identical length to FFmpeg with maximum sample error two, RMS error 0.5040, correlation `0.999999969`, and MPEG-frame boundary jumps of 167 counts against 168 in the reference. The terminal failure is independent and deterministic: the video's last bytes contain no sequence-end code, yet `check_media_compatibility.py` reports PASS and only emits a note, so the core cannot reach the sequence-ended quiet state that publishes the LED diagnostic. Static transport evidence isolates the crackle to starvation rather than decoding. After startup the helper emits 34,560 consecutive samples and then a 147,748-byte span with no PCM record; the 4,096-sample FPGA FIFO covers only 85.3 milliseconds, while the accepted hardware's 185,149-byte first-picture path completed in 155 milliseconds, predicting about 124 milliseconds for this span before allowing for decode backpressure. `audio_pcm_output_adapter` drives both channels to zero when the FIFO empties and resumes on the next sample, producing two deterministic amplitude edges and setting underrun only after data returns, exactly matching a repeatable two-edge crackle. This is an inference because the missing sequence end prevented telemetry capture. The full soak is exposed to the same problem, with measured post-start PCM-free spans up to 137,625 bytes. FFmpeg mux-rate changes are not a sufficient repair: they reduce this short control's gap at selected rates but produce spans up to 180,106 bytes at 5 Mbit/s and 1,883,117 bytes at 2.4 Mbit/s on the full movie. The reported startup offset remains approximate and should be measured from a recording after terminal framing and underrun are corrected rather than conflated with either defect.

#### Next Steps:

Do not run `01` or any expected-failure case on the current media set. The revised boundary needs user approval because it changes the approved host-only plan: make sequence-end presence a required compatibility condition, generate both the sequence-end video PES and Program Stream end for every good control, and increase the PCM FIFO from 4,096 to 8,192 samples so the current conversion recipe has 170.7 milliseconds of reserve without changing the 2,048-sample startup threshold. Prove the widened dual-clock FIFO, unchanged startup timing, underrun behavior and termination in focused simulation, run the full host regression, perform one timing-clean Quartus build, replace the RBF and corrected media with exact rollback, and repeat only `00_good_480p_48k.mpg` before resuming qualification. If the predicted resource or timing cost is not acceptable, the alternative is a larger ARM-side demux scheduler that reorders PCM throughout long video PES runs rather than relying on FFmpeg mux settings.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 433 COMMIT Unreleased 9afe2f0 2026-08-24T05:10:12-07:00

#### Coming From:

Unreleased 9afe2f0

#### Purpose:

Install the reproducible helper and complete v0.7 qualification media set while preserving exact rollback state.

#### Outcome:

Read-only retrieval first confirmed the MiSTer remained on accepted RBF SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68` and helper SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0`. The official-toolchain `9afe2f0` helper was uploaded under a staging name, downloaded and confirmed byte-identical at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`, marked executable through the FTP server and installed, with its predecessor preserved exactly as `/media/fat/linux/MediaPlayer_Helper.backup.pre-user-media.3f4b272`. A new `/media/fat/games/MediaPlayer/v0.7_qualification` directory contains the 48 kHz control at `b140c76c61da3c8ec46baf90548f290db7657661cc39b2cb0b3e80510531a2dd`, the 44.1 kHz control at `bd3935aa35100544ce4d5fe06b8d9de0e8f48f1a606cd2419f7abcc4c8891c50`, six expected-failure cases at `e4140672b46214b300b1ca558d0a8005dee035bb79ec44ec7c75d341714e89df`, `3f7f2df8eb0c16dedf10fa3059184aab17067cae61305c5994706842fef79f57`, `98965d3223b50258d2e673e5d58786ae1b4152df758f9e9decf10f90a68c48d0`, `ee485d5693caf90304ca348bdedbae5b9ac0559ed383d3e796f811428a6fccb6`, `c4f986798e64081f0128c167a30ab62226ed2f1aa9959cf4e99da49cd21d86cb` and `5ea02141a0be7846389b378f996f67e986bfef2a60dc289f9a7df6ab78f829ce`, and the full soak at `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. Every remote file was retrieved and compared byte-for-byte before the staging area was discarded. Main and the accepted FPGA image are unchanged, no playback was launched, and the obsolete RBFs and older helper backups called out in Entry 430 remain untouched because their deletion was reserved for the user.

#### Next Steps:

Power-cycle once, set Audio Test to Off and run `00_good_480p_48k.mpg` followed by `01_good_480p_44k.mpg`. If both pass, run each numbered bad case for at most ten seconds and immediately replay `00_good_480p_48k.mpg` without rebooting; record the visible result and all three LEDs for both halves of every pair, treating an unavailable menu or failed control as a wedge. After all six pairs pass, power-cycle once and run `20_bbb_full_48k.mpg` through its complete 9:56 duration, checking opening alignment, scene transitions, the high-motion sequence near 7:22, credits and the audio tail, then leave the final image loaded for schema-eight capture. Roll back to `MediaPlayer_Helper.backup.pre-user-media.3f4b272` if the new helper itself fails to start.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 432 COMMIT Unreleased 9afe2f0 2026-08-24T04:58:03-07:00

#### Coming From:

Unreleased 1102830

#### Purpose:

Make the user-converted playback boundary reproducible and prepare the hardware failure sweep and full-length audio-video soak.

#### Outcome:

Commit `9afe2f0` makes the user-media qualification boundary reproducible without changing FPGA RTL or MiSTer Main. The official MiSTer ARM GNU 10.2 archive verifies at its previously recorded SHA-256 `102825ae56c9e00142d06f35d2bdd3299edb6060e84a275a25b095e66fd3fc2a`, identifies as GCC 10.2.1, and produces two byte-identical 361,452-byte static ARM EABI5 helpers at SHA-256 `2cf665c0153a9885e103a1da5038997efb9050c7fcbceb3d3340537cfb153d54`. The helper's capabilities now advertise both 44.1 and 48 kHz, and the permanent generator and verifier exercise both short and faded profiles at each rate. Native and address-and-undefined-sanitized runs all preserve byte-identical video, one clean PCM end, maximum sample error two and correlation rounding to one; the 44.1 kHz paths carry mode byte one for 9,216 and 132,480 samples, while the 48 kHz paths carry mode byte three for 10,368 and 144,000 samples. Two independent generations reproduce the established 48 kHz fixture hash and the new 44.1 kHz fixture hash `8f522f8cc37be5e7a45f32599c5227946b6d1386cb93b452dfae0d37ef8987ff`, and the nine-case envelope corpus retains three passes and six expected failures. `generate_test_big_buck_bunny.py` preserves byte-identical video-only output and adds an opt-in Program Stream mode that verifies its demuxed video against the same sequence-ended elementary stream, carries source audio as stereo MPEG Layer II, writes the final sequence end in a bounded video PES and terminates with a Program Stream end code. The full local source at SHA-256 `4fc75fa403994e7c313da139d93a5aebdbda27cc951616aa4e480db6877c9850` generates a 100,059,153-byte, 14,315-picture, 596.458-second Program Stream at SHA-256 `fdc480e6b16bcbc7c143eb8f7e7edfe0d0bbd8e46a1035b728f07639e71b2357`. The helper strips 13,401 timestamp records to reproduce all 84,423,309 FFmpeg-demuxed video bytes exactly and decodes 28,628,352 stereo PCM frames byte-for-byte in length against FFmpeg, with maximum sample error two, RMS error 0.5037 and correlation `0.999999979`.

#### Next Steps:

Install the exact official-toolchain helper with rollback preserved, then place the generated 44.1 and 48 kHz good controls, six bad cases and full-length soak Program Stream on the MiSTer. Hardware acceptance requires both good controls to play, every bad case to avoid ordinary success and recover immediately through the 48 kHz control without a reboot, and the full movie to complete with stable audio-video alignment, clean audio, normal LEDs and zero PCM protocol, underrun, presentation, decoder or aggregate error telemetry. No Quartus build is required because this commit changes no FPGA source.

#### Files Modified:

- host/arm/media_player_protocol.h
- tools/streams/generate_arm_av_test.py
- tools/streams/generate_test_big_buck_bunny.py
- tools/streams/verify_arm_av_pipeline.py
- docs/TEST_INSTRUCTIONS.md

#### Status:

- [x] Built
- [ ] Passed

---
## 431 COMMIT Unreleased 1102830 2026-08-24T04:50:33-07:00

#### Coming From:

Unreleased 3f4b272

#### Purpose:

Accept 44.1 kHz audio and add a host-side input envelope checker with a deterministic corpus, as the first step toward user-converted playback.

#### Outcome:

The v0.7.0 goal is that users convert their own media with FFmpeg and test it, so the likely failure is an unsupported input rather than a decoder defect. Commit `1102830` addresses the two host-side halves of that. Adding 44.1 kHz proved to be a host-only change: `mpeg2_h262_inband_metadata` already extracts the rate bit from the record's mode byte, the top level already routes it, and `audio_pcm_output_adapter` already selects its phase step between `RATE_48000` and `RATE_44100`, so the entire FPGA path supported 44.1 kHz and only the helper rejected it. The helper now accepts 44,100 as well as 48,000 Hz and sets the mode bit from the decoded rate rather than hardcoding 48 kHz stereo, drains the pending queue before adopting a changed rate so held samples cannot be mislabelled, and reports the supported set when it refuses. Verification on a generated 44.1 kHz Program Stream shows 132,480 records all carrying mode byte one, while the accepted 48 kHz fixture still emits 144,000 records carrying mode byte three and its emitted stream is byte-identical to the previous build, so no 48 kHz behaviour changed. No FPGA rebuild is required. `check_media_compatibility.py` reports, before a file reaches hardware, whether it lies inside the implementation envelope, naming the FFmpeg option that fixes each problem: geometry against 720 by 480 and 45 by 30 macroblocks, frame-rate codes against the paced set one through five with codes six through eight named as unpaced, the progressive 4:2:0 frontend conditions delegated to the existing `analyze_h262_compatibility` so there is one video parser, and audio codec, sample rate and channel count. `generate_compatibility_corpus.sh` builds nine deterministic cases and asserts each verdict, and all nine agree: three good cases pass and six bad ones fail. Building that corpus immediately found a defect in the checker rather than in the core. Its Program Stream demultiplexer implemented only the MPEG-1 PES header form, so on the MPEG-2 PES packets FFmpeg actually emits it mis-stripped every packet and reported a valid video-only file as failing on picture 45. A checker that rejects good files is worse than none, since it sends users chasing a defect that does not exist. The demultiplexer now mirrors `parse_pes_header` in the helper exactly, and its output is byte-identical to FFmpeg's own demux of the same file. That defect also affected the analysis recorded in entry 428, which is corrected here: the fixture's video elementary stream is 185,149 bytes and its first picture spans 179,859 of them, not the 183,120 and 177,830 recorded there. The conclusion is unchanged at 97.1 percent, and the corrected total now matches the decoder's own reported `accepted_bytes` of 185,149 exactly, which the earlier figure did not.

#### Next Steps:

The 44.1 kHz helper cannot reach hardware yet. The user has directed that the official MiSTer ARM GNU 10.2 compiler be used from now on, and only the distribution's `arm-linux-gnueabihf-gcc` is present on the workstation, so no ARM binary was built or installed this cycle and the installed helper remains `3f4b272` at SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0`. Obtain that toolchain before the next helper installation. The remaining v0.7.0 work is the hardware half of the failure sweep and the long-duration audio-video soak. For the sweep, place the corpus's six bad cases on the MiSTer and require each to fail visibly and recoverably rather than wedging the core, which is the specific risk entry 425 demonstrated is real. For the soak, the acceptance target is full Big Buck Bunny playback with audio, which needs a source carrying audio; `generate_test_big_buck_bunny.py` expects `big_buck_bunny_480p_stereo.avi` beside it and does not fetch it, so the user must supply that file, and the generator must then be extended to mux MPEG Layer II audio into a Program Stream rather than emitting a silent elementary stream. That soak is the first test of audio-video drift beyond three seconds and of the startup lead on content whose first picture is small.

#### Files Modified:

- host/arm/media_player_helper.c
- tools/streams/check_media_compatibility.py
- tools/streams/generate_compatibility_corpus.sh

#### Status:

- [x] Built
- [ ] Passed

---
## 430 COMMIT Unreleased 3f4b272 2026-08-24T04:34:03-07:00

#### Coming From:

Unreleased 3f4b272

#### Purpose:

Record hardware acceptance of the helper's startup video lead and the collapse of the video startup offset.

#### Outcome:

The user power-cycled, ran `02_arm_mp2_faded_tones.mpg` with Audio Test Off and reports it working, with USER steady on, DISK steady off and POWER steady on. The schema-eight capture at SHA-256 `6daa2113e83baad9f0c9a5d90fa6b36d62e8b47243da1fda17b0bf5e3879cd26` reports `first_present_cycle` 9,307,288 at the 60 MHz decoder clock, so the first picture now presents 0.155 seconds into the session against 1.372 seconds on `047f5b2`, removing 1.217 seconds of black screen and reducing the offset by a factor of 8.8. All five pictures are displayed by 0.312 seconds. Audio follows its 2,048-sample reserve once PCM begins, so video now leads by a margin small enough to be imperceptible rather than trailing audio by a second, which is the alignment the user asked for. Every decode and audio invariant is unchanged: 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete with no presentation error, saturated PCM sample count 16,383, saturated FIFO peak of 127 or greater, no audio underrun, no PCM protocol error and zero aggregate error flags, freezing for quiet reason one with session quiet true at system-time second three. Session length rises from 3.015 to 3.224 seconds, which is expected now that the video burst precedes the PCM drain instead of being interleaved through it. The residual 0.155 seconds is transfer and decode of the 185 kilobyte payload, whose intra frame is 97 percent of it, and is no longer the real-time PCM throttle; that is the floor for this fixture rather than a defect. The ARM binary built with the undocumented `arm-linux-gnueabihf-gcc` 15.2 toolchain ran correctly, so the deviation recorded in entry 429 is proven harmless in this instance, though it remains unreproducible until the documented ARM GNU 10.2 compiler is available. `047f5b2` therefore stands as the accepted FPGA image and `3f4b272` as the accepted helper.

#### Next Steps:

Resume the deferred FPGA work: define and prove the response to a prolonged ARM producer stall after playback has begun, coordinating any pause or recovery with video presentation, and note that entry 425 established the constraint any such design must respect, since holding the PCM sink stalls the shared byte path and starves video. Housekeeping remains outstanding on the MiSTer, where `MediaPlayer.failed.d9022e6.rbf`, `MediaPlayer.reverted.62e8ccf.rbf` and the undocumented `MediaPlayer_test.rbf` are all obsolete or unaccounted for and should be removed by the user, along with the superseded helper backups. Obtain the documented ARM toolchain so helper builds become reproducible. Consider separately whether the nine-byte-per-sample in-band record format should carry multiple samples per record, since it inflates the audio roughly sevenfold against its compressed source and is the reason the shared path throttles at all; that is now a bandwidth question rather than a startup one.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---
## 429 COMMIT Unreleased 3f4b272 2026-08-24T04:30:48-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Delay the in-band audio at startup by leading video ahead of it in the helper's emission order, and revert the presentation anchor that changed nothing.

#### Outcome:

Commit `dc862e1` reverts `62e8ccf`, so the functional RTL is byte-identical to accepted `047f5b2` again, and the MiSTer was returned to that image with `/media/fat/MediaPlayer.rbf` verifying at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`; the reverted build is retained as `MediaPlayer.reverted.62e8ccf.rbf`. Commit `3f4b272` implements the delay where it can work. The helper previously emitted each decoded sample as a nine-byte in-band record the moment it existed, so PCM records preceded the video bytes behind them and throttled those bytes to real time through the FPGA's `pcm_ready` gate. It now queues decoded PCM and writes video immediately, releasing the queue once the first picture is complete, detected by counting picture start codes in the emitted video, or once a bound of four seconds of audio is buffered, whichever comes first. The bound exists only to keep the buffer finite and had to be generous: an initial one-second bound ended the lead early and left the offset unchanged, because this fixture's intra frame is 97 percent of its video payload and sits behind 69,120 samples. Releasing on the first picture rather than on a fixed delay keeps the effect to startup, so steady-state interleaving is untouched and audio is not left permanently trailing video. Local measurement on `02_arm_mp2_faded_tones.mpg` shows the PCM emitted before the first picture completes falling from 69,120 samples to zero, so the modelled video delay falls from 1.440 seconds to zero against 1.372 seconds measured on hardware, a model error of five percent. The first PCM record now appears at emitted byte 185,158, after all video. Audio should therefore begin after its 2,048-sample reserve, about 43 milliseconds in, leaving video marginally ahead rather than a second behind. Three integrity checks hold: the in-band PCM payload reconstructed from the emitted records is byte-identical to the helper's own `--pcm-out` output, so the audio is delayed and not altered; that `--pcm-out` output is byte-identical to the unmodified helper, confirming the file path is untouched and that its long-standing difference from the FFmpeg reference is pre-existing and unrelated; and an elementary stream with no audio passes through byte-identical, since the queue never engages without PCM. The ARM helper was cross-compiled, verified byte-identical after upload and installed at SHA-256 `c6ce4ef0595beee5f1f231edeaebe360160becccad22e3e51d9f8d23b9c690b0` with mode 755, its predecessor preserved as `/media/fat/linux/MediaPlayer_Helper.backup.pre-video-lead.104c5ff`. One deviation must be recorded: the documented toolchain is MiSTer Main's ARM GNU 10.2 compiler, but only `arm-linux-gnueabihf-gcc` 15.2 was available, and with no qemu on the workstation the ARM binary could not be executed before installation. It is statically linked and stripped, but it is unproven until it runs.

#### Next Steps:

Power-cycle the MiSTer, since the wedged core from `d9022e6` and the reverted `62e8ccf` are both still resident until a cold start, then run `02_arm_mp2_faded_tones.mpg` with Audio Test Off. Require video to appear essentially at once rather than 1.37 seconds late, audio to follow within about 43 milliseconds, tones to stay clean and separated with smooth fades, and LEDs to remain normal. If the helper fails to start at all, suspect the toolchain deviation first and roll back to `MediaPlayer_Helper.backup.pre-video-lead.104c5ff` before suspecting the lead logic. Capture a schema-eight snapshot over FTP and require `first_present_cycle` to collapse from 82,301,563 to a small fraction while the decode evidence holds at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags, with no audio underrun. Confirm separately that an older `.m2v` file is unaffected. Once accepted, delete `MediaPlayer.failed.d9022e6.rbf` and `MediaPlayer.reverted.62e8ccf.rbf`, obtain the documented ARM toolchain so helper builds are reproducible, and resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- host/arm/media_player_helper.c
- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_pts_presentation_timeline.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 428 COMMIT Unreleased 62e8ccf 2026-08-24T04:19:35-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Record that the presentation anchor did not move the startup offset and identify the real cause as real-time PCM pacing of the shared byte path.

#### Outcome:

The user recorded the run at 120 frames per second. Frame analysis places the blackout at 1.117 seconds and the first picture at 2.483 seconds, so the black screen lasts 1.366 seconds, and Goertzel analysis of the 440 and 660 Hz tones places audio onset near 1.50 seconds, leaving audio about one second ahead of video. A schema-eight capture of `62e8ccf` reports `first_present_cycle` 82,322,655 against 82,301,563 for `047f5b2`, a difference of 21,092 cycles or 0.35 milliseconds, so the anchor change moved nothing measurable and the hypothesis behind entry 426 was wrong. The same capture contains the evidence that should have refuted it before the build: `presentation_hold_total_cycles` is 5,728,829, only 0.095 seconds, so the timestamp admission gate was never holding pictures for anything like 1.372 seconds. The first picture was simply not available yet, and the reason is byte delivery. The helper emits each decoded PCM sample as a nine-byte in-band record, expanding 36,756 compressed audio bytes into 1,296,000 bytes and making PCM roughly 88 percent of the emitted stream, while `mpeg2_h262_inband_metadata` gates `input_ready` on `pcm_ready` and `MediaPlayer_top_00.svh` derives that from the PCM FIFO not being full. The shared byte path is therefore throttled to real-time 48 kHz sample delivery once the FIFO fills, which also explains the session lasting 180,910,349 cycles, or 3.015 seconds, for a three-second clip. The fixture makes this severe because its first picture is an intra frame spanning video elementary-stream bytes 30 through 177,860, which is 97.1 percent of all 183,120 video bytes, so almost the entire video payload must cross that throttled path before anything can be displayed. Two independent predictions confirm the mechanism. Only 2,042 audio bytes, or 8,000 samples, remain after the first picture completes, predicting 0.1667 seconds for the remaining four pictures against 0.1657 seconds measured, an error of 0.6 percent. Untimestamped `.m2v` files carry no PCM records, are never throttled, and start immediately, exactly as the user observes. This also explains why the reverted `d9022e6` deadlocked rather than merely delaying: holding the PCM sink stops the only path video bytes have.

#### Next Steps:

Do not pursue further FPGA-side changes for this offset until the emission order is fixed, because the throttle is a real-time sample rate rather than a byte volume and no reachable FIFO depth can absorb it; buffering the 2.8 seconds of PCM that precede the first picture would need roughly 4.7 megabits against 2.28 megabits of free block memory. The correct fix belongs in the ARM helper, which has ample Linux memory and full control of emission order: it should keep video bytes ahead of PCM records rather than emitting each sample as soon as it is decoded, holding only enough PCM in flight to keep the FPGA's 2,048-sample reserve fed. That is a host-side change costing no FPGA logic or timing, consistent with the user's instruction not to spend either on this offset. Decide separately whether to keep or revert `62e8ccf`, which costs 35 ALMs, changed nothing measurable on this fixture, and is defensible only as a correctness improvement for streams whose first metadata timestamp differs from their first picture timestamp. Consider also reducing the nine-byte-per-sample in-band record format, which inflates the stream roughly sevenfold against the compressed audio it replaces, though that is a bandwidth question and not the cause of this offset.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 427 COMMIT Unreleased 62e8ccf 2026-08-24T04:07:06-07:00

#### Coming From:

Unreleased 62e8ccf

#### Purpose:

Install the first-picture presentation anchor through staged, hash-verified replacement while preserving exact rollback state.

#### Outcome:

Installation used the FTP path with download-and-hash round trips in place of on-device hashing. Before installation `/media/fat/MediaPlayer.rbf` verified at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the accepted `047f5b2` restored after the `d9022e6` rollback, and both the staging and rollback names for this cycle were absent. The new RBF was uploaded as `MediaPlayer.upload.62e8ccf.rbf`, downloaded back and confirmed byte-identical to the local build, after which the displaced file was renamed to its rollback name and the staged file renamed into place. `/media/fat/MediaPlayer.rbf` now verifies at SHA-256 `74913cd13a7ecaa3748461da755041b32f47c61e9b3ec64643f7ae15e28c4336` and its predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-anchor.047f5b2.rbf`. The helper remains at `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a`. The failed `d9022e6` image remains set aside as `/media/fat/MediaPlayer.failed.d9022e6.rbf` and should be deleted once this cycle is accepted. No playback was launched and no `sync` could be issued, so the currently loaded core remains the prior in-memory RBF until reboot and the writes depend on the server flushing before the next power cycle.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require that video now starts immediately rather than 1.372 seconds late, that audio and video begin together, that the tones stay clean and separated with smooth fades, and that USER is steady on, DISK steady off and POWER steady on; then leave the completed image loaded for a schema-eight capture triggered over FTP. That capture must show `first_present_cycle` collapse from 82,301,563 to a small fraction of it while the accepted decode evidence is unchanged at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file still behaves exactly as before, since it never anchors the timeline. If any residual offset remains it is now the PCM startup reserve fill rather than the presentation gate, and should be measured before being treated as a defect.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 426 COMMIT Unreleased 62e8ccf 2026-08-24T04:06:21-07:00

#### Coming From:

Unreleased 4220cdc

#### Purpose:

Remove the video startup offset at its source by anchoring the presentation timeline to the first picture rather than the first metadata record.

#### Outcome:

`mpeg2_h262_pts_presentation_timeline` anchored `stc_90k` to the first in-band metadata timestamp, so the origin became whatever timestamp appeared first in the multiplex and any first picture whose own timestamp sat ahead of that origin waited the difference before the scheduler could admit it. Hardware telemetry measured that wait directly on `047f5b2` as `first_present_cycle` 82,301,563 at the 60 MHz decoder clock, or 1.372 seconds of black screen while ungated audio played. Commit `62e8ccf` anchors on the first candidate instead, taking `candidate_pts` as the origin, which makes the first picture due at once and leaves every later interval unchanged because intervals are differences in which the origin cancels. The `metadata_valid` and `metadata_pts` ports are removed; the in-band timestamp still feeds the association module that produces `candidate_pts`, so nothing upstream is pruned. This replaces the reverted audio-delay approach of `d9022e6`, which deadlocked, and costs roughly a mux and a condition rather than the buffer that approach would have required. The blast radius was checked before building rather than after: `anchored` and `stc_90k` are driven at `MediaPlayer_top_05.svh` and consumed nowhere else, so the only outputs reaching logic are `candidate_active` and `candidate_due` into the scheduler's admission gate, and because the timeline is a pure input to an admission decision with no back-pressure anywhere in its path it cannot create the circular stall that wedged `d9022e6`. A stream without timestamps never presents a valid candidate, never anchors and keeps the scheduler's free-running cadence exactly as before. The rewritten `tb_h262_pts_presentation_timeline` passes with the first candidate placed at 123,480 ticks, the measured hardware offset, requiring it to be due immediately and requiring the following picture to still wait its full 3,003 ticks; modulo two-to-the-33 wrap, late timestamps, individually missing timestamps and seek re-anchoring all still hold. The full eight-testbench parser and presentation regression is byte-identical to the accepted `047f5b2` baseline. The build completed in 9 minutes 28 seconds with zero errors and 257 warnings and uses 29,056 ALMs at 69 percent, 44,565 registers, 3,379,667 memory bits, 429 RAM blocks and 65 DSP blocks, a cost of 35 ALMs over `047f5b2` with 57 fewer registers where the metadata anchor path was removed. Worst-case setup slack recovers to 0.681 nanoseconds on `pll_hdmi` against 0.162 on `d9022e6` and 0.500 on `047f5b2`, with total negative slack of zero on every clock, which confirms that the tight path on the previous build was fitter placement variance in HDMI output logic rather than a consequence of either change.

#### Next Steps:

Install the resulting RBF at SHA-256 `74913cd13a7ecaa3748461da755041b32f47c61e9b3ec64643f7ae15e28c4336` and run `02_arm_mp2_faded_tones.mpg` with Audio Test Off, requiring that video now starts immediately instead of 1.372 seconds late, that audio and video begin together, that the tones stay clean and separated with smooth fades and that LEDs remain normal. Capture a schema-eight snapshot by writing a screenshot command to `/dev/MiSTer_cmd` over FTP and require `first_present_cycle` to fall to a small fraction of its previous 82,301,563 while the accepted decode evidence is unchanged at 185,149 elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file is unaffected. Any residual audio-ahead-of-video offset is now the PCM startup reserve fill time rather than the presentation gate, and should be measured before it is treated as a defect. Once accepted, resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- MediaPlayer_top_05.svh
- rtl/mpeg2_new/mpeg2_h262_pts_presentation_timeline.sv
- tools/streams/tb_h262_pts_presentation_timeline.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 425 COMMIT Unreleased 4220cdc 2026-08-24T03:45:41-07:00

#### Coming From:

Unreleased d9022e6

#### Purpose:

Record the hardware failure of the audio start gate, its root cause, and the rollback and revert that restore the accepted state.

#### Outcome:

Running `02_arm_mp2_faded_tones.mpg` on `d9022e6` hung the machine: the user reported a black screen with a short code in the corner and no playback. A screenshot command written to `/dev/MiSTer_cmd` over FTP was accepted but produced no file while ordinary FTP directory listing still worked, so MiSTer Main was wedged rather than Linux, and no schema-eight telemetry could be taken. Static tracing identifies a deadlock that the approved approach makes unavoidable in the current architecture, and the error is in the premise rather than in the implementation. The gate assumed audio and video are independently gated, but they share one back-pressured byte path. `MediaPlayer_top_00.svh` assigns `audio_pcm_ready` from `!audio_pcm_fifo_full` and forwards it to `mpeg2_new_inband_pcm_ready`, while `mpeg2_h262_inband_metadata.sv` includes `(!pcm_payload_final || pcm_ready)` in its `input_ready` term, so the in-band extractor stops accepting bytes from the HPS stream whenever the PCM sink is full. Holding the PCM output therefore fills the FIFO, deasserts `pcm_ready`, stalls the shared byte path, starves the video elementary stream, prevents any picture from decoding or presenting, and so prevents `video_started` from ever asserting, which holds the PCM output. The five-second bound does eventually release audio, but only after the decoder has been byte-starved for five seconds, by which point the core and Main are wedged. `tb_audio_pcm_output_adapter` could not have caught this because it drives the FIFO directly with no in-band extractor and no shared stream in the loop, so the adapter is correct in isolation and wrong in place. The MiSTer was rolled back over FTP: the failed image is retained as `/media/fat/MediaPlayer.failed.d9022e6.rbf`, and `/media/fat/MediaPlayer.rbf` verifies once more at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, the accepted `047f5b2`. Commit `4220cdc` reverts both `946e81f` and `d9022e6` so that master's functional RTL is byte-identical to `047f5b2` again, retaining only the correction to the stale comment in `MediaPlayer_top_00.svh` that wrongly described presentation as free-running.

#### Next Steps:

The approved audio-delay approach cannot be implemented on the FPGA side without a buffer large enough to absorb the offset, because any hold on the PCM sink stalls video through the shared path; at 48 kHz stereo the measured 1.372-second offset is roughly 2.3 megabits in the current 35-bit sample format against about 2.28 megabits of free block memory, so it does not fit. Two viable directions remain and the user must choose before any further change. The first is to move the delay into the ARM helper, which has ample Linux memory and controls the byte stream directly, withholding PCM records for a lead while continuing to emit video bytes so the shared path never stalls. The second, and the cheaper and more standard of the two, is to remove the offset at its source: `mpeg2_h262_pts_presentation_timeline` anchors `stc_90k` to the first in-band metadata timestamp, so a picture whose own timestamp sits ahead of that anchor waits the difference, and anchoring instead to the first picture candidate would present the first picture immediately while preserving every subsequent interval, at a cost of roughly a mux and a condition rather than the logic and timing the user declined to spend. Take no further hardware action until that choice is made; the MiSTer needs a power cycle to load the restored `047f5b2`.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 424 COMMIT Unreleased d9022e6 2026-08-24T03:38:48-07:00

#### Coming From:

Unreleased d9022e6

#### Purpose:

Install the audio start gate through staged, hash-verified replacement while preserving exact rollback state.

#### Outcome:

Installation again used the FTP path with download-and-hash round trips in place of on-device hashing, since key-based SSH is still rejected. Before installation `/media/fat/MediaPlayer.rbf` verified at SHA-256 `2f47c3e61b0892667fbf92e731f6cb2464267243aa5a9b726000f66fde5a2e68`, matching accepted `047f5b2`, and both the staging and rollback names were absent. The new RBF was uploaded as `MediaPlayer.upload.d9022e6.rbf`, downloaded back and confirmed byte-identical to the local build at SHA-256 `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5`, after which the displaced file was renamed to its rollback name and the staged file renamed into place. `/media/fat/MediaPlayer.rbf` now verifies at `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5` and its predecessor is preserved byte-identically as `/media/fat/MediaPlayer.backup.pre-audio-gate.047f5b2.rbf`. The helper remains at `12f6305f35ef56d4e8de2369ecd41d2811bda9d787c885991a5ed0272cd2678a` and the faded fixture at `cb4f143d2d72af72bb03c7a7fbc4e2163ad780a35483bdb871ec661cf29ccc24`, both byte-identical. No playback was launched, so the currently loaded core remains the prior in-memory RBF until reboot. As in the previous installation no `sync` could be issued, so the writes depend on the server flushing before the next power cycle.

#### Next Steps:

Reboot the MiSTer once, enter MediaPlayer with Audio Test Off and run only `02_arm_mp2_faded_tones.mpg`. Require that audio and video now begin together rather than audio leading by roughly 1.4 seconds, that the tones stay clean and separated with smooth fades, that USER is steady on, DISK steady off and POWER steady on, and that no video artefact appears; then leave the completed image loaded so a schema-eight capture can be taken by writing a screenshot command to `/dev/MiSTer_cmd` over FTP. That capture must still report 185,149 accepted elementary-stream bytes, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete and zero aggregate error flags, and its `first_present_cycle` should be close to the 82,301,563 recorded for `047f5b2` since video timing is deliberately unchanged. Separately confirm an older `.m2v` file still starts immediately. Treat any video artefact as a candidate for a fitter seed retune before treating it as a functional defect, because `pll_hdmi` slack is 0.162 nanoseconds this build.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 423 COMMIT Unreleased d9022e6 2026-08-24T03:19:14-07:00

#### Coming From:

Unreleased 047f5b2

#### Purpose:

Hold the PCM output until the first picture is presented so audio and video begin together on timestamped streams.

#### Outcome:

Audio began as soon as the startup reserve filled while video waited for the PTS-gated presentation timeline, so on a Program Stream audio led video by the first picture's timestamp offset. Rather than force video to present early, which would mean altering the presentation gate Entry 389 established and spending logic and timing margin on a path the user has accepted as correct, this cycle delays the audio instead. `MediaPlayer_top_05.svh` gains a decoder-domain sticky flag that sets on the first genuine display swap, detected from a change in the scheduler's `display_frame_bank`, `display_scratch` or `display_scratch_bank` outputs exactly as the cadence profiler detects one, but derived independently so that gating the profiler out later cannot silently remove it. That single bit crosses into `CLK_AUDIO` through a two-flop synchronizer in `MediaPlayer_top_00.svh`, consistent with the existing rule that only single bits cross between the decoder and audio domains. `audio_pcm_output_adapter` gains a `video_started` input qualifying only its initial transition out of idle, so mid-stream starvation, the accepted-end release for short clips and the audio-tail completion are unchanged. Holding audio cannot stall what video waits on, because the System Time Clock is a free-running accumulator on `CLK_AUDIO` whose `run` input is tied high and which therefore advances regardless of PCM consumption. Restoring telemetry proved decisive for sizing the bounded wait that prevents permanent silence when video never presents. Key-based SSH remains rejected, but `/dev/MiSTer_cmd` is writable over FTP, so uploading a one-line command file to it triggers a screenshot with no shell at all; the decoded schema-eight snapshot of the accepted `047f5b2` image reports 185,149 accepted elementary-stream bytes, one associated timestamp, three reference plus two B pictures, five displays, four swaps, sequence end, presentation complete, saturated PCM sample count 16,383, saturated FIFO peak 127, no underrun, no PCM protocol error, zero aggregate error flags and a quiet reason-one freeze with session quiet true. It also reports `first_present_cycle` 82,301,563 at the 60 MHz decoder clock, placing the first picture 1.372 seconds into the session and measuring the reported delay directly. The initial two-second bound was therefore only 0.63 seconds clear of a real video start and its 26-bit parameter capped at 2.73 seconds, so a file with a larger timestamp offset would have hit the timeout and silently restored the very lead the gate removes; commit `d9022e6` widens the parameter to 27 bits and sets the bound to five seconds, which bounds silence without ever approaching a legitimate presentation. All six `tb_audio_pcm_output_adapter` cases pass, including the four predating the gate, which confirms the accepted paths are unchanged. The build completed in 9 minutes 31 seconds with zero errors and uses 29,188 ALMs at 70 percent, 44,885 registers, 3,379,667 memory bits, 429 RAM blocks and 65 DSP blocks, a cost of 167 ALMs over `047f5b2` for a flag, a synchronizer and one counter. Worst-case setup slack falls to 0.162 nanoseconds on the 152.21 MHz `pll_hdmi` domain with total negative slack of zero, while the decoder domain improves from 1.562 to 1.938 nanoseconds and every other domain holds at or above 1.6; the tightened path is in HDMI output logic this cycle does not touch, so it is fitter placement variance rather than a consequence of the change, but it is thinner than the 0.476 and 0.500 of the two preceding accepted builds and should be watched.

#### Next Steps:

Install the resulting RBF at SHA-256 `b0f3a3125bf803dfaed0924b543760a45f439288b18b742cebbd4816c7b342f5` and run `02_arm_mp2_faded_tones.mpg` with Audio Test Off, requiring that audio and video now begin together rather than audio leading by roughly 1.4 seconds, that the tones stay clean and separated with smooth fades, that LEDs remain normal and that a schema-eight capture still reports five displays, four swaps, sequence end, presentation complete and zero error flags. Confirm separately that an older `.m2v` file still starts immediately, since it carries no timestamps and no audio for the gate to wait on, and that its video is not held by the bounded wait. If any video artefact appears, retune the fitter seed before treating it as a functional defect, because the `pll_hdmi` margin is the thinnest of the recent accepted builds. Once accepted, resume the deferred prolonged ARM producer stall work.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- rtl/audio/audio_pcm_output_adapter.sv
- tools/streams/tb_audio_pcm_output_adapter.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 422 COMMIT Unreleased 047f5b2 2026-08-24T03:19:13-07:00

#### Coming From:

Unreleased 047f5b2

#### Purpose:

Record the hardware acceptance of the block-memory row buffers and the audio-leads-video startup offset it exposed.

#### Outcome:

The user rebooted with Audio Test Off, ran `02_arm_mp2_faded_tones.mpg` and reported that it works well, with audio sounding fine and starting correctly, USER steady on, DISK steady off and POWER steady on. The 7,082-ALM recovery in `047f5b2` therefore carries no audible or visible decode regression and the block-memory conversion is hardware-accepted. The run did expose a startup offset that the user states is new: video now begins one to two seconds after audio on the Program Stream, while older elementary-stream `.m2v` files still start their video immediately. No schema-eight snapshot could be captured because triggering a screenshot writes to `/dev/MiSTer_cmd` over SSH and key authentication to the MiSTer is failing, so this acceptance rests on the user's direct observation and the LED states rather than on decoded telemetry. Static tracing locates the mechanism in the presentation gate rather than in the parser: `mpeg2_h262_b_presentation_scheduler` selects `timestamp_candidate_due` in place of the free-running cadence slot whenever a picture owns a timestamp, and `mpeg2_h262_pts_presentation_timeline` drives that gate from a decoder-domain timeline anchored once by the first in-band timestamp and advanced by the 90 kHz tick synchronized out of `CLK_AUDIO`. An elementary stream carries no timestamps, so its pictures present on cadence with no wait, while a Program Stream holds each picture until the timeline reaches its presentation time. Audio is not gated at all, so it begins as soon as the startup reserve fills and leads video by the first picture's timestamp offset. A stale comment in `MediaPlayer_top_00.svh` still states that nothing consumes the presentation clock and that presentation remains free-running; that was true at Entry 389 but the timeline module is now wired in at `MediaPlayer_top_05.svh` and the comment should not be trusted. The user has decided that the video delay itself is acceptable and must not be closed at the cost of logic or timing, and that audio should instead be held back to match it.

#### Next Steps:

Hold the PCM output adapter's initial start until the presentation side has actually displayed its first picture, so audio and video begin together without touching the parser, the presentation gate or the timeline. Restore key-based SSH access to the MiSTer so that screenshot triggering, on-device hash verification and `sync` become available again, since without a shell no schema-eight telemetry can be decoded and every install depends on the FTP fallback flushing on its own. Correct the stale free-running presentation comment in `MediaPlayer_top_00.svh` when the next change touches that file.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---