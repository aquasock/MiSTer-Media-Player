## 528 COMMIT Unreleased ??? 2026-08-26T01:36:57-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Expose and correct any native line-cache registered-address or byte-lane alignment defect hidden by the constant-data regression stimulus.

#### Outcome:

The user approved entry 527's bounded cache-read alignment cycle after schema sixteen proved correct row, bank and generation provenance but saturated content mismatches in both fields. This proposal changes no behavior speculatively: the first gate replaces the cache test's identical DDR words with deterministic position-varying words containing distinct bytes in all eight lanes while preserving the implemented registered M10K read-address model, four-read-clock pixel cadence, TFF and BFF field order, frame wrap and ordinary refill timing. Only if that test reproduces an exact raw-versus-displayed position mismatch will the same commit correct the proven pipeline alignment and require bit-exact 720-byte line comparisons; if it does not reproduce, work stops before RTL changes and the next proposal becomes a lane-resolved schema-seventeen diagnostic.

#### Next Steps:

Synchronize the designated GUNSMOKE checkout from the authoritative master branch, implement and run the position-varying native cache regression there, and inspect the first failing word and lane. If the existing RTL fails deterministically, make the smallest registered-read-address and byte-lane correction supported by that evidence, rerun the focused TFF and BFF cache controls followed by the complete native, reconstruction and canonical mixed-I/P/B live-raster suites, commit the source on the Raspberry Pi, synchronize GUNSMOKE to the exact source hash and perform an incremental Quartus Prime 17.0.2 build with timing, resource and netlist checks. Preserve schema sixteen unchanged for the hardware acceptance run and directly replace only `/media/fat/MediaPlayer.rbf` after a verified build, without creating backup, rollback or staging files.

#### Files Modified:

- rtl/mpeg2_luma_framebuffer.sv
- tools/streams/tb_native_480i_cache_refill.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 527 COMMIT Unreleased 98ee2dc 2026-08-26T01:20:30-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Resolve the schema-sixteen hardware result and distinguish wrong native cache-line provenance from corruption of correctly tagged cache bytes.

#### Outcome:

The user reloaded the exact `98ee2dc` image and, after stopping one false start made with the wrong media, ran `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while the corrected burst deleted the fixed remote screenshot before every trigger. The thirty-second burst retrieved ninety-three fresh PNGs: fourteen byte-identical pre-playback frames, thirty distinct live frames numbered fourteen through forty-three and forty-nine byte-identical terminal frames. The fixture authors a thirty-two-pixel bar that advances four pixels per source field and alternating upper and lower field markers. At representative active rows 200 and 201, frames fourteen through thirty-three contain no bright first-parity bar while the other parity advances around the screen. In frame thirty-four the missing parity appears at x=360 through x=391 and remains fixed there through frame forty-three, while the other parity continues from x=357 through x=516 with a wrap during the interval. The live images therefore preserve both observed failure forms in one run: a missing field followed by one stale field bar, split moving edges and many horizontal comb-like fragments. The user's initial impression that playback might have been smoother was explicitly withdrawn as uncertain because of the time since the prior run, so no performance change is claimed for this passive diagnostic image. Schema sixteen accepts all 5,007,304 source bytes and its wrapped counters represent 300 reference and displayed pictures and 299 swaps. The 299 presentation intervals span 599,534,823 cycles, 9.992247 seconds or 29.923 pictures per second. The session reaches sequence end, presentation completion and normal quiet reason one with every aggregate, cache-overlap, prefill, region and phase error clear; it records 300 framebuffer resets, 299 publications and 242/240 terminal-generation field fetches. Both per-field content-mismatch counters saturate at 255 while both tag-mismatch counters remain exactly zero. The first mismatch for the authored first field expects and carries row two, bank one and generation one; the other field likewise expects and carries row three, bank one and generation one. Both first mismatches compare raw fingerprint `001fffe0` with displayed-cache fingerprint `001fffc0`, an XOR difference of exactly `00000020`. The terminal first-field raw/display pair is `f964952b`/`e855bf21` and the second-field pair is `8c26df67`/`ab1ec443`. Correct row, bank and generation tags with independently wrong bytes on at least 255 lines of each parity rule out refill ownership and source-row selection and place the defect in cache RAM write, registered read-address or byte-lane alignment. The selected evidence is `.ai/current_results/entry527_schema16_live_missing_field.png` at 9,790 bytes with SHA-256 `0447f759660eb50926fb97d56d6e9bc446f0b92716b7a83027e2631f32530869`, `.ai/current_results/entry527_schema16_live_field_appears.png` at 11,836 bytes with SHA-256 `74528360d21de793e95505301abc725c6fe2834ae05e7d0b6cd1e42a2fd936f1`, `.ai/current_results/entry527_schema16_live_stale_split.png` at 11,297 bytes with SHA-256 `0805c00621d72e25e48bfccfe2ab4bf4e71326e52c9425c77c9dd06d51180357` and `.ai/current_results/entry527_schema16_terminal.png` at 12,691 bytes with SHA-256 `9064b4493e439cfd76cc58ebf5603da16317c6da2e082f251f52f9949df7460c`. Source review also exposes a regression blind spot: the ordinary cache test returns the same 64-bit value for every word, so its realistic registered-address model cannot reveal a word-position or byte-lane shift except for the separately injected bit. The implementation uses a clock-registered M10K read address and a separately delayed byte-lane selector, making a position-varying timing regression the next evidence boundary before another hardware-only schema.

#### Next Steps:

Stop before changing behavior and obtain approval for one bounded cache-read alignment cycle. On the designated GUNSMOKE checkout, strengthen the native cache regression with distinct bytes in every lane and position-varying 64-bit words while retaining the real four-read-clock pixel cadence, TFF and BFF field order, wrap and refill timing. Require the current RTL either to reproduce a raw-versus-displayed mismatch at an exact word/lane boundary or to pass bit-exactly. If it reproduces, correct only the proven registered-read-address and byte-lane pipeline alignment, require all 720 bytes of every line to compare exactly, rerun the complete native, reconstruction and canonical live-raster suites, then perform an incremental Quartus build and use unchanged schema sixteen for hardware acceptance. If the stronger regression does not reproduce the hardware signature, stop without a behavioral change and propose schema seventeen with per-byte-lane raw/display fingerprints. Continue direct verified replacement of only `/media/fat/MediaPlayer.rbf` with no backup, rollback or staging files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 526 COMMIT Unreleased 98ee2dc 2026-08-26T00:56:34-07:00

#### Coming From:

Unreleased 98ee2dc

#### Purpose:

Install and verify the exact schema-sixteen image without creating any backup, rollback or staging file.

#### Outcome:

The exact 4,239,056-byte `98ee2dc` RBF was copied from the designated GUNSMOKE checkout to the Raspberry Pi and independently retained SHA-256 `ef78d18bb5f8fe974e1b132df73305878e1da99fd72f602a28c223fb295c8825`. Two initial `curl` uploads were rejected with FTP status 550 and changed nothing because curl interpreted the URL relative to the server login directory `/root`; the established Python `ftplib` absolute-path operation then wrote directly to `/media/fat/MediaPlayer.rbf` with no intermediate remote filename. An initial curl readback likewise fetched the unrelated historical `/root/MediaPlayer.rbf`, which exposed the path interpretation rather than an installation failure. Absolute-path `ftplib` readback of `/media/fat/MediaPlayer.rbf` returns exactly 4,239,056 bytes at the candidate hash and compares byte-identically with the local build. No backup, rollback or staging file was created or modified.

#### Next Steps:

Reload the Media Player core, prepare `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i and reply ready. Start playback immediately when prompted while a corrected thirty-second burst deletes the prior screenshot before every trigger, then leave the terminal image loaded for absolute-path schema-sixteen capture and decoding. Report whether the first-field bar remains frozen and whether the grey line fragments remain visible.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 525 COMMIT Unreleased 98ee2dc 2026-08-25T23:27:33-07:00

#### Coming From:

Unreleased 4e4db95

#### Purpose:

Distinguish incorrect native line-cache provenance from corruption of correctly selected cache content.

#### Outcome:

Commit `98ee2dc` implements schema sixteen without changing cache control or presentation behavior. Every completed native luma fill now publishes a stable per-bank raw fingerprint, physical row, bank and eight-bit framebuffer generation tag across a bundled-data toggle handshake; the video side latches the selected tag, fingerprints all seven hundred twenty returned cache bytes and reports mutually exclusive tag or content mismatch evidence per line. The profiler preserves the first tag and content mismatch separately for each authored field, adds four saturating mismatch counters, advances the overlay to sixty-one words and retains schema fifteen through legacy decoding. The initial clean TFF line test exposed a diagnostic-only startup gap in which the delayed publication qualifier omitted pixel zero of the first displayed line and left its tag at reset generation zero; the same source commit corrects that qualifier and all four directed controls then pass, with TFF and BFF equality, one injected byte producing content-only mismatch and a forced wrong bank producing tag-only mismatch. The complete native suite passes its established field-order, mapping, timing, presentation, refill, profiler and decoder gates; TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, field-DCT rejection remains at 82,326 cycles and the canonical seventy-two-picture mixed I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B pictures, seventy-one swaps and every error clear. A from-scratch Quartus Prime 17.0.2 build completes in ten minutes fifty seconds with zero errors and 143 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.352, 0.245, 4.056, 0.590 and 0.925 nanoseconds with zero endpoint negative slack; focused decoder setup and recovery are positive 1.509 and 10.903 nanoseconds and focused video setup is positive 3.328 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains, and timing-netlist probes find every sampled schema-sixteen generation, synchronized tag, provenance toggle, mismatch counter, metadata and fingerprint register group. The fit uses 30,748 ALMs, 48,766 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,239,056-byte RBF has SHA-256 `ef78d18bb5f8fe974e1b132df73305878e1da99fd72f602a28c223fb295c8825`.

#### Next Steps:

Copy the exact `98ee2dc` RBF to the Raspberry Pi, directly replace only `/media/fat/MediaPlayer.rbf` on the MiSTer without creating backup, rollback or staging files and verify the active image by readback. Reload the core, prepare `_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i, then acquire a corrected fresh screenshot burst during playback and decode schema sixteen from the same run. A tag mismatch identifies wrong refill ownership, row, bank or generation; matching tags with a content mismatch identifies cache RAM write, address or byte-lane read corruption. Preserve generated Quartus state and use incremental builds for future cycles as directed by the user.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `MediaPlayer.sdc`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_interlaced_420_cache_mapping.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 524 COMMIT Unreleased 4e4db95 2026-08-25T21:43:10-07:00

#### Coming From:

Unreleased 4e4db95

#### Purpose:

Resolve the schema-fifteen hardware result and identify which side of the raw-DDR-to-displayed-cache boundary loses field content.

#### Outcome:

The user reloaded the directly installed `4e4db95` image and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while an agent-triggered burst sampled the live raster. The first burst retrieved the same pre-existing terminal PNG fifty-four times because its quarter-second settle interval allowed the fixed remote filename to be fetched before the new screenshot replaced it; deleting that exact remote screenshot before each subsequent trigger made stale reuse impossible. The corrected thirty-second burst returned twenty-five fresh screenshots, the first eight distinct and live and the final seventeen one byte-identical quiet snapshot. Across all eight live frames the authored first field is cleanly frozen at x=72 through x=103 for the complete 176-row bar, while the other field advances through x positions 424, 48, 360, 648, 272, 584, 208 and 496; the user independently confirms the screen behaved as before with one bar stuck on the left and the other moving right. Schema fifteen from the same run accepts all 5,007,304 bytes, records 299 framebuffer resets and publications, sequence end, presentation completion and quiet reason one, and keeps every aggregate, cache-overlap, prefill, region and phase error clear. The final generation retains 242 first-field and 240 second-field fetches. Its completed first-field raw and displayed fingerprints are respectively `f964952b` and `e855bf31`, while the second-field pair is `8c26df67` and `ab1ec443`; both completion counters and both mismatch counters saturate at 255, proving at least 255 independently completed mismatches for each parity rather than a terminal-only anomaly. The raw DDR-return byte stream therefore does not survive the line-cache write and post-cache readout boundary in either field, while the gross visual retention remains asymmetric to the first field. This passes the schema-fifteen diagnostic objective and localizes the fault inside cache population, bank ownership, address selection or readout rather than the decoder, DDR region, native raster, final mux or processed-HDMI capture path. Evidence is `.ai/current_results/entry524_stale_first_field_live_early.png` at 11,113 bytes with SHA-256 `2131b1178899856a454a033721c11143c822160259219d6e1e23a44a3624a000`, `.ai/current_results/entry524_stale_first_field_live_late.png` at 11,120 bytes with SHA-256 `d254713100fad7b6a8a410e0d0f0e625e797d7c7c2cec8bc85e298571d239d88` and `.ai/current_results/entry524_schema15_terminal.png` at 12,484 bytes with SHA-256 `b4b78e8d4415f66de5fbc6f6be3795e410ed2e96ad4b95454239fee948157e62`.

#### Next Steps:

Stop before changing behavior and obtain approval for one schema-sixteen cache-provenance boundary. At completion of each luma-line fill, retain the raw line fingerprint, physical source row, cache bank and framebuffer generation; synchronize only completed stable per-bank tags to the video domain, latch the applicable tag before each displayed line begins and compare its expected row and raw line fingerprint with the post-cache bytes completed at that line's end. Preserve the first tag mismatch and first content mismatch separately for each authored field and count each class without feeding cache control. Directed simulation must prove correct TFF and BFF tag/content matches, a wrong-bank tag failure and a one-byte cache-content failure, while the full native, reconstruction and canonical live-raster suites remain exact. A hardware tag mismatch would identify refill ownership or bank selection, while matching tags with differing content would isolate the dual-clock RAM write, word address or byte-lane read pipeline. Continue direct verified replacement of only `/media/fat/MediaPlayer.rbf` with no backup, rollback or staging files.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 523 COMMIT Unreleased 4e4db95 2026-08-25T20:41:57-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Correlate each symptom-bearing generation's complete DDR-return luma content with the luma actually read from the line cache for display.

#### Outcome:

The pre-change thirty-second burst acquired forty-nine screenshots at approximately 1.6 frames per second, with seventeen distinct live frames followed by thirty-two byte-identical terminal frames. Both field bars advance during the live interval but are commonly separated by roughly twenty-four pixels rather than the authored four-pixel weave offset, and short horizontal grey edge fragments accompany one field, proving a field-age mismatch rather than one field remaining constant for the entire session. Commit `4e4db95` adds a passive position-sensitive thirty-two-bit fingerprint over all eight bytes of every native luma DDR return and the same byte sequence read from the post-cache display path, separated by authored field and framebuffer generation. Completed video-domain fingerprints cross as stable bundled data behind a three-stage toggle synchronizer, only the source-to-first-stage paths are cut, and the memory domain publishes raw, displayed and mismatch evidence without feeding cache, decoder, scheduler or presentation control. Cadence schema fifteen expands to forty-eight words at diagnostic and native origins 408 and 288, preserves words zero through forty-one, records the four most recent fingerprints and four saturating completion or mismatch counts, retains schema fourteen through legacy decoding, checks every overlay row and independently guards the packed count width. Directed TFF and BFF cache runs each produce two matching completions, an intentionally corrupted cache byte produces exactly one mismatch, and the complete native suite, interlaced reconstruction suite and canonical mixed I/P/B live-raster suite pass, the latter retaining exactly 6,529,997 cycles, twenty-five publications, forty-seven B-picture persistences, seventy-one swaps and no errors. A clean Quartus Prime 17.0.2 build from empty generated state completes in eleven minutes four seconds with zero errors and 143 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.172, 0.245, 3.999, 0.591 and 0.925 nanoseconds with zero endpoint negative slack; focused decoder setup and recovery are positive 1.311 and 11.527 nanoseconds and focused video setup is positive 2.987 nanoseconds, all with zero violated paths. Only the established unmatched `RESET` filter remains, and a timing-netlist probe finds every new raw, displayed and mismatch register. The fit uses 30,027 ALMs, 46,948 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,207,656-byte RBF has SHA-256 `f53a686f0775b6bf1fce6be14669c2fe9761e2f6edcdcd5fd4d972b744711b93` and was written directly to `/media/fat/MediaPlayer.rbf`; an immediate ordinary-FTP readback matches its size and hash exactly. At the user's direction, all twenty `MediaPlayer.backup.*` and `MediaPlayer.rbf.rollback*` files were deleted from the MiSTer, the prior active file was not disturbed during that cleanup, and future installations will directly replace and verify the active file without creating backup, rollback or staging copies.

#### Next Steps:

Reload the installed `4e4db95` image, run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i while an agent-triggered thirty-second screenshot burst captures the live fault, then decode schema fifteen from that same run. A raw-versus-displayed mismatch localizes corruption to the line-cache write or readout boundary; equality while the field-age mismatch is visible moves the investigation after the cache output. Record the hardware result in a new entry because this source and build boundary is now settled, and continue replacing the active RBF directly without creating backup, rollback or staging files.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `MediaPlayer.sdc`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_interlaced_420_cache_mapping.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 522 COMMIT Unreleased bfb9361 2026-08-25T20:39:25-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Interpret the first schema-fourteen hardware result and define the next evidence boundary without mistaking session-wide variation for generation-correlated correctness.

#### Outcome:

After reloading the installed `bfb9361` image, the user ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` and reports that what appeared to be the second field was duplicated, with the established ghosting and tiny horizontal grey lines still visible during playback. The terminal screenshot `.ai/current_results/entry522_schema14_terminal.png` was triggered and retrieved through ordinary authenticated FTP at 12,278 bytes and SHA-256 `7803856948fb73b61b332a0525fbf89289ef90b3dd0c41d4dbec63567ce5cfc2`. Schema fourteen accepts all 5,007,304 source bytes and its wrapped counters reconstruct 300 reference and displayed pictures with 299 swaps across 599,290,215 cycles, or 29.935413 pictures per second. Sequence end, presentation completion and quiet reason one are present; all error flags are clear. The framebuffer reports 300 generation resets, 299 publications, zero unpublished resets, zero prefill misses, a 2,002,004-cycle maximum publication latency, 242 first-field and 240 second-field fetches in the terminal generation, region one for both fields, zero region mismatches and zero phase errors. Both session-wide varied flags are set and the first-field and second-field signatures are respectively `0x37` and `0x03`. This disproves only a parity returning one constant sampled byte for the entire session. Entries 520 and 521 stated the stronger inference too broadly: the current signature XORs only byte lane zero of each returned sixty-four-bit word and aggregates all generations, so activity outside the symptom-bearing interval can set varied and a terminal snapshot cannot prove that the correct position-dependent field content arrived during the duplicated or ghosted frame. The result therefore passes the schema-fourteen diagnostic objective but does not yet place the loss definitively on either side of the DDR return; it narrows the required correlation to the raw-return, line-cache write and displayed-cache-read boundary.

