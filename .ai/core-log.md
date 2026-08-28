## 650 COMMIT Unreleased ??? 2026-08-27T21:40:57-07:00

#### Coming From:

Unreleased 3e89189

#### Purpose:

Open the field-DCT gate by accepting all-I frame pictures coded with `frame_pred_frame_dct` clear.

#### Outcome:

This entry is written as a plan and its commit does not exist yet; it replaces an earlier field-picture plan that carried the same number and was corrected before any work began. The user directs that fixtures and per-step tests use standard ffmpeg commands. Measurement shows that requirement selects the gate. FFmpeg's `mpeg2video` encoder never emits field pictures: an encode with `+ilme` and `+ildct` at `-top 1` produced fifteen picture coding extensions all carrying `picture_structure` equal to `2'b11`, so a field-picture fixture would require a hand-synthesised bitstream and cannot meet the stated standard. The same tool produces field-DCT content natively. A single all-intra encode with `+ildct` and `-g 1` yields fifteen I pictures, no P or B, frame pictures, `frame_pred_frame_dct` clear, `intra_vlc_format` clear and `alternate_scan` clear, which isolates field DCT with no prediction and requires no second scan table. The field-picture gate is therefore deferred and the field-DCT gate is opened in its place. Today `phase1_supported` at `mpeg2_h262_frontend.sv` line 252 requires `frame_pred_frame_dct` set, and that one bit gates both field DCT and field prediction; relaxing it is safe while `picture_coding_type` remains restricted to `3'b001`, because prediction cannot appear in an all-intra stream. The work is confined to the macroblock layer and the reconstruction line mapping: parse the `dct_type` bit, which is present whenever `frame_pred_frame_dct` is clear in a frame picture, and when it is set map the four luma blocks in field order so blocks zero and one carry the even lines of the macroblock and blocks two and three the odd lines, with 4:2:0 chroma unaffected. One picture still equals one frame, so no picture-to-frame bookkeeping, field pairing, reference publication or presentation change is required, which makes this materially smaller and lower risk than the deferred field-picture work. Verification of the fixture itself is a recorded difficulty rather than an assumption: `ffmpeg -debug mb_type` prints only an intra marker and does not distinguish field DCT, so no offline ffmpeg command proves that any macroblock actually chose `dct_type` equal to one. The decoder will therefore count field-DCT macroblocks in spare telemetry bits and a non-zero count becomes an acceptance criterion, which makes the device under test the oracle for fixture adequacy and directly guards the stale-fixture failure recorded in entry 639. Acceptance additionally requires the new fixture to complete every picture with no decoder or presentation error, sequence end and quiet completion, and requires the existing seven fixtures to be unchanged in accepted byte counts and picture counts with final rasters still pixel-identical to their recorded baselines, because a reconstruction mapping change can corrupt output silently while every counter stays identical. The cadence snapshot must remain readable as schema nineteen so recorded baselines do not break. The build must close timing in every category and any block-memory increase must fit inside the 41 free blocks, none having been recovered by entry 649. This gate does not make commercial discs play; interlaced P and B remains the gate that does, and every other interlaced gate only ever decodes I pictures until it exists. Nothing is built or changed yet, so both status boxes are unchecked.

#### Next Steps:

Write the fixture generator first so the target exists before the decoder changes, using a single standard ffmpeg command at 720 by 480 and frame rate code four with `+ildct` and `-g 1`, and have it verify from the bitstream that every picture is intra, that `picture_structure` is a frame picture and that `frame_pred_frame_dct`, `alternate_scan`, `intra_vlc_format`, `repeat_first_field`, `chroma_420_type` and `progressive_frame` all hold the expected values. Then relax the frontend predicate, add `dct_type` parsing to the macroblock layer, apply the field-order luma mapping in reconstruction, and add the field-DCT macroblock counter. Establish the ALM and block-memory cost from the first successful fit before adding further logic, check the weakest margin across all clocks rather than the decoder alone, and reseed rather than restructure if the HDMI domain is the category that fails. Regression must cover the seven existing fixtures as well as the new one. Do not widen scope to field pictures, interlaced P or B, `repeat_first_field` or 576i inside this cycle. Record the field-picture fixture obstacle so a later cycle does not rediscover it, since that gate will need either a non-ffmpeg generator or a real disc sample and that choice needs the user's direction. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_field_dct.py
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_hardware_cadence_profiler.sv

