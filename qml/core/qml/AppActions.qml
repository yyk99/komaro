import QtQuick
import QtQuick.Controls

QtObject {
    id: root

    signal connectRequested()
    signal aboutRequested()
    signal settingsRequested()

    readonly property Action connectAction: Action {
        text: qsTr("&Connect...")
        onTriggered: root.connectRequested()
    }

    readonly property Action aboutAction: Action {
        text: qsTr("&About")
        onTriggered: root.aboutRequested()
    }

    readonly property Action settingsAction: Action {
        text: qsTr("&Settings")
        onTriggered: root.settingsRequested()
    }

    readonly property Action exitAction: Action {
        text: qsTr("E&xit")
        onTriggered: Qt.quit()
    }
}
