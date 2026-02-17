#!/bin/bash
#
# Read DHT11 sensor from /dev/dht11 and publish to MQTT.
#
# Usage: dht11_reader.sh [topic_prefix] [mqtt_host]
#

TOPIC_PREFIX="${1:-home/living_room}"
MQTT_HOST="${2:-localhost}"
TOPIC_TEMP="$TOPIC_PREFIX/temperature"
TOPIC_HUMID="$TOPIC_PREFIX/humidity"

reading=$(cat /dev/dht11)

case "$reading" in
    T:*)
        temp=$(echo "$reading" | sed 's/T: \(.*\)C H: .*/\1/')
        humid=$(echo "$reading" | sed 's/.*H: \(.*\)%.*/\1/')
        mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_TEMP" -m "$temp"
        mosquitto_pub -h "$MQTT_HOST" -t "$TOPIC_HUMID" -m "$humid"
        echo "$reading"
        ;;
    *)
        echo "Error: $reading" >&2
        exit 1
        ;;
esac