#### Next Steps:

Do not make a behavioral correction from the coarse signatures. Prepare a bounded schema-fifteen diagnostic that computes generation-correlated, position-sensitive luma fingerprints over all eight bytes of every raw DDR return and over the corresponding post-cache displayed luma samples for each field parity, transfers only completed stable fingerprints across the video-to-decoder clock boundary and counts raw-versus-displayed mismatches without feeding control logic. Retain the established fetch, region, phase, publication and error evidence, add directed tests that prove matching TFF and BFF fields compare equal and an intentionally corrupted cache word compares unequal, preserve schema-fourteen through legacy decoding and run the complete native, reconstruction and live-raster suites before any clean build. If timing closes, repeat the same fixture while an agent-triggered live screenshot burst captures the visible duplication and read the correlated fingerprints from that same run; a mismatch localizes the defect to cache write/readout, while equality moves the search after the cache output.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 521 COMMIT Unreleased bfb9361 2026-08-25T20:30:53-07:00

#### Coming From:

Unreleased bfb9361

#### Purpose:

Correct the deployment-path diagnosis and install the verified schema-fourteen candidate rollback-safe.

#### Outcome:

Entry 520's reported active-image mismatch came from using a relative FTP URL with curl's single-directory method, which resolved a different server object containing the user-identified bad compile rather than the authoritative absolute `/media/fat/MediaPlayer.rbf`; its attempted rollback upload was rejected with FTP status 550 and changed no file. Repeating the read with the repository's established double-slash absolute URL retrieved the true active image at entry 519's exact 4,205,620-byte size and SHA-256 `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197`. After the user explicitly authorized replacement, ordinary FTP preserved and round-trip verified that image as `/media/fat/MediaPlayer.rbf.rollback-pre-bfb9361`, staged and round-trip verified the 4,188,256-byte `bfb9361` candidate at SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df`, promoted it to the absolute active path and retrieved the active and rollback files again at their respective exact hashes. The first relative stage-delete command was rejected without changing the verified files; an absolute delete removed only `MediaPlayer.rbf.stage-bfb9361`, and a final directory read confirms the stage is absent while the active and rollback names remain. No helper, media, Main or MiSTer configuration changed.

#### Next Steps:

Reload the core and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and the deinterlacer that exposes the symptom most readily. Capture a live burst and the terminal schema-fourteen snapshot from the same run, retaining the established acceptance of 300 decoded pictures, 299 swaps, quiet completion and no aggregate, presentation or phase error. Read both session-wide varied flags and signatures: a first field that never varies while the second does proves the data is already wrong when it arrives and moves the search upstream of the framebuffer, while both parities varying proves correct data arrives and is lost afterwards.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 520 COMMIT Unreleased bfb9361 2026-08-25T20:00:21-07:00

#### Coming From:

Unreleased 2668c8f

#### Purpose:

Repair and complete the session-wide per-field luma-content diagnostic so its telemetry is structurally valid and independently regression-protected.

#### Outcome:

The user approved continuation after recovery reproduced the uncommitted schema-fourteen profiler regression failure and identified it as an unintended no-progress test snapshot rather than an asserted design error: the added luma-return stimulus extended a deliberately short test interval beyond the sixty-four-cycle watchdog while none of those passive diagnostic events are, or should become, production session progress. Commit `afdece5` supplies one genuine decoder-byte acceptance inside that directed scenario while leaving the production watchdog unchanged, exports each raw native luma return from the framebuffer and accumulates per-parity signature, reference and varied state across the entire profiler session. It also corrects snapshot word forty to exactly thirty-two bits, adds an independently summed elaboration-time width guard, advances the cadence format to schema fourteen and labels schema-fourteen content evidence as session scoped while retaining schema-thirteen, schema-ten and legacy decoding at their original layouts. Icarus and Verilator accepted a packed-structure implementation of the width-safe word, but the first Quartus Prime 17.0.2 analysis rejected that syntax; no image was produced from it. Correction commit `bfb9361` expresses the same independently sized payload through explicit vector slices compatible with the target compiler. The focused profiler passes schema fourteen at checksum `e2266429`; decoder layout passes schema fourteen, thirteen, ten and legacy at their established 428/308/43, 428/308/43, 436/316/41 and 444/324/38 origins and word counts. The complete native suite passes field order, mapping, exact TFF and BFF timing, Bob and Weave selection, timing-pattern isolation, ownership, the long presentation integration, every cache mode, the profiler and decoder. Its long integration retains twenty windows and forty fields, ten serialized, thirteen overlapped and twenty-one accelerated decoded pictures with twenty accelerated presentations, plus eight decoded and eight presented terminal pictures with empty terminal state. TFF, BFF and progressive reconstruction pass at 7,926,459, 7,948,706 and 13,048,137 cycles with zero out-of-tolerance pixels, field-DCT rejection passes at 82,326 cycles, and the canonical mixed I/P/B live raster remains exactly 6,529,997 cycles with twenty-five publications, forty-seven B-picture persistences, seventy-one swaps and every error clear. A clean from-scratch Quartus Prime 17.0.2 build of `bfb9361` completes in 11 minutes 2 seconds with zero errors and 143 warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.281, 0.244, 3.271, 0.595 and 0.925 nanoseconds with zero endpoint total negative slack. Focused decoder setup and recovery are positive 1.617 and 6.784 nanoseconds and focused video setup is positive 2.959 nanoseconds, all with zero violated paths; only the established unmatched `RESET` filter remains. Fit uses 29,706 ALMs, 45,755 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. A timing-netlist probe finds all eight bits of both session signatures and both varied-state keepers; the reference and seen intermediates are optimized into that retained logic. The 4,188,256-byte RBF has SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df`. Deployment stopped before any write because two independent ordinary-FTP reads found the active `/media/fat/MediaPlayer.rbf` to be a stable but unrecognized 4,200,652-byte file at SHA-256 `98c73c1b23499e5461fa789b3b77fbf59d798e957b9f7e9357bf6d932009a615`, rather than entry 519's logged 4,205,620-byte `2668c8f` image at `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197`. No remote file was changed.

#### Next Steps:

Identify or explicitly authorize replacement of the unrecognized active RBF before deployment. If replacement is approved, preserve that exact 4,200,652-byte file as `/media/fat/MediaPlayer.rbf.rollback-pre-bfb9361`, retrieve and verify the rollback copy at SHA-256 `98c73c1b23499e5461fa789b3b77fbf59d798e957b9f7e9357bf6d932009a615`, stage and round-trip verify the `bfb9361` candidate, promote it, verify the active file at SHA-256 `4f51994b786a6728a1ce57d120fec12c889460bfbbce7757354ad523bb7c29df` and remove only the temporary stage. Leave helper, media, Main and MiSTer configuration untouched. Reload the core and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with a live burst, reading both session-wide varied flags and signatures from the same symptom-bearing run. A first field whose returns never vary across the whole session while the second field's do proves the data is already wrong when it arrives and moves the search upstream of the framebuffer; both parities varying proves correct data arrives and is lost afterwards.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 519 COMMIT Unreleased 2668c8f 2026-08-25T19:53:29-07:00

#### Coming From:

Unreleased 7356e4a

#### Purpose:

Observe the luma content DDR returns for each field parity.

#### Outcome:

This commit folds every returned luma word into a per-parity signature and sets a varied flag when any word differs from the first that parity saw, attributing each word by `fetch_line[0]` against `first_field_mem`. Reading `fetch_line` also cleared one long-standing assigned-but-never-read warning, so the build reports 143 rather than the established 144. A clean build completed in 10 minutes 31 seconds with zero errors, global setup, hold, recovery, removal and minimum-pulse-width margins of positive 0.230, 0.253, 2.888, 0.689 and 0.925 nanoseconds, focused decoder setup and recovery of positive 1.735 and 11.737 and focused video setup of positive 2.346, all with zero violated paths, a fit of 29,440 ALMs and 45,469 registers, and every new register confirmed present by netlist probe. The 4,205,620-byte RBF has SHA-256 `c0eb30d2181b613a383b506bb30482f700c92c17eff7da33b082d049ac05c197` and was installed rollback-safe with `7356e4a` preserved. The first hardware attempt read schema twelve because the core had not been reloaded; the file on the card was verified correct and the run repeated after a reload. That repeat produced the clearest symptom capture so far, showing both presentations in one session: the first field blank at pre-playback level 24 with no bar for roughly eight seconds, then a transition, then the first field frozen on a picture with a stationary bar parked at x=112 through x=143 while the odd field continued sweeping, then correct content in both parities at terminal drain. The content counters from that run are void. Word forty was concatenated as eight, eight, one, one, six, three and three bits, which totals thirty rather than thirty-two, so the assignment zero-extended on the left and every field decoded two bits from its intended position. The reported varied flags and signatures are therefore meaningless, and the earlier explanation attributing their inconsistency to per-generation latching was wrong. The directed profiler regression did not catch it because it compared an equally malformed thirty-bit literal against the same wire, the same class of blind spot as the overlay case in entry 516 where a test validated the defect instead of detecting it. Schema twelve is unaffected and entry 518's conclusions stand, because its word forty totalled eight, eight, ten, three and three bits, which is exactly thirty-two. The padding has since been corrected to eight bits and a session-wide rework moves the accumulation into the profiler, whose reset scope is the session rather than the generation, so a parity that never receives varying data reports varied low regardless of which generation precedes terminal quiet. That rework lints clean but its directed regression currently fails with snapshot reason three, the fatal-error path, at 12.159 microseconds whenever the luma-return stimulus is present; the failure time is identical for a two-cycle and a three-cycle stimulus task, which rules out the no-progress budget that caused two earlier regression failures, and the mechanism is not yet understood. Nothing of that rework is committed. It remains uncommitted in the working tree so it is not lost, and the installed image remains `2668c8f`, which runs and captures normally but whose word-forty fields must not be read.

#### Next Steps:

Root-cause the profiler regression failure before anything else, since snapshot reason three means an error flag is asserting during the luma-return stimulus and that must be understood rather than worked around. Then complete the session-wide content rework on top of the corrected thirty-two-bit padding, and add a width check to the regression so a malformed snapshot word fails on its own rather than being confirmed by a matching malformed expectation, which is the specific gap that let both this defect and the entry 516 overlay defect reach a build. Rebuild, reinstall rollback-safe and repeat the fixture with a burst, reading the two varied flags and two signatures alongside burst frames from the same run. A first field whose returns never vary across the whole session while the second field's do proves the data is already wrong when it arrives and moves the search upstream of the framebuffer entirely; both parities varying proves correct data arrives and is lost afterwards, which would be the first evidence pointing downstream of the fetch. Retain the standing observation that the symptom presents in two forms, so a single run's flags do not generalize.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 518 COMMIT Unreleased 7356e4a 2026-08-25T19:52:53-07:00

#### Coming From:

Unreleased 3e91073

#### Purpose:

Record which DDR region each field parity's fetch actually resolves into.

#### Outcome:

Entry 517 showed the framebuffer requesting every first-field row correctly and receiving pre-playback content, so this commit observes the one thing no counter recorded: which of the five DDR regions the top-level offset steers each fetch into. The framebuffer emits a plain row address and `mpeg2_new_display_frame_offset` is added combinationally at issue time, so a native frame readout spanning two vertical periods could in principle straddle a display swap and resolve its two parities differently. The top level now samples the region on each parity's fetch edge and the profiler latches both and counts generations where they disagree; all of it is `clk_mpeg2` logic and none enters the video domain. Schema twelve retires the per-parity displayed-line counters, which entry 517 proved uninformative by reading two hundred forty against two hundred forty while the field carried no picture, and reuses their bits for the two regions and a mismatch count at the same forty-three words. Retiring them also removed two video-domain toggles, two three-stage synchronizers and two timing exceptions, which is why this build has more margin than the one before it. A clean Quartus Prime 17.0.2 build completed in 10 minutes 35 seconds with zero errors and the established 144 warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.343, 0.252, 3.420, 0.572 and 0.925 nanoseconds, with global setup above the accepted `9573923` baseline rather than merely matching it. Focused decoder setup and recovery are positive 1.608 and 11.174 nanoseconds and focused video setup is positive 3.117 nanoseconds, all with zero violated paths, and a timing-netlist probe confirms every new register survives. The fit uses 29,399 ALMs and 45,254 registers. The 4,223,092-byte RBF has SHA-256 `2d011ce350f427f0d3c4eb147825947c6bf93a9ec7fc4e8a0771f1a86cc3ed58` and was installed rollback-safe over ordinary FTP with `3e91073` preserved. On hardware the symptom reproduced across fourteen live burst frames with the first field blank at pre-playback level and the odd field sweeping normally, while the counters reported 242 first-field and 240 second-field fetches, region one for both parities, zero region mismatches across all three hundred generations and zero phase errors. Both parities therefore resolve into the same region in every generation, the straddled-swap mechanism does not occur, and the banked address path is exonerated along with readout sequencing, field phase and per-parity fetch service. A static read then eliminated the writer structurally rather than by measurement: `mpeg2_h262_ddram_store_420p.sv` uses the identical base, bank offsets and ninety-word row stride as the reader, and snaps each block origin to a multiple of eight so every write covers eight consecutive frame rows and cannot populate one parity without the other.

