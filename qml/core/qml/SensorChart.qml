import QtQuick

// Dual-axis line chart for temperature (left axis, red) and humidity (right
// axis, blue) over time, mirroring nano/plot_sensor.py's matplotlib output.
// `series` is a list of {measurement, points}, where each `points` is a list
// of {time (ms since epoch), temperatureC, humidity} - as produced by
// ChartController.series. Multiple series overlay on the same axes, one
// temperature/humidity line pair each, distinguished by dash pattern
// (mirroring nano/plot_multi_sensor.py's line-style-per-measurement
// approach) since color is already spoken for by temperature-vs-humidity.
Item {
    id: root

    property var series: []
    property bool useFahrenheit: false

    // When enabled, the corresponding axis uses [min, max] verbatim instead
    // of auto-scaling to the data (paddedRange()) - useful for keeping the
    // y-axis stable across refreshes/measurements. Temperature bounds are
    // always in Celsius, matching how `points` stores temperatureC; the
    // caller is responsible for converting from whatever unit its own UI
    // collects the values in.
    property bool fixedTempRangeEnabled: false
    property real fixedTempMinC: 0
    property real fixedTempMaxC: 40
    property bool fixedHumidRangeEnabled: false
    property real fixedHumidMin: 0
    property real fixedHumidMax: 100

    readonly property color temperatureColor: "#e06666"
    readonly property color humidityColor: "#6fa8dc"
    // Cycled by series index so any number of overlaid measurements stays
    // distinguishable; same 4-pattern vocabulary matplotlib's default style
    // cycle uses (solid/dashed/dash-dot/dotted).
    readonly property var dashPatterns: [[], [6, 4], [6, 3, 1, 3], [1, 3]]

    // Horizontal-only margins, shared between onPaint's drawing and the
    // hairline/zoom hit-testing below - both need to agree on the same
    // pixel-x <-> time mapping. marginTop/marginBottom don't affect that
    // mapping, so they stay local to onPaint.
    readonly property int marginLeft: 56
    readonly property int marginRight: 56

    // Hairline (crosshair) inspection tool: tap to toggle on/off; drag (a
    // press followed by movement, on mouse or touch alike) shows/moves it
    // regardless of prior state. See qml/KB.md for why one gesture model
    // serves both mouse and touch here. Position is stored as a time value,
    // not a pixel-x - a pixel position would silently point at a different
    // moment whenever the x axis rescales (e.g. switching the time range),
    // since the same pixel maps to a different time once minTime/timeSpan
    // change. Storing the time instead means the hairline stays pinned to
    // the moment the user picked, and simply redraws at whatever pixel that
    // moment now falls on.
    property bool hairlineActive: false
    property real hairlineTimeMs: 0

    // Zoom: double-click sets one corner of a temporary time window
    // (zoomPending, at zoomPendingTimeMs), a second double-click sets the
    // other corner and activates it (zoomActive, [zoomStartTimeMs,
    // zoomEndTimeMs]) - narrowing the x axis (and, unless a fixed range is
    // set, the y axes too, since only the points falling inside the window
    // are drawn) without re-querying InfluxDB for a smaller time range.
    // Double-click was chosen specifically to not collide with the
    // hairline's single-click toggle/drag above - see qml/KB.md. Exiting
    // zoom is intentionally not another chart gesture: each app's time
    // range control calls resetZoom() when the user picks any of its
    // normal presets, since zoom is conceptually just a temporary
    // override of that same "what time window am I viewing" choice.
    property bool zoomPending: false
    property real zoomPendingTimeMs: 0
    property bool zoomActive: false
    property real zoomStartTimeMs: 0
    property real zoomEndTimeMs: 0

    function nonEmptySeries() {
        return (root.series || []).filter(s => s.points && s.points.length > 0)
    }

    function timeSpanOf(nonEmpty) {
        const allTimes = [].concat(...nonEmpty.map(s => s.points.map(p => p.time)))
        const minTime = Math.min.apply(null, allTimes)
        const maxTime = Math.max.apply(null, allTimes)
        return [minTime, Math.max(1, maxTime - minTime)]
    }

    // [minTime, timeSpan] for whatever's currently driving the x axis - the
    // zoom window if active, otherwise the full data range. Shared by
    // onPaint and the hit-testing functions below so they always agree.
    function effectiveTimeRange() {
        if (zoomActive) {
            const lo = Math.min(zoomStartTimeMs, zoomEndTimeMs)
            const hi = Math.max(zoomStartTimeMs, zoomEndTimeMs)
            return [lo, Math.max(1, hi - lo)]
        }
        const nonEmpty = nonEmptySeries()
        if (nonEmpty.length === 0) {
            return [0, 1]
        }
        return timeSpanOf(nonEmpty)
    }

    // Maps a pixel-x within the plot area to the time (ms since epoch) it
    // corresponds to, using the same effective time range onPaint computes
    // for the x axis. Returns null if there's no data to map against.
    function timeAtPixelX(pixelX) {
        if (nonEmptySeries().length === 0) {
            return null
        }
        const [minTime, timeSpan] = effectiveTimeRange()
        const plotWidth = Math.max(1, width - marginLeft - marginRight)
        const frac = (pixelX - marginLeft) / plotWidth
        return minTime + frac * timeSpan
    }

    // Inverse of timeAtPixelX() - where a given time currently falls on the
    // x axis, for drawing the hairline/zoom markers at their pinned times.
    function pixelXAtTime(timeMs) {
        if (nonEmptySeries().length === 0) {
            return marginLeft
        }
        const [minTime, timeSpan] = effectiveTimeRange()
        const plotWidth = Math.max(1, width - marginLeft - marginRight)
        return marginLeft + ((timeMs - minTime) / timeSpan) * plotWidth
    }

    // For each non-empty series, finds the point nearest `timeMs` - the
    // hairline snaps to real readings rather than interpolating between
    // them, so the status bar always shows values that actually occurred.
    function nearestPointsAtTime(timeMs) {
        const result = []
        for (const s of nonEmptySeries()) {
            let nearest = s.points[0]
            let bestDiff = Math.abs(nearest.time - timeMs)
            for (const p of s.points) {
                const diff = Math.abs(p.time - timeMs)
                if (diff < bestDiff) {
                    bestDiff = diff
                    nearest = p
                }
            }
            result.push({measurement: s.measurement, temperatureC: nearest.temperatureC, humidity: nearest.humidity})
        }
        return result
    }

    // Handles one double-click during zoom-window selection: the first call
    // records the pending corner, the second completes the window (ordering
    // the two times so drag direction doesn't matter) and activates zoom.
    // Also usable to start a *new* zoom window while already zoomed in.
    function handleZoomCornerClick(pixelX) {
        const timeMs = timeAtPixelX(pixelX)
        if (timeMs === null) {
            return
        }
        if (!zoomPending) {
            zoomPendingTimeMs = timeMs
            zoomPending = true
            return
        }
        if (Math.abs(timeMs - zoomPendingTimeMs) < 1) {
            // Second corner landed on the first - too close to be
            // intentional; cancel rather than activate a zero-width zoom.
            zoomPending = false
            return
        }
        zoomStartTimeMs = Math.min(zoomPendingTimeMs, timeMs)
        zoomEndTimeMs = Math.max(zoomPendingTimeMs, timeMs)
        zoomPending = false
        zoomActive = true
    }

    // Called by each app's time-range control when the user picks one of
    // its normal presets - see the zoomActive/zoomPending doc comment above
    // for why exiting zoom isn't a chart gesture.
    function resetZoom() {
        zoomActive = false
        zoomPending = false
    }

    function celsiusToFahrenheit(c) { return c * 9 / 5 + 32 }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    function formatTime(ms) {
        const d = new Date(ms)
        return pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + " " + pad2(d.getHours()) + ":"
                + pad2(d.getMinutes())
    }

    // Ready-to-display status-bar text for the hairline's current position,
    // e.g. "11-14 17:23  —  living_room: 19.5°C, 42%  •  outdoor: 8.0°C, 68%"
    // - formatting lives here (not in each app's Main.qml) so unit
    // conversion isn't duplicated across desktop/mobile.
    readonly property string hairlineStatusText: {
        if (!hairlineActive) {
            return ""
        }
        const values = nearestPointsAtTime(hairlineTimeMs)
        if (values.length === 0) {
            return ""
        }
        const parts = values.map(v => {
            const displayTemp = useFahrenheit ? celsiusToFahrenheit(v.temperatureC) : v.temperatureC
            return v.measurement + ": " + displayTemp.toFixed(1) + (useFahrenheit ? "°F" : "°C") + ", "
                    + v.humidity.toFixed(0) + "%"
        })
        return formatTime(hairlineTimeMs) + "  —  " + parts.join("  •  ")
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        function paddedRange(lo, hi) {
            if (hi - lo < 1e-6) {
                return [lo - 1, hi + 1]
            }
            const margin = (hi - lo) * 0.1
            return [lo - margin, hi + margin]
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const allSeries = root.nonEmptySeries()

            if (allSeries.length === 0) {
                ctx.fillStyle = "#888888"
                ctx.font = "16px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(qsTr("No data"), width / 2, height / 2)
                return
            }

            const marginLeft = root.marginLeft
            const marginRight = root.marginRight
            const marginTop = 28 + 3 * 16
            const marginBottom = 40
            const plotWidth = Math.max(1, width - marginLeft - marginRight)
            const plotHeight = Math.max(1, height - marginTop - marginBottom)

            const [minTime, timeSpan] = root.effectiveTimeRange()
            const maxTime = minTime + timeSpan

            // Only the points actually falling inside the current window
            // (full range, or the zoom window if active) count towards
            // drawing and the y-axis auto-scale - zooming in also rescales
            // temperature/humidity to whatever's visible, not the full
            // dataset's range. A series with nothing in the window is
            // dropped for this paint, same as an empty series normally is.
            const nonEmptySeries = allSeries
                    .map(s => ({measurement: s.measurement,
                                points: s.points.filter(p => p.time >= minTime && p.time <= maxTime)}))
                    .filter(s => s.points.length > 0)

            if (nonEmptySeries.length === 0) {
                ctx.fillStyle = "#888888"
                ctx.font = "16px sans-serif"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(qsTr("No data in this range"), width / 2, height / 2)
                return
            }

            const allTemps = [].concat(...nonEmptySeries.map(s => s.points.map(p => p.temperatureC)))
            const allHumids = [].concat(...nonEmptySeries.map(s => s.points.map(p => p.humidity)))

            const tempRange = root.fixedTempRangeEnabled
                    ? [root.fixedTempMinC, root.fixedTempMaxC]
                    : paddedRange(Math.min.apply(null, allTemps), Math.max.apply(null, allTemps))
            const humidRange = root.fixedHumidRangeEnabled
                    ? [root.fixedHumidMin, root.fixedHumidMax]
                    : paddedRange(Math.min.apply(null, allHumids), Math.max.apply(null, allHumids))

            function xFor(t) { return marginLeft + ((t - minTime) / timeSpan) * plotWidth }
            function yFor(v, range) {
                return marginTop + (1 - (v - range[0]) / (range[1] - range[0])) * plotHeight
            }

            // Gridlines + temperature/humidity axis labels
            const gridLines = 4
            ctx.strokeStyle = "#3a3a3a"
            ctx.lineWidth = 1
            ctx.font = "11px sans-serif"
            ctx.textBaseline = "middle"
            for (let g = 0; g <= gridLines; ++g) {
                const gy = marginTop + (g / gridLines) * plotHeight

                ctx.beginPath()
                ctx.moveTo(marginLeft, gy)
                ctx.lineTo(marginLeft + plotWidth, gy)
                ctx.stroke()

                const tempValue = tempRange[1] - (g / gridLines) * (tempRange[1] - tempRange[0])
                const displayTemp = root.useFahrenheit ? root.celsiusToFahrenheit(tempValue) : tempValue
                ctx.fillStyle = root.temperatureColor
                ctx.textAlign = "right"
                ctx.fillText(displayTemp.toFixed(1) + (root.useFahrenheit ? "F" : "C"), marginLeft - 6, gy)

                const humidValue = humidRange[1] - (g / gridLines) * (humidRange[1] - humidRange[0])
                ctx.fillStyle = root.humidityColor
                ctx.textAlign = "left"
                ctx.fillText(humidValue.toFixed(0) + "%", marginLeft + plotWidth + 6, gy)
            }

            // X axis ticks
            ctx.fillStyle = "#cccccc"
            ctx.textAlign = "center"
            ctx.textBaseline = "top"
            const xTicks = 5
            for (let xt = 0; xt < xTicks; ++xt) {
                const frac = xt / (xTicks - 1)
                const tTime = minTime + frac * timeSpan
                ctx.fillText(root.formatTime(tTime), xFor(tTime), marginTop + plotHeight + 6)
            }

            function drawLine(points, valueKey, range, color, dash) {
                ctx.strokeStyle = color
                ctx.lineWidth = 1.5
                ctx.setLineDash(dash)
                ctx.beginPath()
                for (let i = 0; i < points.length; ++i) {
                    const x = xFor(points[i].time)
                    const y = yFor(points[i][valueKey], range)
                    if (i === 0) {
                        ctx.moveTo(x, y)
                    } else {
                        ctx.lineTo(x, y)
                    }
                }
                ctx.stroke()
                ctx.setLineDash([])
            }

            for (let s = 0; s < nonEmptySeries.length; ++s) {
                const dash = root.dashPatterns[s % root.dashPatterns.length]
                drawLine(nonEmptySeries[s].points, "temperatureC", tempRange, root.temperatureColor, dash)
                drawLine(nonEmptySeries[s].points, "humidity", humidRange, root.humidityColor, dash)
            }

            // Legend: one row, sampling each series' dash pattern so it
            // doubles as a key for "which dash style is which measurement".
            ctx.textAlign = "left"
            ctx.textBaseline = "top"
            ctx.font = "11px sans-serif"
            const legendY = 4
            let lx = marginLeft + 8
            for (let s = 0; s < nonEmptySeries.length; ++s) {
                const dash = root.dashPatterns[s % root.dashPatterns.length]

                ctx.strokeStyle = "#cccccc"
                ctx.lineWidth = 1.5
                ctx.setLineDash(dash)
                ctx.beginPath()
                ctx.moveTo(lx, legendY + 6)
                ctx.lineTo(lx + 24, legendY + 6)
                ctx.stroke()
                ctx.setLineDash([])
                lx += 30

                ctx.fillStyle = "#cccccc"
                const label = nonEmptySeries[s].measurement
                ctx.fillText(label, lx, legendY)
                lx += ctx.measureText(label).width + 20
            }

            // Color key: which color is temperature vs. humidity, same as
            // the axis tick label colors above.
            const colorKeyY = legendY + 16
            ctx.fillStyle = root.temperatureColor
            ctx.fillText(qsTr("Temperature (%1)").arg(root.useFahrenheit ? "F" : "C"), marginLeft + 8, colorKeyY)
            ctx.fillStyle = root.humidityColor
            ctx.fillText(qsTr("Humidity (%)"), marginLeft + 8, colorKeyY + 16)

            // Hairline: a vertical line spanning the plot area, styled the
            // same as the horizontal gridlines above; drawn last so it sits
            // on top of everything else.
            if (root.hairlineActive) {
                const hairlineX = root.pixelXAtTime(root.hairlineTimeMs)
                ctx.strokeStyle = "#3a3a3a"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(hairlineX, marginTop)
                ctx.lineTo(hairlineX, marginTop + plotHeight)
                ctx.stroke()
            }

            // Zoom-pending marker: the first corner the user already
            // placed, waiting for the second double-click. Styled
            // distinctly (yellow, dashed) from both the hairline and the
            // data lines so it doesn't get confused with either.
            if (root.zoomPending) {
                const pendingX = root.pixelXAtTime(root.zoomPendingTimeMs)
                ctx.strokeStyle = "#e0c040"
                ctx.lineWidth = 1
                ctx.setLineDash([2, 3])
                ctx.beginPath()
                ctx.moveTo(pendingX, marginTop)
                ctx.lineTo(pendingX, marginTop + plotHeight)
                ctx.stroke()
                ctx.setLineDash([])
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    MouseArea {
        id: hairlineArea
        anchors.fill: parent

        property real pressX: 0
        property real pressY: 0
        property bool moved: false
        property real pendingTapX: 0

        onPressed: (mouse) => {
            pressX = mouse.x
            pressY = mouse.y
            moved = false
        }
        onPositionChanged: (mouse) => {
            if (!pressed) {
                return
            }
            if (!moved && (Math.abs(mouse.x - pressX) > 5 || Math.abs(mouse.y - pressY) > 5)) {
                moved = true
            }
            if (moved) {
                const timeMs = root.timeAtPixelX(mouse.x)
                if (timeMs !== null) {
                    root.hairlineActive = true
                    root.hairlineTimeMs = timeMs
                }
            }
        }
        onReleased: (mouse) => {
            if (!moved) {
                // Deferred: might be the first half of a double-click (for
                // zoom), which onDoubleClicked below will cancel via
                // singleTapTimer.stop() if a second click follows in time.
                pendingTapX = mouse.x
                singleTapTimer.restart()
            }
            moved = false
        }
        onDoubleClicked: (mouse) => {
            singleTapTimer.stop()
            root.handleZoomCornerClick(mouse.x)
        }

        Timer {
            id: singleTapTimer
            // Matches Qt's own double-click detection window, so a plain
            // tap is confirmed exactly when Qt itself would have given up
            // on waiting for a second click.
            interval: Qt.styleHints.mouseDoubleClickInterval
            onTriggered: {
                root.hairlineActive = !root.hairlineActive
                if (root.hairlineActive) {
                    const timeMs = root.timeAtPixelX(hairlineArea.pendingTapX)
                    if (timeMs !== null) {
                        root.hairlineTimeMs = timeMs
                    } else {
                        root.hairlineActive = false
                    }
                }
            }
        }
    }

    onSeriesChanged: canvas.requestPaint()
    onUseFahrenheitChanged: canvas.requestPaint()
    onFixedTempRangeEnabledChanged: canvas.requestPaint()
    onFixedTempMinCChanged: canvas.requestPaint()
    onFixedTempMaxCChanged: canvas.requestPaint()
    onFixedHumidRangeEnabledChanged: canvas.requestPaint()
    onFixedHumidMinChanged: canvas.requestPaint()
    onFixedHumidMaxChanged: canvas.requestPaint()
    onHairlineActiveChanged: canvas.requestPaint()
    onHairlineTimeMsChanged: canvas.requestPaint()
    onZoomPendingChanged: canvas.requestPaint()
    onZoomPendingTimeMsChanged: canvas.requestPaint()
    onZoomActiveChanged: canvas.requestPaint()
    onZoomStartTimeMsChanged: canvas.requestPaint()
    onZoomEndTimeMsChanged: canvas.requestPaint()
}
