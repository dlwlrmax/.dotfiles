//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import Quickshell.Io
import QtQuick
import qs.notification
import qs.mpris
import qs.volume
import qs.weather
import qs.calendar
import qs.sysusage
import qs.power
import qs.battery
import qs.kdeconnect  // KDEConnect.qml, KDEConnectPanel.qml

ShellRoot {
    id: shell

    QtObject {
        id: g
        property bool notifPanelOpen: false
        property var activeNotifScreen: null
        property bool mprisPanelOpen: false
        property var activeMprisScreen: null
        property int mprisWidgetCenterX: 0
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
        property bool batteryPanelOpen: false
        property var activeBatteryScreen: null
        property int batteryWidgetCenterX: 0
        property bool kdePanelOpen: false
        property var activeKdeScreen: null
        property int kdeWidgetCenterX: 0

        function closeOtherPanels(name) {
            if (name !== "notif") notifPanelOpen = false
            if (name !== "mpris") mprisPanelOpen = false
            if (name !== "volume") volumePanelOpen = false
            if (name !== "weather") weatherPanelOpen = false
            if (name !== "calendar") calendarPanelOpen = false
            if (name !== "sysUsage") sysUsagePanelOpen = false
            if (name !== "power") powerPanelOpen = false
            if (name !== "battery") batteryPanelOpen = false
            if (name !== "kde") kdePanelOpen = false
        }
    }

    // Shared KDE Connect data model (inline, not separate type — avoids hot-reload module registry bug)
    Item {
        id: kdeData
        property var devices: []
        property var device: devices.length > 0 ? devices[0] : null
        property bool anyConnected: false

        Process {
            id: fetchProc
            command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/kdeconnect.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    console.log("KDEConnectData: stream complete")
                    try {
                        var data = JSON.parse(this.text.trim())
                        console.log("KDEConnectData: got", data.devices ? data.devices.length : 0, "devices")
                        kdeData.devices = data.devices || []
                        kdeData.anyConnected = data.anyConnected || false
                    } catch (e) {
                        console.log("KDEConnectData parse error:", e)
                    }
                }
            }
        }

        Timer {
            interval: 5000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!fetchProc.running) fetchProc.running = true
            }
        }

        onDevicesChanged: console.log("kdeData devices changed: count=", devices.length, "device=", device ? device.name + " bat=" + device.battery : "null")
        onAnyConnectedChanged: console.log("kdeData anyConnected=", anyConnected)

        Component.onCompleted: {
            console.log("KDEConnectData: completed, starting fetchProc")
            fetchProc.running = true
        }
    }

    // Shared notification data (single poll for bar + panel)
    Item {
        id: notifData
        property int count: 0
        property bool dnd: false
        property var activeNotifs: []
        property var historyNotifs: []

        Process {
            id: notifFetchProc
            command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/mako-notifs.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(this.text.trim())
                        notifData.count = data.count || 0
                        notifData.dnd = data.dnd === true
                        notifData.activeNotifs = data.active || []
                        notifData.historyNotifs = data.history || []
                    } catch (e) {
                        console.log("notifData parse error:", e)
                    }
                }
            }
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!notifFetchProc.running) notifFetchProc.running = true
            }
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
                    id: barItem
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    monitor: Hyprland.monitorFor(screenScope.screenData)
                    kdeDataSource: kdeData
                    notifDataSource: notifData

                    onToggleNotifPanel: {
                        g.closeOtherPanels("notif")
                        g.notifPanelOpen = !g.notifPanelOpen
                        if (g.notifPanelOpen) g.activeNotifScreen = screenScope.screenData
                    }
                    onToggleMprisPanel: centerX => {
                        g.closeOtherPanels("mpris")
                        g.mprisPanelOpen = !g.mprisPanelOpen
                        if (g.mprisPanelOpen) {
                            g.activeMprisScreen = screenScope.screenData
                            g.mprisWidgetCenterX = centerX
                        }
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
                    onToggleKdePanel: centerX => {
                        g.closeOtherPanels("kde")
                        g.kdePanelOpen = !g.kdePanelOpen
                        if (g.kdePanelOpen) {
                            g.activeKdeScreen = screenScope.screenData
                            g.kdeWidgetCenterX = centerX
                        }
                    }
                    onToggleBatteryPanel: centerX => {
                        g.closeOtherPanels("battery")
                        g.batteryPanelOpen = !g.batteryPanelOpen
                        if (g.batteryPanelOpen) {
                            g.activeBatteryScreen = screenScope.screenData
                            g.batteryWidgetCenterX = centerX
                        }
                    }
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
                onCloseRequested: g.notifPanelOpen = false
                topMargin: 44

                NotificationPanel {
                    anchors.fill: parent
                    active: g.notifPanelOpen && g.activeNotifScreen === screenScope.screenData
                    dataSource: notifData
                    onClose: g.notifPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.mprisPanelOpen && g.activeMprisScreen === screenScope.screenData
                onCloseRequested: g.mprisPanelOpen = false
                topMargin: 44
                position: PanelOverlay.Position.TopCenter
                centerOffset: g.mprisWidgetCenterX - screenScope.screenData.width / 2

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
                topMargin: 44

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
                topMargin: 44

                WeatherPanel {
                    anchors.fill: parent
                    active: g.weatherPanelOpen && g.activeWeatherScreen === screenScope.screenData
                    onClose: g.weatherPanelOpen = false
                    onBarRefreshRequested: {
                        if (barItem && barItem.weatherWidget)
                            barItem.weatherWidget.refresh()
                    }
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.calendarPanelOpen && g.activeCalendarScreen === screenScope.screenData
                onCloseRequested: g.calendarPanelOpen = false
                topMargin: 44
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
                topMargin: 44
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

                PowerMenuPanel {
                    anchors.fill: parent
                    active: g.powerPanelOpen && g.activePowerScreen === screenScope.screenData
                    onClose: g.powerPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.kdePanelOpen && g.activeKdeScreen === screenScope.screenData
                onCloseRequested: g.kdePanelOpen = false
                topMargin: 44
                position: PanelOverlay.Position.TopCenter
                centerOffset: g.kdeWidgetCenterX - screenScope.screenData.width / 2

                KDEConnectPanel {
                    anchors.fill: parent
                    active: g.kdePanelOpen && g.activeKdeScreen === screenScope.screenData
                    dataSource: kdeData
                    onClose: g.kdePanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.batteryPanelOpen && g.activeBatteryScreen === screenScope.screenData
                onCloseRequested: g.batteryPanelOpen = false
                topMargin: 44
                position: PanelOverlay.Position.TopCenter
                centerOffset: g.batteryWidgetCenterX - screenScope.screenData.width / 2

                BatteryPanel {
                    anchors.fill: parent
                    active: g.batteryPanelOpen && g.activeBatteryScreen === screenScope.screenData
                    onClose: g.batteryPanelOpen = false
                }
            }
        }
    }
}
