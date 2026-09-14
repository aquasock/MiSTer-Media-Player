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


def _cell_bit(image: Image.Image, column: int, row: int, origin_y: int = Y0) -> int:
    x0 = X0 + column * CELL + 1
    y0 = origin_y + row * CELL + 1
    pixels = []
    for y in range(y0, y0 + 2):
        for x in range(x0, x0 + 2):
            r, g, b = image.getpixel((x, y))[:3]
            pixels.append((int(r) + int(g) + int(b)) // 3)
    return int(sum(pixels) >= 128 * len(pixels))


def decode_words(path: Path | str) -> list[int]:
    image = Image.open(path).convert("RGB")
    origin_y, count = None, None
    # Read the header count so compact and detailed profiles share an origin.
    for candidate_y in (280, 312, 432, 444):
        candidate_count = 2
        if image.width < X0 + 43 * CELL or image.height < candidate_y + candidate_count * CELL:
            continue
        probe = [_cell_bit(image, column, 0, candidate_y) for column in range(43)]
        magic = 0
        for bit in probe[10:42]:
            magic = (magic << 1) | bit
        if tuple(probe[:4]) == ROW_PREFIX and magic == MAGIC:
            header = 0
            for column in range(10,42):
                header = (header << 1) | _cell_bit(image, column, 1, candidate_y)
            candidate_count = (header >> 16) & 255
            version = header >> 24
            if candidate_count not in (25,38,41,49) or (candidate_count == 25 and version != 10):
                raise TelemetryDecodeError(f"unsupported snapshot format 0x{header:08x}")
            if image.height < candidate_y + candidate_count * CELL:
                raise TelemetryDecodeError("truncated telemetry image")
            origin_y, count = candidate_y, candidate_count
            break
    if origin_y is None:
        raise TelemetryDecodeError("telemetry absent; use an unscaled 720x480 or 800x600 MiSTer screenshot")
    words: list[int] = []
    for row in range(count):
        bits = [_cell_bit(image, column, row, origin_y) for column in range(43)]
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
    if ((words[1] >> 16) & 0xFF) != count:
        raise TelemetryDecodeError(
            f"snapshot declares {(words[1] >> 16) & 0xFF} words, expected {count}"
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
    if len(words) < 2:
        raise TelemetryDecodeError("truncated telemetry header")
    if words[1] >> 24 == 10:
        if len(words) != 25 or (words[1] >> 16) & 255 != 25:
            raise TelemetryDecodeError("schema 10 requires 25 words")
        # Reuse established field decoding, then mark unavailable diagnostics
        # explicitly. Zero expansion is internal only, never evidence of zero stalls.
        indices = [0,1,2,3,4,5,6,17,18,19,25,26,35,37,38,39,*range(40,48)]
        expanded = [0] * 49
        for index, value in zip(indices, words[:-1]):
            expanded[index] = value
        expanded[1] = (9 << 24) | (49 << 16) | (words[1] & 0xffff)
        expanded[48] = words[-1]
        result = parse_words(expanded)
        result.update(schema_version=10, snapshot_words=25, telemetry_profile="compact", checksum=words[-1])
        unavailable = ["decoder_stall_cycles", "presentation_stall_cycles", "destination_stall_cycles",
            "i_stall_cycles", "p_stall_cycles", "b_stall_cycles", "prediction_requests",
            "prediction_request_wait_cycles", "prediction_response_cycles", "writer_wait_cycles",
            "presentation_hold_total_cycles", "destination_hold_total_cycles", "hold_overlap_cycles",
            "hold_scratch_available_cycles", "hold_promotion_pending_cycles", "scheduler_debug_word", "scheduler_flags"]
        for name in unavailable:
            result[name] = None
        result["unavailable_fields"] = unavailable
        result["largest_display_gaps"] = [{key: result["largest_display_gaps"][0][key]
                                          for key in ("rank", "cycles", "seconds")}]
        return result
    if len(words) not in (38,41,49):
        raise TelemetryDecodeError("unsupported telemetry word count")
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
        "audio_frames_decoded": words[37] if len(words) >= 41 else None,
        "audio_samples_played": words[38] if len(words) >= 41 else None,
        "audio_status": words[39] if len(words) >= 41 else None,
        "audio_finished": bool(words[39] & 8) if len(words) >= 41 else None,
        "transport_requests": words[40] if len(words) == 49 else None,
        "transport_completions": words[41] if len(words) == 49 else None,
        "transport_max_wait_sys_cycles": words[42] if len(words) == 49 else None,
        "transport_byte_position": (words[43] | words[44] << 32) if len(words) == 49 else None,
        "transport_generation": words[45] if len(words) == 49 else None,
        "transport_reservoir_min_bytes": words[46] if len(words) == 49 else None,
        "transport_status": words[47] if len(words) == 49 else None,
        "transport_error": (words[47] & 15) if len(words) == 49 else None,
        "mp2_decode_error": bool(words[19] & (1 << 27)),
        "mp2_underrun": bool(words[19] & (1 << 28)),
        "mp2_timestamp_error": bool(words[19] & (1 << 29)),
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
        "checksum": words[-1],
    }


def decode_seek(path: Path | str):
    im = Image.open(path).convert('RGB')
    if im.width < 364 or im.height < 336:
        return None
    words = []
    for row in range(14):
        bits = []
        for col in range(43):
            total = sum(sum(im.getpixel((192+col*4+x, 280+row*4+y)))
                        for x in (1, 2) for y in (1, 2))
            bits.append(int(total >= 128*12))
        word = int(''.join(map(str, bits[10:42])), 2)
        if row == 0 and (bits[:4] != [1, 0, 1, 0] or word != 0x4D4D5331):
            return None
        if bits[:4] != [1, 0, 1, 0] or int(''.join(map(str, bits[4:10])), 2) != row:
            raise ValueError(f'seek telemetry row {row} framing error')
        if bits[42] != word.bit_count() % 2:
            raise ValueError(f'seek telemetry row {row} parity error')
        words.append(word)
    checksum = 0
    for word in words[:-1]:
        checksum ^= word
    if words[1] != 0x010EEA60 or checksum != words[-1]:
        raise ValueError('seek telemetry format/checksum error')
    code = words[3]
    state = (words[2] >> 16) & 4095
    names = ('pcm_full', 'destination_hold', 'presentation_hold', 'frame_waiting',
             'reader_idle', 'reader_cancel', 'decoder_reset', 'seek_done',
             'seeking', 'paused', 'program_stream', 'audio_bypass_disabled')
    elapsed = words[4] | ((words[6] & 7) << 32)
    target = words[5] | (((words[6] >> 3) & 7) << 32)
    return dict(schema_version=1, reason={1:'error_after_seek_entry', 2:'error_at_seek_entry',
        3:'seek_progress_timeout'}[words[2] >> 28], error_flags=words[2] & 65535,
        state={name:bool(state & (1 << i)) for i, name in enumerate(names)},
        syntax_source=code & 31, probe_source=(code >> 5) & 15,
        p_probe_source=(code >> 9) & 15, publication_detail=(code >> 13) & 7,
        p_wide_detail=(code >> 16) & 31, prediction_source=(code >> 21) & 7,
        prediction_detail=(code >> 24) & 31,
        elapsed_q=elapsed, target_q=target, elapsed_seconds=elapsed/360000,
        target_seconds=target/360000, display_pts=words[7] | (((words[6] >> 6) & 1) << 32),
        frame_rate_code=(words[6] >> 7) & 15, temporal_reference=(words[6] >> 11) & 1023,
        picture_type=(words[6] >> 21) & 7, display_pts_valid=bool(words[6] & (1 << 24)),
        video_ram_words=words[8] >> 11, audio_ram_bytes=words[8] & 2047,
        pcm_write_domain_used=words[9] & 8191, ingress_reservoir_min=(words[9] >> 13) & 65535,
        scheduler=words[10], cycles_since_seek=words[11], seek_count=words[12] >> 16,
        entry_errors=words[12] & 65535, checksum=words[-1], words=words)


def decode(path: Path | str) -> dict[str, Any]:
    try:
        seek = decode_seek(path)
    except ValueError as exc:
        raise TelemetryDecodeError(str(exc)) from exc
    try:
        result = parse_words(decode_words(path))
    except TelemetryDecodeError:
        if seek is None:
            raise
        result = {"telemetry_profile": "seek_only", "error_flags": seek["error_flags"]}
    if seek is not None:
        result["seek_diagnostics"] = seek
    return result


def validate(
    result: dict[str, Any],
    expected_pictures: int | None = None,
    expected_bytes: int | None = None,
    require_fps: float | None = None,
) -> list[str]:
    failures: list[str] = []
    if "seek_diagnostics" in result:
        seek = result["seek_diagnostics"]
        failures.append(f"seek diagnostic: {seek['reason']}, errors 0x{seek['error_flags']:04x}")
    if result.get("telemetry_profile") == "seek_only":
        return failures
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

    if args.json or result.get("telemetry_profile") == "seek_only":
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(
            f"hardware cadence: {result['display_pictures']} pictures, "
            f"{result['display_swaps']} intervals in "
            f"{result['cadence_seconds']:.6f} s = "
            f"{result['delivered_fps']:.6f} fps"
        )
        if result.get("telemetry_profile") == "compact":
            print("compact telemetry: detailed stall, DDR and scheduler history unavailable")
        else:
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
                f"{gap['cycles']}cy/{gap['seconds']:.6f}s"
                for gap in result["largest_display_gaps"]
            )
        )
        for failure in failures:
            print(f"FAIL: {failure}")
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())
