import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import "TodoLogic.js" as T

// Add bar: title field + "+" button, quick due chips (Today / Tomorrow / Next week),
// a date picker (inline month grid) and a time picker (hour / minute spinner, default 17:30).
// A picked date and a chip are mutually exclusive; the time only applies once a date is set.
Item {
    id: root
    property Theme theme: ThemeStore
    property int todayKey: 0
    // Current time of day (minutes after midnight); today's due time can't be earlier than this.
    property int nowMinutes: 0
    // dueKey / dueMinutes are null when absent.
    signal submitted(string title, var dueKey, var dueMinutes)

    // "" | "today" | "tomorrow" | "week"
    property string chip: ""
    // yyyymmdd chosen in the picker, 0 = none
    property int pickedKey: 0
    property bool pickerOpen: false
    property bool timePickerOpen: false
    // Time of day in minutes after midnight; reset to the default after each submit.
    readonly property int defaultMinutes: 17 * 60 + 30
    property int timeMinutes: defaultMinutes
    // true = date-only todo (no due time, falls back to 09:00 in the logic).
    property bool noTime: false
    // Month shown in the picker (month is 0-based). Starts on today's month;
    // togglePicker() re-centres it on the picked date each time it opens.
    property int viewYear: Math.floor(todayKey / 10000)
    property int viewMonth: Math.floor(todayKey / 100) % 100 - 1

    readonly property int dueKey: pickedKey !== 0 ? pickedKey
                                  : (T.resolveDue(chip, "", todayKey).key ?? 0)
    readonly property bool hasDue: dueKey !== 0
    // Earliest selectable time: now (rounded up to 5 min) when the due date is today, else 0.
    readonly property int minMinutes: dueKey === todayKey && dueKey !== 0
                                      ? Math.min(Math.ceil(nowMinutes / 5) * 5, 1435) : 0
    // The time actually used: the picked time, lifted to minMinutes so it is never in the past.
    readonly property int shownMinutes: Math.max(timeMinutes, minMinutes)
    readonly property bool canAdd: T.normalizeTitle(titleField.text) !== ""
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]

    implicitHeight: col.implicitHeight

    function focusTitle() { titleField.forceActiveFocus() }

    function toggleChip(name) {
        chip = chip === name ? "" : name
        pickedKey = 0
        pickerOpen = false
        timePickerOpen = false
    }

    function pickDate(key) {
        pickedKey = key
        chip = ""
        pickerOpen = false
    }

    function toggleTimePicker() {
        if (!hasDue) return
        timePickerOpen = !timePickerOpen
        if (timePickerOpen) pickerOpen = false
    }

    // Step hours (+-1, wrap 24) or minutes (+-5, snapped to the 5-minute grid, wrap 60).
    function stepTime(hour, dir) {
        var h = Math.floor(shownMinutes / 60)
        var m = shownMinutes % 60
        if (hour) h = (h + dir + 24) % 24
        else m = ((dir > 0 ? Math.floor(m / 5) + 1 : Math.ceil(m / 5) - 1) * 5 + 60) % 60
        timeMinutes = Math.max(h * 60 + m, minMinutes)
        noTime = false
    }

    function togglePicker() {
        if (!pickerOpen) {
            var k = pickedKey !== 0 ? pickedKey : todayKey
            viewYear = Math.floor(k / 10000)
            viewMonth = Math.floor(k / 100) % 100 - 1
        }
        pickerOpen = !pickerOpen
        if (pickerOpen) timePickerOpen = false
    }

    function shiftMonth(n) {
        var m = viewMonth + n
        viewYear += Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
    }

    function submit() {
        var title = T.normalizeTitle(titleField.text)
        if (title === "") return
        root.submitted(title, hasDue ? dueKey : null, hasDue && !noTime ? shownMinutes : null)
        titleField.text = ""
        chip = ""
        pickedKey = 0
        pickerOpen = false
        timePickerOpen = false
        timeMinutes = defaultMinutes
        noTime = false
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

            // Clock button; shows the chosen time (hh:mm). Needs a due date.
            Badge {
                theme: root.theme
                text: "  " + (root.noTime ? "--:--"
                      : String(Math.floor(root.shownMinutes / 60)).padStart(2, "0") + ":"
                        + String(root.shownMinutes % 60).padStart(2, "0"))
                clickable: root.hasDue
                opacity: root.hasDue ? 1 : 0.45
                solid: false
                clr: root.hasDue && root.timePickerOpen ? theme.highlight : theme.subtext0
                implicitHeight: 24
                onClicked: root.toggleTimePicker()
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

        // ── inline time picker: spinner, hours wrap 00-23, minutes step 5 and wrap ──
        Rectangle {
            visible: root.timePickerOpen && root.hasDue
            Layout.fillWidth: true
            implicitHeight: pickCol.implicitHeight + 16
            radius: theme.radiusMd
            color: theme.surface0

            ColumnLayout {
                id: pickCol
                anchors.centerIn: parent
                spacing: 6

            RowLayout {
                id: spinRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Repeater {
                    model: [0, 1]

                    delegate: RowLayout {
                        id: spin
                        required property int modelData
                        readonly property bool isHour: modelData === 0
                        spacing: 8

                        Text {
                            visible: !spin.isHour
                            text: ":"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize + 4
                            font.bold: true
                            font.family: theme.fontUi
                        }

                        ColumnLayout {
                            spacing: 0

                            IconButton {
                                Layout.alignment: Qt.AlignHCenter
                                theme: root.theme
                                text: Glyphs.up
                                glyphSize: theme.fontSizeMin
                                onClicked: root.stepTime(spin.isHour, 1)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: String(spin.isHour ? Math.floor(root.shownMinutes / 60)
                                                         : root.shownMinutes % 60).padStart(2, "0")
                                color: root.noTime ? Qt.alpha(theme.subtext0, 0.5) : theme.text
                                font.pixelSize: theme.fontSize + 4
                                font.bold: true
                                font.family: theme.fontUi

                                // Scroll wheel steps the value too.
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onWheel: wheel => root.stepTime(spin.isHour, wheel.angleDelta.y > 0 ? 1 : -1)
                                }
                            }

                            IconButton {
                                Layout.alignment: Qt.AlignHCenter
                                theme: root.theme
                                text: Glyphs.down
                                glyphSize: theme.fontSizeMin
                                onClicked: root.stepTime(spin.isHour, -1)
                            }
                        }
                    }
                }
            }

            // Date-only todo: no due time.
            Badge {
                Layout.alignment: Qt.AlignHCenter
                theme: root.theme
                text: "No time"
                clickable: true
                solid: root.noTime
                clr: root.noTime ? theme.highlight : theme.subtext0
                implicitHeight: 24
                onClicked: root.noTime = !root.noTime
            }
            }
        }
    }
}
