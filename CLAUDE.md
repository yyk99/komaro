# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KOMARO is an environmental sensor data retrieval project. It communicates with a Nano-based sensor device over UDP (port 2390) to collect temperature/moisture readings, and logs the data via cron jobs. A second, MQTT-based pipeline (`pino/` + `mosquitto` + `telegraf/`) ingests DHT11 readings from a Raspberry Pi. Both pipelines write into the same InfluxDB database; see README.md's "Under the hood" section for how the components fit together. `qml/` is a Qt6/QML desktop+Android app that queries and charts that data, as an alternative to the `nano/plot_*.py` matplotlib scripts.

## Architecture

- `nano/nanoget.py` - Core library: UDP client that sends `CONNECT`/`CLOSE` messages to a sensor device and unpacks binary response data using `struct.unpack('<IiiiIII')` (little-endian, fixed 4-byte integers for portability across 32/64-bit hosts)
- `nano/nanoget_snapshot.py` - Simple snapshot script using hardcoded sensor IP
- `nano/nanoget_snapshot2.py` - Snapshot script that accepts sensor IP as a CLI argument; intended to be run from cron every 5 minutes
- `nano/nanoget.ipynb` - Jupyter notebook for interactive testing of `nanoget` module
- `nano/plot_sensor.py` - Module to query InfluxDB and plot temperature/humidity with matplotlib; supports `all` time range, moving average smoothing, and configurable measurement name
- `nano/plot_multi_sensor.py` - Plot multiple measurements on one chart; comma-delimited measurement list; distinguishes series by line style (solid, dashed, dash-dot, dotted); reuses `moving_average` from `plot_sensor`
- `nano/plot_sensor.ipynb` - Jupyter notebook for interactive use of `plot_sensor` module
- `nano/import_log.py` - Backfill historical log records into InfluxDB; supports stdin via `-`
- `nano/nanoget2influx.py` - Read sensor and write to InfluxDB; supports configurable measurement name; skips records with NaN values (9999)
- `nano/fix_swap_fields.py` - One-off script to swap humidity/temperature_f fields in InfluxDB
- `nano/moisture.bat` - Windows batch file for quick testing
- `pino/dht11_reader.sh` - Read DHT11 sensor from `/dev/dht11` and publish to MQTT (individual and combined topics)
- `pino/mqtt2influx.py` - Subscribe to MQTT temperature/humidity topics and write to InfluxDB
- `telegraf/telegraf_mqtt.conf` - Telegraf config to subscribe to MQTT dht11 topic and write to InfluxDB

### qml/ - Qt6/QML sensor viewer (desktop + Android)

A C++/QML app that queries InfluxDB and charts temperature/humidity, mirroring `nano/plot_sensor.py`. Three CMake projects, each with its own `CMakePresets.json`. See `qml/KB.md` for QML/Qt topics (e.g. the headless visual-verification technique used to check chart rendering) that don't fit `README.md`.

- `qml/core/` - static libs shared by both shells, no UI of its own:
  - `komaro_core` - `InfluxResponseParser`, `InfluxDbClient` (async `QNetworkAccessManager`), `RecentServers`, `MovingAverage`, `ChartController`, `ConnectionManager`, `SensorPoint`. GTest suite in `tests/` (`BUILD_TESTS` cache var, default `ON`).
  - `komaro_core_qml` - QML module `KomaroCore`: `AppActions.qml` (shared Connect/About/Exit actions) and `SensorChart.qml` (hand-rolled `Canvas` dual-axis chart - no Qt Charts/Graphs installed in the Qt kit).
- `qml/desktop/` - `MenuBar` shell (`komaro_qml_desktop`).
- `qml/mobile/` - `ToolBar`+`Drawer` (Material Dark) shell (`komaro_qml_mobile`), buildable as either a desktop prototype or a real Android APK.

Build/test (see `qml/README.md`, `qml/core/README.md`, `qml/mobile/README.md` for full detail):

```
cd qml/desktop   # or qml/core, qml/mobile
cmake --preset windows-msvc      # or linux-rpi on the Raspberry Pi dev box
cmake --build --preset windows-msvc-debug     # or linux-rpi-debug
ctest --preset windows-msvc-debug             # or linux-rpi-debug
```

