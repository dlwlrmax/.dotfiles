import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts

RowLayout {
    property Theme theme: Theme {}
    spacing: 8
    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

    property string _activeAppId: Hyprland.activeToplevel?.wayland?.appId ?? Hyprland.activeToplevel?.class ?? ""
    property string _appIcon: {
        var appId = _activeAppId;
        if (!appId) return "";

        var iconMap = {
            "DBeaver": "dbeaver",
            "zen": "zen-browser",
            "Ferdium": "ferdium",
            "google-chrome": "google-chrome",
            "com.mitchellh.ghostty": "com.mitchellh.ghostty",
            "Thunar": "org.xfce.thunar"
        };

        var iconName = iconMap[appId] || appId;

        var entry = DesktopEntries.heuristicLookup(appId);
        var entryIcon = entry && entry.icon ? entry.icon : "";

        var fallback = entryIcon || "application-x-executable";
        return Quickshell.iconPath(iconName, fallback);
    }

    Image {
        source: _appIcon
        visible: source.toString().length > 0
        width: 12
        height: 12
        Layout.preferredWidth: 12
        Layout.preferredHeight: 12
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 12
        sourceSize.height: 12
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        text: Hyprland.activeToplevel?.title ?? "Quickshell"
        color: theme.text
        font.pixelSize: theme.fontSize
        font.bold: true
        font.family: theme.font
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        elide: Text.ElideRight
        clip: true
    }
}
