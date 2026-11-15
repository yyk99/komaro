#!/usr/bin/env python3
"""Integrate the energy (Wh) and charge (mAh) a sensor's ina219 readings
add up to over a period, from InfluxDB 1.x.

Reads the points of measurement "ina219" whose "sensor" tag equals SENSOR
(database "ina219" by default - that is where the readings are written, not
in the "komaro" database of the temperature/humidity sensors) and integrates
with the trapezoidal rule:

  charge [mAh] = integral of current_ma dt / 3600
  energy [Wh]  = integral of power_mw  dt / 3600 / 1000

Samples are ~30 s apart. When the sensor was off or the network down there is
a hole in the data; integrating a straight line across it would invent
consumption, so intervals longer than --max-gap (default 5m) are skipped and
reported as "gaps" with the covered fraction of the period. The result is the
net value: a negative current (charging) subtracts.

Usage: ina219_energy.py SENSOR [options]

Examples:
  ina219_energy.py sensor4 --influx-host silvana.home            # last 24h
  ina219_energy.py sensor4 --since 7d
  ina219_energy.py sensor4 --start 2026-11-10 --end 2026-11-11   # UTC
  ina219_energy.py sensor4 --start 2026-11-10T08:00:00 --since 12h   # 12h from start
  ina219_energy.py sensor4 --start "2026-11-10 08:00" --end now      # until now
"""

import argparse
import re
import sys
from datetime import datetime, timedelta, timezone

DURATION_UNITS = {"s": 1, "m": 60, "h": 3600, "d": 86400, "w": 604800}


def parse_duration(text):
    """'90s', '5m', '6h', '7d', '2w' -> seconds (float)."""
    m = re.fullmatch(r"\s*(\d+(?:\.\d+)?)\s*([smhdw])\s*", text)
    if not m:
        raise ValueError("bad duration %r (use e.g. 30s, 5m, 6h, 7d)" % text)
    return float(m.group(1)) * DURATION_UNITS[m.group(2)]


def parse_time(text, now=None):
    """ISO date or datetime (UTC unless it carries an offset or Z) -> aware datetime.

    "now" means the current time (`now` if given). Replaces a trailing Z by
    +00:00 so Python < 3.11 can parse it."""
    if text.strip().lower() == "now":
        return now or datetime.now(timezone.utc)
    t = datetime.fromisoformat(text.strip().replace("Z", "+00:00"))
    return t if t.tzinfo else t.replace(tzinfo=timezone.utc)


def resolve_period(start, end, since, now=None):
    """Return (start, end) datetimes from the options.

    --start/--end give the period; with only --start, --since is its length;
    with neither, the period is the last --since up to now."""
    now = now or datetime.now(timezone.utc)  # one "now" for the whole call
    since_s = timedelta(seconds=parse_duration(since))
    if start and end:
        a, b = parse_time(start, now), parse_time(end, now)
    elif start:
        a = parse_time(start, now)
        b = a + since_s
    elif end:
        b = parse_time(end, now)
        a = b - since_s
    else:
        b = now
        a = b - since_s
    if a >= b:
        raise ValueError("the period is empty: start %s is not before end %s" % (a, b))
    return a, b


def integrate(rows, max_gap):
    """Trapezoidal integration of consecutive (t_seconds, current_ma, power_mw) rows.

    Returns a dict: mah, wh, covered (seconds actually integrated), gaps (count
    of skipped intervals), gap_seconds, samples. Rows must be sorted by time;
    a row whose current or power is None is treated as a hole."""
    mas = 0.0   # mA * s
    mws = 0.0   # mW * s
    covered = gap_seconds = 0.0
    gaps = 0
    prev = None
    for row in rows:
        t, i, p = row
        if i is None or p is None:
            prev = None
            continue
        if prev is not None:
            dt = t - prev[0]
            if dt <= 0:
                pass
            elif dt > max_gap:
                gaps += 1
                gap_seconds += dt
            else:
                mas += (i + prev[1]) / 2.0 * dt
                mws += (p + prev[2]) / 2.0 * dt
                covered += dt
        prev = row
    return {"mah": mas / 3600.0, "wh": mws / 3.6e6, "covered": covered,
            "gaps": gaps, "gap_seconds": gap_seconds, "samples": len(rows)}


def fetch(args, start, end):
    from influxdb import InfluxDBClient
    client = InfluxDBClient(host=args.influx_host, port=args.influx_port,
                            database=args.database)
    q = ('SELECT "current_ma", "power_mw" FROM "%s" WHERE "sensor" = $sensor '
         "AND time >= $start AND time < $end ORDER BY time"
         % args.measurement.replace('"', '\\"'))
    res = client.query(q, epoch="ms", bind_params={
        "sensor": args.sensor,
        "start": start.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
        "end": end.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ"),
    })
    return [(r["time"] / 1000.0, r.get("current_ma"), r.get("power_mw"))
            for r in res.get_points()]


def fmt_duration(seconds):
    seconds = int(round(seconds))
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return "%dh %02dm %02ds" % (h, m, s)


def main():
    p = argparse.ArgumentParser(
        description="Energy (Wh) and charge (mAh) from a sensor's ina219 readings")
    p.add_argument("sensor", help='value of the "sensor" tag')
    p.add_argument("--influx-host", default="localhost",
                   help="InfluxDB host (default localhost)")
    p.add_argument("--influx-port", type=int, default=8086, help="InfluxDB port (default 8086)")
    p.add_argument("--database", default="ina219", help="InfluxDB database (default ina219)")
    p.add_argument("--measurement", default="ina219", help="measurement (default ina219)")
    p.add_argument("--since", default="24h",
                   help="period length, such as 30m, 24h, 7d (default 24h): counted back "
                   "from now, or forward from --start, or back from --end")
    p.add_argument("--start", help="period start, ISO date/time (UTC unless it has an offset), or now")
    p.add_argument("--end", help="period end, ISO date/time (exclusive), or now")
    p.add_argument("--max-gap", default="5m",
                   help="do not integrate across holes longer than this (default 5m)")
    args = p.parse_args()

    try:
        start, end = resolve_period(args.start, args.end, args.since)
        max_gap = parse_duration(args.max_gap)
    except ValueError as e:
        p.error(str(e))

    try:
        rows = fetch(args, start, end)
    except Exception as e:
        print("Error: %s" % e, file=sys.stderr)
        return 1
    if len(rows) < 2:
        print("not enough data for sensor %r between %s and %s (%d sample(s))"
              % (args.sensor, start, end, len(rows)), file=sys.stderr)
        return 1

    r = integrate(rows, max_gap)
    total = (end - start).total_seconds()
    print("sensor   %s (%s.%s on %s)" % (args.sensor, args.database, args.measurement,
                                         args.influx_host))
    print("period   %s .. %s  (%s)" % (start.strftime("%Y-%m-%d %H:%M:%S UTC"),
                                       end.strftime("%Y-%m-%d %H:%M:%S UTC"),
                                       fmt_duration(total)))
    print("samples  %d, integrated over %s (%.1f%% of the period)"
          % (r["samples"], fmt_duration(r["covered"]), 100.0 * r["covered"] / total))
    if r["gaps"]:
        print("gaps     %d longer than %s, %s skipped"
              % (r["gaps"], args.max_gap, fmt_duration(r["gap_seconds"])))
    print("charge   %.3f mAh" % r["mah"])
    print("energy   %.5f Wh" % r["wh"])
    if r["covered"] > 0:
        print("average  %.2f mA, %.2f mW over the integrated time"
              % (r["mah"] * 3600.0 / r["covered"], r["wh"] * 3.6e6 / r["covered"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
