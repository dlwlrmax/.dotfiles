import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import "TodoLogic.js" as T

// Deadline editor of the detail view: quick chips, a month grid and an optional time
// (hour / minute steppers, 5-minute steps). Nothing is saved until "Set"; "Clear"
// removes the deadline. load() fills it from a todo each time it is opened.
Rectangle {
    id: root
    property Theme theme: ThemeStore
    property int todayKey: 0
    // dueKey / dueMinutes are null when absent.
    signal picked(var dueKey, var dueMinutes)

    // yyyymmdd being edited, 0 = none
    property int key: 0
    property int minutes: defaultMinutes
    property bool noTime: false
    readonly property int defaultMinutes: 17 * 60 + 30
    // Month shown in the grid (month is 0-based).
    property int viewYear: Math.floor(todayKey / 10000)
    property int viewMonth: Math.floor(todayKey / 100) % 100 - 1
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                       "July", "August", "September", "October", "November", "December"]

    implicitHeight: col.implicitHeight + 16
    radius: theme.radiusMd
    color: theme.surface0

    function load(todo) {
        var has = !!todo && T.isDated(todo)
        key = has ? todo.due_key : 0
        noTime = has && (todo.due_minutes === null || todo.due_minutes === undefined)
        minutes = has && !noTime ? todo.due_minutes : defaultMinutes
        var k = key !== 0 ? key : todayKey
        viewYear = Math.floor(k / 10000)
        viewMonth = Math.floor(k / 100) % 100 - 1
    }

    function setKey(k) {
        key = k
        viewYear = Math.floor(k / 10000)
        viewMonth = Math.floor(k / 100) % 100 - 1
    }

    function shiftMonth(n) {
        var m = viewMonth + n
        viewYear += Math.floor(m / 12)
        viewMonth = ((m % 12) + 12) % 12
    }

    // Step hours (+-1, wrap 24) or minutes (+-5 on the 5-minute grid, wrap 60).
    function stepTime(hour, dir) {
        var h = Math.floor(minutes / 60)
        var m = minutes % 60
        if (hour) h = (h + dir + 24) % 24
        else m = ((dir > 0 ? Math.floor(m / 5) + 1 : Math.ceil(m / 5) - 1) * 5 + 60) % 60
        minutes = h * 60 + m
        noTime = false
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        // ── quick chips ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [{ label: "Today", days: 0 }, { label: "Tomorrow", days: 1 }, { label: "Next week", days: 7 }]

                delegate: Badge {
                    required property var modelData
                    readonly property int target: T.addDays(root.todayKey, modelData.days)
                    theme: root.theme
                    text: modelData.label
                    clickable: true
                    solid: root.key === target
                    clr: root.key === target ? theme.highlight : theme.subtext0
                    implicitHeight: 22
                    onClicked: root.setKey(target)
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ── month grid (Monday first, past days disabled) ──
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
            id: grid
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 6 * 22
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
                readonly property int dayKey: model.year * 10000 + (model.month + 1) * 100 + model.day
                readonly property bool inMonth: model.month === grid.month
                readonly property bool past: dayKey < root.todayKey

                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    visible: dayItem.inMonth
                    radius: theme.radiusSm
                    color: dayItem.dayKey === root.key ? theme.highlight
                         : dayMa.containsMouse && !dayItem.past ? theme.surface1 : "transparent"
                    border.width: dayItem.dayKey === root.todayKey && dayItem.dayKey !== root.key ? 1 : 0
                    border.color: theme.highlight

                    Text {
                        anchors.centerIn: parent
                        text: dayItem.model.day
                        color: dayItem.dayKey === root.key ? theme.base
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
                    onClicked: root.key = dayItem.dayKey
                }
            }
        }

        // ── time + actions ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [true, false]

                delegate: RowLayout {
                    id: spin
                    required property bool modelData
                    spacing: 2

                    Text {
                        visible: !spin.modelData
                        text: ":"
                        color: theme.subtext0
                        font.pixelSize: theme.fontSize
                        font.bold: true
                        font.family: theme.fontUi
                    }

                    IconButton {
                        theme: root.theme
                        text: Glyphs.down
                        glyphSize: theme.fontSizeMin
                        onClicked: root.stepTime(spin.modelData, -1)
                    }

                    Text {
                        text: String(spin.modelData ? Math.floor(root.minutes / 60) : root.minutes % 60).padStart(2, "0")
                        color: root.noTime ? Qt.alpha(theme.subtext0, 0.5) : theme.text
                        font.pixelSize: theme.fontSize + 2
                        font.bold: true
                        font.family: theme.fontUi

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onWheel: wheel => root.stepTime(spin.modelData, wheel.angleDelta.y > 0 ? 1 : -1)
                        }
                    }

                    IconButton {
                        theme: root.theme
                        text: Glyphs.up
                        glyphSize: theme.fontSizeMin
                        onClicked: root.stepTime(spin.modelData, 1)
                    }
                }
            }

            Badge {
                theme: root.theme
                text: "No time"
                clickable: true
                solid: root.noTime
                clr: root.noTime ? theme.highlight : theme.subtext0
                implicitHeight: 22
                onClicked: root.noTime = !root.noTime
            }

            Item { Layout.fillWidth: true }

            Badge {
                theme: root.theme
                text: "Clear"
                clickable: true
                clr: theme.red
                implicitHeight: 22
                onClicked: root.picked(null, null)
            }

            Badge {
                theme: root.theme
                text: "Set"
                clickable: root.key !== 0
                opacity: root.key !== 0 ? 1 : 0.45
                solid: root.key !== 0
                clr: root.key !== 0 ? theme.highlight : theme.subtext0
                implicitHeight: 22
                onClicked: root.picked(root.key, root.noTime ? null : root.minutes)
            }
        }
    }
}
