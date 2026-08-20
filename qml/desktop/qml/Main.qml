import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
    }

    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")
            MenuItem { action: appActions.connectAction }
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
            chartController.load(connectionManager.currentHost, measurementField.text,
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
            TextField {
                id: measurementField
                text: "sensor"
                Layout.preferredWidth: 120
                onEditingFinished: reloadChart()
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

        Label {
            text: qsTr("Komaro Sensor Viewer\nDesktop QML app")
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
                model: connectionManager.recentServers
            }
        }
    }
}
