import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import KomaroCore

ApplicationWindow {
    id: window
    width: 411
    height: 891
    visible: true
    title: qsTr("Komaro Sensor Viewer")

    Material.theme: Material.Dark

    AppActions {
        id: appActions
        onConnectRequested: connectDialog.open()
        onAboutRequested: aboutDialog.open()
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent

            ToolButton {
                text: "☰"
                font.pixelSize: 20
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
        width: Math.min(window.width * 0.75, 320)
        height: window.height

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            ItemDelegate {
                text: appActions.connectAction.text
                Layout.fillWidth: true
                onClicked: {
                    drawer.close()
                    appActions.connectAction.trigger()
                }
            }
            ItemDelegate {
                text: appActions.aboutAction.text
                Layout.fillWidth: true
                onClicked: {
                    drawer.close()
                    appActions.aboutAction.trigger()
                }
            }
            ItemDelegate {
                text: appActions.exitAction.text
                Layout.fillWidth: true
                onClicked: {
                    drawer.close()
                    appActions.exitAction.trigger()
                }
            }
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

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 8
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label { text: qsTr("Measurement:") }
                TextField {
                    id: measurementField
                    text: "sensor"
                    Layout.fillWidth: true
                    onEditingFinished: reloadChart()
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
            text: qsTr("Komaro Sensor Viewer\nMobile-look QML app")
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
