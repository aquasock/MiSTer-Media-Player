#!/usr/bin/env python3
"""The native trace gate must reject losses, stale metadata and cadence errors."""
import copy
import unittest

from analyze_original_dvd_timing import analyze


class NativeTraceTests(unittest.TestCase):
    def setUp(self):
        self.fixture = {
            'pictures': [
                {'coded': 0, 'display': 0, 'top_field_first': True, 'repeat_first_field': True},
                {'coded': 1, 'display': 1, 'top_field_first': False, 'repeat_first_field': False},
            ],
            'pts_records': [{'next_coded_picture': 0, 'pts': 90000}],
        }
        def row(event, coded, cycle, field):
            return dict(event=event, id=coded, cycle=cycle, field=field,
                        tff=int(coded == 0), rff=int(coded == 0),
                        display_pts=90000, display_pts_valid=int(coded == 0),
                        prefill_miss=0, phase_error=0, overlap_error=0)
        self.rows = [row('START', 0, 0, 0), row('READY', 0, 1, 0),
                     row('PUBLISH', 0, 2, 0), row('START', 1, 3, 0),
                     row('READY', 1, 4, 0), row('PUBLISH', 1, 5, 3),
                     row('END', 1, 6, 5)]

    def test_complete_authored_cadence_passes_only_simulation(self):
        result = analyze(self.fixture, self.rows)
        self.assertTrue(result['simulation_timing_pass'])
        self.assertFalse(result['timing_accepted'])

    def test_incomplete_or_duplicate_publication_fails(self):
        cases = [self.rows[:-1], self.rows[:5] + self.rows[6:],
                 self.rows[:6] + [copy.copy(self.rows[5])] + self.rows[6:]]
        for rows in cases:
            self.assertFalse(analyze(self.fixture, rows)['simulation_timing_pass'])

    def test_metadata_cadence_and_cache_failures(self):
        for index, key, value in [(2, 'tff', 0), (2, 'rff', 0),
                                  (2, 'display_pts_valid', 0), (2, 'display_pts', 90001),
                                  (5, 'display_pts_valid', 1), (5, 'field', 2),
                                  (5, 'field', 4), (6, 'field', 4),
                                  (5, 'prefill_miss', 1), (5, 'phase_error', 1),
                                  (5, 'overlap_error', 1)]:
            with self.subTest(key=key, value=value):
                rows = copy.deepcopy(self.rows)
                rows[index][key] = value
                self.assertFalse(analyze(self.fixture, rows)['simulation_timing_pass'])


if __name__ == '__main__':
    unittest.main()
