import QtQuick

// Tiny history line/area (0..maxValue). The data source mutates `values` in
// place and bumps `tick`, which triggers the repaint.
Canvas {
    id: spark

    property var values: []
    property int tick: 0
    property real maxValue: 100
    property color clr: "#89b4fa"
    property int slots: 30

    implicitWidth: 32
    implicitHeight: 14

    onTickChanged: requestPaint()
    onClrChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var n = values.length
        if (n < 2) return
        var step = (width - 2) / (slots - 1)
        function xOf(i) { return width - 1 - (n - 1 - i) * step }
        function yOf(v) { return height - 1 - Math.min(v / maxValue, 1) * (height - 2) }

        ctx.beginPath()
        ctx.moveTo(xOf(0), height)
        for (var i = 0; i < n; i++) ctx.lineTo(xOf(i), yOf(values[i]))
        ctx.lineTo(xOf(n - 1), height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(clr, 0.2)
        ctx.fill()

        ctx.beginPath()
        ctx.moveTo(xOf(0), yOf(values[0]))
        for (var j = 1; j < n; j++) ctx.lineTo(xOf(j), yOf(values[j]))
        ctx.strokeStyle = clr
        ctx.lineWidth = 1.2
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
