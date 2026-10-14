import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    readonly property int volumeLevel: dataSource ? dataSource.volumeLevel : 0
    readonly property bool muted: dataSource ? dataSource.muted : false
    signal togglePanel()

    property string iconColor: root.muted ? theme.surface1 : (root.volumeLevel > theme.volumeCriticalLevel ? theme.volumeCriticalColor : root.volumeLevel > theme.volumeWarnLevel ? theme.volumeWarnColor : root.volumeLevel > theme.volumeElevatedLevel ? theme.volumeElevatedColor : theme.volumeNormalColor)
    property string iconText: root.muted ? "" : (root.volumeLevel > 70 ? "" : root.volumeLevel > 30 ? "" : "")
    property string textColor: root.muted ? theme.surface1 : theme.text

    property var _pendingCmd: []

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function handleVolumeWheel(wheel) {
        if (volCooldown.elapsedMs() < 100) return
        volCooldown.restart()
        // wpctl -l 1.0 clamps at 100% server-side, so fast scrolling can't
        // overshoot on a stale volumeLevel.
        if (wheel.angleDelta.y > 0) {
            root._pendingCmd = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]
            volChangeProc.running = true
        } else if (wheel.angleDelta.y < 0) {
            root._pendingCmd = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]
            volChangeProc.running = true
        }
    }

    function refreshState() {
        if (root.dataSource) root.dataSource.refresh()
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Item {
            id: iconWrapper
            implicitWidth: iconLabel.implicitWidth
            implicitHeight: iconLabel.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: iconLabel
                text: root.iconText
                color: root.iconColor
                font.pixelSize: root.theme.fontSize + 5
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleMuteProc.running = true
                onWheel: wheel => root.handleVolumeWheel(wheel)
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
                onWheel: wheel => root.handleVolumeWheel(wheel)
            }
        }
    }

    Process {
        id: toggleMuteProc
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        onRunningChanged: {
            if (!running) root.refreshState()
        }
    }

    Process {
        id: volChangeProc
        command: root._pendingCmd
        onRunningChanged: {
            if (!running) root.refreshState()
        }
    }

    ElapsedTimer {
        id: volCooldown
    }
}
