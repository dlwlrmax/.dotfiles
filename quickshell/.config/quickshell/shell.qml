//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import qs.notification
import qs.mpris
import qs.volume
import qs.weather
import qs.calendar
import qs.sysusage
import qs.netspeed
import qs.power
import qs.battery
import qs.kdeconnect  // KDEConnect.qml, KDEConnectPanel.qml
import qs.launcher
import qs.clipboard
import qs.common
import qs.osd

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
        property bool netPanelOpen: false
        property var activeNetScreen: null
        property bool kdePanelOpen: false
        property var activeKdeScreen: null
        property int kdeWidgetCenterX: 0
        property bool launcherPanelOpen: false
        property var activeLauncherScreen: null
        property bool clipboardPanelOpen: false
        property var activeClipboardScreen: null

        // Dict maps panel name → open-property name on g. Single source of truth.
        property var _panels: [
            { name: "notif",    prop: "notifPanelOpen" },
            { name: "mpris",    prop: "mprisPanelOpen" },
            { name: "volume",   prop: "volumePanelOpen" },
            { name: "weather",  prop: "weatherPanelOpen" },
            { name: "calendar", prop: "calendarPanelOpen" },
            { name: "sysUsage", prop: "sysUsagePanelOpen" },
            { name: "power",    prop: "powerPanelOpen" },
            { name: "battery",  prop: "batteryPanelOpen" },
            { name: "net",      prop: "netPanelOpen" },
            { name: "kde",      prop: "kdePanelOpen" },
            { name: "launcher", prop: "launcherPanelOpen" },
            { name: "clipboard",prop: "clipboardPanelOpen" }
        ]

        function closeOtherPanels(name) {
            var panels = _panels
            for (var i = 0; i < panels.length; i++) {
                if (panels[i].name !== name) g[panels[i].prop] = false
            }
        }
    }

    DataProviders { id: dp }

    // Power menu toggle via IPC (replaces 1s file-polling timer)
    IpcHandler {
        target: "power"
        function toggle(): void {
            if (g.powerPanelOpen) {
                g.powerPanelOpen = false
                return
            }
            g.closeOtherPanels("power")
            g.powerPanelOpen = true
            g.activePowerScreen = Quickshell.screens[0]
        }
        function close(): void {
            g.powerPanelOpen = false
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (g.launcherPanelOpen) {
                g.launcherPanelOpen = false
                return
            }
            g.closeOtherPanels("launcher")
            g.launcherPanelOpen = true
            g.activeLauncherScreen = Quickshell.screens[0]
        }
        function close(): void {
            g.launcherPanelOpen = false
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            if (g.clipboardPanelOpen) {
                g.clipboardPanelOpen = false
                return
            }
            g.closeOtherPanels("clipboard")
            g.clipboardPanelOpen = true
            g.activeClipboardScreen = Quickshell.screens[0]
        }
        function close(): void {
            g.clipboardPanelOpen = false
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
                    kdeDataSource: dp.kdeData
                    notifDataSource: dp.notifData
                    cpuDataSource: dp.cpuData
                    netDataSource: dp.netData
                    weatherDataSource: dp.weatherData
                    volumeDataSource: dp.volumeData
                    batteryDataSource: dp.batteryData

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
                    onToggleNetPanel: {
                        g.closeOtherPanels("net")
                        g.netPanelOpen = !g.netPanelOpen
                        if (g.netPanelOpen) g.activeNetScreen = screenScope.screenData
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

            // Notification popup window (toast-style, appears below bar)
            // Top anchor + margin pushes it below bar; no left/right → centered.
            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                implicitWidth: 440
                implicitHeight: notifPopupItem.implicitHeight > 0 ? notifPopupItem.implicitHeight + 60 : 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-notif-popup"
                WlrLayershell.margins.top: 44

                NotificationPopup {
                    id: notifPopupItem
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    theme: Theme {}
                    notifTimes: dp.notifData.notifTimes
                    dnd: dp.notifData.dnd
                    dataSource: dp.notifData
                }

                Connections {
                    target: dp.notifData
                    function onNewNotification(notif) {
                        notifPopupItem.onNotification(notif)
                    }
                }
            }

            // OSD popup: shows on volume/brightness change, auto-fades below bar
            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                implicitHeight: 52
                visible: volumeOsd.opacity > 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-osd"
                WlrLayershell.margins.top: 44

                OsdPopup {
                    id: volumeOsd
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    icon: dp.volumeData.muted ? "" : (dp.volumeData.volumeLevel > 70 ? "" : dp.volumeData.volumeLevel > 30 ? "" : "")
                    level: dp.volumeData.volumeLevel
                    muted: dp.volumeData.muted
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
                    dataSource: dp.notifData
                    notifTimes: dp.notifData.notifTimes
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
                active: g.netPanelOpen && g.activeNetScreen === screenScope.screenData
                onCloseRequested: g.netPanelOpen = false
                topMargin: 44

                NetPanel {
                    anchors.fill: parent
                    active: g.netPanelOpen && g.activeNetScreen === screenScope.screenData
                    dataSource: dp.netData
                    onClose: g.netPanelOpen = false
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
                    dataSource: dp.kdeData
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

            PanelOverlay {
                screen: screenScope.screenData
                active: g.launcherPanelOpen && g.activeLauncherScreen === screenScope.screenData
                onCloseRequested: g.launcherPanelOpen = false
                position: PanelOverlay.Position.Center
                keyboardFocus: true

                LauncherPanel {
                    anchors.fill: parent
                    active: g.launcherPanelOpen && g.activeLauncherScreen === screenScope.screenData
                    onClose: g.launcherPanelOpen = false
                }
            }

            PanelOverlay {
                screen: screenScope.screenData
                active: g.clipboardPanelOpen && g.activeClipboardScreen === screenScope.screenData
                onCloseRequested: g.clipboardPanelOpen = false
                position: PanelOverlay.Position.Center
                keyboardFocus: true

                ClipboardPanel {
                    anchors.fill: parent
                    active: g.clipboardPanelOpen && g.activeClipboardScreen === screenScope.screenData
                    onClose: g.clipboardPanelOpen = false
                }
            }
        }
    }
}
