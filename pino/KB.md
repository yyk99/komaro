# Topic naming best practice

## **Standard Structure**

```
<location>/<device>/<measurement>
```

**Examples for your temperature/humidity sensors:**
```
home/bedroom/temperature
home/bedroom/humidity
home/kitchen/temperature
home/kitchen/humidity
home/basement/temperature
home/basement/humidity
```

Or with device IDs:
```
home/bedroom/sensor01/temperature
home/bedroom/sensor01/humidity
home/livingroom/sensor02/temperature
```

## **Key Principles**

### **1. Use forward slashes `/` as separators**
- Standard MQTT convention
- Enables wildcard subscriptions

### **2. Go from general → specific**
```
building/floor/room/device/measurement
```

Examples:
```
house/ground/kitchen/temp_sensor/temperature
house/ground/kitchen/temp_sensor/humidity
house/upstairs/bedroom/temp_sensor/temperature
```

### **3. Use lowercase and underscores**
```
✅ home/living_room/temperature
❌ Home/Living-Room/Temperature
```

### **4. Avoid leading/trailing slashes**
```
✅ home/bedroom/temperature
❌ /home/bedroom/temperature/
```

### **5. Keep it readable and descriptive**
```
✅ home/bedroom/temperature
❌ h/br/t
❌ sensor_12345/data/0
```

## **Wildcard Subscriptions**

Good naming enables powerful filtering:

```bash
# All data from bedroom
mosquitto_sub -t 'home/bedroom/#'

# All temperatures in home
mosquitto_sub -t 'home/+/temperature'

# Everything
mosquitto_sub -t '#'
```

- `+` = single level wildcard
- `#` = multi-level wildcard (must be at end)

## **Common Patterns**

### **Pattern 1: By Location**
```
home/bedroom/temperature
home/bedroom/humidity
home/kitchen/temperature
garage/temperature
outdoor/temperature
```

### **Pattern 2: By Device Type**
```
sensors/temperature/bedroom
sensors/temperature/kitchen
sensors/humidity/bedroom
sensors/humidity/kitchen
```

### **Pattern 3: Device-Centric**
```
devices/esp32_bedroom/temperature
devices/esp32_bedroom/humidity
devices/esp32_bedroom/battery
devices/esp32_bedroom/status
```

### **Pattern 4: Hierarchical Building**
```
building/floor1/room101/temperature
building/floor1/room101/humidity
building/floor2/room201/temperature
```

## **Additional Topics for Sensors**

Consider these alongside temperature/humidity:

```
home/bedroom/temperature        # °C or °F
home/bedroom/humidity           # %
home/bedroom/battery            # % or voltage
home/bedroom/rssi               # WiFi signal strength
home/bedroom/status             # online/offline
home/bedroom/uptime             # seconds
```

## **For Your Use Case**

I'd recommend **Pattern 1** (by location) since you're focused on monitoring rooms:

```
home/bedroom/temperature
home/bedroom/humidity
home/living_room/temperature
home/living_room/humidity
home/basement/temperature
home/basement/humidity
```

**Simple, clear, and easy to subscribe to specific rooms or all data.**

Would you like help configuring your ESP8266/ESP32 sensors to publish to these topics?
