import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property Theme theme: Theme {}
    property int notifCount: 0
    property bool dnd: false
    signal togglePanel()

    implicitWidth: iconText.implicitWidth
    implicitHeight: iconText.implicitHeight

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.dnd ? "󰂛" : ""
        color: root.notifCount > 0 ? theme.white : theme.surface1
        font.pixelSize: theme.fontSize
        font.weight: Font.Medium
        font.family: theme.font + 5
    }

    Rectangle {
        id: badge
        visible: root.notifCount > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -4
        anchors.rightMargin: -8
        width: Math.max(14, badgeText.implicitWidth + 6)
        height: 14
        radius: 7
        color: theme.red

        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.notifCount > 9 ? "9+" : root.notifCount
            color: theme.white
            font.pixelSize: 9
            font.bold: true
            font.family: theme.font
        }
    }

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
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton) {
                root.togglePanel();
            } else if (mouse.button === Qt.RightButton) {
                toggleDndProc.running = true;
            }
        }
    }

    Process {
        id: toggleDndProc
        command: ["makoctl", "mode", "-t", "dnd"]
    }
}
