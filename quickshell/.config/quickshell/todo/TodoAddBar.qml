import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import "TodoLogic.js" as T

// Add bar: title field + "+" button, quick due chips (Today / Tomorrow / Next week),
// a date picker (inline month grid) and an optional "hh:mm" time. A picked date and a
// chip are mutually exclusive; the time only applies once a date is set.
Item {
    id: root
    property Theme theme: ThemeStore
    property int todayKey: 0
    // dueKey / dueMinutes are null when absent.
    signal submitted(string title, var dueKey, var dueMinutes)

    // "" | "today" | "tomorrow" | "week"
    property string chip: ""
    // yyyymmdd chosen in the picker, 0 = none
    property int pickedKey: 0
    property bool pickerOpen: false
    property bool timeInvalid: false
    // Month shown in the picker (month is 0-based). Starts on today's month;
    // togglePicker() re-centres it on the picked date each time it opens.
    property int viewYear: Math.floor(todayKey / 10000)
    property int viewMonth: Math.floor(todayKey / 100) % 100 - 1

    readonly property int dueKey: pickedKey !== 0 ? pickedKey
                                  : (T.resolveDue(chip, "", todayKey).key ?? 0)
    readonly property bool hasDue: dueKey !== 0
    readonly property bool canAdd: T.normalizeTitle(titleField.text) !== ""
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]

    implicitHeight: col.implicitHeight

    function focusTitle() { titleField.forceActiveFocus() }

    function toggleChip(name) {
        chip = chip === name ? "" : name
        pickedKey = 0
        pickerOpen = false
    }

    function pickDate(key) {
        pickedKey = key
        chip = ""
        pickerOpen = false
    }

    function togglePicker() {
        if (!pickerOpen) {
            var k = pickedKey !== 0 ? pickedKey : todayKey
            viewYear = Math.floor(k / 10000)
            viewMonth = Math.floor(k / 100) % 100 - 1
        }
        pickerOpen = !pickerOpen
    }

    function shiftMonth(n) {
        var m = viewMonth + n
        viewYear += Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
    }

    function submit() {
        var t = T.parseTime(timeField.text)
        if (!t.ok) {
            timeInvalid = true
            return
        }
        var title = T.normalizeTitle(titleField.text)
        if (title === "") return
        root.submitted(title, hasDue ? dueKey : null, hasDue ? t.minutes : null)
        titleField.text = ""
        timeField.text = ""
        chip = ""
        pickedKey = 0
        pickerOpen = false
        timeInvalid = false
        titleField.forceActiveFocus()
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        // ── title + add button ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

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

            IconButton {
                theme: root.theme
                text: ""   // nf-fa-plus
                glyphSize: theme.fontSize + 1
                fill: theme.highlight
                implicitWidth: 32
                implicitHeight: 32
                enabled: root.canAdd
                onClicked: root.submit()
            }
        }

        // ── due: chips, date picker button, time ──
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
                    solid: root.chip === modelData.name
                    clr: root.chip === modelData.name ? theme.highlight : theme.subtext0
                    implicitHeight: 24
                    onClicked: root.toggleChip(modelData.name)
                }
            }

            // Calendar button; shows the picked date (dd/mm) once chosen.
            Badge {
                theme: root.theme
                text: "" + (root.pickedKey !== 0
                      ? "  " + String(root.pickedKey % 100).padStart(2, "0") + "/"
                        + String(Math.floor(root.pickedKey / 100) % 100).padStart(2, "0")
                      : "")
                clickable: true
                solid: root.pickedKey !== 0
                clr: root.pickedKey !== 0 || root.pickerOpen ? theme.highlight : theme.subtext0
                implicitHeight: 24
                onClicked: root.togglePicker()
            }

            Item { Layout.fillWidth: true }

            TextField {
                id: timeField
                implicitWidth: 56
                implicitHeight: 24
                enabled: root.hasDue
                opacity: root.hasDue ? 1 : 0.45
                placeholderText: "hh:mm"
                color: root.timeInvalid ? theme.red : theme.text
                placeholderTextColor: theme.overlay0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                selectByMouse: true
                horizontalAlignment: TextInput.AlignHCenter
                leftPadding: 4
                rightPadding: 4
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                background: Rectangle {
                    radius: theme.radiusMd
                    color: root.timeInvalid ? Qt.alpha(theme.red, 0.12) : theme.surface0
                    border.color: root.timeInvalid ? theme.red
                                : timeField.activeFocus ? theme.blue : "transparent"
                    border.width: 1
                }
                onTextChanged: root.timeInvalid = false
                onAccepted: root.submit()
            }
        }

        // ── inline date picker (one month, Monday first, past days disabled) ──
        Rectangle {
            id: picker
            visible: root.pickerOpen
            Layout.fillWidth: true
            implicitHeight: pickerCol.implicitHeight + 16
            radius: theme.radiusMd
            color: theme.surface0

            ColumnLayout {
                id: pickerCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    IconButton { theme: root.theme; text: Glyphs.prev; onClicked: root.shiftMonth(-1) }

                    Text {
                        Layout.fillWidth: true
                        text: root.monthNames[root.viewMonth] + " " + root.viewYear
                        color: theme.text
                        font.pixelSize: theme.fontSize
                        font.bold: true
                        font.family: theme.fontUi
                        horizontalAlignment: Text.AlignHCenter
                    }

                    IconButton { theme: root.theme; text: Glyphs.next; onClicked: root.shiftMonth(1) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]

                        Text {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            text: modelData
                            color: Qt.alpha(theme.subtext0, 0.6)
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.fontUi
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                MonthGrid {
                    id: pickGrid
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 6 * 24
                    month: root.viewMonth
                    year: root.viewYear
                    locale: Qt.locale("en_GB")   // Monday-first, matches the header row
                    spacing: 0
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0

                    delegate: Item {
                        id: dayItem
                        required property var model
                        readonly property int key: model.year * 10000 + (model.month + 1) * 100 + model.day
                        readonly property bool inMonth: model.month === pickGrid.month
                        readonly property bool past: key < root.todayKey

                        Rectangle {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            visible: dayItem.inMonth
                            radius: theme.radiusSm
                            color: dayItem.key === root.pickedKey ? theme.highlight
                                 : dayMa.containsMouse && !dayItem.past ? theme.surface1 : "transparent"
                            border.width: dayItem.key === root.todayKey && dayItem.key !== root.pickedKey ? 1 : 0
                            border.color: theme.highlight

                            Text {
                                anchors.centerIn: parent
                                text: dayItem.model.day
                                color: dayItem.key === root.pickedKey ? theme.base
                                     : dayItem.past ? Qt.alpha(theme.subtext0, 0.35) : theme.text
                                font.pixelSize: theme.fontSizeMin
                                font.family: theme.fontUi
                            }
                        }

                        MouseArea {
                            id: dayMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: dayItem.inMonth && !dayItem.past
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.pickDate(dayItem.key)
                        }
                    }
                }
            }
        }
    }
}
