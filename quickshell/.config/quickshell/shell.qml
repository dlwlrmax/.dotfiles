import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import QtQuick

ShellRoot {
    Instantiator {
        model: Quickshell.screens
        delegate: PanelWindow {
            screen: modelData
            anchors.top: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            exclusionMode: ExclusionMode.Auto
            implicitHeight: 44

            Bar {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                monitor: Hyprland.monitorFor(modelData)
            }
        }
    }
}
