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

    function iconForApp(appId) {
        if (!appId) return "";

        var iconMap = {
            "DBeaver": "dbeaver",
            "zen": "zen-browser",
            "Ferdium": "ferdium",
            "google-chrome": "google-chrome",
            "com.mitchellh.ghostty": "com.mitchellh.ghostty",
            "Thunar": "org.xfce.thunar",
            "com.stremio.stremio": "com.stremio.Stremio"
        };

        var iconName = iconMap[appId] || appId;
        return Quickshell.iconPath(iconName, "image://icon/application-x-executable");
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
                    delegate: Image {
                        required property var modelData
                        width: 16
                        height: 16
                        antialiasing: true
                        smooth: true
                        mipmap: true
                        fillMode: Image.PreserveAspectFit
                        sourceSize.width: 48
                        sourceSize.height: 48
                        source: iconForApp(modelData.wayland?.appId)
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
