# KOMARO project

A simple environmental sensor retrival project

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
