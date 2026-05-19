import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property Theme theme: Theme {}
    property int cpuUsage: 0
    property int ramUsage: 0
    property int swapUsage: 0
    signal togglePanel()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        spacing: 12

        Text {
            text: root.cpuUsage + "%  "
            color: root.cpuUsage > 70 ? theme.red : root.cpuUsage > 30 ? theme.yellow : theme.green
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        Text {
            text: root.ramUsage + "%  "
            color: root.ramUsage > 80 ? theme.red : root.ramUsage > 50 ? theme.yellow : theme.green
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        Text {
            text: root.swapUsage + "% 󰾵 "
            color: root.swapUsage > 50 ? theme.red : root.swapUsage > 20 ? theme.yellow : theme.green
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
            visible: root.swapUsage > 0
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }

    Process {
        id: cpuProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/cpu-usage.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var usage = parseInt(output);
                if (!isNaN(usage)) {
                    root.cpuUsage = usage;
                }
            }
        }
    }

    Process {
        id: memProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mem-usage.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n");
                if (lines.length >= 1) {
                    var ram = parseInt(lines[0]);
                    if (!isNaN(ram)) root.ramUsage = ram;
                }
                if (lines.length >= 2) {
                    var swap = parseInt(lines[1]);
                    if (!isNaN(swap)) root.swapUsage = swap;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
        }
    }
}