#### Next Steps:

Observe the luma content DDR returns for each parity, since every measurement so far has observed control rather than data and all of it has been correct. Fold each returned luma word into a per-parity signature and set a flag when any returned word differs from the first that parity saw, attributing the word by the fetch address parity. Keep the accumulation on the decoder clock, publish it in the existing forty-three words, and read it alongside burst frames from the same run because the symptom presents in two forms: a first field blank at pre-playback level, and a first field frozen on a picture.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [x] Passed

---

## 517 COMMIT Unreleased 3e91073 2026-08-25T18:48:23-07:00

#### Coming From:

Unreleased 3e91073

#### Purpose:

Read the new per-field evidence on hardware and determine whether framebuffer field readout is actually at fault.

#### Outcome:

The instrumented `3e91073` image was installed rollback-safe and run against `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and Bob, while a live burst sampled the core's raster at roughly 2.4 hertz. Schema eleven decoded on hardware for the first time at forty-three words from the moved native origin. Its verdict is that field readout is correct and entry 515's classification is superseded. The last generation was served 242 first-field and 240 second-field luma line fetches, presented 240 lines of each parity, and recorded zero generations of per-parity line imbalance and zero field-phase errors, while the established counters remained at 300 framebuffer resets, 299 publications, zero prefill misses and zero superseded generations. The 242 figure confirms the counter rather than contradicting it, because the two prefill luma lines are the sequence-zero and sequence-one rows and both therefore carry first-field parity by construction. The session itself was ordinary, with the complete 5,007,304-byte stream accepted, 300 decoded pictures, 300 displayed and 299 swaps across 599,116,647 cycles or 9.985277 seconds, top-field-first, sequence end seen, presentation complete, quiet reason one and every error clear. Against that, the burst shows the first field carrying no picture at all. Fourteen distinct live frames each place the moving bar on odd rows only, and the even rows sit at background level 24, which is the pre-playback screen rather than the fixture's level 19; a sweep found zero even-row pixels above background anywhere outside the reference rows and the telemetry overlay. Only the terminal frame shows both parities agreeing at the authored weave. The framebuffer therefore requests every first-field row, on the correct lines, in the correct field phase, and receives pre-playback content: the addresses are right and what they resolve to is wrong. Evidence is `.ai/current_results/entry517_stale_first_field_live.png` at 10,031 bytes with SHA-256 `a6ff293687eca203b3660e4881ffb0884e04676975aaeaab8633a090fcee566c` and `.ai/current_results/entry517_field_readout_counters.png` at 12,262 bytes with SHA-256 `bb02eca2ea6ce2364146f48a13c83ca14c487d579fec586abba117963d1a91d0`. A static read of the address path identifies the mechanism this evidence points at without proving it. The framebuffer emits a plain row address and the top level adds `mpeg2_new_display_frame_offset` combinationally at the instant each fetch is issued, selecting between five distinct DDR regions for bank zero, bank one, bank two and the two scratch areas. The framebuffer has no knowledge of which region its correct row lands in, and a native frame readout is uniquely exposed because its 480-entry sequence spans two vertical periods and can therefore straddle a display-bank swap, leaving the two fields resolved into different regions while every framebuffer counter still reads perfectly. No existing signal records which region a fetch resolved into, so this is invisible to all present telemetry. Commit `3e91073` passes its objective: the instrumentation was built to decide this question and it decided it against the standing hypothesis.

#### Next Steps:

Instrument the region a fetch actually resolves into, keeping every new observation inside the decoder clock domain so that none of it competes with the framework scaler for video-domain placement, which is what cost three rebuilds in the previous cycle. The display bank, display scratch and scratch bank levels already live on that clock, as do the two per-parity fetch toggles the framebuffer exports, so the top level can latch the region in effect on each first-field and each second-field fetch edge and compare them per generation. Retire the per-parity displayed-line counters, which have now demonstrably served their purpose by reading two hundred forty against two hundred forty with zero imbalance while the field carried no picture at all, and reuse their bits for the two observed regions and a count of generations whose two parities resolved differently. Publish this as schema twelve at the same forty-three words so the snapshot does not grow, update the telemetry decoder and its layout test for both schema twelve and the existing schema eleven and ten, extend the profiler regression with a directed case where the two parities disagree, then clean-build with focused timing and confirm by netlist probe that every new register survives and no timing exception is left unmatched before installing rollback-safe. Two differing regions localize the defect to the banked address path and justify a bounded correction there, while identical regions in every generation clear that path and move the investigation to whatever populates the first field's rows.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 516 COMMIT Unreleased 3e91073 2026-08-25T18:31:59-07:00

#### Coming From:ff

Unreleased 9573923

#### Purpose:

Instrument the per-field framebuffer readout invariants that whole-picture counters cannot observe.

#### Outcome:

Entry 515 placed the fault in framebuffer field readout, and this cycle adds passive evidence for it. The framebuffer exports a sticky per-generation field-phase error, one toggle per displayed line of each parity from the video domain, and one toggle per launched luma DDR line fetch of each parity from the memory domain, which is `clk_mpeg2` itself and therefore needs no synchronizer. Three-stage synchronizers carry the video-domain levels to the decoder domain and `MediaPlayer.sdc` cuts only their stage-zero paths, matching the convention `69a4f20` established. Cadence schema ten becomes schema eleven at forty-three words: one appended word packs four saturating eight-bit per-generation figures for first-field and second-field DDR fetches and displayed lines, a second carries sixteen-bit counts of generations whose per-parity line counts disagreed and of field-phase errors, and the checksum moves to word forty-two. A native field presents two hundred forty lines and is served two hundred forty luma rows, so eight bits carry the ordinary range while two hundred fifty-five reports saturation, which arises only when one generation spans several displayed frames. Both overlay origins move eight rows up to 428 and 308 so the final row stays flush with the diagnostic and native rasters. The Python decoder accepts schema eleven while schema ten and legacy schema nine still decode at their original origins. Reaching this state required three corrections, all recorded here rather than hidden. Commit `9bff941` appended three words but did not extend the overlay's per-word case statement or its fixed height, so nothing read words forty-one through forty-three and synthesis correctly deleted the entire phase-error synchronizer chain, the fetch toggles, the per-generation latches and both counters; a `get_keepers` probe returned zero keepers for every one of them, and the only symptom in an otherwise clean build was an ignored-filter warning naming `mpeg2_new_framebuffer_phase_error_sync[0]`. The profiler regression had passed because it asserts against the snapshot register directly and never exercised the overlay decode, so `5c6c311` added the missing branches, raised the height and introduced a row-coverage regression that walks every word row checking the decoded index, the rendered word and that the row lies inside the overlay height; reinstating the short height proves it fails. That build restored all keepers but global setup fell to negative 0.082 nanoseconds entirely inside MiSTer's `ascal` scaler. Packing to forty-three words in `0d2aead` unexpectedly grew the fit to 29,680 ALMs and left setup at negative 0.091 with the critical path relocated inside `ascal`, proving word count was not the cost. Commit `3e91073` instead removed the video-domain arithmetic by replacing a nine-bit expected-index adder and equality comparator with a single constant magnitude compare: the replica's own position names its field, so comparing that parity against the raster parity detects a retained or misaligned field without computing the index. A clean Quartus Prime 17.0.2 build from empty generated state completed in 10 minutes 47 seconds with zero errors and the established 144 warnings, none attributable to the new logic. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.252, 0.244, 4.132, 0.589 and 0.925 nanoseconds, with global setup exactly matching the accepted `9573923` build. Focused decoder setup and recovery are positive 1.646 and 11.735 nanoseconds and focused video setup is positive 2.811 nanoseconds, all with zero violated paths. Only the pre-existing `RESET` filter remains unmatched, and a timing-netlist probe confirms every new register survives. The fit uses 29,448 ALMs, 45,442 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,219,576-byte RBF has SHA-256 `05e3a5b564ca49554707d39205749f9b96dec8028fcfe68a562b30d921f0aa54`. The complete native suite passes all thirteen cases including the new row-coverage check, and TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles with field-DCT rejection at 82,326 cycles. The live raster soak still fails its historical 6,529,997-cycle assertion against an observed 6,529,996 with every other figure clean; it compiles none of the files this cycle changed, so the drift entry 511 documented remains outstanding and independent. No decoder, scheduler, cache, presentation or native timing behavior changes.

#### Next Steps:

Preserve the running `9573923` image as `/media/fat/MediaPlayer.rbf.rollback-pre-3e91073` through ordinary FTP with the default `root` and `1` login, round-trip verify both it and the staged candidate, promote the candidate, verify the promoted file at its exact hash and remove only the temporary stage while leaving helper, media, Main and MiSTer configuration untouched. Then run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, Interlaced output Native 480i and the deinterlacer that ghosts most readily, and capture the terminal raster along with a live burst through `/dev/MiSTer_cmd`. Acceptance requires the established 300 decoded pictures, 299 swaps, normal quiet completion and no aggregate or presentation error, with the new evidence read alongside. Balanced per-parity DDR fetch counts with zero phase errors would clear field readout and force the investigation back upstream to what writes the frame, while a starved first-field fetch count during a generation the burst shows frozen would localize the defect to the refill path and justify a bounded correction there. Report the per-generation figures with the burst evidence before any behavioral change is proposed.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [x] Built
- [ ] Passed

---

## 515 COMMIT Unreleased 9573923 2026-08-25T11:32:46-07:00

#### Coming From:fff

Unreleased 9573923

#### Purpose:

Locate the native ghost by capturing the core's own raster during live playback instead of only after it ends.

#### Outcome:

Every prior capture in this investigation was terminal, so the intermittent ghost had never been measured while visible. Bursts of screenshot triggers issued through the MiSTer's ordinary-FTP view of `/dev/MiSTer_cmd` with the default `root` and `1` login now sample the live raster at roughly 2.4 hertz. The decisive fixture burst returned twenty-four distinct live frames of `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off and Interlaced output Native 480i. Decomposed by field, the bottom field advances its bar every single frame across the full sweep while the top field holds one position for 4.2 seconds at x=512 through x=543, jumps once and then holds the next for 4.6 seconds at x=632 through x=663. Each frozen top-field bar measures exactly thirty-two columns by one hundred seventy-six rows, the exact authored field-bar geometry, so it is a cleanly retained picture rather than a smear. An earlier burst independently caught the same asymmetry with content instead of position: at playback start the top field carried the entire previous screen at background level 24 while the bottom field carried live video at level 19, and two frames 0.8 seconds apart both showed it, which excludes the ordinary sixteen-millisecond inter-field sampling offset of an interlaced screenshot. That evidence is `.ai/current_results/entry515_live_ghost_two_bars.png` at 13,565 bytes with SHA-256 `4c6ad022c14e55a586270072a1807b5d02a2b4d5e2e1d6153dc35e975ca26c82`, `.ai/current_results/entry515_field_freeze_early.png` at 13,233 bytes with SHA-256 `d0387b6c4c423ff737ee3eff426b79759a27bde5b936392667f6252c252baaed` and `.ai/current_results/entry515_field_freeze_midrun.png` at 10,864 bytes with SHA-256 `69ac1b3517d343d8de3683c79d1596f08a6288fe17b0187af00d59586a0eefe1`. The pattern control settles the boundary. With Native timing pattern On and motion Moving the same burst returned fifty-five distinct frames over forty-six seconds at background exactly `(16,16,16)`, reference rows 120, 121, 360 and 361 and sixteen-pixel bars at the authored positions; forty-eight of them place both fields at the identical x with 3,840 bright pixels each, and the seven that differ are jump instants between adjacent authored positions which resolve to a united bar by the next sample 0.42 seconds later. The pattern therefore proves the capture path, final mux, native sync, MiSTer's processed-HDMI Bob path and the display all track a moving object within one field time, while decoded video retains a stale field for over two hundred forty field times through the same chain. Its evidence is `.ai/current_results/entry515_pattern_control_locked.png` at 7,721 bytes with SHA-256 `71ac91a908a494bce09f7ecbf32c0b8c3ca617e44e4fc8b001a13df52adc05e6` and `.ai/current_results/entry515_pattern_control_transition.png` at 9,850 bytes with SHA-256 `ac115389e3cc3ea33df5d552903f09c5f4fd77477511eda8fff294ed3b871153`. Because the pattern bypasses the framebuffer, DDR and line cache while video does not, the fault is field readout, confirming the classification entry 514 assigned. A static read of `rtl/mpeg2_luma_framebuffer.sv` mapped the mechanism but did not identify the defect, and it disproved the leading hypothesis: the 480-entry presentation sequence is not free to sit at an arbitrary raster phase, because the per-generation reset zeroes `line_done_sequence_mem` and the event advancing it is gated on `picture_present_rd`, which asserts only at the authored first-field origin, so entry zero is anchored to the correct field by construction. The monitored reader-fell-behind and same-bank refill collision detectors also remain clear in every run, so neither is the cause.

#### Next Steps:

Instrument the per-field invariants the static read identified, all of which are currently unmeasured because existing telemetry counts whole pictures and therefore cannot see a single stale field. Derive the true presentation sequence index in the video domain from the raster position as the authored-parity field line or two hundred forty plus that line, compare it against the memory-domain `line_done_sequence_mem`, and record mismatch count, the first mismatching pair and maximum drift. Add per-parity displayed-line counts for each generation so that a frozen top field appears directly as an imbalance against the expected two hundred forty and two hundred forty, record whether publication ever asserts on the wrong raster parity, and count DDR line refills served to each field. Extend the hardware snapshot from schema ten to schema eleven by appending words only, without repurposing any established MPEG, prediction, PCM, scheduler or error field, exactly as `52a5a64` extended schema nine to ten, and move the checksum accordingly. Update the telemetry decoder and its tests, add focused framebuffer and native integration regressions covering an ordinary locked sequence and a deliberately stalled field, retain the complete native and scheduler suites, then run a clean Quartus Prime 17.0.2 build with focused timing analysis and install through rollback-safe ordinary FTP. Repeat the fixture with the live burst and require the new counters to identify which invariant breaks when the top field freezes. No presentation, cache, scheduler or native timing behavior may change in this observational commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 514 COMMIT Unreleased 9573923 2026-08-25T11:06:08-07:00

#### Coming From:

Unreleased 9573923

#### Purpose:

Determine whether the intermittent native ghost and the grey dash artefact originate upstream or downstream of the FPGA final mux.

#### Outcome:

