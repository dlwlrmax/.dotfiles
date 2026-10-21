// NetData
// Network throughput from net-stats, with rate history.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: netData
    property Theme theme: ThemeStore
    // Poll period; DataProviders slows it down while gaming.
    property int statPollMs: 2000
    property string dlText: "--"
    property string ulText: "--"
    // Raw rates (bytes/s) from net-stats fields 3/4 (0 with an older binary).
    property real dlBps: 0
    property real ulBps: 0
    // False when there is no active interface / net-stats output.
    property bool connected: true
    // Rolling window for the panel graph; arrays are mutated in place and
    // historyTick signals a change.
    readonly property int maxHistory: 60
    property var dlHistory: []
    property var ulHistory: []
    property int historyTick: 0

    function pushRates() {
        dlHistory.push(dlBps)
        ulHistory.push(ulBps)
        if (dlHistory.length > maxHistory) {
            dlHistory.shift()
            ulHistory.shift()
        }
        historyTick++
    }

    Process {
        id: netFetchProc
        command: [Quickshell.env("HOME") + "/.cargo/bin/net-stats"]

        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                var parts = output ? output.split("|") : [];
                if (parts.length < 2 || parts[0] === "--") {
                    netData.dlText = "--";
                    netData.ulText = "--";
                    netData.dlBps = 0;
                    netData.ulBps = 0;
                    netData.connected = false;
                } else {
                    netData.dlText = parts[0];
                    netData.ulText = parts[1] || "--";
                    netData.dlBps = parts.length >= 4 ? (parseFloat(parts[2]) || 0) : 0;
                    netData.ulBps = parts.length >= 4 ? (parseFloat(parts[3]) || 0) : 0;
                    netData.connected = true;
                }
                netData.pushRates();
            }
        }
    }

    Timer {
        interval: statPollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!netFetchProc.running) netFetchProc.running = true;
        }
    }
}
