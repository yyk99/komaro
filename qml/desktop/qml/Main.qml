import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 1024
    height: 768
    visible: true
    title: qsTr("Komaro Sensor Viewer")

    menuBar: MenuBar {
        Menu {
            title: qsTr("&File")
            MenuItem {
                text: qsTr("E&xit")
                onTriggered: Qt.quit()
            }
        }
        Menu {
            title: qsTr("&Help")
            MenuItem {
                text: qsTr("&About")
                onTriggered: aboutDialog.open()
            }
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
}
