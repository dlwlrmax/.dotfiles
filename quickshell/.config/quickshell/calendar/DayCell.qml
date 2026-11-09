import QtQuick
import QtQuick.Layouts
import "../common/CalendarLogic.js" as Cal

// One day cell of a MonthView's MonthGrid (compact in the year view, roomy with
// lunar date + holiday name in the zoomed month view).
Item {
    id: cell

    required property var model
    property var view
    property var grid

    readonly property var theme: view.theme
    readonly property int key: Cal.makeKey(model.year, model.month + 1, model.day)
    readonly property bool other: model.month !== grid.month
    readonly property bool isToday: !other && key === view.todayKey
    readonly property bool selected: !other && (key === view.selStart || key === view.selEnd)
    readonly property bool inRange: !other && view.selStart !== 0 && view.selEnd !== 0
                                    && key > view.selStart && key < view.selEnd
    // Worked day of this month (see Cal.isWorkday); filler cells never count.
    readonly property bool workday: !other && Cal.isWorkday(key)
    // Lunar/holiday data only for days of this month (adjacent-month cells are dim filler).
    readonly property var info: other ? null : Cal.dayInfo(key)
    readonly property var holiday: info ? info.holiday : null
    readonly property bool hovered: ma.containsMouse
    // Open todo due this day (one dot however many; filler cells never marked).
    readonly property bool hasTodo: !other && view.markedSet[key] === true

    readonly property color numberColor: isToday ? theme.base
        : selected ? theme.text
        : other ? theme.surface1
        : (holiday && holiday.kind === "holiday") ? theme.red
        : workday ? theme.text
        : Qt.alpha(theme.subtext0, 0.55)
    readonly property int numberWeight: isToday ? Font.Bold : workday ? Font.DemiBold : Font.Normal
    readonly property color markColor: holiday && holiday.kind === "holiday" ? theme.red : theme.sapphire

    width: grid.availableWidth / 7
    height: grid.availableHeight / 6

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.view.dayClicked(cell.key)
    }

    Loader {
        anchors.fill: parent
        sourceComponent: cell.view.big ? bigVisual : smallVisual
    }

    Component {
        id: smallVisual

        Item {
            Rectangle {
                id: badge
                anchors.centerIn: parent
                width: 20
                height: 20
                radius: theme.radiusSm
                color: cell.isToday ? cell.theme.highlight
                     : cell.selected ? Qt.alpha(cell.theme.sapphire, 0.35)
                     : cell.inRange ? Qt.alpha(cell.theme.sapphire, 0.15)
                     : cell.hovered ? cell.theme.surface0 : "transparent"
                border.width: cell.selected && !cell.isToday ? 1 : 0
                border.color: cell.theme.sapphire

                Text {
                    anchors.centerIn: parent
                    text: cell.model.day
                    color: cell.numberColor
                    font.pixelSize: cell.theme.fontSize - 1
                    font.weight: cell.numberWeight
                    font.family: cell.theme.font
                }

                // holiday / observance marker
                Rectangle {
                    visible: cell.holiday !== null
                    x: parent.width - 5
                    y: 1
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.markColor
                }

                // open-todo marker: bottom centre, clear of the holiday dot
                Rectangle {
                    visible: cell.hasTodo
                    x: (parent.width - width) / 2
                    y: parent.height - height - 1
                    width: 4
                    height: 4
                    radius: 2
                    color: cell.theme.green
                }
            }
        }
    }

    Component {
        id: bigVisual

        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: theme.radiusMd
            color: cell.isToday ? Qt.alpha(cell.theme.highlight, 0.18)
                 : cell.selected ? Qt.alpha(cell.theme.sapphire, 0.3)
                 : cell.inRange ? Qt.alpha(cell.theme.sapphire, 0.12)
                 : cell.hovered ? Qt.alpha(cell.theme.surface0, 0.9)
                 : cell.other ? "transparent"
                 : Qt.alpha(cell.theme.surface0, cell.workday ? 0.6 : 0.1)
            border.width: cell.selected ? 1.5 : cell.isToday ? 1 : 0
            border.color: cell.selected ? cell.theme.sapphire : cell.theme.highlight

            Rectangle {
                id: dayBox
                x: 4
                y: 4
                width: dayText.implicitWidth + 8
                height: dayText.implicitHeight + 2
                radius: theme.radiusSm
                color: cell.isToday ? cell.theme.highlight : "transparent"

                Text {
                    id: dayText
                    anchors.centerIn: parent
                    text: cell.model.day
                    color: cell.numberColor
                    font.pixelSize: cell.theme.fontSize + 1
                    font.weight: cell.numberWeight
                    font.family: cell.theme.font
                }
            }

            // open-todo marker beside the day number
            Rectangle {
                visible: cell.hasTodo
                x: 4 + dayBox.width + 3
                y: dayBox.y + (dayBox.height - height) / 2
                width: 5
                height: 5
                radius: 2.5
                color: cell.theme.green
            }

            // lunar day (d/m on the first of a lunar month)
            Text {
                visible: !cell.other
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 5
                text: cell.other ? "" : Cal.lunarLabel(cell.key)
                readonly property bool first: !cell.other && cell.info.lunar[0] === 1
                color: first ? cell.theme.peach : Qt.alpha(cell.theme.subtext0, 0.7)
                font.pixelSize: cell.theme.fontSizeMin
                font.bold: first
                font.family: cell.theme.font
            }

            Text {
                visible: cell.holiday !== null
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                text: cell.holiday ? cell.holiday.name : ""
                color: cell.markColor
                font.pixelSize: cell.theme.fontSizeMin
                font.family: cell.theme.font
                elide: Text.ElideRight
            }
        }
    }
}
