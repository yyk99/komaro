# mobile

A `ToolBar` + `Drawer` (Material Dark style) mobile UI, buildable two ways:
- **Desktop prototype** (`windows-msvc` preset): runs as a regular Windows app in a phone-ish 411x891 window, for quick UI iteration without touching the Android toolchain.
- **Real Android build** (`android-arm64` preset): cross-compiles and packages an actual `.apk`.

It shares `AppActions` (Connect/About/Exit) with `../desktop` via the `KomaroCore` QML module and links `../core`'s InfluxDB query client, same as desktop.

## Build & run (desktop prototype)

Same pattern as `../desktop`:

```
cd qml/mobile
cmake --preset windows-msvc
cmake --build --preset windows-msvc-debug
ctest --preset windows-msvc-debug
```

Executables land in `build/windows-msvc/bin/<Config>/`; `windeployqt` runs automatically as a post-build step.

## Build (Android)

Requires, alongside the Qt 6.8.3 `android_arm64_v8a` kit (`E:\qt6\6.8.3\android_arm64_v8a`):
- Android SDK with `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`, and NDK **r26b** (`ndk;26.1.10909125` — must match `android_arm64_v8a/mkspecs/qdevice.pri`'s `DEFAULT_ANDROID_NDK_ROOT`)
- A JDK 17 (`JAVA_HOME`) for Gradle
- Install the SDK/NDK to a path with **no spaces** (e.g. `C:\Users\<you>\android-sdk`, not `C:\Program Files (x86)\...`) — `sdkmanager.bat` and the Gradle-driven APK packaging step both mis-parse space-containing paths on Windows

```
cd qml/mobile
cmake --preset android-arm64
cmake --build build/android-arm64 --target apk
```

The APK lands at `build/android-arm64/android-build/build/outputs/apk/debug/android-build-debug.apk`. Install to a connected device with `adb install <path>`.

`BUILD_TESTS` is forced `OFF` for this preset — `komaro_core`'s GTest suite is vcpkg/x64-windows only and doesn't cross-compile for Android.

The `windeployqt` post-build step in `CMakeLists.txt` is skipped under `if(NOT ANDROID)`: on Android, `Qt6::qmake` resolves to the *host* Qt kit (needed for cross-build tooling), so without the guard the desktop kit's `windeployqt.exe` would run against the Android `.so` and fail. APK packaging itself is handled by the `apk`/`komaro_qml_mobile_make_apk` targets Qt's CMake integration adds automatically under the Android toolchain.
