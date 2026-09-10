import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtCore
import KomaroCore

ApplicationWindow {
    id: window
    width: 411
    height: 891
    visible: true
    title: qsTr("Komaro Sensor Viewer")

    Material.theme: Material.Dark
    Material.accent: Material.Blue

    AppActions {
        id: appActions
        onConnectRequested: connectDialog.open()
        onAboutRequested: aboutDialog.open()
        onSettingsRequested: settingsDialog.open()
        onHelpRequested: helpDialog.open()
    }

    // Inline data-URI icons (link/sliders/info/logout/question-mark) since
    // the project has no bundled icon asset pipeline; drawn in white to
    // match Material.Dark text.
    readonly property string connectIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><rect x='2' y='7' width='10' height='10' rx='5' fill='none' stroke='white' stroke-width='2'/><rect x='12' y='7' width='10' height='10' rx='5' fill='none' stroke='white' stroke-width='2'/></svg>"
    readonly property string aboutIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><circle cx='12' cy='12' r='10' fill='none' stroke='white' stroke-width='2'/><circle cx='12' cy='7.5' r='1.3' fill='white'/><rect x='10.8' y='10.5' width='2.4' height='7' rx='1.2' fill='white'/></svg>"
    readonly property string helpIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><circle cx='12' cy='12' r='10' fill='none' stroke='white' stroke-width='2'/><text x='12' y='17' text-anchor='middle' font-size='14' font-family='sans-serif' fill='white'>?</text></svg>"
    readonly property string settingsIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><line x1='4' y1='6' x2='20' y2='6' stroke='white' stroke-width='2' stroke-linecap='round'/><circle cx='9' cy='6' r='2' fill='white'/><line x1='4' y1='12' x2='20' y2='12' stroke='white' stroke-width='2' stroke-linecap='round'/><circle cx='15' cy='12' r='2' fill='white'/><line x1='4' y1='18' x2='20' y2='18' stroke='white' stroke-width='2' stroke-linecap='round'/><circle cx='9' cy='18' r='2' fill='white'/></svg>"
    // "Hamburger" menu icon - a literal U+2630 glyph looked wrong on Android
    // (the default font there doesn't reliably cover it), so this uses the
    // same inline-SVG approach as the drawer icons above instead of a font glyph.
    readonly property string hamburgerIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><line x1='3' y1='6' x2='21' y2='6' stroke='white' stroke-width='2' stroke-linecap='round'/><line x1='3' y1='12' x2='21' y2='12' stroke='white' stroke-width='2' stroke-linecap='round'/><line x1='3' y1='18' x2='21' y2='18' stroke='white' stroke-width='2' stroke-linecap='round'/></svg>"
    readonly property string exitIconSource: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='M9 4H5a1 1 0 0 0-1 1v14a1 1 0 0 0 1 1h4' fill='none' stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/><path d='M13 8l4 4-4 4' fill='none' stroke='white' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/><line x1='8' y1='12' x2='20' y2='12' stroke='white' stroke-width='2' stroke-linecap='round'/></svg>"

    // Fixed temperature range bounds, always stored in Celsius (matching
    // SensorChart.series' points' temperatureC) regardless of the °C/°F toggle -
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
        property alias selectedMeasurements: measurementSelect.selected
    }

    Settings {
        category: "app"
        property alias keepScreenOn: keepScreenOnSwitch.checked
        property alias autoRefreshEnabled: autoRefreshSwitch.checked
        property alias autoRefreshIntervalMin: autoRefreshIntervalSpin.value
        property alias autoConnect: autoConnectSwitch.checked
    }

    Component.onCompleted: {
        if (autoConnectSwitch.checked && connectionManager.recentServers.length > 0) {
            connectionManager.connectToServer(connectionManager.recentServers[0])
            reloadChart()
        }
    }

    Timer {
        interval: autoRefreshIntervalSpin.value * 60000
        running: autoRefreshSwitch.checked && connectionManager.currentHost.length > 0
        repeat: true
        onTriggered: reloadChart()
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent

            ToolButton {
                icon.source: hamburgerIconSource
                icon.width: 20
                icon.height: 20
                onClicked: drawer.open()
            }
            Label {
                text: window.title
                elide: Label.ElideRight
                horizontalAlignment: Qt.AlignHCenter
                verticalAlignment: Qt.AlignVCenter
                Layout.fillWidth: true
            }
        }
    }

    Drawer {
        id: drawer
        width: Math.min(window.width * 0.6, 220)
        height: window.height

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            ItemDelegate {
                text: appActions.connectAction.text
                icon.source: connectIconSource
                icon.width: 20
                icon.height: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: {
                    drawer.close()
                    appActions.connectAction.trigger()
                }
            }
            ItemDelegate {
                text: appActions.settingsAction.text
                icon.source: settingsIconSource
                icon.width: 20
                icon.height: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: {
                    drawer.close()
                    appActions.settingsAction.trigger()
                }
            }
            ItemDelegate {
                text: appActions.exitAction.text
                icon.source: exitIconSource
                icon.width: 20
                icon.height: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: {
                    drawer.close()
                    appActions.exitAction.trigger()
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            ItemDelegate {
                text: appActions.helpAction.text
                icon.source: helpIconSource
                icon.width: 20
                icon.height: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: {
                    drawer.close()
                    appActions.helpAction.trigger()
                }
            }
            ItemDelegate {
                text: appActions.aboutAction.text
                icon.source: aboutIconSource
                icon.width: 20
                icon.height: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                onClicked: {
                    drawer.close()
                    appActions.aboutAction.trigger()
                }
            }
        }
    }

    function reloadChart() {
        if (connectionManager.currentHost.length > 0) {
            chartController.load(connectionManager.currentHost, measurementSelect.selected,
                                  timeRangeCombo.currentText, windowSpin.value)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label { text: qsTr("Sensors:") }
                MultiMeasurementSelect {
                    id: measurementSelect
                    Layout.fillWidth: true
                    options: chartController.recentMeasurements
                    onSelectedChanged: reloadChart()
                    Component.onCompleted: {
                        // Settings' selectedMeasurements alias has already
                        // restored the previous session's selection by this
                        // point (if any) - only fall back to a default when
                        // there's nothing to restore.
                        if (selected.length === 0) {
                            selected = chartController.recentMeasurements.length > 0
                                    ? [chartController.recentMeasurements[0]] : ["sensor"]
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ComboBox {
                    id: timeRangeCombo
                    Layout.fillWidth: true
                    model: ["1h", "6h", "24h", "48h", "7d", "30d", "all"]
                    currentIndex: 4
                    onActivated: reloadChart()
                }
                SpinBox {
                    id: windowSpin
                    from: 1
                    to: 200
                    value: 10
                    onValueModified: reloadChart()
                }
                Switch {
                    id: unitsSwitch
                    text: checked ? qsTr("°F") : qsTr("°C")
                }
                Button {
                    text: qsTr("Refresh")
                    enabled: connectionManager.currentHost.length > 0
                    onClicked: reloadChart()
                }
            }
        }

        Rectangle {
            id: plotArea
            color: "#1e1e1e"
            Layout.fillWidth: true
            Layout.fillHeight: true

            SensorChart {
                id: sensorChart
                anchors.fill: parent
                anchors.margins: 8
                series: chartController.series
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
                text: sensorChart.hairlineStatusText.length > 0 ? sensorChart.hairlineStatusText : chartController.status
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
            Label { text: qsTr("Mobile-look QML app") }
            Label { text: qsTr("Built: %1").arg(appBuildTimestamp) }
        }
    }

    Dialog {
        id: helpDialog
        title: qsTr("Help")
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok

        ColumnLayout {
            width: Math.min(340, window.width - 40)
            spacing: 12

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("<b>Connect</b><br>Menu (☰) → Connect to enter an InfluxDB host. Recently used hosts are remembered.")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("<b>Sensors</b><br>Pick one or more measurements from the Sensors selector. Each selected sensor gets its own temperature/humidity line pair on the chart, distinguished by line style.")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("<b>Range / Smoothing / Units</b><br>Choose how far back to query, a moving-average smoothing window (in samples), and °C/°F.")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("<b>Settings</b><br>Fixed temperature/humidity axis ranges, keeping the screen on, connecting to the last server automatically on startup, and periodic auto-refresh are all here.")
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("<b>Hairline</b><br>Tap the chart to show a vertical hairline with each sensor's value at that time in the status bar. Drag to move it. Tap again to hide it.")
            }
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
                id: keepScreenOnSwitch
                text: qsTr("Keep screen on")
                onCheckedChanged: screenWakeLock.keepScreenOn = checked
            }

            Switch {
                id: autoRefreshSwitch
                text: qsTr("Auto refresh")
            }

            RowLayout {
                spacing: 8
                enabled: autoRefreshSwitch.checked

                Label { text: qsTr("Interval (min):") }
                SpinBox {
                    id: autoRefreshIntervalSpin
                    from: 1
                    to: 120
                    value: 5
                }
            }

            Switch {
                id: autoConnectSwitch
                text: qsTr("Auto connect")
            }

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
