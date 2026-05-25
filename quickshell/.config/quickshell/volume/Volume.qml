import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property int volumeLevel: 0
    property bool muted: false
    signal togglePanel()

    property string iconColor: root.muted ? theme.surface1 : (root.volumeLevel > 80 ? theme.red : root.volumeLevel > 50 ? theme.yellow : root.volumeLevel > 30 ? theme.peach : theme.green)
    property string iconText: root.muted ? "" : (root.volumeLevel > 70 ? "" : root.volumeLevel > 30 ? "" : "")
    property string textColor: root.muted ? theme.surface1 : theme.text

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Item {
            id: iconWrapper
            implicitWidth: iconText.implicitWidth
            implicitHeight: iconText.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: iconText
                text: root.iconText
                color: root.iconColor
                font.pixelSize: root.theme.fontSize + 5
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleMuteProc.running = true
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        volUpProc.running = true;
                    } else if (wheel.angleDelta.y < 0) {
                        volDownProc.running = true;
                    }
                }
            }
        }

        Item {
            id: numberWrapper
            implicitWidth: numberText.implicitWidth
            implicitHeight: numberText.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: numberText
                text: root.volumeLevel + "%"
                color: root.textColor
                font.pixelSize: root.theme.fontSize - 1
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePanel()
                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0) {
                        volUpProc.running = true;
                    } else if (wheel.angleDelta.y < 0) {
                        volDownProc.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: volProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/volume-status.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var parts = output.split(" ");
                if (parts.length >= 2) {
                    var vol = parseInt(parts[0]);
                    if (!isNaN(vol)) root.volumeLevel = vol;
                    root.muted = parts[1] === "true";
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: volProc.running = true
    }

    Process {
        id: toggleMuteProc
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        onRunningChanged: {
            if (!running) refreshTimer.start();
        }
    }

    Process {
        id: volUpProc
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
        onRunningChanged: {
            if (!running) refreshTimer.start();
        }
    }

    Process {
        id: volDownProc
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]
        onRunningChanged: {
            if (!running) refreshTimer.start();
        }
    }

    Timer {
        id: refreshTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: volProc.running = true
    }
}