The first ordinary-FTP capture of this cycle was taken while `Native timing pattern` was still Off and was initially misread as pattern output. `.ai/current_results/entry514_moving_pattern_retention.png` is 12,192 bytes with SHA-256 `146d3f343bf9c5a8607eee944a0d71ab59b6372bc9a07d1d4b30922ba4de6ac0`. Measured against entries 508 and 509 it is structurally identical to them, with background `(19,19,19)`, full-width reference rows 119 through 122 and 357 through 360 and the authored terminal weave whose even rows span x=512 through x=543 and odd rows x=516 through x=547, so it recorded decoded video rather than the diagnostic. That reading and the downstream conclusion drawn from it are withdrawn. The installed image was then verified over ordinary FTP with the default `root` and `1` login at exactly 4,220,300 bytes and SHA-256 `03bb6a504538fd7e62b2877a428e2e570841ccb3d2d834674f163dd580d76642`, confirming `9573923` was the running core and that the Moving submode existed but had not been selected. The user then set Native timing pattern On, Native pattern motion Moving, HDMI scaler deinterlacer Bob and Interlaced output Native 480i and reran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v`. The resulting `.ai/current_results/entry514_moving_pattern_on.png` is 7,676 bytes with SHA-256 `76e71cd567acd63e29049a078502de80cac2822c45c35e710370f1d79d58ab6c` and its raster is pixel-exact against the authored source: background exactly `(16,16,16)`, reference lines exactly `(80,80,80)` at rows 120, 121, 360 and 361 and one `(191,191,191)` bar occupying columns 432 through 447, exactly sixteen pixels wide and all 480 rows tall at authored position 432. A sweep for any intermediate level outside the reference rows and the telemetry overlay returned no pixel at all, so no second bar, partial bar or dash exists anywhere in the emitted frame. The user independently reports one bar only throughout live playback, correct holds, ninety-six-pixel jumps and wrap, and no grey dashes at any point in this mode. Schema ten accepted the complete 5,007,304-byte stream and represented 300 decoded pictures, 300 displayed pictures and 299 swaps across 599,436,793 cycles or 9.990613 seconds, with 300 framebuffer resets, 299 publications, zero superseded unpublished generations, zero prefill misses, a maximum 2,002,004-cycle publication latency, zero gap outliers, top-field-first, sequence end seen, presentation complete, quiet reason one and every error clear. Commit `9573923` therefore passes its diagnostic objective. Because the final mux, cadence overlay, native sync generation, MiSTer's processed-HDMI Bob path and the display together rendered a moving object with no retention whatsoever, the decoded-video ghost originates upstream of the final mux in framebuffer cache or field readout, which is the conclusion entry 513 assigned to this outcome. That inference is bounded rather than absolute because the pattern bar is pair-identical between fields and holds each position thirty frame windows, so it exercises neither inter-field difference nor per-frame motion and cannot fully exonerate downstream processing for field-differing content; entries 502, 503, 509 and 510 weaken the downstream account independently because the ghost survives both Weave and Bob. Separately, `decode_hardware_cadence.py` derives `delivered_fps` from the wrapped eight-bit swap counter rather than the reconstructed count and printed 4.303 where the true rate is 29.928 pictures per second, a reporting trap every prior entry avoided by computing the rate by hand.

#### Next Steps:

Close the remaining gap with direct evidence rather than inference by capturing the core's own raster while the ghost is live, since every capture in this investigation so far has been a terminal capture taken after playback ended. With Native timing pattern Off, Interlaced output Native 480i and whichever deinterlacer ghosts most readily, the user launches `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` and the agent bursts sixteen screenshot triggers at approximately 0.8-second intervals through the MiSTer's ordinary-FTP view of `/dev/MiSTer_cmd` into `/media/fat/screenshots`, retrieves each one and measures every raster for a second bar group, a faint column group or dash rows against the established thirty-seven-pixel authored weave baseline. A ghost present in any core-side raster places the fault upstream and justifies a following commit instrumenting framebuffer field readout, while a ghost absent from every raster during a run the user sees ghosting on the panel proves the fault is downstream and justifies extending the timing pattern with per-frame motion and a field-differing submode matching the fixture's four-pixel inter-field offset. No RTL, menu, scheduler or MiSTer configuration changes belong in this step, and the retrieved screenshots stay on the SD card unless the user asks for their removal.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 513 COMMIT Unreleased 9573923 2026-08-25T09:58:18-07:00

#### Coming From:

Unreleased 69a4f20

#### Purpose:

Add a moving final-mux native pattern that distinguishes FPGA field-readout retention from MiSTer scaler or display retention.

#### Outcome:

The user approved the revised diagnostic after review of `.ai/current_results/PXL_20260825_160322728.mp4`, a 56,383,735-byte 13.564622-second Pixel 8 Pro recording at SHA-256 `267561d6246d06ce7ec03f533e979b6b1bd7e15c27fffa8bc01b9f8154adaec6`. The ordinary full-height bar moves and wraps throughout the active playback, while a separate upper-half bar remains fixed at one horizontal position for nearly the entire ten-second session and disappears abruptly when playback completes and the terminal overlay returns. This is not a brief Bob tradeoff, rolling-shutter duplicate or panel afterimage. The paired schema-ten capture accepts the complete 5,007,304-byte stream, represents all 300 pictures and 299 swaps in its wrapped counters, records 300 framebuffer resets, 299 publications, zero superseded unpublished generations, zero prefill misses, a maximum 2,002,005-cycle publication latency, three regular 2,002,000-cycle ranked gaps, normal quiet completion and no error. Commit `9573923` retains the established status-bit-123 static bars and adds status bit 125 as a separately synchronized Static/Moving submode. Moving mode emits a sixteen-pixel pair-identical bar at x positions 48 through 624, holds each for exactly thirty complete frame-window edges, advances ninety-six pixels and wraps through seven positions; pair-identical horizontal references use the common field-row coordinate. This source remains after the framebuffer mux and before the cadence overlay, so decoder, DDR and line-cache pixels are absent while native sync, field signalling and MiSTer's processed-HDMI path remain active. Destination-scoped timing exceptions cut only the two asynchronous menu sources entering stage zero. Directed tests prove unchanged static colors, blanking and sync passthrough, exact hold, jump and wrap behavior, no double-count from a held frame-window level and identical TFF/BFF content. The complete native suite passes field order, mapping, timing, Bob/Weave control, ownership, accelerated presentation, cache refill and schema-ten telemetry; TFF, BFF and progressive reconstruction retain zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, field-DCT rejection remains 82,326 cycles and the canonical mixed I/P/B raster remains exactly 6,529,997 cycles with every error clear. No decoder, scheduler, framebuffer, cache or native timing behavior changes. A clean Quartus Prime 17.0.2 build from empty generated state completed in 10 minutes 45 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.252, 0.251, 3.650, 0.630 and 0.925 nanoseconds. Focused decoder setup and recovery are positive 0.913 and 11.075 nanoseconds and focused video setup is positive 2.661 nanoseconds, all with zero violated paths. Both native menu synchronizer exceptions match without an empty-filter warning. The fit uses 29,271 ALMs, 45,209 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,220,300-byte RBF has SHA-256 `03bb6a504538fd7e62b2877a428e2e570841ccb3d2d834674f163dd580d76642`. Ordinary FTP retrieved the installed `69a4f20` image at its exact known 4,237,424-byte hash `57cee7a30c9802c256398cbf44875c5c2118b4b912aca0ef08e103467068c673`, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-9573923`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact new hash. The temporary stage is absent; helper, media, Main and MiSTer configuration are unchanged.

#### Next Steps:

Reload the installed core, set HDMI scaler deinterlacer to Bob, Native timing pattern to On, Native pattern motion to Moving and Interlaced output to Native 480i, then run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` once and record the complete active interval. The direct pattern must show one sixteen-pixel bar at a time, hold each position for approximately one second, jump ninety-six pixels and wrap after seven positions while the two horizontal references remain fixed. Any second retained bar or partial bar proves the fault is downstream of the FPGA final mux in MiSTer's processed-HDMI scaler or display; clean single-bar jumps prove the FPGA final mux and downstream path and place the decoded-video fault inside field-specific framebuffer cache or readout. Report USER, DISK and POWER and leave the terminal image displayed for ordinary-FTP capture.

#### Files Modified:

- `MediaPlayer.sdc`
- `MediaPlayer_top_00.svh`
- `MediaPlayer_top_01.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_native_timing_pattern.sv`
- `tools/streams/tb_native_480i_timing_pattern.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 512 COMMIT Unreleased 69a4f20 2026-08-25T08:40:51-07:00

#### Coming From:

Unreleased 52a5a64

#### Purpose:

Constrain only the asynchronous first stages of the new framebuffer telemetry synchronizers and restore clean timing without hiding their synchronous delivery paths.

#### Outcome:

The clean Quartus Prime 17.0.2 build of `52a5a64` completed in 10 minutes 34 seconds with zero errors and produced an RBF, but global setup failed at negative 1.883 nanoseconds and is not eligible for installation. Focused timing proved the established same-clock decoder paths remained positive at 1.457 nanoseconds and video paths remained positive at 2.611 nanoseconds. The only two violations were the intentional 54 MHz video-domain `picture_present_rd` and `prefill_deadline_missed_rd` levels entering stage zero of their respective three-stage 60 MHz synchronizers. Their raw asynchronous phase relationship created a 1.850-nanosecond TimeQuest relationship which must not be treated as a synchronous transfer. Commit `69a4f20` adds two destination-scoped false paths to stage zero only, matching the existing project convention for mode, cadence, download, snapshot and cache synchronizers. TimeQuest matches both keepers without an empty-filter warning; stages zero-to-one and one-to-two remain fully timed, and no RTL, diagnostic meaning, clock or functional behavior changes. A second clean Quartus build from an empty database completed in 10 minutes 30 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively positive 0.206, 0.253, 3.189, 0.461 and 0.925 nanoseconds. Focused decoder setup and recovery are positive 1.873 and 11.235 nanoseconds and focused video setup is positive 3.225 nanoseconds, all with zero violated paths. The fit uses 29,133 ALMs, 44,992 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,237,424-byte RBF has SHA-256 `57cee7a30c9802c256398cbf44875c5c2118b4b912aca0ef08e103467068c673`. Ordinary FTP with the default `root` and `1` login retrieved the active `48c2c87` image at its exact known `a4e7678719072f0790d8bce74f5c29e329eedb8ef5d6163245c2de8328756332` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-69a4f20`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact new hash. The temporary stage is absent; helper, media, Main and MiSTer configuration are unchanged.

#### Next Steps:

Use ordinary FTP with the default `root` and `1` login to verify the active image remains the accepted `48c2c87` RBF, preserve it as `/media/fat/MediaPlayer.rbf.rollback-pre-69a4f20`, round-trip verify a staged `69a4f20` image, promote it and remove only the temporary stage while leaving helper, media, Main and MiSTer configuration untouched. Then repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` in Bob up to three times and leave the first ghosted run's terminal raster displayed for capture. A nonzero prefill miss, superseded unpublished reset or excessive publication latency correlated with the ghost will justify a narrow cache-publication correction; complete publication with regular ranked gaps will clear this FPGA boundary and retain the downstream-display diagnosis.

#### Files Modified:

- `MediaPlayer.sdc`

#### Status:

- [x] Built
- [ ] Passed

---

## 511 COMMIT Unreleased 52a5a64 2026-08-25T08:00:22-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Instrument the intermittent native framebuffer publication boundary without changing decoder, scheduler, cache or output behavior.

#### Outcome:

Commit `52a5a64` adds only passive native framebuffer-publication evidence. The framebuffer exports its video-domain picture-present level and a per-generation sticky indication that the authored first-field origin arrived before the six-line cache prefill was ready; three-stage synchronizers carry both levels to the 60 MHz decoder domain while the existing scheduler-generated framebuffer reset supplies the generation boundary. Cadence schema ten expands from thirty-eight to forty-one words without repurposing the established MPEG, prediction, PCM, scheduler or error fields. Its appended words count generation resets, picture publications, resets which supersede an unpublished generation, prefill deadline misses and maximum reset-to-publication latency, and the checksum moves to word forty. Ranked gaps and timestamp conflicts begin at STC second zero in this diagnostic hardware instance. The overlay moves eight pixels upward to retain all rows inside both diagnostic and native rasters, while the Python decoder accepts both new schema-ten positions and the two legacy schema-nine positions. Directed tests proved an ordinary ready-first publication, a deliberately late prefill which records a miss without publishing unready pixels, and a three-reset/two-publication sequence with one superseded generation; the profiler retained exact counts, nonzero latency and a valid checksum, and both schema versions decoded from both raster layouts. The complete native suite passed field order, exact 4:2:0 mapping, TFF and BFF timing, Bob and Weave control, timing pattern, ordinary ownership, twenty-window accelerated presentation, ordinary and delayed cache refill and the new late-prefill case. All five scheduler frame rates and native field cadence passed. TFF, BFF and progressive reconstruction retained zero out-of-tolerance pixels at 7,926,459, 7,948,706 and 13,048,137 cycles, and field-DCT rejection remained 82,326 cycles. The canonical seventy-two-picture mixed I/P/B raster completed all twenty-five reference publications, forty-seven B-picture persistences and seventy-one swaps with exact DDR and reconstruction accounting and zero errors at 6,529,996 cycles. Its historical assertion expects 6,529,997 cycles, but an untouched archived `48c2c87` source snapshot replayed against the exact same 291,641-byte fixture produced the identical cycle-by-cycle trace, identical 6,529,996 terminal count and identical sole assertion, proving the one-cycle expectation drift predates and is independent of this observational commit. No unrelated decoder test was changed or relaxed.

#### Next Steps:

Run a clean Quartus Prime 17.0.2 build and focused timing analysis, preserve the currently installed `48c2c87` image as rollback through ordinary FTP with the default `root` and `1` login, round-trip verify and promote the `52a5a64` diagnostic image, and leave helper, media, Main and MiSTer configuration untouched. Repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` in Bob up to three times and leave the first ghosted run's terminal raster displayed for ordinary-FTP capture. A nonzero prefill miss, superseded unpublished reset or excessive publication latency correlated with the ghost will justify a narrow cache-publication correction; complete publication with regular ranked gaps will clear this FPGA boundary and retain the downstream-display diagnosis.

#### Files Modified:

- `MediaPlayer_top_06.svh`
- `MediaPlayer_top_07.svh`
- `rtl/mpeg2_luma_framebuffer.sv`
- `rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv`
- `tools/streams/decode_hardware_cadence.py`
- `tools/streams/run_native_480i_timing.sh`
- `tools/streams/tb_h262_hardware_cadence_profiler.sv`
- `tools/streams/tb_native_480i_cache_refill.sv`
- `tools/streams/test_decode_hardware_cadence.py`

#### Status:

- [ ] Built
- [ ] Passed

---

## 510 COMMIT Unreleased 48c2c87 2026-08-25T07:56:37-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Capture the repeated TFF Bob comparison and determine whether the intermittent native ghost depends on Weave field history.

#### Outcome:

The user changed only HDMI scaler deinterlacer from Weave to Bob, retained Native timing pattern Off and Interlaced output Native 480i, and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` three consecutive times on the exact installed `48c2c87` image. One of the three runs showed the intermittent ghost earlier in the stream, so Weave's multi-field reconstruction history is not its sole cause. Bob is otherwise mostly perfect while the bar moves left to right; the approximately 60 Hz flicker and fuzzy stationary bar are the expected Bob tradeoff from displaying one field at a time rather than reconstructing full vertical detail. All LEDs pass. The untouched terminal screenshot from the run which ghosted was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry509_terminal_drain_bob.png` is 11,976 bytes with SHA-256 `08b22c2e3cb3cfc470ab7a77586d5e45d5ea8f6794550dcf9ed1b21cb93b4b87`. Schema nine accepts all 5,007,304 bytes and its wrapped counts represent exactly 300 decoded pictures, 300 displayed pictures and 299 swaps. Those 299 intervals span 598,786,877 decoder cycles or 9.979781 seconds and deliver 29.960576 pictures per second. Top-field-first remains correct, sequence end is seen, presentation completes, the session reaches quiet reason one and every aggregate, presentation, destination and cache-bank-overlap error is clear. The terminal raster is the correct final authored weave and contains no retained old position. Scheduler ownership and cadence therefore remain clean even in a Bob run where the user saw the live ghost. The current profiler's zero ranked gaps cannot clear an intermittent early-run stall because its hardware instance deliberately begins gap ranking at STC second 500 for the former full-movie credits investigation, far beyond this ten-second fixture. A plausible remaining boundary is the variable reset-and-prefill interval between a scheduler display-bank swap and the framebuffer's next field-origin publication; missing that cache-ready deadline would be invisible to the current swap counter and could affect Bob and Weave alike.

#### Next Steps:

