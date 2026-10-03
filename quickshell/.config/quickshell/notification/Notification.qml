import QtQuick
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property int notifCount: 0
    property bool dnd: dataSource ? dataSource.dnd : false
    signal togglePanel()

    onDataSourceChanged: {
        if (dataSource && dataSource.unreadCount !== undefined)
            notifCount = dataSource.unreadCount
    }

    Connections {
        target: dataSource
        enabled: root.dataSource !== null
        ignoreUnknownSignals: true
        function onUnreadCountChanged() {
            if (root.dataSource && root.dataSource.unreadCount !== undefined)
                root.notifCount = root.dataSource.unreadCount
        }
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: Math.max(iconText.implicitWidth + 6, badge.width + 2)
    implicitHeight: iconText.implicitHeight + 4

    Text {
        id: iconText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 2
        text: root.dnd ? "\uF09B" : "\uF0F3"
        color: root.notifCount > 0 ? theme.white : theme.surface1
        font.pixelSize: theme.fontSize + 8
        font.weight: Font.Medium
        font.family: theme.font
    }

    Rectangle {
        id: badge
        visible: root.notifCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.rightMargin: 1
        // True circle like KDE Connect: square with radius = diameter/2.
        // Clamp diameter to 18 so wide "9+" text stays circular.
        readonly property int diameter: Math.min(18, Math.max(14, badgeText.implicitWidth + 8))
        width: badge.diameter
        height: badge.diameter
        radius: badge.diameter / 2
        color: theme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.notifCount > 9 ? "9+" : root.notifCount
            color: theme.white
            font.pixelSize: 9
            font.bold: true
            font.family: theme.font
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel();
            } else if (mouse.button === Qt.RightButton) {
                if (root.dataSource && root.dataSource.toggleDnd)
                    root.dataSource.toggleDnd();
            }
        }
    }
}
