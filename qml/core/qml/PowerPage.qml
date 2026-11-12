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

    property var selectedValues: ["voltage", "current", "power"]

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
                onActivated: page.reload()
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

            // Shared x range so stacked panels line up.
            readonly property var range: {
                let lo = Infinity, hi = -Infinity
                for (const panel of powerController.panels)
                    for (const s of panel.series)
                        if (s.points.length > 0) {
                            lo = Math.min(lo, s.points[0].time)
                            hi = Math.max(hi, s.points[s.points.length - 1].time)
                        }
                return isFinite(lo) ? [lo, hi] : [0, 1]
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 0

                Repeater {
                    model: powerController.panels
                    delegate: PanelChart {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        title: modelData.title
                        unit: modelData.unit
                        series: modelData.series
                        minTime: parent.parent.range[0]
                        maxTime: parent.parent.range[1]
                        showTimeAxis: index === powerController.panels.length - 1
                    }
                }
            }

            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: powerController.status
                color: "white"
                visible: text.length > 0
            }
        }
    }
}
