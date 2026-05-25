import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    property int calYear: 0
    property var today: new Date()
    property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                              "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    property var dayHeaders: ["M", "T", "W", "T", "F", "S", "S"]
    property var months: []

    clip: true
    implicitWidth: 720
    implicitHeight: 560

    function cellGrid(month) {
        var firstDay = new Date(calYear, month, 1).getDay(); // 0=Sun
        var daysInMon = new Date(calYear, month + 1, 0).getDate();
        var prevMonthDays = new Date(calYear, month, 0).getDate();
        var startOffset = firstDay === 0 ? 6 : firstDay - 1;

        var tYear = today.getFullYear();
        var tMonth = today.getMonth();
        var tDate = today.getDate();
        var isTodayMonth = (calYear === tYear && month === tMonth);

        var cells = [];
        for (var i = startOffset - 1; i >= 0; i--) {
            cells.push({ day: prevMonthDays - i, other: true, today: false });
        }
        for (var d = 1; d <= daysInMon; d++) {
            cells.push({ day: d, other: false, today: isTodayMonth && d === tDate });
        }
        var rem = 42 - cells.length;
        for (var d = 1; d <= rem; d++) {
            cells.push({ day: d, other: true, today: false });
        }
        return cells;
    }

    function buildYear() {
        var result = [];
        for (var m = 0; m < 12; m++) {
            result.push({ name: monthNames[m], grid: cellGrid(m) });
        }
        months = result;
    }

    function goToToday() {
        calYear = today.getFullYear();
        buildYear();
    }

    function prevYear() { calYear--; buildYear(); }
    function nextYear() { calYear++; buildYear(); }

    Component.onCompleted: goToToday()

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        // mask top border
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        // ── year header ──
        RowLayout {
            id: headerLayout
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "◀"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 2
                font.family: theme.font
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevYear()
                }
            }

            Text {
                text: root.calYear
                color: theme.text
                font.pixelSize: theme.fontSize + 4
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "▶"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 2
                font.family: theme.font
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextYear()
                }
            }

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4
                font.family: theme.font
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ── 12-month grid (4 cols × 3 rows) ──
        GridLayout {
            id: yearGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 10
            columnSpacing: 14

            Repeater {
                model: root.months
                delegate: ColumnLayout {
                    id: monthBlock
                    required property var modelData
                    property var m: modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 2

                    // month name
                    Text {
                        text: m.name
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize + 1
                        font.bold: true
                        font.family: theme.font
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // day-of-week headers
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: root.dayHeaders
                            delegate: Text {
                                text: modelData
                                color: theme.surface1
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // 6 week rows
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: 6
                            delegate: RowLayout {
                                id: weekRow
                                property int rowIdx: index
                                Layout.fillWidth: true
                                spacing: 0
                                Repeater {
                                    model: 7
                                    delegate: Item {
                                        property int cellIdx: weekRow.rowIdx * 7 + index
                                        property var cell: cellIdx < monthBlock.m.grid.length ? monthBlock.m.grid[cellIdx] : null
                                        Layout.fillWidth: true
                                        implicitHeight: 18

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            radius: 4
                                            color: cell && cell.today ? theme.mauve : "transparent"
                                            visible: cell !== null

                                            Text {
                                                anchors.centerIn: parent
                                                text: cell ? cell.day : ""
                                                color: cell ? (cell.today ? theme.base : (cell.other ? theme.surface0 : theme.subtext0)) : "transparent"
                                                font.pixelSize: theme.fontSize - 1
                                                font.bold: cell && cell.today
                                                font.family: theme.font
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
