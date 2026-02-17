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
