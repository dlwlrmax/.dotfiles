import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: root

    property string icon: ""
    property int level: 0
    property bool muted: false
    property int autoHideMs: 1500

    readonly property Theme theme: ThemeStore
    // "volume" (level + bar) or "mic" (mute state only)
    property string mode: "volume"
    readonly property color accentColor: mode === "mic" ? (muted ? theme.red : theme.green)
                                                        : theme.volumeColor(level, muted)

    implicitWidth: osdRow.implicitWidth + 32
    implicitHeight: osdRow.implicitHeight + 16
    opacity: 0

    property int _changeSeq: 0
    // Pipewire reports the real level a moment after start-up (and after a sink switch);
    // stay quiet for the first seconds so reloads do not flash the OSD.
    property bool _armed: false
    Timer { interval: 3000; running: true; onTriggered: root._armed = true }
    onLevelChanged: { _changeSeq++; _show() }
    onMutedChanged: { _changeSeq++; _show() }

    // Show for an event that doesn't change level/muted (e.g. microphone mute).
    function flash() { _changeSeq++; _show() }

    function _show() {
        if (!_armed) return
        var seq = _changeSeq
        root.opacity = 1.0
        hideTimer.restart()
        hideTimer._activeSeq = seq
    }

    Timer {
        id: hideTimer
        property int _activeSeq: 0
        interval: root.autoHideMs
        onTriggered: {
            if (_activeSeq === root._changeSeq) {
                root.opacity = 0.0
            }
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: osdCard
        anchors.fill: parent
        radius: theme.radiusXl
        color: root.theme.panelColorSolid
        border.width: 1
        border.color: root.theme.surface1

        RowLayout {
            id: osdRow
            anchors.centerIn: parent
            spacing: 10

            Text {
                text: root.icon
                color: root.mode === "mic" || !root.muted ? root.accentColor : root.theme.overlay0
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize + 8
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 8
                Layout.alignment: Qt.AlignVCenter
                radius: theme.radiusSm
                color: root.theme.surface1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: root.mode === "mic" ? (root.muted ? 0 : parent.width) : parent.width * Math.min(1, root.level / 100.0)
                    radius: theme.radiusSm
                    color: root.accentColor
                }
            }

            Text {
                text: root.mode === "mic" ? (root.muted ? "Mic off" : "Mic on") : (root.muted ? "Muted" : root.level + "%")
                color: root.mode !== "mic" && root.muted ? root.theme.overlay0 : root.theme.text
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignVCenter
                Layout.minimumWidth: 46
            }
        }
    }
}
