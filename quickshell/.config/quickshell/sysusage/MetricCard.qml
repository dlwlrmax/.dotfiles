import QtQuick
import QtQuick.Layouts
import qs.common

Item {
    id: card

    property Theme theme
    property string label: ""
    property var history: []
    property int pct: 0
    property int minVal: 0
    property int maxVal: 0
    property string subText: ""
    property color subColor: "transparent"
    property bool subVisible: true
    property color lineClr: "transparent"
    readonly property color fillClr: Qt.alpha(lineClr, 0.15)
    property bool hasData: false

    // Y axis auto-scales so a quiet metric still shows shape: never below
    // minScale, otherwise the window max rounded up to the next 25%.
    property int minScale: 50
    readonly property int scaleMax: Math.min(100, Math.max(minScale, Math.ceil(maxVal / 25) * 25))

    Layout.fillWidth: true
    Layout.fillHeight: true

    function requestPaint() {
        spark.requestPaint()
    }

    // Sparkline is drawn imperatively so no binding churn on every sample.
    function drawSparkline(canvas, hist) {
        var w = canvas.width, h = canvas.height, n = hist.length
        if (w < 20 || h < 20 || n < 1) return

        var ctx = canvas.getContext("2d")
        ctx.clearRect(0, 0, w, h)

        var padR = 6  // right padding for terminal dot clearance
        var padB = 3  // bottom padding
        var padT = 3  // top padding
        var plotW = w - padR
        var plotH = h - padT - padB
        var baseY = h - padB
        var scale = card.scaleMax

        function yOf(v) { return baseY - Math.min(v / scale, 1) * plotH }

        // grid lines (25%, 50%, 75% of the current scale)
        ctx.strokeStyle = card.theme.surface1
        ctx.globalAlpha = 0.5
        ctx.lineWidth = 0.5
        for (var g = 1; g <= 3; g++) {
            var gy = baseY - (g / 4) * plotH
            ctx.beginPath()
            ctx.moveTo(0, gy)
            ctx.lineTo(w, gy)
            ctx.stroke()
        }
        ctx.globalAlpha = 1

        // scale label (top-left, dim)
        ctx.fillStyle = card.theme.overlay0
        ctx.font = (card.theme.fontSizeMin) + "px '" + card.theme.font + "'"
        ctx.textBaseline = "top"
        ctx.fillText(scale + "%", 2, 1)

        if (n === 1) {
            ctx.fillStyle = canvas.lineClr
            ctx.beginPath()
            ctx.arc(plotW / 2, yOf(hist[0]), 2.5, 0, 2 * Math.PI)
            ctx.fill()
            return
        }

        var stepX = plotW / (n - 1)

        // ── filled area ──
        ctx.beginPath()
        ctx.moveTo(0, baseY)
        ctx.lineTo(0, yOf(hist[0]))
        for (var i = 1; i < n; i++)
            ctx.lineTo(i * stepX, yOf(hist[i]))
        ctx.lineTo((n - 1) * stepX, baseY)
        ctx.closePath()
        ctx.fillStyle = canvas.fillClr
        ctx.fill()

        // ── line ──
        ctx.beginPath()
        ctx.moveTo(0, yOf(hist[0]))
        for (var j = 1; j < n; j++)
            ctx.lineTo(j * stepX, yOf(hist[j]))
        ctx.strokeStyle = canvas.lineClr
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.stroke()

        // ── terminal dot ──
        ctx.fillStyle = canvas.lineClr
        ctx.beginPath()
        ctx.arc((n - 1) * stepX, yOf(hist[n - 1]), 2.5, 0, 2 * Math.PI)
        ctx.fill()
    }

    Rectangle {
        anchors.fill: parent
        radius: theme.radiusLg
        color: Qt.alpha(card.theme.surface0, 0.45)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: card.label
                color: card.theme.subtext1
                font.pixelSize: card.theme.fontSize - 1
                font.bold: true
                font.family: card.theme.font
            }

            Text {
                text: card.hasData ? card.minVal + "–" + card.maxVal + "%" : ""
                color: card.theme.subtext0
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
            }

            Item { Layout.fillWidth: true }

            Text {
                text: card.subText
                color: card.subColor
                font.pixelSize: card.theme.fontSizeMin
                font.family: card.theme.font
                visible: card.subVisible
            }

            Text {
                text: card.pct + "%"
                color: card.lineClr
                font.pixelSize: card.theme.fontSize + 2
                font.bold: true
                font.family: card.theme.font
            }
        }

        Canvas {
            id: spark
            Layout.fillWidth: true
            Layout.fillHeight: true
            property color lineClr: card.lineClr
            property color fillClr: card.fillClr
            onPaint: card.drawSparkline(this, card.history)
        }
    }
}
