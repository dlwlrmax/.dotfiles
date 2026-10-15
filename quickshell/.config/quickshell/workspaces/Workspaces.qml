import Quickshell
import Quickshell.Hyprland._Ipc
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.common

// Workspace buttons for one monitor.
//   focused (keyboard here)        blue
//   visible on the other monitor   blue outline
//   new window opened unseen       mauve   — cleared on visit / when it closes
//   app wants attention (urgent)   peach   — cleared by Hyprland on focus
// Left click: go there. Right click: send the focused window there (stay put).
// Wheel: previous/next workspace on this monitor. Hover: window previews.
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
            // Toplevel objects, only while the tooltip is open: live previews must not run
            // for a suppressed/quiet tooltip. The list only changes when windows open or
            // close; each card binds its own title, so title churn doesn't rebuild cards.
            readonly property var windows: wsTip.open ? (modelData.toplevels?.values ?? []) : []
            readonly property string status: focusedWs ? "focused"
                : current ? "shown, keyboard on other monitor"
                : fresh ? "new window"
                : urgent ? "needs attention"
                : ""

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
                    wsTip.suppressed = true
                    if (mouse.button === Qt.RightButton)
                        Hyprland.dispatch("hl.dsp.window.move({ workspace = " + id + ", follow = false })")
                    else
                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
                }
                onWheel: wheel => root.wheelStep(wheel.angleDelta.y)
            }

            BarTooltip {
                id: wsTip
                target: wsDelegate
                theme: root.theme
                hovered: wsMouse.containsMouse
                delay: 500

                RowLayout {
                    spacing: 6
                    Text {
                        text: "Workspace " + wsDelegate.modelData.name
                        color: theme.text
                        font.pixelSize: theme.fontSize
                        font.weight: Font.Medium
                        font.family: theme.font
                    }
                    Text {
                        visible: wsDelegate.status !== ""
                        text: "· " + wsDelegate.status
                        color: wsDelegate.focusedWs || wsDelegate.current ? theme.blue
                             : wsDelegate.fresh ? theme.mauve
                             : theme.red
                        font.pixelSize: theme.fontSize - 1
                        font.family: theme.font
                    }
                }

                // One card per window: live preview + icon + title. Built only while
                // hovered (windows is empty otherwise).
                GridLayout {
                    visible: wsDelegate.windows.length > 0
                    columns: Math.min(3, Math.max(1, wsDelegate.windows.length))
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: wsDelegate.windows
                        delegate: ColumnLayout {
                            id: card
                            required property var modelData   // HyprlandToplevel
                            readonly property string appId: modelData.wayland?.appId || ""
                            spacing: 4
                            Layout.preferredWidth: 200
                            Layout.alignment: Qt.AlignTop

                            Rectangle {
                                Layout.preferredWidth: 200
                                Layout.preferredHeight: 120
                                radius: 6
                                color: theme.mantle
                                clip: true

                                ScreencopyView {
                                    id: preview
                                    anchors.centerIn: parent
                                    captureSource: modelData.wayland ?? null
                                    // A one-shot captureFrame() on creation fails ("no recording
                                    // context is ready"); stream until the first frame lands, then
                                    // stop, so each window costs one frame, not a live feed.
                                    live: !hasContent
                                    constraintSize: Qt.size(200, 120)
                                }

                                // Until (or unless) the snapshot arrives
                                AppIcon {
                                    anchors.centerIn: parent
                                    visible: !preview.hasContent
                                    appId: card.appId
                                    size: 32
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Layout.maximumWidth: 200
                                AppIcon {
                                    appId: card.appId
                                    size: 14
                                    Layout.preferredWidth: 14
                                    Layout.preferredHeight: 14
                                }
                                Text {
                                    text: modelData.title || card.appId || "?"
                                    color: theme.subtext0
                                    font.pixelSize: theme.fontSize - 2
                                    font.family: theme.font
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: wsDelegate.windows.length === 0
                    text: "No windows"
                    color: theme.surface1
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    implicitHeight: 1
                    color: theme.surface0
                }

                Text {
                    text: "Click: go · Right-click: move window here · Scroll: switch"
                    color: theme.surface1
                    font.pixelSize: theme.fontSize - 2
                    font.family: theme.font
                }
            }
        }
    }
}
