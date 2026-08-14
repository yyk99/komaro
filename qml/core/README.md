# core

Two CMake targets shared by the desktop and mobile apps:

- `komaro_core` — a static C++ library (Qt6 Core + Network) with the InfluxDB querying logic and app state.
  - `InfluxResponseParser` — parses an InfluxDB `/query` JSON response into `SensorPoint` values (time, temperature_c, humidity). Pure/synchronous, no network or event loop involved, so it's unit-tested directly.
  - `InfluxDbClient` — async client (`QNetworkAccessManager`) that issues an InfluxQL `SELECT` query against InfluxDB's HTTP `/query` endpoint and reports results via `succeeded`/`failed` signals, using `InfluxResponseParser` internally.
  - `SensorPoint` — plain struct: `QDateTime time`, `double temperatureC`, `double humidity`.
  - `RecentServers` — pure list-management logic (dedupe, cap, move-to-front) for a most-recently-used server list; unit-tested directly.
  - `MovingAverage` — cumulative windowed mean, matching `nano/plot_sensor.py`'s `moving_average()` (never shrinks the series); unit-tested directly.
  - `ConnectionManager` — QML-facing (via `QQmlContext::setContextProperty`, registered as `connectionManager` in each app's `main.cpp`) wrapper that persists the recent-server list (`QSettings`) and tracks the currently-selected host (`currentHost`), exposing `recentServers` and `currentHost` properties. No longer does any querying itself — see `ChartController`.
  - `ChartController` — QML-facing (`chartController`) wrapper that drives an `InfluxDbClient` query for a given host/measurement/time-range, applies `MovingAverage` smoothing (mirroring `nano/plot_sensor.py`), and exposes the result as `points` (a `QVariantList` of `{time, temperatureC, humidity}`, ready for `SensorChart.qml`) and `status`.
- `komaro_core_qml` — a QML module (URI `KomaroCore`) with UI pieces shared between platform-specific "shells":
  - `AppActions.qml` — a `QtObject` exposing the app's actions (Connect, About, Exit) as `Action` items, so each shell (desktop's `MenuBar`, mobile's `Drawer`/`ToolBar`) can present the same actions in whatever form suits that platform, instead of duplicating the logic. See `../desktop/qml/Main.qml` for how it's consumed.
  - `SensorChart.qml` — a dual-axis (temperature left/red, humidity right/blue) line chart drawn on a plain QtQuick `Canvas`, since the installed Qt kit has neither Qt Charts nor Qt Graphs (see below). Takes a `points` list (as produced by `ChartController.points`) and redraws on data or size changes.

Charting note: the Qt 6.8.3 kit at `E:\qt6\6.8.3\msvc2022_64` only has base/Quick/QuickControls2/etc — no Qt Charts or Qt Graphs component. Rather than requiring a Qt Maintenance Tool install step, `SensorChart.qml` draws the chart itself via `Canvas`'s immediate-mode 2D API. Revisit if one of those modules gets installed later and a richer chart (zoom/pan, hover tooltips) is wanted.

Notes on a couple of non-obvious build quirks (both cost real debugging time, worth knowing if you touch this again):
- `komaro_core_qml` is deliberately a separate target from `komaro_core` — attaching `qt_add_qml_module` to an already-existing library target doesn't reliably propagate the generated plugin into consumers, so the QML module gets its own fresh target instead.
- `ConnectionManager` is exposed via a context property, not `QML_ELEMENT` — a C++ QML-registered type inside `komaro_core_qml` hit further static-plugin-registration gaps (the generated `_init` object library doesn't reliably propagate either) that weren't worth chasing further for a type that only ever needs one instance per app anyway.
- `komaro_core`'s Q_OBJECT headers (`InfluxDbClient.h`, `ConnectionManager.h`, etc.) are listed explicitly in `add_library()`, not just their `.cpp` files — AUTOMOC's transitive-include scanning silently found nothing to moc without that, leaving their signals/metaobject undefined at link time.

## Build & test

Qt 6.8.3 is used via `CMAKE_PREFIX_PATH`; GTest is pulled from vcpkg (`G:\opt\vcpkg`). Using the CMake bundled with Visual Studio 2022 and the `windows-msvc` preset:

```
cd qml/core
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug
```

Tests are gated by the `BUILD_TESTS` cache variable (default `ON`); pass `-DBUILD_TESTS=OFF` to skip them. When `core` is pulled in via `add_subdirectory` from another project (e.g. `desktop`), that project's own `BUILD_TESTS` option controls this instead.
