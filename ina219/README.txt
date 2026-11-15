ina219 - tools for the INA219 power sensor readings
===================================================

The readings (bus_v, load_v, shunt_mv, current_ma, power_mw) are written to
InfluxDB 1.x as measurement "ina219" in database "ina219" (not in the "komaro"
database of the temperature/humidity sensors), one sensor per "sensor" tag
value, e.g. sensor4. They can be viewed on the Power tab of the qml/ app.

ina219_energy.py
----------------
Integrates the consumed charge (mAh) and energy (Wh) of one sensor over a
period. Needs the "influxdb" Python package (see ../requirements.txt).

  ina219_energy.py SENSOR [options]

  --influx-host HOST   InfluxDB host (default localhost)
  --influx-port PORT   InfluxDB port (default 8086)
  --database DB        database (default ina219)
  --measurement NAME   measurement (default ina219)
  --since DURATION     length of the period: 30s, 5m, 6h, 7d, 2w (default 24h)
  --start TIME         exact start of the period, ISO date-time, or now
  --end TIME           end of the period (exclusive), ISO date-time, or now
  --max-gap DURATION   do not integrate across holes in the data longer than
                       this (default 5m)

The period is chosen like this:
  - no --start, no --end:  the last --since, up to now
  - --start only:          --since long, starting at --start
  - --end only:            --since long, ending at --end
  - --start and --end:     exactly that; --since is ignored

TIME is an ISO 8601 date or date-time: 2026-11-14, 2026-11-14T08:30:00,
"2026-11-14 08:30". A time without an offset is UTC, NOT local time. Give an
offset or Z to be explicit: 2026-11-14T08:30:00-05:00, 2026-11-14T13:30:00Z.
The period is printed in UTC. "now" (either option) is the current time, taken
once when the script starts.

Examples:
  ina219_energy.py sensor4 --influx-host silvana.home
  ina219_energy.py sensor4 --influx-host silvana.home --since 7d
  ina219_energy.py sensor4 --start 2026-11-14T08:30:00 --since 12h
  ina219_energy.py sensor4 --start 2026-11-10 --end 2026-11-11
  ina219_energy.py sensor4 --start "2026-11-10 08:00" --end now

Example output:
  sensor   sensor4 (ina219.ina219 on silvana.home)
  period   2026-11-14 09:24:08 UTC .. 2026-11-15 09:24:08 UTC  (24h 00m 00s)
  samples  2759, integrated over 23h 59m 32s (100.0% of the period)
  charge   807.103 mAh
  energy   3.01314 Wh
  average  33.64 mA, 125.59 mW over the integrated time

How it is computed:
  charge [mAh] = integral of current_ma dt / 3600
  energy [Wh]  = integral of power_mw dt / 3600 / 1000
using the trapezoidal rule between consecutive samples (about 30 s apart).
  - Holes: an interval longer than --max-gap (sensor off, network down) is
    skipped rather than interpolated, and reported as a gap together with the
    fraction of the period that was actually integrated.
  - The result is net: a negative current (charging) subtracts.
  - Energy uses the stored power_mw field, which is a whole number of mW
    (the INA219 power register is coarse).

Exit status is 1 if the query fails or the period has fewer than two samples.

Tests (no InfluxDB needed):
  python3 -m unittest test_ina219_energy