Stop before changing presentation or cache behavior and obtain approval for one observational diagnostic RBF. Begin ranked display-gap capture at STC second zero for short native fixtures and extend the hardware snapshot without repurposing existing MPEG, audio or prediction fields to record framebuffer publication count, authored field origins missed while the post-swap prefill is not ready, maximum swap-to-publication latency and a compact cache refill deadline state. Update the telemetry decoder and focused profiler, framebuffer and native integration regressions, then clean-build and install through rollback-safe ordinary FTP. Repeat the TFF light-motion fixture in Bob up to three times and capture the first run which ghosts. A nonzero missed-origin or excessive publication latency correlated with that run will justify a narrow prefetch/publication correction; exact framebuffer publication with regular ranked scheduler gaps will clear the FPGA delivery path and leave the residual to the downstream display. Do not alter Bob, Weave, native timing or scheduler ownership in the diagnostic commit.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 509 COMMIT Unreleased 48c2c87 2026-08-25T07:29:58-07:00

#### Coming From:

Unreleased 48c2c87

#### Purpose:

Capture the terminal-drain hardware result and separate its accepted presentation completion from the remaining intermittent display-history ghost and faint moving-line artifact.

#### Outcome:

The user reloaded the installed `48c2c87` image and ran `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Playback is materially better and the prior pervasive ghosting is almost gone, but one intermittent event near mid-run retained an old image for a noticeable interval, and the user can still barely see the transient short horizontal lines while the movie is moving; those lines are now gray. USER and POWER are solid and DISK blinks twice. The untouched terminal screenshot was triggered, retrieved and decoded entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry508_terminal_drain_hardware.png` is 11,909 bytes with SHA-256 `6db00f683783d9fbe2aea7579b9e30c228c82ecb47c6e182a2e534b27b593320`. Schema nine accepts all 5,007,304 bytes, and its wrapped reference, display and swap counts of 44, 44 and 43 represent exactly 300 decoded pictures, 300 displayed pictures and 299 swaps. The 299 presentation intervals span 599,109,027 decoder cycles or 9.985150 seconds and deliver 29.944466 pictures per second. Top-field-first remains correct, sequence end is seen, presentation completes, the session reaches quiet reason one and every aggregate, presentation, destination and cache-bank-overlap error is clear. The final raster contains the correct authored last-field weave at x=512 through x=543 and x=516 through x=547 rather than an old terminal position. Commit `48c2c87` therefore passes its bounded terminal-drain objective and eliminates the prior missing final picture. The clean swap count and cadence place the remaining intermittent stuck appearance below scheduler ownership; together with the previously analyzed pair-identical step-hold recording, its working classification remains downstream Weave or display field-history processing. The live-only gray dashes remain unresolved because the terminal still cannot retain them and the cache-bank overlap diagnostic excludes only the monitored same-bank refill collision.

#### Next Steps:

Keep the exact installed `48c2c87` image, Native timing pattern Off and Interlaced output Native 480i, change only HDMI scaler deinterlacer from Weave to Bob and run `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` three consecutive times. Report whether any old bar or image persists during any run, whether the faint gray horizontal dashes remain, and the final USER, DISK and POWER states, then leave the last terminal image displayed for another ordinary-FTP capture. Bob removes Weave's multi-field reconstruction history while retaining the decoder, scheduler, DDR frame banks and line-cache path: disappearance of the intermittent ghost with unchanged clean cadence will confirm the established downstream-history classification, while gray dashes in both modes will isolate the next cycle to line-cache delivery instrumentation. Do not change RTL or native timing before this comparison.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 508 COMMIT Unreleased 48c2c87 2026-08-25T04:26:41-07:00

#### Coming From:

Unreleased c78bd15

#### Purpose:

Guarantee that native all-I sequence end releases and presents the final queued picture across every completion, promotion and swap race.

#### Outcome:

The user approved a bounded terminal-drain correction after entry 507 materially improved playback but ended with USER and DISK off and POWER blinking once. The two Pixel 8 Pro recordings `.ai/current_results/PXL_20260825_111447318.mp4` and `.ai/current_results/PXL_20260825_111514313.mp4` are respectively 52,996,175 bytes over 12.844311 seconds at 59.715153 captured frames per second with SHA-256 `7beb985475df4639fb4606302445a24ac2b6ed558553c57b16d8744e84a3fa02`, and 56,185,455 bytes over 13.629356 seconds at 59.503914 captured frames per second with SHA-256 `cf15f7d59e07356dcd0fd92c74d790ebd18b42c6c5f63dc2b89caf9d41e598e1`. Both show the bright bar advancing and wrapping at the corrected rate while retaining the already classified downstream Weave/display-history ghosts. The untouched ordinary-FTP schema-nine capture `.ai/current_results/entry507_tff_light_secondary_queue.png` is 11,841 bytes with SHA-256 `d029cdd623391ff27611b014456e8bbcc2406b860a71f7d392d22408d7de503d`. It accepts all 5,007,304 bytes, decodes all 300 reference pictures as the wrapped count 44, but displays only 299 with 298 swaps as wrapped counts 43 and 42. Those 298 intervals span 597,055,088 decoder cycles and deliver 29.946985 pictures per second with zero aggregate or presentation error and sequence end seen, but terminal quiet remains false because one pending ordinary identity is valid and unreleased. Pixel inspection independently finds the penultimate authored field positions at x=504 and approximately x=508 rather than the final x=512 and x=516 positions. Commit `48c2c87` makes native ordinary sequence-end permission sticky until the primary and secondary identities drain, including terminal events before, coincident with and after secondary completion or promotion. The finite accelerated integration case decoded and presented all eight pictures and finished with no primary, secondary, terminal-latch or hold state. The official native suite passed with forty field ticks, twenty frame windows, the existing ten-picture serialized and thirteen-picture overlapped controls, twenty-one decoded and twenty presented accelerated pictures, ordinary and delayed cache refill, schema-nine cadence telemetry and decoder layout. The full scheduler regression also preserved all cadence rates, timestamp behavior, B-picture ordering and starvation handling. TFF and BFF reconstruction passed with zero out-of-tolerance pixels at 7,926,459 and 7,948,706 cycles, progressive passed at 13,048,137 cycles, field-DCT rejection passed at 82,326 cycles and canonical mixed I/P/B live-raster playback remained exactly 6,529,997 cycles with all error flags clear. A clean Quartus Prime 17.0.2 build completed in 10 minutes 44 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.160, +0.248, +2.959, +0.368 and +0.925 nanoseconds; focused decoder setup and recovery are +1.519 and +11.273 nanoseconds and focused video setup is +3.227 nanoseconds, all with zero violated paths. The fit uses 28,968 ALMs, 44,679 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,151,600-byte RBF has SHA-256 `a4e7678719072f0790d8bce74f5c29e329eedb8ef5d6163245c2de8328756332`. Ordinary FTP with the default `root` and `1` login retrieved the active `c78bd15` image at its exact known `e8e71ce25ba6dd9d783bacb4b62a237bdd0de4d98a8891b00dd5bf82bb80636f` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-48c2c87`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage is absent; helper, Main, media and MiSTer configuration are unchanged.

#### Next Steps:

Run a clean Quartus build and focused timing analysis, preserve `c78bd15` as rollback through ordinary FTP, install the byte-verified image and repeat `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Acceptance requires all 300 pictures and 299 swaps, normal quiet completion, no aggregate or presentation error and passing LEDs.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv`
- `tools/streams/tb_native_ordinary_overlap_ownership.sv`
- `tools/streams/tb_native_480i_presentation_integration.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 507 COMMIT Unreleased c78bd15 2026-08-25T03:43:42-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Retain two pending native all-I frames safely when optimized decode momentarily outruns the 29.97-fps presentation boundary.

#### Outcome:

Commit `c78bd15` retains one completed secondary native all-I identity while its predecessor still owns the primary pending slot. It admits only the next safe I-picture classification boundary, then applies payload backpressure until the predecessor presents and the freed display bank becomes the resumed decode destination. Duplicate pending-bank and displayed-bank reuse remain fatal, while P pictures still cannot enter the exception. The accelerated 480i integration model repeatedly exercised this queue with one-field decode latency and completed twenty frame windows with forty field ticks, twenty-one decoded pictures, twenty ordered presentations and no scheduler error. The former three-field controls remained exactly ten serialized and thirteen overlapped decoded/presented pictures. Native cache/cadence tests passed, TFF and BFF reconstruction remained within one code value with zero out-of-tolerance pixels at 7,926,459 and 7,948,706 cycles, the progressive control passed at 13,048,137 cycles, and the canonical mixed I/P/B live-raster result remained exactly 6,529,997 cycles with all decoder, reconstruction and presentation checks clear. A clean Quartus Prime 17.0.2 build completed in 10 minutes 36 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.321, +0.246, +3.444, +0.634 and +0.925 nanoseconds; focused decoder setup and recovery are +1.805 and +9.741 nanoseconds and focused video setup is +2.729 nanoseconds, all with zero violated paths. The fit uses 29,124 ALMs, 44,427 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs. The 4,150,888-byte RBF has SHA-256 `e8e71ce25ba6dd9d783bacb4b62a237bdd0de4d98a8891b00dd5bf82bb80636f`. Ordinary FTP with the default `root` and `1` login retrieved the active `f866ce2` image at its exact known `acc28e644100e0452e45fcfe9749762d3a690ca8d6da9479cc4a2ac23d736b7b` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-c78bd15`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage is absent; helper, Main, media and MiSTer configuration are unchanged.

#### Next Steps:

Restart hardware validation at `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, HDMI scaler deinterlacer Weave and Interlaced output Native 480i. Confirm that the complete moving bar now reaches the right edge, that presentation remains smooth and stable, and that USER/DISK/POWER all report pass before marking this entry passed.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv`
- `tools/streams/tb_native_ordinary_overlap_ownership.sv`
- `tools/streams/tb_native_480i_presentation_integration.sv`

#### Status:

- [x] Built
- [ ] Passed

---

## 506 COMMIT Unreleased f866ce2 2026-08-25T03:40:25-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Capture the first optimized TFF Weave hardware run and distinguish decoder throughput from presentation ownership.

#### Outcome:

The user opened `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v` with Native timing pattern Off, the renamed HDMI scaler deinterlacer set to Weave and Interlaced output set to Native 480i. The image looks better, but the moving bar stops before crossing the screen; USER and DISK are solid off and POWER blinks once. The untouched image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH. `.ai/current_results/entry506_tff_light_weave_throughput.png` is 12,014 bytes with SHA-256 `9d17a5d3523c7f090576e99516b51d9e7bd4590b482c8972846abee379cbcaef`.

Schema nine freezes for fatal-or-no-progress reason three after accepting only 283,775 of 5,007,304 bytes, decoding seventeen I pictures and displaying fifteen with fourteen swaps; sequence end and session quiet are absent. The first-to-last presentation span is 28,123,416 decoder clocks or 0.4687236 seconds, delivering 29.868349 pictures per second across the short fourteen-interval window. Top-field-first remains correct, audio and PCM errors are clear, no cache-bank or destination overlap error appears and the decode/presentation result otherwise remains coherent. The sole aggregate bit is `0x0200`, `presentation_error`. At the freeze, the scheduler has a released primary pending frame while the optimized overlap decode has already completed the next frame; `pending_frame_valid` and `pending_frame_released` are both set, `ordinary_reference_decode_open` has just closed and the current scheduler intentionally treats completion before predecessor presentation as fatal. The prior measured-latency regression modeled a three-field or approximately 50-millisecond decode and explicitly asserted this early completion must fail. Removing the IQ replay shortened a light all-I picture enough to reach that formerly impossible state. The throughput fix therefore succeeds, but exposes a latent one-slot ordinary-presentation queue limit rather than a decoder, field-order, scaler-mode or pixel fault.

#### Next Steps:

Do not run Bob or BFF on `f866ce2`; they will reach the same field-order-independent scheduler boundary. Obtain approval for one bounded presentation-queue correction that preserves the direct IQ-to-IDCT throughput. Extend only native untimestamped frame-rate-code-four all-I ordinary ownership from one pending identity to the two pending identities physically supported by the three ordinary DDR banks: if an overlap decode completes before its predecessor presents, retain the completed bank in a secondary slot, stop further payload before any bank can be reused, promote that slot when the predecessor swaps and resume into the newly freed bank. Add an accelerated integration regression that reproduces the seventeen-decoded/fifteen-displayed failure, proves sustained 29.97-fps presentation with bounded backpressure and validates premature completion as safe only in this exact native all-I class; retain fatal guards for displayed-bank reuse, bank duplication, P/B, timestamps and all non-native modes. Re-run the complete native, reconstruction and mixed I/P/B suites, clean-build, install through rollback-safe ordinary FTP and restart the four-mode hardware matrix from TFF Weave.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 505 COMMIT Unreleased f866ce2 2026-08-25T03:34:13-07:00

#### Coming From:

Unreleased f866ce2

#### Purpose:

Place the native-interlace cadence fixtures under the MiSTer MediaPlayer directory for convenient hardware validation.

#### Outcome:

The existing `/media/fat/_cadence` directory was copied, not moved, to `/media/fat/MediaPlayer/_cadence` using only ordinary FTP with the default MiSTer `root` and `1` login and no SSH. All eighteen files were downloaded from the original folder, uploaded into the new folder and downloaded again; every source and destination SHA-256 pair matched. The copied set includes the TFF and BFF light-motion fixtures required for commit `f866ce2`, the longer interlaced fixtures, the step-hold diagnostic, the preserved cadence RBF and the existing MGL controls. The original `/media/fat/_cadence` contents remain intact, and no RBF, Main, helper, configuration or media outside the new copy was changed.

#### Next Steps:

Reload the installed `f866ce2` core, leave `Native timing pattern` Off, choose `HDMI scaler deinterlacer` Weave and `Interlaced output` Native 480i, then open `MediaPlayer/_cadence/native_480i_tff_light_10s.m2v`. Report motion smoothness, ghosting or flicker and all three LED states, and leave the terminal image displayed for an ordinary-FTP schema-nine capture. Follow with TFF Bob, BFF Weave and BFF Bob only after each preceding result is captured.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 504 COMMIT Unreleased f866ce2 2026-08-25T03:04:24-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Remove the serialized inverse-quantization replay that limits full-D1 all-I playback and publish the approved two-tier output wording.

#### Outcome:

Commit `f866ce2` streams each finalized inverse-quantized coefficient directly into the already-idle IDCT instead of first storing and replaying the complete 64-coefficient block. The parser continues to wait for completed reconstruction before admitting another block, so coefficient order, saturation, mismatch control, IDCT arithmetic and block ownership remain unchanged. The TFF four-picture reconstruction falls from 10,000,059 to 7,926,459 clocks and BFF falls from 10,022,306 to 7,948,706: both remove exactly 2,073,600 clocks, equal to 64 clocks times 8,100 blocks times four pictures. At 60 MHz those results correspond to approximately 30.28 and 30.19 pictures per second including the regression's framing overhead and pass the new 8,008,000-clock four-picture implementation gate for 29.97 fps. All 2,073,600 TFF samples retain the established 9,442 one-LSB differences, all BFF samples retain 9,632, the progressive control retains 69,671 and every case has zero pixels outside the one-LSB IDCT tolerance; the field-DCT rejection control also remains exact. The complete native suite passes stable TFF/BFF order, exhaustive 4:2:0 cache mapping, exact half-line timing, Bob/Weave selection, timing-pattern isolation, safe ownership, measured-latency overlap, ordinary/delayed refill behavior and schema-nine telemetry. The canonical 72-picture mixed I/P/B live-raster soak remains bit-exact at its 6,529,997-clock signature with all publication, prediction, DDR and presentation counters correct and every error clear. The menu now names `HDMI scaler deinterlacer`, and the README, architecture, decoder notes and changelog document processed-HDMI Bob/Weave separately from Native 480i plus MiSTer's external `direct_video` requirement.

A clean Quartus Prime 17.0.2 build completes in 10 minutes 23 seconds with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.128, +0.251, +3.352, +0.449 and +0.925 nanoseconds; focused 60 MHz decoder setup and recovery are +1.543 and +11.393 nanoseconds and focused video setup is +2.658 nanoseconds, all with zero violated paths. The fit uses 28,969 ALMs, 44,696 registers, 3,655,139 block-memory bits, 464 RAM blocks, 67 DSP blocks and three PLLs, reducing the prior Bob/Weave build by 599 ALMs and 819 registers with unchanged memory. The 4,171,412-byte RBF has SHA-256 `acc28e644100e0452e45fcfe9749762d3a690ca8d6da9479cc4a2ac23d736b7b`. Ordinary FTP with the default `root` and `1` login and no SSH first retrieved the active `4e4da3a` image at its known `94d194e36f7deeacaf899934547860366a8649455e8c4f0d15ac51e478d90aff` hash, preserved and round-trip verified it as `/media/fat/MediaPlayer.rbf.rollback-pre-f866ce2`, round-trip verified the staged candidate and then verified the promoted `/media/fat/MediaPlayer.rbf` at the exact candidate hash. The temporary stage was removed; Main, helper, media and MiSTer configuration are unchanged.

#### Next Steps:

Perform a clean Quartus Prime 17.0.2 build and the Phase-1P timing review. If fit and timing pass, stage the exact RBF through ordinary FTP with the default MiSTer `root` and `1` login, retrieve it for byte verification, preserve the current `4e4da3a` image as rollback and promote the candidate without changing Main, helper, media or MiSTer configuration. Reload the core and run the established TFF and BFF light-motion fixtures in both Weave and Bob. Hardware acceptance requires the schema-nine picture rate to reach native 29.97-fps presentation without errors or dropped pictures while retaining the already accepted field order and the expected scaler-mode visual tradeoff.

#### Files Modified:

- `rtl/mpeg2_new/mpeg2_h262_inverse_quant.sv`
- `tools/streams/tb_h262_interlaced_i_reconstruction.sv`
- `MediaPlayer_top_00.svh`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/MPEG2_NEW_DECODER.md`
- `CHANGELOG.md`

