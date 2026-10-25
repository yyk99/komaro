# Pino sensor

This is a DHT11 sensor presented with a /dev/dht11 driver.
The /dev/dht11 is connected to a dht11_module

An example of /dev/dht11 input

```
T: 18.50C H: 28.00%
```

or in case of an error

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
- `<topic_prefix>/dht11` - combined, in InfluxDB line protocol format (e.g. `dht11 temperature_c=21.10,humidity=31.00`)

## serial_reader.sh

Same as `dht11_reader.sh`, but for a DHT22 attached to a Raspberry Pi Pico that
prints one reading every 2 s to its USB serial port, in the same format
(`T: 18.50C H: 28.00%`).
The firmware is the `dht22_driver` project of the pico_getting_started repo.

A serial port never ends, so `cat` would hang. `serial_reader.sh` puts the port
in raw mode and reads one line (giving up after 5 s); everything else (MQTT topics)
is the same as in `dht11_reader.sh`.

```
./serial_reader.sh [topic_prefix] [mqtt_host] [serial_device]
```

- `serial_device` - the Pico serial port (default: `/dev/ttyACM0`)

Your user needs to be in the `dialout` group to open the port.

## subscribe to topics

```
mosquitto_sub -h $MQTT_SERVER -t home/living_room/+ -v
```

Returns anything like:

```
home/living_room/temperature 21.10
home/living_room/humidity 31.00
home/living_room/temperature 21.00
home/living_room/humidity 31.00
...
```
