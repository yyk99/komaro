# Pino sensor

This is a DHT11 sensor presented with /dev/dht11 driver.
The /dev/dht11 is connected to dht11_module

The example of /dev/dht11 input

```
T: 18.50C H: 28.00%
```

or in case of error

```
Inconsistent data
```

## Prerequisites

```
sudo apt install mosquitto-clients
sudo modprobe dht11_module
```

## dht11_reader.sh

Reads `/dev/dht11` and publishes temperature and humidity via MQTT.

```
./dht11_reader.sh [topic_prefix] [mqtt_host]
```

- `topic_prefix` - MQTT topic prefix (default: `home/living_room`)
- `mqtt_host` - MQTT broker address (default: `localhost`)

MQTT topics published:
- `<topic_prefix>/temperature` - temperature in Celsius
- `<topic_prefix>/humidity` - relative humidity in percent
