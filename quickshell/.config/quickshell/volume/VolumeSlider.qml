import QtQuick
import QtQuick.Layouts
import qs.common

// Volume bar + percent label bound to a Pipewire node (sink, source or stream).
// Drag or click to set, scroll to step 5%. Writes go straight to Pipewire.
Item {
    id: s
    property Theme theme: ThemeStore
    property var node: null              // PwNode; must be tracked by a PwObjectTracker
    property color fillColor: theme.mauve

    readonly property bool ready: !!(node && node.audio)
    readonly property bool muted: ready && node.audio.muted
    readonly property real level: ready ? node.audio.volume : 0
    readonly property real shown: dragArea.dragging ? _dragVal : level

    property real _dragVal: 0
    WheelSteps { id: wheelSteps }

    implicitHeight: label.implicitHeight

    // Drag/click: 0..100%. (Wheel goes through VolumeStep, which keeps boosted levels.)
    function setVolume(v) {
        if (ready) node.audio.volume = Math.max(0, Math.min(1, v))
    }

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            id: track
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: s.theme.surface0
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: 3
                color: s.muted ? s.theme.surface1 : s.fillColor
                width: parent.width * Math.min(1, s.shown)
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                property bool dragging: false

                function valueAt(x) { return Math.max(0, Math.min(1, (x - 6) / track.width)) }

                onPressed: mouse => {
                    s._dragVal = valueAt(mouse.x)
                    dragging = true
                    s.setVolume(s._dragVal)
                }
                onPositionChanged: mouse => {
                    if (!dragging) return
                    s._dragVal = valueAt(mouse.x)
                    s.setVolume(s._dragVal)
                }
                onReleased: dragging = false
                onCanceled: dragging = false

                onWheel: wheel => {
                    var steps = wheelSteps.feed(wheel.angleDelta.y)
                    if (steps && s.ready) s.node.audio.volume = VolumeStep.target(s.level, steps)
                }
            }
        }

        Text {
            id: label
            text: Math.round(s.shown * 100) + "%"
            color: s.muted ? s.theme.overlay0 : s.theme.subtext0
            font.pixelSize: s.theme.fontSize - 1
            font.family: s.theme.font
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 40
        }
    }
}
