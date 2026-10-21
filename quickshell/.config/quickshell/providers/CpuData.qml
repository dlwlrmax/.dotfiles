// CpuData
// CPU / RAM / GPU / temperature from sys-stats, plus a short CPU history.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import qs.common

Item {
    id: cpuData
    property Theme theme: ThemeStore
    // Poll period; DataProviders slows it down while gaming.
    property int statPollMs: 2000
    property int cpuUsage: 0
    property int ramUsage: 0
    property int swapUsage: 0
    property int gpuUsage: 0
    property int cpuTemp: 0
    property bool _parseWarned: false
    // Rolling CPU window for the bar sparkline; mutated in place, historyTick signals.
    readonly property int maxHistory: 30
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var swapHistory: []
    property int historyTick: 0
    // Epoch seconds of the last good sample (0 until the first).
    property real updatedAt: 0

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
                    cpuData.cpuHistory.push(cpuData.cpuUsage);
                    if (cpuData.cpuHistory.length > cpuData.maxHistory) cpuData.cpuHistory.shift();
                    var extra = [["gpuHistory", cpuData.gpuUsage], ["ramHistory", cpuData.ramUsage], ["swapHistory", cpuData.swapUsage]];
                    for (var i = 0; i < extra.length; i++) {
                        cpuData[extra[i][0]].push(extra[i][1]);
                        if (cpuData[extra[i][0]].length > cpuData.maxHistory) cpuData[extra[i][0]].shift();
                    }
                    cpuData.historyTick++;
                    cpuData.updatedAt = Date.now() / 1000;
                } catch (e) {
                    // Warn once per failure mode instead of spamming every
                    // 2s poll. Include the raw payload (truncated) so a bad
                    // sys-stats build is diagnosable.
                    if (!cpuData._parseWarned) {
                        cpuData._parseWarned = true
                        var raw = this.text ? this.text.trim() : ""
                        if (raw.length > 120) raw = raw.substring(0, 120) + "..."
                        console.warn("cpuData: sys-stats JSON parse failed:", e, "raw:", raw)
                    }
                }
            }
        }
    }

    Timer {
        interval: statPollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sysFetchProc.running) sysFetchProc.running = true;
        }
    }
}
