import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Bar widget: checklist glyph plus a badge with the pending count (red while
// anything is overdue). Hover for the numbers; click opens the panel.
Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    signal togglePanel()

    readonly property int pending: dataSource ? dataSource.pendingCount : 0
    readonly property int overdue: dataSource ? dataSource.overdueCount : 0

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        spacing: 3

        Text {
            text: Glyphs.todo
            color: root.overdue > 0 ? theme.red : theme.subtext0
            font.pixelSize: theme.fontSize + 9
            font.family: theme.font
            Layout.alignment: Qt.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }

        Badge {
            visible: root.pending > 0
            theme: root.theme
            text: root.pending
            clr: root.overdue > 0 ? theme.red : theme.subtext0
            Layout.alignment: Qt.AlignVCenter
        }
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse
        text: root.pending + " pending, " + root.overdue + " overdue"
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.togglePanel()
        }
    }
}
