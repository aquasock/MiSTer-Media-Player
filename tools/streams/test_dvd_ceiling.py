#!/usr/bin/env python3
"""Focused tests for the DVD-ceiling fixture's narrow buffer validation."""
import unittest

import generate_test_dvd_ceiling as dvd


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
