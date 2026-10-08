import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    property int ramPct: 0
    property int swapPct: 0
    signal togglePanel()

    property string ramColor: root.ramPct > 80 ? theme.red : root.ramPct > 50 ? theme.yellow : theme.green
    property string swapColor: root.swapPct > 50 ? theme.red : root.swapPct > 20 ? theme.yellow : theme.green

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        spacing: 8

        Text {
            text: root.ramPct + "% \uE7C5 "
            color: root.ramColor
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        Text {
            text: root.swapPct + "% \uF0BD "
            color: root.swapColor
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
            visible: root.swapPct > 0
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
        id: fetchProc
        command: ["bash", theme.scriptDir + "/mem-apps.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text);
                    root.ramPct = data.ram.pct || 0;
                    root.swapPct = data.swap ? (data.swap.pct || 0) : 0;
                } catch (e) {
                    console.log("Failed to parse mem-apps:", e);
                }
            }
        }
    }

    // Only poll while explicitly activated. This standalone widget is currently
    // unused (Bar renders cpu/Cpu.qml); leaving it always-on caused a dead 2s
    // mem-apps.sh poll. Matches the active-gated sibling SysUsagePanel.
    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
