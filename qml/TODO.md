# qml TODO

## Data / backend

- [x] Wire the Connect dialog's host field to `InfluxDbClient`, with a recent-server history (`ConnectionManager`, persisted via `QSettings`)
- [x] Add unit/integration coverage for `InfluxDbClient` itself (query building, plus a `QTcpServer`-backed fake HTTP server exercising the real success/InfluxDB-error/connection-refused paths)
- [ ] `ConnectionManager`'s "connect" is just a one-shot `SELECT ... FROM sensor WHERE time > now() - 1h` used as a connectivity probe; revisit once real querying/measurement selection exists

## Plotting

- [x] Replace the placeholder plot area with a real temperature/humidity chart, mirroring `nano/plot_sensor.py` (query, moving average, dual y-axis) — `ChartController` (core) + `SensorChart.qml` (custom `Canvas`, shared via `KomaroCore`), wired into both desktop and mobile shells with measurement/range/smoothing controls
- [ ] Chart is a hand-rolled `Canvas` (no QtCharts/QtGraphs installed in the Qt kit); revisit if Qt Charts/Graphs gets added to the kit later and a richer chart (zoom/pan, legends) is wanted
- [ ] No axis interaction (zoom/pan/hover tooltips) yet — static redraw on data/resize only

## Mobile / Android

- [x] Set up real Android packaging: `android-arm64` CMake preset in `mobile/CMakePresets.json` (Qt 6.8.3 `android_arm64_v8a` kit, NDK r26b, `QT_HOST_PATH` pointing at `msvc2022_64` for cross-build tooling) builds `komaro_qml_mobile.apk` via `cmake --build build/android-arm64 --target apk`
- [x] Installed and launched on a real device (Lenovo Tab M11, `adb install` + `adb shell am start`) — layout renders correctly, no crash on launch; see `screenshots/android-tablet-sensor-viewer.JPG`
- [ ] Drawer's hamburger icon (`☰`) renders as a missing-glyph box on-device — the Unicode char isn't in whatever font ships with this build; needs an icon font/image instead
- [ ] Haven't yet verified touch interactions (opening the Drawer, Connect dialog, actually querying InfluxDB) on-device — only confirmed the initial "No data" state renders
- [ ] `mobile`'s desktop-look `windows-msvc` preset and the new `android-arm64` preset now diverge further (windeployqt guarded behind `if(NOT ANDROID)`); keep an eye on this if a third platform target is added

## Cleanup

- [ ] `desktop/CMakeLists.txt` and `mobile/CMakeLists.txt` are now near-duplicates (Qt setup, output dirs, `komaro_core`/`komaro_core_qml` linking, windeployqt step) — consider factoring shared bits into a common `.cmake` include if a third shell ever appears
- [ ] `qml/README.md` — mention the mobile prototype once it settles
