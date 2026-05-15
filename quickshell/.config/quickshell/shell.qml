import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import QtQuick

ShellRoot {
    Instantiator {
        model: Quickshell.screens
        delegate: Item {
            id: screenScope
            property var screenData: modelData
            property bool notifPanelOpen: false

            PanelWindow {
                screen: screenScope.screenData
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
                    monitor: Hyprland.monitorFor(screenScope.screenData)
                    onToggleNotifPanel: screenScope.notifPanelOpen = !screenScope.notifPanelOpen
                }
            }

            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                anchors.right: true
                color: "transparent"
                visible: screenScope.notifPanelOpen
                implicitWidth: 360
                implicitHeight: notifPanel.implicitHeight
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                margins.top: 50
                margins.right: 10

                NotificationPanel {
                    id: notifPanel
                    anchors.fill: parent
                    active: screenScope.notifPanelOpen
                    onClose: screenScope.notifPanelOpen = false
                }
            }
        }
    }
}
