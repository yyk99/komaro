#!/usr/bin/python3
#
# Plot temperature and humidity from multiple InfluxDB measurements on one chart.
#
# Usage: plot_multi_sensor.py [influx_host] [time_range] [window] [measurements]
#   influx_host:   InfluxDB hostname (default: localhost)
#   time_range:    InfluxDB time range, e.g. 1h, 7d, 30d, all (default: 7d)
#   window:        moving average window size (default: 10)
#   measurements:  comma-delimited list of measurement names (default: sensor)

import sys
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import matplotlib.ticker as mticker
from datetime import datetime
from influxdb import InfluxDBClient
from plot_sensor import moving_average

INFLUX_PORT = 8086
INFLUX_DB = "komaro"

LINE_STYLES = ["-", "--", "-.", ":", (0, (3, 1, 1, 1)), (0, (5, 2))]


def main(influx_host="localhost", time_range="7d", window=10, measurements=None):
    if measurements is None:
        measurements = ["sensor"]

    client = InfluxDBClient(host=influx_host, port=INFLUX_PORT, database=INFLUX_DB)

    local_tz = str(datetime.now().astimezone().tzinfo)
    plt.rcParams['timezone'] = local_tz
    plt.rcParams.update({"font.size": 16})

    fig, ax_temp = plt.subplots(figsize=(12, 6))
    ax_humid = ax_temp.twinx()

    for i, measurement in enumerate(measurements):
        try:
            if time_range == "all":
                query = f"SELECT temperature_c, humidity FROM {measurement}"
            else:
                query = f"SELECT temperature_c, humidity FROM {measurement} WHERE time > now() - {time_range}"
            result = client.query(query)
            points = list(result.get_points())
        except Exception as e:
            print(f"Warning: could not query {measurement} - {e}", file=sys.stderr)
            continue

        if not points:
            print(f"Warning: no data for {measurement}", file=sys.stderr)
            continue

        times = [datetime.fromisoformat(p["time"]) for p in points]
        temps = moving_average([p["temperature_c"] for p in points], window)
        humids = moving_average([p["humidity"] for p in points], window)

        ls = LINE_STYLES[i % len(LINE_STYLES)]

        ax_temp.plot(times, temps, linewidth=0.8, color="red", linestyle=ls, label=f"{measurement} - Temp")
        ax_humid.plot(times, humids, linewidth=0.8, color="blue", linestyle=ls, label=f"{measurement} - Humid")

    ax_temp.set_ylabel("Temperature (C / F)", color="red")
    ax_temp.tick_params(axis="y", labelcolor="red")
    ax_temp.yaxis.set_major_formatter(mticker.FuncFormatter(
        lambda c, _: f"{c:.0f}C / {c * 9 / 5 + 32:.0f}F"))

    ax_humid.set_ylabel("Humidity (%)", color="blue")
    ax_humid.tick_params(axis="y", labelcolor="blue")

    names = ", ".join(measurements)
    title = f"{names} - all" if time_range == "all" else f"{names} - last {time_range}"
    ax_temp.set_title(title)
    ax_temp.set_xlabel(f"Time ({local_tz})")
    ax_temp.grid(True, alpha=0.3)

    ax_temp.xaxis.set_major_formatter(mdates.DateFormatter("%m-%d %H:%M"))
    lines1, labels1 = ax_temp.get_legend_handles_labels()
    lines2, labels2 = ax_humid.get_legend_handles_labels()
    fig.legend(lines1 + lines2, labels1 + labels2, loc="upper right", bbox_to_anchor=(0.98, 0.95))
    fig.autofmt_xdate()
    plt.tight_layout()

    outfile = "multi_sensor_plot.png"
    plt.savefig(outfile, dpi=150)
    print(f"Saved {outfile}")
    plt.show()


if __name__ == "__main__":
    host = sys.argv[1] if len(sys.argv) >= 2 else "localhost"
    time_range = sys.argv[2] if len(sys.argv) >= 3 else "7d"
    window = int(sys.argv[3]) if len(sys.argv) >= 4 else 10
    measurements = sys.argv[4].split(",") if len(sys.argv) >= 5 else ["sensor"]
    main(host, time_range, window, measurements)
