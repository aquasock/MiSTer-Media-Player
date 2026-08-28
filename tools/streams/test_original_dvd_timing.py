#!/usr/bin/env python3
"""The native trace gate must reject losses, stale metadata and cadence errors."""
import copy
import csv
import json
from pathlib import Path
import unittest

from analyze_original_dvd_timing import analyze


class NativeTraceTests(unittest.TestCase):
    def setUp(self):
        self.fixture = {
            'pictures': [
                {'coded': 0, 'display': 0, 'top_field_first': True, 'repeat_first_field': True, 'progressive_frame': True},
                {'coded': 1, 'display': 1, 'top_field_first': False, 'repeat_first_field': False, 'progressive_frame': True},
            ],
            'pts_records': [{'next_coded_picture': 0, 'pts': 90000}],
        }
        def row(event, coded, cycle, field):
            return dict(event=event, id=coded, cycle=cycle, field=field,
                        tff=int(coded == 0), rff=int(coded == 0),
                        progressive=1, descriptor_valid=1,
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
                                  (5, 'progressive', 0), (5, 'descriptor_valid', 0),
                                  (5, 'field', 4), (6, 'field', 4),
                                  (5, 'prefill_miss', 1), (5, 'phase_error', 1),
                                  (5, 'overlap_error', 1)]:
            with self.subTest(key=key, value=value):
                rows = copy.deepcopy(self.rows)
                rows[index][key] = value
                self.assertFalse(analyze(self.fixture, rows)['simulation_timing_pass'])


class TerminalCutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Reuse the checked-in complete traces, including the earlier real miss.
        cls.evidence = Path(__file__).resolve().parents[2] / '.ai/current_results'
        cls.fixture = json.loads((cls.evidence / 'entry676_timing_fixture.json').read_text())

    def trace(self, name):
        with (self.evidence / name).open() as handle:
            return [{k: v if k == 'event' else int(v) for k, v in r.items()}
                    for r in csv.DictReader(handle)]

    def test_both_complete_traces_require_explicit_exception(self):
        for case in ('ideal', 'contended'):
            rows = self.trace(f'entry676_{case}_native.csv')
            raw = analyze(self.fixture, rows)
            result = analyze(self.fixture, rows, allow_terminal_cut=True)
            self.assertFalse(raw['qualification_pass'])
            self.assertTrue(result['qualification_pass'])
            self.assertTrue(result['terminal_cut_exception']['applied'])
            self.assertFalse(result['simulation_timing_pass'])
            self.assertFalse(result['timing_accepted'])
            self.assertEqual(result['cadence_mismatches'], raw['cadence_mismatches'])

    def test_exception_cannot_hide_other_failures(self):
        rows = self.trace('entry676_contended_native.csv')
        final = next(i for i, r in enumerate(rows) if r['event'] == 'PUBLISH' and r['id'] == 288)
        interior = next(i for i, r in enumerate(rows) if r['event'] == 'PUBLISH' and r['id'] == 116)
        for index, key, value in [(final, 'field', rows[final]['field'] + 1),
                                  (interior, 'field', rows[interior]['field'] + 2),
                                  (final, 'descriptor_valid', 0), (final, 'tff', 1),
                                  (final, 'display_pts_valid', 1), (final, 'prefill_miss', 1),
                                  (final, 'phase_error', 1), (final, 'overlap_error', 1),
                                  (len(rows) - 1, 'field', rows[final]['field'])]:
            with self.subTest(key=key, index=index):
                changed = copy.deepcopy(rows)
                changed[index][key] = value
                self.assertFalse(analyze(self.fixture, changed, True)['qualification_pass'])
        for changed in (rows[:-1], rows[:final] + rows[final+1:],
                        rows[:final] + [rows[final]] + rows[final:]):
            self.assertFalse(analyze(self.fixture, changed, True)['qualification_pass'])

    def test_unknown_fixture_and_late_or_unready_terminal_fail(self):
        rows = self.trace('entry676_ideal_native.csv')
        fixture = copy.deepcopy(self.fixture)
        fixture['fixture_sha256'] = '0' * 64
        self.assertFalse(analyze(fixture, rows, True)['qualification_pass'])
        previous = next(r for r in rows if r['event'] == 'PUBLISH' and r['id'] == 285)
        window = next(r for r in rows if r['event'] == 'FIELD' and r['field'] == previous['field'] + 2)
        for key, value in [('candidate_ready', 0), ('candidate_id', 285), ('pts_active', 1)]:
            changed = copy.deepcopy(rows)
            changed[rows.index(window)][key] = value
            self.assertFalse(analyze(self.fixture, changed, True)['qualification_pass'])
        changed = copy.deepcopy(rows)
        next(r for r in changed if r['event'] == 'READY' and r['id'] == 288)['cycle'] = window['cycle'] + 1
        changed.sort(key=lambda r: r['cycle'])
        self.assertFalse(analyze(self.fixture, changed, True)['qualification_pass'])


if __name__ == '__main__':
    unittest.main()
