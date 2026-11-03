import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import "TodoLogic.js" as T

// Add bar: title field, mutually exclusive due chips, and a typed due field
// ("dd/mm [hh:mm]") that overrides the chip when non-empty.
Item {
    id: root
    property Theme theme: ThemeStore
    property int todayKey: 0
    // dueKey / dueMinutes are null when absent.
    signal submitted(string title, var dueKey, var dueMinutes)

    // "" | "today" | "tomorrow" | "week"
    property string chip: ""
    property bool dueInvalid: false

    implicitHeight: col.implicitHeight

    function focusTitle() { titleField.forceActiveFocus() }

    function toggleChip(name) {
        chip = chip === name ? "" : name
        dueInvalid = false
    }

    function submit() {
        var r = T.resolveDue(chip, dueField.text, todayKey)
        if (!r.ok) {
            dueInvalid = true
            return
        }
        var title = T.normalizeTitle(titleField.text)
        if (title === "") return
        root.submitted(title, r.key, r.minutes)
        titleField.text = ""
        dueField.text = ""
        chip = ""
        dueInvalid = false
        titleField.forceActiveFocus()
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        TextField {
            id: titleField
            Layout.fillWidth: true
            implicitHeight: 32
            placeholderText: "Add a todo…"
            color: theme.text
            placeholderTextColor: theme.overlay0
            font.pixelSize: theme.fontSize
            font.family: theme.fontUi
            selectByMouse: true
            leftPadding: 10
            rightPadding: 10
            background: Rectangle {
                radius: theme.radiusMd
                color: theme.surface0
                border.color: titleField.activeFocus ? theme.blue : "transparent"
                border.width: 1
            }
            onAccepted: root.submit()
            // Escape is not consumed here, so it bubbles up to the panel and closes it.
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { name: "today", label: "Today" },
                    { name: "tomorrow", label: "Tomorrow" },
                    { name: "week", label: "Next week" }
                ]

                delegate: Badge {
                    required property var modelData
                    theme: root.theme
                    text: modelData.label
                    clickable: true
                    solid: root.chip === modelData.name && dueField.text.trim() === ""
                    clr: root.chip === modelData.name ? theme.highlight : theme.subtext0
                    opacity: dueField.text.trim() !== "" ? 0.45 : 1
                    implicitHeight: 24
                    onClicked: root.toggleChip(modelData.name)
                }
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: dueField
                implicitWidth: 112
                implicitHeight: 24
                placeholderText: "dd/mm [hh:mm]"
                color: root.dueInvalid ? theme.red : theme.text
                placeholderTextColor: theme.overlay0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                selectByMouse: true
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle {
                    radius: theme.radiusMd
                    color: root.dueInvalid ? Qt.alpha(theme.red, 0.12) : theme.surface0
                    border.color: root.dueInvalid ? theme.red
                                : dueField.activeFocus ? theme.blue : "transparent"
                    border.width: 1
                }
                onTextChanged: root.dueInvalid = false
                onAccepted: root.submit()
            }
        }
    }
}
