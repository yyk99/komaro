# qml TODO

## Data / backend

- [ ] Wire the Connect dialog's host field to `InfluxDbClient` (currently UI-only, doesn't do anything with the entered host)
- [ ] Persist the last-used InfluxDB host across app restarts
- [ ] Add unit/integration coverage for `InfluxDbClient` itself (only `InfluxResponseParser` is tested so far; the network path is unverified)

## Plotting

- [ ] Replace the placeholder plot area with a real temperature/humidity chart, mirroring `nano/plot_sensor.py` (query, moving average, dual y-axis)
- [ ] Decide on a charting approach (QtCharts vs QtGraphs vs custom `Canvas`)
- [ ] Wire the same chart into the mobile shell once it works on desktop

## Mobile / Android

- [ ] `qml/mobile` currently only builds as a desktop app with a mobile-look UI (for quick prototyping); actual Android packaging (NDK toolchain, Qt for Android kit, APK build) isn't set up yet
- [ ] Once Android build is set up, verify touch interactions (Drawer, dialogs) on a real device/emulator

## Cleanup

- [ ] `desktop/CMakeLists.txt` and `mobile/CMakeLists.txt` are now near-duplicates (Qt setup, output dirs, `komaro_core`/`komaro_core_qml` linking, windeployqt step) — consider factoring shared bits into a common `.cmake` include if a third shell ever appears
- [ ] `qml/README.md` — mention the mobile prototype once it settles
