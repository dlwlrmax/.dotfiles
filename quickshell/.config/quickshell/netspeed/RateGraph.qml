import QtQuick
import qs.common

// Download (filled) / upload (line) throughput history, newest sample at the
// right edge. Arrays are mutated in place by the data source; `tick` repaints.
Canvas {
    id: g

    property Theme theme
    property var dl: []
    property var ul: []
    property int tick: 0
    property int slots: 60
    property color dlClr: theme.blue
    property color ulClr: theme.peach

    onTickChanged: requestPaint()
    onDlClrChanged: requestPaint()
    onUlClrChanged: requestPaint()

    // Next round scale at or above v (bytes/s): 20/50/100/200/500 KB, then
    // 1/2/5 × 10^k MB. Never below 20 KB/s.
    function niceMax(v) {
        var kib = Math.max(v / 1024, 20)
        var steps = [20, 50, 100, 200, 500]
        for (var m = 1024; m <= 1048576; m *= 10) steps.push(m, m * 2, m * 5)
        for (var i = 0; i < steps.length; i++)
            if (steps[i] >= kib) return steps[i] * 1024
        return steps[steps.length - 1] * 1024
    }

    function fmtRate(bps) {
        if (bps >= 1048576) return +(bps / 1048576).toFixed(1) + "M/s"
        return Math.round(bps / 1024) + "K/s"
    }

    function seriesMax() {
        var m = 0
        for (var i = 0; i < dl.length; i++) m = Math.max(m, dl[i], ul[i] || 0)
        return m
    }

    onPaint: {
        var w = width, h = height
        if (w < 20 || h < 20) return
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, w, h)

        var padT = 3, padB = 3
        var plotH = h - padT - padB
        var baseY = h - padB
        var scale = niceMax(seriesMax())
        var n = dl.length
        var stepX = (w - 4) / (slots - 1)

        function xOf(i) { return w - 4 - (n - 1 - i) * stepX }
        function yOf(v) { return baseY - Math.min(v / scale, 1) * plotH }

        // grid: half and full scale
        ctx.strokeStyle = g.theme.surface1
        ctx.globalAlpha = 0.5
        ctx.lineWidth = 0.5
        for (var q = 1; q <= 2; q++) {
            var gy = baseY - (q / 2) * plotH
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(w, gy)
            ctx.stroke()
        }
        ctx.globalAlpha = 1

        ctx.fillStyle = g.theme.overlay0
        ctx.font = (g.theme.fontSizeMin) + "px '" + g.theme.font + "'"
        ctx.textBaseline = "top"
        ctx.fillText(fmtRate(scale), 2, 1)

        if (n < 2) return

        function trace(series) {
            ctx.moveTo(xOf(0), yOf(series[0]))
            for (var i = 1; i < n; i++) ctx.lineTo(xOf(i), yOf(series[i]))
        }

        // download: filled area + line
        ctx.beginPath()
        ctx.moveTo(xOf(0), baseY)
        ctx.lineTo(xOf(0), yOf(dl[0]))
        for (var i = 1; i < n; i++) ctx.lineTo(xOf(i), yOf(dl[i]))
        ctx.lineTo(xOf(n - 1), baseY)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(dlClr, 0.18)
        ctx.fill()

        ctx.beginPath()
        trace(dl)
        ctx.strokeStyle = dlClr
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()

        // upload: line
        ctx.beginPath()
        trace(ul)
        ctx.strokeStyle = ulClr
        ctx.lineWidth = 1.5
        ctx.stroke()
    }
}
