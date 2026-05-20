//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import Quickshell.Io
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
        property bool calendarPanelOpen: false
        property var activeCalendarScreen: null
        property bool sysUsagePanelOpen: false
        property var activeSysUsageScreen: null
        property bool powerPanelOpen: false
        property var activePowerScreen: null
    }

    Item {
        id: powerTrigger

        Timer {
            id: powerPollTimer
            interval: 300
            running: true
            repeat: true
            onTriggered: {
                if (!powerFlagProc.running) powerFlagProc.running = true
            }
        }

        Process {
            id: powerFlagProc
            command: ["/bin/sh", "-c", "if [ -f /tmp/quickshell-power-toggle ]; then rm /tmp/quickshell-power-toggle; echo 1; else echo 0; fi"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (this.text.trim() === "1") {
                        g.powerPanelOpen = !g.powerPanelOpen
                        if (g.powerPanelOpen) {
                            g.activePowerScreen = Quickshell.screens[0]
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.volumePanelOpen = false
                            g.weatherPanelOpen = false
                            g.calendarPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                }
            }
        }
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
                            g.calendarPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                    onToggleMprisPanel: {
                        g.mprisPanelOpen = !g.mprisPanelOpen
                        if (g.mprisPanelOpen) {
                            g.activeMprisScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.weatherPanelOpen = false
                            g.calendarPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                    onToggleVolumePanel: {
                        g.volumePanelOpen = !g.volumePanelOpen
                        if (g.volumePanelOpen) {
                            g.activeVolumeScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.weatherPanelOpen = false
                            g.calendarPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                    onToggleWeatherPanel: {
                        g.weatherPanelOpen = !g.weatherPanelOpen
                        if (g.weatherPanelOpen) {
                            g.activeWeatherScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.volumePanelOpen = false
                            g.calendarPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                    onToggleCalendarPanel: {
                        g.calendarPanelOpen = !g.calendarPanelOpen
                        if (g.calendarPanelOpen) {
                            g.activeCalendarScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.volumePanelOpen = false
                            g.weatherPanelOpen = false
                            g.sysUsagePanelOpen = false
                        }
                    }
                    onToggleSysUsagePanel: {
                        g.sysUsagePanelOpen = !g.sysUsagePanelOpen
                        if (g.sysUsagePanelOpen) {
                            g.activeSysUsageScreen = screenScope.screenData
                            g.notifPanelOpen = false
                            g.mprisPanelOpen = false
                            g.volumePanelOpen = false
                            g.weatherPanelOpen = false
                            g.calendarPanelOpen = false
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
                    focus: true
                    Keys.onEscapePressed: g.notifPanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

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
                    focus: true
                    Keys.onEscapePressed: g.mprisPanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

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
                    focus: true
                    Keys.onEscapePressed: g.volumePanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

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
                    focus: true
                    Keys.onEscapePressed: g.weatherPanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

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

            PanelWindow {
                id: calendarWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: (g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData) || calWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(calWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > calWrapper.width ||
                            pos.y < 0 || pos.y > calWrapper.height) {
                            g.calendarPanelOpen = false;
                        }
                    }
                }

                Item {
                    id: calWrapper
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: calendarPanel.implicitWidth
                    height: calendarPanel.implicitHeight
                    opacity: 0
                    focus: true
                    Keys.onEscapePressed: g.calendarPanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

                    CalendarPanel {
                        id: calendarPanel
                        anchors.fill: parent
                        active: g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData
                        onClose: g.calendarPanelOpen = false
                    }

                    transform: Translate { id: calTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData
                        PropertyChanges { target: calWrapper; opacity: 1 }
                        PropertyChanges { target: calTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: calTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            PanelWindow {
                id: sysUsageWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: (g.sysUsagePanelOpen && g.activeSysUsageScreen === screenScope.screenData) || sysWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(sysWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > sysWrapper.width ||
                            pos.y < 0 || pos.y > sysWrapper.height) {
                            g.sysUsagePanelOpen = false;
                        }
                    }
                }

                Item {
                    id: sysWrapper
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: 250
                    width: sysUsagePanel.implicitWidth
                    height: sysUsagePanel.implicitHeight
                    opacity: 0
                    focus: true
                    Keys.onEscapePressed: g.sysUsagePanelOpen = false
                    onOpacityChanged: if (opacity > 0) forceActiveFocus()

                    SysUsagePanel {
                        id: sysUsagePanel
                        anchors.fill: parent
                        active: g.sysUsagePanelOpen && g.activeSysUsageScreen === screenScope.screenData
                        onClose: g.sysUsagePanelOpen = false
                    }

                    transform: Translate { id: sysTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.sysUsagePanelOpen && g.activeSysUsageScreen === screenScope.screenData
                        PropertyChanges { target: sysWrapper; opacity: 1 }
                        PropertyChanges { target: sysTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: sysTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            PanelWindow {
                id: powerWindow
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true
                color: "transparent"
                visible: (g.powerPanelOpen && g.activePowerScreen === screenScope.screenData) || powerWrapper.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        var pos = mapToItem(powerWrapper, mouse.x, mouse.y);
                        if (pos.x < 0 || pos.x > powerWrapper.width ||
                            pos.y < 0 || pos.y > powerWrapper.height) {
                            g.powerPanelOpen = false;
                        }
                    }
                }

                Item {
                    id: powerWrapper
                    anchors.centerIn: parent
                    width: powerMenuPanel.implicitWidth
                    height: powerMenuPanel.implicitHeight
                    opacity: 0

                    PowerMenuPanel {
                        id: powerMenuPanel
                        anchors.fill: parent
                        active: g.powerPanelOpen && g.activePowerScreen === screenScope.screenData
                        onClose: g.powerPanelOpen = false
                    }

                    transform: Translate { id: powerTranslate; y: -20 }

                    states: State {
                        name: "open"
                        when: g.powerPanelOpen && g.activePowerScreen === screenScope.screenData
                        PropertyChanges { target: powerWrapper; opacity: 1 }
                        PropertyChanges { target: powerTranslate; y: 0 }
                    }

                    transitions: Transition {
                        from: ""; to: "open"
                        reversible: true
                        ParallelAnimation {
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: powerTranslate; property: "y"; duration: 200; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }
}
