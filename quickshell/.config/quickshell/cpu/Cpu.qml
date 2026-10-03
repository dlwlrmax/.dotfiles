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
    property int gpuUsage: dataSource ? dataSource.gpuUsage : 0
    signal togglePanel()

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

        RowLayout {
            id: row
            spacing: 4

            Text {
                text: root.cpuUsage + "%"
                color: root.cpuUsage > theme.cpuLoadCrit ? theme.red : root.cpuUsage > theme.cpuLoadWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: ""
                color: root.cpuUsage > theme.cpuLoadCrit ? theme.red : root.cpuUsage > theme.cpuLoadWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 5
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: root.gpuUsage + "%"
                color: root.gpuUsage > theme.cpuLoadCrit ? theme.red : root.gpuUsage > theme.cpuLoadWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: "󰢮"
                color: root.gpuUsage > theme.cpuLoadCrit ? theme.red : root.gpuUsage > theme.cpuLoadWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 5
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: root.ramUsage + "%"
                color: root.ramUsage > theme.ramCrit ? theme.red : root.ramUsage > theme.ramWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: ""
                color: root.ramUsage > theme.ramCrit ? theme.red : root.ramUsage > theme.ramWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize + 5
                font.weight: Font.Medium
                font.family: theme.font
            }

            Text {
                text: root.swapUsage + "%"
                color: root.swapUsage > theme.swapCrit ? theme.red : root.swapUsage > theme.swapWarn ? theme.yellow : theme.green
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
                visible: root.swapUsage > 0
            }

            Text {
                text: "󰾵"
                color: root.swapUsage > theme.swapCrit ? theme.red : root.swapUsage > theme.swapWarn ? theme.yellow : theme.green
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
        command: ["bash", theme.scriptDir + "/cpu-usage.sh"]
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
        command: ["bash", theme.scriptDir + "/mem-usage.sh"]
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

    Process {
        id: gpuProc
        command: ["bash", theme.scriptDir + "/gpu-usage.sh"]
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                var parts = this.text.trim().split(/\s+/);
                if (parts.length >= 1) {
                    var usage = parseInt(parts[0]);
                    if (!isNaN(usage)) root.gpuUsage = usage;
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
            gpuProc.running = true;
        }
    }
}
