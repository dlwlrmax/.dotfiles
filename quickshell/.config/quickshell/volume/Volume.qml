import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property var dataSource: null
    property int _vol: 0
    property bool _muted: false
    readonly property int volumeLevel: dataSource ? dataSource.volumeLevel : _vol
    readonly property bool muted: dataSource ? dataSource.muted : _muted
    signal togglePanel()

    property string iconColor: root.muted ? theme.surface1 : (root.volumeLevel > 80 ? theme.red : root.volumeLevel > 50 ? theme.yellow : root.volumeLevel > 30 ? theme.peach : theme.green)
    property string iconText: root.muted ? "" : (root.volumeLevel > 70 ? "" : root.volumeLevel > 30 ? "" : "")
    property string textColor: root.muted ? theme.surface1 : theme.text

    property var _pendingCmd: []

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function refreshState() {
        if (root.dataSource) {
            root.dataSource.refresh()
        } else {
            if (!volProc.running) volProc.running = true
        }
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
                onClicked: {
                    if (!root.dataSource) root._muted = !root._muted
                    toggleMuteProc.running = true
                }
                onWheel: wheel => {
                    if (volCooldown.elapsedMs() < 30) return
                    volCooldown.restart()
                    if (wheel.angleDelta.y > 0) {
                        if (!root.dataSource) {
                            root._vol = Math.min(100, root._vol + 5)
                            root._muted = false
                        }
                        root._pendingCmd = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
                        volChangeProc.running = true
                    } else if (wheel.angleDelta.y < 0) {
                        if (!root.dataSource) {
                            root._vol = Math.max(0, root._vol - 5)
                            root._muted = false
                        }
                        root._pendingCmd = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]
                        volChangeProc.running = true
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
                    if (volCooldown.elapsedMs() < 30) return
                    volCooldown.restart()
                    if (wheel.angleDelta.y > 0) {
                        if (!root.dataSource) {
                            root._vol = Math.min(100, root._vol + 5)
                            root._muted = false
                        }
                        root._pendingCmd = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%"]
                        volChangeProc.running = true
                    } else if (wheel.angleDelta.y < 0) {
                        if (!root.dataSource) {
                            root._vol = Math.max(0, root._vol - 5)
                            root._muted = false
                        }
                        root._pendingCmd = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%"]
                        volChangeProc.running = true
                    }
                }
            }
        }
    }

    Process {
        id: volProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/volume-status.sh"]
        running: !root.dataSource

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.dataSource) return
                var output = this.text.trim()
                var parts = output.split(" ")
                if (parts.length >= 2) {
                    var vol = parseInt(parts[0])
                    if (!isNaN(vol)) {
                        if (vol > 100) {
                            clampVolProc.running = true
                            root._vol = 100
                        } else {
                            root._vol = vol
                        }
                    }
                    root._muted = parts[1] === "true"
                }
            }
        }
    }

    Timer {
        interval: 500
        running: !root.dataSource
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!volProc.running) volProc.running = true
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

    Process {
        id: clampVolProc
        command: ["pactl", "set-sink-volume", "@DEFAULT_SINK@", "100%"]
    }

    ElapsedTimer {
        id: volCooldown
    }
}
