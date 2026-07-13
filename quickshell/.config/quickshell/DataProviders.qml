// DataProviders — shared data models, notification server, and polling processes.
// Extracted from shell.qml. Property aliases let the outer scope bind to each source.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root
    property alias kdeData: kdeData
    property alias notifServer: notifServer
    property alias notifData: notifData
    property alias cpuData: cpuData
    property alias netData: netData
    property alias weatherData: weatherData
    property alias volumeData: volumeData
    property alias batteryData: batteryData

    // ── KDE Connect ─────────────────────────────────────────

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

    // ── Notification Server (DBus daemon, replaces mako) ────

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function(notif) {
            if (notifData.dnd) return

            if (!notifData.timesLoaded) return

            var key = notifData.notifHash(notif)
            if (notifData.timesByKey[key] !== undefined
                && Date.now() - notifData.startupTime < 5000) {
                notif.tracked = false
                return
            }

            notif.tracked = true
            notifData.addNotifTime(notif)
            notifData.activeNotifs = notifData.activeNotifs.concat([notif])
            notifData.count = notifData.activeNotifs.length
            notifData.tryPlaySound()
            notifData.newNotification(notif)

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

    // ── Notification Data Adapter ───────────────────────────

    Item {
        id: notifData
        property int count: 0
        property bool dnd: false
        property var activeNotifs: []
        property var notifTimes: ({})
        property var timesByKey: ({})
        property bool timesLoaded: false
        property var savedNotifs: []
        property int lastSoundTime: 0
        property int startupTime: Date.now()
        property string storagePath: Quickshell.env("HOME") + "/.local/state/quickshell/notifications.json"
        signal newNotification(var notif)
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
            saveDebounce.restart()
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

        // --- persistence ---

        Timer {
            id: saveDebounce
            interval: 500
            onTriggered: _doSave()
        }

        Process { id: saveProc }

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
            saveDebounce.stop()
            var json = JSON.stringify(savedNotifs)
            var dir = storagePath.substring(0, storagePath.lastIndexOf("/"))
            saveProc.command = [
                "/bin/sh", "-c",
                "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"",
                "_", dir, json, storagePath
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

    // ── CPU / RAM / GPU / Temp ──────────────────────────────

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

    // ── Network Speed ───────────────────────────────────────

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

    // ── Weather ─────────────────────────────────────────────

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

    // ── Volume ──────────────────────────────────────────────

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
            interval: 5000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (!volumeFetchProc.running) volumeFetchProc.running = true;
            }
        }
    }

    // ── Battery ─────────────────────────────────────────────

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
}
