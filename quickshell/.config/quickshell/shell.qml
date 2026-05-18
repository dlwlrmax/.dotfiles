//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import QtQuick

ShellRoot {
    id: shell

    QtObject {
        id: g
        property bool notifPanelOpen: false
        property var activeNotifScreen: null
        property bool mprisPanelOpen: false
        property var activeMprisScreen: null
        property bool volumePanelOpen: false
        property var activeVolumeScreen: null
        property bool weatherPanelOpen: false
        property var activeWeatherScreen: null
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Item {
            id: screenScope
            property var screenData: modelData

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
                        g.notifPanelOpen = !g.notifPanelOpen
                        if (g.notifPanelOpen) {
                            g.activeNotifScreen = screenScope.screenData
                            g.mprisPanelOpen = false
                            g.weatherPanelOpen = false
                        }
                    }
                    onToggleMprisPanel: {
                        g.mprisPanelOpen = !g.mprisPanelOpen
                        if (g.mprisPanelOpen) {
                            g.activeMprisScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.weatherPanelOpen = false
                        }
                    }
                    onToggleVolumePanel: {
                        g.volumePanelOpen = !g.volumePanelOpen
                        if (g.volumePanelOpen) {
                            g.activeVolumeScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.weatherPanelOpen = false
                        }
                    }
                    onToggleWeatherPanel: {
                        g.weatherPanelOpen = !g.weatherPanelOpen
                        if (g.weatherPanelOpen) {
                            g.activeWeatherScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.volumePanelOpen = false
                        }
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
                visible: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData || panelWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var panelPos = mapToItem(panelWrapper, mouse.x, mouse.y);
                        if (panelPos.x < 0 || panelPos.x > panelWrapper.width ||
                            panelPos.y < 0 || panelPos.y > panelWrapper.height) {
                            g.notifPanelOpen = false;
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
                        active: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
                        onClose: g.notifPanelOpen = false
                    }

                    transform: Translate { id: panelTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
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
                visible: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData || mprisWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(mprisWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > mprisWrapper.width ||
                            pos.y < 0 || pos.y > mprisWrapper.height) {
                            g.mprisPanelOpen = false;
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
                        active: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData
                        onClose: g.mprisPanelOpen = false
                    }

                    transform: Translate { id: mprisTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData
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

            PanelWindow {
                id: volumeWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: g.volumePanelOpen && g.activeVolumeScreen === screenScope.screenData || volWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(volWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > volWrapper.width ||
                            pos.y < 0 || pos.y > volWrapper.height) {
                            g.volumePanelOpen = false;
                        }
                    }
                }

                Item {
                    id: volWrapper
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    width: volumePanel.implicitWidth
                    height: volumePanel.implicitHeight
                    opacity: 0

                    VolumePanel {
                        id: volumePanel
                        anchors.fill: parent
                        active: g.volumePanelOpen && g.activeVolumeScreen === screenScope.screenData
                        onClose: g.volumePanelOpen = false
                    }

                    transform: Translate { id: volTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.volumePanelOpen && g.activeVolumeScreen === screenScope.screenData
                        PropertyChanges { target: volWrapper; opacity: 1 }
                        PropertyChanges { target: volTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: volTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            PanelWindow {
                id: weatherWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: (g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData) || weatherWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(weatherWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > weatherWrapper.width ||
                            pos.y < 0 || pos.y > weatherWrapper.height) {
                            g.weatherPanelOpen = false;
                        }
                    }
                }

                Item {
                    id: weatherWrapper
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    width: weatherPanel.implicitWidth
                    height: weatherPanel.implicitHeight
                    opacity: 0

                    WeatherPanel {
                        id: weatherPanel
                        anchors.fill: parent
                        active: g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData
                        onClose: g.weatherPanelOpen = false
                    }

                    transform: Translate { id: weatherTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData
                        PropertyChanges { target: weatherWrapper; opacity: 1 }
                        PropertyChanges { target: weatherTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: weatherTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
