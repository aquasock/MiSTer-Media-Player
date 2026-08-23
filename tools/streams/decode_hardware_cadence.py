#!/usr/bin/env python3
"""Decode the Entry-312 machine-readable cadence overlay from a MiSTer PNG."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


MAGIC = 0x4D4D5031
WORDS = 38
X0 = 8
Y0 = 444
CELL = 4
ROW_PREFIX = (1, 0, 1, 0)


class TelemetryDecodeError(RuntimeError):
    pass


def _cell_bit(image: Image.Image, column: int, row: int) -> int:
    x0 = X0 + column * CELL + 1
    y0 = Y0 + row * CELL + 1
    pixels = []
    for y in range(y0, y0 + 2):
        for x in range(x0, x0 + 2):
            r, g, b = image.getpixel((x, y))[:3]
            pixels.append((int(r) + int(g) + int(b)) // 3)
    return int(sum(pixels) >= 128 * len(pixels))


def decode_words(path: Path | str) -> list[int]:
    image = Image.open(path).convert("RGB")
    if image.width < X0 + 43 * CELL or image.height < Y0 + WORDS * CELL:
        raise TelemetryDecodeError(
            f"image is {image.width}x{image.height}; an unscaled 800x600 "
            "MiSTer screenshot is required"
        )

    words: list[int] = []
    for row in range(WORDS):
        bits = [_cell_bit(image, column, row) for column in range(43)]
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
    if ((words[1] >> 16) & 0xFF) != WORDS:
        raise TelemetryDecodeError(
            f"snapshot declares {(words[1] >> 16) & 0xFF} words, expected {WORDS}"
        )
    checksum = 0
    for word in words[:-1]:
        checksum ^= word
    if checksum != words[-1]:
        raise TelemetryDecodeError(
            f"checksum mismatch 0x{checksum:08x}/0x{words[-1]:08x}"
        )
    return words


def parse_words(words: list[int]) -> dict[str, Any]:
    format_word = words[1]
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
    latest_pts_90k = (
        ((terminal & 0x7FF) << 22)
        | (((metadata >> 1) & 0x3F) << 16)
        | (words[19] & 0xFFFF)
    )

    def scheduler_flags(state: int) -> dict[str, Any]:
        return {
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

    def gap(rank: int, word_index: int) -> dict[str, Any]:
        cycles = words[word_index]
        metadata = words[word_index + 1]
        state = words[word_index + 2]
        return {
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

    return {
        "schema_version": (format_word >> 24) & 0xFF,
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
        "error_flags": (words[19] >> 16) & 0xFFFF,
        "pts_association_count": (terminal >> 11) & 0xFF,
        "latest_pts_90k": latest_pts_90k,
        "latest_pts_seconds": latest_pts_90k / 90000.0,
        # Entry 282: unconditional hold attribution.  These are NOT mutually
        # exclusive with each other or with the stall counters above, so they
        # must not be summed against them.
        "presentation_hold_total_cycles": words[20],
        "destination_hold_total_cycles": words[21],
        "hold_overlap_cycles": words[22],
        "hold_scratch_available_cycles": words[23],
        "hold_promotion_pending_cycles": words[24],
        "snapshot_reason_code": (snapshot_meta >> 30) & 0x3,
        "snapshot_reason": {
            1: "quiet",
            2: "forced_terminal_timeout",
            3: "fatal_or_no_progress",
        }.get((snapshot_meta >> 30) & 0x3, "unknown"),
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
        "checksum": words[37],
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