Android build (`qml/mobile` only): `cmake --preset android-arm64 && cmake --build build/android-arm64 --target apk`. Requires the Android SDK/NDK to live under a **space-free path** (`sdkmanager.bat` and Gradle packaging both break under `Program Files (x86)`), NDK r26b (must match `android_arm64_v8a/mkspecs/qdevice.pri`), and `platforms;android-35`+ (Qt's bundled AndroidX deps need compileSdk >= 34).

Non-obvious build gotchas worth knowing before touching `qml/core/CMakeLists.txt`:
- `komaro_core`'s Q_OBJECT headers must be listed explicitly in `add_library()`, not just their `.cpp` files - AUTOMOC's transitive-include scanning otherwise silently mocs nothing.
- `komaro_core_qml` is a separate target from `komaro_core` (not `qt_add_qml_module` attached to an existing lib) - otherwise the generated QML plugin doesn't propagate to consumers.
- `ConnectionManager`/`ChartController` are exposed via `QQmlContext::setContextProperty` (in each app's `main.cpp`), not `QML_ELEMENT` - see `qml/core/README.md` for why.
- The `windeployqt` post-build step in `qml/mobile/CMakeLists.txt` is guarded with `if(NOT ANDROID)` - `Qt6::qmake` resolves to the *host* Qt kit under the Android toolchain, so without the guard it runs against the Android `.so` and fails.
- `qt_add_qml_module` needs `qt_policy(SET QTP0004 NEW)` set beforehand in all three `CMakeLists.txt` - each project's `QML_FILES` live under a `qml/` subdirectory of the module's resource root, which Qt 6.8+ otherwise warns about wanting to treat as an "extra" importable sub-namespace.
- Persisted UI prefs (e.g. `desktop/qml/Main.qml`'s time-range/units `Settings {}` block) use the `QtCore` QML module, not the deprecated `Qt.labs.settings` - it needs `QCoreApplication::setOrganizationName("Komaro")`/`setApplicationName("QmlApp")` set in each app's `main.cpp` to land under the same `~/.config/Komaro/` directory as `ConnectionManager`'s `QSettings` (a different file though: `QmlApp.conf`/`NativeFormat` vs `ConnectionManager`'s explicit `QmlApp.ini`/`IniFormat`).

## Running

```bash
# Direct test
python3 nano/nanoget.py

# Snapshot with custom IP
python3 nano/nanoget_snapshot2.py 192.168.68.67
```

### Windows

The `nano/` scripts also run on Windows (tested against a remote InfluxDB host, no local mosquitto/InfluxDB/Telegraf install needed for the query/plot scripts). Use a venv and `requirements.txt`:

```
py -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe nano\plot_sensor.py silvana.home
```

`datetime.fromisoformat()` only accepts the `Z` UTC suffix InfluxDB emits on Python 3.11+; earlier versions (e.g. the 3.9 commonly found on Windows) raise `ValueError: Invalid isoformat string`. `plot_sensor.py` and `plot_multi_sensor.py` work around this by replacing `Z` with `+00:00` before parsing — keep that pattern when adding new timestamp parsing code so scripts stay portable across Python versions and OSes.

## Infrastructure

The project uses mosquitto (MQTT), InfluxDB, and Telegraf for the data pipeline. See README.md for install instructions.

For `qml/` on this Windows dev machine: Qt 6.8.3 at `E:\qt6\6.8.3\` (`msvc2022_64`, `android_arm64_v8a`, etc.), vcpkg at `G:\opt\vcpkg` (GTest only), Android SDK/NDK at `C:\Users\<user>\android-sdk` (deliberately not under `Program Files`), JDK 17 for Gradle.

For `qml/` on the Raspberry Pi Linux dev box (the `linux-rpi` preset): Ninja Multi-Config against a self-built Qt 6.11.1 tree at `/home/yyk/Downloads/qt-everywhere-src-6.11.1/qtbase` (set via `CMAKE_PREFIX_PATH` in the preset, not a system Qt), GTest via the `libgtest-dev` apt package. `windeployqt` doesn't exist on Linux, so the post-build deploy step just no-ops with a warning - fine, since nothing packages this build for distribution.

## Git

- Main branch: `master`
- Feature branch naming: `f/<username>/<feature>`
- Pull request titles must include the PR id as a `(#<id>)` suffix, e.g. `Add units toggle, persisted UI prefs, and Android build docs (#7)` - this becomes the squash-merge commit title, so set it explicitly when merging (`gh pr merge --squash --subject "... (#<id>)"`) rather than relying on GitHub's default
