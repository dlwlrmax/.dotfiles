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
            if (pct > 80) return theme.red
            if (pct > 50) return theme.yellow
            return theme.blue
        }
        if (metric === "gpu") {
            if (pct > 70) return theme.red
            if (pct > 40) return theme.yellow
            return theme.mauve
        }
        if (metric === "ram") {
            if (pct > 80) return theme.red
            if (pct > 50) return theme.yellow
            return theme.green
        }
        // swap
        if (pct > 50) return theme.red
        if (pct > 20) return theme.yellow
        return theme.peach
    }

    function pushHistory(which, value) {
        var arr = root[which].concat([value])
        if (arr.length > root.maxHistory)
            arr = arr.slice(arr.length - root.maxHistory)
        root[which] = arr

        // recalc min/max
        var minProp = which.replace("History", "Min")
        var maxProp = which.replace("History", "Max")
        if (arr.length === 0) {
            root[minProp] = 0; root[maxProp] = 0
        } else {
            var lo = 100, hi = 0
            for (var i = 0; i < arr.length; i++) {
                if (arr[i] < lo) lo = arr[i]
                if (arr[i] > hi) hi = arr[i]
            }
            root[minProp] = lo; root[maxProp] = hi
        }
        requestPaints()
    }

    function requestPaints() {
        if (cpuCanvas) cpuCanvas.requestPaint()
        if (gpuCanvas) gpuCanvas.requestPaint()
        if (ramCanvas) ramCanvas.requestPaint()
        if (swapCanvas) swapCanvas.requestPaint()
    }

    function drawSparkline(canvas, hist) {
        var w = canvas.width, h = canvas.height, n = hist.length
        if (w < 20 || h < 20 || n < 1) return

        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, w, h)

        var padR = 6  // right padding for terminal dot clearance
        var padB = 4  // bottom padding
        var padT = 4  // top padding
        var plotW = w - padR
        var plotH = h - padT - padB
        var baseY = h - padB

        // grid lines (25%, 50%, 75%)
        ctx.strokeStyle = theme.surface0
        ctx.lineWidth = 0.5
        for (var g = 25; g <= 75; g += 25) {
            var gy = baseY - (g / 100) * plotH
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(w, gy)
            ctx.stroke()
        }

        if (n === 1) {
            var sx = plotW / 2
            var sy = baseY - (hist[0] / 100) * plotH
            ctx.fillStyle = canvas.lineClr
            ctx.beginPath()
            ctx.arc(sx, sy, 2.5, 0, 2 * Math.PI)
            ctx.fill()
            return
        }

        var stepX = plotW / (n - 1)

        // ── filled area ──
        ctx.beginPath()
        ctx.moveTo(0, baseY)
        ctx.lineTo(0, baseY - (hist[0] / 100) * plotH)
        for (var i = 1; i < n; i++)
            ctx.lineTo(i * stepX, baseY - (hist[i] / 100) * plotH)
        ctx.lineTo((n - 1) * stepX, baseY)
        ctx.closePath()
        ctx.fillStyle = canvas.fillClr
        ctx.fill()

        // ── line ──
        ctx.beginPath()
        ctx.moveTo(0, baseY - (hist[0] / 100) * plotH)
        for (var j = 1; j < n; j++)
            ctx.lineTo(j * stepX, baseY - (hist[j] / 100) * plotH)
        ctx.strokeStyle = canvas.lineClr
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()

        // ── terminal dot ──
        var lx = (n - 1) * stepX
        var ly = baseY - (hist[n - 1] / 100) * plotH
        ctx.fillStyle = canvas.lineClr
        ctx.beginPath()
        ctx.arc(lx, ly, 2.5, 0, 2 * Math.PI)
        ctx.fill()
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

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4
                font.family: theme.font
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
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

                // ── CPU ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: 4
                        Text {
                            text: "CPU"
                            color: root.lineColor("cpu", root.cpuPct)
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.font
                            width: 24
                            verticalAlignment: Text.AlignVCenter
                        }
                        Canvas {
                            id: cpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property string lineClr: root.lineColor("cpu", root.cpuPct)
                            property string fillClr: root.hexToRgba(lineClr, 0.15)
                            onPaint: root.drawSparkline(this, root.cpuHistory)
                        }
                        ColumnLayout {
                            width: 54
                            spacing: 1
                            Text {
                                text: root.cpuPct + "%"
                                color: root.lineColor("cpu", root.cpuPct)
                                font.pixelSize: theme.fontSize + 1
                                font.bold: true
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: "L" + root.cpuMin + " H" + root.cpuMax
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: root.cpuTemp > 0
                                      ? (root.cpuTemp > 85 ? " " : root.cpuTemp > 70 ? " " : root.cpuTemp > 50 ? " " : " ") + root.cpuTemp + "°C"
                                      : ""
                                color: root.cpuTemp > 85 ? theme.red : root.cpuTemp > 70 ? theme.peach : root.cpuTemp > 50 ? theme.yellow : theme.green
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                                visible: root.cpuTemp > 0
                            }
                        }
                    }
                }

                // ── separator ──
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: theme.surface0
                }

                // ── GPU ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: 4
                        Text {
                            text: "GPU"
                            color: root.lineColor("gpu", root.gpuPct)
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.font
                            width: 24
                            verticalAlignment: Text.AlignVCenter
                        }
                        Canvas {
                            id: gpuCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property string lineClr: root.lineColor("gpu", root.gpuPct)
                            property string fillClr: root.hexToRgba(lineClr, 0.15)
                            onPaint: root.drawSparkline(this, root.gpuHistory)
                        }
                        ColumnLayout {
                            width: 54
                            spacing: 1
                            Text {
                                text: root.gpuPct + "%"
                                color: root.lineColor("gpu", root.gpuPct)
                                font.pixelSize: theme.fontSize + 1
                                font.bold: true
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: "L" + root.gpuMin + " H" + root.gpuMax
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: root.gpuFreq > 0 ? root.gpuFreq + "MHz" : ""
                                color: theme.subtext1
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                                visible: root.gpuFreq > 0
                            }
                        }
                    }
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

                // ── RAM ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: 4
                        Text {
                            text: "RAM"
                            color: root.lineColor("ram", root.ramPct)
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.font
                            width: 24
                            verticalAlignment: Text.AlignVCenter
                        }
                        Canvas {
                            id: ramCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property string lineClr: root.lineColor("ram", root.ramPct)
                            property string fillClr: root.hexToRgba(lineClr, 0.15)
                            onPaint: root.drawSparkline(this, root.ramHistory)
                        }
                        ColumnLayout {
                            width: 54
                            spacing: 1
                            Text {
                                text: root.ramPct + "%"
                                color: root.lineColor("ram", root.ramPct)
                                font.pixelSize: theme.fontSize + 1
                                font.bold: true
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: "L" + root.ramMin + " H" + root.ramMax
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: root.ramTotalMb > 0
                                      ? root.fmtMem(root.ramUsedMb) + "/" + root.fmtMem(root.ramTotalMb)
                                      : ""
                                color: theme.subtext1
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                                visible: root.ramTotalMb > 0
                            }
                        }
                    }
                }

                // ── separator ──
                Rectangle {
                    width: 1
                    Layout.fillHeight: true
                    color: theme.surface0
                }

                // ── SWAP ──
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    RowLayout {
                        anchors.fill: parent
                        spacing: 4
                        Text {
                            text: "SWAP"
                            color: root.lineColor("swap", root.swapPct)
                            font.pixelSize: theme.fontSize - 1
                            font.bold: true
                            font.family: theme.font
                            width: 24
                            verticalAlignment: Text.AlignVCenter
                        }
                        Canvas {
                            id: swapCanvas
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            property string lineClr: root.lineColor("swap", root.swapPct)
                            property string fillClr: root.hexToRgba(lineClr, 0.15)
                            onPaint: root.drawSparkline(this, root.swapHistory)
                        }
                        ColumnLayout {
                            width: 54
                            spacing: 1
                            Text {
                                text: root.swapPct + "%"
                                color: root.lineColor("swap", root.swapPct)
                                font.pixelSize: theme.fontSize + 1
                                font.bold: true
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: "L" + root.swapMin + " H" + root.swapMax
                                color: theme.subtext0
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                            }
                            Text {
                                text: root.swapTotalMb > 0
                                      ? root.fmtMem(root.swapUsedMb) + "/" + root.fmtMem(root.swapTotalMb)
                                      : ""
                                color: theme.subtext1
                                font.pixelSize: theme.fontSize - 2
                                font.family: theme.font
                                horizontalAlignment: Text.AlignRight
                                Layout.alignment: Qt.AlignRight
                                visible: root.swapTotalMb > 0
                            }
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
                width: 50
                horizontalAlignment: Text.AlignRight
            }

            Text {
                text: "CPU%"
                color: theme.subtext1
                font.pixelSize: theme.fontSize - 1
                font.bold: true
                font.family: theme.font
                width: 42
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
                        if (mb > 1024) return theme.red
                        if (mb > 512) return theme.yellow
                        return theme.subtext0
                    }
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    width: 50
                    horizontalAlignment: Text.AlignRight
                }

                Text {
                    text: modelData.cpu
                    color: {
                        var v = parseFloat(modelData.cpu)
                        if (v > 20) return theme.red
                        if (v > 10) return theme.yellow
                        return theme.subtext0
                    }
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    width: 42
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
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/sys-usage-full.sh"]

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
                    if (Array.isArray(data.top_processes)) root.topProcesses = data.top_processes

                    root.pushHistory("cpuHistory", root.cpuPct)
                    root.pushHistory("gpuHistory", root.gpuPct)
                    root.pushHistory("ramHistory", root.ramPct)
                    root.pushHistory("swapHistory", root.swapPct)
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
