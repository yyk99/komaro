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

    Rectangle {
        id: plotArea
        anchors.fill: parent
        color: "#1e1e1e"

        Text {
            anchors.centerIn: parent
            text: qsTr("Plot area")
            color: "white"
            font.pixelSize: 20
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

        ColumnLayout {
            spacing: 8

            Label {
                text: qsTr("InfluxDB host")
            }
            TextField {
                id: hostField
                Layout.preferredWidth: 240
                placeholderText: qsTr("e.g. silvana.home")
            }
        }
    }
}
