import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A checkable multi-select control: a button summarizing the current
// selection that opens a popup with a checkable list of `options` (typically
// bound to ChartController.recentMeasurements) plus a text field to add a
// name not yet in that list. Shared by desktop/mobile so both can select
// more than one sensor/measurement to overlay on the same SensorChart.
Item {
    id: root

    property var options: []
    property var selected: []

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Button {
        id: button
        anchors.fill: parent
        text: root.selected.length === 0
                ? qsTr("Select sensors...")
                : root.selected.join(", ")
        onClicked: popup.open()
    }

    Popup {
        id: popup
        y: button.height
        width: Math.max(240, button.width)
        modal: true
        focus: true

        ColumnLayout {
            width: parent.width
            spacing: 4

            Repeater {
                model: root.options

                delegate: CheckDelegate {
                    required property string modelData

                    Layout.fillWidth: true
                    text: modelData
                    checked: root.selected.indexOf(modelData) !== -1
                    onToggled: {
                        const list = root.selected.slice()
                        const idx = list.indexOf(modelData)
                        if (checked && idx === -1) {
                            list.push(modelData)
                        } else if (!checked && idx !== -1) {
                            list.splice(idx, 1)
                        }
                        root.selected = list
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                TextField {
                    id: newMeasurementField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Add sensor...")
                    inputMethodHints: Qt.ImhNoAutoUppercase
                    onAccepted: addButton.clicked()
                }
                Button {
                    id: addButton
                    text: qsTr("Add")
                    enabled: newMeasurementField.text.trim().length > 0
                    onClicked: {
                        const name = newMeasurementField.text.trim()
                        if (name.length === 0) {
                            return
                        }
                        if (root.selected.indexOf(name) === -1) {
                            root.selected = root.selected.concat([name])
                        }
                        newMeasurementField.text = ""
                    }
                }
            }
        }
    }
}
