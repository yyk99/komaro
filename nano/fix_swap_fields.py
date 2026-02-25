#!/usr/bin/python3
#
# One-off script to swap humidity and temperature_f fields in InfluxDB.
#
# Usage: fix_swap_fields.py [influx_host]

import sys
from influxdb import InfluxDBClient

INFLUX_HOST = sys.argv[1] if len(sys.argv) >= 2 else "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "komaro"

client = InfluxDBClient(host=INFLUX_HOST, port=INFLUX_PORT, database=INFLUX_DB)
points = list(client.query("SELECT * FROM sensor").get_points())

if not points:
    print("No data found.", file=sys.stderr)
    sys.exit(1)

corrected = []
for p in points:
    corrected.append({
        "measurement": "sensor",
        "time": p["time"],
        "fields": {
            "serial": p["serial"],
            "accel_x": p["accel_x"],
            "accel_y": p["accel_y"],
            "accel_z": p["accel_z"],
            "humidity": p["temperature_f"],
            "temperature_c": p["temperature_c"],
            "temperature_f": p["humidity"],
        }
    })

client.drop_measurement("sensor")
client.write_points(corrected, batch_size=1000)
print(f"Fixed {len(corrected)} records")
