# mosquitto_stuff

## Install

   sudo apt update
   sudo apt install mosquitto mosquitto-clients

## Basic commands

   sudo systemctl start mosquitto    # Start
   sudo systemctl enable mosquitto   # Auto-start on boot
   sudo systemctl status mosquitto   # Check status

## Testing

   # Subscribe (in one terminal)
   mosquitto_sub -h localhost -t test/topic

   # Publish (in another terminal)
   mosquitto_pub -h localhost -t test/topic -m "Hello MQTT"

## Configure Mosquitto

   sudo nano /etc/mosquitto/mosquitto.conf
