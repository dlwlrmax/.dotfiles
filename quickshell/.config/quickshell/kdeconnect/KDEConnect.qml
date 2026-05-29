import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var device: null  // current main device
    property bool anyConnected: false
    signal togglePanel(int centerX)

    implicitWidth: anyConnected ? row.implicitWidth : 0
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter
    visible: anyConnected

    MouseArea {
        id: clickArea
        anchors.fill: row
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var globalPos = root.mapToItem(null, 0, 0)
            root.togglePanel(globalPos.x + root.width / 2)
        }
    }

    RowLayout {
        id: row
        spacing: 4

        Item {
            implicitWidth: iconText.implicitWidth
            implicitHeight: iconText.implicitHeight

            Text {
                id: iconText
                anchors.centerIn: parent
                text: ""  // phone icon
                color: theme.text
                font.pixelSize: theme.fontSize + 4
                font.weight: Font.Medium
                font.family: theme.font
            }

            // Notification badge
            Rectangle {
                visible: root.device && root.device.notifCount > 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -4
                anchors.rightMargin: -6
                width: Math.max(12, badgeText.implicitWidth + 4)
                height: 12
                radius: 6
                color: theme.red

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.device && root.device.notifCount > 0
                          ? (root.device.notifCount > 9 ? "9+" : root.device.notifCount) : ""
                    color: theme.white
                    font.pixelSize: 8
                    font.bold: true
                    font.family: theme.font
                }
            }
        }

        // Battery %
        Text {
            id: batteryText
            visible: root.device && root.device.battery !== null && root.device.battery >= 0
            text: root.device ? root.device.battery + "%" : ""
            color: {
                if (!root.device || root.device.battery === null) return theme.text
                var b = root.device.battery
                if (b < 20) return theme.red
                if (b < 50) return theme.yellow
                return theme.green
            }
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }
    }

    Process {
        id: kdProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/kdeconnect.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    root.anyConnected = data.anyConnected || false
                    if (data.devices && data.devices.length > 0) {
                        root.device = data.devices[0]
                    } else {
                        root.device = null
                    }
                } catch (e) {
                    console.log("KDEConnect parse error:", e)
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: kdProc.running = true
    }
}
