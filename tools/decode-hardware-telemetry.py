#!/usr/bin/env python3
"""Decode the machine-readable cadence overlay from a MiSTer PNG."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import cv2


MAGIC = 0x4D4D5031
X0 = 8
WORDS = 64
DIAGNOSTIC_Y0 = 344
NATIVE_480I_Y0 = 224
SCHEMA17_DIAGNOSTIC_Y0 = 352
SCHEMA17_NATIVE_480I_Y0 = 232
SCHEMA16_DIAGNOSTIC_Y0 = 356
SCHEMA16_NATIVE_480I_Y0 = 236
SCHEMA15_DIAGNOSTIC_Y0 = 408
SCHEMA15_NATIVE_480I_Y0 = 288
SCHEMA14_DIAGNOSTIC_Y0 = 428
SCHEMA14_NATIVE_480I_Y0 = 308
SCHEMA10_DIAGNOSTIC_Y0 = 436
SCHEMA10_NATIVE_480I_Y0 = 316
LEGACY_DIAGNOSTIC_Y0 = 444
LEGACY_NATIVE_480I_Y0 = 324
CELL = 4
ROW_PREFIX = (1, 0, 1, 0)


class TelemetryDecodeError(RuntimeError):
    pass


def _cell_bit(image: Any, y_origin: int, column: int, row: int) -> int:
    x0 = X0 + column * CELL + 1
    y0 = y_origin + row * CELL + 1
    pixels = image[y0:y0 + 2, x0:x0 + 2]
    return int(int(pixels.sum()) >= 128 * pixels.size)


def _decode_image_words(image: Any) -> list[int]:
    height, width = image.shape[:2]
    minimum_width = X0 + 43 * CELL
    if width < minimum_width:
        raise TelemetryDecodeError(
            f"image is {width}x{height}; telemetry requires at "
            f"least {minimum_width} horizontal pixels"
        )

    layouts = (
        (SCHEMA17_DIAGNOSTIC_Y0, 62),
        (SCHEMA17_NATIVE_480I_Y0, 62),
        (SCHEMA16_DIAGNOSTIC_Y0, 61),
        (SCHEMA16_NATIVE_480I_Y0, 61),
        (DIAGNOSTIC_Y0, WORDS),
        (NATIVE_480I_Y0, WORDS),
        (SCHEMA15_DIAGNOSTIC_Y0, 48),
        (SCHEMA15_NATIVE_480I_Y0, 48),
        (SCHEMA14_DIAGNOSTIC_Y0, 43),
        (SCHEMA14_NATIVE_480I_Y0, 43),
        (SCHEMA10_DIAGNOSTIC_Y0, 41),
        (SCHEMA10_NATIVE_480I_Y0, 41),
        (LEGACY_DIAGNOSTIC_Y0, 38),
        (LEGACY_NATIVE_480I_Y0, 38),
    )
    failures: list[str] = []
    for y_origin, word_count in layouts:
        if height < y_origin + word_count * CELL:
            continue
        try:
            words: list[int] = []
            for row in range(word_count):
                bits = [
                    _cell_bit(image, y_origin, column, row)
                    for column in range(43)
                ]
                if tuple(bits[:4]) != ROW_PREFIX:
                    raise TelemetryDecodeError(
                        f"row {row}: telemetry prefix absent ({bits[:4]})"
                    )
                encoded_row = 0
                for bit in bits[4:10]:
                    encoded_row = (encoded_row << 1) | bit
                if encoded_row != row:
                    raise TelemetryDecodeError(
                        f"row {row}: encoded row index is {encoded_row}"
                    )
                word = 0
                for bit in bits[10:42]:
                    word = (word << 1) | bit
                if bits[42] != (word.bit_count() & 1):
                    raise TelemetryDecodeError(f"row {row}: parity mismatch")
                words.append(word)

            if words[0] != MAGIC:
                raise TelemetryDecodeError(f"bad magic 0x{words[0]:08x}")
            declared_words = (words[1] >> 16) & 0xFF
            if declared_words != word_count:
                raise TelemetryDecodeError(
                    f"snapshot declares {declared_words} words, "
                    f"layout has {word_count}"
                )
            checksum = 0
            for word in words[:-1]:
                checksum ^= word
            if checksum != words[-1]:
                raise TelemetryDecodeError(
                    f"checksum mismatch 0x{checksum:08x}/"
                    f"0x{words[-1]:08x}"
                )
            return words
        except TelemetryDecodeError as exc:
            failures.append(f"y={y_origin} words={word_count}: {exc}")

    raise TelemetryDecodeError(
        f"image is {width}x{height}; no supported telemetry "
        f"layout decoded ({'; '.join(failures)})"
    )


def decode_words(path: Path | str) -> list[int]:
    source = cv2.imread(str(path), cv2.IMREAD_COLOR)
    if source is None:
        raise TelemetryDecodeError(f"could not read image: {path}")

    height, width = source.shape[:2]
    candidates = [source]
    for size in ((800, 600), (720, 480)):
        if (width, height) != size:
            candidates.append(
                cv2.resize(source, size, interpolation=cv2.INTER_NEAREST)
            )

    failures: list[str] = []
    for image in candidates:
        try:
            return _decode_image_words(image)
        except TelemetryDecodeError as exc:
            failures.append(str(exc))

    raise TelemetryDecodeError(
        f"no telemetry decoded from {width}x{height} image "
        f"({'; '.join(failures)})"
    )


def parse_words(words: list[int]) -> dict[str, Any]:
    format_word = words[1]
    schema_version = (format_word >> 24) & 0xFF
    if schema_version > 22:
        raise TelemetryDecodeError(f"unsupported telemetry schema {schema_version}")
    clock_hz = (format_word & 0xFFFF) * 1000
    counts = words[17]
    metadata = words[18]
    cadence_cycles = words[6]
    display_swaps = counts & 0xFF
    cadence_seconds = cadence_cycles / clock_hz if clock_hz else 0.0
    delivered_fps = (
        display_swaps / cadence_seconds if cadence_seconds > 0.0 else 0.0
    )
    snapshot_meta = words[25]
    terminal = words[35]
    scheduler = words[36]
    current_write_read_layout = (
        schema_version >= 16 and bool((words[40] >> 13) & 1)
    )

    def provenance_event(
        meta_index: int,
        generation_index: int,
        raw_index: int | None = None,
        display_index: int | None = None,
    ) -> dict[str, Any] | None:
        if schema_version < 16:
            return None
        meta = words[meta_index]
        generations = words[generation_index]
        return {
            "expected_row": (meta >> 21) & 0x7FF,
            "tagged_row": (meta >> 10) & 0x7FF,
            "expected_bank": (meta >> 9) & 1,
            "tagged_bank": (meta >> 8) & 1,
            "expected_generation": (generations >> 24) & 0xFF,
            "tagged_generation": (generations >> 16) & 0xFF,
            "raw_fingerprint": words[raw_index] if raw_index is not None else None,
            "display_fingerprint": (
                words[display_index] if display_index is not None else None
            ),
        }

    def scheduler_flags(state: int) -> dict[str, Any]:
        result = {
            "reorder_active": bool(state & (1 << 0)),
            "run_closed": bool(state & (1 << 1)),
            "decode_inflight": bool(state & (1 << 2)),
            "scratch0_pending": bool(state & (1 << 3)),
            "scratch1_pending": bool(state & (1 << 4)),
            "next_present_scratch_bank": bool(state & (1 << 5)),
            "future_frame_pending": bool(state & (1 << 6)),
            "future_reference_pending": bool(state & (1 << 7)),
            "scratch_presented": bool(state & (1 << 8)),
            "run_picture_count": (state >> 9) & 0x3,
            "overlap_decode_open": bool(state & (1 << 11)),
            "overlap_frame_pending": bool(state & (1 << 12)),
            "queued_run_active": bool(state & (1 << 13)),
            "queued_run_closed": bool(state & (1 << 14)),
            "queued_decode_inflight": bool(state & (1 << 15)),
            "queued_scratch0_pending": bool(state & (1 << 16)),
            "queued_scratch1_pending": bool(state & (1 << 17)),
            "queued_future_frame_pending": bool(state & (1 << 18)),
            "queued_future_reference_pending": bool(state & (1 << 19)),
            "queued_run_picture_count": (state >> 20) & 0x3,
            "queued_overlap_decode_open": bool(state & (1 << 22)),
            "queued_overlap_frame_pending": bool(state & (1 << 23)),
            "decode_generation_queued": bool(state & (1 << 24)),
            "promotion_pending": bool(state & (1 << 25)),
            "pending_frame_valid": bool(state & (1 << 26)),
            "pending_frame_released": bool(state & (1 << 27)),
            "terminal_boundary_pending": bool(state & (1 << 28)),
            "queued_first_scratch_bank": bool(state & (1 << 29)),
            "last_bound_reference_valid": bool(state & (1 << 30)),
            "scheduler_presentation_complete": bool(state & (1 << 31)),
        }
        return result

    def gap(rank: int, word_index: int) -> dict[str, Any]:
        cycles = words[word_index]
        metadata = words[word_index + 1]
        state = words[word_index + 2]
        result = {
            "rank": rank,
            "cycles": cycles,
            "seconds": cycles / clock_hz if clock_hz else 0.0,
            "display_picture_ordinal": (metadata >> 24) & 0xFF,
            "presentation_hold": bool((metadata >> 23) & 1),
            "destination_hold": bool((metadata >> 22) & 1),
            "fifo_pending": bool((metadata >> 21) & 1),
            "decoder_ready": bool((metadata >> 20) & 1),
            "scratch_available": bool((metadata >> 19) & 1),
            "promotion_active": bool((metadata >> 18) & 1),
            "frame_waiting": bool((metadata >> 17) & 1),
            "presentation_complete": bool((metadata >> 16) & 1),
            "presentation_error": bool((metadata >> 15) & 1),
            "sequence_end_seen": bool((metadata >> 14) & 1),
            "session_quiet": bool((metadata >> 13) & 1),
            "completed_frame_bank": (metadata >> 11) & 0x3,
            "display_frame_bank": (metadata >> 9) & 0x3,
            "display_scratch": bool((metadata >> 8) & 1),
            "display_scratch_bank": (metadata >> 7) & 1,
            "scheduler_debug_word": state,
            "scheduler_flags": scheduler_flags(state),
        }
        if schema_version >= 9:
            result.update(
                {
                    "timestamp_candidate_active": bool((metadata >> 6) & 1),
                    "timestamp_candidate_due": bool((metadata >> 5) & 1),
                    "cadence_slot": bool((metadata >> 4) & 1),
                    "candidate_presentable": bool((metadata >> 3) & 1),
                    "swap_window_pulse": bool((metadata >> 2) & 1),
                }
            )
        return result

    result = {
        "schema_version": schema_version,
        "snapshot_words": (format_word >> 16) & 0xFF,
        "decoder_clock_hz": clock_hz,
        "accepted_bytes": words[2],
        "session_cycles": words[3],
        "first_present_cycle": words[4],
        "last_present_cycle": words[5],
        "cadence_cycles": cadence_cycles,
        "cadence_seconds": cadence_seconds,
        "delivered_fps": delivered_fps,
        "decoder_stall_cycles": words[7],
        "presentation_stall_cycles": words[8],
        "destination_stall_cycles": words[9],
        "i_stall_cycles": words[10],
        "p_stall_cycles": words[11],
        "b_stall_cycles": words[12],
        "prediction_requests": words[13],
        "prediction_request_wait_cycles": words[14],
        "prediction_response_cycles": words[15],
        "writer_wait_cycles": words[16],
        "reference_pictures": (counts >> 24) & 0xFF,
        "b_pictures": (counts >> 16) & 0xFF,
        "display_pictures": (counts >> 8) & 0xFF,
        "display_swaps": display_swaps,
        "frame_rate_code": (metadata >> 28) & 0xF,
        "final_picture_type": (metadata >> 25) & 0x7,
        "final_temporal_reference": (metadata >> 15) & 0x3FF,
        "reference_picture_count": (metadata >> 7) & 0xFF,
        # Entry 410 (schema 8): the previously reserved low seven bits of
        # word 18 hold the saturated peak PCM FIFO occupancy.
        "pcm_fifo_peak": metadata & 0x7F,
        "error_flags": (words[19] >> 16) & 0xFFFF,
        "cache_bank_overlap_error": bool((words[19] >> 28) & 1),
        "audio_underrun": bool((words[19] >> 26) & 1),
        "pcm_protocol_error": bool((words[19] >> 27) & 1),
        # Entry 365 (schema 5): the formerly reserved low half of word 19
        # carries the presentation-clock seconds count and the two field
        # flags.  Neither flag is consumed by presentation yet.
        "stc_seconds": (words[19] >> 2) & 0x3FFF,
        # Entry 369 (schema 6): word 35 spare bits carry in-band record
        # telemetry -- how many metadata records the fabric extracted and
        # the low bits of the most recent timestamp.
        # Entry 372 (schema 7): the timestamp reported is now that of the
        # frame being displayed, carried through reordering, not the last
        # record extracted.
        "associated_count": (words[35] >> 11) & 0xFF,
        "display_pts_low11": words[35] & 0x7FF,
        "top_field_first": (words[19] >> 1) & 0x1,
        "repeat_first_field": words[19] & 0x1,
        # Entry 282: unconditional hold attribution.  These are NOT mutually
        # exclusive with each other or with the stall counters above, so they
        # must not be summed against them.
        "presentation_hold_total_cycles": words[20],
        "destination_hold_total_cycles": words[21],
        "hold_overlap_cycles": words[22],
        "hold_scratch_available_cycles": words[23],
        "hold_promotion_pending_cycles": (
            None if schema_version >= 9 else words[24]
        ),
        # Entry 468 (schema 9): word 24 becomes two saturated admission-
        # conflict counts. Schema 9's credits diagnostic begins at second 500;
        # Entry 511 schema 10 restores whole-session capture for short native
        # fixtures while retaining backward-compatible schema-9 decoding.
        "late_window_start_seconds": (
            0 if schema_version >= 10 else
            500 if schema_version >= 9 else None
        ),
        "timestamp_delay_conflicts": (
            (words[24] >> 16) & 0xFFFF if schema_version >= 9 else None
        ),
        "timestamp_advance_conflicts": (
            words[24] & 0xFFFF if schema_version >= 9 else None
        ),
        "snapshot_reason_code": (snapshot_meta >> 30) & 0x3,
        "snapshot_reason": {
            1: "quiet",
            2: "forced_terminal_timeout",
            3: "fatal_or_no_progress",
        }.get((snapshot_meta >> 30) & 0x3, "unknown"),
        # Entry 410 (schema 8): the formerly reserved middle field carries
        # the saturated count of PCM samples extracted into the FPGA path.
        "pcm_sample_count": (snapshot_meta >> 16) & 0x3FFF,
        "gap_outlier_count": snapshot_meta & 0xFFFF,
        "largest_display_gaps": [gap(1, 26), gap(2, 29), gap(3, 32)],
        "completed_frame_bank": (terminal >> 30) & 0x3,
        "display_frame_bank": (terminal >> 28) & 0x3,
        "display_scratch": bool((terminal >> 27) & 1),
        "display_scratch_bank": (terminal >> 26) & 1,
        "frame_waiting": bool((terminal >> 25) & 1),
        "presentation_hold": bool((terminal >> 24) & 1),
        "destination_hold": bool((terminal >> 23) & 1),
        "session_quiet": bool((terminal >> 22) & 1),
        "sequence_end_seen": bool((terminal >> 21) & 1),
        "presentation_complete": bool((terminal >> 20) & 1),
        "presentation_error": bool((terminal >> 19) & 1),
        "scheduler_debug_word": scheduler,
        "scheduler_flags": scheduler_flags(scheduler),
        # Entry 511 (schema 10): three appended words observe the boundary
        # between a scheduler bank swap and actual framebuffer publication.
        "framebuffer_reset_count": (
            (words[37] >> 16) & 0xFFFF if schema_version >= 10 else None
        ),
        "framebuffer_publication_count": (
            words[37] & 0xFFFF if schema_version >= 10 else None
        ),
        "framebuffer_unpublished_reset_count": (
            (words[38] >> 16) & 0xFFFF if schema_version >= 10 else None
        ),
        "framebuffer_prefill_miss_count": (
            words[38] & 0xFFFF if schema_version >= 10 else None
        ),
        "framebuffer_max_publication_latency_cycles": (
            words[39] if schema_version >= 10 else None
        ),
        "framebuffer_max_publication_latency_seconds": (
            words[39] / clock_hz
            if schema_version >= 10 and clock_hz else None
        ),
        # Entry 516 (schema 11): three appended words expose the per-field
        # readout invariants that whole-picture counters cannot see.
        # Word 40 carries two saturating eight-bit per-generation DDR fetch
        # counts.  A native field is served 240 luma rows, so 255 means "at
        # least 255" and arises only when one generation spans several frames.
        "framebuffer_last_first_field_fetches": (
            (words[40] >> 24) & 0xFF if schema_version >= 11 else None
        ),
        "framebuffer_last_second_field_fetches": (
            (words[40] >> 16) & 0xFF if schema_version >= 11 else None
        ),
        # Entry 517 retired the per-parity displayed-line counts, which read
        # 240/240 while the field carried no picture.  Schema 12 reuses their
        # bits for the DDR region each parity's fetch actually resolved into.
        "framebuffer_last_first_field_lines": (
            (words[40] >> 8) & 0xFF if schema_version == 11 else None
        ),
        "framebuffer_last_second_field_lines": (
            words[40] & 0xFF if schema_version == 11 else None
        ),
        "framebuffer_last_first_field_region": (
            (words[40] >> 3) & 0x7 if schema_version >= 12 else None
        ),
        "framebuffer_last_second_field_region": (
            words[40] & 0x7 if schema_version >= 12 else None
        ),
        "framebuffer_field_region_mismatch_count": (
            (words[41] >> 8) & 0xFF if schema_version >= 13
            else (words[41] >> 16) & 0xFFFF if schema_version == 12 else None
        ),
        # Entry 519 (schema 13) records the luma content returned in the last
        # framebuffer generation. Entry 520 (schema 14) retains the same bit
        # layout but accumulates it across the complete profiler session.
        "framebuffer_content_scope": (
            "session" if schema_version >= 14
            else "last_generation" if schema_version == 13 else None
        ),
        "framebuffer_first_field_varied": (
            bool((words[40] >> 15) & 1) if schema_version >= 13 else None
        ),
        "framebuffer_second_field_varied": (
            bool((words[40] >> 14) & 1) if schema_version >= 13 else None
        ),
        "framebuffer_first_field_signature": (
            (words[41] >> 24) & 0xFF if schema_version >= 13 else None
        ),
        "framebuffer_second_field_signature": (
            (words[41] >> 16) & 0xFF if schema_version >= 13 else None
        ),
        "framebuffer_field_line_imbalance_count": (
            (words[41] >> 16) & 0xFFFF if schema_version == 11 else None
        ),
        "framebuffer_sequence_phase_error_count": (
            words[41] & 0xFF if schema_version >= 13
            else words[41] & 0xFFFF if schema_version >= 11 else None
        ),
        # The historical schema-15 interpretation remains available for old
        # screenshots. Entry 531 marks the one current diagnostic in word 40
        # and reuses words 42-46 for accepted-write versus raw-DDR readback.
        "framebuffer_last_first_field_raw_fingerprint": (
            words[42]
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_last_first_field_display_fingerprint": (
            words[43]
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_last_second_field_raw_fingerprint": (
            words[44]
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_last_second_field_display_fingerprint": (
            words[45]
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_first_field_fingerprint_count": (
            (words[46] >> 24) & 0xFF
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_second_field_fingerprint_count": (
            (words[46] >> 16) & 0xFF
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_first_field_fingerprint_mismatch_count": (
            (words[46] >> 8) & 0xFF
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_second_field_fingerprint_mismatch_count": (
            words[46] & 0xFF
            if schema_version >= 15 and not current_write_read_layout else None
        ),
        "framebuffer_write_read_scope": (
            "accepted_luma_write_to_raw_ddr_return"
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_first_expected_valid": (
            bool((words[40] >> 12) & 1)
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_second_expected_valid": (
            bool((words[40] >> 11) & 1)
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_region": (
            (words[40] >> 8) & 0x7
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_first_expected_fingerprint": (
            words[42] if current_write_read_layout else None
        ),
        "framebuffer_write_read_first_raw_fingerprint": (
            words[43] if current_write_read_layout else None
        ),
        "framebuffer_write_read_second_expected_fingerprint": (
            words[44] if current_write_read_layout else None
        ),
        "framebuffer_write_read_second_raw_fingerprint": (
            words[45] if current_write_read_layout else None
        ),
        "framebuffer_write_read_first_count": (
            (words[46] >> 24) & 0xFF
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_second_count": (
            (words[46] >> 16) & 0xFF
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_first_mismatch_count": (
            (words[46] >> 8) & 0xFF
            if current_write_read_layout else None
        ),
        "framebuffer_write_read_second_mismatch_count": (
            words[46] & 0xFF if current_write_read_layout else None
        ),
        # Entry 525 (schema 16): per-line cache provenance keeps ownership/tag
        # failures distinct from content failures with matching tags.
        "framebuffer_first_field_tag_mismatch_count": (
            (words[47] >> 24) & 0xFF if schema_version >= 16 else None
        ),
        "framebuffer_second_field_tag_mismatch_count": (
            (words[47] >> 16) & 0xFF if schema_version >= 16 else None
        ),
        "framebuffer_first_field_content_mismatch_count": (
            (words[47] >> 8) & 0xFF if schema_version >= 16 else None
        ),
        "framebuffer_second_field_content_mismatch_count": (
            words[47] & 0xFF if schema_version >= 16 else None
        ),
        "framebuffer_first_field_first_tag_mismatch": provenance_event(48, 49),
        "framebuffer_second_field_first_tag_mismatch": provenance_event(50, 51),
        "framebuffer_first_field_first_content_mismatch": provenance_event(
            52, 53, 54, 55
        ),
        "framebuffer_second_field_first_content_mismatch": provenance_event(
            56, 57, 58, 59
        ),
        # Entry 548 (schema 17): address-sensitive fetch evidence.  A healthy
        # native generation sweeps first-field rows 0..478 plus prefill rows 0
        # and 2, whose XOR is 2, and second-field rows 1..479, whose XOR is 0.
        # A repeated or wrong row set changes the signature; the existing fetch
        # counts cannot, being attributed only by row parity.
        "framebuffer_first_field_row_xor": (
            (words[60] >> 23) & 0x1FF if schema_version >= 17 else None
        ),
        "framebuffer_second_field_row_xor": (
            (words[60] >> 14) & 0x1FF if schema_version >= 17 else None
        ),
        "framebuffer_first_field_region_changed": (
            bool((words[60] >> 13) & 1) if schema_version >= 17 else None
        ),
        "framebuffer_second_field_region_changed": (
            bool((words[60] >> 12) & 1) if schema_version >= 17 else None
        ),
        # Entry 549 (schema 18): does the fetched word actually reach the line
        # cache for that parity?  A healthy generation writes 242*90=21780
        # first-field and 240*90=21600 second-field words, with 16-bit address
        # sums of 48766 and 32656.  Nothing before this counted cache writes.
        "framebuffer_first_field_cache_writes": (
            (words[61] >> 16) & 0xFFFF if schema_version >= 18 else None
        ),
        "framebuffer_second_field_cache_writes": (
            words[61] & 0xFFFF if schema_version >= 18 else None
        ),
        "framebuffer_first_field_cache_addr_sum": (
            (words[62] >> 16) & 0xFFFF if schema_version >= 18 else None
        ),
        "framebuffer_second_field_cache_addr_sum": (
            words[62] & 0xFFFF if schema_version >= 18 else None
        ),
        "checksum": words[-1],
    }

    if schema_version >= 19:
        # Schemas 19 and later retire the framebuffer-detail payload. Never
        # expose reused words as framebuffer fields, even if a legacy marker
        # happens to match.
        for key in result:
            if key.startswith("framebuffer_"):
                result[key] = None
        result["display_pictures_8bit"] = result["display_pictures"]
        result["display_swaps_8bit"] = result["display_swaps"]

        if schema_version >= 21:
            # Entry 884: schemas 21 and 22 overlay words 37..54 with authored-menu
            # pipeline telemetry. The exact full-width display counters and
            # deadline records are therefore unavailable in schema 21. Schema
            # 22 restores the display counters in word 58 below.
            overlay_counts = words[38]
            overlay_commits = words[39]
            overlay_publications = words[43]
            overlay_state = words[44]
            overlay_capture = words[54]
            overlay_highlight = words[47]
            result.update({
                "display_counts_saturated": None,
                "delivered_fps": None,
                "deadline_scope": None,
                "deadline_gap_count": None,
                "deadline_records": [],
                "overlay_scope": "authored_menu_pipeline",
                "overlay_debug_magic": words[37],
                "overlay_debug_magic_ascii": words[37].to_bytes(
                    4, "big"
                ).decode("ascii", errors="replace"),
                "overlay_debug_magic_valid": words[37] == 0x4F564C31,
                "overlay_config_records": overlay_counts & 0xFF,
                "overlay_data_records": (overlay_counts >> 8) & 0xFF,
                "overlay_commit_records": (overlay_counts >> 16) & 0xFF,
                "overlay_style_records": (overlay_counts >> 24) & 0xFF,
                "overlay_plane_publications": overlay_commits & 0xFF,
                "overlay_commit_ok": (overlay_commits >> 8) & 0xFF,
                "overlay_commit_bad": (overlay_commits >> 16) & 0xFF,
                "overlay_clear_records": (overlay_commits >> 24) & 0xFF,
                "overlay_record_bytes": words[40],
                "overlay_plane_bytes": words[41],
                "overlay_cache_rows": words[42] & 0xFFFF,
                "overlay_writer_accepts": (words[42] >> 16) & 0xFFFF,
                "overlay_style_publications": (
                    overlay_publications >> 24
                ) & 0xFF,
                "overlay_memory_plane_publications": (
                    overlay_publications >> 16
                ) & 0xFF,
                "overlay_video_publications": (
                    overlay_publications >> 8
                ) & 0xFF,
                "overlay_memory_style_publish_pending": bool(
                    overlay_publications & 1
                ),
                "overlay_memory_plane_publish_pending": bool(
                    overlay_publications & 2
                ),
                "overlay_memory_protocol_error": bool(
                    overlay_publications & 4
                ),
                "overlay_current_command": (overlay_state >> 24) & 0xFF,
                "overlay_write_word_index": (overlay_state >> 10) & 0x3FFF,
                "overlay_write_byte_lane": (overlay_state >> 7) & 0x7,
                "overlay_display_bank": (overlay_state >> 6) & 1,
                "overlay_published_visible": bool(overlay_state & (1 << 5)),
                "overlay_published_menu": bool(overlay_state & (1 << 4)),
                "overlay_plane_publish_pending": bool(
                    overlay_state & (1 << 3)
                ),
                "overlay_style_publish_pending": bool(
                    overlay_state & (1 << 2)
                ),
                "overlay_protocol_error": bool(overlay_state & (1 << 1)),
                "overlay_record_ready": bool(overlay_state & 1),
                "overlay_published_x1": (words[45] >> 16) & 0xFFFF,
                "overlay_published_y1": words[45] & 0xFFFF,
                "overlay_published_x2": (words[46] >> 16) & 0xFFFF,
                "overlay_published_y2": words[46] & 0xFFFF,
                "overlay_highlight_index1_abgr": overlay_highlight,
                "overlay_highlight_index1_alpha": (
                    overlay_highlight >> 24
                ) & 0xFF,
                "overlay_highlight_index1_blue": (
                    overlay_highlight >> 16
                ) & 0xFF,
                "overlay_highlight_index1_green": (
                    overlay_highlight >> 8
                ) & 0xFF,
                "overlay_highlight_index1_red": overlay_highlight & 0xFF,
                "overlay_received_plane_bytes": words[48] & 0x1FFFF,
                "overlay_video_row_tags": words[49] & 0xFFFF,
                "overlay_video_row_matches": words[50],
                "overlay_video_highlights": words[51],
                "overlay_video_alpha": words[52],
                "overlay_video_magenta": words[53],
                "overlay_capture_reason_code": (overlay_capture >> 30) & 0x3,
                "overlay_capture_reason": {
                    1: "settled_overlay_commit",
                    2: "bounded_no_commit_fallback",
                }.get((overlay_capture >> 30) & 0x3, "unknown"),
                "overlay_capture_armed": bool(overlay_capture & (1 << 29)),
                "overlay_capture_commit_seen": bool(
                    overlay_capture & (1 << 28)
                ),
                "overlay_capture_settle_cycles": overlay_capture & 0x0FFFFFFF,
                "overlay_capture_settle_seconds": (
                    (overlay_capture & 0x0FFFFFFF) / clock_hz
                    if clock_hz else None
                ),
                "audio_pcm_dequeue_count": None,
                "display_pts_lateness_valid": None,
                "display_pts_lateness_ticks": None,
                "display_pts_lateness_seconds": None,
                "candidate_pts_lateness_valid": None,
                "candidate_pts_lateness_ticks": None,
                "candidate_pts_lateness_seconds": None,
                "candidate_unavailable_windows": None,
                "cadence_blocked_windows": None,
                "timestamp_blocked_windows": None,
            })
        else:
            result["display_pictures"] = words[37] >> 16
            result["display_swaps"] = words[37] & 0xFFFF
            result["reference_pictures"] = words[38] >> 16
            result["display_counts_saturated"] = (
                result["display_pictures"] == 0xFFFF or
                result["display_swaps"] == 0xFFFF
            )
            result["delivered_fps"] = (
                result["display_swaps"] / cadence_seconds
                if cadence_seconds and not result["display_counts_saturated"]
                else None
            )
            result["deadline_gap_count"] = words[38] & 0xFFFF

        if schema_version >= 20:
            # Entry 693: the longest single stall of the shared transport byte
            # path is what the audio FIFO depth must cover; the underrun count
            # reports recurrence the first-error snapshot latch cannot.
            result["transport_block_longest_cycles"] = words[55]
            result["transport_block_longest_ms"] = (
                words[55] * 1000.0 / clock_hz if clock_hz else None
            )
            result["transport_block_count"] = (words[56] >> 16) & 0xFFFF
            result["audio_underrun_count"] = words[56] & 0xFFFF
            result["audio_fifo_floor"] = words[57] & 0x3FFF
            result["audio_fifo_floor_ms"] = (words[57] & 0x3FFF) / 48.0
        else:
            for key in (
                "transport_block_longest_cycles", "transport_block_longest_ms",
                "transport_block_count", "audio_underrun_count",
                "audio_fifo_floor", "audio_fifo_floor_ms",
            ):
                result[key] = None
        if schema_version >= 22:
            display_progress = words[58]
            result["display_pictures"] = display_progress >> 16
            result["display_swaps"] = display_progress & 0xFFFF
            result["display_counts_saturated"] = (
                result["display_pictures"] == 0xFFFF or
                result["display_swaps"] == 0xFFFF
            )
            result["delivered_fps"] = (
                result["display_swaps"] / cadence_seconds
                if cadence_seconds and not result["display_counts_saturated"]
                else None
            )
            result["audio_pcm_dequeue_count"] = words[59]

            def signed_word(value: int) -> int:
                return value - (1 << 32) if value & 0x80000000 else value

            progress_flags = words[62]
            display_lateness_valid = bool(progress_flags & (1 << 31))
            candidate_lateness_valid = bool(progress_flags & (1 << 30))
            display_lateness = signed_word(words[60])
            candidate_lateness = signed_word(words[61])
            result.update({
                "display_pts_lateness_valid": display_lateness_valid,
                "display_pts_lateness_ticks": (
                    display_lateness if display_lateness_valid else None
                ),
                "display_pts_lateness_seconds": (
                    display_lateness / 90000.0
                    if display_lateness_valid else None
                ),
                "candidate_pts_lateness_valid": candidate_lateness_valid,
                "candidate_pts_lateness_ticks": (
                    candidate_lateness if candidate_lateness_valid else None
                ),
                "candidate_pts_lateness_seconds": (
                    candidate_lateness / 90000.0
                    if candidate_lateness_valid else None
                ),
                "candidate_unavailable_windows": (
                    progress_flags >> 20
                ) & 0x3FF,
                "cadence_blocked_windows": (progress_flags >> 10) & 0x3FF,
                "timestamp_blocked_windows": progress_flags & 0x3FF,
            })

        if schema_version >= 21:
            return result

        result["deadline_scope"] = "native_30000_1001_after_first_swap"
        result["deadline_records"] = []
        flag_bits = {
            "native_active": 23, "decoder_input_pending": 22,
            "decoder_ready": 21, "upstream_fifo_pending": 20,
            "presentation_hold": 19, "destination_hold": 18,
            "writer_capacity_blocked": 17, "writer_write": 16,
            "writer_busy": 15, "candidate_presentable": 14,
            "cadence_slot": 13, "timestamp_candidate_active": 12,
            "timestamp_candidate_due": 11, "frame_waiting": 10,
            "reference_complete": 9, "sequence_end_seen": 8,
            "presentation_error": 7, "display_scratch": 6,
            "first_reference_seen": 1,
        }
        # Entry 693: schema 20 spends the third deadline record on audio block
        # telemetry, so only two remain readable.
        deadline_slots = 2 if schema_version >= 20 else 3
        for index in range(min(result["deadline_gap_count"], deadline_slots)):
            base = 39 + index * 8
            meta, cycle, flags, age, starvation, capacity, delay, byte = \
                words[base:base + 8]
            result["deadline_records"].append({
                "display_picture_ordinal": meta >> 16,
                "completed_reference_count": meta & 0xFFFF,
                "deadline_session_cycle": cycle,
                "flags_word": flags,
                **{name: bool(flags & (1 << bit))
                   for name, bit in flag_bits.items()},
                "display_frame_bank": (flags >> 4) & 3,
                "completed_frame_bank": (flags >> 2) & 3,
                "last_reference_completion_age_cycles": age,
                "input_starved_cycles_since_previous_swap": starvation,
                "writer_capacity_blocked_cycles_since_previous_swap": capacity,
                "candidate_ready_delay_cycles": None if delay == 0xFFFFFFFF else delay,
                "accepted_bytes_at_deadline": byte,
            })
    return result


def decode(path: Path | str) -> dict[str, Any]:
    return parse_words(decode_words(path))


def format_word_dump(words: list[int]) -> str:
    schema_version = (words[1] >> 24) & 0xFF
    checksum = 0
    for word in words[:-1]:
        checksum ^= word

    lines = [
        f"{len(words)}-word schema-{schema_version} snapshot.",
        "All omitted words are 00000000.",
        f"All {len(words)} prefixes, row indices, and parity bits passed.",
        f"XOR checksum calculated {checksum:08x} and matched word "
        f"{len(words) - 1}.",
        "",
    ]
    lines.extend(
        f"{index:02d}  {word:08x}"
        for index, word in enumerate(words)
        if word
    )
    return "\n".join(lines)


def validate(
    result: dict[str, Any],
    expected_pictures: int | None = None,
    expected_bytes: int | None = None,
    require_fps: float | None = None,
) -> list[str]:
    failures: list[str] = []
    if result["error_flags"]:
        failures.append(f"hardware error flags 0x{result['error_flags']:04x}")
    if expected_pictures is not None:
        if result["display_pictures"] != expected_pictures:
            failures.append(
                f"displayed {result['display_pictures']} pictures, "
                f"expected {expected_pictures}"
            )
        if result["reference_pictures"] + result["b_pictures"] != expected_pictures:
            failures.append(
                "reference+B completion count does not equal expected pictures"
            )
        if result["display_swaps"] != max(expected_pictures - 1, 0):
            failures.append(
                f"observed {result['display_swaps']} swaps, expected "
                f"{max(expected_pictures - 1, 0)}"
            )
    if expected_bytes is not None and result["accepted_bytes"] != expected_bytes:
        failures.append(
            f"accepted {result['accepted_bytes']} bytes, expected {expected_bytes}"
        )
    if require_fps is not None and result["delivered_fps"] is None:
        failures.append(
            "exact delivered rate unavailable: full-width display counters "
            "are absent or saturated"
        )
    elif require_fps is not None and result["delivered_fps"] + 1e-9 < require_fps:
        failures.append(
            f"delivered {result['delivered_fps']:.6f} fps, "
            f"required {require_fps:.6f} fps"
        )
    if result.get("overlay_scope") is not None:
        if not result["overlay_debug_magic_valid"]:
            failures.append(
                "bad overlay telemetry magic "
                f"0x{result['overlay_debug_magic']:08x}"
            )
        if result["overlay_memory_protocol_error"]:
            failures.append("overlay memory-domain protocol error")
        if result["overlay_protocol_error"]:
            failures.append("overlay engine protocol error")
    if result["framebuffer_write_read_scope"] is not None:
        if not result["framebuffer_write_read_first_expected_valid"]:
            failures.append("first-field accepted-write fingerprint is invalid")
        if not result["framebuffer_write_read_second_expected_valid"]:
            failures.append("second-field accepted-write fingerprint is invalid")
        if result["framebuffer_write_read_first_count"] == 0:
            failures.append("no first-field write/read comparison completed")
        if result["framebuffer_write_read_second_count"] == 0:
            failures.append("no second-field write/read comparison completed")
        if result["framebuffer_write_read_first_mismatch_count"]:
            failures.append("first-field accepted-write/raw-read mismatch")
        if result["framebuffer_write_read_second_mismatch_count"]:
            failures.append("second-field accepted-write/raw-read mismatch")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("--expected-pictures", type=int)
    parser.add_argument("--expected-bytes", type=int)
    parser.add_argument("--require-fps", type=float)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--word-dump", action="store_true")
    args = parser.parse_args()

    try:
        words = decode_words(args.screenshot)
    except TelemetryDecodeError as exc:
        parser.error(str(exc))

    if args.word_dump:
        print(format_word_dump(words), end="")
        return 0

    result = parse_words(words)
    failures = validate(
        result,
        expected_pictures=args.expected_pictures,
        expected_bytes=args.expected_bytes,
        require_fps=args.require_fps,
    )
    result["validation_failures"] = failures

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        if result["delivered_fps"] is None:
            print(
                "hardware cadence: low-byte counters="
                f"{result['display_pictures_8bit']} pictures/"
                f"{result['display_swaps_8bit']} swaps in "
                f"{result['cadence_seconds']:.6f} s; exact rate unavailable"
            )
        else:
            print(
                f"hardware cadence: {result['display_pictures']} pictures, "
                f"{result['display_swaps']} intervals in "
                f"{result['cadence_seconds']:.6f} s = "
                f"{result['delivered_fps']} fps"
            )
        print(
            "stalls: decoder={decoder_stall_cycles} "
            "presentation={presentation_stall_cycles} "
            "destination={destination_stall_cycles} "
            "I/P/B={i_stall_cycles}/{p_stall_cycles}/{b_stall_cycles}".format(
                **result
            )
        )
        print(
            "prediction: requests={prediction_requests} "
            "request_wait={prediction_request_wait_cycles} "
            "response={prediction_response_cycles}; "
            "writer_wait={writer_wait_cycles}".format(**result)
        )
        print(
            "holds: presentation={presentation_hold_total_cycles} "
            "destination={destination_hold_total_cycles} "
            "overlap={hold_overlap_cycles} "
            "scratch_free={hold_scratch_available_cycles} "
            "promotion={hold_promotion_pending_cycles}".format(**result)
        )
        print(
            "snapshot: {snapshot_reason}; outlier_gaps={gap_outlier_count}; "
            "terminal completed/display={completed_frame_bank}/{display_frame_bank} "
            "waiting={frame_waiting} hold={presentation_hold} "
            "complete={presentation_complete} error={presentation_error}".format(
                **result
            )
        )
        if result["schema_version"] >= 9:
            print(
                "late-window: start={late_window_start_seconds}s "
                "timestamp_delay={timestamp_delay_conflicts} "
                "timestamp_advance={timestamp_advance_conflicts}".format(
                    **result
                )
            )
        if 10 <= result["schema_version"] <= 18:
            print(
                "framebuffer: resets={framebuffer_reset_count} "
                "publications={framebuffer_publication_count} "
                "unpublished_resets={framebuffer_unpublished_reset_count} "
                "prefill_misses={framebuffer_prefill_miss_count} "
                "max_latency={framebuffer_max_publication_latency_cycles}cy/"
                "{framebuffer_max_publication_latency_seconds:.6f}s".format(
                    **result
                )
            )
        if 13 <= result["schema_version"] <= 18:
            print(
                "field content: scope={framebuffer_content_scope} "
                "varied={framebuffer_first_field_varied}/"
                "{framebuffer_second_field_varied} "
                "signatures={framebuffer_first_field_signature:#04x}/"
                "{framebuffer_second_field_signature:#04x}".format(**result)
            )
        if result["framebuffer_write_read_scope"] is not None:
            print(
                "write/read fingerprints: first expected/raw="
                "{framebuffer_write_read_first_expected_fingerprint:#010x}/"
                "{framebuffer_write_read_first_raw_fingerprint:#010x} "
                "second expected/raw="
                "{framebuffer_write_read_second_expected_fingerprint:#010x}/"
                "{framebuffer_write_read_second_raw_fingerprint:#010x} "
                "valid={framebuffer_write_read_first_expected_valid}/"
                "{framebuffer_write_read_second_expected_valid} "
                "completed={framebuffer_write_read_first_count}/"
                "{framebuffer_write_read_second_count} "
                "mismatches="
                "{framebuffer_write_read_first_mismatch_count}/"
                "{framebuffer_write_read_second_mismatch_count}".format(
                    **result
                )
            )
        elif 15 <= result["schema_version"] <= 18:
            print(
                "field fingerprints: first raw/display="
                "{framebuffer_last_first_field_raw_fingerprint:#010x}/"
                "{framebuffer_last_first_field_display_fingerprint:#010x} "
                "second raw/display="
                "{framebuffer_last_second_field_raw_fingerprint:#010x}/"
                "{framebuffer_last_second_field_display_fingerprint:#010x} "
                "completed={framebuffer_first_field_fingerprint_count}/"
                "{framebuffer_second_field_fingerprint_count} "
                "mismatches="
                "{framebuffer_first_field_fingerprint_mismatch_count}/"
                "{framebuffer_second_field_fingerprint_mismatch_count}".format(
                    **result
                )
            )
        if 16 <= result["schema_version"] <= 18:
            print(
                "line provenance mismatches: tag first/second="
                "{framebuffer_first_field_tag_mismatch_count}/"
                "{framebuffer_second_field_tag_mismatch_count} "
                "content first/second="
                "{framebuffer_first_field_content_mismatch_count}/"
                "{framebuffer_second_field_content_mismatch_count}".format(
                    **result
                )
            )
            print(
                "first tag mismatch: "
                f"{result['framebuffer_first_field_first_tag_mismatch']}"
            )
            print(
                "second tag mismatch: "
                f"{result['framebuffer_second_field_first_tag_mismatch']}"
            )
            print(
                "first content mismatch: "
                f"{result['framebuffer_first_field_first_content_mismatch']}"
            )
            print(
                "second content mismatch: "
                f"{result['framebuffer_second_field_first_content_mismatch']}"
            )
        if 18 <= result["schema_version"] <= 18:
            fw = result["framebuffer_first_field_cache_writes"]
            sw = result["framebuffer_second_field_cache_writes"]
            fs = result["framebuffer_first_field_cache_addr_sum"]
            ss = result["framebuffer_second_field_cache_addr_sum"]
            print(
                "cache writes: first={}{} second={}{} "
                "addr_sum={}{} / {}{}".format(
                    fw, "" if fw == 21780 else "  <-- expect 21780",
                    sw, "" if sw == 21600 else "  <-- expect 21600",
                    fs, "" if fs == 48766 else "  <-- expect 48766",
                    ss, "" if ss == 32656 else "  <-- expect 32656",
                )
            )
        if 17 <= result["schema_version"] <= 18:
            fx = result["framebuffer_first_field_row_xor"]
            sx = result["framebuffer_second_field_row_xor"]
            print(
                "fetch addresses: first_row_xor={} (expect 2){} "
                "second_row_xor={} (expect 0){} "
                "region_changed={}/{}".format(
                    fx, "" if fx == 2 else "  <-- UNEXPECTED",
                    sx, "" if sx == 0 else "  <-- UNEXPECTED",
                    result["framebuffer_first_field_region_changed"],
                    result["framebuffer_second_field_region_changed"],
                )
            )
        if 12 <= result["schema_version"] <= 18:
            print(
                "field readout: last_generation_fetches="
                "{framebuffer_last_first_field_fetches}/"
                "{framebuffer_last_second_field_fetches} "
                "regions={framebuffer_last_first_field_region}/"
                "{framebuffer_last_second_field_region} "
                "region_mismatch_generations="
                "{framebuffer_field_region_mismatch_count} "
                "phase_errors={framebuffer_sequence_phase_error_count}".format(
                    **result
                )
            )
        elif result["schema_version"] == 11:
            print(
                "field readout: last_generation_lines="
                "{framebuffer_last_first_field_lines}/"
                "{framebuffer_last_second_field_lines} "
                "last_generation_fetches="
                "{framebuffer_last_first_field_fetches}/"
                "{framebuffer_last_second_field_fetches} "
                "line_imbalance_generations="
                "{framebuffer_field_line_imbalance_count} "
                "phase_errors={framebuffer_sequence_phase_error_count}".format(
                    **result
                )
            )
        if result["schema_version"] == 19:
            print(f"confirmed deadline gaps: {result['deadline_gap_count']}")
        if result.get("overlay_scope") is not None:
            print(
                "overlay records: config={overlay_config_records} "
                "data={overlay_data_records} commit={overlay_commit_records} "
                "style={overlay_style_records} clear={overlay_clear_records}; "
                "commit_ok/bad={overlay_commit_ok}/{overlay_commit_bad}; "
                "plane_publications={overlay_plane_publications}".format(
                    **result
                )
            )
            print(
                "overlay transfer: record_bytes={overlay_record_bytes} "
                "plane_bytes={overlay_plane_bytes} "
                "received={overlay_received_plane_bytes} "
                "writer_accepts={overlay_writer_accepts} "
                "cache_rows={overlay_cache_rows}; "
                "publications style/plane/video="
                "{overlay_style_publications}/"
                "{overlay_memory_plane_publications}/"
                "{overlay_video_publications}".format(**result)
            )
            print(
                "overlay publication: visible={overlay_published_visible} "
                "menu={overlay_published_menu} bank={overlay_display_bank} "
                "rect=({overlay_published_x1},{overlay_published_y1})-"
                "({overlay_published_x2},{overlay_published_y2}) "
                "highlight1=0x{overlay_highlight_index1_abgr:08x}; "
                "video row_tags/matches/highlights/alpha/magenta="
                "{overlay_video_row_tags}/{overlay_video_row_matches}/"
                "{overlay_video_highlights}/{overlay_video_alpha}/"
                "{overlay_video_magenta}".format(**result)
            )
            print(
                "overlay capture: reason={overlay_capture_reason} "
                "armed={overlay_capture_armed} "
                "commit_seen={overlay_capture_commit_seen} "
                "settle={overlay_capture_settle_cycles}cy; "
                "ready={overlay_record_ready} "
                "protocol_error={overlay_protocol_error}/"
                "{overlay_memory_protocol_error}".format(**result)
            )
        if result.get("audio_underrun_count") is not None:
            longest = result["transport_block_longest_ms"]
            print(
                "audio: underruns=%d transport_blocks=%d longest_block=%s "
                "fifo_floor=%d frames/%.1f ms" % (
                    result["audio_underrun_count"],
                    result["transport_block_count"],
                    "%.1f ms" % longest if longest is not None else "n/a",
                    result["audio_fifo_floor"],
                    result["audio_fifo_floor_ms"],
                )
            )
        if result["schema_version"] >= 22:
            print(
                "A/V progress: audio_dequeues={audio_pcm_dequeue_count} "
                "display={display_pictures}/{display_swaps}; "
                "lateness display={display_pts_lateness_ticks} ticks/"
                "{display_pts_lateness_seconds}s "
                "candidate={candidate_pts_lateness_ticks} ticks/"
                "{candidate_pts_lateness_seconds}s; "
                "blocked unavailable/cadence/timestamp="
                "{candidate_unavailable_windows}/{cadence_blocked_windows}/"
                "{timestamp_blocked_windows}".format(**result)
            )
        if result.get("audio_underrun_count") is not None:
            for record in result["deadline_records"]:
                print("deadline: " + json.dumps(record, sort_keys=True))
        print(
            "largest gaps: "
            + ", ".join(
                "#{display_picture_ordinal}={cycles}cy/{seconds:.6f}s".format(
                    **gap
                )
                for gap in result["largest_display_gaps"]
            )
        )
        for failure in failures:
            print(f"FAIL: {failure}")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
