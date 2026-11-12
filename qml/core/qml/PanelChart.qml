import QtQuick

// One single-axis line panel: `series` is a list of {field, points:[{time,
// value}]} (a PowerController panel's "series"). Several panels stacked in
// PowerPage share minTime/maxTime so their x axes line up. Deliberately
// simpler than SensorChart (no zoom/hairline): it is the stacked-panel
// counterpart of ina219_plot.py's subplots.
Item {
    id: root

    property string title: ""
    property string unit: ""
    property var series: []
    property real minTime: 0
    property real maxTime: 1
    property bool showTimeAxis: true

    readonly property var lineColors: ["#e06666", "#6fa8dc", "#93c47d", "#f6b26b"]
    readonly property int marginLeft: 64
    readonly property int marginRight: 16

    onSeriesChanged: canvas.requestPaint()
    onMinTimeChanged: canvas.requestPaint()
    onMaxTimeChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

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
            const pad = (hi - lo) * 0.08
            lo -= pad
            hi += pad

            const span = Math.max(1, root.maxTime - root.minTime)
            const xFor = t => root.marginLeft + (t - root.minTime) / span * plotW
            const yFor = v => top + (1 - (v - lo) / (hi - lo)) * plotH

            // grid + y labels
            ctx.strokeStyle = "#3a3a3a"
            ctx.lineWidth = 1
            ctx.fillStyle = "#aaaaaa"
            ctx.textAlign = "right"
            ctx.textBaseline = "middle"
            for (let i = 0; i <= 4; ++i) {
                const v = lo + (hi - lo) * i / 4
                const y = Math.round(yFor(v)) + 0.5
                ctx.beginPath()
                ctx.moveTo(root.marginLeft, y)
                ctx.lineTo(root.marginLeft + plotW, y)
                ctx.stroke()
                ctx.fillText(v.toPrecision(4), root.marginLeft - 6, y)
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
