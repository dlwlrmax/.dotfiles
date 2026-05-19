import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property Theme theme: Theme {}
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
            text: root.ramPct + "%  "
            color: root.ramColor
            font.pixelSize: theme.fontSize - 1
            font.weight: Font.Medium
            font.family: theme.font
        }

        Text {
            text: root.swapPct + "% 󰾵 "
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
        onClicked: {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel()
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mem-apps.sh"]

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

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }
}
