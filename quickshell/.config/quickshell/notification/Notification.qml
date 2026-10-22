import QtQuick
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
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
    implicitWidth: iconText.implicitWidth + 6
    implicitHeight: iconText.implicitHeight + 4

    Text {
        id: iconText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 0.5
        text: root.dnd ? "\uF09B" : "\uF0F3"
        color: root.notifCount > 0 ? theme.onAccent : theme.overlay0
        font.pixelSize: theme.fontSize + 8
        font.weight: Font.Medium
        font.family: theme.font
    }

    // Unread marker: a small dot; the count is in the tooltip.
    Rectangle {
        id: badge
        visible: root.notifCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 2
        anchors.rightMargin: 2
        width: 8
        height: 8
        radius: 4
        color: theme.red
        border.width: 1
        border.color: theme.capsuleColor
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: hoverArea.containsMouse
        text: (root.notifCount > 0 ? root.notifCount + " unread" : "No unread notifications")
              + (root.dnd ? "\nDo not disturb on" : "")
              + "\nRight-click toggles do not disturb"
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
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
