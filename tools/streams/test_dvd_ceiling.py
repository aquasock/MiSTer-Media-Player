#!/usr/bin/env python3
"""Focused tests for the DVD-ceiling fixture's narrow buffer validation."""
import unittest
import tempfile
from pathlib import Path

import generate_test_dvd_ceiling as dvd
import generate_test_dvd_av_soak as av
import generate_test_interlaced_i_frames as interlaced


def pack(clock, rate=av.MUX_RATE):
    base, extension = divmod(clock, 300)
    bits = (f'01{base >> 30:03b}1{(base >> 15) & 32767:015b}1'
            f'{base & 32767:015b}1{extension:09b}1{rate // 400:022b}11' + '11111000')
    return b'\x00\x00\x01\xba' + int(bits, 2).to_bytes(10, 'big')


class AvSoakTests(unittest.TestCase):
    def test_video_patch_preserves_packet_headers_and_audio(self):
        def pes(sid, data):
            body = b'\x80\x80\x05\x21\x00\x01\x00\x01' + data
            return b'\x00\x00\x01' + bytes([sid]) + len(body).to_bytes(2, 'big') + body

        source = pack(0) + pes(0xE0, b'ab') + pes(0xC0, b'sound') + pes(0xE0, b'cd') + b'\x00\x00\x01\xb9'
        expected = pack(0) + pes(0xE0, b'AB') + pes(0xC0, b'sound') + pes(0xE0, b'CD') + b'\x00\x00\x01\xb9'
        with tempfile.TemporaryDirectory() as directory:
            program, video = (Path(directory) / name for name in ('test.mpg', 'test.m2v'))
            program.write_bytes(source)
            video.write_bytes(b'ABCD')
            av.replace_video_payloads(program, video)
            self.assertEqual(program.read_bytes(), expected)
            for data, error in ((b'ABC', 'too short'), (b'ABCDE', 'too long')):
                program.write_bytes(source)
                video.write_bytes(data)
                with self.assertRaisesRegex(ValueError, error):
                    av.replace_video_payloads(program, video)

    def test_pack_clock_roundtrip_and_markers(self):
        for clock in (0, 3001, (1 << 33) * 300 - 1):
            self.assertEqual(av.pack_clock(pack(clock)[4:]), (clock, av.MUX_RATE))
        damaged = bytearray(pack(3001)[4:])
        damaged[0] &= ~4
        with self.assertRaisesRegex(ValueError, 'marker'):
            av.pack_clock(damaged)

    def test_pack_schedule_and_terminal_guards(self):
        padding = b'\x00\x00\x01\xbe\x07\xec' + b'\xff' * 2028
        first = pack(0) + padding
        self.assertEqual(len(first), 2048)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'test.mpg'
            path.write_bytes(first + pack(44000) + b'\x00\x00\x01\xb9')
            self.assertEqual(av.verify_packs(path)['packs'], 2)
            for suffix, error in (
                (pack(10) + b'\x00\x00\x01\xb9', 'exceeds mux rate'),
                (pack(44000, 9_000_000) + b'\x00\x00\x01\xb9', 'wrong program mux rate'),
                (pack(44000), 'missing program end'),
                (pack(44000) + b'\x00\x00\x01\xb9x', 'bytes after program end'),
            ):
                path.write_bytes(first + suffix)
                with self.assertRaisesRegex(ValueError, error):
                    av.verify_packs(path)

    def test_signalling_patch_uses_bounded_extension_reads(self):
        class BoundedBytes(bytes):
            def __getitem__(self, key):
                if isinstance(key, slice) and key.stop is None:
                    raise AssertionError('unbounded copy of full movie tail')
                return super().__getitem__(key)

        original = BoundedBytes(b'\x00\x00\x01\xb5\x10\x08\x00\x00\x00\x00'
                                b'\x00\x00\x01\xb5\x80\x00\x00\x43\x80')
        result = interlaced.patch_interlaced_signalling(original, True, 1)
        self.assertEqual(result[5] & 8, 0)
        self.assertEqual(result[17] & 0xC3, 0xC0)
        self.assertEqual(result[18] & 0x80, 0)


class CbrTests(unittest.TestCase):
    def test_exact_period_and_eof(self):
        # At 30,000 bit/s each frame supplies exactly 1001 bits.
        result = dvd.check_cbr([1001] * 5, [32 + n * 1001 for n in range(5)],
                               [9000] * 5, rate=30000, capacity=4000)
        self.assertEqual(result['minimum_after_removal_bits'], 0)
        self.assertEqual(result['maximum_occupancy_bits'], 3032)

    def test_underflow_rejected(self):
        with self.assertRaisesRegex(ValueError, 'underflow'):
            dvd.check_cbr([4000, 1000], [32, 4032], [100, 100],
                          rate=30000, capacity=10000)

    def test_overflow_rejected(self):
        with self.assertRaisesRegex(ValueError, 'overflow'):
            dvd.check_cbr([1001] * 5, [32 + n * 1001 for n in range(5)],
                          [9000] * 5, rate=30000, capacity=2000)

    def test_delay_drift_rejected(self):
        with self.assertRaisesRegex(ValueError, 'delay inconsistency'):
            dvd.check_cbr([1001] * 5, [32 + n * 1001 for n in range(5)],
                          [9000, 9000, 9100, 9000, 9000], rate=30000, capacity=4000)

    def test_quantized_delays(self):
        dvd.check_cbr([1001] * 5, [32 + n * 1001 for n in range(5)],
                      [9000, 8999, 9001, 9000, 9000], rate=30000, capacity=4000)

    def test_invalid_inputs(self):
        for sizes, starts, delays in [([], [], []), ([1], [], [1]),
                                      ([1], [1], [65535]), ([0], [1], [1])]:
            with self.assertRaises(ValueError):
                dvd.check_cbr(sizes, starts, delays)

    def test_access_unit_headers_belong_to_next_picture(self):
        picture = b'\x00\x00\x01\x00' + b'\x00\x08\x00\x08'
        prefix = b'\x00\x00\x01\xb3' + b'header'
        slice_data = b'\x00\x00\x01\x01' + b'pixels'
        unit = prefix + picture + slice_data
        data = unit * 2 + b'\x00\x00\x01\xb7'
        sizes, starts, delays = dvd.access_units(data)
        self.assertEqual(sizes, [len(unit) * 8, (len(unit) + 4) * 8])
        self.assertEqual(starts, [(len(prefix) + 4) * 8,
                                  (len(unit) + len(prefix) + 4) * 8])
        self.assertEqual(delays, [1, 1])


if __name__ == '__main__':
    unittest.main()
