import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property var device: dataSource ? dataSource.device : null
    property bool anyConnected: dataSource ? dataSource.anyConnected : false
    signal togglePanel(int centerX)

    function batteryColor(b) {
        if (b === null || b === undefined || b < 0) return theme.text
        if (b < 20) return theme.red
        if (b < 50) return theme.yellow
        return theme.green
    }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + 4
    Layout.alignment: Qt.AlignVCenter
    visible: true
    opacity: anyConnected ? 1 : 0.35

    MouseArea {
        id: clickArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var win = root.window
            var p = root.mapToItem(win ? win.contentItem : null, 0, 0)
            root.togglePanel(p.x + root.width / 2)
        }
    }

    RowLayout {
        id: row
        y: 4
        spacing: 4

        Item {
            // Match notification badge containment and spacing.
            implicitWidth: Math.max(iconText.implicitWidth + 6, badge.width + 2)
            implicitHeight: iconText.implicitHeight + 4

            Text {
                id: iconText
                anchors.centerIn: parent
                text: "\uF10B"  // phone icon
                color: theme.text
                font.pixelSize: theme.fontSize + 4
                font.weight: Font.Medium
                font.family: root.theme && root.theme.monoFont ? root.theme.monoFont : theme.font
            }

            // Notification badge
            Rectangle {
                id: badge
                visible: root.device && root.device.notifCount > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -4
                anchors.rightMargin: 1
                width: Math.max(14, badgeText.implicitWidth + 8)
                height: 14
                radius: 7
                color: theme.red

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.device && root.device.notifCount > 0
                          ? (root.device.notifCount > 9 ? "9+" : root.device.notifCount) : ""
                    color: theme.white
                    font.pixelSize: 9
                    font.bold: true
                    font.family: theme.font
                }
            }
        }

        // Battery %
        Text {
            id: batteryText
            visible: root.device && root.anyConnected
            text: root.device && root.device.battery !== null && root.device.battery >= 0
                  ? root.device.battery + "%" : "--"
            color: root.device ? root.batteryColor(root.device.battery) : theme.text
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }
    }
}
