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

### Windows (`android-arm64` preset)

Requires, alongside the Qt 6.8.3 `android_arm64_v8a` kit (`E:\qt6\6.8.3\android_arm64_v8a`):
- Android SDK with `platform-tools`, `build-tools;35.0.0`, `platforms;android-35`, and NDK **r26b** (`ndk;26.1.10909125` — must match `android_arm64_v8a/mkspecs/qdevice.pri`'s `DEFAULT_ANDROID_NDK_ROOT`)
- A JDK 17 (`JAVA_HOME`) for Gradle
- Install the SDK/NDK to a path with **no spaces** (e.g. `C:\Users\<you>\android-sdk`, not `C:\Program Files (x86)\...`) — `sdkmanager.bat` and the Gradle-driven APK packaging step both mis-parse space-containing paths on Windows

```
cd qml/mobile
cmake --preset android-arm64
cmake --build build/android-arm64 --target apk
```

The APK lands at `build/android-arm64/android-build/build/outputs/apk/debug/android-build-debug.apk`.

`BUILD_TESTS` is forced `OFF` for this preset — `komaro_core`'s GTest suite is vcpkg/x64-windows only and doesn't cross-compile for Android.

### Linux (`android-arm64-ubuntu` preset, host kestrel)

No Android Studio needed — the command-line tools are enough since CMake/Gradle drive everything:

1. **SDK command-line tools**: download the Linux "command line tools only" zip from https://developer.android.com/studio/index.html#command-line-tools-only and unpack it so `sdkmanager` ends up at `/home/yyk/android-sdk/cmdline-tools/latest/bin/sdkmanager` (the SDK manager requires exactly this `cmdline-tools/latest/` layout).
2. **Pull the actual packages** (same versions as the Windows setup above):
   ```
   cd /home/yyk/android-sdk/cmdline-tools/latest/bin
   ./sdkmanager --sdk_root=/home/yyk/android-sdk --licenses
   ./sdkmanager --sdk_root=/home/yyk/android-sdk \
     "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;26.1.10909125"
   ```
3. **Qt's `android_arm64_v8a` kit** isn't part of the SDK/NDK download — install it through the Qt Maintenance Tool (the same one that installed the `gcc_64` kit at `/home/yyk/Qt/6.8.1/`), adding the Android arm64-v8a component for 6.8.1.
4. `JAVA_HOME` uses the system OpenJDK (`/usr/lib/jvm/java-21-openjdk-amd64`) — JDK 21, not 17 like the Windows setup; not yet verified against the Android Gradle Plugin version Qt 6.8.1 bundles.

```
cd qml/mobile
cmake --preset android-arm64-ubuntu
cmake --build build/android-arm64-ubuntu --target apk
```

Same `BUILD_TESTS=OFF` caveat as the Windows preset applies.

## Install & run on a real device

**Linux only, one-time setup:** `adb devices` will list the device but show `no permissions` until a udev rule grants USB access. Add one for the device's USB vendor ID (find it via `lsusb` after connecting — e.g. `17ef` for Lenovo):
```
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="17ef", MODE="0666", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/51-android.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```
Then unplug and replug the device (safest way to force re-enumeration under the new rule). This needs your user account in the `plugdev` group (`groups` to check).

1. On the device: Settings → About → tap "Build number" 7 times to unlock Developer options, then Settings → Developer options → enable **USB debugging**.
2. Connect the device via USB. Check the "Charging this device via USB" notification and switch it to **File Transfer (MTP)** or **PTP** — "Charging only" mode doesn't expose the ADB interface, so Windows won't see the device for `adb` even with USB debugging on (confirmed via `Get-PnpDevice`: the device showed up as a phantom/absent MTP entry until the mode was switched).
3. Accept the "Allow USB debugging?" prompt that appears on the device.
4. From `C:\Users\<you>\android-sdk\platform-tools\`:
   ```
   adb devices                    # confirm the device shows up as "device", not "unauthorized"
   adb install -r <path-to-apk>
   adb shell am start -n io.github.yyk99.komaro/org.qtproject.qt.android.bindings.QtActivity
   ```
   (`-r` reinstalls over an existing install, useful when iterating.)

   Or, once `adb devices` shows the device as authorized, skip the manual `adb install`/`am start` invocations and use the CMake targets instead (wrap the same commands, using each preset's `ANDROID_SDK_ROOT`):
   ```
   cmake --build build/<android-preset> --target install-apk   # rebuilds the apk if stale, then installs it
   cmake --build build/<android-preset> --target launch-apk
   ```
5. To sanity-check without touching the device: `adb shell pidof io.github.yyk99.komaro` (confirms it's still running) and `adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png` (grab a screenshot). If running these from Git Bash, prefix with `MSYS_NO_PATHCONV=1` — otherwise it mangles the device-side `/sdcard/...` path into a Windows path.

Verified working on a Lenovo Tab M11 (`TB330FU`) — see `../screenshots/android-tablet-sensor-viewer.JPG`. Touch interaction (Drawer, Connect dialog, live querying) is still unverified on-device — see `../TODO.md`.

The `windeployqt` post-build step in `CMakeLists.txt` is skipped under `if(NOT ANDROID)`: on Android, `Qt6::qmake` resolves to the *host* Qt kit (needed for cross-build tooling), so without the guard the desktop kit's `windeployqt.exe` would run against the Android `.so` and fail. APK packaging itself is handled by the `apk`/`komaro_qml_mobile_make_apk` targets Qt's CMake integration adds automatically under the Android toolchain.
