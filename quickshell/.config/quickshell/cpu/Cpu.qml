import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property int cpuUsage: dataSource ? dataSource.cpuUsage : 0
    property int ramUsage: dataSource ? dataSource.ramUsage : 0
    property int swapUsage: dataSource ? dataSource.swapUsage : 0
    signal togglePanel()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

        RowLayout {
            id: row
            spacing: 6

            Text {
                text: root.cpuUsage + "%"
                color: root.cpuUsage > 70 ? theme.red : root.cpuUsage > 30 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: ""
                color: root.cpuUsage > 70 ? theme.red : root.cpuUsage > 30 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 5
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: root.ramUsage + "%"
                color: root.ramUsage > 80 ? theme.red : root.ramUsage > 50 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: ""
                color: root.ramUsage > 80 ? theme.red : root.ramUsage > 50 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 5
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: root.swapUsage + "%"
                color: root.swapUsage > 50 ? theme.red : root.swapUsage > 20 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
                visible: root.swapUsage > 0
            }

            Text {
                text: "󰾵"
                color: root.swapUsage > 50 ? theme.red : root.swapUsage > 20 ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 1
                font.weight: Font.Medium
                font.family: theme.font
                visible: root.swapUsage > 0
            }
        }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }

    Process {
        id: cpuProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/cpu-usage.sh"]
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
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
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
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
        running: !root.dataSource
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            memProc.running = true;
        }
    }
}
