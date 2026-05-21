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

        function closeOtherPanels(name) {
            if (name !== "notif") notifPanelOpen = false
            if (name !== "mpris") mprisPanelOpen = false
            if (name !== "volume") volumePanelOpen = false
            if (name !== "weather") weatherPanelOpen = false
            if (name !== "calendar") calendarPanelOpen = false
            if (name !== "sysUsage") sysUsagePanelOpen = false
            if (name !== "power") powerPanelOpen = false
        }
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
                id: powerFlagOut
                onStreamFinished: {
                    if (powerFlagOut.text.trim() === "1") {
                        g.powerPanelOpen = !g.powerPanelOpen
                        if (g.powerPanelOpen) {
                            g.activePowerScreen = Quickshell.screens[0]
                            g.closeOtherPanels("power")
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
                        g.closeOtherPanels("notif")
                        g.notifPanelOpen = !g.notifPanelOpen
                        if (g.notifPanelOpen) g.activeNotifScreen = screenScope.screenData
                    }
                    onToggleMprisPanel: {
                        g.closeOtherPanels("mpris")
                        g.mprisPanelOpen = !g.mprisPanelOpen
                        if (g.mprisPanelOpen) g.activeMprisScreen = screenScope.screenData
                    }
                    onToggleVolumePanel: {
                        g.closeOtherPanels("volume")
                        g.volumePanelOpen = !g.volumePanelOpen
                        if (g.volumePanelOpen) g.activeVolumeScreen = screenScope.screenData
                    }
                    onToggleWeatherPanel: {
                        g.closeOtherPanels("weather")
                        g.weatherPanelOpen = !g.weatherPanelOpen
                        if (g.weatherPanelOpen) g.activeWeatherScreen = screenScope.screenData
                    }
                    onToggleCalendarPanel: {
                        g.closeOtherPanels("calendar")
                        g.calendarPanelOpen = !g.calendarPanelOpen
                        if (g.calendarPanelOpen) g.activeCalendarScreen = screenScope.screenData
                    }
                    onToggleSysUsagePanel: {
                        g.closeOtherPanels("sysUsage")
                        g.sysUsagePanelOpen = !g.sysUsagePanelOpen
                        if (g.sysUsagePanelOpen) g.activeSysUsageScreen = screenScope.screenData
                    }
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
                onCloseRequested: g.notifPanelOpen = false

                NotificationPanel {
                    anchors.fill: parent
                    active: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
                    onClose: g.notifPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData
                onCloseRequested: g.mprisPanelOpen = false
                position: PanelOverlay.Position.TopCenter
                centerOffset: parent.width / 4 - 250

                MprisPanel {
                    anchors.fill: parent
                    active: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData
                    onClose: g.mprisPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.volumePanelOpen && g.activeVolumeScreen === screenScope.screenData
                onCloseRequested: g.volumePanelOpen = false

                VolumePanel {
                    anchors.fill: parent
                    active: g.volumePanelOpen && g.activeVolumeScreen === screenScope.screenData
                    onClose: g.volumePanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData
                onCloseRequested: g.weatherPanelOpen = false

                WeatherPanel {
                    anchors.fill: parent
                    active: g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData
                    onClose: g.weatherPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData
                onCloseRequested: g.calendarPanelOpen = false
                position: PanelOverlay.Position.TopCenter

                CalendarPanel {
                    anchors.fill: parent
                    active: g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData
                    onClose: g.calendarPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.sysUsagePanelOpen && g.activeSysUsageScreen === screenScope.screenData
                onCloseRequested: g.sysUsagePanelOpen = false
                rightMargin: 250

                SysUsagePanel {
                    anchors.fill: parent
                    active: g.sysUsagePanelOpen && g.activeSysUsageScreen === screenScope.screenData
                    onClose: g.sysUsagePanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.powerPanelOpen && g.activePowerScreen === screenScope.screenData
                onCloseRequested: g.powerPanelOpen = false
                position: PanelOverlay.Position.Center
                keyboardFocus: false

                PowerMenuPanel {
                    anchors.fill: parent
                    active: g.powerPanelOpen && g.activePowerScreen === screenScope.screenData
                    onClose: g.powerPanelOpen = false
                }
            }
        }
    }
}
