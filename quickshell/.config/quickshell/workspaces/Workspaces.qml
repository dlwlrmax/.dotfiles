import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Controls
import qs.common

// Workspace buttons for one monitor.
//   focused (keyboard here)        blue
//   visible on the other monitor   blue outline
//   new window opened unseen       mauve   — cleared on visit / when it closes
//   app wants attention (urgent)   peach   — cleared by Hyprland on focus
// Left click: go there. Right click: send the focused window there (stay put).
// Wheel: previous/next workspace on this monitor. Hover: window titles.
Row {
    id: root
    property Theme theme: Theme {}
    required property var monitor
    spacing: 8

    // Wheel: step through this monitor's workspaces (wraps).
    property real _wheelAcc: 0
    Timer { id: wheelReset; interval: 400; onTriggered: root._wheelAcc = 0 }
    function wheelStep(deltaY) {
        _wheelAcc += deltaY
        wheelReset.restart()                    // a stale half-notch must not count later
        if (Math.abs(_wheelAcc) < 120) return   // one notch; smooths hi-res wheels/touchpads
        var dir = _wheelAcc > 0 ? -1 : 1        // wheel up = previous
        _wheelAcc = 0
        var ids = [], cur = -1
        var list = Hyprland.workspaces.values
        for (var i = 0; i < list.length; i++) {
            var w = list[i]
            if (w.id > 0 && w.monitor?.name === monitor?.name) {
                ids.push(w.id)
                if (w.active) cur = w.id
            }
        }
        if (ids.length < 2) return
        ids.sort(function(a, b) { return a - b })
        var idx = ids.indexOf(cur)
        var next = ids[(idx + dir + ids.length) % ids.length]
        Hyprland.dispatch("hl.dsp.focus({ workspace = " + next + " })")
    }

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            id: wsDelegate
            required property var modelData

            // The Repeater sees every workspace; only this monitor's are shown,
            // and only those build icons/titles.
            readonly property bool onMonitor: modelData.id > 0 && modelData.monitor?.name === monitor?.name
            readonly property bool focusedWs: modelData.focused
            readonly property bool current: modelData.focused || modelData.active
            readonly property bool urgent: !current && modelData.urgent
            readonly property bool fresh: !current && WorkspaceAttention.has(modelData.name)

            // One icon per app with a count: [{ appId, count }] in first-seen order.
            readonly property var apps: {
                if (!onMonitor) return []
                var tl = modelData.toplevels?.values ?? []
                var order = [], counts = {}
                for (var i = 0; i < tl.length; i++) {
                    var id = tl[i].wayland?.appId || ""
                    if (counts[id] === undefined) { counts[id] = 0; order.push(id) }
                    counts[id]++
                }
                return order.map(function(id) { return { appId: id, count: counts[id] } })
            }
            // Only while hovered: window titles change constantly (browsers,
            // terminals), and the short-circuit drops those dependencies otherwise.
            readonly property string titles: {
                if (!wsMouse.containsMouse) return ""
                var tl = modelData.toplevels?.values ?? []
                return tl.map(function(t) { return t.title || t.wayland?.appId || "?" }).join("\n")
            }

            onCurrentChanged: if (current) WorkspaceAttention.clear(modelData.name)

            visible: onMonitor
            implicitWidth: wsRow.implicitWidth + 20
            implicitHeight: 24
            radius: 15
            // fresh wins over urgent: many apps request activation as they start,
            // which Hyprland flags urgent on a hidden workspace. Peach is for
            // windows that were already there and later ask for attention.
            color: focusedWs ? theme.blue
                 : fresh ? theme.mauve
                 : urgent ? theme.red
                 : theme.surface0
            // Visible on its monitor but the keyboard is on the other one.
            border.width: current && !focusedWs ? 2 : 0
            border.color: theme.blue

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "[ " + wsDelegate.modelData.name + " ]"
                    color: wsDelegate.urgent || wsDelegate.fresh ? theme.crust : theme.white
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                }

                Repeater {
                    model: wsDelegate.apps
                    delegate: Row {
                        required property var modelData
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter

                        AppIcon {
                            appId: modelData.appId
                            size: 16
                        }
                        Text {
                            visible: modelData.count > 1
                            text: modelData.count
                            anchors.bottom: parent.bottom
                            color: wsDelegate.urgent || wsDelegate.fresh ? theme.crust : theme.white
                            font.pixelSize: theme.fontSize - 3
                            font.bold: true
                            font.family: theme.font
                        }
                    }
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    var id = wsDelegate.modelData.id
                    if (!Number.isInteger(id)) return
                    if (mouse.button === Qt.RightButton)
                        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + id + ", follow = false })")
                    else
                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
                }
                onWheel: wheel => root.wheelStep(wheel.angleDelta.y)
            }

            ToolTip.visible: wsMouse.containsMouse && wsDelegate.titles !== ""
            ToolTip.delay: 600
            ToolTip.text: wsDelegate.titles
        }
    }
}
