import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()

    // ── ring buffers (max 30 samples = 1 min at 2s interval) ──
    readonly property int maxHistory: 30
    property var cpuHistory: []
    property var gpuHistory: []
    property var ramHistory: []
    property var swapHistory: []

    // ── current snapshot ──
    property int cpuPct: 0
    property int gpuPct: 0
    property int ramPct: 0
    property int swapPct: 0
    property int ramTotalMb: 0
    property int ramUsedMb: 0
    property int swapTotalMb: 0
    property int swapUsedMb: 0
    property int gpuFreq: 0
    property int cpuTemp: 0
    property var topProcesses: []
    property string topProcJson: ""
    property bool hasData: false
    property bool gpuAvail: false

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
    function hexToRgba(hex, alpha) {
        var r = parseInt(hex.substr(1, 2), 16)
        var g = parseInt(hex.substr(3, 2), 16)
        var b = parseInt(hex.substr(5, 2), 16)
        return "rgba(" + r + "," + g + "," + b + "," + alpha + ")"
    }

    function fmtMem(mb) {
        if (mb >= 1024) return (mb / 1024).toFixed(1) + "G"
        return mb + "M"
    }

    function lineColor(metric, pct) {
        if (metric === "cpu") {
            if (pct > theme.sysCpuLineCrit) return theme.red
            if (pct > theme.sysCpuLineWarn) return theme.yellow
            return theme.blue
        }
        if (metric === "gpu") {
            if (pct > theme.sysGpuLineCrit) return theme.red
            if (pct > theme.sysGpuLineWarn) return theme.yellow
            return theme.mauve
        }
        if (metric === "ram") {
            if (pct > theme.sysRamLineCrit) return theme.red
            if (pct > theme.sysRamLineWarn) return theme.yellow
            return theme.green
        }
        // swap
        if (pct > theme.sysSwapLineCrit) return theme.red
        if (pct > theme.sysSwapLineWarn) return theme.yellow
        return theme.peach
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
        requestPaints()
    }

    function requestPaints() {
        if (cpuCard) cpuCard.requestPaint()
        if (gpuCard) gpuCard.requestPaint()
        if (ramCard) ramCard.requestPaint()
        if (swapCard) swapCard.requestPaint()
    }

    // ── layout ──
    clip: true
    implicitWidth: 480
    implicitHeight: 560

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
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
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 4
                color: closeMa.containsMouse ? theme.surface0 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: theme.subtext0
                    font.pixelSize: theme.fontSize + 4
                    font.family: theme.font
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        // ═══════════════════ Row 1: CPU | GPU ═══════════════════
        Item {
            Layout.fillWidth: true
            implicitHeight: 105

            RowLayout {
                anchors.fill: parent
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
                    fillClr: root.hexToRgba(root.lineColor("cpu", root.cpuPct), 0.15)
                    subText: root.cpuTemp > 0
                             ? (root.cpuTemp > theme.cpuTempCrit ? " " : root.cpuTemp > theme.cpuTempHigh ? " " : root.cpuTemp > theme.cpuTempWarn ? " " : " ") + root.cpuTemp + "°C"
                             : ""
                    subColor: root.cpuTemp > theme.cpuTempCrit ? theme.red : root.cpuTemp > theme.cpuTempHigh ? theme.peach : root.cpuTemp > theme.cpuTempWarn ? theme.yellow : theme.green
                    subVisible: root.cpuTemp > 0
                }

                // ── separator ──
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: theme.surface0
                    visible: gpuCard.visible
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
                    fillClr: root.hexToRgba(root.lineColor("gpu", root.gpuPct), 0.15)
                    subText: root.gpuFreq > 0 ? root.gpuFreq + "MHz" : ""
                    subColor: theme.subtext1
                    subVisible: root.gpuFreq > 0
                }
            }
        }

        // ═══════════════════ Row 2: RAM | SWAP ═══════════════════
        Item {
            Layout.fillWidth: true
            implicitHeight: 105

            RowLayout {
                anchors.fill: parent
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
                    fillClr: root.hexToRgba(root.lineColor("ram", root.ramPct), 0.15)
                    subText: root.ramTotalMb > 0
                             ? root.fmtMem(root.ramUsedMb) + "/" + root.fmtMem(root.ramTotalMb)
                             : ""
                    subColor: theme.subtext1
                    subVisible: root.ramTotalMb > 0
                }

                // ── separator ──
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: theme.surface0
                    visible: swapCard.visible
                }

                MetricCard {
                    id: swapCard
                    visible: root.swapTotalMb > 0
                    theme: root.theme
                    label: "SWAP"
                    history: root.swapHistory
                    pct: root.swapPct
                    minVal: root.swapMin
                    maxVal: root.swapMax
                    hasData: root.hasData
                    lineClr: root.lineColor("swap", root.swapPct)
                    fillClr: root.hexToRgba(root.lineColor("swap", root.swapPct), 0.15)
                    subText: root.swapTotalMb > 0
                             ? root.fmtMem(root.swapUsedMb) + "/" + root.fmtMem(root.swapTotalMb)
                             : ""
                    subColor: theme.subtext1
                    subVisible: root.swapTotalMb > 0
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

            Text {
                text: "Process"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

            Text {
                text: "RAM"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                Layout.preferredWidth: 50
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text: "CPU%"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
            }
        }

        ListView {
            id: procList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 3
            clip: true
            model: root.topProcesses

            delegate: RowLayout {
                required property var modelData
                width: procList.width
                spacing: 6

                Text {
                    text: modelData.name
                    color: theme.text
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: {
                        var mb = parseInt(modelData.ram)
                        if (isNaN(mb)) return "—"
                        return root.fmtMem(mb)
                    }
                    color: {
                        var mb = parseInt(modelData.ram)
                        if (isNaN(mb)) return theme.subtext0
                        if (mb > theme.sysProcRamCrit) return theme.red
                        if (mb > theme.sysProcRamWarn) return theme.yellow
                        return theme.subtext0
                    }
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    Layout.preferredWidth: 50
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    text: modelData.cpu
                    color: {
                        var v = parseFloat(modelData.cpu)
                        if (v > theme.sysProcCpuCrit) return theme.red
                        if (v > theme.sysProcCpuWarn) return theme.yellow
                        return theme.subtext0
                    }
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    Layout.preferredWidth: 42
                    horizontalAlignment: Text.AlignRight
                }
            }
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
                    if (typeof data.cpu === "number") root.cpuPct = data.cpu
                    if (typeof data.gpu === "number") root.gpuPct = data.gpu
                    if (typeof data.ram === "number") root.ramPct = data.ram
                    if (typeof data.swap === "number") root.swapPct = data.swap
                    if (typeof data.ram_total === "number") root.ramTotalMb = data.ram_total
                    if (typeof data.ram_used === "number") root.ramUsedMb = data.ram_used
                    if (typeof data.swap_total === "number") root.swapTotalMb = data.swap_total
                    if (typeof data.swap_used === "number") root.swapUsedMb = data.swap_used
                    if (typeof data.gpu_freq === "number") root.gpuFreq = data.gpu_freq
                    if (typeof data.cpu_temp === "number") root.cpuTemp = data.cpu_temp
                    if (Array.isArray(data.top_processes)) {
                        var json = JSON.stringify(data.top_processes)
                        if (json !== root.topProcJson) {
                            root.topProcJson = json
                            root.topProcesses = data.top_processes
                        }
                    }

                    // GPU presence: prefer the script flag, else sticky heuristic.
                    if (data.gpu_available !== undefined)
                        root.gpuAvail = data.gpu_available === 1 || data.gpu_available === true
                    else if (root.gpuPct > 0 || root.gpuFreq > 0)
                        root.gpuAvail = true

                    root.pushHistory("cpuHistory", root.cpuPct)
                    root.pushHistory("gpuHistory", root.gpuPct)
                    root.pushHistory("ramHistory", root.ramPct)
                    root.pushHistory("swapHistory", root.swapPct)

                    root.hasData = true
                } catch (e) {
                    console.log("sys-usage-full parse error:", e)
                }
            }
        }
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
