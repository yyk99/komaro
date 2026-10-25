#!/bin/bash
#
# Read DHT22 sensor from a Pico serial port (dht22_driver firmware) and publish to MQTT.
#
# Usage: serial_reader.sh [topic_prefix] [mqtt_host] [serial_device]
#

TOPIC_PREFIX="${1:-home/living_room}"
MQTT_HOST="${2:-localhost}"
SERIAL_DEV="${3:-/dev/ttyACM0}"
TOPIC_TEMP="$TOPIC_PREFIX/temperature"
TOPIC_HUMID="$TOPIC_PREFIX/humidity"
TOPIC_DHT11="$TOPIC_PREFIX/dht11"

stty -F "$SERIAL_DEV" raw -echo || exit 1
# a serial port never ends: read one line, give up after 5 s
reading=$(timeout 5 head -n1 "$SERIAL_DEV")

case "$reading" in
    T:*)
        temp=$(echo "$reading" | sed 's/T: \(.*\)C H: .*/\1/')
        humid=$(echo "$reading" | sed 's/.*H: \(.*\)%.*/\1/')
        mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_TEMP" -m "$temp"
        mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_HUMID" -m "$humid"
        mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_DHT11" -m "dht11 temperature_c=$temp,humidity=$humid"
        echo "$reading"
        ;;
    *)
        echo "Error: $reading" >&2
        exit 1
        ;;
esac
