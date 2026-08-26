#!/usr/bin/env python3
"""Decode the machine-readable cadence overlay from a MiSTer PNG."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


MAGIC = 0x4D4D5031
X0 = 8
WORDS = 43
DIAGNOSTIC_Y0 = 428
NATIVE_480I_Y0 = 308
SCHEMA10_DIAGNOSTIC_Y0 = 436
SCHEMA10_NATIVE_480I_Y0 = 316
LEGACY_DIAGNOSTIC_Y0 = 444
LEGACY_NATIVE_480I_Y0 = 324
CELL = 4
ROW_PREFIX = (1, 0, 1, 0)


class TelemetryDecodeError(RuntimeError):
    pass


def _cell_bit(image: Image.Image, y_origin: int, column: int, row: int) -> int:
    x0 = X0 + column * CELL + 1
    y0 = y_origin + row * CELL + 1
    pixels = []
    for y in range(y0, y0 + 2):
        for x in range(x0, x0 + 2):
            r, g, b = image.getpixel((x, y))[:3]
            pixels.append((int(r) + int(g) + int(b)) // 3)
    return int(sum(pixels) >= 128 * len(pixels))


def decode_words(path: Path | str) -> list[int]:
    image = Image.open(path).convert("RGB")
    minimum_width = X0 + 43 * CELL
    if image.width < minimum_width:
        raise TelemetryDecodeError(
            f"image is {image.width}x{image.height}; telemetry requires at "
            f"least {minimum_width} horizontal pixels"
        )

    layouts = (
        (DIAGNOSTIC_Y0, WORDS),
        (NATIVE_480I_Y0, WORDS),
        (SCHEMA10_DIAGNOSTIC_Y0, 41),
        (SCHEMA10_NATIVE_480I_Y0, 41),
        (LEGACY_DIAGNOSTIC_Y0, 38),
        (LEGACY_NATIVE_480I_Y0, 38),
    )
    failures: list[str] = []
    for y_origin, word_count in layouts:
        if image.height < y_origin + word_count * CELL:
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
        f"image is {image.width}x{image.height}; no supported telemetry "
        f"layout decoded ({'; '.join(failures)})"
    )


def parse_words(words: list[int]) -> dict[str, Any]:
    format_word = words[1]
    schema_version = (format_word >> 24) & 0xFF
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

    return {
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
        "checksum": words[-1],
    }


def decode(path: Path | str) -> dict[str, Any]:
    return parse_words(decode_words(path))


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
    if require_fps is not None and result["delivered_fps"] + 1e-9 < require_fps:
        failures.append(
            f"delivered {result['delivered_fps']:.6f} fps, "
            f"required {require_fps:.6f} fps"
        )
    return failures


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("screenshot", type=Path)
    parser.add_argument("--expected-pictures", type=int)
    parser.add_argument("--expected-bytes", type=int)
    parser.add_argument("--require-fps", type=float)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    try:
        result = decode(args.screenshot)
    except TelemetryDecodeError as exc:
        parser.error(str(exc))

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
        print(
            f"hardware cadence: {result['display_pictures']} pictures, "
            f"{result['display_swaps']} intervals in "
            f"{result['cadence_seconds']:.6f} s = "
            f"{result['delivered_fps']:.6f} fps"
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
        if result["schema_version"] >= 10:
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
        if result["schema_version"] >= 13:
            print(
                "field content: scope={framebuffer_content_scope} "
                "varied={framebuffer_first_field_varied}/"
                "{framebuffer_second_field_varied} "
                "signatures={framebuffer_first_field_signature:#04x}/"
                "{framebuffer_second_field_signature:#04x}".format(**result)
            )
        if result["schema_version"] >= 12:
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
