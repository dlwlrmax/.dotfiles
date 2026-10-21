import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: ThemeStore
    property bool active: false
    // Bar's shared stats source (DataProviders.cpuData): cpu/gpu/ram/swap %, cpu temp.
    property var dataSource: null
    signal close()

    // ── ring buffers (max 30 samples = 1 min at 2s interval) ──
    readonly property int maxHistory: 30
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var swapHistory: []

    // ── current snapshot ──
    readonly property int cpuPct: dataSource ? dataSource.cpuUsage : 0
    readonly property int gpuPct: dataSource ? dataSource.gpuUsage : 0
    readonly property int ramPct: dataSource ? dataSource.ramUsage : 0
    readonly property int swapPct: dataSource ? dataSource.swapUsage : 0
    readonly property int cpuTemp: dataSource ? dataSource.cpuTemp : 0
    property int ramTotalMb: 0
    property int ramUsedMb: 0
    property int swapTotalMb: 0
    property int swapUsedMb: 0
    property int gpuFreq: 0
    property int diskTotalMb: 0
    property int diskUsedMb: 0
    property int uptimeSec: 0
    property string load: ""
    property var cores: []
    property var topProcesses: []
    property bool hasData: false
    property bool gpuAvail: false
    // Swap is a full card only while busy (hysteresis avoids flapping at the
    // warn line); otherwise it collapses to a one-line gauge.
    property bool swapExpanded: false

    // ── process table ──
    readonly property int maxProcs: 10
    property string procSort: "cpu"   // "cpu" | "ram"
    property int hoverIdx: -1
    readonly property var shownProcs: {
        var key = procSort, other = key === "cpu" ? "ram" : "cpu"
        return topProcesses.slice()
            .sort(function (a, b) { return (b[key] - a[key]) || (b[other] - a[other]) })
            .slice(0, maxProcs)
    }
    // Inline bars are relative to the largest visible row, with a floor so a
    // quiet system doesn't render every row as a full bar.
    readonly property real barCpuMax: shownProcs.reduce(function (m, p) { return Math.max(m, p.cpu) }, 25)
    readonly property real barRamMax: shownProcs.reduce(function (m, p) { return Math.max(m, p.ram) }, 256)
    readonly property string hoverText: {
        var p = hoverIdx >= 0 ? shownProcs[hoverIdx] : undefined
        if (!p) return "click RAM / CPU% to sort · right-click a row to end it"
        return p.name + " · pid " + p.pid + (p.count > 1 ? " · ×" + p.count + " (busiest)" : "")
    }

    // ── end process (right-click a row, then confirm) ──
    // Snapshot of the right-clicked row (rows re-sort every poll, so not an index).
    property var killTarget: undefined
    property string killMsg: ""
    // Never offered: ending these takes the session or this shell down.
    readonly property var protectedNames: ["Hyprland", "qs", "quickshell", "systemd", "Xwayland", "dbus-daemon"]
    readonly property bool killProtected: killTarget !== undefined && protectedNames.indexOf(killTarget.name) >= 0

    function confirmKill() {
        var t = killTarget
        if (!t || killProtected) return
        // One process: by pid. A group: every process with that exact name.
        killProc.command = t.count > 1 ? ["pkill", "-TERM", "-x", "--", t.name]
                                       : ["kill", "-TERM", String(t.pid)]
        killMsg = "Sent SIGTERM to " + t.name + (t.count > 1 ? " (×" + t.count + ")" : "")
        killProc.running = true
        killTarget = undefined
        killMsgTimer.restart()
    }

    // ── disk throughput / fans (from the panel script) ──
    property real diskReadBps: 0
    property real diskWriteBps: 0
    property var fans: []

    function fmtRate(bps) {
        if (bps >= 1073741824) return (bps / 1073741824).toFixed(1) + "G/s"
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + "M/s"
        if (bps >= 1024) return Math.round(bps / 1024) + "K/s"
        return "0"
    }

    // ── min / max over ring buffer ──
    property int cpuMin: 0
    property int cpuMax: 0
    property int gpuMin: 0
    property int gpuMax: 0
    property int ramMin: 0
    property int ramMax: 0
    property int swapMin: 0
    property int swapMax: 0

    // ── helpers ──
    function fmtMem(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(1) + "G"
        return mb + "M"
    }

    function fmtUptime(s) {
        var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        if (d > 0) return d + "d " + h + "h"
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    function band(pct, warn, crit, base) {
        return pct > crit ? theme.red : pct > warn ? theme.yellow : base
    }

    function lineColor(metric, pct) {
        switch (metric) {
        case "cpu": return band(pct, theme.sysCpuLineWarn, theme.sysCpuLineCrit, theme.blue)
        case "gpu": return band(pct, theme.sysGpuLineWarn, theme.sysGpuLineCrit, theme.mauve)
        case "ram": return band(pct, theme.ramWarn, theme.ramCrit, theme.green)
        default:    return band(pct, theme.swapWarn, theme.swapCrit, theme.peach)
        }
    }

    function tempColor(t) {
        return t > theme.cpuTempCrit ? theme.red
             : t > theme.cpuTempHigh ? theme.peach
             : t > theme.cpuTempWarn ? theme.yellow : theme.green
    }

    function tempText(t) {
        if (t <= 0) return ""
        var icon = t > theme.cpuTempCrit ? " "
                 : t > theme.cpuTempHigh ? " "
                 : t > theme.cpuTempWarn ? " " : " "
        return icon + t + "°C"
    }

    function pushHistory(which, value) {
        var arr = root[which]
        var minProp = which.replace("History", "Min")
        var maxProp = which.replace("History", "Max")
        var evicted
        if (arr.length >= root.maxHistory)
            evicted = arr.shift()
        arr.push(value)

        if (arr.length === 1) {
            root[minProp] = value
            root[maxProp] = value
        } else if (evicted !== undefined
                   && (evicted === root[minProp] || evicted === root[maxProp])) {
            // A bound left the window — rescan only then.
            var lo = arr[0], hi = arr[0]
            for (var i = 1; i < arr.length; i++) {
                if (arr[i] < lo) lo = arr[i]
                if (arr[i] > hi) hi = arr[i]
            }
            root[minProp] = lo
            root[maxProp] = hi
        } else {
            if (value < root[minProp]) root[minProp] = value
            if (value > root[maxProp]) root[maxProp] = value
        }
    }

    // A freshly built panel (they exist only while open) starts from the shared history, so the
    // graphs are filled on open and both screens show the same.
    function seedHistory() {
        var ds = dataSource
        if (!ds) return
        var map = { cpuHistory: ds.cpuHistory, gpuHistory: ds.gpuHistory, ramHistory: ds.ramHistory, swapHistory: ds.swapHistory }
        for (var k in map) {
            var arr = (map[k] || []).slice()
            root[k] = arr
            var base = k.replace("History", "")
            if (arr.length) {
                root[base + "Min"] = Math.min.apply(null, arr)
                root[base + "Max"] = Math.max.apply(null, arr)
            }
        }
        if (ds.cpuHistory.length > 0) hasData = true
    }

    Component.onCompleted: seedHistory()

    function requestPaints() {
        cpuCard.requestPaint()
        gpuCard.requestPaint()
        ramCard.requestPaint()
        swapCard.requestPaint()
    }

    // ── layout ──
    onActiveChanged: if (!active) { killTarget = undefined; killMsg = "" }

    clip: true
    implicitWidth: theme.panelWidthL
    implicitHeight: 620

    PanelBackground {
        anchors.fill: parent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 6

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "System Usage"
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.hasData ? "load " + root.load + " · up " + root.fmtUptime(root.uptimeSec) : ""
                color: theme.subtext0
                font.pixelSize: theme.fontSizeMin
                font.family: theme.font
            }

            IconButton {
                theme: root.theme
                text: Glyphs.close
                glyphSize: theme.fontSize + 1
                onClicked: root.close()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ═══════════════════ Row 1: CPU | GPU ═══════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 6

            MetricCard {
                id: cpuCard
                theme: root.theme
                label: "CPU"
                history: root.cpuHistory
                pct: root.cpuPct
                minVal: root.cpuMin
                maxVal: root.cpuMax
                hasData: root.hasData
                lineClr: root.lineColor("cpu", root.cpuPct)
                subText: root.tempText(root.cpuTemp)
                subColor: root.tempColor(root.cpuTemp)
                subVisible: root.cpuTemp > 0
            }

            MetricCard {
                id: gpuCard
                visible: root.gpuAvail
                theme: root.theme
                label: "GPU"
                history: root.gpuHistory
                pct: root.gpuPct
                minVal: root.gpuMin
                maxVal: root.gpuMax
                hasData: root.hasData
                lineClr: root.lineColor("gpu", root.gpuPct)
                subText: root.gpuFreq > 0 ? root.gpuFreq + "MHz" : ""
                subColor: theme.subtext1
                subVisible: root.gpuFreq > 0
            }
        }

        // ═══════════════════ Row 2: RAM | SWAP (when busy) ═══════════════════
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 100
            spacing: 6

            MetricCard {
                id: ramCard
                theme: root.theme
                label: "RAM"
                history: root.ramHistory
                pct: root.ramPct
                minVal: root.ramMin
                maxVal: root.ramMax
                hasData: root.hasData
                lineClr: root.lineColor("ram", root.ramPct)
                subText: root.ramTotalMb > 0
                         ? root.fmtMem(root.ramUsedMb) + "/" + root.fmtMem(root.ramTotalMb)
                         : ""
                subColor: theme.subtext1
                subVisible: root.ramTotalMb > 0
            }

            MetricCard {
                id: swapCard
                visible: root.swapTotalMb > 0 && root.swapExpanded
                theme: root.theme
                label: "SWAP"
                history: root.swapHistory
                pct: root.swapPct
                minVal: root.swapMin
                maxVal: root.swapMax
                hasData: root.hasData
                lineClr: root.lineColor("swap", root.swapPct)
                subText: root.fmtMem(root.swapUsedMb) + "/" + root.fmtMem(root.swapTotalMb)
                subColor: theme.subtext1
                subVisible: root.swapTotalMb > 0
            }
        }

        MiniBar {
            visible: root.swapTotalMb > 0 && !root.swapExpanded
            theme: root.theme
            label: "SWAP"
            pct: root.swapPct
            detail: root.fmtMem(root.swapUsedMb) + "/" + root.fmtMem(root.swapTotalMb)
            barClr: root.lineColor("swap", root.swapPct)
        }

        // ── per-core usage ──
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            spacing: 8
            visible: root.cores.length > 0

            Text {
                text: "CORES"
                color: theme.subtext1
                font.pixelSize: theme.fontSizeMin
                font.bold: true
                font.family: theme.font
                Layout.preferredWidth: 36
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                Repeater {
                    model: root.cores

                    Item {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Qt.alpha(theme.surface0, 0.8)
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: Math.max(2, parent.height * modelData / 100)
                            radius: 2
                            color: root.lineColor("cpu", modelData)
                        }
                    }
                }
            }
        }

        // ── top processes ──
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { title: "Process", width: 0, key: "" },
                    { title: "RAM", width: 64, key: "ram" },
                    { title: "CPU%", width: 56, key: "cpu" }
                ]

                Text {
                    required property var modelData
                    readonly property bool sorted: modelData.key !== "" && modelData.key === root.procSort
                    text: modelData.title + (sorted ? " ▾" : "")
                    color: sorted ? theme.text : theme.subtext1
                    font.pixelSize: theme.fontSize - 1
                    font.bold: true
                    font.family: theme.font
                    Layout.fillWidth: modelData.width === 0
                    Layout.preferredWidth: modelData.width
                    horizontalAlignment: modelData.width ? Text.AlignRight : Text.AlignLeft

                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.key !== ""
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.procSort = modelData.key
                    }
                }
            }
        }

        // Fixed rows updated in place (the list is always <= maxProcs entries).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Repeater {
                model: root.maxProcs

                Rectangle {
                    id: procRow
                    required property int index
                    readonly property var proc: root.shownProcs[index]
                    readonly property real ramMb: proc ? proc.ram : 0
                    readonly property real cpuV: proc ? proc.cpu : 0
                    readonly property color ramClr: root.band(ramMb, theme.sysProcRamWarn, theme.sysProcRamCrit, theme.subtext0)
                    readonly property color cpuClr: root.band(cpuV, theme.sysProcCpuWarn, theme.sysProcCpuCrit, theme.subtext0)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    radius: theme.radiusSm
                    color: root.hoverIdx === index ? Qt.alpha(theme.surface0, 0.8) : "transparent"
                    visible: proc !== undefined

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onContainsMouseChanged: {
                            if (containsMouse) root.hoverIdx = procRow.index
                            else if (root.hoverIdx === procRow.index) root.hoverIdx = -1
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) root.killTarget = procRow.proc
                            else root.killTarget = undefined
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 6

                        Text {
                            text: procRow.proc ? procRow.proc.name : ""
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: procRow.proc ? "×" + procRow.proc.count : ""
                            visible: procRow.proc !== undefined && procRow.proc.count > 1
                            color: theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.font
                        }

                        Item {
                            Layout.preferredWidth: 64
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 1
                                width: parent.width * Math.min(procRow.ramMb / root.barRamMax, 1)
                                radius: 3
                                color: Qt.alpha(procRow.ramClr, 0.22)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fmtMem(Math.round(procRow.ramMb))
                                color: procRow.ramClr
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                            }
                        }

                        Item {
                            Layout.preferredWidth: 56
                            Layout.fillHeight: true

                            Rectangle {
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 1
                                width: parent.width * Math.min(procRow.cpuV / root.barCpuMax, 1)
                                radius: 3
                                color: Qt.alpha(procRow.cpuClr, 0.22)
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: procRow.cpuV.toFixed(1)
                                color: procRow.cpuClr
                                font.pixelSize: theme.fontSize - 1
                                font.family: theme.font
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.killTarget === undefined
            text: root.killMsg !== "" ? root.killMsg : root.hoverText
            color: root.killMsg !== "" ? theme.green : theme.subtext0
            font.pixelSize: theme.fontSizeMin
            font.family: theme.font
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        // Confirm strip for ending the right-clicked process.
        RowLayout {
            visible: root.killTarget !== undefined
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.killProtected
                      ? (root.killTarget ? root.killTarget.name : "") + " is protected"
                      : "End " + (root.killTarget ? root.killTarget.name
                                  + (root.killTarget.count > 1 ? " (×" + root.killTarget.count + ")" : "") : "") + "?"
                color: root.killProtected ? theme.yellow : theme.text
                font.pixelSize: theme.fontSizeMin
                font.family: theme.font
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Badge {
                visible: !root.killProtected
                theme: root.theme
                text: "End"
                clr: theme.red
                solid: true
                clickable: true
                onClicked: root.confirmKill()
            }

            Badge {
                theme: root.theme
                text: "Cancel"
                clr: theme.subtext0
                clickable: true
                onClicked: root.killTarget = undefined
            }
        }

        Item { Layout.fillHeight: true }

        // Disk throughput and spinning fans.
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.hasData

            Badge {
                theme: root.theme
                text: Glyphs.download + " " + root.fmtRate(root.diskReadBps)
                clr: theme.blue
            }

            Badge {
                theme: root.theme
                text: Glyphs.upload + " " + root.fmtRate(root.diskWriteBps)
                clr: theme.peach
            }

            Repeater {
                model: root.fans

                Badge {
                    required property var modelData
                    theme: root.theme
                    text: modelData.name.replace(/^\S+ /, "") + " " + modelData.rpm + " rpm"
                    clr: theme.subtext1
                }
            }
        }

        MiniBar {
            visible: root.diskTotalMb > 0
            theme: root.theme
            label: "DISK"
            pct: root.diskTotalMb > 0 ? Math.round(100 * root.diskUsedMb / root.diskTotalMb) : 0
            detail: "/ " + root.fmtMem(root.diskUsedMb) + "/" + root.fmtMem(root.diskTotalMb)
            barClr: root.band(pct, theme.sysDiskWarn, theme.sysDiskCrit, theme.sapphire)
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // data polling — only when panel is open
    // ═══════════════════════════════════════════════════════════════

    Process {
        id: fetchProc
        command: ["bash", theme.scriptDir + "/sys-usage-full.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    if (typeof data.ram_total === "number") root.ramTotalMb = data.ram_total
                    if (typeof data.ram_used === "number") root.ramUsedMb = data.ram_used
                    if (typeof data.swap_total === "number") root.swapTotalMb = data.swap_total
                    if (typeof data.swap_used === "number") root.swapUsedMb = data.swap_used
                    if (typeof data.gpu_freq === "number") root.gpuFreq = data.gpu_freq
                    if (typeof data.disk_total === "number") root.diskTotalMb = data.disk_total
                    if (typeof data.disk_used === "number") root.diskUsedMb = data.disk_used
                    if (typeof data.uptime === "number") root.uptimeSec = data.uptime
                    if (typeof data.disk_read_bps === "number") root.diskReadBps = data.disk_read_bps
                    if (typeof data.disk_write_bps === "number") root.diskWriteBps = data.disk_write_bps
                    if (Array.isArray(data.fans)) root.fans = data.fans
                    if (typeof data.load === "number") root.load = data.load.toFixed(2)
                    if (Array.isArray(data.cores)) root.cores = data.cores
                    if (Array.isArray(data.top_processes)) root.topProcesses = data.top_processes
                    root.gpuAvail = data.gpu_available === 1

                    if (root.swapPct >= root.theme.swapWarn) root.swapExpanded = true
                    else if (root.swapPct < root.theme.swapWarn - 5) root.swapExpanded = false

                    root.pushHistory("cpuHistory", root.cpuPct)
                    root.pushHistory("gpuHistory", root.gpuPct)
                    root.pushHistory("ramHistory", root.ramPct)
                    root.pushHistory("swapHistory", root.swapPct)
                    root.requestPaints()

                    root.hasData = true
                } catch (e) {
                    console.log("sys-usage-full parse error:", e)
                }
            }
        }
    }

    Process { id: killProc; running: false }

    Timer {
        id: killMsgTimer
        interval: 3000
        onTriggered: root.killMsg = ""
    }

    Timer {
        id: pollTimer
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchProc.running) fetchProc.running = true
        }
    }
}
