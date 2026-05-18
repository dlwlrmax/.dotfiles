//@ pragma UseQApplication
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
            property bool mprisPanelOpen: false

            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                color: "transparent"
                exclusionMode: ExclusionMode.Auto
                implicitHeight: 44
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"

                Bar {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    monitor: Hyprland.monitorFor(screenScope.screenData)
                    onToggleNotifPanel: {
                        screenScope.notifPanelOpen = !screenScope.notifPanelOpen
                        if (screenScope.notifPanelOpen) screenScope.mprisPanelOpen = false
                    }
                    onToggleMprisPanel: {
                        screenScope.mprisPanelOpen = !screenScope.mprisPanelOpen
                        if (screenScope.mprisPanelOpen) screenScope.notifPanelOpen = false
                    }
                }
            }

            PanelWindow {
                id: notifWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: screenScope.notifPanelOpen || panelWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var panelPos = mapToItem(panelWrapper, mouse.x, mouse.y);
                        if (panelPos.x < 0 || panelPos.x > panelWrapper.width ||
                            panelPos.y < 0 || panelPos.y > panelWrapper.height) {
                            screenScope.notifPanelOpen = false;
                        }
                    }
                }

                Item {
                    id: panelWrapper
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    width: notifPanel.implicitWidth
                    height: notifPanel.implicitHeight
                    opacity: 0

                    NotificationPanel {
                        id: notifPanel
                        anchors.fill: parent
                        active: screenScope.notifPanelOpen
                        onClose: screenScope.notifPanelOpen = false
                    }

                    transform: Translate { id: panelTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: screenScope.notifPanelOpen
                        PropertyChanges { target: panelWrapper; opacity: 1 }
                        PropertyChanges { target: panelTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: panelTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            PanelWindow {
                id: mprisWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: screenScope.mprisPanelOpen || mprisWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(mprisWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > mprisWrapper.width ||
                            pos.y < 0 || pos.y > mprisWrapper.height) {
                            screenScope.mprisPanelOpen = false;
                        }
                    }
                }

                Item {
                    id: mprisWrapper
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.width / 4 - 200
                    width: mprisPanel.implicitWidth
                    height: mprisPanel.implicitHeight
                    opacity: 0

                    MprisPanel {
                        id: mprisPanel
                        anchors.fill: parent
                        active: screenScope.mprisPanelOpen
                        onClose: screenScope.mprisPanelOpen = false
                    }

                    transform: Translate { id: mprisTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: screenScope.mprisPanelOpen
                        PropertyChanges { target: mprisWrapper; opacity: 1 }
                        PropertyChanges { target: mprisTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: mprisTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
