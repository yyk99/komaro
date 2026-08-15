import QtQuick
import QtQuick.Controls

QtObject {
    id: root

    signal connectRequested()
    signal aboutRequested()

    readonly property Action connectAction: Action {
        text: qsTr("&Connect...")
        onTriggered: root.connectRequested()
    }

    readonly property Action aboutAction: Action {
        text: qsTr("&About")
        onTriggered: root.aboutRequested()
    }

    readonly property Action exitAction: Action {
        text: qsTr("E&xit")
        onTriggered: Qt.quit()
    }
}
