import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Text {
    id: root
    property Theme theme: Theme {}
    property int notifCount: 0
    property bool dnd: false

    text: root.dnd ? (root.notifCount > 0 ? "<span style='color:" + theme.red + "'></span>" : " ") : (root.notifCount > 0 ? "<span style='color:" + theme.red + "'></span>" : " ")
    color: theme.text
    font.pixelSize: theme.fontSize
    font.weight: Font.Medium

    Process {
        id: notifProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/notification-status.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var parts = output.split(" ");
                if (parts.length >= 2) {
                    var count = parseInt(parts[0]);
                    if (!isNaN(count)) root.notifCount = count;
                    root.dnd = parts[1] === "true";
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: notifProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (mouse.button === Qt.LeftButton) {
                togglePanelProc.running = true;
            } else if (mouse.button === Qt.RightButton) {
                toggleDndProc.running = true;
            }
        }
    }

    Process {
        id: togglePanelProc
        command: ["swaync-client", "--skip-wait", "--toggle-panel"]
    }

    Process {
        id: toggleDndProc
        command: ["swaync-client", "--skip-wait", "--toggle-dnd"]
    }
}
