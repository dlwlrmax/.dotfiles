import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property int notifCount: dataSource ? dataSource.count : 0
    property bool dnd: dataSource ? dataSource.dnd : false
    property var dataSource: null
    signal togglePanel()

    implicitWidth: iconText.implicitWidth
    implicitHeight: iconText.implicitHeight

    Text {
        id: iconText
        anchors.centerIn: parent
        text: root.dnd ? "\uF09B" : "\uF0F3"
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

    // Fallback poll when no shared dataSource
    Process {
        id: notifProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mako-notifs.sh"]
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                var output = this.text.trim();
                try {
                    var data = JSON.parse(output)
                    root.notifCount = data.count || 0
                    root.dnd = data.dnd === true
                } catch (e) {}
            }
        }

        onRunningChanged: {
            if (!running && !root.dataSource)
                pollTimer.restart()
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        running: !root.dataSource
        repeat: true
        triggeredOnStart: !root.dataSource
        onTriggered: {
            if (!root.dataSource && !notifProc.running) notifProc.running = true
        }
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
