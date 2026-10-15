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

    WheelSteps { id: wheelSteps }

    // Hard containment: layout squeeze must never paint over neighbors.
    clip: true
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight
    Layout.alignment: Qt.AlignVCenter

    function handleVolumeWheel(wheel) {
        var steps = wheelSteps.feed(wheel.angleDelta.y)
        if (steps && root.dataSource) root.dataSource.stepVolume(steps)
    }

    // Same as Super+Ctrl+A: next physical output, streams follow, notifies.
    function cycleOutput() {
        if (root.dataSource) root.dataSource.cycleSink()
    }

    // ── Hover tooltip ───────────────────────────────────────
    // Device name comes live from Pipewire; EasyEffects info is fetched on hover only, never polled.

    readonly property var defaultSink: dataSource ? dataSource.sink : null
    readonly property string tipDevice: defaultSink ? (defaultSink.description || defaultSink.nickname || defaultSink.name) : ""
    property string tipEeState: ""   // "" = EasyEffects not running, "1" = bypassed, "2" = active
    property string tipPreset: ""

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered && !tipInfoProc.running) tipInfoProc.running = true
    }

    Process {
        id: tipInfoProc
        // Labeled lines so stray log output from easyeffects can't shift values.
        command: ["sh", "-c",
            "if pgrep -x easyeffects >/dev/null; then "
            + "echo \"ee=$(easyeffects -b 3 | grep -E '^[12]$' | tail -1)\"; "
            + "echo \"preset=$(easyeffects -a output | grep . | tail -1)\"; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var kv = {}
                this.text.split("\n").forEach(l => {
                    var i = l.indexOf("=")
                    if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1).trim()
                })
                root.tipEeState = kv.ee || ""
                root.tipPreset = kv.preset || ""
            }
        }
    }

    BarTooltip {
        id: tip
        target: root
        theme: root.theme
        hovered: hover.hovered

        Text {
            text: root.tipDevice || "Output device"
            color: root.theme.text
            font.pixelSize: root.theme.fontSize
            font.weight: Font.Medium
            font.family: root.theme.font
            elide: Text.ElideRight
            Layout.maximumWidth: 280
        }

        Text {
            text: root.muted ? "Muted · " + root.volumeLevel + "%" : "Volume " + root.volumeLevel + "%"
            color: root.muted ? root.theme.surface1 : root.theme.subtext0
            font.pixelSize: root.theme.fontSize - 1
            font.family: root.theme.font
        }

        RowLayout {
            visible: root.tipEeState !== ""
            spacing: 6

            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: root.tipEeState === "2" ? root.theme.green : root.theme.surface1
            }

            Text {
                text: "EasyEffects" + (root.tipPreset ? " · " + root.tipPreset : "")
                      + (root.tipEeState === "2" ? "" : " (off)")
                color: root.tipEeState === "2" ? root.theme.subtext0 : root.theme.surface1
                font.pixelSize: root.theme.fontSize - 1
                font.family: root.theme.font
                elide: Text.ElideRight
                Layout.maximumWidth: 260
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 1
            color: root.theme.surface0
        }

        Text {
            text: "Click icon: mute · Click %: panel · Middle-click: next output · Scroll: volume"
            color: root.theme.surface1
            font.pixelSize: root.theme.fontSize - 2
            font.family: root.theme.font
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
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    tip.suppressed = true
                    if (mouse.button === Qt.MiddleButton) root.cycleOutput()
                    else if (root.dataSource) root.dataSource.toggleMute()
                }
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
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: mouse => {
                    tip.suppressed = true
                    if (mouse.button === Qt.MiddleButton) root.cycleOutput()
                    else root.togglePanel()
                }
                onWheel: wheel => root.handleVolumeWheel(wheel)
            }
        }
    }
}
