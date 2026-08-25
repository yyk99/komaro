import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import KomaroCore

ApplicationWindow {
    id: window
    width: 1024
    height: 768
    visible: true
    title: qsTr("Komaro Sensor Viewer")

    AppActions {
        id: appActions
        onConnectRequested: connectDialog.open()
        onAboutRequested: aboutDialog.open()
        onSettingsRequested: settingsDialog.open()
    }

    // Fixed temperature range bounds, always stored in Celsius (matching
    // SensorChart.points' temperatureC) regardless of the °C/°F toggle -
    // the Settings dialog's spin boxes convert to/from whatever unit is
    // currently displayed.
    property real fixedTempMinC: 0
    property real fixedTempMaxC: 40

    Settings {
        category: "chart"
        property alias timeRangeIndex: timeRangeCombo.currentIndex
        property alias useFahrenheit: unitsSwitch.checked
        property alias smoothingWindow: windowSpin.value
        property alias fixedTempRangeEnabled: fixedTempRangeSwitch.checked
        property alias fixedTempMinC: window.fixedTempMinC
        property alias fixedTempMaxC: window.fixedTempMaxC
        property alias fixedHumidRangeEnabled: fixedHumidRangeSwitch.checked
        property alias fixedHumidMin: humidMinSpin.value
        property alias fixedHumidMax: humidMaxSpin.value
    }

    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")
            MenuItem { action: appActions.connectAction }
            MenuItem { action: appActions.settingsAction }
            MenuSeparator {}
            MenuItem { action: appActions.exitAction }
        }
        Menu {
            title: qsTr("&Help")
            MenuItem { action: appActions.aboutAction }
        }
    }

    function reloadChart() {
        if (connectionManager.currentHost.length > 0) {
            chartController.load(connectionManager.currentHost, measurementCombo.editText,
                                  timeRangeCombo.currentText, windowSpin.value)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            Label { text: qsTr("Measurement:") }
            ComboBox {
                id: measurementCombo
                Layout.preferredWidth: 140
                editable: true
                inputMethodHints: Qt.ImhNoAutoUppercase
                model: chartController.recentMeasurements
                onAccepted: reloadChart()
                onActivated: reloadChart()
                Component.onCompleted: {
                    editText = chartController.recentMeasurements.length > 0
                            ? chartController.recentMeasurements[0] : "sensor"
                }
            }
            Label { text: qsTr("Range:") }
            ComboBox {
                id: timeRangeCombo
                model: ["1h", "6h", "24h", "48h", "7d", "30d", "all"]
                currentIndex: 4
                onActivated: reloadChart()
            }
            Label { text: qsTr("Smoothing:") }
            SpinBox {
                id: windowSpin
                from: 1
                to: 200
                value: 10
                onValueModified: reloadChart()
            }
            Label { text: qsTr("Units:") }
            Switch {
                id: unitsSwitch
                text: checked ? qsTr("°F") : qsTr("°C")
            }
            Button {
                text: qsTr("Refresh")
                enabled: connectionManager.currentHost.length > 0
                onClicked: reloadChart()
            }
            Item { Layout.fillWidth: true }
        }

        Rectangle {
            id: plotArea
            color: "#1e1e1e"
            Layout.fillWidth: true
            Layout.fillHeight: true

            SensorChart {
                anchors.fill: parent
                anchors.margins: 8
                points: chartController.points
                useFahrenheit: unitsSwitch.checked
                fixedTempRangeEnabled: fixedTempRangeSwitch.checked
                fixedTempMinC: window.fixedTempMinC
                fixedTempMaxC: window.fixedTempMaxC
                fixedHumidRangeEnabled: fixedHumidRangeSwitch.checked
                fixedHumidMin: humidMinSpin.value
                fixedHumidMax: humidMaxSpin.value
            }

            Label {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 8
                text: chartController.status
                color: "white"
                visible: text.length > 0
            }
        }
    }

    Dialog {
        id: aboutDialog
        title: qsTr("About")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok

        ColumnLayout {
            spacing: 4

            Label { text: qsTr("Komaro Sensor Viewer") }
            Label { text: qsTr("Desktop QML app") }
            Label { text: qsTr("Built: %1").arg(appBuildTimestamp) }
        }
    }

    Dialog {
        id: settingsDialog
        title: qsTr("Settings")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok

        ColumnLayout {
            spacing: 4

            Switch {
                id: fixedTempRangeSwitch
                text: qsTr("Fixed temperature range")
            }

            RowLayout {
                spacing: 8
                enabled: fixedTempRangeSwitch.checked

                Label { text: qsTr("Min:") }
                SpinBox {
                    id: tempMinSpin
                    from: unitsSwitch.checked ? -58 : -50
                    to: unitsSwitch.checked ? 302 : 150
                    value: unitsSwitch.checked
                            ? Math.round(window.fixedTempMinC * 9 / 5 + 32)
                            : Math.round(window.fixedTempMinC)
                    onValueModified: {
                        window.fixedTempMinC = unitsSwitch.checked ? (value - 32) * 5 / 9 : value
                    }
                }
                Label { text: qsTr("Max:") }
                SpinBox {
                    id: tempMaxSpin
                    from: unitsSwitch.checked ? -58 : -50
                    to: unitsSwitch.checked ? 302 : 150
                    value: unitsSwitch.checked
                            ? Math.round(window.fixedTempMaxC * 9 / 5 + 32)
                            : Math.round(window.fixedTempMaxC)
                    onValueModified: {
                        window.fixedTempMaxC = unitsSwitch.checked ? (value - 32) * 5 / 9 : value
                    }
                }
                Label { text: unitsSwitch.checked ? qsTr("°F") : qsTr("°C") }
            }

            Switch {
                id: fixedHumidRangeSwitch
                text: qsTr("Fixed humidity range")
            }

            RowLayout {
                spacing: 8
                enabled: fixedHumidRangeSwitch.checked

                Label { text: qsTr("Min:") }
                SpinBox {
                    id: humidMinSpin
                    from: 0
                    to: 100
                    value: 0
                }
                Label { text: qsTr("Max:") }
                SpinBox {
                    id: humidMaxSpin
                    from: 0
                    to: 100
                    value: 100
                }
                Label { text: qsTr("%") }
            }
        }
    }

    Dialog {
        id: connectDialog
        title: qsTr("Connect")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel

        onAboutToShow: {
            if (hostCombo.editText.length === 0 && connectionManager.recentServers.length > 0) {
                hostCombo.editText = connectionManager.recentServers[0]
            }
        }
        onAccepted: {
            connectionManager.connectToServer(hostCombo.editText)
            reloadChart()
        }

        ColumnLayout {
            spacing: 8

            Label {
                text: qsTr("InfluxDB host")
            }
            ComboBox {
                id: hostCombo
                Layout.preferredWidth: 240
                editable: true
                inputMethodHints: Qt.ImhNoAutoUppercase
                model: connectionManager.recentServers
            }
        }
    }
}
