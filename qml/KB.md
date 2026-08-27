# qml Knowledge Base

Notes on QML/Qt topics for this project that don't belong in `README.md` (which covers what the app *is*, not how to work on it).

## Why `desktop`'s Linux install needs a wrapper script (RPATH doesn't reach dlopen'd QML plugins)

`desktop/CMakeLists.txt`'s install step deploys a self-contained Qt runtime via `qt_generate_deploy_app_script`/`qt6_deploy_runtime_dependencies`, which sets the installed executable's RPATH to `$ORIGIN:$ORIGIN/../lib` so it finds its bundled Qt libraries instead of any system Qt. That's enough for the executable's own *direct* dependencies (`libQt6Core.so`, etc.) - but not for the QML modules it imports (`QtQuick`, `QtQuick.Controls`, ...), which get pulled in as separate `.so` plugin files that `QQmlEngine` loads via `dlopen()` at runtime, not linked into the executable at build time.

**The gap this causes:** an RPATH/RUNPATH set on the main executable only governs resolution of *that binary's own* `DT_NEEDED` entries - it is not inherited by a library the process later `dlopen()`s, so that library's *own* transitive dependencies fall back to the system's normal search path. On this Ubuntu dev box that's a real collision, not a hypothetical one: Ubuntu ships its own `libQt6QuickTemplates2.so.6` system package, a different (ABI-incompatible) build than ours. Installing to a plain `~/.local` and running the binary directly loaded `QtQuick.Controls`'s plugin fine, but *that plugin's* dependency on `libQt6QuickTemplates2.so.6` resolved to the system copy instead of the bundled one, crashing with an undefined-symbol error the first time a `Control` was instantiated - a failure mode that only shows up once you actually exercise a QML type from the affected module, not at plain startup.

`LD_LIBRARY_PATH`, unlike RPATH/RUNPATH, applies to *every* `dlopen()` in the process, so it's the fix that actually reaches the QML plugins' own dependencies. Rather than requiring the user to set it themselves, the install step installs the real binary to `libexec/komaro_qml_desktop` and puts a thin `bin/komaro_qml_desktop` wrapper script in its place that sets `LD_LIBRARY_PATH` relative to itself before `exec`ing the real one - a standard pattern for self-contained Linux app installs.

**Related gap, same root cause:** `qt6_deploy_runtime_dependencies` (which copies shared-library dependencies) only scans the *executable's* dependency graph - it doesn't know about QML plugins deployed by a separate `qt6_deploy_qml_imports` call, since those plugin files don't exist on disk yet when the first scan runs. Fixed by capturing `qt6_deploy_qml_imports`'s `PLUGINS_FOUND` output and feeding it back into a second `qt6_deploy_runtime_dependencies` call's `ADDITIONAL_MODULES` argument, so the plugins' own dependencies (like the `QuickTemplates2` example above) get scanned and copied too - see the `install(CODE ...)` block in `desktop/CMakeLists.txt`.

**How this was caught:** by actually installing to a scratch prefix and running the result (`env -i HOME=<scratch> QT_QPA_PLATFORM=offscreen <installed-binary>`) rather than trusting a clean `cmake --install` log - the missing-QML-imports gap surfaced as `module ... is not installed`, and the missing-transitive-dependency gap only surfaced one layer deeper, as an undefined-symbol crash, once the first was fixed.

## Visually verifying a QML component without running the full app

Useful when a change touches rendering (e.g. a `Canvas`-based chart) and you want to confirm actual pixels, not just that the code compiles.

**Problem:** `komaro_qml_desktop`/`komaro_qml_mobile` need a live InfluxDB connection to populate the chart with real data. Waiting on that (or mocking the whole app) is overkill for checking a label or a layout tweak.

**Technique:**

