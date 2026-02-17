#!/usr/bin/python3
#
# Plot temperature and humidity time-series from InfluxDB.
#
# Usage: plot_sensor.py [influx_host] [time_range]
#   influx_host: InfluxDB hostname (default: localhost)
#   time_range:  InfluxDB time range, e.g. 1h, 7d, 30d, all (default: 7d)

import sys
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime
from influxdb import InfluxDBClient

INFLUX_PORT = 8086
INFLUX_DB = "komaro"


def main(influx_host="localhost", time_range="7d"):
    try:
        client = InfluxDBClient(host=influx_host, port=INFLUX_PORT, database=INFLUX_DB)
        if time_range == "all":
            query = "SELECT temperature_c, humidity FROM sensor"
        else:
            query = f"SELECT temperature_c, humidity FROM sensor WHERE time > now() - {time_range}"
        result = client.query(query)
        points = list(result.get_points())
    except Exception as e:
        print(f"Error: could not query InfluxDB at {influx_host}:{INFLUX_PORT} - {e}", file=sys.stderr)
        sys.exit(1)

    if not points:
        print("No data found.", file=sys.stderr)
        sys.exit(1)

    times = [datetime.fromisoformat(p["time"].replace("Z", "+00:00")) for p in points]
    temps = [p["temperature_c"] for p in points]
    humids = [p["humidity"] for p in points]

    plt.rcParams.update({"font.size": 16})

    fig, ax_temp = plt.subplots(figsize=(12, 6))

    ax_temp.plot(times, temps, linewidth=0.8, color="red", label="Temperature (C)")
    ax_temp.set_ylabel("Temperature (C)", color="red")
    ax_temp.tick_params(axis="y", labelcolor="red")

    ax_humid = ax_temp.twinx()
    ax_humid.plot(times, humids, linewidth=0.8, color="blue", label="Humidity (%)")
    ax_humid.set_ylabel("Humidity (%)", color="blue")
    ax_humid.tick_params(axis="y", labelcolor="blue")

    title = "Sensor data - all" if time_range == "all" else f"Sensor data - last {time_range}"
    ax_temp.set_title(title)
    ax_temp.set_xlabel("Time")
    ax_temp.grid(True, alpha=0.3)

    ax_temp.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d %H:%M"))
    fig.legend(loc="upper right", bbox_to_anchor=(0.98, 0.95))
    fig.autofmt_xdate()
    plt.tight_layout()

    plt.savefig("sensor_plot.png", dpi=150)
    print("Saved sensor_plot.png")
    plt.show()


if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) >= 2 else "localhost"
    time_range = sys.argv[2] if len(sys.argv) >= 3 else "7d"
    main(host, time_range)
