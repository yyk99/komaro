# mobile

For now, this is a desktop-buildable app with a mobile-style UI — a `ToolBar` + `Drawer` (Material Dark style, phone-ish 411x891 window) instead of desktop's `MenuBar`, built for quick UI prototyping without needing an Android toolchain. It shares `AppActions` (Connect/About/Exit) with `../desktop` via the `KomaroCore` QML module and links `../core`'s InfluxDB query client, same as desktop.

Actual Android packaging (NDK toolchain, Qt for Android kit, APK build) isn't set up yet — see `../TODO.md`.

## Build & run

Same pattern as `../desktop`:

```
cd qml/mobile
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug
```

Executables land in `build/windows-msvc/bin/<Config>/`; `windeployqt` runs automatically as a post-build step.
