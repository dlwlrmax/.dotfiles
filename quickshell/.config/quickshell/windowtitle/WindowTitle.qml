import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts
import qs.common

RowLayout {
    property Theme theme: Theme {}
    spacing: 8
    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

    property string _activeAppId: Hyprland.activeToplevel?.wayland?.appId ?? Hyprland.activeToplevel?.class ?? ""

    AppIcon {
        appId: _activeAppId
        size: 14
        Layout.preferredWidth: 14
        Layout.preferredHeight: 14
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        text: Hyprland.activeToplevel?.title ?? "Quickshell"
        color: theme.text
        font.pixelSize: theme.fontSize - 1
        font.bold: true
        font.family: theme.font
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        elide: Text.ElideRight
        clip: true
    }
}