1. **Isolate the component if it has no C++ dependency.** `core/qml/SensorChart.qml` only does `import QtQuick` — no dependency on `ChartController`/`InfluxDbClient` or any C++-registered QML type. That means it can be loaded standalone, outside the app, by pointing an `import` at its directory via a `file:` URL (plain absolute paths aren't valid QML import URLs):
   ```qml
   import "file:/home/yyk/src/komaro/qml/core/qml"
   ```

2. **Write a tiny harness QML file, not a unit test.** Feed the component's public property directly with hardcoded sample data — the same interface `ChartController.points` would populate at runtime:
   ```qml
   import QtQuick
   import QtQuick.Window
   import "file:/home/yyk/src/komaro/qml/core/qml"

   Window {
       width: 900; height: 500; visible: true
       SensorChart {
           id: content
           anchors.fill: parent
           points: [ {time: 1700000000000, temperatureC: -5.0, humidity: 40}, /* ... */ ]
       }
       Timer {
           interval: 700; running: true
           onTriggered: content.grabToImage(result => {
               result.saveToFile("/tmp/chart_screenshot.png")
               Qt.quit()
           })
       }
   }
   ```

3. **Run it headless with `qml` + `xvfb-run`.** `qml` is Qt's QML runtime tool (`qtbase/bin/qml`, ships alongside `qmlscene`/`qmllint`/`qmlformat`) — it loads and executes a `.qml` file directly, no compiled C++ host app needed. `xvfb-run` supplies a virtual X display in a headless environment; Qt Quick still does real rendering into that virtual framebuffer, so the output is genuine paint output, not a mock:
   ```bash
   export LD_LIBRARY_PATH=/path/to/qtbase/lib:$LD_LIBRARY_PATH
   xvfb-run -a /path/to/qtbase/bin/qml chart_harness.qml
   ```

4. **Capture pixels, not logs.** `Item.grabToImage()` renders the item's actual `Canvas` output to a `QQuickItemGrabResult` and writes a PNG. Give `Canvas.onPaint` time to run before grabbing (a short `Timer` delay) — grabbing on the same tick the window becomes visible risks capturing a blank frame.

5. **Inspect the PNG directly.** Read the screenshot back and check it visually — label text, layout, clipping, overlap — the way a human reviewer would, rather than trusting that "no errors were logged" means it looks right.

6. **Spot-check one computed value numerically.** Visual inspection catches gross bugs; picking one data point and manually recomputing the expected value (e.g. a Celsius→Fahrenheit conversion from the *unrounded* source number) catches subtler bugs like rounding artifacts or off-by-one errors that look fine at a glance.

**Why this over alternatives:**
- A GTest/unit test calling the paint function in isolation never actually renders anything — it can't catch a layout/clipping bug.
- Running the full app requires a reachable InfluxDB server just to get non-empty `points`, which is unrelated to what's being verified.
- This works for *any* QML file with no C++ type dependencies — swap the hardcoded `points` for whatever properties the component under test exposes.

**Caveats:**
- Only works standalone for QML files that don't reference C++-registered types (`QML_ELEMENT` classes, context properties like `connectionManager`/`chartController`). Components that do need those would require either registering stub types in the harness or running through the real app.
- The `qml` runtime tool must come from the *same* Qt build used to compile the app (mixing a system Qt's `qml` binary with a self-built Qt's plugins will fail to load or behave inconsistently) — set `LD_LIBRARY_PATH` accordingly.

## Android build: how the toolchain pieces fit together

`mobile/README.md` has the quick-reference command sequence. This is the *why* behind it — worth knowing before touching `mobile/CMakePresets.json`'s `android-arm64` preset or debugging a build failure, since an Android build here is really four independent toolchains chained together, each with its own job.

**The pieces and their roles:**

- **Qt's Android kit** (`E:\qt6\6.8.3\android_arm64_v8a`) — Qt's own libraries (`Qt6Core`, `Qt6Quick`, ...) precompiled *for* Android/arm64, plus the CMake glue (`lib/cmake/Qt6/qt.toolchain.cmake`) that turns a normal `qt_add_executable()` project into a cross-compiling one. This is what `CMAKE_PREFIX_PATH` and `CMAKE_TOOLCHAIN_FILE` point at in the preset.
- **The NDK** (r26b, `ANDROID_NDK_ROOT`) — the actual C++ cross-compiler (`clang++` targeting `aarch64-none-linux-android28`) and Android's C/C++ system headers/libs (`libc`, `EGL`, `GLESv2`, ...). Qt's toolchain file doesn't compile anything itself; it *chainloads* the NDK's own `build/cmake/android.toolchain.cmake`, which is what actually sets up the compiler.
- **`QT_HOST_PATH`** (pointing at `msvc2022_64`) — Qt's build-time code generators (`moc`, `rcc`, `qmlcachegen`, the QML type registrar) are ordinary Windows x64 tools; they process source *at build time* on the host, they don't run on the Android device. Cross-compiling Qt needs a *native* Qt install to supply these, separate from the *target* Qt libraries the app links against. Without `QT_HOST_PATH`, CMake can't find them and configure fails.
- **The Android SDK** (`platform-tools`, `build-tools;35.0.0`, `platforms;android-35`) — not needed to compile C++ at all. It's Google's *packaging* toolchain: `aapt2` compiles resources/manifest into the APK's binary XML, `d8`/`dexer` and friends turn any Java/Kotlin bytecode (from Qt's small Android Java shim + AndroidX support libraries) into `classes.dex`, `apksigner` signs the result, and `adb` (in `platform-tools`) is the device-communication protocol used to install/launch/debug on a real device.
- **Gradle + a JDK** — Qt's CMake integration doesn't invoke `aapt2`/`d8` directly; it generates a small Gradle project (`androiddeployqt`'s output, in `build/android-arm64/android-build/`) and lets the **Android Gradle Plugin** (a normal Gradle build, downloaded on first run) drive the actual packaging. Gradle itself needs a JDK to run (not to compile our C++ — that's already done by this point).
- **`androiddeployqt`** (ships in the *host* Qt kit's `bin/`, i.e. `msvc2022_64\bin\androiddeployqt.exe`, not the Android kit's) — the glue script that reads a `<target>-deployment-settings.json` CMake generates, copies the cross-compiled `.so` and Qt's own Android runtime Java classes into the Gradle project skeleton, and invokes Gradle. This is what `cmake --build build/android-arm64 --target apk` ultimately runs (see the `${target}_make_apk` custom target Qt's CMake macros add).