#### Status:

- [x] Built
- [ ] Passed

---

## 503 COMMIT Unreleased 4e4da3a 2026-08-25T02:59:35-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Capture the TFF processed-HDMI Bob result and complete field-order validation of the Bob/Weave control.

#### Outcome:

The user ran `_cadence/native_480i_tff_light_10s.m2v` with native 480i active and Bob selected and reports issues broadly similar to BFF Bob with slight visual differences, followed by USER and POWER solid and DISK blinking twice. The untouched terminal image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH; `.ai/current_results/entry503_tff_light_hdmi_bob.png` is 11,865 bytes with SHA-256 `9bfbb7f0595707877835dd38f8b2ab2458086fc83314b037725d742d6d3cb604`. Schema nine accepts all 5,007,304 bytes, preserves top-field-first, reaches sequence end and presentation completion, closes normally for quiet reason one and reports zero aggregate, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors. The wrapped picture and swap counters again represent all 300 pictures and 299 swaps. First presentation is cycle 2,378,246 and last is 719,313,464, so 299 intervals span 716,935,218 cycles or 11.948920 seconds and deliver 25.023181 pictures per second. This differs from BFF Bob by only 304,372 cycles or 5.072867 milliseconds across the whole run, and from the accepted TFF Weave run by only 609,880 cycles or 10.164667 milliseconds; those small decoder-runtime variations cannot explain the reported mode-specific live appearance. The TFF and BFF Bob terminal rasters are structurally equivalent apart from the expected field-marker and field-phase content, while both field orders remain logically exact. The current result therefore closes the discriminator: residual shorter shadows, more frequent visible steps and slight instability are field-order-independent behavior of MiSTer's processed-HDMI Bob reconstruction combined with the separate approximately 25-picture-per-second all-I decoder ceiling, not reversed fields or corruption. Commit `4e4da3a` passes its hardware objective because Bob and Weave are both selectable, preserve native/raw and progressive behavior and expose the intended motion-versus-stability tradeoff without correctness errors.

#### Next Steps:

Freeze the Bob/Weave control and do not attempt another deinterlacer implementation. Retain Weave for users prioritizing stable vertical detail and Bob for users prioritizing shorter motion history, while Native 480i remains the unprocessed external-processing tier. Bundle the already approved menu wording `HDMI scaler deinterlacer` and two-tier documentation with the next materially useful source build rather than spending a Quartus cycle on labels alone. The next technical proposal should address the independent approximately 25-picture-per-second full-D1 all-I throughput ceiling that now dominates the remaining visible jumps, beginning with measured decoder-stage occupancy and a bounded optimization that preserves TFF/BFF timing, field order and the now accepted scaler selection; native direct-video and eventual SDI qualification remain separate until compatible hardware is available.

#### Files Modified:

None.

#### Status:

- [x] Built
- [x] Passed

---

## 502 COMMIT Unreleased 4e4da3a 2026-08-25T02:55:54-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Capture the BFF processed-HDMI Bob result and separate decoder cadence from the scaler's deinterlacing tradeoff.

#### Outcome:

The user ran only `_cadence/native_480i_bff_light_10s.m2v` with native 480i active and Bob selected. The menu disappears normally, motion now appears to run at the right field rate, the historical shadow lags for less time but jumps more frequently and the final image is slightly unstable; USER and POWER remain solid and DISK blinks twice. The untouched terminal image was triggered and retrieved entirely through ordinary FTP with the default `root` and `1` login and no SSH; `.ai/current_results/entry502_bff_light_hdmi_bob.png` is 11,860 bytes with SHA-256 `3970ae3eedcc91b6fa75d2fca0fad253d6aef63d849d4708c9328bfadfabd5b0`. Schema nine accepts all 5,007,154 bytes, preserves bottom-field-first, reaches sequence end and presentation completion, closes normally for quiet reason one and reports zero aggregate, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors. The eight-bit picture and swap counters wrap to 44 and 43 exactly as expected for 300 pictures and 299 swaps. First presentation remains cycle 2,378,235 and last presentation is cycle 719,009,081, so the 299 intervals span 716,630,846 cycles or 11.943847 seconds and deliver 25.033809 pictures per second. The prior Weave run delivered 25.037584 pictures per second and finished only 108,033 decoder cycles or 1.80055 milliseconds earlier across the entire fixture, proving Bob did not materially change decoder throughput or source presentation cadence. The shorter history, more visible steps and live final-image instability instead characterize MiSTer's Bob reconstruction: it removes most long field history by expanding individual fields, at the expected cost of greater vertical jitter and reduced stable vertical detail. BFF core logic passes, while processed-HDMI Bob remains a user-selectable motion-versus-stability tradeoff rather than a universal replacement for Weave.

#### Next Steps:

Keep `Native timing pattern` Off, `HDMI deinterlacer` Bob and `Interlaced output` Native 480i, then run only `_cadence/native_480i_tff_light_10s.m2v`. Compare shadow duration, step frequency and final-image instability directly with this BFF Bob result, report all three LEDs and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Matching clean telemetry and materially similar Bob artifacts will show the residual is field-order-independent scaler behavior and complete the current Bob/Weave control validation; a strong TFF/BFF visual asymmetry would instead require checking how the framework's Bob path interprets field polarity before refining the two-tier menu. Do not change MiSTer configuration or run the native direct-video/SDI tier yet.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 501 COMMIT Unreleased 4e4da3a 2026-08-25T02:50:47-07:00

#### Coming From:

Unreleased 4e4da3a

#### Purpose:

Adopt a permanent two-tier output model serving processed-HDMI viewers and native-480i external-processing users.

#### Outcome:

The user approved two explicit product tiers going forward: a normal processed-HDMI path using MiSTer's scaler with user-selectable Bob or Weave deinterlacing, and a separate Native 480i path that preserves correctly ordered, standards-timed decoded fields for eventual HDMI-to-SDI conversion and high-end external processing. The native tier must not silently deinterlace, scale or field-combine the source, while the convenience tier may use MiSTer's existing reconstruction and should clearly identify that processing in the menu and documentation. The current `4e4da3a` build already supplies native 480i timing and the scaler's Bob/Weave request, but MiSTer's `direct_video` bypass is framework configuration supplied through `cfg[10]`, not a signal this core can switch through its own status menu. Future menu work may select and label the core's intended output tier, but documentation and UI must not imply that this alone enables raw HDMI; actual SDI qualification will use the Native 480i tier together with MiSTer's direct-video setting and a compatible converter or sink.

#### Next Steps:

Complete entry 500's installed-build validation before changing the menu again: run the BFF light-motion fixture with Bob selected, capture visual and schema-nine evidence, then repeat the TFF fixture if BFF passes. After those results settle the processed-HDMI path, propose one bounded menu and documentation refinement that names the processed control `HDMI scaler deinterlacer`, presents Native 480i as the external-processing tier, suppresses or clearly marks irrelevant combinations and documents the separate MiSTer direct-video requirement. Do not implement a core-native deinterlacer or claim SDI readiness until raw-output timing has been tested on a compatible direct-video sink or converter.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 500 COMMIT Unreleased 4e4da3a 2026-08-25T02:45:02-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Expose MiSTer's processed-HDMI Bob/Weave choice without altering native raw 480i or progressive output.

#### Outcome:

Commit `4e4da3a` replaces the hardwired `HDMI_BOB_DEINT=0` with a clock-domain-safe `HDMI deinterlacer` menu control on status bit 124, retaining Weave as the default and asserting MiSTer's existing Bob request only while native interlaced output is active; direct video continues to carry the core's raw fields and progressive output always suppresses the request. The focused selector test passes reset, native Weave, native Bob, progressive suppression and return cases. The complete native timing suite passes stable and changed-order handling, exhaustive 4:2:0 mapping, exact TFF and BFF half-line timing, timing-pattern isolation, ordinary ownership, measured-latency presentation, ordinary and delayed cache refills, cadence-profiler schema and decoder layout. TFF/BFF interlaced reconstruction also passes with zero out-of-tolerance samples and the progressive control remains distinct. The Icarus live-raster wrapper reproduced all functional counts with zero functional errors but ended one scheduler cycle below its fixed wrapper expectation; the independently regenerated input was byte-identical and the canonical Verilator live-raster run passed the exact 6,529,997-cycle expectation with every error counter clear. A clean Quartus 17.0.2 build completed in 10 minutes 59 seconds with zero errors, full-design setup, hold and recovery slack of 0.184, 0.231 and 3.194 nanoseconds, focused decoder setup and recovery slack of 1.357 and 10.515 nanoseconds and focused video setup slack of 2.432 nanoseconds. Fit uses 29,568 ALMs at 71 percent, 45,515 registers, 3,655,139 memory bits at 65 percent, 464 RAM blocks at 84 percent and 67 DSP blocks at 60 percent. The 4,184,000-byte RBF has SHA-256 `94d194e36f7deeacaf899934547860366a8649455e8c4f0d15ac51e478d90aff`; it was uploaded and retrieved under a staging name, promoted through ordinary FTP with the default `root` and `1` login and retrieved again at the exact local hash. The predecessor remains `/media/fat/MediaPlayer.rbf.rollback-pre-4e4da3a` at SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. No helper, Main, media or MiSTer configuration changed.

#### Next Steps:

Reload the core, leave `Native timing pattern` Off, select `HDMI deinterlacer` Bob and `Interlaced output` Native 480i, then run only `_cadence/native_480i_bff_light_10s.m2v`. Judge rightward motion, field-marker order, bob shimmer or vertical-detail loss and specifically whether the long historical bars and retained OSD disappear; report all three LEDs and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Acceptance requires the prior clean logical telemetry plus materially shorter field history than Weave. If BFF Bob passes, run the TFF light-motion fixture second under the same settings. Keep the public native-interlace claim disabled until both are captured, keep raw direct-video qualification separate and defer a core-native deinterlacer unless MiSTer's scaler path proves inadequate or a distinct core-generated 480p mode is approved.

#### Files Modified:

- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- files.qip
- rtl/mpeg2_hdmi_deinterlace_control.sv
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_hdmi_deinterlace_control.sv

#### Status:

- [x] Built
- [ ] Passed

---

## 499 COMMIT Unreleased baf5d2c 2026-08-25T02:06:54-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Capture the BFF hardware run and distinguish core field-order failure from artifacts introduced by the active MiSTer HDMI scaling path.

#### Outcome:

The user ran `_cadence/native_480i_bff_light_10s.m2v`, reports many visible issues and the expected terminal LEDs with USER solid, DISK blinking twice and POWER solid. The untouched terminal image was captured entirely through ordinary FTP with the default login and no SSH; `.ai/current_results/entry498_bff_light_native480i.png` is 11,828 bytes with SHA-256 `e08199714000955a47588255aef8aacd7b9902467458f32e891363342e825332`. Schema nine accepts exactly all 5,007,154 source bytes, reconstructs all 300 reference and displayed pictures and 299 swaps from the wrapped counters, reports stable bottom-field-first with `top_field_first=0`, reaches sequence end and presentation completion and closes normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. First presentation at cycle 2,378,235 and last at 718,901,048 span 716,522,813 cycles, or 11.942047 seconds and 25.037584 pictures per second, materially matching the accepted TFF light-motion rate.

The user's 61,120,546-byte, 14.788667-second Pixel 8 Pro recording `.ai/current_results/PXL_20260825_085714649.mp4` is SHA-256 `4646fc58721626cac3f5da1fcd0d49712f8c93632f602af7ebf90ab6203846a9` and averages 59.775504 captured frames per second. Frame-by-frame review shows the bright current bar progressing monotonically to the right with no field-order backstep or reversal, while a dim historical bar trails many source fields behind and portions of the already closed MiSTer OSD remain visible during startup. The fixture's decoded BFF planes independently place the bottom-field bar at x=40 before the top-field bar at x=44, then advance both four pixels per field; the timing and framebuffer regressions and hardware telemetry preserve that order. Because the OSD is composited after the MPEG framebuffer, its retained shapes cannot originate in decoder DDR or line caches. An ordinary-FTP inspection also finds no active `/media/fat/MiSTer.ini`; the installed example documents `direct_video=0` as the default. The run therefore feeds the core's native 480i into MiSTer's `ascal` path rather than sending raw 480i to HDMI, and `MediaPlayer_top_00.svh` currently hardwires `HDMI_BOB_DEINT=0`, selecting the scaler's weave and field-buffer path. The recording is consistent with field-history retention in that path, potentially compounded by the monitor and phone, not BFF decoding or field-order reversal. BFF logical acceptance passes, but visual acceptance through the current scaled-HDMI weave path does not.

#### Next Steps:

Stop and obtain approval for a revised bounded scaler-path commit before addressing decoder throughput. Add an `HDMI deinterlacer` menu choice using the next free status bit, retain Weave as the existing default and drive MiSTer's already implemented `HDMI_BOB_DEINT` only when native interlaced output is active and Bob is selected; direct-video raw 480i and progressive output must remain unchanged. Add a focused control regression proving progressive always requests no bob, native Weave remains zero and native Bob asserts the framework signal, retain all TFF/BFF timing, framebuffer and presentation regressions, then complete a clean Quartus build and staged ordinary-FTP installation. Rerun BFF light motion in Bob mode first and TFF light motion second, requiring monotonic motion without long historical bars or retained OSD. Do not create or alter `MiSTer.ini` and do not enable `direct_video` without separate user direction; raw-output qualification on a compatible sink remains a later, distinct test, and the public interlace claim stays disabled.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 498 COMMIT Unreleased baf5d2c 2026-08-25T01:54:16-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Reproduce, validate and install the deferred bottom-field-first light-motion fixture without changing the accepted FPGA image.

#### Outcome:

