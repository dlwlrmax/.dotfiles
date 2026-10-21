import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.common
import "../common/CalendarLogic.js" as Cal

// One month: compact card in the year overview, or the big zoomed view
// (week numbers, lunar dates, holiday names) when `big`.
Item {
    id: mv

    property Theme theme
    property int year: 0
    property int month: 0          // 0-based
    property bool big: false
    property int todayKey: 0
    property int selStart: 0
    property int selEnd: 0
    property var calLocale
    readonly property var dayHeaders: ["M", "T", "W", "T", "F", "S", "S"]
    readonly property bool isCurrent: Cal.keyYear(todayKey) === year && Cal.keyMonth(todayKey) === month + 1
    readonly property int rowHeight: big ? 46 : 18
    readonly property int weekColWidth: 28

    signal dayClicked(int key)
    signal titleClicked()

    implicitHeight: col.implicitHeight + (big ? 0 : 12)

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusLg
        color: mv.isCurrent && !mv.big ? Qt.alpha(mv.theme.surface0, 0.45) : "transparent"
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        anchors.margins: mv.big ? 0 : 6
        spacing: mv.big ? 6 : 2

        Text {
            visible: !mv.big
            text: Cal.MONTHS[mv.month]
            color: titleMa.containsMouse ? mv.theme.text : mv.isCurrent ? mv.theme.highlight : mv.theme.subtext1
            font.pixelSize: mv.theme.fontSize + 1
            font.bold: true
            font.family: mv.theme.font
            Layout.alignment: Qt.AlignHCenter

            MouseArea {
                id: titleMa
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mv.titleClicked()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1   // cells size from our width, not vice versa
            spacing: 0

            Item { visible: mv.big; Layout.preferredWidth: mv.weekColWidth }

            Repeater {
                model: mv.dayHeaders

                Text {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: modelData
                    color: Qt.alpha(mv.theme.subtext0, 0.6)
                    font.pixelSize: mv.theme.fontSize - 1
                    font.family: mv.theme.font
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Cells size from our size, so give the layout fixed hints
            // instead of the (circular) content size.
            Layout.preferredWidth: 1
            Layout.preferredHeight: 6 * mv.rowHeight
            Layout.minimumHeight: 6 * mv.rowHeight
            spacing: 0

            // ISO week numbers (zoomed view only)
            ColumnLayout {
                visible: mv.big
                Layout.fillWidth: false   // nested layouts default to filling
                Layout.preferredWidth: mv.weekColWidth
                Layout.fillHeight: true
                spacing: 0

                Repeater {
                    model: mv.big ? Cal.weekNumbers(mv.year, mv.month) : []

                    Text {
                        required property int modelData
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        text: modelData
                        color: Qt.alpha(mv.theme.subtext0, 0.45)
                        font.pixelSize: mv.theme.fontSizeMin
                        font.family: mv.theme.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            MonthGrid {
                id: mg
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                month: mv.month
                year: mv.year
                locale: mv.calLocale
                spacing: 0
                padding: 0
                topPadding: 0
                bottomPadding: 0
                leftPadding: 0
                rightPadding: 0

                delegate: DayCell {
                    view: mv
                    grid: mg
                }
            }
        }
    }
}
