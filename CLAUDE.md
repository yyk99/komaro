# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KOMARO is an environmental sensor data retrieval project. It communicates with a Nano-based sensor device over UDP (port 2390) to collect temperature/moisture readings, and logs the data via cron jobs.

## Architecture

- `nano/nanoget.py` - Core library: UDP client that sends `CONNECT`/`CLOSE` messages to a sensor device and unpacks binary response data using `struct.unpack('<IiiiIII')` (little-endian, fixed 4-byte integers for portability across 32/64-bit hosts)
- `nano/nanoget_snapshot.py` - Simple snapshot script using hardcoded sensor IP
- `nano/nanoget_snapshot2.py` - Snapshot script that accepts sensor IP as a CLI argument; intended to be run from cron every 5 minutes
- `nano/nanoget.ipynb` - Jupyter notebook for interactive testing of `nanoget` module
- `nano/plot_sensor.py` - Module to query InfluxDB and plot temperature/humidity with matplotlib; supports `all` time range
- `nano/plot_sensor.ipynb` - Jupyter notebook for interactive use of `plot_sensor` module
- `nano/import_log.py` - Backfill historical log records into InfluxDB; supports stdin via `-`
- `nano/moisture.bat` - Windows batch file for quick testing

## Running

```bash
# Direct test
python3 nano/nanoget.py

# Snapshot with custom IP
python3 nano/nanoget_snapshot2.py 192.168.68.67
```

## Infrastructure

The project uses mosquitto (MQTT), InfluxDB, and Telegraf for the data pipeline. See README.md for install instructions.

## Git

- Main branch: `master`
- Feature branch naming: `f/<username>/<feature>`
