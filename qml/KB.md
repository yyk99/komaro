# qml Knowledge Base

Notes on QML/Qt topics for this project that don't belong in `README.md` (which covers what the app *is*, not how to work on it).

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