The user approved entry 497's recommendation to skip the no-longer-required moving final-mux pattern and advance to BFF hardware qualification. Two independent invocations of `generate_test_interlaced_i_frames.py --light-visual-seconds 10` reproduce every generated artifact and the complete manifest byte-for-byte. The BFF light-motion fixture contains 300 all-I 720x480 pictures at 30000/1001, is 5,007,154 bytes with encoded SHA-256 `b26d0d4090ec8c39346782918e97eb0721ba0da5670b42ef14435e385f822271`, decodes to YUV420p SHA-256 `554fbf879319392629bb1d3ac7a041358929e0ee2e8fed6a7a05862f9efa65eb`, preserves bottom-field-first `bb` signalling in all pictures and remains decoded-plane-identical before and after the signalling patch. The analyzer retains the intentional interlaced all-I candidate classification and the public compatibility checker deliberately fails because native interlaced support is not publicly enabled. No source or RBF build was needed. The active `/media/fat/MediaPlayer.rbf` was independently retrieved at the exact accepted `2601573` SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. Only the BFF media file was uploaded under a temporary name through ordinary FTP with the default `root` and `1` login and no SSH, retrieved at the local hash, promoted as `/media/fat/_cadence/native_480i_bff_light_10s.m2v`, retrieved again at the same hash and left with no staging file. Helper, Main and existing media files were not changed.

#### Next Steps:

Leave `Native timing pattern` Off, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_bff_light_10s.m2v`. Judge whether the bar continues moving smoothly to the right without field-order reversal, backstep or alternating-field judder, whether the upper and lower field markers remain orderly, and report flicker, combing, horizontal dashes or any other artifact separately from the already classified display-history ghost. Report USER, DISK and POWER after completion and leave the terminal image loaded for an ordinary-FTP schema-nine capture. Acceptance requires all 300 pictures and 299 swaps, stable bottom-field-first telemetry, sequence end and presentation completion, zero aggregate, presentation, destination and cache-bank-overlap errors and a decoder-limited duration comparable to the accepted TFF light-motion run. Keep the public native-interlace compatibility claim disabled until this BFF result is captured; address the independent approximately 25-picture-per-second all-I throughput ceiling afterward.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 497 COMMIT Unreleased baf5d2c 2026-08-25T01:49:06-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Use the user's high-frame-rate recording to classify the step-hold ghost before spending a Quartus cycle on the proposed moving framebuffer-bypass pattern.

#### Outcome:

The user supplied `.ai/current_results/PXL_20260825_084158381.mp4`, a 68,665,532-byte, 16.631233-second 1920x1080 H.264 Pixel 8 Pro recording at an average 59.706937 frames per second and SHA-256 `d2a4d296d8dd9f86ee6cacc341992b144722b741be35b46606d441a199782386`. Frame-by-frame review confirms the naked-eye report and materially changes the diagnosis. At a representative jump, the old bar is absent before the transition, becomes visible alongside the immediately present new bar, then alternates between bright, dim and field-striped appearances before fading away over roughly nine captured 30-fps samples; during the same interval the new bar alternates between complete and field-striped appearances and then stabilizes. The two stationary horizontal references remain stable throughout. That gradual, intensity-weighted temporal decay and alternating reconstruction is characteristic of downstream field-history processing by the display scaler or deinterlacer, potentially compounded by the phone's own temporal video processing, rather than binary stale DDR or line-cache pixels. The user's direct visual observation establishes that the effect exists before the camera, while the recording exposes its temporal structure. Combined with the pair-identical decoded source, zero old-position source pixels, clean cache and destination telemetry, a clean terminal framebuffer and the static framebuffer-bypass result, this is strong enough to clear framebuffer corruption as the working diagnosis and supersedes entry 496's need to modify cache RTL. It is not a mathematical replacement for a moving final-mux bypass, but that build is now confirmation rather than a prerequisite.

#### Next Steps:

Stop and obtain approval to supersede entry 496's moving-bypass build. If approved, make no RTL or RBF change for this ghost and treat it as downstream interlace reconstruction on the present display; optionally confirm later with deinterlacing disabled, a game mode, a different native-480i display or the moving final-mux pattern if a public compatibility claim requires formal isolation. Advance the core qualification instead to the already deferred bottom-field-first hardware case: regenerate and validate the established BFF light-motion fixture byte-identically, install only that media file through staged ordinary FTP with the default MiSTer login, then run it in native 480i and capture field order, motion, LEDs and schema-nine telemetry before addressing the independent approximately 25-picture-per-second all-I throughput ceiling. Keep the public native-interlace compatibility claim disabled until BFF passes.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 496 COMMIT Unreleased baf5d2c 2026-08-25T01:38:31-07:00

#### Coming From:

Unreleased baf5d2c

#### Purpose:

Record the pair-identical TFF step-hold hardware result and separate framebuffer persistence from downstream motion-adaptive interlace processing before changing cache RTL.

#### Outcome:

The user ran only `_cadence/native_480i_tff_step_hold_10s.m2v` with `Native timing pattern` Off and native 480i active. There is no flicker, combing, horizontal dashes or other steady-state artifact, and the picture looks excellent. At each discrete bar jump, however, the old position remains slightly visible for approximately half a second while the new position initially appears to be missing alternating scan lines; the new bar then becomes complete and the old position disappears fully. Playback completes and all three LED indications pass. The untouched terminal frame was captured entirely through ordinary FTP with the default MiSTer login and no SSH. `.ai/current_results/entry495_tff_step_hold.png` is 7,689 bytes with SHA-256 `37d7e8687b28b258a1b1d4e996609bb5c49f98235e72967e9e2d1f00fbde84fc`; it shows one complete current bar and no old-position residue after stabilization.

Schema nine accepts all 3,483,304 bytes, reconstructs all 300 reference and displayed pictures and 299 swaps from the wrapped counters, preserves top-field-first, reaches sequence end and presentation completion and closes normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear, and no destination holds occur. The first presentation at cycle 2,332,280 and last at cycle 706,661,049 span 704,328,769 cycles, or 11.738813 seconds and 25.471060 pictures per second. The terminal still and telemetry therefore show that the transient resolves rather than accumulating into a corrupt frame.

The fixture makes two conclusions firm. Its decoded validator proves both authored fields are identical, the current position is complete in adjacent field rows, every prior non-current position is background after a jump and the maximum adjacent-field row delta is zero; therefore neither an encoded old bar nor ordinary one-field temporal separation can last half a second. The static video-domain pattern previously proved decode and DDR traffic do not perturb native sync or the final mux. But the earlier plan's statement that persistence would by itself prove stale framebuffer content was too strong: a downstream television, scaler or capture device doing motion-adaptive deinterlacing can also retain several prior fields after a discontinuous motion step and can temporarily reconstruct only alternating lines at the new position. Because the prior bypass pattern was static, it could not distinguish that external temporal processing from the framebuffer and line caches. The clear cache-bank-overlap flag excludes only a refill into the line-cache bank currently being scanned and does not settle the broader framebuffer case.

#### Next Steps:

Stop before changing framebuffer or cache RTL and obtain approval for one moving video-domain discriminator. Extend `Native timing pattern` from Off/Static to Off/Static bars/Step-hold, with the new mode generating the same narrow field-invariant bar directly after the framebuffer, holding each position for thirty complete output frames and jumping ninety-six pixels while MPEG decode and DDR traffic continue underneath. Regress exact native timing, pair-identical fields, hold length, jump positions and unchanged static-pattern behavior, then build and install one RBF through the established staged ordinary-FTP process. Replay the same TFF file with the video-domain Step-hold mode enabled. If the approximately half-second ghost and incomplete new lines repeat, the artifact is downstream display processing and the FPGA pixel path is cleared; if the bypass bar changes cleanly while the decoded bar does not, the fault is inside framebuffer publication or line-cache generation and the following RTL cycle should instrument current display-bank identity and per-line cache generation. Continue to defer BFF, throughput optimization and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---

## 495 COMMIT Unreleased baf5d2c 2026-08-25T01:30:20-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Create and install the pair-identical step-hold TFF fixture that distinguishes stale framebuffer pixels from authored temporal interlace and downstream display persistence.

#### Outcome:

Commit `baf5d2c` adds `--step-hold-visual-seconds` to the deterministic interlaced all-I generator without changing its established default, sustained-motion or low-complexity-motion outputs. The new source authors an eight-pixel bright bar identically in both fields, holds each position for sixty 60000/1001 source fields or thirty 30000/1001 output pictures, then jumps ninety-six pixels; two stationary horizontal references remain while alternating field markers are deliberately absent. A permanent decoded-plane validator checks every frame, proves the current bar bright in both adjacent field rows, checks every previous non-current position remains background after each jump and records zero maximum difference between representative adjacent field rows. Independent generations reproduce byte-identical TFF and BFF outputs, retain the exact four-picture baseline hashes, preserve patched-versus-unpatched decoded-plane equality, contain 300 all-I pictures with the intended field order and remain deliberately rejected by the public compatibility checker. The 3,483,304-byte TFF fixture is SHA-256 `71f00b8f8c919857fe8c92bec9f0dfd440493650573ef0ae4bc0ac4b7754f4df`; its decoded YUV420 plane hash is `cf629eaefc50ffb89d83450332cd312828390bcdc94454d45e823139edfe8544`, and nine decoded jumps contain no prior-position residue. Its byte-identical regeneration was uploaded under a staging name and retrieved at the local hash, promoted as `/media/fat/_cadence/native_480i_tff_step_hold_10s.m2v`, retrieved again at the same hash and only then had the stage removed, entirely through ordinary FTP with the default MiSTer login and no SSH. The BFF counterpart remains local and deferred. The installed RBF was independently retrieved unchanged at the exact `2601573` hash `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`; helper and Main were not touched.

#### Next Steps:

Turn `Native timing pattern` Off, keep `Interlaced output` at `Native 480i` and run only `_cadence/native_480i_tff_step_hold_10s.m2v`. The narrow white bar should remain fixed for about one authored second and then jump ninety-six pixels nine times; after each jump judge whether the old position disappears immediately or within one field or frame, or remains visibly stuck for a material fraction of the next hold, and note any comb, flicker or horizontal dashes. Report USER, DISK and POWER and leave the final image loaded for an FTP-only schema-nine capture. Immediate clean disappearance places the earlier continuous-motion shadow in ordinary interlaced temporal presentation or downstream display processing, while persistence into the hold proves stale framebuffer, cache or frame-bank content and requires a targeted field/cache identity RTL diagnostic. Continue to defer BFF, throughput optimization and any public native-interlace compatibility claim.

#### Files Modified:

- tools/streams/generate_test_interlaced_i_frames.py

#### Status:

- [x] Built
- [ ] Passed

---
## 494 COMMIT Unreleased 2601573 2026-08-25T01:26:01-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Record the native timing-pattern hardware discriminator and relocate the remaining motion artifacts to framebuffer or field-content presentation.

#### Outcome:

The user enabled `Native timing pattern`, kept native 480i active and replayed `_cadence/native_480i_tff_light_10s.m2v`; the eight static vertical bars remained absolutely unchanged throughout playback and looked as if no file had been launched, while USER and POWER stayed solid and DISK blinked twice. The untouched terminal pattern was captured entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry493_native_timing_pattern.png` is 7,336 bytes with SHA-256 `8a34c6f8bd0de81cc8f6bd9f02a165626e7a629c547f7d294f26da16140a61da`. The image shows eight clean full-height bars with stable vertical boundaries and no short horizontal dashes or changing ghost edge. Schema nine proves the apparently static view concealed a complete active decode: all 5,007,304 bytes were accepted, the wrapped counters represent 300 reference and displayed pictures and 299 swaps, top-field-first stayed stable, sequence end and presentation completion occurred and the snapshot closed normally for quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. The 299 presentation intervals span 716,738,843 cycles from cycle 2,378,246 to 719,117,089, or 11.945647 seconds and 25.030037 pictures per second, materially identical to the normal-video run's 25.044486 pictures per second. Decoder and DDRAM traffic therefore continued without perturbing the video-domain pattern, decisively excluding the native sync clock, field cadence and final output mux as the cause of playback-induced flicker, transient dashes or moving ghost content. Earlier progressive and native terminal stills also show the same completed 32-pixel-wide authored bar with bright interior and combed boundaries, so a still cannot distinguish the user's live persistence report from normal temporal field separation; the remaining diagnostic boundary is dynamic framebuffer and field-content presentation, while the independent approximately 25-picture decoder ceiling remains below the 29.97-picture source.

#### Next Steps:

Stop before changing RTL and obtain approval for one content-only framebuffer discriminator. Extend the deterministic interlaced generator with a narrow bar whose two authored fields are identical and whose position holds for approximately one second before a large discrete step, then generate and upload only the TFF fixture through ordinary FTP without changing the accepted RBF. Long static holds remove continuous-motion and bar-width ambiguity: if the old position disappears within the next field or frame and each held position is clean, the original comb and apparent shadow are authored temporal interlace or downstream display processing; if the old position persists materially into the hold, the framebuffer cache or frame-bank handoff is retaining stale pixels and the next RTL cycle should instrument field and cache identity. Keep `Native timing pattern` Off for that fixture, continue to defer BFF and do not make a public native-interlace compatibility claim. Treat the separate 25-picture-per-second decoder throughput ceiling as a later optimization rather than mixing it into this artifact discriminator.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 493 COMMIT Unreleased 2601573 2026-08-25T01:20:24-07:00

#### Coming From:

Unreleased 2601573

#### Purpose:

Record the three-bank native TFF hardware result and advance to the framebuffer-independent timing-pattern discriminator.

#### Outcome:

