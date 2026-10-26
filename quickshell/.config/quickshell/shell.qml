//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland._Ipc
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import qs.common
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
import qs.systemtray
import qs.settings
import qs.wallpaper
import qs.common
import qs.osd
import qs.deps
import qs.browserpick

ShellRoot {
    id: shell

    Component.onCompleted: {
        Db.open()
        Db.migrateFromJson()
        Prefs.load()
    }

    // A panel open on a monitor that disappears must not come back when it is re-plugged.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (Panels.openName !== "" && !Quickshell.screens.some(sc => sc.name === Panels.screenName))
                Panels.close()
        }
    }



    DataProviders { id: dp }

    // Missing-package notifier (deps/deps.list)
    DepsCheck {}

    // Power menu toggle via IPC (replaces 1s file-polling timer)
    // A failed reload keeps the previous config running silently. Say so, with the
    // root-cause line, so a typo doesn't go unnoticed. (This handler lives in the
    // still-running old generation, which is the one that receives the signal.)
    Connections {
        target: Quickshell
        function onReloadFailed(errorString) {
            // Last line is the root cause ("caused by @file.qml[line:col]: ..."); the first
            // is just "Failed to load configuration".
            var lines = (errorString || "").split("\n").map(l => l.trim()).filter(l => l !== "")
            var cause = (lines.length ? lines[lines.length - 1] : "unknown error").replace(/^caused by\s*/, "")
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Quickshell",
                "Config reload failed", cause + "\nStill running the previous config. Details: qs log"])
        }
    }

    // Panel under the focused monitor (IPC, keybinds, testing).
    function screenNameOfFocus() {
        var mon = Hyprland.focusedMonitor?.name ?? ""
        return (Quickshell.screens.find(sc => sc.name === mon) ?? Quickshell.screens[0]).name
    }

    readonly property var panelNames: ["notif", "mpris", "volume", "weather", "calendar", "sysUsage",
        "power", "battery", "net", "kde", "launcher", "clipboard", "tray", "settings", "wallpaper",
        "browserPick"]

    // qs ipc call panel toggle <name>   (names: qs ipc call panel list)
    IpcHandler {
        target: "panel"
        function toggle(name: string): string {
            if (shell.panelNames.indexOf(name) < 0) return "unknown panel: " + name
            Panels.toggle(name, shell.screenNameOfFocus(), 0)
            return "ok"
        }
        function close(): void { Panels.close() }
        function list(): string { return shell.panelNames.join(" ") }
    }

    // qs ipc call media now    → "now playing" card for the current track (keybind-friendly)
    IpcHandler {
        target: "media"
        function now(): string {
            if (!MediaInfo.playing) return "nothing playing"
            MediaInfo.trackStarted(MediaInfo.playing)
            return "ok"
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { Panels.toggle("power", shell.screenNameOfFocus(), 0) }
        function close(): void { if (Panels.openName === "power") Panels.close() }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { Panels.toggle("launcher", shell.screenNameOfFocus(), 0) }
        function close(): void { if (Panels.openName === "launcher") Panels.close() }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { Panels.toggle("clipboard", shell.screenNameOfFocus(), 0) }
        function close(): void { if (Panels.openName === "clipboard") Panels.close() }
    }

    // qs ipc call link pick   (scripts/link-open.sh). The link and the browser list come
    // through $XDG_RUNTIME_DIR/quickshell-link.json: `qs ipc` splits arguments on commas.
    IpcHandler {
        target: "link"
        function pick(): string {
            var d
            try { d = JSON.parse(Db._readFile(Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-link.json")) }
            catch (e) { return "bad link file" }
            if (!d.url || !Array.isArray(d.browsers) || d.browsers.length === 0) return "no browsers"
            ShellState.linkUrl = d.url
            ShellState.linkBrowsers = d.browsers
            var scr = shell.screenNameOfFocus()
            if (!Panels.isOpen("browserPick", scr)) Panels.toggle("browserPick", scr, 0)
            return "ok"
        }
    }

    // Audio output cycle (Super+Ctrl+A): next sink + move streams + notify
    IpcHandler {
        target: "audio"
        function cycle(): void { dp.cycleAudio() }
        // Toggle the volume panel on the focused monitor.
        function panel(): void { Panels.toggle("volume", shell.screenNameOfFocus(), 0) }
    }

    // Driven by Hyprland's auto gaming profile (hypr lua/gaming.lua).
    IpcHandler {
        target: "gaming"
        function set(on: bool): void {
            dp.gamingMonitor = on ? (Hyprland.focusedMonitor?.name ?? "") : ""
            dp.gaming = on
        }
        function get(): bool { return dp.gaming }
        function monitor(): string { return ShellState.gamingMonitor }
    }

    Binding {
        target: ShellState
        property: "gamingMonitor"
        value: dp.gaming ? (dp.gamingMonitor || "*") : ""
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Item {
            id: screenScope
            property var screenData: modelData
            property Theme theme: ThemeStore

            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                anchors.left: true
                anchors.right: true
                color: "transparent"
                exclusionMode: ExclusionMode.Auto
                implicitHeight: theme.barHeight
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"

                Bar {
                    id: barItem
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    anchors.topMargin: 6
                    monitor: Hyprland.monitorFor(screenScope.screenData)
                    // primary = leftmost screen (DP-1 first in hypr/lua/monitors.lua)
                    showStats: Prefs.show("stats") && (Prefs.statsAllScreens
                               || screenScope.screenData.x === Math.min.apply(null, Quickshell.screens.map(sc => sc.x)))
                    kdeDataSource: dp.kdeData
                    notifDataSource: dp.notifData
                    cpuDataSource: dp.cpuData
                    netDataSource: dp.netData
                    weatherDataSource: dp.weatherData
                    volumeDataSource: dp.volumeData
                    batteryDataSource: dp.batteryData
                    healthDataSource: dp.healthData

                    onTogglePanel: (name, centerX) => Panels.toggle(name, screenScope.screenData.name, centerX)
                }
            }

            // Toasts mirror on ALL screens (per user preference).
            PanelWindow {
                screen: screenScope.screenData
                anchors.top: true
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                implicitWidth: 440
                implicitHeight: notifPopupItem.implicitHeight > 0 ? notifPopupItem.implicitHeight + 60 : 0
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-notif-popup"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                WlrLayershell.margins.top: theme.barHeight

                NotificationPopup {
                    id: notifPopupItem
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    theme: ThemeStore
                    notifTimes: dp.notifData.notifTimes
                    // Gaming: only critical popups over the game's monitor; other screens show
                    // everything, and history still records everything.
                    dnd: dp.notifData.dnd
                    quiet: ShellState.quietOn(screenScope.screenData.name)
                    dataSource: dp.notifData
                }

                Connections {
                    target: dp.notifData
                    function onNewNotification(notif) {
                        notifPopupItem.onNotification(notif)
                    }
                    function onNotificationUpdated(notif) {
                        notifPopupItem.onNotificationUpdated(notif)
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
                WlrLayershell.margins.top: theme.barHeight

                OsdPopup {
                    id: volumeOsd
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    mode: osdMic ? "mic" : "volume"
                    icon: osdMic ? (dp.volumeData.micMuted ? "\udb80\udf6d" : "\udb80\udf6c")
                                 : ThemeStore.volumeGlyph(dp.volumeData.volumeLevel, dp.volumeData.muted)
                    level: dp.volumeData.volumeLevel
                    muted: osdMic ? dp.volumeData.micMuted : dp.volumeData.muted

                    // Microphone mute shows "Mic on/off"; any output change switches back.
                    property bool osdMic: false
                    Connections {
                        target: dp.volumeData
                        function onMicMutedChanged() { volumeOsd.osdMic = true; volumeOsd.flash() }
                        function onVolumeLevelChanged() { volumeOsd.osdMic = false }
                        function onMutedChanged() { volumeOsd.osdMic = false }
                    }
                }
            }

            // ── popup panels (open state: Panels singleton) ──

            PanelHost {
                id: hNotif
                targetScreen: screenScope.screenData
                name: "notif"; placement: "widget"
                panel: Component {
                    NotificationPanel {
                        anchors.fill: parent
                        dataSource: dp.notifData
                        notifTimes: dp.notifData.notifTimes
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hMpris
                targetScreen: screenScope.screenData
                name: "mpris"; placement: "widget"
                panel: Component {
                    MprisPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hVolume
                targetScreen: screenScope.screenData
                name: "volume"; placement: "widget"
                panel: Component {
                    VolumePanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hWeather
                targetScreen: screenScope.screenData
                name: "weather"; placement: "widget"
                panel: Component {
                    WeatherPanel {
                        anchors.fill: parent
                        dataSource: dp.weatherData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hCalendar
                targetScreen: screenScope.screenData
                name: "calendar"; placement: "widget"
                panel: Component {
                    CalendarPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hSys
                targetScreen: screenScope.screenData
                name: "sysUsage"; placement: "widget"
                panel: Component {
                    SysUsagePanel {
                        anchors.fill: parent
                        dataSource: dp.cpuData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hNet
                targetScreen: screenScope.screenData
                name: "net"; placement: "widget"
                panel: Component {
                    NetPanel {
                        anchors.fill: parent
                        dataSource: dp.netData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hKde
                targetScreen: screenScope.screenData
                name: "kde"; placement: "widget"
                panel: Component {
                    KDEConnectPanel {
                        anchors.fill: parent
                        dataSource: dp.kdeData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hBattery
                targetScreen: screenScope.screenData
                name: "battery"; placement: "widget"
                panel: Component {
                    BatteryPanel {
                        anchors.fill: parent
                        dataSource: dp.batteryData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hWallpaper
                targetScreen: screenScope.screenData
                name: "wallpaper"; placement: "center"
                panel: Component {
                    WallpaperPanel {
                        anchors.fill: parent
                        wp: dp.wallpaperData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hSettings
                targetScreen: screenScope.screenData
                name: "settings"; placement: "widget"
                panel: Component {
                    SettingsPanel {
                        anchors.fill: parent
                        health: dp.healthData
                        weather: dp.weatherData
                        volumeData: dp.volumeData
                        notifData: dp.notifData
                        wallpaper: dp.wallpaperData
                        onClose: Panels.close()
                    }
                }
            }

            PanelHost {
                id: hTray
                targetScreen: screenScope.screenData
                name: "tray"; placement: "widget"
                panel: Component {
                    TrayOverflowPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hPower
                targetScreen: screenScope.screenData
                name: "power"; placement: "center"
                panel: Component {
                    PowerMenuPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hLauncher
                targetScreen: screenScope.screenData
                name: "launcher"; placement: "center"
                panel: Component {
                    LauncherPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hClipboard
                targetScreen: screenScope.screenData
                name: "clipboard"; placement: "center"
                panel: Component {
                    ClipboardPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }

            PanelHost {
                id: hBrowserPick
                targetScreen: screenScope.screenData
                name: "browserPick"; placement: "center"
                panel: Component {
                    BrowserPickPanel { anchors.fill: parent; onClose: Panels.close() }
                }
            }
        }
    }
}
