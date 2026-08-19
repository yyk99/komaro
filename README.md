# KOMARO project

A simple environmental sensor retrieval project

## Software

The software to be used:

    sudo apt update
    sudo apt install mosquitto mosquitto-clients

    # Install InfluxDB
    sudo apt install influxdb influxdb-client
    sudo systemctl start influxdb

    # Install Telegraf (MQTT to InfluxDB bridge)
    sudo apt install telegraf

## Under the hood

There are two independent sensor-ingestion pipelines in this repo, both writing into the same InfluxDB database (`komaro`).

### Components

- **InfluxDB** — the time-series database. It's the single point of storage both pipelines converge on, and the only thing `nano/plot_sensor.py`, `nano/plot_multi_sensor.py`, and the QML app's `InfluxDbClient` ever query.
- **mosquitto** — an MQTT broker (pub/sub message bus), used only by the `pino/` (Raspberry Pi + DHT11) pipeline. `pino/dht11_reader.sh` reads `/dev/dht11` and *publishes* readings to it as MQTT topics — `home/<location>/temperature`, `home/<location>/humidity`, and a combined `home/<location>/dht11` message already in InfluxDB line-protocol format (`dht11 temperature_c=21.10,humidity=31.00`). Mosquitto itself doesn't store anything; it just relays those messages to whoever's subscribed.
- **Telegraf** — a metrics-collection agent, configured (`telegraf/telegraf_mqtt.conf`) as an MQTT-to-InfluxDB bridge: it *subscribes* to `home/+/dht11` on mosquitto, parses the already-InfluxDB-formatted payload, pulls the location out of the topic path to use as the measurement name, and writes straight to InfluxDB. It's an alternative to `pino/mqtt2influx.py` — same job (MQTT subscriber → InfluxDB writer), done via config instead of a hand-rolled script. You'd run one or the other, not both.

### How UDP is used

UDP only shows up in the other, unrelated pipeline — `nano/` (the Arduino Nano 33 IoT board) — and mosquitto/Telegraf play no role there at all. It's a simple custom request/response protocol over a raw UDP socket, port 2390 (`nano/nanoget.py`):

1. Open a UDP socket, `sendto()` the ASCII command `CONNECT\r\n` to the board.
2. Wait (10s timeout, via `select`) for an ack datagram (`OK Connected\r\n`).
3. Wait for a second datagram — a fixed 28-byte binary payload — and unpack it with `struct.unpack('<IiiiIII', data)`: little-endian, 1 unsigned int + 3 signed ints + 3 unsigned ints → `(serial, accel_x, accel_y, accel_z, humidity*100, temp_c*100, temp_f*100)`.
4. `sendto()` a closing `CLOSE\r\n` command and close the socket.

`nano/nanoget_snapshot2.py` runs this from cron every 5 minutes; `nano/nanoget2influx.py` does the same and writes the unpacked fields directly to InfluxDB via HTTP (the `influxdb` Python client) — no broker in between. UDP is purely the wire protocol between the Python poller and the physical Nano board; InfluxDB gets the data via a direct write, not through mosquitto/Telegraf.

## nanoget

The crontab fragment:

    */5 * * * * src/python_junk/nano/nanoget_snapshot2.py 192.168.68.67 >> nanoget.log

The Raspberry PI host:
```
Linux vrijdag.home 6.1.21-v8+ #1642 SMP PREEMPT Mon Apr  3 17:24:16 BST 2023 aarch64 GNU/Linux
```
Example output from the nanoget.py module at the host:
```
pi@vrijdag:~/src/python_junk/nano $ ./nanoget.py
UDP target IP: 192.168.68.67
UDP target port: 2390
message: b'CONNECT\r\n'
ready: b'OK Connected\r\n'
data b"{\xe8\xd2\x0b\r\x03\x00\x00\xf5\x01\x00\x00'\x01\x00\x00<\x0f\x00\x00\xd0\x02\x00\x00\x90\x11\x00\x00" 28
(198371451, 781, 501, 295, 3900, 720, 4496)
```

## Windows

The `nano/` plotting and query scripts (`plot_sensor.py`, `plot_multi_sensor.py`, `import_log.py`, `nanoget2influx.py`, etc.) also run on Windows against a remote InfluxDB host. Set up a virtual environment and install dependencies from `requirements.txt`:

    py -m venv .venv
    .venv\Scripts\python.exe -m pip install -r requirements.txt

Then run scripts with the venv's interpreter, e.g.:

    .venv\Scripts\python.exe nano\plot_sensor.py silvana.home

Note: on Python versions before 3.11, `datetime.fromisoformat()` cannot parse the `Z`-suffixed UTC timestamps InfluxDB returns (e.g. `2026-08-05T19:05:03.476179Z`). The scripts work around this by replacing `Z` with `+00:00` before parsing, so any Python 3.7+ interpreter works on both Windows and Linux.

## Grafana (optional)

Grafana isn't in the default Debian/Raspberry Pi OS repos. You need to add their repository first:

   # Add Grafana GPG key and repo
   sudo apt install -y apt-transport-https software-properties-common
   wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/grafana-archive-keyring.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

   # Now install
   sudo apt update
   sudo apt install grafana

Then:

   sudo systemctl enable grafana-server
   sudo systemctl start grafana-server
