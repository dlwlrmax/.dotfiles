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
        property bool kdePanelOpen: false
        property var activeKdeScreen: null
        property int kdeWidgetCenterX: 0
        property bool launcherPanelOpen: false
        property var activeLauncherScreen: null
        property bool clipboardPanelOpen: false
        property var activeClipboardScreen: null

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
            if (name !== "launcher") launcherPanelOpen = false
            if (name !== "clipboard") clipboardPanelOpen = false
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
            interval: 10000
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

    // NotificationServer (DBus notification daemon, replaces mako)
    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function(notif) {
            if (notifData.dnd) return

            // Wait for saved timestamps to load before accepting notifs,
            // so we can tell re-delivered (old) notifs from new ones.
            if (!notifData.timesLoaded) return

            // Skip re-delivered old notifs: if we've seen this content
            // before (hash in timesByKey), it's a stale restart redelivery.
            var key = notifData.notifHash(notif)
            if (notifData.timesByKey[key] !== undefined) {
                notif.tracked = false
                return
            }

            notif.tracked = true
            notifData.addNotifTime(notif)
            notifData.activeNotifs = notifData.activeNotifs.concat([notif])
            notifData.count = notifData.activeNotifs.length
            notifData.tryPlaySound()
            notifData.newNotification(notif)

            // Cleanup when notification closes (dismiss/expire/remote close)
            notif.closed.connect(function(reason) {
                var arr = notifData.activeNotifs
                for (var i = 0; i < arr.length; i++) {
                    if (arr[i].id === notif.id) {
                        arr = arr.slice(0, i).concat(arr.slice(i + 1))
                        notifData.activeNotifs = arr
                        notifData.count = arr.length
                        break
                    }
                }
            })
        }
    }

    // Shared notification data adapter (event-driven, no polling)
    Item {
        id: notifData
        property int count: 0
        property bool dnd: false
        property var activeNotifs: []
        property var notifTimes: ({})
        // Persistent map: content-hash -> unix timestamp, built from notifications.json.
        property var timesByKey: ({})
        property bool timesLoaded: false
        // In-memory copy of notifications.json array (append-only, for saving).
        property var savedNotifs: []
        property int lastSoundTime: 0
        property int startupTime: Date.now()
        property string storagePath: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.json"
        signal newNotification(var notif)
        // Broadcast: a popup card on one screen should close on all screens.
        signal dismissPopup(var notifId)

        Component.onCompleted: loadSaved()

        function requestDismissPopup(notifId) {
            dismissPopup(notifId)
        }

        function notifHash(notif) {
            var s = (notif.appName || "") + "|" + (notif.summary || "") + "|" + (notif.body || "")
            var h = 0
            for (var i = 0; i < s.length; i++) {
                h = ((h << 5) - h) + s.charCodeAt(i)
                h |= 0
            }
            return "" + h
        }

        function addNotifTime(notif) {
            var key = notifHash(notif)
            var t = Date.now() / 1000
            notifTimes[notif.id] = t
            timesByKey[key] = t
            // Append savable entry and persist.
            var entry = {
                appName: notif.appName || "",
                summary: notif.summary || "",
                body: notif.body || "",
                urgency: notif.urgency || 1,
                appIcon: notif.appIcon || "",
                desktopEntry: notif.desktopEntry || "",
                expireTimeout: notif.expireTimeout || 0,
                actions: (notif.actions || []).map(function(a) {
                    return { text: a.text, identifier: a.identifier }
                }),
                timestamp: t
            }
            savedNotifs.push(entry)
            _doSave()
        }

        function toggleDnd() {
            dnd = !dnd
        }

        function clearAll() {
            var notifs = activeNotifs
            activeNotifs = []
            count = 0
            for (var i = 0; i < notifs.length; i++) {
                notifs[i].dismiss()
            }
        }

        // --- notifications.json persistence ---

        Process {
            id: saveProc
        }

        Process {
            id: loadProc
            stdout: StdioCollector {
                onStreamFinished: {
                    var text = this.text.trim()
                    if (!text) {
                        notifData.timesLoaded = true
                        return
                    }
                    try {
                        var data = JSON.parse(text)
                        if (Array.isArray(data)) {
                            notifData.savedNotifs = data
                            // Build hash -> timestamp map from saved entries.
                            var map = {}
                            for (var i = 0; i < data.length; i++) {
                                var d = data[i]
                                var s = (d.appName || "") + "|" + (d.summary || "") + "|" + (d.body || "")
                                var h = 0
                                for (var j = 0; j < s.length; j++) {
                                    h = ((h << 5) - h) + s.charCodeAt(j)
                                    h |= 0
                                }
                                map["" + h] = d.timestamp || 0
                            }
                            notifData.timesByKey = map
                            console.log("notifData: loaded", data.length, "saved notifs,", Object.keys(map).length, "timestamps")
                        }
                        notifData.timesLoaded = true
                    } catch (e) {
                        console.log("Failed to load notifications.json:", e)
                        notifData.timesLoaded = true
                    }
                }
            }
        }

        function _doSave() {
            if (saveProc.running) return
            var json = JSON.stringify(savedNotifs)
            var dir = storagePath.substring(0, storagePath.lastIndexOf("/"))
            saveProc.command = [
                "python3", "-c",
                "import json,sys,os; os.makedirs(sys.argv[2], exist_ok=True); json.dump(json.loads(sys.argv[1]), open(sys.argv[3], 'w'))",
                json, dir, storagePath
            ]
            saveProc.running = true
        }

        function loadSaved() {
            loadProc.command = ["/bin/cat", storagePath]
            loadProc.running = true
        }

        Process {
            id: soundProc
            command: ["paplay", Quickshell.env("HOME") + "/Nextcloud/Sounds/notification.wav"]
        }

        function tryPlaySound() {
            var now = Date.now()
            if (now - lastSoundTime < 1000) return
            lastSoundTime = now
            soundProc.running = true
        }
    }

    // Shared CPU/mem/gpu data (single Rust binary, no bash/awk overhead)
    Item {
        id: cpuData
        property int cpuUsage: 0
        property int ramUsage: 0
        property int swapUsage: 0
        property int gpuUsage: 0
        property int cpuTemp: 0

        Process {
            id: sysFetchProc
            command: [Quickshell.env("HOME") + "/.cargo/bin/sys-stats"]

            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        var data = JSON.parse(this.text.trim());
                        if (!isNaN(data.cpu)) cpuData.cpuUsage = data.cpu;
                        if (!isNaN(data.ram)) cpuData.ramUsage = data.ram;
                        if (!isNaN(data.swap)) cpuData.swapUsage = data.swap;
                        if (!isNaN(data.gpu)) cpuData.gpuUsage = data.gpu;
                        if (!isNaN(data.cpu_temp)) cpuData.cpuTemp = data.cpu_temp;
                    } catch (e) {}
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!sysFetchProc.running) sysFetchProc.running = true;
            }
        }
    }

    // Shared net speed data (single poll for both bars)
    Item {
        id: netData
        property string dlText: "--"
        property string ulText: "--"

        Process {
            id: netFetchProc
            command: [Quickshell.env("HOME") + "/.cargo/bin/net-stats"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    if (!output) {
                        netData.dlText = "--";
                        netData.ulText = "--";
                    } else {
                        var parts = output.split("|")
                        if (parts.length >= 2) {
                            netData.dlText = parts[0] || "--";
                            netData.ulText = parts[1] || "--";
                        }
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!netFetchProc.running) netFetchProc.running = true;
            }
        }
    }

    // Shared weather data (single poll for both bars)
    Item {
        id: weatherData
        property string weatherIcon: ""
        property string weatherText: "--"

        function refresh() {
            if (!weatherFetchProc.running) weatherFetchProc.running = true;
        }

        Process {
            id: weatherFetchProc
            command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    if (output) {
                        var outputs = output.split(/\s+/);
                        weatherData.weatherIcon = outputs[0];
                        weatherData.weatherText = outputs[1];
                    }
                }
            }
        }

        Timer {
            interval: 1800000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!weatherFetchProc.running) weatherFetchProc.running = true;
            }
        }
    }

    // Shared volume data (single poll for both bars)
    Item {
        id: volumeData
        property int volumeLevel: 0
        property bool muted: false

        function refresh() {
            if (!volumeFetchProc.running) volumeFetchProc.running = true;
        }

        Process {
            id: volumeFetchProc
            command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/volume-status.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim();
                    var parts = output.split(" ");
                    if (parts.length >= 2) {
                        var vol = parseInt(parts[0]);
                        if (!isNaN(vol)) volumeData.volumeLevel = vol;
                        volumeData.muted = parts[1] === "true";
                    }
                }
            }
        }

        Timer {
            interval: 2000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!volumeFetchProc.running) volumeFetchProc.running = true;
            }
        }
    }

    // Shared battery data (single poll for both bars)
    Item {
        id: batteryData
        property string batteryIcon: ""
        property string batteryStatus: ""

        Process {
            id: batteryFetchProc
            command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/battery.sh"]

            stdout: StdioCollector {
                onStreamFinished: {
                    var output = this.text.trim()
                    if (!output) {
                        batteryData.batteryIcon = ""
                        batteryData.batteryStatus = ""
                    } else {
                        var parts = output.split("|")
                        if (parts.length >= 3) {
                            batteryData.batteryIcon = parts[0] || ""
                            batteryData.batteryStatus = parts[2] || ""
                        }
                    }
                }
            }
        }

        Timer {
            interval: 30000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!batteryFetchProc.running) batteryFetchProc.running = true;
            }
        }
    }

    Item {
        id: powerTrigger

        Timer {
            id: powerPollTimer
            interval: 1000
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
                    kdeDataSource: kdeData
                    notifDataSource: notifData
                    cpuDataSource: cpuData
                    netDataSource: netData
                    weatherDataSource: weatherData
                    volumeDataSource: volumeData
                    batteryDataSource: batteryData

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
                    notifTimes: notifData.notifTimes
                    dnd: notifData.dnd
                    dataSource: notifData
                }

                Connections {
                    target: notifData
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
                    icon: volumeData.muted ? "" : (volumeData.volumeLevel > 70 ? "" : volumeData.volumeLevel > 30 ? "" : "")
                    level: volumeData.volumeLevel
                    muted: volumeData.muted
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
                    notifTimes: notifData.notifTimes
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
