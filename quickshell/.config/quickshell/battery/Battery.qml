import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property string batteryIcon: ""
    property string batteryStatus: ""
    signal togglePanel(int centerX)

    property string iconColor: {
        if (!batteryStatus) return theme.subtext0
        if (batteryStatus === "Charging") return theme.green
        if (batteryStatus === "Full") return theme.green
        if (batteryStatus === "Discharging") return theme.peach
        return theme.subtext0
    }

    implicitWidth: batteryIcon ? iconText.implicitWidth : 0
    implicitHeight: iconText.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    Text {
        id: iconText
        visible: batteryIcon !== ""
        text: batteryIcon || ""
        color: root.iconColor
        font.pixelSize: root.theme.fontSize + 10
        font.weight: Font.Medium
        font.family: theme.font

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                var globalPos = root.mapToItem(null, 0, 0)
                root.togglePanel(globalPos.x + root.width / 2)
            }
        }
    }

    Process {
        id: battProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/battery.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim()
                if (!output) {
                    root.batteryIcon = ""
                    root.batteryStatus = ""
                } else {
                    var parts = output.split("|")
                    if (parts.length >= 3) {
                        root.batteryIcon = parts[0] || ""
                        root.batteryStatus = parts[2] || ""
                    }
                }
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: battProc.running = true
    }
}
