import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common

// Compact system stat: CPU % with a sparkline, plus thin gauges for GPU, RAM and
// swap. Everything (incl. temperature) is in the hover tooltip; click opens the
// System Usage panel.
Item {
    id: root
    property Theme theme: ThemeStore
    property var dataSource: null
    property int cpuUsage: dataSource ? dataSource.cpuUsage : 0
    property int ramUsage: dataSource ? dataSource.ramUsage : 0
    property int swapUsage: dataSource ? dataSource.swapUsage : 0
    property int gpuUsage: dataSource ? dataSource.gpuUsage : 0
    property int cpuTemp: dataSource ? dataSource.cpuTemp : 0
    signal togglePanel()

    readonly property color cpuClr: theme.severity(cpuUsage, theme.cpuLoadWarn, theme.cpuLoadCrit)

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        spacing: 8

        RowLayout {
            spacing: 4

            Text {
                text: ""   // nf-fa-microchip
                color: root.cpuClr
                font.pixelSize: theme.fontSize + 6
                font.family: theme.font
            }

            Text {
                text: root.cpuUsage + "%"
                color: root.cpuClr
                font.pixelSize: theme.fontSize - 1
                font.weight: Font.Medium
                font.family: theme.font
                Layout.minimumWidth: 28
                horizontalAlignment: Text.AlignRight
            }

            Sparkline {
                values: root.dataSource ? root.dataSource.cpuHistory : []
                tick: root.dataSource ? root.dataSource.historyTick : 0
                slots: root.dataSource ? root.dataSource.maxHistory : 30
                clr: root.cpuClr
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 32
                Layout.preferredHeight: 14
            }
        }

        RowLayout {
            spacing: 4
            Layout.alignment: Qt.AlignVCenter

            MiniMeter {
                theme: root.theme
                value: root.gpuUsage
                clr: theme.severity(root.gpuUsage, theme.cpuLoadWarn, theme.cpuLoadCrit)
            }

            MiniMeter {
                theme: root.theme
                value: root.ramUsage
                clr: theme.severity(root.ramUsage, theme.ramWarn, theme.ramCrit)
            }

            MiniMeter {
                theme: root.theme
                visible: root.swapUsage > 0
                value: root.swapUsage
                clr: theme.severity(root.swapUsage, theme.swapWarn, theme.swapCrit)
            }
        }
    }

    BarTooltip {
        target: root
        theme: root.theme
        hovered: ma.containsMouse
        text: "CPU  " + root.cpuUsage + "%" + (root.cpuTemp > 0 ? "  " + root.cpuTemp + "°C" : "")
              + "\nGPU  " + root.gpuUsage + "%"
              + "\nRAM  " + root.ramUsage + "%"
              + (root.swapUsage > 0 ? "\nSwap " + root.swapUsage + "%" : "")
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }
}
