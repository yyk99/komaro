#!/usr/bin/python3
#
# Usage: nanoget2influx.py [sensor_ip] [influx_host] [measurement]

import sys
import os
import time

sys.path.append(os.path.dirname(__file__))

import nanoget
from influxdb import InfluxDBClient

INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "komaro"
MEASUREMENT = "sensor"

def write_record(client, record, measurement):
    point = {
        "measurement": measurement,
        "fields": {
            "serial": record[0],
            "accel_x": record[1],
            "accel_y": record[2],
            "accel_z": record[3],
            "humidity": record[4] / 100.0,
            "temperature_c": record[5] / 100.0,
            "temperature_f": record[6] / 100.0,
        }
    }
    client.write_points([point])

if len(sys.argv) >= 2 and sys.argv[1] == "-h":
    print(f"Usage: {sys.argv[0]} [sensor_ip] [influx_host] [measurement]")
    sys.exit(0)

try:
    if len(sys.argv) >= 2:
        nanoget.UDP_IP = sys.argv[1]
    if len(sys.argv) >= 3:
        INFLUX_HOST = sys.argv[2]
    if len(sys.argv) >= 4:
        MEASUREMENT = sys.argv[3]

    client = InfluxDBClient(host=INFLUX_HOST, port=INFLUX_PORT, database=INFLUX_DB)

    res = nanoget.get_record()
    print(time.time(), *res)
    write_record(client, res, MEASUREMENT)

    time.sleep(1.5)
    res = nanoget.get_record()
    print(time.time(), *res)
    write_record(client, res, MEASUREMENT)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
