#!/usr/bin/env python3
"""Regression tests for the hardware telemetry host decoder."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).with_name("decode-hardware-telemetry.py")
SPEC = importlib.util.spec_from_file_location("hardware_telemetry", MODULE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {MODULE_PATH}")
TELEMETRY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TELEMETRY)


def snapshot(schema: int) -> list[int]:
    words = [0] * 64
    words[0] = TELEMETRY.MAGIC
    words[1] = (schema << 24) | (64 << 16) | 60000
    return words


class HardwareTelemetryTest(unittest.TestCase):
    def test_accepted_schema21_screenshot_words(self) -> None:
        """The exact accepted ordinary-video snapshot decodes as fallback."""
        words = snapshot(21)
        captured = {
            2: 0x007EE97E,
            3: 0x6B49D200,
            4: 0x002E8610,
            5: 0x6B4317F3,
            6: 0x6B1491E3,
            7: 0x252FD426,
            8: 0x040E000A,
            10: 0x0351F4F9,
            11: 0x0B38027E,
            12: 0x16A5DCAF,
            13: 0x03673532,
            14: 0x007F4681,
            15: 0x0960FA85,
            16: 0x021D78E0,
            17: 0xECD5BFBE,
            18: 0x2605767F,
            19: 0x00000078,
            20: 0x040E000A,
            23: 0x000000FC,
            24: 0x0000002D,
            25: 0x3FFF015D,
            26: 0x002DD278,
            27: 0x03200918,
            28: 0x40000D73,
            29: 0x002DD278,
            30: 0x05301298,
            31: 0x40000C5B,
            32: 0x002DD278,
            33: 0x07300398,
            34: 0x4114A543,
            35: 0x4400FEBE,
            36: 0x4000044D,
            37: 0x4F564C31,
            44: 0x00000001,
            54: 0x80000000,
            63: 0x7EA59E0A,
        }
        for index, value in captured.items():
            words[index] = value

        checksum = 0
        for word in words[:-1]:
            checksum ^= word
        self.assertEqual(checksum, words[-1])

        result = TELEMETRY.parse_words(words)
        self.assertEqual(result["schema_version"], 21)
        self.assertEqual(result["overlay_debug_magic_ascii"], "OVL1")
        self.assertTrue(result["overlay_debug_magic_valid"])
        self.assertTrue(result["overlay_record_ready"])
        self.assertEqual(result["overlay_commit_records"], 0)
        self.assertEqual(
            result["overlay_capture_reason"], "bounded_no_commit_fallback"
        )
        self.assertFalse(result["overlay_capture_commit_seen"])
        self.assertEqual(result["audio_underrun_count"], 0)
        self.assertEqual(result["transport_block_count"], 0)
        self.assertIsNone(result["delivered_fps"])
        self.assertEqual(TELEMETRY.validate(result), [])

    def test_schema21_active_overlay_semantics(self) -> None:
        words = snapshot(21)
        words[37] = 0x4F564C31
        words[38] = (4 << 24) | (3 << 16) | (22 << 8) | 2
        words[39] = (1 << 24) | (1 << 16) | (2 << 8) | 2
        words[40] = 90000
        words[41] = 86400
        words[42] = (10800 << 16) | 480
        words[43] = (4 << 24) | (2 << 16) | (2 << 8)
        words[44] = (
            (4 << 24) | (10800 << 10) | (1 << 6) |
            (1 << 5) | (1 << 4) | 1
        )
        words[45] = (100 << 16) | 200
        words[46] = (300 << 16) | 400
        words[47] = 0xFFFF00FF
        words[48] = 86400
        words[49] = 480
        words[50] = 123456
        words[51] = 6543
        words[52] = 6432
        words[53] = 6321
        words[54] = (1 << 30) | (1 << 29) | (1 << 28) | 60000000
        words[55] = 120000
        words[56] = (3 << 16) | 2
        words[57] = 960

        result = TELEMETRY.parse_words(words)
        self.assertEqual(result["overlay_config_records"], 2)
        self.assertEqual(result["overlay_data_records"], 22)
        self.assertEqual(result["overlay_commit_records"], 3)
        self.assertEqual(result["overlay_style_records"], 4)
        self.assertEqual(result["overlay_commit_ok"], 2)
        self.assertEqual(result["overlay_commit_bad"], 1)
        self.assertEqual(result["overlay_clear_records"], 1)
        self.assertEqual(result["overlay_record_bytes"], 90000)
        self.assertEqual(result["overlay_plane_bytes"], 86400)
        self.assertEqual(result["overlay_writer_accepts"], 10800)
        self.assertEqual(result["overlay_cache_rows"], 480)
        self.assertEqual(result["overlay_current_command"], 4)
        self.assertEqual(result["overlay_write_word_index"], 10800)
        self.assertTrue(result["overlay_published_visible"])
        self.assertTrue(result["overlay_published_menu"])
        self.assertEqual(
            (result["overlay_published_x1"], result["overlay_published_y1"],
             result["overlay_published_x2"], result["overlay_published_y2"]),
            (100, 200, 300, 400),
        )
        self.assertEqual(result["overlay_highlight_index1_alpha"], 255)
        self.assertEqual(result["overlay_highlight_index1_blue"], 255)
        self.assertEqual(result["overlay_highlight_index1_green"], 0)
        self.assertEqual(result["overlay_highlight_index1_red"], 255)
        self.assertEqual(result["overlay_video_magenta"], 6321)
        self.assertEqual(
            result["overlay_capture_reason"], "settled_overlay_commit"
        )
        self.assertTrue(result["overlay_capture_armed"])
        self.assertTrue(result["overlay_capture_commit_seen"])
        self.assertAlmostEqual(result["overlay_capture_settle_seconds"], 1.0)
        self.assertEqual(result["transport_block_longest_ms"], 2.0)
        self.assertEqual(result["transport_block_count"], 3)
        self.assertEqual(result["audio_underrun_count"], 2)
        self.assertEqual(result["audio_fifo_floor"], 960)
        # Rejected intermediate commits are diagnostic evidence, not by
        # themselves a parser validation failure.
        self.assertEqual(TELEMETRY.validate(result), [])

    def test_schema22_av_progress_semantics(self) -> None:
        words = snapshot(22)
        words[6] = 1_800_000_000
        words[37] = 0x4F564C31
        words[58] = (900 << 16) | 899
        words[59] = 1_440_000
        words[60] = 9_000
        words[61] = (-4_500) & 0xFFFFFFFF
        words[62] = (1 << 31) | (1 << 30) | (7 << 20) | (11 << 10) | 13

        result = TELEMETRY.parse_words(words)
        self.assertEqual(result["schema_version"], 22)
        self.assertTrue(result["overlay_debug_magic_valid"])
        self.assertEqual(result["display_pictures"], 900)
        self.assertEqual(result["display_swaps"], 899)
        self.assertAlmostEqual(result["delivered_fps"], 899 / 30)
        self.assertEqual(result["audio_pcm_dequeue_count"], 1_440_000)
        self.assertTrue(result["display_pts_lateness_valid"])
        self.assertEqual(result["display_pts_lateness_ticks"], 9_000)
        self.assertAlmostEqual(result["display_pts_lateness_seconds"], 0.1)
        self.assertTrue(result["candidate_pts_lateness_valid"])
        self.assertEqual(result["candidate_pts_lateness_ticks"], -4_500)
        self.assertAlmostEqual(result["candidate_pts_lateness_seconds"], -0.05)
        self.assertEqual(result["candidate_unavailable_windows"], 7)
        self.assertEqual(result["cadence_blocked_windows"], 11)
        self.assertEqual(result["timestamp_blocked_windows"], 13)
        self.assertEqual(TELEMETRY.validate(result), [])

    def test_schema20_deadline_layout_remains_unchanged(self) -> None:
        words = snapshot(20)
        words[6] = 120000000
        words[37] = (60 << 16) | 59
        words[38] = (40 << 16)
        words[55] = 180000
        words[56] = (7 << 16) | 5
        words[57] = 1440

        result = TELEMETRY.parse_words(words)
        self.assertEqual(result["display_pictures"], 60)
        self.assertEqual(result["display_swaps"], 59)
        self.assertEqual(result["reference_pictures"], 40)
        self.assertEqual(result["deadline_gap_count"], 0)
        self.assertEqual(result["deadline_records"], [])
        self.assertAlmostEqual(result["delivered_fps"], 29.5)
        self.assertEqual(result["transport_block_longest_ms"], 3.0)
        self.assertEqual(result["transport_block_count"], 7)
        self.assertEqual(result["audio_underrun_count"], 5)
        self.assertNotIn("overlay_scope", result)

    def test_schema21_protocol_error_fails_validation(self) -> None:
        words = snapshot(21)
        words[37] = 0x4F564C31
        words[43] = 1 << 2
        words[44] = (1 << 1) | 1
        result = TELEMETRY.parse_words(words)
        self.assertEqual(
            TELEMETRY.validate(result),
            ["overlay memory-domain protocol error",
             "overlay engine protocol error"],
        )


if __name__ == "__main__":
    unittest.main()
