# core

Two CMake targets shared by the desktop and mobile apps:

- `komaro_core` — a static C++ library (Qt6 Core + Network) with the InfluxDB querying logic.
  - `InfluxResponseParser` — parses an InfluxDB `/query` JSON response into `SensorPoint` values (time, temperature_c, humidity). Pure/synchronous, no network or event loop involved, so it's unit-tested directly.
  - `InfluxDbClient` — async client (`QNetworkAccessManager`) that issues an InfluxQL `SELECT` query against InfluxDB's HTTP `/query` endpoint and reports results via `succeeded`/`failed` signals, using `InfluxResponseParser` internally.
  - `SensorPoint` — plain struct: `QDateTime time`, `double temperatureC`, `double humidity`.
- `komaro_core_qml` — a QML module (URI `KomaroCore`) with UI pieces shared between platform-specific "shells". Currently just `AppActions.qml`: a `QtObject` exposing the app's actions (Connect, About, Exit) as `Action` items, so each shell (desktop's `MenuBar`, a future mobile `Drawer`/`ToolBar`) can present the same actions in whatever form suits that platform, instead of duplicating the logic. See `../desktop/qml/Main.qml` for how it's consumed.

Not yet wired into the desktop UI/plot area (InfluxDB querying, that is — `AppActions` is already used by desktop's menu bar).

Note: `komaro_core_qml` is deliberately a separate target from `komaro_core` — attaching `qt_add_qml_module` to an already-existing library target doesn't reliably propagate the generated plugin into consumers, so the QML module gets its own fresh target instead.

## Build & test

Qt 6.8.3 is used via `CMAKE_PREFIX_PATH`; GTest is pulled from vcpkg (`G:\opt\vcpkg`). Using the CMake bundled with Visual Studio 2022 and the `windows-msvc` preset:

```
cd qml/core
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug
```

Tests are gated by the `BUILD_TESTS` cache variable (default `ON`); pass `-DBUILD_TESTS=OFF` to skip them. When `core` is pulled in via `add_subdirectory` from another project (e.g. `desktop`), that project's own `BUILD_TESTS` option controls this instead.
