#!/usr/bin/python3
#
# Import nanoget.log historical records into InfluxDB.
#
# Usage: import_log.py [--dry-run] <logfile | -> [influx_host]
#   tail -10000 huge_log_file.log | import_log.py -
#
# Log format (from nanoget_snapshot2.py):
#   <unix_timestamp> <serial> <accel_x> <accel_y> <accel_z> <temp_f> <temp_c> <humidity>

import sys
from influxdb import InfluxDBClient

INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "komaro"

args = [a for a in sys.argv[1:] if not a.startswith('--')]
dry_run = '--dry-run' in sys.argv

if len(args) < 1:
    print(f"Usage: {sys.argv[0]} [--dry-run] <logfile> [influx_host]", file=sys.stderr)
    sys.exit(1)

logfile = args[0]
if len(args) >= 2:
    INFLUX_HOST = args[1]

if dry_run:
    print("Dry run mode - no data will be written to InfluxDB")
    client = None
else:
    client = InfluxDBClient(host=INFLUX_HOST, port=INFLUX_PORT, database=INFLUX_DB)

count = 0
errors = 0
f = sys.stdin if logfile == "-" else open(logfile)
with f:
    for lineno, line in enumerate(f, 1):
        line = line.strip()
        if not line:
            continue
        try:
            parts = line.split()
            if len(parts) != 8:
                print(f"Line {lineno}: expected 8 fields, got {len(parts)}, skipping", file=sys.stderr)
                errors += 1
                continue
            ts = int(float(parts[0]) * 1e9)
            point = {
                "measurement": "sensor",
                "time": ts,
                "fields": {
                    "serial": int(parts[1]),
                    "accel_x": int(parts[2]),
                    "accel_y": int(parts[3]),
                    "accel_z": int(parts[4]),
                    "temperature_f": int(parts[5]) / 100.0,
                    "temperature_c": int(parts[6]) / 100.0,
                    "humidity": int(parts[7]) / 100.0,
                }
            }
            if not dry_run:
                client.write_points([point], time_precision='n')
            count += 1
        except Exception as e:
            print(f"Line {lineno}: {e}", file=sys.stderr)
            errors += 1

print(f"Imported {count} records, {errors} errors")
