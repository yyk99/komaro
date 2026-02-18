#!/usr/bin/python3
#
# Subscribe to MQTT temperature/humidity topics and write to InfluxDB.
#
# Usage: mqtt2influx.py [mqtt_host] [influx_host] [measurement]
#
# Subscribes to: home/<measurement>/temperature, home/<measurement>/humidity
# Writes fields: temperature_c, humidity

import sys
import paho.mqtt.client as mqtt
from influxdb import InfluxDBClient

MQTT_HOST = "localhost"
MQTT_PORT = 1883
INFLUX_HOST = "localhost"
INFLUX_PORT = 8086
INFLUX_DB = "komaro"
MEASUREMENT = "living_room"

if len(sys.argv) >= 2 and sys.argv[1] == "-h":
    print(f"Usage: {sys.argv[0]} [mqtt_host] [influx_host] [measurement]")
    sys.exit(0)

if len(sys.argv) >= 2:
    MQTT_HOST = sys.argv[1]
if len(sys.argv) >= 3:
    INFLUX_HOST = sys.argv[2]
if len(sys.argv) >= 4:
    MEASUREMENT = sys.argv[3]

influx = InfluxDBClient(host=INFLUX_HOST, port=INFLUX_PORT, database=INFLUX_DB)

TOPIC_PREFIX = f"home/{MEASUREMENT}"
FIELD_MAP = {
    f"{TOPIC_PREFIX}/temperature": "temperature_c",
    f"{TOPIC_PREFIX}/humidity": "humidity",
}


def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print(f"Connected to MQTT broker at {MQTT_HOST}:{MQTT_PORT}")
        client.subscribe(f"{TOPIC_PREFIX}/+")
    else:
        print(f"MQTT connection failed with code {rc}", file=sys.stderr)


def on_message(client, userdata, msg):
    field = FIELD_MAP.get(msg.topic)
    if not field:
        return
    try:
        value = float(msg.payload)
    except ValueError:
        print(f"Invalid value on {msg.topic}: {msg.payload}", file=sys.stderr)
        return

    point = {
        "measurement": MEASUREMENT,
        "fields": {field: value},
    }
    influx.write_points([point])
    print(f"{field}={value}")


client = mqtt.Client()
client.on_connect = on_connect
client.on_message = on_message

try:
    client.connect(MQTT_HOST, MQTT_PORT)
    client.loop_forever()
except KeyboardInterrupt:
    print("\nStopped.")
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
