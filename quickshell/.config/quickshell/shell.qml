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
            exclusionMode: ExclusionMode.Auto
            implicitHeight: 32

            Bar {
                anchors.fill: parent
                monitor: Hyprland.monitorFor(modelData)
            }
        }
    }
}
