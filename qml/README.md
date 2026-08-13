# Qt/QML based apps

A QML app to display temperature/humidity plots from InfluxDB, targeting desktop and Android, similar in purpose to the `nano/plot_sensor.py` / `nano/plot_multi_sensor.py` Python scripts.

## Status

Desktop skeleton in `desktop/`: a Qt Quick `ApplicationWindow` with `File`/`Help` menus and a placeholder plot area filling the space below the menu bar. No InfluxDB querying or charting wired up yet. Android target not started.

## Backend

Starting with a C++ backend (native Qt Quick app, CMake + Qt for Android). Other backends (e.g. PySide6/Python, reusing the existing `nano/` InfluxDB query code) may be added later.

## Desktop build

Qt 6.8.3 (LTS) is installed directly at `E:\qt6\6.8.3\msvc2022_64` and used via `CMAKE_PREFIX_PATH`. Using the CMake bundled with Visual Studio 2022 and the `windows-msvc` preset in `desktop/CMakePresets.json`:

```
cd qml/desktop
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
```

`desktop/vcpkg.json` (against the vcpkg instance at `G:\opt\vcpkg`) is kept for any non-Qt dependencies added later; it isn't wired into the presets above, so Qt itself is not built from source via vcpkg.