The user reloaded the exact `2601573` image, left `Native timing pattern` Off and ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode. Playback feels faster but still lags the nominal source, flicker is reduced but remains, the transient one-pixel-high short dashes are gone, combing remains and the moving vertical bar can leave a temporarily stationary shadow while it continues rightward. USER and POWER are solid and DISK blinks twice. The untouched terminal screenshot was triggered and retrieved entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry492_tff_native480i_overlap.png` is 11,867 bytes with SHA-256 `2d8a9ae24dc9d5ffc7d38d1707a197694c29f239a808c18bcb3e3d4a58985d84`. Schema nine accepts all 5,007,304 bytes and its wrapped counters represent all 300 reference and displayed pictures and 299 swaps, with stable top-field-first signalling, sequence end, presentation completion and normal quiet reason one. Aggregate, decoder, presentation, destination, cache-bank-overlap, audio-underrun and PCM-protocol errors are all clear. The first presentation is at cycle 2,378,291 and the last at 718,703,629, so the 299 intervals span 716,325,338 cycles, 11.938756 seconds or 25.044486 pictures per second. The overlap therefore removes the prior deterministic 15.004885-picture serialization and exceeds the predicted approximately 20.10-picture baseline because that earlier progressive measurement also included ordinary presentation waiting; the remaining approximately 40-millisecond decoder throughput is still below the 29.97-picture source and explains the residual lag. Presentation hold collapses from the prior run's hundreds of millions of cycles to 108,513 cycles, while the disappearance of the short dashes and reduced flicker show that their severity was coupled to the old stop-and-resume schedule even though the clear cache-overlap flag still rules out only the monitored same-bank refill collision. The still preserves the authored interlaced edge structure but cannot determine whether the reported temporary moving shadow is an intended field-time separation or stale pixel delivery; the static timing pattern is now the required discriminator.

#### Next Steps:

Without changing the RBF, enable `Native timing pattern`, keep `Interlaced output` at `Native 480i` and replay only `_cadence/native_480i_tff_light_10s.m2v`. The moving source will be hidden behind eight static vertical color bars while decoder and DDRAM activity continue, so judge whether the bars flicker, acquire transient horizontal dashes, shimmer at their vertical boundaries or leave any changing ghost edge; report USER, DISK and POWER and leave the terminal pattern image loaded for a second FTP-only capture. Stable bars with ordinary telemetry will place the remaining comb and moving shadow in framebuffer or field-content presentation rather than native sync timing, while flickering or changing bars will retain the timing/output path as the cause. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 492 COMMIT Unreleased 2601573 2026-08-25T01:09:18-07:00

#### Coming From:

Unreleased f6f2fe4

#### Purpose:

Remove the avoidable native all-I decode/presentation serialization and add a framebuffer-independent native timing pattern for the remaining flicker and short-line isolation.

#### Outcome:

Commit `2601573` implements the approved bounded native correction and diagnostic. The presentation scheduler permits exactly one native, untimestamped, frame-rate-code-four I picture to decode into the existing third ordinary frame region while its released predecessor waits for a complete-frame native swap boundary. Admission requires the decode bank to differ from both the visible and pending banks, retains the completed-bank identity for the whole transaction, rejects any destination change into the visible bank, rejects completion before the predecessor presents and leaves timestamped, progressive, P, B and scratch-frame behavior on the established serialized paths. A measured-latency integration regression models the hardware's approximately 50-millisecond all-I decode time across twenty real native frame windows: the old path reproduces ten decoded and ten displayed pictures, or approximately 15 fps, while the overlap path produces thirteen decoded and thirteen displayed pictures, or the decoder-limited approximately 20 fps, with no presentation error. Separate negative cases prove that a P header cannot enter the exception, a displayed-bank destination is fatal and premature completion cannot overwrite the pending predecessor.

The new `Native timing pattern` menu option selects eight field-invariant vertical bars only when native output is active. It replaces the final framebuffer RGB, data-enable and sync source while the decoder, DDRAM, cache refill, scheduler and cadence profiler continue running underneath, so playback with the pattern enabled distinguishes native timing/output artifacts from framebuffer and line-cache pixel delivery without changing the 480i raster. The pattern contains no horizontal one-line detail and its RTL regression proves blanking, sync passthrough, all eight bar boundaries and structural field invariance. Exact TFF and BFF timing, field order, exhaustive interlaced 4:2:0 mapping, measured presentation latency, safe/unsafe ordinary ownership, ordinary and delayed cache refill, schema-nine cadence profiling and decoding, scheduler rate codes one through five, timestamp cadence floor, dense three-bank publication, the progressive live-raster DDR soak and TFF/BFF/progressive reconstruction all pass. The legacy Cycle-A wrapper retains its established three fixed-expectation nonzero cases, while every emitted functional result remains complete and error-free.

The clean from-scratch Quartus Prime 17.0.2 build finishes in 11:07 with zero errors and 144 established warnings. Global setup, hold, recovery, removal and minimum-pulse-width margins are respectively +0.386, +0.245, +4.208, +0.566 and +0.925 nanoseconds. Focused decoder setup and recovery margins are +0.881 and +11.444 nanoseconds, and video setup is +2.076 nanoseconds, with zero violated paths. The fit uses 29,554 of 41,910 ALMs, 45,539 registers, 3,655,139 block-memory bits, 464 RAM blocks, 65 DSP blocks and three PLLs. The 4,195,444-byte RBF has SHA-256 `67bd360b0efa1864ca5184049ad6dfd9fc2edc006421871309c2c0be9de70969`. Installation used only ordinary FTP with the default `root` / `1` login and no SSH keys. The prior active 4,192,152-byte RBF was independently retrieved at SHA-256 `9f60f116d145fde30e93de7db17bfc525168db0e5781f7d167f04ee2b5c01904` and preserved byte-identically as `/media/fat/MediaPlayer.rbf.rollback-pre-2601573`. The new image was uploaded under a staging name, retrieved at its local hash, promoted, retrieved again from `/media/fat/MediaPlayer.rbf` at the same hash and only then had the temporary stage removed. Helper, Main and media files were not changed.

#### Next Steps:

Reload the Media Player core, leave `Native timing pattern` Off, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_tff_light_10s.m2v`. Observe the apparent duration, motion continuity, approximately 60 Hz flicker and transient one-pixel-high short dashes, report USER, DISK and POWER and leave the final image loaded for an FTP-only schema-nine capture. Acceptance is all 300 pictures and 299 swaps with zero aggregate and ownership errors, and a presentation span near the established approximately 14.87-second decoder-limited progressive result rather than the previous approximately 19.93-second serialized native result. After that normal-video capture, enable `Native timing pattern`, replay the same file and report whether the bars themselves flicker or acquire transient short lines; do not run that second isolation view before the normal telemetry is captured. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_00.svh
- MediaPlayer_top_01.svh
- MediaPlayer_top_05.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- files.qip
- rtl/mpeg2_native_timing_pattern.sv
- rtl/mpeg2_new/mpeg2_h262_b_presentation_scheduler.sv
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_h262_b_presentation_scheduler.sv
- tools/streams/tb_h262_dense_publication_order.sv
- tools/streams/tb_h262_live_raster_soak.sv
- tools/streams/tb_native_480i_presentation_integration.sv
- tools/streams/tb_native_480i_timing_pattern.sv
- tools/streams/tb_native_ordinary_overlap_ownership.sv

#### Status:

- [x] Built
- [ ] Passed

---
## 491 COMMIT Unreleased f6f2fe4 2026-08-25T00:24:32-07:00

#### Coming From:

Unreleased f6f2fe4

#### Purpose:

Record the cadence-corrected native TFF hardware result, test the new cache-bank-overlap hypothesis and identify the remaining half-rate mechanism.

#### Outcome:

The user reloaded the exact `f6f2fe4` image, ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode and reports approximately the same speed as before, unchanged approximately 60 Hz flicker and the same quantity of transient tiny horizontal lines during playback. USER and POWER remain solid and DISK blinks twice. The untouched terminal screenshot was triggered and retrieved entirely through ordinary FTP with the default MiSTer login and no SSH; `.ai/current_results/entry490_tff_light_native480i_cadencefix.png` is 11,945 bytes with SHA-256 `1af6b303238d82fa3fc03840ad92c93afe0402923b100ef462a7eb0417c61d1a`. Schema nine accepts all 5,007,304 bytes, reconstructs 300 reference and displayed pictures and 299 swaps from the wrapped counters, preserves stable `top_field_first=1`, sees sequence end and presentation completion and reaches normal quiet reason one. Every aggregate, decoder, presentation, destination, cache, audio-underrun and PCM-protocol error is clear, including the new `cache_bank_overlap_error`; the tested same-bank active-scan refill collision therefore did not occur. First presentation is at 2,378,243 cycles and the last at 1,197,988,906 cycles, so the 299 intervals occupy 1,195,610,663 cycles, or 19.926844 seconds and 15.004885 pictures per second. This is materially identical to entry 489's 14.988809 pictures per second and proves the cadence-window separation did not remove the half-rate behavior. The integrated regression's immediate synthetic feeder hid the actual limiting interaction. The same fixture's progressive diagnostic baseline takes 14.874526 seconds, or approximately 49.75 milliseconds per decoded picture. Native output offers a complete-frame presentation boundary every 33.37 milliseconds, but `ordinary_reference_waiting` asserts `presentation_hold` while one decoded reference waits for that boundary. Decode therefore resumes only after presentation, completes approximately 49.75 milliseconds later, misses the immediately following native frame boundary and waits to the next one; the serial decode-plus-window quantization deterministically becomes about 66.73 milliseconds per picture, or 14.99 pictures per second. The synthetic feeder publishes a new completed frame immediately after the pending slot clears and thus proves cadence arithmetic without modeling measured decode latency or the real hold. The settled raster does not contain the transient short lines, and the clear overlap flag rules out only the specific monitored collision rather than every cache or output-path mechanism.

#### Next Steps:

With explicit user approval, replace the immediate-feeder integration case with a measured-latency ordinary-reference regression that reproduces the current approximately 15-picture-per-second native result through the real `presentation_hold` path. Then use the already implemented third ordinary DDR frame region to permit exactly one queued ordinary reference while a prior reference awaits its safe complete-frame boundary, with explicit ownership assertions preventing decode from targeting the displayed or pending bank and with all established I, P and B presentation regressions retained. The corrected measured-latency regression must approach the decoder-limited approximately 20.10-picture-per-second baseline without changing native field order or the 59.94-field raster. In the same diagnostic build, add a selectable native video-domain timing pattern that bypasses decoder DDR and line caches while preserving the exact 480i timing, so one hardware run can determine whether the flicker and transient short lines originate in the timing/output path or only during framebuffer refill. Rebuild and install only after timing closure, then rerun the TFF fixture for cadence and the bypass pattern for artifact isolation. Continue to defer BFF and any public native-interlace compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
## 490 COMMIT Unreleased f6f2fe4 2026-08-25T00:16:30-07:00

#### Coming From:

Unreleased 8d9043a

#### Purpose:

Correct native 480i frame admission to one presentation per authored frame and add a passive diagnostic for line-cache refill overlap.

#### Outcome:

Commits `6f4e1aa` and `f6f2fe4` implement and close the approved native TFF correction. Native timing now raises the cadence window at logical sample zero of the vertical-blanking tail and raises the frame-admission window one complete logical 13.5 MHz sample later, so the synchronized scheduler applies the second-field credit before testing the physical bank swap. The integrated 54 MHz timing to 60 MHz scheduler regression observes twelve fields, six frame windows and six presentations at 30000/1001 with no coincident cadence and admission pulses; the established synthetic scheduler rates remain unchanged for all five supported rate codes. The framebuffer now passively synchronizes active scan and selected Y/C cache-bank levels into the memory domain and latches a telemetry-only overlap error if a completed DDR refill writes the bank currently being scanned. The ordinary-latency live-raster test remains clear at latency 64 while the forced-delay case deterministically latches overlap at latency 3400, and the schema-nine decoder exposes the new flag. Exact TFF and BFF field timing, exhaustive interlaced cache mapping, stable field-order controls, scheduler rates, cadence profiling, telemetry decoding and fixture generation all pass. The first full compile exposed only the three intentional first-stage 54-to-60 MHz diagnostic synchronizer paths; `f6f2fe4` adds narrowly scoped timing exceptions for those destinations, leaving all second stages and functional logic timed. The exact `f6f2fe4` rebuild completes with zero errors and 144 warnings, 29,434 of 41,910 ALMs, 3,655,139 of 5,662,720 memory bits and 65 of 112 DSP blocks. Worst-case global setup, hold, recovery and removal margins are respectively 0.593, 0.243, 3.336 and 0.531 ns; the decoder and video setup margins are 1.453 and 2.848 ns. The 4,192,152-byte RBF has SHA-256 `9f60f116d145fde30e93de7db17bfc525168db0e5781f7d167f04ee2b5c01904`. It was uploaded, retrieved byte-identically under a staging name and promoted entirely through ordinary FTP with the default MiSTer login and no SSH. `/media/fat/MediaPlayer.rbf` retrieves at the exact new hash, while the known prior 4,210,740-byte image is preserved as `/media/fat/MediaPlayer.rbf.rollback-20260825T0015` at SHA-256 `5544bb48bea6d0f066b01f09f63087d46e7a52438ca60b6872b9f452ef213c09`.

#### Next Steps:

Reload the Media Player core, set `Interlaced output` to `Native 480i` and run only `_cadence/native_480i_tff_light_10s.m2v`. Judge whether playback is materially closer to the progressive diagnostic duration rather than the prior approximately twenty-second half-rate native run, whether the approximately 60 Hz flicker and transient one-pixel-high short dashes are gone or changed, and whether motion and field combing remain orderly. Report USER, DISK and POWER after completion and leave the final image loaded for an FTP-only schema-nine capture. Acceptance requires approximately 20.10 displayed pictures per second for this decoder-limited fixture, all 300 pictures and 299 swaps, zero aggregate errors and a clear new cache-bank-overlap flag. Continue to defer BFF and any public native-interlace compatibility claim until this TFF result passes.

#### Files Modified:

- MediaPlayer.sdc
- MediaPlayer_top_02.svh
- MediaPlayer_top_06.svh
- MediaPlayer_top_07.svh
- rtl/mpeg2_luma_framebuffer.sv
- rtl/mpeg2_video_output_timing.sv
- tools/streams/decode_hardware_cadence.py
- tools/streams/run_native_480i_timing.sh
- tools/streams/tb_native_480i_cache_refill.sv
- tools/streams/tb_native_480i_presentation_integration.sv
- tools/streams/tb_native_480i_timing.sv
- tools/streams/test_decode_hardware_cadence.py

#### Status:

- [x] Built
- [ ] Passed

---
## 489 COMMIT Unreleased 8d9043a 2026-08-24T23:35:44-07:00

#### Coming From:

Unreleased 8d9043a

#### Purpose:

Record the native TFF comparison, identify the exact half-rate native admission defect and distinguish the authored reference lines from transient cache-like playback artifacts.

#### Outcome:

The user ran `_cadence/native_480i_tff_light_10s.m2v` in `Native 480i` mode and reports that the comb-like artifacts improved relative to the progressive weave, the approximately 60 Hz flicker returned and the apparent playback rate seemed similar. USER and POWER remained solid and DISK blinked twice. The user sees two authored full-width gray reference lines, but separately observes many transient one-pixel-high, roughly fifteen-pixel-long horizontal dashes across the screen only while native playback is active; these are not the fixture's reference lines and are absent from the settled terminal still. The 720x480 screenshot was triggered and retrieved entirely through ordinary FTP using the default MiSTer login and no SSH; `.ai/current_results/entry488_tff_light_native480i.png` is 11,916 bytes with SHA-256 `74788181ac9642ef09bba56d2cd70bddf9c0895167f1d1bb9740f7812e891363`. Schema nine accepts all 5,007,304 bytes, reports 300 reference and displayed pictures and 299 swaps after modulo-counter interpretation, preserves stable `top_field_first=1`, sees sequence end and presentation completion and reaches normal quiet reason one with every aggregate, decoder, presentation, destination, cache, audio-underrun and PCM-protocol error clear. First presentation occurs at 2,378,252 cycles and the last at 1,199,271,231 cycles, so the 299 intervals occupy 1,196,892,979 cycles, or 19.948216 seconds. Native presentation therefore sustains 14.988809 pictures per second, materially slower than the same stream's 20.101481-picture progressive diagnostic baseline; the visual rate estimate does not distinguish that difference. RTL inspection identifies the exact deterministic cause. On the non-first native field, `display_field_window` and `display_frame_window` rise together and cross identically into the scheduler as simultaneous cadence and swap pulses. After a presentation, rate-code-four credit is zero; the first field adds 5,652, then the second-field swap evaluates the old 5,652 against the due threshold of 5,723 before its coincident tick is applied, misses that frame window and updates credit to 11,304. The following native frame is therefore admitted, producing one swap every four fields and the measured 14.99-picture rate. The existing native scheduler test incorrectly applies two field ticks and then a separate frame-window pulse, so it proves intended arithmetic but not actual integrated pulse ordering. The settled still shows only the authored full-width references and expected field weave; it cannot capture the transient short dashes. The line-cache error bit currently detects a reader falling more than one complete line behind but does not identify a cache bank being refilled while that same bank is still scanned, leaving a plausible refill-deadline blind spot. The unused 135 MHz PLL output cannot safely replace the current 60 MHz shared decoder/DDRAM clock without a new clock-domain boundary, so the user's historical clock observation is relevant evidence but not yet a safe direct fix.

#### Next Steps:

With explicit user approval, create one bounded native-presentation correction and diagnostic commit. Separate the native frame-window assertion from the second-field cadence assertion by a deterministic logical-sample interval inside vertical blanking, preserving the scheduler's established progressive arithmetic while ensuring the second field's credit is visible before physical bank admission. Replace the synthetic native scheduler test with an integrated timing-to-scheduler regression that reproduces the current simultaneous-pulse half-rate failure and proves one 30000/1001 presentation per two fields after correction. Add a passive sticky line-cache bank-overlap diagnostic and a native delayed-DDR live-raster stress case so the next hardware run can distinguish an actual refill collision from an output-clock symptom without changing clocks or cache depth speculatively. Rebuild and install the exact RBF, rerun only the light TFF fixture in Native 480i, require the decoder-limited rate to match the approximately 20.10-picture progressive baseline rather than 14.99, report flicker and transient dashes and leave the result for FTP-only capture. Continue to defer BFF and the public interlaced compatibility claim.

#### Files Modified:

None.

#### Status:

- [x] Built
- [ ] Passed

---
