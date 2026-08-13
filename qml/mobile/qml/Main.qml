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
            text: qsTr("Komaro Sensor Viewer\nMobile-look QML app")
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