#### Status:

- [ ] Built
- [ ] Passed

---

## 650 COMMIT Unreleased ??? 2026-08-27T21:33:30-07:00

#### Coming From:

Unreleased 3e89189

#### Purpose:

Open the field-picture gate by accepting and reconstructing I/I field pairs at 720 by 480.

#### Outcome:

This entry is written as a plan and its commit does not exist yet. The inert width change of entry 648 is reverted by `3e89189`, whose two files now match the v0.8.0 source exactly, and optimization work is closed with the free-block position unchanged at 41. Field pictures are today refused by one term, `picture_structure` equal to `2'b11`, in the `phase1_supported` predicate at `mpeg2_h262_frontend.sv` line 252, with matching guards in `mpeg2_h262_p_syntax_probe.sv` at lines 526 and 609 and `mpeg2_h262_p_residual_parser_420.sv` at line 377. Removing that term is trivial and everything behind it is the work, which falls into two parts. Reconstruction addressing is the smaller: `mpeg2_h262_ddram_store_420p.sv` line 77 fixes a luma stride of 90 words and a chroma stride of 45, one full row per step across 480 rows, whereas a field picture codes 240 lines that land on alternate frame lines and therefore needs a doubled stride and a base offset selected by field parity. That is an addressing change rather than a capacity change and is currently expected to cost little or no additional block memory, which matters because none was recovered. Picture-to-frame bookkeeping is the larger: two coded pictures now form one displayed frame, so `mpeg2_h262_picture_bookkeeper` must accumulate both fields into one frame bank and assert `picture_420_complete` only on the second field, leaving picture counting, reference publication, presentation swap and the cadence telemetry consistent with one displayed frame per pair rather than per coded picture. The bounded scope is I pictures in both fields, 720 by 480, frame rate code four, 4:2:0, no `repeat_first_field`, with every other current restriction retained; field DCT, interlaced P and B, `repeat_first_field` and 576i stay rejected. One expectation is recorded so it is not mistaken later for a defect: a typical commercial DVD codes the two fields of an I frame as I then P, so this gate unlocks the coded structure but does not by itself make commercial discs play, and interlaced P remains the gate that does. Validation needs a fixture that does not exist yet, to be produced by a committed deterministic script under `tools/streams/` and generated locally by the user in the manner of the seven-test suite. Acceptance requires the new fixture to complete every picture with correct field parity and no swapped or doubled lines, zero decoder and presentation errors, sequence end and quiet completion, and it equally requires the existing seven fixtures to be unaffected, with identical accepted byte counts and picture counts and final rasters still pixel-identical to their recorded baselines. The build must close timing in every category and any block-memory increase must fit inside the 41 free blocks. Nothing is built or changed yet, so both status boxes are unchecked.

#### Next Steps:

Write the fixture generator first so the target is testable before the decoder changes, then relax the frontend predicate under the bounded conditions, then add field-parity addressing to the DDR store, then pair fields in the bookkeeper, keeping the cadence snapshot backward compatible so the existing decode tool continues to read schema nineteen rather than breaking every recorded baseline. Establish the ALM and block-memory cost from the first successful fit before adding any further logic, and check the weakest margin across all clocks rather than the decoder alone, reseeding rather than restructuring if the HDMI domain is the category that fails. Regression must cover the seven existing fixtures as well as the new one, because a reconstruction addressing change can corrupt frame-picture output silently while every counter stays identical, exactly as the entry 649 analysis showed telemetry cannot detect coefficient corruption. Do not widen scope to field DCT or interlaced P inside this cycle even if the structure appears to allow it. Preserve restricted core.md and the forty-entry ring.

#### Files Modified:

- tools/streams/generate_test_field_pictures.py
- rtl/mpeg2_new/mpeg2_h262_frontend.sv
- rtl/mpeg2_new/mpeg2_h262_ddram_store_420p.sv
- rtl/mpeg2_new/mpeg2_h262_picture_bookkeeper.sv

#### Status:

- [ ] Built
- [ ] Passed

---

