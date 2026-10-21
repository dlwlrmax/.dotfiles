import Quickshell
import Quickshell.Hyprland._Ipc
import QtQuick
import QtQuick.Layouts
import qs.common

RowLayout {
    id: root
    property Theme theme: ThemeStore
    spacing: 8
    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter

    readonly property var tl: Hyprland.activeToplevel
    property string _activeAppId: tl?.wayland?.appId ?? tl?.class ?? ""
    readonly property string title: tl?.title ?? "Quickshell"

    AppIcon {
        appId: root._activeAppId
        size: 16
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        Layout.alignment: Qt.AlignVCenter
    }

    Text {
        id: titleText
        text: root.title
        color: theme.text
        font.pixelSize: theme.fontSize - 1
        font.bold: true
        font.family: theme.font
        Layout.alignment: Qt.AlignVCenter
        Layout.fillWidth: true
        elide: Text.ElideRight
        clip: true
    }

    HoverHandler { id: hover }

    // Full title and app id, only when the title is cut off or the app isn't obvious from it.
    BarTooltip {
        target: root
        theme: root.theme
        hovered: hover.hovered && root._activeAppId !== ""
        delay: 700
        text: root.title + "\n" + root._activeAppId
              + (root.tl?.workspace ? " \u00b7 workspace " + root.tl.workspace.name : "")
    }
}
