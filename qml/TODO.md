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

- [ ] `qml/mobile` currently only builds as a desktop app with a mobile-look UI (for quick prototyping); actual Android packaging (NDK toolchain, Qt for Android kit, APK build) isn't set up yet
- [ ] Once Android build is set up, verify touch interactions (Drawer, dialogs) on a real device/emulator

## Cleanup

- [ ] `desktop/CMakeLists.txt` and `mobile/CMakeLists.txt` are now near-duplicates (Qt setup, output dirs, `komaro_core`/`komaro_core_qml` linking, windeployqt step) — consider factoring shared bits into a common `.cmake` include if a third shell ever appears
- [ ] `qml/README.md` — mention the mobile prototype once it settles
