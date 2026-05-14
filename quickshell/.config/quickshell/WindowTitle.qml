import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts

Text {
    property Theme theme: Theme {}
    text: Hyprland.activeToplevel?.title ?? "Quickshell"
    color: theme.text
    font.pixelSize: theme.fontSize
    font.bold: true
    font.family: theme.font
    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
}
