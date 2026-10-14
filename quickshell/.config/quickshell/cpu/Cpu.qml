import QtQuick
import QtQuick.Layouts
import Quickshell
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
}
