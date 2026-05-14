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

        // Hardcoded icon name mappings
        var iconMap = {
            "DBeaver": "dbeaver",
            "zen": "zen-browser",
            "Ferdium": "ferdium",
            "google-chrome": "google-chrome",
            "com.mitchellh.ghostty": "com.mitchellh.ghostty"
        };

        var iconName = iconMap[appId] || appId;
        var path = Quickshell.iconPath(iconName);
        if (path) return path;

        // Try lowercase
        path = Quickshell.iconPath(iconName.toLowerCase());
        if (path) return path;

        // Try desktop entry as last resort
        var entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.icon) {
            path = Quickshell.iconPath(entry.icon);
            if (path) return path;
        }

        return "";
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
                        sourceSize.width: 64
                        sourceSize.height: 64
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
