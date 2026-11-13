import QtQuick

// One single-axis line panel: `series` is a list of {field, points:[{time,
// value}]} (a PowerController panel's "series"). Several panels stacked in
// PowerPage share minTime/maxTime so their x axes line up. Deliberately
// simpler than SensorChart: it is the stacked-panel counterpart of
// ina219_plot.py's subplots. Hairline / zoom-corner markers are drawn from
// times the page owns (PowerPage handles the mouse, since one gesture spans
// every panel).
Item {
    id: root

    property string title: ""
    property string unit: ""
    property var series: []
    property real minTime: 0
    property real maxTime: 1
    property bool showTimeAxis: true
    property bool hairlineActive: false
    property real hairlineTime: 0
    property bool pendingActive: false
    property real pendingTime: 0

    // Main line color; a second line in the same panel (e.g. load_v next to
    // bus_v) is drawn in a darker shade of it.
    property color color: "#e06666"
    readonly property var lineColors: [color, Qt.darker(color, 1.6)]
    readonly property int marginLeft: 64
    readonly property int marginRight: 16

    onSeriesChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onMinTimeChanged: canvas.requestPaint()
    onMaxTimeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
    onHairlineActiveChanged: canvas.requestPaint()
    onHairlineTimeChanged: canvas.requestPaint()
    onPendingActiveChanged: canvas.requestPaint()
    onPendingTimeChanged: canvas.requestPaint()

    // Round the axis outwards to multiples of a "nice" step (1, 2, 2.5 or 5
    // times a power of ten), aiming for about 4-5 intervals. Because the
    // limits are multiples of the step, zero is a tick whenever it is in range.
    function niceAxis(lo, hi) {
        const raw = (hi - lo) / 4
        const mag = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10))
        let step = 10 * mag
        for (const m of [1, 2, 2.5, 5]) {
            if (raw <= m * mag + 1e-12) { step = m * mag; break }
        }
        let decimals = 0
        while (decimals < 8 && Math.abs(step * Math.pow(10, decimals)
                - Math.round(step * Math.pow(10, decimals))) > 1e-9) decimals++
        return {
            lo: Math.floor(lo / step + 1e-9) * step,
            hi: Math.ceil(hi / step - 1e-9) * step,
            step: step,
            decimals: decimals
        }
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const top = 24
            const bottom = root.showTimeAxis ? 28 : 6
            const plotW = Math.max(1, width - root.marginLeft - root.marginRight)
            const plotH = Math.max(1, height - top - bottom)

            ctx.fillStyle = "#dddddd"
            ctx.font = "13px sans-serif"
            ctx.textAlign = "left"
            ctx.textBaseline = "top"
            ctx.fillText(root.title + (root.unit ? " (" + root.unit + ")" : ""), root.marginLeft, 4)

            let lo = Infinity, hi = -Infinity
            for (const s of root.series) {
                for (const p of s.points) {
                    if (p.time < root.minTime || p.time > root.maxTime) continue
                    lo = Math.min(lo, p.value)
                    hi = Math.max(hi, p.value)
                }
            }
            if (!isFinite(lo)) {
                ctx.fillStyle = "#888888"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.fillText(qsTr("No data"), width / 2, top + plotH / 2)
                return
            }
            if (hi - lo < 1e-9) { lo -= 1; hi += 1 }
            // Include zero when the data is a sizeable fraction of the way to it
            // (current/power sit near 0; voltage near 4 V would just flatten).
            if (lo > 0 && lo <= hi * 0.5) lo = 0
            else if (hi < 0 && hi >= lo * 0.5) hi = 0
            const axis = root.niceAxis(lo, hi)
            lo = axis.lo
            hi = axis.hi

            const span = Math.max(1, root.maxTime - root.minTime)
            const xFor = t => root.marginLeft + (t - root.minTime) / span * plotW
            const yFor = v => top + (1 - (v - lo) / (hi - lo)) * plotH

            // grid + y labels, one per round step (0.25, 0.5, 0.75 ...)
            ctx.strokeStyle = "#3a3a3a"
            ctx.lineWidth = 1
            ctx.fillStyle = "#aaaaaa"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            const n = Math.round((hi - lo) / axis.step)
            for (let i = 0; i <= n; ++i) {
                const v = axis.step * Math.round(lo / axis.step + i)
                const y = Math.round(yFor(v)) + 0.5
                ctx.beginPath()
                ctx.moveTo(root.marginLeft, y)
                ctx.lineTo(root.marginLeft + plotW, y)
                ctx.stroke()
                ctx.fillText(Math.abs(v) < axis.step * 1e-6 ? "0" : v.toFixed(axis.decimals),
                             root.marginLeft - 6, y)
            }

            // x labels
            if (root.showTimeAxis) {
                ctx.textAlign = "center"
                ctx.textBaseline = "top"
                const multiDay = span > 36 * 3600 * 1000
                for (let i = 0; i <= 5; ++i) {
                    const t = root.minTime + span * i / 5
                    const d = new Date(t)
                    const label = (multiDay ? (d.getMonth() + 1) + "/" + d.getDate() + " " : "")
                            + root.pad2(d.getHours()) + ":" + root.pad2(d.getMinutes())
                    ctx.fillText(label, xFor(t), top + plotH + 6)
                }
            }

            // lines
            ctx.save()
            ctx.beginPath()
            ctx.rect(root.marginLeft, top, plotW, plotH)
            ctx.clip()
            ctx.lineWidth = 1.5
            root.series.forEach((s, idx) => {
                ctx.strokeStyle = root.lineColors[idx % root.lineColors.length]
                ctx.beginPath()
                let started = false
                for (const p of s.points) {
                    const x = xFor(p.time), y = yFor(p.value)
                    if (!started) { ctx.moveTo(x, y); started = true } else ctx.lineTo(x, y)
                }
                ctx.stroke()
            })
            ctx.restore()

            // Hairline (same grey as the grid) and the yellow dashed first
            // zoom corner, as on the Environment page.
            if (root.hairlineActive) {
                const x = xFor(root.hairlineTime)
                ctx.strokeStyle = "#6a6a6a"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(x, top)
                ctx.lineTo(x, top + plotH)
                ctx.stroke()
            }
            if (root.pendingActive) {
                const x = xFor(root.pendingTime)
                ctx.strokeStyle = "#e0c040"
                ctx.lineWidth = 1
                ctx.setLineDash([2, 3])
                ctx.beginPath()
                ctx.moveTo(x, top)
                ctx.lineTo(x, top + plotH)
                ctx.stroke()
                ctx.setLineDash([])
            }

            // legend, only when a panel has more than one line
            if (root.series.length > 1) {
                ctx.textAlign = "right"
                ctx.textBaseline = "top"
                let x = root.marginLeft + plotW
                for (let i = root.series.length - 1; i >= 0; --i) {
                    const name = root.series[i].field
                    ctx.fillStyle = root.lineColors[i % root.lineColors.length]
                    ctx.fillText(name, x, 4)
                    x -= ctx.measureText(name).width + 14
                }
            }
        }
    }
}
