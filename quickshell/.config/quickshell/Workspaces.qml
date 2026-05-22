import Quickshell
import Quickshell.Hyprland._Ipc
import Quickshell.Io
import QtQuick

Row {
    property Theme theme: Theme {}
    required property var monitor
    spacing: 8

    Process {
        id: wsSwitch
    }

    Repeater {
        model: Hyprland.workspaces
        delegate: Rectangle {
            required property var modelData

            visible: modelData.id > 0 && modelData.monitor?.name === monitor?.name
            implicitWidth: wsRow.implicitWidth + 20
            implicitHeight: 24
            radius: 15
            color: modelData.focused || modelData.active ? theme.blue : theme.surface0

            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text:"[ " + modelData.name + " ]"
                    color: theme.white
                    font.pixelSize: theme.fontSize
                    font.bold: true
                    font.family: theme.font
                }

                Repeater {
                    model: modelData.toplevels
                    delegate: AppIcon {
                        required property var modelData
                        appId: modelData.wayland?.appId || ""
                        size: 16
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    wsSwitch.command = [
                        "/usr/bin/hyprctl", "eval",
                        "hl.dispatch(hl.dsp.focus({ workspace = " + modelData.id + " }))"
                    ];
                    wsSwitch.startDetached();
                }
            }
        }
    }
}
