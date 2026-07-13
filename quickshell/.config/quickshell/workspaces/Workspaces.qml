import Quickshell
import Quickshell.Hyprland._Ipc
import Quickshell.Io
import QtQuick
import qs.common

Row {
    property Theme theme: Theme {}
    required property var monitor
    spacing: 8

    // Guard rapid workspace switching (prevents Process reuse race).
    property bool _switching: false

    Process {
        id: wsSwitch
    }

    Timer {
        id: wsGuardTimer
        interval: 200
        onTriggered: _switching = false
    }

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            id: wsDelegate
            required property var modelData

            visible: wsDelegate.modelData.id > 0 && wsDelegate.modelData.monitor?.name === monitor?.name
            implicitWidth: wsRow.implicitWidth + 20
            implicitHeight: 24
            radius: 15
            color: wsDelegate.modelData.focused || wsDelegate.modelData.active ? theme.blue : theme.surface0

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "[ " + wsDelegate.modelData.name + " ]"
                    color: theme.white
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                }

                Repeater {
                    model: wsDelegate.modelData.toplevels
                    delegate: AppIcon {
                        id: topLevelDelegate
                        required property var modelData
                        appId: topLevelDelegate.modelData.wayland?.appId || ""
                        size: 16
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (_switching) return
                    _switching = true
                    wsSwitch.command = [
                        "/usr/bin/hyprctl", "eval",
                        "hl.dispatch(hl.dsp.focus({ workspace = " + wsDelegate.modelData.id + " }))"
                    ];
                    wsSwitch.startDetached();
                    wsGuardTimer.restart()
                }
            }
        }
    }
}
