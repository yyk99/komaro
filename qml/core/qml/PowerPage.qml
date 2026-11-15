import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// "Power" page: INA219 voltage/current/power/shunt as stacked panels for one
// sensor tag, the QML counterpart of ina219_plot.py. Reads the
// "powerController" context property; the shell only supplies the connected
// `host` and calls reload() (on connect, on tab activation, on auto-refresh).
Item {
    id: page

    property string host: ""
    // Smoothing / range come from here, not the Environment page's controls:
    // the two pages are independent.
    readonly property var valueLabels: ({
        voltage: qsTr("Voltage"), current: qsTr("Current"),
        power: qsTr("Power"), shunt: qsTr("Shunt")
    })

    // Same palette as the komaro-digest touchscreen app's power page.
    readonly property var valueColors: ({
        voltage: "#FFD040", current: "#40FF80", power: "#FF8060", shunt: "#60B0FF"
    })

    property var selectedValues: ["voltage", "current", "power"]

    // Mouse interaction, as on the Environment page: tap toggles a vertical
    // hairline (drag moves it) with the values at that time in the status
    // line; double-tap twice sets the two corners of a temporary zoom
    // window. Picking a range preset leaves zoom. State is per page, so one
    // gesture spans every stacked panel.
    property bool hairlineActive: false
    property real hairlineTime: 0
    property bool zoomPending: false
    property real zoomPendingTime: 0
    property bool zoomActive: false
    property real zoomStart: 0
    property real zoomEnd: 0

    // Full x extent of the loaded data.
    readonly property var dataRange: {
        let lo = Infinity, hi = -Infinity
        for (const panel of powerController.panels)
            for (const s of panel.series)
                if (s.points.length > 0) {
                    lo = Math.min(lo, s.points[0].time)
                    hi = Math.max(hi, s.points[s.points.length - 1].time)
                }
        return isFinite(lo) ? [lo, hi] : [0, 1]
    }
    // Shared x range so stacked panels line up (the zoom window if active).
    readonly property var range: zoomActive ? [zoomStart, zoomEnd] : dataRange

    function resetZoom() {
        zoomActive = false
        zoomPending = false
    }

    function timeAtPixelX(x, width) {
        // Panel plot area: 64 px left / 16 px right margin (PanelChart).
        const plotW = Math.max(1, width - 64 - 16)
        const frac = Math.min(1, Math.max(0, (x - 64) / plotW))
        return range[0] + frac * Math.max(1, range[1] - range[0])
    }

    function zoomCorner(x, width) {
        const t = timeAtPixelX(x, width)
        if (!zoomPending) {
            zoomPendingTime = t
            zoomPending = true
            return
        }
        zoomPending = false
        if (Math.abs(t - zoomPendingTime) < 1) return
        zoomStart = Math.min(zoomPendingTime, t)
        zoomEnd = Math.max(zoomPendingTime, t)
        zoomActive = true
    }

    function pad2(n) { return (n < 10 ? "0" : "") + n }

    function formatTime(ms) {
        const d = new Date(ms)
        return pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()) + " "
                + pad2(d.getHours()) + ":" + pad2(d.getMinutes())
    }

    // "11-14 17:23  -  Voltage: 4.12 V  *  Current: ..." - nearest reading
    // to the hairline in each series.
    readonly property string hairlineStatusText: {
        if (!hairlineActive) return ""
        const parts = []
        for (const panel of powerController.panels) {
            for (const s of panel.series) {
                if (s.points.length === 0) continue
                let best = s.points[0]
                for (const p of s.points)
                    if (Math.abs(p.time - hairlineTime) < Math.abs(best.time - hairlineTime))
                        best = p
                const name = panel.series.length > 1 ? panel.title + " " + s.field : panel.title
                parts.push(name + ": " + best.value.toPrecision(4) + (panel.unit ? " " + panel.unit : ""))
            }
        }
        return parts.length > 0 ? formatTime(hairlineTime) + "  \u2014  " + parts.join("  \u2022  ") : ""
    }
    readonly property string zoomStatusText: zoomActive ? qsTr("Zoomed") : ""

    Settings {
        category: "power"
        property alias sensor: sensorCombo.editText
        property alias timeRangeIndex: rangeCombo.currentIndex
        property alias smoothingWindow: windowSpin.value
        property string values: page.selectedValues.join(",")
        Component.onCompleted: {
            if (values.length > 0) page.selectedValues = values.split(",")
        }
    }

    // Consumed charge/energy of the selected sensor over the displayed period
    // (the zoom window if zoomed, else the loaded data's extent), computed by
    // PowerController from the raw samples - same as ina219/ina219_energy.py.
    readonly property bool canIntegral: host.length > 0 && powerController.panels.length > 0

    function showIntegral() {
        if (canIntegral) {
            powerController.computeIntegral(host, sensorCombo.editText, range[0], range[1])
        }
        integralDialog.open()
    }

    function formatDateTime(ms) {
        return Qt.formatDateTime(new Date(ms), "yyyy-MM-dd hh:mm:ss")
    }

    function formatDuration(sec) {
        sec = Math.round(sec)
        return Math.floor(sec / 3600) + "h " + pad2(Math.floor(sec % 3600 / 60)) + "m "
                + pad2(sec % 60) + "s"
    }

    function reload() {
        if (host.length === 0) return
        powerController.loadSensors(host)
        if (sensorCombo.editText.length === 0 && powerController.sensors.length > 0) {
            sensorCombo.editText = powerController.sensors[0]
        }
        if (sensorCombo.editText.length === 0) return
        powerController.load(host, sensorCombo.editText, selectedValues,
                             rangeCombo.currentText, windowSpin.value)
    }

    onHostChanged: reload()

    Connections {
        target: powerController
        function onSensorsChanged() {
            // The editable ComboBox may already have taken the first entry
            // on its own; either way, load once if nothing is shown yet.
            if (sensorCombo.editText.length === 0 && powerController.sensors.length > 0) {
                sensorCombo.editText = powerController.sensors[0]
            }
            if (powerController.panels.length === 0) {
                page.reload()
            }
        }
    }

    Dialog {
        id: integralDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(420, parent ? parent.width - 32 : 420)
        modal: true
        title: qsTr("Power Usage")
        standardButtons: Dialog.Ok

        readonly property var r: powerController.integral
        readonly property bool done: page.canIntegral && r.state === "done"

        ColumnLayout {
            width: parent.width
            spacing: 8

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !page.canIntegral
                text: qsTr("No Power data loaded: connect and pick a sensor first.")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: page.canIntegral && integralDialog.r.state === "loading"
                text: qsTr("Computing...")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: page.canIntegral && integralDialog.r.state === "error"
                text: qsTr("Error: %1").arg(integralDialog.r.error)
            }

            GridLayout {
                visible: integralDialog.done
                columns: 2
                columnSpacing: 16
                rowSpacing: 4

                Label { text: qsTr("Sensor") }
                Label { text: integralDialog.done ? integralDialog.r.sensor : "" }
                Label { text: qsTr("From") }
                Label { text: integralDialog.done ? page.formatDateTime(integralDialog.r.startMs) : "" }
                Label { text: qsTr("To") }
                Label { text: integralDialog.done ? page.formatDateTime(integralDialog.r.endMs) : "" }
                Label { text: qsTr("Samples") }
                Label {
                    text: !integralDialog.done ? "" : qsTr("%1, integrated over %2 (%3%)")
                            .arg(integralDialog.r.samples)
                            .arg(page.formatDuration(integralDialog.r.coveredSec))
                            .arg((100 * integralDialog.r.coveredSec
                                  / Math.max(1, (integralDialog.r.endMs - integralDialog.r.startMs) / 1000)).toFixed(1))
                }
                Label {
                    text: qsTr("Gaps")
                    visible: integralDialog.done && integralDialog.r.gapCount > 0
                }
                Label {
                    visible: integralDialog.done && integralDialog.r.gapCount > 0
                    text: !visible ? "" : qsTr("%1 skipped (%2)").arg(integralDialog.r.gapCount)
                            .arg(page.formatDuration(integralDialog.r.gapSec))
                }
                Label { text: qsTr("Charge"); font.bold: true }
                Label {
                    font.bold: true
                    text: integralDialog.done ? integralDialog.r.mah.toFixed(3) + " mAh" : ""
                }
                Label { text: qsTr("Energy"); font.bold: true }
                Label {
                    font.bold: true
                    text: integralDialog.done ? integralDialog.r.wh.toFixed(5) + " Wh" : ""
                }
                Label { text: qsTr("Average") }
                Label {
                    text: !integralDialog.done || integralDialog.r.coveredSec <= 0 ? ""
                            : (integralDialog.r.mah * 3600 / integralDialog.r.coveredSec).toFixed(2) + " mA, "
                              + (integralDialog.r.wh * 3.6e6 / integralDialog.r.coveredSec).toFixed(2) + " mW"
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flow {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            Label { text: qsTr("Sensor:"); height: sensorCombo.height; verticalAlignment: Text.AlignVCenter }
            ComboBox {
                id: sensorCombo
                width: 160
                editable: true
                model: powerController.sensors
                inputMethodHints: Qt.ImhNoAutoUppercase
                onActivated: page.reload()
                onAccepted: page.reload()
            }
            Repeater {
                model: powerController.valueKeys
                delegate: CheckBox {
                    required property string modelData
                    text: page.valueLabels[modelData]
                    checked: page.selectedValues.indexOf(modelData) !== -1
                    onToggled: {
                        // Keep canonical order (voltage, current, power, shunt).
                        const want = new Set(page.selectedValues)
                        if (checked) want.add(modelData); else want.delete(modelData)
                        page.selectedValues = powerController.valueKeys.filter(k => want.has(k))
                        page.reload()
                    }
                }
            }
            Label { text: qsTr("Range:"); height: rangeCombo.height; verticalAlignment: Text.AlignVCenter }
            ComboBox {
                id: rangeCombo
                model: ["1h", "6h", "12h", "24h", "48h", "7d", "30d", "all"]
                currentIndex: 0
                displayText: page.zoomActive ? qsTr("Zoomed") : currentText
                onActivated: {
                    page.resetZoom()
                    page.reload()
                }
            }
            Label { text: qsTr("Smoothing:"); height: windowSpin.height; verticalAlignment: Text.AlignVCenter }
            SpinBox {
                id: windowSpin
                from: 1
                to: 200
                value: 1
                onValueModified: page.reload()
            }
            Button {
                text: qsTr("Refresh")
                enabled: page.host.length > 0
                onClicked: page.reload()
            }
        }

        Rectangle {
            color: "#1e1e1e"
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                id: panelColumn
                anchors.fill: parent
                anchors.margins: 8
                // Reserve a strip under the last panel's time axis for the
                // status line, so it doesn't overlap the x tick labels.
                anchors.bottomMargin: 8 + 22
                spacing: 0

                Repeater {
                    model: powerController.panels
                    delegate: PanelChart {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: modelData.title
                        color: page.valueColors[modelData.key]
                        unit: modelData.unit
                        series: modelData.series
                        minTime: page.range[0]
                        maxTime: page.range[1]
                        hairlineActive: page.hairlineActive
                        hairlineTime: page.hairlineTime
                        pendingActive: page.zoomPending
                        pendingTime: page.zoomPendingTime
                        showTimeAxis: index === powerController.panels.length - 1
                    }
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: panelColumn
                property real pressX: 0
                property real pressY: 0
                property bool moved: false
                property real tapX: 0

                onPressed: (mouse) => { pressX = mouse.x; pressY = mouse.y; moved = false }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    if (!moved && (Math.abs(mouse.x - pressX) > 5 || Math.abs(mouse.y - pressY) > 5))
                        moved = true
                    if (moved && powerController.panels.length > 0) {
                        page.hairlineActive = true
                        page.hairlineTime = page.timeAtPixelX(mouse.x, width)
                    }
                }
                onReleased: (mouse) => {
                    if (!moved) { tapX = mouse.x; tapTimer.restart() }
                    moved = false
                }
                onDoubleClicked: (mouse) => {
                    tapTimer.stop()
                    if (powerController.panels.length > 0) page.zoomCorner(mouse.x, width)
                }

                Timer {
                    id: tapTimer
                    interval: Qt.styleHints.mouseDoubleClickInterval
                    onTriggered: {
                        if (powerController.panels.length === 0) return
                        page.hairlineActive = !page.hairlineActive
                        if (page.hairlineActive)
                            page.hairlineTime = page.timeAtPixelX(mouseArea.tapX, mouseArea.width)
                    }
                }
            }

            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: page.hairlineStatusText.length > 0 ? page.hairlineStatusText
                        : page.zoomStatusText.length > 0 ? page.zoomStatusText
                        : powerController.status
                color: "white"
                visible: text.length > 0
            }
        }
    }
}
