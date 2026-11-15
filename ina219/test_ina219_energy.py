import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ina219_energy as e  # noqa: E402


class IntegrateTest(unittest.TestCase):
    def test_constant_load_one_hour(self):
        # 100 mA at 500 mW for one hour, a sample every minute.
        rows = [(t * 60.0, 100.0, 500.0) for t in range(61)]
        r = e.integrate(rows, max_gap=300)
        self.assertAlmostEqual(r["mah"], 100.0)
        self.assertAlmostEqual(r["wh"], 0.5)
        self.assertAlmostEqual(r["covered"], 3600.0)
        self.assertEqual(r["gaps"], 0)

    def test_trapezoid_ramp(self):
        # 0 -> 200 mA linearly over an hour averages 100 mA.
        r = e.integrate([(0.0, 0.0, 0.0), (3600.0, 200.0, 1000.0)], max_gap=7200)
        self.assertAlmostEqual(r["mah"], 100.0)
        self.assertAlmostEqual(r["wh"], 0.5)

    def test_gap_is_skipped(self):
        rows = [(0.0, 100.0, 500.0), (60.0, 100.0, 500.0),
                (3660.0, 100.0, 500.0), (3720.0, 100.0, 500.0)]
        r = e.integrate(rows, max_gap=300)
        self.assertEqual(r["gaps"], 1)
        self.assertAlmostEqual(r["gap_seconds"], 3600.0)
        self.assertAlmostEqual(r["covered"], 120.0)
        self.assertAlmostEqual(r["mah"], 100.0 * 120 / 3600)

    def test_none_values_break_the_chain(self):
        rows = [(0.0, 100.0, 500.0), (60.0, None, None), (120.0, 100.0, 500.0),
                (180.0, 100.0, 500.0)]
        r = e.integrate(rows, max_gap=300)
        self.assertAlmostEqual(r["covered"], 60.0)

    def test_negative_current_subtracts(self):
        r = e.integrate([(0.0, -100.0, -500.0), (3600.0, -100.0, -500.0)], max_gap=7200)
        self.assertAlmostEqual(r["mah"], -100.0)


class PeriodTest(unittest.TestCase):
    NOW = datetime(2026, 11, 15, 12, 0, tzinfo=timezone.utc)

    def test_default_is_last_since(self):
        a, b = e.resolve_period(None, None, "6h", now=self.NOW)
        self.assertEqual(b, self.NOW)
        self.assertEqual((b - a).total_seconds(), 6 * 3600)

    def test_start_plus_since(self):
        a, b = e.resolve_period("2026-11-10", None, "12h", now=self.NOW)
        self.assertEqual(a, datetime(2026, 11, 10, tzinfo=timezone.utc))
        self.assertEqual((b - a).total_seconds(), 12 * 3600)

    def test_start_end_and_z_suffix(self):
        a, b = e.resolve_period("2026-11-10T00:00:00Z", "2026-11-11", "1h", now=self.NOW)
        self.assertEqual((b - a).total_seconds(), 86400)

    def test_now_for_start_and_end(self):
        a, b = e.resolve_period("2026-11-15T06:00:00", "NOW", "1h", now=self.NOW)
        self.assertEqual(b, self.NOW)
        self.assertEqual((b - a).total_seconds(), 6 * 3600)

    def test_empty_period_rejected(self):
        with self.assertRaises(ValueError):
            e.resolve_period("2026-11-11", "2026-11-10", "1h", now=self.NOW)

    def test_bad_duration(self):
        with self.assertRaises(ValueError):
            e.parse_duration("soon")


if __name__ == "__main__":
    unittest.main()
