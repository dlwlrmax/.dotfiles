//@ pragma UseQApplication
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
import qs.common

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
            notif.tracked = true
            notifData.addNotifTime(notif.id)
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
                        notifData.save()
                        break
                    }
                }
            })

            notifData.save()
        }
    }

    // Shared notification data adapter (event-driven, no polling)
    Item {
        id: notifData
        property int count: 0
        property bool dnd: false
        property var activeNotifs: []
        property var notifTimes: ({})
        property int lastSoundTime: 0
        property int _stubCounter: 0
        property string storagePath: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.json"
        signal newNotification(var notif)

        Component.onCompleted: load()

        function addNotifTime(id) {
            notifTimes[id] = Date.now() / 1000
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
            save()
        }

        // --- Persistence ---

        function createStub(data) {
            _stubCounter++
            var stubId = "stub-" + _stubCounter
            notifTimes[stubId] = data.timestamp || Date.now() / 1000
            return {
                id: stubId,
                appName: data.appName || "Unknown",
                summary: data.summary || "",
                body: data.body || "",
                urgency: data.urgency || 1,
                appIcon: data.appIcon || "",
                desktopEntry: data.desktopEntry || "",
                expireTimeout: data.expireTimeout || 0,
                restored: true,
                actions: (data.actions || []).map(function(a) {
                    return {
                        text: a.text,
                        identifier: a.identifier,
                        invoke: function() {}
                    }
                }),
                dismiss: function() {
                    var arr = notifData.activeNotifs
                    for (var i = 0; i < arr.length; i++) {
                        if (arr[i].id === this.id) {
                            arr = arr.slice(0, i).concat(arr.slice(i + 1))
                            notifData.activeNotifs = arr
                            notifData.count = arr.length
                            notifData.save()
                            break
                        }
                    }
                }
            }
        }

        function toSavable(notif) {
            var out = {
                appName: notif.appName,
                summary: notif.summary,
                body: notif.body,
                urgency: notif.urgency,
                appIcon: notif.appIcon,
                desktopEntry: notif.desktopEntry,
                expireTimeout: notif.expireTimeout,
                actions: (notif.actions || []).map(function(a) {
                    return { text: a.text, identifier: a.identifier }
                }),
                timestamp: notifData.notifTimes[notif.id] || Date.now() / 1000
            }
            return out
        }

        Timer {
            id: saveTimer
            interval: 300
            onTriggered: notifData._doSave()
        }

        function save() {
            saveTimer.restart()
        }

        Process {
            id: saveProc
        }

        Process {
            id: loadProc
            stdout: StdioCollector {
                onStreamFinished: {
                    var text = this.text.trim()
                    if (!text) return
                    try {
                        var data = JSON.parse(text)
                        if (!Array.isArray(data) || data.length === 0) return
                        var stubs = data.map(function(d) { return notifData.createStub(d) })
                        if (notifData.activeNotifs.length === 0) {
                            notifData.activeNotifs = stubs
                            notifData.count = stubs.length
                        }
                    } catch (e) {
                        console.log("Failed to load notifications:", e)
                    }
                }
            }
        }

        function _doSave() {
            if (saveProc.running) return
            var data = activeNotifs.map(toSavable)
            var json = JSON.stringify(data)
            var dir = storagePath.substring(0, storagePath.lastIndexOf("/"))
            saveProc.command = [
                "python3", "-c",
                "import json,sys,os; os.makedirs(sys.argv[2], exist_ok=True); json.dump(json.loads(sys.argv[1]), open(sys.argv[3], 'w'))",
                json, dir, notifData.storagePath
            ]
            saveProc.running = true
        }

        function load() {
            loadProc.command = ["/bin/cat", notifData.storagePath]
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
                }

                Connections {
                    target: notifData
                    function onNewNotification(notif) {
                        notifPopupItem.onNotification(notif)
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
        }
    }
}
