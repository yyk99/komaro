import QtQuick
import QtQuick.Controls

QtObject {
    id: root

    signal connectRequested()
    signal aboutRequested()
    signal settingsRequested()
    signal helpRequested()
    signal integralRequested()

    readonly property Action connectAction: Action {
        text: qsTr("&Connect...")
        onTriggered: root.connectRequested()
    }

    readonly property Action aboutAction: Action {
        text: qsTr("&About")
        onTriggered: root.aboutRequested()
    }

    readonly property Action helpAction: Action {
        text: qsTr("Help &Contents")
        onTriggered: root.helpRequested()
    }

    // Consumed charge/energy over the Power page's displayed period; the
    // shell decides when it is enabled and calls PowerPage.showIntegral().
    readonly property Action integralAction: Action {
        text: qsTr("&Integral...")
        onTriggered: root.integralRequested()
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