**Build-time flow:** `cmake --preset android-arm64` configures using the NDK's `clang++` (via Qt's chainloaded toolchain file) → `cmake --build --target apk` compiles `komaro_core`/`komaro_core_qml`/`komaro_qml_mobile` into a single `libkomaro_qml_mobile_arm64-v8a.so` → `androiddeployqt` (host Qt tool) assembles the Gradle project skeleton around it → Gradle (JDK-driven) resolves AndroidX dependencies, dexes, packages, and signs → `android-build-debug.apk` lands in `build/android-arm64/android-build/build/outputs/apk/debug/`.

**Gotchas, and the mechanism behind each:**

- **Space-containing install paths silently break everything.** `sdkmanager.bat` (and Gradle's own bootstrapping) build a Java command line internally without quoting `%JAVA_HOME%`/`%~dp0` consistently on Windows; a path like `C:\Program Files (x86)\Android\android-sdk` gets split at the space and Java fails with `Error: Could not find or load main class Files`. This isn't a permissions issue (though `Program Files (x86)` *also* blocks non-elevated writes, a second independent reason to avoid it) — it reproduces even for a JDK under `C:\Program Files\...`. Fix: install the SDK/NDK and JDK (or junction them) to a path with no spaces anywhere in it, e.g. `C:\Users\<you>\android-sdk`.
- **`androiddeployqt` picks whatever's the highest *installed* SDK platform, not what AndroidX needs.** It doesn't consult Gradle/AndroidX at all when choosing `compileSdkVersion` — it just uses the newest `platforms;android-N` present in `ANDROID_SDK_ROOT`. If that's too old, the *Gradle* step fails later, deep into `:checkDebugAarMetadata`, with "Dependency 'androidx.core:core:1.13.1' requires ... compile against version 34 or later" — a completely different tool than the one that picked the platform in the first place, which makes the error confusing to trace back. Qt 6.8.3's bundled AndroidX libraries need `platforms;android-35` (as of this Qt version); install it even though the NDK's own `ANDROID_PLATFORM` default (`android-28`, in `qdevice.pri`) is much lower — that one controls the *NDK* API level (what device OS versions the native code can run on), a separate knob from Gradle's *compileSdk*.
- **`Qt6::qmake` is the host kit's qmake when cross-compiling**, not the Android kit's (Android's kit doesn't ship a usable one for this purpose). `mobile/CMakeLists.txt`'s `windeployqt` post-build step derives its search path from `Qt6::qmake`'s location, so without an `if(NOT ANDROID)` guard it happily finds and runs the *desktop* `windeployqt.exe` against the Android `.so` — which fails confusingly (`DOS header check failed`, because it's trying to parse an ELF binary as if it were a PE/DLL).
- **A connected device won't show up in `adb devices` if its USB mode is "Charging only"**, even with USB debugging enabled in Developer options — the ADB interface is only exposed as part of the MTP/PTP composite USB configuration, not the bare charging one. Confirmed on a Lenovo Tab M11 via `Get-PnpDevice`: with USB debugging on but the device in charging-only mode, Windows registered it as a `CM_PROB_PHANTOM` (present: false) WPD/MTP entry — it *looked* like a driver problem but was actually just the wrong USB mode. Switching the device to File Transfer fixed it immediately.

## CI: how the qml/core GitHub Actions workflow runs, and whether it needs a container

`.github/workflows/qml-core-ci.yml` builds and tests `qml/core` standalone (not through any of the `CMakeUserPresets.json` machine-specific presets - those hardcode paths like `/home/yyk/Qt/...` that don't exist on a GitHub-hosted runner) on every push/PR that touches `qml/core/**`.

**Mechanics:** each run gets a brand-new, disposable Ubuntu VM from GitHub (not a container you configure) - `actions/checkout` clones the repo into it, `jurplel/install-qt-action` downloads and unpacks Qt 6.8.1, `apt-get install libgtest-dev` adds GTest, then plain `cmake`/`ctest` commands configure/build/test `qml/core` directly (`cmake -S qml/core -B build -DBUILD_TESTS=ON`). When the job ends, the whole VM is destroyed - nothing persists between runs unless you opt into `actions/cache` or `actions/upload-artifact`.

**No, you don't need to build an isolated container yourself** - that VM-per-run model *is* the isolation; it's the whole point of GitHub-hosted runners (`runs-on: ubuntu-latest`) versus self-hosting. A `container:` key on the job (running steps inside a specific Docker image) is only worth reaching for if you need an exact pinned toolchain instead of whatever `ubuntu-latest` + apt gives you that day - not needed here. Self-hosted runners (pointing a workflow at your own kestrel box or the Pi instead of GitHub's VMs) are the one case where isolation *becomes* your responsibility, since then it's your persistent hardware being reused run after run - this workflow doesn't do that.

**Public-repo security note:** since `komaro` is public, anyone can open a PR and trigger this workflow against their branch. The `pull_request` trigger (as opposed to the riskier `pull_request_target`) already runs with a read-only `GITHUB_TOKEN` and no access to repo secrets when triggered from a fork, so an untrusted PR can waste CI minutes or fail loudly but can't exfiltrate secrets or push back to the repo. Moot for now anyway, since this workflow doesn't use any secrets. GitHub Actions minutes themselves are unlimited/free for public repos regardless.
